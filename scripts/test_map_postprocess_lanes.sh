#!/usr/bin/env bash
# test_map_postprocess_lanes.sh — scripts/map_postprocess.py 의 두 계약을 고정한다.
#
# WHY: 이 후처리는 발행되는 지도 HTML 의 «폭 하한»을 바꾸고 SVG 를 다시 만든다. 둘 다 조용히
# 실패하면 사람이 못 본다 — 패치가 안 붙어도 페이지는 뜨고(옛 폭), SVG 가 어긋나도 열리기는 한다.
# 그래서 ⓐ 리터럴 부재 = 드리프트 = 하드 정지(3), ⓑ SVG 는 «커밋된 두 장 바이트 동일 재현»을
# known-pair 로 잡는다. 컨트롤: 패치 문자열이 실제로 상수와 다르고 뷰포트를 참조하는가.
#
# 종료코드: 0 pass · 1 레인 실패 · 2 대상 부재 · 10 setup 실패
set -uo pipefail
cd "$(dirname "$0")/.." || exit 10
S=scripts/map_postprocess.py
PASS=0; FAIL=0
ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

[ -f "$S" ] || { echo "ⓘ $S absent — subject missing when we looked (NOT a pass)"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ⓘ python3 absent — setup broke (NOT a pass)"; exit 10; }

TMP=$(mktemp -d) || exit 10
trap 'rm -rf "$TMP"' EXIT

mkfix() {  # $1=out path, $2=reader-width literal line (may be empty), $3=extra style blocks
  {
    printf '<html><head><style>.a{color:red}</style>'
    [ -n "${3:-}" ] && printf '<style>.b{color:blue}</style>'
    printf '</head><body>'
    printf '<svg viewBox="0 0 10 10"><rect/></svg>'
    printf '<script>%s</script></body></html>' "$2"
  } > "$1"
}

# ── L1 known-positive: 상수가 있으면 패치되고 SVG 가 나온다
mkfix "$TMP/pos.html" 'var MIN_READER_WIDTH = 960;' ''
python3 "$S" "$TMP/pos.html" >"$TMP/o1" 2>&1; RC=$?
if [ $RC -eq 0 ] && /usr/bin/grep -q 'window.innerWidth' "$TMP/pos.html" && [ -f "$TMP/pos.svg" ]; then
  ok "L1 known-positive: patched + svg written (rc=0)"
else
  ng "L1 known-positive failed (rc=$RC): $(head -2 "$TMP/o1" | tr '\n' ' ')"
fi

# ── L2 멱등: 두 번째 실행은 SKIP 이고 여전히 rc=0
python3 "$S" "$TMP/pos.html" >"$TMP/o2" 2>&1; RC=$?
if [ $RC -eq 0 ] && /usr/bin/grep -q 'SKIP' "$TMP/o2"; then
  ok "L2 idempotent re-run reports SKIP (rc=0)"
else
  ng "L2 idempotency broken (rc=$RC): $(head -2 "$TMP/o2" | tr '\n' ' ')"
fi

# ── L3 known-negative(드리프트): 리터럴이 아예 없으면 rc=3 이고 파일을 안 건드린다
mkfix "$TMP/drift.html" 'var SOMETHING_ELSE = 1;' ''
BEFORE=$(shasum "$TMP/drift.html" | awk '{print $1}')
python3 "$S" "$TMP/drift.html" >"$TMP/o3" 2>&1; RC=$?
AFTER=$(shasum "$TMP/drift.html" | awk '{print $1}')
if [ $RC -eq 3 ] && [ "$BEFORE" = "$AFTER" ] && [ ! -f "$TMP/drift.svg" ]; then
  ok "L3 drift → rc=3, file untouched, no svg (fail-closed)"
else
  ng "L3 drift not fail-closed (rc=$RC, sha changed=$([ "$BEFORE" = "$AFTER" ] && echo no || echo yes))"
fi

# ── L4 컨트롤: 패치 문자열이 상수와 실제로 다르고 뷰포트를 참조하는가
#    (같은 값으로 «치환»하면 L1 도 통과한다 — 그 자멸을 막는 자리)
OLDLIT=$(python3 -c "import re;s=open('$S',encoding='utf-8').read();print(re.search(r\"^OLD = '(.*)'\",s,re.M).group(1))")
NEWLIT=$(python3 -c "
import re
s=open('$S',encoding='utf-8').read()
m=re.search(r\"NEW = \((.*?)\)\n\", s, re.S)
print(''.join(re.findall(r\"'([^']*)'\", m.group(1))))")
if [ -n "$OLDLIT" ] && [ -n "$NEWLIT" ] && [ "$OLDLIT" != "$NEWLIT" ] && \
   printf '%s' "$NEWLIT" | /usr/bin/grep -q 'innerWidth'; then
  ok "L4 control: replacement differs from the constant and reads the viewport"
else
  ng "L4 control: replacement is vacuous (old='$OLDLIT' new='$NEWLIT')"
fi

# ── L5 known-pair: 커밋된 지도 두 장을 HTML 에서 바이트 동일하게 재현하는가
#    (SVG 는 <style>+<svg> 만 담아 뷰어 JS 를 안 싣는다 — 그래서 폭 패치와 무관하게 안정적인 짝이다)
PAIR_OK=1; PAIR_RAN=0
for base in docs/map/fh_trust.dataflow docs/map/fh_assets.architecture; do
  [ -f "$base.html" ] && [ -f "$base.svg" ] || continue
  PAIR_RAN=$((PAIR_RAN+1))
  python3 - "$S" "$base.html" "$base.svg" <<'PY' || PAIR_OK=0
import importlib.util, sys
spec = importlib.util.spec_from_file_location('mp', sys.argv[1])
mp = importlib.util.module_from_spec(spec); spec.loader.exec_module(mp)
built = mp.build_svg(open(sys.argv[2], encoding='utf-8').read())
cur = open(sys.argv[3], encoding='utf-8').read()
if built != cur:
    print(f'   ✗ {sys.argv[3]}: rebuilt {len(built)}B != committed {len(cur)}B')
    sys.exit(1)
PY
done
if [ "$PAIR_RAN" -eq 0 ]; then
  ng "L5 known-pair: 0 pairs found — instrument had nothing to measure (NOT a pass)"
elif [ "$PAIR_OK" -eq 1 ]; then
  ok "L5 known-pair: $PAIR_RAN committed svg(s) reproduced byte-for-byte from html"
else
  ng "L5 known-pair: rebuilt svg differs from the committed one"
fi

# ── L6 <style> 블록이 둘이면 추출기는 멈춘다(조용히 첫 장만 싣지 않는다)
mkfix "$TMP/two.html" 'var MIN_READER_WIDTH = 960;' 'extra'
python3 "$S" "$TMP/two.html" >"$TMP/o6" 2>&1; RC=$?
if [ $RC -eq 3 ] && [ ! -f "$TMP/two.svg" ]; then
  ok "L6 two <style> blocks → rc=3, no svg written"
else
  ng "L6 two <style> blocks not rejected (rc=$RC)"
fi

# ── L7 없는 파일 → rc=4 (인자 오류와 드리프트를 섞지 않는다)
python3 "$S" "$TMP/nope.html" >"$TMP/o7" 2>&1; RC=$?
[ $RC -eq 4 ] && ok "L7 missing file → rc=4 (distinct from drift rc=3)" || ng "L7 missing file rc=$RC (expected 4)"

# ── L8 --check 는 쓰지 않는다
mkfix "$TMP/chk.html" 'var MIN_READER_WIDTH = 960;' ''
B=$(shasum "$TMP/chk.html" | awk '{print $1}')
python3 "$S" --check "$TMP/chk.html" >"$TMP/o8" 2>&1; RC=$?
A=$(shasum "$TMP/chk.html" | awk '{print $1}')
if [ $RC -eq 0 ] && [ "$B" = "$A" ] && /usr/bin/grep -q 'UNPATCHED' "$TMP/o8" && [ ! -f "$TMP/chk.svg" ]; then
  ok "L8 --check reports without writing"
else
  ng "L8 --check wrote or misreported (rc=$RC)"
fi

# ── L9 발행본이 실제로 패치된 상태인가 (배선 확인 — 스크립트가 있는데 안 돌린 경우를 잡는다)
SHIPPED_OK=1; SHIPPED_N=0
for f in docs/map/*.html; do
  [ -f "$f" ] || continue
  case "$f" in *.visual-check.html) continue;; esac
  SHIPPED_N=$((SHIPPED_N+1))
  python3 "$S" --check "$f" 2>/dev/null | /usr/bin/grep -q '^PATCHED' || { SHIPPED_OK=0; echo "   ✗ $f not patched"; }
done
if [ "$SHIPPED_N" -eq 0 ]; then
  ng "L9 no docs/map/*.html found — nothing measured (NOT a pass)"
elif [ "$SHIPPED_OK" -eq 1 ]; then
  ok "L9 all $SHIPPED_N shipped map html carry the patched reader-width floor"
else
  ng "L9 a shipped map html is unpatched — re-run: python3 $S docs/map/*.html"
fi

echo "── map_postprocess lanes: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
