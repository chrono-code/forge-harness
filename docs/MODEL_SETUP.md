# Model setup — which model to run FH on, and why the default is the mid tier

> Canonical home for FH's model doctrine. The two **structural laws** below are the part other
> documents cite — `docs/OUTPUT_EVIDENCE.md` §Validation signals references them by name.
> `README.md` §Model setup still carries its own copy; this file supersedes it, and that section
> is scheduled to be replaced by a link here.

Claude Code does not auto-select models by task complexity — you configure this once.

```bash
/model sonnet   # recommended default — FH dispatches stronger models itself where they matter
```

| Command | Who runs what | Best for |
|---|---|---|
| `/model sonnet` | Sonnet session; FH dispatches higher-tier sub-agents on declared floors | **FH default** — operation + routine dev |
| `/model opus` | Opus handles everything | Harness-editing sessions (Mode D) · maximum depth on every turn |
| `/model opusplan` | Opus *plans* · Sonnet executes *(when Opus engages)* | Cost-conscious routine coding — see caveat |

## Why default Sonnet now works

Measured (see *Measured, not asserted* below), *operating* FH is nearly model-flat — the rules in
context do most of the work. What still needs a stronger model is a small set of depth-sensitive
turns, and FH handles those itself: **some skills and agents declare a model-tier floor** (e.g.
`quench-challenger` floors at opus) and are dispatched as sub-agents at the floor tier when your
environment can reach it — your session model stays untouched. **FH never switches your session
model**: a default you set by hand is followed; floors apply only to FH's own sub-agent dispatches.
If your environment tops out below a floor (e.g. Sonnet-only API routing), the floored asset still
runs at the best available tier with an explicit `below-floor` flag in its output — degraded delivery
is visible, never silent (tier-floor resolution:
`knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Tier-floor`).

## `opusplan` caveat (measured)

Its Opus engagement is **not guaranteed** — in a measured 10-turn run it used Opus on **0** turns
(CC classifies few turns as "plan-mode"). If you want Opus on every turn, pin `/model opus` (22/22
turns Opus in the follow-up run). **Sub-agent dispatch** model is set by the dispatch's own `model`
parameter; the session model / plan-mode does **not** propagate to sub-agents.

> **By role**: running FH (field projects, gates, routine dev) → `/model sonnet` + let the floors
> escalate. Editing the harness itself (Mode D) → pin the strongest model you have — harness
> *self-development* is where tier depth measurably pays (design-increment finding), while operation
> does not. Sub-agent token costs are CC-visible in the session jsonl under `message.model`.

## Measured, not asserted (worked examples)

On a blind rule-application battery, *operating* FH is near model-flat — on a 30-point blind battery
(2026-06-10) the four tiers run scored **94–100%** (top-tier anchor / Opus 4.8 / Sonnet 4.6 /
Haiku 4.5 = 100 / 100 / 97 / 94), and a 2026-07-03 replication re-anchored Opus 4.8, **Sonnet 5** and
Haiku 4.5 at 16/16 each. Two honesty notes rather than one round number: the source artifact
deliberately leaves the top tier unnamed, so this page does not name it either; and the **current**
top tier has not been run on this battery — the doctrine below is what carries forward, not the
scores. The few lost points are format discipline, never a trap or gate-class miss. The tiers
separate only on above-rubric *design* increments (developing the harness, not running it) — which is
why the default is Sonnet with **tier-floored dispatch** covering the depth-sensitive turns, and a
pinned stronger model is recommended only for harness-editing sessions.

## The two structural laws

This is stated as an **invariant, not a per-model leaderboard**. Two structural laws, neither of which
a new release overturns:

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
— that is guaranteed by design. Details + dated runs: [`OUTPUT_EVIDENCE.md`](OUTPUT_EVIDENCE.md)
§Validation signals.

If you use external CLIs (Gemini, Codex, `gh copilot`) as sidecars, their costs are billed to their own
quota and not visible in CC's token display.

## Hardware tiers (local sidecars are optional accelerators)

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

## Multi-model sidecar

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

Full doctrine: `knowledge/shared/harness-core/multi_model_sidecar_strategy.md`.
