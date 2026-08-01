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
sys.stdout.buffer.write((d.get("tool_input", {}).get("file_path", "") or "").encode("utf-8"))
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
# Remote name resolution (leg-C LOW, 2026-08-01): `${UPSTREAM%%/*}` truncates a remote whose NAME
# carries `/` (git accepts them via config even though `git remote add` rejects them) — `a/b/main`
# became remote `a`, the fetch failed, and the guard went silently inert on exactly that clone.
# `%(upstream:remotename)` is git's own parse; the cut stays as fallback for git versions without it.
_HEAD_REF=$(git -C "$ROOT" symbolic-ref -q HEAD 2>/dev/null) || _HEAD_REF=""
REMOTE=""
[ -n "$_HEAD_REF" ] && REMOTE=$(git -C "$ROOT" for-each-ref --format='%(upstream:remotename)' "$_HEAD_REF" 2>/dev/null | head -1)
[ -n "$REMOTE" ] || REMOTE="${UPSTREAM%%/*}"   # fallback; never a hardcoded origin (GPT pass)
[ -n "$REMOTE" ] || exit 0

if [ "${FH_STALE_CLONE_NO_FETCH:-0}" != "1" ]; then
  # Internally-bounded fetch (leg-C MED, 2026-08-01): the previous hard bound was the RUNNER's
  # hook timeout (20s), which kills the whole guard — preempting the exit-0 contract AND skipping
  # the marker write, so a wedged transport re-stalled EVERY Write for the rest of the day
  # (20s × N calls, a session-killer). The guard now owns its bound: fetch in the background,
  # poll, and on expiry kill the fetch, ARM the day-throttle, exit 0. Arming on timeout is a
  # deliberate trade: one silent day on a broken-network machine (fail-open, the documented
  # degrade direction) beats a stall on every file creation. This is NOT the attempt-marker the
  # GPT pass rejected — that armed on every early exit; this arms only after a full budget spent
  # against a wedged transport. GIT_TERMINAL_PROMPT=0 still kills the credential-prompt class.
  # Budget: tenths of a second; default 150 (15s) stays under the snippet's 20s runner timeout.
  # CAPPED at 150 (terra round, 2026-08-01): an env-supplied budget > the runner timeout would
  # restore the exact runner-preemption this bound exists to remove. (No boundary lane on purpose
  # — it would idle its full 15s by construction; the cap is these three lines.)
  # LENGTH-first, then value (terra round 2, 2026-08-01): an all-digit literal wider than the
  # shell's integer width makes `[ "$x" -gt 150 ]` itself an ERROR ("integer expression expected" /
  # "number truncated"), so the numeric cap never ran and the value stayed unnormalized. Digits are
  # capped at 3 (max 999) before any arithmetic touches the value — safe in bash 3.2 and zsh alike.
  _BUDGET="${FH_STALE_CLONE_FETCH_BUDGET_TENTHS:-150}"
  case "$_BUDGET" in ''|*[!0-9]*) _BUDGET=150 ;; esac
  [ "${#_BUDGET}" -gt 3 ] && _BUDGET=150
  [ "$_BUDGET" -gt 150 ] && _BUDGET=150
  # stdout AND stderr to /dev/null: the child inherits this hook's stdout pipe, and a
  # still-running child holding it open would stall the hook runner past our own exit.
  GIT_TERMINAL_PROMPT=0 git -C "$ROOT" fetch -q "$REMOTE" >/dev/null 2>&1 &
  _FPID=$!
  _t=0
  while kill -0 "$_FPID" 2>/dev/null && [ "$_t" -lt "$_BUDGET" ]; do
    sleep 0.1; _t=$((_t+1))
  done
  if kill -0 "$_FPID" 2>/dev/null; then
    # No wait after the kill: a shell-script transport defers TERM until its foreground child
    # exits (measured: the lane's wedge shim held a wait for the full 30s hang). The child is
    # reparented at our exit; TERM is best-effort cleanup, the BOUND is the contract.
    kill "$_FPID" 2>/dev/null || true
    : > "$MARKER" 2>/dev/null || true
    exit 0
  fi
  wait "$_FPID" 2>/dev/null || exit 0
fi

BEHIND=$(git -C "$ROOT" rev-list --count 'HEAD..@{u}' 2>/dev/null) || exit 0
case "$BEHIND" in ''|*[!0-9]*) exit 0 ;; esac
: > "$MARKER" 2>/dev/null || true   # comparison completed — only now does the day-throttle arm
[ "$BEHIND" -gt 0 ] || exit 0

MSG="  ⚠️  STALE-CLONE $ROOT is behind $UPSTREAM by $BEHIND commit(s).
      Building on a stale clone manufactures duplicates of work that already exists upstream
      (measured: a 46-PR-behind clone rebuilt an existing lane, 2026-07-31).
      Advisory timing: this notice arrives with the Write already evaluated — reconcile NOW,
      before the next file: git -C '$ROOT' pull --ff-only  (or rebase your branch).
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
