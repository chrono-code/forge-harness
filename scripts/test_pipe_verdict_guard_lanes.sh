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

echo
if [ "$fail" -eq 0 ]; then
  echo "[pipe-verdict-guard] ✅ all $pass known pairs hold"; exit 0
else
  echo "[pipe-verdict-guard] ❌ $fail/$((pass+fail)) lanes failed"; exit 1
fi
