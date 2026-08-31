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
WORK=$(mktemp -d) || exit 1; : "${WORK:?fixture root unset — refusing to run git in cwd}"
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
  local d; d=$(mktemp -d); : "${d:?fixture root unset — refusing to run git in cwd}"
  mkdir -p "$d/.claude/rules" "$d/templates/.git-hooks" "$d/tracks/_meta"
  cp "$DEF_SRC" "$d/.claude/rules/.public-surface-patterns.defaults"
  # The operator override is GITIGNORED in the real repo, so it never enters history. Committing it
  # here made its own literals show up as leaks in the pushed content — a fixture artifact that read
  # exactly like a product defect. Mirror reality instead.
  printf '.claude/rules/.public-surface-patterns\n' > "$d/.gitignore"
  printf 'HIGH\tzzsynthoperator\n' > "$d/.claude/rules/.public-surface-patterns"
  cp "$HOOK" "$d/templates/.git-hooks/pre-push"
  mkdir -p "$d/scripts"
  cp "$REPO_ROOT/scripts/psa_scan_lib.sh" "$d/scripts/psa_scan_lib.sh"
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
  # "It blocked" is not the same as "it blocked correctly". A missing dependency, an unreadable
  # file, or any harness error also exits non-zero — and every BLOCK pair would score green while
  # the gate was actually broken. (Observed: after the scan logic moved into a shared library, the
  # sandbox repos lacked it, so 6 of 8 BLOCK pairs still "passed" — for the wrong reason.) A block
  # therefore has to name a confidentiality cause.
  if [ "$rc" -ne 0 ]; then
    if printf '%s' "$out" | grep -qE '(leak —|leak in pushed|incomplete confidentiality instrument|unusable pattern)'; then
      got=block
    else
      echo "  ❌ $name — blocked, but for a HARNESS reason, not a confidentiality finding"
      printf '%s\n' "$out" | sed 's/^/       | /' | head -6
      FAILED=1; return
    fi
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

# ── Pair 6: instrument completeness, and the line between "not configured" and "broken".
# CHANGED DELIBERATELY 2026-07-26 — this pair used to expect BLOCK on an absent operator override.
# Two things overturned that: selfcheck flagged it as over-blocking (T7: "guard over-fires; that
# trains the override"), and the reasoning did not hold — the override contains THIS operator's
# literals, so another environment lacking it was never protected by it anyway. What protects a fresh
# clone is the generic credential shapes in the COMMITTED layer. So an absent override now warns, and
# what still blocks is a genuinely BROKEN pattern source, which affects everyone. Both pinned. ──
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && echo ok > g.md && git add g.md && git commit -qm g >/dev/null && rm -f .claude/rules/.public-surface-patterns )
check "operator override absent (per-operator) → PASS " "$R" pass \
      "refs/heads/f $(cd "$R" && git rev-parse HEAD) refs/heads/f $B"
rm -rf "$R"

# ── Pair 6-b (2026-08-06): the OTHER arm of the same state, which the 07-26 flag could not see.
# Identical to 6-a except the checkout carries CLAUDE.local.md — the operator's gitignored binding
# file, absent in every clone/CI/worktree by construction. There the missing override is not an
# unset per-operator config, it is evidence missing where evidence is expected, on a surface that
# publishes. This is what `npm publish` already blocked while `git push` waved through; the two
# irreversible surfaces now degrade in the same direction.
# The PAIR is what makes it a measurement: 6-a (no CLAUDE.local.md → PASS) is the known-negative and
# must keep passing, or this is not a scoped block, it is the 07-26 over-block re-shipped. ──
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && echo ok > g2.md && git add g2.md && git commit -qm g2 >/dev/null \
  && rm -f .claude/rules/.public-surface-patterns && printf '# operator binding\n' > CLAUDE.local.md )
check "override absent + operator checkout    → BLOCK" "$R" block \
      "refs/heads/f $(cd "$R" && git rev-parse HEAD) refs/heads/f $B"
rm -rf "$R"

R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && echo ok > g.md && git add g.md && git commit -qm g >/dev/null \
  && : > .claude/rules/.public-surface-patterns.defaults )   # present but EMPTY = broken, not unconfigured
check "committed defaults EMPTY (broken)      → BLOCK" "$R" block \
      "refs/heads/f $(cd "$R" && git rev-parse HEAD) refs/heads/f $B"
rm -rf "$R"

# Applicability is mechanical: no committed pattern source at all = not an FH checkout = legs N/A.
# Without this the hook blocked every push in any bare repo it was copied into, which is how the
# over-block was found in the first place.
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && echo ok > g.md && git add g.md && git commit -qm g >/dev/null \
  && rm -f .claude/rules/.public-surface-patterns.defaults .claude/rules/.public-surface-patterns )
check "no committed pattern source (not FH)   → PASS " "$R" pass \
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

# ── Pair 10: stacked-branch ADVISORY. Unlike every pair above, the assertion is on the WARNING,
# not on the verdict — this leg exists precisely because the advisory must never change the exit
# code. Origin (2026-07-27, field harness PRs #38/#39): a branch cut off a feature branch produced a
# child PR carrying the parent's three commits. Both ways out bill at parent-merge time — keeping the
# integration base leaves the child CONFLICTING after the parent is squashed, and retargeting onto the
# parent branch makes --delete-branch CLOSE the child. The observed run hit both (state=CLOSED,
# mergeable=CONFLICTING), and the tempting recovery is a force-push — the irreversible surface this
# hook guards.
#
# Assertions key on the STABLE MARKER `[fh-advisory:stacked-branch]`, not on the human prose around
# it (Wave-1 B): a prose-coupled assertion silently desyncs the moment the message is reworded. ──
SB_MARK='[fh-advisory:stacked-branch]'
sb_check() {  # sb_check <name> <repo> <expect: warn|skip|none> <refline> [must-name]
  # [must-name]: a branch the warning MUST name. "a warning appeared" is too weak an assertion —
  # under a mutation that broke the self-exclusion, the advisory still warned, but about the
  # pushed branch ITSELF. The leg went green while the defect was live (measured 2026-07-27).
  local name="$1" repo="$2" expect="$3" refline="$4" mustname="${5:-}" out rc got
  out=$(printf '%s\n' "$refline" | ( cd "$repo" && bash templates/.git-hooks/pre-push origin git@example:x/y.git 2>&1 )); rc=$?
  if printf '%s' "$out" | grep -qiE 'bad substitution|unbound variable|syntax error|command not found'; then
    echo "  ❌ $name — RUNTIME FAULT in the hook"; FAILED=1; return
  fi
  if printf '%s' "$out" | grep -qF "$SB_MARK"; then
    # Key on a machine token, not prose. Measured 2026-07-27: this classifier first grepped the
    # phrase "skipped —", and a one-word rewording of the hook's message silently reclassified a
    # correct SKIP as a WARN — the same prose-coupling defect Wave-1 flagged in the leg assertions.
    if printf '%s' "$out" | grep -qF "$SB_MARK SKIPPED"; then got=skip; else got=warn; fi
  else
    got=none
  fi
  if [ "$got" != "$expect" ]; then
    echo "  ❌ $name — expected $expect, got $got"
    printf '%s\n' "$out" | sed 's/^/       | /' | head -8
    FAILED=1; return
  fi
  # The advisory must not move the verdict. These legs are otherwise-clean pushes, so a non-zero
  # exit means the advisory (or something it perturbed) started blocking.
  if [ "$rc" -ne 0 ]; then
    echo "  ❌ $name — advisory changed the verdict (exit $rc); it must be advisory only"
    printf '%s\n' "$out" | sed 's/^/       | /' | head -6
    FAILED=1; return
  fi
  if [ -n "$mustname" ] && ! printf '%s' "$out" | grep -qF "$mustname"; then
    echo "  ❌ $name — warned, but never named '$mustname' (warning for the wrong reason)"
    printf '%s\n' "$out" | grep -F "$SB_MARK" -A5 | sed 's/^/       | /' | head -8
    FAILED=1; return
  fi
  echo "  ✅ $name ($expect, verdict unchanged${mustname:+, named $mustname})"
}
# ⚠️ 계기 주의 (실측): 처음엔 remote_sha 를 all-zero(=신규 브랜치)로 줬는데, 그러면 push 범위에
# 샌드박스의 base 커밋(= templates/.git-hooks/pre-push 사본을 담고 있다)이 들어가 이 훅의 **기존**
# load-bearing cross-family 가드가 발화해 차단됐다. sb_check 은 그 rc!=0 을 "advisory 가 verdict 를
# 바꿨다"로 오귀속했다 — 다른 가드의 차단을 이 기능 탓으로 읽는 계기 결함이다.
# base 커밋을 remote_sha 로 주면 범위가 픽스처 커밋만으로 좁혀져 그 혼선이 사라진다.

# 10-a known-positive: cut off a REMOTE feature branch.
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)" \
  && git switch -q -c feat/parent && printf 'p\n' > p.md && git add p.md && git commit -qm parent >/dev/null \
  && git update-ref refs/remotes/origin/feat/parent "$(git rev-parse HEAD)" \
  && git switch -q -c feat/child && printf 'c\n' > c.md && git add c.md && git commit -qm child >/dev/null )
sb_check "cut off a REMOTE feature branch     → warn" "$R" warn \
      "refs/heads/feat/child $(cd "$R" && git rev-parse feat/child) refs/heads/feat/child $B"
rm -rf "$R"

# 10-b known-positive (Wave-1 A): the parent was never pushed. A remote-only check misses exactly
# the most likely moment for this mistake — before the parent's first push.
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)" \
  && git switch -q -c feat/localparent && printf 'p\n' > p.md && git add p.md && git commit -qm parent >/dev/null \
  && git switch -q -c feat/child2 && printf 'c\n' > c.md && git add c.md && git commit -qm child >/dev/null )
sb_check "cut off a LOCAL-only feature branch → warn" "$R" warn \
      "refs/heads/feat/child2 $(cd "$R" && git rev-parse feat/child2) refs/heads/feat/child2 $B"
rm -rf "$R"

# 10-c known-positive (Wave-1 S, live-reproduced): a branch name carrying a regex metacharacter.
# The first draft interpolated the name into `grep -vE ".../${self}$"`, so `feat/a.b`'s `.` also
# matched a genuinely different branch `feat/aXb` — grep -v dropped the REAL hit and the advisory
# silently no-opped on a true positive. Exclusion is exact-name now; this leg pins that.
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)" \
  && git switch -q -c feat/aXb && printf 'p\n' > p.md && git add p.md && git commit -qm parent >/dev/null \
  && git update-ref refs/remotes/origin/feat/aXb "$(git rev-parse HEAD)" \
  && git switch -q -c 'feat/a.b' \
  && git branch -q -D feat/aXb )
# ⚠️ the local `feat/aXb` is DELETED on purpose. Left in place, the local listing line
# (`local  feat/aXb`, no `/` before `feat`) dodges the vulnerable pattern `/feat/a.b$` and the leg
# goes green even with the bug restored — i.e. it would pass for the wrong reason. Measured: the
# first version of this fixture did exactly that under a mutation test.
sb_check "regex-metachar branch name          → warn" "$R" warn \
      "refs/heads/feat/a.b $(cd "$R" && git rev-parse 'feat/a.b') refs/heads/feat/a.b $B" \
      "origin/feat/aXb"
rm -rf "$R"

# 10-d (Wave-1 A): base unresolvable → must SAY it did not scan. A silent return is
# indistinguishable from "scanned, nothing found" — 부재는 통과가 아니다.
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && git switch -q -c feat/nobase && printf 'n\n' > n.md && git add n.md && git commit -qm x >/dev/null )
sb_check "base unresolvable                   → skip announced" "$R" skip \
      "refs/heads/feat/nobase $(cd "$R" && git rev-parse feat/nobase) refs/heads/feat/nobase $B"
rm -rf "$R"

# 10-e (cross-family LOW-7): parser edge cases. The first draft parsed human `git branch -r`
# output, where `origin/HEAD -> origin/main` parses as ref="HEAD" and a branch name with a space is
# truncated. for-each-ref emits refs, not a listing — this leg pins that the symbolic HEAD ref does
# not manufacture a warning and does not mask a real one.
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)" \
  && git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main \
  && git switch -q -c feat/parent2 && printf 'p\n' > p.md && git add p.md && git commit -qm parent >/dev/null \
  && git update-ref refs/remotes/origin/feat/parent2 "$(git rev-parse HEAD)" \
  && git switch -q -c feat/child3 && printf 'c\n' > c.md && git add c.md && git commit -qm child >/dev/null )
sb_check "origin/HEAD symref present         → warn" "$R" warn \
      "refs/heads/feat/child3 $(cd "$R" && git rev-parse feat/child3) refs/heads/feat/child3 $B" \
      "origin/feat/parent2"
rm -rf "$R"

# 10-f (cross-family MED-2): the integration branch is excluded by its RESOLVED name, not by a
# hard-coded main/master. A stack built on a LOCAL branch merely named `master` in a repo whose base
# is origin/main must still warn — hard-coding hid exactly that case.
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)" \
  && git switch -q -c master && printf 'p\n' > p.md && git add p.md && git commit -qm onmaster >/dev/null \
  && git switch -q -c feat/child4 && printf 'c\n' > c.md && git add c.md && git commit -qm child >/dev/null )
sb_check "stack on a local 'master' branch   → warn" "$R" warn \
      "refs/heads/feat/child4 $(cd "$R" && git rev-parse feat/child4) refs/heads/feat/child4 $B" \
      "master"
rm -rf "$R"

# 10-g CONTROL: cut off the integration branch. Without this leg an advisory that fired
# unconditionally would score green on every positive leg above while being useless.
R=$(newrepo); B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)" \
  && git switch -q -c feat/clean && printf 'w\n' > w.md && git add w.md && git commit -qm clean >/dev/null )
sb_check "control: cut off main               → no warn" "$R" none \
      "refs/heads/feat/clean $(cd "$R" && git rev-parse feat/clean) refs/heads/feat/clean $B"
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
