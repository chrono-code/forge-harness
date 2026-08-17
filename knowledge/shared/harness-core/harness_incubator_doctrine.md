# Harness Incubator Doctrine — intent machinization, the nursery, and compose ∪ disrupt

> Crystallized 2026-07-12 from an operator insight session ("the day FH stepped forward").
> This is the *why* underneath the four pillars in `README.md §What makes it a harness, not a toolbox`.
> Always-loaded summary: `CLAUDE.md §Identity`. Operating unit: `harness_6axis_framework.md`.

## 1. What a harness is — intent machinization

A harness is a platform that **reads a human's intent and forges it into a machined form**: either
*AI-salience* (rules and prompts an AI reliably follows) or *deterministic code* (hooks, scripts, gates
that need no model at all). Building a project IS machinizing human intent; a harness **accelerates and
amplifies** that machinization.

The trajectory is always the same four steps:

```
intent (human) → forge into an executable form (AI) → agreement (HITL) → machinery
```

**Agreement is a load-bearing gate, not a courtesy** — machinizing an unagreed intent hardens the wrong
thing. The HITL step sits immediately *before* machinization for exactly this reason.

### Trial-and-error relocates; it does not disappear

The harness's payoff is **less trial-and-error on the human side** — the request → feedback → regenerate
loop is skipped. But the loop is not deleted; it **relocates into the harness**, where agents and
sidecars run it in parallel. Two gains, not one:

1. Trial-and-error the human **does not perform** → human time drops.
2. Trial-and-error the harness runs **in parallel** → wall-clock drops versus sequential human retries.

What is freed is not only time but **attention** — and the quality gate (the responsibility-router
pillar) re-spends that freed attention only where a change is *irreversible*. "Time down + attention
routed to what matters" is the complete form of harness acceleration, and it is what "quality is the
lever; speed is the result" cashes out to.

## 2. The scale ladder — tool < star < galaxy

| Unit | What it is |
|---|---|
| skill / agent / plugin | a tool |
| **harness** (field harness) | a *star* — one project's tools, rules, gates, and memory bound into a single working body, purpose-built (e.g. a coding harness specialized for one product domain) |
| **meta-harness** (FH) | the *galaxy* the stars live in — and a **nursery**, not just a container |

A meta-harness is "a harness for building harnesses." Under a given theme it can machinize anything —
which is why its unit of work is the harness, not the skill.

## 3. The nursery — FH as field-harness incubator and simulator

**Origin layer (operator-forged, 2026-07-18)** — beneath the nursery frame sits the founding
observation: the defects and improvement points that many reviewers find *by hand over a long
time* can be found by an LLM running **many simulations**, compressing that labor by 99%+.
Incubation-acceleration is the natural extension of that single move, not a separate idea. The
resulting differentiator: **a solo developer can ship a product with frontier-grade robustness,
ready for immediate real use** — because the simulations exhaust the functional-defect space
before any human reviewer sees it, the human loop is freed to add *taste* (personal and
organizational judgment) rather than hunt bugs. First end-to-end instance: chamber run #9
(2026-07-18) — surveys, an N=50 concurrency chamber, three find-fix-regress defect cycles, and
a gated public release, in one session.

FH's dual role:

- **Primary — build and emit**: forge a field harness and release it as an independent, specialized
  unit. What ships today is the **scaffold + approval machinery** (Full-Harness Mode in
  `auto_project_mapping.md §6`, gate-compliant field scaffolds); the full simulate-then-emit chamber
  flow is the *named target*, practiced to date as dogfooding a capability inside FH and then landing
  it in the field repo.
- **Contingency — act as the field harness itself**: run the whole of FH (harness-unit, not
  skill-unit) as a sandbox simulator for a project. Expensive per run — that is the price of a
  general-purpose chamber.

**Completeness requirement**: a nursery that can birth any star must hold every element. "Everything a
field-harness simulator needs must be possible inside FH" — multi-model dispatch, tooling, live-surface
operation, gates. This is an *aspiration that directs capability assembly* (what `goal-quench`'s
assembly ladder points at), not a claim of current completeness.

**The economics (why expensive-per-run is cheap-in-total):**

```
Option A: build N field harnesses separately, each doing its own trial-and-error
          → the same errors are repeated N times; learning is never shared
Option B: incubate each field project inside the FH chamber
          → trial-and-error pools in ONE place and compounds (the self-evolving loop)
          → each next project inherits the previous learning → total trial-and-error shrinks
```

FH's sandbox unit cost is higher (general-purpose overhead), but total portfolio cost is *expected* to
be lower — when reuse amortizes the chamber overhead. Honest trade-off: it is expensive *until
emission*; the emitted harness is specialized and cheap, and the learning stays in FH. **Evidence grade
(stated honestly)**: this economics is a *design argument plus n=1*, not a measured comparison — the
counterfactual (building the same capability standalone) was never run, so "cheaper in total" is a
**named bet**, the same treatment the disrupt path gets in §4(c); residual risk: one-off projects that
never recur may not amortize. Empirical grounding for the *capability* (not the cost comparison): a
field QA harness's acts 2–3 arc (2026-07, private) — its live-run capability was forged inside the FH
chamber, then landed in the field repo.

**Minimal execution skeleton (when the operator accepts simulate-first)**: the procedure is currently
*judged/ad-hoc*, standardization deferred to a second real occurrence (measured-trigger, per the
evidence-threshold build discipline): ① open a chamber workspace (a worktree or `tracks/_chamber/{project}/`
— never a real project repo; the underscore prefix rides the onboarding carve-out for meta dirs
(any `tracks/_*` dir — general rule, stated as such in the branch tests), so a **chamber run** never
registers as a mapped project and never pollutes the returning-menu door counts — a
`tracks/{project}-sim/` path would); ② scope the run through `goal-quench`'s budget
gate (chamber runs are the expensive path — cap them); ③ drive the simulation with existing FH assets
(dispatch, gates, live surfaces as needed); ④ the **Emission Gate** — the emit judgment "the simulation
holds" — is a *judged* call paired with the run's own mechanical evidence (tests passing, gate verdicts,
reproduced flows), decided **with the operator (HITL)**; ⑤ on emit, route by candidate class: a **field
harness** goes through Full-Harness Mode / field scaffolds (`auto_project_mapping.md §6` — that mode is
this chamber's field emit terminus); an **FH-internal utility** (a skill/script/rule, not a standalone
field harness) instead routes through the **New-Skill Pre-Commit gate + `asset-placement-gate`** (the
same gate every FH asset passes). KILL emits nothing — the workspace stays as the evidence record.

> 🟥 **2026-08-17 이후 이 문단은 단독으로 읽으면 틀린다.** 아래 «clears **all four**» 중
> **(1) net-new 는 더 이상 KILL 사유가 아니다**(→ `CURATED` 라우팅) — §3-SCREEN-2026-08-17 로
> 대체됐고, (2) 는 `NOT-APPLICABLE` 라우팅이다. **(3)·(4) 는 KILL 로 그대로 유효하다.**
> 아래 본문은 그 정정 이전의 원문이며 이력으로 보존한다.

**EMIT-worthiness — the measured screening criterion (runs #5–#6, 2026-07-14)**: six chamber runs, EMIT
0/6, all KILL. A candidate is emit-worthy only if it clears **all four** of — (1) **net-new** (not a
reinvention of an existing FH/official asset, nor a cosmetic re-wrap of code that already ships — runs
#2–#4 died here, and run #6 partially here too — its core was already conceived in a parked FH signal);
(2) **artifact-shaped** (a tool/script/rule that stands alone, *not* a judgment-method — run #5's genuine
niche was real, but its value lived in a scan∪cross-family *lens*, i.e. an LLM judgment, which cannot be
`npm publish`ed); (3) **real-code/real-data-precision-adequate** (its mechanical form, measured on real
external inputs, does not cry-wolf — run #5's rule scored 5/5 false-positive on 111 real files; run #6's
heuristic scored 14/22 false-fire on a real sibling-folder scan); (4) **hub-state-independent** (run #6,
new axis — a capability whose value structurally depends on hub-held state, e.g. the curated registry +
company-residency knowledge, is not a standalone-first candidate: run #6's `harness-orchestrator` hit
private/company repos it structurally could not know to suppress, because residency knowledge lives only
in the hub. Contrast with fh-commons's 4 skills, which graduated cleanly to portable precisely because they
never depended on hub state). 0/6 candidates cleared all four. This is not "keep trying" — it is a
**pre-screen for future candidates**, cheapest-to-costliest: (1)/(2)/(4) are cheap to predict from the
candidate's own design (does it need hub-only knowledge to work correctly?); only (3) needs a measurement
leg (a real-input precision run), which runs #5–#6 established as the decisive test. The chamber's honest
value to date remains *screening* — preventing reinventions, low-precision births, and premature
standalone graduations — not yet *birthing*. **Graduation order** (run #6's positive finding): a
hub-state-dependent capability graduates hub-internal → proven in use → THEN extracted portable, never
speculated standalone-first — the only path every successfully-portable FH asset actually took.

---

### 🟢 §3-SCREEN-2026-08-17 — **(1) net-new 는 더 이상 KILL 사유가 아니다** (운영자 결정)

> *"사람들이 자신이 구상한 하네스를 인큐베이팅으로 해서 출하하려는데, 그럴 때마다 항상
> **«이미 있는 기능이야»라고 리젝시키면 쓰고 싶은 생각이 들까?** 그것보다는 «이미 이러한
> 레퍼런스가 있는데 **너만의 방법으로 커스터마이징하고 싶다면 여기서 출발해보자**»가 되어야 할
> 것 같아. **인큐베이팅이 필요없다면 큐레이팅으로 가면 되는 거고.**"*
> · *"**그 사람이 만들려는 걸 인큐베이터가 막을 필요가 있을까. 그냥 만들게 두면 되지.**"*
> · *"인큐베이터는 **훈수를 놓게 하기 위한 장치가 아니라**, 원하는 프로젝트나 하네스를
> **출하 전부터 미리 굴려보고 사용해보게 하는 에뮬레이션**과 그로 인해 자신만의 것을
> **성숙하게 출하시키기 위한 장치**"*

**바뀌는 것 — 기준은 남고, 그 기준의 «판정 결과»가 바뀐다:**
```
전       net-new 미달  →  KILL          (후보가 회수된다. 사용자는 빈손으로 돌아간다)
후       net-new 미달  →  **CURATED**    (선행 목록 + 가장 가까운 것 + 그것이 안 덮는 델타를 준다)
                          → 사용자가 «그거 쓸게» 면 거기서 끝(큐레이팅 종료)
                          → 사용자가 «내 걸 만들래» 면 **인큐베이터로 들어간다**
```
🟥 **전환점은 판정이 아니라 의사다.** 인큐베이터는 「이게 새로운가」를 묻지 않고 「너 만들 거냐」를
묻는다. 그리고 선행 목록은 **회수 통보가 아니라 재료 목록**이다 — 아래 §3-SCREEN-b.

🟥 **초판이 여기서 게이트를 무력화했고, 적대검증이 커밋 전에 잡았다. 그 정정을 남긴다.**
초판은 «진짜 KILL» 을 셋으로 줄이며 **(3) 을 「precision 을 만들 수 없음(원리적 불가)」으로
바꾸고 (4) 를 「형태 라우팅」으로 격하**했다. 둘 다 틀렸다:
- **(3) 의 원문은 «원리적 불가» 가 아니라 «실측 미달» 이다** — *"run #5's rule scored **5/5
  false-positive** on 111 real files; run #6's heuristic scored **14/22 false-fire**"*.
  초판 문장대로면 **런 #5·#6 이 KILL 이 아니게 된다**(둘 다 precision 을 *만들 수는* 있었다).
- **합산이 진짜 문제였다**: 이 절이 챔버의 실증된 값어치를 셋으로 적는데
  (*"preventing **reinventions** · **low-precision births** · **premature standalone
  graduations**"*), 초판이 재발명→CURATE · (3)→원리적불가 · (4)→형태라우팅 으로
  **셋 다 뺐다.** 남는 entry 스크린이 「사용자가 만들겠다고 하나」 하나뿐이 됐다.

**그래서 이렇게 정리한다 — entry 와 exit 를 섞지 않는다** (§3-c 가 *"two different questions,
**do not merge them**"* 이라고 명시한 그 분리):

```
── ENTRY (들어갈 때, 이 절) ──────────────────────────────────────────────
 (1) net-new 미달        → **CURATED**  라우팅. KILL 아님 (§3-SCREEN-2026-08-17)
 (2) artifact-shaped 미달 → **NOT-APPLICABLE**. 판단-방법은 이 인큐베이터의 산출 형태가 아니다
 (3) precision **실측 미달** → **KILL 유지** 🟥 «못 만든다» 가 아니라 «돌려봤더니 나빴다» 다
 (4) hub-state 의존       → **KILL 유지** 🟥 premature standalone graduation 방지가 이 축의 일이고,
                            §3 말미의 Graduation order(hub-internal → proven → extract)가 그 처방이다
 ★ 사용자가 «안 만들래»    → **종료**(큐레이팅으로 끝. KILL 원장에 세지 않는다)

── EXIT (나올 때, §3-c) ──────────────────────────────────────────────────
 «설 수 없다»(inability-to-run) → **KILL**.  약함은 KILL 아님(§3-c ④)
```
🟥 **원리적으로 precision 을 만들 수 없는 대상**(판별 쌍을 구성할 수 없는 것)은 KILL 이 아니라
**`NOT-APPLICABLE`** 이다 — 후보의 실패가 아니라 **이 인큐베이터의 바가 안 맞는 것**이다.

⚠️ **§3-c 의 한 문장이 이 정정으로 갱신된다**: *"clear this one and fail the first
(**alive, but a reinvention**)"* — 그 분기는 이제 KILL 이 아니라 **CURATED 로 라우팅**된다.

**⚠️ 경계가 사라지는 것은 아니다.** 재발명이라는 *사실*은 여전히 측정하고 기록한다. 바뀐 것은
그 사실을 **누구에게 무엇으로 주느냐**다: 게이트의 판정 근거 → 제작자의 출발점.

### §3-SCREEN-b — **선행은 재료다** (인큐베이팅 가속화, 운영자)

> *"앞서 찾았거나 정말 새로운 거라면 검색한 레포 중에서 **배워올 만한 것들을 일부만 빌려와서
> 개발해 나가는 것**이 곧 인큐베이팅 **가속화**의 방법이 되기도 하겠지. 제로부터 자신만의
> 아이디어만으로 하는 게 아니라 **프런티어에서 배워옴으로서 시작점부터 프런티어급 가능성을
> 품은 채 태어나게 하는 것.** 개발자들이 코드를 다 새로 짜는 게 아니라 **구글링하는 전통**이
> 있던 것처럼."*

🟥 **가장 날카로운 형태**: **재발명 위험이 높다는 것은, 그만큼 빌려올 선행이 많다는 뜻이다.**
옛 taxonomy 는 이것을 **거꾸로** 읽었다 — 재료가 풍부할수록 죽였다.
```
전    레퍼런스 발견 → KILL 근거   → 배출 확률 0 · 사용자는 빈손
후    레퍼런스 발견 → 빌드 재료   → 시작점부터 프런티어급 · 사용자는 목록을 들고 간다
```
**같은 정보, 소비처만 바꾸면 정반대로 작동한다.** 그리고 이건 §3-c 의 EMIT 바(«설 수 있나»)를
**더 쉽게 넘게 만든다** — 즉 큐레이팅은 인큐베이팅의 **관문이 아니라 성공률을 올리는 장치**다.

**실물 대조(챔버 런 #13 `n-eff-probe`, 2026-08-17)**: K1(재발명)으로 KILL 됐고, 그 근거였던
선행 5건(capture-recapture · double-fault measure · Snyk VulnBench · BenchGuard · SAST overlap)은
새 taxonomy 에서 **부품 목록**이다 — 통계량은 기성품을 쓰고 새로 만들 것이 「크로스-노드 배선 +
픽스처」 하나로 줄어든다. **판정을 소급해 무르지는 않는다**(사전등록 원칙). 바뀐 것은
**다음 후보가 같은 자리에서 어떻게 처리되는가**다.

> **정본**: `tracks/_meta/fh_signal_2026-08-17_incubator-is-not-a-gate.md`
> — 흐름 전체 · 큐레이팅의 자리(⑤ 증폭자) · 진입로 B(축적 기반 제안) · 원장 과소계상 실측.

**Chamber scope — what belongs in the chamber at all (run #7, 2026-07-14)**: run #7 tested a hub-internal
reactivation of the cluster-wizard signal and KILLed it — decisively on its own merits (its "narrow
net-new" claim collapsed against the real shipped registry and an already-existing synergy skill), but
it also surfaced a scope question worth keeping regardless: **a small feature graft onto an
already-shipped hub-internal mechanism is ordinary Mode D self-development under the 4-axis gate, not
automatically a chamber-EMIT question.** The chamber screens candidates that would become a **new
independent artifact** (a skill, a plugin, a standalone tool) — not every internal feature extension.
Route by this test: *would this, if built, be net-new as a standalone thing someone installs/adopts, or
is it two lines added to something already shipped?* The former is chamber-scope; the latter is ordinary
self-dev review.

*Vocabulary reservation (term hygiene, not standardization)*: a run of this skeleton is a **chamber
run** — going forward, run/workspace/log labels use "chamber" for incubation and keep "sim/simulation"
for *verification* sims (target-tier blind sim, sim-conductor persona sims). Established names are
grandfathered, not renamed: the Autopilot branch stays **simulate-first**, and this section's
"simulation holds" phrasing stands — the reservation governs new labels (grep keys), not existing
doctrine prose. The Emission Gate and chamber-run labels exist so a second real occurrence is
recoverable from logs; the procedure itself stays evidence-gated as above.
*Routing baseline (measured)*: the Autopilot's simulate-first routing branch passed a Step 0.5
trigger-accuracy probe 2026-07-13 — 10/10 blind Sonnet sims (5 should-fire incl. 2 borderline, 5
should-not-fire incl. 3 borderline near-misses), 0 malformed verdicts. Scope honestly: an
authored-case baseline (single-draw per case; reps waived per measurement-integrity since every
first draw matched expected — see the 2026-07-13 subagent-invocations log entry), not a calibrated
accuracy estimate.

### 3-a. What is born, and what it must be able to do on day one (operator-forged, 2026-08-09)

**We are not raising a person. We are shipping a harness that does one thing well.** The founding
image is a calf or a foal: it is born in a laboratory sense — brand new, thin, nowhere near an adult
— but it **stands and walks in the place where it was born.** That is the incubator's bar, and it is
much lower and much clearer than "finished."

```
depth / density   altricial  — like an infant. Filled in only by real use. Takes a long time.
basic locomotion  precocial  — like a calf. Works from the moment it is set down.
```

The two axes are independent, and confusing them is what made this look far away. Aiming at an adult
(a complete judgment circuit at birth) is **not merely slow — it is unreachable**, because density is
supplied by usage that has not happened yet. Aiming at a calf is reachable today.

**Operational form**: *born walking* = on the first run, with the user adding nothing, the thing
produces something useful. This maps onto the existing rungs without inventing a scale —
`🔵 RC` = it stood up in the lab; `🟢 REALIZED` = it walked outside.

**The opposite of this doctrine has a name we already use: `built-but-not-wired`.** A harness that
was born but does not walk is one whose parts exist and whose call sites do not — measured instances
exist (a field harness with a judgment-circuit file and **zero callers**; a sibling meta-harness with
none at all). So *"born walking"* is not a metaphor about vitality; it is the engineering claim that
**wiring is part of the birth**, not a follow-up task. Being born and running are different events,
and the incubator is answerable for the second.

#### What the seed contains — a coordinate system, not a declaration

The seed is **not** an identity sentence. `"You are a world-class QA expert"` is an artifact of the
prompt-engineering era and is actively harmful here: the 105-run measurement scored a bare identity
declaration as a **net loss on the weak tier** (removing it recovered +0.67), while a judgment
circuit gained on the frontier tier. Told only *what it is*, a newborn harness still does not know
what to do, and the gaps show up as arbitrary decisions.

What a newborn actually needs is closer to *how to see, how to walk, how to speak*:

| Layer | What it fixes | Note |
|---|---|---|
| **Seeing** | what counts as a signal at all | inputs — without this the circuit has nothing to run on |
| **Judging** | success · which way to lean under uncertainty · out of scope · never | = the `judgment-circuit` definition |
| **Speaking** | how it reports, what shape its output takes | outputs |
| **Walking** | how it actually executes | wiring, call sites |

Shipping the middle layer alone is the common failure: the circuit is present and has no input or
output attached, which is exactly the zero-caller symptom above. **Form is machine-checkable today**
(`scripts/judgment_circuit_lint.sh` — branch rules, self-sealing, conflict resolution, lean
direction, mandated shape; FH's own `CLAUDE.md` measures `CIRCUIT 4/5`). Density is not, and should
not be given a scale yet — see 3-a-2.

#### 3-a-1. Field ⊥ meta — and meta is out of this incubator's scope

The two kinds have **opposite profiles**, which is why one method cannot birth both:

```
field harness   hard to birth (design · seed · wiring)   │ walks on day one      precocial
meta harness    easy to birth (a declaration starts one) │ needs endless tending  altricial
```

A meta-harness cannot clear a bar that reads *"walks on day one"* — not because it is worse, but
because unbounded growth is its point. FH itself is the standing evidence: it is tended continuously,
by design. ~~**Therefore a meta-harness candidate is not a chamber candidate.**~~

### 🟥 §3-a-1-2026-08-17 — 위 결론 문장은 **폐기한다. 범위가 과했다** (운영자 결정)

**폐기 사유 ① — 아래쪽 범위는 이미 넓혀져 있었고, 이 파일이 그 확장을 반영하지 않았다.**
`ship_readiness_gate.md §Ⓑ-layering`(2026-08-16, 운영자 발화 기반)이 ② 의 범위를 이렇게 적는다:
> *"② 프로젝트 인큐베이터 | **유닛을 낳는다 — 하네스만이 아니다.** … 범위가 **하네스 · 스킬 ·
> 에이전트** · 하네스 형태가 아닌 일반 레포까지다"*

🟥 **초판은 이걸 «8일 전에 뒤집혔는데 안 고쳐졌다 = half-fix 전파 결함» 이라고 적었다. 틀렸고,
적대검증이 잡았다** — 그 줄이 넓힌 것은 사다리의 **아래쪽**(스킬·에이전트·일반 레포)이고,
폐기 대상 문장은 **위쪽**(meta-**harness**)에 대한 진술이라 **둘은 논리적으로 양립한다**
(하위를 포함한다고 상위가 포함되지 않는다). 게다가 그 줄에 **「md 규율」은 없다** — 그건
2026-08-17 운영자 발화에서만 나온다. **결함 귀속을 철회하고 사유를 약화한다**: 뒤집힌 게
아니라 **범위 확장이 이 파일에 반영되지 않은 것**이다. (그리고 폐기 자체는 사유 ③ 으로 선다.)

**폐기 사유 ② — 논거가 실제로 덮는 범위는 «하네스 급» 뿐이다.**
위 논거는 *"unbounded growth 가 본질이라 day-one walk 를 못 넘는다"* 인데, 그건 **meta-harness**
에 대한 진술이다. 스킬 · 에이전트 · md 규율은 **day-one walk 가 가능하다 — 🟥 단 미검증이다.**

⚠️ **초판은 «실제로 넘고 있다» 고 적었는데 근거가 없었고, 반례가 같은 레포에 있다.**
day-one walk 의 정의는 *"on the first run, with the user adding nothing, the thing produces
something useful"* 이고 반대말이 `built-but-not-wired`, 그리고 *"**wiring is part of the birth**"*
다. **md 규율은 구조적으로 호출부가 없다**(살리언스). 실제 반례:
`.claude/rules/fh_4axis_gate.md` 의 `standpoint:` 필드 — *"Still validated by nothing — zero hook
lines, no fixture suite"* 였고, `tier1b` 등급이 **없어서 정적 리뷰가 tier2 로 기록**됐다.
`axes-run` 기호 키도 53건 중 2건이 옛 의미로 쓰였다. **태어났고 안 걸은 md 규율들**이다.

⇒ **유닛 클래스별 day-one walk 판정자를 따로 건다**:
```
스킬 · 에이전트   첫 런에서 사용자가 아무것도 안 더하고 쓸 만한 산출이 나오는가
md 규율          🟥 **블라인드 floor-tier sim 이 실제로 그 규율을 발화하는가**
                 (CLAUDE.md §Skeleton, Not Muscle — "done 은 블라인드 세션이 실제로 발화하는 것")
```

**폐기 사유 ③ — 그 셋이 이 인큐베이터의 최대 산출이다** (운영자, 2026-08-17):
> *"**FH 의 스킬 상당수는 후자식(축적 기반)으로 만들어졌고** 전자도 거기에 해당하지.
> FH 스킬은 **내 아이디어로 발명**한 거니까."* ·
> *"인큐베이터의 **최대 레버는 하네스**이지만 그 **하위의 것들은 다 포함**된다.
> 스킬 · 에이전트 · **md 규율** 등…"* ·
> *"인큐베이션 대상은 마감시점 정리 시 **FH 자체가 될 수도 있다.**"*

### 🟥 그러면 경계가 필요하다 — 판별 기준 (운영자)

경계 없이 폐기만 하면 인큐베이터 정의가 **«FH 가 한 모든 것»**이 되어 계상이 무한대가 되고,
그건 1건만 세는 것과 똑같이 못 쓴다. 기준은 이것이다:

> *"**스킬 없이도 FH 는 동작하지만, 그걸 단축시킬 유닛을 낳은 것까지는 인큐베이팅으로 봐야
> 한다.**"*

```
❌ 「FH 가 그 일을 했나」          — 이러면 전부가 인큐베이팅이라 측정 불능
⭕ 조건 1  「그 일을 **단축시키는 유닛을 낳았나**」
⭕ 조건 2  「그 유닛이 **자기 소비처를 새로 갖는가**」 ← 🟥 **크기 축. 둘 다 필요하다**
           (별도 레포 · 플러그인 엔트리 · 독립 호출면 — «호출부가 새로 생겼나»)

범위   하네스 ← 최대 레버
         ⊃ 스킬 · 에이전트 · **md 규율**
         ⊃ 하네스 형태가 아닌 일반 레포
```
🟥 **조건 1 만으로는 계상이 무한대가 된다 — 적대검증이 반례를 냈다.**
> `templates/.git-hooks/pre-commit` 에 필드 검사 한 줄 추가 → ⓐ md 규율이고 ⓑ 그 일을 단축시키고
> ⓒ 「유닛」으로 셀 수 있다 = **세 조건 충족.** 그런데 그건 평범한 Mode D 자기개발이고
> **4축 게이트가 이미 관할한다.** 여기에 «대상이 FH 자체일 수 있다» 가 붙으면
> **모든 FH 세션의 대부분 커밋이 인큐베이팅**이 된다.

**조건 2 가 그걸 자른다**: 기존 훅에 줄을 더하는 것은 **소비처가 이미 있던 것**이라 탈락하고,
`dashboard-dev`·`ko-tech-writer`(플러그인 엔트리 신설)·`the-bible`(별도 레포)은 통과한다.
**「일을 했다」와 「유닛이 태어났다」를 가르는 것이 조건 1, 「유닛」과 「기존 것의 확장」을
가르는 것이 조건 2** 다.

⚠️ **그래도 남는 잔여**: 조건 2 는 「소비처가 새로 생겼나」라는 **사후 관측**이라, 만드는 중에는
판정이 유보된다. 사전 판정이 필요하면 «이것이 태어나면 어디서 불리는가» 를 INTENT 에 적게 하는
것이 대응이지만 **미구축**이다.

### 위 ⚠️ 회고 관찰은 어떻게 되나 — **재분류하되 폐기하지 않는다**

아래 회고 관찰(«KILL 된 것 중 chamber-internal metering · hub-internal orchestration ·
cluster wizardry · org relay 는 meta-shaped 였다»)은 **여전히 유효한 관찰**이다. 다만 그
처분이 바뀐다: **「스코프 밖이라 KILL」이 아니라 「meta-*harness* 급이라 day-one walk 바를
다르게 받아야 한다」**이다. `NOT-APPLICABLE` 분리(아래 문단)는 그대로 필요하고, 오히려
이 정정으로 **더 필요해진다** — 이제 통이 셋이다: `KILL`(못 선다) · `CURATED`(선행이 있다,
§3-SCREEN-2026-08-17) · `NOT-APPLICABLE`(meta-harness 급이라 이 바가 안 맞는다).

⚠️ **Retrospective observation, not a finding.** Re-reading the run ledger along this axis: of the
KILLed candidates, those aimed at chamber-internal metering, hub-internal orchestration, cluster
wizardry and org relay are all **meta**-shaped, while the single EMIT (`forge-wiki`) is **field**-shaped
— a tool that does one thing. If that holds, several KILLs were not the chamber being strict but
**the wrong kind of candidate entering it**. The classification was made *after the fact* by the same
session that proposed the axis, over n=9; it is a hypothesis to pre-register and predict against, not
a result. The way to test it is to fix the classification first and call the next run before its
verdict — the ordering witness now makes that checkable.

**Proposed consequence (not yet applied)**: give the chamber's entry reason a field/meta axis and
retire meta candidates as **`NOT-APPLICABLE`** rather than `KILL`. Today both land in the same bucket,
so when the ledger says *"the chamber screens"* it is summing two different events.

#### 3-a-2. Density is measured by comparison, never by an absolute scale

Density — how filled-in a circuit is — has no honest unit. Counting clauses, counting cases, or
counting how often the circuit answers all measure different things, and picking one invites the
failure where a metric scores presence instead of the relation it was meant to capture. The way
around it is to **not define the unit**: clone versions (seed only / seed + some usage / seed + more)
and run them against one task set **in parallel**, then read the *shape of the curve* rather than any
version's score. **Where the curve flattens is the interesting point** — that plateau is the practical
floor for "enough of a soul."

Two conditions carry over from the decorrelation work: the clones must be **independent** (run
sequentially in one context and the earlier one bleeds into the later), and the **scorer must be a
different party than the forger**.

🟥 **Named limit — synthesized history yields synthesized density.** Density is defined as accruing
from *real* use; injecting simulated usage into a clone measures something else, and it can fill in a
different direction than real use would. So the question this experiment can answer is narrowed on
purpose: **not** "does the soul grow?" but **"if it grows, where does it plateau?"** That is enough
for a minimum-condition verdict and does not overclaim.

Internal version comparison gives a **growth curve**; comparison against an outside harness gives an
**absolute position**. Both are relative, but their reference points differ — and they can share one
task set, which lets a standing external dominance pre-registration ride along instead of waiting.

### 3-b. The nursery also verifies what it births

The incubator's arc does not end at emission: FH **reviews, accelerates, and verifies** the harnesses
it births or adopts — a verification axis attached to the nursery as an evidenced path (field→meta
reverse-verification arc, 2026-08-01: a field QA harness's doctrine audited the meta-harness itself,
N=2 subjects). Boundary rule for that axis: *harness-verification core = the FH-native
triad-consistency lens (spec ↔ implementation ↔ TC), askable with no cluster member present;
extended = cluster instruments (trace auditors, process-fidelity harnesses), composed by UNION.*
Full doctrine: `harness_verification_core_extended.md`.

**Incubation unit — projects AND features**: incubation applies not only to new projects but to **new
capabilities of an existing harness**. A field harness's self-development is itself run inside the
meta-harness chamber first, then transplanted — the nursery forges new layers for existing stars, not
only new stars. Same economics.

**Simulate-first entry**: when a new project is uncertain, exploratory, or failure-expensive, the
recommended path is *simulate inside the chamber first, then emit the initial model* — not
build-immediately. (Wired as a recommendation branch in `CLAUDE.md §Onboarding / Acceleration
Autopilot`; build-immediately remains correct for clear, small, low-failure-cost projects.)

### 3-c. The EMIT bar — «walks on its own» (operator-forged, 2026-08-16)

> **Relationship to §3's EMIT-worthiness criterion — two different questions, do not merge them.**
> That one screens candidates *going in*: is this worth emitting at all (net-new · artifact-shaped ·
> precision-adequate). This one judges a candidate *coming out*: is it ready to stand. A candidate can
> clear the first and fail this one (worth building, not yet alive), or clear this one and fail the
> first (alive, but a reinvention). Both are required; neither substitutes.

Until now the chamber's EMIT threshold was **implicit**, and that is why its record (9 runs,
8 KILL, 1 EMIT) could not be read: with no stated bar, "screened well" and "over-screened" are
the same picture. An instrument whose output is almost always one value is indistinguishable
from an instrument stuck on that value — the dead-control signature this repo keeps re-finding.
The bar is therefore stated, and stated **low on purpose**:

> **A candidate EMITs when it can stand on its own — not when it is good.**
>
> ① It **runs standalone**, with no defect severe enough to prevent execution.
> ② Every necessary function **fires at least weakly**. Firing, not performing.
> ③ It is in a state where it can **fill itself in through back-and-forth with a human**.
> ④ **Weakness is not a KILL.** Only inability-to-run is.

Newborn-foal semantics: it staggers, and it is standing. Shortcomings are expected and are the
*point* — an emitted harness is raised, not delivered finished.

**The mechanical discriminator, and it is already in hand.** ② is not a judgment call, because
"fired weakly" and "did not fire" separate cleanly at the exit boundary:

```
dead   — dies before doing anything             e.g. a gate that aborts on its own version line (rc=1)
alive  — ran and returned a TYPED verdict       e.g. the same gate returning HARNESS_ERROR (rc=10)
```

`HARNESS_ERROR` is a *bad* result and it satisfies ②: the unit ran and said why it could not
finish. `rc=1`-before-anything is not a weak firing, it is absence. This is the same
`not found ≠ 0` line the rest of this repo runs on, applied to birth.

**Where the judgment must happen: outside the author's environment.** Measured 2026-08-16 — a
gate suite read 31/31 green in the harness that wrote it and was structurally dead in the sibling
that inherited it, because the author's repo happened to supply a file the code assumed. An EMIT
verdict rendered inside the incubator's own environment cannot see that class at all. So the EMIT
check is run the way a recipient would run it: a clean checkout, none of the author's local state,
each declared function exercised once.

**Calibration owed, not claimed.** This bar makes the chamber testable for the first time; it does
not retroactively validate the existing ledger. The 8 KILLs were decided against an unstated bar,
so whether each died on "cannot run" (correct) or on "weak" (over-screen) is **unknown from the
record**. Known-pair to run before the ledger is cited as evidence of anything: a known-positive
(a field harness the operator judges already stands on its own) must EMIT; a ledger KILL whose
recorded reason is explicitly *cannot run* must KILL. If the known-positive is KILLed, the
instrument over-screens and every prior KILL is weakened by that much.

### 3-d. What separates incubating from boosting — the AUTHORITY, not the effort (operator, 2026-08-16)

Operator, verbatim: *"부스팅보다 인큐베이터의 장점은 그 레포 전체(또는 출하하기 전 상태의 플젝)를
FH가 감싸서 **모든 것을 만들어내고 재설계한다**에 있어. 그래서 모든 것을 빠삭히 알아야 하고,
그러면서도 **모든 것을 조작할 수 있는 권한**이 있는 거야. 부스팅과는 다른 지점이 이것이기도 하다."*

The two identities are not «small help» vs «big help». They differ in **scope of authority over the
target**, and the two properties are a matched pair — neither is optional:

| | Ⓑ Project Booster | ② Project Incubator |
|---|---|---|
| Touches | the point that was asked about | **the whole repo — including redesigning what already works** |
| Must know | enough for that point | **the entire target, thoroughly** |
| Reads the codebase | on demand, to answer | **as a precondition, before proposing anything** |

**Why the pair is load-bearing**: total authority without total knowledge is vandalism, and total
knowledge without authority is a booster that reads a lot. An incubation session that has not read
the target's design canon, gate code, and existing verification surfaces has not *earned* the second
column — and the correct move there is to read first, not to scope down to a booster-shaped change
and call it incubation.

**Where this bit, same day**: the-bible's ⓐ run scoped itself to «invariant-preserving» — correct as
a *choice the operator made for that request*, and it was then mistaken for the identity's own reach.
It is not. ⓐ/ⓑ is the operator setting the blast radius for one job; the incubator's standing
authority is the full repo either way. A session that reads a per-request scope as the identity's
ceiling will never propose the redesign that was the point of incubating.

**Relationship to 3-a's «day one» bar**: 3-a says what the *born thing* must do. This says what the
*nursery* is allowed to do to it while it is still inside. The first is an exit condition; the second
is a working posture.

## 4. Compose ∪ disrupt — two operating modes over other harnesses

| Mode | What | FH mechanism |
|---|---|---|
| **Compose** (additive) | cluster leading harnesses, gather their strengths at optimized token cost | sidecar / multi-harness orchestration |
| **Disrupt** (transformative) | dismantle them into parts, overcome-and-adopt their weak points into FH or a target field harness; self-destruct and reassemble to go where others cannot | **crucible mode** (`crucible_mode.md`) — total-ingest → melt via steel/phantom-quench → identity-bond → reforge; **core invariants never melt** |

Theory anchor (an operator-supplied analogy drawing on Clayton Christensen's disruptive-innovation
thesis): disruptive technology tends to emerge from re-purposing existing parts
for unintended uses — crude and inefficient at first, then growing fast along a dimension incumbents
overlooked. Mapped here: "re-purposed parts" = other harnesses dismantled into components;
"the overlooked dimension" = the direction others cannot go. Companion criterion,
**fitness-for-purpose**: equipment that is well-made but would not survive *this* dragon is better
re-forged from scratch than patched.

Honest boundaries: (a) core invariants (floors, gates, identity) are never melted; (b)
overcome-and-adopt is curation with license/provenance respect, never wholesale copying; (c) the
disruptive path *looks inferior early* — running it is a deliberate bet, named as such.

### 4-b. Boundary crossing — what actually flows between harnesses

Compose and disrupt say *what FH does to* other harnesses. They do not say **what moves across the
boundary, or what must not**. That gap is where the value of the **harness cluster** (identity ①; renamed from "multi-harness cluster" 2026-08-16 — "multi" and "cluster" both meant plurality) is won or lost, so
name it: a harness that only deepens its own well stays blind to what the neighbouring well knows —
one harness sees runtime behaviour and not source structure, another sees source structure and never
runtime. **The meta-harness's job is not to dig a deeper well; it is to make outputs flow across the
boundary between wells.**

### 4-c. The return leg, and why the cluster exists at all (operator, 2026-08-17)

§4-b says outputs **flow across** the boundary. It does not say what happens to what flows *in*,
nor why FH pays for the crossing. Both were load-bearing and neither was written down. Operator's
formulation, in three parts — and the third is the one that makes the first two a strategy rather
than a nice habit:

```
1  BORROW-EXECUTE (standing)   FH does not endlessly BUILD the capability it lacks.
                               It reaches into a cluster harness and RUNS theirs.
2  INTERNALIZE (selective)     Of the insight that comes back, only what is genuinely worth
                               adopting is PROPOSED and absorbed. Never automatic.
3  THE POINT IS TIME           Not capability breadth. What FH buys by not-building is time to
                               sharpen its OWN edge — and that is what lets it keep pace with a
                               fast-moving model layer instead of being outrun by it.
```

🟥 **Without (3), (1) inverts on reading.** "We borrow instead of building" reads as *"FH need not
have capabilities"* — which turns the cluster into dependency. The operator's claim is the opposite:
**borrowing is how FH protects its own sharpness.** State (3) whenever (1) is cited.

**The asymmetry in (2) is the whole filter.** Borrowing is constant; absorbing is rare and gated by
a proposal. Automatic absorption produces a collage of other harnesses' capabilities wearing FH's
name — the exact opposite of (3), because a collage has no edge to sharpen.

**First recorded run of the full loop (2026-08-17, gstack → qasp, FH as governor).** FH did not
build a DX/product lens; it stood up the gstack persona (`/plan-devex-review`, `/qa-only`) against a
qasp change and observed. The review returned three findings FH's and qasp's lenses structurally do
not ask (guide-promises-vs-delivered-bundle · the shipped document's readability · release-doc
drift). Then the filter ran, and **it rejected more than it accepted**:

| finding | disposition |
|---|---|
| anchor should be *discovery-based*, not a hand-kept list | **rejected** — measured against FH and the transfer did not hold; a control showed the suites believed unwired do run by another path |
| guide promises ≠ delivered bundle | **rejected** — `package_coverage_check.sh` already covers it |
| release docs did not follow | **rejected** — §④-b entry-point drift covers half; not enough delta |
| **a shipped document is never read as a reader before it ships** | **accepted** — and NOT because gstack said so: FH reached the same place independently the same day from a different axis, recording that *"readability is measured only by rendering it or by a person; a static scan catches what is ABSENT, never what is UNREADABLE"* with 12 findings and **0** caught by static scanners. **Two independent arrivals is the internalization signal.** One source alone leaves it a candidate. |

⚠️ **Honest scope**: one run, one target, one third harness. This is an existence proof that the
loop closes, not a rate. And the filter rejecting 3 of 4 is the expected shape — if it accepted
everything it would not be a filter, it would be a funnel.


Three rules, in falling order of how easily they are broken:

1. **Crossing must not overwrite the receiving harness's identity.** If harness B is deliberately
   black-box (it verifies only what a user could observe), pushing A's white-box artifacts into B does
   not enrich B — it *destroys the property that made B worth having*. Route such insight to the
   knowledge store instead, and let B keep its blindness on purpose. **Identity beats convenience**;
   this is the rule that gets violated first, because injecting looks like helping.
2. **What crosses is a transformed artifact, not a raw dump.** A finding is useful to the neighbour only
   in the form that neighbour already consumes. The meta-harness owns the conversion — that conversion
   *is* the pipe, and building it is the work.
3. **Two-layer governance: the meta layer supplies, the field layer adjudicates.** FH (or any meta
   harness) feeds the engine and the inputs; the field harness declares the verdict on its own surface.
   A meta layer that issues field verdicts directly has collapsed the layers.

Honest boundary: crossing is only worth building where the wells are **genuinely different in kind**
(different observation modality, different failure classes). Between two harnesses that see the same
things, a pipe adds coordination cost and no information — that is composition, not crossing. And a pipe
being *connected* is not the same as it being *effective*: state infrastructure and measured effect
separately, never quote the former as the latter.

Origin: forged in a field environment (2026-07-19, operator) where a black-box regression harness and a
white-box static-review harness had to feed each other without either losing its character; generalized
here with the site-specific well names removed. The field-level instance keeps its own concrete form.

## 5. Sidecar corollary — ride the evolution, don't patch the weak spots

Mechanically patching each frontier model's current weaknesses produces scaffolding that dies as models
improve (the weakness itself disappears). FH's sidecar layer is therefore built to **co-evolve**: shed
what the substrate now does natively (`feedback: frontier substrate self-adaptation`), absorb what it
ships next, and use cross-family decorrelation as *today's* trust lever (composition beats a single
model's ceiling — see `multi_model_sidecar_strategy.md`). Capability is the model's; assembly, trust,
and evolution are the harness's.

## Done When (doctrine doc — reference asset)

- The four-pillar README section, `CLAUDE.md §Identity`, and this doc tell one consistent story
  (no contradicting claims). *Check class: judged; pair: contradiction scan on ingest
  (`sync_push_protocols.md` step 3).*
- Every mechanism named here points at a real, existing asset (Full-Harness Mode, crucible_mode,
  goal-quench, multi_model_sidecar_strategy). *Check class: mandatory-pass (phantom scan).*
