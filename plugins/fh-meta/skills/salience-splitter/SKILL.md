---
name: salience-splitter
description: 'Splits an over-loaded always-loaded context asset — a SKILL.md, CLAUDE.md, or memory index — into a lean always-loaded layer + an on-demand layer, using a governance-semantic criterion (not length, but when the content is needed), connected by imperative pointers. Based on paper §9.5 Protocol-Priority Split pattern. Diagnoses, classifies, splits, and verifies in one pass. Renamed from skill-splitter (old name still routes here). Triggers: "SKILL.md too large", "split this skill", "skill is bloated", "skill file too long", "CLAUDE.md 너무 커".'
user-invocable: true
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Agent"]
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

### Two floors this skill must not cross (behavioral — resident on purpose)

**① A cut is measured, never eyeballed** — and *which* measurement depends on what layer you are
cutting from. Both branches forbid the same thing ("I read it and it looks redundant" is not a
measurement); they differ in cost because the surfaces differ:

| Cutting from | Measurement | Why this one |
|---|---|---|
| **Resident layer** — CLAUDE.md, a memory index (loaded every session, for every task) | **Ablation harness**: pre-registered question set · **isolated arm B** · `reps>=3` · runner precondition `bash scripts/ablation_calibrate.sh` exits 0 (canon = `scripts/probe_scope_check.sh` header) · verdict line → `.claude/regression/ablation_verdicts.md` | A wrong cut here degrades *every* session silently, and the cost is unattributable after the fact |
| **SKILL.md → SKILL_detail.md** (loaded only when the skill is invoked) | **Cold-start sim**: `sim-conductor` Area D-skill on SKILL.md alone must reach grade F (see Done When) | The failure is scoped to one skill's invocation and the sim reproduces exactly that condition |

🟥 **ON A CONSUMER INSTALL THE RESIDENT ROW CANNOT BE RUN — say so rather than let a reader
discover it.** `ablation_calibrate.sh` and `probe_scope_check.sh` are **deliberately not shipped**
(`package_coverage_check.sh` ACCEPTED_ABSENT): the procedure ablates *this hub's* resident
`CLAUDE.md`, so an installer has nothing to point it at, and every run spends `claude` CLI calls on
their account. So on an install:

| | |
|---|---|
| **Hub (this repo)** | Run the ablation. Verdict → `.claude/regression/ablation_verdicts.md`. |
| **Consumer install** | The harness is absent, so the measurement is **unavailable — not waived**. The floor holds in its degraded form: **KEEP is the default and a CUT is not available.** Record `UNMEASURED — no ablation runner on this install`; do not record a PASS. |

**The degrade direction is the whole point**: an unavailable measurement makes cutting *harder*,
never easier. A consumer who wants the resident row runs it against their own resident asset by
copying the two scripts out of the hub — that is a deliberate act, not a default. Concretely, that
means taking `scripts/ablation_calibrate.sh` and `scripts/probe_scope_check.sh` from the hub repo,
running the calibrator until it exits 0 **on your machine** (it is a known-pair, not a formality —
it is what proves the runner discriminates at all), and pointing the arms at YOUR resident file
rather than the hub's. The verdict lands in your own `.claude/regression/ablation_verdicts.md`.
🟡 **Named gap, surfaced by a blind floor-tier read of this very section (2026-08-27)**: two
questions this skill does not answer, and pretending otherwise would be worse than saying so —
(i) whether a section may ever be deleted OUTRIGHT rather than trimmed-with-a-pointer (every path
here assumes the pointer), and (ii) whether *verified* duplication — two files grep-confirmed to
carry the same text — is still subject to the full ablation, or whether that is the one case where
"redundant" is a measurement rather than an impression. Both are open; treat them as KEEP until
decided.

**Arm B answering confidently wrong is a KEEP, not a pass** — fluency is not recall, and that is the
whole reason the arm is isolated. The same reading applies to the sim: a consumer that improvises
plausibly without the moved rule is grade P, not F.

This skill is the one that executes resident removal, so the procedure is named *here* rather than
assumed — an earlier version left the judgment "mentally", which is exactly the eyeball path both
branches exist to replace. **Do not read the resident row onto the SKILL.md row**: requiring a full
ablation for every ambiguous SKILL.md section would price routine splitting out of existence, which
is how a floor turns into a bypass trainer (cross-family review 2026-08-11 flagged exactly that
over-block in the first draft of this section).

**② Every split must re-ask whether the destination is inside the gate.** Moving content to a new
path can move it **out of the 4-axis gate's pathspec** — the gate-locality class has recurred four
times, most sharply when `SKILL_detail.md` fell outside a literal `SKILL\.md` term and 27.7% of the
skill-spec surface went ungated (it leaked twice for real). `.claude/rules/fh_4axis_gate.md` names
*this skill* as the producer that **widens that hole every time the diet succeeds**. So coverage is
re-verified mechanically at split time, not assumed:

```bash
bash scripts/gate_pathspec_check.sh    # exit 0 = known-pair coverage holds, 1 = a pair broke
```

A destination path the gate does not match is not a "later" item: **ship the pathspec update in the
same commit as the split** — the split and its coverage are one change, and separating them is how
the surface silently shrinks.

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
    → Gate check (Floor ②): destination path inside the 4-axis pathspec?
      bash scripts/gate_pathspec_check.sh — not-matched = update the pathspec in THIS commit

Step 4 — Verify
    phantom-quench: every §pointer in SKILL.md resolves to ## §SectionName in SKILL_detail.md
    sim-conductor Area D-skill: consumer agent with SKILL.md only → must reach grade F
      (grade scale — sim-conductor SKILL.md §Area-D: F = Functional/PASS · P = Partial · B = Broken)
    → Any pointer mismatch or grade P/B → fix before commit
```

**Step 4 pointer↔header comparison — run it, don't eyeball it.** Both sides need normalizing or the
check produces ~100% false positives: real headers are written `## §Name — description`, so a naive
compare never matches. And extraction must be anchored to the **declared pointer form**
(see "Imperative Pointer Format" below — a blockquote line whose bolded lead is followed by
`See`), not to "a mention of the
detail file": any prose that *discusses* a pointer, quoted or not, is otherwise collected as one.
That is not hypothetical — a paragraph on this page names an example section, and a
backtick-only filter counted it as a live pointer:

```bash
S="plugins/{plugin}/skills/{name}"   # the skill dir being split
# pointer side: any bolded-lead "See" line (the marker word varies — **Detail**, **Template**, …),
# and ALL §names on it (a documented variant puts two pointers on one line)
diff <(grep -E '^> \*\*[A-Za-z]+\*\*: See ' "$S/SKILL.md" \
         | grep -oE '§[A-Za-z0-9_-]+' | sed 's/^§//' | sort -u) \
     <(grep '^## §' "$S/SKILL_detail.md" | sed 's/^## §//; s/ *—.*//' | sort -u)
# rc=0 → every pointer resolves and every §header has a pointer. rc=1 → the diff names both directions
#         ("<" = pointer with no section · ">" = section with no pointer, i.e. an orphan).
```

**Calibrate before trusting it** (this check was wrong twice while being written — each narrowing
looked reasonable and produced false orphans): run it across sibling skills and confirm it
*discriminates*. Measured 2026-08-11 over 6 FH skills: 5 exit 0, `steel-quench` exits 1 on a real
orphan (`§Phase0` — no pointer anywhere in its SKILL.md), and this page's own prose example is not
collected. A version of this check that flags everything, or nothing, is not measuring.

**Orphan check covers `^## `, not `^## §` — and the two checks have different jobs.** The diff above
compares §-prefixed headers against pointers; a header written *without* the `§` prefix is invisible
to it. Measured across this repo's `SKILL_detail.md` files: **139 `## ` headers vs 97 `## §`**, so 42
(30%) sit outside the comparison entirely and would pass forever. So run both, and read them as one
rule:

```
diff (§ side)   → pointer↔header agreement, both directions
grep '^## '     → coverage net: any header the diff could not see
resolution      → give it the § prefix AND a pointer (then the diff covers it), or merge it away
```

A non-§ header listed by the grep and left alone is **not** a pass — it is the orphan the §-only
scan used to hide.

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

**Common to all three scopes** (§Scope declares SKILL.md · CLAUDE.md · memory index — the conditions
below are the ones that hold whatever was split; scope-specific conditions follow):

```
Step 1 classification table produced
  (mandatory-pass — the table exists and every section carries a verdict)
+ Every AMBIGUOUS section carries the measurement its layer requires (Floor ①)
  (measured — resident layer: ablation verdict line in .claude/regression/ablation_verdicts.md
   (pre-registered set, isolated arm B, reps>=3) · SKILL.md layer: cold-start sim grade F.
   Eyeball judgment = NOT met on either branch)
+ Gate coverage re-verified for every destination path introduced by the split
  (mandatory-pass — `bash scripts/gate_pathspec_check.sh` exits 0, or the pathspec update
   ships in the same commit)
+ No behavioral rule lives only in the on-demand layer
  (judged — pair: an isolated consumer read that has ONLY the always-loaded layer and must reach
   a decision the moved rule governs; author re-reading their own split does not satisfy this)
```

**Scope-specific — SKILL.md split:**
```
+ SKILL.md trimmed: triggers · principles · step overview · decision tables · Done When retained
+ Imperative pointer for every removed section; SKILL_detail.md carries one ## §header per pointer
  (mandatory-pass — Step 4 normalized diff exits 0, both directions)
+ phantom-quench: 0 phantoms (all §pointers resolve)
  → Fallback (skill unavailable): run §Verification-Checklist manually from SKILL_detail.md
+ sim-conductor Area D-skill: grade F (consumer completes core task from SKILL.md alone)
  (measured — grade scale, sim-conductor SKILL.md §Area-D: F = Functional/PASS · P = Partial · B = Broken)
  → Fallback (skill unavailable): manually confirm "trigger → step overview → key decision → Done When" present
```

**Scope-specific — CLAUDE.md split:** the resident file keeps the rule *and* an imperative
`> **Detail**: See …` pointer; the detail destination is inside the gate pathspec (Floor ②); a cold
top-level session can still act on the rule without opening the detail file
(judged — pair: a blind sim at the tier the rule must survive on, **not** the author's re-read).
⚠️ Resident-footprint claims are measured only by a **fresh top-level `/context`** — file char counts
are not resident measurements, and an agent-view window cannot measure it at all.

**Scope-specific — memory index split:** every demoted entry is reachable from the archive by the
recall path the index declares (mandatory-pass — grep the archive for the demoted entry's own nouns
and hit it); the hot index keeps one line per surviving entry.

**Not done**: an on-demand section with no pointer from the always-loaded layer (orphan) — scan
`^## `, not `^## §` (30% of real headers carry no §).
**Not done**: consumer grade P (Partial) or B (Broken) after split — a behavioral rule was moved out
when it should have stayed.
**Not done**: a section CUT on "it looked redundant" with no ablation verdict line.
