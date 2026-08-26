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
| FH Improvement 4-Axis Auto-Gate | **KEEP** | headless · `claude -p --model sonnet --tools ''` · cwd outside repo · per-arm dirs · known pair passed before the arms ran (that pair carries two named residuals — see `scripts/ablation_calibrate.sh`) | **10 per arm** | **2026-08-04** | arm A 8/10, arm B **0/10**, on a question grep-verified to be answerable only from the cut text — see §Re-run 2026-08-04 below. Supersedes the 2026-08-03 `UNCALIBRATED` row (kept below as the record of why the first basis collapsed) |
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

> ⏭️ **SUPERSEDED 2026-08-04 by §Re-run 2026-08-04 below — the row is now KEEP.** The paragraph that
> follows is the 08-03 state and is kept because it records *why the first basis collapsed*, not
> because it is the current verdict. It is left un-rewritten on purpose: this file's failure mode is
> a persuasive self-correcting voice that lets a stale verdict sit 40 lines from a live one, so the
> stale one gets a banner rather than a quiet edit.

**Verdict (2026-08-03, superseded): `UNCALIBRATED`, not KEEP and not CUT.** CUT is not reachable (the read-obligation surface
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

### Re-run 2026-08-04 — §FH 4-Axis, the owed re-measure. Verdict: KEEP

The 08-03 row owed three things **in order**: grep-verify that the target text exists *only* inside
the cut range, build an arm whose retained text does not contain the answer, then re-measure.

**Step 1 — grep, and it split the two candidate surfaces.**

| Candidate target | Occurrences in `CLAUDE.md` | Inside the cut (268–279)? | Usable? |
|---|---|---|---|
| mandatory-read obligation + canonical rule-file name | 264 **and** 274/276 | **no — 264 is outside** | ✗ still contaminated; line 264 names `fh_4axis_gate.md` *and* says "go read it explicitly" |
| **the gated-asset list — specifically `scripts/**/*.sh`** | **270 only** | **yes** | ✓ clean |

So the leg-2 question that failed in 08-03 is *still* unusable, and is not retried. The asset list is
a different surface and it is clean: line 264 now points at the list ("applicability is the asset list
in §FH Improvement 4-Axis Auto-Gate below") **without reproducing it**, so arm B retains a dangling
pointer and no answer. Mechanical check on the built arms: `scripts/**/*.sh` occurs **1×** in armA.md
and **0×** in armB.md.

**Step 2 — question, pre-registered by the prior session** ("a gated path the corrected sentence does
NOT name (agent definition + `scripts/*.sh`)"). Phrased to close the one alternate route: the edit is
declared to change no verdict, no exit code, no gate decision and no safety invariant, which removes
§Field-Harness Load-Bearing Change Gate (retained in arm B) as a legitimate path to YES.

**Step 3 — reps=10 per arm**, same calibrated configuration, calibrator exit 0 before the arms ran.

| | YES + names the 4-axis gate | flat NO | hedge | YES via the wrong gate |
|---|---|---|---|---|
| **arm A** (full text) | **8/10** | 1 | 0 | 1 |
| **arm B** (§4-Axis cut) | **0/10** | 8 | 1 | 1 |

Conditions the procedure requires for a usable verdict:
- **(a) pre-registered** — yes, quoted above. `k tried = 2, k discarded = 1`: a first phrasing naming
  `scripts/selfcheck.sh` was discarded **before any rep batch**, because arm A's smoke answer reached
  YES through §Field-Harness Load-Bearing (a hook file *is* a safety invariant), i.e. the instrument
  could not discriminate the hypotheses. Discarding for non-discrimination is not the same as fishing
  for a question arm B fails — but the log is self-attested, so it is stated rather than omitted.
- **(b) arm A's answer grep-verifiable in the cut text** — yes, **8/8**: every correct arm-A answer
  quotes the line-270 asset list verbatim.
- **(c) arm B's wrong answer consequential** — yes, and **bounded**. Measured, not assumed: staging a
  `scripts/*.sh` edit and attempting a commit **BLOCKED** on the pre-commit gate. So the behavior
  arm B changes is *proactive execution* — the session skips the chain, works on, and is stopped by
  the hook at commit time (wasted work + a surprise block). It does **not** produce an ungated commit.

**Artifact — persisted this time.** 20 arm outputs + both arm files + the verbatim question live at
`tracks/_meta/ablation_2026-08-04_4axis_scripts/` (23 files). That directory is gitignored, so it is
local evidence, not a citation a reviewer can open — which is why the counts above are in this tracked
file. The 08-03 rows' "transcript-attested" residual is closed for **this** run only.

**Named residual, found while measuring (c) — a seam between the hook's two halves.** The commit was
blocked, but `templates/regression_guard.sh` printed
`REGRESSION_GUARD: SKIP (not-checked, NOT a pass) — no file matched the gate pathspec`. The hook's
asset classifier includes `^scripts/.*\.sh$` (`pre-commit:148`) while Axis 1's `GUARD_PATHSPEC`
does not. So a `scripts/*.sh` edit is gated **but its Axis 1 is a skip, not a pass** — the guard
degrades in the honest direction (it says so) and the commit still blocks on the other axes, so this
is a coverage gap rather than a fail-open. It is the same asset-list-drift class the cut parity anchor
was written for; recorded here, not fixed in this commit.

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
| **2026-08-04** | **FH 4-Axis Auto-Gate — the owed re-run** | 1 — the gated-asset-list question aimed at `scripts/**/*.sh`, the class named ONLY inside the cut | prior session's ledger entry, quoted in §Re-run 2026-08-04 | **2 (1 discarded before any batch — non-discriminating, reason stated)** | **1 — UNCALIBRATED → KEEP** |

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

---

## §Autonomous Initiative Layer — **KEEP** (2026-08-27, instrument CONFIRMED)

사전등록 = `tracks/_meta/ablation_PREREG_2026-08-27_autonomous-initiative.md`
봉인 해시 = `23900bf367b88f34…` (`.sha256` 동봉, arm 실행 **전** 기록)
러너 캘리브레이션 = `ablation_calibrate.sh --reps 1` → exit 0 (P/N/T 셋 다 ok)

### 결과 (reps=3, 전 rep 일치 — 이번엔 비결정성 미관측)

| 질문 | arm A (원본) | arm B (절 제거) | arm A′ (Q1 답만 제거) |
|---|---|---|---|
| Q1 frontier-digest 7일 | ✅ 3/3 | **NOT IN MY CONTEXT 3/3** | **NOT IN MY CONTEXT 3/3** |
| Q2 harness-doctor 30일 | ✅ 3/3 | **NOT IN MY CONTEXT 3/3** | ✅ 3/3 |
| Q3 억제 3회 | ✅ 3/3 | **NOT IN MY CONTEXT 3/3** | ✅ 3/3 |
| Q4 원정 주기 없음 | ✅ 3/3 | **NOT IN MY CONTEXT 3/3** | ✅ 3/3 |
| Q5 `과녁: 없음` 정당 | ✅ 3/3 | **NOT IN MY CONTEXT 3/3** | ✅ 3/3 |

**k tried = 5 · k flipped = 0.**

### 판정 = **KEEP**
arm A 가 답하고 arm B 가 못 한다 — 사전 고정한 규칙의 첫 행. 게다가 arm B 는 **틀리지도 않았고**
`NOT IN MY CONTEXT` 를 냈다(«자신 있게 틀림» 경로도 아니다 — 가장 깨끗한 KEEP).

### 🟢 계기 이동 확인 (step 7) — 이 레포에서 처음 행사됐다
arm A′ 는 **Q1 의 답 문자열만** 제거한 arm 이다. 결과가 정확히 그 한 문항에서만 뒤집혔다
(Q1 → NOT IN MY CONTEXT · Q2~Q5 → 그대로 정답). ⇒ **채점기는 이 쌍에서 움직인다.**
「둘 다 답했다」와 「채점기가 안 움직였다」를 가르는 다리가 **실제로 판별력을 갖는 것이 실측됐다.**

### 🟥 부수 발견 — 기존 프로브 8개 중 7개는 이 절차에 쓸 수 없다
정답 토큰이 잘림 **밖에도** 산다(context-doctor 밖1 · harness-doctor 밖3 · harvest-loop 밖7 ·
goal-quench 밖2 · CATALOG 밖7 · plugin-recommender 는 절 안에 **아예 없다**). 그대로 돌렸으면
arm B 가 딴 데서 맞히고 **가짜 CUT** 이 났다 — 2026-08-03 에 반증된 그 다리의 재발이었다.
**사전등록의 grep 검증이 arm 을 돌리기 전에 막았다.**
⇒ 별건: `G-TRIG-01` 의 Scope 가 stale(row diet 로 제거된 행을 가리킨다).

### 이 판정이 말하지 **않는** 것 (사전등록에 미리 적은 한계)
- k=5 는 이 절 137줄 중 **Cadence Rules · 억제 가드 한 줄 · Expedition** 만 겨눈다.
  절의 최대 덩어리인 **트리거 표는 미검증**이다. 「절 전체가 하중」이 아니라 「이 5문항에 대해 하중」이다.
- 부분 절단(표만 잘라내기)은 이 절차의 범위 밖이고, 하려면 별도 사전등록이 필요하다.
- 채점자 = 거버너(동일 계열). 교차계열 재채점 미실행.
- 규격 이탈 1건: 5문항을 **한 프롬프트에 묶었다**(정본 예시는 문항당 1회). 45→9 호출로 줄이려는
  선택이고, 대신 저자가 어느 문항을 보고할지 고를 자유도가 없어진다. 이탈로 기록한다.

### ZERO CUTs 의 성질이 바뀌었다
이전: *"CUT 을 한 번도 낸 적이 없다 — 이 다리는 한 번도 행사된 적 없다. 미검증은 안전이 아니다."*
이후: **여전히 CUT 0 이지만, 이제 한 번은 «재보고 못 잘랐다».** 그리고 계기 이동 확인 다리가
처음 행사되어 **판별력이 있음이 실측됐다** — 미검증 항목 하나가 줄었다.
