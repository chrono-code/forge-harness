# Red-team report — ISO/IEC 42119-7 형 (템플릿, 2026-09-05)

> **쓰는 자리**: cross-family 적대 리뷰(`auto-decorrelation` Step 4~6) · `/steel-quench` Wave-1 · challenger 디스패치의 **산출을 담는 형식**.
> 새 검사가 아니라 **이미 하는 것의 보고 형식**이다 — 개발 중인 ISO/IEC AWI TS 42119-7(AI 레드티밍)의 **공개 스코프가 다루는 주제**
> (용어 · 위험 식별 · 적용 범위 · 목표/공격 벡터 · 계획/실행 방법 · 문서/보고 · 수명주기 통합 — 🟥 규범 «요구사항」은 미공개, 이건 «다루는 주제」다)
> 를 우리 산출이 이미 갖고 있으니 **이름표만 맞춘다**. §4 의 «처분」은 이 레포의 로컬 프로세스이지 표준 스코프 항목이 아니다.
> 정본 crosswalk: `knowledge/shared/harness-core/iso_ai_standards_crosswalk.md §2` (42119-7 행).
>
> 🟥 이 형식은 «잘 했다」를 증명하지 않는다. 채널이다 — 칸이 비어 있으면 안 돌린 것이고, 채워져 있어도 진위는 마커/PR 의 그라운딩이 진다.

```
# RED-TEAM REPORT — <대상 한 줄>            date: YYYY-MM-DD   trigger: <4축 마커 트리거 / load-bearing gate / chamber / 요청>

## 0. 적용 범위와 용어 (applicability · terms)
대상      : <어느 AI 시스템/하네스의 어느 표면 — 코드·프롬프트·게이트·설정>
적용 범위 : <이 평가가 «보는」 것과 «안 보는」 것 한 줄씩>
용어      : <이 보고에서 S/A/B 가 뜻하는 것 · «fail-open」 등 국소 용어의 정의>

## 1. 위험 식별 (what could go wrong — 42119-7 "identification of risks")
표면      : <가역 / 비가역(publish·delete·history) / 소비자 가시>
실패 모드 : <이 변경이 틀렸다면 관측될 것 — 마커 defeater: 와 같은 문장>
AI 특성   : <비결정성 · 데이터 의존 · 적응성 · 불투명성 · 자율성 중 해당 — 없으면 «없음»>

## 2. 목표와 공격 벡터 (objectives & attack vectors)
목표      : S = <fail-open / 유출 / 차단 회피 … 이 대상에서 S 의 정의>  A = <과차단 / 오탐 / …>  B = 유지보수
공격 벡터 : <레지스트리 인용 — steel-quench Wave-1 각도 #n · 또는 프롬프트의 "attack specifically (1)…(n)" 목록 그대로>

## 3. 방법 (methodology — 29119 프로세스 정렬)
리뷰어    : <계열(codex/gemini/…) · 입장(cold / target-repo tier1b·tier2·tier2b·tier3) · 받은 것(diff만 / diff+주장 / 실행 출력)>
격리      : <리뷰어가 저자 추론을 봤나 — 안 봤다 / 봤다(사유)>
실행      : <리뷰어가 무엇을 실행했나 — 명령과 출력, 없으면 «정적»>
residency : <residency=CLEAN(files=n, stripped=m) — 스트립한 파일은 리뷰어에게 이름으로 알렸나>

## 4. 발견 (findings — 재현 입력을 반드시 함께) + 처분(로컬 프로세스)
| # | 심각도 | 위치(file:line) | 재현 입력 | 왜 | 처분(수리 / 반박 / 잔여) | 앵커(레인 id · fail-before) |
|---|---|---|---|---|---|---|

수리 n · 반박 n(각각 근거 한 줄) · 잔여 n(이름으로)

## 5. 수명주기 통합 (integration into the AI system life cycle)
어느 게이트에서 돌았나 : <pre-commit 4축 / Field-Harness Load-Bearing Change Gate / chamber SCREEN / 릴리스 전>
재실행 조건            : <이 표면이 다시 바뀌면 / 모델·계열이 바뀌면 / N 세션 뒤>
기록 위치              : <마커 crossfamily: · PR 본문 · fh_signal_*>
```

**채우는 규칙**
- §4 의 «재현 입력」 이 빈 발견은 발견이 아니라 의견이다 — 그 행은 처분 «반박」으로 가거나 지운다.
- «반박」은 근거 한 줄이 있어야 한다(실측이면 실측을, 계약이면 계약 문장을).
- 이 보고는 **마커를 대체하지 않는다**. 마커 `crossfamily:` 한 줄이 이 보고의 요약이고, 보고는 그 줄의 전개다.
