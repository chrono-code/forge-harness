---
name: agent-composer
description: Reads the current work context and plans the optimal agent dispatch. Clarifies direction with 1-2 questions when unclear; infers and proceeds immediately when execution path is unclear. Runs an automatic recording gate after each Wave completes. Triggered by "compose agents", "which agent should I use?", "run in parallel", or "agent-composer".
user-invocable: true
allowed-tools: ["Read", "Bash", "Glob", "Grep", "Agent", "Skill"]
model-note: session-inherit — Sonnet base is first-class (sonnet_floor_doctrine.md); depth-critical judged steps route to dispatch (opus agent / cross-family sidecar, consent-gated), never a substrate requirement
---

# agent-composer — Agent Composition Layer

A coordinator skill that reads the work context and decides "which agents to dispatch, when, and in what order."
Selects the optimal combination from the FH skill pool and either outputs a fan-out plan or executes it directly.

## Triggers

- `/agent-composer`
- "Which agent should I use?", "Pick one automatically", "Compose the agents"
- "Set up the agents", "Decide which agents to use"
- "Split the work and run in parallel", "Process with multiple agents"
- "Build the dispatch plan", "Run in parallel splits"
- When the task is complex or spans multiple projects

## Core Principles

- **Compose only**: Does not perform work directly. Outputs the dispatch plan and executes after user approval.
- **Parallel first**: When 2+ tasks are independent, propose parallel fan-out instead of sequential.
- **Minimal composition**: Only the agents needed. Over-provisioning agents creates inefficiency.
- **Coordinator ≠ executor**: Only collects results (fan-in) and presents an integrated report.

---

## Step 0. Context Collection

Identify 4 items from the request: task type · scope · constraints · natural-language goal → skill mapping.
Check `LOCAL_SKILL_REGISTRY.md` for project-local skills; check `.mcp.json` or `CLAUDE.md` for external plugins.

> **Detail**: See `SKILL_detail.md §Step-0` — NL pattern mapping table, cross-install detection, registry lookup format — read when auto-mapping an ambiguous request.

---

## Step 0.2 — Capability Fit Analysis

> **Schema**: `knowledge/shared/harness-core/tpa_schema.md` — `artifact_type` enum determines `role_match` lookup domain for scoring.
> Runs before dispatching agents. **Skip if user specifies exact agents by name.**

For each subtask in the composition plan:

1. **Read agent registry**: `.claude/agents/*.md` + installed plugin agents  
   Extract: `role` · `allowed_tools` · `writes` · `declared_capabilities`
2. **Score capability fit**: `[subtask_type]` × `[agent capabilities]` → `fit_score` (0.0–1.0)
3. **GAP**: `fit_score < 0.5` for a required-weight subtask  
   → query `/plugin-recommender`: "agent for [subtask_type] in [context]"  
   → includes Codex marketplace + Claude Code marketplace (not just FH native)  
   → user: **install** / **skip** / **use general-purpose fallback**

### Capability Fit Scoring Table

| Subtask type | Strong fit signal | Weak fit signal |
|---|---|---|
| Adversarial review | `subagent_type="challenger"`, artifact_type match | general-purpose only |
| Phantom detection | `phantom-quench` | general-purpose only |
| Persona simulation | `hub-persona-auditor`, deep-insight persona | general-purpose only |
| Code generation | `writes: true` + code tools | `writes: false` or no code tools |
| Audit-only | `writes: false` (safe) | `writes: true` (risky for audit) |

### Author-Exposure Table — a review pass, not a second executor

The table above picks **who does the subtask**. This one adds a different question at a different
stage: **what failure is the author structurally exposed to, now that the work is claimed done?**
It never replaces capability fit and never selects the agent that performs the work — it adds a
**review pass** before the work is released. A doc-writing subtask scores no "adversarial review"
fit, yet its author is blind to cold-entry failure, and capability fit never surfaces that.

**Materiality gate — run this pass only when the work product is material.** At least one of:
public or otherwise irreversible surface · affects users other than the author · carries external
claims, numbers, or citations · introduces new behavior · touches security, data, deletion, or
permissions. Internal notes, wording fixes, and one-line edits do **not** trigger it — an
unbounded trigger just trains the pass into being skipped.

| Failure the author cannot self-detect | Review mechanism | Type |
|---|---|---|
| Cold entry — first contact breaks (missing install step, undefined term, no success signal) | `beginner` | agent |
| Everyday-use friction invisible to the designer | `main-player` | agent |
| Currency vs the outside field (needs external citation, not assertion) | `expert` | agent |
| Self-verification only fails in the optimistic direction | `challenger` + `auto-decorrelation` | agent + pipeline |
| Rebuilding something that already exists | `fact-checker` · `asset-placement-gate` | agent · skill |
| Numbers/citations living in the artifact without grounding | `phantom-quench` | skill |
| **Exposure unclear** (material, but no row above fits) | `challenger` | agent — default, not a skip |

The `Type` column matters for the capability-fit checks above: `writes`/tooling scoring applies to
**agent** rows only; skill and pipeline rows are invoked, not scored.

**Behavioral rule — no silent skip, and "no row applies" is not an exit.** Name the row before the
agent. If you believe none applies, you must (a) state which rows you considered, (b) give a
one-line reason each is excluded, and (c) fall through to the **Exposure-unclear** row — the
default is `challenger`, never nothing. (Origin: 2026-07-21 — four dispatches in one session were
chosen by orchestrator judgment alone. They were right; that is luck, not a mechanism. In the same
session one `beginner` dispatch blocked a public-repo merge on 4 findings the author had not seen.)

**Behavioral rule — the lens does not hold the verdict.** A review pass returns `evidence`,
`risk`, and a `recommended decision` only. It may **not** emit a terminal `block`/`approve`; the
orchestrator declares the outcome, on its own stated grounds, and approval on an irreversible
surface stays with the human regardless of what the lens returned.

**Row-growth criterion (anti-case-crafting).** A new row is admissible only if the failure type has
been **observed more than once**, is **not coverable by an existing row**, and names a *verifiable
exposure axis* rather than a job title or a favorite tool. If rows keep accreting, that is the
signal to fold the table into a smaller set of principled axes — not to keep appending.

**Behavioral rule**: A `writes: false` agent (e.g. fact-checker, hub-persona-auditor) must NOT be assigned a task requiring edits. Capability fit scoring catches this statically before dispatch.

**Behavioral rule**: Degraded composition — when any required-weight role is filled with general-purpose fallback, output `⚠️ degraded: [role]` in the composition plan. Do not silently use general-purpose for a specialized role.

> **Detail**: See `SKILL_detail.md §CapabilityFit` — scoring procedure, agent registry reading, plugin-recommender query format, worked examples — read when executing Step 0.2.

---

## Step 0-a. Clarification Protocol

> Execution condition: Only when direction or goal is unclear (skip → go directly to Step 0-b if clear)

**Core principle**: Only ask when what the person must provide (direction · insight · decision) is unclear.
Execution method · agent selection · recording location → infer and proceed — do not ask.

### Direction vs. Execution Decision Table

| Request type | Classification | Action |
|---|---|---|
| "Do X" — target and completion criteria are clear | Clear | Immediately enter Step 0-b |
| "Improve X" — improvement dimension unclear | Direction unclear | Ask for clarification |
| "Something feels off" — diagnosis target unclear | Execution unclear → infer | Auto-dispatch harness-doctor |
| "Wrap up / harvest this session" — trigger is clear | Clear | Run harvest-loop based on recent work ("run the pipeline" itself is ceded to pipeline-conductor — route end-to-end sweeps there, not here) |
| No request — session context exists | Execution unclear → infer | Auto-compose based on CATALOG/MEMORY, then confirm |

> **Detail**: See `SKILL_detail.md §Clarification` — 2-question format, 4-question structured confirmation, meta-prompting intervention — read when direction ambiguity requires a clarification block.

---

## Step 0-b. Wave 0 — Reconnaissance Dispatch (Mandatory Before New Tasks)

> Execution condition: For cross-project tasks or when scope is unclear. Skip for single-project tasks with clear scope.

This orchestrator does not read files or understand structure directly — **even reconnaissance work is dispatched as agents.** All tasks including new assets → fact-checker (A) mandatory in Wave 0.

> **Detail**: See `SKILL_detail.md §Wave-0` — self-contained brief requirements, deferred ToolSearch pre-requisite pattern — read when writing a recon agent brief.

---

## Step 1. Agent Mapping

Default composition table by task type.

> **Note**: This table lists known installed agents. Capability fit scoring in Step 0.2 overrides static mapping when `.claude/registry/agent_cards.json` (repo-relative — there is no bare `agent_cards.json` at the repo root) has more current data.

> **Call method distinction**: `(S)` = Skill tool call / `(A)` = Background dispatch via Agent tool

| Task type | Default composition | Parallel |
|---|---|:---:|
| **[Wave 0] Recon (all tasks)** | Recon agent (A) — file/structure understanding. Direct orchestrator execution forbidden | — |
| **[Wave 0] All tasks including new assets** | fact-checker (A) — proactive duplicate/stale validation | — |
| Meta-simulation quality validation | sim-conductor (S) — challenger + beginner + main-player | ✅ Parallel |
| Field pattern harvest | field-harvest (S) | — |
| Harness structural diagnosis | harness-doctor (S) | — |
| New asset placement decision | asset-placement-gate (S) | — |
| External user entry point audit | hub-persona-auditor (A) | — |
| Naming/innovation scan | persona-innovator (A) | — |
| Cross-project simultaneous work | N field agents (A) | ✅ Parallel |
| Three-Doctor Loop | harness-doctor (S) + context-doctor (S) + sim-conductor (S) | ✅ Parallel |
| Pre-PR code review | sim-conductor D-code 3 personas (S) | ✅ Parallel |
| Learning cross-validation | verify-bidirectional (S) | — |
| Ecosystem synergy exploration | cross-ecosystem-synergy-detection (S) | — |
| Plugin recommendation | plugin-recommender (S) | — |
| Install conflict diagnosis | install-doctor (S) | — |
| Onboarding install | install-wizard (S) — ⚠️ interactive; `--dry-run` for bg parallel | — |
| Hub PR review | hub-cc-pr-reviewer (S) — requires PR number first | — |
| **Decision-maker approval review** | apex-review (S) — CTO/tech lead/QA lead personas + HTML deck | — |
| **Project local skills** | LOCAL_SKILL_REGISTRY lookup → relevant project skill (A/S) | Per project |

---

## Step 2. Composition Plan Output

```
agent-composer — Composition Plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Task: {task summary}
  Composition: {N} agents  |  Parallel: {Y/N}  |  Estimated time: ~{N} min

  Wave 0 (Recon):
    [R] Recon agent — {file/structure understanding goal}

  Wave 1 (Parallel):
    [A] {agent name} — {role in 1 line}
    [B] {agent name} — {role in 1 line}

  Wave 2 (after Wave 1 completes):
    [D] {agent name} — {executed after result integration}

  fan-in: integrate results after Wave completes → output report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Execute? (Y: run all / E: edit then run / N: cancel)
```

Optionally name the composition's shape in the plan header (`Composition pattern: {name}`) so the
operator recognizes the structure at a glance — a recognition aid, not a routing input.

> **Detail**: See `SKILL_detail.md §Composition-Pattern-Labels` — the six revfactory-vocabulary labels
> (Pipeline / Fan-out-in / Expert Pool / Producer-Reviewer / Supervisor / Hierarchical) mapped to the
> existing FH constructs they name — read when labeling a plan header.

---

## Step 2.5 — Model Routing Decision (complexity_routing)

### Routing Rules

1. No `complexity_routing` in skill frontmatter → use `model:` field as-is
2. `complexity_routing` present + any `escalate_when` condition matches → use `high` model
3. No conditions match → use `base` model

Include 1-line routing audit in composition plan output: `[Model routing] harness-doctor: cold_start → opus`

### Default Architecture

| Mode | Orchestrator | Executor | When |
|---|---|---|---|
| **Base** | sonnet | sonnet | Default — all tasks |
| **Amplified** | opus | sonnet | `EXECUTION_TIER: full/max` · plan mode · `cross_project` + `high_stakes` both detected |

**Simplification guard**: Single-Wave, single-project tasks → Sonnet sufficient. Do not escalate.

> **Detail**: See `SKILL_detail.md §Model-Routing` — escalation condition evaluation table, amplified audit log format.

---

## Step 2.7 — Destructive Action Gate

After scanning the composition plan, if any of the following types are found, mark with 🚨 and output a separate warning before Step 3.

| Type | Examples |
|---|---|
| External send | git push/force, PR create/merge, Slack/wiki upload |
| File/data destruction | rm -rf, DB DROP/DELETE, file overwrite, branch delete |
| Production impact | Service deploy, migration, permission/config changes |

If 🚨 items exist, insert before the standard Y/E/N in Step 3:

```
⚠️  Irreversible operations are included:
    - [type] [specific operation]
    Do you want to proceed? (yes / no)
```

`no` → remove that operation or cancel entirely. Safe remaining operations can continue.

---

## Step 3. Approval → Execution

- **Y**: Execute immediately. Generate Context Cards (Step 3-a), then dispatch parallel agents in a single message.
- **E**: User modifies plan then re-confirms.
- **N**: Cancel.

> **Detail**: See `SKILL_detail.md §Worktree-Isolation` — Step 3.1 parallel proposal mode with git worktree isolation — read when 2+ agents write to overlapping files.

### Step 3-runtime. Dispatch Runtime Selection

Use the runtime available in the current session:

| Runtime | Dispatch mechanism |
|---|---|
| Claude Code | `Agent(...)` for agents, slash/skill invocation for skills |
| Codex-primary | `FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run --agent {agent}` or `--skill {skill}` |
| Generic shell | `FH_BACKEND=auto npx --package @chrono-meta/fh-gate fh-run ...` |

When using `fh-run`, pass each agent's Context Card through `--prompt` and pass target files with repeated `--file` arguments. The fan-in obligation is unchanged: collect each adapter output, then synthesize one integrated report before proceeding to the next wave.

### Step 3-a. Context Card Injection (required for 2+ parallel agents)

Sub-agents are spawned in isolation — they cannot see the live conversation. Inject a Context Card into each agent prompt before dispatch to prevent context blindness (duplicate work, stale direction, missing constraints).

**N≤2 (standard)**:
```
[Session Context Card]
Purpose: {session goal}
Completed: {done items + file paths — agent must know to avoid duplication}
This agent's task: {specific task for this agent}
Note: {constraints / history the agent must know}
```

**N≥3 (Registry mode — DACS-inspired, arXiv:2604.07911)**:
```
[Session Context Card]
Purpose: {session goal}
Completed: {done items + file paths}
This agent's task: {specific task}
Note: {constraints}

[Agent Registry]
Agent-1 ({role}): {≤1 sentence — what it's doing, key files}
Agent-2 ({role}): {≤1 sentence}
... (all agents except this one)
```
Total Registry ≤200 tokens. Each agent receives its own full card + compressed view of all other agents.

**Coordination-overhead budget** (apply before each Wave):

| Rule | Constraint |
|---|---|
| **Per-wave fan-out cap** | ≤4 agents per dispatch wave. Above 4: decompose hierarchically (supervisor → sub-waves), not flat fan-out |
| **Capability-aware routing** | Match each subtask to agent's `role` + `allowed_tools` + `writes`. Never dispatch a `writes: false` audit agent (e.g., fact-checker, hub-persona-auditor) for a task requiring edits |

Rationale: orchestrator-worker coordination adds ~+285% token overhead at N≥5 flat fan-out (DACS, arXiv:2604.07911). Sub-waves amortize this.

**Focus Mode** (N≥3, on-demand only): When an agent signals `"Need full context from Agent-X to proceed"` → re-dispatch that agent with Agent-X's full Context Card + Registry-compressed view of others. Use only when genuinely needed — adds one round-trip.

**Omit card**: Simple read-only lookup agents with no context dependency may skip injection.

---

## Step 3.5 — Inter-Wave Adaptation Check (Runtime Adaptation)

After Wave N completes, before Wave N+1, evaluate:

**① Premise Reversal** — Does Wave N result reverse a Wave N+1 premise? → revise plan, confirm with user
**② Repeated Failure** — Same agent failed 2+ times? → exclude + suggest replacement
**③ Early-Harvest Trigger** — 3+ new patterns discovered? → propose mini-harvest before Wave N+1

**Simplification guard**: Skip for simple tasks with only one Wave (Wave 0 + Wave 1).

> **Detail**: See `SKILL_detail.md §Wave-Adaptation` — adaptation check output format.

---

## Step 4. fan-in — Result Integration

> **M/S/R tier criteria**: M = blocks external user entry / structural conflict / immediate action required · S = feature degradation / address within next session · R = improvement value / backlog

Each agent finding must satisfy the **loom fan-in contract** (3 fields minimum): `tier | location | fix suggestion`. Results not meeting this format → mark "format non-compliant" and re-request or skip.

Integrate results into M/S/R tiers → output completion report:

```
agent-composer — Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Executed: {N}  |  Time: ~{N} min  |  Parallel gain: {N}x vs sequential
  M: {N} items → [action suggestion]
  S: {N} items → backlog
  R: {N} items → backlog
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

> **Detail**: See `SKILL_detail.md §fan-in-Contract` — per-row format spec, format non-compliant handling.

---

## Step 4-b. State Transition Gate

After fan-in report, evaluate conditions and auto-suggest the next Wave:

| Condition | Wave suggestion |
|---|---|
| ① M-tier > 0 | **Wave next-M**: fact-checker (A) → hub-cc-pr-reviewer (S) |
| ② persona-innovator naming candidates > 0 | **Wave next-I**: delegate to user + asset-placement-gate (S) |
| ③ External absorption signal High > 0 | **Wave next-E**: persona-innovator Mode E (A) + meta-prompt-builder (S) |
| ⑤ Design conflict / 2+ conflicting suggestions | **Wave next-D**: deliberation (S) — verdict folds back into Step 4-b |
| ④ All 0 | **End**: "backlog only, defer to next session" |

Naming/direction/deliberation decisions: auto-execution forbidden — user confirmation required.

---

## Step 4-c. Auto-Recording Gate

| Condition | Auto action |
|---|---|
| 2+ new files created or 3+ existing files changed, **or M-tier resolved** | harvest-loop lightweight mode (field-harvest → contention → verify-bidirectional) |
| Architecture/direction decision made | "Record this decision? [1-line summary]" — save after confirmation |
| None of the above | Fall back to field-harvest proposal |

Auto-recording allowed scope: file change lists + execution results. Decision content and naming require confirmation.

> **Detail**: See `SKILL_detail.md §Auto-Recording` — Wave execution recording format, harvest-loop lightweight mode pipeline, human decision gate.

---

## Step 5. Wave 4 — Final Judgment Gate

Execute after all Waves 0~3 complete. Auto-skip for simple exploration or planning tasks.

### Judgment Logic

```
IF M-tier == 0 AND S-tier < 3:
    → PASS  (merge approved)
ELIF M-tier >= 1:
    → BLOCK (immediate fix required)
ELSE:  # M-tier == 0 AND S-tier >= 3
    → PASS  (S-tier allows backlog — not a merge block reason)
```

| Judgment | Auto-proposal |
|---|---|
| **PASS** | field-harvest proposal: "Are there patterns to harvest from this Wave?" |
| **BLOCK** | Fix M-tier items → suggest re-entry into Wave 1 |

> **Detail**: See `SKILL_detail.md §Wave4` — entry conditions, judgment output format, auto-proposal format.

---

## Phase Guard Pattern (Stage Entry Gate)

| Dependency | Rule |
|---|---|
| Wave 0 (recon) not complete | Cannot enter Wave 1 |
| Wave 2 (fan-in) not complete | Cannot enter Wave 4 |
| State transition (Step 4-b) not complete | Cannot enter Wave next-M/I/E/D |

Maximize parallel fan-out among independent agents; dependent stages wait for prior Wave completion.

---

## Step 6. Round Wrap + Proactive Next Step

Execute after Wave 4 PASS + Step 4-c recording complete.
3-line completion summary → up to 3 next-round suggestions → fh_signal persistence confirmation.

**Proactive suggestion priority** (suggest only 1):

| Situation detected | Suggestion |
|---|---|
| 2+ FH files modified | `harness-doctor` auto-run (after user confirmation) |
| New skill/plugin added | `cross-ecosystem-synergy-detection` |
| Important artifact completed | `steel-quench` |
| No frontier-digest today + large session | `frontier-digest` |
| None | "ready for next session" |

**Anti-redundancy guard**: if this composition was invoked **by** goal-quench (detect `.claude/goal-quench.active` present with `mode: pro|max`), suppress any suggestion that points back to `/goal-quench` — goal-quench is already the caller, so re-suggesting it is a redundant, confusing loop. Return control to goal-quench instead. See Cross-reference below.

> **Detail**: See `SKILL_detail.md §Round-Wrap` — 6-1 completion summary format, 6-2 next round suggestions format, 6-3 fh_signal persistence format.

---

## Execution Tier

| Tier | Tokens | Scope |
|:---:|:---:|---|
| **light** | ~5K | Wave 0 + Wave 1 single → output → end |
| **standard** | ~15K | Wave 0 + Wave 1 multi → fan-in → one proactive suggestion |
| **full** | ~30K | + Wave N state transition → conditional lightweight harvest |
| **max** | ~60K+ | + Three-Doctor Loop → full harvest-loop → next Wave follow-up |

Configure via `EXECUTION_TIER: standard` in CLAUDE.md. Temporary override: "use light mode" / "run at max".

---

## Simplification Guard

- Single-agent tasks → guide user to call that skill directly (skip agent-composer)
- Risk of two agents editing the same file in the same Wave → recommend Wave separation

### Fan-out Scale Tiers

| Tier | Count | Behavior |
|---|---|---|
| **Small** | 2–4 | Dispatch immediately (within per-wave cap) |
| **Medium** | 5–16 | Decompose into sub-waves of ≤4; confirm scale before dispatch |
| **Large** | 17+ | Worktree isolation mandatory + explicit user approval required |

---

## Done When

```
All stages Step 0~6 complete
+ Wave composition plan finalized + execution complete
+ fan-in loom complete: M-tier 0 AND S-tier < 3 → PASS
  or user has confirmed Wave end
+ When deliberation was invoked: wait for verdict before closing Wave N+1;
  verdict folds back into Step 4-b fan-in result set
+ Auto-recording gate (Step 4-c) complete — confirmed by the RECORD ARTIFACT (harvest output
  file exists on disk + harvest-loop typed `Verdict:` line read), never by a completion notice
  alone (completed-notice ≠ completion — return-path audit 2026-08-10)
```

> **Sprint Contract**: Done When must be in an externally verifiable contract format — "criteria a third party can confirm," not "when it feels done." (Anthropic official validation 2025)

---

## Identity

agent-composer is the FH **coordinator** above specialist agents — decides "which agent combination is optimal." Also acts as **Curator**: detects stale/duplicate agents and proposes merge candidates.

| Human domain | System domain |
|---|---|
| What to build, why (direction + insight) | Which agents and how (composition + ordering) |
| Final adoption decision | Pipeline execution + result aggregation |
| Naming/framing | Recording + quality gates |

If unclear item is in human domain → ask. System domain → infer and proceed.
(Brain/Hands decoupling: agent-composer is Brain-only. Brain = goal parsing → Wave construction → gate decisions.)

---

## Cross-reference — goal-quench (upstream caller)

`goal-quench`'s **pro / max** modes invoke agent-composer for goal decomposition (goal-quench Phase 1.5 Step B). The relationship is one-directional and the entry points differ by intent:

| User intent | Entry point | agent-composer's role |
|---|---|---|
| "Compose/dispatch agents for this work" | `/agent-composer` directly | Primary — composes and runs the Wave plan |
| "Run a large/budget-gated `/goal` safely" | `/goal-quench --pro` / `--max` | Sub-step — receives the task in compose-only mode, returns a sub-goal Wave plan, hands control back to goal-quench |

**Routing note**: when a user frames a large or token-sensitive `/goal` run, prefer `/goal-quench` as the entry point — it wraps this skill with budget + quality gates that a bare agent-composer run does not provide. agent-composer does **not** re-invoke goal-quench (that is the caller); the Step 6 anti-redundancy guard enforces this.
