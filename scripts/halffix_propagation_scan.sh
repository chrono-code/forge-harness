#!/usr/bin/env bash
# halffix_propagation_scan.sh — pre-commit advisory: this fix may have landed in only one copy.
#
# THE DEFECT — "반쪽-수리" (half-fix)
#   A defect class lives in N sibling copies. The fix lands in ONE and nothing says so. Measured 3x
#   in this project, and the shape is worse than the count: every one of the three occurred INSIDE
#   an edit that was itself repairing an earlier half-fix. scripts/psa_scan_lib.sh's header records
#   five such divergences found in a single 2026-07-26 audit — every confidentiality defect that
#   audit found was a divergence between duplicated copies, not a flaw in the idea.
#
# WHAT IT DOES
#   Takes the distinctive symbols and path literals touched by the staged diff, re-greps the tree,
#   and NAMES the tracked files that carry the same token but are not staged. That is the whole
#   contribution: the author already knows what they fixed; what they lose is the sibling.
#
# MARK, DO NOT BLOCK — this is mandated, not preferred. The spec for this debt is explicit:
#   "표시(차단 아님 — 정당한 복제도 있다)". Legitimate duplication exists (templates/ ships a
#   field-propagated copy of scripts/ ON PURPOSE, and selfcheck asserts they stay byte-identical).
#   A detector that blocks on correct duplication is a detector that gets disabled.
#
# THE DISCRIMINATOR — if every copy is staged, the fix propagated and this stays SILENT.
#   Without that, the scan fires loudest exactly when the author did the right thing. Two prior
#   claims on this same mistake in this repo: S5 (9/9 false positives, narrowed 2026-07-28) and
#   S6 (0 true positives on the planned surface, retargeted 2026-07-31). Lane N3 pins it.
#
# Usage:  bash scripts/halffix_propagation_scan.sh          # reads the staged diff of $PWD
# Opt out: put `noqa: half-fix` on any added line in the commit.

set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Deletions are excluded (ACM): a removed file's symbols surviving elsewhere is not a half-fix,
# it is the normal state of a deletion, and flagging it would be pure noise.
STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)
[ -n "$STAGED" ] || exit 0

DIFF=$(git diff --cached -U0 --diff-filter=ACM 2>/dev/null)
printf '%s' "$DIFF" | grep -qE '^\+.*noqa:?[[:space:]]*half-fix' && exit 0

# Anchor tokens, from CHANGED lines only (added and removed — a removed spelling is exactly what a
# sibling may still carry). Two shapes:
#   · identifiers >= 10 chars — long enough that a collision is meaningful. Shell/py keywords and
#     the everyday vocabulary (`then`, `echo`, `return`, `local`) are all shorter, so the length
#     floor does the keyword filtering without a denylist to maintain. (Lane N6.)
#   · path literals `a/b` — the spec names filenames as anchors alongside symbols. (Lane P7.)
# The ENCLOSING function counts as a changed symbol even when the edited line itself carries no
# distinctive token — and a half-fix is a function-level thing, so this is the common case, not an
# edge one. git already hands it over in the hunk header (`@@ -2 +2 @@ psa_low_allowlisted() {`),
# so the context comes for free rather than from a hand-rolled scope parser.
# Found by lane P1 failing: the fix edited only a `case` line, whose longest token was 9 chars, and
# the scan went silent on a textbook two-copy divergence.
CHANGED=$( { printf '%s\n' "$DIFF" | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)'
             printf '%s\n' "$DIFF" | sed -n 's/^@@ .* @@ //p'
           } )
TOKENS=$( { printf '%s\n' "$CHANGED" | grep -oE '[A-Za-z_][A-Za-z0-9_-]{9,}'
            printf '%s\n' "$CHANGED" | grep -oE '[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+'
          } | sort -u )
# NO early exit here. R1 (tokens) and R2 (whole-file copies) are INDEPENDENT rules, and an empty
# token set is the normal state for a short edit — `a() { :; }` → `a() { echo fixed; }` carries no
# 10-char anchor at all. An early `exit 0` on empty tokens silently disabled R2 for exactly the
# edits R2 exists to catch. (Caught by lane R2p, 2026-07-31, after the same shape had already
# passed 10/10 in the other lanes — a rule can be correct and unreachable.)

# Cap, and SAY SO when it bites. A silent truncation reads as "checked everything" when it did not.
MAX_TOKENS="${HALFFIX_MAX_TOKENS:-60}"
TOTAL=$(printf '%s\n' "$TOKENS" | grep -c .)
if [ "$TOTAL" -gt "$MAX_TOKENS" ]; then
  echo "  ℹ️  half-fix scan: $TOTAL anchor tokens in this diff, examining the first $MAX_TOKENS (raise with HALFFIX_MAX_TOKENS)." >&2
  TOKENS=$(printf '%s\n' "$TOKENS" | head -n "$MAX_TOKENS")
fi

# A token in many files is framework vocabulary, not a duplicated fix site. (Lane N5.)
MAX_FILES="${HALFFIX_MAX_FILES:-8}"
staged_has() { printf '%s\n' "$STAGED" | grep -qxF "$1"; }

hits=""
while IFS= read -r tok; do
  [ -n "$tok" ] || continue
  files=$(git grep -l --fixed-strings -e "$tok" -- . 2>/dev/null)
  [ -n "$files" ] || continue
  n=$(printf '%s\n' "$files" | grep -c .)
  [ "$n" -le "$MAX_FILES" ] || continue
  others=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    staged_has "$f" || others="${others}${others:+, }$f"
  done <<< "$files"
  [ -n "$others" ] || continue          # every copy staged → propagated → silent (lane N3)
  hits="${hits}  ⚠️  HALF-FIX \`$tok\` also lives in: $others
"
done <<< "$TOKENS"

# ── R2 — whole-file copy divergence. ─────────────────────────────────────────────────────────
# The token rule alone missed this repo's real duplicate pair: a script's NAME lives in 11–18 files
# here (docs, CATALOG, the manifest, selfcheck refs), so the ubiquity filter suppressed it, while an
# internal symbol like psa_low_allowlisted lives in 2. Measured 2026-07-31 — lanes 10/10 green, live
# probe silent. The lanes were necessary and not sufficient.
#
# Exact, not heuristic: the sibling was BYTE-IDENTICAL at HEAD and only one side is staged, so it is
# a divergence by construction and needs no threshold. Same-basename files that were never copies
# (CLAUDE.md vs templates/CLAUDE.md, the 40 SKILL.md files) stay silent — a basename rule would have
# flooded on exactly those.
while IFS= read -r sf; do
  [ -n "$sf" ] || continue
  base=$(basename "$sf")
  head_blob=$(git rev-parse "HEAD:$sf" 2>/dev/null) || continue
  while IFS= read -r cand; do
    [ -n "$cand" ] && [ "$cand" != "$sf" ] || continue
    staged_has "$cand" && continue
    cand_blob=$(git rev-parse "HEAD:$cand" 2>/dev/null) || continue
    [ "$cand_blob" = "$head_blob" ] || continue     # were they the SAME file before this edit?
    hits="${hits}  ⚠️  HALF-FIX \`$sf\` was byte-identical to \`$cand\` at HEAD — only one side is staged
"
  done <<< "$(git ls-files -- "*/$base" "$base" 2>/dev/null)"
done <<< "$STAGED"

[ -n "$hits" ] || exit 0

{
  echo "⚠️  HALF-FIX PROPAGATION — symbols you changed also exist in files you did NOT stage."
  echo "   Not a verdict: templates/ ships deliberate copies of scripts/. Judge each, then proceed."
  printf '%s' "$hits"
  echo "   Silence this commit with a \`noqa: half-fix\` comment on any added line."
} >&2
exit 0
