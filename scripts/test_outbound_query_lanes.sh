#!/usr/bin/env bash
# test_outbound_query_lanes.sh — outbound_query_guard.sh 의 known-pair 앵커.
# 🟥 게이트는 «막나» 만이 아니라 «정상 질의를 안 막나» 도 같이 재야 한다 — 과차단은 override 를
# 반사로 만들고, 그 순간 가드가 장식이 된다(psa_scan_lib.sh 헤더가 같은 이유로 LOW allowlist 를 갖는다).
set -uo pipefail
FH="$(cd "$(dirname "$0")/.." && pwd)"
G="$FH/scripts/outbound_query_guard.sh"
PASS=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "  ✅ $1 → $2"; PASS=$((PASS+1));
       else echo "  ❌ $1 → got=$2 expect=$3"; FAIL=$((FAIL+1)); fi; }

T="$(mktemp -d -t oqg.XXXXXX)" || exit 3
# 🟥 L7 이 실제 라이브러리를 «옮긴다». 중단·실패가 그 사이에 나면 레포에 스캐너가 사라진다
# (cross-family HIGH: "LIBBAK 은 복구에 쓰이지도 않는다"). trap 으로 무조건 되돌린다.
trap 'rm -rf "$T"' EXIT INT TERM
# 픽스처 패턴 파일 — 실제 운영자 토큰을 레인에 넣지 않는다(그 자체가 유출이다)
printf 'HIGH\tZZFIXTURETOKEN\nLOW\tzzlowtok\n' > "$T/defaults"
# override 층은 «있어야» 한다 — 부재는 이제 BLOCK 이다(L8). 내용은 픽스처 전용.
printf 'HIGH\tZZOVERRIDETOKEN\n' > "$T/override"

run(){ PSA_DEFAULTS_FILE="$1" PSA_OVERRIDE_FILE="$2" bash "$G" "$3" >/dev/null 2>&1; echo $?; }

echo "── L1 known-POSITIVE — 내부 토큰이 실린 질의는 막힌다 ──"
chk "L1 내부 토큰 → BLOCK(1)" "$(run "$T/defaults" "$T/override" 'how do I fix ZZFIXTURETOKEN here')" 1

echo "── L2 known-NEGATIVE — 일반 질의는 안 막힌다 (과차단 방지) ──"
chk "L2 일반 질의 → CLEAN(0)" "$(run "$T/defaults" "$T/override" 'harness creator skill prior art')" 0

echo "── L3 🟥 계기 불완전 = 미측정. 통과가 아니라 차단이다 ──"
# defaults 가 없으면 «유출 없음» 이 아니라 «못 쟀다». 커밋 caller 는 경고하지만 외부 질의는 비가역.
chk "L3 defaults 부재 → BLOCK(3), CLEAN 아님" "$(run "$T/nope" "$T/override" 'harmless query')" 3

echo "── L4 override 채널 — 존중되고, 로그가 남는다 ──"
# 🟥 로그도 주입점으로 뺀다(2026-09-05). 박힌 경로였을 때 이 레인은 ⓐ 매 selfcheck 마다 실제
# tracks/_meta 에 행을 쌓았고 ⓑ tracks/ 가 없는 트리(npm 설치본)에서 **`+1` 이 0 이 되어
# 빨개졌다** — 실측으로 확인했고, 그게 이 가드가 출하 목록 밖에 있던 실제 이유였다.
LOG="$T/override_log"
before=$( [ -f "$LOG" ] && wc -l < "$LOG" || echo 0 )
rc=$(PSA_DEFAULTS_FILE="$T/defaults" PSA_OVERRIDE_FILE="$T/override" OUTBOUND_QUERY_OK=1 \
     OUTBOUND_QUERY_LOG="$LOG" bash "$G" 'ZZFIXTURETOKEN 강행' >/dev/null 2>&1; echo $?)
after=$( [ -f "$LOG" ] && wc -l < "$LOG" || echo 0 )
chk "L4 override → 통과(0)" "$rc" 0
chk "L4 override → 로그 +1 (보이지 않는 우회로 금지)" "$((after-before))" 1

echo "── L5 CONTROL — 자리표시자가 «뒤에 오는» 진짜 토큰을 가리지 못한다 ──"
# 🟥 초판 L5 는 같은 토큰을 두 번 넣었을 뿐이라 `head -1` 뮤턴트도 첫 매치에서 막혀 **초록이었다**
# = 장식이었다(cross-family 지목). 진짜 형태: 라이브러리 PSA_PLACEHOLDER 에 걸리는 값이 **먼저**
# 오고 진짜 토큰이 **뒤에** 와야 «모든 매치를 보는가» 가 갈린다.
chk "L5 자리표시자 먼저 + 진짜 토큰 뒤 → BLOCK(1)" \
    "$(run "$T/defaults" "$T/override" 'e.g. YOUR_TOKEN_HERE then ZZFIXTURETOKEN')" 1

echo "── L6 빈 질의 — 스캔할 것이 없으면 막지 않는다 ──"
chk "L6 빈 질의 → 0" "$(run "$T/defaults" "$T/override" '   ')" 0

echo "── L7 CONTROL — 라이브러리 자체가 없으면 차단 ──"
# 🟥 실물 라이브러리를 **안 옮긴다** — 주입점으로 «없는 경로» 를 준다(레포 무결).
rc7=$(PSA_LIB_FILE="$T/does_not_exist.sh" PSA_DEFAULTS_FILE="$T/defaults" \
      PSA_OVERRIDE_FILE="$T/override" bash "$G" 'anything' >/dev/null 2>&1; echo $?)
chk "L7 스캐너 라이브러리 부재 → BLOCK(3)" "$rc7" 3

echo "── L8 🟥 override 층 부재 → 미측정이므로 차단 (HIGH#1 앵커) ──"
chk "L8 override 부재 → BLOCK(3), CLEAN 아님" "$(run "$T/defaults" "$T/nope_ov" 'harmless')" 3

echo "── L9 🟥 개행+탭 우회 — 토큰을 path 필드에 숨길 수 없다 (HIGH#3 앵커) ──"
chk "L9 개행+탭 뒤의 토큰 → BLOCK(1)" \
    "$(run "$T/defaults" "$T/override" "$(printf 'safe question\nZZFIXTURETOKEN\tdecoy')")" 1

echo "── L10 CONTROL — 상태값이 오염돼도 fail-open 하지 않는다 (MED#2 앵커) ──"
# `[ -ne ]` 였으면 비수치 값에서 셸 에러 후 조건 false → 통과했다. `case` 는 안 그렇다.
# psa_load 가 진입 시 상태를 리셋하므로 env 주입으론 이 분기에 **도달할 수 없다**.
# 가짜 레인을 만들지 않고, 주입점으로 «오염 상태를 남기는 라이브러리» 를 넣어 실제로 도달시킨다.
cat > "$T/badlib.sh" <<'STUB'
psa_load(){ PSA_DEFAULTS_OK=oops; PSA_BAD_ROWS=0; PSA_OVERRIDE_PRESENT=1; return 0; }
psa_require_live(){ return 0; }
# 🟥 **테스트 더블이다 — psa 회귀를 구조적으로 못 잡는다** (2026-08-21 배선 리뷰 S-2).
# 이 레인의 대상은 outbound-guard 의 «질의 평탄화·override·로깅» 이지 스캐너가 아니다.
# 단위 경계로서는 정당하지만 **«psa 전수 커버»에 세면 안 된다** — 실물이 아니라 더블을 잰다
# ([[feedback_anchor_can_be_decorative]]). 스캐너 회귀는 test_psa_singlefile_lanes.sh 가 잡는다.
psa_scan_tagged(){ cat >/dev/null; return 0; }
STUB
rc10=$(PSA_LIB_FILE="$T/badlib.sh" PSA_DEFAULTS_FILE="$T/defaults" PSA_OVERRIDE_FILE="$T/override" \
       bash "$G" 'harmless' >/dev/null 2>&1; echo $?)
chk "L10 상태값 비수치 → BLOCK(3)" "$rc10" 3

echo
if [ "$FAIL" -eq 0 ]; then echo "════ outbound-query lanes: $PASS passed · 0 failed ════"; exit 0
else echo "🟥 outbound-query lanes: $FAIL 실패 / $((PASS+FAIL))"; exit 1; fi
