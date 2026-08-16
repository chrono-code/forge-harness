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

The composition identity (**하네스 클러스터** — 2026-08-16 에 「멀티하네스 클러스터」에서 줄임, [§①-naming](#id1-naming)) is downstream of this: we equip *other* harnesses onto the
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

> 🟥 **①에 한한 예외 (운영자 결정, 2026-08-16).** 정체성 ①(하네스 클러스터)에는 이 절의
> dominance 요구를 적용하지 않고 **ⓐⓑⓒ 3기준**(재사용이 실재하고 호출 가능한가 · FH 가 안
> 커졌는가 · 뾰족함이 보존되는가)으로 대체한다. **이 절이 틀려서가 아니라 ①에 대해 겨냥이
> 틀린 계기이기 때문**이다 — ①의 산출은 «더 많이 잡았다»가 아니라 **«안 지어도 됐다»** 다.
> 결정 전에 **두 번 쟀고 둘 다 미성립**이었다(상보 · safety 동률). 근거·측정·반증조건은
> [§①-2026-08-16](#id1-20260816) 와 두 개의 사전등록/결과 쌍
> (`tracks/_meta/dominance_2026-08-16*_RESULT.md`). **다른 행은 이 절 그대로다.**
> 이 예외를 다른 행으로 넓히려면 같은 절차를 밟아라 — 사전등록 → 측정 → 미성립 → 운영자 결정.

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

**Numbering rule — engines are named, never numbered.** Write `context-continuity`, not "engine ④".
There is no canonical engine order: the table above reads *external-grounding · judgment-circuit ·
ship-gate · context-continuity*, and the prose further down this same file reads *judgment-circuit ·
ship-gate · context-continuity · external-grounding*. A number derived from one decodes to a different
engine under the other — and the two candidates for "④" are **context-continuity and
external-grounding**, which currently hold different grades, so the ambiguity is not cosmetic.
The collision is worse than one file's internal disagreement: **the identities are numbered ①–⑤ and the
engines are not numbered at all**, so a bare ① in any record is undecidable without its sentence. This
file shows it — a paragraph enumerating engines sits four lines above `③⑤ are 🟢, ①②④ are 🔵 RC`,
where those numerals mean *identities*.

> **Legacy decode (do not delete — session records already use numbers).** Records written before
> 2026-08-13 say 엔진 ①~④. They decode by the **engine table order above**:
> ① external-grounding(물어보기) · ② judgment-circuit(영혼) · ③ ship-gate(품질게이트) ·
> ④ context-continuity(맥락유지). That is the ordering those records were written under; it is
> recorded here so they stay readable, **not** to make the numbering canonical. New writing uses names.

**Why engines gate the advertised capabilities**: the harness's most-advertised surfaces — incubating a new
project, orchestrating the harness cluster — are simultaneously *long, autonomous, novel and shipping*.
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
| **Ⓑ** | **프로젝트 부스터** (booster) — 🟥 **다른 다섯과 같은 층이 아니다. 포괄 기능이되 ①②⑤ 를 «포함»하지 않고 «끌어다 쓴다» — 셋 다 부스팅 밖의 고유 범위를 갖는다** — 번호 대신 Ⓑ 를 쓰는 이유이자 §Ⓑ-layering 을 먼저 읽어야 하는 이유 | judgment-circuit + ship-gate | 🟢 **GREEN (신설 2026-08-16)** | **이 행이 없던 것이 이 표의 맹점이었다.** 온보딩 문 ③(«매핑 프로젝트 가속»)이 오래전부터 이 기능을 팔고 있었는데 등급표에 대응 행이 없었다 — 그래서 부스터는 **한 번도 등급이 매겨진 적이 없고, 약점이 발견될 자리도 없었다.** 미할당 기능은 미감사 기능이다. **인접 세 행이 이걸 안 덮는다**: ②는 *새 하네스를 낳고*(성숙한 하네스는 대상 아님), ⑤는 *사람의 의도*를 벼리고(증폭 대상이 하네스가 아니다), ①은 남의 능력을 *FH 가* 쓴다(활용 ∪ 흡수 — 둘 다 FH 가 이득 보는 방향). 부스터는 **FH 의 기계가 상대 하네스의 자체 개발을 가속하는 것**이라 셋 다와 방향이 다르다. **실적(운영자 열거 + 실측)**: pmh 는 *이 경로에서 출발했다* · mate 스킬 출하 + 인프라 배선 · 조직 환경 2건(품질 게이트 인프라 이식, 자산명은 residency 로 미기재) · clawd-on-desk · gstack. **Dominance — §Gate consequence 를 면제 없이 그대로 만족한다.** 경쟁자 = *그 하네스 자신의 개발 과정*, 결과 = 그 과정이 놓친 것을 부스팅이 잡았다: ⑴ **gstack**(외부·운영자 통제 밖) — 이슈 #1890 을 외부인 자격으로 제기, 그 레포 오너가 수정하고 **회귀 테스트 `test/claude-provider-keychain.test.ts` 로 못 박아 릴리스에 실었다**(2026-08-15). 채택 판정이 **우리가 아니라 그쪽 메인테이너**라 자기채점이 아니다. ⑵ **pmh**(2026-08-16 실측) — 이식된 자산이 대상 환경에서 **게이트가 죽은 채** 있었고 selfcheck 35 FAIL 이 CI 부재로 몇 달간 안 보였다; 부스팅 경로가 그걸 드러내고 31/31·35→2 로 닫았다. ①이 받은 dominance 면제는 **이 행에 필요하지 않다** — ①은 산출이 «안 지어도 됐다»라 겨냥이 틀렸던 경우고, 부스터의 산출은 «상대가 못 잡던 걸 잡았다»라 이 절의 정의에 그대로 맞는다. 🟥 **명시 잔여 — 초록 행의 잔여이지 보류 사유가 아니다**(①이 «(d) 안 닫힘»을 안고 🟢인 것과 같은 처리): **부스팅이 이식한 자산이 대상 환경에서 실제로 발화하는지 재는 계기가 없었다.** 2026-08-16 pmh 실측이 그 대가다 — 한 줄(`set -euo pipefail` 아래 `package.json` 읽는 할당문)이 게이트를 즉사시켰고, 30레인 회귀 스위트가 그걸 30번 보고하는데 **아무도 안 봤다**(그 레포에 CI 가 없었으므로). 승급이 아니라 **이 행의 첫 승급 기준**이 거기서 나온다(아래). ⚠️ n 은 세지 않는다 — 실적 열거는 운영자 증언 + 오늘 실측 2건이고, 조직 환경 2건은 이 파일에서 검증 불가(residency)이므로 **증언으로 표기하고 측정으로 세지 않는다** |
| ③ | 거버넌스 게이트 (governance) | ship-gate | 🟢 GREEN | pre-commit/pre-push physically block; moat measured 3–4 family blind (HITL 8/8 ABSENT); cross-family caught a real companion-store-name leak 2026-07-14 (fail-closed) |
| ⑤ | 증폭자 (amplifier) | judgment-circuit | 🟢 GREEN | short-intent→literature-grounding→ultimate-doc real instances; rules-diet −18.2k measured; intent-routing probe 94% (below) |
| ④ | 프런티어→조직 전파 (**🔵 RC, 2026-08-09**) | external-grounding | 🔵 RC | frontier-digest launchd auto + AX submission docs both real, but digest→org never closed as ONE pipeline. **2026-08-09**: the missing link was built — `scripts/digest_landing_check.sh` extracts the digest's candidate table into probes and reuses the existing landing checker (no second verifier). Self-test 8 lanes green. **🔵 RC (2026-08-09)**: the mtime defect that initially held it back is closed — the since-filter now splits two axes (git-tracked → commit time via `git log --since`; gitignored `tracks/**` → mtime, the only evidence that axis has; dirty-tracked → `UNMEASURED`), and **two lanes pin that split**: a file with only a fresh mtime is *not* counted, and a file with only a fresh commit *is* counted even when its mtime is stale. The second lane matters — without it the fix degenerates into "discard all tracked files so only negatives pass" (named by the cross-family reviewer). Self-test **10 lanes** green. **What remains is a named residual, not a calibration gap**: `file-change ≠ token-introduction` — a file committed after the digest may carry the token from before (closing it needs token-level diff, which does not fit the checker's interface). The instrument therefore prints, and this row states, that it is a **screener, not an adjudicator**: hits must be opened. Four real runs, four hand-verifications, four defects found |
| ① | 하네스 클러스터 (**🟢 2026-08-16 — 기준이 바뀌었다, 아래 §①-2026-08-16 를 먼저 읽어라**) | context-continuity | 🟢 | routing already ran for real (17 nodes, sidecar-orchestrator, Skill Bus). **The relay half is now built rather than specified**: `capability_composition_contract.md` (2026-08-02) was a complete spec with **zero implementing code** — the ① blocker was missing wiring, not missing design ([[feedback_built_but_not_wired]]). `scripts/relay_channel.sh` executes it (strictest-wins merge · typed invocation · checks 1/2/3 · short-circuit · causal binding), `scripts/test_relay_channel_lanes.sh` carries **64 lanes, BLOCK/PASS symmetric**, and three arms ran across **two real field harnesses** (pmh-dev · qasp-dev) on FH's own assets. ⭐ **The measured result is the divergence arm, and its mechanism is not what the first draft of this row said.** On `templates/.git-hooks`, `qasp` alone returns exit 0 — a single-node pass would have shipped it — and the composition returns `BLOCKED` because `pmh` returns `FINDINGS`. But `qasp`'s exit 0 is `degrade-scan: no scannable (py/sh) target files`: **zero files were scanned.** The qasp copy predates pmh's 2026-07-28 shebang pass, so extension-less hook files are invisible to it, and its exit 0 means *no target*, not *clean*. So the composition did not catch a substantive disagreement between two harnesses — it caught **a single node rendering an unmeasured surface as a pass**, which is `[[feedback_not_found_is_not_zero_family]]`, and structurally the spec's own §ⓑ.4 B1 ("the exit 0 that means I never started"). That is a *stronger* result than the first framing and a narrower one: it demonstrates the union catching a blind spot, not decorrelated judgment. **Correction also to the order claim**: both orders return `rc=2`, but in the pmh-first order the chain short-circuits at node 1 and qasp never runs — only the qasp-first order actually exercises the union. Non-decorative: reverting each wiring line reddens lanes and no reversion passes silently. **Why this is RC and not 🟢** — *updated 2026-08-11; (b) and (c) moved, (a) did not, and a fourth appeared*: (a) the row's *other* half, external-harness recommend, is still parked — **unchanged, and it is a build, not a check**; (b) ~~`scripts/capability_registry_check.sh` does not exist~~ → **built 2026-08-11** (M1–M5 + the ran≠did-not-run clause, M4 pair executed, 7 self-test lanes BLOCK/PASS symmetric); (d) **NEW, and it cuts against the row**: a capability declaring `writes: read-only` passed all of M1–M5 and its entry point then `rm -rf`'d this repo's `scripts/`. The registration bar measures *form* and *known-pair separation*, never *whether the declaration is true* — so the machinery this row now points at carries a demonstrated structural hole (`capability_composition_contract.md §Salience`). A checker whose green can precede a destructive act is not yet a green identity; (c) ~~the two nodes are copies of one scanner at different staleness~~ → **superseded 2026-08-11, but only partly**: a run now exists across two *genuinely different* capabilities (a leak lens ∪ a verdict-direction lens — different enums, different defect classes, each blocking on its own finding), and the clean arm exercised the union end-to-end. ⚠️ **That satisfies the letter of the old (c) and not the identity's spirit: both new nodes live inside FH.** This identity was then named *멀티하네스 클러스터* (shortened to *하네스 클러스터* 2026-08-16); the only run that actually crossed harness boundaries is still the older pmh-dev/qasp-dev one, whose nodes were<a name="c-orig"></a> **copies of one scanner at different staleness** (all three copies — pmh 237 ln, qasp 121 ln, FH 269 ln — share a byte-identical 12-line header; the clean arm's two `out_sha` were identical), so the run proves the channel turns and that composing unequal copies has value, not that two independent judgments were decorrelated. Artifact: `tracks/_meta/identity_audit_2026-08-09_relay_channel.md` <br><br>**<a name="id1-20260816"></a>§①-2026-08-16 — 이 행이 🟢 이 된 이유는 «더 잘해서» 가 아니라 «다른 것을 재서» 다. 그 사실을 먼저 적는다.** 🟥 **옛 바로 재면 이 행은 오늘도 🔵 다.** §Gate consequence 의 dominance 절을 **두 번** 쟀고 **둘 다 미성립**이다 — 1차(기계 스캔 vs recall, `tracks/_meta/dominance_2026-08-16_cluster_scan_vs_recall_RESULT.md`)는 **상보**: 기계는 실행 축(M4·M6)을 독점하고 recall 은 구조·정합 축을 독점한다 — 서열이 아니라 직교다. 2차(**복사 vs 호출**, survives 다리, `tracks/_meta/dominance_2026-08-16b_copy_vs_call_RESULT.md`)는 **safety 동률**: 구 enum 사본으로 `exit 4` 를 부르면 relay 가 enum 밖 값을 `HARNESS_ERROR` 로 접어 `BLOCKED`(rc=2), 소유 선언은 `OUT_OF_SCOPE` 로 `BLOCKED`(rc=2) — **둘 다 막는다.** 「복사는 조용히 썩는다」는 예측이 반증됐고, 안 썩게 막아주는 것은 이 레포가 이미 가진 «미측정≠PASS» 규율의 기계 판본이었다. 두 측정 다 **사전등록 봉인 후 실행**이고 반증 조건을 결과 뒤에 옮기지 않았다. ⇒ **운영자 결정(2026-08-16)**: ①의 🟢 기준을 dominance 에서 **ⓐⓑⓒ 3기준으로 대체**한다. 운영자 원문 — *"그들의 능력을 활용하고 **내 쪽에서 더 짓지 않기 위한(재발명을 최소화하기 위한)** 목적이 멀티하네스 클러스터"* · *"FH 의 **뾰족한 부분을 유지하면서** 능력을 최대한 쓸 수 있는 방법"* · *"오래오래 진화에 따라 **살아남으면서 얇아지면서도** 가치를 발휘 … LLM 의 진화 그리고 다른 유수의 하네스들의 진화, **그 덕을 받는 것이 목적**"* (전문 + 방법론: `tracks/_meta/doctrine_2026-08-16_identity1_redefinition_and_method.md`). ①의 산출은 «더 많이 잡았다»가 아니라 **«안 지어도 됐다»** 라서 dominance 는 겨냥이 틀린 계기다. ⚠️ **이 대체는 ①에만 적용된다** — 다른 행의 dominance 요구는 그대로다. **ⓐ 재사용이 실재하고 호출 가능한가(복붙 아님)** → ✅ **측정**: `pmh-dev:merge-noop-check` 가 **pmh 자기 레포에서** 선언되고(`.claude/capabilities/merge-noop-check.cap`, `requires_cwd: SELF`, known-pair 는 그 레포의 실제 커밋 두 개), FH 가 `cluster_capability_scan.sh discover` 로 **발견** → `capability_registry_check.sh` M1–M6 `REGISTRABLE` → `relay_channel.sh run` 으로 **실제 호출**한다. 양·음 arm 이 갈린다 — NO-OP 입력은 `FH_NODE1_VERDICT: NO_OP` 로 node1 에서 BLOCKED, 차이 있는 입력은 node1 통과(`HAS_DIFF`) 후 node2(`forge-harness:degrade-direction-scan`)가 `FINDINGS` 로 BLOCKED. **다른 노드에서 다른 이유로** 막히므로 「늘 막는 계기」와 구분된다. **ⓑ FH 가 안 커졌는가 — «안 한 일»을 이름으로 댈 수 있는가** → ✅: `merge_noop_check.sh`(트리해시 + 조상관계 판정)를 FH 는 짓지 않았고, FH 자기 정본 `knowledge/shared/rules/multi_session_close_protocol.md §1-b` 가 **그 파일을 이름으로 지목하며 «가져오면 된다»** 고 이미 적어둔 자리가 여기다. 오늘 FH 가 새로 지은 것은 **채널**(`relay_channel.sh --cap-args`, 노드별 호출 인자)이지 판단이 아니다 — 그 채널이 없는 동안 호출 시점 인자를 요구하는 능력은 **항상 `ARGS → HARNESS_ERROR → BLOCKED`** 였다(방향은 fail-closed 로 옳았으나 **신호가 0**, 즉 «호출 가능» 을 구조적으로 만족시킬 수 없었다). **ⓒ 뾰족함이 보존되는가** → ✅ **측정**: 합성이 `FH_MERGED_residency: company`(둘 중 엄격한 쪽) · `verdict_binding` 은 4값 합집합 · 상류가 막히면 하류 노드 미실행. 🟥 **명시 잔여 — 축소하지 않는다.** ⑴ **두 측도를 갈라 적는다.** **㉮ 선언 보유 하네스 = 2**(FH · pmh) — *능력(capacity)* 측도. **㉯ 실제로 함께 돈 하네스 = 5** — *사건(event)* 측도이고 정체성이 묻는 쪽이다. 🟥 **단일 합성 한 번에 5개가 돌았다(실측, 세션 말)**: `relay_channel.sh run` 4노드 체인이 `gstack`(어댑터) → `pmh-dev`(소유 선언) → `mate-dev`(어댑터) → `qasp-dev`(어댑터) 를 태우고 FH 가 그 사이에서 병합했다 — 청정 arm 은 **네 노드 전부 실행 후 `FH_RELAY_VERDICT: PASS`(rc=0)**, 교란 arm 은 node3 `FAIL` 에서 `BLOCKED` + 하류 미실행(rc=2). **늘 통과하지도 늘 막지도 않는다.** 병합 결과: `residency: company`(다섯 중 최엄격) · `verdict_binding` **9값 합집합**. ⚠️ ㉮ 가 여전히 2인 것은 나머지 셋이 **어댑터**(FH 소유·FH 유지)이기 때문이고, 그게 결함이 아니라 운영자 결정으로 정해진 **기본 경로**다(§선언 위치). ㉮ 가 커지는 것은 남이 «노출한다» 고 자기 정본에 적었을 때뿐이다. 그리고 ㉮ 가 여전히 작다는 사실은 남는다: ⚠️ **부풀리지 않는다**: clawd-on-desk 는 하네스 자산이 없는 **대상 레포**라 PR #888 은 기여였지 하네스 주행이 아니다 — 세지 않았다. 그리고 ㉮ 가 여전히 작다는 사실은 남는다: qasp 는 **그 하네스 자신의 입장리뷰가 REJECT** 했다 — 정본 근거 0건 · 소비자 0곳(읽는 건 FH 뿐) · `session.md:101` 「n=3 전엔 추상화 금지」 위반 · **그 선언 경로가 그 하네스의 조직 미러 대상에서 제외돼 있지 않다**(운영자가 이 레포에서 통제하지 않는 목적지로 그대로 복제된다). 운영자 결정(2026-08-16)으로 **보류**이며, 「이 하네스는 외부 하네스에 자기 인터페이스를 노출한다」를 **그 하네스 자신의 정본에 적는 것**이 선행 조건이다. 선언 파일이 남의 레포에 **있다**는 것과 그 하네스가 노출을 **결정했다**는 것은 다른 명제다. ⑵ 🟥 **(d) 는 안 닫혔다.** `.git/objects` 를 감시면에 넣어 객체 쓰기 한 부류를 닫았고(probe L13 탐지 / L13b 과차단 컨트롤 / 되돌림 시 정확히 L13 만 적색), **그러나 M6 는 선언된 캘리브레이션 arm 만 관측한다** — 실증: `merge_noop_check.sh` 는 **분기 입력에서 git 객체를 쓰는데**(격리 클론 실측: `.git/objects` 파일 수가 **+1**. ⚠️ 절대값은 클론 상태에 의존하므로 **델타만 인용한다** — 이전 판본이 적었던 절대 쌍은 재현 불가라 철회한다) 선언된 두 arm 이 그 경로를 안 지나므로 `writes: read-only` 로 거짓 선언해도 `REGISTRABLE` 이 난다(실측 확인). 같은 날 아침에 나온 **「검사기에 enum↔구현 일치 축이 없다」와 같은 형태**다 — 같은 stale 선언이 캘리브레이션 쌍에 따라 REJECTED 도 REGISTRABLE 도 된다. 한 문장으로: **검사기는 선언이 시키는 것만 본다.** ⑶ 그러므로 이 🟢 은 **「클러스터가 실제로 돈다」**에 대한 것이지 **「등록 바가 선언의 진위를 검증한다」**에 대한 것이 아니다. 후자는 열려 있고, 열려 있다고 적는다. Artifact: `tracks/_meta/identity_audit_2026-08-16_cluster_green.md` <br><br>**<a name="id1-naming"></a>§①-naming (운영자 결정, 2026-08-16) — 이름을 줄이고, 그 안의 하중 부품에 이름을 준다.** 「멀티하네스 클러스터」 → **「하네스 클러스터」**: 「멀티」와 「클러스터」가 둘 다 복수를 뜻해 **중복이었다**. 그리고 그 아래에 **크로스하네스**를 둔다 — *"서로간의 능력을 보강하기 위함이야. **없는 걸 쓰기 위함**이고, FH 에서 **‘짓지 않아도 되는 것’을 다른 레포 개발에 활용**하기 위함이지. 다만 그 와중에 **FH 에서 지어야 하는 게 보이면 개선해서 답습**하는 거고."*(운영자) ⇒ **크로스하네스는 양방향이다**: **활용**(남의 능력을 호출해 FH 가 안 짓는다) **∪ 흡수**(FH 가 지어야 할 것이 보이면 개선해 들여온다). 종전 정의는 앞의 절반뿐이었다. 🟥 **둘의 관계는 합집합이 아니라 «포함 + 하중»이다.** 운영자: *"하네스 클러스터가 돌려면 크로스하네스는 항상 있어야 하니까."* ⇒ **크로스하네스는 하네스 클러스터의 필요조건**이고, 그래서 판정에서 다음이 따라 나온다 — **ⓐ(«재사용이 실재하고 호출 가능한가»)가 곧 크로스하네스 시험이고, 그게 이 정체성의 결박 지점이다.** 노드 수 n 은 클러스터의 **범위**를 재지 «도는가»를 재지 않는다. (이 구분이 없어서 이 행의 잔여 ⑴이 «n=1»을 마치 미성립처럼 읽히게 적혀 있었다 — n=1 에서도 교환은 실제로 일어났다. 다만 **n 을 늘리는 것은 여전히 옳고, 그건 선언이 없어서지 기제가 없어서가 아니다**: 실측 2026-08-16, 매핑된 하네스 12개 중 선언 보유 2개 · 나머지 10개는 `.claude/capabilities` 디렉토리 자체가 없다. 도구는 있다 — gstack `bin/*`=69 · gbrain 50 · openhuman 43 · mate-dev 7 · qasp-dev 16.) 🟥 **크로스하네스는 두 형태를 갖고, 둘 다 «건넜다»에 든다(운영자, 2026-08-16).** **기계 형태** = 남의 능력을 typed 채널로 호출한다(`.cap` 선언 필요) · **판단 형태** = **남의 정본을 근거로 심사받는다**(입장리뷰 — 선언 불요). 운영자: *"입장리뷰도 크로스가 아닐까 … 결국 너와 그쪽 하네스 2개가 동시에 도는 거니까."* ⇒ **판단 형태는 선언 없이 지금 당장 모든 하네스에서 성립한다**, 그리고 **한 번의 크로싱이 이미 하네스 2개의 동시 주행**이다. *"크로스하네스는 노드 1개라도 발휘되는 거고 … 그게 늘어나면 클러스터가 되는 거고."* ⇒ **크로스하네스 = 사건(건넜다) · 하네스 클러스터 = 그 사건의 누적.** 🟥 **이 문장이 아래 잔여 ⑴의 계수 오류를 잡는다** — 나는 «외부 **선언** 수»를 셌는데 정체성이 묻는 것은 «**함께 돈 하네스** 수»다. 두 측도를 갈라 적는다(둘 다 남긴다, 유리한 쪽만 남기지 않는다). 🟥 **명칭 경계 — 알고 쓴다.** `cross-harness` 는 이 레포에서 **이미 다른 뜻**으로 쓰인다: `CLAUDE.md §Standpoint axis` · `field_verdict_crossfamily_gate.md §7` 의 *"cross-harness-boundary change"* = **다른 하네스의 동작·게이트 결과·상호작용 계약을 바꾸는 diff**(게이트 트리거 범위). 정체성 이름이 「하네스 클러스터」로 남으므로 **최상위 층에서는 충돌하지 않지만**, 하위 기제 「크로스하네스」와는 여전히 같은 낱말이다 — 구분: **명사 「크로스하네스」 = 능력 교환(이 정체성의 필요조건)** · **형용구 cross-harness-boundary = 그 게이트의 적용 범위**. 섞어 쓰지 마라. 🟥 **ⓑ 기준이 양방향화에 맞춰 «좁아진다»(느슨해지는 게 아니다).** 흡수를 허용하면 ⓑ(«FH 가 안 커졌는가»)가 그대로는 무력해지므로: **FH 는 «닫는 FH 결함을 이름으로 댈 수 있을 때만» 커진다.** 새 규율이 아니라 이미 있는 증거-임계 빌드 규율(`fh_signal_2026-08-16_expedition_two_tracks.md` §경계 2 — *"«좋아 보여서»가 아니라 «우리 결함이 그걸 요구해서»"*)을 ⓑ 의 판정 문구로 승격시킨 것이다. ⇒ **ⓑ = ⑴ 호출로 대체한 것을 이름으로 댈 수 있고, ⑵ 새로 지은 것은 각각 닫는 FH 결함을 이름으로 댄다.** 오늘 실적: 대체 = `merge_noop_check.sh`(안 지었다) · 신축 = `--cap-args` 채널(닫는 결함 = «호출 시점 인자를 요구하는 능력이 relay 를 통과할 방법이 없다», 실측) + `.git/objects` 감시(닫는 결함 = «`writes: read-only` 거짓 선언이 VERIFIED 를 받는다», 실측). 둘 다 이름이 붙는다. 🟥 **선언 위치는 두 종류이고, 기본은 «어댑터»다(운영자 결정 2026-08-16 — 초판은 이걸 거꾸로 적었다).** 운영자: *"사용자들은 다들 대상 레포에 짓지 않을 거야. **FH 내부에 상주시키겠지.** 필요하다면 개인용 레포로 분리해서 관리할 거고."* · *"로컬에서 작업하기 위한 거니까 **어댑터는 내장되어 있어야지.**"* ⇒ **어댑터 선언 = 기본 경로**(FH 안 `.claude/capabilities/adapters/` + FH 소유 스크립트, **유지 책임은 FH**, peer 는 **이름으로 해석**해 tracked 파일에 홈 절대경로를 안 싣는다). **소유 선언 = 특권적 경우** — 그 하네스를 소유하고 **동시에** 「외부 하네스에 인터페이스를 노출한다」를 **그 하네스 자신의 정본에 적었을 때만**(pmh-dev 가 그 유일한 사례다). 🟥 **이 뒤집기는 실측이 강제했다**: qasp 입장리뷰가 남의 레포 안 선언을 REJECT 했고(정본 근거 0건 · 소비자 0곳 · n=3 규칙 위반 · 조직 미러 노출), gstack 은 **애초에 남의 공개 레포(READ 권한)라 푸시 자체가 불가능**했다 — 즉 소유 선언은 «드문 경우»가 아니라 **대부분의 경우 성립조차 하지 않는다.** 어댑터가 허용되는 근거는 dominance-2 가 잰 것이다 — 복사 vs 호출이 **safety 동률**이었고 차이는 «정보와 유지 책임»뿐이었다. 라벨과 FH 소유가 그 차이를 닫는다. ⚠️ **residency 경계**: `company` peer 의 어댑터는 **tracked 로 두지 않는다** — 커밋 시점 공개표면 스캔이 floor 이지만, 판단이 먼저다. ⚠️ **미결 — 운영자 결정 대기**: *"운영자 환경에서는 상시 제안 가능. 사실 제안도 자동으로 반영 가능"*. 제안의 **자동 반영**은 자율성 확장이라 §Operational Adaptation Loop 의 action-class floor 를 그대로 통과해야 한다 — 흡수 커밋 자체는 가역이지만 **그것이 publish 를 먹이면 taint 가 전파**되고, 그 경우 registry floor 가 `promotion_eligible` 을 금한다. 바운드된 형태(운영자 환경 한정 · 가역 표면 한정 · typed 기록 필수 · 게이트는 그대로)로 좁히기 전엔 자동화하지 않는다. **미구축이며, 미구축이라고 적는다.**
| ② | 프로젝트 인큐베이터 (**🔵 RC, 2026-08-09**) | context-continuity + judgment-circuit | 🔵 RC | **RC 세 다리가 섰다** — (a) 구현: `chamber_run.sh` 6단계 게이트 (b) known-pair: 러너 게이트 **18 레인**(`test_chamber_run_lanes.sh`, BLOCK/PASS 대칭 — PASS arm 이 있어야 "전부 막는 게이트"도 걸린다) + 순서 증인 **16 레인**(`chamber_witness.sh`) (c) self-test 초록. **실상황 발화 대기 = formal chamber EMIT 아직 0** — 그것이 RC 가 🟢 이 아닌 이유이자 RC 정의 그 자체다. ⚠️ **그 0 의 해석이 2026-08-09 에 바뀌었다**: 지금까지 *"챔버가 엄격해서"* 로 읽었으나, KILL 된 후보 다수가 **메타-형** 이고 유일한 EMIT(`forge-wiki`)만 **필드-형** 이다 — 즉 *낳을 수 없었던* 게 아니라 **애초에 대상이 아닌 후보가 들어왔을** 가능성이 있다. 필드 ⊥ 메타 프로파일과 씨앗(precocial) 기준 정의: `harness_incubator_doctrine.md §3-a`. ⚠️ 그 분류는 **사후에 이뤄졌고 n=9** 라 가설이다 — 사전 등록 후 다음 런을 예측해야 결과가 된다. 아래 옛 판정 줄은 이력으로 남긴다 |
| ②-old | (이력) 프로젝트 인큐베이터 | context-continuity + judgment-circuit | 🟡 PARTIAL | incubation is running — **stockbattle is being incubated now** (S1 built, mid-flight) + qasp/pmh spin-out precedent + scaffold-emit shipped (doctrine: "emit shipped today as scaffold+approval; the chamber flow is the named target"). **Corrected 2026-08-08** (the old text read "6 runs, 6 KILL … 0/6", which was stale on both counts, and the ledger itself was missing a run): hand-counted from `tracks/_chamber/INDEX.md` — **9 full runs (#2–#10), 8 KILL, 1 EMIT** (#1 is a trigger probe, not a full run). Runs #5–#6 *measured* the emit-worthiness criterion (net-new ∧ artifact-shaped ∧ real-data-precision-adequate ∧ hub-state-independent); run #6 confirmed the graduation-order principle — hub-internal proof before standalone extraction, never the reverse. **The 🟡 is now held for a different reason than before.** The old reason ("no closed emit-via-incubation yet") is false: run #9 `forge-wiki` emitted and shipped publicly under operator approval with the Pre-Publish gate passed. What is *not* proven is that the **formal chamber flow** produced it — that run's workspace holds only an `EMISSION_VERDICT.md`, with no `INTENT.md`, `BUDGET.md` or `SIM_NOTES.md`, so the intent/budget/blind-persona gates have no artifact and the verdict was written after the fact. The first run to complete the formal flow end-to-end is #10 (2026-08-08, 3 blind isolated personas) and it KILLed. So: **the identity has fired once, the mechanism has not yet been shown to be what fired it**, and the dominance result every 🟢 owes is still outstanding → 🟡 |

### <a name="b-layering"></a>§Ⓑ-layering — **프로젝트 부스터**는 여섯 번째 행이 아니라 **다른 층**이다 (운영자, 2026-08-16)

> 🟥 **먼저 — 이 절을 위계도로 읽지 마라. 이 표는 분류학이 아니라 재고 목록이다.**
> 운영자(2026-08-16): *"사실 계층구조로 지으면 5대 정체성은 **서로를 먹고 먹지만**, 그럼에도
> 정체성을 두는 이유는 **여기에 뭐가 있는지를 볼 수 있게** 하기 위함이야. 실제로는 유기적으로
> 서로 연결되고 조합하여 사용해내게 되는 거지."*
>
> 아래 관계 서술은 **«무엇이 무엇 밑이다»를 굳히려는 게 아니라, 각 행이 서로 다른 범위를 갖는다는
> 증거**다. 관계를 정밀화할수록 표는 실제 사용과 멀어진다 — 현장에서는 한 작업이 ①⑤ 를 같이
> 태우고 그 결과가 ② 로 흐른다. **정합한 위계를 못 그리는 것은 이 표의 결함이 아니다.**
>
> ⇒ 그래서 Ⓑ 부재의 비용도 «위계가 틀렸다»가 아니다. **목록에 없어서 안 보였고, 안 보이니 감사가
> 물을 수 없었다** — 그게 전부이고, 그거면 충분히 비싸다.

이 항목의 초판은 부스터를 «⑥» 으로, 즉 나머지 다섯과 **나란한 여섯 번째 정체성**으로 적었다.
운영자가 그걸 정정했다: *"증폭자, 하네스클러스터 이 두 개가 사실 부스팅을 위한 **과정적
정체성**인데 부스터는 **포괄적 기능**이라고 보는 게 맞을지도 모르겠다"* · *"인큐베이터도
비슷한 것 같네."*

🟥 **그리고 그 정정의 초판도 과했다 — 운영자가 같은 자리에서 두 번 고쳤다.** 초판은 위 문장을
«Ⓑ 가 ①②⑤ 를 **포함**한다»로 옮겨 적었는데, 운영자가 되물었다: *"증폭자는 하네스를 부스팅하기
위한 것뿐만이 아니라 **훨씬 범용적으로** 쓸 수 있는 거 아닌가?"* 맞다. 그리고 같은 잣대를 나머지
둘에 대면 셋 다 포함관계가 아니다:

| 행 | 부스팅 밖의 범위 | 그래서 |
|---|---|---|
| ⑤ 증폭자 | **사람의 의도** 전반. `CLAUDE.md §Intent Marshaling` 이 하네스가 전혀 안 끼는 일반 작업(문서·리서치·정리)까지 명시적으로 이 아래 둔다 | Ⓑ 보다 **넓다** |
| ① 하네스 클러스터 | 남의 능력을 **FH 가** 써서 FH 가 안 짓는다 — 수혜자가 FH 다 | Ⓑ 와 **방향이 반대** |
| ② 프로젝트 인큐베이터 | **유닛을 낳는다 — 하네스만이 아니다.** 「프로젝트」는 더 큰 틀로 고른 이름이고 범위가 **하네스 · 스킬 · 에이전트 · 하네스 형태가 아닌 일반 레포**까지다(운영자, 2026-08-16). 부스팅은 낳은 뒤에 온다 | **순차**지 종속이 아니다 |

⇒ **관계는 «포함»이 아니라 «끌어다 쓴다»(uses)** 다.

```
          Ⓑ 프로젝트 부스터      ← 포괄 기능이되, 셋을 소유하지 않는다
             ↑ 끌어다 쓴다 (uses, not contains)
          ⑤ 증폭자 · ① 하네스 클러스터 · ② 프로젝트 인큐베이터
             — 각자 부스팅 밖의 고유 범위를 갖는다 (위 표)
             ② 의 산출 유닛 = 하네스 · 스킬 · 에이전트 · 일반 프로젝트 레포
```

이 구분이 실질을 바꾼다: 포함이면 ①②⑤ 의 등급이 Ⓑ 의 등급에 종속되고, **끌어다 쓰는 관계면
각 행이 자기 승급 기준을 그대로 진다.** 후자가 맞고, 그래서 Ⓑ 신설이 다른 행의 등급을 하나도
건드리지 않는다.

**이게 왜 «행이 없었나»를 설명한다.** 부스터는 다섯과 같은 층에 없었으므로 다섯을 아무리
들여다봐도 나오지 않는다 — 빠진 게 아니라 **층이 하나 접혀 있었다.** 다섯은 각각 자기 자리에서
감사됐고, **그것들을 무엇에 쓰고 있었는지**는 표에 적힌 적이 없다.

🟥 **그리고 «왜 아무도 안 적었나»의 답은 «빠뜨렸다»가 아니다.** 운영자: *"부스터가 비워져
있던 이유는 사실 FH 자체의 **너무나도 당연한 기본 정체성**이었기 때문이야. 가장 근원적인 것.
계속 **숨쉬듯이** 해왔으니까. 그 위에 5개 정체성이 서게 되었는데."*

이건 흔한 사각과 **방향이 반대다.** 보통 놓치는 것은 드물고 눈에 안 띄는 것인데, 이것은
**항상 하고 있어서 안 보였다.** 사람은 자기가 끊임없이 하는 일을 명제로 적지 않는다 — 적을
이유를 못 느끼기 때문이고, 그래서 **가장 근원적인 항목이 가장 늦게 문서화된다.**

⇒ 이 표에 대한 진단 질문이 하나 생긴다: **«우리가 매일 하고 있는데 여기 적혀 있지 않은 것은
무엇인가»** — 없는 것을 찾는 게 아니라 **있는데 너무 흔해서 안 세는 것**을 찾는 물음이다.
`[[feedback_reinvention_reflex_normalization_counterweight]]` 의 사촌이되 반대 극이다: 저쪽은
낯선 것을 익숙한 것으로 접는 반사고, 이쪽은 **익숙한 것을 아예 항목으로 세지 않는 반사**다.

**난이도 순서가 등급을 설명한다(정합성 확인).** 운영자: *"인큐베이터는 이 부스팅보다
어렵기에(**없는 걸 만드는 자리니까**) 초록이 되기까지 오래 걸린 거였고."* ⇒ 있는 것을 빠르게
하는 일(Ⓑ) < 없는 것을 만드는 일(②). 그러므로 **Ⓑ 가 🟢 이고 ② 가 🔵 RC 인 것은 이상이
아니라 예상되는 순서다.** 만약 반대였다면 둘 중 하나의 등급을 의심해야 했다.

**명명이 평행한 것은 우연이 아니다 — 두 행의 유닛 범위가 같기 때문이다(운영자, 2026-08-16).**
② 가 「하네스 인큐베이터」가 아니라 **「프로젝트 인큐베이터」**인 이유가 *"하네스를 인큐베이팅하기
위한 것도 있지만 **스킬이나 에이전트도** 인큐베이팅하기 위해 더 큰 틀로 프로젝트라 명명한 것"*
이고, *"하네스 형태가 아니더라도 **프로젝트 레포**를 만들어 줄 수도 있"*다. 부스터도 같은 범위를
다루므로 **「프로젝트 부스터」**다. 초판이 「하네스 부스터」로 적은 것은 ② 를 「하네스를 낳는다」로
좁게 적은 것과 **같은 실수**이며, 같은 자리에서 두 번 났다.

```
유닛 난이도 사다리 (두 행 공통)
   일반 프로젝트 레포  <  스킬  <  에이전트  <  하네스
   ↑ 쉽다                                      ↑ 가장 어렵다
```

**⇒ 등급 판정 규칙(운영자): «하네스까지 도달해 있으면 이미 초록이다».** 하네스가 사다리 꼭대기라
거기 닿았다는 것은 아래 단계를 이미 통과했다는 뜻이다.
🟥 **이 사다리는 «하네스까지 할 수 있습니다»이지 «하네스만 가능하다»가 아니다**(운영자, 2026-08-16).
포함 관계이지 배타가 아니다 — 하네스에 도달하려면 **그 전까지의 모든 것이 가능해야** 하므로,
꼭대기 칸의 실적은 아래 칸들의 실적을 **함께 주장한다**. 그래서 Ⓑ 의 🟢 은 «하네스를 부스팅한다»가
아니라 **«일반 레포부터 하네스까지 부스팅한다»**로 읽어야 하고, 반대로 아래 칸 실적만 있는 상태를
꼭대기 실적으로 올려 읽어서도 안 된다. 이 자로 두 행을 같이 재면 현재 등급이
설명된다 — **Ⓑ 는 하네스 급 대상(pmh · gstack · mate)에서 실적이 있어 🟢**, **② 는 유일한 EMIT 이
사다리의 아래쪽 유닛이라 아직 🔵**. 두 행이 다른 등급인 것은 서로 다른 잣대를 써서가 아니라
**같은 사다리의 다른 칸에 도달했기 때문**이다.

**기전(운영자 비유)**: *"실무자도 사회초년생을 가르치는 자보다 **3년 이상 실무한 사람을 옆에서
부스팅**해주는 게 훨씬 쉬운 것과 마찬가지."* 3년차에게는 이미 판단·맥락·도는 루프가 있어
**지렛대를 대면 된다**. 신입에게는 그 엔진 자체를 **만들어 줘야** 한다. 부스터는 전자, 인큐베이터는
후자다.

🟥 **그래서 이 행이 실제로 주장하는 범위는 좁게 적어야 한다.** 부스터의 난이도는 **대상의
성숙도에 반비례**하고, 위 실적의 대상은 **전부 이미 도는 개발 과정을 가진 하네스**였다(pmh ·
gstack · mate · 조직 환경 2건 — 어느 것도 무에서 시작하지 않았다). 그러니 이 🟢 은 «성숙한
엔진에 지렛대를 댔다»에 대한 초록이지 «무에서 길렀다»에 대한 초록이 아니다 — 후자는 ②의
자리이고 ②는 아직 🔵 다.
⇒ 승급 기준 4로 승격: **실적을 셀 때 대상의 성숙도를 같이 기록한다.** 안 그러면 «하네스 6개를
부스팅했다»가 «도는 엔진 6개를 가속했다»와 «6개를 무에서 길렀다» 사이에서 **어느 쪽인지 모르는
숫자**가 된다. 지금까지의 실적은 전부 전자이며, 그렇게 적는다.

⚠️ **③ 과 ④ 는 이 아래로 넣지 않았다 — 운영자가 그 둘을 말하지 않았고, 내가 대신 정할 일이
아니다.** 잠정 관찰만 남긴다: ③ 거버넌스 게이트는 부스팅을 *포함한* 모든 행위가 통과하는
품질 바닥이라 하위라기보다 **직교**로 보이고, ④ 프런티어→조직 전파는 대상이 하네스가 아니라
조직이라 **다른 축**일 수 있다. 둘 다 운영자 판단 대기이며, 그때까지 이 표에서 위치를
바꾸지 않는다.

⚠️ 그리고 **계보와 포함은 다른 관계다.** 운영자는 별도로 *"부스터로부터 모든 정체성이
발아했다"* 고도 말했는데, 그건 «부스터가 나머지를 포함한다»가 아니라 **«나머지가 거기서
나왔다»**다. 씨앗이 나무를 포함하지 않는다 — 각 행은 자기 승급 기준을 그대로 진다.

### §Ⓑ-genealogy — 그리고 계보상으로도 **첫 번째**다 (운영자, 2026-08-16)

운영자 원문: *"부스터로부터 모든 정체성이 발아했다고 보면 될 정도임."* 이 행이 표에 **늦게 추가된
것**은 발견 순서이지 계보의 순서가 아니다. 나머지 행들이 전제하는 것을 보면 이유가 보인다:

- **① 하네스 클러스터**는 *클러스터할 남의 하네스가 존재하고 연결돼 있어야* 성립한다. 그 하네스들이
  존재하고 연결된 경위가 부스팅이다. pmh 는 이 경로에서 **출발했다**.
- **② 인큐베이터**가 방출한 것은 방출로 끝나지 않는다 — 길러진다. 그 기르는 행위가 부스팅이다.
- **⑤ 증폭자**는 사람의 의도를 벼리고, 부스터는 그렇게 벼려진 것을 **다른 하네스에 실어 나른다**.

🟥 **그래서 이 행의 부재가 비쌌다.** 등급표는 FH 가 자기를 감사하는 계기인데, 계보상 첫 번째인 기능에
행이 없으면 그 기능은 매 감사에서 **구조적으로 시야 밖**이다. 2026-08-16 pmh 실측(이식 자산이 대상
환경에서 죽어 있었고 몇 달간 안 보였음)은 그 사각의 청구서다.

⚠️ **여기서 «모든 정체성이 부스터에서 나왔다»를 «부스터가 나머지를 포함한다»로 읽지 마라.** 계보와
포함은 다른 관계다. 씨앗이 나무를 포함하지 않는다 — 각 행은 자기 승급 기준을 그대로 진다.

### §Ⓑ promotion criteria — 이 행이 지킬 것

🟢 로 신설됐으므로 이 절은 «어떻게 올라가나»가 아니라 **«무엇이 이 행을 내릴 수 있나»**를 적는다.
잔여가 닫히는 조건이자, 다음 감사가 이 행에 물어야 할 질문이다.

1. **이식 발화 검사 (핵심 잔여, 미구축).** 부스팅이 대상 하네스에 자산을 이식했을 때, 그 자산이
   **대상 환경에서 실제로 발화하는가**를 재는 계기가 없다. 2026-08-16 의 실패 형태가 정본이다:
   저자 레포에는 있고 대상 레포에는 없는 전제(여기서는 npm 표면)를 자산이 조용히 깔고 있었고,
   **저자 환경에서는 31/31 초록**이었다. ⇒ 판정은 **대상 환경에서** 이뤄져야 한다. 판별선은
   `harness_incubator_doctrine.md §3-b` 의 것을 그대로 쓴다 — **«아무것도 하기 전에 죽는다»(rc=1)**
   와 **«돌았고 타입 있는 verdict 를 낸다»(HARNESS_ERROR)** 는 다른 상태다.
2. **가속과 오염을 가른다.** 부스팅은 **자산을 이식하는 행위**라, 이식되는 것에는 저자 하네스의
   결함도 같이 실린다. 이 행의 실적은 «몇 개를 이식했나»가 아니라 «이식된 것이 **거기서** 도나»로
   센다. 전자는 활동량이고 후자만 결과다.
3. **조직 환경 실적은 증언으로 남고 측정으로 세지 않는다.** residency 때문에 이 파일에서 검증할 수
   없고, 검증 못 하는 것을 숫자에 넣으면 그 숫자 전체가 못 쓰게 된다.

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
not all-green. ~~③⑤ are 🟢, **①②④ are 🔵 RC**~~ → **2026-08-16: ①③⑤ are 🟢, ②④ are 🔵 RC**,
**none 🔴** — the `v0.1.0` notes state this and make no
all-green claim (per the refined 0.x↔1.0 mapping above). **`v1.0.0` remains the all-green target.**
🟥 **①의 🟢 은 기준이 바뀐 결과다** — 옛 dominance 절로 재면 오늘도 🔵 이고, 두 번 쟀고 둘 다
미성립이었다. 무엇이 왜 바뀌었는지는 [§①-2026-08-16](#id1-20260816) 을 읽어라. **그 행이 명시
잔여 셋(외부 소유 선언 n=1 · qasp 보류 · (d) 미해결)을 함께 지고 있고, 그걸 빼고 인용하지 마라.**

> *Why this paragraph is being rewritten rather than edited in place*: it read **"①②④ 🟡"** for three
> sessions **after** the rows above had moved — ② to RC on 2026-08-09 (PR #281), ④ on 2026-08-09
> (PR #283), ① in this run. Each session corrected its own row and left the summary alone, which is
> `[[feedback_half_fix_propagation_boundary]]` inside a single file: the propagation boundary is not
> only "other files", it is **every place in this file that restates the same fact**. A summary that
> contradicts its own table is worse than no summary, because it is the line a reader quotes.

What now blocks `v1.0` is **closing the 🔵s** — RC means the mechanism stands in the lab, 🟢 means it
walked outside:

```
①  ✅ **CLOSED 2026-08-16 — 이 행은 더 이상 v1.0 을 막지 않는다.** 아래는 이력이다:
   ~~external-harness recommend (cluster-wizard, still parked)~~ → **BUILT + 머지**
   (`scripts/cluster_capability_scan.sh`, PR #399 / main `db33a7e`) · ~~capability_registry_check.sh
   absent~~ BUILT 2026-08-11 · ~~both nodes are FH-internal~~ → **크로스하네스 유니온이 실주행**
   (`pmh-dev:merge-noop-check` = pmh 자기 레포 소유 선언 ∪ FH 자기 선언, 양·음 arm 이 다른
   노드에서 다른 이유로 막힌다) · dominance 절은 **①에 한해 ⓐⓑⓒ 로 대체**(운영자 결정,
   [§①-2026-08-16](#id1-20260816))
   🟥 **다만 (d) 는 안 닫혔다** — 「선언된 부작용 축을 검증 못 한다」. `.git/objects` 감시로 한
   부류를 닫았으나 **M6 는 선언된 캘리브레이션 arm 만 관측한다**(실증: 분기 입력에서 객체를 쓰는
   능력이 `writes: read-only` 거짓 선언으로 통과). ⚠️ 이건 이제 **①의 블로커가 아니라
   «등록 바의 열린 결함»** 으로 재분류된 것이다 — ⓐⓑⓒ 가 «바가 선언을 검증한다」를 요구하지
   않기 때문이지 **문제가 사라졌기 때문이 아니다.** 별도 항목으로 계속 추적한다
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
