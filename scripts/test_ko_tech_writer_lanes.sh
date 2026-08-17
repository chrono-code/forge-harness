#!/usr/bin/env bash
# test_ko_tech_writer_lanes.sh — `ko-tech-writer` Step 2 / Step 4-b 스캔의 **판별력**을 known-pair 로 잰다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 왜 필요한가 — 이 레포가 자기 스캔을 이미 UNCALIBRATED 로 강등해 놨다
# ─────────────────────────────────────────────────────────────────────────────
# `knowledge/shared/harness-core/harness_terminal_correlation_and_recommendations.md:235-236`:
#
#   Step 2 문체 규율   번역투·조각문 5종 스캔 «잔여 0건(양성 컨트롤 동반)» 주장
#                     → 🟥 UNCALIBRATED — 컨트롤이 무엇이었는지·재현 커맨드·출력이
#                        **하나도 없다**. 재현 불가한 0은 0의 증거가 아니다
#   Step 4 수치 게이트  «전칭 단정 스캔 잔여 0건» 주장
#                     → 🟥 UNCALIBRATED — **자기반증**: 그 «0건» 시점에 전칭 단정이
#                        3건 살아 있었다. 계기는 초록인데 대상을 안 쟀다
#
# 챔버 런 #12(2026-08-17, `prosody-lens` KILL)가 이걸 배출 판정의 결정적 근거로 썼다 —
# *"같은 계열 계기가 미보정인데 하나 더 짓는 것은 재발명이자 미보정 계기의 증식"*.
# 운영자 결정: **새 계기보다 이 부채가 먼저.** 이 파일이 그 부채를 갚는다.
#
# 🟥 이 파일이 주는 것과 안 주는 것 — 섞지 마라
#   준다     각 스캔이 **양성을 잡고 음성을 안 잡는가**(=판별력). 재현 커맨드와 실행 출력.
#   안 준다  그 스캔이 **실제 문서에서 잔여 0건인가**. 그건 문서마다 따로 재는 것이고,
#            이 파일은 «계기가 재는 도구로서 성립하는가»까지만 답한다.
#            ⇒ 이걸 통과했다고 «Step 2 잔여 0» 을 주장하면 강등 사유가 그대로 재발한다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 엔진 고정 — SKILL.md 가 `rg` 로 못 박은 이유가 이 머신에서 실증된다
# ─────────────────────────────────────────────────────────────────────────────
# SKILL.md Step 4: *"유니코드 인식 엔진(ripgrep·GNU grep UTF-8 로케일·Python re —
# **`grep -P`는 예외**)에서 한글은 word 문자"*. 실측 2026-08-17: 이 개발 머신의 `grep` 은
# **ugrep 7.5.0**(GNU 아님)이다. 그래서 이 스위트는 `rg` 를 요구하고, 없으면 **SKIP 이 아니라
# rc=10(계기 부재)** 로 끝낸다 — 미측정을 통과로 렌더하지 않는다.
#
# 사용: bash scripts/test_ko_tech_writer_lanes.sh
# exit: 0 전 레인 통과 · 1 판별 실패 · 10 harness error(엔진/픽스처 부재)

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIX="$SRC/../plugins/fh-commons/skills/ko-tech-writer/fixtures"
POS="$FIX/known_positive.md"
NEG="$FIX/known_negative.md"

command -v rg >/dev/null 2>&1 || {
  echo "❌ harness error: ripgrep(rg) 부재 — SKILL.md 가 엔진을 rg 로 고정했다." >&2
  echo "   이 머신의 grep 이 GNU 인지 ugrep 인지에 따라 한글 word 경계가 갈리므로," >&2
  echo "   grep 으로 대체하지 않는다. 미측정은 통과가 아니다." >&2; exit 10; }
for f in "$POS" "$NEG"; do
  [ -f "$f" ] || { echo "❌ harness error: 픽스처 부재 $f" >&2; exit 10; }
done

PASS=0; FAIL=0
echo "── ko-tech-writer Step2/4-b 판별력 known-pair ──"
echo "   engine: $(rg --version | head -1)"
echo "   known-positive: ${POS#"$SRC/../"}"
echo "   known-negative: ${NEG#"$SRC/../"}"
echo

# $1=라벨  $2=패턴(ERE, rg)  — 양성엔 1건 이상, 음성엔 0건이어야 판별력이 있다
_pair() {
  local label="$1" pat="$2" np nn
  np=$(rg -c --no-heading -e "$pat" "$POS" 2>/dev/null || true); np="${np:-0}"
  nn=$(rg -c --no-heading -e "$pat" "$NEG" 2>/dev/null || true); nn="${nn:-0}"
  if [ "$np" -ge 1 ] && [ "$nn" -eq 0 ]; then
    echo "✅ $label — 양성 ${np}건 · 음성 0건 (판별)"; PASS=$((PASS+1))
  elif [ "$np" -lt 1 ]; then
    echo "❌ $label — **양성을 못 잡는다**(양성 ${np}건). 미탐 = 계기가 죽었다"; FAIL=$((FAIL+1))
  else
    echo "❌ $label — **음성을 잡는다**(음성 ${nn}건). 과차단 = 판별력 없음"; FAIL=$((FAIL+1))
  fi
}

# ── Step 2 — 기계 검출 가능한 5클래스 (SKILL.md 가 «앞 다섯 줄» 로 명시한 것) ──────
_pair "C1 줄표 이어붙임"   '(다|것|음) — '
_pair "C2 용어-머리"       '^\s*[-*]\s+\*\*[^*]+\*\* — '
_pair "C3 콜론 나열투"     '[가-힣]은: '
# 🟥 C4 는 SKILL.md 에 **패턴이 없다.** 검출 힌트 칸이 «서술어 없는 마침» 이라는 **산문 서술**
# 이고, C1·C5 처럼 실제 grep 이 실려 있지 않다. 첫 캘리브레이션이 그걸 드러냈다(내가 임의로
# 지은 패턴이 양성을 0건으로 놓쳤다). ⇒ 정본의 «앞 다섯 줄은 기계 검출 가능» 분류는 **과장**
# 이다 — grep 을 싣고 있는 건 C1·C5 **둘**뿐이고 C2·C3·C4 는 산문 힌트다.
# 아래는 **후보 검출**이지 판정이 아니다(SKILL.md 자신의 규율: "grep은 후보를 표시할 뿐").
# 명사 종결 어휘를 닫힌 목록으로 잡는다 — recall 이 낮은 것이 과차단보다 안전한 방향이고,
# 낮다는 사실을 여기 적는다. 넓히려면 어휘를 늘리는 게 아니라 형태소 분석이 필요하다.
_pair "C4 조각문(후보·닫힌 어휘)" '(층|것|점|축|건|뿐|바|셈)\.\s*(<!--|$)'
_pair "C5 소유 직역"       '(을|를) (갖|가지)'

# ── Step 4-b — 전칭 단정 후보 (SKILL.md 의 두 패턴을 그대로 쓴다) ─────────────────
_pair "C6 전칭 어휘"       '전부|모두|하나도|전혀|일절|예외 없이'
_pair "C6b 부정형 전칭"    '(안|못) ?(했|만들|나오|잡히)|지 않았(다|습니다)'

echo
# ── 메타 컨트롤: 이 스위트 자체가 죽은 계기가 아닌가 ──────────────────────────
# 「늘 판별한다」를 내는 계기와 구분한다 — 절대 안 잡혀야 하는 패턴이 양쪽 다 0인지.
_ctl=$(rg -c --no-heading -e 'ZZZ_존재하지_않는_토큰_ZZZ' "$POS" "$NEG" 2>/dev/null | wc -l | tr -d ' ')
if [ "${_ctl:-0}" = "0" ]; then
  echo "✅ META 컨트롤 — 없는 패턴은 양쪽 다 0건(계기가 «늘 잡는다»를 내지 않는다)"; PASS=$((PASS+1))
else
  echo "❌ META 컨트롤 — 존재하지 않는 토큰이 잡혔다. 이 스위트를 믿지 마라"; FAIL=$((FAIL+1))
fi
# 픽스처가 실제로 다른 파일인가(같은 파일 두 번 읽는 사고 방지)
if [ "$(rg -c . "$POS" 2>/dev/null)" != "$(rg -c . "$NEG" 2>/dev/null)" ] || ! diff -q "$POS" "$NEG" >/dev/null 2>&1; then
  echo "✅ META 컨트롤 — 양성/음성 픽스처가 서로 다른 파일이다"; PASS=$((PASS+1))
else
  echo "❌ META 컨트롤 — 두 픽스처가 동일하다. 판별 결과가 무의미"; FAIL=$((FAIL+1))
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "✅ 판별력 확인 ($PASS 레인) — Step 2 5클래스 + Step 4-b 2패턴이 양성/음성을 가른다."
  echo "   ⚠️ 이것이 증명하지 않는 것: 임의 문서에서의 «잔여 0건». 그건 문서마다 따로 재는 것이고,"
  echo "      이 스위트를 근거로 «잔여 0» 을 주장하면 UNCALIBRATED 강등 사유가 그대로 재발한다."
  exit 0
fi
echo "🟥 판별 실패 ($FAIL/$((PASS+FAIL)))"
exit 1
