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

# ── reason-pair: FAILED-TO-RUN rows carry a `reason` explaining WHY (2026-09-05) ────────────────
# WHY: the 2026-09-05 launchd incident scored 12/12 FAILED-TO-RUN with no clue why in the report
# itself — a human had to go dig through stderr files by hand. score_run() now attaches a `reason`
# to any FAILED-TO-RUN row: the failing arm's own stderr first line when there is one, else an
# rc/bytes fallback parsed from the runner's console log. This never touches score_probe() itself
# (unchanged, still tested above) — reason is a diagnostic label on top of the same verdict.
# $1=run_root $2=id -> "VERDICT<TAB>REASON"
_reason_row() {
  python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/scripts')
from probe_live_eval_lib import score_run
live = [{'id': sys.argv[2], 'polarity': 'present', 'expect_re': '🐿️'}]
res = score_run(live, sys.argv[1], [sys.argv[2]], 0.8, 'sonnet')
row = res['rows'][0]
sys.stdout.write('%s\t%s' % (row['verdict'], row.get('reason', '')))
" "$1" "$2"
}

echo ""
echo "── reason-pair ──────────────────────────────────────────────────"

# R-F1: primary's own stderr has a real line (the launchd incident's actual error text) -> reason
# quotes it verbatim, prefixed by which arm it came from.
RROOT1="$T/reason_f1"; mkdir -p "$RROOT1/X1"
printf 'scripts/sim_isolated_run.sh: line 517: timeout: command not found\n' > "$RROOT1/X1/primary_r1.stderr.txt"
printf 'unused control text' > "$RROOT1/X1/control_r1.txt"
out="$(_reason_row "$RROOT1" X1)"
_lane RF1 reason-pair "primary stderr line -> reason quotes it, prefixed 'primary:'" \
  "FAILED-TO-RUN	primary: scripts/sim_isolated_run.sh: line 517: timeout: command not found" "$out"

# R-F2: stderr file absent/empty -> falls back to rc/bytes, rc parsed from the runner's own
# console log text (the shape sim_isolated_run.sh itself prints: "(rc=<n>, ...)").
RROOT2="$T/reason_f2"; mkdir -p "$RROOT2/X2"
printf '  UNMEASURED (rc=127, 0 bytes) - timeout or crash, NOT a negative result\n' > "$RROOT2/X2/_runner_primary.log"
printf 'unused' > "$RROOT2/X2/control_r1.txt"
out="$(_reason_row "$RROOT2" X2)"
_lane RF2 reason-pair "no stderr line -> rc/bytes fallback parsed from the runner log" \
  "FAILED-TO-RUN	primary: rc=127 bytes=0" "$out"

# R-F3: the CONTROL side is the one missing (primary present) -> reason is prefixed 'control:',
# not 'primary:' — proves the label is attributed to the arm that actually failed.
RROOT3="$T/reason_f3"; mkdir -p "$RROOT3/X3"
printf '🐿️ Welcome to FH' > "$RROOT3/X3/primary_r1.txt"
printf 'boom: control side stderr text\n' > "$RROOT3/X3/control_r1.stderr.txt"
out="$(_reason_row "$RROOT3" X3)"
_lane RF3 reason-pair "control-side failure -> reason prefixed 'control:', not 'primary:'" \
  "FAILED-TO-RUN	control: boom: control side stderr text" "$out"

# R-F4 known-negative: a normal PASS row must carry an EMPTY reason — otherwise RF1-RF3 could be
# passing because `reason` is always non-empty garbage, not because it discriminates on verdict
# ([[feedback_control_presence_is_not_discrimination]]).
RROOT4="$T/reason_f4"; mkdir -p "$RROOT4/X4"
printf '🐿️ Welcome to FH' > "$RROOT4/X4/primary_r1.txt"
printf 'the weather is nice' > "$RROOT4/X4/control_r1.txt"
out="$(_reason_row "$RROOT4" X4)"
_lane RF4 reason-pair "control — a PASS row carries no reason (field is FAILED-TO-RUN-only)" \
  "PASS	" "$out"

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

# ── fail-fast: probe_live_eval.sh aborts on the FIRST rc=2 runner call, not after burning the
# rest of the selected set (2026-09-05, the launchd incident this exists for) ────────────────────
# WHY: sim_isolated_run.sh's own usage guards exit 2 before ever calling `claude` (bad flags, no
# `claude` on PATH, or — the actual incident — a launchd PATH with no `timeout(1)` resolvable
# before that runner grew its own bash-fallback). That condition is identical for every remaining
# probe in the run, so continuing just burns the rest of the clones on an environment already
# known broken. These lanes stub OUT sim_isolated_run.sh entirely via FH_SIM_RUNNER_BIN (added to
# probe_live_eval.sh for exactly this) so the fail-fast branch can be tested without a live
# `claude` call at all.
echo ""
echo "── fail-fast ────────────────────────────────────────────────────"

STUBROOT="$T/failfast_stub"; mkdir -p "$STUBROOT"

# Broken stand-in: exactly what sim_isolated_run.sh's own preflight guards do — print one line to
# stderr and exit 2, never touching a network or spawning `claude`. Records its own invocation
# count so the lane can prove the caller stopped after the FIRST call.
cat > "$STUBROOT/fake_sim_broken.sh" <<'FAKESIM'
#!/usr/bin/env bash
: "${FH_FAKESIM_COUNTER:?FH_FAKESIM_COUNTER must be set by the caller}"
echo "$$" >> "$FH_FAKESIM_COUNTER"
echo "FAIL: claude CLI not on PATH" >&2
exit 2
FAKESIM
chmod +x "$STUBROOT/fake_sim_broken.sh"

# Healthy stand-in (known-negative control): same argv shape, writes a plausible output file and
# exits 0 for EVERY call — proves FF1/FF2 discriminate on rc=2 specifically, not on "stopped after
# one call" regardless of what the runner returns.
cat > "$STUBROOT/fake_sim_ok.sh" <<'FAKESIMOK'
#!/usr/bin/env bash
: "${FH_FAKESIM_COUNTER:?FH_FAKESIM_COUNTER must be set by the caller}"
echo "$$" >> "$FH_FAKESIM_COUNTER"
arm=""; out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --arm) arm="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
mkdir -p "$out"
echo "stub ok output" > "$out/${arm}_r1.txt"
echo "RESULT: CLEAN"
exit 0
FAKESIMOK
chmod +x "$STUBROOT/fake_sim_ok.sh"

# 🟥 FF5 guard — the live nightly record must be untouched by this suite. Measured 2026-09-05 10:18:
# FF4 completed the REAL script with a stub runner and, with no --report-out, replaced that night's
# tracks/_meta/live_eval_<date>.md with stub values. A lane that writes into the live artifact path
# is the fleet class in miniature ([[feedback_sim_with_write_tools_is_a_fleet]]).
LIVE_REPORT="$REPO_ROOT/tracks/_meta/live_eval_$(date +%Y-%m-%d).md"
_live_hash() { if [ -f "$LIVE_REPORT" ]; then shasum "$LIVE_REPORT" | cut -c1-40; else echo ABSENT; fi; }
live_before="$(_live_hash)"
COUNTER1="$T/failfast_counter_broken.txt"; : > "$COUNTER1"
ff_out="$(cd "$REPO_ROOT" && FH_SIM_RUNNER_BIN="$STUBROOT/fake_sim_broken.sh" FH_FAKESIM_COUNTER="$COUNTER1" \
    bash "$RUNNER" --subset 2 --model sonnet --out "$T/failfast_run_broken" --report-out "$T/failfast_report_broken.md" 2>&1)"
ff_rc=$?
_lane FF1 fail-fast "aborts with rc=2 on the runner's own preflight failure" "2" "$ff_rc"
ff_calls=$(wc -l < "$COUNTER1" | tr -d ' ')
_lane FF2 fail-fast "stops after exactly 1 runner call (does not burn the 2nd probe's 3 remaining calls)" "1" "$ff_calls"
case "$ff_out" in
  *"Aborting the whole run"*) ff_msg=yes ;;
  *) ff_msg=no ;;
esac
_lane FF3 fail-fast "abort message names what happened (not a silent stop)" "yes" "$ff_msg"

# Known-negative control: the SAME --subset 2 (2 probes x primary+control = 4 calls) against a
# HEALTHY runner must run to completion, not stop early — otherwise FF1/FF2 could be passing
# because the loop always stops after one call for any reason at all
# ([[feedback_control_presence_is_not_discrimination]]).
COUNTER2="$T/failfast_counter_ok.txt"; : > "$COUNTER2"
( cd "$REPO_ROOT" && FH_SIM_RUNNER_BIN="$STUBROOT/fake_sim_ok.sh" FH_FAKESIM_COUNTER="$COUNTER2" \
    bash "$RUNNER" --subset 2 --model sonnet --out "$T/failfast_run_ok" --report-out "$T/failfast_report_ok.md" ) >/dev/null 2>&1
ff2_calls=$(wc -l < "$COUNTER2" | tr -d ' ')
_lane FF4 fail-fast "control — a healthy runner (rc=0) is called for all 4 (2 probes x 2 arms), not stopped early" "4" "$ff2_calls"
live_after="$(_live_hash)"
_lane FF5 fail-fast "live nightly record untouched by the suite (hash before == after, or both ABSENT)" "$live_before" "$live_after"
[ -s "$T/failfast_report_ok.md" ] && ff_rep=yes || ff_rep=no
_lane FF6 fail-fast "--report-out receives the report instead of the live path" "yes" "$ff_rep"

# 🟥 FF7/FF7b — the seam must bypass the CLI preflight, and ONLY the seam. Measured 2026-09-05 on
# CI (ubuntu, no `claude` on PATH): probe_live_eval.sh checked `command -v claude` BEFORE the
# runner seam, so the stub was never called — FF2/FF3/FF4/FF6 red, FF1 green by coincidence (both
# paths exit 2). A developer machine with `claude` installed cannot see that, so this lane HIDES
# `claude` (a shadow PATH of symlinks to every other executable) and re-runs the healthy stub.
# FF7b is the control: on the REAL runner path with no `claude`, the script must still refuse.
SHADOW_NOCLAUDE="$T/shadow_noclaude"; mkdir -p "$SHADOW_NOCLAUDE"
IFS=':' read -r -a _ff_dirs <<< "$PATH"
for _d in "${_ff_dirs[@]}"; do
  [ -d "$_d" ] || continue
  for _f in "$_d"/*; do
    [ -x "$_f" ] && [ ! -d "$_f" ] || continue
    _b="${_f##*/}"; [ "$_b" = claude ] && continue
    [ -e "$SHADOW_NOCLAUDE/$_b" ] || ln -s "$_f" "$SHADOW_NOCLAUDE/$_b"
  done
done
if PATH="$SHADOW_NOCLAUDE" command -v claude >/dev/null 2>&1; then
  _lane FF7-FIXTURE fail-fast "shadow PATH hides claude (fixture potency — cannot run FF7 on this machine)" "hidden" "still-visible"
else
  COUNTER3="$T/failfast_counter_noclaude.txt"; : > "$COUNTER3"
  ( cd "$REPO_ROOT" && PATH="$SHADOW_NOCLAUDE" FH_SIM_RUNNER_BIN="$STUBROOT/fake_sim_ok.sh" FH_FAKESIM_COUNTER="$COUNTER3" \
      bash "$RUNNER" --subset 2 --model sonnet --out "$T/failfast_run_noclaude" --report-out "$T/failfast_report_noclaude.md" ) >/dev/null 2>&1
  ff7_calls=$(wc -l < "$COUNTER3" | tr -d ' ')
  _lane FF7 fail-fast "claude absent from PATH + stub runner: stub still called for all 4 (the seam bypasses the CLI preflight)" "4" "$ff7_calls"
  ff7b_out="$(cd "$REPO_ROOT" && PATH="$SHADOW_NOCLAUDE" bash "$RUNNER" --subset 2 --model sonnet --out "$T/failfast_run_noclaude_real" --report-out "$T/failfast_report_noclaude_real.md" 2>&1)"
  ff7b_rc=$?
  case "$ff7b_out" in *"claude CLI not on PATH"*) ff7b_msg=yes ;; *) ff7b_msg=no ;; esac
  _lane FF7b fail-fast "control — the REAL runner path with claude absent still exits 2 and names claude" "2/yes" "$ff7b_rc/$ff7b_msg"
fi

echo ""
echo "── summary ──────────────────────────────────────────────────────"
echo "lanes: $N   failed: $([ "$FAIL" -eq 0 ] && echo 0 || echo '>=1')"
if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: REGRESSION"
  exit 1
fi
echo "RESULT: CLEAN"
exit 0
