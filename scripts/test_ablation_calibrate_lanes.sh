#!/usr/bin/env bash
# test_ablation_calibrate_lanes.sh — regression lanes for scripts/ablation_calibrate.sh.
#
# Every FAILURE lane here reproduces a hole that was OPEN in the first draft and was closed on
# 2026-08-03 after a two-family adversarial round (codex + challenger); reverting the fix turns that
# lane red, which is the only thing that stops the hole coming back — each was found by review, none
# by the author. Lane 1 and the argument-hygiene lanes are not that: lane 1 exists so a file made
# entirely of failure cases cannot pass by over-blocking, and the argument lanes are ordinary input
# validation.
#
# No API spend — the LLM is swapped for a stub via the script's own `--runner` argv flag.
#
# ⚠️ SCOPE BOUNDARY. The stub short-circuits `invoke()`, so a green run here means the SCORING is
# sound — not that the isolation is. Some isolation guards are still reached (`pwd -P` → lane 20,
# per-arm `cd` → lane 9); `--tools ''` itself is NOT — deleting it leaves every lane below green.
# The authoritative, re-derivable list lives in ablation_calibrate.sh NAMED RESIDUAL 2, which also
# says how to re-derive it without spending API calls. Do not restate it here: keeping two copies
# of this boundary in sync is what produced three rounds of stale-claim findings.
#
# Usage: bash scripts/test_ablation_calibrate_lanes.sh
# Exit 0 = all lanes pass · 1 = a lane failed (the printed line says which)

set -uo pipefail
FH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CAL="$FH/scripts/ablation_calibrate.sh"
[ -r "$CAL" ] || { echo "❌ lanes: $CAL not readable" >&2; exit 1; }

TMP="$(mktemp -d)" || exit 1
trap 'rm -rf -- "$TMP"' EXIT
pass=0; fail=0

# A stub reads the prompt on stdin and answers per its mode, so a lane can hand the calibrator any
# runner behaviour — including the ones that used to be scored green.
mk_stub() {  # $1 = name, $2 = body
  local f="$TMP/$1.sh"
  { echo '#!/usr/bin/env bash'; echo 'in="$(cat)"'; echo "$2"; } > "$f"
  chmod +x "$f"
  printf '%s' "$f"
}

lane() {  # $1 = name, $2 = expected exit, $3.. = args to the calibrator
  local name="$1" want="$2"; shift 2
  local out rc
  out="$(bash "$CAL" "$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ]; then
    printf "  ✅ %-46s exit=%s\n" "$name" "$rc"; pass=$((pass+1))
  else
    printf "  ❌ %-46s exit=%s (want %s)\n" "$name" "$rc" "$want"; fail=$((fail+1))
    printf '%s\n' "$out" | sed 's/^/       | /' | head -12
  fi
}

echo "── ablation_calibrate lanes (stub runner, no API spend) ──"

# ── Lane 1 — the happy path still passes. A lane file whose every case is a failure case cannot
# tell "the guard works" from "the guard blocks everything" (over-blocking trains the override).
GOOD="$(mk_stub good '
case "$in" in
  *"dispatch ledger identifier"*) echo "NOT IN MY CONTEXT" ;;
  *"Widget Dispatch Gate"*|*"widget dispatch gate"*)
     case "$in" in *"exit code 47"*) echo "47" ;; *) echo "NOT IN MY CONTEXT" ;; esac ;;
  *) echo "NOT IN MY CONTEXT" ;;
esac')"
lane "known-good runner → lane pass (exit 4, untrusted)" 4 --runner "$GOOD"

# ── Lane 2 — INPUT ECHO. The first draft merged stderr into the scored stream, and every control
# token lives in the input (`exit code 47` in armP, the literal `NOT IN MY CONTEXT` in each
# question). One echo passed P, N and T at once. Must now be an INSTRUMENT ERROR, not a verdict.
ECHOER="$(mk_stub echoer 'printf "%s" "$in"')"
lane "runner echoes its input → instrument error" 1 --runner "$ECHOER"

# ── Lane 3 — DEAD RUNNER. A runner that fails must not be scored as "arm B could not answer",
# which is the silent uniform false KEEP.
DEAD="$(mk_stub dead 'echo "Error: Connect Timeout Error" >&2; exit 1')"
lane "runner exits nonzero → instrument error" 1 --runner "$DEAD"

# ── Lane 4 — EMPTY OUTPUT. Same class as lane 3 but with exit 0, which is the sneakier shape.
EMPTY="$(mk_stub empty 'exit 0')"
lane "runner returns empty stdout → instrument error" 1 --runner "$EMPTY"

# ── Lane 5 — UNANCHORED POSITIVE. `grep -q '47'` accepted `470`, `1147`, a temp path, a token
# count. The positive control must require a standalone 47 and no simultaneous decline.
FALSE47="$(mk_stub false47 '
case "$in" in
  *"dispatch ledger identifier"*) echo "NOT IN MY CONTEXT" ;;
  *"exit code 47"*) echo "Error: request failed (HTTP 470)" ;;
  *) echo "NOT IN MY CONTEXT" ;;
esac')"
lane "'470' must not satisfy the positive control" 3 --runner "$FALSE47"

# ── Lane 6 — INCOHERENT POSITIVE. A reply holding both the token and the decline is not a pass.
BOTH="$(mk_stub both '
case "$in" in
  *"dispatch ledger identifier"*) echo "NOT IN MY CONTEXT" ;;
  *) echo "exit code 47 — actually, NOT IN MY CONTEXT" ;;
esac')"
lane "answer + decline together → not a pass" 3 --runner "$BOTH"

# ── Lane 7 — TOOL LEAK. The whole point: a runner that can read the target must not be certified.
LEAKY="$(mk_stub leaky '
case "$in" in
  *"dispatch ledger identifier"*)
     f="$(printf "%s" "$in" | grep -oE "/[^ ]*/target/ledger\.md" | head -1)"
     if [ -r "$f" ]; then grep -oE "QZ[0-9A-Z-]+" "$f" | head -1; else echo "NOT IN MY CONTEXT"; fi ;;
  *"Widget Dispatch Gate"*|*"widget dispatch gate"*)
     case "$in" in *"exit code 47"*) echo "47" ;; *) echo "NOT IN MY CONTEXT" ;; esac ;;
  *) echo "NOT IN MY CONTEXT" ;;
esac')"
lane "runner CAN read the target → control failed" 3 --runner "$LEAKY"

# ── Lane 8 — BASELINE SEMANTICS. `--baseline` asserts the tool control can still FIRE. The first
# draft gated on "did anything fail", so a dead runner printed "baseline leaked as expected" and
# exited 0 — a green assembled out of an unrelated failure. Baseline now needs P ok · N ok · T LEAK.
lane "baseline + dead runner → NOT 'leaked as expected'" 1 --baseline --runner "$DEAD"
lane "baseline + blocked runner → baseline fails"        3 --baseline --runner "$GOOD"
lane "baseline + leaking runner → baseline passes"       4 --baseline --runner "$LEAKY"
# The shape that actually distinguishes the fix: a runner that LEAKS but whose positive control is
# broken. The old `fail -ne 0` gate read that as "leaked as expected" and exited 0 — a baseline
# certified by a runner that cannot answer anything. (Written after the first three baseline lanes
# stayed green under a reverted gate: they agreed with the bug on every input they carried.)
HALFLEAK="$(mk_stub halfleak '
case "$in" in
  *"dispatch ledger identifier"*)
     f="$(printf "%s" "$in" | grep -oE "/[^ ]*/target/ledger\\.md" | head -1)"
     if [ -r "$f" ]; then grep -oE "QZ[0-9A-Z-]+" "$f" | head -1; else echo "NOT IN MY CONTEXT"; fi ;;
  *) echo "Error: request failed (HTTP 470)" ;;
esac')"
lane "baseline + leak but broken P → baseline fails"     3 --baseline --runner "$HALFLEAK"

# ── Lane 9 — ARM ISOLATION. armP and armN shared one cwd, so a tool-enabled negative arm could read
# the answer off its neighbour instead of failing. Each arm now has its own directory: a runner that
# greps its cwd must NOT find the answer while running the negative arm.
NEIGHBOR="$(mk_stub neighbor '
case "$in" in
  *"dispatch ledger identifier"*) echo "NOT IN MY CONTEXT" ;;
  *) if grep -rqs "exit code 47" . ; then echo "47 (found in cwd)"; else
       case "$in" in *"exit code 47"*) echo "47" ;; *) echo "NOT IN MY CONTEXT" ;; esac; fi ;;
esac')"
lane "negative arm cannot read the positive arm" 4 --runner "$NEIGHBOR"

# ── Lane 10 — argument hygiene. `--reps 0` ran TWO reps on BSD seq (`seq 1 0` counts down).
lane "--reps 0 rejected"        1 --reps 0 --runner "$GOOD"
lane "--reps non-numeric rejected" 1 --reps x --runner "$GOOD"
lane "unknown option rejected"  1 --nope


# ── Lane 11 — A2: a STUBBED run must never reach the real "calibrated" exit code. The procedure
# states its precondition as `ablation_calibrate.sh must exit 0`; if a stub could produce 0, no
# caller could tell a lane run from a measurement ([[feedback_typed_verdict_channel]]).
# (Covered by every `--runner` lane above expecting 4 — asserted here explicitly so the contract is
# visible as its own line rather than as an incidental property of the other lanes.)
lane "stubbed success is exit 4, never 0" 4 --runner "$GOOD"

# ── Lane 12 — A1: the runner-exit-status check had NO discriminating lane. Lane 3's DEAD stub writes
# nothing, so the empty-stdout check caught it and the exit-status check could be deleted with the
# file still 15/15 green. This stub answers every control CORRECTLY and exits 1 — only the status
# check can catch it.
RC_USABLE="$(mk_stub rc_usable '
case "$in" in
  *"dispatch ledger identifier"*) echo "NOT IN MY CONTEXT" ;;
  *"exit code 47"*) echo "47" ;;
  *) echo "NOT IN MY CONTEXT" ;;
esac
echo "warning: retried once" >&2
exit 1')"
lane "nonzero exit WITH usable stdout → instrument error" 1 --runner "$RC_USABLE"

# ── Lane 13 — A1: P's `! declined` clause had no discriminating lane. Lane 6's stub answered the P
# and N questions identically, so it failed at N first. Here N is clean and only P is incoherent.
P_BOTH="$(mk_stub p_both '
case "$in" in
  *"dispatch ledger identifier"*) echo "NOT IN MY CONTEXT" ;;
  *"exit code 47"*) echo "exit code 47 — actually, NOT IN MY CONTEXT" ;;
  *) echo "NOT IN MY CONTEXT" ;;
esac')"
lane "P: token + decline in one reply → not a pass" 3 --runner "$P_BOTH"

# ── Lane 14 — A1: N's `! has_token` clause had no lane at all. A negative arm that declines AND then
# volunteers the answer from memory is not a clean decline.
N_LEAKY="$(mk_stub n_leaky '
case "$in" in
  *"dispatch ledger identifier"*) echo "NOT IN MY CONTEXT" ;;
  *"exit code 47"*) echo "47" ;;
  *) echo "NOT IN MY CONTEXT — though from memory it is 47" ;;
esac')"
lane "N: decline that still names the answer → not a pass" 3 --runner "$N_LEAKY"

# ── Lane 15 — S2: baseline must hold across ALL reps, not just the last. This stub fails P on rep 1
# and leaks only on rep 3; the per-rep-variable gate read the last rep and called it "P ok · N ok".
BASE_R1="$(mk_stub base_r1 "
c=\$(cat '$TMP/repcount' 2>/dev/null || echo 0)
case \"\$in\" in
  *'dispatch ledger identifier'*)
     c=\$((c+1)); echo \$c > '$TMP/repcount'
     if [ \$c -ge 3 ]; then echo 'QZ7734-WIDGET-LEDGER'; else echo 'NOT IN MY CONTEXT'; fi ;;
  *'exit code 47'*) if [ \$c -eq 0 ]; then echo 'Error: HTTP 470'; else echo '47'; fi ;;
  *) echo 'NOT IN MY CONTEXT' ;;
esac")"
rm -f "$TMP/repcount"
lane "baseline: rep-1 P failure is not masked by rep-3 leak" 3 --baseline --reps 3 --runner "$BASE_R1"
# ...and the lane above only proves that if three reps actually RAN. Pinning the loop to one rep left
# it green, so the exit code alone did not demonstrate the across-reps property it claims.
rm -f "$TMP/repcount"
reps_out="$(bash "$CAL" --baseline --reps 3 --runner "$BASE_R1" 2>&1)"
reps_seen="$(printf '%s\n' "$reps_out" | grep -c '^  rep')"
if [ "$reps_seen" -eq 3 ]; then
  printf "  ✅ %-46s reps=%s\n" "--reps 3 actually executes three reps" "$reps_seen"; pass=$((pass+1))
else
  printf "  ❌ %-46s reps=%s (want 3)\n" "--reps 3 actually executes three reps" "$reps_seen"; fail=$((fail+1))
fi

# ── Lane 16 — B2/B3: `--timeout 0` reported an armed watchdog and had none (`timeout 0` = no limit,
# `perl alarm 0` cancels the alarm), and no lane covered --timeout validation at all.
lane "--timeout 0 rejected"          1 --timeout 0 --runner "$GOOD"
lane "--timeout non-numeric rejected" 1 --timeout x --runner "$GOOD"


# ── Lane 17 — round 3 A2#5: stdout/stderr SEPARATION had no lane, and the header names stderr
# merging as the FIRST defect this file exists to prevent. This stub answers nothing useful on
# stdout and puts a perfectly-shaped answer on stderr; if the two streams are merged again, P scores
# green off a diagnostic.
STDERR_ANSWER="$(mk_stub stderr_answer '
case "$in" in
  *"dispatch ledger identifier"*) echo "NOT IN MY CONTEXT" ;;
  *"exit code 47"*) echo "warning: exit code 47 (cached)" >&2; echo "" ;;
  *) echo "NOT IN MY CONTEXT" ;;
esac')"
lane "answer on stderr must not score the control" 1 --runner "$STDERR_ANSWER"

# ── Lane 18 — round 3 A2#3: T's UNCLEAR branch. The code comment says an ambiguous tool control
# cannot certify the channel shut; nothing measured it. This stub neither declines nor leaks.
T_HEDGE="$(mk_stub t_hedge '
case "$in" in
  *"dispatch ledger identifier"*) echo "I would need to check that file to be sure." ;;
  *"exit code 47"*) echo "47" ;;
  *) echo "NOT IN MY CONTEXT" ;;
esac')"
lane "T hedges (neither decline nor leak) → control failed" 3 --runner "$T_HEDGE"

# ── Lane 19 — round 3 A2#6: the "temp dir resolved inside the repo" guard. Isolation is the whole
# experiment, so a TMPDIR pointing into the repo must be an instrument error, not a run.
TMPDIR="$FH/.ablation_lane_tmp.$$" bash -c 'mkdir -p "$TMPDIR"' 2>/dev/null
out="$(TMPDIR="$FH/.ablation_lane_tmp.$$" bash "$CAL" --runner "$GOOD" 2>&1)"; rc=$?
rm -rf "$FH/.ablation_lane_tmp.$$"
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'isolation void'; then
  printf "  ✅ %-46s exit=%s\n" "TMPDIR inside the repo → isolation void" "$rc"; pass=$((pass+1))
else
  printf "  ❌ %-46s exit=%s (want 1 + 'isolation void')\n" "TMPDIR inside the repo → isolation void" "$rc"; fail=$((fail+1))
  printf '%s\n' "$out" | sed 's/^/       | /' | head -6
fi

# ── Lane 20 — round 4 M26: `WORK_REAL="$(cd "$WORK" && pwd -P)"`. Lane 19 uses a REAL directory, so
# the unresolved path already matches "$FH"/* and the mutation survives it. Isolation is the central
# invariant of the experiment, and the guard that enforces it had no lane at all. A SYMLINK is what
# actually needs `pwd -P`: $TMPDIR points somewhere harmless that resolves into the repo.
LINKDIR="$TMP/linkfarm"; mkdir -p "$LINKDIR"
mkdir -p "$FH/.ablation_lane_link.$$"
ln -s "$FH/.ablation_lane_link.$$" "$LINKDIR/into_repo" 2>/dev/null
out="$(TMPDIR="$LINKDIR/into_repo" bash "$CAL" --runner "$GOOD" 2>&1)"; rc=$?
rm -rf "$FH/.ablation_lane_link.$$"
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'isolation void'; then
  printf "  ✅ %-46s exit=%s\n" "TMPDIR symlinked into repo → isolation void" "$rc"; pass=$((pass+1))
else
  printf "  ❌ %-46s exit=%s (want 1 + 'isolation void')\n" "TMPDIR symlinked into repo → isolation void" "$rc"; fail=$((fail+1))
  printf '%s\n' "$out" | sed 's/^/       | /' | head -6
fi

echo "── lanes: $pass passed · $fail failed ──"
[ "$fail" -eq 0 ] || exit 1
exit 0
