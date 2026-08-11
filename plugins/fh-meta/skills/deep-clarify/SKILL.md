---
name: deep-clarify
description: Clarifies ambiguous requests through Socratic dialogue, drawing out goals, completion criteria, and constraints to produce a structured spec document. Pre-dispatch requirement clarification step for agent dispatch. Triggered by "I don't know what to build", "how should I approach this", "organize this for me", "clarify this", "deep-clarify".
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Glob"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - cross_project
    - high_stakes
---

# deep-clarify — Socratic Requirement Clarification

A skill that clarifies vague or open-ended requests through conversation to produce **actionable spec documents**.
An independent extension of the "direction confirmation" protocol from agent-composer Step 0-a.

## Triggers

- `/deep-clarify`
- "I don't know what to build", "How should I approach this?"
- "Organize the requirements", "Write a spec document"
- "What should I do with this?", "The direction is unclear"
- When agent-composer detects pre-dispatch clarification is needed and delegates automatically

## Core Principles

**Criteria for asking vs inferring**:
- Things only the human can know (goal, priorities, constraints, completion criteria) → ask
- Things AI can infer (implementation method, file location, technology choices) → infer and present as `(inferred: X)`
- Questions: **maximum 3 rounds, maximum 2 questions per round** — do not overuse

---

## Step 1. Request Analysis

Quickly identify the following from the user's request.

```
Clarity check:
□ Final state (what will be different when done?) — ask if unclear
□ Completion criteria (how will it be verified?) — ask if unclear
□ Constraints (what must not be done, what must not be touched) — ask if unclear
□ Priority (fast vs thorough, now vs later) — ask if unclear
```

**Direct entry conditions** (skip to Step 3 without questions):
- Request is specific and completion criteria are clear → draft spec document and confirm
- Clarity at the level of "add Y feature to file X"

---

## Step 2. Socratic Dialogue

### Round 1 — Goal / Completion Criteria (core 2 questions)

```
Clarification needed.

1. Completion criteria: What does a completed [task name] look like?
   (inferred: [inferred completion criteria] — confirm if correct)

2. Scope: Which of [A / B / C] takes priority?
   (inferred: [inferred choice] — reason: [rationale])
```

### Round 2 — Constraints / Priority (only if needed)

Skip if Round 1 resolves everything.

```
1. Is there anything this task must absolutely not do?
2. Which takes priority: fast completion vs solid design?
```

### Round 3 — Final Confirmation (only if needed)

Draft the spec first, then single confirmation: "Is this the right direction?"

---

## Step 3. Generate Spec Document

Structure and save the results of the conversation. **This step writes a file** — outputting the
path is not saving it.

1. Derive the slug: `slug = kebab-case(spec title) + "-" + YYYYMMDD`
   (lowercase, non-alphanumerics → `-`, collapse repeats, strip leading/trailing `-`).
   Example: "Rewrite the login flow" on 2026-08-11 → `rewrite-the-login-flow-20260811`.
2. If `.claude/specs/{slug}.md` **already exists → ABORT** and report the existing path.
   Never overwrite and never silently suffix — an existing spec is a prior decision to extend or
   supersede, and that is the user's call.
3. Create the directory, then write the file with the **Write** tool (not a shell redirect):

```bash
mkdir -p .claude/specs
```

Then `Write` → `.claude/specs/{slug}.md` with the format below, and verify:

```bash
test -f .claude/specs/{slug}.md && echo "SPEC SAVED: .claude/specs/{slug}.md"
```

**Residency**: the spec records the user's goals, constraints, and "must not touch" list.
`.claude/specs/` is gitignored in this repo; **in a company project, confirm the path is gitignored
there too before writing** — if it is not, write to a gitignored location instead.

### Spec Document Format

```markdown
# Spec: {task title}
Created: {date} | Status: draft

## Goal
{One sentence — what is being built and why}

## Completion Criteria
- [ ] {verifiable condition 1}
- [ ] {verifiable condition 2}

## Scope
Included: {what is explicitly included}
Excluded: {what is explicitly excluded}

## Constraints
- {technical constraint}
- {what must not be done}

## Priority
{Fast completion / Solid design / Balanced} — {reason}

## References
{related files / existing skills / prerequisite work}
```

---

## Step 4. Follow-up Connections

After generating the spec document, suggest the appropriate next path:

| Situation | Connected skill |
|---|---|
| Agent orchestration needed for implementation | `agent-composer` — pass spec document path |
| Plan / design review needed | built-in `Plan` agent — build plan based on spec |
| Single task is now clear | Start implementation directly |
| Audit needed before external sharing | `hub-persona-auditor` |

---

## Done When

| Condition | Completion verdict | Check class |
|---|---|---|
| Socratic dialogue complete (≤3 rounds, ≤2 questions/round) | ✅ Clarification complete | **mandatory-pass** |
| `test -f .claude/specs/{slug}.md` exits 0 — the file **exists on disk** | ✅ Save complete | **mandatory-pass** (a printed path is not a saved file) |
| The spec's Completion Criteria are independently verifiable — someone other than the author could tell whether each is met | ✅ Spec actionable | **judged** — adversarial pairing: `fh-meta:beginner` cold-reads the spec and attempts to state, per criterion, how they would check it; a criterion they cannot operationalize fails |
| Follow-up skill connection suggestion output | ✅ Handoff complete | **mandatory-pass** |

**This skill's Done When = "actionable spec document saved".** Implementation itself is the domain of follow-up agents/skills.
