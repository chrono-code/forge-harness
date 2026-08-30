#!/usr/bin/env bash
# test_marker_soul_tenet_lanes.sh — `validate_soul_tenet_refs` + `validate_defeater_leg` 회귀 픽스처.
# tenet: FH-T02 (기록의 속성만 단언) · FH-T01 (부재를 0으로 렌더하지 않는다)
#
# 🟥 이 스위트는 `sed` 로 함수만 추출해 격리 실행한다 — 즉 **«호출되는가»를 구조적으로 못 본다.**
#    그 축은 `scripts/test_hook_leg_wiring_lanes.sh` 가 실행 프로브로 따로 잰다. 둘은 서로를
#    대체하지 않는다([[feedback_built_but_not_wired]]).
#
# SCOPE — 기록의 속성: 존재 · 단일 · 비공허 · 참조 무결성 · 두 칸이 한 칸이 아님.
#         「그 값이 옳은가」는 어느 레인도 묻지 않는다.
#
# Usage: bash scripts/test_marker_soul_tenet_lanes.sh   Exit: 0 = all behave; 1 = regression
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
FAIL=0

# 🟥 «BLOCK 이면 통과» 는 계기 결함을 초록으로 렌더한다. 실측 2026-08-30: `set -u` unbound
# variable 로 죽은 실행을 이 러너가 BLOCK 으로 읽어 3개 레인이 «✅ BLOCK» 을 찍었다 — 그 셋은
# 검사를 돈 적이 없다([[feedback_broken_parser_reports_a_verdict]] · «막혔다»≠«옳게 막혔다»).
# 그래서 BLOCK 은 다리가 **자기 판정 문구**를 냈을 때만 BLOCK 이다.
verdict() { # $1 = rc, $2 = output  → PASS | BLOCK | HARNESS-ERROR
  if [ "$1" -eq 0 ]; then printf 'PASS'; return; fi
  case "$2" in *"❌ FAIL"*) printf 'BLOCK' ;; *) printf 'HARNESS-ERROR' ;; esac
}

sed -n '/^validate_soul_tenet_refs()/,/^}/p' "$HOOK" > "$T/fnt.sh"
sed -n '/^validate_defeater_leg()/,/^}/p'    "$HOOK" > "$T/fnd.sh"
# 🟥 헬퍼도 결합한다 — 안 하면 `_marker_template_residue` 미정의로 다리가 HARNESS-ERROR 를 낸다.
#    (2026-08-30: 그 가드를 fail-closed 로 만든 직후 이 스위트가 실제로 그렇게 짖었다.
#     종전이었다면 미정의 명령이 «잔여 없음»으로 조용히 통과했을 자리다.)
sed -n '/^_marker_template_residue()/,/^}/p' "$HOOK" > "$T/_helpers.sh"
cat "$T/_helpers.sh" "$T/fnd.sh" > "$T/fnd2.sh" && mv "$T/fnd2.sh" "$T/fnd.sh"
grep -q '^_marker_template_residue()' "$T/fnd.sh" || { echo "❌ HARNESS-ERROR — 헬퍼 미결합"; exit 1; }
# 계기 캘리브레이션 — 빈 추출은 모든 픽스처를 «아무것도 아닌 것»에 대고 통과시킨다.
grep -q 'SOUL_TENET_REGISTRY_REL' "$T/fnt.sh" || { echo "❌ HARNESS-ERROR — tenet leg 추출 실패"; exit 1; }
grep -q 'defeater' "$T/fnd.sh" || { echo "❌ HARNESS-ERROR — defeater leg 추출 실패"; exit 1; }
GRACE=$(grep -m1 '^DEFEATER_GRACE_DATE=' "$HOOK" | sed -E 's/.*"(.*)"/\1/')
[ -n "$GRACE" ] || { echo "❌ HARNESS-ERROR — DEFEATER_GRACE_DATE 를 못 읽었다"; exit 1; }

# 레지스트리는 **실물**을 쓴다 — 픽스처가 자기 레지스트리를 만들면 실제 등록부가 비어도 초록이다.
REG_REAL="$REPO_ROOT/.claude/soul_tenets.txt"
[ -f "$REG_REAL" ] || { echo "❌ HARNESS-ERROR — .claude/soul_tenets.txt 부재. 부재는 «전부 유효»가 아니다"; exit 1; }
REAL_ID=$(grep -m1 -oE '^FH-T[0-9]{2}' "$REG_REAL")
[ -n "$REAL_ID" ] || { echo "❌ HARNESS-ERROR — 실물 등록부에서 ID 를 하나도 못 뽑았다"; exit 1; }

tlane() { # $1=id $2=expect $3=body
  local id="$1" expect="$2" body="$3" rc out
  printf '%s\n' "$body" > "$T/m.marker"
  out=$( bash -c 'set -uo pipefail; REPO_ROOT="$3"; EVIDENCE_ROOT="$3"; . "$1"; validate_soul_tenet_refs "$2"' \
         _ "$T/fnt.sh" "$T/m.marker" "$REPO_ROOT" 2>&1 ); rc=$?
  local got; got=$(verdict "$rc" "$out")
  if [ "$got" = "$expect" ]; then printf '  ✅ %-38s %s\n' "$id" "$got"
  else printf '  ❌ %-38s expected %s, got %s\n     %s\n' "$id" "$expect" "$got" "$(printf '%s' "$out"|head -2)"; FAIL=1; fi
}

dlane() { # $1=id $2=expect $3=filename-date $4=body
  local id="$1" expect="$2" d="$3" body="$4" rc out f
  f="$T/.axes_23_passed_fix_x_${d}.marker"
  printf '%s\n' "$body" > "$f"
  out=$( bash -c 'set -uo pipefail; DEFEATER_GRACE_DATE="$3"; . "$1"; validate_defeater_leg "$2"' \
         _ "$T/fnd.sh" "$f" "$GRACE" 2>&1 ); rc=$?
  local got; got=$(verdict "$rc" "$out")
  if [ "$got" = "$expect" ]; then printf '  ✅ %-38s %s\n' "$id" "$got"
  else printf '  ❌ %-38s expected %s, got %s\n     %s\n' "$id" "$expect" "$got" "$(printf '%s' "$out"|head -2)"; FAIL=1; fi
}

SOUL='①영혼: 성공 정의 = «소비자 경로에서 완주해 rc=0 을 내고 컨트롤로 가른다». 절대 안 함 = «FAIL 을 SKIP 으로»'

echo "== ① tenet 참조 무결성 =="
tlane T1-no-citation-is-legal   PASS  "$SOUL"
tlane T2-real-id-passes         PASS  "$SOUL
tenets: $REAL_ID"
tlane T3-unregistered-id-blocks BLOCK "$SOUL
tenets: FH-T99"
tlane T4-mixed-one-bad-blocks   BLOCK "$SOUL
tenets: $REAL_ID, FH-T88"
tlane T5-id-anywhere-counts     PASS  "$SOUL — 근거는 $REAL_ID 다"
# 등록부 부재는 «전부 유효»가 아니다 (FH-T01). 인용이 있는데 등록부가 없으면 BLOCK.
_o=$( bash -c 'set -uo pipefail; REPO_ROOT="$3"; EVIDENCE_ROOT="$3"; . "$1"; validate_soul_tenet_refs "$2"' \
      _ "$T/fnt.sh" <(printf '%s\ntenets: FH-T01\n' "$SOUL") "$T/nowhere" 2>&1 ); _r=$?
if [ "$(verdict "$_r" "$_o")" = BLOCK ]; then printf '  ✅ %-38s BLOCK\n' "T6-missing-registry-blocks"
else printf '  ❌ %-38s expected BLOCK, got %s\n     %s\n' "T6-missing-registry-blocks" "$(verdict "$_r" "$_o")" "$(printf '%s' "$_o"|head -2)"; FAIL=1; fi

echo
echo "== ② defeater: (grace = $GRACE) =="
dlane D1-missing-post-grace-blocks BLOCK "$GRACE" "$SOUL"
dlane D2-missing-pre-grace-exempt  PASS  "2026-08-01" "$SOUL"
dlane D3-substantive-passes        PASS  "$GRACE" "$SOUL
defeater: 컨트롤 팔도 rc=0 이면 이 레인은 아무것도 안 가른 것이다"
dlane D4-vacuous-blocks            BLOCK "$GRACE" "$SOUL
defeater: 틀렸을 수도"
dlane D5-korean-onetoken-blocks    BLOCK "$GRACE" "$SOUL
defeater: 관측될것이있을것이다확인함"
dlane D6-declared-absent-ok        PASS  "$GRACE" "$SOUL
defeater: 없음"
dlane D7-duplicate-blocks          BLOCK "$GRACE" "$SOUL
defeater: 컨트롤 팔도 rc=0 이면 아무것도 안 가른 것이다
defeater: 없음"
dlane D8-nearmiss-key-blocks       BLOCK "2026-08-01" "$SOUL
defeaters: 컨트롤 팔도 rc=0 이면 아무것도 안 가른 것이다"
dlane D9-copy-of-soul-blocks       BLOCK "$GRACE" '①영혼: 성공 정의 = 소비자 경로에서 완주해 rc=0 을 낸다
defeater: 성공 정의 = 소비자 경로에서 완주해 rc=0 을 낸다'
# 날짜 없는 파일명은 «오래된 것»이 아니다 — grace 로 새면 fail-open 이다.
printf '%s\n' "$SOUL" > "$T/.axes_23_passed_nodate.marker"
_o=$( bash -c 'set -uo pipefail; DEFEATER_GRACE_DATE="$3"; . "$1"; validate_defeater_leg "$2"' \
      _ "$T/fnd.sh" "$T/.axes_23_passed_nodate.marker" "$GRACE" 2>&1 ); _r=$?
if [ "$(verdict "$_r" "$_o")" = BLOCK ]; then printf '  ✅ %-38s BLOCK\n' "D10-unparseable-date-not-exempt"
else printf '  ❌ %-38s expected BLOCK, got %s\n     %s\n' "D10-unparseable-date-not-exempt" "$(verdict "$_r" "$_o")" "$(printf '%s' "$_o"|head -2)"; FAIL=1; fi

# ── T8/T9 — 인용은 `tenets:` 필드에서만 읽는다 (2026-08-30, 게이트가 실물에서 잡았다) ──
#    🟥 초판은 마커 **전문**을 grep 해서, `controls:` 줄이 «known-negative 로 FH-T99 를 쓴다» 고
#    **계기를 설명한 것**을 «인용»으로 읽고 차단했다. 오늘 네 번째 같은 얼굴이다
#    (픽스처 토큰 3회 + 이번). «토큰을 설명하는 것»과 «쓰는 것»은 grep 에게 안 갈린다.
tlane T8-mention-outside-field-is-not-citation PASS "$SOUL
tenets: FH-T00
controls: known-negative 로 FH-T99 를 쓴다 — 등록부에 잡히면 HARNESS-ERROR
defeater: 이 검사가 틀렸다면 미등록 ID 가 조용히 통과하는 것이 관측된다"
# 🟥 컨트롤 — 필드 **안**의 미등록 ID 는 여전히 막혀야 한다. 이게 없으면 T8 은
#    «인용 검사를 통째로 껐다»와 구분되지 않는다([[feedback_control_presence_is_not_discrimination]]).
tlane T9-unregistered-INSIDE-field-still-blocks BLOCK "$SOUL
tenets: FH-T00 FH-T99
defeater: 이 검사가 틀렸다면 미등록 ID 가 조용히 통과하는 것이 관측된다"

echo
if [ $FAIL -eq 0 ]; then echo "SOUL TENET LANES: PASS"; else echo "SOUL TENET LANES: FAIL"; fi
exit $FAIL
