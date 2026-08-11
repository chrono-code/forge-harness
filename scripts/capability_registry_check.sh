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
# · 🟥 **`writes:` 축은 검증 불가 — 그리고 그게 이 파일에서 실제로 터졌다.**
#   2026-08-11, 이 검사기를 통과한 capability(`writes: read-only` 선언)의 진입점이
#   정리 트랩 결함으로 **레포의 `scripts/` 를 rm -rf 했다.** M1(실행 가능)·M2(닫힌 enum)·
#   M3(mechanical)·M4(known-pair 통과)·M5(cwd) 를 **전부 통과한 채로** 그랬다.
#   등록 바는 «선언이 형식에 맞나 · 답 아는 쌍을 가르나» 를 보지, **«선언이 사실인가»**
#   를 보지 않는다. read-only 선언의 진위는 여기서 닫히지 않는다.
#   부분 처방(오늘 적용): 진입점 쪽 트랩 규율(정리 대상 변수 재대입 금지 + 임시경로 검문).
#   구조 처방(미구축): 샌드박스/읽기전용 마운트에서 M4 를 돌려 쓰기 시도를 관측하는 것.
#   그 전까지 `writes: read-only` 는 **등록자 주장**이지 이 검사기의 판정이 아니다.
#
# 사용법
#   capability_registry_check.sh <capfile> [<capfile> ...]
#   capability_registry_check.sh --self-test
#
# exit code
#   0  REGISTRABLE      전 capfile 이 M1–M5 + 추가조항 통과
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

  # ── 검증 불가 축의 정직한 표기 (판정 아님) ────────────────────────────────
  [ "$CAP_writes" = "read-only" ] && \
    printf '  ⚠️  writes: read-only 는 **등록자 주장**이다 — 이 검사기는 그 진위를 못 잰다(헤더 §잔여 참조)\n'
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
