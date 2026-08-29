#!/usr/bin/env bash
# test_precommit_staged_drift_lanes.sh — fixtures for pre-commit's `staged_worktree_drift`.
#
# WHAT IT GUARDS. "The tree you verified is not the tree you commit" happened FOUR times in one
# day (2026-08-29/30) and a DIFFERENT instrument caught each one — which is luck, not coverage:
#   ⑴ a pathspec failure was ignored and the verification credited to the commit anyway
#   ⑵ a file was edited AFTER `git add`
#   ⑶ a detector read the git index while the author ran it against the worktree
#   ⑷ the caller-ratchet could not see new wiring until it was staged
# Only shape ⑵ is computable at commit time, and it is: `git diff` ∩ `git diff --cached`.
# This suite pins that computation, not the judgement about whether the drift matters.
#
# 🟥 SCOPE — channel, never conclusion. The gate says "these two byte streams diverged" and stops.
# It must NEVER block: partial/hunk staging is legitimate practice, and a gate that fires on it
# trains `--no-verify`, which disarms the Destructive-Op gate living in the same hook. So there is
# no BLOCK lane here on purpose — the absence is the design, and L5 pins it.
#
# Usage: bash scripts/test_precommit_staged_drift_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

sed -n '/^staged_worktree_drift()/,/^}/p' "$HOOK" > "$T/fn.sh"

# 🟥 INSTRUMENT CALIBRATION FIRST. An empty extraction would let every fixture below "pass"
# against nothing — the exact false-green this repo keeps closing elsewhere.
if ! grep -q 'comm -12' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — staged_worktree_drift did not extract from $HOOK."
  echo "   The fixtures would measure an empty function. Aborting rather than reporting green."
  exit 1
fi
# shellcheck disable=SC1090
. "$T/fn.sh"

pass=0; fail=0
ok() { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
no() { fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        got: %s\n' "$(printf '%s' "${2:-}" | tr '\n' '|')"; }

# L1 — the real shape: a file both staged and further modified
o=$(staged_worktree_drift "a.sh
b.md" "b.md")
[ "$o" = "b.md" ] && ok "L1 a path in BOTH lists is reported" || no "L1" "$o"

# L2 — known-negative: staged only, no worktree edit → silent
o=$(staged_worktree_drift "a.sh
b.md" "c.txt")
[ -z "$o" ] && ok "L2 control — disjoint lists report nothing (no false positive)" || no "L2" "$o"

# L3 — worktree-only changes are NOT drift. A file you never staged is not "verified ≠ committed";
# it is simply not in this commit. Reporting it would make the gate noisy on every partial commit
# and that noise is how an advisory gets ignored.
o=$(staged_worktree_drift "a.sh" "b.md
c.txt")
[ -z "$o" ] && ok "L3 control — unstaged-only paths are not reported" || no "L3" "$o"

# L4 — empty inputs. Both directions, because "nothing to compare" and "nothing diverged" take the
# same action here (do nothing), and the lane records that the collapse is deliberate.
o=$(staged_worktree_drift "" "")
[ -z "$o" ] && ok "L4 empty ∩ empty is empty" || no "L4" "$o"
o=$(staged_worktree_drift "" "a.sh")
[ -z "$o" ] && ok "L4b empty staged ∩ nonempty worktree is empty" || no "L4b" "$o"

# L5 — THE GATE MUST NOT BLOCK. Pinned as a lane because the whole design rests on it: a blocking
# version would fire on legitimate hunk staging and train `--no-verify`.
if grep -A14 '^_DRIFT=' "$HOOK" | grep -qE 'FAILED=1|exit 1'; then
  no "L5 the drift gate sets FAILED/exit — it must stay advisory"
else
  ok "L5 the drift gate never blocks (advisory by construction)"
fi

# L6 — ordering must not matter; the function sorts. A caller handing git's raw output in a
# different order must get the same verdict.
o1=$(staged_worktree_drift "b.md
a.sh" "a.sh
b.md")
o2=$(staged_worktree_drift "a.sh
b.md" "b.md
a.sh")
[ "$o1" = "$o2" ] && [ -n "$o1" ] && ok "L6 order-independent (both orders agree, non-empty)" \
                                  || no "L6" "$o1 // $o2"

# L7 — duplicates collapse. `git diff` can list a path twice across modes; a doubled report line
# would read as two problems.
o=$(staged_worktree_drift "a.sh
a.sh" "a.sh")
[ "$(printf '%s\n' "$o" | grep -c .)" = "1" ] && ok "L7 duplicate input reports once" || no "L7" "$o"

echo "staged-drift lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
