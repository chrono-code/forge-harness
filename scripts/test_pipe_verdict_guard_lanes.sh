#!/usr/bin/env bash
# test_pipe_verdict_guard_lanes.sh — known pairs for scripts/pipe_verdict_guard.sh
#
# WHY THIS FILE EXISTS, AND WHY IT IS WRITTEN BEFORE THE DETECTOR
#   2026-07-30 harvest #1: across a 5-round challenger run, three rounds contained a fix that
#   reverted an earlier fix — and the rounds that wrote the lane BEFORE touching the code had
#   zero such regressions. Convergence came from the ORDER, not the patch. So: lanes first.
#
# WHAT IS BEING GUARDED
#   Reading a verdict from `$?`/`${PIPESTATUS[…]}` after a pipeline, which yields the status of
#   the LAST stage. When the last stage is a display filter (`tail`, `head`, `cat`), that status
#   is the filter's — a FAILING gate reads as exit 0. Degrade direction: toward PASS.
#
#   R1 (deterministic, zero-FP): `${PIPESTATUS[...]}` under zsh. zsh spells it `$pipestatus[1]`
#       and 1-indexes it; the bash array expands to the EMPTY STRING. Any verdict read from it is
#       not merely wrong, it is absent. Measured 6× in this project's ad-hoc invocations.
#   R2 (heuristic, narrowed): pipeline whose FINAL stage is a display filter, followed by a read
#       of `$?`. Narrowed to display filters on purpose — see the FP lanes below.
#
# WHY A REPO-FILE LINTER IS THE WRONG SURFACE (measured 2026-07-31)
#   The prescription on the session card was "add an S6 class to degrade_direction_scan.sh".
#   Hand-verifying every `pipe + $?` hit in this repo's scripts returned 7 hits, 7 of them correct
#   (the last stage WAS the command under test in all 7). True positives in shipped files: 0.
#   All 6 measured recurrences were in interactively-composed commands, which no file scanner
#   reads. Shipping S6 would have been a 0-true-positive probe — exactly the failure S5's own
#   comment records ("100% FP trains dismissal of the one hit that will matter").

set -u
G="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pipe_verdict_guard.sh"
pass=0; fail=0

# expect <label> <expected: HIT|CLEAN> <command-string>
expect() {
  local label="$1" want="$2" cmd="$3" out got
  out=$(printf '%s' "$cmd" | bash "$G" --stdin-raw 2>&1)
  if printf '%s' "$out" | grep -q 'PIPE-VERDICT'; then got=HIT; else got=CLEAN; fi
  if [ "$got" = "$want" ]; then
    printf '  ✅ %-52s %s (expected %s)\n' "$label" "$got" "$want"; pass=$((pass+1))
  else
    printf '  ❌ %-52s %s (expected %s)\n' "$label" "$got" "$want"; fail=$((fail+1))
    printf '     cmd: %s\n     out: %s\n' "$cmd" "$out"
  fi
}

echo "[pipe-verdict-guard] known pairs"
echo "-- R1: PIPESTATUS under zsh (deterministic) --"
# The exact shape emitted 6× in this project, including twice on 2026-07-31.
expect "R1 the measured shape"            HIT   'bash x.sh | tail -5; echo "exit=${PIPESTATUS[0]}"'  # portability-noqa: fixture string fed to pipe_verdict_guard.sh for static analysis, never executed by this shell
expect "R1 any index"                     HIT   'a | b; rc=${PIPESTATUS[1]}'  # portability-noqa: same as above
expect "R1 inside a larger command"       HIT   'cd /r && npm t | tail; E=${PIPESTATUS[0]}; echo $E'  # portability-noqa: same as above
# zsh's own spelling is correct here and must never be flagged.
expect "R1 zsh spelling is CLEAN"         CLEAN 'a | b; rc=$pipestatus[1]'

echo "-- R2: display-filter final stage, then \$? --"
expect "R2 tail then \$?"                  HIT   'bash gate.sh | tail -20; echo "exit=$?"'
expect "R2 head then \$?"                  HIT   'make test | head -40; rc=$?'
expect "R2 cat then \$?"                   HIT   'run.sh | cat; if [ $? -ne 0 ]; then echo bad; fi'

echo "-- R2 «바로 다음 문장» 좁힘 (2026-09-06, 운영자 실사용 신고) --"
# 🟥 종전 꼬리 `[;&].*\$\?` 는 파이프 뒤 **어디든** `$?` 가 있으면 잡았다 — 그게 다른
#   명령의 것이어도. 한 호출에 문장이 여럿인 실사용 커맨드는 거의 항상 걸렸고, 그건
#   «100% FP 는 정작 중요한 한 건을 무시하도록 훈련시킨다» 는 이 훅 자신의 경고 그대로다.
expect "R2 좁힘: 사이에 다른 명령이 끼면 그 \$? 는 그 명령의 것" CLEAN \
       'out=$(a 2>&1); rc=$?; echo "$out" | tail -1; b; echo $?'
expect "R2 좁힘: 두 문장 뒤의 \$? 도 아니다"                    CLEAN \
       'pytest | tail -2; echo done; echo $?'
expect "R2 좁힘: 파이프 앞에서 잡은 rc 는 원래 정상"             CLEAN \
       'out=$(pytest 2>&1); rc=$?; echo "$out" | tail -2 | head -1; echo "rc=$rc"'
# 짝 — 좁히다가 진짜 결함을 죽이면 그게 과교정이다
expect "R2 좁힘 짝: 직후 문장의 \$? 는 여전히 잡는다"           HIT \
       'pytest 2>&1 | tail -2; echo "rc=$?"'
expect "R2 좁힘 짝: && 로 이어진 직후 읽기도 잡는다"             HIT \
       'make test | head -5 && echo $?'

echo "-- R2 false-positive lanes: the 7 shapes this repo actually ships --"
# Every one of these was hand-verified on 2026-07-31 as CORRECT: the final stage IS the command
# whose status is wanted. A detector that flags these is noise, and noise trains dismissal.
expect "FP grep -q is the test itself"    CLEAN 'echo "$pos" | grep -qE "$re"; rc=$?'
expect "FP grep compiles the regex"       CLEAN "printf '' | grep -E \"\$re\" >/dev/null 2>&1; rc=\$?"
# Path deliberately generic: naming a real unshipped script here would make this lane a shipped
# doc pointing at a file the package omits (caught by selfcheck's package-coverage rule).
expect "FP last stage is the script"      CLEAN "printf '%s' \"\$S\" | bash some-filter.sh - ; echo EXIT:\$?"
expect "FP command substitution assign"   CLEAN 'out=$(printf x | ( cd "$r" && bash hook 2>&1 )); rc=$?'
expect "FP no pipe at all"                CLEAN 'bash gate.sh; echo "exit=$?"'
expect "FP || fallback, not a pipe"       CLEAN 'stat -c %Y f || stat -f %m f || echo 0'
expect "FP pipefail set, explicit"        CLEAN 'set -o pipefail; bash gate.sh | tail -5; rc=$?'

echo "-- adversarial (found by the Axis-2 pass on this guard, 2026-07-31) --"
# A: grep is line-oriented, so `.*` never spanned a newline and every MULTI-LINE command missed.
#    This mattered more than the single-line case: the invocations that actually recur in this
#    project are multi-line. Caught by attacking the guard, not by the happy-path lanes.
expect "A multi-line pipe then \$?"        HIT   'bash gate.sh | tail -20
echo "exit=$?"'
expect "A multi-line, three statements"   HIT   'cd /r
make test | head -40
rc=$?'
expect "A multi-line stays CLEAN if legit" CLEAN 'cd /r
echo x | grep -q y
rc=$?'
# B: zsh accepts `$PIPESTATUS[0]` without braces; the brace-anchored regex missed it.
expect "B PIPESTATUS without braces"      HIT   'a | b; rc=$PIPESTATUS[0]'
expect "B braced form still caught"       HIT   'a | b; rc=${PIPESTATUS[0]}'  # portability-noqa: fixture string fed to pipe_verdict_guard.sh for static analysis, never executed by this shell

echo "-- D: statement-continuation flatten + wrapped filter (leg-C MED round, 2026-08-01) --"
# The blanket newline→`;` rewrite broke the CONTINUATION shapes: a newline after `|`/`&&` or a
# backslash-newline continues the statement, and inserting `;` un-matched R2 on exactly the
# multi-line pipelines the flatten exists to catch.
expect "D pipe-continuation newline then \$?"  HIT   'bash gate.sh |
tail -20
echo "exit=$?"'
expect "D &&-continuation newline then \$?"    HIT   'bash gate.sh | tail -3 &&
echo "exit=$?"'
expect "D backslash-continuation mid-args"     HIT   'bash gate.sh | tail \
-20; echo "exit=$?"'
expect "D pipe-continuation to grep -q CLEAN"  CLEAN 'bash gate.sh |
grep -q ok
rc=$?'
# Subshell/group wrapper around the filter is the same mistake one paren deeper.
expect "D subshell-wrapped filter"             HIT   'bash gate.sh | (tail -5); echo "exit=$?"'
expect "D subshell-wrapped filter, no args"    HIT   'bash gate.sh | (tail); rc=$?'
expect "D brace-group filter"                  HIT   'bash gate.sh | { tail -5; }; echo "exit=$?"'
expect "D subshell non-filter stays CLEAN"     CLEAN 'bash gate.sh | (grep -q ok); rc=$?'

echo "-- T: terra decorrelation round (2026-08-01) --"
# T2: |& merges stderr into the pipe — same verdict mistake, evaded the whitespace-anchored matcher.
expect "T |& then \$?"                         HIT   'false |& tail -5; echo "exit=$?"'
expect "T |& to grep -q stays CLEAN"           CLEAN 'false |& grep -q x; rc=$?'
expect "T |&-continuation newline then \$?"    HIT   'false |&
tail -5; echo "exit=$?"'
# T3: newline directly after the wrapper open used to insert `;` and un-match R2.
expect "T multiline subshell wrapper"          HIT   'false | (
tail -5
); echo "exit=$?"'
# T4: KNOWN FP, pinned as expected — the quote-blind join reads quoted multi-line data as a live
# pipeline (mention-as-data, advisory-tolerated; see the flatten comment in the guard).
expect "T quoted-data FP is pinned HIT"        HIT   "printf 'false |
tail; echo \$?'"

echo "-- T2: terra round-2 (defects the round-1 FIXES introduced) --"
# The wrapper matcher must require the filter to be the wrapper's FINAL command: when a real
# command follows it inside the group, `$?` is THAT command's status and the warning is an FP
# the pre-wrapper matcher never produced.
expect "T2 filter not last in group is CLEAN"  CLEAN 'false | (tail -5; test -n "$x"); echo "exit=$?"'
expect "T2 brace, filter not last is CLEAN"    CLEAN 'false | { tail -5; grep -q ok; }; rc=$?'
expect "T2 filter IS last in group still HIT"  HIT   'false | (sort; tail -5); echo "exit=$?"'
expect "T2 wrapped filter alone still HIT"     HIT   'false | (tail -5); echo "exit=$?"'
# The `;` in branch (b)'s prefix keeps the filter at a statement start — a bare word ending in a
# filter name must not satisfy it.
expect "T2 bare word inside group is CLEAN"    CLEAN 'false | (echo cat); rc=$?'
# KNOWN MISS, pinned so it cannot be silently "fixed" into a worse trade: a comment inside the
# wrapper hides the closer. The available fix (strip `#…`) is quote-blind and would turn the
# NEXT lane — a real, currently-caught shape — into a miss. Recall loss accepted, direction chosen.
expect "T2 comment-in-group is a KNOWN MISS"   CLEAN 'false | (tail -5; # note
); rc=$?'
expect "T2 url-fragment shape must stay HIT"   HIT   'curl "https://x.dev/a#frag" | tail -3; rc=$?'

echo "-- E: spec'd-but-unpinned shapes (triad-lens Sonnet floor run, 2026-08-01: F1/F3) --"
# F1: the guard names five display filters; only three had lanes — less/more were shipped-but-unverified.
expect "E less then \$?"                       HIT   'bash gate.sh | less; echo "exit=$?"'
expect "E more then \$?"                       HIT   'make test | more; rc=$?'
# F3: unparsed/absent payload → silent, spec'd in the header but never pinned (siblings pin theirs).
e_out=$(printf '%s' 'not json' | bash "$G" 2>&1); e_rc=$?
if [ "$e_rc" -eq 0 ] && [ -z "$e_out" ]; then
  printf '  ✅ %-52s OK\n' "E malformed payload: silent exit 0"; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s\n' "E malformed payload: silent exit 0" "$e_rc" "$e_out"; fail=$((fail+1))
fi
e_out=$(python3 -c 'import json;print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"/x"}}))' | bash "$G" 2>&1); e_rc=$?
if [ "$e_rc" -eq 0 ] && [ -z "$e_out" ]; then
  printf '  ✅ %-52s OK\n' "E non-Bash tool: silent"; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s\n' "E non-Bash tool: silent" "$e_rc" "$e_out"; fail=$((fail+1))
fi

echo "-- opt-out --"
expect "noqa suppresses"                  CLEAN 'bash g.sh | tail; rc=$?  # noqa: pipe-verdict'

echo "-- C: delivery channel (closes N=8 — detection without delivery is decoration) --"
# These lanes assert the CHANNEL, not the detection: per the hook contract, on exit 0 only stdout
# JSON reaches anyone (additionalContext → model, systemMessage → user); stderr is discarded.
# A lane that only greps merged output would stay green while the warning goes nowhere — which is
# exactly the hole the 2026-07-31 rewrite closed. Verdicts are exit codes, not free-form stdout.
# NAMED RESIDUAL (cross-family LOW, accepted): $(…) capture strips NUL bytes, so a mutant emitting
# NUL+JSON would pass C1. The producer's hits text is static ASCII+⚠️ with no NUL source, so the
# lane does not pay for a byte-exact harness; revisit only if the producer ever emits dynamic bytes.
HIT_CMD='bash x.sh | tail -5; echo "exit=${PIPESTATUS[0]}"'  # portability-noqa: fixture string fed to the guard for static analysis, never executed by this shell
payload() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1"; }

# All C lanes measure ONE invocation: stdout, stderr, and exit code from the same run (a pair of
# runs can each satisfy half the contract while no single run satisfies it — cross-family finding).
c_errf=$(mktemp)

# C1 — advisory hit, full hook payload path: stdout must be one JSON object carrying
#      additionalContext + systemMessage, with permissionDecision ABSENT (emitting "allow" would
#      auto-approve the flagged command — the guard must never grant what it questions). exit 0.
c_out=$(payload "$HIT_CMD" | bash "$G" 2>"$c_errf"); c_rc=$?
c_err=$(cat "$c_errf")
if [ "$c_rc" -eq 0 ] && printf '%s' "$c_out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
h = d["hookSpecificOutput"]
assert h["hookEventName"] == "PreToolUse"
assert "PIPE-VERDICT" in h["additionalContext"]
assert "PIPE-VERDICT" in d["systemMessage"]
assert "permissionDecision" not in h and "permissionDecision" not in d
' 2>/dev/null; then
  printf '  ✅ %-52s %s\n' "C1 advisory: stdout JSON, no permissionDecision" OK; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s err=%s\n' "C1 advisory: stdout JSON, no permissionDecision" "$c_rc" "$c_out" "$c_err"; fail=$((fail+1))
fi

# C2 — block mode: exit 2, warning on stderr (stdout JSON is ignored by contract on exit 2).
c_out=$(payload "$HIT_CMD" | FH_PIPE_VERDICT_BLOCK=1 bash "$G" 2>"$c_errf"); c_rc=$?
c_err=$(cat "$c_errf")
if [ "$c_rc" -eq 2 ] && printf '%s' "$c_err" | grep -q 'PIPE-VERDICT' && [ -z "$c_out" ]; then
  printf '  ✅ %-52s %s\n' "C2 block: exit 2, stderr carries the reason" OK; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s err=%s\n' "C2 block: exit 2, stderr carries the reason" "$c_rc" "$c_out" "$c_err"; fail=$((fail+1))
fi

# C3 — clean command through the full payload path: NO JSON at all (an empty advisory would still
#      inject an empty reminder every Bash call — silence must stay silent). exit 0.
c_out=$(payload 'echo hello' | bash "$G" 2>"$c_errf"); c_rc=$?
rm -f "$c_errf"
if [ "$c_rc" -eq 0 ] && [ -z "$c_out" ]; then
  printf '  ✅ %-52s %s\n' "C3 clean: no emission at all" OK; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s\n' "C3 clean: no emission at all" "$c_rc" "$c_out"; fail=$((fail+1))
fi

# C4 — hostile inherited codec: the hits text is non-ASCII (⚠️), and an environment-inherited
#      PYTHONIOENCODING=ascii was measured (2026-07-31) to abort json.dumps and silently restore
#      the pre-fix delivery loss. The guard pins PYTHONUTF8=1; this lane keeps that pin honest.
c_out=$(payload "$HIT_CMD" | PYTHONIOENCODING=ascii bash "$G" 2>/dev/null); c_rc=$?
if [ "$c_rc" -eq 0 ] && printf '%s' "$c_out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert "PIPE-VERDICT" in d["hookSpecificOutput"]["additionalContext"]
' 2>/dev/null; then
  printf '  ✅ %-52s %s\n' "C4 ascii-codec env: JSON still delivered" OK; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s\n' "C4 ascii-codec env: JSON still delivered" "$c_rc" "$c_out"; fail=$((fail+1))
fi

# ── R3 — redirection-only statement (zsh NULLCMD=cat reads an open-pipe stdin). Measured 2026-09-04:
# nine `git commit -q -F - <<'CEOF' … CEOF ⏎ 2>&1)` tasks in two sessions hung after the commit landed.
# Fixtures are the measured shape verbatim (P), the same shape with the redirect moved onto the
# command line (N1 — the one-token fix), and a one-word markdown blockquote INSIDE the heredoc body
# (N2 — data, not a redirection; must stay CLEAN or the guard fires on every quoted commit message).
expect "R3 measured shape: bare 2>&1 line closes \$( )" HIT   $'out=$(git commit -q -F - <<\'CEOF\'\nfix: x\n\nbody\nCEOF\n2>&1); rc=$?; echo "commit rc=$rc"'
expect "R3 bare > file line after a heredoc"           HIT   $'cat <<\'EOF\'\nhello\nEOF\n> out.txt\necho done'
expect "R3 fixed: 2>&1 on the command line"            CLEAN $'out=$(git commit -q -F - 2>&1 <<\'CEOF\'\nfix: x\n\nbody\nCEOF\n); rc=$?; echo "commit rc=$rc"'
expect "R3 blockquote inside heredoc body is data"     CLEAN $'out=$(git commit -q -F - 2>&1 <<\'CEOF\'\nfix: x\n\n> 정본\n> see also)\nCEOF\n); rc=$?'

echo
if [ "$fail" -eq 0 ]; then
  echo "[pipe-verdict-guard] ✅ all $pass known pairs hold"; exit 0
else
  echo "[pipe-verdict-guard] ❌ $fail/$((pass+fail)) lanes failed"; exit 1
fi
