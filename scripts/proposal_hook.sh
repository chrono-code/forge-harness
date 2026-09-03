#!/usr/bin/env bash
# proposal_hook.sh — PreToolUse(Edit|Write|Bash) advisory: a verdict/guard line in scripts/**/*.sh or
# templates/*.sh is about to change → put ONE proposal instruction into the model's context
# (additionalContext): «offer the user a known-pair control + degrade_direction_scan.sh in one line».
#
# WHY A HOOK (identity ⑤, measured 2026-09-03)
#   r3: a CLAUDE.md table row keyed on this exact file class fired 1/15 at floor tier (that 1 a
#   recitation). r4: this hook, installed in a disposable clone, fired on 9/10 editing reps and the
#   floor session relayed the proposal 9/9; the hard negative (a usage-string edit in a .sh) 0/5.
#   Same tasks, same tier, same prose layer — the row 0, the channel 100%. That is the
#   «explicit instruction 3/3 · advisory 0/3 · framing 0/3» result of 2026-08-21 seen a second time
#   (tracks/_meta/RESULT_2026-09-03_identity5-r4.md · prior_art_prompt.sh header). A channel is
#   built at the channel (§Mechanization Boundary); what the proposal SAYS stays the model's.
#
# WHAT IT DOES NOT CLAIM
#   Relaying an injected instruction is not initiative. Of r4's 9 hits, 4 carried task-specific
#   substance beyond the hook's own wording (the K1 «judgment residue» — innovator signal
#   fh_signal_2026-09-03_innovator-identity5-r4.md). This hook opens the window; whether ⑤'s bar
#   («proposes unasked») counts a relayed proposal is the operator's call, recorded there, not here.
#
# DISCRIMINATOR (mechanical, quote-aware where it can be)
#   file class  : scripts/**/*.sh · templates/*.sh          (docs, tracks, tests-as-fixtures: no)
#   edit kind   : the touched text carries a verdict/guard token — exit N · return N ·
#                 `|| continue|exit|true|return` · `&& continue|exit` · -ne/-eq/-gt/-lt · ==/!= ·
#                 `[ -e/-f/-s/-n/-z` · comm/diff/cmp · grep -q — AND for Edit the change is not
#                 confined to quoted strings (old/new with quotes stripped must differ). A usage
#                 string that happens to contain `exit 2` does not fire (r4 HARD 0/5).
#   Bash path   : an edit made through the shell (sed -i · > · >> · tee) — the r4 miss (T2 r5 edited
#                 via Bash, hook 0). No old/new here, so the rule is weaker: target file class AND the
#                 the RAW command text (quotes included) carries a token. Quotes are NOT stripped on
#                 this path — in `sed -i 's/exit 1/exit 2/' x.sh` the token is inside the quotes by
#                 construction, and stripping made the path silent on exactly the shape it exists for
#                 (found by the Air node 2026-09-03; the original lane's known-positive only fired
#                 because its token sat outside the quotes). Named residual now: over-fire when a
#                 quoted token elsewhere in the command co-occurs with a script-file edit (advisory).
#
# DEGRADE DIRECTION: advisory, exit 0 always, no permissionDecision (same contract as pipe_verdict_guard).
#   Unparseable payload → silent. python3 absent → silent (a dead interpreter must not block edits).
#   Evidence line appended to $CLAUDE_PROJECT_DIR/.claude/.proposal_hook_events.tsv (gitignored dir)
#   so a sim arm can prove the hook fired INSIDE its clone (runner header: absence of that file
#   invalidates the arm, never the hypothesis).
# Opt out on one call with `# noqa: proposal-hook`.
# test: printf '%s' '<PreToolUse JSON>' | bash scripts/proposal_hook.sh
set -u
RAW=$(cat 2>/dev/null || true)
printf '%s' "$RAW" | grep -qE '#[[:space:]]*noqa:?[[:space:]]*proposal-hook' && exit 0
read -r FP FLAG < <(printf '%s' "$RAW" | python3 -c '
import json,sys,re
try: d=json.load(sys.stdin)
except Exception: print("",""); sys.exit(0)
tn=d.get("tool_name",""); ti=d.get("tool_input",{}) or {}
TOK=r"exit [0-9]|return [0-9]|\|\| *(continue|exit|true|return)|&& *(continue|exit)|-ne |-eq |-gt |-lt | == | != |\[ -[efsnz] |\bcomm |\bdiff |\bcmp |grep -q"
def strip(x): return re.sub(r"\"[^\"]*\"|\x27[^\x27]*\x27","",x)
fp=""; flag="0"
if tn in ("Edit","Write"):
    fp=ti.get("file_path","") or ""
    old=ti.get("old_string","") or ""; new=(ti.get("new_string","") or ti.get("content","") or "")
    touches=bool(re.search(TOK, old+"\n"+new)); real=strip(old).strip()!=strip(new).strip()
    flag="1" if (touches and real) else "0"
elif tn=="Bash":
    cmd=(ti.get("command","") or "").replace("\n"," ")
    m=re.search(r"(?:sed\s+-i\S*(?:\s+(?:\x27[^\x27]*\x27|\"[^\"]*\"|\S+)){1,2}\s+|>>?\s*|tee\s+(?:-a\s+)?)[\"\x27]?([^\s\"\x27|;&)<>]+\.sh)\b", cmd)
    if m:
        fp=m.group(1); flag="1" if re.search(TOK, cmd) else "0"   # raw cmd, NOT strip(): in a sed -i the token lives INSIDE the quoted expression by construction (Air 2026-09-03: a1 silent, known-positive only fired because its token sat outside the quotes)
print(fp, flag)
' 2>/dev/null) || exit 0
[ -n "${FP:-}" ] || exit 0
case "$FP" in *scripts/*.sh|*templates/*.sh|scripts/*.sh|templates/*.sh) ;; *) exit 0 ;; esac
[ "${FLAG:-0}" = 1 ] || exit 0
_D="${CLAUDE_PROJECT_DIR:-.}/.claude"; mkdir -p "$_D" 2>/dev/null
printf '%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "FIRE" "$FP" >> "$_D/.proposal_hook_events.tsv" 2>/dev/null
# ── Fact lines (r8, 2026-09-03): the two preconditions of the proposal are DETERMINISTIC, so the hook checks
#    them itself and carries the result as a «사실» line — agents propose, solvers verify. Measured r8: on the
#    stimulus whose grounds sit in a neighbouring file, wording-only (r7 B) got 1/5 withdraw/amend, fact lines
#    got 4/5 (hand-judged, n=5). Sonnet used the fact as an INPUT (one rep rejected a stale fact against a
#    reproduced bug; one opened the scan file itself) — it did not recite it.
#    Self-lane case: editing `scripts/test_X_lanes.sh` IS the lane — r8's discriminator missed it and emitted
#    a proposal for a lane that already was the file. Fixed here (F2 lane).
_ROOT="${CLAUDE_PROJECT_DIR:-.}"; _BN=$(basename "$FP" .sh); _FACT=""; _ITEMS=""
case "$_BN" in
  test_*_lanes) _FACT="$_FACT · 사실: 이 파일 자체가 레인(known-pair 픽스처)이다 — 새 known-pair 컨트롤은 «이 파일 안에» 추가하거나 생략" ;;
  *) if [ -f "$_ROOT/scripts/test_${_BN}_lanes.sh" ]; then _FACT="$_FACT · 사실: 이 파일의 레인 \`scripts/test_${_BN}_lanes.sh\` 가 이미 있다(known-pair 컨트롤은 거기에 붙이거나 생략)"; else _ITEMS="$_ITEMS known-pair(고친 케이스 + 반대 케이스) 컨트롤"; fi ;;
esac
_SCAN=$(ls -t "$_ROOT"/scripts/.degrade_scan_last_*.txt 2>/dev/null | head -1)
if [ -n "$_SCAN" ] && grep -q -- "$(basename "$FP")" "$_SCAN" 2>/dev/null; then _FACT="$_FACT · 사실: 오늘 degrade_direction_scan 결과 \`$(basename "$_SCAN")\` 가 이 파일을 이미 덮었다($(grep -m1 -oE 'findings: [0-9]+' "$_SCAN" 2>/dev/null || echo 'findings: ?')) — 스캐너 통과이지 손 확인이 아니다"; else _ITEMS="$_ITEMS degrade_direction_scan.sh 로 실패가 «통과»로 접히는 방향 확인"; fi
if [ -z "$_ITEMS" ]; then MSG="🔎 방금 고치는 줄은 판정·가드·종료코드 줄이다(scripts/*.sh · templates/*.sh)${_FACT}. 둘 다 이미 있으니 새 제안은 내지 말고, 작업을 마친 뒤 그 사실을 한 줄로만 말해라(형식: «확인 | basis: <위 사실>»)."
else MSG="🔎 방금 고치는 줄은 판정·가드·종료코드 줄이다(scripts/*.sh · templates/*.sh)${_FACT}. 없는 것만 사용자에게 한 줄로 제안해라 —${_ITEMS} — 형식은 «제안: … | basis: <네가 확인한 근거 한 구절>». 가능하면 이 파일·이 케이스의 실제 이름으로. 제안이지 실행이 아니다."; fi
python3 -c 'import json,sys; m=sys.argv[1]; print(json.dumps({"systemMessage":m,"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":m}}, ensure_ascii=False))' "$MSG" 2>/dev/null || exit 0
exit 0
