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

<!-- This line was chosen, not drafted. Before rewriting it, read docs/ETHOS.md
     §"Who this line is for" — two rejected alternatives are recorded there with why. -->
<p align="center">
  <b>Quality gates that catch you, not just your agent.</b>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/gate-block.gif" alt="regression guard blocking a change that dropped a Done When section, then passing once it is restored" width="820">
</p>
<p align="center">
  <sub>A real run, not a mock: an agent “tidied up” a skill spec, the guard names what was <b>lost</b>, and the cleanup still ships once the section is back.<br>Regenerate: <code>brew install vhs &amp;&amp; vhs docs/demo/gate-block.tape</code></sub>
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

### ② The whole harness — inside Claude Code

```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness
git clone https://github.com/chrono-meta/forge-harness.git ~/projects/forge-harness
cd ~/projects/forge-harness && claude        # then type a greeting: hi · 안녕 · こんにちは · 你好
```

**What you get, on top of ①**

- The gate stops being a command you remember to run. It fires on its own, before the commit.
- **40 skills · 8 agents** you can call in plain language: diagnose a project, accelerate one, wire a
  new one up.
- `tracks/` keeps what each session learned, so **session 2 starts where session 1 stopped**. This is
  the part that compounds — and the part you cannot judge on day one.
- Ask for the same thing three times and it stops answering: it builds you the harness that answers.

<sub><b>Not sure?</b> Start with ①. It costs one command and nothing to uninstall, and ② is a superset —
nothing you learn in ① is thrown away.</sub>

---

## Details from here down

Everything above is the whole decision. What follows is reference for when you want it.

### After the four lines in ②

**Type `hi`** — or a greeting in whatever language you actually think in: `안녕`, `こんにちは`,
`你好`, `hola`, `bonjour`. **Any of them opens the menu**, and it will try to answer in the language you
used. A numbered menu appears and takes it from there — pick a door, answer a couple of questions, and
it runs the install wizard for you.

<sub>🟥 <b>Honest about that last part</b>: matching your language is a prose rule with nothing
mechanical behind it, so it does not always hold. Measured blind at the floor tier on 2026-08-21, on a
<b>clean clone like the one you just made</b>: Chinese and Korean greetings both came back fully
translated, door labels included. On the maintainer's own machine — which pins a default language —
Chinese landed only 1 time in 5, which is why this note exists at all. What is still shaky is whether
the menu fires: one greeting variant produced no menu. If it answers in the wrong language, or skips
the menu, just say so — it will switch. Written up in <code>CLAUDE.md</code> §Voice/Tone rather than
smoothed over.</sub>

Everything below this line is reference for when you want it, not homework before you start.

- **What it amplifies** — the number of attempts. Trial and error moves off you and runs in parallel.

- **What it does not** — the model's ceiling. A harness lifts a model to its own ceiling, not past it.

- **How you can check** — it grades itself in public. It names **five things it claims to be**
  (harness cluster · project incubator · governance gate · frontier → org propagation · amplifier) and grades each
  one honestly in every [release](https://github.com/chrono-meta/forge-harness/releases). Any square
  that is not green names the real run that is still missing.
  <sub>Each of the five is spelled out further down, under «The five identities».</sub>

---

<p align="center">
  <img src="docs/pillars.svg" alt="HARNESS - FORGE - ACCELERATE - COMPOUND" width="680">
</p>

<p align="center">
  <b>Quality is the lever; speed is the result.</b><br>
  <sub>If this is useful, a star helps others find it.</sub>
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
| You need a governance layer for AI-generated code | `fh-gate` wraps any coding agent as a post-generation gate — `npx --package @chrono-meta/fh-gate fh-gate` |

> **This document is for humans.** AI operating rules → `CLAUDE.md` · Command reference → `CHEATSHEET.md`

**Two footnotes to the two doors**, rather than a third table:

- **Trying ② on one project only?** [`templates/starter_profile.md`](templates/starter_profile.md) is
  one command and a curated first five skills.
- **`brew` instead of `npx` in ①?** `brew tap chrono-meta/forge-harness && brew install forge-harness`
  — identical content, different install UX. Community tap, not Homebrew Core, so `brew search` will
  not find it until you tap.

---

## Requirements

**Door ② needs the Claude Code CLI** — verify with `claude --version`. **Door ① does not**; that is
the point of it.

<details><summary><b>Optional: one gate needs Python + PyYAML</b> — <code>npm test</code> is red without it</summary>

The consent-registry gate parses YAML, and it **fails closed** when it cannot — correctly, since an
unvalidated consent record must not read as a clean one. But that fail-closed turns the whole of
`npm test` (and `prepublishOnly`) red on a machine without PyYAML, and until 2026-08-12 the
requirement was written down **nowhere**. It is written here now — and, as of this edit, *only*
here: it is still absent from `package.json`, the cheatsheet and every other doc, so this block is
the single place a new machine can learn it. That is an improvement over nowhere, not a fix:

```bash
python3 -m pip install --user pyyaml     # verify:  python3 -c 'import yaml; print(yaml.__version__)'
```

Every verdict from that gate prints the interpreter and PyYAML version it used, so a green
states what produced it.

</details>

> ✅ **After the four lines in ②**, the 🐿️ door menu appears on a *typed* greeting, not on launch alone.
> Say **"Connect a project"** → hub scans `../`, finds `.git` directories, creates `tracks/{project}/`.
> For full initial setup (hooks · gates · baseline — each item individually approved, declining is
> respected and recorded), ask for **`/install-wizard`**.
> Already cloned somewhere else? That path *is* your hub — read every `~/projects/forge-harness`
> in the docs as your actual clone path.

**Your first 15 minutes** — what success looks like, and what to do with it:

1. You'll know setup worked when a greeting — in any language — shows the 🐿️ door menu, and
   "Connect a project" creates `tracks/{your-project}/`.
2. Then grab an immediate win in the same session: say **"accelerate this project"** (ranked plan of
   skills/plugins worth wiring, install-gated) or **"run /context-doctor"** (token-waste scan).
3. One honest note: FH's core payoff is **compounding** — session records, harvested learnings,
   cross-session memory. It shows from **session 2 onward**. Day one gives you the menu, the
   acceleration plan, and governance gates; don't judge the compounding on day one.

Unfamiliar words on the way? → [`knowledge/shared/GLOSSARY.md`](knowledge/shared/GLOSSARY.md).

**② without the clone** — plugin only, if you want the skills but not a hub directory:
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

---

## Two version numbers, and they measure different things

This repo publishes **two counters**, deliberately. Conflating them is the single most common way to
misread the project's status, so they are named here rather than only in the canon.

| Counter | Where you see it | What it means |
|---|---|---|
| **Package version** (currently **2.8.0** — hardcoded here, so a release must update this cell by hand; the lockstep bump does not reach it) | npm, the plugin manifests, `git tag v2.x` | *what you install.* Ordinary release numbering: fixes → patch, new assets and gate lanes → minor, a capability **class** appearing or the thing being rebuilt → major |
| **Identity-maturity release** (currently **identity-v0.4.0**) | the GitHub **Releases** page | *how far along the harness is.* `0.x` carries an incomplete-but-honest status **by design**; **the all-green ship is reserved for `identity-v1.0.0`** — every one of the five identities at 🟢, none 🔵/🟡/🔴 |

🟥 **A high package number does not mean maturity.** `2.8.0` is not "ahead of" `identity-v0.4.0`; they are not on
the same scale. The maturity track is deliberately allowed to sit at `0.x` while the package ships and
improves, because the thing `0.x` refuses to do is **lie** — it says out loud that not every identity has
cleared its bar yet, and each release names exactly which real run is still missing.

⚠️ **Fixed, and the wart is left on the record**: the two counters used to share one `vX.Y.Z` git-tag
namespace, and only the maturity track had GitHub *Release* objects — so the Releases page showed
`v0.3.0` as "Latest" while the shipped package was `2.6.0`. Two layers under one name is a defect this
project keeps finding in its own gates; here it was in its own version numbers. The maturity track now
carries its own `identity-v*` prefix (first such release: `identity-v0.4.0`, 2026-08-21). 🟥 **Not** by also publishing the package
track here — that was tried on 2026-08-21 and reverted the same hour: GitHub gives exactly **one**
"Latest" badge, so two tracks on one page compete for it, and whichever holds it defines what the repo
says it is. Putting the package number there pushed the maturity claim — the honest core — below it.
**The Releases page carries the maturity track; what the package shipped is carried by
[CHANGELOG](plugins/fh-meta/CHANGELOG.md) and the registry.** Existing tags are left alone — renaming them is an irreversible operation on a public surface, and the
[Destructive-Op gate](knowledge/shared/harness-core/claude_md_gate_details.md) applies to us too.

Full rules for what each grade requires:
[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md).

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
harness. **That last step is the goal it is built toward, not a shipped feature** — the incubation
chamber has emitted once, and the run that produced it did not go through the full flow. Read the
simulate-and-emit sentence as direction of travel; everything before it is in use today.

### The five identities — what FH is for

These are not five modules, and they are not five shipped features either. They are the **shapes the
skills clump into** — the name of something that was already there, spread across the skills and agents
rather than layered on top of them. They sit at a different level from the problem table at the top of
this page: that table is *symptoms you might arrive with*, this is *what the hub is organized around*.

| | Identity | What a person gets |
|---|---|---|
| **①** | **Harness cluster** | One task rides several harnesses, and governance is computed *between* them. Its load-bearing sub-mechanism, **cross-harness**: **call** a capability you do not have (rather than build it), and **absorb** the one you should have built |
| **②** | **Project incubator** | A new harness comes out **walking where it was born**, not as an empty scaffold |
| **③** | **Governance gate** | What must not ship is blocked **mechanically**, not by remembering to check |
| **④** | **Frontier → org propagation** | What arrives from outside lands all the way *inside* the organization |
| **⑤** | **Amplifier** | A short intent gets forged all the way to the finished artifact |

**A sixth row is deliberately absent from that table.** `Ⓑ` **Project Booster** — FH's machinery
accelerating *another harness's own development* — is real and graded, and it is **not on the same
layer as the five**. It carries a letter instead of a number for exactly that reason. Each of the
five keeps scope that sits outside boosting: ⑤ covers human intent generally (including work where
no harness is involved at all), ① runs in the opposite direction (FH is the beneficiary), and ②
births units — boosting comes *after* birth. So the relation is not containment.

🟥 **The canon stops there on purpose and does not draw an arrow.** Pinning a hierarchy makes the
table drift from how the work actually runs, where one job rides ① and ⑤ together and the result
flows into ②. Read "different scopes", not "one sits under another". Grades — Ⓑ's included — live
in one file: [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md)
§Ⓑ-layering.

**They are not equally finished, and you should not read the table as five working features.** Maturity is
tracked per identity on a four-step scale — `aspirational → partial → RC (stood up in the lab) → REALIZED
(walked outside)` — with a dated line of evidence for each. Those grades are deliberately **not** copied
here: a grade kept in two files goes stale in one, and this page exists in four languages, so a copy here
would be four copies. Before you rely on any row above, read the current grades — that is one file:
[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md). The short version if you
only want one sentence, as of **2026-08-17**: **①, ③, ⑤ and Ⓑ are graded green — demonstrated outside
the lab; ② and ④ are release candidates — built and calibrated, not yet shown to walk in someone
else's hands.**
If that sentence and the gate file disagree, the gate file is right and this line is stale.

Two properties cut across all five, and neither is a feature you switch on:

- **It rides the frontier instead of patching it.** FH dispatches across families (Claude, Codex, Gemini,
  local) — but the point is *not* papering over each model's weak spots, because that scaffolding dies as
  models improve. It is co-evolution: shed what the substrate now does natively, absorb what it ships
  next. **Decorrelation** is today's trust lever, and it is the load-bearing word on this page:
  deliberately making two checks fail *differently* — a reviewer from another model family, a run against
  a real target, an outside audit of your own record — so that what one is blind to, another is not.
  A cross-family panel beats a single model's ceiling for exactly that reason, not because it is bigger.
- **It evolves in two directions.** *Outward*, each session's lessons compound into the hub so the next
  project starts further along. *Inward*, it catches and repairs **its own** defects — the same gates,
  turned on the harness itself.

The whole thing is a division of labor: **raw capability is the model's; assembly, trust, and evolution
are the harness's.**

---

## How it is built — process → engines → identity

The five identities above are the surface. Two layers sit under them, and naming all three is what keeps
"what FH does" from collapsing into one undifferentiated pile:

```
five identities   what a person can actually use          (surface — what you get)
      ↑ backed by
four engines      the capability that makes it possible   (capability — what it can do)
      ↑ produced by
three-stage       the ORDER those engines are forged in   (process — how it gets made)
  process
      └ stage ③ = the six-axis gate                     (§The six verification axes, below)
```

As a mnemonic: **three-stage process · four engines · five identities · six-axis gate**.
⚠️ But **the six axes are not a fourth layer** — they are *what stage ③ of the three-stage process
consists of*. Read the four as parallel layers and you get back the very "the layers do not land"
problem this section was written to fix.

**The four engines.** Each one is what some identity above is standing on. They were not invented for this
page: the readiness gate had already been scoring every identity against these same four capabilities in a
column of its own ([`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md)), so
naming them was recognition rather than taxonomy-building.

| Engine | What it is | Identities it backs |
|---|---|---|
| `judgment-circuit` | what counts as success, which way to lean under uncertainty, what is out of scope, what never happens | ⑤ Amplifier · ② Incubator |
| `ship-gate` | mechanical blocking before an irreversible surface — commit, publish, delete, rewrite | ③ Governance gate |
| `context-continuity` | not losing the thread across compaction, sub-agents, machines, sessions | ① Cluster · ② Incubator |
| `external-grounding` | reaching outside the repo *before* asserting novelty or settling a design | ④ Frontier → org |

They are written by name, never by number — the table order here and the prose order elsewhere differ, so
"engine ④" decodes to two different engines depending on which you read.

`judgment-circuit` is the one that gets misread most, so state it flatly: **it is a coordinate system for
deciding, not a statement of who the harness is.** The four items in its row are the whole of it. Do not
shorten it to "the harness's soul" in English either — that word reads as *persona*, and the largest
finding of the measurement behind this engine (105 runs, comparing prompts with and without an identity
declaration) was precisely that the two are different things: adding *"you are a ~"* came out a **net loss**
on the weakest model tested, and taking it out recovered ground. A one-word rename re-fuses exactly what
that measurement separated. The figure itself is deliberately not quoted here — the source records it
without a scale, and an unscaled number on a front page is decoration; it is in
[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) with its context. Nor is
a judgment circuit built in one sitting: FH hands a new harness a **seed draft**, and it fills in as that
harness is actually used.

**The three-stage process** — this is an *order of investment*, not a menu:

```mermaid
flowchart TD
  S["① Circuit<br/>before design"]
  P["② Parallel decorrelation<br/>in the middle"]
  B["③ Burn it down<br/>on six axes"]
  A(["⟹ It accelerates"])
  S --> P --> B --> A
  style A fill:#0f766e,stroke:#0f766e,color:#fff
```

**Speed is the arrow at the end, not a fourth box.** And ② is **two dials, turned separately** —
*decorrelation* (reacts to blind-spot risk: a different model family ⓐ, a different standpoint ⓑ)
and *parallelism* (reacts to surface size: can one context hold it?). Do not multiply them, choose.

```
① Circuit before design   the judgment circuit goes in FIRST — success · leaning · out-of-scope ·
                          never-do — not written up afterwards as a record of what you did

② Parallel decorrelation  split the work into checks that fail DIFFERENTLY and run them at once.
   middle, to accelerate  Choose which differences matter — a second reviewer of the same kind is
                          not decorrelation, it is the same blind spot twice. Parallelism has no
                          direction of its own; the judgment circuit from ① is what picks.
                          This is a way of WORKING, not the end-of-line check in ③.

③ Burn it down at the     the six axes below. Adversarial review is ONE of them, not all of them —
   end, on six axes       adversariality is a **posture**, not an axis. It can ride on any axis, and
                          riding it does not make that axis see what it cannot see
```

> 📖 **From here down is for whoever wants to go further — it is not needed to start using this.**
> If you came to install it and get going, the two-minute section at the top is the whole job; you can
> stop here and come back when a check surprises you. What follows is the reasoning behind the gates,
> written for someone already running the hub. Unfamiliar words →
> [`GLOSSARY.md`](knowledge/shared/GLOSSARY.md).

**The six verification axes** — where "we reviewed it" usually turns out to mean only the first of them.

🟥 **Axes are not divided by *how adversarial* they are. They are divided by *what they were given*.**
Hand two reviewers the same input and **the same blind spot survives**, however many of them you add.
That is why the column that matters most below is *what it gets*:

| Axis | **What it gets** | What it catches | Typical instrument |
|---|---|---|---|
| **ⓐ Different family** | the diff + the author's framing | the **implementation** is wrong | a reviewer from another model family (`auto-decorrelation`) |
| **ⓑ Standpoint** | the diff + **the target harness's own canon** | **whether the rule you cited actually says that** | run the diff from that harness's own repo and rules ([`§7`](knowledge/shared/harness-core/field_verdict_crossfamily_gate.md)) |
| **ⓒ Isolated grounding** | the sentences the author wrote — their claims *and* what they **declared before starting** — + the tree as it stands now | the **claim** is wrong · the delta does not match what was declared | someone who did not write it re-measures what it says; for the pre-declaration, a gate that reads the stated success definition back against the delta |
| **ⓓ Third-party encounter** | the problem + **someone else's codebase** | **is this already solved** · where your change touches someone else's repo | look at the same problem in an unrelated third repo |
| **ⓔ First real use** | one real target | the **way you are measuring** is wrong — the instrument's instrument | run it once against one real target and check the result by hand |
| **ⓕ Revert and observe** | the tree with the wiring deleted | the **anchor** is wrong — the check is decorative | delete the thing it guards and confirm *that specific* check goes red |

> **ⓒ widened on 2026-08-21, and how it widened is the more useful part.** Every commit marker in
> this repo has been required since 2026-08-09 to carry the author's own pre-declaration — *what
> counts as success* and *what I will not do* — written before designing. Measured with a control
> that day: **nothing read it.** Zero lines of consuming code anywhere, while the sibling fields
> were checked in 21 places; the gate spec did not even name it. On the real corpus, **37 of 98
> markers carried no such line at all** — including a panel-reviewed one with 28 lanes and every
> other field filled. The axes all looked *outward* (the diff, the target repo, prior art, the
> artifact); none looked at the record's own mandatory field. A slot with no consumer always
> reports "done", because presence is doing the judging.
>
> The fix was not a seventh axis. ⓒ already receives *the sentences the author wrote plus the tree
> as it stands* — which is, word for word, what a pre-declaration check receives. Tense (declared
> beforehand vs claimed afterwards) is a **posture**, like adversariality, not an axis. Minting a
> new one would have repeated the exact error the blind reclassification above found.

> **A peer session counts on ⓑ and ⓓ — decided 2026-08-21, and *which* peer you ask is the whole
> trick.** A parallel session of this same harness, running hot on a different branch of the work, is
> not a copy of you. At the point it got hot it has genuinely grown a second face: a real standpoint
> (ⓑ) and a real someone-else's-codebase (ⓓ). So peer findings are recorded on those two axes — no
> seventh axis was minted, and the marker's `axes-run` alphabet did not change.
>
> This is why the ⓓ row above says *someone else's codebase* rather than *another company's repo*:
> the boundary that matters is **whose working context produced the judgment**, not whose GitHub org
> owns the files. A peer hot on a different branch is across that boundary; a subagent you spawned
> from this context is not, however different the repo it reads.
>
> 🟥 The corollary is the part that bites. **Ask the peer about the axis it actually got hot on.**
> Anywhere else it wears your face and decorrelates nothing — same input, same blind spot. And a
> subagent cannot stand in for it, nor can re-reading your own work: the second face comes from that
> session having *done* different work, and a prompt cannot manufacture it.

**You do not run all six every time, and that is the design** — do not multiply them, **choose**:

```
one-line fix (typo · gitignore)     nothing burns. Not even ①'s circuit — when there is one answer,
                                    planting one is overhead
ordinary code change (reversible)   ⓔ first real use + ⓕ revert
verdict · gate code                 + ⓐ different family — verdict logic is what a reviewer who
                                    shares the author's optimism misses **structurally**
change that touches another         + ⓑ standpoint — bolt on three families and if all three eat
harness                             your framing, nobody asks "does that canon actually say so"
very large · irreversible           + ⓒ isolation + ⓓ third-party encounter. Burn all of it
```

⚠️ **ⓓ third-party encounter is the most expensive and has the smallest unique yield.** And yet that
handful were all of the **boundary-crossing** kind (a rule someone else had already retired · someone
else's repo importing your file). On small, reversible changes such items simply **do not arise**; on
large irreversible ones those two are exactly what becomes an incident. That is where the cost earns
itself.

**Why this is not superseded by base-model advances** — an axis is defined by its **input**, not by the
*reviewer's ability*. A stronger model still **cannot see information it was not given.** Scaffolding
sheds as models improve, but **input-boundary decorrelation does not**, and a single author cannot, by
definition, step outside their own input.

🟥 **Honest edge**: if the agent **fetches more input by itself with tools**, the boundary blurs — an outside judgment held that "the store is never used in full" and
"the swallowed exception" are catchable by ⓐ and ⓒ as well, since those reviewers grep for themselves.
Conversely, "a rule another repo retired long ago" **cannot be fetched by any tool** — there is no reason
to have access to that project's review history in the first place. That is where ⓓ remains.

**Where a rule lives — and why the always-loaded layer does not have to grow forever.**

A harness learns by writing rules down. The obvious place is the always-loaded file every session
reads, and that file only ever gets longer. Left there, the reasoning ends in a corner: *a harness
that keeps learning keeps getting more expensive to start.*

It does not, because a rule has **three possible seats**, and the right one is decided by **when the
rule has to fire**:

| Seat | Fires | Costs | Fits |
|---|---|---|---|
| **Always-loaded** | before you act | every session, every turn | rules whose trigger is an *intention* — tone, "don't normalize the unfamiliar", "prove the instrument works here". Nothing can hook an intention, so salience is the only layer |
| **The gate's own error message** | at the moment you act | **nothing** | rules whose trigger is an *action*. The message that blocks you also teaches the form: `Write, before the design: success = «…». never = «…».` |
| **The hook** | after you act | nothing | properties of a record — present · typed · attributable · non-vacuous |

The middle seat is the one that usually goes unused, and it is free. It is
[gate-locality](knowledge/shared/harness-core/gate_locality_principle.md) applied to salience: the actor reads it exactly where the
action happens, so it does not have to be carried all session to be there when needed.

🟥 **It is a third layer, not a replacement — and the honest limit is that it only fires on failure.**
Someone who gets it right never sees it. So mechanizing a rule does **not** shrink the resident layer:
measured on the very change described above, the machine grew by 480 lines and the always-loaded prose
by **zero**, and that is correct. The prose has to reach the author *before* they design; the hook
catches its absence *after*. A backstop cannot substitute for salience that must fire earlier.

⚠️ And the threshold that would tell you the resident layer is "too big" is, in this repo, **not
grounded** — the numbers in our own doctor skill were introduced without a single line justifying the
cutpoints, and one of them was set to a value the target already exceeded on the day it landed. We are
re-deriving them rather than trimming toward a number nobody can defend. Cutting resident text toward
an unjustified target buys fail-open with the savings.

> 🟥 **Limits to read before citing this**: the six-axis table is **n=1** (one artifact · one session ·
> one author). Whether the axes' non-overlap is structural or an accident of that day is **unmeasured**.
> And when the author's self-scoring was stripped out — 16 findings handed, **with their provenance
> removed**, to two classifiers from other families for blind judgment — **3 of the 5** the author had
> attributed to ⓓ were judged to belong to a different axis; those three were not "what the axis was
> needed for" but "what another axis missed". Discount the table's attributions accordingly.

> **Honest note — this is not a clean stack, and that is the point.** Stage ① and stage ③ are made of the
> same material as the engines, so the lower layer uses the upper one. The contradiction resolves on
> *subject*: the **engines** are what FH applies to your work, while the **process** is the order FH uses
> when forging its own engines. If the method had been borrowed from outside it would be unrelated to the
> engines; the overlap is the fingerprint of dogfooding. Full canon, including the sample limits behind
> each claim: [`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md).

> **Self-healing here isn't a claim — check it.** `git log` in this repo is the record, and the shape
> repeats: a miss is caught, the fix is attacked, and the attack often lands on the fix rather than on the
> original. One you can open by hash — `cb74ea4`, where a register-consistency rule was added to
> `CLAUDE.md §Voice/Tone` after the harness drifted register mid-session. A second, in the same change
> that added this section: a checker whose whole job is finding tests nothing runs was caught reporting a
> green count off a script's *own comment*, and then the guard written to fix that turned out to have no
> test that would fail if it were deleted — found by a different model family, not by the author, and
> closed with a fixture that does fail. Commit hashes on feature branches do not survive squash-merge, so
> that one is cited by its shape rather than by an ID that would rot.

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

## The forge — where the name comes from

forge-harness treats a project like steel, and the metaphor is literal, not decoration. Work is shaped,
hardened by attack, and only then does it ship faster, for having survived.

> 🟥 **Not a fifth numbered set — it is the three-stage process said in the smith's words.**
> An earlier version of this section said the smith's vocabulary *"lines up with nothing"* above.
> That was wrong, and the two diagrams gave it away: both are three steps and an arrow into
> **⟹ accelerate**. They were already the same shape; only the naming was kept apart. So this is
> **one layer told twice**, not a second layer — the four engines, the four-axis commit gate and the
> six verification axes remain different counts and still do not line up here.

**Three at the anvil — and each is a stage of the three-stage process:**

| The smith's word | The stage | What it means here | The commands |
|---|---|---|---|
| **Forge** | ① **Plant the circuit** | shape the raw project into a harness, and settle *what counts as success / what it will never do* — **before** the design | `install-wizard` · `deep-clarify` · the marker's mandatory `①영혼` line (enforced at commit) |
| **Quench** | ② **Parallel decorrelation** | cool it fast: many attempts in parallel, from decorrelated angles. It hardens quickly — 🟥 **and it makes the asset brittle**, which is exactly what quenching does to steel | `auto-decorrelation` · `agent-composer` · `meta-prompt-builder` · cross-family sidecars (codex · agy · gemini) · isolated worktree lanes |
| **Temper** | ③ **Burn it on six axes** | reheat and draw the brittleness back out while keeping the hardness — this is where the attacking passes actually belong | `steel-quench` · `phantom-quench` · `sim-conductor` · `prompt-regression` · `verify-bidirectional` · `fh-meta:challenger` · revert probes · `templates/temper_check.sh` |

> ⚠️ **The skill names carry the older reading and are kept as they are.** `steel-quench` and
> `phantom-quench` say *quench*, but what they do — attacking a hardened asset until the brittleness
> shows — is **temper**. Renaming shipped skills to fix a metaphor would be the more expensive lie;
> the names stay and the roles are stated correctly here.

```mermaid
flowchart TD
  F["Forge<br/>① circuit"] --> Q["Quench<br/>② parallel"] --> T["Temper<br/>③ six axes"] --> A(["⟹ Accelerate"])
  style A fill:#0f766e,stroke:#0f766e,color:#fff
```

**⟹ And then it accelerates.** A blade that survived the forge cuts faster — `goal-quench`,
*Pass → Accelerate*. Speed is what the three above **produce**; it is not a fourth thing you do.
That is the same sentence as the tagline at the top of this page, said in the smith's words:
quality is the lever, speed is the result.

Every command named above ships today. Temper was named before it was built — deliberately (see
[`ETHOS.md`](docs/ETHOS.md#the-forge)) — and shipped once measurement runs validated it.

Around the forge, two more signatures keep it running: `harvest-loop` (each session's lessons become
permanent skills) and `agent-composer` (orchestrate the dispatch). The other skills wait until you need
them — full list below.

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
| `auto-decorrelation` | Recruits a different-model-family reviewer for load-bearing changes | "Decorrelate this verification" |
| `video-ingest` | Video → agent context, routed by capability and length | "What does this video show?" |
| `fh` | Renders the hub map on demand, without a greeting | "fh" |
| *(+ remaining skills)* | marketplace-gate · contention-layer · deliberation · edit-manifest · goal-quench · install-doctor · memory-hygiene · prompt-regression · public-surface-audit · return-path-gate · salience-splitter | |
| **8 agents** | `challenger` · `quench-challenger` (adversarial) · `beginner` · `main-player` · `expert` (the user-mastery spectrum — cold read, daily use, domain authority) · `fact-checker` · `hub-persona-auditor` · `persona-innovator` | dispatched by the skills above, or by name |

| Active count | Diagnosis |
|:---:|---|
| **~half the surface or more** | Advanced — chain agent-composer + sim-conductor + steel-quench + pipeline-conductor |
| **a handful up to that** | Activation stage — gradually enable unchecked assets |
| **almost none** | Early stage — start with `install-wizard` |

> These bands are a rough self-check, not a measurement — no artifact defines the thresholds, and the
> earlier fixed numbers were calibrated against a smaller roster, so they quietly drifted as the roster
> grew. Using more skills is also not the goal; using the ones your work actually needs is.

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

**Why default Sonnet now works**: measured (see *Measured, not asserted* below), *operating* FH is
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
near model-flat — on a 30-point blind battery (2026-06-10) the four tiers run scored **94–100%**
(top-tier anchor / Opus 4.8 / Sonnet 4.6 / Haiku 4.5 = 100 / 100 / 97 / 94), and a 2026-07-03
replication re-anchored Opus 4.8, **Sonnet 5** and Haiku 4.5 at 16/16 each. Two honesty notes rather
than one round number: the source artifact deliberately leaves the top tier unnamed, so this page does
not name it either; and the **current** top tier has not been run on this battery — the doctrine below
is what carries forward, not the scores. The few lost points are format discipline, never a trap or
gate-class miss. The tiers
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
> - **cs.SE companion — governance-gate methodology** · **published** [Zenodo](https://zenodo.org/records/20680081) (DOI 10.5281/zenodo.20680081 · latest v1.1 10.5281/zenodo.20740038 · CC-BY-4.0) · arXiv submitted (cs.SE); the moderation outcome is not tracked in this repo, so treat "submitted" as the last state this page can vouch for, not as current.
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
