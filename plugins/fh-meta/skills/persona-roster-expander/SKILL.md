---
name: persona-roster-expander
description: Expands a named persona seed into a tiered, judgment-mapped cast — tiering each persona by a domain safety rule, mapping each to a decision-lens in the user's vocabulary, then proposing additional voices with sourced anchors.
user-invocable: true
allowed-tools: ["Read", "Grep", "WebSearch", "WebFetch", "Write", "Agent"]
model: sonnet
---

# persona-roster-expander

Takes a seed set of named personas and turns it into a usable judgment cast: each persona tiered by a
domain safety rule, mapped to a concrete decision-lens, plus a few proposed additions filling
uncovered lenses with real anchors. An innovator-family skill — generative, but bounded by a
caller-supplied safety rule so the expansion stays faithful to the domain's constraints.

> Origin: harvested from the-bible (2026-06-20) — an operator persona seed (priest/nun/angel/devil/
> God/Jesus/Holy-Spirit/apostles) tiered relay-vs-lens by a relay-safety rule and mapped to
> engineering-judgment lenses, +4 sourced proposals. **The grounds, inline, because the harvest
> record does not ship**: an ungated persona cast drifts into inventing its own authority — a voice
> given a lens will speak past what the domain lets it assert — so tiering by a *caller-supplied*
> rule is what keeps the expansion faithful, and the lens mapping is what makes a named voice
> usable as a decision instrument instead of flavor. Full harvest record — **hub-local, not
> distributed in the npm package**:
> `tracks/_contrib/field_harvest_2026-06-20_gate-locality-and-grounding-capabilities.md`.

## Triggers
- "broaden these personas" / "what other voices fit this cast"
- "map these roles to a decision lens"
- "expand the persona roster and keep it faithful to <rule>"
- `/persona-roster-expander {seed personas + domain + safety rule}`

### Natural Language Triggers (example user phrases)
- "내가 명명한 페르소나 후보군을 더 넓혀줘, 판단 매핑이랑 같이"
- "take these character archetypes and tell me what engineering judgment each one provides"
- "add a few more voices that cover a perspective these don't"

## Steps
1. **Collect the seed + the safety rule** — the named personas, the domain (what decisions they
   reflect on), and the caller-supplied **tiering rule** (the hard constraint that decides what each
   persona is allowed to do). Without an explicit safety rule, ask for one — do not invent authority.
2. **Tier each persona** by the safety rule (e.g. relay/quote-only vs lens/framed-perspective). State
   a one-line justification per persona; the tier caps what the persona may emit.
3. **Map each to a decision-lens** in the **user's domain vocabulary** — what concrete judgment-
   perspective does this voice provide, and when to invoke it. Pair any adversarial voice with a
   constructive counter-voice (no adversary as the last word).
4. **Propose 2–4 additions** filling lenses the seed doesn't cover (delegate net-new *name*
   generation to the `persona-innovator` agent — this skill's distinct value is the tiering +
   lens-mapping, not naming). For the strongest 2–3, find a real anchor (a sourced
   example/reference); **any remaining proposal ships with a literal `stub:` prefix** — unanchored
   and unlabeled is not an allowed output (see Done When).
5. **Emit the tiered, lens-mapped cast** (named + proposed) by **writing it to a structured file**
   the system can load (e.g. `personas.json`), then confirm the written file parses. Leaving the
   cast in the response text only does not complete this step.

## Done When
- **Every persona has a tier + lens label + invoke-condition.** *Check class: mandatory-pass (binary — all three fields present per persona).*
- **Every proposal is either anchored or explicitly labeled a stub.** An anchored proposal names a source/reference that resolves; a proposal without one is emitted with a literal `stub:` prefix and is **not counted as a candidate**. *Check class: mandatory-pass (binary — each proposal carries either a resolving anchor or a `stub:` label; an unanchored, unlabeled proposal is FAIL). Anchor resolution is checked mechanically (fetch/look up the cited reference), not by judgment.* (This is the Done-When floor; Step 4's "strongest 2–3" is the effort target that sits above it — a 4th proposal may ship as `stub:` without violating either.)
- **The cast is materialized as a loadable artifact** (e.g. `personas.json`) that a consumer can parse — the file exists on disk and a parse of it succeeds against the declared schema (per persona: tier / lens / invoke-condition; per proposal additionally `anchor` or `stub:`). *Check class: mandatory-pass (binary — file exists and parses; a cast that exists only in the response text is UNMET).*
- **The tiering respects the caller's safety rule** (no persona exceeds its tier's allowed emission). *Check class: judged, pair: dispatch `fh-meta:challenger` at the tier-escalation angle — "find a persona whose lens mapping lets it emit beyond its tier". The pairing is a **different-agent** read; the author's own re-read does not satisfy it. If that agent is unreachable, record `pair: unavailable (<reason>)` — the condition stays UNMET and is **reported as a named residual**, never self-scored closed. It does **not** block delivery: a roster is a reversible artifact, so the degrade direction here is declare-and-ship, not fail-closed (that direction is reserved for irreversible surfaces — publish, delete, history-rewrite). Shipping with an UNMET pairing is honest; silently marking it met is the defect.*

## Guards
- **Caller-supplied safety rule is mandatory** — the skill tiers by the domain's rule, it does not
  invent one (inventing authority is the failure this guard prevents).
- **Adversary never last** — any devil's-advocate voice is paired with a constructive counter-voice.
- **Anchors must be real** — a proposal without a resolvable anchor is a stub, not a candidate.

## Relationship to `persona-innovator` (agent)
`persona-innovator` *generates* names, frames, and frontier-absorption signals from scratch. This skill
takes an **existing seed** and adds the **tier-by-safety-rule + lens-to-domain mapping** — it is the
*structuring/governance* layer, not the *generator*. When net-new names are needed (Step 4), it
delegates to `persona-innovator` rather than reinventing generation.

## Independently executable
Yes — needs only the seed + rule + (for anchors) web search. Delegates name *generation* to
`persona-innovator` when invoked, but has no hard dependency on it for the core tier+lens mapping.
