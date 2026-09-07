# forge-harness (fh-meta) Changelog

### [Unreleased] — 4축 게이트가 `scripts/*.py` 를 본다

**BREAKING (gate):** `scripts/**/*.py` 가 이제 HEAVY 다 — 마커 없는 파이썬 단독 커밋이 막힌다.
처방 = `.sh` 와 동일: Axes 2–3 마커 + edit_manifest 항목.
🟥 **소비자 install 도 같다** — 설치된 훅은 «그 레포의» `scripts/**/*.py` 전부를 HEAVY 로 본다.
FH 와 무관한 파이썬 변경도 업그레이드 뒤엔 마커 없이 커밋이 막힌다. 그게 싫으면 `.sh` 와 같은
자리에서 같은 방법으로 좁혀라(훅 정규식 한 줄).
그 전까지 **출하되는 파이썬 8개**(측정 시점 7 + 3.1.4 이후 `doc_claim_triad_scan.py` —
`residency_closure_scan.py` · `memory_link_check.py` · `probe_live_eval_lib.py` 등)가 게이트를
한 번도 안 탔다. 훅 정규식 `^scripts/.*\.sh$` → `^scripts/.*\.(sh|py)$`. 레인
`test_heavy_classifier_lanes.sh` 가 이 구멍을 `uncovered` 로 **핀해 두고** 있었다 — 뒤집었다.

### [3.1.4] — 2026-09-07 — 논문이 arXiv 에 걸렸고, 「published」는 과대주장이었다

3.1.3 과 **같은 사유**다: 소비자가 받는 문서가 더 이상 참이 아니게 됐다.

    이전   cs.SE companion … **published** · Zenodo 22558450
    지금   cs.SE companion … **preprint, publicly posted** · Zenodo 22635721
                            · arXiv:2609.04218 (arXiv shows v1 as of 2026-09-07)

두 가지가 같이 바뀌었다.

**① arXiv 등재.** `submit/7775978` 이 68일 온홀드 끝에 통과해 `arXiv:2609.04218`(cs.SE)이 됐다.

**② 「published」를 뺐다.** cross-family 감사(codex)가 과대주장으로 지목했다 —
**예치(deposit)와 프리프린트 공개는 «게재»가 아니다.** 심사를 통과한 적이 없다.
자력 적발 0 이었고, 같은 라운드에서 유사한 과대주장 17건이 함께 지목됐다.

**③ Zenodo v1.2.1.** v1.2 가 §6.6 에서 severity 주장을 철회해 놓고 **초록과 §11 결론에는
그 주장이 그대로 살아 있었다.** v1.2.1 이 그 둘을 철회 문장으로 바꾸고 recall 에
단일세션 자격표시를 붙였다. 지금 논문 안에 그 주장을 *주장하는* 자리는 0이다.

동작 무변경 — 실행 코드 diff 0건이라 **patch** 다.

### [3.1.3] — 2026-09-07 — 출하 문서가 「arXiv in review」라고 말하는데 반려됐다

링크 정정이 아니라 **거짓 진술** 때문에 올린다. 3.1.2 를 받은 소비자의
`docs/OUTPUT_EVIDENCE.md` 가 methodology 논문을 이렇게 말하고 있었다:

    Paper v1.0 — methodology | Zenodo … arXiv in review

**2026-09-06 에 모더레이션에서 반려됐다.** 사유는 방법론이 아니라 인용이었다 —
17개 참고문헌 중 11개가 실제로 인용한 저작과 맞지 않았다. 그 정정본이 v1.0.1 이다.

바뀐 것:

    docs/OUTPUT_EVIDENCE.md   반려 사실 + v1.0.1 정정본 명시.
                              「방법론에 대한 평가로 읽지 마라」와
                              「v1.0.1 을 재심사된 것으로도 읽지 마라」를 함께 적었다
    README ×4                 v1.0.1 (22542168) · 거버넌스 v1.2 (22558450) 로
    knowledge/ 인용 5곳       concept DOI (20397565) — 판이 아니라 «그 논문»을
                              가리키는 자리라 항상 최신으로 해석된다
    multi_model_sidecar…      죽은 arXiv ID `submit/7657304` 를 죽었다고 명시
    README ×4                 마켓플레이스 진입 경로(배지 + 본문 링크). 슬러그는
                              추측 3개가 404 인 것을 먼저 확인하고 실측으로 골랐다

동작 무변경 — `action.yml`·게이트·레인 무접촉이라 **patch** 다.

⚠️ 이 릴리스가 검증하지 못한 것: 배지 «이미지» URL. shields.io 는 존재하지 않는
경로에도 200 을 주므로 그 확인에는 판별력이 없다. 검증된 것은 링크뿐이다.

### [3.1.2] — 2026-09-07 — Action 설명이 마켓플레이스 한도를 넘어 게시가 막혔다

운영자가 마켓플레이스 개발자 약관에 동의해 게시 체크박스가 열리자, GitHub 의 리스팅 폼이
`action.yml` 을 검증하고 **거절**했다:

    ✅ 이름   fh-gate — typed AI code-review verdict
    ❌ 설명   Description must be less than 125 characters   ← 155자였다
    ✅ 아이콘 shield · ✅ 색상 purple · ✅ README 존재

**이 레포의 어떤 검사도 그 한도를 안 보고 있었다.** 그래서 태그와 릴리스가 이미 만들어진 뒤,
게시 단계에서야 드러났다 — 배우기에 가장 비싼 자리다.

- 설명을 **121자**로(«안 돌았다 ≠ 통과」라는 이 액션의 구별점은 유지)
- **레인 D6** — `action.yml` 의 `description` 길이를 판정한다. 한도는 GitHub 것이라 여기서는
  상수일 수밖에 없고, 그 사실을 숨기지 않고 주석에 적었다. `D6` 은 읽기 실패도 잡는다(빈 값이면
  길이 검사가 공허 통과한다). fail-before: 옛 155자 설명으로 되돌리면 **정확히 D6 만** 적색
  (34 passed · 1 failed), 복원하면 35/0.

⚠️ `v3.1.0`·`v3.1.1` 태그는 안 움직인다. 마켓플레이스에 게시되는 것은 **3.1.2** 다.

### [3.1.1] — 2026-09-07 — fh-gate Action 의 기본 `level` 이 게이트가 안 받는 값이었다

### 🟥 무엇이 깨져 있었나
`action.yml` 의 `level` 기본값이 **`'standard'`** 였는데, `scripts/fh-gate.sh:275` 는 `quick` 과
`full` 만 받고 나머지는 **ARG_ERROR(11)** 로 거절한다. 그리고 `fail-on` 기본 집합에 `ARG_ERROR`
가 들어 있다. ⇒ **`uses: chrono-meta/forge-harness@v3.1.0` 을 `level:` 없이 쓰면 스텝이 실패했고,
에러 메시지는 사용자가 설정한 적 없는 인자를 지목했다.**

발행된 3.1.0 타르볼로 실측(소스를 읽은 게 아니다):
```
level=standard → rc=11  ERROR: gate level must be 'quick' or 'full' (got: standard)
level=quick    → rc=12  (DRY_RUN, 정상)
level=full     → rc=12  (DRY_RUN, 정상)
```

### 어떻게 잡혔나
릴리스 마커에 `standpoint: DEGRADED_NOT_RUN — 소비자 install 팔을 안 돌렸다` 라고 적어 두고,
발행 직후 그 팔을 실제로 돌렸다. **읽어서는 안 나오고 돌려야 나오는 자리**였다.
레인 28개가 이미 있었지만 전부 **종료코드 매핑**만 봤고 「입력 기본값이 CLI 가 받는 값인가」는
아무도 안 봤다.

### 고친 것
- `action.yml` `level` 기본값 `'standard'` → **`'quick'`**, description 도 «다른 값은 안 받는다»로
- **레인 D0~D2 신설** — `action.yml` 의 기본값과 `fh-gate.sh` 의 허용 집합을 **둘 다 실물에서 추출**해
  대조한다(어느 쪽도 하드코딩 안 한다 — 그러면 같은 방식으로 또 드리프트한다).
  D0 = 허용 집합 추출 성공(계기 생사) · D1 = 기본값이 그 안에 있나 · D2 = **컨트롤**(같은 검사가
  `'standard'` 를 거절하는지 — 아니면 D1 이 아무것도 증명 못 한다). fail-before 실증: 기본값을
  `standard` 로 되돌리면 **정확히 D1 만** 적색(30 passed · 1 failed), 복원하면 31/0.
- README 4판의 사용례를 `@v3.1.1` 로

⚠️ **`@v3.1.0` 태그는 그대로 둔다**(태그는 안 움직인다). 그 태그를 쓰는 워크플로는 `level: quick`
을 명시하면 정상 동작한다.

### [3.1.0] — 2026-09-06 — QP 플러그인 · `oracle:` 마커 채널 · preprep 도해 굽기 · FH 전체 지도 발행 · fh-gate GitHub Action

### 왜 minor 인가
CLAUDE.md §④-b — 새 자산(fh-qp 플러그인 · `oracle:` 채널 · preprep 도해) + 새 게이트 레인 다수 + 행동을 바꾸는 교리(3층 정본 개정). 🟡 **major 로 읽을 여지는 있었다**: fh-qp 는 «제품 QA» 라는 capability *class* 가 FH 에 처음 생긴 것(정책 ⓒ)이다. 다만 폴백 1차판 · 선택 설치 · 기존 게이트 무변경이라 minor 로 뒀다. 정체성 등급은 무변경(다섯 🟢 유지)이라 major ⓑ 사유도 없다.

### 🟥 BREAKING (gate): 마커 `oracle:` 근사키 차단 (#642)
**무엇이 이제 막히나**: `oracle_type:` · `Oracle:` · `oracle :` 처럼 «oracle 로 시작하는데 정확히 `oracle:` 이 아닌 줄」과, enum 6종 밖의 값. 종전엔 근사키가 조용히 무시돼 «오라클을 적었다고 믿는데 아무것도 안 적힌» 상태가 났다.
**처방**: `oracle: <known-pair|metamorphic|back-to-back|a-b|human|none — 근거>` 한 줄로 고치거나, 줄을 지운다(**부재는 통과**한다 — 이 필드는 옵셔널이다).

### 🟥 BREAKING (gate): preprep 레인 L12 diagram (#654)
**무엇이 이제 막히나** — 도해 표면(`kind: diagram_source`)을 **선언한** 덱에서만, 그리고 아래 여덟 가지에서만 rc=1 이 난다: 선언된 PNG 가 디스크에 없다 · 영수증 파싱 실패 · JSON 지문이 영수증과 다르다(고치고 다시 안 구웠다) · showcase validate 통과 기록 없음 · PNG 헤더 읽기 실패 · PNG 폭이 하한 미만 · viewBox 폭이 상한 초과(글자 배율 미달) · 여백이 하한 미만. **도해 표면을 선언하지 않은 덱은 무영향.**
🟥 **영수증이 «없는» 것은 차단이 아니다 — `UNMEASURED` 로 기록된다**(`lane_diagram.py:62` 가 `notes` 로 보내고 `preprep.py:903` 은 `findings` 가 있을 때만 rc=1). 손으로 넣은 그림은 이 레인이 «못 보는» 것이지 «틀렸다»가 아니고, 그 둘을 접지 않는 것이 이 레인의 설계다.
**처방**: 위 여덟 중 하나에 걸렸으면 `diagram_from_json.py` 로 다시 굽거나 표면 선언을 지운다. `UNMEASURED` 는 고칠 것이 아니라 «안 쟀다」는 기록이다.
⚠️ 이 문단의 초판은 「영수증 없는 그림은 차단」이라고 적었다 — 과대 주장이었고, 릴리스 전 cross-family 감사(codex)가 소스에서 잡았다. 자력 적발 0.

### 새로 실리는 것
- **fh-qp (QP · Quality Platform)** — qasp PAR 의 범용판. 도메인 상수 0, MCP 폴백 1차(Playwright 웹 · computer-use 데스크톱), typed capability 슬롯(미등록). 스킬 4 · `qp_tools.sh` · 레인 29 · 챔버 런 #18 EMIT. 선택 설치: `claude plugin install -s user fh-qp@forge-harness` (#653)
- **fh-gate GitHub Action** — `action.yml`. typed exit 7값을 boolean 으로 접지 않는 매핑, 모르는 코드는 `UNKNOWN`(fail-closed), 출력 `reviewed` 로 «안 돌았다 ≠ 통과» 를 분리. `fail-on` 기본이 PASS·PENDING 만 통과. 레인 28. 사용례가 `uses: chrono-meta/forge-harness@v3.1.0` 을 가리키므로 **이 태그가 그 자산의 사용 조건**이다 (#658)
- **마커 옵셔널 `oracle:` 채널** — TR 29119-11 오라클 유형 닫힌 enum 6, 훅은 형식만 검사. 레인 39 · 배선 W6 (#642)
- **마커 옵셔널 `affected:` 채널** — 「이 변경이 건드리는 것 + 열린 질문」 한 줄. 자리표시자만 있는 값은 차단(제로 영향은 명제상 없다) (#624)
- **preprep — «도해는 타입 JSON 에서 굽는다»** + 레인 L12 + 앵커 K1~K7. 첫 실사용 121장 덱 (#654). L13 슬라이드 참조 레인(장 번호 참조가 실제 장을 가리키는가) (#662)
- **FH 전체 지도** — `docs/map/FH_MAP.md` 5층 + archify 인터랙티브 3장, GitHub Pages 로 발행: **https://chrono-meta.github.io/forge-harness/** (#644 #645 #647 #659)
- **3층 정본 개정** — 3단 공정 = 모든 작업의 방법론 · 4대 엔진 = 출력이 나오는 코어 · 정체성 = 맞물려 나타나는 능력(5대 = 단련된 실물+등급) (#643)
- **ISO/IEC AI 표준 crosswalk** — 42119-2/3.2/7/8 · TR 29119-11 · 25059 · 42001 Annex A · 5338 · 23894 · TS 8200 (#641) · `docs/STANDARDS_ALIGNMENT.md`
- **live-eval** — `/prompt-regression` 의 라이브 짝(프로브 12 · 격리 클론 · 4값 채점 · launchd 템플릿) (#625), launchd PATH 에 `timeout(1)` 부재로 12/12 FAILED-TO-RUN 하던 것 수리 (#632)
- **worktree_reclaim.sh** — 워크트리 제거 «전» gitignored `tracks/**` 회수(목록 파일 먼저 → 복사+검증, 제거는 사람) (#639)
- **push-zone 게이트** — 비-소유 github.com 원격 push 를 pre-push 에서 차단 (#636) · **outbound query 가드** PreToolUse(WebSearch|WebFetch) (#637) · **residency 폐포 스캔**을 `crossfamily:` grounds 의 `residency=` 토큰으로 (#633)
- **sim 러너 MCP 격리** — `--strict-mcp-config` 기본. 헤드리스 팔이 운영자 사용자 스코프 MCP 를 상속하던 것 차단 (#651)
- **pipe_verdict_guard R3** — heredoc 뒤 «리다이렉션만 있는 줄»(zsh NULLCMD `cat` 이 stdin 파이프를 영원히 읽는 형태) 검출. «push 멈춤» 9건의 실제 원인이었다 (#618) · R2 오탐 수리 (#661)
- 문서: 모델 등급 × 기대 역량 (#635) · `docs/USE_CASES.md` · 카드 규율의 역방향 상주화(«안 닫힌 것이 사라지면 유실») (#656)

### 같이 고친 것
- `directional_diff_gate.sh` `has_nul` 이중 정의 — 셀프테스트가 자기 사본만 재고 프로덕션 파손에 초록이던 결함 (#634)
- 챔버 step 5 가 2026-08-17 교리 어휘(CURATED · NOT-APPLICABLE)를 받는다 — **18일간 러너가 교리를 거부하고 있었다** (#620)
- 헤드리스 런에서 Skill 툴 무음 거부(`--allowedTools`) + 그 플래그가 variadic 이라 뒤따르는 프롬프트를 먹던 인자 순서 (#612 #631)
- `fh_audit_check.zsh` 빈 허브에서 zsh 미매치 glob 오류 (#613)
- (허브 오너 노트 · npm 미출하) `sync-to-be.sh` 목적지 가드 — 비-git 디렉토리·외부 레포 서브디렉토리 companion 은 rc=12 거부 (#646)

### 알려진 한계 (이 릴리스 시점)
- `docs/map/**` 는 `files[]` 밖이라 **npm 배포물에 안 실린다** — GitHub Pages 표면에만 있다.
- live-eval 문턱 `0.80` 은 **보정 주간(~2026-09-11) 상수**다. rc 는 나오지만 판정에 쓰지 않는다.

### [3.0.0] — 2026-09-04 — 정체성 다섯 전부 🟢(identity 1.0 을 이 번호가 나른다) · 릴리스 트랙 통일 · 훅 사실 줄 · 게이트 무음 접힘 수리 · 6축 단련

### 왜 major 인가
CLAUDE.md §④-b major ⓑ — **정체성 다섯이 «전부» 🟢**(2026-09-04 ⑤ 증폭자 승격 #604, 여섯 행 Ⓑ①②③④⑤ 전부 초록, 4대 엔진도 전부 🟢).
운영자 결정(2026-09-04): `identity-v1.0.0` 은 정체성 트랙의 마지막 태그, **이후 한 번호** — 이 3.0.0 이 identity 1.0 을 같이 나른다. 🧭 접두 태그는 더 만들지 않는다. 등급의 정본은 여전히 `ship_readiness_gate.md` 의 셀이고 번호는 나르기만 한다.

### 🟥 BREAKING (gate): pre-commit [Pointers] 게이트가 워킹트리가 아니라 **인덱스**를 읽는다 (#602)
**무엇이 이제 막히나**: `.md` 를 스테이징한 뒤 디스크에서 지우면(또는 더 고치면) 종전엔 `[ -f ] || continue` 로 Detail-pointer 검사가 통째로 빠졌다 — 깨진 Detail 포인터(`**Detail**` + `See <path> §X` 형태)가 조용히 커밋됐다. 이제 `git show ":$f"` 로 스테이징된 바이트를 검사하고, 인덱스에서 못 읽으면 ❌ 로 막는다. **처방**: 스테이징한 것이 곧 커밋되는 것이다 — 디스크 파일을 믿지 마라. 레인 `scripts/test_precommit_pointer_index_lanes.sh`(일회용 클론) 가 옛 훅에선 정확히 P1 만 실패함을 보인다.

### 🟥 BREAKING (gate): selfcheck 가 명시경로 게이트 인프라(bin/fh-gate·fh-run·fh-goal 등) 부재를 FAIL 로 센다 (#602)
종전엔 glob 미매칭과 같은 `continue` 로 무음. glob 미매칭 스킵은 그대로. **처방**: 그 파일들이 없어졌으면 files[] 와 selfcheck 목록을 같이 고쳐라.

### 같이 들어온 것 (행동 변경, advisory)
- **proposal_hook**(#598 → #600 → #601 → #602): 판정·가드 줄 편집 시 «known-pair + degrade 방향» 제안을 PreToolUse 컨텍스트로. #601 부터 훅이 결정적 전제(레인 존재·레인 파일 자신·오늘 스캔 덮음)를 확인해 **«사실:» 줄**로 싣고 없는 항목만 제안 — r8 실측 근거가 옆 파일인 자극에서 복창 1/5 → 판단 4/5. Bash 팔은 raw 명령으로 토큰을 본다(sed -i 따옴표 안, 에어 노드 적발). `.git-hooks/*` 도 사정거리.
- **backtick_guard**(#592): 셸 이중인용 문맥의 백틱을 쓰기 전에 잡는 advisory 훅.
- **6축·3단 공정 단련**(#606, 운영자 승인): `scripts/revert_probe.sh`(ⓕ 범용 되돌림 프로브, 종료 0/1/2/10) · sim 러너 날짜 오염 필드 3(기록만) · 영혼 «성공 정의/절대 안 함» 2칸 advisory · ⓔ `shadow(N=,F=)` 사다리 · 사전등록 «몇 번째 프레이밍» 필드 · tier3 UNREACHED · ⓓ=선행자산 · 기호 전용 규칙. 새 차단 없음.
- **레인 이중 실행 단일화**(#603): test_lane_runner·caller_ratchet·package_coverage 가 out 과 rc 를 다른 실행에서 뽑던 구조 → 단일 실행(CI 비결정 L4 의 통로) · 실패 분기 출력 덤프 · no() 미정의 7곳 · prepublish_scope_note self-test 배선 · 이식성 11파일.
- **채점기**(#599): 인용 구간 제외 + 명사형 «없음» 결박 — 회차5 P07 0/5→5/5.
- **회차 러너**(#596·#597·#594): `--arms CTRL` 사전 디스패치 · 봉인 전 실행 · 헤더 철회.
- **sync**(#593·#595): exclude 대칭 · preprep 드리프트 앵커 컴패니언 자동 후보.
- **npm Trusted Publishing**(#590): 태그 `v<version>` 푸시 → OIDC provenance 발행. 이 릴리스가 그 경로의 첫 실사용.
- **문서**: 릴리스 트랙 통일(#605, README·등급표·CLAUDE.md ④-b) · ⑤ 세 얼굴(a 발화 · b 프로젝트 역량 · c 자연발화=등급) · 2주 반증 예측.

> 이 릴리스부터 패키지와 정체성은 **한 번호**다. 종전 `🧭 identity-v0.x` 는 이력. 노트 = 영어 본문 + 한국어 요약(GitHub Release).

### [2.15.1] — 2026-09-03 — 채점기·회차 게이트 fail-closed 4자리 + REFUSE_RE 결박 + 정체성 ④ 🟢

### 🟥 BREAKING (gate): 회차 게이트가 «깨진 qset» 을 더는 통과시키지 않는다
**무엇이 이제 막히나**: `scripts/round/eligcheck_qset.sh` · `gatecheck_qset.sh` · `context_continuity_score.sh` 에서
TSV 파서가 죽거나(값에 `|` · 파일 부재) 채점 행이 0 이면 종전엔 «🟢 전 문항 적격 / 선통과 / 계기 생존» rc 0 이었다
(프로세스 치환이 rc 를 삼켰다). 이제 파서 실패 → rc 2·3, 채점 행 0 → eligcheck 3 · gatecheck 6 · 채점기 12.
**처방**: rc≠0 을 «부적격»으로 읽어라. positive 전용 qset 을 eligcheck 에 넣지 마라(이제 positive 행도 채점된다 — 아래).

### 🟥 BREAKING (gate): eligcheck 가 positive 문항을 채점한다 — CTRL 이 토큰을 한 번이라도 내면 DEAD_CONTROL
종전엔 positive 행이 조용히 건너뛰어졌다(설계는 있고 코드가 없던 자리). 처방: 회차4 이후 positive 문항은 CTRL 사전 디스패치 후 이 게이트를 통과해야 봉인한다.

### 🟥 BREAKING (gate): REFUSE_RE 가 맨몸 부정을 거절로 안 읽는다
`없습니다|없다|없는 것|없었` 는 거절 대상 명사(기록·근거·항목…)에 결박됐다 — 설명문 안의 「반대 의견은 없었습니다」는 더는 거절이 아니다.
얼린 바 48/48 · 96/96 유지. 처방: 기존 회차 숫자는 재산출 대상(negative 축 과차단 감소 방향). 브래킷은 ASCII 전용, grep 은 `LC_ALL=C` 핀.

### 🟥 BREAKING (gate): ccs 오염 게이트가 6열 qset 에서 눈뜬다
`read` 4변수가 6열에서 토큰을 `"tok||"` 로 삼켜 git grep 이 영원히 0 히트였다. 처방: 6열 qset 회차는 오염 게이트를 다시 통과해야 한다(재검: round2 2건 실피해 0).

### 같이 들어온 것
- `capability_effect_probe.sh`: 스냅샷 부재 dir → «부작용 없음» 오판 → SNAPSHOT_ERROR → RC_HARNESS(10)
- `target_pin.sh` mtime GNU/BSD 분기 레인(P6~P8, stat 흉내) · 레인 E0·E4~E9·G1~G5·L16·L29
- salience-splitter description 다이어트(561→375자) — 등재 준비
- **정체성 ④ 프런티어 답습 🔵 → 🟢** (2026-09-03 운영자 판정, 근거 `ship_readiness_gate.md` ④ 행). 정체성별 단계: Ⓑ①②③④ 🟢 · ⑤ 🔵(2회차 «플로어에서 안 뜬다» — 배선 결함으로 기록, 다음 사전등록)

### [2.15.0] — 2026-09-02 — 게이트 정본을 Codex 진입점에 미러 + round/ 계기에 앵커

### 🟥 BREAKING (gate): `axes-run:` 한 줄에 `ⓔ=` 는 **정확히 하나**여야 한다

**무엇이 이제 막히나**: **새 계기 파일을 추가하는 커밋**에 한해, Axes 2–3 마커의 `axes-run:`
줄에 `ⓔ=` 표기가 **하나가 아니면**(0개든 2개 이상이든) 커밋이 차단된다. 종전에는 2개일 때
첫 번째만 읽고 나머지를 조용히 버렸다 — 즉 «둘째 ⓔ 에 적은 근거»가 검사도 기록도 안 되는
상태로 통과했다. 읽는 사람과 기계가 같은 값을 안 보는 자리였다.

**적용 범위**: 계기를 «추가»하지 않는 커밋은 이 다리를 아예 안 지난다
(`validate_first_use_leg` 이 새 파일 없으면 즉시 통과). 수정·삭제만 하는 커밋은 무관하다.

**한 줄 처방**: `ⓔ=` 를 하나로 합쳐라. 실행 근거가 여럿이면 그 한 칸 안에서 `·` 로 잇는다.

### 🟥 BREAKING (gate): 발행 스캔이 «스캔 못 한 파일»에 차단한다

**무엇이 이제 막히나**: `npm publish` 의 `prepublishOnly` 가 부르는
`scripts/public_surface_scan_files.sh` 가, 발행 파일 목록에 있는데 **읽지 못한 파일**을 만나면
`exit 1` 로 발행을 막는다. 종전에는 읽기 실패를 조용히 넘겨 «스캔했고 깨끗함»과 구분되지 않았다.

**한 줄 처방**: `npm pack` 산출물과 목록을 대조해 읽을 수 없는 항목을 없애라. 알고 지나갈
때만 `PUBLIC_SURFACE_OK=1 npm publish`(이 우회는 로그에 남는다).

**왜 minor 인가**: 발행은 비가역 표면이라 degrade 가 fail-closed 여야 한다
(CLAUDE.md §Irreversibility Gates). «스캔 못 한 파일»을 «깨끗»으로 렌더하던 것이 결함이다.

### 같이 들어온 것 — 차단 아님

- `scripts/context_continuity_score.sh` 가 typed 태그(`<<VERDICT:…>>`)에서 **판정을 건너뛰던
  것**을 고쳤다. 태그는 이제 경로 표시(접두)로만 쓰고 검증 경로가 항상 값을 낸다.
  🟥 **게이트 수용은 안 바뀐다**(채점기이지 게이트가 아니다). 다만 **규약이 켜진 회차의 기존
  숫자는 재산출이 필요하다** — 그 회차들은 `negative` 축의 구분이 통째로 사라진 채 집계됐다.
- `scripts/round/{eligcheck_qset,instrument_manifest}.sh` 도 같은 회차에서 차단 분기가
  늘었다(응답 파일 부분 부재 · 채점 지시문 미봉인). 🟥 **둘 다 `files[]` 밖이라 소비자에겐
  안 나간다** — 이 레포 내부 계기이므로 BREAKING 으로 세지 않는다.

### Codex 진입점 미러 (④-b 가 잡은 드리프트)

`CLAUDE.md` 쪽에만 있던 9/1 게이트 서술이 `AGENTS.md` 에 없었다. 두 진입점은 **다른 런타임이
읽으므로**, 한쪽에만 사는 규칙은 다른 쪽에 **안 보인다**. 양방향 드리프트 검사가 후보를 냈고
판정은 사람이 했다.

🟥 명명된 잔여: `standpoint: tier1b(codex-runtime)` — 그쪽 진입점 파일을 **읽어서** 맞췄지만
**Codex 세션에서 실행하지 않았다.**

### round/ 회차 계기 4종에 «돌리는» 앵커 (new-code-anchor 4 → 0)

`delta_guard` · `target_pin` · `instrument_manifest` · `eligcheck_qset` 넷이 앵커 없이
출하되고 있었다 — 「출하되는 레인이 출하 안 되는 도구를 부르면 package_coverage 가 울고,
안 부르면 new_code_anchor 가 운다」는 한 문제였다. 출하 안 되는 레인 스위트를 신설해 풀었다.

⚠️ **소비자에겐 아무것도 안 늘어난다** — 넷과 그 레인은 `files[]` 밖이고
`ACCEPTED_ABSENT` 로 선언돼 있다. 이 항목은 «이 레포의 게이트가 자기 코드를 잰다»는 뜻이다.

### 그 밖

- `scripts/selfcheck.sh` 의 실행비트가 2.14.0 이후 조용히 떨어져 있었다 — 복원(내용 무변경).
  오늘의 호출부는 전부 `bash …` 형태라 기능 파손은 **없었다**. «깨진 것의 수리»가 아니라
  «무장해제될 자리의 복원»이다.
- 로케일 문자열-동등 결함 수리, 격리 레인 중복 검사 등 2.14.0 이후 누적분.


### [2.14.0] — 2026-08-31 — 영혼 엔진 배선 + sim 경로 격리

### 🟥 BREAKING (gate): 2026-09-01 부터 마커에 `defeater:` 가 필요하다

**무엇이 이제 막히나**: **2026-09-01 이후 날짜**의 Axes 2–3 마커에 `defeater:` 줄이 없으면
**커밋이 차단된다.** 「이 성공 정의가 틀렸다면 **무엇이 관측될 것인가**」 한 줄이다.
비공허성만 검사한다(6낱말 이상). 그 전 날짜의 마커는 **소급 없음**.

**한 줄 처방**: 마커에 `defeater: <틀렸다면 관측될 사건>` 을 추가해라.
반증 조건이 정말 없으면 `defeater: 없음` 도 **합법**이다 — 선언된 부재는 값이고 침묵이 아니다.

**같이 들어온 것(차단 아님)**: `tenets:` 는 **선택**이다. 인용하면 `.claude/soul_tenets.txt` 에
실재하는 `FH-T\d\d` 만 허용된다(오타를 조용히 안 버린다). 인용이 없으면 통과한다.
`soul-check:` 는 **있으면** enum 이 강제되고 **없으면 통과**한다(부재는 차단 아님).

**왜 지금**: `judgment-circuit`(영혼) 엔진이 🔴 였고 기계 앵커가 6단 중 1단뿐이었다.
외부 정본을 따랐다 — 원자 tenet([arXiv 2605.24229](https://arxiv.org/abs/2605.24229)) ·
defeater([Assurance 2.0](https://arxiv.org/abs/2004.10474)) · 양방향 추적성(DO-178C) ·
등록부 규율([AWS tenets](https://aws.amazon.com/blogs/enterprise-strategy/tenets-supercharging-decision-making/):
최대 7 · 우선순위 · **반대가 방어 가능해야 한다**). 셋 다 «기록의 속성»만 단언한다.

### 🟥 sim 러너는 2.13.0 까지 «격리»가 아니었다

`scripts/sim_isolated_run.sh` 헤더가 *"disposable clone 이라 오염 없음"* 이라 적어왔으나
**클론은 cwd 일 뿐**이고 `--tools "Read,Grep,Glob"` 는 쓰기만 막았다. 실측에서 팔이
**채점용 정답 키를 그대로 읽었다.** 이 버전부터 클론에 `Read` deny 를 주입한다
(실제 레포 · 홈 · out · 다른 팔의 클론 트리). 격리가 없으면 **회차를 시작하지 않는다**.

⚠️ **2.13.0 이하로 낸 sim 숫자는 재측정 대상이다.** ARM/CTRL 차이가 「운반체 덕」인지
「팔이 답을 읽었는지」 구조적으로 구분되지 않는다.

### 그 외

- `portability_lint` **[P10]** — `tr` 집합 안의 하이픈이 **범위**로 읽히는 이식성 결함.
  GNU/BSD 가 갈리고 **로컬만 초록**이 되는 클래스를 로컬로 당겨온다.
- 훅 다리 넷이 «정의만 하고 안 부르는» 상태를 잡는 배선 레인(`test_hook_leg_wiring_lanes.sh`).
- 마커 스펙(`.claude/rules/fh_4axis_gate.md`)에 `soul:`·`soul-check:`·`defeater:`·`tenets:` 기재
  — 🟥 `soul:` 은 2026-08-21 부터 차단해왔는데 **어느 규칙 파일에도 적혀 있지 않았다**.


### 🟥 BREAKING (gate): novelty/absence 주장 검사가 **차단**으로 바뀐다 (2026-08-30)

**무엇이 이제 막히나**: `knowledge/**` · `docs/**` 의 `.md` 를 커밋할 때, **세계에 대한
신규성·부재 주장**(「선례가 없다」·「시장에 유일하게」·`no prior art`·`unprecedented` 등)이
**±6줄 안에 외부 앵커 없이** 서 있으면 **커밋이 차단된다.** 종전에는 advisory 였다.

**한 줄 처방**: 그 주장 옆에 외부 앵커를 둬라 — URL · arXiv/DOI · `WebSearch`/`WebFetch` ·
`출처` · `원문 확인` · `서베이`. 강행이 필요하면 `FH_NOVELTY_OK=1 git commit …` (기록에 남는다).

**왜 지금**: `external-grounding` 엔진이 🟡 인 두 다리 중 하나가 「배선은 됐는데 안 막는다」였다.

🟢 **켜기 전에 쟀다** — 대상 표면 전수(`knowledge/`·`docs/` **69개 문서**)에서 무앵커 **0건**.

🟥 **그 숫자가 «켜도 안전하다»를 지지하지는 않는다** — cross-family 패널(gpt-5.5 · gemini-3.1)이
독립 수렴해 지적했고 맞다. 잰 것은 **완성돼 안착한 정적 코퍼스의 마찰**이지, 저자가 **작성 중인**
워크플로가 아니다. 사람은 주장을 먼저 쓰고 출처를 나중에 보강한다. 소비자 코퍼스·미래 편집·
무관 앵커의 false pass 는 **전부 미측정**이다. 정확한 표현은
「**현재 이 레포의 정적 마찰 = 0**」이지 「배포 안전」이 아니다.

⚠️ **명명된 우회 경로 3건** (숨기지 않는다 — 두 계열이 같은 것을 짚었다):
1. **무관한 앵커 세탁** — ±6줄 안에 **아무 URL** 이나 있으면 통과한다.
   *"이 아키텍처는 전례가 없다. 백엔드는 [Node.js](https://nodejs.org)로 구축했다."* 가 통과한다.
   앵커의 **존재**만 보고 **연관성**을 안 본다(진위는 phantom-quench 의 일).
2. **GUI git 클라이언트** — VS Code·SourceTree 등에서 커밋당 env 주입은 번거롭다.
   가장 쉬운 우회가 **「Skip hooks」 = `--no-verify`** 이고, 그건 **같은 훅의 Destructive-Op
   게이트까지** 끈다. 그래서 차단 메시지가 이 함정을 명시적으로 경고한다.
3. **override 는 습관이 되기 쉽다** — env 는 셸에 export 해두면 영구다.
   완화: `tracks/_meta/.novelty_override_log` 에 **시각·브랜치·우회한 주장**을 append 한다
   (집안 관행 `.psa_override_log` 와 같은 형태). 🟥 초판은 「기록에 남는다」고 **말만** 하고
   원장이 없었다 — gpt-5.5 가 잡았고, 그건 규칙이 자기 기계를 잘못 서술한 판이었다.

All notable changes to fh-meta plugin and all skills.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

**Version policy**: v0.x = internal validation phase / v1.0 = external install confirmed

---

### [2.13.0] — 2026-08-29

> **추가 (발행 전 보완)** — 아래 두 항목은 릴리스 커밋 이후, **발행 전에** 같은 2.13.0 으로
> 들어왔다. 미발행 상태라 노트를 보완하는 것이 태그·타르볼·문서를 일치시키는 정직한 방향이다.
>
> - **새 게이트 행 + 필드 렌즈 — `measurement-reps`.** 측정을 기록했는데 `reps` 가 바(3) 미달
>   이고 그 결론이 **하중을 지면**(판정·등급·교리·비가역 처방) 한 줄 제안이 뜬다. 지금까지는
>   「바 미달」이라고 **적고 넘어가는 것**이 기본값이었다 — 라벨은 측정이 아니다. §Field-Harness
>   Diagnostic 도 8렌즈 → **9렌즈**. 🟥 필드 하네스에 돌리기 전에
>   `knowledge/shared/harness-core/field_harness_diagnostic.md` 의 **Step 0(provenance 분리)**
>   를 읽어라 — FH 파생 하네스를 그냥 스캔하면 FH 자기 텍스트를 필드 발견으로 되읽는다
>   (실측: 어느 필드 레포 원시 히트의 2/3).
> - **인사말 번역 조항** — 문장은 어느 언어로든 자연스럽게 옮기되 이름 「FH」는 움직이지 않는다.
>   🟥 **측정했고 안 닫혔다**(컨트롤 1/3 · 조항 2/3, n=3 에서 차이 1). 조항은 옳고 싸서 남겼지
>   효과가 측정돼서가 아니다. 이 축엔 기계 floor 가 없다.
> - 🟥 **fail-open 수리 — `templates/regression_guard.sh` F1(frontmatter).** 발행 직전 보안 패스가
>   찾았다: 검사기(`python3`)가 없거나 안 도는 머신에서 F1 이 **「✅ frontmatter intact」로 렌더**
>   됐다 — 출력에 `FAIL` 토큰이 없다는 이유만으로. **macOS 는 python3 를 기본 탑재하지 않으므로**
>   상당수 소비자에게 이 레인은 늘 초록이었고, 그 초록은 「검사했다」가 아니라 「검사기가 없었다」였다.
>   이제 **종료코드**로 판정한다(0=정상 · 1=FAIL · 그 외=`⚠️ F1 UNMEASURED`). 🟥 **차단하지 않는다**
>   — 가역 표면이고, 과차단은 이 파일 자신이 경고한 대로 `--no-verify` 를 근육에 새긴다.
>   ⚠️ **행동 변화**: 그런 머신에서 이제 경고 줄이 뜬다. 통과/차단 판정은 안 바뀐다.
> - `scripts/activity_log.sh` 가 **files[] 에 진입**했다 — 배포되는 digest 생산자
>   (`frontier_digest_autopilot.sh`)가 언더스코어 날짜 파일을 만드는데 그 판독기가 안 실려 있었다.

> **BREAKING (gate)**: `templates/regression_guard.sh` 의 Axis 1 pathspec 이 이제
> `README*.md` · `CHEATSHEET.md` · `CATALOG.md` · `.github/workflows/*.yml` · `scripts/*.py` ·
> `.claude/registry/*.md` · `package.json` 을 **본다**. **FH 클론에 4축 pre-commit 훅을
> opt-in 한 경우**, 그 파일들만 바꾼 커밋이 이전엔 `SKIP (not-checked)` 이었는데 이제 검사되고,
> 대규모 삭제 시 `REVIEW`(S-tier) 또는 `BLOCK`(M-tier)이 될 수 있다.
> **처방**: 의도된 감량이면 마커에 근거를 적고 진행한다 — S-tier 는 머지를 막지 않는다.
> 영향 범위는 **FH 클론 + 훅 opt-in** 에 한정된다(그 게이트는 필드 프로젝트에 설치되지 않는다).

**Added**
- `docs/MODEL_SETUP.md` — 모델 교리의 정본 신설. `/model` 선택 표 · `opusplan` 측정 캐비앗
  (10턴 중 Opus 0턴) · 하드웨어 티어 · **두 구조 법칙** · Multi-Model Sidecar.
  `docs/OUTPUT_EVIDENCE.md` 가 「README §Model setup」을 역참조하던 것을 이 파일로 고쳤다
  (그대로 뒀으면 README 감량 후 팬텀 참조가 된다).
- `scripts/gate_pathspec_check.sh` — 새로 커버된 클래스에 **앵커 6쌍 추가**. 되돌림 프로브 확인:
  `README*.md` 항만 제거하면 FAIL, 복원하면 PASS(30쌍).

**Changed**
- **README 4판 감량 3,443 → 1,535줄 (−55%)**. EN 896→382 · ko 880→387 · ja 861→396 · zh 806→370.
  가장 설득력 있는 증거(OpenCode 실측 · 8홀 5/8→6/8→8/8)가 **72% 지점**에 묻혀 있던 것을
  **40% 지점**으로 올렸다. 지운 것은 전부 착지처를 열어서 확인하고 옮겼다.
  🟥 판마다 보존 경계가 다르다(EN L1~100 · ko L1~96 · ja L1~111 · zh L1~106) — 「100줄」을
  일괄 적용했으면 ja·zh 는 두 문(door) 구조를 잘라먹었다.
- `CHEATSHEET.md` — `FH_BACKEND=cross` 행 신설(기존 `FH_BACKEND` 행에 「one leg」 명시:
  `auto` 는 폴백 *선택*이라 레그를 하나만 돈다) · PyYAML 요구사항 착지(§6).
- `fh_three_layer_canon.md` — 「'4'가 셋이다」 3자 구분표를 `README.ko.md` 에서 정본으로 이관
  (4개 언어판 중 ko 에만 있던 비대칭 해소).

**Fixed**
- **온보딩 분기** — 뭔가 하고 **마감 없이 끈 사용자에게 「완전 신규」 인사가 뜰 수 있었다.**
  정본(`fh_detail_protocols.md`)은 원래 옳았고(`tracks/_meta/*.md` 도 세션 파일로 센다),
  상주 요약이 「밑줄 디렉터리는 안 센다」를 어디에 거는지 안 정해 놓은 것이 원인이었다.
  인사는 세션 첫 턴이라 detail 을 안 읽고 판정하는 경로가 실재한다 — 두 조건을 갈라 적었다.
  같이: 재방문 문 **아래** 마감 권고 한 줄(문 개수·환영문 리터럴 불변) ·
  🟥 **마감 트리거를 「어느 언어든」으로 명시** — 인사말 트리거는 이미 그런데 마감은 아니어서,
  세션이 「마무리하자」라고 가르쳐도 그 말이 목록에 없었다. 블라인드 sim 이 잡았다.
  검증: 플로어 티어(sonnet) known-pair **reps=3** — ARM 마감줄 3/3 · CONTROL 0/3.
- `ship_readiness_gate.md` — §6 「확인된 stale 2건」이 그 자체로 stale 이었다. 1건은 stale 이
  맞고 1건은 **수리완료를 미수리로 가리키는 오보**였다. 둘 다 철회·정정.
- `scripts/activity_log.sh` — digest 날짜 정규식이 대시 표기만 봐서 언더스코어 파일 **70건을
  무음 드롭**했다. `emit_line` 에 정규화가 있는데 호출부가 그 앞에서 죽여 도달하지 못한 형태.
  실측 1 → 71.
- README 4판의 stale 사실 2건 — 버전 셀(`2.8.0` vs 실제 2.12.1)과 정체성 등급(② 는 2026-08-21
  부로 🟢). **고쳐 적지 않고 복제를 지웠다** — 그 문단이 스스로 «두 파일에 나눠 두면 썩는다»고
  적어놓고 복제한 자리였다.

---

### [2.12.1] — 2026-08-28

**코드 무변경.** 2.12.0 이 **정정 전 리드미**로 발행됐다 — v2.12.0 태그(19:48)가 리드미 정정
PR #541 머지(20:33)보다 45분 앞섰다. `BREAKING (gate):` 줄 없음(게이트 수용 무변경).

#### Fixed
- **리드미 4판(en·ko·zh·ja) 재발행** — 발행분에 빠져 있던 것이 두 가지다.
  ⓐ ②문 게이트 서술이 정정 전 형태(*"It fires on its own, before the commit"*)
  ⓑ 🟥 **소비자 보호 경고 부재** — 「FH 의 4축 **pre-commit** 훅은 허브 경로·마커를 하드코딩하고
  있어 **네 레포에 깔면 커밋이 막힌다. 네 레포엔 ①이 게이트다**」. 그 실패를 막으려고 쓴 문단이
  배포면에 없었다. 과장 하나가 아니라 경고 누락이다.
- 확인 방법: 태그 시각이 아니라 **`npm pack` 으로 실물 tarball 을 열어** main 과 대조
  (README 16줄 · ko 16 · zh 15 · ja 17 / 나머지 `files[]` 는 전부 동일).
  🟥 **태그 시각은 대리변수고 tarball 이 대상이다** — 이번엔 시각으로 잡혔지만 겹쳤으면 못 잡는다.
  발행 후 실물 대조를 `RELEASE_READY` 서식에 의무로 넣었다.

---

### [2.12.0] — 2026-08-27

**BREAKING (gate)**: `fh-goal` 이 `git status`/`git diff` 조회 실패를 더 이상 「변경 없음」으로
접지 않는다. 종전에는 조용히 통과(exit 0)하며 `fh-gate` 호출 자체를 생략했다 — 조회가 실패한
것과 변경이 없는 것을 같은 값으로 접은 fail-open 이다. 이제 **exit 10** 으로 막는다.
**처방**: `--files` 로 대상을 명시하거나, git 조회가 실패하는 원인을 고친다.

#### Fixed
- **게이트 인접 fail-open 3경로 차단** — ⓐ `fh-goal`(출하물) 의 git 조회 실패 → 위 BREAKING
  ⓑ `degrade_direction_scan.sh` 의 S1b 주석 억제 ⓒ `session_close_check.sh` 의 읽기 실패 → 0.
  셋 다 «못 읽었다」를 «없다」로 접던 자리다. 각각 되돌림 앵커가 붙은 레인으로 증명한다.

#### Added
- 새 게이트 레인 4종 — S1b 프로브 · ENV-ISO(레인 환경 격리) · utterance-probe · fh-goal 변경 탐지
- `scripts/utterance_skill_probe.sh` — 정체성 ④ 발화-유도 스킬 계측 채널 (주입 0 / 차단 0)
- SessionStart 배너에 노드 명 표시 — 다중 노드에서 어느 머신의 판정인지 구분

#### Changed
- **공개 리드미 네 판(en·ko·zh·ja) 도입부를 두 문 구조로** — ① 게이트만(`npx`/`brew`,
  Claude Code 불요) / ② 하네스 전체. 진입 경로 안내가 네 곳에 흩어져 겹치던 것을 하나의
  결정으로 접고 나머지를 상세로 내렸다. 「두 문 다 아닌 것」 절을 새로 두어, 이 도구가 **뒷단의
  검토를 대신하지 않는다**는 것과 **diff 로 볼 수 없는 것은 사람의 몫**이라는 것을 명시한다.
- 한국어판 번역투 정리 — 산문 em dash 149건 → 0 · 낫표 → 작은따옴표 · 「당신」은 표어 한 줄만
- **중국어판 인용부호 수정** — 간체 문서인데 번체 관행 「」 를 쓰고 있었다(27건 → `“ ”`).
  ASCII 도식 안 7건은 East Asian Width 차이로 표 정렬이 깨져 의도적으로 남김.
  일본어판은 「」 가 표준 부호라 **제외**
- `salience-splitter` Floor ① 에 소비자 분기 문서화 — 측정 불가 = KEEP 기본, CUT 없음
- 데모 GIF 페이싱 — `36.0초 → 23.0초`(899→575 프레임 · 592→550KB). 정지 화면이 53%였고
  끝 8초가 통째로 죽어 있었다(GitHub 은 GIF 를 루프한다). BLOCK→수정→PASS 마지막 프레임은 동일

---

### [2.10.0] — 2026-08-24

**BREAKING (gate)**: `lane_runner_check` 가 러너 표면을 워킹트리가 아니라 **git index** 로
판정한다. clone 트리에서 untracked 러너에 기대던 레인은 이제 DEBT 로 뜬다 — 그 초록은
clone 을 못 넘는 것이었다. **처방**: 그 러너를 `git add` 하거나 EXEMPT 로 선언한다.
npm 설치본(`node_modules`, gitignored)은 `outside-index` 분기로 디스크 폴백하므로 무변경.

#### Fixed
- **러너 표면 index 전환** (`lane_runner_check.sh` · `script_caller_ratchet.sh`) — 러너 이름과
  본문 둘 다 index 기준(`ls-files` + `cat-file --batch` 단일 프로세스). 실패는 전부 UNMEASURED:
  git 없음 · 깨진 index · `ls-files` rc≠0 · blob 아님 · 조기 종료 · 짧은 본문. 빈 결과로 접는
  경로 0개. 「git 아님」과 「git 실패」는 `.git` 상향 탐색으로 분리한다(판별자 자신의 실패 대비).
  🟥 **모집단(검사 대상)은 그대로 디스크 기준** — 그쪽 글롭은 untracked 를 *잡는* 안전 방향이고,
  함께 바꾸면 새 스크립트가 조용히 모집단에서 빠진다. 위험 방향이 반대인 두 글롭을 갈랐다.
- dotfile parity: 세그먼트 선행 dot 가드로 `glob.glob` 원래 동작 유지(리터럴 dot 디렉터리 무영향)

#### Added
- `scripts/test_runner_surface_index_lanes.sh` — 32레인, 되돌림 앵커 6그룹(enum·state·dot·
  content·isfile·nul). 각 앵커가 자기 그룹만 적색임을 실행으로 확인
- `.github/workflows/new-code-anchor.yml` + 체커/레인을 tracked 로 — 종전엔 untracked 라
  CI 에서 한 번도 돌지 않았다. 이 릴리스부터 PR 마다 돈다(필수 체크는 아니다)

#### Docs
- `docs/ETHOS.md` — "harness" 라는 낱말에 대한 한 문단. 🟥 넣기 전에 쟀고 **계측은 「넣지 마라」**
  였다(플로어 티어 블라인드, CONTROL 3/3 이 문장 없이도 두 뜻을 알았다). 운영자 판정으로 넣었고
  그 사실을 커밋에 남겼다 — taste 층이다

#### Notes
- cross-family 4라운드, 신규 S/A 벡터 `3 → 1 → 0 → 2 → 0`. R3 에서 뒤집힌 것 자체를 마커에
  남겼다 — 라운드마다 새 코드가 새 결함을 낳았고, 5라운드는 「조이지 말고 줄여라」로 안 돌렸다
- 잔여: `outside-index` 트리에서는 이 보호가 꺼진다(라벨만) · `LOCAL_ONLY_SURFACES` 는 디스크
  기준(의도) · `GIT_DIR`/`GIT_WORK_TREE` 명시 배치 미측정 · `check-ignore` 부재는 fail-closed

---

### [2.9.1] — 2026-08-23

**자릿수 근거 (patch)**: 수정 · 배선 · 표시자료. 행동을 바꾸는 교리도 새 게이트 클래스도 없다.
**`BREAKING (gate)` 없음** — 게이트가 무엇을 막는지는 2.9.0 그대로다.

#### 🟥 `--version` 이 «대상 파일»로 읽혀, 사용자의 `claude` 가 우리를 인젝션으로 판정했다

`scripts/fh-gate.sh` 에 **플래그 처리 분기가 존재하지 않았다**(`grep` 히트 0). 모든 인자가
`TARGET_FILES` 로 흘러서 `npx @chrono-meta/fh-gate --version` 이 «대상 파일: --version» 으로
거버넌스 프롬프트를 만들고 사용자의 `claude` CLI 로 보냈다. Claude 는 그것을
**프롬프트 인젝션 시도로 판정하고 거부**했고, 그 거부문이 우리 도구의 출력으로 찍혔다.
**신규 사용자가 가장 먼저 치는 명령이 그것이다.**

이제 `--version`/`-V`·`--help`/`-h` 를 처리하고, **인식 못 하는 `-*` 는 `exit 11` 로 거부**한다 —
모르는 플래그를 파일명으로 강등하는 것은 «알 수 없는 입력 → 약한 처리»다.
기존 호출(인자 없음 = git diff 자동감지 · 파일목록)은 무변경이며 컨트롤로 확인했다.

🟥 **적대검증도 레인도 못 잡았다.** 「`--version` 을 쳐본다」를 아무도 질문하지 않았고,
Reddit 게시글에 그 명령을 넣기 직전 레포 **밖에서 실제로 돌려서** 나왔다
(`[[feedback_adversarial_review_not_substitute_for_first_use]]`).

#### 소비자 표면 수리

- **`package.json` 에 `homepage`·`bugs` 신설.** 없으면 npmjs.com 페이지에서 레포 링크가 눈에
  띄는 자리에 안 걸린다. 실측: npm 주간 다운로드 2465 → 14일간 레포 유입 **uniq 1명**.
  ⚠️ 다만 그 두 숫자는 **둘 다 사람을 안 센다** — 다운로드는 미러/스캐너 바닥을 포함하고
  (구버전 110개에 주 2~3건씩 균일하게 깔린다), npm 의 레포 링크는 Referer 를 안 보낸다.
  **새는 것을 막는 수리이지 채우는 것이 아니다.**
- **postinstall 배너 재작성.** 「유용하면 별을 눌러달라」만 있고 **무엇을 하는 물건인지 0글자**였다.
  이제 한 줄 정의 + 지금 돌려볼 명령 + 그 결과를 말한다. 🟥 문구를 쓰기 전 실제로 돌려봤고
  초안 둘이 팬텀이었다(`--help` 미지원 · `check` 서브커맨드 부재).
- **README star 배지 제거**(4개 언어판). 정보가 아니라 사회적 증거 위젯이고, GitHub 이 레포
  상단에 같은 숫자를 항상 표시하므로 은폐가 성립하지 않는다 — 강조하지 않기로 한 것이다.

#### 데모 GIF — 연출이 아니라 재생성 가능하다

`docs/demo/gate-block.gif` + `.tape` + `setup.sh`. 에이전트가 스킬 명세를 「정리」했고 diff 는
8줄 삭제로 무해해 보이는데, `regression_guard` 가 `'Done When' section group dropped (1 → 0)` 으로
이름을 대고 BLOCK 한다. **섹션만 되살리고 정리는 유지하면 PASS** — 게이트는 정리를 막지 않고
손실만 막는다. `brew install vhs && vhs docs/demo/gate-block.tape` 로 누구나 같은 GIF 를 다시 굽는다.
🟥 첫 렌더의 2막은 틀렸고(전부 되돌려서 `SKIP (not-checked, NOT a pass)`) **프레임을 눈으로 봐서**
걸렸다.

#### 잔여 — 이름으로

- **다른 bin(`fh-run`·`fh-goal`·`fh-codex-doctor`)의 플래그 처리는 전수 검사하지 않았다.**
  히트 수만 셌고(각 1) 형태는 안 봤다. half-fix 전파경계 후보로 남긴다.
- 대시로 시작하는 파일명은 이제 거부된다. `--` 구분자는 **안 넣었다** — 실재한 적이 없다.
- 데모 GIF 의 전환 효과는 **미측정**이다. 근거는 남의 코퍼스 상관(n=252)이다.

---

### [2.9.0] — 2026-08-23

**자릿수 근거 (minor)**: 새 게이트 레인 둘 · 새 자산 하나 · 소비자 게이트 수용을 바꾸는 변경 하나.
major 아님 — 정체성 다섯이 전부 🟢 도 아니고(블로커는 여전히 ④ 하나), capability **class** 신설도
아니다. **이미 있던 게이트를 조인 것에는 major 를 쓰지 않는다**는 정책 그대로.

> **BREAKING (gate)**: `templates/regression_guard.sh` 가 이제 «0바이트로 비워진 / 내용이 사라진»
> 게이트 경로 자산을 **M-tier 로 막는다**(전에는 통과했다). 처방: 제거가 의도라면 **파일을 지워라**
> — 진짜 삭제는 git 에게 직접 물어(`--diff-filter=D`) 여전히 통과한다. 원래 비어 있던 파일은
> **S-tier 경고**이고 차단하지 않으며, 못 읽는 파일은 **M-tier 계기오류**로 «통과»가 아니다.

#### 🟥 부재-단언 관용구 — 우리 게이트 셋이 같은 얼굴로 뚫려 있었다

`cmd && echo FOUND || echo NOT_FOUND` 계열, 즉 **통과 토큰이 실패 가지에서 생산되는** 형태.
부재를 확인하는 게이트는 «참이기를 가장 바라는» 게이트라 거짓 초록의 피해가 가장 크다.

- `templates/regression_guard.sh` — *삭제* · *0바이트로 비워짐* · *못 읽음* 세 상태가 한 분기로
  접혀 있었고 접힌 방향이 PASS 였다. 실측(일회용 레포, `--staged`, 변수 하나씩):
  컨트롤 = 무해한 추가 → PASS · known-positive = `## Done When` 삭제 → **BLOCK**(계기 판별력 확인)
  · 🟥 **같은 파일 0바이트 → PASS**. 전부 잃었는데 초록이었다.
- `.github/workflows/validate.yml` — `|| true` 가 grep 의 **오류(2)** 를 **무매치(1)** 에 접었다.
  죽은 계기가 「깨끗함」으로 렌더된다. `rc>=2` → `INSTRUMENT ERROR` 로 분리하고, **실제 히트를
  세기 전에** known-positive 컨트롤 픽스처를 먼저 통과시키도록 순서를 고정했다.
- `scripts/mapped_tracks.sh` — 못 읽는 디렉터리가 `count=0` 이 되어 하류가 `skipped` 로 통과.
  `[ -r ] && [ -x ]` 로 분리. 4케이스 표에서 `111` 이 결정적이다(`-x` 만으로는 통과한다).

외부에서 이 부류에 이름을 붙여 준 것은 `Leonxlnx/unlazy` 이슈 #13 의 회신자다.

#### 🟥 인큐베이션 큐가 한글 후보의 절반을 조용히 삼키고 있었다

`scripts/chamber_candidate_collect.sh` 의 `raw 64 → dedup 31` 은 성능이 아니라 **결함**이었다.
`sort -u` 의 UTF-8 collation 이 토큰 8개를 2개로 접었고, 2차 피해가 더 나빴다 — `comm -12` 가
같은 collation 을 쓰므로 **jaccard 의 분자가 토큰이 아니라 collation 을 재고 있었다.**
`LC_ALL=C` + 바이트 기반 awk 토크나이저로 교체(BSD awk · mawk 1.3.4 · gawk 5 에서 바이트 동일 확인).
수리 후 **61**. 삼켜지고 있던 것 중에 정체성 ④ 후보가 있었다.

#### 추가된 게이트·자산

- **caller-zero ratchet** (`scripts/script_caller_ratchet.sh` + `ratchet_base_resolve.sh` +
  `package_coverage_check.sh`, CI 는 `caller-zero-ratchet.yml`) — 호출자 0인 스크립트가 조용히
  느는 것을 막는다. 🟥 **그 게이트 자신이 처음엔 fail-open 이었고**, 그 사실을 함께 기록했다.
- **파괴적-op 훅 CI 상시 재검증** — 훅이 조용히 망가지는 것을 known-pair 로 매 PR 재실행.
- **`scripts/mapped_tracks.sh`** (신규) — 매핑된 필드 하네스 리졸버 + 전용 레인 스위트.
  door ④ Step 3-b 배선.
- **door ④ Step 3-c** — 프런티어 답습 루프 배선.

#### 정정 · 기록

- 🟥 **「`standpoint:` 값을 검증하는 코드가 0줄」은 거짓이었다** — 상주·정본 층 **8자리 / 6파일**
  전수 철회. 실물: `validate_standpoint_leg()` 는 86줄이고 호출되어 커밋을 **차단한다**.
  정확한 잔여는 훨씬 좁다 — enum 은 닫혀 차단하고, `tier2`+ 의 grounds 검사만 advisory 다.
  레포 안에 계수기가 **둘**이었고(FIVE vs 여섯) **둘 다 틀렸다.**
- **`docs/GATE_DAY.md`** (신규, 공개) — 하루치 자기 실측. 게이트가 저자를 **7회** 막았고
  **자력 적발 0**, 여덟 번째는 CI 가 뒤늦게 잡았다(그 자체가 이 레포의 「CI 는 백스톱이지
  발견 수단이 아니다」 위반이다). 어떤 델타도 6축을 전부 태우지 않았다.
- **마감 체인** — 워크트리에서 마감하면 살아있는 peer 를 전원 놓치던 것을 수리.
- **README** — 게이트만 쓸 사람이 4스크롤 뒤에 만나던 답을 첫 화면으로. 첫 줄 =
  *"Quality gates that catch you, not just your agent."* (4개 언어 + 레포 description 통일).
  DOI · `Codex-beta — help validate` 배지 제거.

#### 정직하게 남기는 잔여

- 이 릴리스의 커밋 셋(#511·#512·#513)은 **PR 제목이 전부 동일**하다. 브랜치를 서로 위에 쌓고
  가장 **오래된** 커밋 제목을 집는 스크립트를 쓴 결과다. 내용은 컨트롤과 함께 검증됐고,
  이력 재작성은 금지라 **고치지 않고 적어 둔다.**
- 부재-단언 관용구(N=4)와 built-but-not-wired(N=4) 둘 다 기계화 임계를 넘었으나
  **«무엇을 지을지»가 미정**이다. 투기 빌드를 하지 않는다.

---

### [2.8.0] — 2026-08-22

**자릿수 근거 (minor)**: 새 게이트 레인 · 행동을 바꾸는 교리 · 소비자 install 동작 변경.
major 아님(정체성 다섯이 전부 🟢 도, capability class 신설도 아니다).
**`BREAKING (gate)` 없음** — 새로 등록되는 훅은 `exit 0` 로 끝나는 표면화 훅이고 아무것도 차단하지 않는다.

#### 🟥 install-wizard 가 PriorArt 스니펫을 «항상 조용히 SKIP» 하고 있었다

`templates/settings.PriorArt.snippet.json` 이 형제 스니펫 넷과 달리 `project_settings_json`
래퍼 없이 출하되고 있었고, install-wizard 머지 코드는 그 키가 없으면
`SKIP (no project_settings_json) … continue` 로 건너뛴다.
⇒ **이 훅은 install-wizard 를 돌려도 한 번도 등록된 적이 없었다.**
전수 실측: Compaction·FieldCanon·PreToolUse·SessionStart 래퍼 O · PriorArt 혼자 부재.

**소비자 영향**: 이제 install-wizard 가 이 훅을 실제로 등록한다. 새 메커니즘을 짓기 직전에
「책장 먼저, 없으면 도서관」을 표면화하는 PreToolUse 훅이고, **차단하지 않는다**.

회귀 앵커: `scripts/test_wizard_snippet_merge_lanes.sh` 에 **SHIP-1**(출하 스니펫 전수 스키마,
0개 스캔 시 FAIL — 부재를 통과로 안 렌더) + **SHIP-2**(판별력 컨트롤) 신설. 되돌림 3단 검증됨.

#### door ④ 가 하네스 레벨 이식쌍을 기본값으로 낸다 — Step 3-b

`cross-ecosystem-synergy-detection` 이 «설치된 플러그인/스킬» 층만 냈다. 매핑 트랙 2+ 환경에서
**매핑된 필드 하네스끼리의 거버넌스 이식쌍**을 조건부 기본값으로 낸다. 발화 트리거 4행(단독 호출)
+ Done When 2행(`harness-error` 는 NON-PASS, 세 번째 허용 상태가 아니다).
⚠️ 재발 N=2 로 **이 레포 임계(N≥3) 미달**이며 **운영자 지시로** 기계화했다. 본문에 명시.

#### 「워크트리에서 4축 증거가 구조적으로 부재」 철회

`pre-commit` 이 `--git-common-dir` 로 메인 트리 증거를 잡는다(2026-08-18 수리, 08-22 첫 실사용).
🟥 **운영 규칙은 불변 — 워크트리에서 FH 자산을 커밋하지 않는다.** 남은 것은 성립한 근거가 아니라
열린 위험 영역이고 이유로 열거하지 않는다(초판이 열거했다가 적대검증에서 추가 주장 대부분에 결함).

#### 정체성 ④ 트리거 재정의 (운영자)

「의문 표명」 예시 넷 → **요청·질문·제안 ∧ «조금이라도» 불확실**의 곱. ①은 채널·②는 판정.
결말 셋 신설: **숙고만으로 닫힘** / 책장 / 도서관.

#### 기타

디스패치 원장 3엔트리(66건 무기록 해소) · README 4언어 · `listing_watch.sh` · 3층 정본 ·
`docs/ETHOS.md` (2.7.0 이후 누적).

---

## Plugin Level

### [2.7.0] — 2026-08-21

### 🟥 BREAKING (gate): 2026-08-21 이후 날짜의 마커는 `①영혼` 줄이 없으면 커밋이 막힌다 — 없으면 `soul: 없음` 한 줄로 통과한다

이 필드는 `CLAUDE.md §자기 대조` 가 **2026-08-09 부터 의무**로 정한 것이고, 이 릴리스는 그것을
새로 요구하는 게 아니라 **처음으로 읽는다.** 소급 안 한다(그 날짜 이전 마커는 그대로).
**선언된 부재는 1급 값이다** — `없음`/`none`/`n/a` 는 통과하고, 통과가 아니라 **기록**으로 찍힌다
(`⚠️ ①영혼: 없음 — declared absent. Recorded, not silent.`). 빈 필드만 막힌다.

---

**마커의 `①영혼` 은 6주째 의무였는데, 읽는 코드가 0줄이었다.**

컨트롤 동반 실측: 훅에서 `crossfamily` 는 **21곳**에서 검사되는데 `①영혼`/`soul` 을 읽는 코드는
**0줄**이었고, 게이트 명세(`fh_4axis_gate.md`)는 그 필드 이름조차 안 적는다. 실물 코퍼스에서
**2026-08-10 이후 마커 98건 중 37건(37.8%)** 이 어떤 표기로도 그 줄을 안 갖고 있었다 — 그중
손검증한 하나는 **codex+agy 패널 · 28레인 · controls alive · 나머지 필드 전부 채운** 마커다.
**시킨 축은 다 돌렸고, 아무 기계도 안 읽는 그 한 줄만 없었다.**

- **새 축이 아니다 — ⓒ 격리 그라운딩의 확장이다.** `fh_three_layer_canon.md §1-a-2` 의 판별자는
  «무엇을 받았는가»이고, ⓒ 는 이미 «저자가 쓴 문장 + 지금의 트리» 를 받는다 — 사전 선언 검사의
  입력과 한 글자도 다르지 않다. 시제(사전 선언 ↔ 사후 주장)는 적대성과 같은 **자세**지 축이 아니다.
  🟥 초안은 ⓖ 로 뽑으려 했고 **운영자가 기존 카테고리 검토를 지시해 정정했다** — 그대로 갔으면
  정본 6축·`axes-run` enum·덱 표·마커 190건 재해석이 전부 따라왔을 것이고, 그건 정본 안에 이미
  기록된 오류(저자가 ⓓ에 귀속한 5건 중 3건이 다른 축으로 재분류)의 반복이었다.
- **검사하는 것은 채널뿐이다.** 선언이 있는가(줄머리 키) · 공허하지 않은가 · `soul-check:` 가 닫힌
  enum 인가 · **같은 레코드 안에서 정합적인가**(`reflected` 를 적으려면 그 마커에 실제로 선언이
  있어야 한다). **검사하지 않는 것**: 사전에 썼는가(파일에서 안 갈린다) · 그 판단이 옳은가.
  날조된 `reflected` 는 통과한다 — §4-b(cross-family 가 마커를 읽는다)의 몫이고 여기서 안 닫혔다.
- **검증**: 레인 44개(BLOCK/PASS 양방향 · 실물 코퍼스 known-pair 2쌍) · 되돌림에서 **정확히 대응
  7레인만** 적색 · 격리 클론 실 커밋 2팔(선언 없음 `rc=1` / 있음 `rc=0 ALL AXES PASSED`).
- 🟥 **자력 적발 0 이 14건.** cross-family 2계열 분리 발주(codex=diff 축 / agy=주장 축) 10건 +
  첫실사용 4건, **겹친 지적 0**. 그중 하나는 **사이드카의 수리가 새 fail-open 을 만든 것**이다 —
  넓힌 탐지기가 `soul-check:` 줄 자신의 텍스트를 증거로 잡아 BLOCK 레인이 PASS 로 뒤집혔고
  **레인 41개가 전부 초록이었다.** 잡은 것은 격리 클론 첫실사용이다.

**유출 스캐너가 zsh 에서 죽었고, 그 죽음이 「깨끗함」과 바이트 동일이었다.** (PR #480)

`psa_scan_tagged` 가 `local path` 를 선언하는데 **zsh 에서 `path` 는 `PATH` 와 tied 된 특수
배열**이라 그 스코프의 `PATH` 가 비고 첫 실행문(`input=$(cat)`)부터 죽는다. 계약이
「빈 입력 = `return 0`」이라 **출력이 깨끗한 스캔과 구별되지 않았다.** `/public-surface-audit` 가
한 줄도 안 스캔하고 「유출 없음」을 냈고, 그 스킬은 **Pre-Publish Gate 가 publish 직전에 1번으로
체이닝하는 렌즈**다.

- 훅 경로(`pre-commit`·`pre-push`)는 bash 로 `execve` 되어 **원래 안전했다.** 뚫린 것은
  **에이전트가 Bash 툴로 치는 스킬 본문**이고, macOS 기본 셸이 zsh 라서 난다.
- 수리는 둘이다: **A** 식별자 개명 · **E** `psa_scan_tagged` 진입에 생존성 가드 배선
  (실패 → `rc=3 NOT SCANNED`). 🟥 **A 만으로는 계열이 안 닫힌다** — 같은 형태가 7곳 더 있고 그중
  6곳은 «오늘 안전한데 그건 호출부가 bash 라서»지 코드가 이식성 있어서가 아니다.
  **A 는 이 실례를, E 는 다음 실례를 막는다.**
- ⚠️ **소비자에게 보이는 변화**: 패턴 파일이 **부분만 로드되는** 설치본은 이제 `rc=3`
  (NOT SCANNED)를 받는다 — 전에는 `rc=0`(깨끗)이었다. 방향은 옳지만 **막히는 경우가 늘었다**.
  잘못된 패턴 파일을 쓰던 소비자는 그 사실을 이제 통보받는다.
- **rc 계약 `0 깨끗 · 1 유출 · 3 미측정` 을 1과 3으로 접지 않는다** — 합치면 `PUBLIC_SURFACE_OK=1`
  이 **계기 사망까지 «승인된 유출»로 통과**시킨다. 비가역 표면에서 가장 나쁜 조합이다.
- **소비자 설치본 실측**(리뷰에서 추가): 깨끗한 클론 → `npm pack` → `node_modules` 경로 추출 →
  **스킬 본문 호출 형태 그대로** known-pair. 수리 전 `zsh` 양성 **rc=0 무보고**(유일한 흔적은
  stderr 한 줄) → 수리 후 **rc=1 보고**. bash 팔은 양쪽 불변(컨트롤).

**릴리스 표면 — 두 계보가 한 이름공간을 쓰고 있었다.**

GitHub Releases 가 **v0.3.0(8/16)을 「Latest」로** 보여주는 동안 배포물은 **2.6.0** 이었다. 둘 다
`vX.Y.Z` 를 쓰고 정체성 계보에만 Release 객체가 있었기 때문이다. 🟥 **이건 이 저장소가 자기
게이트에서 반복해 찾아낸 그 결함(두 층·한 이름)이 자기 버전 번호에 난 것이다.**

- **통일하지 않는다** — 두 숫자가 다른 것을 잰다(무엇을 설치하는가 ↔ 얼마나 익었는가). 합치면
  성숙도 신호가 사라지고, **`identity-v1.0.0` = 전정체성 🟢** 라는 마일스톤이 죽는다.
- 이름공간만 가른다: 정체성 계보는 **`identity-v0.4.0` 부터** 접두어를 갖는다. 기존
  `v0.1.0`·`v0.2.0`·`v0.3.0` 은 **개명하지 않는다** — 공개 ref 재작성은 비가역이라
  Destructive-Op 게이트가 우리 자신의 태그에도 적용된다.
- `README §Two version numbers` 신설 ·
  🟥 `v2.6.0` Release 객체를 만들었다가 **같은 시각에 되돌렸다**(운영자 지적) — GitHub 의 «Latest»
  배지는 **슬롯이 하나**라 두 계보가 한 페이지에 있으면 경쟁하고, 배지를 쥔 쪽이 «이 저장소가
  뭐라고 말하는가»를 정한다. 패키지 번호가 표제를 가져가면서 **성숙도 주장이 그 아래로 밀렸다.**
  오독은 더 싼 절반(기존 본문 맨 위 한 줄)이 이미 닫았다. ⇒ **Releases 는 정체성 계보만** 나른다 ·
  `v0.3.0` 본문 **맨 위**에 계보 한 줄(본문 4문단 아래엔 이미 있었다 — **gate-locality**: 읽는
  자리에 없으면 없는 것이다).
- ⚠️ 정본의 stale 하나 같이 정정: `ship_readiness_gate.md` 가 npm 을 *"`1.4.x` range"* 로 적고
  있었다(실제 2.6.0). **산문에 박힌 버전 숫자는 조용히 낡고 사실처럼 읽힌다.**

**사이드카는 감사하지 쓰지 않는다.** (`multi_model_sidecar_strategy.md §Runtime Authority`)

기존 교리는 «사이드카 finding 은 증거 후보이지 판정이 아니다»를 **판정 축**에서만 말했고 **쓰기
축이 비어 있었다.** 실측: 적대 감사자로 발주된 사이드카가 워킹트리를 **직접 편집**했고(`mtime`
으로 적발 — 어떤 게이트도 못 잡았다), 그 수리가 **자기참조 fail-open** 을 새로 만들었다.
🟥 **금지 근거는 「월권」이 아니라 「고친 쪽과 검사하는 쪽이 같아진다」다.**
프로세스 판도 같이 적었다 — 폭주 사이드카를 죽일 때 **자기 프로세스 판별자**(모델 핀·PID·
`pgrep` 선열거)를 갖고 쓰고, **죽인 뒤 무엇이 죽었는지 확인한다**.

**규칙은 세 자리 중 하나에 산다.** (`README §Where a rule lives`)

상주 층이 무한히 자라야만 하는가라는 질문에 대한 답이다. 🟥 **가운데 자리가 보통 비어 있고,
그게 공짜다** — **게이트 자신의 오류 메시지**는 행위자가 **행동하는 순간에** 읽는 자리라 상주
예산을 한 글자도 안 쓴다. 한계도 같이 적었다: **막힐 때만 읽힌다.** 그래서 대체가 아니라 3층이고,
실측이 그 증거다 — 이번 게이트에서 **기계 +480줄, 상주 산문 ±0**.

### 명시 잔여 — 안 닫은 것

- **날조된 `reflected(…)` 는 통과한다.** provenance 는 파일에서 안 갈린다. §4-b 의 몫이다.
- **`①영혼` 소급 안 함** — grace `2026-08-21`, 기존 37건 유지.
- **형제 축 문법 분열**: `standpoint:` 는 근거를 em-dash 로만 받고 `thirdparty:`·`soul-check:` 는
  괄호로 받는다. 같은 훅 안에서 갈리고, 괄호로 쓰면 *"is not a member of the enum"* 이라는
  **오진**을 낸다(값은 멤버가 맞고 문법만 틀렸다).
- **psa 계열 7건이 호출부에 의존해 잠들어 있다** — 「남은 7건」이 아니라 **조건부 활성**이다.
- **`M-1`(상주) · `M-2`(memory) · `M-3`(스킬 활동도)은 안 건드렸다.** 🟥 셋 다 **계기가 미검증**
  이다: 임계 40k·80k·10k **어느 것도 절단점 근거가 없고**(도입 커밋이 축은 20줄 논증하고
  절단점은 한 줄도 안 함, 그리고 도입 당일 대상이 이미 초과였다) · 출하 스캔이 `wc -c`(바이트)를
  **«chars» 라고 라벨**하며(163,456 vs 실제 문자 144,471) · 스킬 활동도 계기가 **언급을 사용으로**
  센다(실행 0인데 «활발» 로 오분류 27종). **재정초 전에 감량하면 근거 없는 목표를 향해 깎는 것**
  이고, 그 절약으로 fail-open 을 산다.

### [2.6.0] — 2026-08-20

**배포본이 소비자 설치에서 `SELFCHECK: FAIL` 이었다 — 그리고 원인 넷이 전부 «계기가 저자의 머신에 결박» 이었다.** 이 릴리스의 중심은 새 기능이 아니라 그 복구다. 발견 경로는 재출하 준비 중의 손 실행이다: `npm pack` → 추출 → **`node_modules/@chrono-meta/fh-gate` 실경로에서 완주**. 레지스트리에서 받은 **실물 2.5.1** 로도 재현했다(컨트롤).

- **위성 레인 둘이 주체 없이 출하됐다.** `test_satellite_publish_gate_lanes.sh`(2.5.1 에 이미 실림) · `test_satellite_profile_schema_lanes.sh`(이번 범위에 추가됨)의 주체는 `frontier_digest_daily.sh` 인데 그건 의도적으로 출하 대상이 아니다(소비자 계정으로 `claude` CLI 를 태운다). 실측: publish_gate **4 passed / 21 failed**, `rc=127`. 🟥 **통과한 쪽이 더 나빴다** — "dispatch 자체가 안 일어남 ✅" 은 러너가 **없어서** 통과한 거짓 초록이다. 선행 사례(`test_frontier_digest_retry.sh`, *"Anchor follows subject"*)대로 `ACCEPTED_ABSENT` 로 내리고, `selfcheck.sh` 는 **주체** 부재를 보고 `_absent_subject_verdict` 로 위임한다 → 이름 있는 SKIP
- **`digest_landing_check --self-test` 가 폴더 이름에 결박돼 있었다.** 컨트롤이 `basename "$FH"` 로 유도되는데 픽스처 카드가 리터럴 `forge-harness` 를 담고 있어, **디렉터리 이름이 `forge-harness` 일 때만** 컨트롤이 살았다. known-pair(같은 바이트, 이름만 교체): `forge-harness/` **15/15 PASS** · `some-consumer-app/` **5/15 FAIL**. 레인별로 컨트롤을 픽스처 토큰에 고정했다. 🟥 «10 을 기대하는» 레인들도 고정했다 — 고정 전에도 10 을 냈지만 **의도한 사유가 아니라 컨트롤 사망** 때문이었다. 🟥 N1·★N-ctl·★N-ctl-re 는 일부러 유도/사망을 주장하므로 **고정하지 않았다**
- **`cluster_capability_scan` L13c — 전제만 결박이었다.** `discover` 가 `tracks/`(gitignored, 배포물에 구조적 부재)를 전제하므로, 부재는 **FAIL 이 아니라 이름 있는 SKIP**(미측정 ≠ 0건)으로 낸다. 🟥 **초판은 여기서 하나를 더 «고쳤고», 그게 틀렸다** — 기대 문자열 `^forge-harness\(hub\)` 를 폴더명 결박으로 읽고 `basename` 유도로 바꿨는데, **생산자(`:128`)는 그 리터럴을 낸다.** 유도로 바꾸면 이름이 다른 트리에서 기대와 산출이 갈려 **거짓 FAIL** 이 된다 — 이 파일이 자기 주석에서 경고하는 divergent-normalizer 를 수리가 새로 만든 꼴이다. 되돌렸다. 그 라벨은 디렉터리 이름이 아니라 **허브의 상수 식별자**이고, 양쪽이 같은 상수를 쓰는 한 결박이 아니다. **cross-family(codex/gpt-5.5)가 잡았다 — 자력 적발 0.** known-pair 로 재현: 이름이 다른 트리 + `tracks/` 존재에서 상수판 **20 PASS / 0 FAIL** · 유도판 **19 PASS / 1 FAIL**. 내 소비자 테스트는 그 팔에 **구조적으로 못 닿았다**(거기선 L13c 가 SKIP 이라)
- **mate 어댑터의 known-pair 픽스처가 안 실렸다.** 게이트는 출하되는데 보정쌍이 소비자 머신에 없어 `HARNESS_ERROR(10)`. `mate_agent_boundary_known_{positive,negative}.md` 를 `files[]` 에 추가 — 이건 **출하하는 쪽**이 맞다(주체가 이미 출하되므로)
- 검증: 수리 후 소비자 설치 **`SELFCHECK: PASS` (rc=0)**. 🟥 중간에 내 계기가 한 번 틀렸다 — `grep '^FAIL'` 로 세어 «FAIL=0 인데 FAIL» 이라는 가짜 모순을 만들었다. 이 스위트들은 `❌` 로 찍는다

**온보딩 메뉴를 세로로 편다.** `·` 로 이어붙인 한 줄 메뉴는 터미널 폭에서 임의로 접혀 문 경계가 안 보인다(운영자 지적). `G-GREET-02`(🐿️+환영문 같은 줄)·`G-GREET-03`(고정 4문)·`G-GREET-05`(문구 리터럴) **셋 다 불변** — 그 프로브들이 박은 것은 문 집합·리터럴·환영문 줄이지 메뉴의 줄 수가 아니다. 플로어 티어 블라인드 sim(레포 밖 cwd·헤드리스·reps=3): **ARM 3/3 세로 · CONTROL 3/3 가로**, 같은 실행에서 G-GREET-02 도 3/3 유지.

**BREAKING 없음 — 그리고 그 판정을 적어둔다.** 카드는 «위성 런이 프로필 미선언이면 막힌다» 를 `BREAKING (gate):` 후보로 올려뒀는데, 그 게이트가 사는 `frontier_digest_daily.sh` 가 **출하 대상이 아니라** 소비자의 게이트 수용은 안 바뀐다. 오늘 수리는 FAIL→PASS 라 완화 방향이다.

🟥 **이 릴리스가 스스로 낸 교훈**: 결함 넷 중 **셋은 진단이 맞았고 하나는 틀렸는데, 틀린 하나를 자력으로는 못 잡았다.** 소비자-설치 완주라는 계기는 「돌아가나」를 재지 「고친 게 옳은가」를 못 잰다 — SKIP 으로 빠지는 팔은 그 계기가 구조적으로 안 보는 자리다. 잡은 것은 **다른 계열에 diff 를 보낸 것**이다.

**같은 릴리스에 함께 나가는 것 — `harness-doctor` 30일 캐던스 수리 (#468).** 진단이 낸 것 중 **지금 출하물에 살아 있던 것**만 골랐다.
- **팬텀 「500줄 / 16스킬」 임계 제거** (`docs/platform_sustainability.md`, 이번에 출하 대상에 편입). 실제는 1,414줄 / 40스킬이고, `harness-doctor` 는 meta 타깃에서 줄수 행을 «판정 아님»으로 **비활성화**하지 큰 숫자로 갈지 않는다. 🟥 덤이 본체보다 컸다 — 이 팬텀의 사후분석이 *"`500` 은 이 파일 어디에도 없다(grep 0 hits)"* → «런이 지어냈다» 로 결론냈는데 **그 grep 이 자기 파일만 봤다.** 교훈은 «환각했다»가 아니라 **«부재 검사를 틀린 코퍼스에 돌렸다»**
- **CATALOG 미등재 정본 7건 등재** (컨트롤 `harness_6axis_framework`=2, 대상 7건 전부 0). 그중 `fh_three_layer_canon.md` 는 CLAUDE.md 가 **필독**으로 지정한 문서다 — 색인이 못 찾는 필수 문서는 파일명을 이미 아는 세션이 아닌 한 부재와 구별되지 않는다
- **`[[wikilink]]` 규약 선언** (`knowledge/shared/GLOSSARY.md` 신설 절). 출하 `.md` 156개에 안 풀리는 타깃 **59 / 출현 98**, 선언이 아무 데도 없었다. 🟥 이건 **깨진 참조가 아니라 출처 표시**다 — 고치려 들지 마라. 메모리 스토어는 운영자별·세션 스코프라 vendoring 은 수리가 아니라 residency 위반이다
- 🟥 **`CLAUDE.md` 가 자기 기계를 거짓 서술하고 있었다.** *"standpoint 는 Prose-only today — 검증하는 pre-commit 훅도 픽스처도 없다"* → `validate_standpoint_leg()` 는 `pre-commit:798` 정의 · `:1575` 호출이고 `test_marker_standpoint_lanes.sh` 는 `selfcheck.sh:531` 배선이다. **같은 파일이 정반대도 적고 있었다.** 이 계열은 레인이 구조적으로 못 잡는다 — 규칙의 **자기서술**을 그 규칙이 서술하는 **기계**와 대조하는 검사가 없다. 그리고 stale 한 «아직 안 지었다» 는 가장 조용한 드리프트다: 정직한 겸손처럼 읽히면서 **이미 있는 컨트롤의 사용을 억제한다**
- **M-1(상주 140k)은 안 닫았다.** 상주 원장 32절 전수 결과 **M·S·R 전부 0** — 절 단위 레버가 없다는 것이 실측이다. 유일한 레버는 capability-level merge(후보 6묶음)이고, **그 병합이 실제로 문자를 줄이는지는 UNMEASURED**

**명시 잔여**: `package_coverage_check.sh` 는 「참조된 경로가 출하되나」를 보지 「**출하된 레인의 주체가 출하되나**」를 안 본다 — 네 결함 중 셋을 rc=0 으로 통과시켰다. 그 갭은 이번에 안 닫았다.

### [2.5.1] — 2026-08-19

**진입점 패리티 — 규칙이 출하돼야 발화한다.** 2.5.0 직후 `④-b` 드리프트 검사가 **AGENTS.md 에 공유 체크아웃 규율이 없다**를 냈다. CLAUDE.md 에는 있고 Codex 진입점에는 없는 상태였고, 그 상태에서는 비-Claude 런타임에 그 규칙이 **보이지 않는다**(gate-locality). 이 릴리스는 그 한 항목을 소비자에게 실제로 보내기 위한 것이다.

- **`AGENTS.md` 항목 9 — 공유 체크아웃**: 스위치 전 `git branch --show-current` · 자른 직후 `git log main..HEAD` · **claim 파일은 lock 이 아니라 스냅샷**(남이 브랜치를 옮겨도 안 바뀐다) · 공유 체크아웃에서 `git add -A`/`git stash` 는 트리 전체에 닿는다. 🟥 이 레포에서 두 세션이 오늘 실제로 그걸로 부딪혔다. 기계층(`pre-commit` 의 `branch_claim` 게이트)은 **커밋 시점**이라 그 앞의 `git switch` 사고는 못 막는다
- 검증: 플로어 티어 블라인드 sim(무엇을 시험하는지 안 알림, reps=3) **arm 3/3 vs control 0/3**. 🟥 control 한 런이 죽어 있어(stdin 경고만) 재실행해 유효 3수를 채웠다 — 죽은 팔을 0 으로 계상하면 n 을 부풀린다
- 🟥 **잔여: 비-Claude 런타임에서 실제로 안 돌렸다.** sim 은 Claude 로 돌렸다 — 「따라와지는가」는 쟀고 「Codex 가 실제로 그렇게 하는가」는 못 쟀다

**함께 나가는 것 (데이터)**: `subagent_invocations_log.yaml` 3건 — 게시 전 보안 패스 · cross-family 패널 · **ⓓ 3자대면**. 마지막 것이 위성 설계에서 **미등록 redaction sink**(입력 무검사)와 **레포 밖 폭발반경**을 찾았고, 처방 5건은 **전부 미착수**다(`tracks/` 신호에 기록, 출하 대상 아님).

**BREAKING 없음.** 문서·데이터만이고 게이트 수용은 안 바뀐다.

### [2.5.0] — 2026-08-18

**정체성 ④(프런티어→조직 전파)의 «조직 = 레포» 축.** 다이제스트 러너가 FH 한 곳만 대상으로 지어져 있어 ④ 가 «자기 소비» 에 머물렀다. 대상 축을 열고, 그 산출이 **복제가 아니라 응용**이 되도록 프로필을 싣고, 공개 표면과 착지를 각각 기계로 잰다.

**위성 — `scripts/frontier_digest_daily.sh`**
- `FD_OUT_DIR`(대상 레포의 어디에) · `FD_MODEL`(위성별 티어 핀)
- `FD_PROFILE` — 대상 하네스가 **자기를 설명하는 파일**을 프롬프트에 싣는다. 🟥 없으면 산출은 **복제**다(실측: 대상 어휘 0 · FH 어휘 11 · Route 0). 있으면 **응용**(실측 2대상: 대상 어휘 0→33 · **Route 0→19**). **변인은 프로필 하나였다**
- `publish_gate()` — 공개 레포 대상이면 **매 런이 publish** 다(비가역). `0 게시 / 1 격리 / 그 외 보류` — 🟥 **세 값을 두 값으로 접지 않는다**
- `landing_witness()` — 직전 다이제스트 후보의 착지를 매일 기록. 차단하지 않는다(선별기). 프로덕션 호출부 **0 → 3**
- 앵커: `scripts/test_satellite_publish_gate_lanes.sh` (초판 **11 레인**, 아래 후속 수리로 **22 레인**), 되돌림 다중 arm

**착지 검증기 파서 — `scripts/digest_landing_check.sh`**
- 후보를 **표로만** 읽고 있었다. 실측 60건 중 표는 **4건(6.7%)**. 문단·헤딩·번호 리스트를 더해 **후보 절이 있는 56건 전부** 추출. 판별자 추출은 두 경로가 **공유**(중복 정규화기 방지)
- 🟥 이 결함은 **호출부가 0 이라 가려져 있었다.** 배선해서 처음 돌린 그 실행이 뱉었다 ⇒ **self-test 만 도는 스크립트는 실물과 어긋나 있어도 초록이다**

**규율 — `CLAUDE.md`**
- **§Expedition**: 원정 개시에 **«과녁 정체성» 한 줄** 의무. 근거는 1차 ⓐ 채점 **0건**이고 원인이 노력이 아니라 **겨냥**이었다(세 갈래가 전부 이미 🟢 인 정체성 위에 떨어졌다). 주기는 2차 이후로 연기, **계측 3항을 방법까지** 명시(거버너 토큰은 `UNMEASURED` 를 이름으로 남기고 **합계 금지**)
- **§AI Contribution Model**: 기본 워크플로에 **claim** 단계 + `scripts/branch_claim.sh` 를 이름으로. 기계는 이미 있었는데 산문이 그 이름을 안 불러 두 세션이 «없다»로 결론했다

**게이트 (peer 동시 착지분 #447·#448)**
```
BREAKING (gate): edit_manifest.yaml 에 `date` 만 있는 엔트리가 있으면 커밋이 차단된다
  — 동시 append 로 손상된 매니페스트의 지문이다(종전엔 무음 통과).
  remedy: 훅이 지목한 엔트리를 손으로 확인해 필드를 복구하거나 제거한다.
```
실측: 이 레포 매니페스트 411건 중 date-only **0건** — **건강한 매니페스트를 가진 소비자는 안 막힌다.** 막히는 것은 동시 append 로 손상된 경우이고, 그 손상은 종전에 **조용히 통과**했다.

**동작 변경(차단 아님)**: 워크트리에서 FH 자산 커밋이 **가능해진다**(evidence-root 를 `--git-common-dir` 로 해석). 종전엔 `tracks/` 가 안 따라와 Axis 2+3·Axis 4 가 구조적으로 부재했다 — 즉 이 항목은 **완화**다.
> 🟥 **정정 (2026-08-22) — 위 줄을 「워크트리에서 커밋해도 된다」로 읽지 마라.** 기술적으로 *가능해진* 것은 맞으나, **운영 규칙은 여전히 «워크트리에서 FH 자산을 커밋하지 않는다»** 이다(`CLAUDE.md §Agent Dispatch Operation`). 이 항목이 없앤 것은 «증거에 도달 못 한다»는 **우연한 장벽** 하나뿐이고, 마커 provenance·동시 append 같은 남은 근거는 그대로다. 이 줄이 없으면 소비자는 출하 문서에서 내부 규칙과 반대되는 지시를 읽는다.
⚠️ **위 둘은 같은 사건의 앞뒤다.** 경로 변경으로 워크트리 소비자에게 게이트가 **처음 도달**하는데, 그 순간 `core.hooksPath` 가 **상대 경로**면 워크트리가 **자기 훅 사본**을 돌아 자기무력화가 가능하다.
권고: `git config core.hooksPath "$(git rev-parse --show-toplevel)/templates/.git-hooks"`

**같은 날 후속 수리 — 위 배선이 만든 결함 5 + 타계열 3 (#452)**
🟥 위 항목들을 「배선 완료」로 보고한 뒤 **되돌림 프로브·첫 실사용·타계열 패널**이 다음을 찾았다.
- **착지 증언이 배선 첫날부터 죽어 있었다** — 러너가 checker 에 **디렉터리를 «타깃 파일»로** 넘겨 매 런 `rc=10`. 손으로 잰 형태(1인자)와 러너가 부르는 형태(2인자)가 달랐다. 컨트롤 토큰도 하드코딩이라 대상 레포에선 고쳐도 죽은 채였다 ⇒ 스코프·컨트롤을 `DLC_*` 로 외부화, 유도 기본값은 **리터럴**(레포명에 정규식 메타문자가 있으면 «아무거나 매치»했다)
- **「직전 다이제스트」를 로케일 `sort` 로 골라 두 달 전 파일을 집었다** — 실물 코퍼스에 `2026-06-02`(대시)와 `2026_08_17`(언더바)가 섞여 있다 ⇒ `LC_ALL=C`. 🟥 **이건 레인이 아니라 첫 실사용이 잡았다**(그 시점 레인 21개는 전부 초록)
- **`publish_gate` 가 `head -1` 로 한 파일만 스캔**했고, 선택자가 `digest_ready` 와 갈려 있었다 ⇒ 단일 선택자 + 전 파일 순회 + 최악값. 선택자 자기모순은 **게시가 아니라 보류(3)**
- **공개 대상 트리 «안»에 로그를 팠고 findings 가 토큰 원문을 찍었다** ⇒ 트리 밖 + 리댁션 3단(인용 스팬·row 꼬리·경로). ⚠️ **이 러너는 출하 대상이 아니므로 npm 소비자에겐 해당 없다** — 러너를 복사해 쓰는 위성에서만 참이다
- **`pre-commit` 이 gitignored 패턴 오버라이드를 `REPO_ROOT` 에서만 찾았다** ⇒ `EVIDENCE_ROOT` 우선 + 폴백. **이건 출하된다.** 종전엔 워크트리 커밋이 매번 defaults-only 로 돌아 회사명·실명 클래스가 UNSCANNED 였고, 게다가 비차단 경고라 조용했다. ⓑ #448 의 반쪽-픽스였다
- **훅 주석 정정**: «절대 hooksPath 면 자기무력화가 **구조적으로 막힌다**» 는 과대주장 — 훅이 `$REPO_ROOT/scripts/*` 를 source 하므로 «한 겹 좁아진다» 가 정확하다
- 🟥 **셸 에러가 착지율 시계열에 «실측값»으로 들어갔다** (첫 실사용 발견). `set -u` + bash 3.2 에서 **빈 배열의 `${a[@]}` 는 unbound 에러**다. 대상 레포에 digest 이후 커밋이 없으면 타깃이 0건이 되고, 그러면 필터 루프가 터져 스크립트가 **판정을 인쇄하지 못한 채 rc=1** 로 끝난다 — 러너는 그 1 을 「SOME-UNLANDED」로 적는다. 올바른 값은 **rc=10(타깃 0건 = HARNESS-ERROR)**. 실측: forge-wiki 첫 런 로그가 정확히 그 형태였고 본문이 비어 있었다
- 🟥 **엔진 루트 ≠ 대상 루트** (첫 실사용 발견). 위성은 이 러너를 복사하지 않고 FH 의 것을 그대로 도는데(launchd 가 FH 경로를 가리킨다), 초판은 스캐너·패턴·checker 를 전부 `$FH_DIR`(=**대상 레포**)에서 찾았다 ⇒ 대상에 `scripts/psa_scan_lib.sh` 가 없으니 **publish gate 가 영영 fail-closed**. 게다가 그 분기는 파일을 **격리하지 않아** 「게시 안 함」이 **거짓**이었다(digest 는 이미 트리에 쓰여 있다). ⇒ 도구는 `ENGINE_DIR`, 대상만 env. 부재 분기도 실제 격리
- 🟥 **게시 직전 보안 패스가 신설 레인 2개에서 실 결함을 냈다**(MED·재현됨): 고정 `/tmp` 경로(`/tmp/.r4out` · `/tmp/.lw_*` · `/tmp/.lg_*`)라 공유 `/tmp` 에서 **심볼릭 링크 선점으로 임의 파일이 덮인다**(CWE-377). 이 스위트들은 **출하되고** `selfcheck.sh` 에 배선돼 있어 소비자가 셀프체크만 돌려도 발동했다 ⇒ `mktemp` + `trap` 정리. 재현으로 확인: 링크를 걸고 돌려도 피해 파일이 그대로다
- 앵커: 위성 **25 레인** · 착지 self-test **13 레인** · **`test_evidence_root_psa_lanes.sh` 신설 5 레인**(이 경로엔 앵커가 0개였다) · 착지 self-test 12. 되돌림 **8/8 이 각각 그 레인만** 적색

**호환성 — 위성 축은 BREAKING 아님.** 미설정 시 **종전 동작 그대로**이고(`N1`/`N3` 컨트롤이 그것을 주장), FH 자신의 일일 런은 무변경이다. ⚠️ `frontier_digest_daily.sh` 는 **출하 대상이 아니다**(종전 동일 — 출하되는 것은 `frontier_digest_autopilot.sh`).

**위성 주기 (2026-08-18 신설)**: `launchd` 2대 등록 — `com.forge-harness.satellite-forge-wiki`(10:00) · `satellite-the-bible`(11:00). FH 자신(09:00)과 시차를 둔다. 🟥 **엔진은 FH 에 있고 대상만 환경변수로 바뀐다** — 러너를 대상 레포에 복사하지 않는다(그게 복제다).

### [2.4.0] — 2026-08-18

🟥 **BREAKING (gate) ①**: the Axes 2–3 marker's **`standpoint:` and `thirdparty:` fields are now
validated by value**, not merely by presence (`validate_standpoint_leg` / `validate_thirdparty_leg`
in `templates/.git-hooks/pre-commit`). A marker carrying free prose where the closed enum is
required, a degrade value with **no substantive grounds on the same line**, or **more than one**
line of either field, now **blocks the commit**.
- **Remedy**: use the enum. `standpoint: tier1b(<harness>) — <what you read>` ·
  `standpoint: not-applicable — <what you checked to conclude no target exists>` ·
  `thirdparty: checked(<what prior art you searched>)`. The hook prints the accepted forms.
- **Why**: presence-only checking catches silence but not a **confident wrong answer** — measured on
  the marker corpus, 4 markers used the enum correctly while **2 wrote free prose about peer-session
  contact** and matched no enum member at all (the field-canon failure this repo already names:
  normalizing a harness term into a general concept).

🟥 **BREAKING (gate) ②**: **Axis 1 (`regression-guard.yml`) had never actually run** — an
instrument error was rendering **green**. It now runs, so a repo whose Axis 1 check was
"passing" may go **red on its first real execution**.
- **Remedy**: read the actual guard output; the failures it now reports were always there.
- **Why**: the sample was 5/5 instrument-errors-as-green. A check that cannot fail is not a check.

🟥 **BREAKING (gate) ③**: `scripts/selfcheck.sh` now executes **`test_target_freeze_lanes.sh`**
(28 lanes) as part of the standard run. A consumer whose `selfcheck` was green may see new output,
and a genuinely broken environment (no `shasum`/`sha256sum`) now surfaces there instead of silently.
- **Remedy**: the lanes are self-contained (`mktemp` fixtures, no network). A missing hash tool is a
  real finding, not a lane defect — the gate it anchors fails closed without one.
- **Why**: `lane-runner` flagged the suite as having **no runner** — *"a suite nothing executes is
  prose."* The author of the lanes had not wired them.

**Added**
- `scripts/target_freeze.sh` + `scripts/test_target_freeze_lanes.sh` — **audit target freeze**.
  Pin a target repo's content-addressed fingerprint before dispatching an audit; verify on return;
  `WRONG-TARGET` (rc 1) invalidates that round's verdict wholesale. Third mechanization attempt,
  deliberately routed **around** the two failures recorded in `steel-quench/SKILL.md` (a hook
  advisory that fired on 100% of markers; a `base-SHA + diff-line-count` fingerprint invariant under
  in-place edits and blind to untracked files).
  🟥 **Cross-family review found 3 fail-open paths while its lanes were 11/11 green** — `_sha`
  losing `shasum`'s rc through `| awk`, `git ls-files -o` failure swallowed by a pipeline, and a
  label-sanitizing collision that returned `MATCH` for a label **never pinned**. All reproduced by
  hand, all fixed, lanes 11 → 28.
- `④ promotion-criteria` section in the identity gate (its absence was itself the first finding).
- Incubator routing: `net-new` failure now routes to **`CURATED`** (hand the maker the prior-art
  list and the delta it does not cover) instead of `KILL`; judgment-shaped candidates route to
  `NOT-APPLICABLE`. KILL survives for measured precision-shortfall, hub-state dependence, and
  inability-to-run.

**Fixed**
- `relay_channel` registration-time checker had a **0-line call site** — the gate existed as 42KB
  of code that nothing invoked.
- `standpoint: §7` closed its `not-applicable` definition (`Q0` target-class resolution, which can
  return **more than one** target, each owing its own tier).
- `mate-agent-boundary` adapter: its **calibration pair was dead** — the peer entry point hardcodes
  its target and ignores `$1`, so the positive and negative arms were measuring **the same file**.
  The negative arm's green was not discrimination; the live target simply happened to be failing.
- `package.json files[]` omitted two scripts that shipped documentation instructs consumers to run
  (a phantom pointer inside a gate instruction).

### [2.3.0] — 2026-08-17

🟥 **BREAKING (gate) ①**: the capability effect-probe (`M6`) now watches **directory existence and
non-regular nodes**, not files only. A `.cap` declaring `writes: read-only` whose entry point
creates an **empty directory**, a **symlink**, or a **fifo/socket/device node** now returns
`VIOLATION` where it previously returned `✅ VERIFIED`. Registration of such a capability
**blocks**.
- **Remedy**: declare the real value (`write-local` / `write-remote`), or stop creating the node.
  The probe prints which surface changed.
- **Why**: `_snapshot()` used `find -type f`, so **empty directories were invisible** — git does not
  track them, so they are absent from the isolated-clone sandbox too. Measured with a 3-arm
  known-pair: write-file-to-new-path → 1, write-file-to-existing-dir → 1, **empty-dirs-only → 0**
  (the false green). A cross-family review then found the same class still open one layer down:
  `ln -sf /etc/passwd link` and `mkfifo pipe` **also passed** after the directory axis was added.
  Both are now caught; symlinks are compared **by target**, since existence alone makes
  `ln -sf other link` look like no change.
- ⚠️ **Named residual, unchanged**: metadata-only writes (`chmod`, xattr, hardlink topology) and
  empty directories **under `.git`** remain invisible. And the probe **still cannot discriminate an
  adapter-class capability** — its outside-watch is a temp canary plus `$HOME`, while an adapter by
  definition runs in the peer tree. That value stands on hand measurement, not on the probe.

🟥 **BREAKING (gate) ②**: writing `ⓓ=→thirdparty` in the Axes 2–3 marker now **requires a non-empty
`thirdparty:` line**. A marker with the pointer but no target **blocks the commit**.
- **Remedy**: the hook prints the accepted forms —
  `checked(<what was surveyed>)` · `none-found(<what was searched>)` · `UNKNOWN` · `not-applicable`.
- **Why**: a pointer at nothing is not a record. Same failure the `ⓑ=→standpoint` guard closed.

**Added**
- `adapter/qasp-web-rules` — a cluster node wrapping a peer harness's web selector-stability rule
  set. Enum `0=CLEAN 1=FINDINGS 2=ARGS 3=ENGINE_ERROR 10=HARNESS_ERROR 20=PEER_ABSENT`, calibration
  pair from **FH-owned fixtures** (offline, deterministic), `writes: write-local` established by
  cold-clone measurement. Registration bar M1–M6: **REGISTRABLE**.
  🟥 **Consumer 0** — declared and callable, nothing calls it yet. Do not round that to "wired".
  🟥 The declared enum is **wider than the peer's documented contract** (`0/1/3`): the underlying
  CLI uses `parser.error()`, argparse exits **2**, and the shell wrapper propagates it verbatim.
  The adapter declares the **real** contract, or an argument mistake renders as "the instrument broke".

**Fixed**
- The adapter's argument validation now runs **before** peer resolution. Previously the **same bad
  call returned different values on different machines** — `ARGS(2)` where the peer was installed,
  `HARNESS_ERROR(10)` where it was not — i.e. the check measured **what is installed on this box**
  rather than **how it was called**. `ARGS` is a statement about the call; `PEER_ABSENT` is a
  statement about the cluster; the two are independent facts.
- Capability entry points and their calibration fixtures are now in `files[]`. Consumers previously
  received the **declaration without the instrument** — a `.cap` that passes the registration bar
  and then returns `HARNESS_ERROR` inside the tarball.

**Note for consumers of the effect-probe**
If you hold `.cap` files, re-run the probe **before** upgrading: this release changes verdicts for
the three shapes above. A green result under 2.2.0 is not evidence under 2.3.0.

---

### [2.2.0] — 2026-08-17

🟥 **BREAKING (gate)**: chamber step 6 now reads `ACTUAL.md`, **not `BUDGET.md`**. An in-flight
chamber run whose actual cost was written into `BUDGET.md` will **block at step 6** until the value
moves to a new `ACTUAL.md` in the same workspace.
- **Remedy**: the runner prints the exact path when it blocks — move the `ACTUAL:` line to
  `tracks/_chamber/<slug>/ACTUAL.md`. `BUDGET.md` keeps `ESTIMATE:` only.
- **Why**: `BUDGET.md`'s pre-verdict hash IS the ordering witness (`ship_readiness_gate §② P1`), and
  step 6 was hard-blocking until that same file changed. So **every run that reached COMPLETE
  necessarily mutated a witnessed artifact** and `verify` returned `TAMPERED` — identity ②'s only
  promotion condition was unsatisfiable by construction, not by strictness. Measured on chamber run
  #11, the first run ever taken through step 7. Two roles (immutable witness / post-verdict
  calibration sink) had collided in one file; each was correct alone, so neither side's code showed
  the conflict.

**Added**
- `scripts/ko_tech_writer_calibrate.py` + `scripts/test_ko_tech_writer_lanes.sh` + two known-pair
  fixtures — the discrimination of `ko-tech-writer` Step 2 (five translationese classes) and
  Step 4-b (universal-claim candidates) is now **reproducible**: positive ≥1 / negative 0 per class,
  plus two META controls. Wired into `selfcheck.sh` and shipped in `files[]`.
  🟥 **What this does NOT prove**: "zero residue" in any real document. Discrimination and residue
  are different propositions; the suite prints that warning itself.
- Chamber lane suite **12 → 33 lanes**, including the **runner × witness seam** that no test covered
  (the runner's lanes excluded the witness by design; the witness self-test ran it standalone).

**Changed**
- `chamber_run.sh` now teaches the **two-commit discipline** where the actor reads it: gate hashes
  and the verdict hash must land in **separate commits** (and, for a squash-merge repo, **separate
  PRs**). Committing them together yields `UNORDERED` — the runner previously advised the opposite.
- `chamber_witness.sh do_record` skips a byte-identical re-record of the same
  `(run, artifact, sha)` triple. A **changed** artifact still appends — that is the tamper evidence.

**Fixed**
- `harness_terminal_correlation_and_recommendations.md` Appendix: Step 2 / Step 4 rows move from
  🟥 `UNCALIBRATED` to 🟡 **partially resolved**, with the reproduction command recorded. The
  original claims ("zero residue" in that document; Step 4's numeric extraction half) remain
  **unverified and are labelled as such**.

**Known residual (not closed)**
- Identity ② stays **RC**. No run has yet been `WITNESSED` on `main`; the two-PR prescription is
  reasoned from the verify logic, and its efficacy is provable only by the next EMIT run.
- `--delete-branch` still orphans ordering evidence — warned in prose, not blocked.
- Of Step 2's five "machine-detectable" classes, only two ship an actual grep in `SKILL.md`; the
  calibration surfaced that the doc over-claims. C4's pattern is a closed noun list with **low recall**.

### [2.1.0] — 2026-08-17

🟥 **BREAKING (gate)**: `crossfamily: declined` in an Axes 2-3 marker now requires grounds naming a
record path that **resolves on disk**. Bare `declined`, and `declined` justified by author judgment,
are **blocked at commit**.
- **Remedy**: cite where the operator decision lives — e.g.
  `crossfamily: declined — operator declined sidecars, per knowledge/shared/rules/operational_adaptation.md`
- **Or use the value that describes what actually happened**: if a panel was reachable and you chose
  not to recruit it, that is `DEGRADED_PANEL_UNUSED`, not `declined`.
- **Why**: `declined` was the only value in the enum with no grounds requirement, so an author
  judgment flowed into the nearest permissive token and passed clean. A cross-family review then
  broke the first (vocabulary-grep) fix three ways — self-validating on the value's own token,
  vacuous keyword passes, and over-blocking genuine declinations phrased in natural prose — so the
  check asserts a **resolvable record** rather than words. It proves a cited record EXISTS, not that
  it says what is claimed; that residual is the marker's own declared scope, stated in the code.

**Added**
- `standpoint:` gains **`tier1b`** (a STATIC read of a target repo — executed nothing) plus a
  decide-in-order procedure, after blind floor-tier sims graded pure cold-reads as `tier2` for three
  rounds, defeating three separate rewordings via the enum's own internal logic.
  🟥 **[RETRACTED 2026-08-17, noted here 2026-08-30]** — that sim result is withdrawn: the runs had
  `tool_uses: 0`, so the agents never opened a file and the grades measure nothing. The live re-run
  landed the **opposite** result at reps=1, below this repo's own bar — so neither direction is
  established. **The `tier1b` rung itself stands** on its own wording (a read that executed nothing
  is not `tier2`), not on this measurement. Canon: `CLAUDE.md` §Skeleton-Not-Muscle ·
  `field_verdict_crossfamily_gate.md:310`. The sentence above is kept rather than deleted so the
  citation stays traceable.
- steel-quench Wave 1's sixth angle (**gate-locality**) gains the output-template row it never had —
  a mandatory angle that was structurally unreportable. Gate-locality failing its own check.
- `verify-bidirectional` category 5 — **prescriptive doctrine statement**, the operator-correction
  shape that fell between its doubt-shaped triggers and its "simple correction, no review" exception.
- Sister Asset Protocol gains an **active-adoption** condition — all four prior conditions were
  passive discovery, so installing an external framework and running it against our own asset
  matched none of them.
- Resident doctrine: **Mechanization Boundary** (machinery at irreversible edges and channels;
  judgment left to evolution) · **Local Execution First** (CI is a backstop, never the discovery
  mechanism) · **Skeleton-not-Muscle** (a wiring change is done when the floor tier executes it) ·
  **Expedition** track · **this package's versioning policy** (major reserved for built-anew /
  identity-established / capability-class change — never for tightening an existing gate).

**Fixed**
- `fh-gate.sh` survives a missing or unreadable `package.json`; `selfcheck.sh` decides npm-surface
  applicability at the call site.
- `capability_registry_check.sh` M3 basename-token matching (a path containing "claude" was silently
  rejected) + a stdin channel for calibration arms.
- `subagent-tally-hook.json` root resolution is 3-tier, matching the convention the sibling
  `SessionStart` hook already used.

---

### [2.0.1] — 2026-08-16

- **feat(cadence)**: `harness-doctor` 30일 캐던스가 산문 제안에서 SessionStart 훅으로 승격 —
  초과 상태가 더 이상 침묵으로 렌더되지 않는다.
- **feat(portability)**: BSD/GNU·zsh/bash 패턴 denylist 린트를 pre-commit에 배선 —
  `degrade_direction_scan` 옆 셸 레이어 자매 레인, advisory(비차단).
- **fix(branch-claim)**: `branch_claim.sh show`가 live claim 수를 실제 동시편집 스레드 수처럼
  오독시키는 문제 — 헤더 주석 + 출력 자체에 경계선 명시.
- **fix(confidentiality)**: `.public-surface-patterns`(operator override) 부재 시 fail-open
  경고가 두 줄짜리 아쉬운 존재였던 것을 놓칠 수 없는 배너로 — 방향(PASS)은 그대로, 가시성만.
- **fix(fh-gate)**: `package.json` 부재 시 `set -euo pipefail` 아래서 즉사하던 결함 수리 —
  known-pair 확정(수정본 rc=12 / package.json 있으면 rc=12 / HEAD 사본 rc=1).
- **feat(cluster)**: 정체성 ① 하네스 클러스터 🔵→🟢 — 기준을 dominance에서 재정의된 ⓐⓑⓒ로
  교체(운영자 결정). 크로스하네스 어댑터 + `relay_channel.sh --cap-args` 노드별 인자 채널.
  잔여 명시: (d) 등록 바가 선언의 진위를 검증하지 못하는 구조는 안 닫힘 — 별도 항목 추적.
- **docs(canon)**: 6축 검증 정본(§1-a-2) 표기가 파일 내 두 자리에서 어긋나 있던 것 동기화.

### [2.0.0] — 2026-08-16

**BREAKING — M6 로 인해 종전 통과하던 capability 등록이 거부될 수 있다. 그리고 그 M6 는 1.4.99 에서 출하되지 않았다.**

- 🔴 **BREAKING: `capability_registry_check.sh` 에 M6(선언 진위 관측)가 실제로 도달한다.**
  M1–M5 를 전부 통과하던 capfile 이 `writes:` 선언과 실제 부작용이 다르면 이제 **REJECTED** 된다.
  major 인 이유는 이것 하나다 — 소비자의 초록이 빨강이 될 수 있다. `^1.4.x` 범위가 이 변경을 자동
  수용하지 않도록 minor 가 아니라 major 로 낸다. 🟥 **M6 를 opt-in 으로 낮추는 선택지는 거부했다**:
  비가역 표면(등록 → 이후 자동 호출)의 fail-closed 축을 끌 수 있게 만들면 그건 floor 가 아니다.
- 🔴 **fix: `scripts/capability_effect_probe.sh` 가 `files[]` 에 없어 출하되지 않았다.**
  M6 를 배선한 커밋(`a48e644`)이 그 M6 가 호출하는 프로브를 출하 목록에 넣지 않았다. 실측 결과
  1.4.99 tarball 의 `capability_registry_check.sh` 에는 **M6 가 0회** 등장한다 — 소비자는 깨진 M6 가
  아니라 **M6 자체를 못 받았다**(출하본이 main 보다 뒤처져 있었다). 고치지 않고 재출하했다면 그때
  프로브 부재 → fail-closed → **모든 등록 거부**가 됐다.
- **feat: 형제 의존 출하 검사** — `test_capability_entrypoint_shipping.sh` 가 세 번째 방향을 얻었다.
  출하되는 셸 스크립트가 `${0%/*}/x.sh` 형태로 부르는 **형제 파일**도 `files[]` 에 있어야 한다.
  기존 두 방향은 `*_capability.sh` **진입점 규약**에만 걸려 있어 이번 결함에 구조적으로 눈이 멀었고,
  `package_coverage_check.sh` 는 참조 정규식이 `scripts/` 로 **시작하는 리터럴**만 봐서 런타임에
  조립되는 경로를 볼 수 없다. 이 클래스의 4번째 발생이라 앞단에 기계로 세웠다.
- **fix: script-dir 해석이 symlink 를 통과한다** — `${0%/*}` 는 심링크 경유 호출에서 링크의
  디렉토리를 가리켜 M6 가 «프로브 부재» 로 fail-closed 했다(있는데 없다고 말한다). `BASH_SOURCE` +
  symlink 해소로 교체.
- **feat: publish 신선도 게이트** — `prepublishOnly` 가 «출하 트리가 커밋된 main 인가» 를 본다.
  이번 사고와 2026-08-13 의 «남의 미커밋 초안 출하» 가 같은 표면의 두 발생이다.
- **fix: `sync-to-be.sh` 락 경합 경로가 rc=64 로 죽었다** — `log()` 가 호출부보다 아래에 정의돼
  macOS `/usr/bin/log` 로 떨어졌고, `set -euo pipefail` 이 의도한 `exit 0` 도착 전에 스크립트를
  죽였다. 경합 경로는 **경합할 때만** 실행되므로 병렬 세션 둘이 붙기 전까지 출하된 채로 있었다.

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
- **라운드 3 이 또 두 건을 깎았고 하나는 내가 만든 A급이었다** — 첫 수리가 `tr -d '[:space:]'` 로
  이름의 **모든 공백을 삭제**해서 `--require-class 'repo-freshness-auto pull'` 이 실제 클래스로 접혀
  **다른 이름을 물었는데 다른 클래스의 판정을 받았다**(신원 붕괴). 지금은 **트림만** 하고 내부 공백이
  남으면 **고쳐주지 않고 거부**한다 — 신원을 조용히 수선하는 것이 바로 잘못된 클래스가 승인되는 경로다.
  같은 라운드가 인자 재조립도 깎았다: 개행 구분 문자열 방식이 **argv 보존이 아니라** 개행 포함 경로를
  쪼개고 빈 위치인자를 드롭해 **UAP 를 레지스트리 자리로 승격**시켰다 → bash 배열로 교체. 레인 +4(98 → 102).
- **라운드 4 = 새 S/A 0** (수렴). 남은 B 1건은 **명시 잔여로 소스에 적었다**: 영-폭 결합자 같은 보이지
  않는 문자가 클래스 이름으로 허용된다. 같은 라운드 컨트롤이 **거짓 조인은 없음**을 보였고(`ok` vs
  `o<ZWJ>k` → 3, NFC/NFD 불일치 → 3), 악용에는 레지스트리와 UAP **둘 다** 쓰기 권한이 필요한데 그건
  동의의 원천 자체라 권한 상승이 아니다. 올바른 수리는 NFC 정규화 + format/control 문자 거부이지
  비-ASCII 일괄 거부가 아니다(이 하네스는 언어 중립이고 한글 클래스명은 정당하다) — 릴리스 중에 넣을
  줄이 아니라 자기 known-pair 를 갖는 설계 결정이다.
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
