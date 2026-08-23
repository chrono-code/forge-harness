# Measurement-Integrity Checklist — cross-model measurement pre-flight

> A cross-model measurement is only trustworthy if its **instrument** is verified first.
> Measurement integrity is a *precondition*, not a result. Four observed failure modes, each with a
> concrete countermeasure. Consult this before any FH measurement that compares models (sims, sidecar
> comparisons, capability-equalizer runs, the-bible model panels, A6-class experiments).

This is a **checklist a measurement consults**, not a gate with triggers and not a dispatch surface —
hence a knowledge doc, the lightest asset that holds it (a harness gets simpler over time). If it ever
becomes a gate other skills invoke, revisit the weight.

## The three failure modes + countermeasures

| # | Failure mode (observed) | Countermeasure |
|---|---|---|
| 1 | **Silent model fallback** — passing a model *slug* silently resolved to a weaker model (e.g. an `agy` slug fell back to Flash) instead of the intended one. The run *looks* like the named model but isn't. | **Pin the display name, not the slug** (e.g. `"Gemini 3.1 Pro (High)"`, not a bare slug). Confirm the resolved identity, don't assume the slug binds. |
| 2 | **Non-deterministic borderline verdicts** — contested/borderline cases flip across runs (observed: haiku 4/4 flip; flagship models flip too — flipping is **not** a tier signal). A single draw is noise, not a measurement. | **reps ≥ 3 on any borderline/contested verdict.** A single run on a contested case is inadmissible. Report the flip pattern (STABLE vs FLIP), not just the modal verdict. |
| 3 | **Generic self-identity probe** — a probe any model passes ("are you working? → OK") proves nothing about *which* model answered. | **Use a discriminating probe** — one that two different models answer *differently*. A generic-pass probe is invalid. The probe is a **pattern, not a fixed string**: a probe that discriminates Opus 4.8 from Sonnet 4.6 today may both-pass a future model generation, so **re-validate the probe each model generation** (same staleness class `memory-hygiene` exists to catch). |
| 4 | **Serving-path / quantization variance** — the *same* display-name model served over two different backends (different quantization/infra) is a **different instrument** and yields materially different measurements. Observed: one GLM-5.2 model family gave effect-size delta **+0.21** when served via an internal NVFP4-quantized deployment vs **+0.08** via an OpenRouter relay — same model name, ~2.6× different effect (n=864, reps≥3). A correctly-pinned display name (item #1) is **necessary but not sufficient**. | **Pin *and record* the serving path** — backend host + quantization, not just the display name. Two runs are comparable only if the serving path matches; a name match across different infra is an implicit apples-to-oranges. When you cannot hold it fixed, **report the serving path as a measured variable**, not a constant. |
| 5 | **Injected-context contamination (blind-sim class)** — a subagent dispatched to evaluate a *modified* instruction file answers from the **auto-injected project context** (claudeMd/memory baked into its system prompt at spawn) instead of reading the target. Observed twice in one session (2026-07-17): a "blind sim" quoted section numbering that existed only in the pre-edit file, and a second sim cited trigger-table rows that had been **deleted** from the file it claimed to have read — tool-use count 0–1 in both. The measurement *looks* grounded (fluent, plausibly cited) but the instrument never touched the target. A prompt-line telling it to ignore injected context is **not sufficient** — both runs had one. | **Force mechanical grounding a stale answer cannot fake**: ① stage the target at a **neutral path** (tmp copy) the injection cannot cover; ② require **verbatim quotes** (or grep line-number output) from that path for every claim; ③ design the probe around a **content discriminator** — something present only in the new version, or *absent* from it (a deleted row cited = instant invalidation); ④ treat **tool-use count as a validity signal** — a sim that "read two files" with 0–1 tool calls is invalid regardless of answer quality. Re-run, don't argue with a contaminated result. |

## Why these are entangled (and why they matter beyond their own scope)

Item #2 (reps≥3) is the discipline that **retracted half the evidence** for the
`[[feedback_correlated_blindspot_union_over_majority]]` finding — one of its two supporting cases
turned out to be non-deterministic borderline flipping, not a stable correlated blind spot. So this
checklist is the **prerequisite** for any "correlated error" claim: you cannot call an error correlated
(and prescribe union-over-majority) until reps≥3 has distinguished a stable correlated error from a
single-draw artifact. Item #3 (discriminating probe) **embodies** the judge-robustness /
mechanical-anchor principle — don't trust self-reported identity, prove it discriminatingly
([[feedback_judge_robustness_mechanical_anchor]]).

Item #4 (serving-path variance) **sharpens** item #1 into a two-part identity: #1 catches the *wrong
model* (a slug that fell back); #4 catches the *right model on the wrong instrument* (a correct name
served over a different quantization/backend). The verified identity a measurement records is therefore
**name + serving path**, not name alone — a family-decorrelation claim (cross-family sidecar) is only
sound once the serving path of each family is itself pinned, else "different family" silently smuggles
"different infra" ([[reference_measurement_serving_path_variance]]).

Item #5 (injected-context contamination) is item #3's sibling on the *input* side: #3 proves *who*
answered, #5 proves *what they actually read*. Both reduce to the same mechanical-anchor rule — never
accept a measurement's self-report (of identity or of grounding) when a discriminating mechanical
check is available. Its sharpest tool is the **deleted-content discriminator**: a probe target that no
longer contains X makes any answer citing X self-invalidating — certainty no prompt instruction buys.

## Done When

- The checklist enumerates all five failure modes, each with its countermeasure.
  *Check class: mandatory-pass (binary — five items present, each with a countermeasure).*
- The probe item specifies a **discriminating** test and rejects generic probes.
  *Check class: judged, pair: a probe that two different models both pass must FAIL this check; a
  discriminating one must distinguish them.*
- Any FH cross-model measurement records which checklist items it ran.
  *Check class: measured (count of items applied) — closes the predict-verify loop for future audit.*

## Optional hardening (when a measurement feeds a published / paper claim)

Escalate item #1 (display-name pin) and item #3 (identity verification) from prose to a **logged
mechanical assertion**: the measurement harness records the *verified* model identity it observed, not
the requested slug. Prose discipline is sufficient for internal dogfooding; a published claim earns the
mechanical log.

> **External dogfood (a second, field-layer instance — n=1 external, a signal not a settled frontier):**
> the sister skill `ponytail` ships a runnable instance of the precondition behind all three modes —
> a `--selftest` that proves each instrument (`good===true && bad===false`) before any API spend, and
> two caught instrument contaminations. Detail + pinned citations: `tracks/_audit/session_2026_06_24_ponytail-lazy-senior-dev.md` §2-C (single source).

---

**Origin** (2026-06-22 harvest-loop): three failure modes observed across the-bible L2 model panel
(agy slug→Flash silent fallback; reps=3 non-determinism) and prior multi-model sims (generic-probe
ambiguity). Sister findings: [[feedback_correlated_blindspot_union_over_majority]] (reps≥3 prerequisite),
[[feedback_judge_robustness_mechanical_anchor]] (discriminating-probe = mechanical anchor),
[[reference_agy_model_catalog]] (display-name pin — agy slug fallback documented there).

**#4 added** (2026-07-05): serving-path variance surfaced in a cross-family verdict-invariance run
(n=864, borderline fixtures × 2 conditions × K=6 paraphrase × reps≥3). An identical GLM-5.2 model name
served over an internal NVFP4-quantized deployment vs an OpenRouter relay gave +0.21 vs +0.08
effect-size delta — quantifying that "same model name ⇒ same measurement" is false. Provenance +
generalizable finding: [[reference_measurement_serving_path_variance]].

**External corroboration** (2026-07): the local-LLM community independently reports the same hazard —
practitioners conflate "running model X" with running a *pruned/quantized derivative* of X (aggressive
low-bit quantization + expert pruning measurably degrade long-context quality while the model *name* is
unchanged). This is a general measurement pitfall, not FH-specific: a leaderboard or replication that
pins only the display name silently compares different instruments across serving paths.

---

## §Instrument-Calibration

> Scope note: the sections above govern **cross-model measurement** (pin the display name, reps ≥ 3,
> discriminating identity probe). This section is broader and upstream of them: it governs **any
> instrument whose output becomes a count, a tier, or a claim** — a scan, a grep, a checker script, a
> diagnostic row, a coverage ratio. Added 2026-07-20 after three instrument defects in one session.

### The rule

**Before an instrument's output is trusted or published, it must be shown to work on *this* target.**

1. **Known-pair calibration.** Run it against **one case you already know is positive** and **one you
   know is negative**. If it cannot separate those, it is not measuring — it is generating. This costs
   one run and catches the entire class below.
2. **Hand-verify one sample before publishing.** Open the single case the instrument is *most* confident
   about and confirm by eye. Do this **before** the number enters a report.

**Publish-order asymmetry (why step 2 is not optional):** verification is cheap *before* publication and
expensive *after*. A number written into a report, a session card, and a signal file must then be
corrected in **all three**, and every downstream reader who already consumed it is not recalled.
Measured 2026-07-20: a scanner's "77 items / 70% of the index" went into exactly those three records; a
single hand-check reduced the true figure to **3**.

### The failure class this catches: *the instrument's assumptions don't hold for this target*

Not "measured the wrong property" — the subtler one: **never asked whether this instrument is valid
here.** Three shapes, all observed 2026-07-20 in a single session:

| # | Shape | Concrete instance | What the known-pair would have shown |
|---|---|---|---|
| n+7 | **Instrument sees only part of its own declared surface** | An "always-loaded footprint" scan summed files rooted at `$TARGET`, silently omitting the auto-loaded memory index living outside it — **61% of the real resident surface** | A known-positive (a file you *know* is resident) fails to appear in the sum |
| n+8 | **A cheap proxy substituted for the real property** | Index-line/topic-file **size ratio** used as a proxy for *content coverage*; minimum ratio 3.7× read as "safe" — while an entry whose file was 3.7× larger still lacked every fact the index carried | One known case checked by content, not size, inverts the verdict immediately |
| n+9 | **Language / encoding assumption mismatch** | An **ASCII-token scanner run over a Korean corpus**: the index wrote `catch`, `MERGED`, `expert-system`; the files wrote `잡았다`, `머지`, `케이스크래프트` → every token scored as missing. **~96% false positives** | One known-negative (an entry you know is fully covered) scores as "missing" → mismatch exposed |
| n+10 | **Accepted into the scanned set, but no probe matches that shape** — the instrument counts the file as covered and reports it *clean* | `degrade_direction_scan.sh` collected `.sh` files while every probe was Python-shaped (`except:` / `.get(k, True)` / `if not x:`). A known-positive bash file with four default-toward-PASS constructs scored **0/4**, and the output read `no default-toward-PASS smells in 1 scanned py/sh file` (2026-07-28) | The known-positive of *that shape* scores 0 while the summary says "scanned" — the tell is coverage claimed without detection demonstrated |
| n+11 | **The collection predicate, not the probe, is what silently drops the target** | Same scan: git hooks are named `pre-push` (no extension) under `.git-hooks` (dotted directory), and the extension test ran against the **full path**, so FH's own mechanical floor reported `no scannable (py/sh) target files`, exit 0 | Point the instrument at a directory you *know* holds a positive; an empty file list is the finding, not a clean result |
| n+12 | **The measured axis does not vary with the arm — and equal scores are read as "no difference"** | External name: **frozen-replay defect** (`001TMF/harness-forge`, absorbed 2026-08-23 — *"the single most common way a harness search produces a confident, meaningless result"*). Their instance: a scorer replaying cached outputs makes quality **constant across candidates**, so the search happily returns a winner while measuring only cost. **Ours is not that instance** — see the note below | A **known-pair on the actual pair being compared**, not on a fixture: inject an arm that MUST score differently. If it does not, the equal scores were the instrument standing still, not the arms being alike |

🟥 **n+12 is the class every *comparative* measurement is exposed to — A/B arms, ablation, before/after,
tier batteries** — and it is the one shape on this list where **the instrument's silence looks exactly
like a finding.** n+7…n+11 produce a wrong number; n+12 produces a *confident conclusion* ("no
difference → CUT / no regression → ship") out of an instrument that never moved.

**Measured against our own ablation runner, 2026-08-23** (`scripts/probe_scope_check.sh` ·
`ablation_calibrate.sh` · `.claude/regression/ablation_verdicts.md`), so this row is not imported on faith:

| Leg | Verdict |
|---|---|
| Is there a cache/replay path (their literal mechanism)? | **Structurally absent** — every arm/rep is a live dispatch, so their instance cannot occur here |
| Is arm B verified to have actually not seen the ablated section? | **Closed** — injection/leak control |
| Is the scorer verified to respond at all? | **Closed** — a known-pair the calibrator must pass before a run is allowed |
| 🟥 Is the scorer verified to respond **to the pair actually being compared**? | **OPEN.** The known-pair runs against a separate fixed fixture, never against the live arm A/B. Equal scores on a real pair are therefore not distinguishable from a stalled instrument |

⚠️ **Do not read "no false CUT has happened" as safety.** Of the recorded verdicts, all showed arms
scoring clearly apart and **zero CUTs have ever been issued** — so the open leg has never been
exercised. `not found ≠ 0`; an untriggered hole is untested, not closed.

**What actually transferred was the question, not the defect** — *"is my instrument responding to the
arm at all?"* That question is portable even where the mechanism is not, which is the general lesson
for absorbing an outside failure shape: check whether their **mechanism** exists here before adopting
their **conclusion**. (Prescription deliberately NOT built: recurrence is 1, below this repo's own
mechanization threshold — `[[feedback_mechanize_at_repetition_prose_before]]`.)

Secondary false-positive sources in the same run, worth checking explicitly: **whitespace/hyphen
variants** (`3주새` vs `3주 새`), and treating a line's **navigational annotation** (`(detail …, archive)`)
as a factual claim.

### Degrade direction

- Calibration impossible or inconclusive → ship the output **labeled `UNCALIBRATED`**. It may inform;
  it may **not** ground a tier, a verdict, or a published figure.
- **`not found` ≠ `0`.** A file that does not exist is not an empty file; a scan that died mid-run
  reports a low number, and low numbers read as PASS. Guard the empty case explicitly and say
  `UNMEASURED`, never `0`.
- An instrument that produces an **impossible value** (all-pass, all-fail, or a self-scan in which the
  running tool does not detect itself) is suspect **before** its target is. Suspect the instrument first.
- **"Scanned" is a claim, and it is separate from "covered."** A scanner that admits a file type into its
  scanned set owes a known-positive *of that type*; without one, its clean message is a false clean, which
  is strictly worse than an honest "not covered" (n+10). Same for the collection step: an empty file list
  is a calibration failure to report, never a clean run (n+11).
- **A probe that flags the prescribed remedy is a defect in the probe.** Measured 2026-07-28: flagging
  `${count:-0}` — the integer sanitization that closes the `pipefail`-fallback class — would push an author
  to delete the fix. Hand-check a sample of hits before shipping a probe; on this corpus 6/6 sampled hits
  were false positives and the scoping that followed cut the load from 73 to 14.

### Done When

- Known-positive and known-negative both run, and the instrument separated them
  (check class: **mandatory-pass** — record both cases and their outcomes)
- At least one sample hand-verified before any count is written into a report
  (check class: **mandatory-pass**)
- **If the measurement is COMPARATIVE** (A/B arms, ablation, before/after, tier battery): the
  known-pair ran against **the pair actually being compared**, not only against a fixed fixture — and
  **equal scores are reported as `INSTRUMENT-UNCONFIRMED`, never as "no difference"**, until an arm
  known to score differently has moved the metric (check class: **mandatory-pass** — record which
  pair the known-pair ran on; n+12)
- If either is absent, the output carries the literal token `UNCALIBRATED`
  (check class: **mandatory-pass** — grep the report for the label)
- Adversarial pairing for the judged part ("is this instrument valid for this corpus?"): the
  known-negative **is** the adversarial case — it is chosen to be one the instrument should *not* flag,
  so a flag there is a refutation, not a finding.
