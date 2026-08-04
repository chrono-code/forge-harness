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
echo "── matcher located in the subject"

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
    [ "$(grep -c "$(date +%Y-%m-%d)" "$T/hub/tracks/_meta/.subagent_dispatch_tally" 2>/dev/null || echo 0)" -ge 1 ]
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
    TODAY=NOSUCHDATE; TALLY='$CHECK'; LOG='$CHECK'
    $line
    printf %s \"\$$var\"" 2>/dev/null
}
for _v in DISPATCHED LOGGED; do
  _got=$(_eval_subject_assign "$_v")
  [ "$(printf %s "$_got" | grep -c '')" -le 1 ] ; chk $? "subject's \$$_v is ONE line on a zero match (was two: the disarm)"
  ( set -uo pipefail; [ "${_got:-x}" -eq 0 ] ) 2>/dev/null ; chk $? "subject's \$$_v survives \`[ -eq 0 ]\` (the disarm threw here)"
done

echo ""
if [ "$FAILED" -ne 0 ]; then echo "DISPATCH-LOG LANES: FAIL"; exit 1; fi
echo "DISPATCH-LOG LANES: PASS ($PASS/$PASS)"
exit 0
