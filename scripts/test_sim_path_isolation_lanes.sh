#!/usr/bin/env bash
# test_sim_path_isolation_lanes.sh — `sim_isolated_run.sh` 의 경로 격리 회귀 픽스처.
# tenet: FH-T01 (부재를 0으로 렌더하지 않는다) · FH-T06 (실행이 하중 지는 절반)
#
# 🟥 WHY. 2026-08-30 까지 이 러너는 «격리»가 아니었다. 헤더가 «disposable clone» 이라 적었지만
#    클론은 cwd 일 뿐이고 `--tools "Read,Grep,Glob"` 는 경로를 안 막았다. 실측으로 팔이
#    **채점용 qset 을 정답 토큰까지** 읽었고, 맥락유지 3개 회차가 전부 무효가 됐다.
#    이 레인은 그 구멍이 다시 열리는 것을 막는다.
#
# 🟥 이 스위트는 LLM 을 호출하지 않는다 — 그건 느리고 비결정적이라 회귀 레인에 안 맞는다.
#    대신 «러너가 클론에 무엇을 써넣는가»(= 기록의 속성)를 본다. 실제 차단 여부는 도입 시점에
#    known-pair 3방향으로 실측했고 그 결과를 러너 주석에 남겼다. 그 구분을 접지 마라.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$ROOT/scripts/sim_isolated_run.sh"
FAIL=0
chk(){ if [ "$2" = "$3" ]; then printf '  ✅ %-46s %s\n' "$1" "$2"; else printf '  ❌ %-46s got=%s want=%s\n' "$1" "$2" "$3"; FAIL=1; fi; }

# 계기 캘리브레이션 — 러너를 못 읽으면 아래 전부가 «없음»으로 통과한다.
[ -f "$R" ] || { echo "❌ HARNESS-ERROR — 러너 없음"; exit 10; }
chk "L0-calibration 러너에 known-positive 문자열이 있다" \
    "$(grep -c 'sim_isolated_run' "$R" | tr -d ' ' | awk '{print ($1>0)?"yes":"no"}')" yes

chk "L1 deny 규칙을 클론에 써넣는다" \
    "$(grep -c 'settings.local.json' "$R" | tr -d ' ' | awk '{print ($1>0)?"yes":"no"}')" yes
# 🟥 슬래시 하나짜리(`Read(/tmp/**)`)는 실측에서 **안 막혔다**. 절대경로 표기라야 한다.
chk "L2 절대경로 표기(//)를 쓴다" \
    "$(grep -c 'Read(//tmp/\*\*)' "$R" | tr -d ' ' | awk '{print ($1>0)?"yes":"no"}')" yes
chk "L3 홈 경로도 막는다 (qset·앞선 답변이 사는 곳)" \
    "$(grep -c '_p_home' "$R" | tr -d ' ' | awk '{print ($1>0)?"yes":"no"}')" yes
# 🟥 macOS 에서 `/tmp` = `/private/tmp` 심링크라 **같은 자리가 두 이름**을 갖는다.
#    논리경로만 적으면 어떤 회차는 클론을 막고(과차단) 어떤 회차는 레포를 못 막는다(누출).
#    실측으로 그 비결정성을 봤다 — 비결정적 격리는 격리가 아니다.
chk "L3b 물리경로로 계산한다 (심링크 비결정성 차단)" \
    "$(grep -c 'pwd -P' "$R" | tr -d ' ' | awk '{print ($1>0)?"yes":"no"}')" yes
chk "L3c 다른 팔의 클론 트리도 막는다 (주입된 봉인 원장)" \
    "$(grep -c 'w_\*/repo/tracks' "$R" | tr -d ' ' | awk '{print ($1>0)?"yes":"no"}')" yes
# 🟥 Glob/Grep 항목을 섞으면 클론 «안»까지 과차단됐다(실측). Read 만이어야 한다.
chk "L4 Glob/Grep deny 를 섞지 않는다 (과차단 방지)" \
    "$(grep -cE '\"(Glob|Grep)\(//' "$R" | tr -d ' ')" 0
# 🟥 L5 의 기대값이 바뀌었다 — **결과에 맞춘 게 아니라 규칙이 틀렸었다.**
#    초판은 «기존 settings 가 있으면 SKIPPED 로 알리고 넘어간다» 를 고정했는데,
#    cross-family(agy #4)가 그것을 **명백한 fail-open** 으로 지목했다: 격리 없는 상태로
#    측정을 강행하고, 그 회차의 숫자는 그래도 쓰인다. 「알렸다」는 변명이 안 된다.
#    ⇒ 격리 없이는 **회차를 시작하지 않는다**(CONTAMINATED + continue). 강행은 명시 플래그로만.
chk "L5 격리 없으면 회차를 시작하지 않는다 (fail-closed)" \
    "$(grep -c '격리 없이 재지 않는다' "$R" | tr -d ' ' | awk '{print ($1>0)?"yes":"no"}')" yes
chk "L6 강행 플래그가 명시적으로 있다 (조용한 우회 금지)" \
    "$(grep -c 'FH_SIM_NO_ISOLATION_OK' "$R" | tr -d ' ' | awk '{print ($1>0)?"yes":"no"}')" yes
# 🟥 클론이 사는 경로를 막으면 자기 발을 쏜다 — 첫 수리가 실제로 그랬다(ARM 이 «working
#    directory read 거부»라고 답했다). 그 회피가 코드에 있는지 본다.
chk "L7 클론을 품는 접두사는 deny 에서 제외한다" \
    "$(grep -c '내 클론이 그 아래면 막지 않는다' "$R" | tr -d ' ' | awk '{print ($1>0)?"yes":"no"}')" yes

echo
if [ $FAIL -eq 0 ]; then echo "SIM PATH ISOLATION LANES: PASS"; else echo "SIM PATH ISOLATION LANES: FAIL"; fi
exit $FAIL
