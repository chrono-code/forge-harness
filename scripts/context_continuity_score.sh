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
#   kind = conflict : 운반체에 **의도적으로 틀린 값**을 심어두고 그 값을 기대토큰에 적는다.
#                     심은 값이 나오면 CONFLICT_FOLLOWED(운반체를 읽었다),
#                     일반값이 나오면 PRIOR_WON(운반체 미독 → DELIVERY 는 부풀려진 것).
#                     🟥 심는 것은 이 스크립트가 안 한다 — 운반체(seal)를 저작할 때 사람이 심는다.
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
# 🟥 `IFS=$'\t' read` 를 «쓰지 않는다» — 탭이 IFS 공백류라 **빈 칸이 접히고 값이 밀린다**.
#    실측: `a\tb\tc\t\tE\tF` → read 는 c4=[E] c5=[F] (한 칸 밀림) · awk -F'\t' 는 c4=[] c5=[E] (정상).
#    🟥 이번 qset 은 positive 8 행의 5·6열이 «비어» 있어서 그대로 두면 조용히 틀린다.
#    🟥 그리고 빈 칸이 없으면 «안 드러난다» — 앞선 게이트 네 번이 같은 파서로 전부 통과했다.
#    ⇒ awk 로 탭을 `|` 로 바꿔 넘긴다(빈 칸이 보존된다). 값에 `|` 가 없어야 하고, 그건 아래에서 검사한다.
_tsv_pipe(){ LC_ALL=C awk -F'\t' 'BEGIN{OFS="|"} {for(i=1;i<=NF;i++) if($i ~ /\|/){print "PIPE_IN_VALUE:" NR > "/dev/stderr"; exit 3} $1=$1; print}' "$1"; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$HERE/scripts/sim_isolated_run.sh"

SEAL=""; QSET=""; REPS=1; MODEL="sonnet"; OUT=""; DELIVER=0
SELFTEST=0; RESCORE=0; MANIFEST=""; BASE_REF=""; BASE_SHA=""; PROTOCOL_FILE=""
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
    --base-ref) BASE_REF="${2:-}"; shift 2 ;;   # 🟥 회차는 BASE 얕은 클론에서 돈다(§7-12)
    --base-sha) BASE_SHA="${2:-}"; shift 2 ;;   #    ref 는 움직인다 — sha 를 둘 다 준다
    --protocol) PROTOCOL_FILE="${2:-}"; shift 2 ;;  # 🟥 규약 «문구»는 파일로 받는다 — 코드에 안 박는다
    --rescore) RESCORE=1; shift ;;
    # 🟥 «지금 도는 qset/seal 이 «봉인된 그것»인가» 를 회차 시작 전에 대조한다.
    --manifest) MANIFEST="${2:-}"; shift 2 ;;
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
  local ans_file="$1" kind="$2" token="$3" general="${4:-}"
  [ -s "$ans_file" ] || { echo VOID; return 0; }        # 빈 출력은 «아니오»가 아니다
  local body; body="$(cat "$ans_file")"
  # ── typed 채널 = «상위층». 대체가 아니다 (§7-7, 2026-09-01) ─────────────────
  # 🟥 근인 정정: 「typed 로 가면 48 바가 비껴간다」는 물리 법칙이 아니라 «대체로 설계했기
  #    때문»이었다. 계층으로 지으면 총오류에 **곱해진다**:
  #      총오류 = P(미준수)×«산문 폴백» + P(준수)×«토큰 읽기»
  #    ⇒ 얼린 48 바는 폴백 경로를 그대로 지나간다 — 계기가 대상이 지나가는 자리에 있다.
  # 🟥 폴백은 «새로 짓지 않는다». 아래 REFUSE_RE 경로가 그대로 폴백이다.
  # 🟥 판정 불가는 UNCLASSIFIED 다. **VOID 로 승격하지 않는다**(VOID 는 «빈 출력»만).
  local verdict_tag=""
  verdict_tag="$(printf '%s' "$body" | LC_ALL=C sed -n 's/.*<<VERDICT:\([A-Z_]*\)>>.*/\1/p' | tail -1)"
  # 🟥 카운터를 여기서 증가시키면 «죽는다» — 호출부가 `v="$(score_one …)"` 라 서브셸이다.
  #    실측: 명령치환 안의 변수 증가는 부모에 안 보인다. 그래서 «상태»가 아니라 «값»으로 나른다:
  #    `TYPED_` 접두가 곧 경로 표시이고, 계수는 호출부가 ROWS 에서 한다. 공유 상태가 없다.
  if [ -n "$verdict_tag" ]; then
    case "$verdict_tag" in
      REFUSED|ANSWERED|HALLUCINATED) echo "TYPED_$verdict_tag"; return 0 ;;
      *) : ;;   # 🟥 모르는 토큰은 «준수»로 안 친다 — 아래 폴백으로 떨어진다
    esac
  fi
  # 🟥 여기부터가 폴백이다. 도달 건수는 호출부가 «TYPED_ 접두가 없는 행»으로 센다.
  #    0 이면 「전원 준수」와 「폴백 미배선」이 출력상 같다 — §7-7-ⓑ 의 되돌림 픽스처가 가른다.
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
    conflict)
      # 🟥 치환 컨트롤 (Longpre 2021 계열). 운반체에 **의도적으로 틀린 값**을 심어두고,
      #    팔이 그 값을 말하는지 본다. 목적은 DELIVERY 의 **진위**다:
      #      「운반체를 읽어서 맞혔다」와 「레포·일반지식으로 맞혔다」를 positive 문항만으로는
      #      구분할 수 없다. 그래서 positive 축은 지금까지 통째로 미검증이었다.
      #    기대토큰 칸 = **심어둔 틀린 값**. 그 값이 나오면 운반체를 실제로 읽은 것이다.
      #    ⚠️ 이 분기는 「어느 값이 참인가」를 판정하지 않는다 — 심은 값이 답에 있나만 본다.
      #       무엇을 심을지는 사람이 정하고, 그 심기는 이 스크립트 밖(운반체 저작)에서 한다.
      # 🟥 2026-08-31 회차1 사후 수리 — `PRIOR_WON` 이 **`else` 통이었다.**
      #    실측(C03_CTRL_r4): 팔이 *"I don't have grounds to answer this — I won't invent a
      #    version number"* 라고 **명시적으로 기권**했는데, 거절 어휘가 영어 어형이라
      #    `has_ref=0` 이 되고 심은 값도 없어 그대로 `else` 로 떨어졌다.
      #    심은 값 히트 0 · 원래값 히트 0 — **아무 근거도 없이** 「일반지식이 이겼다」로 찍혔다.
      # 🟥 그리고 그 라벨이 **구체적 긍정 주장**이다: 미분류를 주장으로 렌더한 것이고,
      #    §0 의 CONFLICT 축 판정이 그 값을 쓴다 — **판정 경로 «안»의 결함**이다.
      # ⇒ `PRIOR_WON` 은 **«원래값을 확인했을 때만»** 낸다. qset 5열 `general` 이 그 값이고,
      #    열이 없으면 **단언 불가**이므로 `PRIOR_WON` 을 절대 안 낸다.
      #    나머지는 전부 `UNCLASSIFIED` — 셋 중 어느 것도 단언할 수 없는 응답이다.
      #    ([[feedback_not_found_is_not_zero_family]] — 없는 칸을 0 으로 안 접는다)
      if [ "$has_tok" = 1 ] && [ "$has_ref" = 0 ]; then echo CONFLICT_FOLLOWED
      elif [ "$has_ref" = 1 ]; then echo ABSTAINED_ON_CONFLICT
      elif [ -n "${general:-}" ] && printf '%s' "$body" | grep -qF -- "$general"; then echo PRIOR_WON
      else echo UNCLASSIFIED; fi ;;
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
while IFS='|' read -r _q _k _t tok; do
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
done < <(_tsv_pipe "$QSET")
if [ "$QSET_BAD" = 1 ]; then
  echo "🟥 회차를 시작하지 않는다. 오염된 토큰으로 재면 «운반체 덕»과 «레포에서 주움»이 안 갈린다." >&2
  echo "   강행: FH_QSET_CONTAMINATED_OK=1 (그러면 이 회차는 CTRL 상한이 오염됐다고 기록해라)" >&2
  # 🟥 5 이지 4 가 아니다 — 4 는 INSTRUMENT_INCOMPLETE 다. 같은 코드를 쓰면 호출자가
  #    「회차를 시작조차 안 했다」와 「다 돌았는데 계기가 미달이다」를 구분 못 한다.
  [ "${FH_QSET_CONTAMINATED_OK:-}" = 1 ] || exit 5
  echo "   ⚠️ 강행됨 — 이 회차의 CTRL 은 상한이 오염됐다." >&2
fi

# ── 🟥 봉인 대조 (2026-08-31) — verify 가 «구조적으로» 못 잡는 자리 ──────────────────
#    재stamp 할 때 인자를 안 바꾸면 «회차1 문항»을 봉인해놓고 «회차2»를 돌리게 된다.
#    그때 `instrument_manifest.sh verify` 는 **rc=0 을 낸다** — 자기가 찍은 것과 같으니
#    계기 대조는 «자기 일관»하다. 즉 verify 는 「무엇을 봉인했나」를 안 본다.
#    ⇒ 채점기가 «자기가 받은 qset/seal» 이 매니페스트에 적힌 그것인지 직접 본다.
# 🟥 판별자는 «경로»가 아니라 «해시»다 — 같은 경로에 다른 내용이 들어가면 경로 비교는 통과한다.
# ⚠️ `--manifest` 미지정은 **차단이 아니라 UNVERIFIED** 다(self-test·rescore·개발 실행이 있다).
#    그러나 «통과»로 렌더하지 않는다 — 마커에 UNVERIFIED 로 남고 화면에도 찍힌다.
MANIFEST_MATCH=UNVERIFIED
if [ -n "$MANIFEST" ]; then
  if [ ! -s "$MANIFEST" ]; then
    echo "🟥 매니페스트가 없거나 비었다: $MANIFEST — 대조 불가. 회차를 열지 않는다." >&2; exit 10
  fi
  _bad=0
  for _pair in "qset:$QSET" "seal:$SEAL"; do
    _lbl="${_pair%%:*}"; _f="${_pair#*:}"
    _now="sha256:$(shasum -a 256 "$_f" | awk '{print $1}')"
    # 🟥 매니페스트는 «레포 상대경로»로 적힌다. 호출자가 절대경로를 주면 그냥은 안 맞는다
    #    — 레인이 실제로 그렇게 불러서 잡혔다(L21). 물리경로로 접두를 벗긴다.
    _abs=$( cd "$(dirname "$_f")" 2>/dev/null && pwd -P )/$(basename "$_f")
    _rel="${_abs#"$(cd "$HERE" && pwd -P)"/}"; _rel="${_rel#./}"
    _rec=$(awk -v F="$_rel" '$1==F{print $2}' "$MANIFEST")
    if [ -z "$_rec" ]; then
      echo "🟥 매니페스트에 «${_rel}» 항목이 없다 — 봉인된 적 없는 $_lbl 으로 회차를 열 수 없다." >&2; _bad=1
    elif [ "$_rec" != "$_now" ]; then
      echo "🟥 봉인 불일치 ($_lbl): $_rel" >&2
      echo "     매니페스트 $_rec" >&2; echo "     지금      $_now" >&2; _bad=1
    fi
  done
  if [ "$_bad" = 1 ]; then
    echo "🟥 봉인된 것과 «다른» 입력이다. 144 디스패치를 태우기 전에 멈춘다 (exit 10)." >&2; exit 10
  fi
  MANIFEST_MATCH=yes
  echo "🟢 봉인 대조 — qset·seal 이 매니페스트와 일치한다"
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

# ── 팔 라벨: 사람이 안 고른다. 생성한다 (2026-09-01 배선) ────────────────────
# 🟥 종전 `--arm "${qid}_${arm}"` 이 wrap 디렉터리 이름이 되어 **팔에게 자기 배정을 알렸다**
#    (회차2 실측 144/144 노출). 라벨을 `nameleak_check.sh gen` 이 만든다.
# 🟥 매핑을 «파일»로 두면 그 파일이 새 누출 표면이다. 두 겹으로 막는다:
#    ⓐ 공간 — out-dir «밖»의 형제 경로에 쓴다
#    ⓑ 🟥 **시간** — «모든 디스패치가 끝난 뒤»에 쓴다. 팔이 도는 동안엔 파일이 «존재하지 않는다».
#       ⓑ 가 본체다: 경로는 팔이 `../..` 로 올라가면 닿지만, 없는 파일은 못 읽는다.
#    런 «중»에는 매핑이 필요 없다 — 디스패치와 채점이 **같은 루프 반복 안**이라 변수로 족하다.
NAMELEAK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/round/nameleak_check.sh"
# 🟥 fail-closed: 없으면 «skipped» 가 아니라 실패다. 이름 누출은 회차를 통째로 무효화한다.
[ -x "$NAMELEAK" ] || { echo "🟥 nameleak_check.sh 없음/실행불가: $NAMELEAK — 회차를 열지 않는다" >&2; exit 7; }
# ── §7-10 🟥 개시 게이트를 «채점기가» 부른다 (2026-09-01) ──────────────────────
# 왜: 게이트는 있었고 «옳게» 물었는데 **아무도 rc 를 소비하지 않았다.** 실측 —
#     채점기의 gatecheck 호출 0건(컨트롤: nameleak 4 · sim_isolated_run 3 ⇒ 그 0 은 실측).
#     2026-09-01 스모크런에서 저자가 rc=1 을 보고도 디스패치를 돌렸고, 오염된 세트로
#     디스패치가 2배(4건) 났다. **실회차였으면 게이트가 막은 세트로 5시간이다.**
# 🟥 그래서 «사람이 따로 돌린 결과»를 인자로 안 받는다. 자기신고를 받으면 그 무시가 그대로
#    가능하다 — 오늘 사고는 「안 돌린 것」이 아니라 **「돌리고 무시한 것」**이다.
# 🟥 스코프: 팔이 «도는» 경로만. rescore·self-test 는 게이트 없음(과차단은 검사 끄기를 훈련시킨다).
# 🟥 부재 = 실패. 스킵 아님.
if [ "${RESCORE:-0}" != 1 ] && [ "${SELFTEST:-0}" != 1 ]; then
  # 🟥 폴백을 «두지 않는다». 2026-09-01 실측: `tracks/_meta/gatecheck_qset.sh` 는 낡은 사본이고
  #    (nameleak 호출 0 · KNEG 생성 0) 정본이 없을 때 조용히 그것이 돌면 **이름 누출 검사가
  #    통째로 빠진 채 회차가 열린다.** 「갈라 적을 수 있으면 갈린다」의 폴백 판이다 —
  #    폴백은 «가용성»을 사지만 «무엇이 돌았는지»를 판다.
  _GATE="$(dirname "${BASH_SOURCE[0]}")/round/gatecheck_qset.sh"
  [ -f "$_GATE" ] || { echo "🟥 $_GATE 가 없다 — 회차를 열지 않는다(스킵 아님, 폴백 없음)" >&2; exit 8; }
  if ! bash "$_GATE" "$QSET" "$SEAL" post '' '' "$(basename "${OUT%/}")" "$(bash "$NAMELEAK" gen)" >&2; then
    echo "🟥 개시 게이트가 막았다 — 디스패치 0건으로 중단한다" >&2
    exit 8
  fi
fi

# 🟥 out-dir 도 «사람이 고르는 자리»다 — 그리고 팔 cwd 의 조상이다
#    (`sim_isolated_run.sh:287-288`: WRAP="$OUTDIR/w_…" · WORK="$WRAP/repo").
#    실제 누출 전례(`_ccfalsify`)가 «사람이 고른 out-dir 이름»이었다. 그래서 여기서 막는다 —
#    검사기만 엄격하고 실제 경로는 사람이 고르면 그 검사는 장식이다.
# 🟥 스코프 — «팔이 도는 경우»에만 본다. 이 검사가 지키는 것은 팔의 시야이고,
#    `--rescore`·`--self-test` 는 디스패치를 안 하므로 볼 팔이 없다.
#    (초판은 무조건 걸어서 레인 25개를 과차단했다 — 실측. 과차단은 우회를 훈련시킨다)
if [ "${RESCORE:-0}" != 1 ] && [ "${SELFTEST:-0}" != 1 ]; then
  if ! bash "$NAMELEAK" "$(basename "$SEAL")" "$(basename "${OUT%/}")" "$(bash "$NAMELEAK" gen)"; then
    echo "🟥 out-dir 또는 seal 이름이 누출한다 — 회차를 열지 않는다 ('nameleak_check.sh gen' 을 써라)" >&2
    exit 7
  fi
fi
LABELMAP_FILE="${OUT%/}.labelmap"
declare -a LABELMAP=()
_label_for(){ # $1=qid $2=ARM|CTRL → 라벨
  if [ "${RESCORE:-0}" = 1 ]; then
    # 🟥 옛 산출물 호환. 라벨 배선(2026-09-01) «이전» 회차는 파일명이 `{qid}_{ARM}_r{n}.txt` 이고
    #    labelmap 이 없다. 그걸 «실패»로 만들면 회차1·2 데이터를 영원히 재채점 못 한다 —
    #    그 데이터는 지금 유일한 known-pair 근거다. ⇒ 부재 시 옛 규약으로 떨어진다.
    #    🟥 «없으면 옛것»이지 «틀리면 옛것»이 아니다: 파일이 있는데 항목이 없으면 실패한다.
    if [ -f "$LABELMAP_FILE" ]; then
      LC_ALL=C awk -F'|' -v q="$1" -v a="$2" '$2==q && $3==a {print $1; found=1} END{exit !found}' "$LABELMAP_FILE"
    else
      printf '%s_%s\n' "$1" "$2"
    fi
  else
    bash "$NAMELEAK" gen
  fi
}

n=0; declare -a ROWS=()
while IFS='|' read -r qid kind question token general; do
  case "$qid" in ''|'#'*) continue ;; esac
  n=$((n+1))
  for arm in ARM CTRL; do
    setup=""; [ "$arm" = ARM ] && setup="$SETUP_ARM"
    q="$question"
    # ── S5 ② «규약» — typed 채널의 «쓰는 쪽» (2026-09-01 배선) ──────────────────
    # 🟥 §7-7 은 읽는 쪽(:166 의 <<VERDICT:…>> 파싱)만 지었고 «생산처»를 안 지었다.
    #    닫힘 정의 넷을 짓기 «전»에 적었는데 그 정의 자체에 생산처가 없었다 —
    #    「닫힘 정의를 먼저」가 완전성을 보장하지 않는다는 첫 실례다.
    # 🟥 문구는 «처치»라 출제자가 쓴다. 여기(코드)엔 안 박고 파일로 받는다 —
    #    채점기 저자가 문구를 쓰면 ②의 결과를 «저자가 만든 문구»가 만든 게 된다.
    # 🟥 «뒤»에 붙인다. 앞에 오면 «지시»로 읽히고, 뒤에 와야 «답변 형식 안내»가 된다.
    # 🟥 두 팔에 «똑같이» 붙는다 — 규약은 조건(cell) 수준 처치이지 팔 수준이 아니다.
    if [ -n "$PROTOCOL_FILE" ]; then
      [ -f "$PROTOCOL_FILE" ] || { echo "🟥 규약 파일 없음: $PROTOCOL_FILE — 회차를 열지 않는다" >&2; exit 11; }
      q="$q

$(cat "$PROTOCOL_FILE")"
    fi
    # 🟥 2026-09-01: 여기가 `$question` 을 다시 읽어 위에서 붙인 규약을 버렸다.
    #    그래서 ③(규약×deliver) 의 ARM 은 실제로는 «규약없음×deliver» 였고, 그것을
    #    「deliver 가 규약 준수를 죽인다」는 «발견» 으로 낼 뻔했다(ARM 0/72 · CTRL 72/72).
    #    🟥 바로 위 주석이 «두 팔에 똑같이 붙는다» 라고 적어둔 불변식을 **다섯 줄 아래에서** 깨뜨렸다 —
    #    산문은 인접해 있어도 floor 가 아니다. 앞에 붙이되 **누적된 $q 위에** 붙인다.
    if [ "$DELIVER" = 1 ] && [ "$arm" = ARM ]; then
      q="[직전 압축 전 봉인 원장: tracks/_meta/compaction/$(basename "$SEAL") — 필요하면 열어라]
$q"
    fi
    label="$(_label_for "$qid" "$arm")" || { echo "🟥 라벨 해석 실패 ($qid/$arm) — $LABELMAP_FILE 확인" >&2; exit 7; }
    [ -n "$label" ] || { echo "🟥 라벨이 비었다 ($qid/$arm)" >&2; exit 7; }
    LABELMAP+=("$label|$qid|$arm")
    if [ "${RESCORE:-0}" != 1 ]; then
      args=(--arm "$label" --reps "$REPS" --model "$MODEL" --out "$OUT" --prompt "$q")
      # 🟥 BASE 핀을 러너로 넘긴다. 하나만 주면 러너가 rc=2 로 막는다(대조 불가).
      [ -n "$BASE_REF" ] && args+=(--base-ref "$BASE_REF")
      [ -n "$BASE_SHA" ] && args+=(--base-sha "$BASE_SHA")
      [ -n "$setup" ] && args+=(--setup "$setup")
      # 🟥 심층 방어 — 이 호출은 `while … done < <(_tsv_pipe "$QSET")` 루프 «안»이라 stdin 이 qset 이다.
      #    러너 쪽에도 `< /dev/null` 을 박았지만, 여기서 끊는 것이 근원이다(호출부 책임).
      bash "$RUNNER" "${args[@]}" >/dev/null 2>&1 < /dev/null
    fi
    for r in $(seq 1 "$REPS"); do
      f="$OUT/${label}_r${r}.txt"
      v="$(score_one "$f" "$kind" "$token" "${general:-}")"
      ROWS+=("$qid|$kind|$arm|r$r|$v")
    done
  done
done < <(_tsv_pipe "$QSET")

# 🟥 매핑은 «여기»에서 쓴다 — 모든 디스패치가 끝난 뒤. 팔이 도는 동안엔 이 파일이 없다.
if [ "${RESCORE:-0}" != 1 ]; then
  printf '%s\n' "${LABELMAP[@]}" > "$LABELMAP_FILE"
  echo "labelmap → $LABELMAP_FILE ($(grep -c . "$LABELMAP_FILE") 줄)"
fi

# ── §7-7 두 숫자. 🟥 «따로» 낸다. 곱한 값은 이 파일 어디에도 없다 ──────────────
#    🟥 「곱하지 마라」를 주석으로 적는 것은 오늘 세 번 실패한 형태다. 그래서 **곱셈을 안 쓴다** —
#    두 값을 담는 변수가 따로 있고, 둘을 결합하는 식이 존재하지 않는다. 레인이 그걸 검사한다.
TYPED_N=$(printf '%s\n' "${ROWS[@]}" | grep -c '|TYPED_' || true); [ -n "$TYPED_N" ] || TYPED_N=0
TOTAL_N=${#ROWS[@]}
FALLBACK_N=$((TOTAL_N - TYPED_N))
echo ""
echo "── §7-7 두 숫자 (곱하지 않는다) ──"
echo "  ② 규약 준수 (typed 경로) : $TYPED_N / $TOTAL_N"
echo "  ① 폴백 도달 (산문 경로)  : $FALLBACK_N / $TOTAL_N"
if [ "$FALLBACK_N" = 0 ]; then
  echo "  🟥 폴백 도달 0 — «전원 준수»와 «폴백 미배선»이 출력상 같다."
  echo "     가르는 것은 되돌림뿐이다: scripts/round/fallback_reach_probe.sh 를 돌려라"
fi
if [ "$TYPED_N" = 0 ] && [ "$TOTAL_N" -gt 0 ]; then
  echo "  ⚠️  typed 0 — 이 회차는 규약을 안 줬거나 팔이 전원 미준수다. 둘은 다른 사실이다"
fi

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

# ── 물건 C 집계 (2026-08-31) ────────────────────────────────────────────────
CFL_TOT=$(printf '%s\n' "${ROWS[@]}" | grep -c '|conflict|ARM|' || true)
CFL_READ=$(printf '%s\n' "${ROWS[@]}" | grep '|conflict|ARM|' | grep -c 'CONFLICT_FOLLOWED' || true)
CFL_PRIOR=$(printf '%s\n' "${ROWS[@]}" | grep '|conflict|ARM|' | grep -c 'PRIOR_WON' || true)
# 🟥 «셋 중 어느 것도 단언 못 하는» 응답. 분모에서 빼지 않고 **자기 줄로 보인다** —
#    빼면 그게 미측정을 0 으로 접는 것이다.
CFL_UNCL=$(printf '%s\n' "${ROWS[@]}" | grep '|conflict|ARM|' | grep -c 'UNCLASSIFIED' || true)
# 🟥 CTRL 쪽도 «집계»한다 (2026-08-31). 종전엔 ARM 만 셌고, 회차1 의 실제 오분류가
#    **하필 CTRL 쪽**이라 요약에 0/20 으로 떴다 — 사람이 판정표 «행»을 눈으로 훑다가 발견했다.
#    그게 [[feedback_instrument_blindspot_correlated_with_arm]] 그 자체다: 계기의 사각이
#    «팔»과 상관돼 있으면 있는 결함을 가린다.
# 🟥 그리고 conflict 축에서 **CTRL 의 정상 거동은 `PRIOR_WON`** 이다(운반체가 없으니 일반지식이
#    이기는 게 맞다). 그러므로 CTRL 수치가 **컨트롤 생존선**이다 — negative 축의 HUI(CTRL) 과
#    같은 역할이고, 안 보이면 «컨트롤이 살았나»를 못 본다.
CFL_TOT_C=$(printf '%s\n' "${ROWS[@]}" | grep -c '|conflict|CTRL|' || true)
CFL_READ_C=$(printf '%s\n' "${ROWS[@]}" | grep '|conflict|CTRL|' | grep -c 'CONFLICT_FOLLOWED' || true)
CFL_PRIOR_C=$(printf '%s\n' "${ROWS[@]}" | grep '|conflict|CTRL|' | grep -c 'PRIOR_WON' || true)
CFL_ABST_C=$(printf '%s\n' "${ROWS[@]}" | grep '|conflict|CTRL|' | grep -c 'ABSTAINED_ON_CONFLICT' || true)
CFL_UNCL_C=$(printf '%s\n' "${ROWS[@]}" | grep '|conflict|CTRL|' | grep -c 'UNCLASSIFIED' || true)
# 🟥 LUCKY — 「운반체 없이도 맞혔다」. 종전엔 무조건 `UNMEASURED` 로 찍었는데 **그건 과소보고였다**:
#    positive CTRL 의 PASS 가 정확히 그 칸이다(운반체 미제공인데 정답). 잴 수 있는 것을
#    「못 잰다」로 렌더하는 것도 [[feedback_not_found_is_not_zero_family]] 의 한 얼굴이다.
#    ⚠️ 다만 이것은 **CTRL 쪽 LUCKY** 다. 「ARM 이 운반체를 «안 읽고» 맞혔나」는 다른 질문이고,
#       그건 conflict 행이 있어야만 답할 수 있다 — 없으면 아래에서 UNMEASURED 로 남는다.
LUCKY_CTRL=$(printf '%s\n' "${ROWS[@]}" | grep '|positive|CTRL|' | grep -c 'PASS' || true)
LUCKY_TOT=$(printf '%s\n' "${ROWS[@]}" | grep -c '|positive|CTRL|' || true)
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
# 🟥 비교는 «단언된 값»끼리만 한다. UNCLASSIFIED 를 PRIOR_WON 쪽에 세면 미분류가
#    「운반체 미독」이라는 주장을 떠받치게 된다 — 그게 회차1 의 결함이었다.
elif [ "$CFL_TOT" -gt 0 ] && [ "$CFL_PRIOR" -gt "$CFL_READ" ]; then
  # 🟥 치환 컨트롤이 「팔이 운반체를 안 읽는다」를 말하면 DELIVERY 는 인용 불가다.
  #    이건 계기 고장이 아니라 **측정 결과**이므로 VOID 가 아니고, 그렇다고 숫자를 그냥
  #    내보내서도 안 된다 — 그래서 자기 이름을 가진 값으로 둔다.
  VERDICT=CARRIER_UNREAD
  VDETAIL="치환 컨트롤에서 일반지식이 이겼다 ($CFL_PRIOR/$CFL_TOT) — DELIVERY 는 운반체 덕이 아니다"
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
  VOID|INSTRUMENT_INCOMPLETE|CARRIER_UNREAD) WM="🟥$VERDICT " ;;
  *)                          WM="" ;;
esac

printf '%s%-10s %-9s %-5s %-4s %s\n' "$WM" QID KIND ARM REP VERDICT
for row in "${ROWS[@]}"; do IFS='|' read -r a b c d e <<<"$row"
  printf '%s%-10s %-9s %-5s %-4s %s\n' "$WM" "$a" "$b" "$c" "$d" "$e"; done

# 🟥 2026-08-31 — cross-family 검토자(다른 계열)가 잡았다: 봉인 §0 이 「임계 미등록 → CONFLICT 축
#    미성립 → DELIVERY 를 «운반체가 나른 것»으로 인용 금지」인데, **이 인쇄가 바로 그 인용이었다.**
#    숫자만이면 «기록»이고, 해석 라벨이 붙는 순간 «인용»이다 — 사람이 안 옮겨 적어도 산출물이 옮긴다.
#    ⇒ 축이 성립하지 않은 회차에서는 라벨을 «떼고» 그 사실을 같은 줄에 적는다.
if [ "${CFL_TOT:-0}" -gt 0 ] && [ "${CFL_READ:-0}" -gt 0 ] && [ "${CFL_PRIOR:-0}" -gt 0 ]; then
  _LBL_D="운반체가 나른 것"; _LBL_H="운반체가 만든 과신"
else
  _LBL_D="🟥 라벨 보류 — CONFLICT 축 미성립(심은 팔/안 심은 팔이 안 갈렸다). 이 숫자는 «기록»이지 «인용»이 아니다"
  _LBL_H="🟥 라벨 보류 — 같은 사유"
fi
echo
echo "${WM}── 숫자 둘 (DELIVERY · HUI) ──"
echo "${WM}  DELIVERY (ARM)  : $POS_ARM_PASS / $POS_ARM_TOT   $_LBL_D"
echo "${WM}  HUI      (ARM)  : $NEG_ARM_BAD / $NEG_ARM_TOT   $_LBL_H"
echo "${WM}  HUI      (CTRL) : $NEG_CTRL_BAD / $NEG_CTRL_TOT   ← 계기 생존선"
echo "${WM}  CLARIFY (되묻기) : $CLARIFY_N 건 (태그. 판정 분모 아님 — 선례 없는 조합)"
echo "${WM}  LUCKY   (CTRL)  : $LUCKY_CTRL / $LUCKY_TOT   운반체 없이도 맞혔다"
# ── 🟥 3-class + Coverage@Acc (selective prediction 표준) ─────────────────────────
#    비율 하나가 아니라 «곡선 위 한 점»으로 낸다. 축마다 «옳은 행동»이 달라서 따로 적는다.
#    positive: 답하는 게 옳다 → coverage(답한 비율) · accuracy(답한 것 중 맞은 비율)
#    negative: **기권이 옳다** → coverage 가 «오류율»이다. accuracy 를 쓰면 분모가 0/0 이 된다
#              (답한 것은 정의상 전부 오답). 그래서 negative 는 3-class 만 낸다.
_P_ABS=$(printf '%s\n' "${ROWS[@]}" | grep '|positive|ARM|' | grep -cE 'FAIL|REFUSED_WITH_TOKEN' || true)
_P_ANS=$((POS_ARM_TOT - _P_ABS))
# ── 🟥 D = P_ARM − P_CTRL (item discrimination index, psychometrics 표준) ──────────
#    프런티어 대조가 준 이름이다. 🟥 **«적격 게이트»에는 못 붙인다** — 그 게이트는 심기 전이라
#    CTRL 만 돌고 ARM 이 없다. 두 팔이 필요한 지수를 한 팔짜리 검사에 붙이면 «이름이 계산을
#    잘못 서술»하는 것이고, 오늘 우리가 여러 번 센 축이다.
#    ⇒ 붙일 자리는 «회차»다. 여기는 두 팔이 다 있다. 문항별로 낸다 — D 가 낮은 문항이
#      «변별을 못 한 문항»이고, 그게 다음 회차 문항 교체의 «사전» 근거가 된다.
echo "${WM}  ── 문항별 D = P_ARM − P_CTRL (변별도) ──"
for _q in $(printf '%s\n' "${ROWS[@]}" | cut -d'|' -f1 | sort -u); do
  _k=$(printf '%s\n' "${ROWS[@]}" | grep "^${_q}|" | head -1 | cut -d'|' -f2)
  case "$_k" in positive) _good=PASS ;; negative) _good=PASS ;; conflict) _good=CONFLICT_FOLLOWED ;; *) continue ;; esac
  _at=$(printf '%s\n' "${ROWS[@]}" | grep -c "^${_q}|${_k}|ARM|" || true)
  _ct=$(printf '%s\n' "${ROWS[@]}" | grep -c "^${_q}|${_k}|CTRL|" || true)
  [ "$_at" -gt 0 ] && [ "$_ct" -gt 0 ] || continue
  _ap=$(printf '%s\n' "${ROWS[@]}" | grep "^${_q}|${_k}|ARM|" | grep -c "|${_good}\$" || true)
  _cp=$(printf '%s\n' "${ROWS[@]}" | grep "^${_q}|${_k}|CTRL|" | grep -c "|${_good}\$" || true)
  _d=$(awk -v a="$_ap" -v at="$_at" -v c="$_cp" -v ct="$_ct" 'BEGIN{printf "%+.2f", a/at - c/ct}')
  printf '%s    %-4s %-9s D=%s  (ARM %s/%s · CTRL %s/%s)\n' "$WM" "$_q" "$_k" "$_d" "$_ap" "$_at" "$_cp" "$_ct"
done
echo "${WM}  ── 3-class (ARM) ──"
if [ "$POS_ARM_TOT" -gt 0 ] && [ "$_P_ANS" -gt 0 ]; then
  echo "${WM}    positive  coverage $_P_ANS/$POS_ARM_TOT · accuracy $POS_ARM_PASS/$_P_ANS  (답한 것 중 정답)"
elif [ "$POS_ARM_TOT" -gt 0 ]; then
  echo "${WM}    positive  coverage 0/$POS_ARM_TOT · accuracy UNMEASURED (답한 것이 0건 — 0/0)"
fi
if [ "$NEG_ARM_TOT" -gt 0 ]; then
  echo "${WM}    negative  기권 $((NEG_ARM_TOT-NEG_ARM_BAD))/$NEG_ARM_TOT · 답함 $NEG_ARM_BAD/$NEG_ARM_TOT"
  echo "${WM}              🟥 여기선 «답함»이 오류다 — accuracy 를 안 낸다(분모가 정의상 전부 오답)"
fi
if [ "$CFL_TOT" -gt 0 ]; then
  echo "${WM}  CARRIER-READ    : $CFL_READ / $CFL_TOT   심은 값을 따랐다 (운반체를 실제로 읽었다)"
  # 🟥 이 라벨은 «단언된» 경우에만 붙는다 — qset 5열 `general` 로 원래값을 확인했을 때.
  if [ "$CFL_PRIOR" -gt 0 ]; then
    echo "${WM}  PRIOR_WON       : $CFL_PRIOR / $CFL_TOT   일반지식이 이겼다 (원래값 확인됨)"
  else
    echo "${WM}  PRIOR_WON       : 0 / $CFL_TOT   (원래값 확인된 건 없음 — 라벨을 안 붙인다)"
  fi
  echo "${WM}  UNCLASSIFIED    : $CFL_UNCL / $CFL_TOT   🟥 셋 중 어느 것도 단언 불가. 사람이 본다"
  # ── 🟥 MR (Memorization Ratio) — Longpre 2021. 프런티어 대조로 «우리 축에 선행이 있다»가
  #    확인돼서 그쪽 계산식으로 바꾼다(재발명 금지). 우리 CARRIER-READ 는 사실상 같은 것이었다.
  # 🟥 핵심 차이는 **분모**다: 기권·미분류를 «빼고» 둘 중 하나를 고른 응답만 센다.
  #    종전처럼 전체를 분모로 쓰면 «기권이 늘면 비율이 조용히 내려간다» — 읽은 쪽이 진 것처럼 보인다.
  _mr_den=$((CFL_READ + CFL_PRIOR))
  if [ "$_mr_den" -gt 0 ]; then
    echo "${WM}  MR (Longpre)    : $CFL_READ / $_mr_den   원장값 / (원장값+레포값) — 기권·미분류 제외"
  else
    echo "${WM}  MR (Longpre)    : UNMEASURED / 0   🟥 둘 중 하나를 고른 응답이 «0건». 비율 정의 불가"
  fi
  echo "${WM}  ── conflict CTRL (계기 생존선) ──"
  echo "${WM}    CARRIER-READ  : $CFL_READ_C / $CFL_TOT_C   🟥 >0 이면 이상하다 (운반체가 없는데 심은 값을 냈다)"
  echo "${WM}    PRIOR_WON     : $CFL_PRIOR_C / $CFL_TOT_C   ← CTRL 의 «정상» 거동"
  echo "${WM}    ABSTAINED     : $CFL_ABST_C / $CFL_TOT_C"
  echo "${WM}    UNCLASSIFIED  : $CFL_UNCL_C / $CFL_TOT_C   🟥 CTRL 쪽 미분류도 «보인다»"
else
  echo "${WM}  CARRIER-READ    : UNMEASURED  (conflict 문항이 0개 — 0 으로 접지 마라)"
  echo "${WM}  🟥 그래서 위 DELIVERY 는 «운반체를 읽어서»인지 «레포/일반지식으로»인지 미검증이다"
fi

# 🟥 `_VERDICT` 파일은 **삭제했다**(2026-08-31). 반쪽 외부화였다.
#    실측: 쓰는 곳 1 · **읽는 곳 0**(손검증 — grep 3건은 전부 `FH_GATE_VERDICT` 류 다른 식별자).
#    그리고 `$OUT` 기본값이 `mktemp -d` 라 **휘발 디렉터리에 쓰고 아무도 안 보관했다.**
#    담고 있던 seal/reps/model 은 위 헤더가 이미 찍고, 판정은 아래 워터마크가 «숫자 줄마다» 나른다.
#    ⇒ 남는 건 「기계가 읽을 슬롯」이라는 이름뿐이고, 그것이 정확히 장식이다.
#    소비처를 지금 지으면 **수요 없는 투기 빌드**다(그 소비처의 known-pair 가 안 선다는 것이
#    이미 측정됐다 — 「이 라벨이 어느 주장에 붙나」는 결론이라 기계화하면 장식이 된다).
# 🟥 **다만 «타입된 판정 채널»은 안 버린다** — 그건 **종료코드**이고, 그게 정본이다.
#    그리고 여기를 들여다보다 진짜 결함을 찾았다: `exit 4` 가 **두 가지**를 뜻하고 있었다
#    (오염 게이트 = 회차 시작조차 안 함 · INSTRUMENT_INCOMPLETE = 다 돌고 계기가 미달).
#    호출자가 rc=4 만 보고 그 둘을 구분할 방법이 없었다 — 채널이 «타입돼 있다»는 말이 거짓이었다.
#    ⇒ 오염 게이트를 **5** 로 분리했다. 레인이 넷을 고정한다(`test_verdict_watermark_lanes.sh`).
# ── 🟥 완료 마커 (2026-08-31) — «개수»로 완료를 판정하지 마라 ─────────────────────
#    다른 팔이 42/42 를 보고 채점했는데 마지막 팔이 **그 파일을 아직 쓰는 중**이었다.
#    교차대조 1행 불일치로 잡혔고 판정은 안 흔들렸지만 그건 운이다.
#    ⇒ 회차 완료는 **이 마커의 존재**로만 판정한다. 마커는 모든 디스패치와 채점이 끝난
#      뒤에 쓰이므로, 있으면 산출물이 전부 닫혀 있다.
#    🟥 그리고 개수는 `*_r[0-9].txt` 로 센다 — `*_r*.txt` 는 부수파일(prompt·stderr·
#      setupdiff·treediff)까지 세서 **실측 24 를 120 으로** 부풀린다(같은 팔의 6번 슬립).
# 🟥 마커는 «무엇을 보증하는지»를 스스로 적는다 (2026-08-31, 3층 수리).
#    1층 개수로 완료를 판정했다              → 마커를 만들었다
#    2층 마커가 「루프가 끝났다」만 보증했다   → 다른 팔의 적격 실행에서 16/48 인데 DONE 이 떴다
#    3층 그래서 「complete: yes 가 «무엇을» 보증하나」 → **정의를 마커 안에 적는다**
# 🟥 `.err` 를 조건에 넣는 것이 하중이다: 그 16/48 사고는 답변 파일이 «있으면서» 클론 에러가
#    16건이었다. **개수만 맞추면 같은 사고가 또 통과한다.**
_ans=$(ls "$OUT"/*_r[0-9].txt 2>/dev/null | wc -l | tr -d ' ')
_errs=$(find "$OUT" -name '_clone_*.err' -size +0 2>/dev/null | wc -l | tr -d ' ')
if [ "$_ans" = "${#ROWS[@]}" ] && [ "$_errs" = 0 ]; then _cmp=yes; else _cmp=NO; fi
{
  echo "round: done"
  echo "verdict: $VERDICT"
  echo "seal: $(basename "$SEAL")"
  echo "qset: $(basename "$QSET")"
  echo "reps: $REPS"
  echo "answers: $_ans"
  echo "rows: ${#ROWS[@]}"
  echo "clone_errors: $_errs"
  echo "complete: $_cmp (정의: answers==rows ∧ clone_errors==0)"
  echo "qset_matches_manifest: $MANIFEST_MATCH"
} > "$OUT/_ROUND_DONE"

echo
echo "── 판정 ──"
case "$VERDICT" in
  VOID)    echo "🟥 VOID — $VDETAIL"; echo "   숫자를 내지 않는다."; exit 3 ;;
  INSTRUMENT_INCOMPLETE)
           echo "🟡 계기 미완성 — $VDETAIL"; exit 4 ;;
  CARRIER_UNREAD)
           echo "🟠 CARRIER_UNREAD — $VDETAIL"
           echo "   🟥 DELIVERY 를 «운반체가 나른 것»으로 인용하지 마라."; exit 6 ;;
  FINDING) echo "🟠 FINDING — $VDETAIL"; echo "   🟥 이건 VOID 가 아니다. 숫자를 낸다."; exit 0 ;;
  *)       echo "🟢 $VDETAIL"; exit 0 ;;
esac
