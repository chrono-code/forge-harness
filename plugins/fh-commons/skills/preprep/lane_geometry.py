#!/usr/bin/env python3
"""P1·P3 — 도형 배치 검사 둘. the private companion store's origin script (lane_geometry.py(2026-09-04,
36p 사고에서 역산)를 preprep 관례로 이식한 것 — 로직은 그대로다.
정본: `tracks-meta/fh_signal_2026-09-04_preprep-evolution.md` §2.

  P1 build-jitter   같은 이름의 도형이 «연속한 두 장»에서 조금 다른 자리에 있다
                    → 넘길 때 튄다. 실사고: 노란 게이트 막대가 직전 장 대비 35,000 EMU 밀려
                      회색 연결선과 겹쳤다. 큰 차이는 «의도한 이동»이라 제외한다.
  P3 adjacency      한 도형의 «오른쪽 끝»과 다른 도형의 «왼쪽 끝»이 맞닿으려다 어긋났다
                    → 실제 결함이 이 형태였다(회색 스텁 끝 ↔ 막대 시작, 35,000 겹침).

🟥 **P2(near-miss, 같은 종류 모서리끼리만 대조)는 미포함이다 — 채택하지 않는다.** 실사고가
   못 잡히는 이유가 설계 근거였다: 실제 결함은 「회색 스텁 오른쪽 끝 ↔ 막대 왼쪽 끝」이라는
   **다른 종류** 모서리의 인접 관계인데, P2 는 왼↔왼·오른↔오른만 봐서 구조적으로 못 잡는다.
   그 관계는 P3 가 이미 덮는다. 새 레인을 짤 때 «같은 종류끼리»가 기본값이라는 것을 의심하라.

🟥 둘 다 advisory. 임계는 사람이 정한다(기본 JIT=200,000 EMU · ALN=63,500 EMU=5pt ·
   1pt=12,700 EMU). `surfaces.yaml` 의 `geometry.jitter_emu` / `geometry.align_emu` 로 바꾼다.
🟥 «차이 0» 은 정상이고 «차이 큼» 도 정상이다. 이 검사가 보는 것은 그 사이뿐이다.

## 🟥 목록으로 읽지 마라 — 델타로 읽어라

실측: P3 는 원 코퍼스에서 기저 오탐이 76건이다(아이콘 무리 내부 · 맵 라벨의 «의도된» 겹침).
그 목록에서 진짜를 골라낼 방법이 없다. 그런데 편집 전/후를 대조하면 **차이가 정확히 그
한 줄**이었다. ⇒ 절대 목록은 회귀 도구로 못 쓰고 **편집 전후 델타는 정확하다.**
`surfaces.yaml` 의 `geometry.baseline`(이전 판 pptx 경로)이 있으면 이 레인은 델타 모드로 돈다
— 「지금 몇 건이냐」가 아니라 «내가 방금 뭘 어긋냈냐»를 묻는 회귀 도구다.

## 🟥 P1 이 «비교 안 함»을 «튐 없음»으로 속일 수 있는 자리 (계기 결함, 미리 적는다)

`shapes()` 는 **한 장 안에서 이름이 겹치는 도형을 통째로 버린다**(`len(v) == 1` 만 남긴다) —
겹치는 이름끼리는 대조할 대상을 하나로 못 정하기 때문이다. python-pptx 기본 이름
(`TextBox 1` 류)은 장마다 새로 매겨져 **이름이 우연히 안 겹칠 수 있고**, 대조 자체가 0건이
되는 입력에서도 「후보 0건」이 똑같이 출력된다 — 그 0 은 **「튐 없음」이 아니라 「비교 안 함」**
이다(이 저장소가 이름 붙인 「레인이 초록인 이유는 셋」의 ②). ⇒ `scan()` 은 **비교된 도형-쌍
수**를 항상 같이 낸다 — 0 이면 UNMEASURED 로 읽어야 한다는 뜻이다.
"""
import zipfile, re, os, collections

EMU_PT = 12700


def shapes(z, sn):
    """한 슬라이드의 도형을 {이름: (x,y,cx,cy,text)} 로. 이름 중복은 대조 못 하니 뺀다."""
    x = z.read('ppt/slides/slide%d.xml' % sn).decode('utf-8')
    out = {}
    for m in re.finditer(r'<p:(sp|cxnSp)>.*?</p:\1>', x, re.S):
        b = m.group(0)
        nm = re.search(r'name="([^"]*)"', b)
        o = re.search(r'<a:off x="(-?\d+)" y="(-?\d+)"/><a:ext cx="(-?\d+)" cy="(-?\d+)"', b)
        if not (nm and o):
            continue
        t = re.sub(r'\s+', ' ', ' '.join(re.findall(r'<a:t>([^<]*)</a:t>', b))).strip()
        out.setdefault(nm.group(1), []).append(
            (int(o.group(1)), int(o.group(2)), int(o.group(3)), int(o.group(4)), t))
    return {k: v[0] for k, v in out.items() if len(v) == 1}


def _order(z):
    rels = dict(re.findall(r'Id="([^"]+)"[^>]*Target="slides/slide(\d+)\.xml"',
                            z.read('ppt/_rels/presentation.xml.rels').decode('utf-8')))
    lst = re.search(r'<p:sldIdLst>.*?</p:sldIdLst>',
                     z.read('ppt/presentation.xml').decode('utf-8'), re.S).group(0)
    return [int(rels[r]) for r in re.findall(r'<p:sldId id="\d+" r:id="([^"]+)"/>', lst)]


def load_slides(path):
    z = zipfile.ZipFile(path)
    return [shapes(z, sn) for sn in _order(z)]


def p1_lines(S, JIT):
    """build-jitter 후보. 반환: (lines, compared) — compared=0 이면 대조 대상이 아예 없었다는
    뜻이라 «튐 0건»과 «UNMEASURED」를 갈라야 한다."""
    lines, compared = [], 0
    for i in range(1, len(S)):
        for nm, cur in S[i].items():
            prv = S[i - 1].get(nm)
            if not prv:
                continue
            compared += 1
            d = [cur[k] - prv[k] for k in range(4)]
            mx = max(abs(v) for v in d)
            if 0 < mx <= JIT:
                lab = ['x', 'y', 'cx', 'cy']
                moved = ' · '.join(f'{lab[k]} {d[k]:+d}' for k in range(4) if d[k])
                lines.append(f"   {i:>3}p→{i+1:<3}p {nm[:16]:16} {moved}  ({mx/EMU_PT:.2f}pt)  "
                             f"«{cur[4][:26]}»")
    return lines, compared


def p3_lines(S, ALN):
    """adjacency 후보 — A 오른쪽 끝 ↔ B 왼쪽 끝, 세로로 겹치는 띠에 있을 때만."""
    lines = []
    for i, sh in enumerate(S):
        items = [(nm, v) for nm, v in sh.items() if v[2] > 0 and v[3] > 0]
        for a in range(len(items)):
            for b in range(len(items)):
                if a == b:
                    continue
                na, va = items[a]
                nb, vb = items[b]
                oy = min(va[1] + va[3], vb[1] + vb[3]) - max(va[1], vb[1])
                if oy <= 0:
                    continue
                gap = vb[0] - (va[0] + va[2])  # A 오른쪽 → B 왼쪽
                if 0 < abs(gap) <= ALN:
                    kind = '겹침' if gap < 0 else '틈'
                    lines.append(f"   {i+1:>3}p {na[:14]:14} 오른끝 → {nb[:14]:14} 왼끝  "
                                 f"{kind} {abs(gap):>6} EMU ({abs(gap)/EMU_PT:.2f}pt)")
    return lines


def collect_lines(path, JIT, ALN):
    """(lines, compared) — P1+P3 합친 후보 줄과, P1 이 실제로 대조한 도형-쌍 수."""
    S = load_slides(path)
    l1, compared = p1_lines(S, JIT)
    l3 = p3_lines(S, ALN)
    return l1 + l3, compared


def delta(base_path, cur_path, JIT, ALN):
    """편집 전/후 델타 — 절대 목록이 아니라 **차이**로 읽는 용법(정확했던 것). P3 는 SYS 를 안 쓰니
    양쪽에 같은 규칙을 그대로 적용하면 된다(계기 자기결함이 P2 전용이라 여기 안 옮는다)."""
    bl, cmp_b = collect_lines(base_path, JIT, ALN)
    cur, cmp_c = collect_lines(cur_path, JIT, ALN)
    b = set(bl)
    new = [l for l in cur if l not in b]
    gone = [l for l in bl if l not in set(cur)]
    return new, gone, cmp_b, cmp_c


def _resolve(root, p):
    return os.path.normpath(os.path.join(root, os.path.expanduser(p)))


def scan(cfg, root):
    """preprep.py 가 부르는 레인 진입점. (findings, notes) — 🟥 **advisory 고정**:
    호출자는 findings 를 버리고 notes 만 취한다(L8·L11 관례)."""
    deck_s = (cfg.get('surfaces_by_id') or {}).get('built_deck')
    if not deck_s:
        return [], ['P1/P3 geometry : built_deck 미선언 — NOT_CONFIGURED (0 아님)']
    deck = _resolve(root, deck_s['path'])
    if not os.path.exists(deck):
        return [], [f'P1/P3 geometry : built_deck 실물 없음({deck}) — UNMEASURED (0 아님)']
    spec = cfg.get('geometry') or {}
    JIT = int(spec.get('jitter_emu', 200000))
    ALN = int(spec.get('align_emu', 63500))
    base_p = spec.get('baseline')
    notes = []

    if base_p:
        base = _resolve(root, base_p)
        if not os.path.exists(base):
            return [], [f'P1/P3 geometry : baseline 실물 없음({base}) — UNMEASURED (0 아님)']
        try:
            new, gone, cmp_b, cmp_c = delta(base, deck, JIT, ALN)
        except Exception as e:
            return [], [f'P1/P3 geometry : 계기 오류({type(e).__name__}: {e}) — UNMEASURED (0 아님)']
        notes.append(f'P1/P3 geometry(델타) : 기준 {os.path.basename(base)} 대비 '
                     f'새 어긋남 {len(new)}건 · 사라진 어긋남 {len(gone)}건 🟥 advisory '
                     f'(P1 대조된 도형-쌍: 기준 {cmp_b} · 현재 {cmp_c}'
                     + ('' if cmp_b and cmp_c else ' — 🟥 0건이면 UNMEASURED, 「튐 없음」이 아니다') + ')')
        for l in new:
            notes.append('   + ' + l.strip())
        for l in gone:
            notes.append('   - ' + l.strip())
        return [], notes

    try:
        lines, compared = collect_lines(deck, JIT, ALN)
    except Exception as e:
        return [], [f'P1/P3 geometry : 계기 오류({type(e).__name__}: {e}) — UNMEASURED (0 아님)']
    notes.append(f'P1/P3 geometry(목록) : 후보 {len(lines)}건 — 🟥 절대 목록으로 읽지 마라, '
                 f'P3 기저 오탐이 코퍼스마다 수십 건일 수 있다(원 코퍼스 실측 76건). '
                 f'`geometry.baseline` 을 쓰는 편집-델타 용법이 정확하다 '
                 f'(P1 대조된 도형-쌍 {compared}'
                 + ('' if compared else ' — 🟥 UNMEASURED, 「튐 없음」이 아니다') + ')')
    for l in lines:
        notes.append(l)
    return [], notes
