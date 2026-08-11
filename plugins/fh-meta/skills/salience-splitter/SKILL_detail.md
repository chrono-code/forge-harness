---
name: salience-splitter-detail
description: Detail reference for salience-splitter — content classification algorithm, pointer format variants, verification checklist. Load when executing a specific step.
load: on-demand
---

# salience-splitter — Detail Reference

> Load when executing a specific step. SKILL.md contains the core principle, step overview, pointer format requirement, and Done When.

---

## §Classification — Content Classification Algorithm

### Decision algorithm (per section)

```
For each section in target SKILL.md:

1. Is this content needed to RECOGNIZE the trigger or understand WHAT the skill does?
   → YES → Always-loaded (keep in SKILL.md)

2. Is this content a BEHAVIORAL RULE (governs what counts as X, what is allowed, what is forbidden)?
   → YES → Always-loaded (keep in SKILL.md, regardless of length)
   → "what counts as closed", "auto-allowed vs prohibited", "never touch" rules are behavioral

3. Is this content needed only when EXECUTING a specific step?
   → YES → On-demand (move to SKILL_detail.md)

4. Is this a DECISION TABLE (compact lookup, not step-by-step procedure)?
   → YES → Always-loaded (tables are high information density, keep)
   → Exception: table > 20 rows → candidate for SKILL_detail.md

5. Is this BASH CODE or a FORMAT TEMPLATE?
   → YES → On-demand (move to SKILL_detail.md)
   → Exception: one-liner illustration (≤1 line) used to identify a concept → may stay in SKILL.md
```

### 12 annotated examples

| Content type | Layer | Reason |
|---|---|---|
| Trigger phrases table | Always | Needed to recognize invocation |
| Step names + one-line criteria | Always | Overview — consumer needs to see the full sequence |
| Collision type routing table (3 rows) | Always | Decision table, compact |
| "natural-language close" patterns | Always | Behavioral rule — governs what counts as closed |
| "Memory curator safety: only INDEX-ORPHAN auto-allowed" | Always | Behavioral rule — prohibition |
| Multi-step synthesizer verdict matrix (5 rows) | Always | Decision table |
| Bash script for STALE detection | On-demand | Execution detail, step-specific |
| Agent() call format with prompt template | On-demand | Execution detail |
| 20-row edge case catalog | On-demand | Reference, not needed every invocation |
| Output format template (12 fields) | On-demand | Execution detail |
| "Done When" block | Always | Completion criterion — always needed |
| Connected skills table | Always | Navigation aid, compact |

### Ambiguous content test

The D-skill cold-start question frames the decision:

> *"If a consumer agent had only SKILL.md and typed the trigger phrase, would they need this content in the first 2 steps?"*
> - YES → Always-loaded
> - NO → **candidate** for on-demand — not yet a verdict

**Do not answer it in your head.** AMBIGUOUS is precisely the case where the eyeball answer is
unreliable, so the verdict is measured, per SKILL.md §Floor ① and CLAUDE.md's ablation procedure:

```bash
bash scripts/ablation_calibrate.sh          # runner precondition — must exit 0 before any arm runs
# then run the pre-registered arms per scripts/probe_scope_check.sh (header = canon:
#   arms · isolation · reps>=3 · pre-registration · the two leak channels)
# verdict line → .claude/regression/ablation_verdicts.md
```

Read the result correctly: a section is CUT only when the **isolated arm B answers the pre-registered
questions correctly**. Arm B answering **confidently wrong is a KEEP** — fluency is not recall, and
that is the failure the isolation exists to expose.

Behavioral rules skip the probe and stay Always-loaded (even if rarely triggered, the consumer needs
to know the constraint exists) — that is a KEEP by classification, not an unmeasured cut.

---

## §Pointers — Pointer Format Variants

### Standard pointer (single section reference)

```markdown
> **Detail**: See `SKILL_detail.md §<SectionName>` — [one-line description of what's there] — read when [specific condition that triggers need].
```

### Multi-item pointer (several related sections)

```markdown
> **Detail**: See `SKILL_detail.md §<SectionName-A>` (bash scripts) · `§<SectionName-B>` (format templates) — read when executing this step.
```

### Pointer placement rules

1. Place immediately **after** the summary/overview of the removed content in SKILL.md
2. If an entire step's execution detail is removed, place pointer **at the end of the step's one-line summary**
3. One pointer per removed block — do not stack multiple pointers for the same removal
4. The `— read when [condition]` clause is mandatory — it is the activation trigger for imperative loading

### What makes a pointer imperative vs advisory

Advisory (risky — consumer may skip):
```
"See SKILL_detail.md for bash scripts."
"Refer to SKILL_detail.md §Step6-Detail for details."
```

Imperative (required form):
```
"> **Detail**: See `SKILL_detail.md §<Step6-Detail>` — bash for STALE detection, memory scan, skill usage leaderboard — read when executing Step 6."
```

The imperative form includes:
- Blockquote + bold `**Detail**:` prefix (visual weight)
- Backtick-quoted path
- What's inside (one line)
- When to read (activation condition)

---

## §Split-Execution — Step-by-Step Procedure

### Step 1: Produce classification table

Read target SKILL.md. For every H2/H3 section, output:

```
| Section | Lines | Classification | Reason |
|---|---|---|---|
| ## Trigger Phrases | 8 | Always | Invocation recognition |
| ## Step 3 — bash scripts | 45 | On-demand | Execution detail, step-specific |
| "auto-allowed" rule | 2 | Always | Behavioral rule |
...
```

Count: Always N lines / On-demand N lines / Expected SKILL.md reduction: N%

### Step 2: Trim SKILL.md

1. For each On-demand section: delete content, replace with imperative pointer
2. Pointer §SectionName must match the header you will create in SKILL_detail.md exactly
3. Check: does SKILL.md still flow logically? Step overview must remain complete (names + criteria, no gaps)

### Step 3: Create SKILL_detail.md

Front-matter:
```yaml
---
name: {skill-name}-detail
description: Detail reference for {skill-name} — [what's here]. Load when executing a specific step.
load: on-demand
---
```

Opening line:
```
> Load when executing a specific step. SKILL.md contains [list what stays there].
```

For each pointer in SKILL.md: create matching `## §SectionName` header, paste removed content under it.

Orphan check: every section header in SKILL_detail.md must have a corresponding pointer in SKILL.md.
Scan `^## ` — **not** `^## §`: measured across this repo, 139 `## ` headers vs 97 `## §`, so a §-only
scan is structurally blind to 42 (30%) of real sections and passes them forever. If a header has no
pointer → add the pointer or merge with an adjacent section.

### Step 4: Verification sequence

```bash
S=plugins/{plugin}/skills/{name}

# 1+2+3 in one comparison. Three normalizations, each one learned from a false positive:
#   · headers are written "## §Name — description"      → strip the em-dash tail
#   · the marker word varies (**Detail**, **Template**) → match any bolded lead + "See"
#   · one line may carry TWO pointers (documented variant, §Pointers)
#                                                       → collect ALL §names on the line
#   Anchoring on the pointer LINE (not "any mention of the detail file") is what keeps prose that
#   merely DISCUSSES a pointer out — measured: a backtick-only filter counted an explanatory
#   example as a live pointer, and a **Detail**-only filter called two real pointers orphans.
diff <(grep -E '^> \*\*[A-Za-z]+\*\*: See ' "$S/SKILL.md" \
         | grep -oE '§[A-Za-z0-9_-]+' | sed 's/^§//' | sort -u) \
     <(grep '^## §' "$S/SKILL_detail.md" | sed 's/^## §//; s/ *—.*//' | sort -u)
# rc=0 → every pointer resolves AND every §header has a pointer (both directions in one run)
# rc=1 → the diff output names which side is missing what. Fix before commit.

# 4. Orphan scan over the WIDER header form (see above — §-only misses 30%)
grep -n '^## ' "$S/SKILL_detail.md"

# 5. Gate coverage for the destination path (SKILL.md §Floor ②)
bash scripts/gate_pathspec_check.sh
```

Then run:
- `/phantom-quench` — artifact: SKILL.md, declared source: SKILL_detail.md
- `/sim-conductor D skill {name}` — provide SKILL.md only, attempt core task from trigger phrase

---

## §Verification-Checklist

Use before committing a completed split:

| Check | Pass condition |
|---|---|
| Trigger phrases ≥ 3 | SKILL.md §Trigger Phrases has 3+ entries |
| Done When defined | SKILL.md has Done When block with ≥1 measurable condition |
| All §pointers resolve | phantom-quench: 0 phantoms |
| Cold-start grade F | sim-conductor Area D-skill: consumer reaches core completion |
| No behavioral rule in SKILL_detail only | Any rule governing "what counts as X" present in SKILL.md |
| No orphan sections | Every `## ` header in SKILL_detail.md has a pointer from SKILL.md (scan `^## `, not `^## §` — §-only is blind to 30% of real headers) |
| Gate coverage holds | `bash scripts/gate_pathspec_check.sh` exits 0, or the pathspec update ships in the same commit |
| Ablation verdict for every AMBIGUOUS cut | Verdict line in `.claude/regression/ablation_verdicts.md`; arm B correct = CUT, arm B confidently wrong = KEEP |
| SKILL.md ≤ 50% of original | Line count check |
| SKILL.md flows without gaps | Reading SKILL.md alone gives complete step sequence understanding |
