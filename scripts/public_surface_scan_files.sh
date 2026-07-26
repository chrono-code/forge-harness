#!/usr/bin/env bash
# public_surface_scan_files.sh — Pre-Publish confidentiality floor for `npm publish`.
#
# Mechanizes the npm-publish half of the Pre-Publish Surface Gate (CLAUDE.md). The pre-commit
# confidentiality scan sees only the ADDED LINES of this repo's commits; a token committed before
# that scan existed, or carried in a files[] entry, would otherwise reach the registry unscanned.
# This scans the FULL CONTENT of the exact npm-published file set (npm pack --dry-run) against the
# same operator-private patterns, and blocks `npm publish` on a HIGH/MED hit.
#
# Honest scope: covers `npm publish` only (wired via package.json prepublishOnly). The separate-repo
# go-public surface (gh repo create --public / visibility flip / first push to a new public remote) is
# not an npm or git op against this repo, so no hook here sees it — it stays prose + PRE-PUBLISH-CHECKLIST.md
# (genuinely un-hookable). Same shape as the Destructive-Op story: git/npm surface mechanized, the
# separate-repo go-public surface stays prose.
#
# Degrade direction: irreversible surface (publish) → fail-CLOSED. Patterns absent, or the published
# file set unresolved → BLOCK (proceed only on an explicit, logged PUBLIC_SURFACE_OK=1). Never silent-allow.
#
# Override (explicit, logged — mirrors the pre-commit PUBLIC_SURFACE_OK channel):
#   PUBLIC_SURFACE_OK=1 npm publish …   ← after conscious review of the flagged hit(s).
#
# Patterns are single-source (shared with the pre-commit scan): .claude/rules/.public-surface-patterns.defaults
# (committed, universal) + .claude/rules/.public-surface-patterns (gitignored, operator literals).

set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PSA_DEFAULTS="$REPO_ROOT/.claude/rules/.public-surface-patterns.defaults"
PSA_OVERRIDE="${PSA_PATTERNS:-$REPO_ROOT/.claude/rules/.public-surface-patterns}"
# PSA_PLACEHOLDER and the default psa_low_allowlisted now come from scripts/psa_scan_lib.sh.
# A second copy here is exactly the divergence this refactor removed; do not reintroduce one.

# LOW-severity allowlist by file (HIGH/MED still block). For the PUBLISH scan this is nearly vacuous:
# a published file should carry NO operator-private token at all. Deliberately names no operator-private
# file literal here (the pre-commit copy of this list does, but it lives in a git-hooks-allowlisted path;
# THIS script is public-tracked, so hardcoding e.g. a companion-script name would itself be a LOW leak —
# caught by the pre-commit confidentiality scan, 2026-06-27). Generic template paths only.

echo "[Pre-Publish] public-surface scan (npm-published file content)..."

# ── Load patterns via the shared library (scripts/psa_scan_lib.sh) ──
# One implementation of loading + row validation + exemption decisions, shared with pre-commit and
# pre-push. What this file KEEPS for itself, deliberately:
#   • the file-level `grep -a` scan. It forces every published file to be read as TEXT; the library's
#     line-stream interface would drop back to text-only handling and re-open the hole a challenger
#     found earlier — a token inside an SVG / null-byte file (docs/pillars.svg ships) scanning clean.
#   • a STRICTER LOW allowlist (below). A published artifact should carry no operator-private token
#     at all, so the commit-time list of files that legitimately name wiring tokens does not apply.
#     Sourcing the library and then redefining the function is how that difference stays visible
#     instead of being buried as a divergence.
PSA_LIB="$REPO_ROOT/scripts/psa_scan_lib.sh"
if [ ! -r "$PSA_LIB" ]; then
  echo "  ❌ scripts/psa_scan_lib.sh missing — the confidentiality scanner cannot run."
  [ "${PUBLIC_SURFACE_OK:-0}" = "1" ] || { echo "     Fail-closed on the publish boundary."; exit 1; }
else
  . "$PSA_LIB"
fi

# Stricter than the library default — see the note above. Named here so the difference is legible.
psa_low_allowlisted() {
  case "$1" in
    templates/*) return 0 ;;
    *) return 1 ;;
  esac
}

psa_load "$PSA_DEFAULTS" "$PSA_OVERRIDE"

# Publish is an irreversible surface: EVERY incomplete-instrument state blocks, including the merely
# absent operator override (which only warns at commit time — see the library header for why the two
# surfaces degrade differently).
_psa_why=""
[ "$PSA_DEFAULTS_OK" -eq 0 ]      && _psa_why="committed pattern defaults missing/unreadable/empty"
[ "$PSA_BAD_ROWS" -gt 0 ]         && _psa_why="${_psa_why:+$_psa_why; }$PSA_BAD_ROWS unusable pattern row(s)"
[ "$PSA_OVERRIDE_PRESENT" -eq 0 ] && _psa_why="${_psa_why:+$_psa_why; }operator-literal override absent/empty (HIGH company/companion literals NOT scanned)"
if [ -n "$_psa_why" ]; then
  echo "  ❌ incomplete confidentiality instrument — $_psa_why"
  if [ "${PUBLIC_SURFACE_OK:-0}" = "1" ]; then
    echo "  ⚠️  proceeding by PUBLIC_SURFACE_OK=1 (conscious — the scan is incomplete)"
    echo "$(date +%Y-%m-%dT%H:%M:%S) PUBLIC_SURFACE_OK override (npm publish, incomplete instrument)" \
      >> "$REPO_ROOT/tracks/_meta/.psa_override_log" 2>/dev/null || true
  else
    echo "     Fail-closed on an irreversible surface: an incomplete instrument cannot certify clean."
    exit 1
  fi
fi


# Named residual (cross-family audit 2026-06-27, deferred): this scans the WORKING-TREE content of the
# packed file list, not the final tarball bytes. A content-generating publish lifecycle (prepack/prepare
# that writes files AFTER this prepublishOnly scan) could ship bytes this never saw, and a path containing
# a newline would mis-split the list. The robust fix is to scan the actual `npm pack` tarball; deferred
# because THIS package's lifecycle is content-neutral (prepare = chmod only, no prepack). Re-open if a
# content-generating lifecycle is ever added.
# ── Resolve the exact npm-published file set (fail-closed if unresolved OR partial) ──
FILES=$(npm pack --dry-run --json 2>/dev/null \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{JSON.parse(s)[0].files.forEach(f=>console.log(f.path))}catch(e){process.exit(3)}})' 2>/dev/null || true)
if [ -z "$FILES" ]; then
  echo "  ❌ could not resolve the npm-published file set (npm pack --dry-run failed)."
  [ "${PUBLIC_SURFACE_OK:-0}" = "1" ] && { echo "  ⚠️  proceeding by PUBLIC_SURFACE_OK=1"; exit 0; }
  echo "     Fail-closed on an irreversible surface. Fix npm pack or override with PUBLIC_SURFACE_OK=1."
  exit 1
fi

# Wrong-set guard (challenger M6): a future npm --json shape change could yield a NON-empty but PARTIAL
# file list (forEach iterates a renamed/nested structure without throwing) → files silently unscanned.
# npm always ships package.json in the tarball; its absence means the parse got a wrong set → fail-closed.
if ! printf '%s\n' "$FILES" | grep -qx "package.json"; then
  echo "  ❌ published file set looks wrong — 'package.json' (always shipped) is absent from the parse."
  [ "${PUBLIC_SURFACE_OK:-0}" = "1" ] && { echo "  ⚠️  proceeding by PUBLIC_SURFACE_OK=1"; exit 0; }
  echo "     Fail-closed (possible npm --json shape change). Verify npm pack output or PUBLIC_SURFACE_OK=1."
  exit 1
fi

# ── Scan full content of each published file ──
LEAK=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  path="$REPO_ROOT/$f"
  [ -f "$path" ] || continue
  while IFS=$'\t' read -r sev regex; do
    [ -z "$regex" ] && continue
    case "$sev" in \#*) continue;; esac
    while IFS= read -r tok; do
      [ -z "$tok" ] && continue
      printf '%s' "$tok" | grep -qiE "$PSA_PLACEHOLDER" && continue
      if [ "$sev" = "LOW" ] && psa_low_allowlisted "$f"; then continue; fi
      echo "  ❌ $sev leak — $f: '$tok' would ship to the registry"
      LEAK=1
      # -a forces every published file to scan as TEXT (challenger S1): -I skipped binary-classified
      # files, so a token in an SVG / null-byte file (docs/pillars.svg ships) would slip unscanned.
    done <<< "$(grep -aoiE "$regex" "$path" 2>/dev/null | sort -u || true)"
  done <<< "$PSA_STREAM"
done <<< "$FILES"

if [ "$LEAK" -eq 1 ]; then
  if [ "${PUBLIC_SURFACE_OK:-0}" = "1" ]; then
    echo "  ⚠️  public-surface hit(s) allowed by PUBLIC_SURFACE_OK=1 (conscious, reviewed intent)"
    echo "$(date +%Y-%m-%dT%H:%M:%S) PUBLIC_SURFACE_OK override (npm publish) — suppressed hit(s) above" \
      >> "$REPO_ROOT/tracks/_meta/.psa_override_log" 2>/dev/null || true
    exit 0
  fi
  echo "  An operator-private token would ship in the npm package. Generalize it (real home path → '~'"
  echo "  or '{project}'; companion/corp name → a generic phrase), or PUBLIC_SURFACE_OK=1 npm publish …"
  exit 1
fi

# Renamed with the refactor: the flag is PSA_OVERRIDE_PRESENT, set by psa_load. The bare name was a
# leftover that referenced nothing under `set -u` and aborted the scan at its final line.
if [ "$PSA_OVERRIDE_PRESENT" -eq 0 ]; then
  echo "  ⚠️  PASS (DEFAULTS-ONLY) — no home-path leak, but HIGH operator literals were NOT scanned (override absent)."
else
  echo "  ✅ PASS — no operator-private token in the published file set (full pattern set)."
fi
# Residual (named, not closed): the scan is a DENYLIST against loaded patterns — an un-patterned secret
# shape (an API key the patterns don't describe) still ships. This gate is not a general secret-detector.
exit 0
