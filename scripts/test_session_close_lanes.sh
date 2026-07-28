#!/usr/bin/env bash
# test_session_close_lanes.sh — known-pair anchor for session_close_check.sh ② (harvest-loop
# obligation) and ⑤ (card-last invariant).
#
# WHY (2026-07-28): ② used to be an UNSATISFIABLE warning — it fired whenever an FH asset was
# touched today and the script had no way to observe whether harvest-loop ran, so no session could
# ever discharge it. A line that fires on every healthy close is noise, and noise trains the runner
# to skim past the ❌ lines that matter. The repair gave it a mechanical discharge (a harvest-loop
# decision recorded in TODAY's fh_completed file). This file is that repair's regression anchor:
# the fix is only real if the ⚠️ still fires when NOTHING is recorded, and stops firing when it is.
#
# Lanes (each is a decision the gate must get right, not a smoke test):
#   ②-N   FH asset touched today, no harvest-loop line anywhere  → ⚠️  MUST fire
#   ②-P1  same, plus "harvest-loop 실행 완료"                     → ✅  must NOT fire
#   ②-P2  same, plus an explicit SKIP note                        → ✅  must NOT fire
#         (CLAUDE.md ② accepts "harvest-loop (or an explicit skip note)" — a recorded skip is
#          a discharged obligation, not an evaded one)
#   ②-C   no FH asset touched today                               → neither line appears at all
#         (over-firing is a defect in its own right — the whole reason this repair exists)
#   ⑤-N   a close artifact newer than the card                    → ❌ card-last MUST fire (exit 1)
#   ⑤-P   card is the newest artifact                             → ✅ card-last holds
#
# Exit 0 = 7/7 lanes calibrated · exit 1 = the gate's instrument is wrong (do not trust its verdict)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/session_close_check.sh"
TODAY=$(date +%Y-%m-%d)
FAILED=0

if [ ! -f "$CHECK" ]; then
  echo "FAIL  session-close lanes: subject $CHECK missing"
  exit 1
fi

# Builds a throwaway repo whose HEAD commit touches (or does not touch) an FH asset path.
_fixture() {  # $1=touch_fh_asset(0/1)  $2=completed-file body (empty = no file)
  local touch_fh="$1" body="$2" T
  T=$(mktemp -d)
  ( cd "$T" \
    && git init -q . \
    && git config user.email anchor@local && git config user.name anchor \
    && if [ "$touch_fh" = 1 ]; then echo x > CLAUDE.md; else echo x > unrelated.txt; fi \
    && git add -A && git commit -qm "fixture" ) >/dev/null 2>&1
  mkdir -p "$T/tracks/_meta"
  [ -n "$body" ] && printf '%s\n' "$body" > "$T/tracks/_meta/fh_completed_${TODAY}.md"
  printf '# card\n' > "$T/tracks/_meta/reference_next_session_starter.md"
  printf '%s' "$T"
}

_lane() {  # $1=name  $2=grep-pattern  $3=expect(0/1)  $4=fixture dir
  local name="$1" pat="$2" expect="$3" T="$4" out hit
  out=$(bash "$CHECK" "$T" 2>/dev/null)
  hit=0
  printf '%s\n' "$out" | grep -q "$pat" && hit=1
  rm -rf "$T"
  if [ "$hit" = "$expect" ]; then
    echo "✅ $name (hit=$hit, expected=$expect)"
  else
    echo "❌ $name — hit=$hit, expected=$expect"
    printf '%s\n' "$out" | sed 's/^/     /'
    FAILED=1
  fi
}

WARN2='⚠️  ② FH assets changed today'
OK2='✅ ② FH assets changed today'

_lane "②-N  no harvest-loop decision recorded → warns" "$WARN2" 1 "$(_fixture 1 '- 항목 하나')"
_lane "②-P1 harvest-loop run recorded → silent"        "$WARN2" 0 "$(_fixture 1 '- harvest-loop 실행 완료')"
_lane "②-P2 explicit skip note → silent"               "$WARN2" 0 "$(_fixture 1 '- harvest-loop: skipped — 3-repo session, deferred')"
_lane "②-P1 run recorded → prints the ✅ form"          "$OK2"   1 "$(_fixture 1 '- harvest-loop 실행 완료')"
_lane "②-C  no FH asset touched → no ② line at all"    ' ② '    0 "$(_fixture 0 '- 항목 하나')"

# ⑤ card-last: an artifact newer than the card is the bug class the invariant exists to catch.
T=$(_fixture 1 '- harvest-loop 실행 완료')
touch "$T/tracks/_meta/fh_completed_${TODAY}.md"   # make it strictly newer than the card
if bash "$CHECK" "$T" >/dev/null 2>&1; then
  echo "❌ ⑤-N  artifact newer than card → expected exit 1, got 0 (card-last not enforced)"
  FAILED=1
else
  echo "✅ ⑤-N  artifact newer than card → exit 1 (card-last enforced)"
fi
touch "$T/tracks/_meta/reference_next_session_starter.md"   # card becomes newest
if bash "$CHECK" "$T" >/dev/null 2>&1; then
  echo "✅ ⑤-P  card newest → exit 0"
else
  echo "❌ ⑤-P  card newest → expected exit 0, got 1 (over-blocking: trains --no-verify)"
  bash "$CHECK" "$T" 2>&1 | sed 's/^/     /'
  FAILED=1
fi
rm -rf "$T"

if [ "$FAILED" -ne 0 ]; then
  echo "SESSION-CLOSE LANES: FAIL — the gate's instrument is miscalibrated"
  exit 1
fi
echo "SESSION-CLOSE LANES: PASS (7/7)"
exit 0
