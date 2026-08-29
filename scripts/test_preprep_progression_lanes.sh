#!/usr/bin/env bash
# test_preprep_progression_lanes.sh — L9 progression 레인의 회귀 앵커.
#
# 재는 것 셋:
#   P1 판별력   실사고 재현(①이 화면에서 빠짐) → 그 단계를 «이름으로» 지목하나
#   P2 오탐 0   네 칸이 다 있으면 findings 0
#   P3 부재≠0   선언이 없으면 NOT_CONFIGURED 이고 «통과»로 렌더하지 않나
# 🟥 P3 이 없으면 선언을 지우는 것만으로 이 레인이 조용해진다(가장 싼 무마 경로).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$HERE/plugins/fh-commons/skills/preprep"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

if ! command -v python3 >/dev/null 2>&1; then
  echo "  ⚠️  UNMEASURED — python3 unavailable; progression lanes NOT run (this is not a pass)"
  echo "progression lanes: SKIPPED (not passed)"; exit 0
fi

out=$(cd "$SKILL" && python3 - <<'PY' 2>&1
import sys, json
sys.path.insert(0, '.')
import lane_progression as LP
cfg = {'progressions': [{'id': 'escalation', 'steps': [
    {'anchor': '좋아집니다'}, {'anchor': '그래도 남는'},
    {'anchor': '더 늘려도'}, {'anchor': '입장을 바꾸면'}], 'screens': ['deck']}]}
r = {}
for k, f in (('pos', 'fixtures/progression_known_positive.md'),
             ('neg', 'fixtures/progression_known_negative.md')):
    t = open(f, encoding='utf-8').read()
    fi, _ = LP.scan(cfg, {'deck': (t, 'markdown')}, {'deck': {}})
    r[k] = {'n': len(fi), 'named': [x[2] for x in fi]}
fi, no = LP.scan({}, {'deck': ('x', 'markdown')}, {'deck': {}})
r['unconf'] = {'n': len(fi), 'nc': any('NOT_CONFIGURED' in s for s in no)}
print(json.dumps(r, ensure_ascii=False))
PY
); rc=$?
[ $rc -eq 0 ] || { echo "  ❌ INSTRUMENT ERROR — lane_progression 실행 실패 (rc=$rc): $out"; exit 1; }
pn=$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['pos']['n'])" "$out")
pnm=$(python3 -c "import json,sys;print(','.join(json.loads(sys.argv[1])['pos']['named']))" "$out")
nn=$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['neg']['n'])" "$out")
un=$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['unconf']['n'])" "$out")
uc=$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['unconf']['nc'])" "$out")

[ "$pn" = "1" ]        && ok "P1 판별력: ①이 빠지면 1건 적발" || ng "P1 판별력 없음: ${pn}건 (기대 1)"
[ "$pnm" = "step1" ]   && ok "P1-b 이름 지목: step1 을 «이름으로» 짚는다" || ng "P1-b 지목 실패: '$pnm' — 판정은 맞고 처방이 틀린 게이트다"
[ "$nn" = "0" ]        && ok "P2 오탐 0" || ng "P2 오탐 ${nn}건"
{ [ "$un" = "0" ] && [ "$uc" = "True" ]; } && ok "P3 부재≠0: 선언 없으면 NOT_CONFIGURED 명시" \
  || ng "P3 실패 — 선언 없음이 «통과»로 렌더된다. 선언을 지우면 조용해지는 게이트다"

echo "progression lanes: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
