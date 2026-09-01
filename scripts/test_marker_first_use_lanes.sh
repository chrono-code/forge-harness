#!/usr/bin/env bash
# test_marker_first_use_lanes.sh — regression fixtures for pre-commit's
# `validate_first_use_leg` (ⓔ 첫 실사용, 2026-08-29).
#
# tenet: FH-T06 (실행이 하중 지는 절반) · FH-T02 (기록의 속성만 단언)
#
# WHY THIS LANE EXISTS. Measured 2026-08-31 by `soul_trace.sh` backward + a delete-and-observe
# probe: neutralising `validate_first_use_leg` to `return 0` left **all nine** marker lanes green.
# The leg is CALLED (pre-commit:2028) — so it is not dead code — but it had **zero mechanical
# coverage**. That is a different thing from an orphan and there is no enum value for it; rather
# than invent one, the coverage was built. ([[feedback_built_but_not_wired]] 의 반대 얼굴:
# 배선은 됐는데 **재는 것이 없다**.)
#
# 🟥 FIXTURES ARE NOT SPELLED THE EASY WAY. The leg reads `git diff --cached`, so a fixture that
# merely calls the function proves nothing — each case stages real files in a real throwaway repo.
# And the ⓔ-value cases deliberately include the awkward spellings (leading space, absent ⓕ,
# duplicate axes-run line), because an anchor that picks the operation's easiest spelling cannot
# see the defect's other spellings ([[feedback_fixture_must_use_the_breaking_spelling]]).
#
# Usage: bash scripts/test_marker_first_use_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # 픽스처는 실레포에 쓰지 않는다
# Script-relative, NOT `git rev-parse --show-toplevel` — same reason as the sibling marker lanes
# (a vendored/nested checkout answers with the OUTER repo's root).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T="$(fh_fixture_root "$(mktemp -d)")"
: "${T:?fixture root unset — refusing to run git in cwd}"
trap 'rm -rf "$T"' EXIT

# 🟥 픽스처 루트 가드는 **공용 lib** 이 진다 — 초판은 여기 인라인 사본이었고, 그때 스스로
#    「공용 함수가 배선되면 이 사본은 지우고 그걸 불러라」고 적었다. 지금이 그때다
#    ([[feedback_divergent_leniency_duplicate_normalizers]]: 관대함 갈린 중복은 무음 드롭을 만든다).

sed -n '/^validate_first_use_leg()/,/^}/p' "$HOOK" > "$T/fn.sh"
# 계기 캘리브레이션 — 빈 추출이면 모든 픽스처가 «아무것도 아닌 것»을 상대로 통과한다.
if ! grep -q 'diff-filter=A' "$T/fn.sh" || ! grep -q 'axes-run' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — validate_first_use_leg did not extract from $HOOK."
  exit 1
fi

R="$T/repo"; mkdir -p "$R/scripts"
git -C "$R" -c init.defaultBranch=main init -q
git -C "$R" config user.email lane@example.invalid
git -C "$R" config user.name lane
printf 'seed\n' > "$R/seed.txt"
git -C "$R" add seed.txt
git -C "$R" -c core.hooksPath=/nonexistent-fixture-hooks commit -qm seed
SEED=$(git -C "$R" rev-parse HEAD)

FAIL=0; N=0
# 🟥 케이스 간 격리 — 초판은 `reset -q` + 파일 삭제만 했다. A3 컨트롤이 픽스처 레포에 **커밋을
#    남기자** 이후 모든 케이스에서 같은 파일이 `--diff-filter=A` 가 아니게 되어, 훅이 멀쩡한데
#    레인이 «B1~B9 전부 fail-open» 이라는 **거짓 판정**을 냈다. 상태를 나르는 픽스처는 자기
#    앞 케이스를 재는 것이지 대상을 재는 것이 아니다([[feedback_broken_parser_reports_a_verdict]]).
#    ⇒ 매 케이스마다 씨앗 커밋으로 **완전 복귀**한다.
stage_reset() {
  git -C "$R" reset -q --hard "$SEED" >/dev/null 2>&1
  git -C "$R" clean -qfd >/dev/null 2>&1
  mkdir -p "$R/scripts"
}
run() { bash -c "cd '$R'; source '$T/fn.sh'; validate_first_use_leg '$T/marker'" >/dev/null 2>&1; }
check() { # $1=label $2=expected(PASS|BLOCK) $3=staged-setup $4=marker body
  N=$((N+1)); stage_reset; eval "$3"; printf '%b' "$4" > "$T/marker"
  if run; then got=PASS; else got=BLOCK; fi
  if [ "$got" = "$2" ]; then printf '✅ %-54s → %s\n' "$1" "$got"
  else printf '❌ %-54s → %s (expected %s)\n' "$1" "$got" "$2"; FAIL=1; fi
}

NEWCHK='printf "#\n" > "$R/scripts/new_check.sh"; git -C "$R" add scripts/new_check.sh'
AXR() { printf 'axes-run: ⓐ=계열 %s ⓕ=되돌림\n' "$1"; }

echo "── ① 발화 차원: 이 커밋이 «새 계기»를 추가하는가 ──"
check "A1 새 *_check.sh 추가 + ⓔ=none → 걸린다" BLOCK "$NEWCHK" "$(AXR 'ⓔ=none')"
check "A2 새 lane_*.py 추가 + ⓔ=none → 걸린다"  BLOCK \
      'printf "#\n" > "$R/scripts/lane_bar.py"; git -C "$R" add scripts/lane_bar.py' "$(AXR 'ⓔ=none')"
# 컨트롤 — 이 셋이 PASS 여야 «전부 막는 레인»이 아님이 보인다.
check "A3 기존 계기의 «수정» 은 대상 아님 (컨트롤)"  PASS \
      'printf "#\n" > "$R/scripts/new_check.sh"; git -C "$R" add scripts/new_check.sh;
       git -C "$R" -c core.hooksPath=/nonexistent-fixture-hooks commit -qm add;
       printf "#v2\n" > "$R/scripts/new_check.sh"; git -C "$R" add scripts/new_check.sh' "$(AXR 'ⓔ=none')"
check "A4 새 파일이나 계기 패턴 불일치 (컨트롤)"    PASS \
      'printf "#\n" > "$R/scripts/foo_lanes.sh"; git -C "$R" add scripts/foo_lanes.sh' "$(AXR 'ⓔ=none')"
check "A5 스테이징 자체가 없다 (컨트롤)"           PASS ':' "$(AXR 'ⓔ=none')"

echo "── ② ⓔ 값 차원 (발화 조건 고정) ──"
check "B1 ⓔ=none"                                BLOCK "$NEWCHK" "$(AXR 'ⓔ=none')"
check "B2 ⓔ=none(<근거>) 는 통과 (컨트롤)"        PASS  "$NEWCHK" "$(AXR 'ⓔ=none(대상 없이 성립하는 계기)')"
check "B3 ⓔ=<실물 서술> 는 통과 (컨트롤)"          PASS  "$NEWCHK" "$(AXR 'ⓔ=qasp 에 돌려 3건 적발')"
check "B4 axes-run 줄 부재는 이 다리 소관 아님"     PASS  "$NEWCHK" '①영혼: 성공 정의\n'
check "B6 ⓔ=NONE 대문자도 걸린다"                 BLOCK "$NEWCHK" "$(AXR 'ⓔ=NONE')"
check "B7 ⓔ=- 도 걸린다"                          BLOCK "$NEWCHK" "$(AXR 'ⓔ=-')"
check "B8 ⓕ 부재 — 추출이 줄끝까지 흡수해도 걸린다" BLOCK "$NEWCHK" 'axes-run: ⓐ=계열 ⓔ=none\n'
check "B9 axes-run 이 두 줄이면 첫 줄로 판정한다"   BLOCK "$NEWCHK" \
      'axes-run: ⓐ=계열 ⓔ=none ⓕ=되돌림\naxes-run: ⓐ=계열 ⓔ=실행함 ⓕ=되돌림\n'

# 🟥 B10 — cross-family(codex/gpt-5.5)가 지목했고 실행으로 재현했다. **자력 적발 0.**
#    `.*ⓔ=` 의 `.*` 가 탐욕적이라 **줄의 마지막 `ⓔ=`** 를 잡는다. 그래서 앞에 `ⓔ=none` 을 적어
#    axes_run 의 존재 검사를 만족시켜 놓고, 줄 뒤에 `ⓔ=ran` 을 하나 더 붙이면 이 다리가 `ran` 을
#    읽고 통과시킨다. B9(두 «줄»)와 다른 축이다 — 이건 **한 줄 안의 중복 키**다.
#    🟥 그리고 B5(앞 공백)와도 성질이 다르다: B5 는 앞 검사가 먼저 막아서 end-to-end 로는
#    안 뚫렸고, B10 은 **끝까지 뚫렸다.** 실재하는 end-to-end fail-open 은 이쪽이다.
check "B10 한 줄 안에 ⓔ= 가 둘이면 걸린다 (탐욕 .*)" BLOCK "$NEWCHK" \
      'axes-run: ⓐ=계열 ⓔ=none ⓕ=되돌림 ⓔ=ran\n'
check "B10b 컨트롤 — ⓔ= 가 하나면 통과한다"          PASS  "$NEWCHK" \
      'axes-run: ⓐ=계열 ⓔ=qasp 에 돌려 3건 적발 ⓕ=되돌림\n'

echo "── ③ 🟥 뚫리는 표기 ──"
# 🟥 실측 2026-08-31: 이 픽스처는 **현재 PASS 한다 = fail-open**.
#    원인: `e_val` 추출이 `sed 's/[[:space:]]*$//'` 로 **뒤 공백만** 다듬고 앞 공백을 안 다듬어,
#    `ⓔ= none` 이 " none" 이 되어 case 의 `none` 과 안 맞는다. 마커 저자가 키=값 사이에 공백
#    하나를 넣는 것은 흔한 표기이고, 그 한 칸이 게이트를 통째로 무음화한다.
#    처방(훅, 1줄): `| sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
#    🟥 의도된 동작(BLOCK)을 단언한다 — 결함을 «기대값»으로 적어 초록을 만드는 것은
#    수리가 아니라 은폐다([[feedback_deletion_beats_repair_dead_filter]] 와 같은 성질).
check "B5 ⓔ= none (앞 공백 한 칸) 도 걸려야 한다"  BLOCK "$NEWCHK" "$(AXR 'ⓔ= none')"

echo
if [ "$FAIL" -eq 0 ]; then echo "FIRST-USE LANES: PASS ($N fixtures)"; else echo "FIRST-USE LANES: FAIL ($N fixtures)"; fi
exit $FAIL
