# Harness Incubator Doctrine — intent machinization, the nursery, and compose ∪ disrupt

> Crystallized 2026-07-12 from an operator insight session ("the day FH stepped forward").
> This is the *why* underneath the four pillars in `README.md §What makes it a harness, not a toolbox`.
> Always-loaded summary: `CLAUDE.md §Identity`. Operating unit: `harness_6axis_framework.md`.

## 1. What a harness is — intent machinization

A harness is a platform that **reads a human's intent and forges it into a machined form**: either
*AI-salience* (rules and prompts an AI reliably follows) or *deterministic code* (hooks, scripts, gates
that need no model at all). Building a project IS machinizing human intent; a harness **accelerates and
amplifies** that machinization.

The trajectory is always the same four steps:

```
intent (human) → forge into an executable form (AI) → agreement (HITL) → machinery
```

**Agreement is a load-bearing gate, not a courtesy** — machinizing an unagreed intent hardens the wrong
thing. The HITL step sits immediately *before* machinization for exactly this reason.

### Trial-and-error relocates; it does not disappear

The harness's payoff is **less trial-and-error on the human side** — the request → feedback → regenerate
loop is skipped. But the loop is not deleted; it **relocates into the harness**, where agents and
sidecars run it in parallel. Two gains, not one:

1. Trial-and-error the human **does not perform** → human time drops.
2. Trial-and-error the harness runs **in parallel** → wall-clock drops versus sequential human retries.

What is freed is not only time but **attention** — and the quality gate (the responsibility-router
pillar) re-spends that freed attention only where a change is *irreversible*. "Time down + attention
routed to what matters" is the complete form of harness acceleration, and it is what "quality is the
lever; speed is the result" cashes out to.

## 2. The scale ladder — tool < star < galaxy

| Unit | What it is |
|---|---|
| skill / agent / plugin | a tool |
| **harness** (field harness) | a *star* — one project's tools, rules, gates, and memory bound into a single working body, purpose-built (e.g. a coding harness specialized for one product domain) |
| **meta-harness** (FH) | the *galaxy* the stars live in — and a **nursery**, not just a container |

A meta-harness is "a harness for building harnesses." Under a given theme it can machinize anything —
which is why its unit of work is the harness, not the skill.

## 3. The nursery — FH as field-harness incubator and simulator

**Origin layer (operator-forged, 2026-07-18)** — beneath the nursery frame sits the founding
observation: the defects and improvement points that many reviewers find *by hand over a long
time* can be found by an LLM running **many simulations**, compressing that labor by 99%+.
Incubation-acceleration is the natural extension of that single move, not a separate idea. The
resulting differentiator: **a solo developer can ship a product with frontier-grade robustness,
ready for immediate real use** — because the simulations exhaust the functional-defect space
before any human reviewer sees it, the human loop is freed to add *taste* (personal and
organizational judgment) rather than hunt bugs. First end-to-end instance: chamber run #9
(2026-07-18) — surveys, an N=50 concurrency chamber, three find-fix-regress defect cycles, and
a gated public release, in one session.

FH's dual role:

- **Primary — build and emit**: forge a field harness and release it as an independent, specialized
  unit. What ships today is the **scaffold + approval machinery** (Full-Harness Mode in
  `auto_project_mapping.md §6`, gate-compliant field scaffolds); the full simulate-then-emit chamber
  flow is the *named target*, practiced to date as dogfooding a capability inside FH and then landing
  it in the field repo.
- **Contingency — act as the field harness itself**: run the whole of FH (harness-unit, not
  skill-unit) as a sandbox simulator for a project. Expensive per run — that is the price of a
  general-purpose chamber.

**Completeness requirement**: a nursery that can birth any star must hold every element. "Everything a
field-harness simulator needs must be possible inside FH" — multi-model dispatch, tooling, live-surface
operation, gates. This is an *aspiration that directs capability assembly* (what `goal-quench`'s
assembly ladder points at), not a claim of current completeness.

**The economics (why expensive-per-run is cheap-in-total):**

```
Option A: build N field harnesses separately, each doing its own trial-and-error
          → the same errors are repeated N times; learning is never shared
Option B: incubate each field project inside the FH chamber
          → trial-and-error pools in ONE place and compounds (the self-evolving loop)
          → each next project inherits the previous learning → total trial-and-error shrinks
```

FH's sandbox unit cost is higher (general-purpose overhead), but total portfolio cost is *expected* to
be lower — when reuse amortizes the chamber overhead. Honest trade-off: it is expensive *until
emission*; the emitted harness is specialized and cheap, and the learning stays in FH. **Evidence grade
(stated honestly)**: this economics is a *design argument plus n=1*, not a measured comparison — the
counterfactual (building the same capability standalone) was never run, so "cheaper in total" is a
**named bet**, the same treatment the disrupt path gets in §4(c); residual risk: one-off projects that
never recur may not amortize. Empirical grounding for the *capability* (not the cost comparison): a
field QA harness's acts 2–3 arc (2026-07, private) — its live-run capability was forged inside the FH
chamber, then landed in the field repo.

**Minimal execution skeleton (when the operator accepts simulate-first)**: the procedure is currently
*judged/ad-hoc*, standardization deferred to a second real occurrence (measured-trigger, per the
evidence-threshold build discipline): ① open a chamber workspace (a worktree or `tracks/_chamber/{project}/`
— never a real project repo; the underscore prefix rides the onboarding carve-out for meta dirs
(any `tracks/_*` dir — general rule, stated as such in the branch tests), so a **chamber run** never
registers as a mapped project and never pollutes the returning-menu door counts — a
`tracks/{project}-sim/` path would); ② scope the run through `goal-quench`'s budget
gate (chamber runs are the expensive path — cap them); ③ drive the simulation with existing FH assets
(dispatch, gates, live surfaces as needed); ④ the **Emission Gate** — the emit judgment "the simulation
holds" — is a *judged* call paired with the run's own mechanical evidence (tests passing, gate verdicts,
reproduced flows), decided **with the operator (HITL)**; ⑤ on emit, route by candidate class: a **field
harness** goes through Full-Harness Mode / field scaffolds (`auto_project_mapping.md §6` — that mode is
this chamber's field emit terminus); an **FH-internal utility** (a skill/script/rule, not a standalone
field harness) instead routes through the **New-Skill Pre-Commit gate + `asset-placement-gate`** (the
same gate every FH asset passes). KILL emits nothing — the workspace stays as the evidence record.

**EMIT-worthiness — the measured screening criterion (runs #5–#6, 2026-07-14)**: six chamber runs, EMIT
0/6, all KILL. A candidate is emit-worthy only if it clears **all four** of — (1) **net-new** (not a
reinvention of an existing FH/official asset, nor a cosmetic re-wrap of code that already ships — runs
#2–#4 died here, and run #6 partially here too — its core was already conceived in a parked FH signal);
(2) **artifact-shaped** (a tool/script/rule that stands alone, *not* a judgment-method — run #5's genuine
niche was real, but its value lived in a scan∪cross-family *lens*, i.e. an LLM judgment, which cannot be
`npm publish`ed); (3) **real-code/real-data-precision-adequate** (its mechanical form, measured on real
external inputs, does not cry-wolf — run #5's rule scored 5/5 false-positive on 111 real files; run #6's
heuristic scored 14/22 false-fire on a real sibling-folder scan); (4) **hub-state-independent** (run #6,
new axis — a capability whose value structurally depends on hub-held state, e.g. the curated registry +
company-residency knowledge, is not a standalone-first candidate: run #6's `harness-orchestrator` hit
private/company repos it structurally could not know to suppress, because residency knowledge lives only
in the hub. Contrast with fh-commons's 4 skills, which graduated cleanly to portable precisely because they
never depended on hub state). 0/6 candidates cleared all four. This is not "keep trying" — it is a
**pre-screen for future candidates**, cheapest-to-costliest: (1)/(2)/(4) are cheap to predict from the
candidate's own design (does it need hub-only knowledge to work correctly?); only (3) needs a measurement
leg (a real-input precision run), which runs #5–#6 established as the decisive test. The chamber's honest
value to date remains *screening* — preventing reinventions, low-precision births, and premature
standalone graduations — not yet *birthing*. **Graduation order** (run #6's positive finding): a
hub-state-dependent capability graduates hub-internal → proven in use → THEN extracted portable, never
speculated standalone-first — the only path every successfully-portable FH asset actually took.

**Chamber scope — what belongs in the chamber at all (run #7, 2026-07-14)**: run #7 tested a hub-internal
reactivation of the cluster-wizard signal and KILLed it — decisively on its own merits (its "narrow
net-new" claim collapsed against the real shipped registry and an already-existing synergy skill), but
it also surfaced a scope question worth keeping regardless: **a small feature graft onto an
already-shipped hub-internal mechanism is ordinary Mode D self-development under the 4-axis gate, not
automatically a chamber-EMIT question.** The chamber screens candidates that would become a **new
independent artifact** (a skill, a plugin, a standalone tool) — not every internal feature extension.
Route by this test: *would this, if built, be net-new as a standalone thing someone installs/adopts, or
is it two lines added to something already shipped?* The former is chamber-scope; the latter is ordinary
self-dev review.

*Vocabulary reservation (term hygiene, not standardization)*: a run of this skeleton is a **chamber
run** — going forward, run/workspace/log labels use "chamber" for incubation and keep "sim/simulation"
for *verification* sims (target-tier blind sim, sim-conductor persona sims). Established names are
grandfathered, not renamed: the Autopilot branch stays **simulate-first**, and this section's
"simulation holds" phrasing stands — the reservation governs new labels (grep keys), not existing
doctrine prose. The Emission Gate and chamber-run labels exist so a second real occurrence is
recoverable from logs; the procedure itself stays evidence-gated as above.
*Routing baseline (measured)*: the Autopilot's simulate-first routing branch passed a Step 0.5
trigger-accuracy probe 2026-07-13 — 10/10 blind Sonnet sims (5 should-fire incl. 2 borderline, 5
should-not-fire incl. 3 borderline near-misses), 0 malformed verdicts. Scope honestly: an
authored-case baseline (single-draw per case; reps waived per measurement-integrity since every
first draw matched expected — see the 2026-07-13 subagent-invocations log entry), not a calibrated
accuracy estimate.

### 3-a. What is born, and what it must be able to do on day one (operator-forged, 2026-08-09)

**We are not raising a person. We are shipping a harness that does one thing well.** The founding
image is a calf or a foal: it is born in a laboratory sense — brand new, thin, nowhere near an adult
— but it **stands and walks in the place where it was born.** That is the incubator's bar, and it is
much lower and much clearer than "finished."

```
depth / density   altricial  — like an infant. Filled in only by real use. Takes a long time.
basic locomotion  precocial  — like a calf. Works from the moment it is set down.
```

The two axes are independent, and confusing them is what made this look far away. Aiming at an adult
(a complete judgment circuit at birth) is **not merely slow — it is unreachable**, because density is
supplied by usage that has not happened yet. Aiming at a calf is reachable today.

**Operational form**: *born walking* = on the first run, with the user adding nothing, the thing
produces something useful. This maps onto the existing rungs without inventing a scale —
`🔵 RC` = it stood up in the lab; `🟢 REALIZED` = it walked outside.

**The opposite of this doctrine has a name we already use: `built-but-not-wired`.** A harness that
was born but does not walk is one whose parts exist and whose call sites do not — measured instances
exist (a field harness with a judgment-circuit file and **zero callers**; a sibling meta-harness with
none at all). So *"born walking"* is not a metaphor about vitality; it is the engineering claim that
**wiring is part of the birth**, not a follow-up task. Being born and running are different events,
and the incubator is answerable for the second.

#### What the seed contains — a coordinate system, not a declaration

The seed is **not** an identity sentence. `"You are a world-class QA expert"` is an artifact of the
prompt-engineering era and is actively harmful here: the 105-run measurement scored a bare identity
declaration as a **net loss on the weak tier** (removing it recovered +0.67), while a judgment
circuit gained on the frontier tier. Told only *what it is*, a newborn harness still does not know
what to do, and the gaps show up as arbitrary decisions.

What a newborn actually needs is closer to *how to see, how to walk, how to speak*:

| Layer | What it fixes | Note |
|---|---|---|
| **Seeing** | what counts as a signal at all | inputs — without this the circuit has nothing to run on |
| **Judging** | success · which way to lean under uncertainty · out of scope · never | = the `judgment-circuit` definition |
| **Speaking** | how it reports, what shape its output takes | outputs |
| **Walking** | how it actually executes | wiring, call sites |

Shipping the middle layer alone is the common failure: the circuit is present and has no input or
output attached, which is exactly the zero-caller symptom above. **Form is machine-checkable today**
(`scripts/judgment_circuit_lint.sh` — branch rules, self-sealing, conflict resolution, lean
direction, mandated shape; FH's own `CLAUDE.md` measures `CIRCUIT 4/5`). Density is not, and should
not be given a scale yet — see 3-a-2.

#### 3-a-1. Field ⊥ meta — and meta is out of this incubator's scope

The two kinds have **opposite profiles**, which is why one method cannot birth both:

```
field harness   hard to birth (design · seed · wiring)   │ walks on day one      precocial
meta harness    easy to birth (a declaration starts one) │ needs endless tending  altricial
```

A meta-harness cannot clear a bar that reads *"walks on day one"* — not because it is worse, but
because unbounded growth is its point. FH itself is the standing evidence: it is tended continuously,
by design. **Therefore a meta-harness candidate is not a chamber candidate.**

⚠️ **Retrospective observation, not a finding.** Re-reading the run ledger along this axis: of the
KILLed candidates, those aimed at chamber-internal metering, hub-internal orchestration, cluster
wizardry and org relay are all **meta**-shaped, while the single EMIT (`forge-wiki`) is **field**-shaped
— a tool that does one thing. If that holds, several KILLs were not the chamber being strict but
**the wrong kind of candidate entering it**. The classification was made *after the fact* by the same
session that proposed the axis, over n=9; it is a hypothesis to pre-register and predict against, not
a result. The way to test it is to fix the classification first and call the next run before its
verdict — the ordering witness now makes that checkable.

**Proposed consequence (not yet applied)**: give the chamber's entry reason a field/meta axis and
retire meta candidates as **`NOT-APPLICABLE`** rather than `KILL`. Today both land in the same bucket,
so when the ledger says *"the chamber screens"* it is summing two different events.

#### 3-a-2. Density is measured by comparison, never by an absolute scale

Density — how filled-in a circuit is — has no honest unit. Counting clauses, counting cases, or
counting how often the circuit answers all measure different things, and picking one invites the
failure where a metric scores presence instead of the relation it was meant to capture. The way
around it is to **not define the unit**: clone versions (seed only / seed + some usage / seed + more)
and run them against one task set **in parallel**, then read the *shape of the curve* rather than any
version's score. **Where the curve flattens is the interesting point** — that plateau is the practical
floor for "enough of a soul."

Two conditions carry over from the decorrelation work: the clones must be **independent** (run
sequentially in one context and the earlier one bleeds into the later), and the **scorer must be a
different party than the forger**.

🟥 **Named limit — synthesized history yields synthesized density.** Density is defined as accruing
from *real* use; injecting simulated usage into a clone measures something else, and it can fill in a
different direction than real use would. So the question this experiment can answer is narrowed on
purpose: **not** "does the soul grow?" but **"if it grows, where does it plateau?"** That is enough
for a minimum-condition verdict and does not overclaim.

Internal version comparison gives a **growth curve**; comparison against an outside harness gives an
**absolute position**. Both are relative, but their reference points differ — and they can share one
task set, which lets a standing external dominance pre-registration ride along instead of waiting.

### 3-b. The nursery also verifies what it births

The incubator's arc does not end at emission: FH **reviews, accelerates, and verifies** the harnesses
it births or adopts — a verification axis attached to the nursery as an evidenced path (field→meta
reverse-verification arc, 2026-08-01: a field QA harness's doctrine audited the meta-harness itself,
N=2 subjects). Boundary rule for that axis: *harness-verification core = the FH-native
triad-consistency lens (spec ↔ implementation ↔ TC), askable with no cluster member present;
extended = cluster instruments (trace auditors, process-fidelity harnesses), composed by UNION.*
Full doctrine: `harness_verification_core_extended.md`.

**Incubation unit — projects AND features**: incubation applies not only to new projects but to **new
capabilities of an existing harness**. A field harness's self-development is itself run inside the
meta-harness chamber first, then transplanted — the nursery forges new layers for existing stars, not
only new stars. Same economics.

**Simulate-first entry**: when a new project is uncertain, exploratory, or failure-expensive, the
recommended path is *simulate inside the chamber first, then emit the initial model* — not
build-immediately. (Wired as a recommendation branch in `CLAUDE.md §Onboarding / Acceleration
Autopilot`; build-immediately remains correct for clear, small, low-failure-cost projects.)

## 4. Compose ∪ disrupt — two operating modes over other harnesses

| Mode | What | FH mechanism |
|---|---|---|
| **Compose** (additive) | cluster leading harnesses, gather their strengths at optimized token cost | sidecar / multi-harness orchestration |
| **Disrupt** (transformative) | dismantle them into parts, overcome-and-adopt their weak points into FH or a target field harness; self-destruct and reassemble to go where others cannot | **crucible mode** (`crucible_mode.md`) — total-ingest → melt via steel/phantom-quench → identity-bond → reforge; **core invariants never melt** |

Theory anchor (an operator-supplied analogy drawing on Clayton Christensen's disruptive-innovation
thesis): disruptive technology tends to emerge from re-purposing existing parts
for unintended uses — crude and inefficient at first, then growing fast along a dimension incumbents
overlooked. Mapped here: "re-purposed parts" = other harnesses dismantled into components;
"the overlooked dimension" = the direction others cannot go. Companion criterion,
**fitness-for-purpose**: equipment that is well-made but would not survive *this* dragon is better
re-forged from scratch than patched.

Honest boundaries: (a) core invariants (floors, gates, identity) are never melted; (b)
overcome-and-adopt is curation with license/provenance respect, never wholesale copying; (c) the
disruptive path *looks inferior early* — running it is a deliberate bet, named as such.

### 4-b. Boundary crossing — what actually flows between harnesses

Compose and disrupt say *what FH does to* other harnesses. They do not say **what moves across the
boundary, or what must not**. That gap is where the value of a multi-harness cluster is won or lost, so
name it: a harness that only deepens its own well stays blind to what the neighbouring well knows —
one harness sees runtime behaviour and not source structure, another sees source structure and never
runtime. **The meta-harness's job is not to dig a deeper well; it is to make outputs flow across the
boundary between wells.**

Three rules, in falling order of how easily they are broken:

1. **Crossing must not overwrite the receiving harness's identity.** If harness B is deliberately
   black-box (it verifies only what a user could observe), pushing A's white-box artifacts into B does
   not enrich B — it *destroys the property that made B worth having*. Route such insight to the
   knowledge store instead, and let B keep its blindness on purpose. **Identity beats convenience**;
   this is the rule that gets violated first, because injecting looks like helping.
2. **What crosses is a transformed artifact, not a raw dump.** A finding is useful to the neighbour only
   in the form that neighbour already consumes. The meta-harness owns the conversion — that conversion
   *is* the pipe, and building it is the work.
3. **Two-layer governance: the meta layer supplies, the field layer adjudicates.** FH (or any meta
   harness) feeds the engine and the inputs; the field harness declares the verdict on its own surface.
   A meta layer that issues field verdicts directly has collapsed the layers.

Honest boundary: crossing is only worth building where the wells are **genuinely different in kind**
(different observation modality, different failure classes). Between two harnesses that see the same
things, a pipe adds coordination cost and no information — that is composition, not crossing. And a pipe
being *connected* is not the same as it being *effective*: state infrastructure and measured effect
separately, never quote the former as the latter.

Origin: forged in a field environment (2026-07-19, operator) where a black-box regression harness and a
white-box static-review harness had to feed each other without either losing its character; generalized
here with the site-specific well names removed. The field-level instance keeps its own concrete form.

## 5. Sidecar corollary — ride the evolution, don't patch the weak spots

Mechanically patching each frontier model's current weaknesses produces scaffolding that dies as models
improve (the weakness itself disappears). FH's sidecar layer is therefore built to **co-evolve**: shed
what the substrate now does natively (`feedback: frontier substrate self-adaptation`), absorb what it
ships next, and use cross-family decorrelation as *today's* trust lever (composition beats a single
model's ceiling — see `multi_model_sidecar_strategy.md`). Capability is the model's; assembly, trust,
and evolution are the harness's.

## Done When (doctrine doc — reference asset)

- The four-pillar README section, `CLAUDE.md §Identity`, and this doc tell one consistent story
  (no contradicting claims). *Check class: judged; pair: contradiction scan on ingest
  (`sync_push_protocols.md` step 3).*
- Every mechanism named here points at a real, existing asset (Full-Harness Mode, crucible_mode,
  goal-quench, multi_model_sidecar_strategy). *Check class: mandatory-pass (phantom scan).*
