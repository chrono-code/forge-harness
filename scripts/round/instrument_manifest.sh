#!/usr/bin/env bash
# 계기 매니페스트 — 「계기가 바뀌면 봉인 무효」의 «계기» 외연을 기계로 고정한다 (BLOCK-2).
# 🟥 손으로 베낀 해시는 봉인이 아니다. 이 스크립트가 «집합»과 «알고리즘»을 동시에 박는다.
#    알고리즘: sha256 (`shasum -a 256`). 접두 `sha256:` 를 값에 붙여 출력한다 —
#    알고리즘 없는 해시 비교가 오늘 이미 한 번 봉인을 날릴 뻔했다.
#   stamp  : 봉인 시점 매니페스트를 만든다
#   verify : 회차 종료 시 재계산해서 대조한다 (일치/불일치를 종료코드로 낸다)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="${1:?usage: instrument_manifest.sh stamp|verify <manifest> [qset]}"
MF="${2:?manifest path}"; QSET="${3:-}"; SEAL="${4:-}"; GRADE="${5:-}"

# ── 집합. 각 항목 옆에 «왜 이것이 계기인가» ────────────────────────────────────
# 🟥 빠뜨리면 그 파일이 바뀌어도 봉인이 살아남는다. 넣는 기준은 «판정을 바꿀 수 있는가»다.
files=(
  "scripts/context_continuity_score.sh"        # 채점 규칙 자체 — 값이 여기서 정해진다
  "scripts/sim_isolated_run.sh"                # 팔이 무엇을 보는가(격리·프롬프트·stdin)
  "scripts/round/gatecheck_qset.sh"             # 회차를 열지 말지를 정한다(오염 축 차단 + 지시대상 축 advisory)
  "scripts/round/eligcheck_qset.sh"             # negative·conflict 문항 «적격»을 실측으로 차단 — 두 축의 판정 방향이 반대다
  "scripts/test_verdict_watermark_lanes.sh"    # 채점 규칙의 앵커 — 바뀌면 규칙 보증이 바뀐다
  "scripts/test_sim_path_isolation_lanes.sh"   # 격리의 앵커 — 같은 이유
  "scripts/test_sim_isolated_run_lanes.sh"     # stdin·도구 배선의 앵커
  "scripts/round/target_pin.sh"                 # 대상 고정 — gatecheck 가 --pin 으로 부른다(2026-09-01 배선). 이게 바뀌면 «내가 잰 것이 그 파일인가»의 판정이 바뀐다
)
# 🟥 이 스크립트 «자신»도 계기다 — 대조 규칙이 여기 있다. 빠뜨리면 규칙이 바뀌어도 봉인이 산다.
files+=("scripts/round/instrument_manifest.sh")
# qset 과 seal 은 회차마다 다르므로 인자로 받는다(집합의 일부이되 이름이 고정 아님).
# 🟥 seal 을 «손으로 한 줄 추가»하면 verify 가 그 줄을 재생성 못 해 **영구 불일치**가 된다.
#    실제로 그렇게 해봤고 즉시 깨졌다 — 그래서 인자로 받는다. 손추가 잔여는 이걸로 닫혔다.
[ -n "$QSET" ] && files+=("$QSET")
[ -n "$SEAL" ] && files+=("$SEAL")
# 🟥 2026-09-01 신설 — **채점 지시문**. 그날 ①의 지시문이 디스크에서 사라졌고,
#    「기억으로 재구성」과 「새로 쓰기」 사이에서 계기 동일성이 통째로 흔들렸다.
#    채점 지시문은 «값을 정하는 것»이므로 채점기와 같은 급의 계기다.
# 🟥 그런데 실제 사고는 «파일이 없음»이 아니라 **«인자를 안 넘김»** 이었다.
#    인자가 비면 files 에 안 들어가고, 매니페스트는 그 부재를 **한 줄도 안 적는다** —
#    「봉인 안 됨」과 「봉인됨」이 출력상 같아진다. 그래서 부재를 **명시적으로 적는다.**
[ -n "$GRADE" ] && files+=("$GRADE")

emit(){
  # 🟥 채점 계기가 «인자로 안 온» 경우를 한 줄로 물질화한다. 안 적으면 부재가 안 보인다.
  [ -n "$GRADE" ] || printf '%s  %s\n' "<grade-instruction>" "ABSENT"
  for f in "${files[@]}"; do
    if [ -f "$ROOT/$f" ]; then
      printf '%s  sha256:%s\n' "$f" "$(shasum -a 256 "$ROOT/$f" | awk '{print $1}')"
    else
      # 🟥 부재를 «해시 없음»으로 조용히 넘기지 않는다. 없으면 그것도 상태다.
      printf '%s  MISSING\n' "$f"
    fi
  done
}

case "$MODE" in
  stamp)  emit > "$MF"; echo "stamped $(grep -c . "$MF") entries → $MF"
          # 🟥 2026-09-01: 여기가 `grep -c 'MISSING' | awk` 였다. `grep -c` 는 **0 을 찍고 exit 1**
          #    을 낸다. 그게 케이스의 마지막 명령이라 **stamp 성공이 rc=1 로 나왔다** —
          #    「MISSING 0개」가 「실패」로 렌더됐다. 호출자가 rc 를 보면 봉인이 부당하게 막히고,
          #    안 보게 되면 rc 자체가 장식이 된다. 둘 다 나쁘다.
          #    ⇒ 종료코드를 «판정»으로 쓴다: 0=온전 · 2=MISSING 있음.
          _miss=$(grep -c 'MISSING' "$MF"); [ -n "$_miss" ] || _miss=0
          if [ "$_miss" -gt 0 ]; then
            echo "🟥 MISSING 항목 ${_miss}개 — 봉인 전에 해결해라"; exit 2
          fi
          # 🟥 채점 계기 미봉인은 «MISSING(파일 없음)» 과 다른 상태다 — 종료코드를 가른다.
          #    막지는 않는다(과차단은 우회를 훈련시킨다). 대신 «조용하지 않게» 한다.
          if grep -q '^<grade-instruction>  ABSENT$' "$MF"; then
            echo "🟥 채점 지시문이 봉인되지 않았다(5번째 인자 부재) — 매니페스트에 ABSENT 로 적었다"
            echo "   채점 계기가 바뀌면 회차 간 비교가 성립하지 않는다. 봉인하려면:"
            echo "   instrument_manifest.sh stamp <mf> <qset> <seal> <채점지시문>"
            exit 3
          fi
          exit 0 ;;
  verify) [ -f "$MF" ] || { echo "🟥 매니페스트 없음: $MF — 대조 불가(UNVERIFIED, 일치 아님)"; exit 2; }
          # 🟥 2026-09-01 수리. 종전 verify 는 `emit` 을 «지금 인자»로 다시 만들어 diff 했다.
          #    그래서 stamp 때 준 qset/seal 인자를 verify 에서 «안 주면» 그 두 줄이 재생성되지
          #    않아 **거짓 불일치**가 났다. 실제로 밟았다: 회차2 봉인 직후 `verify $MF` 만 불러
          #    「봉인 무효」를 봤고, 인자를 붙여 다시 부르니 rc=0 이었다.
          #    🟥 위험은 «막혔다»가 아니라 **그 반대**다 — 거짓 경보를 한 번 겪으면 다음 사람은
          #    불일치를 보고 「또 인자 문제겠지」로 넘긴다. 진짜 변조가 그 소음에 묻힌다.
          # ⇒ verify 는 «매니페스트가 적은 것»을 대조한다. 인자에 의존하지 않는다.
          #    그리고 반대 방향도 본다: 고정 집합의 계기가 매니페스트에 «없으면» 실패.
          #    (한 방향만 보면 새 계기를 추가하고 재stamp 안 한 상태가 조용히 통과한다)
          if [ -z "$QSET" ] && [ -z "$SEAL" ]; then
            _bad=0; _incomplete=0
            while read -r _p _h; do
              [ -n "$_p" ] || continue
              # 🟥 <grade-instruction> ABSENT 는 «파일»이 아니라 «상태 기록»이다.
              #    파일로 검사하면 verify 가 자기 기록 때문에 영구 불일치를 낸다.
              if [ "$_p" = "<grade-instruction>" ]; then
                echo "🟥 채점 지시문이 봉인되지 않았다 — 이 회차의 숫자는 계기 동일성이 미보증이다"
                _incomplete=1; continue
              fi
              if [ ! -f "$ROOT/$_p" ]; then
                echo "🟥 매니페스트가 적은 파일이 없다: $_p"; _bad=$((_bad+1)); continue
              fi
              _now="sha256:$(shasum -a 256 "$ROOT/$_p" | awk '{print $1}')"
              [ "$_now" = "$_h" ] || { echo "🟥 바뀜: $_p"; echo "   기록 $_h"; echo "   지금 $_now"; _bad=$((_bad+1)); }
            done < "$MF"
            for _f in "${files[@]}"; do
              grep -qF -- "$_f  " "$MF" || { echo "🟥 계기가 매니페스트에 없다(재stamp 필요): $_f"; _bad=$((_bad+1)); }
            done
            if [ "$_bad" -gt 0 ]; then
              echo "🟥 계기 대조 **불일치** — 이 회차의 봉인은 무효다 (${_bad}건)"; exit 1
            fi
            # 🟥 «바뀐 게 없다»와 «봉인이 온전하다»는 다른 명제다. stamp 가 3 을 내는데
            #    verify 가 0 을 내면, verify 만 돌리는 호출자는 미봉인 회차에서 초록을 본다.
            #    종료코드를 갈라 둔다: 1=불일치 · 3=봉인 불완전(대조는 통과).
            if [ "$_incomplete" -gt 0 ]; then
              echo "🟡 대조는 통과했지만 **봉인이 불완전하다** — 채점 계기가 봉인 집합에 없다"; exit 3
            fi
            echo "🟢 계기 대조 일치 — 봉인이 유효하다 ($(grep -c . "$MF") 항목, sha256)"; exit 0
          fi
          now=$(mktemp); emit > "$now"
          if diff -q "$MF" "$now" >/dev/null; then
            echo "🟢 계기 대조 일치 — 봉인이 유효하다 ($(grep -c . "$MF") 항목, sha256)"; rm -f "$now"; exit 0
          else
            echo "🟥 계기 대조 **불일치** — 이 회차의 봉인은 무효다. 바뀐 것:"
            diff "$MF" "$now" | grep '^[<>]' | sed 's|^|   |'; rm -f "$now"; exit 1
          fi ;;
  *) echo "unknown mode: $MODE" >&2; exit 2 ;;
esac
