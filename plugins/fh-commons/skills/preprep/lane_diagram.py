"""L12 diagram — **도해가 «지금 JSON» 에서 검증을 거쳐 구워졌나.**

## 존재 근거 (2026-09-05, archify × preprep 결합 실측)

도해를 타입 있는 JSON → 외부 렌더러(archify) → PNG → pptx 로 넣는 경로가 뚫렸다. 그 경로의 사각은
셋이고, 셋 다 «PNG 가 있다»로는 안 보인다:
  ① JSON 을 고쳤는데 PNG 는 옛 것(재생성 안 함)         — 빌드는 성공, 그림은 거짓
  ② validate 를 못 통과한 JSON 을 손으로 렌더해 넣음      — 겹침·라벨 마스킹이 화면에
  ③ 픽셀은 충분한데 viewBox 가 넓어 글자가 12pt 로 떨어짐 — «해상도 OK» 인데 못 읽는다

## 무엇을 재고 무엇을 안 재나

- 잰다 — `kind: diagram_source` 표면마다 `render:` PNG 옆의 **굽기 영수증**(`*.receipt.json`,
  `diagram_from_json.py` 가 쓴다)을 읽어: 영수증 존재 · JSON sha 일치 · validate ok(showcase) ·
  PNG 실제 폭(IHDR 을 직접 읽는다 — 영수증 자기신고가 아니다) ≥ min_px · viewBox 폭 ≤ max ·
  pad ≥ min.
- 안 잰다 — 그림이 «좋은가». 그건 §방법론 ⓒ «도해를 건드렸으면 렌더한다» 의 사람 몫이다.
- 🟥 영수증이 없는 PNG(손으로 넣은 그림)는 **UNMEASURED 로 낸다** — 0 이 아니고, 통과도 아니다.
  이 레인은 «생성기를 거친 그림»만 본다. 사각은 좁아지지 좁아지지 닫히지 않는다(SKILL.md §갈라 적는 것).

## 차단인 이유
선언된 표면에 한해 «지문이 다르다 / validate 가 아니다 / 폭이 모자란다» 는 애매하지 않은 사실이다.
오탐의 최저비용 무마는 «다시 굽는 것»이라 원고를 망가뜨리는 방향이 아니다.
"""
import hashlib, json, os, struct


def _sha(p):
    h = hashlib.sha256(); h.update(open(p, 'rb').read()); return h.hexdigest()


def _png_w(p):
    with open(p, 'rb') as f: head = f.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n': raise ValueError('PNG 아님')
    return struct.unpack('>II', head[16:24])[0]


def _resolve(root, p):
    return os.path.normpath(os.path.join(root, os.path.expanduser(p)))


def scan(cfg, root):
    """(findings, notes). findings 튜플 = (sid, kind, ref, lit, why) — preprep.py 의 USE 계열."""
    surfs = [s for s in cfg.get('surfaces', []) if s.get('kind') == 'diagram_source']
    if not surfs:
        return [], ['L12 diagram : diagram_source 표면 없음 — NOT_CONFIGURED (0 아님)']
    spec = cfg.get('diagram') or {}
    min_px = int(spec.get('min_px', 3840)); max_vb = float(spec.get('max_viewbox_w', 720)); min_pad = float(spec.get('min_pad', 0.02))
    findings, notes = [], []
    n_ok = n_unm = 0
    for s in surfs:
        sid = s['id']; jp = _resolve(root, s['path'])
        if not os.path.exists(jp):
            notes.append(f'L12 diagram : {sid} JSON 없음({jp}) — UNMEASURED (0 아님)'); n_unm += 1; continue
        rp_png = s.get('render')
        if not rp_png:
            notes.append(f'L12 diagram : {sid} render(PNG) 미선언 — UNMEASURED (0 아님)'); n_unm += 1; continue
        png = _resolve(root, rp_png); rec = png[:-4] + '.receipt.json' if png.endswith('.png') else png + '.receipt.json'
        if not os.path.exists(png):
            findings.append((sid, 'diagram', 'render', os.path.basename(png), 'L12 선언된 PNG 가 디스크에 없다 — 굽지 않았거나 경로가 틀렸다')); continue
        if not os.path.exists(rec):
            notes.append(f'L12 diagram : {sid} 굽기 영수증 없음({os.path.basename(rec)}) — 손으로 넣은 그림은 이 레인이 못 본다. UNMEASURED (0 아님)'); n_unm += 1; continue
        try: r = json.load(open(rec, encoding='utf-8'))
        except Exception as e:
            findings.append((sid, 'diagram', 'receipt', os.path.basename(rec), f'L12 영수증 파싱 실패({type(e).__name__}) — 채널이 깨졌다')); continue
        bad = False
        if r.get('spec_sha256') != _sha(jp):
            findings.append((sid, 'diagram', 'stale', os.path.basename(png), 'L12 JSON 지문이 영수증과 다르다 — JSON 을 고친 뒤 다시 굽지 않았다')); bad = True
        if not (r.get('validate') or {}).get('ok') or (r.get('validate') or {}).get('profile') != 'showcase':
            findings.append((sid, 'diagram', 'validate', os.path.basename(png), 'L12 showcase validate 통과 기록이 없다 — 검증 안 된 그림')); bad = True
        try: w = _png_w(png)
        except Exception as e:
            findings.append((sid, 'diagram', 'png', os.path.basename(png), f'L12 PNG 헤더 읽기 실패({e})')); continue
        if w < min_px:
            # 자른(crop) PNG 는 캔버스보다 좁다 — 영수증의 png_size 가 아니라 «crop 전 캔버스»가 하한을 넘겼는지 본다.
            # 🟥 캔버스 폭은 영수증 자기신고다. IHDR 실측(w)과 함께 둘 다 적어 감사자가 가르게 한다.
            canvas_w = None
            cv = r.get('canvas')
            if isinstance(cv, str) and 'x' in cv.lower() and cv.lower() != 'auto':
                canvas_w = int(cv.lower().split('x')[0])
            elif r.get('crop'):
                canvas_w = min_px if r.get('png_size') else None   # auto 캔버스는 스크립트가 하한 이상으로만 만든다
            if not (r.get('crop') and canvas_w and canvas_w >= min_px):
                findings.append((sid, 'diagram', 'resolution', os.path.basename(png), f'L12 PNG 폭 {w} < 하한 {min_px} (장표 2×)')); bad = True
            else:
                notes.append(f'L12 diagram : {sid} 자른 PNG 폭 {w}(IHDR) — 캔버스 {canvas_w}(영수증 자기신고) 로 하한 판정')
        vbw = r.get('viewbox_w')
        if vbw is None or float(vbw) > max_vb:
            findings.append((sid, 'diagram', 'viewbox', os.path.basename(png), f'L12 viewBox 폭 {vbw} > 상한 {max_vb:.0f} — 글자 배율 미달(라벨≈{12*1728/float(vbw or 1):.0f}pt)')); bad = True
        if float(r.get('pad', 0)) < min_pad:
            findings.append((sid, 'diagram', 'pad', os.path.basename(png), f'L12 여백 {r.get("pad")} < 하한 {min_pad}')); bad = True
        if not bad: n_ok += 1
    notes.append(f'L12 diagram : 표면 {len(surfs)} · 통과 {n_ok} · UNMEASURED {n_unm} · 발견 {len(findings)} '
                 f'(하한 {min_px}px · viewBox≤{max_vb:.0f} · pad≥{min_pad})')
    return findings, notes
