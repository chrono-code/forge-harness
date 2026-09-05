# FH 전체 지도 — 무엇인가 · 어떻게 구현돼 있나 · 왜 믿을 만한가 · 어디가 운영자 로컬인가 · 어느 표면에 올리나 (2026-09-05)

> **읽는 사람 = FH 를 처음 보는 하네스 엔지니어 · 팀 리드.** FH 를 만든 사람을 위한 문서가 아니다.
> «믿을 만하다» 는 산문으로 주장하지 않고 **파일 경로 · 게이트 · 레인 수 · 등급표 행**으로 뒷받침한다 —
> 경로는 «여기 봐라» 하고 건넬 수 있는 좌표다. 수치는 전부 **출처 파일 + 측정일**을 달았고, 안 잰 것은 «안 쟀다» 라고 적었다(0 이 아니다).
> 그림 세 장은 같은 폴더의 HTML 이고 브라우저에서 그냥 열린다(설치·서버 불필요). 위치는 이 문서 끝 §그림·재생성.

**30초 요약**: FH(forge-harness)는 **사람의 의도를 기계로 벼리는 메타하네스**다 — 의도를 AI 가 따르는 규칙이나 모델이 필요 없는 코드로 굳히고,
그 산출(스킬·게이트·하네스)을 다른 프로젝트에 낳는다. 모든 작업은 **3단 공정**(성공 정의 먼저 → 병렬 탈상관 → 6축 태우기)을 밟고, 출력은
**4대 엔진**에서 나오며, 사람은 **5대 정체성**(클러스터 · 인큐베이터 · 게이트 · 답습 · 증폭자)으로 그것을 만난다. 믿을 만한 이유는 **막는 것이
산문이 아니라 파일**이기 때문이다 — **설치된 pre-commit/pre-push 경로에서는** FH 자산을 고친 커밋이 4축 마커 없이 못 들어가고, 원격 삭제·force push 가 못 나간다. 🟥 한정: 둘은 **클라이언트 훅**이라 `--no-verify` 로 우회되고, 마커는 gitignored 라 CI 가 못 보며, 서버측 floor 는 «main 은 PR 전용 + `validate` 체크 하나» 뿐이다(③ 정직 표기). 발행(npm publish · 공개 전환)은 별도 게이트다(`prepublishOnly` 스캔 + Pre-Publish 절차). 훅·스크립트를 재는 레인 스위트(테스트 묶음) **104 개**는 전부 러너에 배선돼 있다(선언 면제 1 포함)(산식은 ② 계기 표). FH 자체는 Claude Code 위에서 돌고, LLM 없이 도는 것은 그 산출 중 코드·훅 층이다.
소비자가 받는 것은 **레포 클론 또는 npm 패키지**(둘 다 스킬·훅·정본을 담는다)이고, 세션 기록 · 로컬 바인딩 · 무인 잡은 **운영자 로컬**이라 없다. 상세는 ④ · 시작 명령은 ①-끝.

**용어 20개** (이 문서에서만 쓰는 뜻):

| 용어 | 뜻 |
|---|---|
| **하네스** | 한 프로젝트의 도구 · 규칙 · 게이트 · 기억을 한 몸으로 묶은 것. 스킬·에이전트는 도구고 하네스는 한 단계 위다. FH 는 그런 하네스들이 사는 **메타**하네스 |
| **3단 공정** | ① 성공 정의(심지)를 설계 앞에 심고 → ② 다른 계열·다른 입장으로 갈라 병렬로 가속하고 → ③ 여섯 축으로 태우는 순서. 속도는 결과이고 네 번째 단이 아니다 |
| **엔진** | 출력이 실제로 나오는 코어 능력 넷 — `judgment-circuit`(심지) · `ship-gate`(품질게이트) · `context-continuity`(맥락유지) · `external-grounding`(질문하기). 이름으로 부르고 번호를 붙이지 않는다 |
| **정체성** | 방법론과 코어가 맞물려 나타나는 능력. **5대**(①~⑤)는 엔진과 별개의 실물과 등급을 가진 안정 정체성이고, 그 외는 사용 방향에 따라 나타났다 사라지는 **면모** |
| **6축 검증** | 리뷰어가 «무엇을 받았나» 로 가르는 여섯 축 — ⓐ 다른 계열 · ⓑ 대상 하네스의 입장 · ⓒ 격리 그라운딩 · ⓓ 3자 대면 · ⓔ 첫 실사용 · ⓕ 되돌림. 다 돌리지 않고 실패 모드에 맞춰 고른다 |
| **4축 마커** | FH 자산을 고친 커밋에 붙는 증거 파일 — 어느 축을 돌렸고 컨트롤이 살았는지, 성공 정의가 무엇이었는지. 설치된 pre-commit 경로에서는 없으면 커밋이 막힌다(클라이언트 훅). 검증 6축과는 **다른** 4(회귀·적대·팬텀·매니페스트) |
| **fail-closed** | 확신이 없으면 «통과» 가 아니라 «멈춤» 쪽으로 떨어지는 설계. 비가역 표면(발행·삭제·히스토리 재작성)은 전부 이 방향 |
| **미실행 ≠ 0** | 못 잰 것을 0 으로 적지 않는 규율. `UNMEASURED` · `FAILED-TO-RUN` · «안 쟀다» 는 실패가 아니라 정직한 공백이다 |
| **레인 / 레인 스위트** | 레인 = 한 검사(known-positive 와 known-negative 짝을 실행해 초록/빨강을 내는 것). 스위트 = 레인을 담은 `scripts/test_*.sh` 한 파일. «104 스위트» 는 러너가 아는 파일 수(`scripts/test_*.sh` 102 + 다른 경로 2)이고 레인 수는 그 안에서 더 많다 |
| **계열 · 입장** | 계열 = 모델 가족(Claude · Codex/GPT · Gemini). 입장 = 리뷰어가 «어느 레포의 규칙을 정본으로 읽나» — 내 레포에서 남의 하네스를 짐작하는 것과 그 하네스의 레포에서 직접 돌리는 것은 다른 입장이다 |
| **정본 · 문 · 계기** | 정본 = 그 사실이 «여기 하나에만» 사는 파일(사본이 둘이면 하나가 낡는다). 문 = 인사 뒤 뜨는 메뉴 ①~④·🔧·📖. 계기(instrument) = 무엇을 재는 스크립트 — 레인 · sim · 프로브 · 되돌림 |
| **챔버 · 원장** | 챔버 = 새 하네스/스킬 후보를 격리해 낳을지 죽일지 판정하는 인큐베이션 런. 원장(ledger) = 그 런의 결과를 한 줄씩 적는 파일(EMIT 낳음 · KILL 죽임 · CURATED 선행자료만 · NOT-APPLICABLE) |
| **residency · PSA** | residency = 회사 코드·실명·조직 자산명은 로컬에 머문다(외부 계열 모델·공개 파일로 안 나간다)는 규칙 — 그 규칙의 **기계 반쪽은 «기본 패턴 + 설정된 조직 패턴으로 잡히는 리터럴」 만 보는 스캔**이라 스크리닝이지 보증이 아니다. PSA(public-surface audit) = 공개 파일에 그런 토큰이 실렸는지 훅이 그레프하는 스캔 |
| **ARM / CTRL** | 한 변수만 다른 두 팔 — ARM 은 검증하려는 조건, CTRL 은 그 조건이 빠진 대조군. CTRL 이 안 갈리면 그 측정은 판정하지 않는다 |
| **HITL · lease · register** | HITL = 사람이 승인하는 지점. lease = 그 승인을 «인용문 · 만료일 · 범위» 로 적은 기한부 동의. register = 응답의 말투(반말/존댓말 · casual/corporate) |
| **floor · base op** | floor = 어떤 설정으로도 끌 수 없는 하한(끌 수 있으면 floor 가 아니다). base op = 정체성 하나를 단독으로 쓰는 기본 작업(감사 · 게이트 · 디스패치 한 건 · 마감) |
| **등급 (🟢🔵🟡🔴)** | 정체성·엔진에 매기는 4단 — 🟢 실제 상황에서 발화한 실물 기록 n≥1 · 🔵 구현+known-pair 보정+자기 테스트 초록이나 실발화 없음 · 🟡 조각은 돌지만 끝까지 이어진 기록 없음 · 🔴 문서만 있음. 정본 `ship_readiness_gate.md` 첫 표 |

---

## ① 무엇인가 — 3단 공정 → 4대 엔진 → 정체성, 그리고 사람이 들어오는 문

![① 무엇인가 — 문 · 3단 공정 · 4대 엔진 · 정체성](fh_process.workflow.png)

**FH 는 의도를 기계로 벼린다.** 짧은 의도를 던지면 하네스가 근거를 붙여 산출까지 벼리고, 되돌릴 수 없는 지점에서만 사람을 부른다.

1. 사람은 **인사 한 마디**로 들어온다(어느 언어든). 문 ①~④가 뜬다 — ① 프로젝트 매핑 · ② 새 프로젝트 · ③ 매핑 프로젝트 가속/진단 · ④ 크로스 시너지(프로젝트 2개 이상일 때만) · 🔧 FH 자체 개발(운영자만) · 📖 가이드/Q&A(항상). 바로 일을 말하면 메뉴는 안 뜬다.
2. Claude Code 밖에서는 **`fh-gate` CLI 하나**만 쓴다 — 어떤 코딩 에이전트의 산출물에도 후단 게이트로 붙고, Codex 백엔드와 두 계열 UNION 모드가 있다(`bin/fh-gate.js` · `docs/codex-compat.md`).
3. 어떤 작업이든 **3단 공정**을 밟는다. ① **영혼(심지)** — 무엇이 성공이고 무엇은 절대 안 하는지를 설계 *앞에* 적는다(마커 `soul:` 줄이 의무). ② **병렬 탈상관 가속** — 사각 위험에 맞춰 계열(ⓐ)·입장(ⓑ)을 갈라 병렬로 돌린다. ③ **6축 태우기** — 실패 모드에 맞는 축만 골라 태운다(`knowledge/shared/harness-core/fh_three_layer_canon.md`).
4. 출력은 **4대 엔진**에서 나온다 — `judgment-circuit` · `ship-gate` · `context-continuity` · `external-grounding`(`ship_readiness_gate.md` §The four engines).
5. 사람은 그것을 **정체성**으로 만난다. **5대**는 각자 실물(②층 표 = 경로)과 등급(정본 `ship_readiness_gate.md`, ③층에서 인용)을 가진 안정 정체성이고, 그 외는 결합에 따라 나타났다 사라지는 면모다. Ⓑ 프로젝트 부스터는 여섯 번째가 아니라 다른 층(다른 하네스의 자체 개발을 FH 기계가 가속하는 것).
6. 받는 것은 **산출물 + 4축 마커 + 세션 카드**다. 카드는 `tracks/**`(gitignored)에 남아 다음 세션이 이어받는다.
7. 🟥 **6축은 네 번째 층이 아니다** — 3단 공정 ③단의 내용물이다. 그리고 이 저장소 안에서 «4» 는 셋이다(4축 게이트 · 4대 엔진 · 옛 4축 검증) — 인용 전 어느 4인지 확인한다.

**시작하기 — 첫 명령 (세 갈래)**

| 원하는 것 | 명령 / 참조 | 얻는 것 |
|---|---|---|
| 게이트만, Claude Code 없이 | `npx --package @chrono-meta/fh-gate fh-gate` | `fh-gate` CLI(Claude · Codex · cross 백엔드) — 어떤 에이전트 산출물에도 후단 게이트 |
| 하네스 전체, Claude Code 안에서 | `git clone` + 플러그인 설치(`README.md` §② 절차) → 세션에서 «안녕» | 규칙 · 정본 · 훅 · 스킬 41 · 문 ①~④ |
| 지금 상태가 무엇인지 모르겠다 | `docs/USER_GUIDE.md` §0 의 세 줄 · `/install-doctor` | 클론만 / 플러그인만 / 둘 다 — 무엇이 되고 안 되나 |

요구 환경: git · Node ≥18 · bash(훅) · Claude Code(슬래시 커맨드·문). 무인 잡(launchd)은 **macOS 전용 선택 사항**이다.
🟥 **훅은 자동으로 켜지지 않는다** — `git config core.hooksPath templates/.git-hooks` 가 설정돼야 pre-commit/pre-push 가 돈다(`/install-wizard` 가 한다, 멱등). 미설정 클론에서는 이 문서의 «막힌다» 문장이 **전부 보장 없음**이다.

정본: `CLAUDE.md` §Identity · `README.md` §How it is built · `knowledge/shared/harness-core/fh_three_layer_canon.md`(🟥 2026-09-05 개정 진행 중 — 이 문서는 개정 방향 «3단 공정 = 모든 작업의 방법론 · 엔진 = 출력의 코어 · 정체성 = 맞물려 나타나는 능력, 5대 = 단련된 실물+등급» 을 따른다).

---

## ② 어떻게 구현돼 있나 — 노드 = 실재 경로

![② 어떻게 — 범용 코어 vs 운영자 로컬, 노드 = 실재 경로](fh_assets.architecture.png)

②번 그림의 **컴포넌트 25개가 싣는 경로 37개 전부가 이 워크트리에 실재한다**(2026-09-05 `test -e` 전수 37/37, 부재 0 —
`scripts/test_fh_map_paths_lanes.sh` 가 이후에도 매번 다시 센다). 개수는 손으로 옮긴 것이 아니라 같은 날 `ls | wc` · `lane_runner_check.sh` 실측이다.

### 진입점 — 누가 무엇을 읽나

| 읽는 주체 | 진입점 | 무엇이 실려 있나 |
|---|---|---|
| Claude Code 세션 | `CLAUDE.md` | 상주 규칙 · 문 ①~④ · 게이트 절 · 마감 체인 |
| Codex 등 다른 런타임 | `AGENTS.md` · `docs/codex-compat.md` | 이식 규칙 · 에이전트 8 표 · 검증된 호출 패턴 |
| 처음 쓰는 사람 | `docs/USER_GUIDE.md` (📖 문) | 첫 세션 완주 · FAQ |
| 슬래시 커맨드 | `plugins/fh-meta/skills` (35) · `plugins/fh-commons/skills` (6) | 스킬 **41** · 에이전트 **8**(`plugins/*/agents`) — `ls` 실측 2026-09-05, `README.md` §41 skills 와 일치 |
| 어느 셸 | `bin/fh-gate.js` · `scripts/fh-gate.sh` (+ `fh-run` · `fh-goal` · `fh-codex-doctor`) | npm `@chrono-meta/fh-gate` 3.0.0 — `package.json files[]` **259 항목**이 배포 범위 |

### 5대 정체성 — 각자의 «자기 실물» (등급은 여기 없다 → `ship_readiness_gate.md`)

| 정체성 | 사람이 얻는 것 | 자기 실물 (경로) | 등급 출처 |
|---|---|---|---|
| **① 하네스 클러스터** | 없는 능력을 짓지 않고 **다른 하네스의 것을 부른다** · 있어야 했던 것은 흡수한다 | `scripts/adapters`(어댑터 5 + 픽스처) · `.claude/capabilities` · `knowledge/shared/rules/auto_project_mapping.md` · `scripts/mapped_tracks.sh` | `ship_readiness_gate.md` 행 ① |
| **② 프로젝트 인큐베이터** | 새 하네스·스킬 후보를 격리 런(챔버)에 넣어 **낳을지 죽일지 판정**한다 — 원장 16 런 · EMIT 3 · KILL 12 · 프로브 1(운영자 로컬 원장, 2026-09-05 손계수). EMIT 조건 = net-new ∧ 산출물 형태 ∧ 실코드 정밀도 셋 동시. 낳은 것의 적용 공수는 **안 쟀다** | `scripts/chamber_run.sh`(6단 게이트 러너) · `scripts/chamber_candidate_collect.sh` · `knowledge/shared/harness-core/harness_incubator_doctrine.md` | 행 ② |
| **③ 거버넌스 게이트** | 나가면 안 되는 것이 **기계적으로** 막힌다 — 기억에 의존하지 않는다. 단 «기계」 는 **설치된 클라이언트 훅 경로**에서만 서고(`--no-verify` 로 우회 가능), 서버측 floor 는 `main` PR 전용 + `validate` 하나다 | `templates/.git-hooks/pre-commit` · `pre-push` · `.claude/rules/fh_4axis_gate.md` · `scripts/fh-gate.sh` | 행 ③ |
| **④ 프런티어 답습** | 확신이 없을 때 **책장(우리 것) → 도서관(세상 것)** 순으로 먼저 뒤져 재발명을 막는다 | `scripts/prior_art_prompt.sh`(PriorArt 훅) · `scripts/novelty_claim_check.sh`(net-new 주장 차단) · `scripts/frontier_digest_autopilot.sh` · `knowledge/shared/harness-core/deep_research_capability_ladder.md` | 행 ④ |
| **⑤ 증폭자** | 짧은 의도를 받아 명확화(`deep-clarify`) → 예산·품질 게이트 아래 실행(`goal-quench`) → 렌즈 결합(`agent-composer`)으로 잇는다. «완성까지» 는 약속이 아니라 게이트 통과가 조건이고, 자연발화 여부는 미측정(④ «모르는 부분») | `plugins/fh-meta/skills/deep-clarify` · `goal-quench` · `agent-composer` · `knowledge/shared/harness-core/intent_marshaling_general_work.md` | 행 ⑤ |
| **Ⓑ 부스터 (다른 층)** | 다른 하네스의 **자체 개발이 빨라진다** — 부르는 법이 없고 ①⑤(+②)를 함께 돌리면 그것이다 | 별도 실물 없음 — 위 셋의 결합 | 행 Ⓑ |

### 4대 엔진 — 출력이 나오는 기계

| 엔진 | 무엇 | 기계 (경로) |
|---|---|---|
| `judgment-circuit` (심지) | 성공 정의 · 기울 방향 · 절대 안 함이 설계 앞에 적혀 있는가 | `.claude/soul_tenets.txt`(원자 tenet 등록부) · pre-commit `validate_soul_present_leg` 등 차단 다리 4 · `scripts/judgment_circuit_lint.sh` |
| `ship-gate` (품질게이트) | 비가역 표면 앞의 물리 차단 — 설치된 클라이언트 훅 경로에서만, `--no-verify` 우회 가능, 서버 floor 는 `main` PR 전용 + `validate` 하나 | `templates/.git-hooks/pre-commit`(2,944 줄 · `validate_*_leg` **12**) · `pre-push`(773 줄) — `wc -l` · `grep -c '^validate_'` 2026-09-05 |
| `context-continuity` (맥락유지) | 압축 · 서브에이전트 · 머신 · 세션을 넘을 때 **실을 놓치는지를 검사하고 복구하려 한다** — 증거는 계기 4 개(프로브·로더·마감 체크·발화 착지)이고 «안 놓친다» 는 주장하지 않는다 | `scripts/compaction_probe.sh` · `scripts/session_close_check.sh`(pre-push 가 호출) · `scripts/utterance_intake.sh` · `scripts/fh_session_load.sh` |
| `external-grounding` (질문하기) | net-new 를 주장하기 전에 밖에 먼저 묻는다 | `scripts/novelty_claim_check.sh`(차단) · `scripts/prior_art_prompt.sh` · `deep_research_capability_ladder.md` |

### 계기 — 초록이 무엇을 뜻하는지 고정하는 것

| 계기 | 경로 | 2026-09-05 실측 |
|---|---|---|
| 레인 스위트 러너 | `scripts/selfcheck.sh` · `scripts/lane_runner_check.sh` | `lane_runner_check.sh` → **104 suites — 104 wired · 1 exempt · 0 declared debt**(rc=0, 이 브랜치 2026-09-05 — #642 의 oracle 레인과 이 지도의 경로 레인이 들어간 뒤). 산식 하나: 러너가 아는 suite = `scripts/test_*.sh` **102 파일** + 다른 경로의 스위트 2 = 104. 그중 1 은 EXEMPT(비용·라이브 CLI 때문에 자동 실행 금지로 **선언**한 것)이고 러너는 선언된 것도 «wired」 로 센다 → wired 104 = 실제 호출 103 + 선언 면제 1 · debt 0 |
| 격리 sim | `scripts/sim_isolated_run.sh` | 일회용 클론 · 플로어 티어 `claude -p` · ARM/CTRL · 머신 부작용 스냅샷(관측 모드는 읽기 전용) |
| 야간 live-eval | `scripts/probe_live_eval.sh` · `.claude/regression/probes_live.yaml` | 라이브 프로브 **12**(golden 33행 중 기계 규칙으로 선별) · 각 프로브 = ARM + CTRL 두 호출 |
| 되돌림 프로브 | `scripts/revert_probe.sh` | 파일 하나를 baseline 으로 되돌리고 **그 레인만** 빨개지는지 — 한 파일 = 한 뮤턴트, 일반화 금지가 헤더에 적혀 있다 |
| 정본 | `knowledge/shared/harness-core` | md **44** · `knowledge/` 전체 59 (`find` 실측) |

세 층이 어떻게 이어지는지(진입점 → 정체성 실물 → 엔진 → 계기, 그리고 위쪽 운영자 로컬 경계)는 ②번 그림의 화살표 그대로다.

---

## ③ 왜 믿을 만한가 — 각 항목에 파일 경로와 실측 레인 수

![③ 왜 믿나 — 증거가 어디서 생겨 어디로 가나](fh_trust.dataflow.png)

원칙 한 줄: **AI 가 말하는 것을 믿지 않고, 파일이 막는 것과 레인이 재는 것을 본다.** 리더는 «무엇을 막나» 와 «증거» 두 열만 읽어도 된다. 아래 수치는 전부 2026-09-05 이 워크트리(HEAD `72a2d61`)에서 직접 센 값이다.

| 항목 | 무엇을 막나 | 기제 (파일) | 증거 · 실측 |
|---|---|---|---|
| **4축 마커 커밋 게이트** | FH 자산을 «검증했다고 말만 하고» 커밋하는 것 | `templates/.git-hooks/pre-commit` `validate_marker_floor` + `validate_*_leg` 12(soul · axes-run · crossfamily · standpoint · thirdparty · defeater · affected …) | 설치된 pre-commit 경로에서 마커 부재·공허 → **커밋 차단**(화면에 어느 파일에 무엇을 쓰라고 찍힌다) · 클라이언트 훅이라 `--no-verify` 우회 가능 · 마커는 gitignored 라 CI 미검증. 레인 `scripts/test_marker_*_lanes.sh` 9 스위트 · 🟡 정직 표기: 훅은 값의 **형식**(닫힌 enum · 비공허 근거)을 검증하고 **진위**는 못 본다 — `CLAUDE.md` §자기 대조 |
| **파괴 연산 푸시 게이트** | 원격 브랜치 삭제 · force push · main 직접 푸시가 «잊고» 나가는 것 | `templates/.git-hooks/pre-push`(**클라이언트 훅** — `--no-verify` 로 우회된다) — 참조별 판정을 훅 안에서 계산, 분류 불가도 차단 | 설치된 경로에서 통과는 명시·로그되는 `DESTRUCTIVE_OP_OK=1` · `MAIN_PUSH_OK=1` 만. 레인 `scripts/test_prepush_destructive_lanes.sh`. **서버측 floor 는 `main` PR 전용(`enforce_admins`) + `validate` 필수 체크 하나** — 브랜치 삭제·force 는 서버가 안 막는다. 발행(npm · 공개 전환)은 이 행이 아니라 다음 행 + Pre-Publish 절차 |
| **사설 토큰 스캔** | 운영자 실명 · 조직 자산명 · 홈 경로가 공개 파일에 실리는 것 | pre-commit 기밀 스캔(staged 추가 줄) · pre-push 재검(푸시 범위 커밋의 추가 줄, `pre-push:429-448`) · `scripts/public_surface_scan_files.sh`(`prepublishOnly`, 발행 파일셋 **전수** — 유일한 파일셋 스캔) · `scripts/residency_closure_scan.py` | 설치된 훅 경로에서 HIGH/MED 차단 · `PUBLIC_SURFACE_OK=1` 로만 통과(로그). 범위 = **동봉 기본 패턴 + 설정된 조직 패턴**(gitignored, 없으면 기본 패턴만 돌고 경고). 이 문서와 JSON 3장 = residency **CLEAN — 그 패턴 범위 안의 스크리닝**(2026-09-05), «보내도 안전» 이 아니다 |
| **레인 스위트** | 훅·스크립트가 «있다» 로 끝나는 것 — 아무도 실행 안 하는 레인은 산문이다 | `scripts/selfcheck.sh` · `scripts/lane_runner_check.sh`(러너 없는 스위트를 센다) | **104 스위트 · 104 배선(선언 면제 1 포함) · 0 debt**(rc=0). CI `validate` 잡이 selfcheck 를 돌리고 `main` 의 **유일한 필수 체크**다 |
| **격리 sim · 첫 실사용(ⓔ)** | «읽으면 맞다» 로 규칙 변경을 끝내는 것 | `scripts/sim_isolated_run.sh` — 일회용 클론 · 플로어 티어 · ARM/CTRL 한 변수 · reps≥3 바 | 헤더가 실패한 첫 런(라이브 레포 sim 이 launchd 를 등록한 사고, 2026-08-29)을 적고 격리 범위와 **못 막는 것**을 갈라 적는다 |
| **야간 live-eval** | 규칙이 «남아 있는데 발화가 멈춘» 드리프트 | `scripts/probe_live_eval.sh` · `probes_live.yaml`(12) · `scripts/com.forge-harness.live-eval.plist` | 0 바이트 응답 = **FAILED-TO-RUN, 분모 제외**. 같은 날 두 런을 갈라 적는다 — ⓐ 2026-09-05 02:30 **launchd 예약 런** = 프로브 0 실행(launchd PATH 환경) → `NO-PROBES-RAN` 으로 남았고 «통과» 로 접히지 않았다 · ⓑ 같은 날 낮 **수동 로컬 런**(sonnet) = 12/12 실행, PASS 8 · FAIL 4(문턱 미집행) |
| **되돌림 프로브(ⓕ)** | 앵커가 장식인 것 — 지워도 초록 | `scripts/revert_probe.sh` · 각 레인의 fail-before 규약 | 이 문서의 레인도 그렇게 검증했다: 노드 경로 하나를 가짜로 바꾸면 `L2 … missing: 1 of 37` 로 빨개짐(아래 §재생성) |
| **cross-family 적대 리뷰(ⓐ)** | 한 계열의 낙관을 같은 계열이 승인하는 것 | `plugins/fh-meta/skills/auto-decorrelation` · 마커 `crossfamily:` 닫힌 enum(could-not / did-not / did-not-look 를 따로 센다) · `knowledge/shared/harness-core/field_verdict_crossfamily_gate.md` | 🟥 사이드카는 **감사만 하고 트리를 쓰지 않는다**(2026-08-21 실측 사고 뒤 규칙) · 실례: 사람 승인 지점이 빠진 결함 8건을 저자 계열은 못 보고 다른 계열 리뷰가 잡았다(`ship_readiness_gate.md` 행 ③) |
| **등급표(정체성 · 엔진)** | 정체성을 «있다» 로 파는 것 — 실발화 n≥1 없이 | `knowledge/shared/harness-core/ship_readiness_gate.md` | 2026-09-05 HEAD 기준 5대 정체성 **①②③④⑤ 전부 🟢** · Ⓑ 🟢 · 엔진 4 **전부 🟢**(승격일 각 행에 기재: ①08-16 ②08-21 ③초판 2026-07-14 부터 🟢 ④09-03 ⑤09-03 · ship-gate 08-13 · context 09-01 · grounding/judgment 08-30). 🟡 **등급은 자평이고 게임 가능하다고 그 파일이 스스로 적는다** — 이 문서는 인용만 한다 |
| **인큐베이터 원장** | 챔버가 «낳았다» 를 말로 하는 것 | `tracks/_chamber/INDEX.md`(gitignored, 운영자 로컬) · `scripts/chamber_run.sh` | **16 런 · EMIT 3(#9 · #14 · #15) · KILL 12 · 프로브 1** — 원장 손계수 2026-09-05. 🟡 «KILL 이 많다 = 잘 거른다» 로 읽지 마라 — 어휘가 2026-08-17 에 바뀌어 옛 비율은 다른 계기의 값이다 |
| **국제표준 정렬** | «믿을 만하다» 를 우리 어휘로만 말하는 것 | `docs/STANDARDS_ALIGNMENT.md` · `knowledge/shared/harness-core/iso_ai_standards_crosswalk.md` · `templates/RED_TEAM_REPORT.md` | 요약표 **25 행** = 단독 ✅ 11 · 단독 🟡 12 · 혼합(✅와 ❌/🟡 병기) 2 · crosswalk 72 행. 🟡 **«준수» 가 아니라 «정렬» 자기평가**이고 42119 절반은 아직 draft 다 — 그 페이지가 스스로 적는다 |
| **모델 등급 무관 층** | 강한 모델만 지킬 수 있는 규율 | `knowledge/shared/harness-core/sonnet_floor_doctrine.md` · `docs/model_tier_expectations.md` | base op 100% Sonnet 은 **규율(목표)**이지 측정치가 아니다. 실측 하나: 2026-09-05 낮 **수동 로컬 live-eval 런**(sonnet, 12 프로브) 분포 **PASS 8 · FAIL 4**(문턱 미집행) — 같은 날 02:30 launchd 예약 런은 0 프로브 실행(③ 표 live-eval 행). 등급이 바꾸는 것은 판단 층(결합 폭)이고 훅·레인·마커는 모델이 아니라 파일이 한다 |

③번 그림은 이 표를 **흐름**으로 그린 것이다: 변경 → 커밋 게이트 → 푸시 게이트 → 계기 → 감시·등급.

**정직 표기 — 이 표가 못 닫는 것**: ⓐ 훅은 클라이언트측이라 `--no-verify` 로 우회된다(서버측 floor 는 PR 전용 main + `validate` 하나) ⓑ 마커·매니페스트는 gitignored `tracks/**` 라 **CI 가 구조적으로 못 본다** ⓒ 등급·마커·표준 정렬은 전부 **자기 채점**이다 — 닫는 방향은 다른 계열이 그 기록을 읽는 것이고, 그 근거(병렬 두 세션 상호 정정 7건 · 판단 축 자력 적발 0)는 `CLAUDE.md` §자기 대조에 있다.

---

## ④ 사용자 맥락 분리선 — 범용 vs 운영자 로컬 vs 티어 의존

②번 그림의 위쪽 상자가 **운영자 로컬**, 아래 큰 상자가 **범용 코어**다. 답은 네 갈래다.

### 범용 — 클론(또는 npm 설치)만으로 그대로 있다

| 무엇 | 근거 |
|---|---|
| 스킬 41 · 에이전트 8 · 두 플러그인 | `plugins/` · `.claude-plugin/marketplace.json` |
| 훅 둘 + 레인 스위트 104(선언 면제 1 포함) + selfcheck | `templates/.git-hooks` · `scripts/` — `package.json files[]` 259 항목 안 |
| 정본 44 + 가이드 · 표준 정렬 · 티어 기대표 | `knowledge/shared/harness-core` · `docs/` |
| `fh-gate` CLI(Claude · Codex · cross 백엔드) | `bin/` · `docs/codex-compat.md` |
| 격리 sim · live-eval 러너 · 되돌림 프로브 · 챔버 러너 | `scripts/sim_isolated_run.sh` · `probe_live_eval.sh` · `revert_probe.sh` · `chamber_run.sh` |

### 운영자 로컬 — 클론에 없거나 gitignored. 없으면 무엇이 빠지나

| 자리 | 무엇 | 없으면 | 갈아 끼우는 법 |
|---|---|---|---|
| `CLAUDE.local.md` | 티어 · register(반말/존댓말) 핀 · 디스패치 동의(인용문 · lease · 범위 3요소) | 세션이 매번 묻는다(absent ≠ granted) · 기본 register | `install-wizard` Step 3-D 가 3요소를 받아 적는다. 템플릿 `templates/local_fh_context.md` |
| `tracks/**` | 세션 카드 · 4축 마커 · 챔버 원장 · 디스패치 원장 | 온보딩이 «새 사용자» 로 뜬다 · 마커를 새로 쓴다 · 챔버 이력 0 | 자동 생성. 보관하려면 **private companion store**(사설 저장소)를 붙인다 — 실명은 residency 규칙상 공개 파일에 적지 않아 이 문서도 그렇게만 부른다 |
| private companion store | 노드 간 카드·마커·스냅샷 동기화 | 단일 노드로 돈다 | `scripts/sync-from-be.sh` 류 — 선택 |
| launchd 무인 잡 3 | 야간 live-eval · frontier-digest · daily report — **plist 템플릿은 레포에 있고**(`scripts/com.forge-harness.*.plist`) **등록 상태만 로컬**이다 | 드리프트 감시가 없다(세션 중 검증은 그대로) | plist 를 `~/Library/LaunchAgents` 에 등록 — 🟥 «그 환경에서 첫 실사용» 을 해야 한다(2026-09-05 live-eval · digest 둘 다 로직 초록 · launchd 환경에서 사망) |
| `.claude/rules/.residency-patterns` · `.public-surface-patterns` | 조직 리터럴 패턴(조직 호스트 · 자산명 · 실명) | **커밋은 안 막힌다** — pre-commit 은 동봉 defaults 만으로 돌고 «커버리지 축소» 경고를 크게 찍는다(깨끗한 클론의 첫 커밋을 막지 않기로 한 결정). 외부 전송 전 `residency_closure_scan.py` 는 파일이 없으면 HARNESS_ERROR 로 **멈춘다**(dispatch 도구, 훅 아님) | 한 줄 = 한 패턴, gitignored |

### 런타임 축 — Claude Code 가 없는 팀에는 무엇이 남나

| 있음 | 남는 것 | 근거 |
|---|---|---|
| git + Node 만 | `fh-gate` CLI · 훅 둘(git 훅이라 런타임 무관) · 레인 스위트 · selfcheck | `bin/` · `templates/.git-hooks` |
| Codex | 위 + `SKILL.md` 를 stdin 으로 읽혀 방법론 층 실행(`codex exec -m … -`) · `fh-gate` Codex 백엔드 | `AGENTS.md` · `docs/codex-compat.md`(beta = 검증 성숙도) |
| Claude Code | 전부 — 슬래시 커맨드 · 문 ①~④ · 에이전트 디스패치 · 훅 기반 자동화 | `CLAUDE.md` |

정체성으로 말하면 ③ 게이트는 어디서나 남고, ①②④⑤ 의 **자동 발화**(문 · PriorArt 훅 · 디스패치)는 Claude Code 층이다.

### 티어 의존 — 무엇이 모델 등급을 타나

| 층 | 등급 의존 | 근거 |
|---|---|---|
| 훅 · 레인 · 마커 요구 · residency 스캔 · «미실행 ≠ 0» 분류 | **없음** — 파일이 한다 | `docs/model_tier_expectations.md` §등급과 무관한 것 |
| base op(감사 · 게이트 · 디스패치 한 건 · 마감 체인) | Sonnet 에서 100% 가 **규율(목표)** — 티어로만 발화하는 base op 는 결함. 실측은 09-05 낮 수동 로컬 live-eval 런(sonnet, 12 프로브) PASS 8/FAIL 4 뿐(같은 날 예약 런은 0 실행) | `sonnet_floor_doctrine.md` · `tracks/_meta/live_eval_2026-09-05.md`(운영자 로컬) |
| 지시된 조합 수행 | Sonnet 잘 함(단 자기 패치 구멍은 못 봄) | 실측 2026-09-05, N 작음 — `docs/model_tier_expectations.md` |
| 여러 정체성을 한 임무에 **엮는** 설계 · 리턴 재검 | Opus 기본 · Fable 거버너 온디맨드 | 관측 N=1 — **기대**로 표기, 실측 아님 |

### 모르는 부분 — 정직하게

- **①③⑤ 의 자연발화 여부는 미측정**이다(`docs/IDENTITIES.md` §어디에 서 있으면 — «안 된다» 가 아니라 «재본 적이 없다»).
- 운영자 언어 핀이 **언어까지 잠그는 결함**이 이 install 에서 실측됐다(`你好` → 한국어 응답). 깨끗한 클론에서는 재현 안 됨 — 그러므로 위 표의 «없으면» 열은 소비자 관점이고, 운영자 관점 결함은 `CLAUDE.md` §Voice/Tone 에 있다.
- 결합(엔진 2중 이상)이 어느 정체성을 드러내는지는 n=1 세션 표본이다(`tracks/_meta/DESIGN_2026-09-05_engine-composition.md`, 운영자 로컬). 반복 관측 전에는 «면모» 이름을 붙이지 않는다.
- 챔버 어휘가 2026-08-17 에 바뀌었고, 옛 어휘가 과차단했는지는 **아직 안 쟀다**(frozen known-pair 가 그걸 재기 위해 있다).
- **launchd live-eval 의 운영 유효성은 미검증/실패 상태**다 — 2026-09-05 새벽 런이 프로브 0 실행으로 끝났다(환경 PATH). 위 ③ 표의 «드리프트 감시» 는 계기가 있다는 뜻이고, 무인으로 돌고 있다는 뜻이 아니다.
- **훅 설치·활성화 여부**는 이 문서가 검증할 수 없다 — `core.hooksPath` 가 설정된 클론에서만 «막힌다» 가 성립하고, 미설치 클론에는 보장이 없다.

---

## ⑤ 표면별 갈림 — 위키 · GitHub Pages · 레포 안 정본

> 이 절만은 **FH 운영자의 결정 자료**다(이 지도를 어디에 올릴지). 처음 보는 독자는 건너뛰어도 된다.

이 절의 질문 = «지도를 위키에 넣을까, GitHub Pages 로 볼까» (운영자 요청, 2026-09-05).

**가르는 기준** (후보 제시까지 — 결정은 운영자):

| 기준 | 위키(마크다운 + PNG/SVG) | GitHub Pages(자기완결 HTML) | 레포 안 정본(README · USER_GUIDE) |
|---|---|---|---|
| 형태 | 정적 · 스크립트 불가 | 인터랙티브(검색 · 뷰 · 경로 추적 · 다크/라이트) | 텍스트 · 4개 언어 |
| 갱신 비용 | 재생성 후 PNG/SVG 교체 | 재생성 후 HTML 교체(각 ~720 KB) | 커밋 게이트 통과 |
| 낡을 위험 | 높음(수치 복사) | 중(HTML 이 소스 JSON 과 같은 커밋에 산다) | 낮음(정본이 여기) |
| 사설 토큰 | 스캔 필수(위키는 스캐너 밖) | 스캔 필수 | pre-commit 이 스캔 |

| 후보 | 표면 | 왜 |
|---|---|---|
| ① 그림 3장 PNG/SVG + 30초 요약 + 용어표 | **위키 1순위** | 리더가 «FH 가 뭔지» 를 스크롤 없이 본다 · 스크립트 불필요 · `docs/map/*.svg` 가 그대로 붙는다 |
| ② 그림 3장 HTML | **Pages 1순위** | 가이드 뷰(챕터) · 노드 검색 · 경로 추적이 산다 · 3 파일만 올리면 되고 서버 불필요. `docs/` 를 Pages 소스로 두면 이 폴더가 그대로 URL 이 된다 |
| ③ 표 ③(왜 믿을 만한가) | 위키 + 레포 | 수치가 낡는다 — 위키에는 **날짜와 함께** 붙이고 정본은 이 파일 |
| ④ 등급표 | **레포만** | 사본이 둘이면 하나가 낡는다 — 위키·Pages 는 «등급은 여기» 링크만 |
| ⑤ ④층 분리선 표 | 위키 | 도입 검토자가 가장 먼저 묻는 것(«우리 환경에 뭐가 없나») |
| ⑥ 이 문서 전체 | 레포(`docs/map/FH_MAP.md`) | 정본. 위키·Pages 는 이걸 **가리킨다** |

🟥 어느 표면이든 발행은 **Pre-Publish Surface Gate** 를 지난다(`CLAUDE.md` §Pre-Publish) — 위키·Pages 는 «이미 공개된 레포에 내용을 더하는 것» 이라 그것도 발행이다. 발행 자체는 운영자 결정이다.

---

## 이 문서가 답하지 않는 것 (정직하게)

- **도입 비용 · 시간 절감 · 결함 검출률 수치** — 안 쟀다. 여기 없는 수치는 0 이 아니다. 속도·규모 표(커밋 수 · PR 수)는 `docs/OUTPUT_EVIDENCE.md` 에 날짜와 함께 있고 그 문서가 «velocity, not maturity» 라고 스스로 적는다.
- **104 스위트가 «많다» 의 비교 기준** — 없다. 절대 수가 아니라 «어떤 레인이 무엇을 막나»(③ 표) 로 읽어야 한다.
- **다른 조직이 갈아 끼우는 데 드는 공수** — 안 쟀다. ④ 표는 *어디를* 바꾸는지까지만 답한다.
- **훅이 켜져 있는가** — 소비자 클론에서 `core.hooksPath` 설정 여부는 이 문서가 모른다. 미설정이면 ③ 표의 차단 문장은 성립하지 않는다.
- **설치 절차 전체** — ①-끝 «시작하기» 는 첫 명령까지만 답한다. 절차는 `README.md` §Pick one · `docs/USER_GUIDE.md`.
- **정체성이 정말 그 등급인가** — 이 문서는 등급표를 인용만 한다. 등급표는 자평이고 그 파일이 그렇게 적는다.

## 그림 · 재생성

| 그림 | 파일 (HTML · SVG · PNG) | 답하는 질문 |
|---|---|---|
| ① 무엇인가 | [`fh_process.workflow.html`](fh_process.workflow.html) · `.svg` · `.png` | 사람이 어느 문으로 들어와 3단 공정 · 4대 엔진 · 정체성을 거쳐 무엇을 받나 |
| ② 어떻게 | [`fh_assets.architecture.html`](fh_assets.architecture.html) · `.svg` · `.png` | 어떤 파일이 그 일을 하나 · 범용 코어와 운영자 로컬의 경계 |
| ③ 왜 믿나 | [`fh_trust.dataflow.html`](fh_trust.dataflow.html) · `.svg` · `.png` | 증거가 어디서 생겨 어디로 가나 |

그림의 소스는 옆의 `.json` 이다(타입 있는 JSON → MIT 라이선스 로컬 Node 렌더러 [archify](https://github.com/tt-a1i/archify) 의 `validate` 단계로 검증하고 `deliver` 로 컴파일했다).
**이 문서는 기존 문서를 대체하지 않는다** — `README.md`(무엇·왜) · `docs/USER_GUIDE.md`(첫 세션) · `docs/IDENTITIES.md`(무엇이 켜지나) ·
`knowledge/shared/harness-core/ship_readiness_gate.md`(등급) 가 그대로 정본이고, 이 문서는 그 위에 얹는 **처음 보는 사람용 한 장**이다.

### 다시 그리려면

```bash
# 렌더러(외부 자산, MIT) — 프로젝트 로컬 설치. 레포에는 커밋하지 않는다(.gitignore 후보: .claude/skills/archify/ · skills-lock.json)
npx -y skills add tt-a1i/archify --skill archify --agent claude-code --copy --yes
export ARCHIFY_UPDATE_CHECK_DISABLED=1          # 외부 통신(업데이트 확인) 차단
A=.claude/skills/archify/bin/archify.mjs
node $A validate workflow     docs/map/fh_process.workflow.json     --quality showcase --json
node $A validate architecture docs/map/fh_assets.architecture.json  --quality showcase --json
node $A validate dataflow     docs/map/fh_trust.dataflow.json       --quality showcase --json
node $A deliver  workflow     docs/map/fh_process.workflow.json     docs/map/fh_process.workflow.html --quality showcase --json
# (architecture · dataflow 도 같은 꼴)
# SVG = HTML 안의 유일한 <svg> 블록 + 뷰어 <style> 을 심은 정적 벡터(다크 테마 기본값으로 렌더된다)
# PNG = `node $A visual-check <html>` 이 실제 Chrome 으로 찍은 2048×1320 라이트 스크린샷(뷰어 크롬 포함) — 사이드카(*.visual-check.*)는 절대경로를 품으므로 커밋하지 않고 지운다
bash scripts/test_fh_map_paths_lanes.sh          # 노드 경로 전수 test -e (부재 0 이어야 초록)
```

- 렌더러는 **코드를 외부로 보내지 않는다** — `bin/archify.mjs` 에 네트워크 import 0, 렌더러 전체에서 네트워크 import 는 `renderers/shared/brand-marks.mjs`(명시적 `brands capture <url>` 만)와 `scripts/check-update.mjs`(고정 매니페스트 URL, 위 환경변수로 차단) 둘뿐(2026-09-05 grep 실측, v2.17.0-dev.1).
- 뷰어의 고정 UI(검색 · 범례 · Export 버튼)는 영어다 — 렌더러가 한국어 UI 를 지원하지 않아 `meta.locale` 을 비웠다. 본문(노드 · 카드)은 한국어다.
- 렌더러 `visual-check`(실제 Chrome 4 뷰포트 컨테인먼트) 결과: ② architecture · ③ dataflow **pass** · ① workflow 는 1440×900 에서 **세로 60px 초과**(4 레인 최소 높이 668 이 렌더러 하한이라 못 줄였다; 2048×1320 은 pass). 그 상태로 둔다 — 스크롤 한 번이고, 뷰어 폭 모델과 validate 폭 모델이 다른 것은 같은 날 별도 지도 작업에서도 관측된 렌더러 쪽 결함 후보다.
