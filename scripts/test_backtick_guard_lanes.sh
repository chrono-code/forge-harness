#!/usr/bin/env bash
# test_backtick_guard_lanes.sh — known pairs for scripts/backtick_guard.sh. Written BEFORE the detector.
#
# WHAT IS BEING GUARDED
#   A backtick inside a shell DOUBLE-QUOTING CONTEXT — an unquoted heredoc body (`<<EOF`) or a
#   "double-quoted string" — is command substitution: the text between the backticks is REPLACED by
#   the command's output. With no such command the output is empty, so the text is DELETED; with one,
#   foreign content is INSERTED. The sentence stays grammatical (only its subject is gone), the only
#   signal is one `command not found` line at the top of the output, and every marker/record hook
#   checks a field's presence, not its completeness.
#   Measured 7× (2026-08-10 · 2026-09-01 ×3 · 2026-09-02 ×4 — marker, RESULT doc, fh_completed echo ×2)
#   with a resident memory rule that failed each time because the actor's task had a different NAME
#   (writing a marker · a failure message · a seal). N≥3 → mechanize (weekly_audit_2026-09-02 HIGH #1).
#
#   BT1 — unquoted heredoc body (`<<TAG`, `<<-TAG`; NOT `<<'TAG'` / `<<"TAG"` / `<<\TAG`) containing `
#   BT2 — double-quoted string containing ` (single-quoted text and `\`` are literal → CLEAN)
#
# Surface = the Bash tool call itself (interactively-composed commands), same reasoning as
# pipe_verdict_guard: every recurrence was in a composed command, none in a shipped file.

set -u
G="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backtick_guard.sh"
pass=0; fail=0

# expect <label> <HIT|CLEAN> <command-string>   (the command text is passed raw via --stdin-raw)
expect() {
  local label="$1" want="$2" cmd="$3" out got
  out=$(printf '%s' "$cmd" | bash "$G" --stdin-raw 2>&1)
  # want may be HIT · CLEAN · HIT:BT1@2 (rule and line asserted — a hit on the WRONG line is a miss)
  if printf '%s' "$out" | grep -q 'BACKTICK'; then got=HIT; else got=CLEAN; fi
  case "$want" in HIT:*) printf '%s' "$out" | grep -q "${want#HIT:BT}" 2>/dev/null; :; esac
  if [ "$got" = HIT ] && [ "${want%%:*}" = HIT ] && [ "$want" != HIT ]; then
    local r="${want#HIT:}"; r="${r%@*}"; local l="${want##*@}"
    printf '%s' "$out" | grep -q "$r L$l " || got="HIT-WRONG($(printf '%s' "$out" | grep -oE 'BT[12] L[0-9]+' | head -1))"
    [ "$got" = HIT ] && got="$want"
  fi
  if [ "$got" = "$want" ]; then
    printf '  ✅ %-56s %s (expected %s)\n' "$label" "$got" "$want"; pass=$((pass+1))
  else
    printf '  ❌ %-56s %s (expected %s)\n' "$label" "$got" "$want"; fail=$((fail+1))
    printf '     cmd: %s\n     out: %s\n' "$cmd" "$out"
  fi
}
BT='`'   # one backtick, spelled once so the lanes below never carry a live one in double quotes
NL=$'\n'

echo "[backtick-guard] known pairs"
echo "-- BT1: unquoted heredoc body --"
# 2026-09-02 ⓐ — the measured shape: a marker written through an unquoted heredoc so a $VAR expands.
expect "BT1 measured: marker heredoc"        HIT:BT1@3   "cat > m.marker <<EOF${NL}date: \$TODAY${NL}axis2-evidence: 러너가 ${BT}--keep-blind-paths${BT} 를 삼켰다${NL}EOF"
expect "BT1 <<-TAG (tab-stripped) form"      HIT   "cat <<-EOF${NL}	note ${BT}x${BT}${NL}	EOF"
expect "BT1 markdown fence in heredoc"       HIT   "cat > r.md <<EOF${NL}\`\`\`${NL}out${NL}\`\`\`${NL}EOF"
expect "BT1 second of two heredocs on a line" HIT:BT1@4  "diff <(cat <<'A') <(cat <<B)${NL}${BT}a${BT}${NL}A${NL}${BT}b${BT}${NL}B"
expect "BT1 quoted <<'EOF' is CLEAN"          CLEAN "cat > m.marker <<'EOF'${NL}evidence: ${BT}--keep-blind-paths${BT} 삼킴${NL}EOF"
expect "BT1 quoted <<\"EOF\" is CLEAN"        CLEAN "cat <<\"EOF\"${NL}${BT}x${BT}${NL}EOF"
expect "BT1 escaped <<\\EOF is CLEAN"         CLEAN "cat <<\\EOF${NL}${BT}x${BT}${NL}EOF"
expect "BT1 backslash-escaped backtick CLEAN" CLEAN "cat <<EOF${NL}see \\${BT}x\\${BT}${NL}EOF"
expect "BT1 backtick AFTER the body ends"     CLEAN "cat <<EOF${NL}plain${NL}EOF${NL}echo '${BT}later${BT}'"
expect "BT1 <<< herestring is not a heredoc"  CLEAN "grep -c x <<< 'a ${BT}b${BT}'"

echo "-- BT2: double-quoted string --"
# 2026-09-02 ⓑ — the measured shape: a completion-log append through echo "…".
expect "BT2 measured: echo append"            HIT:BT2@1   "echo \"- ✅ 러너 ${BT}sim_isolated_run.sh${BT} 헤더 경고\" >> tracks/_meta/fh_completed.md"
expect "BT2 failure-message string (09-01)"   HIT   "printf '%s\\n' \"(${BT}nameleak_check.sh gen${BT} 을 써라)\""
expect "BT2 single quote inside dq is inert"  HIT   "echo \"don't ${BT}x${BT}\""
expect "BT2 single-quoted is CLEAN"           CLEAN "printf '%s\\n' '- ✅ 러너 ${BT}sim_isolated_run.sh${BT} 헤더' >> log.md"
expect "BT2 escaped \\\` is CLEAN"             CLEAN "echo \"see \\${BT}x\\${BT}\""
expect "BT2 dq inside single quotes is CLEAN" CLEAN "echo '\"${BT}x${BT}\"'"
expect "BT2 sq inside \$( ) inside dq CLEAN"  CLEAN "echo \"\$(printf '%s' '${BT}x${BT}')\""
expect "BT2 no backtick at all"               CLEAN "echo \"\$(git log -1) done\" && cat <<EOF${NL}plain \$X${NL}EOF"
expect "BT2 bare backtick outside quotes"     CLEAN "V=${BT}date${BT}; echo ok"   # live command substitution on purpose, not a text context

echo "-- Axis-2 pass 2026-09-03 (challenger, repros executed by the governor) --"
# A1: the first build stripped single-quoted spans BEFORE matching heredoc operators, so <<'EOF' was
# never a heredoc — three symptoms from one cause. Each pinned in its real shape.
expect "A1a quoted body with dq+backtick CLEAN" CLEAN "cat <<'EOF'${NL}axis2-evidence: 메시지 \"use ${BT}x${BT}\" 가 떴다${NL}EOF"
expect "A1b quoted A then unquoted B: only B" CLEAN "diff <(cat <<'A') <(cat <<B)${NL}${BT}a${BT}${NL}A${NL}plain${NL}B"
expect "A1c apostrophe in quoted body, then echo" HIT:BT2@4 "cat <<'EOF'${NL}don't${NL}EOF${NL}echo \"${BT}x${BT}\" >> log"
# A2: a comment's apostrophe must not open a single-quote context that swallows the next line.
expect "A2 comment apostrophe then echo"      HIT:BT2@2 "# don't re-run this${NL}echo \"${BT}x${BT}\" >> f.md"
expect "A2 url fragment is not a comment"     HIT:BT2@1 "curl \"https://x/a#frag ${BT}x${BT}\""
# B3: <<TAG inside a double-quoted string (commit message) opens no heredoc.
expect "B3 <<EOF in commit message is CLEAN" CLEAN "git commit -m \"docs: prefer <<EOF for markers\"${NL}V=${BT}date${BT}; echo ok"
# B5: escaped backslash + LIVE backtick.
expect "B5 \\\\ then live backtick HITs"      HIT:BT1@2 "cat <<EOF${NL}path\\\\${BT}x${BT}${NL}EOF"
# B2: ANSI-C $'…' with an escaped apostrophe does not end early.
expect "B2 \$'don\\'t' then dq backtick"      HIT:BT2@1 "echo \$'don\\'t' \"${BT}x${BT}\""
# B1: backtick inside \$( ) re-entered from dq is live substitution — deliberately NOT flagged.
expect "B1 backtick inside \$( ) in dq CLEAN"  CLEAN "echo \"\$(echo ${BT}x${BT})\""

echo "-- hook mode: JSON payload in → JSON out (A4: detection is worthless if delivery is 0) --"
jexp() {  # <label> <expect-substring-in-additionalContext|SILENT> <env> <payload>
  local label="$1" want="$2" env_="$3" payload="$4" out ctx
  out=$(printf '%s' "$payload" | env $env_ bash "$G" 2>/dev/null)
  if [ "$want" = SILENT ]; then
    if [ -z "$out" ]; then printf '  ✅ %-56s SILENT\n' "$label"; pass=$((pass+1)); else printf '  ❌ %-56s expected SILENT, got: %s\n' "$label" "${out:0:80}"; fail=$((fail+1)); fi
    return
  fi
  ctx=$(printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["hookSpecificOutput"]["additionalContext"])' 2>/dev/null)
  if printf '%s' "$ctx" | grep -q "$want"; then printf '  ✅ %-56s JSON additionalContext carries %s\n' "$label" "$want"; pass=$((pass+1))
  else printf '  ❌ %-56s no JSON/context (%s)\n' "$label" "${out:0:80}"; fail=$((fail+1)); fi
}
P='{"tool_name":"Bash","tool_input":{"command":"echo \"- done `x.sh` ok\""}}'
jexp "JSON payload → additionalContext"       "BT2 L1" "X=1" "$P"
jexp "ascii PYTHONIOENCODING still emits"     "BT2 L1" "PYTHONIOENCODING=ascii" "$P"
jexp "non-Bash tool is SILENT"                SILENT   "X=1" '{"tool_name":"Write","tool_input":{"content":"`x`"}}'
jexp "unparseable payload is SILENT"          SILENT   "X=1" 'not json'

echo "-- opt-out / payload --"
expect "noqa exempts"                         CLEAN "echo \"${BT}x${BT}\"  # noqa: backtick"
expect "empty payload"                        CLEAN ""

echo
echo "[backtick-guard] $pass passed, $fail failed"
[ "$fail" -eq 0 ]
