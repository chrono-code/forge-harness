#!/usr/bin/env bash
# test_destructive_pre_gate_lanes.sh — known pairs for scripts/destructive_pre_gate.sh
#
# LANES FIRST (2026-07-30 harvest #1): write the lane before touching the detector — rounds that
# did had zero fix-reverts-fix regressions. Every PATTERNS row in the guard owes a HIT lane and at
# least one adjacent CLEAN lane (the known-pair rule: an instrument that cannot separate a case you
# already know the answer to is not measuring, it is generating).
#
# WHAT IS BEING GUARDED
#   A destructive command self-justified and executed in one breath (origin: GLM 4-bit sidecar ran
#   `git reset --hard origin/main` after declaring it "safe", 2026-08-01, pmh-dev prototype).
#   Advisory by default; FH_DESTRUCTIVE_BLOCK=1 escalates. The FP lanes matter as much as the HIT
#   lanes: noise trains dismissal of the one warning that will matter (pipe_verdict S5 lesson).

set -u
G="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/destructive_pre_gate.sh"
pass=0; fail=0

# expect <label> <expected: HIT|CLEAN> <command-string>
expect() {
  local label="$1" want="$2" cmd="$3" out got
  out=$(printf '%s' "$cmd" | bash "$G" --stdin-raw 2>&1)
  if printf '%s' "$out" | grep -q 'DESTRUCTIVE-OP'; then got=HIT; else got=CLEAN; fi
  if [ "$got" = "$want" ]; then
    printf '  ✅ %-52s %s (expected %s)\n' "$label" "$got" "$want"; pass=$((pass+1))
  else
    printf '  ❌ %-52s %s (expected %s)\n' "$label" "$got" "$want"; fail=$((fail+1))
    printf '     cmd: %s\n     out: %s\n' "$cmd" "$out"
  fi
}

echo "[destructive-pre-gate] known pairs"
echo "-- git working-tree destroyers --"
expect "reset --hard (the measured origin shape)"  HIT   'git reset --hard origin/main'
expect "reset --hard bare"                         HIT   'git reset --hard'
expect "reset --soft is CLEAN"                     CLEAN 'git reset --soft HEAD~1'
expect "reset (mixed, default) is CLEAN"           CLEAN 'git reset HEAD~1'
expect "clean -fd"                                 HIT   'git clean -fd'
expect "clean -fdx"                                HIT   'git clean -fdx'
expect "clean -n dry-run is CLEAN"                 CLEAN 'git clean -nd'
expect "checkout ."                                HIT   'git checkout .'
expect "checkout -- ."                             HIT   'git checkout -- .'
expect "checkout .gitignore is CLEAN"              CLEAN 'git checkout .gitignore'
expect "checkout branch is CLEAN"                  CLEAN 'git checkout feature/x'
expect "restore --worktree"                        HIT   'git restore --staged --worktree src/'
expect "restore ."                                 HIT   'git restore .'
expect "restore single file is CLEAN"              CLEAN 'git restore src/app.py'

echo "-- history / remote / branch destroyers --"
expect "push --force"                              HIT   'git push --force origin main'
expect "push -f trailing (prototype [^i] missed)"  HIT   'git push origin main -f'
expect "push --force-with-lease still flagged"     HIT   'git push --force-with-lease'
expect "plain push is CLEAN"                       CLEAN 'git push origin feature/x'
expect "push -u is CLEAN"                          CLEAN 'git push -u origin feature/x'
expect "branch -D"                                 HIT   'git branch -D old-branch'
expect "branch -d (merge-checked) is CLEAN"        CLEAN 'git branch -d merged-branch'
expect "stash drop"                                HIT   'git stash drop'
expect "stash clear"                               HIT   'git stash clear'
expect "stash pop is CLEAN"                        CLEAN 'git stash pop'
expect "worktree remove --force"                   HIT   'git worktree remove --force ../wt'
expect "worktree remove plain is CLEAN"            CLEAN 'git worktree remove ../wt'

echo "-- rm scope (precision over recall: only root/home/cwd/glob) --"
expect "rm -rf /"                                  HIT   'rm -rf /'
expect "rm -rf ~"                                  HIT   'rm -rf ~'
expect "rm -rf ."                                  HIT   'rm -rf .'
expect "rm -rf ./"                                 HIT   'rm -rf ./'
expect "rm -rf *"                                  HIT   'rm -rf *'
expect "rm -fr / (flag order)"                     HIT   'rm -fr /'
expect "rm --no-preserve-root"                     HIT   'rm -rf --no-preserve-root /tmp/x'
expect "rm -rf scratch path is CLEAN (residual)"   CLEAN 'rm -rf /tmp/scratch/build'
expect "rm -rf named dir is CLEAN"                 CLEAN 'rm -rf node_modules'
expect "rm single file is CLEAN"                   CLEAN 'rm -f out.log'

echo "-- adversarial shapes --"
expect "multi-line command still caught"           HIT   'cd /repo
git reset --hard origin/main'
expect "compound command still caught"             HIT   'git fetch origin && git reset --hard origin/main'
expect "multi-line legit stays CLEAN"              CLEAN 'cd /repo
git status
git log --oneline -5'
expect "reset --hard with pathspec"                HIT   'git reset --keep x; git reset --hard HEAD~2'

echo "-- Axis-2 round 2: cross-family + challenger bypass shapes (2026-08-01) --"
expect "git -C reset --hard (trained shape)"       HIT   'git -C /repo reset --hard origin/main'
expect "git -C clean -fd"                          HIT   'git -C /repo clean -fd'
expect "git --git-dir reset --hard"                HIT   'git --git-dir=/r/.git reset --hard'
expect "git -C on safe subcommand is CLEAN"        CLEAN 'git -C /repo status'
expect "checkout HEAD -- ."                        HIT   'git checkout HEAD -- .'
expect "checkout ./"                               HIT   'git checkout ./'
expect "branch --delete --force"                   HIT   'git branch --delete --force old'
expect "rm -rf /* (root glob)"                     HIT   'rm -rf /*'
expect "rm -rf ./* (cwd glob)"                     HIT   'rm -rf ./*'
expect "rm -Rf / (uppercase R)"                    HIT   'rm -Rf /'
expect "rm -r -f / (split flags)"                  HIT   'rm -r -f /'
expect "rm -rf quoted root"                        HIT   'rm -rf "/"'
expect "double space between tokens"               HIT   'git  reset  --hard'
expect "backslash line continuation"               HIT   $'rm -rf \\\n/'
expect "CRLF payload"                              HIT   $'rm -rf /\r'
expect "push +refspec force"                       HIT   'git push origin +main'
expect "push-option with + is CLEAN"               CLEAN 'git push origin main --push-option=a+b'
expect "clean -fdn dry-run is CLEAN"               CLEAN 'git clean -fdn'
expect "clean -n -fdx dry-run is CLEAN"            CLEAN 'git clean -n -fdx'
expect "stash dropstash substring is CLEAN"        CLEAN 'git stash dropstash'
expect "stash drop with ref still HIT"             HIT   'git stash drop stash@{1}'
# Named residuals pinned as lanes so a future "fix" that silently changes them is visible:
expect "residual: rm -rf \$HOME stays CLEAN"       CLEAN 'rm -rf $HOME'
expect "residual: find -delete stays CLEAN"        CLEAN 'find . -delete'
expect "residual: mention-as-data DOES fire"       HIT   'echo "git reset --hard is dangerous"'
expect "residual: sudo wrapper still caught"       HIT   'sudo rm -rf /'
expect "path-prefix /bin/rm still caught"          HIT   '/bin/rm -rf /'
expect "subshell (git reset --hard) caught"        HIT   'out=$(git reset --hard 2>&1)'
# Round 3 (measured live 2x): English prose satisfied the rm row via the word TAIL of
# "Confirm" + a dash-word carrying r + a stray glob — leading-separator class kills it.
expect "prose word-tail rm FP stays CLEAN"         CLEAN 'echo Round 2 verification. Confirm each prior finding is closed WITHOUT introducing a new default-toward-PASS hole (attack) * done'
expect "legit reset word-tail stays CLEAN"         CLEAN 'echo the legit reset --hard flag docs'

echo "-- Round 4: GPT-family (gpt-5.6-sol via OpenRouter) decorrelation shapes (2026-08-01) --"
expect "token-split continuation gi\\ t"           HIT   $'git re\\\nset --hard'
expect ":&&git no-whitespace separator"            HIT   ':&&git reset --hard'
expect "false||git separator"                      HIT   'false||git reset --hard'
expect "trailing |cat after --force"               HIT   'git push --force|cat'
expect "(rm -rf ~) closing paren"                  HIT   '(rm -rf ~)'
expect "git --no-pager global opt"                 HIT   'git --no-pager reset --hard'
expect "git -c k=v global opt"                     HIT   'git -c core.a=b reset --hard'
expect "git --git-dir space form"                  HIT   'git --git-dir /r/.git reset --hard'
expect "nested \$(echo -n) not a dry-run"          HIT   'git clean -fd "$(echo -n build)"'
expect "post-'--' -n pathspec not a dry-run"       HIT   'git clean -fd -- -n'
expect "--force-with-lease=<ref>"                  HIT   'git push --force-with-lease=main'
expect "push -fu bundle"                           HIT   'git push -fu origin main'
expect "worktree remove -f short"                  HIT   'git worktree remove -f ../wt'
expect "restore -W short"                          HIT   'git restore -W src/'
expect "rm -rf ././* canonicalized"                HIT   'rm -rf ././*'
expect "rm --recursive long form"                  HIT   'rm --recursive --force /'
expect "FP: docs--hard operand stays CLEAN"        CLEAN 'git reset HEAD -- docs--hard'
expect "FP: clean --exclude=cache stays CLEAN"     CLEAN 'git clean --exclude=cache build/'
expect "FP: branch name release--force CLEAN"      CLEAN 'git branch --delete release--force'
expect "FP: rm --verbose / stays CLEAN"            CLEAN 'rm --verbose /'
expect "FP: push --follow-tags stays CLEAN"        CLEAN 'git push --follow-tags'
expect "dry-run with long opt before -n CLEAN"     CLEAN 'git clean --quiet -n -fd'

echo "-- Round 4: fault-injection (pins the DOCUMENTED degrade, not a safety claim) --"
c_out=$(printf '%s' 'not json at all' | bash "$G" 2>/dev/null); c_rc=$?
if [ "$c_rc" -eq 0 ] && [ -z "$c_out" ]; then
  printf '  ✅ %-52s %s\n' "F1 malformed payload: silent exit 0 (advisory)" OK; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s\n' "F1 malformed payload: silent exit 0 (advisory)" "$c_rc" "$c_out"; fail=$((fail+1))
fi
c_out=$(printf '%s' 'not json at all' | FH_DESTRUCTIVE_BLOCK=1 bash "$G" 2>/dev/null); c_rc=$?
if [ "$c_rc" -eq 0 ] && [ -z "$c_out" ]; then
  printf '  ✅ %-52s %s\n' "F2 block+malformed: fails OPEN (documented residual)" OK; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s\n' "F2 block+malformed: fails OPEN (documented residual)" "$c_rc" "$c_out"; fail=$((fail+1))
fi

echo "-- opt-out --"
expect "noqa suppresses"                           CLEAN 'git reset --hard origin/main  # noqa: destructive-op'

echo "-- C: delivery channel (advisory must reach the model, not a discarded stream) --"
HIT_CMD='git reset --hard origin/main'
payload() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1"; }
c_errf=$(mktemp)

# C1 — advisory hit via full hook payload: stdout = one JSON object, additionalContext +
#      systemMessage present, permissionDecision ABSENT, exit 0.
c_out=$(payload "$HIT_CMD" | bash "$G" 2>"$c_errf"); c_rc=$?
c_err=$(cat "$c_errf")
if [ "$c_rc" -eq 0 ] && printf '%s' "$c_out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
h = d["hookSpecificOutput"]
assert h["hookEventName"] == "PreToolUse"
assert "DESTRUCTIVE-OP" in h["additionalContext"]
assert "DESTRUCTIVE-OP" in d["systemMessage"]
assert "permissionDecision" not in h and "permissionDecision" not in d
' 2>/dev/null; then
  printf '  ✅ %-52s %s\n' "C1 advisory: stdout JSON, no permissionDecision" OK; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s err=%s\n' "C1 advisory: stdout JSON, no permissionDecision" "$c_rc" "$c_out" "$c_err"; fail=$((fail+1))
fi

# C2 — block mode: exit 2, reason on stderr, stdout empty.
c_out=$(payload "$HIT_CMD" | FH_DESTRUCTIVE_BLOCK=1 bash "$G" 2>"$c_errf"); c_rc=$?
c_err=$(cat "$c_errf")
if [ "$c_rc" -eq 2 ] && printf '%s' "$c_err" | grep -q 'DESTRUCTIVE-OP' && [ -z "$c_out" ]; then
  printf '  ✅ %-52s %s\n' "C2 block: exit 2, stderr carries the reason" OK; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s err=%s\n' "C2 block: exit 2, stderr carries the reason" "$c_rc" "$c_out" "$c_err"; fail=$((fail+1))
fi

# C3 — clean command: NO emission at all (silence must stay silent).
c_out=$(payload 'git status' | bash "$G" 2>"$c_errf"); c_rc=$?
rm -f "$c_errf"
if [ "$c_rc" -eq 0 ] && [ -z "$c_out" ]; then
  printf '  ✅ %-52s %s\n' "C3 clean: no emission at all" OK; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s\n' "C3 clean: no emission at all" "$c_rc" "$c_out"; fail=$((fail+1))
fi

# C4 — hostile inherited codec (⚠️ is non-ASCII): JSON must still deliver under
#      PYTHONIOENCODING=ascii thanks to the guard's own utf-8 pin.
c_out=$(payload "$HIT_CMD" | PYTHONIOENCODING=ascii bash "$G" 2>/dev/null); c_rc=$?
if [ "$c_rc" -eq 0 ] && printf '%s' "$c_out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert "DESTRUCTIVE-OP" in d["hookSpecificOutput"]["additionalContext"]
' 2>/dev/null; then
  printf '  ✅ %-52s %s\n' "C4 ascii-codec env: JSON still delivered" OK; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s\n' "C4 ascii-codec env: JSON still delivered" "$c_rc" "$c_out"; fail=$((fail+1))
fi

# C5 — non-Bash tool payload: guard must stay silent (matcher is Bash, but defense in depth).
c_out=$(python3 -c 'import json;print(json.dumps({"tool_name":"Read","tool_input":{"file_path":"git reset --hard"}}))' | bash "$G" 2>/dev/null); c_rc=$?
if [ "$c_rc" -eq 0 ] && [ -z "$c_out" ]; then
  printf '  ✅ %-52s %s\n' "C5 non-Bash payload: silent" OK; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s\n' "C5 non-Bash payload: silent" "$c_rc" "$c_out"; fail=$((fail+1))
fi

echo "-- GPT leg-C round (2026-08-01): option-before-pathspec + staged-only + unicode-input --"
expect "checkout -f . (leg-C bypass)"              HIT   'git checkout -f .'
expect "restore --source=HEAD . (leg-C bypass)"    HIT   'git restore --source=HEAD .'
expect "restore -s HEAD ."                         HIT   'git restore -s HEAD .'
expect "restore --staged . is CLEAN (unstage only)" CLEAN 'git restore --staged .'
expect "restore --staged --worktree ."             HIT   'git restore --staged --worktree .'
expect "checkout .gitignore still CLEAN"           CLEAN 'git checkout .gitignore'

# C6 — unicode command + ascii-codec env: the INPUT extractor must survive (leg-C HIGH #8 —
# output encoder was pinned, input was not; a non-ASCII char anywhere in the payload emptied CMD
# and the guard failed CLEAN-open).
c_out=$(python3 -c 'import json;print(json.dumps({"tool_name":"Bash","tool_input":{"command":"git reset --hard # 한글 주석"}}))' | PYTHONIOENCODING=ascii bash "$G" 2>/dev/null); c_rc=$?
if [ "$c_rc" -eq 0 ] && printf '%s' "$c_out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert "DESTRUCTIVE-OP" in d["hookSpecificOutput"]["additionalContext"]
' 2>/dev/null; then
  printf '  ✅ %-52s %s\n' "C6 unicode cmd + ascii env: still HIT" OK; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s\n' "C6 unicode cmd + ascii env: still HIT" "$c_rc" "$c_out"; fail=$((fail+1))
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "[destructive-pre-gate] ✅ all $pass known pairs hold"; exit 0
else
  echo "[destructive-pre-gate] ❌ $fail/$((pass+fail)) lanes failed"; exit 1
fi
