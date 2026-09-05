#!/usr/bin/env bash
# test_fh_map_paths_lanes.sh — docs/map 지도의 «노드 = 실재 경로» 계약을 test -e 로 고정한다.
#
# WHY: docs/map/fh_assets.architecture.json 의 각 컴포넌트는 sublabel/tag 에 레포 상대 경로를 적고,
# FH_MAP.md ②층은 «그림의 노드 전부가 실재 파일이다» 라고 주장한다. 파일이 옮겨지거나 지워지면
# 그림은 조용히 거짓이 된다 — 그래서 매번 다시 센다. 부재 0 이 아니면 빨갛다.
# 선례: qasp-dev tests/test_map_paths_exist.py (pytest). FH 관례는 bash 레인이라 같은 계약을 bash 로 쓴다.
#
# 종료코드는 selfcheck.sh 규약: 0 = pass · 1 = 레인 실패 · 2 = 대상(지도 소스) 부재 · 10 = 이 스위트 setup 실패
set -uo pipefail
cd "$(dirname "$0")/.." || exit 10
MAP=docs/map/fh_assets.architecture.json
PASS=0; FAIL=0
ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

[ -f "$MAP" ] || { echo "ⓘ $MAP absent — subject missing when we looked (NOT a pass)"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ⓘ python3 absent — this suite's own setup broke (NOT a pass)"; exit 10; }

# 컴포넌트별 (id<TAB>path) — 경로 토큰 = 알려진 최상위 디렉토리/파일로 시작하는 것만
PAIRS="$(python3 - "$MAP" <<'PY'
import json,re,sys
doc=json.load(open(sys.argv[1],encoding='utf-8'))
rx=re.compile(r'(?:scripts|plugins|templates|knowledge|docs|bin|tests|\.claude|\.github)/[\w./\-]+|(?:CLAUDE|AGENTS|README|CATALOG|CHEATSHEET)\.md')
for c in doc['components']:
    found=set()
    for k in ('sublabel','tag'):
        for m in rx.findall(c.get(k,'')): found.add(m.rstrip('.'))
    if not found: print(f"{c['id']}\t<NONE>")
    for p in sorted(found): print(f"{c['id']}\t{p}")
PY
)" || { echo "ⓘ JSON parse failed — this suite's own setup broke (NOT a pass)"; exit 10; }

# L1 — 모든 컴포넌트가 경로를 하나 이상 싣는가 (계약 자체)
NONE=$(printf '%s\n' "$PAIRS" | awk -F'\t' '$2=="<NONE>"{print $1}')
[ -z "$NONE" ] && ok "L1 every component carries a repo path" || ng "L1 components without a path (contract violation): $(echo "$NONE" | tr '\n' ' ')"

# L2 — 경로 전수 test -e
TOTAL=0; MISSING=0
while IFS=$'\t' read -r cid rel; do
  [ -n "$rel" ] && [ "$rel" != "<NONE>" ] || continue
  TOTAL=$((TOTAL+1))
  if [ -e "$rel" ]; then :; else MISSING=$((MISSING+1)); echo "   ✗ node '$cid' → $rel (absent)"; fi
done <<< "$PAIRS"
[ "$TOTAL" -gt 0 ] || { echo "ⓘ 0 paths extracted — extractor broke, not a pass"; exit 10; }
[ "$MISSING" -eq 0 ] && ok "L2 node paths exist: $TOTAL/$TOTAL (missing 0)" || ng "L2 node paths missing: $MISSING of $TOTAL"

# L3 — known-negative: 계기가 부재를 «볼 수 있나» (없는 경로를 하나 넣어 빨개지는지)
if [ -e "scripts/__fh_map_lane_nonexistent__.sh" ]; then ng "L3 control path unexpectedly exists"; else ok "L3 control: a fabricated path is reported absent (instrument discriminates)"; fi

# L4 — 사설 토큰 0: 지도 산출물에 절대 홈 경로가 없다 (residency 정책의 기계 반쪽)
# 소스 4개만 본다 — visual-check 사이드카(*.visual-check.json)는 절대경로를 품는 로컬 산물이라 대상이 아니다(커밋 대상도 아님)
HITS=$(grep -l -E '/Users/[A-Za-z0-9_.-]+/' docs/map/fh_process.workflow.json docs/map/fh_assets.architecture.json docs/map/fh_trust.dataflow.json docs/map/FH_MAP.md 2>/dev/null | wc -l | tr -d ' ')
[ "$HITS" -eq 0 ] && ok "L4 no absolute home paths in docs/map sources" || ng "L4 absolute home path found in $HITS docs/map file(s)"

echo "test_fh_map_paths_lanes: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
