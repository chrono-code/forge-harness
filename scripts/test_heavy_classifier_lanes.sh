#!/usr/bin/env bash
# test_heavy_classifier_lanes.sh — known-pair anchor for the pre-commit HEAVY/LIGHT path classifier.
#
# WHY: the classifier is three `grep -E` lines, and everything downstream of it — Axes 2+3, the
# marker, the whole full-gate path — is gated on what they match. A term missing from those lines
# does not FAIL; it makes the gate **silently not apply**, and the commit goes green. There is no
# louder symptom. Nothing was watching the watcher: measured 2026-08-20, `scripts/test_*.sh` files
# testing this classifier = **0**, while 12 test files touch the hook for other reasons.
#
# Absorbed from a sibling harness (pmh-dev, 2026-08-08) rather than invented here. The load-bearing
# idea is the extraction below, not the fixture list.
#
# 🟥 FH's classifier is FOUR-WAY, not two-way like the sibling's. The port is not a copy:
#     HEAVY     → full gate
#     CARVEOUT  → knowledge/ · docs/*.md · AGENTS.md — promoted to HEAVY only if the diff is
#                 substantive (adds a fenced block or a citation), else demoted to LIGHT
#     LIGHT     → CATALOG.md · tracks/
#     uncovered → matches none of the three. **This class is real and is pinned below** — a path
#                 nobody classified is the quietest way for a surface to leave the gate.
#
# This lane pins all four directions. Over-matching is a defect too: a gate that fires on every
# commit is the one people learn to bypass with `--no-verify`, which disarms the Destructive-Op
# gate living in the same hook.
#
# Usage: bash scripts/test_heavy_classifier_lanes.sh   → exit 0 if all pairs hold, 1 otherwise.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
[ -r "$HOOK" ] || { echo "❌ FAIL — $HOOK not readable"; exit 1; }

FAILED=0

# Extract the LIVE regexes from the hook rather than restating them. A lane that hard-codes its own
# copy of the pattern passes forever while the real classifier drifts away underneath it — that is
# testing the fixture instead of the subject, and it is the failure this whole file exists to catch.
_extract() { # $1 = variable name as it appears at column 0 in the hook
  sed -n "/^$1=\\\$(echo \"\\\$STAGED\"/,/|| true)/p" "$HOOK" \
    | grep -o 'grep -E "[^"]*"' | head -1 | sed 's/^grep -E "//; s/"$//'
}
HEAVY_RE=$(_extract HEAVY)
CARVE_RE=$(_extract CARVEOUT)
LIGHT_RE=$(_extract LIGHT)

# 🟥 Fail CLOSED on extraction failure. An empty regex makes `grep -qE ""` match EVERYTHING, so a
# silent extraction failure would turn this lane green while classifying every path as heavy.
for v in HEAVY_RE CARVE_RE LIGHT_RE; do
  if [ -z "${!v}" ]; then
    echo "❌ FAIL — could not extract \$$v from the hook."
    echo "   The hook's shape changed. Fix THIS extraction — do not delete the lane, and do not"
    echo "   inline a copy of the pattern here (that is how a lane stops covering its subject)."
    exit 1
  fi
done

classify() { # <path> → heavy | carveout | light | uncovered
  # Order mirrors the hook: HEAVY wins, then CARVEOUT (which the hook excludes
  # knowledge/shared/rules/ from, since that is already HEAVY), then LIGHT.
  if printf '%s\n' "$1" | grep -qE "$HEAVY_RE"; then echo heavy
  elif printf '%s\n' "$1" | grep -qE "$CARVE_RE"; then echo carveout
  elif printf '%s\n' "$1" | grep -qE "$LIGHT_RE"; then echo light
  else echo uncovered; fi
}

check() { # <expect> <path> <why>
  local expect="$1" path="$2" why="$3" got
  got=$(classify "$path")
  if [ "$got" = "$expect" ]; then
    printf '  ✅ %-9s %-52s %s\n' "$expect" "$path" "$why"
  else
    printf '  ❌ %-9s %-52s expected %s, got %s\n' "$expect" "$path" "$expect" "$got"
    FAILED=1
  fi
}

echo "[heavy-classifier] known-pair anchor (4-way)"
echo "  ── must be HEAVY (full 4-axis gate applies) ──"
check heavy "plugins/fh-meta/skills/steel-quench/SKILL.md"        "skill spec"
check heavy "plugins/fh-meta/skills/goal-quench/SKILL_detail.md"  "detail file — the salience-split half"
check heavy "plugins/fh-meta/skills/fh/assets/note.md"            "any md under a skill dir"
check heavy "plugins/fh-meta/agents/challenger.md"                "agent definition"
check heavy ".claude/agents/local.md"                             "repo-local agent definition"
check heavy ".claude/rules/fh_4axis_gate.md"                      "gate rule"
check heavy "knowledge/shared/rules/operations.md"                "shared rules — HEAVY, not carveout"
check heavy "templates/.git-hooks/pre-commit"                     "the gate machinery itself"
check heavy "templates/CLAUDE.md"                                 "propagated field asset"
check heavy "CLAUDE.md"                                           "the resident layer"
check heavy "scripts/selfcheck.sh"                                "shipped executable"
check heavy "scripts/adapters/qasp_web_rules.sh"                  "nested script still matches"

echo "  ── CARVEOUT (heavy only if the diff is substantive) ──"
check carveout "knowledge/shared/harness-core/sonnet_floor_doctrine.md" "doctrine prose"
check carveout "docs/USER_GUIDE.md"                                    "published guide"
check carveout "AGENTS.md"                                             "Codex entry point"

echo "  ── must stay LIGHT (over-firing trains --no-verify) ──"
check light "CATALOG.md"                     "index entry"
check light "tracks/_meta/fh_completed.md"   "session record"
check light "tracks/qasp/NEXT_ACTION.md"     "field track record"

echo "  ── honestly UNCOVERED — pinned so the residual cannot be believed closed ──"
check carveout  "README.md"                  "npm-shipped surface — first-screen edits promote to HEAVY (2026-08-28)"
check carveout  "README.ko.md"               "language variants route the same way"
check carveout  "README.zh-CN.md"            "🟥 5-char locale forms too — cross-family caught [a-z]{2} missing these"
check uncovered ".claude/registry/README.md" "🟥 STILL UNCOVERED — in files[] but not root; named, not closed"
check uncovered "package.json"               "files[] / version changes are unclassified"
check uncovered ".github/workflows/validate.yml" "🟥 CI definition — changing what CI runs is unclassified"
check uncovered "scripts/memory_link_check.py"   "🟥 .py is not .sh — shipped python is unclassified"

echo "  ── controls (the classifier discriminates, it does not just fire) ──"
# known-negative: a path that resembles a HEAVY one but must not match. This is the arm that
# separates "the classifier works" from "the classifier fires on everything" — without it, a
# regex of `.` would pass every HEAVY row above.
check uncovered "notes/scripts/foo.sh.txt"   "control — .sh.txt is not a shell script (\$-anchored)"
check uncovered "notes/skills-overview.md"   "control — 'skills' in a path is not a skill spec"
# ⚠️ this control was first written as `docs/design/skills-overview.md`, which the lane
#    correctly classified `carveout` (`^docs/.*\.md$`). The FIXTURE was wrong, not the
#    subject — pick a path outside every class when the claim is "matches none of them".

# 🟥 KNOWN OVER-MATCH, pinned deliberately as `heavy` rather than "fixed" (2026-08-20).
# `SKILL(_detail)?\.md` is written WITHOUT a `$` anchor, so any path merely CONTAINING that
# substring classifies HEAVY — `SKILL.md.bak`, `SKILL.md.orig`, `SKILL.md~`. Recorded, not
# repaired, for three reasons, and the reasons are the point:
#   ⓐ the error direction is fail-SAFE — it adds gate coverage, never removes it. The classifier's
#     dangerous direction is under-matching (the gate silently not applying), which this is not.
#   ⓑ those paths are not committed in practice, so the over-block the hook warns about
#     ("a gate that always fires is the one people learn to bypass") does not actually fire here.
#   ⓒ anchoring it is a live change to gate routing, and gate routing is exactly what this lane
#     exists to detect changes in. Changing the subject in the same commit that first measures it
#     leaves no before-state.
# This row is therefore a RECORD, not an endorsement: if someone anchors the pattern later, this
# line goes red and they will read this comment — which is the whole job of a known-pair.
check heavy "docs/skills/SKILL.md.bak"       "🟥 over-match: pattern is unanchored (see comment)"

echo
echo "🟥 NOT COVERED BY THIS LANE (named, not silently absent):"
echo "   · \`diff_is_substantive\` — whether a CARVEOUT file is promoted depends on diff CONTENT,"
echo "     not path. This lane pins the PATH class only. That test needs its own anchor."
echo "   · the hook's behaviour once classified (marker required, manifest required). Pinned"
echo "     elsewhere (test_marker_*_lanes.sh); this lane covers only the routing decision."

if [ "$FAILED" -eq 0 ]; then
  echo "✅ heavy-classifier: all pairs hold"
  exit 0
fi
echo "❌ heavy-classifier: at least one pair broke — the gate's routing changed"
exit 1
