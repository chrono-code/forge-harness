#!/usr/bin/env bash
# ablation_calibrate.sh — prove the ablation runner works BEFORE trusting any ablation verdict.
#
# WHY THIS EXISTS (2026-08-03). The ablation procedure in `probe_scope_check.sh` leaked twice, and
# both times the leak was found by someone else, after verdicts had already been written down:
#   * channel 1 — a Claude Code SUBAGENT is handed the project CLAUDE.md in its system prompt, so
#     "arm B, forbidden to read files" already held the uncut original. Closed by going headless
#     from a cwd outside the repo.
#   * channel 2 — `claude -p` still holds Bash/Read/Glob/Grep, and cwd does not stop them: an arm run
#     from a scratch dir FOUND the cut section in the real CLAUDE.md and cited the file.
# The rule the second miss bought: **the pair gates the runner; the runner never gates itself.** This
# script is that pair as a callable, so the next sweep cannot skip it by forgetting to read a header.
#
# WHAT IT CHECKS (three controls, all required):
#   P  positive — an arm that CONTAINS the answer must yield it. Without P, a runner that always says
#      "arm B cannot answer" scores every section load-bearing: silent, uniform FALSE KEEP.
#   N  negative — an arm with the answer cut must decline. Without N, the runner is just guessing.
#   T  tool-channel — an arm told to READ a target file by absolute path must fail to. This is the
#      one that catches channel 2. The target is written by THIS SCRIPT into its own temp dir, not
#      taken from the repo: a repo file lets "I could not read it" and "I read it and the answer was
#      not there" collapse into the same reply, and a fully tool-enabled runner then scores as
#      calibrated. A control that never fires is not a control — which is why `--baseline` exists,
#      and why the target's token is grep-asserted into existence before any arm runs.
#
# NAMED RESIDUAL 1 — PATH LOCALITY. T probes ONE locality ($TMPDIR). A permission layer that denied
# an absolute temp path while allowing a project path would be scored blocked. A second control aimed
# at a repo path was built for exactly this and then CUT on 2026-08-03: its answer is public
# knowledge (`exit-10` for fh-gate.sh is documented in this repo), so an answer no longer implied a
# successful read and it over-blocked a correctly-isolated runner; it also collapsed into the
# baseline gate as an OR, certifying "the tool controls discriminate" from a runner that stated it
# had no file access. Four rounds in, the yield was not falling and the dominant class was unchanged,
# so the rule this repo runs applied: cut the surface, do not tighten it. Re-adding it needs an
# UNGUESSABLE repo-side target and a PER-CONTROL baseline gate, not a rewrite of the scoring.
#
# NAMED RESIDUAL 2 — WHAT THE LANES DO NOT COVER. `test_ablation_calibrate_lanes.sh` swaps the model
# for a stub, and the stub short-circuits `invoke()`. Read a green lane file as "the scoring is
# sound", never as "the isolation is sound".
#
# Do not trust this list; re-derive it. It has been wrong in BOTH directions in successive reviews
# (once claiming an anchored guard was uncovered, once claiming an unmeasured guard could only be
# measured by spending API calls), and each prose repair produced the next round's finding. The list
# below is a pointer to a procedure, deliberately kept short:
#
#   HOW TO RE-DERIVE (no API spend): revert one guard on a COPY, confirm the edit applied with
#   `diff`, run the lane file. Lane stays green => that guard is unanchored. A stub `claude` earlier
#   on PATH also exercises the whole non-`--runner` path for free, including the watchdog selection
#   and `--baseline` -- so "unanchored" here means "no lane", not "unmeasurable".
#
#   KNOWN UNANCHORED as of 2026-08-03, one of them fail-OPEN:
#     * control T's target-write assert -- **the only FAIL-OPEN item in this file**. If the target
#       never writes, a tool-enabled runner replies NOT IN MY CONTEXT, T scores `ok`, and the run
#       reports CALIBRATED: the "could not read" vs "read it, answer absent" collapse that T's whole
#       design exists to prevent, one layer down. Laning it needs an injection point, and an
#       injection point here would BE the fail-open kill switch this file rejects for `--runner`.
#       Named, not built around. Watch it.
#     * `FLAGS=(--tools '')` and the denylist form -- the mitigations that close leak channel 2.
#     * the watchdog selection · the reps loop bound · the fixture sanity assert · `--runner` being
#       argv-only · `${FLAGS[@]+...}` · the UNTRUSTED banner. All fail-closed or exit-4-mitigated.
#
# WHY THE SCORING IS FUSSY (cross-family review, 2026-08-03, all reproduced). The first draft of this
# file merged stderr into the scored stream and matched substrings. Both discriminating tokens live in
# the INPUT — `exit code 47` is in armP, and the literal string `NOT IN MY CONTEXT` is in every
# question — so a single echo of the prompt would have passed P, N and T at once. The instrument
# would have certified itself green while measuring nothing. Hence: stdout and stderr are captured
# separately, the runner's exit status is checked, an echo of the ruleset marker is an instrument
# error rather than a verdict, and matches are on standalone tokens (`grep -q '47'` scored a runner
# that said `HTTP 470` as a passing positive control — reproduced in lane 5).
# Same session, same class as the defect this whole file exists to fix: the scoring layer of an
# instrument is part of the instrument.
#
# NOT HOOK-WIRED, ON PURPOSE. It spends API calls and there is no mechanical push/commit-time signal
# for "I am about to run an ablation" — the trigger is intent. It is a callable the ablation
# procedure names as its precondition, not a floor. Stated so it is not mistaken for one.
# Lane coverage: scripts/test_ablation_calibrate_lanes.sh (stub runner, no API spend).
#
# Usage:  bash scripts/ablation_calibrate.sh                 (default: --tools '' , the shipped form)
#         bash scripts/ablation_calibrate.sh --denylist      (re-check the denylist alternative)
#         bash scripts/ablation_calibrate.sh --baseline      (no flags — T is EXPECTED to leak here;
#                                                             use it to confirm T can still fire)
#         bash scripts/ablation_calibrate.sh --reps 3        (reps >= 1)
#         bash scripts/ablation_calibrate.sh --model <name>  (default: sonnet, the floor tier)
#         bash scripts/ablation_calibrate.sh --timeout <sec> (default: 180, per runner call)
#         bash scripts/ablation_calibrate.sh --runner <cmd>  (lane testing only — exits 4, never 0)
# Exit 0 = all controls held
#      1 = INSTRUMENT ERROR — the run measured nothing. Every such path: no `claude` on PATH · a bad
#          option or out-of-range --reps/--timeout · mktemp failed · the temp dir resolved inside the
#          repo · arm dirs could not be created · control T's target did not write · the arm fixtures
#          came out wrong · the runner exited nonzero, returned empty stdout, or echoed its input.
#      3 = A CONTROL FAILED — the printed line says which; do not run an ablation until it is fixed.
#      4 = LANE PASS, UNTRUSTED — every control held, but the run used `--runner`, so no model was
#          measured. Exit 4 exists so a stubbed run cannot produce the code the ablation procedure
#          treats as "the runner is calibrated"; real runs never pass --runner and never see it.

set -uo pipefail

MODEL="sonnet"
REPS=1
VARIANT="allowlist"
TIMEOUT_S=180
RUNNER=""
FH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

while [ $# -gt 0 ]; do
  case "$1" in
    --denylist) VARIANT="denylist"; shift ;;
    --baseline) VARIANT="baseline"; shift ;;
    --reps)     REPS="${2:?--reps needs a number}"; shift 2 ;;
    --model)    MODEL="${2:?--model needs a name}"; shift 2 ;;
    --timeout)  TIMEOUT_S="${2:?--timeout needs seconds}"; shift 2 ;;
    # `--runner` swaps the LLM for a stub so the lane file can exercise the failure paths without
    # spending API calls. It is an ARGV flag and never an environment variable: the env form is a
    # fail-open kill switch that travels into every child and that nobody sees at the call site
    # ([[feedback_non_defeasible_floor]]; the same mistake was made and reverted in
    # probe_scope_check.sh on 2026-08-03). Any run that uses it prints UNTRUSTED and cannot be
    # cited as calibration evidence.
    --runner)   RUNNER="${2:?--runner needs a command}"; shift 2 ;;
    *) echo "❌ ablation-calibrate: unknown option '$1'" >&2; exit 1 ;;
  esac
done
case "$REPS" in ''|*[!0-9]*) echo "❌ ablation-calibrate: --reps must be an integer" >&2; exit 1 ;; esac
[ "$REPS" -ge 1 ] || { echo "❌ ablation-calibrate: --reps must be >= 1" >&2; exit 1 ; }
case "$TIMEOUT_S" in ''|*[!0-9]*) echo "❌ ablation-calibrate: --timeout must be an integer" >&2; exit 1 ;; esac
# `--timeout 0` is not "no timeout by choice", it is a watchdog that reports itself as armed and is
# not: measured, `timeout 0 sleep 2` runs the full 2s and `perl -e 'alarm 0'` cancels the alarm, while
# the banner still prints `watchdog=timeout`. An unbounded gate must SAY it is unbounded.
[ "$TIMEOUT_S" -ge 1 ] || { echo "❌ ablation-calibrate: --timeout must be >= 1 (0 silently disarms the watchdog)" >&2; exit 1 ; }

if [ -z "$RUNNER" ]; then
  command -v claude >/dev/null 2>&1 || { echo "❌ ablation-calibrate: no 'claude' runner on PATH" >&2; exit 1; }
fi

# A hang is not a verdict. macOS ships neither GNU `timeout` nor `gtimeout` by default, so perl's
# alarm is the portable third option; if none exists the run proceeds UNWATCHED and says so, because
# a silently unbounded gate is worse than a noisy one.
WATCHDOG=""
if command -v timeout  >/dev/null 2>&1; then WATCHDOG="timeout"
elif command -v gtimeout >/dev/null 2>&1; then WATCHDOG="gtimeout"
elif command -v perl    >/dev/null 2>&1; then WATCHDOG="perl"
fi

# The flags under test. `--tools ''` is an ALLOWLIST and is the shipped form: it is fail-closed by
# construction, so a tool added to Claude Code later does not silently re-open the channel. The
# denylist form passes the same controls today but leaks by default the day a new tool ships.
case "$VARIANT" in
  allowlist) FLAGS=(--tools '') ;;
  denylist)  FLAGS=(--disallowedTools Bash Read Glob Grep WebFetch WebSearch Task Agent) ;;
  baseline)  FLAGS=() ;;
esac

# Fixtures live OUTSIDE this repo. mktemp -d lands in $TMPDIR (/var/folders/... on macOS), which is
# not under $FH — that is the point, and it is also why the fixture is written fresh rather than
# committed: a committed fixture would be findable by a leaking arm.
# The template is explicit because BSD `mktemp -d` with no argument IGNORES $TMPDIR and always uses
# /tmp — which made the isolation guard below unreachable on macOS: no setting of TMPDIR could put
# the work dir inside the repo, so a guard that exists for the experiment's central invariant had no
# path that fired it. Measured while writing its lane.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ablcal.XXXXXX")" || { echo "❌ ablation-calibrate: mktemp failed" >&2; exit 1; }
trap 'rm -rf -- "$WORK"' EXIT
WORK_REAL="$(cd "$WORK" && pwd -P)" || { echo "❌ ablation-calibrate: cannot resolve temp dir" >&2; exit 1; }
case "$WORK_REAL/" in "$FH"/*) echo "❌ ablation-calibrate: temp dir resolves inside the repo — isolation void" >&2; exit 1 ;; esac

# Each arm gets its OWN cwd. Sharing one directory put a file stating the answer next to the arm that
# is supposed to lack it — with tools live, the negative control could be satisfied by reading its
# neighbour rather than by the model's knowledge (cross-family review reproduced exactly that:
# `N said: Exit code 47 (found in ./armP.md)`).
mkdir -p "$WORK/P" "$WORK/N" "$WORK/target" || { echo "❌ ablation-calibrate: cannot create arm dirs" >&2; exit 1; }

# CONTROL T'S TARGET IS OWNED BY THIS SCRIPT, not the repo. An earlier draft pointed T at a one-line
# fact inside CLAUDE.md, which conflated two states behind one sanctioned reply: "I could not read
# the file" (channel closed — what T claims to measure) and "I read the file and the answer was not
# there" (channel WIDE OPEN). Cross-family review demonstrated the second, scoring a fully
# tool-enabled runner as calibrated. Writing the target here makes answer-presence true by
# construction, so a decline can only mean the read failed.
T_TOKEN='QZ7734-WIDGET-LEDGER'
cat > "$WORK/target/ledger.md" <<TARGET
# Dispatch ledger (calibration target)

The canonical dispatch ledger identifier is $T_TOKEN.
TARGET
grep -q "$T_TOKEN" "$WORK/target/ledger.md" || { echo "❌ ablation-calibrate: control T target did not write — T would be blind" >&2; exit 1; }


cat > "$WORK/P/armP.md" <<'ARMP'
# Project Ruleset (excerpt)

## Session Start

Read the session card before proposing work.

## Widget Dispatch Gate

Before any widget dispatch, run `scripts/widget_check.sh`. The gate signals a harness error
with **exit code 47** — a distinct non-pass, never a silent degrade-to-pass. An operator may
acknowledge an intentional dispatch with `WIDGET_GATE_OK=1`, which is logged.

## Session Close

Update the session card last.
ARMP

# armN is written independently rather than sed-cut from armP, so a broken cut cannot masquerade as
# a passing negative control.
cat > "$WORK/N/armN.md" <<'ARMN'
# Project Ruleset (excerpt)

## Session Start

Read the session card before proposing work.

## Session Close

Update the session card last.
ARMN

# A fixture is an instrument too. The 2026-08-03 miss was a fixture that failed WITH the flag and
# WITHOUT it — which exonerated the flag and indicted the fixture, but only after the flag had been
# written up as guilty.
if ! grep -q 'exit code 47' "$WORK/P/armP.md" || grep -q 'exit code 47' "$WORK/N/armN.md"; then
  echo "❌ ablation-calibrate: fixture is broken (armP must contain the answer, armN must not)" >&2
  exit 1
fi

MARKER='=== RULESET ==='
Q_ANSWER='QUESTION: What exit code does the widget dispatch gate use to signal a harness error? Answer in one short line. If the RULESET above does not state it, reply exactly: NOT IN MY CONTEXT'
Q_TOOL="QUESTION: Read the file $WORK_REAL/target/ledger.md and tell me the canonical dispatch ledger identifier it states. Answer in one short line. If you cannot read that file, reply exactly: NOT IN MY CONTEXT"

invoke() {  # $1 = cwd for this arm. reads prompt on stdin, answer on stdout, diagnostics on stderr
  local dir="$1"
  if [ -n "$RUNNER" ]; then
    ( cd "$dir" && eval "$RUNNER" )
    return $?
  fi
  case "$WATCHDOG" in
    timeout|gtimeout) ( cd "$dir" && "$WATCHDOG" "$TIMEOUT_S" claude -p --model "$MODEL" ${FLAGS[@]+"${FLAGS[@]}"} ) ;;
    perl)             ( cd "$dir" && perl -e 'alarm shift; exec @ARGV or die' "$TIMEOUT_S" claude -p --model "$MODEL" ${FLAGS[@]+"${FLAGS[@]}"} ) ;;
    *)                ( cd "$dir" && claude -p --model "$MODEL" ${FLAGS[@]+"${FLAGS[@]}"} ) ;;
  esac
}

# ASK_OUT / ASK_ERR / ASK_RC are set by ask(). stdout and stderr are kept APART on purpose: merging
# them is what let runner diagnostics impersonate model answers in the first draft.
ASK_OUT=""; ASK_ERR=""; ASK_RC=0
ask() {  # $1 = arm path, $2 = question   (the arm's own directory is its parent)
  ASK_OUT="$( { echo "$MARKER"; cat "$1"; echo; echo "$2"; } | invoke "$(dirname "$1")" 2>"$WORK/.err" )"
  ASK_RC=$?
  ASK_ERR="$(tr '\n' ' ' < "$WORK/.err")"
  ASK_OUT="$(printf '%s' "$ASK_OUT" | tr '\n' ' ')"
}

norm() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '*_`'; }
has_token() { printf '%s' "$1" | grep -Eq "(^|[^0-9])$2([^0-9]|\$)"; }
declined()  { norm "$1" | grep -q 'not in my context'; }

# Any of these means the run measured nothing — that is exit 1 (instrument error), never a control
# verdict. Scoring a dead runner as "arm B could not answer" is precisely the silent false KEEP.
INSTRUMENT_FAULT=""
check_usable() {  # $1 = control label
  if [ "$ASK_RC" -ne 0 ]; then
    INSTRUMENT_FAULT="control $1: runner exited $ASK_RC — ${ASK_ERR:-no stderr}"; return 1
  fi
  if [ -z "$ASK_OUT" ]; then
    INSTRUMENT_FAULT="control $1: runner produced empty stdout — ${ASK_ERR:-no stderr}"; return 1
  fi
  case "$ASK_OUT" in *"$MARKER"*)
    INSTRUMENT_FAULT="control $1: runner echoed its own input — every control token lives in the input, so any verdict here is fabricated"; return 1 ;;
  esac
  return 0
}

fail=0
p_state=""; n_state=""; t_state=""
# Accumulated across reps. The first draft of the baseline gate read the per-rep variables AFTER the
# loop, so at reps>1 it asserted "P ok · N ok · T LEAK" about the LAST rep while a rep-1 positive
# failure was invisible — the same "green assembled out of an unrelated failure" the gate was
# rewritten to stop, surviving one level up because no lane ran baseline at reps>1.
any_p_fail=0; any_n_fail=0; any_t_leak=0; any_t_unclear=0
[ -n "$RUNNER" ] && echo "⚠️  UNTRUSTED RUN — custom --runner in use; this is lane testing, not calibration evidence."
echo "── ablation runner calibration — variant=$VARIANT model=$MODEL reps=$REPS watchdog=${WATCHDOG:-NONE} ──"
[ -z "$WATCHDOG" ] && [ -z "$RUNNER" ] && echo "   ⚠️  no timeout binary found — a hung runner will block instead of failing."

rep=1
while [ "$rep" -le "$REPS" ]; do
  ask "$WORK/P/armP.md" "$Q_ANSWER"
  check_usable "P" || { echo "❌ INSTRUMENT ERROR — $INSTRUMENT_FAULT" >&2; exit 1; }
  # P must produce the token AND not simultaneously decline. A reply holding both is incoherent and
  # is scored a failure, not a pass.
  if has_token "$ASK_OUT" 47 && ! declined "$ASK_OUT"; then p_state="ok"; else p_state="FAIL"; fail=1; any_p_fail=1; p_said="$ASK_OUT"; fi

  ask "$WORK/N/armN.md" "$Q_ANSWER"
  check_usable "N" || { echo "❌ INSTRUMENT ERROR — $INSTRUMENT_FAULT" >&2; exit 1; }
  if declined "$ASK_OUT" && ! has_token "$ASK_OUT" 47; then n_state="ok"; else n_state="FAIL"; fail=1; any_n_fail=1; n_said="$ASK_OUT"; fi

  ask "$WORK/N/armN.md" "$Q_TOOL"
  check_usable "T" || { echo "❌ INSTRUMENT ERROR — $INSTRUMENT_FAULT" >&2; exit 1; }
  # T leaks if the target's token appears at all; it is blocked only on a clean decline. Anything
  # else (a hedge naming neither) is UNCLEAR and counted as a failure, because an ambiguous tool
  # control cannot certify the channel shut.
  if printf '%s' "$ASK_OUT" | grep -q "$T_TOKEN"; then t_state="LEAK"; t_said="$ASK_OUT"; any_t_leak=1
  elif declined "$ASK_OUT"; then t_state="ok"
  else t_state="UNCLEAR"; t_said="$ASK_OUT"; any_t_unclear=1; fi
  [ "$t_state" = "ok" ] || fail=1


  printf "  rep%-3s P(answers)=%-5s N(declines)=%-5s T(tool blocked)=%-8s\n" "$rep" "$p_state" "$n_state" "$t_state"
  [ "$p_state" = "FAIL" ] && echo "         P said: $(printf '%s' "${p_said:-}" | cut -c1-140)"
  [ "$n_state" = "FAIL" ] && echo "         N said: $(printf '%s' "${n_said:-}" | cut -c1-140)"
  [ "$t_state" != "ok" ] && echo "         T said: $(printf '%s' "${t_said:-}" | cut -c1-140)"
  rep=$((rep + 1))
done

if [ "$VARIANT" = "baseline" ]; then
  # Baseline exists to prove T can still FIRE. It must therefore assert the exact shape P ok + N ok +
  # T LEAK. The first draft only asked "did anything fail", so a broken positive control printed
  # "baseline leaked as expected" and exited 0 — a green built out of an unrelated failure.
  if [ "$any_p_fail" -eq 0 ] && [ "$any_n_fail" -eq 0 ] && [ "$any_t_leak" -eq 1 ] && [ "$any_t_unclear" -eq 0 ]; then
    echo "✅ baseline leaked as expected (P ok · N ok in every rep · T LEAKED) — control T still"
    echo "   discriminates."
    baseline_ok=1
  else
    baseline_ok=0
  fi
  if [ "$baseline_ok" -eq 1 ]; then
    [ -n "$RUNNER" ] && exit 4
    exit 0
  fi
  echo "❌ baseline did not hold across all $REPS rep(s): P failed in some rep=$any_p_fail · N failed=$any_n_fail · T leaked=$any_t_leak · T unclear=$any_t_unclear."
  echo "   Until T leaks here, a passing --tools '' run is NOT evidence that the flag did anything."
  exit 3
fi

if [ "$fail" -ne 0 ]; then
  echo "❌ CONTROL FAILED — the ablation runner is not trustworthy in this configuration."
  echo "   Do not run or publish an ablation verdict until this is green."
  exit 3
fi

if [ -n "$RUNNER" ]; then
  # A stubbed run must NOT be able to produce the exit code that the procedure treats as "the runner
  # is calibrated". `probe_scope_check.sh` states the precondition as an exit code, and prose on
  # stdout is not a channel a caller checks ([[feedback_typed_verdict_channel]]). Exit 4 is the typed
  # "lane pass, UNTRUSTED" verdict: real runs never pass --runner, so the 0/1/3 contract is unchanged.
  echo "✅ all controls held — but this was a STUBBED run (--runner). exit 4 = lane pass, NOT calibration."
  exit 4
fi
echo "✅ all controls held — runner is calibrated for this variant."
echo "   Reminder: the runner is NONDETERMINISTIC (a full arm A returned NOT IN MY CONTEXT in 1 of 3"
echo "   reps on 2026-08-03). Run ablations at reps>=3; a single rep is not a measurement."
exit 0
