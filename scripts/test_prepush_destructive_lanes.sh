#!/usr/bin/env bash
# test_prepush_destructive_lanes.sh — known pairs for the pre-push hook's DESTRUCTIVE-OP verdict.
#
# ── WHY THIS FILE EXISTS (the hole it closes) ────────────────────────────────────────────────
# CLAUDE.md §Destructive-Op Gate names `templates/.git-hooks/pre-push` as the MECHANICAL FLOOR for
# the git-side irreversible surfaces (remote branch delete · force / non-ff push · tag delete), and
# is explicit that `templates/predelete_check.sh` is the operator's HUMAN enumerate tool which no
# hook executes. So the floor is the hook's own inline per-ref verdict block (pre-push:595-677 —
# banner at :595, `BLOCK=0` at :598, file ends :677; re-measured 2026-08-22, the old "600-676"
# was approximate).
#
# Measured 2026-08-22, bookshelf pass before writing a line of this file:
#   • scripts/test_destructive_pre_gate_lanes.sh anchors scripts/destructive_pre_gate.sh — the
#     PreToolUse *advisory text-pattern* guard over a proposed command. A DIFFERENT subject.
#   • scripts/prepush_guard_check.sh anchors the same hook but only its PUBLISH boundary: all 20 of
#     its pairs are confidentiality / main-PR-only / tag-version. Grepped for delete|force verdict
#     pairs: ZERO — measured with a known-positive control (the same grep hits 14 times in THIS
#     file, so the zero is a measurement and not a dead grep).
#     ⚠️ "13" stood here until 2026-08-22 and was wrong; the count is 20. The `ZERO` half was
#     re-measured with the control above and survived. A count nobody re-runs decays silently.
#   • templates/predelete_check.test.sh anchors the enumerate tool, and WAS executed by nothing.
#     ⚠️ Corrected 2026-08-22 R2: that present-tense claim went stale the same day it was written —
#     .github/workflows/destructive-op-anchor.yml step 'Anchor 3/3' now runs it, and stage ⑥ of
#     scripts/test_prepush_destructive_liveness.sh guards that runner. A file describing its own
#     machine in a tense that no longer holds is [[feedback_rule_misdescribes_its_own_machine]];
#     it is left visible as a correction rather than quietly overwritten.
#   ⇒ The inline block that actually blocks a force-push or a branch delete had NO known-pair
#     anchor anywhere, and therefore never re-ran in CI. An anchor that never re-runs cannot tell
#     you the gate broke; it tells you it was correct once, on the author's machine.
#
# ── DISCIPLINE THIS SUITE INHERITS FROM ITS SIBLING (scripts/prepush_guard_check.sh) ──────────
#  (a) Run the hook FOR REAL. `bash -n` is not an instrument: a `${...}` bad substitution is a
#      RUNTIME fault that parses clean, aborts the hook, and still exits 0 — every push allowed.
#  (b) A runtime fault is checked BEFORE the verdict, else an aborted hook scores as a clean pass.
#  (c) "It blocked" is NOT "it blocked correctly". A missing dependency also exits non-zero and
#      would score every BLOCK pair green while the gate was broken. So a block must NAME a
#      destructive cause; a block for a harness reason is reported as its own distinct failure.
#  (d) A pass must show its marker line — proof the hook ran far enough to make a claim. A hook
#      killed by a signal prints no fault text and rc alone would read as a pass.
#
# ── 🟥 WHAT THIS SUITE CLAIMS, AND WHAT IT DOES NOT (narrowed 2026-08-22 R3) ──────────────────
# It claims: on THESE 12 constructed inputs, the hook reached a verdict, the verdict matched the
# expected direction, and the hook ATTRIBUTED it to the named cause. That is a known-pair anchor.
# It does NOT claim to be an analyzer of the hook's execution semantics. Two places where this
# suite, like its liveness control, matches FORM rather than meaning — named rather than implied:
#   • (a)/(b)'s runtime-fault detector is a fixed vocabulary of bash's own error strings
#     (bad substitution · unbound variable · syntax error · command not found). A runtime fault
#     that words itself differently, or one whose message goes to a closed fd, is not recognised
#     and the lane falls through to the verdict check. Deliberately a vocabulary and not a
#     `set -e` harness: the failure it guards against (a parse-clean `${...}` fault aborting the
#     hook while it exits 0) does emit one of these, and every widening of the list adds false
#     "RUNTIME FAULT" reds on hooks that merely print the word.
#   • (c)/(d)'s attribution is `grep` over the hook's own output. It establishes that the hook
#     SAID the cause, not that the code path that said it is the one that decided.
# Neither is a defect to be repaired by a bigger regex — a regex chasing shell semantics loses at
# the edges in both directions at once, which is the class that produced the R3 findings. The
# thing that settles these is the hook running for real against a real destructive ref, which is
# what each lane below actually does.
#
# Runs entirely in mktemp throwaway repos: never touches this repo's index, worktree, or refs.
# Portability: git + coreutils only. No `stat -f` (BSD-first breaks the Linux runner), no
# `|| echo 0` pipefail fallbacks (that disarms the very guard being measured).
#
# Usage: bash scripts/test_prepush_destructive_lanes.sh   → exit 0 all pairs hold, 1 otherwise.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # 픽스처는 실레포에 쓰지 않는다

# FH_TEST_SUBJECT_ROOT points the suite at a COPY of the tree. It exists for the revert probe
# ("disable the gate on a copy — does exactly this suite go red?"), which is the only way to tell a
# live anchor from a decorative one without mutating a shared checkout. It selects WHICH subject is
# measured; it changes no verdict logic and cannot turn a red lane green.
REPO_ROOT="${FH_TEST_SUBJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HOOK_SRC="$REPO_ROOT/templates/.git-hooks/pre-push"
DEF_SRC="$REPO_ROOT/.claude/rules/.public-surface-patterns.defaults"
ZERO="0000000000000000000000000000000000000000"

# Fail-closed on a missing subject. A suite that cannot find what it measures reports HARNESS_ERROR
# and exits non-zero — it never renders "could not measure" as a zero-findings pass.
if [ ! -f "$HOOK_SRC" ]; then
  echo "HARNESS_ERROR — pre-push hook not found at $HOOK_SRC (subject absent; NOT a pass)"; exit 1
fi

# Test the STAGED blob when the hook is staged, same reasoning as the sibling anchor: an anchor that
# reads the worktree is bypassed by staging a regression and restoring the worktree.
WORK="$(fh_fixture_root "$(mktemp -d)")" || exit 1
trap 'rm -rf "$WORK"' EXIT
_status=$(git -C "$REPO_ROOT" -c core.quotePath=false diff --cached --name-status --no-renames 2>/dev/null \
          | awk -F'\t' '$2 == "templates/.git-hooks/pre-push" { print $1; exit }')
case "$_status" in
  D)  echo "❌ FAIL — pre-push is being DELETED from the index — fail-closed."; exit 1 ;;
  '') cp "$HOOK_SRC" "$WORK/hook" ;;
  *)  git -C "$REPO_ROOT" show ":templates/.git-hooks/pre-push" > "$WORK/hook" 2>/dev/null \
        || { echo "❌ FAIL — staged pre-push blob unreadable — fail-closed."; exit 1; } ;;
esac
HOOK="$WORK/hook"

PASSED=0; FAILED=0

# ── fixture ──────────────────────────────────────────────────────────────────────────────────
# A repo with: main, a real `refs/remotes/origin/main` (the hook's default BASE is `origin/main`
# and an unresolvable base is itself one of the lanes — it must be resolvable everywhere else, or
# every delete lane would block for the WRONG reason and the suite would be green for nothing).
newrepo() {
  local d; d="$(fh_fixture_root "$(mktemp -d)")" || return 1
  mkdir -p "$d/.claude/rules" "$d/templates/.git-hooks" "$d/tracks/_meta" "$d/scripts" || return 1
  [ -f "$DEF_SRC" ] && cp "$DEF_SRC" "$d/.claude/rules/.public-surface-patterns.defaults"
  [ -f "$REPO_ROOT/scripts/psa_scan_lib.sh" ] && cp "$REPO_ROOT/scripts/psa_scan_lib.sh" "$d/scripts/psa_scan_lib.sh"
  printf '.claude/rules/.public-surface-patterns\n' > "$d/.gitignore"
  cp "$HOOK" "$d/templates/.git-hooks/pre-push" || return 1
  printf 'base\n' > "$d/a.txt"
  (
    cd "$d" || exit 1
    # `git init -b main` needs git >= 2.28 and is rejected outright by anything older ("unknown
    # switch `b'", rc 129). scripts/test_stale_clone_guard_lanes.sh:34 already builds its fixture
    # via symbolic-ref for exactly this reason; this suite did not, so on an older git
    # it died in SETUP — see the require_repo note below for why that was worse than a red lane.
    # symbolic-ref also pins the branch name against init.defaultBranch differing per machine
    # (main on this operator's, master on a stock image) — the fixture's `main` is load-bearing:
    # the P4 PROTECTED lane and the origin/main base ref both name it.
    git init -q                                  || exit 1
    git symbolic-ref HEAD refs/heads/main        || exit 1
    git config user.email t@example.com          || exit 1
    git config user.name t                       || exit 1
    git add -A >/dev/null 2>&1                   || exit 1
    git commit -qm base >/dev/null 2>&1          || exit 1
    # Materialise the base ref the hook resolves against.
    git update-ref refs/remotes/origin/main HEAD || exit 1
  ) || return 1
  printf '%s' "$d"
}

# 🟥 SETUP FAILURE MUST BE LOUD — and until 2026-08-22 it was the opposite of loud.
# `newrepo` signals failure by returning 1 without echoing, so `R=$(newrepo)` leaves R EMPTY.
# `cd ""` is a NO-OP SUCCESS in bash (measured: `cd /tmp; cd "" ; pwd` → /tmp; control:
# `cd /no/such/dir` → rc 1). So every `( cd "$repo" && ... )` in this file silently ran in the
# CURRENT directory — this repo — and the lanes graded the operator's REAL tree.
# Measured on a git<2.28 shim, pre-fix: 6 passed / 6 failed, with P7 and P8 scoring **PASS** off
# the real repo's own hook output. That is the [[feedback_not_found_is_not_zero_family]] shape at
# its quietest: not a missing measurement rendered as zero, but a FAILED fixture rendered as a
# green lane, on the irreversible surface this suite exists to guard. The TOTAL==0 dead-instrument
# control at the bottom cannot see it either — the lanes did run; they ran against the wrong thing.
require_repo() {   # $1 = candidate repo path, $2 = lane name
  if [ -z "${1:-}" ] || [ ! -d "$1/.git" ]; then
    echo "HARNESS_ERROR — fixture repo not built for $2 (setup failed; NOT a pass)"
    echo "   path='${1:-}' — an empty path makes \`cd\` a no-op, so this lane would have graded"
    echo "   the REAL working tree instead of a throwaway fixture. Aborting rather than scoring."
    exit 1
  fi
}

# check <name> <repo> <expect: block|pass> <cause-regex> <refline...>
#   cause-regex — what the verdict must be ATTRIBUTED to. For a block, the hook must name this
#   destructive cause; for a pass, this marker must appear. Both directions require the hook to
#   have reached the point of making a claim, so neither can be satisfied by an abort.
check() {
  local name="$1" repo="$2" expect="$3" cause="$4"; shift 4
  local out rc got
  require_repo "$repo" "$name"   # fail-closed: never grade a lane whose fixture did not build
  out=$(printf '%s\n' "$@" | ( cd "$repo" && bash templates/.git-hooks/pre-push origin git@example:x/y.git 2>&1 )); rc=$?

  # (b) runtime fault first — an aborted hook is not a hook that passed.
  if printf '%s' "$out" | grep -qiE 'bad substitution|unbound variable|syntax error|command not found'; then
    echo "  ❌ $name — RUNTIME FAULT in the hook (aborted, not passed)"
    printf '%s\n' "$out" | grep -iE 'bad substitution|unbound|syntax error|command not found' | sed 's/^/       /' | head -3
    FAILED=$((FAILED+1)); return
  fi

  if [ "$rc" -ne 0 ]; then
    # (c) blocked — but was it blocked for a DESTRUCTIVE reason? A harness error also exits 1.
    if printf '%s' "$out" | grep -qE 'FH Destructive-Op Gate'; then
      got=block
    else
      echo "  ❌ $name — blocked, but NOT by the Destructive-Op gate (harness reason ≠ finding)"
      printf '%s\n' "$out" | sed 's/^/       | /' | head -8
      FAILED=$((FAILED+1)); return
    fi
  else
    got=pass
  fi

  if [ "$got" != "$expect" ]; then
    echo "  ❌ $name — expected $expect, got $got"
    printf '%s\n' "$out" | sed 's/^/       | /' | head -10
    FAILED=$((FAILED+1)); return
  fi

  # (d) the verdict must be attributed — for BOTH directions.
  if ! printf '%s' "$out" | grep -qE "$cause"; then
    echo "  ❌ $name — verdict $got is correct but UNATTRIBUTED (missing: $cause)"
    printf '%s\n' "$out" | sed 's/^/       | /' | head -10
    FAILED=$((FAILED+1)); return
  fi

  echo "  ✅ $name (expected $expect)"
  PASSED=$((PASSED+1))
}

echo "[prepush-destructive] known-pair anchor for the pre-push destructive-op verdict"
echo ""
echo "── KNOWN-NEGATIVE (must PASS — over-blocking trains the override that disarms the gate) ──"

# N1 — ordinary fast-forward push of a feature branch. Nothing destructive.
#      Marker: the hook must reach the publish check, proving it ran past classification.
R=$(newrepo)
require_repo "$R" "N1"
B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && printf 'x\n' >> a.txt && git commit -qam ff >/dev/null )
check "N1 ordinary fast-forward push        → PASS " "$R" pass 'FH Pre-Publish' \
      "refs/heads/feat $(cd "$R" && git rev-parse HEAD) refs/heads/feat $B"
rm -rf "$R"

# N2 — deleting a FULLY MERGED branch. The enumerate is load-bearing: nothing unique is lost,
#      so the gate must allow it. This is the lane that proves the gate is not a blanket deny.
R=$(newrepo)
require_repo "$R" "N2"
( cd "$R" && git branch merged-branch ) >/dev/null 2>&1
TIP=$(cd "$R" && git rev-parse merged-branch)
check "N2 delete FULLY-MERGED branch        → PASS " "$R" pass 'SAFE: fully merged' \
      "(delete) $ZERO refs/heads/merged-branch $TIP"
rm -rf "$R"

echo ""
echo "── KNOWN-POSITIVE (must BLOCK — and be attributed to the right destructive cause) ──"

# P1 — force / non-fast-forward push (history rewrite). Always blocks: a rewrite loses commits.
R=$(newrepo)
require_repo "$R" "P1"
B=$(cd "$R" && git rev-parse HEAD)
( cd "$R" && printf 'x\n' >> a.txt && git commit -qam one >/dev/null \
   && git checkout -q --detach "$B" && printf 'y\n' >> a.txt && git commit -qam divergent >/dev/null )
check "P1 FORCE / non-ff push               → BLOCK" "$R" block 'FORCE / non-fast-forward' \
      "refs/heads/feat $(cd "$R" && git rev-parse HEAD) refs/heads/feat $(cd "$R" && git rev-parse main)"
rm -rf "$R"

# P2 — delete a branch carrying UNIQUE PATHS → REVIEW. Recovery is mandatory before deleting.
R=$(newrepo)
require_repo "$R" "P2"
( cd "$R" && git checkout -q -b unique-work && printf 'only here\n' > unique.txt \
   && git add unique.txt && git commit -qm unique >/dev/null && git checkout -q main )
TIP=$(cd "$R" && git rev-parse unique-work)
check "P2 delete branch w/ UNIQUE PATHS     → BLOCK" "$R" block 'REVIEW: .* unique path' \
      "(delete) $ZERO refs/heads/unique-work $TIP"
rm -rf "$R"

# P3 — delete a branch with commits off base but ZERO unique paths → CHECK. This is the SILENT
#      loss class: a shared file (an unmerged session card) may hold NEWER content. A gate that
#      only looked at unique paths would auto-SAFE this one.
R=$(newrepo)
require_repo "$R" "P3"
( cd "$R" && git checkout -q -b newer-content && printf 'newer\n' >> a.txt \
   && git commit -qam newer >/dev/null && git checkout -q main )
TIP=$(cd "$R" && git rev-parse newer-content)
check "P3 delete branch, 0 uniq but NEWER   → BLOCK" "$R" block 'CHECK: .* commit' \
      "(delete) $ZERO refs/heads/newer-content $TIP"
rm -rf "$R"

# P4 — delete the INTEGRATION branch. Trivially "merged into itself" (n=0, uniq=0), so without an
#      explicit guard it would auto-pass the SAFE branch. The most dangerous auto-pass in the block.
R=$(newrepo)
require_repo "$R" "P4"
TIP=$(cd "$R" && git rev-parse main)
check "P4 delete INTEGRATION branch (main)  → BLOCK" "$R" block 'PROTECTED' \
      "(delete) $ZERO refs/heads/main $TIP"
rm -rf "$R"

# P5 — delete a TAG. predelete_check walks branches only, so tags have no unique-path verdict; a
#      release tag is an external anchor and deleting it is irreversible for consumers.
R=$(newrepo)
require_repo "$R" "P5"
( cd "$R" && git tag v9.9.9 ) >/dev/null 2>&1
TIP=$(cd "$R" && git rev-parse v9.9.9)
check "P5 delete TAG (non-branch ref)       → BLOCK" "$R" block 'DELETE \(non-branch ref\)' \
      "(delete) $ZERO refs/tags/v9.9.9 $TIP"
rm -rf "$R"

# P6 — remote tip not fetched. An unfetched tip makes a force indistinguishable from a
#      fast-forward, so "cannot decide" must never render as "allowed".
#
#      🟥 MEASURED WHILE WRITING THIS SUITE — the destructive block's `CANNOT CLASSIFY` branch is
#      SHADOWED on the default path. The same condition (remote_sha absent locally) also makes the
#      push RANGE unreadable, and the confidentiality guard fail-closes at pre-push:357 — before
#      classification at :598 ever runs. The first draft of this lane asserted the destructive
#      cause, went red, and the honest diagnosis was that the lane's expectation was wrong, not
#      the hook. Two lanes now, because they assert different things:
#        P6a — the SAFETY property on the path a real push takes: it fail-closes. Whichever guard
#              wins, the push does not proceed. This is what protects the operator.
#        P6b — the destructive branch itself, reached by unshadowing the earlier guard with
#              PUBLIC_SURFACE_OK=1. Without this lane that code path is UNMEASURED, and an
#              unmeasured branch is where a silent regression lives.
#      Named residual, not closed here: on the default path :609's CANNOT CLASSIFY line is
#      unreachable. Both guards fail closed so this is not a safety hole — it is a decorative
#      line, and it is recorded rather than deleted because deleting it is a hook change and this
#      file is an anchor, not a repair.
R=$(newrepo)
require_repo "$R" "P6"
( cd "$R" && printf 'x\n' >> a.txt && git commit -qam ff >/dev/null )
FAKE=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
# Asserted directly, NOT through check(): check() requires a block to be attributed to the
# destructive gate, and here a DIFFERENT guard legitimately wins. Reusing check() would either
# fail a correct behaviour or force the attribution test to be loosened for every other lane —
# and that test is what stops a harness error from scoring as a finding.
out=$(printf 'refs/heads/feat %s refs/heads/feat %s\n' "$(cd "$R" && git rev-parse HEAD)" "$FAKE" \
      | ( cd "$R" && bash templates/.git-hooks/pre-push origin git@example:x/y.git 2>&1 )); rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF 'unread history is not a clean one'; then
  echo "  ✅ P6a remote tip NOT FETCHED → BLOCK, fail-closed (push-range guard wins; see note)"
  PASSED=$((PASSED+1))
else
  echo "  ❌ P6a remote tip NOT FETCHED — expected a fail-closed block, rc=$rc"
  printf '%s\n' "$out" | sed 's/^/       | /' | head -8; FAILED=$((FAILED+1))
fi

out=$(printf 'refs/heads/feat %s refs/heads/feat %s\n' "$(cd "$R" && git rev-parse HEAD)" "$FAKE" \
      | ( cd "$R" && PUBLIC_SURFACE_OK=1 bash templates/.git-hooks/pre-push origin git@example:x/y.git 2>&1 )); rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF 'CANNOT CLASSIFY (remote tip not fetched)'; then
  echo "  ✅ P6b CANNOT CLASSIFY branch (unshadowed) → BLOCK (expected block)"; PASSED=$((PASSED+1))
else
  echo "  ❌ P6b CANNOT CLASSIFY branch (unshadowed) — expected an attributed block, rc=$rc"
  printf '%s\n' "$out" | sed 's/^/       | /' | head -8; FAILED=$((FAILED+1))
fi
rm -rf "$R"

# P7 — base ref unresolvable → ALL branch deletes blocked. Same fail-closed direction as P6, on a
#      different input: the gate cannot verify SAFE, so it must not grant SAFE.
R=$(newrepo)
require_repo "$R" "P7"
( cd "$R" && git branch merged-branch && git update-ref -d refs/remotes/origin/main ) >/dev/null 2>&1
TIP=$(cd "$R" && git rev-parse merged-branch)
check "P7 base ref UNRESOLVABLE             → BLOCK" "$R" block "unresolvable" \
      "(delete) $ZERO refs/heads/merged-branch $TIP"
rm -rf "$R"

echo ""
echo "── OVERRIDE CHANNEL (explicit + logged — the only sanctioned way past a real block) ──"

# P8 — DESTRUCTIVE_OP_OK=1 converts P2's REVIEW block into an allow, AND must leave a record.
#      Two assertions, because an override that proceeds without logging is an UNRECORDED
#      irreversible act — the override channel's whole value is the audit trail it leaves.
R=$(newrepo)
require_repo "$R" "P8"
( cd "$R" && git checkout -q -b unique-work && printf 'only here\n' > unique.txt \
   && git add unique.txt && git commit -qm unique >/dev/null && git checkout -q main )
TIP=$(cd "$R" && git rev-parse unique-work)
out=$(printf '%s\n' "(delete) $ZERO refs/heads/unique-work $TIP" \
      | ( cd "$R" && DESTRUCTIVE_OP_OK=1 bash templates/.git-hooks/pre-push origin git@example:x/y.git 2>&1 )); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qF 'allowed by DESTRUCTIVE_OP_OK=1'; then
  echo "  ✅ P8 DESTRUCTIVE_OP_OK=1 overrides REVIEW  → PASS (expected pass)"; PASSED=$((PASSED+1))
else
  echo "  ❌ P8 DESTRUCTIVE_OP_OK=1 overrides REVIEW — expected allow, rc=$rc"
  printf '%s\n' "$out" | sed 's/^/       | /' | head -8; FAILED=$((FAILED+1))
fi
if [ -s "$R/tracks/_meta/.destructive_op_override_log" ]; then
  echo "  ✅ P8b override was LOGGED (unrecorded override would defeat the channel)"; PASSED=$((PASSED+1))
else
  echo "  ❌ P8b override proceeded but wrote NO log entry"; FAILED=$((FAILED+1))
fi
rm -rf "$R"

echo ""
# Dead-instrument control. If the suite somehow ran zero pairs, that is HARNESS_ERROR — never a
# pass. `all/any/count==0` all read clean on an empty set; this is the explicit empty-input answer.
TOTAL=$((PASSED+FAILED))
if [ "$TOTAL" -eq 0 ]; then
  echo "HARNESS_ERROR — prepush-destructive 캘리브레이션: 0 pairs executed (dead instrument, NOT a pass)"
  exit 1
fi
echo "prepush-destructive 캘리브레이션: $PASSED passed, $FAILED failed ($TOTAL pairs)"
[ "$FAILED" -eq 0 ]
