#!/usr/bin/env bash
# fh_env_delta_scan.sh — Mode D SessionStart ENVIRONMENT-DELTA detector (mechanical).
#
# WHY: FH's "undeployed-asset discovery + auto-mapping" (CLAUDE.md claim ②) works ONLY when a skill
# is explicitly invoked. The AUTONOMOUS half — "the environment changed (a new sibling repo pulled,
# a task-first session opened in an unmapped project) → detect it and propose setup" — did NOT exist
# in code. It was suppressed by the onboarding guards (metadata-is-not-intent, task-first skip), which
# are correct (they stop FALSE onboarding from branch-name metadata) but also silence GENUINE
# env-change setup. (Measured miss 2026-07-06: pulling pmh in the company env was not self-detected.
# Cross-family confirmed 2026-07-06: Claude workflow + codex both rated ② PARTIAL/THEATER, biggest 허풍.)
#
# WHAT: this is the SIBLING of scripts/fh_session_load.sh. That hook closes the companion-store
# FRESHNESS gap ("did the store change?"); THIS hook closes the CAPABILITY-SURFACE gap ("did the
# environment change?"). It scans the projects root for git repos that are neither mapped
# (tracks/{name}/ — the is-mapped signal, feedback_tracks_dir_is_mapped_signal) nor wizard-done
# (~/.cc_sentinels/{name}_wizard_done), and emits a ONE-LINE proposal into turn-0 context. It fires
# BEFORE the first user turn regardless of what the user types — so it closes the task-first salience
# gap mechanically, exactly as fh_session_load.sh does for freshness.
#
# INVARIANTS:
#  - PROPOSE, never auto-act. Detection is mechanical; mapping/install stays approval-gated (HITL).
#    The hook emits a proposal line; the agent decides whether to surface/act. (metadata-is-not-intent:
#    a mechanical fs delta is a proposal input, not an executed mapping.)
#  - ONE-LINE proposal, NOT the onboarding menu. The guards suppress menus for a reason; this is a
#    targeted delta, not a door skeleton.
#  - Silent no-op when nothing is new (no repos, or all mapped/wizard-done). Majority path = quiet.
#  - Offline-safe / fast: pure local filesystem, no network, maxdepth-1 scan.
#  - Non-Mode-D public users: harmless — it only ever PROPOSES /install-wizard --dry-run, which is
#    itself read-only. Still, gate on the hub being present so a bare plugin install stays silent.


# ── SessionStart source (단일 소스 lib) ─────────────────────────────────────────
_FH_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hook_source_lib.sh"
# shellcheck source=scripts/hook_source_lib.sh
if [ -f "$_FH_LIB" ]; then . "$_FH_LIB"; else
  fh_hook_source() { printf 'unknown\n'; }; fh_cadence_due() { return 0; }
fi
_FH_HOOK_SRC="$(fh_hook_source)"
set -u

# FH = the HUB, derived from THIS script's location ($FH/scripts/fh_env_delta_scan.sh → ../ = hub) —
# NOT from CLAUDE_PROJECT_DIR. (codex cross-family review 2026-07-06 [HIGH]: defaulting FH to
# CLAUDE_PROJECT_DIR made a hook run inside a new FIELD repo resolve FH to that field repo → the
# `tracks` guard failed → the hook silently did NOT fire in exactly the new-project scenario it exists
# for. Deriving from $0 makes FH correct wherever invoked.) HUB_DIR override still wins for tests.
FH="${HUB_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." 2>/dev/null && pwd)}"
FH="${FH:-$HOME/projects/forge-harness}"
ROOT="${FH_PROJECTS_ROOT:-$(dirname "$FH")}"
BE="${BE_DIR:-}"                          # companion store — never a mapping candidate
SENT="${CC_SENTINEL_DIR:-$HOME/.cc_sentinels}"

# Only operate where the hub actually exists (keeps bare-plugin installs silent).
[ -d "$FH/tracks" ] || exit 0
[ -d "$ROOT" ] || exit 0

_abspath() { CDPATH= cd -- "$1" 2>/dev/null && pwd; }
FH_ABS="$(_abspath "$FH")"
BE_ABS=""; [ -n "$BE" ] && BE_ABS="$(_abspath "$BE")"

# _candidate DIR → echoes basename if DIR is an unmapped mapping candidate, else nothing + returns 1.
# ONE predicate for BOTH sibling-scan and current-cwd (codex [MED]×2: cwd previously had weaker
# exclusions + ignored the skip sentinel → could propose the hub/companion/hidden repo and re-nag a
# skipped repo). [LOW]: `-e .git` (not `-d`) so git worktrees/submodules (`.git` is a file) count.
_candidate() {
  local d abs name
  abs="$(_abspath "$1")" || return 1
  [ -n "$abs" ] || return 1
  [ -e "$abs/.git" ] || return 1                       # real repo (dir OR file .git = worktree)
  name="$(basename "$abs")"
  [ "$abs" = "$FH_ABS" ] && return 1                   # not the hub
  [ -n "$BE_ABS" ] && [ "$abs" = "$BE_ABS" ] && return 1   # not the companion store
  case "$name" in _*|.*) return 1 ;; esac              # not underscore/hidden
  [ -d "$FH/tracks/$name" ] && return 1                # mapped (is-mapped signal)
  [ -f "$SENT/${name}_wizard_done" ] && return 1       # wizard already run
  [ -f "$SENT/${name}_mapping_skipped" ] && return 1   # operator skipped → mechanical no-re-nag
  printf '%s' "$name"
}

CANDIDATES=""
COUNT=0
for d in "$ROOT"/*/; do
  [ -d "$d" ] || continue
  name="$(_candidate "$d")" || continue
  [ -n "$name" ] || continue
  COUNT=$((COUNT + 1))
  [ "$COUNT" -le 6 ] && CANDIDATES="${CANDIDATES}${name}, "
done

# Current cwd itself an unmapped project? (the pmh-pull / task-first-in-new-project case) — SAME
# predicate, so identical exclusions + skip-sentinel apply.
CWD_UNMAPPED="$(_candidate "${CLAUDE_PROJECT_DIR:-$PWD}")" || CWD_UNMAPPED=""

# Nothing new → silent no-op (majority path).
# ── /clear·compact 억제는 **표시 판단보다 먼저** 접는다 ─────────────────────────
# sibling 줄은 «사람이 이미 보고 결정한 나그» 라 같은 세션에서 다시 안 띄운다. 반면 cwd-미매핑
# 줄은 «지금 그 안에서 일하고 있다» 는 상태라 /clear 직후에 오히려 필요하다 — 둘을 같이 묶지
# 않는다. ★출력 지점이 아니라 여기서 접는 이유: 뒤에서 접으면 sibling 만 있는 경우에
#   «변화 감지» 헤더가 찍히고 그 아래가 비는 알림이 나간다(=내용 없는 경보).
fh_cadence_due "$_FH_HOOK_SRC" || COUNT=0

[ "$COUNT" -eq 0 ] && [ -z "$CWD_UNMAPPED" ] && exit 0

# Emit the delta proposal (one block, imperative). Trim trailing ", ".
LIST="${CANDIDATES%, }"
# Emit: keep it LOW-NOISE (target-tier sim 2026-07-06 [noise finding]: naming irrelevant repos on a
# task-first entry reads as a nag). The current-cwd case is the high-signal one (the pmh-pull scenario
# = you are working IN an unmapped project right now); siblings collapse to a count + a single
# actionable (/install-wizard --dry-run), not a named list.
{
  echo "⚙️ [FH env-delta] capability-surface change detected (mechanically, even on task-first entry):"
  if [ -n "$CWD_UNMAPPED" ]; then
    echo "  • ★ current cwd '$CWD_UNMAPPED' is an UNMAPPED project — you are working in it now; propose mapping it (auto_project_mapping, HITL)."
  fi
  if [ "$COUNT" -gt 0 ]; then
    echo "  • $COUNT unmapped sibling repo(s) under $ROOT — run \`/install-wizard --dry-run\` to review + map (HITL); skip via touch \"$SENT/<name>_mapping_skipped\" (mechanical, no re-nag)."
  fi
  # Honest scope (target-tier sim [surfacing residual]): this hook mechanizes the CONTEXT-INJECTION
  # half of claim ② — the env-change now reliably REACHES turn-0 context. It does NOT mechanize the
  # SURFACING half (whether the model mentions it to the operator), which stays salience-dependent —
  # a model cannot be mechanically forced to emit. Surface this in ONE line if the cwd is unmapped;
  # for siblings-only, mention at most once and never derail an explicit task.
}
exit 0
