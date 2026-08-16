#!/usr/bin/env bash
# relay_channel.sh — 정체성 ① 의 «연속 2-node 경유 채널».
#   한 태스크를 **서로 다른 필드 하네스 2개(이상)** 에 연달아 태우고,
#   그 사이에서 FH 가 `capability_composition_contract.md` 의 병합을 **계산**한다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 왜 이게 지어졌나 — 스펙만 있고 실행기가 없었다
# ─────────────────────────────────────────────────────────────────────────────
# `knowledge/shared/harness-core/capability_composition_contract.md` 는 2026-08-02 에
# 완성된 스펙이다. ⓐ restriction-union merge · ⓑ typed invocation · 검사 1/2/3 ·
# transitive closure · judge:model 의 non-clearing PASS — 전부 적혀 있다.
# **그런데 그 문서를 실행하는 코드가 레포에 0줄이었다.**
# `ship_readiness_gate.md` 의 정체성 ① 이 🟡 인 이유가 정확히 그것이다:
#
#   "routing runs for real … Missing: continuous 2-node relay channel"
#
# 라우팅(Skill Bus·17노드)은 돌지만, **한 태스크가 두 하네스를 연속으로 통과하며
# 그 사이에 거버넌스가 계산되는** 경로가 없었다. 이 파일이 그 경로다.
# 재발명이 아니라 **배선**이다([[feedback_built_but_not_wired]] 의 정통 형태).
#
# ─────────────────────────────────────────────────────────────────────────────
# 이 계기가 증명하지 않는 것 (과잉주장 금지 — 명명된 잔여)
# ─────────────────────────────────────────────────────────────────────────────
# · **등록 시점은 여기서 안 막는다.** 스펙 §1 이 이름 붙인
#   `scripts/capability_registry_check.sh`(M1–M5 + M4 쌍 실행)는 **여전히 없다.**
#   여기는 *call moment* 만 본다 — 선언이 문법에 맞는지·enum 안인지는 런타임에
#   다시 거부하지만(ⓑ.5), 그 선언이 **진실인지**는 검사하지 않는다.
# · **호출 순간 자체엔 기계 floor 가 없다.** "지금 capability 를 조합하려 한다" 를
#   관측하는 훅은 존재하지 않는다(트리거가 의도다). 이 스크립트는 *호출되면* 계산을
#   강제하지만, **호출되도록 강제하지는 못한다.** 스펙 §1 이 이미 그렇게 적어놨고
#   여기서 그 문장을 뒤집지 않는다.
# · **verdict 의 진위는 노드 소관.** 우리는 선언된 채널에서 값을 읽을 뿐이고,
#   노드가 거짓 PASS 를 내면 그건 노드의 결함이다. 다만 *"안 돌았는데 0"* 은
#   `DID_NOT_RUN` 을 enum 에 요구하는 것으로 부분 방어한다(ⓑ.4 B1).
#
# ─────────────────────────────────────────────────────────────────────────────
# cross-family 설계 감사에서 닫은 구멍 (2026-08-09, Gemini 3.1 Pro — 자력 적발 0)
# ─────────────────────────────────────────────────────────────────────────────
#   D1 단락 없음        A 가 BLOCK 인데 B 실행 → B 가 write-remote 면 원격 부작용
#                       ⟹ blocking 판정 즉시 체인 중단, 하류 노드는 실행 안 함
#   D2 model-only 통과  A·B 둘 다 judge:model 이고 PASS 면 blocking 합집합이 공집합
#                       ⟹ 조합 PASS 가 나온다(스펙 정면 위반)
#                       ⟹ 체인에 judge:model 이 하나라도 있으면 PASS 는 NON_CLEARING
#   D3 오타 축 무음드롭  `degrad:` 한 글자로 key preservation 이 뚫린다
#                       ⟹ 축 이름은 CLOSED 목록. 모르는 키는 VIOLATION, 무시 아님
#   D4 미측정=0         노드가 죽어 토큰이 비면 빈 문자열이 **빈 blocking 집합**으로
#                       유니온돼 무음 PASS ⟹ 빈/부재 verdict = HARNESS_ERROR
#   D5 인과 결박 부재    해시 체인이 "A 돌고 B 돌았다"만 적으면 «1노드 2회»와 구분 불가
#                       ⟹ B 의 입력에 A 의 verdict 토큰을 넣고, 런 기록에
#                          `sha256(upstream_verdict || upstream_stdout)` 를 남긴다
#   D6 pipefail         `node | grep TOKEN` 은 노드의 exit code 를 가린다
#                       ⟹ 파이프로 verdict 를 읽지 않는다. 출력은 파일로 받고
#                          exit status 는 직접 취한다(스펙 ⓑ.3 step 5 와 동일)
#
# ─────────────────────────────────────────────────────────────────────────────
# 사용법
# ─────────────────────────────────────────────────────────────────────────────
#   relay_channel.sh run --cap <capfile> --cap <capfile> [--cap ...] \
#                        [--task <string>] [--record <dir>] [--ack]
#   relay_channel.sh merge --cap <capfile> [--cap ...]      # 병합만 계산해 출력
#   relay_channel.sh --self-test
#
# exit code (fh_integration_contract.md 어휘 승계)
#   0  PASS                    전 노드 실행, blocking 없음, PASS 가 clearing
#   1  PENDING                 blocking 은 없으나 PASS 가 **NON_CLEARING**
#                              (체인에 judge:model 존재 → 단독으로 게이트 못 연다)
#   2  BLOCKED                 어떤 노드의 verdict 가 병합된 verdict_binding 에 속함
#   3  ESCALATE                병합 approval 이 사람을 요구(ask/ask-per-item)하는데 --ack 없음
#   4  COMPOSITION_VIOLATION   검사 1/2/3 실패 → **조합은 돌지 않는다**(스펙: 결함이지 리뷰건 아님)
#   10 HARNESS_ERROR           capfile 파손·entry 부재·enum 밖 값·빈 채널·레지스트리 도달불가
#
set -o pipefail
# ★ noglob. 선언 파일의 값은 **데이터**지 파일 패턴이 아니다. 이게 없으면
#   `verdict_binding: *` 가 레포 파일명으로 확장돼 blocking 집합이 통째로 바뀐다
#   = 병합이 입력보다 느슨해진다(cross-family #2, 실행 재현).
set -f

RC_PASS=0; RC_PENDING=1; RC_BLOCKED=2; RC_ESCALATE=3; RC_VIOLATION=4; RC_HARNESS=10

# ── 축 정의 — CLOSED. 여기 없는 키는 선언 파일에 있어도 VIOLATION 이다(D3) ──────
# permission 축: 왼→오 = permissive → strictest.  병합 = max(index)
AXES_PERM="approval reversibility residency degrade tier_floor"
ORDER_approval="auto notify ask ask-per-item forbidden"
ORDER_reversibility="reversible unknown irreversible"
ORDER_residency="public operator-private company"
ORDER_degrade="advisory fail-closed"
ORDER_tier_floor="none haiku sonnet opus fable"
# behaviour 축: 왼→오 = least → most capable.  병합 = max(index) (가장 유능한 쪽)
AXES_BEH="writes judge"
ORDER_writes="read-only write-local write-remote"
ORDER_judge="mechanical model"
# 집합 축
AXES_SET="verdict_binding"
# 선언 파일이 쓸 수 있는 비-축 키 (메타데이터)
# 스펙 §ⓑ.2 의 `calibration:` 블록(known_positive/known_negative)은 등록 시점 필드다.
# 여기는 call moment 라 그 값을 **쓰지 않지만**, CLOSED 목록에서 빠뜨리면 스펙대로 쓴
# 선언이 VIOLATION 으로 거부된다 — 2026-08-11 실측: registry_check 를 통과한 capfile 2개가
# relay 에서 8건 VIOLATION. 같은 스펙에 대해 두 계기가 서로 다른 스키마를 든
# divergent-normalizer 이고, 관대함이 갈리면 한쪽만 통과하는 입력이 생긴다.
# 🟥 **2026-08-16 재발.** 위 문단이 이 함정을 2026-08-11 사례로 적어놨는데, `summary`/`tags` 가
# `capability_registry_check.sh` 에만 추가되고 여기 안 들어와 **같은 파일이 같은 함정을 두 번**
# 밟았다 — 출하된 `.claude/capabilities/*.cap` 2개가 `✅ REGISTRABLE` 인데 relay 에서
# `⛔ COMPOSITION_VIOLATION` 이었다(등록되지만 **부를 수 없는** 선언). 아래 교차 레인이
# 그 재발을 잡는 앵커다 — 산문 경고는 이미 있었고 막지 못했다.
META_KEYS="id entry requires_cwd summary tags verdict_channel verdict_enum verdict_stdout_key upstream_argv echoes_upstream calibration_positive_args calibration_positive_expect calibration_negative_args calibration_negative_expect"

_die() { printf '❌ %s\n' "$*" >&2; exit "$RC_HARNESS"; }
_violation() { printf '⛔ COMPOSITION_VIOLATION — %s\n' "$*" >&2; VIOLATED=1; }

_order_of() {  # $1=axis → 선언된 순서 문자열
  case "$1" in
    approval) printf '%s' "$ORDER_approval" ;;
    reversibility) printf '%s' "$ORDER_reversibility" ;;
    residency) printf '%s' "$ORDER_residency" ;;
    degrade) printf '%s' "$ORDER_degrade" ;;
    tier_floor) printf '%s' "$ORDER_tier_floor" ;;
    writes) printf '%s' "$ORDER_writes" ;;
    judge) printf '%s' "$ORDER_judge" ;;
    *) printf '' ;;
  esac
}

_idx() {  # $1=value $2=order-string → index, 없으면 -1
  local v="$1" o="$2" i=0 x
  for x in $o; do [ "$x" = "$v" ] && { printf '%d' "$i"; return 0; }; i=$((i+1)); done
  printf '%d' -1
}

_nth() {  # $1=index $2=order-string
  local n="$1" o="$2" i=0 x
  for x in $o; do [ "$i" -eq "$n" ] && { printf '%s' "$x"; return 0; }; i=$((i+1)); done
  printf ''
}

# 선언 파일에서 키 하나 읽기. 없으면 빈 문자열.
# ★ 키 비교는 **리터럴**이다. 초판은 키를 grep -E 패턴으로 넘겨서, 선언 키가
#   `FH_.*` 같은 정규식이면 **다른 키의 값을 verdict 로 받았다**(cross-family #6).
_cap_get() {  # $1=capfile $2=key
  local k="$2" line found=""
  while IFS= read -r line; do
    case "$line" in
      *:*) ;;
      *) continue ;;
    esac
    # 키 부분만 떼어 공백 제거 후 **문자열 동일성**으로 비교(패턴 매칭 아님)
    local kk
    kk=$(printf '%s' "${line%%:*}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    if [ "$kk" = "$k" ]; then found="${line#*:}"; break; fi
  done < "$1"
  [ -z "$found" ] && { printf ''; return 0; }
  printf '%s' "$found" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# verdict_binding 전용 판독 — **스펙 스키마 표기를 그대로 받는다.**
#   스펙 §ⓑ.2 의 예시는 `verdict_binding: [FAIL, DID_NOT_RUN, HARNESS_ERROR]` 이고,
#   초판 파서는 공백 분해라 토큰이 `[FAIL,` 가 됐다 → **blocking 집합이 통째로 증발** →
#   스펙대로 쓴 사용자가 가장 크게 뚫렸다(cross-family #1, 실행 재현).
_cap_binding() {  # $1=capfile
  _cap_get "$1" verdict_binding | tr ',[]' '   '
}

# ── 선언 파일 문법 검사 — 모르는 키는 무시가 아니라 VIOLATION (D3) ─────────────
_cap_lint() {
  local f="$1" key ok seen="" pair code name
  [ -f "$f" ] || _die "capfile 없음: $f"
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    case "$line" in *:*) ;; *) _violation "$f: 'key: value' 형식 아님 → $line"; continue ;; esac
    key=$(printf '%s' "${line%%:*}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    ok=0
    for k in $AXES_PERM $AXES_BEH $AXES_SET $META_KEYS; do [ "$k" = "$key" ] && ok=1; done
    [ "$ok" -eq 1 ] || _violation "$f: 선언되지 않은 키 '$key' — 축 이름은 CLOSED 다(오타 무음드롭 방지)"
    # ★ 중복 키 거부. `_cap_get` 은 first-wins 라, 같은 키를 두 번 쓰면 **뒤엣것이 조용히
    #   무시된다** — 수렴 라운드 2 가 실행으로 재현했다: `verdict_enum` 을 두 번 선언해
    #   `1=PASS` 를 먼저 두면 실패 코드가 PASS 가 되고, `approval`/`reversibility` 중복은
    #   비가역→ask 파생 조임까지 우회한다. 어느 쪽을 택하든 임의적이므로 **택하지 않는다.**
    case " $seen " in *" $key "*) _violation "$f: 키 '$key' 가 중복 선언됐다 — 어느 쪽이 유효한지 임의로 고르지 않는다" ;; esac
    seen="$seen $key"
  done < "$f"
  # ★ enum 원자 검증. 두 가지를 본다:
  #   ⓐ 이름에 `,` `[` `]` 가 들어가면 안 된다 — 그 문자는 **스키마 문법**이라
  #     `_cap_binding` 이 분리자로 지운다. 이름이 `FAIL,ODD` 면 binding 은 `FAIL ODD` 로
  #     갈라지고 노드 verdict `FAIL,ODD` 와 **영원히 안 맞아** blocking 이 무력화된다.
  #     조용히 정규화하는 것이 fail-open 이라 거부한다(라운드 2, 실행 재현).
  #   ⓑ 코드는 0~128 정수여야 한다 — 129~255 는 런타임이 시그널 사망으로 우선 처리하므로
  #     선언해봐야 **절대 인정되지 않는다.** 인정 못 할 선언을 통과시키는 lint 는 거짓말이다.
  #   ⓒ 한 선언 안에서 **코드도 이름도 중복 금지**. 키 중복은 앞서 막았지만 그건 줄 단위였고,
  #     `verdict_enum: 0=PASS 1=FAIL 1=PASS` 처럼 **한 줄 안**의 중복 코드는 조회 루프가
  #     last-wins 로 삼켰다(라운드 3, 실행 재현) — 실패 코드가 PASS 로 세탁된다.
  #   ⓓ `=` 없는 짝 거부. `0=PASS 1` 은 `${pair%%=*}`·`${pair#*=}` 가 **둘 다 `1`** 을 내서
  #     "코드 1 = 이름 1" 이라는 유령 원자가 통과했다(라운드 3).
  local seen_code="" seen_name=""
  for pair in $(_cap_get "$f" verdict_enum); do
    case "$pair" in *=*) ;; *) _violation "$f: verdict_enum 항목 '$pair' 에 '=' 가 없다 — code=NAME 형식이어야 한다"; continue ;; esac
    code="${pair%%=*}"; name="${pair#*=}"
    [ -n "$name" ] || { _violation "$f: verdict_enum '$pair' 의 이름이 비었다"; continue; }
    case "$name" in *,*|*'['*|*']'*) _violation "$f: verdict_enum 이름 '$name' 에 스키마 문자(, [ ])가 있다 — 원자에 쓸 수 없다" ;; esac
    case "$code" in ''|*[!0-9]*) _violation "$f: verdict_enum 코드 '$code' 가 정수가 아니다" ;;
      *) if [ "$code" -gt 125 ]; then
           # 126/127 = 실행 불가/명령 없음, 128 초과 = 시그널 사망. 셋 다 **노드가 안 돈** 상태다.
           # 라운드 3 이 `127=PASS` 로 "존재하지 않는 entry" 를 PASS 로 세탁하는 걸 재현했다.
           _violation "$f: verdict_enum 코드 $code 는 126 이상 — 126/127(실행 불가·명령 없음)과 시그널 구간은 '노드가 돌지 않음' 이라 verdict 로 선언할 수 없다"
         fi ;;
    esac
    case " $seen_code " in *" $code "*) _violation "$f: verdict_enum 에 코드 $code 가 중복됐다 — 어느 이름이 유효한지 임의로 고르지 않는다" ;; esac
    case " $seen_name " in *" $name "*) _violation "$f: verdict_enum 에 이름 '$name' 이 중복됐다" ;; esac
    seen_code="$seen_code $code"; seen_name="$seen_name $name"
  done
  # ★ `verdict_enum` 은 **필수**다(스펙 M2: "typed verdict on a closed declared channel").
  #   초판은 enum 이 없으면 enum-밖 검사를 건너뛰어, stdout-key 노드가 찍은 **아무 문자열이나**
  #   verdict 로 통과했다(cross-family #5, 실행 재현). 닫힌 어휘가 없으면 typed 가 아니다.
  [ -n "$(_cap_get "$f" verdict_enum)" ] || \
    _violation "$f: verdict_enum 이 없다 — 닫힌 enum 없이는 typed 채널이 아니다(M2). 등록 불가"
}

# ── 병합 ──────────────────────────────────────────────────────────────────────
# 결과는 MERGED_<axis> 전역에, verdict_binding 은 MERGED_verdict_binding 에 공백구분.
# 부재 축은 **역할별 최악값**으로 채운다(스펙 ⓐ.5 / ⓑ.5): permission → 최엄격,
# behaviour → 최유능. "모르면 안전" 이 아니라 "모르면 최악" 이다.
_merge_caps() {
  local f axis order v i best bestv declared_any
  VIOLATED=0
  for f in "${CAPS[@]}"; do _cap_lint "$f"; done
  [ "$VIOLATED" -eq 1 ] && return "$RC_VIOLATION"

  for axis in $AXES_PERM $AXES_BEH; do
    order=$(_order_of "$axis"); best=-1; declared_any=0
    for f in "${CAPS[@]}"; do
      v=$(_cap_get "$f" "$axis")
      [ -z "$v" ] && continue
      declared_any=1
      i=$(_idx "$v" "$order")
      if [ "$i" -lt 0 ]; then
        _violation "$f: $axis='$v' 는 선언된 enum 밖이다 — 허용값으로 폴백하지 않는다"
        continue
      fi
      [ "$i" -gt "$best" ] && best="$i"
    done
    if [ "$declared_any" -eq 0 ]; then
      # ★ 양쪽 침묵 → 스펙 ⓑ.5 가 **이름으로 지정한 값**을 쓴다. "순서의 마지막 원소" 로
      #   일반화하면 안 된다 — 초판이 그렇게 했고 `approval` 이 `forbidden` 이 됐다.
      #   스펙은 `ask` 라고 적어놨다. 차이는 전건 미선언에선 안 보이고(둘 다 VIOLATION),
      #   **일부만 미선언인 조합**에서 갈린다: 스펙은 --ack 로 돌고 초판은 영구 차단이었다.
      #   과차단은 override 를 습관화시켜 게이트를 무장해제하므로 loosening 만큼 나쁘다.
      case "$axis" in
        approval)      bestv="ask" ;;
        reversibility) bestv="irreversible" ;;
        residency)     bestv="company" ;;
        degrade)       bestv="fail-closed" ;;
        writes)        bestv="write-remote" ;;   # behaviour = 최유능
        judge)         bestv="model" ;;          # behaviour = 최유능
        tier_floor)
          # 스펙의 worst-case 목록에 tier_floor 가 **없다.** 없는 값을 지어내지 않는다:
          # `none` 은 허용쪽이라 fail-open 이고, `fable` 은 Sonnet-floor 독트린을
          # 정면으로 깬다(base op 의 tier-gated capability = 결함). ⇒ 선언을 요구한다.
          _violation "tier_floor 를 아무 레이어도 선언하지 않았다 — 스펙이 이 축의 both-silent 값을 정의하지 않으므로 추정하지 않는다(선언 필요)"
          bestv="" ;;
      esac
      eval "MERGED_$axis=\"\$bestv\""
      continue
    fi
    bestv=$(_nth "$best" "$order")
    eval "MERGED_$axis=\"\$bestv\""
  done

  # verdict_binding = 집합 합집합
  MERGED_verdict_binding=""
  for f in "${CAPS[@]}"; do
    for v in $(_cap_binding "$f"); do
      case " $MERGED_verdict_binding " in *" $v "*) ;; *) MERGED_verdict_binding="$MERGED_verdict_binding $v" ;; esac
    done
  done
  MERGED_verdict_binding=$(printf '%s' "$MERGED_verdict_binding" | sed -e 's/^ *//' -e 's/ *$//')
  # `NONE` = "빈 집합을 **명시적으로** 선언했다" 는 표식이지 blocking 원자가 아니다.
  # 표식이 있으면 검사3 의 빈-집합 위반을 면제하되, 어떤 verdict 도 막지 않는다.
  case " $MERGED_verdict_binding " in
    *" NONE "*)
      BINDING_EXPLICIT_NONE=1
      # ⚠️ 토큰 제거를 sed 로 하지 마라. 초판은 `s/\bNONE\b//g` 를 썼는데 **BSD sed(macOS
      #   기본)는 `\b` 를 지원하지 않아 아무것도 안 지운다** — GNU sed(리눅스/CI)에서는
      #   지워진다. 즉 같은 코드가 플랫폼마다 다른 상태를 만들고, 두 경로의 최종 rc 가
      #   우연히 같아서 레인이 그걸 못 본다([[feedback_wiring_surfaces_hidden_failures]]
      #   의 BSD-first 가족: 로컬 초록 ≠ CI 초록). 셸 루프는 두 플랫폼에서 동일하다.
      _nb=""
      for _t in $MERGED_verdict_binding; do
        [ "$_t" = "NONE" ] && continue
        _nb="$_nb $_t"
      done
      MERGED_verdict_binding=$(printf '%s' "$_nb" | sed -e 's/^ *//' -e 's/ *$//') ;;
    *) BINDING_EXPLICIT_NONE=0 ;;
  esac

  [ "$VIOLATED" -eq 1 ] && return "$RC_VIOLATION"
  return 0
}

# ── 검사 1 / 2 / 3 ────────────────────────────────────────────────────────────
_run_checks() {
  local f axis order v i m
  VIOLATED=0

  # 검사 1 — KEY PRESERVATION. 어떤 레이어가 선언한 축은 병합에 반드시 살아 있어야.
  for f in "${CAPS[@]}"; do
    for axis in $AXES_PERM $AXES_BEH; do
      v=$(_cap_get "$f" "$axis"); [ -z "$v" ] && continue
      eval "m=\$MERGED_$axis"
      [ -z "$m" ] && _violation "검사1: $f 가 선언한 축 '$axis' 가 병합에서 사라졌다(누락에 의한 loosening)"
    done
    for v in $(_cap_binding "$f"); do
      # `NONE` 은 "빈 집합을 명시했다" 는 **센티널**이지 blocking 원자가 아니다 —
      # 병합에서 제거되는 게 정상이므로 키 보존 검사 대상이 아니다.
      # (초판은 sed `\b` 가 BSD 에서 무음 no-op 이라 NONE 이 안 지워졌고, 그래서 이 구멍이
      #  가려져 있었다. 이식성 수리가 숨은 실패를 드러낸 사례.)
      [ "$v" = "NONE" ] && continue
      case " $MERGED_verdict_binding " in *" $v "*) ;; *) _violation "검사1: $f 의 blocking verdict '$v' 가 병합 집합에 없다" ;; esac
    done
  done

  # 검사 2 — DIRECTION. 병합은 **어느 입력보다도** 더 많이 허용해서는 안 된다.
  for axis in $AXES_PERM; do
    order=$(_order_of "$axis"); eval "m=\$MERGED_$axis"; i=$(_idx "$m" "$order")
    for f in "${CAPS[@]}"; do
      v=$(_cap_get "$f" "$axis"); [ -z "$v" ] && continue
      [ "$i" -lt "$(_idx "$v" "$order")" ] && _violation "검사2: $axis 병합값 '$m' 이 $f 의 '$v' 보다 느슨하다"
    done
  done
  # behaviour 축은 방향이 반대다 — 병합은 어느 입력보다도 덜 유능해서는 안 된다.
  for axis in $AXES_BEH; do
    order=$(_order_of "$axis"); eval "m=\$MERGED_$axis"; i=$(_idx "$m" "$order")
    for f in "${CAPS[@]}"; do
      v=$(_cap_get "$f" "$axis"); [ -z "$v" ] && continue
      [ "$i" -lt "$(_idx "$v" "$order")" ] && _violation "검사2b: $axis 병합값 '$m' 이 $f 의 '$v' 보다 덜 유능하다"
    done
  done

  # 검사 3 — ROLE FIT. 병합된 behaviour 가 병합된 permission 안에 들어가야 한다.
  #   (각 표가 따로 옳고 짝이 틀린 경우를 잡는 유일한 검사)
  if [ "$MERGED_writes" = "write-remote" ] && [ "$MERGED_residency" != "public" ]; then
    _violation "검사3: writes=write-remote 인데 residency=$MERGED_residency — 비공개 residency 조합은 원격 쓰기 금지"
  fi
  if [ "$MERGED_approval" = "forbidden" ]; then
    _violation "검사3: 병합 approval=forbidden — 이 조합은 실행 대상이 아니다"
  fi
  # ★ blocking 집합이 비면 **이 조합은 아무것도 막을 수 없다.** 초판은 그걸 조용히 허용해서
  #   `verdict_binding` 을 아무도 선언하지 않은 조합이 FAIL 을 받고도 PASS 를 냈다
  #   (라운드 3, 실행 재현). 부재는 허가가 아니다 — 다만 "정말 advisory 전용" 인 조합도
  #   있을 수 있으므로, 값을 **지어내지 않고** 명시 선언(`verdict_binding: NONE`)을 요구한다.
  if [ -z "$MERGED_verdict_binding" ] && [ "${BINDING_EXPLICIT_NONE:-0}" -ne 1 ]; then
    _violation "검사3: 병합 verdict_binding 이 비었다 — 아무것도 막을 수 없는 조합이다. 정말 advisory 전용이면 어느 한 레이어가 'verdict_binding: NONE' 을 **명시**해야 한다"
  fi
  # 파생 조임(스펙 ⓐ.4 A2 — 비가역 sink 는 체인 전체가 상속한다). loosening 이 아니라 tightening 이라 안전.
  if [ "$MERGED_reversibility" = "irreversible" ]; then
    if [ "$(_idx "$MERGED_approval" "$ORDER_approval")" -lt "$(_idx ask "$ORDER_approval")" ]; then
      MERGED_approval="ask"
      DERIVED_TIGHTEN="approval→ask (비가역 sink 상속)"
    fi
  fi

  [ "$VIOLATED" -eq 1 ] && return "$RC_VIOLATION"
  return 0
}

_print_merge() {
  printf 'FH_MERGED_approval: %s\n'       "$MERGED_approval"
  printf 'FH_MERGED_reversibility: %s\n'  "$MERGED_reversibility"
  printf 'FH_MERGED_residency: %s\n'      "$MERGED_residency"
  printf 'FH_MERGED_degrade: %s\n'        "$MERGED_degrade"
  printf 'FH_MERGED_tier_floor: %s\n'     "$MERGED_tier_floor"
  printf 'FH_MERGED_writes: %s\n'         "$MERGED_writes"
  printf 'FH_MERGED_judge: %s\n'          "$MERGED_judge"
  printf 'FH_MERGED_verdict_binding: %s\n' "$MERGED_verdict_binding"
  [ -n "${DERIVED_TIGHTEN:-}" ] && printf 'FH_MERGED_derived: %s\n' "$DERIVED_TIGHTEN"
  return 0
}

_sha() { # stdin → sha256 hex (macOS/linux 양쪽)
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else printf 'NO_HASH_TOOL'; fi
}

# ── 노드 1개 실행 ─────────────────────────────────────────────────────────────
# 반환: 전역 NODE_VERDICT / NODE_EXIT / NODE_OUT_FILE
# 파이프로 verdict 를 읽지 않는다(D6) — 출력은 파일로 받고 exit status 를 직접 취한다.
_invoke_node() {
  local f="$1" task="$2" upstream="$3" outdir="$4" n="$5"
  local entry cwd chan enum key argv_extra rc line code name
  entry=$(_cap_get "$f" entry)
  cwd=$(_cap_get "$f" requires_cwd)
  chan=$(_cap_get "$f" verdict_channel); [ -z "$chan" ] && chan="exit"
  enum=$(_cap_get "$f" verdict_enum)
  key=$(_cap_get "$f" verdict_stdout_key); [ -z "$key" ] && key="FH_GATE_VERDICT"

  [ -n "$entry" ] || { NODE_VERDICT="HARNESS_ERROR"; NODE_EXIT=$RC_HARNESS; return 0; }
  # ★`requires_cwd: SELF` = «이 선언을 품은 레포». 해석은 `capability_registry_check.sh` ·
  #   `capability_effect_probe.sh` 와 **같은 규칙**(git 레포 루트)이어야 한다 — 규칙이 갈리면
  #   두 계기가 서로 다른 트리를 재고, 그건 이 파일이 §divergent-normalizer 로 이름 붙인 결함이다.
  #   🟥 이 값이 없으면 **tracked 선언이 구조적으로 uncallable** 하다: `SELF` 는 공개표면에
  #   운영자 홈 절대경로를 안 싣기 위해 도입된 형태라, 하네스 자기선언은 전부 이 형태를 쓴다.
  #   실측(2026-08-16): SELF 두 노드 → `NOT_CALLABLE … HARNESS_ERROR` · 절대경로 두 노드 → 진짜 판정.
  if [ "$cwd" = "SELF" ]; then
    cwd="$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null)"
    if [ -z "$cwd" ]; then
      printf 'ℹ️  NOT_CALLABLE: requires_cwd: SELF 인데 선언이 git 레포 안에 없다 → dispatch 폴백\n' >&2
      NODE_VERDICT="HARNESS_ERROR"; NODE_EXIT=$RC_HARNESS; return 0
    fi
  fi
  if [ -n "$cwd" ] && [ ! -d "$cwd" ]; then
    printf 'ℹ️  NOT_CALLABLE: requires_cwd 부재(%s) → dispatch 폴백 대상\n' "$cwd" >&2
    NODE_VERDICT="HARNESS_ERROR"; NODE_EXIT=$RC_HARNESS; return 0
  fi

  NODE_OUT_FILE="$outdir/node${n}.out"
  # ★ 인과 결박(D5): 상류 verdict 를 하류 노드의 **입력으로 실제로 넘긴다.**
  #    이 인자를 빼면 relay 는 «1노드 2회» 와 구분 불가가 된다.
  #    ⚠️ **argv 주입은 선언한 노드에만 한다.** 첫 실사용에서 잡힌 결함(2026-08-09):
  #    실물 필드 스캐너는 `TARGETS=("$@")` 로 인자를 전부 경로로 받는다 — 결박용 플래그를
  #    무조건 붙이면 그 노드가 **없는 경로를 스캔하려다 깨진다.** 결박을 위해 피감 대상을
  #    부수는 것은 계기가 대상을 바꾸는 것이라 결박 자체가 무의미해진다.
  #    ⇒ env `RELAY_UPSTREAM_VERDICT` 는 **항상** 넘긴다(모든 노드가 읽을 수 있고 인자를 안 깬다).
  #      argv 는 `upstream_argv: yes` 를 선언한 노드에만.
  argv_extra=""
  if [ -n "$upstream" ] && [ "$(_cap_get "$f" upstream_argv)" = "yes" ]; then
    argv_extra="--upstream-verdict $upstream"
  fi

  ( [ -n "$cwd" ] && cd "$cwd"; RELAY_TASK="$task" RELAY_UPSTREAM_VERDICT="$upstream" \
      $entry $argv_extra ) > "$NODE_OUT_FILE" 2>&1
  rc=$?
  NODE_EXIT=$rc

  # verdict 해석 — 선언된 채널에서만 읽는다.
  # ★ 시그널 사망은 enum 이 뭐라 선언하든 HARNESS_ERROR 다(스펙 ⓑ.5 "Process killed").
  #   초판은 `137=PASS` 를 선언한 capfile 을 그대로 믿었다 — 즉 **죽은 프로세스가 PASS**
  #   였다(cross-family #4, 실행 재현). 죽음은 verdict 가 아니라 계기 사망이다.
  #   126/127 도 같은 계열이다 — **실행 불가 · 명령 없음**. 즉 노드가 돌지 않았다.
  #   초판은 128 초과만 막아서 `127=PASS` 를 선언한 capfile 이 *존재하지 않는 entry* 를
  #   PASS 로 세탁했다(라운드 3, 실행 재현). "안 돌았다" 는 verdict 가 아니다.
  if [ "$rc" -ge 126 ]; then
    printf 'ℹ️  node%s: rc=%s (실행 불가/명령 없음/시그널) → HARNESS_ERROR — 노드가 돌지 않았다\n' "$n" "$rc" >&2
    NODE_VERDICT="HARNESS_ERROR"; return 0
  fi

  local v_exit="" v_key=""
  case "$chan" in
    exit|both)
      for pair in $enum; do
        code="${pair%%=*}"; name="${pair#*=}"
        [ "$code" = "$rc" ] && v_exit="$name"
      done
      ;;
  esac
  case "$chan" in
    stdout-key|both)
      # 키 매칭은 **리터럴 접두**다 — 정규식이면 다른 키를 받는다(cross-family #6).
      while IFS= read -r line; do
        case "$line" in
          "$key":*) v_key=$(printf '%s' "${line#*:}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'); break ;;
        esac
      done < "$NODE_OUT_FILE"
      ;;
  esac

  case "$chan" in
    exit)        NODE_VERDICT="$v_exit" ;;
    stdout-key)  NODE_VERDICT="$v_key" ;;
    both)
      # ★ `both` 는 **두 채널이 일치해야** 한다. 초판은 stdout 이 exit 을 덮어써서,
      #   exit 1(FAIL) 로 죽은 노드가 stdout 에 `PASS` 만 찍으면 PASS 가 됐다
      #   (cross-family #3, 실행 재현). 불일치는 더 관대한 쪽이 아니라 HARNESS_ERROR 다.
      if [ -n "$v_exit" ] && [ -n "$v_key" ]; then
        if [ "$v_exit" = "$v_key" ]; then NODE_VERDICT="$v_exit"
        else
          printf 'ℹ️  node%s: both 채널 불일치 exit=%s stdout=%s → HARNESS_ERROR\n' "$n" "$v_exit" "$v_key" >&2
          NODE_VERDICT="HARNESS_ERROR"; return 0
        fi
      else
        printf 'ℹ️  node%s: both 를 선언했는데 한쪽 채널이 비었다(exit=%s stdout=%s) → HARNESS_ERROR\n' "$n" "${v_exit:-NONE}" "${v_key:-NONE}" >&2
        NODE_VERDICT="HARNESS_ERROR"; return 0
      fi
      ;;
    *) NODE_VERDICT="" ;;
  esac

  # ★ D7 — enum 밖 값은 HARNESS_ERROR, 절대 PASS 아님(스펙 ⓑ.3 step 6).
  #   exit 채널엔 이게 자동으로 걸린다(매칭 실패 → 빈 문자열). 그러나 **stdout-key 는
  #   노드가 찍은 임의 문자열이 그대로 들어온다** — 초판이 그 경로를 안 막아서,
  #   노드가 `FH_GATE_VERDICT: TOTALLY_FINE` 을 찍으면 binding 에 없다는 이유로 PASS 가 됐다.
  #   노드의 stdout 은 데이터지 명령이 아니다(ⓑ.3 step 7) — 어휘까지 노드에 맡기지 않는다.
  #   발견 경로: 첫 실사용에서 pmh 스캐너 히트를 따라가다 나옴(적대검증이 아니라 실사용).
  if [ -n "$NODE_VERDICT" ] && [ -n "$enum" ]; then
    local known=0
    for pair in $enum; do [ "${pair#*=}" = "$NODE_VERDICT" ] && known=1; done
    if [ "$known" -eq 0 ]; then
      printf 'ℹ️  node%s: verdict "%s" 가 선언된 enum 밖이다 → HARNESS_ERROR\n' "$n" "$NODE_VERDICT" >&2
      NODE_VERDICT="HARNESS_ERROR"
    fi
  fi

  # D4 — 빈/부재 verdict 는 **빈 blocking 집합이 아니라** 하네스 에러다.
  if [ -z "$NODE_VERDICT" ]; then
    printf 'ℹ️  node%s: 선언된 채널(%s)에서 verdict 를 못 읽었다 → HARNESS_ERROR (미측정≠PASS)\n' "$n" "$chan" >&2
    NODE_VERDICT="HARNESS_ERROR"
  fi
  return 0
}

# ── run ───────────────────────────────────────────────────────────────────────
do_run() {
  local task="" recdir="" ack=0 n=0 upstream="" rc final=$RC_PASS
  CAPS=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --cap) shift; CAPS+=("$1") ;;
      --task) shift; task="$1" ;;
      --record) shift; recdir="$1" ;;
      --ack) ack=1 ;;
      *) _die "알 수 없는 인자: $1" ;;
    esac
    shift
  done
  [ "${#CAPS[@]}" -gt 0 ] || _die "usage: run --cap <capfile> --cap <capfile> [--task s] [--record dir] [--ack]"

  # 노드가 2개 미만이면 이건 relay 가 아니다. 정체성 ① 의 주장 자체가 2-node 다.
  # ⚠️ 세는 단위는 **줄**이다. `set -- $files` 로 세면 공백 있는 경로가 2개로 쪼개져
  #    1노드 호출이 relay 로 통과한다(cross-family #8 과 같은 뿌리).
  local ncap=${#CAPS[@]}
  [ "$ncap" -ge 2 ] || _die "relay 는 노드 2개 이상을 요구한다(받은 수: $ncap) — 1노드는 단순 호출이지 경유가 아니다"

  _merge_caps || { printf 'FH_STATUS: ERROR\nFH_RELAY_VERDICT: COMPOSITION_VIOLATION\n'; return "$RC_VIOLATION"; }
  _run_checks || { printf 'FH_STATUS: ERROR\nFH_RELAY_VERDICT: COMPOSITION_VIOLATION\n'; return "$RC_VIOLATION"; }

  printf 'FH_STATUS: SUCCESS\n'
  _print_merge

  # 병합 approval 이 사람을 요구하면 여기서 멈춘다(스펙 ⓑ.3 step 3).
  case "$MERGED_approval" in
    ask|ask-per-item)
      if [ "$ack" -ne 1 ]; then
        printf 'FH_RELAY_VERDICT: ESCALATE\n'
        printf 'ℹ️  병합 approval=%s — 사람 승인이 필요하다. 승인했으면 --ack 로 재실행.\n' "$MERGED_approval" >&2
        return "$RC_ESCALATE"
      fi
      ;;
  esac

  [ -n "$recdir" ] || recdir=$(mktemp -d 2>/dev/null || printf '/tmp/relay.%s' "$$")
  mkdir -p "$recdir" 2>/dev/null
  # ★ 이전 런의 잔여 산출물 제거. 남겨두면 짧아진 이번 런이 **지난 런의 node2.out 을**
  #   자기 증거로 갖게 된다(라운드 3 MAJOR, 실행 재현). 기록 디렉터리는 런 단위다.
  #   ⚠️ 이 줄은 **글롭이 필요한 유일한 자리**인데 위에서 `set -f` 를 켰다 — 서브셸에서만
  #     되돌린다. (전역으로 풀면 선언값이 다시 파일명으로 확장된다. 실제로 이 레인이
  #     `set -f` 도입의 부작용을 잡아냈다.)
  ( set +f; rm -f "$recdir"/node*.out 2>/dev/null )
  : > "$recdir/CHAIN.txt"
  printf 'task_sha: %s\n' "$(printf '%s' "$task" | _sha)" >> "$recdir/CHAIN.txt"

  for f in "${CAPS[@]}"; do
    n=$((n+1))
    _invoke_node "$f" "$task" "$upstream" "$recdir" "$n"
    printf 'FH_NODE%d_ID: %s\n' "$n" "$(_cap_get "$f" id)"
    printf 'FH_NODE%d_VERDICT: %s\n' "$n" "$NODE_VERDICT"
    printf 'FH_NODE%d_EXIT: %s\n' "$n" "$NODE_EXIT"

    # ★ 인과 결박 기록(D5): 이 노드가 **무엇을 상류로 받았는지** 를 해시로 남긴다.
    #   upstream 이 비어 있으면(=1번 노드) 그 사실도 명시적으로 적는다 — 미측정≠0.
    local up_sha consumed
    if [ -n "$upstream" ]; then
      up_sha=$(printf '%s|%s' "$upstream" "$(cat "$recdir/node$((n-1)).out" 2>/dev/null | _sha)" | _sha)
    else
      up_sha="ROOT"
    fi
    # ★ **"넘겼다" 와 "소비했다" 는 다른 주장이다.** 초판 기록은 `upstream=PASS` 라고만 적었고
    #   그건 우리가 *제공*했다는 뜻인데, 읽는 사람에겐 노드가 *받아 썼다*로 읽힌다.
    #   cross-family #7 이 그 갭을 실행으로 재현했다(상류를 무시하는 노드도 같은 줄을 얻는다).
    #   ⇒ 필드명을 `upstream_offered` 로 바꾸고, **소비는 별도 축**으로 적는다.
    #     노드가 `echoes_upstream: yes` 를 선언하면 되돌려 찍은 값을 대조해 VERIFIED,
    #     아니면 **UNVERIFIED**. 미측정을 "확인됨" 으로 렌더하지 않는다.
    consumed="NA"
    if [ -n "$upstream" ]; then
      if [ "$(_cap_get "$f" echoes_upstream)" = "yes" ]; then
        # ★ 되돌림 대조도 **리터럴**이다. 초판은 `grep "^…: $upstream$"` 이라 verdict 이름이
        #   `P.*` 이면 노드가 찍은 `PASS` 를 VERIFIED 로 받았다(라운드 2, 실행 재현) —
        #   #6 에서 고친 것과 **같은 결함이 다른 자리에** 남아 있던 반쪽-픽스다.
        local ech="" el
        while IFS= read -r el; do
          case "$el" in
            "RELAY_UPSTREAM_SEEN:"*)
              ech=$(printf '%s' "${el#*:}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'); break ;;
          esac
        done < "$NODE_OUT_FILE"
        if [ -n "$ech" ] && [ "$ech" = "$upstream" ]; then
          consumed="VERIFIED"
        else
          consumed="DECLARED_BUT_NOT_ECHOED"
          printf 'ℹ️  node%s: echoes_upstream 을 선언했는데 되돌린 값이 없다 → 소비 미확인\n' "$n" >&2
        fi
      else
        consumed="UNVERIFIED"
      fi
    fi
    printf 'node%d id=%s upstream_offered=%s upstream_consumption=%s upstream_binding_sha=%s verdict=%s exit=%s out_sha=%s\n' \
      "$n" "$(_cap_get "$f" id)" "${upstream:-NONE}" "$consumed" "$up_sha" "$NODE_VERDICT" "$NODE_EXIT" \
      "$(cat "$NODE_OUT_FILE" 2>/dev/null | _sha)" >> "$recdir/CHAIN.txt"

    # ★ 병합된 degrade 가 **실제로 무는 지점**. 이게 없으면 degrade 병합은 장식이다.
    #   HARNESS_ERROR(=계기가 안 돌았다/못 읽었다)를 만났을 때:
    #     fail-closed → 여기서 막는다.  advisory → 계속 가되 **clearing PASS 는 영구히 불가**.
    #   agy 가 지목한 판별 레인이 정확히 여기다 — A 가 fail-closed 이고 B 가 advisory 인데
    #   B 의 계기가 죽으면, 진짜 relay 는 B 가 A 의 fail-closed 를 **상속**해서 빨개지고,
    #   «독립 2회 호출» 이면 B 의 로컬 advisory 로 초록이 된다. 두 세계가 여기서 갈린다.
    if [ "$NODE_VERDICT" = "HARNESS_ERROR" ]; then
      if [ "$MERGED_degrade" = "fail-closed" ]; then
        printf 'FH_RELAY_VERDICT: BLOCKED\n'
        printf 'FH_RELAY_BLOCKED_AT: node%d (HARNESS_ERROR under merged degrade=fail-closed)\n' "$n"
        printf 'FH_RELAY_CHAIN_RECORD: %s\n' "$recdir/CHAIN.txt"
        return "$RC_BLOCKED"
      fi
      DEGRADED_SEEN=1
    fi

    # blocking 판정 → **즉시 체인 중단**(D1). 하류 노드는 실행하지 않는다.
    case " $MERGED_verdict_binding " in
      *" $NODE_VERDICT "*)
        printf 'FH_RELAY_VERDICT: BLOCKED\n'
        printf 'FH_RELAY_BLOCKED_AT: node%d (%s)\n' "$n" "$NODE_VERDICT"
        printf 'FH_RELAY_CHAIN_RECORD: %s\n' "$recdir/CHAIN.txt"
        printf 'ℹ️  하류 노드는 실행하지 않았다 — 이미 막힌 체인이 부작용을 내지 않게 한다.\n' >&2
        return "$RC_BLOCKED" ;;
    esac
    upstream="$NODE_VERDICT"
  done

  # D2 — 체인에 judge:model 이 있으면 PASS 는 **단독으로 게이트를 열 수 없다.**
  # D4 연장 — advisory 로 넘긴 HARNESS_ERROR 도 clearing PASS 를 영구히 막는다.
  #   "안 재고 통과" 를 초록으로 렌더하지 않는다(미측정≠PASS).
  if [ "${DEGRADED_SEEN:-0}" -eq 1 ]; then
    printf 'FH_RELAY_VERDICT: PENDING\n'
    printf 'FH_RELAY_CLEARING: NON_CLEARING (HARNESS_ERROR 를 advisory 로 통과시켰다 — 미측정은 PASS 가 아니다)\n'
    final=$RC_PENDING
  elif [ "$MERGED_judge" = "model" ]; then
    printf 'FH_RELAY_VERDICT: PENDING\n'
    printf 'FH_RELAY_CLEARING: NON_CLEARING (judge=model — 모델 PASS 는 단독으로 게이트를 만족시키지 못한다)\n'
    final=$RC_PENDING
  else
    printf 'FH_RELAY_VERDICT: PASS\n'
    printf 'FH_RELAY_CLEARING: CLEARING\n'
    final=$RC_PASS
  fi
  printf 'FH_RELAY_CHAIN_RECORD: %s\n' "$recdir/CHAIN.txt"
  return "$final"
}

do_merge_only() {
  CAPS=()
  while [ $# -gt 0 ]; do case "$1" in --cap) shift; CAPS+=("$1") ;; *) _die "알 수 없는 인자: $1" ;; esac; shift; done
  [ "${#CAPS[@]}" -gt 0 ] || _die "usage: merge --cap <capfile> [--cap ...]"
  _merge_caps || return "$RC_VIOLATION"
  _run_checks || return "$RC_VIOLATION"
  printf 'FH_STATUS: SUCCESS\n'; _print_merge
}

case "${1:-}" in
  run)   shift; do_run "$@" ;;
  merge) shift; do_merge_only "$@" ;;
  --self-test) exec bash "$(dirname "$0")/test_relay_channel_lanes.sh" ;;
  *) printf 'usage: %s {run|merge|--self-test} ...\n' "$(basename "$0")" >&2; exit "$RC_HARNESS" ;;
esac
