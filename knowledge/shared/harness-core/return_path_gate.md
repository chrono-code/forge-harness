---
name: return-path-gate
description: Skill chain pattern where a downstream skill returns a structured conditional verdict back to its caller, which gates its next step on that verdict. Prevents fire-and-forget chains and closes the feedback loop.
type: pattern
date: 2026-05-29
tags: [pattern, skill-chain, verdict, conditional-pass, closed-loop]
instances:
  - apex-review → sim-conductor
  - agent-composer ↔ deliberation
---

# Return-Path Gate — Closed-Loop Skill Chain Pattern

A skill chain is **closed** when the downstream skill's output feeds back into the upstream caller's decision logic. Without a return path, downstream calls are fire-and-forget: the caller can't act on results, conditions go unresolved, and the chain terminates with unverified state.

The Return-Path Gate enforces closure: the caller registers a verdict expectation before calling downstream, the downstream returns a structured verdict, and the caller gates its next step on that verdict.

---

## Structure

```
[Caller Skill]
  Step N: Detect trigger condition
  Step N+1: Dispatch → [Callee Skill] (with topic + context)
  Step N+2: ◀ WAIT for verdict ▶
  Step N+3: Gate on verdict
    PASS           → proceed normally
    CONDITIONAL    → resolve listed conditions before proceeding
    FAIL/ESCALATE  → block + surface to user

[Callee Skill]
  Processes topic
  Returns structured verdict (not a binary win/lose)
  ↓
[Caller] receives verdict → re-enters decision logic
```

---

## Verdict Format (standard)

```
Verdict: PASS | CONDITIONAL_PASS | FAIL | ESCALATE
Conditions: [list — only present when CONDITIONAL_PASS]
Basis: [one-line rationale]
```

- **PASS** — proceed without modification
- **CONDITIONAL_PASS** — proceed only after listed conditions are addressed; conditions must be explicitly resolved, not silently skipped
- **FAIL** — block; requires redesign before proceeding
- **ESCALATE** — surface to user; decision requires human judgment

---

## Verified Instances

### 1. apex-review → sim-conductor

**Caller**: `apex-review`
**Callee**: `sim-conductor` (Area E — external scenario validation)

**Trigger**: apex-review produces `Conditionally passed` verdict
**Return path**: sim-conductor Area E results fold back into the apex-review HTML deck
**Gate logic**:
- `Passed` → deck is submission-ready
- `Conditionally passed` → **mandatory sim-conductor dispatch** (option B is default; user must explicitly opt out)
- `Rejected` → redesign required

**Why it matters**: Without this gate, persona conditions from apex-review are listed but never verified. sim-conductor's challenger/beginner/main-player validation is the only mechanism that resolves them.

---

### 2. agent-composer ↔ deliberation

**Caller**: `agent-composer` (Step 4-b state transition)
**Callee**: `deliberation` (3-layer: Innovator → Devil → Mediator)

**Trigger**: 2+ conflicting suggestions or design decision conflict detected in fan-in results → `Wave next-D`
**Return path**: deliberation synthesis verdict folds back into agent-composer Step 4-b fan-in result set → conflict marked resolved → state transition re-runs
**Gate logic**:
- Synthesis verdict (conditional, not binary) replaces the conflict entry
- Step 4-b re-evaluates with conflict resolved
- Auto-execution forbidden — user decision finalizes

**Why it matters**: Without the return fold, deliberation output is displayed to the user but the agent-composer orchestration loop doesn't update — the conflict remains unresolved in the state machine.

---

## Anti-Pattern: Fire-and-Forget

```
[Caller] → [Callee]
              ↓
         outputs result (displayed to user)
              ↓
         [Caller continues independently — does not act on result]
```

This is the default failure mode when a skill chain has no return path defined. Symptoms:
- Downstream output is shown but not acted on
- Conditions listed by callee remain unverified
- Caller proceeds as if callee succeeded unconditionally

---

## Implementation Checklist (when adding a Return-Path Gate to a skill)

- [ ] Caller SKILL.md: `§Done When` — explicitly states "wait for callee verdict before proceeding"
- [ ] Callee SKILL.md: `§Done When` — outputs structured verdict (PASS / CONDITIONAL_PASS / FAIL / ESCALATE)
- [ ] Callee SKILL.md: `§Chains` — "returns verdict to `[caller]`"
- [ ] Caller SKILL.md: `§Chains` — "→ Mandatory next (`[callee]`) when [condition]; verdict folds back into [step]"
- [ ] CONDITIONAL_PASS gate: default path is resolution, not bypass

---

## Verdict Extension (harvested from field use — pmh-dev@cbe3932, 2026-08-10)

The 4-tier enum is the floor, not the ceiling. A project may extend it (field precedent:
`WAVE_SKIP` / `WAVE_INSERT` for wave-orchestrating callers) under two rules:

- the extended enum is declared in the **callee's** SKILL.md verdict section — a verdict value the
  emitter never documents is prose, not a contract;
- the caller maps **any verdict value it does not recognize to ESCALATE** — an unknown verdict is a
  human-decision signal, never a silent PASS. (Same degrade direction as the typed-Verdict contract:
  unparseable ⇒ escalate, never optimistic.)

Do NOT harvest the field's `[Verdict]` block output format — FH's typed contract (final-line
`Verdict:` literal, #318) is newer and stricter; two competing formats would reopen the
divergent-normalizer class.

## Relation to Other Patterns

- **Three-Doctor Loop** (`harness-doctor ↔ context-doctor ↔ sim-conductor`) uses return paths implicitly — each doctor's output triggers the next. A full Return-Path Gate implementation would make the fold-back explicit.
- **verify-bidirectional** is a single-depth return path: AI recommendation → user counter-argument → AI baseline update. The verdict here is implicit (user correction = FAIL signal).
