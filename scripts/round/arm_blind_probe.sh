#!/usr/bin/env bash
# «팔이 읽으면 안 되는 tracked 자산»이 클론에서 실제로 사라지나 — known-pair + 되돌림.
#
# 🟥 이 프로브가 없으면 배선은 «산문이 실행기»다. 그리고 「제거했다」는 rm 의 rc 로 확인할 수
#    없다 — 경로 오타면 rm 은 지울 게 없어서 «성공»을 낸다. 판정은 «제거 후 존재»로만 한다.
# 사용: arm_blind_probe.sh   → rc 0 통과 · 1 실패 · 2 계기 문제
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
R="$ROOT/scripts/sim_isolated_run.sh"
[ -f "$R" ] || { echo "🟥 러너 없음: $R" >&2; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ck(){ if [ "$2" = "$3" ]; then echo "  🟢 $1 ($2)"; pass=$((pass+1))
      else echo "  🟥 $1 (기대 $3, 실제 $2)"; fail=$((fail+1)); fi; }

W="$T/clone"
git clone --quiet --local --no-hardlinks "$ROOT" "$W" 2>/dev/null || { echo "🟥 클론 실패" >&2; exit 2; }

# 🟥 조건을 «만든다». 이 프로브는 「이 트리에 픽스처가 있나」가 아니라 「제거 로직이 도나」를 잰다.
#    두 브랜치가 갈려서 워크트리에 픽스처가 없을 수 있다(실측: probe4/base 엔 없다).
#    그때 K+ 가 0 이 되어 프로브가 «무의미»해지므로, 실물 픽스처를 실제 경로에 놓고 잰다.
#    ⚠️ 합성이 아니다 — git 에 있는 그 내용을 그 경로에 둔다.
FXB="origin/docs/agents-defeater-mirror"
FXD="scripts/fixtures/knownpair_refusal_48_2026-09-01"
if [ ! -e "$W/$FXD" ]; then
  mkdir -p "$W/$FXD/items"
  i=1; got=0
  while [ "$i" -le 48 ]; do
    n=$(printf '%02d' "$i")
    if git -C "$ROOT" show "${FXB}:${FXD}/items/ITEM_${n}.txt" > "$W/$FXD/items/ITEM_${n}.txt" 2>/dev/null; then
      got=$((got+1))
    fi
    i=$((i+1))
  done
  echo "  ── 조건 조성: 실물 items ${got}건을 클론의 실제 경로에 놓았다"
  [ "$got" -gt 0 ] || { echo "  🟥 픽스처를 git 에서 못 꺼냈다 — 프로브 불가(UNMEASURED)"; exit 2; }
fi

# ── K+ : 제거 «전» 클론에 실재하나. 🟥 개수까지 적는다
HIT_BEFORE=$(/usr/bin/grep -rlF -- '가상의 팀명' "$W" 2>/dev/null | wc -l | tr -d ' ')
KPOS=$(/usr/bin/grep -rlF -- 'REFUSE_RE' "$W" 2>/dev/null | wc -l | tr -d ' ')
KNEG=$(/usr/bin/grep -rlF -- "zzABSENT$$_$(date +%s%N)zz" "$W" 2>/dev/null | wc -l | tr -d ' ')
ck "컨트롤 K+ (스캔이 산다: REFUSE_RE)" "$([ "$KPOS" -gt 0 ] && echo live || echo dead)" live
ck "컨트롤 K- (생성 부재토큰)" "$KNEG" 0
[ "$HIT_BEFORE" -gt 0 ] && { echo "  🟢 K+ 제거 전 히트 $HIT_BEFORE (>0)"; pass=$((pass+1)); } \
  || { echo "  🟥 제거 전 히트가 0 — 픽스처가 클론에 없다. 이 프로브는 무의미하다"; fail=$((fail+1)); }

# ── 러너와 «같은 목록»으로 제거한다. 🟥 목록을 러너 소스에서 읽어 이중 정의를 막는다
# 🟥 `mapfile` 은 bash 3.2(맥 기본)에 없다 — 실측으로 밟았다. while-read 로 간다.
PATHS=()
while IFS= read -r _p; do [ -n "$_p" ] && PATHS+=("$_p"); done < <(
  sed -n 's/^ *ARM_BLIND_PATHS=( *\(.*\) *)/\1/p' "$R" | tr -d '"' | tr ' ' '\n' | grep -v '^$')
[ "${#PATHS[@]}" -gt 0 ] || { echo "  🟥 러너에서 ARM_BLIND_PATHS 를 못 읽었다"; exit 1; }
echo "  ── 러너 선언 목록: ${PATHS[*]}"
for bp in "${PATHS[@]}"; do rm -rf "$W/$bp"; done

HIT_AFTER=$(/usr/bin/grep -rlF -- '가상의 팀명' "$W" 2>/dev/null | wc -l | tr -d ' ')
ck "K- 제거 후 히트" "$HIT_AFTER" 0
for bp in "${PATHS[@]}"; do
  ck "제거 후 «존재»로 확인: $bp" "$([ -e "$W/$bp" ] && echo 남음 || echo 없음)" 없음
done
# 🟥 되돌림: 러너에 제거 줄이 «실제로» 있나 (없으면 위 통과는 이 스크립트 자신의 rm 덕이다)
grep -q 'ARM_BLIND_PATHS' "$R" && { echo "  🟢 [되돌림] 러너에 제거 배선이 실재한다"; pass=$((pass+1)); } \
  || { echo "  🟥 [되돌림] 러너엔 없다 — 이 프로브만 지우고 있었다(장식)"; fail=$((fail+1)); }
grep -q 'BLIND-STRIP FAILED' "$R" && { echo "  🟢 [되돌림] 실패 시 회차를 버리는 분기가 있다"; pass=$((pass+1)); } \
  || { echo "  🟥 [되돌림] 실패해도 계속 도는 배선이다"; fail=$((fail+1)); }

echo "  ── arm_blind: $pass passed, $fail failed  (히트 $HIT_BEFORE → $HIT_AFTER)"
[ "$fail" = 0 ]
