# ISO/IEC AI 표준 ↔ 하네스 게이트 crosswalk — «모델이 도는 하네스」 단위의 정렬 구조 (2026-09-05)

> **한 줄**: ISO/IEC 42119(AI 테스트) · 29119-11(AI 기반 시스템 테스트 가이드) · 25059(AI 품질 모델) · 42001(AI 경영시스템) ·
> 5338(AI 수명주기) · 23894(AI 위험) · TS 8200(제어가능성)이 요구하는 것을 **FH 의 게이트·마커·레인·로그**와 **qasp 의 1~3막**에
> 조항 단위로 대응시켰다. 목적은 «인증」이 아니라 **보여줄 수 있는 정렬** — 어느 조항에 어느 기제가 있고 그 증거가 어느 파일에
> 있는지를 사람이 따라갈 수 있게. 🟥 42119 시리즈의 절반은 아직 TS 초안(DTS/AWI)이라 «준수」라는 낱말은 쓰지 않는다.
>
> **운영자 논지(2026-09-05, 축자)**: *«국제표준을 준수한 구조나 능력을 보여줄 수 있다면 더 가치 있는 활동이 가능하다 — FH 도 qasp 도.»*
> 그리고 *«모델이 돌아가는 하네스 단위로 쓸 만하지 않을까.»* — 이 문서는 그 두 문장의 실행이다. 🟥 인용 안의 «준수」는 운영자 낱말이고,
> 이 문서 자신의 낱말은 **정렬(alignment)**이다 — 적합성 평가를 한 적이 없으므로 «준수」를 자기 목소리로 쓰지 않는다.

## 0. 왜 «하네스 단위」인가

표준이 말하는 «AI 시스템」은 모델 가중치가 아니라 **모델 + 그것을 돌리는 것**(프롬프트·게이트·로그·개입 지점·위험 기록)이다.
모델 벤더가 보여줄 수 없는 것 — 운영 조직의 V&V(42001 A.6.2.4), 이벤트 로그(A.6.2.8), 개입 가능성(25059 intervenability ·
TS 8200), 위험 식별(42119-2 §6) — 이 정확히 **하네스 층**에 산다. 25059 개정판(DIS)이 신설한 «AI 서비스 품질 모델」의
**traceability** 특성이 이 층을 이름으로 부른다 — 🟥 정의는 2차 자료가 갈린다(한 해설은 *models·datasets·requests·outcomes 의
로깅*으로, cross-family 리뷰가 인용한 OBP 는 *서비스 결과 ↔ 사용자 요구의 추적*으로). 실물 미열람이라 둘을 병기하고, «로깅」 증거는
42001 A.6.2.8 행에 둔다. 어느 독법이든 그 특성이 사는 자리는 모델이 아니라 하네스 층이다.
⇒ 정렬 «구조」를 보여줄 단위로 하네스가 맞다. FH 는 메타하네스이니 자기 자신에도, 낳은 필드 하네스(qasp)에도 같은 표가 걸린다.

## 1. 표준 지형 — 무엇이 무엇을 요구하나 (상태 2026-09)

| 표준 | 상태 | 요구하는 것(요지) | 이 표에서의 역할 |
|---|---|---|---|
| ISO/IEC/IEEE 29119-1~4 | IS | 테스트 개념 · 프로세스(조직/관리/동적) · 문서 템플릿 · 설계 기법 | 뼈대. 42119-2 가 이것을 AI 에 «적용」한다 |
| ISO/IEC TR 29119-11:2020 | TR | AI 기반 시스템 테스트 가이드 — 복잡·데이터 의존·미명세·**비결정성**, **테스트 오라클 문제**, 블랙박스(AI 전반)·화이트박스(신경망) | AI 특성과 오라클 어휘의 출처 |
| ISO/IEC TS 42119-2:2025 | TS 발행 | AI 시스템 테스트 총론: 수명주기·기능 뷰·**위험 기반 테스트**·테스트 프로세스/문서/이해관계자 · 위험 식별(§6) · 테스트 레벨/유형(공통·**데이터 품질**·**AI 모델**·지식공학 정적)·설계 기법/커버리지(공통·전문) · Annex B AI 특성 · Annex C 위험평가 예 | 조항 번호의 출처(공개 샘플 ToC 기준) |
| ISO/IEC DTS 42119-3.2 | DTS(2차 초안, stage 50.20) | V&V «분석」 — 형식적 방법·시뮬레이션·평가, 수명주기 단계별 | 시뮬레이션·평가 = FH sim 의 자리 |
| ISO/IEC AWI TS 42119-7 | AWI(승인된 작업 항목 — 공개된 것은 **스코프 문장뿐**, 규범 요구사항 아님) | **레드티밍** — 공개 스코프가 «다루는」 주제: 용어·위험 식별·적용 범위·목표/공격 벡터·계획/실행 방법(29119 프로세스 정렬)·문서/보고·수명주기 통합 | 적대검증(cross-family·challenger·steel-quench)의 자리 |
| ISO/IEC AWI TS 42119-8 | AWI(stage 20.00) | **프롬프트 기반 텍스트→텍스트 생성 AI 품질 평가**(안전 포함, 레드티밍 결합) | live-eval · probes · 등급×이폴트의 자리 |
| ISO/IEC 25059:2023 (+DIS 개정) | IS / DIS | AI 품질 모델 — **제품 품질**: functional adaptability · functional correctness · **robustness** · **user controllability** · **intervenability** · **transparency** — **사용 품질**: 사회·윤리 위험 완화(transparency 재등장) — **(DIS) 서비스 품질 모델**: traceability · service adaptability. (안전·fail-safe 는 25059 의 추가가 아니라 개정판이 **25010:2023 에서 상속**하는 특성) | 품질 특성 어휘 |
| ISO/IEC 42001:2023 | IS | AIMS. Annex A 38 컨트롤 — A.5 영향평가 · **A.6 수명주기(A.6.2.4 V&V · A.6.2.6 운영 모니터링 · A.6.2.7 기술문서 · A.6.2.8 이벤트 로그)** · A.7 데이터 · A.8 이해관계자 정보 · A.9 사용 · A.10 3자 | 경영시스템 컨트롤 — «있다/없다」를 보여주기 가장 좋은 표 |
| ISO/IEC 5338:2023 | IS | AI 수명주기 프로세스(데이터 준비·운영 중 모델 행동·역할·지속 모니터링) | 인큐베이터→EMIT→검증 루프의 자리 |
| ISO/IEC 23894:2023 | IS | AI 위험관리(31000 을 AI 에) | 등급표·비가역 표면 불변식의 자리 |
| ISO/IEC TS 8200:2024 | TS | AI 시스템 제어가능성(원칙·특성·접근) | HITL·동의 lease·자율성 floor 의 자리 |
| ISO/IEC 20246 | IS | 작업산출물 리뷰(인스펙션·워크스루·기술리뷰) | 정적 리뷰(qasp 1.5막 · FH 리뷰 스킬)의 자리 |
| (참조) ISO/IEC 5259-1~5 | IS(part 5 는 2025) | ML/분석용 데이터 품질 | 어휘 정렬만 |
| (참조) ISO/IEC 24029 | TR 24029-1:2021 · IS 24029-2:2023 · FDIS 24029-3 | 신경망 강건성 평가 | 어휘 정렬만 |
| (참조) ISO/IEC 22989:2022 | IS(개정안 진행 중) | AI 개념·용어 | 어휘 정렬만 |

## 2. FH crosswalk — 조항 → 기제 → 증거 → 상태

상태: ✅ 기제와 증거가 있다 · 🟡 있으나 표준 어휘·문서 형태가 아니거나 부분 · ❌ 없음(강화 후보 §4)

| 표준 조항 | 요구 | FH 기제 | 증거(파일) | 상태 |
|---|---|---|---|---|
| 42119-2 §5.4 · §6 · Annex C | 위험 기반 테스트 — AI 특성별 위험을 식별하고 테스트 깊이를 거기 맞춘다 | 6축 검증은 «실패 모드에 맞춰 축을 **고른다**」(곱하지 말고) · 마커 `defeater:`(틀렸다면 관측될 것) · `affected:` | `CLAUDE.md §자기 대조` · `fh_three_layer_canon.md §1-a-2` · `tracks/_meta/.axes_23_passed_*.marker` | 🟡 위험 등록부가 아니라 커밋 단위 필드에 분산. AI 특성 어휘(비결정성·데이터 의존·적응성·불투명성) 미채택 → §4 S1 |
| 42119-2 §5.5 (29119-2 **동적** 테스트 프로세스) | 설계→구현→실행→결과 보고 | 레인 스위트 → `selfcheck.sh` 전수 → CI `validate` · 4축 pre-commit 게이트 | `templates/.git-hooks/pre-commit` · `scripts/selfcheck.sh`(99 스위트 배선) · `.github/workflows/validate.yml` | ✅ |
| 42119-2 §5.5 (29119-2 **조직·관리** 프로세스) | 테스트 정책·전략 · 계획·감시/통제·완료 | 정책 = `CLAUDE.md` 게이트 절 · 계획 = 사전등록 · 완료 = 마커 — **감시/통제·완료 기준의 프로세스 문서는 없다** | `CLAUDE.md` · `PREREG_*.md` | 🟡 활동은 있고 프로세스 문서가 없다 |
| 42119-2 §5.6 (29119-3 테스트 문서) | 계획 · 설계/케이스/절차 명세 · 완료 보고 · 사고 보고 | 계획 = **사전등록 봉인**(`PREREG_sealed.md`, 해시) · 케이스/절차 = 레인 파일(known-pair) · 완료 보고 = **마커**(axes-run·controls) + PR 본문 · 사고 = `fh_signal_*.md` | `scripts/test_*_lanes.sh` · 마커 · `tracks/_meta/fh_signal_*` | 🟡 대응은 1:1 인데 29119-3 템플릿 명칭으로 안 불린다 → `docs/STANDARDS_ALIGNMENT.md` 가 그 이름표를 붙인다 |
| 42119-2 §5.7 | 이해관계자 | 거버너 / 사이드카(다른 계열) / 운영자(HITL) / 소비자 install — 역할이 기록면에 있다 | `multi_model_sidecar_strategy.md §Runtime Authority` · 마커 `standpoint:` | ✅ |
| 42119-2 §7.2 테스트 레벨 | 단위→통합→시스템→인수 | 단위 = 레인 · 통합 = selfcheck 전수 · 시스템 = `sim_isolated_run.sh`(격리 클론 실세션) · **첫 실사용 ⓔ**는 인수 테스트가 아니라 «실사용 시운전(field trial)」— 인수 기준·서명 증거가 없다 | `scripts/sim_isolated_run.sh` · `feedback_adversarial_review_not_substitute_for_first_use` | 🟡 단위~시스템 ✅ · 인수 ❌(기준 없음) |
| 42119-2 §7.3.3 데이터 품질 테스트 | 대표성·출처·라벨 정확성 | FH 자체는 학습 데이터가 없다. 있는 것은 **코퍼스 그라운딩 fail-closed**(생성기 없음) · residency 스캔(조직 식별자) | `corpus-grounding-expander` · `scripts/residency_closure_scan.py` | 🟡 해당 범위가 좁다(qasp 표 참조) |
| 42119-2 §7.3.4 AI 모델 테스트 (TR 29119-11 §8 블랙박스 기법: 적대 · 메타모픽 · back-to-back · A/B — 드리프트는 29119-11 에선 «모니터링/모델 갱신」 관심사, «드리프트 테스트」 명칭은 ISTQB CT-AI v2 쪽) | 모델 행동을 여러 기법으로 | A/B = sim **ARM/CTRL 한 변수**(reps≥3) · back-to-back = **cross-family**(다른 계열이 같은 diff 를 읽는다) · 적대 = challenger/steel-quench Wave-1 · 드리프트 감시 = **live-eval 야간**(모델 핀·cutoff 헤더) · 뮤테이션 = 되돌림 프로브 ⓕ | `.claude/regression/probes_live.yaml` · `scripts/probe_live_eval.sh` · `scripts/revert_probe.sh` | 🟡 **메타모픽 관계**(입력 변환→기대 출력 변화)를 이름으로 적는 자리가 없다 → §4 S2 |
| 29119-11 테스트 오라클 문제 | 기대값을 정할 수 없을 때의 오라클 | **known-pair**(양성/음성 컨트롤이 같은 실행에) · 결과 전 채점기 고정 · «미측정 ≠ 0」 · UNCALIBRATED 라벨 | `measurement-integrity-checklist.md §Instrument-Calibration` · `CLAUDE.md §Instrument Calibration` | ✅ 기제 · ✅ **오라클 유형 채널** — 마커 옵셔널 `oracle:`(닫힌 enum 6: known-pair · metamorphic · back-to-back · a-b · human · none, 훅은 형식만 — §4 M1 **구현됨 2026-09-05**, `validate_oracle_leg` · `scripts/test_marker_oracle_lanes.sh`) |
| 29119-11 비결정성 | 확률적 출력의 통계적 처리 | reps≥3 바 · 3/3 또는 0/3 아니면 분리 안 됨 · 컨트롤 동반 | `probe_scope_check.sh` 헤더 · 사전등록 «명명된 한계」 | ✅ |
| 42119-3 V&V 분석(시뮬레이션·평가·형식적 방법) | 실행 외 분석 수단 | 시뮬레이션 = 격리 클론 sim · 평가 = live-eval 문턱 · **형식적 방법 없음** | `scripts/sim_isolated_run.sh` · `tracks/_meta/live_eval_*.md` | 🟡 |
| **42119-7 레드티밍**(공개 스코프가 다루는 주제: 용어 · 위험 식별 · 적용 범위 · 목표/공격 벡터 · 계획/실행 · 문서/보고 · 수명주기 통합 — 규범 요구사항은 미공개) | 구조화된 적대 평가 | 위험 = 4축 트리거 · 공격 벡터 = steel-quench **Wave-1 공격각 레지스트리** + codex 프롬프트의 «attack specifically (1)…(n)」 · 실행 = cross-family 패널(다른 계열, 내 추론을 못 본 리뷰어) · 보고 = 마커 `crossfamily:` + PR 본문 · 통합 = **커밋 전 의무**(Field-Harness Load-Bearing Change Gate) | `plugins/fh-meta/skills/auto-decorrelation/SKILL.md` · `field_verdict_crossfamily_gate.md` · `plugins/fh-meta/agents/challenger.md` | 🟡 **보고 형식이 스코프의 주제 순서로 정렬돼 있지 않다** → §4 M2 `templates/RED_TEAM_REPORT.md` |
| 42119-8 프롬프트 기반 생성 AI 품질 평가 | 텍스트→텍스트 시스템의 품질·안전 평가 | probes(기대/컨트롤 정규식 · polarity) · live-eval(격리 클론 · 문턱) · 등급×이폴트 기대 역량 문서 | `.claude/regression/probes_live.yaml` · `docs/model_tier_expectations.md` | 🟡 25059 특성 어휘로 표현 안 됨 |
| 25059 robustness | 미지·적대·비정상 입력에서 기능 유지 | 예: 훅의 **패딩 우회 수리**(10KB 47s→0.23s, H23) · 절단/문자열/키 fail-closed | `scripts/test_outbound_query_hook_lanes.sh` H23~H30 | ✅ 사례 / 🟡 특성 이름 미부착 |
| 25059 user controllability · intervenability · TS 8200 | 적시 개입 · 제어 지점 | HITL 게이트 · 동의 **lease**(3요소 기록) · 자율성 floor · 명시 override 채널(`PUSH_ZONE_OK`·`DESTRUCTIVE_OP_OK`·`PUBLIC_SURFACE_OK`, 전부 로그) · `# noqa:` 도 로그 행 | `CLAUDE.md §Agent Dispatch` · `templates/.git-hooks/pre-push` · `tracks/_meta/consent_classes.yaml` | ✅ 강함 — 제어 지점이 전부 **기록되는 채널**이다 |
| 25059 transparency | 이해관계자에게 적절한 정보 | 마커 «축과 컨트롤의 생사」 · PR 본문 «잔여를 이름으로」 · 위키 현황판 «무엇이 증명했나」 | `docs/OUTPUT_EVIDENCE.md` · wiki Status-Board | ✅ |
| 25059(DIS) 서비스 traceability | (정의 불일치 — §0) 로깅 독법: models·datasets·requests·outcomes 기록 / OBP 독법: 서비스 결과 ↔ 사용자 요구 추적 | 로깅 독법 = governance_log · 훅 이벤트 tsv(값 없이 개수·라벨) · 서브에이전트 원장 · sim 헤더(corpus_head_date · sim_model · cutoff) / 요구 추적 독법 = 마커 `soul:`(성공 정의) ↔ `defeater:` ↔ 레인 | `tracks/_meta/governance_log_*.yaml` · `knowledge/shared/learnings/subagent_invocations_log.yaml` · 마커 | 🟡 로깅 독법으로는 강하고, 요구 추적 독법으로는 마커 필드 대응까지 |
| 42001 A.6.2.4 V&V | 정의된 기준으로 검증·확인 | 4축 게이트(필수 필드·닫힌 enum·비공허 근거) | `pre-commit` `validate_*_leg()` | ✅ |
| 42001 A.6.2.6 운영 모니터링 | 운영 중 감시 — 기준·검토·대응·소유자 | **기제**: live-eval 02:30 · digest 09:00 · daily-report(launchd) · «검증 환경≠실행 환경」 규율 · 문턱은 보정 주간 뒤 결정 | `scripts/com.forge-harness.*.plist` · 카드 «live-eval 보정 주간」 | 🟡 기제는 있고 «기준·검토·대응·소유자」 를 적은 절차 문서는 없다 |
| 42001 A.6.2.7 기술문서 · A.8 이해관계자 정보 | 문서·정보 | `knowledge/` · `docs/USER_GUIDE.md` · `docs/USE_CASES.md` · `docs/model_tier_expectations.md` · `docs/STANDARDS_ALIGNMENT.md` | — | ✅ |
| 42001 A.9 사용(A.9.2 책임 있는 사용 프로세스 · A.9.3 목표 · A.9.4 의도된 사용) | 책임 있는 사용의 프로세스와 목표 | 의도된 사용의 **전달**은 문서(USER_GUIDE·USE_CASES) · 사용 프로세스 = 동의 lease·자율성 floor·비가역 게이트 — **«책임 있는 사용 목표」 문서는 없다** | `CLAUDE.md §Agent Dispatch` | 🟡 |
| 42001 A.6.2.8 이벤트 로그 | 로그 기록 | 위 traceability 행 + 훅 이벤트 | — | ✅ |
| 42001 A.5 영향평가 | AI 시스템 영향 평가 | 챔버 §3-SCREEN(KILL·NOT-APPLICABLE·CURATED·EMIT) — «누구에게 어떤 영향」 은 안 묻는다 | `harness_incubator_doctrine.md §3-SCREEN` | 🟡 → §4 S3 |
| 42001 A.7 데이터(A.7.2 개발·개선 데이터 · A.7.3 획득 · A.7.4 품질 · A.7.5 출처 · A.7.6 준비) | 데이터 획득·품질·출처·준비 | FH 는 학습 데이터가 없지만 **평가 데이터는 있다**(probes · 코퍼스 · 전사본 · 로그): 출처 = sim 헤더 `corpus_head_date` · 품질 = known-pair 캘리브레이션 · 준비 = residency 스트립 · 반출 = **residency 절대 규칙** | `probes_live.yaml` · `scripts/residency_closure_scan.py` · sim 헤더 | 🟡 A.7.5/A.7.6 는 있고 A.7.3/A.7.4 의 «평가 데이터 획득·품질 기준」 문서는 없다 |
| 42001 A.10 3자 | 3자·고객 관계 | capability composition contract(strictest-wins) · 클러스터 노드 등록 | `capability_composition_contract.md` | 🟡 |
| 5338 수명주기 | 정의·통제·실행·개선 프로세스 | 인큐베이터(챔버 run) → EMIT → 필드 → harvest-loop 복리 | `harness_incubator_doctrine.md` · `hub_compounding_loop.md` | ✅ |
| 23894 위험관리 | 식별·분석·평가·처리 | 등급표(🔴🟡🔵🟢) · Surface-Class Degrade Invariant(비가역 = fail-closed) · «미측정≠0」 | `ship_readiness_gate.md` · `CLAUDE.md §Irreversibility Gates` | ✅ 부분 |
| 20246 리뷰 | 작업산출물 리뷰 프로세스 | cross-family 리뷰 · `/apex-review` · `hub-cc-pr-reviewer` · 콜드리드(`beginner`) | `plugins/fh-meta/agents/*` | ✅ |

## 3. qasp crosswalk — QA 하네스에게 29119 는 «선택된 활동」 단위로 걸린다

qasp 는 «AI 로 QA 를 하는 시스템」이라 **두 방향**이 걸린다: ⓐ qasp 가 수행하는 테스트 **활동**이 29119 의 어느 활동에 대응하는가
(프로세스 «커버리지」가 아니다 — 조직 정책·테스트 관리·감시/통제·완료 기준·사고 프로세스·형상관리는 파이프라인 바깥이다)
ⓑ qasp 자신이 AI 시스템으로서 42119/25059 로 평가되는가.

| 표준 조항 | 요구 | qasp 기제 | 상태 |
|---|---|---|---|
| 29119-2 테스트 설계·구현 **활동** | 기능/요구에서 테스트 조건→케이스→절차 | **1막 spec-first TC 생성** — P4 MECE 검사 · P6 메뉴 트리 · P7 TC 설계 · surface inventory · clarification 프로토콜(«물어봐야 한다」) | ✅ 활동 / 🟡 프로세스(계획·감시/통제·완료 기준 문서 없음) |
| 29119-4 설계 기법 | 동등분할·경계값·상태전이·조합 등 | P7 의 좌표(surface coordinates)는 상태전이 테스트의 **재료**(상태·이벤트·전이·기대 행동 모델까지는 아님) · MECE 는 동등분할의 **재료**(입력 도메인 동등류 표까지는 아님) | 🟡 기법이라 부르려면 `technique:` 증거(분할표·상태 모델)가 필요하다 |
| 20246 정적 리뷰 | 인스펙션·워크스루 | **1.5막 정적 리뷰 7 렌즈**(spec_drift 포함, 한국어 기획서) | ✅ |
| 29119-2 테스트 실행·사고 보고 **활동** | 실행·결과 기록·사고 | **2막 runner/interpreter**(verb navigate·click·input·verify) · **MTM**(기획의도/기획과 다름/코드가 다름 3갈래) · triage 3분기 · defect_lifecycle · evidence.json | ✅ 활동 / 🟡 사고 «프로세스」(접수·분류·종결 기준)는 운영 조직의 도구 쪽 |
| 29119-11 오라클 문제 | 기대값 부재의 처리 | MTM 3갈래 = **3-way pseudo-oracle**(기획 · 코드 · 실행을 대조) · Self-Check Gate 33 · `__RUNTIME__` 자리표시자 | ✅ / TC 에 `oracle_type` 없음 → §4 M1 |
| 29119-2 완료·회귀 **활동** | 완료 보고·회귀 | **3막 회귀** · `surface_reach` 도달 지표(«완주 51/51 이 로그인 51번」 사고에서 신설) · new_code_anchor · caller_zero baseline | ✅ 활동 / 🟡 완료 «기준」 문서 없음 |
| 29119-3 문서 | 계획·명세·보고 템플릿 | evidence.json · report · tc_update_suggestion · act2_runner_design §6-b | 🟡 템플릿 명칭 미부착 |
| 42001 A.7 / 5259 데이터 | 데이터 품질·출처·비밀 | **evidence 평문 입력값 마스킹**(interpreted.value · action_attempted · tc_update_suggestion) · 필드명 기준 secret 판정 · XML 스냅샷 평문은 잔여(#253) | 🟡 |
| 42119-8 / 25059 | 생성 AI 기반 QA 시스템 자신의 품질 | «AX-레디 블라인드 완주」(비저자가 가이드만으로 1→3막) · surface_reach · 챔버 #16 K3 안전 레인 | 🟡 25059 특성(robustness·controllability·transparency)으로 표현 안 됨 |
| 42119-7 레드티밍 | 적대 평가 | cross-family 리뷰(홈에서, residency 스트립 후) · 운영 조직 내부 패널(cross-family 대체) | 🟡 보고 형식 |
| 42001 A.6.2.8 로그 | 이벤트 로그 | evidence.json · collector · governance | ✅ |

## 4. 강화 후보 — 전부 «기록의 속성」(채널)이고 «결론」(판단)이 아니다 (§Mechanization Boundary)

| 등급 | 후보 | 무엇 | 왜 표준이 이걸 이름 부르나 | 비용/위험 |
|---|---|---|---|---|
| **M1** | **오라클 유형 채널** — ✅ **구현됨 2026-09-05** (FH 마커 `oracle:` · `templates/.git-hooks/pre-commit validate_oracle_leg` · 레인 o1~o36(o21~o31 = cross-family codex 가 연 구멍) · 배선 W6 · 스펙 `.claude/rules/fh_4axis_gate.md §Marker axis fields`). qasp TC `oracle_type` 은 별도 PR(미착수) | 레인/마커/TC 에 `oracle:` 값 — `known-pair` · `metamorphic` · `back-to-back` · `a-b`(`A/B` 허용) · `human` · `none(사유 필수)` — 닫힌 enum, 훅은 형식만 | 29119-11 의 핵심이 «오라클 문제」다. 지금은 «컨트롤이 살아 있다」까지만 적고 **어떤 종류의 오라클**인지는 안 적는다 — 외부 독자가 첫 번째로 묻는 것 | 낮음(옵셔널 필드 + enum). 값의 진위는 안 본다(형식만) |
| **M2** | **42119-7 형 레드팀 보고 템플릿** | `templates/RED_TEAM_REPORT.md` — 목표 · 공격 벡터(레지스트리 인용) · 방법(계열·입장·받은 것) · 발견(S/A/B + 재현 입력) · 처분(수리/반박/잔여) · 수명주기 통합(어느 게이트에서 돌았나). codex 프롬프트의 «attack specifically (1)…(n)」이 이미 이 형태 | 개발 중인 표준이 요구하는 5 요소를 **우리 산출이 이미 갖고 있는데 형식만 안 맞는다** — 가장 싸게 «보여줄 수 있는」 자리 | 낮음(템플릿 + SKILL 포인터) |
| **M3** | **`docs/STANDARDS_ALIGNMENT.md`** | 이 문서의 요약본 + 증거 포인터 + 정직 경계(인증 아님 · TS 초안) — 외부에 보이는 표면 | 42001 A.8(이해관계자 정보) 자체가 «보여줘라」다 | 낮음 |
| S1 | AI 특성 위험 어휘 | 마커 `affected:` 옆 옵셔널 `risk:` — 42119-2/29119-11 특성(비결정성·데이터 의존·적응성·불투명성·자율성) 중 이 변경이 건드리는 것 | §6 위험 식별의 어휘 정렬 | 낮음이나 «자평」 채널이 하나 더 는다 |
| S2 | 메타모픽 관계 명시 | 사전등록에 «입력 변환 → 기대 출력 변화」 를 관계 문장으로(ARM/CTRL 한 변수 규율의 일반형) | 29119-11 의 대표 기법 | 산문 규율 |
| S3 | 챔버 영향평가 한 줄 | §3-SCREEN 에 «누가 영향받나」 | 42001 A.5 | 산문 |
| R1 | 형식적 방법 | 42119-3 의 한 축 — 적용 자리 없음 | — | 기록만 |
| qasp M | `oracle_type` + 29119-3 문서 이름표 + 25059 특성 표현 | TC 스키마 필드 · 산출물 문서 표 · AX-레디 기준을 특성으로 | 29119 자체가 QA 제품의 과녁 | 운영 조직 반입 순서와 무관한 문서/스키마 |

## 4-b. 이 문서가 다루지 않은 인접 표준 (명시적 비포함)

| 표준 | 무엇 | 왜 여기 없나 |
|---|---|---|
| ISO/IEC TS 25058 | AI 시스템 품질 평가(25040 의 AI 확장) | 평가 «절차」 표준 — 42119 와 겹치는 층이라 후속 |
| ISO/IEC TS 6254 · ISO/IEC 12792 | 설명가능성 · 투명성 분류체계 | transparency 행의 어휘만 필요했다 |
| ISO/IEC 24029-2/3 | 신경망 강건성 형식적/통계적 방법 | FH 는 가중치를 안 만진다 |
| ISO/IEC TS 24970 | AI 시스템 로깅 | traceability/A.6.2.8 행의 후속 정본 후보 — **다음 개정에서 1순위** |
| NIST AI RMF 1.0 · IEEE 7001 · EU AI Act Art. 9/15 | 위험관리 프레임 · 투명성 · 위험/정확성·강건성 요구 | 법·프레임 층 — 이 문서는 ISO/IEC 기술 표준에 한정 |

## 5. 정직한 한계

- 42119-2 는 **공개 샘플(ToC·서문)**만 읽었다. 조항 번호·제목은 실물이고, 조항 «본문」의 요구사항은 2차 자료(SGS·Resync·ogunsecurity)와
  **ISTQB CT-AI v2.0 실라버스**(AI 테스트 주제를 다루는 공개 교육 자료 — 29119-11 의 «거울」이 **아니다**: v2 는 생성 AI·레드티밍까지
  넓힌 인증 실라버스다)로 보강했다. 42119-3.2/7/8 은 **스코프 문장**까지만 공개다.
- 25059(DIS) traceability 의 정의는 2차 자료 간 불일치(§0) — 실물 열람 전까지 병기.
- «준수」가 아니라 **정렬**이다. 적합성 평가·인증은 별개의 절차이고, 이 문서는 자기평가다(자평이라 게임 가능 — `CLAUDE.md §자기 대조` 와 같은 경계).
- 한 저자·한 저장소의 해석이다. 조항↔기제 대응의 «맞음」은 cross-family 리뷰로 한 번 더 봤다(마커 `crossfamily:`).

## Sources
- ISO/IEC TS 42119-2:2025 공개 샘플(ToC·서문) — https://cdn.standards.iteh.ai/samples/iso/iso-iec-ts-42119-2-2025/03241f088b1442bb8ee6866252c2bd98/iso-iec-ts-42119-2-2025.pdf
- ISO/IEC AWI TS 42119-7 Red teaming — https://www.iso.org/standard/91240.html · https://isme.me/en/project/show/iso:proj:91240
- ISO/IEC AWI TS 42119-8 — https://www.iso.org/standard/91609.html
- ISO/IEC DTS 42119-3 — https://www.iso.org/standard/85072.html
- 42119 시리즈 소개 — https://www.sgs.com/en-gb/news/2026/01/announcing-the-iso-iec-42119-series-a-new-era-for-ai-testing-and-assurance · https://bootcamp.resync.nz/ai-testing/iso42119/ · https://blog.nucida.com/blog/the-dawn-of-iso-42119
- ISO/IEC TR 29119-11:2020 — https://www.iso.org/standard/79016.html · https://oecd.ai/en/catalogue/tools/isoiec-tr-29119-112020-software-and-systems-engineering-software-testing-part-11-guidelines-on-the-testing-of-ai-based-systems
- ISTQB CT-AI Syllabus v2.0 — https://istqb.org/wp-content/uploads/2026/05/ISTQB-_CTAI_Syllabus_v2.0_Release.pdf
- ISO/IEC 25059:2023 및 DIS 개정 해설 — https://www.iso.org/standard/80655.html · https://adamleonsmith.substack.com/p/isoiec-25059-gets-a-rewrite-ai-quality
- ISO/IEC 42001 Annex A — https://www.isms.online/iso-42001/annex-a-controls/
- ISO/IEC 5338:2023 · 23894:2023 · TS 8200:2024 — https://www.iso.org/standard/81118.html · https://blog.stackaware.com/p/iso-5338-42001-ai-risk-management-lifecycle
