#!/usr/bin/env zsh
# forge-harness — periodic audit reminder (zshrc hook template)
#
# Checks elapsed days for each audit item every time a terminal opens,
# and prints a warning if the threshold is exceeded.
#
# ── Installation ──────────────────────────────────────────
#
#   1. Set environment variables in .zshrc:
#
#      export FH_DIR="$HOME/path/to/forge-harness"         # required
#      export CC_HUB_DIR="$HOME/path/to/your-cc-hub"       # if you have a CC hub
#      export CC_SENTINELS_DIR="$HOME/.cc_sentinels"        # project sentinels (optional)
#
#   2. Load the function using one of:
#
#      a) source "$FH_DIR/templates/fh_audit_check.zsh"    # source file directly
#      b) Paste the contents of this file into .zshrc       # standalone
#
# ── Auto-run (opt-in) ─────────────────────────────────────
#
#   Default is manual run (call _fh_audit_check directly).
#   To auto-run on terminal start, add to .zshrc:
#
#      export FH_AUDIT_AUTO=1
#
# ── Sentinel-based project audits ─────────────────────────
#
#   Quarterly/monthly project audits are tracked via sentinel files.
#   After completing an audit, touch the sentinel to reset the warning.
#
#     mkdir -p ~/.cc_sentinels
#     touch ~/.cc_sentinels/my_project_pfd          # record audit completion
#     export CC_SENTINEL_MY_PROJECT_PFD_DAYS=90     # set 90-day threshold
#
# ──────────────────────────────────────────────────────────

# mtime lookup (macOS / Linux compatible) — **GNU-first, and the order is load-bearing**.
# This was BSD-first (`stat -f %m || stat -c %Y`) and that is silently wrong on GNU/Linux: `-f`
# there means `--file-system`, so on a regular file it exits 0 and prints a filesystem report
# instead of an epoch — the `||` fallback never runs and the caller gets a multi-line blob that
# compares as garbage. Fixed 2026-08-15 after the identical bug was measured in
# scripts/digest_landing_check.sh (macOS 10/10 PASS · ubuntu 1/10 FAIL). Every other _mtime helper
# in this repo is already GNU-first (scripts/sync-from-be.sh:116 · scripts/fh_session_load.sh:105
# carry the same warning); this template copy was the straggler, and it ships to field harnesses.
_fh_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

_fh_audit_check() {
  local -a warns=()
  local now
  now=$(date +%s)

  # ① weekly_harvest — 7-day threshold (when CC_HUB_DIR is set)
  if [[ -n "${CC_HUB_DIR}" && -d "${CC_HUB_DIR}/tracks/_meta" ]]; then
    local aud
    aud=$(ls -t "${CC_HUB_DIR}/tracks/_meta"/harvest_*.md 2>/dev/null | head -1)
    if [[ -n "$aud" ]]; then
      local d=$(( (now - $(_fh_mtime "$aud")) / 86400 ))
      (( d >= 7 )) && warns+=("weekly_harvest ${d}d elapsed → run /harvest-loop in your CC hub cwd")
    else
      warns+=("No harvest history found → run /harvest-loop in your CC hub cwd")
    fi
  fi

  # ② frontier_diagnosis — 90-day threshold (when CC_HUB_DIR is set)
  if [[ -n "${CC_HUB_DIR}" && -d "${CC_HUB_DIR}/knowledge/shared/harness-core" ]]; then
    local fd
    fd=$(ls -t "${CC_HUB_DIR}/knowledge/shared/harness-core"/harness_frontier_diagnosis_*.md 2>/dev/null | head -1)
    if [[ -n "$fd" ]]; then
      local d=$(( (now - $(_fh_mtime "$fd")) / 86400 ))
      (( d >= 90 )) && warns+=("frontier_diagnosis ${d}d elapsed → run /frontier-digest in your CC hub cwd")
    fi
  fi

  # ③ FH sim Area B — 30-day threshold (when FH_DIR is set)
  if [[ -n "${FH_DIR}" && -d "${FH_DIR}/tracks/_meta" ]]; then
    local sim
    sim=$(ls -t "${FH_DIR}/tracks/_meta"/sim_*.md 2>/dev/null | head -1)
    if [[ -n "$sim" ]]; then
      local d=$(( (now - $(_fh_mtime "$sim")) / 86400 ))
      (( d >= 30 )) && warns+=("FH internal sim ${d}d elapsed → run /sim-conductor Area B in your FH cwd")
    fi
  fi

  # ④ Custom sentinels — per-file threshold in CC_SENTINELS_DIR (optional)
  #    Uppercase filename = env var key: CC_SENTINEL_{NAME}_DAYS (default 90)
  if [[ -n "${CC_SENTINELS_DIR}" && -d "${CC_SENTINELS_DIR}" ]]; then
    for f in "${CC_SENTINELS_DIR}"/*; do
      [[ -f "$f" ]] || continue
      local name="${${f:t}:u}"
      local key="CC_SENTINEL_${name}_DAYS"
      local threshold="${(P)key:-90}"
      local d=$(( (now - $(_fh_mtime "$f")) / 86400 ))
      (( d >= threshold )) && warns+=("${f:t} sentinel ${d}d elapsed → touch ${f} to reset")
    done
  fi

  # Output
  (( ${#warns[@]} == 0 )) && return
  print ""
  print "\033[33m── forge-harness Audit Reminders ────────────────────────\033[0m"
  for w in "${warns[@]}"; do
    print "\033[33m  ⚠  ${w}\033[0m"
  done
  print "\033[33m────────────────────────────────────────────────────────\033[0m"
  print ""
}
[[ "${FH_AUDIT_AUTO:-0}" == "1" ]] && _fh_audit_check
