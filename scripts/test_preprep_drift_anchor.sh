#!/usr/bin/env bash
# test_preprep_drift_anchor.sh — 이원화의 단일-소스 앵커.
#
# preprep 은 두 진입점을 갖는다: FH 안의 스킬(plugins/fh-commons/skills/preprep/)과,
# 거기서 뽑아 세우는 standalone 현장 하네스. 🟥 **코드 사본이 둘이면 갈린다** —
# FH 자신의 규칙이 그것을 «single source of truth collapse · double maintenance burden»
# 이라 부른다. 그래서 이원화는 «복사본 둘»이 아니라 «단일 소스 + 얇은 두 진입점»이어야 하고,
# 이 앵커가 그 «단일»을 기계로 지킨다.
#
# 재는 것:
#   D1 단일 소스가 실재하고 실행 가능한가 (부재를 통과로 렌더하지 않는다)
#   D2 standalone 배포본이 있다면, 그 코드가 단일 소스와 «바이트 동일»한가
#      — 없으면 SKIP 이고 SKIP 은 PASS 가 아니다. 있는데 다르면 FAIL
#   D3 진입점 문서가 단일 소스를 가리키나 (죽은 포인터 금지)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$HERE/plugins/fh-commons/skills/preprep"
# standalone 배포 위치는 환경변수로 받는다. 기본값을 박으면 다른 머신에서 거짓 SKIP 이 된다.
DIST="${PREPREP_STANDALONE_DIR:-}"
PASS=0; FAIL=0; SKIP=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }
sk(){ echo "  ⏭  $1 — SKIPPED (**통과 아님**)"; SKIP=$((SKIP+1)); }

# D1 — 단일 소스
missing=""
for f in preprep.py interslide_deps.py SKILL.md README.md surfaces.example.yaml; do
  [ -f "$SRC/$f" ] || missing="$missing $f"
done
if [ -n "$missing" ]; then ng "D1 단일 소스 결손:$missing"
elif ! command -v python3 >/dev/null 2>&1; then
  sk "D1 구문 검사 — python3 부재라 «돌 수 있나»를 못 쟀다(UNMEASURED)"
else
  synerr=""
  for f in preprep.py interslide_deps.py; do
    python3 -c "import ast,sys;ast.parse(open(sys.argv[1],encoding='utf-8').read())" "$SRC/$f" 2>/dev/null || synerr="$synerr $f"
  done
  [ -z "$synerr" ] && ok "D1 단일 소스 5파일 실재 + python 2파일 구문 통과" \
                   || ng "D1 구문 실패:$synerr"
fi

# D2 — standalone 대조
if [ -z "$DIST" ]; then
  sk "D2 standalone 대조 — PREPREP_STANDALONE_DIR 미설정이라 배포본을 못 찾았다"
elif [ ! -d "$DIST" ]; then
  ng "D2 PREPREP_STANDALONE_DIR 이 가리키는 곳이 없다: $DIST (설정됐는데 부재 = 드리프트 아니라 배선 결함)"
else
  drift=""
  for f in preprep.py interslide_deps.py; do
    if [ ! -f "$DIST/$f" ]; then drift="$drift $f(부재)"
    elif ! cmp -s "$SRC/$f" "$DIST/$f"; then drift="$drift $f(갈림)"; fi
  done
  [ -z "$drift" ] && ok "D2 standalone 코드 2파일이 단일 소스와 바이트 동일" \
                  || ng "D2 드리프트:$drift ⇒ 사본이 둘이 됐다. 단일 소스에서 다시 뽑아라"
fi

# D3 — 진입점 포인터가 죽었나
if grep -q "ko-tech-writer" "$SRC/SKILL.md" 2>/dev/null; then
  if [ -f "$HERE/plugins/fh-commons/skills/ko-tech-writer/SKILL.md" ]; then
    ok "D3 SKILL.md 가 가리키는 ko-tech-writer 가 실재"
  else ng "D3 죽은 포인터 — SKILL.md 가 ko-tech-writer 를 가리키는데 그 스킬이 없다"; fi
else ng "D3 SKILL.md 가 ko-tech-writer 라우팅을 잃었다 — L9 는 절반만 덮는데 나머지 절반의 출구가 사라졌다"; fi

echo "preprep drift anchor: $PASS passed, $FAIL failed, $SKIP skipped (skip != pass)"
[ "$FAIL" -eq 0 ] || exit 1
