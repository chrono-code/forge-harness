---
name: fh-opencode-governance-wrapper
description: Step-by-step usage guide for FH + OpenCode governance integration. No API adapter required — FH reads files OpenCode writes. Includes empirical findings from 2026-05-31 controlled trial on arity.ts.
date: 2026-05-31
tags: [opencode, governance, usage-guide, synergy, pipeline-conductor, steel-quench, v2-paper]
---

# FH + OpenCode Governance Wrapper — Usage Guide

## What this is

OpenCode generates code fast. FH catches what fast generation misses.

The integration requires no runtime adapter. OpenCode writes files; FH reads files. The protocol is the interface. You can run this today on any OpenCode output.

---

## The 3-Step Governance Pass

After OpenCode completes a task (or at any checkpoint), run these three steps in order:

### Step 1 — Capture the diff

```bash
# Capture everything OpenCode changed since the task started
git diff <start-commit>..HEAD > /tmp/opencode_output.diff

# If you don't know the start commit:
git diff main..HEAD > /tmp/opencode_output.diff

# List changed files explicitly (needed for Steps 2 and 3):
CHANGED=$(git diff main..HEAD --name-only | tr '\n' ' ')
echo "Changed: $CHANGED"
```

### Step 2 — steel-quench adversarial pass

Run `/steel-quench` (or describe the target to Claude):

```
Run steel-quench adversarial review on these files: $CHANGED
Focus: behavioral edge cases, untested contracts, security assumptions.
Output: 3 most critical findings with severity (A/B/C) and evidence.
```

steel-quench looks for what tests don't cover: contract boundary violations,
caller assumption gaps, silent fallbacks that mask errors.

### Step 3 — pipeline-conductor --quick

```
Run pipeline-conductor --quick on: $CHANGED
```

4-axis verdict:
- Axis 1 (Backward): regression risk
- Axis 2 (Adversarial): structural gaps (from Step 2)
- Axis 3 (Forward): phantom claims, broken references
- Axis 4 (Record): calibration log entry

**If verdict is CLEAN or PENDING**: proceed. Log the run.
**If verdict is BLOCKED**: surface findings to OpenCode, re-run the task with constraints added.
**If verdict is ESCALATE**: human decision required before merge.

---

## Optional: Step 0 — Pre-task scope gate

Before running OpenCode on a large task, estimate the scope:

```
Estimate token budget for: <task description>, ~<N> files expected to change.
```

Use `/token-budget-gate` or the fallback heuristic:

| Scope | Verdict |
|---|---|
| < 5 files, no new architecture | GREEN — proceed |
| 5–20 files or new module | YELLOW — proceed with monitoring |
| 20+ files or cross-system refactor | ORANGE — confirm scope |
| Full rewrite | RED — split into smaller tasks first |

---

## Empirical Baseline (2026-05-31)

**Target**: OpenCode's own `packages/opencode/src/permission/arity.ts` (163 lines, AI-generated).

**Baseline (CI + self-evaluation)**: 6 unit tests, all pass. No syntax errors. Verdict: DONE.

**After FH governance pass**:

| Finding | Grade | What CI missed |
|---|---|---|
| Short-token overflow in `prefix()` — arity=3 entry with 2-token input builds allowlist pattern that may not cover bare commands | A | Untested path; `git stash` alone may not match `"git stash *"` |
| `npx`, `opencode`, `claude`, `bunx`, `uvx` absent from arity table — any `npx <package>` receives same broad `"npx *"` pattern | A | Not in test scope; security model weakened |
| AI-generated dictionary has no maintenance protocol or rule compliance check | B | No cadence, drift risk |

**Verdict flip**: DONE → PENDING. Delta is attributable to methodology layer, not the model.

**Implication**: 3 findings per 163-line AI-generated module that CI treats as done. Extrapolate across a codebase and the governance dividend compounds.

---

## When to run

| Signal | Action |
|---|---|
| OpenCode completes a task and opens a PR | Run all 3 steps before merge review |
| OpenCode generates a new module (AI-authored code) | Run Steps 2+3 — adversarial + 4-axis |
| OpenCode touches a security-adjacent file (permissions, auth, tokens) | Mandatory — run Steps 2+3 with security lens |
| OpenCode generates tests | Step 3 (pipeline-conductor) — check if tests actually cover the contract |
| Long OpenCode session (YELLOW or ORANGE budget) | Run Step 1 at each checkpoint, not just at the end |

---

## Synergy map — what each layer contributes

| Layer | Role | What it catches |
|---|---|---|
| **OpenCode** | Fast autonomous coding | Working code at speed |
| **FH steel-quench** | Adversarial review | Behavioral edge cases, untested contracts, security assumptions — what tests don't cover |
| **FH pipeline-conductor** | 4-axis structured gate | Regression risk, phantom claims, record keeping — what code review doesn't structure |
| **Combined** | Governance wrapper | Fast coder + structured critique = rigorous engineer |

The key: OpenCode and FH operate on the same files with no integration layer. The governance wrapper is a *protocol*, not an API.

---

## Full automation (optional)

For teams that want to run governance automatically after every OpenCode session, add a Stop hook:

```json
// .claude/settings.json (in your project, not forge-harness)
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "echo '[FH governance] Run pipeline-conductor --quick on $(git diff main..HEAD --name-only | tr \"\\n\" \" \")' >> /tmp/fh-pending-governance.txt"
          }
        ]
      }
    ]
  }
}
```

On session end, check `/tmp/fh-pending-governance.txt` and run the governance pass.

---

## References

- `fh_ecosystem_positioning.md` — ecosystem context, synergy map, v2 paper connection
- `multi_model_sidecar_strategy.md` — multi-model orchestration (sidecar pattern for adding Gemini/Codex review)
- `tracks/_meta/fh_opencode_governance_experiment_2026_05_31.md` — full empirical record (local)
- FH paper (Zenodo: 10.5281/zenodo.20397565) — harness-as-durable-layer thesis
