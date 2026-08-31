#!/usr/bin/env bash
# test_prepush_destructive_liveness.sh — the CONTROL for scripts/test_prepush_destructive_lanes.sh.
#
# ── WHAT THIS ANSWERS THAT THE SUITE CANNOT ANSWER ABOUT ITSELF ──────────────────────────────
# A green lane suite has two possible causes: the gate is healthy, or the suite stopped testing
# anything. In a log those are byte-identical, and the second is how an anchor becomes decorative
# (CLAUDE.md / [[feedback_anchor_can_be_decorative]]: "되돌려도 초록"). Presence of a control is
# not discrimination — the question is whether the suite is CAPABLE of going red, and the only way
# to know is to break the gate on purpose and watch.
#
# So: disable one guard ON A COPY, re-run the suite against that copy, and require it to go red on
# the SPECIFIC lane that guard backs. Red-for-any-reason is not enough — a suite that dies from a
# missing dependency is also non-zero and would satisfy a bare exit-code check while proving
# nothing ([[feedback_gate_verification_must_execute]]: "막혔다"≠"옳게 막혔다").
#
# ── WHY A COPY ───────────────────────────────────────────────────────────────────────────────
# The real tree is never touched. This repo is a SHARED CHECKOUT (CLAUDE.md §병렬세션): mutating a
# tracked file here, even with an intended restore, puts another session's worktree at risk and can
# be swallowed into someone else's commit. Copy-mutate-discard has no restore step to forget.
#
# Seven stages, in order, each of which can fail the probe on its own:
#   ① APPLY  — verify the mutation actually landed (an unapplied mutation makes "still green" mean
#              nothing, which is the failure mode this whole file exists to name)
#   ② RUN    — the suite must exit non-zero AND name the expected lane
#   ③ DISCARD— drop the copy
#   ④ PORTABILITY  — the suite must still be GREEN under a git that has no `init -b` (< 2.28)
#   ⑤ SETUP-LOUDNESS — when the fixture cannot be built at all, the suite must abort with
#              HARNESS_ERROR and score ZERO lanes, never grade the real tree
#   ⑥ ORPHAN   — templates/predelete_check.test.sh still has a REACHABLE executing runner (no other
#              detector can see that file — it is outside lane_runner_check.sh's glob). The counter
#              carries its own known pairs (⑥-cal): one per surface (.yml · .yaml · package.json)
#              and one per reachability rule (manual-only trigger · `if: false` · comment-only ·
#              `on:`-scope). 🟥 It is a COMMON-FORM MATCHER, not a YAML/shell semantics analyzer —
#              what it does and does not catch is enumerated at §NAMED LIMITS above count_execs,
#              and unrecognised shapes fold to NOT-reachable (the loud direction) on purpose
#   ⑦ CONTAINMENT — running the suite leaves the REAL repository byte-identical
#
# ④–⑦ were added 2026-08-22 as the regression anchors for that day's repairs, and they live here
# rather than in the suite because each is a question ABOUT the suite ("is it still runnable · is
# it honest when it cannot run · is its subject still wired · does it stay inside its sandbox")
# which a suite cannot ask about itself.
#
# Portability, stated because the suite it controls claims "git + coreutils only" and this file does
# NOT: stage ① uses `python3` for the mutation (already a de-facto dependency here —
# scripts/selfcheck.sh, scripts/lane_runner_check.sh and scripts/residency_closure_scan.py all need
# it; re-grounded 2026-08-22 R3 against TRACKED files only, because the first draft cited a sibling
# script from an unlanded branch and would have shipped a phantom reference) and stage ⑦'s diff uses bash
# process substitution. Named rather than assumed; if python3 is absent, stage ① fails LOUDLY
# ("LIVENESS PROBE INVALID") and never reports "still green".
#
# Usage: bash scripts/test_prepush_destructive_liveness.sh   → exit 0 anchor is live, 1 otherwise.
set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HOOK="$REPO_ROOT/templates/.git-hooks/pre-push"
SUITE="$REPO_ROOT/scripts/test_prepush_destructive_lanes.sh"

for f in "$HOOK" "$SUITE"; do
  [ -f "$f" ] || { echo "HARNESS_ERROR — missing: $f (absent instrument is NOT a pass)"; exit 1; }
done

# ── CONTAINMENT BASELINE — taken BEFORE any suite is run (see stage ⑦ for why the position is the
# check). Every invocation this probe makes is inside the window it covers.
git_state() {   # $1 = root to snapshot (default: the real repo)
  local r="${1:-$REPO_ROOT}"
  git -C "$r" status --porcelain 2>&1
  echo "--HEAD--";     git -C "$r" rev-parse HEAD 2>&1
  echo "--SYMREF--";   git -C "$r" symbolic-ref -q HEAD 2>&1
  echo "--BRANCHES--"; git -C "$r" for-each-ref --format='%(refname) %(objectname)' refs/heads 2>&1
  echo "--TAGS--";     git -C "$r" for-each-ref --format='%(refname) %(objectname)' refs/tags 2>&1
  echo "--STAGED--";   git -C "$r" diff --cached --name-status 2>&1
}
# Not a git work tree (an unpacked tarball, a consumer's node_modules) → stage ⑦ has nothing to
# compare and every snapshot would be the same error text: equal, green, and meaningless. Say so
# rather than banking a vacuous pass — `not found` is not `0`.
CONTAINMENT=on
git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || CONTAINMENT=skip
_before=$(git_state)
# Known-positive control for the COMPARATOR: an empty or constant snapshot would match anything and
# make stage ⑦ green by construction. Presence of a control is not discrimination unless it can fail.
if [ "$CONTAINMENT" = "on" ]; then
if [ -z "$_before" ] || [ "$_before" = "$(printf -- '--HEAD--\n--SYMREF--\n--BRANCHES--\n--TAGS--\n--STAGED--')" ]; then
  echo "❌ CONTAINMENT CONTROL INVALID — git-state snapshot is empty/degenerate; it would match anything."
  exit 1
fi
  # 🟥 THE DISCRIMINATION HALF, and the first version of it was a TAUTOLOGY (found 2026-08-22 R2).
  # It read `[ "$_before" = "${_before}"$'\n'"?? planted_control_entry" ]` — a string compared to
  # ITSELF PLUS A SUFFIX. That is false for every possible input (proved: 1000 random strings, 0
  # fires; control: an ordinary equality test does fire), so the branch was unreachable and the
  # "comparator can distinguish two states" claim was never actually measured. A control that
  # cannot fail is decorative, which is the exact defect this whole file exists to name
  # ([[feedback_anchor_can_be_decorative]] · [[feedback_control_presence_is_not_discrimination]]).
  #
  # The replacement is a genuine known pair: snapshot a DIFFERENT repository and require the two
  # snapshots to differ. If git_state ever degrades into a constant (a hardcoded root, a swallowed
  # error path), this fires. Building the probe repo is itself fail-closed — an unbuildable control
  # is HARNESS_ERROR, never a silent skip.
  _cmpdir=$(mktemp -d) || { echo "❌ CONTAINMENT CONTROL — cannot mktemp; NOT a pass"; exit 1; }
  if ! git -C "$_cmpdir" init -q >/dev/null 2>&1; then
    rm -rf "$_cmpdir"
    echo "❌ CONTAINMENT CONTROL — could not build the comparison repo; discrimination UNPROVEN (not a pass)"
    exit 1
  fi
  _othersnap=$(git_state "$_cmpdir")
  rm -rf "$_cmpdir"
  if [ "$_before" = "$_othersnap" ]; then
    echo "❌ CONTAINMENT CONTROL INVALID — two DIFFERENT repositories produce the same snapshot."
    echo "   git_state is returning a constant, so stage ⑦ would be green by construction."
    exit 1
  fi
fi

# The guard being disabled, and the lane that backs it. Kept as a pair on purpose: a probe that
# mutates one thing and asserts another is a probe that cannot fail honestly.
GUARD_LINE='if [ "$r" = "refs/heads/${BASE_BRANCH}" ] || [ "$r" = "refs/heads/master" ] || [ "$r" = "refs/heads/main" ]; then'
EXPECT_LANE='P4 delete INTEGRATION branch'

C=$(mktemp -d) || exit 1
trap 'rm -rf "$C"' EXIT   # ③ DISCARD — unconditional, including on an early exit
mkdir -p "$C/templates/.git-hooks" "$C/.claude/rules" "$C/scripts"
cp "$HOOK" "$C/templates/.git-hooks/pre-push"
[ -f "$REPO_ROOT/.claude/rules/.public-surface-patterns.defaults" ] \
  && cp "$REPO_ROOT/.claude/rules/.public-surface-patterns.defaults" "$C/.claude/rules/"
[ -f "$REPO_ROOT/scripts/psa_scan_lib.sh" ] && cp "$REPO_ROOT/scripts/psa_scan_lib.sh" "$C/scripts/"

# ── ① APPLY ──────────────────────────────────────────────────────────────────────────────────
# Disabling the integration-branch PROTECTED check makes deleting `main` trivially "merged into
# itself" (n=0, uniq=0), so it auto-passes the SAFE branch. A FAIL-OPEN — the direction that
# matters, and the most dangerous auto-pass in the block.
GUARD_LINE="$GUARD_LINE" python3 - "$C/templates/.git-hooks/pre-push" <<'PY'
import os, sys
path = sys.argv[1]
src = open(path).read()
old = os.environ['GUARD_LINE']
if old not in src:
    sys.stderr.write("mutation target not found — the guard was reworded\n")
    sys.exit(3)
open(path, 'w').write(src.replace(old, 'if false; then', 1))
PY
mrc=$?

if [ "$mrc" -ne 0 ]; then
  echo "❌ LIVENESS PROBE INVALID — could not apply the mutation (rc=$mrc)."
  echo "   The PROTECTED guard in templates/.git-hooks/pre-push was reworded."
  echo "   Re-point GUARD_LINE in this file at the current wording. Do NOT delete this probe:"
  echo "   a probe that cannot apply its mutation must fail loudly, never report 'still green'."
  exit 1
fi
if cmp -s "$HOOK" "$C/templates/.git-hooks/pre-push"; then
  echo "❌ LIVENESS PROBE INVALID — the copy is byte-identical after mutation."
  exit 1
fi
echo "① mutation applied to the copy (PROTECTED guard disabled); real tree untouched"

# ── ② RUN ────────────────────────────────────────────────────────────────────────────────────
out=$(FH_TEST_SUBJECT_ROOT="$C" bash "$SUITE" 2>&1); rc=$?

if [ "$rc" -eq 0 ]; then
  echo "❌ DECORATIVE ANCHOR — the gate was disabled and the suite still PASSED."
  echo "   Every green run of test_prepush_destructive_lanes.sh certifies nothing."
  printf '%s\n' "$out" | sed 's/^/   | /'
  exit 1
fi
if ! printf '%s' "$out" | grep -qF "$EXPECT_LANE"; then
  echo "❌ Suite went red, but NOT on the expected lane ($EXPECT_LANE)."
  echo "   It failed for an unrelated reason, so liveness is UNPROVEN — not established, not refuted."
  printf '%s\n' "$out" | sed 's/^/   | /'
  exit 1
fi

# Precision: disabling ONE guard should redden ONE lane. A mutation that reddens many means the
# lanes are entangled and none of them isolates what it claims to.
reds=$(printf '%s\n' "$out" | grep -c '❌')
echo "② suite went red on cue — reddened lanes: $reds"
printf '%s\n' "$out" | grep -E '❌|캘리브레이션' | sed 's/^/   /'
if [ "$reds" -ne 1 ]; then
  echo "⚠️  expected exactly 1 reddened lane, got $reds — lanes may not be isolating what they name."
  exit 1
fi

echo ""

# ── ④ PORTABILITY CONTROL ────────────────────────────────────────────────────────────────────
# Regression anchor for the 2026-08-22 `git init -b main` repair. `-b` needs git >= 2.28; anything
# older rejects it outright ("unknown switch `b'", rc 129) and the fixture never gets built. The
# runner image and the operator's macOS both ship a new git, so NOTHING here would notice the
# reintroduction — which is precisely why it survived review the first time.
#
# The shim is a targeted reproduction, not a whole old git: it removes the ONE switch whose absence
# defines git < 2.28 and passes everything else through. Named scope: it does not reproduce other
# 2.28-era differences, and `git --version` still reports the real version.
#
# 🟥 WHAT THAT UNMEASURED SCOPE DOES AND DOES NOT AFFECT (adjudicated 2026-08-22 R2, because an
# unqualified "partial reproduction" reads as "the repair might be wrong", and it is not):
#   • It does NOT affect the repair's justification. The repair swapped `git init -b main` for
#     `git init` + `git symbolic-ref HEAD refs/heads/main`. Its correctness needs only that the
#     replacement predates 2.28 — `symbolic-ref` and `update-ref` are 1.x-era plumbing — and that
#     `-b` is genuinely the breaking switch, which the shim's own known pair measures directly.
#   • It DOES bound what stage ④ can claim. ④ proves "no dependency on `init -b`", not "runs on
#     git 2.27". Enumerated rather than assumed: every git call in the lanes suite is
#     add · branch · checkout (incl. --detach, 1.7.5) · commit · config · init -q · rev-parse
#     (incl. --show-toplevel, 1.7.x) · symbolic-ref · tag · update-ref — all pre-2.28, so the
#     residual is a coverage limit on the CONTROL, not an open question about the SUBJECT.
#   • Closing it properly needs a real old git (a container with 2.27), which is a CI decision, not
#     something a shim can fake. Recorded as a named limit; not claimed closed.
SHIM=$(mktemp -d) || exit 1
trap 'rm -rf "$C" "$SHIM"' EXIT
REALGIT=$(command -v git) || { echo "HARNESS_ERROR — no git on PATH"; exit 1; }
cat > "$SHIM/git" <<EOF
#!/bin/bash
if [ "\${1:-}" = "init" ]; then
  for a in "\$@"; do
    case "\$a" in
      -b|--initial-branch|--initial-branch=*)
        echo "error: unknown switch \\\`b'" >&2; exit 129 ;;
    esac
  done
fi
exec "$REALGIT" "\$@"
EOF
chmod +x "$SHIM/git"

# Known pair for the SHIM ITSELF. A shim that silently stopped intercepting would make stage ④ a
# guaranteed green that measures nothing — the decorative-anchor failure, one level down.
_kn=$(mktemp -d); ( cd "$_kn" && PATH="$SHIM:$PATH" git init -q . ) >/dev/null 2>&1; _knrc=$?
_kp=$(mktemp -d); ( cd "$_kp" && PATH="$SHIM:$PATH" git init -q -b main . ) >/dev/null 2>&1; _kprc=$?
rm -rf "$_kn" "$_kp"
if [ "$_knrc" -ne 0 ] || [ "$_kprc" -eq 0 ]; then
  echo "❌ PORTABILITY CONTROL INVALID — shim does not discriminate"
  echo "   known-negative (plain \`git init\`) rc=$_knrc (want 0); known-positive (\`init -b\`) rc=$_kprc (want ≠0)"
  exit 1
fi

pout=$(PATH="$SHIM:$PATH" bash "$SUITE" 2>&1); prc=$?
if [ "$prc" -ne 0 ]; then
  echo "❌ PORTABILITY REGRESSION — the suite does not run on git < 2.28 (rc=$prc)."
  echo "   Build fixtures with \`git init\` + \`git symbolic-ref HEAD refs/heads/main\`, never \`init -b\`."
  printf '%s\n' "$pout" | grep -E '❌|HARNESS_ERROR|unknown switch|캘리브레이션' | sed 's/^/   | /' | head -10
  exit 1
fi
echo "④ portability: suite is GREEN under a git with no \`init -b\` — $(printf '%s' "$pout" | grep -c '✅') lanes"

# ── ⑤ SETUP-LOUDNESS CONTROL ─────────────────────────────────────────────────────────────────
# Regression anchor for the 2026-08-22 fail-open repair. `cd ""` is a NO-OP SUCCESS in bash, so a
# fixture that failed to build left an empty path that redirected every lane into the CURRENT
# directory — the real shared checkout. Measured pre-fix: 6 lanes scored ✅ off the operator's own
# tree, and the run created branches, a tag and an index entry there.
#
# The assertion is deliberately THREE-part. rc≠0 alone is not enough: the pre-fix suite ALSO
# exited 1 (some lanes failed). What distinguishes honest from fail-open is that zero lanes were
# scored and the abort is named. ([[feedback_gate_verification_must_execute]]: "막혔다"≠"옳게 막혔다".)
DEAD=$(mktemp -d) || exit 1
trap 'rm -rf "$C" "$SHIM" "$DEAD"' EXIT
cat > "$DEAD/git" <<EOF
#!/bin/bash
if [ "\${1:-}" = "init" ]; then echo "fatal: simulated init failure" >&2; exit 1; fi
exec "$REALGIT" "\$@"
EOF
chmod +x "$DEAD/git"

sout=$(PATH="$DEAD:$PATH" bash "$SUITE" 2>&1); src=$?
sgreen=$(printf '%s\n' "$sout" | grep -c '✅')
if [ "$src" -eq 0 ]; then
  echo "❌ SETUP FAIL-OPEN — no fixture could be built and the suite still exited 0."; exit 1
fi
if ! printf '%s' "$sout" | grep -qF 'HARNESS_ERROR — fixture repo not built'; then
  echo "❌ SETUP FAILURE IS UNNAMED — the suite went red without saying the fixture never built."
  echo "   An unnamed red is indistinguishable from a real finding, and the next reader 'fixes' the gate."
  printf '%s\n' "$sout" | tail -8 | sed 's/^/   | /'; exit 1
fi
if [ "$sgreen" -ne 0 ]; then
  echo "❌ FAIL-OPEN — $sgreen lane(s) scored ✅ with NO fixture repo. Those lanes graded the REAL tree."
  printf '%s\n' "$sout" | grep '✅' | sed 's/^/   | /' | head -8; exit 1
fi
echo "⑤ setup-loudness: unbuildable fixture → rc=$src, named HARNESS_ERROR, 0 lanes scored"


# ── ⑥ ORPHAN CONTROL — templates/predelete_check.test.sh ─────────────────────────────────────
# The other two anchors in this family are `scripts/test_*.sh`, so scripts/lane_runner_check.sh
# already covers them: it globs scripts/*.sh as suites and .github/workflows/*.yml as a caller
# surface (lane_runner_check.sh:291), and selfcheck.sh:488 runs it inside the required `validate`
# check. Delete their workflow and `validate` goes red. That is a real backstop.
#
# templates/predelete_check.test.sh has NO such backstop. It is `templates/*.test.sh`, outside the
# lane-runner's `scripts/*.sh` field of view — measured: the lane-runner reports 66 suites, 66
# wired, and never names this file. So the moment whatever executes it goes away, it returns to
# being executed by nothing, and the detector reports 66/66 the whole time. A detector that is
# silent about the file it cannot see is exactly [[feedback_built_but_not_wired]] with the alarm
# disconnected — so the alarm is wired here instead, in a file the lane-runner DOES watch.
SUBJ_ORPHAN="templates/predelete_check.test.sh"
if [ ! -f "$REPO_ROOT/$SUBJ_ORPHAN" ]; then
  echo "❌ ORPHAN CONTROL — subject missing: $SUBJ_ORPHAN (absent is not a pass)"; exit 1
fi

# Count REACHABLE EXECUTING callers — not mentions, and not text in something that never runs.
# A comment naming the path is how this file was described as wired while nothing ran it; the
# pattern therefore requires an invocation form and drops comment lines.
#
# 🟥 The SURFACE LIST is the part that has been wrong, and it was wrong in a direction that produces
# a FALSE ORPHAN (over-block), not a false pass. Two repairs, both 2026-08-22 R2:
#   • `.yaml` — GitHub executes BOTH `.github/workflows/*.yml` AND `*.yaml`. Renaming
#     destructive-op-anchor.yml to .yaml would leave the runner fully live in CI while this stage
#     reported ORPHANED. Measured: no `.yaml` exists in .github today, so nothing here would have
#     noticed — the same "the runner image happens to agree with me" blindness that let `init -b`
#     through in stage ④.
#   • `package.json` — `npm test` / `prepublishOnly` are real executing surfaces; a suite wired
#     only from there was invisible. Verified NOT to false-positive on the `files[]` entry for this
#     very path (files[] has no `bash `/`sh ` prefix, so the exec pattern does not match it).
# Named residual (unclosed, measured): `bin/*.js` is NOT in the list — probed, and no file there
# executes a shell suite today (`grep -nE 'bash '` over bin/*.js → 0 hits, control: the same grep
# hits in scripts/*.sh). If a JS entrypoint ever shells out to a suite, this list is short again.
#
# 🟥 REACHABILITY (ⓒ) — presence of the invocation text is not execution. A workflow triggered only
# by `workflow_dispatch`, or whose step is `if: false`, contains the exact line and runs never. That
# is [[feedback_not_found_is_not_zero_family]] inverted: a DEAD path rendered as EXECUTED. Workflow
# files therefore additionally require a push/pull_request trigger and no `if: false`.
#
# 🟥 WHAT THIS COUNTER CLAIMS, STATED NARROWLY (rewritten 2026-08-22 R3 after a codex reproduction).
# It is a COMMON-FORM MATCHER, not a YAML/shell semantics analyzer, and it never claimed to be one
# without leaking. The R2 wording called both tests "file-scoped greps … coarse on purpose", which
# reads as one accepted imprecision; measuring it showed the coarseness ran in BOTH directions at
# once, and one of those directions is unsafe:
#   • UNSAFE (fixed) — the trigger test matched any indented `push:` ANYWHERE in the file, so a
#     manual-only workflow with `env:\n  push: not-a-trigger` was counted REACHABLE. A dead runner
#     certified as live is a green ⑥ over a returned orphan, which is the one outcome this stage
#     exists to prevent. Measured pre-fix: fixture `envpush` → 1 (want 0).
#   • OVER-BLOCK (also fixed, because it was silent) — that same colon-anchored pattern REJECTED
#     `on: push` and `on: [push, pull_request]`, the two ordinary inline spellings. Measured
#     pre-fix: `onscalar` → 0 and `oninline` → 0 (want 1 each). Nobody would have noticed until a
#     rename of the real runner's trigger style turned ⑥ red for a reason that is not a finding.
#
# The replacement is a purpose-built `on:`-BLOCK EXTRACTOR, not a YAML parser — deliberately, since
# a parser is both a dependency this suite does not have and the scope R3 judged too large. It
# recognises exactly one YAML structure: a top-level key ends where the next column-0 key begins.
# That is enough, and the reason it is enough is specific rather than optimistic: the whole defect
# class here is "a `push:` token that belongs to some OTHER top-level key", and top-level key
# boundaries are the minimum structure that separates those. Anything finer (anchors, merge keys,
# multi-line flow scalars spanning column 0) is out of scope and folds the safe way, below.
#
# 🟥 DEGRADE DIRECTION, FIXED AND EXPLICIT — when the shape is not recognised, fold to NOT REACHABLE.
# The two errors are not symmetric: an undercount makes ⑥ print "❌ ORPHANED" (loud, red, a human
# looks at a file that is in fact fine), while an overcount makes ⑥ print a green line while nothing
# executes the subject (silent, and indistinguishable from health — [[feedback_not_found_is_not_zero_family]]).
# One is a wasted five minutes; the other is the anchor this stage guards going missing without a
# sound. So: no `on:` block found · an unrecognised trigger spelling · a `push:` nested deeper than a
# direct child of `on:` → all count as NOT reachable. The over-block twins (`oninline` · `onscalar` ·
# `onquoted`) exist so that this bias is measured rather than allowed to drift into blocking
# everything ([[feedback_overblock_traded_for_failopen]]).
#
# 🟥 NAMED LIMITS — what this counter does NOT catch (it is a matcher; these need real semantics):
#   • `if: false` is still FILE-scoped, not step-scoped: an `if: false` on an unrelated step
#     disqualifies the whole file. Left as-is on purpose — that is the over-block direction.
#   • Only the literal `false` is recognised. `if: ${{ false }}`, `if: github.event_name == 'never'`,
#     or a job-level `if:` are not modelled; a step guarded that way counts as reachable (overcount).
#   • A `paths:`/`branches:` filter that can never match is not modelled — such a workflow counts as
#     reachable.
#   • Shell dead code counts: `if false; then bash …; fi`, or an invocation inside a function that
#     is never called, is an executing runner as far as this counter is concerned.
#   • A `jobs:`-level `if:`, a `needs:` chain that can never satisfy, and reusable-workflow
#     (`workflow_call`) indirection are all unmodelled.
#   • In the OVER-BLOCK direction (loud, so accepted rather than fixed): only `push`/`pull_request`
#     count as triggers. A runner reached solely by `schedule:`, `release:`, `workflow_run:` or
#     `workflow_call:` really does execute and would be reported ORPHANED. Measured, not assumed —
#     a `schedule:`-only fixture reads `dead` here. Widening the set is a one-line change IF such a
#     runner ever exists; today none does, and every added trigger widens the unsafe direction too.
#   The only thing that truly settles reachability is EXECUTING the runner and watching the subject
#   run, which is what CI's 'Anchor 3/3' step does; ⑥ guards that step's existence, it does not
#   replace it ([[feedback_gate_binding_point_not_check_point]]).

# Extract the top-level `on:` block: the `on:` line itself (so inline forms `on: push` and
# `on: [push, …]` are visible) plus every following line until the next column-0 key. Handles the
# YAML-1.1 quoting workarounds (`"on":` / `'on':`) that exist because bare `on` is a boolean there.
_on_block() {   # $1 = workflow file
  awk '
    /^[[:space:]]*#/ { next }
    /^[^[:space:]#]/ {
      if ($0 ~ /^("on"|'"'"'on'"'"'|on)[[:space:]]*:/) { inblk = 1; print; next }
      inblk = 0; next
    }
    inblk { print }
  ' "$1"
}

# Reachable iff the `on:` block names push/pull_request as a TRIGGER — either inline on the `on:`
# line, or as a direct child key. The 1–4 space band is the direct-child depth for both 2-space and
# 4-space styles; anything deeper is a descendant of some other trigger (a `workflow_dispatch`
# input named `push`, fixture `ondeep`) and folds to not-reachable per the degrade rule above.
_wf_triggered() {   # $1 = workflow file → rc 0 if reachable
  local blk head rhs
  blk=$(_on_block "$1")
  [ -n "$blk" ] || return 1                                   # no on: block → not reachable
  # (a) inline forms — everything to the right of the `on:` colon, e.g. `on: push`,
  #     `on: [push, pull_request]`. Empty rhs = block form, which falls through to (b).
  head=$(printf '%s\n' "$blk" | head -1)
  rhs=${head#*:}
  case "$rhs" in
    *push*|*pull_request*) return 0 ;;
  esac
  # (b) block form — a DIRECT child key of `on:`.
  printf '%s\n' "$blk" | grep -qE '^[[:space:]]{1,4}(push|pull_request):([[:space:]]|$)'
}

count_execs() {  # $1 = path to look for; $2 = root to scan (default: the real repo)
  local n=0 f root="${2:-$REPO_ROOT}"
  for f in "$root"/scripts/*.sh "$root"/.github/workflows/*.yml "$root"/.github/workflows/*.yaml \
           "$root"/templates/.git-hooks/* "$root"/package.json; do
    [ -f "$f" ] || continue
    case "$f" in *"$(basename "$0")") continue ;; esac   # this probe's own mention is not a runner
    grep -vE '^[[:space:]]*#' "$f" 2>/dev/null \
      | grep -qE "(bash|sh|\./)[[:space:]]+[^[:space:]]*$1" || continue
    case "$f" in
      *.yml|*.yaml)
        _wf_triggered "$f" || continue        # manual-only / unrecognised `on:` → not reachable
        # `- if: false` (the step-list form) is the spelling that actually occurs; anchoring on
        # `^[[:space:]]*if:` alone missed it and the ⑥-cal lane caught that while writing this
        # ([[feedback_fixture_must_use_the_breaking_spelling]]).
        grep -qE '^[[:space:]]*-?[[:space:]]*if:[[:space:]]*false[[:space:]]*$' "$f" && continue
        ;;
    esac
    n=$((n+1))
  done
  printf '%s' "$n"
}

# ── ⑥-cal — KNOWN PAIRS FOR count_execs ITSELF, on purpose-built fixtures ────────────────────
# The single control below ("a path nobody executes scores 0") measures only that the counter is
# not stuck-on. It cannot see a counter that is stuck-OFF for a whole surface, which is exactly the
# `.yaml` defect: presence of a control is not discrimination
# ([[feedback_control_presence_is_not_discrimination]]). These lanes give each surface and each
# reachability rule its own known-positive AND known-negative.
_CALROOT=$(mktemp -d) || exit 1
trap 'rm -rf "$C" "$SHIM" "$DEAD" "$_CALROOT"' EXIT
_calfix() {  # $1 = subdir, $2 = relative file to create, $3 = contents
  mkdir -p "$_CALROOT/$1/$(dirname "$2")" || return 1
  printf '%s\n' "$3" > "$_CALROOT/$1/$2"
}
_WF_LIVE='on:
  push:
    branches: ["**"]
jobs:
  j:
    steps:
      - run: bash templates/predelete_check.test.sh'

_calfix yml    .github/workflows/a.yml  "$_WF_LIVE"
_calfix yaml   .github/workflows/a.yaml "$_WF_LIVE"          # B — the twin GitHub also executes
_calfix none   README.md                'no runner here'      # known-negative
_calfix pkg    package.json             '{ "scripts": { "test": "bash templates/predelete_check.test.sh" } }'
# The three reachability fixtures are deliberately `.yml`, NOT `.yaml`: on `.yaml` they would be
# green under the pre-repair counter too — for the wrong reason (that surface was invisible), which
# makes the lane unable to attribute its own result. Measured while writing this: the first draft
# used .yaml and the fail-before probe showed manual/iffalse "passing" with reachability removed.
_calfix manual .github/workflows/a.yml 'on:
  workflow_dispatch:
jobs:
  j:
    steps:
      - run: bash templates/predelete_check.test.sh'
_calfix iffalse .github/workflows/a.yml 'on:
  push:
    branches: ["**"]
jobs:
  j:
    steps:
      - if: false
        run: bash templates/predelete_check.test.sh'
_calfix mention .github/workflows/a.yml 'on:
  push:
    branches: ["**"]
jobs:
  j:
    steps:
      # bash templates/predelete_check.test.sh   <- a comment, not a runner
      - run: echo templates/predelete_check.test.sh'
# 🟥 THE `on:`-SCOPE PAIR (added 2026-08-22 R3, from a codex reproduction). The trigger test used
# to be FILE-scoped: any indented `push:` anywhere in the file satisfied it. `envpush` is that
# reproduction — a manual-only workflow with an unrelated `push:` key under `env:` — and it was
# counted as REACHABLE, i.e. a dead runner certified as live. That is the unsafe direction (a green
# ⑥ while the orphan is back), which is why it is fixed rather than named as a residual.
# The three positives beside it are the OVER-BLOCK twins: tightening the scope must not turn the
# legitimate `on:` spellings into false ORPHANs ([[feedback_overblock_traded_for_failopen]]).
_calfix envpush .github/workflows/a.yml 'on:
  workflow_dispatch:
env:
  push: not-a-trigger
jobs:
  j:
    steps:
      - run: bash templates/predelete_check.test.sh'
_calfix oninline .github/workflows/a.yml 'on: [push, pull_request]
jobs:
  j:
    steps:
      - run: bash templates/predelete_check.test.sh'
_calfix onscalar .github/workflows/a.yml 'on: push
jobs:
  j:
    steps:
      - run: bash templates/predelete_check.test.sh'
_calfix onquoted .github/workflows/a.yml '"on":
  pull_request:
    branches: [main]
jobs:
  j:
    steps:
      - run: bash templates/predelete_check.test.sh'
# Not a trigger, and NOT the same shape as `envpush`: here the `push:` key lives INSIDE the `on:`
# block but as a deep descendant (a workflow_dispatch input name), so block-extraction alone does
# not reject it — only the direct-child depth band does. Separate lane because it fails for a
# different reason ([[feedback_candidate_list_completeness]]).
_calfix ondeep .github/workflows/a.yml 'on:
  workflow_dispatch:
    inputs:
      push:
        description: not-a-trigger
jobs:
  j:
    steps:
      - run: bash templates/predelete_check.test.sh'

_calfail=0
_cal() {  # $1 = fixture subdir, $2 = expected count, $3 = what it proves
  local got; got=$(count_execs "templates/predelete_check.test.sh" "$_CALROOT/$1")
  if [ "$got" = "$2" ]; then
    echo "   ✅ ⑥-cal $1 → $got (want $2) — $3"
  else
    echo "   ❌ ⑥-cal $1 → $got (want $2) — $3"
    _calfail=$((_calfail+1))
  fi
}
_cal yml     1 "known-positive: the surface that already worked"
_cal yaml    1 "B: GitHub runs .yaml too — a rename must not read as ORPHANED"
_cal pkg     1 "npm scripts are an executing surface"
_cal none    0 "known-negative: no runner anywhere scores 0"
_cal manual  0 "ⓒ: workflow_dispatch-only contains the text and never runs"
_cal iffalse 0 "ⓒ: an \`if: false\` step contains the text and never runs"
_cal mention 0 "a commented invocation is a mention, not a runner"
_cal envpush  0 "ⓒ-scope: a \`push:\` under \`env:\` is not a trigger (codex repro — the unsafe direction)"
_cal ondeep   0 "ⓒ-scope: \`push:\` as a workflow_dispatch INPUT NAME is not a trigger"
_cal oninline 1 "over-block twin: \`on: [push, pull_request]\` is a real trigger"
_cal onscalar 1 "over-block twin: \`on: push\` (scalar) is a real trigger"
_cal onquoted 1 "over-block twin: YAML-1.1 \`\"on\":\` quoting is a real trigger"
if [ "$_calfail" -ne 0 ]; then
  echo "❌ ORPHAN COUNTER MISCALIBRATED — $_calfail of its own known pairs failed."
  echo "   The ≥1 assertion below would be satisfied (or denied) by a broken counter, not by a runner."
  exit 1
fi

# Known pair against the REAL tree: a path nobody executes must score 0, or the "≥1" below is
# satisfied by a broken counter rather than by a real runner.
_ctrl=$(count_execs "templates/no_such_suite_xyzzy.test.sh")
_real=$(count_execs "$SUBJ_ORPHAN")
if [ "$_ctrl" -ne 0 ]; then
  echo "❌ ORPHAN CONTROL INVALID — the counter scores $_ctrl runners for a file that does not exist."
  exit 1
fi
if [ "$_real" -lt 1 ]; then
  echo "❌ ORPHANED — $SUBJ_ORPHAN is executed by NOTHING again."
  echo "   scripts/lane_runner_check.sh cannot see it (templates/*.test.sh is outside its"
  echo "   scripts/*.sh glob), so nothing else will tell you. Restore a runner — the intended one"
  echo "   is .github/workflows/destructive-op-anchor.yml, step 'Anchor 3/3'."
  exit 1
fi
echo "⑥ orphan control: $SUBJ_ORPHAN has $_real runner(s) matching the reachable-invocation FORM"
echo "   (control: nonexistent path → $_ctrl · form-matcher, not a semantics analyzer — §NAMED LIMITS)"

# 🟥 RESIDUAL 4, RE-ADJUDICATED TWICE — "⑥ counts CALLERS, not EXECUTIONS".
# The R1 wording conceded the whole axis; the R2 wording then overclaimed the opposite. Both are
# corrected here rather than overwritten, because the overclaim is the instructive half:
#   R2 said "CLOSED for workflows — manual-only and `if: false` are THE two ways a workflow can hold
#     the invocation text and never run it". 🟥 That "the two" was a completeness claim made without
#     enumerating the candidates, and R3 falsified it in one try: a `push:` key under `env:` is a
#     third way, and the file-scoped trigger grep counted it as live
#     ([[feedback_candidate_list_completeness]]). The honest statement is NARROWER and is not a
#     count: three SPELLINGS are now rejected with their own known pairs (manual-only · `if: false` ·
#     a `push:` outside the `on:` block or below its direct children). No claim is made that the
#     list is complete — §NAMED LIMITS above enumerates the ones known to be missing.
#   OPEN, and measured rather than hand-waved: an invocation sitting in a dead branch of a SHELL
#     runner (`if false; then bash …`, an uncalled function) still counts, and a `paths:` filter
#     that never matches is not modelled. Live exposure TODAY is ZERO: the only counted runner is
#     .github/workflows/destructive-op-anchor.yml (measured with a control — the same scan finds 5
#     runners for scripts/selfcheck.sh, so the single hit is a measurement, not a dead grep), and
#     it triggers on `push: branches: ['**']`. So the open half is a future exposure, not a
#     present one.
#   The only form that truly closes it is EXECUTING the runner and observing the subject run —
#     which is what CI's 'Anchor 3/3' step does. ⑥ is the guard on that step's continued
#     existence, not a substitute for it ([[feedback_gate_binding_point_not_check_point]]).


# ── ⑦ CONTAINMENT CONTROL — the suite must not touch the REAL repo ───────────────────────────
# 🟥 This is the anchor for a leak that actually happened, on 2026-08-22, in this shared checkout:
# a run of the pre-fix suite created branches (merged-branch · newer-content · unique-work), a tag
# (v9.9.9), an untracked a.txt, left `unique.txt` STAGED IN THE INDEX, and stranded HEAD on a
# fixture branch. A sibling lane's session found it, not this one.
#
# Mechanism, reproduced rather than guessed: `newrepo` returns 1 WITHOUT echoing, so `R=$(newrepo)`
# is empty, and `cd ""` is a NO-OP SUCCESS in bash — every `( cd "$R" && git … )` then ran with cwd
# = the real repo. Repair ⑤ closes the door (no fixture → abort). THIS stage is the independent
# check on the OUTCOME, because a future leak may arrive through a door ⑤ does not watch: a lane
# that forgets `cd`, a `git -C` pointed at the wrong root, a helper that resolves REPO_ROOT.
# Door-check and outcome-check are different axes; ⑤ alone would have been the same class of
# half-measure ([[feedback_gate_binding_point_not_check_point]]).
#
# In a SHARED CHECKOUT the stake is higher than a dirty tree: a staged fixture file is committed by
# whoever commits next ([[feedback_shared_checkout_ops_touch_others_work]]).

# 🟥 THE BASELINE IS TAKEN AT THE TOP OF THIS FILE, NOT HERE — and that placement is the whole
# check. A first draft snapshotted at this point, i.e. AFTER stages ②/④/⑤ had each already run the
# suite. A revert probe with a deliberately-leaking stand-in then reported "byte-identical": the
# leak had already landed during ④, so it was inside the baseline and the comparison saw no delta.
# An IDEMPOTENT leak (create-if-absent, add-if-unstaged) is invisible to any baseline taken after
# the first run. Anchors are measured by what they can still catch, not by what they caught once
# ([[feedback_anchor_can_be_decorative]]) — so the baseline moved to before the first invocation
# and now covers every suite run this probe performs.
cout=$(bash "$SUITE" 2>&1); crc=$?
_after=$(git_state)

if [ "$crc" -ne 0 ]; then
  echo "❌ CONTAINMENT stage could not measure — the suite itself failed (rc=$crc)."
  printf '%s\n' "$cout" | grep -E '❌|HARNESS_ERROR' | sed 's/^/   | /' | head -6; exit 1
fi
if [ "$CONTAINMENT" = "skip" ]; then
  echo "⑦ containment: SKIPPED — $REPO_ROOT is not a git work tree (nothing to compare; NOT a pass)"
elif [ "$_before" != "$_after" ]; then
  echo "❌ FIXTURE LEAK — running the suite CHANGED the real repository."
  echo "   Fixtures must live only under mktemp. In a shared checkout a staged fixture file is"
  echo "   committed by whoever commits next. Diff of git state (before → after):"
  diff <(printf '%s\n' "$_before") <(printf '%s\n' "$_after") | sed 's/^/   | /' | head -20
  exit 1
else
  echo "⑦ containment: real repo byte-identical across a full suite run (status·HEAD·refs·tags·index)"
fi

echo ""
echo "✅ LIVENESS 캘리브레이션: anchor is LIVE (1 guard disabled → exactly 1 lane red, the right one)"
echo "   + portability, setup-loudness, orphan and containment controls all hold"
