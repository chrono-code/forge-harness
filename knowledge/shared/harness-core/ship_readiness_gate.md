# Ship-Readiness Gate — Identity All-Green as the Release Condition

> **What this is**: the release gate for a harness (FH itself, or any field harness it incubates). A
> harness **ships** — and earns a **formal release tag** — only when the identities that define it are
> **all-green**: each proven REALIZED by a concrete track-record artifact (n≥1), not merely documented.
> This is the "품질보증서 (quality-assurance certificate)" the operator asked for: it certifies the
> harness does what its identity claims, with evidence, before it goes out. Origin: the 2026-07-14
> identity-fulfillment audit (`tracks/_meta/identity_audit_2026-07-14.md`).

## Why an identity gate, not a feature checklist
A harness is a means, not a feature list. Shipping it means promising it *does what its identity claims*.
A feature can be present yet the identity still be 이상론 (aspirational) — e.g. an incubator with a runner
but zero real emits. So the gate scores **identities by evidence**, and the honest states are:

| Status | Meaning | Bar |
|---|---|---|
| 🟢 GREEN | **REALIZED** | a concrete track-record artifact proves the identity fired for real, n≥1 (a real gate block, a measured probe, a real orchestration record) — *not* a doc that describes it |
| 🔵 RC | **RELEASE-CANDIDATE** | implemented **and** calibrated on a known pair **and** its own self-test green — but it has not yet fired in a real situation. All three legs, each with an evidence line; two out of three is 🟡 |
| 🟡 YELLOW | **PARTIAL** | pieces work but no single closed track record (e.g. two half-pipelines that never connected end-to-end) |
| 🔴 RED | **이상론 (ideal-only)** | documented aspiration, never actually run; or the source itself says "not built yet / named target" |

**All-green rule**: ship + tag only when **every** identity is 🟢. A 🔵, 🟡 or 🔴 blocks the tag — and names
exactly what real run is missing. The remedy for RED is never to relabel it green; it is to **run it and
leave the artifact** (the operator's standing rule: "이상론이면 실제로 돌려봐서 실적을 남겨야 한다").

**🔵 RC is deliberately not green.** It is the rung for "we built it, we proved the instrument works, and
our own tests pass" — a real and reportable milestone, and *still* short of the bar, because a self-test
is authored by the same party it tests. The boundary is the one named in
`[[feedback_adversarial_review_not_substitute_for_first_use]]`: **passing your own tests is not firing in
the real situation**, and the first real use is repeatedly what invalidates the design. So RC never opens
a `v1.0.0`; only REALIZED does.

> The origin note (2026-08-08 session card) drew this ladder with RC and REALIZED **both** marked 🟢. That
> shorthand is fine in a card and breaks here: this gate's rule reads literally as "every identity 🟢 →
> ship", so a green RC would open the tag that the same note says RC must not open. Distinct symbol, same
> intent.

**RC is self-reported by construction — so it carries evidence, not a claim.** Each RC status names, on
one line, *what ran and what came out* (the non-vacuity requirement borrowed from the 4-axis marker's
`axis2-evidence`: a recorded verdict, count or fixture result — never "it works"). An RC without that line
is 🟡. Where an instrument could not be calibrated against a real case, the leg ships labelled
**`UNCALIBRATED`** rather than silently counted (`not found ≠ 0`).

## Dominance, not concession — the AlexNet bar
A harness earns the right to say "we compose with other harnesses" **only from proven dominance**, never
as a humble concession. The reference is AlexNet: on data it had never seen, it did not *participate* — it
**crushed every competitor**. That is the bar for a shippable identity: on unseen input, in a head-to-head
against the realistic alternative (a plain single-model session, a competing harness's flow), our harness
must **decisively win**, not merely tie or "also work."

The composition identity (멀티하네스 클러스터) is downstream of this: we equip *other* harnesses onto the
parts **we deliberately chose not to cover, or left general-purpose** — a decision made from strength, after
proving we would win the parts we do cover. Composing because we *can't* win is weakness wearing the costume
of humility; composing because we *choose* the frontier and hand the rest to specialists is dominance.

**The squirrel-and-equipment shape (operator, 2026-07-14)**: the squirrel (🐿️ FH) dons **specialized gear**
for a specific harness/project — micro-work can't be done barehanded, and the gear (a field/domain harness)
makes it easier and more specialized. But **the squirrel itself must be an all-rounder master** at the one
thing it does everywhere: *creating and accelerating harnesses*. The mastery is the squirrel (general,
must-dominate — the governance/quality/harness-craft); the specialization is the equipment (per-domain,
composed-in). You never concede the craft; you equip for the domain. So the dominance bar applies to the
**craft** (does FH out-govern / out-build any alternative on unseen ground?), and composition applies to the
**gear** (which specialist harness to bolt on for this domain's micro-work).

**Dominance result (governance craft, 2026-07-14)** — `tracks/_meta/dominance_benchmark_2026-07-14.md`.
Model held fixed at the Sonnet floor; only the harness *method* varied. Two rounds:
- **Round 1 (5 easy holes)**: FH degrade-lens **5/5 (0 FP)** vs plain review **3/5** (1 miss + 1 false-alarm).
  Honest read: obvious fail-opens are caught by both — the lens's edge showed only on the subtle hole and
  in not crying wolf. Not a blowout; it pointed to harder holes as the real test.
- **Round 2 (8 subtle holes, authored by Fable + Codex — decorrelated from the method under test)**: plain
  review **5/8** (and 2 of its "catches" were distractor mis-identifications = false confidence, worse than
  a clean miss); degrade-lens **6/8, 0 FP**; and critically **both single Sonnet lanes missed the same 2
  holes** (a falsy-error-sentinel return, and a separator-negation parse). A **cross-family (Codex) lane
  with the same lens caught both** — the correlated blind spot inside one model family, closed only by a
  *different* family. **FH stack (degrade-lens ∪ cross-family) = 8/8, 0 FP.**

The load-bearing finding is architectural, not a headline number: **dominance comes from the decorrelated
stack (`degrade-lint ∪ cross-family ∪ mechanical-anchor`), not from any single clever reviewer** — even a
well-prompted floor model has a correlated blind spot that only a different family closes. This is the
*empirical* basis for why FH is a stack, not a prompt. And the two blind-spot classes round 2 exposed were
**immediately mechanized** — `degrade_direction_scan.sh` probes E (falsy-sentinel→PASS) and F
(split-positional-verdict) now flag both at the pre-lens layer (0 false-positive on the FH codebase), so the
correlated miss is caught one layer earlier. Forward direction: more such classes, and reps≥3 to fix the numbers.

**Gate consequence**: each 🟢 identity should carry not just an existence artifact (n≥1) but, where a
competitor exists, a **dominance result** — a measured head-to-head where our harness catches / completes /
survives what the alternative misses. The governance identity already has one (blind cross-family: FH's gate
the *only* thing that caught the irreversibility/safety class; competitors HITL 8/8 ABSENT). The others owe
theirs. A dominance benchmark is also *diagnostic*: where we do NOT yet dominate tells us exactly where to go
next (the operator: "압도성을 결과로 봐야 앞으로 나아갈 방향을 안다").

## The gate is the audit method (reusable)
Score with the same triangulation the 2026-07-14 audit used — no single-source self-attestation:
1. **Cross-family falsifiable checklist** — draft the per-identity PASS criteria with ≥2 decorrelated
   models (e.g. Fable higher-tier + Codex cross-family); they must converge on the load-bearing checks.
2. **Origin-grounding** — for each identity, quote its *original intent* from the accumulated record
   (memory / tracks / companion store) and find the artifact that proves it fired (or prove none exists).
3. **Blind floor-tier probe** — for any identity whose value is "intent-based autonomous completion"
   (a user gets the value by intent, without naming the skill), *measure* it: blind Sonnet sessions given
   novice-vocabulary intents, scored on whether the right skill/gate fires. Salience-only ≠ measured.

## Versioning policy — the formal release track
The formal release tag is **independent of the npm package version**. The npm version (currently in the
`1.4.x` range) is the **plugin-cache lockstep number** — it bumps on every shipped-asset change so Codex/
marketplace cache-invalidate; it is not a maturity claim. The **formal identity-maturity release starts at
`v0.1.0`**. Do not conflate the two counters; a high npm number does not make the harness mature.

**The `0.x` ↔ `1.0` mapping (refined 2026-07-14, informed operator decision).** Semver `0.x` explicitly
means *early / not-yet-complete*, so the formal track maps cleanly onto the identity gate:
- **`v0.1.0` = the first formal-release baseline.** It is tagged when the harness has a *proven core*
  (≥1 identity 🟢 by real artifact) and an *honest, evidence-scored status for the rest* — NOT when every
  identity is green. `v0.1.0` makes **no all-green claim**; its release notes carry the real per-identity
  status (🟢/🟡/🔴). This is the baseline *from which* all-green is tracked, not the all-green ship itself.
- **`v1.0.0` = the all-green ship.** The original "ship only when every identity is 🟢" condition maps to
  **v1.0.0**, not v0.1.0. A 🟡/🔴 blocks *v1.0*, and names exactly what real run is missing — it does not
  block the honest v0.1.0 baseline.

This refinement resolves the tension of tagging a baseline while identities are still maturing: `0.x` is
*designed* to carry an incomplete-but-honest status. What it must never do is **lie** — a v0.x tag whose
notes claim more green than the audit shows is the defect the gate exists to prevent. The operator, shown
the non-all-green status (③⑤ 🟢, ④ 🟡, ①② 🔴), elected to tag `v0.1.0` as this honest baseline; the
decision is logged here and the tag's notes state the real status.

## The four engines — what has to run for an identity to be reachable at all

An identity is what a harness *claims*; an **engine** is a capability the harness must actually possess
for that claim to be reachable. They are different axes, and scoring only identities hides *why* one is
stuck: the failure shows up in the identity and the cause sits in the engine.

| Engine | What it is | Why an identity needs it |
|---|---|---|
| **external-grounding** | Asking the world on its own initiative — reaching outside the repo before asserting novelty or settling a design, without being told to | Anything **new** has no known answer inside; asserting `net-new` from an internal grep alone is how a phantom is born |
| **judgment-circuit** | A forged decision circuit: what counts as success, which way to lean under uncertainty, what is out of scope, what never happens | Anything **autonomous** has no direction without one; the harness fills the vacuum with volume instead |
| **ship-gate** | Mechanical blocking before an irreversible surface — commit, publish, delete, rewrite | Anything that **ships** needs a last line that does not depend on remembering |
| **context-continuity** | Not losing the thread mid-run — across compaction, sub-agents, machines and sessions | Anything **long** loses its own premises first, and the loss is silent |

**Naming rule — do not translate `judgment-circuit` as "soul".** In Korean the operator's word is 영혼, but
the English word reads as *persona*, and the single largest finding of the 105-run measurement behind this
engine was precisely that **an identity declaration is not a judgment circuit** ("너는 ~이다" measured as a
net loss; removing it recovered +0.67 on the weak tier). A one-word translation re-fuses exactly what the
measurement separated.

**Why engines gate the advertised capabilities**: the harness's most-advertised surfaces — incubating a new
project, orchestrating a multi-harness cluster — are simultaneously *long, autonomous, novel and shipping*.
They therefore load all four engines at once, which is why a harness with a mature ship-gate and little
else appears to fail *at* those surfaces while the cause is underneath them.

> ⚠️ **The identity↔engine mapping below was composed by the AI, not measured.** It is a structural
> hypothesis, not established causality. The way to test it is to bring **one** engine up a rung and watch
> whether the mapped identity moves; until then, read the column as a claim about *what to try*, not about
> what is known. (The counterweight matters here: a mapping that looks tidy is the easiest thing to start
> citing as a finding.)

## FH's own status (2026-07-14) — NOT yet all-green

Engine column added 2026-08-08 (mapping is the unverified hypothesis flagged above; Status column is
unchanged and keeps its own 2026-07-14 evidence).

| # | Identity | Engines it loads | Status | Evidence / what's missing |
|---|---|---|---|---|
| ③ | 거버넌스 게이트 (governance) | ship-gate | 🟢 GREEN | pre-commit/pre-push physically block; moat measured 3–4 family blind (HITL 8/8 ABSENT); cross-family caught a real companion-store-name leak 2026-07-14 (fail-closed) |
| ⑤ | 증폭자 (amplifier) | judgment-circuit | 🟢 GREEN | short-intent→literature-grounding→ultimate-doc real instances; rules-diet −18.2k measured; intent-routing probe 94% (below) |
| ④ | 프런티어→조직 전파 | external-grounding | 🟡 YELLOW | frontier-digest launchd auto + AX submission docs both real, but digest→org never closed as ONE pipeline |
| ① | 멀티하네스 클러스터 | context-continuity | 🟡 PARTIAL | routing runs for real — 17 nodes mapped, sidecar-orchestrator, Skill Bus routing qasp/dashboard/stockbattle (so NOT 🔴 ideal-only). Missing: continuous 2-node relay channel + external-harness recommend (cluster-wizard parked) → 🟡 not 🟢 |
| ② | 프로젝트 인큐베이터 | context-continuity + judgment-circuit | 🟡 PARTIAL | incubation is running — **stockbattle is being incubated now** (S1 built, mid-flight) + qasp/pmh spin-out precedent + scaffold-emit shipped (doctrine: "emit shipped today as scaffold+approval; the chamber flow is the named target"). **Corrected 2026-08-08** (the old text read "6 runs, 6 KILL … 0/6", which was stale on both counts, and the ledger itself was missing a run): hand-counted from `tracks/_chamber/INDEX.md` — **9 full runs (#2–#10), 8 KILL, 1 EMIT** (#1 is a trigger probe, not a full run). Runs #5–#6 *measured* the emit-worthiness criterion (net-new ∧ artifact-shaped ∧ real-data-precision-adequate ∧ hub-state-independent); run #6 confirmed the graduation-order principle — hub-internal proof before standalone extraction, never the reverse. **The 🟡 is now held for a different reason than before.** The old reason ("no closed emit-via-incubation yet") is false: run #9 `forge-wiki` emitted and shipped publicly under operator approval with the Pre-Publish gate passed. What is *not* proven is that the **formal chamber flow** produced it — that run's workspace holds only an `EMISSION_VERDICT.md`, with no `INTENT.md`, `BUDGET.md` or `SIM_NOTES.md`, so the intent/budget/blind-persona gates have no artifact and the verdict was written after the fact. The first run to complete the formal flow end-to-end is #10 (2026-08-08, 3 blind isolated personas) and it KILLed. So: **the identity has fired once, the mechanism has not yet been shown to be what fired it**, and the dominance result every 🟢 owes is still outstanding → 🟡 |

**Cross-cutting measured (intent-based autonomous completion)**: blind floor-tier Sonnet trigger-accuracy
probe (n=10, 2026-07-14): **should-fire 7.5/8 (94%), false-fire 0/2**. One weak trigger (simulate-first /
incubator entry absorbed into deep-clarify) — the identity-② weakness surfaces in routing too.

**Verdict (2026-07-14, ①② corrected)**: FH is tagged **`v0.1.0` = honest baseline**, not all-green. ③⑤ are
🟢, ①②④ 🟡, **none 🔴** — the `v0.1.0` notes state this and make no all-green claim (per the refined 0.x↔1.0
mapping above). **`v1.0.0` remains the all-green target.** What blocks v1.0 is **closing the 🟡s**: ①'s
continuous 2-node relay channel, ②'s first closed emit-via-incubation (formal chamber first EMIT — criterion
measured in run #5 — or a chamber-incubated spin-out closing), ④'s closed digest→org pipeline. Each remedy
is a run that leaves an artifact, tracked in `tracks/_meta/identity_audit_*.md`.

> **①② correction (2026-07-14)**: an earlier pass marked ①② 🔴 by collapsing each identity onto its most
> advanced *single mechanism* — ② onto the formal chamber EMIT (0/5), ① onto the continuous-relay channel.
> That contradicts the doctrine (emit is "shipped today as scaffold+approval; the chamber is the named
> target") and the live reality (routing runs; **stockbattle is being incubated now**; qasp/pmh spun out).
> An identity whose broad path *runs* is not 🔴 ideal-only. Both are 🟡: running, not yet closed. Lesson:
> do not score an identity by its hardest sub-mechanism — that reads a live-but-incomplete path as zero.

## For a field harness (e.g. pmh, qasp)
Same gate, its own identities. A field harness ships to its team when its identity checklist is all-green,
certified by a **실증상세 (demonstration-detail) doc in that harness's own repo** — the QA certificate
listing each identity, its PASS criterion, and the artifact proving it. FH≡field parity: what FH proves
about itself, a field harness proves about itself, by the same method. (Company-residency: a field
harness's 실증상세 lives in its own private repo; FH holds only the method, never the field's evidence.)
