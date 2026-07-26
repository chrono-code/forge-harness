# Loop Engineering — the 5-question discipline and FH's loop inventory

> Companion node to the CLAUDE.md §Field-Harness Diagnostic **Loop-readiness lens** (its detail
> home) and to `sonnet_floor_doctrine.md` (PROSE loop legs are exactly where Sonnet-tier misses
> live — one spine, two lenses). Origin: 황민호 loop-eng 5-question review (2026-07-10, C-tier
> sister ledger — dedup hit on coverage, the *lens* absorbed) + Loop Engineering sister
> (`[[project_loop_engineering_sister]]`, Prompt→Context→Harness→Loop layering).

## The 5 questions — from diagnostic to design-time discipline

A path that *runs* is not a path that *loops*. Before authoring any autonomous path (skill step
chain, routine, close sequence), answer all five **at design time** — the diagnostic lens then only
re-checks what authoring already declared:

| # | Question | FH's mechanical form |
|---|---|---|
| 1 | **Initiate** — what starts it, mechanically or by utterance? | trigger phrases (≥3, gate-checked) · hooks (SessionStart/Stop/pre-commit) · cadence rules |
| 2 | **Complete** — is there a Done-When? | Done-When with declared check class (mandatory-pass / measured / judged) — already a skill-gate item |
| 3 | **Validate** — is the check anchored, not judge-only? | mechanical anchor over judge verdict (`[[feedback_judge_robustness_mechanical_anchor]]`); judged conditions name their adversarial pairing |
| 4 | **Halt** — budget guard, convergence detection, runaway stop? | token-budget-gate · convergence-loop N-round cap · goal-quench thresholds · the 1000-agent backstop |
| 5 | **Persist** — does state reach the next run? | session card · handoff STATUS stamps · edit-manifest predict-verify · memory |

**Design-time rule**: a new autonomous path whose author cannot answer one of the five has found a
defect *before shipping it* — cheaper than the diagnostic finding it later. The field-asset
scaffold (auto_project_mapping §6) carries halt + persist stubs so field skills answer #4/#5 by
construction, the same by-construction pattern as the gate-compliant skeleton.

## FH loop inventory — legs, enforcement class, measured gaps

Census 2026-07-10, all rows cross-family source-verified (codex gpt-5.5 — xhigh for micro/session/
weekly, high for quarterly/substrate; the substrate row's original governor self-assessment was
4/5 REFUTED by the external pass — the census discipline earning its keep). MECH = hook /
script / exit-code (tier-independent); PROSE = salience-dependent (Sonnet-floor risk surface).

| Loop | initiate | complete | validate | halt | persist |
|---|---|---|---|---|---|
| **Micro** — goal-quench | MECH (`.active` state) | mixed (Done-When explicit; `/goal` invocation manual) | MECH (`.pending` + pipeline-conductor gate) | **PROSE** (mid-run thresholds instructional) | MECH (calibration record) |
| **Session** — close chain ①–⑥ | PROSE (closing-phrase trigger) | **mixed** (card-last + step coverage now verified by `scripts/session_close_check.sh` — exit 1 on violation; the *performing* stays with the session, the *catching* is MECH, 2026-07-10) | mixed (git/PR inputs mech, synthesis remembered) | PROSE (no budget/stop guard) | **mixed** (companion-store sync script + SessionStart STATUS map + close-check ⑤ invariant, 2026-07-10) |
| **Weekly** — harvest-loop / audit cycle | PROSE (proposal at session start) | PROSE (self-reported Done-When) | mixed (`below_floor_scan.sh` exit code; rest hand-gathered) | mixed (critic retry cap 1; no global budget) | PROSE (audit file by hand) |
| **Quarterly** — maturity roadmap | PROSE (~90d cadence, no auto-detection) | PROSE (phase gates, checked manually) | PROSE (basis-path obligations, no anchor bundle) | **PROSE** (transition deferral / Phase-regression guards exist — hub_maturity_roadmap §6.1 — prose, NOT n/a) | PROSE (roadmap doc, no canonical state file) |
| **Substrate** — self-adaptation mission | **mixed→MECH improving** (routine schedules + context-entry proposals; the "substrate-version jump" detector now EXISTS — `scripts/substrate_jump_detector.sh`, SessionStart-wired, silent-unless-jump; was a phantom until 2026-07-10) | PROSE (routine terminal states are prompt-following) | mixed (weekly change runs the 4-axis gate — marker form MECH at commit; removal approval prose/HITL) | PROSE (one-proposal-per-week · deferred-draft-PR fallback · stop-after-PR — guards exist, all prose, NOT n/a) | mixed (GitHub issue comments + draft PRs are the durable spine, plus gate markers/edit-manifest/fh_signals — not "memory") |

**Reading the map**: the 4-axis auto-gate is FH's only all-MECH loop (initiate=hook detect,
complete=all-axes-or-block, halt=missing-marker-fails, persist=marker+manifest) — and it is also
FH's most trusted loop. That correlation is the doctrine: **trust tracks mechanization, not model
tier.** The PROSE-densest loops (session close, weekly) are where the measured misses actually
occurred (card staleness 2026-07-10; audit cadence slips).

## Case study — persist-leg mechanization (2026-07-10)

Company sessions push results to the companion store but never run the local close chain, so the
card's ⑤ update was the only reconcile point — prose, and mtime-blind: a status stamp landing
*before* a card rewrite became permanently invisible to the "newer than card" list. Fix: the
SessionStart hook now emits an **mtime-independent STATUS map** (all DONE/SUPERSEDED/RESOLVED
stamps, every session) with an explicit cross-check imperative. One measured miss → one mechanized
leg — the standing pattern (`sonnet_floor_doctrine.md §Why`).

## Hardening backlog — evidence-threshold, NOT built speculatively

The census surfaces candidate hardenings (close-chain checklist script, weekly-audit scaffold
script, harvest-loop evidence bundle, goal-quench checkpoint files). Per the build discipline
(`[[feedback_evidence_threshold_build_discipline]]`), each is built **only when its miss is
measured** (a real slip attributable to that PROSE leg), mirroring how the SessionStart hook and
STATUS map each shipped on a production miss, not a guess. Recording the map here *is* the
instrument: the next slip finds its leg pre-diagnosed.

| Backlog item | Fires when (measured trigger) |
|---|---|
| ~~Close-chain ordered-checklist script~~ | **BUILT 2026-07-10** (`scripts/session_close_check.sh`) — operator strengthen-instruction; the miss class (card staleness) was already measured, only the build trigger was overridden (recorded, not silent) |
| Weekly-audit scaffold + data-gather script | a weekly audit missed or hand-gathered wrong window data |
| harvest-loop Step 0-b/0-c evidence check | a harvest run misses completed items despite `fh_completed_*` existing |
| goal-quench mid-run checkpoint files (70/85/95%) | a /goal run blows through a threshold unnoticed |
| ~~Substrate-jump detector~~ | **BUILT 2026-07-10** (`scripts/substrate_jump_detector.sh`, SessionStart-wired) — same operator instruction; structure-enforcing class (out-of-context drift), permanent per the durable-mechanization criterion |
| Quarterly maturity checker (`quarterly_maturity_check.sh`) — **still unbuilt, correctly so** | ⚠️ **TRIGGER WAS UNFIRING — condition rewritten 2026-07-26** (the row stays live; strikethrough in this table means BUILT and must not be used for anything else). Its condition was *"a quarterly re-diagnosis is missed >90d"*, which needs a **last-diagnosis date to measure from, and none exists**: `hub_maturity_roadmap.md` is still the shipped **template** (its own header says *"in actual hub operation… write an operating copy"*), no operating copy was ever created, §5's six indicators still hold their template descriptions rather than counters, and no quarterly diagnosis artifact exists in either store. A backlog row whose trigger cannot fire is not deferred — it is **dead**, and it reads as deferred. **New trigger (observable): the first quarterly re-diagnosis is actually run and dated.** Until an instance-zero exists there is nothing for a checker to check; building the checker first would be the checker-for-a-loop-that-never-ran. |
| **Tested kill switch for any FH path that runs unattended** — documented one-move stop, *actually exercised once*, recorded | FH runs a genuinely unattended loop. Today the only candidate is the launchd `frontier-digest` (09:00 daily); the moment a second one ships, or that one gains write authority beyond its digest file, this fires |

### On the kill-switch row — provenance and the boundary of what is being proposed

Added 2026-07-26 with **two independent sources naming the same gap**, which is why it is on the
backlog rather than in a signal:
1. **External transcript already in-house since 2026-06-27** (a private companion store's
   cross-audit shelf, `raw_2026-06-27_loop-engineering-transcript.txt` — single-author, 44 KB)
   — *"실수도 무인으로 쌓이기 때문에 브레이크가 필요하다"* · iteration cap ·
   stop-on-stall · budget guard. **This corpus was never cited by any FH asset** (whole-repo grep, 0
   references) — it sat unmined for 13 days while this very file was authored from a different sister.
   Surfaced by the first real-corpus `dialogue-harvest` run.
2. **`agentsmith/profiles/autonomous-loops.md`** (2026-07-16) — *"a documented one-move stop you have
   actually tested. No budget, no cap, no L3."* Cross-audit `session_2026_07_26_agentsmith-sister.md §I-4`.

**Measured absence, instrument-calibrated**: `kill switch` · `emergency stop` · `abort the run/loop` ·
`정지 스위치` · `tested stop` → **0 hits** repo-wide, with known-positive controls in the same run.

⚠️ **What is deliberately NOT proposed — do not relitigate**: the same two sources also teach
*stagnation-triggered stopping* ("stop when the number does not improve twice"). FH already
**considered and declined** that class — `hub_maturity_roadmap.md §(c) Trigger-based`: *"Stagnation
detection criteria + auto-alerts + trigger tags all require new infra. Simplification principle
violation risk."* That declination stands; reopening it needs new evidence about **that** decision,
not a fresh citation of the same idea. Separately, FH **already has** stall detection where it
measurably mattered — `auto-decorrelation` §sidecar liveness, built on a production miss.
The kill-switch row is narrower than either source's full prescription, on purpose.

## Done When (for a new/changed autonomous path)

- All 5 questions answered at design time, each leg labeled MECH or PROSE *(mandatory-pass)*.
- Any judged validate-leg names its adversarial pairing *(mandatory-pass — inherits the skill gate)*.
- PROSE legs on load-bearing paths carry a Sonnet blind-sim verdict *(measured — doctrine §ladder step 2)*.
