#!/usr/bin/env bash
# directional_diff_gate.sh — post-push loss detector for FILE-REPLACEMENT pushes.
#
# WHY (pmh-dev #42, measured 2026-08-08): a push that REPLACES a file with local bytes
# (REST Contents API, mirror sync, any upload-the-whole-file path) silently drops lines
# that existed only on the remote. Three defenses were green while the file was damaged:
#
#   tool warning   "remote differs (remote=X local=Y) — overwriting"  → says THAT it differs,
#                  never WHAT disappears. Reads as normal if you believe local is canonical.
#   additions/deletions total   1 deletion + 91 additions looks like net growth. The
#                  previous round passed 141 = 141 with this method — it cannot see DIRECTION.
#   rc             rc=0, correctly: the replace succeeded. The defect was in the request.
#
# The lost line was a mirror banner ("do not edit here, next sync overwrites"). Losing it
# does not cost one line — it costs the only marker telling the next session the file is
# not canonical. Loss classes are silent by nature; that is why this runs as a gate.
#
# WHAT THIS ADDS: direction. It does not replace the total-count check; totals stay useful
# and blind to sign. Verdict is per file: deletions must be 0, additions/modifications free.
#
# ── Verdict / exit codes ────────────────────────────────────────────────────────
#   0   CLEAN        no deleted lines (or every deletion acknowledged, see ack below)
#   1   DELETIONS    lines present on the remote are gone locally, unacknowledged → BLOCK
#  10   UNDECIDABLE  the comparison could not be MADE (decode/API/instrument failure).
#                    Deliberately NOT 0. A file-replacement push is a delete-class surface,
#                    so an un-runnable check fails CLOSED (§Irreversibility Surface-Class
#                    Degrade Invariant). "Could not compare" is not "nothing was lost".
#
# ── Acknowledging an intentional deletion ───────────────────────────────────────
# Removing a remote-only line is sometimes correct (retiring a bot banner). Blocking
# unconditionally would make this an always-red gate and teach --no-verify — the #33
# lineage this repo has already paid for. So deletions are ACK-gated, not forbidden:
#
#   DIRECTIONAL_DIFF_ACK="<what is being deleted and why>" bash scripts/directional_diff_gate.sh …
#
# The ack is checked for non-vacuity because the whole defect was a warning that said
# "something differs" without saying what. An ack that also declines to say what is the
# same failure wearing an approval. A bare "ok"/"yes"/"1" is rejected.
#
# ── Usage ───────────────────────────────────────────────────────────────────────
#   bash scripts/directional_diff_gate.sh <owner/repo> <base_sha> <path> [<path>...]
#   bash scripts/directional_diff_gate.sh --self-test        # known-pair calibration
#
# <base_sha> is the commit the push was based on — the state to compare AGAINST.

set -uo pipefail

# ── portable base64 decode (BSD `-D` vs GNU `-d`) ───────────────────────────────
# A BSD-first `-D || -d` chain is how this repo previously shipped a script that was
# green on macOS and 66/70 red on Linux CI. Probe once, both directions, no assumption.
b64_decode() {
  if printf 'YQ==' | base64 -d >/dev/null 2>&1; then base64 -d
  elif printf 'YQ==' | base64 -D >/dev/null 2>&1; then base64 -D
  else return 127; fi
}

TMP=$(mktemp -d) || { echo "HARNESS-ERROR: mktemp failed"; exit 10; }
trap 'rm -rf "$TMP"' EXIT

# ── one file → verdict on stdout, status in return code ─────────────────────────
check_path() { # $1=repo $2=base_sha $3=path
  local repo="$1" base="$2" path="$3"
  local prev="$TMP/prev" raw="$TMP/raw"

  if [ ! -f "$path" ]; then
    echo "  ⚠️  $path — not present locally; nothing to compare (skipped)"
    return 0
  fi

  # Trap #1 (measured): an unquoted ?ref= is eaten by zsh as a glob → "no matches found",
  # which reads like a repo/path error and is a shell error. The URL is quoted here so a
  # caller cannot reintroduce it.
  local http
  http=$(gh api "repos/${repo}/contents/${path}?ref=${base}" --jq .content > "$raw" 2>"$TMP/err"; echo $?)

  if [ "$http" -ne 0 ]; then
    # 404 = the file did NOT exist at base → this push creates it → every line is an
    # addition and deletions are genuinely 0. Any OTHER failure is undecidable, and the
    # two must not share an exit: treating an auth/network error as "new file" is exactly
    # the not-found-is-not-zero collapse this gate exists to stop.
    if grep -qi 'not found\|HTTP 404' "$TMP/err"; then
      echo "  ✅ $path — new file at base (404) → del=0"
      return 0
    fi
    echo "  🟥 $path — UNDECIDABLE: API call failed"
    sed 's/^/       /' "$TMP/err" | head -3
    return 10
  fi

  # Trap #2 (measured, and it actually fired): `--jq .content` returns base64 WITH
  # embedded newlines. Decoding without stripping them dies and leaves a 0-line file —
  # and then diff reports "all additions", del=0, and the loss check passes while having
  # measured nothing. The line-count assertion below is the whole point: a 0-line decode
  # of a non-empty payload is UNDECIDABLE, never a clean verdict.
  if ! tr -d '\n' < "$raw" | b64_decode > "$prev" 2>/dev/null; then
    echo "  🟥 $path — UNDECIDABLE: base64 decode failed (no usable base64 on PATH?)"
    return 10
  fi
  local raw_bytes prev_lines
  raw_bytes=$(wc -c < "$raw" | tr -d ' ')
  prev_lines=$(wc -l < "$prev" | tr -d ' ')
  if [ "$raw_bytes" -gt 8 ] && [ "$prev_lines" -eq 0 ]; then
    echo "  🟥 $path — UNDECIDABLE: payload was ${raw_bytes}B but decoded to 0 lines"
    echo "       (this is the measured trap: 0 lines makes diff report del=0 and the"
    echo "        check passes without comparing anything — unmeasured, not clean)"
    return 10
  fi

  # Direction: count only lines the remote had and the local does not.
  local del
  del=$(diff "$prev" "$path" 2>/dev/null | grep -c '^<')
  if [ "$del" -eq 0 ]; then
    echo "  ✅ $path — del=0 (compared ${prev_lines} remote lines)"
    return 0
  fi
  echo "  ❌ $path — ${del} remote line(s) would be LOST:"
  diff "$prev" "$path" 2>/dev/null | grep '^<' | head -10 | sed 's/^/       /'
  [ "$del" -gt 10 ] && echo "       … and $((del-10)) more"
  return 1
}

# ── known-pair calibration ──────────────────────────────────────────────────────
# An instrument is a claim about the world only after it separates a case whose answer
# you already know. This runs offline against fabricated pairs — no network, no repo.
self_test() {
  local f=0 n=0
  t() { n=$((n+1)); if [ "$2" = "$3" ]; then echo "✅ $1 → $3"; else echo "❌ $1 → $3 (expected $2)"; f=1; fi; }

  printf 'a\nb\nc\n' > "$TMP/p"; printf 'a\nb\nc\n' > "$TMP/l"
  diff "$TMP/p" "$TMP/l" >/dev/null 2>&1 && r=CLEAN || r=DIFF
  t "identical files" CLEAN "$r"

  printf 'a\nb\nc\n' > "$TMP/p"; printf 'a\nb\nc\nd\n' > "$TMP/l"
  [ "$(diff "$TMP/p" "$TMP/l" | grep -c '^<')" -eq 0 ] && r=CLEAN || r=DEL
  t "pure addition (del must be 0)" CLEAN "$r"

  # The measured event: 1 deletion buried under 91 additions. Totals call this net growth.
  printf 'BANNER\na\nb\n' > "$TMP/p"; { echo a; echo b; for i in $(seq 1 91); do echo "new$i"; done; } > "$TMP/l"
  [ "$(diff "$TMP/p" "$TMP/l" | grep -c '^<')" -gt 0 ] && r=DEL || r=CLEAN
  t "banner dropped under 91 additions (the measured event)" DEL "$r"
  local tot_add tot_del
  tot_add=$(diff "$TMP/p" "$TMP/l" | grep -c '^>'); tot_del=$(diff "$TMP/p" "$TMP/l" | grep -c '^<')
  [ "$tot_add" -gt "$tot_del" ] && r=NETGROWTH || r=NETLOSS
  t "  └ and a total-only check reads it as" NETGROWTH "$r"

  # Trap #2 reproduced: a 0-line "previous" makes deletions unmeasurable, not zero.
  : > "$TMP/p0"; printf 'a\nb\n' > "$TMP/l"
  [ "$(diff "$TMP/p0" "$TMP/l" | grep -c '^<')" -eq 0 ] && r=LOOKS_CLEAN || r=DEL
  t "0-line decode reads as clean (why 0 lines must be UNDECIDABLE)" LOOKS_CLEAN "$r"

  printf 'YQ==' | b64_decode >/dev/null 2>&1 && r=OK || r=BROKEN
  t "base64 decode available on this platform" OK "$r"

  # Ack non-vacuity, both directions.
  for pair in "ok:VACUOUS" "1:VACUOUS" "yes:VACUOUS" "removing the retired mirror banner, superseded by frontmatter:SUBSTANTIVE"; do
    local val="${pair%:*}" want="${pair##*:}"
    if printf '%s' "$val" | grep -qE '.{20,}'; then r=SUBSTANTIVE; else r=VACUOUS; fi
    t "ack '${val:0:24}'" "$want" "$r"
  done

  echo; [ "$f" -eq 0 ] && echo "✅ calibration passed ($n pairs)" || echo "❌ calibration FAILED ($n pairs)"
  return "$f"
}

# ── main ────────────────────────────────────────────────────────────────────────
[ "${1:-}" = "--self-test" ] && { self_test; exit $?; }

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <owner/repo> <base_sha> <path> [<path>...]"
  echo "       $0 --self-test"
  exit 10
fi
REPO="$1"; BASE="$2"; shift 2

echo "── directional diff vs ${REPO}@${BASE:0:12} ──"
WORST=0
for p in "$@"; do
  check_path "$REPO" "$BASE" "$p"; rc=$?
  # 10 (undecidable) outranks 1 (deletions): an unmeasured file is a worse verdict than a
  # measured bad one, because only the first is invisible.
  [ "$rc" -eq 10 ] && WORST=10
  [ "$rc" -eq 1 ] && [ "$WORST" -ne 10 ] && WORST=1
done

echo
case "$WORST" in
  0) echo "✅ CLEAN — no remote-only lines lost"; exit 0 ;;
  10) echo "🟥 UNDECIDABLE — the comparison could not be made for ≥1 file."
      echo "   Fails closed: a file-replacement push is a delete-class surface, and"
      echo "   'could not compare' is not 'nothing was lost'. Fix the instrument and re-run."
      exit 10 ;;
  1) ACK="${DIRECTIONAL_DIFF_ACK:-}"
     if [ -z "$ACK" ]; then
       echo "❌ DELETIONS — remote-only lines would be lost, unacknowledged."
       echo "   If the removal is intentional, say WHAT is being removed (the defect this"
       echo "   gate exists for was a warning that announced a difference without naming it):"
       echo "     DIRECTIONAL_DIFF_ACK=\"<what is deleted and why>\" $0 $REPO $BASE <paths>"
       exit 1
     fi
     if ! printf '%s' "$ACK" | grep -qE '.{20,}'; then
       echo "❌ DELETIONS — ack present but vacuous ('$ACK')."
       echo "   Name the removed content, not the fact of removal. 'ok' / '1' / 'yes' is"
       echo "   an approval that declines to say what it approves."
       exit 1
     fi
     echo "⚠️  DELETIONS acknowledged — proceeding (recorded, not silent)"
     echo "    ack: $ACK"
     exit 0 ;;
esac
