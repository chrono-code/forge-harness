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

CLOSED_KEYS="id entry requires_cwd verdict_channel verdict_enum verdict_stdout_key upstream_argv echoes_upstream approval reversibility residency degrade tier_floor writes judge verdict_binding calibration_positive_args calibration_positive_expect calibration_negative_args calibration_negative_expect"

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
  UNKNOWN_KEYS=""
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
      calibration_positive_args) CAP_cal_pos_args="$val" ;;
      calibration_positive_expect) CAP_cal_pos_expect="$val" ;;
      calibration_negative_args) CAP_cal_neg_args="$val" ;;
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

_run_arm() {   # $1=extra args → ARM_RC / ARM_NAME. 파이프로 읽지 않는다(PIPE-VERDICT).
  ( cd "$CAP_requires_cwd" 2>/dev/null || exit 127
    # shellcheck disable=SC2086  # argv 토큰 분리는 의도 (noglob 로 확장은 막혀 있다)
    set -- $CAP_entry $1; "$@" ) > /dev/null 2>&1
  ARM_RC=$?
  ARM_NAME="$(_enum_name_of "$ARM_RC" "$CAP_verdict_enum")"
}

_check_one() {
  local f="$1"
  [ -r "$f" ] || _die "capfile 도달 불가: $f"
  _parse "$f"
  FILE_FAILED=0
  printf '\n── %s (%s)\n' "${CAP_id:-<id 미선언>}" "$f"

  [ -n "$UNKNOWN_KEYS" ] && _fail "SCHEMA" "닫힌 키 목록 밖:$UNKNOWN_KEYS (오타 축 무음드롭 방지 — 무시하지 않는다)"

  # ── M1 실행 가능한 진입점 ──────────────────────────────────────────────────
  local first second
  first="$(printf '%s' "$CAP_entry" | awk '{print $1}')"
  second="$(printf '%s' "$CAP_entry" | awk '{print $2}')"
  case "$CAP_entry" in
    *'|'*|*';'*|*'&&'*|*'>'*|*'`'*|*'$('*)
      _fail "M1" "entry 가 argv 가 아니라 셸 문자열이다(파이프/리다이렉트/치환 포함) — 인젝션 표면" ;;
    '') _fail "M1" "entry 미선언" ;;
    *)
      if [ -x "$first" ] 2>/dev/null; then _ok "M1" "실행 가능: $first"
      elif command -v "$first" >/dev/null 2>&1 && [ -r "$second" ]; then
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
      case "$CAP_entry" in
        *claude*|*codex*|*gemini*|*copilot*|*ollama*|*llm*)
          _fail "M3" "judge: mechanical 선언인데 entry 가 모델 CLI 를 부른다: $CAP_entry" ;;
        *) _ok "M3" "judge: mechanical (모델 미개입 선언)" ;;
      esac ;;
    model) _ok "M3" "judge: model — 선언됨(합법). 조합에서 이 PASS 는 NON_CLEARING 이다" ;;
    '') _fail "M3" "judge 축 미선언 — 모델 개입 여부가 불명이면 조합이 계산될 수 없다" ;;
    *) _fail "M3" "judge 값이 {mechanical|model} 밖: '$CAP_judge'" ;;
  esac

  # ── M5 선언된 cwd (M4 를 그 자리에서 돌리므로 먼저) ────────────────────────
  case "$CAP_requires_cwd" in
    /*) [ -d "$CAP_requires_cwd" ] && _ok "M5" "requires_cwd 실재: $CAP_requires_cwd" \
          || _fail "M5" "requires_cwd 가 절대경로지만 존재하지 않는다: $CAP_requires_cwd" ;;
    '') _fail "M5" "requires_cwd 미선언 — 콕핏이 어디서 부를지 알 수 없다" ;;
    *)  _fail "M5" "requires_cwd 가 절대경로가 아니다: $CAP_requires_cwd" ;;
  esac

  # ── M4 캘리브레이션 쌍 — 선언 + **실행** ──────────────────────────────────
  if [ -z "$CAP_cal_pos_expect" ] || [ -z "$CAP_cal_neg_expect" ]; then
    _fail "M4" "캘리브레이션 쌍 미선언(양성·음성 expect 둘 다 필요) — 답을 아는 케이스를 못 가르는 계기는 재는 게 아니다"
  elif [ "$FILE_FAILED" -eq 1 ] && [ -z "${CRC_FORCE_M4:-}" ]; then
    printf '  ⏭  M4 — 앞선 축이 실패해 실행 생략(SKIPPED, PASS 아님)\n'
  elif ! _validate_arm_args "$CAP_cal_pos_args" || ! _validate_arm_args "$CAP_cal_neg_args"; then
    printf '  ⏭  M4 — args 검문 실패로 arm 을 실행하지 않았다(SKIPPED, PASS 아님)\n'
  else
    local pos_name neg_name pos_rc neg_rc pos_name2
    _run_arm "$CAP_cal_pos_args"; pos_rc="$ARM_RC"; pos_name="$ARM_NAME"
    [ "$pos_rc" = "127" ] && _fail "M4" "requires_cwd 로 진입 실패 — arm 을 돌릴 수 없다"
    _run_arm "$CAP_cal_pos_args"; pos_name2="$ARM_NAME"     # reps=2 (M3 부분 방어)
    _run_arm "$CAP_cal_neg_args"; neg_rc="$ARM_RC"; neg_name="$ARM_NAME"

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
  printf '\n  통과 %d · 실패 %d\n' "$pass" "$fail"
  rm -rf "$T"
  [ "$fail" -eq 0 ] || return 1
  return 0
}

[ "${1:-}" = "--self-test" ] && { _self_test; exit $?; }
[ $# -ge 1 ] || _die "capfile 인자가 없다. 사용법: $0 <capfile> [<capfile>...]"

printf 'capability_registry_check — M1–M5 + 추가조항 (등록 시점)\n'
for f in "$@"; do _check_one "$f"; done

printf '\n'
if [ "$FAILED" -eq 0 ]; then
  printf '✅ REGISTRABLE — 전 capfile 이 M1–M5 + 추가조항 통과\n'; exit "$RC_OK"
else
  printf '❌ REJECTED — 등록 불가. 그 표면은 오늘 있던 자리(dispatch 엔트리)에 그대로 남는다 — 손실이 아니다\n'
  exit "$RC_REJECT"
fi
