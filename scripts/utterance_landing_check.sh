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
# ── ⚠️ 명명된 잔여: 프로브는 문구 변경에 깨진다 (2026-08-08 실측) ──
# 정규식을 **정확한 문구**에 걸면, 그 문구를 나중에 고치는 순간 프로브가 죽고 **착지한 항목이
# 미착지로 뜬다**. 실측: 프로브 `2건만|두 개에만` 이 카드 제목을 `2건만` → `2건 병렬` 로
# 편집하자 오탐을 냈다(내용은 그대로 있었다).
#
# 이건 `[[feedback_typed_verdict_channel]]` 이 이름 붙인 Grep-Collision Treadmill 의 반대편이다:
# 충돌은 없는데 **너무 좁아서** 깨진다. 두 방향 모두 "문자열을 재고 대상을 안 본다" 의 사례다.
#
# 완화(닫히지 않음):
#   · 정규식은 **여러 표현을 OR** 로 — 한 문구에 걸지 마라 (`A|B|C`)
#   · **미착지가 뜨면 먼저 손으로 열어 확인**하라. 프로브 노후가 첫 번째 의심 대상이다.
#     rc=1 은 "기록하라"가 아니라 "확인하라"로 읽어야 한다.
#   · 이 실패 방향은 **안전**하다 — 착지한 것을 미착지로 부르지, 미착지를 착지로 부르지 않는다.
#     과차단이지 fail-open 이 아니다. (반대였다면 이 도구는 못 쓴다.)
#
# ── 종료 코드 ──
#   0   전건 착지
#   1   미착지 있음 (라벨과 함께 출력)
#  10   HARNESS-ERROR — 컨트롤 사망 또는 입력 불량. **PASS 도 FAIL 도 아니다**

set -uo pipefail

self_test() {
  local T f=0 n=0
  # mktemp 실패를 안 보면 T 가 빈 문자열이 되고 이어지는 쓰기가 `/a.md` 로 나간다 — 루트에
  # 쓰려다 실패하고, 그 실패가 '캘리브레이션 실패' 로 렌더된다. 계기 부재를 계기 결함으로
  # 오진하는 경로라 여기서 갈라 놓는다. (cross-family 감사에서 실제 샌드박스가 이걸 밟았다.)
  T=$(mktemp -d 2>/dev/null) || T=""
  if [ -z "$T" ] || [ ! -d "$T" ]; then
    echo "🟥 HARNESS-ERROR: mktemp -d 실패 — 캘리브레이션을 돌릴 수 없다(계기 결함이 아니라 환경 부재)."
    return 10
  fi
  trap 'rm -rf "$T"' RETURN
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

  # zsh word-split 재현 방어: 파일 인자가 여러 개일 때 실제로 전부 읽히는가.
  # ⚠️ 이 픽스처는 원래 TARGET 없이 컨트롤 2건만 두고 rc=0 을 기대했다. 그 형태가 곧
  # "아무것도 안 쟀는데 합격" 을 **레인이 승인하는** 상태였다(아래 p6 이 그래서 신설됐다).
  # word-split 을 재려면 컨트롤이 두 파일에 흩어져 있으면 충분하고, TARGET 은 있어야 한다.
  printf 'CONTROL\talpha\tctl\nCONTROL\tbeta\tctl2\nTARGET\t라는\thit\n' > "$T/p4.tsv"
  bash "$0" "$T/p4.tsv" "$T/a.md" "$T/b.md" >/dev/null 2>&1; rc=$?
  t "두 파일에 흩어진 컨트롤 2건 모두 생존" 0 "$rc"

  printf 'TARGET\tbeta\thit\n' > "$T/p5.tsv"
  bash "$0" "$T/p5.tsv" "$T/a.md" >/dev/null 2>&1; rc=$?
  t "컨트롤 0개 → rc=10 (검증 불가)" 10 "$rc"

  # 잰 발화가 0 건인데 초록을 내면 안 된다. rc=1(미착지)과도 **다른 값**이어야 한다 —
  # 둘이 뭉치면 "기록하라" 와 "프로브를 안 썼다" 가 구분되지 않는다.
  printf 'CONTROL\talpha\tctl\n' > "$T/p6.tsv"
  bash "$0" "$T/p6.tsv" "$T/a.md" "$T/b.md" >/dev/null 2>&1; rc=$?
  t "TARGET 0개 → rc=10 (0 도 1 도 아님)" 10 "$rc"

  # 깨진 정규식은 무매치가 아니다. grep 은 에러도 비영으로 주므로 순진하게 받으면
  # **고장난 프로브가 '미착지' 로 렌더된다** = 있지도 않은 누락을 기록하게 만든다.
  printf 'CONTROL\talpha\tctl\nTARGET\t[\tbroken\n' > "$T/p7.tsv"
  bash "$0" "$T/p7.tsv" "$T/a.md" "$T/b.md" >/dev/null 2>&1; rc=$?
  t "깨진 정규식 → rc=10 (1 아님)" 10 "$rc"

  # 대시로 시작하는 패턴이 grep 옵션으로 먹히면 계기가 통째로 오작동한다.
  printf 'CONTROL\talpha\tctl\nTARGET\t-베타\tdashy\n' > "$T/p8.tsv"
  bash "$0" "$T/p8.tsv" "$T/a.md" "$T/b.md" >/dev/null 2>&1; rc=$?
  t "대시 시작 패턴이 옵션으로 안 먹힘 → rc=1(정상 미착지)" 1 "$rc"

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

# 단일 검색 경로. CONTROL 과 TARGET 이 **같은 함수**를 통과해야 한다 — 두 벌로 나누면 한쪽만
# 통과하는 입력이 다른 쪽에서 무음 드롭된다([[feedback_divergent_leniency_duplicate_normalizers]]).
# 반환: 0=매치 · 1=무매치 · 2=grep 에러(잘못된 정규식 등). grep 은 에러도 2 로 주는데, 그걸
# 무매치와 뭉치면 **깨진 프로브가 '미착지'로 렌더된다** — 계기 고장을 데이터로 파는 것이라
# 이 스크립트가 막으려는 바로 그 오독이다. `--` 는 `-foo` 같은 패턴이 옵션으로 먹히는 걸 막는다.
_probe_hits() {
  local pat="$1"; shift
  grep -lE -- "$pat" "$@" 2>/dev/null
  return "${PIPESTATUS[0]:-$?}"
}

# ── 1단계: 컨트롤. 살아있음을 증명하기 전에는 타깃을 인쇄하지 않는다 ──
CTL_TOTAL=0; CTL_DEAD=0; DEAD_LABELS=""; BAD_PAT=""
while IFS=$'\t' read -r kind pat label; do
  [ "${kind:-}" = "CONTROL" ] || continue
  CTL_TOTAL=$((CTL_TOTAL+1))
  _probe_hits "$pat" "${FILES[@]}" >/dev/null; _rc=$?
  if [ "$_rc" -ge 2 ]; then
    BAD_PAT="${BAD_PAT:+$BAD_PAT, }CONTROL/${label:-$pat}"
  elif [ "$_rc" -ne 0 ]; then
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

# TARGET 이 0건이면 잰 것이 없다. 예전 판본은 여기서 `발화 0 건 전부 착지` 를 인쇄하고 **0 을
# 냈다** — 빈 프로브 세트가 초록 도장으로 환전됐다는 뜻이고, 그건 이 스크립트가 존재하는
# 이유와 정확히 반대 방향이다(미측정을 0 으로, 0 을 합격으로). cross-family 감사가 지목했고,
# self-test 의 p4 픽스처가 그 상태를 **기대값 0 으로 인코딩해** 굳히고 있었다 — 레인이 결함을
# 방어하는 대신 승인하고 있었던 셈이다([[feedback_not_found_is_not_zero_family]]).
if ! grep -qE '^TARGET'$'\t' "$PROBES"; then
  echo "🟥 HARNESS-ERROR: probes 에 TARGET 이 없다 — 잰 발화가 0 건이다."
  echo "   '전부 착지' 가 아니라 '아무것도 안 쟀다' 다. 빈 프로브 세트는 합격이 아니다."
  exit 10
fi
echo "계기 생존: 컨트롤 $CTL_TOTAL/$CTL_TOTAL"
echo

# ── 2단계: 타깃 ──
MISS=0; N=0
while IFS=$'\t' read -r kind pat label; do
  [ "${kind:-}" = "TARGET" ] || continue
  N=$((N+1))
  hits=$(_probe_hits "$pat" "${FILES[@]}" | wc -l | tr -d ' '); _rc=${PIPESTATUS[0]}
  if [ "$_rc" -ge 2 ]; then
    printf "  🟥 %-46s 프로브 오류\n" "${label:-$pat}"
    BAD_PAT="${BAD_PAT:+$BAD_PAT, }TARGET/${label:-$pat}"
  elif [ "$hits" -gt 0 ]; then
    printf "  ✅ %-46s %s파일\n" "${label:-$pat}" "$hits"
  else
    printf "  🟥 %-46s 미착지\n" "${label:-$pat}"
    MISS=$((MISS+1))
  fi
done < "$PROBES"

echo
# 깨진 프로브는 '미착지' 가 아니다. 둘을 같은 rc 로 내면 "기록하라" 와 "프로브를 고쳐라" 가
# 구분되지 않고, 후자를 전자로 읽으면 있지도 않은 누락을 기록하게 된다.
if [ -n "$BAD_PAT" ]; then
  echo "🟥 HARNESS-ERROR: 프로브 정규식 오류 — [$BAD_PAT]"
  echo "   grep 이 에러(rc≥2)를 냈다. 무매치가 아니라 계기 고장이다 — 정규식을 고쳐라."
  exit 10
fi
if [ "$MISS" -eq 0 ]; then
  echo "✅ 발화 $N 건 전부 착지"
  exit 0
fi
echo "🟥 $N 건 중 $MISS 건 미착지 — 마감 전에 기록하라."
echo "   ⚠️ 가장 잘 빠지는 것은 잊은 발화가 아니라 **행동으로 대응한 발화**다."
echo "      답장에서 판단까지 내리고 나면 처리된 느낌이 남고, 그 판단이 어디에도 안 적힌다."
exit 1
