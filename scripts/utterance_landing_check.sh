#!/usr/bin/env bash
# utterance_landing_check.sh — 마감 전, 운영자 발화가 기록에 착지했는지 grep 검증.
#
# WHY. 마감 체인이 `CONSISTENT` 를 내면서도 운영자 발화가 통째로 빠지는 일이 두 세션 연속
# 일어났다(2026-08-07 5건 · 2026-08-08 2건). close check 는 **형식**만 본다 — 카드가 로그보다
# 새로운가, 필수 아티팩트가 있는가. **내용이 착지했는지는 안 본다.**
#
# 가장 잘 빠지는 것은 잊은 발화가 아니라 **행동으로 대응한 발화**다. 답장에서 판단까지 내리고
# 나면 처리된 느낌이 남아서, 그 판단이 어디에도 안 적힌 채 세션이 끝난다. 2026-08-08 실측:
# "PMH 가 개인위키에 4축을 돌려 늦어졌다" 에 대해 과적용이라는 판정을 답장에 썼고 기록은 0건.
#
# ── 이 스크립트가 존재하는 두 번째 이유: 손으로 짜면 계기가 죽는다 ──
# 같은 검증을 손으로 짤 때마다 계기가 죽었다(N=3). 마지막 사망 원인은 **zsh word-split**:
#
#     S="a.md b.md";  grep -l "$pat" $S      # bash 는 분리, zsh 는 파일명 하나로 전달 → 전건 0
#
# 컨트롤이 없으면 그 0 이 "전부 미착지" 로 읽힌다. 그래서 이 스크립트는 (1) 파일을 배열로
# 다루고 (2) **컨트롤을 먼저 돌려 살아있음을 증명한 뒤에만** 타깃 결과를 출력한다.
# 컨트롤이 죽으면 타깃 결과를 아예 인쇄하지 않는다 — 죽은 계기의 출력은 데이터가 아니다.
#
# ── 사용 ──
#   bash scripts/utterance_landing_check.sh <probes.tsv> <file> [<file>...]
#   bash scripts/utterance_landing_check.sh --self-test
#
#   probes.tsv 형식 (탭 구분):
#     CONTROL<TAB><정규식><TAB><라벨>     착지가 확실한 것. 하나라도 0이면 HARNESS-ERROR
#     TARGET<TAB><정규식><TAB><라벨>      검증 대상 발화
#
# ── 종료 코드 ──
#   0   전건 착지
#   1   미착지 있음 (라벨과 함께 출력)
#  10   HARNESS-ERROR — 컨트롤 사망 또는 입력 불량. **PASS 도 FAIL 도 아니다**

set -uo pipefail

self_test() {
  local T f=0 n=0
  T=$(mktemp -d); trap 'rm -rf "$T"' RETURN
  printf 'alpha 라는 단어\n' > "$T/a.md"
  printf 'beta 라는 단어\n'  > "$T/b.md"
  t() { n=$((n+1)); if [ "$2" = "$3" ]; then echo "✅ $1 → $3"; else echo "❌ $1 → $3 (기대 $2)"; f=1; fi; }

  printf 'CONTROL\talpha\tctl\nTARGET\tbeta\thit\n' > "$T/p1.tsv"
  bash "$0" "$T/p1.tsv" "$T/a.md" "$T/b.md" >/dev/null 2>&1 && r=PASS || r=FAIL
  t "컨트롤 생존 + 타깃 착지" PASS "$r"

  printf 'CONTROL\talpha\tctl\nTARGET\tgamma\tmiss\n' > "$T/p2.tsv"
  bash "$0" "$T/p2.tsv" "$T/a.md" "$T/b.md" >/dev/null 2>&1; rc=$?
  t "타깃 미착지 → rc=1" 1 "$rc"

  # 핵심 레인: 컨트롤이 죽으면 타깃이 '전부 미착지'처럼 보이는데, 그때 1을 내면 안 된다.
  printf 'CONTROL\tzzz없는단어\tctl\nTARGET\tbeta\thit\n' > "$T/p3.tsv"
  bash "$0" "$T/p3.tsv" "$T/a.md" "$T/b.md" >/dev/null 2>&1; rc=$?
  t "컨트롤 사망 → rc=10 (1 아님)" 10 "$rc"

  # zsh word-split 재현 방어: 파일 인자가 여러 개일 때 실제로 전부 읽히는가
  printf 'CONTROL\talpha\tctl\nCONTROL\tbeta\tctl2\n' > "$T/p4.tsv"
  bash "$0" "$T/p4.tsv" "$T/a.md" "$T/b.md" >/dev/null 2>&1; rc=$?
  t "두 파일에 흩어진 컨트롤 2건 모두 생존" 0 "$rc"

  printf 'TARGET\tbeta\thit\n' > "$T/p5.tsv"
  bash "$0" "$T/p5.tsv" "$T/a.md" >/dev/null 2>&1; rc=$?
  t "컨트롤 0개 → rc=10 (검증 불가)" 10 "$rc"

  echo; [ "$f" -eq 0 ] && echo "✅ 캘리브레이션 통과 ($n 쌍)" || echo "❌ 캘리브레이션 실패 ($n 쌍)"
  return "$f"
}

[ "${1:-}" = "--self-test" ] && { self_test; exit $?; }

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <probes.tsv> <file> [<file>...]" >&2
  echo "       $0 --self-test" >&2
  exit 10
fi

PROBES="$1"; shift
FILES=("$@")   # 배열 — word-split 에 의존하지 않는다
[ -f "$PROBES" ] || { echo "🟥 HARNESS-ERROR: probes 파일 없음: $PROBES"; exit 10; }
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "🟥 HARNESS-ERROR: 대상 파일 없음: $f"; exit 10; }
done

# ── 1단계: 컨트롤. 살아있음을 증명하기 전에는 타깃을 인쇄하지 않는다 ──
CTL_TOTAL=0; CTL_DEAD=0; DEAD_LABELS=""
while IFS=$'\t' read -r kind pat label; do
  [ "${kind:-}" = "CONTROL" ] || continue
  CTL_TOTAL=$((CTL_TOTAL+1))
  if ! grep -lE "$pat" "${FILES[@]}" >/dev/null 2>&1; then
    CTL_DEAD=$((CTL_DEAD+1)); DEAD_LABELS="${DEAD_LABELS:+$DEAD_LABELS, }${label:-$pat}"
  fi
done < "$PROBES"

if [ "$CTL_TOTAL" -eq 0 ]; then
  echo "🟥 HARNESS-ERROR: probes 에 CONTROL 이 없다."
  echo "   컨트롤 없는 부재 측정은 근거가 아니다 — 0 이 '미착지'인지 '계기 사망'인지 구분 불가."
  exit 10
fi
if [ "$CTL_DEAD" -gt 0 ]; then
  echo "🟥 HARNESS-ERROR: 컨트롤 $CTL_DEAD/$CTL_TOTAL 사망 — [$DEAD_LABELS]"
  echo "   착지가 확실한 문자열이 안 잡힌다 = 계기가 대상을 못 읽고 있다."
  echo "   타깃 결과는 **인쇄하지 않는다** — 죽은 계기의 출력은 데이터가 아니라 소음이다."
  echo "   흔한 원인: zsh word-split(\$FILES 인용 누락) · 경로 오류 · 인코딩 불일치."
  exit 10
fi
echo "계기 생존: 컨트롤 $CTL_TOTAL/$CTL_TOTAL"
echo

# ── 2단계: 타깃 ──
MISS=0; N=0
while IFS=$'\t' read -r kind pat label; do
  [ "${kind:-}" = "TARGET" ] || continue
  N=$((N+1))
  hits=$(grep -lE "$pat" "${FILES[@]}" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$hits" -gt 0 ]; then
    printf "  ✅ %-46s %s파일\n" "${label:-$pat}" "$hits"
  else
    printf "  🟥 %-46s 미착지\n" "${label:-$pat}"
    MISS=$((MISS+1))
  fi
done < "$PROBES"

echo
if [ "$MISS" -eq 0 ]; then
  echo "✅ 발화 $N 건 전부 착지"
  exit 0
fi
echo "🟥 $N 건 중 $MISS 건 미착지 — 마감 전에 기록하라."
echo "   ⚠️ 가장 잘 빠지는 것은 잊은 발화가 아니라 **행동으로 대응한 발화**다."
echo "      답장에서 판단까지 내리고 나면 처리된 느낌이 남고, 그 판단이 어디에도 안 적힌다."
exit 1
