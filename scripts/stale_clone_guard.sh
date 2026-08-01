#!/usr/bin/env bash
# stale_clone_guard.sh — PreToolUse(Write) advisory: building on a stale clone.
#
# THE DEFECT (fh_signal_2026-07-31_qasp-wiring)
#   found→extend is wired at the artifact/wiki level (R1-b), but nothing measures the LOCAL CLONE's
#   freshness before a build starts. Measured 2026-07-31: a session built an act2 router on a qasp
#   clone that was 46+ PRs behind origin — the tie-break lane it built already existed upstream, so
#   it manufactured a partial duplicate. The session-start load refreshes only the hub's own
#   companion store — mapped project clones are nobody's job, hence this guard.
#
# DESIGN
#   Trigger = Write (file creation — the mechanical proxy for "build work entry"), NOT session
#   start: fetching every mapped repo at session start is over-cost; the signal names work-entry
#   as the correct trigger. Throttle: once per repo per day (marker in TMPDIR) — the freshness
#   question is answered once, not per file.
#   Advisory contract identical to pipe_verdict_guard/destructive_pre_gate: stdout JSON
#   additionalContext (model) + systemMessage (user), NO permissionDecision, exit 0 always.
#   A guard about freshness must never block writing — it surfaces `behind N`, the session decides
#   (fetch may legitimately be skipped mid-hotfix).
#
# DEGRADE DIRECTION: fail-open everywhere — non-repo path, no upstream, fetch failure/timeout,
#   dead python3, detached HEAD: all silent exit 0. A freshness advisory that blocks or errors
#   trains hook resentment; the irreversible surfaces have their own gates.
#
# Test hooks (lanes): FH_STALE_CLONE_NO_FETCH=1 skips the network fetch (fixture repos already
#   carry their remote state); FH_STALE_CLONE_MARKER_DIR overrides the throttle dir.
#
# NAMED RESIDUALS (GPT pass 2026-08-01 — registered, not fixed; advisory proportionality):
#   day-scale throttle means an upstream advance AFTER the day's check goes unseen until tomorrow
#   (the incident class is day-scale, deliberate cost trade) · fork-canonical baseline (current
#   with origin/feature yet behind upstream/main) unmeasured — @{u} is the baseline · no-upstream /
#   detached HEAD silent · prune-free fetch can report a deleted upstream · nested-repo/submodule
#   ownership ambiguity on missing path levels · concurrent-Write double-fetch (duplicate advisory,
#   harmless) · CRC marker-key collision · dead python3 → inert (consistent with sibling guards).

set -u

RAW=$(cat)
FILE=$(printf '%s' "$RAW" | python3 -c '
import json,sys
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
if d.get("tool_name") != "Write": sys.exit(0)
sys.stdout.write(d.get("tool_input", {}).get("file_path", "") or "")
' 2>/dev/null) || FILE=""
[ -n "$FILE" ] || exit 0

# Creation-only scope (GPT pass): "build entry" means a NEW file — overwrites of existing files
# (generated output, doc touch-ups, conflict repair) neither fetch nor warn.
[ -e "$FILE" ] && exit 0

# Walk up to the nearest EXISTING ancestor — a Write may create several missing levels at once.
DIR=$(dirname "$FILE")
while [ ! -d "$DIR" ] && [ "$DIR" != "/" ] && [ -n "$DIR" ]; do
  DIR=$(dirname "$DIR")
done
[ -d "$DIR" ] || exit 0
ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0

# Throttle: one SUCCESSFUL check per repo per day. The marker is written only after a completed
# comparison (GPT pass: an attempt-marker turned every early-exit into a day-long silence).
# Default marker home is TMPDIR (user-private 0700 on macOS); the explicit subdir is created 0700
# so a /tmp fallback is not other-user-writable.
umask 077
MARKER_DIR="${FH_STALE_CLONE_MARKER_DIR:-${TMPDIR:-/tmp}/fh-stale-clone}"
mkdir -p "$MARKER_DIR" 2>/dev/null || exit 0
MARKER="$MARKER_DIR/$(printf '%s' "$ROOT" | cksum | cut -d' ' -f1)-$(date +%Y%m%d)"
[ -e "$MARKER" ] && exit 0

UPSTREAM=$(git -C "$ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || exit 0
REMOTE="${UPSTREAM%%/*}"   # fetch the remote @{u} actually tracks, not a hardcoded origin (GPT pass)
[ -n "$REMOTE" ] || exit 0

if [ "${FH_STALE_CLONE_NO_FETCH:-0}" != "1" ]; then
  # Bounded fetch: GIT_TERMINAL_PROMPT=0 kills the credential-prompt hang class; the hook-level
  # timeout is the hard bound for wedged transports (macOS ships no GNU timeout).
  GIT_TERMINAL_PROMPT=0 git -C "$ROOT" fetch -q "$REMOTE" 2>/dev/null || exit 0
fi

BEHIND=$(git -C "$ROOT" rev-list --count 'HEAD..@{u}' 2>/dev/null) || exit 0
case "$BEHIND" in ''|*[!0-9]*) exit 0 ;; esac
: > "$MARKER" 2>/dev/null || true   # comparison completed — only now does the day-throttle arm
[ "$BEHIND" -gt 0 ] || exit 0

MSG="  ⚠️  STALE-CLONE $ROOT is behind $UPSTREAM by $BEHIND commit(s).
      Building on a stale clone manufactures duplicates of work that already exists upstream
      (measured: a 46-PR-behind clone rebuilt an existing lane, 2026-07-31).
      Before creating new files here: git -C $ROOT pull --ff-only  (or rebase your branch).
      found→extend applies at repo level too — check what upstream already has."

if json_out=$(printf '%s' "$MSG" | PYTHONIOENCODING=utf-8 python3 -c '
import json, sys
h = sys.stdin.read()
print(json.dumps({
    "systemMessage": h,
    "hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": h},
}))
' 2>/dev/null) && [ -n "$json_out" ]; then
  printf '%s\n' "$json_out"
  exit 0
fi
printf '%s\n' "$MSG" >&2
exit 0
