---
title: FH Platform Sustainability — Plan B + Simplification Criteria
type: strategy
date: 2026-05-18
tags: [sustainability, plan-b, simplification-gate, scenario]
---

# FH Platform Sustainability

> **Purpose**: Document how forge-harness survives and evolves in scenarios where the Anthropic official ecosystem expands. Describes simplification gate criteria and meta-harness specification principles together.

---

## 1. FH Survival Strategy Per Anthropic Official Ecosystem Expansion Scenario

As Anthropic develops Claude Code, some FH functions may overlap with default features. This section states FH's differentiation points and survival strategy for each scenario.

### Scenario A: Anthropic official skill marketplace launches

**Risk**: If Anthropic operates an official skill marketplace, FH's plugin distribution function could be replaced.

**FH differentiation**:
- **Organization-specific domain curation**: Generic skills in the official market vs FH's optimized combinations for your organization's specific infrastructure — irreplaceable
- **Organizational context preservation**: `tracks/` session history and `knowledge/` domain knowledge are organization-specific assets — cannot be transferred to the official market
- **Federated market role**: FH becomes a sub-channel (specialized marketplace) of the official market → actually strengthens canonical source positioning

**Strategy**: When official market launches, use `marketplace-gate` skill to select FH assets worth registering in the official market → contribute to the official market in reverse.

---

### Scenario B: Claude Code harness diagnostic features built-in

**Risk**: Features similar to `harness-doctor` and `context-doctor` may be added as Claude Code default features.

**FH differentiation**:
- **Organization context-specific diagnosis**: Default features are generic — FH has organization-specific diagnostic layers (your GHE structure, network policies, etc.)
- **Three-Doctor Loop**: `harness-doctor` + `context-doctor` + `sim-conductor` closed-loop connection is a system, not a single feature — not replaceable by one default feature
- **L4~L5 layers**: Field project connection diagnosis (L4) + skill activity, context fit, and effect indicators (L5) are FH-unique layers

**Strategy**: Delegate L1~L3 that overlap with default features to defaults, and FH focuses on L4·L5 organization-specific layers.

---

### Scenario C: Organization-internal marketplace newly created

**Risk**: If an internal official marketplace is created by your organization's leadership, FH's internal distribution role could be replaced.

**FH differentiation → FH becomes canonical source**:
- FH = the **original input** for the internal marketplace. Verified skills originate from FH → the market is a distribution channel
- `marketplace-gate` skill already performs pre-registration 5-point suitability gate — can naturally integrate with the internal market quality gate
- `field-harvest` feeds field patterns back to FH → plays the role of automatic supply pipeline to the internal market

**Strategy**: When internal marketplace is created, position FH as canonical source. Register FH in the internal market as an official source.

---

### Common principle: Replacement vs Complement judgment criteria

| Judgment criterion | Replaced (delegate) | Complement maintained |
|---|---|---|
| Generic function | Delegate to default feature + remove from FH | — |
| Organization-specific function | — | Maintain in FH + layer on top of default feature |
| Domain knowledge assets (`knowledge/`) | — | FH-unique — irreplaceable |
| Session history (`tracks/`) | — | FH-unique — irreplaceable |
| Cross-project synergy combinations | — | FH-unique combination — not possible with single default feature |

> **Core principle**: FH differentiates through **combination, context, and accumulation** rather than feature competition. As default features get stronger, the value of FH's combination layer grows more.

---

## 2. Simplification Gate Criteria

> **Basis**: "A good harness gets simpler over time. If it's getting more complex, something is wrong." — CLAUDE.md throughline

### Required checks before adding new skills (RULE-AUTO-EXPANSION-GATE)

Every time a new skill addition proposal arises, the following checklist must be passed first.

**Checklist** (check in order):

```
[ ] 1. Is there an existing skill among the current skills that can cover it?
       → If yes: replace with existing skill SKILL.md improvement. No new creation.
       → If no: proceed to next check.

[ ] 2. Did it pass `/asset-placement-gate` 4-criteria judgment?
       → ①(cross-project value) + ④(non-duplicate with existing skills) must pass
       → If not passed: no new creation.

[ ] 3. Has it been demonstrated as a pattern repeated 3+ times in the field?
       → 1-2 time pattern: mark as candidate only + ★ 1 → create properly after 3+ accumulation
       → 3+ time pattern: creation possible.

[ ] 4. Can `/marketplace-gate` Check 1~5 PASS?
       → If FAIL items exist: revise then re-verify.
```

All 4 checks must pass to proceed with creation. **If any one fails, no creation**.

### Existing skill deprecation criteria

`harness-doctor` L5-A INACTIVE_90D judgment = Deprecation Gate entry:

| Status | Criteria | Handling |
|---|---|---|
| INACTIVE_30D | 0 times within 30 days | `/sim-conductor D skill {name}` — trigger phrase verification |
| INACTIVE_90D | 0 times within 90 days | Deprecation Gate — consider deprecation/consolidation |
| Deprecation confirmed | INACTIVE_90D + coverable skill exists | archive + remove corresponding skill SKILL.md |

---

## 3. Meta-Harness Specification Simplification Principle

> **Core proposition**: "The meta-harness gets simpler **within its own specification (meta layer)** — do not evaluate by single project standards."

### Server room vs data center distinction

| Classification | Criteria | Application |
|---|---|---|
| **Server room** (single project) | 200-line CLAUDE.md standard | Single project exceeds 200 lines = M-tier |
| **Data center** (meta-harness) | Meta layer specification standard | **No line/count threshold exists.** `harness-doctor` declares meta CLAUDE.md raw line and section count **"Not a verdict"** and judges by the char-based always-loaded footprint (S > 40k · M > 80k) plus the residency ledger and the doctrine red flags (orphaned · redundant · decorative) |

`harness-doctor` L2 complexity diagnosis automatically applies this separation:
- Scope is decided **mechanically at the TARGET root** (`tracks/` ∧ `knowledge/` ∧ `plugins/` all present = meta),
  never from cwd and never self-declared — a bare cwd test misclassifies every field target as meta
- On a meta target the line-count rows are **disabled outright**, not swapped for a larger number —
  so `harness-doctor` cannot fire an **M-tier** on FH's own CLAUDE.md off a single-project line
  standard. The verdict comes instead from the footprint rows, which apply to both scopes and are
  char-based; those *can* legitimately reach M-tier, and when they do the lever is capability-level
  (merge or retire a governance unit), never "the file is long"

### Meta-harness self-constraint prohibition

Prohibit the pattern of applying external standards (single project complexity standards) to the meta-harness to self-constrain:

- **Prohibited**: "FH has N skills, it's gotten complex → needs to be reduced" (single project standard applied)
- **Allowed**: "Among FH skills, some have 0 invocation records within 90 days → those skills enter Deprecation Gate" (meta layer standard applied)

🟥 **Why this section carries no numbers (2026-08-20).** It used to pin "500-line / 16 skills".
Both went stale (CLAUDE.md is past 1,400 lines; there are 40 skills) and — worse — the 500 was
**contradicted by the skill it claimed to describe**: `harness-doctor` disables the line-count row for
meta targets rather than raising it. That live-but-wrong number is not inert: a run once fabricated
`M-1 · exceeds the FH threshold of 500` and a downstream sidecar reasoned from the invented figure
(recurrence N=2 — `harness-doctor/SKILL.md` §"Every M/S-tier must cite the row it fired"). The skill's
own post-mortem grepped **itself** and found 0 hits, so it concluded the threshold was invented from
nothing — it never grepped the repo, where **this file was the source**. Do not re-pin a number here:
thresholds belong in the skill that measures them, where a citation can be quoted verbatim.

Judgment standard: **If there are no real-use problems, no simplification pressure**. Simplification is solving real-use problems, not reducing complexity.

---

## 4. External Contribution Facilitation Structure (not one-way)

FH aims for a **bidirectional contribution structure**, not one-way distribution.

### Contribution occurrence examples

| Contribution direction | Example | Channel |
|---|---|---|
| FH → field | Skill/agent distribution, session context connection | plugin install, clone |
| Field → FH | Field pattern feedback (`field-harvest`) | PR |
| External → FH | External user contributions, cascade β | External PR / autonomous operation |

### cascade β demonstration

- An external user (not the owner) autonomously operated FH skills → caught and merged a bug in a PR
- Contribution from external project: owner contributed to that project → demonstrated structure where FH facilitates external contributions

**Meaning**: FH looks like a 1-contributor project but it's an **amplifier structure** where contributions to other projects occur through FH.

---

*Reference: `CONTRIBUTING.md` (PR rules) · `plugins/fh-meta/skills/asset-placement-gate/SKILL.md` (new asset judgment) · `plugins/fh-meta/skills/harness-doctor/SKILL.md` (L5 activity check)*
