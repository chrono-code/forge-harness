---
name: meta-prompt-builder
description: Generates structured prompts to send to each agent in an agent dispatch plan. Triggered by "write the instructions", "what do I say to the agent?", "write the prompt for me", "meta-prompt-builder". Bridges agent-composer (which agents) and prompt content (what to say). Uses Goal/Context/Constraints/Done When structure.
user-invocable: true
allowed-tools: ["Read", "Bash", "Glob", "Grep"]
model-note: session-inherit — Sonnet base is first-class (sonnet_floor_doctrine.md); depth-critical judged steps route to dispatch (opus agent / cross-family sidecar, consent-gated), never a substrate requirement
---

# meta-prompt-builder — Prompt Delegation Skill

When agent-composer decides "what to orchestrate", meta-prompt-builder designs "what to say to each agent."
Delegates prompt writing itself to AI — interprets Goal / Context / Constraints / Done When structure within the FH context.

## Primary Users

**agent-composer proficients** — People who already have an orchestration plan and want to structure the specific instructions for each agent. Use this when you already know "which agents to use."

Beginners (unsure which agents to use) → start with agent-composer first. meta-prompt-builder is a post-orchestration step.

## Triggers

- `/meta-prompt-builder`
- Automatically suggested immediately after agent-composer outputs an orchestration plan when user says "how do I instruct each one specifically?"
- "Write the prompts per Wave", "What should I say to each agent?", "Design the instructions"
- "I don't know what to tell the agents"
- "Tell me how to instruct this task so it's handled well"
- "Write the prompt for me"
- "Tell me how to request this from Claude"
- "How should I write the instructions?"

---

## Step 0. Receive Task

Input: natural language task description + (optional) agent-composer orchestration plan

If no input is provided, ask for 4 fields:
```
What task are you designing a prompt for?
 - Goal: What are you trying to achieve?
 - Context: What project, files, or harness state is involved?
 - Constraints: What should be avoided? Are there budget or time limits?
 - Done When: When can you say "it's done"?
```

### Natural Language Goal → Auto-suggest Recommended Chain

When Goal is provided in natural language (e.g., "I need to report to the team lead"), suggest a recommended chain using the keyword mapping below.

| Goal keyword | Recommended chain | Reason |
|---|---|---|
| "report", "team lead", "executive", "CTO", "persuade", "review" | apex-review → (sim-conductor if needed) | Decision-maker simulation then quality validation |
| "analyze", "diagnose", "something seems off" | harness-doctor → context-doctor | Structural + contextual diagnosis simultaneously |
| "simulate", "validate", "meta" | sim-conductor (D-code or Area B) | Multi-perspective validation |
| "install", "setup", "onboarding" | plugin-recommender → install-wizard | Recommend then install |
| "review", "code check" | sim-conductor D-code → hub-cc-pr-reviewer | Code review chain |

Output format:
```
Recommended chain: {Goal keyword} →
  Wave 1: {Agent A} — {1-line reason}
  Wave 2: {Agent B} — {1-line reason}
→ Proceed with this chain? (Y: immediately orchestrate with agent-composer / N: enter 4-field directly)
```

---

## Step 1. Reinterpret as FH 4-field

Structure the input task according to FH context.

| Field | FH interpretation |
|---|---|
| Goal | The harness state change this agent combination must achieve |
| Context | Harness version + latest sim result M/S tier + target file paths |
| Constraints | Simplification guard + no self-recursion + no inter-Wave file conflicts |
| Done When | M-tier 0 items OR specified agent fan-in complete OR N naming candidates produced |

---

## Step 2. Generate Per-Agent Prompt Drafts

Receive agent-composer orchestration plan as input and generate instructions to deliver to each agent per Wave.

Format:
```
Wave {N}-{ID}: [{agent name}]
  Goal: {1 line}
  Context: {harness state in 3 lines max}
  Constraints: {prohibited items in 2 lines max}
  Done When: {evaluation criterion in 1 line}
  ───────────────────────────────
  Actual instruction:
  "{Natural language instruction for the agent — 2–4 sentences}"
```

When called standalone without an agent-composer plan: collect 4-field directly via Step 0 questions, then generate a single-agent prompt.

---

## Step 3. Quality Self-Validation

Before outputting the generated prompt draft, check against 3 criteria.

1. **Goal achievability**: Is the Goal achievable within the agent's allowed-tools range?
2. **Done When measurability**: Is Done When a measurable event in the M/S/R framework?
3. **Context alignment**: Does the Context match the "target" scope defined in the agent's SKILL.md?

Items that fail the check are marked `[WARN]` and the decision is delegated to the user.

**Step 3 bias prevention**: When checking Goal achievability, Read the agent's SKILL.md to directly verify (directly compare allowed-tools list). Since generator and validator are the same LLM, self-validation without external reference repeats bias.

**Done When completeness check**: Even if Done When is measurable in the M/S/R framework, the following 3 must also be stated to pass without WARN:
1. Measurement subject (which agent's output is the basis)
2. Measurement timing (absolute basis for this run vs relative to previous run)
3. Version / baseline (harness-doctor version, sim-conductor Area, etc.)

### Done When Ambiguity Patterns — Automatic WARN Triggers

If Done When contains any of the following patterns, automatically emit `[WARN: Done When not measurable]`.

| Ambiguity type | Example expression | WARN reason |
|---|---|---|
| **Subjective completion** | "if it goes well", "if it's done properly", "if it feels right" | No binary judgment criterion |
| **Speed without numbers** | "quickly done", "finished soon" | No count/time criterion |
| **Absence description** | "if there are no issues", "if there are no errors" | Cannot count as M/S/R |
| **Unconditioned completion** | "when it's all done", "when finished" | What state counts as complete is undefined |

Acceptable form examples:
- "M-tier 0 items" ✅
- "harness-doctor fan-in complete + S-tier 3 or fewer" ✅
- "Scenario 1 PASS verdict received" ✅

---

## Integration with Existing FH Assets

| Asset | Integration direction |
|---|---|
| **agent-composer** | Input source: orchestration plan → meta-prompt-builder elaborates Wave-by-Wave prompts |
| **sim-conductor** | Output validation: generated prompts can be quality-validated via D-code mode |
| **fact-checker** | Wave 0 gating: check if generated prompts overlap or conflict with existing assets |
| **field-harvest** | Context field input source: field patterns can be reflected in Constraints |
| **harness-doctor** | Done When cross-validation: verify alignment with harness-doctor checklist |

---

## Meta-Simulation Validation Criteria (required after onboarding)

> **Detail**: See `SKILL_detail.md §Meta-Simulation Validation Criteria` — 3-axis functional/performance measurement (goal achievement / context alignment / constraint validity) + 3 validation scenarios + marketplace-gate onboarding gate — read after onboarding when validating the skill itself, not per-invocation.

---

## Done When

This skill's own Done When must satisfy the 3-part completeness check it imposes on others
(**measurement subject · measurement timing · version/baseline**). The previous version —
`All steps 0–3 completed` — met 0 of 3 and matched its own `Unconditioned completion` WARN pattern.

```
Measurement subject: this skill's own output — the prompt draft set
                     produced in this invocation (not the dispatched
                     agents' results, which this skill never sees)
Measurement timing:  absolute, at end of this run — no comparison to a
                     previous run is implied or required
Version / baseline:  the Step 3 checklist and the WARN-trigger table in
                     THIS file; note the SKILL.md revision used if the
                     table has changed since the draft was written

☐ Steps 0–3 each produced their named artifact — a step with no
  artifact is incomplete, not "completed"                        (measured: 4 steps, 4 artifacts)
☐ One prompt draft exists per agent named in the dispatch plan   (measured: drafts == agents
                                                                  in plan)
☐ Every draft carries all four fields (Goal / Context /
  Constraints / Done When), none empty                           (measured: 4 fields × N drafts,
                                                                  0 empty)
☐ Each draft's own Done When was run through the 3-part
  completeness check and the WARN-trigger table, with the
  result recorded per draft                                      (mandatory-pass)
☐ Every Goal was checked against the target agent's declared
  allowed-tools by READING that agent's SKILL.md — not from
  recall                                                          (mandatory-pass)
☐ [WARN] items are surfaced to the user with the reason, and
  the decision is the user's                                     (mandatory-pass)
☐ Drafts are handed over for review, not dispatched              (mandatory-pass)
☐ The drafts are usable by the target agent as written           (judged — adversarial pairing:
                                                                  generator and validator are the
                                                                  same model, so self-validation
                                                                  repeats its own bias. Have the
                                                                  target agent, or a different
                                                                  model, read one draft cold and
                                                                  state what it would do; a
                                                                  divergence from the intended
                                                                  task is a FAIL)
```

## Simplification Guard

- meta-prompt-builder does not execute agents directly. Prompt design only.
- Requests without Done When must be confirmed before proceeding.
- Generated prompts are always reviewed by the user before execution.
