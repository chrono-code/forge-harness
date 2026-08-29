"""L9 progression — **선언된 단계 중 하나가 화면에서 빠졌나.**

## 실사고 (이 레인의 존재 근거)

원고가 slide 17~20 에 **단계적 확장**을 깔았다:
  ① 좋아진다 → ② 그래도 남는다 → ③ 더 늘려도 안 된다 → ④ 입장을 바꾸면 보인다
그런데 **①이 화면에서 빠졌고**, 리뷰어가 논지를 **정반대로** 읽었다.

🟥 **개별 문장은 전부 옳았다.** 압축 과정에서 첫 칸이 떨어진 것이라 문장 층 교정으로는
구조적으로 안 잡힌다. 원문의 처방: *«리뷰어가 요약한 뜻이 저자 의도와 반대인가»를 물어야
잡힌다.* 그 질문의 **기계로 되는 절반**이 이 레인이다.

## 무엇을 재고 무엇을 안 재나

- 잰다   — 사람이 `surfaces.yaml` 에 **선언한** 단계 각각이, 그 단계가 놓이기로 한
           **화면 표면들 안에 실제로 있는가.** 있거나 없거나다. 애매하지 않다.
- 안 잰다 — «이 단계 구성이 좋은가» · «리뷰어가 옳게 이해했나». 그건 결론이고, 코드로
           굳히면 오늘의 판단이 내일의 천장이 된다. 되읊음 대조는 사람이 한다.

🟥 **L8(interslide) 과 다른 축이다.** L8 은 «가리킨 대상이 있나»(의존)를 보고, 이 레인은
«선언된 단계가 다 있나»(완결)를 본다. 실측으로 확인: `interslide_deps.py` 에 «단계»·«열거»
0 히트, «의존» 11 히트.

## 왜 advisory 가 아니라 차단인가

L8·구 L9(prose)는 오탐의 최저비용 무마가 «그 문장을 지우는 것»이라 advisory 였다. 여기는
다르다 — **사람이 «이 넷은 한 세트다»라고 명시 선언한 것**만 검사한다. 선언이 없으면
`NOT_CONFIGURED`(0 아님)이고 아무것도 안 본다. 즉 오탐의 여지가 선언 자체에 갇혀 있고,
선언한 단계가 화면에 없는 것은 **애매하지 않은 사실**이다.
"""
import os


def scan(cfg, texts, surf_meta):
    """(findings, notes). 선언이 없으면 아무것도 안 본다 — 그리고 그걸 0 으로 안 읽는다."""
    specs = cfg.get('progressions')
    if not specs:
        return [], ['L9 progression : 선언 없음 — NOT_CONFIGURED (0 아님). '
                    '단계가 빠지면 논지가 뒤집히는 자리가 있으면 surfaces.yaml 에 선언해라']
    findings, notes = [], []
    for spec in specs:
        pid = spec.get('id', '?')
        steps = spec.get('steps') or []
        screens = spec.get('screens') or []
        if not steps or not screens:
            notes.append(f'L9 progression : {pid} — steps/screens 미기재, UNMEASURED (0 아님)')
            continue
        # 선언된 화면 중 실제로 읽힌 것만 합친다. 못 읽은 화면은 «없음»이 아니라 미측정이다.
        present, unread = [], []
        for sid in screens:
            if sid in texts:
                present.append(sid)
            else:
                unread.append(sid)
        if unread:
            notes.append(f'L9 progression : {pid} — 선언된 화면 {unread} 를 못 읽었다 '
                         f'(UNMEASURED — 이 단계들의 «없음»은 판정하지 않는다)')
        if not present:
            notes.append(f'L9 progression : {pid} — 읽힌 화면 0, 판정 불가 (0 아님)')
            continue
        blob = '\n'.join(texts[sid][0] for sid in present)
        missing = []
        for i, st in enumerate(steps, 1):
            anchor = st.get('anchor') if isinstance(st, dict) else str(st)
            if not anchor:
                notes.append(f'L9 progression : {pid} 단계 {i} — anchor 비어 있음, UNMEASURED')
                continue
            if anchor not in blob:
                missing.append((i, anchor, st.get('why') if isinstance(st, dict) else None))
        notes.append(f'L9 progression : {pid} — 단계 {len(steps)} · 화면 {len(present)}면'
                     + (f' · 미측정 화면 {len(unread)}' if unread else '')
                     + f' · 화면에 없는 단계 {len(missing)}')
        for i, anchor, why in missing:
            findings.append((f'{pid}:L9', 'PROGRESSION-GAP', f'step{i}', anchor,
                             '선언된 단계가 화면에 없다 — 압축에서 떨어졌나. '
                             '🟥 개별 문장이 다 옳아도 논지가 뒤집힌다'
                             + (f' ▸ {why}' if why else '')))
    if not findings:
        notes.append('   🟢 선언된 단계가 전부 화면에 있다. '
                     '⚠️ 이것은 «구성이 좋다»가 아니라 «선언한 것이 안 빠졌다»이다')
    return findings, notes
