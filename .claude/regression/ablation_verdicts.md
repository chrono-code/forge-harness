# Ablation verdicts — which resident CLAUDE.md sections are load-bearing

Companion to `probes.md`. A probe says *what a section must make happen*; an ablation says *whether
the section is where that comes from*. Procedure and its two known leak channels:
`scripts/probe_scope_check.sh` header. Runner precondition: `scripts/ablation_calibrate.sh` exits 0.

**This file is tracked on purpose.** The detailed session records live under `tracks/`, which is
gitignored — so a reviewer on another machine cannot open them. A verdict cited only from there is
a phantom citation to everyone but the operator (cross-family review, 2026-08-03). The verdict, its
arms, its rep count and its date belong here; the narrative belongs in the session record.

## Verdict table

| Section (CLAUDE.md §) | Verdict | Instrument | Reps | Date | Basis |
|---|---|---|---|---|---|
| Pre-Publish Surface Gate | **KEEP** | headless · `claude -p --model sonnet --tools ''` · cwd outside repo · per-arm dirs · known pair passed before the arms ran (that pair carries two named residuals — see `scripts/ablation_calibrate.sh`) | 3 | 2026-08-03 | arm B recovered the trigger + both audit skills from the Autonomous-Initiative row and the Degrade Invariant, but lost `/security-review` in 3/3 — the third check that actually blocked the 1.4.86 publish |
| FH Improvement 4-Axis Auto-Gate | **KEEP** (tighten, do not cut) | headless · `claude -p --model sonnet --tools ''` · cwd outside repo · per-arm dirs · known pair passed before the arms ran (that pair carries two named residuals — see `scripts/ablation_calibrate.sh`) | 3 | 2026-08-03 | the `G-GATE-02` slice is genuinely redundant (both arms 3/3), but on the surface no probe covered, arm B was **confidently wrong** 3/3: it concluded the gate does not apply to `AGENTS.md`/`templates/` edits and could not name the mandatory-read rule file. Withdraws the provisional CUT candidate |
| Permission-Denial Guidance | **KEEP** | headless · `claude -p --model sonnet --tools ''` · cwd outside repo · per-arm dirs · known pair passed before the arms ran (that pair carries two named residuals — see `scripts/ablation_calibrate.sh`) | 3 | 2026-08-03 | arm A 2/3, arm B 0/3. The single arm-A miss is the runner's nondeterminism, not a finding |
| New Skill Creation Pre-Commit Gate | **UNCALIBRATED** | subagent method (leak channel 1 open) | — | 2026-08-02 | recorded KEEP by an instrument that had the uncut original in its system prompt. Not disproved — unqualified. Owes a re-run |

**Instrument-config field, not an instrument-version field.** Each row records the runner
configuration the arms actually ran under, because that is what the verdict depends on. The
*calibrator* that certified the configuration has changed since (a second tool control was added and
then cut — `scripts/ablation_calibrate.sh` header, NAMED RESIDUAL), and would keep changing; pinning
verdicts to a calibrator version would demote them on every edit to the calibrator. What a re-run
owes is a configuration change, not a calibrator change. If the configuration column ever stops
matching what `ablation_calibrate.sh` certifies, the row is UNCALIBRATED, not merely dated.

## Reading a verdict

- **KEEP** — arm A answers, arm B cannot, or arm B answers wrongly in a way that changes behavior.
- **CUT candidate** — arm B answers *correctly*, on a **pre-registered** question set. Fishing for a
  question arm B fails makes every section keepable; see the pre-registration rule in
  `probe_scope_check.sh`.
- **UNCALIBRATED** — produced by an instrument that had not passed its known pair. Re-run, don't cite.

## Pre-registration log

The question set must be fixed before the arms run, and the count reported, or the CUT branch is
unfalsifiable.

| Date | Section | Questions pre-registered | Source of registration | k tried | k that flipped the verdict |
|---|---|---|---|---|---|
| 2026-08-03 | Pre-Publish Surface Gate | 1 (`G-TRIG-05`'s own question) | probes.md | 1 | 0 |
| 2026-08-03 | FH 4-Axis Auto-Gate | 2 — `G-GATE-02`'s question, plus one aimed at the asset-type list + mandatory-read obligation | probes.md, plus the verbatim prior-session registration quoted below | 2 | 1 |
| 2026-08-03 | Permission-Denial Guidance | 1 (`G-DENY-01`'s own question) | probes.md | 1 | 0 |

### Verbatim registration — FH 4-Axis, question 2 (2026-08-03)

The second question was not chosen after seeing a result. It was named as an owed measurement by the
prior session, quoted here in full because its source (`tracks/_meta/reference_next_session_starter.md`,
priority 2) is **gitignored** — and a pre-registration claim that only the operator can open is the
same phantom citation this file exists to remove:

> **§FH 4-Axis Auto-Gate 는 자르지 마라 (DO NOT CUT).** … 그리고 누출과 무관하게, 그 절의
> **자산타입 목록**과 **"정본을 반드시 직접 읽어라" 의무**는 **어떤 프로브도 안 겨눈다** —
> 미검증 표면이지 중복 증명이 아니다. **프로브 먼저.**

**Named residual — this log is self-attested.** `k tried` is reported by the session that did the
trying; a third question tried and discarded would not appear. Quoting the registration makes the
*claim* auditable, not the *count*. Mechanize on the first recurrence of a disputed k, not before.
