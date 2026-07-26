#!/usr/bin/env bash
# prepush_guard_check.sh — known-pair anchor for the pre-push PUBLISH-boundary guards.
#
# Sibling of scripts/universal_guard_check.sh (which anchors the pre-COMMIT universal guards).
# This one anchors what pre-push added on 2026-07-26: the confidentiality CONTENT scan over the
# commits a push would actually publish, and the load-bearing cross-family acknowledgment.
#
# WHY IT EXISTS AS A SCRIPT AND NOT AS A CHECKLIST — measured, twice, in one session:
#   While repairing this very hook, TWO fail-opens were authored into it and neither was caught by
#   the checks in use at the time:
#     (1) `git show $(git rev-list …)` expanded every SHA into argv; on a large push that hits
#         ARG_MAX, git dies, the capture is empty, and an empty capture reads as "no hits" → PASS.
#     (2) A mangled `${...}` produced a RUNTIME "bad substitution" that aborted the hook — and the
#         hook still exited 0, i.e. every push allowed. `bash -n` PASSED on that file: bad
#         substitution is a runtime error, not a parse error. Syntax-checking a gate is not testing it.
#   So this anchor always runs the hook FOR REAL and greps the output for runtime faults, in addition
#   to checking verdicts. A gate that aborts must never be readable as a gate that passed.
#
# Runs in throwaway repos (mktemp): never touches this repo's index or worktree.
# Usage: bash scripts/prepush_guard_check.sh   → exit 0 all pairs hold, 1 otherwise.
set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HOOK_SRC="$REPO_ROOT/templates/.git-hooks/pre-push"
DEF_SRC="$REPO_ROOT/.claude/rules/.public-surface-patterns.defaults"
[ -f "$HOOK_SRC" ] || { echo "❌ FAIL — pre-push hook not found"; exit 1; }
[ -f "$DEF_SRC" ]  || { echo "❌ FAIL — pattern defaults not found"; exit 1; }

# Test the STAGED blob when the hook is staged — same reasoning as universal_guard_check.sh: an
# anchor that reads the worktree can be bypassed by staging a regression and restoring the worktree.
WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT
_status=$(git -C "$REPO_ROOT" -c core.quotePath=false diff --cached --name-status --no-renames 2>/dev/null \
          | awk -F'\t' '$2 == "templates/.git-hooks/pre-push" { print $1; exit }')
case "$_status" in
  D) echo "❌ FAIL — pre-push is being DELETED from the index — fail-closed."; exit 1 ;;
  '') cp "$HOOK_SRC" "$WORK/hook" ;;
  *) git -C "$REPO_ROOT" show ":templates/.git-hooks/pre-push" > "$WORK/hook" 2>/dev/null \
       || { echo "❌ FAIL — staged pre-push blob unreadable — fail-closed."; exit 1; } ;;
esac
HOOK="$WORK/hook"

FAILED=0
# Fixtures assembled at runtime so this file's own bytes carry no matching credential shape
# (same rule as universal_guard_check.sh — a fixture file excluded from scanning would be a hole).
AWSK="AKIA""1234567890ABCDEF"
PATK="ghp""_abcdefghijklmnopqrstuvwxyz012345"
DOCK="AKIAIOSFODNN7EXAMPLE"     # the documented example key: must be exempt, so it stays literal

newrepo() {  # echoes a fresh repo path with the pattern layers in place and one base commit
  local d; d=$(mktemp -d)
  mkdir -p "$d/.claude/rules" "$d/templates/.git-hooks" "$d/tracks/_meta"
  cp "$DEF_SRC" "$d/.claude/rules/.public-surface-patterns.defaults"
  # The operator override is GITIGNORED in the real repo, so it never enters history. Committing it
  # here made its own literals show up as leaks in the pushed content — a fixture artifact that read
  # exactly like a product defect. Mirror reality instead.
  printf '.claude/rules/.public-surface-patterns\n' > "$d/.gitignore"
  printf 'HIGH\tzzsynthoperator\n' > "$d/.claude/rules/.public-surface-patterns"
  cp "$HOOK" "$d/templates/.git-hooks/pre-push"
  ( cd "$d" && git init -q -b main && git config user.email t@example.com && git config user.name t \
    && git add -A >/dev/null 2>&1 && git commit -qm base >/dev/null 2>&1 ) || return 1
  printf '%s' "$d"
}

# check <name> <repo> <expect: block|pass> <refline...>
check() {
  local name="$1" repo="$2" expect="$3"; shift 3
  local out rc got
  out=$(printf '%s\n' "$@" | ( cd "$repo" && bash templates/.git-hooks/pre-push origin git@example:x/y.git 2>&1 )); rc=$?
  # A runtime fault is its own failure mode, checked BEFORE the verdict: an aborted hook that exits 0
  # would otherwise be scored as a clean pass — the exact defect this anchor was written for.
  if printf '%s' "$out" | grep -qiE 'bad substitution|unbound variable|syntax error|command not found'; then
    echo "  ❌ $name — RUNTIME FAULT in the hook (a hook that aborts is not a hook that passed)"
    printf '%s\n' "$out" | grep -iE 'bad substitution|unbound|syntax error|command not found' | sed 's/^/       /' | head -3
    FAILED=1; return
  fi
  # A hook killed by a signal, or one that dies printing nothing, produces no fault TEXT — the grep
  # above cannot see it, and rc alone would score it as a pass (R7 audit, 2026-07-26). So a `pass`
  # additionally requires the leg's own marker line: proof it ran to the point of making a claim.
  if [ "$rc" -ne 0 ]; then
    got=block
  elif printf '%s' "$out" | grep -qF 'FH Pre-Publish'; then
    got=pass
  else
    echo "  ❌ $name — hook exited 0 without reaching the publish check (silent abort is not a pass)"
    printf '%s\n' "$out" | sed 's/^/       | /' | head -5
    FAILED=1; return
  fi
  if [ "$got" = "$expect" ]; then
    echo "  ✅ $name (expected $expect)"
  else
    echo "  ❌ $name — expected $expect, got $got"
    printf '%s\n' "$out" | sed 's/^/       | /' | head -8
    FAILED=1
  fi
}

echo "[prepush-guard] known-pair anchor"

# ── Pair 1: a token in the pushed HISTORY, with a clean tip. Net-diff-based scanning misses this. ──
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && printf 'tok %s\n' "$PATK" > s.md && git add s.md && git commit -qm add >/dev/null \
  && git rm -q s.md && git commit -qm remove >/dev/null )
check "token added then REMOVED (history)  → BLOCK" "$R" block \
      "refs/heads/f $(cd "$R" && git rev-parse HEAD) refs/heads/f $B"
rm -rf "$R"

# ── Pair 2: evidence truncation. Twenty documented example keys ahead of one real key used to
# produce zero hits AND an affirmative "no token" line — wrong out loud, not merely incomplete. ──
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && for i in $(seq 1 20); do echo "example: $DOCK"; done > d.md \
  && echo "real: $AWSK" >> d.md && git add d.md && git commit -qm docs >/dev/null )
check "20 example keys THEN a real key     → BLOCK" "$R" block \
      "refs/heads/f $(cd "$R" && git rev-parse HEAD) refs/heads/f $B"
rm -rf "$R"

# ── Pair 3: same line, placeholder first. Taking only the first match per line hid the real token. ──
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && printf '%s then %s\n' "$DOCK" "$AWSK" > e.md && git add e.md && git commit -qm same >/dev/null )
check "placeholder BEFORE real, same line  → BLOCK" "$R" block \
      "refs/heads/f $(cd "$R" && git rev-parse HEAD) refs/heads/f $B"
rm -rf "$R"

# ── Pair 4: no over-blocking. Documented example keys alone must push cleanly, or the override
# becomes routine and the gate is disarmed. ──
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && for i in $(seq 1 20); do echo "example: $DOCK"; done > f.md && git add f.md && git commit -qm only >/dev/null )
check "documented example keys only        → PASS " "$R" pass \
      "refs/heads/f $(cd "$R" && git rev-parse HEAD) refs/heads/f $B"
rm -rf "$R"

# ── Pair 5: multi-ref push. Ranges concatenated into one arg list let `--not` from ref A flip
# polarity for ref B, so a token on the second branch went unseen. ──
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && git checkout -qb clean1 "$B" && echo ok > c1.md && git add c1.md && git commit -qm c1 >/dev/null \
  && git checkout -qb dirty2 "$B" && printf 'tok %s\n' "$PATK" > c2.md && git add c2.md && git commit -qm c2 >/dev/null )
C1=$(cd "$R" && git rev-parse clean1); C2=$(cd "$R" && git rev-parse dirty2)
check "multi-ref push, token on 2nd ref    → BLOCK" "$R" block \
      "refs/heads/clean1 $C1 refs/heads/clean1 $B" \
      "refs/heads/dirty2 $C2 refs/heads/dirty2 $B"
rm -rf "$R"

# ── Pair 6: instrument completeness. An absent operator override is fail-closed at the PUBLISH
# boundary (it only warns at commit time — that asymmetry is deliberate, see the hook's comment). ──
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && echo ok > g.md && git add g.md && git commit -qm g >/dev/null && rm -f .claude/rules/.public-surface-patterns )
check "operator override ABSENT            → BLOCK" "$R" block \
      "refs/heads/f $(cd "$R" && git rev-parse HEAD) refs/heads/f $B"
rm -rf "$R"

# ── Pair 7: a pattern row with a SPACE instead of a TAB defines no detector. Silently skipping it
# (this copy's behaviour until the R7 sweep) certifies a push clean against a pattern that never
# existed. pre-commit and the publish scanner were already fail-closed; this one was missed. ──
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && printf 'HIGH zzsynthoperator\n' > .claude/rules/.public-surface-patterns \
  && printf 'token zzsynthoperator\n' > n.md && git add -A && git commit -qm notab >/dev/null )
check "pattern row with SPACE not TAB     → BLOCK" "$R" block \
      "refs/heads/f $(cd "$R" && git rev-parse HEAD) refs/heads/f $B"
rm -rf "$R"

# ── Pair 8: a NEW branch whose commits already exist on a DIFFERENT remote. `--not --remotes`
# excludes commits reachable from ANY remote, so the range came out empty and the push published
# them to THIS remote unscanned. Simulated by planting a refs/remotes ref for another remote. ──
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && printf 'tok %s\n' "$PATK" > o.md && git add o.md && git commit -qm other >/dev/null \
  && git update-ref refs/remotes/otherremote/main "$(git rev-parse HEAD)" )
check "new branch, commits on ANOTHER remote → BLOCK" "$R" block \
      "refs/heads/f $(cd "$R" && git rev-parse HEAD) refs/heads/f 0000000000000000000000000000000000000000"
rm -rf "$R"

# ── Pair 9: the LOW allowlist must survive into the PUSH leg. Files like scripts/sync-to-be.sh name
# the companion store as part of doing their job; pre-commit exempts them at LOW severity and the
# push leg did not, because it had flattened the diff and kept no file context. That over-block was
# found by the FIRST REAL PUSH of this very change, after seven adversarial rounds missed it — an
# over-blocking gate trains PUBLIC_SURFACE_OK into reflex, so it is pinned in both directions. ──
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && mkdir -p scripts && printf '# backs up to zzsynthoperator\n' > scripts/sync-to-be.sh \
  && printf 'LOW\tzzsynthoperator\n' > .claude/rules/.public-surface-patterns \
  && git add -A && git commit -qm allowlisted >/dev/null )
check "LOW token in an allowlisted file    → PASS " "$R" pass \
      "refs/heads/f $(cd "$R" && git rev-parse HEAD) refs/heads/f $B"
rm -rf "$R"

# ── Pair 9-b: the same LOW token in a file that is NOT allowlisted must still block. ──
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && printf 'mentions zzsynthoperator\n' > notes.md \
  && printf 'LOW\tzzsynthoperator\n' > .claude/rules/.public-surface-patterns \
  && git add -A && git commit -qm notallowlisted >/dev/null )
check "LOW token in a NON-allowlisted file → BLOCK" "$R" block \
      "refs/heads/f $(cd "$R" && git rev-parse HEAD) refs/heads/f $B"
rm -rf "$R"

echo
if [ "$FAILED" -eq 0 ]; then
  echo "[prepush-guard] ✅ all known pairs hold"
  exit 0
fi
echo "[prepush-guard] ❌ BLOCKED — a known pair broke."
echo "  BLOCK→PASS = the publish boundary stopped covering something it claims to cover."
echo "  PASS→BLOCK = over-blocking, which trains PUBLIC_SURFACE_OK into reflex and disarms the gate."
echo "  RUNTIME FAULT = the hook aborted; that is never a pass, however it exited."
exit 1
