#!/usr/bin/env bash
# fh_node_check.sh — per-NODE environment floor check, fired at SessionStart.
#
# WHY A NODE-SCOPED CHECK EXISTS:
#   A user's context (companion store, memory, session card) travels between machines; the machine's
#   own wiring does not. A rich context makes an unwired laptop read as "already configured".
#   Measured 2026-07-30: a machine holding the full companion store and memory ran sessions with its
#   SessionStart hooks unregistered; nothing surfaced it — it was found by accident.
#
# WHY IT IS NOT INSIDE fh_session_load.sh:
#   That script is registered in the gitignored .claude/settings.local.json, so on a fresh clone it
#   is not registered — the situation this check exists for is the one in which it could not run.
#   This script carries no operator-private path, so it can be registered from
#   templates/settings.SessionStart.snippet.json, which IS tracked and ships with a clone.
#   HONEST SCOPE: registration still requires the wizard to merge that snippet — every
#   .claude/settings*.json path in this repo is gitignored, so no SessionStart entry can be tracked.
#   The chicken-and-egg is REDUCED (script + snippet ship), not ELIMINATED (a user who never runs
#   the wizard still gets nothing). An earlier revision of this header claimed "survives a clone";
#   that was false, and a cross-family review caught it before merge. Do not restore the claim
#   without running `git check-ignore` on the settings paths first.
#
# EMISSION IS STATE-BASED, NOT EVENT-BASED — this is the load-bearing design decision:
#   A missing floor is a PERSISTENT CONDITION, so it is reported EVERY session until fixed.
#   A healthy machine is silent AFTER its one event line (first session / machine change / infra
#   delta) — events report once, conditions report until they stop being true.
#   Earlier revisions fired on events only (first session / machine change / idle >= 7 days / HEAD
#   advanced >= 20 commits) and that was wrong in both directions: on this hub's measured velocity
#   (~33 commits/week) the commit axis fired every ~4 days on a healthy machine (noise, and an
#   ignored detector cannot be revived), while a broken machine reported once then went quiet
#   forever — reproducing the very accident above.
#
# Detector, never a gate: always exits 0, and it RECOMMENDS — it cannot compel.
# State: tracks/_meta/.fh_node_state (gitignored; excluded from companion sync — it is machine-local
# by nature, and mirroring it would make node identity flap between machines).
# FH_NODE_STATE overrides the state path (used by the wizard's verification so that verifying does
# not consume a one-shot event report).

set -uo pipefail

FH="${HUB_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
STATE="${FH_NODE_STATE:-$FH/tracks/_meta/.fh_node_state}"

NODE_ID="${FH_MACHINE_ID:-$(hostname -s 2>/dev/null || echo unknown)}"
HEAD_NOW="$(git -C "$FH" rev-parse --short HEAD 2>/dev/null || echo none)"
NOW="$(date +%s)"

PREV_ID=""; PREV_EPOCH=0; PREV_HEAD=""
if [ -f "$STATE" ]; then
  IFS='|' read -r PREV_ID PREV_EPOCH PREV_HEAD < "$STATE" 2>/dev/null || true
fi
# Never feed a file-sourced value straight into arithmetic (bash arithmetic evaluates command
# substitution inside array subscripts).
case "${PREV_EPOCH:-}" in ''|*[!0-9]*) PREV_EPOCH=0 ;; esac

# ── floor probes — always run, before any decision about whether to speak ──────
MISS=""

# ① git-side floor. Probe the EXECUTABLE HOOK, not the config key: `core.hooksPath` unset is a
#    normal working install when hooks live in .git/hooks, and a set-but-empty path is a broken
#    install the key alone reports as fine. Resolve the directory with `git rev-parse --git-path`,
#    which handles set/unset, relative/absolute, AND linked worktrees (where .git is a file, so a
#    hand-built "$FH/.git/hooks" is simply wrong — FH runs worktree-isolated agents, so that path
#    is reachable, not hypothetical).
if ! git -C "$FH" rev-parse --git-dir >/dev/null 2>&1; then
  # NOT a git repo (plugin-only / marketplace install, or a non-repo directory). A git hook cannot
  # be installed here at all, so this floor is N/A — not missing. Applicability is decided
  # mechanically, per CLAUDE.md §Irreversibility Surface-Class: reporting it would print an
  # UNFIXABLE notice every session (emission is state-based), training the reader to ignore the
  # one check that must not be ignored.
  :
else
  # --path-format needs git >= 2.31; fall back to the relative form resolved against the repo root
  # (still correct in a linked worktree, where a hand-built "$FH/.git/hooks" does not exist at all).
  HD="$(git -C "$FH" rev-parse --path-format=absolute --git-path hooks 2>/dev/null)"
  if [ -z "$HD" ]; then
    _rel="$(git -C "$FH" rev-parse --git-path hooks 2>/dev/null || echo .git/hooks)"
    case "$_rel" in /*) HD="$_rel" ;; *) HD="$(git -C "$FH" rev-parse --show-toplevel 2>/dev/null || echo "$FH")/$_rel" ;; esac
  fi
  for h in pre-commit pre-push; do
    if [ ! -x "$HD/$h" ]; then
      MISS="${MISS}no executable ${h} hook · "
    elif ! grep -qE 'fh-gate|FH .*Gate|4-Axis|4축' "$HD/$h" 2>/dev/null; then
      # Executable is not the same proposition as OURS. husky and pre-commit-framework are standard
      # equipment in the JS/Python projects FH maps, and they install an executable pre-commit that
      # runs a linter — under an executable-only probe such a machine reports "floors present" and
      # then goes silent, which is precisely the accident this check exists to prevent.
      MISS="${MISS}${h} hook present but not FH's gate (another framework owns it) · "
    fi
  done
fi

# ② companion-load hook (Mode D only). Reported as INFORMATION, never as a missing floor: this hook
#    is registered for ALL users, and a public non-Mode-D user has no companion store to load, so
#    listing it under ❌ would be a false positive for the majority path.
#    APPLICABILITY: "is this a Mode D user", NOT "does settings.local.json exist". Keying on that
#    file was wrong in the worst possible way — it is gitignored, so a FRESH CLONE never has it, and
#    a fresh clone with a full companion store is EXACTLY the measured 2026-07-30 incident. The gate
#    silenced its own flagship case. Mode D signals that survive a clone: an exported BE_DIR, or the
#    operator's CLAUDE.local.md binding.
COMPANION_NOTE=""
_IS_MODE_D=""
{ [ -n "${BE_DIR:-}" ] && [ -d "$BE_DIR" ]; } && _IS_MODE_D=1
# CLAUDE.local.md is Claude Code's STANDARD local-override file — anyone may have one for any
# reason, and having one says nothing about a companion store. Keying on its EXISTENCE re-admitted
# the majority-path false positive through a second door, and state-based emission made it permanent
# rather than one-shot (cross-family review 2026-07-30). So key on the file MENTIONING a companion
# binding instead.
# The vocabulary spans every backend the wizard documents — the store is a ROLE, not a repo layout
# (Obsidian vault · gbrain ingest target · *-be repo all qualify), and an FH-flavoured regex would
# have silently excluded two first-class backends: the same "flagship case goes quiet" shape as the
# fresh-clone defect, one door over.
# HONEST SCOPE: this is a MENTION test, not a semantic one. "I do not use a companion store" also
# matches. The cost of that over-match is one informational line, never a floor claim — deliberately
# the cheap direction, since the expensive direction is silence.
[ -f "$FH/CLAUDE.local.md" ] \
  && grep -qiE 'BE_DIR|companion[ -]store|컴패니언|vault|gbrain|obsidian' "$FH/CLAUDE.local.md" 2>/dev/null \
  && _IS_MODE_D=1
if [ -n "$_IS_MODE_D" ] && ! command -v python3 >/dev/null 2>&1; then
  # not found ≠ 0: without a JSON parser the registration verdict is unknown, not clean.
  COMPANION_NOTE="companion-load registration UNMEASURED (no python3 — cannot parse the hook config; do not read this as 'registered')"
elif [ -n "$_IS_MODE_D" ]; then
  python3 - "$FH" <<'PY' || COMPANION_NOTE="companion-load SessionStart not registered (Mode D — freshness + env-delta will not fire at turn 0)"
import json, os, sys
hub = sys.argv[1]
for p in (os.path.join(hub, ".claude", "settings.local.json"),
          os.path.expanduser("~/.claude/settings.json")):
    try:
        groups = json.load(open(p)).get("hooks", {}).get("SessionStart", [])
    except Exception:
        continue
    if any("fh_session_load" in h.get("command", "") for g in groups for h in g.get("hooks", [])):
        sys.exit(0)
sys.exit(1)
PY
fi

# ── event: infra delta since the commit this clone last saw ───────────────────
# Reported ONCE per pull (it is an event). Distinguishes "no change" from "could not measure".
INFRA=""; INFRA_NOTE=""
if [ -n "$PREV_HEAD" ] && [ "$PREV_HEAD" != "$HEAD_NOW" ]; then
  if INFRA_RAW="$(git -C "$FH" diff --name-only "${PREV_HEAD}..HEAD" 2>/dev/null)"; then
    INFRA="$(printf '%s\n' "$INFRA_RAW" \
      | grep -E '^(templates/\.git-hooks/|templates/settings\.|scripts/fh_|plugins/[^/]+/skills/install-(wizard|doctor)/)' \
      | head -6)"
  else
    INFRA_NOTE="UNMEASURED — cannot reach the previously seen commit ($PREV_HEAD), so the infra delta was not computed (rebase, shallow clone, or GC). Not the same as 'nothing changed'."
  fi
fi

IDENTITY=""
if [ -z "$PREV_ID" ]; then IDENTITY="first session for this clone"
elif [ "$PREV_ID" != "$NODE_ID" ]; then IDENTITY="machine changed ($PREV_ID → $NODE_ID)"; fi

# ── state write — unconditional, and a failure is reported, never swallowed ────
# Writing only when the check speaks would make the recorded timestamp mean "last time it spoke",
# and a write failure would make this banner repeat forever with no explanation.
STATE_WARN=""
if ! { mkdir -p "$(dirname "$STATE")" 2>/dev/null \
       && printf '%s|%s|%s' "$NODE_ID" "$NOW" "$HEAD_NOW" > "$STATE" 2>/dev/null; }; then
  STATE_WARN="could not record node state ($STATE) — this notice may repeat every session"
fi

# ── emit: condition (every session) OR event (once) ───────────────────────────
[ -n "$MISS$COMPANION_NOTE$INFRA$INFRA_NOTE$IDENTITY$STATE_WARN" ] || exit 0

if [ -n "$MISS" ]; then
  echo "🖥️  [node] Missing mechanical floor on this machine (node: $NODE_ID): ${MISS% · }"
  echo "    → Run /install-doctor, then /install-wizard. A rich context (memory, companion store)"
  echo "      is a different proposition from this machine being wired."
elif [ -n "$IDENTITY" ]; then
  echo "🖥️  [node] $IDENTITY (node: $NODE_ID) — floors present."
fi
[ -n "$STATE_WARN" ] && echo "    ⚠️  $STATE_WARN"
[ -n "$COMPANION_NOTE" ] && echo "    ℹ️  $COMPANION_NOTE"
if [ -n "$INFRA_NOTE" ]; then
  echo "    ⚠️  $INFRA_NOTE"
elif [ -n "$INFRA" ]; then
  echo "    🆕 Install-relevant assets changed since this clone last ran — being registered is not"
  echo "       the same as being current, and a pull moves files without wiring hooks:"
  printf '%s\n' "$INFRA" | while IFS= read -r f; do [ -n "$f" ] && echo "       - $f"; done
  echo "    → Re-run /install-wizard (idempotent)."
fi

exit 0
