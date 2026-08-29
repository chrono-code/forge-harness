#!/usr/bin/env bash
# test_preprep_adjacent_dup_lanes.sh — L10 인접 장 중복 낭독 앵커.
#
# 실사고: 한 장을 두 프레임으로 쪼갤 때 뒤 프레임에 원본을 **통째로** 남겨
# 117자 중 82자(70%)가 중복이었다. 앞 장에서 이미 읽은 문장을 다시 읽는다.
#
# 재는 것 넷:
#   J1 판별력   원본을 통째로 남기면 잡나
#   J2 오탐 0   제대로 쪼개면 조용한가
#   J3 임계분리 임계 미기재면 «재기만 하고 판정 안 함» 인가 (구조=A · 값=B 분리)
#   J4 처방     몇 자 / 몇 % / 어느 문장인지를 내나 — 숫자 없는 지적은 처방이 아니다
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$HERE/plugins/fh-commons/skills/preprep"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }
command -v python3 >/dev/null 2>&1 || {
  echo "  ⚠️  UNMEASURED — python3 unavailable; adjacent-dup lanes NOT run (this is not a pass)"
  echo "adjacent-dup lanes: SKIPPED (not passed)"; exit 0; }

out=$(cd "$SKILL" && python3 - <<'PY' 2>&1
import sys, json, importlib.util as ilu
sys.path.insert(0, '.')
import lane_adjacent_dup as L
sp = ilu.spec_from_file_location('i', 'interslide_deps.py'); im = ilu.module_from_spec(sp); sp.loader.exec_module(im)
lim = {'adjacent_dup': {'max_dup_chars': 30}}
r = {}
for k, f, cfg in (('pos', 'fixtures/adjdup_known_positive.md', lim),
                  ('neg', 'fixtures/adjdup_known_negative.md', lim),
                  ('nolim', 'fixtures/adjdup_known_positive.md', {})):
    t = open(f, encoding='utf-8').read()
    fi, no = L.scan(cfg, {'s': (t, 'markdown')}, {'s': {'spoken': True}}, im)
    r[k] = {'n': len(fi), 'msg': ' '.join(x[4] for x in fi),
            'nolim_note': any('임계 미기재' in x for x in no)}
print(json.dumps(r, ensure_ascii=False))
PY
); rc=$?
[ $rc -eq 0 ] || { echo "  ❌ INSTRUMENT ERROR — lane_adjacent_dup 실행 실패 (rc=$rc): $out"; exit 1; }
g(){ python3 -c "import json,sys;d=json.loads(sys.argv[1]);print(d[sys.argv[2]][sys.argv[3]])" "$out" "$1" "$2"; }

[ "$(g pos n)" = "1" ] && ok "J1 판별력: 원본 통째 남김을 잡는다" || ng "J1 판별력 없음: $(g pos n)건"
[ "$(g neg n)" = "0" ] && ok "J2 오탐 0: 제대로 쪼개면 조용" || ng "J2 오탐 $(g neg n)건"
{ [ "$(g nolim n)" = "0" ] && [ "$(g nolim nolim_note)" = "True" ]; } \
  && ok "J3 임계분리: 미기재면 재기만 하고 판정 안 한다" \
  || ng "J3 실패 — 임계를 코드에 박았거나, 미기재를 조용히 통과시킨다"
# 🟥 J4 의 초판은 glob `*%*자*` 였는데 **되돌림 프로브가 그걸 뚫었다** — 숫자를 지워도 남은
#    문자열에 «자» 와 «%» 가 우연히 들어 있어 통과했다. 장식 앵커였다.
#    지금은 «숫자 + 단위» 를 정규식으로 요구한다: `NN자` 와 `NN%` 가 둘 다 있어야 한다.
if printf '%s' "$(g pos msg)" | grep -qE '[0-9]+자' && printf '%s' "$(g pos msg)" | grep -qE '[0-9]+%'; then
  ok "J4 처방: «NN자»·«NN%» 를 실제 숫자로 낸다"
else
  ng "J4 실패 — 숫자 없는 지적은 처방이 아니다: $(g pos msg)"
fi

echo "adjacent-dup lanes: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
