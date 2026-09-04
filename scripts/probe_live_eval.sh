#!/usr/bin/env bash
# probe_live_eval.sh — the LIVE twin of /prompt-regression's static probe check.
#
# WHY THIS EXISTS. `plugins/fh-meta/skills/prompt-regression/SKILL.md` says this about itself,
# verbatim, in its own §Step 4: "What it therefore cannot catch — a rule that is still present but
# has stopped FIRING (salience loss, ordering, competition from another rule) — a trigger phrase
# present in the file but shadowed by a higher-priority route — any behavior change that leaves the
# source text identical." That gap is exactly what an eval-style harness closes (CLAUDE.md
# §Autonomous Initiative Layer cites the shape: settings-changed PR + a scored run against real
# tasks, not a source grep). This script IS that harness for FH's own golden probe set
# (.claude/regression/probes.md): it sends each selected probe's literal utterance to a floor-tier
# `claude -p` inside an ISOLATED, disposable clone (via scripts/sim_isolated_run.sh — never the live
# repo, per that script's own header) and greps the ACTUAL RESPONSE, not the source.
#
# WHAT IT IS NOT. It does not replace /prompt-regression (source-correctness stays cheap and
# instant) and it does not replace a blind sim-conductor persona run (which reads a whole artifact
# for open-ended judgment). This is narrow, mechanical, known-answer, and cheap enough to run
# nightly — the same trade CLAUDE.md's Measured-Loop memory entry describes for any recurring
# measurement: sealed pre-registration (probes_live.yaml is authored BEFORE a run, not fit to one),
# one variable per probe (ARM=primary utterance, CTRL=known-negative), a scorer that runs before
# results are read, and the falsification condition (a probe whose control does not discriminate
# is not scored PASS/FAIL — see §Scoring) executed exactly as it is written.
#
# SELECTION. Not every probes.md row is live-runnable — see .claude/regression/probes_live.yaml's
# header for the 4-step mechanical rule (class filter, utterance-shape filter, INERT-ANCHOR filter,
# hand-curated CLI-event filter) and scripts/probe_live_eval_lib.py for the implementation. Run
# `--dry-run` to see the full 33-row breakdown: which probes are selected, which are excluded and
# why, and which pass the mechanical rule but have no authored expect/control yet
# (NOT-YET-AUTHORED — an honest gap, not a silent drop; G-LINT-01 is the current example, deferred
# because scoring a full /harness-doctor Step 5 run needs more than a keyword regex).
#
# COST. Each selected probe costs TWO live `claude -p` calls (primary + control). Do not run the
# full selected set casually — use --subset N or --ids P1,P2 for a spot-check, and read
# sim_isolated_run.sh's own header before running unattended (isolation guarantees, what "observe"
# mode does and does not prevent, the three-valued rc/bytes verdict for a timeout vs an empty
# answer).
#
# 🟥 «미실행 ≠ 0» — a probe whose primary or control call produced 0 bytes (timeout, rate limit,
# crash) is scored FAILED-TO-RUN, excluded from the pass-rate denominator, and its count is
# reported separately. A FAILED-TO-RUN probe is not evidence the behavior is absent — it is
# evidence nothing was measured (CLAUDE.md §Instrument-Calibration: "not found ≠ 0").
#
# SCORING (see scripts/probe_live_eval_lib.py:score_probe for the exact rule). Each probe declares
# a `polarity` in probes_live.yaml:
#   present — expect_re must appear in PRIMARY and must NOT appear in CONTROL
#   absent  — expect_re must NOT appear in PRIMARY and MUST appear in CONTROL
# Either direction of "the control disagrees with what polarity predicts" scores that probe
# UNCALIBRATED, never PASS or FAIL — an instrument that cannot discriminate has not measured
# anything, per this repo's own instrument-calibration discipline. If ANY probe in a run is
# UNCALIBRATED, the WHOLE RUN's overall verdict is UNCALIBRATED (rc=2) — a pass rate computed
# alongside a proven-blind probe is not trustworthy just because the other rows look fine.
#
# EXIT CODES: 0 = PASS (pass_rate >= threshold, no UNCALIBRATED). 1 = FAIL (pass_rate < threshold).
# 2 = UNCALIBRATED or NO-PROBES-RAN (no verdict rendered — fix the instrument before trusting it).
#
# USAGE
#   bash scripts/probe_live_eval.sh --dry-run
#   bash scripts/probe_live_eval.sh --ids G-GREET-01,G-TRIG-02 --model sonnet
#   bash scripts/probe_live_eval.sh --subset 3
#   bash scripts/probe_live_eval.sh                      # full selected set — nightly cron shape
#
# PORTABILITY: bash 3.2 (macOS) + bash 5.x (Linux CI). No associative arrays, no `${var,,}`,
# heredocs only inside functions with quoted delimiters (see [[feedback_unquoted_heredoc_backtick_executes]]
# — this script has none; the one heredoc-shaped block lives in probe_live_eval_lib.py, a real
# file, not a bash heredoc).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBES_MD="$REPO_ROOT/.claude/regression/probes.md"
PROBES_LIVE="$REPO_ROOT/.claude/regression/probes_live.yaml"
LIB="$REPO_ROOT/scripts/probe_live_eval_lib.py"
SIM_RUNNER="$REPO_ROOT/scripts/sim_isolated_run.sh"

# ── file-header constant — the "문턱" the design brief calls for. Change here, not per-invocation. ──
THRESHOLD="0.8"

MODEL="sonnet"
DRYRUN=0
SUBSET=""
IDS=""
OUTDIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --subset)   SUBSET="${2:-}"; shift 2 ;;
    --ids)      IDS="${2:-}"; shift 2 ;;
    --model)    MODEL="${2:-sonnet}"; shift 2 ;;
    --dry-run)  DRYRUN=1; shift ;;
    --out)      OUTDIR="${2:-}"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "FAIL: python3 required" >&2; exit 2; }
[ -f "$PROBES_MD" ]   || { echo "FAIL: $PROBES_MD not found" >&2; exit 2; }
[ -f "$PROBES_LIVE" ] || { echo "FAIL: $PROBES_LIVE not found" >&2; exit 2; }
[ -f "$LIB" ]         || { echo "FAIL: $LIB not found" >&2; exit 2; }

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/fh-live-eval-XXXXXX")"
SPEC_DIR="$WORKDIR/spec"
SELECT_JSON="$WORKDIR/select.json"

SELECT_ARGS=(select --probes-md "$PROBES_MD" --probes-live "$PROBES_LIVE"
             --json-out "$SELECT_JSON" --spec-dir "$SPEC_DIR")
[ -n "$SUBSET" ] && SELECT_ARGS+=(--subset "$SUBSET")
[ -n "$IDS" ]     && SELECT_ARGS+=(--ids "$IDS")

python3 "$LIB" "${SELECT_ARGS[@]}"
select_rc=$?
# select_rc nonzero = a DEAD-POINTER (probes_live.yaml names an id absent from probes.md). That is
# an authoring bug in this repo's own asset, not a runtime condition — fail loudly rather than
# silently running a smaller set than intended.
if [ "$select_rc" -ne 0 ]; then
  echo "" >&2
  echo "❌ selection reported a dead pointer — fix .claude/regression/probes_live.yaml before running." >&2
  rm -rf "$WORKDIR"
  exit "$select_rc"
fi

if [ "$DRYRUN" -eq 1 ]; then
  rm -rf "$WORKDIR"
  exit 0
fi

[ -f "$SPEC_DIR/selected_ids.txt" ] || { echo "FAIL: selection produced no spec dir" >&2; rm -rf "$WORKDIR"; exit 2; }
SELECTED_COUNT=$(wc -l < "$SPEC_DIR/selected_ids.txt" | tr -d ' ')
if [ "$SELECTED_COUNT" -eq 0 ]; then
  echo "❌ 0 probes selected after filtering — nothing to run (check --ids / --subset against the" >&2
  echo "   SELECTED list printed above)." >&2
  rm -rf "$WORKDIR"
  exit 2
fi

command -v claude >/dev/null 2>&1 || { echo "FAIL: claude CLI not on PATH — cannot run live" >&2; rm -rf "$WORKDIR"; exit 2; }

RUN_DATE="$(date +%Y-%m-%d)"
OUTDIR="${OUTDIR:-$WORKDIR/run}"
mkdir -p "$OUTDIR"

echo ""
echo "── live run: $SELECTED_COUNT probe(s), model=$MODEL, out=$OUTDIR ──────────────────────"

while IFS= read -r id; do
  [ -z "$id" ] && continue
  input_text="$(cat "$SPEC_DIR/$id.input.txt")"
  control_text="$(cat "$SPEC_DIR/$id.control.txt")"
  probe_out="$OUTDIR/$id"
  mkdir -p "$probe_out"

  echo ""
  echo "▶ $id — primary"
  bash "$SIM_RUNNER" --arm primary --reps 1 --prompt "$input_text" \
       --mode observe --model "$MODEL" --out "$probe_out" \
       > "$probe_out/_runner_primary.log" 2>&1
  tail -n 6 "$probe_out/_runner_primary.log"

  echo "▶ $id — control"
  bash "$SIM_RUNNER" --arm control --reps 1 --prompt "$control_text" \
       --mode observe --model "$MODEL" --out "$probe_out" \
       > "$probe_out/_runner_control.log" 2>&1
  tail -n 6 "$probe_out/_runner_control.log"
done < "$SPEC_DIR/selected_ids.txt"

echo ""
REPORT_PATH="$REPO_ROOT/tracks/_meta/live_eval_${RUN_DATE}.md"
python3 "$LIB" score \
  --probes-live "$PROBES_LIVE" \
  --select-json "$SELECT_JSON" \
  --ids-file "$SPEC_DIR/selected_ids.txt" \
  --run-root "$OUTDIR" \
  --threshold "$THRESHOLD" \
  --model "$MODEL" \
  --report-out "$REPORT_PATH" \
  --run-date "$RUN_DATE"
score_rc=$?

echo ""
echo "run artifacts kept at: $OUTDIR"
echo "(temp selection workspace $WORKDIR is NOT auto-deleted when --out was passed explicitly; ok to remove by hand)"

exit "$score_rc"
