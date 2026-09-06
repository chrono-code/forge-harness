---
name: goal-quench-anthropic-issue
description: Draft Anthropic GitHub issue — native /goal token budget + quality verification hook. Reference for when arXiv number is confirmed.
type: reference
date: 2026-05-31
tags: [goal, anthropic, feature-request, token-budget, quality-gate]
---

# [Feature Request] /goal — native token budget control + quality verification hook

## Summary

`/goal` is powerful but ships two structural gaps: no token budget enforcement and a binary completion evaluator (Haiku yes/no) with no quality signal. This issue proposes three native flags to close these gaps, with a userspace proof-of-concept as reference.

---

## Problem

### 1. Token explosion with no mid-run intervention

`/goal` runs until Haiku says "done" or context is exhausted. There is no mechanism to:
- Set a token ceiling before the run
- Intervene at a percentage threshold (e.g., 80% consumed)
- Save and checkpoint progress when budget runs low

Real-world symptom: users report running `/goal "finish all of this"`, going to sleep, and waking to a fully exhausted context with no recovery path for incomplete work.

### 2. Completion ≠ quality

Haiku's binary evaluator (`done? yes/no`) checks whether the stated goal condition is satisfied — not whether the output is correct, well-structured, or regression-free.

A session can reach `done = yes` while having introduced bugs, phantom references, or broken existing behavior. There is no hook for a quality gate on the completion verdict.

### 3. No checkpoint / resume

When budget exhaustion forces a stop, there is no structured record of what was completed vs. what remains. The next session starts cold.

---

## Proposed Native Flags

### `--budget <N>`

Enforce a token ceiling for the `/goal` session.

Behavior:
- At 70% of `N`: surface a warning to the user — "Budget at 70%. Recommend re-prioritizing remaining tasks."
- At 85% of `N`: pause the session. Prompt: "Budget at 85%. Options: (a) continue / (b) reduce scope / (c) stop and save."
- At 95% of `N`: force stop. Commit completed work. Output structured summary: `Completed: [...] | Remaining: [...]`

### `--verify <command>`

Run a shell command when Haiku returns `done = yes`. Accept the completion verdict only if the command exits 0.

```bash
# Example: test suite must pass before /goal accepts "done"
/goal "all tests pass" --verify "npm test"

# Example: FH quality gate before accepting completion
/goal "refactor complete" --verify "claude -p 'run pipeline-conductor --quick'"
```

This separates the concerns that a single evaluator cannot serve simultaneously:
- **Haiku**: completion detection (fast, cheap, every turn)
- `--verify` command: quality gate (once, on completion, user-defined)

The same principle that motivated separating the Haiku evaluator from Claude's self-assessment (avoiding cognitive bias) applies here: the completion judge should not also be the quality judge.

### `--checkpoint`

Auto-commit on structured sub-goal boundaries. Requires Haiku to output sub-goal markers (not just yes/no), which is a separate RFC — listed here for completeness.

---

## Reference Implementation

**forge-harness `goal-quench`** implements a userspace version of `--budget` + `--verify` using:
- Pre-run: `token-budget-gate` skill estimates cost and sets thresholds
- Mid-run: thresholds injected as session instructions (Claude self-enforces)
- Post-run: Stop hook detects `/goal` completion → triggers `pipeline-conductor --quick`

Limitations of the userspace approach (why native support is needed):
- Mid-run token ceiling cannot be hard-enforced without native hook
- Stop hook cannot invoke Claude recursively (verification triggers on next session, not immediately)
- Checkpoint requires manual commit — no structured sub-goal output from Haiku

**Paper reference**: forge-harness: A Meta-Harness Engineering Platform for Terminal-Native Claude Code Workflows. Zenodo DOI: 10.5281/zenodo.20397565. arXiv: [pending number].

---

## Adoption signal

`/goal` was introduced in Claude Code Week 20 (2026-05-11), absorbing the community `claude-goal` project (Stop hook implementation) 11 days after OpenAI Codex CLI v0.128.0 shipped a similar feature. Community demand is established. This request addresses the production-readiness gap that community implementations cannot close without native runtime access.

---

## Related issues / PRs

- `claude-goal` (community Stop hook implementation): [link if available]
- OpenAI Codex CLI `/goal` reference: v0.128.0 release notes

---

*Drafted: 2026-05-31. Submit after arXiv number confirmed.*
