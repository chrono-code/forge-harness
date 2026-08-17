#!/usr/bin/env bash
# test_marker_axes_run_lanes.sh — regression fixtures for pre-commit validate_marker_axes_run.
#
# 대상: CLAUDE.md §3층 자기 대조가 요구하는 마커 3줄 중 **기계로 볼 수 있는 두 줄** —
#   axes-run:  각 축의 실행 여부. 마커 날짜에 따라 **배열이 둘**이다:
#                >= 2026-08-17  ⓐ계열 · ⓑ입장 · ⓒ격리그라운딩 · ⓓ3자대면 · ⓔ첫실사용 · ⓕ되돌림
#                <  2026-08-17  a=계열 · b=첫실사용 · c=기록그라운딩 · d=되돌림  (옛 ASCII 4축)
#   controls:  각 축 컨트롤의 **생사**
#
# 🟥 이 헤더 자신이 2026-08-17 까지 그 충돌을 저지르고 있었다 — «네 축(ⓐ다른계열 ⓑ첫실사용
#    ⓒ기록그라운딩 ⓓ되돌림)» 이라고, **기호 표기로 옛 4축 의미**를 가르쳤다. 훅 본문이
#    「옛 b=첫실사용은 지금 ⓔ」 라고 경고하는 파일의 짝인데 정작 짝이 반대를 가르쳤고,
#    같은 세션이 이 파일을 11→25레인으로 늘리면서 **헤더는 안 봤다**. 잡은 것은 pmh-dev
#    입장리뷰(tier2)이고, 이 파일은 전파 자산이라 그 오류가 하류로 배송되던 중이었다.
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
  grep -E '^SIX_AXES_GRACE_DATE=' "$HOOK"
  sed -n '/^validate_marker_axes_run()/,/^}/p' "$HOOK"
} > "$T/fn.sh"

# 계기 자체가 살아있는지 먼저 본다 — 추출이 실패하면 모든 레인이 «통과»로 초록이 된다.
# 🟥 상수를 **각각** 확인한다. 하나로 뭉뚱그리면 새 상수가 추출에서 빠져도 초록이고,
#    그 경우 함수는 unbound 로 죽으며 모든 레인이 BLOCK 으로 몰려 «6축이 잘 막는다» 로
#    오독된다 — 계기 고장이 판정으로 렌더되는 형태다.
for _c in AXES_RUN_GRACE_DATE SIX_AXES_GRACE_DATE; do
  grep -q "^${_c}=" "$T/fn.sh" || { echo "❌ 계기 사망: 훅에서 ${_c} 추출 실패 — 레인 결과를 신뢰하지 마라"; exit 1; }
done
if ! grep -q 'validate_marker_axes_run()' "$T/fn.sh"; then
  echo "❌ 계기 사망: 훅에서 함수 추출 실패 — 레인 결과를 신뢰하지 마라"
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

# ── 6축 확장 (2026-08-17) ───────────────────────────────────────────────────
# 표기법이 배열을 선언한다: ASCII(a=…d=)=옛 4축 · 기호(ⓐ=…ⓕ=)=현 6축.
# 그래서 여기서 고정할 것이 셋이다 — ⓐ 새 날짜는 기호 여섯을 요구하나 ⓑ 옛 날짜는
# 건드리지 않나(소급 차단 금지) ⓒ **혼용이 막히나**(혼용을 허용하면 판별 가능성이
# 통째로 사라지고, 옛 b=/d= 는 새 배열에서 다른 축이라 무음 오독이 된다).
D_SIX=2026-08-18        # 6축 유예일 이후
SIX_OK='axes-run: ⓐ=codex(4건) ⓑ=→standpoint ⓒ=none ⓓ=none ⓔ=CI배선 ⓕ=되돌림(국소성)
controls: alive — known-positive 3히트 · known-negative 0
standpoint: not-applicable'

S1=$(mk "$D_SIX" "$SIX_OK")
check "$S1" PASS "6축: 기호 여섯 + 컨트롤 + standpoint → 통과"

S2=$(mk "$D_SIX" 'axes-run: ⓐ=codex ⓑ=→standpoint ⓒ=none ⓓ=none ⓕ=되돌림
controls: alive — ok
standpoint: tier1')
check "$S2" BLOCK "6축: ⓔ 가 빠짐 → 차단"

S3=$(mk "$D_SIX" 'axes-run: ⓐ=codex b=CI배선 ⓒ=none ⓓ=none ⓔ=실사용 ⓕ=되돌림
controls: alive — ok')
check "$S3" BLOCK "★6축: ASCII 키가 기호 키를 대신함 → 차단 (ⓑ 가 빠졌다는 뜻이므로 missing-key 가 잡는다)"

# ★ 오탐 컨트롤 — 전용 혼용 가드를 지었다가 **실측 오탐 때문에 지웠다**. 값이 자유 산문이라
# `f=0.9` 나 `a=제어 b=처리` 가 값 안에 정당하게 들어온다. 과차단은 `--no-verify` 를 훈련시키고
# 그건 같은 훅의 Destructive-Op 게이트까지 무장해제한다. 이 두 레인이 그 삭제를 고정한다 —
# 누가 «안전하게» 혼용 가드를 되살리면 여기서 빨개진다.
S3b=$(mk "$D_SIX" 'axes-run: ⓐ=codex ⓑ=→standpoint ⓒ=none ⓓ=none ⓔ=실사용 ⓕ=되돌림 f=0.9 상승
controls: alive — ok
standpoint: tier1')
check "$S3b" PASS "★오탐 컨트롤: 값 안의 f=0.9 는 혼용이 아니다 → 통과"

S3c=$(mk "$D_SIX" 'axes-run: ⓐ=codex ⓑ=→standpoint ⓒ=none ⓓ=none ⓔ=arm a=제어 b=처리 비교 ⓕ=되돌림
controls: alive — ok
standpoint: tier1')
check "$S3c" PASS "★오탐 컨트롤: 값 안의 a=제어 b=처리 는 혼용이 아니다 → 통과"

S4=$(mk "$D_SIX" 'axes-run: a=codex b=CI배선 c=none d=되돌림
controls: alive — ok')
check "$S4" BLOCK "★6축 유예 후 옛 ASCII 넷만 → 차단 (같은 글자가 다른 축을 가리키므로 그대로 두면 무음 재해석)"

S5=$(mk "$D_NEW" 'axes-run: a=codex b=CI배선 c=none d=되돌림
controls: alive — ok')
check "$S5" PASS "★컨트롤: 6축 유예 **이전** 마커는 옛 ASCII 넷으로 그대로 통과 (소급 차단 없음)"

S6=$(mk 2026-08-17 'axes-run: a=codex b=CI c=none d=되돌림
controls: alive — ok')
check "$S6" BLOCK "★6축 유예일 **당일**은 요구한다 (경계가 < 임을 고정 — 상수를 바꾸면 빨개진다)"

S7=$(mk "$D_SIX" 'axes-run: ⓐ=none ⓑ=→standpoint ⓒ=none ⓓ=none ⓔ=none ⓕ=none
controls: n/a — 이번 델타에 측정이 없다')
check "$S7" BLOCK "★ⓑ=→standpoint 인데 standpoint: 줄이 없음 → 차단 (죽은 포인터)"

# ★ fail-open 컨트롤 — 초판은 화살표(→)를 필수로 봤고, 자기 프로브가 `ⓑ=standpoint`(화살표 없음)이
# 검사를 통째로 비껴가는 것을 실측했다. 죽은 포인터가 표기 하나로 통과하면 그건 fail-open 이다.
S7b=$(mk "$D_SIX" 'axes-run: ⓐ=none ⓑ=standpoint ⓒ=none ⓓ=none ⓔ=none ⓕ=none
controls: n/a — 측정 없음')
check "$S7b" BLOCK "★화살표 없는 ⓑ=standpoint 도 차단 (표기 하나로 검사를 비껴가면 fail-open)"

S7c=$(mk "$D_SIX" 'axes-run: ⓐ=none ⓑ=→standpoint(qasp) ⓒ=none ⓓ=none ⓔ=none ⓕ=none
controls: n/a — 측정 없음
standpoint: tier1b(qasp)')
check "$S7c" PASS "★컨트롤: 포인터에 대상이 붙어도 standpoint: 줄이 있으면 통과 (과차단 방지)"

S8=$(mk "$D_SIX" 'axes-run: ⓐ=codex ⓑ=→standpoint ⓒ=none ⓓ=none ⓔ=실사용 ⓕ=되돌림
axes-run: ⓐ=거짓말 ⓑ=x ⓒ=x ⓓ=x ⓔ=x ⓕ=x
controls: alive — ok
standpoint: tier1')
check "$S8" BLOCK "★axes-run 줄이 둘 → 차단 (첫 줄만 읽히므로 둘째 줄은 «없다»가 아니라 «안 보인다»)"

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
