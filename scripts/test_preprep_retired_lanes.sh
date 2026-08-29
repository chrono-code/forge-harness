#!/usr/bin/env bash
# test_preprep_retired_lanes.sh — L1-c 폐어(retired) 갈래의 회귀 앵커.
#
# 실사고: 리뷰가 명시적으로 걷어낸 「재다」가 4개월 뒤 재유입됐고 **아무 검사도 안 울렸다**
# (운영자가 잡았다). jargon_terms=조어→풀이, banned=수치 인용 금지라 «걷어낸 말» 자리가 없었다.
#
# 재는 것 넷:
#   R1 판별력   폐어가 산출물에 «쓰이면» RETIRED 로 잡나
#   R2 오탐 0   대체어로 바꾸면 조용한가
#   R3 자기신고 🟥 «「재다」는 걷어낸 낱말이다» 라고 «적은» 줄은 위반이 아니라 mention 인가
#              — 이게 없으면 폐어 원장이 자기를 위반으로 신고한다
#   R4 처방     대체어를 finding 에 싣나 (처방 없는 판정은 절반이다)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$HERE/plugins/fh-commons/skills/preprep"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }
command -v python3 >/dev/null 2>&1 || {
  echo "  ⚠️  UNMEASURED — python3 unavailable; retired lanes NOT run (this is not a pass)"
  echo "retired lanes: SKIPPED (not passed)"; exit 0; }

out=$(cd "$SKILL" && python3 - <<'PY' 2>&1
import sys, os, json, yaml, tempfile
sys.path.insert(0, '.')
import preprep as P
spec = {'banned': [], 'conditional': [], 'retired': [
    {'id': 'measure-verb', 'literals': ['재다'], 'replacement': '측정하다',
     'why': '리뷰가 걷어낸 어휘', 'retired_by': 'review', 'retired_at': '2026-08-25'}]}
d = tempfile.mkdtemp(); sp = os.path.join(d, 't.yaml')
yaml.safe_dump(spec, open(sp, 'w', encoding='utf-8'), allow_unicode=True)
cfg = {'canon_terms': sp, 'canon_ledger': os.path.join(d, 'absent.md')}
r = {}
for k, body in (('use', '🗣\n> 그것을 재다 보면 압니다.\n'),
                ('repl', '🗣\n> 그것을 측정하다 보면 압니다.\n'),
                ('ment', '> 🚫 「재다」는 걷어낸 낱말이다. 쓰지 마라.\n')):
    f, _ = P.lane_canon(cfg, '.', {'s': (body, 'markdown')}, {'s': {'spoken': True}})
    r[k] = {'tags': [x[1] for x in f], 'msg': ' '.join(x[4] for x in f if x[1] == 'RETIRED')}
print(json.dumps(r, ensure_ascii=False))
PY
); rc=$?
[ $rc -eq 0 ] || { echo "  ❌ INSTRUMENT ERROR — lane_canon 실행 실패 (rc=$rc): $out"; exit 1; }
g(){ python3 -c "import json,sys;d=json.loads(sys.argv[1]);print(d[sys.argv[2]][sys.argv[3]])" "$out" "$1" "$2"; }

[ "$(g use tags)" = "['RETIRED']" ] && ok "R1 판별력: 폐어 재유입을 RETIRED 로 잡는다" \
  || ng "R1 판별력 없음: $(g use tags)"
[ "$(g repl tags)" = "[]" ] && ok "R2 오탐 0: 대체어로 바꾸면 조용" || ng "R2 오탐: $(g repl tags)"
[ "$(g ment tags)" = "['mention']" ] && ok "R3 자기신고 방지: 폐어를 «적은» 줄은 mention" \
  || ng "R3 실패: $(g ment tags) — 폐어 원장이 자기를 위반으로 신고한다"
case "$(g use msg)" in *측정하다*) ok "R4 처방: 대체어를 finding 에 싣는다" ;;
                       *) ng "R4 실패 — 처방 없는 판정이다: $(g use msg)" ;; esac

echo "retired lanes: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
