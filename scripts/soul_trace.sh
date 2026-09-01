#!/usr/bin/env bash
# soul_trace.sh — 심지 원칙(tenet) ↔ 기계 앵커의 **양방향 추적성**.
#
# 외부 근거: DO-178C bidirectional traceability —
#   forward  : 모든 요구가 최소 1개 구현/검증에 걸렸나          (미구현 탐지)
#   backward : 모든 구현/검증이 어떤 요구를 근거로 존재하나      (**장식·고아 유닛 탐지**)
# backward 가 값이 큰 쪽이다: 아무 원칙도 근거로 대지 못하는 레인은 «있으니까 있는» 레인이다.
#
# 🟥 **«갭 N건» 이라고 한 숫자로 세지 않는다 (2026-08-31, 외부 답습이 정정).**
#    forward 갭과 backward 갭은 **다른 것**이고 표준에도 다른 이름이 있다:
#      forward  = **undeveloped goal** (GSN) — 오류가 아니라 1급 표기법이다. 「아직 전개 안 됨」.
#      backward = **orphan code** (DO-178C · FDA GPSV) — 근거 없이 존재하는 유닛.
#    둘을 합산하면 「18 → 0」이 목표가 되고, 그러면 **삭제돼야 할 기계에 tenet 을 지어 붙이게 된다.**
#    ⇒ 따로 세고, 따로 렌더하고, **합계를 찍지 않는다.**
#
# 🟥 **정지조건은 「0」이 아니라 「전건 처분됨」이다.** 숫자를 정지조건으로 쓰면 세는 대상이
#    조정된다([[feedback_unreachable_done_when_trains_evasion]]). 표준의 정지조건은
#    indefeasibility 이고, 여기서의 기계적 대응물은 **UNCLASSIFIED = 0** 이다.
#
# 🟥 **갭은 FAIL 이 아니다.** 갭을 FAIL 로 찍으면 «모든 레인이 tenet 을 가져야 한다»는 결론을
#    코드로 굳히는 것이고, 그건 CLAUDE.md §Mechanization Boundary 가 금지하는 형태다
#    (오늘의 판단 → 내일의 천장). 그래서 갭은 **남은 태스크로 append** 한다
#    (GitHub Spec Kit `/speckit.converge` 형태). append 는 채널이고 FAIL 은 결론이다.
#
# SCOPE — backward 는 «마커 다리»(hook 의 validate_*_leg + scripts/test_marker_*.sh) 로 좁혀져
#    있다. 81개 레인 전부에 걸면 태스크 74건이 쏟아져 목록이 소음이 되고, 소음이 된 목록은 꺼진다.
#    넓힐 거면 `TRACE_BACKWARD_GLOBS` 를 늘려라 — 지금 범위는 «심지 엔진 자신의 표면»이다.
#
# Usage: bash scripts/soul_trace.sh [--quiet]
# Exit : 0 정상(갭이 있어도 0 — advisory) · 10 계기 불량(레지스트리 부재/파싱 실패)
set -uo pipefail

# ── 선언-스코프 인용 추출 (D1) — self-test 와 본 경로가 **같은 함수**를 부른다 ──
# 🟥 self-test 가 로직을 «흉내내면» 계기가 대상을 안 부르는 것이 된다
#    ([[feedback_instrument_vs_target_and_budget]]). 그래서 함수로 올려 둘 다 여기를 부른다.
_cite_of() { # $1 = blob → 선언된 `# tenet:` 줄에서만 ID 를 뽑는다. 픽스처 페이로드는 인용이 아니다.
  printf '%s' "$1" | grep -iE '^[[:space:]]*#[[:space:]]*tenets?:' \
    | grep -oE 'FH-T[0-9]{2}' | sort -u
}
# ── disposition — 닫힌 enum, 기존 `crossfamily:`/`standpoint:` 패턴 재사용 (새 기계 아님) ──
# 🟥 이것은 **기록의 속성**이지 결론이 아니다(FH-T02). 훅이 하는 것과 같다: 값이 목록 안에 있는가,
#    근거가 비어 있지 않은가. 「그 처분이 옳은가」는 **안 묻는다.**
# 선언 자리: 유닛은 `# disposition: <값>`, tenet 은 등록부 항목의 `  disposition: <값>`.
SOUL_DISPOSITIONS="derived-promote deactivated-justified dead-remove declared-exception residual-accepted"
# 🟥 `declared-exception` 은 **두 짝**이다 — 사전 선언 + **검출 수단**. 한 낱말이면 미달이다.
#    그래서 이 값만 같은 줄에 ` — <검출 수단>` 을 요구한다(crossfamily 의 degrade-grounds 와 같은 형태).
_disposition_of() { # $1 = blob → stdout: "<값>|<근거>"  (없으면 UNCLASSIFIED|)
  local line v rest
  line=$(printf '%s' "$1" | grep -iE '^[[:space:]]*#?[[:space:]]*disposition:' | head -1)
  if [ -z "$line" ]; then echo "UNCLASSIFIED|"; return; fi
  v=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*#?[[:space:]]*[Dd]isposition:[[:space:]]*//' \
      | awk '{print $1}')
  rest=$(printf '%s' "$line" | sed -E 's/^[^—]*(—[[:space:]]*)?//')
  case " $SOUL_DISPOSITIONS " in
    *" $v "*) ;;
    # 🟥 목록 밖 값을 UNCLASSIFIED 로 접지 마라 — 「안 적었다」와 「틀리게 적었다」는 다르다.
    *) echo "INVALID($v)|$rest"; return ;;
  esac
  if [ "$v" = "declared-exception" ] && [ ${#rest} -lt 12 ]; then
    echo "INVALID(declared-exception:검출수단없음)|$rest"; return
  fi
  echo "$v|$rest"
}
DISPO_TALLY=""

# ── --self-test — 호출부가 있어야 이 스크립트가 «주장»이 아니다 ──────────────────
# 🟥 CI 의 caller-zero ratchet 이 이 파일을 **호출부 0** 으로 잡았다(2026-08-30).
#    오늘 하루 «만들고 안 부른다» 가 아홉 번째였고, **그 결함을 잡으려고 만든 도구 자신이**
#    그 결함이었다. 자기검사를 붙이고 `selfcheck.sh` 의 embedded-suite 목록에 배선한다.
# SCOPE — LLM 없이, 트레이스의 **판별 규칙**만 본다: 산문(.md)·레인(test_*)은 기계 앵커가 아니다.
if [ "${1:-}" = "--self-test" ]; then
  _t=$(mktemp -d); trap 'rm -rf "$_t"' EXIT; _f=0
  _chk(){ if [ "$2" = "$3" ]; then printf '  ✅ %-44s %s\n' "$1" "$2"; else printf '  ❌ %-44s got=%s want=%s\n' "$1" "$2" "$3"; _f=1; fi; }
  # 이 스크립트가 앵커에서 무엇을 빼는지 — 규칙 자체를 본다(실행 경로와 같은 필터).
  _excl(){ printf '%s\n' "$1" | grep -v '/soul_tenets.txt$' | grep -v '/soul_trace.sh$' \
           | grep -v '/test_[^/]*\.sh$' | grep -v '/\.claude/rules/' \
           | grep -v '/\.claude/agents/' | grep -vE '\.md$' | grep -c . | tr -d ' '; }
  _chk "S1 레인 스위트는 앵커가 아니다"       "$(_excl '/r/scripts/test_x_lanes.sh')" 0
  _chk "S2 규칙 산문은 앵커가 아니다"         "$(_excl '/r/.claude/rules/x.md')"      0
  _chk "S3 에이전트 산문도 앵커가 아니다"     "$(_excl '/r/.claude/agents/x.md')"     0
  _chk "S4 모든 .md 가 앵커가 아니다"         "$(_excl '/r/docs/x.md')"              0
  _chk "S5 등록부 자신은 앵커가 아니다"       "$(_excl '/r/.claude/soul_tenets.txt')" 0
  # 🟥 known-negative — 전부 0 이면 «필터가 다 죽인 것»과 구분이 안 된다. 진짜 앵커는 남아야 한다.
  _chk "S6 훅은 앵커다 (컨트롤)"              "$(_excl '/r/templates/.git-hooks/pre-commit')" 1
  _chk "S7 프로덕션 스크립트는 앵커다 (컨트롤)" "$(_excl '/r/scripts/novelty_claim_check.sh')"  1
  # ── D1 회귀 앵커 (2026-08-31) — 「픽스처 페이로드 ≠ 인용」. 🟥 S8 만 넣으면 «추출이 통째로
  #    죽은 것»과 구분이 안 된다. S9 가 그 컨트롤이고, 둘은 **짝으로만** 의미가 있다.
  #    실제 결함 표기를 쓴다: `test_marker_soul_tenet_lanes.sh` 의 tlane 페이로드가 바로 이 형태였다.
  _chk "S8 픽스처 페이로드는 인용이 아니다"     "$(_cite_of 'tenets: FH-T00')"      ""
  _chk "S9 선언 줄은 인용이다 (컨트롤)"         "$(_cite_of '# tenet: FH-T00')"     "FH-T00"
  _chk "S9b 들여쓴 선언도 인용이다"             "$(_cite_of '   #  Tenets: FH-T02')" "FH-T02"
  # ── disposition enum 앵커 — 닫힌 목록 + «안 적었다»≠«틀리게 적었다» + declared-exception 두 짝
  _chk "S10 미선언은 UNCLASSIFIED"              "$(_disposition_of 'x')"                                  "UNCLASSIFIED|"
  _chk "S11 목록 안 값은 통과 (컨트롤)"          "$(_disposition_of '# disposition: dead-remove' | cut -d'|' -f1)" "dead-remove"
  _chk "S12 목록 밖 값은 INVALID (UNCLASSIFIED 아님)" "$(_disposition_of '# disposition: looks-fine' | cut -d'|' -f1)" "INVALID(looks-fine)"
  _chk "S13 declared-exception 은 검출수단 없으면 미달" \
       "$(_disposition_of '# disposition: declared-exception' | cut -d'|' -f1)" "INVALID(declared-exception:검출수단없음)"
  _chk "S14 declared-exception + 검출수단은 통과 (컨트롤)" \
       "$(_disposition_of '# disposition: declared-exception — CI 의 caller-zero ratchet 이 잡는다' | cut -d'|' -f1)" "declared-exception"
  echo; if [ $_f -eq 0 ]; then echo "SOUL TRACE SELFTEST: PASS"; else echo "SOUL TRACE SELFTEST: FAIL"; fi
  exit $_f
fi
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REG="$REPO_ROOT/.claude/soul_tenets.txt"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
# 🟥 검증 실행이 실제 converge 큐를 오염시키지 않도록 override 를 둔다. 기본값은 불변이다.
#    (D3 «append-only, 소비처 0» 의 완전한 수리가 아니다 — 그건 별건이다.)
TASKS="${SOUL_TRACE_TASKS:-$REPO_ROOT/tracks/_meta/soul_trace_tasks.md}"
TRACE_BACKWARD_GLOBS=("$REPO_ROOT"/scripts/test_marker_*.sh)

if [ ! -f "$REG" ]; then
  echo "❌ HARNESS-ERROR — tenet registry not found: .claude/soul_tenets.txt"
  echo "   부재를 0 으로 렌더하지 않는다 ([[feedback_not_found_is_not_zero_family]] · FH-T01)."
  exit 10
fi
# 🟥 bash 3.2 (macOS 기본) 에는 `mapfile` 이 없다 — while-read 로 채운다.
TENETS=()
while IFS= read -r _t; do TENETS+=("$_t"); done < <(grep -oE '^FH-T[0-9]{2}' "$REG" | sort -u)
if [ "${#TENETS[@]:-0}" -eq 0 ] || [ -z "${TENETS[0]:-}" ]; then
  echo "❌ HARNESS-ERROR — registry parsed to ZERO tenets. 계기가 빈 집합을 «통과»로 렌더하려던 참이다."
  exit 10
fi
# 계기 캘리브레이션 — known-positive: 이 스크립트 자신이 레지스트리에서 ID 를 실제로 뽑았고,
# known-negative: 실재하지 않는 ID 는 안 잡혀야 한다.
if printf '%s\n' "${TENETS[@]}" | grep -q '^FH-T99$'; then
  echo "❌ HARNESS-ERROR — known-negative FH-T99 가 잡혔다. 추출 정규식이 과광범위하다."; exit 10
fi


echo "== soul trace — tenets: ${#TENETS[@]} (${TENETS[*]}) =="
# 🟥 합산 금지 — 두 배열은 다른 것을 센다(undeveloped goal ≠ orphan code).
UNDEV=(); ORPHAN=()

echo
echo "-- forward: 각 tenet 이 최소 1개 기계 앵커에 걸렸나 --"
for t in "${TENETS[@]}"; do
  # 🟥 cross-family 독립 수렴(codex #6 · agy 1-①): 초판은 **테스트 픽스처**를 기계 앵커로 셌다.
  #    `test_marker_soul_tenet_lanes.sh` 의 T8 픽스처가 `tenets: FH-T00` 을 담고 있어서
  #    FH-T00 이 «앵커 1개»로 닫힌 것처럼 보였다 — 실제 배선 근거는 0이다.
  #    앵커는 «그 원칙을 근거로 존재하는 프로덕션 유닛»이지 «그 문자열이 등장하는 파일»이 아니다.
  #    ⇒ 레인 스위트(test_*)를 제외한다. 규칙 산문(.claude/rules)도 앵커가 아니다 — 기계가 아니다.
#    🟥 2라운드(agy 결함3): 같은 논리로 `.claude/agents/*.md` 도, **모든 `.md`** 도 제외한다.
#       초판은 rules 만 뺐는데 에이전트 정의는 똑같은 «프롬프트 산문»이다. 판별자는
#       «디렉터리»가 아니라 «실행되는가»여야 한다 — 산문은 어디 있든 기계 앵커가 아니다.
  #    ⚠️ 제외를 넓히면 «앵커 0» 이 늘어나는데, 그건 나빠진 게 아니라 **정직해진 것**이다.
  hits=$(grep -rlF "$t" "$REPO_ROOT/scripts" "$REPO_ROOT/templates" "$REPO_ROOT/.claude" 2>/dev/null \
         | grep -v '/soul_tenets.txt$' | grep -v '/soul_trace.sh$' \
         | grep -v '/test_[^/]*\.sh$' | grep -v '/\.claude/rules/' \
         | grep -v '/\.claude/agents/' | grep -vE '\.md$' | sort -u)
  n=$(printf '%s' "$hits" | grep -c . )
  if [ "$n" -gt 0 ]; then
    printf '  ✅ %-8s %s anchor(s): %s\n' "$t" "$n" "$(printf '%s' "$hits" | sed "s|$REPO_ROOT/||" | tr '\n' ' ')"
  else
    # 🟥 «갭»이 아니라 **undeveloped goal** (GSN). 오류가 아니라 1급 표기법이다.
    _blk=$(awk -v id="$t" '$0 ~ "^"id":" {f=1} f && /^$/ {exit} f' "$REG")
    _d=$(_disposition_of "$_blk"); _dv="${_d%%|*}"
    DISPO_TALLY="$DISPO_TALLY$_dv\n"
    printf '  ⬜ %-8s undeveloped — 앵커 0 · disposition: %s\n' "$t" "$_dv"
    UNDEV+=("undeveloped · $t · [$_dv] 이 tenet 을 근거로 대는 프로덕션 유닛이 0개. 🟥 「0 으로 만들기」가 목표가 아니다 — 위 6값 중 하나로 **처분**하라(등록부 항목에 «  disposition: <값>» 한 줄).")
  fi
done

echo
echo "-- backward: 각 마커-다리가 어떤 tenet 을 근거로 존재하나 --"
declare -a UNITS=()
# 🟥 D2 (2026-08-31) — 초판은 `^validate_[a-z_]+_leg` 였다. 헤더 SCOPE 는 「마커 다리」라고
#    **의미로** 적어놓고 구현은 **작명 규약 grep** 이었다. 그래서 `_leg` 로 안 끝나는 살아있는
#    마커 검증기 셋이 통째로 안 보였다 — `validate_soul_tenet_refs`(호출 :2026) ·
#    `validate_marker_floor`(:2028) · `validate_marker_axes_run`(:2028). 부재가 아니라 **미측정**이었다.
#    ⇒ 전수 수집 후 **제외 목록**으로 좁힌다. 지금 제외는 0개다 — 제외할 것이 생기면 여기 이름으로 적어라.
#    ⚠️ lookahead 를 쓰지 마라: 이 스크립트가 부르는 grep 은 대화형 셸의 ugrep 래퍼가 아니라
#       **BSD grep 2.6.0-FreeBSD** 이고, `(?=...)` 는 `repetition-operator operand invalid` 로 죽는다.
while IFS= read -r fn; do
  case "$fn" in
    ""|_*) continue ;;          # 제외 목록 — 비면 전수. 넓히려면 여기에 이름을 적어라.
  esac
  UNITS+=("hook:$fn")
done < <(
  # 🟥 범위 확대 2026-08-31 — 「작명」에서 「선언된 시그니처」로.
  #    D2 는 `validate_` 접두어로 좁혔는데, 그 규약 밖에 **진짜 마커 다리**가 하나 있었다:
  #    `unread_markers()` — 「이 게이트가 어느 마커 파일을 읽는가」를 판정하고, 전용 레인
  #    (`test_marker_address_lanes.sh`)까지 있으며, 뮤테이션으로 짝이 확인됐다(2026-08-31).
  #    ⇒ 판별자를 **기록의 속성**으로 바꾼다(FH-T02): 이름이 `validate_` 이거나,
  #      **정의 줄의 시그니처 주석이 마커를 인자로 선언**하면 마커 다리다.
  #    ⚠️ 「본문에 marker 가 나오나」로 하면 안 된다 — 손검증 결과 `readme_first_screen_touched`
  #      가 **주석 속 낱말 하나**로 잡히는 오탐이었다. 시그니처는 저자가 선언한 계약이라 안 흔들린다.
  { grep -oE '^validate_[a-z_]+\(\)' "$HOOK" | sed 's/()$//'
    grep -E '^[a-z_][a-z0-9_]*\(\).*#.*\$[0-9].*([Mm]arker|마커)' "$HOOK" \
      | sed -E 's/^([a-z_][a-z0-9_]*)\(\).*/\1/'
  } | sort -u
)
for f in "${TRACE_BACKWARD_GLOBS[@]}"; do [ -f "$f" ] && UNITS+=("lane:${f#"$REPO_ROOT"/}"); done
if [ "${#UNITS[@]}" -eq 0 ]; then
  echo "❌ HARNESS-ERROR — backward 대상이 0개. 빈 집합은 «전부 추적됨»이 아니다."; exit 10
fi
for u in "${UNITS[@]}"; do
  kind="${u%%:*}"; name="${u#*:}"
  case "$kind" in
    hook) # 🟥 선언 헤더는 정의 **앞** 주석 블록에 사는 경우가 있다(`validate_soul_tenet_refs` 가
          #    그 형태다). 본문만 보면 그 선언을 못 읽는다 — `validate_defeater_leg` 가 잡혔던 것은
          #    그것이 헤더를 본문 안에 **한 번 더 복제**해 뒀기 때문이지 규약 덕이 아니었다.
          _ln=$(grep -nE "^${name}\(\)" "$HOOK" | head -1 | cut -d: -f1)
          _from=$(( _ln > 14 ? _ln - 14 : 1 ))
          blob=$(sed -n "${_from},$(( _ln - 1 ))p" "$HOOK"; sed -n "/^${name}()/,/^}/p" "$HOOK") ;;
    lane) blob=$(cat "$REPO_ROOT/$name" 2>/dev/null) ;;
  esac
  # 🟥 인용을 **등록부와 교집합** 낸다 (2026-08-30 첫 실사용이 잡은 오탐):
  #    레인 파일에는 known-negative 픽스처(`FH-T88`/`FH-T99`)가 들어 있는데, 초판은 그것을
  #    «이 레인이 근거로 대는 tenet» 으로 셌다. 즉 **존재하지 않는 원칙을 근거로 인정**했다.
  #    참조 무결성은 훅의 tenet-refs 다리가 마커에 대해 하는 것과 같은 검사다 — 여기도 같아야 한다.
  # 🟥 D1 (2026-08-31) — forward 가 2026-08-30 에 고친 «픽스처를 앵커로 센다» 를 backward 에도
  #    전파한다. 초판은 blob **전문**을 grep 해서, 레인이 실재 ID 를 **시험 데이터**로 쓴 것을
  #    «이 레인의 존재 근거»로 읽었다(`test_marker_soul_tenet_lanes.sh` 의 tlane 페이로드가
  #    `tenets: FH-T00` 을 담고 있어 FH-T00 이 근거로 잡혔다 — 선언 헤더는 FH-T02·FH-T01 뿐이다).
  #    같은 반쪽-픽스가 forward 에만 있었다. 인용은 이 스크립트 자신이 처방하는 규약,
  #    즉 **선언된 `# tenet:` 줄**에서만 읽는다. 「토큰을 쓰는 것」과 「담고 있는 것」은 다르다.
  _raw=$(_cite_of "$blob")
  cited=""; unreg=""
  for _c in $_raw; do
    if printf '%s\n' "${TENETS[@]}" | grep -qx -- "$_c"; then cited="$cited$_c "; else unreg="$unreg$_c "; fi
  done
  if [ -n "$cited" ]; then
    [ -z "$unreg" ] || printf '     ⚠️  미등록 인용 무시: %s(픽스처거나 오타다)\n' "$unreg"
    printf '  ✅ %-46s ← %s\n' "$name" "$cited"
  else
    [ -z "$unreg" ] || printf '     ⚠️  미등록 인용만 있다: %s— 근거로 안 센다\n' "$unreg"
    # 🟥 «갭»이 아니라 **orphan code** (DO-178C · FDA GPSV).
    # 🟥 첫 질문은 「어느 tenet 이 근거인가」가 **아니다** — 그 질문엔 「없다, 지워라」가 유효
    #    선택지가 아니라서 dead code 가 구조적으로 안 나온다. 첫 질문은 **「이걸 지우면 무엇이
    #    빨개지나」**이고, 아무것도 안 빨개지면 `dead-remove` 후보다. 되돌림 축이 그 계기다.
    _d=$(_disposition_of "$blob"); _dv="${_d%%|*}"
    DISPO_TALLY="$DISPO_TALLY$_dv\n"
    printf '  ⬜ %-46s orphan — 근거 tenet 없음 · disposition: %s\n' "$name" "$_dv"
    ORPHAN+=("orphan · $name · [$_dv] 근거 tenet 이 없다. 🟥 먼저 «지우면 무엇이 빨개지나»를 **실행**해라. 아무것도 안 빨개지면 dead-remove 다 — 문서화가 아니라 제거. 그 다음에야 «# tenet:» 을 붙일지 정한다.")
  fi
done

echo
_n_undev=${#UNDEV[@]}; _n_orph=${#ORPHAN[@]}
_uncl=$(printf '%b' "$DISPO_TALLY" | grep -c '^UNCLASSIFIED$')
_inval=$(printf '%b' "$DISPO_TALLY" | grep -c '^INVALID')
echo "-- 처분 분포 (disposition) --"
for _v in $SOUL_DISPOSITIONS UNCLASSIFIED; do
  printf '  %-24s %s\n' "$_v" "$(printf '%b' "$DISPO_TALLY" | grep -c "^$_v\$")"
done
[ "$_inval" -eq 0 ] || printf '  %-24s %s  ← 🟥 목록 밖 값. «안 적었다»와 다르다\n' "INVALID" "$_inval"
echo
# 🟥 두 숫자를 **합치지 않는다.** 합치면 「N → 0」이 목표가 되고, 그 목표는 삭제돼야 할 기계에
#    tenet 을 지어 붙이도록 압력을 만든다.
printf 'TRACE: undeveloped %s (GSN)  ·  orphan %s (DO-178C)  — 🟥 합산하지 않는다\n' "$_n_undev" "$_n_orph"
# 🟥 정지조건 = 「0」이 아니라 **전건 처분됨**. 그 기계적 대응물이 UNCLASSIFIED=0 이다.
if [ "$_uncl" -eq 0 ] && [ "$_inval" -eq 0 ]; then
  echo "TRACE: 정상 종료 — 미처분 0. 처분 분포가 남는 것이 정상이지 «0 건»이 정상이 아니다."
  exit 0
fi
echo "TRACE: 미처분 UNCLASSIFIED=$_uncl · INVALID=$_inval — FAIL 아님. converge 큐에 append: ${TASKS#"$REPO_ROOT"/}"
mkdir -p "$(dirname "$TASKS")"
{
  printf '\n## %s — soul_trace 처분 큐 (undeveloped %s · orphan %s · 미처분 %s)\n\n' \
         "$(date +%Y-%m-%d\ %H:%M)" "$_n_undev" "$_n_orph" "$_uncl"
  printf '> 🟥 이것은 FAIL 목록도 «갭 카운트»도 아니다. 두 종류를 **합산하지 않는다**:\n'
  printf '> undeveloped goal(GSN, 1급 표기법) ≠ orphan code(DO-178C). 정지조건은 「0」이 아니라\n'
  printf '> **미처분 0** 이다 — 숫자를 정지조건으로 쓰면 세는 대상이 조정된다.\n\n'
  for g in ${UNDEV[@]+"${UNDEV[@]}"};  do printf -- '- [ ] %s\n' "$g"; done
  for g in ${ORPHAN[@]+"${ORPHAN[@]}"}; do printf -- '- [ ] %s\n' "$g"; done
} >> "$TASKS"
exit 0
