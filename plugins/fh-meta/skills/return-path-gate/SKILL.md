---
name: return-path-gate
description: Audits SKILL.md files in plugins/ for return-path gate compliance. Detects fire-and-forget chains where a caller dispatches a downstream skill but does not gate its next step on the callee's verdict. Reports each chain as CLOSED or OPEN and outputs specific fix suggestions. Triggered by "chain audit", "return-path check", "fire-and-forget detection", "chain closure audit", "skill chain compliance".
user-invocable: true
allowed-tools: ["Read", "Bash", "Glob", "Grep"]
model: sonnet
---

# return-path-gate — Skill Chain Closure Audit

A skill chain is CLOSED when the callee's verdict folds back into the caller's decision logic. A chain is OPEN (fire-and-forget) when the caller dispatches a downstream skill but proceeds independently of the result.

This skill audits `§Chains` and `§Done When` sections across SKILL.md files to detect OPEN chains and prescribe specific closures.

## Role Separation from harness-doctor

| Dimension | harness-doctor | return-path-gate |
|---|---|---|
| **What it checks** | Structural completeness (files, references, line counts, drift) | Chain closure compliance (caller/callee verdict handoff) |
| **Core question** | "Are the required harness files present and consistent?" | "Does the caller wait for the callee's verdict?" |
| **Failure mode detected** | Missing CLAUDE.md, broken refs, complexity drift | Fire-and-forget chains, unverified CONDITIONAL_PASS conditions |
| **Output** | L1–L5 structural health report | CLOSED/OPEN chain table with fix prescriptions |

---

## Trigger Phrases

| Phrase | Situation |
|---|---|
| "chain audit", "chain closure audit" | Full scan of all skill chains in plugins/ |
| "return-path check", "return-path gate" | Explicit compliance audit |
| "fire-and-forget detection", "fire-and-forget chain" | Targeting known anti-pattern |
| "skill chain compliance" | Pre-flight check before pipeline execution |
| "does this skill wait for verdict" | Single-skill targeted check |
| "check chains in [skill-name]" | Scoped audit on a named skill |
| `/return-path-gate` | Explicit call |

---

## Audit Scope Options

| Flag | Scope | When to use |
|---|---|---|
| `--skill [name]` | Single named skill | Targeted check during development |
| `--all` | All SKILL.md files under `plugins/` | Full compliance sweep |
| `--pr` | Skills changed relative to `origin/main` | Pre-PR gate mode (worktree-aware) |
| *(default)* | Modified + newly added SKILL.md files in working tree | Pre-commit gate mode |

---

## Execution Steps

### Step 0. Determine Scope

```bash
# Default: modified and newly added SKILL.md files in working tree
{ git diff --name-only HEAD; git ls-files --others --exclude-standard; } | grep "SKILL\.md"

# --pr mode: PR-relative, worktree-aware (use for pre-PR audits)
git diff --name-only origin/main...HEAD | grep "SKILL\.md"

# --all: full scan
find plugins/ -name "SKILL.md" | sort

# --skill [name]: targeted
find plugins/ -path "*[name]/SKILL.md"
```

If 0 SKILL.md files are in scope, **distinguish the two causes before stopping** — a failed scope
command and a genuinely empty scope both render as zero lines, and only one of them is skippable:

```bash
git rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "HARNESS_ERROR: git unavailable — scope could NOT be measured (not an empty scope)"; exit 10; }

# Repo-liveness alone is NOT enough: a broken ref (e.g. missing origin/main in --pr mode) fails the
# scope command with rc=1 and empty output while rev-parse stays green. Capture the scope command's
# OWN exit status — before the grep, which legitimately returns 1 on no-match:
scope_out=$(git diff --name-only origin/main...HEAD 2>&1); scope_rc=$?
[ "$scope_rc" -ne 0 ] \
  && { echo "HARNESS_ERROR: scope command failed (rc=$scope_rc): $scope_out"; exit 10; }
printf '%s\n' "$scope_out" | grep "SKILL\.md"
# (same rc-capture shape applies to the default and --all scope commands)
```

With both controls green and genuinely 0 files in scope, output:
"No SKILL.md files in scope — audit skipped (control: git rev-parse OK)." and stop.
A HARNESS_ERROR is a distinct non-pass — it must never be reported as "audit skipped", because this
skill is pipeline-conductor's Step 0.5 pre-flight and a tooling-down skip would render as a pass there.

---

### Step 1. Extract Chain Declarations

For each SKILL.md in scope, extract:

1. **`§Chains` section** — every `→ [skill-name]` reference (downstream dispatch)
2. **`§Done When` section** — completion conditions listed by the caller

**Two-pass extraction** (mandatory — do not conflate the two passes):

**Pass A — Caller-wait signals** (look for in §Done When of the *caller* skill):
```
"wait for"          ← waits for callee verdict before proceeding
"verdict received"
"folds back"
"gates on"
"callee returns"
```
These signals indicate the caller waits for the callee's verdict. They are the primary CLOSED gate.

**Pass B — Callee-output signals** (look for in §Done When of the *callee* skill):
```
Verdict: PASS | CONDITIONAL_PASS | FAIL | ESCALATE
```
These signals indicate the callee emits a structured verdict. They confirm the callee side is closeable. They do **not** indicate the caller waits — treat as callee-role evidence only and never conflate with Pass A.

**Step 1 output**:

```
## Step 1 — Chain Extraction

Skill: [skill-name]
  §Chains dispatches: → [callee-1], → [callee-2]
  §Done When (Pass A — caller-wait signals): [extracted text or "none"]
  [callee-1] §Done When (Pass B — callee-output signals): [extracted text or "none"]
```

---

### Step 2. Classify Each Chain as CLOSED or OPEN

Apply the following decision rules per (caller → callee) pair.

**CLOSED criteria**:

1. **(Mandatory)** Caller §Done When has Pass A signals (caller-wait: "wait for", "verdict received", "folds back", "gates on", "callee returns")
2. **(Mandatory)** Callee §Done When has Pass B signals (callee-output: `Verdict: PASS | CONDITIONAL_PASS | FAIL | ESCALATE`)
3. **(Advisory — not independently required)** Caller §Chains uses the closed form: `→ Mandatory next ([callee]) when [condition]; verdict folds back into [step]`

**CLOSED when**: Criteria 1 AND 2 both pass. Criterion 3 adds confidence but is not mandatory — a skill with informal §Chains language that still satisfies criteria 1+2 is CLOSED.

**OPEN when**: Criterion 1 OR criterion 2 fails:
- Caller §Done When has no Pass A signals, OR
- Callee §Done When has no Pass B signals

**Highest-risk OPEN pattern — CONDITIONAL_PASS gap**: Callee §Done When lists conditions under `CONDITIONAL_PASS` but caller §Done When has no mechanism to enforce resolution. Classify as OPEN + flag `CONDITIONAL_PASS gap` in basis.

**Severity assignment** (two dimensions — take the higher tier as final severity):

*Caller tier*:
| Caller identity | Tier |
|---|:---:|
| Core pipeline skill (harvest-loop, steel-quench, apex-review, agent-composer, sim-conductor, pipeline-conductor) | HIGH |
| Diagnostic or gate skill (harness-doctor, phantom-quench, verify-bidirectional, return-path-gate) | MEDIUM |
| Utility or advisory skill (context-doctor, plugin-recommender, frontier-digest, etc.) | LOW |

*Callee consequence tier*:
| Callee output capability | Tier |
|---|:---:|
| Callee can output FAIL or ESCALATE verdicts | HIGH |
| Callee can output CONDITIONAL_PASS verdicts | MEDIUM |
| Callee is advisory only (no structured verdict) | LOW |

**Final severity** = max(caller tier, callee consequence tier).

**Step 2 output**:

```
## Step 2 — Chain Classification

| Caller | → Callee | Status | Severity | Basis |
|---|---|:---:|:---:|---|
| [skill] | [callee] | CLOSED | — | Criteria 1+2 pass; criterion 3 advisory met |
| [skill] | [callee] | OPEN | HIGH | Caller §Done When: no Pass A signals |
```

---

### Step 3. Generate Fix Prescriptions for OPEN Chains

For each OPEN chain, output a specific prescription. Use the Implementation Checklist from `knowledge/shared/harness-core/return_path_gate.md` as the fix template.

**Core FH skill scope check**: If the callee is a core FH skill (harvest-loop, steel-quench, sim-conductor, apex-review, agent-composer, pipeline-conductor), output a **proposal-only note** flagged for human review. Do not generate a standard callee-side prescription — changes to core FH skills have downstream consequences requiring deliberate review.

**Tool limitation**: `allowed-tools` does not include `Write` or `Edit`. All prescriptions are text output only — manual application required.

**Fix prescription format**:

```
### OPEN: [caller] → [callee] (Severity: HIGH/MEDIUM/LOW)

Required changes:

1. [caller]/SKILL.md §Chains:
   Replace: → [callee]
   With:    → Mandatory next ([callee]) when [condition]; verdict folds back into [step N]

2. [caller]/SKILL.md §Done When:
   Add: "Wait for [callee] verdict before proceeding to [next action]"

3. [callee]/SKILL.md §Done When:
   [If callee is a core FH skill] → PROPOSAL ONLY — flag for human review before modifying
   [Otherwise] Add structured verdict block:
   Verdict: PASS | CONDITIONAL_PASS | FAIL | ESCALATE
   Conditions: [list — only present when CONDITIONAL_PASS]
   Basis: [one-line rationale]

4. [callee]/SKILL.md §Chains (if not present):
   Add: "Returns verdict to [caller]"
```

**Simplification guard**: If callee already outputs a structured verdict (Pass B satisfied) but caller only lacks Pass A signals, output only caller-side changes (items 1 and 2).

---

### Step 4. Summary Report

```
## return-path-gate Audit Complete

Scope: [--skill name | --all | --pr | changed files (default)]
Skills audited: N
Chains evaluated: N

Results:
  CLOSED: N chains
  OPEN:   N chains (HIGH: N / MEDIUM: N / LOW: N)

HIGH severity OPEN chains (requires immediate fix):
  - [caller] → [callee]

Next actions:
  - Apply prescriptions above for each OPEN chain
  - Re-run /return-path-gate --skill [name] after each fix to confirm CLOSED
  - HIGH severity chains block pipeline-conductor Step 0.5 pre-flight
```

---

## Done When

```
Step 0 scope determined; a failed scope command reported as
  HARNESS_ERROR, never as empty scope                           — mandatory-pass
+ Step 1 two-pass extraction complete (Pass A caller-wait +
  Pass B callee-output evaluated separately)                    — mandatory-pass
+ Step 2 every (caller → callee) pair classified CLOSED or
  OPEN with two-dimension severity                              — judged (adversarial pairing:
  before ANY chain is reported OPEN, the ground-truth CLOSED
  pair from §Operating Notes must classify CLOSED in the same
  run — an instrument that cannot separate the known pair
  reports nothing)
+ Step 3 fix prescriptions output for each OPEN chain
  (core FH skills: proposal-only)                               — mandatory-pass
+ Step 4 summary report with CLOSED/OPEN counts output          — measured (counts)
```

> Fix prescriptions are text output only (Write not in allowed-tools). Prescription application is manual and out of scope for this skill. Verification of applied fixes requires re-running `/return-path-gate --skill [name]`.

Verdict: PASS (0 HIGH severity OPEN chains) | CONDITIONAL_PASS (MEDIUM/LOW severity OPEN chains only) | FAIL (1+ HIGH severity OPEN chains found)

---

## Connected Skills

| Situation | Connected Skill |
|---|---|
| Check harness structural completeness alongside chain closure | `/harness-doctor` |
| Verify phantom references in §Chains targets (callee skill actually exists) | `/phantom-quench` |
| Run chain audit as pre-flight before parallel dispatch | `pipeline-conductor` Step 0.5 calls this skill |
| Prescribe verdict format for callee skills missing structured output | `/meta-prompt-builder` |
| Chain OPEN finding becomes improvement candidate | `/field-harvest` |

---

## Operating Notes

- **Read callee SKILL.md directly**: Do not infer whether a callee outputs structured verdicts from memory. Always Read the callee's `§Done When` section.
- **Two-pass extraction is mandatory**: Pass A (caller-wait signals) and Pass B (callee-output signals) serve different purposes. Never conflate them — a callee-output signal in §Done When is not a caller-wait signal.
- **Criterion 3 is advisory**: §Chains formal language (`→ Mandatory next ...`) adds confidence but criteria 1+2 are the mandatory gate. A skill with informal §Chains language that still satisfies criteria 1+2 is CLOSED.
- **CONDITIONAL_PASS gate is the highest-risk gap**: A chain where CONDITIONAL_PASS conditions are listed by the callee but the caller has no enforcement path is OPEN even if other verdict paths fold correctly.
- **Scope default is narrow by design**: Default captures modified + newly added files (not just staged changes). Use `--pr` for PR-relative mode in worktrees, `--all` for periodic sweeps.
- **Core FH skill prescriptions are proposals only**: Edits to harvest-loop, steel-quench, sim-conductor, and other core skills require deliberate review — output proposal notes, not standard prescriptions.
- **Reference pattern**: `knowledge/shared/harness-core/return_path_gate.md` defines the canonical closed-loop structure and verified instances (apex-review → sim-conductor, agent-composer ↔ deliberation). These are the ground-truth CLOSED examples for calibrating classification — and that calibration is a Done When condition (Step 2's adversarial pairing), not an optional note.
- **The Pass A signal list is a closed English keyword list — know its degrade direction**: synonyms ("blocks until", "halts on") and non-English documentation will read as false OPEN. That direction is by design (over-report, never silent-close), but treat an OPEN verdict on unconventional wording as a candidate for human reading before prescribing a fix.
