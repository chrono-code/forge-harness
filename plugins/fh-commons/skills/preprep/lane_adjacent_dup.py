"""L10 adjacent-dup — **인접 장 대본이 같은 문장을 다시 읽나.**

## 실사고

한 장을 여러 프레임으로 쪼개면 대본도 갈라야 한다. 뒤 프레임에 원본을 **통째로** 남기면
앞 장에서 이미 읽은 문장을 다시 읽는다. 실측: 규율 상세를 두 프레임으로 쪼갤 때 앞
프레임엔 뒷부분만 넣고 뒤 프레임엔 원본을 통째로 남겨 **117자 중 82자가 중복**이었다.

## 왜 «인접» 인가

빌드 프레임은 **붙어 있다.** 멀리 떨어진 두 장이 같은 문장을 쓰는 것은 수미상관이거나
의도된 반복일 수 있고, 그건 취향이다. 붙어 있는 두 장이 같은 문장을 읽는 것은 대개
**쪼개다 만 것**이다. 그래서 창을 인접으로 좁힌다 — 넓히면 오탐이 취향을 침범한다.

## 구조는 범용 · 임계는 발표마다 다르다

이 코퍼스의 지배적 형태가 «규칙(A)과 값(B)이 한 줄에 붙어 있고 값이 규칙을 타고 넘는»
것이라, 여기서는 **갈라 놓는다**: 「인접 장 중복 자수를 재고 임계를 넘으면 낸다」가 구조이고,
임계값은 `surfaces.yaml` 에 사람이 적는다. 미기재면 **재기만 하고 판정하지 않는다**.

🟥 재사용: 절 분할과 🖥/🗣 분리는 `interslide_deps` 의 `units()`·`blocks()` 를 그대로 쓴다.
   그 함수들은 원고의 **주석 블록**(🟥·실측·2026-0…)을 이미 배제한다 — 안 배제하면 정정
   기록이 낭독으로 계상돼 known-negative 가 통째로 실패한다(런 #14 에서 실제로 겪었다).
"""
import re

_SENT = re.compile(r'[^.!?。…\n]+[.!?。…]?')


def _sentences(text):
    """문장 후보. 짧은 조각은 버린다 — 「네.」 같은 것이 인접 장마다 있는 건 중복이 아니다."""
    out = []
    for raw in _SENT.findall(text or ''):
        s = raw.strip().lstrip('>').strip()
        if len(s) >= 12:          # 임계 미만은 상투어라 신호가 아니다
            out.append(s)
    return out


def scan(cfg, texts, surf_meta, mod):
    """(findings, notes). mod = interslide_deps 모듈(units/blocks 재사용)."""
    spec = cfg.get('adjacent_dup') or {}
    limit = spec.get('max_dup_chars')          # 사람이 적는다. 없으면 재기만 한다
    spoken = [sid for sid, m in surf_meta.items() if m.get('spoken')]
    if not spoken:
        return [], ['L10 adjacent-dup : 낭독면 선언 0 — UNMEASURED (0 아님)']
    findings, notes = [], []
    for sid in sorted(spoken):
        text = texts[sid][0]
        us = [u for u in mod.units(text) if not u[3]]      # 은퇴 절 제외
        if len(us) < 2:
            notes.append(f'L10 adjacent-dup : {sid} — 절 {len(us)}개, 인접 쌍 없음 (0 아님)')
            continue
        speeches = []
        for uid, _head, body, _r in us:
            _screen, speech = mod.blocks(body)
            # 🟥 `blocks()` 는 리스트가 아니라 **문자열**을 돌려준다. 초판이 join 을 걸어
            #    글자 사이에 개행을 끼워 텍스트를 부쉈고, 그 결과 «인접 쌍 0» 이 나왔다 —
            #    계기가 조용히 «중복 없음» 을 보고한 형태다(부재가 아니라 파손).
            speeches.append((uid, _sentences(speech if isinstance(speech, str)
                                             else '\n'.join(speech))))
        pairs = dup_total = 0
        for (a_id, a), (b_id, b) in zip(speeches, speeches[1:]):
            if not a or not b:
                continue
            pairs += 1
            shared = [s for s in b if s in a]
            n = sum(len(s) for s in shared)
            if not shared:
                continue
            dup_total += n
            total_b = sum(len(s) for s in b) or 1
            pct = round(100 * n / total_b)
            msg = (f'{a_id}→{b_id} 인접 두 절이 같은 문장 {len(shared)}개를 다시 읽는다 '
                   f'({n}자 / 뒤 절 {total_b}자 = {pct}%) ▸ 쪼갤 때 뒤 프레임에 원본을 '
                   f'통째로 남겼나 ▸ «{shared[0][:50]}»')
            if limit is None:
                notes.append(f'   · {msg}  🟥 임계 미기재 — 재기만 하고 판정 안 한다')
            elif n > limit:
                findings.append((f'{sid}:{b_id}', 'ADJACENT-DUP', a_id, f'{n}자', msg))
            else:
                notes.append(f'   · {msg}  (임계 {limit}자 이하 — 판정 안 함)')
        notes.append(f'L10 adjacent-dup : {sid} — 인접 쌍 {pairs} · 중복 총 {dup_total}자'
                     + (f' · 임계 {limit}자' if limit is not None
                        else ' · 🟥 임계 미기재(surfaces.yaml adjacent_dup.max_dup_chars) — 판정 안 함'))
    return findings, notes
