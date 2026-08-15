<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/banner.png" alt="forge-harness — Forge your projects, pass them through, faster. Quality is the lever — speed is the result." width="680">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e.svg" alt="MIT License"></a>
  <a href="https://zenodo.org/records/20397566"><img src="https://img.shields.io/badge/DOI-10.5281%2Fzenodo.20397566-blue.svg" alt="DOI"></a>
  <img src="https://img.shields.io/badge/Claude_Code-compatible-a855f7.svg" alt="Claude Code">
  <a href="https://github.com/chrono-meta/forge-harness/issues/72"><img src="https://img.shields.io/badge/Codex-beta_·_help_validate-f59e0b.svg" alt="Codex-compatible beta — help validate (issue #72)"></a>
  <a href="https://www.npmjs.com/package/@chrono-meta/fh-gate"><img src="https://img.shields.io/npm/v/@chrono-meta/fh-gate.svg?color=cb3837" alt="npm"></a>
  <a href="https://github.com/chrono-meta/homebrew-forge-harness"><img src="https://img.shields.io/badge/homebrew-tap-FBB040.svg" alt="Homebrew tap"></a>
  <a href="https://github.com/chrono-meta/forge-harness/stargazers"><img src="https://img.shields.io/github/stars/chrono-meta/forge-harness?style=social" alt="GitHub stars"></a>
</p>

<p align="center">
  <b>English</b> · <a href="README.ko.md">한국어</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a>
</p>

<p align="center">
  <sub>If this is useful, a ⭐ helps others find it.</sub>
</p>

<p align="center">
  <b>Forge your Claude Code projects — pass them through, they come out faster.</b><br>
  A practitioner's <b>meta-harness</b> — the galaxy your project harnesses live in.<br>It raises each project's <b>floor</b> (harness-ify the setup) and <b>ceiling</b> (accelerate the work), then compounds the gains across your whole portfolio.
</p>

<p align="center">
  <b>Quality is the lever; speed is the result.</b> Every change earns its way through the gates —<br>adversarial · phantom · regression — and <i>that</i> is what makes the next change faster.
</p>

<p align="center">
  <i>Fork it. Rename it. Make it yours.</i>
</p>

<p align="center">
  <img src="docs/pillars.svg" alt="FORK · ADAPT · COLLABORATE · EMPOWER" width="680">
</p>

<p align="center">
  <a href="docs/ETHOS.md"><b>The principles</b></a> ·
  <a href="docs/WHY.md"><b>Why it exists</b></a> ·
  <a href="docs/OUTPUT_EVIDENCE.md"><b>The evidence</b></a> ·
  <a href="CHEATSHEET.md"><b>How to use it</b></a>
</p>

---

| If you're here because… | forge-harness solves it |
|---|---|
| Context disappears when a session ends | Persistent `tracks/` — resumable from anywhere |
| You repeat the same setup across projects | Connect once to the hub, share across all projects |
| Team AI know-how lives only in people's heads | Codify it so everyone shares it |
| You want AI to get *better* as work accumulates | Skills and patterns compound session over session |
| You need a governance layer for AI-generated code | `fh-gate` wraps any coding agent as a post-generation gate |

> **This document is for humans.** AI operating rules → `CLAUDE.md` · Command reference → `CHEATSHEET.md`

---

## Get started in 2 minutes

**Prerequisite**: Claude Code CLI — verify with `claude --version`

<details><summary><b>Optional: one gate needs Python + PyYAML</b> — <code>npm test</code> is red without it</summary>

The consent-registry gate parses YAML, and it **fails closed** when it cannot — correctly, since an
unvalidated consent record must not read as a clean one. But that fail-closed turns the whole of
`npm test` (and `prepublishOnly`) red on a machine without PyYAML, and until 2026-08-12 the
requirement was written down **nowhere**:

```bash
python3 -m pip install --user pyyaml     # verify:  python3 -c 'import yaml; print(yaml.__version__)'
```

Why this is called out rather than left implicit: a release once shipped green from a session whose
`python3` happened to resolve to an **unrelated project's virtualenv** that had PyYAML, while the
machine's own `python3` did not. The gate was never bypassed — it passed, and the pass simply was not
portable. Every verdict from that gate now prints the interpreter and PyYAML version it used, so a
green states what produced it instead of leaving the reader to assume.

</details>

```bash
# 1. Install the plugin
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness

# 2. Clone the hub
git clone https://github.com/chrono-meta/forge-harness.git ~/projects/forge-harness
cd ~/projects/forge-harness

# 3. Start a session
claude
```

> ✅ Then **type a greeting ("hi")** — the 🐿️ door menu appears on a typed greeting, not on launch alone.
> Say **"Connect a project"** → hub scans `../`, finds `.git` directories, creates `tracks/{project}/`.
> For full initial setup (hooks · gates · baseline — each item individually approved, declining is
> respected and recorded), ask for **`/install-wizard`**.
> Already cloned somewhere else? That path *is* your hub — read every `~/projects/forge-harness`
> in the docs as your actual clone path.

**Your first 15 minutes** — what success looks like, and what to do with it:

1. You'll know setup worked when a greeting ("hi") shows the 🐿️ door menu, and "Connect a project"
   creates `tracks/{your-project}/`.
2. Then grab an immediate win in the same session: say **"accelerate this project"** (ranked plan of
   skills/plugins worth wiring, install-gated) or **"run /context-doctor"** (token-waste scan).
3. One honest note: FH's core payoff is **compounding** — session records, harvested learnings,
   cross-session memory. It shows from **session 2 onward**. Day one gives you the menu, the
   acceleration plan, and governance gates; don't judge the compounding on day one.

Unfamiliar words on the way? → [`knowledge/shared/GLOSSARY.md`](knowledge/shared/GLOSSARY.md).

**Plugin only (no clone):**
```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git  # once
claude plugin install -s user fh-meta@forge-harness
cd ~/projects/{your-project} && claude
```

> ⚠️ **Plugin-only is partial synergy.** You get the skills and agents, but **not** the hub-side
> orchestration — the `CLAUDE.md` governance (active onboarding, the 4-axis gate, mode branching;
> automation layer) and the compounding context (`tracks/` memory accumulation, `harvest-loop`
> learning; methodology layer).
> Each skill runs the same in isolation; what's missing is the orchestration that makes them compound
> across sessions. Clone the hub (above) when you want the full set, not just the tools.

**Which entry path is for you?**

| You are… | Start with |
|---|---|
| Solo dev, one project, just trying it | [`templates/starter_profile.md`](templates/starter_profile.md) — one command, curated first-five skills |
| Multiple projects, want the compounding hub | Clone the hub (quickstart above) |
| CI / non-Claude runtime, gates only | `npx @chrono-meta/fh-gate` (zero-install governance gate) |
| Prefer `brew` over `npx`/`npm` | `brew tap chrono-meta/forge-harness && brew install forge-harness` — same 100%-parity content, different install UX (community tap; not yet in Homebrew Core, so `brew search` won't find it without the tap first) |

---

## What it is

forge-harness is structured as **two distinct layers**:

| Layer | Contents | AI compatibility |
|---|---|---|
| **Methodology layer** | `tracks/`, `knowledge/`, `SKILL.md` docs, session protocols | Any AI model |
| **Automation layer** | `plugins/*/agents/` (FH agents), `.claude/agents/` (field-project overrides), hooks, slash commands, `CLAUDE.md` rules | Claude Code only |

The methodology layer is the portable core — persistent hub, accumulating learnings, curating cross-project knowledge. The automation layer makes it frictionless when running Claude Code.

**Where this sits (2026):** "harness engineering" is now a public paradigm — and basic agent
orchestration is rapidly commoditizing into standard infrastructure. FH deliberately stakes nothing on
that plumbing. Its durable layer is what does *not* commoditize: the governance gates (adversarial ·
phantom · regression), drift control, and the cross-project compounding loop. Routing and dispatch are
means; **the gate and the loop are the asset.**

```
forge-harness/   ← the hub (persistent brain)
├── knowledge/   → shared across all projects
└── tracks/      → work records per project

Project A  ──→  connect hub in CLAUDE.md
Project B  ──→  connect hub in CLAUDE.md
```

---

## What makes it a harness, not a toolbox

Start with what a harness *is for*: it reads your **intent** and forges it into a **machined form** — rules
an AI reliably follows, or deterministic code that needs no model at all. You give intent and insight; the
harness shapes them into something executable; you approve; it becomes machinery. The payoff is
**less trial-and-error on the human side**: the request → feedback → regenerate loop doesn't disappear, it
*relocates* — into the harness, run in parallel by agents and sidecars — so your time drops and your
attention is spent only where a change is irreversible.

Scale is the second point. A **skill, agent, or plugin** is a tool. A **harness** is a level up — a *star*:
one project's tools, rules, gates, and memory bound into a single working body. **forge-harness is the
galaxy those stars live in**: it binds many harnesses onto a shared floor to prevent drift, and lets
them evolve together instead of scattering.

This galaxy is more than a container. FH can run a field harness **in simulation inside its own
sandbox** — expensive per run, cheaper in total, because the trial-and-error pools in one place and
compounds — and when the simulation holds, it **emits** the project as an independent, specialized
harness. That is the goal it is built toward. In practice it works in four ways:

**① Assemble** — FH runs a *cluster* of harnesses at optimized token cost and hands you the right one for
the project. You don't wire up skills one by one; you get a **harness** — its plugins, skills, and agents
included — assembled to fit.

**② Forge** *(the quality gate)* — every change earns its way through adversarial · phantom · regression
gates. This is not "check more." It is a **responsibility router**: as automation rises, human sign-offs
get fewer but heavier, so the gate spends your attention only where a change is *irreversible*. Quality is
the lever; the speed is the result.

**③ Sidecar** — capability itself stays on the frontier. FH dispatches across multiple LLMs (Claude,
Codex, Gemini, local) so raw power is never tied to one model or one generation. The point is *not*
patching each model's weak spots — that scaffolding dies as models improve. It is **riding the frontier's
evolution**: shed what the substrate now does natively, absorb what it ships next. Decorrelation is
today's trust lever (a cross-family panel beats a single model's ceiling); co-evolution is the structure.

**④ Self-evolving loop** — the harness gets better without being rebuilt, in two directions: **outward**,
where each session's lessons compound into the hub so the next project starts faster, and **inward**,
where it catches and repairs *its own* defects (the 4-axis gate, bidirectional verify, per-user
adaptation).

The whole thing is a division of labor: **raw capability is the model's; assembly, trust, and evolution
are the harness's.**

> **Self-healing here isn't a claim — it's in the commit log.** This very README's voice rules were fixed
> mid-session by FH catching its own drift: a tone miss → diagnosis → a cross-family challenger that
> attacked *its own first fix* → re-fix → floor-tier re-verification → memory update. A harness repairing
> its own defect, on the record — not a slogan.

---

## Why it works

After a long co-authoring session with your AI, you and it share the same context — and the same blind spots. The reviewer worth having is the one who never saw your reasoning. You can get that by hand: paste the work into a fresh, empty chat. FH just turns that chore into one routine command.

- **sidecar / agent dispatch** → a reviewer with none of your session's context
- **steel-quench · phantom-quench** → that cold pass, on demand

It's model-agnostic: co-build with one AI, run the cold pass with any other. Whoever was absent from the original session is your cold reviewer — this is not a ranking of models.

**What FH does not claim:** the cold pass is your base model's own ability, not a detection engine FH adds — a plain prompt to a fresh instance does much of the same. FH's value is narrower and honest: it takes a method drawn from real practice and makes running that independent pass routine, instead of a chore you skip. The methodology is copyable; what FH packages is the workflow, not a secret sauce.

---

## Governance layer for AI-generated code

FH wraps any coding agent (OpenCode, Codex, etc.) as a **post-generation governance gate**.

```bash
npx --package @chrono-meta/fh-gate fh-gate                    # default: Claude backend
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate   # Codex backend
FH_BACKEND=auto npx --package @chrono-meta/fh-gate fh-gate "src/foo.ts" full
# → FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE

# or, via Homebrew (same content, no npx prefix needed after install):
brew tap chrono-meta/forge-harness && brew install forge-harness
fh-gate
```

`fh-gate` uses the same FH governance prompt for both runtimes. `FH_BACKEND=claude` runs `claude --print`; `FH_BACKEND=codex` runs `codex exec`; `FH_BACKEND=auto` prefers Codex when both CLIs are present — note that `auto` is fallback *selection*: it runs ONE leg. `FH_BACKEND=cross` runs BOTH families and unions their findings (a finding only one family saw is still a finding, so it unions rather than votes); the verdict is the most severe across legs. It costs ~2x, so it is for load-bearing verdict/gate/irreversible-surface changes, not a default. The output always declares which legs actually ran (`FH_GATE_LEGS:`, `FH_GATE_DECORRELATED:`) — on a machine with only one family, `cross` degrades to that single leg and says so, because a single-family result that reads as cross-checked is worse than an honest one.

For direct skill or agent execution outside Claude Code, use `fh-run`:

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run --skill phantom-quench --file docs/foo.md
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run --agent fh-commons:quench-challenger --file plugins/fh-meta/skills/foo/SKILL.md
```

To check whether a changed FH skill/agent surface still has a clean Codex adapter path, run:

```bash
npx --package @chrono-meta/fh-gate fh-codex-doctor --strict
```

`fh-codex-doctor` scans the canonical skill/agent registry and reports which units are Codex-native,
adapter-required, Claude-native, or unclassified. It is a drift detector for the thin adapter boundary;
it does not try to clone the Claude Code automation layer. When run from an FH checkout it scans the
current working tree; outside a checkout it scans the installed package.

For Codex-primary work, keep using Codex's native goal/session features when available. `fh-goal` is only a portable wrapper for one-off non-interactive runs that should be followed by FH governance:

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-goal --prompt "Implement X and update tests" --gate quick
```

The broader FH automation layer still depends on Claude Code for sub-agents, hooks, and slash commands. The portable path is shared documents plus runtime adapters, not separate Codex and Claude forks.

**Recommended posture — Claude Code as orchestrator, others as sidecars.** FH's automation layer (auto-firing hooks, sub-agent dispatch, onboarding, memory) is Claude-Code-native, so the fullest experience runs **Claude Code as the main orchestrator with Gemini, Codex, or Antigravity (`agy`) as actively-used sidecars**. You can also run a **non-CC runtime as your main agent** — you keep the full methodology layer and M1 skills (M1 = runs on any runtime as written; M2 = needs agent dispatch; M3 = Claude-Code-native — the portability tiers detailed in [`docs/codex-compat.md`](docs/codex-compat.md)) through `fh-gate`/`fh-run`, but you do **not** get the autopilot layer: hooks don't auto-fire, M2 agent-dispatch steps need the adapter (or interactive approval), and M3 skills are reference-only. This is a deliberate two-layer boundary, not a gap to be closed. Per-runtime detail: [`docs/codex-compat.md`](docs/codex-compat.md) (tier-by-tier) and [`multi_model_sidecar_strategy.md`](knowledge/shared/harness-core/multi_model_sidecar_strategy.md) (sidecar engines, including the Gemini→`agy` succession at the 2026-06-18 EOL).

**Empirical result (2026-05-31)**: Applied to OpenCode's AI-generated `permission/arity.ts` (163 lines, CI green). Current gate semantics classify this as BLOCKED: 2 A-grade findings CI didn't catch (short-token overflow in allowlist, executor tools absent from arity table).

**Does the method actually add anything? A measured check (2026-07-14).** We held the model fixed at a
mid-tier floor and varied only the review *method*, on unseen gate snippets with planted *default-toward-PASS*
(fail-open) holes. On eight subtle holes — authored by two other models so the test set wasn't tuned to our
method — a plain review caught 5/8 (and two of those "catches" were the wrong bug, i.e. false confidence);
the same model with FH's degrade-direction lens caught 6/8 with zero false alarms. The honest part: **both
single-model lanes missed the same two holes** (a falsy error-sentinel, and a separator-negation parse). A
different model family, same lens, caught both — so the FH *stack* (lens + cross-family + a mechanical
pre-screen) reaches 8/8. The takeaway isn't a headline score; it's that the value comes from the
**decorrelated stack**, because even a well-prompted single model has a correlated blind spot that only a
different family closes. The two missed classes are now caught mechanically (a lint pre-screen), one layer
earlier. Small sample (single draw); reps and harder holes are the stated next step. Method + full result:
[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md).

Full spec: [`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md)

---

## The forge

forge-harness treats a project like steel — and the metaphor is literal, not decoration. Work is shaped,
hardened by attack, and only then does it ship faster, for having survived.

| Movement | What happens | The commands |
|---|---|---|
| **Forge** | shape the raw project into a harness — raise its floor | `install-wizard`, "harness-ify this project" |
| **Quench** | harden it by attack — the cold pass leaves standing only what is sound | `steel-quench` · `phantom-quench` |
| **Temper** | take the brittleness back out of the hardened asset | `steel-quench` Wave-T · `templates/temper_check.sh` |
| → **Accelerate** | a blade that survived the forge cuts faster | `goal-quench` — *Pass → Accelerate* |

All four movements ship. Temper was named before it was built — deliberately (see
[`ETHOS.md`](docs/ETHOS.md#the-forge)) — and shipped once measurement runs validated it. Around the forge,
two more signatures keep it running: `harvest-loop` (each session's lessons become permanent skills) and
`agent-composer` (orchestrate the dispatch). The other skills wait until you need them — full list below.

## 40 skills · 8 agents

> Count = non-deprecated skills (deprecated redirect stubs — kept only for old-name routing — excluded).

<details>
<summary>Full asset activation check</summary>

| Asset | Role | Triggers |
|---|---|---|
| `steel-quench` | Full-spectrum adversarial verification | "Run the quench", "Attack from the root" |
| `phantom-quench` | Phantom claim detection + source back-tracing | "Verify the source", "Grounding audit" |
| `harvest-loop` | End-of-session learning → evolution pipeline | "Harvest the session" |
| `agent-composer` | Plans optimal agent dispatch | "Run in parallel", "Which agents?" |
| `sim-conductor` | Meta-simulation orchestrator | "External user perspective" |
| `context-doctor` | Token efficiency + `.claudeignore` | "Session is slow", "Clean up context" |
| `harness-doctor` | Harness structure diagnosis | "Check my Claude setup" |
| `pipeline-conductor` | 4-axis quality gate (backward/adversarial/forward/record) | "Run the quality gate" |
| `field-harvest` | Back-propagate field patterns to hub | "I could reuse this" |
| `dialogue-harvest` | Mine AI-dialogue logs: strip sycophancy, label induced vs independent | "What did I actually contribute in this thread?" |
| `frontier-digest` | HN + arXiv → actionable insights | "AI trend digest" |
| `hub-cc-pr-reviewer` | Automated PR review | "Review this PR" |
| `verify-bidirectional` | Reverse-verify decisions | "Is that right?", "Double-check" |
| `deep-clarify` | Socratic requirements clarification | "I'm not sure what to build" |
| `install-wizard` | Initial onboarding | "First-time setup" |
| `plugin-recommender` | Plugin recommendations | "Is there a good tool for this?" |
| `apex-review` | Executive-perspective quality review | "Will this hold up?" |
| `meta-prompt-builder` | Meta prompt design | "Write a prompt for the agent" |
| `asset-placement-gate` | Hub vs project asset routing | "Should this be shared?" |
| `cross-ecosystem-synergy-detection` | Cross-tool synergy finder | "Are my tools working together?" |
| `corpus-grounding-expander` | Multi-version public-domain corpus → verified-axiom grounding store | "Broaden the grounded corpus" |
| `persona-roster-expander` | Persona seed → tiered, judgment-mapped cast | "Broaden these personas" |
| `convergence-loop` *(fh-commons)* | N-round convergence loops | "Single-pass seems suspicious" |
| `token-budget-gate` *(fh-commons)* | Pre-task token cost estimate | "How expensive is this?" |
| `mcp-circuit-breaker` *(fh-commons)* | MCP tool failure pattern detection | "MCP keeps failing" |
| `ko-tech-writer` *(fh-commons)* | Korean technical-writing pipeline (register calibration, translationese removal, honesty layering, perceptual QA) | "기술문서 써줘", "번역투 고쳐줘" |
| `quench-challenger` *(fh-commons)* | Adversarial pressure-test agent | "Challenge this with a devil" |
| *(+ additional assets)* | marketplace-gate · contention-layer · edit-manifest · fact-checker · goal-quench · hub-persona-auditor · install-doctor · memory-hygiene · persona-innovator · prompt-regression · public-surface-audit · salience-splitter | |

| Active count | Diagnosis |
|:---:|---|
| **28+** | Advanced — chain agent-composer + sim-conductor + steel-quench + pipeline-conductor |
| **10–27** | Activation stage — gradually enable unchecked assets |
| **0–9** | Early stage — start with `install-wizard` |

**Find a skill by what you're trying to do:**

| Cluster | Skills |
|---|---|
| Verification | `steel-quench` · `phantom-quench` · `convergence-loop` · `prompt-regression` · `return-path-gate` |
| Orchestration | `agent-composer` · `pipeline-conductor` · `goal-quench` · `deliberation` |
| Diagnosis | `harness-doctor` · `context-doctor` · `install-doctor` · `mcp-circuit-breaker` |
| Harvesting / Learning | `harvest-loop` · `field-harvest` · `edit-manifest` · `memory-hygiene` |
| Gate / Guard | `token-budget-gate` · `asset-placement-gate` · `marketplace-gate` |
| Discovery | `plugin-recommender` · `cross-ecosystem-synergy-detection` · `frontier-digest` · `verify-bidirectional` |
| Content / Simulation | `sim-conductor` · `apex-review` · `meta-prompt-builder` · `deep-clarify` |
| Setup | `install-wizard` · `hub-cc-pr-reviewer` · `salience-splitter` |

> **Full phrasebook** — every skill + agent with its one-line definition and the plain-language phrase
> that triggers it: [`CHEATSHEET.md` §12](CHEATSHEET.md#12-skills--agents--what-each-does-and-what-to-say).

</details>

---

## Model setup

Claude Code does not auto-select models by task complexity — you configure this once.

```bash
/model sonnet   # recommended default — FH dispatches stronger models itself where they matter
```

| Command | Who runs what | Best for |
|---|---|---|
| `/model sonnet` | Sonnet session; FH dispatches higher-tier sub-agents on declared floors | **FH default** — operation + routine dev |
| `/model opus` | Opus handles everything | Harness-editing sessions (Mode D) · maximum depth on every turn |
| `/model opusplan` | Opus *plans* · Sonnet executes *(when Opus engages)* | Cost-conscious routine coding — see caveat |

**Why default Sonnet now works**: measured (see §Model setup evidence note below), *operating* FH is
nearly model-flat — the rules in context do most of the work. What still needs a stronger model is a
small set of depth-sensitive turns, and FH handles those itself: **some skills and agents declare a
model-tier floor** (e.g. `quench-challenger` floors at opus) and are dispatched as sub-agents at the
floor tier when your environment can reach it — your session model stays untouched. **FH never switches
your session model**: a default you set by hand is followed; floors apply only to FH's own sub-agent
dispatches. If your environment tops out below a floor (e.g. Sonnet-only API routing), the floored
asset still runs at the best available tier with an explicit `below-floor` flag in its output — degraded
delivery is visible, never silent (tier-floor resolution: `knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Tier-floor`).

**`opusplan` caveat (measured)**: its Opus engagement is **not guaranteed** — in a measured 10-turn run
it used Opus on **0** turns (CC classifies few turns as "plan-mode"). If you want Opus on every turn,
pin `/model opus` (22/22 turns Opus in the follow-up run). **Sub-agent dispatch** model is set by the
dispatch's own `model` parameter; the session model/plan-mode does **not** propagate to sub-agents.

> **By role**: running FH (field projects, gates, routine dev) → `/model sonnet` + let the floors
> escalate. Editing the harness itself (Mode D) → pin the strongest model you have — harness
> *self-development* is where tier depth measurably pays (design-increment finding), while operation
> does not. Sub-agent token costs are CC-visible in the session jsonl under `message.model`.

**Measured, not asserted** (worked examples): on a blind rule-application battery, *operating* FH is
near model-flat — **every Claude tier measured scores 94–100%** (Fable, Opus 4.8, Sonnet 4.6 and 5,
Haiku 4.5); the few lost points are format discipline, never a trap or gate-class miss. The tiers
separate only on above-rubric *design* increments (developing the harness, not running it) — which is
why the default is Sonnet with **tier-floored dispatch** covering the depth-sensitive turns, and a
pinned stronger model is recommended only for harness-editing sessions.

This is stated as an **invariant, not a per-model leaderboard**. Two structural laws, neither of which a
new release overturns:

1. **Operation flattens across tiers** — the rules-in-context do the work, so every tier ceilings
   on rule-application (Sonnet 5 tied Opus 4.8 at the battery ceiling in a 2026-07-03 replication).
2. **Depth (design increments) is tier-ordered, and the order is fixed *within a generation*** — a lower
   tier never overtakes the higher of the **same** generation (tiers are priced to be worth it, so the
   vendor keeps them ordered). *Across* generations a newer lower-tier model can surpass an older
   higher-tier one (Sonnet 5 ≥ Opus 4.8 on operation is exactly this cross-generation case) — but the
   current top tier of any generation still wins its own depth turns.

So the doctrine is permanent, not perishable: **default to the mid tier for operation; escalate to the
current top tier for depth.** Re-measurement is warranted only when a new model becomes a field-main
*candidate* (a one-time cross-generation threshold check), never to re-confirm same-generation tier order
— that is guaranteed by design. Details + dated runs: `docs/OUTPUT_EVIDENCE.md` §Validation signals.

If you use external CLIs (Gemini, Codex, `gh copilot`) as sidecars, their costs are billed to their own quota and not visible in CC's token display.

### Hardware tiers (local sidecars are optional accelerators)

FH needs **no local LLM** — the baseline is whatever runs Claude Code. Local models are *optional*, for
the canary / cheap-breadth rungs only:

| Tier | Spec | Runs locally | What it buys |
|---|---|---|---|
| **Minimum** | anything that runs Claude Code | nothing | full methodology + gates; operating FH is ~model-flat across every tier tested (94–100%) |
| **Recommended** | laptop-class, ~16GB RAM | one 8B-class quantized model (e.g. an 8B / small Gemma) | a token-free **floor canary** (pre-screen before a metered sim) · offline triage · a cheap-breadth panel arm |
| **Optional (heavy)** | ~24GB VRAM GPU | a 27–32B model | a *stronger* decorrelation canary |

> Local tiers are **canaries, never the terminal verdict** — measured: the floor model missed a subtle
> adversarial case the frontier caught (and even a 27–32B local scored 1/4 on it). They lower the *cost
> of breadth*; the verdict stays frontier.

---

## Multi-Model Sidecar

Run Gemini, Codex, or `gh copilot` as independent reviewers alongside Claude. The point is **context
isolation**: a reviewer that did *not* co-create the work is cold to its froth — whoever sits *outside* the
collaboration tends to catch what the co-author, now an advocate for the shared result, glides past. It's
symmetric, not a model-ranking: when you co-build with Gemini, a fresh Claude catches its froth; when you
co-build with Claude, a fresh sidecar catches Claude's.

In one internal case study, layering reviewers surfaced progressively more issues — a single in-session
pass missed items that cross-session personas caught, and an external-CLI reviewer surfaced a few the
Claude personas shared a blind spot on. Treat it as a worked example, **not a benchmark**: the gain scales
with task complexity and how much you co-created the artifact, and an isolated reviewer also adds false
positives you have to triage. Whether the net is worth it on a given task is an empirical, per-use question.

Claude-side token cost does not increase when the extra reviewer is an external CLI — it bills to its own quota.

---

## Research

> **FH papers** — the methodology below is documented, not just asserted:
> - **v1.0 — methodology** · [Zenodo](https://zenodo.org/records/20397566) (DOI 10.5281/zenodo.20397566). 2-layer design, 6-axis framework, 4-agent orchestration, and the compounding loop, with empirical evidence.
> - **cs.SE companion — governance-gate methodology** · **published** [Zenodo](https://zenodo.org/records/20680081) (DOI 10.5281/zenodo.20680081 · latest v1.1 10.5281/zenodo.20740038 · CC-BY-4.0) · arXiv submitted (cs.SE, in moderation).
> - **cs.AI companion — "Governance Dividend"** · in preparation.

External convergence:
- ["Dive into Claude Code: The Design Space of Today's and Future AI Agent Systems"](https://arxiv.org/abs/2604.14228) — arXiv April 2026
- ["Code as Agent Harness"](https://arxiv.org/abs/2605.18747) — arXiv May 2026
- Stanford IRIS Lab: ["Meta-Harness"](https://arxiv.org/abs/2603.28052) — +7.7pts at 4× fewer tokens

---

## Learn more

| Resource | Purpose |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | AI operating rules + sync/push protocol |
| [`CHEATSHEET.md`](CHEATSHEET.md) | Full command reference |
| [`AGENTS.md`](AGENTS.md) | Runtime agent specs |
| [`CATALOG.md`](CATALOG.md) | Past work search index |
| [`CONTRIBUTING.md`](docs/CONTRIBUTING.md) | How to contribute skills and patterns |
| [`tracks/_contrib/`](tracks/_contrib/README.md) | **Consent lane** — share a de-identified work session; the repo compounds across operators, not just locally |
| [`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md) | Governance gate spec |
