#!/usr/bin/env bash
# test_marker_thirdparty_lanes.sh — regression fixtures for pre-commit's validate_thirdparty_leg.
#
# WHY: `thirdparty:` shipped 2026-08-17 with presence checked and the VALUE unvalidated. Within the
# same day the author wrote it wrong TWICE — free prose about peer-session contact — while a peer
# session used the enum correctly 4/4. ⓓ3자대면 is confronting third-party PRIOR ART (does this
# claimed-new thing already exist outside the repo), not "I talked to another session". Nothing
# caught the substitution because nothing read the value.
#
# 🟥 THE AXIS HAS TWO HALVES and the field originally encoded only one — ① prior art
# (checked/none-found) and ② harness-level adversarial review (peer-review): put a model in a THIRD
# harness, wearing that harness's persona, and have it review the target's change. FH is the
# governor — it creates the situation, observes, judges; the 4-axis gate verifies the OPINION that
# came back, locally. Because ② had no value, records that meant ② leaked into free prose. That is
# the very defect this field was created to fix, recurring one level in.
#
# SCOPE — channel, not judgment. These lanes assert the record is an enum member with non-vacuous
# grounds. They never assert the search was thorough, and never assert that what a third party
# said is TRUE: the axis exists to surface information you could not predict, and adjudicating what
# comes back belongs to the other axes. That separation is the point of the 4-axis gate.
#
# Fixtures assert BOTH directions. The real corpus supplied both arms on its own — that is unusual
# and worth stating: peer-authored markers were the known-negatives, the author's own malformed
# ones were the known-positives.
#
# Usage: bash scripts/test_marker_thirdparty_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
sed -n '/^validate_thirdparty_leg()/,/^}/p' "$HOOK" > "$T/fn.sh"
if ! grep -q 'DEGRADED_NO_ACCESS' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — validate_thirdparty_leg did not extract from $HOOK."
  echo "   Fixtures below would measure an empty function. Aborting rather than reporting green."
  exit 1
fi
FAIL=0
lane() { # $1=id $2=expect $3=body
  local rc out got
  printf '%s\n' "$3" > "$T/m.marker"
  out=$( bash -c 'set -uo pipefail; . "$1"; validate_thirdparty_leg "$2"' _ "$T/fn.sh" "$T/m.marker" 2>&1 ); rc=$?
  got=PASS; [ $rc -ne 0 ] && got=BLOCK
  if [ "$got" = "$2" ]; then printf '  ✅ %-32s %s\n' "$1" "$got"
  else printf '  ❌ %-32s expected %s, got %s\n     %s\n' "$1" "$2" "$got" "$(printf '%s' "$out"|head -1)"; FAIL=1; fi
}

echo "== BLOCK side =="
lane T1-wrong-axis-semantics  BLOCK 'thirdparty: 병렬 챔버 세션과 실교신 — 상호 정정 3건'
lane T2-bare-checked          BLOCK 'thirdparty: checked'
lane T3-vacuous-grounds       BLOCK 'thirdparty: none-found(없음)'
lane T4-standpoint-token      BLOCK 'thirdparty: tier1b(pmh-dev) — 축을 헷갈렸다'
lane T5-crossfamily-token     BLOCK 'thirdparty: panel(codex) — 축을 헷갈렸다'
lane T6-not-in-enum           BLOCK 'thirdparty: yes'
lane T7-duplicate             BLOCK 'thirdparty: UNKNOWN
thirdparty: none-found(나중에 고침)'

echo "== PASS side =="
lane N1-unknown-bare          PASS  'thirdparty: UNKNOWN'
lane N2-checked-grounded      PASS  'thirdparty: checked(promptfoo·DeepEval·garak 훑음 — 겹치는 선행 없음)'
lane N3-none-found            PASS  'thirdparty: none-found(「등록 시점 검사기를 호출 시점에 배선」 조합의 외부 선행)'
lane N4-degraded-not-run      PASS  'thirdparty: DEGRADED_NOT_RUN(외부 선행 미조사 — 필드 설계가 먼저였다)'
lane N5-not-applicable        PASS  'thirdparty: not-applicable(이 저장소 고유 taxonomy 의 내부 규정 변경)'
lane N6-multiline-parenthetical PASS 'thirdparty: none-found(「정체성 승급 기준의 residency-제약 하 측정」이라는
  조합으로 외부 선행을 찾았고 겹치는 것이 없었다)'
# ② 하네스 단위 적대검증 — 이 축의 «다른 반쪽». 규격에 값이 없어서 산문으로 새던 자리다.
lane N8-peer-review           PASS  'thirdparty: peer-review(gstack/harness-persona → qasp, 경계 가정 2건을 그쪽 입장에서 반증)'
lane N9-peer-review-degraded  PASS  'thirdparty: DEGRADED_NO_ACCESS(gstack 로컬 클론 없음 — 제3 하네스 페르소나를 세울 수 없었다)'
lane T8-peer-review-vacuous   BLOCK 'thirdparty: peer-review(했음)'
lane N7-absent                PASS  'axis2-model: opus'

[ $FAIL -eq 0 ] && { echo "✅ all thirdparty lanes behave"; exit 0; }
echo "❌ thirdparty lane regression"; exit 1
