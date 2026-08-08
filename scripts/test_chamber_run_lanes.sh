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
_mk_budget()  { printf 'ESTIMATE: demo-scale, self-capped\nACTUAL: -\n' > "$(_ws "$1")/BUDGET.md"; }
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
_mk_intent g2; _mk_budget g2; _mk_sim3 g2; _mk_verdict g2 PARTIAL-EMIT
_run g2; rc=$?
_t "L10 PASS — PARTIAL-EMIT 도 정상 완주한다" 0 "$rc"
if grep -q "PARTIAL-EMIT" "$T/tracks/_chamber/INDEX.md" 2>/dev/null; then
  _t "L10b PASS ★ 원장에 PARTIAL-EMIT 으로 기록(EMIT 부분일치 오인 아님)" 0 0
else
  _t "L10b PASS ★ 원장 PARTIAL-EMIT 기록" 0 1
fi

# ── L11 멱등: 완주한 런을 다시 돌려도 원장이 중복되지 않는다 ──────────────────
# ⚠️ g2 로 잰다. g1 은 **원장이 없을 때** 완주했으므로(L9b) 원장이 생긴 뒤 재실행하면
# 그때 처음 append 된다 — 그건 멱등 위반이 아니라 순서 아티팩트다. 첫 판본이 g1 으로
# 재서 거짓 실패를 냈고, 계기가 아니라 **테스트 설계**가 틀린 경우였다.
_before="$(grep -c "g2" "$T/tracks/_chamber/INDEX.md" 2>/dev/null || true)"
_before="${_before//[^0-9]/}"; _before="${_before:-0}"
_run g2 >/dev/null 2>&1
_after="$(grep -c "g2" "$T/tracks/_chamber/INDEX.md" 2>/dev/null || true)"
_after="${_after//[^0-9]/}"; _after="${_after:-0}"
if [ "$_before" = "$_after" ]; then _t "L11 PASS — 재실행이 원장을 중복 append 하지 않는다" 0 0
else echo "❌ L11 멱등 실패: $_before → $_after"; FAIL=$((FAIL+1)); fi

# ── L12 컨트롤: 이 테스트가 실물 tracks/_chamber 를 건드리지 않았는가 ─────────
if [ -d "$SRC/../tracks/_chamber/g1" ] || [ -d "$SRC/../tracks/_chamber/g2" ]; then
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
