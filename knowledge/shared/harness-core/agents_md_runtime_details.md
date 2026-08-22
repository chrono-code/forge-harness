# AGENTS.md Runtime Details

> **Load: on demand.** `AGENTS.md` is the always-loaded runtime entry point. Read only the section
> named by its imperative pointer.

## §Architecture-and-output-routing

forge-harness has two distinct layers:

| Layer | Contents | Compatibility |
|---|---|---|
| **Methodology** | `tracks/`, `knowledge/`, `SKILL.md` documents, session protocols | Model-agnostic |
| **Automation** | Plugin agents, hooks, slash commands, `CLAUDE.md` rules | Claude Code-native |

FH agents ship under `plugins/*/agents/` through the plugin channel. `.claude/agents/` is the
field-project local/override slot, not FH's shipping location. Skills straddle both layers: their
methodology is portable, while their automatic invocation is Claude-native.

The methodology layer is Codex-compatible, marked **beta** in the *validation-maturity* sense
(external validation is still thin — see §Beta-removal), not in the *scope* sense: partial
automation-layer support is the design, not an unfinished state. Gemini, Codex, and other runtimes
can apply it by replacing hooks and native dispatch with manual invocation.

Directory names do not determine publication residency:

| Content | Default destination |
|---|---|
| Reusable methodology, docs, skills, public guidance, polished external conclusions | Public mirror: `knowledge/`, `plugins/`, `docs/` |
| Raw signals, operator observations, private validation, handoffs, paper drafts, PR-background reasoning | Private companion store or local-only |

In a workspace pairing a public mirror with a private companion store, preserve repository ownership
even when both are locally available. Treat observational or operator-specific material as
private-first and promote only the polished result.

## §Sidecar-routing-and-waiting

A sidecar is a capability-routing layer, not a second harness or co-governor. Gemini/Antigravity is
suited to breadth and multimodal work. Codex's primary FH role is repo-grounded audit: file reads,
source-close grep, diff/patch review, gate execution, and phantom/backtrace. A Codex session with
Browser or Chrome connectors may also take live web-flow automation.

Sidecars are Bash/adapter invocations coordinated inline; they bypass plugin agent dispatch and this
registry. Route Codex to repo-grounded audit by default, not breadth, discovery, or design-depth work.

After dispatch, wait mechanically:

```bash
printf '%s' "$prompt" | bash scripts/sidecar_wait.sh out.txt 900 -- codex exec -m gpt-5.5 -
```

Interpret only the typed verdict:

| Verdict | Meaning |
|---|---|
| `SIDECAR_VERDICT=COMPLETE exit=0 bytes=N` | The process completed; read the output file |
| `SIDECAR_VERDICT=TIMEOUT waited=Ns bytes=N` | The process is still alive; this is not a result |
| `SIDECAR_VERDICT=EMPTY exit=0` | The completed process returned no content |

A live process and a completed empty process can both show a zero-byte file. Never judge state by
file inspection. Canonical authority and waiting doctrine:
`knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Runtime Authority` and
`plugins/fh-meta/skills/auto-decorrelation/SKILL.md §S-1b`.

## §Mandatory-checklist-procedures

### FH asset changes

Read `.claude/rules/fh_4axis_gate.md` before changing an FH asset. It defines the mandatory
Backward, Adversarial, Forward, and Record axes, marker fields, lightweight exception, and
substantive carve-out. The pre-commit hook blocks commits that lack required evidence.

When running `templates/regression_guard.sh`, prefer `REGRESSION_GUARD_RESULT_FILE=<path>` and read
`result=pass|review|block|skip|error`. Without that environment variable, read the typed
`REGRESSION_GUARD_RESULT=` stdout line. Exit 0 alone cannot distinguish PASS from SKIP.

### Company residency

Keep raw company source, secrets, hostnames, internal names, stack traces, and unredacted findings
local. Outbound requests may contain only a sanitized summary. An exception requires explicit
operator approval plus a gitignored audit note. Canonical procedure:
`CLAUDE.md §Field-Harness Diagnostic`.

### Author exposure

Before completing a material deliverable, use `agent-composer §Author-Exposure Table`:

| Blind spot | Lens |
|---|---|
| Cold entry | `beginner` |
| Everyday friction | `main-player` |
| Outside currency | `expert` |
| Optimistic self-verification | `challenger` plus cross-family evidence |
| Rebuilding an existing asset | `fact-checker` |
| Ungrounded numbers or references | `phantom-quench` |
| Unclear | `challenger` |

Run an agent lens through `fh-run` or a direct `codex exec` reading the agent spec. The result remains
evidence for the governor to source-close.

### Intent marshaling

For ordinary work requests, read
`knowledge/shared/harness-core/intent_marshaling_general_work.md` before applying its ladder or when a
capability gap appears. The required loop is: restate deliverable and doneness; enumerate installed
and mapped capability with trust tiers; compose and run reversible FH-native work; cite the scan
before declaring a gap; search the internal registry, then external capability, then synthesize
in-session; apply the Author-Exposure check to material output.

Marshaling never upgrades trust. Non-FH sibling `ask-tier` capability remains propose-only.
Send, post, deploy, delete, and payment retain their own gates. Installing external capability routes
to `plugin-recommender` HITL; persisting a synthesized skill routes to the New-Skill gate.

### Measurement integrity

Read `knowledge/shared/harness-core/measurement-integrity-checklist.md` before relying on a scan,
checker, or metric. Demonstrate that the instrument separates one known-positive target from one
known-clean target, and inspect at least one hit before stating a count. Report no-target and
mid-run failure as `UNMEASURED`. Treat all-pass or all-fail output as an instrument warning.

### Irreversible surfaces

The Pre-Publish and Destructive-Op gates in `CLAUDE.md` fire on intent rather than file paths.
Read the relevant gate before any publish, delete, or history rewrite. The pre-push hook provides
only the git-side mechanical backstop.

## §Invocation-patterns

### Single agent

Ask for the required lens directly, for example: "Analyze this SKILL.md for structural flaws before
I commit it." Claude may description-dispatch `quench-challenger`; a non-Claude runtime invokes the
agent through the adapter.

### Parallel independent work

Dispatch two or more agents concurrently only when their tasks are independent, such as a
`fact-checker` duplicate scan and a `persona-innovator` naming-gap scan. The orchestrator integrates
their evidence after both finish.

### Wave composition

For complex dependent work, use `agent-composer`: Wave 0 reconnaissance, Wave 1 execution, then
Wave 2 synthesis.

## §Codex-entry-points

Read a skill workflow directly:

```bash
cat plugins/fh-meta/skills/steel-quench/SKILL.md
```

Prefer the runtime adapter:

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run \
  --skill steel-quench \
  --file path/to/artifact.md

FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run \
  --agent fh-commons:quench-challenger \
  --file path/to/artifact.md
```

Direct headless fallback:

```bash
cat plugins/fh-meta/skills/steel-quench/SKILL.md path/to/artifact.md \
  | codex exec -m gpt-5.5 -
```

`codex exec -m gpt-5.5 -` reads stdin headlessly. Interactive `npx @openai/codex` requires a TTY and
is not the headless substitute.

## §Compatibility-tiers

| Tier | Definition | Examples |
|---|---|---|
| **M1 — Full** | No Claude-native dependency | `token-budget-gate`, `asset-placement-gate`, `phantom-quench`, `deep-clarify`, `convergence-loop` |
| **M2 — Partial** | Core works; native agent/slash-command steps need adaptation | `deliberation`, `steel-quench`, `harness-doctor`, `context-doctor`, `sim-conductor`, `harvest-loop` |
| **M3 — Claude-only** | Requires a Claude hook or session-scoped dispatch | `goal-quench`, `hub-cc-pr-reviewer`, `install-wizard` |

**Which phase needs adapting** — the operative half of the M2/M3 rows. Without this a tier label
tells a non-Claude runtime that a skill is "partial" but not *where* to intervene, which is the only
thing it can act on. (Restored 2026-07-30 during review of the salience split: the rows survived the
move, these per-skill cues did not, and they existed in no other file.)

| Skill | Runs unchanged | Needs substitution |
|---|---|---|
| `steel-quench` | Waves 1–3 | the `quench-challenger` agent step |
| `harvest-loop` | the git-scan phase | PR auto-proposal |
| `deliberation` | proposal/synthesis structure | Mediator and Jury agent steps |
| `goal-quench` (M3) | — | Phase 3 depends on a Claude Stop hook |
| `hub-cc-pr-reviewer` (M3) | — | needs Claude session context |
| `install-wizard` (M3) | — | writes `settings.json` |

For M2, replace `Agent(subagent_type=...)` and slash-command steps with `fh-run` or direct
`codex exec` reading the relevant spec.

Use Codex native goal/session control when available. FH's portable role is the post-goal quality
gate (`fh-gate`). `fh-goal` is for non-interactive one-shot runs followed automatically by
`fh-gate`; it does not replace native goal control.

## §Beta-removal

🟥 **"Beta" here means ⓑ validation maturity (external evidence is thin), never ⓐ scope.** Partial
automation-layer support under Codex is the design, not an unfinished state, so it is not something
these conditions complete. Canonical statement of the split: `docs/codex-compat.md §Beta removal`.
Every condition below is a ⓑ condition.

| Condition | Status |
|---|---|
| Known-limitations document published at `docs/codex-compat.md` | Done |
| At least 5 externally validated M1 skill runs from non-authors | Pending |
| At least 1 external Codex user confirms methodology reproduction | Pending |
| ~~README badge removes `beta`~~ | **RETRACTED 2026-08-23 — no longer a condition.** The `Codex-beta · help validate` badge was removed from all four READMEs that day (operator decision); the condition named an artifact that no longer exists. Beta status now lives in the `Status:` header of `docs/codex-compat.md`, which the READMEs link to. Struck through, not deleted — a dropped condition and a met one must not look alike. |

Internal author validation does not satisfy the external conditions. The author validated
`phantom-quench` against a phantom-seeded fixture and `asset-placement-gate` against a duplicate-skill
proposal on 2026-06-04. See `docs/codex-compat.md` for limitations and validation details.

Report external validation through an issue on `chrono-meta/forge-harness` with the
`codex-validation` label.

## §Adding-agents

Before adding an agent:

1. Run `asset-placement-gate` and confirm the role does not duplicate an existing asset.
2. Use a plain description with no self-marketing language.
3. Define at least one explicit `Done When` condition.
4. Provide at least three natural-language trigger examples.
5. Make the agent independently executable or document its dependencies.
6. Add the canonical spec under the correct `plugins/*/agents/` directory.
7. Synchronize `AGENTS.md` and `.claude/registry/agent_cards.json`.

Before commit, apply `.claude/rules/fh_4axis_gate.md §FH Improvement 4-Axis Auto-Gate` and read
`knowledge/shared/rules/operations.md §Sub-agent Operations`. After at least two weeks of use,
strengthen an agent when accepted invocations are at least 60%; redefine or deprecate it when
rejected invocations are at least 40%.
