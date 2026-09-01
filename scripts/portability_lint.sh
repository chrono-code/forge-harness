#!/usr/bin/env bash
# portability_lint.sh — 셸 이식성 · 조용한 즉사 · 레포전제 픽스처 린트 (advisory)
#
# 왜 이게 있나 (weekly_audit_2026-08-16 🟧-3):
#   이 레포의 재발 클래스 중 BSD/GNU · zsh/bash 이식성이 윈도우 16일에 ~12건인데
#   **전용 계기가 없었고**, 잡힌 경로는 **전부 CI ubuntu 에서 사후**였다. 즉 저자 머신
#   (macOS)에서는 구조적으로 초록이고, 로컬 초록 / CI 적색이 2026-08-16 하루에 2회 났다.
#   이 린트는 그 사각을 보라고 지어졌다.
#
# 🟥 배선 상태를 헤더가 정직하게 말한다 (적대검증 2026-08-16 이 초판 헤더를 «거짓말»로 지목):
#   초판 헤더는 "저자 머신에서 **커밋 전에** 한 번 본다" 고 적었는데, 실제 호출부는
#   `selfcheck.sh` 의 `--self-test` **하나뿐**이다. 즉 **계기의 계기는 도는데 계기 자체는 안 돈다.**
#   제자리는 pre-commit 의 staged `*.sh` 한정 advisory 인데 아직 안 붙였다(별도 커밋 · 인계됨).
#   그때까지 본 실행은 **손으로 돌려야 한다**: `bash scripts/portability_lint.sh`.
#   이 문장을 «커밋 전에 본다»로 되돌리려면 **먼저 pre-commit 에 붙여라.** 헤더가 배선보다
#   앞서 나가는 것이 이 커밋이 고치고 있는 바로 그 결함이다.
#
# 무엇이 아닌가:
#   · shellcheck 대체가 아니다. shellcheck 는 「성공하는 첫 명령」 패턴(P1)을 못 잡는다 —
#     문법이 아니라 **플랫폼별 의미 차이**라서다. 둘은 상보적이다.
#   · 게이트가 아니다. **advisory** 다(exit 0 유지, `--strict` 로만 1). 이유는
#     degrade_direction_scan 과 같다 — FP 를 감수하는 사전 선별기이고, 과차단은
#     `--no-verify` 를 근육기억으로 만들어 같은 훅의 비가역 게이트까지 무장해제시킨다.
#
# Exit: 0 = 소견 없음 또는 advisory 모드 · 1 = --strict 에서 소견 有 · 10 = 하네스 오류
# Usage: bash scripts/portability_lint.sh [PATHS...] [--strict] [--quiet]
#        bash scripts/portability_lint.sh --self-test

set -uo pipefail

STRICT=0; QUIET=0; SELFTEST=0; TARGETS=()
for a in "$@"; do
  case "$a" in
    --strict)    STRICT=1 ;;
    --quiet)     QUIET=1 ;;
    --self-test) SELFTEST=1 ;;
    -*)          echo "unknown flag: $a" >&2; exit 10 ;;
    *)           TARGETS+=("$a") ;;
  esac
done

# ── 규칙표 ────────────────────────────────────────────────────────────────────
# 각 규칙 = ID§정규식§한 줄 사유§처방
#
# 🟥 구분자가 `|` 가 아니라 `§` 인 이유 — 이 린트의 self-test 가 초판에서 잡은 결함이다:
#    `|` 를 필드 구분자로 쓰면 정규식 안의 **교대(alternation) `|`** 에서 잘린다.
#    P1 이 `…=\$\((cat` 까지만 남아 known-positive 를 놓쳤다. 계기가 자기 문법에 걸린 것이고,
#    known-pair 가 없었으면 «소견 0건»이 그냥 초록으로 보였을 것이다.
# 전부 **오늘 실물에서 나온 것**이거나 이 레포의 기록된 재발이다. 추측 규칙은 넣지 않는다 —
# FP 가 늘면 이 린트가 무시되고, 무시되는 린트는 없는 린트보다 나쁘다(경고 하나가 0건보다
# 나쁠 수 있다: 0건은 «아무도 안 봤다»로 남지만 1건은 «봤고 이것만 나왔다»로 접힌다).
RULES=(
'P1§^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=\$\((cat|sed|awk|grep|head|tail|python3?|node|jq)[^)]*\)§[후보] set -e 아래 명령치환 ASSIGNMENT — 파일 부재 시 그 줄에서 즉사. set -e 판별이 파일 스코프라 확정 아님§`|| true` 를 붙여라. 2>/dev/null 도 ${VAR:-기본값} 도 이걸 못 막는다(할당문 자체가 죽으므로). [ -f ] 가드도 present-but-unreadable arm 을 못 막는다 — 2026-08-16 4방 매트릭스가 반증'  # portability-noqa: 규칙표 데이터이지 실행 코드가 아니다
'P2§stat -f §`stat -f` 가 먼저 오면 GNU 에서 **성공한다** — 파일시스템 정보를 내고 폴백이 영영 안 돈다§stat -c %Y … 2>/dev/null || stat -f %m … 2>/dev/null || echo 0 순서로. GNU-first 가 맞다'  # portability-noqa: 규칙표 데이터이지 실행 코드가 아니다
'P3§sed -i[[:space:]]+[^-.]§`sed -i` 는 BSD 가 백업 접미사를 요구한다 — GNU 폼은 macOS 에서 다음 토큰을 파일명으로 먹는다§sed -i.bak 후 삭제, 또는 sed … > tmp && mv tmp f'  # portability-noqa: 규칙표 데이터이지 실행 코드가 아니다
'P4§grep -P§`grep -P` 는 BSD/macOS 기본 grep 에 없다§grep -E 로 낮추거나 perl -ne 로'  # portability-noqa: 규칙표 데이터이지 실행 코드가 아니다
'P5§\$\{PIPESTATUS§`${PIPESTATUS[…]}` 는 zsh 에서 빈 문자열이다 — 판정이 "" 로 접힌다§bash 전용이면 shebang 확인. 더 나은 형태: 파이프를 빼고 out=$(cmd); rc=$?'  # portability-noqa: 규칙표 데이터이지 실행 코드가 아니다
'P6§readlink -f§`readlink -f` 는 구형 BSD 에 없다§cd "$(dirname "$f")" && pwd -P 조합으로'  # portability-noqa: 규칙표 데이터이지 실행 코드가 아니다
'P7§date -d §`date -d` 는 GNU 전용 — BSD 는 date -v§epoch 로 계산하거나 두 폼을 || 로 잇되 GNU-first'  # portability-noqa: 규칙표 데이터이지 실행 코드가 아니다
'P9§"(package\.json|bin/)§테스트가 **레포 고유 파일**을 픽스처로 참조한다 — 이식된 자산에서 전량 FAIL 한다§자기 픽스처를 mktemp 로 만들어 써라. 2026-08-16 PMH 이식에서 selfcheck 35 FAIL 의 원인'  # portability-noqa: 규칙표 데이터이지 실행 코드가 아니다
)

_hits=0
_emit() { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }

lint_file() {
  local f="$1" rule id re why fix line n
  # 🟥 끊어진 심링크는 «소견 없음»이 아니라 **미측정**이다 (cross-family 2026-08-16).
  if [ -L "$f" ] && [ ! -e "$f" ]; then
    _emit "  [UNMEASURED] $f — 끊어진 심링크. 읽지 못했다(초록이 아니다)."
    return 0
  fi
  # 🟥 **로케일 fail-open — cross-family 가 양쪽 로케일을 실제로 돌려서 잡았다.**
  # UTF-8 로케일에서 대상 줄에 비-UTF8 바이트가 있으면 `grep -nE` 가 **매치하지 않고**, 그
  # 실패가 삼켜져 최종 「소견 없음」으로 접힌다. 같은 입력이 `LC_ALL=C` 에서는 검출됐다.
  # 즉 «무매치»와 «해석 실패»가 구분되지 않는 fail-open 이고, 이 린트가 잡으라고 만들어진
  # 클래스 그 자체다. 이 함수의 모든 매칭을 **바이트 기반으로 고정**한다.
  local LC_ALL=C LANG=C
  # P1 은 «set -e 계열이 켜져 있는 파일»에서만 의미가 있다. 아니면 FP 폭발.
  # ⚠️ 이 판별은 **파일 스코프**라 정확하지 않다 (cross-family 실측): 호출되지 않는 함수 안의
  # `set -e` 로도 켜지고, 뒤따르는 `set +e` 로 꺼지지 않으며, 부모가 `set -e` 상태로 source 하는
  # 파일은 **놓친다**. 그래서 P1 은 «확정 결함»이 아니라 **후보**다 — 출력 문구도 그렇게 낮춘다.
  local has_sete=0
  grep -qE '^[[:space:]]*set -[a-z]*e' "$f" 2>/dev/null && has_sete=1
  for rule in "${RULES[@]}"; do
    id="${rule%%§*}"; rest="${rule#*§}"
    re="${rest%%§*}";  rest="${rest#*§}"
    why="${rest%%§*}"; fix="${rest#*§}"
    case "$id" in P1) [ "$has_sete" = 1 ] || continue ;; esac
    while IFS= read -r line; do
      n="${line%%:*}"; body="${line#*:}"
      # noqa 이탈구: 알고 쓴 경우를 위한 문서화된 억제(전부 차단하면 우회를 훈련시킨다)
      # noqa 는 **사유가 있어야** 억제한다. 초판은 문자열 존재만 봐서 사유 없이도, 심지어
      # 문자열 리터럴 안에서도 억제됐다 — advisory 인 지금은 경미하나 `--strict` 를 게이트로
      # 승격하는 순간 무료 우회로가 된다.
      printf '%s' "$body" | grep -qE '#[[:space:]]*portability-noqa:[[:space:]]*[^[:space:]]' && continue
      # 주석 전용 줄은 소견이 아니다. 이 레포는 결함을 **주석으로 길게 설명하는** 관습이 있어서
      # (그 설명이 문제 패턴을 그대로 인용한다) 이걸 안 빼면 FP 가 구조적으로 쌓인다.
      # 손검증 2026-08-16: 초판 50건 중 8건이 정확히 이 형태였다.
      case "$(printf '%s' "$body" | sed 's/^[[:space:]]*//')" in '#'*) continue ;; esac
      # P2 는 **순서**가 결함이지 `stat -f` 의 존재가 아니다. GNU-first(`stat -c … || stat -f …`)는
      # 이 레포의 올바른 관용구이고, 초판은 그걸 12건 중 대다수로 지적했다 — 즉 규칙이 처방을
      # 위반으로 렌더했다. 손검증 한 건이 이걸 잡았다(`_mtime()` 두 곳).
      case "$id" in
        P2) case "$body" in *'stat -c'*'stat -f'*) continue ;; esac ;;
        # P7 도 같은 형태다 — `date -d … || date -v…` 는 GNU-first 폴백이라 **올바른 관용구**다.
        # P2 에서 한 번 겪고도 새 규칙에 같은 오류를 심었다(손검증이 두 번째로 잡음).
        P7) case "$body" in *'date -d'*'date -v'*) continue ;; esac ;;
      esac
      # P1 의 처방이 이미 적용된 줄은 소견이 아니다. 이 이탈구가 없으면 린트가 **자기 처방을
      # 따른 코드를 계속 지적**하고, 그러면 사람이 린트를 끄게 된다 — self-test 가 잡았다.
      # ⚠️ `2>/dev/null` 이나 `${VAR:-기본값}` 은 이탈 사유가 **아니다**: 둘 다 할당문의
      # 즉사를 막지 못한다(2026-08-16 4방 매트릭스). 여기서 인정하는 건 `|| true` 뿐이다.
      case "$id" in
        P1) case "$body" in *'|| true'*|*'||true'*) continue ;; esac ;;
      esac
      _emit "  [$id] $f:$n"
      _emit "        $why"
      _emit "        → $fix"
      _hits=$((_hits+1))
    done < <(grep -nE "$re" "$f" 2>/dev/null)
  done

  # P8 — 가드 없는 glob 루프. 규칙표에 못 넣는다: **판정이 다음 줄에 있기 때문**이다.
  # 줄 단위 정규식은 `for f in *.sh; do` 만 보고 바로 아래의 `[ -e "$f" ] || continue` 를
  # 볼 수 없어서, 초판 self-test 가 known-negative 에서 오탐을 냈다(hits=1, expected 0).
  # 계기의 시야가 한 줄이면 두 줄짜리 관용구를 영영 오판한다 — 그래서 여기만 창을 넓힌다.
  while IFS= read -r line; do
    n="${line%%:*}"; body="${line#*:}"
    printf '%s' "$body" | grep -qE '#[[:space:]]*portability-noqa:[[:space:]]*[^[:space:]]' && continue
    # 주석 전용 줄 제외 — RULES 루프엔 넣고 여기엔 안 넣어서, 이 블록이 **자기 자신을 설명하는
    # 주석**을 소견으로 냈다(손검증이 잡음). 같은 이탈구는 두 루프에 **같이** 있어야 한다.
    case "$(printf '%s' "$body" | sed 's/^[[:space:]]*//')" in '#'*) continue ;; esac
    # 다음 2줄 안에 가드가 있으면 관용구를 지킨 것이다
    if sed -n "$((n+1)),$((n+2))p" "$f" 2>/dev/null \
         | grep -qE '\[ *-[efd] |\|\| *continue|nullglob'; then continue; fi
    # 파일 어딘가에 nullglob 이 켜져 있으면 전역적으로 해결된 것이다
    grep -qE '^[[:space:]]*shopt -s [a-z ]*nullglob' "$f" 2>/dev/null && continue
    _emit "  [P8] $f:$n"
    _emit "        glob 이 하나도 안 맞으면 **리터럴 문자열 자체**가 루프에 들어온다"
    _emit "        → 루프 첫 줄에 \`[ -e \"\$f\" ] || continue\`, 또는 shopt -s nullglob"
    _hits=$((_hits+1))
  done < <(grep -nE 'for [A-Za-z_][A-Za-z0-9_]* in [^;]*\*[^;)]*; *do' "$f" 2>/dev/null)

  # ── [P10] `tr` 집합 안의 «범위로 읽힐 수 있는» 하이픈 ────────────────────────────
  # 🟥 2026-08-30 실측, N=3 로 기계화. (번호: 초판이 이미 쓰인 P9 를 재사용해 충돌했다 — 실행해서 잡았다.) `tr -d '[:space:].·—-]'` 의 `—-]` 를 **범위**로 읽는
  #    구현이 있다(GNU tr). 그러면 그 범위에 든 바이트가 전부 삭제되고 — 한글 코퍼스에서는
  #    낱말 자체가 사라진다. macOS 는 리터럴로 읽어 통과하므로 **로컬만 초록이고 CI 에서 적색**이다.
  #    실제 피해: `defeater: 없음` 이 「1 낱말 공허」로 차단됐다(D6 레인, CI 전용 실패).
  # 판별: `tr` 인자 안에서 **양쪽에 문자가 있는 `-`**. 맨 앞/맨 뒤 하이픈은 리터럴이라 안전하고,
  #       `a-z`·`0-9` 같은 **의도된 범위**는 오탐이므로 뺀다.
  while IFS= read -r line; do
    n="${line%%:*}"; body="${line#*:}"
    printf '%s' "$body" | grep -qE '#[[:space:]]*portability-noqa:[[:space:]]*[^[:space:]]' && continue
    case "$(printf '%s' "$body" | sed 's/^[[:space:]]*//')" in '#'*) continue ;; esac
    # 의도된 ASCII 범위만 쓰는 줄은 통과
    printf '%s' "$body" | grep -qE "tr[^|]*'[^']*[a-zA-Z0-9]-[a-zA-Z0-9][^']*'" && continue
    _emit "  [P10] $f:$n"
    _emit "        \`tr\` 집합 안의 하이픈이 **범위**로 읽힐 수 있다(구현마다 다르다)."
    _emit "        비-ASCII 가 섞인 집합에서는 낱말이 통째로 지워진다 — 로컬만 초록이 된다."
    _emit "        → 하이픈을 **맨 뒤**로 옮기거나, \`tr\` 대신 셸 파라미터 확장을 써라."
    _hits=$((_hits+1))
  done < <(grep -nE "tr +-[a-z]* *'[^']*[^-'][-][^-'][^']*'" "$f" 2>/dev/null)

  # ── [P11] 비인용 heredoc 본문의 백틱 = 조용한 명령치환 ──────────────────────────
  # 🟥 2026-09-01, N=3 로 기계화(하루에 두 세션이 각각 겪었다).
  #    `cat <<EOF` 는 본문을 **확장**한다. 그래서 본문의 백틱은 문자열이 아니라 **명령**이다:
  #      · 그 명령이 없으면 → 그 자리가 **삭제**된다(문장이 문법적으로 멀쩡한 채 주어를 잃는다)
  #      · 있으면 → 출력이 **오삽입**된다
  #    실제 피해: 4축 마커의 한 낱말이 사라진 채 커밋됐다. 훅은 «필드 존재»만 보므로 안 막았다.
  # 🟥 처방이 「인용 heredoc(`<<'EOF'`)을 써라」가 **아닌** 이유: 사고는 «확장이 필요해서»
  #    비인용을 골랐을 때 난다. ⇒ **값을 미리 계산해 변수에 담고, 본문엔 변수만 넣어라.**
  # 판별이 좁다: 비인용 heredoc 본문의 **이스케이프되지 않은** 백틱은 언제나 명령치환이다.
  #    (\\` 는 리터럴이라 대상이 아니다 — 첫 실사용에서 그 형태 하나가 오탐으로 나왔다.)
  #    인용 형태(`<<'EOF'` · `<<"EOF"`)는 확장이 없으므로 대상이 아니다.
  # 🟥 python 은 **임시 파일**로 뺀다. 종전엔 `<(python3 - "$f" <<'P11PY' … )` 였는데
  #    **프로세스 치환 안의 heredoc** 은 셸이 못 판다 — 본문에 `)` 가 하나 들어간 순간
  #    `bad substitution` 으로 죽고, 이 린트는 그걸 삼켜 **「소견 없음」으로 렌더했다**(fail-open).
  #    이 스크립트가 잡으라고 존재하는 «조용한 즉사» 클래스를 자기가 저질렀다.
  # 🟥 2026-09-01 CI 가 잡았다: `mktemp -t p11py` 는 macOS 에서 통하고 **GNU 에서 죽는다**
  #    (`too few X's in template`). 이식성 린트 «안»의 이식성 결함이고, 이 린트가 잡으라고
  #    존재하는 클래스 그 자체다. 로컬은 초록이었다 — 「로컬 초록 ≠ CI 초록」.
  # 🟥 **이 수리는 이 머신에서 검증 불가다** — macOS mktemp 는 X 없는 템플릿도, X 있는
  #    템플릿도 «둘 다» 받는다(실측 rc=0/rc=0). 그러니 로컬 초록은 이 수리에 대해 아무것도
  #    증명하지 않는다. **GNU 동작의 유일한 계기는 CI 다.** 미검증이라고 적어둔다.
  _p11py=$(mktemp -t p11py.XXXXXX 2>/dev/null || mktemp) || _p11py=""
  if [ -n "$_p11py" ]; then
    cat > "$_p11py" <<'P11PY'
import re, sys
try:
    lines = open(sys.argv[1], encoding='utf-8', errors='replace').read().split('\n')
except OSError:
    sys.exit(0)
# 진짜 heredoc 여는 줄은 구분자 «뒤»에 줄끝이나 리다이렉션이 온다.
# 이 꼬리 조건이 없으면 `sed 's/.*<<VERDICT:...'` 같은 «heredoc 처럼 생긴 문자열»을
# 여는 줄로 읽고 파일 끝까지 heredoc 모드에 갇힌다 — 첫 실사용에서 오탐 119건이 났다.
open_re = re.compile(
    r"<<-?\s*(?P<q>['\"])?(?P<w>[A-Za-z_][A-Za-z0-9_]*)(?(q)(?P=q))\s*(?:[|>&;)]|$)")
delim = None
for i, l in enumerate(lines):
    if delim is None:
        m = open_re.search(l)
        if m and not m.group('q'):
            delim = m.group('w')
        continue
    if l.strip() == delim:
        delim = None
    else:
        # \U0001f7e5 이스케이프된 백틱(\\`)은 리터럴이라 명령치환이 아니다 — 첫 실사용에서
        #    유일하게 남은 소견이 정확히 그 형태였다(의도된 셸 shim 문자열).
        #    ⇒ 규칙 진술도 정정된다: 「비인용 heredoc 의 백틱은 언제나 명령치환」이 아니라
        #       **「이스케이프되지 않은 백틱은 언제나 명령치환」**이다.
        stripped = re.sub(r'\\.', '', l)   # 이스케이프 시퀀스(백슬래시+1문자)를 먼저 지운다
        if '\x60' in stripped:
            print(i + 1)
P11PY
    _p11out=$(python3 "$_p11py" "$f" 2>&1); _p11rc=$?
    rm -f "$_p11py"
    if [ "$_p11rc" != 0 ]; then
      _emit "  [UNMEASURED] $f — P11 검사기가 죽었다(rc=$_p11rc). 초록이 아니다."
      _emit "        $(printf '%s' "$_p11out" | head -1)"
    else
      for n in $_p11out; do
        body=$(sed -n "${n}p" "$f" 2>/dev/null)
        printf '%s' "$body" | grep -qE '#[[:space:]]*portability-noqa:[[:space:]]*[^[:space:]]' && continue
        _emit "  [P11] $f:$n"
        _emit "        비인용 heredoc 본문의 백틱은 **명령치환**이다 — 없으면 그 자리가 삭제된다."
        _emit "        → 값을 미리 계산해 변수에 담고 본문엔 변수만 넣어라."
        _hits=$((_hits+1))
      done
    fi
  else
    _emit "  [UNMEASURED] $f — P11 임시파일 생성 실패. 초록이 아니다."
  fi
}

# ── self-test (known-pair) ────────────────────────────────────────────────────
# 이 린트가 «무엇을 못 잡는지»까지 고정한다. 컨트롤이 없으면 초록의 이유를 모른다.
if [ "$SELFTEST" = 1 ]; then
  t=$(mktemp -d) || { echo "harness-error: mktemp"; exit 10; }
  trap 'rm -rf "$t"' EXIT
  pass=0; failn=0
  _ck(){ # _ck <label> <expect-hit:0|1> <file>
    _hits=0; QUIET=1; lint_file "$3"; QUIET=0
    if { [ "$2" = 1 ] && [ "$_hits" -gt 0 ]; } || { [ "$2" = 0 ] && [ "$_hits" -eq 0 ]; }; then
      echo "  ✅ $1"; pass=$((pass+1))
    else echo "  ❌ $1 (hits=$_hits, expected-hit=$2)"; failn=$((failn+1)); fi
  }
    # P1 known-positive — 오늘 `scripts/fh-gate.sh` 의 VERSION 할당이 정확히 이 형태였다.
  # ⚠️ 행번호를 적지 않는다: 초판은 `:37` 이라 적었는데 **같은 세션의 수리가 그걸 :52 로 밀었고**,
  # Axis 3 이 그 stale 참조를 잡았다. 이 커밋이 지적하는 결함 클래스의 자기재현이라 이름으로만 건다.
  printf 'set -euo pipefail\nV=$(sed -n s/x/y/p package.json 2>/dev/null | head -1)\n' > "$t/p1_pos.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  _ck "P1 known-positive (set -e + 명령치환 할당)" 1 "$t/p1_pos.sh"
  # P1 known-negative — || true 가 붙으면 안 잡아야 한다
  printf 'set -euo pipefail\nV=$(sed -n s/x/y/p f 2>/dev/null | head -1 || true)\n' > "$t/p1_neg.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  _ck "P1 known-negative (|| true 있음)" 0 "$t/p1_neg.sh"
  # P1 컨트롤 — set -e 가 없으면 애초에 해당 없음
  printf 'V=$(cat package.json)\n' > "$t/p1_nosete.sh"
  _ck "P1 컨트롤 (set -e 없음 → 해당없음)" 0 "$t/p1_nosete.sh"
  # P2 stat BSD-first
  printf 'm=$(stat -f %%m "$1" || stat -c %%Y "$1")\n' > "$t/p2_pos.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  _ck "P2 known-positive (stat -f 선행)" 1 "$t/p2_pos.sh"
  printf 'm=$(stat -c %%Y "$1" 2>/dev/null || echo 0)\n' > "$t/p2_neg.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  _ck "P2 known-negative (GNU-first)" 0 "$t/p2_neg.sh"
  # P11 known-positive — 비인용 heredoc 본문에 백틱 (2026-09-01 실사고 형태)
  #   🟥 픽스처를 printf 로 «조립»한다. 소스에 그대로 쓰면 이 파일 자신이 P11 에 걸린다 —
  #      계기가 자기 픽스처에 걸리는 것은 P1 초판이 이미 한 번 겪은 형태다.
  BQ=$(printf '\140')
  printf 'cat <<EOF\nvalue is %snproc%s\nEOF\n' "$BQ" "$BQ" > "$t/p11_pos.sh"
  _ck "P11 known-positive (비인용 heredoc + 백틱)" 1 "$t/p11_pos.sh"
  # P11 known-negative ① — 인용 heredoc 이면 확장이 없다
  printf "cat <<'EOF'\nvalue is %snproc%s\nEOF\n" "$BQ" "$BQ" > "$t/p11_neg_quoted.sh"
  _ck "P11 known-negative (인용 heredoc → 확장 없음)" 0 "$t/p11_neg_quoted.sh"
  # P11 known-negative ② — 비인용이지만 백틱이 없다
  printf 'cat <<EOF\nvalue is $VAR\nEOF\n' > "$t/p11_neg_nobq.sh"
  _ck "P11 known-negative (백틱 없음)" 0 "$t/p11_neg_nobq.sh"
  # P11 컨트롤 — heredoc «밖»의 백틱은 이 규칙 대상이 아니다(다른 결함일 수는 있다)
  printf 'x=%sdate%s\n' "$BQ" "$BQ" > "$t/p11_ctrl_outside.sh"
  _ck "P11 컨트롤 (heredoc 밖 백틱 → 해당없음)" 0 "$t/p11_ctrl_outside.sh"

  # P5 PIPESTATUS
  printf 'cmd | tail -1\nrc=${PIPESTATUS[0]}\n' > "$t/p5_pos.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  _ck "P5 known-positive (PIPESTATUS)" 1 "$t/p5_pos.sh"
  # P8 unguarded glob
  printf 'for f in scripts/*.sh; do\n  echo "$f"\ndone\n' > "$t/p8_pos.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  _ck "P8 known-positive (가드 없는 glob 루프)" 1 "$t/p8_pos.sh"
  printf 'for f in scripts/*.sh; do\n  [ -e "$f" ] || continue\ndone\n' > "$t/p8_neg.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  _ck "P8 known-negative (continue 가드)" 0 "$t/p8_neg.sh"
  # noqa 이탈구가 실제로 억제하나
  printf 'set -e\nV=$(cat package.json) # portability-noqa: 이 레포 전용 도구다\n' > "$t/noqa.sh"
  _ck "noqa 억제 동작" 0 "$t/noqa.sh"
  # 🟥 P3·P4·P6·P7·P9 는 초판에 레인이 **하나도 없었다** — 적대검증이 잡았다. 레인 없는 규칙은
  # 정규식에 오타를 내도 self-test 가 `10 pass / 0 fail` 그대로라, 판별력이 미측정이다.
  printf 'sed -i s/a/b/ f\n'            > "$t/p3_pos.sh"; _ck "P3 known-positive (sed -i GNU폼)" 1 "$t/p3_pos.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  printf 'sed -i.bak s/a/b/ f\n'        > "$t/p3_neg.sh"; _ck "P3 known-negative (접미사 있음)" 0 "$t/p3_neg.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  printf 'grep -P "\\d+" f\n'           > "$t/p4_pos.sh"; _ck "P4 known-positive (grep -P)" 1 "$t/p4_pos.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  printf 'grep -E "[0-9]+" f\n'         > "$t/p4_neg.sh"; _ck "P4 known-negative (grep -E)" 0 "$t/p4_neg.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  printf 'p=$(readlink -f "$1")\n'      > "$t/p6_pos.sh"; _ck "P6 known-positive (readlink -f)" 1 "$t/p6_pos.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  printf 'p=$(cd "$(dirname "$1")" && pwd -P)\n' > "$t/p6_neg.sh"; _ck "P6 known-negative (pwd -P)" 0 "$t/p6_neg.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  printf 'd=$(date -d @123 +%%s)\n'      > "$t/p7_pos.sh"; _ck "P7 known-positive (date -d)" 1 "$t/p7_pos.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  printf 'd=$(date +%%s)\n'              > "$t/p7_neg.sh"; _ck "P7 known-negative (date +%s)" 0 "$t/p7_neg.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  printf 'run_review "package.json"\n'  > "$t/p9_pos.sh"; _ck "P9 known-positive (레포고유 픽스처)" 1 "$t/p9_pos.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  printf 'run_review "$t/fixture.json"\n' > "$t/p9_neg.sh"; _ck "P9 known-negative (자기 픽스처)" 0 "$t/p9_neg.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  # 🟥 P10 — `tr` 집합 안의 «범위로 읽힐 수 있는» 하이픈. 2026-08-30 CI 전용 실패에서 나왔다:
  #    `tr -d '[:space:].·—-]'` 가 GNU 에서 범위로 읽혀 한글이 지워졌고 `defeater: 없음` 이
  #    「1 낱말 공허」로 차단됐다. macOS 는 리터럴로 읽어 **로컬만 초록**이었다.
  printf 'x=$(printf %%s "$b" | tr -d \x27[:space:].\xc2\xb7\xe2\x80\x94-]\x27)\n' > "$t/p10_pos.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  _ck "P10 known-positive (하이픈이 범위로 읽힌다)" 1 "$t/p10_pos.sh"
  printf 'y=$(printf %%s "$b" | tr -d \x27[:space:].\xc2\xb7]\x27)\n' > "$t/p10_neg.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  _ck "P10 known-negative (하이픈 없음 = 리터럴)" 0 "$t/p10_neg.sh"
  # 🟥 컨트롤 — 의도된 ASCII 범위(a-z)는 오탐이면 안 된다. 없으면 «전부 잡는 계기»와 구분 안 된다.
  printf 'z=$(printf %%s "$b" | tr \x27a-z\x27 \x27A-Z\x27)\n' > "$t/p10_ctl.sh"  # portability-noqa: self-test 픽스처 — 일부러 위반형을 쓴다
  _ck "P10 control (의도된 a-z 범위는 오탐 아님)" 0 "$t/p10_ctl.sh"

  # 🟥 로케일 fail-open — cross-family 가 실측으로 잡은 것. 비-UTF8 바이트가 섞인 줄을
  # UTF-8 로케일에서 돌려도 검출돼야 한다(lint_file 이 LC_ALL=C 로 고정하므로).
  printf 'set -e\nV=$(cat package.json)\n\xff\n' > "$t/nonutf.sh"
  ( export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8; _ck "비-UTF8 바이트 (UTF-8 로케일에서도 검출)" 1 "$t/nonutf.sh" )

  # 끊어진 심링크 — 조용한 «소견 없음» 이 아니라 UNMEASURED 로 나와야 한다
  ln -s "$t/does_not_exist.sh" "$t/broken.sh" 2>/dev/null
  _bo=$(QUIET=0; _hits=0; lint_file "$t/broken.sh"); case "$_bo" in
    *UNMEASURED*) echo "  ✅ 끊어진 심링크 → UNMEASURED"; pass=$((pass+1)) ;;
    *) echo "  ❌ 끊어진 심링크가 조용히 통과했다"; failn=$((failn+1)) ;;
  esac

  # 빈 파일 — 계기가 아무 데나 울리지 않는가
  : > "$t/empty.sh"
  _ck "빈 파일 (오탐 없음)" 0 "$t/empty.sh"
  # 종결 verdict 한 줄 — selfcheck.sh 의 --self-test 루프가 이 문자열로 «실제로 돌았다»를 판정한다.
  # 규약(그 루프의 주석): 이 줄은 **진짜 종결 판정**이어야 하고 한국어 테스트케이스 *제목*이면
  # 안 된다. 제목이면 그 레인 이름 하나만 바꿔도 진짜 PASS 가 거짓 "dispatcher missing?" 으로
  # 뒤집힌다(capability_registry_check 가 그 이유로 루프에서 빠졌다). 그래서 여기 딱 한 번,
  # 요약 자리에서만 쓴다.
  if [ "$failn" -eq 0 ]; then
    echo "portability-lint 캘리브레이션 통과: $pass pass / 0 fail"
    exit 0
  fi
  echo "portability-lint 캘리브레이션 실패: $pass pass / $failn fail"
  exit 1
fi

# ── 본 실행 ───────────────────────────────────────────────────────────────────
if [ "${#TARGETS[@]}" -eq 0 ]; then
  while IFS= read -r f; do TARGETS+=("$f"); done < <(
    { git ls-files '*.sh' 'templates/.git-hooks/*' 'bin/*' 2>/dev/null \
      || find . \( -name '*.sh' -o -path './templates/.git-hooks/*' -o -path './bin/*' \) \
           -not -path './.git/*' 2>/dev/null; } )
fi
[ "${#TARGETS[@]}" -gt 0 ] || { _emit "portability-lint: 대상 파일 0 — 잴 것이 없다(초록이 아니라 미측정)"; exit 0; }

_emit "── portability-lint (${#TARGETS[@]} files) ──"
for f in "${TARGETS[@]}"; do
  [ -f "$f" ] || { [ -L "$f" ] && lint_file "$f"; continue; }
  # 🟥 확장자 없는 셸 파일을 넣었으므로(templates/.git-hooks/pre-commit·pre-push, bin/fh-*)
  # 비-셸 파일(.js 등)을 걸러야 한다. 판별은 확장자가 아니라 **shebang** 이다.
  # 초판은 `git ls-files '*.sh'` 뿐이라 **이 레포에서 BSD/GNU 결함이 가장 비싼 두 파일**
  # (pre-commit·pre-push)을 구조적으로 못 봤다 — 그리고 같은 커밋의 selfcheck 주석이
  # «첫 스캔이 확장자 없는 훅을 놓쳤다»고 적어 놓고서 새 계기에 같은 스코프를 다시 심었다.
  case "$f" in
    *.sh) : ;;
    *) head -1 "$f" 2>/dev/null | grep -qE '^#!.*\b(ba)?sh' || continue ;;
  esac
  lint_file "$f"
done

if [ "$_hits" -eq 0 ]; then
  _emit "  소견 없음 (${#TARGETS[@]} files 스캔)"
  exit 0
fi
_emit "── 소견 $_hits 건 ──"
_emit "  advisory 다 — 이 린트만으로 막지 않는다. 알고 쓰는 줄엔 \`# portability-noqa: <사유>\`."
[ "$STRICT" = 1 ] && exit 1
exit 0
