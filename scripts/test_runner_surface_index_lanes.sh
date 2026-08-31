#!/usr/bin/env bash
# test_runner_surface_index_lanes.sh — the known pair for defect D-5 and for the two defects the
# first repair of D-5 introduced.
#
# WHAT D-5 WAS. `scripts/lane_runner_check.sh` and `scripts/script_caller_ratchet.sh` both answer
# "is this thing WIRED?" by looking for a caller among a list of RUNNER SURFACES. Both enumerated
# that surface with `glob.glob`, i.e. against the WORKING TREE. So a file that existed only in
# this working copy counted as a caller. It was green that `git clone` would have deleted.
#
# WHAT THE FIX IS, AND WHAT IT DELIBERATELY IS NOT. Only the RUNNER surface moved to the git index.
# The POPULATION globs (which files get CHECKED) stay on disk on purpose: there an untracked file
# must be SEEN so a new uncommitted script goes red. Moving both would trade one silent pass for
# another, so this suite pins BOTH directions — the tracked-runner lanes below are the over-block
# control and are as load-bearing as the untracked ones.
#
# 🟥 THE FIRST REPAIR SHIPPED TWO DEFECTS OF ITS OWN. Cross-family review (codex/gpt-5.5, diff
# axis, 2026-08-24) found them and executed the first:
#   S  every non-zero `git ls-files` exit was folded into "no index, use the disk". A fake `git`
#      that exits 1 for everything printed a warning and then PASSED. A missing binary, a corrupt
#      or locked index and a permission failure all shared a branch with an unpacked tarball, so
#      the repair against "green a clone deletes" installed a fresh green of its own — and the
#      asymmetry was backwards, since an EMPTY result was already routed to UNMEASURED.
#      L12–L15 pin the split; L16–L17 execute the fail-before.
#   ①  `*` -> `[^/]*` is WIDER than the `glob.glob()` it replaced: glob hides dotfiles, the regex
#      did not, so a hidden TRACKED file would certify a caller the old surface never contained.
#      L18–L20 pin it, on BOTH dot spellings, L21–L22 execute the fail-before.
#
# 🟥 WHY THIS SUITE EXISTS AT ALL. On the day of the fix the behaviour change was ZERO: every
# runner surface in this tree happened to be tracked. "It still passes" is therefore not evidence
# of anything. The only evidence available is a FAIL-BEFORE executed on the pre-fix code — the
# lanes marked "fail-before" do exactly that, by mechanically reverting ONE named line in a
# scratch copy and asserting the defect reproduces there. Each revert self-confirms (the anchor
# must appear exactly once, and the rewritten copy is re-read to prove the swap landed); if an
# anchor ever stops matching, those lanes go red as WRONG-TARGET rather than passing on an
# unmodified copy.
#
# Fixtures are materialised as real files in a real throwaway `git init` repo, never as strings
# handed to a re-implementation of the predicate: a test double would measure the double.
#
# 🟥 FIXTURE SPELLING. Untracked runners are planted in `.github/workflows/*.yml`, in
# `templates/.git-hooks/*` and in `scripts/*.sh`; the broken-git arm is spelled BOTH as "git is
# entirely unusable" AND as "git works but `ls-files` alone fails" (a repair that only probed
# `git --version` would pass the first and fail the second); the dotfile arm is spelled in a plain
# directory AND inside the `.git-hooks` dot-directory. A partial repair goes red.
#
# Exit: 0 = every lane passed · 1 = a lane failed · 2 = the harness itself could not run.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/.." && pwd)"
LRC="$ROOT/scripts/lane_runner_check.sh"
RAT="$ROOT/scripts/script_caller_ratchet.sh"
for _f in "$LRC" "$RAT"; do
  [ -f "$_f" ] || { echo "FAIL  runner-surface: subject missing: $_f"; exit 2; }
done
REALGIT="$(command -v git 2>/dev/null)"
[ -n "$REALGIT" ] || { echo "FAIL  runner-surface: git unavailable"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL  runner-surface: python3 unavailable"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

# ── fake-git shims ────────────────────────────────────────────────────────────────────────────
# Two spellings, because they discriminate two different half-repairs. `allfail` is the shape the
# cross-family review executed. `lsfail` is the sharper one: `git --version` and `rev-parse` both
# work, so a repair that probes only "is the binary usable" reads the tree as healthy and then
# gets an empty answer from a broken index.
FAKE_ALLFAIL="$WORK/fake_allfail"; mkdir -p "$FAKE_ALLFAIL"
printf '#!/bin/sh\nexit 1\n' > "$FAKE_ALLFAIL/git"; chmod +x "$FAKE_ALLFAIL/git"
FAKE_LSFAIL="$WORK/fake_lsfail"; mkdir -p "$FAKE_LSFAIL"
cat > "$FAKE_LSFAIL/git" <<EOS
#!/bin/sh
case "\$1" in
  ls-files) echo "fatal: index file smaller than expected" >&2; exit 128 ;;
  *) exec "$REALGIT" "\$@" ;;
esac
EOS
chmod +x "$FAKE_LSFAIL/git"

# ── the mechanical revert anchors ─────────────────────────────────────────────────────────────
# One named line per defect, so each fail-before is a single deliberate substitution rather than a
# hand-built "old version" that could drift from what actually shipped.
#   enum  — D-5 itself: runner enumeration goes back to globbing the disk.
#   state — the S-class: the initial state goes back to `nongit`, so EVERY unresolved branch falls
#           through to the disk fallback exactly as the first repair did.
#   dot   — defect ①: the dotfile guard is removed from the segment translator.
_revert_copy() {   # $1 = kind (enum|state|dot) · $2 = src · $3 = dst
  python3 - "$1" "$2" "$3" <<'PY'
import sys
kind, src, dst = sys.argv[1:4]
ANCHORS = {
    'enum': ('runners = enumerate_runners(RUNNER_GLOBS)',
             'runners = [p for pat in RUNNER_GLOBS for p in glob.glob(pat) if os.path.isfile(p)]'),
    'state': ('FH_INDEX_STATE="UNMEASURED"; FH_INDEX_WHY="not determined"; FH_INDEX_FILE_LIST=""',
              'FH_INDEX_STATE="nongit"; FH_INDEX_WHY="not determined"; FH_INDEX_FILE_LIST=""'),
    'dot': ("            _s += '(?!\\\\.)'",
            "            _s += ''  # DOTFILE GUARD REMOVED (fail-before fixture)"),
    'content': ("    if INDEX_MODE != 'index' or not paths:",
                '    if True:  # INDEX BLOB LOADER DISABLED (fail-before fixture)'),
    'isfile': ('        return [_p for _p in INDEX_FILES if any(_r.match(_p) for _r in _rx)]',
               '        return [_p for _p in INDEX_FILES if any(_r.match(_p) for _r in _rx) and os.path.isfile(_p)]'),
}
fixed, prefix = ANCHORS[kind]
t = open(src, encoding='utf-8').read()
if t.count(fixed) != 1:
    print('WRONG-TARGET: the %s anchor appears %d times in %s' % (kind, t.count(fixed), src))
    raise SystemExit(3)
open(dst, 'w', encoding='utf-8').write(t.replace(fixed, prefix, 1))
# step 1 of the control, done mechanically: re-read what was written and prove the swap landed.
# A copy that was not modified would pass the lane below while proving nothing.
back = open(dst, encoding='utf-8').read()
if fixed in back or prefix not in back:
    print('WRONG-TARGET: the %s revert did not land in %s' % (kind, dst))
    raise SystemExit(4)
raise SystemExit(0)
PY
}

# ── fixture builders ──────────────────────────────────────────────────────────────────────────
# `git init` + `git add`, no commit. `git ls-files` reads the INDEX, so staging is enough and the
# fixture never needs a commit, an identity, or a base ref.
_new_repo() {
  local d="$WORK/$1"
  rm -rf "$d"; mkdir -p "$d/scripts" "$d/.github/workflows" "$d/templates/.git-hooks"
  git -C "$d" init -q 2>/dev/null || return 2
  printf '%s' "$d"
}

_write_workflow() {
  cat > "$1" <<YML
name: zz-d5-probe
on: [push]
jobs:
  probe:
    runs-on: ubuntu-latest
    steps:
      - run: bash $2
YML
}
_write_hook() {
  printf '#!/usr/bin/env bash\nbash %s || exit 1\n' "$2" > "$1"
  chmod +x "$1"
}

# runner kind -> relative path. `dotwf` and `dothook` are the two dotfile spellings: a hidden file
# in a plain directory, and a hidden file inside the `.git-hooks` DOT-DIRECTORY. The second is the
# one that reads as already-covered and is not: what glob hides is a leading dot in the matched
# BASENAME, never a dot in a literal directory component.
_runner_path() {
  case "$1" in
    workflow) printf '.github/workflows/zz-d5-probe.yml' ;;
    hook)     printf 'templates/.git-hooks/zz-d5-probe' ;;
    script)   printf 'scripts/zz_d5_runner.sh' ;;
    dotwf)    printf '.github/workflows/.zz-d5-hidden.yml' ;;
    dothook)  printf 'templates/.git-hooks/.zz-d5-hidden' ;;
  esac
}
_write_runner() {  # $1 = kind · $2 = abs path · $3 = dispatch target
  case "$1" in
    workflow|dotwf) _write_workflow "$2" "$3" ;;
    *)              _write_hook     "$2" "$3" ;;
  esac
}

# `unstaged` is the sharpest spelling of the second half of D-5: the runner FILE is tracked, its
# index blob is a real runner, and it even NAMES the target -- in a comment, which is a mention and
# not an invocation. The only dispatch lives in the working tree and has never been staged. A
# repair that greps the blob for the name, or that reads the file list from the index and the body
# from disk, both certify it. Only reading the BODY from the index gets it right.
_write_unstaged_runner() {  # $1 = abs path · $2 = dispatch target · $3 = repo dir · $4 = rel path
  {
    printf 'name: zz-d5-probe\non: [push]\njobs:\n  probe:\n    runs-on: ubuntu-latest\n'
    printf '    steps:\n      # see %s for the calibration this workflow will run one day\n' "$2"
    printf '      - run: echo staged-body-dispatches-nothing\n'
  } > "$1"
  git -C "$3" add "$4" >/dev/null 2>&1 || return 2
  printf '      - run: bash %s\n' "$2" >> "$1"     # working tree ONLY -- never staged
}

PROBE_SUITE='test_zz_d5_probe_lanes.sh'
PROBE_SUBJ='zz_d5_probe_subject.sh'

_lrc_fixture() {   # $1 = tag · $2 = runner kind (or none) · $3 = track? (1|0)
  local d; d="$(_new_repo "$1")" || return 2
  printf '#!/usr/bin/env bash\necho "zz probe lane"\nexit 0\n' > "$d/scripts/$PROBE_SUITE"
  cp "$LRC" "$d/scripts/lane_runner_check.sh"
  git -C "$d" add "scripts/$PROBE_SUITE" >/dev/null 2>&1 || return 2
  if [ "$2" != "none" ]; then
    local runner; runner="$(_runner_path "$2")"
    _write_runner "$2" "$d/$runner" "scripts/$PROBE_SUITE"
    [ "$3" = "1" ] && { git -C "$d" add "$runner" >/dev/null 2>&1 || return 2; }
  fi
  printf '%s' "$d"
}
_rat_fixture() {   # $1 = tag · $2 = runner kind (or none) · $3 = track?
  local d; d="$(_new_repo "$1")" || return 2
  printf '#!/usr/bin/env bash\necho "zz probe subject"\n' > "$d/scripts/$PROBE_SUBJ"
  printf 'exempt:\nbaseline:\n' > "$d/scripts/caller_zero_baseline.txt"
  git -C "$d" add "scripts/$PROBE_SUBJ" "scripts/caller_zero_baseline.txt" >/dev/null 2>&1 || return 2
  if [ "$2" != "none" ]; then
    local runner; runner="$(_runner_path "$2")"
    _write_runner "$2" "$d/$runner" "scripts/$PROBE_SUBJ"
    [ "$3" = "1" ] && { git -C "$d" add "$runner" >/dev/null 2>&1 || return 2; }
  fi
  printf '%s' "$d"
}

_lrc_run() {  # $1 = fixture dir · $2 = script (default: the copy inside) · $3 = PATH prefix
  local script="${2:-$1/scripts/lane_runner_check.sh}"
  if [ -n "${3:-}" ]; then ( cd "$1" && PATH="$3:$PATH" bash "$script" 2>&1 )
  else                     ( cd "$1" && bash "$script" 2>&1 ); fi
}
_rat_run() {  # $1 = fixture dir · $2 = script (default: the real one) · $3 = PATH prefix
  local script="${2:-$RAT}"
  if [ -n "${3:-}" ]; then PATH="$3:$PATH" bash "$script" --root "$1" 2>&1
  else                     bash "$script" --root "$1" 2>&1; fi
}

echo "── D-5 runner surface: lane_runner_check.sh ──────────────────────────────────────────────"

D="$(_lrc_fixture lrc_untracked_wf workflow 0)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_lrc_run "$D")"; RC=$?
if printf '%s' "$OUT" | grep -q "$PROBE_SUITE" && [ "$RC" -ne 0 ]; then
  ok "L1 untracked .github/workflows runner does NOT certify a suite as WIRED"
else
  bad "L1 untracked workflow still certifies the suite (rc=$RC) — D-5 is live"
fi

D="$(_lrc_fixture lrc_tracked_wf workflow 1)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_lrc_run "$D")"; RC=$?
if [ "$RC" -eq 0 ] && ! printf '%s' "$OUT" | grep -q "no runner and no declaration"; then
  ok "L2 TRACKED workflow runner still certifies WIRED (no over-block)"
else
  bad "L2 over-block: a runner that IS in the index was dropped (rc=$RC)"
fi

D="$(_lrc_fixture lrc_untracked_hook hook 0)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_lrc_run "$D")"; RC=$?
if printf '%s' "$OUT" | grep -q "$PROBE_SUITE" && [ "$RC" -ne 0 ]; then
  ok "L3 untracked templates/.git-hooks runner does NOT certify WIRED (second spelling)"
else
  bad "L3 the hook glob still resolves against disk — the repair was partial (rc=$RC)"
fi

D="$(_lrc_fixture lrc_untracked_script script 0)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_lrc_run "$D")"; RC=$?
if printf '%s' "$OUT" | grep -q "$PROBE_SUITE" && [ "$RC" -ne 0 ]; then
  ok "L4 untracked scripts/*.sh runner does NOT certify WIRED (third spelling)"
else
  bad "L4 the scripts glob still resolves against disk (rc=$RC)"
fi

# ── L5: UNMEASURED is not zero ────────────────────────────────────────────────────────────────
D="$(_new_repo lrc_empty_index)" || { echo "FAIL harness: fixture build"; exit 2; }
printf '#!/usr/bin/env bash\nexit 0\n' > "$D/scripts/$PROBE_SUITE"
cp "$LRC" "$D/scripts/lane_runner_check.sh"
OUT="$(_lrc_run "$D")"; RC=$?
if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -qi "UNMEASURED"; then
  ok "L5 empty index in tracked territory → UNMEASURED, refuses to report zero runners"
else
  bad "L5 an empty index was folded into a verdict (rc=$RC)"
fi

# ── L6: no index at all (an unpacked npm tarball) degrades to disk, LABELLED ──────────────────
D="$WORK/lrc_nongit"; rm -rf "$D"; mkdir -p "$D/scripts" "$D/.github/workflows"
printf '#!/usr/bin/env bash\nexit 0\n' > "$D/scripts/$PROBE_SUITE"
cp "$LRC" "$D/scripts/lane_runner_check.sh"
_write_workflow "$D/.github/workflows/zz-d5-probe.yml" "scripts/$PROBE_SUITE"
OUT="$( cd "$D" && bash "$D/scripts/lane_runner_check.sh" 2>&1 )"; RC=$?
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q "nongit"; then
  ok "L6 no repository and no .git above → disk fallback, and the run SAYS so (not zero)"
else
  bad "L6 the non-git degrade is wrong or silent (rc=$RC)"
  printf '%s\n' "$OUT" | tail -4 | sed 's/^/       /'
fi

echo "── D-5 runner surface: script_caller_ratchet.sh ──────────────────────────────────────────"

D="$(_rat_fixture rat_untracked_wf workflow 0)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_rat_run "$D")"; RC=$?
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "$PROBE_SUBJ"; then
  ok "L7 untracked .github/workflows runner does NOT certify a script as having a caller"
else
  bad "L7 untracked workflow still counts as a caller (rc=$RC) — D-5 is live"
fi

D="$(_rat_fixture rat_tracked_wf workflow 1)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_rat_run "$D")"; RC=$?
if [ "$RC" -eq 0 ]; then
  ok "L8 TRACKED workflow runner still counts as a caller (no over-block)"
else
  bad "L8 over-block: a runner that IS in the index was dropped (rc=$RC)"
fi

D="$(_rat_fixture rat_untracked_hook hook 0)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_rat_run "$D")"; RC=$?
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "$PROBE_SUBJ"; then
  ok "L9 untracked templates/.git-hooks runner does NOT count as a caller (second spelling)"
else
  bad "L9 the hook glob still resolves against disk — the repair was partial (rc=$RC)"
fi

# ══ FAIL-BEFORE for D-5 itself ════════════════════════════════════════════════════════════════
echo "── fail-before: D-5 (the pre-fix enumeration, executed) ──────────────────────────────────"

# 🟥 TWO reverts, chained, because the pre-fix code was pre-fix in BOTH halves: it globbed the
# disk for runner NAMES *and* read their BODIES from disk. Reverting only the enumeration leaves
# the blob loader in place, which then correctly reports "no blob in the index for <untracked
# runner>" and goes UNMEASURED — red, but for the wrong reason, and it would not reproduce the
# original green. Each step self-confirms, so a chain that half-applies is WRONG-TARGET.
D="$(_lrc_fixture lrc_failbefore workflow 0)" || { echo "FAIL harness: fixture build"; exit 2; }
MSG="$(_revert_copy enum "$LRC" "$WORK/lrc_enum_step1.sh")" && MSG="$(_revert_copy content "$WORK/lrc_enum_step1.sh" "$D/scripts/lane_runner_check.sh")"; RRC=$?
if [ "$RRC" -ne 0 ]; then
  bad "L10 revert control could not apply: $MSG"
else
  OUT="$(_lrc_run "$D")"; RC=$?
  if [ "$RC" -eq 0 ] && ! printf '%s' "$OUT" | grep -q "no runner and no declaration"; then
    ok "L10 fail-before: pre-fix lane_runner_check reads the UNTRACKED runner as WIRED"
  else
    bad "L10 fail-before did NOT reproduce (rc=$RC) — the fixture is not potent, so L1 proves nothing"
  fi
fi

D="$(_rat_fixture rat_failbefore workflow 0)" || { echo "FAIL harness: fixture build"; exit 2; }
PRE="$WORK/rat_enum_prefix.sh"
MSG="$(_revert_copy enum "$RAT" "$WORK/rat_enum_step1.sh")" && MSG="$(_revert_copy content "$WORK/rat_enum_step1.sh" "$PRE")"; RRC=$?
if [ "$RRC" -ne 0 ]; then
  bad "L11 revert control could not apply: $MSG"
else
  OUT="$(_rat_run "$D" "$PRE")"; RC=$?
  if [ "$RC" -eq 0 ]; then
    ok "L11 fail-before: pre-fix caller-ratchet reads the UNTRACKED runner as a caller"
  else
    bad "L11 fail-before did NOT reproduce (rc=$RC) — the fixture is not potent, so L7 proves nothing"
  fi
fi

# ══ S-CLASS: "git failed" must never be read as "not a repository" ════════════════════════════
# The fixture is a HEALTHY tracked repo. Only the git binary is sabotaged, so any verdict other
# than UNMEASURED means the subject answered a question it could not measure.
echo "── S-class: broken git ≠ no repository ───────────────────────────────────────────────────"

D="$(_lrc_fixture lrc_gitallfail workflow 1)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_lrc_run "$D" "" "$FAKE_ALLFAIL")"; RC=$?
if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -qi "UNMEASURED"; then
  ok "L12 lane-runner: a git that fails everything → UNMEASURED, not a disk-fallback PASS"
else
  bad "L12 a broken git produced a verdict (rc=$RC) — the S-class hole is open"
  printf '%s\n' "$OUT" | tail -3 | sed 's/^/       /'
fi

D="$(_lrc_fixture lrc_gitlsfail workflow 1)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_lrc_run "$D" "" "$FAKE_LSFAIL")"; RC=$?
if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -qi "UNMEASURED"; then
  ok "L13 lane-runner: git healthy but \`ls-files\` broken → UNMEASURED (the sharper spelling)"
else
  bad "L13 a corrupt index passed as a clean tree (rc=$RC) — probing only \`git --version\` is not enough"
  printf '%s\n' "$OUT" | tail -3 | sed 's/^/       /'
fi

D="$(_rat_fixture rat_gitallfail workflow 1)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_rat_run "$D" "" "$FAKE_ALLFAIL")"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -qi "UNMEASURED"; then
  ok "L14 caller-ratchet: a git that fails everything → exit 2 UNMEASURED, not a PASS"
else
  bad "L14 a broken git produced a verdict (rc=$RC) — the S-class hole is open"
  printf '%s\n' "$OUT" | tail -3 | sed 's/^/       /'
fi

D="$(_rat_fixture rat_gitlsfail workflow 1)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_rat_run "$D" "" "$FAKE_LSFAIL")"; RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -qi "UNMEASURED"; then
  ok "L15 caller-ratchet: git healthy but \`ls-files\` broken → exit 2 UNMEASURED"
else
  bad "L15 a corrupt index passed as a clean tree (rc=$RC)"
  printf '%s\n' "$OUT" | tail -3 | sed 's/^/       /'
fi

echo "── fail-before: S-class (the first repair's state fold, executed) ────────────────────────"
# Reverting the initial state to `nongit` restores exactly the first repair's behaviour: every
# unresolved branch falls through to the disk fallback. The fixture below is a HEALTHY repo with
# a TRACKED runner, so the pre-fix code must print a warning and then PASS — which is the thing
# the cross-family review executed and this suite now owns.
D="$(_lrc_fixture lrc_state_failbefore workflow 1)" || { echo "FAIL harness: fixture build"; exit 2; }
MSG="$(_revert_copy state "$LRC" "$D/scripts/lane_runner_check.sh")"; RRC=$?
if [ "$RRC" -ne 0 ]; then
  bad "L16 revert control could not apply: $MSG"
else
  OUT="$(_lrc_run "$D" "" "$FAKE_ALLFAIL")"; RC=$?
  if [ "$RC" -eq 0 ]; then
    ok "L16 fail-before: the first repair PASSES with a totally broken git (defect reproduced)"
  else
    bad "L16 fail-before did NOT reproduce (rc=$RC) — L12/L13 then prove nothing"
  fi
fi

D="$(_rat_fixture rat_state_failbefore workflow 1)" || { echo "FAIL harness: fixture build"; exit 2; }
PRE="$WORK/rat_state_prefix.sh"
MSG="$(_revert_copy state "$RAT" "$PRE")"; RRC=$?
if [ "$RRC" -ne 0 ]; then
  bad "L17 revert control could not apply: $MSG"
else
  OUT="$(_rat_run "$D" "$PRE" "$FAKE_ALLFAIL")"; RC=$?
  if [ "$RC" -eq 0 ]; then
    ok "L17 fail-before: the first repair PASSES with a totally broken git (defect reproduced)"
  else
    bad "L17 fail-before did NOT reproduce (rc=$RC) — L14/L15 then prove nothing"
  fi
fi

# ══ DEFECT ①: dotfile parity with glob.glob ═══════════════════════════════════════════════════
# The runner here is TRACKED — the index question is satisfied — and hidden. `glob.glob` never
# returned it, so the index surface must not either, or the repair widened the surface it was
# supposed to narrow. Both dot spellings, because the `.git-hooks` one reads as already covered.
echo "── defect ①: dotfile parity with glob.glob ───────────────────────────────────────────────"

D="$(_lrc_fixture lrc_dotwf dotwf 1)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_lrc_run "$D")"; RC=$?
if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "$PROBE_SUITE"; then
  ok "L18 a TRACKED hidden .github/workflows/.x.yml does NOT certify WIRED (glob hides dotfiles)"
else
  bad "L18 the index surface is WIDER than the glob.glob it replaced (rc=$RC)"
fi

D="$(_lrc_fixture lrc_dothook dothook 1)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_lrc_run "$D")"; RC=$?
if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "$PROBE_SUITE"; then
  ok "L19 a TRACKED hidden file inside the .git-hooks DOT-DIRECTORY does NOT certify WIRED"
else
  bad "L19 dotfile parity was fixed in one spelling only (rc=$RC)"
fi

D="$(_rat_fixture rat_dothook dothook 1)" || { echo "FAIL harness: fixture build"; exit 2; }
OUT="$(_rat_run "$D")"; RC=$?
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "$PROBE_SUBJ"; then
  ok "L20 caller-ratchet: a TRACKED hidden runner does NOT count as a caller"
else
  bad "L20 caller-ratchet's surface is wider than glob.glob (rc=$RC)"
fi

echo "── fail-before: dotfile guard (removed, executed) ────────────────────────────────────────"
D="$(_lrc_fixture lrc_dot_failbefore dotwf 1)" || { echo "FAIL harness: fixture build"; exit 2; }
MSG="$(_revert_copy dot "$LRC" "$D/scripts/lane_runner_check.sh")"; RRC=$?
if [ "$RRC" -ne 0 ]; then
  bad "L21 revert control could not apply: $MSG"
else
  OUT="$(_lrc_run "$D")"; RC=$?
  if [ "$RC" -eq 0 ]; then
    ok "L21 fail-before: without the guard the hidden runner DOES certify (defect reproduced)"
  else
    bad "L21 fail-before did NOT reproduce (rc=$RC) — L18/L19 then prove nothing"
  fi
fi

D="$(_rat_fixture rat_dot_failbefore dothook 1)" || { echo "FAIL harness: fixture build"; exit 2; }
PRE="$WORK/rat_dot_prefix.sh"
MSG="$(_revert_copy dot "$RAT" "$PRE")"; RRC=$?
if [ "$RRC" -ne 0 ]; then
  bad "L22 revert control could not apply: $MSG"
else
  OUT="$(_rat_run "$D" "$PRE")"; RC=$?
  if [ "$RC" -eq 0 ]; then
    ok "L22 fail-before: without the guard the hidden runner DOES count as a caller"
  else
    bad "L22 fail-before did NOT reproduce (rc=$RC) — L20 then proves nothing"
  fi
fi

# ── L23: a package unpacked INSIDE a repo that ignores it ─────────────────────────────────────
# `git ls-files` answers rc=0 and NOTHING here, which is indistinguishable from an empty index by
# exit code alone. Blocking would red-light every consumer install that lives under a gitignored
# node_modules, which this repo's own doctrine calls a bypass trainer — so it degrades to disk and
# says which of the two disk states it is in.
echo "── outside-index (a package unpacked inside another repo) ────────────────────────────────"
D="$(_new_repo lrc_outside)" || { echo "FAIL harness: fixture build"; exit 2; }
printf 'vendor/\n' > "$D/.gitignore"
git -C "$D" add .gitignore >/dev/null 2>&1
mkdir -p "$D/vendor/pkg/scripts" "$D/vendor/pkg/.github/workflows"
printf '#!/usr/bin/env bash\nexit 0\n' > "$D/vendor/pkg/scripts/$PROBE_SUITE"
cp "$LRC" "$D/vendor/pkg/scripts/lane_runner_check.sh"
_write_workflow "$D/vendor/pkg/.github/workflows/zz-d5-probe.yml" "scripts/$PROBE_SUITE"
OUT="$( cd "$D/vendor/pkg" && bash scripts/lane_runner_check.sh 2>&1 )"; RC=$?
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q "outside-index"; then
  ok "L23 ignored subtree → labelled outside-index disk fallback, not a red gate on every install"
else
  bad "L23 an ignored subtree was misrouted (rc=$RC)"
  printf '%s\n' "$OUT" | tail -4 | sed 's/^/       /'
fi

# ══ D-5, SECOND HALF: the runner's BODY must come from the index too ══════════════════════════
echo "── second half: tracked runner + UNSTAGED dispatch line ──────────────────────────────────"

D="$(_lrc_fixture lrc_unstaged none 0)" || { echo "FAIL harness: fixture build"; exit 2; }
_write_unstaged_runner "$D/.github/workflows/zz-d5-probe.yml" "scripts/$PROBE_SUITE" "$D" ".github/workflows/zz-d5-probe.yml"
OUT="$(_lrc_run "$D")"; RC=$?
if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "$PROBE_SUITE"; then
  ok "L24 an UNSTAGED dispatch line in a TRACKED runner does NOT certify WIRED"
else
  bad "L24 working-tree-only wiring still counts (rc=$RC) — only half the surface is index-grounded"
  printf '%s\n' "$OUT" | tail -3 | sed 's/^/       /'
fi

D="$(_rat_fixture rat_unstaged none 0)" || { echo "FAIL harness: fixture build"; exit 2; }
_write_unstaged_runner "$D/.github/workflows/zz-d5-probe.yml" "scripts/$PROBE_SUBJ" "$D" ".github/workflows/zz-d5-probe.yml"
OUT="$(_rat_run "$D")"; RC=$?
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "$PROBE_SUBJ"; then
  ok "L25 caller-ratchet: an UNSTAGED dispatch line does NOT count as a caller"
else
  bad "L25 working-tree-only wiring still counts as a caller (rc=$RC)"
  printf '%s\n' "$OUT" | tail -3 | sed 's/^/       /'
fi

echo "── fail-before: runner body read from disk (executed) ────────────────────────────────────"
D="$(_lrc_fixture lrc_content_failbefore none 0)" || { echo "FAIL harness: fixture build"; exit 2; }
_write_unstaged_runner "$D/.github/workflows/zz-d5-probe.yml" "scripts/$PROBE_SUITE" "$D" ".github/workflows/zz-d5-probe.yml"
MSG="$(_revert_copy content "$LRC" "$D/scripts/lane_runner_check.sh")"; RRC=$?
if [ "$RRC" -ne 0 ]; then
  bad "L26 revert control could not apply: $MSG"
else
  OUT="$(_lrc_run "$D")"; RC=$?
  if [ "$RC" -eq 0 ]; then
    ok "L26 fail-before: reading the body from disk certifies the unstaged line (defect reproduced)"
  else
    bad "L26 fail-before did NOT reproduce (rc=$RC) — L24 then proves nothing"
  fi
fi

D="$(_rat_fixture rat_content_failbefore none 0)" || { echo "FAIL harness: fixture build"; exit 2; }
_write_unstaged_runner "$D/.github/workflows/zz-d5-probe.yml" "scripts/$PROBE_SUBJ" "$D" ".github/workflows/zz-d5-probe.yml"
PRE="$WORK/rat_content_prefix.sh"
MSG="$(_revert_copy content "$RAT" "$PRE")"; RRC=$?
if [ "$RRC" -ne 0 ]; then
  bad "L27 revert control could not apply: $MSG"
else
  OUT="$(_rat_run "$D" "$PRE")"; RC=$?
  if [ "$RC" -eq 0 ]; then
    ok "L27 fail-before: reading the body from disk certifies the unstaged line (defect reproduced)"
  else
    bad "L27 fail-before did NOT reproduce (rc=$RC) — L25 then proves nothing"
  fi
fi

# ══ A-CLASS: the working tree must not decide an index-grounded population ════════════════════
# The runner is TRACKED and its blob dispatches the target; only the working-tree FILE is gone
# (`rm`, deliberately NOT `git rm` — the index entry survives). In a clone that wiring exists, so
# WIRED is the correct answer. The pre-fix code filtered the index list by `os.path.isfile` and
# therefore dropped the runner entirely — a FALSE RED, and worse, it slipped past the completeness
# check that exists to turn "could not read" into UNMEASURED.
# 🟥 Recorded divergence: the brief expected the post-fix verdict to be UNMEASURED/red. Measured,
# it is green, and green is right — the blob is readable, so there is nothing unmeasured. What the
# fix removes is the working tree's vote, not the runner.
echo "── A-class: tracked runner deleted from the WORKING TREE only ────────────────────────────"

D="$(_lrc_fixture lrc_wt_deleted workflow 1)" || { echo "FAIL harness: fixture build"; exit 2; }
rm -f "$D/$(_runner_path workflow)"
OUT="$(_lrc_run "$D")"; RC=$?
if [ "$RC" -eq 0 ] && ! printf '%s' "$OUT" | grep -q "no runner and no declaration"; then
  ok "L28 a TRACKED runner missing from the worktree still counts — the index is the authority"
else
  bad "L28 the working tree removed a runner from an index-grounded population (rc=$RC)"
  printf '%s\n' "$OUT" | tail -3 | sed 's/^/       /'
fi

D="$(_rat_fixture rat_wt_deleted workflow 1)" || { echo "FAIL harness: fixture build"; exit 2; }
rm -f "$D/$(_runner_path workflow)"
OUT="$(_rat_run "$D")"; RC=$?
if [ "$RC" -eq 0 ]; then
  ok "L29 caller-ratchet: same — a worktree-deleted tracked runner is still a caller"
else
  bad "L29 the working tree removed a runner from an index-grounded population (rc=$RC)"
  printf '%s\n' "$OUT" | tail -3 | sed 's/^/       /'
fi

echo "── fail-before: isfile filter over the index list (executed) ─────────────────────────────"
D="$(_lrc_fixture lrc_isfile_failbefore workflow 1)" || { echo "FAIL harness: fixture build"; exit 2; }
rm -f "$D/$(_runner_path workflow)"
MSG="$(_revert_copy isfile "$LRC" "$D/scripts/lane_runner_check.sh")"; RRC=$?
if [ "$RRC" -ne 0 ]; then
  bad "L30 revert control could not apply: $MSG"
else
  OUT="$(_lrc_run "$D")"; RC=$?
  if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "$PROBE_SUITE"; then
    ok "L30 fail-before: the isfile filter silently drops the tracked runner (defect reproduced)"
  else
    bad "L30 fail-before did NOT reproduce (rc=$RC) — L28 then proves nothing"
  fi
fi

D="$(_rat_fixture rat_isfile_failbefore workflow 1)" || { echo "FAIL harness: fixture build"; exit 2; }
rm -f "$D/$(_runner_path workflow)"
PRE="$WORK/rat_isfile_prefix.sh"
MSG="$(_revert_copy isfile "$RAT" "$PRE")"; RRC=$?
if [ "$RRC" -ne 0 ]; then
  bad "L31 revert control could not apply: $MSG"
else
  OUT="$(_rat_run "$D" "$PRE")"; RC=$?
  if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "$PROBE_SUBJ"; then
    ok "L31 fail-before: the isfile filter silently drops the tracked runner (defect reproduced)"
  else
    bad "L31 fail-before did NOT reproduce (rc=$RC) — L29 then proves nothing"
  fi
fi

# ══ B-CLASS: a NEWLINE in a tracked path ══════════════════════════════════════════════════════
# `git ls-files -z` exists so that such a path survives transport. An earlier draft translated the
# NULs back to newlines into an env var, which split this fixture into two bogus paths before the
# scan ever ran. The list now travels as a FILE and is split on NUL; the path then reaches the
# batch loader, which refuses it (cat-file --batch input is newline-delimited) and routes to
# UNMEASURED rather than guessing. Not creatable on every filesystem — if it cannot be built here,
# this lane reports UNMEASURED and neither passes nor fails, which is the honest value.
echo "── B-class: a newline inside a tracked path ──────────────────────────────────────────────"
D="$(_lrc_fixture lrc_newline none 0)" || { echo "FAIL harness: fixture build"; exit 2; }
NLNAME="$(printf 'zz-d5\nnl.yml')"
if printf 'run: bash scripts/%s\n' "$PROBE_SUITE" > "$D/.github/workflows/$NLNAME" 2>/dev/null \
   && git -C "$D" add -- ".github/workflows/$NLNAME" >/dev/null 2>&1; then
  OUT="$(_lrc_run "$D")"; RC=$?
  if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "newline"; then
    ok "L32 a newline in a tracked runner path → UNMEASURED, never silently split into two paths"
  else
    bad "L32 a newline path was mis-handled (rc=$RC)"
    printf '%s\n' "$OUT" | tail -3 | sed 's/^/       /'
  fi
else
  echo "  ⬜ L32 UNMEASURED — this filesystem would not accept a newline in a filename, so the"
  echo "       transport fix is unexercised here. Not a pass and not a failure."
fi

echo "──────────────────────────────────────────────────────────────────────────────────────────"
echo "runner-surface-index 캘리브레이션: PASS $PASS · FAIL $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
