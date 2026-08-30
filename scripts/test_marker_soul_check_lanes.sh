#!/usr/bin/env bash
# test_marker_soul_check_lanes.sh — regression fixtures for pre-commit's
# validate_soul_check_leg
# (ⓒ 격리 그라운딩 — 사전 선언으로 확장, 2026-08-21).
#
# 🟥 NOT a seventh axis. `fh_three_layer_canon.md §1-a-2` splits axes by «무엇을 받았는가», and
# ⓒ already receives «저자가 쓴 문장 + 지금의 트리» — identical to this leg's input. Tense
# (사전 선언 vs 사후 주장) is a posture, not an axis.
#
# WHY: `①영혼` has been required on every marker since 2026-08-09 and is written 4/4 on the real
# corpus, with ZERO consuming code (measured with a control: `crossfamily` = 21 hits in the hook,
# `①영혼`/`soul` = 0 lines that read it; `fh_4axis_gate.md` does not name the field). Slot with no
# consumer → presence does the judging → always "done".
#
# SCOPE — channel, not judgment. These lanes assert the RECORD's properties: single · closed enum ·
# non-vacuous · not wearing another axis's tokens · consistent with the ①영혼 line in the SAME file.
# They never assert the read-back reached the right conclusion.
#
# 🟥 NAMED RESIDUAL — a fabricated `reflected(<fluent reason>)` on a marker that DOES carry an
# ①영혼 line PASSES. Provenance is not checkable from a file (the hook says so at the ①영혼
# comment, and that part is correct). The hole is §4-b's — cross-family reads the marker.
#
# Fixtures assert BOTH directions (known-pair): every intended shape is admitted, and every hole
# the lane closes still blocks.
#
# Usage: bash scripts/test_marker_soul_check_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# 🟥 헬퍼도 같이 추출한다 — 안 하면 다리가 fail-open 이 되고 레인이 거짓 PASS 를 낸다
#    (실측 2026-08-30: R1 이 BLOCK 기대에 PASS). 훅은 이제 헬퍼 부재를 HARNESS-ERROR 로 낸다.
# 🟥 v3 부터 `_marker_template_residue` 는 `marker_recreate_hint` 를 **부른다**(템플릿에서 파생).
#    헬퍼 하나만 뽑으면 미정의로 죽고, 그러면 이 검사는 SKIPPED 를 낸다(통과 아님).
sed -n '/^marker_recreate_hint()/,/^}/p'    "$HOOK" >  "$T/_helpers.sh"
sed -n '/^_marker_template_residue()/,/^}/p' "$HOOK" >> "$T/_helpers.sh"
sed -n '/^validate_soul_check_leg()/,/^}/p' "$HOOK" > "$T/fn.sh"

# Instrument calibration — an empty extraction would let every fixture "pass" against nothing.
if ! grep -q 'DEGRADED_NO_SOUL' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — validate_soul_check_leg did not extract from $HOOK."
  echo "   Fixtures below would measure an empty function. Aborting rather than reporting green."
  exit 1
fi

SOUL='①영혼: 성공 정의 = «소비자 경로에서 완주해 rc=0 을 내고 컨트롤로 가른다». 절대 안 함 = «FAIL 을 SKIP 으로 바꾸는 것»'

FAIL=0
lane() { # $1 = id  $2 = expect(BLOCK|PASS)  $3 = marker body
  local id="$1" expect="$2" body="$3" rc out
  printf '%s\n' "$body" > "$T/m.marker"
  out=$( bash -c 'set -uo pipefail; . "$1"; validate_soul_check_leg "$2"' _ "$T/fn.sh" "$T/m.marker" 2>&1 ); rc=$?
  local got=PASS; [ $rc -ne 0 ] && got=BLOCK
  if [ "$got" = "$expect" ]; then
    printf '  ✅ %-40s %s\n' "$id" "$got"
  else
    printf '  ❌ %-40s expected %s, got %s\n     %s\n' "$id" "$expect" "$got" "$(printf '%s' "$out" | head -3)"
    FAIL=1
  fi
}

echo "== soul-check lanes — BLOCK side (holes that must stay closed) =="
lane G1-not-in-enum          BLOCK "$SOUL
soul-check: done"
lane G2-bare-reflected       BLOCK "$SOUL
soul-check: reflected"
lane G3-vacuous-grounds      BLOCK "$SOUL
soul-check: reflected(ok)"
lane G4-duplicate-line       BLOCK "$SOUL
soul-check: UNKNOWN
soul-check: reflected(cross-family agy 가 델타를 성공정의에 비춰 2건 지적)"
lane G5-crossaxis-tier2      BLOCK "$SOUL
soul-check: tier2(qasp)"
lane G6-crossaxis-checked    BLOCK "$SOUL
soul-check: checked(prior art 없음)"
lane G7-crossaxis-panel      BLOCK "$SOUL
soul-check: panel(codex,agy)"
echo "  -- the consistency check (two fields, one record) --"
lane G8-reflected-no-soul    BLOCK "axis2-model: opus
soul-check: reflected(델타를 성공정의에 비춰 봤고 어긋남 없음)"
lane G9-reflected-empty-soul BLOCK "①영혼: 없음
soul-check: reflected(델타를 성공정의에 비춰 봤고 어긋남 없음)"
lane G10-violated-no-soul    BLOCK "axis2-model: opus
soul-check: violated(절대안함 을 어겼다 — SKIP 으로 바꿨다)"
lane G11-nosoul-but-soul-is  BLOCK "$SOUL
soul-check: DEGRADED_NO_SOUL(영혼 줄이 없어서 되비출 대상 자체가 없다)"
lane G11b-nosoul-but-soul-key BLOCK "soul: 성공 정의 = 소비자 경로에서 완주한다. 절대 안 함 = FAIL 을 SKIP 으로 바꾸지 않는다
soul-check: DEGRADED_NO_SOUL(영혼 줄이 없어서 되비출 대상 자체가 없다)"

echo "== soul-check lanes — PASS side (intended shapes must be admitted) =="
lane G12-absent-is-grace     PASS  "$SOUL
axis2-model: opus"
lane G13-reflected-ok        PASS  "$SOUL
soul-check: reflected(agy/gemini 가 델타를 성공정의에 비춰 재검 — 절대안함 위반 0, 성공정의 미달 0)"
lane G13b-reflected-soul-key PASS  "soul: 성공 정의 = 소비자 경로에서 완주한다. 절대 안 함 = FAIL 을 SKIP 으로 바꾸지 않는다
soul-check: reflected(codex 가 soul 필드를 성공정의에 비춰 재검 — 위반 0)"
lane G14-violated-is-legal   PASS  "$SOUL
soul-check: violated(절대안함 «FAIL 을 SKIP 으로» 를 어겼다 — 되돌리고 주체를 이름으로 찍게 고쳤다)"
lane G15-unknown-bare-ok     PASS  "$SOUL
soul-check: UNKNOWN"
lane G16-degraded-not-run    PASS  "$SOUL
soul-check: DEGRADED_NOT_RUN(되비출 사이드카가 없어 이번 커밋에선 안 돌렸다)"
lane G17-nosoul-when-truly   PASS  "axis2-model: opus
soul-check: DEGRADED_NO_SOUL(경량 예외 커밋이라 영혼 줄을 안 썼다)"
lane G18-not-applicable      PASS  "$SOUL
soul-check: not-applicable(문서 오타 수정이라 성공정의에 걸리는 델타가 없다)"
lane G19-em-dash-reason      PASS  "$SOUL
soul-check: reflected(codex 가 성공정의 대조 — 어긋남 없음) — 2026-08-21"


# ── ①영혼 presence lane (validate_soul_present_leg) ───────────────────────────
sed -n '/^validate_soul_present_leg()/,/^}/p' "$HOOK" > "$T/fnp.sh"
cat "$T/_helpers.sh" "$T/fnp.sh" > "$T/fnp2.sh" && mv "$T/fnp2.sh" "$T/fnp.sh"
cat "$T/_helpers.sh" "$T/fn.sh"  > "$T/fn2.sh"  && mv "$T/fn2.sh"  "$T/fn.sh"
# 🟥 계기 캘리브레이션 — 헬퍼가 실제로 붙었나. 안 붙으면 다리가 HARNESS-ERROR 를 내고
#    모든 레인이 BLOCK 으로 쏠려 «잘 막는다»처럼 보인다. 그건 판별력이 아니다.
grep -q '^_marker_template_residue()' "$T/fnp.sh" || { echo "❌ HARNESS-ERROR — 헬퍼 미결합"; exit 1; }
if ! grep -q 'SOUL_PRESENT_GRACE' "$T/fnp.sh" && ! grep -q '①영혼 line' "$T/fnp.sh"; then
  echo "❌ HARNESS-ERROR — validate_soul_present_leg did not extract. Aborting."
  exit 1
fi
GRACE=$(grep -m1 '^SOUL_PRESENT_GRACE_DATE=' "$HOOK" | sed -E 's/.*"(.*)"/\1/')

planep() { # $1=id $2=expect $3=filename-date $4=body
  local id="$1" expect="$2" d="$3" body="$4" rc out f
  f="$T/.axes_23_passed_fix_x_${d}.marker"
  printf '%s\n' "$body" > "$f"
  out=$( bash -c 'set -uo pipefail; SOUL_PRESENT_GRACE_DATE="$3"; . "$1"; validate_soul_present_leg "$2"' \
         _ "$T/fnp.sh" "$f" "$GRACE" 2>&1 ); rc=$?
  local got=PASS; [ $rc -ne 0 ] && got=BLOCK
  if [ "$got" = "$expect" ]; then printf '  ✅ %-40s %s\n' "$id" "$got"
  else printf '  ❌ %-40s expected %s, got %s\n     %s\n' "$id" "$expect" "$got" "$(printf '%s' "$out"|head -2)"; FAIL=1; fi
}

echo
echo "== ①영혼 presence lanes (grace = $GRACE) =="
planep P1-missing-post-grace   BLOCK "$GRACE" 'axes-run: ⓐ=codex ⓑ=→standpoint
crossfamily: panel(codex,agy) — 겹친 지적 0'
# 🟥 P2 flipped BLOCK→PASS on 2026-08-21: a bare `없음` is the value CLAUDE.md §자기 대조
# explicitly permits, and blocking it punished the honest form while a padded «I didn't write
# one» paragraph passed. Found by a peer session's first real use, not by this suite.
planep P2-declared-absent-ok   PASS  "$GRACE" '①영혼: 없음
axes-run: ⓐ=codex'
planep P2b-empty-field-blocks  BLOCK "$GRACE" 'soul:
axes-run: ⓐ=codex'
planep P2c-absent-heading-form PASS  "$GRACE" '## ①영혼 — 없음
axes-run: ⓐ=codex'
# fixture updated 2026-08-21: `없음` became a legal declared-absence value, so a truly vacuous
# field is now the discriminating input (the point of codex's lane was masking-by-next-field,
# not the token `없음`).
planep P2b-vacuous-before-fields BLOCK "$GRACE" '①영혼: ok
axis2-engine: steel-quench
axis2-model: opus
floor-status: ok
axes-run: ⓐ=codex ⓑ=→standpoint ⓒ=x ⓓ=x ⓔ=x ⓕ=x
controls: alive — known-positive x 1 hit · known-negative 0'
planep P3-present-korean       PASS  "$GRACE" "$SOUL
axes-run: ⓐ=codex"
planep P4-present-soul-key     PASS  "$GRACE" 'soul: 성공 정의 = 소비자 경로에서 완주한다. 절대 안 함 = FAIL 을 SKIP 으로 바꾸지 않는다
axes-run: ⓐ=codex'
planep P5-grace-old-exempt     PASS  "2026-08-01" 'axes-run: ⓐ=codex
crossfamily: panel(codex,agy) — 겹친 지적 0'
planep P6-real-corpus-negative BLOCK "$GRACE" "$(cat "$REPO_ROOT/tracks/_meta/.axes_23_passed_feat_target-freeze-gate_2026-08-18.marker" 2>/dev/null || echo 'axes-run: x')"
planep P7-real-corpus-positive PASS  "$GRACE" "$(cat "$REPO_ROOT/tracks/_meta/.axes_23_passed_fix_witness-two-commit-discipline_2026-08-17.marker" 2>/dev/null || echo '①영혼: 성공 정의 = 하나 둘 셋 넷 다섯 여섯')"

echo
echo "== cross-family findings — regression lanes (codex/gpt-5.5, diff 축, 2026-08-21) =="
# F1 self-referential FP: codex's own alignment fix flipped G8 to PASS because the
# `soul-check:` line contains 「성공정의」 and matched as its own evidence.
lane F1-selfref-soulcheck-only BLOCK 'axis2-model: opus
soul-check: reflected(델타를 성공정의에 비춰 봤고 절대 안 함 도 안 어겼다)'
# F4 grounds outside the parens
lane F4-grounds-outside-parens BLOCK "$SOUL
soul-check: reflected() — 아주 길고 그럴듯한 꼬리말이 여기 붙어 있어서 길이를 채운다"
# F3 near-miss key reads as absent
lane F3-nearmiss-key           BLOCK "$SOUL
soul_check: reflected(델타를 성공정의에 비춰 재검했다)"
lane F3b-nearmiss-space        BLOCK "$SOUL
soul-check : reflected(델타를 성공정의에 비춰 재검했다)"
planep F1b-presence-selfref    BLOCK "$GRACE" 'axes-run: ⓐ=codex
soul-check: reflected(성공 정의 대조 · 절대 안 함 확인)'
planep F1c-comment-not-soul    BLOCK "$GRACE" '# 성공 정의 를 나중에 쓸 예정이다 절대 안 함 도
axes-run: ⓐ=codex'
# F2: unparseable date must NOT take the grace exit (was fail-open)
printf 'axes-run: a=codex\n' > "$T/.axes_23_passed_nodate.marker"
_o=$( bash -c 'set -uo pipefail; SOUL_PRESENT_GRACE_DATE="$3"; . "$1"; validate_soul_present_leg "$2"' \
      _ "$T/fnp.sh" "$T/.axes_23_passed_nodate.marker" "$GRACE" 2>&1 ); _r=$?
if [ $_r -ne 0 ]; then printf '  ✅ %-40s %s\n' "F2-unparseable-date-not-exempt" "BLOCK"
else printf '  ❌ %-40s expected BLOCK, got PASS\n' "F2-unparseable-date-not-exempt"; FAIL=1; fi

echo
echo "== cross-family findings — regression lanes (agy/gemini-3.1-pro, 주장·기록 축) =="
# A6 [S]: grounds counted with ${#} passed on a single long Korean token. Word count now.
lane A6-korean-onetoken-grounds BLOCK "$SOUL
soul-check: reflected(어긋남없음확인완료했음)"
# A6b [S]: the two legs disagreed on the SAME soul block (6 vs 4 words). Aligned to 6.
# 5 words under `wc -w` — passed the old 4-word floor in the check leg while the present leg
# demanded 6 on the SAME block. Empirically calibrated, not guessed: `wc -w` does not equal a
# human word count on Korean («①영혼: 완주» reports 3), so the fixture was measured, not reasoned.
lane A6b-threshold-aligned      BLOCK '①영혼: 성공 정의
soul-check: reflected(델타를 성공정의에 비춰 재검했고 어긋남 없음)'
# A6-control: a genuinely grounded, multi-word reason still passes (this lane must NOT block).
lane A6c-control-passes         PASS "$SOUL
soul-check: reflected(codex 가 성공정의 대조 — 어긋남 없음)"

echo
echo "== 첫 실사용 findings — peer session (forge-harness-59, 2026-08-21) =="
# A marker that declares NO success definition cannot claim to have reflected against one.
lane N1-absent-soul-vs-reflected BLOCK 'soul: 없음
soul-check: reflected(델타를 성공정의에 비춰 재검했고 어긋남 없음)'
lane N2-absent-soul-degraded-ok  PASS  'soul: 없음
soul-check: DEGRADED_NO_SOUL(설계 전에 성공 정의를 쓰지 않았다 — 되비출 대상이 없다)'
# The padded confession that passed in the field: it IS a real declaration of absence, and once
# `없음` is a first-class value the padded form is no longer the only way through.
lane N3-padded-confession        PASS  'soul: 없음 — 설계 전에 안 썼다. 사후 재구성이 아니라 그 사실을 적는다. 붙잡고 있던 것은 범위 결정 하나였다
axes-run: ⓐ=codex'

# ── R1/R2 — 템플릿 잔여 (2026-08-30, 블라인드 sim 이 자기 힌트에 걸렸다) ──────────
#    힌트에 `soul:` 예시를 넣자마자 플로어 티어 3/3 이 **자리표시자를 그대로** 복사했고
#    비공허성 검사를 통과했다. 채널 검사로 닫았다: «이 기록이 템플릿 자신인가».
# 🟥 이 둘은 `planep`(presence 다리)로 돌려야 한다. 초판은 `lane`(soul-check 다리)로 짜서
#    **틀린 함수를 겨눴고**, BLOCK 기대에 PASS 가 나왔다. 초록/적색이 아니라 «무엇을 겨눴나»였다.
# 🟥 **이 레인의 기대값이 v3 에서 바뀐다. 결과에 맞춘 게 아니라 범위가 좁아진 것이고,
#    그 좁아짐이 의도다.** v2 는 「꺾쇠+공백/비-ASCII」로 일반화해 이 문장을 잡았는데,
#    같은 규칙이 `Map<String, Object>` 와 `<사용자_ID>` 를 **과차단**했다(두 계열 독립 지적).
#    「이 꺾쇠가 자리표시자인가 타입인가」는 판단이고, 판단은 코드로 안 굳힌다.
#    v3 는 «우리가 배포한 템플릿과 같은가»만 본다 — 아래 문장은 힌트에 없으므로 통과한다.
#    ⚠️ 이것은 **명명된 잔여**다: 모델이 힌트를 자기 말로 바꿔 쓰면 안 잡힌다.
planep R1-nonhint-paraphrase-not-blocked PASS 2026-09-05 "soul: 성공 정의 = <이 fix가 통과했다고 판단할 관측 가능한 결과> · 절대 안 함 = <이번 수정에서 하지 않기로 정한 것>"
# 🟥 컨트롤 — 실제로 채운 줄은 통과해야 한다. 없으면 R1 은 «presence 검사를 통째로 껐다»와 구분 안 된다.
# 🟥 cross-family 가 잡은 우회 — 내 힌트의 자리표시자 `<...>` 가 잔여 목록에 없었다
#    (codex #3 · agy 2-b 독립 수렴). 픽스처는 «가장 쉬운 표기»가 아니라 «뚫리는 표기»여야 한다.
planep R3-hint-placeholder-blocks BLOCK 2026-09-05 "soul: 성공 정의 = <...> · 절대 안 함 = <...>"
# 🟥 2라운드(agy 결함1): 잔여 목록이 «손목록»이라 규칙 문서가 새 자리표시자를 실을 때마다
#    어긋났다. 규칙으로 일반화했고, 아래가 그 양방향 고정이다. 차단 5 · 과차단 0 을 잰 뒤 박았다.
# 🟥 v3 는 «힌트가 실제로 주는» 자리표시자만 본다. 스펙 문서에만 있는 표기는 안 잡히고,
#    그건 명명된 잔여다(판단을 코드로 굳히는 것보다 낫다는 결정).
planep R4-hint-derived-placeholder-blocks BLOCK 2026-09-05 "soul-check: reflected(<무엇이 되돌아왔나>)"
planep R5-generic-type-not-blocked PASS 2026-09-05 "soul: 성공 정의 = Map<String, Object> 가 직렬화된다 · 절대 안 함 = 공개 API 깨기"
planep R6-inequality-not-blocked PASS 2026-09-05 "soul: 성공 정의 = n < 3 이면 판정 보류하고 n > 5 면 채점한다 · 절대 안 함 = 바 미달로 결론내기"
planep R2-real-content-still-passes PASS 2026-09-05 "soul: 성공 정의 = 레인 28개가 초록이고 되돌림에서 자기 레인만 적색 · 절대 안 함 = 결과에 맞춰 기대값 바꾸기"

echo
if [ $FAIL -eq 0 ]; then echo "SOUL LANES: PASS"; else echo "SOUL LANES: FAIL"; fi
exit $FAIL
