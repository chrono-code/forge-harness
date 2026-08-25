---
name: steel-quench
description: >-
  All-angle verification meta-skill for near-complete artifacts. Turns vague design
  anxiety into structured challenger waves using fh-commons:quench-challenger, then
  drives defense and convergence until root weaknesses, residual risks, and added
  complexity are explicit. Covers standard attack/defense rounds, optional
  Meta-Aware Adversary mode for AI-specific risks such as hallucination, context
  collapse, prompt injection, and tool lock-in, and Wave-P3 re-attack after an
  upstream gate declares PASS. Built-in outputs emphasize attack-plus-prescription
  pairs and can feed fh-meta:persona-innovator after convergence. Triggered by:
  "quench this", "devil's judgment", "all-angle review", "end-to-end verification",
  "steel quench", "deep pre-completion inspection", "did it really pass?".
user-invocable: true
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "WebSearch", "Agent"]
model-note: session-inherit — Sonnet base is first-class (sonnet_floor_doctrine.md); depth-critical judged steps route to dispatch (opus agent / cross-family sidecar, consent-gated), never a substrate requirement
---

# steel-quench — All-Angle Verification Meta-Skill

> Heating steel and plunging it into water brings internal defects to the surface. quench-challenger attacks → defense → repeat = systematic surfacing and elimination of design flaws.

A designer's anxiety is most dangerous when vague. steel-quench breaks that anxiety into concrete attack angles, defends against them, and closes with residual risks explicitly stated.

> **Scope boundary**: steel-quench stress-tests a **near-complete artifact** (post-build). For pre-build design decisions → `deliberation`. For completed-asset validation → `sim-conductor`.

## Trigger Phrases

| Phrase | Situation |
|---|---|
| "quench this", "run quench" | All-angle verification just before completion |
| "devil's judgment" | Focused challenger attack on specific design decision |
| "all-angle review", "end-to-end verification" | Full project scope verification |
| "shake out design anxiety", "deep pre-completion inspection" | Concretize vague anxiety |
| "attack from the root" | Re-verify from reason for existence |
| "diagnose with counterexample", "use this bad case as reference" | Phase 0 calibration |
| "did it really pass?", "re-attack after the gate", "the gate said PASS" | Wave-P3 gate-passage re-attack |
| `/steel-quench` | Explicit call |

---

## Wave Structure

| Wave | Role | Termination |
|---|---|---|
| **Phase 0** (optional) | Counterexample calibration — extract patterns from external bad cases, merge into Wave 1 (→ `SKILL_detail.md §Phase0`) | No external case → skip |
| **Wave 1** | Challenger attack (quench-challenger) — surface critical flaws, no defense | — |
| **Wave 2** | Defense — defend or state as residual risk | — |
| **Wave 3+** | Convergence — repeat until a round is clean AND triggers no repair | Zero new S/A **and no repairs made in response, B included** (§Convergence Criteria) |
| **Wave 4** (optional) | Meta-Aware Adversary — AI uses its own nature as attack vector | Wave 3+ criterion (clean + no-repair) + AI-specific criteria |
| **Wave-P3** (optional) | Gate-passage re-attack — when an upstream gate declares PASS, re-attack the just-passed artifact on Coverage / Narrative / False-confidence | All 3 dimensions Attack Failed |
| **Wave 5** (optional) | Multi-Team Adversarial Panel — external CLIs or cross-session Claude | Wave 3+ criterion, cross-team |
| **Wave-T** (after convergence) | Temper — measure complexity the quench *added*; flag over-hardening | τ-PASS or named τ-FAIL |

> **Detail**: See `SKILL_detail.md §Phase0` — counterexample calibration full spec (pattern extraction from an external bad case, merge rules into Wave 1) — read when an external bad case is supplied.

**Zero-finding wave names its angles (2026-08-26).** A wave reported as clean (0 new findings) must
state *which attack angles actually ran and which did not* (e.g. `clean (돌린 각: #1 단순대안 · #3
실사용 — #5 미실행)`), never a bare "clean". A clean round means «these angles found nothing», not
«nothing is there» — a different perspective can still find new issues (externally replicated:
edgelog ~400-call measurement, 2026-08-25 digest, finding ⓔ). Same discipline as the marker's
`axes-run:` — silence is not zero. **This is a record requirement, not a new termination rule**: the
§Convergence Criteria verdict (zero new S/A + no repairs) is unchanged — what changes is that an
unnamed clean round is an *incomplete record*, so a reader auditing convergence can see which angles
each clean round actually covered instead of assuming all of them ran.

---

## Step 0.3 — Artifact Vulnerability Profile

> **Schema**: `knowledge/shared/harness-core/tpa_schema.md` — canonical artifact_type/risk_level/phantom_risk derivation, gate routing, meta-harness broadcast multiplier.

Runs when steel-quench is invoked without a specific wave restriction.
Skip if user specifies exact waves (e.g. "run Wave 1 and Wave 4 only").

Read target artifact → classify vulnerability surface:

| Dimension | Signal → Wave weight shift |
|---|---|
| `artifact_type` | SKILL.md/design-doc → Wave 2 (structural defense) weight↑ · bash/code → Wave 1 (real-code) weight↑ · external publish imminent → Wave 5 (cross-team) weight↑ |
| `phantom_risk` | citations/arXiv/DOIs/http URLs present → Wave 3 (source-grounding) weight↑ |
| `claim_density` | 3+ benefit claims → Wave 1 U3 (evidence grounding) angle weight↑ |
| `novelty` | first-of-its-kind pattern → Wave 4 (convergence) weight↑ |
| `scope` | internal-only doc → Wave 5 (external CLI) weight=0 (skip) |

Wave selection output:
```
Run:  [list of selected waves with rationale]
Skip: [list of skipped waves with reason]
External CLIs available: [yes/no → Wave 5 available]
```

**Degraded coverage rule**: if a high-weight wave or capability is skipped (user choice, unavailable tool, or scope=internal) **or runs below its declared model-tier floor** (tier-floor resolution, `multi_model_sidecar_strategy.md §Tier-floor`), flag explicitly in the output header — do not silently proceed. Below-floor example: `challenger: sonnet (below-floor; floor=opus)`; a judged verdict produced below floor is a re-quench candidate once a floor-tier is available.

---

## Step 0.35 — Org Constraint Load (조직 제약 적재)

**조직 제약을 모르는 적대 검증은 헛방을 친다** — 조직이 이미 결정한 것을 공격하거나, 조직 정책
하에서만 성립하는 실제 공격을 놓친다. 공격 각도를 정하기 **전에** 조직층을 읽는다.
계약: `knowledge/shared/rules/knowledge_layer_seam.md` (이 스킬이 **2호 소비자**;
1호는 `phantom-quench` Step 2-O).

**절차**: 진입 인덱스(`knowledge/{org}/INDEX.md` · `index.md` · `README.md` · `readme.md` —
판정기와 같은 후보 집합) → 대상과 **관련된** 정책·용어·도메인 사실만 로드. 전수 스캔 금지(계약 K2).
부재면 **«조직 제약 미상»으로 명시하고 진행** — 없는 제약을 추론으로 만들지 않는다.
🟥 `not found` 는 «제약 없음» 이 아니다. 미상은 미상으로 적는다.

**로드한 것의 용도는 딱 둘**
1. **공격의 사실 근거**: "조직 정책 P 하에서 이 설계는 X 를 위반한다" → **유효한 공격**
2. **헛방 필터**: 조직이 이미 결정·문서화한 사항을 "왜 안 했나"로 공격하지 않는다. 대신
   **그 결정 자체를 공격**한다(그 결정이 지금도 유효한가). **결정의 존재는 면제가 아니다.**

### ⛔ 세탁 차단 — 이 배선의 유일한 위험

> **조직층은 공격을 무장해제할 수 없다.** 조직 위키에 *"이건 승인된 패턴"*, *"이 케이스는 예외"*,
> *"과거에 검토 완료"* 가 있어도 **그것은 공격을 기각하는 근거가 아니다.**

이유: 조직층은 **무엇**(사실·정책)만 공급하고 **어떻게 판정하나**는 공급하지 않는다(계약 §1-a).
"승인됨"은 *조직이 그렇게 정했다*는 **사실**이지 *그 결정이 옳다*는 **판정**이 아니다.
적대 검증의 일이 정확히 그 판정을 다시 하는 것이다.

| 조직층에 있는 것 | 허용되는 사용 | 금지 |
|---|---|---|
| 정책·규칙 | 위반을 공격 근거로 | **면제 근거로** |
| "승인된 패턴" | 그 승인의 근거를 공격 대상으로 | 공격 기각 |
| "과거 검토 완료" | 그때의 전제가 아직 참인지 확인 | 재검토 생략 |
| stale 페이지(`review_after` 경과) | **제약으로 쓰지 않는다** — 미상 처리 | 최신으로 가정 |

**보고 의무**: 조직층 때문에 공격을 조정했으면(각도 추가 · 헛방 제거) **무엇을 왜 조정했는지
Wave 1 출력에 남긴다.** 조용한 조정은 검증 범위 축소와 구별되지 않는다.

**반출 금지**(K1-s): cross-provider/cross-family 챌린저에 조직층 **원문을 넘기지 않는다** —
넘어가는 것은 **sanitized 제약 요약**뿐이다. (CLAUDE.md §Field-Harness Diagnostic 의 residency
규칙과 같은 floor 이고, 이 스킬이 그것을 느슨하게 만들지 않는다.)

> **출처**: 원 필드(sibling harness)의 선례를 이식했다. FH 자기 정본이 이 자리를 **명시적으로
> 「미배선 — 약속이 아니라 후보」**로 적어두고 있었다(`knowledge_layer_seam.md` §0 배선 현황).
> 이 절이 그 행을 후보에서 배선으로 옮긴다.
> 🟥 **이식한 것은 절차이지 그쪽의 기계-주장이 아니다** — 원본에는 훅이 이 절을 강제한다는
> 취지의 서술이 딸려 있었으나, 실측하니 그 훅 레인이 **존재하지 않았다**(`axis2-defense` 훅 히트 0,
> 컨트롤 `crossfamily` 21). 그래서 **강제 서술은 안 가져왔다.** 이 절은 오늘 기준
> **살리언스 층이고 기계 바닥이 없다** — 그렇게 적는 것이 팬텀을 들여오지 않는 유일한 방법이다.

## Step 0.4 — Specialized Reviewer Discovery

For the target artifact, scan installed agents for a domain-specific adversarial reviewer:

1. Check `.claude/agents/` for a reviewer matching `artifact_type`
2. Built-in fallback: `fh-commons:quench-challenger` (general-purpose adversarial review)
3. GAP for high-risk artifact: query `/plugin-recommender "adversarial reviewer for [artifact_type]"` → user: install / skip / use fallback

> **Sidecar availability** for a cross-provider challenger (Gemini/Codex, Wave 5) is resolved via the Tier 1→2→3 recipe in `knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Sidecar Engine Resolution Protocol`; Tier 3 = the `fh-commons:quench-challenger` Claude sub-agent below (guaranteed fallback — same-provider, so model-access not cross-provider diversity).

**Runtime adapter note**: In Claude Code, invoke the fallback as an isolated `Agent(subagent_type="fh-commons:quench-challenger")`. In Codex-primary or other non-Claude runtimes, use the FH adapter instead:

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run \
  --agent fh-commons:quench-challenger \
  --file {target-artifact}
```

Treat the adapter output as the isolated challenger result for Wave 1. This preserves the same workflow without depending on Claude Code's Agent tool.

**Wave 5 activation rule**: Wave 5 (external CLI team) is only activated when `scope` is not internal-only AND external CLIs are available AND risk_level is high or user explicitly requests it.

> **Detail**: See `SKILL_detail.md §ArtifactProfile` — worked examples (SKILL.md, bash script, README, design doc with citations) showing wave selection and rationale — read when classifying an unfamiliar artifact type.

---

## Step 0.5 — Trigger-Accuracy Probe (SKILL.md artifacts only · measured)

> **Import origin** (sister-asset cross-audit 2026-06-14, `tracks/_audit/session_2026_06_14_official-plugins-cross-audit.md`): skill-creator + plugin-dev/skill-reviewer measure trigger accuracy **empirically**; FH's skill gate ("3+ NL triggers") and steel-quench's trigger-collision attack are **judged**, not measured. This probe converts that one verdict to **measured** — the mechanical-anchor discipline (a terminal trigger verdict should rest on a count, not an inference: the W4-4 question applied to the skill's own description).

> **External frame**: treating a trigger/prompt phrase set as a first-class artifact that needs a
> coverage criterion analog to code coverage is the position argued in arXiv:2607.02057, *Prompt
> Coverage Adequacy*. FH's instrument here is a fire-count over should-fire / near-miss phrases,
> not that paper's attention-based test-suite coverage — the anchor grounds the coverage-adequacy
> framing, not a drop-in metric.

**Fires only when** `artifact_type = skill_md` (Step 0.3 canonical enum, `tpa_schema.md` — i.e. a SKILL.md) AND the **trigger surface** changed. *Trigger surface* = exactly the `description:` YAML field **plus** the `## Triggers` / `## Trigger Phrases` section (and nothing else — a body-wave or procedure edit with both of those untouched does **not** fire it). Any other artifact has no trigger surface — note `Step 0.5: skipped (not a skill_md trigger change)` and proceed.

**Procedure** (prose-scale — FH routes + governs, it does **not** rebuild skill-creator's eval engine; no Python harness, no vector store):
1. From the skill's `description`, author **8–10 should-trigger** phrases (varied, realistic user utterances; include some that omit the skill's internal vocabulary) and **8–10 near-miss should-NOT-trigger** phrases (share keywords/domain but actually need a different tool — the discriminating cases, not obvious irrelevants).
2. Dispatch the probe set **in isolation** (`Agent` / `fh-run` — same isolation rule as Wave 1; the author session must not judge its own triggers) against the live skill description only.
3. **Count** and report as measured: `trigger-probe: <fired>/<should> fire · <false>/<should-not> false-fire (model: <tier>)`.

**Verdict mapping** (measured → severity; feeds Wave-T temper + Done When):

| Measured | Verdict | Severity |
|---|---|---|
| should-fire < 70% | **undertrigger** — description too narrow, or diet stripped a real trigger | S if load-bearing gate skill, else A |
| should-not false-fire > 20% | **overtrigger / collision** — bleeds into an adjacent skill's territory (the collision class steel-quench owns, now measured) | A |
| both within bound | trigger surface PASS (measured, not guessed) | — |

**Threshold granularity** (the bounds are guidelines, not a knife-edge): at the probe size (N=8–10 → ~10–12.5% steps) the percentages are coarse and 20%/70% may not be exactly reachable. Report the **count** (`2/8 false-fire`), not just a percentage; on a boundary result take the **stricter** verdict and re-probe with more phrases before finalizing. The bound is a trigger-collision heuristic, not a derived constant.

**Honesty caveat**: the probe measures *trigger-description* accuracy on the session model — not field behavior across all tiers. A near-floor model may under-fire regardless of description quality; record the probe model and, on a below-floor run, treat the result as provisional (Step 0.3 below-floor rule).

> **Detail**: See `SKILL_detail.md §TriggerProbe` — worked probe set + fire-count table + before/after description fix.

---

## Step 0.6 — Verdict-Invariance Probe (load-bearing judged gates only · measured)

> **Sibling of Step 0.5**: Step 0.5 measures whether a skill *fires* on the right utterances; Step 0.6 measures whether a judged gate's *verdict* rests on behavior or on the rubric's phrasing. Cross-family review (auto-decorrelation) lowers correlation between judges but does not test groundedness — two decorrelated families can be swayed by the same wording artifact. This probe converts "is this verdict grounded?" from judged to **measured**: hold the behavior fixed, paraphrase the rubric, count flips.

> **External frame**: content-preserving policy rewrites flip up to 9.1% of LLM safety-judge verdicts above baseline jitter — 18–43% of those flips on *unambiguous* cases (arXiv:2605.06161, *Beyond Accuracy: Policy Invariance as a Reliability Test for LLM Safety Judges*, Weng/Feng/Xie 2026). The instrument here is a flip-count over fixture×paraphrase runs, not that paper's benchmark — the anchor grounds the invariance framing, not a drop-in metric.

**Fires only when** the target is a **load-bearing judged gate** — a rubric whose verdict is a gate enum (PASS/FAIL/BLOCK/allow/deny) **AND whose verdict gates a consequential action** (a FAIL actually blocks a publish/delete/merge, changes a safety outcome, or guards an irreversible surface). The same scope as the Field-Harness Load-Bearing Change Gate. **The enum shape is necessary but not sufficient** (target-tier sim, 2026-07-03): a cosmetic judged Done-When that merely *uses* PASS/FAIL vocabulary but gates nothing consequential ("does the description read well — PASS/FAIL") is **not** load-bearing — confirm a real downstream consequence before firing, or the probe over-fires on gate-shaped-but-inert rubrics. **One-time baseline per gate; re-probe only when the gate's rubric prose changes** (mirror of Step 0.5's re-probe rule). It does **not** fire on ordinary judged Done-When conditions, advisory checks, or prose-only edits that leave the rubric untouched — note `Step 0.6: skipped (not a load-bearing judged-gate rubric change)` and proceed. A gate whose verdict is already bound to a mechanical assertion (fixture test, exit code) has no discretion to probe — skip with that note.

**Procedure** (rides shipped machinery — no new harness, benchmark, or daemon):
1. **Fixtures**: take 2–3 **unambiguous** behavior fixtures — at least one clear-PASS and one clear-FAIL. Reuse the mechanical regression fixtures the gate already ships (the Field-Harness gate's convergence sub-condition requires them); author minimal ones only if absent, and ship them with the gate afterward.
2. **Paraphrase**: generate **K=5 semantics-preserving rewrites** of the rubric prose (reorder clauses, synonym-swap, restructure lists — never add/remove a criterion). Generate the set **cross-family via auto-decorrelation** so the paraphrase distribution is not same-family-biased; degrade honestly to same-family with a logged note if no sidecar is reachable.
3. **Dispatch**: run the gate's verdict on each fixture × each paraphrase (plus the original rubric) through the target-tier sim already used by the 4-axis gate — isolated Agent, `model:` pinned to the tier the gate must survive on; the author session does not judge its own rubric.
4. **Metric**: count verdict flips on the unambiguous fixtures. Report as measured: `verdict-invariance: <flips>/<fixtures×K> runs flipped (gate: <name> · tier: <model>)`.
5. **Record**: write the flip-count into the Axis-2 marker's `axis2-evidence` field (non-vacuous by construction — a count, not "it ran") and emit a one-line **Judge Card** alongside the gate: `judge-card: <gate> · flip-rate <n>/<runs> · fixtures <ids> · <date>`. The card is the baseline the re-probe rule compares against.

**Threshold + verdict mapping** (measured):

| Measured | Verdict | Severity |
|---|---|---|
| ≥1 flip on an unambiguous fixture | **ungrounded** — the verdict tracks phrasing, not behavior; the rubric leaks discretion | S (load-bearing by scope definition) |
| 0 flips across all fixture×paraphrase runs | invariance PASS (measured, not guessed) | — |

**Remediation** (on FAIL, before the gate is trusted): either **bind a fixture-based mechanical assertion** (the fixture that flipped becomes a regression test the verdict must satisfy regardless of prose), or **narrow/shorten the rubric prose** until the re-probe stops flipping. Both moves remove discretion from the prose — the ratchet direction is always toward less judged surface, not more rubric.

**Check class**: measured. **Adversarial pairing** (the probe's own soft spot is "were the paraphrases actually semantics-preserving?" — a corrupted paraphrase manufactures flips): paired by (a) **ambiguity control** — flips are counted only on unambiguous fixtures, where a semantics-changing rewrite would move both fixtures coherently rather than flipping one, and (b) **cross-family paraphrase generation** — the rewrite set is not authored by the family whose verdict is under test. No judge-only path: the terminal artifact is a count over dispatched runs.

**Honest residual (named)**: the probe proves the verdict is **invariant to wording**, not that it is **correct** — a gate can be robustly, invariantly wrong. Correctness stays with fixture ground-truth and the human PR gate; Step 0.6 removes one failure class (phrasing-dependence), it does not certify the rubric.

**Simplicity note** (earned-complexity check, Wave-1 angle #1 applied to itself): net-new surface = a fixture-paraphrase procedure + one threshold. Everything else is already shipped — steel-quench dispatch, the 4-axis target-tier sim, the Axis-2 marker field, auto-decorrelation, and the mechanical fixtures load-bearing gates already owe. Cost converges to zero: baseline once per gate, re-probe only on rubric prose change. Each FAIL's remediation shrinks judged prose or adds a mechanical anchor — the harness gets simpler under measurement, not more decorated.

> **Origin**: proposed by an autonomous innovator scan (Mode F, 2026-07-03), designed by a Fable-5 sidecar, source-verified (2605.06161 numerics confirmed verbatim) before adoption. Orthogonal to today's cross-family gate: that lowers judge *correlation*, this measures verdict *groundedness*.

---

## Wave 1 — 6 Mandatory Attack Angles

**Execution principles**: Attacks must be based on real code/files/configs — abstract criticism prohibited.
Assign severity: **S** (immediate blocker) / **A** (required before deployment) / **B** (improvement recommended).
Call **fh-commons:quench-challenger** in isolation first (6-axis structural attack); apply 6 angles in parallel.

Isolation can be achieved by Claude Code `Agent(...)` or by `fh-run --agent fh-commons:quench-challenger` under Codex. Do not run the challenger inline in the same reasoning pass when the attack result gates the defense.

| # | Attack Angle | Core Question |
|:---:|---|---|
| 1 | **Reason for existence** | "Why this structure? Is there no simpler alternative?" |
| 2 | **Real-use verification** | "Does what's written in the docs actually match the real code?" |
| 3 | **Bus factor** | "Single-person dependency — can it operate if that person is absent?" |
| 4 | **Platform obsolescence** | "Does this structure survive when the external ecosystem expands or changes?" |
| 5 | **Self-referential structure** | "Is there a closed circuit that evaluates itself by its own criteria?" |
| 6 | **Gate-locality** | "Is every safety gate readable by the actor that must enforce it? Name any gate defined only in a file/layer the enforcing runtime never loads (e.g. a rule in a Claude-only `CLAUDE.md` that a Gemini/Codex orchestrator reading `AGENTS.md` never sees; a provenance check described in a doc but absent from the write path)." (see `knowledge/shared/harness-core/gate_locality_principle.md`) |

**S-grade Immediate Human Gate**: If Wave 1 contains 1+ S-grade blocker → pause, surface options (a) proceed to Wave 2 / (b) human review first / (c) abort. Do not silently enter Wave 2 with unreviewed S-grade items.

**Code-artifact supplementary lens — silent-failure scan** (conditional · fires only when `artifact_type ∈ {bash_script, code}` — Step 0.3 canonical enum, `tpa_schema.md`; non-code artifact → note `code-lens: n/a (non-code artifact)` and skip). `artifact_type` is derived from **file path / extension** (`tpa_schema.md` classification rule), **not** interior content — a `skill_md` that embeds a ```` ```bash ```` fence stays `skill_md` and does **not** fire this lens (do not conflate with the CLAUDE.md Substantive carve-out, which keys Axes 2–3 of the *commit gate* off code-fence presence — a different mechanism). Import origin: pr-review-toolkit/silent-failure-hunter (sister-asset cross-audit 2026-06-14, Import #2). Wave 1's 5 angles attack *structure*; this adds the named *error-suppression* vector the general angles miss. Grep the diff/file for each named pattern:

| Pattern | What to flag | Severity guide |
|---|---|---|
| **Empty catch / `\|\| true` / `2>/dev/null` swallow** | An error path that discards the error with no log, no re-raise, no user surface | S if it hides a gate/verification failure, else A |
| **Broad catch** (`except:` / `catch (e)` with no type) | Catches more than intended; masks unrelated failures | A |
| **Unjustified fallback** | Falls back to a default on error without recording *that* it fell back | A — silent degradation is the worst class (cf. P6 graceful-degradation must be *documented*) |
| **Exit-code ignored** | A piped/chained command whose non-zero exit can't propagate (`cmd1 \| cmd2`, missing `set -e`/`pipefail`) | A if it gates a downstream destructive/publish step |

A finding here is a real-code attack (Wave 1 execution principle) — cite the exact line. The lens is a *checklist supplement*, not a 6th mandatory angle: it carries no weight on non-code artifacts.

> **Detail**: See `SKILL_detail.md §Wave1` — Wave 1 output format, optional numeric score, quench-challenger invocation; and `§CodeLens` — silent-failure worked examples (bash + python).

---

## Wave 1-D — Defense Questions (floor tiers · mechanically required)

Three questions, asked of **your own findings and numbers**, before Wave 1 is done. They are written
out rather than left to judgment because that is exactly what makes them portable: measured n=6 in
the origin field, a floor-tier pass executes the attack angles above without defect but **does not
spontaneously ask these three**, while a stronger tier does. That is a **checklist gap, not a
capability gap** — and by `sonnet_floor_doctrine.md` a harness whose behaviour depends on which model
is driving is *defective*, not merely limited.

| # | Question | What a real answer looks like |
|:---:|---|---|
| **재현성** | Can another session reproduce this verdict from the same inputs? | The exact command, or `file:line`, another session runs. "It's reproducible" is not an answer. |
| **비교공정성** | Were the two arms measured under the same conditions? | reps, inputs and environment named for **both** arms. An asymmetry you found and left in place counts — say so. |
| **추정층위** | Is each number a measurement, an estimate, or a quotation? | Which, per number — and for a measurement, what showed the instrument works **on this target** (known-pair). |

**Where the answers go** — one line in the Axes 2+3 marker:

```
axis2-defense: reproducibility=<…> fairness=<…> estimation-layer=<…>
```

**Enforcement, stated exactly.** `templates/.git-hooks/pre-commit` → `validate_defense_leg()` runs
this **at the floor tiers only** (`floor-status: sonnet-floor` or `below-floor`), and checks
**presence · completeness · non-vacuity**: all three sub-answers must exist and `ok`/`yes`/`n/a` is
rejected as a filled form rather than an answer. Fixtures: `scripts/test_marker_defense_lanes.sh`
(17 lanes: known-pairs both directions, two over-block controls, four prescription assertions, and a
call-site pin — because a suite that extracts the function and calls it directly stays green when
the hook stops calling it, which is precisely the failure being imported against).
🟥 **It cannot check whether the answers are TRUE.** That stays with the operator and the weekly
audit, exactly like every other marker field — do not read the hook's PASS as verification.

**Why the trigger is narrow.** `below-floor` occurs **0 times** across the existing marker corpus, so
gating on it alone would be a decoration that never fires; `sonnet-floor` occurs 11. The wide reading
("any marker carrying numbers") is deliberately **not** taken — pricing this axis at a near-universal
rate is the over-trigger `field_verdict_crossfamily_gate.md §7` rejects, and a field required
everywhere becomes a rubber stamp.

> **Provenance, and what was deliberately NOT imported.** Absorbed from a sibling harness
> (2026-08-20). That document additionally amends its floor rule so a below-floor pass carrying this
> line **plus** a crossfamily record passes **without the operator ack**. 🟥 That is a *loosening* of
> an existing FH gate and **was not adopted** — here the leg is purely additive and `below-floor`
> still requires `below-floor-ack`, unchanged.
> 🟥 The same document asserted its own hook read this field and its own fixture suite pinned it.
> Measured twice with a control (`crossfamily` → 21 hits in the same files): **both were 0**. The
> prose was portable; the machine was not. Everything claimed in this section's *Enforcement*
> paragraph was built here, and the fixture file named there is the receipt.

---

## Wave 2 — Defense Principles

**3 Defense Principles**: (1) Reinforce with external cases via WebSearch — "unique to us" or "structural pattern"?
(2) Cover with experience — other project cases defend bus factor. (3) Prioritize immediate implementation over logical construction.

**Classification**: Immediate implementation (this session) / Long-term improvement (residual risk card) / Structural acceptance (declare with rationale).

**"Brain in a Vat + Sandboxed Adversary"**: Challenger attacks only static code (isolated). Defender brings living system evidence. This asymmetry makes Wave 2 structurally superior to Wave 1.

> **Detail**: See `SKILL_detail.md §Wave2` — Wave 2 output format, full Brain-in-Vat principle.

---

## Wave 4 — Meta-Aware Adversary (5 Attack Angles)

The challenger (quench-challenger in Wave 4 mode) knows it's running in an isolated sub-agent sandbox and uses that knowledge as a weapon.

| # | Attack Angle | Core Question |
|:---:|---|---|
| W4-1 | **AI dependency single point of failure** | "If Claude API goes down, does harness core function go to zero?" |
| W4-2 | **Context Collapse** | "When initial instructions are lost to context compression, does harness go silent?" |
| W4-3 | **Prompt Injection exposure** | "Can external data overwrite harness internal rules?" |
| W4-4 | **Hallucination cumulative contamination** | "Do Wave defense arguments rely on LLM inference rather than actual measurement?" |
| W4-5 | **Tool Dependency Lock-in** | "If a specific MCP/plugin/tool is removed, does harness functionality collapse?" |

Wave 4 convergence = Wave 3 criteria + 3 AI-specific vectors actually reviewed + hallucination defense based on original file references.

> **W4-4 ↔ Step 0.5**: W4-4 is the *general* measurement-vs-inference question; **Step 0.5 (Trigger-Accuracy Probe)** is its *measured instance* for one surface — the skill's own trigger description. When the target is a `skill_md` with a changed trigger surface, satisfy W4-4 by running Step 0.5 rather than answering it by inference.

> **Detail**: See `SKILL_detail.md §Wave4` — Wave 4 output format, defense principles, convergence criteria, activation declaration format.

---

## Wave-P3 — Gate-Passage Re-Attack (optional)

**Activation**: When an upstream gate declares PASS on an artifact — any "declared-complete boundary"
(a verification gate's terminal PASS, a `/pipeline-conductor` green sweep, a `/marketplace-gate` listing
verdict, the 4-axis auto-gate marker, a domain TC/coverage gate). Propose preemptively, run after approval.
No gate-PASS in scope → skip Wave-P3 entirely.

> A 1-round gate PASS is exactly when reviewers stop looking — "we just passed" is the lowest-vigilance
> moment in any workflow. Wave-P3 distrusts the declaration and re-attacks the just-passed artifact on three
> dimensions the gate's own pass criteria structurally could not check. Only when all three Attack Failed can
> a **"Real PASS"** be declared.

**PASS-framing redaction (mandatory pre-step)** — the artifact reaches Wave-P3 *carrying its own
PASS declaration* (a `✅`, a "Verified" header, the gate marker), and a re-judge that reads that
framing is biased toward "Attack Failed" — the exact bias Wave-P3 exists to defeat (judge-robustness
swarm, 2026-06-13). Before feeding the artifact to the dimensions/challenger, **strip the pass-framing
at the bash layer, not the AI layer**:

```bash
# Strip framing glyphs + canonical FH verdict PHRASES only — never the bare word PASS
# (a global s/PASS//g corrupts substance: "status==PASS" → "status==", manufacturing findings).
P3R=$(mktemp)
sed -E -e 's/[✅🟩✓]//g' \
       -e 's/(ALL AXES PASSED|FH_GATE_VERDICT:[[:space:]]*PASS|Real PASS|VERIFIED|[Gg]ate[^.]{0,24}declared PASS)//g' \
       "{ARTIFACT}" > "$P3R"
# feed "$P3R" to Wave-P3; clean up after: rm -f "$P3R"
```

Feed `$P3R` to Wave-P3, then `rm -f "$P3R"`. The redaction is mechanical, so it cannot itself be
placated. **Honest scope**: it strips framing glyphs and *canonical FH verdict phrases* — bare-word or
lowercase prose self-congratulation ("this passed review", "looks green") is out of scope for `sed`
and is covered by a prose backstop instead: the Wave-P3 persona is instructed to **disregard any
residual self-pass language in the artifact** and attack as if no verdict were stated.

**Agent utilization**:
- `fh-commons:quench-challenger` (optional) — adds 6-axis structural attack to each dimension, fed the **redacted** artifact. If absent, run the 3 dimensions directly on the redacted copy.
- `fh-meta:persona-innovator` (after convergence) — error/gap patterns found during Wave-P3 → auto-propose new Cross-Project Pattern rows or skill-candidate signals.

The three dimensions generalize the gate's three blind spots:

| # | Dimension | The blind spot it attacks |
|:---:|---|---|
| Wave-P3a | **Coverage** | *What did the gate not check?* Items marked covered/passed that lack a traceable artifact (ID, test, file, citation). |
| Wave-P3b | **Narrative** | *What story does the passed artifact tell that may be wrong?* Residual hardcoded/environment-coupled values and vague, unverifiable claims the PASS declaration smuggled through. |
| Wave-P3c | **False-confidence** | *Did the gate produce false confidence?* High-risk items that passed carrying only a binary pass/fail, with no residual-risk or failure-mode caveat. |

Each dimension is `Attack Succeeded` (defect found) or `Attack Failed` (clean).

**Wave-P3 Done When**:
```
All 3 dimensions [Attack Failed] → ✅ Real PASS → activate fh-meta:persona-innovator (extract new patterns)
Any 1 [Attack Succeeded]        → fix affected items, re-run Wave-P3 (max 2 re-runs)
Still [Attack Succeeded] after 2 re-runs → "gate structural redesign required" → ESCALATE
```

**Basis**: reverse-imported from a field-side sister harness (private companion signal, 2026-06-08). Field
evidence: a test-case coverage gate declared a 1-round PASS, then additional FAILs surfaced in rounds 2–3 —
the gate-PASS-then-defect-found-in-next-stage pattern Wave-P3 collapses. Generalized from the field's
domain-coupled (a spec→test-case gate) form to a gate-agnostic boundary hook. Shares its root with
`fh-commons:convergence-loop` (single-pass distrust).

> **Detail**: See `SKILL_detail.md §WaveP3` — per-dimension attack questions, gap criteria, and output format — read when running a gate-passage re-attack.

---

## Wave-T — Temper (post-convergence)

Quench hardens, but quenched steel is brittle — no smith ships it un-tempered. steel-quench attacks
until a frozen-artifact round is clean; nothing in that loop asks whether the hardening itself **introduced complexity
beyond what the fixes required** (defense scaffolding, decorative wiring). Wave-T is that inverse
corrective. It runs **after Wave 3+ convergence, before Done When**. It does not attack; it measures
the cost of the convergence just achieved.

| Step | Class | What it does |
|---|---|---|
| **T-1 complexity delta** | measured | `bash templates/temper_check.sh <repo> <file> <pre-quench-ref>` — Δlines/sections/steps/tables/fences/cross-refs, baseline (pre-Wave-1) → post-convergence. Prose-only counts: code-fence interiors are excluded (bash comments are not sections) |
| **T-2 absolute context** | measured | `harness-doctor` L1–L3 on the post-quench asset — absolute complexity tier (reuse, don't reimplement) |
| **T-3 τ verdict** | judged — paired with the quench's own Wave findings (each flagged construct must trace to a specific finding it allegedly fixes; no judge-only path) | **τ-PASS**: added complexity ⊆ what the fixes required. **τ-FAIL**: the quench introduced a construct that *defends against an attack rather than fixing the flaw* — name it, propose the simpler form, hand back for de-brittling. τ-FAIL is the temper step working, not a quench failure |

**T-3 heuristic flags** (any → review, never auto-reject): a new section/table/step whose only referent
is a Wave-N finding · Δcross-refs ≫ Δsteps (wiring, not function) · the asset crosses a harness-doctor
complexity tier it was below pre-quench.

**Don't-overbuild guard (τ applied to τ)**: Wave-T is one script + this section, reusing harness-doctor
for the absolute read. If Wave-T grows its own detection engine, it has failed its own test — a temper
step that adds complexity is self-refuting. Known limits (honest): `temper_check.sh` takes one path —
renamed files need a manual pre/post measurement; the wiring flag uses strict `>`, so Δxrefs = Δsteps
does not fire it (the section flag usually carries those cases).

**Model note**: T-1 is bash (no model), T-2 reuses harness-doctor (sonnet-rated). T-3 adjudication was
validated blind on both Opus and Sonnet (3-fixture ground-truth test, 3/3 each, 2026-06-10) — Wave-T
end-to-end does not require the largest model tier. Opus remains the recommendation for full
steel-quench runs (challenger waves are broader than T-3).

---

## External-GT Adjudication (when the target has a public ground truth)

When quenching a **public artifact that has its own ground truth** — a repo's open issues, test suite, or
stated policy/threat-model (a frontier codebase, a sister project — *not* your own in-progress draft) — add
an adjudication pass after the panel produces findings. The panel (Wave 5 cross-family) gives decorrelated
detection; this pass adds the *external check* the panel cannot self-supply. For each finding, classify:

| Class | Test | Meaning |
|---|---|---|
| **Corroborated** | matches an OPEN issue / a failing test | independent rediscovery — strongest |
| **Novel** | no matching issue, but confirmed by logic or a written test | caught what the target missed |
| **Reframe / reject** | the target's own docs/policy/threat-model marks it intentional or out-of-scope | NOT a confident catch — a false positive |

The GT (not a cross-family vote) resolves contention objectively, and it catches the panel's own
**shared training-prior** false positives. Report only Corroborated + Novel as confident catches; a null
result on sound code is the correct answer, not a failure. **Basis**: 2026-06-06 frontier-quench sweep —
a single-family pass repeated still misses what cross-family catches, and a target's `SECURITY.md` reframed
"security" findings to "correctness" (its permission layer was UX, not a boundary).

---

## Cross-Project Common Patterns (initial seed)

| # | Pattern Name | Description | Response Direction |
|:---:|---|---|---|
| P1 | **Single-person bus factor** | System paralysis when core operator absent | Document, automate, formalize delegation |
| P2 | **Doc-code mismatch** | Documented behavior differs from actual code | Re-sync to real code as ground truth |
| P3 | **Self-referential diagnosis** | Creator validates — internal viewpoint closed circuit | Connect external persona or sim-conductor |
| P4 | **No real-use verification** | Theoretically designed but never executed | Mandate 1 cold-start simulation |
| P5 | **Platform obsolescence unplanned** | No response to external ecosystem changes | Quarterly frontier diagnosis |
| P6 | **AI dependency single point of failure** | Claude API/MCP removal causes collapse | Document graceful degradation + fallback |
| P7 | **Hallucination-contaminated defense** | Defense relies on LLM inference, not measurement | Mandate citing original file/commit/value |
| P8 | **Context Collapse unguarded** | Key instructions lost to compression → harness silent | Review CLAUDE.md compact repeated insertion |
| P9 | **Harness-bulk as model compensation** | Pipeline thickened to substitute for a model capability ceiling (a gap no iteration count closes — e.g. domain understanding) — complexity replaces missing capability, violating the field axis "simpler over time" (meta-harness: distinguish from complexity that earns its scope) | Route the task class to a stronger model; never paper over the ceiling with more harness. Signals: steps added for one model's weakness; step count rising while class quality stays flat across iterations |
| P10 | **Untrusted-Boundary Text-Parse Treadmill** (Grep-Collision Treadmill) | A control decision (verdict / pass-block / routing) is grep'd out of free-form text on a boundary that **also carries untrusted content**. Each text-parser patch (anchor-first-line → scan-anywhere → count-headers → render-aware) only **relocates** the spoof — untrusted content can always forge or shadow the parsed token, because verdict and attacker share one surface (the prose/data plane). No terminal state exists *inside the text plane*. | **Bind the decision to a typed, out-of-band channel** (schema-constrained structured output — `--json-schema` / `--output-schema`) the untrusted content cannot occupy; structurally eliminate the format-spoof/grep-collision class instead of patching it. **Residual is named, not closed**: structured output constrains format, not the model's chosen value — and the decoding constraint is itself an injection surface (Constrained Decoding Attack, arXiv:2503.24191) → keep the untrusted-evidence instruction + irreversible-action HITL floor. Signal: a parser fix on an untrusted-content boundary that the *next* adversarial round defeats. Origin: fh-gate.sh verdict parser, 2026-06-26 (frontier-converged: arXiv:2506.08837 Dual-LLM symbolic channel). |

Add new rows as new patterns are discovered.

---

## Done When

```
Wave convergence criteria met: zero new S/A-grade findings in a round that triggered NO repairs at
  any grade (B included — a repaired B is an unverified change, and that is the measured way a
  'clean' round has already leaked an A) — see §Convergence Criteria
+ Residual risk card output (A-grade · B-grade items)
+ "steel-quench Complete" declaration output
```

Verdict: PASS (zero new S/A **and no repairs made in response, at any grade** — §Convergence Criteria; repairing even a B and then declaring convergence is the measured round-4 failure) | CONDITIONAL_PASS (A/B-grade remain) | FAIL (S-grade persist) | ESCALATE (structural ambiguity requiring human judgment)

---

## Convergence Criteria + Downstream Chaining

### Convergence Criteria

**Convergence is measured over a FROZEN artifact.** A round that produced repairs did not verify the
artifact you are shipping — it verified the previous one. So the terminating round must be a round
over **unchanged** code:

1. **Terminate** when a round returns **zero new S/A-grade** findings **AND you make no repairs in
   response to it — at ANY grade, B included**. A round whose B findings you *accept as residual* is
   terminal; a round whose B findings you *fix* is not, because the fix is unverified.
   Why the B clause is the load-bearing half, not a formality: in the measured history below, round 4
   returned `0A+3B` — clean by every S/A-based criterion, and the old rule would have stopped there.
   The three B's were repaired, and round 5 found a genuine **A inside those repairs**. So "zero new
   S/A" is not the discriminator; "nothing was changed in response" is. The loop ends when you stop
   repairing, not when the challenger runs out of ideas.
   **A post-convergence Wave-T de-brittling edit counts as a repair for this purpose.** Wave-T runs
   after convergence and before Done When, so trimming a construct there is an unaudited edit that
   the completion declaration would still describe truthfully ("no repairs were made in response to
   this round") while the invariant it certifies — the shipped artifact is the audited one — is
   false. Either ship the τ-FAIL as a **named** τ-FAIL (the pipeline table's own alternative, and
   terminal) or run one more round over the trimmed artifact before declaring Done.
2. **Record the per-round yield vector** in the Axis-2 marker — `axis2-rounds: 4A / 3A+1B / 2A /
   0A+3B / 1A+2B`. It is what makes the stop decision auditable afterwards, and a flat or rising
   vector is criterion 4's only input.

   **PIN THE TARGET — mandatory on every dispatched Wave, and the reason criterion 1 can be trusted
   at all.** The dispatch prompt carries a measured fingerprint and orders the agent to report
   `WRONG-TARGET` and stop on mismatch:

   ```bash
   bash scripts/target_freeze.sh pin    "$REPO" "$WAVE_LABEL"   # 발주 직전 — 토큰을 프롬프트에 박는다
   bash scripts/target_freeze.sh verify "$REPO" "$WAVE_LABEL"   # 회수 직후 — rc 1 이면 WRONG-TARGET
   ```

   An audit that did not pin its target **cannot be counted as a terminating round** — it may have
   read a tree that changed under it, which voids the verdict wholesale
   ([[feedback_audit_target_must_be_frozen]]). This lives HERE, inline, next to the claim it holds
   up: the first draft put it in `SKILL_detail.md §Wave5`, reachable only when `--sidecar` is
   active — gate-locality on the very fix that was closing a gate-locality gap, caught by the round
   that audited it.

   > ✅ **MECHANIZED 2026-08-17 — the residual below is the history, not the current state.**
   > The recurrence condition this paragraph set ("mechanize on the first recurrence") fired **three
   > times in one day**: a cross-family review was sent a **pre-repair** diff · a review's output was
   > truncated with `tail`, losing findings and the pin itself · a scan was followed by an edit that
   > shifted every line number. All three were "did I send / read the tree that is there now?", and
   > the prose rule above was already in place and caught **none** of them (operator-approved as the
   > next session's 1순위, 2026-08-17).
   >
   > `scripts/target_freeze.sh` (lanes: `scripts/test_target_freeze_lanes.sh`, **28/28**) takes the
   > third attempt deliberately **through** the two failures recorded below: it content-addresses
   > `git diff HEAD` (the **patch**, not its line count — so a same-line-count in-place edit is
   > caught, lane A) and hashes untracked files separately (lane B), and it is **not a hook** —
   > two explicit commands the dispatcher runs, so it cannot become the 100%-firing background noise
   > of attempt ①. It refuses to answer at all when `assume-unchanged`/`skip-worktree` is set
   > (exit 10 UNKNOWN, never MATCH), and a **restore-to-original lane returns MATCH** — that arm is
   > the point: without it, "always reports WRONG" would pass every other lane.
   > 🟥 **Scope, stated narrowly**: it freezes the *target tree*, **not the bytes you inlined into a
   > sidecar prompt**. Where files are pasted into the prompt (`auto-decorrelation` §L191 — sidecars
   > often cannot read a tree at all), the inlined content needs its own binding; this script does
   > not provide it.
   >
   > **Named residual (HISTORICAL — superseded by the block above) — the freeze claim was
   > SELF-ATTESTED, and deliberately not
   > mechanized.** Criterion 1 turns on "unmodified since the previous audit", and nothing checks
   > that. Two attempts to mechanize it on the day the rule was written were both wrong: a hook
   > advisory that fired on 100% of markers (noise, and its convergence detector could not match the
   > hook's own prescribed evidence vocabulary), and a `base-SHA + diff-line-count` fingerprint that
   > is **invariant under an in-place edit** — the modal shape of a prose repair — and structurally
   > blind to untracked files. Both were removed rather than patched. This repo mechanizes at
   > **repetition**, not at first sight, and a one-day-old rule that has already produced two wrong
   > machines is telling you which side of that line it is on. What holds the claim honest today is
   > practice, not mechanism: a dispatched audit pins the target fingerprint in its Step 0 and
   > reports `WRONG-TARGET` on mismatch ([[feedback_audit_target_must_be_frozen]]). **Mechanize on
   > the first recurrence of a convergence claim that turns out to be false** — and when you do,
   > content-address the full working state (tracked diff **and** untracked files), because that is
   > the specific hole the discarded attempt fell into.
3. A-grade or higher complex improvements → skill-ize with `/meta-prompt-builder`
4. **If the yield does not fall across rounds, stop tightening and REDUCE THE DESIGN.** A vector that
   stays flat is not telling you to review harder; it is telling you that each round's repairs are
   manufacturing the next round's findings. Cut the scope that is generating them (see the
   Added-Scope Gate in `.claude/rules/fh_4axis_gate.md`) and re-audit the smaller artifact.
5. Full Wave results → recommend persisting to `tracks/_meta/steel_quench_YYYY_MM_DD_{slug}.md`

> **Why this replaced "zero new S-grade → terminate" (measured 2026-08-02, PR #231).** A single
> change ran 5 rounds with yields `4A / 3A+1B / 2A / 0A+3B(cross-family) / 1A+2B`. The old criterion
> would have terminated at round 4 (zero S/A) — and round 5, run over round 4's repairs, found a
> genuine A. Meanwhile the competing criterion carried in operator memory ("two consecutive rounds
> with zero new") can never fire while every round ships repairs, so it read as permanently
> not-converged and the change shipped with that stated instead. **Both criteria were wrong in the
> same way: they counted rounds instead of asking whether anything had changed underneath.** Rounds
> 2, 3 and 5 found defects exclusively in code the previous round had added. Freezing is the fix that
> both were reaching for — the same discipline the single-audit rule already requires of its target,
> applied to the convergence loop itself.

### Connected Skills

| Situation | Connected Skill | Mandatory? |
|---|---|:---:|
| Delegate improvements as prompts | `/meta-prompt-builder` | optional |
| **External publish: re-validate from external user perspective** | **`/sim-conductor Area A`** | **mandatory** |
| Re-validate structural decision | `/verify-bidirectional` | optional |
| Attack angle is a harness structure problem | `/harness-doctor` | optional |
| After Wave convergence, propose new pattern rules | `fh-meta:persona-innovator` | optional |
| Wave 1 structure-specific attack (6-axis) | `fh-commons:quench-challenger` | priority |
| Back-trace whether claims exist in source files | `/phantom-quench` | **mandatory** when `phantom_risk=true` OR `scope=external` — **its verdict folds back: a load-bearing Phantom = a new S-grade finding, convergence blocked until closed** (routing defined in tpa_schema.md §Gate Routing Table — read it when this fires) |

**steel-quench → sim-conductor gate**: After Wave convergence in external-publish context, `/sim-conductor Area A` is the mandatory next step.

### Required Pre-External-Deployment Sequence

```
steel-quench convergence (zero new S/A over a frozen artifact)
        ↓  pass residual risk list
sim-conductor Area A (external user perspective)
        ↓  new items found that steel-quench missed?
        ├── yes → additional steel-quench Wave round
        └── no  → deployment approved
```

> **Detail**: See `SKILL_detail.md §Wave5` — Wave 5 Multi-Team Panel (team formation bash, parallel dispatch, cross-team synthesis) — read when activating `--sidecar` flag. See `SKILL_detail.md §Structural-Defense` for meta-harness defense layering explanation.

---

## Operating Notes

- **Do not defend in Wave 1.** Mixing attack and defense modes dulls the attack's edge.
- **Attacks without real code are invalid.** Abstract criticism is not included in Wave 1 results.
- **quench-challenger first.** Call fh-commons:quench-challenger in isolation in Wave 1 if available.
- **Always check self-referential pattern (P3).** Cross-validate Wave results with external criteria.
- **Public target → adjudicate against external GT before claiming.** A finding the target's own docs/policy/threat-model marks intentional or out-of-scope is a false positive, not a catch. See §External-GT Adjudication.
- **Attack surface limit**: steel-quench attacks output content patterns. Phantom Claim detection → `phantom-quench`.
- **Gate cross-reference**: any FH skill that declares a PASS / green / listing-ready verdict (`pipeline-conductor`, `marketplace-gate`, the 4-axis auto-gate, `convergence-loop`, domain coverage gates) is a valid Wave-P3 entry point. Invoke `/steel-quench` Wave-P3 on the just-passed artifact rather than editing each gate to embed it — the hook lives here, callers reference it.

## Failure Fallback

On Claude API / MCP failure → refer to [`references/fallback-guide.md`](../../references/fallback-guide.md).
