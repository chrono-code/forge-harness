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
| FH Improvement 4-Axis Auto-Gate | **UNCALIBRATED** — owes a re-run | headless · `claude -p --model sonnet --tools ''` · cwd outside repo · per-arm dirs · known pair passed before the arms ran (that pair carries two named residuals — see `scripts/ablation_calibrate.sh`) | 3 | 2026-08-03 | see §Basis narrowed below — leg 1 REDUCED (not eliminated), leg 2 falsified by grep |
| Permission-Denial Guidance | **KEEP** | headless · `claude -p --model sonnet --tools ''` · cwd outside repo · per-arm dirs · known pair passed before the arms ran (that pair carries two named residuals — see `scripts/ablation_calibrate.sh`) | 3 | 2026-08-03 | arm A 2/3, arm B 0/3. The single arm-A miss is the runner's nondeterminism, not a finding |
| New Skill Creation Pre-Commit Gate | **UNCALIBRATED** | subagent method (leak channel 1 open) | — | 2026-08-02 | recorded KEEP by an instrument that had the uncut original in its system prompt. Not disproved — unqualified. Owes a re-run |

**Instrument-config field, not an instrument-version field.** Each row records the runner
configuration the arms actually ran under, because that is what the verdict depends on. The
*calibrator* that certified the configuration has changed since (a second tool control was added and
then cut — `scripts/ablation_calibrate.sh` header, NAMED RESIDUAL), and would keep changing; pinning
verdicts to a calibrator version would demote them on every edit to the calibrator. What a re-run
owes is a configuration change, not a calibrator change. If the configuration column ever stops
matching what `ablation_calibrate.sh` certifies, the row is UNCALIBRATED, not merely dated.

### Basis narrowed — §FH 4-Axis Auto-Gate, same day, after a resident-layer fix

The 2026-08-03 KEEP stood on **two** legs, both measured on the surface no probe covered:
(1) arm B answered **confidently wrong** 3/3 — it concluded the gate does not apply to `AGENTS.md`
or `templates/` edits; (2) arm B named the mandatory-read rule file in only 1 of 3 reps (arm A: 3/3).

Leg (1) was a symptom of a *separate* defect the ablation surfaced rather than of the section being
load-bearing: `CLAUDE.md` told the reader the rule file was "`paths:`-scoped to
`plugins/**/SKILL.md`" while its frontmatter lists six globs, and it conflated *when the rule file
loads* with *whether the gate applies*. Fixing that sentence (this commit) and re-measuring with the
same calibrated runner at reps=3:

| | before the fix | after |
|---|---|---|
| arm A — does the gate apply to `AGENTS.md`/`templates/`? | 3/3 correct | 3/3 correct |
| arm B (§4-Axis cut) — same question | **3/3 WRONG** | **1 wrong in 16** (see the correction below) |
| arm A — does it apply to an agent definition + `scripts/**/*.sh`? | not asked | 3/3 correct, citing the **asset list** |

The corrected sentence names neither `AGENTS.md` nor `templates/`, so the re-run doubles as the
discriminating probe: arm B answers WRONG far less often without the pattern-match crutch, which
attributes the improvement to the principle rather than to keyword adjacency. **Far less often is
not never — see the correction below before citing this row.**

> **Target freshness.** The rows above were re-measured against the FINAL text of this commit, after
> an intermediate draft — which had explained the gap in prose ("the hook's path set is wider than
> the asset list") — was replaced by widening the asset lists themselves. An earlier version of this
> table cited that deleted clause as arm A's evidence, i.e. the record described an artifact that no
> longer shipped. Corrected here; the lesson is [[feedback_audit_target_must_be_frozen]] applied to
> the record rather than to the runner.

> 🔴 **The "after" number was wrong when first written, and the correction is the point.** This row
> originally read `0/3 wrong`, then `0 wrong in 6`. An independent re-run at n=6 by the adversarial
> round reproduced a **confidently wrong** arm-B answer against the FINAL text, quoting the pointer's
> own backstop clause: *"the gate applies to any `SKILL.md` path … but neither `AGENTS.md` nor a
> generic file under `templates/` is a `SKILL.md`, so … the 4-axis gate does not apply."* A further
> n=10 by the author returned 10/10 correct. **Pooled: 1 confidently wrong + 1 wrong-reasoned hedge
> in 16 reps** — a real rate, not zero. The zero was a small-sample artifact of n≤6 on a ~6% event,
> which is exactly what `reps>=3` is too small to see. The clause that produced it has since been
> rewritten to say the hook blocks on every listed asset class, not only `SKILL.md`; that rewrite is
> **not** re-measured at a sample large enough to resolve a 6% rate, and is recorded as such.
>
> **Artifact residual**: the re-measure batches were not persisted to disk; the counts above are
> transcript-attested. The 2026-08-03 first batch (`out/*.txt`, 24 files) was persisted and is the
> only measurement here with a durable artifact.

**So leg (1) is REDUCED, not withdrawn** — from 3/3 wrong to roughly 1 in 16. And a second adversarial round then falsified leg (2) by grep, before
any re-run: `.claude/rules/fh_4axis_gate.md` is named at **CLAUDE.md:264**, which is OUTSIDE the cut
(the arm removes 268–279). **Arm B held the answer string the whole time.** So "arm B named the rule file
in only 1 of 3" measures the runner failing to use text it was handed — the nondeterminism the
procedure already documents — not the cut section being load-bearing. It also fails CUT-reachability
condition (b): arm A's answer is not grep-verifiable as coming *from the cut text*, because line 264
alone supports it.

The contamination was visible in the record before this commit — `ablation_method_correction_2026-08-03.md`
noted arm B assembling its answer from "§New Skill Creation 포인터 + Autonomous Initiative 표 행 +
§Surface-Class Degrade Invariant" — and was not carried forward into the verdict. That is the failure
this ledger exists to prevent, committed by the ledger's own author.

**Verdict: `UNCALIBRATED`, not KEEP and not CUT.** CUT is not reachable (the read-obligation surface
still has no clean probe), and KEEP now rests on nothing that survives a grep. What is owed, in order:
grep-verify that the obligation text exists **only** inside the cut range, build an arm whose retained
text does not contain the answer, then re-measure. Until then this row is a re-run target, not a
finding — the same status the subagent-method verdict below carries, and for the same reason.

**Named residual — the two asset classes added on 2026-08-03 have no regression anchor.**
`scripts/**/*.sh` and `plugins/*/agents/**/*.md` were added to both canonical asset lists in the same
commit. `scripts/gate_pathspec_check.sh` anchors only the `SKILL_detail.md` mention and sweeps only
`plugins/*/skills/`, so deleting either new class from either list leaves it exit 0. A parity check
was built for exactly this and **cut in the same session**: it produced four findings in one
adversarial round and never fired on `CLAUDE.md`, the file it was written to guard. Re-attempting it
owes, first, a fixed per-class needle table and `CLAUDE\.md` in the hook's `GATE_IMPL` trigger —
without those two it repeats.

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
| 2026-08-03 | FH 4-Axis Auto-Gate (re-measure after the CLAUDE.md pointer fix) | 2 — the same asset-type question, plus one aimed at a gated path the corrected sentence does NOT name (agent definition + `scripts/*.sh`) | pre-registered by the adversarial round that demanded a probe the fix could not satisfy by keyword adjacency | 2 | 2 (leg 1 REDUCED to ~1-in-16 by re-measure, NOT eliminated; leg 2 falsified by grep → row is now UNCALIBRATED) |

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

---

## Why this file needs an outside reader

Four same-family adversarial rounds passed over the paragraph above without noticing that it said
**"REDUCED, not withdrawn"** in one place and **"withdrawn"** in three others, 40 lines apart. A
cross-family auditor found it in one pass and named the mechanism: *this file performs visible
self-correction in a persuasive narrative voice, which makes an internal contradiction easy to wave
through.* The voice that makes a correction legible is the same voice that makes the next
overstatement legible. **Grep this file for its own verdict words before citing it.**
