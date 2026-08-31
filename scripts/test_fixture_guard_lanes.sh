#!/usr/bin/env bash
# test_fixture_guard_lanes.sh — `scripts/fixture_guard_lib.sh` 의 known-pair 회귀 앵커.
#
# tenet: FH-T02 (기계는 비가역 경계와 채널에만 — 여기서는 «픽스처가 실레포에 쓰나») · FH-T06
#
# WHY THIS LANE EXISTS — 2026-08-31, 3×4 되돌림 행렬이 낸 결론이다:
#   가드 상태 × 처방 조합에서 **가드의 «검사» 가 지키는 칸은 처방이 하나도 못 막는다.**
#     루트가 비었고 가드 rc≠0            → 호출부의 `|| exit 1` 또는 `: "${v:?}"` 가 막는다
#     루트가 비었는데 가드가 rc=0        → `: "${v:?}"` 만 막는다
#     루트가 **비지 않았는데 틀림**(`.`)  → 🟥 **아무 처방도 못 막는다. 가드의 검사뿐이다.**
#   ⇒ 가드를 무장해제하는 회귀에는 **앵커가 하나도 없었다.** 그 자리를 이 레인이 잡는다.
#
# 🟥 stray 탐지기(`test_stray_path_lanes.sh`)와 중복이 아니다 — 축이 다르다:
#     stray_path_scan : 증상을 **사후**에 본다 (디렉터리가 이미 생긴 뒤)
#     이 레인          : 가드가 **무장해제됐나**를 본다 (사고 전)
#
# 🟥 `.` 케이스는 뺄 수 없다 — 처방 A·B 가 둘 다 못 보는 **유일한 칸**이다.
#
# Usage: bash scripts/test_fixture_guard_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$REPO_ROOT/scripts/fixture_guard_lib.sh"

if [ ! -f "$LIB" ]; then
  echo "❌ HARNESS-ERROR — fixture_guard_lib.sh 부재. 부재를 «통과» 로 렌더하지 않는다."; exit 1
fi
# 계기 캘리브레이션 — 빈 추출이면 모든 픽스처가 «아무것도 아닌 것» 을 상대로 통과한다.
if ! grep -q '^fh_fixture_root()' "$LIB"; then
  echo "❌ HARNESS-ERROR — fh_fixture_root 정의를 $LIB 에서 못 찾았다."; exit 1
fi

FAIL=0; N=0
# 🟥 가드는 `exit 1` 로 거부하므로 **서브셸에서** 부른다 — 그러지 않으면 이 레인이 첫 거부에 죽는다.
verdict() { # $1 = 후보 루트(평가 전 문자열) → ALLOW | REFUSE
  if ( . "$LIB"; eval "fh_fixture_root $1" ) >/dev/null 2>&1; then echo ALLOW; else echo REFUSE; fi
}
check() { # $1=label $2=expected $3=arg-expression
  N=$((N+1)); got=$(verdict "$3")
  if [ "$got" = "$2" ]; then printf '✅ %-52s → %s\n' "$1" "$got"
  else printf '❌ %-52s → %s (expected %s)\n' "$1" "$got" "$2"; FAIL=1; fi
}

echo "── K+ 거부해야 하는 루트 ──"
check "K+1 빈 값 (git -C \"\" 는 cwd 를 뜻한다)"      REFUSE "''"
check "K+2 존재하지 않는 경로"                        REFUSE "'/nonexistent-fixture-root-zz'"
check "K+3 파일시스템 루트"                           REFUSE "'/'"
check "K+4 \$HOME"                                    REFUSE "\"\$HOME\""
check "K+5 레포 자신"                                 REFUSE "'$REPO_ROOT'"
check "K+6 레포 하위"                                 REFUSE "'$REPO_ROOT/scripts'"
# 🟥 이것이 A·B 가 둘 다 못 보는 칸이다. 비어 있지 않고, 존재하고, 그런데 **틀렸다**.
check "K+7 '.' — 비지 않은 오답 (A·B 사각)"           REFUSE "'.'"
check "K+8 레포 안의 상대경로 'scripts'"              REFUSE "'scripts'"

echo "── K- 통과해야 하는 루트 (컨트롤 — 전부 REFUSE 면 «다 막는 가드»와 구분이 안 된다) ──"
check "K-1 정상 mktemp"                               ALLOW  "\"\$(mktemp -d)\""
check "K-2 두 번째 정상 mktemp (독립)"                ALLOW  "\"\$(mktemp -d)\""

echo "── 반환값 계약 (호출부가 이 값을 쓴다) ──"
_t=$(mktemp -d); _out=$( . "$LIB"; fh_fixture_root "$_t" 2>/dev/null )
N=$((N+1))
if [ -n "$_out" ] && [ -d "$_out" ]; then printf '✅ %-52s → %s\n' "R1 해석된 절대경로를 반환한다" "ok"
else printf '❌ %-52s → [%s]\n' "R1 해석된 절대경로를 반환한다" "$_out"; FAIL=1; fi
N=$((N+1))
_sym="$_t/link"; ln -s "$_t" "$_sym" 2>/dev/null
_out2=$( . "$LIB"; fh_fixture_root "$_sym" 2>/dev/null )
case "$_out2" in
  */link) printf '❌ %-52s → %s\n' "R2 심볼릭을 해석한다(pwd -P)" "$_out2"; FAIL=1 ;;
  "")     printf '❌ %-52s → 빈 값\n' "R2 심볼릭을 해석한다(pwd -P)"; FAIL=1 ;;
  *)      printf '✅ %-52s → %s\n' "R2 심볼릭을 해석한다(pwd -P)" "ok" ;;
esac
rm -rf "$_t"

echo
if [ "$FAIL" -eq 0 ]; then echo "FIXTURE-GUARD LANES: PASS ($N fixtures)"; else echo "FIXTURE-GUARD LANES: FAIL ($N fixtures)"; fi
exit $FAIL
