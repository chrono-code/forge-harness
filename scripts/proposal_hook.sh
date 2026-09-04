#!/usr/bin/env bash
# proposal_hook.sh — PreToolUse(Edit|Write|Bash) advisory: a verdict/guard line in scripts/**/*.sh or
# templates/*.sh is about to change → put ONE proposal instruction into the model's context
# (additionalContext): «offer the user a known-pair control + degrade_direction_scan.sh in one line».
#
# 🟥 2026-09-04 계기 교체 — 이후 F 행은 이전 F 행과 같은 계기가 아니다. The Bash-path discriminator below
#    was replaced after the first independent grading of the live FIRE rows
#    (tracks/_meta/RESULT_2026-09-04_identity5-armC-live-count.md §계기 결함 1·2·3): 3 of 7 rows were not edits
#    at all, and 6 of 8 load-bearing verdict edits that day never fired. Rows written by the old rule and rows
#    written by this one must not be pooled into one count. Whether the open falsification window is closed,
#    restarted, or split is the governor's / operator's decision, recorded there — not here.
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
#   file class  : scripts/**/*.sh · templates/*.sh · */.git-hooks/*   (docs, tracks, tests-as-fixtures: no)
#   edit kind   : the touched text carries a verdict/guard token — exit N · return N ·
#                 `|| continue|exit|true|return` · `&& continue|exit` · -ne/-eq/-gt/-lt · ==/!= ·
#                 `[ -e/-f/-s/-n/-z` · comm/diff/cmp · grep -q — AND for Edit the change is not
#                 confined to quoted strings (old/new with quotes stripped must differ). A usage
#                 string that happens to contain `exit 2` does not fire (r4 HARD 0/5).
#   Edit/Write  : the file is `tool_input.file_path` — the tool tells us what changes; nothing is inferred.
#   Bash path   : the shell has no file_path, so the question «which file does this command WRITE» is answered
#                 by a small scanner instead of a whole-command regex (the 2026-09-03 rule matched the raw
#                 text, so a heredoc body, a PR body, or a python string that merely QUOTED `sed -i … x.sh`
#                 counted as an edit — RESULT 2026-09-04 rows 2·3·4):
#                   ① heredoc bodies are lifted out (`<<EOF` … `EOF`) and kept aside, keyed to the line that opened them
#                   ② the rest is split into segments on `;` `&&` `||` newline — OUTSIDE quotes; quoted text is masked
#                   ③ a target is an ARGUMENT POSITION only: `> path` · `>> path` · `tee [-a] path` (unquoted in the
#                      masked text, or a quoted path directly after the operator) · the file argument of `sed -i …`
#                   ④ a `python3 … <<HEREDOC` segment is opened: `open(P,"w"|"a")` / `Path(P).write_text` with P a
#                      literal or a variable assigned ONCE in the body (`p="scripts/x.sh"`) names the target
#                      (RESULT §결함 2 — 16 of 27 script edits that day were this shape and all were silent)
#                   ⑤ the token test runs on the segment that OWNS the target (+ its heredoc body), not on the
#                      whole command — `|| exit 1` two segments later is a check, not an edit (RESULT §결함 3, row 6).
#                      For a python heredoc the token text is the body's STRING LITERALS only, so `if a == b:` in the
#                      python code itself is not a verdict edit, and a comment-word replace stays silent
#                   ⑥ a path containing `$` is dropped — `: > "$T/scripts/x.sh"` is a fixture root, not this repo
#                 Quotes are NOT stripped from the owning segment's token text: in `sed -i 's/exit 1/exit 2/' x.sh`
#                 the token sits inside the quotes by construction (Air 2026-09-03).
#   WHAT THE BASH PATH STILL CANNOT SEE (named, not closed)
#                 · a script path reached through a variable (`"$REPO_ROOT/scripts/x.sh"`, `$f`) — ⑥ drops it
#                 · python targets built at runtime (`os.path.join`, `sys.argv[1]`, `p = base + name`)
#                 · edits by other tools: `perl -pi`, `awk … > tmp && mv tmp x.sh`, `patch`, `git apply`, `ed`,
#                   `cp`/`mv`/`install` onto a script, `sponge`
#                 · an unterminated quote earlier in the command swallows every target after it
#                 · a token inside the owning segment that is not the edit payload (`sed -i 's/a/b/' x.sh | grep -q y`
#                   is still one segment) — narrower than before, not zero
#                 It is PreToolUse, so «what actually changed on disk» is not available here at all; a PostToolUse
#                 twin diffing mtimes would close the tool-shape residuals above and was NOT built in this patch
#                 (it needs a wiring change in settings.json, outside this file).
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
PYCODE=$(cat <<'PY'
import json,sys,re
try: d=json.load(sys.stdin)
except Exception: print("",""); sys.exit(0)
tn=d.get("tool_name",""); ti=d.get("tool_input",{}) or {}
TOK=r"exit [0-9]|return [0-9]|\|\| *(continue|exit|true|return)|&& *(continue|exit)|-ne |-eq |-gt |-lt | == | != |\[ -[efsnz] |\bcomm |\bdiff |\bcmp |grep -q"
CLASS=re.compile(r"(scripts/[^\s]*\.sh$|templates/[^\s]*\.sh$|(^|/)\.git-hooks/[^/]+$)")
def strip(x): return re.sub(r"\"[^\"]*\"|'[^']*'","",x)
def is_target(p): return bool(p) and "$" not in p and bool(CLASS.search(p))
def tok(x): return bool(re.search(TOK,x))

def lift_heredocs(cmd):
    # replace each `<<[-]['"]DELIM['"]` with \x02k\x02 and cut its body out; bodies[k]=text
    HD=re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
    lines=cmd.split("\n"); out=[]; bodies=[]; i=0
    while i<len(lines):
        ln=lines[i]; i+=1; ms=list(HD.finditer(ln))
        for m in ms:
            k=len(bodies); body=[]
            while i<len(lines) and lines[i].strip()!=m.group(2): body.append(lines[i]); i+=1
            i+=1
            bodies.append("\n".join(body)); ln=ln.replace(m.group(0),"\x02%d\x02"%k,1)
        out.append(ln)
    return "\n".join(out),bodies

def segments(text):
    # split on ; && || newline outside quotes; returns [(raw, masked, quoted_list)]
    segs=[]; raw=[]; masked=[]; quoted=[]; q=None; i=0; n=len(text)
    def flush():
        segs.append(("".join(raw),"".join(masked),list(quoted))); raw[:]=[]; masked[:]=[]; quoted[:]=[]
    while i<n:
        c=text[i]
        if q:
            j=i
            while j<n:
                if text[j]=="\\" and q=='"' and j+1<n: j+=2; continue
                if text[j]==q: break
                j+=1
            body=text[i:j]; raw.append(body); masked.append("\x01%d\x01"%len(quoted)); quoted.append(body)
            if j<n: raw.append(q); masked.append(q)
            q=None; i=j+1; continue
        if c in "\"'": q=c; raw.append(c); masked.append(c); i+=1; continue
        if c=="\\" and i+1<n: raw.append(text[i:i+2]); masked.append(text[i:i+2]); i+=2; continue
        if text.startswith("&&",i) or text.startswith("||",i): flush(); i+=2; continue
        if c==";" or c=="\n": flush(); i+=1; continue
        raw.append(c); masked.append(c); i+=1
    flush(); return segs

PATH_RE=r"(?:[\"']\x01(\d+)\x01[\"']|([^\s\"'|;&<>()]+))"
RED=re.compile(r"(?:(?<![<\w])>>?|\btee\s+(?:-a\s+)?)\s*"+PATH_RE)
PYW=re.compile(r"open\(\s*(?:['\"]([^'\"]+)['\"]|([A-Za-z_]\w*))\s*,\s*['\"][wa]|Path\(\s*(?:['\"]([^'\"]+)['\"]|([A-Za-z_]\w*))\s*\)\.write_(?:text|bytes)|\b([A-Za-z_]\w*)\.write_(?:text|bytes)\(")
PYSTR=re.compile(r"\"\"\"(?:.|\n)*?\"\"\"|'''(?:.|\n)*?'''|\"(?:\\.|[^\"\\\n])*\"|'(?:\\.|[^'\\\n])*'")

def bash_targets(cmd):
    text,bodies=lift_heredocs(cmd); found=[]
    for raw,masked,quoted in segments(text):
        hb="\n".join(bodies[int(k)] for k in re.findall(r"\x02(\d+)\x02",masked))
        cands=[]
        for m in RED.finditer(masked):
            p=quoted[int(m.group(1))] if m.group(1) else m.group(2)
            if is_target(p): cands.append((p,raw+"\n"+hb))
        if re.search(r"\bsed\s+(?:-\S+\s+)*-i",masked):
            for a in masked.split():
                if is_target(a): cands.append((a,raw+"\n"+hb)); break
        if hb and re.search(r"\bpython[0-9.]*\b",masked):
            assigns=dict(re.findall(r"^\s*([A-Za-z_]\w*)\s*=\s*(?:Path\(\s*)?['\"]([^'\"\n]+)['\"]\s*\)?\s*$",hb,re.M))
            lits=" ".join(PYSTR.findall(hb))
            for m in PYW.finditer(hb):
                p=m.group(1) or m.group(3) or assigns.get(m.group(2) or m.group(4) or m.group(5) or "","")
                if is_target(p): cands.append((p,lits))
        for p,ttext in cands: found.append((p,"1" if tok(ttext) else "0"))
    for p,f in found:
        if f=="1": return p,f
    return (found[0] if found else ("","0"))

fp=""; flag="0"
if tn in ("Edit","Write"):
    fp=ti.get("file_path","") or ""
    old=ti.get("old_string","") or ""; new=(ti.get("new_string","") or ti.get("content","") or "")
    touches=tok(old+"\n"+new); real=strip(old).strip()!=strip(new).strip()
    flag="1" if (touches and real) else "0"
elif tn=="Bash":
    fp,flag=bash_targets(ti.get("command","") or "")
print(fp, flag)
PY
)
read -r FP FLAG < <(printf '%s' "$RAW" | python3 -c "$PYCODE" 2>/dev/null) || exit 0
[ -n "${FP:-}" ] || exit 0
case "$FP" in *scripts/*.sh|*templates/*.sh|scripts/*.sh|templates/*.sh|*/.git-hooks/*|.git-hooks/*) ;; *) exit 0 ;; esac   # .git-hooks/* has no .sh suffix — the gate files themselves were outside the filter (arm C wt2 2026-09-03: pre-commit edit, no FIRE)
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
