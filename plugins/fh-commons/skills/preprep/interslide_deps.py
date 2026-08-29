#!/usr/bin/env python3
"""L5 — 장 사이 의존 그래프 (챔버 런 #15).

한 장이 다른 장에 의존하는 관계를 뽑고, **그 의존이 깨졌는지** 판정한다.
실사고: S8 을 빼자 S9 가 성립 불가가 됐다 — S9 는 S8 의 화면을 재사용하며 「방금 오른쪽에서」로
되짚는 장이었다. 🟥 렌더 28장을 전부 눈으로 봐도 안 잡혔다(한 장씩 보므로).

## 🟥 두 층으로 가른다. 합치면 계기가 거짓말한다
    HARD  구조적 의존 — 앞 장의 **화면이 없으면 성립 불가**
          · 🖥 이 화면 재사용을 선언한다 («그대로», «같은 화면», «이어서»)
          · 🗣 가 **시각 지시**를 한다 (방향어 + 시각동사: 「오른쪽에서 보셨」 「방금 … 보신」)
    SOFT  수사적 되짚기 — 말로 앞을 가리킨다 («앞서 말씀드린», «그 세 규율»)
          장을 빼도 **문장 한 줄로 메울 수 있다.** 이건 «의존»으로 세면 안 된다 —
          세면 「장을 지우지 마라」는 거짓 제약이 되고, 그 오탐은 편집을 막는 방향이다.

두 층을 나누는 것이 이 계기의 하중선이다. 「앞서 말씀드린」이 의존인지 수사인지는 원리적으로
애매하지만, **화면을 가리키는 것**은 애매하지 않다 — 화면은 있거나 없다.

exit 0 = 깨진 의존 없음 · 1 = 있음 · 2 = 계기 오류/미측정 (PASS 아님)
usage: interslide_deps.py <draft.md> <builder.py> [--all]
"""
import sys, re, ast, os

# 어휘는 **실물에서 뽑았다**(pre-자립화 S9 원문). 지어내지 않았다.
SCREEN_REUSE = ('그대로', '같은 화면', '이어서', '화면 유지', '왼쪽 그대로', '오른쪽 그대로')
DIRECTION    = ('오른쪽', '왼쪽', '위에서', '아래', '옆')
VISUAL_VERB  = ('보셨', '보신', '보시는', '보시면', '보였')
RECALL       = ('방금', '아까', '조금 전', '앞서', '앞에서', '지금까지')
SOFT_ONLY    = ('말씀드린', '말씀드렸', '설명드린', '그 세', '앞의')

def units(src):
    """(sid, 헤딩, 본문) 순서대로. 🚫 은퇴 표기 절은 «죽은 것»으로 표시해 같이 낸다."""
    out = []
    for m in re.finditer(r'^### (S[0-9]+(?:-[a-z])?)\s*·([^\n]*)\n(.*?)(?=^### |\Z)', src, re.M | re.S):
        retired = any(t in m.group(2) for t in ('🚫', '제거됨', '폐기'))
        out.append((m.group(1), m.group(2).strip(), m.group(3), retired))
    return out

# 🟥 런 #14 에서 이미 한 번 겪은 결함이 여기서 재현됐다: 원고의 **주석 블록**도 `>` 라서
# 낭독으로 섞여 들어온다. 그러면 «과거에 없는 화면을 가리켰다» 고 적은 주석이 «지금 가리킨다»로
# 계상된다(known-negative 가 통째로 실패했다). 낭독과 주석을 가르는 것은 원고 자신의 표기다.
ANNOTATION = ('🆕', '🟥', '✅', '🚫', '★', '⚠️', '🟢', '🟡', '원장', '2026-0', '실측', '정정')

def is_annotation(line):
    return any(c in line for c in ANNOTATION)

def blocks(body):
    """🖥(화면) · 🗣(낭독) 을 가른다. 인용(>)은 낭독의 일부로 본다 — 원고 형식이 그렇다."""
    screen, speech, cur, in_anno = [], [], None, False
    for ln in body.split('\n'):
        t = ln.strip()
        if t.startswith('🖥'): cur = 'screen'; screen.append(t); continue
        if t.startswith('🗣'): cur = 'speech'; in_anno = False; continue
        if t.startswith('⏱'):  cur = None; continue
        if cur == 'screen': screen.append(t)
        elif cur == 'speech':
            t2 = t.lstrip('> ').strip()
            # 🟥 주석은 **여러 줄 블록**이다. 줄 단위로만 배제하면 둘째 줄부터 낭독으로 샌다
            #    (실측: known-negative 가 그 한 줄 때문에 계속 실패했다).
            #    빈 줄이 블록을 닫는다 — 원고 형식이 그렇다.
            if not t2:
                in_anno = False; continue
            if is_annotation(t2): in_anno = True
            if not in_anno: speech.append(t2)
    return '\n'.join(screen), '\n'.join(speech)

def classify_unit(screen, speech):
    """HARD / SOFT 근거를 각각 모은다. 한 장이 둘 다 가질 수 있다."""
    hard, soft = [], []
    for ln in screen.split('\n'):
        if any(c in ln for c in SCREEN_REUSE):
            hard.append(('screen-reuse', ln.strip()[:90]))
    for ln in speech.split('\n'):
        has_dir = any(d in ln for d in DIRECTION)
        has_vis = any(v in ln for v in VISUAL_VERB)
        has_rec = any(r in ln for r in RECALL)
        if (has_dir and has_vis) or (has_rec and has_vis):
            hard.append(('visual-deixis', ln.strip()[:90]))
        elif has_rec or any(s in ln for s in SOFT_ONLY):
            soft.append(('verbal-recall', ln.strip()[:90]))
    return hard, soft

# 🟥 선행자를 «직전 절» 로 추정하면 오탐이 난다 — 실측: S20 의 «앞에서 보신 그 초록 벽» 은
#    직전 절(S18-b)이 아니라 **S9 자신의 이미지**였고(원고가 그렇게 적어놨다), S9 는 배선돼
#    있으므로 안 깨졌다. 추정을 버리고 **지시 대상을 실제로 찾는다.**
#    판정은 3값이다: 배선된 절에서 찾음=OK · 안 배선된 절에서만 찾음=BROKEN · 아무 데도 없음=UNRESOLVED
#    🟥 UNRESOLVED 를 BROKEN 으로 접지 않는다(미측정은 0 도 1 도 아니다).
DEICTIC_PREFIX = r'^(그|저|이|방금|아까|앞에서 보신|조금 전에 보신|앞서 말씀드린|지금 보시는|첫 번째로|두 번째로)\s*'
COMMON = ('것', '자리', '검사', '화면', '때', '말', '점', '수', '얘기', '문제', '경우', '부분')

def referents(line):
    """지시 표현이 가리키는 «것»의 후보.

    🟥 판별자를 바꿨다 — 블라인드 냉독이 실물 8건을 손분류해서 낸 규칙이다:
       트리거는 회고 부사(«앞서 말씀드린»)가 **아니다**. 그건 판별력이 없다(수사에도 붙는다).
       판별자는 **«지시 명사구가 이 장에서 처음 정의되는가»** — 인용부호 안 조어 · 백틱 용어 ·
       고유 명명이 붙어 있으면 의존이고, 지시 명사구가 없으면 수사다.
    초판은 강조 스팬을 20자로 잘랐는데, 실제 known-positive 의 대상은
    «방금 오른쪽에서 첫 번째로 빨갛던 그 검사»(23자) + 백틱 `stale base` 였다 — 둘 다 놓쳤다.
    """
    cands = []
    for m in re.finditer(r'`([^`]{2,40})`', line):                 # 백틱 = 고유 용어
        cands.append(m.group(1).strip())
    for m in re.finditer(r'[«“]([^»”]{2,40})[»”]', line):          # 인용 조어
        cands.append(m.group(1).strip())
    for m in re.finditer(r'\*\*([^*]{2,40})\*\*', line):         # 강조 = 대상을 나른다
        t = re.sub(DEICTIC_PREFIX, '', m.group(1).strip(' .,·「」«»')).strip()
        # 지시어만 벗기면 남는 말이 너무 짧거나 흔하면 대상이 못 된다
        if len(t) >= 2: cands.append(t)
    for m in re.finditer(r'[그저]\s*([가-힣A-Za-z][가-힣A-Za-z0-9 ]{1,12})', line):
        cands.append(m.group(1).strip())
    return [c for c in dict.fromkeys(cands) if c not in COMMON and len(c) >= 2]

# 🟥 표기 정규화 — 2026-08-21. **양쪽을 같은 규칙으로 벗겨야 한다.**
#    실측 사고: S20 의 «전부 정상» 이 S9 본문의 `전부 **«정상»**` 과 안 맞아 UNRESOLVED 로 떨어졌다.
#    대상어는 뽑을 때 이미 강조·인용을 벗기는데 본문은 안 벗겨서, **한쪽만 정규화된 비교**였다.
#    (이 저장소가 이름 붙인 「관대함 갈린 중복 정규화」의 한 팔짜리 형태다.)
#    ⚠️ 넓히는 방향의 수정이라 오탐이 늘 수 있다 — 그래서 known-pair 양팔 + 기존 판정 불변을
#    같이 잰다. 공백은 **접지 않는다**: 접으면 서로 다른 어절이 붙어서 새 오탐이 생긴다.
_MARKUP = re.compile(r'[*`«»""\u201c\u201d\u2018\u2019\'"「」]')

def _norm(t):
    return _MARKUP.sub('', t)

def find_owners(term, all_units, self_sid):
    t = _norm(term)
    if len(t) < 2: return []
    return [sid for sid, head, body, _r in all_units
            if sid != self_sid and (t in _norm(body) or t in _norm(head))]

def wired_ids(builder):
    src = open(builder, encoding='utf-8').read()
    m = re.search(r'^NOTE_MAP\s*=\s*\{', src, re.M)
    if not m: raise RuntimeError('NOTE_MAP 미발견')
    start, depth = m.end() - 1, 0
    for i in range(start, len(src)):
        if src[i] == '{': depth += 1
        elif src[i] == '}':
            depth -= 1
            if depth == 0:
                return {v[0] for v in ast.literal_eval(src[start:i+1]).values() if v[0]}
    raise RuntimeError('NOTE_MAP 괄호 불균형')

def analyze(draft, builder, show_all=False):
    """계산부 — 출력하지 않는다. 레인 배선이 이걸 부른다(main 은 이걸 «찍기만» 한다).

    🟥 로직을 복제하지 않으려고 뺀 것이다. CLI 와 레인이 각자 계산하면
    관대함이 갈려서 한쪽만 통과하는 입력이 조용히 생긴다.
    반환: dict(error, n_units, n_retired, n_wired, edges, broken, unresolved)
    """
    try:
        us = units(open(draft, encoding='utf-8').read())
        wired = wired_ids(builder)
    except Exception as e:
        return {'error': f'{e}', 'edges': [], 'broken': [], 'unresolved': []}
    if not us:
        return {'error': '절 0건 — 포맷 불일치', 'edges': [], 'broken': [], 'unresolved': []}

    live = [u for u in us if not u[3]]
    broken, edges, unresolved = [], [], []
    for i, (sid, head, body, _r) in enumerate(live):
        screen, speech = blocks(body)
        hard, soft = classify_unit(screen, speech)
        # 선행자 = 바로 앞의 «살아있는» 절. 화면 재사용/시각 지시는 직전 화면을 가리킨다.
        prev = live[i-1][0] if i > 0 else None
        if hard:
            # 지시 대상을 실제로 찾는다 (추정 금지)
            verdict, owners_found, terms_tried = 'UNRESOLVED', [], []
            for _k, ln in hard:
                for term in referents(ln):
                    terms_tried.append(term)
                    owners = find_owners(term, us, sid)
                    if not owners: continue
                    owners_found += owners
                    if any(o in wired for o in owners):
                        verdict = 'OK'; break
                    verdict = 'BROKEN'
                if verdict == 'OK': break
            edges.append((sid, sorted(set(owners_found)) or ['?'], 'HARD', hard, verdict))
            if verdict == 'BROKEN':
                broken.append((sid, sorted(set(owners_found)), hard))
            elif verdict == 'UNRESOLVED':
                unresolved.append((sid, terms_tried[:4], hard))
        if soft and show_all:
            edges.append((sid, ['-'], 'SOFT', soft, 'n/a'))

    return {'error': None, 'n_units': len(us), 'n_retired': len(us) - len(live),
            'n_wired': len(wired), 'edges': edges, 'broken': broken, 'unresolved': unresolved}


def main():
    if len(sys.argv) < 3: print(__doc__); return 2
    draft, builder = sys.argv[1], sys.argv[2]
    show_all = '--all' in sys.argv
    r = analyze(draft, builder, show_all)
    if r['error']:
        print(f'❌ INSTRUMENT ERROR: {r["error"]}  (미측정이지 0 이 아니다)'); return 2

    edges, broken, unresolved = r['edges'], r['broken'], r['unresolved']
    print(f'절 {r["n_units"]} (은퇴 표기 {r["n_retired"]}) · 배선 {r["n_wired"]}')

    print(f'\nHARD 의존 {sum(1 for e in edges if e[2]=="HARD")}건'
          + (f' · SOFT(수사) {sum(1 for e in edges if e[2]=="SOFT")}건' if show_all else ''))
    for sid, owners, kind, ev, verdict in edges:
        mark = {'BROKEN': '🟥', 'OK': '🟢', 'UNRESOLVED': '⚠️'}.get(verdict, '·')
        print(f'  {mark} {sid} → {",".join(owners)} [{kind}/{verdict}]')
        for k, ln in ev[:2]: print(f'        {k}: {ln}')

    if unresolved:
        print(f'\n⚠️ 지시 대상 UNRESOLVED {len(unresolved)}건 — 의존 표현은 있는데 대상을 못 찾았다.')
        print('   🟥 이건 «안 깨졌다»가 아니라 **미측정**이다. 사람이 봐야 한다.')
        for sid, terms, _ in unresolved: print(f'   {sid}: 시도한 대상어 {terms}')
    if broken:
        print(f'\n🟥 깨진 의존 {len(broken)}건 — 선행 장이 배선에 없다(그 화면이 산출물에 없다)')
        for sid, prev, _ in broken: print(f'   {sid} 가 {prev} 를 필요로 하는데 {prev} 는 안 만들어진다')
    else:
        print('\n🟢 깨진 의존 0 — HARD 의존의 선행 장이 전부 배선돼 있다')
    return 1 if broken else 0


# 🟥 가드 필수 — 이게 없으면 import 하는 쪽에서 프로세스가 죽는다(레인 배선 불가).
if __name__ == '__main__':
    sys.exit(main())
