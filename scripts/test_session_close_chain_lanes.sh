#!/usr/bin/env bash
# test_session_close_chain_lanes.sh — known-pair anchors for the close-chain steps that had NO
# mechanical lane: ① (status snapshot) · ①-b (open-PR sweep) · ④-log (real-time completion log, the
# only exit-1 FAIL path besides ⑤) · ④-b (npm freshness + BIDIRECTIONAL entry-point drift) ·
# and the pre-push SURFACE MATCHING (ordinary push advises · FH_SESSION_CLOSE=1 push blocks).
#
# Already anchored elsewhere, deliberately NOT duplicated here:
#   ②, ⑤ card-last          → scripts/test_session_close_lanes.sh
#   ⑤-b card-drift probe    → scripts/test_card_drift_probe.sh (incl. the locale-divergence leg)
#   pre-push stdin/ordering → scripts/test_prepush_stdin_integrity.sh
#
# CALIBRATION RULE OBSERVED THROUGHOUT: every lane that asserts an ABSENCE is paired with a
# known-POSITIVE built from the SAME fixture family, so "passed because the guard worked" is
# distinguishable from "passed because nothing ran". Exit codes are read DIRECTLY off the
# subject (never through a pipe — `cmd | tail; echo $?` reads tail's status and has produced
# false green in this repo four times).
#
# ⓘ GAP lanes: places where the subject's CURRENT behaviour is believed WRONG (fail-open, or a
# spec/code disagreement). They pin the observed behaviour but never fail the suite; if the
# behaviour changes they announce "GAP CLOSED" so the lane gets promoted instead of silently
# rotting. They are counted and printed separately — a green summary here does NOT mean the
# chain is fully guarded.
#
# Exit 0 = every asserting lane calibrated · exit 1 = the gate's instrument is wrong.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK="$SCRIPT_DIR/session_close_check.sh"
HOOK="$ROOT/templates/.git-hooks/pre-push"
TODAY=$(date +%Y-%m-%d)
FAILED=0
PASSED=0
GAPS=0

[ -f "$CHECK" ] || { echo "FAIL  subject missing: $CHECK"; exit 1; }
[ -f "$HOOK" ]  || { echo "FAIL  subject missing: $HOOK";  exit 1; }

TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/fh_close_lanes.XXXXXX")
trap 'rm -rf "$TMPROOT"' EXIT

_pass() { echo "✅ $1"; PASSED=$((PASSED+1)); }
_fail() { echo "❌ $1"; FAILED=1; }

# assert a line IS / IS NOT present in captured output
_line() {  # $1=name $2=pattern $3=expect(0/1) $4=output
  local hit=0
  printf '%s\n' "$4" | grep -q -- "$2" && hit=1
  if [ "$hit" = "$3" ]; then _pass "$1 (hit=$hit, expected=$3)"
  else _fail "$1 — hit=$hit, expected=$3"; printf '%s\n' "$4" | sed 's/^/       │ /'; fi
}

_rc() {  # $1=name $2=actual $3=expected
  if [ "$2" = "$3" ]; then _pass "$1 (exit=$2, expected=$3)"
  else _fail "$1 — exit=$2, expected=$3"; fi
}

# GAP lane: pins believed-wrong behaviour without failing the suite.
_gap() {  # $1=name $2=observed-condition-result(0/1 as evaluated by caller) $3=note
  if [ "$2" = "1" ]; then
    echo "ⓘ GAP (still open) $1"
    echo "       ↳ $3"
    GAPS=$((GAPS+1))
  else
    echo "🎉 GAP CLOSED — $1 : behaviour changed, promote this lane to an asserting one"
  fi
}

# ── fixture builders ─────────────────────────────────────────────────────────────
_repo() {  # $1=dirname ; makes a git repo with one commit dated $2 (default now)
  local T="$TMPROOT/$1" when="${2:-}"
  mkdir -p "$T"
  (
    cd "$T" || exit 1
    git init -q . 2>/dev/null
    git config user.email anchor@local
    git config user.name anchor
    echo seed > unrelated.txt
    # tracks/ is gitignored in the real repo too — without this the fixture's own card+log show up
    # as untracked paths and ①'s "clean tree" lane can never be built (self-inflicted dirt).
    printf 'tracks/\nbin/\n' > .gitignore
    git add -A
    if [ -n "$when" ]; then
      GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" git commit -qm seed
    else
      git commit -qm seed
    fi
    # A real repo HAS an upstream. Without one the close check now (correctly) reports
    # `① UNMEASURED — no upstream`, which is not the state any of these lanes means to express —
    # a fixture with no upstream cannot assert "clean tree, nothing unpushed" because the second
    # half of that sentence is genuinely unknown. Every lane below therefore runs on a pushed
    # baseline; upstream ABSENCE is measured on purpose by its own lane (KP-2).
    git init -q --bare "$TMPROOT/$1.git"
    git remote add origin "$TMPROOT/$1.git"
    # `-c core.hooksPath=` : a fixture push must never execute the HOST's git hooks. This repo sets
    # core.hooksPath locally (so a temp repo does not inherit it) but a machine that sets it GLOBALLY
    # would run FH's own pre-push Destructive-Op gate against a throwaway fixture — the suite's result
    # would then depend on the operator's git config rather than on the code under test.
    git -c core.hooksPath= push -q -u origin HEAD
  ) >/dev/null 2>&1
  mkdir -p "$T/tracks/_meta"
  printf '%s' "$T"
}

_card() { printf '# card\n' > "$1/tracks/_meta/reference_next_session_starter.md"; }
# ④ + ⑤ satisfied: completion log first, card LAST (card-last ordering) — so any exit 1 in the
# ① / ①-b lanes is attributable to the leg under test, not to ambient ④/⑤ noise.
_artifacts() { printf -- '- ✅ x\n' > "$1/tracks/_meta/fh_completed_${TODAY}.md"; _card "$1"; }

_run() {  # $1=repo ; sets OUT and RC (RC read directly, no pipe)
  # HERMETIC: stub `gh` to "no open PRs" for every lane that is not specifically testing ①-b.
  # Without this the ambient environment leaked in — the ①-P lane passed only while this operator
  # happened to have zero open PRs, and went red the moment a PR was opened mid-session. A lane
  # that depends on the day's PR count is measuring the environment, not the code.
  mkdir -p "$1/bin"
  { printf '#!/usr/bin/env bash\necho "[]"\nexit 0\n'; } > "$1/bin/gh"
  chmod +x "$1/bin/gh"
  OUT=$(PATH="$1/bin:$PATH" bash "$CHECK" "$1" 2>/dev/null); RC=$?
}

echo "══ ① status snapshot ══"
T=$(_repo one_clean); _artifacts "$T"
_run "$T"
_line "①-P  clean tree → ✅ clean line"            '✅ ① working tree clean' 1 "$OUT"
# Pattern must not match `⚠️  ①-b` — a loose `⚠️  ①` conflated two different steps and made
# this absence assertion answer a question about the OPEN-PR sweep instead of the status snapshot.
_line "①-P  clean tree → no ⚠️ ① line (paired)"   '⚠️  ① '                  0 "$OUT"
_rc   "①-P  clean tree → exit 0" "$RC" 0

T=$(_repo one_dirty); _artifacts "$T"; echo scratch > "$T/uncommitted.txt"
_run "$T"
_line "①-N  uncommitted path → ⚠️ fires"           'uncommitted path'        1 "$OUT"
_line "①-N  uncommitted path → clean line absent"  '✅ ① working tree clean' 0 "$OUT"
_rc   "①-N  uncommitted is ADVISORY, not blocking" "$RC" 0

# unpushed: _repo already pushed the seed, so one extra commit is exactly one unpushed commit
T=$(_repo one_unpushed); _artifacts "$T"
(
  cd "$T" || exit 1
  echo more > second.txt && git add -A && git commit -qm second
) >/dev/null 2>&1
_run "$T"
_line "①-N  unpushed commit → ⚠️ fires"            'unpushed commit'         1 "$OUT"
_line "①-N  unpushed → clean line absent (paired)" '✅ ① working tree clean' 0 "$OUT"

T="$TMPROOT/one_notrepo"; mkdir -p "$T/tracks/_meta"; _artifacts "$T"
_run "$T"
_g=0; printf '%s\n' "$OUT" | grep -q '✅ ① working tree clean' && _g=1
_gap "①  non-repo reports CLEAN" "$_g" \
  "git is unavailable/not a repo → DIRTY=0, UNPUSHED=0 → the check reports '✅ working tree clean'. \
An instrument that could not look is not a clean result (not found ≠ 0). Should say UNSCANNED."

# ── ① not-found ≠ 0 : the five states where git CANNOT answer ────────────────────
# Origin: the fix that introduced these five guards (2026-08-06) listed all six known pairs in its
# COMMIT MESSAGE and shipped none of them as a lane — the code changed, the suite did not, and CI
# went red on the two lanes the change broke rather than on the five it left unmeasured. Prose in a
# commit message is not a regression anchor: nothing re-runs it. Each pair below is
# known-positive (the instrument is blind) + a paired control (the clean line must NOT appear),
# because "the warning fired" and "the warning fired INSTEAD of a false all-clear" are two claims.
# KP-1 (the healthy case) is the ①-P lane at the top of this section.

# KP-2 upstream absent — `@{u}..` fails, prints 0 lines, and `wc -l` counts that 0 as "nothing
# unpushed". A commit that never left the machine reads as pushed. `--unset-upstream` (not
# `remote remove`) keeps a remote present, so the all-branch scan still runs: this isolates the
# upstream leg instead of quietly testing two things at once.
T=$(_repo kp2_no_upstream); _artifacts "$T"
git -C "$T" branch --unset-upstream >/dev/null 2>&1
_run "$T"
_line "KP-2 no upstream → UNMEASURED, not zero"    'unpushed count is UNKNOWN' 1 "$OUT"
_line "KP-2 → clean line absent (paired)"          '✅ ① working tree clean'   0 "$OUT"
_rc   "KP-2 → advisory, not blocking"              "$RC" 0

# KP-3 git status itself fails — a corrupt index makes `status` exit non-zero with EMPTY output,
# and `| wc -l` renders that emptiness as "0 dirty paths" = clean.
T=$(_repo kp3_broken_index); _artifacts "$T"
printf 'garbage' > "$T/.git/index"
_run "$T"
_line "KP-3 corrupt index → cleanliness UNKNOWN"   'cleanliness is UNKNOWN'    1 "$OUT"
_line "KP-3 → clean line absent (paired)"          '✅ ① working tree clean'   0 "$OUT"
# Measured while writing this lane: a corrupt index makes `ls-files -v` exit 128 too, so the
# assume-unchanged probe (MASKED) silently reads 0 — the same not-found-≠-0 shape, one layer in.
# It is NOT a false all-clear (DIRTY_KNOWN=0 already suppresses the clean line), so it is recorded
# as a residual rather than patched here. `rev-parse @{u}` still exits 0 under a corrupt index,
# which is what keeps this lane measuring cleanliness and not accidentally re-measuring KP-2.

# KP-4 measured scope ≠ claimed scope — `@{u}..` reads the CURRENT branch only, while the message
# says "nothing unpushed" about the repo. An unpushed commit parked on another local branch is
# invisible. The current branch stays clean and pushed on purpose: only the other branch is dirty,
# so a green here would be the exact false all-clear.
T=$(_repo kp4_other_branch); _artifacts "$T"
(
  cd "$T" || exit 1
  git checkout -q -b side
  echo side > side.txt && git add -A && git commit -qm side
  git checkout -q -
) >/dev/null 2>&1
_run "$T"
_line "KP-4 unpushed on ANOTHER branch → ⚠️ fires" 'never pushed anywhere'     1 "$OUT"
_line "KP-4 → clean line absent (paired)"          '✅ ① working tree clean'   0 "$OUT"

# KP-5 `status.showUntrackedFiles=no` — git succeeds and stays SILENT (exit 0, empty output), so
# the exit-code guard of KP-3 cannot catch this one. Only `--untracked-files=all` overrides it.
T=$(_repo kp5_untracked_off); _artifacts "$T"
git -C "$T" config status.showUntrackedFiles no
echo hidden > "$T/hidden.txt"
_run "$T"
_line "KP-5 showUntrackedFiles=no → still counted"  'uncommitted path'         1 "$OUT"
_line "KP-5 → clean line absent (paired)"           '✅ ① working tree clean'  0 "$OUT"

# KP-6 assume-unchanged / skip-worktree — edits to a marked TRACKED file never reach porcelain at
# all, so `-uall` does not help either. A separate instrument (`ls-files -v`) has to surface it.
T=$(_repo kp6_assume_unchanged); _artifacts "$T"
git -C "$T" update-index --assume-unchanged unrelated.txt
echo edited >> "$T/unrelated.txt"
_run "$T"
_line "KP-6 assume-unchanged edit → surfaced"       'INVISIBLE here'           1 "$OUT"
_line "KP-6 → clean line absent (paired)"           '✅ ① working tree clean'  0 "$OUT"

echo
echo "══ ①-b open-PR sweep ══"
_ghstub() {  # $1=repo $2=stdout $3=exit
  mkdir -p "$1/bin"
  { printf '#!/usr/bin/env bash\ncat <<'"'"'GHEOF'"'"'\n%s\nGHEOF\nexit %s\n' "$2" "$3"; } > "$1/bin/gh"
  chmod +x "$1/bin/gh"
}
_run_with_gh() {  # $1=repo
  OUT=$(PATH="$1/bin:$PATH" bash "$CHECK" "$1" 2>/dev/null); RC=$?
}

T=$(_repo b_zero); _artifacts "$T"; _ghstub "$T" '[]' 0
_run_with_gh "$T"
_line "①-b-C  no open PRs → no ①-b line (over-fire control)" '①-b' 0 "$OUT"

T=$(_repo b_one); _artifacts "$T"; _ghstub "$T" '[{"number":227}]' 0
_run_with_gh "$T"
_line "①-b-P1 one open PR → sweep line fires"    '①-b 1 open PR' 1 "$OUT"

# COUNT CONSISTENCY. gh emits compact single-line JSON when piped (measured 2026-08-02:
# `[{"number":227},{"number":226},{"number":225}]` on ONE line), so a line-counting `grep -c`
# reports 1 for any non-zero number of PRs. CLAUDE.md ①-b's own origin note pairs this step with
# count-consistency, so a sweep that says "1 open PR" while three are open is a real defect, not
# a cosmetic one — the operator classifies what the sweep names.
T=$(_repo b_three); _artifacts "$T"
_ghstub "$T" '[{"number":227},{"number":226},{"number":225}]' 0
_run_with_gh "$T"
_line "①-b-P3 three open PRs → sweep says 3"     '①-b 3 open PR' 1 "$OUT"

T=$(_repo b_err); _artifacts "$T"; _ghstub "$T" '' 4
_run_with_gh "$T"
_g=0; printf '%s\n' "$OUT" | grep -q '①-b' || _g=1
_gap "①-b gh ERROR is silent (indistinguishable from zero PRs)" "$_g" \
  "gh present but failing (auth/offline, exit 4) → stderr discarded, count 0, NO line printed. \
The sweep 'not run' and the sweep 'found nothing' look identical. Advisory surface, so not \
fail-closed — but it should print 'sweep UNAVAILABLE' rather than nothing."

echo
echo "══ ④-log real-time completion log (the exit-1 FAIL path) ══"
# NOTE the label: this is NOT CLAUDE.md's ④ (memory hygiene, deliberately unmechanized — see
# CLAUDE.md §Session Wrap-up). The block was renamed 2026-08-02 because a green "④" implied memory
# hygiene had been verified when nothing checked it. These lanes follow the renamed label; if they
# ever go green against the OLD string again, the grep has stopped matching and the pair below is
# passing vacuously.
# The card is present and NEWEST in both ④ lanes on purpose: otherwise an exit 1 could be ⑤'s,
# and the lane would not discriminate which invariant fired (instrument-discrimination rule).
T=$(_repo four_missing); _card "$T"          # commit today, fh_completed absent
_run "$T"
_line "④-N  commits today + no fh_completed → ❌ fires" "❌ ④-log commits landed today" 1 "$OUT"
_line "④-N  ⑤ still holds (failure attributable to ④)" '✅ ⑤ card is the newest'    1 "$OUT"
_rc   "④-N  → exit 1 (BLOCKS a close push)" "$RC" 1

T=$(_repo four_present)
printf -- '- ✅ something — done\n' > "$T/tracks/_meta/fh_completed_${TODAY}.md"
_card "$T"                                    # card written LAST → card-last holds
_run "$T"
_line "④-P  fh_completed present → no ❌ ④-log" '❌ ④-log'              0 "$OUT"
_line "④-P  ⑤ ✅ present (known-positive)"    '✅ ⑤ card is the newest' 1 "$OUT"
_rc   "④-P  → exit 0" "$RC" 0

T=$(_repo four_old "3 days ago"); _card "$T"  # no commits today, no fh_completed
_run "$T"
_line "④-C  no commits today → no ④ line at all (over-fire control)" '④-log' 0 "$OUT"
_rc   "④-C  → exit 0" "$RC" 0

T="$TMPROOT/four_notrepo"; mkdir -p "$T/tracks/_meta"; _card "$T"
_run "$T"
_g=0; { printf '%s\n' "$OUT" | grep -q '❌ ④' || true; } ; printf '%s\n' "$OUT" | grep -q '❌ ④' || _g=1
_gap "④  instrument-down degrades to PASS on a BLOCKING leg" "$_g" \
  "No git → COMMITS_TODAY=0 → the ④ requirement silently evaporates and the check exits 0. \
④ is one of only two legs that can block a close push; its trigger failing open means the block \
is only as reliable as git being readable. Should distinguish 'no commits' from 'could not count'."

echo
echo "══ ④-b npm freshness + BIDIRECTIONAL entry-point drift ══"
_tagged() {  # $1=name  $2..=paths to change AFTER the tag
  local name="$1"; shift
  local T="$TMPROOT/$name" p
  mkdir -p "$T"
  (
    cd "$T" || exit 1
    git init -q . 2>/dev/null
    git config user.email anchor@local && git config user.name anchor
    echo '{"name":"fx","version":"1.0.0"}' > package.json
    echo base > CLAUDE.md; echo base > AGENTS.md
    mkdir -p docs knowledge/shared/harness-core knowledge/shared/learnings
    echo base > docs/codex-compat.md
    echo base > knowledge/shared/harness-core/x.md
    echo base > knowledge/shared/learnings/log.yaml
    git add -A && git commit -qm base && git tag v1.0.0
    for p in "$@"; do mkdir -p "$(dirname "$p")"; echo changed >> "$p"; done
    git add -A && git commit -qm change
  ) >/dev/null 2>&1
  mkdir -p "$T/tracks/_meta"
  printf -- '- ✅ x\n' > "$T/tracks/_meta/fh_completed_${TODAY}.md"
  _card "$T"
  printf '%s' "$T"
}
SHIP='④-b npm-shipped assets changed'
DRIFT_CC='drift candidate (CC→Codex)'
DRIFT_CX='drift candidate (Codex→CC)'

T=$(_tagged bb_cc CLAUDE.md); _run "$T"
_line "④-b-1 CLAUDE.md changed → republish reminder" "$SHIP"      1 "$OUT"
_line "④-b-1 → CC→Codex drift fires"                 "$DRIFT_CC"  1 "$OUT"
_line "④-b-1 → Codex→CC does NOT fire (paired)"      "$DRIFT_CX"  0 "$OUT"
_rc   "④-b-1 drift is ADVISORY (exit 0)" "$RC" 0

T=$(_tagged bb_cx AGENTS.md); _run "$T"
_line "④-b-2 AGENTS.md changed → republish reminder" "$SHIP"      1 "$OUT"
_line "④-b-2 → Codex→CC drift fires (the 07-19 miss)" "$DRIFT_CX" 1 "$OUT"
_line "④-b-2 → CC→Codex does NOT fire (paired)"      "$DRIFT_CC"  0 "$OUT"

T=$(_tagged bb_cx2 docs/codex-compat.md); _run "$T"
_line "④-b-3 docs/codex-compat.md → Codex→CC fires" "$DRIFT_CX"   1 "$OUT"
_line "④-b-3 → CC→Codex does NOT fire (paired)"     "$DRIFT_CC"   0 "$OUT"

T=$(_tagged bb_kn knowledge/shared/harness-core/x.md); _run "$T"
_line "④-b-4 shipped knowledge/ counts as a CC entry point" "$DRIFT_CC" 1 "$OUT"

T=$(_tagged bb_both CLAUDE.md AGENTS.md); _run "$T"
_line "④-b-5 both sides changed → republish reminder still"  "$SHIP"     1 "$OUT"
_line "④-b-5 both sides → CC→Codex silent (over-fire ctrl)"  "$DRIFT_CC" 0 "$OUT"
_line "④-b-5 both sides → Codex→CC silent (over-fire ctrl)"  "$DRIFT_CX" 0 "$OUT"

T=$(_tagged bb_unshipped knowledge/shared/learnings/log.yaml); _run "$T"
_line "④-b-6 UNshipped path → no republish reminder" "$SHIP"     0 "$OUT"
_line "④-b-6 UNshipped path → no drift candidate"    "$DRIFT_CC" 0 "$OUT"
_line "④-b-6 UNshipped path → ④-b is not silent-broken (control below)" '④-b' 0 "$OUT"

# no-tag fixture: identical CLAUDE.md change, but no version tag exists
T="$TMPROOT/bb_notag"; mkdir -p "$T"
(
  cd "$T" || exit 1
  git init -q . 2>/dev/null
  git config user.email anchor@local && git config user.name anchor
  echo '{"name":"fx","version":"1.0.0"}' > package.json
  echo base > CLAUDE.md && git add -A && git commit -qm base
  echo changed >> CLAUDE.md && git add -A && git commit -qm change
) >/dev/null 2>&1
mkdir -p "$T/tracks/_meta"; printf -- '- ✅ x\n' > "$T/tracks/_meta/fh_completed_${TODAY}.md"; _card "$T"
_run "$T"
_g=0; printf '%s\n' "$OUT" | grep -q '④-b' || _g=1
_gap "④-b whole step vanishes when no version tag is reachable" "$_g" \
  "LAST_TAG empty → the republish reminder AND both drift candidates are skipped silently. \
CLAUDE.md ④-b conditions the drift check on 'npm-shipped assets changed', not on a tag existing; \
a shallow/tagless clone or a pre-first-release state therefore runs a close with the entry-point \
drift check simply absent, and nothing says so."

echo
echo "══ pre-push SURFACE MATCHING (advise vs block) ══"
# A stubbed session_close_check lets these lanes control _SC_RC exactly, which is the variable
# under test. The real script's verdict logic is anchored above; what is anchored HERE is that
# the hook routes verdict → advisory or block by surface, and nothing else.
_hookfx() {  # $1=name $2=stub exit code  → echoes repo path
  local T="$TMPROOT/$1"
  mkdir -p "$T/scripts"
  (
    cd "$T" || exit 1
    git init -q . 2>/dev/null
    git config user.email anchor@local && git config user.name anchor
    printf '#!/usr/bin/env bash\necho "❌ ⑤ card-last violated — synthetic"\nexit %s\n' "$2" \
      > scripts/session_close_check.sh
    chmod +x scripts/session_close_check.sh
    git add -A && git commit -qm seed
  ) >/dev/null 2>&1
  cp "$HOOK" "$T/pre-push-under-test"
  printf '%s' "$T"
}
_hookrun() {  # $1=repo $2=FH_SESSION_CLOSE value ("" = unset)
  local T="$1" v="$2" sha
  sha=$(git -C "$T" rev-parse HEAD)
  # ordinary NEW-BRANCH push: local_sha real, remote_sha zero → not a delete, not a force,
  # not the integration branch → the hook must fall through to exit 0 unless a leg blocks.
  OUT=$(cd "$T" && printf 'refs/heads/feat/x %s refs/heads/feat/x %s\n' "$sha" "0000000000000000000000000000000000000000" \
        | env ${v:+FH_SESSION_CLOSE=$v} bash ./pre-push-under-test origin https://example.invalid/x.git 2>&1)
  RC=$?   # command substitution: this is the pipeline's status under pipefail, i.e. the HOOK's
}

T=$(_hookfx hook_adv 1); _hookrun "$T" ""
_rc   "PP-1 ordinary push + violation → exit 0 (ADVISORY)" "$RC" 0
_line "PP-1 → the ❌ line is surfaced, not swallowed"  '❌ ⑤ card-last violated' 1 "$OUT"
_line "PP-1 → says it is advisory + names the enforcing form" 'FH_SESSION_CLOSE=1' 1 "$OUT"

T=$(_hookfx hook_block 1); _hookrun "$T" 1
_rc   "PP-2 close push + violation → exit 1 (BLOCKS)" "$RC" 1
_line "PP-2 → prints the enforcing banner" '⛔ FH Session-Close Check' 1 "$OUT"

T=$(_hookfx hook_ok 0); _hookrun "$T" 1
_rc   "PP-3 close push + CLEAN → exit 0 (blocks on the VERDICT, not on the flag)" "$RC" 0
_line "PP-3 → prints the consistent line" '✅ FH Session-Close Check' 1 "$OUT"

T=$(_hookfx hook_ok2 0); _hookrun "$T" ""
_rc   "PP-4 ordinary push + CLEAN → exit 0" "$RC" 0
_line "PP-4 → no advisory noise on a healthy push" 'close invariant(s) violated' 0 "$OUT"

echo
echo "──────────────────────────────────────────────"
if [ "$FAILED" -ne 0 ]; then
  echo "CLOSE-CHAIN LANES: FAIL — the close-chain instrument is miscalibrated (do not trust its verdict)"
  echo "  asserting lanes passed: $PASSED · open gaps: $GAPS"
  exit 1
fi
echo "CLOSE-CHAIN LANES: PASS ($PASSED asserting lanes) · $GAPS KNOWN GAP(S) still open (see ⓘ above)"
echo "  A green line here covers ① ①-b ④ ④-b and the pre-push advise/block split — NOT the gaps."
exit 0
