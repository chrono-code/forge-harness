"""L9 prose-candidates — ko-tech-writer 의 «기계화 가능한 절반» 이식분.

## 왜 이 레인이 있나

preprep 의 레인 여덟은 전부 **구조·사실** 축이다 — 금지 인용, 참조 정합, 표면 존재,
왕복 무변경, 조어 풀이 «여부», 장당 발화 «수», 재생성 삼킴, 장 사이 의존.
🟥 **문장이 읽히는가를 보는 레인이 하나도 없었다.** 그 구멍은 FH 가 이미 이름 붙인 것이다:
«정적 검사는 「없는 것」을 잡고 「안 읽히는 것」은 못 잡는다» (독립 실측 2건 수렴).

이식 원본 = `plugins/fh-commons/skills/ko-tech-writer/SKILL.md` Step 2 · Step 4-b.
그 문서가 **스스로 기계 5 / 판단 2 로 갈라 놨고**, 이 파일은 기계 쪽만 가져온다.
판단 쪽(레지스터 드리프트 · 내부 조어 · 캘리브레이션 · 지각 QA)은 코드가 아니라
그 스킬을 불러서 한다 — 판정을 코드로 굳히면 오늘의 판단이 내일의 천장이 된다.

## 🟥 advisory 고정 — findings 를 내지 않는다

L8 이 advisory 인 이유가 여기 그대로 적용된다: 이 계기의 오탐을 **최저비용으로 무마하는
길이 「그 문장을 지우는 것」**이라, 종료코드에 태우면 원고를 나쁜 방향으로 미는 압력이 된다.
후보를 내고 판정은 사람이 한다. 오탐 다수가 정상이다.

## 안 한 것을 이름으로 남긴다 (부재 ≠ 0)

원본 Step 2 의 일곱 클래스 중 **둘은 기계화하지 않았다**:
  · 콜론 나열투 — 「서술어 없는 `:` 도입」은 서술어 판정이 필요하다
  · 조각문       — 「서술어 없는 마침」도 같다
한국어 서술어 판정을 정규식으로 흉내내면 오탐이 본문을 덮는다. **못 해서가 아니라
안 한 것**이고, 이 목록이 그 사실을 나른다 — 0 을 「그 클래스가 없다」로 읽지 마라.
"""
import re

# ── 기계 검출 클래스 (ko-tech-writer Step 2) ──────────────────────────────
# 각 항목: (클래스명, 정규식, 수리 방향)
STYLE = [
    ('줄표 이어붙임', re.compile(r'(다 — |것 — |음 — )'),
     '문장 분리. 줄표는 «일을 하는 곳»만 남긴다(열거 매달기·리듬 결속)'),
    ('용어-머리 «**X** — »', re.compile(r'^\s*[-*·]\s*\*\*[^*]+\*\*\s*—\s'),
     '«**X**: 설명» 콜론형으로'),
    ('소유 직역', re.compile(r'(을 갖|를 갖|을 가지|를 가지)'),
     '존재문으로 — «이전 상태를 갖지 않는다» → «이전 상태가 없다». 소유가 실제 논점인 자리는 남긴다'),
]

# ── 전칭 단정 후보 (Step 4-b) ─────────────────────────────────────────────
# 🟥 부정형이 별도인 이유는 실측이다: 어휘 목록에 없는 부정형 전칭("~을 안 만들었다")을
#    같은 세션에서 실제로 썼다. 어휘만으로 못 잡는 계열이 실재한다.
# 🟥 어휘는 원본(ko-tech-writer Step 4-b)에 «적힌 것만» 쓴다. 초안은 여기에 `항상|절대` 를
#    임의로 보탰다가 걷어냈다 — 그 파일의 유지 규칙이 «실측 근거가 없는 클래스를 추가하지
#    않는 것»이라고 못박는데, 이식하면서 그걸 어긴 것이었다. 넓히려면 실측을 먼저 대라.
UNIVERSAL_LEX = re.compile(r'(전부|모두|하나도 없|전혀|일절|예외 없이)')
UNIVERSAL_NEG = re.compile(r'((안|못) ?(했|만들|나오|잡히)|지 않았(다|습니다))')

# 🟥 USE ↔ MENTION 을 이 레인은 못 가른다 — 「전부」를 «쓴 줄»과 「'전부'라고 쓰지 마라」고
#    «적은 줄»이 같이 걸린다. preprep 의 L1 이 같은 자리에서 두 부류로 갈라 내는데, 여기서는
#    갈라내지 않는다: 이 레인은 이미 advisory 라 판정이 사람 몫이고, 필터를 하나 더 얹으면
#    «죽은 필터가 진짜를 죽이는» 쪽 위험이 더 크다. 실측으로 확인된 한계로 남긴다
#    (known-negative 픽스처 초판이 자기 헤더의 언급에 걸렸다).
NOT_MECHANIZED = ['콜론 나열투 (서술어 없는 `:` 도입)', '조각문 (서술어 없는 마침)']


def _lines(text):
    return text.split('\n')


def scan(texts, surf_meta, max_per_class=6):
    """(findings, notes) — findings 는 **항상 빈 리스트**다(advisory 고정).

    대상은 «사람이 읽는 면»뿐이다: 낭독면(spoken) + markdown 문서.
    pptx XML·note_map·figure_source 는 사람이 읽는 산문이 아니라 섞으면 오탐이 된다.
    """
    notes, hits = [], {}
    scanned = []
    for sid, (text, kind) in sorted(texts.items()):
        if not (surf_meta.get(sid, {}).get('spoken') or kind == 'markdown'):
            continue
        scanned.append(sid)
        for i, ln in enumerate(_lines(text), 1):
            for name, pat, fix in STYLE:
                if pat.search(ln):
                    hits.setdefault(name, []).append((sid, i, ln.strip()[:70], fix))
            if UNIVERSAL_LEX.search(ln):
                hits.setdefault('전칭 단정 (어휘)', []).append(
                    (sid, i, ln.strip()[:70], '반례를 실제로 찾아봤나 — 근거를 다시 대조'))
            if UNIVERSAL_NEG.search(ln):
                hits.setdefault('전칭 단정 (부정형)', []).append(
                    (sid, i, ln.strip()[:70], '어휘 목록에 안 걸리는 계열 — 반례 대조'))

    if not scanned:
        return [], ['L9 prose : 사람이 읽는 면 0 — UNMEASURED (0 아님)']

    notes.append(f'L9 prose : 스캔 {len(scanned)}면 ({", ".join(scanned)}) · '
                 f'후보 클래스 {len(hits)}종 · 총 {sum(len(v) for v in hits.values())}건 '
                 f'— 🟥 advisory, 판정은 사람')
    for name, rows in sorted(hits.items()):
        notes.append(f'   ▸ {name} — {len(rows)}건 (아래 최대 {max_per_class})')
        for sid, i, snippet, fix in rows[:max_per_class]:
            notes.append(f'      {sid}:{i}  «{snippet}»  ▸ {fix}')
        if len(rows) > max_per_class:
            notes.append(f'      … 외 {len(rows) - max_per_class}건 (전량은 --prose-all)')
    notes.append('   ⚠️ 기계화 안 한 클래스(부재 ≠ 0): ' + ' · '.join(NOT_MECHANIZED))
    notes.append('   ⚠️ 판단 클래스(레지스터 드리프트 · 내부 조어)는 이 레인이 못 본다 — '
                 'ko-tech-writer 스킬로 라우팅해라')
    return [], notes
