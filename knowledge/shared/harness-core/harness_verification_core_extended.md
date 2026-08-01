# Harness-Verification Doctrine — core lens vs cluster instruments

> Crystallized 2026-08-01 from the field→meta reverse-verification arc (operator-proposed boundary,
> evidence-gated GO the same day). Companion to `harness_incubator_doctrine.md` — the nursery does not
> only birth harnesses; it **verifies what it births and accelerates**. Always-loaded summary:
> `CLAUDE.md §Identity` (one clause). Sibling invariant: `sonnet_floor_doctrine.md` (same shape,
> different axis).

## 1. The axis this doctrine names

FH's verification of harnesses (its own assets, and the field harnesses it incubates or accelerates)
has two structurally different sources of lift:

| Mode | What it is | Availability |
|---|---|---|
| **Core** | Verification questions FH/PMH can ask **natively, with no cluster member present** — methodology internalized as FH's own lens | Must hold stand-alone (cluster-independent) |
| **Extended** | Verification **instruments** dispatched from the multi-harness cluster — a field QA harness's audit lens, a trace-boundary auditor, a process-fidelity/judge harness | Available when the cluster member and its consent lane are |

**First clause (the boundary)**: *harness-verification core = the FH-native triad-consistency lens;
harness-verification extended = cluster instruments.* The operative test is **what discharges the
capability at the floor**: discharged by a portable methodology or by an asset FH itself ships →
core; discharge requires a cluster member's running engine → extended. Form (question vs instrument)
is the usual correlate, not the criterion — and class membership can migrate: a class listed as
extended today (e.g. trace auditing) becomes core the day FH ships a native carrier for it (the
pilot's mechanized transcript adapter is exactly such a candidate). **Precedence rule** (the test
looks through to the discharge dependency): an FH-shipped *thin client* whose verification work is
actually done by a cluster member's engine is **extended** — shipping a wrapper does not internalize
a capability; core requires that the discharge **completes with no cluster member present**. And
"core" names a **requirement placed on the capability, not a certification** that today's route
meets it at every tier — the floor-conformance question is a named residual (§5).

This is the Sonnet-Floor doctrine's shape applied to verification: base capability must be 100%
present at the floor (no cluster required); reinforcement is dispatch, never substrate. A
verification ability that silently requires a cluster member is a tier-gated-capability defect in
this axis, exactly as a base op that requires Opus is in the model axis.

## 2. The core lens — static triad consistency (spec ↔ implementation ↔ TC)

The internalized question: **"do the spec surface, the implementation, and the test/TC set agree with
each other?"** — coverage of the *declared contract*, not adversarial pressure on an asset in
isolation. FH's native verification stack (asset-unit adversarial review, lane suites, phantom/grounding
audits) structurally does not ask it **in general form**: narrow spec↔repo agreement checkers exist
(the pre-commit new-skill count-consistency slice, `scripts/count_check.sh`) but they are point
checks on declared counts, while the triad lens interrogates the **agreement between three
artifacts** across the whole declared contract. Measured consequence of not asking the general
question: pinned
counts rot against grown suites, implementations ship with no spec presence (orphan implementations),
and opt-out semantics drift between spec text and code comment — all invisible to per-asset review,
all found on first application of the lens (see §4).

Why this is *core*, not a borrowed instrument: the lens is a **methodology** (a MECE
spec-coverage matrix + a three-way traceability table + findings with per-item grounding), learned
from a field QA harness's protocol doctrine but askable without it. The field harness taught the
question; it is not needed to ask the question.

**Internalization status (honest label)**: dispatched-procedure level today — the recipe below is
the public, runnable discharge route; no dedicated FH asset (skill or mechanical spec-sync checker)
carries it yet. Building that carrier follows the evidence-threshold build discipline: the second
real demand decides the form. What is already doctrine-binding now: **a "verify this harness"
engagement must be able to run the triad lens without any cluster member present** — by the recipe
below if no native asset exists yet. Entry point: the lens is a row in the Field-Harness Diagnostic
composition (`field_harness_diagnostic.md`), so a "diagnose this harness" ask routes to it without
anyone recalling this file.

**Dispatched-procedure recipe (public — runnable with no cluster member; pilot-grade provenance,
§5 scale residual applies)**, the pilot's Step 1 generalized: ① fix the subject slice — spec docs, implementations, their test suites, and
**mechanically include every enforcement owner the spec names and every test file that references
the subject** (the pilot's only false findings came from a hand-fed slice omitting these); ②
calibrate on a known pair before trusting output — one documented-but-uncovered residual the lens
must independently re-derive, one well-covered region where any reported gap is a false positive; ③
dispatch one **context-decorrelated** agent loaded with only the slice plus the audit method — a
spec-coverage MECE matrix (spec clause × covering TC), a three-way traceability table (spec ↔
implementation ↔ TC, orphans named on all three sides), findings each carrying a file:line ground —
and forbidden from loading the subject harness's own verification doctrine (the decorrelation is the
point); ④ the governor source-grounds every finding via a mechanical anchor (grep, execution),
classifying re-derived / novel-grounded / rejected; ⑤ findings are proposals — HITL, nothing
auto-fixed.

## 3. The extended mode — cluster instruments, UNION composition

Instruments the cluster contributes are **class-disjoint** from the core lens, and from each other,
by observation modality (first measured 2026-08-01, instrument-triple run on one FH slice —
finding-class intersection **zero**):

- **Static triad lens** (core, above) — sees spec/implementation/TC disagreement. Principally blind
  to runtime events: a trace auditor's violation classes do not exist in static artifacts.
- **Trace/boundary auditors** (extended — e.g. a HarnessAudit-style fence/severity channel over a
  machine-written transcript) — see runtime boundary violations and blocked attempts. Principally
  blind to static drift: a rotten spec count is not an event in any trace.
- **Process-fidelity / judge harnesses** (extended — e.g. a DeepEval-style expected-tool-set +
  LLM-judge leg) — see procedure deviation; conceptual overlap with trace auditors on some classes,
  different mechanism, still zero overlap with the static class.

Composition rule: **detection composes by UNION** — the model-ensemble union pattern
(operator-measured, held in operator memory: detection = UNION lift, generation = voting; the
instrument-level measurement is §4 item 3) generalizes from model diversity to **instrument
diversity**. Blindness between these instruments is principled (modality), not a performance gap, so
adding reps of one instrument is not expected to cover another's class (principled claim, measured
once — §5); only adding the other instrument does.

Extended-mode discipline (unchanged invariants, restated for this surface): cluster dispatch rides
the existing consent lanes and residency rules; instrument findings are evidence candidates until the
governor source-grounds them via a mechanical anchor (grep/known-pair), never verdicts by agreement;
and the audit channel must be one the audited session cannot rewrite after the fact (a
machine-written transcript, not a self-attested action list — the pilot's Run #3 exists because its
Run #2 violated exactly this and was sealed the same day).

## 4. Evidence base (why this graduated to doctrine)

Four runs, one day (2026-08-01), two subjects; runs 1, 3 and 4 instrument-calibrated FH-side
(known-pair) before any number was trusted — run 2's calibration record is company-side (item 2
below):

1. **Run #1 (FH slice)** — the field QA lens, context-decorrelated (the auditing agent read none of
   FH's verification doctrine), CALIBRATED, produced **7 novel grounded findings** — every one in the
   spec↔implementation↔TC disagreement class; three S-tier were fixed on a same-day branch.
2. **Second-subject replication (PMH, company environment)** — the same design reproduced the lift on
   a different meta-harness: 7 novel grounded findings (1 S · 3 M · 3 R), three fixed same-day.
   N=2 subjects supports reading the lens as a defect-class detector rather than a one-harness
   quirk. (Calibration status of this run is recorded company-side only — residency boundary; the
   FH-side judgment stands on runs 1, 3, 4 alone.)
3. **Instrument-triple UNION run** — three instruments over one governed/mutant trace pair:
   finding-class intersection zero; discriminating control separated (governed vs mutant) on every
   instrument. First measurement of the class-disjointness §3 argues (single slice, single pair —
   the principled-blindness argument carries the rest; §5).
4. **Mechanized trace adapter** — the self-attested-trace residual sealed by extracting actions from
   the session's machine-written transcript; known-pair PASS, one live false-positive (data-vs-execution
   confusion) hand-verified and fixed same-day with a regression pair.

Operator-local records (gitignored, referenced for the operator's own audit trail):
`tracks/_meta/qasp_reverse_verification_run_2026-08-01.md` · `…_run2_2026-08-01.md` ·
`…/run2_instrument_calibration_2026-08-01.md` · design doc same directory.

## 5. Honest residuals (named, not waived)

- **Scale**: subjects = 2, trace pairs = 1, mutant = synthetic counterfactual; judge separation
  measured only on a degenerate (trivially-separable) pair. Fine-discrimination (partially-compliant
  traces) is unmeasured.
- **Adapter limits**: compound commands collapse to first-match class; quoted-string operation text
  remains a false-positive reserve; approval detection is keyword-level.
- **No native carrier yet** for the core lens (see §2 status label) — until one ships, "core" is a
  doctrine obligation discharged by the §2 recipe, and this gap is the first thing a triad-lens
  audit of FH itself should re-find.
- **Floor tier unmeasured**: the pilot runs executed at frontier tier. Whether the §2 recipe holds
  at the Sonnet floor is unmeasured — per the sibling invariant, the first floor question to close.

## Done When (doctrine doc — reference asset)

- `CLAUDE.md §Identity` clause, `harness_incubator_doctrine.md` §3-b, and this doc tell one
  consistent story (core/extended boundary stated identically). *Check class: judged; pair:
  contradiction scan on ingest.*
- Every mechanism named here points at a real existing asset or is explicitly labeled
  doctrine-only/unbuilt (§2 status, §5). *Check class: mandatory-pass (phantom scan).*
