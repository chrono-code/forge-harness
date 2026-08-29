# Field-Harness Diagnostic — compose → rank → HITL (detail)

> Always-loaded summary: `CLAUDE.md §Field-Harness Diagnostic`. This file is the detail home —
> the full lens table, dogfood examples, and guard rationale. Read when actually running the
> diagnostic on a mapped project.

The Load-Bearing Change Gate fires on a **specific field code change**. This diagnostic is its
**on-demand pull sibling**: when the operator, working in a mapped project, asks to *diagnose* or
*improve* the harness itself ("진단해줘", "개선해줘", "check this project"), don't hand-pick one
skill — **compose the checks FH already has into a single ranked diagnostic list and get per-item
approval.** The value is that the operator asks once and the harness surfaces *everything* worth
fixing, ranked, instead of the operator having to know which of a dozen skills to invoke. Every fix
is HITL — the diagnostic **proposes**, never auto-edits.

## Composition (no-reinvention — every row is an existing check; the diagnostic only *routes and ranks*)

| Lens | Existing check | Catches (real examples from 2026-07-08) |
|---|---|---|
| **Confidentiality / leak** | `/public-surface-audit` (incl. Step 3c ignore-verification) | a hardcoded internal API host literal in a SKILL body; a `local_*_context.md` that is **tracked** when it should be gitignored (the gitignore-mistake class) |
| **Split integrity** | `/phantom-quench` **Step 2.7** (bidirectional) | orphan detail sections + phantom pointers in a SKILL.md ↔ SKILL_detail.md pair |
| **Token / salience** | salience-split candidates (`/context-doctor` · `/salience-splitter` targets) | oversized always-loaded SKILL.md / CLAUDE.md — trim candidates |
| **Structure** | `/harness-doctor` (L1–L4) | orphaned/redundant/decorative units, missing Done-When, ≥70% overlap |
| **Verdict/gate degrade** | `scripts/degrade_direction_scan.sh` | a field verdict/gate helper that degrades toward permissive (advisory pre-screen) |
| **Loop-readiness** (황민호 loop-eng 5-question lens, 2026-07-10 — detail home: `loop_engineering.md`, incl. the FH loop inventory + design-time discipline) | *Loop-runtime axis — net-new vs Structure* (harness-doctor scans static form; this scans whether the path closes a loop). **Mechanical grep**: `/goal-quench`·`/loop` wiring present · check-class token declared. **Judged**: is the persisted state (card/handoff/memory) actually reloaded · is the declared check-class anchored, not judged-only · does the path halt. Done-When *presence* → see Structure row (no double-grep). **Adversarial pair** (for the judged sub-checks — decorrelated, behavior-vs-checklist): a target-tier blind sim that *runs* the path and observes whether it halts + persists, rather than re-checklisting it (the harness litmus shares this lens's axis, so it is a co-lens, not the adversary). | an agent path that *runs but doesn't loop*: no completion criterion (Done-When absent), judged-only validation with no anchor, no halt/budget guard (runaway/cost), or no state carried to the next run — the 5 questions (initiate · complete · validate · halt · persist) with 0 answers |

| **Built-but-unwired scan** (2026-08-01, from the qasp full audit) | **Mechanical grep**: for each module/entry-point under the project's source root, count call/import sites outside its own file and tests — `grep -rn "module_name" --include="*.py" | grep -v "module_file\|tests/"` per module (adapt the include glob per language). 0 external callers on a *completed* module = a finding. **Judged**: is it staged-for-later (documented as such) or genuinely orphaned capability? | the dominant defect class of the 2026-08-01 qasp audit: most M/S prescriptions were not "build new" but **wire what exists** — ET·delivery·feasibility modules complete with ZERO callers. A harness that keeps building finished capability nobody invokes reads as progress while shipping none; harness-doctor's Structure lens sees orphaned *harness units*, this lens sees orphaned *product modules* (net-new axis) |
| **Triad consistency** (2026-08-01, from the field→meta reverse-verification arc — doctrine home: `harness_verification_core_extended.md` §2, incl. the full dispatched-procedure recipe) | **Dispatched procedure** (no shipped carrier yet — honest label): one context-decorrelated agent over the slice {spec docs · implementations · test suites + every enforcement owner the spec names}, producing a spec-coverage MECE matrix + three-way traceability table + grounded findings; known-pair calibration before trusting output; governor source-grounds each finding. Cluster-independent by doctrine (core lens). | the class every per-asset check misses: **spec ↔ implementation ↔ TC disagreement** — pinned counts rotten against grown suites, orphan implementations with zero spec presence, opt-out semantics drifting between spec text and code comment (7/7 novel findings of the 2026-08-01 FH pilot were in this class; replicated N=2 on a second subject) |

| **measurement-reps** (2026-08-29 신설 · 같은 날 필드 1회 실행으로 개정) | **Step 0 — provenance 분리(필수, 세기 전에).** 🟥 FH 가 온보딩한 하네스는 **전부 FH 파생**이라, 그냥 스캔하면 **FH 자기 텍스트를 필드 발견으로 되읽는다**. 실측 2026-08-29 pmh-dev: 원시 히트의 **2/3**가 미러였고 `knowledge/shared/harness-core/` 에만 동명 파일 **41개**였다. 그러므로 먼저 `diff -rq <field>/knowledge/shared <FH>/knowledge/shared` + 경로 배제로 **고유 기록**과 **상류 미러**를 가른 뒤, 고유 기록에만 렌즈를 건다. 이 단계를 빼면 숫자가 구조적으로 부풀려진다. **Mechanical grep**: 고유 기록(마커·판정·신호·릴리스 노트)에서 **바 미달(1~2)** 표기를 찾는다. 권장 변이 목록 — `n=1|N=1` · `reps=1|2` · `단일 (시행|관측|런|측정)` · `점추정` · `anecdata` · `1회 (실측|측정)` · `single (run|sample|draw)`. 🟥 **`단발` 은 넣지 마라** — 산문의 「단발 풀세트 산출」 류에 걸리는 false friend 다(같은 실측에서 50KB 소음). **Judged, 두 질문이다**: ⓐ 그 측정이 떠받치는 결론이 «하중을 지나» — 판정 · 등급 · 교리 변경 · 비가역 처방 중 하나인가. 아니면 계상하지 않는다(계기 확인용 1회는 올릴 값이 없고, 전부 올리면 소음이 된다). ⓑ 🟥 **그리고 「이미 닫혔나」를 반드시 같이 물어라** — 이미 철회됐거나, 그 값을 인용하는 **하류에 `reps<3` 를 기계 거부하는 게이트가 있으면** 그건 열린 갭이 아니라 **수리의 기록**이다. `CLOSED`(0점)이지 R 이 아니다. 판별자 한 줄: «그 값을 소비하는 자리에 reps 게이트가 있나». 이 질문이 없으면 렌즈가 남이 이미 고친 것을 발견으로 되판다. **처방은 언제나 「sim 으로 올리자」 한 줄** — 자동 실행이 아니라 랭크. | 🟥 지금까지의 기본값: 「reps=1, 바 미달」이라 **적고 넘어간다**. 라벨은 측정이 아니다. 실측 2026-08-29 — 같은 세션에서 두 번 그렇게 적었고 **두 번 다 운영자가 밀어서** reps=3 으로 올라갔으며, 올려보니 **결정적**이었다(ARM 3/3 · CONTROL 0/3). 즉 그 라벨들은 「모른다」가 아니라 **「안 재봤다」**였다. ⚠️ 이 렌즈는 FH 자산에만 걸리는 규율이 아니다 — 필드 하네스가 자기 개선을 기록할 때 같은 자리가 생기고, 오히려 그쪽이 표본이 더 귀하다 |

> **Considered-and-held, 7th-lens candidate (2026-07-24)**: the context-quality 7-criteria rubric
> (arXiv:2607.14275 — role clarity · guardrail coverage · instruction consistency · tool schema ·
> grounding sufficiency · injection hardening · token efficiency) is **not** adopted as a lens: its
> shipped scoring is ProofAgent-Harness multi-juror consensus — judge-only, failing the measured bar
> this table holds. Re-check triggers: ⓐ a deterministic scoring rubric ships upstream, or ⓑ the
> token-efficiency / tool-schema subset proves mechanically scoreable on a known pair. Do not
> re-propose without one of the two. Cross-audit: `tracks/_audit/session_2026_07_24_grace-context-rubric.md` (operator-local record).

## Output

One ranked list, `M` (must-fix) / `S` (should-fix) / `R` (recommended) — same tiering as
harness-doctor — each item stating *lens · file:line · one-line fix*. **Then HITL**: the operator
approves per item (or a batch); an approved fix routes to the owning skill's normal path (and, if it
is itself a load-bearing field change, through the Load-Bearing Change Gate). **Nothing is
auto-fixed** — the diagnostic's job is the *intelligent list*, the human's job is the *go*.

## Guards

- **(a) Project-level ask only** — fires on a project-level "진단/개선" ask, not a single-file edit
  request (those go straight to the relevant skill).
- **(b) Once per ask** — not a per-turn nag.
- **(c) Company residency** — run leak/confidentiality lenses locally, sanitize before any
  cross-family dispatch, and *surface* company-sensitive findings (tracked company hosts,
  git-history rewrites) for operator decision rather than auto-fixing them. Dogfood 2026-07-08: the
  `local_pmh_context.md` tracked-company-hosts finding was surfaced, not auto-untracked — history
  rewrite is the operator's call.
- **(d) Autonomy floor** — the compose/rank judgment is trusted at opus-tier+; below-floor, run the
  individual checks and present raw rather than silently skipping a lens.

**Scale to the ask**: a quick "뭐 고칠 거 있어?" runs the cheap mechanical lenses (leak · split ·
token); "제대로 진단해줘" runs all six + harness-doctor depth.


## measurement-reps — 첫 필드 실행 (2026-08-29, reps=1)

렌즈를 신설한 날 **FH 밖에서 처음** 돌렸다. 대상 qasp-dev(2,008 md) · pmh-dev(224 md), 격리 위임.

**캘리브레이션 먼저 (PASS)** — known-positive `qasp-dev/sandbox/matrix_bench/DESIGN_v1.md:43`
(*"성립 조건: reps≥3(v0는 n=1)"*) · known-negative `.../RUNNER_gal3.md:69`(*"reps ≥ 3 / 조건 (v0 n=1 해소)"*).
**같은 디렉터리·같은 측정 계열이라 코퍼스도 주제도 아니라 reps 값만 다르다** — 그래서 이 쌍이
판별력을 잰다. 둘을 반대 팔로 정확히 갈랐다.

**헛돌지 않았다.** qasp-dev 에서 M 2 · S 1 · R 1 이 나왔고, 넷 다 그 레포의 기존 렌즈
(triad · leak · structure · degrade)가 **구조적으로 못 잡는 자리**다. 대표 하나만 적는다 —
`docs/interface/gem/[지식]Master_Blueprint_v10.md:551,558,565` 의 `scale_baseline_3_tier` 가
규모별 기대 산출 건수와 분류 분포를 박아두는데 **세 티어가 각각 `sample n=1`** 이고, Gem 이
소비하는 기계 baseline 이라 판정 기준을 떠받친다. 🟥 **분포에 0% 칸이 있는 것이 증거다** —
n=1 은 「이 분류는 안 나온다」와 「이번엔 안 나왔다」를 구분하지 못한다. 코드도 게이트도 아닌
**「기계가 읽는 상수」**라 어떤 정적 스캐너도 안 짖는다.

**그리고 이 실행이 렌즈 자신의 결함 4개를 잡았다** — 위 표의 Step 0(provenance) · Judged ⓑ(닫혔나) ·
변이 목록에서 `단발` 제거 · 행 제목 대소문자가 전부 여기서 나왔다. 마지막 것은 사소해 보이지만
gate-locality 다: 정본이 `Measurement-reps`, 요약이 `measurement-reps` 라 **요약대로 grep 하면
정본에서 0 히트**였고, 그 임무의 첫 grep 이 실제로 그렇게 빗나갔다.

⚠️ **정직 경계 — 이 절의 숫자를 일반화하지 마라.** 필드 실행 **reps=1**(레포당 1회 스캔)이다.
오탐 4종은 그 1회에서 관측된 것이고 미관측 클래스가 더 있을 수 있다. 「M 2 · S 1」 은 *이 스캔이
그날 그 트리에서 낸 랭크*이지 그 하네스의 결함 총량이 아니다. 그리고 이 렌즈는 **랭크만 하고 아무것도
고치지 않는다** — 그 실행도 파일을 하나도 수정하지 않았다.
