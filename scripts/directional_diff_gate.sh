#!/usr/bin/env bash
# directional_diff_gate.sh — PRE-push loss gate for FILE-REPLACEMENT pushes.
# (It said "post-push detector" while it had no callers. Wired into rest_push.sh on
#  2026-08-09 it runs BEFORE tree/commit/ref, so the name had to stop lying.)
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
# and blind to sign.
#
# ── Which deletions are the DEFECT, and which are just editing (measured 2026-08-09) ──
# The first version blocked on EVERY deletion. Measured against the real remote that day:
#
#   local file identical to remote                          → CLEAN  rc=0   (correct)
#   one comment line deliberately removed, two lines added  → BLOCK  rc=1   (over-block)
#
# i.e. every routine refactor push goes red, the operator sets DIRECTIONAL_DIFF_ACK by
# reflex, and the gate is disarmed. That is the #33 lineage this repo has already paid for:
# a tool that always blocks teaches the bypass. An always-red gate is not a strict gate.
#
# The verdict stays what it was: **any line the remote has and the local upload does not**
# is a loss, and it blocks. That is `R − L` as a MULTISET (`comm` over sorted files), so a
# remote process appending a SECOND copy of a line the file already had once is caught too;
# a set-membership test waves that through.
#
# ── Why the over-block is answered by the ACK, not by a smarter verdict ─────────
# A three-way was built and MEASURED on 2026-08-09 and then withdrawn. It took
# B = merge-base(HEAD, <base_sha>) and blocked only on `(R − B) − (L − B)`, so your own
# deletions never blocked. It was withdrawn because a cross-family review produced a
# counterexample the author had not found:
#
#     HEAD == remote tip  ⇒  B == R  ⇒  R − B = ∅  ⇒  NOTHING can ever be reported,
#     including a genuine loss when the local file is stale or foreign bytes rather than
#     an edit of HEAD.
#
# merge-base proves a common ANCESTOR; it does not prove "the version this upload was
# derived from". Git cannot tell an edit of HEAD from foreign bytes pasted over it, and a
# file-replacement push is exactly the surface where the bytes come from somewhere else.
# So the precise mode needs the caller to DECLARE its edit base, and until something can
# supply that declaration the gate does not guess. Trading a measured over-block for an
# unmeasurable fail-open is the wrong direction on a delete-class surface.
#
# What answers the over-block instead: the acknowledgement is bound to the exact loss set
# (see below). You cannot keep one ACK in your shell history and wave every push through —
# the token changes with the content, so an ACK always costs a LOOK at what is being lost.
# That is the property the reflex-ACK failure mode actually needs; a looser verdict was
# never the only way to get it.
#
# ── Verdict / exit codes ────────────────────────────────────────────────────────
#   0   CLEAN        no deleted lines (or every deletion acknowledged, see ack below)
#   1   DELETIONS    lines the remote has are missing from the upload, unacknowledged
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
#   DIRECTIONAL_DIFF_ACK="LOSS-<token> <what is being deleted and why>" …
#
# TWO conditions, and the second is the one that matters:
#   · non-vacuous prose (≥20 chars) — the original defect was a warning that announced a
#     difference without naming it; an approval that also declines to say what is the same
#     failure wearing a different hat. "ok" / "1" / "yes" is rejected.
#   · the LOSS-<token> printed by THIS run. The token hashes the repo, the base sha, and
#     every (path, lost line) pair — so an ack is valid for exactly one loss set, on one
#     repo, at one base. It cannot be parked in shell history and reused: the same line
#     lost from a different file is a different token, and so is the same file at a
#     different base. Every acknowledgement therefore costs one LOOK at the list. That is
#     what actually defuses reflex-ACK; a looser verdict never had to.
#     It also ends the blanket ACK — one file's explanation no longer clears a second
#     file's loss, because the token covers the union of both.
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

# ── has_nul: binary detection ──────────────────────────────────────────────────
# ONE implementation, called by check_path AND by --self-test. Until 2026-09-05 this was defined
# twice, byte-identical, once inside each caller — so the self-test exercised ITS OWN copy and a
# broken production copy stayed green (3-arm mutation: production-only break → rc=0). The file
# already pinned the one-implementation rule for compute_lost and loss_token; this was the one
# helper that escaped it. NOT `grep -q $'\x00'`: bash cannot hold a NUL in a string, so that
# collapses to the EMPTY pattern and every text file is declared binary. Strip-and-compare.
has_nul() { LC_ALL=C tr -d '\000' < "$1" | cmp -s - "$1" || return 0; return 1; }

# ── compute_lost: the verdict, as multiset arithmetic ───────────────────────────
#   $TMP/lost = R − L   (occurrences the remote has that the upload does not)
# ONE implementation, called by check_path AND by --self-test — two copies of the same
# normalisation is how an input passes one and is silently dropped by the other.
#
# rc: 0 = computed, 10 = the computation itself failed. `sort`/`comm` failures used to be
# invisible: a truncated sort leaves an empty file, comm then produces an empty `lost`, and
# nlost=0 renders as CLEAN. An instrument that failed must not answer "nothing was lost".
compute_lost() { # $1=R file  $2=L file
  # 🟥 2026-09-01 — `LC_ALL=C` 가 하중이다. 이 로케일에서 `sort`/`comm` 은 **ASCII 접두가 같고
  #    그 뒤가 비ASCII 인 두 줄을 «같다»고 접는다**(비교가 첫 비ASCII 바이트에서 잘린다).
  #    비교 대상은 «파일 내용의 줄»이고 이 저장소 문서는 한글이다. 실측:
  #      「한글 줄 하나」 vs 「한글 줄 둘」 → comm -23 **0 줄** · LC_ALL=C **1 줄** · ASCII 컨트롤 1 줄
  #    ⇒ 없어진 줄이 «0» 으로 렌더되고 위 주석이 경고한 그 CLEAN 오답이 그대로 난다.
  #    rc 실패 경로는 아래 `|| return 10` 이 막지만 **로케일 접힘은 rc 가 0 이라 안 막힌다** —
  #    같은 결과가 다른 원인으로 난다. [[feedback_locale_string_equality_breaks_nonascii]]
  LC_ALL=C sort "$1" > "$TMP/rs" || return 10
  LC_ALL=C sort "$2" > "$TMP/ls" || return 10
  LC_ALL=C comm -23 "$TMP/rs" "$TMP/ls" > "$TMP/lost" || return 10
  return 0
}

# ── loss_token: the ack binding ─────────────────────────────────────────────────
# Material = repo + base + every (path, lost line). One implementation, called by main
# AND by --self-test: a calibration that hashes a *replica* of the material proves nothing
# about the token the operator is actually asked to paste.
loss_token() { # $1=repo $2=base   (reads $TMP/lost_all)
  { printf '%s\n%s\n' "$1" "$2"; sort "$TMP/lost_all"; } 2>/dev/null | shasum 2>/dev/null | cut -c1-12
}

# ── one file → verdict on stdout, status in return code ─────────────────────────
check_path() { # $1=repo $2=base_sha $3=path
  local repo="$1" base="$2" path="$3"
  local prev="$TMP/prev" raw="$TMP/raw"

  # A missing local file is NOT "nothing to compare". On a delete-class surface it is the
  # signature of a mis-wired caller (wrong cwd, cwd-relative path passed where a repo-root
  # one was meant) — and the previous version returned 0 here, so a wiring mistake read as
  # CLEAN and the whole gate silently measured nothing. Unmeasured is not clean.
  if [ ! -f "$path" ]; then
    echo "  🟥 $path — UNDECIDABLE: not present locally (wrong cwd, or a path that is not"
    echo "       repo-root-relative). A file this gate cannot read is not a file it cleared."
    return 10
  fi

  # The path goes into a URL query-bearing request unencoded. A legitimate filename with
  # `?`, `#` or `%` therefore addresses a DIFFERENT resource, and the likely answer is a
  # 404 — which this gate reads as "new file at base → nothing to lose". A wrong request
  # that returns a clean verdict is worse than no request. Refuse instead of guessing.
  # ── the bytes I judged must be the bytes you upload ─────────────────────────
  # A caller that materialises a fixed payload into a scratch tree still hands this gate a
  # MUTABLE file. The verdict then binds to "whatever was in that file when I read it",
  # while the upload binds to the fixed object — swap the scratch copy mid-run and the two
  # diverge (cross-family R5). So the caller may DECLARE the object id per path, and this
  # gate refuses to judge anything whose bytes do not hash to the declared id.
  # Absent declaration = standalone/manual use; no binding is claimed and none is enforced.
  if [ -n "${DIRECTIONAL_DIFF_PINS:-}" ] && [ -f "${DIRECTIONAL_DIFF_PINS}" ]; then
    local want got
    want=$(LC_ALL=C awk -F'\t' -v p="$path" '$2==p{print $1; exit}' "$DIRECTIONAL_DIFF_PINS")  # 로케일 접힘 방지(pins 경로)
    if [ -z "$want" ]; then
      echo "  🟥 $path — UNDECIDABLE: pins declared but this path is not among them."
      echo "       Judging a file the caller did not pin means the verdict binds to nothing."
      return 10
    fi
    got=$(git hash-object --no-filters "$path" 2>/dev/null)
    if [ "$got" != "$want" ]; then
      echo "  🟥 $path — UNDECIDABLE: bytes do not match the declared object."
      echo "       declared ${want:0:12} · read ${got:0:12} — the thing I would judge is not"
      echo "       the thing you would upload. Refusing to produce a verdict for it."
      return 10
    fi
  fi

  case "$path" in
    *'?'*|*'#'*|*'%'*)
      echo "  🟥 $path — UNDECIDABLE: path contains a URL-significant character (? # %)."
      echo "       The contents request would address a different resource and its 404"
      echo "       would read as 'new file'. Not encoding it silently."
      return 10 ;;
  esac

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
    # NOT a loose `not found` grep: `gh: command not found` and `repository not found`
    # both match it, and both would be rendered as "new file at base → del=0" — a
    # fail-open dressed as a 404. Require the HTTP status literal.
    if grep -q 'HTTP 404' "$TMP/err"; then
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

  # A binary payload has no lines to reason about, and a line-wise verdict over it is
  # noise that reads as a measurement. Refuse rather than produce a number.
  # NOT `grep -q $'\x00'`: bash cannot hold a NUL in a string, so `$'\x00'` collapses to
  # the EMPTY pattern, grep matches every line, and every text file is declared binary —
  # a total over-block that looks like a strict check. Strip-and-compare instead.
  if has_nul "$prev" || has_nul "$path"; then
    echo "  🟥 $path — UNDECIDABLE: binary content (NUL bytes); a line-wise direction"
    echo "       verdict over binary is not a measurement."
    return 10
  fi

  if ! compute_lost "$prev" "$path"; then
    echo "  🟥 $path — UNDECIDABLE: the comparison itself failed (sort/comm)."
    echo "       A failed instrument does not get to answer 'nothing was lost'."
    return 10
  fi
  local nlost
  nlost=$(wc -l < "$TMP/lost" | tr -d ' ')
  if [ "$nlost" -eq 0 ]; then
    echo "  ✅ $path — 0 lost (compared ${prev_lines} remote lines)"
    return 0
  fi
  echo "  ❌ $path — ${nlost} remote line(s) would be LOST:"
  head -10 "$TMP/lost" | sed 's/^/       < /'
  [ "$nlost" -gt 10 ] && echo "       … and $((nlost-10)) more"
  # Accumulate WITH the path so the token distinguishes "line X lost from a" from
  # "line X lost from b" — without it, an ack earned on one file clears the other.
  # rc is checked: a partial accumulation would hash to a token that acknowledges less
  # than what is actually being lost.
  if ! sed "s|^|${path}\t|" "$TMP/lost" >> "$TMP/lost_all"; then
    echo "  🟥 $path — UNDECIDABLE: could not record the loss set for the ack token"
    return 10
  fi
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

  # ── the verdict arithmetic, against the SHIPPED compute_lost ──────────────────
  lostn() { compute_lost "$TMP/tr" "$TMP/tl" || { echo ERR; return; }; wc -l < "$TMP/lost" | tr -d ' '; }

  # (a) the measured incident: a banner the remote has and the upload does not.
  printf 'BANNER\na\nb\n' > "$TMP/tr"; printf 'a\nb\n' > "$TMP/tl"
  t "remote line missing from the upload → lost" 1 "$(lostn)"

  # (b) pure addition must not block — an always-red gate teaches the bypass (#33).
  printf 'a\nb\n' > "$TMP/tr"; printf 'a\nb\nnew\n' > "$TMP/tl"
  t "pure addition → 0 lost (over-block guard)" 0 "$(lostn)"

  # (c) multiplicity: a SECOND copy of a line the file already had once is a real loss.
  #     Set membership reports 0 here; that is why comm (multiset) is used.
  printf 'DUP\nDUP\n' > "$TMP/tr"; printf 'DUP\n' > "$TMP/tl"
  t "remote has 2 copies, upload has 1 → 1 lost (set-test would say 0)" 1 "$(lostn)"

  # (d) a block of remote-only lines counts as a block, not as one.
  printf 'x\nP\nQ\nR\n' > "$TMP/tr"; printf 'x\n' > "$TMP/tl"
  t "remote-only block of 3 → 3 lost" 3 "$(lostn)"

  # (e) reordering is NOT loss under a line-frequency contract — pinned so the contract is
  #     explicit rather than accidental. (Position/section context is a named non-goal:
  #     this gate preserves line occurrences, not their placement.)
  printf 'a\nb\n' > "$TMP/tr"; printf 'b\na\n' > "$TMP/tl"
  t "reordered lines → 0 lost (frequency contract, not a position check)" 0 "$(lostn)"

  # (f) instrument failure must not answer "nothing was lost".
  compute_lost "$TMP/__no_such_file__" "$TMP/tl" >/dev/null 2>&1 && r=SILENT || r=RC_NONZERO
  t "unreadable input → compute_lost fails loudly (not a clean 0)" RC_NONZERO "$r"

  # (g) ACK binding, against the SHIPPED loss_token. The token must move with EVERY part
  #     of the material — content, path, repo, base — or a parked ack clears the wrong loss.
  : > "$TMP/lost_all"; printf 'a.sh\tX\n' >> "$TMP/lost_all"
  g_content=$(loss_token o/r base1)
  : > "$TMP/lost_all"; printf 'a.sh\tY\n' >> "$TMP/lost_all"
  g_other=$(loss_token o/r base1)
  t "token moves when the lost LINE differs" DIFFERENT "$([ "$g_content" != "$g_other" ] && echo DIFFERENT || echo SAME)"

  : > "$TMP/lost_all"; printf 'b.sh\tX\n' >> "$TMP/lost_all"
  g_path=$(loss_token o/r base1)
  t "token moves when the same line is lost from a DIFFERENT FILE" DIFFERENT \
    "$([ "$g_content" != "$g_path" ] && echo DIFFERENT || echo SAME)"

  : > "$TMP/lost_all"; printf 'a.sh\tX\n' >> "$TMP/lost_all"
  t "token moves with the REPO"  DIFFERENT "$([ "$g_content" != "$(loss_token o/other base1)" ] && echo DIFFERENT || echo SAME)"
  t "token moves with the BASE"  DIFFERENT "$([ "$g_content" != "$(loss_token o/r base2)" ] && echo DIFFERENT || echo SAME)"
  t "token is stable for identical material" STABLE \
    "$([ "$g_content" = "$(loss_token o/r base1)" ] && echo STABLE || echo UNSTABLE)"
  t "token is 12 hex chars (8 is 32 bits on a value that must not collide by accident)" 12 \
    "$(printf '%s' "$g_content" | wc -c | tr -d ' ')"
  : > "$TMP/lost_all"

  # (h) NUL detection. The first draft used `grep -q $'"'"'\x00'"'"'`, which bash collapses to the
  #     EMPTY pattern — every text file matched and every push would have been declared
  #     binary/UNDECIDABLE. Both directions are pinned so that regression cannot return.
  printf 'plain text\n' > "$TMP/tn"
  has_nul "$TMP/tn" && r=BINARY || r=TEXT
  t "plain text is not misread as binary" TEXT "$r"
  printf 'a\000b\n' > "$TMP/tn"
  has_nul "$TMP/tn" && r=BINARY || r=TEXT
  t "a file with NUL bytes is detected as binary" BINARY "$r"
  # (h2) The pair above measures PRODUCTION only if there is exactly ONE definition — a second,
  #      self-test-local copy made this suite green while the production copy was broken
  #      (2026-09-05, 3-arm mutation). Pin the count so the shadow copy cannot return.
  t "has_nul is defined exactly once (the self-test measures the production copy)" 1 \
    "$(grep -c '^has_nul() {' "$0" | tr -d ' ')"

  # (i) 404 must be the HTTP status, not any stderr containing "not found".
  #     `gh: command not found` used to be accepted as "new file at base" → fail-open.
  for pair in "gh: Not Found (HTTP 404):IS404" "gh: command not found:NOT404" "repository not found:NOT404"; do
    msg="${pair%:*}"; want="${pair##*:}"
    printf '%s\n' "$msg" | grep -q 'HTTP 404' && r=IS404 || r=NOT404
    t "404 discrimination '${msg:0:26}'" "$want" "$r"
  done

  # (j) structural: an unrecognised per-file rc must not aggregate to CLEAN.
  if grep -q '\*)  echo "  🟥 \$p — HARNESS-ERROR: unrecognised check rc' "$0"; then r=HAS_DEFAULT; else r=NO_DEFAULT; fi
  t "aggregator has a default branch for unknown rc" HAS_DEFAULT "$r"

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
: > "$TMP/lost_all"
WORST=0
for p in "$@"; do
  check_path "$REPO" "$BASE" "$p"; rc=$?
  # 10 (undecidable) outranks 1 (deletions): an unmeasured file is a worse verdict than a
  # measured bad one, because only the first is invisible.
  # An UNRECOGNISED rc must not fall through as clean. check_path returns 0/1/10 today,
  # but a future edit (or a `set -u` abort, a 127, a 128 from git) returning anything else
  # would leave WORST at 0 and the run would end "✅ CLEAN" having decided nothing. The
  # aggregator is where that becomes invisible, so the default lives here.
  case "$rc" in
    0)  : ;;
    1)  [ "$WORST" -ne 10 ] && WORST=1 ;;
    10) WORST=10 ;;
    *)  echo "  🟥 $p — HARNESS-ERROR: unrecognised check rc=$rc (treated as undecidable)"
        WORST=10 ;;
  esac
done

echo
case "$WORST" in
  0) echo "✅ CLEAN — no remote-only lines lost"; exit 0 ;;
  10) echo "🟥 UNDECIDABLE — the comparison could not be made for ≥1 file."
      echo "   Fails closed: a file-replacement push is a delete-class surface, and"
      echo "   'could not compare' is not 'nothing was lost'. Fix the instrument and re-run."
      exit 10 ;;
  1) ACK="${DIRECTIONAL_DIFF_ACK:-}"
     # Token over the UNION of every lost line, sorted so the same loss set always yields
     # the same token regardless of the order files were given on the command line.
     # Material = repo + base + every (path, lost line). An ack is then valid for exactly
     # one loss, on one repo, at one base — not for "some line X somewhere". 12 hex chars
     # rather than 8: an 8-char prefix is 32 bits, which is a collision surface on a value
     # whose whole job is to be unforgeable-by-accident.
     TOKEN=$(loss_token "$REPO" "$BASE")
     if [ -z "$TOKEN" ]; then
       # No hash tool ⇒ the ACK cannot be bound to anything ⇒ do not fall back to an
       # unbound ACK. An unbindable acknowledgement on a delete-class surface is the
       # reflex-ACK failure this token exists to stop.
       echo "🟥 UNDECIDABLE — cannot compute the loss token (no shasum on PATH)."
       echo "   Refusing to accept an unbound acknowledgement. Fix the instrument."
       exit 10
     fi
     if [ -z "$ACK" ]; then
       echo "❌ DELETIONS — lines present on the remote would be lost, unacknowledged."
       echo "   Look at the list above. If every one of those removals is intended, say WHAT"
       echo "   is being removed and include this run's token:"
       echo "     DIRECTIONAL_DIFF_ACK=\"LOSS-$TOKEN <what is deleted and why>\" $0 $REPO $BASE <paths>"
       echo "   The token is derived from the lost lines themselves — it changes with the"
       echo "   content, so a previously-used ack will not clear a different loss."
       exit 1
     fi
     if ! printf '%s' "$ACK" | grep -q "LOSS-$TOKEN"; then
       echo "❌ DELETIONS — ack does not carry THIS run's token (expected LOSS-$TOKEN)."
       echo "   An ack from an earlier run acknowledges earlier content. Re-read the list above."
       exit 1
     fi
     # ⚠️ `.{20,}` alone passes on 20 spaces. Require 20 NON-space characters — the point
     # is a stated reason, and whitespace states nothing.
     if [ "$(printf '%s' "$ACK" | sed "s/LOSS-$TOKEN//" | tr -cd '[:graph:]' | wc -c | tr -d ' ')" -lt 20 ]; then
       echo "❌ DELETIONS — token present but no substantive reason."
       echo "   Name the removed content, not the fact of removal. The token proves you saw"
       echo "   the list; the prose proves you decided about it."
       exit 1
     fi
     echo "⚠️  DELETIONS acknowledged — proceeding (recorded, not silent)"
     echo "    token: LOSS-$TOKEN"
     echo "    ack: $ACK"
     exit 0 ;;
esac
