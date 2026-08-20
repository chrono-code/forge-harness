#!/usr/bin/env bash
# test_residency_admission_lanes.sh — residency_admission_check.sh 의 known-pair 레인.
# 🟥 컨트롤(감량·무변경)이 없으면 «오탐이 있나» 를 못 잰다. 차단 레인만 있는 스위트는
#    「막혔다」만 증명하고 「옳게 막혔다」는 못 증명한다(`feedback_gate_verification_must_execute`).
set -uo pipefail
CHECK="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/residency_admission_check.sh}"
# 🟥 절대경로로 고정한다. 각 레인은 임시 디렉터리로 `cd` 하므로 상대경로를 받으면
#    거기서 깨진다 — 스크래치패드에서 10/10 이던 것이 레포로 옮기자마자 **0/10** 이 됐다
#    (`feedback_parallel_isolation_unit_is_checkout_not_file`: cwd 상대경로는 이동에 안 산다).
case "$CHECK" in /*) ;; *) CHECK="$(cd "$(dirname "$CHECK")" && pwd)/$(basename "$CHECK")" ;; esac
[ -f "$CHECK" ] || { echo "❌ HARNESS ERROR: 검사 스크립트를 못 찾겠다: $CHECK" >&2; exit 2; }
PASS=0; FAIL=0
# 🟥 rc 만 보면 **처방을 안 본다.** 이 게이트의 산출물은 판정이 아니라 «무엇을 하라» 이고,
#    필드-부재 레인은 rc 만으로는 enum 가드에 가려져 격리가 안 된다(되돌림 프로브가 지목).
run() { # run <lane> <expected-rc> <setup-fn> [expected-substring]
  local lane="$1" want="$2" fn="$3" want_msg="${4:-}"
  W=$(mktemp -d); ( cd "$W" && git init -q . && mkdir -p scripts tracks/_meta && cp "$CHECK" scripts/ \
      && git config user.email t@t && git config user.name t && "$fn" ) >/dev/null 2>&1
  out=$(cd "$W" && bash scripts/"$(basename "$CHECK")" 2>&1); rc=$?
  local msg_ok=1
  if [ -n "$want_msg" ] && ! printf '%s' "$out" | grep -q "$want_msg"; then msg_ok=0; fi
  if [ "$rc" -eq "$want" ] && [ "$msg_ok" -eq 1 ]; then PASS=$((PASS+1)); printf '  ✅ %-34s rc=%s\n' "$lane" "$rc"
  else FAIL=$((FAIL+1)); printf '  ❌ %-34s rc=%s (기대 %s)\n     %s\n' "$lane" "$rc" "$want" "$(printf '%s' "$out" | head -2 | tr '\n' ' ')"; fi
  rm -rf "$W"
}
mk_base() { printf 'x\n%.0s' $(seq 1 50) > CLAUDE.md; git add CLAUDE.md; git commit -qm base; }
mk_marker() { printf '%s\n' "$1" > "tracks/_meta/.axes_23_passed_test_$(date +%Y-%m-%d).marker"; }
grow() { printf 'y\n%.0s' $(seq 1 20) >> CLAUDE.md; git add CLAUDE.md; }

L_nochange()  { mk_base; }                                                   # 컨트롤
L_shrink()    { mk_base; sed -i '' '1,20d' CLAUDE.md 2>/dev/null || sed -i '1,20d' CLAUDE.md; git add CLAUDE.md; }  # 컨트롤: 감량
L_nofield()   { mk_base; grow; mk_marker "axes-run: ⓐⓑ"; }
# 🟥 근거를 **일부러 길게** 준다. 짧으면 근거-공허 검사에 먼저 걸려서 이 레인이
#    enum 가드를 격리하지 못한다 — 되돌림 프로브가 그걸 잡았다(가드를 지워도 8/8 초록이었다).
L_badenum()   { mk_base; grow; mk_marker "residency: whatever — 근거는 충분히 길게 적어서 이 레인이 오직 enum 검사에만 걸리도록 만든다"; }
L_selfreject(){ mk_base; grow; mk_marker "residency: relocatable(knowledge/shared/rules/operations.md) — 근거를 길게 적어 오직 자기거절 가드에만 걸리게 한다"; }
L_nodest()    { mk_base; grow; mk_marker "residency: relocatable — 목적지를 안 적었다 그래도 근거는 충분히 길게 적는다"; }
L_novoid()    { mk_base; grow; mk_marker "residency: soul —"; }
L_valid()     { mk_base; grow; mk_marker "residency: soul — 절대 안 함 목록이라 판단 회로다"; }
# soul 인데 추가분이 근거 서술 → advisory 가 떠야 한다(차단은 아니다: rc=0)
L_soulprov()  { mk_base; for i in 1 2 3 4 5; do echo "2026-08-$i 실측: n=3 반증됨" >> CLAUDE.md; done; git add CLAUDE.md; mk_marker "residency: soul — 판단 회로라고 주장한다 근거는 길게"; }
L_nomarker()  { mk_base; grow; }   # tracks/_meta 는 있는데 오늘자 마커가 없다 → HARNESS ERROR
# 🟥 소비 레포: 마커 체제 자체가 없다 → **SKIP(적용 대상 없음)** 이지 차단이 아니다.
#    이 레인이 없으면 「이식 후 통과 불가」가 조용히 살아 있다(소비자 트리 실행이 잡았다).
L_consumer()  { mk_base; grow; rm -rf tracks/_meta; }

echo "── residency admission lanes ──"
run "컨트롤: 상주 무변경"        0 L_nochange
run "컨트롤: 감량(순감)"         0 L_shrink
run "순증 + 유형 선언 정상"      0 L_valid
run "soul 인데 근거서술(advisory)" 0 L_soulprov "근거 서술이다"
run "순증인데 필드 없음(+처방)"  1 L_nofield "판단 회로다"
run "순증 + enum 밖 값"          1 L_badenum
run "순증 + 자기 거절(목적지 있음)" 1 L_selfreject
run "순증 + 자기 거절(목적지 없음)" 1 L_nodest "옮길 곳을 안 적었다"
run "순증 + 근거 공허"           1 L_novoid
run "순증인데 마커 자체 부재"    2 L_nomarker
run "소비 레포(마커 체제 없음)"  0 L_consumer "적용 대상 없음"
echo "── PASS $PASS · FAIL $FAIL ──"
[ "$FAIL" -eq 0 ]
