#!/usr/bin/env bash
# test_probe_live_eval_lanes.sh — regression lanes for scripts/probe_live_eval.sh's SCORER and
# SELECTOR (scripts/probe_live_eval_lib.py). Never calls `claude` and spawns no live session —
# this pins the scoring logic and the probes.md/probes_live.yaml cross-reference against fixture
# text, exactly the split ablation_calibrate.sh's own header argues for ("the pair gates the
# runner; the runner never gates itself" — applied here to the scorer instead of a sim runner).
#
# LANE CLASSES
#   score-pair     known-pair calibration of score_probe(): PASS / FAIL / UNCALIBRATED(present) /
#                  UNCALIBRATED(absent) / FAILED-TO-RUN, both empty-string and missing-file shapes
#   select-guard   the mechanical selection rule (class filter, utterance-shape, INERT-ANCHOR,
#                  CLI-event exclude) reproduces the 12-selected / 21-excluded split against the
#                  REAL probes.md + probes_live.yaml shipped in this repo
#   dead-pointer   probes_live.yaml naming an id absent from probes.md is caught (nonzero exit),
#                  not silently ignored — this IS the "id 가 probes.md 에 실재하는지" guard the
#                  dispatching session's task named explicitly
#   dry-run        `--dry-run` on the real files exits 0 and touches nothing under run/ (no live
#                  network call, no OUTDIR created)
#
# exit: 0 = all lanes as expected · 1 = regression · 10 = harness error (setup failed, not a verdict)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$REPO_ROOT/scripts/probe_live_eval_lib.py"
RUNNER="$REPO_ROOT/scripts/probe_live_eval.sh"
PROBES_MD="$REPO_ROOT/.claude/regression/probes.md"
PROBES_LIVE="$REPO_ROOT/.claude/regression/probes_live.yaml"

command -v python3 >/dev/null 2>&1 || { echo "❌ HARNESS-ERROR — python3 missing"; exit 10; }
[ -f "$LIB" ]    || { echo "❌ HARNESS-ERROR — $LIB missing"; exit 10; }
[ -f "$RUNNER" ] || { echo "❌ HARNESS-ERROR — $RUNNER missing"; exit 10; }

T="$(mktemp -d)" || { echo "❌ HARNESS-ERROR — mktemp failed"; exit 10; }
trap 'rm -rf "$T"' EXIT

FAIL=0; N=0
_lane() {  # $1=id $2=class $3=desc $4=expected $5=actual
  N=$((N + 1))
  if [ "$4" = "$5" ]; then
    printf '  ✅ %-8s [%-14s] %s\n' "$1" "$2" "$3"
  else
    printf '  ❌ %-8s [%-14s] %s — expected=%s actual=%s\n' "$1" "$2" "$3" "$4" "$5"
    FAIL=1
  fi
}

# ── score-pair: known-pair calibration of score_probe() ────────────────────────────────────────
# $1=primary $2=control $3=polarity $4=expect_re -> prints "VERDICT PRIMARY_HIT CONTROL_HIT"
# `__NONE__` maps to Python None (FAILED-TO-RUN fixture — a file that was never written, distinct
# from an empty string, which is a file that WAS written with 0 bytes; both must score the same).
_score() {
  python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/scripts')
from probe_live_eval_lib import score_probe
primary = None if sys.argv[1] == '__NONE__' else sys.argv[1]
control = None if sys.argv[2] == '__NONE__' else sys.argv[2]
v, ph, ch = score_probe(primary, control, sys.argv[3], sys.argv[4])
print('%s %s %s' % (v, ph, ch))
" "$1" "$2" "$3" "$4"
}

echo "── score-pair ────────────────────────────────────────────────────"

# P1: polarity=present, pattern fires on primary, does not fire on control → PASS
r="$(_score '🐿️ Welcome to FH' 'the weather is nice today' present '🐿️')"
_lane P1 score-pair "present polarity, control clean -> PASS" "PASS True False" "$r"

# P2: polarity=present, pattern absent from primary -> FAIL
r="$(_score 'sure, here is the weather' 'the weather is nice today' present '🐿️')"
_lane P2 score-pair "present polarity, primary silent -> FAIL" "FAIL False False" "$r"

# P3: polarity=present, pattern ALSO fires on control -> UNCALIBRATED (the instrument cannot
# discriminate — this is the known-pair's whole point: a probe whose control leaks the pattern
# must not be scored as if it discriminated)
r="$(_score '🐿️ Welcome to FH' 'random text with 🐿️ in it too' present '🐿️')"
_lane P3 score-pair "present polarity, control ALSO hits -> UNCALIBRATED" "UNCALIBRATED True True" "$r"

# P4: polarity=absent, pattern absent from primary, present on control -> PASS
r="$(_score 'here are the dependencies' '🐿️ Welcome to FH' absent '🐿️')"
_lane P4 score-pair "absent polarity, control fires -> PASS" "PASS False True" "$r"

# P5: polarity=absent, pattern LEAKS into primary too -> FAIL (a real regression: onboarding
# leaking into an explicit task-utterance response)
r="$(_score '🐿️ Welcome to FH — here are the dependencies' '🐿️ Welcome to FH' absent '🐿️')"
_lane P5 score-pair "absent polarity, primary leaks -> FAIL" "FAIL True True" "$r"

# P6: polarity=absent, control ALSO never fires -> UNCALIBRATED (control failed to prove the
# pattern can appear at all — primary's silence is not evidence of anything)
r="$(_score 'here are the dependencies' 'also just dependencies' absent '🐿️')"
_lane P6 score-pair "absent polarity, control never fires -> UNCALIBRATED" "UNCALIBRATED False False" "$r"

# P7/P8: FAILED-TO-RUN — missing file (None) and empty-string both collapse to the same verdict,
# never silently read as a FAIL (CLAUDE.md not-found-is-not-zero discipline).
r="$(_score '__NONE__' 'the weather is nice' present '🐿️')"
_lane P7 score-pair "primary file missing -> FAILED-TO-RUN" "FAILED-TO-RUN False False" "$r"
r="$(_score '' 'the weather is nice' present '🐿️')"
_lane P8 score-pair "primary file empty -> FAILED-TO-RUN" "FAILED-TO-RUN False False" "$r"

# ── select-guard: mechanical rule reproduces the real 12/21 split ──────────────────────────────
echo ""
echo "── select-guard ──────────────────────────────────────────────────"

SELECT_JSON="$T/select.json"
SPEC_DIR="$T/spec"
sel_out="$(python3 "$LIB" select --probes-md "$PROBES_MD" --probes-live "$PROBES_LIVE" \
             --json-out "$SELECT_JSON" --spec-dir "$SPEC_DIR" 2>&1)"
sel_rc=$?
_lane S1 select-guard "real probes.md/probes_live.yaml -> selector exits 0 (no dead pointer)" "0" "$sel_rc"

if [ -f "$SELECT_JSON" ]; then
  sel_count=$(python3 -c "import json; print(len(json.load(open('$SELECT_JSON'))['selected']))")
  exc_count=$(python3 -c "import json; print(len(json.load(open('$SELECT_JSON'))['excluded']))")
else
  sel_count="ERR"; exc_count="ERR"
fi
_lane S2 select-guard "selected count == 12 (see probes_live.yaml header for the derivation)" "12" "$sel_count"
_lane S3 select-guard "excluded count == 21 (33 probes.md rows - 12 selected)" "21" "$exc_count"

# --subset and --ids filters
sub_out="$(python3 "$LIB" select --probes-md "$PROBES_MD" --probes-live "$PROBES_LIVE" --subset 3 \
             --spec-dir "$T/spec_subset" 2>&1)"
sub_count=$(wc -l < "$T/spec_subset/selected_ids.txt" 2>/dev/null | tr -d ' ')
_lane S4 select-guard "--subset 3 yields exactly 3 selected ids" "3" "${sub_count:-ERR}"

ids_out="$(python3 "$LIB" select --probes-md "$PROBES_MD" --probes-live "$PROBES_LIVE" \
             --ids "G-GREET-01,G-TRIG-02" --spec-dir "$T/spec_ids" 2>&1)"
ids_count=$(wc -l < "$T/spec_ids/selected_ids.txt" 2>/dev/null | tr -d ' ')
_lane S5 select-guard "--ids G-GREET-01,G-TRIG-02 yields exactly 2" "2" "${ids_count:-ERR}"

unk_out="$(python3 "$LIB" select --probes-md "$PROBES_MD" --probes-live "$PROBES_LIVE" \
             --ids "G-NOT-A-REAL-ID-99" --spec-dir "$T/spec_unk" 2>&1)"
case "$unk_out" in
  *"unknown ids requested"*) unk_hit="yes" ;;
  *) unk_hit="no" ;;
esac
_lane S6 select-guard "--ids with an unknown id is reported, not silently dropped" "yes" "$unk_hit"

# ── dead-pointer: probes_live.yaml naming an id absent from probes.md must fail loudly ─────────
echo ""
echo "── dead-pointer ──────────────────────────────────────────────────"

BAD_YAML="$T/probes_live_bad.yaml"
{
  cat "$PROBES_LIVE"
  cat <<'BADEOF'
  - id: G-DOES-NOT-EXIST-99
    polarity: present
    input: "this id has no row in probes.md"
    expect_re: "x"
    control_input: "y"
BADEOF
} > "$BAD_YAML"

python3 "$LIB" select --probes-md "$PROBES_MD" --probes-live "$BAD_YAML" \
  --json-out "$T/select_bad.json" --spec-dir "$T/spec_bad" >"$T/bad_out.txt" 2>&1
bad_rc=$?
_lane D1 dead-pointer "id absent from probes.md -> select exits nonzero" "nonzero" "$([ "$bad_rc" -ne 0 ] && echo nonzero || echo zero)"
grep -q "DEAD-POINTER: G-DOES-NOT-EXIST-99" "$T/bad_out.txt" && d2=found || d2=missing
_lane D2 dead-pointer "dead-pointer id named explicitly in the warning" "found" "$d2"

# Known-negative for D1/D2: the SAME check must NOT fire on the real, uncorrupted file — otherwise
# D1/D2 could be passing on a scanner that always says "dead pointer found" regardless of input.
python3 "$LIB" select --probes-md "$PROBES_MD" --probes-live "$PROBES_LIVE" \
  --json-out "$T/select_clean.json" --spec-dir "$T/spec_clean" >"$T/clean_out.txt" 2>&1
clean_rc=$?
grep -q "DEAD-POINTER" "$T/clean_out.txt" && d3=found || d3=missing
_lane D3 dead-pointer "control: real file has no dead pointer, rc=0" "0 missing" "${clean_rc} ${d3}"

# ── dry-run: probe_live_eval.sh --dry-run touches nothing under a fresh OUTDIR and exits 0 ─────
echo ""
echo "── dry-run ───────────────────────────────────────────────────────"

DRY_OUT="$T/dryrun_out"
dry_stdout="$(cd "$REPO_ROOT" && bash "$RUNNER" --dry-run --out "$DRY_OUT" 2>&1)"
dry_rc=$?
_lane R1 dry-run "probe_live_eval.sh --dry-run exits 0" "0" "$dry_rc"
_lane R2 dry-run "--dry-run creates no OUTDIR (no live run attempted)" "absent" "$([ -d "$DRY_OUT" ] && echo present || echo absent)"
case "$dry_stdout" in
  *"SELECTED (12)"*) r3=yes ;;
  *) r3=no ;;
esac
_lane R3 dry-run "--dry-run stdout shows the real 12-probe selection" "yes" "$r3"

echo ""
echo "── summary ──────────────────────────────────────────────────────"
echo "lanes: $N   failed: $([ "$FAIL" -eq 0 ] && echo 0 || echo '>=1')"
if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: REGRESSION"
  exit 1
fi
echo "RESULT: CLEAN"
exit 0
