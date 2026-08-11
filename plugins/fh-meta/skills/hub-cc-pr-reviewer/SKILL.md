---
name: hub-cc-pr-reviewer
description: Checks a submitted PR against the environment's baseline assets (CLAUDE.md, memory, naming, asset classification) and attaches a review comment with a merge recommendation. 5 steps — diff read, 8-area consistency check, self-catch, comment, merge recommendation.
user-invocable: true
allowed-tools: ["Bash", "Read", "Grep", "Glob"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - adversarial
    - cross_project
    - high_stakes
---

> **Note:** The original developer is the forge-harness original developer (development source + meta-monitoring home). In external user install environments, the install environment user themselves is the baseline integrity gate operator (following path B generalization baseline / `SKILL_detail.md §External User Environment Adaptation Path` §).

# hub-cc-pr-reviewer — Hub Gate Operation Rule Automation

When a PR is submitted, checks consistency against the user environment's baseline assets (CLAUDE.md · memory · naming · asset classification) and attaches a review comment. 5-step: diff read → 8-matrix check → self-catch → comment attachment → merge recommendation.

## Activation Triggers

1. **PR #N input**: *"Review PR #N"* / *"Check PR #N"* / *"hub review"* / *"baseline consistency check"*
2. **Action leader cc → hub sync point**: Large decision area PR catch (following Option C Hybrid policy — memory creation / CLAUDE.md change / CATALOG round / skill v0.x evolution / policy change / asset synergy branch judgment)
3. **Hub cc session entry**: Layer A auto-read recent external commit catch (auto-discover new PRs)

### Natural Language Triggers (General user phrasing — activates without internal vocabulary)

| Example phrasing | Intent |
|---|---|
| "Is it okay to submit this PR?" | PR review request |
| "This change seems inconsistent with existing rules" | Baseline consistency check |
| "Please review before merging" | PR review gate |
| "Does this change affect other parts?" | Consistency check |

**Activation criteria**: "Review PR #N" / "Add review comment" / "Baseline check" → Run this skill directly  
*(pr-review-watcher deprecated as of v0.2.0 — recommend using `gh pr view --json reviews` directly)*

**Exceptions** (this skill does NOT apply):
- **Small patches** (typo / 1-line cross-ref addition / sync / minor adjustments) → Follow Option C Hybrid policy (direct push allowed area / review skip)
- **Original developer simple correction commands** ("This is wrong, redo it") → Immediate correction (no review / direct handling)

## Processing Steps (5-step)

### Step 1. PR Diff Read

Read the PR diff + metadata. If this cc authored the change, the diff read can be skipped (directly state changed areas in PR body).

> **Detail**: See `SKILL_detail.md §Step 1 Diff Read` — `gh pr diff` + `gh pr view` commands — read when executing the diff read.

### Step 2. Baseline Consistency Check — 8-Matrix Auto-Generation

| # | Area | Check path |
|:---:|---|---|
| 1 | CLAUDE.md (hub identity + asset ownership + sync policy) | Grep PR diff vs CLAUDE.md baseline areas |
| 2 | Memory accumulation (accumulated naming/decision baseline + asset synergy branch judgment + active onboarding + bidirectional self-validation, etc.) | Grep PR diff vs `memory feedback_*.md` key areas (**External environment**: skip this item if memory files absent → `SKILL_detail.md §External User Environment Adaptation Path` §) |
| 3 | Naming baseline (accumulated naming baseline + new naming candidate area) | Catch new naming candidates from PR diff / check adherence to existing naming |
| 4 | Asset synergy branch judgment (meta/hub seed vs action leader persistent location) | Check PR changed asset location consistency |
| 5 | Simplification guard (P15 asymmetry catch + R7 over-engineering) | New asset creation vs existing asset reinforcement judgment / body length check |
| 6 | Dimension separation baseline (## Plugins / ## Skills / ## Agents) | Check dimension separation consistency on CATALOG changes |
| 7 | Branch criteria (large decision PR mandatory vs small patch direct push) | Check if PR is a large decision area (Option C Hybrid) |
| 8 | Hub gate operation consistency | Check if PR itself is a hub gate operation proof path |

Matrix result = Consistent ✅ / Partially Consistent ⚠️ / Inconsistent ❌.

### Step 3. Layer 5 Self-Catch Matrix

Self-precision catch areas after first cc review (following previous PR self-catch patterns):
- Check adherence to frontmatter description plain text only baseline (project baseline)
- Check honest documentation of generalization effect weakening areas
- Check explicit statement of gap between accumulated history (original developer environment) vs external user starting point (0 instances)
- Check explicit statement that audience-specific guides are limited to original developer environment
- Check explicit statement of organization-specific areas

Self-catch areas 0 items = skip this entire catch matrix (no token-filling / following `feedback_simplification_evidence`).

### Step 4. Review Comment Attachment

**Mandatory before any `gh pr comment`: run `/public-surface-audit` over the composed comment text.**
A PR comment is a **paste on a public surface**, and the repo's mechanical privacy floor does not
reach it — the pre-commit confidentiality guard scans *staged tracked content* and has **no view of
PR-body text** (`.claude/rules/fh_4axis_gate.md §Reviewer-visible evidence` says so explicitly).
This step's own inputs make that acute: Step 2 matrix #2 greps the operator's **local memory files**,
so an unfiltered paste can carry absolute home paths and private memory prose onto a public PR.

```
verdict CLEAN                     → attach (automatic, within this skill's authority)
verdict REVIEW / LEAK             → do NOT attach. Redact the flagged spans, re-scan, then attach
verdict NOT_CONFIGURED, or the
  skill is unavailable            → do NOT attach automatically. This is an irreversible surface
                                    (a posted comment is public the instant it lands and may be
                                    mirrored before deletion) → **fail-closed**: hand the composed
                                    text to the operator, or take an explicit logged override
```

**Never paste raw Step 2 grep output.** Write a *sanitized capsule* — what was checked, what it
returned, what was found — never the matched lines themselves. Same rule as the marker: the file is
a local artifact, the capsule is what crosses the boundary.

Then attach the review comment (8-matrix results + self-catch + refinement suggestions + merge
recommendation) via `gh pr comment`.

> **Detail**: See `SKILL_detail.md §Step 4 Comment Template` — `gh pr comment` heredoc template — read when attaching the comment.

### Step 5. Admin Override Merge Recommendation

**User decision delegation** (this skill = review/recording automation / no merge authority):
- **Read the branch-protection state at run time — never from this line.** This repo moved to
  `enforce_admins: true` + `required_approving_review_count: 0` on 2026-07-20, and an earlier version
  of this bullet still claimed `false`: a gate skill was recommending an override on a **field that
  had already flipped**. Protection is also two independent layers (legacy + rulesets, strictest
  wins), so one object is never the effective answer — check both:
  `gh api repos/{owner}/{repo}/branches/main/protection` **and**
  `gh api repos/{owner}/{repo}/rules/branches/main`
- Self-approve is impossible when this cc authored the PR → after a completed review, `--admin` is
  the normal route, not a shortcut
- Self-approve blocked (GHE policy) → admin override path adherence
- When this cc authored the change, admin override path is mandatory
- N+1th operation proof = baseline stabilization acceleration path

> **Detail**: See `SKILL_detail.md §Step 5 Merge Command` — `gh pr merge` command (executed after user decision, not by this skill) — read when the user authorizes merge.

## User Approval Gate

| Stage | Approval |
|---|---|
| Step 1~3 check auto-activation | **Automatic** (editable afterward) |
| Step 4 review comment attachment | **Automatic only after `/public-surface-audit` on the comment text returns CLEAN.** REVIEW/LEAK → redact and re-scan; NOT_CONFIGURED or audit unavailable → **fail-closed**, hand to the operator (a posted comment is public on landing) |
| Step 5 admin override merge execution | **User decision** (this skill = recommendation only / no merge authority) |

## Constraints

- **This skill = review/recording automation / no merge authority** — user admin override or other reviewer merge decision
- **No single-person decision application** — following `fact-checker` rule (narrow 1 / broad N+1 / this cc self-catch joins fact-checker count)
- **Simplification guard consistency** (`feedback_simplification_evidence`) — when creating/modifying this skill, update SKILL.md only. No new auxiliary files
- **Markdown editing discipline mandatory** (`feedback_markdown_edit_discipline`) — Edit first. No Write
- **Frontmatter description plain text only baseline** (`feedback_skill_frontmatter_description_plain_text`) — avoid markdown bold

> **Detail**: See `SKILL_detail.md §Sister Asset Utilization Path`, `§External User Environment Adaptation Path`, `§Disable Path`, `§Persona Synergy Catch` — cross-ecosystem utilization, external-environment fallback, own-PRS disable resolution, and deep-insight simultaneous-activation handling — read when operating in an external user environment, resolving own-PRS conflict, or coordinating with deep-insight.

## Done When

```
All 5 Steps completed
+ Baseline consistency check 8-matrix results output (✅/⚠️/❌ each item)
+ Review comment attached via gh pr comment command
+ Admin override merge recommendation output (merge execution is user's decision)
+ External verification path: harvest-loop Step 3.75 Critic isolation Agent can independently judge based on above criteria (skill_quality_rubric.md verifiable criteria)
```

**→ Mandatory when PR contains SKILL.md / rules / templates changes: `bash templates/regression_guard.sh`** — run Axis 1 (backward check) before merge recommendation is issued. If regression_guard exits with M-tier block, merge recommendation must change to ❌ regardless of other checks.
**Read the verdict from the typed channel, not the exit code** — `exit 0` means pass **or** skip
(not-checked). Run with `REGRESSION_GUARD_RESULT_FILE=/tmp/rg.$$` and read `result=` from that file:
`skip` means Axis 1 **did not examine** this PR (no matching file) — record it as "Axis 1 N/A", never
as a green check. A merge recommendation that cites an unexamined Axis 1 as PASS is the 2026-07-22
fail-open class.

## References

> ⚠️ **The memory filenames below were audited 2026-08-11 and **none of them exist** — 8/8 absent in
> the operator's own memory root, i.e. they were never reachable, not merely absent externally. They
> are kept, struck, as the record of a phantom-reference class: a gate skill citing rule bodies that
> resolve nowhere, while matrix #2 silently "skips" and the run still reports an 8-matrix pass.
> **Matrix #2 is therefore a 7-matrix in practice** — report it as `matrix 2: SKIPPED (no resolvable
> memory baseline)` rather than folding it into the pass count (`not found ≠ 0`).
> Re-populate this list only with paths verified by `ls` **in the same run that cites them**.

- ~~Rule body: `memory feedback_command_tower_gate.md` + `memory feedback_field_to_hub_sync_protocol.md`~~ — **absent (verified 2026-08-11)**
- ~~Consistency rules: `feedback_simplification_evidence` · `feedback_markdown_edit_discipline` · `feedback_skill_frontmatter_description_plain_text` · `feedback_bidirectional_self_validation` · `feedback_reference_own_hub_assets_first`~~ — **absent (verified 2026-08-11)**
- Sister skills: `cross-ecosystem-synergy-detection` (sister asset cluster baseline) · `verify-bidirectional` (bidirectional self-validation automation / self-catch auxiliary axis) · `harvest-loop` (weekly audit automation / operation proof accumulation cross-link)
- Autonomous commit proposal §2.19 baseline: `memory feedback_autonomous_commit_proposal.md` (① development source automation + PR proposal under human approval)
