#!/usr/bin/env bash
# probe_scope_check.sh — every `Scope` in the probe set must still name a real section.
#
# WHY (2026-08-02). `.claude/regression/probes.md` states its own maintenance rule: "when a Scope
# target section changes, the probes pointing at it MUST be updated in the same commit — a stale probe
# is a false alarm generator." Nothing enforced it. First run found **8 stale scopes**: two had been
# relocated into `.claude/rules/fh_4axis_gate.md` when the 4-axis section was split out of CLAUDE.md,
# and five named sub-steps or notations that are not section anchors at all. A probe whose Scope points
# nowhere still runs, but nobody can tell what it defends — and the drift is invisible until someone
# reasons from the probe set about which assets are protected.
#
# WHAT THIS IS NOT, AND WHY (the honest part). This began as an *ablation coverage* reporter: it also
# printed "how much of CLAUDE.md is defended by no probe", to give the shed/advance pass something to
# act on. That number was wrong four times in a row (98% -> 51% -> 51% -> 46%, plus a confident
# "100% unmeasured" on an asset three probes defended), each time for a different reason, and each
# repair produced the next defect. The convergence rule this repo now runs says a yield that stops
# falling means the design is manufacturing its own findings — cut it, do not tighten it. So the
# number is GONE and only the check that kept proving useful remains. Coverage measurement is a
# separate problem; it is NOT solved here and should not be reported as if it were.
#
# HOW TO ACTUALLY ABLATE (the cheap loop that works, measured 2026-08-02). The coverage number was
# the wrong shape; a per-section verdict with a known pair is the right one, and it costs ~2 minutes:
#   1. pick a section that has >=1 probe (this script tells you the Scopes resolve; grep probes.md
#      for the section name to find its probes)
#   2. write two copies of the asset — arm A unchanged, arm B with that section cut
#   3. CALIBRATE THE RUNNER FIRST: `bash scripts/ablation_calibrate.sh` must exit 0. The pair gates
#      the runner; the runner never gates itself. Skipping this is how both leaks below shipped.
#   4. run each arm through a HEADLESS runtime whose cwd is OUTSIDE this repo, feeding the arm on
#      stdin, WITH TOOLS STRIPPED, and ask the probe's own question. Give EACH ARM ITS OWN
#      DIRECTORY -- an arm that runs beside a copy containing the answer can read it off the
#      neighbour instead of failing, which is a false CUT ([[feedback_half_fix_propagation_boundary]]:
#      the calibrator fixed this in itself first, and this line is the propagation):
#        mkdir -p <scratch-outside-repo>/A <scratch-outside-repo>/B   # armA.md and armB.md, apart
#        cd <scratch-outside-repo>/B
#        { echo '=== RULESET ==='; cat armB.md; echo; echo "$QUESTION"; } \
#          | claude -p --model sonnet --tools ''
#      Use `--tools ''` (empty ALLOWLIST), not the denylist form. Both pass calibration today, but a
#      denylist re-opens the channel by default the day Claude Code ships a new tool.
#   5. RUN AT reps>=3. The runner is nondeterministic: on 2026-08-03 an arm A that CONTAINED the
#      answer returned NOT IN MY CONTEXT in 1 of 3 reps. A single rep is not a measurement.
#   6. arm A answers it and arm B cannot -> the section is load-bearing, KEEP. Both answer -> the
#      section is redundant with whatever else is resident, and it is a deletion candidate.
#      A third outcome exists and is the worst: arm B answers CONFIDENTLY AND WRONGLY. That is not
#      redundancy, it is the section doing load-bearing work by preventing a wrong inference. Score
#      it KEEP. (Measured: cutting §FH 4-Axis made every rep conclude the gate does NOT apply to
#      `AGENTS.md`/`templates/` edits — the exact opposite of the rule.)
#      ⚠️ THAT THIRD OUTCOME MAKES **CUT UNREACHABLE** UNLESS ALL THREE HOLD -- with an unbounded
#      question space and a nonzero model error rate, any section can be rescued by hunting for a
#      question arm B fumbles, and a shed procedure that cannot shed has inverted its purpose:
#        (a) PRE-REGISTER the question set before any arm runs, and report k tried / k that flipped
#            the verdict, in `.claude/regression/ablation_verdicts.md` §Pre-registration log;
#        (b) arm A's answer must be GREP-VERIFIABLE in the cut text -- right because of the section,
#            not right by luck;
#        (c) arm B's wrong answer must be CONSEQUENTIAL -- name the behavior it changes. "Wrong but
#            harmless" is not a KEEP.
#   7. 🟥 "BOTH ANSWERED" AND "THE SCORER NEVER MOVED" LOOK IDENTICAL -- and only one of them is a
#      CUT. Step 6's redundancy branch reads equal outcomes as evidence about the SECTION; it is
#      equally consistent with the instrument standing still, in which case the CUT is manufactured
#      by the measurement rather than found by it. This is the one failure on the calibration list
#      whose silence is shaped like a finding (measurement-integrity-checklist.md n+12; the external
#      name for the cached-scorer instance is "frozen-replay defect").
#      WHAT IS ALREADY CLOSED, so this is not a restatement of the controls above: the leak control
#      proves arm B did not SEE the section, and ablation_calibrate.sh proves the scorer responds
#      AT ALL -- but that known-pair runs against a FIXED FIXTURE, never against the live A/B pair.
#      So neither one licenses "these two arms are alike".
#      THEREFORE, before writing a CUT on equal outcomes: name an arm that MUST score differently
#      (e.g. arm A with the answer deleted outright) and show the metric moved on THIS pair. If it
#      did not, the verdict is INSTRUMENT-UNCONFIRMED, not CUT -- and that token goes in
#      `.claude/regression/ablation_verdicts.md`, because an unconfirmed instrument recorded as
#      "no difference" is exactly how a live section gets deleted.
#      Scope, measured 2026-08-23 rather than assumed: this repo has issued ZERO CUTs, so this leg
#      has never been exercised. Untested is not safe ([[feedback_not_found_is_not_zero_family]]).
#      Deliberately PROSE, not a code assert: recurrence is 1, below the mechanization threshold
#      ([[feedback_mechanize_at_repetition_prose_before]]). Mechanize on the first real CUT.
# The isolation is the whole experiment: ablation asks "is this knowable without the resident text",
# not "can an agent find it".
#
# PROCEDURE STATUS: CALIBRATED 2026-08-03 (session 2), WITH TWO NAMED RESIDUALS. Channel 1 is closed.
# Channel 2 is closed AGAINST THE ONE PATH LOCALITY THE CONTROL PROBES ($TMPDIR) -- not proven closed
# against a permission layer that treats project paths differently -- and the lane file that guards
# the calibrator covers its SCORING only, so `--tools ''` itself can be deleted with every lane still
# green. Both residuals are stated in full in `scripts/ablation_calibrate.sh` (NAMED RESIDUAL 1 and 2);
# read them before quoting this line as coverage. Re-run `scripts/ablation_calibrate.sh` before a
# sweep rather than trusting this status -- the flags are Claude Code surface and can move.
# Full record: tracks/_meta/ablation_calibration_2026-08-03_session2.md
#
# LEAK CHANNEL 1 -- system prompt (CLOSED by the cwd move). The first version of step 3 said
# "dispatch TWO isolated agents ... forbidden to read anything else". A Claude Code subagent is
# handed the project CLAUDE.md as part of its SYSTEM PROMPT, so a file-access ban buys nothing: arm B
# already holds the uncut original and the trimmed arm file is decoration. Caught by a control that
# gave an agent NO file and banned every tool -- it reproduced the ablated section verbatim and named
# its own source, "project instructions / CLAUDE.md included in my system prompt". In the same run one
# arm answered from the injected copy while another reported the section missing, so the method could
# return a false KEEP or a false CUT by luck. Running headless from outside the repo removes this
# channel (verified: no arm supplied -> NOT IN MY CONTEXT).
#
# LEAK CHANNEL 2 -- tools (CLOSED for the probed locality; see NAMED RESIDUAL 1). `claude -p` holds
# Bash/Read/Glob/Grep, and cwd does not stop them: adversarial review ran the arm from a scratch dir
# with the section removed and the arm FOUND IT IN THE REAL CLAUDE.md AND CITED THE FILE. Both
# `--tools ''` and the denylist form now pass a three-control known pair (positive / negative /
# tool-channel), and the calibration run agreed across all 3 reps -- which is a statement about the
# CALIBRATION, not about the arms: step 5 above says the runner is nondeterministic and it is, on a
# 68k-char asset. `--tools ''` is the shipped form because it is
# an allowlist. The tool control still FIRES with no flags -- verified, so a green run means the
# flag worked, not that the control went blind.
#   * The earlier claim that `--tools ''` fails its positive control was WRONG. That verdict came
#     from a fixture that failed with the flag AND without it -- the fixture was the defect, and it
#     indicted both flags. Rebuilding the fixture exonerated both.
# Direction of error matters here and it is the dangerous one: arm B answering scores as
# "redundant -> deletion candidate", so a tool leak manufactures FALSE CUT on load-bearing sections.
#
# VERDICTS ARE NOT KEPT HERE. `.claude/regression/ablation_verdicts.md` (TRACKED) holds the verdict
# table, the reps, and the pre-registration log. This header used to carry them, which put a public
# script's load-bearing safety claims behind citations to `tracks/**` -- gitignored, so unreadable to
# every reviewer who is not the operator. A verdict a reviewer cannot open is a phantom citation.
# Narrative record (operator-local, not required to read the table):
#              tracks/_meta/ablation_calibration_2026-08-03_session2.md
#              tracks/_meta/ablation_method_correction_2026-08-03.md (the two leaks, as found)
#
# Usage:  bash scripts/probe_scope_check.sh [--self-test]     (both forms run the same checks)
#         bash scripts/probe_scope_check.sh --fixture-corpus <path>   (control C only — not for humans)
# Exit 0 = every Scope resolves AND control C held
#      1 = instrument error (missing probe set · unknown option · control C could not run)
#      3 = a CONTROL FAILED — either a Scope does not resolve, or control C's ambiguous-basename
#          term did not hold. Both mean 'this instrument is not currently trustworthy'; the printed
#          line above the exit says which. (Callers that map 3 to 'a probe Scope no longer resolves'
#          are now imprecise — scripts/selfcheck.sh is the one such caller.)

set -uo pipefail
FH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Fixture mode exists ONLY so the ambig-gate arm below can point the same code at a fixture corpus.
# It is an ARGV flag, deliberately not an environment variable: cross-family review measured the env
# form as a fail-open kill switch — `PROBE_SCOPE_FIXTURE=<2-row file> bash probe_scope_check.sh`
# validated two probes instead of the real corpus, silently skipped control C, and still printed
# "every probe Scope resolves" with exit 0. An exported variable travels into every child process and
# nobody sees it; an argv flag has to be typed at the call site. A floor that a stray env var can
# switch off is not a floor ([[feedback_non_defeasible_floor]]).
FIXTURE_CORPUS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --fixture-corpus) FIXTURE_CORPUS="${2:?--fixture-corpus needs a path}"; shift 2 ;;
    # `--self-test` is what selfcheck.sh passes. It has always been a no-op (both forms run the same
    # checks) but it must be ACCEPTED: the first draft of this parser rejected unknown options, which
    # turned the shipped `selfcheck.sh` call into `exit 1 unknown option` — a self-inflicted break of
    # the one caller, caught by adversarial review before commit.
    --self-test) shift ;;
    *) echo "❌ probe-scope: unknown option '$1'" >&2; exit 1 ;;
  esac
done
PROBES="${FIXTURE_CORPUS:-$FH/.claude/regression/probes.md}"

# ── Section matching ──────────────────────────────────────────────────────────
# A probe writes a section SHORT (`CLAUDE.md §Autonomous Initiative`); the asset's real anchor may be
# a long `## ` heading, a `### ` sub-heading, or a bold-lead paragraph (`**Guards**:`). Matching only
# `## ` headings scored 9 of 16 scopes as unmatched and put a 7-probe section at UNMEASURED — a false
# zero a narrow control passed straight over, because that control fed the short name in directly and
# never exercised the heading-derived path the scan uses. Direction matters too: the probe's name is a
# PREFIX of the anchor, never the reverse.
_anchors() {  # $1=asset file — every section-ish anchor text, one per line
  # awk, not a regex alternation: a bold-lead anchor can contain `*` itself
  # (`**Substantive carve-out — `docs/*.md` · …**`), which defeats a `[^*]+` class and made that
  # anchor invisible — reported as a STALE scope when the section was right there. Cut from the
  # opening `**` to the NEXT `**`, which is exact regardless of what sits between them.
  awk '
    /^```/      { fence = !fence; next }
    fence       { next }
    /^##+ /     { sub(/^#+ /, ""); print; next }
    /^\*\*/     { l = substr($0, 3); i = index(l, "**"); if (i > 1) print substr(l, 1, i - 1) }
  ' "$1" 2>/dev/null
}

# ONE extractor feeds the control and every count taken from the probe set. `_scope_rows` emits one
# line per probe ROW, un-deduped; `_all_scopes` (control B) is that list deduped, and `_scope_hits`
# matches over the same list. The earlier split — control on a table parser, matcher on a free-text scan —
# left the control certifying a number it did not govern: a prose line ending in `CLAUDE.md §Autonomous
# Initiative` (a retirement note, a see-also — probes.md:11 is already such a line) inflated the count
# by 1 while control B reported stale=0 and selfcheck said PASS. That is the two-code-paths defect the
# comment below R2 declares closed, re-created on the other axis, and in the worse direction: the
# loose path is the one that produces the output.
# Dedup belongs ONLY to the control: eight probes legitimately share one Scope, so `sort -u` in the
# matcher would collapse them to 1 and under-report.
_scope_rows() {  # one "asset<TAB>section" per probe row; unparseable cells -> stderr
  awk -F'|' 'NF>=6 && $2 ~ /`/ { print $5 }' "$PROBES" 2>/dev/null \
  | sed -E 's/`//g; s/^[[:space:]]+//; s/[[:space:]]+$//' \
  | while IFS= read -r cell; do
      [ -n "$cell" ] || continue
      case "$cell" in
        *" §"*)
          _a="${cell%% §*}"; _n="${cell#* §}"
          case "$_n" in *" · "*) _n="${_n%% · *}" ;; esac
          printf '%s\t%s\n' "$_a" "$_n" ;;
        *)      printf 'UNPARSED\t%s\n' "$cell" >&2 ;;
      esac
    done
}

_scope_hits() {  # $1=asset basename  $2=anchor -> matching probe rows (control A only)
  # Normalize BOTH sides to a basename. The caller passes a bare asset name while a Scope cell
  # may write a full path (`knowledge/shared/rules/sync_push_protocols.md §…`), so a raw `$1 == asset`
  # dropped every path-qualified scope — and control B, which resolves assets path-agnostically, was
  # green throughout. Running the script on `.claude/rules/fh_4axis_gate.md` printed a confident
  # "100% unmeasured" while three probes defended it. Sharing an extractor is not enough; the KEY has
  # to be shared too. Collisions are the control's job (_resolve_asset returns AMBIGUOUS).
  _scope_rows 2>/dev/null | awk -F'\t' -v asset="$1" -v anchor="$2" '
    { p = $1; sub(/^.*\//, "", p) }
    p == asset && $2 != "" && substr(anchor, 1, length($2)) == $2 { n++ }
    END { print n + 0 }'
}

# Every Scope CELL in the probe table, as "asset<TAB>name" — plus, on stderr, every cell this parser
# could not decompose. The first version grepped `<x>.md §` and silently dropped 7 of 20 cells (assets
# that are not .md, cells written without `§`, and one wrapped in backticks). It then printed
# `stale=0 · unresolvable=0`, which reads as "every scope resolves" while covering 65% of them —
# absence measured without a counter for what was skipped, the exact defect this repo names.
_all_scopes() { _scope_rows | sort -u; }

_resolve_asset() {  # $1=asset name -> a real path, 'AMBIGUOUS', or empty
  # -print -quit picked an arbitrary same-named file, which would validate a scope against the WRONG
  # file and hide a stale one. `templates/` is precisely where identically-named copies live.
  [ -f "$FH/$1" ] && { echo "$FH/$1"; return; }
  local n hits
  hits=$(find "$FH" -name "$(basename "$1")" -not -path '*/node_modules/*' 2>/dev/null)
  n=$(printf '%s\n' "$hits" | grep -c . )
  [ "$n" -eq 1 ] && { printf '%s\n' "$hits"; return; }
  [ "$n" -gt 1 ] && { echo AMBIGUOUS; return; }
  echo ""
}

# ── CONTROLS ──────────────────────────────────────────────────────────────────
# Two arms, because the first version only had the easy one. A known-negative ("garbage must not
# match") tests that the parser is not indiscriminate; it says nothing about whether real scopes
# resolve. Control B catches this instrument's actual failure mode: a section gets renamed or
# relocated (salience-splitter moves content out of CLAUDE.md routinely) and its probes silently stop
# matching, so the corpus reads as LESS covered than it is — an error that points the reader at
# deleting a section which is in fact defended.
_control() {
  local pos neg head rc=0 stale=0 nofile=0 nonmd=0 ambig=0 path a n
  head=$(grep -m1 '^## Autonomous Initiative' "$FH/CLAUDE.md" 2>/dev/null); head="${head#\#\# }"
  [ -n "$head" ] || { echo "  control A: FIXTURE — the anchor heading is gone from CLAUDE.md"; return 1; }
  pos=$(_scope_hits "CLAUDE.md" "$head")
  neg=$(_scope_hits "CLAUDE.md" "Zzz No Such Section Exists")
  # A SECOND positive arm, path-qualified on purpose. The first arm asks only about `CLAUDE.md`,
  # which every probe writes unqualified — so it never exercises the basename normalization in
  # _scope_hits, and reverting that normalization left both controls green (measured). A repair with
  # no arm that goes red when it is undone is not anchored; this is that arm.
  local pos2; pos2=$(_scope_hits "fh_4axis_gate.md" "Lightweight exception")
  # Third arm: a basename that really is duplicated in-tree must resolve to AMBIGUOUS. This anchors
  # the RESOLVER (reverting it to "pick the first hit" now turns this red — measured), which guards
  # the fail-open of validating a scope against the WRONG same-named file.
  # The `[ "$ambig" -eq 0 ]` term in the exit gate below used to be unanchored: no live Scope uses a
  # duplicated basename, so nothing drove `ambig` above 0 and dropping the term kept the controls
  # green (measured). The objection recorded here was that anchoring it would mean mutating the probe
  # corpus from inside the control — correct, and the reason the arm lives OUTSIDE the control
  # instead: `_ambig_gate_arm` re-invokes this script against a FIXTURE corpus via
  # PROBE_SCOPE_FIXTURE. The real corpus is never touched. See below.
  local dup; dup=$(_resolve_asset "plugin.json")
  echo "  control A (known pair): positive='${head:0:34}…'=$pos (need >0) · path-qualified positive=$pos2 (need >0) · negative=$neg (need 0)"
  echo "  control A (duplicate-basename): plugin.json → ${dup:-<empty>} (need AMBIGUOUS)"
  { [ "${pos:-0}" -gt 0 ] && [ "${pos2:-0}" -gt 0 ] && [ "${neg:-0}" -eq 0 ] && [ "$dup" = AMBIGUOUS ]; } || rc=1

  while IFS=$'\t' read -r a n; do
    [ -n "$a" ] && [ -n "$n" ] || continue
    path=$(_resolve_asset "$a")
    if [ -z "$path" ]; then
      echo "  ⚠️  NOFILE  $a §$n — probe names an asset that does not resolve"
      nofile=$((nofile+1)); continue
    fi
    if [ "$path" = AMBIGUOUS ]; then
      echo "  ⚠️  AMBIGUOUS $a §$n — more than one file shares this basename; qualify the Scope with a path"
      ambig=$((ambig+1)); continue
    fi
    case "$a" in
      *.md) ;;
      *)  # A shell/JSON asset has no markdown anchors, so this extractor cannot decide. Saying
          # "stale" would be a false accusation; saying nothing would be a silent gap. Count it.
          echo "  ⚠️  UNCHECKABLE $a §$n — not a markdown asset; this extractor cannot resolve section anchors in it"
          nonmd=$((nonmd+1)); continue ;;
    esac
    _anchors_out="$(_anchors "$path")"; _anchors_rc=$?
    # DIAGNOSTIC-ONLY, MEASURED: the verdict is unchanged with and without this branch — `pipefail`
    # already propagated awk's nonzero, so both forms exit 3. What changes is that the operator is
    # told "instrument error" instead of "STALE", which sends them to the file instead of to a probe
    # that was fine. Recorded as a message improvement, NOT as a closed fail-open.
    # ANY nonzero from the extractor is an instrument error, not a finding. Routing on `-ne 0`
    # rather than a sentinel: an explicit `[ -r ]` guard was added here first and measured to be
    # observably INERT — awk already exits 2 on an unreadable file, so the guard changed nothing and
    # only looked like coverage. Reverting it left behaviour identical, which is the test that
    # caught it. The direction that matters is that an unreadable asset must not be scored STALE:
    # that would send the next reader to edit a probe that was fine.
    if [ "$_anchors_rc" -ne 0 ]; then
      echo "  ⚠️  UNREADABLE $a §$n — the asset exists but cannot be read; this is an instrument error, NOT a stale probe"
      nofile=$((nofile+1)); continue
    fi
    # 🟡 지금은 «접두가 다르다»라 안 접히지만, 포맷이 바뀌어 양쪽 접두가 같아지면 즉시 뚫린다
    if ! printf '%s\n' "$_anchors_out" | LC_ALL=C awk -v n="$n" 'substr($0,1,length(n))==n{f=1} END{exit !f}'; then
      echo "  ❌ STALE   $a §$n — no section by that name in the asset (renamed, or relocated by a split)"
      stale=$((stale+1))
    fi
  done < <(_all_scopes)
  local skipped; skipped=$(_all_scopes 2>&1 >/dev/null | grep -c '^UNPARSED' || true)
  echo "  control B (scope resolution): stale=$stale · unresolvable-asset=$nofile · ambiguous-basename: $ambig (these three need 0) · non-markdown assets (undecidable here): $nonmd · scope cells this parser could NOT decompose: $skipped (reported, not silently dropped — this parser only splits on '§', so a scope written in another notation is UNVALIDATED here, not sectionless)"
  # `ambig` gates too. Without it an ambiguous basename printed a warning and then let the number
  # publish anyway — a caveated publish, which this script's own rule forbids ("the coverage number is
  # WITHHELD, not printed with a caveat"). It belongs with nofile, not with nonmd: non-markdown is
  # permanently undecidable here, whereas an ambiguous basename has a stated fix (qualify the Scope).
  { [ "$stale" -eq 0 ] && [ "$nofile" -eq 0 ] && [ "$ambig" -eq 0 ]; } || rc=1
  return $rc
}

# ── AMBIG-GATE ARM ────────────────────────────────────────────────────────────
# Anchors the `[ "$ambig" -eq 0 ]` term of control B's exit gate, which no live Scope exercises.
# A semantic-stub known pair: two fixture corpora identical except for ONE row whose Scope names a
# basename that really is duplicated in-tree. Both fixtures carry the rows control A needs, so the
# ONLY thing that differs between the two exits is `ambig` — without those rows the ambiguous fixture
# would exit 3 via a failed control A and the arm would pass for the wrong reason.
# Skipped when already running against a fixture (no recursion).
_ambig_gate_arm() {
  local d rc_pos rc_neg out_pos amb_pos
  d=$(mktemp -d) || { echo "  ❌ ambig-gate arm: mktemp failed — arm NOT RUN (instrument error)"; return 2; }
  # Single-quoted trap body: `$d` expands when the trap FIRES, inside the function where `d` is still
  # in scope. The first version was `trap "rm -rf '$d'" RETURN`, which pastes the path into a
  # single-quoted string at definition time — a TMPDIR containing an apostrophe closes the quote and
  # the trap becomes a syntax error. Cross-family review reproduced exactly that on a directory named
  # `/tmp/probe quote ' dir` ("return trap: unexpected EOF while looking for matching `''").
  trap 'rm -rf "$d"' RETURN
  {
    printf '| Probe | Trigger | Expect | Scope | Class |\n|---|---|---|---|---|\n'
    printf '| `X-CTRL-01` | t | e | CLAUDE.md §Autonomous Initiative Layer | mandatory-pass |\n'
    printf '| `X-CTRL-02` | t | e | fh_4axis_gate.md §Lightweight exception | mandatory-pass |\n'
  } > "$d/clean.md"
  cp "$d/clean.md" "$d/ambig.md"
  printf '| `X-AMBIG-01` | t | e | plugin.json §Anything | mandatory-pass |\n' >> "$d/ambig.md"

  bash "${BASH_SOURCE[0]}" --fixture-corpus "$d/clean.md" >/dev/null 2>&1; rc_neg=$?
  # Keep the positive arm's OUTPUT, not just its exit code. Exit 3 is the generic "a Scope does not
  # resolve" code, so `rc_pos == 3` alone proves only that the child failed *somehow* — a fixture that
  # went stale or unresolvable for an unrelated reason would satisfy it and the arm would certify a
  # gate that never fired. Cross-family review named this: an untyped child exit accepted as proof.
  # So the arm asserts the typed reason too: the child must report ambiguous-basename >= 1.
  out_pos=$(bash "${BASH_SOURCE[0]}" --fixture-corpus "$d/ambig.md" 2>&1); rc_pos=$?
  amb_pos=$(printf '%s\n' "$out_pos" | sed -n 's/.*ambiguous-basename: \([0-9][0-9]*\).*/\1/p' | head -1)
  amb_pos=${amb_pos:-0}
  echo "  control C (ambig gate): clean fixture exit=$rc_neg (need 0) · duplicated-basename fixture exit=$rc_pos (need 3) · its ambiguous-basename count=$amb_pos (need >0 — the typed reason, not just the code)"
  [ "$rc_neg" -eq 0 ] && [ "$rc_pos" -eq 3 ] && [ "$amb_pos" -gt 0 ]
}

[ -f "$PROBES" ] || { echo "❌ probe-scope: probe set missing: $PROBES — instrument error, NOT an empty result"; exit 1; }

echo "── probe-scope check — does every Scope still name a real section? ──"
if [ -z "$FIXTURE_CORPUS" ]; then
  _ambig_gate_arm; _arm_rc=$?
  # Distinguish the two failures instead of collapsing them. Returning 2 means the arm could not RUN
  # (mktemp failed) — an instrument error, which this file's contract maps to exit 1. Returning 1
  # means the arm RAN and the gate term did not hold — that is a real control failure, exit 3.
  # The first draft mapped both to exit 3 with the message "the ambiguous-basename term is not
  # holding", so a broken TMPDIR accused the code under test of a defect it did not have.
  if [ "$_arm_rc" -eq 2 ]; then
    echo "❌ probe-scope: ambig-gate arm could not run (instrument error, exit 1) — NOT a finding about the probe corpus."
    exit 1
  elif [ "$_arm_rc" -ne 0 ]; then
    echo "❌ AMBIG-GATE ARM FAILED (exit 3) — the ambiguous-basename term of the exit gate is not"
    echo "   holding: a fixture whose Scope names a duplicated basename did not fail the check with"
    echo "   ambiguous-basename > 0."
    exit 3
  fi
fi
if ! _control; then
  echo "❌ SCOPE CHECK FAILED (exit 3) — a probe points at a section that is not there."
  echo "   Fix the scope strings (or the probe) named above, then re-run. probes.md's own maintenance"
  echo "   rule already requires this: when a Scope target moves, its probes move in the same commit."
  exit 3
fi

# Recomputed here, NOT read from control B's `local skipped` — that variable is function-scoped and
# reads as unset at this point, so `${skipped:-0}` silently took the "nothing unvalidated" branch and
# printed the unqualified success line while four cells were unchecked. An instrument that cannot see
# its own number is the failure this file exists to report, committed by this file.
unparsed_n=$(_all_scopes 2>&1 >/dev/null | grep -c '^UNPARSED' || true)
# BOTH classes are unvalidated, and the first version of this line counted only the first — so it
# said "4 UNVALIDATED" when 5 cells were unchecked, and a corpus of only non-markdown scopes printed
# ⚠️ UNCHECKABLE and then the UNQUALIFIED success line on the very next row. That is the defect this
# conditional exists to remove, reproduced one axis over inside the fix for it.
nonmd_n=$(_all_scopes 2>/dev/null | awk -F'\t' '{print $1}' | grep -vc '\.md$' || true)
unvalidated=$((unparsed_n + nonmd_n))
if [ "${unvalidated:-0}" -gt 0 ]; then
  echo "✅ every probe Scope this parser could decompose resolves to a real section — ${unvalidated} cell(s) UNVALIDATED (${unparsed_n} in a notation this parser cannot split + ${nonmd_n} non-markdown; neither proven sectionless nor proven fine)"
else
  echo "✅ every probe Scope resolves to a real section"
fi
exit 0
