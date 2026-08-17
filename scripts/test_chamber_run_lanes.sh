#!/usr/bin/env bash
# test_chamber_run_lanes.sh — `chamber_run.sh` 의 게이트가 **실제로 막는지** known-pair 로 잰다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 왜 필요한가 (identity ② 의 마지막 다리)
# ─────────────────────────────────────────────────────────────────────────────
# 챔버 러너는 6단계 게이트를 기계적으로 강제하지만, **그 게이트들이 정말 막는지 잰 적이 없다.**
# 릴리스 게이트에서 🔵 RC 는 세 다리를 요구한다 — (a) 구현 (b) known-pair 캘리브레이션
# (c) 자기 테스트 초록. 러너는 (a)만 있었다.
#
# ★ **BLOCK arm 과 PASS arm 을 대칭으로 짠다.** 막는 것만 재면 *"전부 막는 게이트"* 도 만점을
# 받는다 — 이 지적은 cross-family(agy/gemini-3.1-pro-high)가 냈고 채택했다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 격리 — 러너를 고치지 않고 실물을 돌린다
# ─────────────────────────────────────────────────────────────────────────────
# 러너는 루트를 `dirname "$0"/..` 로 잡고 `tracks/`·`plugins/` 존재로 FH 를 확인한다.
# 그래서 **스크립트를 임시 트리에 복사**하면 그 임시 트리가 루트가 된다 — 러너 수정 0,
# 실제 `tracks/_chamber/` 오염 0. (cross-family 는 환경변수 DI 를 제안했지만, 러너를 건드리지
# 않는 쪽이 더 가볍고 **테스트가 실물 코드 경로를 그대로 탄다**.)
#
# 사용: bash scripts/test_chamber_run_lanes.sh
# exit: 0 전 레인 통과 · 1 실패 있음 · 10 harness error

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SRC/chamber_run.sh"
[ -f "$RUNNER" ] || { echo "❌ chamber_run.sh 부재" >&2; exit 10; }

T="$(mktemp -d -t chrun_t.XXXXXX)" || exit 10
trap 'rm -rf "$T"' EXIT INT TERM
mkdir -p "$T/scripts" "$T/tracks/_chamber" "$T/plugins" || exit 10
cp "$RUNNER" "$T/scripts/" || exit 10
# 순서 증인은 이 테스트의 대상이 아니다 — 있으면 부수 효과가 섞이므로 복사하지 않는다.
# (러너는 witness 부재를 경고만 하고 진행하도록 설계돼 있다. 그 자체가 아래 L0 에서 확인된다.)

PASS=0; FAIL=0
_t() { # $1=label $2=expected-rc $3=actual-rc
  if [ "$2" = "$3" ]; then echo "✅ $1 → rc=$3"; PASS=$((PASS+1));
  else echo "❌ $1 → rc=$3 (기대 $2)"; FAIL=$((FAIL+1)); fi
}
_run() { ( cd "$T" && bash "$T/scripts/chamber_run.sh" "$1" >/dev/null 2>&1 ); }
_ws()  { echo "$T/tracks/_chamber/$1"; }

_mk_intent() { # $1=slug — 채워진 INTENT
  cat > "$(_ws "$1")/INTENT.md" <<'EOF'
# INTENT — test

## Candidate intent
테스트용 후보 능력 한 줄.

## Success conditions (each with a check class)
1. 게이트가 실제로 막는다 · [mandatory-pass]
2. 통과해야 하는 입력은 통과한다 · [mandatory-pass]

## Failure cost
- 없음(테스트)
EOF
}
# 🟥 ACTUAL 을 여기 안 쓴다 — 그리고 그 «안 쓴다»가 이 픽스처의 수리 지점이다.
# 이전 판본은 `ESTIMATE:...\nACTUAL: -` 를 **한 번에** 썼다. 그래서 12레인 어디에도
# «추정을 적는다 → 돌린다 → 실비용을 적는다» 라는 **실제 순서가 존재하지 않았고**,
# 러너가 증인 아티팩트를 사후 변경하도록 강제하는 결함(런 #11 실측)이 구조적으로
# 안 잡혔다. 픽스처가 *상태*를 모델링하고 결함은 *과정*에 있었다.
_mk_budget()  { printf 'ESTIMATE: demo-scale, self-capped\n' > "$(_ws "$1")/BUDGET.md"; }
_mk_actual()  { printf 'ACTUAL: 3 dispatches, demo-scale\n' > "$(_ws "$1")/ACTUAL.md"; }
_sha() { # $1=path — 이식성: coreutils / BSD 양쪽
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
_mk_sim3()    { printf '## beginner\n첫 접촉 마찰.\n\n## main-player\n일상 사용 가치.\n\n## challenger\n회의적 공격.\n' > "$(_ws "$1")/SIM_NOTES.md"; }
_mk_verdict() { printf '# verdict\n\nVERDICT: %s\n\n## Carry-forward\n- 없음\n' "$2" > "$(_ws "$1")/EMISSION_VERDICT.md"; }

echo "── chamber_run 게이트 known-pair (격리 트리: $T) ──"

# ── L0 워크스페이스 생성 + step2 진입 차단 (BLOCK) ────────────────────────────
# 첫 실행은 워크스페이스와 INTENT 템플릿을 만들고 **막아야** 한다.
_run g1; rc=$?
_t "L0 BLOCK — 신규 런은 INTENT 미작성으로 막힌다" 1 "$rc"
[ -f "$(_ws g1)/INTENT.md" ] && _t "L0b PASS — 템플릿이 실제로 생성됐다" 0 0 || _t "L0b PASS — 템플릿 생성" 0 1

# ── L1 step2: 플레이스홀더 잔존 (BLOCK) ───────────────────────────────────────
_run g1; rc=$?
_t "L1 BLOCK — 플레이스홀더가 남으면 막는다" 1 "$rc"

# ── L2 step2: 성공조건이 비면 (BLOCK) — "플레이스홀더만 지우면 통과" 방지 ──────
cat > "$(_ws g1)/INTENT.md" <<'EOF'
# INTENT — test

## Candidate intent
채워진 한 줄.

## Success conditions (each with a check class)

## Failure cost
-
EOF
_run g1; rc=$?
_t "L2 BLOCK — 성공조건 0건이면 막는다(껍데기 통과 방지)" 1 "$rc"

# ── L3 step3: INTENT 통과 후 BUDGET 플레이스홀더 (BLOCK) ─────────────────────
_mk_intent g1
_run g1; rc=$?
_t "L3 BLOCK — INTENT 통과 → BUDGET ESTIMATE 미기재로 막힌다" 1 "$rc"
[ -f "$(_ws g1)/BUDGET.md" ] && _t "L3b PASS — BUDGET 템플릿 생성됨" 0 0 || _t "L3b PASS — BUDGET 템플릿" 0 1

# ── L4 step4: 페르소나 파일 자체가 없으면 (BLOCK) ─────────────────────────────
_mk_budget g1
_run g1; rc=$?
_t "L4 BLOCK — SIM_NOTES 부재로 막힌다" 1 "$rc"

# ── L5 step4 ★의미론: 같은 페르소나를 3번 써도 막는다 (BLOCK) ────────────────
# cross-family 지적 — "3종 존재" 를 문자열 수로 세면 중복이 통과한다.
printf '## beginner\nA\n\n## beginner\nB\n\n## beginner\nC\n' > "$(_ws g1)/SIM_NOTES.md"
_run g1; rc=$?
_t "L5 BLOCK ★ 동일 페르소나 3회는 3종으로 안 센다" 1 "$rc"

# ── L6 step4 ★의미론: 2종만 있으면 막는다 (BLOCK) ────────────────────────────
printf '## beginner\nA\n\n## challenger\nB\n' > "$(_ws g1)/SIM_NOTES.md"
_run g1; rc=$?
_t "L6 BLOCK ★ 2/3 페르소나는 통과 못 한다" 1 "$rc"

# ── L7 step5: 3종 갖추면 step4 통과, VERDICT 미기재로 막힌다 (경계 통과+차단) ──
_mk_sim3 g1
_run g1; rc=$?
_t "L7 BLOCK — 페르소나 3종 통과 후 VERDICT 미기재로 막힌다" 1 "$rc"
[ -f "$(_ws g1)/EMISSION_VERDICT.md" ] && _t "L7b PASS ★ step4 를 실제로 통과했다(다음 템플릿 생성)" 0 0 \
  || _t "L7b PASS ★ step4 통과" 0 1

# ── L8 step5: 판정 문자열이 불량이면 (BLOCK) ─────────────────────────────────
printf '# verdict\n\nVERDICT: MAYBE\n' > "$(_ws g1)/EMISSION_VERDICT.md"
_run g1; rc=$?
_t "L8 BLOCK — 비표준 판정(MAYBE)은 막는다" 1 "$rc"

# ── L9 ★PASS arm: 전부 갖추면 완주한다 ───────────────────────────────────────
# 이 레인이 없으면 "전부 막는 게이트" 도 만점을 받는다.
_mk_verdict g1 KILL
# ── L8b step6: verdict 는 있는데 ACTUAL 이 없으면 막힌다 (BLOCK) ───────────────
# 신설(2026-08-17). 종전 픽스처는 ACTUAL 을 BUDGET 에 미리 박아둬서 이 경계가 없었다.
_run g1; rc=$?
_t "L8b BLOCK — verdict 후 ACTUAL 미기재면 step6 이 막는다" 1 "$rc"
[ -f "$(_ws g1)/ACTUAL.md" ] \
  && _t "L8b-2 — step6 이 ACTUAL.md 템플릿을 생성한다(BUDGET.md 아님)" 0 0 \
  || { echo "❌ L8b-2 — ACTUAL.md 템플릿 미생성"; FAIL=$((FAIL+1)); }

_mk_actual g1
_run g1; rc=$?
_t "L9 PASS ★ 전건 충족 시 완주한다(전부-차단 버그 검출)" 0 "$rc"

# ── L9b ★ 원장 부재는 **조용히 넘어가지 않는다**(fail-visible) ────────────────
# 첫 실행에서 발견: 임시 트리에 INDEX.md 가 없자 러너가 skip 하면서 경고를 냈다.
# 이건 결함이 아니라 설계다 — 원장이 없다고 완주를 막으면 과차단이고, 조용히 넘기면
# `not found ≠ 0` 위반이다. **경고를 내는 그 동작 자체**를 레인으로 고정한다.
_out="$( cd "$T" && bash "$T/scripts/chamber_run.sh" g1 2>&1 )"
case "$_out" in
  *"no ledger"*) _t "L9b PASS ★ 원장 부재를 경고로 드러낸다(무음 skip 아님)" 0 0 ;;
  *)             echo "❌ L9b — 원장 부재가 무음으로 넘어갔다"; FAIL=$((FAIL+1)) ;;
esac

# ── L10 PARTIAL-EMIT 이 EMIT 로 오인되지 않는다 ──────────────────────────────
# 원장을 만들어 둔다 — 위 L9b 가 "없을 때" 를 쟀으니 여기서는 "있을 때" 를 잰다.
printf '# Chamber Run Ledger (test)\n\n## Runs\n\n| Run | Date | Candidate | Verdict | Carry | Workspace |\n|---|---|---|---|---|---|\n' \
  > "$T/tracks/_chamber/INDEX.md"
mkdir -p "$(_ws g2)"; _run g2 >/dev/null 2>&1
_mk_intent g2; _mk_budget g2; _mk_sim3 g2; _mk_verdict g2 PARTIAL-EMIT; _mk_actual g2
_run g2; rc=$?
_t "L10 PASS — PARTIAL-EMIT 도 정상 완주한다" 0 "$rc"
if grep -q "PARTIAL-EMIT" "$T/tracks/_chamber/INDEX.md" 2>/dev/null; then
  _t "L10b PASS ★ 원장에 PARTIAL-EMIT 으로 기록(EMIT 부분일치 오인 아님)" 0 0
else
  _t "L10b PASS ★ 원장 PARTIAL-EMIT 기록" 0 1
fi

# ── L11 멱등: 완주한 런을 다시 돌려도 **G4 원장(INDEX.md)** 이 중복되지 않는다 ─────
# ⚠️ 이건 **증인 원장이 아니다**(cross-family 가 그 혼동을 지목했다). 증인 멱등은 L14 가 잰다.
# ⚠️ g2 로 잰다. g1 은 **원장이 없을 때** 완주했으므로(L9b) 원장이 생긴 뒤 재실행하면
# 그때 처음 append 된다 — 그건 멱등 위반이 아니라 순서 아티팩트다. 첫 판본이 g1 으로
# 재서 거짓 실패를 냈고, 계기가 아니라 **테스트 설계**가 틀린 경우였다.
_before="$(grep -c "g2" "$T/tracks/_chamber/INDEX.md" 2>/dev/null || true)"
_before="${_before//[^0-9]/}"; _before="${_before:-0}"
_run g2 >/dev/null 2>&1
_after="$(grep -c "g2" "$T/tracks/_chamber/INDEX.md" 2>/dev/null || true)"
_after="${_after//[^0-9]/}"; _after="${_after:-0}"
if [ "$_before" = "$_after" ]; then _t "L11 PASS — 재실행이 G4 원장(INDEX.md)을 중복 append 하지 않는다" 0 0
else echo "❌ L11 멱등 실패: $_before → $_after"; FAIL=$((FAIL+1)); fi

# ── L13 ★이음매: 러너가 «증인 아티팩트»를 판정 후 변경하지 않는다 ────────────
# 🟥 이 레인이 없어서 런 #11 이 첫 형식 완주에서 TAMPERED 로 죽었다. 기전은 이 파일
# 상단 주석이 스스로 적어둔 그것이다 — 「순서 증인은 이 테스트의 대상이 아니다」.
# 러너 레인은 증인을 제외했고 증인 16레인은 증인을 단독 시험했다. ⇒ **러너 × 증인의
# 이음매를 어느 쪽 테스트도 안 봤다.** 여기서 그 이음매를 «과정»으로 고정한다.
# 증인 스크립트 자체는 git 이력을 읽으므로 임시 트리에서 못 돌린다 — 대신 그것이
# 의존하는 **불변식**(판정 전에 해시가 걸린 파일은 이후 안 바뀐다)을 직접 잰다.
mkdir -p "$(_ws g3)"; _run g3 >/dev/null 2>&1
_mk_intent g3; _mk_budget g3; _mk_sim3 g3; _mk_verdict g3 KILL
_run g3 >/dev/null 2>&1                     # step5 까지 진행
# ⚠️ 이 트리에는 증인 스크립트가 **없다**(위 35행에서 일부러 복사 안 함). 그러므로 여기서
# 실제 증인 기록이 생기지는 않는다 — 이 레인이 재는 것은 «증인이 의존하는 불변식»(판정 전에
# 해시가 걸린 파일이 이후 안 바뀐다)뿐이다. 초판 주석이 "여기서 BUDGET 해시가 증인이 된다"
# 라고 적었는데 **거짓이었고**(cross-family 적발), 그 거짓이 L13-a 를 실제보다 강해 보이게 했다.
_b_at_verdict="$(_sha "$(_ws g3)/BUDGET.md")"
_mk_actual g3
_run g3; rc=$?
_t "L13 PASS — ACTUAL 기록 후에도 완주한다" 0 "$rc"
_b_at_end="$(_sha "$(_ws g3)/BUDGET.md")"
if [ "$_b_at_verdict" = "$_b_at_end" ]; then
  _t "L13 ★이음매-a — 완주해도 증인 아티팩트(BUDGET.md)가 안 바뀐다" 0 0
else
  echo "❌ L13 이음매-a 실패 — 러너가 증인 아티팩트를 변경했다(TAMPERED 재발)"; FAIL=$((FAIL+1))
fi

# ── L13-b ★이음매의 **진짜** 축: 러너가 «무엇을 고치라고 시키는가» ────────────
# 🟥 위 L13-a 만으로는 부족하다 — 되돌림 프로브(2026-08-17)가 그걸 실측했다.
# 옛 코드로 되돌려도 L13-a 는 **초록으로 남았다.** 이유: **러너는 BUDGET.md 를 직접
# 안 고친다 — 사람에게 고치라고 시킨다.** 파일 해시만 보는 어서션은 사람이 그 지시를
# 따르는 경로를 구조적으로 못 본다. 즉 L13-a 는 그 자체로는 **장식에 가까웠다.**
# ⇒ 잴 것은 파일이 아니라 **지시**다: step6 이 이름을 대는 파일이 증인 대상이면 안 된다.
mkdir -p "$(_ws g4)"; _run g4 >/dev/null 2>&1
_mk_intent g4; _mk_budget g4; _mk_sim3 g4; _mk_verdict g4 KILL
_step6_msg="$( cd "$T" && bash "$T/scripts/chamber_run.sh" g4 2>&1 )"   # step6 에서 막힌다
_witnessed_re='INTENT\.md|BUDGET\.md|SIM_NOTES\.md|EMISSION_VERDICT\.md'
# 🟥 **한 줄이 아니라 출력 전체를 본다.** 초판은 `grep 'step 6 BLOCKED'` 한 줄만 검사했고,
# cross-family(A급)가 그 게임 가능성을 지목했다 — 그 줄은 ACTUAL.md 로 두고 **뒤에 한 줄 더**
# `echo "also update $WS/BUDGET.md"` 를 붙이면 레인은 초록인데 사용자 경로는 tamper 로 돌아간다.
# 사람이 실제로 읽는 것은 **차단 시 출력 전부**이므로, 재는 대상도 그것이어야 한다.
# 범위 = **차단 블록**(그 줄부터 끝까지). 출력 전체를 훑으면 정상 진행줄
# (`✓ step 2: INTENT.md present`)까지 걸려 거짓 적색이 난다 — 첫 판본이 그렇게 났다.
_step6_block="$(printf '%s\n' "$_step6_msg" | awk '/step 6 BLOCKED/{f=1} f')"
if [ -z "$_step6_block" ]; then
  echo "❌ L13-b 계기 실패 — step6 차단 메시지를 못 잡았다(known-positive 부재)"; FAIL=$((FAIL+1))
elif printf '%s\n' "$_step6_block" | grep -E "$_witnessed_re" | grep -qvE '증인|witness|TAMPERED|아니다'; then
  echo "❌ L13-b ★ step6 출력이 **증인 아티팩트**를 고치라고 시킨다 — 완주하면 TAMPERED 다"
  printf '%s\n' "$_step6_msg" | grep -E "$_witnessed_re" | sed 's/^/   → /'; FAIL=$((FAIL+1))
else
  _t "L13-b ★이음매 — step6 차단 블록이 증인 대상을 지목하지 않는다" 0 0
fi
# 컨트롤: 위 정규식이 실제로 매칭하긴 하는가(늘 «불일치»를 내는 죽은 계기 배제)
if printf 'x BUDGET.md y\n' | grep -qE "$_witnessed_re"; then
  _t "L13-b 컨트롤 — 증인-파일 정규식이 살아 있다" 0 0
else
  echo "❌ L13-b 컨트롤 — 정규식이 known-positive 도 못 잡는다"; FAIL=$((FAIL+1))
fi

# ── L13b 컨트롤: 위 비교가 «늘 같다» 를 내는 죽은 계기가 아님을 보인다 ────────
# 컨트롤이 없으면 L13 은 _sha 가 상수를 뱉어도 초록이다. 실제로 바꿔서 적색을 확인한다.
printf 'ESTIMATE: mutated by control\n' > "$(_ws g3)/BUDGET.md"
if [ "$(_sha "$(_ws g3)/BUDGET.md")" != "$_b_at_verdict" ]; then
  _t "L13b 컨트롤 — 실제로 바꾸면 해시가 갈린다(계기 생존)" 0 0
else
  echo "❌ L13b — 파일을 바꿨는데 해시가 같다. 계기가 죽었다"; FAIL=$((FAIL+1))
fi

# ── L13c: ACTUAL.md 는 증인 대상이 아니다 — 러너가 그것을 record 하지 않는다 ───
# 정의상 판정 후 산물이므로 해시를 걸면 안 된다. 러너 소스에서 직접 확인한다
# (부재 측정이므로 같은 실행에 known-positive 를 붙인다).
# 🟥 리터럴 한 줄을 찾지 않는다 — **호출 인자 집합을 뽑아 기대집합과 대조**한다.
# 초판은 `_witness_record "$WS/ACTUAL.md"` 라는 **정확한 리터럴**만 봤고, cross-family(B급)가
# `p="$WS/ACTUAL.md"; _witness_record "$p"` 로 우회 가능함을 지목했다. 집합 대조로 바꾸면
# 변수 간접호출은 기대집합에 없는 토큰으로 나타나 **시끄럽게 실패**한다(안전 방향).
_calls="$(grep -oE '_witness_record "\$WS/[A-Za-z_]+\.md"' "$T/scripts/chamber_run.sh" \
          | sed 's|.*/||; s|"$||' | sort -u | tr '\n' ' ')"
_calls="${_calls% }"
_expected="BUDGET.md EMISSION_VERDICT.md INTENT.md SIM_NOTES.md"
_defs="$(grep -cE '^\s*_witness_record ' "$T/scripts/chamber_run.sh" || true)"
if [ "$_calls" = "$_expected" ]; then
  _t "L13c — 증인 기록 호출 집합이 기대와 정확히 일치(ACTUAL.md 부재)" 0 0
else
  echo "❌ L13c ★ 증인 기록 대상이 바뀌었다"
  echo "   기대: [$_expected]"
  echo "   실제: [$_calls]   (리터럴 아닌 호출이 있으면 여기서 빠진다)"; FAIL=$((FAIL+1))
fi
# 컨트롤: 위 grep 이 호출을 실제로 세는가 — 파싱된 수와 총 호출 수가 맞는지
if [ "$_defs" = "4" ]; then
  _t "L13c 컨트롤 — _witness_record 호출 4개 전부 리터럴로 파싱됨" 0 0
else
  echo "❌ L13c 컨트롤 — 호출 $_defs 개 중 리터럴 파싱은 $(echo "$_calls" | wc -w) 개. 간접호출 의심"
  FAIL=$((FAIL+1))
fi

# ── L14 ★ 증인 멱등 가드를 **실제로** 돌린다 (신설, cross-family A급 적발분) ────
# 🟥 L11 은 멱등을 «잰다고 적혀 있었지만» 실제로는 `tracks/_chamber/INDEX.md` 의 g2 줄 수를
# 셌다 — **증인 원장이 아니다.** 게다가 이 트리엔 증인 스크립트가 아예 없었다. 그래서 내
# 멱등 가드의 `substr($0,9)` 오프셋 버그(슬러그 첫 글자 절단 → **어떤 엔트리와도 매칭 안 됨**)가
# 26레인 전부 초록인 채로 통과했다. 여기서 증인을 **복사해 실제로 두 번 기록**하고 원장을 센다.
# ⚠️ `CLAUDE_PROJECT_DIR` 를 벗긴다 — 안 벗기면 REPO_ROOT 가 **실물 레포**가 되어 진짜 원장을 쓴다.
cp "$SRC/chamber_witness.sh" "$T/scripts/" 2>/dev/null || true
if [ -f "$T/scripts/chamber_witness.sh" ]; then
  mkdir -p "$T/knowledge/shared/learnings"
  printf 'hello\n' > "$T/w_art.md"
  env -u CLAUDE_PROJECT_DIR bash "$T/scripts/chamber_witness.sh" record wlane "$T/w_art.md" >/dev/null 2>&1
  _w1="$(grep -c '^- run: wlane' "$T/knowledge/shared/learnings/chamber_ordering_witness.yaml" 2>/dev/null || echo 0)"
  env -u CLAUDE_PROJECT_DIR bash "$T/scripts/chamber_witness.sh" record wlane "$T/w_art.md" >/dev/null 2>&1
  _w2="$(grep -c '^- run: wlane' "$T/knowledge/shared/learnings/chamber_ordering_witness.yaml" 2>/dev/null || echo 0)"
  if [ "$_w1" = "1" ] && [ "$_w2" = "1" ]; then
    _t "L14 ★ 동일 (run,artifact,sha) 재기록이 실제로 스킵된다" 0 0
  else
    echo "❌ L14 멱등 가드 미작동 — 1회차 $_w1 · 2회차 $_w2 (기대 1·1)"; FAIL=$((FAIL+1))
  fi
  # 컨트롤: 내용이 바뀌면 **반드시** 새 엔트리가 생긴다(TAMPERED 증거를 접으면 안 된다)
  printf 'changed\n' > "$T/w_art.md"
  env -u CLAUDE_PROJECT_DIR bash "$T/scripts/chamber_witness.sh" record wlane "$T/w_art.md" >/dev/null 2>&1
  _w3="$(grep -c '^- run: wlane' "$T/knowledge/shared/learnings/chamber_ordering_witness.yaml" 2>/dev/null || echo 0)"
  if [ "$_w3" = "2" ]; then
    _t "L14b 컨트롤 — 내용이 바뀌면 새 엔트리가 남는다(가드가 tamper 를 안 숨긴다)" 0 0
  else
    echo "❌ L14b 컨트롤 — 내용 변경 후 엔트리 $_w3 (기대 2). 가드가 실제 tamper 를 숨긴다"; FAIL=$((FAIL+1))
  fi
  # 컨트롤: 이 레인이 **실물** 원장을 안 건드렸는가
  if [ -f "$T/knowledge/shared/learnings/chamber_ordering_witness.yaml" ] \
     && ! grep -q '^- run: wlane' "$SRC/../knowledge/shared/learnings/chamber_ordering_witness.yaml" 2>/dev/null; then
    _t "L14c 컨트롤 — 실물 증인 원장 무오염" 0 0
  else
    echo "❌ L14c ★ 실물 원장이 오염됐다 (CLAUDE_PROJECT_DIR 누출 의심)"; FAIL=$((FAIL+1))
  fi
else
  echo "❌ L14 — chamber_witness.sh 를 복사하지 못했다(미측정, 0 아님)"; FAIL=$((FAIL+1))
fi

# ── L12 컨트롤: 이 테스트가 실물 tracks/_chamber 를 건드리지 않았는가 ─────────
if [ -d "$SRC/../tracks/_chamber/g1" ] || [ -d "$SRC/../tracks/_chamber/g2" ] || [ -d "$SRC/../tracks/_chamber/g3" ] || [ -d "$SRC/../tracks/_chamber/g4" ]; then
  echo "❌ L12 격리 실패 — 실제 워크스페이스가 오염됐다"; FAIL=$((FAIL+1))
else
  _t "L12 컨트롤 — 실물 워크스페이스 무오염" 0 0
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "✅ 캘리브레이션 통과 ($PASS 레인) — BLOCK/PASS 대칭, 전부-차단 버그도 검출한다."
  echo "   ⚠️ 못 재는 것(명명): INTENT 내용의 실질 타당성 · challenger 가 진짜 공격했는지 ·"
  echo "      ESTIMATE 가 현실적인지 · 런타임 중단 시 복구력. 전부 정적 게이트 밖이다."
  exit 0
fi
echo "🟥 캘리브레이션 실패 ($FAIL/$((PASS+FAIL)))"
exit 1
