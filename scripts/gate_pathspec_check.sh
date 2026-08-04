#!/usr/bin/env bash
# gate_pathspec_check.sh — known-pair regression anchor for gate PATH COVERAGE.
#
# WHY THIS EXISTS
# The gate-locality class has now recurred four times: scripts/ (2026-06-26), AGENTS.md
# inheritance (#111/#117), agent definitions (2026-06-27), and SKILL_detail.md (2026-07-26).
# Every instance had the same shape: an asset class the canonical rule *declared* covered, which
# the gate implementation's path term did not actually match — and the miss rendered as PASS,
# because "no file matched" and "all files passed" are indistinguishable downstream.
#
# The 07-26 instance was the sharpest: the term was the literal `SKILL\.md`, and the string
# `SKILL_detail.md` does not contain `SKILL.md` (the underscore breaks it). 17 files, 208,710 B,
# 27.7% of the skill-spec surface, 16 of 17 holding fenced code blocks — ungated. It leaked twice
# for real (371c04f, e661931: single-file edits to a GATE SKILL's own behavioral spec).
#
# So this is not a style check. It is the mechanical anchor for the fix, per the FH rule that a
# harness edit is a draft until a check fails when the mistake recurs.
#
# METHOD — known-pair, per CLAUDE.md §Instrument-Calibration. Every case asserts BOTH directions:
# a known-positive that MUST match and a known-negative that MUST NOT. A checker that only ever
# confirms positives cannot tell "covers everything" from "matches everything".
#
# Usage: bash scripts/gate_pathspec_check.sh          # exit 0 = all pairs hold, 1 = a pair broke
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
GUARD="$REPO_ROOT/templates/regression_guard.sh"

fail=0
pass=0

# Extract a live regex from the implementation instead of restating it here. A copy would drift
# from the thing it claims to verify — which is the very defect class this file exists to catch.
extract_term() {  # $1 = file, $2 = variable-assignment marker
  grep -A2 "^${2}=" "$1" 2>/dev/null | grep -oE '\| grep -E "[^"]+"' | head -1 \
    | sed -E 's/^\| grep -E "//; s/"$//'
}

check() {  # $1 = label, $2 = regex, $3 = should-match path, $4 = should-NOT-match path
  local label="$1" re="$2" pos="$3" neg="$4" ok=1 rc
  # grep exits 2 on a MALFORMED regex. `if ! grep -q` would negate that 2 into "true" and report
  # it as "known-positive not covered" — fail-closed in direction, but it misnames the cause, and
  # a checker that misreports why it failed sends the next reader to fix the wrong thing.
  echo "$pos" | grep -qE "$re"; rc=$?
  if [ "$rc" -eq 2 ]; then
    echo "  ❌ $label — extracted pattern is not a valid regex (instrument error, NOT a coverage result)"
    echo "     pattern: $re"
    fail=$((fail + 1)); return
  fi
  [ "$rc" -ne 0 ] && { echo "  ❌ $label — known-POSITIVE not covered: $pos"; ok=0; }
  if echo "$neg" | grep -qE "$re"; then
    echo "  ❌ $label — known-NEGATIVE wrongly covered: $neg"; ok=0
  fi
  if [ "$ok" -eq 1 ]; then
    echo "  ✅ $label"; pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
}

echo "gate_pathspec_check — known-pair coverage anchors"
echo

# ── 1. pre-commit HEAVY term ──────────────────────────────────────────────────
HEAVY_RE="$(extract_term "$HOOK" HEAVY)"
if [ -z "$HEAVY_RE" ]; then
  echo "  ❌ could not extract HEAVY term from $HOOK — instrument error, NOT a pass"
  exit 1
fi
# The 07-26 regression: detail files must be HEAVY. Negative: a tracks/ record must not be.
check "HEAVY covers SKILL_detail.md" "$HEAVY_RE" \
  "plugins/fh-meta/skills/frontier-digest/SKILL_detail.md" \
  "tracks/_meta/fh_signal_2026-07-26_ai.md"
check "HEAVY still covers SKILL.md" "$HEAVY_RE" \
  "plugins/fh-meta/skills/frontier-digest/SKILL.md" \
  "README.md"
# Prior gate-locality instances — anchored so a future edit cannot silently drop them.
check "HEAVY covers agent definitions (seam #3)" "$HEAVY_RE" \
  "plugins/fh-meta/agents/challenger.md" \
  "docs/README.md"
check "HEAVY covers scripts/*.sh (seam #1)" "$HEAVY_RE" \
  "scripts/gate_pathspec_check.sh" \
  "tracks/_audit/session_2026_07_26_agentsmith-sister.md"

# ── 2. regression_guard GUARD_PATHSPEC ────────────────────────────────────────
# Read the array as the guard itself defines it; match with the same glob semantics git uses.
# NOTE: no `mapfile` — macOS ships bash 3.2, where it does not exist. This is the documented
# bash-3.2 portability class; a 4.x-only builtin here would make the anchor itself the thing that
# breaks on the operator's own machine.
SPEC=()
while IFS= read -r line; do
  [ -n "$line" ] && SPEC+=("$line")
done < <(sed -n '/^GUARD_PATHSPEC=(/,/^)/p' "$GUARD" | grep -oE "'[^']+'" | tr -d "'")
if [ "${#SPEC[@]:-0}" -eq 0 ]; then
  echo "  ❌ could not extract GUARD_PATHSPEC from $GUARD — instrument error, NOT a pass"
  exit 1
fi
spec_matches() {  # $1 = path
  local p="$1" g
  for g in "${SPEC[@]}"; do
    # shellcheck disable=SC2254
    case "$p" in $g) return 0 ;; esac
  done
  return 1
}
for pair in \
  "plugins/fh-meta/skills/frontier-digest/SKILL_detail.md|tracks/_meta/x.md|PATHSPEC covers SKILL_detail.md" \
  "plugins/fh-meta/skills/frontier-digest/SKILL.md|README.md|PATHSPEC still covers SKILL.md" \
  "CLAUDE.md|CLAUDE.local.md|PATHSPEC covers CLAUDE.md but not the local override" \
  "scripts/selfcheck.sh|README.md|PATHSPEC covers scripts/*.sh (seam #1 — the HEAVY term already gated it, this array did not)" \
  "scripts/sub/nested.sh|package.json|PATHSPEC covers scripts/ recursively (git/bash globs cross '/')" \
  "templates/regression_guard.sh|package-lock.json|PATHSPEC covers templates/*.sh — i.e. the guard can guard ITSELF" \
  "templates/.git-hooks/pre-commit|.gitignore|PATHSPEC covers the git-hook floor (the hook that hard-blocks commits)" \
  "plugins/fh-meta/agents/challenger.md|tracks/_meta/y.md|PATHSPEC covers agent definitions (seam #3)"
do
  IFS='|' read -r pos neg label <<< "$pair"
  ok=1
  spec_matches "$pos" || { echo "  ❌ $label — known-POSITIVE not covered: $pos"; ok=0; }
  spec_matches "$neg" && { echo "  ❌ $label — known-NEGATIVE wrongly covered: $neg"; ok=0; }
  if [ "$ok" -eq 1 ]; then echo "  ✅ $label"; pass=$((pass + 1)); else fail=$((fail + 1)); fi
done

# ── 3. Canonical-vs-implementation parity ─────────────────────────────────────
# regression_guard.sh's own comment: "두 목록이 갈리면 갈린 쪽이 조용히 무검사 구간이 된다."
# Anchor that warning mechanically for the asset class that just broke.
CANON="$REPO_ROOT/.claude/rules/fh_4axis_gate.md"
# Scope the match to the ASSET-LIST sentence, not the whole file. A bare whole-file grep would go
# green on a line that says "SKILL_detail.md is excluded" — i.e. it would certify parity against
# documentation that contradicts the code. Match the declaration line itself.
if grep -q 'Whenever the AI modifies FH assets.*SKILL_detail\.md' "$CANON" 2>/dev/null; then
  echo "  ✅ canonical rule declares SKILL_detail.md (in the asset-list line)"; pass=$((pass + 1))
else
  echo "  ❌ canonical rule ($CANON) no longer declares SKILL_detail.md — the two lists diverged,"
  echo "     which is exactly the silent no-check condition this anchor exists to prevent."
  fail=$((fail + 1))
fi

# ── 4. Enumeration sweep — the anti-guessing check ────────────────────────────
# Every fix above answers "is THIS name covered?" — which only ever closes the names someone
# thought of. This one inverts it: enumerate what actually EXISTS under plugins/*/skills/ and
# assert the HEAVY term covers all of it. A new companion-file convention (SKILL_summary.md,
# a nested docs/ page, a deeper skill directory) then fails HERE, at introduction, instead of
# waiting for someone to notice the naming gap years later. Reality is the input, not a guess.
# (Adversarial credit: an Axis-2 sidecar pass argued the name-by-name fixes could not, in
# principle, close the class — correct, and this is the answer to it.)
uncovered=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  echo "$f" | grep -qE "$HEAVY_RE" || uncovered="$uncovered$f
"
done < <(cd "$REPO_ROOT" && find plugins -path '*/skills/*' -name '*.md' -type f 2>/dev/null | sort)
if [ -z "$uncovered" ]; then
  echo "  ✅ enumeration: every .md under plugins/*/skills/ is covered by the HEAVY term"
  pass=$((pass + 1))
else
  echo "  ❌ enumeration: files exist under plugins/*/skills/ that NO gate term covers —"
  printf '%s' "$uncovered" | sed 's/^/       /'
  echo "     Either widen the gate term, or state in fh_4axis_gate.md why this class is exempt."
  fail=$((fail + 1))
fi

# ── 5. CLAUDE.md asset-list parity — the FIXED per-class needle table ─────────
# WHY A TABLE, AND WHY FIXED. A parity check was attempted for this on 2026-08-03 and CUT the same
# day: it guessed its needles per run, produced four findings in one adversarial round, and — the
# decisive part — never fired on `CLAUDE.md` at all, because `CLAUDE\.md` was not in the hook's
# GATE_IMPL trigger. Both defects are addressed here and neither is optional: the needles below are
# FIXED (a literal table, reviewed as data), and the hook gained a SEPARATE trigger
# (`ASSETLIST_IMPL`) so this anchor actually runs when the list it guards is edited. The trigger is
# deliberately NOT `GATE_IMPL`: that variable also feeds `$LOADBEARING`, and enrolling every
# CLAUDE.md prose edit into cross-family review is a different job. Retrying without both the
# fixed table AND a trigger repeats the cut.
#
# WHAT IT GUARDS. `CLAUDE.md` §FH Improvement 4-Axis Auto-Gate carries a canonical asset list, and
# `.claude/rules/fh_4axis_gate.md` carries another. When a class is added to the hook but not to a
# prose list (or dropped from one list only), the divergence is silent — the gate still blocks, so
# nothing goes red, while the resident text tells readers a class is not covered. That is the exact
# shape measured on 2026-08-03, when two classes were added to both lists with no anchor behind them.
#
# SCOPE, deliberately narrow: this asserts the asset-list SENTENCE names each class. It does not
# assert the hook and the sentence are equal sets — that stronger claim needs a parse of the regex
# into classes, which is the guessing this table replaces. Narrow and mechanical beats broad and
# self-generating; the enumeration sweep in §4 is where breadth lives.
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
# Read the STAGED blob as well as the worktree, and require BOTH to declare the class.
# Cross-family review (2026-08-04, codex/gpt-5.5) reproduced the fail-open: reading only the worktree
# lets a commit stage a broken asset line, repair the worktree WITHOUT staging, and pass — the hook
# sees CLAUDE.md in $STAGED, runs this anchor, and validates content that is not what is being
# committed. Measured before the fix: index 0 occurrences / worktree 1 / anchor exit 0.
# Checking only the index would invert the same hole (a broken UNSTAGED edit would pass a manual
# run), so both are required. `git show :CLAUDE.md` fails outside a repo or with nothing in the
# index; that is a skip of the staged leg, never a pass of it.
_asset_line_of() {  # $1 = file-or-'-' content source label; reads stdin
  grep -m1 '^\*\*FH 자산을 수정하면\*\*' || true
}
ASSET_LINE=$(_asset_line_of < "$CLAUDE_MD" 2>/dev/null || true)
# Distinguish "not in the index" (a real skip) from "git failed" (an instrument error). The advisory
# degrade lint flagged the first draft here, and correctly: a bare `|| true` let the staged leg
# silently abstain on ANY git failure, which half-reopens the fail-open this section was just fixed
# for. Tracked files always have an index entry, so for this repo the abstain branch is unreachable
# in normal operation — it exists for a clone where CLAUDE.md is untracked.
if git -C "$REPO_ROOT" ls-files --error-unmatch CLAUDE.md >/dev/null 2>&1; then
  ASSET_LINE_STAGED=$(git -C "$REPO_ROOT" show :CLAUDE.md 2>/dev/null | _asset_line_of)
  if [ -z "$ASSET_LINE_STAGED" ]; then
    echo "  ❌ CLAUDE.md is tracked but its staged blob yielded no declaration line —"
    echo "     instrument error (or the staged content dropped the line entirely), NOT a pass."
    fail=$((fail + 1))
  fi
else
  ASSET_LINE_STAGED=""   # untracked clone — worktree leg is the only measurable one
fi
if [ -z "$ASSET_LINE" ]; then
  echo "  ❌ CLAUDE.md asset-list declaration line not found — instrument error, NOT a pass"
  echo "     (looked for a line starting '**FH 자산을 수정하면**' in $CLAUDE_MD)"
  fail=$((fail + 1))
else
  # label|needle (ERE, matched against the declaration line only)
  for entry in \
    'SKILL.md|SKILL\.md' \
    'SKILL_detail.md|SKILL_detail\.md' \
    '.claude/rules|\.claude/rules/' \
    'knowledge/shared/rules|knowledge/shared/rules/' \
    'templates/|templates/' \
    'CLAUDE.md|CLAUDE\.md' \
    'AGENTS.md|AGENTS\.md' \
    'scripts/**/*.sh|scripts/\*\*/\*\.sh' \
    'agent definitions (plugins/*/agents)|plugins/\*/agents/' \
    'agent definitions (.claude/agents)|\.claude/agents/'
  do
    lbl="${entry%%|*}"; needle="${entry#*|}"
    _hit=1
    printf '%s' "$ASSET_LINE" | grep -qE "$needle" || _hit=0
    # The staged leg only votes when it exists — an empty index blob is "not measured", not "absent".
    if [ -n "$ASSET_LINE_STAGED" ]; then
      printf '%s' "$ASSET_LINE_STAGED" | grep -qE "$needle" || _hit=0
    fi
    if [ "$_hit" -eq 1 ]; then
      echo "  ✅ CLAUDE.md asset list declares: $lbl"; pass=$((pass + 1))
    else
      echo "  ❌ CLAUDE.md asset list no longer declares: $lbl"
      echo "     The hook still gates it, so nothing goes red — the resident text now tells readers"
      echo "     a gated class is not covered. Re-add it, or retire the class from the hook too."
      fail=$((fail + 1))
    fi
  done
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "gate_pathspec_check: PASS ($pass pairs)"
  exit 0
fi
echo "gate_pathspec_check: FAIL ($fail broken, $pass ok)"
echo "A gate path term stopped covering an asset class it is declared to cover."
echo "Do NOT relax the anchor to make it green — fix the term, or retire the pair deliberately."
exit 1
