"""L11 promise — **앞에서 예고한 것이 뒤에서 상환되나** (후보 나열, 판정은 사람).

## 실사고

- 수량 약속: S6 이 «세 번» 을 예고했는데 본편 상환이 **1건**이었다.
- 주제 약속: §2→§3 전환문이 «가속» 을 약속했는데 §3 은 **정의와 비용 정직만** 냈다.
둘 다 콜드리더가 잡았다. 기존 체크리스트는 «결론이 첫 질문에 답하는가»만 봐서, **중반 티저의
미상환**은 구조적으로 안 잡혔다.

## 🟥 판정하지 않는다 — 이 레인은 «채널»이지 «결론»이 아니다

«무엇이 상환으로 쳐지는가»는 의미 판정이고, 코드로 굳히면 오늘의 판단이 내일의 천장이 된다.
그래서 이 레인은 **예고를 찾아 나열하고, 그 뒤에 대상어가 몇 번 나오는지 세기만** 한다.
숫자가 맞아도 상환이 아닐 수 있고, 숫자가 달라도 상환일 수 있다 — **판정은 사람이 한다.**
선례: `ko-tech-writer` Step 4-b(전칭 단정 후보 검출 — 오탐 허용, 판정은 사람).

🟥 **advisory 고정.** 오탐의 최저비용 무마가 «예고 문장을 지우는 것»이라 종료코드에 태우면
원고를 나쁜 방향으로 민다 — L8 과 같은 이유다.

## 오탐이 어디서 나나 (미리 적는다)

대상어 추출이 약하다. 「세 번」 앞의 명사를 집는 단순 규칙이라 조사·수식이 붙으면 빗나간다.
**빗나가면 대상어 없이 예고만 낸다** — 그게 «못 찾았다»를 «없다»로 접는 것보다 낫다.
"""
import re

# 수량 예고: 「세 번」 「두 가지」 「네 개」 — 아라비아 숫자와 한글 수사 둘 다.
_QUANT = re.compile(r'(한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|[0-9]+)\s*(번|가지|개|축|단계)')
# 시점 예고: 뒤에서 다룬다는 신호
_FWD = ('뒤에서', '나중에', '곧 ', '잠시 후', '이따', '뒤이어', '다음에 ', '말씀드리겠', '보시겠')
# 대상어 후보: 수량 앞의 한글 덩어리
# 🟥 조사를 반드시 떼어낸다. 초판은 `([가-힣]{2,10})` 이 탐욕적이라 «실패를» 을 통째로 집었고,
#    그걸로 세니 뒤에 「실패는」 이 세 번 나와도 **0회**가 나왔다 — 두 픽스처가 같은 답을 내서
#    판별력이 0 이었다. 조사 목록을 명시 그룹으로 빼야 어간이 남는다.
_HEAD = re.compile(r'([가-힣]{2,10}?)(?:을|를|은|는|이|가|의|도|만)?\s*$')
# 🟥 서수는 예고가 아니라 **상환 그 자체**다 — 「두 번째 실패는…」 은 약속이 아니다.
#    안 거르면 상환 문장이 미상환 후보로 계상돼 방향이 거꾸로 된다.
_ORDINAL = re.compile(r'(한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|[0-9]+)\s*번째')


def _lines(text):
    for i, ln in enumerate(text.split('\n'), 1):
        s = ln.strip().lstrip('>').strip()
        if s:
            yield i, s


def scan(texts, surf_meta, max_report=8):
    spoken = [sid for sid, m in surf_meta.items() if m.get('spoken')]
    if not spoken:
        return [], ['L11 promise : 낭독면 선언 0 — UNMEASURED (0 아님)']
    notes = []
    for sid in sorted(spoken):
        text = texts[sid][0]
        rows = list(_lines(text))
        promises = []
        for idx, (no, s) in enumerate(rows):
            if _ORDINAL.search(s):
                continue                      # 상환 문장을 예고로 세지 않는다
            m = _QUANT.search(s)
            fwd = any(w in s for w in _FWD)
            if not m and not fwd:
                continue
            head = None
            if m:
                pre = s[:m.start()]
                hm = _HEAD.search(pre)
                head = hm.group(1) if hm else None
            after = '\n'.join(x[1] for x in rows[idx + 1:])
            cnt = after.count(head) if head else None
            promises.append((no, s, m.group(0) if m else '(시점 예고)', head, cnt))
        if not promises:
            notes.append(f'L11 promise : {sid} — 예고 후보 0. '
                         '⚠️ «약속이 없다»가 아니라 «이 패턴으로는 안 잡혔다»이다')
            continue
        notes.append(f'L11 promise : {sid} — 예고 후보 {len(promises)}건 '
                     f'🟥 advisory, 상환 여부는 사람이 판정한다 (아래 최대 {max_report})')
        for no, s, q, head, cnt in promises[:max_report]:
            if head is None:
                tail = '대상어 추출 실패 — 사람이 본다 (없다고 접지 않는다)'
            elif cnt == 0:
                tail = f'🟥 뒤에서 «{head}» 가 **0회** — 상환 안 됐을 수 있다'
            else:
                tail = f'뒤에서 «{head}» {cnt}회 — 예고({q})와 맞나'
            notes.append(f'   · {no}: «{s[:60]}» ▸ {q} ▸ {tail}')
        if len(promises) > max_report:
            notes.append(f'   … 외 {len(promises) - max_report}건')
    return [], notes
