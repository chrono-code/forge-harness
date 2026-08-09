---
name: edit-manifest
description: Implements a predict-verify loop for harness edits. Every SKILL.md, rules/*.md, or CLAUDE.md change is paired with a predicted impact stored in a manifest. The next session verifies predictions against actual outcomes, and a validation gate accepts edits only when improvement is measurable. Runs automatically on harvest-loop Step 0-c and on explicit invocation.
user-invocable: true
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
model: sonnet
---

# edit-manifest — Predict-Verify Loop for Harness Edits

> Implements two mechanisms from frontier harness research, named as in their source papers (both terms
> are the papers' own — verified 2026-06-17 against arXiv full text):
> - **Change Manifest** (AHE, arXiv:2604.25850): each edit attaches a manifest entry declaring a
>   falsifiable predicted impact (expected fixes + at-risk regressions); the next round intersects it
>   with observed task-level deltas to produce a per-edit verdict. (Paper: "the Evolve Agent produces a
>   change manifest…".)
> - **Validation Gate** (SkillOpt, arXiv:2605.23904): a candidate is accepted only when its
>   selection-split score is strictly greater than the current selection score (ties rejected); rejected
>   edits are kept in an epoch-local buffer, not silently discarded. (Paper: "validation gate" /
>   "held-out gate".)

FH's regression_guard.sh catches backward regressions. edit-manifest closes the forward
loop: did the edit actually improve what it claimed to improve?

**Boundary vs. verify-bidirectional**: verify-bidirectional is *reactive* — it updates the
baseline when the user raises a counter-argument to an AI recommendation. edit-manifest is
*predictive* — it records a forward prediction at edit time and verifies it against outcomes
later, with no user counter-argument required. Different axes: one responds to challenge,
the other tests a self-declared hypothesis.

## Manifest File Location

```
tracks/_meta/edit_manifest.yaml
```

Single append-only file. Entries are never deleted — they accumulate as the harness's
edit history and negative-feedback buffer.

## Manifest Entry Format

```yaml
- id: em-{YYYY-MM-DD}-{slug}
  date: YYYY-MM-DD
  file: plugins/fh-meta/skills/{skill}/SKILL.md   # relative to repo root
  edit_summary: "added 'trigger phrase X' to natural language triggers"
  predicted_impact: "users entering via phrase X will increase — estimate +1 session/week"
  predicted_measurable_by: "session start logs or user utterance pattern in next 2 sessions"
  validation_status: pending   # pending | verified | falsified | untestable
  validation_type: judged      # mechanical (grep/count/git) | judged (cited observation) | untestable
  baseline_value: null         # number, when a metric exists (mechanical)
  measured_value: null         # filled at VERIFY
  delta: null                  # measured_value - baseline_value, or null
  match_score: null            # at VERIFY: 1.0 confirmed | 0.5 partial | 0.0 contradicted
  verified_at: null
  verification_note: null      # one-line MEASURED outcome + cited evidence (never bare "seems better")
  gate_decision: null   # accepted | redefine | rejected
```

> **Status vocabulary is canonical and machine-greppable** — `validation_status` MUST be one of
> `pending | verified | falsified | untestable`, never freeform prose. The verify pass (Step V1)
> greps these literals; a freeform status like `"predicted — verify next session"` is **invisible to
> the grep and silently never closes the loop** (the format-reconciliation bug fixed 2026-06-16 — put
> the prose in `predicted_measurable_by`, keep `validation_status: pending`).
>
> `baseline_value` / `measured_value` / `delta` apply to **mechanical** entries only; judged and
> untestable entries leave them `null`. **`match_score` is the gate input (Step V3) for all types** —
> the numeric fields are a mechanical-entry audit detail, not a second gate signal.

## Trigger Conditions

### Automatic — Record Phase (on every FH asset edit)

Whenever the **3-axis auto-gate** in CLAUDE.md fires (any SKILL.md / rules / CLAUDE.md edit),
append a manifest entry **before** committing.

> **Wiring note**: This Record step is invoked manually or via harvest-loop until the
> CLAUDE.md 3-axis auto-gate is explicitly extended to call it. The auto-gate currently
> chains regression_guard → steel-quench → phantom-quench; adding edit-manifest
> Record as a pre-step is a proposed extension, not yet wired. Do not assume automatic
> invocation — call it explicitly after an FH asset edit.

### Automatic — Verify Phase (harvest-loop Step 0-c)

At session start (via harvest-loop), read all `pending` entries and attempt verification.

### Manual

| Phrase | Action |
|---|---|
| "check edit manifest", "did our edits work?" | Full verify pass on pending entries |
| "show rejected edits", "what didn't work?" | Display rejected-edits buffer |
| "add to manifest", "record this edit" | Manual Record step |

## Execution Steps

### RECORD mode (called on each FH asset edit)

**Step R1 — Draft Entry**

Prompt the AI (or the user, for high-stakes edits) to fill:
- `edit_summary`: one line, what changed
- `predicted_impact`: what observable improvement is expected
- `predicted_measurable_by`: how and when this can be checked

**Step R2 — Append to Manifest**

```bash
# Append YAML block to tracks/_meta/edit_manifest.yaml
```

Output confirmation: `edit-manifest: entry em-{date}-{slug} recorded`

**Step R3 — Flag Untestable Predictions**

If `predicted_measurable_by` is vague ("generally better", "feels cleaner") → mark
`validation_status: untestable` immediately. These are tracked separately as a signal
that the edit rationale needs sharpening.

---

### VERIFY mode (harvest-loop Step 0-c or manual)

**Step V1 — Load Pending Entries**

```bash
# canonical pending + legacy freeform "predicted ..." entries (transition: reconcile legacy to pending)
# \b anchors the alternation so 'pending_review' / 'predicted_outcome' (non-canonical) still surface as legacy, not swept as pending
grep -nA22 -E 'validation_status: *"?(predicted|pending)\b' tracks/_meta/edit_manifest.yaml
```

Skip entries where `predicted_measurable_by` date has not yet passed. **Reconcile any legacy
freeform `validation_status: "predicted — ..."` entry to `pending` (move the prose into
`predicted_measurable_by`) as you touch it — otherwise it stays invisible to future passes.**
**Reconciliation completeness** (a half-reconciled entry stays unverifiable): when you touch a legacy
entry, also backfill the fields a canonical entry needs — generate a missing `id`
(`em-{date}-{slug}`), set `file:` from the edit's target, and set `validation_type` explicitly (default
**mechanical** when `predicted_measurable_by` names a grep/count/git check; **judged** when it names a
reviewer observation). A missing `validation_type` is not a silent default — name it, or the entry
can't be scored consistently across passes.

**Step V2 — Verify Each Entry**

First classify the entry by `validation_type`, then collect evidence accordingly:

- **mechanical** — prediction is a count/presence checkable by grep/git. Record `baseline_value` →
  `measured_value` → `delta`. The check IS the evidence (non-vacuous by construction).
- **judged** — prediction needs reviewer judgment. Requires **one concrete cited observation**
  (file:line / a quoted signal), never a bare "seems better". No citation → stays `pending`, not verified.
  **Non-Model Ground (the citation must be tool-confirmed, not asserted)**: the cited file:line MUST be
  confirmed by an actual Grep/Read **in this verify pass** and the tool output (the matched line) pasted
  into `verification_note` — a citation-shaped string asserted from memory is NOT evidence. An
  unverifiable / un-pasted citation caps `match_score` at **0.5** (never 1.0). This is the same anchor
  discipline as phantom-quench: a verdict rests on a surfaced span, not a claim that one exists.
- **untestable** — no observable evidence source. Mark `untestable`, do not score.

For each entry, check the evidence source specified in `predicted_measurable_by`:

| Evidence Source | Check Method |
|---|---|
| Session utterance patterns | Grep `tracks/_meta/` for trigger phrases |
| Skill invocation count | Read `knowledge/shared/learnings/subagent_invocations_log.yaml` (create if absent) |
| User friction signals | Grep `tracks/_meta/fh_signal_*.md` for related friction |
| Git commit frequency | `git log --oneline --since={date} -- {file}` |

Then score `match_score`: **1.0** = evidence clearly confirms the prediction · **0.5** = partial/ambiguous
· **0.0** = contradicted or no-occurrence. Record the score + the cited evidence in `verification_note`.

> **Circularity guard**: edit-manifest is invoked *by* harvest-loop (Step 0-c). To avoid a
> circular evidence loop, edit-manifest must NOT use harvest-loop's own synthesis outputs
> (proposal lists, curator decisions) as verification evidence. Evidence sources are limited
> to primary signals — raw utterance logs, invocation counts, git history, friction signals —
> that exist independently of any harvest-loop run.

**Step V3 — Apply Validation Gate**

| `match_score` | status → Gate Decision | Next Action |
|---|---|---|
| ≥ 0.75 | `verified` → `accepted` | No action needed |
| 0.25–0.75 | `verified`(partial) → `redefine` | Sharpen the prediction/edit; note what partially held |
| ≤ 0.25 | `falsified` → `rejected` | Add to rejected-edits buffer; propose revert if regression |
| no evidence / window not matured | keep `pending` | Re-check next session |
| no evidence source | `untestable` | Flag for human judgment |

**Step V4 — Rejected-Edits Buffer Report**

After verification pass, output rejected entries as a learning signal:

```
edit-manifest: verification complete
  Verified (accepted): N
  Falsified (rejected): N
  Still pending: N
  Untestable: N

Rejected edits (negative feedback buffer):
  em-2026-05-28-trigger-phrase: predicted "+1 session/week via phrase X"
    → falsified: no utterance evidence in 7 sessions
    → proposed revert: [y/N]
```

**Step V5 — Update Manifest**

Apply `verified_at`, `verification_note`, `gate_decision` to each resolved entry via Edit.

## Validation Gate Logic

Mirrors SkillOpt's validation gate (the held-out gate over its selection-split score):

```
IF verified evidence shows improvement:
    gate_decision = accepted (edit stays)
ELSE IF falsified (no improvement or regression):
    gate_decision = rejected
    → retained in manifest as negative feedback
    → future edit proposals for same file grep rejected entries first
    → propose revert to human
ELSE:
    stay pending
```

**Rejected-Edit Reuse**: When proposing a new edit for a file, the AI must grep
`edit_manifest.yaml` for prior `rejected` entries on that file and explicitly
state why the new proposal avoids the same failure mode.

## Constraints

- **Append-only**: Never delete manifest entries. Rejected edits are the most valuable
  learning signal — they prevent the same mistake twice.
- **Human gate on revert**: Gate decision `rejected` proposes revert; human confirms.
- **Simplification guard**: If no pending entries exist, output one line
  "edit-manifest: no pending entries" and exit.
- **Untestable rate alarm**: If `untestable` entries exceed 30% of total, flag:
  "edit rationale quality degrading — predictions are not falsifiable."

## Done When

```
RECORD mode:
  Entry appended to edit_manifest.yaml
  + Untestable flag applied if vague prediction

VERIFY mode:
  All pending entries checked (canonical + legacy freeform reconciled to pending)
  + Final output line, EVERY exit path including no-pending: literal `Verdict: PASS` |
    `Verdict: PASS (no pending entries)` | `Verdict: CONDITIONAL_PASS` (rejected buffer non-empty —
    attach the list on the same line) | `Verdict: FAIL` — nothing after it; callers gate on this
    line (return-path audit + codex S2 2026-08-10)
  + validation_type classified (mechanical / judged / untestable)
  + match_score recorded with cited evidence (mechanical: delta; judged: one cited observation)
  + Gate decisions applied (accepted / redefine / rejected / pending)
  + Rejected-edits buffer reported
  + Manifest file updated via Edit
  + Human gate presented for any proposed reverts
```

**Check class** (per `harness_6axis_framework.md §Axis 5`): the verify pass itself is *measured* for
mechanical entries (delta is a number) and *judged* for judged entries — the judged path is kept
non-vacuous by the **mandatory cited observation** (no citation → stays pending, never auto-verified).

## References

- Theoretical basis: AHE (arXiv:2604.25850) §4 change manifest + prediction falsifiability
- Validation gate: SkillOpt (arXiv:2605.23904) §3.3 validation/held-out gate over the selection-split score + rejected-edit buffer
- Integrates with: `harvest-loop` Step 0-c · `verify-bidirectional` · 3-axis auto-gate (CLAUDE.md)
- Manifest file: `tracks/_meta/edit_manifest.yaml`
