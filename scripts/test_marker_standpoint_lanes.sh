#!/usr/bin/env bash
# test_marker_standpoint_lanes.sh — regression fixtures for pre-commit's
# validate_standpoint_leg (typed standpoint verdict, 2026-08-17).
#
# WHY: `standpoint:` shipped 2026-08-14 with its value DELIBERATELY unvalidated — the doctrine
# said "mechanize on the first recorded false value, not before". That value has now been
# recorded (three, in fact): a `release_2.3.0` marker wrote `not-applicable` on a delta whose own
# grounds line concedes "소비자 install 의 게이트 수용은 바뀐다 (BREAKING 2건)", and two
# 2026-08-14 deltas that altered shipped gate scripts / a shipped SKILL.md carried no line at all.
# The threshold the doctrine set for this field is met; this lane is that mechanization.
#
# SCOPE — channel, not judgment (CLAUDE.md §Mechanization Boundary). These lanes assert the
# RECORD's properties: present · single · a member of the closed enum · not vacuous · not wearing
# the OTHER axis's tokens. They never assert the value is CORRECT.
#
# 🟥 NAMED RESIDUAL — the execution claim is WARN, not BLOCK. `tier2`/`tier2b`/`tier3` assert that
# something was EXECUTED in the target, and the doctrine calls that "the load-bearing half". A
# blocking check for it needs a vocabulary grep, and on first contact with the real corpus that
# grep over-blocked a legitimate marker whose grounds read "그 레포에서 실제로 호출해 양·음 arm 을
# 확인했다" — it simply did not know 「호출」. Over-blocking trains `--no-verify`, which would
# disarm the Destructive-Op gate living in the same hook, so the check warns. The cost is stated
# rather than hidden: a fabricated `tier2` with a fluent reason PASSES this lane. That hole is
# what §4-b (cross-family reads the marker) is for — it is not closed here.
#
# Fixtures assert BOTH directions (known-pair): every intended shape is admitted, and every hole
# the lane closes still blocks. Asserting only BLOCK cannot tell "blocked" from "blocked for the
# wrong reason"; asserting only PASS cannot see a lane that admits everything.
#
# Usage: bash scripts/test_marker_standpoint_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

sed -n '/^validate_standpoint_leg()/,/^}/p' "$HOOK" > "$T/fn.sh"

# Instrument calibration — an empty extraction would let every fixture "pass" against nothing.
if ! grep -q 'DEGRADED_NO_TARGET_ACCESS' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — validate_standpoint_leg did not extract from $HOOK."
  echo "   Fixtures below would measure an empty function. Aborting rather than reporting green."
  exit 1
fi

FAIL=0
lane() { # $1 = id  $2 = expect(BLOCK|PASS)  $3 = marker body
  local id="$1" expect="$2" body="$3" rc out
  printf '%s\n' "$body" > "$T/m.marker"
  out=$( bash -c 'set -uo pipefail; . "$1"; validate_standpoint_leg "$2"' _ "$T/fn.sh" "$T/m.marker" 2>&1 ); rc=$?
  local got=PASS; [ $rc -ne 0 ] && got=BLOCK
  if [ "$got" = "$expect" ]; then
    printf '  ✅ %-34s %s\n' "$id" "$got"
  else
    printf '  ❌ %-34s expected %s, got %s\n     %s\n' "$id" "$expect" "$got" "$(printf '%s' "$out" | head -2)"
    FAIL=1
  fi
}

echo "== standpoint lanes — BLOCK side (holes that must stay closed) =="
lane S1-missing        BLOCK 'axis2-model: opus'
lane S2-duplicate      BLOCK 'standpoint: tier1
standpoint: not-applicable — 나중에 고침'
lane S3-bare-na        BLOCK 'standpoint: not-applicable'
lane S4-unknown-value  BLOCK 'standpoint: tier9(qasp) — 새 등급을 지어냈다'
lane S5-crossfamily    BLOCK 'standpoint: DEGRADED_SINGLE_FAMILY — codex 안 붙었다'
lane S6-panel-token    BLOCK 'standpoint: panel(codex) — 축을 헷갈렸다'
lane S7-ungrounded-unk BLOCK 'standpoint: UNKNOWN'
lane S8-ungrounded-deg BLOCK 'standpoint: DEGRADED_NOT_RUN — 안 했음'

echo "== standpoint lanes — PASS side (legitimate shapes must not over-block) =="
lane N1-tier1          PASS  'standpoint: tier1'
lane N2-na-grounded    PASS  'standpoint: not-applicable — FH 내부 문서이고 출하 표면·peer 계약을 안 건드린다(확인함)'
lane N3-tier1b         PASS  'standpoint: tier1b(pmh-dev) — pmh-dev 정본 사본 직독 + 마커 42건 grep, 재분류 대상 0'
lane N4-tier2-exec     PASS  'standpoint: tier2(qasp-dev) — 그 레포에서 스위트 실행, rc=0 / 3176 passed 출력 확인'
lane N5-deg-grounded   PASS  'standpoint: DEGRADED_NOT_RUN — 표적 접근 가능했으나 안 돌렸다, 다음 라운드 이월'
lane N6-deg-targets    PASS  'standpoint: DEGRADED_NOT_RUN(qasp-dev · pmh-dev) — 전파 자산이라 해당되나 대상 레포에서 아무것도 실행 안 했다'
lane N7-quoted-value   PASS  'standpoint: "tier2(pmh-dev) — 그 레포 로컬 클론에서 실제로 실행, 양·음 arm 확인"'

echo "== WARN side — recorded, not blocking (the named residual above) =="
lane N8-tier2-vague    PASS  'standpoint: tier2(pmh-dev) — 그쪽 레포 기준으로 판단했다'

[ $FAIL -eq 0 ] && { echo "✅ all standpoint lanes behave"; exit 0; }
echo "❌ standpoint lane regression"; exit 1
