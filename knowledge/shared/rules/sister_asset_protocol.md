---
description: Protocol for when a sister asset (another team within the organization, external frontier, another repo) covering the same topic is discovered — blocks cognitive gaps and opens a bidirectional learning loop. Keep the activation threshold low.
---

# Sister Asset Protocol

When a **sister asset** (another team in the organization · external frontier · another repo) covering the same topic is discovered, follow this procedure to block cognitive gaps and open a bidirectional learning loop.

## When to activate

- During work, a **sense of deja vu** arises: "I feel like this topic was covered somewhere"
- An external resource with **similar scope but different resolution** from a `knowledge/shared/` asset is found
- An external reference URL repeatedly appears in the weekly audit scanner aggregation
- User mentions "that other project/team also did this"
- 🟥 **ACTIVE ADOPTION — you went looking for an external asset, installed it, and RAN it** against
  something this hub owns. Added 2026-08-16 because every condition above is **passive discovery**
  ("a resource *is found*"), and the strongest sister signal there is does not look like discovery
  at all: deliberately reaching for an outside tool *because ours did not cover something* is a
  measured resolution difference, not a hunch about one. **Measured miss**: an external red-team
  framework was installed, run against a field harness's safety gate, and found a real bypass — and
  none of it fired this protocol. It was filed in memory as `type: reference`, a **tool pointer**,
  because "a tool I used" was an available and correct-looking category while "sister asset" was a
  category no listed condition named. That is the normalization reflex `CLAUDE.md
  §Envelope-Boundary Discipline` exists to counter, reproduced inside the protocol meant to catch it.
  **The tell**: if you can answer *"what does it do that ours doesn't?"* — you have already done
  step 1's resolution-difference analysis, and owe steps 2–3.

## Lightweight path (C-tier — cheap debt entry)

If step 1 (asset identity) shows the territory is **already covered** — dedup hit on the source, or
a prior cross-audit of the same claims, with no new increment — do **not** write a full cross-audit:
record a **one-paragraph entry** (source · dedup verdict · the one-line increment if any · pointer to
the prior audit) in the ledger/log used for speculative intake. Full steps 2–3 are reserved for
A/B-tier sources (new territory or a real increment). Keeps intake cheap — the discipline that lets
the wide net stay wide.

## 3 steps after detection

1. **Asset identity confirmation (5 min)** — Confirm creation date · author · access scope (internal-public·open-source) · scope in one line. Identify **resolution difference** from the hub's corresponding asset.

2. **Cross-audit session creation** — Record comparison in `tracks/_audit/session_YYYY_MM_DD_{slug}.md`. Minimum contents:
   - Position comparison table of the two assets (perspective · axis basis · conclusion method)
   - Overlap area (value if combined)
   - List of **items to import** from the other side
   - List of **items the hub can propagate**
   - Cognitive gap facts (independent work interval, mutual unaware period)

3. **Cross-reference link insertion judgment** — 1 line at the end of hub asset + 1 line at the head of the other asset. If no write access to the other repo, write a **proposal** (`tracks/_audit/proposal_*.md`) and deliver to the team.

## Prohibited

- **One-way export** — No "we'll teach them" tone. **Publicly list the items to import first** to demonstrate bidirectionality.
- **Instructive proposals to restructure the other asset** — "add section / restructure / insert" verbs risk damaging the relationship. Use provider-humble phrasing.
- **Clone-and-own the other asset** — Do not copy the other repo's asset into the hub. Reference links + session records only.

## Required before distributing proposals externally

Proposals to deliver to the other team are external-facing assets. After **3+ persona × 4-axis** (resonance·confusion·resistance·supplement) audit using `hub-persona-auditor` or similar, accept 3-tier revisions. Do not deliver directly without audit.

## Quarterly sync

Quarterly sync with the latest version of the sister asset recommended (approximately 3-month cycle). Sharing the schedule with the other side makes work timing predictable.

## Real-world value basis

The value of discovering a sister asset is proportional to the **cognitive gap period**. In a case where two teams in the same organization independently worked on the same topic 4 days apart, simply having cross-links would have multiplied the combined value. Keeping the protocol activation threshold low is the safe choice.
