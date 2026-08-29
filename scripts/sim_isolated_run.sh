#!/usr/bin/env bash
# sim_isolated_run.sh — run a blind floor-tier sim WITHOUT letting it become an agent fleet.
#
# WHY THIS EXISTS (measured 2026-08-29, twice):
#   A blind sim of identity ④ was launched as 12 parallel `claude -p` calls in the LIVE repo cwd.
#   Three things went wrong, and the third is the one that matters:
#     1. the arms wrote 6 files into the working tree and read each other's output — corpus
#        self-contamination, the same defect as the 2026-08-23 probe's invalidated arm A3;
#     2. one arm registered a **launchd agent** in ~/Library/LaunchAgents — an unrequested,
#        persistent change to the operator's machine, made by something called "a measurement";
#     3. 🟥 the contamination produced a FALSE POSITIVE POINTING AT THE DESIRED CONCLUSION.
#        An arm answered "이미 돼있어" — found prior art, declined to rebuild — which is the
#        textbook success scene for identity ④. The "prior art" was a file another arm had
#        created two minutes earlier. Scored naively, ④ would have looked GREEN, on the same
#        day the operator asked for ④ to be shown green.
#   Isolation is therefore not "keep the answer word out of the prompt". It is "put the target
#   where the arms cannot reach it".
#
# WHAT THIS GIVES YOU, and what it does NOT:
#   ✅ PREVENTS repo-tree contamination   — each arm gets its own disposable clone
#   ✅ PREVENTS settings inheritance      — `--restricted` ignores user/project/local settings
#   ✅ DETECTS machine-level side effects — LaunchAgents / crontab / ~/.claude snapshot diff
#   🟥 DOES NOT PREVENT machine-level side effects in `act` mode. Full containment needs an OS
#      sandbox, which this script does not provide. `observe` mode prevents them by removing the
#      tools that could cause them; `act` mode trades that for behavioural fidelity and reports
#      what happened. Saying "isolated" without this paragraph would be the lie this file exists
#      to stop. A detector is not a gate (CLAUDE.md §Surface-Class Degrade Invariant).
#
# MODES
#   observe (default)  --tools "Read,Grep,Glob"  → read-only. No writes possible.
#   act                write tools, inside a disposable clone. Machine surfaces are snapshotted
#                      before and after; any delta is printed LOUDLY and the run is CONTAMINATED.
#   --no-harness       adds `--restricted`, which DROPS the project CLAUDE.md. See below — this is
#                      a CONTROL arm generator, never the default.
#
# 🟥 WHY `--restricted` IS NOT THE DEFAULT — measured, one variable at a time, 2026-08-29.
#   `--restricted` reads like the isolation flag you want ("ignores user, project and local
#   settings files"). It also drops the project memory, so the harness under test is not loaded.
#   The first build of this script used it, and the very first smoke run returned a bare
#   "안녕하세요! 무엇을 도와드릴까요?" to a greeting — which would have been written up as
#   **"the onboarding menu does not fire at floor tier"**, a large and false claim about FH.
#   Worse, the first known-positive PASSED and hid it: the arm answered a CLAUDE.md question
#   correctly *by grepping a file*, so "the harness is loaded" and "the model can search" were
#   never separated. The discriminating pair needs `--tools ""` so search is impossible:
#       same clone, --tools "", --restricted      → "그런 규칙이 없어요"   (memory ABSENT)
#       same clone, --tools "", no --restricted   → "🐿️"                  (memory PRESENT)
#   One variable, opposite answers. ([[feedback_instrument_cannot_discriminate_hypotheses]])
#
# 🟢 AND THE DEFECT IS REUSABLE AS AN INSTRUMENT. `--no-harness` answers a question this repo
#   asks constantly and usually by eye: **does this behaviour come from FH, or would the base
#   model have done it anyway?** Run the same prompt with and without the flag; a behaviour that
#   survives `--no-harness` was never the harness's doing. That is a control arm, and it is the
#   cheapest honest one available here.
#
# USAGE
#   bash scripts/sim_isolated_run.sh --arm cluster --reps 3 --prompt "이 프로젝트 가속화하고 싶어"
#   bash scripts/sim_isolated_run.sh --arm build --mode act --reps 3 --prompt "..." --model sonnet
#   bash scripts/sim_isolated_run.sh --arm door3 --reps 3 --prompt "..." \
#        --setup 'mkdir -p tracks/demoproj'      # build the precondition inside the clone
#   Outputs land in a run dir printed at the end; each arm/rep is its own file.
#
# 🟥 OBSERVE MODE CANNOT SEE AN EMPTY DIRECTORY — and FH has machine signals that ARE empty
#   directories. `fh_detail_protocols.md` §Branch test defines a mapped project as a
#   `tracks/{name}/` **dir**, which is routinely empty; `Glob` matches files, so a read-only arm
#   reports "no mapped projects" no matter what you created. Measured 2026-08-29: a `--setup` that
#   ran `mkdir -p tracks/demoproj` succeeded, the directory existed in the clone, and all three
#   arms still answered "매핑된 프로젝트가 하나도 없다". The fixture was real and invisible.
#   ⇒ **A fixture for observe mode must contain a FILE.** This is an instrument constraint, not an
#   FH defect (a normal session has Bash and can `ls`) — but scoring an arm without knowing it
#   produces a confident zero from a fixture that was never observable.
#
# 🟥 PROJECT HOOKS DO NOT RUN IN A DISPOSABLE CLONE — so this runner cannot measure anything
#   that depends on one. Measured 2026-08-30: an arm copied `.claude/settings.json` into its clone
#   to make the PreToolUse PriorArt hook live; not one of the three clones grew
#   `.claude/.prior_art_events.tsv`, while the live repo's copy carries entries from the same hour.
#   The hook never fired, so the "hook vs no-hook" contrast was HOOK ≡ NOHOOK and either verdict
#   would have been false. ⇒ Before claiming a hook-dependent result, check the hook's own
#   evidence file INSIDE the clone; absence of that file invalidates the arm, not the hypothesis.
#
# 🟥 CONTROL IS NOT OPTIONAL. Always run at least one arm whose correct answer is "the thing
#   being measured should NOT fire". An instrument that fires on everything measures nothing
#   ([[feedback_control_presence_is_not_discrimination]]).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARM=""; REPS=1; PROMPT=""; MODE="observe"; MODEL="sonnet"; TIMEOUT=900; OUTDIR=""; NOHARNESS=0; SETUP=""; EXTRA=""
while [ $# -gt 0 ]; do
  case "$1" in
    --arm)     ARM="${2:-}"; shift 2 ;;
    --reps)    REPS="${2:-1}"; shift 2 ;;
    --prompt)  PROMPT="${2:-}"; shift 2 ;;
    --mode)    MODE="${2:-observe}"; shift 2 ;;
    --model)   MODEL="${2:-sonnet}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-900}"; shift 2 ;;
    --out)     OUTDIR="${2:-}"; shift 2 ;;
    --no-harness) NOHARNESS=1; shift ;;   # CONTROL arm: drops project CLAUDE.md. Not isolation.
    --setup)   SETUP="${2:-}"; shift 2 ;;  # shell run INSIDE each clone before the sim. See below.
    --extra-tools) EXTRA="${2:-}"; shift 2 ;;  # append tools to the mode's set. See TOOL VISIBILITY.
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done
[ -n "$ARM" ]    || { echo "FAIL: --arm required" >&2; exit 2; }
[ -n "$PROMPT" ] || { echo "FAIL: --prompt required" >&2; exit 2; }
case "$MODE" in observe|act) ;; *) echo "FAIL: --mode must be observe|act" >&2; exit 2 ;; esac

command -v claude >/dev/null 2>&1 || { echo "FAIL: claude CLI not on PATH" >&2; exit 2; }

OUTDIR="${OUTDIR:-$(mktemp -d "${TMPDIR:-/tmp}/fh-sim-XXXXXX")}"
mkdir -p "$OUTDIR"

# ── machine-surface snapshot ──────────────────────────────────────────────────────────────────
# Enumerated, not guessed. Each line is a surface a past run actually touched or plausibly could.
# `not found` is written as `ABSENT`, never as an empty string — an unreadable surface and an
# empty one must not collapse ([[feedback_not_found_is_not_zero_family]]).
snapshot() {
  local f="$1"
  {
    echo "## LaunchAgents"
    ls -1 "$HOME/Library/LaunchAgents" 2>/dev/null || echo "ABSENT"
    echo "## crontab"
    crontab -l 2>/dev/null || echo "ABSENT"
    echo "## claude settings mtime"
    # GNU-first on purpose: `stat -f` on GNU coreutils means "filesystem info" and SUCCEEDS,
    # so a BSD-first chain never reaches the fallback and silently reports the wrong thing.
    # Caught by this repo's own portability lint on the first commit attempt of this file.
    stat -c '%Y %n' "$HOME/.claude/settings.json" 2>/dev/null \
      || stat -f '%m %N' "$HOME/.claude/settings.json" 2>/dev/null || echo "ABSENT"
  } > "$f"
}

echo "── sim_isolated_run ──────────────────────────────────────────────"
echo "arm=$ARM mode=$MODE model=$MODEL reps=$REPS timeout=${TIMEOUT}s"
echo "out=$OUTDIR"

snapshot "$OUTDIR/_machine_before.txt"

CONTAMINATED=0
for r in $(seq 1 "$REPS"); do
  # Each clone gets its OWN parent directory. Siblings under one parent are visible to `../`,
  # and that is not hypothetical: an arm measured 2026-08-29 scanned its parent for mappable
  # projects and reported finding "iso_A, door_CTRL" — the other arms' work dirs. Content stayed
  # isolated, but their EXISTENCE leaked into the arm's reasoning, which is enough to change an
  # answer about "what projects are around". Isolation has to hold for the parent too.
  WRAP="$OUTDIR/w_${ARM}_r${r}"; mkdir -p "$WRAP"
  WORK="$WRAP/repo"
  # A disposable clone per REP, not per arm: two reps of the same arm contaminate each other
  # exactly as two different arms do. That was the measured failure — reps 1 and 2 of build_cron.
  if ! git clone --quiet --local --no-hardlinks "$REPO_ROOT" "$WORK" 2>"$OUTDIR/_clone_${ARM}_r${r}.err"; then
    echo "  ❌ r$r CLONE FAILED — see $OUTDIR/_clone_${ARM}_r${r}.err"
    continue
  fi

  # --setup: build the PRECONDITION the measurement needs, inside the clone, before the sim.
  # WHY THIS EXISTS: the first door-③ measurement (2026-08-29) scored 0/3 on both arms and the
  # number meant nothing — a fresh clone has no mapped project tracks, so door ③ can never reach
  # the follow-up proposal that was under test. Both arms correctly answered "there is nothing to
  # accelerate" and the instrument never entered the state it was built to observe. A run whose
  # precondition is unmet does not produce a negative result; it produces no result. Setting the
  # fixture up INSIDE the disposable clone keeps that from being a reason to touch the live tree.
  if [ -n "$SETUP" ]; then
    if ! ( cd "$WORK" && eval "$SETUP" ) >"$WRAP/_setup.log" 2>&1; then
      echo "  ❌ r$r SETUP FAILED — precondition not built, arm is VOID (see $WRAP/_setup.log)"
      CONTAMINATED=1
      continue
    fi
  fi

  if [ "$MODE" = observe ]; then
    TOOLS=(--tools "Read,Grep,Glob")
  else
    TOOLS=(--tools "Read,Grep,Glob,Bash,Write,Edit")
  fi
  # 🟥 TOOL VISIBILITY IS PART OF THE MEASUREMENT, NOT A DETAIL. `Glob` matches FILES; a
  # directory with no file directly inside it is invisible to a Read/Grep/Glob arm. FH's branch
  # test keys on `tracks/{name}/` DIRECTORIES, so an observe-mode arm can report "tracks/ has only
  # .gitkeep" while `tracks/demoproj/` and `tracks/webshop/` both exist — measured 2026-08-29,
  # verified by opening the clones. That looks exactly like a session misjudging, and it is not.
  # ⇒ When the thing under test depends on ENUMERATION, add Bash and say so:
  #      --extra-tools Bash
  # and treat the observe-only number as the "cannot enumerate" arm rather than as a defect rate.
  [ -n "$EXTRA" ] && TOOLS[1]="${TOOLS[1]},$EXTRA"
  # `--restricted` is opt-in ONLY, and opting in means you are measuring the BASE MODEL, not FH.
  [ "$NOHARNESS" -eq 1 ] && TOOLS+=(--restricted)

  # Blindness comes from the CLONE, not from a flag: `CLAUDE.local.md` is gitignored, so the
  # operator's register pin and standing bindings are structurally absent from every arm. That is
  # verifiable (`git ls-files | grep CLAUDE` returns CLAUDE.md alone) rather than asserted.
  # `.claude/settings.json` is untracked too, so no hooks fire — which makes an arm resemble a
  # CONSUMER install. State that when scoring: this measures the shipped surface, not this node.
  ( cd "$WORK" && timeout "$TIMEOUT" claude -p "$PROMPT" \
        --model "$MODEL" "${TOOLS[@]}" 2>/dev/null ) > "$OUTDIR/${ARM}_r${r}.txt"
  rc=$?
  bytes=$(wc -c < "$OUTDIR/${ARM}_r${r}.txt" | tr -d ' ')

  # 🟥 An empty output is NOT a "no" answer. The first version of tonight's runner used
  # `timeout 300`, which killed exactly the heavy arms — the ones where the behaviour under test
  # actually fired — and left 0-byte files that read as "the identity did not fire". A false RED
  # generated by the instrument. So the verdict here is three-valued, never two.
  if [ "$rc" -ne 0 ] && [ "$bytes" -eq 0 ]; then
    echo "  ⚠️  r$r UNMEASURED (rc=$rc, 0 bytes) — timeout or crash, NOT a negative result"
  elif [ "$bytes" -eq 0 ]; then
    echo "  ⚠️  r$r EMPTY (rc=0) — the session said nothing; distinct from UNMEASURED"
  else
    echo "  ✅ r$r captured ${bytes}B"
  fi

  # Report what the arm changed inside its own clone — in `act` mode this is the interesting part,
  # and in `observe` mode a non-empty diff means --restricted did not hold and the run is void.
  ( cd "$WORK" && git status --porcelain ) > "$OUTDIR/${ARM}_r${r}.treediff.txt" 2>/dev/null
  tchanged=$(wc -l < "$OUTDIR/${ARM}_r${r}.treediff.txt" | tr -d ' ')
  if [ "$MODE" = observe ] && [ "$tchanged" -gt 0 ]; then
    echo "     🟥 r$r VOID — observe mode wrote $tchanged path(s); the read-only tool set did not hold"
    CONTAMINATED=1
  elif [ "$tchanged" -gt 0 ]; then
    echo "     ℹ️  r$r touched $tchanged path(s) inside its own clone (contained)"
  fi
done

snapshot "$OUTDIR/_machine_after.txt"
if ! diff -q "$OUTDIR/_machine_before.txt" "$OUTDIR/_machine_after.txt" >/dev/null 2>&1; then
  echo ""
  echo "🟥🟥🟥 MACHINE SURFACE CHANGED DURING THIS RUN — the sim had side effects outside its clone."
  diff "$OUTDIR/_machine_before.txt" "$OUTDIR/_machine_after.txt" | sed 's/^/     /'
  echo "     이 실행은 CONTAMINATED 다. 채점하기 전에 되돌려라."
  CONTAMINATED=1
fi

echo ""
echo "── scoring reminder (the part no script can do for you) ──────────"
echo "  🟥 «찾았다»는 답이 나오면 그것이 «언제 생겼는지»부터 봐라."
echo "     tonight's false positive was an arm finding another arm's output and calling it prior art."
echo "  🟥 컨트롤 팔 없이 낸 숫자는 숫자가 아니다."
echo "  🟢 «이게 FH 때문인가»가 궁금하면 같은 프롬프트를 --no-harness 로 한 번 더 돌려라."
[ "$NOHARNESS" -eq 1 ] && echo "  ⚠️  이 실행은 --no-harness 다 — FH 를 잰 것이 아니라 «FH 없이도 그런가»를 잰 것이다."
echo ""
[ "$CONTAMINATED" -eq 1 ] && echo "RESULT: CONTAMINATED — do not score" || echo "RESULT: CLEAN"
echo "OUT: $OUTDIR"
# Detector, never a gate: always exit 0 so a caller cannot be trained to skip running it.
exit 0
