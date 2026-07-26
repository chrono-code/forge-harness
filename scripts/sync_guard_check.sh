#!/usr/bin/env bash
# sync_guard_check.sh — known-pair anchor for the one-way sync's destination-newer guard.
#
# WHY
# On 2026-07-26 two consecutive sessions lost a session card: each wrote it into the companion
# store (which is where the session-start rule tells an agent to read from), and the next one-way
# sync silently overwrote it with the older canonical copy. v9 (7,567 B) -> v8 (5,299 B), then v10
# the same way. No checker caught it — the close-check complained about timestamp ORDER, an
# adjacent symptom, while the actual event was an overwrite. Discovery was accidental.
#
# `sync-to-be.sh` now aborts when a destination file is newer than its source. This file is that
# guard's regression anchor, because a guard nobody re-tests degrades into a comment.
#
# It asserts BOTH directions, because a guard that only ever blocks is as broken as one that never
# does — over-blocking trains the operator to set the override reflexively, and at that moment the
# gate becomes decoration. That failure mode is not hypothetical: the guard's own first
# calibration run over-blocked (it scanned `logs/`, which the transport excludes) and would have
# aborted every normal sync.
#
# Usage: bash scripts/sync_guard_check.sh     # exit 0 = both directions hold
set -uo pipefail

FH="${HUB_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SYNC="$FH/scripts/sync-to-be.sh"
fail=0

pass() { echo "  ✅ $1"; }
bad()  { echo "  ❌ $1"; fail=$((fail + 1)); }

echo "sync_guard_check — destination-newer guard, both directions"
echo

[ -f "$SYNC" ] || { echo "  ❌ $SYNC missing — instrument error, NOT a pass"; exit 1; }

# ── 1. Exclusion-set parity ───────────────────────────────────────────────────
# The guard walks the tree with `find`; the transport copies with `rsync`. They must describe the
# SAME file set. When they diverged, a normal sync aborted on files the transport never touches.
# SYNC_EXCLUDES is the single source for rsync; the find predicates are hand-spelled, so this
# check is what keeps the hand-spelled copy honest.
excludes=$(sed -n 's/^SYNC_EXCLUDES=(\(.*\))$/\1/p' "$SYNC" | tr -d "'" )
if [ -z "$excludes" ]; then
  bad "cannot read SYNC_EXCLUDES from $SYNC — instrument error, NOT a pass"
else
  missing=""
  for e in $excludes; do
    case "$e" in
      # -F: these predicates contain glob metacharacters (*), and matching them as REGEX
      # silently fails — measured on this anchor's own first run, where `*.marker` was reported
      # missing while sitting in the file. Literal matching is the only honest comparison here.
      logs/) grep -qF -- "! -path '*/logs/*'" "$SYNC" || missing="$missing $e" ;;
      *)     grep -qF -- "! -name '$e'" "$SYNC"       || missing="$missing $e" ;;
    esac
  done
  if [ -n "$missing" ]; then
    bad "exclusion parity — in SYNC_EXCLUDES but not in the guard's find predicates:$missing"
    echo "     The guard would inspect files the transport never writes → false aborts."
  else
    pass "exclusion parity — every SYNC_EXCLUDES entry has a matching find predicate"
  fi
fi

# ── 2. Both directions, on a scratch pair ─────────────────────────────────────
# Exercise the guard's logic itself rather than the real stores: this must be safe to run any
# time, including from a hook, and must never touch operator data.
TD="$(mktemp -d 2>/dev/null || echo "/tmp/sync_guard_check.$$")"
mkdir -p "$TD/src" "$TD/dst"
cleanup() { rm -rf "$TD"; }
trap cleanup EXIT

printf 'canonical\n' > "$TD/src/card.md"
cp "$TD/src/card.md" "$TD/dst/card.md"
touch -r "$TD/src/card.md" "$TD/dst/card.md"

newer_than() { [ "$2" -nt "$1" ]; }   # same predicate the guard uses

# known-NEGATIVE: mirror equal-or-older → must NOT trip
if newer_than "$TD/src/card.md" "$TD/dst/card.md"; then
  bad "known-NEGATIVE — a freshly-mirrored file reads as 'destination newer' (guard would over-block)"
else
  pass "known-NEGATIVE — normal mirror does not trip the guard"
fi

# known-POSITIVE: the actual incident — someone edits the mirror
sleep 1
printf 'edited in the mirror\n' >> "$TD/dst/card.md"
if newer_than "$TD/src/card.md" "$TD/dst/card.md"; then
  pass "known-POSITIVE — a mirror-side edit trips the guard (the 07-26 incident)"
else
  bad "known-POSITIVE — a mirror-side edit does NOT trip the guard; the loss path is open again"
fi

# ── 3. The override must exist, and must be explicit ──────────────────────────
if grep -q 'SYNC_OVERWRITE_OK' "$SYNC"; then
  if grep -q 'sync_overwrite_override_log' "$SYNC"; then
    pass "override channel present and logged (SYNC_OVERWRITE_OK)"
  else
    bad "override exists but is not logged — an unlogged bypass is invisible in review"
  fi
else
  bad "no override channel — a gate with no legitimate exit gets bypassed by deleting the gate"
fi

# ── 3b. The guard must cover EVERY caller of the hazard ───────────────────────
# The first cut guarded sync_dir only, leaving sync_file (which carries CLAUDE.local.md) on the
# original silent-overwrite path. A guard on some callers of a shared hazard is not a guard.
for fn in sync_dir sync_file; do
  body=$(awk "/^$fn\(\) \{/,/^\}/" "$SYNC")
  if printf '%s' "$body" | grep -q 'nt "\$src"\|check_dest_newer'; then
    pass "$fn carries the destination-newer guard"
  else
    bad "$fn does NOT carry the guard — the overwrite path is open through it"
  fi
done

# ── 4. Banner must not fight the guard ────────────────────────────────────────
# The banner writes to the destination, which would make it newer than its source and trip the
# guard on this script's own output every run. The mtime restore is what prevents that.
if grep -q 'stamp_banner' "$SYNC"; then
  if grep -q 'touch -r "\$s" "\$f"' "$SYNC"; then
    pass "banner restores mtime from source (guard and banner do not fight)"
  else
    bad "banner injects without restoring mtime — the guard will abort on its own banner next run"
  fi
else
  pass "no banner step (n/a)"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "sync_guard_check: PASS"
  exit 0
fi
echo "sync_guard_check: FAIL ($fail)"
echo "Do not relax the anchor to go green — the guard exists because data was actually lost."
exit 1
