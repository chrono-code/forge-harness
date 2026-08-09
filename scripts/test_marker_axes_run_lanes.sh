#!/usr/bin/env bash
# test_marker_axes_run_lanes.sh — regression fixtures for pre-commit validate_marker_axes_run.
#
# 대상: CLAUDE.md §3층 자기 대조가 요구하는 마커 3줄 중 **기계로 볼 수 있는 두 줄** —
#   axes-run:  네 축(ⓐ다른계열 ⓑ첫실사용 ⓒ기록그라운딩 ⓓ되돌림) 각각의 실행 여부
#   controls:  각 축 컨트롤의 **생사**
#
# 🟥 이 스위트가 증명하지 않는 것 (계약을 픽스처로 못박는다):
#   「a=codex」 라고 적혀 있을 때 codex 가 **실제로 돌았는지**는 검사하지 않는다.
#   마커의 계약은 form + non-vacuity + auditability 이지 provenance 가 아니다 —
#   그건 cross-family 가 마커를 읽는 일이고, 훅의 일이 아니다. 아래 lane `p3` 이
#   그 사실을 **의도된 통과**로 고정한다(거짓말은 통과한다).
#
# 날짜 유예: 파일명 날짜 < AXES_RUN_GRACE_DATE 이면 요구하지 않는다. 소급 강제는
# 진행 중인 브랜치를 전부 막고, 그 과차단이 `--no-verify` 를 습관화시켜 같은 훅 안의
# Destructive-Op 게이트까지 무장해제한다.
#
# Usage: bash scripts/test_marker_axes_run_lanes.sh   Exit: 0 = all fixtures behave; 1 = regression.

set -uo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# 훅에서 함수 + 유예 상수를 그대로 뽑아 쓴다. 복제하면 드리프트하므로 **소스가 하나**다.
{
  grep -E '^AXES_RUN_GRACE_DATE=' "$HOOK"
  sed -n '/^validate_marker_axes_run()/,/^}/p' "$HOOK"
} > "$T/fn.sh"

# 계기 자체가 살아있는지 먼저 본다 — 추출이 실패하면 모든 레인이 «통과»로 초록이 된다.
if ! grep -q 'validate_marker_axes_run()' "$T/fn.sh" || ! grep -q '^AXES_RUN_GRACE_DATE=' "$T/fn.sh"; then
  echo "❌ 계기 사망: 훅에서 함수/상수 추출 실패 — 레인 결과를 신뢰하지 마라"
  exit 1
fi

run() { bash -c "source '$T/fn.sh'; validate_marker_axes_run '$1'" >/dev/null 2>&1; }

FAIL=0
check() { # $1=fixture $2=expected(PASS|BLOCK) $3=label
  if run "$1"; then got=PASS; else got=BLOCK; fi
  if [ "$got" = "$2" ]; then echo "✅ $3 → $got"; else echo "❌ $3 → $got (expected $2)"; FAIL=1; fi
}

D_NEW=2026-08-11      # 유예일 이후
D_OLD=2026-08-01      # 유예일 이전
mk() { printf '%s\n' "$2" > "$T/.axes_23_passed_lane_$1.marker"; echo "$T/.axes_23_passed_lane_$1.marker"; }

# ── 의도된 형태 ──────────────────────────────────────────────────────────────
P1=$(mk "$D_NEW" 'axes-run: a=codex(4건) b=CI배선 c=none d=되돌림(국소성)
controls: alive — known-positive 3히트 · known-negative 0')
check "$P1" PASS "네 축 전부 + 컨트롤 생사 → 통과"

P2=$(mk "$D_NEW" 'axes-run: a=none b=none c=none d=none
controls: n/a — 이번 델타에 측정이 없다 (문구 수정)')
check "$P2" PASS "전 축 none + controls n/a → 통과 (안 돌렸다고 **적는 것**은 위반이 아니다)"

# ★ 계약 고정: 거짓말은 통과한다. 이 훅은 침묵을 잡지 오답을 못 잡는다.
P3=$(mk "$D_NEW" 'axes-run: a=codex b=CI c=격리감사 d=되돌림
controls: alive — 전부 살아있었다')
check "$P3" PASS "★내용이 거짓이어도 통과 — provenance 는 훅의 계약이 아니다(의도된 통과)"

# ── 침묵 차단 ────────────────────────────────────────────────────────────────
B1=$(mk "$D_NEW" 'axis2-evidence: PASS no-S')
check "$B1" BLOCK "axes-run 자체가 없음 → 차단"

B2=$(mk "$D_NEW" 'axes-run: a=codex b=CI배선 d=되돌림
controls: alive — ok')
check "$B2" BLOCK "★c 가 빠짐 → 차단 (빠뜨리는 것 ≠ none 이라고 적는 것)"

B3=$(mk "$D_NEW" 'axes-run: a=codex(4) b=CI c=none d=되돌림')
check "$B3" BLOCK "controls 줄이 없음 → 차단"

B4=$(mk "$D_NEW" 'axes-run: a=codex(4) b=CI c=none d=되돌림
controls: 컨트롤 붙였다')
check "$B4" BLOCK "controls 에 생사 토큰 없음(무실질) → 차단"

B5=$(mk "$D_NEW" 'axes-run: a= b=CI c=none d=되돌림
controls: alive — ok')
check "$B5" BLOCK "축 키는 있는데 값이 빈 문자열 → 차단"

# ── 날짜 유예 (컨트롤) ───────────────────────────────────────────────────────
G1=$(mk "$D_OLD" 'axis2-evidence: PASS no-S')
check "$G1" PASS "★유예일 **이전** 마커는 요구하지 않는다 — 소급 차단이 우회를 훈련시킨다"

G2="$T/marker_without_date.marker"; printf 'axis2-evidence: PASS\n' > "$G2"
check "$G2" PASS "파일명에 날짜가 없으면 판정 근거가 없다 → 요구하지 않는다"

# ── 유예 경계 자체를 고정 (상수를 바꾸면 이 레인이 빨개진다) ─────────────────
B6=$(mk 2026-08-10 'axis2-evidence: PASS')
check "$B6" BLOCK "★유예일 **당일**은 요구한다 (경계가 < 이지 <= 가 아님을 고정)"

# ── ★ 배선 판별자 — 위 레인들은 **함수만** 본다 ──────────────────────────────
# 실측 2026-08-09: 훅의 호출부에서 `&& validate_marker_axes_run "$MARKER"` 를 떼고
# 위 11 레인을 돌렸더니 **전부 초록**이었다. 함수는 멀쩡하고 아무도 안 부르는 상태를
# 레인이 구조적으로 못 본다 — 「장식 앵커」의 6번 얼굴(호출부 우회)이다.
# 그래서 **호출부 자체를 앵커한다.** 이 검사가 없으면 배선 제거가 무증상으로 지나간다.
if grep -qF 'validate_marker_axes_run "$MARKER"' "$HOOK"; then
  echo "✅ ★배선: 훅 호출부에 validate_marker_axes_run 이 실제로 걸려 있다"
else
  echo "❌ ★배선 소실: 함수는 있는데 **아무도 안 부른다** — 위 레인은 이걸 못 잡는다"
  echo "   기대: pre-commit 의 마커 검증 분기에 && validate_marker_axes_run \"\$MARKER\""
  FAIL=1
fi
# 컨트롤: 존재하지 않는 호출부를 같은 방식으로 찾으면 실패해야 한다(계기 생존).
if grep -qF 'validate_marker_zzz_nonexistent "$MARKER"' "$HOOK"; then
  echo "❌ 계기 고장: 없는 호출부를 있다고 한다"
  FAIL=1
else
  echo "✅ 컨트롤: 없는 호출부는 없다고 판정한다(계기 생존)"
fi

echo
[ "$FAIL" -eq 0 ] && echo "── all marker-axes-run lane fixtures behave ──"
exit "$FAIL"
