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
  # 🟥 stdin 을 그대로 받아 적는다 — 실물 `claude -p` 가 하는 짓을 재현한다.
  #    진짜 CLI 는 stdin 이 TTY 가 아니면 그것을 «읽어 프롬프트 뒤에 붙인다».
  stdin)    echo "stub answer"; cat >> "${FH_STUB_STDIN_LOG:-/dev/null}" ;;
  # L26 (2026-09-05) — a command that runs long past any sane --timeout, default SIGTERM
  # disposition (no trap): dies as soon as the watchdog signals it, so a lane can tell "the
  # deadline was enforced" from "we just waited for it to finish on its own".
  hang)     sleep 30 ;;
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

# L12 — --extra-tools must reach the CLI, and must NOT be there by default. Both directions,
# because this flag decides what the arm can SEE, and a silently-dropped tool turns an
# enumeration failure into what looks like a session misjudging.
OUTDIR="$WORKROOT/o12"; LOG12="$WORKROOT/argv12.log"; : > "$LOG12"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say FH_STUB_ARGV_LOG="$LOG12" \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" --extra-tools Bash ) >/dev/null 2>&1
grep -q "Read,Grep,Glob,Bash" "$LOG12" \
  && ok "L12 --extra-tools appended to the tool set" \
  || no "L12 --extra-tools did not reach the CLI ($(head -1 "$LOG12" 2>/dev/null))"
OUTDIR="$WORKROOT/o12b"; LOG12B="$WORKROOT/argv12b.log"; : > "$LOG12B"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say FH_STUB_ARGV_LOG="$LOG12B" \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" ) >/dev/null 2>&1
grep -q "Read,Grep,Glob,Bash" "$LOG12B" \
  && no "L12b control — Bash present WITHOUT --extra-tools (observe mode is not read-only)" \
  || ok "L12b control — no Bash without --extra-tools"

# ── L13 stdin 격리 (2026-08-31) — 🟥 이 레인이 없으면 근인이 조용히 재발한다 ────────────
#    실측: `claude -p` 는 **stdin 이 TTY 가 아니면 그것을 읽어 프롬프트 뒤에 붙인다.**
#    호출부(`context_continuity_score.sh`)가 `while … done < "$QSET"` 루프 «안»에서 이 러너를
#    부르므로, 러너도 claude 도 **stdin = 채점용 qset(정답 열 포함)** 을 상속했다.
#    ⇒ 회차 1~3 과 probe1~4 의 모든 팔이 정답키 전체를 받았다. ARM 도 CTRL 도.
#    🟥 경로 deny·코퍼스 마스킹은 **원리적으로 못 막는다** — 도구 읽기가 아니라 프롬프트 조립이다.
#    🟥 그리고 «팔에게 물어보면» 안 잡힌다: 팔은 그것을 「프롬프트 인젝션」이라 부르며 정직하게
#    거부하면서 **거부문 안에서 정답을 말하고**, 채점기는 그 문장을 토큰으로 센다.
#    라이브 확인은 이미 났다(같은 문항 q2, 변수는 stdin 하나: 수리 전 3/3 → 수리 후 0/3).
#    여기서는 **모델 없이 결함 자체**를 잰다 — 스텁이 자기가 받은 stdin 을 적는다.
BAIT="ZZSTDINBAIT$(printf '%s' 7731)"
OUTDIR="$WORKROOT/o13"; SLOG="$WORKROOT/stdin13.log"; : > "$SLOG"
printf 'q1\tpositive\t질문\t%s\n' "$BAIT" > "$WORKROOT/bait.tsv"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=stdin FH_STUB_STDIN_LOG="$SLOG"    bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" < "$WORKROOT/bait.tsv" ) >/dev/null 2>&1
# 🟥 컨트롤 먼저 — 스텁이 실제로 돌았나. 안 돌았으면 「미끼 0」은 통과가 아니라 계기 사망이다
#    ([[feedback_absence_measurement_needs_control]] · 부재를 0 으로 렌더하지 않는다).
if [ ! -s "$OUTDIR/a_r1.txt" ]; then
  no "L13-CTRL 팔이 산출을 냈나 (미끼 0 이 계기 사망이 아님을 보증)"
else
  ok "L13-CTRL 팔이 산출을 냈다 ($(wc -c < "$OUTDIR/a_r1.txt" | tr -d ' ')B)"
fi
grep -qF "$BAIT" "$SLOG" 2>/dev/null \
  && no "L13 stdin 이 claude 까지 샜다 — 미끼가 프롬프트 채널에 도달했다" \
  || ok "L13 stdin 격리 — 미끼가 claude 에 도달하지 않는다"
# 🟥 known-positive: 같은 스텁·같은 미끼가 «막지 않으면» 실제로 잡히는가.
#    이게 없으면 위 레인은 「미끼가 원래 안 새는 것」과 구분되지 않는다
#    ([[feedback_control_presence_is_not_discrimination]]).
SLOG2="$WORKROOT/stdin13b.log"; : > "$SLOG2"
( cd "$SRC" && PATH="$STUBBIN:$PATH" FH_STUB_MODE=stdin FH_STUB_STDIN_LOG="$SLOG2" \
   claude -p p < "$WORKROOT/bait.tsv" ) >/dev/null 2>&1
grep -qF "$BAIT" "$SLOG2" 2>/dev/null \
  && ok "L13b known-positive — 차단 없이 부르면 미끼가 실제로 도달한다 (레인이 판별한다)" \
  || no "L13b known-positive 실패 — 스텁이 stdin 을 못 읽는다. L13 의 초록은 무의미하다"

# ── L24 🟥 «팔 눈가림» 자산이 클론에서 실제로 사라지나 ─────────────────────────────
#    얼린 정답지가 tracked 가 되면서 모든 팔의 클론에 들어갔다(실측: negative 명사구 히트 6~7).
#    deny 가 아니라 «제거»인 이유 — 없는 파일은 어떤 도구로도 못 읽는다.
if [ -x "$ROOT/scripts/round/arm_blind_probe.sh" ]; then
  bash "$ROOT/scripts/round/arm_blind_probe.sh" >/dev/null 2>&1 \
    && ok "L24 팔 눈가림 자산이 클론에서 제거된다 (히트 >0 → 0)" \
    || no "L24 눈가림 실패 — 팔이 정답지를 읽을 수 있다"
else no "L24 프로브 없음 — 검사 못 함(스킵 아님)"; fi

# ── L25 ⓒ 날짜 오염 통제 필드 (six_axis_review_2026-09-04 강화 #3) — 존재만 본다, 값은 안 본다.
#    이 러너가 판정을 안 낸다는 것이 헤더의 약속이라, 레인도 «필드가 있나»만 잰다.
OUTDIR="$WORKROOT/o25"
( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
   bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" ) >/dev/null 2>&1
META="$OUTDIR/a_r1.meta.tsv"
if [ -f "$META" ]; then
  grep -q '^corpus_head_date	' "$META" && ok "L25a corpus_head_date field recorded" \
    || no "L25a corpus_head_date field missing"
  grep -q '^sim_model	' "$META" && ok "L25b sim_model field recorded" \
    || no "L25b sim_model field missing"
  grep -q '^sim_model_cutoff	' "$META" && ok "L25c sim_model_cutoff field recorded" \
    || no "L25c sim_model_cutoff field missing"
else
  no "L25 meta.tsv not written at all ($META)"
fi

# ── L26 timeout(1) resolution (2026-09-05) — the launchd-PATH incident this exists for ──────────
#    WHY: launchd's PATH ($HOME/.local/bin:/usr/local/bin:/usr/bin:/bin, per this repo's own plist
#    templates prior to this patch) has neither `timeout` nor `gtimeout` on it — both live under
#    Homebrew's prefix. The first real launchd live-eval run (2026-09-05 02:30) hit exactly this:
#    every rep of every arm died at `timeout: command not found` and the run scored 12/12
#    FAILED-TO-RUN with no clue why. This lane strips whichever CURRENT PATH dir(s) actually hold
#    `timeout`/`gtimeout` — computed, not hardcoded to /opt/homebrew/bin, so the same lane works on
#    Intel or a Linux box — and proves two things a prose comment cannot: the bash-native fallback
#    actually answers (not just "doesn't crash"), and it actually enforces the deadline rather than
#    silently never firing.
_strip_timeout_dirs() {  # prints $PATH with every dir holding an executable timeout/gtimeout removed
  local IFS=':' d out=""
  for d in $PATH; do
    [ -x "$d/timeout" ] && continue
    [ -x "$d/gtimeout" ] && continue
    out="${out:+$out:}$d"
  done
  printf '%s' "$out"
}
NOTIMEOUT_PATH="$(_strip_timeout_dirs)"

echo ""
echo "── L26 timeout(1) resolution ───────────────────────────────────────"

# Fixture-potency check FIRST — a stripped PATH that still resolves timeout/gtimeout proves
# nothing ([[feedback_fixture_must_use_the_breaking_spelling]]), and a strip that ALSO removed
# bash/git would confound every assertion below with an unrelated clone failure. Both are named
# distinctly rather than let a downstream lane fail for the wrong reason. Per this file's own
# convention (see L24's "검사 못 함(스킵 아님)"), an unusable fixture on this machine is scored
# as a failure, not silently skipped — it is loud precisely because CI does not gate this file
# (verified: no .github/workflows/*.yml references it), so a quiet skip would never be noticed.
if PATH="$NOTIMEOUT_PATH" command -v timeout >/dev/null 2>&1 || PATH="$NOTIMEOUT_PATH" command -v gtimeout >/dev/null 2>&1; then
  no "L26-FIXTURE stripped PATH still resolves timeout/gtimeout — cannot run L26 on this machine"
elif ! PATH="$NOTIMEOUT_PATH" command -v bash >/dev/null 2>&1 || ! PATH="$NOTIMEOUT_PATH" command -v git >/dev/null 2>&1; then
  no "L26-FIXTURE stripping timeout/gtimeout also removed bash or git — cannot run L26 on this machine"
else
  ok "L26-FIXTURE stripped PATH lacks timeout+gtimeout; bash/git still resolve"

  # L26a — no timeout/gtimeout at all: the runner must still answer (via the bash fallback) and
  # must NAME which control it used in its own header, rather than leaving that to be inferred.
  OUTDIR="$WORKROOT/o26a"
  OUT=$( cd "$SRC" && PATH="$STUBBIN:$NOTIMEOUT_PATH" HOME="$FAKEHOME" FH_STUB_MODE=say \
     bash "$SUT" --arm a --reps 1 --prompt p --out "$OUTDIR" 2>&1 )
  if printf '%s' "$OUT" | grep -q "timeout_tool=bash-fallback" && printf '%s' "$OUT" | grep -q "captured"; then
    ok "L26a no timeout/gtimeout on PATH -> bash-fallback answers and names itself in the header"
  else
    no "L26a bash-fallback did not fire/name itself: $(printf '%s' "$OUT" | grep -E 'timeout_tool|captured|UNMEASURED|EMPTY' | head -3 | tr '\n' ';')"
  fi

  # L26b — the fallback must actually ENFORCE the deadline, not just silently never fire. A stub
  # that would otherwise run 30s under --timeout 2 must come back UNMEASURED well under 30s.
  OUTDIR="$WORKROOT/o26b"
  _t0=$(date +%s)
  OUT=$( cd "$SRC" && PATH="$STUBBIN:$NOTIMEOUT_PATH" HOME="$FAKEHOME" FH_STUB_MODE=hang \
     bash "$SUT" --arm a --reps 1 --prompt p --timeout 2 --out "$OUTDIR" 2>&1 )
  _t1=$(date +%s); _elapsed=$(( _t1 - _t0 ))
  if printf '%s' "$OUT" | grep -q "UNMEASURED" && [ "$_elapsed" -le 10 ]; then
    ok "L26b bash-fallback enforces the deadline (UNMEASURED in ${_elapsed}s of a 30s hang, timeout=2s)"
  else
    no "L26b fallback did not enforce the timeout (elapsed=${_elapsed}s): $(printf '%s' "$OUT" | grep -E 'UNMEASURED|captured' | head -1)"
  fi

  # L26c control — SAME hang stub, DEFAULT (unstripped) PATH: real timeout/gtimeout must still be
  # preferred over the fallback (header says gnu/gtimeout, not bash-fallback), AND must enforce
  # the same deadline. Without this, L26a/L26b could be passing because the fallback is used
  # unconditionally, not because resolution correctly prefers the real tool when it is present
  # ([[feedback_control_presence_is_not_discrimination]]).
  OUTDIR="$WORKROOT/o26c"
  OUT=$( cd "$SRC" && PATH="$STUBBIN:$PATH" HOME="$FAKEHOME" FH_STUB_MODE=hang \
     bash "$SUT" --arm a --reps 1 --prompt p --timeout 2 --out "$OUTDIR" 2>&1 )
  case "$OUT" in
    *"timeout_tool=bash-fallback"*)
      no "L26c control — default PATH used bash-fallback instead of a real timeout/gtimeout" ;;
    *"timeout_tool=gnu"*|*"timeout_tool=gtimeout"*)
      printf '%s' "$OUT" | grep -q "UNMEASURED" \
        && ok "L26c control — default PATH prefers the real timeout tool and still enforces the deadline" \
        || no "L26c control — real timeout tool resolved but did not enforce the deadline"
      ;;
    *) no "L26c control — no timeout_tool= line in header at all: $(printf '%s' "$OUT" | grep timeout_tool)" ;;
  esac
fi

echo "sim_isolated_run lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
