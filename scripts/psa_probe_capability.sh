#!/usr/bin/env bash
# psa_probe_capability.sh — public-surface-audit 기계층의 **capability 진입점**.
#
# 왜 별도 파일인가: `public_surface_scan_files.sh` 는 publish 경계 전용(exit 1 = 차단)이고
# npm **배포 파일셋**(package.json files[])만 스캔한다. capability 로 등록하려면 §ⓑ.2 가
# 요구하는 것 — 닫힌 enum · 「안 돌았다」 구분 · 캘리브레이션 쌍 argv — 을 갖춘 진입점이
# 필요하고, 스코프도 다르다: 여기는 **전 tracked 파일**을 본다.
#   ⚠️ 두 표면은 서로를 포함하지 않는다 — npm PASS 는 공개 표면 PASS 가 아니다
#      (레포가 public 이면 files[] 밖 tracked 파일도 GitHub 이 이미 게시하고 있다).
# 스캔 로직은 재구현하지 않고 `psa_scan_lib.sh` 를 그대로 쓴다(단일 소스).
#
# verdict enum (declared): 0=CLEAN 1=LEAK 3=NOT_CONFIGURED 10=HARNESS_ERROR
#   3 은 「돌았는데 깨끗」이 아니라 「스캔할 패턴이 없어 아무것도 안 봤다」다 — §ⓑ.4 B1.
#
# 🟥 정리 트랩 규율(자매 파일 degrade_probe 의 실사고에서): 트랩이 지우는 변수는
#    **재대입하지 않는다**. OWNED_TMP 는 내가 만든 것만 가리키고, 스캔 대상은 별 변수다.
set -o pipefail
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
LIB="$REPO_ROOT/scripts/psa_scan_lib.sh"
[ -r "$LIB" ] || { echo "psa-probe: scan lib 부재 — 계기가 없다"; exit 10; }
. "$LIB" || { echo "psa-probe: scan lib 로드 실패"; exit 10; }

OWNED_TMP="$(mktemp -d)"      # 재대입 금지
_cleanup() {
  case "$OWNED_TMP" in
    /tmp/*|/var/folders/*) [ -d "$OWNED_TMP" ] && rm -rf "$OWNED_TMP" ;;
    *) echo "psa-probe: cleanup 거부 — OWNED_TMP 가 임시 경로가 아니다: $OWNED_TMP" >&2 ;;
  esac
}
trap _cleanup EXIT

MODE="${1:-}"
IN="$OWNED_TMP/in"
SCAN_NOTE=""

# 합성 양성 토큰은 **조각으로 보관하고 실행 시 조립**한다. 통짜 리터럴을 두면 이 파일 자체가
# MED 히트가 되어 pre-commit 기밀 스캔에 걸린다 — 실제로 걸렸고(2026-08-11), 그 차단은 옳았다.
# 우회(override)가 아니라 스킬 자신의 2층 규율(리터럴은 추적 파일에 두지 않는다)을 따르는 게 답이다.
_synth_home_token() { printf '/Users/%s/' "realuser1234"; }

case "$MODE" in
  --known-positive)   # 답을 아는 양성: 조립된 홈경로 토큰을 심은 합성 입력
    printf 'synthetic_fixture.md\tsee %ssecret for detail\n' "$(_synth_home_token)" > "$IN" ;;
  --known-negative)   # 답을 아는 음성: 어떤 패턴에도 안 걸리는 합성 입력
    printf 'synthetic_fixture.md\tperfectly ordinary documentation line\n' > "$IN" ;;
  --tracked|'')       # 실사용: 이 레포의 tracked 파일 전량
    # `-z` (NUL 구분) 필수: 기본 `core.quotePath=true` 는 비-ASCII 파일명을 따옴표+8진
    # 이스케이프로 내보내므로, 줄 단위로 읽으면 그 파일들이 **무음으로 스캔에서 빠지고**
    # 결과는 CLEAN 이 된다(못 잰 것을 0으로 렌더). 드롭은 세어서 보고한다.
    git -C "$REPO_ROOT" ls-files -z > "$OWNED_TMP/files" 2>/dev/null || { echo "psa-probe: git 도달 불가"; exit 10; }
    : > "$IN"; scanned=0; dropped=0
    while IFS= read -r -d '' f; do
      if [ ! -f "$REPO_ROOT/$f" ]; then dropped=$((dropped+1)); continue; fi
      if awk -v p="$f" '{printf "%s\t%s\n", p, $0}' "$REPO_ROOT/$f" >> "$IN" 2>/dev/null; then
        scanned=$((scanned+1))
      else dropped=$((dropped+1)); fi
    done < "$OWNED_TMP/files"
    SCAN_NOTE=" (스캔 $scanned 파일$([ "$dropped" -gt 0 ] && printf ', 드롭 %s' "$dropped"))"
    [ "$dropped" -gt 0 ] && { echo "psa-probe: HARNESS_ERROR — 읽지 못한 tracked 파일 $dropped 개(부분 스캔은 CLEAN 을 증명하지 못한다)"; exit 10; } ;;
  *) echo "psa-probe: 알 수 없는 모드 '$MODE'"; exit 10 ;;
esac

psa_load "$REPO_ROOT/.claude/rules/.public-surface-patterns.defaults" \
         "${PSA_PATTERNS:-$REPO_ROOT/.claude/rules/.public-surface-patterns}" \
  || { echo "psa-probe: 패턴 로드 실패"; exit 10; }

# 「안 돌았다」와 「돌았는데 깨끗」의 구분 — 패턴 층이 하나도 없으면 스캔한 게 없다
if [ "${PSA_DEFAULTS_OK:-0}" -eq 0 ] && [ "${PSA_OVERRIDE_PRESENT:-0}" -eq 0 ]; then
  echo "psa-probe: NOT_CONFIGURED — 패턴 층 부재, 아무것도 스캔하지 않았다"; exit 3
fi
[ "${PSA_BAD_ROWS:-0}" -gt 0 ] && { echo "psa-probe: HARNESS_ERROR — 못 쓰는 패턴 행 $PSA_BAD_ROWS 개"; exit 10; }

psa_scan_tagged < "$IN"; hit_rc=$?     # verdict 는 직접 취한다(PIPE-VERDICT)
case "$hit_rc" in
  0) echo "psa-probe: CLEAN${SCAN_NOTE}"; exit 0 ;;
  1) echo "psa-probe: LEAK${SCAN_NOTE}"; exit 1 ;;
  *) echo "psa-probe: HARNESS_ERROR — scan_tagged 가 enum 밖 $hit_rc 반환"; exit 10 ;;
esac
