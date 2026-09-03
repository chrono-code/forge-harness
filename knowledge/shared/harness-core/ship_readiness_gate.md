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
an `identity-v1.0.0`; only REALIZED does.

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
The formal release tag is **independent of the npm package version**. The npm version (**2.6.0** as of
2026-08-21; ⚠️ this parenthetical said `1.4.x` until then — a version number written into prose goes
stale silently and reads as fact, so verify it against `package.json` before citing) is the
**plugin-cache lockstep number** — it bumps on every shipped-asset change so Codex/
marketplace cache-invalidate; it is not a maturity claim. The **formal identity-maturity release starts at
`v0.1.0`**. Do not conflate the two counters; a high npm number does not make the harness mature.

🟥 **Tag namespace — the two counters must not share one (added 2026-08-21, operator-approved).**
They did, and it broke the public surface: both tracks used `vX.Y.Z`, only the maturity track had
GitHub *Release* objects, so the Releases page advertised **`v0.3.0` (2026-08-16) as "Latest"** while
the shipped package was **2.6.0**. A visitor could not tell which number was newer or what either meant.

This is the same defect class this repo keeps finding in its gates — **two layers, one name** (a CI
`paths:` filter read as the local hook; a leg scoped to load-bearing changes read as scoped to every
marker, both measured 2026-08-21). The fix is never "merge the layers"; the two counters measure
genuinely different quantities and collapsing them destroys the maturity signal. The fix is to stop
sharing the name:

```
maturity track   identity-v0.4.0 onward       (v0.1.0 · v0.2.0 · v0.3.0 keep their names)
package track    v2.6.0 onward, unchanged     tags only — NO GitHub Release objects (see below)
```

🟥 **The Releases page carries the maturity track ONLY — and this was measured, not assumed.**
On 2026-08-21 a Release object was created for `v2.6.0` to make "Latest" reflect what ships. It was
deleted the same hour, by operator decision, because it solved the wrong half: **GitHub gives exactly
one "Latest" badge**, so two tracks on one page compete for it and the holder defines what the repo
announces. The package number took the headline and pushed the maturity claim under it. The misreading
that prompted it was already closed by the cheaper half — a one-line header on the existing release
bodies. ⇒ **package releases live in `CHANGELOG.md` and the registry, not here.** The `v2.x` tags
remain (a deleted Release does not delete its tag — verified).

🟥 **Releases 페이지에서 두 트랙을 «눈으로» 가르는 규약 (2026-09-03, 운영자 지적 「npm 이랑 같이 올라오는데
어떻게 구분」)**: 태그 접두만으로는 목록에서 안 갈린다. GitHub 이 주는 시각 장치 둘을 트랙에 고정한다 —
**제목 접두** 📦(패키지 `vX.Y.Z`) / 🧭(정체성 `identity-vX.Y.Z`) · **배지** Latest 는 **패키지 트랙만**,
정체성 트랙은 전부 **Pre-release**(0.x = «전부 🟢 아직 아님»이라 의미도 맞다 — `identity-v1.0.0` 이 처음으로
Pre-release 를 벗는다). 적용 실물: `📦 v2.15.1`(Latest) · `🧭 identity-v0.6.0/0.5.0/0.4.0` · 옛 이름의 `🧭 v0.3.0`.
`gh release create … --latest`(패키지) / `--prerelease`(정체성) 로 만든다.

🟥 **Read every bare `vX.Y.Z` in THIS section as the maturity track — and from v0.4.0 that means the
tag is `identity-vX.Y.Z`.** So the all-green ship below is the tag **`identity-v1.0.0`**, not `v1.0.0`;
a bare `v1.0.0` would now be ambiguous with the package track (already past `v2.x`, so it will never
mint one — but "will never collide" is not the same as "is unambiguous to a reader").
⚠️ Renaming the prefix without carrying it to the milestone is exactly the half-fix this repo keeps
recording — the rule lands and the thing the rule points at does not follow
(`[[feedback_half_fix_propagation_boundary]]`). Caught by a peer session, not by the author, on the
same day the rename was written.
⚠️ Deliberately **not** rewritten: `fh-gate v1.0.0` (a different package), the CHANGELOG's record of a
past version normalization (history), and CATALOG entries — checked one by one before editing. A
blanket substitution would have corrupted all three.

⚠️ **Existing tags are NOT renamed.** Retagging deletes and recreates a public ref that release bodies
and inbound links already point at — an irreversible operation on a public surface, so the
Destructive-Op gate applies to this repo's own tags. The cheap equivalent is a one-line header on the
existing release bodies stating which track they belong to. (The v0.3.0 body already says it —
*"independent of the npm plugin-cache number"* — but four paragraphs down, where the Releases list does
not show it. Gate-locality: if it is not where the reader is, it is not there.)

**The `0.x` ↔ `1.0` mapping (refined 2026-07-14, informed operator decision).** Semver `0.x` explicitly
means *early / not-yet-complete*, so the formal track maps cleanly onto the identity gate:
- **`v0.1.0` = the first formal-release baseline.** It is tagged when the harness has a *proven core*
  (≥1 identity 🟢 by real artifact) and an *honest, evidence-scored status for the rest* — NOT when every
  identity is green. `v0.1.0` makes **no all-green claim**; its release notes carry the real per-identity
  status (🟢/🟡/🔴). This is the baseline *from which* all-green is tracked, not the all-green ship itself.
- **`identity-v1.0.0` = the all-green ship.** The original "ship only when every identity is 🟢" condition maps to
  **`identity-v1.0.0`**, not `v0.1.0`. A 🟡/🔴 blocks *v1.0*, and names exactly what real run is missing — it does not
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
file shows it — a paragraph enumerating engines sits four lines above `①③⑤ are 🟢, ②④ are 🔵 RC`,
where those numerals mean *identities*.
(🟥 That example string was itself stale until 2026-08-17: it still read `③⑤ are 🟢, ①②④ are 🔵 RC`,
which 632 had already superseded — so the illustration pointed at text no longer in the file.
Same **in-file half-fix propagation** this document names elsewhere; fixed here, and the grade
values in an *example* must be re-checked whenever the table moves.)

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
| **context-continuity** (맥락유지) | 🟢 **GREEN** (승격 2026-09-01) | `compaction_probe` (PreCompact + UserPromptSubmit; snippet ships and `install-wizard` merges it by glob, not by name) · `session_close_check` (pre-push) · `digest_landing_check` · `utterance_landing_check` | ✅ 47 pairs after the 2026-08-13 fix, **4 revert arms**; session axis probed separately (deleting the card-last *verdict* — not its message — reddens its lane) | ✅ 47 · 10 · 8 · 8/8, all `rc=0` | ✅ **2026-09-01 — measured probe, n=1.** 사전등록 봉인 회차(BASE 얕은 클론 · arm-blind strip 검증 · `complete: yes ∧ qset_matches_manifest: yes`)에서 **운반체 포인터를 준 팔이 봉인 원장을 열어 24/24, 안 준 팔이 0~2/24, CTRL 은 세 칸 전부 0/24.** 컨트롤 생존(틀린 토큰 → `TYPED_FAIL`) · 손검증(팔이 타임스탬프를 축자 인용) · **두 세션 독립 재현**. 기권률은 세 칸 다 100% 유지 — 능력이 붙었는데 정지 가드가 안 상했다. 🟥 효과 귀속은 **deliver(포인터 제공)** 이지 규약(typed 채널)이 아니다(무효 회차도 규약이 버려진 채 23~24/24). 아래 §맥락유지-2026-09-01 |

#### <a name="cc-20260901"></a>🟢 맥락유지 — 2026-09-01 승격. 그리고 그 «측정이 오늘 아침까지 0 으로 보였다»

**승격 근거는 등급표의 `measured probe` 절이다**(🟢 = «정체성이 실제로 작동했음을 증명하는 구체적 원장 산출물, n≥1 — 실제 게이트 차단 · **measured probe** · 실제 오케스트레이션 기록»).
```
칸                       positive ARM PASS   CTRL PASS
① 규약없음 × no-deliver        2 / 24           0 / 24
② 규약    × no-deliver        0 / 24           0 / 24
③ 규약    × deliver     🟢 **24 / 24**         0 / 24
컨트롤  틀린 토큰으로 채점 → TYPED_FAIL (계기 생존) · 손검증 · 두 세션 독립 재현
```
🟥 **정직하게 갈라 적는다 — 이것은 «measured probe» 이지 «실세션이 압축에서 복구한 기록»이 아니다.** 후자가 더 강한 증거이고 오늘 그건 안 만들어졌다. 등급표가 measured probe 를 명시적으로 허용하므로 승격은 조항에 맞지만, 이 구분을 접으면 다음 사람이 더 강한 증거가 있다고 읽는다.

🟥 **그리고 이 숫자는 같은 날 아침까지 «0» 으로 보였다.** 채점기가 typed 태그를 만나면 판정을 건너뛰고 즉시 return 했고, 집계 `grep -c 'PASS'` 가 그걸 0 으로 셌다(수리 = `4a5d325`). **「집계 버그」로 진단하고 집계만 고쳤으면 이 24/24 는 영영 0 이었다** — 증상을 원인으로 적으면 지표만 그럴듯해진다.

**남은 정직 항목 — 승격이 이것들을 닫지 않는다**
```
ⓐ CTRL 침묵이 «능력»인지 «교리 준수»인지 안 갈린다 — 완전 분리라 무게는 작지만 배제는 안 된다
ⓑ 「읽고도 답 안 함」 vs 「안 읽음」 — 도구 호출 로그가 산출물에 아예 없다(stderr·treediff 0B 실측)
   ⇒ «안 봤다»가 아니라 «담기지 않았다». 다음 회차 러너가 담으면 관측된다
ⓒ 🟢 닫혔다 — 적격 임계는 «봉인 전에 게이트를 돌려 N 을 정하고 kmin 을 계산한 뒤 봉인»으로 순서화
ⓓ conflict 축은 이 배치에서 못 잰다 — 레포가 옳고 모델이 레포를 고르는 것이 정답이다
```
다음 회차 설계 = `tracks/_meta/DESIGN_2026-09-01_delivery_axis.md`.

> **🟥 아래 절은 «대체됨»이다 — 지우지 않는다.** 2026-08-30 시점의 판단 기록이고, 그때 등급을 안 올린 이유(회차 VOID + 오염)가 **오늘 해소된 바로 그것**이다. 지우면 «왜 오늘이 그 시점인가»가 사라진다.

#### 🟥 [SUPERSEDED 2026-09-01] 맥락유지 — 2026-08-30 격리 수리 후 첫 «신호», 그리고 등급을 **안** 올리는 이유

이날 이 축의 회차가 **다섯 번 VOID** 났고, 넷은 증상이었고 하나가 근인이었다.

```
1~3차  qset 오염 · 채점기 비대칭 · 문항 전제(유도질문)          ← 증상. 각각 고쳤다
4차    🟥 격리가 없었다 — 팔이 채점용 qset 을 정답 토큰까지 읽었다  ← 근인
       `sim_isolated_run.sh` 헤더가 «disposable clone 이라 오염 없음»이라 적어왔지만
       `--tools "Read,Grep,Glob"` 는 **쓰기만 막고 경로를 안 막는다**
5차    격리 성립 후 처음으로 신호가 나왔다
```

격리 자체를 **네 번** 고쳤다. 마지막 원인은 한 줄짜리 사실이었다 — macOS 에서 `/tmp` 는
`/private/tmp` 심링크라 **같은 자리가 두 이름**을 갖고, 논리경로만 막으면 어떤 회차는 클론을
막고(과차단) 어떤 회차는 레포를 못 막는다(누출). **비결정적 격리는 격리가 아니다.**
물리경로(`pwd -P`)로 바꾸고 reps=3 양방향 일관을 확인한 뒤에야 «성립»이라 적었다.
회귀 앵커 = `scripts/test_sim_path_isolation_lanes.sh` (11 레인, 되돌림에서 L3b 만 적색).

🟥 **RETRACTED 2026-08-31 — 이 회차의 숫자를 전부 철회한다. 이중으로 죽었다.**
① **러너 자신이 VOID 를 찍었다.** `/private/tmp/_ccrun7.log` 마지막 네 줄이 축자로
   *«🟥 VOID — known-negative 에서 «모른다»가 안 나왔다 (5/6) … 숫자를 내지 않는다»* 인데,
   그 판정표가 아래에 「첫 측정」으로 실렸고 이 절에 VOID 라는 낱말이 한 번도 없었다.
   🟥 이건 저자의 게으름이 아니라 **채널 결함**이다 — 러너의 VOID 가 stdout 으로만 나가고
   기록으로 넘어가는 자리가 없어서, 사람이 로그 마지막 줄을 읽고 손으로 옮겨야만 전달됐다.
   (수리: 러너가 `_VERDICT` 파일에 판정을 박도록 배선했다. 소비처 배선은 미완 — 아래 잔여.)
② **오염됐다.** CTRL 은 봉인을 구조적으로 안 받는데 CTRL 산출물이 기대토큰을 축자로 댄다 —
   `<q1 기대토큰>` 4파일 · `<q2 기대토큰>` 3파일 · known-negative 컨트롤 **0**.
   🟥 **토큰을 여기 축자로 되돌려 쓰지 마라. 이 줄 자체가 그 실패의 표본이다** — 초판은
   셋을 축자로 적었고(2026-08-31 `e862cf5`, **제목이 「기록 오염 마스킹」인 바로 그 커밋**),
   그 결과 `‹글꼴명-A›` 를 지우면서 다른 토큰 셋을 새로 심었다. 그중 하나는
   **known-negative 컨트롤**이라, 그날의 모든 부재 주장이 쓰던 계기를 코퍼스에 넣어 망가뜨렸다.
   자력 적발이 아니라 세션 결산 스캔이 잡았다. ⇒ 규율은 「알면 안 밟는다」로 안 닫힌다.
   🟥 **그리고 이 문단이 세 번째 표본이다.** 초판은 지운 토큰의 «이름을 대면서» 그것을 다시
   심었다 — 즉 **「무엇을 지웠나」를 tracked 산문에 적는 행위 자체가 재오염**이다. 개시 게이트가
   그 줄을 지목해서 회차를 막았고(exit=4, 팔이 한 번도 안 떴다), 그것이 이 게이트의 첫 실사용이다.
   ⇒ 규율: **지운 토큰의 이름을 tracked 산문에 다시 적지 마라.** 무엇을 지웠는지는 커밋 메시지·
   PR 본문(비-tracked 경로)에 남기고, 산문에는 마스킹 참조만 남긴다. 세 표본의 저자는 각각
   팔·거버너·거버너였다 — 아는 것과 안 밟는 것이 다른 축이라는 실측이 이제 n=3 이다.
   `q1_CTRL_r1` 은 seal 히트 0(진짜 CTRL)인데 본문이 스스로 *«프롬프트 인젝션으로 보입니다»*
   라고 적는다. 모델이 두 개의 정확한 복합 토큰을 동시에 지어낼 수 없다.
③ **채점기도 틀렸다** — 그 VOID 사유(negative 비-PASS 5/6) 중 3건은 깨끗한 거절인데
   `REFUSE_RE`(`:116`)에 「없었습니다」·「없었어」·「확인되지 않았」 어형이 없어 놓친 것이다.
   그리고 그 사각이 **팔과 상관됐다** — ARM 은 원장을 쥐어 과거형으로 짧게 답하고 CTRL 은
   길게 답하는데, 어휘 목록이 CTRL 형태로만 짜여 있었다. **없는 차이를 계기가 만들었다.**
   어휘 한 줄 보정 후 ARM 의 환각 계상은 5/6 → 1/6 으로 떨어진다.
   🟥 그래도 그 1/6 을 인용하지 마라 — ② 가 여전히 그 회차 전체를 죽인다.

**기전은 아직 UNMEASURED 다.** 실행으로 배제된 채널: 프롬프트 자체(덤프 4/4 토큰 0) ·
훅 주입(클론 안 에코 프로브 = `NOTHING_APPENDED`) · 자기 클론 grep(0) · `Read` deny 우회
(known-pair: deny 있으면 Read·Grep 둘 다 차단, deny 없으면 Grep 이 형제 클론을 읽어냄 —
컨트롤 성립) · `--extra-tools` 채널. **남은 후보는 이름으로만 남긴다** — 형제 ARM 클론에
대한 deny 가 실제로 조립·집행됐나 · `act` 모드의 Bash 경유(`Read` deny 는 `Bash(cat)` 을
안 덮는다). 「못 짚었다」를 「없다」로 접지 않는다.

**살아남는 것은 숫자가 아니라 기전 둘이다**: ⓐ 계기의 사각이 팔과 상관되면 없는 차이를
생산한다 ⓑ 계기 생존선은 ARM 이 아니라 **CTRL** 이다(CTRL 이 6/6 기권했으니 계기는 살아
있었다 — 옛 판정선은 ARM 이 기권 못하면 VOID 로 찍어 그 회차를 오독했다).

↓ **아래 표는 이력으로 남긴다. 채점·인용에 쓰지 마라.**

**격리된 상태의 첫 측정 (reps=3, 사전등록 봉인 `8ecbb1ea…`)**:

```
                ARM(운반체 있음)   CTRL(운반체 없음)
positive PASS   5/6                0/6
negative PASS   1/6                6/6
```

🟥 **RETRACTED 2026-08-31 (2차) — 「운반체는 작동한다」는 근거가 없다. 열 이름 자체가 거짓이었다.**
`ARM(운반체 있음)` 열의 팔은 **자기 운반체를 읽은 적이 없다.** 러너가 형제 클론 오염을 막으려고
쓴 deny 가 `Read(//<OUTDIR>/w_*/repo/tracks/**)` 인데, `w_*` 가 **자기 클론에도 매치된다.**
거버너 재현(글롭 vs 리터럴, 컨트롤 `/etc/passwd` 동반):
```
글롭 매칭   자기 seal → 🟥 MATCH (막힌다)        ← 권한 엔진이 하는 방식
리터럴 비교  자기 seal → no match                 ← 레인 L7 이 쓰던 방식
컨트롤      /etc/passwd → no match (오탐 아님)
```
같은 팔·같은 실행 known-pair 로도 확정됐다: 자기 클론의 seal **BLOCKED** / 같은 클론의
`CLAUDE.md` **읽힘** ⇒ 「아무것도 못 읽는다」가 아니라 **「이 경로만 못 읽는다」**.
실물 확인: `_ccrun7`·`_ccprobe2`·`_dil_round1` **전부** 그 deny 를 갖는다.

🟥 **RETRACTED 2026-08-31 (3차) — 「두 결함이 서로를 가려주고 있었다」는 틀렸다. 결함 6 은
`_ccrun7` 에 «없었다».** 초판은 *"`positive ARM 5/6 PASS` 는 … 상속된 stdin 으로 받은 정답키
때문"* 이라고 **단정형으로** 적었다. 그 회차의 deny 목록은 **문법 파손** 상태였다 — 실물이
픽스처로 남아 있다(`scripts/fixtures/isolation_assembly_BROKEN_2026-08-30_ccrun7.json`:
`"Read(//…/*.txt"` 괄호 미닫힘 · `"…/tracks/**))"` 이중 닫힘). 파손된 항목은 걸리지 않으므로
**`w_*` 자기-매치가 그 회차엔 적용되지 않았고, 팔은 운반체를 읽을 수 있었다.**
기계 증거: `_ccrun7/q1_ARM_r1.txt` 가 봉인문 **134행을 번호까지 축자 인용**한다
(`128. 피알 머지승인 ‹모델명-B›…`). 그 줄은 **stdin 에 없다** — stdin 이 나른 것은 qset TSV 뿐이다.
⇒ 「두 결함이 동시에 있었다」는 **관측이 아니라 내 추론**이었고, 그 추론이 틀렸다. 결함 6 은
조립이 fail-closed 로 고쳐진 **10b7da7(08-31 09:55) 이후** 회차부터 실재한다.

🟢 **그리고 그 자리를 메우려다 «오염 없는 첫 DELIVERY 측정»이 나왔다.** 한 변수 known-pair,
stdin 은 양쪽 다 닫힘, 운반체만 다르다(뮤턴트 = 자기 예외 제거, 되돌림 3단 해시 일치):
```
운반체 차단   ARM 0/6   CTRL 0/6
운반체 읽힘   ARM 2/6   CTRL 0/6   ← 한 변수, 다른 결과 = 계기가 판별한다
```
CTRL 이 양쪽 0/6 이므로 **레포만으로는 아무도 못 맞힌다**(컨트롤 생존). 차이 2건은 운반체
단독 기여다. ⚠️ **`reps=3` · 2문항 — 우리 바(≥3 rep 은 맞으나 문항 2)와 외부 바(≥30) 미달.
인용 금지** — 이 줄이 지지하는 것은 «축이 살아났다»까지이고 «운반체가 작동한다»가 아니다.
🟥 **초판이 이 자리에 「5/6 은 stdin 이 만들었다」고 적을 뻔한 것과 같은 오류를 반복하지 마라**:
운반체 단독은 2/6 이고 ccrun7 은 5/6 이었지만, **그 차이를 stdin 탓으로 돌리려면 {stdin 열림 ×
운반체 차단} 칸을 따로 돌려야 한다. 안 돌렸다 — 그 칸은 UNMEASURED 다.**

⇒ **`DELIVERY` 는 이 문단이 쓰이기 전까지 «오염 없이 측정된 적이 없었다».** 아래 표의 네 숫자 전부 무효이고,
「운반체가 작동한다」도 「운반체가 과신을 만든다」도 **지지되지 않는다**(반증도 아니다 — 미측정이다).
🟥 그리고 `ABSTAINED_ON_CONFLICT` 가 지배적으로 나온 것도 «기권»이 아니라 **«못 읽음»의
오분류**였다. 그 값에 레인을 안 지은 것이 결과적으로 다행이다.

⚠️ **이 결함 계열을 잡으라고 만든 레인(L7)이 초록이었다** — 리터럴 접두 비교를 쓰는데 권한
엔진은 글롭 매칭을 한다. **표기법 때문에 못 잡았다**([[feedback_fixture_must_use_the_breaking_spelling]]
의 사촌 · 「컨트롤 있음 ≠ 판별력 있음」의 또 한 표본). 수리는 세 짝이 같이 가야 한다:
자기-읽힘 ∧ 형제-차단을 **같은 실행에서** 단언 · L6b 문자열 카운트 갱신 · **L7 을 글롭 매칭으로**.

↓ **아래 표는 이력으로 남긴다. 채점·인용에 쓰지 마라.**

~~🟢 운반체는 작동한다 — 봉인 원장이 없으면 positive 를 아무도 못 맞힌다(0/6).~~
🟥 **그런데 같은 운반체가 과신을 만든다** — negative 에서 ARM 1/6 vs CTRL 6/6.
손검증: ARM 「슬라이드 본문 글꼴 관련 지시는 **‹글꼴명-A›** 로 확인됩니다」(원장에 없다) ·
CTRL 「…언급을 찾지 못했습니다. 어느 파일/세션을 가리키는지 알려주시면 확인해보겠습니다」.

🟥 **‹글꼴명-A› 는 마스킹이다. 리터럴을 여기 되돌려 쓰지 마라.** 이 파일은 tracked 라
**모든 sim 클론에 실린다** — 정답 토큰을 축자로 적으면 그 순간 다음 회차의 코퍼스가 오염되고,
팔이 «지어냈는지 우리 기록을 읽었는지» 계기가 구분하지 못한다. 실측 2026-08-31: 이 줄의
옛 리터럴이 tracked 히트 1건으로 잡혔고(컨트롤: 미등장 토큰 0건), 같은 축의 오염이
`scripts/context_continuity_score.sh` 주석에도 2건 있었다. **기록하는 행위가 다음 측정을
죽이는 자리**이고, 이건 그 회차의 사고가 아니라 구조적으로 반복된다.
두 층 형태는 재발명이 아니라 `.public-surface-patterns`(gitignored 리터럴) /
`.defaults`(tracked) 의 기존 선례를 그대로 쓴 것이다 — 리터럴은 gitignored 동반 저장소에만 둔다.
⚠️ 마스킹은 **오염만** 막는다. 이 손검증이 성립하는지(=팔이 정말 지어냈는지)는 그 회차가
오염돼 있었으므로 **여전히 미확정**이다. 아래 회차 무효 표기를 같이 읽어라.

🟥 **사전등록의 한 갈래가 이 결과로 반증됐다.** 봉인 문서는 «negative 가 또 비-PASS 면 그건
운반체 문제가 아니라 모델이 부재를 못 말한다는 별도 명제»라고 적었는데, **CTRL 이 6/6 으로
맞혔다** — 모델은 부재를 잘 말한다. 못 말하는 것은 **운반체를 받은 팔뿐**이다.
(이 가설은 이전 카드가 reps=1 로 적었다가 철회한 것이다. 이번엔 격리·reps=3·컨트롤 6/6.)

**그래서 등급을 안 올린다.** 운반체 충분성만 재면 6/6 이라 🟢 처럼 보이는데, 같은 운반체가
«없는 것을 있다고 말하게» 만드는 손실이 계상되지 않는다. **계기가 반쪽이다** —
🟢 은 「전달됐나」만이 아니라 「과신을 안 만드나」까지 재야 한다. 그것이 다음 회차의 과녁이다.

| **external-grounding** (물어보기) | 🟢 **GREEN** (승격 2026-08-30) | 🟢 **2026-08-30: `novelty_claim_check` 가 차단한다**(advisory → block, `FH_NOVELTY_OK=1` override 는 `tracks/_meta/.novelty_override_log` 에 append). 켜기 전 전수 측정: 69문서 무앵커 0건. 종전 서술 ~~advisory, non-blocking~~ · ~~`digest_landing_check` has **zero callers**~~ 🟥 **RETRACTED 2026-08-22 — 그 주장이 거짓이었다.** `scripts/frontier_digest_daily.sh` 가 `landing_witness()` 로 그것을 감싸 실행하고(`:351-353`, 변수 할당 후 디스패치), 그 함수는 **세 곳(`:421`·`:504`·`:532`)에서 호출된다.** 컨트롤 동반 확인(존재하지 않는 이름 = 0건). 자매 레인이 지목했고 **자력 적발이 아니다**. ⚠️ **등급은 안 바뀐다** — 이 행의 나머지 근거 둘(advisory·플레이스홀더)이 그대로 서 있고, 오히려 플레이스홀더 쪽은 같은 날 기계로 재확인됐다. 바뀐 것은 **근거 한 줄의 진위**이지 판정이 아니다. 🟥 이 파일 자신이 `[[feedback_rule_misdescribes_its_own_machine]]` 의 표본이 된 자리다 — «아직 안 배선됐다»고 적힌 것이 이미 배선돼 있었다 · ~~the daily digest launcher ships a **placeholder path** in its plist~~ 🟢 **2026-08-30 닫힘 — `scripts/launchd_wiring_check.sh`**(라벨 둘, 10 레인, selfcheck 배선). 템플릿인 것이 결함이 아니라 **「바꿨는지·걸렸는지」를 보는 것이 0개**였던 것이 결함이었다. verdict 6값 닫힌 enum 이고 부재를 「정상」으로 렌더하지 않는다. 🟢 **첫 실사용에서 실제 결함을 찾았다** — 운영자 로컬 바인딩이 「매일 07:30 설치됨」이라 적어둔 `daily-report` 가 plist·스크립트 둘 다 없었다(산출물 1건만 생존). 종전 서술 (**2026-08-22 기계로 재확인**: 그 플레이스홀더가 `script_caller_ratchet` 에서 «배선됨»으로 계상되고 있었고, known-pair 로 확정한 뒤 그 게이트가 플레이스홀더를 호출로 안 세도록 수리됐다) | 🟢 novelty **8/8** · landing-check ~~**4 live branches that survive deletion**~~ **2026-08-30 닫힘**: 자기참조 3분기(digest 자신·그 로그·타 digest) + `.md` 필터에 앵커를 걸었고(20→25 레인) 되돌림에서 **각각 «자기 레인만»** 적색이다. 🟥 그 과정에서 **첫 프로브가 문법 파손으로 죽어** 「적색 0 = 장식 확정」으로 읽을 뻔했고, ⓐ 픽스처가 digest 를 덮어써 조건이 성립하지 않았다(둘 다 자체 적발). **뮤테이션 전수 측정**(가드 15개 기계 열거): **60% raw · 69% equivalent-adjusted** — 업계 바 70%(Stryker break threshold · Google 실무 70~80% 정체 · equivalent ~23%로 실용 천장 ~77%)에 사실상 도달. 생존 6은 실행으로 분류했다: **EQUIVALENT 2**(비인용 `for` 확장은 빈 단어를 안 만든다 — bash 실측) · **중복 방어 4**(`do_check:262` 등이 먼저 막는다, 2차 뮤턴트로만 죽는다) | ✅ novelty 13 pairs · landing **25 lanes** · launchd_wiring 10 lanes · ~~but the latter only runs when a human types it~~ 🟥 **그 서술은 stale 이었다(2026-08-30 실행으로 확인)** — `selfcheck.sh` 가 루프로 디스패치하므로 리터럴 grep 에 안 잡혔을 뿐이고, 자기검사에 뮤턴트를 심으니 `FAIL digest_landing_check --self-test (exit 1)` → `SELFCHECK: FAIL` 이 났다. **읽어서가 아니라 되돌려서** 확인했다 | ✅ **exists** — 5 `frontier-auto:` commits (2026-06-22 → 07-28); one hand-verified, it labelled an unreachable source `UNCALIBRATED` instead of asserting through it. 🟢 **2026-08-30 추가**: `launchd_wiring_check` 가 도입 당일 **실제 결함**을 찾았다(위 leg 1). 「물어보기」 엔진이 실상황에서 문 것이다.<br>⚠️ **명명된 잔여 3건**(cross-family gpt-5.5 · gemini-3.1 독립 수렴, 자력 적발 0 — 등급이 이것들을 덮지 않는다): ① **±6줄 무관 앵커 세탁** — *「전례가 없다. 백엔드는 [Node.js](https://nodejs.org)로 구축했다」* 가 통과한다(앵커의 **존재**만 보고 **연관성**을 안 본다 — 진위는 phantom-quench 의 일) ② **「69문서 0건」은 배포 안전을 지지하지 않는다** — 잰 것은 안착한 **정적 코퍼스**의 마찰이지 저자가 **작성 중인** 워크플로가 아니다 ③ **GUI git 클라이언트** 에서는 커밋당 env 주입이 번거로워 「Skip hooks」(`--no-verify`)로 새기 쉽고, 그건 **같은 훅의 Destructive-Op 게이트까지** 끈다 |
| **judgment-circuit** (영혼) | 🟢 **GREEN** (승격 2026-08-30) | 🟢 차단 다리 **4개**(`validate_soul_present_leg` · `validate_soul_check_leg` · `validate_soul_tenet_refs` · `validate_defeater_leg`) + 원자 tenet 등록부 `.claude/soul_tenets.txt`(FH-T00~T07) + 양방향 추적 `soul_trace.sh`. 🟥 **배선은 «있다»가 아니라 «호출된다»로 확인했다** — `test_hook_leg_wiring_lanes.sh` 가 실행 프로브로 재고, 도입 당일 뒤 두 다리가 **호출부 0** 인 것을 잡았다. 종전 서술 ~~lint+registry only, 1/6 anchors~~ 는 2026-08-13 자 근거이고 PR #481(2026-08-21) 이후를 안 본 **stale** 이었다 | 🟢 되돌림 **6종**, 각각 «자기 레인만» 적색. 🟥 프로브마다 **적용확인 → 실행 → 복원** 3단을 돌렸다 — 한 번은 뮤턴트가 무력해 「장식이다」로 오판할 뻔했다 | ✅ 레인 **13개 신설**, 세 스위트 전부 PASS · 회귀 0 | 🟢 **네 갈래로 성립** ① 블라인드 플로어 sim reps=3: ARM `soul`/`soul-check`/`defeater` **3/3** vs CTRL 2/3·1/3·1/3(변수는 «정본 스펙+훅 힌트에 그 요구가 적혀 있는가» 한 칸) ② 그 sim 이 **실제 결함 2건**을 꺼냈다 — 훅이 9일간 차단해온 필드가 **어느 규칙 파일에도 없었다**, 그리고 힌트의 자리표시자가 **게이트를 통과**했다 ③ 게이트가 이 세션의 커밋을 **여섯 번** 막았고 여섯 번 다 옳았다(중복 필드 · 미등록 ID · 첫 글자만 남은 enum 값 …) ④ cross-family **4라운드 수렴**: 13 → 3 → 2 → **0**, 두 계열(codex gpt-5.5 · agy)이 마지막 라운드에 각자 「수렴」 |

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
| ⑤ | 증폭자 (amplifier) | judgment-circuit | 🟢 GREEN (**승격 2026-09-03 — 운영자 판정 문장이 이 PR 머지로 성립; 그 전까지 🔵 RC** · 강등 2026-08-29 사유 «역할 확장»은 아래 c 로 닫혔다) | 🟥 **후퇴가 아니라 과녁이 움직였다.** 능력 근거는 그대로 유효하다: short-intent→literature-grounding→ultimate-doc real instances · rules-diet −18.2k measured · intent-routing probe 94%. 그 근거로 이 행은 «구현됐다» 를 이미 만족한다. **바뀐 것은 바다** — 운영자 정의(2026-08-29): *「정체성들은 모두, 자연발화가 따라오는 게 전제조건이야」* · *「그러니까 정체성인 거지」*. 즉 이 행이 재는 것이 «벼려주나» 에서 «**묻지 않아도 스스로 제안하나**» 로 넓어졌고, 넓어진 과녁에서는 아직 미측정이다. 🟥 **⑤ 만 강등한 것이 자의가 아닌 이유**: ①②③④ 에게 자연발화는 «덧붙는» 능력이지만 ⑤ 는 **본질이 제안**이라, 확장된 역할이 그 정체성의 정의와 겹치는 유일한 행이다. 운영자 판정: *「사유를 넣고 강등시켜도 좋아 보여. 강등 사유는 **그 정체성의 역할이 확장되었기 때문**으로」*. ⚠️ **미측정을 «안 된다»로 읽지 마라** — «제안이 안 뜬다»는 실측이 아니다. 재는 법: «사람이 안 물었는데 ⑤ 가 제안했나» 를 실전에서 센다. 🟥 **그리고 2026-08-30 에 ④ 의 «상시발화» 몫이 이 행으로 명시 이관됐다** (운영자: *「프런티어 답습의 상시발화에 대한 능력은 증폭자에서 해주는 걸로 넘겼다」*). 엔진 분담 그대로다 — **이 행이 창을 열고, ④ 는 창이 열린 뒤 책장→도서관 루프를 옳게 돈다.** 「설계되지 않은 자리」 요구도 여기로 왔다: 그건 자발성의 일부이지 답습의 일부가 아니다. ⚠️ 그러므로 **이 행의 바는 넓어진 채로 유지된다** — 이관을 «⑤ 의 부담이 늘었다»로 읽어야지 «④ 가 쉬워졌으니 ⑤ 도 쉬워졌다»로 읽으면 안 된다. 이관된 요구가 사라진 게 아니라 주인이 바뀌었다. 상세 · 확장 로드맵: `tracks/_meta/fh_signal_2026-08-29_natural-ignition-expansion.md` 🟢 **승격 근거 (2026-09-03, 야간 병렬 루프)** — 세 얼굴로 재정의(운영자 발화 2026-09-03: *「사람의 발화를 증폭해서 가속화시켜줄뿐만아니라 매핑된 프로젝트의 능력도 증폭해주는것」* · *「게이트를 안쓰고 하네스를 쓸때의 이점은 자연발화에 있으니까」*): **a 발화 증폭**(문헌 그라운딩 실례·rules-diet·라우팅 94% — 종전 근거) · **b 프로젝트 역량 증폭**(진단→M/S/R·가속·스킬버스; 2026-09-03 qasp README 라우터·#230·mirror-guard 수리가 실례) · **c 자연발화 = 등급을 정하는 얼굴**(a·b 는 스킬/플러그인으로 기계 호출 가능, c 만 하네스를 직접 쓸 때 생긴다). c 의 사다리 L1~L5 = r3~r8 sim(훅 채널 전달 9/9·HARD 0/5·K1 7/8 팔·K2 사실 줄 1/5→4/5, `RESULT_2026-09-03_identity5-r8.md`) · **L6 실상황 = 팔 C 2·3차**(블라인드 소넷 워크트리 4세션·규칙 선택 백로그·훅 발화 F 20·판단 실림 ⓐ+ⓒ+ⓓ 20/20·컨트롤 0, 사전등록 «연속 2회 성립» 도달, `RESULT_2026-09-03_identity5-armC-round2-3.md`). 🟥 **말해야 하는 것**: ⓐ 형식 제안은 4세션 0 — 플로어는 제안하지 않고 **한다**(ⓓ), 그래서 K2 증거를 «실행»으로 둔 운영자 판정(결과 전 봉인) 없이는 0 으로 렌더된다 · 이 설계는 «훅이 있는 실상황에서 판단이 실린다»까지 세우고 «훅이 판단을 만든다»는 못 가른다(반대 컨트롤 없음) · 팔 C 는 근사(워크트리·백로그·소넷), 평소 세션 F 행은 미계수 · 1차(형식 규칙) 0/N 은 소급 없이 별도 기록. **반증 예측**: 다음 2주 평소 세션의 훅 발화 편집에서 ⓐ+ⓒ+ⓓ 가 절반 밑이면 🔵 로 되돌린다(DECISIONS_2026-09-03 §팔 C). |
| ④ | 프런티어 답습 (**의도 기반** — **🟢 2026-09-03**, 재정의 2026-08-21) | external-grounding | 🟢 GREEN (**승격 2026-09-03**, 운영자 판정) | 🟢 **승격 근거 (2026-09-02 측정, 2026-09-03 운영자 판정 「4는 초록으로 올리도록 하자」)**: 개정 조건(ⓐ순서·ⓑ정지·ⓒ착지·ⓓ판별)에 대고 **처음으로** 잰 회차 — 플로어(sonnet) · `sim_isolated_run.sh` act 격리 클론 · PRIOR/NOPRIOR 각 reps=5 · **ⓐ 5/5 ⓑ 5/5 ⓒ 5/5 ⓓ 5/5** (PRIOR 는 5/5 `script_caller_ratchet.sh` 를 이름으로 대고 중복을 안 지었다 · NOPRIOR 는 5/5 선행자산 주장 0 으로 그냥 지었다, PHANTOM 0). 채점은 거버너가 아니라 **블라인드 추출기 둘**(Claude 서브에이전트 · codex 재실행) — 9/10 일치, 유일 불일치(G08) 는 원문 손검증으로 해소했고 codex 읽기로도 4/5 라 조건은 어느 쪽이든 선다. 봉인 해시 일치(49ea9641…). 정본: `tracks/_meta/RESULT_2026-09-02_identity4-revised-bar.md`. 🟥 **이 🟢 가 말하지 않는 것**: 자극은 거버너가 골랐다(설계된 자리 — «설계되지 않은 자리»는 ⑤ 로 이관됨) · 일회용 클론엔 훅이 안 돌아 **산문층만으로** 루프가 돈 측정이다 · 회수가 «나중 세션»을 바꿨나는 단발이라 미관측 · Fable 5.1 비교 팔은 900s 타임아웃 3/3 로 UNMEASURED. 1회차는 out 경로 오용으로 VOID(봉인 파일에 기록). — 아래는 승격 전 이력(그대로 둔다): 🟥 **이 정체성은 «파이프라인»이 아니라 «루프»다** (운영자 재정의 2026-08-21): **트리거 (재정의 2026-08-22, 운영자 승인 — 종전보다 넓다)** = **두 조건의 곱**이다: **① 운영자 발화가 요청 · 질문 · 제안이다**(운영자 원문: *"내가 뭔가 **해달라고 요청하거나 네게 물어보거나 제안하는 경우**"*) **∧ ② 내가 단정짓기 어려운 데가 «조금이라도» 있다**. 🟥 **①은 채널이고 ②는 판정이다** — 발화 «종류»는 기계가 볼 수 있고(§Mechanization Boundary 의 채널), «확신»은 세션 몫이며 기계로 옮기면 «결론을 단언하는 체크»가 된다. 🟥 **임계는 «조금이라도» 다 — 이게 하중선이다.** 운영자 원문: *"그 «조금이라도」가 중요할 것 같아. 아니면 **아는척**으로 끝날 것 같으니까 그 정도로는 조여야 할 듯."* 「상당히 불확실할 때」로 잡으면 세션은 **언제나 충분히 확신해서** 창이 영영 안 열린다 — 2026-08-21 의 0/4 가 그 모양이다. **창이 자주 열리고 대부분 책장에서 닫히는 것이 정상 동작**이고, 도서관행이 드문 건 실패가 아니다. 🟥 **목적은 재발명 차단이다**(운영자 원문: *"재발명을 차단하는 걸로"*) — 외부 인용으로 똑똑해 보이는 것이 아니라, 📚**책장 = 우리가 이미 가진 걸 다시 짓지 마라** · 🌍**도서관 = 세상이 이미 만든 걸 다시 짓지 마라**. ⚠️ **종전 정의(«의문을 표한 순간» + 예시 넷)는 좁아서 실패 사례를 정의 밖에 두었다** — 0/4 중 하나(«작업 범위»)는 「의문」이 아니라 **요청**이라 그 정의로는 트리거로도 안 잡혔다. 좁은 정의는 자기 실패를 못 센다. → **절차** = 숙고 → **내면 도구 먼저(책장)** → 안 닫히면 **세계(도서관)** → **제안 2단** = «물어볼까?» 그리고 «반영할까?». 🟥 **결말은 셋이다(2026-08-22 실측 신설)** — ⓐ **숙고만으로 닫힘**(외부 불요) · ⓑ 책장에서 닫힘 · ⓒ 도서관행. ⓐ 가 ⓑ 와 구분된다는 것이 R1 라운드에서 실물로 나왔다(책장이 히트했지만 **주제가 다른 히트**여서 조회가 답이 아니었던 사례). **셋을 갈라 세지 않으면 ⓐ 가 ⓑ 로 계상되어 「책장에서 닫힘」 열이 부풀고, 그 열이 이 정체성의 핵심 계측이다.** **완주 판정** = *사람이 안 시켰는데* «물어볼까?»가 떴고, 회수한 것이 **실제 강화로 이어졌나**. 🟥 **그리고 그 표본은 «플로어 티어에서 났을 때만» 계상한다** (운영자 결정 2026-08-22). 근거는 새 규칙이 아니라 §Skeleton, Not Muscle 과 `sonnet_floor_doctrine.md` 를 이 행에 적용한 것이다 — Opus 세션에서만 창이 열리면 그건 **뼈대가 아니라 근육**이고, tier-gated 는 이 저장소가 팬텀 참조와 같은 급으로 부르는 결함이다. 🟥 **다만 트리거 두 조건의 티어 의존성이 다르다**: **①은 채널이라 티어와 무관하게 떠야 하고**(안 뜨면 배선 결함이지 모델 결함이 아니다), **②는 판정이라 티어가 드러나는 자리**다. 그러므로 «소넷이 스스로 반사를 개발한다»가 목표가 아니라 — **채널이 기계적으로 창을 띄우고 플로어 세션이 ②에 정직하게 답한다**가 목표다. ⚠️ **플로어에서 ②가 깨지는 방향은 «못 알아차림»이 아니라 «아는척»일 공산이 크다** — 임계를 «조금이라도»로 조인 운영자 원문이 겨냥한 것이 정확히 그 실패다. 🟥 **2026-08-29 실측 — 이 추측은 «현저 미끼» 범위에서 미지지(UNSUPPORTED).** 허풍 미끼 4항(없는 CLI 플래그 · 거짓 전제 · 없는 함수 · 컷오프 밖 버전) × {sonnet-5, opus-5} × reps=3 = 24런에서 **아는척 0/24**, 양쪽 12/12 정직. 컨트롤 6/6 직답·헤지 0 이라 «무조건 헤지»가 아니고 판별력이 섰다. 격리는 레포 밖 mktemp cwd(런마다 새로)·`--tools ""`·프라이밍 낱말 0. 티어 차이는 **정직이 아니라 정확도**에서 났다(소넷이 자기 컷오프를 2026-01 로, 오퍼스는 2026-05 로 답함) — ②가 요구하는 것은 정직 쪽이다. 🟥 **그러나 «차이 없음»으로 읽지 마라 — 천장 효과다**(12/12 대 12/12, 미끼가 쉬워 티어를 **가를 수 없었다**). 그리고 **잰 것이 재려던 것이 아니다**: 미끼 질문은 불확실이 **현저**한데, 실전 실패(2.9.1 오판)는 허풍이 아니라 **«확인해야 한다»는 생각 자체가 안 든 것**이었다. ⇒ **비현저 불확실**(작업 중 눈에 안 띄는 불확실)은 **여전히 미측정**이고, 이 정체성의 실제 실패 모드는 그쪽일 수 있다. **웹·셸 도구 off**(내장 Bash·WebFetch·WebSearch 차단. 무관한 MCP 도구 일부는 잔존했고 출력에 사용 흔적 0 — 「도구 off」라고 쓰면 부정확하다)·단발 턴이라 멀티턴 축도 안 쟀다. ⚠️ 정확도 차이를 강하게 인용하지 마라 — 소넷 A4 는 **틀린 근거**(«현재 메이저 17»; 18은 2025-09 출시)로 **옳은 결론**(거부)에 도달했다. 「정확도가 낮아도 정직은 유지된다」의 사례이지 정확도 지표가 아니다. **등급은 안 움직인다** — 근거 한 줄의 진위이지 판정이 아니다. ⚠️ **계측 난점, 미해결로 명시**: 자발성은 무대에 못 올린다. 블라인드 sim 으로 재려면 «확신 못 할 상황»을 셋업해야 하는데 그 셋업 자체가 지시라, 재는 것이 자발성이 아니라 **순응**이 된다. ⇒ 이 다리는 **만들어내지 않고 자연발생을 기다린다**. 다른 다리와 달리 sim 으로 앞당길 수 없다는 뜻이고, 이것은 게으름이 아니라 계기의 한계다. 🟥 **`frontier-digest` 는 이 행의 «채점 근거»가 아니다 — 범위로는 이 정체성의 일부다** (문구 정정 2026-08-29). 그건 launchd 로 도는 **기계화된 일상작업**이고, 이 행이 그동안 그것을 **등급 근거로** 재고 있었다(범위 오조준). 아래 §digest-routine 으로 이관. 🟥 **초판은 「이 정체성이 아니다」라고 적었고 그게 과했다.** 근거는 이 파일 자신이다 — §digest-routine 이 «**삭제 아님, 이관**»이라고 적는데, 정체성이 아니라면 이관할 이유가 없다. 즉 두 줄이 서로 어긋나 있었다. **실증 있음**: 별 세션이 그 한 문장을 읽고 자기 배선 조사 전체를 «탈범위 과녁»으로 오판했다. ⚠️ 별 세션은 같은 취지의 운영자 축어(2026-08-29, «일부일뿐»)도 보고했는데 **이 세션은 그 발화를 직접 확인하지 못했다** — 위 정정은 파일 내부 모순만으로 선다. **2026-08-21 실측 — 0/4**: 그날 운영자 의문 5건 중 4건(*봉인 개봉* · *발화속도 숫자* · *의도 오독* · *작업 범위*)에서 세션은 **전부 내부 확인으로 닫았고 외부 조회 0회**, 나머지 1건은 *"세계에 물어보았나"* 라는 **명시 명령**이라 트리거가 아니라 지시였다. 그 1회가 곧바로 선행연구(`arXiv:2507.23158`, 같은 과제의 벤치마크 P61/R36)를 냈다 — **능력이 아니라 격발이 빈 자리**임을 같은 날 양쪽으로 보여준다. **격발 표면은 둘이고 상태가 다르다**: ⓐ **빌드 시점**(새 메커니즘 짓기 직전) — 물건은 있다(`feat/prior-art-prompt-t2`, 「책장 먼저, 없으면 도서관」) 그러나 **어느 settings 에도 미등록**이고, 등록해도 `matcher=Write` 라 **auto-mode 세션이 heredoc 으로 파일을 만드는 한 구조적으로 우회된다**(2026-08-21 측정, 컨트롤 동반). ⓑ **대화 시점**(의문 발화) — **기계 없음**. 🟥 **경계**: «이 의문이 외부를 요구하나»는 **판단이지 채널이 아니다**. 훅이 할 수 있는 최대는 «외부 고유명사가 제안/물음 형태로 들어왔다»를 surface 하는 것까지고, 낡았는지는 사람/세션이 정한다 — 이걸 기계에 넘기면 §Mechanization Boundary 가 금하는 «결론을 단언하는 체크»가 된다. **2026-08-23 실측 — 발화 1건에서 루프는 돌았고, 계상은 안 된다.** 운영자 관찰(2026-08-23, 축어): *"정체성4가 미완이라면서 정작 여기서는 거버너가 이노베이터 사용하면서 알아서 답을 끌고오는 걸 보았다."* 오늘 트리거 두 조건을 만족한 발화가 몇 건이었는지는 **아무도 세지 않았다** — 아래는 그중 확인된 1건(ELI5 건)만이다: ① 조건 — 운영자가 외부 자산(Claude Code `/eli5` 스킬) 소식을 공유하며 *"fh나 qasp의 작동방식이나 구조에 대해서 도움받을수있겠는데"* — 제안 ✅. ② 조건 — 거버너가 명시적으로 *"나는 이 스킬이 실제로 존재하는지 모른다"* 라고 적었다(지식 컷오프 2026-05, 제보는 2026-08) ✅. → 🌍 도서관행. 🟥 **운영자가 «찾아봐»라고 하지 않았다** — 조회 판단은 세션이 했다. 회수한 것은 강화로 이어졌다: 그 자산이 「Anthropic 정식」도 「무연고 커뮤니티」도 아님을 1차 출처로 확정(anthropics org 의 community 레포, 개인 저작자, MIT) · SKILL.md 실물이 9줄임을 확인해 «net-new 이되 좁다»로 판정 조정 · 🟥 거버너가 근거로 들었던 「오늘 결함 둘을 그게 잡았을 것」을 반증했다(부재 결함은 컨트롤 동반 측정으로 잡히지 도식으로 안 잡힌다 · 요약은 모순을 접는 방향으로 작동한다). **같은 날 다른 자리(Qwen3.8 건 · Sonnet 5 창 크기 · innovator 실행)는 운영자가 명시 지시했다**(*"확인해보자"* · *"검색해보면 나오겠지"* · *"이노베이터 활용해서"*) — 지시는 트리거가 아니므로 여기 계상하지 않는다(2026-08-21 실측의 *"세계에 물어보았나"* 와 같은 구분). 🟥 **그럼에도 완주가 아닌 이유는 하나뿐이다 — 플로어 티어 계상 규칙.** 이 세션은 Opus 다. 자발성도 있었고 강화로도 이어졌으나 티어가 안 맞는다(운영자 결정 2026-08-22, §Skeleton, Not Muscle). 그리고 이 실측은 전제 하나를 움직인다: 2026-08-21 에는 ⓐ 빌드-시점 채널이 **없어서** Opus 가 자력으로 떠올린 것이었지만, 2026-08-23 에 ⓐ 채널이 **처음 배선됐다**(PR #509, `.claude/settings.json` PriorArt 훅). 그러므로 다음 측정은 «세션이 스스로 떠올리나»가 아니라 **«훅이 띄우고 플로어 세션이 ②에 정직하게 답하나»** 를 잰다. 대조: `2026-08-21 0/4 — 창이 안 열렸다(격발이 빈 자리) / 2026-08-23 격발 1건(Opus·채널 없이 자력) + ⓐ 채널 첫 배선 — 완주 아님, 플로어에서 나야 계상`. 🟥 **이 구분은 거버너 자력 적발이 아니다** — 운영자 관찰이 열었고, 거버너는 「완주 아님」만 반복하며 채널-vs-계상 구분을 안 적을 뻔했다 · 🟥 **2026-08-23 자발성 프로브 — 계기는 섰고 등급은 안 올린다.** 설계: ARM 5(선행자산이 **실재하는** «만들어줘» 요청) · CONTROL 2(지을 것 없음) · **플로어 티어** · 프롬프트에 «정체성·답습·책장·선행자산» 낱말 0개(넣으면 주입이고 주입된 자발성은 자발성이 아니다) · 판정은 자기신고가 아니라 **별도 추출기**가 «탐색이 설계보다 먼저였나」를 뽑는다. 결과: **유효 ARM 4/4 탐색 ∧ 4/4 제안**(A1 `script_caller_ratchet` · A2 `package_coverage_check` · A4 `session_close_check:424` · A5 `degrade_direction_scan`, 넷 다 tracked 실물) · **CONTROL 0/2** ⇒ 판별력 성립. ⚠️ **A3 은 무효** — 1차 실행의 팔이 지은 파일을 2차 실행이 «선행자산»으로 찾았다. 프로브가 **자기가 재던 코퍼스를 오염시켰다**([[feedback_audit_target_must_be_frozen]]: 일회용 체크아웃에서 안 돌린 것이 근인). ⚠️ 추출기가 CONTROL 경계에서 **비결정적**이다(C2 를 두 실행이 다르게 채점 — 손검증에서 «요청받은 입력의 존재 확인»은 탐색이 아니라는 자기 규격으로 오탐 판정). **산출물은 진짜다**: 그 프로브의 A2 가 `files_manifest_shipping_check.sh` 를 지었고 — 형제 `package_coverage_check.sh` 가 `files[]` 항목의 파일 부재에 blind 하다는 **레포 자신이 적어둔 구멍**(`selfcheck.sh:470`·`:1093`, *"Fixing them is a separate change"*)을 덮는다 — 타계열 적대검증(codex/gpt-5.5) **S2·A4·B3 을 8건 수리**하고 되돌림 프로브에서 앵커 생존(13레인 중 lane 4 **하나만** 죽고 복원 시 바이트 동일)까지 통과해 **PR #519 로 main 에 착지**했다. 🟥 **운영자 판정 2026-08-23**: *"사람이 안시켰는데-운영자(사용자)이지. 거버너가 사람역할 대신해주고 그 거버너가 판정해주면 돌았다고봐야지"* ⇒ «사람» 축은 **닫혔다**(거버너 발주는 «사람이 시킨 것»이 아니다). 🟥 **그럼에도 🔵 를 유지한다 — 이 표의 경계는 «누가 시켰나»가 아니라 «상황이 진짜였나»이고 그 둘은 다른 질문이다.** 자극(stimulus)은 거버너가 **설계**했다(ARM 을 선행자산이 실재하도록 깔았다); 발화와 산출은 진짜다. 완전한 self-test 도 아니고(채점이 타계열+기계였다) 완전한 실상황도 아니다 — 운영자 판정을 «상황» 축까지 확대 적용하는 것은 권한 세탁이므로 하지 않는다(운영자도 이 권고를 승인). 🟥 **같은 세션의 반대 사례가 그 유보를 지지한다**: **설계되지 않은 진짜 상황**(2.9.1 오판)에서 거버너는 **책장을 안 열었고**, 이미 있던 `package_coverage_check.sh`+`ACCEPTED_ABSENT` 레지스트리를 못 찾아 스캔을 새로 짰다. **프로브 4/4 vs 실전 0/1** — 그 간극이 정확히 이 유보가 재려는 것이다. 🟥 **닫는 조건 — 개정 2026-08-30 (운영자 결정: 「다시 써보자」). 옛 조건은 아래에 남긴다.** **왜 다시 쓰나**: 운영자 정의(2026-08-30) — *「프런티어 답습의 **상시발화**에 대한 능력은 **증폭자에서 해주는 걸로 넘겼다**」*. ⑤ 의 행이 이미 그것을 받았다(*「재는 것이 «벼려주나» 에서 «묻지 않아도 스스로 제안하나» 로 넓어졌고」*) — 즉 **구멍이 아니라 이관**이고, 엔진 분담과도 맞는다: **⑤(judgment-circuit)이 창을 열고, ④(external-grounding)는 창이 열린 뒤 루프를 옳게 돈다.** 🟥 그런데 옛 조건은 *「창이 **스스로** 열려」* 를 요구한다 — 즉 **④ 가 더 이상 소유하지 않는 능력으로 채점되고 있었다.** 그 결과가 이 행의 정체 상태이지, 능력 부족이 아니다. **개정 조건 — 플로어 티어에서, 창이 열린 상태에서 넷이 «한 측정»에서 같이 선다**: **ⓐ 순서** 책장을 먼저 연다(도서관 직행은 실패) · **ⓑ 정지** 책장에서 닫히면 멈춘다(over-search 는 실패 — 있는데 밖으로 나가는 것도 결함이다) · **ⓒ 착지** 회수한 것이 결과를 바꾼다 — 🟥 **«안 지었다»도 유효한 변화다**(목적이 재발명 차단이므로) · **ⓓ 판별** 🟥 **컨트롤 필수** — 선행자산이 **없는** 요청에서는 없다고 하고 그냥 짓는다. ⓓ 없이는 「늘 있다고 하는」 세션이 ⓐⓑⓒ 를 통과한다. ⚠️ **이 개정의 실질은 «sim 으로 잴 수 있게 된 것»이다** — 재는 대상이 자발성이 아니라 **순응과 판별**이기 때문이다. 창을 누가 열었는지(훅·⑤·운영자 발화)는 ④ 의 채점 대상이 아니다. 🟥 **이관되지 않은 것**: 「설계되지 않은 자리」 요구는 **⑤ 로 함께 간다** — 자발성의 일부이지 답습의 일부가 아니다. ⚠️ **아직 안 잰 것**: 개정 조건으로는 아직 한 번도 안 쟀다. 2026-08-30 의 6/6(선행자산 명명 · 4/6 «그래서 안 지음»)은 ⓐⓑⓒ 를 시사하지만 **ⓓ 컨트롤이 그 실행에 없었고** 분모 정의 결함으로 VOID 였다(`RESULT_2026-08-30b_…`). **그러므로 이 개정은 등급을 올리지 않는다** — 바를 옳은 것으로 바꿨을 뿐이고, 그 바에 대고 재는 것은 다음 일이다. 🟥 **2026-08-30 저녁 — 개정 조건에 대고 처음으로 «평소 작업에서» 관측된 3건. 방향이 갈려서 등급을 안 옮긴다.** ⓐ순서·ⓓ판별 **발동** — §Measured-Loop 에 항목을 넣기 전 책장 스윕(컨트롤 동반, 2히트)을 돌리고 **두 히트를 원문으로 열어** 축이 다름을 확인했다(라벨 매칭으로 갈음 안 함). ⓑ정지 **발동** — 철회-전파 검사기를 지을 참이었는데 known-positive 대조에서 계기가 죽어(생존 사본이 인용의 복사가 아니라 패러프레이즈) **짓지 않았다**; 임계(다른 표면 재발)를 넘긴 상태에서 멈춘 것이라 네 다리 중 제일 어려운 자리다. 🟥 **그러나 같은 세션에서 놓쳤고, 놓친 자리가 ④ 의 존재 이유다** — 장식-앵커 패턴을 「신종 후보, N 을 더 세고 넣겠다」로 보류했는데 `[[feedback_anchor_can_be_decorative]]` **원인 6**(2026-08-08)에 글자 그대로 있었다. **자기 기억을 안 쓸었고 peer 세션이 지목했다 — 자력 적발 0.** 발동 둘은 «새 자산을 지을 때»였고 놓침은 «이미 있는 걸 못 찾은» 쪽이라, **상쇄되지 않는다.** ⇒ **🔵 유지.** 🟢 를 여는 다음 칸은 명확해졌다: 「짓기 전에 기억/책장을 쓸었나」에 **기계 앵커가 0** 이고, 트리거가 파일이 아니라 **저술 시점**이라 훅으로 못 잡는다(`[[feedback_instrument_not_on_the_path]]`). 정본: `tracks/_meta/fh_signal_2026-08-30_retraction-scope.md` — **↓ 옛 조건(참조용, 채점에 쓰지 마라)**: 설계되지 않은 자리에서 창이 스스로 열려 자산으로 이어지는 **1건**. 기다리는 것이 아니라 평소 작업에서 저절로 생긴다 |
| ① | 하네스 클러스터 (**🟢 2026-08-16 — 기준이 바뀌었다, 아래 §①-2026-08-16 를 먼저 읽어라**) | context-continuity | 🟢 | routing already ran for real (17 nodes, sidecar-orchestrator, Skill Bus). **The relay half is now built rather than specified**: `capability_composition_contract.md` (2026-08-02) was a complete spec with **zero implementing code** — the ① blocker was missing wiring, not missing design ([[feedback_built_but_not_wired]]). `scripts/relay_channel.sh` executes it (strictest-wins merge · typed invocation · checks 1/2/3 · short-circuit · causal binding), `scripts/test_relay_channel_lanes.sh` carries **64 lanes, BLOCK/PASS symmetric**, and three arms ran across **two real field harnesses** (pmh-dev · qasp-dev) on FH's own assets. ⭐ **The measured result is the divergence arm, and its mechanism is not what the first draft of this row said.** On `templates/.git-hooks`, `qasp` alone returns exit 0 — a single-node pass would have shipped it — and the composition returns `BLOCKED` because `pmh` returns `FINDINGS`. But `qasp`'s exit 0 is `degrade-scan: no scannable (py/sh) target files`: **zero files were scanned.** The qasp copy predates pmh's 2026-07-28 shebang pass, so extension-less hook files are invisible to it, and its exit 0 means *no target*, not *clean*. So the composition did not catch a substantive disagreement between two harnesses — it caught **a single node rendering an unmeasured surface as a pass**, which is `[[feedback_not_found_is_not_zero_family]]`, and structurally the spec's own §ⓑ.4 B1 ("the exit 0 that means I never started"). That is a *stronger* result than the first framing and a narrower one: it demonstrates the union catching a blind spot, not decorrelated judgment. **Correction also to the order claim**: both orders return `rc=2`, but in the pmh-first order the chain short-circuits at node 1 and qasp never runs — only the qasp-first order actually exercises the union. Non-decorative: reverting each wiring line reddens lanes and no reversion passes silently. **Why this is RC and not 🟢** — *updated 2026-08-11; (b) and (c) moved, (a) did not, and a fourth appeared*: (a) the row's *other* half, external-harness recommend, is still parked — **unchanged, and it is a build, not a check**; (b) ~~`scripts/capability_registry_check.sh` does not exist~~ → **built 2026-08-11** (M1–M5 + the ran≠did-not-run clause, M4 pair executed, 7 self-test lanes BLOCK/PASS symmetric); (d) **NEW, and it cuts against the row**: a capability declaring `writes: read-only` passed all of M1–M5 and its entry point then `rm -rf`'d this repo's `scripts/`. The registration bar measures *form* and *known-pair separation*, never *whether the declaration is true* — so the machinery this row now points at carries a demonstrated structural hole (`capability_composition_contract.md §Salience`). A checker whose green can precede a destructive act is not yet a green identity; (c) ~~the two nodes are copies of one scanner at different staleness~~ → **superseded 2026-08-11, but only partly**: a run now exists across two *genuinely different* capabilities (a leak lens ∪ a verdict-direction lens — different enums, different defect classes, each blocking on its own finding), and the clean arm exercised the union end-to-end. ⚠️ **That satisfies the letter of the old (c) and not the identity's spirit: both new nodes live inside FH.** This identity was then named *멀티하네스 클러스터* (shortened to *하네스 클러스터* 2026-08-16); the only run that actually crossed harness boundaries is still the older pmh-dev/qasp-dev one, whose nodes were<a name="c-orig"></a> **copies of one scanner at different staleness** (all three copies — pmh 237 ln, qasp 121 ln, FH 269 ln — share a byte-identical 12-line header; the clean arm's two `out_sha` were identical), so the run proves the channel turns and that composing unequal copies has value, not that two independent judgments were decorrelated. Artifact: `tracks/_meta/identity_audit_2026-08-09_relay_channel.md` <br><br>**<a name="id1-20260816"></a>§①-2026-08-16 — 이 행이 🟢 이 된 이유는 «더 잘해서» 가 아니라 «다른 것을 재서» 다. 그 사실을 먼저 적는다.** 🟥 **옛 바로 재면 이 행은 오늘도 🔵 다.** §Gate consequence 의 dominance 절을 **두 번** 쟀고 **둘 다 미성립**이다 — 1차(기계 스캔 vs recall, `tracks/_meta/dominance_2026-08-16_cluster_scan_vs_recall_RESULT.md`)는 **상보**: 기계는 실행 축(M4·M6)을 독점하고 recall 은 구조·정합 축을 독점한다 — 서열이 아니라 직교다. 2차(**복사 vs 호출**, survives 다리, `tracks/_meta/dominance_2026-08-16b_copy_vs_call_RESULT.md`)는 **safety 동률**: 구 enum 사본으로 `exit 4` 를 부르면 relay 가 enum 밖 값을 `HARNESS_ERROR` 로 접어 `BLOCKED`(rc=2), 소유 선언은 `OUT_OF_SCOPE` 로 `BLOCKED`(rc=2) — **둘 다 막는다.** 「복사는 조용히 썩는다」는 예측이 반증됐고, 안 썩게 막아주는 것은 이 레포가 이미 가진 «미측정≠PASS» 규율의 기계 판본이었다. 두 측정 다 **사전등록 봉인 후 실행**이고 반증 조건을 결과 뒤에 옮기지 않았다. ⇒ **운영자 결정(2026-08-16)**: ①의 🟢 기준을 dominance 에서 **ⓐⓑⓒ 3기준으로 대체**한다. 운영자 원문 — *"그들의 능력을 활용하고 **내 쪽에서 더 짓지 않기 위한(재발명을 최소화하기 위한)** 목적이 멀티하네스 클러스터"* · *"FH 의 **뾰족한 부분을 유지하면서** 능력을 최대한 쓸 수 있는 방법"* · *"오래오래 진화에 따라 **살아남으면서 얇아지면서도** 가치를 발휘 … LLM 의 진화 그리고 다른 유수의 하네스들의 진화, **그 덕을 받는 것이 목적**"* (전문 + 방법론: `tracks/_meta/doctrine_2026-08-16_identity1_redefinition_and_method.md`). ①의 산출은 «더 많이 잡았다»가 아니라 **«안 지어도 됐다»** 라서 dominance 는 겨냥이 틀린 계기다. ⚠️ **이 대체는 ①에만 적용된다** — 다른 행의 dominance 요구는 그대로다. **ⓐ 재사용이 실재하고 호출 가능한가(복붙 아님)** → ✅ **측정**: `pmh-dev:merge-noop-check` 가 **pmh 자기 레포에서** 선언되고(`.claude/capabilities/merge-noop-check.cap`, `requires_cwd: SELF`, known-pair 는 그 레포의 실제 커밋 두 개), FH 가 `cluster_capability_scan.sh discover` 로 **발견** → `capability_registry_check.sh` M1–M6 `REGISTRABLE` → `relay_channel.sh run` 으로 **실제 호출**한다. 양·음 arm 이 갈린다 — NO-OP 입력은 `FH_NODE1_VERDICT: NO_OP` 로 node1 에서 BLOCKED, 차이 있는 입력은 node1 통과(`HAS_DIFF`) 후 node2(`forge-harness:degrade-direction-scan`)가 `FINDINGS` 로 BLOCKED. **다른 노드에서 다른 이유로** 막히므로 「늘 막는 계기」와 구분된다. **ⓑ FH 가 안 커졌는가 — «안 한 일»을 이름으로 댈 수 있는가** → ✅: `merge_noop_check.sh`(트리해시 + 조상관계 판정)를 FH 는 짓지 않았고, FH 자기 정본 `knowledge/shared/rules/multi_session_close_protocol.md §1-b` 가 **그 파일을 이름으로 지목하며 «가져오면 된다»** 고 이미 적어둔 자리가 여기다. 오늘 FH 가 새로 지은 것은 **채널**(`relay_channel.sh --cap-args`, 노드별 호출 인자)이지 판단이 아니다 — 그 채널이 없는 동안 호출 시점 인자를 요구하는 능력은 **항상 `ARGS → HARNESS_ERROR → BLOCKED`** 였다(방향은 fail-closed 로 옳았으나 **신호가 0**, 즉 «호출 가능» 을 구조적으로 만족시킬 수 없었다). **ⓒ 뾰족함이 보존되는가** → ✅ **측정**: 합성이 `FH_MERGED_residency: company`(둘 중 엄격한 쪽) · `verdict_binding` 은 4값 합집합 · 상류가 막히면 하류 노드 미실행. 🟥 **명시 잔여 — 축소하지 않는다.** ⑴ **두 측도를 갈라 적는다.** **㉮ 선언 보유 하네스 = 2**(FH · pmh) — *능력(capacity)* 측도. **㉯ 실제로 함께 돈 하네스 = 5** — *사건(event)* 측도이고 정체성이 묻는 쪽이다. 🟥 **단일 합성 한 번에 5개가 돌았다(실측, 세션 말)**: `relay_channel.sh run` 4노드 체인이 `gstack`(어댑터) → `pmh-dev`(소유 선언) → `mate-dev`(어댑터) → `qasp-dev`(어댑터) 를 태우고 FH 가 그 사이에서 병합했다 — 청정 arm 은 **네 노드 전부 실행 후 `FH_RELAY_VERDICT: PASS`(rc=0)**, 교란 arm 은 node3 `FAIL` 에서 `BLOCKED` + 하류 미실행(rc=2). **늘 통과하지도 늘 막지도 않는다.** 병합 결과: `residency: company`(다섯 중 최엄격) · `verdict_binding` **9값 합집합**. ⚠️ ㉮ 가 여전히 2인 것은 나머지 셋이 **어댑터**(FH 소유·FH 유지)이기 때문이고, 그게 결함이 아니라 운영자 결정으로 정해진 **기본 경로**다(§선언 위치). ㉮ 가 커지는 것은 남이 «노출한다» 고 자기 정본에 적었을 때뿐이다. 그리고 ㉮ 가 여전히 작다는 사실은 남는다: ⚠️ **부풀리지 않는다**: clawd-on-desk 는 하네스 자산이 없는 **대상 레포**라 PR #888 은 기여였지 하네스 주행이 아니다 — 세지 않았다. 그리고 ㉮ 가 여전히 작다는 사실은 남는다: qasp 는 **그 하네스 자신의 입장리뷰가 REJECT** 했다 — 정본 근거 0건 · 소비자 0곳(읽는 건 FH 뿐) · `session.md:101` 「n=3 전엔 추상화 금지」 위반 · **그 선언 경로가 그 하네스의 조직 미러 대상에서 제외돼 있지 않다**(운영자가 이 레포에서 통제하지 않는 목적지로 그대로 복제된다). 운영자 결정(2026-08-16)으로 **보류**이며, 「이 하네스는 외부 하네스에 자기 인터페이스를 노출한다」를 **그 하네스 자신의 정본에 적는 것**이 선행 조건이다. 선언 파일이 남의 레포에 **있다**는 것과 그 하네스가 노출을 **결정했다**는 것은 다른 명제다. ⑵ 🟥 **(d) 는 안 닫혔다.** `.git/objects` 를 감시면에 넣어 객체 쓰기 한 부류를 닫았고(probe L13 탐지 / L13b 과차단 컨트롤 / 되돌림 시 정확히 L13 만 적색), **그러나 M6 는 선언된 캘리브레이션 arm 만 관측한다** — 실증: `merge_noop_check.sh` 는 **분기 입력에서 git 객체를 쓰는데**(격리 클론 실측: `.git/objects` 파일 수가 **+1**. ⚠️ 절대값은 클론 상태에 의존하므로 **델타만 인용한다** — 이전 판본이 적었던 절대 쌍은 재현 불가라 철회한다) 선언된 두 arm 이 그 경로를 안 지나므로 `writes: read-only` 로 거짓 선언해도 `REGISTRABLE` 이 난다(실측 확인). 같은 날 아침에 나온 **「검사기에 enum↔구현 일치 축이 없다」와 같은 형태**다 — 같은 stale 선언이 캘리브레이션 쌍에 따라 REJECTED 도 REGISTRABLE 도 된다. 한 문장으로: **검사기는 선언이 시키는 것만 본다.** ⑶ 그러므로 이 🟢 은 **「클러스터가 실제로 돈다」**에 대한 것이지 **「등록 바가 선언의 진위를 검증한다」**에 대한 것이 아니다. 후자는 열려 있고, 열려 있다고 적는다. Artifact: `tracks/_meta/identity_audit_2026-08-16_cluster_green.md` <br><br>**<a name="id1-naming"></a>§①-naming (운영자 결정, 2026-08-16) — 이름을 줄이고, 그 안의 하중 부품에 이름을 준다.** 「멀티하네스 클러스터」 → **「하네스 클러스터」**: 「멀티」와 「클러스터」가 둘 다 복수를 뜻해 **중복이었다**. 그리고 그 아래에 **크로스하네스**를 둔다 — *"서로간의 능력을 보강하기 위함이야. **없는 걸 쓰기 위함**이고, FH 에서 **‘짓지 않아도 되는 것’을 다른 레포 개발에 활용**하기 위함이지. 다만 그 와중에 **FH 에서 지어야 하는 게 보이면 개선해서 답습**하는 거고."*(운영자) ⇒ **크로스하네스는 양방향이다**: **활용**(남의 능력을 호출해 FH 가 안 짓는다) **∪ 흡수**(FH 가 지어야 할 것이 보이면 개선해 들여온다). 종전 정의는 앞의 절반뿐이었다. 🟥 **둘의 관계는 합집합이 아니라 «포함 + 하중»이다.** 운영자: *"하네스 클러스터가 돌려면 크로스하네스는 항상 있어야 하니까."* ⇒ **크로스하네스는 하네스 클러스터의 필요조건**이고, 그래서 판정에서 다음이 따라 나온다 — **ⓐ(«재사용이 실재하고 호출 가능한가»)가 곧 크로스하네스 시험이고, 그게 이 정체성의 결박 지점이다.** 노드 수 n 은 클러스터의 **범위**를 재지 «도는가»를 재지 않는다. (이 구분이 없어서 이 행의 잔여 ⑴이 «n=1»을 마치 미성립처럼 읽히게 적혀 있었다 — n=1 에서도 교환은 실제로 일어났다. 다만 **n 을 늘리는 것은 여전히 옳고, 그건 선언이 없어서지 기제가 없어서가 아니다**: 실측 2026-08-16, 매핑된 하네스 12개 중 선언 보유 2개 · 나머지 10개는 `.claude/capabilities` 디렉토리 자체가 없다. 도구는 있다 — gstack `bin/*`=69 · gbrain 50 · openhuman 43 · mate-dev 7 · qasp-dev 16.) 🟥 **크로스하네스는 두 형태를 갖고, 둘 다 «건넜다»에 든다(운영자, 2026-08-16).** **기계 형태** = 남의 능력을 typed 채널로 호출한다(`.cap` 선언 필요) · **판단 형태** = **남의 정본을 근거로 심사받는다**(입장리뷰 — 선언 불요). 운영자: *"입장리뷰도 크로스가 아닐까 … 결국 너와 그쪽 하네스 2개가 동시에 도는 거니까."* ⇒ **판단 형태는 선언 없이 지금 당장 모든 하네스에서 성립한다**, 그리고 **한 번의 크로싱이 이미 하네스 2개의 동시 주행**이다. *"크로스하네스는 노드 1개라도 발휘되는 거고 … 그게 늘어나면 클러스터가 되는 거고."* ⇒ **크로스하네스 = 사건(건넜다) · 하네스 클러스터 = 그 사건의 누적.** 🟥 **이 문장이 아래 잔여 ⑴의 계수 오류를 잡는다** — 나는 «외부 **선언** 수»를 셌는데 정체성이 묻는 것은 «**함께 돈 하네스** 수»다. 두 측도를 갈라 적는다(둘 다 남긴다, 유리한 쪽만 남기지 않는다). 🟥 **명칭 경계 — 알고 쓴다.** `cross-harness` 는 이 레포에서 **이미 다른 뜻**으로 쓰인다: `CLAUDE.md §Standpoint axis` · `field_verdict_crossfamily_gate.md §7` 의 *"cross-harness-boundary change"* = **다른 하네스의 동작·게이트 결과·상호작용 계약을 바꾸는 diff**(게이트 트리거 범위). 정체성 이름이 「하네스 클러스터」로 남으므로 **최상위 층에서는 충돌하지 않지만**, 하위 기제 「크로스하네스」와는 여전히 같은 낱말이다 — 구분: **명사 「크로스하네스」 = 능력 교환(이 정체성의 필요조건)** · **형용구 cross-harness-boundary = 그 게이트의 적용 범위**. 섞어 쓰지 마라. 🟥 **ⓑ 기준이 양방향화에 맞춰 «좁아진다»(느슨해지는 게 아니다).** 흡수를 허용하면 ⓑ(«FH 가 안 커졌는가»)가 그대로는 무력해지므로: **FH 는 «닫는 FH 결함을 이름으로 댈 수 있을 때만» 커진다.** 새 규율이 아니라 이미 있는 증거-임계 빌드 규율(`fh_signal_2026-08-16_expedition_two_tracks.md` §경계 2 — *"«좋아 보여서»가 아니라 «우리 결함이 그걸 요구해서»"*)을 ⓑ 의 판정 문구로 승격시킨 것이다. ⇒ **ⓑ = ⑴ 호출로 대체한 것을 이름으로 댈 수 있고, ⑵ 새로 지은 것은 각각 닫는 FH 결함을 이름으로 댄다.** 오늘 실적: 대체 = `merge_noop_check.sh`(안 지었다) · 신축 = `--cap-args` 채널(닫는 결함 = «호출 시점 인자를 요구하는 능력이 relay 를 통과할 방법이 없다», 실측) + `.git/objects` 감시(닫는 결함 = «`writes: read-only` 거짓 선언이 VERIFIED 를 받는다», 실측). 둘 다 이름이 붙는다. 🟥 **선언 위치는 두 종류이고, 기본은 «어댑터»다(운영자 결정 2026-08-16 — 초판은 이걸 거꾸로 적었다).** 운영자: *"사용자들은 다들 대상 레포에 짓지 않을 거야. **FH 내부에 상주시키겠지.** 필요하다면 개인용 레포로 분리해서 관리할 거고."* · *"로컬에서 작업하기 위한 거니까 **어댑터는 내장되어 있어야지.**"* ⇒ **어댑터 선언 = 기본 경로**(FH 안 `.claude/capabilities/adapters/` + FH 소유 스크립트, **유지 책임은 FH**, peer 는 **이름으로 해석**해 tracked 파일에 홈 절대경로를 안 싣는다). **소유 선언 = 특권적 경우** — 그 하네스를 소유하고 **동시에** 「외부 하네스에 인터페이스를 노출한다」를 **그 하네스 자신의 정본에 적었을 때만**(pmh-dev 가 그 유일한 사례다). 🟥 **이 뒤집기는 실측이 강제했다**: qasp 입장리뷰가 남의 레포 안 선언을 REJECT 했고(정본 근거 0건 · 소비자 0곳 · n=3 규칙 위반 · 조직 미러 노출), gstack 은 **애초에 남의 공개 레포(READ 권한)라 푸시 자체가 불가능**했다 — 즉 소유 선언은 «드문 경우»가 아니라 **대부분의 경우 성립조차 하지 않는다.** 어댑터가 허용되는 근거는 dominance-2 가 잰 것이다 — 복사 vs 호출이 **safety 동률**이었고 차이는 «정보와 유지 책임»뿐이었다. 라벨과 FH 소유가 그 차이를 닫는다. ⚠️ **residency 경계**: `company` peer 의 어댑터는 **tracked 로 두지 않는다** — 커밋 시점 공개표면 스캔이 floor 이지만, 판단이 먼저다. ⚠️ **미결 — 운영자 결정 대기**: *"운영자 환경에서는 상시 제안 가능. 사실 제안도 자동으로 반영 가능"*. 제안의 **자동 반영**은 자율성 확장이라 §Operational Adaptation Loop 의 action-class floor 를 그대로 통과해야 한다 — 흡수 커밋 자체는 가역이지만 **그것이 publish 를 먹이면 taint 가 전파**되고, 그 경우 registry floor 가 `promotion_eligible` 을 금한다. 바운드된 형태(운영자 환경 한정 · 가역 표면 한정 · typed 기록 필수 · 게이트는 그대로)로 좁히기 전엔 자동화하지 않는다. **미구축이며, 미구축이라고 적는다.**
| ② | 프로젝트 인큐베이터 (**🟢 2026-08-21**) | context-continuity + judgment-circuit | 🟢 GREEN | **정식 흐름이 배출했고, 배출물이 대상 하네스에서 돌았다.** (a) 구현 `chamber_run.sh` 6단계 게이트 (b) known-pair 러너 18 레인 + 순서 증인 16 레인 (c) self-test 초록 — RC 세 다리는 2026-08-09 에 섰다. **🟢 로 올린 근거는 그 위의 넷이다**: ⓐ **런 #15 `interslide-dependency-graph` = EMIT + 순서 증인 `WITNESSED`**(게이트 아티팩트 3건이 verdict 보다 먼저 커밋 고정; `chamber_witness.sh verify` 재실행 확인) ⓑ 배출물이 **대상 하네스에 배선되어 실물 발화**(2026-08-21, `preprep` L8 — 절 29 · HARD 의존 4 · 깨짐 0 · UNRESOLVED 2) ⓒ **배출물의 미해소를 재서 줄였고 정답쌍이 안 깨졌다**(표기 정규화 수리 → `S20 → S9 [OK]`; arm A rc=1 BROKEN 유지 · arm B rc=0 불변; 진짜 모호한 1건은 안 풀림 = 새 오탐 0) ⓓ advisory 되돌림 컨트롤 통과(HEAD 판 대비 rc·USE 불변). 🟥 **정직 조건 셋, 지우지 마라**: (1) **n=1** — 런 #14 도 EMIT 이나 순서 증인 `VOID(TAMPERED)` 라 근거로 못 쓰고 **그 문서가 스스로 그렇게 적었다** (2) L8 은 **advisory 고정**이라 아직 «사람이 못 본 결함을 잡은» 적은 없다 — 잡은 것은 자기 미해소다 (3) 옛 서술 *"formal chamber EMIT 아직 0"* 은 **2026-08-20 부로 stale** 이었다(#14·#15). 그 stale 이 12일간 안 잡힌 것 자체가 `[[feedback_rule_misdescribes_its_own_machine]]` 사례다. 아래 옛 판정 줄은 이력으로 남긴다 |
| ②-old | (이력) 프로젝트 인큐베이터 | context-continuity + judgment-circuit | 🟡 PARTIAL | incubation is running — **stockbattle is being incubated now** (S1 built, mid-flight) + qasp/pmh spin-out precedent + scaffold-emit shipped (doctrine: "emit shipped today as scaffold+approval; the chamber flow is the named target"). **Corrected 2026-08-08** (the old text read "6 runs, 6 KILL … 0/6", which was stale on both counts, and the ledger itself was missing a run): hand-counted from `tracks/_chamber/INDEX.md` — **9 full runs (#2–#10), 8 KILL, 1 EMIT** (#1 is a trigger probe, not a full run). Runs #5–#6 *measured* the emit-worthiness criterion (net-new ∧ artifact-shaped ∧ real-data-precision-adequate ∧ hub-state-independent); run #6 confirmed the graduation-order principle — hub-internal proof before standalone extraction, never the reverse. **The 🟡 is now held for a different reason than before.** The old reason ("no closed emit-via-incubation yet") is false: run #9 `forge-wiki` emitted and shipped publicly under operator approval with the Pre-Publish gate passed. What is *not* proven is that the **formal chamber flow** produced it — that run's workspace holds only an `EMISSION_VERDICT.md`, with no `INTENT.md`, `BUDGET.md` or `SIM_NOTES.md`, so the intent/budget/blind-persona gates have no artifact and the verdict was written after the fact. The first run to complete the formal flow end-to-end is #10 (2026-08-08, 3 blind isolated personas) and it KILLed. So: **the identity has fired once, the mechanism has not yet been shown to be what fired it**, and the dominance result every 🟢 owes is still outstanding → 🟡 |

### §digest-routine — 옛 ④ 행의 측정 내용 (삭제 아님, 이관)

`scripts/digest_landing_check.sh` 는 **기계화된 일상작업(frontier-digest)의 스크리너**다.
원문의 측정을 그대로 보존한다: 두 축 분리(git추적 → `git log --since` 커밋시각 / gitignored
`tracks/**` → mtime / dirty-tracked → `UNMEASURED`)를 **두 레인이 고정**하고, 두 번째 레인이
없으면 «추적 파일을 전부 버려 negative 만 통과»로 퇴화한다(cross-family 지목). self-test
**20 레인** 초록. 명시 잔여: `file-change ≠ token-introduction`. 행이 스스로
*"screener, not an adjudicator — 히트는 열어야 한다"* 라고 선언한다.

**2026-08-21 추가 실측 — 그 선언이 실제로 물었다**:
```
frontier_digest_2026_08_20.md   계기 rc=0 «3건 전부 착지»  →  손검증 0/3 착지
  후보 1·2·3 이 각자 착지 지점을 지정해뒀고, 세 자리 모두 비어 있다(컨트롤 동반)
  비공개 companion store 도 확인 — 거기도 없다(스코프 밖 착지 아님)
같은 후보(2608.09096·2608.06301)가 08-17 digest 에도 앵커검증까지 돼서 올라갔고 그때도 미착지
```
🟥 **이것을 «계기 결함»으로 적지 마라** — 행이 이미 스크리너라고 선언했고 «히트를 열어라»고
지시한다. 새로운 것은 결함이 아니라 **비율(1개 digest 3/3)과 반복(같은 후보 2회 미착지)**이다.
⇒ 일상작업 쪽 잔여로 기록: **표면화는 되는데 닫히지 않는다.** 그리고 이 결과는 **④ 의 판정에
안 걸린다** — 재정의로 대상이 갈렸기 때문이다.

---

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
| **P1** | An EMIT run leaves an ordering record that does not depend on trusting the author — the intent/budget/sim record committed, hashed, or otherwise witnessed **outside** the gitignored workspace, before the verdict | mandatory-pass | **channel exists (2026-08-08)** — `scripts/chamber_witness.sh`, wired into `chamber_run.sh` steps 2–5. 🟥 **and it was UNSATISFIABLE until 2026-08-17 — by construction, not by strictness.** See §P1-2026-08-17 below. **Still unsatisfied**: no run holds a witness yet |

<a name="p1-20260817"></a>
**§P1-2026-08-17 — 첫 형식 완주가 이 조건이 «도달 불가능»이었음을 실측했다. 수리했고, 그 사실을 남긴다.**

챔버 런 **#11**(`persona-simulator-harness`, KILL)은 이 채널을 **처음으로 끝까지** 태운 런이다.
그리고 완주하자마자 `verify` 가 **`TAMPERED — 증인 무효`** 를 냈다. 기전은 추측이 아니라 코드다:

```
step 3   BUDGET.md(ESTIMATE)의 해시를 증인 원장에 기록          ← 사전등록 증인
step 5   verdict 기록
step 6   BUDGET.md 에 ^ACTUAL: 을 요구하며 하드 차단(exit 1)    ← 그 파일을 변경하도록 강제
verify   기록된 해시 ≠ 현재 파일  →  TAMPERED
```

⇒ **COMPLETE 에 도달하려면 반드시 증인 아티팩트를 사후 변경해야 했다. 우회로가 없었다.**
즉 P1 은 «완주한 런»으로 만족이 불가능했고, 그것이 ②가 🔵 였던 **기계적** 이유다 — 후보가
부족해서가 아니다. 이 절이 2026-08-08 에 *"unreachable condition … trains people to delete the
thing being counted"* 라고 경고한 그 형태가, **그 경고를 적은 채널 자신에서** 재발했다.

**대상 선정 실수가 아니다.** P1 문언이 *"the **intent/budget**/sim record"* 로 BUDGET 을 증인
대상으로 **명시 지목**한다. 결함은 **한 파일에 두 역할이 겹친 것**이다 — ①불변을 요구하는 증인 ·
②변경을 요구하는 사후 캘리브레이션. **개별로는 둘 다 옳고, 충돌은 아무도 소유하지 않는다.**
그래서 어느 쪽 코드를 읽어도 안 보였고, 정적 판독은 양쪽 다 초록으로 읽힌다.

**왜 기존 검증이 다 놓쳤나 — 이게 남길 값의 본체다.**
- `test_chamber_run_lanes.sh` 는 헤더에 *"순서 증인은 이 테스트의 대상이 아니다 — 부수 효과가
  섞이므로 복사하지 않는다"* 라고 **명시적으로 증인을 제외**했다.
- `chamber_witness.sh --self-test` 16레인은 증인을 **단독으로** 시험했다(cross-family 가 fail-open
  7건을 잡은 그 레인들이다).
- ⇒ **러너 × 증인의 이음매를 어느 쪽도 안 봤다.** 두 테스트 다 자기 범위에선 옳았다.
- 그리고 러너 픽스처 `_mk_budget()` 이 `ESTIMATE:\nACTUAL: -` 를 **한 번에** 써서, 12레인 어디에도
  «추정→실행→실비용» 이라는 **실제 순서가 존재하지 않았다.** 픽스처가 *상태*를 모델링했고 결함은
  *과정*에 있었다. `[[feedback_adversarial_review_not_substitute_for_first_use]]` 의 교과서 사례다.

**수리(2026-08-17)** — 스펙은 안 건드리고 **변경 요구만** 빼낸다:
- `chamber_run.sh` step 6 → **별도 `ACTUAL.md`**. 정의상 판정 후 산물이므로 **증인에 기록하지 않는다.**
- `chamber_witness.sh do_record` → 동일 `(run, artifact, sha)` 삼중항 재기록 스킵. 종전엔 무조건
  append 라 4스텝 런에 엔트리 **11개**가 쌓였다(판정은 안 틀리나 공개 tracked 파일이 부풀고 verify
  출력이 같은 줄을 반복해 **읽는 사람이 「몇 건이 문제인가」를 오독**한다). 🟥 **내용이 바뀐 경우는
  여전히 새 엔트리로 남는다** — 그게 TAMPERED 를 성립시키는 증거다.
- `test_chamber_run_lanes.sh` **12 → 26레인**. 신설 축은 **이음매**이고, 어서션이 두 겹이다:
  **L13-a**(완주 후 BUDGET.md 해시 불변) + 🟥 **L13-b**(step 6 이 **지목하는 파일**이 증인 대상이
  아닐 것). L13-b 가 본체다 — **러너는 BUDGET.md 를 직접 고치지 않고 사람에게 고치라고 시키므로**,
  파일 해시만 보는 L13-a 는 되돌림 프로브에서 **초록으로 남았다**(즉 그것만으로는 장식이었다).
  잴 것은 파일이 아니라 **지시**였다. 되돌림 실측: `git show HEAD:` 판으로 되돌리면 L13-b 가
  적색(`step6 이 증인 아티팩트를 고치라고 시킨다`), 컨트롤은 초록 유지.

### 🟥 §P1-2026-08-17-b — 그리고 그 수리로도 아직 부족했다. **커밋을 합치는 모든 경로가 증인을 죽인다**

런 #12(`prosody-lens`, KILL)가 수리 후 첫 런이었고, TAMPERED 는 사라졌으나 **`UNORDERED`** 가 나왔다.
판정 코드가 이유를 명시한다 — `chamber_witness.sh do_verify`:

```bash
# 주석 원문: "같은 커밋(또는 같은 초)에 들어온 verdict 는 «먼저» 를 증명하지 못한다"
if [ "$verdict_ts" -le "$pre_max_ts" ]; then    # ← -le. 같은 «초» 도 실패
  echo "UNORDERED — verdict 가 pre-verdict 아티팩트보다 먼저이거나 같은 시점에 커밋됐다."
  return 1
fi
```
이건 의도된 설계다(초판이 `-lt` 라 same-second 역순을 통과시켰고 cross-family 가 잡았다).
문제는 **그 조건을 만드는 경로가 이 레포의 표준 절차 안에 셋이나 있다**는 것이다:

| 경로 | 실측 |
|---|---|
| **P-a `--squash` 머지** | 런 #11 은 브랜치에서 게이트/verdict 를 **따로** 커밋해 순서가 성립했다(`e86f796`→`f79cc05`→`852064b`). PR #414 를 squash 하자 **main 에서 원장을 건드린 커밋 = 1개** — 게이트 4 + verdict 가 전부 그 하나에 접혔다 |
| **P-b 저자가 한 커밋에 배치** | 런 #12 에서 4해시를 한 번에 커밋(`50ef761`) → 브랜치에서부터 UNORDERED. 실측 `verdict_commit=1786935355 latest_pre=1786935355` |
| **P-c `--delete-branch`** | 순서를 담은 커밋이 도달 불가가 된다(런 #12 의 첫 증인 커밋이 그렇게 됐다) |

🟥 **정정**: 위 §P1-2026-08-17 을 *"P1 이 만족 가능해졌다"* 로 읽지 마라. 정확히는
**피처 브랜치에서 만족 가능하고, 이 레포가 의무화한 squash 머지가 main 에서 그것을 파괴한다.**

**채택된 처방 ⓐ (운영자 결정 2026-08-17) — 정책 변경 0**:
> **게이트 해시와 verdict 해시를 두 PR 로 분리한다.** 각각 squash 해도 main 에 **2커밋**이 남아
> 순서가 보존된다. 저자 규율이 따라온다 — **게이트 커밋과 verdict 커밋을 절대 합치지 않는다**(P-b 차단).

**배선**(산문으로 안 남긴다): `chamber_run.sh` 가 **행위자가 읽는 자리에서** 이 규율을 인쇄한다 —
게이트 기록 시 «verdict 보다 먼저, 별도 커밋으로», verdict 기록 시 «게이트 해시들과 **다른 커밋**»,
그리고 UNORDERED 일 때 세 경로를 이름으로 열거. 앵커는 `test_chamber_run_lanes.sh` **L15/L15b/L15c**
(33레인) — 🟥 **그 레인이 생긴 이유는 러너가 틀린 처방을 가르치고 있었기 때문이다**:
*"원장 해시를 커밋한 뒤 재실행하면 증인이 성립한다"* — 한 커밋에 넣으면 성립하지 않는다.
**게이트 문구는 «막는가»만이 아니라 «옳은 것을 가르치는가»도 재야 한다**
(`[[feedback_gate_prescription_is_unverified]]`, 2026-08-17 3번째 사례).

⚠️ **런 #11 자신은 TAMPERED 로 남는다. 소급 수리하지 않는다** — 과거 9런을 back-fill 하지 않는 것과
같은 이유다(사후에 쓴 기록은 증명하지 않는다). **P1 은 이 수리 이후의 EMIT 런에서 처음 만족 가능하다.**
🟥 그리고 이 수리는 **P1 을 만족시키지 않는다** — 만족을 *가능하게* 만들 뿐이다. ②는 🔵 유지.

⚠️ **되돌림 프로브 자체에서 실책 1건(기록)**: 첫 시도가 `sed` 로 따옴표 포함 패턴만 바꿔 **검사는
BUDGET, 메시지는 ACTUAL 인 잡종**을 만들었고, 그 상태에서 L13-b 가 초록이라 하마터면 «레인이
장식이다»로 결론 낼 뻔했다. 되돌림은 **`git show HEAD:` 로 통째 복원**해야 한다 — 부분 되돌림은
되돌림이 아니다.

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
all-green claim (per the refined 0.x↔1.0 mapping above). **`identity-v1.0.0` remains the all-green target.**
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

### ④ promotion criteria — 이 절이 **없었다는 것** 자체가 첫 발견 (2026-08-17)

> 🟥 **STALE — 이 절로 ④ 를 채점하지 마라 (라벨 2026-08-29, 절 자체는 미개정).**
> 본문은 **2026-08-17** 자이고, ④ 는 그 뒤 **2026-08-21 에 «파이프라인」이 아니라 «루프»로 재정의**
> 되고 **08-22 에 트리거가 넓어졌다**. 그런데 이 절은 여전히 digest·조직전파 프레임(P4-1/P4-2)을
> 잰다 ⇒ **탈범위된 명제를 재고 있다.**
> **실측(컨트롤 동반)**: 이 절 구간에서 `P4-1` 7회(= 구간·grep 살아있음) · `책장|도서관|자발|플로어`
> **0회**.
> 🟥 **여기에 이 절이 스스로 밟은 함정이 하나 있다 — 감사 대상이 측정 뒤에 움직였다.**
> 별 세션은 «08-17 이후 날짜 0회»라고 보고했고, 이 세션은 3건을 세고 **「그쪽 근거가 틀렸다」고
> 적었다. 그 귀속이 틀렸다(정정 2026-08-29).** 실측: 그 3줄은 `#### 6. 부수` 의 철회 주석이고
> **같은 날 이 세션의 PR #549 가 넣은 것**이다 — 그 커밋의 부모에서 같은 구간의 날짜는 **0건**
> (같은 슬라이스 컨트롤 `P4-1` 7건, 계기 살아있음). 즉 **peer 의 0 은 자기가 잰 버전에서 참이었고**,
> 이 세션이 그 뒤 대상을 편집해 놓고 그것을 반증이라 불렀다. 덧붙여 줄이 밀려서 「744–870」이라는
> **같은 창이 두 버전에서 다른 내용을 덮는다** — 같은 숫자로 두 버전을 비교하면 안 맞는 게 정상이다.
> [[feedback_audit_target_must_be_frozen]] 의 교과서 형태이고, 여기 적어 두는 이유는 다음 독자가
> 프로브 세션의 근거를 부정확한 것으로 읽지 않게 하기 위해서다(인용 훼손 경로).
> **판정은 안 바뀐다**: 그 셋은 기준의 갱신이 아니라 철회 주석이므로 STALE 라벨은 그대로 선다.
> 🟥 **실제 닫는 조건은 여기가 아니라 §external-grounding 행(`④`) 맨 끝에 있다** —
> «설계되지 않은 자리에서 창이 스스로 열려 자산으로 이어지는 **1건**». 부재가 아니라 **두 자리
> 어긋남**이고, 절이 행을 안 따라갔다.
> 🟥 **그리고 이것은 이 절이 자기 앞 버전에 대해 내린 진단과 같은 형태다** — 「그 조건을 100% 닫아도
> ④ 의 명제는 한 글자도 안 재진다」. 같은 결함이 한 칸 옮겨 재발했다
> ([[feedback_half_fix_propagation_boundary]]).
> **미개정 이유**: 기준을 다시 쓰는 것은 «④ 의 바가 무엇이어야 하나»라는 판단이라 운영자 몫이다.
> 그때까지 이 절은 **읽되 채점에 쓰지 않는다** — 조용히 두는 것보다 라벨이 낫다.

②(438줄)와 Ⓑ(421줄)는 전용 승급 기준 절을 갖고, ①은 행 안에 인라인으로 갖는다.
**④만 없었다.** 그리고 이 파일이 ② 절 첫머리에 그 절이 왜 필요한지 이미 적어놨다 —
*"매 라운드가 바닥부터 기준을 재도출하지 않도록"*. **그 처방이 ④에만 적용되지 않았다.**

#### 1. 🟥 유일하게 명시돼 있던 조건은 **다른 명제를 잰다**

지금까지 ④에 대해 조건처럼 읽힌 문장은 하나뿐이었다:
> *"④ file-change ≠ token-introduction — the instrument is a screener, not an adjudicator"*

그런데 그 계기(`scripts/digest_landing_check.sh`)가 **자기 헤더에서 스코프를 자백한다**:
> *"착지 대상 = 공개 FH 자산 + `tracks/`. 비공개 companion store 는 **보지 않는다** …
> 따라서 **이 계기가 재는 것은 «조직 전체 전파»가 아니라 «허브 내부 착지»다**"*

반면 ④가 주장하는 명제는 `fh_three_layer_canon.md` — *"바깥에서 온 것이 **조직 안까지** 착지한다"*.
⇒ **그 조건을 100% 닫아도 ④의 명제는 한 글자도 안 재진다.** ①이 dominance 를 두 번 측정하고
«겨냥이 틀렸다»로 판정한 것과 같은 형태이고, ④는 그 판정을 **한 번도 받은 적이 없다**.

#### 2. 🟥 그리고 구조적으로 도달 불가다 — P1 과 같은 형태 (**이 파일 안에서는** 지목된 적 없다)

이 파일의 residency 규율(§Ⓑ promotion criteria 3)이 못 박는다:
> *"조직 환경 실적은 **증언으로 남고 측정으로 세지 않는다.** residency 때문에 이 파일에서
> 검증할 수 없고, 검증 못 하는 것을 숫자에 넣으면 그 숫자 전체가 못 쓰게 된다"*

그런데 **④는 대상이 조직인 유일한 행**이다. ⇒ 🟢가 요구하는 «구체적 실적 아티팩트»를
**이 파일 안에서는 원리적으로 만들 수 없다.** ②의 P1이 «mtime은 위조 가능 → 어떤 런도 만족
불가»였던 것과 정확히 같은 구조이며, P1 은 지목되어 수리됐고 **이 파일 안에서는** ④ 에 대한
같은 지목이 없다. ⚠️ **범위 제한이다** — 이 파일을 읽어서 내린 판단이고, 전 코퍼스 부재 스캔
(검색어·컨트롤 동반)은 **안 돌렸다**. 「아무도 지목한 적 없다」로 넓혀 읽지 마라.

#### 3. 이미 충족돼 있을 가능성 — 못 읽는 지점이 한 단어로 특정된다

조직 착지는 **운영자 증언으로 존재한다 — 이 세션이 검증한 것이 아니고, §2 대로 이 파일에서는
검증 불가다**(전부 residency 경계 안이라 종류만 적는다): 정기 조직 보고 채널로의 상시 착지 ·
외부 발표 채택과 그 산출이 다시 FH 기계의 근거로 인용됨(**증언 — 「관통」으로 단정하지 않는다**) ·
조직 내 정식 공개 1건.

🟥 **라벨을 반드시 붙인다.** Ⓑ 행이 같은 처리를 한다 — *"실적 열거는 **운영자 증언** + 실측
2건이고 … **증언으로 표기하고 측정으로 세지 않는다**"*. 증인이 없는 관통을 「관통」으로 적으면
다음 라운드가 이 절을 «④는 사실상 충족» 의 근거로 인용한다. 그게 이 파일이 반복해 자책한
인용 훼손 경로다.

> **못 읽는 지점 = «as ONE pipeline».** 조건이 「착지했나」가 아니라
> **「하나의 계기로 관통을 증인할 수 있나」**를 요구하는데, 그 증인 계기가 스스로 조직을
> 스코프 밖으로 선언했다. 계기 헤더도 절반 자백해뒀다 — *"«안 닫힌다»가 아니라
> **«닫히는데 증인이 없다»**"*, *"**파이프라인은 그날 실제로 관통했다**"*.

#### 4. 제안하는 기준 — 막힌 것은 측정이 아니라 **측정의 위치**다

```
지금   조직 데이터를 공개 레포로 가져와 재려 한다   → residency 가 막는다 (정당하게)
대안   계기를 데이터가 있는 쪽으로 옮긴다          → 조직 밖으로 나오는 것을 최소화한다
```

🟥 **초판이 여기서 두 번 틀렸고, 적대검증이 커밋 전에 잡았다. 그 정정을 남긴다.**

**틀린 것 ①** — 초판은 *"**판정만** 넘어오므로 residency 를 안 깬다"* 고 적었다. 그런데 §2 가
도달 불가의 **근거로** 인용한 것이 Ⓑ-3 의 *"조직 실적은 … 이 파일에서 **검증할 수 없다**"* 다.
**조직에서 나온 판정을 이 파일 계열의 공개 기록에 넣는 것**이 곧 그 규칙이 금지한 행위다 —
블로커로 인용한 규칙을 처방이 우회했다. 순환이 아니라 **자기무효화**다.

**틀린 것 ②** — 초판은 챔버 순서 증인(*"해시만 적는다, 본문 유출 0"*)을 유비로 들었다.
**성립하지 않는다**:
```
챔버 증인이 넘기는 것   해시        → 원문 N 개 중 무엇인지에 대해 **0 비트**
초판의 P4-1 이 넘기는 것 후보별 PASS/FAIL → 후보 N 개에 대해 **N 비트**
```
「조직이 이 프런티어 항목을 도입했다/안 했다」는 **그 자체가 조직 정보**다.
*"원본은 한 바이트도 안 나온다"* 는 **바이트 수를 정보량과 혼동한 문장**이었다. 유비를 철회한다.

**그래서 좁힌다.** 조직 밖으로 나오는 것은 **집계된 단일 verdict 하나**뿐이다:

**P4-1 (mandatory-pass)** — 조직 환경 클론에서 착지 계기가 실행되고, 공개 쪽으로는
**집계된 단일 verdict(PASS/FAIL 하나)** 만 기록된다.
🟥 **후보별 판정·건수·비율을 공개 쪽에 쓰는 것은 금지한다** — N 비트가 새는 경로다.
🟥 그리고 residency 예외 절차를 그대로 탄다(`CLAUDE.md §Field-Harness Diagnostic`):
**명시적 운영자 승인 + gitignored 감사노트**. *"«이게 충분히 sanitize 됐나»는 세션이 혼자
내리는 판단이 아니다"* — 이 조건이 없으면 P4-1 은 미충족이다.

**P4-1 의 선행조건 — 지금 둘 다 미충족이고, 그걸 적는 것이 이 절의 값이다**
1. 🟥 **잴 대상이 조직 클론에 존재해야 한다.** 계기 인터페이스는
   `digest_landing_check.sh <digest.md> [target ...]` 인데, digest 산출물은
   `tracks/_meta/frontier_digest_<날짜>.md` 이고 **`tracks/**` 는 gitignored**, 생성은
   **이 머신의 launchd 매일 09:00** 이다. ⇒ **조직 클론에는 잴 digest 가 구조적으로 없다.**
   조직 쪽 생성 경로가 생기거나 공개 digest 를 반입할 수 있어야 한다.
2. 🟥 **실행 주체를 이름으로 적어야 한다.** 없으면 P4-1 은 **「미도달」로 표기하고 승급 기준으로
   세지 않는다** — 이름 없는 실행 주체는 P1 이 «어떤 런도 만족 불가» 였던 것과 같은 형태다.

**P4-2 (measured)**: 그 verdict 가 known-pair 를 가른다 — 착지한 건과 착지 안 한 건을 실제로
구분. 컨트롤 없는 PASS 는 이 조건을 만족시키지 않는다.

#### 5. 🟥 남는 잔여 — 닫는 게 아니라 한 칸 올리는 것이다

그 판정은 **비저자가 볼 수 없는 환경에서 나온 자기신고**다. 챔버 증인이 «저자를 신뢰하지 않는
기록»을 요구한 것과 **같은 문제가 조직 경계에서 재발한다**. 그래서 이 기준은 ④를 «완전히
닫는다»가 아니라 **«증언 → 측정으로 한 칸 올린다»**이고, 그 한계를 조건에 같이 적는다.
비저자 실증이 가능해지는 시점(조직 내 다른 운영자가 그 계기를 돌리는 것)이 다음 칸이다.

**강등 조건 — 이 절이 승급만 적고 강등을 안 적으면 Ⓑ 절의 목적을 못 따른다**
(Ⓑ 절 자기 규정: *"«어떻게 올라가나»가 아니라 «**무엇이 이 행을 내릴 수 있나**»"*):
- **D4-1**: P4-1 의 verdict 가 **known-pair 를 못 가르면**(착지한 건과 안 한 건이 같은 값을 받으면)
  ④는 **🔵 로 되돌린다.** 판별력 없는 PASS 는 측정이 아니다
- **D4-2**: 선행조건 1·2 중 하나라도 **다시 미충족이 되면**(조직 쪽 digest 경로가 사라지거나
  실행 주체가 없어지면) ④는 **「미도달」로 되돌아간다** — 한 번 통과한 것으로 고정되지 않는다
- **D4-3**: residency 예외 절차(운영자 승인 + 감사노트) 없이 조직 판정이 공개 쪽에 기록되면
  그 기록은 **무효이고 ④는 강등된다.** 이건 등급 문제가 아니라 규율 위반이다

#### 6. 부수 — 이 절이 적었던 stale 2건, 둘 다 2026-08-29 에 정정됨

🟥 **이 절의 초판 두 항목은 «확인된 stale 2건»이었는데, 실제로는 1건이 stale, 1건이 수리완료
오보였다.** 즉 stale 을 세는 절 자신이 stale 이었다. 아래는 정정 후 상태다.

- 🟥 **RETRACTED 2026-08-29 — «인자와 함께 부르는 프로덕션 호출부는 0개» 는 거짓이었다.**
  이 항목은 «zero callers 처방은 stale 이 아니다» 라고 적으며 그 근거로 위 문장을 들었다.
  근거가 틀렸다: `scripts/frontier_digest_daily.sh:391` 이 `bash "$checker" "$prev"` 로
  **digest 파일을 1인자로** 넘긴다(`landing_witness()` `:351-392`, 호출부 `:421`·`:504`·`:532`).
  🟥 **판별자를 좁혀도 살아남지 못한다** — 이 문장은 «인자와 함께»라고 **좁게** 적었으므로
  env 전달이었다면 좁게 참일 수 있었다. 실제 호출 형태가 1인자라서 **좁게도 거짓**이다.
  ⚠️ **이 파일 안에서 이미 철회된 주장이었다** — 위 §external-grounding 행이 **2026-08-22 에**
  같은 주장을 RETRACT 했는데 이 절만 옛 서술로 남았다. 같은 파일 안에서 정정이 *옆에* 착지하고
  *대체하지* 않은 형태 = `[[feedback_half_fix_propagation_boundary]]`, 이 파일에서 두 번째다.
  🟥 **따라서 이 항목이 파생시킨 «§4 P4-1 미충족 선행조건» 주장도 함께 철회한다** — 그 논거가
  «실행 경로가 없다»였는데 실행 경로는 있다. P4-1 의 실제 상태는 **미측정**이며(조직 클론은
  residency 경계라 이 레포에서 확인 불가), 미측정을 미충족으로 렌더하지 않는다
  (`[[feedback_not_found_is_not_zero_family]]`).
  ⓐ 여전히 참인 것: 「나머지 절반 «네 분기 앵커링»은 **미확인**」.
- 🟥 **RETRACTED 2026-08-29 — «160줄이 옛 등급을 현재형으로 인용한다» 는 두 겹으로 어긋났다.**
  ⓐ 줄번호가 틀렸다(160 → **206**). ⓑ 그 자리는 **이미 수리돼 있다** — `:206` 은 현재 등급
  `①③⑤ are 🟢, ②④ are 🔵 RC` 를 쓰고, 바로 아래 `:208` 이 그 수리 이력을 스스로 적는다.
  ⇒ 이 항목은 **수리완료를 미수리로 가리키는 오보**였다. 컨트롤 동반 확인:
  `:155-168` 구간 `🔵` 히트 0 / 같은 grep 을 `:204-210` 에 = 2 (계기 생존).
  ⚠️ **순서는 확정 못 한다** — 이 절의 헤더도 `:208` 의 수리도 같은 2026-08-17 자라 파일만으로는
  선후가 안 갈린다. 확실한 것은 «현재 상태에 수리가 들어 있고 이 항목이 그것을 미수리로 가리켰다»
  까지다.
  ⚠️ **`:176` 은 건드리지 않는다** — `③⑤ 🟢, ④ 🟡, ①② 🔴` 은 v0.1.0 태깅 당시 결정의 **이력
  서술**이라 정당하다. `:206` 과 형태가 비슷해 일괄 치환하면 이력이 깨진다(`:154` 가 같은 파일에서
  *"blanket substitution would have corrupted all three"* 라고 경고한 그 함정).

**출처**: 2026-08-29, 워크트리 세션의 격리 그라운딩 감사가 지목했고 본 세션이 소스로 재검증했다.
**자력 적발 0** — 이 파일을 여러 번 편집한 세션들이 세 번 다 놓쳤다.

### §Gate-consequence 의 일관성 — 자백은 적혀 있고 처분은 안 됐다 (2026-08-17)

607–614줄이 **스스로** 이렇게 적어놨다:
> *"⑤ 는 🟢 on `intent-routing probe 94%` — **a self-measurement, not a head-to-head** …
> The inconsistency is real and it is **the gate's, not ②'s** … Resolving that is a **separate
> change** to the status definitions — flagged here, **not silently settled**."*

**그 «separate change» 가 오지 않았다.** 실측하면 **6행 중 4행이 비일관**이다:
```
Ⓑ  일관 적용  만족 — 282줄이 "§Gate consequence 를 **면제 없이 그대로 만족**한다" 고 명시
③  일관 적용  보유 (moat 3–4 family blind · HITL 8/8)
─────────────────────────────────────────────────
①  비일관     예외를 정식 취득 (92-99줄 — 사전등록 2회 측정 후 미성립. 절차는 밟았다)
②  비일관     **미결** — 607-614 자백이 "②를 면제할지 ⑤를 재측정할지" 를 안 정했다
⑤  비일관     미보유인 채 🟢   ← 자백의 대상
④  비일관     언급조차 없음
```
🟥 **초판이 여기서 «6행 중 일관 적용된 행이 없다» 고 적었는데, 바로 아래 자기 표가 그걸
반증했다**(Ⓑ 만족 · ③ 보유). 적대검증이 잡았고 정정한다. 그리고 초판은 ②를 **「면제」로 확정
표기**했는데, 자백 원문은 **미결**이다 — 절의 결론(«아무것도 정하지 않는다»)과 표가 어긋나 있었다.
🟥 **이건 오늘 이 저장소가 반복해 만난 «미측정을 0으로 접었다»와 다른 형태다** — 접힘이 아니라
**적용 누락**이다. 그리고 자백이 문서에 적혀 있는데 안 고쳐진 것은 「몰랐다」가 아니라
**「알고 미뤘다」**라서, 다음 라운드가 그 자백을 「이미 인지된 사항」으로 읽고 또 넘길 위험이 크다.

**처분(운영자 결정 필요, 여기서 확정하지 않음)** — 둘 중 하나여야 하고 셋째는 없다:
- **(A) §Gate-consequence 가 모든 🟢 를 구속한다** ⇒ ⑤ 는 과대 채점이고 재측정 대상이다
- **(B) advisory 다** ⇒ ②·④ 를 거기에 묶어서는 안 되고, ① 이 받은 «예외»는 애초에 필요 없었다

⚠️ 이 절은 **자백을 결정으로 바꾸지 않는다.** 지금 하는 것은 「미뤄졌다는 사실 자체를 기록해서
다음 라운드가 그것을 인지된 사항으로 소비하지 못하게」 하는 것뿐이다.

🟥 **그런데 그것만으로는 이 절이 자기가 진단한 실패를 반복한다 — 적대검증 지적, 수용한다.**
607-614줄의 자백도 **이 파일의 산문**이었고, 그 매체로 **이미 한 번 실패했다**(그래서 이 절이
있다). 같은 매체에 한 번 더 적으면서 앵커·기한·소유자를 안 붙이면 결과가 같다.
`CLAUDE.md §Mechanization Boundary` 가 **채널(«기록이 있는가»)은 기계화 대상**이라고 정한다.

⇒ **파일 밖 앵커를 건다**: 세션 카드(`tracks/_meta/reference_next_session_starter.md`)의
🧵 블록에 **«⑤ dominance 일관성 — 운영자 결정 대기 (제기 2026-08-17)»** 를 등재한다.
카드는 매 세션 시작에 읽히고 이 파일은 안 읽힌다 — 그게 차이다.
🟥 **이 등재가 없으면 이 절은 자백의 재생산일 뿐이다.**

---

## For a field harness (e.g. pmh, qasp)
Same gate, its own identities. A field harness ships to its team when its identity checklist is all-green,
certified by a **실증상세 (demonstration-detail) doc in that harness's own repo** — the QA certificate
listing each identity, its PASS criterion, and the artifact proving it. FH≡field parity: what FH proves
about itself, a field harness proves about itself, by the same method. (Company-residency: a field
harness's 실증상세 lives in its own private repo; FH holds only the method, never the field's evidence.)
