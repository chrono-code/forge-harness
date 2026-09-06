#!/usr/bin/env bash
# test_preprep_slide_refs_lanes.sh — preprep L13(리터럴 장 번호 참조)의 계약을 고정한다.
#
# WHY: 장을 빼면 뒤 번호가 통째로 당겨진다. 이웃 레인들은 «말로 가리키는 것»만 본다
# (L5/L8 화면 재사용·시각 지시 · R1~R5 접속어·소유권) — 숫자 참조는 아무도 안 봤다.
#
# 🟥 이 레인의 난점은 검출이 아니라 **분류**다. 같은 «숫자+단위»가 셋을 가리킨다:
#      SLIDE(진짜 장) · SECTION(섹션 번호) · CITATION(논문 쪽수)
#    실측 코퍼스(if(kakao) 121장)에 셋이 **전부** 있었고, SLIDE 는 **0건**이었다.
#    ⇒ 실물은 known-**negative** 만 대준다. 양성은 아래 픽스처가 댄다 — 그래서 둘 다 있다.
#
# 종료코드: 0 pass · 1 레인 실패 · 2 대상 부재 · 10 setup 실패
set -uo pipefail
cd "$(dirname "$0")/.." || exit 10
LANE=plugins/fh-commons/skills/preprep/lane_slide_refs.py
[ -f "$LANE" ] || { echo "ⓘ $LANE absent — subject missing (NOT a pass)"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ⓘ python3 absent — setup broke"; exit 10; }
python3 -c 'import pptx' 2>/dev/null || { echo "ⓘ python-pptx absent — setup broke (NOT a pass)"; exit 10; }
T=$(mktemp -d) || exit 10; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

RUN=$T/run.py
cat > "$RUN" <<'PY'
import sys, os
sys.path.insert(0, 'plugins/fh-commons/skills/preprep')
from pptx import Presentation
from pptx.util import Inches, Pt

def build(path, slides):
    """slides = [(화면 줄들, 대본)] — 화면 줄은 각각 별도 텍스트 상자."""
    prs = Presentation()
    blank = prs.slide_layouts[6]
    for scr, note in slides:
        s = prs.slides.add_slide(blank)
        for j, line in enumerate(scr):
            tb = s.shapes.add_textbox(Inches(0.5), Inches(0.5 + j*0.6), Inches(8), Inches(0.5))
            tb.text_frame.paragraphs[0].add_run().text = line
        s.notes_slide.notes_text_frame.text = note
    prs.save(path)

def scan(path, mutate=None):
    import importlib, lane_slide_refs as L
    importlib.reload(L)
    if mutate == 'kill-cite':
        L.CITE = __import__('re').compile(r'(?!x)x')          # 절대 안 맞는다
    if mutate == 'kill-section':
        L.section_numbers = lambda prs: set()
    cfg = {'surfaces_by_id': {'built_deck': {'path': path}}}
    return L.scan(cfg, '.')

if __name__ == '__main__':
    build(sys.argv[1], eval(sys.argv[2]))
    f, n = scan(sys.argv[1], sys.argv[3] if len(sys.argv) > 3 else None)
    print('FINDINGS', len(f))
    for x in f: print('F|', x[2])
    for x in n: print('N|', x)
PY

SEC=$'3. 어떻게 만들었나'
# 섹션 라벨은 «여러 장에 반복» 되어야 섹션으로 인정된다 — 픽스처도 그 조건을 만족시킨다
DECK_SEC="[(['$SEC','3장에서 게이트부터 보겠습니다'],''),(['$SEC'],''),(['$SEC'],'')]"
DECK_CITE="[(['1) Ye, 『Coding with Enemy』, arXiv:2606.05647, 2026 (4p)'],''),([''],''),([''],'')]"
DECK_DANGLING="[(['본문'],'130p 를 보세요'),(['본문'],''),(['본문'],'')]"
DECK_OK="[(['본문'],'2p 에서 보셨듯이'),(['본문'],''),(['본문'],'')]"
DECK_SELF="[(['본문'],''),(['본문'],'2p 를 보세요'),(['본문'],'')]"
DECK_DECIMAL="[(['62.5% 개선'],'62장을 보세요'),(['62.5% 개선'],''),(['본문'],'')]"
DECK_EMPTY="[(['아무 참조도 없다'],''),(['본문'],''),(['본문'],'')]"

run(){ python3 "$RUN" "$T/$1.pptx" "$2" ${3:-} 2>&1; }

echo "== L13 — 분류가 하중을 진다 =="

OUT=$(run pos "$DECK_DANGLING")
echo "$OUT" | grep -q '^FINDINGS 1' && echo "$OUT" | grep -q '범위 밖' \
  && ok "L1 known-positive: 3장 덱의 «130p» → 범위 밖 finding" \
  || ng "L1 known-positive 실패: $(echo "$OUT" | head -2 | tr '\n' ' ')"

OUT=$(run sec "$DECK_SEC")
echo "$OUT" | grep -q '^FINDINGS 0' && echo "$OUT" | grep -q 'SECTION 1' \
  && ok "L2 known-negative: 「3장에서」 = SECTION, finding 0" \
  || ng "L2 섹션이 안 갈렸다: $(echo "$OUT" | grep '^N|' | head -1)"

OUT=$(run cite "$DECK_CITE")
echo "$OUT" | grep -q '^FINDINGS 0' && echo "$OUT" | grep -q 'CITATION 1' \
  && ok "L3 known-negative: 인용 「(4p)」 = CITATION, finding 0" \
  || ng "L3 인용이 안 갈렸다: $(echo "$OUT" | grep '^N|' | head -1)"

OUT=$(run okref "$DECK_OK")
echo "$OUT" | grep -q '^FINDINGS 0' && echo "$OUT" | grep -q 'SLIDE 1' \
  && ok "L4 정상 SLIDE 참조는 노트로만(범위 안이라 finding 아님)" \
  || ng "L4 정상 참조 처리 이상: $(echo "$OUT" | grep '^N|' | head -1)"

OUT=$(run self "$DECK_SELF")
echo "$OUT" | grep -q '자기 자신 참조' \
  && ok "L5 자기 자신 참조는 ⚠️ 로 표면화(차단은 아님)" \
  || ng "L5 자기 참조가 안 뜬다"

OUT=$(run dec "$DECK_DECIMAL")
if echo "$OUT" | grep -q '^FINDINGS 1' && echo "$OUT" | grep -q '범위 밖'; then
  ok "L6 «62.5%» 를 섹션으로 안 먹는다 → 「62장」이 SLIDE 로 남아 범위 밖으로 잡힌다"
else
  ng "L6 소수점이 섹션으로 먹혔다(실측 사고 재발): $(echo "$OUT" | grep '^N|' | head -1)"
fi

OUT=$(run empty "$DECK_EMPTY")
echo "$OUT" | grep -q 'UNMEASURED' \
  && ok "L7 참조 0건 → «깨끗하다»가 아니라 UNMEASURED 로 적는다" \
  || ng "L7 0건을 통과로 읽는다(미측정≠0 위반)"

echo "== 컨트롤 — 판별자를 죽이면 빨개지는가(되돌림) =="
OUT=$(run cite2 "$DECK_CITE" kill-cite)
echo "$OUT" | grep -q '^FINDINGS 1' \
  && ok "CTRL-A 인용 판별자를 죽이면 L3 가 오탐으로 뒤집힌다(판별자가 하중을 진다)" \
  || ng "CTRL-A 뮤턴트인데 아무 일도 없다 — 인용 분기가 장식이다"

OUT=$(run sec2 "$DECK_SEC" kill-section)
echo "$OUT" | grep -q 'SLIDE 1' \
  && ok "CTRL-B 섹션 판별자를 죽이면 「3장에서」가 SLIDE 로 넘어간다" \
  || ng "CTRL-B 뮤턴트인데 분류가 그대로 — 섹션 분기가 장식이다"

echo "== 배선·퇴화 =="
OUT=$(python3 -c "
import sys; sys.path.insert(0,'plugins/fh-commons/skills/preprep')
import lane_slide_refs as L
print(L.scan({}, '.')[1][0])
print(L.scan({'surfaces_by_id':{'built_deck':{'path':'/nope/none.pptx'}}}, '.')[1][0])
" 2>&1)
echo "$OUT" | grep -q 'NOT_CONFIGURED' && echo "$OUT" | grep -q 'UNMEASURED' \
  && ok "L8 미선언 → NOT_CONFIGURED · 실물 없음 → UNMEASURED (둘 다 0 아님)" \
  || ng "L8 퇴화 표기가 0 으로 접힌다: $OUT"

grep -q "import lane_slide_refs" plugins/fh-commons/skills/preprep/preprep.py \
  && ok "L9 배선: preprep.py 가 이 레인을 부른다" \
  || ng "L9 배선 없음 — 정의만 있고 아무도 안 부른다(built-but-not-wired)"

echo "── preprep slide-refs lanes: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
