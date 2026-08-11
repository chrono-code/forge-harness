---
name: convergence-loop
description: >-
  A universal gate-reinforcement meta-skill that replaces the "single-pass = done" pattern with a converging loop of up to N rounds. Can be applied to any gate, checkpoint, or verification step. Only declares "truly passed" after FAIL→FIX→re-verify repeats until convergence (all items pass). Escalates to structural redesign if not converged within N rounds. Triggers on: "convergence-loop", "how many rounds do we need", "suspicious of single-pass", "not sure if it really passed", or equivalent phrasing.
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Agent"]
model: sonnet
origin: contention-layer
contention-parents: [harvest-loop]
---

# convergence-loop — Universal Convergence Loop Gate Reinforcement

> A single pass declaration is hard to trust. A fix exposes new FAILs, and round 2 catches what round 1 missed. convergence-loop assigns a "truly passed" criterion to any gate.

## Triggers

- `/convergence-loop`
- "convergence-loop", "how many rounds do we need", "not sure if it really passed"
- "suspicious of single-pass", "run until it passes", "keep verifying until clean"
- "single pass isn't enough", "need another round", "the fix might have introduced new issues"
- Auto-proposed: when the same artifact receives a FAIL verdict 2+ times in the same session (observable: 2nd FAIL on identical scope)

---

## Origin

Extracted from a recurring "single-pass gate is hard to trust" pattern observed across multiple hub workflows. The canonical reference is:
- `harvest-loop` extract→attack→synthesize cycle: pattern extraction → attack → synthesis → the repeating structure must run until convergence

When the same structure recurs across gates, it is a skill.

## Applicable Targets

| Applicable Gate | Example |
|---|---|
| Skill diagnostic gate | harness-doctor + apex-review |
| Session harvest loop | harvest-loop extract→attack→synthesize cycle |
| External asset audit | steel-quench Wave 1~N |
| Domain-specific quality gate | Plug in any project-defined FAIL→FIX checkpoint |
| Any FAIL→FIX repeating structure | User-defined gate |

---

## Pipeline Structure

```
[Input] gate name + pass criteria + max rounds N (default 3)
    │
    ▼
Round 1
    │  Execute gate
    │  → All items pass: ✅ Round 1 passed → Round 2 (verification)
    │  → FAIL occurs: List FAIL items → Execute FIX → Round 2
    │
    ▼
Round N (N ≥ 2)
    │  Re-execute same gate (with FIX applied + search for new FAILs)
    │  → All items pass AND no FIX was applied in response to THIS round:
    │        ✅ Declare truly passed  ← the only terminating exit
    │  → All items pass BUT you fixed something this round (any severity):
    │        the fix is unverified → Round N+1
    │  → New FAIL: List → FIX → Round N+1
    │
    ▼
    │  → FAILs remain after N rounds: "Structural redesign required" → Escalate
    │  → Rounds clean but each keeps producing fixes: the fixes are manufacturing the
    │    findings → REDUCE THE DESIGN, then re-run (steel-quench §Convergence Criteria 4)
    │
    ▼ (if not converged within N rounds)
Escalation
    → Classify root cause: ambiguous criteria / FIX capability limit / gate design flaw
    → Output recommended action
```

**Core principle**: A fix exposing new FAILs is not a failure — it is a **signal that the gate is working correctly**. The deeper the round, the more fundamental the FAILs it uncovers.

---

## Execution Guidelines

### Setup (confirm before running)

```
Gate name:       [what checkpoint is this]
Pass criteria:   [specify pass condition — "all items ✅" or concrete criteria]
Max rounds:      [default 3; simple gates 2; complex gates up to 5]
FIX owner:       [auto-fixable / requires human / mixed]
Escalation:      [who to escalate to / how, if not converged within N rounds]
```

### Per-Round Execution Rules

**What must stay constant across rounds**:
- Pass criteria are immutable (no relaxing criteria per round)
- Cumulative tracking of FAIL items (verify that prior-round FAILs were fixed)
- New FAILs explicitly labeled (distinguish newly surfaced items from fix chain)

**What changes across rounds**:
- FIX-applied targets (revised TCs, skills, documents)
- FAIL list (should shrink; growth is also acceptable — it means items are surfacing)

### Convergence Judgment

```
Convergence = a round returns 0 new FAILs AND no FIX was applied in response to it
Conditions to declare truly passed:
  1. All items pass AND
  2. Nothing was changed in response to THIS round, at any severity
     (a FAIL you accept as residual is terminal; a FAIL you fix is not — the fix is unverified) AND
  3. At least 2 rounds executed (a single clean round is "provisionally passed" only)
     ← condition 3 is NOT redundant with 2 and was nearly lost when 2 replaced it: freezing answers
       "did the artifact change under the audit", min-2 answers "is one look enough". Independent
       questions, both still open. Done When and the pipeline diagram enforce min-2 as well.
NOT "0 new FAILs across 2 consecutive rounds": while every round ships fixes that can never fire,
so it reads as permanently not-converged and gets shipped past anyway. Stricter form for quench
waves: steel-quench §Convergence Criteria.
```

### Escalation Root Cause Classification

| Cause | Signal | Recommended Action |
|---|---|---|
| Ambiguous pass criteria | Same item judged differently each round | Restate criteria explicitly, then restart |
| FIX capability limit | FAILs detected but fix method unknown | Bring in expert or reduce scope |
| Gate design flaw | Same FAIL repeats after N rounds | Redesign the gate itself → meta-prompt-builder |

---

## Output Format

```
## convergence-loop Result

Gate: [gate name]
Max rounds: N | Actual convergence round: M

| Round | Verdict | FAIL Items | New FAILs | FIX Applied |
|:---:|:---:|---|:---:|:---:|
| 1 | FAIL/PASS | [item list] | — | Y/N |
| 2 | FAIL/PASS | [item list] | [new] | Y/N |
| 3 | PASS | none | none | — |

✅ Truly passed (converged at round M)
❌ Not converged within N rounds → Escalation: [root cause classification]
```

---

## Related Skills

| Situation | Related Skill |
|---|---|
| Applied to skill diagnostic gate | `harness-doctor` → convergence-loop wrapper |
| Applied to quench wave | `steel-quench` Wave 3+ — **stricter**: S/A grade + the no-repair clause. Defer to its §Convergence Criteria, do not re-derive |
| Applied to session harvest loop | `harvest-loop` extract→attack→synthesize cycle |
| When gate redesign is needed | `meta-prompt-builder` |

## Done When

Each condition declares its check class (mandatory-pass / measured / judged); every judged condition
names its adversarial pairing — no judge-only path.

```
Setup complete (gate name, pass criteria, max rounds confirmed)
  (mandatory-pass — all three named in writing BEFORE round 1; criteria written after seeing round-1
   output are post-hoc and do not satisfy this)
+ Minimum 2 rounds executed
  (measured: round count >= 2, read off the per-round table below)
+ Convergence declared (a round returns zero new failures AND you make no repairs in response to
  it, at any grade) or escalation triggered
  (measured: the round's new-failure count = 0 AND its repair count = 0 — two numbers, both recorded
   per round; a single-number reading is what let "0 new failures while still repairing" pass)
  ⚠️ NOT "2 consecutive rounds": while every round ships repairs that criterion can never fire, so
  it reads as permanently not-converged and gets shipped past. Adjudicated with measured evidence in
  `steel-quench` §Convergence Criteria (2026-08-02).
+ Escalation root cause classified when max rounds is hit without convergence
  (judged — adversarial pairing: `fh-commons:quench-challenger` argues that the loop stopped because
   the GATE is blind rather than because the artifact is clean; an unchallenged "converged" on a
   gate that never produced a FAIL is the failure mode this pairing exists to catch)
+ Per-round result table output
  (mandatory-pass — one row per executed round, each carrying its new-failure and repair counts;
   a missing row makes the two measured conditions above unreadable)
```

## External anchor (independent convergence)

arXiv:2606.27009 (*Semantic Early-Stopping for Iterative LLM Agent Loops*, 2026-06-25, verified
2026-06-27) externally validates this skill's core thesis — **stop on convergence, not a fixed
iteration cap** — measuring −38% tokens vs fixed caps when stopping is *judge-free* (consecutive draft
embeddings stop changing in meaning). **Sharpening, not blind validation**: the same paper finds
*quality-gated* stopping (a judge call each round) counterproductive due to judging cost, and that an
oracle picking the best round beats any stopping rule — so the harder problem is *which* round was
best, not *when* to stop. Implication for this skill's judge/checklist-gated rounds: per-round
verification cost is real; prefer a cheap convergence signal where one exists, and keep `max rounds N`
bounded.
