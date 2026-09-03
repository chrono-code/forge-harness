#!/usr/bin/env bash
# test_proposal_hook_lanes.sh — known pairs for scripts/proposal_hook.sh (written before shipping; r4 KP + Bash path)
set -u; HDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T=$(mktemp -d); pass=0; fail=0
export CLAUDE_PROJECT_DIR="$T"
exp(){ local label="$1" want="$2" payload="$3" got; got=$(printf '%s' "$payload" | bash "$HDIR/proposal_hook.sh" 2>/dev/null | wc -c | tr -d ' '); [ "$got" -gt 0 ] && got=HIT || got=CLEAN
  if [ "$got" = "$want" ]; then printf '  ✅ %-52s %s\n' "$label" "$got"; pass=$((pass+1)); else printf '  ❌ %-52s %s (expected %s)\n' "$label" "$got" "$want"; fail=$((fail+1)); fi; }
echo "[proposal-hook] known pairs"
exp "T1 Edit comm+LC_ALL (verdict compare)"   HIT   '{"tool_name":"Edit","tool_input":{"file_path":"/x/scripts/sim_isolated_run.sh","old_string":"  comm -13 <(sort a) <(sort b) \\","new_string":"  comm -13 <(LC_ALL=C sort a) <(LC_ALL=C sort b) \\"}}'
exp "T2 Edit adds fail-open guard"            HIT   '{"tool_name":"Edit","tool_input":{"file_path":"/x/scripts/capability_effect_probe.sh","old_string":"  h=$(ls -A \"$HOME\" | shasum)","new_string":"  h=$(ls -A \"$HOME\" | shasum) || { echo LS_FAILED; exit 10; }"}}'
exp "T3 Edit continue guard"                  HIT   '{"tool_name":"Edit","tool_input":{"file_path":"/x/templates/regression_guard.sh","old_string":"      [ -e \"$blk\" ] && [ -s \"$blk\" ] || continue","new_string":"      [ -e \"$blk\" ] || { echo missing >&2; continue; }"}}'
exp "HARD Edit usage string only (r4 0/5)"    CLEAN '{"tool_name":"Edit","tool_input":{"file_path":"/x/scripts/daily_report.sh","old_string":"  *) echo \"usage: d.sh [run]\" >&2; exit 2 ;;","new_string":"  *) echo \"usage: d.sh [run|--self-test] (DR_DATE)\" >&2; exit 2 ;;"}}'
exp "docs file with tokens"                   CLEAN '{"tool_name":"Edit","tool_input":{"file_path":"/x/docs/a.md","old_string":"a","new_string":"exit 1 || continue"}}'
exp "Write new scripts/*.sh with verdict"     HIT   '{"tool_name":"Write","tool_input":{"file_path":"/x/scripts/new_check.sh","content":"#!/bin/bash\n[ -f x ] || exit 1"}}'
exp "Bash sed -i on scripts/*.sh with token"  HIT   '{"tool_name":"Bash","tool_input":{"command":"sed -i \"\" \"s/comm -13/LC_ALL=C comm -13/\" scripts/sim_isolated_run.sh && [ -s out ] || exit 1"}}'
exp "Bash redirect into scripts/*.sh w/ token" HIT  '{"tool_name":"Bash","tool_input":{"command":"printf \"%s\\n\" x >> scripts/x.sh; grep -q y scripts/x.sh || exit 3"}}'
exp "Bash redirect into docs (no)"            CLEAN '{"tool_name":"Bash","tool_input":{"command":"echo \"exit 1\" >> docs/a.md || exit 1"}}'
exp "Bash ls only (no target)"                CLEAN '{"tool_name":"Bash","tool_input":{"command":"ls scripts/ && [ -d scripts ] || exit 1"}}'
exp "noqa exempts"                            CLEAN '{"tool_name":"Edit","tool_input":{"file_path":"/x/scripts/a.sh","old_string":"a","new_string":"exit 1  # noqa: proposal-hook"}}'
exp "unparseable payload silent"              CLEAN 'not json'
[ -f "$T/.claude/.proposal_hook_events.tsv" ] && [ "$(grep -c FIRE "$T/.claude/.proposal_hook_events.tsv")" -ge 5 ]; r=$?; [ $r = 0 ] && { echo "  ✅ evidence file carries a FIRE row per hit"; pass=$((pass+1)); } || { echo "  ❌ evidence file missing/short"; fail=$((fail+1)); }
rm -rf "$T"; echo "[proposal-hook] $pass passed, $fail failed"; [ "$fail" -eq 0 ]
