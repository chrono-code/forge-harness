#!/usr/bin/env bash
# test_marker_affected_lanes.sh — regression fixtures for pre-commit's
# validate_affected_leg (2026-09-04, frontier absorption of Anthropic AI-Native SDLC
# playbook intent.md's "Affected users and systems" / "Open questions" columns).
#
# WHY: FH does not split the two source columns into two marker fields — a second field is
# a second empty slot, the exact shape soul-check:/tenets:/thirdparty: already avoid. One
# free-prose line carries both, by convention ("건드리는 것 · 열린 질문 = …").
#
# SCOPE — channel, not judgment: single line · no duplicate · non-vacuous · not a bare
# placeholder. Unlike defeater:, "없음" is NOT a legal declared-absence here — every change
# touches something, so a placeholder-only value is an unfilled field, not an honest record
# of nothing. Absent (no `affected:` line at all) is legal — adoption is incremental, same
# shape as soul-check:/tenets:.
#
# Fixtures assert BOTH directions (known-pair): every intended shape is admitted, and every
# hole this lane closes still blocks.
#
# Usage: bash scripts/test_marker_affected_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# 헬퍼도 같이 추출한다 — 안 하면 다리가 fail-open 이 되고 레인이 거짓 PASS 를 낸다
# (defeater/soul-check 가 이미 겪은 형태: [[feedback_broken_parser_reports_a_verdict]]).
sed -n '/^marker_recreate_hint()/,/^}/p'     "$HOOK" >  "$T/_helpers.sh"
sed -n '/^_marker_template_residue()/,/^}/p' "$HOOK" >> "$T/_helpers.sh"
sed -n '/^validate_affected_leg()/,/^}/p'    "$HOOK" >  "$T/fn0.sh"
cat "$T/_helpers.sh" "$T/fn0.sh" > "$T/fn.sh"

# Instrument calibration — an empty extraction would let every fixture "pass" against nothing.
if ! grep -q 'validate_affected_leg' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — validate_affected_leg did not extract from $HOOK."
  echo "   Fixtures below would measure an empty function. Aborting rather than reporting green."
  exit 1
fi
grep -q '^_marker_template_residue()' "$T/fn.sh" || { echo "❌ HARNESS-ERROR — 헬퍼 미결합"; exit 1; }

FAIL=0
lane() { # $1 = id  $2 = expect(BLOCK|PASS)  $3 = marker body
  local id="$1" expect="$2" body="$3" rc out
  printf '%s\n' "$body" > "$T/m.marker"
  out=$( bash -c 'set -uo pipefail; . "$1"; validate_affected_leg "$2"' _ "$T/fn.sh" "$T/m.marker" 2>&1 ); rc=$?
  local got=PASS; [ $rc -ne 0 ] && got=BLOCK
  if [ "$got" = "$expect" ]; then
    printf '  ✅ %-40s %s\n' "$id" "$got"
  else
    printf '  ❌ %-40s expected %s, got %s\n     %s\n' "$id" "$expect" "$got" "$(printf '%s' "$out" | head -3)"
    FAIL=1
  fi
}

echo "== affected: lanes — PASS side (absent / genuinely filled) =="
lane P1-absent-is-legal        PASS  "axis2-model: opus
axes-run: ⓐ=codex"
lane P2-real-content           PASS  "affected: 소비자 install 의 pre-commit 사용자(마커 형식) · 열린 질문 = 필드 강제 시점"
lane P3-real-content-no-openq  PASS  "affected: the private companion store 미러 사용자 · 인덱스 재생성 스크립트가 이 필드를 안 읽는다"
lane P4-korean-multiword       PASS  "affected: 마커를 grep 으로 감사하는 하류 세션 전부 · 열린 질문 = 강제 시점을 정할 것인가"

echo "== affected: lanes — BLOCK side (holes that must stay closed) =="
lane G1-placeholder-none-ko    BLOCK "affected: 없음"
lane G2-placeholder-tbd        BLOCK "affected: TBD"
lane G3-placeholder-tbd-lower  BLOCK "affected: tbd"
lane G4-placeholder-dash       BLOCK "affected: -"
lane G5-placeholder-na         BLOCK "affected: n/a"
lane G6-empty-field            BLOCK "affected:"
lane G7-duplicate-line         BLOCK "affected: 소비자 install 사용자
affected: 정정 — 사실은 필드 하네스 사용자다"
lane G8-nearmiss-plural        BLOCK "affects: 소비자 install 사용자"
lane G9-nearmiss-space         BLOCK "affected : 소비자 install 사용자"
lane G10-nearmiss-typo         BLOCK "affeted: 소비자 install 사용자"
lane G11-too-short             BLOCK "affected: TBD 확인"
# 🟥 _marker_template_residue 는 힌트에서 파생한 자리표시자만 본다(v3, defeater 의 R1~R4 가
# 이미 겪은 형태). `affected:` 는 힌트에 아직 실려 있지 않아서 필드-고유 자리표시자는 못
# 잡는다 — 명명된 잔여(defeater 절 참고). 잡히는 것은 다른 필드와 **공유하는** `<...>` 뿐이다.
lane G13-shared-hint-placeholder BLOCK "affected: <...>"

echo
echo "== 실물 코퍼스 대조 (있으면) =="
# 실물 마커에 affected: 가 아직 없는 것이 정상이다 — 이 필드는 오늘 신설이다. 부재 마커도
# 여전히 PASS 여야 한다는 것을 실물로도 한 번 더 확인한다(계기가 실물 코퍼스에서도 안 죽는가).
_real="$REPO_ROOT/tracks/_meta/.axes_23_passed_fix_chamber-run-doctrine-vocabulary_2026-09-04.marker"
if [ -f "$_real" ]; then
  lane R1-real-corpus-marker-still-passes PASS "$(cat "$_real")"
else
  echo "  ⚠️  실물 마커 부재 — SKIPPED (아직 오늘자 the private companion store 미러가 없을 수 있다, 통과 아님)"
fi

echo
if [ $FAIL -eq 0 ]; then echo "AFFECTED LANES: PASS"; else echo "AFFECTED LANES: FAIL"; fi
exit $FAIL
