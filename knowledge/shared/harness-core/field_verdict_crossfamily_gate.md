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

```
tier1                        content-only review — no standpoint decorrelation (the default
                              unless upgraded; NOT itself a failure, most changes have no target
                              standpoint to borrow)
tier2(<target-harness>)      peer-simulated — the reviewer instantiated/ran the TARGET's own repo
                              (a local clone, real content) and executed the change from that
                              standpoint. Closes shared-body-path defects; a BARE clone cannot see
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
not-applicable                the change has no target-harness standpoint to borrow (no
                              shared-body surface, no cross-repo consumer contract) — distinct
                              from a degrade value; this is a scoping fact, not a miss. Carries the
                              same substantive-grounds-on-the-same-line discipline as a degrade
                              value below — asserting non-applicability without naming what was
                              checked is indistinguishable from UNKNOWN wearing a permissive label
DEGRADED_NO_TARGET_ACCESS     could not — applicable, but no local clone/access to the target
                              harness existed
DEGRADED_NOT_RUN              did not — target was accessible, standpoint review was skipped
UNKNOWN                       did not look — applicability itself was never assessed
```

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
validated fixtures). `standpoint:` has **zero** matches in that hook and no fixture suite — nothing
stops an author from writing `not-applicable` with a thin justification, or omitting the field
entirely, and no marker-shape check catches it. §Marker required fields in
`.claude/rules/fh_4axis_gate.md` does not yet list `standpoint:` either (add it there when this
mechanizes). This is the honest current state, not a placeholder apology: the field exists so a
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
