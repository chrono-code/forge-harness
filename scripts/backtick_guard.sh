#!/usr/bin/env bash
# backtick_guard.sh — PreToolUse(Bash) advisory: a backtick inside a shell double-quoting context.
#
# THE DEFECT
#   In an unquoted heredoc body (`<<EOF`) or a "double-quoted string", a backtick is COMMAND
#   SUBSTITUTION: the text between the backticks is REPLACED by that command's output. Written as
#   markup (`--flag`, `file.sh`), it names no command, so the output is empty and the text is
#   DELETED — the sentence stays grammatical, only its subject is gone. The one signal is a
#   `command not found` line at the TOP of the output, where it reads as unrelated noise. Every
#   record hook (marker · manifest · completed-log) checks a field's PRESENCE, not its completeness,
#   so the hole commits. Measured 7×: 2026-08-10 (lane stub, stderr noise) · 2026-09-01 ×3 (marker,
#   failure-message string, seal) · 2026-09-02 ×4 (marker, RESULT doc, fh_completed echo ×2).
#
# WHY A HOOK AND NOT A MEMORY RULE
#   The memory rule existed since 08-10 and was re-read the day of each recurrence. It failed every
#   time for the same reason: recall is grep, and the actor's task carried a different NAME (writing
#   a marker · a failure message · a seal) than the rule's title (heredoc). N=7 ≥ 3 → mechanize
#   (weekly_audit_2026-09-02 HIGH #1). The surface is the Bash tool call, where every recurrence
#   lived (see KNOWN RESIDUALS for the two that may not have been).
#
# TWO RULES
#   BT1 — unquoted heredoc body: `<<TAG` / `<<-TAG` whose tag is NOT quoted (`'TAG'` `"TAG"` `\TAG`).
#         A `\`` inside is literal and not flagged. Body ends at a line equal to TAG (`<<-` strips
#         leading tabs). Several heredocs on one line are queued in order (shell semantics).
#   BT2 — double-quoted string containing an unescaped backtick. Single-quoted text is literal.
#         `$( … )` inside double quotes re-enters normal parsing, so a single-quoted backtick
#         there is literal and not flagged.
#   Both rules come from ONE quote-aware state machine (N · single · double · $'…' · heredoc
#   body), not a regex — the defect IS a quoting context, so a quote-blind matcher would flag the
#   exact prescription (`printf '%s' '…`…`…'`). A heredoc operator counts only in normal context,
#   comments (`#` at a word start) are skipped, and a quoted heredoc body is skipped whole.
#   KNOWN RESIDUALS (named, not hidden — several found by the Axis-2 pass of 2026-09-03):
#   · a bare backtick outside any quote (V=`date`), or inside `$( )` re-entered from double quotes,
#     is live substitution written on purpose — NOT flagged (an earlier header said BT2; the code
#     never did, and the code is the intent).
#   · `# noqa: backtick` exempts the WHOLE payload, including when the phrase appears inside a
#     record being written (quoting this header's own prescription into a marker exempts that
#     marker's payload). Same accepted residual as destructive_pre_gate's noqa.
#   · python3 broken/absent → CMD="" → silent exit 0 even under FH_BACKTICK_BLOCK=1: block mode
#     fails OPEN on a dead interpreter, the same accepted trade as pipe_verdict_guard (the
#     alternative blocks every Bash call on such a machine).
#   · surface = the Bash tool call. Of the 7 measured recurrences, at least 5 were composed Bash
#     commands; the 2026-08-10 one lived in a shipped lane file (`test_sidecar_calibrate_lanes.sh`,
#     git log -S confirms) and the 09-01 failure-message one in a script — if those were authored
#     through Write/Edit, this hook is not on that path. Coverage claim is therefore «the composed
#     command surface», not 7/7; a file-side scanner is a separate, unbuilt instrument.
#   · three JSON-emitting PreToolUse(Bash) hooks now fire on every call (pipe_verdict ·
#     destructive_pre_gate · this one); concurrent emission is unverified at runtime (LOW).
#
# DEGRADE DIRECTION: advisory. Warns and exits 0 — a mangled write is re-runnable, and a false block
#   on the developer's shell trains --no-verify on the hooks that guard irreversible surfaces.
#   FH_BACKTICK_BLOCK=1 escalates to exit 2. Unparseable payload → silent (not a finding).
#   DELIVERY: JSON on stdout — additionalContext (model) + systemMessage (user), no
#   permissionDecision (same contract as pipe_verdict_guard; see its header for why).
#
# PRESCRIPTION (memory feedback_unquoted_heredoc_backtick_executes, 4th revision):
#   ① heredoc → `<<'EOF'`; a value that must expand (hash, time) is computed FIRST into a variable
#     and substituted after, or printed on its own line — never opened unquoted for one value.
#   ② one-line append → `printf '%s\n' '…'` (single quotes), not `echo "…"`.
#
# Usage:
#   hook:  PreToolUse matcher "Bash" → bash scripts/backtick_guard.sh
#   test:  printf '%s' "<command>" | bash scripts/backtick_guard.sh --stdin-raw
# Opt out on a single call with a trailing `# noqa: backtick` (exempts the whole payload).

set -u

CMD=""
if [ "${1:-}" = "--stdin-raw" ]; then
  CMD=$(cat)
else
  RAW=$(cat)
  CMD=$(printf '%s' "$RAW" | python3 -c '
import json,sys
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
if d.get("tool_name") != "Bash": sys.exit(0)
sys.stdout.buffer.write((d.get("tool_input", {}).get("command", "") or "").encode("utf-8"))
' 2>/dev/null) || CMD=""
fi
[ -n "$CMD" ] || exit 0
printf '%s' "$CMD" | grep -qE '#[[:space:]]*noqa:?[[:space:]]*backtick' && exit 0

# The scanner. Emits one line per finding: "<rule>\t<line>\t<snippet>". Empty output = clean.
hits=$(printf '%s' "$CMD" | PYTHONIOENCODING=utf-8 python3 -c '
import re, sys
text = sys.stdin.read()
L = len(text)
findings = []
# ONE quote-aware pass. Contexts: N normal · S single-quoted · D double-quoted · A $\x27…\x27 ANSI-C.
# A heredoc operator is recognised ONLY in N (so `"<<EOF"` in a commit message opens nothing), and
# its body is consumed line-by-line when the operator line ends — quoted bodies are skipped whole,
# unquoted bodies are scanned for a live backtick (`\\` escapes the next char, so `\\\\`+backtick is live).
HD = re.compile(r"<<(-?)[ \t]*(?:\x27([^\x27\n]*)\x27|\"([^\"\n]*)\"|\\\\([A-Za-z_][A-Za-z0-9_]*)|([A-Za-z_][A-Za-z0-9_]*))")
st = ["N"]; depth = []   # depth: paren depth per $( ) nesting opened from D
pending = []             # (tag, quoted, strip_tabs) heredocs opened on the current line, in order
line = 1
k = 0
def snippet(i):
    return text[max(0, i-30):i+31].replace("\n", " ").strip()[:90]
while k < L:
    c = text[k]
    top = st[-1]
    if c == "\n":
        line += 1; k += 1
        if pending and top == "N":
            for tag, quoted, strip_tabs in pending:
                while k < L:
                    e = text.find("\n", k)
                    if e < 0: e = L
                    ln = text[k:e]
                    cmp_ = ln.lstrip("\t") if strip_tabs else ln
                    if cmp_ == tag:
                        k = e + 1; line += 1; break
                    if not quoted:
                        j = 0
                        while j < len(ln):
                            if ln[j] == "\\": j += 2; continue
                            if ln[j] == "`":
                                findings.append(("BT1", line, ln.strip()[:90])); break
                            j += 1
                    k = e + 1; line += 1
            pending = []
        continue
    if top == "S":
        if c == "\x27": st.pop()
        k += 1; continue
    if top == "A":
        if c == "\\": k += 2; continue
        if c == "\x27": st.pop()
        k += 1; continue
    if c == "\\":
        k += 2; continue
    if top == "D":
        if c == "\"": st.pop(); k += 1; continue
        if text.startswith("$(", k): st.append("N"); depth.append(1); k += 2; continue
        if c == "`": findings.append(("BT2", line, snippet(k))); k += 1; continue
        k += 1; continue
    # top == N
    if c == "#" and (k == 0 or text[k-1] in " \t\n;&|(" ) and not depth:
        e = text.find("\n", k); k = L if e < 0 else e; continue
    if text.startswith("$\x27", k): st.append("A"); k += 2; continue
    if c == "\x27": st.append("S"); k += 1; continue
    if c == "\"": st.append("D"); k += 1; continue
    if text.startswith("$(", k):
        if depth: depth[-1] += 1
        k += 2; continue
    if c == "(" and depth: depth[-1] += 1; k += 1; continue
    if c == ")" and depth:
        depth[-1] -= 1
        if depth[-1] == 0: depth.pop(); st.pop()
        k += 1; continue
    if c == "<" and text.startswith("<<", k) and not text.startswith("<<<", k) and (k == 0 or text[k-1] != "<"):
        m = HD.match(text, k)
        if m:
            dash, q1, q2, esc, bare = m.groups()
            tag = q1 if q1 is not None else (q2 if q2 is not None else (esc if esc is not None else bare))
            pending.append((tag, (q1 is not None) or (q2 is not None) or (esc is not None), dash == "-"))
            k = m.end(); continue
    k += 1
seen = set()
for r, l, s in findings:
    if (r, l) in seen: continue
    seen.add((r, l)); print("%s\t%d\t%s" % (r, l, s))
' 2>/dev/null) || hits=""
[ -n "$hits" ] || exit 0

msg="  ⚠️  BACKTICK — 셸 이중인용 문맥 안의 백틱은 «명령 치환»이다: 그 자리 텍스트가 명령 출력으로 바뀐다(명령 없으면 삭제·있으면 오삽입). 실측 7회, 마커·기록에 구멍이 뚫린 채 커밋됐다.
"
while IFS=$'\t' read -r rule ln snip; do
  [ -n "$rule" ] || continue
  case "$rule" in
    BT1) what="비인용 heredoc 본문";;
    BT2) what="큰따옴표 문자열";;
    *)   what="$rule";;
  esac
  msg="${msg}      ${rule} L${ln} (${what}): ${snip}
"
done <<< "$hits"
msg="${msg}      처방: heredoc 은 <<'EOF' 로 열고 확장할 값(해시·시각)은 «먼저 변수로 계산해» 뒤에 치환 · 한 줄 append 는 printf '%s\\n' '…'(작은따옴표). 의도된 치환이면 # noqa: backtick
"

if [ "${FH_BACKTICK_BLOCK:-0}" = "1" ]; then
  printf '%s' "$msg" >&2
  exit 2
fi
json_out=$(printf '%s' "$msg" | PYTHONIOENCODING=utf-8 python3 -c '
import json, sys
h = sys.stdin.read()
print(json.dumps({"systemMessage": h, "hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": h}}))
' 2>/dev/null)
if [ -n "$json_out" ]; then printf '%s\n' "$json_out"; exit 0; fi
printf '%s' "$msg" >&2
exit 0
