---
name: field_verdict_crossfamily_gate
description: Load-bearing field-project verdict/gate/safety code gets the same cross-family adversarial gate as FH assets — the correlated default-toward-PASS blind spot is model-family-level, not FH-specific. §7 adds the standpoint axis (orthogonal to family) for shared-body/cross-harness-boundary changes.
type: reference
date: 2026-07-03
tags: [cross-family, decorrelation, verdict-binding, field-harness, degrade-direction, correlated-blindspot, mode-d, standpoint-axis, cross-harness-boundary]
---

# Field-Harness Load-Bearing Change Gate — cross-family, pre-merge

> Compressed rule + trigger table live in `CLAUDE.md §Field-Harness Load-Bearing Change Gate`.
> This is the detail: the root principle, the failure signature, the gate mechanics, and the
> field evidence (qasp, 2026-07-03).

## 1. The root principle — prose specification grants discretion, not depth

Specifying an engine's decision logic in **conversational / prose** terms ("add more depth",
"break it down and analyze", "consider carefully whether it passed") does **not** add depth —
it grants **discretion**. The model fills that discretion with its **optimistic prior**. On a
verdict surface, the optimistic prior is *PASS*. So wherever a verdict surface's judgment is
under-constrained, its **degrade direction is toward PASS** — the exact opposite of safe-fail.

Corollary: **real depth in an engine = removing discretion (more mechanical constraint), not
better prose.** "깊이를 더해라" applied to engine logic is a category error. This is the same
axis as FH's `[[feedback_judge_robustness_mechanical_anchor]]` (terminal verdict needs a
mechanical anchor, never judge-only) and the source-level reinforcement question (does the
*format* of an emitted anchor change computation, not just its content).

Negative example (반면교사): **CaseCraft** hung loose prompts on the engine logic → the engine's
verdicts inherited the LLM's unconstrained optimistic reading → holes. **qasp / pmh overcame it**
by mechanizing the verdict surface (verdict-binding = mechanical ground truth only, no-judge,
fail-closed gates, mechanical anchors). See `[[project_qasp_casecraft_positioning]]`.

## 2. The failure signature — one sentence, four faces

> **"When a verdict surface cannot mechanically ground its judgment, it defaults toward PASS
> instead of safe-fail."**

Every instance is a form of **discretion leaking into verdict logic**:

| Face | The discretion | Safe-fail form |
|---|---|---|
| **default-PASS-on-absence** | unconstrained `else` / fall-through picks the permissive value | explicit `BLOCK`/`None`/raise |
| **affordance-without-grounding** | score-heuristic "judgment" of what counts as a match | hard grounding gate (target-text must score > 0) |
| **substring-not-exact** | loose definition of "present" (`tok in text` → paid⊂prepaid, 완료⊂미완료) | exact / word-boundary match |
| **unknown-to-permissive-default** | unenumerated branch defaults to allow | enumerate-or-safe-fail |

## 3. Why same-family review misses it — and cross-family catches it

The blind spot is **directional** (the degrade direction on the unhappy path) and rests on a
**shared optimistic prior**. A same-family reviewer — even a frontier model, even a target-tier
blind sim — reads the under-constrained branch the same optimistic way the author wrote it, so
it does not *see* the discretion as a hole. A **different-family** auditor does not share that
prior, so it reads the same branch adversarially and names the false-PASS.

This is not "cross-family is smarter" — it is **decorrelation**: the value is that the auditor's
error distribution is *different*, so it covers the author's directional blind spot. Governor
discipline still applies: sidecar findings are **candidates**, not terminal; the governor
source-grounds each (does the real pipeline reach it? does an existing mechanical anchor mitigate
it?) before acting — mechanical anchor over agreement.

## 4. The gate (before merge, not after)

1. **Degrade-direction lint** — `scripts/degrade_direction_scan.sh` (portable copy:
   `templates/degrade_direction_scan.sh`). A cheap **mechanical pre-screen**: greps the changed
   files for the code shapes above (except/else→PASS, `.get(k, <pass>)`/`setdefault`,
   substring-on-grounding-line). **Advisory review surface, NOT a hard gate** — grep-heuristic,
   false positives expected; a hit means *"prove this is not default-toward-PASS"*, and it never
   blocks alone (exit 2 = advisory). It points attention; it does not decide. Opt-out per line:
   `# noqa: degrade`. It scans **py + sh**; a changed load-bearing surface in any other language is
   reported as *unscannable / not-covered* (exit 2), never folded into an "advisory clean". **Efficacy
   caveat**: in the n=7 qasp sweep the lint itself caught nothing — the catches were the cross-family
   audit + accumulated regression tests. It is a token-free pre-screen ahead of a paid cross-family
   dispatch, *not a proven detector*; revisit if it never surfaces what the cross-family pass wouldn't.
2. **Cross-family adversarial review** — `auto-decorrelation` recruits ≥1 different-family auditor
   (e.g. `codex` gpt-5.5 / high for repo-grounded verdict code). The same standing verifier the
   4-axis gate uses for load-bearing FH assets, now applied to **field** load-bearing changes.
3. **Confirm → fix → re-verify loop** — iterate until the cross-family pass is **CONVERGED**: no
   reachable false-PASS / false-CONFIRMED / masked-FAIL / crash-where-safe-fail-required. **Each fix
   ships a mechanical regression test** reproducing the closed hole — a *required* convergence
   sub-condition, not incidental. (Two decorrelated models agreeing is still judgment; in the n=7
   sweep the round-6 over-correction was caught by an accumulated regression test, so the anchor leg
   is made mandatory — mechanical anchor over agreement.) Documented recall-limits of a
   deliberately-precise no-judge oracle (e.g. separator-negation `un-paid`, row-level positional
   state swap in a multiset projection) are **not** blockers — inherent precision>recall tradeoffs,
   fixture-tracked, not discretion-holes.

**Degrade direction — cross-family unavailable ≠ silent same-family pass** (the gate's own standard,
dogfood-caught 2026-07-03): the gate delegates the cross-family step to `auto-decorrelation`, whose
*general* degrade is "missing sidecar CLIs never hard-fail → in-session same-family + honest note."
That silent-degrade is **fail-OPEN for a load-bearing pre-merge surface** — same-family review shares
the author's directional blind spot, so proceeding on it defeats the gate's entire decorrelation
value while *claiming* the gate ran. So for this surface the gate **overrides** the default degrade:
cross-family unreachable → mark **NOT-CONVERGED** and block the autonomous merge / ask the operator,
or proceed only under an explicit **logged same-family-only acknowledgment** — never a silent
same-family pass. (This is the same fail-closed direction the target-tier Sonnet sim itself chose:
"if no cross-family sidecar is reachable, say so explicitly … not silently treat that as a pass.")

**Trigger (per changed file — grep-assisted, salience-dependent, no field hook)** — an AI-authored
change to a load-bearing field surface: a function returning a **verdict/gate enum or exit code**
(PASS/FAIL/BLOCK/allow/deny), an **irreversible-op** path (publish/delete/history-rewrite), or a
**safety invariant** (the-bible L1 floor, qasp verdict-binding, a pre-push/pre-commit hook). The
grep recipe (verdict-enum return / gate exit / safety-marked function) is a **strong-advisory
trigger, not a hook** — the FH pre-commit gate is FH-internal and never installed into field
projects, so it is salience-dependent, and the "safety invariant" category is interpretive, not
grep-decidable. **Named under-trigger residual** (do not claim airtight): unmarked safety logic,
boolean-return gate helpers, config-driven allow/deny, and shell/CI irreversible paths can escape
the grep — an agent under merge pressure can under-trigger by treating a change as non-load-bearing.
That residual is the reason the gate is reinforced by the always-on Autonomous-Initiative trigger
row + the operator's proactive framing, not by the grep alone.

**Residency** — sanitize company code (redact vendor/domain literals) before any external-family
dispatch; domain data never leaves. **Autonomy** — autonomous once the operator has consented in
the UAP (`tracks/_meta/user_adaptation_profile.md`, defined in `knowledge/shared/rules/operational_adaptation.md`),
same as the FH cross-family complement.

## 5. Field evidence — qasp verdict-binding sweep, 2026-07-03 (n=7)

The gap that motivated this rule: FH's cross-family decorrelation rigor had **never been
auto-applied to field-harness code** — only to FH's own assets. A one-time sweep of 3 mapped
harnesses (qasp / the-bible / pmh) found **9 HIGH default-toward-PASS holes**, all one signature.

qasp was fixed under this exact gate, and the **loop itself became the evidence**: each
confirm→fix→re-verify round, a **different family** caught the residual discretion that the
*previous same-family fix* had left — 7 rounds to CONVERGED. Even the frontier author's own
round-6 fix over-corrected (trusted a raw `"PASS"` string), and a **mechanical anchor** (a
round-1 regression test) caught it. Both legs of the doctrine — cross-family audit *and*
accumulated mechanical tests — fired against same-family error.

Positioning note: this is an **observational** field study, not yet a controlled claim. The
controlled follow-up (same- vs cross-family yield on a fixed bug corpus) is what turns the
observation into a result. Raw study: a private companion store's `paper-signals/` (Mode D;
`research_candidate_correlated_blindspot_verdict_code_2026-07-03.md`).

## 6. When baked into autonomous loops

In innovator-based loop-engineering (operator delegates a goal), `/goal`, or cluster
orchestration, this gate is **part of the delegated pipeline**, not an afterthought: a
load-bearing field change produced autonomously runs the degrade-lint → cross-family review →
converge loop **before it is considered done**. The autonomy floor applies — the skip/run
judgment on borderline cases is trusted only at opus-tier or above; a below-floor orchestrator
runs the review or asks, never silently skips (`[[feedback_judge_robustness_mechanical_anchor]]`,
CLAUDE.md §Floor governance).

## §7 Standpoint axis — orthogonal to family, formalized 2026-08-14

**The gap this closes**: §3 above establishes that cross-family review decorrelates the
*reviewer's error distribution*. It does not decorrelate the *reviewer's ground-truth source*.
Three families reviewing a shared-body change (code authored in one harness, consumed by or
governing interaction with a different harness) all read the SAME artifact from the SAME
standpoint — the author's own repo, the author's own understanding of the target's rules — if none
of them ever executes as, or is run by, the target harness itself. A defect that only manifests
relative to the target's actual conventions is invisible from that standpoint regardless of how
many families read it, because the miss is not in *how the diff was read*, it is in *what the
review was grounded against*.

**One sentence**: *family diversity raises resolution within one standpoint; standpoint diversity
changes which ground truth the review is checked against — they are orthogonal axes, and a review
that maxes out the first while leaving the second at zero has not raised its coverage of
standpoint-dependent defects at all.*

**Why the same author cannot close this by working inside the target repo and opening the PR
there — corrected framing (2026-08-14, after a cross-harness standpoint review of this section
itself).** The claim is *not* "the author is structurally blind to their own work" — a controlled
same-repo trial recorded outside this repo found that authors explicitly asked to self-check their
own output largely close the gap themselves (a clean replication refuted the stronger
"non-self-administrable" reading). What that trial's surviving result actually supports is
narrower and still real: a **routinely-run rubric that checks against the target's own corpus**
does work the author's default self-review does not reliably do on its own — the value is in the
rubric being supplied and run as a matter of course, not in some inherent authorial blindness.
This is measured, not asserted, from a second angle too: a 2026-08-14 trial recorded a human
insider review approving a change that violated a directory convention its own governance
documents disagreed about — neither reviewer, human or AI, held both conflicting documents at
once. Standpoint-grounded review is a routine cross-check against the target's ground truth, not
a claim that the author (of any kind, including a human insider) is incapable of finding it alone.

**Field evidence — three artifacts, two organizations, three repos, one carrying two independent
trials, one day** (corrected count, 2026-08-14 — an earlier draft of this section said "four
independent instances"; row 2 and row 4 below are two trials of the *same* artifact, not two
artifacts, and internal project codenames in a sibling field harness's private tooling are
genericized here per that harness's own residency rule — the specific names are on record in FH's
private companion store, not in this shared-layer doctrine file):

| # | Where | What only-standpoint-review caught | What full-family review missed it |
|---|---|---|---|
| 1 | forge-harness PR #368 | Write-side namespace fix left the read side (`sync-from-be.sh`, `fh_session_load.sh`) completely unsuffixed — a sibling hub's first SessionStart would read the author hub's own data as its own. **Confound named, not smoothed over**: the file is FH-owned, so "different harness" and "not the original author" are not cleanly separated here — this instance supports *"a different-standpoint check caught it,"* not *"a different-standpoint check was structurally necessary"* (see `fh_three_layer_canon.md §1-b ⓑ` for the fuller hedge) | 2 Claude waves + codex(gpt-5.5), all reviewing from the author hub's own content-reading standpoint |
| 2 | a sibling field harness's black-box regression repo, PR #8 (reps=3, 2026-08-07) | First measurement of the **finding-class split** under this specific frame — peripheral finding class differs by harness even when core defects are harness-invariant. Not the first sample of the underlying axis: `harness_verification_core_extended.md` (PR #225, 2026-08-01) already doctrinized "verification dispatched from a different harness" as Extended, with its own N=2 evidence; this instance and `[[feedback_decorrelation_axis_matches_failure_mode]]` are additional samples of that same axis, not a new one | Same-model, same-prompt, harness-blind arm |
| 3 | qasp-dev PR #161 (`mirror_guard_check.sh`) | 67 tracked files sat unregistered in a real protected-path list for months; 50 existing regression fixtures were **synthetic**, built by the same process that wrote the implementation, so they shared its blind spot structurally. **Confound named**: this is a same-author/same-repo blind spot (synthetic fixtures written by the implementer), not a cross-harness-boundary case under this section's own trigger below — an *adjacent* axis to standpoint, not a direct instance of it; kept here as corroboration of the family, not as a fourth standpoint data point | The suite's own author, repeatedly, across its whole synthetic-fixture lifetime |
| 2b | the same sibling harness's PR #8, known-answer calibration trial (2026-08-14) | 9 confirmed findings beyond a 21-comment human review baseline (7 of them S-tier, verdict-input-corrupting); the trial's own hint-vs-no-hint arms scored identically, so **prompt** variation (the hint) contributed nothing the standpoint shift didn't already carry — the arms did not vary model family, so this instance is silent on the family axis specifically | A target-harness-native human reviewer, plus the same-repo author |

Instance 3 was found *by this session, independently,* while reviewing qasp PR #161 for merge —
not fed in from the sibling harness's thread — even though (per the confound above) it is adjacent
rather than a clean standpoint instance. The genuine standpoint pattern (rows 1, 2, 2b) reproduced
across two organizations the same day it was being formalized, and a fourth, retrospective data
point landed the same day too: a cross-harness standpoint review of *this very section*, run
against a sibling field harness's own repo, independently surfaced the residency and citation
defects this revision fixes — a second live demonstration of the same axis, folded into the fix
rather than tabulated as a fifth row (it reviewed this doctrine, not a code change). That same
review also revealed a *sequencing* defect, not just a content one — see **Sequencing** below;
one event, cited twice for two different things it showed.

**Formalization decision (operator, 2026-08-14)**: the evidence bar this repo requires before
mechanizing a judgment call (`[[feedback_evidence_threshold_build_discipline]]`,
`[[feedback_mechanize_at_repetition_prose_before]]`) is met — three artifacts (one with two
independent trials), cross-organization, with a named causal mechanism, not a recurrence count
alone. The prior hold on this (pmh-dev#68: *"1회 시행부터, 지금 게이트/마커를 늘리지 않는다"*) is
**lifted**. This section is that formalization.

**Naming note**: this field's name collides with FH's own existing use of "standpoint" as the
persona/viewpoint organizing noun (`fh-meta:beginner`/`main-player`/`expert`, "parallax-compatible"
output — a *different* axis: which persona is looking, not whose repo is the ground truth). Kept
as-is rather than renamed — the term is already load-bearing in this session's own conversation and
in cross-harness correspondence about it — but the two senses are genuinely different concepts and
must not be conflated: agent-registry "standpoint" = which persona reviews; this field's
`standpoint:` = whose repo the review is grounded against. If this collision causes real confusion
in practice, the fallback is renaming the *field* (not the section) to `ground_truth:` — the enum
values below are unaffected either way.

**The field**: `standpoint:` — sits alongside `crossfamily:` in the same load-bearing verification
marker, never replacing it. Closed enum, same discipline as `crossfamily:`'s three-way *could
not / did not / did not look* split (a free-prose field would let an unrun check read as a clean
pass):

**🟥 DECIDE IN THIS ORDER — first match wins. Do not pick by matching a description.**

```
Q0. WHICH TARGETS? — settle the target CLASS(es) before reaching for a tier.
    🟥 NOT first-match. Q0 can return MORE THAN ONE target, and each one owes its own tier.
    A release that also alters a named peer's contract owes both arms; recording only the
    first shadows the second (caught by cross-family review, 2026-08-17).

      ⓐ Does a NAMED PEER HARNESS carry this surface?
         Mechanical test, in this order — do not decide from memory or from a name list:
           · a local repo of a cluster peer carries the file this delta changes
             (`for d in ~/projects/*; do test -f "$d/<changed-path>"; done`), OR
           · the peer is declared in `.claude/capabilities` / the cluster registry, OR
             the change edits an adapter under `scripts/adapters/` naming it
         YES → target = that repo (one per peer)              → run Q1 for each
      ⓑ Does this delta change CONSUMER-VISIBLE BEHAVIOR — what a consumer's gate blocks or
         passes, what a consumer's session is instructed to do, what an install receives?
         YES → target = a CLEAN INSTALL of the packed artifact → run Q1
               🟥 This binds NOW, at the change, pre-push (§Sequencing) — NOT deferred to
               the eventual release. Deferral was the first draft's hole: "not a release
               yet" would have let a behavior change ship unexamined and left the releaser
               holding a delta they did not write.
      ⓒ Neither ⓐ nor ⓑ → `not-applicable`   STOP.

    🟥 A consumer install IS another harness — settled, not open. What Q0 scopes is not WHO
    RECEIVES the change but WHERE IT HAS TO BE EXECUTED, and 🟥 **not «is this file shipped»**:
    almost everything here is shipped, so shipped-ness cannot be the discriminator (see
    «Target class» below). The discriminator is ⓑ's *behavior* clause — the same effect-based
    trigger this section already uses, applied to the consumer as a target rather than as an
    audience.
    Reading Q1/Q2 when the target is an install tree rather than a repo: Q1's "executed in the
    target's repo" = "executed inside the extracted/installed tree"; Q2's local-wiring question
    is answered NO for a bare extraction (`tier2`), YES only if a real consumer node's own
    settings/state were in play (`tier2b`).
Q1. Did anything EXECUTE in the target's repo — a command, a script, a suite?
      NO, I only read files          → tier1b(<harness>)   STOP.
      NO, I did not touch its repo   → tier1               STOP.
      YES                            → continue to Q2
    ⚠️ tier2 AND tier2b BOTH REQUIRE EXECUTION. This question is first precisely so the
    next one cannot be used to reason backwards into "tier2 must be the non-executing rung."
Q2. Was the target's own LOCAL / gitignored wiring visible (settings, consent bindings,
    node-local state) — i.e. its real installed runtime, not a bare clone?
      NO  (bare clone, tracked content only)   → tier2(<harness>)
      YES (the target's real runtime)          → tier2b(<harness>)
Q3. Was it run by a DIFFERENT operator of the target harness, not you?
      YES → tier3(<harness>)   (supersedes Q2)
```

**Why the procedure exists rather than more definition.** `tier2` vs `tier2b` is **wiring
visibility**, NOT execution-vs-reading — both execute. But `tier2b`'s gloss names "the target's
real runtime," which reads as *"tier2b is the execution rung"*, and a reader then infers that
`tier2` must therefore be the non-executing one.

🟥 **RETRACTED (2026-08-17) — the sim evidence formerly cited here is withdrawn.** This paragraph
read: *"after all three were corrected to say EXECUTED CODE, two independent blind Sonnet reps STILL
graded a pure cold-read `tier2`"*, and quoted one rep's reasoning verbatim. Those runs had
**`tool_uses: 0`** — the agents never opened a file, so the quoted reasoning is a cold guess about
text it did not read, and the grades measure nothing
(`tracks/_meta/fh_completed_2026-08-16.md:690`). The live re-run **inverted** the result at
**reps=1**, below this repo's `reps>=3` bar. **Neither direction is established**; do not restore
the numbers and do not cite the inversion either.

What remains, and it is enough to justify ordering the questions: the enum's *wording* really does
place the execution claim on `tier2b`'s line, so a reader can reach "then `tier2` is the
non-executing one" **by the text alone** — that is a property of the text, checkable by reading it,
and it needs no sim. Ordering the questions removes the inference instead of arguing with it.

```
tier1                        content-only review — no standpoint decorrelation (the default
                              unless upgraded; NOT itself a failure, most changes have no target
                              standpoint to borrow)
tier1b(<target-harness>)     STATIC standpoint read — the reviewer read the TARGET's own files
                              (cold, from the target's repo, without the author's framing) and
                              adjudicated the change against them, but executed NOTHING. Added
                              2026-08-16 because its absence was actively harmful: a run of exactly
                              this shape was recorded as `tier2`, since tier1 undersold it and no
                              nearer value existed. A missing rung does not stay empty — it gets
                              filled by the next one up. Real but weak: see «execution is the
                              load-bearing half» below before crediting it.
tier2(<target-harness>)      peer-simulated — the reviewer EXECUTED CODE in the TARGET's own repo
                              (a local clone, real content) and observed the result.
                              🟥 DISCRIMINATOR — «reading the target's real files is NOT this rung».
                              🟥 RETRACTED (2026-08-17): the «two blind Sonnet sims both graded a
                              cold-read tier2 … 0/2» measurement that stood here is WITHDRAWN —
                              tool_uses: 0, the agents never opened a file, so the grades and the
                              quoted reasoning measure nothing (fh_completed_2026-08-16.md:690).
                              The live re-run INVERTED it at reps=1, below this repo's reps>=3 bar.
                              Neither direction is established; restore no number here.
                              The AMBIGUITY it was cited for is still checkable WITHOUT a sim: the
                              earlier wording said «instantiated/ran the target's own repo», and
                              «ran» admits «operated within / engaged with», which a read satisfies.
                              That is a property of the text — read the two lines and see it.
                              THE TEST, and it is mechanical: **name the command you executed and
                              the output you observed.** Cannot name one → `tier1b`, always. An
                              agent that read files, however cold and however many, executed
                              nothing. Closes shared-body-path defects; a BARE clone cannot see
                              the target's gitignored local wiring (settings, consent bindings,
                              node-local state) — that gap is inherent to a clone, not a defect in
                              a given run. Named exception, not a loophole: if the reviewer's own
                              node ALSO mirrors the target's gitignored state through some other
                              channel (e.g. a companion-store sync that carries `tracks/_meta`
                              across machines), that visibility is real and should be credited —
                              but state so explicitly on the marker line, since the default
                              assumption for an ordinary clone is still "local wiring invisible."
tier2b(<target-harness>)     same operator, target's real runtime — the SAME human operator who
                              authored the change runs it in the target harness's actual runtime
                              (not just a clone's content), so local wiring IS visible, but the
                              reviewer is not an independent party. Distinct from tier2 (content
                              only, no local wiring) and from tier3 (independent party). Exists
                              because tier3 is structurally unreachable for a harness pair with a
                              single shared operator — see the residual below — and collapsing that
                              case into tier3 would overclaim independence it does not have.
tier3(<target-harness>)      actual peer — a DIFFERENT human operator of the target harness ran
                              the change in their real runtime. The only tier with both local
                              wiring AND reviewer independence from the author.
not-applicable                the change has no target-harness standpoint to borrow — Q0 found
                              neither a named peer harness NOR a release/publish surface, so there
                              is no repo and no install to run this from. 🟥 Read the second half
                              literally: «no cross-repo consumer contract» does NOT mean «this file
                              is never shipped». Almost everything here is shipped (measured
                              2026-08-17: 192/200 recent commits touch an npm-shipped path, and that
                              96% is a LOWER bound — `package.json` is packed without appearing in
                              `files[]`). Reading shipped-ness as the trigger makes this value
                              reachable in under 4% of commits, i.e. effectively unreachable, and an
                              unreachable value teaches authors to delete what they are counting
                              (`[[feedback_unreachable_done_when_trains_evasion]]`). The trigger is
                              the RELEASE, not the path — distinct
                              from a degrade value; this is a scoping fact, not a miss. Carries the
                              same substantive-grounds-on-the-same-line discipline as a degrade
                              value below — asserting non-applicability without naming what was
                              checked is indistinguishable from UNKNOWN wearing a permissive label
DEGRADED_NO_TARGET_ACCESS     could not — applicable, but no local clone/access to the target
                              harness existed
DEGRADED_NOT_RUN              did not — target was accessible, standpoint review was skipped
UNKNOWN                       did not look — applicability itself was never assessed
```

**🟥 Execution is the load-bearing half — a static standpoint read is largely subsumed by the other
axes (operator decision, 2026-08-16).** The reason to pay for a standpoint at all is not that
someone re-read the diff from a different chair; it is that **the target harness was actually made
to run.** Operator's framing, verbatim: *"그 하네스의 입장에서 정적리뷰하는 것만으로도 뭔가 잡을
수야 있겠지만 그건 다른 검증축으로도 커버가 아마 가능하지 않을까. 진짜로 중요한 건, 그 하네스
입장에서 돌려봐서 구동이 되는지를 로컬에서 완벽하게 확인하는 것."* A static read competes with
cross-family review (§3) and isolated grounding for the same defect classes and mostly loses —
those axes are cheaper and already routine. Execution has no substitute, because the class it
catches is *unreachable by reading*: the target's own environment differs (absent files, different
resolution order, a lane that has never once run there).

**Measured the same day this was written, on one delta (pmh-dev PR #72)**:

| Arm | Found |
|---|---|
| `tier1b` static standpoint read (isolated agent, target's own files, cold) | **1** — a 2-tier-vs-3-tier root-path resolution mismatch |
| Running the target's own `selfcheck.sh` to completion, locally | **2 more**, both invisible to any read: a test fixture keying on a file that does not exist in that repo, and an npm-shipping check whose premise is inapplicable there. One of them printed **neither `FAIL` nor `❌`** anywhere in its output (it used its own vocabulary, `INSTRUMENT ERROR`) and needed a `bash -x` trace to locate — a defect that is *structurally* undiscoverable by reading, since the reader must already know which string to look for. |

n=1 delta, same operator, same session — reported as a directional observation, not a rate. It is
recorded because it is the first time the two arms were run *separately on the same change* and
their yields could be attributed. ⚠️ **Do not read the table as "static review is worthless"** — it
found a real defect that shipped a fix. Read it as: *static is the half that has substitutes;
execution is the half that does not.*

**🟥 What dynamic standpoint review DOES and DOES NOT subsume (operator + governor, agreed
2026-08-16 after both arms were measured).** Operator's proposal: *"FH가 기여하는 다른 레포들도 다
마찬가지일 테니, 그쪽 입장에서의 동적 리뷰는 소넷을 상주시켜 돌려보는 거지. 이건 굳이 짓지 않아도
동적 입장리뷰만 잘 시킨다면 알아서 커버될 거라고 생각해."* Agreed, with one boundary — and the
agreement is evidenced, not deferential:

- **SUBSUMES: building per-target instruments.** Do not write a new scanner for each contributed
  repo, language, or defect class. Execution is **stack-agnostic**; an instrument is not. Measured
  the same day: `degrade_direction_scan.sh` is bound to shell/python *and* to verdict vocabulary —
  a faithful Python port of a real upstream defect scores CLEAN, because the fail-open value was
  ordinary *data*, not a verdict token. An instrument carries a scope boundary into every repo it
  visits; running the target's own suite does not.
- **DOES NOT SUBSUME: adversarial reading.** **Execution is a detector, not a generator.** It
  answers *does this break · does it fire · does the environment differ*; it cannot answer *is
  there a defect class nobody has instrumented yet*. The upstream `clawd-on-desk` PR #888 defect
  was **not** found by running that repo's tests — it was found by reading and conceiving the
  unreadable-file case, after which a test was written. And where the target ships no runnable
  suite, execution has nothing to run at all.

**The measured split, same delta, same day**: static read → **1** finding · execution → **2** more.
Neither arm was zero, which is the whole result. So both run: reading generates the hypothesis,
execution confirms or refutes it, **and the hypothesis that survives becomes a test left behind in
the target** — which is exactly what our own upstream contribution did (the survivor-lane pattern,
`tracks/_meta/fh_signal_2026-08-16_clawd-survivor-lane-air.md`).

**Consequence for the marker**: a `tier2`/`tier2b`/`tier3` claim asserts that something was RUN. If
the review only read, the honest value is `tier1b` — and since `tier1b` is explicitly the weak rung,
recording it truthfully is what surfaces that the execution arm is still owed. (This rule exists
because it was broken on the day it was written: see the `tier1b` entry above.)

**Residual this enum split names rather than hides**: for a harness pair with one shared human
operator (this repo and a sibling field harness the same operator also runs), `tier3` is either
unreachable or collapses into "the same author ran it in the other repo" — which is exactly the
standpoint the "why the same author cannot close this" argument above says is insufficient on its
own. `tier2b` is the honest reachable rung for that pairing; do not inflate a `tier2b` run to
`tier3`, and do not undersell it to `tier2` either — it is a distinct, real, if operator-correlated,
data point.

**Mechanization status — `standpoint:` is prose-only today, and this must not be read as more than
that.** `crossfamily:`'s degrade triad is hard-blocked at commit (`templates/.git-hooks/pre-commit`,
`scripts/test_marker_crossfamily_lanes.sh` — grep-verified: ~20 crossfamily references in the hook,
validated fixtures). `standpoint:` has **no value-enum validation and no fixture suite** — nothing stops an author from
writing `not-applicable` with a thin justification, and no marker-shape check catches a wrong value.

🟥 **Two sentences that stood here were STALE and are corrected (2026-08-17, re-measured — a
cross-family reviewer flagged the second, the first fell out of checking it).** They read
*"`standpoint:` has **zero** matches in that hook"* and *"§Marker required fields in
`.claude/rules/fh_4axis_gate.md` does not yet list `standpoint:` either"*. Both are false as of this
date: `grep -c standpoint templates/.git-hooks/pre-commit` → **15**, and the hook *does* enforce one
property (when `axes-run` carries `ⓑ=→standpoint`, the `standpoint:` line must exist and be non-empty
— `pre-commit:780-782`); `.claude/rules/fh_4axis_gate.md` lists the field at **§133 and §192**.
**What is still true is the narrower claim**: the *value* is unvalidated — «the line exists» is
enforced, «the value is right» is deliberately reserved (§Mechanization Boundary). Do not read the
corrected sentence as "now mechanized"; read it as "the channel is checked, the judgment is not".
The distinction this stale text destroyed is exactly the one that matters here, and it destroyed it
in the *pessimistic* direction — under-claiming coverage is not a safe error either, because it
invites someone to rebuild a lane that already exists. This is the honest current state, not a placeholder apology: the field exists so a
human reader can ask for it and so the *next* occurrence of a false `not-applicable` has something
concrete to point at — mechanize on that first recorded false value
(`[[feedback_mechanize_at_repetition_prose_before]]`), not before. **Ownership**: this field lives
in FH's own shared-layer canon, so mechanizing it (hook lanes, fixtures) is FH's job — a sibling
field harness that syncs this file verbatim cannot add the check locally without its own sync
process rejecting the divergence, so do not expect the check to appear from the consuming side.

**Where the evidence itself lives — the same gate-locality problem, applied to this field.** A
sibling field harness's own governance doctrine already names this exact defect: verification
evidence recorded in a gitignored local marker is *"evidence placed where the reviewer cannot
read it"* — a reviewer on another session, repo, or runtime structurally cannot reach it. This
field inherits that problem in its sharpest form, because a `tier2`/`tier3` value is a claim
*about a second party*, and the only party positioned to falsify it is the party the field is
gitignored away from. Treat the local marker line as a private note, never the canonical evidence:
the canonical, reviewer-visible copy belongs in the sanitized PR-body evidence capsule
(`.claude/rules/fh_4axis_gate.md` §Reviewer-visible evidence — same discipline, not a new one), and
a `tier3`/`tier2b` claim should carry a counter-artifact reachable from the target side (a linked
issue/PR comment, not just an assertion in the author's own repo) whenever one exists.

**Sequencing — runs on the local diff before the first push, one rule, no risk-branch (added
2026-08-14, self-correction).** §4 above titles the whole gate *"before merge, not after"* — this
field **tightens** that, it does not merely inherit it: a push to a public remote is itself a
publication event, so "before merge" is not early enough on its own (a PR can sit open, reviewed,
un-merged, and still have leaked). The retrospective review recorded above as the *"fourth,
retrospective data point"* — the cross-harness standpoint review of this very section — is the same
event this paragraph is about, cited there for its evidentiary weight, cited here for what it
revealed about *timing*: it ran on **PR #370**, the PR that introduced this field, **after** the PR
was already open and pushed to a public repo. That review found four S-tier findings; two were
residency leaks (an internal codename, a re-identifiable colleague anecdote), and by the time they
were caught, the leaking lines had already sat in a public, pushed commit — precisely the ordering
the repo's own Pre-Publish Surface Gate exists to prevent (*"scrub before publish, never
publish-then-scrub"*). Those specific lines were fixed forward in a later commit, not removed via
history rewrite (which would itself be a Destructive-Op-gated action) — the pushed commit that
originally carried them is still reachable in git history. Record which path was taken whenever
this recurs; do not let "fixed" imply the exposure itself was undone. (Findings recorded in PR
#370's sanitized evidence capsule; the specific leaked strings are in FH's private companion store,
not here.)

The fix is not a second risk-judgment ("is this specific change risky enough to justify running
pre-push instead of post-PR") — that would just add another judged branch point with its own cost
and its own failure mode. The fix is a single unconditional rule: whenever the §7 trigger below says
`standpoint:` applies at all, the review runs on the **local diff, before the first push to any
remote** — public or private, no visibility judgment to make. Axis 2/3 (steel-quench/phantom-quench)
run earlier still, at first commit (`.claude/rules/fh_4axis_gate.md`); run standpoint alongside them
when convenient, but the binding line for this field is the push, not the commit. Opening the PR is
the reviewer hand-off, and by that point this review should already be clean; if it is not clean
yet, the PR does not open yet.

**Trigger — narrower than §4's full gate, deliberately, and defined by effect, not by file-class.**
A file-class trigger ("touches `scripts/`, `knowledge/shared/`, `templates/`...") overtriggers for
a harness pair whose consumer contract already treats nearly the entire shared layer as
synced-verbatim — for such a pair almost every commit would qualify, which is the over-pricing
this trigger is trying to avoid, not invoke. The trigger is therefore the **behavioral** subset:
`standpoint:` is required when a change alters another harness's actual behavior, gate outcome, or
interaction contract — not merely when it touches a synced path. An ordinary load-bearing change
with no behavioral cross-harness surface is `not-applicable` by scope, not by degrade, even if the
file it lives in happens to be synced elsewhere. This mirrors a sibling harness's own scoping
proposal (pmh-dev issue #68, verified verbatim in that thread: *"대상 후보가 좁다 — 두 허브가 같은
컴패니언·같은 스크립트를 공유하는 경로. 전면 도입이 아니라 이 클래스만"*) — narrowed here to the
behavioral reading after that same review found the file-class reading false for at least one real
pair.

**Target class — «누가 받나» is not the question; «어디서 돌려야 하나» is (operator decision,
2026-08-17).** The trigger above says *effect, not file-class*, and that was still not enough: three
independent marker-audit legs, run the same day against three different markers, all failed at the
same place — each reasoned *"it ships, therefore there are consumers, therefore a cross-repo consumer
contract exists, therefore applicable"*. That reading is not obviously wrong; the enum's own words
(*"no cross-repo consumer contract"*) invite it. What kills it is the size: **192 of the last 200
commits touch an npm-shipped path (96%, a lower bound — `package.json` ships without being listed in
`files[]`, so at least one of the 8 remaining is a false negative too)**. A value reachable in under
4% of commits is not a scoping value — it prices the axis at a rate this section's own **Trigger**
paragraph already rejects as over-triggering (*"almost every commit would qualify, which is the
over-pricing this trigger is trying to avoid, not invoke"*). That is the argument, and it was
already in this document.

⚠️ **A citation is withdrawn here.** The first draft justified this with
`[[feedback_unreachable_done_when_trains_evasion]]` — *"an unreachable condition teaches people to
delete what they are counting"*. An adversarial round showed the direction is **inverted**: that
memory is about an unreachable **pass condition** a person must reach, whereas `not-applicable` is an
**exemption**. An unreachable exemption does not make anyone delete anything; it makes the obligation
fire almost always, and the failure mode is over-pricing and formality, not evasion. Same discomfort,
different mechanism — do not re-import the citation.

🟥 **State precisely what that 96% does and does not establish — it is narrower than it looks, and a
cross-family reviewer caught the first draft overreaching on exactly this.** It is a *file-class*
count, which this very section rejects as a trigger. It is admissible for **one** claim: the legs'
argument *was* the file-class argument (*"it ships, therefore consumers, therefore applicable"*), so
the number measures **that argument's reach**, and shows that adopting it collapses `not-applicable`
to under 4%. It does **NOT** establish how often the *behavioral* trigger (Q0-ⓑ) actually fires —
that number is **unmeasured**, and the step from "touched a shipped path" to "a consumer standpoint
obligation arose" is precisely the step Q0-ⓑ exists to make someone take by hand. Anyone citing 96%
as the applicability rate is citing it wrong.

**Corrected figure, and the instrument defect behind it — surfaced only because an adversarial round
demanded the hand-check.** The first pass reported **192/200 (96%)** with 8 non-touching commits. Two
faults, in opposite directions:
- **Instrument**: the scan ran `--first-parent` *including merge commits*, and `--name-only` emits no
  file list for a merge — so merges were silently scored *non-touching*. Re-run with `--no-merges`:
  the ratio held at 192/200, but the non-touching set collapsed to **6 real cases** (2 commits
  legitimately carry no files).
- **Hand-check of all 6** (this repo's own publish-a-number rule; N=6 made it trivially cheap):
  **2 are `package.json`-only**, which npm packs regardless of `files[]` — they *are* shipped. The
  other 4 are genuinely unshipped (`.gitignore` · `knowledge/shared/learnings/…` · two `scripts/`
  paths absent from `files[]`).

⇒ **Measured: 194/200 = 97%, every exception hand-verified.** ⚠️ One direction stays unexamined: the
scan applies **today's** `files[]` to **past** commits, and that manifest has only grown, so older
commits are over-counted as shipped. That FP direction is **unmeasured** — read 97% as *"under the
current manifest"*, never as a historical claim.

🟥 **And read the reachability argument in BOTH directions, which the first draft did not.** It
measured only what the *rejected* reading does to `not-applicable` (collapses it to <4%). It never
measured what the *adopted* reading does — Q0-ⓑ is a judged behavioral test, so no scan settles it,
and the honest statement is that **the new rate is unknown in both tails**: the value could stay rare
(if most shipped-path commits do change consumer-visible behavior) or become near-universal (if most
do not), and a near-universal exemption is a rubber stamp, which is its own failure — not the one
this edit was fixing. Watch the next 20 markers rather than assuming this landed in the middle.
⚠️ **The «unreachable ⇒ trap» premise is also weaker here than the first draft implied**: `tier1` is
explicitly *"NOT itself a failure"*, so even under the rejected reading an author had a cheap honest
value to write and was not cornered into deleting anything.

⚠️ **Two different denominators, both of which happen to be 200 — do not merge them.** The 192/200 is
over the **last 200 commits**. The 177/200 below is over the **200 markers in
`tracks/_meta/.axes_23_passed_*.marker`**. Commits and markers are different populations (a marker
covers a delta, not a commit; unmarked commits exist), and their coincident size is an accident of
this corpus. No ratio may be carried from one to the other.

So the split is by **execution site**:

| Q0 target class | What discharges the standpoint arm | Binds at |
|---|---|---|
| named peer harness (qasp · pmh · mate · gstack · sibling hub) | the enum as written — `tier1b`/`tier2`/`tier2b`/`tier3` against that repo | the change, pre-push |
| generic consumer install | run the **packed artifact in a clean install** — see the split below; the *presence* half already runs at ship time, the *execution* half does not exist yet | the **release/publish** delta |
| neither | `not-applicable` | — |

**🟥 What that arm is actually covered by today — corrected in the same session that wrote it, by
reading the lanes instead of naming them.** The first draft of this table said the consumer-install
arm was *"already mechanized"* by `publish_freshness_check.sh` · `package_coverage_check.sh
--vs-tarball` · `test_capability_entrypoint_shipping.sh`. Reading those three shows they answer a
narrower question than the arm asks:

```
covered, AT PUBLISH   `prepublishOnly` = prepublish_scope_note · publish_freshness_check ·
                      version_lockstep_check · package_coverage_check --vs-tarball ·
                      public_surface_scan_files          ← read from package.json, not recalled
covered, BUT IN CI    test_capability_entrypoint_shipping.sh is NOT in that chain — it runs under
                      the selfcheck anchor loop (`npm test`/CI). Naming it as a ship-time lane was
                      wrong; a green CI is not a publish gate (§Local Execution First).
NOT covered (exec)    extract the tarball into a clean directory, run the gate as a consumer would,
                      observe it behaves as intended. Measured 2026-08-17: of the lanes that invoke
                      `npm pack`, ZERO extract or execute the result — `--vs-tarball` compares a
                      FILE LIST (`npm pack --dry-run --json`), it never unpacks.
```

This matters because it is the same asymmetry this section already argues for: *"execution is the
load-bearing half"*. An arm discharged by presence checks alone is a `tier1b`-shaped arm wearing a
`tier2` label — the exact substitution the `tier1b` rung was added to stop. **So: the presence half
is mechanized and free; the execution half is a named residual, discharged by hand
(`npm pack` → extract to a clean dir → run the gate → record the command and the output, per the
`tier2` discriminator) until a lane exists.** Do not cite this arm as fully mechanized. The
decision's «no new machinery» framing was correct about the *presence* half and overstated about
the whole — recorded here rather than quietly narrowed, because a reader reaching for this table
mid-release is exactly the reader who would otherwise skip the half that has no lane.

**What this decision costs, stated rather than hidden.** Of the three legs, **leg B was right and
the other two were wrong to generalize it**: the `release_2.3.0` marker's `not-applicable` IS a
defect under this closure (a release delta whose own grounds line concede *"소비자 install 의 게이트
수용은 바뀐다 (BREAKING 2건)"* — that is the trigger being met, written out in the field that denies
it), while an ordinary commit touching a shipped script correctly stays `not-applicable`. Row 1
(PR #368) needs no reclassification: its target was a sibling hub with its own repo, a named peer.
⚠️ Those three legs were **not decorrelated** — same family, same prompt shape, same canon — so their
3/3 agreement is closer to one observation than three; it is cited here as *the pattern that exposed
the definitional hole*, never as three confirmations
(`[[feedback_decorrelation_axis_is_what_you_send]]`).

**Measured after this edit shipped, and it REFUTES the residual this paragraph first carried.** The
original text read: *"177 of the 200 corpus markers carry no `standpoint:` line at all … that pool is
larger than the one measured and remains unexamined."* It has now been examined, and the pool is not
larger — it barely exists:

```
201 markers · 24 carry `standpoint:` · 177 do not
  172   predate the field itself (born 2026-08-14, PR #370 landed 14:13) — structural, not a miss
    2   written the same day but BEFORE 14:13 (12:29 · 12:39) — also structural
    3   written after the field existed (16:41 · 19:10 · 21:06)   ← the entire real pool
    0   absences dated 2026-08-15 or later — adoption is 100% from day two onward
```

🟥 **The first step was decomposition, not adjudication.** Counting "no field" as "not recorded"
folds *the field did not exist yet* into *the author skipped it* — the same `not-found ≠ 0` collapse
this session hit three separate times (`[[feedback_not_found_is_not_zero_family]]`). Splitting by the
field's own birth timestamp is what turned 177 into 3.

**Hand-check of all 3, judged from the real diffs** (their markers use the pre-2026-08-17 four-letter
`axes-run` notation, where `b` means first-real-use and NOT standpoint — reading the marker's own
self-description instead of the diff would have inverted two axes):

| commit | delta | verdict under Q0 |
|---|---|---|
| #375 `cedd8ac` | `version_lockstep_check.sh` +11 lines, **all comment** | `not-applicable` would have been correct — a **missing line**, not a wrong judgment |
| #374 `0690ba7` | 7 files, +409 — shipped gate scripts plus `templates/degrade_direction_scan.sh` | 🟥 **genuinely under-recorded** (Q0-ⓑ, and `templates/` propagates to field harnesses) |
| #373 `549a4bc` | `ko-tech-writer/SKILL.md` +63/−12 (shipped plugin) | 🟥 **genuinely under-recorded** (Q0-ⓑ) |

**The direction matches §6's earlier finding: over-claiming 0, under-recording only.** A gate that
tightens *"were you really tier2?"* cannot catch this direction by construction.

⚠️ **Retroactive-application caveat**: Q0 was written 2026-08-17 and these three are 2026-08-14, so
their authors could not have applied it. What survives the caveat is narrower and still real — the
**field existed** by then, so the absent line is a gap independent of Q0.

**Consequence for sequencing**: the argument for postponing mechanization was *"absence is the
dominant reality, so validating values would only tighten a recording minority."* That premise is
**dead** — recording is 100% from 2026-08-15 onward. ⚠️ The refutation does **not** travel to peers:
pmh-dev's 42 markers carry the field 0 times, and whether that is late arrival or non-adoption is
**unmeasured** there. `thirdparty:` likewise stands at 2 corpus instances — unmeasured, not clean.

**Relationship to `harness_verification_core_extended.md`'s core/extended axis**: tier2 and tier3
are both "extended" in that document's sense (they require a cluster member's engine or repo to
discharge) — this field does not compete with that doctrine, it subdivides one corner of it.
Extended asks *was a cluster instrument used*; `standpoint:` asks, given that a cross-harness
surface exists, *whose ground truth was the review checked against*. A verification can be
Extended (a field harness's own audit lens was dispatched) while still being `standpoint: tier1`
if that dispatch never executed as the *specific other harness on the other side of this exact
change* — Extended is about instrument sourcing, `standpoint:` is about whose repo the check ran
against.

**Named residual, honestly scoped**: the proven-uplift bar `auto-decorrelation` already requires
for the family axis (`tracks/_meta/decorrelation_calibration_*.md`, N≥3 before claiming *proven*
rather than *measured*) applies here too — three artifacts (one with two independent trials, plus
the retrospective standpoint review of this section itself) is enough to mechanize the **field**,
not enough to claim the standpoint axis's uplift is calibrated in the same statistical sense family
diversity is. Record accordingly: `standpoint:` entries accumulate toward that bar, they do not
presuppose it already cleared.

---

### §7-b Standpoint **acquisition** — where the third party comes from (operator decision, 2026-08-15)

§7 above says *whose ground truth the check ran against*. It never said **where that standpoint
comes from when you don't have one**. In practice the roster was whatever repos happened to be on
disk, which silently caps the axis at "harnesses we already cloned".

**Operator decision (2026-08-15)**: when a change is judged **large-and-irreversible**, propose
cluster mode (skip the prompt for an operator who already granted standing consent) → use a local
repo if one fits → **if none does, search (GitHub etc.), clone, and run the standpoint review
against the clone** → produce the result. The clone step is covered by the same standing setup
consent as dispatch; it is not a separate ask.

**Selection criterion — not any repo is a standpoint.** The 2026-08-15 run measured this: the
third-party review that paid was against a repo carrying its **own written discipline**
(`CLAUDE.md` + `ETHOS.md` with explicit anti-patterns and a "search before building" rule). A repo
with code but no articulated discipline yields a code dump, not a standpoint — there is nothing to
judge *from*. Require an articulated canon (rules/ethos/contributing with normative statements)
before spending a clone on it.

🟥 **Read, never execute.** A standpoint review **reads** the target's canon and code. Cloning an
unfamiliar repo and *running* it is a different risk class and is not part of this protocol —
the 2026-08-15 runs (mate, gstack) were read-only, and that is the shape that generalizes.
Residency applies unchanged: nothing from a company-origin surface is sent outward to obtain a
standpoint.

**What the acquisition step does NOT settle** (named, not deferred):
- **Uplift is unmeasured for acquired standpoints.** The 2026-08-15 evidence used repos already on
  disk. Whether a *newly cloned* repo yields comparable findings is **untested** — the selection
  criterion above is reasoned from one case, not calibrated.
- **Cost is real and the yield is thin.** Blind external classification of that run put the
  third-party axis's *exclusive* yield at **2 of 15** findings. Both were boundary-crossing
  (a rule the other project had already abandoned; another repo importing the changed file) —
  which is why it earns its place on large-and-irreversible surfaces and nowhere else.
