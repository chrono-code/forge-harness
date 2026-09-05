#!/usr/bin/env python3
"""diagram_from_json.py — 타입 있는 JSON 한 장 → 검증된 다이어그램 PNG(장표용) + 굽기 영수증.

⑤ 제작·퇴고 단계의 «도해» 갈래. 도해를 영점부터 그리는 시행착오를 줄이는 자리다(SKILL.md §제작 흐름).

파이프라인 (한 번에, 중간 산출은 전부 남긴다):
  JSON ──archify validate(showcase)──▶ 못 통과 = **굽기 거부(exit 1)**, PNG 를 안 만든다
       ──archify deliver───────────▶ <out>.html (뷰어 포함 정본 산출)
       ──SVG 단독 추출 + 토큰 CSS──▶ headless Chrome 스크린샷 <out>.png (뷰어 크롬 0)
       ──해상도 하한·여백·viewBox 폭 검사──▶ <out>.receipt.json (레인 L12 가 읽는 채널)

🟥 archify 소스는 복사하지 않는다 — 외부 렌더러(MIT)를 **쓴다**. 위치는 --archify 또는
   $PREPREP_ARCHIFY_BIN, 없으면 cwd 기준 .claude/skills/archify/bin/archify.mjs.
🟥 해상도 하한: 장표 폭 26.67in(1920pt) 기준 2× = 3840px. 미달이면 굽기 거부.
🟥 viewBox 폭 상한(기본 720): archify 는 글자 크기 토큰이 없어 **viewBox 폭이 pt 를 정한다**
   (pt = unit × 1728/viewBox폭). 720 이면 라벨 29pt·부제 19pt, 1137 이면 12pt 로 안 읽힌다
   (tracks-meta/dispatch/2026-09-05_archify-preprep/DESIGN_TOKENS.md §3). 넘으면 거부 — --max-viewbox-w 로 조정.
🟥 여백(--pad): 그림 가장자리 비율. 0 이면 장표 가장자리와 선이 붙는다.

exit 0 굽음 · 1 거부(validate 실패 · 해상도 · viewBox · deliver 실패) · 10 계기 오류(node/archify/Chrome 부재)
usage: diagram_from_json.py <spec.json> --out <name.png> [--css tokens.css] [--theme dark|light]
       [--focus id,id] [--no-legend] [--size 3840x2160] [--pad 0.03] [--min-px 3840] [--max-viewbox-w 720] [--archify BIN]
"""
import argparse, hashlib, json, os, re, shutil, struct, subprocess, sys, tempfile, zlib

def sha256_file(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f: h.update(f.read())
    return h.hexdigest()

def png_size(p):
    with open(p, 'rb') as f: head = f.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n': raise ValueError('PNG 아님')
    w, h = struct.unpack('>II', head[16:24]); return w, h

def run_json(cmd, env):
    r = subprocess.run(cmd, capture_output=True, text=True, env=env)
    try: return json.loads(r.stdout), r
    except Exception: return None, r

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('spec'); ap.add_argument('--out', required=True, help='산출 PNG 경로(.png). HTML·영수증은 같은 이름으로 옆에')
    ap.add_argument('--css', default=None, help='디자인 토큰 override CSS(archify CSS 변수 재정의)')
    ap.add_argument('--theme', default='dark', choices=['dark', 'light'])
    ap.add_argument('--focus', default=None, help='빌드 프레임: 켤 노드 id(콤마). 나머지는 흐림 — 좌표는 불변(§B3)')
    ap.add_argument('--dim', type=float, default=0.22)
    ap.add_argument('--opaque', action='store_true', help='배경을 칠한다(기본은 투명 — 장표 배경이 그대로 비친다. 색 관리 차이로 «패널»이 보이던 실측 결함의 처방)')
    ap.add_argument('--strip-lane-prefix', action='store_true', help='레인 제목의 «01 / »·«EX / » 접두를 뺀다(archify 고정 어휘 — 장표에선 뜻이 없다). 글자만 짧아지고 기하는 불변')
    ap.add_argument('--no-crop', action='store_true', help='내용 경계로 자르지 않는다(기본은 자른다 — archify 가 범례 행·채널 여백을 남겨 장표에서 그림이 작아진다)')
    ap.add_argument('--no-legend', action='store_true', help='SVG 범례 행 숨김(영어 고정이라 D1 위반)')
    ap.add_argument('--size', default='auto', help="'auto' = 폭 3840 · 높이는 SVG 비율대로(레터박스 0 — 장표에 넣을 때 글자 배율이 안 죽는다) 또는 WxH"); ap.add_argument('--pad', type=float, default=0.03)
    ap.add_argument('--min-px', type=int, default=3840); ap.add_argument('--max-viewbox-w', type=int, default=720)
    ap.add_argument('--archify', default=os.environ.get('PREPREP_ARCHIFY_BIN', '.claude/skills/archify/bin/archify.mjs'))
    ap.add_argument('--chrome', default=os.environ.get('PREPREP_CHROME', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'))
    a = ap.parse_args()

    if not os.path.exists(a.spec): print('HARNESS ERROR: spec 없음', a.spec); return 10
    if not os.path.exists(a.archify): print('HARNESS ERROR: archify 없음 —', a.archify, '(npx -y skills add tt-a1i/archify --skill archify --agent claude-code --copy --yes)'); return 10
    if shutil.which('node') is None: print('HARNESS ERROR: node 없음'); return 10
    if not os.path.exists(a.chrome) and shutil.which(a.chrome) is None: print('HARNESS ERROR: Chrome 없음 —', a.chrome); return 10
    env = dict(os.environ, ARCHIFY_UPDATE_CHECK_DISABLED='1')   # 외부 통신 차단
    spec = json.load(open(a.spec, encoding='utf-8'))
    dtype = spec.get('diagram_type')
    if dtype not in ('architecture', 'workflow', 'sequence', 'dataflow', 'lifecycle'):
        print('REFUSE: diagram_type 없음/미지원:', dtype); return 1
    out_png = os.path.abspath(a.out); stem = re.sub(r'\.png$', '', out_png)
    out_html, out_receipt = stem + '.html', stem + '.receipt.json'

    # ① validate — showcase 9 검사 전부. 못 통과하면 여기서 끝(PNG 안 만든다)
    v, r = run_json(['node', a.archify, 'validate', dtype, a.spec, '--quality', 'showcase', '--json'], env)
    if not v or not v.get('ok'):
        print('REFUSE: archify validate 실패 — 굽지 않는다')
        for d in (v or {}).get('diagnostics') or (((v or {}).get('composition') or {}).get('diagnostics') or []):
            print('   ·', d.get('code'), d.get('message', '')[:300])
        if not v: print('   ·', (r.stderr or r.stdout)[-600:])
        return 1
    comp = v.get('composition') or {}
    if (comp.get('summary') or {}).get('errors', 0) or (comp.get('summary') or {}).get('warnings', 0):
        print('REFUSE: showcase 구성 오류/경고 있음', comp.get('summary')); return 1
    # ② deliver
    d, r = run_json(['node', a.archify, 'deliver', dtype, a.spec, out_html, '--quality', 'showcase', '--json'], env)
    if not d or not d.get('ok'):
        print('REFUSE: deliver 실패', (r.stderr or r.stdout)[-600:]); return 1
    html = open(out_html, encoding='utf-8').read()
    svgs = re.findall(r'<svg[\s\S]*?</svg>', html)
    if len(svgs) != 1: print('REFUSE: <svg> 블록이 1개가 아님:', len(svgs)); return 1
    vb = re.search(r'viewBox="([^"]+)"', svgs[0]); vbw = float(vb.group(1).split()[2]) if vb else None
    if vbw is None or vbw > a.max_viewbox_w:
        print(f'REFUSE: viewBox 폭 {vbw} > 상한 {a.max_viewbox_w} — 글자가 {12*1728/(vbw or 1):.0f}pt 로 떨어진다. 노드/레인을 줄이거나 --max-viewbox-w 를 근거와 함께 올려라')
        return 1
    # ③ SVG 단독 PNG
    styles = ''.join(re.findall(r'<style[^>]*>[\s\S]*?</style>', html))
    svg_out = svgs[0]
    if a.strip_lane_prefix:
        # 레인 제목 <text …font-size="10"…>01 / 사람</text> — 접두만 지운다. 텍스트가 짧아질 뿐 어떤 좌표도 안 바뀐다.
        svg_out = re.sub(r'(<text[^>]*font-size="10"[^>]*>)(?:\d{2}|EX) / ', r'\1', svg_out)
    vbh = float(vb.group(1).split()[3])
    if a.size.lower() == 'auto':
        # 🟥 16:9 고정 캔버스에 1.9:1 도해를 넣으면 레터박스가 생겨 장표에서 그림이 작아진다(실측:
        #    후보 1차가 라벨 18pt 로 떨어졌다). 캔버스를 SVG 비율에 맞춰 여백 0 으로 굽는다.
        W = max(a.min_px, 3840); H = int(round(W * vbh / vbw))
    else:
        W, H = map(int, a.size.lower().split('x'))
    focus_css = ''
    if a.no_legend: focus_css += '[data-legend],[data-legend-kind]{display:none !important}\n'
    if a.focus:
        ids = [x.strip() for x in a.focus.split(',') if x.strip()]
        keep_n = ','.join(f'g[data-node-id="{i}"]' for i in ids)
        keep_e = ','.join(f'[data-edge-from="{x}"][data-edge-to="{y}"]' for x in ids for y in ids if x != y)
        focus_css += f'g[data-node-id],[data-edge-from]{{opacity:{a.dim}}}\n{keep_n}{{opacity:1}}\n' + (f'{keep_e}{{opacity:1}}\n' if keep_e else '')
    token_css = ('<style>' + open(a.css, encoding='utf-8').read() + '</style>') if a.css else ''
    bg_css = '' if a.opaque else 'html,body{background:transparent !important}'
    doc = (f'<!doctype html><html lang="ko" data-theme="{a.theme}" data-preset="classic"><head><meta charset="utf-8">{styles}'
           f'<style>{focus_css}html,body{{margin:0;padding:0;width:{W}px;height:{H}px;overflow:hidden}}{bg_css}'
           f'body{{display:flex;align-items:center;justify-content:center}}'
           f'.stage{{width:{W*(1-2*a.pad):.0f}px;height:{H*(1-2*a.pad):.0f}px;display:flex;align-items:center;justify-content:center}}'
           f'.stage>svg{{width:100%;height:100%;max-width:100%;max-height:100%}}</style>{token_css}</head>'
           f'<body><div class="stage">{svg_out}</div></body></html>')
    tmpd = tempfile.mkdtemp(prefix='preprep_diagram_'); src = os.path.join(tmpd, 'svg_only.html')
    open(src, 'w', encoding='utf-8').write(doc)
    subprocess.run([a.chrome, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run'] +
                   ([] if a.opaque else ['--default-background-color=00000000']) +
                   [f'--window-size={W},{H}', f'--screenshot={out_png}', 'file://' + src], capture_output=True, text=True, timeout=180)
    shutil.rmtree(tmpd, ignore_errors=True)
    if not os.path.exists(out_png): print('HARNESS ERROR: Chrome 스크린샷 없음'); return 10
    cropped = None
    if not a.no_crop and not a.opaque:
        try:
            from PIL import Image
            im = Image.open(out_png).convert('RGBA'); bb = im.getbbox()   # 알파 0 이 아닌 픽셀의 경계
            if bb:
                m = int(round(a.pad * W)); bb2 = (max(0, bb[0]-m), max(0, bb[1]-m), min(W, bb[2]+m), min(H, bb[3]+m))
                im.crop(bb2).save(out_png); cropped = bb2
        except ImportError:
            cropped = 'PIL 없음 — 자르지 못함(UNMEASURED)'
    pw, ph = png_size(out_png)
    if pw < a.min_px and not cropped:
        os.remove(out_png); print(f'REFUSE: PNG 폭 {pw} < 하한 {a.min_px} — 지웠다'); return 1
    if cropped and W < a.min_px:
        os.remove(out_png); print(f'REFUSE: 캔버스 폭 {W} < 하한 {a.min_px} — 지웠다'); return 1
    # ④ 영수증 — L12 가 읽는 채널. JSON 지문으로 «지금 JSON 의 그림인가»를 묶는다
    receipt = {'schema': 'preprep.diagram.receipt/1', 'spec': os.path.abspath(a.spec), 'spec_sha256': sha256_file(a.spec),
               'diagram_type': dtype, 'validate': {'ok': True, 'profile': 'showcase', 'checks': len(v.get('checks', [])),
               'composition': comp.get('summary')}, 'deliver': {'artifact_sha256': (d.get('artifact') or {}).get('sha256')},
               'html': out_html, 'png': out_png, 'png_size': [pw, ph], 'viewbox_w': vbw, 'viewbox_h': vbh, 'canvas': a.size, 'transparent': not a.opaque, 'crop': cropped, 'pad': a.pad, 'theme': a.theme,
               'css': os.path.abspath(a.css) if a.css else None, 'focus': a.focus, 'legend_hidden': bool(a.no_legend), 'lane_prefix_stripped': bool(a.strip_lane_prefix),
               'text_pt_estimate': {'label12': round(12*1728/vbw, 1), 'sublabel8': round(8*1728/vbw, 1)}}
    json.dump(receipt, open(out_receipt, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    print(f'OK {out_png} {pw}x{ph} viewBox_w={vbw:.0f} (라벨≈{receipt["text_pt_estimate"]["label12"]}pt · 부제≈{receipt["text_pt_estimate"]["sublabel8"]}pt) 영수증 {out_receipt}')
    return 0

if __name__ == '__main__':
    sys.exit(main())
