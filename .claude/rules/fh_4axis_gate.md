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

### Marker axis fields — `axes-run:` · `controls:` · `standpoint:`

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
swaps two axes, and no error fires. This is why the **notation itself declares the array**: ASCII
keys = old 4-axis, circled keys = current 6-axis. A reader (or an auditor grepping 190 markers) can
tell which array a marker used without asking its author.

- **ⓑ입장 carries a pointer, not a value** — `standpoint:` is its canonical field, so writing the
  value in both places would be a double record. `ⓑ=→standpoint` requires a non-empty `standpoint:`
  line to exist (a pointer at nothing is not a record). Enforced on any ⓑ value *referencing*
  standpoint, arrow or not — requiring the arrow was fail-open and was measured as such.
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
`knowledge/shared/harness-core/field_verdict_crossfamily_gate.md §7`. **Still validated by nothing**
— zero hook lines, no fixture suite. Recorded here so the gap is visible from the rules side rather
than only from the hook's absence.

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
