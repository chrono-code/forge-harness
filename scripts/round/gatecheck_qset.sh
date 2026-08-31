#!/usr/bin/env bash
# 개시 게이트 선통과 확인 — 회차 «전»에 돌린다. 출제자에게 넘기는 검사기.
#
# 🟥 2026-08-31 재작성. 초판은 **두 겹으로 틀렸다**:
#   겹1  `git grep` 을 썼다 → **tracked 만** 본다. 팔이 받는 건 `.git` 을 포함한 클론 전체다.
#   겹2  ⚠️ **이 겹은 스크립트에 «해당 없다» — 측정해서 좁혔다.** 대화형 zsh 의 `grep` 은
#        셸 함수(RTK 래퍼)라 `-r` 에서 닷디렉터리를 건너뛴다(실측 0히트). 그러나 **bash 스크립트
#        안에서는 그 함수가 안 보이고** `grep` 이 `/usr/bin/grep` 으로 풀린다(실측 4히트, `type -t`
#        = `file`). ⇒ 이 파일이 초판에서 못 잡은 원인은 **겹1 하나**다.
#        `/usr/bin/grep` 을 «절대경로로» 박는 것은 그래서 수리가 아니라 **방어**다 —
#        누가 이 로직을 대화형 셸이나 zsh 스크립트로 옮겨도 같은 답을 내게 한다.
#        🟥 안 그런 척하지 않는다: 이 줄이 고친 결함은 겹1 이고 겹2 는 여기 없었다.
#   실측(같은 문자열 `probe4/base`, 클론 대상):
#        .git/HEAD 직접 = 1 · 셸 grep -rl = 0 · git grep = 0 · **/usr/bin/grep -rl = 4**
#   ⇒ 대상은 **실제 클론**, 계기는 **`/usr/bin/grep`**(절대경로. 셸 함수를 우회한다).
#   실피해: 브랜치명을 기대토큰으로 낸 문항이 «0 히트»로 통과했다 — CTRL 이 원장 없이 주울 수
#   있으므로 **저자에게 유리한 방향의 거짓 초록**이다.
#
# 🟥 컨트롤은 «있음»이 아니라 «판별»이라야 한다. 초판 컨트롤은 `CLAUDE.md`(닷디렉터리 «밖»)라
#    바로 이 맹점을 판별하지 못했다 — 살아 있었는데도 못 잡았다.
#    ⇒ K+ 를 **닷디렉터리 안에만 있는 문자열**(클론의 브랜치명)로 바꾼다.
set -uo pipefail
# 🟥 `IFS=$'\t' read` 를 «쓰지 않는다» — 탭이 IFS 공백류라 **빈 칸이 접히고 값이 밀린다**.
#    실측: `a\tb\tc\t\tE\tF` → read 는 c4=[E] c5=[F] (한 칸 밀림) · awk -F'\t' 는 c4=[] c5=[E] (정상).
#    🟥 이번 qset 은 positive 8 행의 5·6열이 «비어» 있어서 그대로 두면 조용히 틀린다.
#    🟥 그리고 빈 칸이 없으면 «안 드러난다» — 앞선 게이트 네 번이 같은 파서로 전부 통과했다.
#    ⇒ awk 로 탭을 `|` 로 바꿔 넘긴다(빈 칸이 보존된다). 값에 `|` 가 없어야 하고, 그건 아래에서 검사한다.
_tsv_pipe(){ LC_ALL=C awk -F'\t' 'BEGIN{OFS="|"} {for(i=1;i<=NF;i++) if($i ~ /\|/){print "PIPE_IN_VALUE:" NR > "/dev/stderr"; exit 3} $1=$1; print}' "$1"; }
Q="${1:?usage: gatecheck_qset.sh <qset.tsv> [seal] [pre|post]}"; SEAL="${2:-}"
# 🟥 시점을 «인자로» 가른다 (검토 조건 ③). conflict 토큰은 **심기 전엔 봉인 0 이 정상**이고
#    **심은 후엔 present 가 정상**이다. 한 검사로 뭉치면 둘 중 한 시점에서 반드시 거짓 경보다.
PHASE="${3:-post}"
# ── --pin: 대상 고정 (2026-09-01 배선) ────────────────────────────────────────
# 🟥 왜 여기냐. 오늘 이 게이트가 **낡은 qset 을 정상적으로 검사해서 정상적으로 통과**시켰다.
#    계기는 안 고장났고 «대상이 그 대상인가»를 아무도 안 물었다. 같은 얼굴이 하루 3회
#    ⇒ N>=3 이라 산문이 아니라 코드다. gate-locality: 검사는 **행위자가 읽는 곳**에 있어야 한다.
# 사용: gatecheck_qset.sh <qset> [seal] [pre|post] [qset-sha12] [seal-sha12]
#       핀을 «안 주면» 검사를 건너뛴다 — 🟥 그건 통과가 아니라 UNVERIFIED 다. 그렇게 찍는다.
_PIN_Q="${4:-}"; _PIN_S="${5:-}"
# ── 이름 누출 검사 (2026-09-01 배선) ─────────────────────────────────────────
# 🟥 «심는 값 검사와 같은 자리» — 회차를 열지 «말지»를 정하는 지점이다.
#    회차2 는 검사기가 없어서가 아니라 **아무도 안 물어서** 뚫렸다.
# 🟥 fail-closed: 스크립트가 없으면 «skipped» 가 아니라 실패다.
#    (부재를 스킵으로 렌더하면 [[feedback_not_found_is_not_zero_family]] 그대로다)
# 사용: gatecheck_qset.sh <qset> [seal] [pre|post] [qset-sha12] [seal-sha12] [out-dir] [arm-label]
_NL_OUT="${6:-}"; _NL_ARM="${7:-}"
_NL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nameleak_check.sh"
[ -x "$_NL" ] || _NL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../scripts/round" 2>/dev/null && pwd)/nameleak_check.sh"
if [ -n "$SEAL" ]; then
  if [ ! -x "$_NL" ]; then
    echo "🟥 nameleak_check.sh 없음/실행불가 — 회차를 열지 않는다 (스킵 아님)" >&2; exit 5
  fi
  if [ -n "$_NL_OUT" ] && [ -n "$_NL_ARM" ]; then
    if ! bash "$_NL" "$(basename "$SEAL")" "$_NL_OUT" "$_NL_ARM"; then
      echo "🟥 이름 누출 — 회차를 열지 않는다" >&2; exit 5
    fi
  else
    # 🟥 out-dir·라벨을 «안 준» 경우: seal 이름만이라도 본다. 그리고 «검사 못 한 칸»을 이름으로 남긴다.
    if ! bash "$_NL" "$(basename "$SEAL")" "$(bash "$_NL" gen)" "$(bash "$_NL" gen)"; then
      echo "🟥 이름 누출(seal) — 회차를 열지 않는다" >&2; exit 5
    fi
    echo "⚠️  nameleak  out-dir·라벨 UNVERIFIED — 인자를 안 줬다(통과가 아니다)"
  fi
fi
if [ -n "$_PIN_Q" ]; then
  bash "$(dirname "${BASH_SOURCE[0]}")/target_pin.sh" "$Q" "$_PIN_Q" >/dev/null || {
    echo "🟥 PIN FAIL (qset) — 게이트를 돌리지 않는다. 최신본을 받아라" >&2
    bash "$(dirname "${BASH_SOURCE[0]}")/target_pin.sh" "$Q" "$_PIN_Q" >&2
    exit 4; }
  echo "🟢 PIN qset  $(shasum -a 256 "$Q" | cut -c1-16)"
else
  echo "⚠️  PIN qset  UNVERIFIED — 핀을 안 줬다(통과가 아니다)"
fi
if [ -n "$SEAL" ] && [ -n "$_PIN_S" ]; then
  bash "$(dirname "${BASH_SOURCE[0]}")/target_pin.sh" "$SEAL" "$_PIN_S" >/dev/null || {
    echo "🟥 PIN FAIL (seal) — 게이트를 돌리지 않는다. 최신본을 받아라" >&2
    bash "$(dirname "${BASH_SOURCE[0]}")/target_pin.sh" "$SEAL" "$_PIN_S" >&2
    exit 4; }
  echo "🟢 PIN seal  $(shasum -a 256 "$SEAL" | cut -c1-16)"
elif [ -n "$SEAL" ]; then
  echo "⚠️  PIN seal  UNVERIFIED — 핀을 안 줬다(통과가 아니다)"
fi
case "$PHASE" in pre|post) ;; *) echo "🟥 phase 는 pre|post (받은 값: $PHASE)"; exit 2 ;; esac
R="$(git rev-parse --show-toplevel)"
GREP=/usr/bin/grep
[ -x "$GREP" ] || { echo "🟥 $GREP 없음 — 셸 함수로 대체하지 않는다(맹점). 중단."; exit 2; }

# 대상 = 팔이 실제로 받는 것. 러너와 «같은 방식»으로 만든다.
C=$(mktemp -d); trap 'rm -rf "$C"' EXIT
git clone --quiet --local --no-hardlinks "$R" "$C/repo" 2>/dev/null || { echo "🟥 클론 실패 — 중단"; exit 2; }
hits(){ "$GREP" -rlF -- "$1" "$C/repo" 2>/dev/null | wc -l | tr -d ' '; }

# ── 컨트롤 먼저. 죽어 있으면 아래 «0 히트»는 청결이 아니라 계기 사망이다 ──────────
KP=$(sed 's|ref: refs/heads/||' "$C/repo/.git/HEAD" 2>/dev/null)   # 닷디렉터리 안에만 있다
# 🟥 K- 는 «생성»한다. 리터럴로 박으면 이 파일이 tracked 가 되는 순간 클론 안에
#    실재해서 컨트롤이 죽는다 — 2026-09-01 실측(1421ca0 이 이 파일을 tracked 로 만들자
#    박아둔 'zzNoSuchTokZZ' 가 히트 1 이 되어 게이트가 exit 2 로 멈췄다).
#    부재 토큰은 «없다고 믿는 문자열»이 아니라 «방금 만든 문자열»이어야 한다.
KNEG="zzABSENT$$_$(date +%s%N 2>/dev/null || date +%s)zz"
kp=$(hits "$KP"); kn=$(hits "$KNEG")
printf '컨트롤  K+(닷디렉터리 전용 "%s")=%s  K-(부재)=%s\n' "$KP" "$kp" "$kn"
if [ "$kp" -le 0 ] || [ "$kn" != 0 ]; then
  echo "🟥 계기 사망 — 닷디렉터리를 못 보거나 오탐이 있다. 아래 숫자를 믿지 마라."; exit 2
fi
echo

# ── 🟥 지시대상(referent) 축 — 2026-08-31 회차1 VOID 가 만든 검사 ──────────────────
#    회차1 은 12/12 게이트를 «통과하고도» negative 축이 구조적으로 죽었다. 실패가 고르지
#    않고 **문항 둘에 몰렸다**(N01 10/10 FAIL · N03 8/10 FAIL vs N02·N04 대부분 PASS).
#    근인은 기대토큰 오염이 아니라 **질문의 «지시대상»** 이다: 「원장에 기록된 PR 번호는?」이
#    묻는 그 범주의 **실재 사례가 클론에 있다**(`subagent_invocations_log.yaml` 340KB, tracked,
#    PR 번호 형태 68건). 팔은 지어낸 게 아니라 **실재 문서를 자신 있게 인용**했다.
#    ⇒ 종전 게이트는 «기대토큰»만 봤고 **질문의 주어는 안 봤다.**
#
# 🟥 **완전 자동은 안 된다** — 「PR 번호」라는 구절을 클론에서 찾아봐야 0 히트다. 클론에 있는
#    것은 구절이 아니라 **사례**(`#560`)다. 범주→사례 패턴 매핑은 판단이다.
#    ⇒ 판단을 **출제자에게** 넘기고(그는 다른 계열이다) 기계는 **집행만** 한다:
#      qset 5번째 열 `probe` = 「이 문항이 묻는 범주의 사례를 잡는 패턴」(ERE).
#      negative·conflict 는 **필수**. 없으면 차단(fail-closed — 검증 못 한 것을 통과시키지 않는다).
#      positive 는 advisory — 그 범주는 «원장에 있어야» 정상이라 축이 반대다.
# 🟥 2026-08-31 회차1 사후 — 이 정규식 축은 **UNCALIBRATED** 다. 「검증됐다」고 적지 마라.
#    known-pair 가 안 갈렸다: N01·N03(부적격) 과 N02·N04(적격)를 **넷 다 차단**한다.
#    그리고 히트 «수»가 관측을 설명 못 한다 — 원장 안으로 좁혀도 N03(4) < N04(7) 인데
#    N03 이 실패했다. **방향이 반대다.**
#    실물이 말한 진짜 판별자는 «범주의 존재»가 아니라 **«지시대상 적합»** 이다:
#      N04_CTRL "리뷰어 핸들을 기록하는 «원장» 파일 자체가 존재하지 않습니다" ← 범주는 82파일에 있다
#      N03      팔이 «실패한 테스트 스위트»를 문자 그대로 기록한 문서를 찾았다
#    ⇒ 「어떤 문서를 «그 원장»이라 부를 수 있으면서 이 질문에 답하는가」는 **정규식으로 원리적
#      으로 못 잰다.** 그래서 이 축은 **advisory 사전선별**로만 남긴다 — 싸고, N01(68건,
#      압도적)은 잡는다. **차단은 `eligcheck_qset.sh`(실측 게이트)가 한다.**
ref_probe(){ "$GREP" -rlE -- "$1" "$C/repo" 2>/dev/null | wc -l | tr -d ' '; }

# ── 🟥 중복 기대토큰 (2026-08-31 신설) — 출제 재작업에서 실제로 났다 ──────────────────
#    codex 재출제분이 P05/P06/P08 에 앞선 문항과 «같은» 기대토큰을 냈다. 근인은 반려문이
#    **실물 토큰을 예시로 보여준 것**이고(출제자가 그걸 권장 답으로 읽었다), 그건 우리가 하루
#    종일 센 «정답키 누출»의 프롬프트 판이다. 사람이 눈으로 잡았다 — 손으로 한 단계는 다음
#    회차에서 빠진다(ⓖ1 과 같은 근거로 기계화한다).
#    🟥 중복이 왜 나쁜가: 같은 토큰이 두 문항에 있으면 **두 문항이 독립이 아니다.** 문항 단위
#    독립을 가정한 임계(Fisher N)가 그 순간 거짓이 된다.
# 🟥 `LC_ALL=C` 는 장식이 아니다 — 이 로케일(en_US.UTF-8)에서 **awk 의 `==` 가 서로 다른
#    한글 문자열을 «같다»고 판정한다**(실측: `"파란카드"=="레몬게이트"` → 참. ASCII 는 정상).
#    같은 로케일에서 `uniq` 도 두 줄을 한 줄로 접는다. 다른 팔의 중복 검사가 그래서
#    24문항 중 **14개를 거짓 중복으로 오보**했다(LC_ALL=C 로 다시 재니 중복 0).
#    🟢 이 줄은 «배열 키»(해시=바이트 정확)라 지금 구현에서는 안 접힌다 — 실측 확인했다.
#    🟥 **그래도 박는다**: 그건 이 awk 구현의 성질이지 «awk 의 계약»이 아니다(gawk/mawk/BSD 가
#    다를 수 있다). 그리고 누가 이걸 `$4==prev` 로 «단순화»하면 그 순간 뚫린다.
#    ⚠️ 이건 오늘의 «셸 이름-경계» 일가와 **다른 축**이다: 그건 「어디까지가 이름인가」,
#    이건 「두 문자열이 같은가」. 공통점은 **비ASCII 에서만 조용히 틀린다**는 것뿐이다.
_dup=$(LC_ALL=C awk -F'\t' 'NF>=4 && $1!~/^#/ && $1!="" {if(seen[$4]++) print $1}' "$Q")
if [ -n "$_dup" ]; then
  echo "🟥 중복 기대토큰 — 두 문항이 독립이 아니다. 임계(Fisher N)가 거짓이 된다:"
  printf '%s\n' "$_dup" | sed 's|^|     중복: |'
  bad_dup=1
else bad_dup=0; fi

bad=$bad_dup; unchecked=0
printf '%-4s %-9s %-8s %-8s %s\n' QID KIND CLONE REF NOTE
while IFS='|' read -r qid kind q tok general probe; do
  case "$qid" in ''|'#'*) continue;; esac
  [ -n "${tok:-}" ] || continue
  n=$(hits "$tok"); note=""
  [ "$n" != 0 ] && { note="🟥 클론 오염 — 팔이 주울 수 있다"; bad=1; }
  # ── 🟥 봉인 원장 쪽 검사 (2026-08-31 신설, 검토자 승인) ────────────────────────
  #    이번 회차엔 이 검사를 **사람이 손으로** 했다. 손으로 한 단계는 다음 회차에서 빠진다.
  #    그리고 실패가 **무음이고 방향이 있다**: negative 토큰이 우연히 봉인문에 있으면 팔이
  #    «옳게» 인용하는데 채점기는 HALLUCINATED 를 찍어 **DELIVERY 에 없는 결함**이 생긴다
  #    (저자에게 불리한 쪽으로 조용하다). ⇒ 새 파일 없이 여기 3줄로 넣는다.
  if [ -z "$SEAL" ]; then
    note="$note ⚠️ 봉인 미지정 — 원장 쪽 미검사(UNCHECKED, 통과 아님)"; unchecked=$((unchecked+1))
  elif [ "$kind" = positive ]; then
    sp=$("$GREP" -cF -- "$tok" "$SEAL" 2>/dev/null); [ -n "$sp" ] || sp=0
    [ "$sp" -ge 1 ] || { note="$note 🟥 positive 인데 원장에 없다 — 팔이 답할 근거가 없다"; bad=1; }
  elif [ "$kind" = negative ]; then
    sn=$("$GREP" -cF -- "$tok" "$SEAL" 2>/dev/null); [ -n "$sn" ] || sn=0
    [ "$sn" = 0 ] || { note="$note 🟥 negative 인데 원장에 있다 — 옳은 인용이 환각으로 찍힌다"; bad=1; }
  fi
  if [ "$kind" = conflict ] && [ -n "$SEAL" ]; then
    # 🟥 `|| echo 0` 을 쓰지 마라 — `grep -c` 는 **0 을 찍고 rc=1 로 죽는다.** 그러면 값이
    #    "0\n0" 이 되어 `[ "$s" = 0 ]` 이 **거짓**이 되고, 이 분기는 「심겼다」로 통과시킨다.
    #    방향이 **fail-open** 이다(안 심긴 conflict 문항이 게이트를 통과한다).
    #    ⇒ 출력과 rc 를 분리해서 받는다 ([[feedback_pipefail_fallback_disarms_guard]]).
    s=$("$GREP" -cF -- "$tok" "$SEAL" 2>/dev/null); [ -n "$s" ] || s=0
    if [ "$PHASE" = post ]; then
      [ "$s" = 0 ] && { note="$note 🟥 심은 값이 운반체에 없다(post)"; bad=1; } || note="$note (운반체에 ${s}회 심김)"
    else
      [ "$s" = 0 ] && note="$note (pre: 아직 안 심김 — 정상)" || { note="$note 🟥 심기 «전»인데 이미 있다 — «틀린 값»이 아니다"; bad=1; }
    fi
  fi
  # ── 지시대상 축 ──
  refn="-"
  case "$kind" in
    negative|conflict)
      if [ -z "${probe:-}" ]; then
        note="$note ⚠️ probe 열 없음 — 정규식 사전선별 생략(advisory). 차단은 eligcheck 가 한다"; refn="-"
      else
        refn=$(ref_probe "$probe")
        [ "$refn" != 0 ] && note="$note ⚠️ 사전선별: 그 범주 사례가 클론에 $refn 파일 (advisory · UNCALIBRATED)"
      fi ;;
    positive)
      if [ -n "${probe:-}" ]; then refn=$(ref_probe "$probe")
        [ "$refn" = 0 ] && note="$note ⚠️ positive 인데 그 범주가 클론에 0 — advisory(차단 아님)"
      fi ;;
  esac
  printf '%-4s %-9s %-8s %-8s %s\n' "$qid" "$kind" "$n" "$refn" "$note"
done < <(_tsv_pipe "$Q")

echo
# 🟥 `UNCHECKED` 를 «통과»로 렌더하지 않는다. 봉인 미지정이면 원장 쪽 계약(positive 는 원장에
#    있어야·negative 는 없어야·conflict 는 심겼어야)이 **한 건도 검사되지 않았다.**
#    「선통과」라고만 찍으면 읽는 사람이 «다 봤다»로 읽는다 — 오늘 우리가 센 그 얼굴이다.
if [ "$bad" != 0 ]; then echo "🟥 이 세트로 회차를 열면 안 된다"; exit 1
elif [ "$unchecked" != 0 ]; then
  echo "🟡 부분 통과 — 클론 오염 축은 통과, **원장 축 ${unchecked}건 UNCHECKED**(봉인 미지정)."
  echo "   🟥 심은 뒤 seal 을 주고 phase=post 로 «다시» 돌려라. 지금은 회차를 열 수 없다."
  exit 3
else echo "🟢 개시 게이트 선통과"; fi
