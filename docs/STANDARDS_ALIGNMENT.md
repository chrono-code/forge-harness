# Standards alignment — what in FH maps to which ISO/IEC clause (self-assessment, 2026-09-05)

> **What this is**: a traceable self-assessment — for each clause of the AI-testing / AI-quality standards and each ISO/IEC 42001
> Annex A control *considered* here (Annex A controls are reference controls chosen through applicability and risk treatment, the
> way a Statement of Applicability would — they are not automatic requirements), the FH mechanism that answers it and the file
> where the evidence lives. **What it is not**: a conformity assessment or a
> certification. Half of the ISO/IEC 42119 series is still a draft Technical Specification (DTS / AWI), so the word used here is
> *alignment*, never *compliance*. Full crosswalk with sources: `knowledge/shared/harness-core/iso_ai_standards_crosswalk.md`.

## Why the harness is the right unit
The standards' "AI system" is the model **plus what runs it** — prompts, gates, logs, intervention points, risk records. The clauses a
model vendor cannot answer for you (42001 A.6.2.4 verification & validation, A.6.2.8 event logs, 25059 intervenability, TS 8200
controllability, 42119-2 §6 risk identification) live exactly in the harness layer. FH is a meta-harness, so the same table applies
to FH itself and to the field harnesses it emits.

## Summary table

| Standard · clause | Requirement (gist) | FH mechanism | Evidence | Status |
|---|---|---|---|---|
| ISO/IEC TS 42119-2:2025 §5.4/§6 | risk-based testing, risk identification | 6-axis verification chosen **by failure mode**; marker `defeater:` / `affected:` | `.axes_23_passed_*.marker` | 🟡 spread over commit-level fields, no risk register |
| 42119-2 §5.5 (29119-2 **dynamic** test process) | design → implement → execute → report | lane suites → `selfcheck.sh` → CI `validate` · 4-axis pre-commit gate | `templates/.git-hooks/pre-commit`, `scripts/selfcheck.sh` | ✅ |
| 42119-2 §5.5 (29119-2 **organizational / management** processes) | policy · strategy · planning · monitoring & control · completion | policy = CLAUDE.md gate sections · plan = pre-registration seal · completion = marker — no written monitoring/control or completion-criteria process | `CLAUDE.md`, `PREREG_*.md` | 🟡 activities exist, process documents do not |
| 42119-2 §5.6 (29119-3 documentation) | plan · case/procedure spec · completion report · incident report | pre-registration seal · lane files · marker + PR body · `fh_signal_*` | `scripts/test_*_lanes.sh`, markers | 🟡 1:1 but not named by 29119-3 template names — this page is the name tag |
| 42119-2 §7.2 | test levels unit → integration → system → acceptance | lanes → selfcheck → isolated-clone sim; **first real use** is a field trial, not acceptance testing (no acceptance criteria or sign-off evidence) | `scripts/sim_isolated_run.sh` | 🟡 unit–system ✅ · acceptance ❌ |
| 42119-2 §7.3.4 / TR 29119-11 §8 | black-box model-testing techniques: A/B, back-to-back, adversarial, metamorphic (drift is a monitoring / model-update concern in TR 29119-11; "drift testing" as a technique name comes from the ISTQB CT-AI v2 syllabus) | ARM/CTRL one-variable sim (A/B) · cross-family review (back-to-back) · challenger / steel-quench (adversarial) · nightly live-eval (drift monitoring) · revert probes (mutation) | `probes_live.yaml`, `probe_live_eval.sh` | 🟡 metamorphic relations not written as such |
| TR 29119-11 test-oracle problem | expected results when none exist | known-pair controls in the same run · scorer fixed before results · "not found ≠ 0" · `UNCALIBRATED` | `measurement-integrity-checklist.md` | ✅ mechanism · ✅ oracle *type* recorded — marker field `oracle:` (closed enum: known-pair · metamorphic · back-to-back · a-b · human · none; `none` needs its reason; form-checked by the pre-commit hook, 2026-09-05) |
| TR 29119-11 non-determinism | statistical treatment | `reps>=3` bar · 3/3 or 0/3 or no separation · controls | `probe_scope_check.sh` | ✅ |
| DTS 42119-3.2 (stage 50.20) | V&V analysis: simulation, evaluation, formal methods | isolated-clone simulation · live-eval thresholds · **no formal methods** | — | 🟡 |
| AWI TS 42119-7 red teaming (public scope only — the topics it *covers*, not normative requirements) | terms · risks · applicability · objectives & attack vectors · method · reporting · life-cycle integration | cross-family adversarial panel (a reviewer that never saw the author's reasoning) · attack-angle registry · findings typed S/A/B · mandatory before commit on load-bearing changes | `auto-decorrelation` SKILL, `field_verdict_crossfamily_gate.md`, **`templates/RED_TEAM_REPORT.md`** | 🟡 → report template added 2026-09-05 |
| AWI TS 42119-8 (stage 20.00) | quality assessment of prompt-based text-to-text GenAI | live probes with expectation/control regex and polarity · nightly isolated run · tier × effort expectation doc | `.claude/regression/probes_live.yaml`, `docs/model_tier_expectations.md` | 🟡 |
| ISO/IEC 25059 robustness | keep working under adversarial / invalid input | e.g. padding-bypass fix on the outbound hook (10 KB: 47 s → 0.23 s) with truncation / string / key fail-closed | `scripts/test_outbound_query_hook_lanes.sh` H23–H30 | ✅ by case |
| 25059 user controllability · intervenability · TS 8200 | timely human intervention, control points | HITL gates · consent **leases** (quoted words · dated · scoped) · autonomy floor · explicit, logged override channels (`DESTRUCTIVE_OP_OK`, `PUBLIC_SURFACE_OK`, `PUSH_ZONE_OK`) | `CLAUDE.md §Agent Dispatch`, `templates/.git-hooks/pre-push` | ✅ strong — every control point is a **logged channel** |
| 25059 transparency | appropriate information to stakeholders | marker "axes run and control liveness" · PR body "residuals named" · wiki status board "what proved it" | `docs/OUTPUT_EVIDENCE.md` | ✅ |
| 25059 (DIS) service traceability | definition differs between public secondary sources (logging of models / datasets / requests / outcomes vs. traceability of service outcomes to user needs) — both readings kept until the text is read | logging reading: governance log · hook event files (counts and labels, never values) · sub-agent ledger · sim header (`corpus_head_date`, `sim_model`, `sim_model_cutoff`) · user-need reading: marker `soul:` ↔ `defeater:` ↔ lanes | `tracks/_meta/governance_log_*.yaml`, `knowledge/shared/learnings/subagent_invocations_log.yaml` | 🟡 strong on the logging reading (which is also the 42001 A.6.2.8 evidence) |
| ISO/IEC 42001 A.6.2.4 V&V | verify against defined criteria | 4-axis gate: required fields, closed enums, non-vacuous grounds | `pre-commit` `validate_*_leg()` | ✅ |
| 42001 A.6.2.6 operation & monitoring | monitoring with criteria, review, response, ownership | mechanisms: nightly live-eval · daily digest · daily report (launchd) · "verification env ≠ runtime env" discipline; thresholds decided after a calibration week | `scripts/com.forge-harness.*.plist` | 🟡 mechanisms exist, no written monitoring procedure |
| 42001 A.6.2.7 / A.8 | technical documentation · stakeholder information | `knowledge/`, `docs/USER_GUIDE.md`, `docs/USE_CASES.md`, this page | — | ✅ |
| 42001 A.9 (A.9.2 responsible-use processes · A.9.3 objectives · A.9.4 intended use) | responsible use | intended use is *communicated* (guides); use processes = consent leases, autonomy floor, irreversible-surface gates; no written responsible-use objectives | `CLAUDE.md §Agent Dispatch` | 🟡 |
| 42001 A.6.2.8 event logs | log events | see traceability row | — | ✅ |
| 42001 A.5 impact assessment | assess impacts | chamber §3-SCREEN screens KILL / NOT-APPLICABLE / CURATED / EMIT — does not ask "impact on whom" | `harness_incubator_doctrine.md` | 🟡 |
| 42001 A.7 data (A.7.2–A.7.6) | acquisition, quality, provenance, preparation | FH holds no training data but does hold **evaluation data** (probes, corpora, transcripts, logs): provenance = sim header `corpus_head_date` · quality = known-pair calibration · preparation = residency strip · **company residency is absolute** | `probes_live.yaml`, `scripts/residency_closure_scan.py` | 🟡 provenance/preparation present; no written acquisition or quality criteria for evaluation data |
| ISO/IEC 5338 life cycle | define · control · execute · improve | incubator (chamber) → EMIT → field → harvest-loop compounding | `harness_incubator_doctrine.md`, `hub_compounding_loop.md` | ✅ |
| ISO/IEC 23894 risk management | identify · analyse · evaluate · treat | ship-readiness grades · Surface-Class Degrade Invariant (irreversible = fail-closed) | `ship_readiness_gate.md`, `CLAUDE.md §Irreversibility Gates` | ✅ partial |
| ISO/IEC 20246 reviews | work-product reviews | cross-family review · `/apex-review` · `hub-cc-pr-reviewer` · cold read (`beginner`) | `plugins/fh-meta/agents/` | ✅ |

## What a field harness inherits
A harness FH emits gets the same rows for free where it adopts the templates (`templates/.git-hooks/*`, the marker schema, the
red-team report). For a QA harness the primary target is ISO/IEC/IEEE 29119 itself: test design & implementation (act 1), work-product
review (act 1.5, ISO/IEC 20246), execution & incident reporting (act 2), completion & regression (act 3). That mapping lives in
the crosswalk §3.

## Honest boundaries
- Read from public material: the 42119-2 sample (table of contents, foreword), scope statements of 42119-3.2/7/8, secondary summaries,
  and the ISTQB CT-AI v2.0 syllabus as a public training syllabus that covers the same AI-testing topics (it is **not** a mirror of
  TR 29119-11 — v2 extends into GenAI and red teaming). Clause *bodies* of the paid texts were not read; the DIS 25059 definition of
  service traceability differs between the two secondary sources consulted and is kept as two readings.
- Not covered here (named so the map is not read as complete): ISO/IEC TS 25058, TS 6254 / 12792, 24029-2/3, TS 24970 (AI logging —
  the first candidate for the next revision), NIST AI RMF, IEEE 7001, EU AI Act Art. 9/15.
- Self-assessment, so gameable in the same way every self-declared field is (`CLAUDE.md §자기 대조`). The cross-family review on
  the commit that added this page is the only independent check applied so far.
- One author, one repository, one day.
