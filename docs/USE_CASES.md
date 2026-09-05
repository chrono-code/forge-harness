# FH 는 어디에 쓰나 — 엔진별·대상별 사용처 지도

> **읽는 사람**: «하네스를 짓는 플랫폼」이라는 말은 들었는데 *내 레포·내 코드*에 무엇을 해 주는지 모르는 사람.
> **한 줄**: 하네스 제작·가속은 **최대 레버**일 뿐이다. 아래로 내려가면 스킬/에이전트 제작, **코드 리뷰로 약점을 찾아 고친 채로 반영**, 비가역 표면(푸시·삭제·공개)의 게이트, 세션 간 맥락 유지가 있고, 각각은 Claude Code 없이도 쓰이는 것이 있다.

## 0. 먼저 — 무엇이 «FH 가 하는 일」이고 무엇이 아닌가
| FH 가 한다 | FH 가 하지 않는다(그 일은 어디로) |
|---|---|
| **변경(diff)과 과정**을 본다 — 이 변경이 판정을 낙관 쪽으로 접지 않나, 참조가 실재하나, 비밀이 새지 않나, 주장이 근거에 묶였나 | **제품 동작**을 검증하지 않는다 — 앱이 기획대로 도는지는 QA 하네스(qasp 류)의 일. FH 는 그 하네스를 짓고 가속한다 |
| 비가역 표면 앞에 **기계로** 선다(커밋·푸시·삭제·공개) | 사람의 «취향」 리뷰를 대신하지 않는다 — 기계가 끝낸 뒤 사람에게 남는 것이 취향이다 |
| 강한 모델의 판단을 **기록의 속성**으로 남긴다(마커·매니페스트·원장) | 판단 자체를 코드로 굳히지 않는다(§Mechanization Boundary) |

## 1. 엔진별 사용처 — 위에서 아래로(레버 큰 순)
| 레버 | 무엇을 얻나 | 엔진 | 진입 |
|---|---|---|---|
| **하네스 제작·가속**(최대) | 남의 레포에 게이트·규칙·세션 규율을 심고, 챔버에서 새 하네스/스킬을 낳는다 | 넷 다 | 온보딩 문 ①②③, `auto_project_mapping.md §6`, 인큐베이터 |
| **스킬/에이전트 제작** | 트리거·Done When·check-class·독립실행성을 갖춘 스킬을 게이트 통과 형태로 | 품질게이트 · 영혼 | §New Skill Creation Pre-Commit Gate · `fh-meta:asset-placement-gate` |
| **코드 리뷰 → 약점 발견 → 고친 채로 반영** | diff 를 놓고 «낙관 방향 degrade · 팬텀 참조 · 비밀 · 주장-근거」를 찾고, 머지 전에 수리·재검까지 | 품질게이트 · 질문하기(cross-family) · 영혼(defeater) | `npx --package @chrono-meta/fh-gate fh-gate`(CI/훅, Claude Code 불요) · 세션 안 `/steel-quench` `/phantom-quench` · §Field-Harness Load-Bearing Change Gate |
| **비가역 표면 게이트** | 브랜치 삭제·force-push·직접 main 푸시·공개·npm publish 앞의 fail-closed | 품질게이트 | `templates/.git-hooks/pre-push` · Pre-Publish 체크리스트 · `PUBLIC_SURFACE_OK`/`DESTRUCTIVE_OP_OK` 로그된 오버라이드 |
| **세션 간 맥락 유지** | 압축·세션·기계 경계를 넘어 실 붙잡기 — 카드·봉인 원장·착지 검사 | 맥락유지 | §Session Wrap-up · compaction seal · `session_close_check.sh` |
| **측정 규율** | 숫자를 내기 전에 계기부터(known-pair·컨트롤·«not found ≠ 0») | (전 엔진의 재료) | §Instrument Calibration · `sim_isolated_run.sh` · `probe_live_eval.sh` |

## 2. «내 코드 리뷰에 FH 를 쓴다」 — 정확히 무엇이 일어나나
1. `fh-gate` 가 diff 를 읽고 **typed 판정**을 낸다: `0 PASS · 1 PENDING(B) · 2 BLOCKED(A) · 3 ESCALATE · 10 하네스 오류(fail-closed) · 12 dry-run`. 판정이 산문이 아니라 exit code 라 CI 가 읽는다.
2. 찾는 것: 검증 게이트가 실패를 통과로 접는 분기(degrade direction), 존재하지 않는 경로·버전·인용(phantom), 비밀·내부 식별자, 테스트가 실물이 아니라 더블을 재는 자리, 근거 없는 주장.
3. **실측 한 건(2026-05-31)**: 남이 쓴 AI 생성 코드 163줄(CI 초록)에 BLOCKED — CI 가 놓친 A급 2건. 같은 입력에 일반 리뷰는 5/8, 그중 2건은 «틀린 버그」. 🟥 한 건이다 — 일반화 근거가 아니라 형태의 예시다.
4. 고치고 다시 돌린다 — «수렴 = 라운드가 아니라 변경으로」(새 S/A 0 ∧ 그 라운드에 안 고침). 사람에게 가는 것은 그 뒤의 취향.

## 3. 서비스 개발 레포에 품질게이트를 얹으면 — 기대와 실측을 갈라서
| 얹는 것 | 효과(근거 등급) | 비용 |
|---|---|---|
| pre-push: 직접 main 금지·force/삭제 fail-closed·공개 전 비밀 스캔 | **기대(구조적)**: 사고가 조용히 나지 않는다. FH 자기 레포 실측 = 실차단 2회(2026-08-13) | 낮음 — 오버라이드는 로그된다 |
| PreToolUse advisory 훅(파이프 뒤 `$?`·백틱·파괴 명령·실행 중 스크립트) | **실측(FH)**: 같은 부류 재발 6~7회를 훅이 잡았다 | 거의 0 |
| diff 게이트(`fh-gate`) — 판정/게이트/비가역 코드에 | **실측(다른 하네스 3곳, n=7)**: default-toward-PASS 구멍 9건 | 리뷰 1회 ≈ 모델 호출 1~2 |
| 4축 마커 규율(soul·defeater·crossfamily) | 🟥 **FH 자산 전용** — 서비스 레포에 그대로 얹으면 커밋을 막는다(`auto_project_mapping §6` «Not installed (deliberately)»). 서비스용 경량 프로필은 **미출하** | — |
| 세션 카드·마감 체인 | **기대**: 다세션 팀에서 «누가 무엇을 열어뒀나」가 보인다. 실측은 FH 자기 운용뿐 | 세션당 마감 1회 |
**정직한 경계**: 위 «실측」은 전부 하네스 레포(FH·QA 하네스·메타하네스)에서 잰 것이다. 프로덕션 서비스 레포에서의 효과는 **미측정**이고, 첫 측정은 «게이트가 실제로 막은 것 1건」이면 된다(n≥1 규율).

## 4. QA 하네스와의 경계 — 무엇을 검증하나로 가른다
```
FH   : 변경과 과정 —  이 diff 가 판정을 접나 · 참조가 실재하나 · 비밀이 새나 · 주장이 근거에 묶였나
                       → 레포에 얹는 것(훅·게이트·리뷰)까지 FH 가 맡는다
QA 하네스: 제품 동작 — 기획대로 도나 · TC 설계 · 실행(웹/앱) · 회귀 · 버그 초안
                       → 인앱에서 «맞물려 도는가」는 여기
경계의 이음매: FH 의 diff 리뷰 산출(«어디가 약한가」) → QA 하네스 1막 입력(«그 약한 곳을 도는 시나리오」)
              typed capability 로 잇는다(`capability_composition_contract.md`) — 제약은 strictest-wins
```

## 5. 같이 읽을 것
`README.md §① Just the gate` · `CHEATSHEET.md` · `docs/USER_GUIDE.md` · `knowledge/shared/harness-core/field_verdict_crossfamily_gate.md` · `knowledge/shared/rules/auto_project_mapping.md §6`
