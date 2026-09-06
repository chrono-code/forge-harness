# Measurement-Integrity Checklist — cross-model measurement pre-flight

> A cross-model measurement is only trustworthy if its **instrument** is verified first.
> Measurement integrity is a *precondition*, not a result. Four observed failure modes, each with a
> concrete countermeasure. Consult this before any FH measurement that compares models (sims, sidecar
> comparisons, capability-equalizer runs, the-bible model panels, A6-class experiments).

This is a **checklist a measurement consults**, not a gate with triggers and not a dispatch surface —
hence a knowledge doc, the lightest asset that holds it (a harness gets simpler over time). If it ever
becomes a gate other skills invoke, revisit the weight.

## The three failure modes + countermeasures

| # | Failure mode (observed) | Countermeasure |
|---|---|---|
| 1 | **Silent model fallback** — passing a model *slug* silently resolved to a weaker model (e.g. an `agy` slug fell back to Flash) instead of the intended one. The run *looks* like the named model but isn't. | **Pin the display name, not the slug** (e.g. `"Gemini 3.1 Pro (High)"`, not a bare slug). Confirm the resolved identity, don't assume the slug binds. |
| 2 | **Non-deterministic borderline verdicts** — contested/borderline cases flip across runs (observed: haiku 4/4 flip; flagship models flip too — flipping is **not** a tier signal). A single draw is noise, not a measurement. | **reps ≥ 3 on any borderline/contested verdict.** A single run on a contested case is inadmissible. Report the flip pattern (STABLE vs FLIP), not just the modal verdict. |
| 3 | **Generic self-identity probe** — a probe any model passes ("are you working? → OK") proves nothing about *which* model answered. | **Use a discriminating probe** — one that two different models answer *differently*. A generic-pass probe is invalid. The probe is a **pattern, not a fixed string**: a probe that discriminates Opus 4.8 from Sonnet 4.6 today may both-pass a future model generation, so **re-validate the probe each model generation** (same staleness class `memory-hygiene` exists to catch). |
| 4 | **Serving-path / quantization variance** — the *same* display-name model served over two different backends (different quantization/infra) is a **different instrument** and yields materially different measurements. Observed: one GLM-5.2 model family gave effect-size delta **+0.21** when served via an internal NVFP4-quantized deployment vs **+0.08** via an OpenRouter relay — same model name, ~2.6× different effect (n=864, reps≥3). A correctly-pinned display name (item #1) is **necessary but not sufficient**. | **Pin *and record* the serving path** — backend host + quantization, not just the display name. Two runs are comparable only if the serving path matches; a name match across different infra is an implicit apples-to-oranges. When you cannot hold it fixed, **report the serving path as a measured variable**, not a constant. |
| 5 | **Injected-context contamination (blind-sim class)** — a subagent dispatched to evaluate a *modified* instruction file answers from the **auto-injected project context** (claudeMd/memory baked into its system prompt at spawn) instead of reading the target. Observed twice in one session (2026-07-17): a "blind sim" quoted section numbering that existed only in the pre-edit file, and a second sim cited trigger-table rows that had been **deleted** from the file it claimed to have read — tool-use count 0–1 in both. The measurement *looks* grounded (fluent, plausibly cited) but the instrument never touched the target. A prompt-line telling it to ignore injected context is **not sufficient** — both runs had one. | **Force mechanical grounding a stale answer cannot fake**: ① stage the target at a **neutral path** (tmp copy) the injection cannot cover; ② require **verbatim quotes** (or grep line-number output) from that path for every claim; ③ design the probe around a **content discriminator** — something present only in the new version, or *absent* from it (a deleted row cited = instant invalidation); ④ treat **tool-use count as a validity signal** — a sim that "read two files" with 0–1 tool calls is invalid regardless of answer quality. Re-run, don't argue with a contaminated result. |

## Why these are entangled (and why they matter beyond their own scope)

Item #2 (reps≥3) is the discipline that **retracted half the evidence** for the
`[[feedback_correlated_blindspot_union_over_majority]]` finding — one of its two supporting cases
turned out to be non-deterministic borderline flipping, not a stable correlated blind spot. So this
checklist is the **prerequisite** for any "correlated error" claim: you cannot call an error correlated
(and prescribe union-over-majority) until reps≥3 has distinguished a stable correlated error from a
single-draw artifact. Item #3 (discriminating probe) **embodies** the judge-robustness /
mechanical-anchor principle — don't trust self-reported identity, prove it discriminatingly
([[feedback_judge_robustness_mechanical_anchor]]).

Item #4 (serving-path variance) **sharpens** item #1 into a two-part identity: #1 catches the *wrong
model* (a slug that fell back); #4 catches the *right model on the wrong instrument* (a correct name
served over a different quantization/backend). The verified identity a measurement records is therefore
**name + serving path**, not name alone — a family-decorrelation claim (cross-family sidecar) is only
sound once the serving path of each family is itself pinned, else "different family" silently smuggles
"different infra" ([[reference_measurement_serving_path_variance]]).

Item #5 (injected-context contamination) is item #3's sibling on the *input* side: #3 proves *who*
answered, #5 proves *what they actually read*. Both reduce to the same mechanical-anchor rule — never
accept a measurement's self-report (of identity or of grounding) when a discriminating mechanical
check is available. Its sharpest tool is the **deleted-content discriminator**: a probe target that no
longer contains X makes any answer citing X self-invalidating — certainty no prompt instruction buys.

## Done When

- The checklist enumerates all five failure modes, each with its countermeasure.
  *Check class: mandatory-pass (binary — five items present, each with a countermeasure).*
- The probe item specifies a **discriminating** test and rejects generic probes.
  *Check class: judged, pair: a probe that two different models both pass must FAIL this check; a
  discriminating one must distinguish them.*
- Any FH cross-model measurement records which checklist items it ran.
  *Check class: measured (count of items applied) — closes the predict-verify loop for future audit.*

## Optional hardening (when a measurement feeds a published / paper claim)

Escalate item #1 (display-name pin) and item #3 (identity verification) from prose to a **logged
mechanical assertion**: the measurement harness records the *verified* model identity it observed, not
the requested slug. Prose discipline is sufficient for internal dogfooding; a published claim earns the
mechanical log.

> **External dogfood (a second, field-layer instance — n=1 external, a signal not a settled frontier):**
> the sister skill `ponytail` ships a runnable instance of the precondition behind all three modes —
> a `--selftest` that proves each instrument (`good===true && bad===false`) before any API spend, and
> two caught instrument contaminations. Detail + pinned citations: `tracks/_audit/session_2026_06_24_ponytail-lazy-senior-dev.md` §2-C (single source).

---

**Origin** (2026-06-22 harvest-loop): three failure modes observed across the-bible L2 model panel
(agy slug→Flash silent fallback; reps=3 non-determinism) and prior multi-model sims (generic-probe
ambiguity). Sister findings: [[feedback_correlated_blindspot_union_over_majority]] (reps≥3 prerequisite),
[[feedback_judge_robustness_mechanical_anchor]] (discriminating-probe = mechanical anchor),
[[reference_agy_model_catalog]] (display-name pin — agy slug fallback documented there).

**#4 added** (2026-07-05): serving-path variance surfaced in a cross-family verdict-invariance run
(n=864, borderline fixtures × 2 conditions × K=6 paraphrase × reps≥3). An identical GLM-5.2 model name
served over an internal NVFP4-quantized deployment vs an OpenRouter relay gave +0.21 vs +0.08
effect-size delta — quantifying that "same model name ⇒ same measurement" is false. Provenance +
generalizable finding: [[reference_measurement_serving_path_variance]].

**External corroboration** (2026-07): the local-LLM community independently reports the same hazard —
practitioners conflate "running model X" with running a *pruned/quantized derivative* of X (aggressive
low-bit quantization + expert pruning measurably degrade long-context quality while the model *name* is
unchanged). This is a general measurement pitfall, not FH-specific: a leaderboard or replication that
pins only the display name silently compares different instruments across serving paths.

---

## §Measured-Loop — 사전등록 → 팔 → 채점기 → 집행, 그리고 계기가 먼저다

> **언제 쓰나**: 「이 규칙/자산이 실제로 먹히나」를 **주장이 아니라 판정으로** 내야 할 때.
> 살리언스 의존 변경(규칙·온보딩·문구)과 게이트 배선이 전형이다.
> **누가 쓰나**: 이 절차의 판단 부분(팔 설계 · 반증 조건 · 무효 판정)은 **opus-tier 이상 권장**이다
> — 플로어 세션이 «측정 대상»인 것과, 플로어 세션이 «측정을 설계»하는 것은 다른 요구다.
> 🟥 그래서 이 절은 `sonnet_floor_doctrine.md` 의 floor 위반이 아니다: base op 가 아니라
> **거버너의 설계 작업**이고, 실행(팔)은 플로어에서 돈다.

### 다섯 걸음 — 순서가 곧 규율이다

```
① 사전등록을 «봉인»한다        무엇을 재나 · 성립 조건 · 🟥 반증 조건 · 「안 재는 것」 ·
                               🟥 «몇 번째 프레이밍인가」(파일럿/시도 횟수 + 버린 프레이밍)
                               결과를 본 뒤 조건을 옮기면 그건 측정이 아니라 사후 서술이다
② 한 변수로 팔을 만든다        ARM = 있는 트리 · CTRL = 그 한 조각«만» 뺀 동일 트리
                               🟥 두 변수가 바뀌면 어느 쪽이든 «둘 다 거짓»으로 쓸 수 있다
③ 채점기를 «결과 전에» 짓는다  규칙을 코드로 고정하고 known-pair 로 캘리브레이션한다
                               known-positive(아는 답을 재현) ∧ known-negative(0/0 이 구분되나)
④ 반증 조건을 그대로 집행한다  미달이면 「미측정」이 아니라 **「측정했고 안 된다」**로 적는다
⑤ 계기를 먼저 의심한다        이상하면 대상보다 계기다. 계기 결함이면 **고치고 재실행**하고,
                               그 실패를 «없던 일»로 접지 않는다 — 무효가 된 이유가 결과다
```

🟥 **①에 새 필수 칸 — «몇 번째 프레이밍인가」(2026-09-04, six_axis_review 판정안 3, append-only).**
사전등록이 «지금 이 형태로» 봉인되기까지 **몇 번 시도했고 무엇을 버렸는지**를 같이 적는다:
파일럿/시도 횟수 · 버린 프레이밍 각각의 한 줄 사유. 안 적으면 사전등록 자체가 **사후에
가장 잘 통과하는 형태로 역산된 것인지 구분이 안 된다** — 사전등록 절차가 막으려는 바로 그
사후 서술이 «시도 횟수»라는 숨은 차원으로 새는 구멍이다. 외부 근거: 사전등록 연구는 파일럿
횟수·탐색한 모델·사전 결과가 최종 프레이밍에 미친 영향의 **공개를 의무로 삼는다**
(arXiv:2606.11217; `frontier_verification_map_2026-09-04.md` §ⓒ 행이 같은 논문을 인용한다).
Mechanization Boundary — 이 칸도 **존재만** 요구한다: 파일럿 횟수가 사실인지, 버린 프레이밍이
정직하게 다 적혔는지는 self-attested 다(같은 잔여를 이미 안고 있는 다른 필드들과 같은 자리 —
자평이다·게임 가능하다는 열려 있다). Done When 에 반영 — 아래.

### 🟥 이 절차가 실제로 산 값 (2026-08-29/30, 한 세션)

같은 밤에 **내가 발표한 것 셋이 거짓**이었고 셋 다 이 절차가 잡았다:
- 「인사말은 훅에 걸려 있다」 → 팔 하나가 `--restricted` 로 돌아 **CLAUDE.md 가 상주에서 빠져
  있었다.** ②(한 변수)를 어긴 것이고, 그 사실은 **레인**이 잡았다.
- 「분기 판정 33% 오판」 → `Glob` 이 디렉토리를 열거 못 하는 것이었다. 도구 하나 추가로 3/5→5/5.
  ⑤(계기를 먼저 의심)가 잡았다.
- 「이 지적은 net-new」 → 레포 도구가 이미 찍고 있었고 **표시용 grep 이 가렸다**(`called` vs `caller`).

그리고 ④의 값: 문-뒤 명명 규칙이 **두 자리에서 각각 0/3·0/5** 로 반증됐다. 「읽으면 맞다」로
남겨뒀으면 지금도 «있는 기능»으로 세고 있었을 것이다.

### 기구 — 새로 짓지 마라

**`scripts/sim_isolated_run.sh`** 가 이 절차의 실행부다. rep 마다 일회용 클론 · 머신 표면
스냅샷 · **3값 판정**(빈 출력은 «아니오»가 아니다) · `--no-harness`(FH 때문인가 vs 베이스 모델도
그런가) · `--setup`(전제를 클론 «안»에서) · `--extra-tools`(도구 가시성이 변수일 때).
🟥 **라이브 레포에서 직접 sim 을 돌리지 마라** — 그 금지는 사고에서 나왔다(팔들이 서로의 산출을
「선행자산」으로 읽었고 운영자 머신에 launchd 를 등록했다).
🟥 **훅 의존 측정은 이 러너로 못 한다** — 일회용 클론에서 프로젝트 훅은 안 돈다(실측).

### 흔한 무효 사유 다섯 — 미리 알면 한 번씩 덜 버린다

```
전제 미비        문 ③ 을 재는데 매핑 프로젝트가 없다 → 관찰하려던 상태에 들어간 적이 없다
픽스처 비가시    빈 디렉토리는 Glob 에 안 잡힌다 → 픽스처엔 «파일»이 있어야 한다
분모 정의 오류   성공 형태가 P0 필터에 걸려 분모가 빈다 (계기가 실패 모드를 가정해 설계된 것)
대조 불성립      변수가 둘이거나, 한쪽 기제가 아예 안 돌았다 → 증거 파일로 «격발»부터 확인
배정 자유도      한 산출이 «두 버킷에» 걸릴 때 어디로 보낼지가 안 정해져 있다 → 결과를 보며
                 정하게 된다. 🟥 판정 규칙을 봉인한 것과 배정 규칙을 봉인한 것은 «다른 자유도»다
```

**배정 자유도가 왜 따로 있나** (2026-08-30, qasp ⓪-c 채점 직전 실측). 채점기가 「무엇을 검출로
세나」를 엄격히 봉인했는데, 한 finding 이 주입 D2·D3 **양쪽 어휘에 걸렸다.** 그 처분이 *"손검증에서
하나로 정리"* 로 남아 있었다 — 즉 **결과를 보며 배정하게 되어 있었다.** 방향도 중립이 아니다:
아직 0 건인 버킷으로 보내면 검출이 늘고, 그건 **저자에게 유리한 쪽**이다
([[feedback_not_found_is_not_zero_family]] 의 방향 편향과 같은 얼굴).

봉인에 넣을 형태 — **분류를 늘리지 말고 «불확실을 성립으로 접지 않는» 쪽으로 닫는다**:

```
① 한 산출은 최대 하나의 버킷에만 배정된다 (중복 계상 금지)
② 배정 기준은 하나뿐이다 — 어느 근거를 «실제로 인용하는가»
③ 둘 다 인용 → 어느 버킷도 아닌 것으로 센다
④ ③ 에 해당한 건수는 «AMBIGUOUS n건» 으로 따로 적는다 (0 으로 접지 않는다)
```

⚠️ 이 다섯째는 **①(사전등록 봉인)의 하위 항목이지 새 걸음이 아니다.** 다섯 걸음은 그대로 다섯이다.

### Done When
- 사전등록 파일이 **결과보다 먼저** 존재한다(타임스탬프로 확인 가능).
- CTRL 팔이 ARM 과 **한 조각만** 다르다(diff 로 크기를 댈 수 있다).
- 채점기가 known-pair 로 캘리브레이션됐고 그 출력이 기록에 있다.
- 반증 조건이 **결과 뒤에 안 바뀌었다** — 바꿔야 한다면 다음 회차의 사전등록에 적는다.
- 🟥 사전등록에 «몇 번째 프레이밍인가»(파일럿/시도 횟수 + 버린 프레이밍)가 적혀 있다
  (2026-09-04 추가 — 없으면 「이 프레이밍이 사후 역산이 아니다」를 아무도 확인할 수 없다).

---

## §Instrument-Calibration

> Scope note: the sections above govern **cross-model measurement** (pin the display name, reps ≥ 3,
> discriminating identity probe). This section is broader and upstream of them: it governs **any
> instrument whose output becomes a count, a tier, or a claim** — a scan, a grep, a checker script, a
> diagnostic row, a coverage ratio. Added 2026-07-20 after three instrument defects in one session.

### The rule

**Before an instrument's output is trusted or published, it must be shown to work on *this* target.**

1. **Known-pair calibration.** Run it against **one case you already know is positive** and **one you
   know is negative**. If it cannot separate those, it is not measuring — it is generating. This costs
   one run and catches the entire class below.
2. **Hand-verify one sample before publishing.** Open the single case the instrument is *most* confident
   about and confirm by eye. Do this **before** the number enters a report.

### 외부 근거 — 이 규율은 우리 도그푸드에만 얹혀 있지 않다 (2026-09-06 추가)

🟢 **published known-pair, 외부 그룹, 우리 사건과 무관하게**: `arXiv:2609.03267` —
*Refusing the Impossible: A Taxonomy and Benchmark for Code Hallucination in Large Language Models*
(Dasu, Kundu, Tan · 2026-09-03 · `cs.SE`). 그들은 «모델이 불가능한 요구에 코드를 지어낸다」는
헤드라인(불가능 프롬프트에서 **약 60%** 가 근거 없는 코드, **27%** 만 거절)을 **내기 전에**
계기가 아는 답을 가르는지부터 보였다: **91 개의 짝지은 «풀 수 있는» 컨트롤**에서 오거부
**0%**, 그리고 두 단계 판정 프로토콜을 사람 라벨과 대조해 **82% 일치, κ=0.73**. (초록에서 직접
확인 — 이 문단은 digest 요약이 아니라 원문 인용이다.)

**왜 여기 적나**: 위 §The rule 의 1번(known-pair)·2번(사람이 한 건 확인)이 이 저장소 안에서는
**전부 자체 사건**(77건→3건 붕괴 등)으로만 근거를 갖고 있었다 — 규율이 옳다는 주장의 유일한
증인이 그 규율을 쓴 우리 자신이었다는 뜻이고, 그건 이 문서가 다른 자리에서 금지하는 형태다.
이 논문은 **같은 절차를 밟은 외부의 공개 사례**라 그 자기참조를 끊는다.

⚠️ **이식되는 것은 계기 설계이지 숫자가 아니다.** 60%/27%/κ=0.73 은 12개 open-weight 모델의
코드 환각 벤치마크 수치이지 하네스에 대한 측정이 아니다. FH 가 인용하는 것은 «헤드라인을 내기
전에 아는 답으로 계기를 갈랐다»는 **순서**뿐이다. 우리 수치에 대한 근거로 쓰면 그 자체가
이 문서 §계기 보정이 금지하는 «남의 숫자 수입»이다.

**Publish-order asymmetry (why step 2 is not optional):** verification is cheap *before* publication and
expensive *after*. A number written into a report, a session card, and a signal file must then be
corrected in **all three**, and every downstream reader who already consumed it is not recalled.
Measured 2026-07-20: a scanner's "77 items / 70% of the index" went into exactly those three records; a
single hand-check reduced the true figure to **3**.

### The failure class this catches: *the instrument's assumptions don't hold for this target*

Not "measured the wrong property" — the subtler one: **never asked whether this instrument is valid
here.** Three shapes, all observed 2026-07-20 in a single session:

| # | Shape | Concrete instance | What the known-pair would have shown |
|---|---|---|---|
| n+7 | **Instrument sees only part of its own declared surface** | An "always-loaded footprint" scan summed files rooted at `$TARGET`, silently omitting the auto-loaded memory index living outside it — **61% of the real resident surface** | A known-positive (a file you *know* is resident) fails to appear in the sum |
| n+8 | **A cheap proxy substituted for the real property** | Index-line/topic-file **size ratio** used as a proxy for *content coverage*; minimum ratio 3.7× read as "safe" — while an entry whose file was 3.7× larger still lacked every fact the index carried | One known case checked by content, not size, inverts the verdict immediately |
| n+9 | **Language / encoding assumption mismatch** | An **ASCII-token scanner run over a Korean corpus**: the index wrote `catch`, `MERGED`, `expert-system`; the files wrote `잡았다`, `머지`, `케이스크래프트` → every token scored as missing. **~96% false positives** | One known-negative (an entry you know is fully covered) scores as "missing" → mismatch exposed |
| n+10 | **Accepted into the scanned set, but no probe matches that shape** — the instrument counts the file as covered and reports it *clean* | `degrade_direction_scan.sh` collected `.sh` files while every probe was Python-shaped (`except:` / `.get(k, True)` / `if not x:`). A known-positive bash file with four default-toward-PASS constructs scored **0/4**, and the output read `no default-toward-PASS smells in 1 scanned py/sh file` (2026-07-28) | The known-positive of *that shape* scores 0 while the summary says "scanned" — the tell is coverage claimed without detection demonstrated |
| n+11 | **The collection predicate, not the probe, is what silently drops the target** | Same scan: git hooks are named `pre-push` (no extension) under `.git-hooks` (dotted directory), and the extension test ran against the **full path**, so FH's own mechanical floor reported `no scannable (py/sh) target files`, exit 0 | Point the instrument at a directory you *know* holds a positive; an empty file list is the finding, not a clean result |
| n+12 | **The measured axis does not vary with the arm — and equal scores are read as "no difference"** | External name: **frozen-replay defect** (`001TMF/harness-forge`, absorbed 2026-08-23 — *"the single most common way a harness search produces a confident, meaningless result"*). Their instance: a scorer replaying cached outputs makes quality **constant across candidates**, so the search happily returns a winner while measuring only cost. **Ours is not that instance** — see the note below | A **known-pair on the actual pair being compared**, not on a fixture: inject an arm that MUST score differently. If it does not, the equal scores were the instrument standing still, not the arms being alike |

🟥 **n+12 is the class every *comparative* measurement is exposed to — A/B arms, ablation, before/after,
tier batteries** — and it is the one shape on this list where **the instrument's silence looks exactly
like a finding.** n+7…n+11 produce a wrong number; n+12 produces a *confident conclusion* ("no
difference → CUT / no regression → ship") out of an instrument that never moved.

**Measured against our own ablation runner, 2026-08-23** (`scripts/probe_scope_check.sh` ·
`ablation_calibrate.sh` · `.claude/regression/ablation_verdicts.md`), so this row is not imported on faith:

| Leg | Verdict |
|---|---|
| Is there a cache/replay path (their literal mechanism)? | **Structurally absent** — every arm/rep is a live dispatch, so their instance cannot occur here |
| Is arm B verified to have actually not seen the ablated section? | **Closed** — injection/leak control |
| Is the scorer verified to respond at all? | **Closed** — a known-pair the calibrator must pass before a run is allowed |
| 🟥 Is the scorer verified to respond **to the pair actually being compared**? | **OPEN.** The known-pair runs against a separate fixed fixture, never against the live arm A/B. Equal scores on a real pair are therefore not distinguishable from a stalled instrument |

⚠️ **Do not read "no false CUT has happened" as safety.** Of the recorded verdicts, all showed arms
scoring clearly apart and **zero CUTs have ever been issued** — so the open leg has never been
exercised. `not found ≠ 0`; an untriggered hole is untested, not closed.

**What actually transferred was the question, not the defect** — *"is my instrument responding to the
arm at all?"* That question is portable even where the mechanism is not, which is the general lesson
for absorbing an outside failure shape: check whether their **mechanism** exists here before adopting
their **conclusion**. (Prescription deliberately NOT built: recurrence is 1, below this repo's own
mechanization threshold — `[[feedback_mechanize_at_repetition_prose_before]]`.)

Secondary false-positive sources in the same run, worth checking explicitly: **whitespace/hyphen
variants** (`3주새` vs `3주 새`), and treating a line's **navigational annotation** (`(detail …, archive)`)
as a factual claim.

### Degrade direction

- Calibration impossible or inconclusive → ship the output **labeled `UNCALIBRATED`**. It may inform;
  it may **not** ground a tier, a verdict, or a published figure.
- **`not found` ≠ `0`.** A file that does not exist is not an empty file; a scan that died mid-run
  reports a low number, and low numbers read as PASS. Guard the empty case explicitly and say
  `UNMEASURED`, never `0`.
- An instrument that produces an **impossible value** (all-pass, all-fail, or a self-scan in which the
  running tool does not detect itself) is suspect **before** its target is. Suspect the instrument first.
- **"Scanned" is a claim, and it is separate from "covered."** A scanner that admits a file type into its
  scanned set owes a known-positive *of that type*; without one, its clean message is a false clean, which
  is strictly worse than an honest "not covered" (n+10). Same for the collection step: an empty file list
  is a calibration failure to report, never a clean run (n+11).
- **A probe that flags the prescribed remedy is a defect in the probe.** Measured 2026-07-28: flagging
  `${count:-0}` — the integer sanitization that closes the `pipefail`-fallback class — would push an author
  to delete the fix. Hand-check a sample of hits before shipping a probe; on this corpus 6/6 sampled hits
  were false positives and the scoping that followed cut the load from 73 to 14.

### Done When

- Known-positive and known-negative both run, and the instrument separated them
  (check class: **mandatory-pass** — record both cases and their outcomes)
- At least one sample hand-verified before any count is written into a report
  (check class: **mandatory-pass**)
- **If the measurement is COMPARATIVE** (A/B arms, ablation, before/after, tier battery): the
  known-pair ran against **the pair actually being compared**, not only against a fixed fixture — and
  **equal scores are reported as `INSTRUMENT-UNCONFIRMED`, never as "no difference"**, until an arm
  known to score differently has moved the metric (check class: **mandatory-pass** — record which
  pair the known-pair ran on; n+12)
- If either is absent, the output carries the literal token `UNCALIBRATED`
  (check class: **mandatory-pass** — grep the report for the label)
- Adversarial pairing for the judged part ("is this instrument valid for this corpus?"): the
  known-negative **is** the adversarial case — it is chosen to be one the instrument should *not* flag,
  so a flag there is a refutation, not a finding.
