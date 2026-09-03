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
# A fixture whose PREMISE never obtained is not a failing guard — it is a run whose verdict means
# nothing. Kept on its own counter and its own exit code so the two are distinguishable from the
# exit status alone, not merely in the log text (Wave-1 finding, 2026-08-02: a distinct message
# folded into a shared exit code is not a distinct signal to CI).
# **3, not 2** — bash returns 2 for a script SYNTAX ERROR, so claiming 2 would make a rotted script
# report itself as a benign fixture issue and send the reader hunting mtimes instead of reading the
# parse error. Exit codes are a shared namespace; do not squat on one the shell already owns.
premise_bad() { echo "  ⛔ $1"; premise_fail=$((premise_fail + 1)); }
premise_fail=0

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
      # directory excludes (2026-09-03): re-home targets, same -path form as logs/.
      manifests/) grep -qF -- "! -path '*/manifests/*'" "$SYNC" || missing="$missing $e" ;;
      _index/)    grep -qF -- "! -path '*/_index/*'"    "$SYNC" || missing="$missing $e" ;;
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

# The guard's predicate: mtime-newer is the cheap screen, divergent CONTENT is the verdict.
# ⚠️ This is a re-spelling of the script's logic, not the script's own function (sync-to-be.sh runs
# on load and cannot be sourced), so it is a DIVERGENT NORMALIZER by construction — §2b below
# pins the two together structurally so this copy cannot quietly drift lenient.
trips() {   # $1 = src, $2 = dst
  [ "$2" -nt "$1" ] || return 1
  if head -1 "$2" 2>/dev/null | grep -q 'MIRROR COPY'; then
    ! tail -n +2 "$2" 2>/dev/null | cmp -s - "$1"
  else
    ! cmp -s "$2" "$1"
  fi
}

# known-NEGATIVE: mirror equal-or-older → must NOT trip
if trips "$TD/src/card.md" "$TD/dst/card.md"; then
  bad "known-NEGATIVE — a freshly-mirrored file reads as 'destination newer' (guard would over-block)"
else
  pass "known-NEGATIVE — normal mirror does not trip the guard"
fi

# known-NEGATIVE 2 (added 2026-07-28, measured FP): destination newer, content IDENTICAL.
# This is what a `git rebase` inside the companion store produces — it re-checks-out the working
# tree and stamps `now` on every touched file. Two byte-identical files aborted a healthy sync,
# and an abort that fires on healthy runs trains SYNC_OVERWRITE_OK into a reflex, which disarms
# the guard on the surface it exists to protect. Overwriting identical bytes cannot lose anything.
sleep 1
touch "$TD/dst/card.md"
if trips "$TD/src/card.md" "$TD/dst/card.md"; then
  bad "known-NEGATIVE 2 — identical content with a newer mtime trips the guard (rebase-stamp FP is back)"
else
  pass "known-NEGATIVE 2 — newer mtime + identical content does not trip (rebase stamp is not an edit)"
fi

# known-NEGATIVE 3: the only difference is the banner this transport itself injects.
printf '%s\n' '<!-- MIRROR COPY — synced from the forge-harness hub. Do NOT edit here; the next sync overwrites it. Edit the canonical file under the hub instead. -->' > "$TD/dst/banner.md"
cat "$TD/src/card.md" >> "$TD/dst/banner.md"
cp "$TD/src/card.md" "$TD/src/banner.md"
# Establish "destination newer" DETERMINISTICALLY, not by write order. The sibling lanes above buy
# the separation with `sleep 1`; this one had nothing, so it rests on two writes landing in
# distinguishable clock ticks — an assumption, not a guarantee (a same-tick tie is the leading
# hypothesis for the 2026-08-02 CI flake in test_session_close_lanes.sh ⑤; the mechanism there is
# labelled unmeasured and the same caution applies here). A tie makes `trips()` return at its `-nt`
# screen, so this lane would report "the banner is not counted as divergence" without the banner
# case ever being reached — a pass for the wrong reason. Stamping the source into the absolute past
# costs nothing and cannot tie.
touch -t 200001010000.00 "$TD/src/banner.md"
# The premise GATES the lane — it does not merely annotate it. The sibling repair in
# test_session_close_lanes.sh skips the lane body when its premise fails; the first draft here only
# incremented a counter and fell through, so a premise failure would still have printed a green
# `pass` line for a lane whose input state was never created. That is the pass-for-the-wrong-reason
# class this whole change exists to close, reproduced inside the same commit (Wave-3, 2026-08-02).
if [ "$TD/dst/banner.md" -nt "$TD/src/banner.md" ]; then
  if trips "$TD/src/banner.md" "$TD/dst/banner.md"; then
    bad "known-NEGATIVE 3 — the injected MIRROR COPY banner reads as a mirror-side edit"
  else
    pass "known-NEGATIVE 3 — the transport's own banner is not counted as divergence"
  fi
else
  premise_bad "known-NEGATIVE 3 — FIXTURE PREMISE: destination is not newer; the lane is SKIPPED, not passed"
fi

# known-POSITIVE: the actual incident — someone edits the mirror
sleep 1
printf 'edited in the mirror\n' >> "$TD/dst/card.md"
if trips "$TD/src/card.md" "$TD/dst/card.md"; then
  pass "known-POSITIVE — a mirror-side edit trips the guard (the 07-26 incident)"
else
  bad "known-POSITIVE — a mirror-side edit does NOT trip the guard; the loss path is open again"
fi

# known-POSITIVE 2: a mirror-side edit UNDER the banner must still trip — the banner-aware
# comparison must skip line 1, not skip the file.
printf 'company-session finding added in the mirror\n' >> "$TD/dst/banner.md"
if trips "$TD/src/banner.md" "$TD/dst/banner.md"; then
  pass "known-POSITIVE 2 — a real edit beneath the banner still trips (banner skip is line-1 only)"
else
  bad "known-POSITIVE 2 — an edit under the banner is invisible; banner handling swallowed a real hit"
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

# ── 2b. Both guard sites must apply the CONTENT verdict, not mtime alone ──────
# `trips()` above re-spells the script's logic. If the script kept mtime-only on either site while
# this anchor tested content, the anchor would report green on a guard that still over-blocks —
# a divergent normalizer scoring its own dialect. Pin it structurally instead.
sites=$(grep -c '_dest_content_differs "\$s" "\$d"\|_dest_content_differs "\$src" "\$dstf"' "$SYNC")
if [ "${sites:-0}" -eq 2 ]; then
  pass "both guard sites (dir + file) gate on _dest_content_differs, not mtime alone"
else
  bad "expected 2 content-checked guard sites in $SYNC, found ${sites:-0} — one path still aborts on mtime alone (rebase-stamp FP)"
fi
if grep -q '^_dest_content_differs()' "$SYNC"; then
  pass "_dest_content_differs is defined once (single source for the content verdict)"
else
  bad "_dest_content_differs missing from $SYNC — this anchor is testing logic the script does not have"
fi

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
if [ "$premise_fail" -ne 0 ]; then
  echo "sync_guard_check: FIXTURE ERROR ($premise_fail) — a lane's input state was never created; this run proves nothing (exit 3 ≠ guard failure)"
  exit 3
fi
if [ "$fail" -eq 0 ]; then
  echo "sync_guard_check: PASS"
  exit 0
fi
echo "sync_guard_check: FAIL ($fail)"
echo "Do not relax the anchor to go green — the guard exists because data was actually lost."
exit 1
