#!/usr/bin/env bash
# degrade_probe_capability.sh — degrade_direction_scan 의 **capability 진입점**.
#
# node A(psa) 와 다른 계보의 다른 질문이다: 내용이 아니라 «판정이 어느 방향으로
# 무너지나»(fail-open 여부)를 본다. 스캔 로직은 재구현하지 않고 기존 스캐너를 부른다.
#
# verdict enum (declared): 0=CLEAN 2=FINDINGS 3=NO_TARGET 10=HARNESS_ERROR
#   3 은 원 스캐너가 exit 0 으로 뭉개던 «스캔할 py/sh 대상이 없다» 를 분리한 값이다 —
#   그 0 은 «깨끗» 이 아니라 «시작조차 안 함» 이고, 정확히 §ⓑ.4 B1 이 막는 형태다.
#
# 🟥 이 파일의 초판이 이 레포의 `scripts/` 를 통째로 지웠다 (2026-08-11, 실발생).
#    기전: `TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT` 로 정리 트랩을 건 뒤,
#    무인자 분기에서 **같은 변수에 실제 레포 경로를 재대입**했다 → 트랩이 종료 시
#    `rm -rf $REPO_ROOT/scripts` 를 실행. 트랩은 «내가 만든 것» 이 아니라
#    «그 변수가 지금 가리키는 것» 을 지운다.
#    **처방(구조적)**: 정리 대상(OWNED_TMP)과 스캔 대상(TARGET)을 **다른 변수로 분리**하고,
#    트랩은 OWNED_TMP 만 본다. OWNED_TMP 는 최초 대입 후 절대 재대입하지 않는다.
#    그리고 트랩 안에서 경로가 mktemp 산출물인지 한 번 더 검문한다(두 번째 방벽).
set -o pipefail
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SCAN="$REPO_ROOT/scripts/degrade_direction_scan.sh"
[ -r "$SCAN" ] || { echo "degrade-probe: 스캐너 부재 — 계기가 없다"; exit 10; }

OWNED_TMP="$(mktemp -d)"      # ← 내가 만든 것. 재대입 금지.
_cleanup() {
  # 두 번째 방벽: 트랩이 지우는 경로가 정말 내가 만든 임시 디렉토리인지 검문한다.
  case "$OWNED_TMP" in
    /tmp/*|/var/folders/*) [ -d "$OWNED_TMP" ] && rm -rf "$OWNED_TMP" ;;
    *) echo "degrade-probe: cleanup 거부 — OWNED_TMP 가 임시 경로가 아니다: $OWNED_TMP" >&2 ;;
  esac
}
trap _cleanup EXIT

MODE="${1:-}"
TARGET=""                     # ← 스캔 대상. 실제 레포 경로를 가리킬 수 있다. 절대 안 지운다.

case "$MODE" in
  --known-positive)   # 답을 아는 양성: 교과서적 fail-open (검사 실패인데 성공 반환)
    TARGET="$OWNED_TMP"
    cat > "$TARGET/probe_target.sh" <<'FIX'
#!/bin/sh
verify_integrity() {
  scan=$(run_scan) || return 0     # 검사가 에러났는데 성공으로 반환 = fail-open
  echo "$scan"
}
FIX
    ;;
  --known-negative)   # 답을 아는 음성: 같은 모양인데 방향이 옳은 대조군
    TARGET="$OWNED_TMP"
    cat > "$TARGET/probe_target.sh" <<'FIX'
#!/bin/sh
verify_integrity() {
  scan=$(run_scan) || return 1     # 검사 실패 → 실패 반환 = fail-closed
  echo "$scan"
}
FIX
    ;;
  --target) TARGET="${2:?--target 은 경로가 필요하다}" ;;
  '')       TARGET="$REPO_ROOT/scripts" ;;
  *) echo "degrade-probe: 알 수 없는 모드 '$MODE'"; exit 10 ;;
esac

# 대상 존재 여부를 **먼저** 판정한다 — 원 스캐너의 exit 0 은 「대상 없음」과
# 「깨끗」을 같은 값으로 렌더한다. 그 둘을 여기서 가른다.
# `.md` joined the候補 set 2026-08-12. Until then this counted only `.sh|.py`, so a pure-markdown
# target exited 3 = NO_TARGET **without ever invoking the scanner** — which means the release's
# headline feature (scanning ```bash/```python fences inside SKILL.md) was unreachable through the
# typed capability path, the one a cockpit caller actually uses. A capability that cannot reach its
# own advertised surface is not a narrow bug; it is the feature not shipping on that path.
# 이 pre-count 자체가 `find` 에 의존한다 — 부재하면 0 이 나오고 그건 NO_TARGET 으로 렌더된다.
# 스캐너 본체는 같은 상황에서 INSTRUMENT ERROR(exit 2)를 내는데 wrapper 가 그걸 «대상 없음»으로
# 덮어써서 HARNESS_ERROR 판정이 도달 불가였다(cross-family, A급). 계기 부재는 대상 부재가 아니다.
command -v find >/dev/null 2>&1 || {
  echo "degrade-probe: HARNESS_ERROR — \`find\` 부재로 대상 열거 자체가 불가(대상 없음이 아니다)"; exit 10; }
# 계기가 **있어도** 이 타깃을 못 훑을 수 있다(권한 없는 디렉토리). 첫 수리는 `command -v` 만 봐서
# 그 경우가 여전히 NO_TARGET 으로 렌더됐다 — 절반만 닫은 수리다(cross-family 재지적, A급).
# 「대상이 없다」와 「대상을 못 셌다」는 다른 말이고, 후자는 HARNESS_ERROR 다.
_perr=$(find -H "$TARGET" -type f 2>&1 >/dev/null); _prc=$?
if [ "$_prc" -ne 0 ] || [ -n "$_perr" ]; then
  echo "degrade-probe: HARNESS_ERROR — 대상 열거 실패(대상 없음이 아니다): ${_perr:-find exited $_prc}"; exit 10
fi
n=$(find -H "$TARGET" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.md' \) 2>/dev/null | wc -l | tr -d ' ')
[ "${n:-0}" -eq 0 ] && { echo "degrade-probe: NO_TARGET — 스캔 대상 파일 0개(깨끗이 아니다)"; exit 3; }

out="$(bash "$SCAN" "$TARGET" 2>&1)"; rc=$?     # verdict 는 직접 취한다(PIPE-VERDICT)
case "$rc" in
  0) echo "degrade-probe: CLEAN (대상 $n)"; exit 0 ;;
  2)
    # rc=2 는 스캐너에서 **세 가지**를 뜻한다: 실제 findings · 못 잰 파일(UNMEASURED) ·
    # 스캔 대상 아님(UNSCANNABLE). 셋을 전부 FINDINGS 로 접으면 「못 쟀다」가 「결함을 찾았다」로
    # 렌더돼, 계기 고장이 대상의 결함으로 오귀속된다(반대 방향이지만 같은 계열의 오분류).
    # 순서가 판정이다 — «못 쟀다» 를 **먼저** 본다. findings 검사를 앞에 두면 「일부는 쟀고 일부는
    # 못 쟀다」가 그냥 FINDINGS 로 나가고, 미측정 표면이 판정에서 사라진다(cross-family 지적, A급).
    # `_md_collect` 의 「err 가 got 을 이긴다」와 같은 규율을 이 층에도 건다.
    if printf '%s' "$out" | grep -qi 'COULD NOT BE MEASURED'; then
      echo "degrade-probe: HARNESS_ERROR — 스캐너가 대상을 측정하지 못했다(깨끗이 아니다)"
      printf '%s\n' "$out" | head -4; exit 10
    elif printf '%s' "$out" | grep -qE '\[[A-Z][0-9]?:'; then
      echo "degrade-probe: FINDINGS (대상 $n)"; printf '%s\n' "$out" | head -6; exit 2
    else
      echo "degrade-probe: NO_TARGET — 대상 $n 개가 전부 스캔 대상 밖이다(깨끗이 아니다)"
      printf '%s\n' "$out" | head -4; exit 3
    fi ;;
  *) echo "degrade-probe: HARNESS_ERROR — 스캐너가 enum 밖 $rc 반환"; exit 10 ;;
esac
