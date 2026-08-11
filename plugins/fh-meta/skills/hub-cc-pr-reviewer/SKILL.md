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

Self-catch areas 0 items = skip this entire catch matrix — do not pad with token-filling to make the section look populated.

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
- **Simplification guard consistency** — when creating/modifying this skill, update SKILL.md only. No new auxiliary files
- **Markdown editing discipline mandatory** — Edit first. No Write
- **Frontmatter description plain text only baseline** — avoid markdown bold

> The three rules above were previously each attributed to a `memory feedback_*.md` file. Those files
> do not exist (verified 2026-08-11 against the operator's memory root, with a known-positive control
> in the same run). The **rules stand on their own**; only the pointers were dead, and citing a
> non-resolving file as the authority is the phantom-reference class this skill is supposed to catch.
> Do not re-attach a memory citation here unless `ls` resolves it **in the same run that cites it**.

> **Detail**: See `SKILL_detail.md §Sister Asset Utilization Path`, `§External User Environment Adaptation Path`, `§Disable Path`, `§Persona Synergy Catch` — cross-ecosystem utilization, external-environment fallback, own-PRS disable resolution, and deep-insight simultaneous-activation handling — read when operating in an external user environment, resolving own-PRS conflict, or coordinating with deep-insight.

## Done When

This is a **gate/routing skill** — its output is a merge verdict — so every judged condition below
names its adversarial pairing. No judge-only path.

```
All 5 Steps completed
  — mandatory-pass: each step produced its output or is marked N/A with a reason

+ Baseline consistency check 8-matrix results output (OK/WARN/BLOCK each item)
  — measured: count items REPORTED vs items ACTUALLY CHECKED; the two must
    match. Matrix #2 (memory baseline) reports SKIPPED when no memory file
    resolves — it is never folded into the pass count (see §References)

+ Axis 1 run in --pr mode with a typed verdict read from
  REGRESSION_GUARD_RESULT_FILE
  — mandatory-pass: result is `pass` or `block`. `skip` and exit 3 are NOT
    passes; they mean Axis 1 did not examine this PR and the recommendation
    may not cite it as green

+ /public-surface-audit run over the composed comment text BEFORE any
  gh pr comment
  — mandatory-pass, fail-closed: CLEAN attaches; REVIEW/LEAK redact-and-rescan;
    NOT_CONFIGURED or audit unavailable hands to the operator. A posted comment
    is irreversible, so tooling-down is a block, never a free skip

+ Review comment attached via gh pr comment command
  — mandatory-pass: the comment URL is returned by the command

+ Admin override merge recommendation output (merge execution is user's
  decision)
  — judged; adversarial pairing: the branch-protection state is re-read at run
    time from BOTH layers (`.../branches/main/protection` and
    `.../rules/branches/main`, strictest wins) in the same run that recommends.
    A recommendation citing this file's prose instead of a live read is
    unfounded — that exact defect already shipped once here, on a field that
    had flipped

+ External verification path: an isolated Critic agent can reach the same
  verdict from the artifacts alone
  — judged; adversarial pairing: the reviewer-visible evidence must be
    reproducible WITHOUT the author's local files. Any verdict resting on a
    gitignored local artifact ships labelled LOCAL-ONLY ATTESTATION -
    UNVERIFIED, which leaves the condition UNMET rather than met
    (`.claude/rules/fh_4axis_gate.md` §Reviewer-visible evidence)
```

**→ Mandatory when PR contains SKILL.md / rules / templates changes: run Axis 1 (backward check) in
`--pr` mode, against the PR's head branch** — before the merge recommendation is issued. If
regression_guard reports an M-tier block, the merge recommendation must change to ❌ regardless of
other checks.

```bash
# Precondition: the PR head branch must exist locally. This skill reads the PR via `gh pr diff`
# without checking anything out, so fetch the head ref first or --pr has nothing to resolve.
PR_BRANCH="$(gh pr view "$PR" --json headRefName -q .headRefName)"
git fetch origin "$PR_BRANCH":"refs/remotes/origin/$PR_BRANCH"   # skip if already present
bash templates/regression_guard.sh --pr "origin/$PR_BRANCH"
```

⚠️ **Do not run it with no arguments.** Bare `bash templates/regression_guard.sh` diffs the **working
tree**, and this skill's own workflow leaves the reviewer standing on a clean `main` — so the bare
form returns `REGRESSION_GUARD_RESULT=skip` with `exit 0` **100% of the time**, and the mandatory
Axis-1 gate never examines the PR at all. Measured 2026-08-11 on a clean checkout: bare form →
`rc=0 / result=skip`; `--pr <branch>` on the same commit → `rc=0 / result=pass` having actually read
the changed SKILL.md. Canonical form is `--pr {BRANCH}` (`.claude/rules/fh_4axis_gate.md`).

**Read the verdict from the typed channel, not the exit code** — `exit 0` means pass **or** skip
(not-checked). Run with `REGRESSION_GUARD_RESULT_FILE=/tmp/rg.$$` and read `result=` from that file:
`skip` means Axis 1 **did not examine** this PR (no matching file, or the wrong invocation form) —
record it as "Axis 1 N/A", never as a green check. `exit 3` means the invocation itself failed
(unresolvable branch) — also not a pass; fetch the ref and re-run. A merge recommendation that cites
an unexamined Axis 1 as PASS is the 2026-07-22 fail-open class.

## References

> ⚠️ **The memory filenames below were audited 2026-08-11 and **none of them exist** — 8/8 absent in
> the operator's own memory root, i.e. they were never reachable, not merely absent externally. They
> are kept, struck, as the record of a phantom-reference class: a gate skill citing rule bodies that
> resolve nowhere, while matrix #2 silently "skips" and the run still reports an 8-matrix pass.
> **Matrix #2 is therefore a 7-matrix in practice** — report it as `matrix 2: SKIPPED (no resolvable
> memory baseline)` rather than folding it into the pass count (`not found ≠ 0`).
> Re-populate this list only with paths verified by `ls` **in the same run that cites them**.
>
> **Arithmetic reconciled 2026-08-11**: the "8/8" above is now true of the list below — all 8 cited
> filenames are struck (re-verified in one run: 8 cited / 8 absent, with a known-positive and a
> known-negative control). Previously only 7 were struck while the 8th
> (`feedback_autonomous_commit_proposal`) was still cited live, and three more were cited as live
> authority up in §Constraints and §Step 3 — where an executor actually reads, since References is
> not on the execution path. **Those live citations are removed; the rules they carried are stated
> directly.** A struck entry in References is not a fix if the same name is still load-bearing above.

- ~~Rule body: `memory feedback_command_tower_gate.md` + `memory feedback_field_to_hub_sync_protocol.md`~~ — **absent (verified 2026-08-11)**
- ~~Consistency rules: `feedback_simplification_evidence` · `feedback_markdown_edit_discipline` · `feedback_skill_frontmatter_description_plain_text` · `feedback_bidirectional_self_validation` · `feedback_reference_own_hub_assets_first`~~ — **absent (verified 2026-08-11)**
- Sister skills: `cross-ecosystem-synergy-detection` (sister asset cluster baseline) · `verify-bidirectional` (bidirectional self-validation automation / self-catch auxiliary axis) · `harvest-loop` (weekly audit automation / operation proof accumulation cross-link)
- ~~Autonomous commit proposal §2.19 baseline: `memory feedback_autonomous_commit_proposal.md`~~ — **absent (verified 2026-08-11)**. The rule it stood for is live and lives in `CLAUDE.md §AI Contribution Model`: development-source automation is allowed, PR submission requires explicit human approval. Cite that, not this filename.
