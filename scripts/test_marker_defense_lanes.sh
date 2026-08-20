#!/usr/bin/env bash
# test_marker_defense_lanes.sh — regression fixtures for pre-commit's validate_defense_leg
# (Wave 1-D defense line, 2026-08-20).
#
# WHY THIS FILE EXISTS AT ALL: the procedure was absorbed from a sibling harness whose own document
# asserted "the commit hook reads that line" and "pinned by scripts/test_marker_floor_lanes.sh".
# 🟥 Measured twice, with a control (`crossfamily` → 21 hits in the same file): BOTH claims were
# **0 hits** there. The prose was portable; the machine was not. This lane is the machine, built
# here, so that FH's own claim is true when FH makes it.
#
# Fixtures assert BOTH directions (known-pair): every intended shape is admitted, and every hole the
# leg closes still blocks. A suite that only asserts BLOCK cannot tell "blocked" from "blocked for
# the wrong reason"; one that only asserts PASS cannot see a leg that admits everything.
#
# Usage: bash scripts/test_marker_defense_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
# Script-relative, NOT `git rev-parse --show-toplevel` — same reason as the sibling lanes: in a
# vendored tree rev-parse answers with the OUTER repo and the suite measures somebody else's files.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

sed -n '/^validate_defense_leg()/,/^}/p' "$HOOK" > "$T/fn.sh"

# Instrument calibration BEFORE any fixture runs. An empty extraction would let every BLOCK
# fixture "pass" against nothing and every PASS fixture fail — and the suite would still print a
# verdict. Assert the body actually arrived.
if ! grep -q 'estimation-layer' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — validate_defense_leg did not extract from $HOOK."
  echo "   Fixtures below would measure an empty function. Aborting rather than reporting green."
  exit 1
fi

pass=0; fail=0
mk() { printf '%s\n' "$2" > "$T/$1"; }
run() { bash -c "source '$T/fn.sh'; validate_defense_leg '$T/$1'" >/dev/null 2>&1; }
want() { # $1=fixture $2=expect(pass|block) $3=label
  local rc; run "$1"; rc=$?
  local got; [ "$rc" -eq 0 ] && got=pass || got=block
  if [ "$got" = "$2" ]; then printf '  ✅ %-6s %s\n' "$2" "$3"; pass=$((pass+1))
  else printf '  ❌ %-6s %s — got %s\n' "$2" "$3" "$got"; fail=$((fail+1)); fi
}

GOOD='axis2-defense: reproducibility=bash scripts/test_marker_defense_lanes.sh at 4c1f2ab fairness=both arms reps=3, same fixture dir, same shell estimation-layer=all measured; known-pair separated arm from control'

echo "[marker-defense] known-pair fixtures"
echo "  ── admitted (must not over-block; over-blocking teaches --no-verify) ──"
mk ok.md          "floor-status: sonnet-floor
$GOOD"
want ok.md          pass  "all three substantive"
mk multiline.md   "floor-status: sonnet-floor
axis2-defense: reproducibility=git show 9cd7350 -- scripts/selfcheck.sh
               fairness=arm and control both on 2.6.0 tarball, reps=1 each, named
               estimation-layer=counts measured; the 2,367 b/day figure is a quotation"
want multiline.md   pass  "continuation lines are one value"
mk order.md       "floor-status: below-floor
axis2-defense: estimation-layer=measured via npm pack --dry-run --json fairness=same tarball both arms reproducibility=npm pack @chrono-meta/fh-gate@2.6.0"
want order.md       pass  "sub-answers in any order"

echo "  ── blocked ──"
mk none.md        "floor-status: sonnet-floor"
want none.md        block "no axis2-defense line at all"
mk empty.md       "floor-status: sonnet-floor
axis2-defense:"
want empty.md       block "key present, value empty (silence is not an answer)"
mk partial.md     "floor-status: sonnet-floor
axis2-defense: reproducibility=bash scripts/selfcheck.sh completes rc=0 fairness=both arms on same tree"
want partial.md     block "estimation-layer missing — a partial form is not a defense"
# 🟥 rc IS NOT ENOUGH HERE — measured by a revert probe on 2026-08-20, the day this was written.
# Deleting the completeness guard leaves `partial.md` STILL blocked, because an absent sub-answer
# also reads as an empty (vacuous) one and the next guard catches it. Gating on the exit code alone
# therefore certifies a guard that is doing nothing: the classic decorative anchor. What the
# completeness guard actually buys is the PRESCRIPTION — "missing sub-answer(s): estimation-layer"
# tells the author which question they skipped, where "too short" sends them to rewrite the wrong
# field. A gate's output is half its product, so the lane measures the output.
want_msg() { # $1=fixture $2=substring $3=label
  local out; out=$(bash -c "source '$T/fn.sh'; validate_defense_leg '$T/$1'" 2>&1)
  if printf '%s' "$out" | grep -qF "$2"; then printf '  ✅ %-6s %s\n' "msg" "$3"; pass=$((pass+1))
  else printf '  ❌ %-6s %s — output did not contain %s\n' "msg" "$3" "$2"; fail=$((fail+1)); fi
}
want_msg partial.md "missing sub-answer(s): estimation-layer" \
  "prescription NAMES the skipped question (guard is load-bearing for the message)"
# (the short.md prescription control lives below, AFTER that fixture is created —
#  🟥 it was first written here, before `mk short.md`, so it measured a NON-EXISTENT file and
#  read the "no line at all" message. The lane was wrong, not the subject. Fixture order is
#  part of the instrument.)
mk vacuous.md     "floor-status: sonnet-floor
axis2-defense: reproducibility=ok fairness=yes estimation-layer=n/a"
want vacuous.md     block "filled form, not an answer"
mk short.md       "floor-status: sonnet-floor
axis2-defense: reproducibility=ran it fairness=same estimation-layer=nums"
want short.md       block "too short to name a command, reps or layer"
want_msg short.md   "vacuous answer(s)" \
  "control — the short case takes the OTHER prescription (the two are distinguishable)"
mk dup.md         "floor-status: sonnet-floor
$GOOD
$GOOD"
want dup.md         block "two lines — the reader takes the first, so a correction is shadowed"

echo "  ── call-site pin (a function nobody calls is prose) ──"
# 🟥 Found by cross-family review 2026-08-20 (codex/gpt-5.5), self-detection 0: this suite extracts
# the FUNCTION and calls it directly, so deleting the hook's call site left every lane green while
# the leg stopped running — and the skill doc claimed "pre-commit runs this". That is the exact
# defect class this whole file was built to stop importing, reproduced one layer up.
# The pin is a grep, and its limit is stated rather than hidden: it proves the call EXISTS and sits
# in the full-gate marker block, not that the block is reached. Reachability is pinned by the hook's
# own end-to-end lanes, not here.
cs=$(grep -c 'validate_defense_leg "\$MARKER"' "$HOOK")
if [ "$cs" -eq 1 ]; then
  printf '  ✅ %-6s %s\n' "call" "hook calls validate_defense_leg exactly once"; pass=$((pass+1))
else
  printf '  ❌ %-6s %s — found %s call site(s)\n' "call" "hook calls validate_defense_leg exactly once" "$cs"; fail=$((fail+1))
fi
# and that the call is gated on the floor tiers the doc claims — not on load-bearing, which is
# where it was first (wrongly) wired.
if grep -B4 'validate_defense_leg "\$MARKER"' "$HOOK" | grep -qE 'floor-status:.*sonnet-floor\|below-floor'; then
  printf '  ✅ %-6s %s\n' "call" "call is gated on floor-status (sonnet-floor|below-floor)"; pass=$((pass+1))
else
  printf '  ❌ %-6s %s\n' "call" "call is NOT gated on floor-status — scope drifted from the doc"; fail=$((fail+1))
fi

echo "  ── prescriptions (rc alone certifies guards that do nothing) ──"
# 🟥 Same shadowing as the completeness guard: removing the presence guard leaves none.md/empty.md
# still blocked by the missing-subanswer guard, so rc cannot see it. What presence buys is the
# prescription that shows the author the whole field shape.
want_msg none.md  "no 'axis2-defense:' line" \
  "presence guard is load-bearing for its own message"
want_msg empty.md "no 'axis2-defense:' line" \
  "empty value takes the same prescription as absent (silence is silence)"

echo "  ── controls (the leg discriminates; it does not just fire) ──"
# 🟥 known-NEGATIVE for over-blocking: a legitimate answer that merely LOOKS terse per-field but
# clears the bar. Without this, a leg that blocked everything would pass every BLOCK row above.
mk borderline.md  "floor-status: sonnet-floor
axis2-defense: reproducibility=see PR #471 CI log job 96296828886 fairness=arms differ: control is v2.5.1 tarball — stated estimation-layer=one measured, one quoted from CHANGELOG"
want borderline.md  pass  "control — admits an honest answer that NAMES an asymmetry"
# 🟥 known-negative on the em-dash: `fairness` here contains a dash, which must NOT truncate parsing
mk dashes.md      "floor-status: sonnet-floor
axis2-defense: reproducibility=git log main..HEAD --oneline fairness=both arms — same reps, same env estimation-layer=measured; instrument calibrated on a known pair"
want dashes.md      pass  "control — dashes inside a value do not truncate it"

echo
if [ "$fail" -eq 0 ]; then
  echo "✅ marker-defense: $pass lanes hold (0 failed)"
  echo "   🟥 SCOPE: this suite pins PRESENCE, COMPLETENESS and NON-VACUITY. It cannot pin whether"
  echo "   the answers are TRUE — that is the operator's and the weekly audit's, like every other"
  echo "   marker field. A green line here is not a claim that the defense was actually mounted."
  exit 0
fi
echo "❌ marker-defense: $fail failed / $pass passed"
exit 1
