# forge-harness (fh-meta) Changelog

All notable changes to fh-meta plugin and all skills.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

**Version policy**: v0.x = internal validation phase / v1.0 = external install confirmed

---

## Plugin Level

### [1.4.99] — 2026-08-15

**fix: 검출기가 «호출부 0» 을 «10/10 초록» 으로 보고하고 있었다 — 그리고 이 릴리스는 #388 의 첫 출하이기도 하다**

- 🔴 **`lane_runner_check.sh` 가 거짓 초록을 생산했다.** 이 도구의 존재 이유가 «호출자 없는 레인
  찾기» 인데, `has_selftest_runner()` 가 subject **자기 파일**을 `runners` 에 포함하고
  `selftest_dispatched()` 가 주석줄을 안 걸렀다. 그래서 `directional_diff_gate.sh` 가 **자기 usage
  주석**(`#   bash scripts/directional_diff_gate.sh --self-test`)을 호출부로 오독당해, 실제 호출부가
  **0개**인데 리포트는 `self-test: 10/10 wired` 를 찍었다. 같은 파일의 `has_runner()` /
  `runner_dispatches()` 는 그 두 가드를 **이미** 갖고 있었다 — 몰라서가 아니라 **한 술어에만
  적용**돼 있었다. 검출기 수리와 그 부채의 실제 배선을 **한 커밋에** 실었다(따로 실으면 한쪽은
  «새로 보이는데 여전히 안 도는 부채», 다른 쪽은 «거짓으로 평평한 카운트» 가 된다).
  🟥 **참값은 6일 전부터 기록돼 있었다** — 2026-08-09 핸드오프가 컨트롤까지 붙여 «호출자 0» 을 재고
  *"오신뢰를 하나 더한 상태"* 라고 진단해 뒀는데, 그 6일 동안 검출기는 10/10 을 보고했고 이 건이
  닫힌 경로는 그 문서가 아니라 **검출기 자신의 오탐을 쫓던 세션**이다.
- **`selfcheck.sh` 의 판정은 종료코드만으로 하지 않는다.** 새 `directional_diff_gate --self-test`
  블록은 **종결 판정줄을 통째로**(`^✅ calibration passed (N pairs)$`) 요구하고 **N > 0** 을 강제한다.
  cross-family 라운드가 준 구체 입력: 그 subject 는 *실패* 수가 0이면 **레인 수와 무관하게** 통과줄을
  찍으므로, 레인을 전부 지우면 `calibration passed (0 pairs)` + `exit 0` 이 나온다 — **삭제가 조용한
  PASS 로 렌더**된다. 부분문자열 매치였다면 usage 배너도 게이트를 만족시켰다. `rc=124`(timeout kill)는
  «레인 실패» 가 아니라 **HARNESS ERROR** 로 라우팅한다.
- **회귀 앵커 7개 신설** — `test_lane_runner_lanes.sh` 14→17, `test_selfcheck_state_lanes.sh` 44→48.
  L16 이 특히 load-bearing 하다: 같은 세션의 적대검증이 **처음 넣은 자기제외 가드에 앵커가 없음**을
  지목했고(레인 둘 다 픽스처의 자기참조를 `#` 주석으로 써서, 가드를 되돌려도 16/16 초록이었다),
  비-주석 픽스처를 넣고서야 «가드 있으면 17/17 · 없으면 정확히 L16 만 적색» 이 됐다.
- **문서: README 가 정본 이전 프레이밍을 싣고 있었다.** `① Assemble / ② Forge / ③ Sidecar /
  ④ Self-evolving loop` 는 2026-08-09 정식화 **이전** 판으로, 5대 정체성과 절반 겹치면서 **⑤ 증폭자와
  ② 인큐베이터가 통째로 빠져** 있었다. 3층 정본(5정체성 → 4엔진 → 3단 공정 + 4축 검증 + standpoint)
  으로 교체하고 **번역 3종(ko/zh/ja)까지 같은 릴리스에서** 맞췄다. 등급표는 복제하지 않는다 —
  `ship_readiness_gate.md` 가 유일 정본이고, 이 페이지는 4개 언어라 복제하면 사본이 4개가 된다.
- **수치 청소(전부 재측정)**: 로스터가 스킬 37/40 · 에이전트 4/8 만 열거하던 것 → 40/40 · 8/8 ·
  `docs/OUTPUT_EVIDENCE.md` 스킬 33→40 · 규칙 6→1(삭제가 아니라 `knowledge/shared/rules/` 로 이전) ·
  지식 23→57 · 「12일차 · 커밋 224 · PR 66」→ **81일 · 768 · 372**, 그리고 **측정 날짜를 박았다** —
  이 표가 두 달간 현재처럼 읽힌 원인은 숫자가 아니라 «언제 쟀는지 안 적힌 것» 이었다.
  그 문서의 재현 recipe 는 SKILL.md 본문에서 "deprecated"/"redirect stub" 을 grep 해 **살아있는 스킬
  2개**(`phantom-quench` · `hub-cc-pr-reviewer`)를 stub 으로 오분류하고 38 을 뱉고 있었다 — 본문 grep 은
  «내가 stub 이다» 와 «나는 stub 을 검출한다» 를 구분하지 못한다. 교체했다.
- 🟥 **이 릴리스는 #388 의 첫 출하이기도 하다.** `v1.4.98` 태그가 `#387` 에서 잘렸고 `#388`
  (consent-gated auto fast-forward)은 그 뒤에 머지돼 **레지스트리에 한 번도 나간 적이 없다.**
  실측 대조: 출하된 1.4.98 tarball 의 `scripts/fh_node_check.sh` 는 **243줄**로 consent 게이트 arm 이
  통째로 없고, main 은 **282줄**이다. 1.4.98 항목이 «버전을 안 올려 런타임에 도달 못 한 규칙» 을
  기록했는데 **같은 얼굴이 태그 절단 지점에서 재발**했다. 다만 이번엔 계기가 잡았다 —
  `session_close_check.sh` ④-b 가 «마지막 태그 이후 출하자산 변경» 을 발화했고, 이번엔 그 출력을
  표시필터로 자르지 않았다.
- **공개면 정리**: `README.zh.md` 가 마지막 두 줄에 `</content>` `</invoke>` 도구 잔재 태그를
  **공개 상태로** 싣고 있었다(이전 커밋부터). 제거.

🟥 **출하 직전 보안 패스가 이 릴리스를 한 번 막았고, 그래서 이 항목이 더 있다.** `npm publish` 전
게이트로 돌린 코드 보안 리뷰가 **BLOCK** 을 냈다 — `scripts/fh_node_check.sh` 의 consent 게이트가
**클래스를 조인하지 않았다.** 두 조건이 각각 이랬다: ① `consent_registry_check.sh` 를 인자 없이 돌린
rc=0 — 그건 «레지스트리와 grant 들이 well-formed 하고 floor join 이 성립» 이라는 **파일 전체 속성**이라
**무관한 클래스 하나만 유효하게 승인돼 있어도 0** 이 난다 ② UAP **파일 전체**에 대한 raw grep 이라
`granted` 와 `revoked` 를 구분하지 못하고, 히트가 기계 판독 영역인 frontmatter 안인지 산문 문단인지도
보지 않는다. **컨트롤 동반 재현**: 무관한 클래스 1건 유효 승인 + 대상 클래스는 산문에
`  repo-freshness-autopull: 안 쓰기로 했다` 한 줄 → 두 조건 통과 → **자동 fast-forward 실행**, 그리고
배너는 운영자에게 *"standing consent"* 가 있다고 말한다. 망가진 쪽이 하필 **철회 경로**였고, 그건
`absent ≠ granted` floor 가 지키려던 바로 그 자리다.
- **수리**: `consent_registry_check.sh --require-class NAME` 신설 — 그 클래스가 **활성·등록·미만료
  grant 로 전 항목을 통과했을 때만 0**, 아니면 3(=계속 물어라). 파일 전체 위반은 여전히 1 이 이긴다
  («판정 불가 == 불허»는 그 스크립트 자신의 규칙이다). 조인 대상은 `validated`(per-grant 검사 **전에**
  증가하는 카운터)가 아니라 **모든 검사를 통과한 이름 집합**이다. 플래그를 안 주면 동작은 종전과 동일.
- **없던 컨트롤을 채웠다** — `lane10-f WRONG-CLASS`. 기존 거부 arm 셋(c/d/e)은 전부 **파일 전체 판정을
  깨는 방식**으로 거부를 만들어서(grant 블록 삭제 · 리스 과거화 · 발산), **클래스 조인 축을 하나도
  건드리지 않았다.** 새 arm 은 «다른 클래스는 유효 승인 + 이 클래스는 산문에만» 상태에서 거부되는지를
  보고, **동시에 「그 순간 파일 전체 검사가 여전히 0인지」를 같이 단언**한다 — 그 두 번째 단언이 없으면
  lane10-c 와 같은 이유로 통과해 축이 또 안 돌아간다.
  🟥 그 레인도 **처음엔 장식이었다**: 되돌림 프로브를 돌리니 수리를 되돌려도 초록이었다(앞 arm 이 픽스처를
  발산 상태로 남겨 consent 와 무관하게 ff 가 거부됐다). 전제조건을 리셋·단언하도록 고쳤고, 그 리셋이
  **tracked UAP 편집을 되돌린다**는 두 번째 함정도 순서를 뒤집어 닫았다. 최종: 수리 있으면 24/24,
  되돌리면 **정확히 lane10-f 만** 적색.
- **그 수리 자체도 cross-family 가 4건 깎았다** — 전부 **fail-open** 이었다: ⓐ `--require-class '   '`
  (공백만)이 bash 의 `-z` 를 통과한 뒤 python 이 strip 해서 빈 문자열이 되어 **좁히기가 조용히 꺼졌다**
  ⓑ 플래그를 경로 **뒤에** 쓰면 무시되고 옛 파일 전체 판정이 나왔다 ⓒ 미지 옵션이 경로로 삼켜졌다
  ⓓ 클래스 거부인데 요약줄은 `PASS` 를 찍어 **판정과 모순**했다(이 파일 자신이 「요약이 판정과 모순되면
  거짓 초록」이라고 적어 둔 규칙). 넷 다 fail-closed 로 닫고 레인 10개를 붙였다(88 → 98).
- **머지 시간 바운드는 넣었다가 뺐다** — cross-family 실측이 그 워치독이 **git 을 안 묶는다**를 보였다
  (`perl alarm 2` 로 감싼 ff 머지가 느린 smudge 필터 앞에서 **7.9초 걸리고 rc=0**). 안 묶는 장치를
  「바운드」라는 이름으로 남기면 이 릴리스가 고치려는 거짓 초록을 내가 다시 만드는 것이라 제거했다.
  🟥 **파급이 더 있다**: 같은 워치독이 그 위 **fetch** 도 감싸고 있고 그건 이 변경 이전부터다 —
  즉 fetch 가 실제로 묶이는지는 이제 **가정이 아니라 UNVERIFIED** 다. 소스에 잔여로 적었다.
- **머지에 자기 예산을 줬다**(`FH_NODE_GIT_MERGE_DEADLINE`, 기본 5s). fetch 는 워치독이 있는데 머지는
  없어서, fetch 가 예산 8s 를 다 쓰면 10s 훅 예산 안에서 큰 fast-forward 가 워킹트리 갱신 도중 죽을 수
  있었다. **실소요는 안 쟀다 — 바운드지 초과했다는 주장이 아니다.**

**남은 잔여(명시)**: 주석 필터는 줄-접두 전용이라 heredoc/문자열 안의 디스패치는 여전히 계수된다 ·
subject **발견** 쪽은 아직 주석을 읽는다(«언급 ≠ 선언» 이 runner 쪽에만 강제된다) ·
`selfcheck.sh` 의 인접 두 루프는 `rc=124` 를 라우팅하지 않는다(하나는 무음 실패, 다른 하나는
«dispatcher missing?» 이라는 확신에 찬 오진) — Added-Scope Gate 로 분리해 신호로 이월.

### [1.4.98] — 2026-08-15

**fix: 1.4.97 이후 쌓인 출하면 36파일을 실제로 배포한다 — 특히 «있는데 실행에 도달 못 하던» 검증 축 하나**

- 🔴 **이 릴리스의 존재 이유 자체가 결함 하나다.** `auto-decorrelation` 에 **Step 6.5 — Standpoint
  axis**(2026-08-14 신설, `crossfamily` 와 직교하는 두 번째 탈상관 축)를 커밋했는데 **버전을 안
  올렸다.** 플러그인 캐시는 `plugin.json` 버전으로 키잉되므로(`~/.claude/plugins/cache/<mk>/<plugin>/<version>/`),
  버전이 그대로면 캐시가 무효화되지 않는다 — 즉 **레포에는 있고 어떤 런타임에도 없는 규칙**이 하루
  넘게 존재했다. 실측(2026-08-15): 설치본 `auto-decorrelation/SKILL.md` 에 `standpoint` **0회** ·
  `Step 6.5` **0회**, 레포본에는 263~291행에 전문. 나머지 34개 스킬은 드리프트 0 — 정확히 이 한
  파일만 도달 실패했고, 하필 그게 그날 실제로 안 걸린 기능이었다.
  **일반형: 스킬을 고치고 버전을 안 올리면 저자 머신을 포함한 모든 런타임에서 그 수정은 존재하지
  않는다.** `built_but_not_wired` 의 배포채널 판본이고, 게이트가 «행위자가 읽는 곳»에 있어야 한다는
  gate-locality 원칙이 *배포 지연*이라는 다른 메커니즘으로 재발한 것이다.
  **기존 검사기는 정상 작동했다** — `session_close_check.sh` ④-b 가 「마지막 태그 이후 출하자산
  변경 → 재출하 제안」을 정확히 발화하고 있었다. 놓친 지점은 검사기가 아니라 **그 출력을 표시필터로
  잘라 읽은 것**(`| tail -15`)이었다. 새 기계장치를 짓지 않고 기존 절차를 실행하는 것이 이 릴리스다.

- **Standpoint 축 신설** (PR #370 · #371 · #378) — 계열(family) 다양성은 *리뷰어의 오류분포*를
  탈상관시키지만 *리뷰가 대조되는 ground truth* 는 탈상관시키지 않는다. 공유 본체(shared-body)
  변경에서 «누구의 레포를 기준으로 검증했는가」를 폐쇄 enum 으로 기록한다
  (`tier1` · `tier2(<대상>)` · `tier2b(<대상>)` · `tier3(<대상>)` · `not-applicable` +
  could-not/did-not/did-not-look 3분 degrade). 실행 시점은 **첫 push 이전, 위험판정 분기 없이**.
  정본 = `knowledge/shared/harness-core/field_verdict_crossfamily_gate.md §7`.
  ⚠️ 정직한 현 상태: 이 필드는 **산문 전용**이다 — pre-commit 훅에 `standpoint` 매치 0건,
  픽스처 스위트 없음(`crossfamily` 는 21건 + 픽스처로 하드 차단). 첫 거짓값이 기록되면 기계화한다.

- **컴패니언 스토어 노드↔노드 스코핑** (PR #368 · #372) — 같은 머신에서 두 하네스가 컴패니언
  스토어를 공유할 때 서로의 manifest/memory-index 를 되읽던 결함. `fh_hub_identity.sh` 신설로
  세 호출부의 네임스페이스 판단을 단일 소스로 통일.
- **레인 배선** (PR #369 · #374) — `test_field_canon` · `test_stale_clone_guard` 재배선(DEBT 2→0),
  자기-재진술 렌즈 + 임베디드 `--self-test` 디스패처 탐지 신설.
- **SessionStart 노드 플로어에 origin-behind 탐지** (PR #376) · **frontier-digest 무인
  파이프라인** (PR #377) · **positioning roadmap 문서** (PR #379).
- **Homebrew tap 출하** (PR #380 · #383) — `brew install forge-harness`(npm 패키지와 100% parity).
  Homebrew Core 제출은 채택 기준(star 75 / fork 30 / watcher 30, 자기제출 ×3) 미달로 **보류**,
  재개조건 ~50+ star 로 명시 기록.
- **ko-tech-writer 수리** (PR #373) — render-artifact 스코프 · 전칭단정 스캔 · 한글 `\b` 정규식 트랩.

---

### [1.4.97] — 2026-08-13

**fix: 죽어 있던 게이트 캘리브레이션 배선 · 참조를 「선언」이 아니라 「실제 tarball」과 대조**

- **아무 데서도 실행되지 않던 레인 스위트를 배선했다** (PR #360). 실측: `scripts/` 의 43개 스위트
  중 12개가 selfcheck·git 훅·CI 어디서도 안 돌았고, **그중 9개는 이 패키지에 실린다** — 소비자가
  받아 놓고 아무것도 부르지 않던 테스트 9종이다. 가장 아픈 둘은 **커밋을 하드 차단하는 게이트의
  캘리브레이션**이었다(`test_marker_crossfamily_lanes.sh` · `test_marker_floor_lanes.sh`).
  진척 지표 **DEBT 12 → 2**. 남은 2건은 「돌면 진다, 사유는 머신 전제」로 사유가 측정돼 있다.
- **vendored git 트리에서의 거짓 FAIL 을 닫았다** — 세 스위트가 `git rev-parse --show-toplevel`
  로 루트를 잡아, 설치 후 `git init` 한 트리나 node_modules 를 커밋하는 모노레포에서 **바깥 레포**
  를 보고 HARNESS-ERROR 를 냈다. 스크립트 상대경로로 수리.
- **`package_coverage_check.sh --vs-tarball`** (PR #361) — 참조 대조의 오라클을 `package.json`
  `files[]`(**선언**)에서 `npm pack --dry-run --json`(**실제 출하 파일셋**)으로 바꾸는 모드.
  npm 부재·비영 종료·파싱 실패 시 **fail-closed**(rc=2 UNMEASURED, 약한 오라클로 폴백하지 않는다).
  `prepublishOnly` 에 배선됐다.
- **참조 추출기가 `.json` 을 못 보고 있었다** — 정규식 교대가 leftmost-first 라 `.js` 가 `.json`
  안에서 먼저 물렸고, 모든 JSON 참조가 존재하지 않는 경로로 잘려 조용히 버려졌다. 수리 후 즉시
  드러난 것 하나가 **소비자-대면 결함**이다: `templates/goal-quench-hook-setup.md` 가
  `cp templates/goal-quench-settings-merged.json .claude/settings.json` 을 지시하는데 **그 JSON 이
  패키지에 없었다.** 이제 실린다.
- **`selfcheck.sh` 의 timeout 가드가 한 번도 설치된 적이 없었다** — `local` 이 함수 밖에 있어
  bash 가 대입을 거부했고, 매 실행 stderr 로 자기 실패를 알렸으나 아무도 읽지 않았다. 수리.

### [1.4.96] — 2026-08-12

**fix: 전수 재출하 캠페인 — 「돌았다고 보고하는데 안 도는」 계기들 · 선언이 무효였던 에이전트**

스킬 40종 + 에이전트 8종 전수 적대검토 후 수리(PR #348 · #349). 지배 결함은 하나의 얼굴이었다 —
**계기가 대상에 안 닿는데 출력은 무결**.

- **`quench-challenger` 의 frontmatter 가 깨져 선언이 무효였다.** 비인용 멀티라인 `description`
  안의 `user:`/`assistant:` 줄이 새 YAML 키로 파싱돼 그 아래 `tools: Read, Grep, Glob` 과
  `model: opus`(HARD FLOOR) 를 **둘 다 무효화**했다. 읽기전용으로 선언된 적대 에이전트가 전체
  도구로 돌고 있었다. `description` 을 한 줄 인용으로, 예시는 본문으로.
- **`scripts/validate_yaml.sh`** — 스캔 대상에 **에이전트 8종 편입**(종전 SKILL.md 만). 양 surface
  중 하나라도 0건이면 `INSTRUMENT ERROR`(exit 3) — 스캔 0을 통과로 렌더하지 않는다. **신규 출하**.
- **`scripts/degrade_direction_scan.sh`** — **마크다운 ```bash 펜스 추출**. FH 가 실제로 실행하는
  bash 는 대부분 SKILL.md 펜스 안에 사는데 스캐너가 `.py`/`.sh` 만 봤다. 그림자 파일이 **원본
  줄번호를 보존**해 findings 가 `SKILL.md (```bash fence):202` 로 나온다. 펜스 없는 md 는 종전대로
  `UNSCANNABLE`(미측정을 커버리지로 바꾸지 않는다).
- **인용 무결성 2건 정정**(원문 직독) — arXiv 2605.00914 의 32.3pp 는 **다수결 oracle gap** 이지
  「자기평가 시 성능저하」가 아니고(논문 결론은 *isolated self-correction prevails*), arXiv
  2603.15255(SAGE)는 **co-evolve** 라 「Critic 격리」 근거가 될 수 없다. `harvest-loop` 의 같은
  오귀속도 동시 수리.
- **`salience-splitter`** — 4축 게이트가 이름으로 지목한 의무(«split 마다 목적지가 게이트 안인지
  재질문») 를 본문에 배선 · 컷 판정 「머릿속으로」를 **레이어별 측정 2분기**로(상주=ablation
  하네스 / SKILL.md=콜드스타트 sim) · 포인터↔헤더 대조를 실행 가능한 형태로(오탐 100% 였다) ·
  orphan 스캔을 `^## §` → `^## ` 로(실물 헤더 139 중 97만 보던 30% 사각).
- **죽은 명령·경로 정리** — `claude mcp search`(부재) · `codex list-agents`(부재) ·
  `marketplace add` 인자 · `GoogleWebSearch`(존재하지 않는 도구명) · `frontier-digest` 저장 경로가
  카덴스 글롭과 어긋나 **7일 카덴스에 영원히 안 잡히던** 것.
- **거짓 PASS 계기들** — `harness-doctor` E7/E3/Step-11(`grep -c || echo 0` 일가가 음성 arm 을
  통과로 렌더) · `install-doctor` 의 `except: pass`(깨진 MCP 설정이 「위험 없음」과 구별 불가) ·
  `asset-placement-gate`(죽은 스캔과 진짜 무충돌이 둘 다 count=0) · `auto-decorrelation`(zsh 에서
  다중 사이드카가 **무음 탈락** → single-family degrade).
- **`AGENTS.md`** — 도구 표 누락 3종(beginner·main-player·expert) 보강 + frontmatter YAML 유효성
  규율(비-CC 파서에서는 깨진 줄 아래 키가 전부 드롭된다). 문서↔파일 전수 대조 불일치 0.


### [1.4.86] — 2026-08-03

**fix: 격리를 자칭하던 어블레이션 절차 + ambig 게이트 앵커 + 밀린 출하 자산 반영**

- `scripts/probe_scope_check.sh` — 어블레이션 절차 정본을 교체했다. 서브에이전트에는 프로젝트
  CLAUDE.md 가 **시스템 프롬프트로 주입**되므로 "다른 파일 읽기 금지"는 블라인드 arm 을 만들지
  못한다(파일 0개·툴 0회 컨트롤이 잘린 절을 verbatim 재현하며 출처를 자백). 헤더는 이제
  **"이 절차는 아직 검증되지 않았다"**로 시작한다 — 적대 검증이 두 번째 누출 채널(`claude -p`
  가 Bash/Read/Glob 을 쥐고 있어 arm 이 진짜 CLAUDE.md 를 찾아 인용)을 실측했고, 툴 차단 처방은
  known-pair 가 없다(`--tools ''` 는 양성 컨트롤 실패 = 전 구간 거짓 KEEP). 기존 판정은
  UNCALIBRATED, 오늘 판정 2건은 PROVISIONAL, CUT 후보는 **DO NOT CUT**.
- 같은 파일 — control B 의 `ambig` 항을 **control C**(픽스처 코퍼스 자기 재호출)로 앵커. 실 코퍼스는
  건드리지 않는다. 게이트 항을 되돌리면 arm 이 빨개지는 것까지 검증.
- 같은 파일 — 적대 검증이 잡은 자기결함 5건 봉합: env 킬스위치(`PROBE_SCOPE_FIXTURE` export 시
  픽스처를 실 코퍼스 대신 검사하고 control C 를 무음으로 끄고도 초록 + exit 0) → argv 플래그로
  교체 · 타입 없는 exit 3 을 증거로 받던 control C → 자식의 `ambiguous-basename` 카운트 동반 요구 ·
  따옴표 불안전한 RETURN trap · mktemp 실패가 exit 3 으로 대상 코드를 무고하던 것 → exit 1 ·
  새 옵션 파서가 `--self-test` 를 거부해 `selfcheck.sh` 를 깨뜨리던 자초 회귀.
- `knowledge/shared/learnings/subagent_invocations_log.yaml` — 호출 로그 2건. 그중 하나가
  전날 엔트리를 `rejected` 로 뒤집는다(그 엔트리의 mode 줄 "all file access denied except the one
  arm file" 이 성립하지 않는다).
- 밀려 있던 출하 자산 반영(#239, 어제): `scripts/selfcheck.sh` · `scripts/package_coverage_check.sh` ·
  `templates/.git-hooks/pre-push` — 태그가 자기 버전을 가리키는지 검사하는 가드.


### [1.4.1] — 2026-06-08

**docs: repo-root declutter + pre-commit gate hardening**

- Moved `ETHOS.md`, `WHY.md`, `OUTPUT_EVIDENCE.md`, `CONTRIBUTING.md` into `docs/` (root
  declutter; `LICENSE`/`CITATION.cff`/`AGENTS.md` kept at root for GitHub/Codex/npm reasons).
  npm `files[]` updated so the package still ships `docs/CONTRIBUTING.md`; README links repointed.
- Hardened the 4-axis pre-commit hook (`templates/.git-hooks/pre-commit`): `diff_is_substantive`
  is now rename-aware with a source-scope discriminator — a pure rename *within* the gated
  namespace no longer false-positives, while content `git mv`'d *into* the namespace from outside
  is scanned in full (closes a rename-into-scope review-skip found by an isolated steel-quench
  challenger). Fails closed on git error; matches indented fences. Not shipped to npm (templates/).
- `docs/OUTPUT_EVIDENCE.md` agent count 5 → 8 (PR #77 agents), surfaced by phantom-quench.

### [1.4.0] — 2026-06-07

**feat: user-mastery spectrum persona agents — sim-conductor shells elevated to frontier-grade agents**

Replaced sim-conductor's thin built-in persona palette (one-line role directives) with a coherent
user-mastery spectrum of shipped, reusable, isolated-dispatchable agents — re-derived to challenger
grade (embedded methodology + Done-When), not name-copied from the field deep-insight `user` group.

- New agents (`plugins/fh-meta/agents/` + `.codex/agents/` mirrors):
  - `beginner` (←Newcomer) — first-contact cold-read; friction taxonomy; reasoning-type
  - `main-player` (←Power-user) — engaged user, intelligently scopes Light/Midcore/Heavy (Heavy = classic power-user); reasoning-type
  - `expert` (←Domain-expert) — web-grounded domain accuracy + SOTA currency, citation-enforced; data-type (WebSearch/WebFetch)
- `challenger` U1 expanded to absorb the standalone skeptic "why not just X?" lens (web-grounded external-alternative search). Skeptic removed as a separate persona.
- sim-conductor palette → shipped-agent index (sourced installed-first); provenance note clarified ("renamed" = pattern→parallax, not personas; lineage acknowledged, nothing carried as a shell).
- Cross-skill references realigned: deliberation, steel-quench multi-team, apex-review, agent-composer, return_path_gate.
- `challenger` relocated `.claude/agents/` → `plugins/fh-meta/agents/` so the full spectrum (beginner · main-player · expert · challenger) ships and registers from the plugin (plugin-only installs no longer reference an unbundled adversary). Registry synced: AGENTS.md + `.claude/registry/agent_cards.json` now list all 8 agents; `package.json` files entry de-duplicated (covered by `plugins/fh-meta/agents`).
- Rationale: bias-isolation operationalization — context-separated diverse personas make the "outside-the-author reads cold" assumption executable (see `tracks/_meta/fh_signal_2026-06-07`).

Also in 1.4.0 (shipped together):
- **install-wizard** — fixed defects surfaced by the spectrum runtime review (verified against source): broken weekly-audit cadence (CronCreate session-death vs weekly promise + allowed-tools gap → session-start/zshrc detection); 4-axis gate auto-install → OPT-IN double-confirm + scope; deep-insight reframed Optional (spectrum ships, so no longer required); reproducible score formula; CC_HUB_DIR documented; metrics relabeled illustrative; prompt-injection scan widened; streamlit pattern-pack generalized.
- **Model guidance** — README + onboarding default switched `/model opusplan` → `/model opus` (opusplan engaged Opus 0/10 in a measured run; explicit opus 22/22); quality-gate hero line added; banner updated (Path A). CLAUDE.md autonomous-initiative layer gained `goal-quench` + `deep-clarify` rows, and the session-close chain gained an npm-republish freshness step.

---

### [1.1.4] — 2026-05-26

**feat: Verifiable + Evolution maturity upgrade — scoring formula defined + execution flow updated**

Pre-quench triple layer (meta-devil · devil-advocate · newcomer) + synthesizer output applied.
Achieved verifiable 75%→85%, evolution 60%→80% by changing execution flow instead of adding assets.

- `knowledge/shared/harness-core/skill_quality_rubric.md` added: verifiable · evolution axis scoring formula (numeric claims without formula = cold audit self-declaration violation)
- harvest-loop Step 3.75 expanded: pattern spec for connecting Critic isolation judgment after core 5 skills execution
- harvest-loop Step 6-b expanded: pmh_signal grep → skill_usage.md Leaderboard automatic aggregation integration (replaces manual estimation)
- Core 5 skills Done When strengthened: external verification path (Critic link) added for harness-doctor · verify-bidirectional · hub-cc-pr-reviewer · context-doctor · sim-conductor
- Deprecated: Verification Criteria new section (merged into Done When), EVOLUTION.md on hold, usage_notes field on hold

---

### [1.1.3] — 2026-05-26

**feat: Harness Evolution Cadence — harvest-loop Step 6-b added**

DemoEvolve strategy (arxiv 2605.24539) implementation: agent capability adjustment by updating escalate_when parameters only, without model retraining.

- harvest-loop Step 6-b added: 4-week cycle complexity_routing condition validity check
- Auto-proposal when 2+ pmh_signals accumulated, outputs removal/addition candidates before user approval gate
- Rationale: frontier-digest 2026-05-26 pmh_signal (DemoEvolve strategy application candidate)

---

### [1.1.2] — 2026-05-26

**feat: Destructive Action Gate — agent-composer Step 2.7 added**

Safety gate before autonomous dispatch to prevent AI agent control violations (DB deletion · OpenClaw type).

- agent-composer Step 2.7 added: scan for 3 types — external output · file destruction · production impact
- 🚨 On detection: "this cannot be undone" warning + separate yes/no approval required before Y/E/N prompt
- Step 2.5: `destructive` escalate_when condition added + 1-line audit log mandatory
- CONTRIBUTING.md: `destructive` condition documented in complexity_routing schema
- Rationale: frontier-digest 2026-05-26 caution signal (AI agent DB deletion · OpenClaw case)

---

### [1.1.1] — 2026-05-26

**feat: P5 Model Routing — complexity_routing schema + applied to 6 skills**

New routing system that dynamically escalates the skill execution model based on task complexity.

- CONTRIBUTING.md: `complexity_routing` field schema documented (base/high/escalate_when)
- agent-composer Step 2.5 added: 5-condition escalation judgment table + routing rules
- `complexity_routing` added to 6 skills:
  - `harness-doctor`: cold_start, cross_project
  - `context-doctor`: cold_start, cross_project
  - `verify-bidirectional`: full_revalidation, high_stakes
  - `hub-cc-pr-reviewer`: adversarial, cross_project, high_stakes
  - `cross-ecosystem-synergy-detection`: cross_project, cold_start
  - `deep-clarify`: cross_project, high_stakes

---

### [1.0.1] — 2026-05-20

**feat: context-bridge-dispatch skill added (18th skill)**

Resolves session context disconnection problem during parallel agent dispatch.
Structural correction for the P8 variant blind spot where sub-agents can read files but do not know the main session's living context.

- `context-bridge-dispatch` v0.1 added
- Context Card format defined (4 fields: purpose / completed / agent task / caution)
- Auto-trigger before 2+ parallel dispatches

---

### [1.0.0] — 2026-05-19

**🎉 v1.0 official release — all C1~C5 conditions met**

All 5 v1.0 release criteria satisfied:
- C1 ✅ Natural language trigger activation confirmed for all 17 skills (cascade α complete)
- C2 ✅ Validated by an external user — autonomous skill execution confirmed (cascade β, 2026-05-12)
- C3 ✅ meta-devil M1 · M2 S-tier issues fully resolved
- C4 ✅ install-wizard G6 bootstrap paradox resolved (2026-05-18)
- C5 ✅ Three-Doctor Loop closed-loop operation confirmed

Natural language trigger reinforced for 8 skills (C1 complete):
- deliberation, agent-composer, marketplace-gate, field-harvest
- asset-placement-gate, cross-ecosystem-synergy-detection, meta-prompt-builder, apex-review

---

### [0.3.0] — 2026-05-19

**bump: M1/M2 S-tier resolved + fallback guide confirmed + sim-conductor human gate formalized (last minor before v1.0)**

Handling remaining incomplete items among v1.0 criteria C1~C5:

M1 resolved (trigger coverage audit 2026-05-17 M-tier):
- install-wizard Step 5 completion report: "next-step skills" block added
  - hub-persona-auditor introduction added ("quality audit after completing assets for external publication")
  - agent-composer connection hint added
  - plugin-recommender connection hint added

M2 resolved (trigger coverage audit 2026-05-17 M-tier):
- agent-composer Wave 0 composition criteria: 3-line fact-checker role description added
  - "No need for the user to call directly — agent-composer auto-dispatches in Wave 0" specified
  - Direct call path (mode D) specified

sim-conductor human gate formalized:
- "Human Gate principle" section added
  - 4-case table for escalation from tentative convergence to final convergence formalized
  - Structural bias-blocking rationale specified

fallback-guide (confirmed at v0.3.0):
- references/fallback-guide.md existing content maintained (AI dependency single point of failure W4-1 response)

---

### [0.2.8] — 2026-05-18

**feat: steel-quench skill added (comprehensive quench validation)**

steel-quench v0.1.0 added:
- Meta-skill that concretizes designer anxiety into AI-driven devil attacks and resolves it through defense strategy
- Wave structure: Wave 1 (Devil attack) → Wave 2 (Defense) → Wave 3+ (convergence, ends with 0 S-tier blockers)
- 5-angle mandatory attack checklist: reason for existence · real-world usage validation · bus factor · platform obsolescence · self-referential structure
- Severity S/A/B classification + rebuttal feasibility judgment (○/△/×) standardized
- 3 defense principles: WebSearch for external cases · cover with experience · implement first
- 5 cross-project common patterns as initial seed: P1 single bus factor · P2 doc-code mismatch · P3 self-referential diagnostic structure · P4 real-world validation absence · P5 platform obsolescence no plan
- Downstream links after convergence: meta-prompt-builder · sim-conductor · verify-bidirectional · harness-doctor
- plugin.json skills array registered (alphabetical order: after sim-conductor)

---

### [0.2.7] — 2026-05-18

**Wave 4 Final Judgment Gate + Composability Gate categorization + 2 skills officially deprecated**

agent-composer Wave 4 Final Judgment Gate added:
- M-tier 0 → PASS / M-tier≥1 → BLOCK judgment logic (based on loom fan-in contract)
- Phase Guard pattern: enforces logical dependency order between Waves
- CONTRIBUTING.md: 3 mandatory pre-rc-bump checklists (fact-checker · marketplace-gate · CHANGELOG) added

Composability Gate categorization:
- `category: Composability Gate` frontmatter added to install-wizard · install-doctor · marketplace-gate
- Common layer for 3 skills specified — external install compatibility gating role formalized

Officially deprecated (moved to `deprecated/` folder):
- `frontier-status-summary`: replaced by cc meta-monitoring hook (PostToolUse)
- `pr-review-watcher`: fully merged into hub-cc-pr-reviewer, separate skill unnecessary

cc FH meta-monitoring hook integration:
- cc `settings.json` PostToolUse hook added — auto check guidance for hub-cc-pr-reviewer on FH change detection
- FH external change monitoring circuit first activated

---

### [0.2.6] — 2026-05-18

**meta-prompt-builder v0.2 integration confirmed + README natural trigger reinforced**

meta-prompt-builder v0.2 integration gate released:
- Scenario 1 · 2 · 3 measured PASS: 91.1% overall achieved (S1 100% · S2 90% · S3 83.3%)
- [0.1.1] status "integration gating: scenario 1 measurement pending" → v0.2 officially integrated

README natural trigger reinforced (root-memory removed + 4 abbreviations expanded + failure examples added):
- Fallback phrase changed: "read root memory" → "what have we done so far?" / "where did we get to?"
- Failure symptom & action block added (3 cases: generic response · CLAUDE.md error · auth error)
- 4 abbreviations expanded: cascade → cascade (sequential validation chain), agents → agents (parallel execution mode), meta-sim → meta-sim (multi-agent simulation), fan-in → fan-in (stage where results from multiple agents are combined)

---

### [0.2.5] — 2026-05-18

**apex-review v0.1 added — decision-maker review layer**

15 skills → 16 skills.

New skill added that reviews technical proposals from the perspective of decision-maker personas (CTO · engineering director · QA team lead · conference organizer) and generates HTML presentation materials. Unlike hub-persona-auditor (reader comprehension), it simulates decision approval likelihood.
Flow: proposal structuring → HTML PPT generation → persona review → approval gate → sim-conductor link.
Added to agent-composer mapping table (decision-maker approval review work type).

---

### [0.2.4] — 2026-05-17

**audit-learnings deprecated from FH → transferred to source development hub only**

Judgment: a tool for the source development layer that *evolves* FH, not for users who merely *use* FH.
External FH users are unlikely to develop their own meta-harness the same way → FH exposure unnecessary.

audit-learnings continues in the hub (project scope maintained).
plugin.json: 16 skills → 15 skills

---

### [0.2.3] — 2026-05-17

**audit-learnings v0.6 → v0.7 — _scanner.sh external dependency resolved**

audit-learnings conditional retention condition met:
- Step 1 self-detection structure replaced: full scanner when `_scanner.sh` exists / auto git fallback when absent
- git fallback 5 sections (COMMITS / TOP MODIFIED / NEW FILES / TAG COUNTS / STALE) inlined
- Constraints section updated: "git fallback auto-used when absent" specified
- Phase 3 entry condition updated: git fallback v0.7 inlined = phase 1 achieved
- deliberation 3-party judgment "conditional retain" → officially retained after condition met

---

### [0.2.2] — 2026-05-17

**frontier-status-summary deprecated + install-wizard suitability pre-flight absorbed**

frontier-status-summary (v0.4) deprecated:
- Judgment: deliberation 3-party review result — ~80% dependent on personal assets, only positioning judgment value extracted
- "Is this tool right for me?" 3-item checklist → absorbed into install-wizard Step 0-A
- Moved to deprecated/ archive

install-wizard v0.3 → v0.3.1:
- Step 0-A added: FH suitability pre-flight check (CC usage · project scale · collaboration willingness)
- frontier-status-summary migration noted (2026-05-17)

plugin.json: 17 skills → 16 skills

---

### [0.2.1] — 2026-05-17

**pr-review-watcher deprecated + cross-ecosystem-synergy-detection structural separation**

pr-review-watcher (v0.1) deprecated:
- Judgment: deliberation 3-party review result — directly replaceable by `gh pr view --json reviews`, no real-world usage evidence
- Moved to deprecated/ archive
- hub-cc-pr-reviewer reference → replaced with deprecation notice

cross-ecosystem-synergy-detection v0.4 → v0.5 structural separation:
- SKILL.md: 279 lines → 103 lines (core algorithm only)
- examples/env_reference.md added: internal GHE org inventory, 3-cluster classification, 8-asset self-X matrix, phase history

plugin.json: 18 skills → 17 skills

---

### [0.2.0] — 2026-05-17

**deliberation added — forge skill + Wave next-D integration**

deliberation v0.1 added (18th skill):
- Innovator (proposal) → Devil (rebuttal) → Mediator (synthesis) 3-layer base structure
- Optional 5-layer: 2-3 deep-insight jurors in parallel + Mediator final synthesis
- Synthesis formula: "Innovator core + Devil warning fragments → conditional judgment" (simple winner selection prohibited)
- 5 WARN auto-detection types: unresolvable rebuttal · simple judgment · conflict-free battle · juror overload · ambiguous Done When
- Design principle: a rope for those who haven't challenged yet to climb / the forge creates new alloys

agent-composer patch:
- Step 4-b state transition gate ⑤ added: design decision conflict → Wave next-D

Naming candidate (delegated to user decision):
- **Forge Skill** — value-based naming candidate for deliberation

---

### [0.1.1] — 2026-05-17

**State transition gate + meta-prompt-builder added — innovator chaining architecture realized**

agent-composer:
- Step 4-b added: automatic evaluation of conditions ①②③④ after fan-in completion → Wave next-M/I/E or end
- Innovator chaining gating condition met

meta-prompt-builder v0.1 added (17th skill):
- For agent-composer power users — designing "what to say" after "which agent to use"
- Goal/Context/Constraints/Done When structure reinterpreted as FH harness state
- Meta-sim completed (QA + devil-advocate 2-agent): trigger redefinition · Step 3 Read mandatory · Done When 3-point check · 4 WARN patterns
- Integration gating: scenario 1 real measurement (≤70% turns) pending

Naming adopted (2026-05-17):
- **Proactive Chain** — closed loop where sim completion triggers next proposal
- **State Transition Gate** — fan-in result becomes next agent selection condition
- **Prompt Delegation Skill** — value-based naming for meta-prompt-builder

### [0.1.0] — 2026-05-16

**Version scheme normalization** — v1.0.0-rc10 → v0.1.0 (external ecosystem alignment)

- Claiming v1.0.0 without external install evidence is excessive — consistent versioning humility with peers in the same ecosystem
- rc1~rc10 iterations consolidated into single v0.1.0 tag (rc history preserved in CHANGELOG)
- Version policy formalized: v0.x = internal validation / v1.0 = external validation complete

_Internal iteration history: rc1 (2026-04-29) ~ rc10 (2026-05-15), 10 cycles total_

### [rc10] — 2026-05-15

**16 skills system — marketplace-gate v0.1 added (marketplace listing suitability gate)**

marketplace-gate:
- v0.1 added: 5-point check automation before repo listing
  - Check 1 README completeness / Check 2 zero-config / Check 3 maintenance signal / Check 4 duplicate detection / Check 5 public safety
  - Overall judgment: 🟢 Recommended / 🟡 Conditional / 🔴 Hold
  - Links: hub-persona-auditor · cross-ecosystem-synergy-detection · harness-doctor · install-doctor

plugin.json:
- version: 1.0.0-rc9 → 1.0.0-rc10
- description: "15 skills" → "16 skills"
- keywords: "marketplace-gate" added

### [1.0-rc9] — 2026-05-15

**--dry-run analysis mode introduced — bg dispatch compatibility secured**

install-wizard:
- v0.2 → v0.3: `--dry-run` analysis mode added
  - Outputs Step 2 report then skips Step 3~4 (approval · execution) → bg dispatch compatible
  - `## Execution Modes` section added (normal / analysis mode comparison table)

audit-learnings:
- v0.5 → v0.6: `--dry-run` analysis mode added
  - Performs only Step 1~4 scan and draft generation, skips all Step 5~9 gates → bg dispatch compatible
  - `## Execution Modes` section added / user approval gate table expanded (normal/dry-run branches)

agent-composer:
- Composition table ⚠️ comment updated: `--dry-run` bg parallel possible specified

### [1.0-rc8] — 2026-05-15

**15 skills system official — agent-composer added (agent composition layer)**

agent-composer (new — coordinator skill):
- v0.2: agent composition layer coordinator skill — FH "agent composition layer" identity realized
- Step 0~4: context collection → agent mapping → composition plan output → approval → execution → fan-in result integration
- Wave 0: fact-checker preemptive gate (prior verification for all tasks including new assets)
- (S)/(A) notation: distinguishes Skill tool / Agent bg dispatch call method
- ⚠️ Conversational isolation: install-wizard · audit-learnings bg parallel dispatch not available (placed last in Wave, standalone)
- M/S/R tier definitions added (fan-in integration report criteria)

install-wizard:
- v0.1 → v0.2: version field updated

README:
- Agent dispatch guide added (agent-composer usage + 3-agent mapping table + parallel patterns)
- Plugin catalog: 14 skills → 15 skills (agent-composer joined), rc4 → rc8
- 18-asset active check updated (agent-composer added)

### [1.0-rc7] — 2026-05-15

**Meta-sim gate passed — M-tier all resolved (M1~M9 + M-A)**

asset-placement-gate:
- M1: ① cross-project value elevated to mandatory gate together with ④ (①+④ mandatory + 1 of ②③)
- M2: Step 0 natural language input requires 3-field forced confirmation (purpose · trigger · caller) — blocks hallucination judgment
- M4: description "forge-harness (FH)" full name stated once

install-wizard:
- M3+M8: /install-doctor pre-call block added before Step 1 + doctor result mapping scope specified (M-A)
- M5: ## Key Terms table added (sentinel · CronCreate · zshrc hook definitions)
- M6: {FH_REPO_URL} → 2 URL variants (internal / external) specified
- New: Step 5 personal fork guidance (asset loss prevention motivation + reverse-harvest welcome)

README + install-wizard:
- Command tower orchestration pattern specified (work type cwd assignment table + 6-agent real-world proof)

### [1.0-rc6.1] — 2026-05-15

- asset-placement-gate M7: frontmatter `tools: Read, Grep, Glob` → `allowed-tools: ["Read", "Grep", "Glob"]` + `user-invocable`, `model`, `version` fields added (rc6 self-contradiction resolved — only skill among all skills missing this standardization)

### [1.0-rc6] — 2026-05-15

- asset-placement-gate M5: trigger section specifies 4-step operation order (path request → Read load → 4-criteria evaluation → FH suitable / skill-free output)
- install-wizard M9: frontmatter `tools:` → `allowed-tools:` standardized (aligned with other FH skills)
- install-wizard M6/M7/M8: settings.json dict/list branch, Streamlit AND condition, zshrc idempotency guard — confirmed already reflected before rc5

### [1.0-rc5] — 2026-05-14

- 14 skills system (asset-placement-gate joined)
- asset-placement-gate v0.1 — 3-way routing gate for new asset FH suitability (FH meta skill / project local agent / drop)

### [1.0-rc4] — 2026-05-14

- 13 skills system (install-wizard joined)
- install-wizard v0.1 — onboarding wizard (environment detection → gap diagnosis → per-item approval → execution → acceleration baseline setting)
- CONTRIBUTING.md added — external contributor PR guide
- templates/fh_audit_check.zsh — recurring audit zshrc hook general template

### [1.0-rc3] — 2026-05-13

- 12 skills + 3 agents system confirmed (install-doctor joined + .claude/agents/ dual registration)
- `.claude/agents/` added — fact-checker · hub-persona-auditor · persona-innovator callable directly from hub cwd without plugin (mode D)
- New technology introduction pipeline (§11) documented — proposal → sim → optimization 3-step standard path
- CHEATSHEET: /goal condition evaluation LLM mechanism measured and documented + Lever 5 updated

### [1.0-rc2] — 2026-05-11

- 11 skills system (field-harvest · pr-review-watcher joined)
- sim-conductor Area D expanded (D-consumer: session · skill · memory consumer sim 3 types)
- sim-conductor Area E added (output quality review)
- persona-innovator v0.2 Mode T added (technology bridge exploration)

### [1.0-rc1] — 2026-05-08

- Plugin level promotion v0.5.0 → v1.0-rc1 (Release Candidate 1)
- 8 release requirements: 7 met + 1 pending (external user install measurement data accumulation)

### [0.5.0] — 2026-05-08

- 6 skills operating baseline established (audit-learnings + verify-bidirectional + frontier-status-summary + plugin-recommender + cross-ecosystem-synergy-detection + hub-cc-pr-reviewer)
- hub-cc-pr-reviewer v0.1 joined (PR review automation)

---

## Skills

### audit-learnings

| version | date | changes |
|:-:|:-:|---|
| 0.5 | 2026-05-13 | Step 1.7 CC feature signal scan added — auto-collect CC releases via WebSearch → FH gap analysis → upgrade candidate proposal (`--cc-scan`) / Step 0 /goal recommended stage added |
| 0.4 | 2026-05-08 | External user perspective refinement / cwd auto-detection + scope auto-mapping fallback / self-audit path |
| 0.3 | 2026-05-08 | Path B generalization (external user environment adaptation) |
| 0.2 | 2026-05-08 | Official release / Phase 2+ PR automation (2026-05-06) |
| 0.1 | 2026-04-27 | Phase 2 activation / weekly audit automation baseline |

### verify-bidirectional

| version | date | changes |
|:-:|:-:|---|
| 0.8 | 2026-05-10 | Proactive concern expression channel added — active type (AI preemptively flags premise errors) / expression format + 3 constraints formalized |
| 0.7 | 2026-05-08 | External user perspective refinement / 8-asset self-X circuit cross-ref / autonomous activation path baseline |
| 0.6 | 2026-05-08 | Path B generalization |
| 0.5 | 2026-05-08 | Mode A · B · C + autonomous activation path baseline |
| 0.4 | 2026-05-06 | Step 4.5 diff gate added |
| 0.3 | 2026-05-04 | Conscious full application channel |
| 0.2 | 2026-05-04 | Internal model cross-check (environment-specific) |
| 0.1 | 2026-05-03 | Skill promoted / 8-iteration baseline |

### frontier-status-summary

| version | date | changes |
|:-:|:-:|---|
| 0.4 | 2026-05-08 | Step 1~5 path B generalization fallback / external user utilization reached |
| 0.3 | 2026-05-08 | Path B generalization (external user environment adaptation) |
| 0.2 | 2026-05-08 | Meta-harness differentiation value + internal GHE cluster cross-link |
| 0.1 | 2026-05-03 | Added (Phase γ option γ) |

### plugin-recommender

| version | date | changes |
|:-:|:-:|---|
| 0.7 | 2026-05-13 | Step 5-B external asset transplant path added — SKILL.md conversion guide + 3 transplant suitability criteria + location branch (FH official · local · mode D) when non-plugin asset found |
| 0.6 | 2026-05-11 | Step 5-0 same-name conflict detection + Step 2 [Priority 2.5] Tier 2.5 project contribution path |
| 0.5 | 2026-05-10 | Step 5-0 pre-check added — duplicate detection before install (manual install + repo-level enabledPlugins bidirectional) |
| 0.4 | 2026-05-08 | External user perspective refinement / Step 0 · 2 · 5 external environment automation |
| 0.3 | 2026-05-08 | Path B generalization |
| 0.2 | 2026-05-08 | Official release / Tier 1 · 2 · 3 classification / Step 0 auth check + Step 2 sibling assets |
| 0.1 | 2026-04 | Added / internal GitHub + external open-source recommendation baseline |

### cross-ecosystem-synergy-detection

| version | date | changes |
|:-:|:-:|---|
| 0.4 | 2026-05-08 | 8-asset cross-applicability matrix + self-X circuit matrix baseline |
| 0.3 | 2026-05-08 | Path B generalization |
| 0.2 | 2026-05-08 | Official release / Tier 1 · 2 · 3 classification / internal GHE org inventory / 13th naming (ecosystem synergy) |
| 0.1 | 2026-05 | Added (automated synergy exploration implementation) |

### hub-cc-pr-reviewer

| version | date | changes |
|:-:|:-:|---|
| 0.2 | 2026-05-08 | PR #7~#13 lifecycle accumulated / autonomous activation path baseline / disable path + persona synergy catch § added |
| 0.1 | 2026-05-08 | Added / PR review automation / PR #7~#11 lifecycle 5-iteration baseline |

### asset-placement-gate

| version | date | changes |
|:-:|:-:|---|
| 0.2 | 2026-05-15 | M5: trigger section specifies 4-step operation order (FH suitable / skill-free output label formalized) |
| 0.1 | 2026-05-14 | Added / FH 4-criteria judgment + project local value judgment 3-way routing / origin: wrong landing case (2026-05-14) |

### install-wizard

| version | date | changes |
|:-:|:-:|---|
| 0.5 | 2026-05-19 | Step 5 completion report "next-step skills" block added — hub-persona-auditor · agent-composer · plugin-recommender 3 introductions added (M1 resolved) |
| 0.4 | 2026-05-15 | M9: frontmatter `tools:` → `allowed-tools:` standardized (aligned with other FH skill spec) |
| 0.3 | 2026-05-14 | Step 2 proposal list: your-mcp-service MCP item specified — path A commitment fulfilled (`claude mcp add <your-mcp-service> -- npx -y <your-mcp-service>`) / your-mcp-service MISS item added to diagnostic sample output |
| 0.2 | 2026-05-14 | PMH_DIR not set branch: bootstrap guidance added (Step 0 immediate stop + clone · plugin install guide) / sentinel project-independent (`{project}_wizard_done`) — prevents malfunction with multiple projects on same machine / your-mcp-service MCP connection check added |
| 0.1 | 2026-05-14 | Added / onboarding wizard — environment detection → gap diagnosis → per-item approval → execution → acceleration baseline setting / Propose-First principle / auto-switches to check mode on re-run |

### install-doctor

| version | date | changes |
|:-:|:-:|---|
| 0.1 | 2026-05-13 | Added / 5-area conflict diagnosis before/after plugin install (CLAUDE.md · skill triggers · hooks · .claudeignore · audit practices) + Layer A fallback guidance |

### context-doctor

| version | date | changes |
|:-:|:-:|---|
| 0.3 | 2026-05-14 | Step 5 added — hub context periodic audit (CLAUDE.md · MEMORY.md · memory/*.md bloat detection → compression proposal) / trigger keywords reinforced (context diet · memory audit) |
| 0.2 | 2026-05-13 | Three-Doctor Loop integration section added (closed loop with harness-doctor · sim-conductor) |
| 0.1 | 2026-05-10 | Added / .claudeignore auto-generation + large file burst detection + /clear · model switching timing + audit-learnings integration / standalone install (mode C) supported |

### harness-doctor

| version | date | changes |
|:-:|:-:|---|
| 0.3 | 2026-05-13 | Step 3-4 periodic skill activity check added — weekly_audit mtime detection → 14/30-day S/M-tier warning (signal 2 implemented) |
| 0.2 | 2026-05-13 | Three-Doctor Loop integration section added (closed loop with context-doctor · sim-conductor) |

### persona-innovator (agent)

| version | date | changes |
|:-:|:-:|---|
| 0.2 | 2026-05-11 | Mode T added — technology bridge exploration (transport type identification → bridge architecture proposal) / your-mcp-service SSE real-world proof |
| 0.1 | 2026-05-10 | Added / 3-mode (I · E · F) + ideation algorithm 6-type named classification + frontier scan + simplification guard built in / Path B (external environment) supported |

### pr-review-watcher

| version | date | changes |
|:-:|:-:|---|
| 0.1 | 2026-05-11 | Added / PR review arrival monitoring + immediate summary / --once · --interval · --repo flags / multi-reviewer tracking |

### field-harvest

| version | date | changes |
|:-:|:-:|---|
| 0.2 | 2026-05-13 | Step 0 hardcoded paths removed → 3-step auto-discover (FH mapping → find PycharmProjects → cwd parent scan) |
| 0.1 | 2026-05-11 | Added / field pattern harvesting + FH reverse-harvest PR auto-proposal / --watch · --once flags |

### sim-conductor

| version | date | changes |
|:-:|:-:|---|
| 0.4 | 2026-05-19 | "Human Gate principle" section added — 4-case table for escalation from tentative to final convergence formalized / structural bias-blocking rationale |
| 0.3 | 2026-05-13 | Three-Doctor Loop integration section added |
| 0.2 | 2026-05-11 | Area D expanded (D-consumer: session · skill · memory consumer sim 3 types) + Area E added (output quality review 3 scenarios) |
| 0.1 | 2026-05-10 | Added / Area A (external user 3 scenarios) + B (internal 3-persona) + C (innovator) / Step 0~4 autonomous completion / M-tier auto PR + R1 frequency limit built in / Path B supported |

---

## Refactor History

### [refactor] — 2026-05-09 / PR #18 (`ac3202c`)

5/9 sim round scenario 3 persona-devil-advocate catch follow-through:

- 6 skill SKILL.md description: 80% of self-promotional language · iteration counts · version history · emphasis words removed
- description first-line essential spec obligation applied (audit-learnings · hub-cc-pr-reviewer)
- Embedded names avoided (verify-bidirectional: "specific-user or install environment user" → "user")
- Internal tone corrected (frontier-status-summary · cross-ecosystem-synergy-detection: "this harness AI" → "meta-harness")
- Internal-only references generalized (plugin-recommender)
- description "PR" truncation catch avoided (hub-cc-pr-reviewer)
- version history now references this CHANGELOG.md path

### [feat] — 2026-05-10 / PR #19 (CHANGELOG added)

- This CHANGELOG.md added (dead link avoidance / 6 skill version history persisted)
- Plugin Level + 6 skill integrated persistence (simplification guard / 1-file integration path)
- Keep a Changelog format applied

---

## Cross-link

- Sim round baseline: `feedback_description_diet_baseline.md` (hub / 5/9 scenario 3 catch)
- External install compatibility: `feedback_external_install_compatibility.md` (hub / 5/9 scenario 2 catch)
- description plain text + external friendliness: `feedback_skill_frontmatter_description_plain_text.md` (hub / 5/9 scenario 1 catch)

Earlier history: see git log or commit messages.
