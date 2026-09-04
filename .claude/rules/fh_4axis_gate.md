---
paths:
  - "plugins/**/SKILL.md"
  - "knowledge/**/*.md"
  - "templates/**"
  - "AGENTS.md"
  - ".claude/rules/**"
  - ".claude/agents/**/*.md"
---

<!-- ⚠️ CLAUDE.md 를 glob 에서 **의도적으로 제외**했다 (2026-07-20, cross-family 지적).
     루트 CLAUDE.md 는 세션 시작에 무조건 읽히므로, glob 에 넣으면 이 규칙이 매 세션
     즉시 로드된다 = 절감 0 이고 총량은 오히려 늘어난다(67.6k + 12.5k > 76.7k).
     즉 "상주 파일을 조건부 규칙의 트리거로 넣는 것"은 pointer-illusion 의 부활 경로다.
     CLAUDE.md 편집은 pre-commit 훅이 계속 커버한다. docs/** · plugins/**/*.md(전체) ·
     scripts/** 도 과매칭(읽기만 해도 로드)이라 좁혔다. -->

<!--
  FH 4-Axis Auto-Gate — 경로 스코핑된 규칙 (2026-07-20 이전)

  왜 여기 있나: CLAUDE.md **파일** 76,706자 중 이 섹션이 10,331자(13.5%)로 단일 최대였다.
  요약으로 대체했다. 파일 전체는 같은 세션의 다른 정리(중복 3건·New-Skill 게이트 편입)까지 합쳐
  76,706 → 67,611 (순감 9,095자, 11.9%) — **합산치이지 이 절 하나의 성과가 아니다**.
  전부 **파일 char 실측**이지 `/context` 상주
  실측이 아니다(상주는 톱레벨 새 세션 `/context` 로만 잰다 — 이번엔 미측정).
  이 게이트는 **FH 자산 파일을 건드릴 때만** 필요하므로 `paths:` 로 조건부 로드한다.
  (`paths:` 없는 rules 파일은 세션 시작 시 항상 로드된다 — 반드시 유지할 것.)
  ⚠️ 공식 트리거는 **read** 다("Path-scoped rules trigger when Claude reads files matching
  the pattern" — code.claude.com/docs/en/memory.md). 즉 매칭 파일을 안 읽고 Write 로 신규
  생성하는 경로엔 이 규칙이 안 실린다. 그 구멍의 floor 는 pre-commit 훅이다.

  왜 이 섹션이 이동 후보 1순위였나 — 2축 판정:
    ① 트리거가 **파일**이다 (FH 자산 수정). 의도·발화 트리거가 아니다.
    ② **기계 백스톱이 있다** — `templates/.git-hooks/pre-commit` 이 커밋을 하드 차단한다.
       즉 이 산문이 안 떠도 훅이 막는다. 산문은 훅 위의 살리언스 층이다.

  ⚠️ 같은 이유로 **옮기면 안 되는 것들**: Pre-Publish Gate · Destructive-Op Gate ·
  Irreversibility 공통 척추. 그것들은 **파일이 아니라 의도로 발동한다**
  (`gh repo create --public` 은 파일을 건드리지 않는다). 경로 스코핑하면
  정확히 그 경로에서 안 뜬다 = fail-open.

  과거 실패 참조: FH 가 detail 포인터 뒤로 ~50k 를 옮겼으나 대상이 여전히 auto-load 라
  절감이 0 이었다(pointer-illusion). `paths:` 는 플랫폼 레벨 강제라 그 함정이 없다.
-->

## FH Improvement 4-Axis Auto-Gate (Self-Verification Orchestrator)

**Whenever the AI modifies FH assets** (SKILL.md · **`SKILL_detail.md`** · `.claude/rules/*.md` · `knowledge/shared/rules/*.md` (relocated protocol rules — always full-gate, NOT under the knowledge carve-out) · `templates/` · `CLAUDE.md` · substantive `knowledge/` docs · substantive `docs/*.md` · `AGENTS.md` · `scripts/**/*.sh` · agent definitions (`plugins/*/agents/**/*.md` · `.claude/agents/**/*.md`) — see Substantive carve-out below),
the 4-axis verification chain runs **automatically before the first commit** of that session.
No user request is needed — this is a mandatory autonomous step, not a proposal.

> **`SKILL_detail.md` added 2026-07-26.** It was absent from this list *and* from both gate
> implementations because the matching term was the literal `SKILL\.md`, which the string
> `SKILL_detail.md` does not contain (the underscore breaks it). Measured at the time: 17 files /
> 208,710 B = **27.7% of the skill-spec surface**, 16 of 17 carrying fenced code blocks — i.e. real
> executable content, precisely what the Substantive carve-out below says must be gated *wherever it
> lives*. It leaked twice for real (`371c04f`, `e661931` — both single-file edits to
> `phantom-quench/SKILL_detail.md`, a gate skill's own behavioral spec, with zero 4-axis coverage).
> **The structural lesson outlives the fix**: `salience-splitter` *widens* a hole of this shape every
> time it relocates content to lean the resident layer, so **every split must re-ask whether the
> destination path is inside the gate** — coverage otherwise shrinks as the diet succeeds.
> Mechanical anchor: `scripts/gate_pathspec_check.sh` (known-pair, wired into pre-commit).

**Commit gate**: `git commit` on FH asset changes is hard-blocked by `templates/.git-hooks/pre-commit` until all required axes PASS. Hook installation (one-time): `git config core.hooksPath templates/.git-hooks && chmod +x templates/.git-hooks/pre-commit templates/.git-hooks/pre-push` (the same `core.hooksPath` also activates the **pre-push** Destructive-Op gate — see that section below).

```
FH asset modified → Axis 1 (templates/regression_guard.sh --pr {BRANCH})
  → Axis 2 (/steel-quench) → Axis 3 (/phantom-quench)
  → marker: tracks/_meta/.axes_23_passed_{branch}_{date}.marker
     (required fields: axis2-engine / axis2-model / floor-status / axis2-evidence /
      **`axes-run:`** + **`controls:`** (see §Marker axis fields below — these were enforced by the
      hook since 2026-08-10 and listed in NO rule file until 2026-08-17; the spec lived only in the
      hook and in two CLAUDE.md/AGENTS.md one-liners, so an author reading the rules could not learn
      the format that blocks their commit);
      + **`crossfamily:`** — required on LOAD-BEARING changes only, and TYPED since 2026-08-08:
      `panel(<families>)` | `declined` | `DEGRADED_SINGLE_FAMILY` | `DEGRADED_PANEL_UNUSED` |
      `UNKNOWN`, the three degrade values requiring substantive grounds on the same line.
      Presence has been required since c1fa459; what was free prose is now a closed enum,
      because a presence check catches silence but not a confident wrong answer — a sibling
      harness shipped `crossfamily: none — 도달 불가` that was later found false and then cited
      as grounds. Fixtures: `scripts/test_marker_crossfamily_lanes.sh`;
      **recorded-by-convention, validated by nothing**: `axis2-rounds` (per-round yield vector) —
      steel-quench §Convergence Criteria consumes it, and a hook check for it was built and then
      REMOVED the same day for firing on 100% of markers. The convergence claim it supports is
      self-attested; that residual is named in §Convergence Criteria, not hidden. Mechanize on the
      first recurrence of a false convergence claim, not before;
      hook validates mechanically: below-floor blocks without below-floor-ack, and axis2-evidence
      must be non-vacuous — a recorded verdict/count, not "it ran". Marker scope is form +
      non-vacuity + auditability, NOT provenance — a fabricated marker is the weekly-audit + operator
      residual by design, do NOT fake-close it.
      → **Detail**: See `knowledge/shared/harness-core/claude_md_gate_details.md §Marker-Irreducibility`
        — why the below-floor-ack is structurally irreducible for an autonomous runner + the
        operator-present GPG hard-close option — read when auditing or attempting to harden the marker.)
  → Axis 4 (/edit-manifest RECORD, today's entry in edit_manifest.yaml)
  → All 4 PASS → git commit allowed   |   Any FAIL → fix inline, re-run
```

**Why automatic**: Each axis catches a different defect class; asking separately means slip-through. **Why hook**: CLAUDE.md rules are advisory — the hook physically blocks commit until marker + manifest exist. External anchor: the HANDBOOK.md benchmark (arXiv:2607.25398) measures prose-only SOP compliance failing at frontier scale — canonical harvest with figures: `knowledge/shared/harness-core/gate_locality_principle.md` §external anchors (numbers live there only; a pinned figure in two files rots independently). **Scope**: active from the moment any FH file is modified in the session.

**Lightweight exception** (Axis 1 + 4 only, skip Axes 2–3): Sessions where **zero SKILL.md / rules / templates files changed** (e.g., CATALOG.md entry, tracks/ update). The hook detects this automatically — no Axes 2+3 marker required for light-only commits. Judgment is file-based, not subjective.

**Substantive carve-out — `knowledge/` · `docs/*.md` · `AGENTS.md`** (Axes 2–3 DO run, despite these not being SKILL/rules/templates): a change to any of these is **not** light if its diff adds a fenced code block (```` ``` ````) or a citation/version claim (`arXiv:` / `DOI` / `http` / a versioned dependency like `x.y.z`). Executable patterns and factual claims need phantom-detection + adversarial review *wherever they live* — `knowledge/` Implementation-Patterns sections carry runnable commands, `docs/` holds published guides, and `AGENTS.md` is the Codex-user entry point, so a phantom skill name or wrong version there is an external-facing error the gate must catch. Prose-only edits (typos, rewording, link fixes) stay light. Detection is mechanical: `git diff` adds a ```` ``` ```` fence or a citation token → run Axes 2–3.

**Unavailable axis**: If steel-quench or phantom-quench are not installed, note `Axis N: skipped (skill unavailable)` and proceed. Axis 1 PASS alone is sufficient to unblock a PR when Axes 2–3 are unavailable. Axis 4 (edit-manifest): if the skill is not installed, substitute a manual one-line prediction appended to `tracks/_meta/edit_manifest.yaml` — the record is what matters, not the skill.

**Target-tier sim gate (Mode D supplement — all change classes: fix, improvement, new asset)**: the
discriminator is not the change class but the **enforcement column**: does the asset's effect depend on
a session *following prose instructions* (salience-dependent — rules, onboarding scaffolds, SKILL.md
trigger behavior), or is it mechanically enforced (hooks, scripts — tier-independent, normal 4-axis
path, exempt)? For salience-dependent changes, verify with a **blind simulation in an isolated Agent**
(no main-session reasoning inherited — isolation is the FH mechanism that keeps the sim honest) with
`model:` pinned to the tier the change must survive on — **default sim tier = Sonnet** (the base
floor every FH behavior must survive on, `sonnet_floor_doctrine.md`). Application strength scales
with context:
- **Mode D (FH self-dev) — near-mandatory**: any salience-dependent FH asset change runs the sim
  before Done, at Sonnet by default. Mandatory without exception when the change fixes a behavioral
  miss *observed* on a specific tier — sim at that same tier, even below Sonnet (the verification
  tier must match the failure tier; fixing on a stronger model and verifying by review alone leaves
  "does it fire on the weaker tier?" unanswered).
- **Field harness assets (templates/ propagated via Full-Harness Mode) — conditional**: sim at the
  default field tier (Sonnet) when the behavior is load-bearing (gates, onboarding, destructive/publish
  paths); skip with a one-line note for low-stakes prose.
- **Light mapping (tracks/ registration, CATALOG entries) — exempt**, alongside mechanical changes
  (hook logic, scripts, file moves — tier-independent by construction).

**Autonomy floor**: the skip/run *judgment* on conditional cases is itself depth-sensitive — trust it
only at opus-tier or above. A below-floor orchestrator does not silently skip — and does not stall:
its default is to RUN the sim (the conservative branch needs no trust); it asks the operator only when
no runnable path exists (run-first, ask-last — sonnet_floor_doctrine.md §Autonomy at Sonnet).

Record sim results in the Axes 2–3 marker + sub-agent invocation log.

### Marker axis fields — `axes-run:` · `controls:` · `standpoint:` · `soul:` · `soul-check:` · `defeater:` · `tenets:` · `affected:`

🟥 **기호 규칙 (2026-09-04, six_axis_review 판정안 8) — ⓐ~ⓕ 는 축 전용 기호다, 열거로 재사용하지
마라.** 산문에서 목록을 셀 때는 `①②③` 또는 `(a)(b)(c)` 를 쓴다. 오늘(2026-09-04) 같은 이틀치
로그에서 ⓐ~ⓓ 가 축이 아닌 **열거 기호**로 재사용된 사례가 실측됐다(작성자 자신의 기록 포함) —
그 문서를 grep 감사하는 쪽이 «⑤ⓑ⓶» 식 문자를 축 참조로 오독한다. 이 줄은 새 검사를 요구하지
않는다 — 재발 시 로그 린트로 기계화한다(`§FH Improvement Signal Recording Protocol`).

> 🟥 **이 제목의 뒤 넷은 2026-08-30 에 추가됐고, 그 이유가 이 절이 이미 적어둔 결함이다.**
> `soul:` 은 **2026-08-21 부터 커밋을 하드 차단**해왔는데 **어느 규칙 파일에도 적혀 있지 않았다**
> 🟥 **정정 (같은 날, cross-family codex #1 지목 — 자력 적발 0)**: 이 줄의 초판은
> «`soul:`·`soul-check:` 이 하드 차단» 이라고 적었는데 **`soul-check:` 은 부재 시 차단하지
> 않는다**(`validate_soul_check_leg` 은 필드가 없으면 `return 0`). 실측 rc=0.
> 즉 **오늘 gate-locality 를 고치면서 같은 절에 새 오설명을 심었다** —
> `[[feedback_rule_misdescribes_its_own_machine]]` 의 당일 재발이다.
> **`soul-check:` 은 «있으면 enum 이 강제되고, 없으면 통과»** 다(채택은 점진적이다). — 즉 아래 문단이 스스로 명명한 «spec 쪽 gate-locality 결함»이 같은 절 안에서
> 9일간 살아 있었다. 블라인드 플로어 티어 sim(2026-08-30, reps=3)이 그것을 실측으로 잡았다:
> 세 팔 전부 나머지 11개 필드를 정확히 썼고 **`soul:` 을 하나도 안 썼다.** 훅이 차단하는 필드인데도.
> 원인은 모델이 아니라 배선이다 — 행위자가 읽는 자리에 그 요구가 없었다(`FH-T07`).

**`soul:` (또는 `①영혼:`) — 설계 *전에* 쓴 «성공 정의 / 절대 안 함». 없으면 `없음`.**
공허한 한 단어(placeholder)는 차단된다. 훅은 **존재와 비공허성**만 본다 — 내용의 옳음은 안 본다.
🟥 provenance(«정말 설계 전에 썼나»)는 **파일에서 확인 불가**다. 훅 주석이 그렇게 명시한다.

**`soul-check:` — 있으면 닫힌 enum, 없으면 통과(부재는 차단 아님).** `reflected(<무엇이 되돌아왔나 — 어긋남 여부>)` ·
`violated(<어느 절반이 깨졌나 + 무엇을 했나>)` · `DEGRADED_NOT_RUN(<왜>)` ·
`DEGRADED_NO_SOUL(<왜>)` · `UNKNOWN` · `not-applicable(<왜>)`.
🟥 `violated` 는 **일부러 합법이다.** 기록된 위반이 숨겨진 위반보다 낫고, 성공만 받는 레인은
지우는 법을 훈련시킨다.

**`defeater:` — 「이 성공 정의가 틀렸다면 무엇이 *관측*될 것인가」 한 줄.** 2026-09-01 이후
날짜의 마커에만 강제된다(그 전 마커는 소급 없음 — `SOUL_PRESENT_GRACE_DATE` 와 같은 패턴).
훅은 **비공허성만** 본다(관측 가능한 사건을 명명했는가). 외부 근거: Assurance 2.0 의
*defeaters and counterevidence*. 🟥 저자가 자기 반증조건을 적는 것은 **게임 가능하고, 안 닫힌다** —
닫는 방향은 cross-family 가 그 마커를 읽는 것이다.

**`tenets:` — 선택. 인용하면 참조 무결성이 강제된다.** `.claude/soul_tenets.txt` 에 실재하는
`FH-T\d\d` ID 만 허용되고, 미등록 ID 는 차단된다(오타를 조용히 버리지 않기 위해서다).
🟥 인용은 **이 줄에서만** 읽는다 — 다른 줄에서 ID 를 «설명»하는 것은 인용이 아니다.
인용이 하나도 없으면 통과한다(채택은 점진적이다).

**`affected:` — 선택. 「이 변경이 건드리는 것(사람·하네스·표면) + 열린 질문」 한 줄.**
(2026-09-04, frontier absorption — Anthropic AI-Native SDLC playbook `intent.md` 의 «Affected
users and systems» · «Open questions» 두 칸을 흡수한다. 두 필드로 쪼개지 않는다 — 별도 필드마다
빈 칸이 하나씩 늘어나는 것은 이 절이 이미 피하는 모양이다. 한 줄 산문 안에 «열린 질문 = …»
관례로 같이 담는다.) **없으면 통과**(soul-check:/tenets: 와 같은 패턴, 채택은 점진적이다). 있으면
비공허성만 본다 — `defeater:` 와 달리 **「없음/TBD/-」류 자리표시자만 있는 값은 차단된다**: 모든
변경은 반드시 무언가를 건드리므로(제로 영향은 명제상 없다) 자리표시자만 있는 값은 정직한 부재가
아니라 안 채운 것이다. 중복 줄도 차단된다(읽는 쪽은 첫 줄만 취한다).
```
affected: 소비자 install 의 pre-commit 사용자(마커 형식) · 열린 질문 = 필드 강제 시점
```


These are enforced (the first two) or expected (the third) on the Axes 2–3 marker. Until 2026-08-17
**none of the three appeared in any rule file** — the format that hard-blocks the commit was legible
only from `templates/.git-hooks/pre-commit` itself. That is a gate-locality defect on the *spec*
side: the rule the author reads did not describe the check the author must pass.

**`axes-run:` — one line, all keys present, `none` for axes not run.** Silence is not zero: an axis
you skipped is written `none`, never omitted. Omitting it makes the reader parse an absence as a
decision.

```
# markers dated BEFORE 2026-08-17 — old 4-axis array, ASCII keys
axes-run: a=<다른 계열> b=<첫 실사용> c=<기록 그라운딩> d=<되돌림 실측>

# markers dated 2026-08-17 OR LATER — 6-axis array, circled keys
axes-run: ⓐ=<다른 계열> ⓑ=→standpoint ⓒ=<격리 그라운딩> ⓓ=<3자 대면> ⓔ=<첫 실사용> ⓕ=<되돌림 실측>
```

🟥 **The two arrays are not the same letters shifted — `b` and `d` mean different axes in each.**
Old `b`=첫 실사용 is now **ⓔ**; old `d`=되돌림 is now **ⓕ**. Copying an old line forward silently
swaps two axes, and no error fires.

**Which array a marker used is decided by the date in its filename** (`< 2026-08-17` = old 4-axis).
⚠️ **The notation is NOT the discriminator** — the first version of this section said it was
("circled keys = 6-axis, so an auditor can grep"), and a hand-count of the corpus refuted it: of 53
markers carrying `axes-run`, 4 use circled keys and 1 mixes, and **2 of those 4 are dated 2026-08-10
while meaning the OLD axes** (`ⓑ 첫실사용` · `ⓓ 되돌림` — ⓔ and ⓕ in the current array). The hook
never reads those markers so no commit is affected; the party that gets a wrong answer is the
**auditor**. Aligning the notation is still worth it going forward — it stops the next author from
copying an old line — but it does not work backwards.

⚠️ **The grace-date comparison is an unreachable branch in production, and saying so is the point.**
The call site builds the marker path from `${TODAY}`, so `mdate` is always today; no real commit
after 2026-08-17 takes the `six=0` path, and the only live consumer is the fixture suite. **What
protected the existing markers was the path construction, not the constant** — the same reason
`crossfamily:` could go from free prose to a closed enum eight days earlier with no cutoff at all.

- **ⓑ입장 carries a pointer, not a value** — `standpoint:` is its canonical field, so writing the
  value in both places would be a double record. `ⓑ=→standpoint` requires a non-empty `standpoint:`
  line to exist (a pointer at nothing is not a record). Enforced on any ⓑ value *referencing*
  standpoint, arrow or not — requiring the arrow was fail-open and was measured as such.
- **ⓔ첫실사용 accepts a `shadow(N=<세션수>, F=<발화수>)` value (2026-09-04, exposure-ladder
  extension — canon: `fh_three_layer_canon.md §1-a-2` ⓔ subsection).** For salience-dependent
  assets (rules · onboarding prose · a hook's own trigger phrasing), ⓔ may read as a **ladder**
  — wire → N-session shadow observation (count only, no verdict) → promote — instead of a single
  live-fire event. `shadow(N=3, F=2)` records "observed across 3 sessions, fired in 2" and is a
  legitimate ⓔ value, not a degrade. 🟥 **The hook is UNCHANGED by this** —
  `validate_first_use_leg` (above) blocks on exactly one condition: a **new instrument file**
  added this commit with `ⓔ=` empty/`none`/no grounds on the same line. It does not parse or
  validate the *shape* of a non-empty ⓔ value — `shadow(...)`, a free-prose sentence, and the
  older "실물 대상 한 건" form all satisfy it identically. So this bullet is documentation only;
  no lane changed.
- **Multiple `axes-run:` lines block.** Only the first is read, so a second line is not *rejected*,
  it is **invisible** — anything written there bypasses the check entirely.
- **Grace dates are deliberate**: `AXES_RUN_GRACE_DATE=2026-08-10`, `SIX_AXES_GRACE_DATE=2026-08-17`,
  compared against the date in the marker's **filename**, boundary `<` (the grace day itself is
  required). Retroactive enforcement would block every in-flight branch, and that over-block trains
  `--no-verify`, which disarms the Destructive-Op gate living in the same hook.

**`controls:` — the liveness of the controls, not their existence.** An axis is «run» only with an
execution output in which a control was alive; "붙였다" without a life/death token is vacuous and
blocks. Note the asymmetry this field exists for: *having* a control is not *having discrimination*
— a known-negative only tells you whether false positives exist at all.

```
controls: alive — known-positive 'X' 3 hits · known-negative 0
controls: n/a — no measurement in this delta (<reason>)
```

**`standpoint:`** — closed enum, canonical spec in
`knowledge/shared/harness-core/field_verdict_crossfamily_gate.md §7`. 🟥 **CORRECTED 2026-08-20, then CORRECTED AGAIN the same hour.** This used to read "Still validated
by nothing — zero hook lines, no fixture suite", which is FALSE: `validate_standpoint_leg()` lives in
`templates/.git-hooks/pre-commit` (grep the function name — **line numbers are deliberately not cited
here; the first version of this fix cited `:798`/`:1575` and a commit landed the same hour that moved
them to `:878`/`:1665`**), and `scripts/test_marker_standpoint_lanes.sh` is wired through
`scripts/selfcheck.sh`.
🟥 **But the first correction over-shot, and cross-family caught that too.** It said "the value enum
IS closed and the grounds ARE required". Only the first half holds. Measured by varying ONE variable
at a time — the original known-pair varied two and mis-attributed the result:

```
standpoint: tier2(qasp) — ran <cmd>, saw <out>   rc=0   ✅
standpoint: tier2(qasp)          (no grounds)    rc=0   ⚠️  warns, does NOT block
standpoint: tier2                (no parens)     rc=1   ❌  not an enum member
standpoint: banana(qasp)                         rc=1   ❌  not an enum member
```

So: **the enum is closed and enforced; the execution grounds for `tier2`+ are ADVISORY.** A marker can
still record `tier2` without naming a command and pass with a warning — that is the real remaining
gap, and it is narrower than "validated by nothing" and wider than "grounds are required". Neither
earlier sentence was accurate, and the accurate one required varying one variable at a time.

🟥 **`tier3` is UNREACHED, not disproven (2026-09-04, six_axis_review corpus scan — n=169 markers
carrying a six-axis `axes-run`, 184 total `standpoint:`-bearing markers scanned).** Zero markers
in that corpus record `tier3`. This is expected by the enum's own definition, not a defect: `tier3`
requires *a different human operator of the target harness* to have run the change — this repo has
one operator, so `tier3` cannot be reached from inside it, structurally, until a genuinely separate
operator of a target harness runs something and reports back. Keep the enum member — deleting it
would foreclose the day that operator exists, which is exactly the "unreachable Done-When trains
evasion" failure this repo already names elsewhere (`[[feedback_unreachable_done_when_trains_evasion]]`)
run in reverse (the harm there is deleting the *counted thing*; here it would be deleting the *value*).
Read `tier3` on any marker written today as **unreached**, not zero-evidence-against.
🟥 **This same false claim stood in ~~three~~ ~~FIVE~~ → EIGHT passages across SIX files, and the
count itself has now been wrong three times — corrected 2026-08-23.** The line first said three, was
corrected to FIVE (`CLAUDE.md` twice, here, `AGENTS.md`, `field_verdict_crossfamily_gate.md`), and
**that enumeration was also incomplete and partly unexecuted** — while a *different* file
(`harness_incubator_doctrine.md`) was independently counting the same propagation as **six documents**
on the same day. Two counts of one propagation, in one repo, neither matching. A widened-vocabulary re-scan (the earlier sweeps grepped
only `0줄|zero lines`, i.e. **the repair's own vocabulary** — `[[feedback_lane_vocabulary_blind_to_its_own_fix]]`)
found:

| # | Passage | State when re-scanned 2026-08-23 |
|---|---|---|
| 1 | `CLAUDE.md` §자기 대조 (the axes-run paragraph) | 🟥 **still false** — listed as fixed, never was. Fixed 2026-08-23 |
| 2 | `CLAUDE.md` §Standpoint-Execution-Evidence pointer | ✅ correct since 2026-08-20 |
| 3 | here (§`standpoint:`) | ✅ correct since 2026-08-20 |
| 4 | `AGENTS.md` §markers | ✅ correct since 2026-08-20 |
| 5 | `field_verdict_crossfamily_gate.md` | 🟥 **still false in different words** — its own correction re-introduced the claim as *"the **value** is unvalidated"*. Fixed 2026-08-23 |
| 6 | `fh_three_layer_canon.md` §95 | 🟥 **never on the list at all.** Fixed 2026-08-23 |
| 7 | `fh_three_layer_canon.md` §354 (the field table) | 🟥 **never on the list at all.** Fixed 2026-08-23 |
| 8 | `harness_incubator_doctrine.md` (cites the claim as its day-one-walk example) | ✅ corrected 2026-08-20 — **and it is the file whose own tally said «six documents»**, counting itself. This list did not count it. Reconciled here |

**Excluded on purpose, not missed**: `plugins/fh-meta/CHANGELOG.md` carries the claim inside a dated
release entry. A changelog records what was believed at ship time; rewriting it would destroy the
history this repo's correction discipline depends on. It is listed here instead.

**Three lessons, and the third is new.** ⑴ Fixing one and stopping is the half-fix propagation
failure; fixing three and stopping was the same failure one round later; **enumerating five and
executing three is that failure wearing a checklist.** ⑵ The question is never "is this sentence
wrong" but **"where else does this sentence live"** — and both times the answer came from a
different-family reviewer, not from me. ⑶ 🟥 **A propagation sweep must not be run in the vocabulary
of the thing it is fixing.** Sites 5–7 survived three rounds because they said *"unvalidated"*,
*"검증하는 코드가 아직 0줄"* inside a fenced table, and *"the value is unvalidated"* — none of which a
grep for the first site's phrasing reaches. **Widen the axis before declaring a sweep complete, and
say which terms you searched.**

**`thirdparty:` — ⓓ3자 대면의 자기 필드 (2026-08-17 신설).** ⓑ가 `standpoint:` 를 갖는 것과
같은 형태다: `axes-run` 에는 포인터(`ⓓ=→thirdparty`)만 두고 값은 이 필드가 나른다.

🟥 **이 축은 반쪽이 아니라 둘이다 — 규격이 한쪽만 인코딩하고 있었다(2026-08-17 정정).**
6축 정본(`knowledge/shared/harness-core/fh_three_layer_canon.md:243`)은 ⓓ가 받는 것을
**«문제 + 남의 코드베이스»**로 정의하고 **두 질문**을 묶는다:

| 반쪽 | 질문 | 값 |
|---|---|---|
| ① 선행자산 | **이미 풀린 문제 아닌가** | `checked` · `none-found` |
| ② **하네스 단위 적대검증** | **내 변경이 남의 레포/입장에서 어떻게 보이나** | `peer-review` ← **신설** |

②의 정본 형태(운영자, 2026-08-17): *"qasp 개선건에 대해서 **지스택에 소넷을 넣고 지스택 하네스
페르소나로** qasp 개선건을 리뷰하고 검증하는 것 — **계열을 넘어선 하네스 단위의 적대검증 스코프**."*
**FH 는 governor 로서 그 상황을 만들고·관측하고·판정한다.** 4축 게이트가 검증하는 대상은 그
제3 하네스가 내놓은 **의견**이고, 그 판정은 **FH 로컬**에서 이뤄진다 — 남의 레포에 게이트를
거는 것이 아니다.

⚠️ **②가 왜 빠져 있었는지가 실측으로 드러났다**: 규격에 ①만 있으니 코퍼스 6건 중 peer 가 쓴
4건은 전부 ① 형태였고, ②에 가까운 것을 적으려던 2건은 **enum 밖 자유 산문으로 샜다.** 이 필드가
신설된 사유(*「적을 자리가 없다」를 벗는다*)가 **한 칸 안쪽에서 재발한 것**이다.

🟥 **그리고 ②는 정의상 «남의 레포 스코프»다.** 게이트 스코프가 자기 자신으로 묶여 있으면 이 축은
**구조적으로 기록될 수 없다** — 정본 §170 의 «ⓓ 자기 스코프가 가장 나빴다» 실측과 같은 자리다.

🟥 **정정(2026-09-04, six_axis_review 판정안 6 — append-only, ①②표·값·아래 예시는 안 지운다).**
전수 실측(마커 169개)이 ②(`peer-review`)를 코퍼스 **6/102** 로 세었다. 이 정정은 그 6건을
지우지 않고 **②의 정의상 소속을 옮긴다**: 피어 하네스 세션이 리뷰를 낸다는 것은 «패널에 다른
계열의 멤버가 하나 더 붙는다»와 같은 모양이라, **②는 ⓐ 계열 축의 패널 분류(`crossfamily:
panel(<families>)`) 안으로 접힌다** — `fh_three_layer_canon.md §1-a-2` 의 ⓓ 정의 절 참조.
**ⓓ 는 이제 ①선행자산 확인만 자기 것으로 남긴다.** `peer-review` 값과 위 표는 삭제하지 않는다
(기록·enum 멤버 보존) — 좁아지는 것은 «이 값이 어느 축 소속인가»라는 정의 문장뿐이다.
**하류 훅 무변경**: `validate_thirdparty_leg` 은 `thirdparty:` 필드의 존재만 보고 ①/②를 구분해
검사하지 않으므로, 이 정정은 아무 레인도 건드리지 않는다.

```
thirdparty: peer-review(<하네스>/<페르소나> → <대상>, <무엇이 돌아왔나>)
                                            ← ② 하네스 단위 적대검증. 계열을 넘는다
                                              예: gstack/harness-persona → qasp, 경계 가정 2건 반증
thirdparty: checked(<무엇을 검색했고 무엇을 찾았나>)
thirdparty: none-found(<무엇을 검색했나>)   ← 찾았는데 선행 없음. «안 봤다»와 다른 명제다
thirdparty: DEGRADED_NO_ACCESS(<사유>)      ← 못 봤다 (검색 수단 부재)
thirdparty: DEGRADED_NOT_RUN(<사유>)        ← 안 돌렸다
thirdparty: UNKNOWN                         ← 안 봤다
thirdparty: not-applicable(<사유>)
```

🟥 **왜 `axes-run` 한 칸으로 부족한가.** 그 칸은 **토큰**을 담는데, 이 축이 실제로 내는 것은
«무엇을 검색해서 무엇을 찾았나» 라 한 토큰에 안 들어간다. **자리가 없으면 안 적히고, 안 적히면
다음 세션이 «이 축을 돌렸나»를 물을 수도 확인할 수도 없다.**
실측 근거(2026-08-17): 이 축을 처음 제대로 돌린 세션에서 **발표 주장 6건이 선행자산에 걸렸다**
(mutation testing · Anthropic skill-creator 블라인드 · Claude Code auto mode · Self-Harness ·
공식 cross-family 플러그인 · constrained decoding). 그 전까지 이 레포 전체 마크다운에서
`promptfoo|DeepEval|Inspect|garak|PyRIT|mutation testing` grep 히트는 **1줄**이었다 —
축은 정본화돼 있었는데 **기록면이 없어서 습관이 안 생겼다.**

**degrade 3값 분리는 `crossfamily:` 를 그대로 상속한다** — 못 봤다 / 안 돌렸다 / 안 봤다는
서로 다른 명제이고, 자유 산문은 그 셋을 접는다. 접히면 «안 돌린 축»이 «선행 없음»으로 읽힌다.

**검증 범위(오늘 기준)**: 훅은 ⓑ와 동일하게 **포인터가 가리키는 필드의 존재**만 본다.
enum 값 검증은 안 한다 — `standpoint:` 와 같은 유보이고, 같은 이유다(첫 거짓 값이 기록되면
그때 기계화한다). ⚠️ ⓑ가 겪은 **화살표 fail-open 도 같이 상속해 미리 막았다**: 화살표를
필수로 보지 않고 «ⓓ 값이 thirdparty 를 참조하는가»로 본다. 같은 명시 잔여(참조어가 다른
토큰에 있으면 미검출)도 그대로 남는다.

**Scope, unchanged**: form + non-vacuity + auditability, **never provenance**. A marker claiming
`ⓐ=codex` when codex never ran passes — deliberately. Catching that is cross-family review *reading*
the marker, which is not this hook's job.

> Fixtures: `scripts/test_marker_axes_run_lanes.sh` (25 lanes, incl. wiring anchor + over-block
> controls). Extending the format means adding lanes there, and running the **revert probe** — a
> lane that stays green when you disable the branch it claims to anchor is decoration.

### Reviewer-visible evidence — the marker is not readable from the other side

**Rule**: a PR touching FH assets carries a **sanitized evidence capsule** in its body — what was
run, what it returned, what was found and closed — plus, for any verdict reported as a **grade, tier
or code**, both the **inline expansion** and the **canonical definition's location**
(`sim grade F = Functional/PASS — scale: sim-conductor SKILL.md §Area-D`). A bare letter is not a
verdict to anyone outside the author's vocabulary, and a decoded letter is still only *semantics* —
it says what the grade means, never that the run produced it. Keep those two separate.

**Never paste the raw marker.** Write the capsule; do not copy the file. The marker is a local
artifact that may quote paths, hostnames, internal asset names, or unredacted findings, and
**§Company residency forbids those reaching a log, comment, or paste** (`CLAUDE.md` — "not into a
log, comment, or paste"). A PR body is a paste on a public surface. This matters mechanically, not
just in principle: the pre-commit confidentiality guard scans **staged tracked content** and has no
view of PR-body text, so a body is *outside* the repo's mechanical privacy floor. Run the
public-surface scan over the capsule text before creating or editing the body. (Cross-family review
2026-07-30 caught this: the first draft of this rule said "inline the evidence itself", which pointed
authors straight through that gap — the residency floor and the reviewer-visibility goal were pulling
in opposite directions and only one of them had a hook.)

**Why this is structural, not politeness**: the marker file itself is **gitignored by design**
(`.gitignore` `tracks/**` — verify per file with `git check-ignore -v <marker>`; a couple of
force-added files elsewhere under `tracks/_meta/` do not change it for markers). So the
machine-checkable evidence for a change exists only on the author's machine — a reviewer on another
session, another worktree, or another runtime **cannot reach it**.
The gate is satisfied and the reviewer still has nothing but prose. This is the same shape as the
gate-locality defect (a gate placed where the actor that needs it cannot read it), one layer over:
**evidence placed where the reviewer cannot read it**.

**Measured 2026-07-30 (PR #205, a Codex-authored change reviewed by Claude)**: the PR body reported
`salience cold-start simulation: grade F`. The reviewer could not resolve it — the marker was in a
gitignored path inside the author's worktree — and recorded it as UNVERIFIED. `F` in fact meant
**Functional**, the PASS grade of sim-conductor's Area-D consumer scale
(`plugins/fh-meta/skills/sim-conductor/SKILL.md` §Area-D — `F` functional / `P` partial / `B` broken),
i.e. the sim had *passed*. Two failures, one on each side, and the rule addresses both: the author
reported a coded verdict without its scale, and the reviewer's own grep surfaced the defining file
and the reviewer did not open it. **A pointer your instrument hands you is not optional reading.**

**Degrade direction — and it does NOT satisfy the rule.** Evidence that cannot be sanitized into a
capsule is declared, never dropped, and never silently counted as met:

```
LOCAL-ONLY ATTESTATION — UNVERIFIED: <one-line result> (record: local marker <name>)
```

That line is **an author's claim, not reviewer-visible evidence**. It leaves the requirement
*unmet*, and the PR proceeds only by one of: a sanitized reproducible capsule · an authorized
independent review on a machine that can read the record · explicit operator acceptance of the
unverified state. Silence reads as verified, which is why the label is mandatory — but the label is
an honest gap, not a way to close one. **Never restate a local-only result as though the reviewer
confirmed it**, and note that inlining a marker field proves nothing about provenance either: the
marker's own scope is form + non-vacuity + auditability, **not** that the run happened (see the
marker-scope note above).

**Enforcement boundary — say which half is mechanical.** An earlier draft of this rule claimed no
hook could enforce any of it. That was overbroad: **presence and syntax are mechanizable** — a
`pull_request` CI status can check that an applicable PR carries a capsule, that graded verdicts are
expanded, and that a local-only attestation is labelled; a local `gh pr create/edit` wrapper can run
the private-pattern scan that public CI cannot (public CI must never hold the private patterns).
What stays un-mechanizable is **truth and provenance** — whether the capsule describes a run that
actually happened. Neither anchor is built today; that is a named residual, and a rule that
over-claims its own floor is the defect this file exists to prevent.

> **Detail**: See `knowledge/shared/harness-core/claude_md_gate_details.md §Sim-Dispatch-Fallback` — the
> headless `claude -p --model` fallback when in-session model-pin is unavailable, the saturation-disguise
> retry (compact-then-retry once), and the credit-pool caveat — read when a model-pinned dispatch fails.

**Measurement-integrity pre-flight**: when the sim/dispatch is a *cross-model measurement* (pinned to a
tier, comparing model behaviors, or feeding a published claim), **the instrument must be verified before
the measurement is trusted**.

> **Detail**: See `knowledge/shared/harness-core/measurement-integrity-checklist.md` — pin the display
> name not a slug (silent fallback to a weaker model is a measured failure) · reps ≥ 3 on any
> borderline/contested verdict (single draw = noise) · use a discriminating identity probe (a generic
> "OK" proves nothing about which model answered) — read **before** running any cross-model measurement.

**Floor-tier canary (optional pre-screen — token-free, *below* the Sonnet sim)**: a local model ≤ Sonnet
can blind-pre-screen a salience-dependent edit before the Sonnet dispatch is spent. **Canary, NOT gate**:
a PASS adds cheap floor confidence and you still run the Sonnet sim; a FAIL never blocks alone. The
terminal verdict stays with the **Sonnet-or-higher governor bound to a mechanical anchor** — **no
judge-only path**, no weak-local-judge regression of the judge-robustness principle.

> **Detail**: See `knowledge/shared/harness-core/claude_md_gate_details.md §Floor-Tier-Canary` — the local
> model/panel options, the blind-probe procedure, dogfood evidence, and the FAIL-triage (real salience gap
> vs floor-model quirk) — read when running a floor canary.

### Added-Scope Gate — before you attach anything to a fix

A fix arrives with a stated job. Everything you attach beyond that job is **new surface that the
adversarial rounds must then verify**, and it is charged to the fix's schedule and to whatever the fix
was blocking. Before adding, answer two questions in writing:

1. **"What can I not do without this?"** — no immediate concrete answer means it is not needed *here*.
2. **"Is this the same change?"** — a real answer to (1) that names a *different* job means it is a
   separate change, not an addition. Ship the fix; open the other thing.

Both must pass. (1) alone is the trap: a genuinely useful addition passes (1) and still belongs
elsewhere.

**A construct and the wiring that makes it reachable are ONE change.** Question (2) answers *same
job* for a caller, a hook line, a package-manifest entry, or a propagated copy of the fix — none of
those is separable scope. Splitting them is not scope discipline, it is
[[feedback_built_but_not_wired]] and [[feedback_half_fix_propagation_boundary]], which this repo has
already self-reproduced. If you build a checker and defer its caller, you shipped prose. The gate
below trims what you *attached*; it never licenses shipping something unreachable.

**Measured 2026-08-02 (PR #231).** The stated job was one flaky test lane — a blocker holding two
other PRs. Attached to it: a production advisory probe, its hook surfacing, a new caller wiring, and a
measurement probe. Each passed (1) on its own. Round-by-round attribution of the 12 adversarial
findings: round 1's 4 were in the original fix; **rounds 2, 3 and 5 found defects exclusively in code
the previous round had added**, and 2 of the cross-family round's 3 traced to the attached scope. The
original fix needed roughly one round. The other four rounds were the bill for scope that would have
passed (2) as its own change. The additions were not wrong — bundling them was.

Read that example precisely: the splittable items were the **advisory probe and its measurement** —
a new capability with its own job. The *hook line that surfaced the probe* and the *caller that
invoked the new anchor* were not splittable and were correctly shipped **with the probe, into
whichever change carries the probe** — not left behind in the fix, which would ship a hook line that
surfaces nothing.

**Relationship to Wave-T (`steel-quench`)**: Wave-T measures complexity the *quench* added, after
convergence. This fires earlier and on a different axis — scope the *author* added, at authoring time.
Do not collapse them; a change can pass Wave-T (every construct traces to a finding) and still have
been the wrong change to bundle.

**Axis ownership** (each skill is already complete — orchestrator only coordinates):

| Axis | Skill | What it catches |
|---|---|---|
| Backward | `templates/regression_guard.sh` | Critical section loss, broken refs, syntax errors, line reduction |
| Adversarial | `steel-quench` | Trigger phrase collisions, design attack surface, over-engineered steps |
| Forward | `phantom-quench` | Phantom references, paths that don't exist, stale external links |
| Record | `edit-manifest` RECORD | Logs predicted impact — closes the predict-verify loop for future harvest-loop |

**Cross-family complement (Axis 2, autonomous when consented)**: `steel-quench` dispatches in-session at the
session tier — **same family** as the governor, so it shares the governor's blind spots. For a **load-bearing**
change (gates · irreversible-surface code · doctrine), `auto-decorrelation` is the standing cross-family
verifier: it recruits ≥1 **different-family** auditor when the sidecar panel is discoverable, and degrades
honestly to single-session when none is. **Autonomous once the operator has consented** (one-time, in the
UAP — `[[user_adaptation_profile]]`); the governor keeps the terminal verdict and **source-grounds** every
sidecar finding before acting on it (`[[feedback_judge_robustness_mechanical_anchor]]`).

> **Detail**: See `knowledge/shared/harness-core/claude_md_gate_details.md §Cross-Family-Complement` — the
> UAP sidecar mapping (which family for which task class) and the 2026-06-27 dogfood evidence — read when
> recruiting or configuring a cross-family auditor.

### Mode D Model Notice (fires once, at the same trigger as this gate)

When FH self-dev begins (an FH asset is about to change), check the **session model** and surface **one
line**, then proceed — never block, **never switch the model** (human override inviolable): opus-tier+ →
no notice · below-opus → **dispatch-first recommend** (keep Sonnet + route depth turns to sidecar/opus
dispatch; `/model opus` pin = secondary — `sonnet_floor_doctrine.md`) · unknown → static fallback recommend. Once per session;
field-project (non-FH-asset) sessions never see it. Whether a session actually *escalates* (not just this
advisory) is governed separately by `capability_escalation_consent.md`.

> **Detail**: See `knowledge/shared/harness-core/claude_md_gate_details.md §Mode-D-Model-Notice` — the
> exact 3-branch wording (한글), the full guards, and the capability-escalation-consent cross-ref — read
> when surfacing the notice.

---

<!-- Relocated from always-loaded CLAUDE.md 2026-07-20 (Fable residency judgment, rank 2).
     ①파일 트리거(신규/편집 SKILL.md) ②기계 백스톱 검증됨 — pre-commit:105 가 어떤 SKILL.md
     경로에도 4축 전체를 발동하고, :552-558 에 신규스킬 count-consistency 슬라이스가 따로 있다.
     glob 은 신설이 아니라 이 파일 frontmatter 의 기존 plugins/**/SKILL.md 를 재사용한다.
     잔여: paths: 는 read 트리거라 '스킬을 맨바닥에서 Write 로 만드는' 경로엔 안 실린다 —
     오늘 아침 4축 분리가 수용한 것과 동일한 잔여이고 floor 도 동일(pre-commit). -->

## New Skill Creation Pre-Commit Gate

All 6 items below must pass before committing a new SKILL.md. If any fails, fix and re-commit.

| Item | Criterion |
|---|---|
| **Role duplication check** | Pass `/asset-placement-gate` — no overlap with existing role clusters, **platform built-ins (Tier 0), or `claude-plugins-official` (Tier 1 official)**. Reinventing an official capability requires explicit justification in the SKILL.md (no-reinvention rule — FH builds only what adds governance) |
| **Description diet** | Plain text / 0 self-marketing expressions / 0 emphasis words (⭐, "critical", "groundbreaking") |
| **Done When defined** | At least 1 explicit completion condition |
| **Check-class declared** | Each Done When condition states its check class — mandatory-pass / measured / judged (`harness_6axis_framework.md` §Axis 5). Any judged condition names its adversarial pairing — no judge-only path |
| **Natural language triggers** | At least 3 examples that work without internal vocabulary. This is a **form** check (judged — do the examples avoid internal jargon). For a load-bearing gate/router skill it can be upgraded **judged → measured** with steel-quench's `Step 0.5 — Trigger-Accuracy Probe` (a dispatched should-fire / near-miss-should-not-fire fire-count), turning "do these triggers collide?" from a guess into a number. Optional for ordinary skills; recommended when the skill is a routing/gate surface |
| **Independently executable** | Confirmed to work without other FH skills (or dependencies are explicitly documented) |

Skills without a Done When definition automatically qualify as harness-doctor L2 M-tier.
Check-class declaration applies to **new** skills; existing skills backfill opportunistically
(when next edited), not retroactively. **Obligation (always-loaded):** a **routing/gate skill** (primary
output = a dispatch decision or pass/block verdict) owes a **one-time `Step 0.5` baseline trigger-probe**
at the next `harness-doctor` run **and a re-probe whenever its trigger phrases change** — not optional for
that skill class, and not a retroactive sweep of all routers.

> **Detail**: See `knowledge/shared/harness-core/claude_md_gate_details.md §New-Skill-Backfill` — the
> probe mechanics (fire-count procedure), the baseline-floor rationale, and the mechanical "routing/gate
> skill" test — read when editing a router/gate skill.

---
