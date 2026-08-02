#!/usr/bin/env bash
# substrate_jump_detector.sh — detect substrate-version jumps (the trigger that was a phantom).
#
# WHY: the substrate self-adaptation loop's initiate leg cited a "substrate-version jump trigger"
# that had NO detector (codex census 2026-07-10 refuted the self-assessment — the trigger existed
# only as inventory text). This is STRUCTURE-ENFORCING mechanization per the durable-mechanization
# criterion (sonnet_floor_doctrine.md): version drift lives OUTSIDE the session's context boundary —
# an infinitely strong model still cannot know what changed on the machine between sessions.
#
# WHAT: snapshots substrate versions to a gitignored state file; on the next run, diffs and emits
# a jump notice naming the doctrine's shed/advance pass. Silent when nothing changed.
# Wire: one line in the SessionStart hook (fh_session_load.sh) or run standalone.
#
# Exit: always 0 (detector, not gate). State: tracks/_meta/.substrate_versions (gitignored).

set -uo pipefail

FH="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE="$FH/tracks/_meta/.substrate_versions"

snapshot() {
  # one line per component: name=version (unavailable components recorded as absent — an
  # appearing/disappearing component is itself a jump)
  echo "claude=$(claude --version 2>/dev/null | head -1 || echo absent)"
  echo "codex=$(codex --version 2>/dev/null | head -1 || echo absent)"
  echo "agy=$(agy --version 2>/dev/null | head -1 || echo absent)"
  echo "node=$(node --version 2>/dev/null || echo absent)"
  echo "git=$(git --version 2>/dev/null || echo absent)"
  echo "os=$(uname -sr 2>/dev/null || echo absent)"
}

CURRENT="$(snapshot)"

if [ ! -f "$STATE" ]; then
  printf '%s\n' "$CURRENT" > "$STATE"
  echo "🧭 [substrate] baseline snapshot recorded ($(echo "$CURRENT" | wc -l | tr -d ' ') components)"
  exit 0
fi

PREV="$(cat "$STATE")"
if [ "$CURRENT" = "$PREV" ]; then
  # silent no-op — a detector that talks every session trains the reader to skip it
  exit 0
fi

echo "🧭 [substrate] VERSION JUMP detected — substrate loop initiate leg fires:"
# show only changed lines (name-keyed diff, bash-3.2 safe)
while IFS= read -r cur; do
  name="${cur%%=*}"
  old=$(printf '%s\n' "$PREV" | grep -m1 "^$name=" || echo "$name=<new>")
  [ "$cur" != "$old" ] && echo "   $old  →  $cur"
done <<EOF
$CURRENT
EOF
echo "   → run the shed/advance pass: re-check capability-compensating scaffolding against the new"
echo "     substrate (sonnet_floor_doctrine.md §durable-mechanization — shed what the model no longer"
echo "     needs, advance what the new substrate enables). Removals go through the 4-axis gate."
# Until 2026-08-02 the line above WAS the whole pass: an instruction with no instrument behind it, so
# nothing measured whether a rule still earned its residency. It now hands off to something runnable.
if [ ! -f "$FH/scripts/probe_scope_check.sh" ]; then
  echo "   (probe-scope check NOT run — scripts/probe_scope_check.sh absent. Expected in the npm"
  echo "    package, which ships neither the script nor its probe set; in a SOURCE checkout it is an"
  echo "    instrument gap, not a skip — selfcheck fails on exactly that state.)"
else
  echo ""
  echo "   ── probe Scope resolution (bash scripts/probe_scope_check.sh) ──"
  # Capture, THEN branch on rc — a pipe here would report the pipe's status, and a `sed` window keyed
  # on a line the tool no longer prints would swallow the whole result silently.
  _ps_out=$(bash "$FH/scripts/probe_scope_check.sh" 2>&1); _ps_rc=$?
  if [ "$_ps_rc" -ne 0 ]; then
    echo "   ⚠️  probe-scope check FAILED (exit $_ps_rc) — a probe points at a section that is not there."
    printf '%s\n' "$_ps_out" | sed 's/^/      /'
  else
    printf '%s\n' "$_ps_out" | grep -E 'control B|✅' | sed 's/^/   /'
  fi
  echo "   This says the probe set still points at real sections — NOT how much of the asset is"
  echo "   defended. Coverage measurement is unsolved; do not read a green check as 'fully probed'."
fi

printf '%s\n' "$CURRENT" > "$STATE"
exit 0
