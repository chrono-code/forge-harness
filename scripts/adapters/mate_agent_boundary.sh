#!/usr/bin/env bash
# mate_agent_boundary.sh — FH 소유 **어댑터**. peer `mate` 의 기존 회귀 앵커
# `scripts/blackbox_invariant_check.sh` 를 클러스터 호출 가능한 typed capability 로 감싼다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 무엇을 재나
# ─────────────────────────────────────────────────────────────────────────────
# 에이전트 명세서가 **정보경계 불변식을 여전히 담고 있는가**. peer 쪽 앵커는 산문 규칙
# 11종(입력 어휘 allowlist · 출처 기준 금지 · 도구 무관 선언 · 신뢰도 상한 · 메모리 쓰기
# 금지 …)이 편집 한 번으로 조용히 되돌아가는 것을 막는다. 그 스크립트는 **peer 소유 코드**이고
# 이 어댑터가 만든 것이 아니다 — 여기서 하는 일은 호출과 enum 재매핑뿐이다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 어댑터가 왜 FH 안에 사나 (운영자 결정 2026-08-16)
# ─────────────────────────────────────────────────────────────────────────────
# 「없는 능력을 남의 하네스에서 호출해 쓴다」의 «쓰는 쪽»이 FH 다. peer 레포 안에 선언을
# 심는 것은 그 하네스를 소유하고 **동시에 노출을 결정한** 특권적 경우이지 일반 경로가 아니다.
#
# ─────────────────────────────────────────────────────────────────────────────
# VERDICT ENUM (선언과 정확히 일치해야 한다)
# ─────────────────────────────────────────────────────────────────────────────
#    0  PASS           전건 통과 — 불변식이 대상 문서에 살아 있다
#    1  FAIL           회귀 — 불변식 문장 중 하나 이상이 사라졌다
#   10  HARNESS_ERROR  계기가 없거나 대상을 못 읽었다
#   20  PEER_ABSENT    **peer 하네스가 이 머신에 없다**
#
# 🟥 peer 스크립트 헤더가 이미 못 박아 뒀다 — *"exit 10 은 «위반 0» 이 아니다. 대상을 못 읽은
#    것이므로 검사가 시작조차 안 한 상태다."* 어댑터는 그 위에 **한 층 더** 구분을 얹는다:
#      PEER_ABSENT   = 그 하네스가 이 머신에 없다   (클러스터에 대한 진술)
#      HARNESS_ERROR = 하네스는 있는데 못 쟀다      (계기/대상에 대한 진술)
#    둘을 접으면 「이 머신에 mate 를 안 깔았다」가 「mate 가 깨졌다」와 같은 얼굴이 된다.
#    `verdict_binding` 에 PASS 를 뺀 전부가 들어간다 — 미측정을 통과로 렌더하지 않는다.
#
# ⚠️ 하위 계기의 exit 을 그대로 전파하지 않는다. 아래 case 가 명시 재매핑이다.
#    지금은 0→0 · 1→1 로 숫자가 같지만 **그건 우연이고 계약이 아니다** — peer 가 코드를
#    바꾸면 여기 case 가 갈라진다. 계약 밖 exit 은 PASS 로 흘리지 않고 HARNESS_ERROR 다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 픽스처 — **어댑터가 자기 픽스처를 갖는다**
# ─────────────────────────────────────────────────────────────────────────────
#   `scripts/adapters/fixtures/mate_agent_boundary_known_{positive,negative}.md`.
#   peer 레포의 같은 이름 파일에서 바이트 동일하게 복사했다(원본: peer 의
#   `scripts/fixtures/agent_boundary_known_*.md`).
#   ★왜 peer 의 실물 명세서를 arm 으로 안 쓰나: 실물은 팀이 계속 고치는 살아있는 문서라
#     그것을 양성 arm 으로 쓰면 이 어댑터의 판정이 **남의 편집에 따라 조용히 뒤집힌다**
#     (감사 대상은 얼려야 한다). 실물은 인자 없는 기본 호출로 계속 검사된다.
#   ★잔여(명명): 복사본이라 **드리프트한다.** peer 가 불변식을 늘리면 이 사본은 낡는다.
#     대가를 알고 고른 것이다 — peer 트리를 실행 시점에 읽으면 계기가 남의 편집에 흔들리고,
#     그건 캘리브레이션 arm 이 가져서는 안 되는 성질이다. 정합성 확인은 손으로 한다.
#   ★residency: 두 픽스처는 **합성**이고 조직 식별자를 담지 않는다 — 이 레포에 tracked 로
#     들어오기 전에 손으로 전문을 읽고, peer 자신의 식별자 denylist grep(컨트롤 포함) ·
#     경로/URL/이메일/IP grep(컨트롤 포함) · 라틴 토큰 전수 열거로 확인했다.
#
# 사용법
#   mate_agent_boundary.sh --target <file>     # 임의 명세서 파일
#   mate_agent_boundary.sh --peer-default      # peer 의 기본 대상(실물 명세서)
#   mate_agent_boundary.sh --known-positive    # 캘리브레이션 arm (expect PASS)
#   mate_agent_boundary.sh --known-negative    # 캘리브레이션 arm (expect FAIL)
set -o pipefail

PEER_NAME="mate"
RC_PASS=0; RC_FAIL=1; RC_HARNESS=10; RC_PEER_ABSENT=20

_harness_error() { printf 'mate-adapter: HARNESS_ERROR — %s\n' "$1" >&2; exit "$RC_HARNESS"; }
_peer_absent()   { printf 'mate-adapter: PEER_ABSENT — %s\n' "$1" >&2; exit "$RC_PEER_ABSENT"; }

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

ENTRY="$PEER_ROOT/scripts/blackbox_invariant_check.sh"
[ -r "$ENTRY" ] || _harness_error "peer 진입점 부재: $ENTRY (하네스는 있으나 계기가 없다)"

TARGET=""
case "${1:-}" in
  --known-positive) TARGET="$SELF_DIR/fixtures/mate_agent_boundary_known_positive.md" ;;
  --known-negative) TARGET="$SELF_DIR/fixtures/mate_agent_boundary_known_negative.md" ;;
  --peer-default)   TARGET="" ;;   # peer 스크립트의 기본 대상에 맡긴다
  --target)
    TARGET="${2:-}"
    [ -n "$TARGET" ] || _harness_error "--target 에 경로가 필요하다"
    case "$TARGET" in /*) ;; *) TARGET="$PWD/$TARGET" ;; esac
    ;;
  '') _harness_error "모드 미지정 — 돌지 않은 실행을 판정으로 렌더하지 않는다" ;;
  *)  _harness_error "알 수 없는 모드 '$1'" ;;
esac
if [ -n "$TARGET" ]; then
  [ -e "$TARGET" ] || _harness_error "대상 경로가 없다: $TARGET (부재 대상은 빈 대상이 아니다)"
  [ -r "$TARGET" ] || _harness_error "대상 경로를 읽을 수 없다: $TARGET"
fi

# peer 트리를 **변이하지 않는다** — cwd 만 peer 로 두고 읽기만 한다.
# (기본 대상이 peer 레포 상대경로라 cwd 가 peer 여야 한다.)
# 판정은 파이프를 통과시키지 않는다(PIPE-VERDICT).
if [ -n "$TARGET" ]; then
  out=$(cd "$PEER_ROOT" && bash "$ENTRY" "$TARGET" 2>&1); rc=$?
else
  out=$(cd "$PEER_ROOT" && bash "$ENTRY" 2>&1); rc=$?
fi
printf '%s\n' "$out"

# ── 명시 재매핑 (같은 숫자, 다른 사건 — 전파가 아니다) ───────────────────────
case "$rc" in
  0)  printf 'mate-adapter: PASS — 정보경계 불변식 전건 통과\n';          exit "$RC_PASS" ;;
  1)  printf 'mate-adapter: FAIL — 불변식 회귀\n';                        exit "$RC_FAIL" ;;
  10) printf 'mate-adapter: HARNESS_ERROR — peer 계기가 대상을 못 읽었다(위반 0 이 아니다)\n' >&2
      exit "$RC_HARNESS" ;;
  *)  _harness_error "peer 진입점이 자기 계약 {0,1,10} 밖의 $rc 를 반환했다" ;;
esac
