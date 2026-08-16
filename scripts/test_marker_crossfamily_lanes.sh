#!/usr/bin/env bash
# test_marker_crossfamily_lanes.sh — regression fixtures for pre-commit's
# validate_crossfamily_leg (typed cross-family verdict, 2026-08-08).
#
# WHY: the `crossfamily:` marker line has been REQUIRED on load-bearing changes since
# 2026-06 (commit c1fa459) — but only its PRESENCE was checked, so the value was free
# prose. That is how a false one shipped: a sibling harness recorded
# `crossfamily: none this round — 도달 불가` (unreachable), the claim was later found
# FALSE, and a later session cited it as grounds. Presence-checking catches silence; it
# cannot catch a confident wrong answer. This lane types the value.
#
# Fixtures assert BOTH directions (known-pair): every intended shape is admitted, and
# every hole the lane closes still blocks. A test that only asserts BLOCK cannot tell
# "blocked" from "blocked for the wrong reason"; one that only asserts PASS cannot see a
# lane that admits everything.
#
# Usage: bash scripts/test_marker_crossfamily_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
# Script-relative, NOT `git rev-parse --show-toplevel`. Measured 2026-08-13 in a vendored tree
# (npm install, then `git init` at a level above — a monorepo committing node_modules is the
# same shape): rev-parse answers with the OUTER repo's root, so this suite looked for the
# package's own files inside somebody else's checkout, found nothing, and reported
# HARNESS-ERROR. The consumer sees a red `npm test` caused entirely by where their .git is.
# The subject of these lanes ships INSIDE this package, so the package root is the only root
# that can be right. Same form as test_capability_entrypoint_shipping.sh:29.
# The exposure is new: before these suites were wired into selfcheck.sh they ran nowhere, so
# the wrong root never cost anything. Wiring a dead lane surfaces every assumption it made.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

sed -n '/^validate_crossfamily_leg()/,/^}/p' "$HOOK" > "$T/fn.sh"

# Instrument calibration: an empty extraction would let every fixture "pass" against
# nothing. Assert the function body actually arrived before measuring anything.
if ! grep -q 'DEGRADED_PANEL_UNUSED' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — validate_crossfamily_leg did not extract from $HOOK."
  echo "   Fixtures below would measure an empty function. Aborting rather than reporting green."
  exit 1
fi

mk() { printf "$1" > "$T/$2"; }   # $1 = marker body, $2 = fixture name
run() { bash -c "source '$T/fn.sh'; validate_crossfamily_leg '$1'" >/dev/null 2>&1; }

FAIL=0; N=0
check() { # $1=fixture $2=expected(PASS|BLOCK) $3=label
  N=$((N+1))
  if run "$T/$1"; then got=PASS; else got=BLOCK; fi
  if [ "$got" = "$2" ]; then echo "✅ $3 → $got"; else echo "❌ $3 → $got (expected $2)"; FAIL=1; fi
}

echo "── admitted shapes (must PASS) ──"
mk 'crossfamily: panel(codex,gemini) — R1..R3, 9 findings, 8 fixed 1 refuted, CONVERGED\n' k1
check k1 PASS "panel() with family list + verdict"
mk 'crossfamily: panel(codex, gemini) — spaced list, the S-grade over-block\n' k1b
check k1b PASS "panel(codex, gemini) — SPACE after comma (was truncated to 'panel(codex,')"
# ⚠️ CONTRACT CHANGE 2026-08-16 — `declined` now requires grounds. It used to pass BARE, which is
# what the old k3 asserted. That was the enum's soft spot: `declined` means the OPERATOR declined
# sidecars (UAP), a chosen floor — a factual, attributable claim — and it was the ONLY value with no
# grounds requirement, so an author who had merely judged decorrelation unnecessary reached for the
# nearest permissive token and passed clean. Measured in this repo the same day, by a session that
# had corrected a different marker's crossfamily value hours earlier and had the correct semantics
# printed to it in the hook's own error text. A closed enum stops prose from collapsing distinct
# states; it does not stop a WRONG token from being a VALID one — that is what these three lanes are.
# The old bare-declined expectation is not deleted silently; it is inverted here with its reason.
mk 'crossfamily: declined\n' k3
check k3 BLOCK "declined BARE — no grounds (was PASS until 2026-08-16; an operator decision has a record)"
mk 'crossfamily: declined — operator declined sidecars, chosen floor, per knowledge/shared/rules/operational_adaptation.md\n' k3b
check k3b PASS "declined + a record path that RESOLVES (the documented form)"
# The real defect, verbatim-shaped: a genuine authorial judgment, plausibly worded, wrong token.
# This is the known-POSITIVE that is not synthetic — it is the sentence that actually shipped.
mk 'crossfamily: declined — this is a small, mechanically-verifiable hook-wiring fix, not a verdict-enum change; the standpoint axis is the decorrelation applied here\n' k3c
check k3c BLOCK "declined + AUTHOR-judgment grounds — a choice with a panel reachable is DEGRADED_PANEL_UNUSED"
# ── the three a cross-family review (codex/gpt-5.6-terra) found against the FIRST version of this
# lane, which grepped for vocabulary (operator|uap|consent|…). All three reproduced on the spot,
# which is why the check is now a RESOLVABLE-RECORD test rather than a word list.
mk 'crossfamily: declined — declined because I judged it unnecessary myself\n' k3d
check k3d BLOCK "SELF-VALIDATING: echoing the value satisfied the old word list ('declin')"
mk 'crossfamily: declined — operator documentation says authors may choose freely\n' k3e
check k3e BLOCK "VACUOUS: carries 'operator' but describes no declination at all"
mk 'crossfamily: declined — operator declined sidecars, see tracks/_meta/nonexistent_record.md\n' k3f
check k3f BLOCK "FABRICATED PATH: cites a record that does not exist on disk"
# ⚠️ INSTRUMENT NOTE, recorded because it nearly produced a false verdict on this very lane:
# the first attempt to known-pair these ran the extracted function under **zsh** (this operator's
# interactive shell) while the hook runs under **bash**. zsh does not word-split an unquoted
# parameter expansion, so the `for _tok in $reason` scan saw ONE token and the legitimate
# path-citing case scored a false BLOCK — the code was correct and the harness was wrong.
# Re-run under bash: 7/7. If you hand-test this function, invoke it with `bash`, not the login shell.
mk 'crossfamily: DEGRADED_SINGLE_FAMILY — probed codex/agy/4090, 0 capable reachable\n' k4
check k4 PASS "DEGRADED_SINGLE_FAMILY + substantive reason"
mk 'crossfamily: UNKNOWN — consent unset, panel not probed this round\n' k5
check k5 PASS "UNKNOWN + reason naming why it was not probed"
mk 'crossfamily: DEGRADED_PANEL_UNUSED — codex/agy/gemini reachable, not recruited (scope)\n' k6
check k6 PASS "DEGRADED_PANEL_UNUSED + reason naming the reachable families"
mk 'crossfamily: panel(qwen,gpt-oss,glm) — clean, 0 findings\n' k7
check k7 PASS "capable families only — guard does not over-block a real panel"

echo "── closed holes (must BLOCK) ──"
mk 'axis2-evidence: PASS no-S\n' b1
check b1 BLOCK "no crossfamily line at all (silence — the original guard, still intact)"
mk 'crossfamily: none this round — 인라인 same-family\n' b2
check b2 BLOCK "'none' free prose (the shape found on disk)"
mk 'crossfamily: none this round — 도달 불가\n' b3
check b3 BLOCK "'none' asserting unreachable (the FALSE one that shipped)"
mk 'crossfamily: none\n' b4
check b4 BLOCK "bare 'none' (merges could-not / did-not / did-not-look)"
mk 'crossfamily: DEGRADED_SINGLE_FAMILY\n' b5
check b5 BLOCK "degrade value with no reason (silent degrade — the whole point)"
mk 'crossfamily: UNKNOWN\n' b6
check b6 BLOCK "UNKNOWN with no reason (unprobed rendered as zero)"
mk 'crossfamily: DEGRADED_PANEL_UNUSED\n' b7
check b7 BLOCK "PANEL_UNUSED with no reason ('did not' passing as 'could not')"
mk 'crossfamily: DEGRADED_SINGLE_FAMILY — degraded\n' b8
check b8 BLOCK "reason too vacuous (names no probe and no grounds)"
mk 'crossfamily: panel\n' b9
check b9 BLOCK "bare panel claim naming no family"
mk 'crossfamily: panel()\n' b10
check b10 BLOCK "panel() with empty family list"
mk 'crossfamily: DEGRADED\n' b11
check b11 BLOCK "near-miss token (not an enum value)"
mk 'crossfamily: codex/gpt-5.5 — R1..R4, 16 findings, CONVERGED\n' b12
check b12 BLOCK "legacy free-form engine string (pre-typed convention) now rejected"

echo "── cross-family review findings (agy/Gemini 3.1 Pro, 2026-08-08) ──"
mk 'crossfamily: panel(claude) — reviewed by another claude session\n' x1
check x1 BLOCK "panel names the AUTHOR'S own family (decorrelation gate not seeing decorrelation)"
mk 'crossfamily: panel(opus,sonnet) — two claude tiers\n' x2
check x2 BLOCK "two same-family tiers dressed as a 2-family panel"
mk 'crossfamily: panel(none)\n' x3
check x3 BLOCK "panel(none) — a non-run laundered through the parens"
mk 'crossfamily: panel(unprobed)\n' x4
check x4 BLOCK "panel(unprobed) — same laundering, other token"
mk 'crossfamily: single-family\n' x5
check x5 BLOCK "single-family on a LOAD-BEARING change (free no-ack bypass of the lane)"
mk 'crossfamily: UNKNOWN — 0\n' x6
check x6 BLOCK "grounds '0' (porous non-vacuity: bare digit passed)"
mk 'crossfamily: UNKNOWN — problem\n' x7
check x7 BLOCK "grounds 'problem' (matched on substring 'prob')"
mk 'crossfamily: UNKNOWN — client error\n' x8
check x8 BLOCK "grounds 'client error' (matched on substring 'cli')"
mk 'crossfamily: panel(voyage-3,bge-m3) — 2 families\n' x9
check x9 BLOCK "embedding models WITHOUT 'embed' in the name (denylist false negative)"
mk 'crossfamily: panel(armorm,starling-rm) — 2 families\n' x10
check x10 BLOCK "reward models emitting scalars, not findings"
mk 'crossfamily: panel(cohere-rank-v3) — reranker named 'rank' not 'rerank'\n' x11
check x11 BLOCK "reranker named 'rank' (denylist false negative)"
mk 'crossfamily: DEGRADED_SINGLE_FAMILY — agy sidecar daemon crashed on startup, none reachable\n' x12
check x12 PASS  "grounds naming agy (was rejected — keyword list omitted it)"

mk 'crossfamily: single-family\ncrossfamily: DEGRADED_SINGLE_FAMILY — probed codex/agy, 0 reachable\n' x13
check x13 BLOCK "two crossfamily lines — appended correction shadowed by stale first (codex net-new)"

echo "── review-capability guard (pmh-dev #41 field measurement) ──"
mk 'crossfamily: panel(qwen,embed,embed) — 3 families\n' c1
check c1 BLOCK "embeddings counted as panel members (the measured false panel)"
mk 'crossfamily: panel(embed,rerank,ocr) — 3 families\n' c2
check c2 BLOCK "every member incapable — '3 families', 0 reviewers"
mk 'crossfamily: panel(gpt-oss,safeguard) — 2 families\n' c3
check c3 BLOCK "safeguard classifier padding one real family"
# Ordering invariant: ineligibility is tested FIRST. Both tokens ALSO match a valid
# family (glm-ocr → glm, qwen-embedding → qwen), so an eligibility-first implementation
# admits them silently. This pair anchors the ORDER, not the list.
mk 'crossfamily: panel(glm-ocr) — glm family\n' c4
check c4 BLOCK "glm-ocr — matches a valid family AND an incapable class"
mk 'crossfamily: panel(qwen-embedding-8b) — qwen family\n' c5
check c5 BLOCK "qwen-embedding — same overlap, other direction"

echo
if [ "$FAIL" -eq 0 ]; then echo "✅ all $N fixtures behave"; else echo "❌ regression ($N fixtures run)"; fi
exit "$FAIL"
