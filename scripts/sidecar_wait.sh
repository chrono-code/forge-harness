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

: > "$OUT"
"$@" > "$OUT" 2>&1 &
PID=$!

waited=0
last_size=0
# Poll rather than `wait`, so a live-but-quiet process is distinguishable from a dead one and the
# caller can SEE progress. A silent minute on a reasoning model is normal; the earlier misreading
# happened precisely because silence was treated as termination.
while kill -0 "$PID" 2>/dev/null; do
  if [ "$waited" -ge "$BUDGET" ]; then
    size=$(wc -c < "$OUT" 2>/dev/null | tr -d ' ')
    echo "SIDECAR_VERDICT=TIMEOUT waited=${BUDGET}s bytes=${size:-0} pid=$PID"
    echo "  the process is STILL RUNNING — this is not 'no output'. Raise the budget, or kill $PID" >&2
    exit 1
  fi
  sleep 5
  waited=$((waited + 5))
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
