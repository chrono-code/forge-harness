# Ship-Readiness Gate — Identity All-Green as the Release Condition

> **What this is**: the release gate for a harness (FH itself, or any field harness it incubates). A
> harness **ships** — and earns a **formal release tag** — only when the identities that define it are
> **all-green**: each proven REALIZED by a concrete track-record artifact (n≥1), not merely documented.
> This is the "품질보증서 (quality-assurance certificate)" the operator asked for: it certifies the
> harness does what its identity claims, with evidence, before it goes out. Origin: the 2026-07-14
> identity-fulfillment audit (`tracks/_meta/identity_audit_2026-07-14.md`).

## Why an identity gate, not a feature checklist
A harness is a means, not a feature list. Shipping it means promising it *does what its identity claims*.
A feature can be present yet the identity still be 이상론 (aspirational) — e.g. an incubator with a runner
but zero real emits. So the gate scores **identities by evidence**, and the honest states are:

| Status | Meaning | Bar |
|---|---|---|
| 🟢 GREEN | **REALIZED** | a concrete track-record artifact proves the identity fired for real, n≥1 (a real gate block, a measured probe, a real orchestration record) — *not* a doc that describes it |
| 🔵 RC | **RELEASE-CANDIDATE** | implemented **and** calibrated on a known pair **and** its own self-test green — but it has not yet fired in a real situation. All three legs, each with an evidence line; two out of three is 🟡 |
| 🟡 YELLOW | **PARTIAL** | pieces work but no single closed track record (e.g. two half-pipelines that never connected end-to-end) |
| 🔴 RED | **이상론 (ideal-only)** | documented aspiration, never actually run; or the source itself says "not built yet / named target" |

**All-green rule**: ship + tag only when **every** identity is 🟢. A 🔵, 🟡 or 🔴 blocks the tag — and names
exactly what real run is missing. The remedy for RED is never to relabel it green; it is to **run it and
leave the artifact** (the operator's standing rule: "이상론이면 실제로 돌려봐서 실적을 남겨야 한다").

**🔵 RC is deliberately not green.** It is the rung for "we built it, we proved the instrument works, and
our own tests pass" — a real and reportable milestone, and *still* short of the bar, because a self-test
is authored by the same party it tests. The boundary is the one named in
`[[feedback_adversarial_review_not_substitute_for_first_use]]`: **passing your own tests is not firing in
the real situation**, and the first real use is repeatedly what invalidates the design. So RC never opens
a `v1.0.0`; only REALIZED does.

> The origin note (2026-08-08 session card) drew this ladder with RC and REALIZED **both** marked 🟢. That
> shorthand is fine in a card and breaks here: this gate's rule reads literally as "every identity 🟢 →
> ship", so a green RC would open the tag that the same note says RC must not open. Distinct symbol, same
> intent.

**RC is self-reported by construction — so it carries evidence, not a claim.** Each RC status names, on
one line, *what ran and what came out* (the non-vacuity requirement borrowed from the 4-axis marker's
`axis2-evidence`: a recorded verdict, count or fixture result — never "it works"). An RC without that line
is 🟡. Where an instrument could not be calibrated against a real case, the leg ships labelled
**`UNCALIBRATED`** rather than silently counted (`not found ≠ 0`).

## Dominance, not concession — the AlexNet bar
A harness earns the right to say "we compose with other harnesses" **only from proven dominance**, never
as a humble concession. The reference is AlexNet: on data it had never seen, it did not *participate* — it
**crushed every competitor**. That is the bar for a shippable identity: on unseen input, in a head-to-head
against the realistic alternative (a plain single-model session, a competing harness's flow), our harness
must **decisively win**, not merely tie or "also work."

The composition identity (멀티하네스 클러스터) is downstream of this: we equip *other* harnesses onto the
parts **we deliberately chose not to cover, or left general-purpose** — a decision made from strength, after
proving we would win the parts we do cover. Composing because we *can't* win is weakness wearing the costume
of humility; composing because we *choose* the frontier and hand the rest to specialists is dominance.

**The squirrel-and-equipment shape (operator, 2026-07-14)**: the squirrel (🐿️ FH) dons **specialized gear**
for a specific harness/project — micro-work can't be done barehanded, and the gear (a field/domain harness)
makes it easier and more specialized. But **the squirrel itself must be an all-rounder master** at the one
thing it does everywhere: *creating and accelerating harnesses*. The mastery is the squirrel (general,
must-dominate — the governance/quality/harness-craft); the specialization is the equipment (per-domain,
composed-in). You never concede the craft; you equip for the domain. So the dominance bar applies to the
**craft** (does FH out-govern / out-build any alternative on unseen ground?), and composition applies to the
**gear** (which specialist harness to bolt on for this domain's micro-work).

**Dominance result (governance craft, 2026-07-14)** — `tracks/_meta/dominance_benchmark_2026-07-14.md`.
Model held fixed at the Sonnet floor; only the harness *method* varied. Two rounds:
- **Round 1 (5 easy holes)**: FH degrade-lens **5/5 (0 FP)** vs plain review **3/5** (1 miss + 1 false-alarm).
  Honest read: obvious fail-opens are caught by both — the lens's edge showed only on the subtle hole and
  in not crying wolf. Not a blowout; it pointed to harder holes as the real test.
- **Round 2 (8 subtle holes, authored by Fable + Codex — decorrelated from the method under test)**: plain
  review **5/8** (and 2 of its "catches" were distractor mis-identifications = false confidence, worse than
  a clean miss); degrade-lens **6/8, 0 FP**; and critically **both single Sonnet lanes missed the same 2
  holes** (a falsy-error-sentinel return, and a separator-negation parse). A **cross-family (Codex) lane
  with the same lens caught both** — the correlated blind spot inside one model family, closed only by a
  *different* family. **FH stack (degrade-lens ∪ cross-family) = 8/8, 0 FP.**

The load-bearing finding is architectural, not a headline number: **dominance comes from the decorrelated
stack (`degrade-lint ∪ cross-family ∪ mechanical-anchor`), not from any single clever reviewer** — even a
well-prompted floor model has a correlated blind spot that only a different family closes. This is the
*empirical* basis for why FH is a stack, not a prompt. And the two blind-spot classes round 2 exposed were
**immediately mechanized** — `degrade_direction_scan.sh` probes E (falsy-sentinel→PASS) and F
(split-positional-verdict) now flag both at the pre-lens layer (0 false-positive on the FH codebase), so the
correlated miss is caught one layer earlier. Forward direction: more such classes, and reps≥3 to fix the numbers.

**Gate consequence**: each 🟢 identity should carry not just an existence artifact (n≥1) but, where a
competitor exists, a **dominance result** — a measured head-to-head where our harness catches / completes /
survives what the alternative misses. The governance identity already has one (blind cross-family: FH's gate
the *only* thing that caught the irreversibility/safety class; competitors HITL 8/8 ABSENT). The others owe
theirs. A dominance benchmark is also *diagnostic*: where we do NOT yet dominate tells us exactly where to go
next (the operator: "압도성을 결과로 봐야 앞으로 나아갈 방향을 안다").

## The gate is the audit method (reusable)
Score with the same triangulation the 2026-07-14 audit used — no single-source self-attestation:
1. **Cross-family falsifiable checklist** — draft the per-identity PASS criteria with ≥2 decorrelated
   models (e.g. Fable higher-tier + Codex cross-family); they must converge on the load-bearing checks.
2. **Origin-grounding** — for each identity, quote its *original intent* from the accumulated record
   (memory / tracks / companion store) and find the artifact that proves it fired (or prove none exists).
3. **Blind floor-tier probe** — for any identity whose value is "intent-based autonomous completion"
   (a user gets the value by intent, without naming the skill), *measure* it: blind Sonnet sessions given
   novice-vocabulary intents, scored on whether the right skill/gate fires. Salience-only ≠ measured.

## Versioning policy — the formal release track
The formal release tag is **independent of the npm package version**. The npm version (currently in the
`1.4.x` range) is the **plugin-cache lockstep number** — it bumps on every shipped-asset change so Codex/
marketplace cache-invalidate; it is not a maturity claim. The **formal identity-maturity release starts at
`v0.1.0`**. Do not conflate the two counters; a high npm number does not make the harness mature.

**The `0.x` ↔ `1.0` mapping (refined 2026-07-14, informed operator decision).** Semver `0.x` explicitly
means *early / not-yet-complete*, so the formal track maps cleanly onto the identity gate:
- **`v0.1.0` = the first formal-release baseline.** It is tagged when the harness has a *proven core*
  (≥1 identity 🟢 by real artifact) and an *honest, evidence-scored status for the rest* — NOT when every
  identity is green. `v0.1.0` makes **no all-green claim**; its release notes carry the real per-identity
  status (🟢/🟡/🔴). This is the baseline *from which* all-green is tracked, not the all-green ship itself.
- **`v1.0.0` = the all-green ship.** The original "ship only when every identity is 🟢" condition maps to
  **v1.0.0**, not v0.1.0. A 🟡/🔴 blocks *v1.0*, and names exactly what real run is missing — it does not
  block the honest v0.1.0 baseline.

This refinement resolves the tension of tagging a baseline while identities are still maturing: `0.x` is
*designed* to carry an incomplete-but-honest status. What it must never do is **lie** — a v0.x tag whose
notes claim more green than the audit shows is the defect the gate exists to prevent. The operator, shown
the non-all-green status (③⑤ 🟢, ④ 🟡, ①② 🔴), elected to tag `v0.1.0` as this honest baseline; the
decision is logged here and the tag's notes state the real status.

## The four engines — what has to run for an identity to be reachable at all

An identity is what a harness *claims*; an **engine** is a capability the harness must actually possess
for that claim to be reachable. They are different axes, and scoring only identities hides *why* one is
stuck: the failure shows up in the identity and the cause sits in the engine.

| Engine | What it is | Why an identity needs it |
|---|---|---|
| **external-grounding** | Asking the world on its own initiative — reaching outside the repo before asserting novelty or settling a design, without being told to | Anything **new** has no known answer inside; asserting `net-new` from an internal grep alone is how a phantom is born |
| **judgment-circuit** | A forged decision circuit: what counts as success, which way to lean under uncertainty, what is out of scope, what never happens | Anything **autonomous** has no direction without one; the harness fills the vacuum with volume instead |
| **ship-gate** | Mechanical blocking before an irreversible surface — commit, publish, delete, rewrite | Anything that **ships** needs a last line that does not depend on remembering |
| **context-continuity** | Not losing the thread mid-run — across compaction, sub-agents, machines and sessions | Anything **long** loses its own premises first, and the loss is silent |

**Naming rule — do not translate `judgment-circuit` as "soul".** In Korean the operator's word is 영혼, but
the English word reads as *persona*, and the single largest finding of the 105-run measurement behind this
engine was precisely that **an identity declaration is not a judgment circuit** ("너는 ~이다" measured as a
net loss; removing it recovered +0.67 on the weak tier). A one-word translation re-fuses exactly what the
measurement separated.

**Why engines gate the advertised capabilities**: the harness's most-advertised surfaces — incubating a new
project, orchestrating a multi-harness cluster — are simultaneously *long, autonomous, novel and shipping*.
They therefore load all four engines at once, which is why a harness with a mature ship-gate and little
else appears to fail *at* those surfaces while the cause is underneath them.

> ⚠️ **The identity↔engine mapping below was composed by the AI, not measured.** It is a structural
> hypothesis, not established causality. The way to test it is to bring **one** engine up a rung and watch
> whether the mapped identity moves; until then, read the column as a claim about *what to try*, not about
> what is known. (The counterweight matters here: a mapping that looks tidy is the easiest thing to start
> citing as a finding.)

### Engine status (2026-08-13) — the first *measured* grades

These grade the **engines themselves**, on the same ladder as the identities (🔵 RC = implemented ∧
known-pair-calibrated ∧ its own self-test green · 🟢 = a real-situation firing artifact, n≥1). They were
**measured, not composed**: every leg-2 verdict comes from a **revert probe** — disable the mechanism,
re-run the suite, check that *exactly* the matching lane reddens — because a green suite is not evidence
that the suite measures the thing. **What a revert probe proves is lane discrimination** — that a
given branch has a lane which notices its removal. It does **not** prove that the engine's whole
instrument surface is covered; those are different claims, and ship-gate below is the row where
they visibly diverge. That method earned its place the same day: **three of the four engines
had at least one live branch that survived deletion with every lane still green.**

**Grade = the LOWEST leg that fails, never the highest leg reached.** A real-situation firing does
not lift a row whose leg 1 or leg 2 is broken. external-grounding below is exactly that case — it
*has* a genuine firing artifact and is still 🟡, because the layer that supervises the firing sits
under the RC bar. Reading the ladder as "highest leg wins" inverts every row in this table.
(Named by the cross-family reviewer as the one real inconsistency in the first draft, which stated
🟢 = firing n≥1 without saying that the lower legs still gate it.)

⚠️ **These are not identity grades, and they do not upgrade the mapping.** The identity↔engine column
above remains the unverified hypothesis it declares itself to be. An engine grade says what the harness
*can do*; it says nothing about which identity that unlocks.

| Engine | Grade | Leg 1 — implemented ∧ wired | Leg 2 — known-pair, revert-probed | Leg 3 — self-test | 🟢 real firing |
|---|---|---|---|---|---|
| **ship-gate** (품질게이트) | 🟢 **GREEN** | pre-commit + pre-push, `core.hooksPath` verified live | ✅ 37 cross-family fixtures · 30 branch-claim · marker-floor. **2 revert arms, each reddening only its own lane** (neutering the degrade-grounds check surfaced `'client error'` passing on the substring `cli`; restoring the `single-family` free exit surfaced two more) | ✅ 3 suites `rc=0` | ✅ **twice in one session (2026-08-13)** — a commit blocked as `🚫 BLOCKED — resolve failing axes`, and a branch-claim block that stopped a commit from landing on a **peer session's branch** in a shared checkout |
| **context-continuity** (맥락유지) | 🔵 **RC** | `compaction_probe` (PreCompact + UserPromptSubmit; snippet ships and `install-wizard` merges it by glob, not by name) · `session_close_check` (pre-push) · `digest_landing_check` · `utterance_landing_check` | ✅ 47 pairs after the 2026-08-13 fix, **4 revert arms**; session axis probed separately (deleting the card-last *verdict* — not its message — reddens its lane) | ✅ 47 · 10 · 8 · 8/8, all `rc=0` | ❌ **withheld, and the reason is the interesting part** — see below |
| **external-grounding** (물어보기) | 🟡 **PARTIAL** | `novelty_claim_check` wired (pre-commit + selfcheck) but **advisory, non-blocking** · `digest_landing_check` has **zero callers** · the daily digest launcher ships a **placeholder path** in its plist | ⚠️ split: novelty **8/8 arms anchored**; landing-check has **4 live branches that survive deletion**, one of which flips a genuine *miss* into a false *landed* | ✅ novelty 13 pairs · landing 10 lanes — but the latter only runs when a human types it | ✅ **exists** — 5 `frontier-auto:` commits (2026-06-22 → 07-28); one hand-verified, it labelled an unreachable source `UNCALIBRATED` instead of asserting through it |
| **judgment-circuit** (영혼) | 🔴 | ⚠️ the lint + registry exist and are wired, but the engine is a **6-step loop and only step ③ has a mechanical anchor (1/6)** | ⚠️ known-positive/negative both present; **5 arms unanchored**, including deleting the pre-commit block, the selfcheck wiring, and the registry file — none reddens anything | ✅ `rc=0`, 15 pairs | ❌ not found in this repo's tracked history (controls run) |

**Why ④ is held at RC rather than promoted.** Its three RC legs stand. The 🟢 leg is withheld for two
reasons that point the same way: (a) **the instrument that would evidence it is disproven** — the scoring
leg greps the transcript, and the transcript preserves history across a compaction, so that scorer reports
zero loss forever (fail-open); the isolated scorer that could answer *"can the model still answer?"* is
unbuilt; and (b) the one observed pre-fix real firing **delivered a false ledger** — a 5-day-old seal
announced as "the compaction just before this one," which misled the session that then fixed it. After the
fix the same path prints an honest *"cannot tell"*. Honest inability is not preserved continuity. **An
engine whose own measuring instrument is refuted cannot be promoted by argument.**

**What the four measurements found in common — one root, three engines.** The wiring of an anchor whose
lanes live *inside* the script (`--self-test`) is **structurally invisible to the repo's wiring checker**,
whose scope is the filename patterns `scripts/test_*.sh` / `*_lanes.sh`. So a caller line can be deleted
and nothing reddens: measured on the judgment-circuit lint (removing its pre-commit block, its selfcheck
entry, or its registry file each left seven checks green) and structurally true of the landing checker,
which has no caller at all. This is one rung above the debt the checker was built for: it catches *"a lane
that never runs"*, not *"a lane that runs, whose caller can vanish unnoticed."* Sharper still — the
selfcheck comment that closed this class on 2026-08-08 did so with a **hardcoded three-name list**, and the
landing checker was born the next day outside it. **A repair that enumerates instead of deriving reopens
itself on the next addition.**

**What blocks the next rung, per engine** — cheapest first, and none of it is a rewrite:

```
② judgment-circuit  ①②(interview · form-forcing) have ZERO mechanism; ④'s mechanism exists and is
    🔴 → 🟡        simply not wired to this loop; the registry holds ONE entry (this repo's own
                    CLAUDE.md), so the instrument has no corpus to measure. Note the instrument
                    measures the PRESENCE of a declared form, never whether a circuit is real —
                    its own header says a "default to PASS" direction still earns credit.
① external-grounding  wire the landing checker (zero callers today), and anchor its four surviving
    🟡 → 🔵         branches — especially the self-reference filter, whose removal turns a real miss
                    into a false landing (optimistic direction).
④ context-continuity  build the isolated scorer. Nothing else moves this row: the question
    🔵 → 🟢         "was the thread preserved?" has no instrument, and a firing without one is an
                    anecdote either way.
③ ship-gate         already 🟢. The open work is not promotion but scope: its own axis-1 job is
    🟢              still not a required server-side check.
```

**A 🟢 engine can still hold an instrument with a silent hole — say so rather than letting the grade
cover it.** This measurement's leg-2 probe for ship-gate covered the marker and branch-claim lanes, not
every instrument the engine owns. A parallel axis measured, the same day, that one of the others — the
package-coverage checker — was dropping **every `.json` reference** through an alternation-order bug
(`js` matching before `json` in a leftmost-first alternation, leaving a path that then fails an existence
test and is discarded in silence). That checker had never seen a JSON reference in the shipped docs;
repairing it surfaced three immediately — one of them a **consumer-facing defect**: a shipped
document instructs the user to copy a settings file that was not in the package at all. That is
the very class this checker exists for, and its own regex kept it invisible. The engine grade is unchanged — it is earned by blocks that
actually fired — but *grade* and *instrument coverage* are different claims and must not be read off
one another.

**And one failure mode this measurement did not anticipate, found the same day by a parallel axis.**
`npm publish` packs the **working tree, not the commit**. In a checkout shared by several concurrent
sessions, the session that publishes therefore ships every *other* session's uncommitted draft. It was
caught here by the pre-publish scan, not by anyone's care — an operator-private token sitting in an
uncommitted line of a shipped file. The shared-checkout hazard is usually stated as *"my git operation
moves your working surface"*, which is recoverable; this is the same hazard reaching an **irreversible**
surface. The fix is not "remove the token" but **publish from a clean tree at a committed state**.

**Named residuals of this measurement.** The registry/launcher state of *other* installs was not measured
(one machine, one tree). The daily launcher's real installation lives outside any git tree, so its liveness
is **UNMEASURED, not zero**. The judgment-circuit loop's canonical 6-step definition **does not exist in
this repository's public knowledge layer** (grep: 0 hits, control positive) — it lives in operator-private
notes, which is itself part of why five of its six steps have nothing here to anchor. And every arm ran
`reps=1`; the scripts are deterministic, but the convention is `reps≥3`.

## FH's own status (2026-07-14) — NOT yet all-green

Engine column added 2026-08-08 (mapping is the unverified hypothesis flagged above; Status column is
unchanged and keeps its own 2026-07-14 evidence).

| # | Identity | Engines it loads | Status | Evidence / what's missing |
|---|---|---|---|---|
| ③ | 거버넌스 게이트 (governance) | ship-gate | 🟢 GREEN | pre-commit/pre-push physically block; moat measured 3–4 family blind (HITL 8/8 ABSENT); cross-family caught a real companion-store-name leak 2026-07-14 (fail-closed) |
| ⑤ | 증폭자 (amplifier) | judgment-circuit | 🟢 GREEN | short-intent→literature-grounding→ultimate-doc real instances; rules-diet −18.2k measured; intent-routing probe 94% (below) |
| ④ | 프런티어→조직 전파 (**🔵 RC, 2026-08-09**) | external-grounding | 🔵 RC | frontier-digest launchd auto + AX submission docs both real, but digest→org never closed as ONE pipeline. **2026-08-09**: the missing link was built — `scripts/digest_landing_check.sh` extracts the digest's candidate table into probes and reuses the existing landing checker (no second verifier). Self-test 8 lanes green. **🔵 RC (2026-08-09)**: the mtime defect that initially held it back is closed — the since-filter now splits two axes (git-tracked → commit time via `git log --since`; gitignored `tracks/**` → mtime, the only evidence that axis has; dirty-tracked → `UNMEASURED`), and **two lanes pin that split**: a file with only a fresh mtime is *not* counted, and a file with only a fresh commit *is* counted even when its mtime is stale. The second lane matters — without it the fix degenerates into "discard all tracked files so only negatives pass" (named by the cross-family reviewer). Self-test **10 lanes** green. **What remains is a named residual, not a calibration gap**: `file-change ≠ token-introduction` — a file committed after the digest may carry the token from before (closing it needs token-level diff, which does not fit the checker's interface). The instrument therefore prints, and this row states, that it is a **screener, not an adjudicator**: hits must be opened. Four real runs, four hand-verifications, four defects found |
| ① | 멀티하네스 클러스터 (**🔵 RC, 2026-08-09**) | context-continuity | 🔵 RC | routing already ran for real (17 nodes, sidecar-orchestrator, Skill Bus). **The relay half is now built rather than specified**: `capability_composition_contract.md` (2026-08-02) was a complete spec with **zero implementing code** — the ① blocker was missing wiring, not missing design ([[feedback_built_but_not_wired]]). `scripts/relay_channel.sh` executes it (strictest-wins merge · typed invocation · checks 1/2/3 · short-circuit · causal binding), `scripts/test_relay_channel_lanes.sh` carries **64 lanes, BLOCK/PASS symmetric**, and three arms ran across **two real field harnesses** (pmh-dev · qasp-dev) on FH's own assets. ⭐ **The measured result is the divergence arm, and its mechanism is not what the first draft of this row said.** On `templates/.git-hooks`, `qasp` alone returns exit 0 — a single-node pass would have shipped it — and the composition returns `BLOCKED` because `pmh` returns `FINDINGS`. But `qasp`'s exit 0 is `degrade-scan: no scannable (py/sh) target files`: **zero files were scanned.** The qasp copy predates pmh's 2026-07-28 shebang pass, so extension-less hook files are invisible to it, and its exit 0 means *no target*, not *clean*. So the composition did not catch a substantive disagreement between two harnesses — it caught **a single node rendering an unmeasured surface as a pass**, which is `[[feedback_not_found_is_not_zero_family]]`, and structurally the spec's own §ⓑ.4 B1 ("the exit 0 that means I never started"). That is a *stronger* result than the first framing and a narrower one: it demonstrates the union catching a blind spot, not decorrelated judgment. **Correction also to the order claim**: both orders return `rc=2`, but in the pmh-first order the chain short-circuits at node 1 and qasp never runs — only the qasp-first order actually exercises the union. Non-decorative: reverting each wiring line reddens lanes and no reversion passes silently. **Why this is RC and not 🟢** — *updated 2026-08-11; (b) and (c) moved, (a) did not, and a fourth appeared*: (a) the row's *other* half, external-harness recommend, is still parked — **unchanged, and it is a build, not a check**; (b) ~~`scripts/capability_registry_check.sh` does not exist~~ → **built 2026-08-11** (M1–M5 + the ran≠did-not-run clause, M4 pair executed, 7 self-test lanes BLOCK/PASS symmetric); (d) **NEW, and it cuts against the row**: a capability declaring `writes: read-only` passed all of M1–M5 and its entry point then `rm -rf`'d this repo's `scripts/`. The registration bar measures *form* and *known-pair separation*, never *whether the declaration is true* — so the machinery this row now points at carries a demonstrated structural hole (`capability_composition_contract.md §Salience`). A checker whose green can precede a destructive act is not yet a green identity; (c) ~~the two nodes are copies of one scanner at different staleness~~ → **superseded 2026-08-11, but only partly**: a run now exists across two *genuinely different* capabilities (a leak lens ∪ a verdict-direction lens — different enums, different defect classes, each blocking on its own finding), and the clean arm exercised the union end-to-end. ⚠️ **That satisfies the letter of the old (c) and not the identity's spirit: both new nodes live inside FH.** This identity is *멀티하네스 클러스터*; the only run that actually crossed harness boundaries is still the older pmh-dev/qasp-dev one, whose nodes were<a name="c-orig"></a> **copies of one scanner at different staleness** (all three copies — pmh 237 ln, qasp 121 ln, FH 269 ln — share a byte-identical 12-line header; the clean arm's two `out_sha` were identical), so the run proves the channel turns and that composing unequal copies has value, not that two independent judgments were decorrelated. Artifact: `tracks/_meta/identity_audit_2026-08-09_relay_channel.md` |
| ② | 프로젝트 인큐베이터 (**🔵 RC, 2026-08-09**) | context-continuity + judgment-circuit | 🔵 RC | **RC 세 다리가 섰다** — (a) 구현: `chamber_run.sh` 6단계 게이트 (b) known-pair: 러너 게이트 **18 레인**(`test_chamber_run_lanes.sh`, BLOCK/PASS 대칭 — PASS arm 이 있어야 "전부 막는 게이트"도 걸린다) + 순서 증인 **16 레인**(`chamber_witness.sh`) (c) self-test 초록. **실상황 발화 대기 = formal chamber EMIT 아직 0** — 그것이 RC 가 🟢 이 아닌 이유이자 RC 정의 그 자체다. ⚠️ **그 0 의 해석이 2026-08-09 에 바뀌었다**: 지금까지 *"챔버가 엄격해서"* 로 읽었으나, KILL 된 후보 다수가 **메타-형** 이고 유일한 EMIT(`forge-wiki`)만 **필드-형** 이다 — 즉 *낳을 수 없었던* 게 아니라 **애초에 대상이 아닌 후보가 들어왔을** 가능성이 있다. 필드 ⊥ 메타 프로파일과 씨앗(precocial) 기준 정의: `harness_incubator_doctrine.md §3-a`. ⚠️ 그 분류는 **사후에 이뤄졌고 n=9** 라 가설이다 — 사전 등록 후 다음 런을 예측해야 결과가 된다. 아래 옛 판정 줄은 이력으로 남긴다 |
| ②-old | (이력) 프로젝트 인큐베이터 | context-continuity + judgment-circuit | 🟡 PARTIAL | incubation is running — **stockbattle is being incubated now** (S1 built, mid-flight) + qasp/pmh spin-out precedent + scaffold-emit shipped (doctrine: "emit shipped today as scaffold+approval; the chamber flow is the named target"). **Corrected 2026-08-08** (the old text read "6 runs, 6 KILL … 0/6", which was stale on both counts, and the ledger itself was missing a run): hand-counted from `tracks/_chamber/INDEX.md` — **9 full runs (#2–#10), 8 KILL, 1 EMIT** (#1 is a trigger probe, not a full run). Runs #5–#6 *measured* the emit-worthiness criterion (net-new ∧ artifact-shaped ∧ real-data-precision-adequate ∧ hub-state-independent); run #6 confirmed the graduation-order principle — hub-internal proof before standalone extraction, never the reverse. **The 🟡 is now held for a different reason than before.** The old reason ("no closed emit-via-incubation yet") is false: run #9 `forge-wiki` emitted and shipped publicly under operator approval with the Pre-Publish gate passed. What is *not* proven is that the **formal chamber flow** produced it — that run's workspace holds only an `EMISSION_VERDICT.md`, with no `INTENT.md`, `BUDGET.md` or `SIM_NOTES.md`, so the intent/budget/blind-persona gates have no artifact and the verdict was written after the fact. The first run to complete the formal flow end-to-end is #10 (2026-08-08, 3 blind isolated personas) and it KILLed. So: **the identity has fired once, the mechanism has not yet been shown to be what fired it**, and the dominance result every 🟢 owes is still outstanding → 🟡 |

### ② promotion criteria — and what the criteria themselves turned out not to be able to check

②'s 🟡 has been re-argued on different grounds each round, every round re-deriving the bar from scratch.
This section exists so the next round starts from a stated condition. **A first draft of it was refuted by
cross-family review before it was committed**, and the refutation is more useful than the draft was, so
both are recorded.

**What the draft got wrong.** It scored run #9 `forge-wiki` as **P1 FAIL** on the grounds that its
workspace holds only `EMISSION_VERDICT.md` — no `INTENT.md`, `BUDGET.md`, `SIM_NOTES.md`. But that
verdict file *contains* the substance those files would hold: the net-new determination (two survey
generations, 15+ systems / 6 standards cross-checked), the artifact-shaped determination, and the
real-code precision leg with a raw-data anchor (`forge-wiki/tests/sim_data_2026-07-18/`, N=50 concurrent
writers, A/B/C design contrast, reps=3, contaminated reps voided and re-run). Absent **files** were read
as an absent **gate** — `[[feedback_not_found_is_not_zero_family]]`, committed by the very section citing
the rule it broke. The honest score for #9 is **UNKNOWN**, not FAIL.

**What actually holds ② at 🟡, once the formalism is stripped out.** Not the missing filenames — the
missing **ordering witness**. The claim that would promote ② is *the mechanism screened this, and then it
emitted*; what #9 can show is *it emitted, and a verdict describes screening*. Nothing distinguishes a
gate that ran before the outcome from a record written after it.

**And that witness cannot currently be produced.** `tracks/**` is gitignored (`.gitignore:40` — verified
per file with `git check-ignore -v`), so no chamber artifact is under version control, and mtimes are the
only ordering evidence there is. Mtimes are trivially forgeable. So the draft's own check — "written
*before* the verdict, compare mtimes" — **cannot be satisfied by any run, honest or not**. It was an
unreachable condition, which is the shape that trains people to delete the thing being counted
(`[[feedback_unreachable_done_when_trains_evasion]]`).

**So the promotion condition is one thing, and it is a build, not a check:**

| | Condition | Check class | Status |
|---|---|---|---|
| **P1** | An EMIT run leaves an ordering record that does not depend on trusting the author — the intent/budget/sim record committed, hashed, or otherwise witnessed **outside** the gitignored workspace, before the verdict | mandatory-pass | **channel now exists (2026-08-08)** — `scripts/chamber_witness.sh`, wired into `chamber_run.sh` steps 2–5. **Still unsatisfied**: no run holds a witness yet |

**P1's channel was built, and that is not the same as P1 passing.** The row above said *not buildable
today*; that is no longer true, and the reason it was true is worth keeping because it names the shape of
the fix. The blocker was never "we lack a checker" — it was that `tracks/**` is gitignored, so the only
ordering evidence was mtime, which is trivially forgeable. The channel takes the **second form P1's own
sentence already permitted — `hashed`**: the artifacts stay in the private workspace and only their
SHA-256 goes into a tracked ledger (`knowledge/shared/learnings/chamber_ordering_witness.yaml`). Content
disclosure is zero, and the commit graph carries the ordering.

**What makes the witness bind here specifically**: `main` runs a `non_fast_forward` ruleset, so pushed
history cannot be rewritten — the commit order is not something the author can retroactively change. That
is a *precondition*, not a property of the script: if the ruleset is ever relaxed, this witness weakens
with it, and that dependency is recorded in the script header rather than assumed.

**What it does NOT prove — stated because the failure to state it is the defect this section exists for.**
A commitment proves *this content was fixed at this time*. It does not prove *the author was honest*: one
can still decide the outcome first and write an INTENT to match before committing. The attack it closes is
**retroactive rewriting** — producing a verdict and then editing INTENT to claim it was screened — and
`verify` returns `TAMPERED` for exactly that (calibrated lane, not a claim).

**Known-pair calibrated, 16 lanes**: correct order → `WITNESSED(0)` · verdict-committed-first →
`UNORDERED(1)` · post-hoc rewrite → `TAMPERED(1)` · unrecorded run → `UNWITNESSED(2)` · recorded but
uncommitted → `PENDING(2)` · missing artifact / bad slug charset / ledger-write failure → `rc=10` ·
verdict hash absent → `INCOMPLETE(2)` · gates and verdict in the **same commit** → `UNORDERED(1)` ·
only *some* gate artifacts before the verdict → not a pass · a duplicate hash from another run →
does not hide `PENDING` · single-arg call → survives · control → still 0.
**`2` is not a pass** — `not found ≠ 0` is enforced in the exit code itself, so a caller cannot read
"no record" as "no problem".

**Seven of those lanes exist because a cross-family audit found the first version fail-open**, and the
finding rate is the point: the author's own review produced **zero** of them. codex (gpt-5.5) returned 11
defects with source lines and **reproduced four of them by execution** — a ledger write to an invalid path
still printed `witnessed` and returned 0; gates and verdict in one commit passed; `INTENT` alone before the
verdict passed while `BUDGET`/`SIM_NOTES` landed after it; and a hash reused from another run masked an
uncommitted entry. Worst of all, **a run with no verdict hash at all returned `0`, which the runner rendered
as "usable as identity ② promotion evidence"** — the witness channel issuing a green with no witness, which
is the exact failure it was built to prevent. Each fix carries a lane, and two were proven non-decorative by
revert (reverting either reddens exactly one lane, 1/16).

**The nine historical runs stay `UNWITNESSED`, and are not back-filled.** Hashing them now would record
the artifacts as they are *today*, after their verdicts — a record written after the outcome, which is
precisely the thing the witness exists to distinguish. Back-filling would produce a ledger that looks
witnessed and proves nothing. So run #9 `forge-wiki` remains **UNKNOWN** on ordering, as the section above
already concluded, and P1 is first satisfiable by the **next** chamber run.

**P2 (dominance) is deliberately NOT listed**, and the reason is a finding about the gate rather than
about ②. The draft required it, citing §"Gate consequence". Checked against the table: ③ does carry a
dominance result (moat measured 3–4 family blind, HITL 8/8 ABSENT), but **⑤ is 🟢 on `intent-routing
probe 94%` — a self-measurement, not a head-to-head**. Requiring dominance of ② while ⑤ holds 🟢 without
it is a bar invented for one row. The inconsistency is real and it is **the gate's, not ②'s**: either
§Gate-consequence binds every 🟢 and ⑤ is over-scored, or it is advisory and ② must not be held to it.
Resolving that is a separate change to the status definitions — flagged here, not silently settled by
scoring ② against a rule the table does not apply uniformly.

**Recurrence count, stated precisely because the draft muddled it.** The 🟡 has been re-argued **three**
times; "promotion attempted without stated criteria" has been *recognized as a problem* **once** (today).
Those count different things, and the draft cited N=1 while asserting three re-arguments in the same
paragraph. Neither number licenses a checker right now — P1 is not implementable at all until the
ordering channel exists, so there is nothing to mechanize yet.

**Cross-cutting measured (intent-based autonomous completion)**: blind floor-tier Sonnet trigger-accuracy
probe (n=10, 2026-07-14): **should-fire 7.5/8 (94%), false-fire 0/2**. One weak trigger (simulate-first /
incubator entry absorbed into deep-clarify) — the identity-② weakness surfaces in routing too.

> **이 표가 다루는 것은 3층 중 한 층이다.** 5대 정체성이 무엇을 받치고(4대 엔진) 무엇으로
> 벼려지는지(3단 공정)는 `fh_three_layer_canon.md` 가 정본이다. **이 표의 `engine` 열이 곧
> 4대 엔진**이며(judgment-circuit=영혼 · ship-gate=품질게이트 · context-continuity=맥락유지 ·
> external-grounding=질문하기), 그 대응은 새로 만든 것이 아니라 이 표에 이미 있던 것이다.

**Verdict (2026-08-09 — supersedes the 2026-07-14 line)**: FH is tagged **`v0.1.0` = honest baseline**,
not all-green. ③⑤ are 🟢, **①②④ are 🔵 RC**, **none 🔴** — the `v0.1.0` notes state this and make no
all-green claim (per the refined 0.x↔1.0 mapping above). **`v1.0.0` remains the all-green target.**

> *Why this paragraph is being rewritten rather than edited in place*: it read **"①②④ 🟡"** for three
> sessions **after** the rows above had moved — ② to RC on 2026-08-09 (PR #281), ④ on 2026-08-09
> (PR #283), ① in this run. Each session corrected its own row and left the summary alone, which is
> `[[feedback_half_fix_propagation_boundary]]` inside a single file: the propagation boundary is not
> only "other files", it is **every place in this file that restates the same fact**. A summary that
> contradicts its own table is worse than no summary, because it is the line a reader quotes.

What now blocks `v1.0` is **closing the 🔵s** — RC means the mechanism stands in the lab, 🟢 means it
walked outside:

```
①  external-harness recommend (cluster-wizard, still parked — UNCHANGED 2026-08-11, and this is
   the one that is a *build*, not a check) · ~~capability_registry_check.sh absent~~ BUILT
   2026-08-11 · ~~a run across two genuinely different capabilities~~ RAN 2026-08-11, but both
   nodes are FH-internal — the *cross-harness* arm is still the old copies-of-one-scanner run
   · NEW: the registration bar cannot verify a declared side-effect axis (`writes: read-only`
   passed M1–M5, then the entry point deleted a directory)
②  a formal chamber EMIT — the mechanism firing in a real situation, not a retrofitted verdict
④  file-change ≠ token-introduction — the instrument is a screener, not an adjudicator
```

Each remedy is a run that leaves an artifact, tracked in `tracks/_meta/identity_audit_*.md`.

> **①② correction (2026-07-14)**: an earlier pass marked ①② 🔴 by collapsing each identity onto its most
> advanced *single mechanism* — ② onto the formal chamber EMIT (0/5), ① onto the continuous-relay channel.
> That contradicts the doctrine (emit is "shipped today as scaffold+approval; the chamber is the named
> target") and the live reality (routing runs; **stockbattle is being incubated now**; qasp/pmh spun out).
> An identity whose broad path *runs* is not 🔴 ideal-only. Both are 🟡: running, not yet closed. Lesson:
> do not score an identity by its hardest sub-mechanism — that reads a live-but-incomplete path as zero.

## For a field harness (e.g. pmh, qasp)
Same gate, its own identities. A field harness ships to its team when its identity checklist is all-green,
certified by a **실증상세 (demonstration-detail) doc in that harness's own repo** — the QA certificate
listing each identity, its PASS criterion, and the artifact proving it. FH≡field parity: what FH proves
about itself, a field harness proves about itself, by the same method. (Company-residency: a field
harness's 실증상세 lives in its own private repo; FH holds only the method, never the field's evidence.)
