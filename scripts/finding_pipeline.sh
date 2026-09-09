#!/usr/bin/env bash
# finding_pipeline.sh — the driver that runs fleet → cross-family reject → drop audit end to end.
# Until this file the two halves existed but nothing called them together outside the lane suite.
#
#   bash scripts/finding_pipeline.sh <target-file> --out <dir> [--fleet <table>]
#
# WHY THE TWO-SPLIT SHAPE (the load-bearing design decision, not an implementation detail):
# finding_verify.py refuses to let a family judge its own findings — it stamps them `unverified`
# rather than judging. With a two-family fleet, ONE verify pass therefore leaves half the findings
# unjudged, and an `unverified` finding still counts as a survivor. Running it that way and reporting
# the survivor count would silently mean "half of these were never checked". So the run is split by
# producer:
#     gemini-produced  → verifier codex  → drop auditor gemini
#     codex-produced   → verifier gemini → drop auditor codex
#
# 🟥 NAMED RESIDUAL — with only two families the drop auditor is ALWAYS the producer (an appeal),
# never a disinterested third party. That is weaker than the protocol allows for, and it is a property
# of the panel size. Do not read `AUDITED` from a two-family run as `independently audited`; the
# per-finding `audit_role` field says which it was.
# 🟥 AND A THIRD FAMILY DOES NOT COME FOR FREE. An earlier draft of this comment claimed the driver
# "picks up a third family automatically". It cannot: finding_verifier.sh only speaks codex|gemini, so
# an unknown family exits 2 and the drops come back unaudited (rc=4). Routing is therefore restricted
# to families the wrapper actually implements — SUPPORTED below — and adding one means adding a
# backend there first. (cross-family review, 2026-09-09; the claim was mine and was wrong.)
#
# EXIT  0 every split verified and every drop audited, with survivors · 1 verified but nothing survived
#       2 usage / schema · 3 UNVERIFIED — some split was not cross-verified (degraded, never a silent
#       pass) · 4 drops happened that were never audited
set -uo pipefail

SUPPORTED_FAMILIES="codex gemini"          # must match finding_verifier.sh's own case statement

TARGET=""; OUT=""; FLEET=""
usage() { echo "usage: finding_pipeline.sh <target-file> --out <dir> [--fleet <table>]" >&2; exit 2; }
need() { [ $# -ge 2 ] || { echo "finding_pipeline: $1 needs a value" >&2; exit 2; }; }
[ $# -ge 1 ] || usage
TARGET="$1"; shift
while [ $# -gt 0 ]; do
  case "$1" in
    --out)   need "$@"; OUT="$2"; shift 2 ;;    # `shift 2` on a trailing flag consumes nothing and
    --fleet) need "$@"; FLEET="$2"; shift 2 ;;  # spins forever; codex reproduced the hang.
    *) usage ;;
  esac
done
[ -n "$TARGET" ] && [ -f "$TARGET" ] && [ -r "$TARGET" ] \
  || { echo "finding_pipeline: target must be a readable file" >&2; exit 2; }
# 🟥 타깃이 심링크면 체크아웃 «밖»을 가리킬 수 있고, 그 내용은 외부 모델로 전송된다.
#    리뷰하려던 것은 레포 코드인데 나가는 것은 남의 비밀이 된다 — residency 위반이다.
#    강행이 필요하면 실제 파일 경로를 직접 주면 된다(그 판단은 사람이 한다).
if [ -L "$TARGET" ]; then
  echo "finding_pipeline: target is a symlink — refusing (it may point outside the checkout, and the content is SENT to an external model)" >&2
  exit 2
fi
[ -n "$OUT" ] || usage
# 🟥 출력물은 프롬프트와 소스를 담는다 — 권한을 좁혀서 만든다(umask 022 면 0644 로 남는다).
umask 077
mkdir -p "$OUT" || { echo "finding_pipeline: cannot create --out" >&2; exit 2; }
# 🟥 미리 깔린 심링크를 따라가면 «출력»이 남의 파일 truncate 가 된다. 리다이렉션도 open() 도
#    심링크를 따라간다 — 그래서 쓰기 «전»에 거부한다(cross-family review 2026-09-09).
for _p in "$OUT" "$OUT/fleet" "$OUT/confirmed.jsonl" "$OUT/dropped.jsonl" "$OUT/splits.txt" "$OUT/families.txt"; do
  if [ -L "$_p" ]; then
    echo "finding_pipeline: refusing to write through a symlink: $_p" >&2; exit 2
  fi
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLEET_SH="$HERE/finding_fleet.sh"; VERIFY_PY="$HERE/finding_verify.py"; VERIFIER_SH="$HERE/finding_verifier.sh"
for f in "$FLEET_SH" "$VERIFY_PY" "$VERIFIER_SH"; do
  [ -f "$f" ] || { echo "finding_pipeline: missing $f — skipped, NOT passed" >&2; exit 3; }
done

# 🟥 NO SHELL IN THIS PATH. An earlier version built a command STRING and quoted the interpolated
# path with bash's `printf %q`. That was not enough, and the reason matters: finding_verify.py ran
# the string with `shell=True`, i.e. `/bin/sh`, while `%q` emits **bash-only** `$'...'` quoting for a
# path containing a newline. On the many Linux systems where `/bin/sh` is dash, that quoting comes
# apart and a crafted filename executes a second command. 🟥 macOS CANNOT SEE THIS — its /bin/sh is
# bash-derived, so the local run is green while the shipped package is not (cross-family review
# 2026-09-09, reproduced on dash). The fix is not better escaping; it is handing argv, never a string.
argv_json() {  # each argument becomes one JSON string — no shell ever parses these
  ARGV_PY="$*" /usr/bin/python3 -c 'import json,os,sys; print(json.dumps(sys.argv[1:]))' "$@"
}

# ── 1. fleet ──────────────────────────────────────────────────────────────────────────────────────
# A reused --out is not a fresh run: finding_fleet.sh concatenates EVERY part_*.jsonl it finds, so a
# member that is absent this time still contributes yesterday's findings — which can silently supply
# the second family and make a single-family run look cross-verified.
/bin/rm -rf "$OUT/fleet"
FA=(); [ -n "$FLEET" ] && FA=(--fleet "$FLEET")
bash "$FLEET_SH" "$TARGET" --out "$OUT/fleet" ${FA[@]+"${FA[@]}"} 2>&1 | tee "$OUT/fleet_run.log"
FLEET_RC=${PIPESTATUS[0]}
FINDINGS="$OUT/fleet/findings.jsonl"
if [ "$FLEET_RC" -ne 0 ] || [ ! -s "$FINDINGS" ]; then
  echo "PIPELINE target=$(basename "$TARGET") fleet_rc=$FLEET_RC findings=0 status=UNREVIEWED"
  echo "  🟥 an empty finding list is UNREVIEWED, not clean (finding_fleet.sh says so and this agrees)" >&2
  exit 3
fi
# A fleet is "ok" when ONE member succeeded. A member that crashed after emitting a few findings still
# leaves its family present, so the split routing below sees two families and the run looks complete.
FAILED_MEMBERS=$(grep -c '^MEMBER .* rc=[^0]' "$OUT/fleet_run.log" 2>/dev/null); FAILED_MEMBERS=${FAILED_MEMBERS:-0}

# ── 2. split by producer, verify each half with the other family ──────────────────────────────────
# Families are read into a newline-delimited list and validated. An unquoted space-joined expansion
# let a family literally named "codex gemini" split into two names that match no record, skipping
# every finding while the run still exited 0.
/usr/bin/python3 -c '
import json,re,sys
seen=[]
for l in open(sys.argv[1],encoding="utf-8"):
    l=l.strip()
    if not l: continue
    f=json.loads(l).get("producer_family")
    if f is None: continue
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", str(f)):
        sys.stderr.write("finding_pipeline: illegal producer_family %r — refusing to route\n" % (f,))
        sys.exit(2)
    if f not in seen: seen.append(f)
print("\n".join(seen))' "$FINDINGS" > "$OUT/families.txt" 2>"$OUT/families.err"
FAMRC=$?
if [ "$FAMRC" -ne 0 ] || [ ! -s "$OUT/families.txt" ]; then
  cat "$OUT/families.err" >&2
  echo "finding_pipeline: findings carry no usable producer_family — cannot route" >&2; exit 3
fi

supported() { case " $SUPPORTED_FAMILIES " in *" $1 "*) return 0;; *) return 1;; esac; }
pick_verifier() { # $1=producer — a DIFFERENT family the wrapper can actually run
  local p="$1" f
  while IFS= read -r f; do [ -n "$f" ] && [ "$f" != "$p" ] && supported "$f" && { echo "$f"; return; }; done < "$OUT/families.txt"
  echo ""
}
pick_auditor() { # $1=producer $2=verifier — prefer a third party; fall back to producer (appeal)
  local p="$1" v="$2" f
  while IFS= read -r f; do
    [ -n "$f" ] && [ "$f" != "$p" ] && [ "$f" != "$v" ] && supported "$f" && { echo "$f"; return; }
  done < "$OUT/families.txt"
  supported "$p" && { echo "$p"; return; }
  echo ""
}

# Exit codes are TYPES, not severities — `max(0,1)` turned "one split found nothing" into the whole
# run's verdict while a confirmed survivor sat in the other split. Rank them explicitly instead, and
# derive 1-vs-0 from the survivor count at the end, never from a split.
WORST_RANK=0; WORST_CODE=0
rank_of() { case "$1" in 2) echo 4;; 3) echo 3;; 4) echo 2;; *) echo 0;; esac; }
note_rc() { local r; r=$(rank_of "$1"); if [ "$r" -gt "$WORST_RANK" ]; then WORST_RANK="$r"; WORST_CODE="$1"; fi; }

: > "$OUT/confirmed.jsonl"; : > "$OUT/dropped.jsonl"; : > "$OUT/splits.txt"

while IFS= read -r PROD; do
  [ -n "$PROD" ] || continue
  VER="$(pick_verifier "$PROD")"
  if [ -z "$VER" ]; then
    echo "  ⚠️  split producer=$PROD — no other SUPPORTED family present; its findings cannot be cross-verified" >&2
    note_rc 3; printf 'split producer=%s verifier=NONE rc=3 (no cross-family)\n' "$PROD" >> "$OUT/splits.txt"; continue
  fi
  AUD="$(pick_auditor "$PROD" "$VER")"
  SD="$OUT/split_$PROD"
  mkdir -p "$SD" || { echo "finding_pipeline: cannot create $SD" >&2; note_rc 2; continue; }
  # An extraction that FAILS and an extraction that finds nothing are not the same event; the first
  # draft's `[ -s ] || continue` read both as "empty partition" and left WORST at 0.
  if ! /usr/bin/python3 -c '
import json,sys
prod=sys.argv[2]
for l in open(sys.argv[1],encoding="utf-8"):
    l=l.strip()
    if l and json.loads(l).get("producer_family")==prod: print(l)' "$FINDINGS" "$PROD" > "$SD/in.jsonl"; then
    echo "finding_pipeline: split extraction failed for producer=$PROD" >&2; note_rc 3; continue
  fi
  if [ ! -s "$SD/in.jsonl" ]; then
    printf 'split producer=%s verifier=%s rc=0 (no findings)\n' "$PROD" "$VER" >> "$OUT/splits.txt"; continue
  fi

  AUDARGS=()
  if [ -n "$AUD" ]; then
    AUDARGS=(--audit-verifier-argv "$(argv_json bash "$VERIFIER_SH" --family "$AUD" --target "$TARGET" --audit)" --audit-family "$AUD")
  else
    echo "  ⚠️  split producer=$PROD — no supported auditor; any drop will come back UNAUDITED" >&2
  fi
  /usr/bin/python3 "$VERIFY_PY" "$SD/in.jsonl" --out "$SD" \
    --verifier-argv "$(argv_json bash "$VERIFIER_SH" --family "$VER" --target "$TARGET")" --family "$VER" \
    ${AUDARGS[@]+"${AUDARGS[@]}"} > "$SD/summary.txt" 2>"$SD/err.txt"
  RC=$?
  note_rc "$RC"
  cat "$SD/summary.txt"
  printf 'split producer=%s verifier=%s auditor=%s rc=%s\n' "$PROD" "$VER" "${AUD:-NONE}" "$RC" >> "$OUT/splits.txt"
  [ -f "$SD/confirmed.jsonl" ] && cat "$SD/confirmed.jsonl" >> "$OUT/confirmed.jsonl"
  [ -f "$SD/dropped.jsonl" ]   && cat "$SD/dropped.jsonl"   >> "$OUT/dropped.jsonl"
done < "$OUT/families.txt"

# 🟥 NOT `$(grep -c ... || echo 0)`: grep -c PRINTS "0" and ALSO exits 1 on no match, so the fallback
# appends a second line and the count becomes "0\n0", which truncates the summary printf.
count_lines() { local n; n=$(grep -c "$1" "$2" 2>/dev/null); printf '%s' "${n:-0}" | tr -d ' \n'; }
TOTAL_CONF=$(count_lines '^{' "$OUT/confirmed.jsonl")
TOTAL_DROP=$(count_lines '^{' "$OUT/dropped.jsonl")
TOTAL_UNVER=$(count_lines '"verdict": *"unverified"' "$OUT/confirmed.jsonl")
# An `unaudited` drop is NOT an audited one — counting it as such is how "we checked the deletions"
# becomes true by wording alone.
TOTAL_AUD=$(count_lines '"drop_verdict": *"\(correct-drop\|wrong-drop\|uncertain\)"' "$OUT/dropped.jsonl")
TOTAL_WRONG=$(count_lines '"reinstated": *true' "$OUT/confirmed.jsonl")

if [ "$FAILED_MEMBERS" -gt 0 ]; then
  echo "  ⚠️  $FAILED_MEMBERS fleet member(s) exited non-zero — a member that crashed after emitting some findings leaves its family looking complete" >&2
  note_rc 3
fi

RC_FINAL="$WORST_CODE"
[ "$WORST_RANK" -eq 0 ] && [ "$TOTAL_CONF" -eq 0 ] && RC_FINAL=1

printf 'PIPELINE target=%s families=%s confirmed=%s dropped=%s unverified=%s audited_drops=%s reinstated=%s failed_members=%s rc=%s\n' \
  "$(basename "$TARGET")" "$(tr '\n' ',' < "$OUT/families.txt" | sed 's/,$//')" "$TOTAL_CONF" "$TOTAL_DROP" \
  "$TOTAL_UNVER" "$TOTAL_AUD" "$TOTAL_WRONG" "$FAILED_MEMBERS" "$RC_FINAL"
# `unverified` is reported on its own line rather than folded into `confirmed`, because folding it is
# exactly the "not found rendered as zero" family this repo keeps re-finding.
exit "$RC_FINAL"
