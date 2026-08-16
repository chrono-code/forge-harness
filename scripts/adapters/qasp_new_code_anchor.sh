#!/usr/bin/env bash
# qasp_new_code_anchor.sh — FH 소유 **어댑터**. peer `qasp` 의
# `scripts/new_code_anchor_scan.sh` 를 클러스터 호출 가능한 typed capability 로 감싼다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 무엇을 재나
# ─────────────────────────────────────────────────────────────────────────────
# **새로 추가된 실행 코드에 그것을 보는 앵커(테스트)가 있는가.** peer 헤더의 기원 실측:
# 앵커 0개인 신규 스크립트가 들어왔는데 CI 는 `success / 123 passed` 였다 — 그 123개 중
# 그 파일을 보는 게 하나도 없었을 뿐이다. 그 상태로 fail-open 3건이 같이 통과했다.
# 이 스캔이 닫는 것은 딱 하나: **「안 돌았다」가 「깨끗하다」로 읽히는 것.**
# 진입점은 **peer 소유 코드**이고 이 어댑터가 만든 것이 아니다.
#
# ─────────────────────────────────────────────────────────────────────────────
# VERDICT ENUM (선언과 정확히 일치해야 한다)
# ─────────────────────────────────────────────────────────────────────────────
#    0  PASS           앵커 없는 신규 실행 코드 없음
#    1  VIOLATION      앵커 없는 신규 실행 코드가 있다
#    2  ARGS           인자 오류 — 판정이 아니다
#    3  HARNESS_ERROR  ref 해석 불가 · git 실패 · 계기 부재 — 판정이 아니다
#    4  OUT_OF_SCOPE   **다른 언어의 신규 실행 코드가 있어 검사되지 않았다** — 판정이 아니다
#   20  PEER_ABSENT    **peer 하네스가 이 머신에 없다**
#
# 🟥 값 넷이 「안 쟀다」의 서로 다른 얼굴이다. peer 헤더가 같은 말을 한다 —
#    *"스캔이 못 돌았는데 1 을 내면 «위반» 으로, 0 을 내면 «깨끗» 으로 읽힌다. 둘 다 틀렸다."*
#    어댑터는 그 위에 한 층을 더 얹는다:
#      PEER_ABSENT   = 그 하네스가 이 머신에 없다   (클러스터에 대한 진술)
#      HARNESS_ERROR = 하네스는 있는데 못 쟀다      (계기에 대한 진술)
#      OUT_OF_SCOPE  = 계기는 돌았는데 대상이 사각지대다 (범위에 대한 진술)
#    `verdict_binding` 에 PASS 를 뺀 전부가 들어간다.
#
# ⚠️ 하위 계기의 exit 을 그대로 전파하지 않는다 — 아래 case 가 명시 재매핑이다.
#    peer 헤더 자신이 그걸 규율로 적어 뒀다: *"같은 숫자가 이 레포 안에서 다른 사건을
#    뜻한다 — 값을 옮겨 쓰지 마라."* (`judge_rer.sh` 의 4=BLOCKED · `pull_cli.py` 의
#    4=NO_CORPUS 와 여기의 4=OUT_OF_SCOPE 는 전부 다른 사건이다.)
#
# ─────────────────────────────────────────────────────────────────────────────
# 캘리브레이션 쌍 — **합성 레포**에서 돈다. 왜 peer 히스토리를 안 쓰나
# ─────────────────────────────────────────────────────────────────────────────
#   ① peer 의 이 진입점은 **오늘 수리 중**이다(qasp PR #174, 브랜치
#      `fix/anchor-scan-out-of-scope-repairs`). 고정 SHA 를 쌍으로 박으면 그 브랜치가
#      squash 머지되는 순간 커밋이 orphan 이 되어 쌍이 해석 불가로 죽는다.
#   ② 상대 ref(`HEAD~N`)는 커밋이 쌓이면 가리키는 구간이 조용히 움직인다 — 같은 선언이
#      다른 것을 재게 된다.
#   ③ peer 는 `residency: company` 다. peer 히스토리를 arm 으로 쓰면 캘리브레이션 출력에
#      조직 경로명이 실린다. 합성 레포는 그 표면을 아예 만들지 않는다.
#   대가: 쌍이 재는 것은 «peer 의 히스토리» 가 아니라 **«peer 의 계기가 답 아는 두 케이스를
#   가르는가»** 다. 등록 바가 M4 에서 묻는 것이 정확히 후자이므로 맞는 표적이다.
#   양성: 신규 `src/plain_config.py`(앵커 0) → VIOLATION
#   음성: 같은 파일 + `tests/test_plain_config.py`(앵커) → PASS
#   ★`src/plain_config.py` 라는 이름은 peer 자신의 B1 실측에서 온 **대조군**이다
#     (`latest_config.py` 는 `test_` 부분문자열 때문에 무검사 통과했고, `plain_config.py`
#     는 정상 차단됐다). 즉 이 양성 arm 은 peer 가 이미 손으로 가른 케이스와 같은 것이다.
#
# ─────────────────────────────────────────────────────────────────────────────
# CLEANUP-TRAP 규율 (물려받은 실패)
# ─────────────────────────────────────────────────────────────────────────────
#   OWNED_TMP(내가 만든 것, 지운다)와 peer 트리는 **다른 변수**다. OWNED_TMP 는 최초 1회만
#   대입하고 트랩이 임시경로인지 한 번 더 검문한다. peer 트리는 rm 에 절대 안 넘어간다.
#
# 사용법
#   qasp_new_code_anchor.sh --range <base-ref> [<head-ref>]   # peer 레포에서 실행
#   qasp_new_code_anchor.sh --known-positive                  # expect VIOLATION
#   qasp_new_code_anchor.sh --known-negative                  # expect PASS
set -o pipefail

PEER_NAME="qasp"
RC_PASS=0; RC_VIOLATION=1; RC_ARGS=2; RC_HARNESS=3; RC_OUT_OF_SCOPE=4; RC_PEER_ABSENT=20

_harness_error() { printf 'qasp-adapter: HARNESS_ERROR — %s\n' "$1" >&2; exit "$RC_HARNESS"; }
_args_error()    { printf 'qasp-adapter: ARGS — %s\n' "$1" >&2; exit "$RC_ARGS"; }
_peer_absent()   { printf 'qasp-adapter: PEER_ABSENT — %s\n' "$1" >&2; exit "$RC_PEER_ABSENT"; }

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_LIB="$SELF_DIR/peer_resolve.sh"
[ -r "$_LIB" ] || _harness_error "peer 해석 라이브러리 부재: $_LIB"
# shellcheck source=/dev/null
. "$_LIB"

# ── peer 해석 — tracked 파일에 운영자 홈 절대경로를 싣지 않는다 ──────────────
PEER_ROOT="$(fh_peer_resolve "$PEER_NAME")"; _rrc=$?
case "$_rrc" in
  0) ;;
  1) _peer_absent "peer «$PEER_NAME» 가 이 머신에 없다 — 안 쟀다(통과가 아니다)" ;;
  2) _harness_error "peer «$PEER_NAME» 해석이 모호하다 — 어느 트리를 쟀는지 말할 수 없으므로 판정하지 않는다" ;;
  *) _harness_error "peer 루트 목록 자체가 없다 — 전제 파손" ;;
esac

ENTRY="$PEER_ROOT/scripts/new_code_anchor_scan.sh"
[ -r "$ENTRY" ] || _harness_error "peer 진입점 부재: $ENTRY (하네스는 있으나 계기가 없다)"
command -v git >/dev/null 2>&1 || _harness_error "git 부재 — 이 계기는 git 없이는 못 돈다"

OWNED_TMP=""    # 캘리브레이션 arm 에서만 만든다. 1회 대입, 재대입 금지.
_cleanup() {
  [ -n "$OWNED_TMP" ] || return 0
  case "$OWNED_TMP" in
    /tmp/*|/var/folders/*|/private/var/folders/*)
      [ -d "$OWNED_TMP" ] && rm -rf "$OWNED_TMP" ;;
    *) printf 'qasp-adapter: cleanup 거부 — OWNED_TMP 가 임시경로가 아니다: %s\n' "$OWNED_TMP" >&2 ;;
  esac
}
trap _cleanup EXIT

# 합성 레포를 세운다. $1 = "anchored" 면 앵커 파일을 같이 넣는다.
# stdout 은 오염시키지 않는다(경로는 전역 변수로 넘긴다).
FIXTURE_REPO=""; FIXTURE_BASE=""
_build_fixture_repo() {
  local anchored="${1:-}"
  OWNED_TMP="$(mktemp -d)" || _harness_error "mktemp 실패"
  local R="$OWNED_TMP/fixture"
  mkdir -p "$R/src" "$R/tests" || _harness_error "픽스처 레포를 만들 수 없다"
  # `-c` 로 신원을 준다 — 전역 gitconfig 를 읽지도 쓰지도 않기 위해서다.
  local G=(git -c user.email=fixture@localhost -c user.name=fixture -c commit.gpgsign=false)
  ( cd "$R" && "${G[@]}" init -q . ) >/dev/null 2>&1 || _harness_error "픽스처 레포 init 실패"
  printf 'fixture base\n' > "$R/README.md"
  ( cd "$R" && "${G[@]}" add -A && "${G[@]}" commit -qm "base" ) >/dev/null 2>&1 \
    || _harness_error "픽스처 base 커밋 실패"
  FIXTURE_BASE="$( cd "$R" && git rev-parse HEAD 2>/dev/null )"
  [ -n "$FIXTURE_BASE" ] || _harness_error "픽스처 base ref 해석 실패"
  # 신규 실행 코드 1개. peer 의 대상 case(`src/*.py`)에 걸린다.
  printf 'def compute(a, b):\n    return a + b\n' > "$R/src/plain_config.py"
  if [ "$anchored" = "anchored" ]; then
    # peer 의 앵커 판정은 «HEAD 시점의 tests/ 가 이 파일의 stem 을 언급하는가» 다.
    printf 'from src.plain_config import compute\n\n\ndef test_compute():\n    assert compute(1, 2) == 3\n' \
      > "$R/tests/test_plain_config.py"
  fi
  ( cd "$R" && "${G[@]}" add -A && "${G[@]}" commit -qm "add new code" ) >/dev/null 2>&1 \
    || _harness_error "픽스처 head 커밋 실패"
  FIXTURE_REPO="$R"
}

RUN_CWD=""; BASE=""; HEAD_REF=""
case "${1:-}" in
  --known-positive) _build_fixture_repo "";         RUN_CWD="$FIXTURE_REPO"; BASE="$FIXTURE_BASE"; HEAD_REF="HEAD" ;;
  --known-negative) _build_fixture_repo "anchored"; RUN_CWD="$FIXTURE_REPO"; BASE="$FIXTURE_BASE"; HEAD_REF="HEAD" ;;
  --range)
    BASE="${2:-}"; HEAD_REF="${3:-HEAD}"
    [ -n "$BASE" ] || _args_error "--range 에 base-ref 가 필요하다"
    RUN_CWD="$PEER_ROOT"
    ;;
  '') _args_error "모드 미지정 — 돌지 않은 실행을 판정으로 렌더하지 않는다" ;;
  *)  _args_error "알 수 없는 모드 '$1'" ;;
esac

# peer 트리를 **변이하지 않는다** — `--range` 에서는 cwd 만 peer 로 두고 읽기만 한다.
# 판정은 파이프를 통과시키지 않는다(PIPE-VERDICT).
out=$(cd "$RUN_CWD" && bash "$ENTRY" "$BASE" "$HEAD_REF" 2>&1); rc=$?
printf '%s\n' "$out"

# ── 명시 재매핑 (같은 숫자, 다른 사건 — 전파가 아니다) ───────────────────────
case "$rc" in
  0) printf 'qasp-adapter: PASS — 앵커 없는 신규 실행 코드 없음\n';                       exit "$RC_PASS" ;;
  1) printf 'qasp-adapter: VIOLATION — 앵커 없는 신규 실행 코드가 있다\n';                exit "$RC_VIOLATION" ;;
  2) printf 'qasp-adapter: ARGS — peer 계기가 인자를 거부했다(판정이 아니다)\n' >&2;      exit "$RC_ARGS" ;;
  3) printf 'qasp-adapter: HARNESS_ERROR — ref 해석 불가/git 실패(판정이 아니다)\n' >&2;  exit "$RC_HARNESS" ;;
  4) printf 'qasp-adapter: OUT_OF_SCOPE — 검사되지 않은 신규 실행 코드가 있다(깨끗함이 아니다)\n' >&2
     exit "$RC_OUT_OF_SCOPE" ;;
  *) _harness_error "peer 진입점이 자기 계약 {0,1,2,3,4} 밖의 $rc 를 반환했다" ;;
esac
