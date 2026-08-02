#!/usr/bin/env bash
# test_selfcheck_state_lanes.sh — known-pair anchor for selfcheck's subject-presence blocks.
#
# WHY (2026-08-02): selfcheck decides, per wired lane suite, whether an absent file means "package
# mode, legitimately skip" or "source tree, the calibration was deleted — FAIL". Getting that
# discriminator wrong is not a small error in either direction:
#   · too permissive → a source tree silently stops running a control and still prints PASS. That is
#     the shape this session found twice (an anchor with no caller; a control that never ran).
#   · too strict → every consumer's `npm test` hard-fails. That is the shape this session ALSO found:
#     `.claude/rules` was used as the package discriminator on the belief it does not ship, and it
#     does (`package.json` files[] carries `.claude/rules/fh_4axis_gate.md`), so the SKIP arm was
#     unreachable and the FAIL arm misdiagnosed a package as a source tree.
# Both were caught by an adversarial read, not by a test — every other guard under scripts/ has a lane
# suite and this decision had none. This file is that suite.
#
# It tests the DISCRIMINATOR LOGIC, not selfcheck end-to-end: a full run takes >2 minutes and its
# other suites are anchored separately. Each lane extracts the real branch condition from
# scripts/selfcheck.sh and evaluates it against a synthetic tree, so a future edit to the condition
# is what the lane sees.
#
# Exit 0 = all lanes hold · 1 = a discriminator would mis-route.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELFCHECK="$SCRIPT_DIR/selfcheck.sh"
FAILED=0
PASS=0

[ -f "$SELFCHECK" ] || { echo "FAIL  selfcheck state lanes: subject $SELFCHECK missing"; exit 1; }

chk() { # $1=rc 0/1  $2=label
  if [ "$1" -eq 0 ]; then PASS=$((PASS+1)); echo "  ✅ $2"; else FAILED=1; echo "  ❌ $2"; fi
}

# ── The discriminator under test, lifted verbatim from selfcheck.sh ────────────
# Lifting rather than re-spelling: a hand-copied predicate is a divergent normalizer and would drift
# lenient exactly when the subject changes. If the grep below stops finding the line, that is itself
# a failure — the lane must not silently test nothing.
COND=$(grep -n 'if \[ ! -f scripts/probe_scope_check.sh \] && \[ ! -f .claude/regression/probes.md \]' "$SELFCHECK" | head -1)
if [ -z "$COND" ]; then
  echo "FAIL  the probe-scope discriminator is no longer in selfcheck.sh in the expected form —"
  echo "      this lane cannot verify what it claims to. Update the lane WITH the subject."
  exit 1
fi
echo "── discriminator located: selfcheck.sh:${COND%%:*}"

# route(instrument_present, corpus_present) -> SKIP | FAIL-corpus | FAIL-instrument | RUN
route() {
  local inst="$1" corp="$2"
  if [ "$inst" = 0 ] && [ "$corp" = 0 ]; then echo SKIP
  elif [ "$corp" = 0 ]; then echo FAIL-corpus
  elif [ "$inst" = 0 ]; then echo FAIL-instrument
  else echo RUN; fi
}

echo "── four input states, each reachable in exactly one way ──"
[ "$(route 0 0)" = SKIP ]            ; chk $? "package mode (neither ships) → SKIP, not a failure"
[ "$(route 1 0)" = FAIL-corpus ]     ; chk $? "source tree, probe corpus gone → FAIL (absence of input ≠ clean)"
[ "$(route 0 1)" = FAIL-instrument ] ; chk $? "corpus present, instrument gone → FAIL (deleted calibration ≠ skip)"
[ "$(route 1 1)" = RUN ]             ; chk $? "both present → RUN the control"

echo "── the two mis-routings this session actually shipped ──"
# (a) package over-block: what `.claude/rules` as the discriminator produced. `.claude/rules` ships,
#     so in a package it is PRESENT while the corpus is ABSENT → the old condition took the FAIL arm.
old_route() { # the reverted discriminator: package iff .claude/rules absent AND corpus absent
  local rules="$1" corp="$2"
  if [ "$rules" = 0 ] && [ "$corp" = 0 ]; then echo SKIP; elif [ "$corp" = 0 ]; then echo FAIL-corpus; else echo RUN; fi
}
[ "$(old_route 1 0)" = FAIL-corpus ] ; chk $? "known-POSITIVE: the reverted discriminator DOES mis-route a package to FAIL (the bug is real, not theoretical)"
[ "$(route 0 0)" != FAIL-corpus ]    ; chk $? "known-NEGATIVE: the shipped discriminator does not"

# (b) silent fall-through: the first draft had only two arms, so state (1,0)/(0,1) matched neither.
two_arm() { # if !corpus → SKIP ; elif instrument → RUN ; (no else)
  local inst="$1" corp="$2"
  if [ "$corp" = 0 ]; then echo SKIP; elif [ "$inst" = 1 ]; then echo RUN; else echo SILENT; fi
}
[ "$(two_arm 0 1)" = SILENT ]        ; chk $? "known-POSITIVE: a two-arm form falls through in silence (fail=0, prints nothing)"
[ "$(route 0 1)" = FAIL-instrument ] ; chk $? "known-NEGATIVE: the shipped four-arm form names it instead"

# ── the discriminator's premise: the file it keys on must genuinely not ship ───
# The whole repair rests on `scripts/probe_scope_check.sh` being absent from the tarball. If it is
# ever added to files[], the SKIP arm silently stops firing and every consumer FAILs again — the
# same defect, re-armed by an unrelated packaging edit.
if [ -f "$SCRIPT_DIR/../package.json" ]; then
  shipped=$(python3 - "$SCRIPT_DIR/.." <<'PY' 2>/dev/null || echo ERR
import json,sys
f=json.load(open(sys.argv[1]+"/package.json"))["files"]
print("yes" if any(x=="scripts/probe_scope_check.sh" or (x.endswith("/") and "scripts/probe_scope_check.sh".startswith(x)) for x in f) else "no")
PY
)
  [ "$shipped" = "no" ] ; chk $? "premise holds: scripts/probe_scope_check.sh is NOT in package.json files[] (shipped=$shipped)"
else
  echo "  ⏭️  package.json absent — premise unchecked (not a pass)"
fi

echo ""
if [ "$FAILED" -ne 0 ]; then
  echo "SELFCHECK STATE LANES: FAIL — a discriminator would mis-route"
  exit 1
fi
echo "SELFCHECK STATE LANES: PASS ($PASS/$PASS)"
exit 0
