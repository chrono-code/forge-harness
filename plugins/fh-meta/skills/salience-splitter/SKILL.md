---
name: salience-splitter
description: 'Splits an over-loaded always-loaded context asset — a SKILL.md, CLAUDE.md, or memory index — into a lean always-loaded layer + an on-demand layer, using a governance-semantic criterion (not length, but when the content is needed), connected by imperative pointers. Based on paper §9.5 Protocol-Priority Split pattern. Diagnoses, classifies, splits, and verifies in one pass. Renamed from skill-splitter (old name still routes here). Triggers: "SKILL.md too large", "split this skill", "skill is bloated", "skill file too long", "CLAUDE.md 너무 커".'
user-invocable: true
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
model: sonnet
---

# salience-splitter — Governance-Semantic Context Split

> **Renamed from `skill-splitter` (2026-07-05).** Old-name references still route here. The rename reflects
> the generalized scope: the split criterion applies to **any always-loaded context asset** — a SKILL.md,
> a CLAUDE.md, or a memory index — not only skills. The label now names the substance (salience-tiering of
> always-loaded context), not one instance of it. Dogfood: applied to a memory index 2026-07-05.

> An always-loaded asset that holds everything in one layer is not simple — it is unscoped.
> The goal is a lean always-loaded layer + an on-demand layer, not one file and its appendix.

**Scope (all three share one criterion — salience: what must be in attention every load):**
- **SKILL.md** → always-loaded SKILL.md + on-demand `SKILL_detail.md`
- **CLAUDE.md** → lean rules + on-demand detail docs (imperative `> **Detail**: See …` pointers)
- **memory index** → hot `MEMORY.md` + on-demand `MEMORY_archive.md` (cold/closed/superseded entries)

## Trigger Phrases

| Phrase | Situation |
|---|---|
| "this skill is getting too long", "trim the skill", "split this SKILL.md" | Direct split request |
| "context-doctor flagged this skill", "SKILL.md is bloated" | Post-diagnosis split |
| "I can't see the key parts", "too much detail in the skill file" | Readability problem |
| "separate the bash from the logic", "move the templates out" | Structural refactor request |
| `/salience-splitter` | Explicit invocation |

---

## Core Principle — Governance-Semantic Criterion

**The split criterion is NOT length. It is: when does this content need to be in memory?**

| Layer | When needed | Examples |
|---|---|---|
| **SKILL.md (always-loaded)** | Every invocation — session boundaries, trigger recognition, step overview, decision tables | Triggers, principles, step names + criteria, key decision tables, Done When |
| **SKILL_detail.md (on-demand)** | Only when executing a specific step | Bash scripts, format templates, edge cases, step-by-step execution detail |

**Behavioral rules stay in SKILL.md** — if a rule governs *what counts* (e.g. "these patterns = closed"), it is behavioral logic and must be always-loaded regardless of length.

**One test**: *"If a consumer agent had only SKILL.md, could they recognize the trigger, understand the full step sequence, and make the key decisions?"* → Yes = correct split. No = something behavioral is missing from SKILL.md.

---

## Step Overview

```
Step 1 — Diagnose
    Read target SKILL.md → classify every section as Always / On-demand / Ambiguous
    → Produce classification table

Step 2 — Draft SKILL.md (trimmed)
    Keep: triggers · principles · step names + one-line criteria · decision tables · Done When
    Remove: bash scripts · format templates · multi-step execution detail · edge case catalogs
    Add: imperative pointer for each removed section → SKILL_detail.md §SectionName

Step 3 — Draft SKILL_detail.md
    One ## §SectionName header per pointer in SKILL.md
    Move removed content under its section
    Front-matter: name, description, load: on-demand

Step 4 — Verify
    phantom-quench: every §pointer in SKILL.md resolves to ## §SectionName in SKILL_detail.md
    sim-conductor Area D-skill: consumer agent with SKILL.md only → must reach grade F
    → Any pointer mismatch or grade P/B → fix before commit
```

> **Detail**: See `SKILL_detail.md §Verification-Checklist` — pre-commit checklist table (8 checks) — read when running Step 4 verification.

> **Detail**: See `SKILL_detail.md §Split-Execution` — step-by-step trimming procedure, SKILL_detail.md front-matter format, orphan-section check — read when executing Steps 2–3.

> **Detail**: See `SKILL_detail.md §Classification` — ambiguous content decision algorithm, behavioral-vs-implementation test, 12 annotated examples — read when unsure which layer a section belongs to.

---

## Imperative Pointer Format (required)

Pointers must be **imperative** (not advisory). The difference:

| Form | Risk |
|---|---|
| Advisory: `"see SKILL_detail.md for details"` | Consumer agent may skip |
| **Imperative**: `"> **Detail**: See \`SKILL_detail.md §<SectionName>\` — [what's there] — read when [specific condition]."` | Consumer agent loads on trigger |

Every removed section must have exactly one imperative pointer at the point of removal in SKILL.md.

> **Detail**: See `SKILL_detail.md §Pointers` — pointer format variants, multi-pointer blocks, pointer placement rules — read when writing pointers.

---

## Target Selection

Run on a SKILL.md when **any one** of:
- context-doctor flags the file as oversized
- SKILL.md exceeds ~300 lines
- sim-conductor Area D-skill grades P or B (cold-start fails)
- Consumer agent reports "could not proceed — too much detail before step 1"

**Not a target**: SKILL.md that has no bash scripts, format templates, or multi-step execution detail. Splitting a file with only behavioral content adds structure without governance value.

---

## Connected Skills

| Situation | Skill |
|---|---|
| Diagnose which SKILL.md files are candidates | `/context-doctor` or `/harness-doctor` |
| Verify §pointer grounding after split | `/phantom-quench` |
| Verify cold-start still works after split | `/sim-conductor D skill <name>` |
| Check new SKILL_detail.md for phantom claims | `/phantom-quench` |
| Adversarial review of the split result | `/steel-quench` |

---

## Done When

```
Step 1 classification table produced
+ SKILL.md trimmed: triggers · principles · step overview · decision tables · Done When retained
+ SKILL.md has imperative pointer for every removed section (> **Detail**: See SKILL_detail.md §<X>)
+ SKILL_detail.md created: ## §SectionName header for every pointer in SKILL.md
+ phantom-quench: 0 phantoms (all §pointers resolve)
  → Fallback (skill unavailable): run §Verification-Checklist manually from SKILL_detail.md
+ sim-conductor Area D-skill: grade F (consumer completes core task from SKILL.md alone)
  → Fallback (skill unavailable): manually confirm "trigger → step overview → key decision → Done When" all present in SKILL.md
```

**Not done**: SKILL_detail.md has a §section with no pointer from SKILL.md (orphan section).
**Not done**: Consumer agent grade P/B after split — a behavioral rule was moved to SKILL_detail.md when it should have stayed.
**Not done**: Any behavioral rule present only in SKILL_detail.md.
