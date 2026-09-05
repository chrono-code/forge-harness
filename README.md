<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/banner.png" alt="forge-harness — Forge your projects, pass them through, faster. Quality is the lever — speed is the result." width="680">
</p>

<p align="center">
  <a href="https://github.com/walkinglabs/awesome-harness-engineering#coding-agent-harnesses"><img src="https://awesome.re/mentioned-badge.svg" alt="Mentioned in Awesome Harness Engineering"></a>
  <a href="https://github.com/VoltAgent/awesome-agent-skills#community-skills"><img src="https://img.shields.io/badge/listed_in-awesome--agent--skills-0ea5e9.svg" alt="Listed in awesome-agent-skills"></a>
  <img src="https://img.shields.io/badge/Claude_Code-compatible-a855f7.svg" alt="Claude Code">
  <a href="https://www.npmjs.com/package/@chrono-meta/fh-gate"><img src="https://img.shields.io/npm/v/@chrono-meta/fh-gate.svg?color=cb3837" alt="npm"></a>
  <a href="https://github.com/chrono-meta/homebrew-forge-harness"><img src="https://img.shields.io/badge/homebrew-tap-FBB040.svg" alt="Homebrew tap"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e.svg" alt="MIT License"></a>
</p>

<p align="center">
  <b>English</b> · <a href="README.ko.md">한국어</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a>
</p>

<p align="center">
  <b>Stop re-explaining your rules to your agent. Put them in the project.</b>
</p>

<!-- This line was chosen, not drafted. Before rewriting it, read docs/ETHOS.md
     §"Who this line is for" — two rejected alternatives are recorded there with why. -->
<p align="center">
  <b>Quality gates that catch you, not just your agent.</b>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/gate-block.gif" alt="regression guard blocking a change that dropped a Done When section, then passing once it is restored" width="820">
</p>
<p align="center">
  <sub>A real run, not a mock: an agent “tidied up” a skill spec (<code>SKILL.md</code>) and dropped its <b>Done When</b> section. The guard names the missing section; put it back and the cleanup ships unchanged.<br>Regenerate: <code>brew install vhs &amp;&amp; vhs docs/demo/gate-block.tape</code></sub>
</p>

---

## Pick one. They install differently and buy you different things.

### ① Just the gate — you do not need Claude Code

```bash
npx --package @chrono-meta/fh-gate fh-gate          # nothing to install
brew tap chrono-meta/forge-harness && brew install forge-harness   # or this
```

**What you get**

- A change is judged **before** it merges, and the verdict names what the change **lost** — not that
  something is "off". The GIF above is that verdict on a real diff.
- The verdict is a **typed value**, not text you grep: `PASS · PENDING · BLOCKED · ESCALATE`.
- Runs anywhere a shell runs — CI, a pre-commit hook, a different coding agent. Claude Code optional.
- **It reviews your own code, not just an agent's.** Point it at a diff and it names the weakness — a verdict
  that quietly degrades toward PASS, a reference that does not exist, a secret, a claim with no grounds —
  so you fix it and re-run *before* merge. Where each FH engine applies (harness building · skill/agent
  authoring · code review · irreversible-surface gates · context continuity), and what changes by model
  tier and effort level: [`docs/USE_CASES.md`](docs/USE_CASES.md) ·
  [`docs/model_tier_expectations.md`](docs/model_tier_expectations.md).
  How the gates line up with ISO/IEC AI-testing and AI-quality standards (42119 · 29119-11 · 25059 · 42001), as a
  self-assessment with evidence pointers: [`docs/STANDARDS_ALIGNMENT.md`](docs/STANDARDS_ALIGNMENT.md).

### ② The whole harness — inside Claude Code

```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness
git clone https://github.com/chrono-meta/forge-harness.git ~/projects/forge-harness
cd ~/projects/forge-harness && claude        # then type a greeting: hi · 안녕 · こんにちは · 你好
```

<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/door2-menu.gif" alt="typing hi in a fresh forge-harness clone; FH reads the checkout, opens the new-user menu, and warns that the install wizard has not run yet" width="820">
</p>
<p align="center">
  <sub>The whole of the fourth line. A clone made minutes earlier: it reads the checkout, sees no session files, opens the <b>new-user</b> menu — and tells you the wizard has not run yet.<br>Launch and thinking time are hidden; every character is that run's output. Regenerate: <code>vhs docs/demo/door2-menu.tape</code></sub>
</p>

**What you get, on top of ①**

- You stop having to pick the check. The harness reads what you are about to do — publish, delete,
  rewrite history, open a PR — and names the gate for that moment. ① is one command you remember; ②
  is the layer that remembers for you.
- **41 skills · 8 agents** you can call in plain language: diagnose a project, accelerate one, wire a
  new one up.
- `tracks/` keeps what each session learned, so **session 2 starts where session 1 stopped**. This is
  the part that compounds — and the part you cannot judge on day one.
- Ask for the same thing three times and it stops answering: it builds you the harness that answers.

<sub>🟥 <b>One thing ② does not give you.</b> FH also carries a 4-axis <b>pre-commit</b> hook, and it is
not for your repos: it hard-codes hub paths and hub markers, so installing it into your project blocks
your commits instead of helping. The installer treats it as opt-in and tells you to skip it unless you
develop FH itself. <b>For your own repos, ① is the gate</b> — wire it into CI or your own pre-commit.</sub>

<sub><b>Not sure?</b> Start with ①. It costs one command and nothing to uninstall, and ② is a superset —
nothing you learn in ① is thrown away.</sub>

### What neither door is

**It does not replace the review that happens after.** It moves the question earlier, so that what
reaches a human reviewer is smaller — not so that a human stops reviewing. The bottleneck it targets
is the gap between how fast things get generated and how fast a person can check them; it closes that
gap from the *front*, by cutting what has to travel to the back.

**What a diff cannot show stays a person's job.** Anything that only surfaces when the thing actually
runs — on a real screen, against real state — is outside what any of this reaches. That work does not
shrink because a gate exists upstream of it. It gets a shorter queue.

---

## Does it actually catch anything?

**On real code someone else wrote** (2026-05-31). `fh-gate` ran on OpenCode's AI-generated
`permission/arity.ts` — 163 lines, agent-written, **CI green**. Verdict: **BLOCKED**, on two A-grade
findings CI missed (short-token overflow in the allowlist; executor tools absent from the arity table).

**On planted holes, with the model held fixed** (2026-07-14). Eight subtle *default-toward-PASS*
(fail-open) holes, authored by two *other* models so the set was not tuned to us. The model stayed
pinned at a mid-tier floor; only the **method** changed:

| Method | Caught | False alarms |
|---|---|---|
| Plain review | 5/8 — **and 2 of those were the wrong bug** (false confidence, worse than a clean miss) | — |
| + FH's degrade-direction lens | 6/8 | 0 |
| + a different model family, same lens | **8/8** | 0 |

🟥 **The load-bearing line is not the 8/8.** Both single-model lanes missed **the same two holes** — a
falsy error-sentinel, and a separator-negation parse. Same input, same blind spot: a second reviewer of
the *same kind* would have missed them too. That is the whole argument for decorrelation; the rest is
arithmetic. Small sample (single draw); reps and harder holes are the stated next step. Method:
[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) §Dominance · more
dated runs: [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md).

<p align="center">
  <b>Quality is the lever; speed is the result.</b> ·
  <a href="docs/ETHOS.md"><b>The principles</b></a> ·
  <a href="docs/WHY.md"><b>Why it exists</b></a> ·
  <a href="docs/OUTPUT_EVIDENCE.md"><b>The evidence</b></a> ·
  <a href="CHEATSHEET.md"><b>How to use it</b></a><br>
  <sub>If this is useful, a star helps others find it.</sub>
</p>

| If you're here because… | forge-harness solves it |
|---|---|
| Context disappears when a session ends | Persistent `tracks/` — resumable from anywhere |
| You repeat the same setup across projects | Connect once to the hub, share across all projects |
| Team AI know-how lives only in people's heads | Codify it so everyone shares it |
| You want AI to get *better* as work accumulates | Skills and patterns compound session over session |
| You need a governance layer for AI-generated code | `fh-gate` wraps any coding agent as a post-generation gate |

> **This document is for humans.** AI operating rules → [`CLAUDE.md`](CLAUDE.md) · command reference →
> [`CHEATSHEET.md`](CHEATSHEET.md). The two doors above are the whole decision; everything below is
> reference for when you want it.

---

## Get going

**Type `hi`** — or `안녕`, `こんにちは`, `你好`, `hola`, `bonjour`. Any of them opens a numbered menu:
pick a door, answer a couple of questions, and it runs the install wizard for you. Say **"Connect a
project"** and the hub scans `../`, finds `.git` directories, and creates `tracks/{project}/`.

<sub>🟥 <b>Honest about that</b>: matching your language is a prose rule with no mechanical floor, so it
does not always hold — measured blind on a clean clone (2026-08-21) it translated the whole menu, but
whether the menu fires at all is shakier: one greeting variant produced none. Say so and it will
switch. Written up in <code>CLAUDE.md</code> §Voice/Tone rather than smoothed over.</sub>

**Requirements.** Door ② needs the Claude Code CLI (`claude --version`); door ① does not — that is the
point of it. One gate additionally needs **Python + PyYAML** (it parses YAML and fails closed without
it, turning all of `npm test` red): `python3 -m pip install --user pyyaml`. Why it fails closed:
[`CHEATSHEET.md`](CHEATSHEET.md) §6.

**Your first 15 minutes.** Setup worked when a greeting shows the 🐿️ door menu and "Connect a project"
creates `tracks/{your-project}/`. Then take a win in the same session: **"accelerate this project"** (a
ranked, install-gated plan) or **"run /context-doctor"** (token-waste scan); for full initial setup —
hooks, gates, baseline, each approved individually and a decline recorded — ask for
**`/install-wizard`**. One honest note: FH's payoff is **compounding**, and it shows from **session 2
onward**; day one gives you the menu, the plan, and the gates, so don't judge it on day one. Already
cloned elsewhere? That path *is* your hub. Unfamiliar words →
[`GLOSSARY.md`](knowledge/shared/GLOSSARY.md); trying ② on one project only?
[`templates/starter_profile.md`](templates/starter_profile.md) is one command and a curated first five.

> ⚠️ **Plugin-only is partial synergy.** You can install the plugin without cloning the hub
> (`claude plugin install -s user fh-meta@forge-harness`, then `cd` into your project). You get the
> skills and agents, but **not** the hub-side orchestration — the `CLAUDE.md` governance, or the
> compounding `tracks/` memory that makes them compound across sessions.
>
> 🟥 **Two version numbers, and they measure different things.** The **package version** (npm badge,
> top of page) is what you install; the **identity-maturity release** (`identity-v1.0.0`, on the
> Releases page) is how far along the harness is — `0.x` by design, because it refuses to call all five
> identities green when they are not. They are not on one scale, and a high package number is not
> maturity: [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md).
> 🟢 **2026-09-04 — the two counters merge.** `identity-v1.0.0` (every identity 🟢) is the **last**
> identity-track tag and the first to carry the *Latest* badge. From here on a release is **one number for
> both** — the next is the package major that carries identity 1.0 — and release notes are written in
> English with a Korean summary. The paragraph above stays as the reason the tracks were split while
> not everything was green; it is history, not the current rule.

---

## What makes it a harness, not a toolbox

A harness reads your **intent** and forges it into a **machined form** — rules an AI reliably follows,
or deterministic code that needs no model at all. The payoff is **less trial-and-error on the human
side**: the request → feedback → regenerate loop *relocates* into the harness and runs in parallel, so
your attention goes only where a change is irreversible. A **skill, agent, or plugin** is a tool; a
**harness** is a level up — a *star*: one project's tools, rules, gates, and memory bound into a single
working body. **forge-harness is the galaxy those stars live in**, binding many onto a shared floor so
they evolve together instead of drifting apart. It can also run a field harness **in simulation inside
its own sandbox** and then **emit** it as an independent one — 🟥 read that step as direction of
travel, not a shipped feature: the chamber has emitted once, and that run skipped the full flow.

```
forge-harness/   ← the hub (persistent brain)      Project A ──→ connect hub in CLAUDE.md
├── knowledge/   → shared across all projects      Project B ──→ connect hub in CLAUDE.md
└── tracks/      → work records per project
```

Structurally it is **two layers** — a model-agnostic **methodology layer** (`tracks/`, `knowledge/`,
`SKILL.md` docs) and a Claude-Code-native **automation layer** (agents, hooks, slash commands,
`CLAUDE.md` rules). That boundary is deliberate, not a gap to be closed:
[`docs/codex-compat.md`](docs/codex-compat.md). **Where this sits (2026):** basic agent orchestration is
commoditizing into standard infrastructure, and FH deliberately stakes nothing on that plumbing — its
durable layer is what does not commoditize: the governance gates, drift control, and the cross-project
compounding loop. Routing and dispatch are means; **the gate and the loop are the asset.**

### The five identities — what FH is for

Not five modules and not five shipped features: the **shapes the skills clump into**, named after the
fact rather than layered on top.

| | Identity | What a person gets |
|---|---|---|
| **①** | **Harness cluster** | One task rides several harnesses, governance computed *between* them — **call** a capability you do not have rather than build it, and **absorb** the one you should have built |
| **②** | **Project incubator** | A new harness comes out **walking where it was born**, not as an empty scaffold |
| **③** | **Governance gate** | What must not ship is blocked **mechanically**, not by remembering to check |
| **④** | **Frontier absorption** | When you are unsure, *what we already have* then *what the world already built* gets searched first — so nothing is rebuilt |
| **⑤** | **Amplifier** | A short intent gets forged all the way to the finished artifact |

A sixth row is deliberately absent: `Ⓑ` **Project Booster** — FH's machinery accelerating *another
harness's own development* — is real and graded, but sits on a different layer, hence a letter rather
than a number. **And the table is not five working features**: maturity is graded per identity
(`aspirational → partial → RC → REALIZED`) with dated evidence, deliberately not copied here — a grade
kept in two files goes stale in one, and this page exists in four languages. Read the grades before
relying on any row: [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md). And for **how to use each one** — which command or door lights which identity — [`docs/IDENTITIES.md`](docs/IDENTITIES.md): the grades say *how ready*, that page says *how to call it*.

Two properties cut across all five. **It rides the frontier instead of patching it** — dispatching
across families (Claude, Codex, Gemini, local) to co-evolve, not to paper over weak spots.
**Decorrelation** is today's trust lever and the load-bearing word on this page: deliberately making
two checks fail *differently* — another model family, a run against a real target, an outside audit of
your own record — so what one is blind to, another is not. And **it evolves in two directions**:
outward, each session's lessons compound into the hub; inward, the same gates turn on the harness
itself.

---

## How it is built — three · four · five · six

**Three-stage process · four engines · five identities · six-axis verification.** The identities above
are what appears where the process and the engines interlock — the five are the forged, graded, stable
ones; other identities surface and recede with how you steer and how far you push (operator's formulation,
2026-09-05); **four engines** (`judgment-circuit` · `ship-gate` · `context-continuity` ·
`external-grounding`) are the core every FH-specific output comes from; the **three-stage process** —
① plant the judgment circuit *before* design → ② parallel decorrelation in the middle → ③ burn it down on
six axes — is the order every piece of FH work runs in, forging an engine included, with speed as the arrow
at the end, not a fourth box. ⚠️ **The six
axes are not a fourth layer**; they are *what stage ③ consists of*. Full canon, and why this is
deliberately *not* a clean stack:
[`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md) — the same three in
the smith's words (forge · quench · temper) are in [`ETHOS.md`](docs/ETHOS.md#the-forge).

🟥 **Axes are not divided by *how adversarial* they are, but by *what they were given*.** Hand two
reviewers the same input and the same blind spot survives, however many you add:

| Axis | **What it gets** | What it catches | Typical instrument |
|---|---|---|---|
| **ⓐ Different family** | the diff + the author's framing | the **implementation** is wrong | a reviewer from another model family (`auto-decorrelation`) |
| **ⓑ Standpoint** | the diff + **the target harness's own canon** | **whether the rule you cited actually says that** | run the diff from that harness's own repo and rules ([`§7`](knowledge/shared/harness-core/field_verdict_crossfamily_gate.md)) |
| **ⓒ Isolated grounding** | the sentences the author wrote — their claims *and* what they **declared before starting** — + the tree as it stands | the **claim** is wrong · the delta does not match what was declared | someone who did not write it re-measures what it says |
| **ⓓ Third-party encounter** | the problem + **someone else's codebase** | **is this already solved** · where your change touches someone else's repo | look at the same problem in an unrelated third repo |
| **ⓔ First real use** | one real target | the **way you are measuring** is wrong — the instrument's instrument | run it once against one real target and check by hand |
| **ⓕ Revert and observe** | the tree with the wiring deleted | the **anchor** is wrong — the check is decorative | delete the thing it guards and confirm *that specific* check goes red |

**You do not run all six every time, and that is the design** — do not multiply them, choose:

```
one-line fix (typo · gitignore)     nothing burns — with one answer, planting a circuit is overhead
ordinary code change (reversible)   ⓔ first real use + ⓕ revert
verdict · gate code                 + ⓐ different family — verdict logic is what a reviewer who
                                    shares the author's optimism misses structurally
change touching another harness     + ⓑ standpoint — bolt on three families and if all three eat
                                    your framing, nobody asks "does that canon actually say so"
very large · irreversible           + ⓒ isolation + ⓓ third-party encounter. Burn all of it
```

An axis is defined by its **input**, not by the reviewer's ability, so base-model advances do not
supersede this: a stronger model still cannot see information it was not given. 🟥 **Limits before
citing it** — the table is **n=1** (one artifact, one session, one author), and when 16 findings were
handed with provenance removed to two classifiers from other families, **3 of the 5** the author
attributed to ⓓ were judged to belong elsewhere. A worked day inside these gates, misses named:
[`docs/GATE_DAY.md`](docs/GATE_DAY.md).

---

## Where a rule lives — three seats

A harness learns by writing rules down, and the always-loaded file only ever gets longer — so the
reasoning ends in a corner: *a harness that keeps learning keeps getting more expensive to start.* It
does not, because a rule has **three seats**, chosen by *when the rule has to fire*: **always-loaded**
(triggers that are an *intention* — nothing can hook one, so salience is the only layer) · **the gate's
own error message** (triggers that are an *action*; the message that blocks you also teaches the form,
and this seat is free) · **the hook** (properties of a record — present, typed, attributable,
non-vacuous). The middle seat is the one that usually goes unused. Full table, and the honest limit
that it only fires on failure:
[gate-locality](knowledge/shared/harness-core/gate_locality_principle.md) §Where a rule lives.

---

## Run it outside Claude Code — the `fh-gate` CLI

FH wraps any coding agent (OpenCode, Codex, …) as a **post-generation governance gate**.

```bash
npx --package @chrono-meta/fh-gate fh-gate                    # default: Claude backend
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate   # Codex backend
FH_BACKEND=cross npx --package @chrono-meta/fh-gate fh-gate   # BOTH families, findings UNIONed
# → FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE
```

Same governance prompt for every runtime. `auto` is fallback *selection* — it runs **one** leg; `cross`
runs both families and unions their findings (a finding only one family saw is still a finding), costs
~2x, and is for load-bearing verdict / gate / irreversible-surface changes, not a default. The output
always declares which legs actually ran, so a single-family result never reads as cross-checked.
`fh-run` (one skill or agent directly), `fh-goal` and `fh-codex-doctor` (adapter drift check) ship
alongside it — flags and the full env table in [`CHEATSHEET.md`](CHEATSHEET.md), spec in
[`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md).
**Recommended posture — Claude Code as orchestrator, others as sidecars**: a non-CC runtime can be your
main agent and keeps the methodology layer through `fh-gate`/`fh-run`, but not the autopilot (hooks do
not auto-fire, dispatch needs the adapter) — tier-by-tier in
[`docs/codex-compat.md`](docs/codex-compat.md).

---

## Model setup

Claude Code does not auto-select models by task complexity — you configure this once.

| Command | Who runs what | Best for |
|---|---|---|
| `/model sonnet` | Sonnet session; FH dispatches higher-tier sub-agents on declared floors | **FH default** — operation + routine dev |
| `/model opus` | Opus handles everything | Harness-editing sessions · maximum depth every turn |
| `/model opusplan` | Opus *plans* · Sonnet executes *(when Opus engages)* | Cost-conscious routine coding — see caveat |

Measured, *operating* FH is near model-flat — the rules in context do the work — so FH dispatches the
few depth-sensitive turns itself at a declared floor and **never switches your session model**; a
below-floor environment gets an explicit `below-floor` flag rather than a silent degrade. ⚠️
`opusplan`'s Opus engagement is **not guaranteed** (0 of 10 turns in one measured run). The two
structural laws behind that doctrine, hardware tiers for optional local sidecars, and the multi-model
sidecar posture: [`docs/MODEL_SETUP.md`](docs/MODEL_SETUP.md).

---

## 41 skills · 8 agents

Count = non-deprecated skills. Clustered as verification · orchestration · diagnosis · harvesting ·
gates · discovery · simulation · setup, plus 8 agents (`challenger` · `quench-challenger` · `beginner`
· `main-player` · `expert` · `fact-checker` · `hub-persona-auditor` · `persona-innovator`) dispatched
by those skills or by name. **Full phrasebook** — every skill and agent with its one-line definition
and the phrase that triggers it:
[`CHEATSHEET.md` §12](CHEATSHEET.md#12-skills--agents--what-each-does-and-what-to-say).

---

## Learn more

| Resource | Purpose |
|---|---|
| [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) | How to actually use it, start to finish |
| [`CHEATSHEET.md`](CHEATSHEET.md) | Full command reference |
| [`docs/ETHOS.md`](docs/ETHOS.md) | What FH believes — the forge, the cold reviewer, claims earning their words |
| [`docs/WHY.md`](docs/WHY.md) | Why it exists |
| [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md) | The evidence — papers, dated runs, external convergence |
| [`docs/GATE_DAY.md`](docs/GATE_DAY.md) | One day inside the gates, measured, with the misses named |
| [`docs/MODEL_SETUP.md`](docs/MODEL_SETUP.md) | Which model to run FH on, hardware tiers, sidecars |
| [`docs/codex-compat.md`](docs/codex-compat.md) | Running FH on a non-Claude-Code runtime |
| [`knowledge/shared/GLOSSARY.md`](knowledge/shared/GLOSSARY.md) | Unfamiliar words |
| [`CLAUDE.md`](CLAUDE.md) | AI operating rules + sync/push protocol |
| [`AGENTS.md`](AGENTS.md) | Runtime agent specs |
| [`CATALOG.md`](CATALOG.md) | Past work search index |
| [`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md) | The three-layer canon — process, engines, identities |
| [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) | Identity grades, the two version tracks, the dominance results |
| [`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md) | Governance gate spec |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | How to contribute skills and patterns |
| [`tracks/_contrib/`](tracks/_contrib/README.md) | **Consent lane** — share a de-identified work session; the repo compounds across operators |

> **FH papers**: v1.0 methodology · [Zenodo](https://zenodo.org/records/20397566) (DOI
> 10.5281/zenodo.20397566) · cs.SE companion, published ·
> [Zenodo](https://zenodo.org/records/20680081) (DOI 10.5281/zenodo.20680081) · cs.AI companion in
> preparation. Those, the independent convergent work, and the caveats on each:
> [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md).
