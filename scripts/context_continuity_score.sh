#!/usr/bin/env bash
# context_continuity_score.sh — 압축 후 「모델이 여전히 답할 수 있는가」를 격리해서 잰다.
#
# ── 왜 이것이 필요했나 (기존 계기는 «미보정»이 아니라 «반증»이다) ──
#   `compaction_probe.sh` 의 `score` 는 transcript 를 grep 한다. 그런데 2026-08-08 실측에서
#   압축 후에도 transcript 파일이 히스토리를 **전부 보존**한다는 것이 확정됐다
#   (user 109 · assistant 238 레코드 보존 · 압축 구조 필드 0건). 그러므로 그 채점기는
#   **손실 0 을 영원히 보고한다 — fail-open.** 그 파일 자신이 `:25` 에서 처방까지 적어뒀다:
#   *"채점을 하려면 전사본이 아니라 «모델이 여전히 답할 수 있는가»를 물어야 하고,
#     그건 훅이 못 한다(격리 채점자 필요 — 미건축)."*  이 스크립트가 그 미건축분이다.
#
# ── 🟥 이름부터 정확히: 이것은 «압축 보존률»이 아니라 «운반체 충분성»이다 ──
#   cross-family 리뷰(gpt-5.5, 2026-08-30)가 첫 번째로 지목한 대리측정 위험이고, 맞다:
#   seal 은 **압축의 산출물이 아니라 압축 직전에 따로 쓴 문서**다. 그러므로 PASS 가 말하는 것은
#   「압축이 보존했다」가 아니라 **「사전에 쓴 포인터 원장이 충분했다」**이다.
#   ⇒ 이 스크립트의 출력을 «압축이 N% 를 잃었다»로 옮겨 적으면 그 순간 거짓이 된다.
#   ✅ 잰다   : 운반체(seal + 카드 + 상주 파일)만 쥔 격리 세션이 사전등록 질문에 답하는가
#   🟥 안 잰다: ⓐ 압축 자체의 보존 ⓑ 「의미가 보존됐나」(채점은 **토큰** 유무이지 이해가 아니다
#              — 접으면 `[[feedback_metric_measures_presence_not_relation]]`)
#
# ── 명명된 잔여 3건 (cross-family 지목, 자력 적발 0 — 숨기지 않는다) ──
#   R1 대리측정      : 위 §이름 참조. PASS = 원장 충분성이지 압축 보존이 아니다
#   R2 커버리지 구멍 : known-pair 는 **최소 생존성**만 본다. 질문에 안 걸린 하중 맥락,
#                     seal 에 포인터만 있고 주변조건이 빠진 항목, 카드·규칙만으로 추론 가능한
#                     항목은 여전히 「보존됨」처럼 보인다
#   R3 저자 편향     : 저자가 **seal 과 질문 셋을 둘 다 고르면** 통과할 것만 고르게 된다.
#                     🟢 완화 절반: seal 은 훅이 기계로 쓴다(사람이 고르지 않는다).
#                     🟢 완화 나머지: **질문 셋을 다른 계열이 출제**한다(2026-08-30 부터 gemini).
#                     ⚠️ 완화이지 폐쇄가 아니다 — 채점기 코드는 여전히 저자 것이다
#
# ── 🟥 이 채점기가 먼저 죽을 수 있는 자리 — known-pair 가 생사다 ──
#   known-negative(어느 운반체에도 없는 사실)를 팔이 **지어내면**, 「보존됨」과 「그럴듯하게
#   추측함」이 구분되지 않는다. 그 회차는 **전량 VOID** 이고 숫자를 내지 않는다.
#   기존 계기가 죽은 이유와 같은 축이다 — 계기가 무엇을 재는지 모른 채 숫자를 냈다.
#
# ── 🟥 두 질문은 다르다 — 2026-08-30 첫 실사용이 갈라냈다 ──
#   ⓐ **발견 가능한가**  (기본): seal 을 클론에 심고 «아무것도 안 알려준다».
#      실측 결과 **못 찾는다** — `tracks/**` 가 gitignored 라 gitignore 를 존중하는 검색은
#      seal 을 **0건**으로 낸다(일반 `grep -r` 은 찾는다). 즉 seal 은 **검색으로 도달 불가능한
#      자리**에 쓰이고, 오직 훅이 경로를 찍어줄 때만 닿는다.
#      → `[[feedback_instrument_not_on_the_path]]` 의 «운반체» 판.
#   ⓑ **건네주면 충분한가** (`--deliver`): 훅이 하듯 프롬프트에 경로를 얹는다.
#      이쪽이 «운반체 충분성»의 본 질문이다.
#   🟥 훅은 일회용 클론에서 안 돈다(러너 헤더에 실측 기록). 그래서 ⓑ 를 «재현»하는 것이고
#      «훅을 검증하는 것»이 아니다 — 그 구분을 접지 마라.
#
# ── 팔 (한 변수) ──
#   ARM   운반체 있음 : 클론 + seal 주입          → 「운반체 덕에 아는가」
#   CTRL  운반체 없음 : 클론만 (seal 주입 안 함)   → 「레포만으로도 아는가」
#   두 팔의 차이가 **seal 의 기여분**이다. 한 변수만 다르다(seal 파일의 유무).
#
# ── 사용 ──
#   bash scripts/context_continuity_score.sh --seal <seal.md> --qset <qset.tsv> [--reps 3]
#   bash scripts/context_continuity_score.sh --self-test
#
# ── qset 형식 (TSV, 사전등록해서 봉인한다) ──
#   <id>\t<kind>\t<질문>\t<기대토큰>
#   kind = positive : 운반체에 있다. 기대토큰이 답에 **나와야** 한다
#   kind = negative : 어느 운반체에도 없다. **거절 토큰이 나와야** 하고 기대토큰이 나오면 환각
#                     (기대토큰 칸에는 «지어냈다면 나올 법한» 문자열을 적는다)
#
# ⚠️ 이 스크립트는 훅에 배선돼 있지 않다. 사람이 돌린다 — 계기가 사는지부터 봐야 하므로
#    자동 실행은 이 회차의 범위가 아니다. 「배선됐다」고 적지 마라.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$HERE/scripts/sim_isolated_run.sh"

SEAL=""; QSET=""; REPS=1; MODEL="sonnet"; OUT=""; DELIVER=0
SELFTEST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --seal)  SEAL="${2:-}"; shift 2 ;;
    --qset)  QSET="${2:-}"; shift 2 ;;
    --reps)  REPS="${2:-1}"; shift 2 ;;
    --model) MODEL="${2:-sonnet}"; shift 2 ;;
    --out)   OUT="${2:-}"; shift 2 ;;
    --deliver) DELIVER=1; shift ;;   # 훅이 경로를 찍어주는 상황을 재현. 아래 §두 질문 참조
    --self-test) SELFTEST=1; shift ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

# 거절 어휘 — 「모른다」의 표현들. 🟥 목록이지 판정이 아니다.
# ⚠️ **방향이 kind 마다 반대다.** negative 에서 빠진 표현은 «환각으로 오채점»(과차단, 안전) 이지만,
#    positive 에서 빠지면 «거절문에 토큰이 들었는데 PASS»(거짓 통과, 위험) 가 된다.
# 🟥 2026-08-30 실측: 초판에 `찾을 수 없` 은 있고 **`찾지 못` 이 없어서** 팔의
#    *"어디에서도 'undine' 을 찾지 못했습니다"* 가 PASS 로 채점됐다. 저자가 자기 어휘로만
#    목록을 짜면 자기가 안 쓰는 표현이 빠진다 — 오늘 같은 축으로 세 번째다.
#    ⇒ 이 목록은 **실제 팔 출력에서 관측된 표현**을 넣어 늘린다. 상상해서 늘리지 마라.
REFUSE_RE='모르|알 수 없|없습니다|없다|찾을 수 없|찾지 못|못 찾|기록이 없|나와 있지 않|확인할 수 없|언급이 없|존재하지 않|not (found|available)|unknown|cannot (tell|determine)|could(n.t| not) find|no (such|mention)'

# ─────────────────────────────────────────────────────────────────────
# score_one — 한 답변 파일을 한 질문에 대해 채점한다. 순수 함수(파일만 읽는다).
#   출력: PASS | FAIL | HALLUCINATED | VOID
# ─────────────────────────────────────────────────────────────────────
score_one() {
  local ans_file="$1" kind="$2" token="$3"
  [ -s "$ans_file" ] || { echo VOID; return 0; }        # 빈 출력은 «아니오»가 아니다
  local body; body="$(cat "$ans_file")"
  local has_tok=0 has_ref=0
  printf '%s' "$body" | grep -qF -- "$token" && has_tok=1
  printf '%s' "$body" | grep -qiE -- "$REFUSE_RE" && has_ref=1
  case "$kind" in
    positive)
      # 🟥 2026-08-30 첫 실사용이 잡은 오채점: 팔이 «'undine' 을 찾지 못했습니다» 라고 답하면
      #    토큰이 문장 안에 있으므로 종전 규칙은 PASS 를 냈다. 「답에 X 가 있다」와
      #    「X 를 못 찾았다고 말한다」가 구분되지 않았다 —
      #    `[[feedback_metric_measures_presence_not_relation]]` 그대로다.
      if [ "$has_tok" = 1 ] && [ "$has_ref" = 0 ]; then echo PASS
      elif [ "$has_tok" = 1 ]; then echo REFUSED_WITH_TOKEN
      else echo FAIL; fi ;;
    negative)
      # 환각이 먼저다: 지어냈으면 거절 문구가 같이 있어도 환각이다
      if [ "$has_tok" = 1 ]; then echo HALLUCINATED
      elif [ "$has_ref" = 1 ]; then echo PASS
      else echo FAIL; fi ;;
    *) echo VOID ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────
if [ "$SELFTEST" = 1 ]; then
  T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
  P=0; F=0
  chk(){ if [ "$2" = "$3" ]; then P=$((P+1)); echo "  ✅ $1"; else F=$((F+1)); echo "  ❌ $1 (got=$2 want=$3)"; fi; }

  printf '봉인된 정본은 reference_next_session_starter.md 입니다.\n' > "$T/a1"
  chk "L1 positive 토큰 있음 → PASS" "$(score_one "$T/a1" positive 'reference_next_session_starter')" PASS
  chk "L2 positive 토큰 없음 → FAIL" "$(score_one "$T/a1" positive 'nonexistent_token_xyz')" FAIL

  printf '그 정보는 기록에 없습니다. 확인할 수 없습니다.\n' > "$T/a2"
  chk "L3 negative 거절 → PASS" "$(score_one "$T/a2" negative '42줄')" PASS

  printf '마지막으로 읽은 파일은 42줄이었습니다.\n' > "$T/a3"
  chk "L4 negative 지어냄 → HALLUCINATED" "$(score_one "$T/a3" negative '42줄')" HALLUCINATED

  # 🟥 환각 우선 규칙: 지어내고 «나서» 얼버무려도 환각이다
  printf '42줄 정도로 보이는데, 정확히는 알 수 없습니다.\n' > "$T/a4"
  chk "L5 negative 지어낸 뒤 거절 → HALLUCINATED (환각 우선)" \
      "$(score_one "$T/a4" negative '42줄')" HALLUCINATED

  : > "$T/a5"
  chk "L6 빈 출력 → VOID («아니오»가 아니다)" "$(score_one "$T/a5" positive 'x')" VOID
  chk "L7 빈 출력 negative 도 VOID" "$(score_one "$T/a5" negative 'x')" VOID

  printf '그런 건 없다고 봅니다만 몰라요.\n' > "$T/a6"
  chk "L8 negative 토큰없음+거절 → PASS" "$(score_one "$T/a6" negative '42줄')" PASS

  printf '그냥 아무 말이나 합니다.\n' > "$T/a7"
  chk "L9 negative 토큰없음+거절없음 → FAIL (모른다고 말하지 않았다)" \
      "$(score_one "$T/a7" negative '42줄')" FAIL

  # 🟥 첫 실사용이 찾은 오채점의 앵커 — 토큰이 «거절문 안에» 있는 경우
  printf "저장소 어디에서도 'undine' 을 찾지 못했습니다.\n" > "$T/a9"
  chk "L11 positive 토큰이 거절문 안 → REFUSED_WITH_TOKEN (PASS 아님)" \
      "$(score_one "$T/a9" positive 'undine')" REFUSED_WITH_TOKEN

  printf "그 예시의 이름은 undine 입니다.\n" > "$T/a10"
  chk "L12 positive 진짜 답 → PASS (컨트롤: L11 과 한 변수만 다르다)" \
      "$(score_one "$T/a10" positive 'undine')" PASS

  # 🟥 첫 실사용이 찾은 구멍의 앵커 — 「다른 문자열로 지어낸」 답은 PASS 가 아니어야 한다.
  #    출제된 기대토큰이 `홍길동` 인데 모델이 `김철수` 라고 답하는 실제 형태다.
  printf '발표자는 김철수 부장입니다.\n' > "$T/a8"
  chk "L10 negative 다른 이름으로 지어냄 → FAIL (PASS 아님이 요점)" \
      "$(score_one "$T/a8" negative '홍길동')" FAIL

  echo; echo "SELFTEST: $P passed, $F failed"
  [ "$F" = 0 ] || exit 1
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────
[ -n "$SEAL" ] && [ -f "$SEAL" ] || { echo "🟥 --seal <실재 파일> 필요" >&2; exit 2; }
[ -n "$QSET" ] && [ -f "$QSET" ] || { echo "🟥 --qset <실재 파일> 필요" >&2; exit 2; }
[ -x "$RUNNER" ] || [ -f "$RUNNER" ] || { echo "🟥 러너 없음: $RUNNER" >&2; exit 2; }

OUT="${OUT:-$(mktemp -d -t cc-score)}"
mkdir -p "$OUT"
SEAL_ABS="$(cd "$(dirname "$SEAL")" && pwd)/$(basename "$SEAL")"

echo "── context_continuity_score ─────────────────────────────────"
echo "seal=$(basename "$SEAL")  reps=$REPS  model=$MODEL"
echo "out=$OUT"
echo

# 운반체 스테이징: ARM 은 클론 «안»에 seal 을 심는다. CTRL 은 안 심는다. 그 한 칸이 변수다.
SETUP_ARM="mkdir -p tracks/_meta/compaction && cp '$SEAL_ABS' tracks/_meta/compaction/"

n=0; declare -a ROWS=()
while IFS=$'\t' read -r qid kind question token; do
  case "$qid" in ''|'#'*) continue ;; esac
  n=$((n+1))
  for arm in ARM CTRL; do
    setup=""; [ "$arm" = ARM ] && setup="$SETUP_ARM"
    q="$question"
    if [ "$DELIVER" = 1 ] && [ "$arm" = ARM ]; then
      q="[직전 압축 전 봉인 원장: tracks/_meta/compaction/$(basename "$SEAL") — 필요하면 열어라]
$question"
    fi
    args=(--arm "${qid}_${arm}" --reps "$REPS" --model "$MODEL" --out "$OUT" --prompt "$q")
    [ -n "$setup" ] && args+=(--setup "$setup")
    bash "$RUNNER" "${args[@]}" >/dev/null 2>&1
    for r in $(seq 1 "$REPS"); do
      f="$OUT/${qid}_${arm}_r${r}.txt"
      v="$(score_one "$f" "$kind" "$token")"
      ROWS+=("$qid|$kind|$arm|r$r|$v")
    done
  done
done < "$QSET"

printf '%-10s %-9s %-5s %-4s %s\n' QID KIND ARM REP VERDICT
for row in "${ROWS[@]}"; do IFS='|' read -r a b c d e <<<"$row"; printf '%-10s %-9s %-5s %-4s %s\n' "$a" "$b" "$c" "$d" "$e"; done

# ── known-pair 게이트: 계기가 살아있나. 🟥 여기서 죽으면 숫자를 «안 낸다» ──
HALL=$(printf '%s\n' "${ROWS[@]}" | grep -c 'HALLUCINATED' || true)
NEG_ARM_TOT=$(printf '%s\n' "${ROWS[@]}" | grep -c '|negative|ARM|' || true)
# 🟥 2026-08-30 첫 실사용이 찾은 구멍: negative 의 기대토큰은 «지어냈다면 나올 법한» 한 문자열인데,
#    모델은 **다른 문자열**을 지어낸다(출제된 `홍길동` 대신 아무 이름이나). 그러면 토큰이 안 걸려
#    HALLUCINATED 가 아니라 FAIL 로 떨어지고, 환각만 보던 게이트를 **조용히 통과**한다.
#    ⇒ negative 는 «거절했다(PASS)»가 아니면 전부 막는다. 설계 리뷰가 못 잡고 실물 문항이 잡았다.
NEG_ARM_BAD=$(printf '%s\n' "${ROWS[@]}" | grep '|negative|ARM|' | grep -vc 'PASS' || true)
POS_ARM_PASS=$(printf '%s\n' "${ROWS[@]}" | grep '|positive|ARM|' | grep -c 'PASS' || true)
POS_ARM_TOT=$(printf '%s\n' "${ROWS[@]}" | grep -c '|positive|ARM|' || true)

echo
echo "── known-pair 게이트 ──"
  echo "  known-negative 비-PASS   : $NEG_ARM_BAD / $NEG_ARM_TOT  (그중 정확일치 환각 $HALL)"
echo "  known-positive ARM PASS  : $POS_ARM_PASS / $POS_ARM_TOT"
if [ "$NEG_ARM_BAD" -gt 0 ]; then
  echo; echo "🟥 VOID — known-negative 에서 «모른다»가 안 나왔다 ($NEG_ARM_BAD/$NEG_ARM_TOT)."
  [ "$HALL" -gt 0 ] && echo "   그중 $HALL 건은 출제된 문자열 그대로 지어냈다(HALLUCINATED)."
  echo "   「보존됨」과 「그럴듯하게 추측함」이 구분되지 않는다 — 숫자를 내지 않는다."
  exit 3
fi
if [ "$POS_ARM_TOT" -gt 0 ] && [ "$POS_ARM_PASS" -lt "$POS_ARM_TOT" ]; then
  echo; echo "🟡 채점기 미완성 — known-positive 가 만점이 아니다."
  echo "   🟥 이것을 「운반체가 부실하다」로 읽지 마라. 팔이 운반체를 못 읽는 것일 수 있다."
  exit 4
fi
echo; echo "🟢 계기 생존 — 이제부터의 숫자는 «운반체가 나른 것»을 가리킨다."
exit 0
