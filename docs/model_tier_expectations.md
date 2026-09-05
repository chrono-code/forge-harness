# 모델 등급 × 이폴트별 FH 기대 역량 — 무엇을 얻고, 무엇은 등급과 무관한가

> **읽는 사람**: FH 를 어느 모델·어느 이폴트(effort)로 돌릴지 정하려는 사용자.
> **한 줄**: FH 의 **기계 층**(훅·레인·게이트·마커 요구)은 등급과 무관하게 같은 것을 막고 같은 것을 요구한다. 등급이 바꾸는 것은 **판단 층** — 정체성을 «조합·응용»하는 폭과 스스로 결함을 잡는 깊이다. 그래서 base op 는 Sonnet 에서 100% 돌아야 하고(`sonnet_floor_doctrine.md`), 강한 모델은 그 위에서 **레버**를 더 얻는다.
> **정직성 규칙**: 아래 표의 모든 칸은 근거 등급을 단다 — **실측**(파일 인용) · **관측**(N=1, 주관 포함) · **기대**(미측정). 기대 칸을 실측처럼 인용하지 마라.

## 1. 등급별로 얻는 것

| 얻는 것 | Sonnet | Opus | Fable |
|---|---|---|---|
| **base op — 정체성 하나를 단독으로 쓰기**(감사·게이트·디스패치 한 건·마감 체인) | **100% 목표이자 규율** — 티어로만 발화하는 base op 는 결함이다 [실측: 야간 live-eval 프로브가 Sonnet 으로 돈다 · `sonnet_floor_doctrine.md`] | 동일 | 동일 |
| **지시된 조합 수행** — 거버너가 짜 준 브리프(정본·설계·known-pair·회신 경로)대로 패치·레인·보고 | 잘 한다 [실측 2026-09-05: 워크트리 패치 3건 accepted, 레인 fail-before/after 원문 첨부] — 단 **자기 패치의 구멍은 못 본다**(같은 날 거버너가 2건 적발: 워치독 고아 · 레인의 라이브 기록 덮어쓰기) | 한다 + 설계 밖의 것도 잡는다 [실측 2026-09-05: qasp 수리에서 설계가 못 본 셋째 채널 발견·수리, 스냅샷 노출 실측] | 한다 |
| **조합 설계** — 여러 정체성(계기·게이트·입장 축·디스패치·마감)을 한 임무에 **엮는 것**, 리턴을 독립 컨트롤로 재검하는 것 | 기대: 낮음 — 질문형·보고형이 정직한 형태(«산출은 보고, 결정은 거버너») | 메인 세션 기본값 [운영자 정책 2026-09-05] — 표준 4축·디스패치·마감 체인 운영 | 거버너/오케스트레이터 온디맨드 [관측 N=1 세션 2026-09-05: 디스패치 8 병렬, 리턴마다 grep·ps·mtime·실 launchd 컨트롤, 운영자 정정 0] |
| **자율 판단의 형태** — 차단 질문 수, 대안 선택, «묻지 않고 하는 것»의 범위 | 기대: 질문 많음(옳은 방향 — 낮은 티어의 자기억제는 약하므로 기계 counterweight 가 있다, `destructive_pre_gate.sh` 헤더) | 실측(Opus 4.8, N=12): 역량 안쪽 단발 판단은 medium≈high | 관측 N=1(운영자): «질문 횟수가 많이 줄었다», 결정 질문을 체크포인트 1회에 묶음 |
| **비용·한도** | 낮음 | 중 | 높음 — 세션 한도 429 실측(2026-09-04 Fable 디스패치 2건 사망 → Sonnet 재시도) |

**등급과 무관한 것**(표에 없는 이유): 커밋 게이트·마커 필드·pre-push 차단·레인·«미실행 ≠ 0» 분류·residency 스캔. 이것들은 **모델이 아니라 파일**이 하는 일이고, 강한 모델도 여기서 면제되지 않는다(`CLAUDE.md §Mechanization Boundary`). 2026-09-05 에 무인 잡 둘이 «첫 실사용»에서 깨진 것을 잡은 것은 산문이 아니라 이 층이었다.

## 2. 이폴트(effort)는 다른 축이다 — 그리고 등급마다 추천이 다르다

이폴트 = **숙고 깊이**, 모델 = **천장**. 둘은 직교한다(`feedback_workflow_stage_effort_routing`). 같은 이폴트라도 모델이 다르면 산출 차이가 크다 — Sonnet-max 와 Fable-max 는 «같은 max» 가 아니다(운영자 2026-09-05). 그래서 추천 이폴트는 등급별 **기대값**에서 나온다:

| 등급 | 추천 기본 | 올리는 조건 | 근거 등급 |
|---|---|---|---|
| **Sonnet** | **high** | 항상 — 싸고, 한 번 더 자기검증하는 값이 base op 의 «미실행 ≠ 0» 분류에 직접 닿는다 | 기대 + 운영자 정책(effort high 기본, 2026-07-18) |
| **Opus** | **medium**(역량 안쪽 단발 판단이 실측된 작업) / **high**(그 밖의 기본) | 설계 확정·교리·경계 판단·장호흡 에이전트 작업은 **high → xhigh**(문서: 코딩·에이전트는 xhigh 시작). max 는 «frontier problems» 에만 · 깊이는 cross-family 디스패치로도 산다 | 실측 N=12(Opus 4.8): 역량 안쪽 단발 판단은 tie · 장호흡 미측정 · 운영자 정책 2026-09-05 «메인 기본 = 오퍼스-미디엄» |
| **Fable** | **max — 거버너/오케스트레이터 세션에만** (문서 기준 다음 후보 = **xhigh**, 미측정) | 여러 정체성을 병렬로 엮고 리턴을 재검하는 «메인» 세션. 그 외 세션은 Opus 가 기본이다 | 운영자 정책 2026-09-05 + 관측 N=1(«medium → max 3단 올리니 답이 체감상 다르다, 메인에서」) |
| **무인 런(launchd/CI)** | plist·워크플로에 **명시 핀** | `/model` 로 저장한 기본값이 `claude -p` 에도 적용된다 — 핀 없으면 무인 잡이 조용히 최상위 모델로 돈다 | 실측 2026-09-05(`~/.claude/settings.json` model 키 · digest plist `FD_MODEL`) |

## 2-b. 세계가 말하는 것 — 공식 문서와 대조 (2026-09-05 열람)

Anthropic 플랫폼 문서 «Effort»(platform.claude.com/docs/en/build-with-claude/effort)와 헬프센터 «Change the model, effort, and thinking settings»를 열어 이 문서의 추천과 맞췄다. 인용은 축자다.

| 문서가 말하는 것 | 이 문서의 추천과의 관계 |
|---|---|
| 이폴트는 5단(low·medium·high·**xhigh**·max), 기본 = high. «Effort is a behavioral signal, not a strict token budget» — 낮은 이폴트에서도 어려운 문제엔 생각한다, 덜 할 뿐 | 이 문서의 «이폴트 = 숙고 깊이» 와 일치. 🟥 **xhigh 라는 중간 단이 있다** — 이 문서 초판은 max 만 봤다 |
| 이폴트는 **모든 출력 토큰**에 걸린다 — 낮으면 «fewer and terser tool calls», 전문 없이 바로 행동; 높으면 도구 호출이 늘고 계획을 먼저 설명한다 | 오늘 관측(«리턴을 끝까지 읽고 컨트롤을 하나씩 붙인다»)과 같은 방향 — 문서는 그것을 도구 호출 수·설명 길이로 기술한다 |
| **Fable 5.1**: «Start with high, the default. Step up to xhigh or max for the most capability-sensitive agentic and coding work, and step down to medium or low for routine … once your evals show quality holds» | «거버너 세션만 max» 와 일치. 단 문서는 그 위 단으로 **xhigh 를 먼저** 든다 — 미측정 대안 |
| **Opus 5**: high 에서 시작, xhigh 는 «demanding coding and agentic work», max 는 «when a task justifies unconstrained token spending», low/medium 은 «liberally as your primary control for token cost … wherever your evals show quality holds» | «Opus = medium 기본」은 운영자 실측(N=12, 역량 안쪽 단발 판단 tie)이 뒷받침하는 «evals show quality holds» 케이스다. 장호흡 오케스트레이션은 그 실측 밖 → 문서대로 high/xhigh |
| **Opus 4.7/4.8**: 코딩·에이전트 작업은 **xhigh 에서 시작**; max 는 «Reserve for frontier problems. On most workloads max adds significant cost for relatively small quality gains … can lead to overthinking» | max 를 «거버너 세션만」으로 제한하는 근거가 문서에도 있다 — 대부분 작업에서 비용 대비 이득이 작다 |
| **Sonnet 5**: 기본 high, medium 은 «Comparable to Claude Sonnet 4.6 at high effort», xhigh 는 가장 어려운 코딩·에이전트, max 도 가능 | «Sonnet = high 기본」 일치 |
| 헬프센터: 앱/CC 의 Extra high 는 «for long-running coding and agentic tasks, offering deeper reasoning than high without the full token cost of max» · «for complex coding and agentic tasks on Opus 4.7 or newer, try Extra high first» | 다음 측정 팔 = **Fable xhigh**. max 체감의 얼마가 xhigh 로 확보되는지가 비용 결정의 핵심이고 미측정이다 |

**대조 결론**: 문서와 체감이 **방향에서 일치**한다(기본 high · 조합·에이전트 작업일수록 위로 · 대부분 작업에서 max 는 비용 대비 작다). 어긋나는 점 하나 = 이 문서 초판이 **xhigh 를 빠뜨렸다**. 추천 표를 그에 맞춰 고쳤다(아래). 「같은 이폴트라도 모델에 따라 산출이 크게 다르다」는 운영자 관측은 문서의 «medium(Sonnet 5) ≈ high(Sonnet 4.6)» 같은 교차 등급 등가 서술과 같은 축이다 — 이폴트 눈금은 모델마다 다른 절대값을 가리킨다.

## 3. 기본을 max 로 두면 무엇이 달라지나 (그리고 무엇은 안 달라지나)

- **달라지는 것 [관측 N=1 · 기대]**: 병렬 디스패치 폭 · 리턴 재검 깊이(에이전트 패치의 구멍을 거버너가 잡는 비율) · 차단 질문 감소 · 토큰·시간 비용 · 세션 한도 도달 확률.
- **안 달라지는 것 [규율]**: 훅·레인·게이트·마커 요구 · Sonnet-floor(base op 는 여전히 Sonnet 에서 돌아야 한다 — max 가 그것을 대신 지면 «근육≠뼈대」 결함) · 비가역 표면의 HITL.
- **최대 레버**: 이폴트의 최대는 max 다(문서의 5단 중 꼭대기; 멀티에이전트 워크플로 «ultracode」는 이폴트가 아니라 별도 오케스트레이션이고 명시 옵트인이다). max 바로 아래 **xhigh** 가 «long-horizon agentic» 용으로 따로 있다.

## 4. 정직한 한계 — 인용하기 전에 읽어라

- 표의 Fable 칸은 **한 세션(2026-09-05)** 의 관측과 운영자 체감이다. 같은 작업 분포에서 medium 팔과 대조한 적이 없다.
- Opus 의 «medium≈high» 는 **Opus 4.8 세대, 역량 안쪽 단발 판단** 에 한정된 실측이다(N=12). Opus 5·장호흡 조합은 미측정.
- Sonnet 칸의 «조합 설계 낮음» 은 기대다 — 반증되면 이 표를 고친다.
- **측정 계획(사전등록 후 실행, reps≥3)**: 같은 임무를 «의도 한 줄 프롬프트」로 Sonnet/Opus/Fable × medium/**xhigh**/max 에 주고 — 엮은 정체성 수 · 차단 질문 수 · 게이트 통과율 · 리턴에서 스스로 잡은 결함 수 — 를 센다. 실행부는 `scripts/sim_isolated_run.sh`(라이브 레포 금지).

## 5. 같이 읽을 것
외부: Anthropic «Effort» 문서 · Claude 헬프센터 «Change the model, effort, and thinking settings» (2026-09-05 열람 — 모델별 권고는 갱신되므로 인용 전 재열람) · 내부: `knowledge/shared/harness-core/sonnet_floor_doctrine.md` · `knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Tier-floor resolution` · `CLAUDE.md §Mechanization Boundary` · `CLAUDE.md §Skeleton, Not Muscle` · (운영자 로컬) `tracks/_meta/user_adaptation_profile.md §Effort A/B`
