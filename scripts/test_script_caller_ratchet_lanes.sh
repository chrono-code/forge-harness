#!/usr/bin/env bash
# test_script_caller_ratchet_lanes.sh — behavioural known-pair lanes for scripts/script_caller_ratchet.sh
#
# 🟥 EVERY LANE RUNS AGAINST A FIXTURE ROOT, NEVER AGAINST THIS REPO.
# The checker takes `--root DIR` for exactly this reason. A lane that scanned the real tree would
# pass or fail on whatever the tree happens to contain today, which is a lane that measures the
# repo instead of the instrument — a trap this repo has fallen into before. Lane L0 is the control
# that proves the swap actually took: it asserts the fixture's own population size, so if `--root`
# were ignored and the real repo were scanned, L0 goes red instead of everything silently passing.
#
# The pairs are deliberate: every blocking lane has a known-negative twin, because "it blocked" is
# not the same claim as "it blocked for the right reason", and an over-blocking gate trains the
# override into muscle memory.
#
# Usage: bash scripts/test_script_caller_ratchet_lanes.sh
# Exit:  0 = all lanes pass · 1 = a lane failed
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # 픽스처는 실레포에 쓰지 않는다

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The override exists for the REVERT PROBE: point the lanes at a deliberately neutered copy of the
# checker and confirm that exactly the lanes covering the removed behaviour go red. An anchor that
# stays green when its subject is disabled is decorative, and the only way to know which one you
# have is to disable it on purpose. Default is the real checker; CI never sets this.
CHECK="${FH_CALLER_RATCHET_BIN:-$ROOT/scripts/script_caller_ratchet.sh}"
[ -f "$CHECK" ] || { echo "FAIL  harness: $CHECK not found"; exit 1; }

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
no()  { fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }

# 🟥 ONE TEMP ROOT FOR THE WHOLE SUITE, and every fixture is a child of it.
# Two reasons, both measured in this repo rather than assumed:
#   · a sibling lane suite leaked fixture writes into the real tree, so "the fixtures are under
#     mktemp" has to be a property of a single named root that can be printed and removed as a unit,
#     not of N independent mktemp calls scattered through the file.
#   · the trap removes the root on ANY exit path, including a lane that dies mid-fixture. The old
#     per-lane `rm -rf "$d"` runs only when the lane reaches its own last line.
# The per-lane `rm -rf "$d"` calls below are KEPT: they bound peak disk during the run, and a
# belt-and-braces cleanup is not a duplicate normalizer — neither one changes any verdict.
FIXROOT="$(mktemp -d)"
trap 'rm -rf "$FIXROOT"' EXIT INT TERM
newfix() { mktemp -d "$FIXROOT/fix.XXXXXX"; }

# Each fixture is a throwaway root with its own scripts/ — no inheritance from this repo.
# 🟥 THE RUNNER LIVES IN .github/workflows/, NOT IN scripts/. First draft put it at
# scripts/runner.sh and eight lanes went red for a reason that had nothing to do with the lane: the
# runner is itself a non-lane script under scripts/, so it entered its own population with no caller
# and every fixture blocked on IT. The fixture, not the checker, was wrong — and it is worth keeping
# written down, because a green version of that fixture would have been the worse outcome.
# 🟥 2026-08-31: this helper returned an EMPTY string when its trap fired first (SIGTERM during a
# selfcheck sweep), and every `git -C "$d"` below then resolved to the CURRENT DIRECTORY — the live
# repo. A fixture lane committed 127 lines of a session's uncommitted work onto its real branch,
# with `--no-verify` and a bogus hooksPath, so no gate saw it. `git -C ""` is fail-OPEN by
# construction: an absent path is not an error, it is "here".
# The guard below is deliberately about the INVARIANT, not the symptom — a fixture must never write
# to a real repo — so it also catches a $d that is non-empty but wrongly points at one.

mkfix() {
  d="$(newfix)"
  d="$(fh_fixture_root "$d")"
  mkdir -p "$d/scripts" "$d/.github/workflows"
  printf '%s\n' '#!/usr/bin/env bash' 'echo alpha' > "$d/scripts/alpha.sh"
  printf 'exempt:\nbaseline:\n' > "$d/scripts/caller_zero_baseline.txt"
  printf 'run: bash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
  echo "$d"
}
# 🟥 2026-08-24: the checker now reads a runner's BODY from the git index, not from the working
# tree (D-5 second half -- an unstaged dispatch line is wiring that exists in nobody's clone). The
# git-backed fixtures below rewrite .github/workflows/ci.yml AFTER their commit, so their intended
# wiring was working-tree-only and stopped counting. Staging that one file restores each lane's
# INTENT -- "this runner dispatches X" -- without weakening anything: it is what an author does
# before committing, and the non-git fixtures (the majority) are untouched because there is no
# index there to stage into. Only ci.yml is staged; the baseline file is deliberately left dirty,
# which is what the shrink-only lanes measure.
_stage_runner() {
  git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  [ -f "$1/.github/workflows/ci.yml" ] || return 0
  git -C "$1" add .github/workflows/ci.yml >/dev/null 2>&1 || true
}
run()  { _stage_runner "$1"; bash "$CHECK" --root "$1" 2>&1; }
rcof() { _stage_runner "$1"; bash "$CHECK" --root "$1" >/dev/null 2>&1; echo $?; }
# Variants that forward extra flags/env (--base, FH_RATCHET_REQUIRE_BASE) to the checker.
runx()  { _d="$1"; shift; bash "$CHECK" --root "$_d" "$@" 2>&1; }
rcofx() { _d="$1"; shift; bash "$CHECK" --root "$_d" "$@" >/dev/null 2>&1; echo $?; }

# A fixture that is a REAL git repo with one commit, so the shrink-only half has a base to diff.
# 🟥 `git init` here touches ONLY a throwaway mktemp directory — never the repo under test. The
# add is by explicit path rather than `-A` to keep that habit intact even where it is harmless.
# hooksPath is pointed at a directory that does not exist and every commit is --no-verify, so a
# global core.hooksPath (this repo installs one) cannot make the FIXTURE run the real gates.
gitfix() {
  _d="$(mkfix)"
  git -C "$_d" -c init.defaultBranch=main init -q >/dev/null 2>&1
  git -C "$_d" add scripts .github >/dev/null 2>&1
  git -C "$_d" -c user.email=lane@example.invalid -c user.name=lane \
      -c core.hooksPath=/nonexistent-fixture-hooks \
      commit -q --no-verify -m base >/dev/null 2>&1
  echo "$_d"
}

# ── L0 CONTROL — the root swap took effect ────────────────────────────────────────────────────
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho beta\n' > "$d/scripts/beta.sh"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\nbash scripts/beta.sh\n' > "$d/.github/workflows/ci.yml"
o="$(run "$d")"
# TWO assertions, because either alone is weak: the population size pins the fixture, and the
# absence of a name that exists only in the real repo pins that the real tree was not reached.
if printf '%s' "$o" | grep -q '2 non-lane scripts' && ! printf '%s' "$o" | grep -q 'selfcheck'; then
  ok "L0 fixture isolation — the fixture's 2 scripts are the population, not this repo's"
else
  no "L0 fixture isolation — --root did not take; the lanes below would be measuring the real repo" "$o"
fi
rm -rf "$d"

# ── L1 known-POSITIVE — a callerless, undeclared script BLOCKS ────────────────────────────────
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/orphan.sh"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"; o="$(run "$d")"
if [ "$rc" = "1" ] && printf '%s' "$o" | grep -q 'scripts/orphan.sh'; then
  ok "L1 known-positive — undeclared zero-caller blocks (exit 1) and is NAMED"
else
  no "L1 known-positive — expected exit 1 naming orphan.sh, got exit $rc" "$o"
fi
rm -rf "$d"

# ── L2 known-NEGATIVE — a properly wired script PASSES ────────────────────────────────────────
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/wired.sh"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\nbash scripts/wired.sh\n' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L2 known-negative — a dispatched script passes (exit 0)" \
                || no "L2 known-negative — a wired script was blocked (over-block), exit $rc" "$(run "$d")"
rm -rf "$d"

# ── L3 THE RATCHET IS BY IDENTITY, NOT BY COUNT ───────────────────────────────────────────────
# The scenario a count-keyed gate passes and an identity-keyed gate must not: the baseline holds ONE
# entry, that entry gets WIRED, and a DIFFERENT script goes callerless. The total is unchanged at 1.
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho old\n' > "$d/scripts/olddebt.sh"
printf '#!/usr/bin/env bash\necho new\n' > "$d/scripts/newdebt.sh"
printf 'exempt:\nbaseline:\n  - scripts/olddebt.sh   # grandfathered measured debt\n' > "$d/scripts/caller_zero_baseline.txt"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\nbash scripts/olddebt.sh\n' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"; o="$(run "$d")"
if [ "$rc" = "1" ] && printf '%s' "$o" | grep -q 'scripts/newdebt.sh' \
   && ! printf '%s' "$o" | grep -q 'FAIL.*olddebt'; then
  ok "L3 identity-keyed — count unchanged (1→1) yet the NEW callerless script blocks"
else
  no "L3 identity-keyed — a count-keyed gate would have passed here; exit $rc" "$o"
fi
# ── L3b twin — the same tree with the new script wired passes ────────────────────────────────
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\nbash scripts/olddebt.sh\nbash scripts/newdebt.sh\n' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L3b twin — wiring the new script clears the block (not a permanent red)" \
                || no "L3b twin — still blocking after the script was wired, exit $rc" "$(run "$d")"
rm -rf "$d"

# ── L4 a declaration without a substantive reason is an INSTRUMENT ERROR, not a pass ──────────
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/orphan.sh"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
printf 'exempt:\n  - scripts/orphan.sh\n' > "$d/scripts/caller_zero_baseline.txt"
rc="$(rcof "$d")"
[ "$rc" = "2" ] && ok "L4 reason required — a bare declaration is exit 2 (channel check), never a silent pass" \
                || no "L4 reason required — expected exit 2, got $rc" "$(run "$d")"
# twin: the same line WITH a reason is accepted
printf 'exempt:\n  - scripts/orphan.sh   # operator-run tool, no caller owed\n' > "$d/scripts/caller_zero_baseline.txt"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L4b twin — the same entry with a written reason is accepted" \
                || no "L4b twin — a reasoned declaration was rejected, exit $rc" "$(run "$d")"
rm -rf "$d"

# ── L5 a MISSING baseline is UNMEASURED, not empty ────────────────────────────────────────────
d="$(mkfix)"
rm -f "$d/scripts/caller_zero_baseline.txt"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"
[ "$rc" = "2" ] && ok "L5 missing baseline — exit 2 (not-found is not zero)" \
                || no "L5 missing baseline — expected exit 2, got $rc" "$(run "$d")"
rm -rf "$d"

# ── L6 an empty population is an instrument failure, not a clean tree ─────────────────────────
d="$(newfix)"; mkdir -p "$d/scripts"
printf 'exempt:\nbaseline:\n' > "$d/scripts/caller_zero_baseline.txt"
rc="$(rcof "$d")"
[ "$rc" = "2" ] && ok "L6 zero population — exit 2, a scan that found nothing did not pass" \
                || no "L6 zero population — expected exit 2, got $rc" "$(run "$d")"
rm -rf "$d"

# ── L7 lane suites are DELEGATED to lane_runner_check.sh, not judged twice ────────────────────
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho lane\n' > "$d/scripts/test_something_lanes.sh"
printf '#!/usr/bin/env bash\necho lane\n' > "$d/scripts/test_other.sh"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L7 delegation — callerless lane suites are out of population (no double judgment)" \
                || no "L7 delegation — a lane suite was judged by this ratchet, exit $rc" "$(run "$d")"
rm -rf "$d"

# ── L8 a MENTION is not an invocation ─────────────────────────────────────────────────────────
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/orphan.sh"
printf '#!/usr/bin/env bash\n#   bash scripts/orphan.sh   <- usage example\nbash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"; o="$(run "$d")"
if [ "$rc" = "1" ] && printf '%s' "$o" | grep -q 'scripts/orphan.sh'; then
  ok "L8 mention≠invocation — a commented usage line does not certify a caller"
else
  no "L8 mention≠invocation — a comment counted as wiring, exit $rc" "$o"
fi
rm -rf "$d"

# ── L9 dot-source counts as a dispatch (a library is CALLED by being sourced) ─────────────────
# The shape that broke the first draft: ` . "$LIB"` has no word boundary before the dot.
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho lib\n' > "$d/scripts/somelib.sh"
printf '%s\n' '#!/usr/bin/env bash' 'L="$(dirname "$0")/somelib.sh"' 'if [ -f "$L" ]; then . "$L"; fi' 'bash scripts/alpha.sh' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L9 dot-source — a sourced library is wired, not callerless" \
                || no "L9 dot-source — a sourced library read as callerless, exit $rc" "$(run "$d")"
rm -rf "$d"

# ── L10 assign-then-dispatch counts / a COPY does not ─────────────────────────────────────────
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/assigned.sh"
printf '%s\n' '#!/usr/bin/env bash' 'JC="$R/scripts/assigned.sh"' 'bash "$JC" --quiet' 'bash scripts/alpha.sh' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L10 assign-then-dispatch — the dominant hook idiom is seen as wiring" \
                || no "L10 assign-then-dispatch — missed, exit $rc" "$(run "$d")"
printf '%s\n' '#!/usr/bin/env bash' 'JC="$R/scripts/assigned.sh"' 'cp "$JC" "$T/scripts/"' 'bash scripts/alpha.sh' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"
[ "$rc" = "1" ] && ok "L10b twin — COPYING a script is not dispatching it (no free pass for fixtures)" \
                || no "L10b twin — a cp was read as a caller, exit $rc" "$(run "$d")"
rm -rf "$d"

# ── L11 plist: <string> is a dispatch, an XML comment is not ─────────────────────────────────
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/daily.sh"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/autopilot.sh"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
printf '%s\n' '<plist>' '<!-- point this at scripts/daily.sh instead -->' '<string>/x/scripts/autopilot.sh</string>' '</plist>' > "$d/scripts/x.plist"
rc="$(rcof "$d")"; o="$(run "$d")"
if [ "$rc" = "1" ] && printf '%s' "$o" | grep -q 'scripts/daily.sh' \
   && ! printf '%s' "$o" | grep -q '· scripts/autopilot.sh'; then
  ok "L11 plist — <string> dispatch wires autopilot, an XML-commented path does NOT wire daily"
else
  no "L11 plist — comment/dispatch not separated, exit $rc" "$o"
fi
rm -rf "$d"

# ── L12 bin/*.js path.join reaches its script ────────────────────────────────────────────────
d="$(mkfix)"; mkdir -p "$d/bin"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/gate.sh"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
printf "%s\n" "path.join(__dirname, '..', 'scripts', 'gate.sh')," > "$d/bin/fh-gate.js"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L12 bin/*.js — a node entry point's path.join counts as a caller" \
                || no "L12 bin/*.js — missed, exit $rc" "$(run "$d")"
rm -rf "$d"

# ── L13 a baseline entry that is now WIRED warns but does not block ──────────────────────────
# Shrink-only hygiene must never punish the person who did the wiring — that is how a ratchet
# becomes something people route around.
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/fixed.sh"
printf 'exempt:\nbaseline:\n  - scripts/fixed.sh   # was debt, wired since\n' > "$d/scripts/caller_zero_baseline.txt"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\nbash scripts/fixed.sh\n' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"; o="$(run "$d")"
# 🟥 The grep is 'now WIRED', not 'shrink-only'. When the shrink-only ENFORCEMENT lanes below were
# added, the checker started printing a `shrink-only: UNMEASURED` line on every non-git fixture —
# which contains the substring 'shrink-only' and would have kept THIS lane green even if the
# resolved-entry warning were deleted. The anchor would have gone decorative at the moment a
# neighbouring feature landed, with nothing red to say so.
if [ "$rc" = "0" ] && printf '%s' "$o" | grep -q 'now WIRED'; then
  ok "L13 shrink-only — a resolved baseline entry warns (visible) and passes (not punished)"
else
  no "L13 shrink-only — expected exit 0 plus a warning, got $rc" "$o"
fi
rm -rf "$d"

# ── L14 an entry naming a file that does not exist is surfaced ───────────────────────────────
d="$(mkfix)"
printf 'exempt:\n  - scripts/renamed_away.sh   # stale entry, file is gone\nbaseline:\n' > "$d/scripts/caller_zero_baseline.txt"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
o="$(run "$d")"
printf '%s' "$o" | grep -q 'does not exist' \
  && ok "L14 ghost entry — a declaration for a missing file is named, not silently honoured" \
  || no "L14 ghost entry — stale declaration passed unnoticed" "$o"
rm -rf "$d"

# ══════════════════════════════════════════════════════════════════════════════════════════════
# L15–L17 — SHRINK-ONLY ENFORCEMENT ON `baseline:`
# The defect these anchor: the checker's own FAIL message said "Adding it under baseline: is NOT
# one of the options … a new entry there is the regrowth this ratchet exists to stop", and the code
# permitted exactly that. Reproduced by the governor 2026-08-22: a new callerless script plus a new
# baseline: line in the same change exited 0. The rule was true in prose and false in machinery.
# ══════════════════════════════════════════════════════════════════════════════════════════════

# ── L15 known-POSITIVE — a NEW baseline: entry blocks even though it is "declared" ────────────
d="$(gitfix)"
printf '#!/usr/bin/env bash\necho new\n' > "$d/scripts/newdebt.sh"
printf 'exempt:\nbaseline:\n  - scripts/newdebt.sh   # freshly added debt, the illegal move\n' > "$d/scripts/caller_zero_baseline.txt"
rc="$(rcof "$d")"; o="$(run "$d")"
if [ "$rc" = "1" ] && printf '%s' "$o" | grep -q 'SHRINK-ONLY' \
   && printf '%s' "$o" | grep -q 'scripts/newdebt.sh'; then
  ok "L15 shrink-only — a NEW baseline: entry blocks (exit 1) and is NAMED"
else
  no "L15 shrink-only — the governor's reproduction still passes; exit $rc" "$o"
fi

# ── L15b known-NEGATIVE twin — the SAME script declared under exempt: passes ──────────────────
# Without this twin, L15 would also be green if the checker simply blocked all declarations. The
# claim under test is narrow: growth of `baseline:` specifically, not declaring a script at all.
printf 'exempt:\n  - scripts/newdebt.sh   # entry point, no caller owed\nbaseline:\n' > "$d/scripts/caller_zero_baseline.txt"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L15b twin — the same new script under exempt: is a legal move (exit 0)" \
                || no "L15b twin — exempt: additions were blocked too (over-block), exit $rc" "$(run "$d")"

# ── L15c known-NEGATIVE twin — an UNCHANGED baseline: passes, and NAMES what it compared to ───
# 🟥 This lane used to assert the word ENFORCED and it was WRONG to. `gitfix` has exactly one
# commit, so the auto-resolved base IS HEAD and the comparison is HEAD-vs-working-tree: real power
# over the uncommitted edit these lanes make, zero power over anything committed. The checker now
# calls that WORKTREE_ONLY, and this lane asserts the honest label — plus, explicitly, that the
# misleading one is ABSENT. Asserting only the new string would have left the lane green if both
# labels were printed.
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\nbash scripts/newdebt.sh\n' > "$d/.github/workflows/ci.yml"
printf 'exempt:\nbaseline:\n' > "$d/scripts/caller_zero_baseline.txt"
rc="$(rcof "$d")"; o="$(run "$d")"
if [ "$rc" = "0" ] && printf '%s' "$o" | grep -q 'shrink-only WORKTREE_ONLY' \
   && ! printf '%s' "$o" | grep -q 'ENFORCED'; then
  ok "L15c twin — an unchanged baseline: passes, labelled WORKTREE_ONLY (never ENFORCED vs HEAD)"
else
  no "L15c twin — expected exit 0 plus WORKTREE_ONLY and no ENFORCED, got $rc" "$o"
fi
rm -rf "$d"

# ── L16 REMOVAL and baseline:→exempt: MIGRATION are always legal ──────────────────────────────
# A ratchet that punished the person who paid down the debt is a ratchet people route around.
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho old\n' > "$d/scripts/olddebt.sh"
printf 'exempt:\nbaseline:\n  - scripts/olddebt.sh   # grandfathered measured debt\n' > "$d/scripts/caller_zero_baseline.txt"
d="$(fh_fixture_root "$d")"
git -C "$d" -c init.defaultBranch=main init -q >/dev/null 2>&1
git -C "$d" add scripts .github >/dev/null 2>&1
git -C "$d" -c user.email=lane@example.invalid -c user.name=lane \
    -c core.hooksPath=/nonexistent-fixture-hooks commit -q --no-verify -m base >/dev/null 2>&1
# (a) wire it and delete the line
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\nbash scripts/olddebt.sh\n' > "$d/.github/workflows/ci.yml"
printf 'exempt:\nbaseline:\n' > "$d/scripts/caller_zero_baseline.txt"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L16 shrink — deleting a paid-off baseline: line passes (exit 0)" \
                || no "L16 shrink — paying down debt was punished, exit $rc" "$(run "$d")"
# (b) move it to exempt: without wiring it
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
printf 'exempt:\n  - scripts/olddebt.sh   # reclassified: operator-run tool\nbaseline:\n' > "$d/scripts/caller_zero_baseline.txt"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L16b migration — baseline: → exempt: is a legal move (exit 0)" \
                || no "L16b migration — a reclassification was blocked, exit $rc" "$(run "$d")"
rm -rf "$d"

# ── L17 DEGRADE DIRECTION — unmeasurable base is LABELLED, and closes only where told to ──────
# 🟥 Three-valued on purpose. "could not compare" must never render as "compared, nothing found".
d="$(mkfix)"          # deliberately NOT a git repo
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"; o="$(run "$d")"
if [ "$rc" = "0" ] && printf '%s' "$o" | grep -q 'shrink-only UNMEASURED' \
   && printf '%s' "$o" | grep -q 'shrink-only: UNMEASURED'; then
  ok "L17 degrade — no base: labelled UNMEASURED in BOTH the body and the PASS line, non-blocking"
else
  no "L17 degrade — an unmeasurable base was rendered as a clean pass, exit $rc" "$o"
fi
# twin: the merge-boundary setting turns the same state into an instrument error
rc="$(FH_RATCHET_REQUIRE_BASE=1 rcof "$d")"
[ "$rc" = "2" ] && ok "L17b degrade-closed — FH_RATCHET_REQUIRE_BASE=1 makes UNMEASURED exit 2" \
                || no "L17b degrade-closed — CI setting did not fail closed, exit $rc" "$(FH_RATCHET_REQUIRE_BASE=1 run "$d")"
rm -rf "$d"

# ══════════════════════════════════════════════════════════════════════════════════════════════
# L18 — SUBSTRING vs PATH TOKEN
# The defect: `bash scripts/foo.sh.bak` in a runner certified scripts/foo.sh as WIRED, exit 0.
# The FP always lands on the PASS side, which is the direction that makes a gate decorative.
# ══════════════════════════════════════════════════════════════════════════════════════════════

# ── L18 known-POSITIVE — a SUFFIXED path does not certify the base name ───────────────────────
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/foo.sh"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\nbash scripts/foo.sh.bak --quiet\n' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"; o="$(run "$d")"
if [ "$rc" = "1" ] && printf '%s' "$o" | grep -q 'scripts/foo.sh$'; then
  ok "L18 token boundary — a .bak suffix does NOT wire foo.sh (blocks, exit 1)"
else
  no "L18 token boundary — a suffixed path certified the base name, exit $rc" "$o"
fi
# twin: the unsuffixed dispatch of the same name still counts (no over-tightening)
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\nbash scripts/foo.sh --quiet\n' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L18b twin — the real dispatch of foo.sh still passes (boundary not over-tight)" \
                || no "L18b twin — the boundary broke a legitimate dispatch, exit $rc" "$(run "$d")"
rm -rf "$d"

# ── L18c the LEADING end of the same hole — a LONGER basename must not certify its suffix ─────
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/foo.sh"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/myfoo.sh"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\nbash scripts/myfoo.sh\n' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"; o="$(run "$d")"
if [ "$rc" = "1" ] && printf '%s' "$o" | grep -q '· scripts/foo.sh' \
   && ! printf '%s' "$o" | grep -q '· scripts/myfoo.sh'; then
  ok "L18c token boundary — myfoo.sh is wired, foo.sh is not; the longer name does not cover it"
else
  no "L18c token boundary — leading end of the substring hole is open, exit $rc" "$o"
fi
rm -rf "$d"

# ── L18d shape 3 through a suffixed path ─────────────────────────────────────────────────────
# The assign-then-dispatch idiom re-opened the same hole one level down: a variable assigned
# `.../foo.sh.bak` and later run as "$VAR" certified foo.sh, because the shape-3 prefilter was a
# bare substring test even after the direct-match regex had been given boundaries.
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/foo.sh"
printf '%s\n' '#!/usr/bin/env bash' 'V="$R/scripts/foo.sh.bak"' 'bash "$V"' 'bash scripts/alpha.sh' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"
[ "$rc" = "1" ] && ok "L18d token boundary — shape 3 over a suffixed path does not wire foo.sh" \
                || no "L18d token boundary — assign-then-dispatch bypassed the boundary, exit $rc" "$(run "$d")"
# twin: shape 3 over the REAL path still wires it
printf '%s\n' '#!/usr/bin/env bash' 'V="$R/scripts/foo.sh"' 'bash "$V"' 'bash scripts/alpha.sh' > "$d/.github/workflows/ci.yml"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L18e twin — shape 3 over the real path still wires it" \
                || no "L18e twin — the boundary broke the dominant hook idiom, exit $rc" "$(run "$d")"
rm -rf "$d"

# ══════════════════════════════════════════════════════════════════════════════════════════════
# L19 — A PLACEHOLDER PLIST PATH IS NOT A DISPATCH
# The defect, found by the governor with a known pair: scripts/frontier_digest_autopilot.sh read
# as WIRED on the strength of `<string>/path/to/forge-harness/scripts/...</string>` — a path
# launchd cannot execute, and one that ship_readiness_gate.md had ALREADY recorded as an
# identity-④ defect. The gate was passing over a defect its own repo had written down.
# ══════════════════════════════════════════════════════════════════════════════════════════════
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/daily.sh"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
printf '%s\n' '<plist>' '<string>/path/to/forge-harness/scripts/daily.sh</string>' '</plist>' > "$d/scripts/x.plist"
rc="$(rcof "$d")"; o="$(run "$d")"
if [ "$rc" = "1" ] && printf '%s' "$o" | grep -q '· scripts/daily.sh' \
   && printf '%s' "$o" | grep -q 'PLACEHOLDER path'; then
  ok "L19 placeholder plist — /path/to/ does not wire, and the run SAYS why (named, not silent)"
else
  no "L19 placeholder plist — a template path certified a dispatch, exit $rc" "$o"
fi
# 🟥 twin, and it is the one that matters for portability: a CORRECT plist hardcodes the author's
# own absolute path, which does not exist on the CI runner. The naive repair (does this path
# resolve on disk?) would go green on macOS and red on Linux for a plist with nothing wrong with
# it. This twin is what forbids that repair from ever being substituted in.
printf '%s\n' '<plist>' '<string>/opt/ci/projects/forge-harness/scripts/daily.sh</string>' '</plist>' > "$d/scripts/x.plist"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L19b twin — a real absolute path wires it, on any OS, resolvable or not" \
                || no "L19b twin — the placeholder filter over-blocks a legitimate plist, exit $rc" "$(run "$d")"
rm -rf "$d"

# ── L20 the EXPLICIT --base ref is honoured, and an unresolvable one is exit 2 ────────────────
# L15–L17 exercise the AUTO resolver, which is the path CI and developers actually take (nobody
# types --base). That left the flag itself with zero anchors — a checker option nothing exercises
# is the built-but-not-wired shape, inside the very gate that hunts it. These two close it.
d="$(gitfix)"
printf '#!/usr/bin/env bash\necho new\n' > "$d/scripts/newdebt.sh"
printf 'exempt:\nbaseline:\n  - scripts/newdebt.sh   # freshly added debt, the illegal move\n' > "$d/scripts/caller_zero_baseline.txt"
rc="$(rcofx "$d" --base HEAD)"; o="$(runx "$d" --base HEAD)"
if [ "$rc" = "1" ] && printf '%s' "$o" | grep -q 'SHRINK-ONLY'; then
  ok "L20 explicit --base — the named ref is used and the new baseline: entry blocks"
else
  no "L20 explicit --base — the flag did not drive the comparison, exit $rc" "$o"
fi
# 🟥 twin: a --base that does not resolve must be exit 2, NOT a silent fall-through to
# auto-detection and NOT a labelled UNMEASURED. Substituting a different comparison for the one
# that was asked for is how an instrument answers confidently about the wrong target.
rc="$(rcofx "$d" --base no-such-ref-xyz)"
[ "$rc" = "2" ] && ok "L20b twin — an unresolvable --base is an instrument error (exit 2), not a fallback" \
                || no "L20b twin — a bad --base silently fell back, exit $rc" "$(runx "$d" --base no-such-ref-xyz)"
# 🟥 twin: and it must still block via the ENV twin of the flag, since CI sets env not argv.
rc="$(FH_RATCHET_BASE_REF=HEAD rcof "$d")"
[ "$rc" = "1" ] && ok "L20c twin — FH_RATCHET_BASE_REF drives the same path as --base" \
                || no "L20c twin — the env twin of --base is dead, exit $rc" "$(FH_RATCHET_BASE_REF=HEAD run "$d")"
rm -rf "$d"

# ══════════════════════════════════════════════════════════════════════════════════════════════
# L21–L22 — THE BASE MUST NOT BE HEAD
# The defect (cross-family reproduction, codex/gpt-5.5, 2026-08-22): on a `push` to main
# GITHUB_BASE_REF is unset and `origin/main` resolves to the checked-out HEAD. A commit carrying
# BOTH scripts/newdebt.sh and its new `baseline:` line — the exact illegal move the ratchet exists
# to stop — exited 0 and printed "shrink-only ENFORCED". Comparing a commit with itself makes
# "nothing was added" true by construction. Detached and shallow checkouts have the same shape.
# Reproduced against the pre-fix checker before these lanes were written; the fail-before output is
# recorded in the repair note rather than paraphrased here.
# ══════════════════════════════════════════════════════════════════════════════════════════════

# A two-commit git fixture: `base` holds the starting tree, then a second commit lands whatever the
# lane wants COMMITTED (clean working tree — that is what CI checks out, and a dirty tree is what
# masked this defect in every earlier lane).
gitfix2() {
  _d="$(gitfix)"
  printf '#!/usr/bin/env bash\necho new\n' > "$_d/scripts/newdebt.sh"
  printf 'exempt:\nbaseline:\n  - scripts/newdebt.sh   # freshly added debt, the illegal move\n' \
      > "$_d/scripts/caller_zero_baseline.txt"
  git -C "$_d" add scripts >/dev/null 2>&1
  git -C "$_d" -c user.email=lane@example.invalid -c user.name=lane \
      -c core.hooksPath=/nonexistent-fixture-hooks \
      commit -q --no-verify -m illegal >/dev/null 2>&1
  echo "$_d"
}

# ── L21 known-POSITIVE — the CI reproduction: clean tree, base auto-resolves to HEAD ──────────
d="$(gitfix2)"
# control first: the tree really is clean, so this lane is testing the committed case and not
# accidentally re-testing the worktree case that already had power.
st="$(git -C "$d" status --short)"
[ -z "$st" ] || no "L21 SETUP — fixture tree is not clean, the lane would measure the wrong thing" "$st"
rc="$(FH_RATCHET_REQUIRE_BASE=1 rcof "$d")"; o="$(FH_RATCHET_REQUIRE_BASE=1 run "$d")"
if [ "$rc" = "2" ] && printf '%s' "$o" | grep -q 'not a usable comparison'; then
  ok "L21 base≠HEAD — a self-comparison under CI settings is exit 2, not a vacuous pass"
else
  no "L21 base≠HEAD — the governor/codex reproduction still passes; exit $rc" "$o"
fi

# ── L21b known-NEGATIVE twin — the SAME tree with a REAL base actually CATCHES it ─────────────
# 🟥 Without this twin L21 would also be green if the fix simply made CI always exit 2. The claim
# under test is that naming an immutable base RESTORES the verdict, not that it suppresses it.
rc="$(FH_RATCHET_BASE_REF=HEAD~1 FH_RATCHET_REQUIRE_BASE=1 rcof "$d")"
o="$(FH_RATCHET_BASE_REF=HEAD~1 FH_RATCHET_REQUIRE_BASE=1 run "$d")"
if [ "$rc" = "1" ] && printf '%s' "$o" | grep -q 'SHRINK-ONLY' \
   && printf '%s' "$o" | grep -q 'scripts/newdebt.sh'; then
  ok "L21b twin — with an immutable base the committed illegal move BLOCKS and is NAMED"
else
  no "L21b twin — a real base did not restore the catch, exit $rc" "$o"
fi

# ── L21c known-NEGATIVE twin — a LEGAL commit under the same CI settings still passes ─────────
# The over-block guard for the whole L21 family: CI must not go red on every push.
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\nbash scripts/newdebt.sh\n' > "$d/.github/workflows/ci.yml"
printf 'exempt:\nbaseline:\n' > "$d/scripts/caller_zero_baseline.txt"
git -C "$d" add scripts .github >/dev/null 2>&1
git -C "$d" -c user.email=lane@example.invalid -c user.name=lane \
    -c core.hooksPath=/nonexistent-fixture-hooks commit -q --no-verify -m legal >/dev/null 2>&1
rc="$(FH_RATCHET_BASE_REF=HEAD~1 FH_RATCHET_REQUIRE_BASE=1 rcof "$d")"
o="$(FH_RATCHET_BASE_REF=HEAD~1 FH_RATCHET_REQUIRE_BASE=1 run "$d")"
if [ "$rc" = "0" ] && printf '%s' "$o" | grep -q 'shrink-only ENFORCED'; then
  ok "L21c twin — a legal commit with a real base passes, and the run says ENFORCED for real"
else
  no "L21c twin — the CI configuration over-blocks a legal change, exit $rc" "$o"
fi
rm -rf "$d"

# ── L22 the LOCAL degrade direction — self-comparison is labelled, not blocked ────────────────
# Without FH_RATCHET_REQUIRE_BASE (a developer's machine, a pre-commit hook) the same state must
# stay non-blocking: an over-blocking local gate trains `--no-verify` and disarms its neighbours.
# But it must NOT be able to print the word a CI log would be quoted from.
d="$(gitfix2)"
rc="$(rcof "$d")"; o="$(run "$d")"
if [ "$rc" = "0" ] && printf '%s' "$o" | grep -q 'shrink-only WORKTREE_ONLY' \
   && ! printf '%s' "$o" | grep -q 'ENFORCED'; then
  ok "L22 degrade — locally a self-comparison passes but is LABELLED, never called ENFORCED"
else
  no "L22 degrade — a self-comparison was rendered as a real comparison, exit $rc" "$o"
fi
rm -rf "$d"

# ══════════════════════════════════════════════════════════════════════════════════════════════
# L23 — AN UNEXPANDED VARIABLE IN A PLIST PATH IS NOT A DISPATCH
# launchd execs ProgramArguments literally; it performs no shell expansion. `$HOME/...` is
# therefore exactly as unexecutable as `/path/to/...`. Cross-family reproduction 2026-08-22:
# `<string>$HOME/projects/forge-harness/scripts/daily.sh</string>` counted as a caller, exit 0.
# ══════════════════════════════════════════════════════════════════════════════════════════════
for _form in '$HOME/projects/repo/scripts/daily.sh' \
             '${HOME}/projects/repo/scripts/daily.sh' \
             '~/projects/repo/scripts/daily.sh'; do
  d="$(mkfix)"
  printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/daily.sh"
  printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
  printf '%s\n' '<plist>' "<string>$_form</string>" '</plist>' > "$d/scripts/x.plist"
  rc="$(rcof "$d")"; o="$(run "$d")"
  if [ "$rc" = "1" ] && printf '%s' "$o" | grep -q '· scripts/daily.sh' \
     && printf '%s' "$o" | grep -q 'PLACEHOLDER path'; then
    ok "L23 unexpanded plist path — '$_form' does NOT wire, and the run SAYS why"
  else
    no "L23 unexpanded plist path — '$_form' certified a dispatch, exit $rc" "$o"
  fi
  rm -rf "$d"
done

# ── L23b known-NEGATIVE twin — an absolute path in the SAME fixture shape still wires ─────────
# 🟥 The over-block twin has to live next to the block, in the same fixture shape. L19b proves the
# `/path/to/` filter does not over-block; it says nothing about the three forms just added, and a
# `$`/`~` class written one character too wide would eat real paths silently on the PASS side.
d="$(mkfix)"
printf '#!/usr/bin/env bash\necho hi\n' > "$d/scripts/daily.sh"
printf '#!/usr/bin/env bash\nbash scripts/alpha.sh\n' > "$d/.github/workflows/ci.yml"
printf '%s\n' '<plist>' '<string>/opt/ci/projects/repo/scripts/daily.sh</string>' '</plist>' \
    > "$d/scripts/x.plist"
rc="$(rcof "$d")"
[ "$rc" = "0" ] && ok "L23b twin — a real absolute path still wires (the \$/~ class did not over-reach)" \
                || no "L23b twin — the added placeholder forms over-block a real path, exit $rc" "$(run "$d")"
rm -rf "$d"

# ══════════════════════════════════════════════════════════════════════════════════════════════
# L24–L26 — THE BASE RESOLVER MUST NOT SUBSTITUTE A DIFFERENT COMPARISON
# The defect (reproduced 2026-08-22, on a three-commit fixture, before scripts/ratchet_base_resolve.sh
# existed): the workflow tested its candidate with `git cat-file -e`, and on failure set B="" and
# fell through to HEAD~1. A base NAMED by the event but force-pushed away therefore became a
# SILENT, NARROWER comparison — and the checker printed "shrink-only ENFORCED" over the exact
# illegal move (a callerless script plus its new `baseline:` line) landed one commit earlier.
#
# 🟥 These lanes could not exist before the extraction. The logic lived in a `run:` block, and no
# lane can execute YAML — which is why an A-grade fail-open survived three adversarial rounds in
# the one component that decides whether this gate measures anything at all.
# ══════════════════════════════════════════════════════════════════════════════════════════════
RESOLVE="${FH_RATCHET_BASE_RESOLVE_BIN:-$ROOT/scripts/ratchet_base_resolve.sh}"
[ -f "$RESOLVE" ] || { echo "FAIL  harness: $RESOLVE not found"; exit 1; }

# 🟥 THE FIXTURE'S UNREACHABLE BASE IS A WELL-FORMED 40-HEX SHA, NOT `no-such-ref`.
# A malformed ref name is the EASY spelling: almost any sloppy check rejects it. What a force-push
# actually leaves behind is a syntactically perfect object id that is simply no longer in the
# object store, and that is the spelling that has to be in the fixture
# ([[feedback_fixture_must_use_the_breaking_spelling]]). `no-such-ref-xyz` is kept as a second,
# weaker case in L24d so the easy spelling is covered too — not as a replacement for this one.
GONE_SHA=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef

# Three commits: A (clean base) · B (the illegal move, COMMITTED) · C (an unrelated later commit).
# HEAD~1 is therefore B, which already contains the growth — so a HEAD~1 substitution reports a
# clean diff. That is the whole shape of the defect, and it needs three commits to exist at all.
gitfix3() {
  _d="$(gitfix)"
  printf '#!/usr/bin/env bash\necho new\n' > "$_d/scripts/newdebt.sh"
  printf 'exempt:\nbaseline:\n  - scripts/newdebt.sh   # freshly added debt, the illegal move\n' \
      > "$_d/scripts/caller_zero_baseline.txt"
  git -C "$_d" add scripts >/dev/null 2>&1
  git -C "$_d" -c user.email=lane@example.invalid -c user.name=lane \
      -c core.hooksPath=/nonexistent-fixture-hooks commit -q --no-verify -m illegal >/dev/null 2>&1
  printf '#!/usr/bin/env bash\necho alpha2\n' > "$_d/scripts/alpha.sh"
  git -C "$_d" add scripts >/dev/null 2>&1
  git -C "$_d" -c user.email=lane@example.invalid -c user.name=lane \
      -c core.hooksPath=/nonexistent-fixture-hooks commit -q --no-verify -m later >/dev/null 2>&1
  echo "$_d"
}
# Drive the resolver the way the workflow does: event vars in, base=/require= out to a FILE.
# RATCHET_OUTPUT is always set explicitly so a real $GITHUB_OUTPUT in the ambient environment can
# never be appended to by a lane.
RESOUT="$FIXROOT/resolver.out"
resolve() {   # resolve <root> [VAR=VAL ...] -> rc; writes base=/require= to $RESOUT
  _d="$1"; shift
  : > "$RESOUT"
  env -u GITHUB_OUTPUT BASE_BRANCH="" PR_BASE_SHA="" PUSH_BEFORE="" RATCHET_OUTPUT="$RESOUT" "$@" \
      bash "$RESOLVE" --root "$_d" >"$FIXROOT/resolver.log" 2>&1
  echo $?
}
rget() { grep "^$1=" "$RESOUT" | tail -1 | cut -d= -f2-; }
rlog() { cat "$FIXROOT/resolver.log"; }

# ── L24 known-POSITIVE — a NAMED base that is unreachable is exit 3, with NO substitution ──────
d="$(gitfix3)"
A="$(git -C "$d" rev-parse HEAD~2)"
rc="$(resolve "$d" PUSH_BEFORE="$GONE_SHA")"
b="$(rget base)"; req="$(rget require)"
# THREE assertions, because "it exited nonzero" is not the claim. The claim is that it refused AND
# published nothing usable: a resolver that exited 3 while still writing base=HEAD~1 would leave
# the substitution live for any caller that ignores the exit code.
if [ "$rc" = "3" ] && [ -z "$b" ] && [ -z "$req" ] && rlog | grep -q 'does not resolve in this checkout'; then
  ok "L24 named-but-gone — exit 3, no base emitted, and the run SAYS the comparison was refused"
else
  no "L24 named-but-gone — the force-push shape still substitutes; exit $rc base='$b' require='$req'" "$(rlog)"
fi

# ── L24b known-NEGATIVE twin — the SAME event with a REACHABLE base resolves normally ──────────
# 🟥 Without this twin L24 would also be green if the resolver simply refused every push event.
# The claim under test is narrow: refusal is keyed on the base being GONE, not on it being named.
rc="$(resolve "$d" PUSH_BEFORE="$A")"
b="$(rget base)"; req="$(rget require)"
if [ "$rc" = "0" ] && [ "$b" = "$A" ] && [ "$req" = "1" ]; then
  ok "L24b twin — a reachable named base resolves to itself, require=1 (refusal is not blanket)"
else
  no "L24b twin — a legitimate push event was refused (over-block); exit $rc base='$b'" "$(rlog)"
fi

# ── L24c THE END-TO-END ARM — resolver + checker, the pair the CI job actually runs ────────────
# L24/L24b test the resolver in isolation. This one closes the loop the defect actually lived in:
# under the OLD code this pair printed "shrink-only ENFORCED" and exited 0 over the illegal move.
# The control runs first so the checker is proven live on this very fixture before the arm's
# non-verdict is read as anything.
ctl_rc="$(FH_RATCHET_BASE_REF="$A" FH_RATCHET_REQUIRE_BASE=1 rcof "$d")"
ctl_o="$(FH_RATCHET_BASE_REF="$A" FH_RATCHET_REQUIRE_BASE=1 run "$d")"
if [ "$ctl_rc" = "1" ] && printf '%s' "$ctl_o" | grep -q 'scripts/newdebt.sh'; then
  ok "L24c CONTROL — with the true base the checker catches the illegal move on this fixture"
else
  no "L24c CONTROL — the checker is not live on this fixture; the arm below would prove nothing" "$ctl_o"
fi
# the arm: the resolver refuses, so the checker is never reached with a substituted base
rc="$(resolve "$d" PUSH_BEFORE="$GONE_SHA")"
h1="$(git -C "$d" rev-parse HEAD~1)"
if [ "$rc" = "3" ] && ! grep -q "$h1" "$RESOUT"; then
  ok "L24c ARM — the gone-base run stops at the resolver; HEAD~1 is never handed to the checker"
else
  no "L24c ARM — HEAD~1 reached the checker as a substitute base; exit $rc" "$(cat "$RESOUT"; rlog)"
fi

# ── L24d the easy spelling too — a MALFORMED named ref is also a refusal, not a fallback ──────
rc="$(resolve "$d" PUSH_BEFORE=no-such-ref-xyz)"
[ "$rc" = "3" ] && ok "L24d named-but-gone — a malformed named ref refuses as well (both spellings)" \
                || no "L24d named-but-gone — a malformed ref fell through, exit $rc" "$(rlog)"

# ── L24e the PR shape — a base BRANCH that does not exist here refuses too ────────────────────
# github.base_ref names a branch, not a sha, and takes a different code path (merge-base). A fix
# applied to only the sha path would leave this one open and every lane above would stay green.
rc="$(resolve "$d" BASE_BRANCH=no-such-branch)"
[ "$rc" = "3" ] && ok "L24e PR shape — an unresolvable base BRANCH refuses (the merge-base path too)" \
                || no "L24e PR shape — the branch path still falls through, exit $rc" "$(rlog)"
rm -rf "$d"

# ── L25 NOTHING NAMED — HEAD~1 is used, and the one-commit window is ANNOUNCED ────────────────
# This half is unchanged from the YAML it replaces: nothing was requested, so nothing is being
# substituted. What it owes is honesty about the width of the window.
d="$(gitfix3)"
h1="$(git -C "$d" rev-parse HEAD~1)"
rc="$(resolve "$d")"
b="$(rget base)"; req="$(rget require)"
if [ "$rc" = "0" ] && [ "$b" = "$h1" ] && [ "$req" = "1" ] && rlog | grep -q 'ONE-COMMIT window'; then
  ok "L25 nothing named — HEAD~1 is used and the narrow window is stated, not implied"
else
  no "L25 nothing named — expected HEAD~1 plus an announcement; exit $rc base='$b'" "$(rlog)"
fi
rm -rf "$d"

# ── L26 EMPTY INPUT — a one-commit repo emits require=0, NEVER require=1 with an empty base ───
# 🟥 The empty-set question asked on its own. `require=1` beside an empty base would reach the
# checker as "compare against nothing, and refuse to accept nothing" — exit 2 for a repo whose
# only sin is having one commit, i.e. a gate no author action can satisfy.
d="$(gitfix)"
rc="$(resolve "$d")"
b="$(rget base)"; req="$(rget require)"
if [ "$rc" = "0" ] && [ -z "$b" ] && [ "$req" = "0" ] && rlog | grep -q 'BOOTSTRAP'; then
  ok "L26 empty input — one commit gives base='' require=0 (bootstrap), not a satisfiable-by-nobody gate"
else
  no "L26 empty input — expected an empty base with require=0; exit $rc base='$b' require='$req'" "$(rlog)"
fi
# twin: and that bootstrap really is non-blocking end to end
rc="$(FH_RATCHET_REQUIRE_BASE=0 rcof "$d")"
[ "$rc" = "0" ] && ok "L26b twin — the bootstrap answer does not block the checker" \
                || no "L26b twin — bootstrap blocked, exit $rc" "$(run "$d")"
rm -rf "$d"

# ── L26c a NON-REPO root is an instrument error (exit 2), distinct from bootstrap (exit 0) ────
# Two different facts, two different codes. Collapsing them would let "the step ran in the wrong
# directory" render as "this repo has no history yet".
d="$(mkfix)"          # deliberately not a git repo
rc="$(resolve "$d")"
[ "$rc" = "2" ] && ok "L26c non-repo — exit 2 (instrument error), not exit 0 bootstrap" \
                || no "L26c non-repo — a non-repo root was read as a bootstrap, exit $rc" "$(rlog)"
rm -rf "$d"

# ── L27 WIRING — the workflow calls the resolver, not an inline copy of it ────────────────────
# 🟥 A static grep, and it is labelled as one. It cannot prove the step RUNS; what it does prove is
# that the extracted logic has not been silently re-inlined beside it, which is the way this repair
# would rot. The behavioural claim is carried by L24–L26, which execute the real file.
WF="$ROOT/.github/workflows/caller-zero-ratchet.yml"
if [ -f "$WF" ] && grep -q 'ratchet_base_resolve.sh' "$WF" \
   && ! grep -q "rev-parse --verify --quiet 'HEAD~1" "$WF"; then
  ok "L27 wiring — the workflow dispatches the resolver and carries no inline HEAD~1 fallback"
else
  no "L27 wiring — the workflow does not call the resolver, or an inline fallback came back" \
     "$(grep -n 'HEAD~1\|ratchet_base_resolve' "$WF" 2>&1)"
fi

# ── L28 — A `SUBJECT|ANCHOR` PAIR DISPATCHES ONLY THE ANCHOR ──────────────────────────────────
# WHAT THIS CLOSES. scripts/selfcheck.sh drives its suite list as `"SUBJECT|ANCHOR"` strings and
# its body does `_subj="${_pair%%|*}"; _anc="${_pair##*|}" ... bash "$_anc"` — the SUBJECT is only
# `[ -f ]`-tested, never run. Shape 2 (for-list) credited BOTH sides, so a script that merely
# appears as a subject was reported WIRED.
# Cost, measured twice on the same file: on 2026-08-26 the ratchet told a session to delete
# scripts/chamber_candidate_collect.sh from `baseline:` — a section whose whole meaning is "still
# owes a PRODUCTION caller" — and a cross-family review had to revert it. On 2026-08-30 the same
# advisory fired again on the same file, and the only thing that prevented a second deletion was
# the note that reviewer had left behind. These two lanes replace that note with a check.
d="$(mkfix)"
printf '%s\n' '#!/usr/bin/env bash' 'echo subj' > "$d/scripts/subj.sh"
printf '%s\n' '#!/usr/bin/env bash' 'echo anch' > "$d/scripts/anch.sh"
cat > "$d/.github/workflows/ci.yml" <<'YML'
run: |
  bash scripts/alpha.sh
  for _p in "scripts/subj.sh|scripts/anch.sh"; do
    _a="${_p##*|}"; bash "$_a"
  done
YML
o28="$(run "$d")"
if printf '%s' "$o28" | grep -q "scripts/subj.sh"; then
  ok "L28a subject side of a pair is NOT credited as a caller"
else
  no "L28a subject was credited — the pair form still discharges a production-caller debt" "$o28"
fi
# 🟥 CONTROL, and it is the half that makes L28a mean anything. If the fix were "stop trusting the
# pipe form at all", L28a would pass while real anchor wiring silently broke — and every suite in
# selfcheck.sh is wired exactly this way.
if printf '%s' "$o28" | grep -q "scripts/anch.sh"; then
  no "L28b control — the ANCHOR side lost its credit; the fix over-narrowed" "$o28"
else
  ok "L28b control — anchor side still counts as wired"
fi
rm -rf "$d"

echo "-- caller-ratchet lanes: PASS $pass · FAIL $fail --"
[ "$fail" -eq 0 ] || exit 1
exit 0
