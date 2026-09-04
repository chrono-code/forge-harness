#!/usr/bin/env python3
"""R1~R5 — 장 사이·장 안의 «관계» 검사 다섯. the private companion store's origin script (lane_slide_relations.py
(2026-09-04, 실사용 하루치에서 역산)를 preprep 관례로 이식한 것 — 로직은 그대로다.
정본: `tracks-meta/fh_signal_2026-09-04_preprep-evolution.md` §1.

preprep L8(interslide) 은 «가리킨 대상이 있나»(화면 재사용 · 시각 지시)를 본다. 아래 다섯은
그 사정거리 밖에서 실제로 놓친 결함이다(L8 HARD 목록에 그 장들이 아예 안 뜬다).

  R1 orphan-connective  선두 줄이 «그러나/그래서»로 시작하는데, 그 문장의 주어가
                        **직전 장 어디에도 없다** → 받을 말 없이 뒤집는다
                        실사고: 40p 부제 «그러나 깃허브는 막을 자리를 줄 뿐…» (39p 에 깃허브 0회)

  R2 enum-dropped       앞 장이 ①②③ 으로 센 것을, 이 장이 «이 셋 중…» 이라 부르면서
                        **번호를 하나도 안 달았다** → 1:1 대응이 안 보인다
                        실사고: 40p 가 38·39p 의 셋을 소유권으로 재편하며 번호를 버렸다
                        (원장 재현 결과 41p — 표 이웃 프레임이라 쪽수가 한 칸 어긋난다)

  R3 lead-term-unbacked 선두 줄이 **강조색으로 선언한 낱말**이 그 장 다른 어디에도 없다
                        → 화면이 자기 부제를 못 받친다
                        실사고: 20p 부제가 «방법론» 을 말하는데 장에 방법론이 없었다

  R4 screen-heavy       화면 자수가 이 덱 자기 분포의 상위권 → 한 장에 너무 많이 얹었다
  R5 read-load          **직전 장 대비 새로 뜬 글자** ÷ 발화 초 — 화면은 늘었는데 말은 짧다.
                        🟥 대사만 줄이고 화면을 그대로 두면 이 값이 올라간다. 그게 역효과다.
                        🟥 «새로 뜬 글자»로 재는 이유: 빌드 프레임은 앞 장에서 이미 읽은 화면이라
                           총 자수로 재면 44p(발화 4초·화면 240자) 같은 것이 1위로 뜬다 — 오탐이다.
                        🟥 **무대 지시**([간지]/[진행])는 발화로 세지 않는다 — 대본 자수 규칙과 같이
                           간다. 안 빼면 Q&A·참고문헌 장이 부담 1·4위로 잘못 오른다.

🟥 다섯 다 **advisory** 다. 판정은 사람이 한다. preprep 배선(`preprep.py`)은 이 레인의
   findings 를 종료코드에 태우지 않는다 — L8·L11 과 같은 자리다.
🟥 강조색은 덱마다 다르므로 `surfaces.yaml` 의 `slide_relations.accent` 로 받는다
   (기본값 FAE100 — 원 코퍼스의 그 회사 옐로. 다른 덱에 옮기면 재선언해야 한다).

## 🟥 R3 «조이는 과정» — 옮길 때 반드시 같이 옮겨야 하는 것 (초판이 겪은 오탐 29건의 원인)

- **선두 줄 판별** — 「y 로 두 번째 도형」은 도해 라벨(「① 커밋할 때」류)을 문다.
  ⇒ 「제목 아래 · 가로로 길게 · 한 줄」(`y < LEAD_MAX_Y` · `w > LEAD_MIN_CX` · `cy < 1.2M`)로
  정의한다 — 아래 `Deck.lead()`.
- **강조 비교** — 통문장 부분일치는 조사 하나로 갈린다. ⇒ **조사 벗긴 낱말 집합** 교집합으로 본다
  (`strip_josa` + `terms`).
- **활용 어미 제외** — 「막고 서는」·「고친 것을 되돌려서」는 낭독 리듬이지 낱말 선언이 아니다
  (`VERBAL_END`).
- 🟥 **전역 빈도 필터를 R3 에 걸면 안 된다** — 「방법론」처럼 덱에 흔한 낱말이 **바로 이 장에서**
  빠지는 것이 결함인데, 흔하다는 이유로 걸러 진짜를 죽이게 된다. R3 는 「이 장 안에 있나」만 본다
  (R2 의 `distinct()` 전역빈도 필터와는 다른 자리다 — 섞지 않는다).
- **R2 는 세는 낱말을 «제목»에서만 찾는다** — 본문에서 찾으면 딴 「세 가지」에 물린다.

## 🟥 R5 는 «신규 글자»로 재야 한다 (총량으로 재면 뒤집힌다)

총 자수 기준이면 부담 1위가 **이미 앞 장에서 다 나온 빌드 프레임**으로 뒤집힌다 — 청중은 새로
안 읽는다. 직전 장 대비 신규분(`Deck.new_chars`)으로 재야 진짜가 남는다. 그리고 무대 지시를
발화로 세면 Q&A·참고문헌 장이 부담 상위에 잘못 오른다(`Deck.STAGE` 로 뺀다).

## R4·R5 임계 — 숫자를 코드에 박지 않는다

임계는 **이 덱 자기 분포**의 P90 에서 뽑는다(`statistics` + `sorted(...)[int(n*0.9)]`). 값은
발표마다 다시 재야 한다. ⚠️ **이 레인은 게이트가 아니라 순위표다** — 정의상 늘 그 덱의 상위
약 10%가 뜬다. 「후보 0건」을 목표로 삼지 마라.

## 증거 등급 (§7, 인용 전에 읽어라)

R1·R2 는 **실제 백업본**에서 뜬 결함이다. R3 는 **합성 뮤턴트**(사람이 실물 2장을 줄여 만든
`fixtures/fixture_R3_{positive,negative}.pptx`)로만 계량됐다 — 자연 발생본이 파일로 안 남았다.
**묶어서 「전부 실물」이라 쓰지 마라.** R4·R5 는 순위표라 known-pair 자체가 성립 형태가 다르다
(오탐/미탐이 아니라 「1위가 진짜인가」로 잰다). reps=1, 이 저장소 자기 바(≥3) 미달.
"""
import zipfile, re, os

CONNECTIVE = ('그러나', '하지만', '그런데', '그래서', '따라서', '그러므로', '반면')
ENUM = ('①', '②', '③', '④', '⑤', '첫째', '둘째', '셋째')
COUNT_WORD = re.compile(r'이\s*(셋|둘|넷|다섯)\s*중|(세|두|네|다섯)\s*가지|(셋|둘|넷)\s*중')
# 조사·흔한 낱말은 «대상»이 못 된다
STOP = set('것 수 때 곳 점 등 및 저희 우리 오늘 이번 발표 지금 여기 그것 이것 하나 자리 경우'.split())
TOKEN = re.compile(r'[가-힣A-Za-z][가-힣A-Za-z0-9]{1,11}')
JOSA = re.compile(r'(은|는|이|가|을|를|의|도|만|과|와|에|에서|으로|로|라는|처럼|보다)$')
# 활용 어미로 끝나면 «낱말 선언»이 아니라 문장 조각이다 (「막고 서는」 · 「고친 것을 되돌려서」)
VERBAL_END = re.compile(r'(는|은|고|서|며|야|지|다|까|나|면|아|어)$')


def strip_josa(t):
    for _ in range(2):
        t2 = JOSA.sub('', t)
        if t2 == t or len(t2) < 2:
            break
        t = t2
    return t


class Deck:
    """pptx 를 장 단위 텍스트+위치로 읽는다. 텍스트 레이어만 본다(이미지 구운 텍스트는 안 보인다)."""

    def __init__(self, path, accent='FAE100'):
        self.z = zipfile.ZipFile(path)
        self.accent = accent
        rels = dict(re.findall(r'Id="([^"]+)"[^>]*Target="slides/slide(\d+)\.xml"',
                                self.z.read('ppt/_rels/presentation.xml.rels').decode('utf-8')))
        lst = re.search(r'<p:sldIdLst>.*?</p:sldIdLst>',
                         self.z.read('ppt/presentation.xml').decode('utf-8'), re.S).group(0)
        self.order = [int(rels[r]) for r in re.findall(r'<p:sldId id="\d+" r:id="([^"]+)"/>', lst)]
        self.shapes = [self._shapes(sn) for sn in self.order]

    def _shapes(self, sn):
        x = self.z.read('ppt/slides/slide%d.xml' % sn).decode('utf-8')
        out = []
        for m in re.finditer(r'<p:sp>.*?</p:sp>', x, re.S):
            b = m.group(0)
            nm = re.search(r'name="([^"]*)"', b)
            o = re.search(r'<a:off x="(-?\d+)" y="(-?\d+)"/><a:ext cx="(\d+)" cy="(\d+)"', b)
            t = ' '.join(re.findall(r'<a:t>([^<]*)</a:t>', b)).strip()
            if not t:
                continue
            acc = [re.sub(r'<[^>]+>', '', r) for r in re.findall(
                r'<a:r><a:rPr[^>]*>(?:(?!</a:r>).)*?%s(?:(?!</a:r>).)*?<a:t>([^<]*)</a:t>'
                % self.accent, b, re.S)]
            out.append({'name': nm.group(1) if nm else '?',
                        'y': int(o.group(2)) if o else 0,
                        'w': int(o.group(3)) if o else 0,
                        'cy': int(o.group(4)) if o else 0,
                        'text': re.sub(r'\s+', ' ', t),
                        'accent': [a.strip() for a in acc if a.strip()]})
        return out

    STAGE = ('[간지]', '[진행]', '[ 간지', '[ 진행')

    def notes(self, i):
        p = 'ppt/slides/_rels/slide%d.xml.rels' % self.order[i]
        if p not in self.z.namelist():
            return ''
        m = re.search(r'notesSlide(\d+)', self.z.read(p).decode('utf-8'))
        if not m:
            return ''
        return re.sub(r'\s+', ' ', ' '.join(re.findall(
            r'<a:t>([^<]*)</a:t>',
            self.z.read('ppt/notesSlides/notesSlide%s.xml' % m.group(1)).decode('utf-8')))).strip()

    def spoken_sec(self, i):
        """발화 초. 🟥 무대 지시([간지]·[진행])는 발화가 아니다 — 대본 자수 규칙과 같이 간다."""
        n = self.notes(i)
        if not n or any(n.lstrip().startswith(t) for t in self.STAGE):
            return None
        return round(len(re.sub(r'\s', '', n)) / 5.36)

    def screen_chars(self, i):
        return sum(len(re.sub(r'\s', '', s['text'])) for s in self.shapes[i])

    def new_chars(self, i):
        cur = {s['text'] for s in self.shapes[i]}
        prev = {s['text'] for s in self.shapes[i - 1]} if i else set()
        return sum(len(re.sub(r'\s', '', t)) for t in cur - prev)

    def text(self, i):
        return ' '.join(s['text'] for s in self.shapes[i])

    # 선두 줄 = «제목 바로 아래에 가로로 길게 깔린 한 줄». 도해 라벨과 갈라야 한다
    #  🟥 초판은 «y 로 두 번째 도형»이라고 했다가 도해 안 라벨(「① 커밋할 때」)을 물었다.
    LEAD_MAX_Y, LEAD_MIN_CX = 4200000, 12000000

    def lead(self, i):
        sh = [s for s in self.shapes[i]
              if s['cy'] and s['name'] != 'sec-guide'
              and s['y'] < self.LEAD_MAX_Y and s['cy'] < 1200000
              and s['w'] > self.LEAD_MIN_CX]
        if not sh:
            return None
        sh.sort(key=lambda s: s['y'])
        return sh[-1]  # 제목이 위, 부제가 그 아래


def doc_freq(deck):
    from collections import Counter
    c = Counter()
    for i in range(len(deck.order)):
        for t in terms(deck.text(i)):
            c[t] += 1
    return c, len(deck.order)


def terms(txt):
    return {strip_josa(t) for t in TOKEN.findall(txt)
            if len(strip_josa(t)) >= 2 and strip_josa(t) not in STOP}


def analyze(deck):
    """계산부 — findings 만 낸다. 출력은 호출자(`scan`) 몫이다(interslide_deps.analyze 와 같은
    분리: CLI/레인이 각자 계산하면 관대함이 갈린다)."""
    F = []
    df, N = doc_freq(deck)

    def distinct(t):
        return df.get(t, 0) <= max(2, N * 0.15)

    for i in range(len(deck.order)):
        page, lead = i + 1, deck.lead(i)
        cur, prev = deck.text(i), deck.text(i - 1) if i else ''

        # ── R1 선두 줄의 접속 부사가 받을 말이 없다
        if lead:
            for c in CONNECTIVE:
                if not lead['text'].startswith(c):
                    continue
                rest = lead['text'][len(c):].strip()
                subj = next((strip_josa(t) for t in TOKEN.findall(rest)
                             if len(strip_josa(t)) >= 2 and strip_josa(t) not in STOP), None)
                if subj and subj not in prev:
                    F.append(('R1', page, f'선두 줄이 «{c}»로 뒤집는데 «{subj}»가 직전 장에 없다'
                                          f' ▸ {lead["text"][:60]}'))
                break

        # ── R2 앞 장이 번호로 센 것을 번호 없이 다시 묶는다
        title = min(deck.shapes[i], key=lambda s: s['y'])['text'] if deck.shapes[i] else ''
        # 🟥 세는 낱말이 «제목»에 있어야 한다. 본문에 있는 다른 「세 가지」에 물린다.
        if COUNT_WORD.search(title) and not any(e in cur for e in ENUM):
            for back in (1, 2, 3):
                if i - back < 0:
                    break
                ptxt = deck.text(i - back)
                if sum(e in ptxt for e in ENUM) < 2:
                    continue
                # 🟥 «가까이 번호가 있다»만으로는 안 된다 — 다른 「세 가지」에 물릴 수 있다.
                #    같은 셋을 다시 묶는 것인지는 **드문 낱말을 공유하는가**로 본다.
                shared = {t for t in terms(cur) & terms(ptxt) if distinct(t)}
                if len(shared) >= 3:
                    F.append(('R2', page, f'«이 셋/세 가지»라 부르는데 번호가 없다 — '
                                          f'{i - back + 1}p 가 번호로 센 것과 '
                                          f'«{", ".join(sorted(shared)[:4])}» 를 공유한다'))
                    break

        # ── R3 선두 줄이 강조로 선언한 낱말이 이 장 어디에도 없다
        if lead:
            body = ' '.join(s['text'] for s in deck.shapes[i] if s is not lead)
            btok = terms(body)
            for a in lead['accent']:
                # 🟥 통문장 부분일치로 보면 안 된다 — 조사 하나로 갈린다. 낱말 집합으로 본다.
                # 🟥 전역 빈도(distinct) 로 거르면 안 된다 — 흔한 낱말이 바로 이 장에서 빠지는
                #    것이 결함이다. 여기서 묻는 건 «이 장 안에 있나» 뿐이다.
                key = strip_josa(a.strip(' ,.·'))
                if VERBAL_END.search(key):
                    continue  # 활용형 강조는 낭독 리듬이지 «선언»이 아니다
                atok = terms(a)
                if not atok or len(a.strip()) > 14:
                    continue  # 긴 강조는 «선언»이 아니라 문장이다
                if not (atok & btok):
                    F.append(('R3', page, f'선두 줄이 «{a.strip()}»를 강조해 놓고 '
                                          f'장 안에 그 낱말이 없다'))

    # ── R4 / R5 — 임계는 «이 덱 자기 분포»에서 뽑는다. 숫자를 지어내지 않는다.
    import statistics
    sc = [deck.screen_chars(i) for i in range(len(deck.order))]
    if sc:
        p90 = sorted(sc)[int(len(sc) * 0.9)]
        for i in range(len(deck.order)):
            if sc[i] > p90:
                F.append(('R4', i + 1, f'화면 {sc[i]}자 — 이 덱 상위 10% '
                                       f'(중앙 {int(statistics.median(sc))}자 · P90 {p90}자)'))
    load = []
    for i in range(len(deck.order)):
        sec = deck.spoken_sec(i)
        if not sec or sec < 3:
            continue
        n = deck.new_chars(i)
        if n < 60:
            continue
        load.append((i, n, sec, n / sec))
    if load:
        lp90 = sorted(x[3] for x in load)[int(len(load) * 0.9)]
        med = statistics.median(x[3] for x in load)
        for i, n, sec, r in load:
            if r > lp90:
                F.append(('R5', i + 1, f'새로 뜬 {n}자를 {sec}초에 — {r:.1f}자/초 '
                                       f'(중앙 {med:.1f} · P90 {lp90:.1f}) ▸ 화면을 줄이거나 말을 늘려라'))
    return F


def _resolve(root, p):
    return os.path.normpath(os.path.join(root, os.path.expanduser(p)))


def scan(cfg, root):
    """preprep.py 가 부르는 레인 진입점. (findings, notes) — 🟥 **advisory 고정**:
    호출자는 findings 를 버리고 notes 만 취한다(L8·L11 관례). 여기서도 findings 를 채워
    반환은 하되, 그 자체가 «종료코드에 안 태운다»는 약속을 깨지 않는다 — 판단은 호출부에 있다.
    """
    deck_s = (cfg.get('surfaces_by_id') or {}).get('built_deck')
    if not deck_s:
        return [], ['R1-R5 slide-relations : built_deck 미선언 — NOT_CONFIGURED (0 아님)']
    path = _resolve(root, deck_s['path'])
    if not os.path.exists(path):
        return [], [f'R1-R5 slide-relations : built_deck 실물 없음({path}) — UNMEASURED (0 아님)']
    accent = (cfg.get('slide_relations') or {}).get('accent', 'FAE100')
    try:
        deck = Deck(path, accent=accent)
        F = analyze(deck)
    except Exception as e:
        return [], [f'R1-R5 slide-relations : 계기 오류({type(e).__name__}: {e}) — UNMEASURED (0 아님)']
    notes = [f'R1-R5 slide-relations : {len(deck.order)}장 · 후보 {len(F)}건 '
             f'🟥 advisory, 판정은 사람 (순위표 성격의 R4/R5 포함 — 「후보 0」을 목표로 삼지 마라)']
    for k, p, m in sorted(F, key=lambda x: x[1]):
        notes.append(f'   {k} {p:3}p {m}')
    return F, notes
