---
name: hub-cc-pr-reviewer-detail
description: On-demand detail for hub-cc-pr-reviewer — step bash commands, comment template, sister-asset utilization, external-environment adaptation, disable path, and persona synergy handling. Read when executing a step or operating in an external/own-PRS/deep-insight environment.
load: on-demand
---

## §Step 1 Diff Read

```bash
gh pr diff "$PR_NUMBER"                                             # Read changes directly
gh pr view "$PR_NUMBER" --json files,additions,deletions,baseRefName,headRefName,title,body  # Metadata
```

If this cc authored the change, `gh pr diff` can be skipped (directly state changed areas in PR body).

## §Step 4 Comment Template

```bash
gh pr comment "$PR_NUMBER" --body "$(cat <<'EOF'
## Hub CC Review (Hub Gate — Accumulated Operation Proof)

### Baseline Consistency Check 8-Matrix
{Step 2 results}

### Layer 5 Self-Catch Matrix
{Step 3 results / omit if 0 items}

### Refinement Suggestions (following simplification guard / areas for subsequent rounds outside this PR)
{Subsequent round areas / omit if 0 items}

### Nits (max 5; +N more not listed)
{At most five style/naming/wording items; omit the section if 0. Never list what a gate already enforces.}

### Admin Override Merge Recommendation
{User decision delegation / beta stage policy adherence}
EOF
)"
```

## §Step 5 Merge Command

```bash
# Execute after user decision (this skill does NOT execute)
gh pr merge "$PR_NUMBER" --squash --admin --delete-branch
```

## §Sister Asset Utilization Path

Sister Asset Utilization Path (cross-ecosystem-synergy-detection v0.2 baseline consistency)

| Cluster | Utilization path | Acceleration to 5+ instances |
|---|---|:---:|
| **QA cluster** (project QA repos) | Domain-specific consistency check auto-activation on action leader cc PR submission | ★★★ |
| **Meta cluster** (forge-harness · related plugins) | FH-meta area new skill consistency / meta/rule baseline consistency check | ★★ |
| **Automation cluster** (CI/CD automation tools) | Compare roles with external review tools and decide whether to apply as supplementary axis | ★★ |

## §External User Environment Adaptation Path

External User Environment Adaptation Path (path B generalization baseline)

This skill = original developer hub environment baseline. External user (mode C install) environment adaptation path — following forge-harness core proposition *"Beta + public release = obligation to have practical capabilities"*.

### External User Environment Assumptions

External users in 2 tiers:

| Type | Internal GHE access | Applicable path |
|---|---|---|
| **Internal non-hub** (org employee, not owner) | Yes | Replace matrix with user's own baseline assets — can use internal GHE PR workflow as-is |
| **External** (outside org) | No | Apply entire Fallback Matrix below — fully replace with user's own environment assets |

Common: In external user install environments, **the install environment user** is the baseline integrity gate operator.

This skill's core essence = "PR input → baseline consistency check + self-catch + review comment + merge recommendation" — cross-applicable to both types.

### Own PRS Priority Environment Catch (following Scenario 3 devil-advocate)

In external user environments where **own PRS (pr-reviewer-self)** is already established (environments with own PR review skill/rules/hooks/own conventions) — risk of conflict when this skill and own PRS activate simultaneously. Lack of activation trigger priority resolution catch.

**Common conflict examples**: `code-review` skills · PR review hooks (`.claude/hooks/post-tool-use`) · review skills from other plugins — duplicate activation on same triggers ("PR", "review").

→ **Disable path** adherence mandatory (see § below). Disable this skill baseline in environments where own PRS takes priority.

### Fallback Matrix (Original Developer Environment → External Environment Replacement)

| Original developer environment dependency | External user environment fallback |
|---|---|
| `memory feedback_*.md` accumulated naming/decision baseline + asset synergy branch judgment etc. (Step 2 matrix #2) | User environment's own baseline assets (`memory/` · `notes/` · `docs/` · `CLAUDE.md`) |
| `CLAUDE.md` hub identity (Step 2 matrix #1) | User environment's own `CLAUDE.md` or project README rules § |
| Accumulated naming/decision baseline adherence (Step 2 matrix #3) | User environment's own naming/decision baseline |
| `CATALOG.md` ## Plugins / ## Skills / ## Agents (Step 2 matrix #6) | User environment's own catalog or asset classification (skip if absent) |
| Option C Hybrid sync policy (Step 2 matrix #7) | User environment's own PR/direct push policy (user environment baseline adherence) |
| PR lifecycle operation proof history + accumulated self-catch (Step 2 matrix #8) | User environment's own operation proof starting at 0 instances |

### External User Usage Scenarios

1. **General PR review automation**: On user PR submission → this skill auto-activates → 5-step processing + review comment attachment
2. **User's own baseline consistency check**: Generalize 8 Step 2 matrix items to user's own environment assets
3. **Accumulate user's own self-catch count**: Starting at 0 / operation proof baseline stabilizes as count grows
4. **Same user approval gate adherence**: Review comment attachment automatic / merge authority is user's own decision

### Limitations (Explicit)

- **Accumulated naming baseline adherence materials** = original developer environment accumulated baseline / external user environments should follow their own naming/decision baseline
- **PR lifecycle operation proof materials + accumulated self-catch** = original developer environment accumulated / external user environments start own PR lifecycle + self-catch accumulation at 0 instances
- **Hub gate core essence** = cross-applicable to all user environments (baseline integrity + self-monitoring + Layer 6 bidirectional evolution circuit consistency)
- This skill = original developer environment base + external user environment fallback path coexistence baseline

## §Disable Path

Disable Path (Own PRS Priority Environment Baseline)

Baseline for disabling this skill in environments where own PRS (pr-reviewer-self) is established. Following Scenario 3 devil-advocate consolidated one-line conclusion — avoiding *"fh-meta risks becoming a circuit that reinjects owner baseline into heavy users via self-reference"*.

### 4 Deactivation Options

| Step | Path | Essence |
|:-:|---|---|
| 1 | Frontmatter `user-invocable: false` | Skill itself deactivated (manual call only) |
| 2 | `.claude/settings.json` plugin disable | fh-meta plugin level deactivation (affects other skills too — for this skill only, recommend step 1 or 3) |
| 3 | Per-skill deactivation | `.claude/settings.json` `skills.disabled` or `.claude/disabled-skills.json` |
| 4 | Trigger avoidance | Avoid description trigger vocabulary ("Review PR" / "hub review") — use own PRS triggers first |

### Priority Resolution Baseline

When own PRS + this skill both activate simultaneously:

| Environment | Default priority |
|---|---|
| Original developer environment (forge-harness original developer) | **This skill takes priority** (hub gate baseline) |
| External user environment (own PRS established) | **Own PRS takes priority** (user environment baseline / this skill = supplementary or disabled) |
| External user environment (own PRS not established) | This skill available (user's decision) |

### Heavy User Autonomy Non-Infringement Baseline

- This skill = NOT "a stronger tool" / obligation to avoid infringing user autonomy
- Catch "owner baseline self-reference reinjecton circuit" risk (following Scenario 3 consolidated conclusion)
- → Mandatory baseline to explicitly document disable path (ensures user decision space)

## §Persona Synergy Catch

Persona Synergy Catch (Scenario 2 adherence)

> **Applies only if the `deep-insight` plugin is installed** (it is an optional external plugin, not bundled with FH). If deep-insight is absent, this simultaneous-activation risk cannot arise — skip this entire section. No fallback is needed because there is no collision to resolve.

### deep-insight Multi-Perspective Review ↔ This Skill Simultaneous Activation Risk

Scenario 2 persona-newcomer catch — when this skill also activates during deep-insight multi-perspective review, risk of token cost/time explosion. Two skills unaware of each other / cross-ref absent area.

### Simultaneous Activation Resolution

When deep-insight + this skill simultaneously trigger → delegate priority decision to user:
- deep-insight first (full multi-perspective review, this skill supplementary)
- or this skill first (hub review, deep-insight supplementary)
- or incompatible (run only one / follow disable path §)

### Cascade Value Areas (Synergy ★★★)

- persona-be / persona-fe → plugin-recommender (Spring / Storybook recommendation cascade)
- harvest-loop → domain persona post-processing (★★ / format conflict catch mandatory)
- deep-insight multi-perspective review → this skill **sequential** activation (not simultaneous / avoid token cost)
