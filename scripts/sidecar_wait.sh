#!/usr/bin/env bash
# sidecar_wait.sh — run a sidecar to COMPLETION and report a typed verdict about it.
#
# WHY THIS EXISTS (measured twice, 2026-07-28 and 2026-07-29)
#
#   A session dispatched `codex exec` and `agy -p` into the background and read their output files
#   one second and thirty seconds later. Both were empty at that moment, so the session recorded
#   "both sidecars returned 0-output", wrote that into a gate marker, a PR body, a session card and
#   a memory file, and did the adversarial work itself instead.
#
#   Both sidecars had in fact answered. codex produced 48 KB containing three findings — one HIGH
#   (a normalization collision that silently reroutes a link and then looks clean forever) and one
#   MED that showed the change was OVER-APPLIED. agy produced a HIGH of its own (anchor-form links
#   were counted as fixable but never rewritten, so the fixer broke idempotence and over-reported
#   its own writes). Every one was real; all were confirmed by execution and fixed.
#
#   So the failure was never the sidecars. It was reading a still-running process and calling the
#   silence a result. That mis-reading then propagated as a claim about ANOTHER system — the worst
#   shape a measurement error can take, because it retires a working mechanism.
#
#   The reflex fires mid-work and prose does not stop it (three consecutive card-last violations the
#   day before are the same lesson). So the wait becomes mechanical: this script will not emit a
#   verdict while the process is alive, and "no output" is only sayable after the process exits.
#
# VERDICTS (typed — grep these, never the prose)
#   SIDECAR_VERDICT=COMPLETE exit=<n> bytes=<n>   process exited on its own
#   SIDECAR_VERDICT=TIMEOUT  waited=<n>s bytes=<n> still alive when the budget ran out; NOT a result
#   SIDECAR_VERDICT=EMPTY    exit=<n>             exited cleanly having written nothing — the only
#                                                 state in which "the sidecar said nothing" is true
#
# Usage:
#   bash scripts/sidecar_wait.sh <outfile> <timeout_seconds> -- <command> [args...]
#   printf '%s' "$prompt" | bash scripts/sidecar_wait.sh out.txt 600 -- codex exec -m gpt-5.5 -
#
# Exit: 0 = COMPLETE (with or without output) · 1 = TIMEOUT (verdict withheld, not a failure claim)
set -uo pipefail

OUT="${1:?usage: sidecar_wait.sh <outfile> <timeout_s> -- <cmd...>}"
BUDGET="${2:?missing timeout seconds}"
shift 2
[ "${1:-}" = "--" ] && shift
[ $# -gt 0 ] || { echo "sidecar_wait: no command given" >&2; exit 2; }

# Forward stdin to the child with an explicit fd dup.
#
# The hole (measured 2026-07-29, known-pair): `"$@" > "$OUT" 2>&1 &` gave the child /dev/null for
# stdin in a non-interactive shell, so the documented pipe form reached codex with NO prompt, codex
# answered "No prompt provided via stdin", and this wrapper reported COMPLETE — the exact 0-output
# misjudgment it exists to prevent, produced by itself.
#
# `<&0` is the whole fix: POSIX substitutes /dev/null ONLY when stdin is not explicitly redirected.
# The first repair spooled stdin to a tempfile instead, and adversarial review (Axis 2) showed that
# mechanism was both unnecessary AND strictly worse than the bug — reproduced, not argued:
#   - the unbounded `cat` ran BEFORE the child, so an inherited never-EOF stdin hung the wrapper
#     forever and the timeout budget never applied (`-- true` with inherited stdin → rc=124);
#   - it CONSUMED the caller's stdin, so a caller reading 3 lines after the call read 0.
# A bounded-wait wrapper with an unbounded pre-step, and an input-preserving tool that eats input.
# The lesson is kept in the file: the simplest correct fix was one token, and the machinery built
# around it introduced two S-grade defects the original bug did not have.
: > "$OUT" || { echo "SIDECAR_VERDICT=OUTFILE_UNWRITABLE path=$OUT" >&2; exit 2; }
set -m   # own process group per child, so the TIMEOUT kill can reach grandchildren
if [ -t 0 ]; then
  # On a controlling tty, a child that READS stdin raises SIGTTIN and stops the whole process
  # group — the wrapper with it — so the budget never fires and no verdict is emitted (measured:
  # `cat` under a tty gave rc=124 and zero verdict lines, while `sleep 30` correctly TIMEOUTed).
  # Interactive callers have no prompt to pipe anyway; the documented pipe form is never a tty.
  "$@" < /dev/null > "$OUT" 2>&1 &
else
  "$@" <&0 > "$OUT" 2>&1 &
fi
PID=$!

waited=0
last_size=0
# Poll interval is overridable so the regression anchor is not charged the 5s floor per
# invocation (a 25s anchor is an anchor people skip).
POLL="${SIDECAR_POLL:-5}"
# Validate it. Caller-controlled and unvalidated, this knob RESTORED the very failure the wrapper
# exists to prevent (measured 2026-07-29, budget 3s under an external timeout 10):
#   SIDECAR_POLL=0    -> rc=124, `waited` never advances, TIMEOUT never fires, zero typed verdicts
#   SIDECAR_POLL=0.5  -> rc=124, arithmetic error each iteration, assignment never lands
#   SIDECAR_POLL=abc  -> exits 1 (the documented TIMEOUT code) with NO verdict line and a live child
# The file's own "a 25s anchor is an anchor people skip" comment invites tuning this, and `0.5` is
# the obvious next step for someone doing that. An unbounded wait must not be reachable by typo.
# `10#` forces base 10: `test` reads 08 as decimal-8 and PASSES it, then $((waited + 08)) dies with
# "value too great for base" every iteration, waited never advances, and the wait is unbounded again
# — the first guard did not close its own finding (measured: 08/09 -> rc=124, zero verdicts).
# The ceiling matters just as much: the budget is checked at the TOP of the loop, so any POLL above
# it makes the effective wait POLL, not BUDGET (SIDECAR_POLL=600 -> rc=124). 600 is exactly what
# someone copying the budget argument into the knob writes.
_poll_raw="$POLL"
case "$POLL" in ''|*[!0-9]*) POLL=5 ;; *) POLL=$((10#$POLL)) 2>/dev/null || POLL=5 ;; esac
{ [ "$POLL" -ge 1 ] && [ "$POLL" -le 60 ]; } 2>/dev/null || POLL=5
# Never coerce silently on a script whose whole thesis is a typed channel.
[ "$POLL" = "$_poll_raw" ] || [ -z "${SIDECAR_POLL:-}" ] || \
  echo "sidecar_wait: ignoring SIDECAR_POLL='$_poll_raw' (not an integer in 1..60); using $POLL" >&2
# Poll rather than `wait`, so a live-but-quiet process is distinguishable from a dead one and the
# caller can SEE progress. A silent minute on a reasoning model is normal; the earlier misreading
# happened precisely because silence was treated as termination.
while kill -0 "$PID" 2>/dev/null; do
  if [ "$waited" -ge "$BUDGET" ]; then
    size=$(wc -c < "$OUT" 2>/dev/null | tr -d ' ')
    echo "SIDECAR_VERDICT=TIMEOUT waited=${BUDGET}s bytes=${size:-0} pid=$PID"
    echo "  the process is STILL RUNNING — this is not 'no output'. Raise the budget if it needs longer." >&2
    # Kill the GROUP. `kill "$PID"` reaches only the direct child, so `sh -c 'sleep N & wait'`
    # left a live grandchild behind while the lane stayed green (measured wave 4).
    kill -- -"$PID" 2>/dev/null || kill "$PID" 2>/dev/null
    exit 1
  fi
  sleep "$POLL"
  waited=$((waited + POLL))
  size=$(wc -c < "$OUT" 2>/dev/null | tr -d ' ')
  if [ "${size:-0}" -ne "$last_size" ]; then
    echo "  … ${waited}s elapsed, ${size} bytes so far (alive)" >&2
    last_size=${size:-0}
  fi
done

wait "$PID"; rc=$?
size=$(wc -c < "$OUT" 2>/dev/null | tr -d ' ')
if [ "${size:-0}" -eq 0 ]; then
  echo "SIDECAR_VERDICT=EMPTY exit=$rc"
else
  echo "SIDECAR_VERDICT=COMPLETE exit=$rc bytes=$size"
fi
exit 0
