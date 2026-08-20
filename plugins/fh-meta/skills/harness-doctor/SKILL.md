---
name: harness-doctor
description: Scans a project's harness structure (.claude/ directory, CLAUDE.md, rules, agents) to diagnose complexity, drift, missing files, and broken references, then suggests improvements. `--lint` flag adds language-pattern scan (self-marketing, cushion words, version brags). Triggered by "harness check", "structure diagnosis", "CLAUDE.md audit".
user-invocable: true
allowed-tools: ["Read", "Bash", "Glob", "Grep"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - cold_start
    - cross_project
---

# harness-doctor — Harness Structure Diagnosis + Prescription

"A good harness gets simpler over time. If it's getting more complex, something is wrong."

Diagnoses harness structural health across 5 layers and proposes M/S/R prescriptions:

1. **L1 Structural completeness** — required file existence (CLAUDE.md · .claudeignore · .claude/)
2. **L2 Complexity** — current state vs. simplification principle (line count · unused files · duplicate definitions)
3. **L3 Drift** — rule vs. actual pattern mismatch (broken references · stale files · conflicting rules)
4. **L4 Connection diagnosis** *(FH environment only)* — meta hub ↔ field project reference consistency
5. **L5 Pattern analysis** *(FH environment only)* — skill activity · call context appropriateness · effect metrics

---

## Execution Steps

### Step 1. Confirm Diagnostic Target

Check current cwd harness file structure and determine if FH environment (tracks/ + knowledge/ + plugins/ all present).

### Step 2. L1 — Structural Completeness

| File | When Missing |
|---|---|
| `CLAUDE.md` | **M-tier** — harness entry impossible |
| `.claudeignore` | S-tier — context-doctor execution recommended |
| `.claude/` directory | M-tier (when rule files exist) |

### Step 2-E. L1-E — ETCLOVG Layer Coverage *(functional-layer lens — orthogonal to the file-presence table above)*

A harness is not only files; it is **seven functional layers** (ETCLOVG — arXiv:2606.06324, a component
taxonomy *orthogonal* to FH's 6-axis process model; cross-audit
`tracks/_audit/session_2026_06_19_harnessfix-etclovg-cross-audit.md`). FH adopts only the **taxonomy as a
coverage lens** — not the paper's scoring model. A **coverage checklist, not a mandate**: not every
harness needs all seven (a read-only doc harness needs no Execution or Governance). For each layer ask
"is there an asset covering it?"; surface gaps, let the human judge if each is real for *this* harness.

> **Orthogonal-sister ledger (same adoption rule — anchor only, no scoring model imported)**:
> GRACE (arXiv:2607.09175, cross-audit `tracks/_audit/session_2026_07_24_grace-context-rubric.md`,
> operator-local record) — typed-semantic-graph **scoped verification** for the **C (Context) layer's
> maintenance path**: edits validated only within the modified node's local typed neighborhood. Cite
> when a C-layer gap involves *how context updates are verified*, not just whether context assets exist.

| Layer | Covers | Typical FH asset | If the gap is judged real → priority hint |
|---|---|---|---|
| **E** Execution | isolated/reproducible env, bounded autonomy | Agent-dispatch isolation · goal-quench budget | advisory |
| **T** Tooling | tool discovery / selection / gating | mcp_tool_gating · plugin-recommender | advisory |
| **C** Context | what the model sees: card, memory, retrieval | session card · CATALOG · context-doctor | advisory |
| **L** Lifecycle | loops, retries, orchestration, termination | agent-composer · goal-quench | advisory |
| **O** Observability | traces / logs / cost to diagnose failures | subagent_invocations_log · audit logs · activity log | advisory |
| **V** Verification | readiness · intermediate · final · regression checks | 4-axis gate (steel/phantom/regression_guard) | higher-stakes |
| **G** Governance | permissions · approvals · audit trails | HITL gates · public-surface gate | higher-stakes |

**Relationship to the Harness-Defect Taxonomy (below)**: ETCLOVG = *component coverage* (is the layer
present?); the Defect Taxonomy = *failure modes* (is a present layer degrading?). Orthogonal — coverage vs health.

**Check class**: judged (advisory) — the presence test is mechanical, but "is this gap real for this
harness's purpose?" is a judged call, **paired** with the human review at Step 7's M-tier gate. **Never
auto-tier a missing layer into the M/S/R report** — the priority column is a *hint only if a human
confirms the gap*, never a verdict the report emits on its own; surface each gap tagged "(human-confirm)".
(FH's own weak layer is **Observability** — retrospective audit only, no runtime layer; named in the cross-audit.)

### Step 3. L2 — Complexity Diagnosis

**Scope the instrument first — field vs meta** (CLAUDE.md §Identity Core Axis): a **field harness** must get
"simpler over time" (complexity = warning signal), so raw size is a real signal there. A **meta-harness**
(the FH hub itself) *optimizes* rather than simplifies — **complexity earns its scope**, and the doctrine's
red flags are **orphaned, redundant, and decorative units, not size**. Applying the field rule to a
meta-harness produces a false M-tier on healthy growth.

**Scope is mechanical, never self-declared** — else any repo dodges the line rows by calling itself meta
(the self-label loophole CLAUDE.md already names for "docs-only" at the Irreversibility gate). A target is
**meta** iff its root holds **all three**: `tracks/` **and** `knowledge/` **and** `plugins/` (Step 1's FH-environment
test). Anything else is **field** — including a repo that merely *contains* skills or a `.claude/` dir:

**The test is rooted at the TARGET, never at cwd.** FH's own default mode diagnoses a field project
*without* switching cwd (CLAUDE.md §Agent Dispatch — "Direct edit … no cwd switch needed"), so a bare
`[ -d tracks ]` run from the hub misclassifies **every** field target as meta and silently deletes the
field rows — a permissive misread reachable through the harness's own recommended workflow. Always pass
the target path explicitly:

```bash
# meta iff all three exist AT THE TARGET ROOT — otherwise field. TARGET is required, never implied by cwd.
TARGET="${1:?pass the target root explicitly — cwd is not the target}"
[ -d "$TARGET/tracks" ] && [ -d "$TARGET/knowledge" ] && [ -d "$TARGET/plugins" ] \
  && echo "scope: meta ($TARGET)" || echo "scope: field ($TARGET)"
```

Scope is a **coarse instrument-selector, not a security boundary**: `[ -d ]` tests existence, not contents,
so three empty dirs would flip field→meta. That is acceptable here (the operator names the target; there is
no adversary picking it) — but it means scope must never gate anything that matters on its own, only *which
size instrument* is read. The footprint rows below apply to **both** scopes and are the actual verdict.

| Check | Verdict |
|---|---|
| **Field/project** CLAUDE.md 100~200 lines | S-tier warning |
| **Field/project** CLAUDE.md 200+ lines | M-tier — separation or reduction needed |
| **Field/project** 15+ `##` sections in CLAUDE.md | S-tier warning |
| **Meta-harness (FH hub)** CLAUDE.md — raw line / section count | **Not a verdict.** Judge by the always-loaded footprint rows below (char-based = actual token cost) + the doctrine's red flags (orphaned · redundant · decorative). Report the count as context only |
| **Meta-harness — residency ledger** (the positive instrument that replaces the disabled line-count rows) | For each `##` section record **trigger class** (intent / file / ambient) + **backstop** (a hook or script path that must be **grep-verified to exist AND to be wired**, or the literal `none-by-nature`). Tier ONLY these: **M** = a section claiming a mechanical floor whose script is referenced by no hook (a prose-invoked "floor" is not a floor) · **S** = `file`-triggered *with* a verified backstop but still resident (splittable — name the destination glob) · **S** = duplicated verbatim in another section · **R** = orphaned/decorative. A section that is intent- or ambient-triggered with `none-by-nature` is **PASS, not a finding** — moving it would be fail-open. Never tier a section on its size |
| **Meta-harness** growth since last run: decompose into *new sections* vs *existing-section growth* (mechanical — diff `##` section names + line counts vs the prior run's commit; **first run / no prior commit → report both as n/a, no tier**) | **Tier is decided by the two counts alone**: **S-tier iff existing-section growth > new-section growth** (the file is thickening faster than it is gaining capability); otherwise advisory, no tier. Report both numbers **and** the new sections' names — the names are *reporting output for the human*, never an input to the tier. Do not judge "was this growth capability-bearing?" per line |
| SKILL.md > 300 lines AND no `SKILL_detail.md` | S-tier — propose `/salience-splitter` (governance-semantic split, not compression) |
| Rules files unreferenced in CLAUDE.md | R-tier |
| Always-loaded footprint > 40k chars (see scan below for what counts) | S-tier — **lever depends on where the chars live**: rules/detail still auto-loading → relocate to a non-loaded dir (e.g. `knowledge/shared/rules/`), pointers stay in CLAUDE.md · narrative inside CLAUDE.md → `/salience-splitter` · **behavioral content only, nothing left to relocate** → capability-level (merge/retire a governance unit) |
| **Memory-index footprint** — the session's auto-loaded memory index (`~/.claude/projects/<slug>/memory/MEMORY.md`), reported as **its own line, never summed into the row above** | S-tier > 10k chars — **different residency, different lever**: this one is `/memory-hygiene` (archive closed items to `MEMORY_archive.md`, tighten hooks to one line), NOT `/salience-splitter`. Summing it into the CLAUDE.md row would mis-route the lever, which is exactly what the row above ties to "where the chars live". **Blind spot this closes (2026-07-20, measured)**: a fresh top-level `/context` showed **Memory files = 41.7k of 68.8k resident tokens (61%)**, of which `MEMORY.md` alone was **14.1k — 55% the size of CLAUDE.md (25.5k)** — and the footprint scan below counted **none of it**. The instrument was optimising the smaller half of the surface it claimed to measure |
| Always-loaded footprint > 80k chars | M-tier — same lever selection, mandatory, **and never self-discharged** (see below) |
| **Pointer-illusion**: a CLAUDE.md "detail/detailed procedure" pointer whose target is itself an always-loaded `.claude/rules/*.md` | S-tier — the split saves zero context (rules/ auto-loads regardless); move the target out of auto-load, keep the pointer |
| weekly_audit 14~30 days elapsed | S-tier |
| weekly_audit 30+ days elapsed | M-tier |

**Per-unit ≠ aggregate — do not slide between them.** "Every section earns its scope" (the per-unit
doctrine test) and "the always-loaded total is affordable" (the budget test) are **different questions, and
both can be true at once**. A meta-harness can pass the red-flag test on every single section and still be
over its footprint budget. So a per-unit PASS never discharges the footprint rows — and conversely, a
footprint M-tier is *not* evidence that some section failed to earn its scope. When footprint is over
budget but every unit earns its scope, the remaining lever is **capability-level** — merge or retire a
governance unit — **not** a salience split, which by construction only moves narrative and returns ~nothing
when the content is behavioral.

**Any scan-derived count must be calibrated before it is reported.** Before a number from a scan
(broken refs, INACTIVE skills, footprint chars, orphan counts, coverage) enters the report, run it
against **one known-positive and one known-negative** and record both outcomes; then **hand-verify the
single case the scan is most confident about**. If either step is skipped the number ships labeled
`UNCALIBRATED` and may not ground a tier. `not found` is reported as `UNMEASURED`, never as `0` — a
scan that dies mid-run reports a low number, and low numbers read as PASS.
Origin (2026-07-20, three instrument defects in one session): a footprint scan omitted 61% of the
resident surface it claimed to measure · a size ratio was used as a proxy for content coverage · an
ASCII-token scanner run over a Korean corpus produced ~96% false positives and a "70%" figure that was
published to three records before one hand-check reduced it to 3 items. **Suspect the instrument before
the target whenever a value is impossible** (all-pass, all-fail, or a self-scan that fails to detect the
running tool itself). Full procedure: `knowledge/shared/harness-core/measurement-integrity-checklist.md
§Instrument-Calibration`.

**Every M/S-tier must cite the row it fired — verbatim, from this file.** Write the finding as
`M-n · <verbatim row text or its threshold> · <measured value>`. If you cannot quote the row, **you do not
have a finding** — downgrade to an observation. Origin (2026-07-20, instrument defect n+4, the *fourth* in
a single run): a run fired `M-1 · CLAUDE.md 816 lines — exceeds the FH threshold of 500`. The string `500`
did not occur anywhere in this file at the time (a later grep finds 2 — both in this narrative, added by
this very post-mortem; the self-referential claim drifted and is corrected here rather than re-asserted).
🟥 **And that grep was scoped wrong**: it searched this file only. The 500 was NOT invented from nothing —
`docs/platform_sustainability.md` carried it as a live standard until 2026-08-20, contradicting this row.
The lesson is not "the run hallucinated" but **"the absence check was run against the wrong corpus"**
([[feedback_absence_measurement_needs_control]] — a no-hit grep is evidence only when its scope covers
where the thing would actually live). The meta-harness row it claimed to read says raw
line count is **"Not a verdict."** So the run invented a threshold *and* fired a row this skill explicitly
disables for meta-harnesses — the exact recurrence of the 2026-07-15 inversion documented below, which had
already been patched *in the skill*. The patch held; the **run** ignored it. A verdict grounded in a
citation that cannot be quoted is the same defect class as a phantom reference, and it propagates: a
downstream sidecar judgment inherited the fabricated 500 and reasoned from it until a grep caught it.

**No M-tier in this skill is ever self-discharged — not just the footprint one.** "The cost is priced /
accepted", "it's all necessary", "over budget but fine" are **not** verdicts this skill may reach on its
own: an M-tier stands in the report and is closed only by an explicit operator acknowledgment logged to
`tracks/_meta/` (same shape as any other logged override). This is **row-agnostic on purpose** — the
rationale (a run under ship pressure prices away the one row that fired) is not specific to footprint, so
scoping the prohibition to a single row would leave every other M-tier open to the same silent PASS. That
is the default-toward-PASS class `field_verdict_crossfamily_gate.md` exists to catch, committed inside the
diagnostic that names it. **Report it; do not price it.**

> Origin (2026-07-15, dogfood): a run read FH's CLAUDE.md at 891 lines, fired the raw-count M-tier, and
> prescribed `/salience-splitter`. Measurement inverted both halves: **+244 of the +381 30-day growth (64%)
> was 6 new governance sections**, each behavioral and salience-passing (two — Voice/Tone, Envelope-Boundary —
> had been *promoted* to always-loaded precisely because memory-only placement made them miss), and actually
> running the splitter on 4 sections yielded **−27 lines / −3.2k chars (−3.7%)** — confirming salience-splitter's
> own Target Selection rule ("splitting a file with only behavioral content adds structure without governance
> value"). The **footprint** row meanwhile fired M-tier correctly and had been M since 06-15. Two rows measured
> the same property; the worse instrument drove the verdict. The line-count rows are now field-scoped.

Always-loaded + pointer-illusion checks are mechanical (found 2026-07-12 — FH itself shipped ~50k chars of rules/ behind "detail pointers" that saved nothing; the meta-harness blind spot this row closes):

```bash
# always-loaded footprint (chars). Counts every file the session loads before turn 1:
#   CLAUDE.md + CLAUDE.local.md + rules files lacking paths: frontmatter + their DIRECT @-imports.
# EVERY path is rooted at $TARGET — the same root the scope test used. Reading from cwd instead
# measures whichever harness you happen to be standing in (usually the hub, while diagnosing a
# field target) — a wrong-target measurement that reports the hub's number as the target's.
TARGET="${1:?pass the target root explicitly — cwd is not the target}"
# MEMORY-INDEX (reported SEPARATELY — see the memory-index row above; do NOT add it to T).
# It is auto-loaded every session but lives outside $TARGET, so the $TARGET-rooted sum below is
# structurally blind to it. Measured 2026-07-20: it was 55% the size of CLAUDE.md and invisible here.
MEMSLUG=$(printf '%s' "$TARGET" | sed 's|^/||; s|/|-|g')
MEMIDX="$HOME/.claude/projects/-$MEMSLUG/memory/MEMORY.md"
if [ -f "$MEMIDX" ]; then
  echo "memory-index: $(wc -c < "$MEMIDX") chars — $MEMIDX  (lever: /memory-hygiene, NOT salience-splitter)"
else
  echo "memory-index: not found at $MEMIDX — report as UNMEASURED, not as 0 (a missing file is not an empty one)"
fi
T=0
for f in "$TARGET/CLAUDE.md" "$TARGET/CLAUDE.local.md"; do
  [ -f "$f" ] && T=$((T + $(wc -c < "$f")))
done
# find | while, not a glob: an unmatched glob aborts under zsh, and a here-string of "" still yields
# one empty line -> head -5 "" errors and the sum breaks. A scan that dies mid-run reports a LOW
# number (= toward PASS), so guard the empty case explicitly.
while IFS= read -r f; do
  [ -n "$f" ] || continue
  head -5 "$f" | grep -q '^paths:' || T=$((T + $(wc -c < "$f")))
done < <(find "$TARGET/.claude/rules" -name '*.md' 2>/dev/null)
# DIRECT @-imports only (not transitive — a nested import chain is a named residual below).
# Resolve against the IMPORTING FILE's own dir first, then ~/.claude/. SUM into T — never
# print-and-ask-the-reader-to-add: a scan that delegates arithmetic re-introduces the judgment
# it exists to remove, and the omission points toward PASS.
for f in "$TARGET/CLAUDE.md" "$TARGET/CLAUDE.local.md"; do
  [ -f "$f" ] || continue
  d=$(dirname "$f")
  for i in $(grep -oE '^@[A-Za-z0-9_./-]+' "$f" 2>/dev/null | sed 's/^@//'); do
    for c in "$d/$i" "$HOME/.claude/$i"; do
      [ -f "$c" ] && { T=$((T + $(wc -c < "$c"))); echo "  +import $c: $(wc -c < "$c") chars"; break; }
    done
  done
done
echo "always-loaded TOTAL ($TARGET): $T chars"
# Verdict: the HIGHEST tripped threshold wins — 80k supersedes 40k. Reporting only the
# S-tier row while >80k is a silent FAIL->CONDITIONAL_PASS downgrade.
[ "$T" -gt 80000 ] && echo "  => M-tier (>80k)" || { [ "$T" -gt 40000 ] && echo "  => S-tier (>40k)" || echo "  => footprint ok"; }
# pointer-illusion: CLAUDE.md pointers targeting still-auto-loaded rules files (any filename shape)
grep -oE '\.claude/rules/[A-Za-z0-9_./-]+\.md' "$TARGET/CLAUDE.md" 2>/dev/null | sort -u | while read -r p; do
  [ -f "$TARGET/$p" ] && echo "ILLUSION: $p (pointed-to AND always-loaded)"
done
```

**Named residuals of this scan** (all documented, none silent): **transitive imports are not followed** —
an import chain `CLAUDE.md → A.md → B.md` counts A but not B, so a deep chain under-counts *toward PASS*;
**`head -5 … grep '^paths:'`** is a proxy, not a frontmatter parser — an incidental early `paths:` line
falsely excludes an always-loaded rule (toward PASS), while a `paths:` below line 5 over-counts (toward
FAIL, the safe direction); and the scope test reads directory *existence*, so three empty dirs flip
field→meta (acceptable: the operator names the target, and the footprint rows apply to **both** scopes
regardless — but it does skip the field-only line rows).

<!-- Context-File Taxonomy check removed 2026-07-22/23 (#153 → weekly-audit #6 decision): consumer
     re-measure = 0 skills read role:/type: from these files; measured FP 99/161 (61%) un-narrowed,
     19/26 (73%) after narrowing; origin citation was mis-attributed (SPECULATIVE, no primary source).
     Decorative unit per doctrine — FP figures preserved in the removal commit message as the
     regression anchor. Re-adding requires a named consumer first. -->

### Step 3-L. Language Lint (`--lint` mode only)

> Activate with `/harness-doctor --lint` or when harvest-loop surfaces a P10-series signal. Skipped in standard runs.

Grep-based scan of SKILL.md, agent `.md`, and doc files for self-marketing language patterns. Outputs replacement suggestions — no automatic edits.

**Detection patterns**:

| Pattern | Examples | Replacement direction |
|---|---|---|
| Self-declarations of quality | "industry-leading", "the world's first", "core skill", "best" | Delete — no external evidence |
| Version / iteration labels | "v0.3", "22nd naming round", "26th iteration", "(added 2026-05-24)" | Remove (git history manages versioning) |
| Cushion language | "easily", "instantly", "seamlessly", "without burden", "fully automated" | Replace with behavior-based description |
| Owner self-reference loops | "validated by our team", "proven internally" | Delete or replace with external evidence |
| Marketing word stacking | 3+ adjectives in one sentence | Reduce to functional description |
| Spec-only artifacts | SKILL.md or agent file missing `Done When` section | Add observable output criteria |

**Scan targets**:
```bash
find {FH_ROOT}/plugins -name "SKILL.md" | sort
find {FH_ROOT}/.claude/agents -name "*.md" | sort
find {FH_ROOT}/docs -name "*.md" 2>/dev/null | sort
```

**Detection commands**:
```bash
# version / iteration labels
grep -n "v[0-9]\+\.[0-9]\|[0-9]\+th\|[0-9]\+th iteration\|prototype [0-9]\+" {file}
# cushion language
grep -n "fully\|instantly\|full coverage\|automatically\|conveniently\|easily\|without burden\|seamlessly" {file}
# self-declaration patterns
grep -n "core skill\|world's first\|best\|most\|top\|industry-leading" {file}
```

**Output format** (per file):
```
File: {path}
  L{N}: "{original text}"
  → Suggested: "{replacement}" (reason: {pattern type})
  → Or: remove (reason: {pattern type})
```

**Lint findings** feed into Step 7 report as a separate "Language Quality" section — not mixed into structural M/S/R tiers. Lint findings are advisory: HIGH (spec-only = missing Done When, treat as S-tier) / LOW (language patterns, R-tier).

---

### Step 4. L3 — Drift Diagnosis

| Check | Tier |
|---|---|
| Broken local file references in CLAUDE.md | M-tier |
| .claude/rules files unmodified 90+ days | R-tier |
| settings.json JSON syntax error | M-tier |
| Hooks in settings.json (PostToolUse/Stop) that don't fire in Agent View | S-tier or M-tier |
| Public-surface FH recommendation or default changed — no N-shot measurement evidence traceable in session records or PR body | S-tier |
| Pre-commit-adjacent gate reads the working tree (cat/glob of a *tracked* path) with no `--staged`/`--cached`/`git show :` on that path, when its verdict is about *what's committed* | S-tier |

Hook divergence verdict: 0 hooks = Normal · 1+ hooks (session-end/Stop) = S-tier · 1+ hooks (PostToolUse file writes or external API) = M-tier (data loss risk in Agent View).

**Index-vs-worktree gate lint** (2026-06-21, gate-locality corollary — `[[feedback_gate_locality_principle]]`):
a gate whose verdict is about *what is being committed* must read the **staged index**
(`git ls-files --cached` / `git show :path`), not the working tree (`cat`/glob of a tracked file) —
else it false-PASSes a commit whose staged content ≠ disk (origin: `count_check.sh` read the worktree
while the pre-commit hook fired on the index; the sibling `regression_guard` already used `--staged`,
so the lesson existed but was non-local). Mechanical scan — in the pre-commit hook + the scripts it
invokes (+ `scripts/*-check.sh`): flag a `cat`/`<`/glob read of a tracked path with no
`--staged`/`--cached`/`git show :` on that path. **Conditional (NOT universal)**: a gate whose verdict is
about what *runs/deploys* (pre-push tests, build, an auto-fixer that rewrites the worktree) correctly
reads the working tree — a line-level `# worktree-intentional:` comment suppresses the flag. FP surface
(isolated-critic): display/log reads and untracked generated files are not violations → keep advisory
(S-tier, never M).

### Step 5. L4 — Connection Diagnosis *(FH only)*

- Tracks with no sync in 30+ days → R-tier
- CATALOG.md: 5+ open items in recent 5 sessions → S-tier
- Field project CLAUDE.md missing → S-tier
- **Knowledge cross-ref lint**: `knowledge/**/*.md` with no CATALOG.md entry → S-tier
  (index orphan — unfindable via CATALOG-first search); with no inbound reference from
  any CLAUDE.md / rules / SKILL.md / knowledge doc → R-tier (orphan page).
  Mechanical: `grep -L` filenames against CATALOG.md, then `grep -rl` for inbound refs.

### Step 6. L5 — Pattern Analysis *(FH only)*

**L5-A Skill Activity** (grep-based on session records):

| State | Criteria | Tier |
|---|---|---|
| ACTIVE | 2+ times in 30 days | Normal |
| LOW_ACTIVE | 1 time in 30 days | R-tier |
| INACTIVE_30D | 0 times in 30 days | S-tier |
| INACTIVE_90D | 0 times in 90 days | M-tier |

**L5-B Call Context Appropriateness**: Keyword grep for known misuse patterns (hub-persona-auditor in code PR context · sim-conductor without onboarding · harness-doctor self-loop). Report as "suspected (false positive possible)" — no LLM call.

**L5-C Effect Metrics**:

| Metric | OK condition | Tier if failing |
|---|---|---|
| E1 CLAUDE.md lines | Decrease or ±10 | E1_WARN if +50 lines |
| E2 Complexity ratio | ≤100 lines/skill | E2_WARN (≤200) / E2_FAIL (>200) |
| E3 CATALOG open consumption | ≥50% in 30 days | — |
| E4 harvest signals | ≥3 in 30 days | — |
| E5 SKILL.md change | Within 14 days | — |
| E6 Cold audit | Within 30 days | E6_WARN |
| E7 Evolution-loop observability | Asset edits have edit_manifest predictions | E7_WARN = S-tier |

**HHS** (Harness Health Score): Each OK condition = +1 point (7 max). HHS ≥ 4 = Healthy · 2~3 = Caution · ≤1 = Critical.

> **Detail**: See `SKILL_detail.md §L5-Detail` — bash scripts for L5-A, L5-B, L5-C/E metrics — read when running L5 pattern analysis.

---

## Harness-Defect Taxonomy (frontier cross-check)

| Defect class | FH detectable signals | Tier |
|---|---|:---:|
| **Context Drift** | Stale paths in CLAUDE.md (L3) · rules unmodified 90+ days (L3) · CLAUDE.md over threshold (L2) | S |
| **Schema Misalignment** | Plugin count drift · SKILL.md missing `Done When` (undocumented contract) | M |
| **State Degradation** | tracks/ no sync 30+ days (L4) · INACTIVE_90D skills (L5-A) · orphaned memory entries | M |
| **Agentic Laziness** *(runtime)* | Completion claims without per-item evidence — "all N done" with no enumerable list in session records / PR bodies · Done When lacking any mandatory-pass condition | S |
| **Self-Preferential Bias** *(runtime)* | judged-class check without a named adversarial pairing (gate-rejectable for new skills; scan existing for backfill) · a self-graded verdict cited as sole completion evidence | M |
| **Goal Drift** *(runtime)* | Long session with S/A-tier work but no pre-compaction completion log (`fh_completed_*` missing) · early-stated constraints absent from card/manifest at close | S |
| **Comprehension Debt** *(runtime/operator)* | Merged FH-asset change with no CATALOG entry · edit_manifest `validation_status: pending` backlog piling up unverified · session closed with work done but zero card delta | S |
| **Evidence Gap** *(FH self-dev)* | Public-surface FH recommendation or default changed with no N-shot measurement evidence traceable in session records or PR history (L3 check) | S |

Signal in 2+ classes → escalate one tier.
Rows 1–3 = structural (2026-06-02 frontier diagnosis). Rows 4–6 = runtime behavioral, agent-side —
named from dynamic-workflows discourse (2026-06). Row 7 = runtime, operator-side — named from
loop-engineering discourse (Osmani, 2026-06): loop output outpacing operator understanding. FH
countermeasures already exist and are what the signals check for: golden probes + multi-persona
coverage (laziness) · judged-pairing rule (bias) · pre-compaction completion log + card-last guard
(drift) · CATALOG 3-line summaries + manifest predict-verify + card protocol (comprehension debt).

---

### Step 7. M/S/R Prescription Report Output

```
## harness-doctor Diagnostic Results

### 🟥 M-tier (Immediate Action)
### 🟧 S-tier (Strongly Recommended)
### 🟩 R-tier (Recommended)

---
## ETCLOVG Layer Coverage (L1-E)
- Covered: [layers with an asset, e.g. E·T·C·L·V·G]
- Gaps (surfaced, never auto-tiered — each "(human-confirm)"): [e.g. "O Observability (human-confirm) — retrospective audit only, no runtime layer"] or "full coverage"

---
## L5 Pattern Analysis
- Activity (L5-A): [list]
- Context appropriateness (L5-B): [suspected misuse or "no issues"]
- Effect metrics (L5-C): E1=[result] / E3=[result] / E5=[result]

---
## Language Quality (`--lint` mode only)
- HIGH (spec-only — missing Done When): [list or "none"]
- LOW (language patterns): [file: L{N}: "{text}" → {suggestion}]

Diagnostic scope: L1 (+L1-E ETCLOVG coverage) ~L3 [· L4 · L5 (FH only)] [· --lint]
```

M-tier 0 → output "Structure healthy. Maintaining simplification trend."

**M-tier Immediate Human Gate**: If 1+ M-tier found → pause, surface options: (a) AI proceeds to Step 8 / (b) human review first / (c) abort. Do not auto-apply prescriptions that could close a self-referential loop.

### Step 8. harvest-loop Integration *(when tracks/_audit/ exists)*

When 1+ M-tier found → propose adding `## Harness Structure Check (harness-doctor)` section to latest weekly_audit file.

### Step 9. Eval-First Quantitative Gate *(v0.x → v1 promotion only)*

**Thresholds** (measured over 5 sim-conductor runs): Tool Selection Accuracy > 0.90 · Multi-Step Coherence > 0.85 · Clarification Rate < 0.30.

### Step 10. Regression Guard *(when SKILL.md / rules / CLAUDE.md modified)*

Verifies that prescription application didn't strip operational content. Run after prescription applied, at pre-merge gate, or when harvest-loop Step 4 detects file changes.

| Check | Tier |
|:---:|:---:|
| F1 Frontmatter integrity | M |
| F2 Critical section preservation (Execution Steps · Done When · Triggers) | M |
| F3 Code block count not reduced by 4+ | S |
| F4 Operational keyword preservation (M-tier/S-tier/Wave/Step/Done When) | M if ≥50% drop · S if 20~49% |
| F5 Cross-reference paths resolve | M |
| F6 Line reduction ≥30% | S |
| F7 Bash block syntax (bash -n parse) | M if net increase in bad blocks |

Verdict: ✅ PASS (0M 0S) · ⚠️ REVIEW (0M 1+S) · ❌ BLOCK (1+M) · ⏭️ SKIP (검사 대상 0 — **PASS 가 아니다**).

Implementation: `bash templates/regression_guard.sh` (compare vs main) or `bash templates/regression_guard.sh BASE HEAD`.
**Verdict 는 종료코드가 아니라 typed 채널로 읽어라** — `exit 0` 은 pass 와 skip 둘 다다(2026-07-23):
`REGRESSION_GUARD_RESULT_FILE=/tmp/rg.$$ bash templates/regression_guard.sh …` 후 파일의
`result=pass|review|block|skip` 를 판정에 쓴다. `skip` = 미검사 — PASS 로 보고하지 말고 "Axis 1
해당 없음(대상 파일 0)" 으로 보고한다.

> **Detail**: See `SKILL_detail.md §Step-1-3` — bash scripts for Steps 1~6 (L1~L4 diagnostics) — read when running the diagnostic commands.

### Step 11. PR Change Consistency Check *(triggered on "PR" / "push" / branch with FH changes)*

Detect changed files vs main → category-based consistency checks:

| Category | What's checked |
|---|---|
| SKILL.md changes | Plugin description count drift · README skill table · CATALOG entry |
| Agent file changes | README agent count · agent_cards.json count sync |
| knowledge/shared/ changes | CATALOG coverage |
| README.md changed | Stale org/version references |
| AGENTS.md / CLAUDE.md changed | Agent count cross-reference sanity |

Verdict: ✅ CONSISTENT · 🟧 INCONSISTENT (fix before push) · 🟩 REVIEW (intent check).

**Auto-propose** (non-blocking) when "PR", "push", "merge" detected in session.

> **Detail**: See `SKILL_detail.md §Step11` — bash scripts for each consistency check category — read when running PR change verification.

---

## Done When

| Stage | Completion |
|---|---|
| Step 7 M/S/R prescription report output | ✅ Diagnosis complete |
| Step 2-E ETCLOVG coverage line in report (covered layers + gaps, or "full coverage") | ✅ Layer-coverage lens applied |
| M-tier 0 + "Structure healthy" output | ✅ Diagnosis complete (no prescription needed) |
| Step 8 weekly_audit section proposed | ✅ Integration proposal complete |
| Step 9 Eval-First verdict output (when requested) | ✅ Promotion verdict complete |
| Step 10 Regression Guard verdict (PASS/REVIEW/BLOCK) | ✅ Post-fix verification complete |
| Step 11 PR consistency check verdict | ✅ PR pre-push verification complete |

**This skill Done When = "prescription report output complete".** Actual resolution of M/S/R items belongs to user or follow-up work.

**Check classes** (`harness_6axis_framework.md` §Axis 5): report-output completions above = mandatory-pass (report exists or not). M/S/R tier *assignments* = judged — paired with verify-bidirectional when the user challenges a tier.

Verdict: PASS (M-tier 0, "Structure healthy") | CONDITIONAL_PASS (S/R remain, no M) | FAIL (1+ M-tier found) | ESCALATE (structural ambiguity before prescription can be issued)

**Three-Doctor Loop chain** (auto-propose after prescription report):
- M-tier + context/token waste → propose `/context-doctor`
- M-tier + user-facing behavior changes → propose `/sim-conductor Area A`
- SKILL.md S-tier (> 300 lines, no SKILL_detail.md) → auto-propose `/salience-splitter`: `"I see [skill] SKILL.md is [N] lines with no SKILL_detail.md. Want me to run /salience-splitter?"`
- Both → propose full Three-Doctor Loop: context-doctor → sim-conductor Area A

---

## Trigger Phrases

- `/harness-doctor` · "harness diagnosis" · "harness structure check" · "CLAUDE.md audit"
- `/harness-doctor --lint` · "check FH files for marketing language" · "description diet" · "remove marketing language" (→ Step 3-L)
- "my Claude settings seem off" · "something that used to work doesn't anymore" · "skill isn't triggering"
- "PR 올려줘" · "PR check" · "변경사항 영향 범위" (→ Step 11)

No auto-firing — only executes when user explicitly invokes. Step 11 exception: propose as one-liner when "PR"/"push"/"merge" detected.

## Failure Fallback

On Claude API / MCP failure → refer to [`references/fallback-guide.md`](../../references/fallback-guide.md).

---

## Three-Doctor Loop Integration

harness-doctor = **current structure diagnostician**. context-doctor = context collapse. sim-conductor = future behavior prediction. Together: diagnose → prescribe → re-diagnose closed loop.
