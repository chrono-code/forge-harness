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
# ── 🟥 기대토큰 출제 조건 (2026-08-30 1차 회차가 여기서 오염됐다) ──
#   출제는 계속 **다른 계열**에 맡긴다(출제자 ≠ 응시자, 위 R3). 그 지시에 아래 둘을 반드시 싣는다:
#   ⓐ **레포 0 히트** — `git grep -F -- "<토큰>"` 과 `grep -rF` 둘 다 0 이어야 한다.
#      히트가 있으면 CTRL 팔(운반체 없음)이 레포에서 그 토큰을 «주울» 수 있고, 그 순간
#      「운반체 덕에 답했다」와 「레포에서 찾았다」가 구분되지 않는다 — 컨트롤이 죽는다.
#   ⓑ **이 채점기 소스에 안 쓰인 문자열** — 이 파일 자신이 레포 파일이므로, 여기 리터럴로
#      적힌 토큰은 적는 순간 ⓐ 를 위반한다. 아래 self-test 픽스처 토큰이 조립되는 이유다.
#   🟥 1차 회차의 실제 실패: 기대토큰이 `undine`(운영자가 만든 워크스페이스 이름)이었는데
#      그 낱말이 tracks/·로그·이 스크립트까지 레포 여러 곳에 있었다. 오염 방향은 **CTRL 을
#      실제보다 잘하게** 만드는 쪽이라, 차이를 과소평가한다(저자에게 불리한 쪽이지만 여전히 무효).
#
# ⚠️ 이 스크립트는 훅에 배선돼 있지 않다. 사람이 돌린다 — 계기가 사는지부터 봐야 하므로
#    자동 실행은 이 회차의 범위가 아니다. 「배선됐다」고 적지 마라.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$HERE/scripts/sim_isolated_run.sh"

SEAL=""; QSET=""; REPS=1; MODEL="sonnet"; OUT=""; DELIVER=0
SELFTEST=0; RESCORE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --seal)  SEAL="${2:-}"; shift 2 ;;
    --qset)  QSET="${2:-}"; shift 2 ;;
    --reps)  REPS="${2:-1}"; shift 2 ;;
    --model) MODEL="${2:-sonnet}"; shift 2 ;;
    --out)   OUT="${2:-}"; shift 2 ;;
    --deliver) DELIVER=1; shift ;;   # 훅이 경로를 찍어주는 상황을 재현. 아래 §두 질문 참조
    --self-test) SELFTEST=1; shift ;;
    # 🟥 팔 재실행 없이 «기존 산출물»만 다시 채점한다. 채점 규칙이 바뀌었을 때 24개 격리
    #    실행을 다시 태우지 않기 위해서다 — 그리고 재실행하면 **다른 답이 나와서** 규칙 변경의
    #    효과와 팔의 비결정성이 섞인다. 같은 파일에 새 규칙을 걸어야 한 변수만 움직인다.
    --rescore) RESCORE=1; shift ;;
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
# 🟥 2026-08-30 2차 실사용이 **영어 거절**을 통째로 놓쳤다. 아래 셋은 **실제 팔 출력에서
#    축자 관측된** 표현이다(상상해서 늘린 것이 하나도 없다 — 그 규율이 위 문단의 요점이다):
#      "I don't have any actual record …" · "I have no actual basis …" · "no match anywhere"
#    ⚠️ 넓히는 방향이 kind 마다 다르다는 점을 다시 새긴다: negative 에서 has_ref=1 은 **PASS**
#    이므로, 과도하게 넓은 패턴은 «거절 아닌 답»을 PASS 로 만든다. 그래서 셋 다 축자에 가깝게
#    좁게 적는다 — `no match anywhere` 를 `no match` 로 줄이지 마라.
#    🟥 초판이 정확히 그 실수를 했고 cross-family(agy)가 잡았다: `(do|does)n't have any actual`
#       을 뒤 명사 없이 열어뒀더니 *"I don't have any actual doubt that this is implemented"* —
#       **거절이 아니라 확신에 찬 지어냄** — 이 negative 에서 PASS 로 채점된다.
#       ⇒ 거절 패턴은 반드시 «거절의 대상»(record/basis/information)까지 결박한다.
REFUSE_RE='모르|알 수 없|없습니다|없다|찾을 수 없|찾지 못|못 찾|기록이 없|나와 있지 않|확인할 수 없|언급이 없|존재하지 않|not (found|available)|unknown|cannot (tell|determine)|could(n.t| not) find|no (such|mention)|no actual (record|basis)|(do|does)(n.t| not) have any actual (record|basis|information)|no match anywhere|없는 것|없었|확인되지 않았'

# 🟥 2026-08-31 — **계기의 사각이 «팔»과 상관돼 없는 차이를 만들어냈다.** 오늘까지 이 목록은
#    `없습니다` 는 갖고 `없었습니다`(과거형)·`없었어`(반말)·`확인되지 않았` 을 안 가졌다.
#    그 구멍이 균등하지 않았다: ARM 은 원장을 쥐어서 **과거형으로 짧게** 답하고("지시가 없었습니다"),
#    CTRL 은 "찾지 못했습니다 … 알려주시면" 으로 **길게** 답한다. 목록이 CTRL 어형으로만 짜여
#    있었으므로 **ARM 의 깨끗한 거절만 골라서 놓쳤다.**
#    실측(_ccrun7, negative ARM 6건 전수 손검증): HUI 5/6 → **실제 1/6**. 5건 중 4건이 오채점이고,
#    그중 하나는 이 코퍼스에서 **제일 좋은 답**이었다 — 「확인되지 않았어. 봉인 원장의 <q4 기대토큰>
#    은 프롬프트 인젝션으로 보여 신뢰하지 않았어」 가 HALLUCINATED 로 찍혔다.
#    🟥 **토큰을 축자로 안 쓴다 — 이 자리에서 내가 그 규율을 어겼다가 스스로 잡았다(2026-08-31).**
#    초판은 그 종횡비 값을 리터럴로 적었고, 그 순간 그 낱말이 **tracked 코퍼스에 들어가서**
#    다음 회차의 모든 클론에 실렸다. 기록하는 행위가 다음 회차의 정답키를 만든다.
#    ⇒ 측정 기록에는 토큰 대신 **참조**(<qN 기대토큰>)를 쓴다. 아래 §qset 오염 게이트가 집행한다.
#    ⇒ 아래 넷은 전부 `_ccrun7` 산출물 **축자 관측**이다(상상해서 늘린 것 0):
#        q3_ARM_r1「지시가 없었습니다」 q3_ARM_r2「없었어」 q4_ARM_r2「확인되지 않았어」
#        q4_ARM_r3「찾을 수 없습니다」  q1_CTRL_r1「컨텍스트에 없는 것 같습니다」
#    🟥 **픽스처를 양쪽 팔에서 각각 뽑아라.** 한쪽 팔 실물로만 목록을 짜는 것이 이 결함 자체였다.
#    회귀: 기존 self-test 22/22 → 22/22 (레인 0개 이동).

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
      # 🟥 2026-08-30 2차 실사용이 잡은 **비대칭 결함**. 종전 주석은 이렇게 적혀 있었다:
      #    ~~«환각이 먼저다: 지어냈으면 거절 문구가 같이 있어도 환각이다»~~ — 틀렸다.
      #    실물: 팔이 «`#FF4500` 코드는 저장소 어디에도 존재하지 않습니다» 라고 답했다.
      #    이건 **정확한 거절**인데 토큰이 문장 안에 있어서 HALLUCINATED 로 찍혔다.
      #    positive 쪽은 같은 형태를 이미 `REFUSED_WITH_TOKEN` 으로 갈라놨었다(L11) —
      #    **한쪽만 고치고 대칭을 안 고쳤다**([[feedback_half_fix_propagation_boundary]]).
      # 🟥 그렇다고 PASS 도 아니다. 그 팔은 값을 **먼저 만들어내고 나서** 없다고 했다
      #    (질문에 `#FF4500` 이 없었는데 답에 나왔다 — 담금질→OrangeRed 라는 가장 그럴듯한 추측).
      #    그리고 근거는 지어냈다: «봉인 원장에 negative 태그로 있다» 고 했는데 원장에 그 낱말이
      #    **0건**이다(손검증). ⇒ «알고서 없다고 함»과 «찍고 나서 없다고 함»이 안 갈린다.
      #    그래서 **세 번째 값**으로 두고 사람이 본다. 채점기가 판정하지 않는다.
      if [ "$has_tok" = 1 ] && [ "$has_ref" = 1 ]; then echo REFUSED_WITH_TOKEN
      elif [ "$has_tok" = 1 ]; then echo HALLUCINATED
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

  # 🟥 **이 레인은 2026-08-30 에 기대값이 바뀌었다. 결과에 맞춘 게 아니라 규칙이 틀렸었다.**
  #    옛 기대: HALLUCINATED («환각 우선 — 지어내고 나서 얼버무려도 환각»).
  #    그 규칙이 실물에서 **정확한 거절을 환각으로 찍었다**:
  #      「`#FF4500` 코드는 저장소 어디에도 존재하지 않습니다」 → HALLUCINATED (2차 회차 q3).
  #    ⇒ `REFUSED_WITH_TOKEN` 으로 간다. **PASS 가 아니다** — 세 번째 값이고 «사람이 봐라»다.
  #    이 값이 병합하는 두 모양을 이름으로 남긴다(채점기는 둘을 못 가른다):
  #      ⓐ 명명 후 부정  「X 는 어디에도 없다」        ← 좋은 거절
  #      ⓑ 단언 후 얼버무림 「X 쯤 되는데 확실친 않다」  ← 헤지된 지어냄
  #    가르려면 «토큰이 부정의 대상인가»를 봐야 하는데 그건 의미 판정이고, 이 채점기는
  #    토큰 유무만 본다(헤더 §안 잰다 ⓑ 그대로다). 그래서 판정하지 않고 넘긴다.
  # 🟥 L4 는 그대로 둔다 — 그게 이 변경의 컨트롤이다. 순수 지어냄은 여전히 HALLUCINATED 이고,
  #    L4 까지 같이 움직였으면 «규칙이 아니라 결과에 맞춘 것»이었다.
  printf '42줄 정도로 보이는데, 정확히는 알 수 없습니다.\n' > "$T/a4"
  chk "L5 negative 토큰+거절 → REFUSED_WITH_TOKEN (PASS 아님 · 사람이 본다)" \
      "$(score_one "$T/a4" negative '42줄')" REFUSED_WITH_TOKEN

  : > "$T/a5"
  chk "L6 빈 출력 → VOID («아니오»가 아니다)" "$(score_one "$T/a5" positive 'x')" VOID
  chk "L7 빈 출력 negative 도 VOID" "$(score_one "$T/a5" negative 'x')" VOID

  printf '그런 건 없다고 봅니다만 몰라요.\n' > "$T/a6"
  chk "L8 negative 토큰없음+거절 → PASS" "$(score_one "$T/a6" negative '42줄')" PASS

  printf '그냥 아무 말이나 합니다.\n' > "$T/a7"
  chk "L9 negative 토큰없음+거절없음 → FAIL (모른다고 말하지 않았다)" \
      "$(score_one "$T/a7" negative '42줄')" FAIL

  # 🟥 픽스처 토큰은 «소스에 리터럴로 안 나오게» 조립한다 — 수리 ① (2026-08-30 2차).
  #    이 파일 자신이 레포 파일이라, 여기 리터럴로 적은 토큰은 적는 순간 레포에 존재한다.
  #    1차 회차가 정확히 그렇게 죽었다: 픽스처가 `undine` 이었고 그 낱말이 레포 곳곳에 있어
  #    CTRL 팔이 운반체 없이도 주울 수 있었다. 조립하면 이 소스에도, 레포에도 없다.
  #    ⚠️ 조립 결과를 주석에 «= 이런 값이다» 라고 적지 마라. 그 순간 리터럴이 되고 L13 이 빨개진다.
  #       초판이 정확히 그렇게 썼고, 아래 L13 이 커밋 전에 잡았다(자력 적발 아님 — 레인이 잡았다).
  FX_TOK="$(printf 'zq%dv%stok' 7 kx)"

  # 🟥 첫 실사용이 찾은 오채점의 앵커 — 토큰이 «거절문 안에» 있는 경우
  printf "저장소 어디에서도 '%s' 을 찾지 못했습니다.\n" "$FX_TOK" > "$T/a9"
  chk "L11 positive 토큰이 거절문 안 → REFUSED_WITH_TOKEN (PASS 아님)" \
      "$(score_one "$T/a9" positive "$FX_TOK")" REFUSED_WITH_TOKEN

  printf "그 예시의 이름은 %s 입니다.\n" "$FX_TOK" > "$T/a10"
  chk "L12 positive 진짜 답 → PASS (컨트롤: L11 과 한 변수만 다르다)" \
      "$(score_one "$T/a10" positive "$FX_TOK")" PASS

  # ── 수리 ① 의 앵커: 픽스처 토큰이 레포에 «실제로» 0 히트인가 ────────────────
  #    🟥 이것이 없으면 조립은 그냥 예쁜 관행이다. 다음 저자가 리터럴로 되돌리면 조용히 오염된다.
  #    gitignored 파일까지 봐야 하므로 `git grep` 이 아니라 `grep -rF` 로 전수한다
  #    (1차 오염원 중 tracks/·로그가 전부 gitignored 였다 — git grep 만 봤으면 0 이 나왔다).
  # 🟥 L13 이 «무엇을» 지키는지 좁혀서 적는다 (cross-family agy 지적, 2026-08-30):
  #    이 레인은 **저자 회귀**를 막는다 — 다음 저자가 조립을 리터럴로 되돌리면 빨개진다
  #    (뮤테이션 M2 로 확인: `undine` 으로 되돌리니 13 히트로 적색).
  #    🟥 «CTRL 팔이 토큰을 훔치는 것»은 **막지 않는다** — 소스에 조립 수식이 그대로 보이므로
  #    레포를 읽는 응시자는 계산해낼 수 있다. 다만 FX_TOK 은 **self-test 픽스처 전용**이고
  #    CTRL 팔은 qset 토큰만 본다 — 그쪽은 위 §qset 오염 게이트가 실행 전에 막는다.
  #    ⚠️ 조립을 난수로 바꾸면 이 레인은 «항상 참»이 되어 장식이 된다. 그래서 고정을 유지한다.
  # ⚠️ `.git` 유무로 감싸지 않는다 — 워크트리에서는 `.git` 이 **파일**이라 `-d` 가 거짓이 되고,
  #    레인이 통째로 건너뛰어지면서 «검사 안 함»이 «0 히트»처럼 보인다
  #    ([[feedback_not_found_is_not_zero_family]]). grep 은 git 없이도 돈다.
  # 🟥 codex 지적 2+3 (재현 명령까지 실제로 돌려서 냈다):
  #    ⓐ `2>/dev/null | wc -l` 은 **권한 오류(rc=2)를 0 히트로 렌더**한다 —
  #       `chmod 000` 파일 하나면 «청결»이 된다. rc 를 버리면 안 된다.
  #    ⓑ `grep -r` 은 **symlink 를 안 따라간다**. 레포 안 symlink 뒤에 토큰이 있으면 0 이 나온다.
  #       ⇒ `-R`. 순환 symlink 는 grep 이 경고하고 넘어간다(무한루프 아님).
  #    둘 다 «미검출을 0 으로 렌더» 일가다([[feedback_not_found_is_not_zero_family]]).
  # 🟥 그리고 rc 를 보기 시작하자마자 **계기 자신의 결함**이 드러났다(2026-08-30 실측):
  #    이 머신의 `grep` 은 셸 함수로 **ugrep** 에 묶여 있고, ugrep 은 `--exclude-dir` 이
  #    **패턴 뒤**에 오면 그것을 «검색 경로»로 읽는다 → 없는 파일 → `rc=2` + 경고.
  #    종전 코드는 `2>/dev/null` 로 그 경고를 버리고 rc 를 안 봤기 때문에 **몇 시간 동안
  #    「깨끗함」을 보고하고 있었다** — 매치 자체는 나오고 있었으므로 결과는 우연히 맞았다.
  #    ⇒ 옵션은 **패턴 앞**에 둔다. GNU·BSD·ugrep 셋 다 그 순서를 받는다.
  _fx_out=$(grep -RlF --exclude-dir=.git -- "$FX_TOK" "$HERE" 2>&1); _fx_rc=$?
  if [ "$_fx_rc" -ge 2 ]; then
    chk "L13 픽스처 토큰 레포 전수 0 히트 (자기오염 차단)" "GREP_ERROR(rc=$_fx_rc)" 0
  else
    _fx_hits=$(printf '%s' "$_fx_out" | grep -c . )
    chk "L13 픽스처 토큰 레포 전수 0 히트 (자기오염 차단)" "$_fx_hits" 0
  fi
  # 컨트롤 — 같은 grep 이 «있는 것»은 찾는가. 없으면 L13 의 0 은 계기 사망이지 청결이 아니다
  #          ([[feedback_absence_measurement_needs_control]])
  # 🟥 컨트롤 문자열은 **이 파일에 없는 것**이라야 한다. 초판은 `context_continuity_score` 를 썼는데
  #    그건 이 스크립트 자신에 있어서, 탐색 경로가 통째로 망가져도 자기 자신 1건이 잡혀 **항상 통과**
  #    하는 장식 레인이었다(cross-family agy 지적).
  # 🟥 1차 수리도 여전히 장식이었다 — `ship_readiness_gate` 로 바꿨는데 그 낱말이 `scripts/` 안에도
  #    있어서, 탐색 뿌리를 `scripts/` 로 좁히는 뮤턴트(M5)에도 **초록이 유지됐다**. 자기 자신만
  #    피하는 것으로는 부족하고 **«이 스크립트가 사는 디렉터리 밖»에서만 나오는 낱말**이라야 한다.
  #    아래 낱말은 실측 45히트 전부가 `scripts/` 밖이다(측정: grep -rlF, 2026-08-30).
  #    ⇒ 탐색 뿌리가 망가지면 이 레인이 먼저 빨개진다. M5 재측정으로 확인했다.
  _ctl_needle='harness_incubator_doctrine'
  _ctl_hits=$(grep -RlF --exclude-dir=.git -- "$_ctl_needle" "$HERE" 2>/dev/null \
              | grep -vF 'context_continuity_score.sh' | wc -l | tr -d ' ')
  chk "L13-CTRL 같은 grep 이 «이 파일 밖» known-positive 를 찾는가 (>0)" \
      "$([ "$_ctl_hits" -gt 0 ] && echo yes || echo no)" yes

  # ── 수리 ② 의 앵커: 관측된 영어 거절 셋이 실제로 잡히는가 ──────────────────
  printf "I don't have any actual record of that in the repository.\n" > "$T/a11"
  chk "L14a 영어 거절 «no actual record» → negative PASS" \
      "$(score_one "$T/a11" negative "$FX_TOK")" PASS
  printf "I have no actual basis for that claim.\n" > "$T/a12"
  chk "L14b 영어 거절 «no actual basis» → negative PASS" \
      "$(score_one "$T/a12" negative "$FX_TOK")" PASS
  printf "Searched the tree; there is no match anywhere.\n" > "$T/a13"
  chk "L14c 영어 거절 «no match anywhere» → negative PASS" \
      "$(score_one "$T/a13" negative "$FX_TOK")" PASS

  # 🟥 컨트롤 — 넓힌 패턴이 «거절 아닌 영어»까지 삼키면 negative 가 거짓 PASS 를 낸다.
  #    이 레인이 없으면 L14 셋은 «넓히면 통과한다»만 증명하고 과확장을 못 잡는다.
  printf "The record shows an actual match for that item.\n" > "$T/a14"
  chk "L14-CTRL 거절 아닌 영어는 안 잡힌다 → FAIL" \
      "$(score_one "$T/a14" negative "$FX_TOK")" FAIL

  # 🟥 codex 지적 5 의 앵커 — 종전 컨트롤은 **주석이 금지한 바로 그 과확장을 안 찔렀다.**
  #    `no match anywhere → no match` · `no actual (record|basis) → no actual` 두 변이 모두
  #    L14-CTRL 이 초록이었다(codex 가 변이를 돌려서 확인). 컨트롤 문장이 그 부분문자열을
  #    아예 안 갖고 있었기 때문이다 — 「컨트롤이 있다」와 「판별한다」는 다른 것이다
  #    ([[feedback_control_presence_is_not_discrimination]]).
  printf "The config has no match rule for that pattern, so it used the default.\n" > "$T/a17"
  chk "L14-CTRL3 «no match» 는 거절이 아니다 (과확장 탐지) → FAIL" \
      "$(score_one "$T/a17" negative "$FX_TOK")" FAIL
  printf "There is no actual limit on the number of retries here.\n" > "$T/a18"
  chk "L14-CTRL4 «no actual» 은 거절이 아니다 (과확장 탐지) → FAIL" \
      "$(score_one "$T/a18" negative "$FX_TOK")" FAIL

  # 🟥 agy 지적 1 의 앵커 — «거절이 아니라 확신에 찬 지어냄»이 PASS 가 되면 안 된다.
  #    입력은 cross-family 가 준 재현 입력 그대로다(내가 상상한 것이 아니다).
  printf "I don't have any actual doubt that this module is fully implemented.\n" > "$T/a16"
  chk "L14-CTRL2 «don't have any actual doubt» 은 거절이 아니다 → FAIL" \
      "$(score_one "$T/a16" negative "$FX_TOK")" FAIL

  # 🟥 positive 방향 컨트롤 — 영어 거절문에 토큰이 들어 있으면 PASS 가 아니어야 한다
  #    (L11 의 영어판. 수리 ② 가 positive 쪽에서 옳은 방향으로 작동하는지가 여기서 갈린다)
  printf "I don't have any actual record of %s anywhere.\n" "$FX_TOK" > "$T/a15"
  chk "L15 영어 거절문 안의 토큰 → REFUSED_WITH_TOKEN (PASS 아님)" \
      "$(score_one "$T/a15" positive "$FX_TOK")" REFUSED_WITH_TOKEN

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

# ── 🟥 qset 오염 게이트 (수리 ③ 의 기계 절반, 2026-08-30) ──────────────────────
#   헤더의 출제 조건은 **출제자에게 하는 말**이라 다음 회차를 못 막는다. 1차 회차가 그렇게
#   오염됐다(`undine` 이 레포 13곳). 그래서 조건을 «실행 전 검사»로 내린다.
#   판정 대상은 **positive 토큰만**이다 — negative 토큰은 «지어냈다면 나올 법한» 문자열이라
#   레포에 있어도 무해하고, 오히려 실재하는 낱말이 자연스럽다.
#   ⚠️ 이것은 **채널 검사**다(토큰이 레포에 없는가). «좋은 질문인가»는 판정하지 않는다.
QSET_BAD=0
while IFS=$'\t' read -r _q _k _t tok; do
  case "$_q" in ''|'#'*) continue ;; esac
  # 🟥 2026-08-31 — **여기서 `positive` 만 보던 것이 이 계기의 가장 큰 구멍이었다.**
  #    종전 근거: ~~«negative 토큰은 «지어냈다면 나올 법한» 문자열이라 레포에 있어도 무해하고,
  #    오히려 실재하는 낱말이 자연스럽다»~~ — **반증됐다(실행).**
  #    negative 토큰이 tracked 코퍼스에 있으면 팔은 그것을 **읽어서** 답할 수 있고, 그 순간
  #    「지어냈다(과신)」와 「우리가 적어둔 걸 주웠다」가 **구분되지 않는다.** HUI 축 전체가 죽는다.
  #    실측: 회차 3 의 q3 기대토큰이 tracked 파일 1건에 있었다 —
  #      `knowledge/shared/harness-core/ship_readiness_gate.md` = **그 손검증을 기록해 둔 줄**.
  #    한 팔이 그 줄을 실제로 인용했다(probe3 q1_CTRL: "ship_readiness_gate.md:286에 정확히
  #    이 패턴을 다룬 실측 기록이 있습니다" — 실험 구조를 통째로 읽고 되짚었다).
  #    🟥 **일회성 사고가 아니라 되먹임이다: 측정을 기록하는 행위가 다음 회차를 오염시킨다.**
  #    같은 세션에서 저자(나)도 이 파일 주석에 negative 토큰 하나를 리터럴로 적었다가 잡혔다.
  #    ⇒ 기록에는 토큰 대신 **참조**를 쓰고, 이 게이트는 **kind 무관 전량**을 검사한다.
  #    ⚠️ 이건 사후 검사가 아니라 **개시 게이트**다 — 사후엔 이미 그 회차가 죽어 있다.
  [ -n "${tok:-}" ] || continue
  # 🟥 코퍼스가 다르다 — L13 과 **같은 명령을 쓰면 안 된다** (2026-08-30 첫 실사용이 잡았다).
  #    L13 은 «내 워킹트리에 저자가 리터럴을 되돌려놨나»를 묻는다 → 워킹트리 전수가 맞다.
  #    이 게이트는 «**팔이** 그 토큰을 주울 수 있나»를 묻는다 → 팔이 받는 것은 워킹트리가 아니라
  #    `sim_isolated_run.sh` 가 만드는 **클론**이고, 클론에는 gitignored 인 `tracks/` 가 안 온다.
  #    🟥 워킹트리로 재면 게이트가 **만족 불가능**해진다: 봉인 원장이 `tracks/` 에 살고
  #    positive 토큰은 정의상 그 원장에서 나오므로 모든 문항이 자동 오염으로 찍힌다.
  #    실측(2026-08-30): 워킹트리 5히트 vs 추적 코퍼스 0히트, 같은 두 토큰. 컨트롤 36히트로 계기 확인.
  #    ⇒ **추적 코퍼스**(`git grep`)로 잰다. 그것이 팔이 실제로 보는 것이다.
  if git -C "$HERE" rev-parse --git-dir >/dev/null 2>&1; then
    tok_out=$(git -C "$HERE" grep -lF -- "$tok" 2>&1); tok_rc=$?
    [ "$tok_rc" -le 1 ] || tok_rc=2          # git grep: 0=found 1=none, 그 외는 오류
  else
    echo "⚠️ git 저장소가 아니다 — 워킹트리로 대체 측정한다(팔이 보는 것과 다를 수 있다)" >&2
    tok_out=$(grep -RlF --exclude-dir=.git -- "$tok" "$HERE" 2>&1); tok_rc=$?
  fi
  if [ "$tok_rc" -ge 2 ]; then
    echo "🟥 qset 오염 검사 자체가 실패했다 (rc=$tok_rc) — «오염 없음»이 아니다" >&2
    printf '%s\n' "$tok_out" | head -3 | sed 's|^|     |' >&2
    QSET_BAD=1; continue
  fi
  hits=$(printf '%s' "$tok_out" | grep -c . )
  if [ "$hits" != 0 ]; then
    echo "🟥 qset 오염: $_q($_k) 의 기대토큰이 tracked 레포 $hits 개 파일에 있다 — 팔이 주울 수 있다" >&2
    echo "     🟥 토큰을 여기 안 찍는다 — 이 stderr 가 로그로 가면 그것도 코퍼스가 된다" >&2
    # 🟥 경로 목록은 **카운트와 같은 코퍼스**에서 뽑는다. 초판은 개수를 `git grep`(추적)으로
    #    세고 경로를 워킹트리 전수 `grep -R` 로 찍어서 «1 개 파일»이라 적고 **3 줄을 나열했다**
    #    — 읽는 사람이 어느 쪽을 믿을지 알 수 없다([[feedback_instrument_vs_target_and_budget]]).
    printf '%s\n' "$tok_out" | sed 's|^|     |' | head -5 >&2
    QSET_BAD=1
  fi
done < "$QSET"
if [ "$QSET_BAD" = 1 ]; then
  echo "🟥 회차를 시작하지 않는다. 오염된 토큰으로 재면 «운반체 덕»과 «레포에서 주움»이 안 갈린다." >&2
  echo "   강행: FH_QSET_CONTAMINATED_OK=1 (그러면 이 회차는 CTRL 상한이 오염됐다고 기록해라)" >&2
  [ "${FH_QSET_CONTAMINATED_OK:-}" = 1 ] || exit 4
  echo "   ⚠️ 강행됨 — 이 회차의 CTRL 은 상한이 오염됐다." >&2
fi

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
    if [ "${RESCORE:-0}" != 1 ]; then
      args=(--arm "${qid}_${arm}" --reps "$REPS" --model "$MODEL" --out "$OUT" --prompt "$q")
      [ -n "$setup" ] && args+=(--setup "$setup")
      # 🟥 심층 방어 — 이 호출은 `while … done < "$QSET"` 루프 «안»이라 stdin 이 qset 이다.
      #    러너 쪽에도 `< /dev/null` 을 박았지만, 여기서 끊는 것이 근원이다(호출부 책임).
      bash "$RUNNER" "${args[@]}" >/dev/null 2>&1 < /dev/null
    fi
    for r in $(seq 1 "$REPS"); do
      f="$OUT/${qid}_${arm}_r${r}.txt"
      v="$(score_one "$f" "$kind" "$token")"
      ROWS+=("$qid|$kind|$arm|r$r|$v")
    done
  done
done < "$QSET"

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

NEG_CTRL_BAD=$(printf '%s\n' "${ROWS[@]}" | grep '|negative|CTRL|' | grep -vc 'PASS' || true)
NEG_CTRL_TOT=$(printf '%s\n' "${ROWS[@]}" | grep -c '|negative|CTRL|' || true)
# CLARIFY 는 **판정 분모가 아니라 별도 카운터**다. 운영자 결정 2026-08-31 (안 1 + 태그 병기):
#   되묻기를 4번째 값으로 빼면 분모가 셋으로 갈려 reps=3 에선 어느 칸도 못 읽는다. 그렇다고
#   ABSTAIN 에 통째로 접으면 「모르겠으니 네가 말해줘」라는 **책임 전가**가 좋은 기권과 같은
#   점수를 받고, 운반체가 나빠질수록 늘어날 그 신호를 우리 손으로 지우게 된다.
#   ⇒ 분모는 ABSTAIN 하나로 두고, 건수만 따로 센다. 칸을 안 늘리고 정보를 안 버린다.
# 🟥 **선례 없는 조합이다.** 외부(SQuAD 2.0 unanswerable)는 기권 하나로만 세고, 되묻기를
#    별도 축으로 두는 벤치를 못 찾았다. 미검증 라벨을 여기 남긴다 — 지우지 마라.
CLARIFY_RE='알려주시|가리키는지|어느 파일|어떤 파일|말씀해 주시|which file|let me know|could you (specify|clarify|point)'
CLARIFY_N=0
for row in "${ROWS[@]}"; do
  IFS='|' read -r _a _b _c _d _e <<<"$row"
  f="$OUT/${_a}_${_c}_${_d#r}.txt"; f="$OUT/${_a}_${_c}_${_d}.txt"
  [ -f "$f" ] && grep -qiE -- "$CLARIFY_RE" "$f" && CLARIFY_N=$((CLARIFY_N+1))
done

# ── 🟥 판정선 (2026-08-31 반전) ────────────────────────────────────────────────
#   종전: `NEG_ARM_BAD > 0 → VOID`. 즉 **ARM 이 기권 못하면 계기가 죽었다**고 찍었다.
#   회차 3 이 정확히 그렇게 오독됐다 — 그 회차는 CTRL 이 6/6 기권했으므로 계기는 **살아 있었고**,
#   ARM 만 못한 것은 계기 사망이 아니라 **발견**이었다. 그런데 게이트가 VOID 를 찍는 바람에
#   판정표의 숫자만 기록으로 넘어가고 VOID 라는 낱말은 한 번도 안 넘어갔다.
#   ⇒ 생존선은 **CTRL** 이 판정한다. ARM 의 실패는 결과다.
VERDICT=""; VDETAIL=""
if [ "$NEG_CTRL_TOT" -gt 0 ] && [ "$NEG_CTRL_BAD" -gt 0 ]; then
  VERDICT=VOID
  VDETAIL="CTRL 조차 기권 못한다 ($NEG_CTRL_BAD/$NEG_CTRL_TOT) — 모델이 부재를 못 말하는 것이고 운반체 얘기가 아니다"
elif [ "$POS_ARM_TOT" -gt 0 ] && [ "$POS_ARM_PASS" -lt "$POS_ARM_TOT" ]; then
  VERDICT=INSTRUMENT_INCOMPLETE
  VDETAIL="known-positive ARM 이 만점이 아니다 — 운반체 부실이 아니라 팔이 운반체를 못 읽는 것일 수 있다"
elif [ "$NEG_ARM_BAD" -gt "$NEG_CTRL_BAD" ]; then
  VERDICT=FINDING
  VDETAIL="CTRL 은 기권하는데 ARM 만 못한다 — DELIVERY 가 올라도 HUI 가 같이 오르면 그 운반체는 개선이 아니다"
else
  VERDICT=OK
  VDETAIL="계기 생존 — 이제부터의 숫자는 «운반체가 나른 것»을 가리킨다"
fi

# ── 🟥 무효 워터마크 (2026-08-31) — 숫자와 판정을 «애초에» 못 떼어놓는다 ──────────────
#    회차 3(_ccrun7)은 자기 게이트가 `🟥 VOID` 를 찍었는데, 그 판정표의 숫자만 기록으로
#    넘어가고 VOID 라는 낱말은 한 번도 안 넘어갔다. 게으름이 아니라 **채널이 없었다**:
#    판정은 표 «밖» 마지막 줄에 있었고, 사람은 표를 복사한다.
#    🟥 그래서 «읽는 쪽»(기록에 라벨이 붙었나)에 검사를 두려던 설계를 버렸다 — known-pair 가
#    안 섰다: VOID 를 잘못 실은 커밋과 옳게 철회한 커밋이 어휘·근접도로 **구분되지 않는다**.
#    「이 라벨이 어느 주장에 붙나」는 **결론**이라 기계화하면 장식이 된다(§Mechanization Boundary).
#    ⇒ 쓰는 쪽에서 **각 숫자 줄이 자기 무효를 나르게** 한다. 한 줄만 복사해도 딸려간다.
#    ⚠️ **숨기지 않는다.** 숫자를 감추면 저자가 로그를 뒤져 다시 꺼내고 그때 라벨이 떨어진다.
#       나르게 하는 것과 감추는 것은 다르다. OK 회차엔 접두사가 없다(있으면 그게 소음이다).
case "$VERDICT" in
  VOID|INSTRUMENT_INCOMPLETE) WM="🟥$VERDICT " ;;
  *)                          WM="" ;;
esac

printf '%s%-10s %-9s %-5s %-4s %s\n' "$WM" QID KIND ARM REP VERDICT
for row in "${ROWS[@]}"; do IFS='|' read -r a b c d e <<<"$row"
  printf '%s%-10s %-9s %-5s %-4s %s\n' "$WM" "$a" "$b" "$c" "$d" "$e"; done

echo
echo "${WM}── 숫자 둘 (DELIVERY · HUI) ──"
echo "${WM}  DELIVERY (ARM)  : $POS_ARM_PASS / $POS_ARM_TOT   운반체가 나른 것"
echo "${WM}  HUI      (ARM)  : $NEG_ARM_BAD / $NEG_ARM_TOT   운반체가 만든 과신"
echo "${WM}  HUI      (CTRL) : $NEG_CTRL_BAD / $NEG_CTRL_TOT   ← 계기 생존선"
echo "${WM}  CLARIFY (되묻기) : $CLARIFY_N 건 (태그. 판정 분모 아님 — 선례 없는 조합)"
echo "${WM}  LUCKY           : UNMEASURED  (conflict 문항 없이는 판별 불가 — 0 으로 접지 마라)"

# 🟥 판정을 **산출물에 박는다** (2026-08-31). 종전엔 stdout 으로만 나갔고, 사람이 손으로
#    옮기는 자리에서 조용히 증발했다: _ccrun7 은 자기 게이트가 VOID 를 찍었는데도 그 판정표가
#    ship_readiness_gate.md 에 「격리된 상태의 첫 측정」으로 올라갔고 그 절에 VOID 라는 낱말이
#    한 번도 없다. 게으름이 아니라 **채널이 없었다.**
#    ⚠️ 이것은 §Mechanization Boundary 가 허가하는 쪽이다 — 「이 숫자가 어떤 판정의 실행에서
#    나왔나」는 **기록의 속성**이다. 무엇이 옳은 값인가(결론)는 기계화하지 않는다.
{
  echo "verdict: $VERDICT"
  echo "detail: $VDETAIL"
  echo "seal: $(basename "$SEAL")"
  echo "qset: $(basename "$QSET")"
  echo "reps: $REPS"
  echo "model: $MODEL"
  echo "delivery_arm: $POS_ARM_PASS/$POS_ARM_TOT"
  echo "hui_arm: $NEG_ARM_BAD/$NEG_ARM_TOT"
  echo "hui_ctrl: $NEG_CTRL_BAD/$NEG_CTRL_TOT"
  echo "clarify_tag: $CLARIFY_N"
  echo "lucky: UNMEASURED"
} > "$OUT/_VERDICT"

echo
echo "── 판정 ──"
case "$VERDICT" in
  VOID)    echo "🟥 VOID — $VDETAIL"; echo "   숫자를 내지 않는다. 판정 기록: $OUT/_VERDICT"; exit 3 ;;
  INSTRUMENT_INCOMPLETE)
           echo "🟡 계기 미완성 — $VDETAIL"; echo "   판정 기록: $OUT/_VERDICT"; exit 4 ;;
  FINDING) echo "🟠 FINDING — $VDETAIL"; echo "   🟥 이건 VOID 가 아니다. 숫자를 낸다."
           echo "   판정 기록: $OUT/_VERDICT"; exit 0 ;;
  *)       echo "🟢 $VDETAIL"; echo "   판정 기록: $OUT/_VERDICT"; exit 0 ;;
esac
