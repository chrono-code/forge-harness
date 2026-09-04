#!/usr/bin/env bash
# test_package_coverage_lanes.sh — regression anchor for scripts/package_coverage_check.sh.
#
# WHY THIS EXISTS (measured 2026-07-31):
#   package_coverage_check.sh gated itself on `[ ! -d .git ]`. In a git WORKTREE `.git` is a FILE
#   (a gitdir pointer), so every worktree fell into the "installed package" branch and the check
#   printed `SKIP` and exited 0 without scanning anything. That is a FALSE CLEAN of the worst shape:
#   a worktree is the standard way to approximate a fresh CI checkout, so the surface used to argue
#   "CI would be green" was precisely the surface on which this check silently did not run.
#   It was found by using the instrument, then asking whether the instrument had run at all —
#   CLAUDE.md §Instrument-Calibration, applied to FH's own tooling.
#
#   Second reason: selfcheck.sh enforces "subject present but anchor missing => FAIL" for eight
#   other scripts, and package_coverage_check.sh was the one subject exempted from its own rule.
#   An unanchored checker is one revert away from being decoration.
#
# The lanes pin, in order: the source-checkout predicate across all four tree shapes (worktree /
# ordinary checkout / package mode / no manifest), and a KNOWN PAIR — a tree that must FAIL and an
# otherwise identical tree that must PASS. A predicate that cannot separate that pair is not
# measuring coverage, it is emitting a verdict.
#
# Usage:  bash scripts/test_package_coverage_lanes.sh
# Exit:   0 = no lane FAILED. 1 = a regression.
#         NOT "all lanes passed": a lane whose precondition is absent (no git) is counted as
#         UNCALIBRATED and printed in the summary, and exit stays 0. Stated precisely because the
#         earlier wording promised more than the code delivers, and an exit contract that overstates
#         is exactly the false-clean this suite exists to prevent (round-3 review, LOW).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBJECT="$REPO_ROOT/scripts/package_coverage_check.sh"
[ -f "$SUBJECT" ] || { echo "FAIL: $SUBJECT not found"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0; skipped=0
ok()  { printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
# $2 (optional) = the actual stdout/stderr/rc this case caught — printed so a red lane in CI is
# diagnosable without re-running it by hand. Truncated/flattened like the node-check lanes' bad().
bad() { printf '  ❌ %s\n' "$1"; [ -n "${2:-}" ] && printf '     got: %s\n' "$(printf '%s' "$2" | tr '\n' '|' | cut -c1-220)"; fail=$((fail+1)); }
# A skip is COUNTED and reported. An uncounted skip is how "could not run" becomes indistinguishable
# from "ran and passed" in the summary line — measured on this very suite in review round 2, where a
# broken git produced "7 passed, 0 failed" and exit 0 while the real-worktree claim went untested.
# Degrade direction per CLAUDE.md §Instrument-Calibration: label it UNCALIBRATED, never a bare pass.
skip() { printf '  ⏭  UNCALIBRATED — %s\n' "$1"; skipped=$((skipped+1)); }

# Build a hermetic fake source tree. `git_shape` is one of: file | dir | none.
# `ship_the_doc` decides whether the referenced path is inside files[] (the known pair).
make_tree() { # make_tree <dir> <git_shape> <cover_target:yes|no> [omit_manifest]
  local d="$1" git_shape="$2" cover="$3" omit="${4:-}"
  mkdir -p "$d/scripts" "$d/docs"
  cp "$SUBJECT" "$d/scripts/package_coverage_check.sh"

  # A shipped document that points at scripts/helper.sh, and that file really exists here.
  # "exists here but absent from files[]" is exactly the defect class this check owns.
  printf 'Run `scripts/helper.sh` before the gate.\n' > "$d/docs/guide.md"
  printf '#!/usr/bin/env bash\necho helper\n' > "$d/scripts/helper.sh"

  if [ "$cover" = "yes" ]; then
    printf '{"files":["docs/guide.md","scripts/helper.sh"]}\n' > "$d/package.json"
  else
    printf '{"files":["docs/guide.md"]}\n' > "$d/package.json"
  fi
  [ -n "$omit" ] && rm -f "$d/package.json"

  case "$git_shape" in
    dir)  mkdir -p "$d/.git" ;;
    file) printf 'gitdir: /somewhere/else/.git/worktrees/x\n' > "$d/.git" ;;
    none) : ;;
  esac
}

run_tree() { bash "$1/scripts/package_coverage_check.sh" 2>&1; }
# 🟥 no more rc_tree(): it used to re-run the subject a SECOND time just to get $? (`out=$(run_tree
# ...); rc=$(rc_tree ...)` — two executions of the same script, so a nondeterministic subject could
# report an (out, rc) pair that never co-occurred in either real run). Every call site below now
# does `out=$(run_tree ...); rc=$?` — one execution, $? read off THAT command substitution.

# Assert a POSITIVE outcome, never merely the absence of the SKIP line. Cross-family review caught
# the first draft here: it checked only that `SKIP  package-coverage` was missing, so a checker that
# exited 1 on every worktree — the opposite defect, equally broken — would have passed the lane that
# exists to prove the worktree path works. "Did not say the wrong thing" is not "did the right
# thing"; a lane phrased as a negative can only ever fail one way.
# Both functions below stash their single execution's output/rc in _LAST_OUT/_LAST_RC (not `local`,
# deliberately — the caller reads them straight off the one run instead of re-invoking the subject a
# second time just to build a diagnostic string, which would be the same two-executions-for-one-
# verdict shape the L3–L7 dual-execution fix below removes).
ran_clean() { # ran_clean <dir> -> 0 iff the check actually ran AND reported a clean scan
  local d="$1"
  _LAST_OUT=$(bash "$d/scripts/package_coverage_check.sh" 2>&1); _LAST_RC=$?
  [ "$_LAST_RC" -eq 0 ] && printf '%s' "$_LAST_OUT" | grep -q 'PASS  package-coverage' \
    && ! printf '%s' "$_LAST_OUT" | grep -q 'SKIP  package-coverage'
}
caught_defect() { # caught_defect <dir> -> 0 iff the check FOUND the planted omission
  local d="$1"
  _LAST_OUT=$(bash "$d/scripts/package_coverage_check.sh" 2>&1); _LAST_RC=$?
  [ "$_LAST_RC" -eq 1 ] && printf '%s' "$_LAST_OUT" | grep -q 'scripts/helper.sh'
}
# A CLEAN LANE ALONE PROVES NOTHING ABOUT THE WORKTREE PATH. Cross-family review round 2 demonstrated
# this by EXECUTION: it replaced the subject with a mutant that printed `PASS  package-coverage`
# whenever `.git` was a file, without scanning anything — and all eight lanes passed, suite exit 0.
# The lanes proved "returned a PASS-shaped string", not "ran the coverage logic". The known-positive
# fixtures existed but only under the `.git`-is-a-DIRECTORY shape, so nothing exercised detection in
# the very shape the fix was about. Every worktree lane below is now a PAIR: the same tree must go
# clean->PASS and planted-omission->FAIL. A bypassing mutant fails the second half by construction.
wt_pair() { # wt_pair <label> <dir> <git_shape>
  local label="$1" d="$2" shape="$3"
  make_tree "$d" "$shape" yes
  if ! ran_clean "$d"; then
    bad "$label — clean leg: did not run to a PASS (rc=$_LAST_RC)" "$_LAST_OUT"; return
  fi
  make_tree "$d" "$shape" no        # identical tree, files[] no longer covers the referenced path
  if ! caught_defect "$d"; then
    bad "$label — DEFECT leg: planted omission not caught, so the clean PASS proved nothing (rc=$_LAST_RC)" "$_LAST_OUT"; return
  fi
  ok "$label"
}

# ── L1 · THE REGRESSION ANCHOR ───────────────────────────────────────────────────────
wt_pair "L1 worktree (.git is a FILE): scans for real — clean PASSes, planted omission FAILs" \
        "$TMP/l1" file

# ── L1-b · a REAL git worktree, not a hand-written pointer ───────────────────────────
# The synthetic fixture writes a gitdir pointer whose target does not exist, so it proves the
# predicate accepts "a file named .git" — not that it accepts a genuine worktree. This lane builds
# an actual repo and an actual `git worktree add`.
# ISOLATION (review round 2, LOW): the git commands run with signing off, hooks disabled, and both
# config files pointed at /dev/null, so a configured signing prompt or a global hook cannot hang the
# suite or write outside $TMP. GIT_TERMINAL_PROMPT=0 turns any credential prompt into an error.
# SKIP ACCOUNTING (review round 2, MED — confirmed by execution): the first draft printed a skip and
# incremented nothing, so a machine with a broken git reported "7 passed, 0 failed" and exited 0 —
# a lane that cannot run must not read as a lane that passed. Now: git ABSENT is a legitimate skip
# but is counted and surfaced as UNCALIBRATED in the summary; git PRESENT but setup failing is a
# FAILURE, because there the claim was testable and the test did not run.
GIT_ISO=(-c commit.gpgsign=false -c core.hooksPath=/dev/null -c user.email=a@b -c user.name=t)
# CONFIG isolation is not REPOSITORY-ROUTING isolation. Round-3 review reproduced this on Apple Git
# 2.50.1: with GIT_DIR pointing at an unrelated repo, this suite reported "8 passed, 0 failed" while
# that external repo's commit count went 0 -> 1. So the lane could pass by exercising — and WRITING
# TO — a repository that is not its fixture. A test that mutates state outside its own $TMP is not
# a test, and the green summary is the worst part: it reports calibration it did not perform.
# Every routing variable is cleared, and the resolved git-dir is then ASSERTED to live under $TMP
# rather than assumed — the unset list is a denylist and a denylist is never proof; the assertion is.
# SECOND LEAK CHANNEL, same class, found by the reviewer running the attack rather than reading for
# it: GIT_CONFIG_PARAMETERS injects config that GIT_CONFIG_GLOBAL/SYSTEM=/dev/null does NOT suppress.
# Reproduced here: with `init.templateDir` pointed at a directory whose `refs` is a symlink to an
# external dir, `git init` populated that external dir — and the suite still printed
# "8 passed, 0 failed". The git-dir assertion cannot see this one, because the git-dir DOES resolve
# inside $TMP; the escape is through the template, not the routing. So the assertion is necessary and
# not sufficient, and the config-injection channels have to be closed by name.
# `--template=` with an empty directory is the belt to that braces: even if a config channel is
# missed, init has an explicit, empty template to copy from.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_CEILING_DIRECTORIES \
      GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_TEMPLATE_DIR
export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
if ! command -v git >/dev/null 2>&1; then
  skip "L1-b real git worktree (git not installed — the on-disk layout under test cannot exist here)"
else
  mkdir -p "$TMP/realrepo"
  # BOTH SIDES NORMALIZED. First version compared the raw `mktemp -d` path against
  # `rev-parse --absolute-git-dir`, and on macOS that fails for a clean tree: mktemp hands back
  # /var/folders/... while git resolves symlinks and returns /private/var/folders/... . The
  # assertion then rejected its OWN correct fixture — a false positive on a safety check, which is
  # the same defect class as a false negative and would have trained the next reader to delete it.
  # `pwd -P` resolves the $TMP side; the other side is already physical because
  # `rev-parse --absolute-git-dir` resolves symlinks itself. The raw "$TMP"/* branch is kept as a
  # belt for platforms where it does not. (An earlier comment said "both sides normalized via
  # pwd -P" — only one side uses it.)
  _TMP_REAL="$(cd "$TMP" && pwd -P)"
  # NAME THE ORDER HONESTLY: `git init` runs FIRST and this assertion runs immediately after, so it
  # gates every subsequent write (commit, worktree add) — not the init itself. init is bounded
  # separately by the unset list plus the explicit empty --template. An earlier comment claimed
  # "before anything is written", which overstated it by one step.
  _gitdir_ok() { # the fixture repo must resolve INSIDE $TMP before anything FURTHER is written
    local r; r=$(git "${GIT_ISO[@]}" -C "$TMP/realrepo" rev-parse --absolute-git-dir 2>/dev/null) || return 1
    case "$r" in
      "$_TMP_REAL"/*|"$TMP"/*) return 0 ;;
      *) echo "  ↳ git-dir resolved OUTSIDE the fixture: $r" >&2; return 1 ;;
    esac
  }
  mkdir -p "$TMP/emptytpl"
  # The whole fixture-build chain runs as ONE group so its combined stdout+stderr lands in one
  # variable instead of /dev/null — a failed build used to report only "could not be built", with
  # no way to tell which of the four steps broke or why.
  _l1b_ok=1
  _l1b_out="$( { git "${GIT_ISO[@]}" -C "$TMP/realrepo" init -q --template="$TMP/emptytpl" . \
     && _gitdir_ok \
     && git "${GIT_ISO[@]}" -C "$TMP/realrepo" commit -q --allow-empty -m init \
     && git "${GIT_ISO[@]}" -C "$TMP/realrepo" worktree add -q --detach "$TMP/realwt" \
     && [ -f "$TMP/realwt/.git" ]; } 2>&1 )" || _l1b_ok=0
  if [ "$_l1b_ok" -eq 1 ]; then
    wt_pair "L1-b real \`git worktree add\` (.git is a genuine gitdir pointer): scans for real" \
            "$TMP/realwt" none          # the REAL .git file is already in place; do not overwrite it
  else
    bad "L1-b git IS installed but the real-worktree fixture could not be built — the claim was testable and was not tested" "$_l1b_out"
  fi
fi

# ── L2 · ordinary checkout keeps working ─────────────────────────────────────────────
wt_pair "L2 ordinary checkout (.git is a DIR): scans for real — both legs" "$TMP/l2" dir

# ── L3 · package mode must STILL skip ────────────────────────────────────────────────
# The widening from -d to -e must not cost the legitimate skip. An installed npm package has no
# .git of either kind; making it fail there would fire on every consumer running `npm test`.
make_tree "$TMP/l3" none yes
out=$(run_tree "$TMP/l3"); rc=$?
if printf '%s' "$out" | grep -q 'SKIP  package-coverage' && [ "$rc" -eq 0 ]; then
  ok "L3 package mode (no .git): still skips, exit 0"
else
  bad "L3 package mode (no .git): expected SKIP+0, got rc=$rc" "$out"
fi

# ── L4 · a checkout with no manifest is UNMEASURED, not clean ────────────────────────
# EXPECTATION CORRECTED by cross-family review, 2026-07-31. The first draft asserted SKIP+0 here
# and would have ANCHORED a fail-open: inside a checkout, a missing package.json means the shipped
# file list cannot be read, which is "cannot measure", not "nothing to measure". An anchor that
# pins the wrong direction is worse than no anchor — it makes the hole look deliberate.
make_tree "$TMP/l4" dir yes omit
out=$(run_tree "$TMP/l4"); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'UNMEASURED, not clean'; then
  ok "L4 .git present but no package.json: FAILS as unmeasured, not a clean skip"
else
  bad "L4 no package.json: expected exit 1 (unmeasured), got rc=$rc" "$out"
fi

# ── L5/L6 · KNOWN PAIR ───────────────────────────────────────────────────────────────
# Same tree twice; the ONLY difference is whether files[] covers the referenced path.
# L5 known-POSITIVE: referenced, exists, not shipped -> must FAIL.
make_tree "$TMP/l5" dir no
out=$(run_tree "$TMP/l5"); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'scripts/helper.sh'; then
  ok "L5 known-positive (referenced ∧ exists ∧ ¬shipped): FAIL, names the path"
else
  bad "L5 known-positive: expected exit 1 naming scripts/helper.sh, got rc=$rc" "$out"
fi

# L6 known-NEGATIVE: identical, but the path is in files[] -> must PASS.
make_tree "$TMP/l6" dir yes
out=$(run_tree "$TMP/l6"); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'PASS  package-coverage'; then
  ok "L6 known-negative (same tree, path shipped): PASS"
else
  bad "L6 known-negative: expected exit 0 PASS, got rc=$rc" "$out"
fi

# ── L7 · the impossible-zero guard is not reachable by an empty files[] ──────────────
# A manifest with no shipped docs must report the extractor as broken, not print a pass.
mkdir -p "$TMP/l7/scripts"; cp "$SUBJECT" "$TMP/l7/scripts/"; mkdir -p "$TMP/l7/.git"
printf '{"files":[]}\n' > "$TMP/l7/package.json"
out=$(run_tree "$TMP/l7"); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'the check broke, it did not pass'; then
  ok "L7 zero shipped docs: reported as broken extractor, not as a pass"
else
  bad "L7 zero shipped docs: expected exit 1 'check broke', got rc=$rc" "$out"
fi

echo
if [ "$skipped" -gt 0 ]; then
  echo "package-coverage lanes: ${pass} passed, ${fail} failed, ${skipped} UNCALIBRATED (not verified here)"
else
  
# ── lane 7: tarball oracle JSON without files[] → text-listing fallback (CI 2026-09-04, v3.0.0) ──
# Known-pair: stub npm returns JSON lacking files[] but delegates the text `pack --dry-run` to the
# real npm → PASS (7a). Stub returns the same JSON and an EMPTY text listing → ORACLE_UNAVAILABLE rc=2 (7b).
cd "$REPO_ROOT" || exit 10; _REAL_NPM=$(command -v npm); _ST=$(mktemp -d)   # earlier lanes cd into fixtures — the subject reads .git/package.json from cwd
printf '#!/bin/bash\nif [ "$*" = "pack --dry-run --json" ]; then echo "[{\\"id\\":\\"x\\"}]"; else exec %s "$@"; fi\n' "$_REAL_NPM" > "$_ST/npm"; chmod +x "$_ST/npm"
o=$(PATH="$_ST:$PATH" bash "$SUBJECT" --vs-tarball 2>&1); rc=$?
if [ "$rc" = 0 ] && printf '%s' "$o" | grep -q "^PASS  package-coverage"; then echo "  ✅ lane 7a: JSON without files[] → text listing fallback PASSes"; pass=$((pass+1)); else echo "  ❌ lane 7a: fallback did not PASS (rc=$rc)"; printf "%s\n" "$o" | grep -E "UNAVAILABLE|head:" | cut -c1-220; fail=$((fail+1)); fi
printf '#!/bin/bash\nif [ "$*" = "pack --dry-run --json" ]; then echo "[{\\"id\\":\\"x\\"}]"; elif [ "$*" = "pack --dry-run" ]; then exit 0; else exec %s "$@"; fi\n' "$_REAL_NPM" > "$_ST/npm"
o=$(PATH="$_ST:$PATH" bash "$SUBJECT" --vs-tarball 2>&1); rc=$?
if [ "$rc" = 2 ] && printf '%s' "$o" | grep -q "UNAVAILABLE"; then echo "  ✅ lane 7b: JSON without files[] AND empty text listing → UNAVAILABLE rc=2 (fail-closed)"; pass=$((pass+1)); else echo "  ❌ lane 7b: expected rc=2 UNAVAILABLE, got rc=$rc"; fail=$((fail+1)); fi
rm -rf "$_ST"
echo "package-coverage lanes: ${pass} passed, ${fail} failed"
fi
[ "$fail" -eq 0 ] || exit 1
