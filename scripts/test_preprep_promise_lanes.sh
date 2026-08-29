#!/usr/bin/env bash
# test_preprep_promise_lanes.sh — L11 예고↔상환 후보 레인의 앵커.
#
# 실사고: S6 이 «세 번» 을 예고했는데 본편 상환이 1건이었다. 기존 검사는 «결론이 첫 질문에
# 답하는가»만 봐서 **중반 티저의 미상환**을 구조적으로 못 잡았다.
#
# 🟥 재는 것은 «후보를 내는가» 가 아니라 **«가르는가»** 다. 둘 다 후보를 내면 판별력이 0 이고,
#    초판이 실제로 그랬다(대상어에 조사가 붙어 양쪽 다 «0회»가 나왔다).
#   Q1 판별력   같은 예고에 대해 상환 1회 vs 3회를 «다른 수»로 낸다
#   Q2 서수배제 「두 번째 …」 같은 **상환 문장**을 예고로 세지 않는다
#              — 안 거르면 방향이 거꾸로 된다(상환을 미상환 후보로 계상)
#   Q3 advisory findings 는 언제나 0 (종료코드 오염 금지)
#   Q4 판정보류 «맞나» 로 사람에게 넘기지 «틀렸다» 고 단정하지 않는다
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$HERE/plugins/fh-commons/skills/preprep"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }
command -v python3 >/dev/null 2>&1 || {
  echo "  ⚠️  UNMEASURED — python3 unavailable; promise lanes NOT run (this is not a pass)"
  echo "promise lanes: SKIPPED (not passed)"; exit 0; }

out=$(cd "$SKILL" && python3 - <<'PY' 2>&1
import sys, json, re
sys.path.insert(0, '.')
import lane_promise as L
r = {}
for k, f in (('pos', 'fixtures/promise_known_positive.md'),
             ('neg', 'fixtures/promise_known_negative.md')):
    t = open(f, encoding='utf-8').read()
    fi, no = L.scan({'s': (t, 'markdown')}, {'s': {'spoken': True}})
    rows = [x.strip() for x in no if x.strip().startswith('·')]
    cnts = [int(m.group(1)) for x in rows for m in [re.search(r'»\s*([0-9]+)회', x)] if m]
    r[k] = {'n_find': len(fi), 'n_rows': len(rows), 'counts': cnts,
            'body': ' '.join(rows)}
print(json.dumps(r, ensure_ascii=False))
PY
); rc=$?
[ $rc -eq 0 ] || { echo "  ❌ INSTRUMENT ERROR — lane_promise 실행 실패 (rc=$rc): $out"; exit 1; }
g(){ python3 -c "import json,sys;d=json.loads(sys.argv[1]);print(d[sys.argv[2]][sys.argv[3]])" "$out" "$1" "$2"; }

pc=$(g pos counts); nc=$(g neg counts)
{ [ "$pc" = "[1]" ] && [ "$nc" = "[3]" ]; } \
  && ok "Q1 판별력: 상환 1회 vs 3회를 «다른 수»로 낸다 (pos=$pc neg=$nc)" \
  || ng "Q1 판별력 없음 — pos=$pc neg=$nc. 같으면 이 레인은 아무것도 안 가른다"
{ [ "$(g pos n_rows)" = "1" ] && [ "$(g neg n_rows)" = "1" ]; } \
  && ok "Q2 서수배제: 「N 번째 …」 상환 문장을 예고로 안 센다" \
  || ng "Q2 실패 — pos=$(g pos n_rows) neg=$(g neg n_rows). 상환을 미상환 후보로 계상하면 방향이 거꾸로다"
{ [ "$(g pos n_find)" = "0" ] && [ "$(g neg n_find)" = "0" ]; } \
  && ok "Q3 advisory 불변: findings 0" || ng "Q3 깨짐 — 종료코드를 오염시킨다"
case "$(g pos body)" in *맞나*) ok "Q4 판정보류: «맞나» 로 사람에게 넘긴다" ;;
  *) ng "Q4 실패 — 단정하면 결론을 코드로 굳히는 것이다: $(g pos body)" ;; esac

echo "promise lanes: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
