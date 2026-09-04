#!/usr/bin/env bash
# revert_probe.sh — general-purpose ⓕ revert-and-observe probe (rung 강화 #2, six_axis_review_2026-09-04).
#
# WHY THIS EXISTS. `되돌림`(revert-and-observe) has been done by hand 15+ times in this repo's own
# history (see 6축 실측: ⓕ none 비율 57.4%, «정확히 4레인 적색» 급 실물은 매번 손으로 짠 1회성
# 스크립트였다). Hand-rolled revert probes are the exact shape §Mechanize-at-repetition names —
# N≥3 recurrence on the SAME operation (swap a file to an older version, rerun a suite, read which
# lines changed color) is a mechanization trigger, not a one-off. This is that mechanization.
#
# 🟥 FRONTIER WARNING — read before citing this tool's PASS as "the suite has detection power".
#   A single revert of a single file is ONE mutant. Mutation-testing research (arXiv 2607.22880,
#   and the companion Meta engineering write-up cited alongside it in
#   frontier_verification_map_2026-09-04.md §ⓕ) found that coverage/mutation SCORE loses its
#   correlation with real fault-detection effectiveness once suite size is controlled for — a
#   single kill is evidence the ANCHOR under test is load-bearing for THIS ONE reverted file,
#   never a general claim that the suite "has good mutation coverage" or "catches regressions".
#   Run this against every file you actually care about; do not average or extrapolate from one.
#
# WHAT IT DOES
#   1. Runs the lane suite AS-IS against the file's CURRENT (working-tree) content — the "수리 후"
#      run.
#   2. Swaps ONLY the target file to its content at --baseline (default HEAD), backing up the
#      current content first.
#   3. Reruns the same lane suite against that swapped-in baseline content — the "되돌린" run.
#   4. Restores the target file to its exact pre-probe content — ALWAYS, even if either suite run
#      crashes, hangs past its timeout, or this script itself errors. Restore is attempted from an
#      EXIT trap (safety net) in addition to the normal-path restore, so a `kill`-free abnormal
#      exit still restores. Physical restore, never `git checkout <ref> -- <path>` — that stages
#      the revert into the index ([[feedback_git_checkout_path_stages_the_revert]]); this tool
#      writes bytes to the file only, with `git show <ref>:<path>` (never `git checkout`), and
#      never touches the index.
#   5. Diffs the two runs' ✅/❌ label lines (this repo's universal `ok()`/`no()` convention —
#      every test_*.sh / *_lanes.sh in scripts/ prints `  ✅ <label>` / `  ❌ <label>`) and reports
#      EXACTLY which labels flipped from ✅ (current) to ❌ (baseline) — i.e. which lane actually
#      went red when the fix was undone.
#
# WHAT IT ASSUMES (named, not hidden): the lane suite's ✅/❌ label text is STABLE across the two
#   runs for a given lane (the suite script itself does not change between the two invocations —
#   only the target file's content does). A suite whose pass/fail label text is dynamically built
#   from data that changes with the target file (e.g. embeds a byte count in the label) will show
#   as "label only in one run" rather than a flip — reported honestly as UNMATCHED, not silently
#   dropped, and not counted toward the flip total.
#
# USAGE
#   bash scripts/revert_probe.sh <target-file> <lane-suite-script> [--baseline <ref>] [--timeout <sec>]
#   bash scripts/revert_probe.sh scripts/foo.sh scripts/test_foo_lanes.sh
#   bash scripts/revert_probe.sh scripts/foo.sh scripts/test_foo_lanes.sh --baseline HEAD~1
#
# EXIT CODES (fail-closed, per CLAUDE.md §Irreversibility Surface-Class Degrade Invariant — this
#   is a REVERSIBLE, read-then-restore surface, so the floor here is "never mis-score", not
#   "never run"):
#   0  = exactly ≥1 lane flipped ✅→❌ when reverted (anchor is alive — it caught the mutant)
#   1  = 0 lanes flipped (anchor is DECORATIVE for this file — nothing depended on the fix)
#   2  = usage error (bad args, target/suite/ref not found)
#   10 = the probe itself is unreliable for this run — either suite run produced ZERO parseable
#        ✅/❌ lines (harness error, not "0 lanes exist"), OR the restore step failed (the target
#        file may still hold BASELINE content — treated as the more severe failure and reported
#        loudly, never silently folded into a verdict)
#
# Usage in a lane test: see scripts/test_revert_probe_lanes.sh for the known-pair calibration
# (decorative anchor → 1, real anchor → 0, restore-guaranteed-on-suite-crash).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TARGET=""; SUITE=""; BASELINE="HEAD"; TIMEOUT="120"
_POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --baseline) BASELINE="${2:-HEAD}"; shift 2 ;;
    --timeout)  TIMEOUT="${2:-120}"; shift 2 ;;
    -*)         echo "FAIL: unknown flag: $1" >&2; exit 2 ;;
    *)          _POS+=("$1"); shift ;;
  esac
done
TARGET="${_POS[0]:-}"; SUITE="${_POS[1]:-}"

[ -n "$TARGET" ] || { echo "FAIL: usage: revert_probe.sh <target-file> <lane-suite-script> [--baseline <ref>]" >&2; exit 2; }
[ -n "$SUITE" ]  || { echo "FAIL: usage: revert_probe.sh <target-file> <lane-suite-script> [--baseline <ref>]" >&2; exit 2; }
[ -f "$TARGET" ] || { echo "FAIL: target file not found: $TARGET" >&2; exit 2; }
[ -f "$SUITE" ]  || { echo "FAIL: lane suite script not found: $SUITE" >&2; exit 2; }

# 🟥 physical path (`pwd -P`), not logical — macOS `/tmp` and `$TMPDIR` are symlinks into
# `/private/...`, and `git rev-parse --show-toplevel` always answers with the PHYSICAL path.
# A logical `pwd` here would make every fixture under a temp dir fail the prefix-strip below
# (same class of defect `sim_isolated_run.sh` already names for its own path isolation).
TARGET_DIR="$(cd "$(dirname "$TARGET")" && pwd -P)"
TARGET_ABS="$TARGET_DIR/$(basename "$TARGET")"
GIT_ROOT="$(cd "$TARGET_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$GIT_ROOT" ] || { echo "FAIL: target file is not inside a git repository: $TARGET" >&2; exit 2; }
case "$TARGET_ABS" in
  "$GIT_ROOT"/*) REL_PATH="${TARGET_ABS#"$GIT_ROOT"/}" ;;
  *) echo "FAIL: could not compute a repo-relative path for $TARGET" >&2; exit 2 ;;
esac

if ! git -C "$GIT_ROOT" cat-file -e "${BASELINE}:${REL_PATH}" 2>/dev/null; then
  echo "FAIL: $REL_PATH not found at baseline '$BASELINE' (bad ref, or the file did not exist there)" >&2
  exit 2
fi

echo "── revert_probe ────────────────────────────────────────────────────"
echo "target:   $REL_PATH"
echo "suite:    $SUITE"
echo "baseline: $BASELINE"
echo ""
echo "🟥 FRONTIER WARNING (arXiv 2607.22880): this run reverts EXACTLY ONE file — ONE mutant."
echo "   A ✅ verdict here means the anchor caught THIS mutant, not that the suite has general"
echo "   mutation-detection power. Coverage/mutation score decorrelates from real effectiveness"
echo "   once suite size is controlled for — do not average or extrapolate from a single run."
echo "되돌린 파일(뮤턴트) 수: 1 — $REL_PATH"
echo ""

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/revert_probe.XXXXXX")" || { echo "FAIL: mktemp -d failed" >&2; exit 10; }
BACKUP="$WORKDIR/backup"
RUN_A="$WORKDIR/run_current.txt"
RUN_B="$WORKDIR/run_baseline.txt"

cp -p "$TARGET_ABS" "$BACKUP" || { echo "FAIL: could not back up $TARGET_ABS — refusing to touch it" >&2; rm -rf "$WORKDIR"; exit 10; }

RESTORED=0
_restore() {
  [ "$RESTORED" = 1 ] && return 0
  if cp -p "$BACKUP" "$TARGET_ABS" 2>/dev/null; then
    RESTORED=1
  else
    echo "🟥🟥🟥 RESTORE FAILED — $TARGET_ABS may still hold BASELINE ($BASELINE) content." >&2
    echo "    Backup of the pre-probe content is kept at: $BACKUP" >&2
    echo "    Restore it by hand: cp \"$BACKUP\" \"$TARGET_ABS\"" >&2
  fi
}
# Safety net — fires on ANY exit path (normal, error, unbound-var under set -u), so a crash
# mid-probe still restores. The normal path below also calls _restore explicitly and checks its
# result directly, because a trap cannot hand its own success/failure back to the exit-code logic.
trap '_restore' EXIT

_run_suite() { # $1=output-file
  if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT" bash "$SUITE" > "$1" 2>&1
  else
    bash "$SUITE" > "$1" 2>&1
  fi
  return 0   # the suite's own exit code (pass/fail count) is not this function's concern
}

echo "── run 1/2: 현재(수리 후) 판 ──"
_run_suite "$RUN_A"
echo "  captured $(wc -l < "$RUN_A" | tr -d ' ') lines"

if ! git -C "$GIT_ROOT" show "${BASELINE}:${REL_PATH}" > "$TARGET_ABS.new" 2>"$WORKDIR/show.err"; then
  echo "FAIL: git show ${BASELINE}:${REL_PATH} failed:" >&2
  cat "$WORKDIR/show.err" >&2
  rm -f "$TARGET_ABS.new"
  # trap restores (no-op here, file was never swapped) and exits
  exit 10
fi
mv "$TARGET_ABS.new" "$TARGET_ABS"

echo "── run 2/2: 기준($BASELINE) 판 (파일만 되돌림, 인덱스는 안 건드림) ──"
_run_suite "$RUN_B"
echo "  captured $(wc -l < "$RUN_B" | tr -d ' ') lines"

_restore
trap - EXIT   # explicit restore already ran; the safety net has nothing left to do
if [ "$RESTORED" != 1 ]; then
  echo "" >&2
  echo "RESULT: RESTORE-FAILED — do not trust the file on disk, see backup path above" >&2
  rm -rf "$WORKDIR"
  exit 10
fi

# ── ✅/❌ 라벨 추출 — 심볼\tSPACE-트림한 설명 ────────────────────────────────────────────
_extract_labels() { # $1=source-file → writes "P|F<TAB>desc"
  grep -E '(✅|❌)' "$1" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      *✅*) sym=P; rest="${line#*✅}" ;;
      *)   sym=F; rest="${line#*❌}" ;;
    esac
    rest="$(printf '%s' "$rest" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$rest" ] && printf '%s\t%s\n' "$sym" "$rest"
  done
}

LABELS_A="$WORKDIR/labels_a.tsv"; LABELS_B="$WORKDIR/labels_b.tsv"
_extract_labels "$RUN_A" > "$LABELS_A"
_extract_labels "$RUN_B" > "$LABELS_B"
NA=$(wc -l < "$LABELS_A" | tr -d ' ')
NB=$(wc -l < "$LABELS_B" | tr -d ' ')

if [ "$NA" -eq 0 ] || [ "$NB" -eq 0 ]; then
  echo ""
  echo "🟥 HARNESS ERROR — one of the two runs produced ZERO ✅/❌ lines (current=$NA, baseline=$NB)."
  echo "   That is not \"0 lanes exist\" — it means this probe cannot see the suite's verdicts at"
  echo "   all for that run (crash, missing labels, wrong suite path). Read the raw output:"
  echo "     current:  $RUN_A"
  echo "     baseline: $RUN_B"
  rm -rf "$WORKDIR"
  exit 10
fi

# DESC\tSYM, sorted by DESC — LC_ALL=C throughout so non-ASCII label text (this repo's labels are
# routinely Korean) never collapses under a locale-dependent string-equality/sort
# ([[feedback_locale_string_equality_breaks_nonascii]]).
DESC_A="$WORKDIR/desc_a.tsv"; DESC_B="$WORKDIR/desc_b.tsv"
awk -F'\t' '{print $2"\t"$1}' "$LABELS_A" | LC_ALL=C sort -t"$(printf '\t')" -k1,1 -k2,2 > "$DESC_A"
awk -F'\t' '{print $2"\t"$1}' "$LABELS_B" | LC_ALL=C sort -t"$(printf '\t')" -k1,1 -k2,2 > "$DESC_B"

JOINED="$WORKDIR/joined.tsv"
LC_ALL=C join -t "$(printf '\t')" -j 1 -o 1.1,1.2,2.2 "$DESC_A" "$DESC_B" > "$JOINED" 2>/dev/null || : > "$JOINED"

FLIPPED_RED="$WORKDIR/flipped_red.txt"     # ✅(현재) → ❌(기준) — 앵커가 실제로 잡은 것
FLIPPED_GREEN="$WORKDIR/flipped_green.txt" # ❌(현재) → ✅(기준) — 이상 신호, 참고용
awk -F'\t' '$2=="P" && $3=="F" {print $1}' "$JOINED" > "$FLIPPED_RED"
awk -F'\t' '$2=="F" && $3=="P" {print $1}' "$JOINED" > "$FLIPPED_GREEN"
K=$(wc -l < "$FLIPPED_RED" | tr -d ' ')
J=$(wc -l < "$FLIPPED_GREEN" | tr -d ' ')

# 라벨 텍스트가 두 실행에서 안 겹치는 경우 — 조용히 버리지 않고 이름으로 남긴다(가정 위반 알림).
ONLY_A="$WORKDIR/only_a.txt"; ONLY_B="$WORKDIR/only_b.txt"
LC_ALL=C comm -23 <(cut -f1 "$DESC_A" | LC_ALL=C sort -u) <(cut -f1 "$DESC_B" | LC_ALL=C sort -u) > "$ONLY_A"
LC_ALL=C comm -13 <(cut -f1 "$DESC_A" | LC_ALL=C sort -u) <(cut -f1 "$DESC_B" | LC_ALL=C sort -u) > "$ONLY_B"
NUM_ONLY_A=$(wc -l < "$ONLY_A" | tr -d ' '); NUM_ONLY_B=$(wc -l < "$ONLY_B" | tr -d ' ')

echo ""
echo "── 결과 ──────────────────────────────────────────────────────────"
echo "현재(수리 후) 라벨: ${NA}줄  ·  기준($BASELINE) 라벨: ${NB}줄"
echo ""
echo "되돌린 레인 (✅→❌, 앵커가 실제로 잡은 것): ${K}개"
if [ "$K" -gt 0 ]; then sed 's/^/    ❌ /' "$FLIPPED_RED"; fi
echo ""
echo "(참고) 반대방향 (❌→✅, 이상 신호): ${J}개"
if [ "$J" -gt 0 ]; then sed 's/^/    ⚠️  /' "$FLIPPED_GREEN"; fi
if [ "$NUM_ONLY_A" -gt 0 ] || [ "$NUM_ONLY_B" -gt 0 ]; then
  echo ""
  echo "🟥 라벨 텍스트가 두 실행에서 완전히 겹치지 않는다 — 이 도구의 가정(라벨 텍스트가 안정적)"
  echo "   이 이 스위트에서는 안 맞을 수 있다. 아래는 매칭 대상에서 빠진 라벨(플립 집계에 미포함):"
  [ "$NUM_ONLY_A" -gt 0 ] && sed 's/^/    현재에만: /' "$ONLY_A"
  [ "$NUM_ONLY_B" -gt 0 ] && sed 's/^/    기준에만: /' "$ONLY_B"
fi

echo ""
if [ "$K" -ge 1 ]; then
  echo "판정: 앵커 살아있음 — 되돌리면 정확히 ${K}개 레인이 빨개진다"
  rm -rf "$WORKDIR"
  exit 0
else
  echo "판정: 앵커 장식 — 되돌려도 빨개지는 레인이 0개다"
  rm -rf "$WORKDIR"
  exit 1
fi
