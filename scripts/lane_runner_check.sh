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
# 🟢 THE TWO THAT WERE HERE ARE RE-WIRED (2026-08-14) — DEBT 2 → 0. Both entries below are
# HISTORICAL: they record why the suites were pulled out and what the fix had to be, kept because
# the reasoning (and the exact CI-reproduction numbers) are load-bearing evidence for the next
# person who touches either suite, not because either is still debt.
#
# test_field_canon_lanes.sh — was: PASS 19 · FAIL 0 locally; PASS 12 · FAIL 7 in CI. Reproduced
# locally by pointing HOME at an empty directory — 12/7, the same split — so the dependency was
# exact and not a guess: field_canon_preload.sh resolves `${HOME}/projects` and seven lanes assumed
# the operator's mapped-project layout was there. Nothing in the suite declared that precondition,
# so on a machine without it the suite reported a REGRESSION rather than "not exercised here". Fix
# (built the second option this entry named, not the first): the suite now carries its own fixture
# hub+project-root (mirroring the shape lane ⑭ already used) instead of depending on the operator's
# real filesystem — `run()`/`runD()` inject `CLAUDE_PROJECT_DIR`/`FIELD_CANON_PROJECT_ROOT` at a
# fixed fixture path. Verified both directions: PASS 19/19 under an empty HOME (the exact CI
# reproduction) AND a known-negative check — breaking the `-dev`-suffix repo-resolution fallback in
# field_canon_preload.sh reproduces the identical PASS 12 / FAIL 7 split, so the fixture measures
# real behavior, not a vacuously-green rewrite.
#
# test_stale_clone_guard_lanes.sh — was: 17/17 locally; 2/17 in CI. Predicted by an adversarial
# review of the delta that introduced `elapsed < 10` as a wall-clock assertion on a mandatory path;
# CI then produced exactly it. Fix (the first option this entry named): the wedge sleep widened
# 30s→60s and the assertion changed from a fixed `elapsed < 10` to a relative `elapsed <
# (wedge/2)=30s` — proving the guard's internal 0.5s budget bounded it (60x headroom) rather than an
# absolute constant tuned to one machine's speed. Known-negative check: neutering the budget's kill
# condition in stale_clone_guard.sh (so it waits out the full wedge instead of self-bounding)
# correctly fails exactly this one lane, confirming the widened threshold still discriminates.
#
# Re-wired into scripts/selfcheck.sh's pair-loop alongside the other ten (found→extend, same shape:
# "scripts/field_canon_preload.sh|scripts/test_field_canon_lanes.sh" and
# "scripts/stale_clone_guard.sh|scripts/test_stale_clone_guard_lanes.sh").
DEBT=()

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

# ── ORG SEAM — a downstream org declares ITS OWN suites in ITS OWN file ───────────────────────
# Why this exists (requested 2026-08-13 by a downstream org fork of this harness, with evidence):
# EXEMPT and DEBT above are hardcoded arrays in a SHARED-LAYER file. A downstream fork carries
# suites this repo has never heard of (`test_rest_push_lanes.sh`, `test_company_delta_lanes.sh` …),
# and all three remedies this check offers land in files that fork does not own:
#     wire into selfcheck.sh   → shared layer   · EXEMPT array → this file, shared layer
#     DEBT array               → this file, shared layer
# So the fork's only choices were "violate the sync boundary" or "live at rc=1 forever". Measured:
# 5 such suites on their first run of this check. That is not a preference — a permanently red
# check stops being read, and one of those five suites had just caught a real regression when it
# was run by hand.
#
# Shape: OPTIONAL file, absent by default. This repo ships none, so the no-op arm is the arm that
# runs here — verified by the known-pair in scripts/test_lane_runner_lanes.sh.
#
# 🟥 A MALFORMED FILE IS FAIL-CLOSED, a stale entry is advisory. Those are different failures:
#   · cannot parse   → the instrument did not look. Reporting "no declarations" would render
#                      UNMEASURED as ZERO, which is the exact family this repo keeps closing.
#   · names a suite that no longer exists → hygiene, same as a stale DEBT entry above, so it warns
#                      with the same voice. Making the downstream rule STRICTER than the upstream
#                      one it mirrors would just train people to delete the file.
ORG_DECL="company/lane_declarations.yaml"
ORG_EXEMPT=(); ORG_DEBT=()
if [ -f "$ORG_DECL" ]; then
  _org_out=$(python3 - "$ORG_DECL" <<'ORGPY'
import re, sys
path = sys.argv[1]
try:
    txt = open(path, encoding='utf-8').read()
except OSError as e:
    print(f"ERR\tcannot read {path}: {e}"); sys.exit(0)
sect = None; seen = {}
for i, ln in enumerate(txt.splitlines(), 1):
    s = ln.split('#', 1)[0].rstrip()
    if not s.strip():
        continue
    m = re.match(r'^([A-Za-z_]+):\s*$', s)
    if m:
        sect = m.group(1)
        if sect not in ('exempt', 'debt'):
            print(f"ERR\t{path}:{i}: unknown section '{sect}' (expected 'exempt' or 'debt')")
            sys.exit(0)
        continue
    m = re.match(r'^\s+-\s+(\S+)\s*$', s)
    if m:
        if sect is None:
            print(f"ERR\t{path}:{i}: entry before any section header"); sys.exit(0)
        name = m.group(1)
        if name in seen and seen[name] != sect:
            print(f"ERR\t{path}:{i}: '{name}' declared both exempt and debt — ambiguous")
            sys.exit(0)
        seen[name] = sect
        print(f"{sect}\t{name}")
        continue
    print(f"ERR\t{path}:{i}: unparseable line: {s.strip()[:60]}")
    sys.exit(0)
ORGPY
)
  # `grep -q '^ERR'` — NOT `'^ERR\t'`. In a POSIX BRE, GNU grep reads `\t` as a literal `t`
  # (so the pattern becomes `^ERRt` and matches nothing) while BSD grep on macOS takes it as a tab.
  # Measured 2026-08-13: this exact line passed all 11 lanes locally and failed L6/L7/L8 in CI —
  # the fail-closed arm was silently dead on Linux, which is the platform that gates merges.
  # Same family as the `"$DDSCAN" "` anchor divergence a sibling harness measured the same day:
  # a regex that means different things on the two greps is an instrument, and an instrument that
  # answers differently per platform has not measured anything.
  if printf '%s' "$_org_out" | grep -q '^ERR'; then
    echo "FAIL  lane-runner: $ORG_DECL exists but could not be read as declarations —"
    printf '%s' "$_org_out" | sed 's/^ERR[[:space:]]*/        /'
    echo "      An unreadable declaration file is UNMEASURED, not empty. Fix the file or delete it."
    exit 2
  fi
  while IFS=$'\t' read -r _k _v; do
    [ -z "${_v:-}" ] && continue
    case "$_k" in
      exempt) ORG_EXEMPT+=("$_v") ;;
      debt)   ORG_DEBT+=("$_v") ;;
    esac
  done <<< "$_org_out"
  # Stale-entry warning, same voice as the DEBT hygiene warnings below.
  for _n in "${ORG_EXEMPT[@]+"${ORG_EXEMPT[@]}"}" "${ORG_DEBT[@]+"${ORG_DEBT[@]}"}"; do
    [ -f "scripts/$_n" ] || echo "⚠️  lane-runner: $ORG_DECL declares '$_n' but scripts/$_n does not exist (renamed/deleted?)"
  done
  # Visibility: an org-declared suite must never be indistinguishable from an upstream one. A
  # reader who sees "0 debt" has to be able to tell whether that is this repo's zero or a fork's
  # declaration absorbing its own list.
  echo "      lane-runner: $ORG_DECL — ${#ORG_EXEMPT[@]} exempt · ${#ORG_DEBT[@]} debt (org-declared)"
  EXEMPT+=("${ORG_EXEMPT[@]+"${ORG_EXEMPT[@]}"}")
  DEBT+=("${ORG_DEBT[@]+"${ORG_DEBT[@]}"}")
fi

# `"${ARR[@]+"${ARR[@]}"}"` and not the plain `"${ARR[@]}"`: on bash 3.2 (stock macOS) `set -u`
# treats an EMPTY array's expansion as an unbound variable and aborts. DEBT is now empty by design,
# which is exactly the state the plain form cannot survive — measured here 2026-08-13, and it
# aborted so early that the script still printed PASS (see the rc routing further down).
# -- RUNNER SURFACE = THE GIT INDEX, NOT THE WORKING TREE (D-5, 2026-08-24) --------------------
# An UNTRACKED file must never certify anything as WIRED. Until this fix the RUNNER globs below
# were resolved against the DISK, so a workflow / hook / script that existed only in this working
# copy counted as a caller -- and the tree read green on wiring that disappears on `git clone`.
#
# The POPULATION globs (what gets CHECKED) stay on DISK on purpose. There an untracked file must
# be SEEN, so a new uncommitted script goes red instead of slipping through. Only the RUNNER
# surface moves to the index; moving both would trade one silent pass for another.
#
# 🟥 "NOT A REPOSITORY" AND "GIT FAILED" ARE DIFFERENT FACTS AND MUST NOT SHARE A BRANCH.
# The first draft of this block folded EVERY non-zero `git ls-files` exit into "no index here, use
# the disk". Cross-family review (codex/gpt-5.5, 2026-08-24) executed the consequence: a fake `git`
# that exits 1 for everything produced a warning line and then a PASS. A missing binary, a locked
# or corrupt index, and a permission failure all landed on the SAME branch as an unpacked npm
# tarball -- so the repair against "green that a clone deletes" had installed a fresh green of its
# own. That is [[feedback_not_found_is_not_zero_family]] wearing this file's colours, and the
# asymmetry was backwards: an EMPTY result was routed to UNMEASURED while a FAILED one was routed
# to a pass.
#
# So the state is resolved by POSITIVE questions, in order, and only the answers that are actually
# established are allowed to reach the disk fallback:
#   git absent / `git --version` non-zero        -> UNMEASURED  (the instrument, not the tree)
#   rev-parse fails AND a .git exists up-chain   -> UNMEASURED  (git broke inside a repo)
#   rev-parse fails AND no .git anywhere up-chain-> nongit      (an unpacked tarball: disk is right)
#   inside a git dir with no work tree           -> nongit
#   in a work tree, `git ls-files` non-zero      -> UNMEASURED  (locked/corrupt index, permissions)
#   in a work tree, ls-files empty, cwd ignored  -> outside-index (a package unpacked INSIDE some
#                                                   other repo -- the index cannot answer for it,
#                                                   and blocking every such install would just
#                                                   train the override)
#   in a work tree, ls-files empty, cwd tracked  -> UNMEASURED  (an empty index is not zero runners)
#   otherwise                                    -> index
# 🟥 The discriminator can itself fail, and when it does the answer is UNMEASURED -- never "not a
# repository". That is why the .git walk-up exists: it is a filesystem fact that needs no working
# git, so "git could not tell us" and "there is genuinely nothing here" stay separable.
#
# 🟥 `git ls-files` into a file, then `$?` on its OWN line. No pipe, no `|| true`: a fallback would
# hand an empty list to the scan and the scan would render it as "no runners".
_fh_has_dotgit_upchain() {
  local _d; _d="$(pwd -P)"
  while : ; do
    [ -e "$_d/.git" ] && return 0
    [ "$_d" = "/" ] && return 1
    _d="$(dirname "$_d")"
  done
}
FH_INDEX_STATE="UNMEASURED"; FH_INDEX_WHY="not determined"; FH_INDEX_FILE_LIST=""
if ! command -v git >/dev/null 2>&1; then
  FH_INDEX_WHY="git is not on PATH -- the index could not be read at all"
else
  _fh_gv="$(git --version 2>/dev/null)"; _fh_gvrc=$?
  if [ "$_fh_gvrc" -ne 0 ] || [ -z "$_fh_gv" ]; then
    FH_INDEX_WHY="\`git --version\` exited $_fh_gvrc -- the git binary is unusable, so nothing below was measured"
  else
    _fh_wt="$(git rev-parse --is-inside-work-tree 2>/dev/null)"; _fh_wtrc=$?
    if [ "$_fh_wtrc" -ne 0 ]; then
      if _fh_has_dotgit_upchain; then
        FH_INDEX_WHY="git works but \`rev-parse --is-inside-work-tree\` exited $_fh_wtrc while a .git exists above this directory -- git failed, this is not a plain directory"
      else
        FH_INDEX_STATE="nongit"; FH_INDEX_WHY="no repository here and no .git anywhere above -- an unpacked tarball"
      fi
    elif [ "$_fh_wt" != "true" ]; then
      FH_INDEX_STATE="nongit"; FH_INDEX_WHY="inside a git dir with no work tree (bare repository)"
    else
      # 🟥 NUL ALL THE WAY. An earlier draft piped this through `tr '\0' '\n'` into an env var,
      # which un-did the whole point of `-z`: a path containing a NEWLINE was split into two paths
      # before python ever saw it. Env vars cannot carry NUL, so the list travels as a FILE and the
      # separator is never translated. Cross-family review, 2026-08-24, round 3.
      _fh_tmp="$(mktemp)"
      git ls-files -z >"$_fh_tmp" 2>/dev/null
      _fh_lrc=$?
      FH_INDEX_FILE_LIST="$_fh_tmp"
      if [ "$_fh_lrc" -ne 0 ]; then
        FH_INDEX_WHY="inside a work tree, but \`git ls-files\` exited $_fh_lrc -- a locked or corrupt index, or a permission failure. NOT an absence of runners"
      elif [ -s "$_fh_tmp" ]; then
        FH_INDEX_STATE="index"; FH_INDEX_WHY="the git index"
      else
        git check-ignore -q . 2>/dev/null; _fh_ci=$?
        if [ "$_fh_ci" -eq 0 ]; then
          FH_INDEX_STATE="outside-index"; FH_INDEX_WHY="this directory is IGNORED by the surrounding repository, so its index cannot answer for these files"
        else
          FH_INDEX_WHY="\`git ls-files\` exited 0 and returned NOTHING while this directory is tracked territory -- an empty index is not zero runners"
        fi
      fi
    fi
  fi
fi
export FH_INDEX_STATE FH_INDEX_WHY FH_INDEX_FILE_LIST

out=$(python3 - "${#EXEMPT[@]}" "${EXEMPT[@]+"${EXEMPT[@]}"}" "${DEBT[@]+"${DEBT[@]}"}" <<'PY'
import os, re, sys, glob, json, subprocess

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
RUNNER_GLOBS = ('scripts/*.sh', 'templates/.git-hooks/*', '.github/workflows/*.yml')

# -- INDEX-vs-DISK enumeration, RUNNER surfaces ONLY. State resolved in the bash preamble above. -
INDEX_MODE = os.environ.get('FH_INDEX_STATE', '')
INDEX_WHY = os.environ.get('FH_INDEX_WHY', 'the preamble did not run')
_idx_path = os.environ.get('FH_INDEX_FILE_LIST', '')
_idx_raw = b''
if _idx_path:
    try:
        _idx_raw = open(_idx_path, 'rb').read()
    except OSError:
        _idx_raw = b''
INDEX_FILES = [_b.decode('utf-8', 'replace') for _b in _idx_raw.split(b'\0') if _b]
# Fail-closed on anything this file does not recognise, including the empty string a caller that
# skipped the preamble would leave behind. A mode nobody set is not a mode that means "use disk".
if INDEX_MODE not in ('index', 'nongit', 'outside-index'):
    INDEX_MODE = 'UNMEASURED'
if INDEX_MODE == 'index' and not INDEX_FILES:
    INDEX_MODE = 'UNMEASURED'
    INDEX_WHY = 'state said index and the file list is empty -- the two disagree'

def _glob_rx(pat):
    # glob semantics, NOT fnmatch, and that includes the DOTFILE rule.
    # `*` -> `[^/]*` alone is WIDER than the `glob.glob()` it replaced: fnmatch translates `*` to
    # `.*`, which also crosses `/`, and neither form hides dotfiles. `glob.glob('scripts/*.sh')`
    # does NOT return `scripts/.x.sh`; a regex without the guard below DOES, so a hidden tracked
    # file would certify a caller that the old surface never contained. Cross-family review,
    # 2026-08-24. The guard is per SEGMENT and keys on a leading `*`/`?` in that segment -- a dot
    # in a literal segment (`templates/.git-hooks/`) is a directory name and is unaffected; what
    # glob hides is a leading dot in the matched BASENAME.
    _segs = []
    for _seg in pat.split('/'):
        _s = ''
        if _seg[:1] in ('*', '?'):
            _s += '(?!\\.)'
        for _c in _seg:
            _s += '[^/]*' if _c == '*' else '[^/]' if _c == '?' else re.escape(_c)
        _segs.append(_s)
    return re.compile('^' + '/'.join(_segs) + '$')

def enumerate_runners(patterns):
    # index: the candidate runners are what `git ls-files` says is TRACKED.
    # nongit / outside-index: no index can answer here, so disk is the correct surface -- and the
    # run says which of the two it is out loud. UNMEASURED never reaches this function.
    if INDEX_MODE == 'index':
        # 🟥 NO os.path.isfile HERE. Filtering the INDEX list by what happens to be on disk lets the
        # working tree decide the population of an index-grounded judgment -- a tracked runner the
        # worktree has deleted would silently become "not a runner" instead of "read its blob",
        # which also skips the completeness check below. The index blob exists regardless of the
        # working tree; that is the whole reason to read it. Cross-family review, round 3.
        # The disk branch on the next line KEEPS isfile, and so do LOCAL_ONLY_SURFACES: there the
        # working tree IS the surface, and a name with no file behind it is genuinely nothing.
        _rx = [_glob_rx(_p) for _p in patterns]
        return [_p for _p in INDEX_FILES if any(_r.match(_p) for _r in _rx)]
    return [_p for _pat in patterns for _p in glob.glob(_pat) if os.path.isfile(_p)]

if INDEX_MODE == 'UNMEASURED':
    print('CONTROL_FAILED\tthe runner surface is UNMEASURED, not zero runners: ' + INDEX_WHY)
    raise SystemExit(2)
print('INDEX_MODE\t' + INDEX_MODE + '\t' + INDEX_WHY)

runners = enumerate_runners(RUNNER_GLOBS)
# This file names every DEBT and EXEMPT suite in its own arrays. Scanning itself would read each of
# those declarations as evidence the suite is run — the check would certify its own todo list as
# done. Caught by the known-negative control below on the first execution.
runners = [r for r in runners if os.path.basename(r) != 'lane_runner_check.sh']

# -- RUNNER CONTENT = THE INDEX BLOB, NOT THE WORKING TREE FILE -------------------------------
# 🟥 THE OTHER HALF OF D-5. Moving the runner FILE LIST to the index closed "is this runner in the
# clone"; it did NOT close "does that runner call this lane in the clone". The names came from
# `git ls-files` while the bodies were still read with `open()`, so ONE UNSTAGED LINE added to an
# already-tracked runner certified a wiring that exists in nobody's checkout but this one -- the
# same defect wearing the other half of its face. Cross-family review, 2026-08-24, round 2.
# Claiming "the surface is index-grounded" while half of it was not is exactly
# [[feedback_half_fix_propagation_boundary]] / "measured scope != claimed scope".
#
# ONE process, not one per runner: there are ~185 runner surfaces here, and `git show` per file
# would be ~185 forks. `git cat-file --batch` reads them all from one stdin stream.
#
# 🟥 EVERY FAILURE PATH IS UNMEASURED, NEVER AN EMPTY BODY. A missing blob, a short read, a
# non-blob object, a git that will not start -- each of them, read as "" , renders the runner as
# calling nothing, which is the fold this whole file exists to refuse. They collect in _BLOB_ERR
# and route to the same UNMEASURED exit as a broken index does.
# In `nongit` / `outside-index` there is no blob to read and that is already decided policy
# (protection off, labelled) -- the loader is simply not run, and the disk reader stays in place.
# No new state value.
_BLOBS = {}
_BLOB_ERR = []

def _load_index_blobs(paths):
    if INDEX_MODE != 'index' or not paths:
        return
    # `git cat-file --batch` reads NEWLINE-delimited input, so a path containing one cannot be
    # asked for safely. Refuse to guess: that is UNMEASURED, not "this runner calls nothing".
    for _p in paths:
        if '\n' in _p:
            _BLOB_ERR.append('a runner path contains a newline and cannot be batched: ' + repr(_p))
    if _BLOB_ERR:
        return
    _inp = ''.join(':' + _p + '\n' for _p in paths)
    try:
        _pr = subprocess.run(['git', 'cat-file', '--batch'], input=_inp.encode('utf-8'), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except OSError as _e:
        _BLOB_ERR.append('git cat-file could not be started: ' + str(_e))
        return
    if _pr.returncode != 0:
        _BLOB_ERR.append('git cat-file --batch exited ' + str(_pr.returncode))
        return
    _buf = _pr.stdout
    _pos = 0
    for _p in paths:
        _nl = _buf.find(b'\n', _pos)
        if _nl < 0:
            _BLOB_ERR.append('git cat-file output ended early at ' + _p)
            return
        _hdr = _buf[_pos:_nl].decode('utf-8', 'replace').split()
        _pos = _nl + 1
        if len(_hdr) != 3 or _hdr[1] != 'blob':
            _BLOB_ERR.append('no blob in the index for ' + _p + ': ' + ' '.join(_hdr))
            return
        _sz = int(_hdr[2])
        _end = _pos + _sz
        if _end > len(_buf):
            _BLOB_ERR.append('git cat-file returned a short body for ' + _p)
            return
        _BLOBS[_p] = _buf[_pos:_end].decode('utf-8', 'replace')
        _pos = _end + 1
    # Completeness, checked rather than assumed, and INSIDE the loader so that the loader is a
    # single switch: this is what makes the disk fallback in read_runner unreachable for a runner
    # in index mode. Without it a silently missing key would fall through to the working tree and
    # rebuild the defect one path at a time.
    for _p in paths:
        if _p not in _BLOBS:
            _BLOB_ERR.append('the index blob for ' + _p + ' was never read')

_load_index_blobs(runners)

def _read_disk(path):
    try:
        return open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return ''

def read_runner(path):
    # index mode: every runner is in _BLOBS (asserted above), so the disk branch is reachable only
    # for surfaces that are deliberately NOT index-backed -- the gitignored local settings file --
    # and for the nongit / outside-index states.
    if path in _BLOBS:
        return _BLOBS[path]
    return _read_disk(path)

if _BLOB_ERR:
    print('CONTROL_FAILED\tthe runner CONTENT is UNMEASURED, not empty: ' + ' - '.join(_BLOB_ERR))
    raise SystemExit(2)

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
        txt = read_runner(r)
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

# ── Embedded --self-test dispatchers — a class the name-pattern `suites` glob cannot see ──────
# Measured 2026-08-13, the header of this file, §WHAT DEBT:0 DOES NOT MEAN: a lane suite that
# lives INSIDE its subject as a `--self-test` flag — not a separate `test_*.sh`/`*_lanes.sh` file
# — is structurally invisible to the glob above. When this block was written, 4 such scripts were
# known and none showed up as WIRED or UNWIRED anywhere in this report.
# ⚠️ Do not read that 4 as a current figure, and do not re-list the names here. The set is
# DISCOVERED at run time by `_st_candidates` below and the live figure is printed in this file's
# own SELFTEST_COUNTS line, so a hand-maintained example list beside a self-discovering scan is a
# second source of truth that goes stale in silence. That is not hypothetical: the previous
# version of this comment named a 4th example the code no longer agreed with, and the session that
# noticed had to trace the discrepancy to ground by hand.
# The wiring line for the subjects that ARE wired,
# the `for _subj in ...` loop in scripts/selfcheck.sh, could be deleted and nothing here would
# go red. found→extend, not a new file: same idiom as `suites`/`has_runner` above — discover
# subjects, detect dispatch, report undeclared — new predicates for the shape this pattern uses.
#
# 🟥 A PARENTHESIS TRAP LIVES IN THIS SPECIFIC HEREDOC, READ BEFORE ADDING A LINE HERE.
# Measured 2026-08-14: a single heredoc-body line whose own paren count was unbalanced — one more
# close-paren than open-paren, from a regex needing a literal close-paren character — broke bash's
# parse of every line after it, on THIS file only. The reason is that the heredoc below sits inside
# a command-substitution wrapper, and that wrapper's own close-paren-matching scan turned out not
# to be fully heredoc-blind in the bash build this repo has tested. `bash -n` then failed dozens of
# lines later with an unrelated-looking error, because by then the parser believed the heredoc had
# already closed. Reproduced in isolation: a bare regex assignment needing a literal close-paren,
# spliced into this file at this exact position, alone, with nothing else added. The fix is
# structural, not "be careful" — every line added inside this heredoc must carry a matched
# open-paren and close-paren count on that same line, and a matched pair spanning two lines is
# exactly the shape that tripped this the first time. Collapse it back to one line, or spell the
# literal paren out as an escape sequence instead of a bare character, rather than splitting it
# across lines.
# A bare substring match on --self-test would also catch prose that only DISCUSSES the flag
# (measured: scripts/selfcheck.sh's `_subj` loop carries a comment naming it as what NOT to grep
# for, which is exactly the false positive this narrower check exists to avoid). Require one of
# the two real dispatcher shapes instead: `"--self-test"` in a quoted comparison, or `--self-test)`
# as a bare case-pattern. The close-paren is built via chr — see the paren-trap note above; a
# literal `)` character on this line, however it is spelled, throws this file's parser off.
_CP = chr(41)
SELFTEST_DISPATCH_FORMS = ('"--self-test"', '--self-test' + _CP)

def _read(path):
    try:
        return open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return ''

# 🟥 NAMED RESIDUALS in the self-test branch — two asymmetries the 2026-08-15 repair did NOT close,
# written here because this file names its other residuals and silence would read as coverage.
#   1. Comment-stripping is LINE-PREFIX only. A dispatch line living inside a heredoc body or
#      inside an echoed string is not a comment and still counts as a live caller. Symmetric with
#      runner_dispatches, which has the same limit — so "symmetry restored" is true, and the shared
#      blind spot survives in both. In-tree example of the shape: the heredoc fixtures in
#      scripts/test_lane_runner_lanes.sh. Harmless today only because those name a fixture subject.
#   2. Subject DISCOVERY below still reads comments. `_st_names` matches the raw dispatcher forms
#      anywhere in the file, so a comment that merely mentions the flag can enrol a script as a
#      self-test subject. Real case: chamber_witness.sh carries the flag inside a usage comment.
#      Harmless today because that file also has a real dispatcher — but it means "a mention is not
#      a declaration" is enforced on the RUNNER side and not on the SUBJECT side.
# Neither is mechanized: closing them means parsing shell rather than scanning lines, which is the
# Grep-Collision Treadmill this repo has already logged. Fix on the first case that actually bites.
#
# One line on purpose — see the paren-trap note above the SELFTEST_PAT definition.
_st_candidates = [f for f in glob.glob('scripts/*.sh') if os.path.basename(f) not in suites and os.path.basename(f) != 'lane_runner_check.sh']
_st_names = [os.path.basename(f)[:-3] for f in _st_candidates if any(_form in _read(f) for _form in SELFTEST_DISPATCH_FORMS)]
selftest_subjects = sorted(set(_st_names))

def selftest_dispatched(bare_name, txt):
    """Two shapes, both real in this repo. Cross-family review (2026-08-14) caught the first draft
    shipping only the second — it read scripts/selfcheck.sh's `_subj` for-loop but missed that
    file's direct `bash scripts/probe_scope_check.sh --self-test` / `bash scripts/
    utterance_landing_check.sh --self-test`, so those two subjects were reported UNDECLARED while
    selfcheck.sh runs them every time. This is the exact failure the header above names by cite —
    a reader trusting the count over the source would have been told a false thing with confidence.

    Shape 1 (direct): `bash scripts/<name>.sh ... --self-test` on one line — mirrors
    runner_dispatches' direct branch, structurally simpler than the indirect case below.
    Shape 2 (indirect): bare_name sits in a `for VAR in ... bare_name ...; do` loop whose body
    dispatches $VAR with --self-test — mirrors the indirect-branch reasoning of runner_dispatches:
    the literal name is in a list construct, the invocation runs through the loop variable, so a
    direct-dispatch grep alone structurally cannot see it (selfcheck.sh's `for _subj in ...` loop).

    Comment lines are dropped first, exactly as runner_dispatches does for ordinary suites: "a
    mention is not an invocation" applies identically here, and until 2026-08-15 it was enforced in
    only one of the two predicates. Measured: a `#   bash scripts/x.sh --self-test` usage line
    matched the direct regex and certified a subject nothing ran."""
    _body = '\n'.join(_l for _l in txt.split('\n') if not _l.strip().startswith('#'))
    if re.search(rf'\bbash\s+scripts/{re.escape(bare_name)}\.sh\b[^\n]*--self-test', _body):
        return True
    in_loop = False; loop_var = None; has_name = False
    for ln in _body.split('\n'):
        s = ln.strip()
        m = re.match(r'for\s+(\w+)\s+in\b(.*)', s)
        if m:
            loop_var = m.group(1)
            has_name = bool(re.search(rf'\b{re.escape(bare_name)}\b', m.group(2)))
            in_loop = True
            continue
        if in_loop:
            if has_name and '--self-test' in ln and re.search(rf'\${{?{re.escape(loop_var)}\b', ln):
                return True
            if s == 'done':
                in_loop = False; loop_var = None; has_name = False
    return False

def has_selftest_runner(bare_name):
    # A subject does not wire itself. has_runner() has skipped a suite's own file since this file
    # was written; this branch did not, and the asymmetry was invisible because nothing exercised
    # it — the only in-file control drove selftest_dispatched with synthetic text, never the
    # runner set.
    # ⚠️ Attribution, kept precise because a cross-family round caught it being loose: the 2026-08-15
    # incident — directional_diff_gate.sh dispatched by nothing while the report said 10/10 — was
    # caused by the COMMENT half, and comment-stripping alone closes it. Every self-reference in
    # this tree at that date was a `#` line; a non-comment one existed nowhere. So this guard is
    # SYMMETRY, not a repair of an observed case: it covers the shape where a subject names its own
    # dispatch in live code, such as a usage helper. That shape is pinned by lane L16, which was
    # added at the same time and for the same reason — without it this line is a repair no control
    # drives, which is the failure mode this file exists to name.
    _own = bare_name + '.sh'
    return any(selftest_dispatched(bare_name, read_runner(r)) for r in runners if os.path.basename(r) != _own)

selftest_wired = {s for s in selftest_subjects if has_selftest_runner(s)}
selftest_undeclared = sorted(s for s in selftest_subjects if s not in selftest_wired)

# Minimal known-pair — proportionate to the size of this addition, not the full CTL apparatus
# below, but a dead predicate must still be caught rather than trusted on read-through alone.
_ST_POS_FIXTURE = 'for _subj in alpha beta; do\n  bash "scripts/$_subj.sh" --self-test\ndone\n'
_ST_NEG_FIXTURE = 'for _subj in alpha beta; do\n  bash "scripts/$_subj.sh" --normal-run\ndone\n'
if not selftest_dispatched('alpha', _ST_POS_FIXTURE):
    print("CONTROL_FAILED\tself-test known-positive fixture read as undispatched — detector is blind")
    raise SystemExit(2)
if selftest_dispatched('alpha', _ST_NEG_FIXTURE):
    print("CONTROL_FAILED\tself-test known-negative fixture with no --self-test flag read as dispatched")
    raise SystemExit(2)
# Second known-negative, added 2026-08-15 with the comment-skip repair. Without it the repair is a
# line of code no control drives — the failure mode this whole file exists to name.
_ST_CMT_FIXTURE = '#   bash scripts/alpha.sh --self-test   # usage example, not a caller\n'
if selftest_dispatched('alpha', _ST_CMT_FIXTURE):
    print("CONTROL_FAILED\tself-test commented usage line read as a live dispatcher")
    raise SystemExit(2)

# ── CONTROL: the instrument must be able to see a suite known to be wired, and must NOT see one
# known to be dead. Without both arms a broken detector reports "all clean" or "all broken" and
# either reads as a verdict. [[feedback_absence_measurement_needs_control]]
CTL_POS  = 'test_selfcheck_state_lanes.sh'    # selfcheck.sh invokes this DIRECTLY
CTL_POS2 = 'test_session_close_lanes.sh'      # selfcheck.sh's `_anchor` for-list + `bash "$_anchor"` — the
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
print(f"SELFTEST_COUNTS\t{len(selftest_subjects)}\t{len(selftest_wired)}")
for s in selftest_undeclared:
    print(f"SELFTEST_UNDECLARED\t{s}")
PY
)
rc=$?
[ -n "${FH_INDEX_FILE_LIST:-}" ] && rm -f "$FH_INDEX_FILE_LIST"

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

SELFTEST_COUNTS=$(printf '%s\n' "$out" | awk -F'\t' '$1=="SELFTEST_COUNTS"{print $2" "$3}')
set -- $SELFTEST_COUNTS
ST_TOTAL="${1:-0}"; ST_WIRED="${2:-0}"
SELFTEST_UNDECLARED=$(printf '%s\n' "$out" | awk -F'\t' '$1=="SELFTEST_UNDECLARED"{print $2}')
ST_UNDECLARED_N=0
if [ -n "$SELFTEST_UNDECLARED" ]; then
  ST_UNDECLARED_N=$(printf '%s\n' "$SELFTEST_UNDECLARED" | wc -l | tr -d ' ')
  # Advisory, not blocking — these are pre-existing (measured 2026-08-13, before this check saw
  # them at all), not something introduced by whatever change is running this check right now.
  # Same DEBT philosophy as above: loudly counted, never silent, must only go down from here.
  echo "⚠️  lane-runner: ${ST_UNDECLARED_N} embedded --self-test subject(s) with no --self-test"
  echo "    dispatcher anywhere (self-test code exists, nothing calls it — see this file's own"
  echo "    §Embedded --self-test comment for why the suites glob above cannot see this class):"
  printf '%s\n' "$SELFTEST_UNDECLARED" | sed 's/^/        /'
  echo "    Fix by wiring \`bash scripts/<name>.sh --self-test\` into scripts/selfcheck.sh, by"
  echo "    ONE of its two shapes — and the choice is decided by the subject's own output, not"
  echo "    by which is shorter. The \`for _subj in ...\` loop gates on the substring 캘리브레이션;"
  echo "    a subject whose terminal verdict is worded any other way goes red there for a reason"
  echo "    that has nothing to do with its lanes — capability_registry_check was added to that"
  echo "    loop and reverted for exactly this. Such a subject takes the second shape: its own"
  echo "    direct-dispatch block, as capability_registry_check.sh and relay_channel.sh do there."
  echo "    🟥 In that second shape do NOT gate on the exit code alone. Measured 2026-08-15 on"
  echo "    directional_diff_gate: a suite whose lanes were all deleted still printed a PASS"
  echo "    verdict and exited 0, and a usage banner carrying the same words satisfied a"
  echo "    substring match. Require the terminal verdict AS A WHOLE LINE, with a non-zero count"
  echo "    in it, or exit 0 will certify a suite that ran nothing."
fi

INDEX_MODE=$(printf '%s\n' "$out" | awk -F'\t' '$1=="INDEX_MODE"{print $2}')
INDEX_WHY=$(printf '%s\n' "$out" | awk -F'\t' '$1=="INDEX_MODE"{print $3}')
# Labelled, never silent, and the two disk-fallback states are NOT merged. `nongit` is an
# unpacked tarball; `outside-index` is this tree sitting inside some OTHER repo that ignores it.
# Both are correct places to read the disk, and neither may appear inside a normal checkout --
# if one does, the WIRED count is not index-grounded and the reader has to know that.
case "$INDEX_MODE" in
  nongit|outside-index)
    echo "⚠️  lane-runner: runner surface enumerated from DISK, not the index ($INDEX_MODE)."
    echo "    $INDEX_WHY"
    echo "    Correct outside a checkout; WRONG inside one. It is not zero runners either way."
    ;;
esac

echo "PASS  lane-runner: ${TOTAL} suites — ${WIRED} wired · ${N_EXEMPT} exempt · ${N_DEBT} declared debt" \
     "· self-test: ${ST_WIRED}/${ST_TOTAL} wired"
exit 0
