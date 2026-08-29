#!/usr/bin/env bash
# test_preprep_prose_lanes.sh — L9 prose-candidates 레인의 회귀 앵커.
#
# 🟥 이 레인은 advisory 다. 그래서 앵커가 재는 것이 둘이다:
#   ① 판별력  — known-positive 에서 5클래스가 «전부» 발화하고 known-negative 는 0
#   ② 무해성  — 어느 쪽에서도 findings 를 «내지 않는다». 하나라도 내면 종료코드를 오염시키고,
#              그 순간 이 계기의 오탐을 무마하는 최저비용 길이 «문장 삭제»가 된다.
# 두 번째가 없으면 나중에 누가 advisory 를 blocking 으로 바꿔도 레인이 초록으로 남는다.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$HERE/plugins/fh-commons/skills/preprep"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

if ! command -v python3 >/dev/null 2>&1; then
  # 계기 부재를 «통과»로 렌더하지 않는다.
  echo "  ⚠️  UNMEASURED — python3 unavailable; prose lanes NOT run (this is not a pass)"
  echo "prose lanes: SKIPPED (not passed)"; exit 0
fi

out=$(cd "$SKILL" && python3 - <<'PY' 2>&1
import sys, json
sys.path.insert(0, '.')
import lane_prose
res = {}
for lbl, p in (('pos','fixtures/prose_known_positive.md'), ('neg','fixtures/prose_known_negative.md')):
    t = open(p, encoding='utf-8').read()
    f, n = lane_prose.scan({'fx': (t, 'markdown')}, {'fx': {'spoken': True}})
    cls = [x.strip() for x in n if x.strip().startswith('▸')]
    res[lbl] = {'findings': len(f), 'classes': len(cls)}
print(json.dumps(res))
PY
); rc=$?
if [ $rc -ne 0 ]; then
  echo "  ❌ INSTRUMENT ERROR — lane_prose 실행 실패 (rc=$rc): $out"; exit 1
fi

pf=$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['pos']['findings'])" "$out")
pc=$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['pos']['classes'])" "$out")
nf=$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['neg']['findings'])" "$out")
nc=$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['neg']['classes'])" "$out")

[ "$pc" = "5" ] && ok "L9-1 known-positive: 기계 클래스 5종이 «전부» 발화 (실제 $pc)" \
                || ng "L9-1 known-positive: 5종이어야 하는데 $pc — 클래스 하나가 죽었다"
[ "$nc" = "0" ] && ok "L9-2 known-negative: 오탐 0 (실제 $nc)" \
                || ng "L9-2 known-negative: 오탐 $nc — 판별력이 아니라 잡음이다"
[ "$pf" = "0" ] && ok "L9-3 advisory 불변(pos): findings 0" \
                || ng "L9-3 advisory 깨짐(pos): findings $pf — 종료코드를 오염시킨다"
[ "$nf" = "0" ] && ok "L9-4 advisory 불변(neg): findings 0" \
                || ng "L9-4 advisory 깨짐(neg): findings $nf"

echo "prose lanes: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
