# AGENTS.md — forge-harness Runtime Entry Point

> **Always-loaded layer.** Keep agent selection and rules that must govern every runtime here.
> Load execution examples, compatibility history, and conditional procedures only through the
> imperative pointers below.

## Relationship to CLAUDE.md

| File | Scope | Audience |
|---|---|---|
| `CLAUDE.md` | Session rules, protocols, orchestration flow | Claude Code |
| `AGENTS.md` | Portable runtime rules, agent roles, dispatch boundaries | AI runtimes + humans |

`CLAUDE.md` governs Claude-native automation. This file is the portable entry point for Codex and
other non-Claude runtimes, which do not auto-load `.claude/rules/*.md`.

## Agent Registry

forge-harness ships 8 tracked agents. The user-mastery spectrum (`beginner` · `main-player` ·
`expert`) plus `challenger` supplies multi-persona review; the remaining agents serve harness
operations or steel-quench.

| Agent | File | Role | Invoked by |
|---|---|---|---|
| `beginner` | `plugins/fh-meta/agents/beginner.md` | First-contact cold read; finds onboarding friction | `sim-conductor` Area A, `marketplace-gate`, `install-wizard`, direct |
| `main-player` | `plugins/fh-meta/agents/main-player.md` | Engaged-user view; scopes Light/Midcore/Heavy usage | `sim-conductor` Area A/D-code, direct |
| `expert` | `plugins/fh-meta/agents/expert.md` | Web-grounded domain accuracy and current practice | `sim-conductor` Area E/D, paper review, direct |
| `challenger` | `plugins/fh-meta/agents/challenger.md` | Evidence-cited adversarial evaluation | `steel-quench`, `harvest-loop`, `sim-conductor`, direct |
| `fact-checker` | `plugins/fh-meta/agents/fact-checker.md` | Pre-recommendation duplicate and stale-fact search | Before new asset creation or recommendation |
| `hub-persona-auditor` | `plugins/fh-meta/agents/hub-persona-auditor.md` | External-facing pre-publication persona audit | `hub-cc-pr-reviewer`, `sim-conductor`, direct |
| `quench-challenger` | `plugins/fh-commons/agents/quench-challenger.md` | Steel-quench attack plus concrete fix direction | `steel-quench` Wave 1, `install-doctor`, `marketplace-gate` |
| `persona-innovator` | `plugins/fh-meta/agents/persona-innovator.md` | Naming gaps, frame proposals, frontier signals | `sim-conductor` Area A, `harvest-loop`, direct |

Machine-readable mirror: `.claude/registry/agent_cards.json`.

### Tool restrictions

| Agent | Allowed tools |
|---|---|
| `challenger` | Read, Grep, Glob, WebSearch, WebFetch |
| `fact-checker` | Read, Grep, Glob |
| `hub-persona-auditor` | Read, Grep, Glob |
| `quench-challenger` | Read, Grep, Glob |
| `persona-innovator` | Read, Grep, Glob, WebSearch, WebFetch |

## Runtime Boundaries

- **Two layers:** `tracks/`, `knowledge/`, and skill methodology are model-agnostic. Plugin agents,
  hooks, slash commands, and `.claude/rules/` automation are Claude-native.
- **Output residency:** reusable methodology and polished public guidance belong in `knowledge/`,
  `plugins/`, or `docs/`. Raw signals, operator observations, handoffs, audit logs, and private
  reasoning are private-first; do not infer that colocated directories share a repository.
- **Runtime authority:** a non-Claude sidecar returns evidence candidates, never the terminal verdict.
  The governor must source-close each finding against a local file hit, literal source span, or
  passing check. Governor agreement alone is not an anchor.
- **Sidecar completion:** judge a sidecar only by the typed verdict from `scripts/sidecar_wait.sh`.
  Never infer completion or emptiness by looking at its output file.
- **Identity grades:** the five-identity grade table is canonical only in
  `knowledge/shared/harness-core/ship_readiness_gate.md`. Do not restate grades from memory or from
  a session card — cite that file's current state.

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Architecture-and-output-routing`
> — layer ownership and destination routing — read before routing work across a public/private workspace pair.

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Sidecar-routing-and-waiting`
> — capability routing, the required wait command, and typed verdict meanings — read before dispatching a sidecar.

## Mandatory Non-Claude Checklist

Because non-Claude runtimes do not auto-load Claude path rules, apply these rules explicitly:

1. **FH asset change:** before editing, read `.claude/rules/fh_4axis_gate.md`; before the first commit,
   run its required axes. Treat `templates/regression_guard.sh` exit 0 as PASS or SKIP; use its typed
   result channel and never report SKIP as checked.
2. **Company residency:** raw company source, secrets, hostnames, internal names, stack traces, and
   unredacted findings never leave the local machine, including to same-family cloud models. Only a
   sanitized summary may leave; exceptions require explicit operator approval and a gitignored note.
3. **Author exposure:** before calling a material work product done, identify the author's blind spot
   and run the matching `agent-composer` Author-Exposure lens. The lens supplies evidence, not a verdict;
   unclear exposure defaults to `challenger`.
4. **Intent marshaling:** general work is in scope. Enumerate installed skills, `LOCAL_SKILL_REGISTRY`,
   and mapped project assets before composing capability. Preserve each trust tier and each outward
   action gate. Declare a gap only with the scan cited, then route through internal registry search,
   external search, and in-session synthesis. Persist and install retain their existing gates.
5. **Measurement integrity:** before trusting a scan or count, run a known-positive and known-clean
   pair, then open one hit manually. An empty or failed scan is `UNMEASURED`, not zero; extreme results
   require instrument suspicion.
6. **Irreversible intent:** before publish, delete, or history rewrite, read and apply the
   Pre-Publish or Destructive-Op gate in `CLAUDE.md`. `pre-push` is only the git-side backstop.
7. **Self-contrast on asset touch:** the trigger for the three-layer self-contrast (process ·
   engines · identities) is *touching an FH/PMH asset*, not being asked. Pick verification axes by
   failure mode — running all four every time is not the rule. Record, in the existing Axes 2–3
   marker fields: the soul line written before design (or `none`), each axis run and not run — by
   name, and each axis's control with whether it survived. The minimum evidence that an axis ran is
   execution output with a live control; reporting an axis as run without one, or recording only a
   reason for not choosing it, is not compliance. The four axes are named in
   `knowledge/shared/harness-core/fh_three_layer_canon.md` §1-a — read it before recording; §1-c
   holds the sample limits — read it before citing. This record is self-attested and has no hook
   behind it; it is closed by a different-family reader, not by writing it more carefully.
8. **Branch-surface claims:** GitHub branch protection is two independent layers — legacy
   protection and rulesets coexist, and the strictest wins. Read both
   `/repos/{owner}/{repo}/branches/{branch}/protection` and
   `/repos/{owner}/{repo}/rules/branches/{branch}` before declaring any branch surface open or
   closed. In the reference repository (forge-harness), reading the protection object alone
   misjudged the force-push surface three times; the symmetric single-endpoint case is untested,
   but the same failure shape applies.

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Mandatory-checklist-procedures`
> — exact supporting procedures and canonical doctrine links — read when any checklist trigger fires.

## Invocation

Non-Claude runtimes apply methodology manually. Prefer `FH_BACKEND=codex ... fh-run` for skills and
agents. When a workflow references `Agent(subagent_type=...)` or a slash command, replace that step
with `fh-run` or a direct `codex exec` call that reads the relevant spec. Use Codex native goal/session
control; FH supplies the quality gate after goal completion.

| Tier | Definition | Skills |
|---|---|---|
| **M1 — Full** | No Claude-native dependency | `token-budget-gate`, `asset-placement-gate`, `phantom-quench`, `deep-clarify`, `convergence-loop` |
| **M2 — Partial** | Core works; native agent or slash-command steps need adaptation | `deliberation`, `steel-quench`, `harness-doctor`, `context-doctor`, `sim-conductor`, `harvest-loop` |
| **M3 — Claude-only** | Requires a Claude hook or session-scoped dispatch | `goal-quench`, `hub-cc-pr-reviewer`, `install-wizard` |

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Invocation-patterns`
> — single, parallel, and wave composition examples — read when choosing a dispatch shape.

### Before dispatching without being asked

FH treats isolated delegation as part of what a harness *is*, so it leans toward dispatching rather
than absorbing separable work inline. One boundary comes with that, and it is runtime-agnostic:

```
unprompted dispatch is available only when a standing request from the user is RECORDED —
  in a durable local file, carrying all three of:
    the user's own words, quoted   · a dated lease   · a scope line
no such record, or the lease has lapsed, or you cannot tell (fresh clone · a runtime whose
  own prompt may restrict this)
  → the request is absent, and absent is not granted → ask per invocation
```

Four notes for anyone porting this. A record is only a record if the *user* authored the quoted
words — an agent writing the file on its own initiative has produced nothing. Consent is **leased,
not owned**: past the lease date the record stops counting and you go back to asking. Every run that
proceeds *without* a prompt should say that it is doing so, so an unnoticed grant cannot accumulate
silently. And the request buys not-being-asked about the dispatch; it never relaxes a gate at what
the dispatched agent then touches (publish, delete, history rewrite).

The Claude-side rationale — including why the boundary is phrased around a *conditional* rather
than a prohibition — lives in `CLAUDE.md §Agent Dispatch Operation` and is specific to that runtime.
The constraint above is not.

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Codex-entry-points`
> — runnable `fh-run` and `codex exec` forms — read before invoking FH from Codex.

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Compatibility-tiers`
> — tier constraints and goal-handling limits — read before adapting an M2/M3 workflow.

## Conditional Procedures

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Beta-removal`
> — external-validation conditions and reporting route — read when evaluating or changing beta status.

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Adding-agents`
> — creation gate, registry synchronization, and post-use thresholds — read before adding an agent.

> **Removing resident text**: if you are considering deleting a section from `CLAUDE.md` (or any
> always-loaded asset) because it looks redundant, this repo settles that by measurement rather than
> by reading. The procedure — two arms, an isolated runtime, `reps>=3`, a question set fixed before
> the arms run — is documented in the header of `scripts/probe_scope_check.sh`; the runner must first
> pass `bash scripts/ablation_calibrate.sh` (exit 0), and verdicts are recorded in
> `.claude/regression/ablation_verdicts.md`. Worth knowing before you propose a cut: a section whose
> removal makes a reader answer *confidently wrong* counts as load-bearing, not as safe to drop.
