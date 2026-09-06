<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/banner.png" alt="forge-harness, 프로젝트를 담금질해 통과시키면, 더 빠르게 나온다. 품질이 지렛대이고, 속도는 그 결과다." width="680">
</p>

<p align="center">
  <a href="https://github.com/walkinglabs/awesome-harness-engineering#coding-agent-harnesses"><img src="https://awesome.re/mentioned-badge.svg" alt="Mentioned in Awesome Harness Engineering"></a>
  <a href="https://github.com/VoltAgent/awesome-agent-skills#community-skills"><img src="https://img.shields.io/badge/listed_in-awesome--agent--skills-0ea5e9.svg" alt="Listed in awesome-agent-skills"></a>
  <a href="https://github.com/anthropics/claude-code"><img src="https://img.shields.io/badge/Claude_Code-compatible-a855f7.svg" alt="Claude Code compatible — official Claude Code repository"></a>
  <a href="https://chrono-meta.github.io/forge-harness/"><img src="https://img.shields.io/badge/whole_map-interactive-6366f1.svg" alt="FH whole map — interactive diagrams on GitHub Pages"></a>
  <a href="https://www.npmjs.com/package/@chrono-meta/fh-gate"><img src="https://img.shields.io/npm/v/@chrono-meta/fh-gate.svg?color=cb3837" alt="npm"></a>
  <a href="https://github.com/chrono-meta/homebrew-forge-harness"><img src="https://img.shields.io/badge/homebrew-tap-FBB040.svg" alt="Homebrew tap"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e.svg" alt="MIT License"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <b>한국어</b> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a>
</p>

<p align="center">
  <b>AI 에게 매번 설명하던 규칙을, 프로젝트마다 심어두세요.</b>
</p>

<p align="center">
  <b>당신의 에이전트도, 당신도 통과해야 합니다.</b>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/gate-block.gif" alt="regression guard blocking a change that dropped a Done When section, then passing once it is restored" width="820">
</p>
<p align="center">
  <sub>연출이 아니라 실제 실행입니다. 에이전트가 스킬 정의 파일(<code>SKILL.md</code>)을 '정리'하면서 <b>완료 조건(Done When)</b> 항목을 지웠습니다. 게이트는 사라진 항목을 이름으로 지목하고, 그 항목을 되살리면 나머지 정리는 그대로 통과합니다.<br>재생성: <code>brew install vhs &amp;&amp; vhs docs/demo/gate-block.tape</code></sub>
</p>

---

## 둘 중 하나를 고르세요. 설치도 다르고, 얻는 것도 다릅니다.

### ① 게이트만: Claude Code 없이도 됩니다

```bash
npx --package @chrono-meta/fh-gate fh-gate          # 설치할 것 없음
brew tap chrono-meta/forge-harness && brew install forge-harness   # 또는 이쪽
```

**GitHub Actions 에서** — 같은 게이트를 스텝 하나로, 판정은 타입을 유지한 채:

```yaml
- uses: chrono-meta/forge-harness@v3.1.2
  with:
    files: ${{ steps.changed.outputs.files }}
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

이 스텝은 `verdict`(PASS · PENDING · BLOCKED · ESCALATE · HARNESS_ERROR · ARG_ERROR · DRY_RUN ·
UNKNOWN)와 `reviewed` 를 내놓습니다. **`reviewed: false` 는 통과가 아닙니다** — 백엔드가 끝내 답을
주지 않은 경우, dry run, 이 래퍼가 모르는 종료 코드가 전부 여기로 떨어지고, 기본값에서는 전부 스텝을
실패시킵니다. 그 기본값이 바로 요점입니다: 돌지 않은 검사가 초록으로 읽혀서는 절대 안 됩니다. 더
느슨한 정책을 원하면 `fail-on:` 으로 바꾸되, 무엇과 바꾸는 것인지는 알고 하세요.


**얻는 것**

- 변경이 머지되기 **전에** 판정이 나오고, 그 판정은 이 변경이 **무엇을 잃었는지**를 이름으로
  말합니다. '뭔가 이상하다'가 아닙니다. 위 GIF가 실제 diff에 대한 그 판정입니다.
- 판정은 grep 할 텍스트가 아니라 **타입이 있는 값**입니다: `PASS · PENDING · BLOCKED · ESCALATE`.
- 셸이 도는 곳이면 어디서나 돕니다. CI, pre-commit 훅, 다른 코딩 에이전트. Claude Code는 선택입니다.
- **에이전트의 코드만이 아니라, 당신이 쓴 코드도 봅니다.** diff 를 가리키면 약한 자리를 이름으로
  말합니다 — 조용히 PASS 쪽으로 열화되는 판정, 존재하지 않는 참조, 새어 나간 비밀, 근거 없는 주장 —
  그래서 머지 *전에* 고치고 다시 돌립니다. 각 FH 엔진이 어디에 걸리는지(하네스 짓기 · 스킬/에이전트
  작성 · 코드 리뷰 · 비가역 표면 게이트 · 맥락 연속성), 그리고 모델 티어와 노력 수준에 따라 무엇이
  달라지는지: [`docs/USE_CASES.md`](docs/USE_CASES.md) ·
  [`docs/model_tier_expectations.md`](docs/model_tier_expectations.md).
  이 게이트들이 ISO/IEC 의 AI 시험 · AI 품질 표준(42119 · 29119-11 · 25059 · 42001)과 어떻게
  맞물리는지를, 증거 포인터를 붙인 자기평가로:
  [`docs/STANDARDS_ALIGNMENT.md`](docs/STANDARDS_ALIGNMENT.md).

### ② 하네스 전체: Claude Code 안에서

```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness
claude plugin install -s user fh-qp@forge-harness      # 선택: QP(Quality Platform) — 세션의 Playwright / computer-use MCP 로 웹·데스크톱 앱을 계획→실행→회귀
git clone https://github.com/chrono-meta/forge-harness.git ~/projects/forge-harness
cd ~/projects/forge-harness && claude        # 그다음 인사 한마디: 안녕 · hi · こんにちは · 你好
```

<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/door2-menu.gif" alt="갓 클론한 forge-harness 에서 hi 를 치자 FH 가 체크아웃을 읽고 신규 사용자 메뉴를 열며 설치 마법사가 아직 안 돌았다고 알린다" width="820">
</p>
<p align="center">
  <sub>네 번째 줄이 하는 일 전부입니다. 몇 분 전에 만든 클론입니다. 체크아웃을 읽고, 세션 파일이 없는 것을 보고, <b>신규 사용자</b> 메뉴를 엽니다. 그리고 마법사가 아직 안 돌았다고 알려 줍니다.<br>실행과 대기 시간은 숨겼습니다. 화면의 모든 글자는 그 실행의 출력입니다. 다시 만들기: <code>vhs docs/demo/door2-menu.tape</code></sub>
</p>

**①에 더해 얻는 것**

- 어떤 검사를 걸지 고르지 않아도 됩니다. 지금 무엇을 하려는지 — 공개, 삭제, 이력 재작성, PR —
  를 읽고 그 자리에 맞는 게이트를 이름으로 불러 줍니다. ①이 기억해서 치는 명령 하나라면,
  ②는 대신 기억해 주는 층입니다.
- **스킬 41종 · 에이전트 8종**을 평범한 말로 부릅니다. 프로젝트를 진단하고, 가속하고, 새로 배선합니다.
- `tracks/` 가 각 세션이 알아낸 것을 남겨서 **두 번째 세션이 첫 세션이 멈춘 자리에서 시작**합니다.
  복리가 붙는 곳이 여기이고, 첫날에는 판단할 수 없는 것도 여기입니다.
- 같은 것을 세 번 부탁하면 답하기를 그만둡니다. 대신 그 답을 하는 하네스를 만들어 줍니다.

<sub>🟥 <b>②가 주지 '않는' 것 하나.</b> FH 에는 4축 <b>pre-commit</b> 훅도 있는데, 그건 여러분의
레포용이 아닙니다. 허브 경로와 허브 마커를 코드에 박고 있어서 여러분 프로젝트에 깔면 도움이 되는
대신 커밋을 막습니다. 설치 마법사도 이걸 선택 항목으로 두고 'FH 자체를 개발하는 게 아니라면
건너뛰라'고 말합니다. <b>여러분 레포의 게이트는 ①입니다</b> — CI 나 직접 만든 pre-commit 에 거세요.</sub>

<sub><b>고르기 어려우면</b> ①부터 하세요. 명령 하나면 되고 지울 것도 없습니다. ②는 ①을 품고 있어서
①에서 익힌 것은 하나도 버려지지 않습니다.</sub>

### 두 문 다 '아닌' 것

**뒷단의 검토를 대신하지 않습니다.** 질문을 앞으로 당길 뿐입니다. 사람 검토자에게 닿는 양이
줄어드는 것이지, 사람이 검토를 그만두는 것이 아닙니다. 겨냥하는 병목은 '만들어지는 속도'와
'사람이 확인하는 속도' 사이의 간격이고, 뒤로 넘어가야 할 것을 줄여서 그 간격을 **앞쪽에서** 좁힙니다.

**diff 로 볼 수 없는 것은 여전히 사람의 몫입니다.** 실제로 돌려 봐야 드러나는 것 — 진짜 화면에서,
진짜 상태를 놓고 — 은 이 도구들이 닿는 범위 밖입니다. 그 일은 앞에 게이트가 있다고 줄어들지
않습니다. 줄어드는 건 대기열입니다.

---


## 정말로 뭔가를 잡아내나요?

**남이 쓴 실제 코드에서** (2026-05-31). `fh-gate` 를 OpenCode 의 AI-생성 `permission/arity.ts`
에 돌렸습니다. 163줄, 에이전트가 쓴 코드, **CI 초록**. 판정은 **BLOCKED**, CI 가 놓친 A급 발견
2건 때문입니다(허용목록의 짧은-토큰 오버플로, arity 테이블에서 빠진 executor 도구).

**심어 둔 구멍에서, 모델은 고정한 채** (2026-07-14). 미묘한 *default-toward-PASS*(fail-open)
구멍 8개를, 테스트셋이 우리 방법에 맞춰지지 않도록 *다른* 두 모델이 만들었습니다. 모델은
중간-티어 바닥에 고정했고, 바꾼 것은 **방법**뿐입니다.

| 방법 | 잡은 것 | 오탐 |
|---|---|---|
| 평범한 리뷰 | 5/8 — **그중 둘은 엉뚱한 버그를 잡은 것**(잘못된 확신, 깨끗한 미스보다 나쁨) | — |
| + FH 의 degrade-direction 렌즈 | 6/8 | 0 |
| + 다른 모델 패밀리, 같은 렌즈 | **8/8** | 0 |

🟥 **하중을 지는 줄은 8/8 이 아닙니다.** 두 단일-모델 레인이 **같은 두 구멍**을 놓쳤습니다 —
falsy 에러-센티널, 그리고 구분자-부정 파싱. 같은 입력, 같은 사각. 같은 종류의 두 번째
리뷰어였어도 놓쳤을 것입니다. 그게 decorrelation 의 유일한 근거이고, 나머지는 산술입니다.
표본이 작습니다(단일 추출). 반복 실행과 더 어려운 구멍이 명시된 다음 단계입니다. 방법:
[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) §Dominance ·
날짜별 실행 더 보기: [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md).

<p align="center">
  <b>품질이 지렛대이고, 속도는 그 결과입니다.</b> ·
  <a href="docs/ETHOS.md"><b>원칙</b></a> ·
  <a href="docs/WHY.md"><b>존재 이유</b></a> ·
  <a href="docs/OUTPUT_EVIDENCE.md"><b>증거</b></a> ·
  <a href="CHEATSHEET.md"><b>사용법</b></a><br>
  <sub>도움이 됐다면 ⭐ 하나가 다른 분이 찾는 데 도움이 됩니다.</sub>
</p>

| 이런 이유로 왔다면… | forge-harness가 해결합니다 |
|---|---|
| 세션이 끝나면 맥락이 사라진다 | 영속 `tracks/` · 어디서든 이어서 재개 |
| 프로젝트마다 같은 설정을 반복한다 | 허브에 한 번 연결하면 모든 프로젝트가 공유 |
| 팀의 AI 노하우가 사람 머릿속에만 있다 | 코드로 박아 모두가 공유 |
| 작업이 쌓일수록 AI가 *더 나아지길* 원한다 | 스킬과 패턴이 세션을 거듭하며 복리로 쌓임 |
| AI가 생성한 코드에 거버넌스 층이 필요하다 | `fh-gate`가 어떤 코딩 에이전트든 생성-후 게이트로 감쌈 |

> **이 문서는 사람이 읽는 문서입니다.** AI 운영 규칙 → [`CLAUDE.md`](CLAUDE.md) · 명령어 레퍼런스 →
> [`CHEATSHEET.md`](CHEATSHEET.md). 위의 두 문이 결정의 전부이고, 아래는 필요할 때 찾아보는
> 참고 자료입니다.

---

## 시작하기

**`안녕` 이라고 입력하세요.** `hi` · `こんにちは` · `你好` · `hola` · `bonjour`, 어느 쪽으로
인사해도 번호가 붙은 메뉴가 열립니다. 문을 고르고 몇 가지에 답하면 설치 마법사까지 대신 돌려
줍니다. **"프로젝트 연결해줘"** 라고 하면 허브가 `../` 를 스캔해 `.git` 디렉터리를 찾고
`tracks/{project}/` 를 만듭니다.

<sub>🟥 <b>여기에 대해 정직하게</b>: 언어를 맞추는 것은 기계 게이트가 없는 산문 규칙이라 늘
지켜지지는 않습니다. 2026-08-21 깨끗한 클론에서 블라인드로 재 보니 메뉴 전체를 그 언어로
번역했지만, <b>메뉴가 뜨는지</b>는 더 흔들립니다. 인사말 한 종류에서는 메뉴가 아예 안 떴습니다.
말씀하시면 바로 바꿉니다. 덮지 않고 <code>CLAUDE.md</code> §Voice/Tone 에 적어 두었습니다.</sub>

**전제 조건.** ②에는 Claude Code CLI 가 필요합니다(`claude --version`). ①에는 필요 없고, 그것이
①이 따로 있는 이유입니다. 게이트 하나에는 추가로 **Python + PyYAML** 이 필요합니다(YAML 을
파싱하고, 없으면 fail-closed 로 막혀 `npm test` 전체가 빨개집니다):
`python3 -m pip install --user pyyaml`. 왜 fail-closed 인지는
[`CHEATSHEET.md`](CHEATSHEET.md) §6.

**처음 15분.** 어떤 언어로 인사하든 🐿️ 문 메뉴가 뜨고 "프로젝트 연결해줘"가
`tracks/{your-project}/` 를 만들면 설정이 된 것입니다. 그다음 같은 세션에서 하나 챙기세요:
**"이 프로젝트 가속화해줘"**(순위가 매겨진, 설치는 게이트를 거치는 계획) 또는
**"/context-doctor 돌려줘"**(토큰 낭비 스캔). 전체 초기 설정 — 훅 · 게이트 · 베이스라인, 항목마다
개별 승인하고 거부는 기록됩니다 — 은 **`/install-wizard`** 를 요청하세요. 정직한 주석 하나:
FH 의 보상은 **복리**이고 **2번째 세션부터** 드러납니다. 첫날에 얻는 것은 메뉴, 계획, 게이트이니
첫날로 판단하지 마세요. 이미 다른 곳에 클론했나요? 그 경로가 허브입니다. 낯선 용어는 →
[`GLOSSARY.md`](knowledge/shared/GLOSSARY.md). ②를 프로젝트 하나에만 써보고 싶다면
[`templates/starter_profile.md`](templates/starter_profile.md) 가 명령 하나에 엄선한 첫 5개입니다.

> ⚠️ **플러그인만 깔면 부분 시너지입니다.** 허브를 클론하지 않고 플러그인만 설치할 수 있습니다
> (`claude plugin install -s user fh-meta@forge-harness` 후 프로젝트로 `cd`). 스킬과 에이전트는
> 얻지만 허브 쪽 오케스트레이션은 **얻지 못합니다** — `CLAUDE.md` 거버넌스도, 그것들을 세션에
> 걸쳐 복리로 만드는 `tracks/` 기억도.
>
> 🟥 **버전 번호가 둘이고, 서로 다른 것을 잽니다.** **패키지 버전**(위쪽 npm 배지)은 설치되는
> 것이고, **정체성 성숙도 릴리스**(`identity-v1.0.0`, Releases 페이지)는 하네스가 어디까지
> 왔는지입니다. 후자가 `0.x` 인 것은 설계입니다 — 다섯 정체성이 다 초록이 아닌데 초록이라고
> 부르기를 거부하기 때문입니다. 둘은 한 척도가 아니고, 패키지 번호가 높다고 성숙한 것이
> 아닙니다: [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md).
> 🟢 **2026-09-04 — 두 카운터가 합쳐집니다.** `identity-v1.0.0`(정체성 전부 🟢)은 정체성 트랙의
> **마지막** 태그이자 *Latest* 배지를 다는 첫 태그입니다. 이후로 릴리스는 **둘을 한 번호로** 냅니다
> — 다음은 정체성 1.0 을 실어 나르는 패키지 메이저입니다 — 그리고 릴리스 노트는 영문으로 쓰고
> 한국어 요약을 붙입니다. 위 문단은 전부 초록이 아니던 동안 트랙을 왜 나눠 두었는지의 근거로
> 남깁니다. 지금의 규칙이 아니라 이력입니다.

---

## 도구 상자가 아니라 하네스인 이유

하네스는 사람의 **의도**를 읽어 **기계화된 형태**로 벼립니다 — AI 가 신뢰성 있게 따르는 규칙,
또는 모델이 아예 필요 없는 결정적 코드로. 그 보상은 **사람 쪽 시행착오의 감소**입니다: 요청 →
피드백 → 재생성 루프가 하네스 안으로 *자리를 옮겨* 병렬로 돌고, 사람의 주의는 변경이 되돌릴 수
없는 지점에만 쓰입니다. **스킬 · 에이전트 · 플러그인**은 하나의 도구입니다. **하네스**는 한 급
위, 하나의 *별(star)* 입니다 — 한 프로젝트의 도구 · 규칙 · 게이트 · 기억이 하나의 작동하는
몸으로 묶인 것. **forge-harness 는 그 별들이 사는 은하계입니다** — 여러 하네스를 공통 바닥 위에
묶어, 흩어지는 대신 함께 진화하게 합니다. 현장 하네스를 자기 샌드박스 안에서 **시뮬레이션으로
돌려보고** 독립된 하네스로 **내보내는(EMIT)** 것도 합니다 — 🟥 그 단계는 지향하는 방향으로
읽으세요, 출하된 기능이 아닙니다. 챔버는 한 번 내보냈고, 그 실행은 전체 흐름을 거치지 않았습니다.

```
forge-harness/   ← 허브 (영속 두뇌)          Project A ──→ CLAUDE.md 에서 허브 연결
├── knowledge/   → 모든 프로젝트가 공유       Project B ──→ CLAUDE.md 에서 허브 연결
└── tracks/      → 프로젝트별 작업 기록
```

구조적으로는 **두 층**입니다 — 모델에 구애받지 않는 **방법론 층**(`tracks/`, `knowledge/`,
`SKILL.md` 문서)과 Claude-Code-네이티브인 **자동화 층**(에이전트, 훅, 슬래시 명령, `CLAUDE.md`
규칙). 그 경계는 메꿔야 할 갭이 아니라 의도된 것입니다:
[`docs/codex-compat.md`](docs/codex-compat.md). **이것이 서 있는 자리 (2026):** 기본적인 에이전트
오케스트레이션은 표준 인프라로 상품화되고 있고, FH 는 그 배관에 아무것도 걸지 않습니다. FH 의
영속 층은 상품화되지 않는 것입니다 — 거버넌스 게이트, 드리프트 통제, 프로젝트 간 복리 루프.
라우팅과 디스패치는 수단이고, **게이트와 루프가 자산입니다.**

### 다섯 정체성 — FH 는 무엇을 위한 것인가

다섯 개의 모듈도, 출하된 기능 다섯도 아닙니다. 스킬들이 **뭉쳐서 만들어내는 형태**들이고,
위에 새로 얹은 층이 아니라 이미 흩어져 있던 것에 나중에 이름을 붙인 것입니다.

| | 정체성 | 사람이 얻는 것 |
|---|---|---|
| **①** | **하네스 클러스터** | 하나의 작업이 여러 하네스를 타고, 거버넌스는 그 *사이에서* 계산됨 — 없는 능력은 짓지 말고 **호출**하고, 지어야 할 것이 보이면 **흡수** |
| **②** | **프로젝트 인큐베이터** | 새 하네스가 빈 스캐폴드가 아니라 **태어난 자리에서 이미 걷는 상태로** 나옴 |
| **③** | **거버넌스 게이트** | 나가면 안 되는 것이 점검을 기억해서가 아니라 **기계적으로** 막힘 |
| **④** | **프런티어 답습** | 확신이 안 서면 *이미 가진 것* → *세상이 만든 것* 순으로 먼저 뒤져, 다시 짓지 않음 |
| **⑤** | **증폭자** | 짧은 의도가 완성된 산출물까지 다듬어짐 |

여섯 번째 행은 의도적으로 없습니다: `Ⓑ` **프로젝트 부스터** — FH 의 기계가 *상대 하네스의 자체
개발*을 가속하는 것 — 은 실재하고 등급도 매겨져 있지만 다른 층에 앉습니다. 번호 대신 문자를 쓰는
이유가 그것입니다. **그리고 이 표는 작동하는 기능 다섯이 아닙니다**: 성숙도는 정체성별로
(`지향 → 부분 → RC → REALIZED`) 날짜 박힌 증거와 함께 채점되며, 여기 옮겨 적지 **않습니다** —
두 파일에 나눠 둔 등급은 한쪽이 반드시 낡고 이 페이지는 4개 언어로 존재합니다. 어느 행이든 믿고
쓰기 전에 등급을 읽으세요:
[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md). 그리고 **각각을 어떻게 쓰는지** — 어느 명령·어느 문이 어느 정체성을 켜는지 — 는 [`docs/IDENTITIES.md`](docs/IDENTITIES.md) 입니다. 등급은 *얼마나 준비됐나*를, 그 문서는 *어떻게 부르나*를 말합니다.

다섯 전부를 가로지르는 성질이 둘 있습니다. **프런티어를 메꾸는 게 아니라 함께 탑니다** — 여러
패밀리(Claude, Codex, Gemini, 로컬)에 디스패치하는 것은 약점을 땜빵하려는 게 아니라 공진화하려는
것입니다. **탈상관(decorrelation)** 은 지금의 신뢰 지렛대이자 이 페이지에서 하중을 지는
단어입니다: 두 검사가 *다르게* 실패하도록 일부러 만드는 것 — 다른 모델 패밀리, 진짜 대상에 대한
한 번의 실행, 내 기록에 대한 외부 감사 — 그래서 하나가 못 보는 것을 다른 하나가 봅니다. 그리고
**두 방향으로 진화합니다**: 밖으로, 매 세션의 교훈이 허브에 복리로 쌓이고, 안으로, 같은 게이트를
하네스 자신에게 돌립니다.

---

## 어떻게 만들어졌나 — 셋 · 넷 · 다섯 · 여섯

**3단 공정 · 4대 엔진 · 5대 정체성 · 6축 검증.** 위의 정체성은 공정과 엔진이 맞물리는 자리에서
나타나는 것입니다 — 다섯은 단련되고 등급이 매겨진, 안정된 것들이고, 그 밖의 정체성은 어느 방향으로
몰고 얼마나 밀어붙이느냐에 따라 나타났다 사라집니다(운영자 정식화, 2026-09-05). **4대 엔진**
(`judgment-circuit` · `ship-gate` · `context-continuity` · `external-grounding`)은 FH 다운 산출이
전부 거기서 나오는 코어이고, **3단 공정** — ① 설계 *전에* 판단 회로를 심고 → ② 중간은 병렬 탈상관 →
③ 마무리로 6축을 태운다 — 은 엔진을 벼릴 때를 포함해 FH 의 모든 작업이 밟는 순서입니다. 속도는 맨
끝의 화살표지 네 번째 상자가 아닙니다. **전체 지도** — FH 가 무엇인지, 어떻게 구현돼 있는지(모든
노드가 실재하는 경로), 왜 믿을 만한지(게이트 · 레인 · 등급을 파일 경로와 함께), 무엇이 운영자
로컬이고 무엇이 일반적인지 — 는 한 페이지에 있습니다: [`docs/map/FH_MAP.md`](docs/map/FH_MAP.md).
그 옆에 인터랙티브 다이어그램 세 장이 있고, **[chrono-meta.github.io/forge-harness](https://chrono-meta.github.io/forge-harness/)** 에서 바로 볼 수 있습니다.

[![FH 전체 지도 — 문 → 3단 공정 → 4대 엔진 → 정체성으로 이어지는 흐름(클릭하면 인터랙티브 버전)](docs/map/fh_process.workflow.png)](https://chrono-meta.github.io/forge-harness/map/fh_process.workflow.html)
⚠️ **6축은 네 번째 층이 아닙니다** — 3단 공정 *③단계가 무엇으로 이루어지는지*입니다. 전체 정본과,
왜 이것이 의도적으로 깔끔한 스택이 *아닌지*:
[`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md) — 같은 셋을
대장장이의 말(벼림 · 담금질 · 뜨임)로 옮긴 것은 [`ETHOS.md`](docs/ETHOS.md#the-forge) 에 있습니다.

🟥 **축은 '얼마나 적대적인가'가 아니라 '무엇을 받았는가'로 갈립니다.** 두 리뷰어에게 같은 입력을
주면 몇 명을 붙여도 같은 사각이 남습니다:

| 축 | **받는 것** | 무엇이 틀린 경우를 잡나 | 대표 계기 |
|---|---|---|---|
| **ⓐ 다른 패밀리** | 변경분 + 저자의 프레이밍 | **구현**이 틀림 | 다른 모델 패밀리의 리뷰어(`auto-decorrelation`) |
| **ⓑ 입장** | 변경분 + **대상 하네스의 정본** | **인용한 규약이 정말 그렇게 말하나** | 그 하네스 자신의 레포·규칙에서 변경분을 돌림 ([`§7`](knowledge/shared/harness-core/field_verdict_crossfamily_gate.md)) |
| **ⓒ 격리 그라운딩** | 저자가 쓴 문장 — 주장 *그리고* **시작 전에 선언해 둔 것** — + 지금의 트리 | **주장**이 틀림 · 델타가 선언한 것과 안 맞음 | 그것을 쓰지 않은 쪽이 적힌 내용을 다시 잼 |
| **ⓓ 3자대면** | 문제 + **남의 코드베이스** | **이미 풀린 문제 아닌가** · 내 변경이 남의 레포를 어디서 만지나 | 관련 없는 제3의 레포에서 같은 문제를 봄 |
| **ⓔ 첫실사용** | 실물 대상 한 건 | **재는 방식**이 틀림 — 계기의 계기 | 진짜 대상 하나에 돌리고 손으로 확인 |
| **ⓕ 되돌림** | 배선을 지운 트리 | **앵커**가 틀림 — 검사가 장식임 | 지키는 대상을 지우고 *바로 그* 검사가 빨개지는지 확인 |

**여섯을 매번 다 돌리지 않으며, 그것이 설계입니다** — 곱하지 말고 고르세요:

```
한 줄 수리(오타 · gitignore)   아무것도 안 태움 — 답이 하나면 회로를 심는 것이 오버헤드
일반 코드 변경(가역)            ⓔ 첫 실사용 + ⓕ 되돌림
판정 · 게이트 코드              + ⓐ 다른 패밀리 — 판정 로직은 저자와 같은 낙관을 공유하는
                                리뷰어가 구조적으로 놓침
남의 하네스에 닿는 변경         + ⓑ 입장 — 패밀리를 셋 붙여도 전부 내 프레이밍을 먹으면
                                '그 정본이 그렇게 말하나'는 아무도 안 봄
초대형 · 비가역                 + ⓒ 격리 + ⓓ 3자 대면. 전부 태움
```

축은 *리뷰어의 능력*이 아니라 **입력**으로 정의되므로 기반 모델 발전으로 대체되지 않습니다.
모델이 세져도 받지 않은 정보는 여전히 못 봅니다. 🟥 **인용 전에 읽어야 할 한계** — 이 표는
**n=1**(한 산출물 · 한 세션 · 한 저자)이고, 발견 16건을 출처를 지운 채 다른 패밀리 분류자 둘에게
넘겼더니 저자가 ⓓ 로 귀속시킨 **5건 중 3건**이 다른 축으로 판정됐습니다. 이 게이트들 안에서 보낸
하루를, 놓친 것까지 이름으로: [`docs/GATE_DAY.md`](docs/GATE_DAY.md).

> **'4'가 여럿입니다.** 이 저장소 안에서 **4축 게이트**(커밋 경계: 회귀 · 적대 · 팬텀 ·
> 매니페스트)와 **4대 엔진**(능력 층)과 **4축 검증**(→ 위 6축으로 확장)은 서로 다른 것입니다.
> 셋은 부분적으로만 겹치고 서로 대체하지 않으므로, 6축은 '6축 게이트'가 아니라 '**6축 검증**'
> 으로 부릅니다. 셋을 나란히 놓은 표:
> [`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md) §1-a ·
> 커밋 게이트의 축별 계기와 무엇을 잡는지:
> [`fh_4axis_gate.md`](.claude/rules/fh_4axis_gate.md) §Axis ownership.

---

## 규칙이 앉는 자리 — 세 좌석

하네스는 규칙을 적어 두면서 배우고, 상시 로드되는 파일은 길어지기만 합니다. 그래서 추론이 막다른
데로 갑니다 — *계속 배우는 하네스는 계속 시작 비용이 비싸진다.* 그렇지 않습니다. 규칙에는 **세
좌석**이 있고, *언제 발동해야 하는가*로 자리가 정해지기 때문입니다: **상시 로드**(트리거가
*의도*인 것 — 훅을 걸 수 없으니 살리언스가 유일한 층) · **게이트 자신의 에러 메시지**(트리거가
*행위*인 것. 막아 세우는 그 메시지가 형식도 가르치고, 이 자리는 공짜입니다) · **훅**(기록의
속성 — 있는가, 타입이 맞는가, 귀속되는가, 공허하지 않은가). 대개 비어 있는 것이 가운데
좌석입니다. 전체 표와, '실패할 때만 뜬다'는 정직한 한계:
[gate-locality](knowledge/shared/harness-core/gate_locality_principle.md) §Where a rule lives.

---

## Claude Code 밖에서 돌리기 — `fh-gate` CLI

FH 는 어떤 코딩 에이전트(OpenCode, Codex 등)든 **생성-후 거버넌스 게이트**로 감쌉니다.

```bash
npx --package @chrono-meta/fh-gate fh-gate                    # 기본: Claude 백엔드
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate   # Codex 백엔드
FH_BACKEND=cross npx --package @chrono-meta/fh-gate fh-gate   # 두 패밀리 모두, findings 를 UNION
# → FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE
```

모든 런타임에 같은 거버넌스 프롬프트를 씁니다. `auto` 는 폴백 *선택*이라 레그를 **하나만**
돌립니다. `cross` 는 두 패밀리를 돌려 findings 를 union 하고(한쪽만 본 지적도 지적입니다) 비용이
약 2배라, 기본값이 아니라 판정 · 게이트 · 비가역 표면 변경에 씁니다. 출력은 실제로 돈 레그를 항상
밝히므로, 단일 패밀리 결과가 교차검증된 것처럼 읽히지 않습니다. `fh-run`(스킬이나 에이전트를 직접
실행) · `fh-goal` · `fh-codex-doctor`(어댑터 드리프트 검사)가 함께 출하됩니다 — 플래그와 전체 환경
변수 표는 [`CHEATSHEET.md`](CHEATSHEET.md), 스펙은
[`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md).
**권장 자세 — Claude Code 를 오케스트레이터로, 나머지를 사이드카로**: 비-CC 런타임을 메인
에이전트로 둘 수도 있고 `fh-gate`/`fh-run` 을 통해 방법론 층은 유지되지만, 오토파일럿은 얻지
못합니다(훅이 자동 발동하지 않고 디스패치에 어댑터가 필요합니다) — 티어별 상세는
[`docs/codex-compat.md`](docs/codex-compat.md).

---

## 모델 설정

Claude Code 는 작업 복잡도로 모델을 자동 선택하지 않습니다. 이것은 한 번 설정합니다.

| 명령 | 누가 무엇을 실행 | 최적 용도 |
|---|---|---|
| `/model sonnet` | Sonnet 세션 · FH 가 선언된 바닥에서 상위-티어 서브에이전트를 디스패치 | **FH 기본값** — 운용 + 일상 개발 |
| `/model opus` | Opus 가 전부 처리 | 하네스-편집 세션 · 매 턴 최대 깊이 |
| `/model opusplan` | Opus 가 *계획* · Sonnet 이 실행 *(Opus 가 관여할 때)* | 비용 의식적 일상 코딩 — 주의사항 참조 |

측정 결과 FH *운용*은 거의 모델-평탄합니다 — 맥락에 든 규칙이 일을 합니다. 그래서 FH 는 깊이에
민감한 소수의 턴만 스스로 선언된 바닥으로 디스패치하고 **사용자의 세션 모델은 절대 바꾸지
않습니다**. 바닥보다 낮게 상한이 걸린 환경에서는 조용히 열화되는 대신 명시적 `below-floor` 플래그가
붙습니다. ⚠️ `opusplan` 의 Opus 관여는 **보장되지 않습니다**(측정한 10턴 실행에서 0턴). 그 독트린
뒤의 두 구조 법칙, 선택적 로컬 사이드카를 위한 하드웨어 티어, 멀티모델 사이드카 자세:
[`docs/MODEL_SETUP.md`](docs/MODEL_SETUP.md).

---

## 41 skills · 8 agents

개수 = 폐기되지 않은 스킬. 검증 · 오케스트레이션 · 진단 · 수확 · 게이트 · 발견 · 시뮬레이션 ·
설정으로 묶이고, 여기에 에이전트 8종(`challenger` · `quench-challenger` · `beginner` ·
`main-player` · `expert` · `fact-checker` · `hub-persona-auditor` · `persona-innovator`)이 그
스킬들에 의해, 또는 이름으로 직접 디스패치됩니다. **전체 표현집** — 모든 스킬과 에이전트의 한 줄
정의와 그것을 발동하는 표현:
[`CHEATSHEET.md` §12](CHEATSHEET.md#12-skills--agents--what-each-does-and-what-to-say).

---

## 더 알아보기

| 리소스 | 목적 |
|---|---|
| [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) | 실제로 쓰는 법, 처음부터 끝까지 |
| [`CHEATSHEET.md`](CHEATSHEET.md) | 전체 명령어 레퍼런스 |
| [`docs/ETHOS.md`](docs/ETHOS.md) | FH 가 믿는 것 — 대장간, 냉정한 리뷰어, 말값을 하는 주장 |
| [`docs/WHY.md`](docs/WHY.md) | 존재 이유 |
| [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md) | 증거 — 논문, 날짜별 실행, 외부 수렴 |
| [`docs/GATE_DAY.md`](docs/GATE_DAY.md) | 게이트 안에서 보낸 하루, 측정된 것과 놓친 것 |
| [`docs/MODEL_SETUP.md`](docs/MODEL_SETUP.md) | 어느 모델로 FH 를 돌릴지, 하드웨어 티어, 사이드카 |
| [`docs/codex-compat.md`](docs/codex-compat.md) | 비-Claude-Code 런타임에서 FH 돌리기 |
| [`knowledge/shared/GLOSSARY.md`](knowledge/shared/GLOSSARY.md) | 낯선 용어 |
| [`CLAUDE.md`](CLAUDE.md) | AI 운영 규칙 + 동기화/푸시 프로토콜 |
| [`AGENTS.md`](AGENTS.md) | 런타임 에이전트 스펙 |
| [`CATALOG.md`](CATALOG.md) | 과거 작업 검색 인덱스 |
| [`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md) | 3층 정본 — 공정 · 엔진 · 정체성 |
| [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) | 정체성 등급, 두 버전 트랙, 우세성 결과 |
| [`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md) | 거버넌스 게이트 스펙 |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | 스킬과 패턴 기여 방법 |
| [`tracks/_contrib/`](tracks/_contrib/README.md) | **동의 레인** — 비식별화된 작업 세션 공유. 레포가 운영자들에 걸쳐 복리로 쌓임 |

> **FH 논문**: v1.0.1 방법론 · [Zenodo](https://zenodo.org/records/22542168) (DOI
> 10.5281/zenodo.22542168) · cs.SE companion v1.1, 게재됨 ·
> [Zenodo](https://zenodo.org/records/20740038) (DOI 10.5281/zenodo.20740038) · cs.AI companion
> 준비 중. 이것들과 독립적인 수렴 연구, 그리고 각각의 주의사항:
> [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md).
