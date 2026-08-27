#!/usr/bin/env bash
# test_card_drift_probe.sh — session_close_check.sh ⑤-b 카드-드리프트 프로브의 known-pair 픽스처.
#
# WHY: 프로브 자체가 계기다 — CLAUDE.md §Instrument Calibration 이 요구하는 known-pair
# (양성 1 + 음성 1)를 통과하지 못하는 프로브는 배선하면 안 된다(다음 오판정의 원천이 된다).
# 이 파일이 그 캘리브레이션의 회귀 앵커: 프로브 정규식/토큰추출을 고칠 때마다 재실행.
#
# 픽스처 3종:
#   P  (known-positive): 카드가 🔴 "foo-digest 미가동 — 산출물 0" 주장 + 실물
#                        tracks/_meta/foo_digest_2026_07_22.md 존재 → ⑤-b 경고가 떠야 한다
#   N1 (known-negative): 카드가 부재 주장하는 bar-report 는 진짜 없음 → 경고 0
#   N2 (과발화 가드):    같은 실물이 있어도 부재-주장이 아닌 🟢 줄 → 경고 0
#                        (건강한 날 뜨는 경고는 무시를 학습시킨다 — 과발화도 결함)
#
# Exit 0 = 3/3 캘리브레이션 통과 · exit 1 = 프로브 계기 불량 (배선 금지)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 🟥 ENVIRONMENT ISOLATION (2026-08-27). `CLAUDE.local.md` INSTRUCTS this operator to export
# FH_COMPANION_STORE, so the suite inherited a REAL companion store and ⑤-C compared each FIXTURE
# card against the operator's actual prior card — reporting a carry-over loss that belongs to
# neither. Measured A/B on this file: exported → rc 1 with 6 exit-code lanes red · unset → rc 0.
# The verdict CONTENT was right every time (every `_line` assertion passed); only the exit code
# moved, which is what made it read like an over-blocking script rather than an ambient leak.
# 🟥 THIS IS THE SECOND FILE WITH THIS LEAK. The sibling test_session_close_lanes.sh was fixed
# earlier the same day and this one was not — a half-fix propagation boundary created by the same
# author who had just named that class. Fixed together now; the sweep that found it is
#   grep -l session_close_check scripts/test_*.sh   → check each for an FH_COMPANION_STORE guard.
# Lanes that genuinely exercise ⑤-C set their own fixture store ON the invocation and still win.
# 🟥 CLASS, NOT INSTANCE. The first draft of this guard unset FH_COMPANION_STORE alone — the one
# variable that had actually bitten. That is the same shape as the half-fix that put this guard in
# only ONE of two sibling lane files hours earlier. Every operator-settable override the subject
# reads is the same window, so all of them are closed here rather than one at a time:
#   FH_COMPANION_STORE  ⑤-C reads a REAL prior card and reports a carry-over loss on a fixture
#   FH_SESSION_CLOSE    flips advisory into blocking — every `expect exit 0` lane would go red
#   FH_CARRYOVER_OK     SKIPs ⑤-C — a lane asserting ⑤-C FIRES would go green for the wrong reason
#                       (note the direction: this one fails OPEN, which is the worse half)
#   FH_PEER_SCAN_FORCE  forces the ①-c peer scan on regardless of session shape
#   FH_PEER_SOCK_DIR / FH_REPO_ID   repoint peer discovery at the ambient machine
# CLAUDE_CODE_AGENT / CLAUDE_CODE_CHILD_SESSION are deliberately NOT in this list: the subject uses
# them to detect session shape and the lanes that care unset them per-case on purpose (see the
# subject's own "NEGATIVE ARM UNVERIFIED" note). Blanket-clearing them here would silently change
# which branch those lanes exercise.
unset FH_COMPANION_STORE FH_SESSION_CLOSE FH_CARRYOVER_OK FH_PEER_SCAN_FORCE FH_PEER_SOCK_DIR FH_REPO_ID
export FH_COMPANION_STORE=""
CHECK="$SCRIPT_DIR/session_close_check.sh"
FAILED=0

run_fixture() {  # $1=name  $2=card-content  $3=make-artifact(0/1)  $4=expect-warn(0/1)
  local name="$1" card="$2" mkart="$3" expect="$4"
  local T; T=$(mktemp -d)
  mkdir -p "$T/tracks/_meta/logs"
  printf '%s\n' "$card" > "$T/tracks/_meta/reference_next_session_starter.md"
  [ "$mkart" = 1 ] && touch "$T/tracks/_meta/foo_digest_2026_07_22.md"
  # git 없는 디렉토리라도 다른 스텝은 조용히 지나간다(모두 2>/dev/null 가드)
  local out; out=$(bash "$CHECK" "$T" 2>/dev/null)
  local warned=0
  printf '%s\n' "$out" | grep -q "⑤-b card-drift" && warned=1
  # RUN EVERY FIXTURE TWICE — ambient locale AND LC_ALL=C. Added 2026-07-31 after the probe passed
  # 3/3 here for weeks while returning warn=0 for EVERY lane on the ubuntu runner. Cause: the
  # absence regex held a Hangul RANGE `[^가-힣]`, which GNU grep in the C locale rejects with
  # "Invalid collation character" — it exits 2 and prints nothing, which downstream is
  # indistinguishable from "no match", so the probe reported the card clean on every input.
  # BSD grep accepts the range, so no amount of running this suite on macOS could ever have caught
  # it. MEASURED LIMIT, stated because the first version of this comment overclaimed: LC_ALL=C on
  # macOS is NOT a stand-in for GNU grep — reverting the Hangul range with this dual-run in place
  # still passed here. So this leg detects the class only where GNU grep runs, i.e. in CI. It is
  # kept because a locale-divergent verdict is a defect wherever it is observed, and it costs one
  # extra invocation; the platform-independent detector is the source lint below.
  local out_c; out_c=$(LC_ALL=C LANG=C bash "$CHECK" "$T" 2>/dev/null)
  local warned_c=0
  printf '%s\n' "$out_c" | grep -q "⑤-b card-drift" && warned_c=1
  if [ "$warned" != "$warned_c" ]; then
    echo "❌ $name — LOCALE-DIVERGENT: ambient warn=$warned but LC_ALL=C warn=$warned_c"
    echo "     텍스트 계기가 로케일에 따라 다른 판정을 낸다 — 어느 쪽이 맞든 캘리브레이션 실패다."
    rm -rf "$T"; FAILED=1; return
  fi
  rm -rf "$T"
  if [ "$warned" = "$expect" ]; then
    echo "✅ $name (warn=$warned, expected=$expect)"
  else
    echo "❌ $name — warn=$warned, expected=$expect"
    FAILED=1
  fi
}

run_fixture "P  known-positive: 부재주장+실물존재 → 경고" \
  "- 🔴 **foo-digest 잡 미가동(07-22)** — 로그도 산출물도 0(launchd 확인 필요)." 1 1

run_fixture "N1 known-negative: 부재주장+진짜부재 → 무경고" \
  "- 🔴 **bar-report 잡 미가동** — 산출물 0, 미착수." 0 0

run_fixture "N2 과발화가드: 실물존재+부재주장아님 → 무경고" \
  "- 🟢 **foo-digest 가동 중** — 오늘자 산출 확인." 1 0

run_fixture "N3 정정문맥가드: 부재주장 인용+오판정 명시 → 무경고" \
  "- 🔴 **foo-digest 산출 누락 수리 미완**. 기존 카드의 \"미가동\"은 오판정이었음." 1 0

run_fixture "N4 날짜토큰가드: 부재주장이나 토큰이 날짜뿐 → 무경고" \
  "- 🔴 잡 미가동 2026-07-22 산출물 0" 1 0

# challenger A-1 반례 (2026-07-23): 살아있는 주장 + 무관한 debunk 어휘 = 경고가 떠야 한다.
# debunk-단독 가드는 이 두 줄을 무음 삼켰다(FN) — 인용부 조건이 판별자.
run_fixture "P2 살아있는 주장+무관한 '정정 필요' → 경고 (A-1 FN 앵커)" \
  "- 🔴 **foo-digest 미가동 지속** — 산출물 0. 지난 카드의 실행횟수 수치는 정정 필요." 1 1

run_fixture "P3 살아있는 주장+무관한 '거짓' → 경고 (A-1 FN 앵커)" \
  "- 🔴 **foo-digest 미가동** — 산출물 0, 로그는 거짓 성공만 찍힘" 1 1

run_fixture "N5 위치-언급 디렉토리 → 무경고 (A-2 FP 앵커)" \
  "- 🟡 bar-report 미생성 — tracks/_meta/ 산출물 0" 0 0

run_fixture "N6 카드 자신 매치 제외 (A-3 FP 앵커)" \
  "- 🔴 next_session_starter 갱신 부재 — 0건" 0 0

run_fixture "P4 영어 부재주장 (A-4 앵커)" \
  "- 🔴 **foo-digest job not running** — zero outputs" 1 1

run_fixture "N7 인용된 부재키워드+정정 → 무경고 (실카드 07-22 클래스)" \
  "- 🔴 foo-digest 산출 누락. 기존 카드의 \"미가동\" 주장은 오판정이었음" 1 0


# ── LOCALE-RANGE LINT (platform-independent, added 2026-07-31) ─────────────────────────
# The behavioural dual-run above cannot fire on BSD grep, so the class needs a detector that does
# not depend on which grep is installed. This one reads the SOURCE: a bracket expression containing
# a non-ASCII RANGE (`[^가-힣]`, `[ㄱ-ㅎ]`, …) is collation-dependent by construction and will be
# rejected outright by GNU grep in the C locale — "Invalid collation character", exit 2, no output,
# which downstream reads as "no match" and therefore as clean.
# Alternation of non-ASCII literals (`(🔴|🟡)`, `미가동|부재`) is NOT flagged: it carries no
# collation, and the runner proved it works (the emoji line-selection stage passed there while the
# range stage errored). Flagging it would push an author to mangle working code.
echo "-- locale-range lint: 비ASCII 문자 범위를 쓰는 정규식 (collation 의존) --"
LINT_OUT=$(python3 - "$SCRIPT_DIR" <<'LINTPY'
import re, sys, glob, os
root = sys.argv[1]
# a bracket expression containing  <non-ascii> - <non-ascii>
rng = re.compile(r'\[[^]\n]*[^\x00-\x7F]-[^\x00-\x7F][^]\n]*\]')
hits = []
for f in sorted(glob.glob(os.path.join(root, '*.sh'))):
    for i, line in enumerate(open(f, encoding='utf-8', errors='replace'), 1):
        if line.lstrip().startswith('#'):
            continue
        m = rng.search(line)
        if m:
            hits.append(f"{os.path.basename(f)}:{i}: {m.group(0)}")
print('\n'.join(hits))
LINTPY
)
if [ -n "$LINT_OUT" ]; then
  echo "❌ 비ASCII 범위 발견 — GNU grep(C 로케일)에서 exit 2 로 죽고 결과가 '무매치'로 읽힌다:"
  printf '%s\n' "$LINT_OUT" | sed 's/^/     /'
  FAILED=1
else
  echo "✅ locale-range lint: 비ASCII 문자 범위 없음"
fi


echo "── card-drift probe calibration: $([ "$FAILED" -eq 0 ] && echo "PASS (전 픽스처) — 배선 가능" || echo "FAIL — 계기 불량, 배선 금지") ──"
exit "$FAILED"
