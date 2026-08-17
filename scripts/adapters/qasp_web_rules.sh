#!/usr/bin/env bash
# qasp_web_rules.sh — FH 소유 **어댑터**. peer `qasp` 의
# `scripts/web_rules_pr_scan.sh`(1.5막 웹 셀렉터-안정성 rule 세트)를 클러스터 호출 가능한
# typed capability 로 감싼다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 무엇을 재나
# ─────────────────────────────────────────────────────────────────────────────
# **웹 E2E 테스트 diff 에 로케이터/대기 규율 위반이 들어왔는가.** rule 5종
# (`web-coordinate-click` · `web-wait-for-timeout` 등 — LOCATOR_DISCIPLINE ·
# ASSERTION_STRENGTH 렌즈). peer 헤더의 기원 실측: 이 rule 테이블은 2026-07-24 부터
# 있었지만 **부르는 사람이 없었다**(2026-07-27 실측: 프로덕션 호출자 0건, tests/ 와
# 자기 자신뿐). *"호출자가 없는 검출기는 산문이지 게이트가 아니다."*
# 진입점은 **peer 소유 코드**이고 이 어댑터가 만든 것이 아니다.
#
# ─────────────────────────────────────────────────────────────────────────────
# VERDICT ENUM (선언과 정확히 일치해야 한다)
# ─────────────────────────────────────────────────────────────────────────────
#    0  CLEAN          위반 0건
#    1  FINDINGS       위반 존재
#    2  ARGS           인자 오류 — 판정이 아니다
#    3  ENGINE_ERROR   스캔이 못 돌았다(python 부재 · 입력 불가 · 대상 0개) — 판정이 아니다
#   20  PEER_ABSENT    **peer 하네스가 이 머신에 없다**
#
# 🟥 **`2` 는 peer 셸 헤더에 안 적혀 있다** — 그 헤더는 `0/1/3` 만 적는다. 그러나 하위
#    python CLI(`src/static_review/web_rules.py`)가 `parser.error()` 를 쓰고 argparse 는
#    **exit 2** 를 내며, 셸 래퍼는 `exit "$RC"` 로 **그대로 전파**한다(실측 2026-08-17).
#    즉 문서화된 계약보다 실제 계약이 한 값 넓다. 어댑터는 **실제 계약**을 선언한다 —
#    안 그러면 argparse 오류가 `*)` 로 떨어져 HARNESS_ERROR 가 되고, 「인자를 틀렸다」가
#    「계기가 깨졌다」로 렌더된다.
#
# 🟥 값 셋이 「안 쟀다」의 서로 다른 얼굴이다:
#      ARGS(2)         인자가 틀렸다            (호출에 대한 진술)
#      ENGINE_ERROR(3) 하네스는 있는데 못 쟀다  (계기에 대한 진술)
#      PEER_ABSENT(20) 그 노드가 이 머신에 없다 (클러스터에 대한 진술)
#    peer 가 자기 규율로 이미 적어 뒀다 — *"exit 3 을 0 으로 뭉개지 않는다. 못 잰 것을
#    깨끗하다고 보고하는 순간 게이트가 장식이 된다."* 어댑터는 그 위에 PEER_ABSENT 만 더한다.
#
# ⚠️ 하위 exit 을 **전파하지 않는다** — 아래 case 가 명시 재매핑이다. 같은 숫자가 이
#    클러스터 안에서 다른 사건을 뜻한다(`new_code_anchor_scan.sh` 의 `4=OUT_OF_SCOPE` ·
#    `judge_rer.sh` 의 `4=BLOCKED` · `pull_cli.py` 의 `4=NO_CORPUS`).
#
# ─────────────────────────────────────────────────────────────────────────────
# 🟥 `writes: write-local` — read-only 가 **아니다.** cold 실측이 근거다
# ─────────────────────────────────────────────────────────────────────────────
# 진입점이 `python -m src.static_review.web_rules` 를 부르고, 그 import 폐포가
# `src/config/settings.py` 의 **import 시점 `ensure_dirs()`** 에 닿는다.
#
#   warm(운영자 실 트리) 실측 : 트리 변화 **없음**  ← 🟥 이것을 근거로 쓰면 안 된다
#   cold(격리 클론) 실측      : 신규 엔트리 **25개**
#     · `__pycache__` 디렉토리 5 + `.pyc` 파일 18
#     · **빈 디렉토리 `./tmp` · `./uploads`**   ← `mkdir(exist_ok=True)` 의 산물
#
# warm 이 깨끗해 보인 이유는 그 디렉토리들이 **이미 있어서** mkdir 이 무음 no-op 이었기
# 때문이다 — **warm cache 아티팩트지 read-only 의 증거가 아니다.**
# ★그리고 저 «빈 디렉토리» 는 2026-08-17 이전의 M6 이펙트 프로브가 **구조적으로 못 보던**
#  형태다(`_snapshot` 이 `-type f` 라 파일만 셌다). FH PR #422 로 그 축을 넣었고,
#  그래서 이 선언은 **이제 기계로 검증·반증된다.** 그 전이었으면 거짓 `read-only` 로
#  선언해도 VERIFIED 를 받았다.
#
# ⚠️ **명시 잔여 — M6 는 peer 트리를 안 본다.** 프로브의 «샌드박스 밖» 감시면은 임시
#    카나리아 하나와 `$HOME` 엔트리 목록뿐이다. 어댑터는 **정의상 peer 트리에서 돌므로**,
#    이 capability 의 가장 실질적인 쓰기 표면이 프로브의 감시 밖에 있다. 위 cold 수치는
#    프로브 판정이 아니라 **손 실측**이다. 이 갭은 이 파일이 만든 게 아니라 어댑터 클래스
#    전체의 성질이고, 여기 이름으로 남긴다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 캘리브레이션 쌍 — **FH 소유 픽스처**, 오프라인·결정적
# ─────────────────────────────────────────────────────────────────────────────
#   양성: `fixtures/qasp_web_rules_known_positive.json` — `page.wait_for_timeout(3000)`
#         → `web-wait-for-timeout` 발화 → FINDINGS
#   음성: `fixtures/qasp_web_rules_known_negative.json` — `get_by_role(...).click()`
#         → 위반 0 → CLEAN
#   ★왜 peer 픽스처를 안 쓰나: peer 의 `tests/` 는 그 레포 사정으로 움직인다. 남의 트리에
#    있는 픽스처에 의존하는 계기는 **별도 계기가 아니라 그 레포의 일부**다.
#   ★왜 PR 번호 모드를 안 쓰나: `gh api` 가 필요해 **네트워크·인증에 의존**하고, 그러면
#    등록 바의 M4 가 「계기가 판별하는가」가 아니라 「오늘 gh 가 되는가」를 재게 된다.
#   ★residency: peer 는 company 다. 이 두 픽스처는 **우리가 지은 합성 diff** 라 조직
#    식별자가 없다 — 캘리브레이션 출력에 조직 경로가 실리지 않는다.
#
# 사용법
#   qasp_web_rules.sh --diff-json <path>     # peer 레포에서 실행, 실제 diff 스캔
#   qasp_web_rules.sh --known-positive       # expect FINDINGS
#   qasp_web_rules.sh --known-negative       # expect CLEAN
set -o pipefail

PEER_NAME="qasp"
RC_CLEAN=0; RC_FINDINGS=1; RC_ARGS=2; RC_ENGINE=3; RC_HARNESS=10; RC_PEER_ABSENT=20

_harness_error() { printf 'qasp-web-rules: HARNESS_ERROR — %s\n' "$1" >&2; exit "$RC_HARNESS"; }
_args_error()    { printf 'qasp-web-rules: ARGS — %s\n' "$1" >&2; exit "$RC_ARGS"; }
_peer_absent()   { printf 'qasp-web-rules: PEER_ABSENT — %s\n' "$1" >&2; exit "$RC_PEER_ABSENT"; }

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_LIB="$SELF_DIR/peer_resolve.sh"
[ -r "$_LIB" ] || _harness_error "peer 해석 라이브러리 부재: $_LIB"
# shellcheck source=/dev/null
. "$_LIB"

PEER_ROOT="$(fh_peer_resolve "$PEER_NAME")"; _rrc=$?
case "$_rrc" in
  0) ;;
  1) _peer_absent "peer «$PEER_NAME» 가 이 머신에 없다 — 안 쟀다(통과가 아니다)" ;;
  2) _harness_error "peer «$PEER_NAME» 해석이 모호하다 — 어느 트리를 쟀는지 말할 수 없으므로 판정하지 않는다" ;;
  *) _harness_error "peer 루트 목록 자체가 없다 — 전제 파손" ;;
esac

ENTRY="$PEER_ROOT/scripts/web_rules_pr_scan.sh"
[ -r "$ENTRY" ] || _harness_error "peer 진입점 부재: $ENTRY (하네스는 있으나 계기가 없다)"

DIFF_JSON=""
case "${1:-}" in
  --known-positive) DIFF_JSON="$SELF_DIR/fixtures/qasp_web_rules_known_positive.json" ;;
  --known-negative) DIFF_JSON="$SELF_DIR/fixtures/qasp_web_rules_known_negative.json" ;;
  --diff-json)
    DIFF_JSON="${2:-}"
    [ -n "$DIFF_JSON" ] || _args_error "--diff-json 뒤에 경로가 필요하다"
    ;;
  '') _args_error "모드 미지정 — 돌지 않은 실행을 판정으로 렌더하지 않는다" ;;
  *)  _args_error "알 수 없는 모드 '$1'" ;;
esac

# 픽스처 부재는 **ARGS 가 아니라 HARNESS_ERROR** 다 — 캘리브레이션 쌍이 사라진 것은
# 「호출을 잘못했다」가 아니라 「이 계기가 자기 판별력을 증명할 수 없다」는 뜻이다.
case "${1:-}" in
  --known-positive|--known-negative)
    [ -r "$DIFF_JSON" ] || _harness_error "캘리브레이션 픽스처 부재: $DIFF_JSON" ;;
  *)
    [ -r "$DIFF_JSON" ] || _args_error "읽을 수 없는 diff-json: $DIFF_JSON" ;;
esac

# peer 의 진입점은 `git rev-parse --show-toplevel` 로 자기 루트를 잡으므로 **cwd 가 peer 여야**
# 한다. 판정은 파이프를 통과시키지 않는다(PIPE-VERDICT).
# `PYTHON` 을 명시로 넘긴다 — peer 의 기본값이 `$REPO_ROOT/.venv/bin/python` 이라 이미 맞지만,
# 그 폴백(`command -v python3`)이 발동하면 **의존성 없는 인터프리터**로 떨어져 ENGINE_ERROR 가
# 나고, 그건 「이 머신에 뭐가 깔렸나」를 재는 것이 된다. 명시하면 그 갈림이 안 생긴다.
_PY="$PEER_ROOT/.venv/bin/python"
if [ -x "$_PY" ]; then
  out=$(cd "$PEER_ROOT" && PYTHON="$_PY" bash "$ENTRY" --files "$DIFF_JSON" 2>&1); rc=$?
else
  out=$(cd "$PEER_ROOT" && bash "$ENTRY" --files "$DIFF_JSON" 2>&1); rc=$?
fi
printf '%s\n' "$out"

# ── 명시 재매핑 (같은 숫자, 다른 사건 — 전파가 아니다) ───────────────────────
case "$rc" in
  0) printf 'qasp-web-rules: CLEAN — 웹 로케이터/대기 규율 위반 0건\n';                       exit "$RC_CLEAN" ;;
  1) printf 'qasp-web-rules: FINDINGS — 위반이 있다\n';                                       exit "$RC_FINDINGS" ;;
  2) printf 'qasp-web-rules: ARGS — peer 계기가 인자를 거부했다(판정이 아니다)\n' >&2;        exit "$RC_ARGS" ;;
  3) printf 'qasp-web-rules: ENGINE_ERROR — 스캔이 돌지 못했다. «위반 0» 이 아니다\n' >&2;    exit "$RC_ENGINE" ;;
  *) _harness_error "peer 진입점이 자기 계약 {0,1,2,3} 밖의 $rc 를 반환했다" ;;
esac
