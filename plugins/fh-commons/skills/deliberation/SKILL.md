---
name: deliberation
description: Multi-perspective synthesis structure — Innovator (propose) → Devil-Advocate (challenge) → Mediator (synthesize) 3-layer execution. Outputs conditional verdicts without binary win/loss. Activates on "deliberation", "battle this out", "weigh the pros and cons", "review from multiple angles", "which side is right?". Optional deep-insight persona jurors for domain-specific views. Designed for design decisions, skill proposals, and architectural choices.
user-invocable: true
allowed-tools: ["Read", "Bash", "Agent"]
model-note: session-inherit — Sonnet base is first-class (sonnet_floor_doctrine.md); depth-critical judged steps route to dispatch (opus agent / cross-family sidecar, consent-gated), never a substrate requirement
origin: fh-meta
---

# deliberation — The Forge Skill

Innovator (propose) → Devil (challenge) → Mediator (synthesize) 3-layer core structure.
The goal is not to pick a winner — it is to **extract salvageable fragments from the losing argument and produce a conditional verdict**.
Even those who struggle to challenge assumptions can use this structure as a rope to reach better decisions.

> **Role distinction from sim-conductor and steel-quench**
> - sim-conductor: **validates** quality and consistency of a completed asset
> - steel-quench: **adversarially stress-tests** a near-complete artifact (post-build defect surfacing)
> - deliberation: perspective clash during the **design decision process** → synthesis (upstream of both)

---

## Triggers

- `/deliberation`
- "battle this out", "make them argue", "clash and synthesize"
- "review this decision from multiple angles"
- When agent-composer Step 4-b proposes `Wave next-D` automatically

### Natural Language Triggers (for general users — activates without internal vocabulary)

Also activates when design decisions or perspective clashes are expressed in natural language:

| Example phrase | Intent |
|---|---|
| "I'm not sure whether to do this or not" | Decision uncertainty → multi-perspective synthesis |
| "It seems like opinions are divided" | Perspective clash → synthesis layer needed |
| "Help me decide which side is right" | Conditional synthesis, not simple winner selection |
| "Someone will probably object to this" | Request for devil's advocate perspective |
| "Is it okay to keep going in this direction?" | Re-validation of design decision |
| "Review this from multiple angles" | Multi-perspective synthesis → 3-layer default |
| "Analyze this from all sides" | Multi-perspective synthesis → 3-layer default |
| "Weigh the pros and cons" | Perspective clash → devil + innovator engaged |
| "Analyze the strengths and weaknesses" | Pro/con structure → Innovator (pros) + Devil (cons) |
| "Help me make a decision" | Decision support → conditional verdict generation |
| "pros and cons", "pros cons" | Comparative analysis → synthesis layer needed |

---

## Step 0. Receive Topic + Select Layer

If no input is provided, ask:
```
Please provide the deliberation topic.
  - Topic: What are you trying to decide or design?
  - Layer: [3-layer default (recommended)] / [5-layer — includes jury]
  - Jury focus (if 5-layer selected): user experience / technical feasibility / business & policy
```

**Default: 3-layer** (Innovator → Devil → Mediator). Use 5-layer only when a jury is needed.

**Execution log (workers_approved pattern)**:
Upon completing Step 0, include the following in the output:
```
[DELIBERATION START] Topic: {topic} | Layer: {layer} | {timestamp}
  → WORKER_CALL: Innovator (isolated instance)
  → WORKER_CALL: Devil-Advocate (isolated instance)
  → WORKER_CALL: Mediator (isolated instance — Cost of Consensus prevention)
```

Jury auto-selection criteria:
| Topic nature | Recommended jury personas |
|---|---|
| New user experience related | `beginner` + `main-player` |
| Technical implementation feasibility | `persona-be` + `persona-fe` |
| Business viability / policy / legal | `persona-pm` + `persona-business` |
| General design decisions | No jury (3-layer is sufficient) |

---

## Step 1. Innovator Layer — Propose

Invoke `deep-insight:persona-innovator`.

> **Fallback (if deep-insight is not installed)**: Claude Code performs the Innovator role inline. Same instruction template and output format apply. The deliberation pipeline is guaranteed to work without deep-insight installed.

> **No isolation (intentional)**: The Innovator is a proposal generator — it does not evaluate its own output, so Agent tool isolation is not needed. Cost of Consensus applies only to the Mediator, which **evaluates** its own generated content (arXiv 2605.00914). Only the Mediator (Step 3) is isolated via the Agent tool.

Instruction template (meta-prompt-builder structure):
```
Goal: Generate the most creative and scalable proposals for {topic}
Context: Current harness state + list of relevant assets
Constraints: No duplication of existing assets / must not violate simplification guard
Done When: 1~3 concrete proposals + 1-line rationale per proposal
Brief limit: Total Context passed to Agent must be kept under 1200 characters
```

Output format:
```
[Innovator]
  Proposal 1: {content} — Rationale: {1 line}
  Proposal 2: {content} — Rationale: {1 line}
  (optional) Proposal 3: {content} — Rationale: {1 line}
```

---

## Step 2. Devil-Advocate Layer — Challenge

Invoke `deep-insight:persona-devil-advocate`. Takes Step 1 output as input.

> **Fallback (if deep-insight is not installed)**: `fh-commons:quench-challenger` (includes Devil DNA) or Claude Code performs the Devil-Advocate role inline. Same output format. Instance isolation is not required, same as Step 1.

Instruction template:
```
Goal: Generate the sharpest single rebuttal for each of the {N} Innovator proposals
Context: Innovator output + harness simplification guard + known failure patterns
Constraints: No emotional rebuttals / no baseless negation / must include a hint toward improvement
Done When: 1 rebuttal per proposal + 1-line core risk + 1-line acknowledgment of valid parts
Brief limit: Total Context passed to Agent must be kept under 1200 characters
```

Output format:
```
[Devil-Advocate]
  Proposal 1 rebuttal: {content}
    Risk: {1 line}
    Acknowledgment: {1 line}  ← this line is the Mediator's raw material
  Proposal 2 rebuttal: ...
```

> **Acknowledgment line is mandatory**: The Devil must explicitly state "this part is valid" — synthesis is impossible without it.
> A rebuttal with no acknowledgment is automatically flagged as `[WARN: unsynthesizable rebuttal]`.

---

## Step 3. Mediator Layer — Synthesize (Core)

**[Isolation Principle — Cost of Consensus Response]**
The Mediator invokes a separate instance via the `Agent` tool.
When the same instance evaluates its own generated content, confirmation bias occurs (demonstrated in arXiv 2605.00914).
Physical separation from the Innovator/Devil generation context is required for unbiased synthesis.

> **What isolation means**: Blocks Self-Evaluation Bias — the tendency for an instance to favor its own output.
> The Mediator reads the Innovator and Devil outputs, but does not share the **reasoning process that generated** those outputs.
> Independence of the reasoning path — not mere information sharing — is the key to resolving Cost of Consensus.

Agent invocation instruction (includes Context Card):
```
Goal: Synthesize Innovator and Devil-Advocate outputs into a conditional verdict
Context: {full Step 1 output} + {full Step 2 output}
Constraints: No simple selection of the winning argument / must extract fragments from the losing argument / no hedge language ("balance both sides") / output under 1200 characters
Done When: All 5 sections output — Adopt / Alert absorption / Verdict / Conditions / Discard
```

**Synthesis formula**:
```
Core value of the Innovator proposal
  + Valid alerts from Devil's rebuttal (extracted from the acknowledgment line)
  → Conditional verdict: "{proposal} OK, provided {condition} is mandatory"
```

**What the Mediator must not do**:
- Simply select the winning argument as-is (simple verdict = deliberation failure)
- Discard the losing argument (fragment extraction is mandatory)
- Use hedge expressions like "we should consider both sides in a balanced way"

Output format:
```
[Mediator — Synthesis Verdict]
  Adopt: Core of {Innovator Proposal N} — {value, 1 line}
  Alert absorption: "{acknowledgment line}" from {Devil rebuttal} → converted to condition {X}
  ─────────────────────────────────────────
  Verdict: Proceed with {proposal} — OK
  Conditions: {1~3 required conditions}
  Discard: {fully rejected parts — with rationale}
```

---

## Step 4 (Optional). Jury Layer — Domain Perspectives

Runs only when 5-layer is selected. **Parallel** dispatch of 2~3 selected deep-insight personas via the `Agent` tool.

> **Fallback (if deep-insight is not installed)**: dispatch the jury from real fh-meta agents instead — `persona-innovator` and `hub-persona-auditor` (and `fh-commons:quench-challenger` for an adversarial juror). Same parallel-Agent dispatch, juror cap, and output format apply. The 5-layer jury is guaranteed to run without deep-insight installed — mirroring the Step 1/Step 2 fallbacks.

Juror count limit: **maximum 3**. If 4 or more are selected, output `[WARN: jury overload — noise risk]` and defer to the user.

Instruction per juror:
```
Goal: Review the Mediator's synthesis verdict from the perspective of {persona}
Context: Full output from Steps 1~3
Constraints: Do not overturn the already-synthesized verdict / only propose additional conditions
Done When: Agree / partial agreement / disagree + 1 line of additional conditions or risk
```

Output format:
```
[Jury: {persona name}]
  Verdict: Agree / Partial agreement / Disagree
  Opinion: {1~2 lines}
  Additional condition: {1 line if applicable}
```

---

## Step 5 (Optional). Mediator Final Synthesis

Incorporates jury opinions to refine the Step 3 verdict.

```
[Final Verdict]
  Based on: Step 3 synthesis verdict
  Jury input: {N agreed / N partial / N disagreed}
  Added conditions: {additional conditions from jury}
  Final conclusion: {1~2 lines}
```

---

## Automatic WARN Detection Patterns

| Situation | WARN content |
|---|---|
| Devil rebuttal has no "acknowledgment" line | `[WARN: unsynthesizable rebuttal — Mediator lacks raw material]` |
| Mediator adopts only one side's argument | `[WARN: simple verdict, not synthesis — deliberation failure]` |
| Innovator and Devil share the same premise | `[WARN: no real clash — recommend redefining the topic]` |
| 4 or more jurors selected | `[WARN: jury overload — reduce to 3 or fewer?]` |
| Done When contains vague expressions | `[WARN: Done When is unmeasurable — share meta-prompt-builder WARN criteria]` |

---

## agent-composer Integration — Wave next-D

Add the following condition to the agent-composer Step 4-b state transition gate:

```
| ⑤ Design decision clash or judgment that "a battle is needed" | Wave next-D | deliberation (S) |
```

`Wave next-D` activation criteria:
- M/S/R results contain "2 or more mutually conflicting proposals"
- User utterance includes "which side is right?", "they conflict", "both seem valid"
- agent-composer cannot synthesize the fan-in results and is about to defer the decision to the user

---

## Design Principle — Why This Skill Exists

It is a **rope** for those who have not yet dared to challenge.

Thinking alone traps you in a single perspective. Only the courageous construct counterarguments themselves.
deliberation provides that counterargument as structure — even those afraid of conflict can start a battle, because the Mediator will synthesize it for them.

The Mediator's conditional verdict creates a safe entry point: "this is okay if you do it this way."
The jury fills the domain blind spots that no single person can see on their own.

**What the forge creates is not a winner — it is a new alloy.**

---

## Done When

Each condition declares its check class (mandatory-pass / measured / judged); every judged condition
names its adversarial pairing — no judge-only path.

```
All Steps 0~3 completed (Steps 4~5 added if 5-layer selected)
  (mandatory-pass — each layer's output block is present in the declared format; a skipped layer is
   a FAIL, not a default pass)
+ Every Innovator proposal carries a Devil-Advocate rebuttal AND an acknowledgment line
  (measured: rebuttal count == proposal count, and acknowledgment count == rebuttal count. A
   rebuttal without an acknowledgment is already flagged `[WARN: unsynthesizable rebuttal]` in
   Step 2 — this condition is what makes that flag block completion instead of decorating it)
+ [Mediator — Synthesis Verdict] output present (Adopt / Alert absorption / Verdict / Conditions / Discard)
  (judged — adversarial pairing: the Devil-Advocate layer is the standing opposition to the
   Innovator, and the Mediator's synthesis is re-attacked by `fh-commons:quench-challenger` on the
   one axis the Devil conceded; a synthesis that only restates the concessions is not a verdict)
+ User's final decision confirmed (deliberation output must never be auto-executed)
  (mandatory-pass — an explicit user utterance selecting an option; silence, absence, or the
   session's own inference does NOT satisfy it)
```

**→ When invoked from agent-composer Wave next-D: synthesis verdict is the fan-in input for Wave continuation** — return the Mediator verdict + Conditions to agent-composer so the conflict is marked resolved in the fan-in result set. After this, agent-composer re-runs Step 4-b state transition evaluation with the conflict cleared; subsequent Waves (next-M / next-E / end) proceed based on the updated result.

## Simplification Guard

- Simple information queries → deliberation is unnecessary. Respond directly.
- Cases where the answer is already clear → route to sim-conductor (validation) or harness-doctor (diagnosis).
- If resolvable without a jury, 3-layer default is sufficient.
- deliberation output always completes with the user's final decision. Auto-execution is prohibited.

---

## Related Skills

| Situation | Related skill |
|---|---|
| Auto-triggered on design decision clash (Wave next-D) | `fh-meta:agent-composer` Step 4-b |
| Validate quality and consistency of a completed asset | `fh-meta:sim-conductor` |
| Validate skill candidates after deliberation | `fh-meta:harness-doctor` |
| Implementation convergence loop after a decision | `fh-commons:convergence-loop` |
