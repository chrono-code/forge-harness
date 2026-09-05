#!/usr/bin/env bash
# test_marker_oracle_lanes.sh — regression fixtures for pre-commit's validate_oracle_leg
# (2026-09-05, ISO/IEC TR 29119-11 alignment — iso_ai_standards_crosswalk.md §4 M1, operator-approved).
#
# WHY: the test-oracle problem is the core of TR 29119-11 — «when no expected result exists, what
# did you decide against?». FH already carries the mechanism (known-pair controls, scorer fixed before
# results, «not found ≠ 0») but the marker recorded only «controls alive», never WHICH KIND of oracle.
# `oracle: <kind> — <grounds>` is that record. Closed enum of six:
#   known-pair · metamorphic · back-to-back · a-b (A/B accepted) · human · none (reason REQUIRED).
#
# SCOPE — channel, not judgment: enum membership · the kind must be followed by a delimiter or end
# of line (an enum member as a mere PREFIX — `known-pair2`, `human_review` — is not a member) ·
# non-vacuous grounds (≥2 words, no placeholder) · `none` must carry its reason · single line ·
# near-miss keys block by ONE rule: any line whose key starts with `oracle` but is not exactly
# `oracle:` (`Oracle:` `oracles:` `oracle :` `oracle　:` `oracle_type:` `oracle-type:` bare `oracle`)
# plus the typos `orcale:` `oralce:` `오라클:` — and they block EVEN WHEN a correct `oracle:` line is
# also present (a shadowed correction is the quietest failure). The hook never judges whether the
# named oracle was actually used. Absent = pass — adoption is incremental, same shape as
# affected:/soul-check:/tenets:.
#
# Fixtures assert BOTH directions (known-pair): every intended shape is admitted, and every hole
# this lane closes still blocks. Indentation is exercised on BOTH sides (o6 pass / o19 block) so a
# leading-space line can neither be skipped nor bypass validation. Where two holes would produce the
# same BLOCK, the lane also asserts the specific diagnostic (4th arg) so each branch is covered
# uniquely (cross-family codex #7). o31 runs the leg WITHOUT its helper and expects HARNESS-ERROR,
# so a fail-open on helper absence cannot hide behind a green suite.
#
# Usage: bash scripts/test_marker_oracle_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# 헬퍼도 같이 추출한다 — 안 하면 다리가 fail-open 이 되고 레인이 거짓 PASS 를 낸다
# ([[feedback_broken_parser_reports_a_verdict]] — defeater/soul-check/affected 가 이미 겪은 형태).
sed -n '/^marker_recreate_hint()/,/^}/p'     "$HOOK" >  "$T/_helpers.sh"
sed -n '/^_marker_template_residue()/,/^}/p' "$HOOK" >> "$T/_helpers.sh"
sed -n '/^validate_oracle_leg()/,/^}/p'      "$HOOK" >  "$T/fn0.sh"
cat "$T/_helpers.sh" "$T/fn0.sh" > "$T/fn.sh"

# Instrument calibration — an empty extraction would let every fixture "pass" against nothing.
if ! grep -q 'validate_oracle_leg' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — validate_oracle_leg did not extract from $HOOK."
  echo "   Fixtures below would measure an empty function. Aborting rather than reporting green."
  exit 1
fi
grep -q '^_marker_template_residue()' "$T/fn.sh" || { echo "❌ HARNESS-ERROR — 헬퍼 미결합"; exit 1; }

FAIL=0
lane() { # $1 = id  $2 = expect(BLOCK|PASS)  $3 = marker body  [$4 = diagnostic substring that must appear]
  local id="$1" expect="$2" body="$3" needle="${4:-}" rc out
  printf '%s\n' "$body" > "$T/m.marker"
  out=$( bash -c 'set -uo pipefail; . "$1"; validate_oracle_leg "$2"' _ "$T/fn.sh" "$T/m.marker" 2>&1 ); rc=$?
  local got=PASS; [ $rc -ne 0 ] && got=BLOCK
  if [ "$got" != "$expect" ]; then
    printf '  ❌ %-40s expected %s, got %s\n     %s\n' "$id" "$expect" "$got" "$(printf '%s' "$out" | head -3)"
    FAIL=1; return
  fi
  if [ -n "$needle" ] && ! printf '%s' "$out" | grep -qF -- "$needle"; then
    printf '  ❌ %-40s %s but the diagnostic «%s» is missing — a different branch fired\n     %s\n' "$id" "$got" "$needle" "$(printf '%s' "$out" | head -2)"
    FAIL=1; return
  fi
  printf '  ✅ %-40s %s\n' "$id" "$got"
}

echo "== oracle: lanes — PASS side (absent / every enum member / delimiter variants) =="
lane o1-absent-is-legal            PASS  "axis2-model: opus
axes-run: ⓐ=codex"
lane o2-known-pair-emdash          PASS  "oracle: known-pair — 레인 PASS/BLOCK 픽스처 양쪽 + W6 되돌림"
lane o3-ab-slash-alias             PASS  "oracle: A/B — ARM/CTRL 한 변수 reps=3"
lane o3b-ab-hyphen                 PASS  "oracle: a-b — ARM/CTRL 한 변수 reps=3"
lane o4-none-with-reason           PASS  "oracle: none — 문서만 변경, 측정 없음"
lane o5-human-paren-form           PASS  "oracle: human(운영자 눈검증 2건)"
lane o6-indented-valid-still-pass  PASS  "   oracle: metamorphic — 입력 변환 관계 (ARM 어형 → CTRL 어형)"
lane o7-mixed-case-kind            PASS  "oracle: Known-Pair — 양성 음성 컨트롤 동반"
lane o7b-back-to-back-no-space     PASS  "oracle: back-to-back—codex 가 같은 diff 를 읽음"
lane o32-colon-delimiter           PASS  "oracle: known-pair: 컨트롤 동반 실행"
lane o33-middle-dot-delimiter      PASS  "oracle: a-b · ARM/CTRL reps=3"
lane o34-value-mention-not-a-key   PASS  "affected: oracle 채널 사용자 · 열린 질문 = 없음
oracle: human — 운영자 눈검증 2건"
lane o35-period-delimiter          PASS  "oracle: known-pair. 컨트롤 동반 실행 양쪽"

echo "== oracle: lanes — BLOCK side (holes that must stay closed; 4th arg = the branch that must fire) =="
lane o8-enum-outside               BLOCK "oracle: pseudo — 3-way 대조" 'enum 밖'
lane o9-none-without-reason        BLOCK "oracle: none" '사유가 필수'
lane o10-none-placeholder-reason   BLOCK "oracle: none — TBD" '사유가 필수'
lane o11-empty-value               BLOCK "oracle:" '비어 있다'
lane o12-duplicate-line            BLOCK "oracle: known-pair — 컨트롤 동반 실행
oracle: human — 정정, 사실은 눈검증" '둘 이상'
lane o13-nearmiss-qasp-field-name  BLOCK "oracle_type: known-pair — 컨트롤 동반 실행" "정확히 'oracle:'"
lane o14-nearmiss-capital-key      BLOCK "Oracle: known-pair — 컨트롤 동반 실행" "정확히 'oracle:'"
lane o15-nearmiss-space-colon      BLOCK "oracle : known-pair — 컨트롤 동반 실행" "정확히 'oracle:'"
lane o16-kind-only-no-grounds      BLOCK "oracle: known-pair" '자리표시자뿐'
lane o17-one-word-grounds          BLOCK "oracle: human — 운영자" '공허하다'
lane o18-shared-hint-placeholder   BLOCK "oracle: known-pair — <...>" '힌트의 자리표시자'
lane o19-indented-invalid-blocks   BLOCK "   oracle: pseudo — 3-way 대조 두 낱말" 'enum 밖'
lane o20-placeholder-grounds       BLOCK "oracle: metamorphic — n/a" '자리표시자뿐'
# ── cross-family (codex, 2026-09-05) 가 연 구멍들 — 각각 fail-before 를 실측한 뒤 닫았다 ──
lane o21-enum-prefix-junk          BLOCK "oracle: known-pair2 positive negative controls" '구분자 없이'
lane o22-underscore-after-kind     BLOCK "oracle: human_review by Alice" '구분자 없이'
lane o23-case-variant-beside-exact BLOCK "oracle: known-pair — positive negative controls
Oracle: human — later correction" "정확히 'oracle:'"
lane o24-fullwidth-space-colon     BLOCK "oracle　: known-pair — 컨트롤 동반 실행" "정확히 'oracle:'"
lane o25-nearmiss-plural           BLOCK "oracles: known-pair — 컨트롤 동반 실행" "정확히 'oracle:'"
lane o26-nearmiss-typo-orcale      BLOCK "orcale: known-pair — 컨트롤 동반 실행" "정확히 'oracle:'"
lane o27-nearmiss-typo-oralce      BLOCK "oralce: known-pair — 컨트롤 동반 실행" "정확히 'oracle:'"
lane o28-nearmiss-korean-key       BLOCK "오라클: known-pair — 컨트롤 동반 실행" "정확히 'oracle:'"
lane o29-nearmiss-hyphen-type      BLOCK "oracle-type: known-pair — 컨트롤 동반 실행" "정확히 'oracle:'"
lane o30-bare-key-no-colon         BLOCK "oracle" "정확히 'oracle:'"
lane o36-unlisted-oracle-star-key  BLOCK "oracle.evidence: positive negative controls" "정확히 'oracle:'"

# o31 — 헬퍼 없이 함수만 격리 실행하면 «통과»가 아니라 HARNESS-ERROR 여야 한다(fail-open 방지 가지).
printf '%s\n' "oracle: known-pair — 컨트롤 동반 실행 양쪽" > "$T/m31.marker"
_o31=$( bash -c 'set -uo pipefail; . "$1"; validate_oracle_leg "$2"' _ "$T/fn0.sh" "$T/m31.marker" 2>&1 ); _rc31=$?
if [ $_rc31 -ne 0 ] && printf '%s' "$_o31" | grep -qF 'HARNESS-ERROR'; then
  printf '  ✅ %-40s BLOCK (HARNESS-ERROR, not a silent pass)\n' o31-helper-absent-is-not-pass
else
  printf '  ❌ %-40s expected HARNESS-ERROR without the helper, got rc=%s: %s\n' o31-helper-absent-is-not-pass "$_rc31" "$(printf '%s' "$_o31" | head -1)"
  FAIL=1
fi

echo
echo "== 실물 코퍼스 대조 (있으면) =="
# 실물 마커에 oracle: 가 아직 없는 것이 정상이다 — 이 필드는 오늘 신설이다. 부재 마커도 여전히
# PASS 여야 한다는 것을 실물로도 한 번 더 확인한다(계기가 실물 코퍼스에서도 안 죽는가).
_real=$(ls -t "$REPO_ROOT"/tracks/_meta/.axes_23_passed_*.marker 2>/dev/null | head -1)
if [ -n "$_real" ] && [ -f "$_real" ]; then
  lane "R1-real-corpus-$(basename "$_real" | cut -c1-24)" PASS "$(cat "$_real")"
else
  echo "  ⚠️  실물 마커 부재 — SKIPPED (gitignored tracks/ 가 없는 체크아웃일 수 있다, 통과 아님)"
fi

echo
if [ $FAIL -eq 0 ]; then echo "ORACLE LANES: PASS"; else echo "ORACLE LANES: FAIL"; fi
exit $FAIL
