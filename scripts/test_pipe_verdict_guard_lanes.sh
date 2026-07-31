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
expect "R1 the measured shape"            HIT   'bash x.sh | tail -5; echo "exit=${PIPESTATUS[0]}"'
expect "R1 any index"                     HIT   'a | b; rc=${PIPESTATUS[1]}'
expect "R1 inside a larger command"       HIT   'cd /r && npm t | tail; E=${PIPESTATUS[0]}; echo $E'
# zsh's own spelling is correct here and must never be flagged.
expect "R1 zsh spelling is CLEAN"         CLEAN 'a | b; rc=$pipestatus[1]'

echo "-- R2: display-filter final stage, then \$? --"
expect "R2 tail then \$?"                  HIT   'bash gate.sh | tail -20; echo "exit=$?"'
expect "R2 head then \$?"                  HIT   'make test | head -40; rc=$?'
expect "R2 cat then \$?"                   HIT   'run.sh | cat; if [ $? -ne 0 ]; then echo bad; fi'

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
expect "B braced form still caught"       HIT   'a | b; rc=${PIPESTATUS[0]}'

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
HIT_CMD='bash x.sh | tail -5; echo "exit=${PIPESTATUS[0]}"'
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

echo
if [ "$fail" -eq 0 ]; then
  echo "[pipe-verdict-guard] ✅ all $pass known pairs hold"; exit 0
else
  echo "[pipe-verdict-guard] ❌ $fail/$((pass+fail)) lanes failed"; exit 1
fi
