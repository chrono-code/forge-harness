import glob,re,os,sys
from lxml import etree
# 작업 트리: 인자 > 환경변수 OOXML_ROOT > 현재 디렉터리(v4 있으면 그쪽)
_root = sys.argv[1] if len(sys.argv)>1 else os.environ.get('OOXML_ROOT')
if not _root:
    _root = 'v4' if os.path.isdir('v4/ppt/slides') else '.'
if not os.path.isdir(os.path.join(_root,'ppt','slides')):
    print('GATE FAIL · 작업 트리를 못 찾음:',_root); sys.exit(1)
os.chdir(_root)
ok=True; P='http://schemas.openxmlformats.org/presentationml/2006/main'
_A='http://schemas.openxmlformats.org/drawingml/2006/main'
def fail(*a):
    global ok; ok=False; print('  ❌',*a)
for p in glob.glob('**/*.xml',recursive=True)+glob.glob('**/*.rels',recursive=True):
    try: etree.parse(p)
    except Exception as e: fail('PARSE',p,e)
# ① 관계 참조 무결성 (repair 다이얼로그의 주범)
for kind in ('slides','notesSlides','slideLayouts','slideMasters','notesMasters'):
    for p in sorted(glob.glob('ppt/%s/*.xml'%kind)):
        x=open(p).read()
        rp='ppt/%s/_rels/%s.rels'%(kind,os.path.basename(p))
        rmap=set(re.findall(r'Id="([^"]+)"',open(rp).read())) if os.path.exists(rp) else set()
        for attr,rid in re.findall(r'(r:(?:id|embed|link|pict|dm|lo|qs|cs))="([^"]+)"',x):
            if rid not in rmap: fail('DANGLING',p,attr,rid)
# ② rels 대상 파일 존재
for rp in glob.glob('**/_rels/*.rels',recursive=True):
    base=os.path.dirname(os.path.dirname(rp))
    for tgt,mode in re.findall(r'Target="([^"]+)"(?:[^>]*TargetMode="([^"]*)")?',open(rp).read()):
        if mode=='External' or tgt.startswith('http'): continue
        f=os.path.normpath(os.path.join(base,tgt))
        if not os.path.exists(f): fail('MISSING TARGET',rp,tgt)
# ③ cNvPr id 중복 · <a:t> 개행
for p in sorted(glob.glob('ppt/slides/slide*.xml')):
    ids=[e.get('id') for e in etree.parse(p).iter('{%s}cNvPr'%P)]
    d=[i for i in set(ids) if ids.count(i)>1]
    if d: fail('DUP cNvPr',p,d)
    for m in re.findall(r'<a:t>([^<]*)</a:t>',open(p).read()):
        if '\n' in m or '\r' in m: fail('NEWLINE in a:t',p,repr(m[:30]))
# ④ 프레젠테이션 등록 / Content_Types / sldId
pres=open('ppt/presentation.xml').read()
m={rid:os.path.basename(t) for rid,t in re.findall(r'Id="([^"]+)"[^>]*Target="([^"]+)"',open('ppt/_rels/presentation.xml.rels').read())}
order=[m[r] for r in re.findall(r'<p:sldId[^>]*r:id="([^"]+)"',pres)]
ct=open('[Content_Types].xml').read()
for f in order:
    if '/ppt/slides/%s"'%f not in ct: fail('CT missing',f)
sld=re.findall(r'<p:sldId id="(\d+)"',pres)
if len(set(sld))!=len(sld): fail('DUP sldId')
for p in glob.glob('ppt/slides/slide*.xml'):
    if os.path.basename(p) not in order: fail('ORPHAN slide',p)
app=open('docProps/app.xml').read()
if '<Slides>%d</Slides>'%len(order) not in app: fail('app.xml Slides != %d'%len(order))
if '<Notes>%d</Notes>'%len(order) not in app: fail('app.xml Notes != %d'%len(order))

i=app.find('<TitlesOfParts>')
import re as _re
n_lp=len(_re.findall(r'<vt:lpstr>',app[i:]))
sz=int(_re.search(r'<TitlesOfParts><vt:vector size="(\d+)"',app).group(1))
if n_lp!=sz: fail('app.xml TitlesOfParts vector size %d != lpstr %d'%(sz,n_lp))

for _p in sorted(glob.glob('ppt/slides/slide*.xml')):
    _t=etree.parse(_p).getroot().find('.//{%s}cSld/{%s}spTree'%(P,P))
    _k=[etree.QName(e).localname for e in _t]
    if _k[:2]!=['nvGrpSpPr','grpSpPr']: fail('spTree 순서 위반',_p,_k[:3])

# ── prstGeom 조정값 이름 검증 (2026-08-27 신설: round2SameRect 에 adj 하나만 줘서 두 번 깨졌다)
_A='http://schemas.openxmlformats.org/drawingml/2006/main'
_ADJ={'rect':set(),'ellipse':set(),'line':set(),'roundRect':{'adj'},
      'arc':{'adj1','adj2'},'round2SameRect':{'adj1','adj2'},'round2DiagRect':{'adj1','adj2'},
      'round1Rect':{'adj'},'triangle':{'adj'},'chevron':{'adj'},
      'circularArrow':{'adj1','adj2','adj3','adj4','adj5'},
      'rightArrow':{'adj1','adj2'},'leftArrow':{'adj1','adj2'},
      'upArrow':{'adj1','adj2'},'downArrow':{'adj1','adj2'}}
for _p in sorted(glob.glob('ppt/slides/slide*.xml')):
    for _g in etree.parse(_p).getroot().iter('{%s}prstGeom'%_A):
        _prst=_g.get('prst')
        if _prst not in _ADJ: continue
        _names={x.get('name') for x in _g.iter('{%s}gd'%_A)}
        if _names and not _names <= _ADJ[_prst]:
            fail('prstGeom 조정값 이름', _p, _prst, sorted(_names), '허용:', sorted(_ADJ[_prst]) or '없음')

# ── ⑤ Content_Types 역방향: Override 가 가리키는 파트가 실제로 있나 (2026-08-28 신설)
#    기존 ④ 는 «등록된 슬라이드가 CT 에 있나» 한 방향만 봤다. 슬라이드를 삭제하면
#    CT 에 죽은 Override 가 남고, 그 파일은 PowerPoint 가 아예 열지 못한다.
#    실제로 40p 삭제 때 정규식이 ContentType 값의 '/' 때문에 매치되지 않아 2개가 남았다.
_over = set(re.findall(r'<Override PartName="([^"]+)"', ct))
for _o in sorted(_over):
    if not _o.startswith(('/ppt/slides/','/ppt/notesSlides/')): continue
    if not os.path.exists(_o.lstrip('/')): fail('CT ORPHAN Override', _o, '(파트 파일 없음)')
for _f in sorted(glob.glob('ppt/notesSlides/notesSlide*.xml')):
    if '/%s"'%_f not in ct: fail('CT missing (notesSlide)', _f)

# ── ⑥ 화면 밖으로 나간 도형 (2026-08-28 신설: 26p 가 우측으로 1,854,400 EMU 벗어나 있었다)
_W,_H = (int(x) for x in (re.search(r'sldSz cx="(\d+)" cy="(\d+)"', pres).groups()))
for _p in sorted(glob.glob('ppt/slides/slide*.xml')):
    for _sp in etree.parse(_p).getroot().iter():
        if etree.QName(_sp).localname not in ('sp','pic','cxnSp','graphicFrame'): continue
        _xf=_sp.find('.//{%s}spPr/{%s}xfrm'%(P,_A))
        if _xf is None: _xf=_sp.find('.//{%s}xfrm'%_A)
        if _xf is None: continue
        _off=_xf.find('{%s}off'%_A); _ext=_xf.find('{%s}ext'%_A)
        if _off is None or _ext is None: continue
        _x,_y=int(_off.get('x')),int(_off.get('y')); _cx,_cy=int(_ext.get('cx')),int(_ext.get('cy'))
        if _x+_cx > _W+10000 or _y+_cy > _H+10000 or _x < -10000 or _y < -10000:
            _nv=_sp.find('.//{%s}cNvPr'%P)
            fail('OFF-CANVAS', os.path.basename(_p), _nv.get('name') if _nv is not None else '?',
                 'x %d~%d y %d~%d (화면 %dx%d)'%(_x,_x+_cx,_y,_y+_cy,_W,_H))

# ── ⑦ 열린 도형에 채움 (2026-08-28 신설: arc 를 카드로 오인해 채우면 부채꼴이 칠해진다)
_OPEN={'arc','line','straightConnector1','bentConnector2','bentConnector3',
       'curvedConnector2','curvedConnector3','curvedConnector4','curvedConnector5'}
for _p in sorted(glob.glob('ppt/slides/slide*.xml')):
    for _sp in etree.parse(_p).getroot().iter('{%s}sp'%P):
        _spPr=_sp.find('{%s}spPr'%P)
        if _spPr is None: continue
        _g=_spPr.find('{%s}prstGeom'%_A)
        if _g is None or _g.get('prst') not in _OPEN: continue
        if _spPr.find('{%s}solidFill'%_A) is not None:
            _nv=_sp.find('.//{%s}cNvPr'%P)
            fail('열린 도형에 채움', os.path.basename(_p),
                 _nv.get('name') if _nv is not None else '?', _g.get('prst'))

# ── ⑧ 선 굵기 토큰 래칫 (2026-08-28 신설)
# 체크리스트 C1 은 «구조 1pt · 테두리 3pt · 흐름 7pt · 강조 14pt» 네 토큰을 정한다.
# 그런데 실측하면 도형을 만들 때마다 눈대중으로 새 굵기가 생겨 42% 가 토큰 밖이었다.
# 🟥 전량 차단하면 첫 실행부터 막혀 --no-verify 를 훈련시킨다(도달불가 Done-When).
#    그래서 «지금»을 기준선에 박고 **늘어날 때만** 막는다. 줄면 낮추라고 알린다.
# 🟥 기준선은 «총합»이 아니라 «굵기별»이다 — 총합만 세면 어느 굵기가 새로 생겼는지
#    못 짚어서, 판정은 맞고 처방은 틀린 게이트가 된다.
_C1={12700:'구조 1pt',38100:'테두리 3pt',88900:'흐름 7pt',177800:'강조 14pt'}
_BASE=os.path.join(os.path.dirname(os.path.abspath(__file__)),'c1_baseline.txt')
_seen={}
for _p in sorted(glob.glob('ppt/slides/slide*.xml')):
    for _l in etree.parse(_p).iter('{%s}ln'%_A):
        _w=_l.get('w')
        if not _w or int(_w) in _C1: continue
        _seen.setdefault(int(_w),[]).append(os.path.basename(_p))
_now={k:len(v) for k,v in _seen.items()}
_dump=lambda d:'\n'.join('%d %d'%(k,d[k]) for k in sorted(d))
if os.path.exists(_BASE):
    _prev={}
    for _line in open(_BASE):
        _line=_line.split('#')[0].strip()
        if _line: _k,_v=_line.split(); _prev[int(_k)]=int(_v)
    _grew={k:(_prev.get(k,0),v) for k,v in _now.items() if v>_prev.get(k,0)}
    if _grew:
        fail('C1 선 굵기 토큰 밖이 늘었다 —','허용:',' · '.join('%d(%s)'%(k,v) for k,v in _C1.items()))
        for _w,(_a,_b) in sorted(_grew.items()):
            _tag='새 굵기' if _a==0 else '증가'
            print('     w=%-7d (%.2fpt)  %d → %d  [%s]  예: %s'%(_w,_w/12700,_a,_b,_tag,
                  ', '.join(sorted(set(_seen[_w]))[:3])))
        print('     ↳ 위 굵기를 네 토큰 중 하나로 바꾸거나, 의도한 값이면 %s 를 갱신해라'%os.path.relpath(_BASE))
    elif sum(_now.values())<sum(_prev.values()):
        print('  ✅ C1 토큰 밖 %d → %d 로 줄었다. 기준선 갱신:'%(sum(_prev.values()),sum(_now.values())))
        print('     python3 %s --write-c1-baseline'%os.path.relpath(__file__))
else:
    print('  ⚠ C1 기준선 없음 — 토큰 밖 %d곳(%d종). 박으려면:'%(sum(_now.values()),len(_now)))
    print('     python3 %s --write-c1-baseline'%os.path.relpath(__file__))
if '--write-c1-baseline' in sys.argv:
    open(_BASE,'w').write('# C1 선 굵기 기준선 — «굵기 개수». gate.py ⑧ 이 읽는다.\n'+_dump(_now)+'\n')
    print('  ✍ 기준선 기록: %s (%d종 %d곳)'%(os.path.relpath(_BASE),len(_now),sum(_now.values())))


print('GATE','PASS' if ok else 'FAIL','·',len(order),'장')
sys.exit(0 if ok else 1)
