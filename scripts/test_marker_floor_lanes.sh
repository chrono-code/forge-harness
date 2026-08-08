#!/usr/bin/env bash
# test_marker_floor_lanes.sh — regression fixtures for pre-commit validate_marker_floor lanes.
#
# Ships with the 2026-07-10 sonnet-floor lane (Sonnet-Floor Doctrine): each closed hole gets a
# mechanical regression test (Field-Harness Load-Bearing Change Gate convergence condition).
# Fixtures assert BOTH directions: the new lane admits exactly its intended shape, and every
# pre-existing guard still blocks (no degrade-toward-permissive regression).
#
# Usage: bash scripts/test_marker_floor_lanes.sh   Exit: 0 = all fixtures behave; 1 = regression.

set -uo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

sed -n '/^marker_recreate_hint()/,/^}/p;/^validate_marker_floor()/,/^}/p' "$HOOK" > "$T/fn.sh"

run() { bash -c "source '$T/fn.sh'; validate_marker_floor '$1'" >/dev/null 2>&1; }

FAIL=0
check() { # $1=fixture $2=expected(PASS|BLOCK) $3=label
  if run "$1"; then got=PASS; else got=BLOCK; fi
  if [ "$got" = "$2" ]; then echo "✅ $3 → $got"; else echo "❌ $3 → $got (expected $2)"; FAIL=1; fi
}

CF=''
printf "axis2-engine: inline\naxis2-model: sonnet\nfloor-status: sonnet-floor\naxis2-anchor: regression test 5/5 pass\n${CF}axis2-evidence: PASS no-S, 2B applied\n" > "$T/m1"
printf "axis2-engine: inline\naxis2-model: sonnet\nfloor-status: sonnet-floor\n${CF}axis2-evidence: PASS no-S\n" > "$T/m2"
printf "axis2-engine: inline\naxis2-model: haiku\nfloor-status: sonnet-floor\naxis2-anchor: probe 3/3\n${CF}axis2-evidence: PASS no-S\n" > "$T/m3"
printf "axis2-engine: inline\naxis2-model: sonnet\nfloor-status: at-floor\n${CF}axis2-evidence: PASS no-S\n" > "$T/m4"
printf "axis2-engine: inline\naxis2-model: haiku\nfloor-status: below-floor\n${CF}axis2-evidence: PASS no-S\n" > "$T/m5"
printf "axis2-engine: quench-challenger\naxis2-model: opus\nfloor-status: at-floor\n${CF}axis2-evidence: 1S/4A fixed\n" > "$T/m6"
printf "axis2-engine: inline\naxis2-model: haiku\nfloor-status: below-floor\nbelow-floor-ack: \"approved, proceed\" — canary-only change\n${CF}axis2-evidence: PASS no-S\n" > "$T/m7"
printf "axis2-engine: inline\naxis2-model: opus\nfloor-status: bogus-status\n${CF}axis2-evidence: PASS\n" > "$T/m8"

check "$T/m1" PASS  "sonnet-floor + anchor + sonnet model (new lane, intended shape)"
check "$T/m2" BLOCK "sonnet-floor WITHOUT anchor (anchor is the compensating requirement)"
check "$T/m3" BLOCK "haiku claiming sonnet-floor (lane mislabel)"
check "$T/m4" BLOCK "sonnet claiming at-floor (2026-06-10 mislabel class — guard intact)"
check "$T/m5" BLOCK "below-floor without ack (guard intact)"
check "$T/m6" PASS  "opus at-floor (legacy lane intact)"
check "$T/m7" PASS  "below-floor with quoted ack (legacy lane intact)"
check "$T/m8" BLOCK "invalid floor-status (fail-closed on unknown value)"

[ "$FAIL" -eq 0 ] && echo "── all marker-floor lane fixtures behave ──"
exit "$FAIL"
