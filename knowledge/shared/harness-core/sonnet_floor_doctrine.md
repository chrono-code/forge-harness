# Sonnet-Floor Doctrine — the harness's optimization target

> **Canonical axiom node** (operator-declared 2026-07-10). Short by design: this file names the
> invariant, its defect class, and the prescription ladder. The operating mechanics live in their
> existing homes — floor resolution & dispatch: `multi_model_sidecar_strategy.md §Tier-floor`
> (F1/F2, "Sonnet-main + Opus-dispatch"); escalation consent: `capability_escalation_consent.md`;
> mechanical enforcement: `templates/.git-hooks/pre-commit` (Axis-2 floor fields) +
> `scripts/below_floor_scan.sh`. Do not restate their details here; do not restate this axiom there.

## The invariant

**FH's base operation must run 100% at Sonnet-tier.** Every gate, onboarding path, diagnostic,
close-chain step, and skill must fire and complete on Sonnet 5. A capability that is only
discoverable, or only fires, on Opus/Fable-tier is a **harness defect** — the same severity class
as a phantom reference. A harness exists to hold quality high *on weaker models*; if it needs the
strongest model to work at all, it has failed as a harness.

**Escalation is dispatch, never substrate.** Depth beyond Sonnet's ceiling is reached by
*recommending* a dispatch — an Opus/Fable same-family sub-agent, or a cross-family sidecar
(codex / agy) — consent-gated per `capability_escalation_consent.md`. The session substrate stays
whatever the operator chose. A Sonnet-only environment is a **first-class mode**: run everything at
Sonnet, extract the harness's maximum, and name residuals honestly (below-floor / sonnet-floor
markers) — never silently drop a capability.

## Why this is the optimization target (measured, not aspirational)

- **H1 (2026-07-05)**: the anchor-emit harness reduced borderline verdict flips **more on weaker
  models** — Flash −18.5pp vs Pro −11.1pp (within-model deltas, 3-measurement convergence). The
  harness's value peaks exactly where the model is weakest; optimizing FH for the strong tier
  optimizes it where it matters least.
- **Every confirmed Sonnet-tier miss in FH history was closed by mechanization or salience
  hardening, never by requiring a stronger model**: the task-first companion-load miss (2026-07-05
  → SessionStart hook), the tone salience gap (2026-07-08 → recorded, prompt-layer), the
  card-reconcile blind spot (2026-07-10 → mtime-independent STATUS map in the hook). The doctrine
  is a name for what the fix pattern already was.
- **The value does not vanish at the top tier — the harness complements the strongest model too**
  (operator observation, 2026-07-10, same-day measured): a Sonnet blind probe caught a SIGPIPE
  silent-death defect in a script the top-tier session had just written (5/5 repro), and the new
  close-chain checker blocked that same top-tier session's card-last violation twice on its first
  day. Structure-enforcing checks are tier-blind by construction — so the harness raises the floor
  for weak models *and* guards the ceiling for strong ones. Weak-model benefit is the larger term
  (H1), top-tier benefit is the existence proof that the harness is not scaffolding-only.
- **External academic grounding (arXiv:2605.30621, "Harness Updating Is Not Harness Benefit,"
  May 2026 — surfaced via issue #102 Frontier Digest, 2026-08-15)**: the paper separates the
  *evolver* role (writes harness updates) from the *beneficiary* role (runs on the updated
  harness) and finds harness-**updating** flat across model capability — a Qwen3.5-9B evolver
  induces gains comparable to a Claude Opus 4.6 evolver, i.e. evolver strength does not predict
  beneficiary gain. Harness-**benefit**, by contrast, is non-monotonic — and the shape matters, so
  all three tiers are quoted rather than only the one that suits this section: **weak-tier models
  benefit little, mid-tier benefit most, and strong-tier benefit *less* than mid-tier.** The paper
  traces the weak-tier shortfall to two named failure modes: failing to *activate* relevant harness
  artifacts, or activating them but failing to *follow* them faithfully. This is independent
  grounding for the floor split below: sub-Sonnet stays `below-floor` because
  activation/faithful-following is where payoff collapses, while Sonnet is named the floor
  precisely because it clears that bar. ⚠️ **The strong-tier half is NOT folded in as support for
  the ceiling-guard clause above** — the paper measures benefit from *self-evolved harness updates*,
  not from structure-enforcing checks, so mid > strong is an adjacent finding this doctrine has not
  reconciled, and is recorded as open rather than read in the author-favorable direction.

## The defect class: tier-gated capability

When auditing (harness-doctor, weekly audit, or a dedicated census), enumerate candidates with
`bash scripts/tier_census_grep.sh <files>` (word-boundary patterns + N/A-sense hints — mechanized
2026-07-10 after a probe's naive grep false-positived on "fron**tier**"), then classify every hit:

| Class | Shape | Verdict |
|---|---|---|
| **Trust-floor** | a *judgment* (skip/run, compose/rank) is trusted only at opus+; below-floor = run the check anyway or ask | **Compatible** — Sonnet still runs everything; degrade direction is run-or-ask, never skip |
| **Availability-gate** | a capability is *absent, blocked, or dead-ended* below a tier (hard `model:` pin, "cannot pass", opus-only judge path) | **Defect** — fix via the ladder below |
| **Advisory** | recommends a tier, never blocks (Mode D Model Notice, depth-escalation notices) | Compatible — but the recommendation direction must be **dispatch-first** (keep Sonnet + dispatch the depth), with a session pin as the secondary option |

## Prescription ladder (for a confirmed tier-gated capability)

1. **Mechanize** — move the behavior to a hook / script / exit code. Tier-independent by
   construction; the strongest fix. (SessionStart load, STATUS map, pre-commit gate.)
2. **Salience-harden** — split, imperative pointers, turn-0 injection; then verify with a
   **Sonnet blind sim** (the target-tier sim gate's default tier *is* Sonnet for this reason).
3. **Reclassify as dispatch** — if the capability is irreducibly judgment-heavy (adversarial
   depth, wide design synthesis), it becomes a *dispatch surface*: at Sonnet the harness surfaces
   a one-line escalation recommendation (sidecar or floor-up, consent-gated) and proceeds at the
   floor with a named residual. Silent absence is never an option.

## Floor semantics under the doctrine

- **Sonnet = the base floor.** Meeting it is `at-floor` for base operation. Judged-class verdicts
  produced at Sonnet on depth-critical roles remain **provisional** (`sonnet-floor` marker,
  auto-queued for the weekly audit's re-run-or-write-off pass) — first-class ≠ free of residuals.
- **Sub-Sonnet (Haiku, local canaries)** stays `below-floor`: canary/producer roles only, explicit
  ack required on gate surfaces. The doctrine raises no ceiling and lowers no guard rails there.
- **Depth ladder on a depth turn at Sonnet** (cheapest rung first — effort is depth, model is
  ceiling, `[[feedback_workflow_stage_effort_routing]]`): ① **raise reasoning effort on the same
  substrate** (Sonnet medium → high — free, no consent needed, no boundary crossed) → ② dispatch
  an audit/research sidecar (consent permitting — cross-family preferred for decorrelation) →
  ③ proceed at Sonnet-high with mechanical anchors + named residual. A hard model requirement is
  never a rung.

## Autonomy at Sonnet — run-first, ask-last (full-potential clause, 2026-07-10)

The intended FH surface — including its **full autonomous potential** (goal-quench max runs,
harvest-loop full mode, overnight loops, cluster orchestration) — must be *executable* at
Sonnet medium-high effort, not merely available-if-a-human-answers. Two rules make that safe:

- **Trust-floor degrade order is RUN → ASK, never ask-first**: where a judgment is trusted at
  opus+ ("skip/run", "compose/rank"), a Sonnet session's default is to **run the full check /
  present the full result** — the conservative branch that needs no trust. Asking is reserved for
  the case where no mechanical or anchored path exists at all (a pure-judged fork with no anchor).
  A Sonnet loop that stalls on "ask" when running-the-check was available has mis-degraded.
- **The defense is the gate layer, not the model tier**: FH's mechanical floors — pre-commit
  4-axis, pre-push Destructive-Op, prepublish scan, consent protocol, HITL irreversibility floors —
  are tier-independent hooks. They hold *regardless of who is driving*, which is precisely what
  makes Sonnet full-autonomy safe: **autonomy removes the prompt, never the gate** (the same
  clause the Autopilot's full-autonomy mode already carries). Irreversible-surface HITL floors are
  surface-class rules and do not scale down with tier — a Sonnet loop gets the same hard walls,
  not softer ones.

## What survives model evolution — the durable-mechanization criterion (operator insight, 2026-07-10)

Sidecar dispatch is the *cheap* way to chase LLM evolution (swap the engine, keep the harness), and
internal mechanization could chase capability gaps forever — so which mechanization is worth
building? Split by **what the mechanization compensates for**:

| Class | Compensates for | Fate as models improve | Examples |
|---|---|---|---|
| **Capability-compensating** | the model being *weak* — reasoning depth, salience, attention discipline | **evaporates** — scaffolding to shed (`[[feedback_frontier_substrate_self_adaptation]]`); build only on measured misses, keep cheap to delete | salience splits · turn-0 imperatives · word-boundary grep discipline (partially — see note) |
| **Structure-enforcing** | what a *perfect* model still cannot see or is still incentivized to fumble: information outside the context boundary (cross-machine state, version drift), ordering invariants across ephemeral contexts, ship-pressure optimism, irreversible surfaces | **permanent** — model evolution never fixes "the card lives on another machine" or "the runner controls what the hook sees" | STATUS map (machine boundary) · card-last check (ordering invariant) · substrate-jump detector (out-of-context drift) · fail-closed gates · consent floors |

**The test question when proposing mechanization: "would an infinitely strong model still miss
this?"** Yes → structure-enforcing, build it, it compounds. No → capability-compensating, prefer
dispatch first, mechanize only on a measured miss, and tag it shed-eligible (the substrate loop's
shed/advance pass is its consumer).

*Note on determinism*: some capability-class tools survive anyway because they are **cheaper and
deterministic** (a grep never has an attention lapse and costs nothing) — determinism is a second
survival axis, orthogonal to capability. A deterministic check that replaces a per-session judged
step keeps paying even when the model no longer needs the help.

## Done When (for any change citing this doctrine)

- No availability-gate remains in the touched surface *(check class: measured — tier-reference
  census grep, classify per the table)*.
- Salience-dependent changes pass a Sonnet blind sim *(measured — sim verdict recorded in the
  Axes 2–3 marker)*.
- Depth needs express as dispatch recommendations, not requirements *(judged, pair: adversarial
  review asks "where does this silently require opus?")*.

Cross-refs: `[[feedback_tier_invariant_over_treadmill]]` · `[[feedback_harness_aerodynamics_perceived_perf]]`
· `[[feedback_fh_rides_on_cc_harness]]` · `[[feedback_h1_two_tier_closure]]` · `loop_engineering.md`
(PROSE legs are where Sonnet-tier misses live — the two lenses share one spine).
