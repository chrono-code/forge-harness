#!/usr/bin/env bash
# psa_scan_lib.sh — the ONE implementation of public-surface pattern loading and matching.
#
# WHY THIS FILE EXISTS
#   Three copies of this logic existed (pre-commit, pre-push, public_surface_scan_files.sh). Across a
#   single 2026-07-26 cross-family audit, EVERY confidentiality defect found was a divergence between
#   them, not a flaw in the idea:
#     • the publish copy checked that the override was readable and non-empty; the commit copy did not
#     • the commit copy failed closed when no patterns loaded; the publish copy did too; the push copy
#       had to be told separately
#     • a row with a SPACE instead of a TAB failed closed in two copies and was silently skipped in the third
#     • `head -1` per line (a placeholder shielding a real token) was fixed in one copy and not the others
#     • the LOW-severity file allowlist existed in one copy only — which is how the push gate blocked
#       its own first real push
#   Each was repaired where it was found. The prescription this repo already had recorded for that
#   pattern — [[feedback_divergent_leniency_duplicate_normalizers]]: single source, visible drops,
#   fail-closed — was quoted during that session and then not applied; the duplication was repaired
#   three times instead of removed. This file removes it.
#
# WHAT IS SHARED vs WHAT STAYS WITH THE CALLER — the split is deliberate, do not "unify" further:
#   SHARED (here): loading the two pattern layers, validating rows, and deciding whether a given
#                  token on a given path is a reportable hit.
#   CALLER'S:      WHICH content is scanned (staged diff / pushed range / packed file set), and the
#                  DEGRADE DIRECTION when the instrument is incomplete. Those genuinely differ:
#                  a commit is local and re-committable, so an absent operator override warns; a push
#                  and a publish are the acts that make content public, so the same state blocks.
#                  Collapsing that would either block every fresh clone's first commit (training the
#                  override into reflex) or let a real leak reach a public remote. This library
#                  therefore REPORTS state and never exits.
#
# Usage:
#   . "$REPO_ROOT/scripts/psa_scan_lib.sh"
#   psa_load "$defaults_path" "$override_path"     # sets PSA_STREAM + the three state flags below
#   psa_scan_tagged <<< "$path<TAB>line"…          # prints hits, returns 1 if any hit was reported
#
# State set by psa_load (read-only for callers):
#   PSA_STREAM            validated rows only (invalid/malformed rows are dropped AND counted)
#   PSA_DEFAULTS_OK       1 = committed defaults present, readable, non-empty
#   PSA_OVERRIDE_PRESENT  1 = operator override present, readable, non-empty
#   PSA_BAD_ROWS          count of rows dropped as unusable (uncompilable regex, or no TAB)
# A caller that treats PSA_BAD_ROWS>0 or PSA_DEFAULTS_OK=0 as "clean" has a hole: those states mean
# the instrument is incomplete, and an incomplete instrument cannot certify anything.

# Placeholder shapes that must never count as a leak. Anchored whole-token: a substring match here
# would let a real token pass by merely CONTAINING a placeholder word.
PSA_PLACEHOLDER='^(<[a-z0-9_-]+>|\{[a-z_]+\}|EXAMPLE|dummy|changeme|REDACTED|xxxx|/Users/(EXAMPLE|yourname|\{[a-z_]+\}|<[a-z0-9_-]+>)/|AKIAIOSFODNN7EXAMPLE)$'

# Files that name wiring/companion tokens as part of doing their job. LOW severity only — HIGH/MED
# block everywhere, including here. Kept as a function so the list has exactly one definition.
psa_low_allowlisted() {
  case "$1" in
    .gitignore|scripts/sync-to-be.sh|.claude/rules/local_fh_context.md|templates/local_fh_context.md|templates/.claude/rules/*|templates/.git-hooks/*) return 0 ;;
    *) return 1 ;;
  esac
}

# psa_load <defaults_path> <override_path>
# Prints diagnostics for every degraded state; sets the flags above. NEVER exits — the caller owns
# the degrade direction, because it differs by surface (see the header).
psa_load() {
  local defaults="$1" override="$2" raw ov
  PSA_STREAM=""; PSA_DEFAULTS_OK=0; PSA_OVERRIDE_PRESENT=0; PSA_BAD_ROWS=0

  # Layer 1 — committed defaults. This file ships with the repo, so missing/unreadable/empty is a
  # BROKEN INSTRUMENT, not a configuration choice. A valid override used to mask its absence, and the
  # scan then reported a clean "full pattern set" with every universal pattern silently gone.
  if [ -f "$defaults" ] && [ -r "$defaults" ]; then
    raw=$(cat "$defaults" 2>/dev/null || true)
    if [ -n "$(printf '%s' "$raw" | grep -vE '^[[:space:]]*(#|$)' || true)" ]; then
      PSA_STREAM="$raw"; PSA_DEFAULTS_OK=1
    fi
  fi
  [ "$PSA_DEFAULTS_OK" -eq 0 ] && \
    echo "  ❌ committed pattern defaults missing/unreadable/empty — universal patterns NOT loaded ($defaults)"

  # Layer 2 — the gitignored operator literals. Present ONLY when a readable, non-empty read actually
  # contributed patterns: an empty file must not masquerade as a configured gate.
  if [ -f "$override" ]; then
    if [ -r "$override" ]; then
      ov=$(cat "$override" 2>/dev/null || true)
      if [ -n "$(printf '%s' "$ov" | grep -vE '^[[:space:]]*(#|$)' || true)" ]; then
        PSA_STREAM="$PSA_STREAM
$ov"; PSA_OVERRIDE_PRESENT=1
      else
        echo "  ⚠️  operator pattern override is EMPTY — treated as absent."
      fi
    else
      echo "  ⚠️  operator pattern override exists but is UNREADABLE — treated as absent."
    fi
  fi

  # Row validation. Two ways a row can be present and still protect nothing, both previously silent:
  #   • no TAB  → the whole line lands in the severity field and no detector is defined
  #   • bad ERE → grep exits >=2 and the error is swallowed downstream as a no-match
  # Both are DROPPED and COUNTED here so the caller can fail closed on an incomplete instrument.
  local valid="" line re rc
  while IFS= read -r line; do
    line="${line%$'\r'}"                 # CRLF: a trailing CR welds onto the regex and it matches nothing
    case "$line" in ''|\#*) continue;; esac
    re="${line#*$'\t'}"
    if [ "$re" = "$line" ]; then
      echo "  ❌ unusable pattern row (no TAB between severity and regex): ${line%%$'\t'*}"
      PSA_BAD_ROWS=$((PSA_BAD_ROWS+1)); continue
    fi
    printf '' | grep -E "$re" >/dev/null 2>&1; rc=$?    # 0/1 = compiled; >=2 = regex error
    if [ "$rc" -ge 2 ]; then
      echo "  ❌ unusable pattern (invalid regex) — this detector would match nothing: [${line%%$'\t'*}]"
      PSA_BAD_ROWS=$((PSA_BAD_ROWS+1)); continue
    fi
    valid="$valid
$line"
  done <<PSA_ROWS
$PSA_STREAM
PSA_ROWS
  PSA_STREAM="$valid"
}

# psa_scan_tagged  — reads "path<TAB>content" lines on stdin, prints one line per reportable hit.
# Returns 0 = nothing reportable, 1 = at least one hit.
#
# Why path-tagged input: the LOW allowlist is per FILE, so a scanner that flattens content loses the
# only information needed to apply it. The push copy did exactly that and blocked its own first real
# push on a companion-store name inside the script whose job is to sync to the companion store.
psa_scan_tagged() {
  local input hit=0 row sev re path body tok
  input=$(cat)
  [ -n "$input" ] || return 0
  while IFS= read -r row; do
    case "$row" in ''|\#*) continue;; esac
    re="${row#*$'\t'}"; [ "$re" = "$row" ] && continue
    sev="${row%%$'\t'*}"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      path="${line%%$'\t'*}"; body="${line#*$'\t'}"
      # EVERY match on the line. Taking only the first let a documented placeholder earlier on the
      # line shield a real token later on it.
      while IFS= read -r tok; do
        [ -z "$tok" ] && continue
        printf '%s' "$tok" | grep -qiE "$PSA_PLACEHOLDER" && continue
        if [ "$sev" = "LOW" ] && psa_low_allowlisted "$path"; then continue; fi
        echo "  ❌ $sev leak — ${path}: '$tok'"
        hit=1
      done <<PSA_TOK
$(printf '%s' "$body" | grep -oiE "$re" 2>/dev/null || true)
PSA_TOK
    done <<PSA_LINES
$(printf '%s\n' "$input" | grep -iE "$re" 2>/dev/null || true)
PSA_LINES
  done <<PSA_PAT
$PSA_STREAM
PSA_PAT
  return $hit
}
