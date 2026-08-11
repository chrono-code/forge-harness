---
name: pipeline-conductor
description: Chains the four core FH verification pipelines (harvest-loop → steel-quench → phantom-quench → sim-conductor) into a single gated sweep. Accepts a scope (single skill, specific asset, full harness) and aggregates results into one structured report. Supports --quick mode (steps 2+3 only) and --full mode (all four steps). Triggered by "run the full pipeline", "chain all verifications", "end-to-end sweep", "pipeline-conductor", or "verify everything".
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Grep", "Glob", "Agent"]
model: sonnet
---

# pipeline-conductor — Chained Verification Sweep

Chains the four standalone FH verification pipelines into a gated sequence. Each step receives the previous step's verdict before proceeding. Aggregates all findings into a single structured report at the end.

The gap this closes: harvest-loop, steel-quench, phantom-quench, and sim-conductor are each invocable independently but have no automatic hand-off between them. Running them sequentially by hand loses inter-step signal — a FAIL in step 2 should block step 3 rather than silently continuing. pipeline-conductor enforces that ordering.

## Triggers

- `/pipeline-conductor`
- "Run the full verification pipeline", "chain all four verifications"
- "End-to-end sweep before I push", "verify everything at once"
- "I want to run all the checks in order", "do a full harness review"
- "Run quench then grounding then sim", "chain the pipelines"
- "Full pipeline on this skill", "sweep this asset before release"

> **Disambiguation**: "run the pipeline" alone may trigger harvest-loop (which uses identical phrasing). Prefer "run pipeline-conductor" or "chain all verifications" for unambiguous activation.

## Modes

| Flag | Steps run | When to use |
|---|---|---|
| `--full` (default) | Steps 1 → 2 → 3 → 4 | Complete verification sweep |
| `--quick` | Steps 2 → 3 only | Fast adversarial + phantom check; skip knowledge loop and simulation |
| `--no-sim` | Steps 1 → 2 → 3 | Skip sim-conductor (e.g., no sim environment available) |

**Mode qualifier on verdicts**: `CLEAN (--quick)` and `CLEAN (--no-sim)` do not qualify as pre-release gates. Only `CLEAN (--full)` is sufficient for external publish or PR approval.

## Verdict Format

Every step emits exactly one verdict line before handing control to the next step:

```
Verdict: PASS | CONDITIONAL_PASS | FAIL | ESCALATE
Basis:   [one-line summary of deciding factor]
```

| Verdict | Meaning | Chain behavior |
|---|---|---|
| `PASS` | Step complete, no blocking issues | Proceed to next step |
| `CONDITIONAL_PASS` | Issues found but none are blockers; must be resolved before final report | Capture items, proceed to next step; flag in final report |
| `FAIL` | Blocking issue found | Halt chain, surface to user immediately |
| `ESCALATE` | Ambiguous state requiring human judgment | Pause chain, present three options to user |

`CONDITIONAL_PASS` means proceed, not skip — captured items accumulate into the final report's Pending section and must be addressed before the sweep is considered clean. `FAIL` halts the chain (user decides fix-and-resume or abandon). `ESCALATE` pauses the chain pending the user's choice.

### ESCALATE Handling

When any step returns `ESCALATE`, present:

> "Step N returned ESCALATE: [basis]. Choose:
> (a) Make a decision — state your judgment and I will incorporate it and continue the chain.
> (b) Accept and continue — mark this as PENDING in the report and proceed to the next step.
> (c) Abort — close the sweep as BLOCKED."

- Option (a): User provides judgment → incorporate as resolution note → re-evaluate step gate with decision context → continue chain.
- Option (b): Mark ESCALATE item as PENDING → continue chain from step N+1.
- Option (c): Halt, output BLOCKED report with ESCALATE item in blocking section.

---

## Step 0. Scope, Mode, and Translation

Determine before running any pipeline step:

1. **Scope**: single skill (path to `SKILL.md`) · specific asset (file/directory) · full harness (`plugins/` + `templates/`)
2. **Mode**: `--quick`, `--no-sim`, or `--full` (default)
3. **Branch**: current git branch (used for regression guard and report header)

If scope is not specified, ask: *"What should I sweep? (e.g., a specific skill path, a directory, or the full harness)"* **Do not infer scope** — a wrong scope produces misleading verdicts.

Output the sweep plan and get Y/N confirmation before running.

> **Detail**: See `SKILL_detail.md §Output-Formats` — sweep plan block, per-step verdict blocks, aggregated report template — read when emitting any step output.

### Scope Translation Table

The four constituent skills use heterogeneous scope models. Translate the pipeline scope to each skill's invocation form before running any step:

| Pipeline scope | harvest-loop (Step 1) | steel-quench (Step 2) | phantom-quench (Step 3) | sim-conductor (Step 4) |
|---|---|---|---|---|
| Single SKILL.md | Check session findings relevant to this skill; propose mode only | Adversarial attack on this SKILL.md | Back-trace claims in this SKILL.md to declared sources | Area D (artifact review) on this SKILL.md |
| Specific directory | Check session findings in this domain | Attack all SKILL.md files in directory | Back-trace all claims in directory | Area A + Area D on the domain |
| Full harness | Check all recent session findings | Attack all harness assets under scope | Back-trace all claims across harness | Area A + Area B + Area D |

---

## Step 0.5. return-path-gate — Pre-flight Chain Audit

> Skip only when scope is a single non-pipeline skill. **return-path-gate not installed is a recorded
> degrade, never a free skip**: proceed, but record `degraded: return-path-gate (not installed)` in the
> final report — and, symmetric with the user-override row below, the sweep **cannot reach
> `CLEAN (--full)`**. A missing tool must not pass more cheaply than an explicit refusal (that
> asymmetry trains uninstalling the gate).

Run `/return-path-gate --skill [scope]`.

| return-path-gate result | Step 0.5 verdict | Chain behavior |
|---|---|---|
| 0 OPEN chains | `PASS` | Proceed |
| MEDIUM/LOW severity OPEN chains only | `CONDITIONAL_PASS` | Proceed; capture in Pending |
| 1+ HIGH severity OPEN chains | `FAIL` | **Halt sweep** — fix chains before running pipeline |

**Skip override rule**: `S` (skip on FAIL) is available but must be declared explicitly. Skipping records as `degraded: return-path-gate (user override)` in the final report and the sweep **cannot reach `CLEAN (--full)` status** regardless of subsequent step verdicts.

---

## Step 1. harvest-loop — Knowledge Loop Check

> Skipped in `--quick` mode.

Check for harvest-loop signals in the current session — read session context rather than invoking harvest-loop directly (a mid-sweep invocation would conflict with the sweep's own pattern collection).

**Typed-first parsing (codex M3 2026-08-10)**: if a harvest-loop output block exists, classify
ONLY from its final non-empty `Verdict:` line; absent/malformed → `ESCALATE`. The prose rows below
apply ONLY to pre-contract historical runs (no typed line anywhere in the output).

| harvest-loop result | pipeline-conductor verdict |
|---|---|
| Typed `Verdict: PASS` | `PASS` |
| Typed `Verdict: CONDITIONAL_PASS` | `CONDITIONAL_PASS` (carry the attached skip-list into the report) |
| Typed `Verdict: FAIL` | `FAIL` |
| Typed `Verdict: ESCALATE` | `ESCALATE` (own handling — never collapsed into FAIL) |
| (legacy, no typed line) all steps pass prose | `PASS` |
| (legacy, no typed line) patterns found but no blockers | `CONDITIONAL_PASS` — capture pattern list |
| (legacy, no typed line) drift/failure prose | `FAIL` |
| Did not run this session | `CONDITIONAL_PASS` — note: knowledge loop not validated |
| Auto-skipped (< 3 patterns) | `CONDITIONAL_PASS` — note: sub-threshold, not validated |

> **Detail**: See `SKILL_detail.md §Execution-Notes` — harvest-loop invocation path, per-step FAIL prompts, Area B cadence bash, what-each-step-checks reference — read when executing Steps 1–4.

---

## Step 2. steel-quench — Adversarial Verification

Run steel-quench against the target scope (for `--quick`, this is the first step).

**steel-quench severity vocabulary** (S/A/B grade — not M/S/R):
- **S-grade**: Immediate blocker — must fix before proceeding
- **A-grade**: Required before deployment — fix before external release
- **B-grade**: Improvement recommended — non-blocking

| steel-quench result | pipeline-conductor verdict |
|---|---|
| 0 S-grade findings | `PASS` |
| A-grade or B-grade findings only | `CONDITIONAL_PASS` — capture finding list |
| 1+ S-grade findings | `FAIL` |
| Wave 4 (Meta-Aware Adversary) surfaces structural ambiguity | `ESCALATE` |

---

## Step 3. phantom-quench — Phantom Claim Detection

Run phantom-quench scoped to the same target as Steps 1 and 2.

**Load-bearing Phantom** (binary test — apply mechanically). A Phantom is load-bearing if it appears in any of:
- `§Done When` section of the skill under audit
- Any numbered `§Step N` execution body
- `§Chains` with mandatory dispatch language (`→ Mandatory next`)

All other locations (§Triggers, advisory §Chains language, frontmatter description) are non-load-bearing by definition.

| phantom-quench result | pipeline-conductor verdict |
|---|---|
| 0 Phantoms, all claims grounded | `PASS` |
| Phantom claims found, none load-bearing (binary test) | `CONDITIONAL_PASS` — list Phantoms |
| 1+ load-bearing Phantoms | `FAIL` |
| Grounding ambiguous (source file exists but content unclear) | `ESCALATE` |

---

## Step 4. sim-conductor — Pre-Deploy Simulation

> Skipped in `--quick` and `--no-sim` modes.

Run sim-conductor against the target scope: Area A + Area B (if cadence allows) + Area D (if scope is a specific SKILL.md or document).

**Area B cadence rule (behavioral)**: Area B has a once-per-week frequency limit. If Area B ran within 7 days (detection bash in §Execution-Notes) → skip Area B, run Area A + D only, capture as `CONDITIONAL_PASS` with note "Area B skipped — within 7-day cadence limit."

| sim-conductor result | pipeline-conductor verdict |
|---|---|
| 0 M-tier findings across all personas | `PASS` |
| S/R-tier findings only | `CONDITIONAL_PASS` — capture finding list |
| 1+ M-tier findings from any persona | `FAIL` |
| Persona results conflict, resolution requires human judgment | `ESCALATE` |

---

## Step 5. Aggregated Report

After all steps complete (or after chain halt), output the aggregated report (template in §Output-Formats).

**Overall verdict logic**:

| Condition | Overall |
|---|---|
| All steps PASS, zero `degraded:` entries | `CLEAN ({mode})` |
| All steps PASS but 1+ `degraded:` entries (skip/not-installed/override) | `CLEAN ({mode}, degraded: [list])` — and the mode may not render `--full` (the Step 0.5 "cannot reach CLEAN (--full)" rule binds HERE, in the aggregate, not only in prose) |
| Any step CONDITIONAL_PASS or accepted ESCALATE; none FAIL | `PENDING` |
| Any step FAIL or unresolved ESCALATE (option c) | `BLOCKED` |

**Mode semantics**:
- `CLEAN (--full)`: Safe to proceed with commit, PR, or external release.
- `CLEAN (--quick)` / `CLEAN (--no-sim)`: Safe for internal iteration only — not sufficient for external publish or PR approval gate.
- `PENDING`: Resolve captured items before external release.
- `BLOCKED`: Do not proceed. Fix blocking items and re-run affected step(s).

**Report persistence**: save to `tracks/_meta/pipeline_conductor_{YYYY-MM-DD}_{scope-slug}.md`. If `tracks/_meta/` does not exist, output a B-grade warning and skip persistence.

---

## Resume After Fix

**After FAIL**:

1. User fixes the issue.
2. User says "resume from step N" or "re-run step N".
3. pipeline-conductor re-runs only the failed step and its gate.
4. On PASS, continues the chain from step N+1.
5. Does not re-run steps that already passed (unless user explicitly requests a full restart).

Resume is scope-bound — the scope from Step 0 is preserved across resume calls.

**After ESCALATE**: present the three options (see ESCALATE Handling above); (a) incorporate decision and continue, (b) mark PENDING and continue from N+1, (c) abort with BLOCKED report.

---

## Simplification Guards

- Do not propose pipeline-conductor for single-file read tasks or exploratory sessions.
- If the user invokes one of the four constituent skills directly, do not auto-redirect to pipeline-conductor.
- If only one step is needed, guide the user to call that skill directly.
- For `--quick` mode on a trivial scope (single short SKILL.md), Steps 2+3 should complete in one pass without sub-Wave fan-out.

---

## Chains

After a `CLEAN (--full)` or `PENDING` sweep, the following are natural follow-ons:

- `field-harvest` — harvest patterns surfaced during the sweep
- `hub-cc-pr-reviewer` — if sweep was run pre-PR, feed results into PR review
- `agent-composer` — if multiple fix tasks are needed across the Pending list, compose agents to resolve them in parallel
- `return-path-gate --all` — if Step 0.5 surfaced OPEN chains, run a full chain closure audit

## Complexity Routing

```yaml
complexity_routing:
  base: sonnet
  escalate_when:
    - high_stakes      # pre-external-publish or pre-deploy sweep
    - full_revalidation # user requested "start over"
    - cross_project    # scope spans 3+ projects
  high: opus
```

---

## Done When

```
Step 0 scope confirmed and scope translation table applied
+ Step 0.5 return-path-gate pre-flight: PASS / CONDITIONAL_PASS / FAIL (halts sweep) / explicitly skipped / degraded (user override | not installed)
+ All in-scope steps executed and verdicts emitted
+ Aggregated report output (Step 5 format)
+ Report saved to tracks/_meta/ (or skip warning issued)
+ Overall verdict qualified with mode: CLEAN (--full) / CLEAN (--quick) / CLEAN (--no-sim) / PENDING / BLOCKED
+ If BLOCKED: blocking items listed and user notified
+ If PENDING: pending items listed in report
+ If ESCALATE occurred: user presented three options; choice recorded in report
```

**Check classes**: every fence row above is *mandatory-pass*, except the completion-claim discipline
below, which is *measured* — its reconciliation (failed+skipped list length vs. in-scope − passed) is
the mechanical anchor. No Done When row here is judged: verdict aggregation is per-step-typed, not
discretionary.

Verdict: PASS (all conditions met, sweep complete) | CONDITIONAL_PASS (sweep complete, pending items captured) | FAIL (chain halted, blocking items remain) | ESCALATE (chain paused, human decision required)

A sweep is not done until the Step 5 report is output. Emitting per-step verdicts without the aggregated report is incomplete.

**Completion-claim discipline (Ralph — no silent partial completion):** the Step 5 report's overall
verdict must **enumerate, not assert** — (a) **evidence artifact**: the per-step verdict source (report
path + the verdict lines it aggregates); (b) **failed + skipped checks listed by name** (degraded /
skipped / `--quick`-omitted steps included). This list is **not self-asserted** — reconcile it against
the Step 0 in-scope step set: a list shorter than (in-scope − passed) is incomplete (an empty list is
valid only when every in-scope step passed). This is the mechanical anchor that keeps the clause off a
judge-only path; (c) **explicit residual risk beyond what the mode-qualifier states** (e.g. a single-skill
scope is not a full-harness claim). A CLEAN verdict that omits any of the three is **incomplete**.
(Convergent sister evidence: oh-my-claudecode Ralph "refuses silent partial completion"; Hermes Agent
`/goal` per-turn completion judge.)
