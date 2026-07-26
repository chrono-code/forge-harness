---
name: multi-persona-review (parallax)
description: Generalized architecture for multi-persona parallel artifact review — parallel isolated personas + shared output protocol + neutral synthesizer. The domain-agnostic, IP-stripped pattern named "parallax" for FH; embodied as sim-conductor Step 1.5. Use when designing or explaining structured multi-viewpoint review (code, spec, design, plan).
type: reference
tags: [pattern, multi-persona, review, parallax, sim-conductor, verify-axis]
---

# Multi-Persona Parallel Review — the `parallax` pattern

> **parallax**: depth — the hidden, the omitted — is only perceivable from multiple viewpoints. One
> standpoint is flat; the shift *between* standpoints reveals what a single seat cannot. The name is the
> thesis: structured multi-standpoint coverage finds categorically more than any one viewpoint.

**Provenance**: generalized and domain-stripped from a field marketplace implementation (`deep-insight`,
a company-internal term — not adopted here). The domain-agnostic *architecture* is portable; the
domain-specific personas were field extensions and are excluded. In FH this pattern is a **mode of
`sim-conductor`** (Step 1.5), not a separate skill — see `asset-placement-gate` verdict (2026-06-06):
it overlaps sim-conductor ~80–90%, so the distinctive patterns were absorbed, not forked.

## The architecture (6 + 1 patterns)

1. **Parallel isolated persona spawn** — N personas run as parallel agents (`Task(subagent_type=…)` /
   parallel Agents), each in its own context, no inter-agent communication. Isolation is mechanical: it
   lets each persona reach an independent verdict, which is what makes cross-persona agreement meaningful.
2. **Shared output protocol (constitution)** — every persona, whatever its lens, emits the same shape:

   ```
   ### Strengths        (0–3, from this persona's viewpoint)
   ### Concerns
     Critical   — compile/runtime failure · clear logic error · data corruption · security leak
     Important  — significant user/service impact in a plausible scenario
     Suggestion — optional improvement
     (each: [file:line or quoted span] one-line summary — rationale)
   ### Open questions   (0–3 needed for a decision)
   ### Absence check    (outside-vantage personas: what does the artifact FAIL to specify that this
                         standpoint needs — discoverability, undocumented contract, unstated assumption?)
   ```
3. **Neutral synthesizer** — a NON-persona aggregator that injects no opinion: never a conclusion no
   persona stated · preserve attribution (who said what) · priority labels verbatim · no forced consensus
   or forced conflict. It reports Common opinions (2+ agree) and Conflicts (A vs B, each with rationale).
4. **Persona taxonomy (group aliases)** — `dev` (fe/be/…), `biz` (pm/designer/…), `review`
   (qa/compliance/devil-advocate), `user` (newcomer/power-user), `all`. Sourced, not hardcoded.
5. **FP judgment discipline** — only escalate when confident. Never escalate: pre-existing issues ·
   style without a quotable rule · linter-catchable · speculative · subjective (→ Suggestion). *If not
   confident, do not mark it* — false positives erode reviewer trust.
6. **Devil's advocate as a structural member** — not a special case; a standard member of `review`. Every
   objection carries a rationale (no contrarianism for its own sake); the faster others converge, the
   harder it hunts the weak point.
7. **External-harness persona sourcing** (FH addition) — a lens may be sourced from an installed *sibling
   harness*, not only the built-in palette: e.g. gstack `/review` (staff-engineer), `/cso`
   (security-officer), `/qa` (QA-lead). The orchestrator runs FH; the sibling supplies the specialist
   lens. Isomorphic to `steel-quench` Step 0.4 (Specialized Reviewer Discovery) + Wave 5 (external CLIs).

## The two-layer severity (why it's required, not redundant)

Per-persona `Critical/Important/Suggestion` (each persona's own judgment in isolation) → synthesizer
triages to `M/S/R` (cross-persona). An isolated persona **cannot** assign `S = found by 3+ personas` —
that depends on agreement it never sees. So the per-persona → synthesized split is *required by isolation*,
not duplicate vocabulary.

## What this pattern's value actually IS (honest, from the R9 experiment arc)

Established by controlled experiment (companion-store `RESULT9`, codex, capability-controlled, 2026-06-06):

- **It is NOT de-biasing.** Ownership had ≈ zero effect (a model self-reviewing blunt = an outsider
  blunt). It is NOT "seeing what the author structurally can't": when explicitly asked, an author finds
  their own omissions about as well as an outsider (clean replication refuted the "non-self-administrable"
  claim).
- **What is real**: the gradient **`blunt < single-rubric < multi-persona`** — structured multi-standpoint
  coverage finds categorically more (a single-flaw prompt missed SSRF; a single rubric missed the
  consumer-contract axis a newcomer surfaces). Different standpoints make different issues *visible*.
- **So the value is**: **pure rubric/standpoint supply + routine enforcement** — the pattern assembles and
  *routinely runs* the structured multi-standpoint rubric (including the omission/absence check) that a
  builder would not assemble or run on themselves. **Fully copyable utility, zero cognitive-moat.**
  Isolation's role is mechanical (independent verdicts → honest cross-persona triage + decorrelation), not
  cognitive.

This framing is falsifiable and matches FH's utility-not-moat positioning: the personas are a copyable
marketplace; the marginal value is making the structured sweep routine, not exclusivity.

## Where it lives in FH

- **Operational home**: `sim-conductor` Step 1.5 (Persona Output Protocol + Neutral Synthesizer). Area D
  (artifact validation) is the focused multi-persona review entry point.
- **Sourcing kinship**: `steel-quench` Step 0.4 + Wave 5 (external reviewer/CLI discovery).
- **6-axis**: a validated pattern for **Axis 5 (Verify)** — structured multi-viewpoint review of a
  near-complete artifact, complementary to steel-quench (adversarial hardening) and phantom-quench
  (source grounding).
