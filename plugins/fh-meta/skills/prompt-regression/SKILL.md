---
name: prompt-regression
description: Statically checks harness assets against a known-answer probe set after rule/skill changes — inspects the changed source for the trigger phrases, chain links and gate conditions each probe expects, and reports PASS/FAIL/SKIP per probe. Source inspection only; it does not run live sessions, so it catches assets that no longer SAY the right thing, not models that stop DOING it. Triggers on "prompt regression", "did my changes break anything", "regression check", "test harness changes".
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - full_suite
    - cross_skill_impact
---

# prompt-regression — Harness Regression Detection

After CLAUDE.md edits, rule changes, or new skill additions, harness behavior can silently regress. This skill runs a lightweight probe suite against the changed assets and compares outputs against saved baselines to surface regressions before they reach production.

> **Scope distinction**
> - harness-doctor: structural completeness (files, links, drift)
> - prompt-regression: **behavioral correctness** — did the change alter expected AI response patterns?

---

## Triggers

- `/prompt-regression`
- "prompt regression", "regression check", "regression test"
- "did my rule change break anything", "test harness changes", "verify harness behavior", "make sure my edit didn't change behavior"
- After significant CLAUDE.md edits or new skill commits

---

## Execution Steps

### Step 1. Identify Changed Assets

```bash
# What changed since last commit (or last N commits)
git diff HEAD~1 --name-only -- CLAUDE.md .claude/ plugins/
```

Classify each changed file:
- `CLAUDE.md` → **core behavior** (high impact)
- `.claude/rules/*.md` → **rule layer** (medium impact)
- `plugins/*/skills/*/SKILL.md` → **skill behavior** (scoped impact)
- `plugins/*/skills/*/SKILL.md` (trigger phrases changed) → **trigger routing** (high impact)

If no changes detected: report "No harness changes since last commit — regression check skipped."

---

### Step 2. Load Probe Suite

Check for custom probes:
```bash
ls .claude/regression/probes.md 2>/dev/null || echo "NO_CUSTOM_PROBES"
```

**If custom probes exist**: load and use them. The hub repo ships its golden probe set
(known-answer offline eval, **33 probes** with check classes — 27 mandatory-pass · 1 measured ·
5 judged, of which 2 rows are inert deletion anchors, so live coverage is 31) at exactly this path
— when present it is canonical and supersedes the default matrix below.

> Count from the file, not from this line: `grep -cE '^\| *`[A-Z][A-Z0-9-]*-[0-9]+` *\|'
> .claude/regression/probes.md`. Both this number and the tally inside `probes.md` read `32` until
> 2026-08-12, when the actual count was 33 — a probe had been added to section A without touching
> either summary. A count duplicated in two files rots independently; if the two disagree, the file
> wins and both get corrected.

**If no custom probes** (e.g. Mode C install without the hub repo): use the default
probe matrix below.

#### Default Probe Matrix

| Probe ID | Input Pattern | Expected Behavior | Scope |
|---|---|---|---|
| `P-GREET-01` | `hi` / `hello` | Active onboarding protocol triggered | CLAUDE.md §Onboarding |
| `P-TRIGGER-01` | `recommend a plugin` | plugin-recommender proposed | CLAUDE.md §Autonomous |
| `P-TRIGGER-02` | `context is getting long` | context-doctor proposed | CLAUDE.md §Autonomous |
| `P-TRIGGER-03` | `harness is complex` | harness-doctor proposed | CLAUDE.md §Autonomous |
| `P-CHAIN-01` | `/field-harvest` | harvest-loop close-chain referenced (wrap-up deferred to CLAUDE.md session-close chain — field-harvest has no inline sim-conductor gate) | field-harvest SKILL.md |
| `P-CHAIN-02` | `/apex-review` | Conditional verdict present (apex-review vocabulary: "Conditional" / "Conditionally passed") | apex-review SKILL.md |
| `P-GATE-01` | new skill commit | New Skill Pre-Commit Gate (6 items, incl. check-class declared) invoked | CLAUDE.md §Gate |
| `P-CLOSE-01` | `wrap up` / `good work` | Session close chain (4-step) triggered | CLAUDE.md §Wrap-up |

---

### Step 3. Map Changes → Affected Probes

| Changed File | Affected Probes |
|---|---|
| `CLAUDE.md` §Onboarding | P-GREET-01 |
| `CLAUDE.md` §Autonomous Initiative | P-TRIGGER-* |
| `CLAUDE.md` §Wrap-up | P-CLOSE-01 |
| `CLAUDE.md` §New Skill Gate | P-GATE-01 |
| `plugins/fh-meta/skills/*/SKILL.md` | P-CHAIN-* matching skill |

If change scope is `CLAUDE.md` core (10+ lines changed): run **full suite** (all probes).

---

### Step 4. Evaluate Affected Probes (static source inspection)

**What this step is, stated plainly.** Every check below reads the changed *source* and asks whether
the text a probe expects is still there. No live session is started, no model is prompted, no output
is compared against a recorded transcript. The description said "running standard prompt probes …
comparing outputs against saved baselines", which reads as live execution; the honest label is a
**known-answer static check**.

**What it therefore cannot catch** — say this in the report, do not leave it implied:
- a rule that is still present but has stopped *firing* (salience loss, ordering, competition
  from another rule)
- a trigger phrase present in the file but shadowed by a higher-priority route
- any behavior change that leaves the source text identical

Those need a dispatched blind sim at the target tier (`sim-conductor`, or the target-tier sim gate in
`.claude/rules/fh_4axis_gate.md`). A green report here means *the assets still say the right thing*.
Treating it as behavioral evidence is the misread this section exists to prevent.

For each affected probe, evaluate:

**4-a. Trigger routing check** — Does the trigger phrase still map to the expected skill/behavior?
- Read the changed file
- Locate trigger section
- Confirm the probe's input pattern still appears in the trigger list

**4-b. Chain integrity check** — Are mandatory chains still present?
- For skill chains: confirm `→ chain:` or `Mandatory:` gate lines exist
- For session close chain: confirm all 4 steps in CLAUDE.md §Wrap-up

**4-c. Gate presence check** — Are gate conditions still enforced?
- Pre-commit gate: confirm all 6 items present in CLAUDE.md (incl. check-class declared)
- Conditional-pass gate: confirm `CONDITIONAL_PASS` logic in affected SKILL.md

Output per probe:
```
[PASS] P-TRIGGER-01 — plugin-recommender trigger phrase found in CLAUDE.md
[FAIL] P-CHAIN-01 — field-harvest SKILL.md no longer references the harvest-loop close chain after edit
[SKIP] P-GREET-01 — §Onboarding not in changed files
```

---

### Step 5. Regression Report

```
## Prompt-Regression Report — YYYY-MM-DD

### Changed Assets
- CLAUDE.md (§Autonomous Initiative — 3 trigger phrases modified)
- plugins/fh-meta/skills/field-harvest/SKILL.md

### Probes Run: 4  |  Pass: 3  |  Fail: 1  |  Skip: 4

### FAIL Details
| Probe | Location | Finding | Fix |
|---|---|---|---|
| P-CHAIN-01 | field-harvest SKILL.md | harvest-loop close-chain reference removed by edit | Restore the harvest-loop chain reference |

### Verdict
⚠️ REGRESSION DETECTED — 1 probe failed. Fix required before merge.
```

If all probes pass:
```
✅ NO REGRESSION — All N probes passed. Safe to merge.
```

---

### Step 6. Baseline Update (on explicit user approval)

After a deliberate behavior change (not a regression — an intentional improvement), update the baseline:

Prompt user first: *"Probe `G-GATE-03` now expects the new gate format. Update baseline? (y/n)"*
Only update on explicit `y` — never auto-update.

On `y`, actually perform the write. The previous version of this step was three lines of which two
were comments — it created the directory and stopped, so "baseline updated" was reported by a step
that had written nothing.

```bash
mkdir -p .claude/regression
```

Then **use the `Write` tool** on `.claude/regression/probes.md` (create it from the SKILL.md default
matrix if absent) to apply the approved edit. Each approved change edits the probe's row in place —
Expected Behavior, Scope, and Class — and:

- update the `**Count**:` tally line **in the same edit** if a row was added or removed, including
  the per-section breakdown and the class counts (a stale tally is exactly how the `32`/`33`
  mismatch was introduced)
- append a one-line note under `**Baseline**:` recording the date and the reason for the change
- never rewrite rows the user did not approve

Confirm afterwards by re-reading the file and reporting the row's new content plus the recount —
`grep -cE '^\| *`[A-Z][A-Z0-9-]*-[0-9]+` *\|' .claude/regression/probes.md`. Do not report a
baseline update whose result you have not read back.

---

## Done When

- All affected probes are evaluated (PASS / FAIL / SKIP) and the three counts sum to the number of
  probes selected in Step 3 — class: measured (`PASS + FAIL + SKIP == selected`)
- Regression report is output with clear PASS/FAIL verdict — class: mandatory-pass
- The report states its own scope: **static source inspection, no live session run** — a green
  verdict is never presented as behavioral evidence — class: mandatory-pass
- If FAIL: specific file + line fix is recommended — class: judged, paired with verify-bidirectional (the fix recommendation is re-checked, not trusted as-is)
- Baseline updated only on explicit user approval, and the written file is **read back** and its
  probe count reported — class: mandatory-pass (HITL). Approval alone does not close this: a step
  that prompts, gets `y`, and writes nothing satisfied the old wording.

---

## Chains

**Upstream** (runs before this skill):
- Automatically triggered after significant harness commits (Step 1 detects via git diff)

**Downstream** (runs after FAIL verdict):
- → `harness-doctor` for structural fixes if L1/L2 issues found
- → `verify-bidirectional` to confirm fix resolved the regression
