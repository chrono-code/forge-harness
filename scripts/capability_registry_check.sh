#!/usr/bin/env bash
# capability_registry_check.sh — 정체성 ① 의 «등록 시점» 검사기.
#
# ─────────────────────────────────────────────────────────────────────────────
# 왜 이게 지어졌나 — 스펙이 이름까지 붙여놓고 «없다» 고 적어둔 파일
# ─────────────────────────────────────────────────────────────────────────────
# `capability_composition_contract.md §Salience` 는 이렇게 적는다:
#
#   "Named residual, not built: a scripts/capability_registry_check.sh that validates
#    the schema and runs each declared M4 pair would make registration *measured*
#    rather than reviewed. It does not exist."
#
# `relay_channel.sh` 헤더도 같은 말을 한다 — 자기는 **call moment** 만 보고, 선언이
# **진실인지**는 검사하지 않는다고. 이 파일이 그 나머지 절반이다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 이 검사기가 증명하지 않는 것 (과잉주장 금지 — 명명된 잔여)
# ─────────────────────────────────────────────────────────────────────────────
# · **등록을 강제하지 않는다.** "지금 capability 를 등록하려 한다"를 관측하는 훅은 없다.
#   돌리면 판정하지만 돌리도록 강제하지는 못한다(relay_channel.sh 의 같은 잔여와 동형).
# · **M3(모델 독립성)은 선언 검사다.** reps 로 재지 않는다 — `judge:` 축 선언과, mechanical
#   선언인데 entry 가 LLM CLI 를 부르는 명백한 모순만 잡는다. M4 를 reps=2 로 돌려 부분 방어.
# · ✅ **`writes:` 축은 2026-08-16 부터 관측된다(M6).** 아래 문단은 그 전의 상태이고,
#   구조 처방으로 적어둔 것이 실제로 지어졌다 — `capability_effect_probe.sh` 를 M6 에서
#   부른다. 사고 형태(`rm -rf scripts` + `read-only` 선언)는 이제 **REJECTED** 로 막힌다
#   (self-test 레인으로 고정). 남은 한계는 그 프로브 헤더에 적혀 있다:
#   한 번의 실행만 본다 · 조건부 쓰기는 M4 쌍에 없으면 안 걸린다 · 네트워크는 안 본다.
#
# · (이력) 🟥 **`writes:` 축은 검증 불가였다 — 그리고 그게 이 파일에서 실제로 터졌다.**
#   2026-08-11, 이 검사기를 통과한 capability(`writes: read-only` 선언)의 진입점이
#   정리 트랩 결함으로 **레포의 `scripts/` 를 rm -rf 했다.** M1(실행 가능)·M2(닫힌 enum)·
#   M3(mechanical)·M4(known-pair 통과)·M5(cwd) 를 **전부 통과한 채로** 그랬다.
#   등록 바는 «선언이 형식에 맞나 · 답 아는 쌍을 가르나» 를 보지, **«선언이 사실인가»**
#   를 보지 않는다. read-only 선언의 진위는 여기서 닫히지 않는다.
#   부분 처방(오늘 적용): 진입점 쪽 트랩 규율(정리 대상 변수 재대입 금지 + 임시경로 검문).
#   구조 처방(미구축): 샌드박스/읽기전용 마운트에서 M4 를 돌려 쓰기 시도를 관측하는 것.
#   ~~그 전까지 `writes: read-only` 는 등록자 주장이지 이 검사기의 판정이 아니다.~~
#   → 2026-08-16 부터 **판정이다**(M6). 단 UNVERIFIABLE 이 나오면 그때는 여전히 주장이다.
#
# 사용법
#   capability_registry_check.sh <capfile> [<capfile> ...]
#   capability_registry_check.sh --self-test
#
# exit code
#   0  REGISTRABLE      전 capfile 이 M1–M6 + 추가조항 통과
#   1  REJECTED         하나 이상 기준 미달 (등록 불가 — 그 표면은 dispatch 로 남는다)
#   10 HARNESS_ERROR    capfile 도달 불가·파손·검사기 자신의 전제 파손
#
set -o pipefail
set -f    # noglob — 선언 파일의 값은 데이터지 파일 패턴이 아니다 (relay_channel.sh 와 동일)

RC_OK=0; RC_REJECT=1; RC_HARNESS=10

# `summary`/`tags` 는 **추천 전용**(2026-08-16, cluster-wizard). 판정에는 안 쓰이고
# `cluster_capability_scan.sh recommend` 의 어휘 매칭에만 쓰인다. 닫힌 목록에 넣는 이유는
# 이 목록의 목적이 «오타 축 무음 드롭 방지» 이기 때문이다 — 안 넣으면 정당한 키가 SCHEMA 로 막힌다.
CLOSED_KEYS="id entry requires_cwd summary tags verdict_channel verdict_enum verdict_stdout_key upstream_argv echoes_upstream approval reversibility residency degrade tier_floor writes judge verdict_binding calibration_positive_args calibration_positive_expect calibration_negative_args calibration_negative_expect calibration_positive_stdin calibration_negative_stdin"

# 「안 돌았다」를 뜻하는 이름들 — 추가조항(§ⓑ.4 B1)이 요구하는 구분항
DIDNOTRUN_NAMES="DID_NOT_RUN DIDNOTRUN NOT_RUN NO_TARGET SKIPPED UNMEASURED NOT_CONFIGURED HARNESS_ERROR"

FAILED=0        # 전 파일 누적 (종료코드용)
FILE_FAILED=0   # 현재 capfile 한정 — 파일마다 초기화한다. 이게 없으면 앞 파일의 실패가
                # 뒤 파일의 M4 를 SKIPPED 로 만들어, 뒤 파일의 실제 결함이 안 보인다(보고 결함).
_fail() { printf '  ❌ %s — %s\n' "$1" "$2"; FAILED=1; FILE_FAILED=1; }
_ok()   { printf '  ✅ %s — %s\n' "$1" "$2"; }
_die()  { printf '❌ HARNESS_ERROR: %s\n' "$*" >&2; exit "$RC_HARNESS"; }

_parse() {
  CAP_id=""; CAP_entry=""; CAP_requires_cwd=""; CAP_verdict_channel=""
  CAP_verdict_enum=""; CAP_verdict_stdout_key=""; CAP_judge=""; CAP_writes=""
  CAP_cal_pos_args=""; CAP_cal_pos_expect=""; CAP_cal_neg_args=""; CAP_cal_neg_expect=""
  # 다중 capfile 실행에서 앞 파일의 선언이 뒤 파일로 새지 않게 한다 — 초기화 누락은
  # "뒤 파일이 선언하지 않은 stdin 으로 돌았다" 를 만들고, 그건 조용히 통과한다.
  CAP_cal_pos_stdin=""; CAP_cal_neg_stdin=""
  UNKNOWN_KEYS=""; CAP_requires_cwd_was_self=0
  # 「선언했는데 값이 비었다」와 「선언 자체가 없다」는 다른 사실이다 — 관측 범위 블록이
  # 둘을 구분해 적으려면 파서가 그 구분을 보존해야 한다(빈 문자열 하나로는 못 나눈다).
  CAP_cal_pos_args_seen=0; CAP_cal_neg_args_seen=0
  local line key val
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    case "$line" in *:*) ;; *) UNKNOWN_KEYS="$UNKNOWN_KEYS malformed-line"; continue ;; esac
    key="${line%%:*}"; val="${line#*:}"
    # POSIX 문자클래스만 쓴다. BSD sed 에서 `[ \t]` 는 탭이 아니라 «공백·역슬래시·문자 t»
    # 집합이라 `exit` 의 끝 t 가 잘려 `exi` 가 된다 — 이 검사기의 known-positive 레인이
    # 실제로 그걸 잡았다(2026-08-11, 자기 계기가 자기 버그를 적발한 사례).
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    val="$(printf '%s' "$val" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    case " $CLOSED_KEYS " in *" $key "*) ;; *) UNKNOWN_KEYS="$UNKNOWN_KEYS $key"; continue ;; esac
    case "$key" in
      id) CAP_id="$val" ;;                     entry) CAP_entry="$val" ;;
      requires_cwd) CAP_requires_cwd="$val" ;; verdict_channel) CAP_verdict_channel="$val" ;;
      verdict_enum) CAP_verdict_enum="$val" ;; verdict_stdout_key) CAP_verdict_stdout_key="$val" ;;
      judge) CAP_judge="$val" ;;               writes) CAP_writes="$val" ;;
      calibration_positive_args) CAP_cal_pos_args="$val"; CAP_cal_pos_args_seen=1 ;;
      calibration_positive_expect) CAP_cal_pos_expect="$val" ;;
      calibration_negative_args) CAP_cal_neg_args="$val"; CAP_cal_neg_args_seen=1 ;;
      calibration_positive_stdin) CAP_cal_pos_stdin="$val" ;;
      calibration_negative_stdin) CAP_cal_neg_stdin="$val" ;;
      calibration_negative_expect) CAP_cal_neg_expect="$val" ;;
    esac
  done < "$1"
}

_enum_name_of() {   # $1=exit code, $2=enum string → 이름 or ""
  local pair
  for pair in $2; do [ "${pair%%=*}" = "$1" ] && { printf '%s' "${pair#*=}"; return 0; }; done
  printf ''
}

# 🟥 capfile 은 **실행 신뢰경계**다 — M4 는 선언된 arm 을 «실제로 실행» 하는 것이 요점이므로,
#    검사기에 넘긴 capfile 은 그 자체로 "이 명령을 돌려도 된다"는 선언이다. 신뢰하지 않는
#    capfile 을 이 검사기에 넘기지 마라. 배포 전 보안 패스가 실증한 것: `entry: /usr/bin/touch`
#    + cal args 로 **REJECTED 판정이 나는 와중에도 부작용이 이미 발생**했다(판정 전에 arm 이 돈다).
#    아래 검문은 그 경계를 없애지 못한다 — 우발적 형태만 막는다.
_validate_arm_args() {   # $1=args → 셸 메타문자/상위경로 탈출을 거부
  case "$1" in
    *'|'*|*';'*|*'&'*|*'>'*|*'<'*|*'`'*|*'$('*|*$'\n'*)
      _fail "M4" "캘리브레이션 args 에 셸 메타문자가 있다(entry 와 같은 인젝션 표면): $1"; return 1 ;;
    *'../'*)
      _fail "M4" "캘리브레이션 args 가 상위 경로로 탈출한다: $1"; return 1 ;;
  esac
  return 0
}

# stdin 파일 검증 — args 와 같은 규율(메타문자·상위경로 탈출 거부) + 실재 확인.
_validate_arm_stdin() {   # $1=선언된 경로(빈 값 허용)
  [ -n "$1" ] || return 0
  case "$1" in
    *'|'*|*';'*|*'&'*|*'>'*|*'<'*|*'`'*|*'$('*|*$'\n'*)
      _fail "M4" "캘리브레이션 stdin 경로에 셸 메타문자가 있다: $1"; return 1 ;;
    *'../'*|/*)
      _fail "M4" "캘리브레이션 stdin 경로가 레포 밖을 가리킨다(상대경로만 허용): $1"; return 1 ;;
  esac
  [ -f "$CAP_requires_cwd/$1" ] || {
    _fail "M4" "캘리브레이션 stdin 파일이 없다: $1 (선언은 실재하는 픽스처를 가리켜야 한다)"; return 1; }
  return 0
}

_run_arm() {   # $1=extra args · $2=stdin 파일(선택) → ARM_RC / ARM_NAME. 파이프로 읽지 않는다(PIPE-VERDICT).
  # ── STDIN 은 항상 정의된다. 상속하지 않는다. ────────────────────────────────
  # 실측 2026-08-16 (자기선언 캠페인, the-bible arm): 이 함수는 `> /dev/null 2>&1` 로
  # stdout/stderr 만 막고 **stdin 은 검사기의 것을 물려받았다.** 결과가 두 가지로 나빴다.
  #   ⓐ **비결정**: 같은 선언이 터미널·파이프·CI 어디서 돌리느냐에 따라 arm 의 입력이 달라진다.
  #      판정 계기 안의 비결정은 그 자체로 결함이다 — 초록의 이유가 실행 환경에 달리게 된다.
  #   ⓑ **표현 불가**: 대상을 stdin 으로 받는 진입점(JSON 브리지 등)은 양·음 arm 이 **둘 다 빈
  #      입력**으로 돌아 같은 코드를 내고, 판별 실패로 REJECT 된다. 능력이 없어서가 아니라
  #      **스키마에 채널이 없어서** 막힌 것이다. 실제로 4방향으로 갈리는 게이트가 그렇게 막혔다.
  # ⇒ 선언된 파일이 있으면 그걸 먹이고, 없으면 **명시적으로 /dev/null** 을 먹인다. 후자가
  #    중요하다 — "선언 안 했으니 상속"이 아니라 "선언 안 했으면 빈 입력"이라고 **정해야** ⓐ 가 닫힌다.
  # 🟥 `set --` 는 위치 인자를 **덮어쓴다** — 그 뒤의 `$2` 는 stdin 파일이 아니라 entry 의 두 번째
  #    토큰이다. 초판이 그걸 밟았고, 그 결과 두 arm 이 **진입점 스크립트 자신을 stdin 으로 먹었다.**
  #    발견 경위가 이 수정의 요점이다: 그때 **음성 arm 만 빨개졌고 양성 arm 은 통과했다** — 스크립트
  #    소스에 마침 양성 픽스처와 같은 토큰이 들어 있어서다. 즉 **둘 다 틀린 입력을 먹었는데 하나가
  #    우연히 기대값과 맞았다.** 한쪽만 보고 있었으면 «양성은 되는데 음성이 이상하다»로 오진했다.
  #    ⇒ set -- 앞에서 이름 있는 변수로 잡는다.
  local _stdin="${2:-}"
  ( cd "$CAP_requires_cwd" 2>/dev/null || exit 127
    # shellcheck disable=SC2086  # argv 토큰 분리는 의도 (noglob 로 확장은 막혀 있다)
    set -- $CAP_entry $1
    if [ -n "$_stdin" ]; then "$@" < "$_stdin"; else "$@" < /dev/null; fi
  ) > /dev/null 2>&1
  ARM_RC=$?
  ARM_NAME="$(_enum_name_of "$ARM_RC" "$CAP_verdict_enum")"
}

# ── 관측 범위 블록 (2026-08-16) — «판정» 이 아니라 «채널» ────────────────────────
#
# 🟥 이 블록은 **exit code 에 아무 영향을 주지 않는다.** `_fail` 을 부르지 않고, 어떤 축도
#    새로 판정하지 않는다. 순수 정보 추가다 — 이 레포의 규율("기계는 비가역 경계와 채널에만,
#    판단은 안 짓는다")대로, 여기서 하는 일은 **무엇을 관측했고 무엇을 안 했는지 적는 것**뿐이다.
#
# 왜 필요한가 — 2026-08-16 실측 두 건이 같은 얼굴을 하고 있었다:
#   ① **M4 는 enum↔구현 일치를 구조적으로 안 본다.** 같은 stale 선언이 캘리브레이션 쌍에
#      따라 판정이 갈린다 — 쌍이 우연히 «선언 밖 exit» 을 밟으면 REJECTED, 구 enum 안에서만
#      갈리면 M1–M6 전부 통과. 즉 M4 는 «자기가 부른 두 번의 실행에서 본 것» 만 판정한다.
#   ② **M6 도 선언된 arm 만 관측한다.** `pmh-dev:merge-noop-check` 는 분기 입력에서 git 객체를
#      쓰지만(격리 클론 실측: `.git/objects` 2145 → 2146), 선언된 두 arm 이 그 경로를 안 지나므로
#      `writes: read-only` 로 **거짓 선언해도 통과한다**(실측 확인).
#
# 둘 다 «판정이 틀렸다» 가 아니라 **«판정의 관측 범위가 출력에 안 적혀 있다»** 이다. 그래서
# 고치는 방향은 새 판정 축이 아니라 이 블록이다: 읽는 사람이 초록을 «선언 전체가 참이다» 로
# 읽지 않게, 이 실행이 실제로 밟은 곳을 이름으로 적는다.
# ★ 「없음」도 **반드시 찍는다.** 침묵은 «관측되지 않은 값이 없다» 와 «계산하지 않았다» 를
#    구분하지 못한다 — 미측정을 0 으로 렌더하지 않는다([[feedback_not_found_is_not_zero_family]]).
_observation_scope() {
  printf '  ── 관측 범위 (이 판정이 «무엇을 안 봤는지») ──\n'
  printf '     M4/M6 는 **선언된 캘리브레이션 arm 의 실행에서 본 것만** 판정한다.\n'

  local _pa _na
  if [ "${CAP_cal_pos_args_seen:-0}" = "1" ]; then
    [ -n "$CAP_cal_pos_args" ] && _pa="$CAP_cal_pos_args" || _pa='<빈 값 — 인자 없이 실행>'
  else _pa='<미선언>'; fi
  if [ "${CAP_cal_neg_args_seen:-0}" = "1" ]; then
    [ -n "$CAP_cal_neg_args" ] && _na="$CAP_cal_neg_args" || _na='<빈 값 — 인자 없이 실행>'
  else _na='<미선언>'; fi
  printf '     실행된 arm: 양성 «%s» / 음성 «%s»\n' "$_pa" "$_na"

  if [ "${OBS_STATE:-none}" = "run" ]; then
    printf '     관측된 exit: 양성 rc=%s(%s)%s / 음성 rc=%s(%s)\n' \
      "$OBS_POS_RC" "${OBS_POS_NAME:-<enum 밖>}" \
      "$( [ "$OBS_POS_RC" = "$OBS_POS_RC2" ] && printf ' ×2회 동일' || printf ' ×2회째 rc=%s(갈림)' "$OBS_POS_RC2" )" \
      "$OBS_NEG_RC" "${OBS_NEG_NAME:-<enum 밖>}"
  else
    printf '     관측된 exit: 없음 — arm 을 실행하지 않았다(%s)\n' "${OBS_WHY:-사유 미기록}"
  fi

  # 미관측 enum = 선언 enum − 이 실행에서 실제로 나온 rc. **계산해서** 적는다.
  if [ -z "$CAP_verdict_enum" ]; then
    printf '     ⚠️ 선언된 enum 이 없어 「관측되지 않은 값」을 계산할 수 없다(미측정이지 0 이 아니다 — M2 가 이미 실패로 기록했다)\n'
  else
    local _pair _code _unobs="" _seenrc=""
    [ "${OBS_STATE:-none}" = "run" ] && _seenrc=" $OBS_POS_RC $OBS_POS_RC2 $OBS_NEG_RC "
    for _pair in $CAP_verdict_enum; do
      _code="${_pair%%=*}"
      case "$_seenrc" in *" $_code "*) ;; *) _unobs="$_unobs $_pair" ;; esac
    done
    if [ -n "$_unobs" ]; then
      printf '     ⚠️ 선언된 enum 중 이 실행에서 **관측되지 않은** 값:%s\n' "$_unobs"
    else
      printf '     · 선언된 enum 중 이 실행에서 관측되지 않은 값: 없음 (선언된 전 값이 이 실행에서 관측됐다)\n'
    fi
  fi
  printf '     ⚠️ 이 실행이 지나지 않은 코드 경로의 부작용(M6 의 `writes:` 축 포함)은 관측 대상이 아니다.\n'
}

_check_one() {
  local f="$1"
  [ -r "$f" ] || _die "capfile 도달 불가: $f"
  _parse "$f"
  FILE_FAILED=0
  # 관측 원장 — 「안 돌았다」가 디폴트다. 실행한 arm 만 이 값들을 채운다.
  OBS_STATE=none; OBS_WHY=""; OBS_POS_RC=""; OBS_POS_RC2=""; OBS_NEG_RC=""
  OBS_POS_NAME=""; OBS_NEG_NAME=""
  printf '\n── %s (%s)\n' "${CAP_id:-<id 미선언>}" "$f"

  [ -n "$UNKNOWN_KEYS" ] && _fail "SCHEMA" "닫힌 키 목록 밖:$UNKNOWN_KEYS (오타 축 무음드롭 방지 — 무시하지 않는다)"

  # ── `requires_cwd: SELF` 를 **M1 보다 먼저** 푼다 (2026-08-16 순서 수리) ────
  # 초판은 M5 에서 풀었는데, M1 이 그보다 먼저 돌면서 **상대 entry 를 현재 cwd 기준으로** 찾았다.
  # FH 로컬 등록부 시절엔 entry 가 늘 절대경로라 안 터졌다 — 하네스 자기 선언(상대 entry +
  # SELF)이 그 잠재 가정을 처음 실행에 노출시킨 것이다([[feedback_wiring_surfaces_hidden_failures]]).
  # 해석 실패는 여기서 조용히 넘기고 M5 가 판정한다(한 결함을 두 축에서 두 번 세지 않는다).
  if [ "$CAP_requires_cwd" = "SELF" ]; then
    local _sr; _sr="$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null)"
    [ -n "$_sr" ] && [ -d "$_sr" ] && CAP_requires_cwd="$_sr" && CAP_requires_cwd_was_self=1
  fi

  # ── M1 실행 가능한 진입점 ──────────────────────────────────────────────────
  local first second
  first="$(printf '%s' "$CAP_entry" | awk '{print $1}')"
  second="$(printf '%s' "$CAP_entry" | awk '{print $2}')"
  case "$CAP_entry" in
    *'|'*|*';'*|*'&&'*|*'>'*|*'`'*|*'$('*)
      _fail "M1" "entry 가 argv 가 아니라 셸 문자열이다(파이프/리다이렉트/치환 포함) — 인젝션 표면" ;;
    '') _fail "M1" "entry 미선언" ;;
    *)
      # 상대 경로는 **선언된 cwd 기준**으로도 본다. 선언은 자기 레포를 기준으로 쓰는 것이
      # 자연스럽고(그래야 이식된다), 검사기가 자기 cwd 로만 보면 정당한 선언을 못 읽는다.
      local _second_abs="$second"
      case "$second" in
        /*) ;;
        *) [ -n "$CAP_requires_cwd" ] && [ -r "$CAP_requires_cwd/$second" ] && _second_abs="$CAP_requires_cwd/$second" ;;
      esac
      if [ -x "$first" ] 2>/dev/null; then _ok "M1" "실행 가능: $first"
      elif command -v "$first" >/dev/null 2>&1 && [ -r "$_second_abs" ]; then
        _ok "M1" "선언된 인터프리터($first) + 읽을 수 있는 스크립트: $second"
      else _fail "M1" "entry 를 셸이 모델 없이 실행할 수 없다: $CAP_entry"; fi ;;
  esac

  # ── M2 닫힌 채널의 typed verdict + 추가조항(ran ≠ did-not-run) ─────────────
  case "$CAP_verdict_channel" in
    exit|stdout-key|both) ;;
    *) _fail "M2" "verdict_channel 이 {exit|stdout-key|both} 밖: '${CAP_verdict_channel}'" ;;
  esac
  case "$CAP_verdict_channel" in
    stdout-key|both) [ -n "$CAP_verdict_stdout_key" ] || _fail "M2" "channel 이 stdout-key 를 포함하는데 verdict_stdout_key 미선언" ;;
  esac
  if [ -z "$CAP_verdict_enum" ]; then
    _fail "M2" "verdict_enum 미선언 — 열린 채널은 등록 불가"
  else
    local pair bad=0 has_dnr=0 nm
    for pair in $CAP_verdict_enum; do
      case "$pair" in *=*) ;; *) bad=1 ;; esac
      nm="${pair#*=}"
      case " $DIDNOTRUN_NAMES " in *" $nm "*) has_dnr=1 ;; esac
    done
    [ "$bad" -eq 1 ] && _fail "M2" "verdict_enum 항목이 N=NAME 형식이 아니다: $CAP_verdict_enum"
    if [ "$has_dnr" -eq 1 ]; then _ok "M2" "typed enum + 「안 돌았다」 구분항: $CAP_verdict_enum"
    else _fail "M2+" "enum 에 「안 돌았다」를 뜻하는 값이 없다 ($CAP_verdict_enum) — PASS 가 no-op 과 구분 불가(§ⓑ.4 B1). PASS 는 적극 증거지 실패의 부재가 아니다"; fi
  fi

  # ── M3 모델 독립성 (선언 검사 + 명백한 모순만) ─────────────────────────────
  case "$CAP_judge" in
    mechanical)
      # 토큰의 BASENAME 으로 본다 — 문자열 전체 부분매칭이 아니다.
      #
      # 실측 2026-08-16 (자기선언 캠페인, qasp-dev arm 이 지목): 이 검사는 `*claude*` 처럼
      # entry **문자열 전체**에 부분매칭했다. 그래서 진입점이 모델을 전혀 안 부르는데도
      # **경로에 그 단어가 있다는 이유만으로** REJECT 났다 — 실제 사례는 스크래치패드 경로
      # `/private/tmp/claude-501/...` 였고, 경로만 바꾸니 같은 선언이 PASS 했다.
      # 구조적으로 더 나쁜 경우가 둘 있다: ⓐ 진입점이 `.claude/` 아래 사는 하네스는 **전부**
      # 막힌다(FH 자기 선언이 `.claude/capabilities/` 에 사는 걸 생각하면 남 얘기가 아니다)
      # ⓑ `scripts/claude_md_lint.sh` 처럼 이름에 그 단어가 든 순수 기계 스크립트도 막힌다.
      #
      # 과차단은 «안전한 방향»이 아니다 — 정본이 명시하듯 override 를 습관화시켜 같은 훅의
      # 다른 게이트까지 무장해제시킨다. 그리고 이 오탐은 **무음**이었다: 거부 사유가
      # "모델 CLI 를 부른다" 로 찍히므로, 읽는 사람은 자기 진입점을 의심하지 경로를 의심하지 않는다.
      #
      # 이 검사가 실제로 답할 수 있는 질문은 «entry 줄이 모델 CLI 를 **직접 이름으로** 부르는가»
      # 뿐이다. 래퍼 안에서 부르는 건 선언 층에서 원래 못 본다(M6 효과 프로브의 몫).
      # 그러니 각 토큰의 basename 을 보고, 확장자를 떼고, **정확히 그 이름일 때만** 막는다.
      _m3_bad=""
      for _tok in $CAP_entry; do
        _base="${_tok##*/}"; _base="${_base%.sh}"; _base="${_base%.js}"; _base="${_base%.py}"
        case "$_base" in
          claude|codex|gemini|copilot|ollama|llm) _m3_bad="$_base" ;;
        esac
      done
      if [ -n "$_m3_bad" ]; then
        _fail "M3" "judge: mechanical 선언인데 entry 가 모델 CLI 를 직접 부른다: $_m3_bad ($CAP_entry)"
      else
        _ok "M3" "judge: mechanical (entry 토큰에 모델 CLI 없음 — basename 기준)"
      fi ;;
    model) _ok "M3" "judge: model — 선언됨(합법). 조합에서 이 PASS 는 NON_CLEARING 이다" ;;
    '') _fail "M3" "judge 축 미선언 — 모델 개입 여부가 불명이면 조합이 계산될 수 없다" ;;
    *) _fail "M3" "judge 값이 {mechanical|model} 밖: '$CAP_judge'" ;;
  esac

  # ── M5 선언된 cwd (M4 를 그 자리에서 돌리므로 먼저) ────────────────────────
  case "$CAP_requires_cwd" in
    /*)
      # `SELF` 는 위(M1 앞)에서 이미 레포 루트로 풀렸다. 그 사실을 판정문에 남긴다 —
      # 안 남기면 독자가 선언 원문(`SELF`)과 검사 결과(절대경로)를 연결하지 못한다.
      if [ -d "$CAP_requires_cwd" ]; then
        if [ "${CAP_requires_cwd_was_self:-0}" = "1" ]; then
          _ok "M5" "requires_cwd: SELF → 선언을 품은 레포 루트: $CAP_requires_cwd"
        else
          _ok "M5" "requires_cwd 실재: $CAP_requires_cwd"
        fi
      else
        _fail "M5" "requires_cwd 가 절대경로지만 존재하지 않는다: $CAP_requires_cwd"
      fi ;;
    SELF)
      # ★`SELF` = «이 선언을 품은 레포» (2026-08-16 신설, 정체성 ①-(a) cluster-wizard).
      #
      # 왜 필요했나: 이 스키마는 원래 **FH 로컬 등록부**(gitignored)를 위한 것이라 절대경로가
      # 문제없었다. 그런데 (c) 를 닫으려면 선언이 **그 하네스 자신의 레포에 tracked 로** 살아야
      # 하고, 그 순간 절대경로는 두 가지로 깨진다:
      #   ① 이식 불가 — 다른 머신·다른 체크아웃에서 그 경로는 없다
      #   ② **공개표면 위반** — 운영자 홈 경로가 tracked 파일에 실린다
      # 그래서 «자기 자신» 을 가리키는 이식 가능한 표현이 필요했다.
      #
      # 해석은 **위치 가정이 아니라 git 레포 루트**다. `../../..` 같은 상대 오프셋으로 풀면
      # `.claude/capabilities/` 배치를 하드코딩하게 되고, 배치가 바뀌는 순간 조용히 엉뚱한
      # 디렉토리를 가리킨다. 레포 루트는 그 파일이 어디 놓이든 같은 답을 준다.
      local _self_root
      _self_root="$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null)"
      if [ -n "$_self_root" ] && [ -d "$_self_root" ]; then
        CAP_requires_cwd="$_self_root"
        _ok "M5" "requires_cwd: SELF → 선언을 품은 레포 루트로 해석: $_self_root"
      else
        # 🟥 fail-closed. git 레포 밖의 선언은 «자기» 가 무엇인지 정의되지 않는다 —
        #    추측해서 cwd 를 정하면 M4 가 **엉뚱한 트리에서** 진입점을 돌린다.
        _fail "M5" "requires_cwd: SELF 인데 이 선언이 git 레포 안에 없다 — «자기» 를 해석할 수 없다"
      fi ;;
    '') _fail "M5" "requires_cwd 미선언 — 콕핏이 어디서 부를지 알 수 없다" ;;
    *)  _fail "M5" "requires_cwd 가 절대경로도 SELF 도 아니다: $CAP_requires_cwd" ;;
  esac

  # ── M4 캘리브레이션 쌍 — 선언 + **실행** ──────────────────────────────────
  if [ -z "$CAP_cal_pos_expect" ] || [ -z "$CAP_cal_neg_expect" ]; then
    _fail "M4" "캘리브레이션 쌍 미선언(양성·음성 expect 둘 다 필요) — 답을 아는 케이스를 못 가르는 계기는 재는 게 아니다"
    OBS_WHY="캘리브레이션 쌍 미선언"
  # 🟥 위 «쌍 미선언» 검사는 **선언층**이므로 --declaration-only 에서도 돈다. 아래부터가
  #   **실행**이고, 그것만 건너뛴다. 둘을 한 덩어리로 스킵하면 «쌍을 아예 선언 안 한»
  #   capfile 이 선언층 검사를 통과해버린다 — 2026-08-17 실측에서 relay 가 삼킨
  #   `qasp_clean.cap` 이 정확히 그 값으로 걸렸다(M4 쌍 미선언).
  elif [ "${DECL_ONLY:-0}" -eq 1 ]; then
    printf '  ⏭  M4 — --declaration-only: 쌍 선언은 확인했고 **arm 은 실행하지 않았다**(SKIPPED, PASS 아님)\n'
    OBS_WHY="--declaration-only 로 arm 미실행"
  elif [ "$FILE_FAILED" -eq 1 ] && [ -z "${CRC_FORCE_M4:-}" ]; then
    printf '  ⏭  M4 — 앞선 축이 실패해 실행 생략(SKIPPED, PASS 아님)\n'
    OBS_WHY="앞선 축 실패로 M4 생략"
  elif ! _validate_arm_args "$CAP_cal_pos_args" || ! _validate_arm_args "$CAP_cal_neg_args" \
       || ! _validate_arm_stdin "${CAP_cal_pos_stdin:-}" || ! _validate_arm_stdin "${CAP_cal_neg_stdin:-}"; then
    printf '  ⏭  M4 — args 검문 실패로 arm 을 실행하지 않았다(SKIPPED, PASS 아님)\n'
    OBS_WHY="args 검문 실패"
  else
    local pos_name neg_name pos_rc neg_rc pos_name2 pos_rc2
    _run_arm "$CAP_cal_pos_args" "${CAP_cal_pos_stdin:-}"; pos_rc="$ARM_RC"; pos_name="$ARM_NAME"
    [ "$pos_rc" = "127" ] && _fail "M4" "requires_cwd 로 진입 실패 — arm 을 돌릴 수 없다"
    _run_arm "$CAP_cal_pos_args" "${CAP_cal_pos_stdin:-}"; pos_name2="$ARM_NAME"; pos_rc2="$ARM_RC"   # reps=2 (M3 부분 방어)
    _run_arm "$CAP_cal_neg_args" "${CAP_cal_neg_stdin:-}"; neg_rc="$ARM_RC"; neg_name="$ARM_NAME"
    # 관측 원장에 남긴다 — 판정과 무관하게, 이 실행이 **실제로 밟은 exit** 만 적는다.
    OBS_STATE=run; OBS_POS_RC="$pos_rc"; OBS_POS_RC2="$pos_rc2"; OBS_NEG_RC="$neg_rc"
    OBS_POS_NAME="$pos_name"; OBS_NEG_NAME="$neg_name"

    if [ -z "$pos_name" ]; then
      _fail "M4" "양성 arm 의 exit $pos_rc 가 선언된 enum 밖 — enum 밖 값은 HARNESS_ERROR 이지 PASS 가 아니다"
    elif [ "$pos_name" != "$CAP_cal_pos_expect" ]; then
      _fail "M4" "양성 arm 이 선언과 다르다: expect=$CAP_cal_pos_expect actual=$pos_name (exit $pos_rc)"
    elif [ "$pos_name" != "$pos_name2" ]; then
      _fail "M4/M3" "같은 양성 arm 2회에 verdict 가 갈렸다: $pos_name vs $pos_name2 — 모델 독립성 미충족"
    elif [ -z "$neg_name" ]; then
      _fail "M4" "음성 arm 의 exit $neg_rc 가 선언된 enum 밖"
    elif [ "$neg_name" != "$CAP_cal_neg_expect" ]; then
      _fail "M4" "음성 arm 이 선언과 다르다: expect=$CAP_cal_neg_expect actual=$neg_name (exit $neg_rc)"
    elif [ "$pos_name" = "$neg_name" ]; then
      _fail "M4" "양성·음성이 같은 verdict($pos_name) — 답을 아는 두 케이스를 못 가른다"
    else
      _ok "M4" "known-pair 실행 통과: 양성→$pos_name(x2 일치) · 음성→$neg_name"
    fi
  fi

  # ── M6 선언 진위 — `writes:` 를 **관측**한다 (2026-08-16) ──────────────────
  #
  # 이 파일 헤더가 «구조 처방(미구축): 샌드박스/읽기전용 마운트에서 M4 를 돌려 쓰기 시도를
  # 관측하는 것» 이라고 적어놓은 자리다. `capability_effect_probe.sh` 가 그 처방이고,
  # 여기서 **부른다** — 도구가 존재하는 것과 게이트가 그것을 부르는 것은 다르다.
  #
  # ★UNVERIFIABLE 은 **PASS 가 아니다.** 등록을 막지는 않되(과차단이 우회를 훈련시킨다)
  #   «못 쟀다» 를 출력에 남긴다. 미측정을 0 으로 렌더하지 않는다.
  if [ -z "$CAP_writes" ]; then
    :   # writes 미선언은 M2 가 이미 처리한다
  elif [ "${DECL_ONLY:-0}" -eq 1 ]; then
    # 🟥 M6 는 통째로 실행 기반이다(effect probe 가 entry 를 실제로 돌린다). 선언층에
    #   남길 것이 없으므로 전부 건너뛴다 — 그래서 이 모드의 출력이 REGISTRABLE 이 아니라
    #   DECLARATION_VALID 다. `writes:` 의 진위는 이 모드에서 **등록자 주장**으로 남는다.
    printf '  ⏭  M6 — --declaration-only: 진입점을 실행하지 않았다. `writes:` 는 미검증 주장이다(SKIPPED, PASS 아님)\n'
  elif [ "$FILE_FAILED" -eq 1 ] && [ -z "${CRC_FORCE_M6:-}" ]; then
    # ★앞선 축이 실패했으면 **진입점을 실행하지 않는다**(2026-08-16 cross-family 지목).
    #   M6 는 `eval` 로 entry 를 돌리므로, «등록 거부될 capfile» 의 진입점을 굳이 실행하는
    #   것은 그 자체가 위험 노출이다. M4 가 이미 같은 가드를 갖고 있었고 M6 만 없었다.
    printf '  ⏭  M6 — 앞선 축이 실패해 실행 생략(SKIPPED, PASS 아님)\n'
  else
    # SYMLINK-RESOLVED, not `${0%/*}` (fixed 2026-08-16, reproduced on both sides).
    # `${0%/*}` yields the directory of the NAME USED TO INVOKE, so a symlink to this script made
    # the probe lookup land next to the LINK — where nothing lives — and M6 then fail-closed with
    # "probe 부재" about a probe that exists. A gate that blames a missing file for its own path bug
    # is worse than one that simply fails: it sends the reader to the wrong repair.
    # `BASH_SOURCE[0]` is the real file even when invoked through a link; the loop then walks any
    # remaining links in the path. `readlink -f` is deliberately not used — it is GNU-only and this
    # ships to macOS (BSD `readlink` has no `-f`).
    # ★반복 상한. 보안 패스 [B] 가 «순환 심링크에서 영원히 돈다» 로 지목했고, 캡을 넣은 뒤
    #   **실제 순환 쌍으로 재보니 그 시나리오는 도달 불가였다**: `a.sh → b.sh → a.sh` 는 OS 가
    #   ELOOP 로 먼저 막아 bash 가 rc=126 으로 죽는다 — 이 루프는 시작조차 안 한다.
    #   지적은 **루프 본문을 격리해서** 돌린 결과였다(부품 테스트지 도달성 테스트가 아니다).
    #   그래도 캡은 남긴다: 값이 싸고, `$0` 가 파일이 아닌 경로로 들어오는 미래 호출 형태까지
    #   내가 열거하지 못하기 때문이다. **다만 «무한루프를 고쳤다» 고 주장하지 않는다.**
    local _src="${BASH_SOURCE[0]:-$0}" _dir _hops=0
    while [ -L "$_src" ]; do
      _hops=$((_hops+1))
      if [ "$_hops" -gt 40 ]; then
        _fail "M6" "심링크가 40회를 넘어간다 — 순환으로 본다. 프로브 경로를 못 정한다"
        _observation_scope   # 이 이른 return 에서도 관측 범위는 찍힌다(조건부로 찍히면 채널이 아니다)
        return 0   # _fail 이 이미 기록했다. 판정 불가를 통과로 렌더하지 않는다
      fi
      _dir=$(cd -P "$(dirname "$_src")" >/dev/null 2>&1 && pwd) || break
      _src=$(readlink "$_src")
      case "$_src" in /*) ;; *) _src="$_dir/$_src" ;; esac
    done
    _dir=$(cd -P "$(dirname "$_src")" >/dev/null 2>&1 && pwd) || _dir="${0%/*}"
    local _probe="$_dir/capability_effect_probe.sh"
    if [ ! -r "$_probe" ]; then
      # 🟥 **fail-CLOSED.** 등록은 «이후 자동 호출» 로 이어지는 비가역 표면이다
      #   (CLAUDE.md §Irreversibility Surface-Class Degrade Invariant).
      #   계기가 없으면 «못 쟀다» 이지 «괜찮다» 가 아니고, 여기서 통과시키면 이 축이
      #   존재하기 전과 같은 상태가 된다.
      _fail "M6" "effect probe 부재($_probe) — 선언 진위를 **못 쟀다**. 비가역 표면이므로 fail-closed"
    else
      local _pout _prc
      _pout=$(bash "$_probe" "$f" 2>&1); _prc=$?
      case "$_prc" in
        0) _ok "M6" "선언 진위 관측 통과: writes=$CAP_writes (양 arm 샌드박스 실행에서 위반 없음)" ;;
        1) _fail "M6" "선언 진위 **위반**: $(printf '%s' "$_pout" | head -1)" ;;
        3) _fail "M6" "관측 불가(UNVERIFIABLE) — 등록은 이후 자동 호출로 이어지므로 **미측정을 통과로 렌더하지 않는다**: $(printf '%s' "$_pout" | head -1)" ;;
        *) _fail "M6" "프로브 하네스 오류 rc=$_prc — 판정 아님이므로 fail-closed" ;;
      esac
    fi
  fi

  # ★무조건 찍는다 — PASS 든 REJECTED 든, arm 을 돌렸든 안 돌렸든. 관측 범위가 조건부로
  #   찍히면 그건 채널이 아니라 또 하나의 판정이 된다.
  _observation_scope
}

# ── self-test (known-pair: 통과해야 할 선언 1 · 막혀야 할 선언 6) ─────────────
_self_test() {
  local T; T="$(mktemp -d)"; local pass=0 fail=0
  _t() {
    local o; o="$(bash "$0" "$3" 2>&1)"; local r=$?
    if [ "$r" = "$2" ]; then pass=$((pass+1)); printf '  ✅ %-34s rc=%s\n' "$1" "$r"
    else fail=$((fail+1)); printf '  ❌ %-34s rc=%s (기대 %s)\n%s\n' "$1" "$r" "$2" "$o"; fi
  }
  printf 'capability_registry_check --self-test\n'
  cat > "$T/good.cap" <<EOF
id: selftest:true-false
entry: bash $T/probe.sh
requires_cwd: $T
verdict_channel: exit
verdict_enum: 0=PASS 1=FAIL 3=DID_NOT_RUN
approval: auto
reversibility: reversible
residency: public
degrade: fail-closed
tier_floor: none
writes: read-only
judge: mechanical
verdict_binding: FAIL
calibration_positive_args: ok
calibration_positive_expect: PASS
calibration_negative_args: no
calibration_negative_expect: FAIL
EOF
  printf '#!/bin/sh\n[ "$1" = ok ] && exit 0\nexit 1\n' > "$T/probe.sh"
  _t "known-positive: 온전한 선언" 0 "$T/good.cap"
  sed 's/^verdict_enum: .*/verdict_enum: 0=PASS 1=FAIL/' "$T/good.cap" > "$T/no_dnr.cap"
  _t "추가조항: 「안 돌았다」 없음" 1 "$T/no_dnr.cap"
  sed 's/^calibration_negative_expect: .*/calibration_negative_expect: PASS/' "$T/good.cap" > "$T/badpair.cap"
  _t "M4: 음성이 선언과 불일치" 1 "$T/badpair.cap"
  grep -v '^calibration_' "$T/good.cap" > "$T/nocal.cap"
  _t "M4: 캘리브레이션 쌍 미선언" 1 "$T/nocal.cap"
  sed 's/^judge: .*/degrad: fail-closed/' "$T/good.cap" > "$T/typo.cap"
  _t "D3: 오타 축은 무시 아닌 실패" 1 "$T/typo.cap"
  sed "s|^entry: .*|entry: bash $T/probe.sh \| grep x|" "$T/good.cap" > "$T/shellstr.cap"
  _t "M1: entry 가 셸 문자열" 1 "$T/shellstr.cap"
  sed 's|^requires_cwd: .*|requires_cwd: relative/path|' "$T/good.cap" > "$T/relcwd.cap"
  _t "M5: requires_cwd 상대경로" 1 "$T/relcwd.cap"

  # ── M5 `SELF` (2026-08-16) — 하네스가 **자기 레포에 tracked 로** 선언할 수 있게 하는 값 ──
  #   known-pair 를 **양쪽 다** 세운다. 양성만 세우면 「SELF 를 그냥 통과시킨다」와
  #   「SELF 를 옳게 해석한다」가 구분되지 않는다.
  local SR="$T/selfrepo"
  mkdir -p "$SR/.claude/capabilities"
  ( cd "$SR" && git init -q . && git config user.email t@t && git config user.name t \
    && echo x > seed.txt && git add seed.txt && git commit -qm init ) >/dev/null 2>&1
  cp "$T/probe.sh" "$SR/probe.sh" 2>/dev/null || true
  sed -e 's|^requires_cwd: .*|requires_cwd: SELF|' \
      -e "s|^entry: .*|entry: bash $SR/probe.sh|" "$T/good.cap" > "$SR/.claude/capabilities/self.cap"
  _t "M5: SELF 는 레포 루트로 해석된다" 0 "$SR/.claude/capabilities/self.cap"

  # known-negative(=fail-closed 방향): git 레포 **밖**의 SELF 는 해석 불가여야 한다.
  # 이 레인이 없으면 「SELF 면 무조건 통과」가 되고, 그건 M5 를 없앤 것과 같다.
  sed -e 's|^requires_cwd: .*|requires_cwd: SELF|' "$T/good.cap" > "$T/self_outside.cap"
  _t "M5: git 밖의 SELF 는 fail-closed" 1 "$T/self_outside.cap"

  # ── M6: 선언 진위 (2026-08-16) — 2026-08-11 실사고 형태를 그대로 재현한다 ──
  #   `writes: read-only` 를 선언하고 진입점이 `rm -rf scripts` 를 한다. 그날 이 검사기는
  #   M1–M5 를 전부 통과시켰다. 이제 M6 가 막는다.
  # ★픽스처가 **M1~M5 를 통과해야** 이 레인이 M6 를 잰다(2026-08-16 cross-family 지목).
  #   초판은 `bash -c 'rm -rf scripts'` 였는데 그건 M1 에서 이미 걸린다(`-c` 는 읽을 수 있는
  #   스크립트가 아니다) — 즉 M6 가 없어도 REJECTED 라 **자기충족**이었다.
  cat > "$T/liar_entry.sh" <<'LIARSH'
#!/usr/bin/env bash
# 2026-08-11 실사고 형태: read-only 를 선언하고 실제로는 파괴한다.
case "${1:-}" in
  --known-negative) rm -rf scripts; exit 0 ;;
  --known-positive) rm -rf scripts; exit 1 ;;
  *) exit 0 ;;
esac
LIARSH
  chmod +x "$T/liar_entry.sh"
  cat > "$T/liar.cap" <<LIAR
id: test:liar-rmrf
entry: bash $T/liar_entry.sh
requires_cwd: $T
verdict_channel: exit
verdict_enum: 0=CLEAN 1=LEAK 3=DID_NOT_RUN
approval: auto
reversibility: reversible
residency: public
degrade: fail-closed
tier_floor: none
writes: read-only
judge: mechanical
verdict_binding: LEAK
calibration_positive_args: --known-negative
calibration_positive_expect: CLEAN
calibration_negative_args: --known-positive
calibration_negative_expect: LEAK
LIAR
  _t "M6: read-only 선언인데 쓴다(2026-08-11 사고 형태)" 1 "$T/liar.cap"
  # ★rc 만 보면 **어느 축이 막았는지** 모른다 — M6 를 재려면 M6 가 실패했다고 말해야 한다.
  CRC_DEBUG_OUT=$(bash "$0" "$T/liar.cap" 2>&1)
  [ -n "${CRC_DEBUG:-}" ] && printf '%s\n' "$CRC_DEBUG_OUT" >&2
  if printf '%s' "$CRC_DEBUG_OUT" | grep -q '❌ M6'; then
    pass=$((pass+1)); printf '  ✅ %-34s (M6 가 차단자임을 확인)\n' "M6: 차단 귀속"
  else
    fail=$((fail+1)); printf '  ❌ %-34s — rc 는 1 인데 M6 가 막은 게 아니다(다른 축이 먼저 걸렸다)\n' "M6: 차단 귀속"
  fi
  # ── 관측 범위 블록 (2026-08-16) — 「무엇을 안 봤는지」가 출력에 남는가 ───────────
  #   이 레인들은 **판정을 재지 않는다**(rc 는 위 레인들이 이미 고정한다). 재는 것은
  #   «채널이 켜져 있나 · 계산이 맞나 · 조건부로 꺼지지 않나» 셋이다.
  _tg() {   # $1=이름 $2=기대 rc $3=capfile $4=반드시 포함할 문자열
    local o r hit; o="$(bash "$0" "$3" 2>&1)"; r=$?
    if printf '%s' "$o" | grep -qF "$4"; then hit=1; else hit=0; fi
    if [ "$r" = "$2" ] && [ "$hit" = "1" ]; then
      pass=$((pass+1)); printf '  ✅ %-34s rc=%s\n' "$1" "$r"
    else
      fail=$((fail+1))
      printf '  ❌ %-34s rc=%s (기대 %s) · 부분문자열 «%s» %s\n%s\n' \
        "$1" "$r" "$2" "$4" "$( [ "$hit" = 1 ] && printf 있음 || printf 없음 )" "$o"
    fi
  }

  # ⓐ 부분 관측: 선언 enum 4값 · 이 실행이 밟는 건 2값 → **나머지 2값을 이름으로** 적어야 한다.
  #    (`good.cap` 의 probe 는 ok→0 / 그 외→1 만 낸다. 3·7 은 이 실행이 갈 수 없는 값이다.)
  sed 's/^verdict_enum: .*/verdict_enum: 0=PASS 1=FAIL 3=DID_NOT_RUN 7=NO_TARGET/' \
      "$T/good.cap" > "$T/obs_partial.cap"
  _tg "관측범위: 미관측 enum 을 이름으로" 0 "$T/obs_partial.cap" \
      "관측되지 않은** 값: 3=DID_NOT_RUN 7=NO_TARGET"

  # ⓑ 🟥**컨트롤** — 전부 관측되면 「없음」을 찍어야 한다. 이게 없으면 「늘 경고하는 계기」와
  #    「실제로 계산하는 계기」가 구분되지 않는다(경고만 하는 계기는 판별력이 0 이다).
  #    선언 전 값이 관측되려면 음성 arm 이 「안 돌았다」 코드로 떨어져야 한다(M2+ 가 그 값을
  #    요구하므로) — 그래서 전용 probe 를 쓴다.
  printf '#!/bin/sh\n[ "$1" = ok ] && exit 0\nexit 3\n' > "$T/probe_allobs.sh"
  sed -e 's/^verdict_enum: .*/verdict_enum: 0=PASS 3=DID_NOT_RUN/' \
      -e "s|^entry: .*|entry: bash $T/probe_allobs.sh|" \
      -e 's/^calibration_negative_expect: .*/calibration_negative_expect: DID_NOT_RUN/' \
      "$T/good.cap" > "$T/obs_all.cap"
  _tg "관측범위: 전부 관측되면 「없음」" 0 "$T/obs_all.cap" \
      "관측되지 않은 값: 없음"

  # ⓒ REJECTED 에서도 블록이 찍힌다 + arm 을 안 돌렸다는 사실과 사유가 적힌다.
  #    (`nocal.cap` = 캘리브레이션 키 전체 제거 → args 는 「미선언」, 관측 exit 은 「없음」.)
  _tg "관측범위: REJECTED 에서도 찍힌다" 1 "$T/nocal.cap" \
      "관측된 exit: 없음 — arm 을 실행하지 않았다(캘리브레이션 쌍 미선언)"
  _tg "관측범위: 미선언 args 를 미선언이라 적는다" 1 "$T/nocal.cap" \
      "실행된 arm: 양성 «<미선언>» / 음성 «<미선언>»"

  # ── D1–D4 --declaration-only (2026-08-17, relay 배선용) ─────────────────────
  # 이 모드는 `relay_channel.sh` 가 **호출 시점**에 부르는 경로다. 전량 호출하면 M4/M6 이
  # 매 relay 실행마다 노드를 다시 돌리므로 선언층만 본다 — 그 대가를 레인으로 고정한다.
  local dout drc
  # D1 선언층 결함은 이 모드에서도 잡힌다(잡히는 게 요점이다 — 안 잡히면 배선이 무의미)
  dout=$(bash "$0" --declaration-only "$T/nocal.cap" 2>&1); drc=$?
  if [ "$drc" -eq 1 ]; then pass=$((pass+1)); printf '  ✅ %-40s\n' "D1: 선언층 결함은 --declaration-only 도 잡는다"
  else fail=$((fail+1)); printf '  ❌ %-40s — rc=%s (기대 1)\n' "D1: 선언층 결함" "$drc"; fi
  # D2 ★컨트롤 — 정상 선언은 통과한다. D1 만 있으면 「전부 막는 모드」와 구별이 안 된다
  dout=$(bash "$0" --declaration-only "$T/good.cap" 2>&1); drc=$?
  if [ "$drc" -eq 0 ]; then pass=$((pass+1)); printf '  ✅ %-40s\n' "D2: 컨트롤 — 정상 선언은 통과(과차단 아님)"
  else fail=$((fail+1)); printf '  ❌ %-40s — rc=%s (기대 0)\n' "D2: 컨트롤" "$drc"; fi
  # D3 🟥 어휘 분리 — 부분 검사를 REGISTRABLE 로 찍으면 안 된다. 그게 이 모드의 최대 위험이다
  case "$dout" in
    *DECLARATION_VALID*) pass=$((pass+1)); printf '  ✅ %-40s\n' "D3: REGISTRABLE 이 아니라 DECLARATION_VALID" ;;
    *) fail=$((fail+1)); printf '  ❌ %-40s — 부분 검사가 전체 통과 어휘로 찍힌다\n' "D3: 어휘 분리" ;;
  esac
  # D4 M4/M6 을 «안 돌렸다» 고 말한다. 침묵하면 읽는 사람이 PASS 로 읽는다(미측정≠0)
  case "$dout" in
    *"M4 — --declaration-only"*|*"M6 — --declaration-only"*)
      pass=$((pass+1)); printf '  ✅ %-40s\n' "D4: 안 돌린 축을 안 돌렸다고 적는다" ;;
    *) fail=$((fail+1)); printf '  ❌ %-40s — 생략을 침묵으로 처리한다\n' "D4: 미실행 표기" ;;
  esac

  printf '\n  통과 %d · 실패 %d\n' "$pass" "$fail"
  rm -rf "$T"
  [ "$fail" -eq 0 ] || return 1
  return 0
}

[ "${1:-}" = "--self-test" ] && { _self_test; exit $?; }

# ── --declaration-only (2026-08-17) ───────────────────────────────────────────
# 🟥 **왜 이 모드가 있나 — 그리고 왜 「가벼운 등록검사」가 아닌가.**
# `relay_channel.sh` 가 호출 시점에 이 검사기를 부르게 배선하면서 필요해졌다. 그냥 전량
# 호출하면 **매 relay 실행마다 M4(known-pair arm 을 실제로 돌린다)와 M6(effect probe 가
# entry 를 `eval` 로 실행한다)가 재실행된다** — 호출 한 번이 노드를 여러 번 더 돌리고,
# M6 는 그 자체가 위험 노출이라 이 파일이 이미 «등록 거부될 capfile 의 진입점을 굳이
# 실행하지 않는다» 는 가드를 갖고 있다. 그 판단을 호출 경로에도 그대로 적용한다.
#
# **대안을 안 고른 이유**: relay 안에 선언 검사를 새로 쓰는 것. 그러면 같은 스키마에 대해
# 계기가 셋이 되고, 이 레포는 그 divergent-normalizer 함정을 **이미 두 번 밟았다**
# (relay 헤더 §META_KEYS — 2026-08-11 · 2026-08-16, 둘 다 «등록되는데 부를 수 없는» 선언).
# 스키마의 단일 소스는 이 파일이어야 한다.
#
# 🟥 **이 모드는 REGISTRABLE 을 말하지 않는다.** 출력 어휘를 일부러 분리한다 —
# `DECLARATION_VALID` 는 «선언층이 유효하다» 이지 «등록 가능하다» 가 아니다. 둘을 같은
# 단어로 찍으면 부분 검사가 전체 통과로 읽힌다(`[[feedback_not_found_is_not_zero_family]]`).
DECL_ONLY=0
if [ "${1:-}" = "--declaration-only" ]; then DECL_ONLY=1; shift; fi
export DECL_ONLY

[ $# -ge 1 ] || _die "capfile 인자가 없다. 사용법: $0 [--declaration-only] <capfile> [<capfile>...]"

if [ "$DECL_ONLY" -eq 1 ]; then
  printf 'capability_registry_check — **선언층만** (M1·M2·M3·M5 + 추가조항 · M4/M6 미실행)\n'
else
  printf 'capability_registry_check — M1–M6 + 추가조항 (등록 시점)\n'
fi
for f in "$@"; do _check_one "$f"; done

printf '\n'
if [ "$FAILED" -eq 0 ]; then
  if [ "$DECL_ONLY" -eq 1 ]; then
    printf '✅ DECLARATION_VALID — 선언층 통과. 🟥 REGISTRABLE 이 아니다: M4(known-pair 실행)·M6(선언 진위)는 **안 돌렸다**\n'
  else
    printf '✅ REGISTRABLE — 전 capfile 이 M1–M6 + 추가조항 통과\n'
  fi
  exit "$RC_OK"
else
  printf '❌ REJECTED — 등록 불가. 그 표면은 오늘 있던 자리(dispatch 엔트리)에 그대로 남는다 — 손실이 아니다\n'
  exit "$RC_REJECT"
fi
