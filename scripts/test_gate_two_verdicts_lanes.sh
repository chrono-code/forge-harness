#!/usr/bin/env bash
# test_gate_two_verdicts_lanes.sh — pre-commit 의 `_acceptance_evidence_line` 계약을 고정한다.
#
# WHY (2026-09-06, frontier-digest 답습 · arXiv:2609.04167 «SWE-Gate»): 그 논문의 실측은
# 기능 테스트를 통과한 수리 644 건 중 **221 건(34%)** 이 실제 PR 리뷰 코멘트에서 뽑은 제약을
# 어겼다는 것이고, 처방은 «기능 정확성과 리뷰 제약 충족을 따로 채점하라» 다. 이 훅도 같은
# 형태였다 — 축이 다 통과하면 «ALL AXES PASSED» 라는 **합성 판정 하나**만 찍혔고, 마커의
# `crossfamily: DEGRADED_PANEL_UNUSED` 같은 값은 출력 어디에도 안 나왔다.
#
# SCOPE — 채널이지 판정이 아니다(§Mechanization Boundary): 이 함수는 «어떤 값이 적혔나」만
# 찍는다. 값의 진위를 판정하지 않고, 어떤 경우에도 종료코드를 바꾸지 않는다. 그래서 레인도
# «막나」가 아니라 «가려지나」를 잰다 — 특히 DEGRADED/UNKNOWN 이 조용히 사라지지 않는지.
#
# 종료코드: 0 = 계약대로 · 1 = 회귀
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
[ -f "$HOOK" ] || { echo "ⓘ $HOOK absent — subject missing when we looked (NOT a pass)"; exit 2; }

sed -n '/^_acceptance_evidence_line()/,/^}/p' "$HOOK" > "$T/fn.sh"
# 계기 보정: 추출이 비면 아래 픽스처가 «아무것도 아닌 것」을 재고 전부 통과한다.
if ! grep -q '_acceptance_evidence_line' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — _acceptance_evidence_line 이 $HOOK 에서 추출되지 않았다."
  echo "   픽스처가 빈 함수를 잴 참이었다. 초록을 보고하지 않고 중단한다."
  exit 1
fi

FAIL=0
run() { bash -c 'set -uo pipefail; . "$1"; _acceptance_evidence_line "$2"' _ "$T/fn.sh" "${1:-}" 2>&1; }
lane() { # $1=id  $2=marker body ('' = 마커 없음)  $3..=출력에 반드시 있어야 하는 조각들
  local id="$1" body="$2"; shift 2
  local path="" out n rc
  if [ -n "$body" ]; then path="$T/m.marker"; printf '%s\n' "$body" > "$path"; fi
  out=$(run "$path"); rc=$?
  if [ $rc -ne 0 ]; then
    printf '  ❌ %-34s 함수가 rc=%s — 보고 전용인데 실패했다\n     %s\n' "$id" "$rc" "$out"; FAIL=1; return
  fi
  for n in "$@"; do
    if ! printf '%s' "$out" | grep -qF -- "$n"; then
      printf '  ❌ %-34s «%s» 가 출력에 없다\n     %s\n' "$id" "$n" "$out"; FAIL=1; return
    fi
  done
  printf '  ✅ %-34s %s\n' "$id" "$(printf '%s' "$out" | head -1)"
}

echo "== 수용-근거 줄: 값이 그대로 드러나는가 =="

# L1 known-positive — 네 필드가 다 있으면 네 값이 다 나온다
lane L1-all-four "crossfamily: panel(codex,gemini) — 2라운드
standpoint: tier2(qasp) — 명령과 출력을 댔다
thirdparty: checked — 상류 소스 독해
oracle: known-pair — 양성/음성 픽스처" \
  "crossfamily=panel(codex,gemini)" "standpoint=tier2(qasp)" "thirdparty=checked" "oracle=known-pair"

# L2 🟥 하중 레인 — DEGRADED 가 «통과» 뒤에 숨지 않는다 (이 레인 스위트의 존재 이유)
lane L2-degraded-visible "crossfamily: DEGRADED_PANEL_UNUSED — 패널 미사용
standpoint: not-applicable — Q0 ⓒ
oracle: none — 잴 값이 없다" \
  "crossfamily=DEGRADED_PANEL_UNUSED" "standpoint=not-applicable"

# L3 UNKNOWN 도 마찬가지 — «안 봤다»가 «봤는데 괜찮다»로 안 접힌다
lane L3-unknown-visible "crossfamily: UNKNOWN — 안 봤다
standpoint: UNKNOWN — 안 봤다" \
  "crossfamily=UNKNOWN" "standpoint=UNKNOWN"

# L4 부재는 «(없음)» 으로 — 빈 문자열이면 필드가 있었는지조차 안 보인다 (미측정≠0)
lane L4-absent-is-typed "axis2-model: opus" \
  "crossfamily=(없음)" "standpoint=(없음)" "thirdparty=(없음)" "oracle=(없음)"

# L5 마커 자체가 없는 경로(경량 게이트) — 근거가 «있다»고 주장하지 않는다
lane L5-no-marker "" "n/a" "경량 게이트"

# L6 들여쓴 필드도 읽는다(마커는 손으로 쓰는 파일이다)
lane L6-indented "  crossfamily: declined — 근거 있음" "crossfamily=declined"

# L7 첫 줄만 — 같은 키가 둘이면 앞의 것을 찍고 조용히 합치지 않는다
lane L7-first-wins "crossfamily: UNKNOWN — 안 봤다
crossfamily: panel(codex) — 나중 줄" "crossfamily=UNKNOWN"

# ── 컨트롤 A (판별력): 값이 다르면 출력도 달라야 한다 ─────────────────────
printf 'crossfamily: panel(codex) — x\n' > "$T/a.marker"
printf 'crossfamily: DEGRADED_SINGLE_FAMILY — y\n' > "$T/b.marker"
OA=$(run "$T/a.marker"); OB=$(run "$T/b.marker")
if [ "$OA" != "$OB" ] && printf '%s' "$OB" | grep -qF 'DEGRADED_SINGLE_FAMILY'; then
  echo "  ✅ CTRL-A 판별력: 서로 다른 값이 서로 다른 줄을 낸다"
else
  echo "  ❌ CTRL-A 판별력 없음 — 두 마커가 같은 줄을 냈다(계기가 값을 안 읽는다)"; FAIL=1
fi

# ── 컨트롤 B (되돌림): 값 추출을 죽인 뮤턴트에서 L2 가 빨개지는가 ──────────
#    이게 없으면 «필드를 안 읽는 함수»도 이 스위트를 통과한다.
sed 's/^  for f in crossfamily.*/  for f in ; do :; done; out="";/' "$T/fn.sh" > "$T/mut.sh"
if ! grep -q 'out=""' "$T/mut.sh"; then
  echo "  ❌ CTRL-B 뮤턴트가 적용되지 않았다 — 되돌림 프로브가 장식이다"; FAIL=1
else
  MOUT=$(bash -c 'set -uo pipefail; . "$1"; _acceptance_evidence_line "$2"' _ "$T/mut.sh" "$T/b.marker" 2>&1 || true)
  if printf '%s' "$MOUT" | grep -qF 'DEGRADED_SINGLE_FAMILY'; then
    echo "  ❌ CTRL-B 뮤턴트인데도 값이 나온다 — 레인이 실물을 안 재고 있다"; FAIL=1
  else
    echo "  ✅ CTRL-B 되돌림: 추출을 죽이면 값이 사라진다(레인이 실패할 수 있음을 증명)"
  fi
fi

# ── 컨트롤 C (배선): 훅의 PASS 배너가 이 함수를 실제로 부르는가 ───────────
#    함수만 있고 호출부가 없으면 산문이다([[feedback_built_but_not_wired]]).
if grep -q '_acceptance_evidence_line "\${MARKER:-}"' "$HOOK" \
   && grep -q 'ALL AXES PASSED' "$HOOK"; then
  echo "  ✅ CTRL-C 배선: PASS 배너가 이 함수를 부른다"
else
  echo "  ❌ CTRL-C 배선 없음 — 정의만 있고 PASS 배너가 안 부른다"; FAIL=1
fi

# ── 컨트롤 D (무해): 이 함수는 종료코드를 바꾸지 않는다 (채널이지 게이트가 아니다) ──
run "" >/dev/null 2>&1; RC_NONE=$?
run "$T/b.marker" >/dev/null 2>&1; RC_DEG=$?
if [ "$RC_NONE" -eq 0 ] && [ "$RC_DEG" -eq 0 ]; then
  echo "  ✅ CTRL-D 채널: 마커 부재도 DEGRADED 도 rc=0 (막지 않는다)"
else
  echo "  ❌ CTRL-D 이 함수가 종료코드를 바꾼다 (none=$RC_NONE degraded=$RC_DEG) — 채널이 아니라 게이트가 됐다"; FAIL=1
fi

echo "── gate-two-verdicts lanes: $([ $FAIL -eq 0 ] && echo 'all green' || echo 'FAILED')"
exit "$FAIL"
