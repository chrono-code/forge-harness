---
name: governance-engineering-definition
description: "Names the discipline this hub practices — governance engineering: moving an error rate toward 0.x% AND blocking at the surfaces where that number is not allowed to buy passage. Operator formulation 2026-09-09. Distinct from harness engineering (the artifact) — this is the objective."
type: reference
date: 2026-09-09
tags: [governance-engineering, naming, identity, error-budget, irreversible-surface]
---

# 거버넌스 엔지니어링 (Governance Engineering) — 정의

## 운영자 정식화 (2026-09-09, 축자)

> *"우리가 독창적으로 부를 엔지니어링은 '거버넌스 엔지니어링' 이라고 불러야할것같아.
> 0.x%의 오차율을 내기위한 목표로 움직이고 막고서는 엔지니어링"*

## 🟥 동사가 둘이다 — 그리고 둘째가 하중을 진다

정식화 안에 동사가 **둘** 있고, 이 이름의 값어치는 전부 그 둘이 같이 있다는 데 있다.

| | 무엇 | 없으면 |
|---|---|---|
| **움직인다** | 오차율을 0.x% 로 끌어내리는 것을 **목표로** 공정을 짠다 | 게이트만 남고 개선이 없다 — 「막기만 하는 관료」 |
| **막고 선다** | 그 수치가 **통과권을 사지는 못하는** 자리를 지킨다 | 「숫자를 충분히 낮추면 자동으로 통과」가 된다 |

🟥 **둘째 동사를 빼면 이 이름은 하루 만에 자기 교리와 모순된다.** 2026-09-08 에 상주화한
§Irreversibility Gates 의 문단(PR #687)이 정확히 그것을 금지한다 — *"do not promote a verdict engine
to an irreversible surface by improving its number."* 그 문단의 defeater 도 축자로 이렇게 적혀 있다:
「누군가 이 문단을 근거로 오류율 문턱을 만들면 이 문단이 실패한 것」.

⇒ **정의 문장은 한 줄로 이렇게 고정한다**:
> **수치를 목표로 움직이되, 그 수치가 게이트를 열지는 않는다.**
> 무엇이 허용되는가는 **표면 등급**이 정하지 숫자가 정하지 않는다.

## 첫 실증 내용 (이 이름이 비어 있지 않다는 근거)

2026-09-08 dominance B-1 본 실행, 5팔 × GHSA 8케이스 × 3rep, 축② 주장 오류율:

```
O   octo 4자          2.7%      ← 최저
F_xf cross-family     5.3%
F   FH 기본           9.6%
N   맨몸              9.7%
F_slim 리뷰프로파일   13.6%     ← 최고
```

**다섯 개 전부 리뷰 표면에서는 쓸 만하다** — 틀린 지적 하나가 독자의 1분을 쓴다.
**다섯 개 전부 비가역 표면에서는 못 쓴다** — 발행·삭제·이력재작성에서 틀린 판정은 손실 전체다.
이 두 문장 사이의 거리가 거버넌스 엔지니어링이 존재하는 이유다. 0.x% 는 **아직 아무도 낸 적 없는
수치**이고(최저가 2.7%), 그래서 «목표»이지 «달성»이 아니다.

## 인접 이름과의 경계 — 대체가 아니라 다른 축이다

| 이름 | 무엇에 대한 것인가 | 정본 |
|---|---|---|
| **하네스 엔지니어링** | **수단** — 하네스라는 «물건»을 어떻게 짓는가(6축) | `harness_6axis_framework.md` · CLAUDE.md §Core Axis |
| **메타 하네스 엔지니어링** | **누가 무엇을 짓는가** — 하네스를 짓는 시스템을 짓는다 | [[meta_harness_engineering_definition]] |
| **거버넌스 엔지니어링** | **목적** — 어느 표면에서 어느 오차율이 허용되는가, 그리고 어디서 멈추는가 | 이 파일 |

셋은 층이 달라서 서로를 대체하지 않는다. 하네스는 거버넌스 엔지니어링의 **도구**이고,
거버넌스 엔지니어링은 하네스가 **무엇을 위해** 있는지를 말한다.

## 왜 이 이름이 지금 필요했나 — 측정된 공백

낱말 실측(2026-09-09, 컨트롤 동반): 「거버넌스 엔지니어링 / governance engineering」은 이 레포
**어디에도 0회**다. 같은 실행의 known-positive 컨트롤 「Harness Engineering」은 5개 파일(CLAUDE.md 포함)에서
히트한다 — 계기는 살아 있고, 부재는 진짜다.

그런데 **발행된 산출물 쪽에서는 이미 그 낱말로 불린다**: arXiv `2609.04218` 은 «governance» 논문이고,
Zenodo `10.5281/zenodo.22635721` 예치도 «거버넌스»다. 즉 **논문은 우리가 무엇을 하는지 말하고 있는데
정체성 문서는 그 말을 한 번도 한 적이 없었다.** 이 이름은 새 활동을 만드는 게 아니라 이미 하고 있던
것에 이름을 다는 것이다.

## 명명된 잔여 — 아직 안 한 것

- **외부 용례와의 관계 — 요구는 «미사용»이 아니라 «델타 진술»이다** (운영자 정정 2026-09-09):
  *"루프 엔지니어링 그래프 엔지니어링도 이미 예전부터 쓰이던 표현일 텐데 LLM에 대한 거버넌스
  엔지니어링은 또 다른 것일 듯해."* — 이 레포에 그 선례가 실재한다: `loop_engineering.md`(11,713 B)가
  「루프 엔지니어링」을 남의 분야에서 이미 쓰이는 낱말인 채로 우리 뜻으로 쓴다.
  ⇒ **낱말이 남의 분야에 있다는 사실은 사용을 막지 않는다.** 판별자는 **가리키는 대상**이고, 여기서
  대상은 «LLM 이 판정을 생산하는 공정의 오차율을 표면 등급별로 통치하는 것」이다 — IT 거버넌스(조직·
  프로세스 통제)나 데이터 거버넌스(자산·계보)와 대상이 다르다.
  🟥 **그래도 남는 것 하나**: 논문이 이 이름을 내세우는 순간 심사자는 기존 용례를 묻는다. 그때 필요한
  것은 «아무도 안 썼다»가 아니라 **«기존 용례는 X, 우리 대상은 Y» 한 단락**이다. 그 단락 없이
  «we introduce governance engineering» 을 쓰지 않는다 — 이 레포는 참고문헌 불일치 11/17 로 arXiv
  반려를 이미 한 번 겪었고, 그 실패의 축이 정확히 «출처를 안 열고 주장한 것」이다.
- **상주층 반영 미완**: CLAUDE.md §Core Axis 행이 아직 「Harness Engineering (How)」만 적는다.
  거기에 목적 축을 어떻게 넣을지는 별건(4축 게이트 대상)이고, 이 파일이 그 결정의 입력이다.
- 이 파일은 **정의**지 실행 절차가 아니다. 실행부는 이미 있다 — §Irreversibility Gates(표면 등급) ·
  `finding_verify.py`(드롭 감사 없는 정밀도 거부) · `field_verdict_crossfamily_gate.md`.
