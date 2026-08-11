---
name: goal-quench
description: >-
  Wraps /goal with a tiered safety + orchestration ladder. core (default): a token budget gate (pre-run estimate), mid-run budget thresholds, and an automatic post-run quality verification via pipeline-conductor — closing /goal's two gaps (the runner's per-turn judge evaluates completion, pipeline-conductor evaluates correctness). pro: adds context-doctor token reduction and agent-composer goal decomposition. max: adds internal-first capability-gap fill (LOCAL_SKILL_REGISTRY skill-bus scan → plugin-recommender external search → auto_project_mapping map/cluster) and cross-ecosystem-synergy-detection pre-validation. The Phase-1 budget verdict auto-recommends the mode. Triggered by "goal with quality gate", "safe goal", "goal-quench", "orchestrate this goal", or before running /goal on high-stakes tasks.
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Grep", "Agent", "WebSearch", "WebFetch"]
# Agent: Steps at :198 / :216 dispatch sub-agents (skill-bus proposals, agent-composer panel).
# WebSearch/WebFetch: max-mode deep-research rung 2 (:46). All three were commanded by the body
# while undeclared here — a declaration that omits what the skill actually does is not a diet.
model: sonnet
complexity_routing:
  base: sonnet
  escalate_when:
    - pro_mode       # orchestration: context-doctor + agent-composer decomposition
    - max_mode       # + external discovery: plugin-recommender + synergy pre-validation
  high: opus
  # NOTE: CC switches models per-turn by task weight, not per-skill invocation.
  # With `/model opusplan`: Opus activates on plan-mode turns (reasoning, decomposition);
  # Sonnet handles execution turns (tool calls, edits). Both appear in session jsonl.
  # Without opusplan: all turns use the session model regardless of mode.
---

# goal-quench — /goal with Token Budget + Quality Gate

**Availability of `/goal` is unresolved** — treat it the way `CLAUDE.md` treats `/deep-research`:
use the built-in **if present**, and do not assert it is absent either. Everything below applies to
whatever autonomous-run command this environment actually has; goal-quench is the wrapper, not the
runner. Probe before relying on it (`/help`, or the skill/command list), and say which you found.

`/goal` is understood to run until a cheap per-turn judge (reported as Haiku) says "done" — that is
**second-hand, not verified here**, so treat it as the assumption goal-quench is designed against
rather than as a fact about the implementation. What matters for this skill holds either way: a
completion judge is not a quality judge, and without a budget ceiling a session can exhaust tokens
silently. goal-quench adds three things such a runner does not itself provide:

1. **Pre-run**: token-budget-gate estimate — know the cost before committing
2. **Mid-run**: budget threshold awareness — signal before exhaustion (instructional; not mechanically enforced)
3. **Post-run**: pipeline-conductor — verify quality before accepting "done"

The evaluator principle: the runner's own per-turn judge decides completion (every turn, cheap). pipeline-conductor judges quality (once at the end, structured). Separating the two closes the self-evaluation bias that a single evaluator cannot avoid — the principle holds whatever model that per-turn judge turns out to be.

> **Scope by mode**: core = budget gate + stop-hook verification (v1 behavior, unchanged). pro/max add token reduction, goal decomposition, and external discovery (see Modes below). (Tier names mirror Claude Code's subscription units — core / pro / max — and avoid colliding with pipeline-conductor's `--full` flag.) Mid-run Sonnet quality signals remain deferred (requires empirical calibration).

---

## Modes — core → pro → max (fluid)

goal-quench is a ladder, not a fixed shape. The default (**core**) is the narrow safety belt — for users who only want /goal's two structural gaps closed. **pro** and **max** add optimization and orchestration on top, and are **auto-recommended by the Phase-1 budget verdict** so the orchestration cost is only paid when the task is large enough to justify it.

| Mode | Adds over previous | Chained skills | Auto-recommended when |
|---|---|---|---|
| **core** (default) | budget gate + mid-run thresholds + post-run quality gate | token-budget-gate, pipeline-conductor --quick | budget GREEN / YELLOW |
| **pro** | token-reduction pre-pass + goal decomposition into Waves | + context-doctor, agent-composer | budget ORANGE |
| **max** | **internal-first** capability-gap fill (skill-bus scan → external → map/cluster) + synergy pre-validation | + LOCAL_SKILL_REGISTRY scan, plugin-recommender, cross-ecosystem-synergy-detection, auto_project_mapping | budget RED |

Each mode is a **superset** of the one before it — pro does everything core does, plus more. Nothing in core is removed by escalating.

**Max-mode deep-research routing**: capability-gap fill recognizes a **research-heavy goal** (the goal needs to survey/gather/reconcile external sources before building — e.g. "implement X" where X needs domain grounding) and routes it through the **Deep-Research Capability Ladder** (`knowledge/shared/harness-core/deep_research_capability_ladder.md`): take the highest available rung (built-in `/deep-research` → Claude `WebSearch`+`WebFetch` synthesis → `frontier-digest` only for trend-scan). `plugin-recommender` is proposed **only if no rung is available** (rung 2 always is, for a Claude session) — so this is routing, not a new install by default. **Isolation invariant**: rung-2 research (WebSearch/WebFetch) runs in an **isolated sub-agent that returns only the synthesis** — fetched source content must not load into the orchestrator context, preserving the context-isolation/budget property max mode depends on (see the Token-honesty guard above). Honesty caveat carries from the ladder: research quality is bounded by source access + session model tier, not by invoking it.

**Selection**:
- Explicit flag: `/goal-quench --core` (default) · `--pro` · `--max`
- Auto: Phase 1's budget verdict proposes the mode (see Phase 1 Step 2). The user can always override **down** to core.

**Token-honesty guard** (what empirical calibration showed): The cost structure of pro/max depends on which sidecar pattern is in use:

| Sidecar type | Who uses it | Cost visibility | Estimation |
|---|---|---|---|
| External CLI (Gemini, Codex, Copilot) | Multi-LLM environment | **Not visible in CC** | Low — external billing only |
| CC sub-agent (isolated context, steel-quench pattern) | CC-only environment | **Visible in CC** | Estimable: Sonnet × sub-agent scope |

For **CC-only users**, pro/max sidecars run as isolated sub-agents (Sonnet for execution), with the orchestrator running at Opus (`complexity_routing`). Both are CC-visible. Cost estimate: `(Opus orchestrator turns × ~3×) + (Sonnet sub-agent tokens)`. The sub-agent context isolation means sidecar work does not load the main context — the context-preservation property holds regardless of sidecar type.

Therefore:
- **Never auto-escalate a GREEN/YELLOW task to pro/max.** For external CLI users, sidecar costs are untracked and invisible in CC's budget display. For CC sub-agent users, the overhead is estimable but still real — orchestrator Opus × 3 applies. Note the appropriate caveat when disclosing cost.
- **Model escalation cost**: With `/model opusplan`, Opus activates on plan-mode turns and Sonnet handles execution turns — both CC-visible in session jsonl under `message.model`. External CLI sidecar fees are additional and invisible to CC; state both when present.
- **RED is no longer a dead-end.** v1 hard-blocked RED ("split manually"). v2 turns RED into the **on-ramp to max** — agent-composer decomposes the over-budget goal into sequential sub-goals automatically.

---

## Autonomy Ladder — how unattended a loop may run (orthogonal to the budget modes)

The core/pro/max modes above key on **budget**. This ladder keys on a different axis — **how much human approval gates each action** — for a *recurring or unattended* loop (the autonomous-loop / `/loop` case), not a one-shot /goal. **Climbing a rung here changes *oversight*, never budget — the two never move together.** (Distilled 2026-06-27 from the "Loop Engineering" sister-asset's "training-mode dry-run → graduated autonomy"; cross-audit `tracks/_audit/session_2026_06_27_loop-engineering-silbal.md`.)

Three rungs, climbed one at a time:

| Rung | What runs | Human role |
|---|---|---|
| **① dry-run** | run once manually; observe outputs; **no irreversible actions** | reads every output |
| **② step-approval** | each action is HITL-gated before it fires | approves per action |
| **③ unattended** | the loop runs on its own | reviews after the fact |

- **Graduation threshold (measured):** a loop climbs one rung only after **K consecutive clean rounds across a 2+ session/run window** — the *2+ window* reuses `operations.md`'s promotion-window discipline (`accepted ≥ 60%` / recurrence `N=3`). **`K=2` is a provisional default, not yet calibrated** — no loop-run data exists yet; revisit once it does (same honesty as this SKILL's `N=10` budget baseline). "Clean" = the round's Done-When passed **AND** a positive downstream verdict (pipeline-conductor / sidecar = CLEAN) **AND zero S/M-grade governor-catch and zero post-ship correction** — *not merely* the absence of a governor-catch, so a quieter or weaker governor cannot manufacture graduation. **The streak is recorded per round in a local autonomy ledger** (the hub keeps it at `tracks/_meta/autonomy_ledger.yaml`; a plugin-only user keeps their own — anywhere in their project, the path is theirs): date · task · done-when · verdict · governor-catch grades · `clean:` bool. Graduation reads that ledger. A *computation script* (`scripts/`) that auto-derives the current rung from the ledger is **deliberately deferred** until enough entries exist to compute over — building the meter before there is a stream to measure is the speculative-infra the evidence-threshold discipline forbids. *Check class: a **measured count** (ledger grep) over a **judged per-round grade** — and the grade must be bound to the round's own challenger / steel-quench S/M verdict (the upstream adversarial artifact), **never an author self-grade** (else "measured" laundering a judge-only path). Until ≥~5 entries make a computation script worth writing, the streak is judged-and-hand-recorded — provisional by construction.*
- **Irreversible carve-out (non-negotiable — the FH increment over the video):** any action whose effect **cannot be undone within the loop** — not only the two examples (Destructive-Op delete/rewrite · Pre-Publish go-public) but **any irreversible side-effecting write** (an MCP `ask`-tier send, a payment, an outbound publish) — **never reaches rung ③**. Membership is the **mechanical surface test** of CLAUDE.md's Surface-Class Degrade Invariant + `mcp_tool_gating` (grep the action surface; do **not** self-label), not a match against the two examples. Such actions stay at rung ② (HITL) **permanently**, regardless of clean-round count. The video graduates a loop to fully unattended; FH caps graduation at the irreversible boundary. *Check class: judged — pair: a target-tier blind sim per CLAUDE.md §Target-tier sim gate (run 2026-06-27, Sonnet, PASS — a remote-branch-delete loop correctly held at rung ② despite 4 clean rounds). **Prose-enforced, not hook-enforced** — accepted residual, named not silent.*
- **Demotion (fail toward oversight, with a liveness floor):** any governor-catch, failed Done-When, or correction **resets the clean-round counter and drops the loop one rung** — autonomy is earned per-window, surrendered on the first miss, never sticky. A failed **dry-run (①)** has no lower rung: it **blocks graduation and surfaces to the operator**, it does not demote. A loop that **flips promote/demote ≥ `N=3` times in a window** (reusing operations.md's recurrence-escalation) is a noisy boundary — **freeze at the lower rung and surface**, do not keep oscillating.

### Two paths to autonomous completion (by surface reversibility)

The clean-streak graduation above governs **unattended-no-review** operation (rung ③) — right for *narrow recurring loops* (digest / sync / poll) where nobody sees each result, so the demonstrated clean streak is the only safety. **Most substantive novel work — including FH self-development — rarely earns a clean streak by design.** It is not therefore undelegatable; it takes a second, *reviewed* path:

- **Path 1 — clean-streak → unattended (rung ③):** narrow recurring tasks reviewed by nobody. Safety = the demonstrated clean streak (above).
- **Path 2 — *deliver-then-review* (a reviewed mode at rung ②'s oversight, not a new rung):** autonomous *execution* with **mandatory review** — it is **not** unattended and **does not climb to ③** (only Path 1's clean streak reaches ③). **Intent-seeded, mechanically-reversible, reviewed** work — mapped-project acceleration / first-project creation (human intent via Q&A), and self-dev absorption of frontier-digest-style insights. Path 2 permits autonomous *execution to completion without per-step approval*, but operator review of the delivery is **mandatory before the work is consumed** — that review is what *substitutes for* pre-approval. All five conditions hold, or it is not Path 2:
  - **(a) Human-selected direction — auditable, not narrated.** A human *selects* the direction; record it in the ledger (`seed: human-selected` or `innovator-proposed-human-confirmed`). An agent/innovator-proposed direction is a **candidate, not a seed**, until a human confirmation token is recorded — the machine never chooses *what* to pursue (self-echo guard, `[[fh_self_evolution_vision]]`).
  - **(b) Mechanically-reversible surface — anchored to the carve-out partition, never a softer self-judged "reversible".** Admissible only if **all three**: **(i)** not a member of the line-81 **grep-gated** irreversible set (mechanical); **(ii)** **effect-confined** to git-tracked tree state — no file deletion, external/DB mutation, or out-of-tree write. *This conjunct is **judged, not grepped** — whether delivered code mutates external state at runtime is behavioral, not a static surface (`[[qa_static_dynamic_complementarity]]`); its pairing is the line-81 grep **plus** the operator's mandatory delivery review, and it **degrades safely** — unproven confinement → treat as irreversible → HITL.* **(iii)** **not yet consumed** (a *local, unpushed-to-shared* commit; the instant a delivery is pushed to a shared branch or read by a downstream cache / CI / registry it is *effectively published* and re-enters HITL, per CLAUDE.md §Pre-Publish (b)).
  - **(c) Reviewable delivery.** Deliver as **discrete revertable units** (per-commit, not one opaque squash) so **rollback granularity ≥ delivery granularity**. A batch too large to actually review makes "roll back after seeing it" theoretical and voids the substitute-for-approval logic — cap the batch at what the operator can review; interdependent commits (revert 1 orphans 3) forfeit per-unit rollback and must be delivered batch-atomic with a higher review bar.
  - **(d) Rollback feeds demotion.** A Path-2 delivery the operator rolls back **forces the next same-class run back to rung ② full step-approval (per-action *pre*-approval — stricter than Path 2's post-hoc review) until one clean delivery**, and counts toward the `N=3` noisy-boundary freeze — so the riskier, novel work-class is not handed the looser path. *Prose-enforced, not hook-enforced — accepted residual (the ledger records the rolled-back delivery; no hook yet gates the next run, same status as the carve-out's residual above).* (Rung ② names two oversight strengths: Path-2 = human reviews *after* each delivery; demoted = human approves *before* each action. The demotion tightens from the former to the latter.)
  - **(e) Every action in the run is gated by (b) — not just the final delivery** *(cross-family review caught this 2026-06-27; the Claude same-family reviewers + the Sonnet sim shared the blind spot)*. Producing a Path-2 delivery often requires *executing* code — running a test suite, installing a package, a migration script, an API call. **Each such action is itself subject to (b)**: a preparation step that deletes files, mutates a DB, installs an untrusted dependency, or hits the network has an **irreversible *runtime* effect that no `git` rollback undoes** (git reverts the tree, never the execution that produced it). So it stops for HITL exactly like a delivery action — and a purely *exploratory/speculative* run that would do any of these is not "free" either. "Reversible" is a property of **every action in the run**, never only of the committed tree at the end.

**Direction is always human (both paths).** The machine automates *execution* of a human-seeded direction, never the direction itself. **The irreversible carve-out holds regardless of path** — anything irreversible, effect-unconfined, or already-consumed (at *delivery or during the run*) stays pre-action HITL; Path 2 delegates only what (b) admits.

---

## Triggers

- `/goal-quench`
- "run /goal with a quality gate", "safe goal run", "goal with verification"
- "I want to use /goal but worried about tokens", "goal with budget control"
- "goal-quench", before any long /goal session
- `/goal-quench --pro`, `/goal-quench --max`, "orchestrate this goal", "decompose this goal", "optimize then run this goal"
- "this goal is too big for one run", "find a tool for this goal if FH lacks one" (→ max mode)
- "assemble capabilities for this project", "develop project X with everything FH has", "what can FH + tools do for this project", "use all of FH's and others' sharp parts on this" (→ max mode, **project-dev capability-assembly** entry — internal skill-bus scan first, then external gap-fill, then map+cluster; token-efficient, non-expert-friendly)
- Automatically proposed when user mentions `/goal` on tasks estimated > 15K tokens
- Mode is auto-recommended by the Phase-1 budget verdict (GREEN/YELLOW → core, ORANGE → pro, RED → max)

---

## One-Time Setup (required)

**Claude Code runtime**: merge the Stop-hook snippet from `templates/goal-quench-hook-setup.md` into `.claude/settings.json`, and gitignore the two state files. Recovery flags exist for hook failures: `/goal-quench --verify` (Phase 3 only, manual trigger) and `/goal-quench --recover` (interrupted /goal — promotes `.active` → `.pending`).

**Codex runtime**: do not replace Codex's native goal/session capability with goal-quench state files — use `fh-gate`/`fh-goal` as post-run governance wrappers instead.

> **Detail**: See `SKILL_detail.md §Setup` — CC hook snippet + gitignore lines, hook-failure/interrupted-run recovery commands, Codex runtime commands — read when performing one-time setup or recovery.

---

## Phase 1 — Pre-run Gate

### Step 1. Collect task description

Ask: *"What will you run with /goal? Describe the task and expected scope."* Collect: task description, target files or directories, expected output.

**Pre-flight rule (pro/max only)**: verify required chained skills (context-doctor, agent-composer) are installed before proposing pro/max. If any is missing, **fall back to core and warn**: "Pro/max mode requires `{skill}` — not installed. Running in core mode instead."

> **Detail**: See `SKILL_detail.md §Phase1-Blocks` — pre-flight check bash, token-budget-gate invocation contract, state file format, threshold injection block, hand-off output — read when executing Phase 1 Steps 1–5.

### Step 2. token-budget-gate estimate

Run token-budget-gate against the task description (invocation contract in §Phase1-Blocks). If the skill is not installed, use this fallback estimator and note `budget_source: fallback-heuristic` in `.active`:

```
< 5 files changed, no new architecture  → GREEN  (< 10K)
5–20 files or new module/feature        → YELLOW (10K–30K)
20+ files or cross-system refactor      → ORANGE (30K–60K)
Full-project migration or rewrite       → RED    (> 60K)
```

**Session overhead factor (empirical, N=10, 2026-06-01–06-03)**: the tiers estimate *task* tokens only. Actual full CC session tokens average 4.7× the task estimate (range 1.3×–10.5×) for harness-heavy projects. Multiply task estimate by 4× for FH-density projects to get the expected session total — this informs the mode recommendation, not the go/no-go thresholds.

Map the verdict to a go/no-go decision:

| token-budget-gate verdict | goal-quench action |
|---|---|
| GREEN (< 10K) | Proceed without comment |
| YELLOW (10K–30K) | Proceed — note estimated cost, suggest /goal scope if possible |
| ORANGE (30K–60K) | Propose **pro mode** as the cheaper path: "This is expensive. Run as a single /goal, or let pro mode optimize (context-doctor) + decompose (agent-composer) it?" Proceed in core only if the user declines orchestration. |
| RED (> 60K) | Propose **max mode** instead of a hard block: "Too big for one /goal run. Route through max mode — agent-composer decomposes into sequential sub-goals, plugin-recommender fills any capability gaps." Hard-block only if the user declines orchestration. |

On RED: **accept max mode** (recommended) → Phase 1.5 decomposition recovery path; **decline orchestration** → goal-quench halts, writes no `.active`, and will not gate or verify a session started without its active file.

### Step 3. Write state file

Create `.claude/goal-quench.active` (format in §Phase1-Blocks). `target_files` is the **verification artifact** — what pipeline-conductor will evaluate in Phase 3. Specify explicitly if known; otherwise write `"inferred from git diff"` and Phase 3 resolves via `git diff {start_commit}..HEAD` (captures interim commits).

> **Control flow (core vs pro/max)**: in **core** mode, proceed directly Step 3 → Step 4. In **pro/max** mode, run **Phase 1.5 (orchestration) here — after Step 3, before Step 4** — then return to Step 4. The `composed_plan` field in `.active` stays `n/a` until Phase 1.5 fills it.

### Step 4. Inject mid-run budget thresholds

Before the user runs /goal, output the threshold instruction block (50% progress note · 70% re-prioritize · 85% stop-and-ask · 95% stop-and-commit — full block in §Phase1-Blocks) so Claude carries it into the /goal session.

### Step 5. Hand off to /goal

Output the ready message (budget verdict + estimated tokens + "run `/goal {your condition}`" — template in §Phase1-Blocks).

---

## Phase 1.5 — Pro / Max Orchestration Layer

> Runs only in `--pro` or `--max` mode (auto-proposed on ORANGE/RED budget, or user-selected). **Skipped entirely in core mode** — core hands off straight to /goal after Step 5.

The ordering is deliberate: optimize the context first (cheapest win), then decompose, then — only if a capability gap remains — reach outside FH.

### Step A — context-doctor (token-reduction pre-pass) · pro + max

Invoke context-doctor on the target scope before /goal runs (generates/updates `.claudeignore`, flags over-read files, recommends `/clear` timing). **Re-estimate** the budget after the pre-pass. If the verdict drops (e.g., ORANGE → YELLOW), offer to step back down to core (see Simplification Guards — post-optimization step-down).

### Step B — agent-composer (goal decomposition) · pro + max

Hand the task description to agent-composer in compose-only mode → Wave plan with capability-fit scoring (agent-composer Step 0.2). For RED-origin runs this decomposition is the recovery path v1 lacked.

**Sub-goal execution (user-driven, not automatic)**: `/goal` is user-invoked — goal-quench cannot programmatically loop over sub-goals. Write the plan to `.claude/goal-quench.queue` (format in §Queue-Format) and instruct the user to invoke `/goal-quench` once per sub-goal. Each invocation pops the first `remaining` item, runs it as an independent core-mode run, then moves it to `completed`. When `remaining` is empty, delete the queue file. (Parallel sub-goal execution is deferred — sequential is the v2 contract.)

goal-quench does **not** re-implement agent-composer's gates — its destructive-action gate (Step 2.7) and per-wave fan-out cap apply as-is.

> **Detail**: See `SKILL_detail.md §Queue-Format` — queue file format, plan-ready output text, sidecar `.active` fields — read when writing the queue (Step B) or the sidecar fields (Step D).

### Step C — capability fill: internal-first, then external · max only

Triggered only when agent-composer Step 0.2 reports a capability **GAP** (`fit_score < 0.5` on a required-weight sub-task). Fill order is **internal before external** — honors no-reinvention (use FH's + sibling projects' sharp parts before installing anything), and cheaper **on an internal hit** (a local registry read ≪ an external marketplace search; on an internal *miss* the scan is added overhead before the same external path):

1. **Internal scan first.** Run the `LOCAL_SKILL_REGISTRY` scan / Cross-Project Skill Bus (the runtime-root-derived scan under `.claude/registry/`) to check whether an existing **FH meta-skill or a sibling-project skill** already fills the gap. **Trust-gated dispatch** (the fields the registry carries are *consumed*, not just surfaced): an **FH meta-skill** hit → propose directly (Agent + Context Card, no install, token-cheap); a **non-FH sibling** hit → if `trust≠trusted` OR `writes≠read-only` → **ask-tier HITL before dispatch** (never propose-directly — sibling code is an injection surface), else propose. **Degrade direction**: if `.claude/registry/` is missing/malformed, treat as an internal-miss and **fall through to external (step 2), warn** — never silently skip capability fill (that drops the GAP sub-task unnoticed; capability-fill is a reversible surface → advisory-degrade per the Surface-Class Degrade Invariant).
2. **External only if internal has nothing.** `plugin-recommender` searches FH + Codex + Claude Code marketplaces + external repos for a fitting skill/agent; `cross-ecosystem-synergy-detection` pre-validates fit + overlap **before anything is installed**.
3. User decides: use-internal / install-external / skip / general-purpose fallback (agent-composer's degraded-composition rule applies — `⚠️ degraded: [role]`).
4. **Approved external capability → map + cluster (deferred to session close).** An adopted external skill or a newly-relevant sibling project is registered via `auto_project_mapping` — but that write **edits CLAUDE.md's track-mapping table and creates `tracks/{project}/` (an FH-asset change that trips the 4-axis auto-gate and shifts the onboarding is-mapped signal — [[feedback_tracks_dir_is_mapped_signal]])**, so it is **deferred to session close**, not run mid-`/goal`-loop: it passes the 4-axis gate as its own change instead of interrupting the run. The **next** run then discovers the capability internally at step 1 — the loop compounds.

max mode never installs or maps anything silently — internal hit, external discovery, synergy-check, and mapping are all surfaced for approval first.

### Step D — scope-driven sidecar configuration · pro + max

Runs after Step C (or after Step B if no capability gap). Selects an adversarial sidecar based on the task's quality-risk profile — distinct from Step C's capability-gap sidecar. Step D's sidecar addresses **blind-spot risk**: the generator and reviewer sharing the same reasoning distribution.

> **Availability resolution**: "if available" below is decided by the canonical Tier 1→2→3 recipe in `knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Sidecar Engine Resolution Protocol` — discovery is automatic, invocation stays value-gated. Tier 3 (Claude sub-agent) guarantees this step never hard-fails even with zero external CLIs/keys.

**Scope → sidecar routing table**:

| Task scope signal | Sidecar | Invocation point |
|---|---|---|
| Code quality review / new SKILL.md / governance gate change | `steel-quench` cross-provider challenger (Gemini sidecar if available; Tier 3 Claude sub-agent fallback) | Post-/goal, before pipeline-conductor |
| Architecture design / cross-project dependency | `agent-composer` multi-model panel (if external CLIs available; otherwise single-Claude sub-agent) | Parallel to /goal as separate Agent |
| External publication / marketplace-gate / skill release | `sim-conductor` + `steel-quench` Wave 5 | Post-/goal quality gate |
| No signal match (default) | None — pipeline-conductor handles quality alone | — |

Write the resolved `sidecar:` + `sidecar_rationale:` fields to `.active` (format in §Queue-Format). Output one line: *"Sidecar: {config} — {rationale}"*. Do not ask for confirmation; the user may override via `/goal-quench --sidecar none`.

**Dispatch-failure triage (saturation disguise)**: a sidecar dispatch failing with a 1M-context / usage-credits error late in a long run may be reporting *session context saturation*, not a billing gate (measured 2026-06-12). Triage order: compact — flushing handoff state to disk first — → retry the dispatch once → only then take the headless `claude -p` fallback (credit-pool cost) or an inline at-floor pass.

### Hand-off

After orchestration, **update** (not re-create) `.claude/goal-quench.active` — add `mode:` and `composed_plan:` lines alongside existing budget fields. Re-creating the file loses the `start_commit` field. Then proceed to threshold injection (Phase 1 Step 4) and hand off to /goal. Phase 3 verification runs as in core — `pipeline-conductor --quick` for pro, `--full` for max.

---

## Phase 2 — Mid-run (during /goal execution)

goal-quench does not directly control /goal execution. The budget thresholds injected in Phase 1 are instructions Claude follows during the /goal session: track approximate consumption against the estimate, execute the corresponding action at each threshold (50/70/85/95%), self-enforced without waiting for goal-quench.

**Threshold enforcement caveat**: Claude cannot reliably read its own real-time token consumption — thresholds are instructional approximations, not mechanically enforced. For hard enforcement, see the Anthropic feature request (--budget flag).

**Queue mode (per-sub-goal threshold scope)**: each `/goal-quench` invocation from the queue is an independent core-mode run — thresholds are re-injected fresh against that sub-goal's own Phase 1 estimate, not inherited from the outer pro/max run.

**What goal-quench cannot do in v1** (requires native Anthropic support): hard token ceiling (--budget), auto-checkpoint commits (--checkpoint), mid-run Sonnet quality signal. These gaps are the basis for the feature request (`knowledge/shared/harness-core/goal_quench_anthropic_issue.md`).

---

## Phase 3 — Post-run Verification

### Claude Code path

When /goal stops, the Stop hook: detects `.active` → copies to `.pending` → removes `.active` → prints the verification-pending notice.

On the next Claude response, check `.claude/goal-quench.pending` **with a freshness guard** (bash in §Phase3-Bash):
- **Fresh (< 4 hours)**: **automatically run pipeline-conductor** before responding to any other request — `--quick` for core/pro, `--full` for max (the `mode:` field in `.pending` selects). Not optional — pending verification takes priority.
- **Stale (> 4 hours)**: warn — "A stale goal-quench.pending exists from {timestamp}. Run `/goal-quench --verify` to re-evaluate, or delete it to clear." Do not auto-trigger verification on stale state.

### Codex path

After the Codex goal completes, run `fh-gate` on changed files (commands in §Phase3-Bash). Treat `BLOCKED`/`ESCALATE` the same as the Claude path.

> **Detail**: See `SKILL_detail.md §Phase3-Bash` — freshness guard bash, verification-artifact resolution bash, Codex gate commands — read when executing Phase 3.

### Verification flow

Resolve the verification artifact from `.pending` — explicit `target_files`, or `git diff {start_commit}..HEAD` when inferred (bash in §Phase3-Bash; empty target = hard error). Run pipeline-conductor on the artifact and gate on the result:

| pipeline-conductor verdict | goal-quench action | Delete `.pending`? |
|---|---|---|
| `CLEAN (--quick)` | Output: "Quality gate passed (--quick). Safe for local iteration and internal commits. Run pipeline-conductor --full before external release or PR." Log tokens. | **Yes — immediately** |
| `PENDING` | Proceed with caution. Output pending items. Recommend: "Resolve before any external release." | **Yes — immediately** |
| `BLOCKED` | Block commit. Output blocking items. Ask: "Fix and re-run /goal, or accept partial completion?" | **Only after user acknowledges** |
| `ESCALATE` | Surface to user for decision. Do not auto-delete — preserve state until user explicitly decides. | **Only after user decision** |

**Deletion rule**: On BLOCKED or ESCALATE, `.pending` must survive until the user makes an explicit decision — deleting before that loses the recovery anchor.

**Deadlock prevention**: While `.pending` exists (BLOCKED/ESCALATE), the next-turn verification check runs ONCE per turn only. After the first verification output, suppress further auto-trigger until the user explicitly acts. If the user starts a new `/goal-quench` run while `.pending` exists, warn and do not silently overwrite with a new `.active`.

Record actual token usage in `tracks/_meta/goal_quench_{YYYY-MM-DD}.md` for calibration (regardless of verdict).

### Step 3-c — Sidecar verdict gate (pro + max, when sidecar ≠ none)

After pipeline-conductor completes, read `sidecar:` from `.pending`. If non-none, gate on the sidecar's verdict before advancing to Done When:

| Sidecar | Wait for | Failure action |
|---|---|---|
| `steel-quench-crossprovider` | Wave 2 convergence: PASS or CONDITIONAL_PASS | FAIL → reopen Phase 2, surface blocking findings to user |
| `agent-composer-panel` | Panel findings file written + incorporated into pipeline-conductor context | Not yet written → re-run pipeline-conductor with panel findings |
| `sim-conductor` + `steel-quench-w5` | Both: sim-conductor Area A PASS **and** steel-quench W5 convergence PASS | Either FAIL → block Done When; surface failing verdict |

This gate is **blocking** — Done When cannot be reached until the sidecar verdict is resolved. Record `sidecar_findings_count` in the calibration record before closing.

---

## Calibration Record

After each goal-quench run, append a calibration entry to `tracks/_meta/goal_quench_{YYYY-MM-DD}.md`. Baseline (N=10, 2026-06-01–06-03, Sonnet): mean actual/estimate ratio 4.7× — systematic underestimation from session overhead. Target: 10 prospective runs per mode before treating mode comparison as reliable.

> **Detail**: See `SKILL_detail.md §Calibration-Record` — full YAML entry format, actual_tokens collection script, calibration baseline notes — read when appending the post-run record.

---

## Simplification Guards

- Do not activate goal-quench for exploratory or single-turn tasks — only for /goal sessions.
- If the user runs /goal without going through goal-quench setup, propose retroactively: "Run /goal-quench --verify to quality-check the output."
- `--verify` mode: skip Phase 1+2, go directly to Phase 3 verification using current session scope.
- **core is the default and the floor** — never auto-escalate a GREEN/YELLOW task to pro/max. Sidecar CLI costs (external, untracked in CC) apply in pro/max — auto-escalation requires ORANGE/RED budget or explicit user flag.
- **pro/max are supersets of core, not replacements** — a user who wants only the v1 safety belt stays in core and sees no orchestration.
- **Post-optimization step-down**: if a pro/max run's re-estimated budget drops to GREEN/YELLOW after context-doctor trims (Phase 1.5 Step A), offer to drop back to core — don't run orchestration the trimmed scope no longer needs.
- Phase 1.5 does not re-implement the gates of the skills it chains (agent-composer's destructive/fan-out gates, plugin-recommender's install approval) — it defers to them.

---

## Chains

- `token-budget-gate` — Phase 1 cost estimation (all modes)
- `context-doctor` — Phase 1.5 Step A token-reduction pre-pass (pro + max)
- `agent-composer` — Phase 1.5 Step B goal decomposition into Waves (pro + max)
- `LOCAL_SKILL_REGISTRY` scan / Cross-Project Skill Bus — Phase 1.5 Step C internal-first scan (max only, GAP-triggered, before external)
- `plugin-recommender` — Phase 1.5 Step C external capability-gap fill (max only, GAP-triggered, only if no internal hit)
- `cross-ecosystem-synergy-detection` — Phase 1.5 Step C pre-validation of discovered candidates (max only)
- `auto_project_mapping` — Phase 1.5 Step C map/cluster of an adopted external capability (max only, approval-gated, deferred to session close)
- `pipeline-conductor` — Phase 3 quality gate (`--quick` for core/pro, `--full` for max; called by Stop hook)
- `field-harvest` — capture calibration data as reusable pattern after 10 runs

---

## Done When

```
☐ Phase 1: token-budget-gate verdict output + mode resolved
  (core default, or pro/max via budget verdict / explicit flag)   (mandatory-pass)
☐ .claude/goal-quench.active written (with mode: field) +
  thresholds injected — the file exists on disk and is read back  (mandatory-pass)
☐ If pro/max: Phase 1.5 ran — context-doctor pre-pass +
  agent-composer plan; max additionally: GAP-triggered internal
  LOCAL_SKILL_REGISTRY scan FIRST (trust-gated dispatch);
  plugin-recommender + cross-ecosystem-synergy pre-validation
  ONLY if no internal hit; auto_project_mapping map/cluster
  deferred to session close only if an external capability was
  adopted (each surfaced for approval)                            (mandatory-pass)
☐ Phase 3 (on next response after /goal): .pending detected +
  pipeline-conductor run (--quick core/pro, --full max)           (mandatory-pass)
☐ Verification verdict output (CLEAN/PENDING/BLOCKED/ESCALATE)    (mandatory-pass)
☐ If sidecar invoked (pro/max Step D): Step 3-c sidecar verdict
  resolved (PASS/CONDITIONAL_PASS) before closing                 (mandatory-pass)
☐ .pending deleted + calibration record appended                  (mandatory-pass)
☐ Calibration record carries actual_tokens as a NUMBER or the
  literal "unknown" — never 0, never blank, never omitted         (measured: field present and
                                                                   non-empty)
☐ Enumerated failed/skipped checks reconcile against the resolved
  mode's in-scope set: len(list) == in-scope − passed             (measured: exact equality —
                                                                   this is the anchor that keeps
                                                                   the verdict off a judge-only
                                                                   path)
☐ The run actually achieved the stated goal, not merely finished  (judged — adversarial pairing:
                                                                   pipeline-conductor's verdict is
                                                                   the independent check; the
                                                                   runner's own completion judge
                                                                   does NOT satisfy this, which is
                                                                   the entire reason this skill
                                                                   exists)
```

Verdict: PASS (CLEAN verification) | CONDITIONAL_PASS (PENDING verification) | FAIL (BLOCKED verification) | ESCALATE (user decision required on partial completion)

**Completion-claim discipline (Ralph — no silent partial completion):** a PASS/CONDITIONAL_PASS
verdict must **enumerate, not assert** — (a) **evidence artifact**: the pipeline-conductor verification
verdict + the calibration record path; (b) **failed/skipped checks by name** (which pipeline axes /
sidecars FAILED or were skipped). This list is **not self-asserted** — reconcile it against the resolved
mode's in-scope axis/sidecar set: a list shorter than (in-scope − passed) is incomplete, not PASS (an
empty list is valid only when every in-scope check passed). This is the mechanical anchor that keeps the
clause off a judge-only path; (c) **explicit residual risk beyond what the mode-qualifier already states**
(e.g. an axis that ran but on degraded input). A verdict that omits any of the three is **incomplete, not
PASS**. (Convergent sister evidence: oh-my-claudecode Ralph "refuses silent partial completion"; Hermes
Agent `/goal` per-turn completion judge.)
