#!/usr/bin/env bash
# test_sim_isolated_run_lanes.sh — behavioural known-pair lanes for scripts/sim_isolated_run.sh
#
# WHY THESE LANES AND NOT OTHERS. The runner exists because a sim became an agent fleet
# (2026-08-29: corpus self-contamination + a launchd agent written to the operator's machine +
# a false positive pointing at the desired conclusion). So the lanes pin the properties that
# failure would have needed, not the ones that are easy to assert:
#   L1–L3  usage guards            — a runner that silently accepts a bad mode runs the wrong thing
#   L4     ABSENT, never empty     — a missing surface and an empty one must not collapse
#   L5     THREE-valued verdict    — the first runner's `timeout 300` killed exactly the heavy arms
#                                    and left 0-byte files that read as "the identity did not fire".
#                                    A false RED manufactured by the instrument. `UNMEASURED` and
#                                    `EMPTY` must stay distinguishable from each other AND from a no.
#   L6     observe-mode VOID       — if the read-only tool set leaks, the run is void, not "clean"
#   L7     machine-surface diff    — the launchd class. Detector, not gate — but it must FIRE.
#   L8     --no-harness is opt-in  — `--restricted` drops the project CLAUDE.md, i.e. it measures
#                                    the BASE MODEL. If it ever became the default again, every
#                                    salience measurement would silently be of the wrong thing.
#   L9     always exit 0           — a detector that can block gets skipped; then it detects nothing
#
# The `claude` CLI is STUBBED. That is deliberate and it is the only way these lanes can carry a
# known pair: a real call is nondeterministic and costs money, so its output could never be a
# fixture. What is under test here is the runner's OWN logic — verdict classification, isolation
# bookkeeping, flag plumbing — never the model's answer.
#
# Usage: bash scripts/test_sim_isolated_run_lanes.sh

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUT="${FH_SIM_RUNNER_BIN:-$ROOT/scripts/sim_isolated_run.sh}"
pass=0; fail=0
ok()  { printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
no()  { printf '  ❌ %s\n' "$1"; fail=$((fail+1)); }

if [ ! -f "$SUT" ]; then
  echo "FAIL  test_sim_isolated_run_lanes.sh: subject absent ($SUT) — skipped is not passed"
  exit 1
fi

WORKROOT="$(mktemp -d "${TMPDIR:-/tmp}/simlane-XXXXXX")"
trap 'rm -rf "$WORKROOT"' EXIT

# ── stub `claude` — behaviour selected by FH_STUB_MODE, read at call time ─────────────────────
STUBBIN="$WORKROOT/bin"; mkdir -p "$STUBBIN"
cat > "$STUBBIN/claude" <<'STUB'
#!/usr/bin/env bash
# Records the argv it was handed so a lane can assert on flag plumbing.
printf '%s\n' "$*" >> "${FH_STUB_ARGV_LOG:-/dev/null}"
case "${FH_STUB_MODE:-say}" in
  say)      echo "stub answer" ;;
  silent)   : ;;                                   # rc 0, no output  → EMPTY
  die)      exit 7 ;;                              # rc!=0, no output → UNMEASURED
  write)    echo "wrote"; : > "./LANE_SIDE_EFFECT.txt" ;;   # dirties its own clone
  machine)  echo "ok"; mkdir -p "$HOME/Library/LaunchAgents"
            : > "$HOME/Library/LaunchAgents/com.lane.probe.plist" ;;
esac
exit 0
STUB
chmod +x "$STUBBIN/claude"

# A throwaway git repo for the runner to clone. `--local` needs a real repo with a commit.
SRC="$WORKROOT/src"; mkdir -p "$SRC"
( cd "$SRC" && git init -q . && git config user.email l@l && git config user.name l \
  && echo hi > f.txt && git add f.txt && git commit -qm init ) >/dev/null 2>&1

run_sut() {  # env is set by the caller; echoes combined output, sets RC
  OUT="$( cd "$SRC" && PATH="$STUBBIN:$PATH" bash "$SUT" "$@" 2>&1 )"; RC=$?
}

echo "── sim_isolated_run known-pair lanes ─────────────────────────────────"

# L1/L2/L3 — usage guards (known-negative: a bad invocation must NOT proceed)
run_sut --reps 1 --prompt p
[ "$RC" -eq 2 ] && ok "L1 missing --arm → exit 2" || no "L1 missing --arm: rc=$RC"
run_sut --arm a --reps 1
[ "$RC" -eq 2 ] && ok "L2 missing --prompt → exit 2" || no "L2 missing --prompt: rc=$RC"
run_sut --arm a --prompt p --mode bogus
[ "$RC" -eq 2 ] && ok "L3 bogus --mode → exit 2" || no "L3 bogus --mode: rc=$RC"

# L4 — ABSENT, never an empty line, for a surface that does not exist
FAKEHOME="$WORKROOT/home"; mkdir -p "$FAKEHOME"
OUTDIR="$WORKROOT/o4"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" ) >/dev/null 2>&1
if grep -q '^ABSENT$' "$OUTDIR/_machine_before.txt" 2>/dev/null; then
  ok "L4 missing surface recorded as ABSENT (not an empty line)"
else no "L4 ABSENT token missing from snapshot"; fi

# L5 — THREE-valued verdict. This is the lane the false-RED incident bought.
OUTDIR="$WORKROOT/o5a"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=die \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" 2>&1 )
printf '%s' "$OUT" | grep -q "UNMEASURED" \
  && ok "L5a rc!=0 + 0 bytes → UNMEASURED (not a negative result)" \
  || no "L5a expected UNMEASURED, got: $(printf '%s' "$OUT" | grep -E 'r1' | head -1)"
OUTDIR="$WORKROOT/o5b"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=silent \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" 2>&1 )
printf '%s' "$OUT" | grep -q "EMPTY" \
  && ok "L5b rc=0 + 0 bytes → EMPTY (distinct from UNMEASURED)" \
  || no "L5b expected EMPTY"
# known-POSITIVE for the pair: a normal answer must be neither
OUTDIR="$WORKROOT/o5c"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" 2>&1 )
if printf '%s' "$OUT" | grep -q "captured" && ! printf '%s' "$OUT" | grep -qE "EMPTY|UNMEASURED"; then
  ok "L5c control — a real answer is captured, not classified as empty/unmeasured"
else no "L5c control failed (the three-way split does not discriminate)"; fi

# L6 — observe mode must call a write VOID, not clean
OUTDIR="$WORKROOT/o6"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=write \
   bash "$SUT" --arm a --reps 1 --prompt p --mode observe --out "$OUTDIR" 2>&1 )
printf '%s' "$OUT" | grep -q "VOID" && printf '%s' "$OUT" | grep -q "CONTAMINATED" \
  && ok "L6 observe-mode write → VOID + CONTAMINATED" || no "L6 write in observe not caught"
# control: the same write in act mode is CONTAINED, not VOID
OUTDIR="$WORKROOT/o6b"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=write \
   bash "$SUT" --arm a --reps 1 --prompt p --mode act --out "$OUTDIR" 2>&1 )
printf '%s' "$OUT" | grep -q "VOID" \
  && no "L6b control — act mode wrongly called VOID (the two modes are not separated)" \
  || ok "L6b control — same write in act mode is contained, not VOID"

# L7 — the launchd class. The detector must FIRE on a machine-surface delta.
OUTDIR="$WORKROOT/o7"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=machine \
   bash "$SUT" --arm a --reps 1 --prompt p --mode act --out "$OUTDIR" 2>&1 )
printf '%s' "$OUT" | grep -q "MACHINE SURFACE CHANGED" \
  && ok "L7 machine-surface delta → detected + CONTAMINATED" \
  || no "L7 launchd-class side effect NOT detected"
rm -f "$FAKEHOME/Library/LaunchAgents/com.lane.probe.plist"

# L8 — --restricted is opt-in only. Both directions, because only the pair proves the plumbing.
OUTDIR="$WORKROOT/o8"; LOG="$WORKROOT/argv8.log"; : > "$LOG"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say FH_STUB_ARGV_LOG="$LOG" \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" ) >/dev/null 2>&1
grep -q -- "--restricted" "$LOG" \
  && no "L8a DEFAULT passed --restricted — the harness under test would not be loaded" \
  || ok "L8a default does NOT pass --restricted (project CLAUDE.md stays resident)"
OUTDIR="$WORKROOT/o8b"; LOG2="$WORKROOT/argv8b.log"; : > "$LOG2"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say FH_STUB_ARGV_LOG="$LOG2" \
   bash "$SUT" --arm a --reps 1 --prompt p --no-harness --out "$OUTDIR" ) >/dev/null 2>&1
grep -q -- "--restricted" "$LOG2" \
  && ok "L8b --no-harness DOES pass --restricted (control-arm generator works)" \
  || no "L8b --no-harness did not reach the CLI"

# L9 — detector, never a gate: even a contaminated run exits 0
OUTDIR="$WORKROOT/o9"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=write \
   bash "$SUT" --arm a --reps 1 --prompt p --mode observe --out "$OUTDIR" ) >/dev/null 2>&1
[ $? -eq 0 ] && ok "L9 always exit 0 (a detector that can block gets skipped)" \
             || no "L9 non-zero exit — callers will learn to skip it"

# L10 — the clone's PARENT must not expose sibling arms. Measured leak: an arm scanning `../`
# for mappable projects reported the other reps' work dirs by name.
OUTDIR="$WORKROOT/o10"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
   bash "$SUT" --arm a --reps 2 --prompt p --out "$OUTDIR" ) >/dev/null 2>&1
# 🟥 PROPERTY-BASED ON PURPOSE. A first draft asserted on the literal path
# `<out>/w_a_r1/...`; a revert probe then "failed" it for the wrong reason — the path simply no
# longer existed, so the lane detected a rename rather than the leak. Locate the clones by what
# they ARE (directories containing .git under the out dir) and ask the actual question:
# does any clone's PARENT contain another clone?
CLONES=$(find "$OUTDIR" -maxdepth 3 -type d -name .git 2>/dev/null | sed 's|/.git$||' | sort)
nclone=$(printf '%s\n' "$CLONES" | grep -c . )
leak=0
for c in $CLONES; do
  par=$(dirname "$c")
  # count OTHER clones that share this parent
  others=$(printf '%s\n' "$CLONES" | grep -v "^$c$" | while read -r o; do
             [ "$(dirname "$o")" = "$par" ] && echo x; done | grep -c x)
  [ "$others" -gt 0 ] && leak=$((leak+1))
done
if [ "$nclone" -ge 2 ] && [ "$leak" -eq 0 ]; then
  ok "L10 no clone shares a parent with another ($nclone clones, 0 co-parented)"
else no "L10 sibling clones share a parent (clones=$nclone co-parented=$leak)"; fi
# control: the lane must be able to SEE two clones, else L10 passes on an empty set
[ "$nclone" -ge 2 ] \
  && ok "L10b control — $nclone clones found (L10 did not pass on an empty set)" \
  || no "L10b control — found $nclone clone(s); L10 proves nothing"

# L11 — --setup builds the precondition INSIDE the clone, and a failing setup VOIDs the arm
# rather than letting the sim run in a state it was not meant to observe.
OUTDIR="$WORKROOT/o11"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" \
   --setup 'mkdir -p tracks/demoproj' ) >/dev/null 2>&1
[ -d "$OUTDIR/w_a_r1/repo/tracks/demoproj" ] \
  && ok "L11 --setup ran inside the clone (precondition built)" \
  || no "L11 --setup did not take effect in the clone"
# and it must NOT have touched the source tree — the whole point of doing it in the clone
[ -d "$SRC/tracks/demoproj" ] \
  && no "L11b --setup leaked into the SOURCE tree" \
  || ok "L11b control — source tree untouched by --setup"
OUTDIR="$WORKROOT/o11c"
OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" --setup 'exit 3' 2>&1 )
printf '%s' "$OUT" | grep -q "SETUP FAILED" && printf '%s' "$OUT" | grep -q "CONTAMINATED" \
  && ok "L11c failing --setup → arm VOID, not a silent negative result" \
  || no "L11c failing setup did not void the arm"

echo "sim_isolated_run lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
