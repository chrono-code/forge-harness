#!/usr/bin/env bash
# lane_runner_check.sh — a lane suite that nothing executes is prose, not an anchor.
#
# WHY (measured 2026-08-12, reship axis, card §🔱⑮ A):
# The card recorded three repairs as "지워도 레인 초록" — delete the repair, the lanes stay green,
# i.e. the anchor is decorative. Investigating those three found the class is much wider: of 43 lane
# and test suites under scripts/, **12 had no runner anywhere** — not selfcheck.sh, not the git
# hooks, not the CI workflows (all three surfaces enumerated, not assumed). 9 of the 12 ship to npm
# consumers (`npm pack --dry-run --json`, 263 files — a tarball measurement, not a files[] reading).
# ⚠️ This header said **11 / 8** until 2026-08-13 while the DEBT block below said 12, and the
# discrepancy is not a typo: 11 was the HAND-ROLLED probe's count, 12 is what this check found on
# its first run (the hand probe had read a pre-commit COMMENT as wiring). The corrected number went
# into the array and the prose above it was left alone, so the file carried both. Caught by
# cross-family review, not by re-reading. ★ A file that states its own measurement twice will
# eventually state it two different ways — and the stale copy is the one a reader meets first.
# The sharpest case was scripts/test_marker_floor_lanes.sh: pre-commit's
# validate_marker_floor() is live and blocks real commits, while its own known-pair calibration has
# never executed. A shipped gate whose calibration is dead is exactly the defect this repo spent the
# 2026-08-11/12 campaign closing, one file at a time.
#
# WHY A DERIVED CHECK AND NOT 12 MORE ANCHORS (the actual design decision):
# "Wire each one" closes today's 12 and is blind to the 13th — and the 13th is not hypothetical: the
# first run of THIS check found one (test_marker_crossfamily_lanes.sh) that the hand-rolled probe
# behind the original count had misread, because the hook names it only in a comment.
#
# ⚠️ THE JUSTIFICATION FOR BUILDING THIS IS THE MEASUREMENT, NOT A RECURRENCE COUNT — and the first
# draft of this header got that wrong. It claimed N=3 for "hardcoded list where a derived one is
# available" (citing selfcheck's `for _subj in compaction_probe judgment_circuit_lint
# novelty_claim_check`, test_selfcheck_state_lanes' four-name list, and the same-day ACCEPTED_ABSENT
# fix) and leaned on [[feedback_mechanize_at_repetition_prose_before]]'s N≥3 threshold. An
# independent scan refuted the count using this repo's own discriminator — "첫 발생 직후 고쳤다면
# 나머지가 막혔겠는가": the ACCEPTED_ABSENT fix is what CREATED the helper that exposed the second
# site, so those two are one discovery, not two recurrences; and the compaction_probe fix runs the
# OPPOSITE direction (no declaration existed there, so the correct fix was to start consulting the
# environment and assert both arms). Honest count for that class: **N=1–2, below threshold.**
#
# What actually justifies this file is a direct measurement, which needs no recurrence argument:
# **12 of 43 lane suites execute nowhere**, 8 of them shipped, including the calibrations for two
# gates that block real commits. That is a present hole, not a predicted one. Where the derived form
# is genuinely doing work is narrower and worth stating plainly: it is what makes the DEBT list
# shrink-only and what fails on the 13th — not a claim that hardcoded lists are a recurring disease
# here.
#
# THREE-VALUED, and the middle value is the whole point:
#   WIRED  — some runner invokes it (selfcheck · git hook · CI workflow · another script's dispatch)
#   EXEMPT — declared below with a reason it must NOT be auto-run (cost, live CLI, network)
#   DEBT   — known-unwired, listed below, counted loudly on every run, does NOT block
# An undeclared unwired suite is none of these and FAILS. That is the regrowth this file exists to
# stop: today's 11 are debt, tomorrow's 12th is a failure.
#
# WHY DEBT DOESN'T BLOCK: 11 suites cannot be wired in one sitting, and a check that fails for weeks
# is a check that trains `--no-verify` — this repo has logged that trade explicitly
# ([[feedback_overblock_traded_for_failopen]]). The DEBT list is a decision surface, not a silencer:
# every entry is printed on every run, and the count is a number someone has to look at.
#
# Usage:  bash scripts/lane_runner_check.sh [--list-debt]
# Exit:   0 = every suite is WIRED, EXEMPT, or declared DEBT · 1 = an undeclared suite has no runner,
#         or the instrument itself broke (zero suites scanned / dead control).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

# ── EXEMPT — declared reasons a suite must NOT be auto-run ────────────────────────────────────
# Same rule as package_coverage_check.sh's ACCEPTED_ABSENT: if you cannot write the sentence, the
# suite probably belongs in a runner instead of here.
#
#   test_sessionstart_multihook_lanes.sh — spends live `claude` CLI calls (auth + tokens) on whoever
#       runs it. selfcheck DOES reference it, via the SessionStart anchor-pair loop, and routes its
#       exit 2 to NOT EXERCISED; it is listed here only so a future reader does not "fix" that loop
#       into an unconditional run.
EXEMPT=(
  "test_sessionstart_multihook_lanes.sh"
)

# ── DEBT — measured unwired on 2026-08-12, each awaiting a runner ─────────────────────────────
# This list is the todo, and it must only ever shrink. Adding a line here is a decision that needs a
# reason in the commit message; the check does not care, but the reviewer should.
# 🟥 WHAT `DEBT: 0` DOES NOT MEAN — read before quoting the number anywhere.
# The scope of this check is a NAME CONVENTION: `suites` is globbed as `test_*.sh` / `*_lanes.sh`
# (see the glob above). A lane suite that lives INSIDE its subject as a `--self-test` dispatcher has
# no such filename and is structurally invisible here. Measured 2026-08-13, after DEBT hit zero:
#   scripts/chamber_witness.sh --self-test            16 lanes   --self-test callers: 0
#   scripts/capability_registry_check.sh --self-test   7 lanes   --self-test callers: 0
#   scripts/digest_landing_check.sh --self-test       10 lanes   --self-test callers: 0
#   scripts/directional_diff_gate.sh --self-test                 --self-test callers: 0
# 🟥 READ THAT COLUMN EXACTLY: it counts dispatches of `--self-test`, NOT callers of the script.
# The two come apart, and collapsing them does real damage in both directions. chamber_witness.sh
# has FOUR live production callers (chamber_run.sh:118·137·158·182) and zero self-test dispatches:
# writing that as "zero callers" would falsify the evidence sentence that ship_readiness_gate.md's
# identity-② promotion rests on ("wired into chamber_run.sh steps 2–5"), and ② would be overturned
# for a reason that is not true. The reverse shorthand is just as wrong: having production callers
# does NOT discharge the self-test debt — a witness generator whose known-pair never runs can break
# silently while every run that uses it still reports success, which is the fail-open the promotion
# criterion is supposed to exclude. (Both halves named by a peer session on 2026-08-13, after my
# own summary of this block used the collapsing shorthand.)
# (callers = grep over selfcheck.sh + .github/workflows/*.yml + templates/.git-hooks/*, the same
# three surfaces this check enumerates. All four SHIP.) selfcheck.sh wires exactly three embedded
# self-tests by name — compaction_probe · judgment_circuit_lint · novelty_claim_check — and these
# four are not among them. So the debt number below is true of the filename-convention population
# and false of "every lane suite in this repo executes". A second lens over `--self-test` dispatchers is
# the honest next step and is NOT built here; it is carried to the card as a measured residual so
# the number in this file cannot be read as a claim it does not make.
# (Raised by adversarial review against this delta, which called C1 "partially refuted" for exactly
# this reason. It was right: the denominator was mine to state and I had stated it as if it were the
# population.)
#
# ── 12 → 2 as of 2026-08-13 (PR: reship — lane-debt wiring) ──────────────────────────────────
# TEN of the twelve are discharged by the pair-loop in scripts/selfcheck.sh. TWO are back here,
# and the point of this block is that THE REASON CHANGED. Before today the entry meant "nothing
# runs this, and we do not know what happens if it does". Now it means "we ran it, and it fails
# outside this operator's machine" — which is a different, smaller, and actionable debt.
#
# What the twelve were: capability_entrypoint_shipping · chamber_run · destructive_pre_gate ·
# env_purity · field_canon · frontier_digest_retry · knowledge_seam · marker_crossfamily ·
# marker_floor · residency_closure · reviewer_capability_conformance · stale_clone_guard.
# Nine were in the published tarball, so consumers carried nine suites nothing called. The two
# that mattered most were the marker pair: test_marker_crossfamily_lanes.sh calibrates the
# `crossfamily:` enum that has hard-blocked commits since 2026-08-08 (the hook names it only in a
# COMMENT — templates/.git-hooks/pre-commit:1068 — which is what made a hand-rolled probe report
# 11 not 12), and test_marker_floor_lanes.sh calibrates pre-commit's live validate_marker_floor().
# Both are wired now.
#
# 🟥 THE TWO BELOW WERE WIRED, MEASURED RED IN CI, AND DELIBERATELY MOVED BACK. Making them green
# was available and is the wrong move: their failures are TRUE — the suites really do depend on
# things a CI runner does not have — so forcing a pass would be routing a real failure to green in
# the same delta that spent nine repairs closing exactly that. A suite whose preconditions are
# undeclared belongs in the todo list, not in the mandatory path.
DEBT=(
  # PASS 19 · FAIL 0 locally; PASS 12 · FAIL 7 in CI. Reproduced locally by pointing HOME at an
  # empty directory — 12/7, the same split — so the dependency is exact and not a guess:
  # field_canon_preload.sh resolves `${HOME}/projects` and seven lanes assume the operator's
  # mapped-project layout is there. Nothing in the suite declares that precondition, so on a
  # machine without it the suite reports a REGRESSION rather than "not exercised here".
  # Fix before re-wiring: the suite must detect the missing layout and exit NOT-EXERCISED (the
  # shape test_sessionstart_multihook_lanes.sh already uses for its CLI dependency), or build its
  # own fixture HOME for those seven the way it already does for the no-HOME lane.
  "test_field_canon_lanes.sh"
  # 17/17 locally; 2/17 in CI. And this one was PREDICTED: the adversarial review of this very
  # delta flagged `elapsed < 10` as a wall-clock assertion that would go falsely red on a loaded CI
  # runner, naming this file and that line. It was filed as a low-severity residual and not acted
  # on; CI then produced exactly it. ★ The finding named a MECHANISM (a wall-clock assertion is now
  # on a mandatory path), and a mechanism does not become less true for being labelled R.
  # Fix before re-wiring: give the timing assertions headroom or gate them behind an explicit
  # opt-in, so the default run measures logic and not the runner's load.
  "test_stale_clone_guard_lanes.sh"
)

if [ "${1:-}" = "--list-debt" ]; then
  # Same bash-3.2 empty-array guard as the scan call below. This site was MISSED when that one was
  # fixed in the same commit — the fix stopped at the two sites the failing run happened to touch,
  # and `--list-debt` (a documented interface, see Usage above) still died with `unbound variable`.
  # Caught by adversarial review, not by me. [[feedback_half_fix_propagation_boundary]]: the
  # question a repair must ask is "where else does this fact have to reach", and "the sites my
  # repro exercised" is not an answer to it.
  printf '%s\n' "${DEBT[@]+"${DEBT[@]}"}"
  exit 0
fi

# ── SELF-REFERENCE: this checker is not a lane suite, so it does not appear in its own scanned set
# (the name pattern below matches `test_*.sh` / `*_lanes.sh`, and this is neither). That gap is the
# exact defect this file exists to detect, one level up: unwire it and nothing notices, because the
# only thing that would notice is itself. Measured by a revert probe on the day it was written —
# removing its call from selfcheck.sh left every check green, this one included.
# Guarded on selfcheck.sh's presence so a tree that legitimately lacks it does not fail here.
if [ -f scripts/selfcheck.sh ] && ! grep -qE '^[[:space:]]*(if !? ?)?bash scripts/lane_runner_check\.sh' scripts/selfcheck.sh; then
  echo "FAIL  lane-runner: scripts/selfcheck.sh no longer invokes this check — the checker that"
  echo "      detects unrun suites is itself unrun. Restore the call in selfcheck.sh."
  exit 1
fi

# `"${ARR[@]+"${ARR[@]}"}"` and not the plain `"${ARR[@]}"`: on bash 3.2 (stock macOS) `set -u`
# treats an EMPTY array's expansion as an unbound variable and aborts. DEBT is now empty by design,
# which is exactly the state the plain form cannot survive — measured here 2026-08-13, and it
# aborted so early that the script still printed PASS (see the rc routing further down).
out=$(python3 - "${#EXEMPT[@]}" "${EXEMPT[@]+"${EXEMPT[@]}"}" "${DEBT[@]+"${DEBT[@]}"}" <<'PY'
import os, re, sys, glob, json

n_exempt = int(sys.argv[1])
exempt = set(sys.argv[2:2 + n_exempt])
debt   = set(sys.argv[2 + n_exempt:])

# Suites: deduped by NAME. An earlier draft globbed `scripts/*_lanes.sh` and `scripts/test_*.sh`
# separately and summed them — every `test_*_lanes.sh` matched both, inflating 43 to 75. The count
# was never published; it was caught because a hand-check of one case disagreed with it
# (CLAUDE.md §Instrument-Calibration, hand-verify-one-sample). Keep this a set.
suites = sorted({os.path.basename(f) for f in glob.glob('scripts/*.sh')
                 if re.match(r'^(test_.*|.*_lanes)\.sh$', os.path.basename(f))})

# Runner surfaces, enumerated rather than assumed. All three were checked by hand when this file was
# written: CI runs `bash scripts/selfcheck.sh` + count_check + the plugin validators and nothing else.
SELF = os.path.basename(__file__) if '__file__' in dir() else 'lane_runner_check.sh'
runners = []
for pat in ('scripts/*.sh', 'templates/.git-hooks/*', '.github/workflows/*.yml'):
    runners += [p for p in glob.glob(pat) if os.path.isfile(p)]
# This file names every DEBT and EXEMPT suite in its own arrays. Scanning itself would read each of
# those declarations as evidence the suite is run — the check would certify its own todo list as
# done. Caught by the known-negative control below on the first execution.
runners = [r for r in runners if os.path.basename(r) != 'lane_runner_check.sh']

# An invocation is `bash <path-ending-in-suite>`, not a mention of the name. The bounded `.{0,60}?`
# spans wrappers like `exec bash "$(dirname "$0")/x.sh"` (which contains a space inside the command
# substitution) without running to the end of an arbitrary line.
INVOKE = re.compile(r'\b(?:exec\s+)?(?:bash|sh)\s+.{0,60}?')

def has_runner(suite):
    """A mention is not an invocation. Comments, package.json files[] entries and prose references in
    tracks/ all name suites without running them — that conflation is what made the original count
    wrong (75 vs the real 43).

    Two measured failures shaped this predicate, both caught by the controls rather than by review:
      · `\\b(bash|sh)\\b` matched the `sh` inside the `.sh` extension itself, so ANY line naming a
        suite counted as running it — every suite read as WIRED, including the known-negative.
      · An earlier quote-anchored regex missed `exec bash "$(dirname "$0")/x.sh"` and reported NONE
        for a suite a hand-check had already confirmed was dispatched.
    Both are the same class: the predicate was re-spelled instead of being pinned to a known pair."""
    for r in runners:
        if os.path.basename(r) == suite:
            continue
        try:
            txt = open(r, encoding='utf-8', errors='replace').read()
        except OSError:
            continue
        if runner_dispatches(suite, txt):
            return True
    return False

def runner_dispatches(suite, txt):
    """The whole predicate, over ONE runner's text. Split out from has_runner so the controls below
    can drive it with synthetic fixtures instead of with whatever the repo happens to look like
    today — see the CONTROL block for why that mattered."""
    direct = re.compile(r'\b(?:exec\s+)?(?:bash|sh)\s+.{0,60}?' + re.escape(suite))
    lines = txt.split('\n')
    # Does this runner invoke ANYTHING through a variable? If so, a suite named in one of its
    # list constructs is plausibly dispatched by that loop.
    indirect_dispatch = any(
        re.search(r'\b(?:exec\s+)?(?:bash|sh)\s+"?\$', ln)
        for ln in lines if not ln.strip().startswith('#'))
    for line in lines:
        if suite not in line or line.strip().startswith('#'):
            continue
        if direct.search(line):
            return True
        # for-list idiom, used twice in selfcheck.sh:
        #   for _anchor in scripts/a.sh scripts/b.sh; do ... bash "$_anchor" ... done
        #   for _pair in "subject|scripts/x.sh|mode" ...; do ... bash "$_anc" ... done
        # The literal name is in the list; the invocation is through the variable, so the direct
        # pattern above structurally cannot see it. Hand-verified 2026-08-12 for both
        # test_session_close_lanes.sh and test_wizard_snippet_merge_lanes.sh — the strict
        # detector called both UNWIRED and both are genuinely run.
        # Gated on the file actually containing a variable dispatch, so a prose mention in a
        # script that never runs anything indirectly does not get a free pass.
        if indirect_dispatch and re.match(r'\s*(for\s+\w+\s+in\b|["\']?\S*\|)', line):
            return True
    return False

wired = {s for s in suites if has_runner(s)}

# ── CONTROL: the instrument must be able to see a suite known to be wired, and must NOT see one
# known to be dead. Without both arms a broken detector reports "all clean" or "all broken" and
# either reads as a verdict. [[feedback_absence_measurement_needs_control]]
CTL_POS  = 'test_selfcheck_state_lanes.sh'    # selfcheck.sh invokes this DIRECTLY
CTL_POS2 = 'test_session_close_lanes.sh'      # selfcheck.sh:613 for-list + `bash "$_anchor"` — the
                                              # INDIRECT arm. Pins the second detection branch: the
                                              # strict detector called this UNWIRED and a hand-check
                                              # showed it runs. Without this control that branch
                                              # could silently rot back to blind.
# ── the known-NEGATIVE arm is now synthetic, and that is a repair, not a weakening ────────────
# It used to name a real suite (test_residency_closure_lanes.sh) that had zero callers. On
# 2026-08-13 the DEBT list was discharged, that suite gained a runner, and the control fired:
# "known-negative read as WIRED — the detector over-matches". The detector was fine. The CONTROL
# had been anchored to WORK NOT YET DONE, so doing the work broke the instrument. A negative
# control that lives on the todo list dies the moment the todo list is emptied — and it dies
# LOUDLY, as a false accusation against the thing it was guarding, which is the worst possible
# time to be debugging your own instrument.
# So the negative arm is driven with fixture text instead. The three fixtures are the three ways a
# name appears WITHOUT being run, all of them observed in this repo:
#   · in a comment (every DEBT/EXEMPT declaration, and the pre-commit:1068 mention that fooled a
#     hand-rolled probe into reporting 11 instead of 12)
#   · in a manifest-style list with no dispatch anywhere in the file (package.json files[])
#   · next to a `bash -n "$f"` syntax-check loop over a glob — flagged 2026-08-13 by a peer session
#     as the way a DEBT count could be silently understated, since that loop touches every script
#     in the tree. Pinned here so the answer stays measured rather than argued: syntax-checking a
#     file is not running its lanes, and `bash -n` must never satisfy this predicate.
# 🟥 NAMED RESIDUAL — the indirect branch is a KNOWN BYPASS, and the claim is narrowed accordingly.
# Both an in-family adversarial review and an independent cross-family audit (codex/gpt-5.5) landed
# on this same hole on 2026-08-13, and the cross-family one reproduced it against the predicate
# itself: a file that contains `bash "$ANY_VAR"` ANYWHERE, plus a line of the shape
# `"x|scripts/test_future_lanes.sh|y"`, reads as WIRED even when nothing dispatches that list.
# So "an undeclared unwired suite cannot regrow" is true of a suite nobody MENTIONS and false of one
# added decoratively to an existing pair table. It is documented rather than closed because
# narrowing the branch to same-loop-body variable matching would put both real known-positives
# (selfcheck.sh:723 and :630) at risk, and this file sits exactly where "the repair is the main
# source of the next defect" has already been measured. The fixture below pins the CURRENT
# permissive behaviour so that a future narrowing is a visible, deliberate change rather than a
# silent one — it asserts what IS, not what should be.
CTL_BYPASS_FIXTURE = (
    '#!/usr/bin/env bash\nbash "$UNRELATED"\n'
    '  "subject|scripts/test_control_never_wired_lanes.sh|mode"\n')
CTL_NEG_NAME = 'test_control_never_wired_lanes.sh'
CTL_NEG_FIXTURES = [
    ("comment-only mention",
     '#!/usr/bin/env bash\nbash "$SOME_OTHER"\n# see test_control_never_wired_lanes.sh for detail\n'),
    ("manifest-style list, no dispatch in file",
     '{\n "files": [\n  "scripts/test_control_never_wired_lanes.sh"\n ]\n}\n'),
    ("bash -n glob loop + prose mention",
     '#!/usr/bin/env bash\nfor f in scripts/*.sh; do bash -n "$f" || fail=1; done\n'
     'echo "coverage includes scripts/test_control_never_wired_lanes.sh"\n'),
]
ctl = []
if CTL_POS in suites and CTL_POS not in wired:
    ctl.append(f"known-positive {CTL_POS} read as UNWIRED — the direct detector is blind")
if CTL_POS2 in suites and CTL_POS2 not in wired:
    ctl.append(f"known-positive {CTL_POS2} read as UNWIRED — the for-list/indirect branch is blind")
for _why, _txt in CTL_NEG_FIXTURES:
    if runner_dispatches(CTL_NEG_NAME, _txt):
        ctl.append(f"known-negative ({_why}) read as WIRED — the detector over-matches")
# The fixtures above drive `runner_dispatches` DIRECTLY, which leaves the layer between it and
# `has_runner` uncontrolled — runner enumeration, and in particular the self-exclusion filter that
# keeps this file out of its own scanned set. That filter is load-bearing: without it, every name
# declared in the arrays here reads as evidence that the suite runs, and the check certifies its own
# todo list as done. The old real-suite known-negative used to cover that path incidentally; the
# fixtures do not, so the loss is pinned explicitly rather than left as an unstated regression
# (raised by adversarial review, which was right that C4 was a strengthening AND a narrowing).
if any(os.path.basename(r) == 'lane_runner_check.sh' for r in runners):
    ctl.append("self-exclusion filter is gone — this file is in its own runner set, so every name "
               "in DEBT/EXEMPT would read as WIRED")
if not runners:
    ctl.append("runner enumeration collapsed to zero — every suite would read as UNWIRED")
# And the positive arm on fixture text too, so the negative arm cannot pass by the predicate simply
# having gone blind — a detector that answers False to everything satisfies three negatives.
if not runner_dispatches(CTL_NEG_NAME, 'bash scripts/test_control_never_wired_lanes.sh\n'):
    ctl.append("fixture known-positive read as UNWIRED — the predicate answers False to everything")
# Pins the documented bypass above. If this ever stops holding, someone narrowed the indirect branch
# — which may well be the right move, but it must be a decision, and both real known-positives above
# have to be re-confirmed at the same time. Update this line and the residual note together.
if not runner_dispatches(CTL_NEG_NAME, CTL_BYPASS_FIXTURE):
    ctl.append("the documented indirect-branch bypass no longer reproduces — the predicate was "
               "narrowed. That is not a failure, but the residual note above is now stale and the "
               "two real for-list known-positives must be re-verified before removing this check.")
if ctl:
    print("CONTROL_FAILED\t" + " · ".join(ctl))
    raise SystemExit(2)

if not suites:
    print("EXTRACTOR_BROKE\tzero lane suites found under scripts/")
    raise SystemExit(2)

undeclared = sorted(s for s in suites if s not in wired and s not in exempt and s not in debt)
# A DEBT entry that has since gained a runner is resolved — say so, so the list shrinks by evidence
# rather than by someone remembering. Same shape as package_coverage_check.sh's STALE report.
resolved = sorted(s for s in debt if s in wired)
# A DEBT entry that no longer exists at all (renamed/deleted) is also stale.
gone = sorted(s for s in debt if s not in suites)

print(f"COUNTS\t{len(suites)}\t{len(wired)}\t{len(exempt)}\t{len(debt)}")
for s in undeclared:
    print(f"UNDECLARED\t{s}")
for s in resolved:
    print(f"RESOLVED\t{s}")
for s in gone:
    print(f"GONE\t{s}")
PY
)
rc=$?

if [ "$rc" -eq 2 ]; then
  echo "FAIL  lane-runner: the instrument broke, it did not pass"
  printf '%s\n' "$out" | sed 's/^/      /'
  exit 1
fi

# ANY other non-zero is also the instrument failing, and it used to fall straight through to the
# PASS line below. Measured 2026-08-13, on this file, by the change that emptied DEBT: under
# `set -u` on bash 3.2 (stock macOS) an EMPTY array expanded with "${DEBT[@]}" is an UNBOUND
# VARIABLE, so the heredoc never ran, `out` was empty, every count parsed as 0 via the `${1:-0}`
# defaults — and the script printed `PASS lane-runner: 0 suites`. A dead instrument reported a
# clean tree. Only rc==2 was handled because only rc==2 had ever been produced deliberately;
# everything else was assumed impossible rather than routed. That assumption is the defect class
# this whole file exists to catch, reproduced inside the catcher.
if [ "$rc" -ne 0 ]; then
  echo "FAIL  lane-runner: the scan exited $rc — the instrument did not complete, so this run"
  echo "      measured nothing. It is not a pass. (An empty result set is NOT an empty todo list.)"
  printf '%s\n' "$out" | head -5 | sed 's/^/      /'
  exit 1
fi

COUNTS=$(printf '%s\n' "$out" | awk -F'\t' '$1=="COUNTS"{print $2" "$3" "$4" "$5}')
set -- $COUNTS
TOTAL="${1:-0}"; WIRED="${2:-0}"; N_EXEMPT="${3:-0}"; N_DEBT="${4:-0}"

UNDECLARED=$(printf '%s\n' "$out" | awk -F'\t' '$1=="UNDECLARED"{print $2}')
RESOLVED=$(printf '%s\n' "$out" | awk -F'\t' '$1=="RESOLVED"{print $2}')
GONE=$(printf '%s\n' "$out" | awk -F'\t' '$1=="GONE"{print $2}')

if [ -n "$UNDECLARED" ]; then
  echo "FAIL  lane-runner: lane suite(s) with no runner and no declaration:"
  printf '%s\n' "$UNDECLARED" | sed 's/^/        /'
  echo "      A suite nothing executes is prose. Fix by ONE of:"
  echo "        · wire it into scripts/selfcheck.sh (the usual answer)"
  echo "        · add it to EXEMPT here WITH the reason it must not be auto-run"
  echo "        · add it to DEBT here if it is known-unwired work you are deferring"
  exit 1
fi

# Advisory, never blocking — a stale DEBT entry is hygiene, and converting a clean run into a red
# gate over bookkeeping is how the check stops being read.
if [ -n "$RESOLVED" ]; then
  echo "⚠️  lane-runner: DEBT entry(ies) now have a runner — remove them from DEBT:"
  printf '%s\n' "$RESOLVED" | sed 's/^/        /'
fi
if [ -n "$GONE" ]; then
  echo "⚠️  lane-runner: DEBT entry(ies) no longer exist (renamed/deleted?) — remove them:"
  printf '%s\n' "$GONE" | sed 's/^/        /'
fi

if [ "$N_DEBT" -gt 0 ]; then
  echo "⚠️  lane-runner: ${N_DEBT} suite(s) still have NO runner (declared debt — see DEBT for the"
  echo "    per-entry reason and the date each was measured; they are not all from one measurement)."
  echo "    They are shipped or present but never execute — see DEBT in this file. This number must"
  echo "    only go down; a new one fails the check rather than joining the list silently."
fi

echo "PASS  lane-runner: ${TOTAL} suites — ${WIRED} wired · ${N_EXEMPT} exempt · ${N_DEBT} declared debt"
exit 0
