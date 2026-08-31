#!/usr/bin/env bash
# test_sim_path_isolation_lanes.sh — `sim_isolated_run.sh` 의 경로 격리 회귀 픽스처.
# tenet: FH-T01 (부재를 0으로 렌더하지 않는다) · FH-T06 (실행이 하중 지는 절반)
#
# 🟥 WHY. 2026-08-30 까지 이 러너는 «격리»가 아니었다. 헤더가 «disposable clone» 이라 적었지만
#    클론은 cwd 일 뿐이고 `--tools "Read,Grep,Glob"` 는 경로를 안 막았다. 팔이 **채점용 qset 을
#    정답 토큰까지** 읽었고, 맥락유지 3개 회차가 무효가 됐다.
#
# 🟥 **초판은 grep 만 했고, new-code-anchor 게이트가 그것을 MENTION_ONLY 로 잡았다** —
#    「레인이 파일을 이름만 대고 실행하지 않는다」. 옳은 지적이었고, 함수를 꺼내 실제로 부르자마자
#    **JSON 결함이 즉시 드러났다**(괄호가 안 닫혀 `Read(...*.txt` + `tracks/**))`).
#    grep 레인이었으면 영영 못 봤다. 이 파일이 그 교훈의 앵커다.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$ROOT/scripts/sim_isolated_run.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
FAIL=0
chk(){ if [ "$2" = "$3" ]; then printf '  ✅ %-48s %s\n' "$1" "$2"; else printf '  ❌ %-48s got=%s want=%s\n' "$1" "$2" "$3"; FAIL=1; fi; }

[ -f "$R" ] || { echo "❌ HARNESS-ERROR — 러너 없음"; exit 10; }
sed -n '/^fh_sim_write_path_isolation()/,/^}/p' "$R" > "$T/f.sh"
# 계기 캘리브레이션 — 빈 추출은 모든 레인을 «아무것도 아닌 것»에 대고 통과시킨다.
grep -q '^fh_sim_write_path_isolation()' "$T/f.sh" || { echo "❌ HARNESS-ERROR — 함수 추출 실패"; exit 10; }
bash -n "$T/f.sh" || { echo "❌ HARNESS-ERROR — 추출본 구문 오류"; exit 10; }

run_iso(){ # $1=WORK $2=OUT $3=REPO $4=HOME → settings 경로를 stdout 으로
  bash -c '. "$1"; fh_sim_write_path_isolation "$2" "$3" "$4" "$5" >/dev/null 2>&1; echo $?' \
       _ "$T/f.sh" "$1" "$2" "$3" "$4"
}
mk(){ local d="$T/$1"; mkdir -p "$d/repo"; printf '%s' "$d"; }
# 🟥 픽스처 경로를 `/Users/x` 같은 «홈처럼 생긴» 리터럴로 쓰지 마라 — 공개표면 기밀 게이트가
#    형태만 보고 MED leak 으로 막는다(2026-08-30 실측 3건). 오탐이지만 **게이트가 옳게 짖는다**:
#    절대 홈 경로가 공개 파일에 리터럴로 들어가는 것은 실제 유출 형태다. 우회하지 않고
#    임시 디렉터리 아래 가짜 이름을 쓴다 — 그러면 픽스처가 실환경과 무관해지기까지 한다.
mkdir -p "$T/fake_repo" "$T/fake_home"
_pt=$(cd "$T" && pwd -P)

# ── L1 실행: 함수가 실제로 파일을 쓴다 ────────────────────────────────────────────
O1=$(mk c1); W1="$O1/repo"
rc=$(run_iso "$W1" "$O1" "$T/fake_repo" "$T/fake_home")
chk "L1 격리 파일을 실제로 쓴다 (rc=0)" "$rc" 0
chk "L1b 파일이 존재한다" "$([ -f "$W1/.claude/settings.local.json" ] && echo yes || echo no)" yes

# ── L2 JSON 유효성 — 🟥 이것이 초판 grep 레인이 못 잡은 결함이다 ──────────────────
chk "L2 유효한 JSON 이다 (괄호/따옴표 조립 결함 탐지)" \
    "$(python3 -c 'import json,sys;json.load(open(sys.argv[1]));print("yes")' "$W1/.claude/settings.local.json" 2>/dev/null || echo no)" yes

# 🟥 L2 만으로는 부족하다 — 실측: 조립이 깨져도 **JSON 은 유효하다**(깨진 괄호가 문자열 «안»에
#    들어가므로). 뮤테이션에서 L2 가 초록으로 남았고, 그래서 아래 L2b 를 추가했다.
#    「JSON 이 파싱되나」와 「각 항목이 규칙 형태인가」는 다른 질문이다.
chk "L2b 모든 deny 항목이 Read(...) 형태이고 괄호가 맞다" \
    "$(python3 - "$W1/.claude/settings.local.json" <<'PY'
import json,sys,re
bad=[d for d in json.load(open(sys.argv[1]))["permissions"]["deny"]
     if not re.fullmatch(r'Read\([^()]*\)', d)]
print(len(bad))
PY
)" 0

DENY=$(python3 -c 'import json,sys;print("\n".join(json.load(open(sys.argv[1]))["permissions"]["deny"]))' "$W1/.claude/settings.local.json" 2>/dev/null)
chk "L3 실제 레포 경로를 막는다"  "$(printf '%s' "$DENY" | grep -cF "/fake_repo/**)" | tr -d ' ')" 1
chk "L4 홈 경로를 막는다"         "$(printf '%s' "$DENY" | grep -cF "/fake_home/**)" | tr -d ' ')" 1
chk "L5 중복 항목이 없다"         "$(printf '%s' "$DENY" | sort | uniq -d | grep -c . | tr -d ' ')" 0

# ── L6 클론이 out 아래면: out 전체가 아니라 «다른 팔의 산출»만 막는다 ─────────────
chk "L6 out-하위 클론이면 out 전체를 막지 않는다" \
    "$(printf '%s' "$DENY" | grep -c "Read(//${O1#/})\$" | tr -d ' ')" 0
chk "L6b 대신 다른 팔의 클론 트리를 막는다" \
    "$(printf '%s' "$DENY" | grep -c 'w_\*/repo/tracks' | tr -d ' ')" 1

# ── L7 자기 클론을 막지 않는다 (첫 수리가 그렇게 자기 발을 쐈다) ──────────────────
_pw=$(cd "$W1" && pwd -P)
_selfblock=0
while IFS= read -r d; do
  case "$d" in "Read(//"*"/**)") pfx="/${d#Read(//}"; pfx="${pfx%/**)}"; case "$_pw" in "$pfx"/*|"$pfx") _selfblock=1 ;; esac ;; esac
done <<< "$DENY"
chk "L7 자기 클론을 포함하는 deny 가 없다" "$_selfblock" 0

# ── L8 격리 없이 강행하는 경로가 명시 플래그로만 열린다 (fail-closed) ─────────────
chk "L8 fail-closed 분기가 있다"       "$(grep -c '격리 없이 재지 않는다' "$R" | tr -d ' ' | awk '{print ($1>0)?"yes":"no"}')" yes
chk "L8b 강행은 명시 플래그로만"        "$(grep -c 'FH_SIM_NO_ISOLATION_OK' "$R" | tr -d ' ' | awk '{print ($1>0)?"yes":"no"}')" yes
# 🟥 심링크 비결정성 — 물리경로로 계산하지 않으면 같은 자리가 두 이름을 갖는다
chk "L9 물리경로로 계산한다 (pwd -P)"   "$(grep -c 'pwd -P' "$R" | tr -d ' ' | awk '{print ($1>0)?"yes":"no"}')" yes

# ── L10 조립 검증 (2026-08-31) — 🟥 «JSON 파싱 레인」은 이 결함을 통과시킨다 ──────────
#    회차 3(_ccrun7)은 위 헤더가 고친 그 파손을 안고 **실제로 돌았다**. 고침은 들어갔는데
#    **레인이 안 들어와서** 재발 감시가 0이었다([[feedback_built_but_not_wired]] 의 이웃).
#    🟥 그 파손된 파일은 **JSON 으로 정상 파싱된다** — 파손이 구조가 아니라 규칙 문자열 «안»에
#    있기 때문이다. 그래서 파싱만 보는 앵커는 두 팔을 못 가르는 장식이다
#    ([[feedback_anchor_can_be_decorative]]). 검사는 셋이다: 파싱 ∧ 항목 문법 ∧ 중복 0.
#    픽스처는 **실물**이다 — 그날의 클론에서 그대로 떠왔고, 홈 경로만 정화했다(정화 후에도
#    BAD=2·DUP=1 로 판별력 동일함을 확인). 🟥 내가 만든 «쉬운 표기»가 아니라 **뚫린 표기**다
#    ([[feedback_fixture_must_use_the_breaking_spelling]]).
_asm_validate(){ python3 - "$1" <<'_PY'
import json,re,sys
try: d=json.load(open(sys.argv[1]))
except Exception: print("JSON_FAIL"); sys.exit(1)
rules=d.get("permissions",{}).get("deny",[])
if not rules: print("EMPTY"); sys.exit(1)
pat=re.compile(r'^[A-Za-z]+\([^()]*\)$')
bad=[r for r in rules if not pat.match(r)]; dup=sorted({r for r in rules if rules.count(r)>1})
print("BAD=%d DUP=%d" % (len(bad),len(dup)))
sys.exit(1 if (bad or dup) else 0)
_PY
}
_FX="$ROOT/scripts/fixtures/isolation_assembly_BROKEN_2026-08-30_ccrun7.json"
# 🟥 픽스처 부재를 «통과»로 렌더하지 않는다 — 사라진 픽스처는 조용한 스킵이고 스킵은 청결로 보인다.
if [ ! -f "$_FX" ]; then echo "❌ HARNESS-ERROR — 파손 픽스처 없음: $_FX"; exit 10; fi
_asm_validate "$_FX" >/dev/null 2>&1
chk "L10 회차3 실물 파손 조립 → 차단" "$([ $? -ne 0 ] && echo BLOCKED || echo passed)" BLOCKED
# 🟥 장식 반증 — 그 픽스처가 JSON 으로는 «정상»임을 같은 레인에서 못 박는다.
chk "L10b 그 픽스처는 JSON 으론 정상 (파싱 앵커 무력 증명)" \
    "$(python3 -c "import json;json.load(open('$_FX'));print('JSON_OK')" 2>/dev/null)" JSON_OK
# known-negative — 현행 조립이 통과하지 못하면 위 BLOCKED 는 «판별»이 아니라 «항상 차단»이다
printf '{"permissions":{"deny":["Read(//a/**)","Read(//b/**)"]}}' > "$T/asm_ok.json"
_asm_validate "$T/asm_ok.json" >/dev/null 2>&1
chk "L10c 정상 조립 → 통과 (판별력)" "$([ $? -eq 0 ] && echo passed || echo BLOCKED)" passed
# 빈 deny 는 «격리 없음»이지 «청결»이 아니다
printf '{"permissions":{"deny":[]}}' > "$T/asm_empty.json"
_asm_validate "$T/asm_empty.json" >/dev/null 2>&1
chk "L10d 빈 deny → 차단 (부재≠청결)" "$([ $? -ne 0 ] && echo BLOCKED || echo passed)" BLOCKED
# 🟥 배선 확인 — 검증이 러너 «안»에서 실제로 불리는가. 함수 밖에 있으면 위 넷은 장식이다.
chk "L10e 러너가 조립 직후 검증을 부른다" \
    "$(grep -c 'ISOLATION-ASSEMBLY' "$R" | awk '{print ($1>0)?"yes":"no"}')" yes

echo
if [ $FAIL -eq 0 ]; then echo "SIM PATH ISOLATION LANES: PASS"; else echo "SIM PATH ISOLATION LANES: FAIL"; fi
exit $FAIL
