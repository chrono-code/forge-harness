#!/usr/bin/env bash
# test_dispatch_log_lanes.sh — known-pair anchor for session_close_check.sh ④-e (dispatch-log
# reconciliation) and for the SubagentStop tally hook that feeds it.
#
# WHY (2026-08-02): CLAUDE.md makes an invocation-log entry mandatory immediately after any custom
# sub-agent invocation — it feeds the 60/40 promotion gate and the UAP loop. Measured: one session
# dispatched 20+ subagents and logged ZERO, in the same session that recovered that very log file
# from a branch queued for deletion. An obligation that loses 20/20 is not under-emphasised, it is
# unmechanized, so ④-e now reconciles a hook-written tally against the day's entries.
#
# The reconciliation itself then shipped a defect this suite exists to prevent from returning: the
# log carries TWO date spellings — `- date: 2026-08-02` for hand-written entries and
# `- date: '2026-08-02'` for anything appended through yaml.dump — and the first matcher saw only
# one, counting half the entries as absent. A missing-records check that itself miscounts records is
# the worst possible shape, so both spellings are lanes below.
#
# Exit 0 = the reconciliation discriminates · 1 = it would mis-report.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/session_close_check.sh"
SETTINGS="$SCRIPT_DIR/../.claude/settings.json"
FAILED=0; PASS=0
chk() { if [ "$1" -eq 0 ]; then PASS=$((PASS+1)); echo "  ✅ $2"; else FAILED=1; echo "  ❌ $2"; fi; }

[ -f "$CHECK" ] || { echo "FAIL  dispatch-log lanes: subject $CHECK missing"; exit 1; }

# The matcher under test, lifted from the subject rather than re-spelled (a hand-copied predicate is
# a divergent normalizer — which is exactly the bug being anchored). If it is gone, fail loudly.
MATCHER=$(grep -oE "grep -cE \"\^- date: \*'\?\\\$TODAY'\?\"" "$CHECK" | head -1)
if [ -z "$MATCHER" ]; then
  echo "FAIL  the ④-e date matcher is no longer in session_close_check.sh in the expected form —"
  echo "      this lane cannot verify what it claims to. Update the lane WITH the subject."
  exit 1
fi
# 주어의 _cat_logs 정의를 그대로 들어온다(재작성 금지 — 재작성하면 정규화가 갈린다)
CATLOGS_DEF=$(awk '/^_cat_logs\(\) \{/,/^\}/' "$CHECK")
if [ -z "$CATLOGS_DEF" ]; then
  echo "FAIL  subject 에 _cat_logs 가 없다 — 전환 설계(레거시 ∪ 디렉터리)가 사라졌거나 이름이 바뀌었다."
  exit 1
fi
echo "── matcher located in the subject"
echo "── _cat_logs lifted from the subject ($(printf '%s' "$CATLOGS_DEF" | grep -c '') lines)"

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
D=2026-08-02

echo "── date-spelling lanes (the shipped miscount) ──"
printf -- "- date: %s\n" "$D" > "$T/plain.yaml"
printf -- "- date: '%s'\n" "$D" > "$T/quoted.yaml"
printf -- "- date: %s\n- date: '%s'\n- date: 2020-01-01\n" "$D" "$D" > "$T/both.yaml"
count() { grep -cE "^- date: *'?$D'?" "$1" 2>/dev/null | tr -d ' '; }
[ "$(count "$T/plain.yaml")"  = 1 ] ; chk $? "unquoted date counted"
[ "$(count "$T/quoted.yaml")" = 1 ] ; chk $? "yaml.dump-quoted date counted (the half the first matcher missed)"
[ "$(count "$T/both.yaml")"   = 2 ] ; chk $? "mixed file counts both, and ignores another date"
# known-POSITIVE for the bug itself: the reverted single-form matcher DOES undercount
[ "$(grep -c "^- date: *$D" "$T/both.yaml")" = 1 ] ; chk $? "known-POSITIVE: the reverted matcher undercounts (1 of 2) — the defect is real"

echo "── reconciliation verdict lanes ──"
verdict() { # $1=dispatched $2=logged -> BLOCK | OK | NONE
  if [ "$1" -gt 0 ] && [ "$2" -eq 0 ]; then echo BLOCK
  elif [ "$1" -gt 0 ]; then echo OK
  else echo NONE; fi
}
[ "$(verdict 20 0)" = BLOCK ] ; chk $? "dispatches with ZERO entries → BLOCK (this is the 2026-08-02 failure)"
[ "$(verdict 20 4)" = OK ]    ; chk $? "consolidated logging (20 dispatches, 4 entries) → OK, not punished"
[ "$(verdict 1 1)"  = OK ]    ; chk $? "1:1 logging → OK"
[ "$(verdict 0 0)"  = NONE ]  ; chk $? "no dispatches → silent, not a failure"

echo "── the tally hook that feeds it ──"
if [ -f "$SETTINGS" ]; then
  python3 - "$SETTINGS" <<'PY' >"$T/hookcmd" 2>/dev/null || true
import json,sys
d=json.load(open(sys.argv[1]))
g=d.get("hooks",{}).get("SubagentStop",[])
print(g[0]["hooks"][0]["command"] if g and g[0].get("hooks") else "")
PY
  cmd=$(cat "$T/hookcmd")
  [ -n "$cmd" ] ; chk $? "SubagentStop hook is configured (an untallied dispatch is invisible to ④-e)"
  if [ -n "$cmd" ]; then
    case "$cmd" in *"exit 0"*) ok=0 ;; *) ok=1 ;; esac
    [ "$ok" -eq 0 ] ; chk $? "hook ends in exit 0 — a non-zero hook exit discards its stdout SILENTLY"
    # run it against a scratch HUB and confirm it appends today's date
    CLAUDE_PROJECT_DIR="$T/hub" bash -c "$cmd" >/dev/null 2>&1
    # Split + sanitize, not `grep -c … || echo 0`: on no-match `grep -c` PRINTS "0" and exits 1, so
    # the fallback appends a SECOND line and `[ -ge ]` dies with "integer expression expected".
    # Here that error happens to land on the FAIL branch — honest scope: this was never a live
    # fail-open, it was a verdict reached by a bash error instead of a comparison, one refactor
    # away from flipping. Found by the S5 sweep after the rule was widened (2026-08-04).
    _tally_n=$(grep -c "$(date +%Y-%m-%d)" "$T/hub/tracks/_meta/.subagent_dispatch_tally" 2>/dev/null); _tally_n=${_tally_n:-0}
    case "$_tally_n" in (*[!0-9]*|'') _tally_n=0 ;; esac
    [ "$_tally_n" -ge 1 ]
    chk $? "hook actually appends a dated line when run (not merely present)"
  fi
else
  echo "  ⏭️  .claude/settings.json absent — hook lanes unchecked (not a pass)"
fi

echo "── absence-is-not-zero (the fail-open this fix nearly shipped) ──"
# .claude/settings.json is GITIGNORED, so a fresh clone has no hook and an empty tally. Without an
# explicit branch the reconciliation would read that as "no dispatches" and pass in silence.
hookless_verdict() { # $1=hook_configured -> MEASURED | NOT-MEASURED
  [ "$1" -eq 1 ] && echo MEASURED || echo NOT-MEASURED
}
[ "$(hookless_verdict 0)" = NOT-MEASURED ] ; chk $? "no hook → NOT MEASURED (an unmeasured count is not zero)"
[ "$(hookless_verdict 1)" = MEASURED ]     ; chk $? "hook present → measured"
grep -q "NOT MEASURED" "$CHECK" ; chk $? "the subject actually carries that branch (not just this lane)"
[ -f "$SCRIPT_DIR/../templates/subagent-tally-hook.json" ] ; chk $? "installable snippet exists for a clone that has no settings.json"

echo "── pipefail disarm (the guard was dead in EXACTLY its target case) ──"
# `grep -c` PRINTS 0 and EXITS 1 on a zero count. Under `set -o pipefail` the old
# `grep -c … | tr -d ' ' || echo 0` therefore produced "0\n0", `[ -eq ]` threw, and the ❌ branch
# was skipped — so ④-e reported ✅ whenever the log had ZERO entries, which is the one situation it
# exists to block. Measured live 2026-08-04 during a session close.
# Lane 1: reproduce the OLD form and assert it is broken (a control — if this ever passes, the
# premise changed and the fix below is measuring nothing).
old_form=$(bash -c 'set -uo pipefail; grep -c "^NOSUCHDATE$" '"$CHECK"' 2>/dev/null | tr -d " " || echo 0')
[ "$(printf %s "$old_form" | grep -c "")" -eq 2 ] ; chk $? "control: the old \`|| echo 0\` form really does yield TWO lines under pipefail"
# Lane 2: the shipped form yields a single sanitised integer.
new_form=$(bash -c 'set -uo pipefail; _int() { case "${1:-}" in (""|*[!0-9]*) echo 0 ;; (*) echo "$1" ;; esac; }; _int "$(grep -c "^NOSUCHDATE$" '"$CHECK"' 2>/dev/null | tr -d " " || true)"')
[ "$new_form" = "0" ] ; chk $? "shipped form yields a single sanitised 0"
( set -uo pipefail; [ "$new_form" -eq 0 ] ) 2>/dev/null ; chk $? "and \`[ -eq ]\` accepts it (the old form threw here)"
# Lane 3-5: BEHAVIOUR, not spelling. The first draft of these lanes string-matched the old form and
# went GREEN on a revert — the needle did not match `tr -d ' '` (quotes), so the anchor was
# decorative in the way this repo already named ([[feedback_anchor_can_be_decorative]], cause:
# "needle matching unrelated text"). Extract the subject's OWN assignment lines and evaluate them.
_eval_subject_assign() {  # $1 = variable name; echoes what the SUBJECT computes for a zero match
  local var="$1" line
  line=$(grep -E "^${var}=" "$CHECK" | head -1)
  [ -n "$line" ] || { echo "NOLINE"; return; }
  bash -c "set -uo pipefail
    _int() { case \"\${1:-}\" in (''|*[!0-9]*) echo 0 ;; (*) echo \"\$1\" ;; esac; }
    # ★ LOGGED 는 주어의 _cat_logs 에 의존한다. 이걸 안 들여오면 «함수 없음 → 빈 입력 → 0»
    #   으로 **틀린 이유로 통과**한다 — 이 파일이 경고하는 장식 앵커 그 자체다.
    $CATLOGS_DEF
    TODAY=NOSUCHDATE; TALLY='$CHECK'; LOG='$CHECK'; LOGDIR='$CHECK.nodir'
    $line
    printf %s \"\$$var\"" 2>/dev/null
}
for _v in DISPATCHED LOGGED; do
  _got=$(_eval_subject_assign "$_v")
  [ "$(printf %s "$_got" | grep -c '')" -le 1 ] ; chk $? "subject's \$$_v is ONE line on a zero match (was two: the disarm)"
  ( set -uo pipefail; [ "${_got:-x}" -eq 0 ] ) 2>/dev/null ; chk $? "subject's \$$_v survives \`[ -eq 0 ]\` (the disarm threw here)"
done

echo ""
echo "── 전환 설계 레인: 레거시 단일 파일 ∪ 세션별 디렉터리 ──"
# 주어의 _cat_logs + LOGGED 를 그대로 들어와 4가지 상태에서 센다.
LOGGED_LINE=$(grep -E "^LOGGED=" "$CHECK" | head -1)
_count_in() {  # $1=LOG 경로(없으면 빈문자) $2=LOGDIR 경로(없으면 빈문자)
  bash -c "set -uo pipefail
    _int() { case \"\${1:-}\" in (''|*[!0-9]*) echo 0 ;; (*) echo \"\$1\" ;; esac; }
    $CATLOGS_DEF
    TODAY='$D'; LOG='$1'; LOGDIR='$2'
    $LOGGED_LINE
    printf %s \"\$LOGGED\"" 2>/dev/null
}
LT="$T/split"; mkdir -p "$LT/dir"
printf -- "- date: %s\n" "$D" > "$LT/legacy.yaml"                       # 1건
printf -- "- date: %s\n- date: '%s'\n" "$D" "$D" > "$LT/dir/a.yaml"     # 2건 (두 표기 다)
printf -- "- date: %s\n" "$D" > "$LT/dir/b.yaml"                        # 1건
[ "$(_count_in "$LT/legacy.yaml" "$LT/nosuchdir")" = 1 ] ; chk $? "레거시 파일만 → 1"
[ "$(_count_in "$LT/nofile.yaml" "$LT/dir")"       = 3 ] ; chk $? "디렉터리만 → 3 (파일 2개 합산)"
[ "$(_count_in "$LT/legacy.yaml" "$LT/dir")"       = 4 ] ; chk $? "둘 다 → 4 (합집합)"
[ "$(_count_in "$LT/nofile.yaml" "$LT/nosuchdir")" = 0 ] ; chk $? "둘 다 없음 → 0 (부재는 오류가 아니다)"
# ★ 컨트롤: 다중 파일에 grep -c 를 직접 걸면 깨진다는 실측을 레인으로 고정
_naive=$(grep -cE "^- date: *'?$D'?" "$LT/dir"/*.yaml 2>/dev/null | tr -d ' \n')
[ "$_naive" != 3 ] ; chk $? "컨트롤: naive grep -c 다중파일은 3을 못 낸다 (실제='$_naive' — 경로:개수 형태)"

echo ""
if [ "$FAILED" -ne 0 ]; then echo "DISPATCH-LOG LANES: FAIL"; exit 1; fi
echo "DISPATCH-LOG LANES: PASS ($PASS/$PASS)"
exit 0
