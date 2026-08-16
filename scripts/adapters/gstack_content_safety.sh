#!/usr/bin/env bash
# gstack_content_safety.sh — FH 소유 **어댑터**. peer `gstack` 의 redact 엔진을
# 클러스터 호출 가능한 typed capability 로 감싼다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 어댑터가 왜 FH 안에 사나 (운영자 결정 2026-08-16)
# ─────────────────────────────────────────────────────────────────────────────
# 「없는 능력을 남의 하네스에서 호출해 쓴다」가 크로스하네스의 요점이고, 그 «쓰는 쪽»은
# FH 다. peer 레포 안에 선언을 심는 것은 **그 하네스를 소유하고 동시에 노출을 결정한**
# 특권적 경우이고, 일반 경로가 아니다. 그래서 선언과 래퍼가 여기 산다.
# gstack 레포에도 같은 목적의 래퍼(`scripts/content-safety-capability.sh`)가 있다 —
# 이 파일은 그것의 **FH 측 이식본**이다(로직·enum·근거를 옮겼다). peer 가 그 래퍼를
# 갖고 있든 아니든 돌게 하려고 엔진(`bin/gstack-redact`)을 직접 부른다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 왜 `bin/gstack-redact` 를 그냥 선언하지 않나 (gstack 래퍼 헤더에서 옮겨온 근거)
# ─────────────────────────────────────────────────────────────────────────────
#   그 CLI 의 exit 은 {0 clean, 2 MEDIUM, 3 HIGH} 에 «git 레포가 아니다» 용 1 이 붙는다.
#   **「아무것도 안 쟀다」를 뜻하는 값이 없다** — 빈 파일도, 스캔 대상이 0개인 디렉토리도,
#   인터프리터 부재도 전부 exit 0 = CLEAN 으로 렌더된다. 「PASS 가 no-op 과 구분 불가」는
#   등록 바가 정확히 거부하는 형태다(§ⓑ.4 B1).
#   CLI 의 코드를 바꾸는 선택지는 **일부러 버렸다** — gstack 의 다른 스킬과 pre-push 훅이
#   그 코드를 소비한다. 설명하는 행위로 남의 레포 계약을 조용히 바꾸지 않는다.
#
# ─────────────────────────────────────────────────────────────────────────────
# VERDICT ENUM (선언과 정확히 일치해야 한다)
# ─────────────────────────────────────────────────────────────────────────────
#    0  CLEAN          실제 내용 1바이트 이상을 쟀고 HIGH·MEDIUM 둘 다 없다
#    1  BLOCK_HIGH     HIGH 등급 findings 있음
#    2  REVIEW_MEDIUM  MEDIUM 만 있음 — 자동 차단이 아니라 사람 판단
#    3  NO_TARGET      잴 게 없었다(빈 파일 · 후보 0개 디렉토리)
#                      *** CLEAN 이 아니다 — 스캔이 시작조차 안 했다 ***
#   10  HARNESS_ERROR  계기가 없거나 깨졌다(bun 부재 · CLI/엔진 부재 · 대상 불가독 ·
#                      열거 실패 · 하위 CLI 가 자기 계약 밖 코드 반환)
#   20  PEER_ABSENT    **peer 하네스가 이 머신에 없다**
#
# 🟥 셋은 서로 다른 명제다 — 접으면 안 된다:
#      PEER_ABSENT   = 그 노드가 이 머신에 없다        (클러스터에 대한 진술)
#      HARNESS_ERROR = 노드는 있는데 계기가 깨졌다      (계기에 대한 진술)
#      NO_TARGET     = 계기는 멀쩡한데 잴 대상이 없다   (대상에 대한 진술)
#    `verdict_binding` 에 셋 다 들어간다. 미측정이 통과로 렌더되면 이 어댑터는 장식이다.
#
# ⚠️ 하위 계기의 exit 을 **그대로 전파하지 않는다.** 아래 case 가 명시 재매핑이다
#    (같은 숫자, 다른 사건 — gstack 의 3=HIGH 는 여기서 1=BLOCK_HIGH 다).
#
# ─────────────────────────────────────────────────────────────────────────────
# CLEANUP-TRAP 규율 (물려받은 실패 — 가정이 아니다)
# ─────────────────────────────────────────────────────────────────────────────
#   자매 하네스의 첫 capability 래퍼가 자기 레포의 `scripts/` 를 지웠다:
#   `TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT` 를 걸고 다른 분기에서 $TMP 를 실제
#   레포 경로로 **재대입**했다. 트랩은 «만든 것» 이 아니라 «지금 가리키는 것» 을 지운다.
#   구조 처방: OWNED_TMP(내 것, 지운다)와 TARGET(재는 것, 절대 안 지운다)을 다른 변수로
#   두고, OWNED_TMP 는 최초 1회만 대입하며, 트랩이 임시경로인지 한 번 더 검문한다.
#
# 사용법
#   gstack_content_safety.sh --target <file|dir>
#   gstack_content_safety.sh --known-positive     # 캘리브레이션 arm (expect BLOCK_HIGH)
#   gstack_content_safety.sh --known-negative     # 캘리브레이션 arm (expect CLEAN)
set -o pipefail

PEER_NAME="gstack"
RC_CLEAN=0; RC_BLOCK=1; RC_REVIEW=2; RC_NO_TARGET=3; RC_HARNESS=10; RC_PEER_ABSENT=20

_harness_error() { printf 'gstack-adapter: HARNESS_ERROR — %s\n' "$1" >&2; exit "$RC_HARNESS"; }
_peer_absent()   { printf 'gstack-adapter: PEER_ABSENT — %s\n' "$1" >&2; exit "$RC_PEER_ABSENT"; }

# ── peer 해석 — 절대경로를 이 파일에 싣지 않는다 ─────────────────────────────
# tracked 파일에 운영자 홈 절대경로가 들어가면 그건 공개 표면 유출이다.
_LIB="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/peer_resolve.sh"
[ -r "$_LIB" ] || _harness_error "peer 해석 라이브러리 부재: $_LIB"
# shellcheck source=/dev/null
. "$_LIB"

PEER_ROOT="$(fh_peer_resolve "$PEER_NAME")"; _rrc=$?
case "$_rrc" in
  0) ;;
  1) _peer_absent "peer «$PEER_NAME» 가 이 머신에 없다 — 안 쟀다(깨끗한 게 아니다)" ;;
  2) _harness_error "peer «$PEER_NAME» 해석이 모호하다 — 어느 트리를 쟀는지 말할 수 없으므로 판정하지 않는다" ;;
  *) _harness_error "peer 루트 목록 자체가 없다 — 전제 파손" ;;
esac

CLI="$PEER_ROOT/bin/gstack-redact"
ENGINE="$PEER_ROOT/lib/redact-engine.ts"

# ── 계기 전제 (계기의 부재는 결코 «깨끗함» 이 아니다) ────────────────────────
# peer 레포는 있는데 그 안의 엔진이 없다 = 계기 파손이지 노드 부재가 아니다.
[ -r "$CLI" ]    || _harness_error "스캐너 CLI 부재: $CLI (peer 는 있으나 계기가 없다)"
[ -r "$ENGINE" ] || _harness_error "스캔 엔진 부재: $ENGINE"
command -v bun  >/dev/null 2>&1 || _harness_error "bun 이 PATH 에 없다 — 스캐너를 돌릴 수 없다(깨끗한 결과가 아니다)"
command -v find >/dev/null 2>&1 || _harness_error "find 부재 — 대상을 열거할 수 없다(열거 불가는 부재가 아니다)"

OWNED_TMP="$(mktemp -d)" || _harness_error "mktemp 실패"   # 1회 대입. 절대 재대입 금지.
_cleanup() {
  case "$OWNED_TMP" in
    /tmp/*|/var/folders/*|/private/var/folders/*)
      [ -d "$OWNED_TMP" ] && rm -rf "$OWNED_TMP" ;;
    *) printf 'gstack-adapter: cleanup 거부 — OWNED_TMP 가 임시경로가 아니다: %s\n' "$OWNED_TMP" >&2 ;;
  esac
}
trap _cleanup EXIT

TARGET=""   # 실제 레포 내용을 가리킬 수 있다. 절대 안 지우고 rm 에 넘기지 않는다.

case "${1:-}" in
  --known-positive)
    # 리터럴을 printf 인자로 **쪼갠다** — 이 소스 자신이 자격증명 형태 스캐너에 걸리면
    # 픽스처가 자기 레포를 발행 불가로 만든다.
    TARGET="$OWNED_TMP/known_positive.txt"
    {
      printf 'deploy notes\n'
      printf 'aws_access_key_id=%s%s\n' 'AKIA' '1234567890ABCDEF'
      printf 'contact ssn %s-%s-%s for payroll\n' '123' '45' '6789'
    } > "$TARGET" || _harness_error "known-positive 픽스처를 쓸 수 없다"
    ;;
  --known-negative)
    # 같은 형태·같은 크기대, 자격증명도 PII 도 없다. 컨트롤이 있어야 PASS 가
    # 「이 계기가 가른다」이지 「이 계기가 조용하다」가 아니게 된다.
    TARGET="$OWNED_TMP/known_negative.txt"
    {
      printf 'deploy notes\n'
      printf 'the build pipeline reads its credentials from the platform keystore\n'
      printf 'contact the payroll team through the internal ticket queue\n'
    } > "$TARGET" || _harness_error "known-negative 픽스처를 쓸 수 없다"
    ;;
  --target)
    TARGET="${2:-}"
    [ -n "$TARGET" ] || _harness_error "--target 에 경로가 필요하다"
    [ -e "$TARGET" ] || _harness_error "--target 경로가 없다: $TARGET (부재 대상은 빈 대상이 아니다)"
    [ -r "$TARGET" ] || _harness_error "--target 경로를 읽을 수 없다: $TARGET"
    ;;
  '') _harness_error "대상 미지정 — 돌지 않은 실행을 판정으로 렌더하지 않는다" ;;
  *)  _harness_error "알 수 없는 모드 '$1'" ;;
esac

# ── 후보 열거 ────────────────────────────────────────────────────────────────
# 「열거 실패」와 「후보 0개」는 다른 사실이다. find 자체가 실패하면 대상을 **안 잰**
# 것이므로 HARNESS_ERROR 이지 NO_TARGET 이 아니다.
CAND_LIST="$OWNED_TMP/.candidates"
if [ -d "$TARGET" ]; then
  _ferr=$(find -H "$TARGET" \( -name .git -o -name node_modules -o -name dist \) -prune -o \
                -type f -print 2>&1 >"$CAND_LIST")
  _frc=$?
  if [ "$_frc" -ne 0 ] || [ -n "$_ferr" ]; then
    _harness_error "대상 열거 실패(부재 대상이 아니다): ${_ferr:-find exited $_frc}"
  fi
else
  printf '%s\n' "$TARGET" > "$CAND_LIST"
fi

SCANNED=0
WORST=0            # 심각도 순서: CLEAN < REVIEW_MEDIUM < BLOCK_HIGH (숫자 순서가 아니다)
_rank() { case "$1" in 0) echo 0 ;; 2) echo 1 ;; 1) echo 2 ;; *) echo 9 ;; esac; }

while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] && [ -r "$f" ] || continue
  LC_ALL=C grep -Iq . "$f" 2>/dev/null || continue          # 바이너리는 대상이 아니다
  [ -n "$(tr -d '[:space:]' < "$f" 2>/dev/null | head -c 1)" ] || continue   # 공백뿐 = 내용 없음

  # 판정은 파이프를 통과시키지 않는다(PIPE-VERDICT).
  out=$(cd "$PEER_ROOT" && bun "$CLI" --from-file "$f" 2>&1); rc=$?
  case "$rc" in
    0|2|3) ;;
    *) _harness_error "스캐너가 자기 계약 {0,2,3} 밖의 $rc 를 반환했다: $f" ;;
  esac
  SCANNED=$((SCANNED + 1))
  # 명시 재매핑 — gstack 3=HIGH → 1 · 2=MEDIUM → 2 · 0 → 0
  case "$rc" in 3) mapped=1 ;; 2) mapped=2 ;; *) mapped=0 ;; esac
  if [ "$(_rank "$mapped")" -gt "$(_rank "$WORST")" ]; then WORST="$mapped"; fi
  if [ "$mapped" != "0" ]; then
    printf 'gstack-adapter: %s\n' "$f"
    printf '%s\n' "$out" | sed -n '2,6p'
  fi
done < "$CAND_LIST"

if [ "$SCANNED" -eq 0 ]; then
  printf 'gstack-adapter: NO_TARGET — %s 아래 스캔 가능한 파일 0개 (CLEAN 이 아니다. 아무것도 안 쟀다)\n' "$TARGET"
  exit "$RC_NO_TARGET"
fi

case "$WORST" in
  0) printf 'gstack-adapter: CLEAN — %d개 파일 스캔, HIGH·MEDIUM 없음\n' "$SCANNED"; exit "$RC_CLEAN" ;;
  2) printf 'gstack-adapter: REVIEW_MEDIUM — %d개 파일 스캔, MEDIUM findings 있음\n' "$SCANNED"; exit "$RC_REVIEW" ;;
  1) printf 'gstack-adapter: BLOCK_HIGH — %d개 파일 스캔, HIGH findings 있음\n' "$SCANNED"; exit "$RC_BLOCK" ;;
  *) _harness_error "내부 심각도 집계가 '$WORST' 를 냈다" ;;
esac
