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
exp "Bash sed -i token ONLY inside quotes (a1)"  HIT   '{"tool_name":"Bash","tool_input":{"command":"sed -i \"\" \"s/exit 1/exit 2/\" scripts/target.sh"}}'
exp "Bash sed -i single-quoted token (a1b)"      HIT   '{"tool_name":"Bash","tool_input":{"command":"sed -i '"'"''"'"' '"'"'s/|| continue/|| { echo x; continue; }/'"'"' scripts/target.sh"}}'
exp "Bash sed -i no token anywhere (a3)"         CLEAN '{"tool_name":"Bash","tool_input":{"command":"sed -i \"\" s/foo/bar/ scripts/target.sh"}}'
exp "Bash redirect into scripts/*.sh w/ token" HIT  '{"tool_name":"Bash","tool_input":{"command":"printf \"[ -f x ] || exit 1\\n\" >> scripts/x.sh; grep -q y scripts/x.sh"}}'
exp "Bash redirect into docs (no)"            CLEAN '{"tool_name":"Bash","tool_input":{"command":"echo \"exit 1\" >> docs/a.md || exit 1"}}'
exp "Bash ls only (no target)"                CLEAN '{"tool_name":"Bash","tool_input":{"command":"ls scripts/ && [ -d scripts ] || exit 1"}}'
# ── 2026-09-04 계기 교체 lanes — fixtures are the SHAPES the first independent grading quoted
#    (tracks/_meta/RESULT_2026-09-04_identity5-armC-live-count.md §계기 결함), not easier spellings.
#    Fail-before: the HEAD~ hook (whole-command regex) is HIT on R2/R3/R4-ctrl/D3-*/D4 and CLEAN on D2-* (recorded in
#    proposal_hook_repair_lanes.txt for the patch); the scanner hook inverts exactly those.
exp "R2 marker heredoc QUOTES sed -i … scripts/target.sh (row 2)" CLEAN '{"tool_name":"Bash","tool_input":{"command":"cat > tracks/_meta/.axes_23_2026-09-03.marker <<'"'"'MK'"'"'\naxes-run: ⓐ ⓑ\na1 `sed -i '"'"''"'"' '"'"'s/exit 1/exit 2/'"'"' scripts/target.sh` → HIT · lanes 16/16 · [ -s x ] || exit 1\nMK"}}'
exp "R3 gh pr --body QUOTES sed -i … scripts/target.sh (row 3)"  CLEAN '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title \"fix(hook): a1\" --body \"Lanes: a1 `sed -i '"'"''"'"' '"'"'s/exit 1/exit 2/'"'"' scripts/target.sh` now HIT; 16/16 · revert 14/16 || exit 1\""}}'
exp "R4-ctrl : > \"\$T/scripts/…\" fixture root (var path)"      CLEAN '{"tool_name":"Bash","tool_input":{"command":"mkdir -p \"$T/scripts\"; : > \"$T/scripts/test_has_lane_lanes.sh\"; [ -f x ] || exit 1"}}'
exp "D2-P python heredoc open(p,\"w\") verdict edit (8746)"      HIT   '{"tool_name":"Bash","tool_input":{"command":"python3 - <<'"'"'PY'"'"'\np=\"scripts/package_coverage_check.sh\"\ns=open(p).read()\nassert s.count(\"  exit 2\") == 1\ns=s.replace(\"  exit 2\", \"  echo \\\"PKG_ORACLE_MISSING: npm pack gave no files[]\\\" >&2; exit 2\")\nopen(p,\"w\").write(s)\nPY"}}'
exp "D2-P2 python heredoc q=Path(…); q.write_text (verdict)"     HIT   '{"tool_name":"Bash","tool_input":{"command":"python3 - <<'"'"'PY'"'"'\nfrom pathlib import Path\nq=Path(\"scripts/selfcheck.sh\")\nq.write_text(q.read_text().replace(\"run_lane x\", \"run_lane x || exit 1\"))\nPY"}}'
exp "D2-ctrl python heredoc comment-word replace (== in code only)" CLEAN '{"tool_name":"Bash","tool_input":{"command":"python3 - <<'"'"'PY'"'"'\np=\"scripts/sim_isolated_run.sh\"\ns=open(p).read()\nassert s.count(\"# 옛말\") == 1\ns=s.replace(\"# 옛말\", \"# 조직\")\nopen(p,\"w\").write(s)\nPY"}}'
exp "D3 row 6: sed comment word + || exit 1 in another segment"  CLEAN '{"tool_name":"Bash","tool_input":{"command":"sed -i '"'"''"'"' '"'"'s/옛말/조직/g'"'"' scripts/sim_isolated_run.sh && bash scripts/test_sim_isolated_run_lanes.sh; rc=$?; [ $rc = 0 ] || exit 1"}}'
exp "D3 row 1: self-probe sed (no token in expr) + [ -s ] || exit 1" CLEAN '{"tool_name":"Bash","tool_input":{"command":"sed -i '"'"''"'"' '"'"'s/^#NOOP-PROBE-LINE$//'"'"' scripts/proposal_hook.sh && [ -s scripts/proposal_hook.sh ] || exit 1; tail -1 .claude/.proposal_hook_events.tsv"}}'
exp "D4 old shape: payload w/o token, check in next segment"      CLEAN '{"tool_name":"Bash","tool_input":{"command":"printf \"%s\\n\" x >> scripts/x.sh; grep -q y scripts/x.sh || exit 3"}}'
exp "H1 cat > scripts/new.sh <<EOF body carries token"           HIT   '{"tool_name":"Bash","tool_input":{"command":"cat > scripts/new_lane.sh <<'"'"'EOF'"'"'\n#!/usr/bin/env bash\n[ -f x ] || exit 1\nEOF"}}'
exp "H2 cat <<EOF > \"scripts/q.sh\" (quoted target after >)"    HIT   '{"tool_name":"Bash","tool_input":{"command":"cat <<'"'"'EOF'"'"' > \"scripts/q.sh\"\nexit 1\nEOF"}}'
exp "H3 printf | tee -a scripts/t.sh"                            HIT   '{"tool_name":"Bash","tool_input":{"command":"printf \"exit 1\\n\" | tee -a scripts/t.sh"}}'
# R4 proper: the real edit is a python heredoc whose CONTENT quotes `: > "$T/scripts/test_has_lane_lanes.sh"` — the hook
# must record the file the python writes, not the fixture root inside the string (row 4 recorded `$T/scripts/…`).
R4='{"tool_name":"Bash","tool_input":{"command":"python3 - <<'"'"'PY'"'"'\np=\"scripts/test_proposal_hook_lanes.sh\"\ns=open(p).read()\ns=s.replace(\"exp \\\"noqa\", \"mkdir -p \\\"$T/scripts\\\"; : > \\\"$T/scripts/test_has_lane_lanes.sh\\\"; [ -f x ] || exit 1; exp \\\"noqa\")\nopen(p,\"w\").write(s)\nPY"}}'
printf '%s' "$R4" | bash "$HDIR/proposal_hook.sh" >/dev/null 2>&1; r4fp=$(tail -1 "$T/.claude/.proposal_hook_events.tsv" 2>/dev/null | cut -f3)
if [ "$r4fp" = "scripts/test_proposal_hook_lanes.sh" ]; then printf '  ✅ %-52s fp=%s\n' "R4 python heredoc → recorded fp is the WRITTEN file" "$r4fp"; pass=$((pass+1)); else printf '  ❌ %-52s fp=%s (expected scripts/test_proposal_hook_lanes.sh)\n' "R4 python heredoc → recorded fp is the WRITTEN file" "${r4fp:-<none>}"; fail=$((fail+1)); fi
exp "G1 Edit templates/.git-hooks/pre-commit (no .sh)" HIT '{"tool_name":"Edit","tool_input":{"file_path":"/x/templates/.git-hooks/pre-commit","old_string":"  [ -f x ] || continue","new_string":"  [ -f x ] || { echo missing; PTR_FAIL=1; continue; }"}}'
exp "G1-ctrl Edit .git-hooks docs-ish no token"        CLEAN '{"tool_name":"Edit","tool_input":{"file_path":"/x/templates/.git-hooks/pre-commit","old_string":"# note a","new_string":"# note b"}}'
exp "noqa exempts"                            CLEAN '{"tool_name":"Edit","tool_input":{"file_path":"/x/scripts/a.sh","old_string":"a","new_string":"exit 1  # noqa: proposal-hook"}}'
exp "unparseable payload silent"              CLEAN 'not json'
msg(){ printf '%s' "$2" | bash "$HDIR/proposal_hook.sh" 2>/dev/null; }
fact(){ local label="$1" want="$2" payload="$3" got; got=$(msg x "$payload"); if printf '%s' "$got" | grep -q -- "$want"; then printf '  ✅ %-52s carries «%s»\n' "$label" "$want"; pass=$((pass+1)); else printf '  ❌ %-52s missing «%s»\n' "$label" "$want"; fail=$((fail+1)); fi; }
mkdir -p "$T/scripts"; : > "$T/scripts/test_has_lane_lanes.sh"; printf 'scan of scripts/covered.sh\nfindings: 0\n' > "$T/scripts/.degrade_scan_last_2026-09-03.txt"
E='{"tool_name":"Edit","tool_input":{"file_path":"/x/scripts/%s","old_string":"a","new_string":"[ -f x ] || exit 1"}}'
fact "F1 lane exists → fact line, no known-pair item" "이미 있다" "$(printf "$E" has_lane.sh)"
fact "F1b lane exists → scan item still proposed"     "degrade_direction_scan.sh 로" "$(printf "$E" has_lane.sh)"
fact "F2 self-lane (test_*_lanes.sh) → fact line"     "이 파일 자체가 레인" "$(printf "$E" test_has_lane_lanes.sh)"
fact "F3 scan covers file → fact line w/ findings"    "findings: 0" "$(printf "$E" covered.sh)"
fact "F4 neither → both items proposed"               "known-pair(고친 케이스 + 반대 케이스) 컨트롤 degrade_direction_scan.sh" "$(printf "$E" bare.sh)"
got=$(msg x "$(printf "$E" bare.sh)"); if printf '%s' "$got" | grep -q "사실:"; then echo "  ❌ F4-ctrl bare file must carry NO fact line"; fail=$((fail+1)); else echo "  ✅ F4-ctrl bare file carries no fact line (known-negative)"; pass=$((pass+1)); fi
[ -f "$T/.claude/.proposal_hook_events.tsv" ] && [ "$(grep -c FIRE "$T/.claude/.proposal_hook_events.tsv")" -ge 5 ]; r=$?; [ $r = 0 ] && { echo "  ✅ evidence file carries a FIRE row per hit"; pass=$((pass+1)); } || { echo "  ❌ evidence file missing/short"; fail=$((fail+1)); }
rm -rf "$T"; echo "[proposal-hook] $pass passed, $fail failed"; [ "$fail" -eq 0 ]
