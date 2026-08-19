#!/usr/bin/env bash
# test_frontier_digest_retry.sh — frontier_digest_daily.sh retry/watchdog 재현 하네스.
#
# WHY (주간감사 2026-07-22 🟧2): 07-18 에 넣은 retry×3 + 30분 watchdog 이 첫 실패일(07-19)에
# **둘 다 미발화**했는데, 그 수리에는 회귀 앵커가 없었다 — "수리 커밋에 회귀 앵커가 없으면
# 수리는 미검증 가설이다"(fh_signal 07-22 S-3). 이 파일이 그 앵커다.
#
# 범위 정직성: 이 하네스는 **스크립트 로직**을 검증한다 — 연결실패→재시도, hang→watchdog kill,
# 성공→조기종료, TERM→계측로그. 07-19 의 환경 원인(ⓐ시스템 슬립 vs ⓑlaunchd 회수)은 로컬에서
# 재현 불가 — 그건 프로덕션 스크립트에 심은 판별 계측(trap + backoff 단계 로깅)이 다음 실발화
# 때 가른다. 여기 4/4 PASS = "로직은 건전, 남은 델타는 환경" 까지만 주장한다.
#
# Exit 0 = 4/4 · exit 1 = 로직 결함 (07-19 클래스가 스크립트 안에 있다)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/frontier_digest_daily.sh"
FAILED=0
TODAY=$(date +%Y_%m_%d)

mk_sandbox() {  # stdout: sandbox dir
  local T; T=$(mktemp -d)
  mkdir -p "$T/fh/tracks/_meta/logs" "$T/bin"
  # 🟥 2026-08-19: 러너가 «엔진 레포가 아닌 트리»에서 돌면 프로필 선언을 요구한다
  #    (FD_PROFILE 미설정으로 게이트를 끌 수 있으면 그게 우회다 — cross-family S1).
  #    이 샌드박스도 엔진 레포가 아니므로 선언을 준다. 재시도/watchdog 로직을 재는 레인이라
  #    금지선은 비우되(`none`) **명시적으로** 적는다 — 빈 값은 미선언과 같이 막힌다.
  printf -- '---\nsatellite_profile: v1\nforbidden_paths: [none]\noutput_location: tracks/_meta\negress_sinks: [none]\n---\n' \
      > "$T/fh/.satellite-profile.md"
  echo "$T"
}

run_case() {  # $1=name $2=stub-body $3=expect-grep $4=expect-exit [$5=extra-env]
  local name="$1" stub="$2" want="$3" want_exit="$4" extra="${5:-}"
  local T; T=$(mk_sandbox)
  printf '#!/usr/bin/env bash\n%s\n' "$stub" > "$T/bin/claude-stub"
  chmod +x "$T/bin/claude-stub"
  local log="$T/fh/tracks/_meta/logs/frontier_digest_${TODAY}.log"
  set +e
  env FD_FH_DIR="$T/fh" FD_PROFILE=.satellite-profile.md FD_CLAUDE_BIN="$T/bin/claude-stub" \
      FD_ATTEMPT_TIMEOUT_SECS=3 FD_POLL_SECS=1 FD_RETRY_SLEEP_SECS=1 $extra \
      bash "$RUNNER" >/dev/null 2>&1
  local rc=$?
  local ok=1
  grep -q "$want" "$log" 2>/dev/null || ok=0
  [ "$rc" -eq "$want_exit" ] || ok=0
  if [ "$ok" = 1 ]; then echo "✅ $name (exit=$rc)"; else
    echo "❌ $name — exit=$rc(기대 $want_exit), 로그에 '$want' $(grep -q "$want" "$log" 2>/dev/null && echo 있음 || echo 없음)"
    sed 's/^/     | /' "$log" 2>/dev/null | tail -8
    FAILED=1
  fi
  # 고아 정리 (challenger B-2: watchdog 이 부모만 죽여 stub 자식 sleep 이 남았었다)
  pkill -f "$T/bin/claude-stub" 2>/dev/null || true
  rm -rf "$T"
}

# ① 연결실패 재현 (07-19 클래스): 즉시 exit 1, 파일 없음 → 3회 전부 시도 후 실패 종료
run_case "① fail-fast → Attempt 3/3 까지 진행 + 최종 실패" \
  'echo "API Error: Connection closed mid-response"; exit 1' \
  "Attempt 3/3" 1

# ② hang 재현 (65분 클래스): 무한 대기 → watchdog(3s) kill
run_case "② hang → watchdog kill" \
  'sleep 300' \
  "killed by watchdog" 1

# ③ 2차 시도 성공: attempt 1 실패, attempt 2 가 산출물 생성 → 조기 성공 종료
#    (스텁이 마커 파일로 호출 횟수를 센다)
run_case "③ 1차 실패 → 2차 성공 조기종료" \
  'M="$FD_FH_DIR/.calls"; n=$(cat "$M" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$M"
   if [ "$n" -ge 2 ]; then head -c 2048 /dev/zero | tr "\0" x > "$FD_FH_DIR/tracks/_meta/frontier_digest_'"$TODAY"'.md"; exit 0; fi
   exit 1' \
  "after attempt 2" 0 "FD_FH_DIR_PASSTHRU=1"

# ④ TERM 판별 계측: backoff sleep 중 TERM → 가설-ⓑ 증거 로그
T=$(mk_sandbox)
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/bin/claude-stub"; chmod +x "$T/bin/claude-stub"
log="$T/fh/tracks/_meta/logs/frontier_digest_${TODAY}.log"
env FD_FH_DIR="$T/fh" FD_PROFILE=.satellite-profile.md FD_CLAUDE_BIN="$T/bin/claude-stub" \
    FD_ATTEMPT_TIMEOUT_SECS=3 FD_POLL_SECS=1 FD_RETRY_SLEEP_SECS=30 \
    bash "$RUNNER" >/dev/null 2>&1 &
RPID=$!
sleep 4   # attempt 1 실패 → backoff sleep 진입 대기
T0=$SECONDS
kill -TERM "$RPID" 2>/dev/null || true
# ★ 신속-종료 기대치 (challenger B-1): trap-without-exit 는 신호를 삼켜 러너가 backoff 를
#   끝까지 돌았다(실측 ~70초). 인터럽터블 sleep + 재발사면 TERM 후 수 초 내 죽어야 한다.
#   5초 안에 안 죽으면 삼킴 회귀다.
DEAD=0
for _i in 1 2 3 4 5; do kill -0 "$RPID" 2>/dev/null || { DEAD=1; break; }; sleep 1; done
wait "$RPID" 2>/dev/null || true
ELAPSED=$((SECONDS - T0))
if grep -q "SIGNAL: runner received TERM" "$log" 2>/dev/null && [ "$DEAD" = 1 ]; then
  echo "✅ ④ backoff 중 TERM → 판별 로그 + ${ELAPSED}s 내 종료 (신호 삼킴 없음)"
else
  echo "❌ ④ TERM: 로그기록=$(grep -q 'SIGNAL: runner received TERM' "$log" 2>/dev/null && echo yes || echo no) 신속종료=$DEAD (${ELAPSED}s) — 삼킴 회귀?"
  sed 's/^/     | /' "$log" 2>/dev/null | tail -6; FAILED=1
fi
pkill -P "$RPID" 2>/dev/null || true   # 고아 정리 (B-2)
rm -rf "$T"

echo "── retry/watchdog harness: $([ "$FAILED" -eq 0 ] && echo "PASS — 로직 건전, 잔여 델타는 환경(라이브 계측이 판별)" || echo "FAIL — 스크립트 로직 결함") ──"
exit "$FAILED"
