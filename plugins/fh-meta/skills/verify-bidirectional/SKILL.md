---
name: verify-bidirectional
description: A skill that immediately updates the baseline and reflects it in the next session when the user raises a counter-argument to an AI recommendation. Triggered by "is that right?", "re-examine this", "something seems off here". Explicit /verify-bidirectional call also possible.
user-invocable: true
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - full_revalidation
    - high_stakes
    - fail_verdict   # AI recommendation was wrong → baseline overwrite is high-stakes: at Sonnet, bind the overwrite to a mechanical anchor (diff review + source re-check) and RECOMMEND an opus/sidecar dispatch (consent-gated) — Sonnet+anchor is a legitimate path (sonnet_floor_doctrine.md), silent judged-only overwrite is not
---

# verify-bidirectional — Bidirectional Self-Validation Automation

Automates the processing procedure for bidirectional self-validation. Three stages: user counter-argument → baseline update → next session reflection.

## Trigger Conditions

Immediately **after** this harness AI recommendation/agreement/decision is committed, when the user raises a refinement challenge:

1. **Proposition refinement**: "isn't it more like..." / "I'd say..." / "what about this" / "what's the root?"
2. **Baseline grep trigger**: User cross-references own assets, memory, CLAUDE.md rules, past decisions
3. **Meta-level trigger**: "if you have objections" / "double-check" / "essence" / "root cause"
4. **Side validation result**: User runs independent tools (`/skills` · `gh` · external fetch) → catches mismatch with this harness AI hypothesis

### Natural Language Triggers (works without internal vocabulary)

Also triggered in external user environments by these natural language phrases:

| Phrase | Intent |
|---|---|
| "is that right?", "re-examine this" | Request AI recommendation re-validation |
| "something seems off", "this doesn't feel right" | Counter-argument / refinement |
| "I think you said something different before" | Catch inconsistency with past decisions |
| "can you be more precise?" | Proposition refinement trigger |
| "what's your basis?", "why do you think that?" | Baseline grep trigger |
| "check that one more time" | Self-validation request |

### 🟥 5. Prescriptive doctrine statement — the category that fell through (added 2026-08-16)

Every trigger above is shaped as **doubt about a claim**. A large class of operator correction is not
doubt at all — it is a **standing rule being handed over**, stated as fact or instruction:

| Shape | Real examples (2026-08-16 session) |
|---|---|
| *"X should also include Y"* | *"입장리뷰에는 정적리뷰뿐만 아니라 **동적리뷰도 포함되어야 할 거야**"* |
| *"the real point of X is Z"* (redefining, not doubting) | *"부스팅보다 인큐베이터의 장점은 그 레포 전체를 감싸서 …**모든 것을 조작할 수 있는 권한**이 있는 거야"* |
| *"isn't this too late / wrong-ordered?"* (rhetorical, expects agreement) | *"이 실패가 CI 확인 단계에서야 발견되는 건 매우 **늦은 게 아닐까**"* |
| *"from now on, do W at Z"* | *"앞으로도 마감할 때 그 갈래로 이어갈 수 있게 **알아서 정리해줘**"* |

**Why these were missed 4 times out of 4** — they sit in the blind spot between the triggers (which
expect a *challenge*) and the Exceptions below (which release a *simple correction* with "no
review"). A doctrine statement is neither: it does not dispute a claim, and it is not a one-off fix
to apply and forget. Treated as the exception, it gets a verbal acknowledgment and evaporates at
session end. **Measured**: four such statements in one session, all acknowledged in conversation,
**zero landed in any file** until a later review grepped for them and found nothing.

**The tell is grammatical, and it is language-independent** — the listed phrases above are all
English interrogatives, which is why a Korean declarative (`~해야 할 거야` · `~인 거야` · `~아닐까`)
matched none of them. Do not fix this by appending more literals (Grep-Collision Treadmill, P10);
the discriminator is: **does this utterance describe how I should behave from now on, rather than
what is wrong with this one output?** If yes, it is this category regardless of language or phrasing.

**Required action** — an acknowledgment is not compliance. The statement must land **in a file** in
the same session: canon (`CLAUDE.md` / `knowledge/`) if it governs future behavior, memory if it is
about this operator, a signal file if it needs a decision first. Then say WHERE it landed, so the
operator can see it did.

**Exceptions** (this skill does NOT apply):
- Simple user correction ("this is wrong, redo it") = direct negation → immediate correction (no review).
  ⚠️ **Not the same as category 5 above** — "redo this" is scoped to one output; "from now on do X"
  is a standing rule. When both readings fit, take it as category 5: over-landing costs a file edit,
  under-landing loses the rule entirely.
- This harness AI self-catch (no external counter-argument) = `fact-checker` rule (narrow 1 / broad N+1)

## Execution Steps

### Step 1. Immediate Baseline Update Channel Processing

Treat user's statement as **external refinement material**. **Do NOT attempt to defend against it** — acknowledge possibility of partial weakening or correction of initial recommendation.

Core proposition: "refinement challenge ≠ fundamental negation". Priority is identifying where the initial recommendation is weakened.

**Evidence gate (overwrite ≠ soften)** — closes the sycophancy/steering vector where a bare assertion
("that's wrong, re-examine") flips a baseline with zero evidence (judge-robustness swarm, 2026-06-13).
"Do NOT defend" still holds for *this conversation's proposition* (anti-stubbornness is the point), but a
**persistent-baseline overwrite** (a rule, asset, memory, or `knowledge/` claim — anything that outlives
this session) requires a **supporting basis**, not mere pushback:

- **(a)** the user cited a file / line / commit / URL / past decision **and the cited content actually
  supports the challenge** — verified by *reading it*, not by its mere existence (an irrelevant-but-real
  citation is the out-of-context-grounding trap, the same vector phantom-quench guards), **or**
- **(b)** the Step 2 grep returns an actual contradiction that *supports the challenge* (not just any
  conflict with the original) — surfaced literally.

If a baseline overwrite is implied but **neither holds**, do not silently rewrite: verdict is **ESCALATE**
— surface *"this would overwrite baseline {X} with no cited evidence; confirm override, or provide a
source?"* and block the Step 4 cascade until the operator answers. Softening a local in-conversation
proposition (no persistent asset changed) proceeds as before — the gate fires only on persistent-baseline
writes. **Sequencing**: this gate is written in Step 1, but Step 4 is what enumerates affected persistent
assets — so if Step 4 later identifies *any* persistent asset to write, **re-apply this gate before Step
4.5** even if the original challenge first looked like a mere soften. This is **not** restored AI defensiveness: the AI still does not argue the user is wrong; it only
declines to *fabricate a baseline change* the evidence does not support (mirror of the steel-quench/phantom
mechanical-anchor principle — judged verdicts bind to evidence).

### Step 2. Consistency Area Grep (3-step mandatory)

Grep to find which rules, assets, or propositions conflict with the initial recommendation:

**Scope priority**:
1. `memory feedback_*.md` (especially operating model rules — meta principles, warning lines)
2. `CLAUDE.md` Sync/Push Protocol, asset ownership table
3. `tracks/*/learnings/feedback_*.md` — this harness AI's own rules
4. `knowledge/shared/harness-core/*.md` — higher-level framework

**Mandatory grep keywords** (baseline consistency guard):
- "drift" · "asset ownership" (CLAUDE.md)
- Asset names, abbreviations, identifiers explicitly stated in user's message

**External users**: Replace with your own environment's baseline keywords (prioritize asset names, abbreviations, identifiers from user's message).

### Step 3. Fact-Checker Self-Catch Mark

Mark the corrected weakened proposition as a fact-checker self-catch:

```
fact-checker self-catch #N (narrow 1 / broad N+1)
- This harness AI initial recommendation: {summary}
- Refinement challenge: {user's statement}
- Corrected recovery: {updated proposition}
- Consistency rule: {grep result}
```

### Step 4. Immediate Patch (Cascading Update Obligation)

First identify the list of affected assets. Actual file modification is performed after user approval in Step 4.5.

| Affected Asset | Update Location | Notes |
|---|---|---|
| This SKILL.md §Validation Ledger | Add cumulative count + new round entry | Self-perpetuation of this rule. (Was `memory feedback_bidirectional_self_validation.md` — **absent, verified 2026-08-12**; the rule body is this file.) |
| memory `project_*.md` (if affected) | Add relevant section | When naming, identity, or roadmap changes |
| `tracks/_audit/*.md` (if affected) | Add pre-design section | When this validation affects persistent assets |
| `CATALOG.md` | Add this session entry | For major decisions |
| `reference_next_session_starter.md` §1 | Merge this conclusion | Material for next session entry |

**Markdown editing discipline** — this skill's own rule, stated here rather than delegated:

> Use `Edit` for any `.md` that already exists. `Write` on an existing file replaces it whole and
> silently discards content this session never read — that is the failure mode the rule exists for,
> not a style preference. If a full rewrite is genuinely unavoidable, `Read` the file first, then
> verify immediately with `git diff` and report what changed.

(Previously cited as `feedback_markdown_edit_discipline` — that memory key is **absent, verified
2026-08-12**. The rule is live; only the pointer was dead, so it is written out here. A prohibition
that rests on a file nobody can open is not enforceable.)

### Step 4.5. Change `diff` Review (User Gate Required)

For each 'affected asset' identified in Step 4, the AI generates a `diff` of the proposed changes and presents it to the user.

```
⚠ Proposed automatic modifications to the following files.
File: {file path}
--- diff
(changes in git diff format)
---
Would you like to apply these changes? [y / N]
```

`y` = execute actual file modification (`Edit` or `Write`). `N` = skip that file change. Must receive `y` or `N` for every change proposal before proceeding. This ensures the Human-in-the-loop principle and minimizes risks from automatic AI modifications.

### Step 5. Compatibility Enhancement Area Identification (Optional)

Refinement challenge ≠ fundamental negation. When a **compatibility enhancement area** is identified (part of initial recommendation + part of refinement = integrated proposition), add 1 explicit statement:

4 refinement challenge patterns:
1. **Compatibility enhancement** — two propositions coexist (e.g., "AI data processing + human baseline validation")
2. **Time-bounded** — proposition is time-bounded (e.g., "Phase II alignment / re-validate in Phase III")
3. **Naming intent verification** — naming itself divides intent (e.g., "bottleneck = efficiency measure vs. negating humanity")
4. **N-way condition** — proposition only holds under N conditions (e.g., "recipient's learning intent + gap separation + resource constraint awareness")

Skip this step if no compatibility enhancement found (no token-filler).

### Step 6. Update Trigger Count + Skill Update Review

Update the trigger count in the **§Validation Ledger** at the bottom of this file. (It formerly
pointed at `memory feedback_bidirectional_self_validation.md`, **absent, verified 2026-08-12** —
so the count had nowhere to land and this step could not actually be performed.)

- 5+ accumulated = Skill promotion review (already fulfilled by creating this skill ✅)
- 8+ accumulated = skill update review (rule refinement + round table compression + update this skill)
- When user names a refinement challenge pattern (bidirectional evolution dimension documentation)
- When this harness AI identifies its own baseline grep omission pattern (add new initial recommendation consistency guard)

## Self-Activation Channel — Autonomous Baseline Cross-Check

This skill's essence = user ↔ this harness AI bidirectional self-validation. This section = active channel where the AI runs autonomous baseline grep without user mediation.

### Activation Triggers (autonomous mode)

- **Natural cadence**: weekly_audit 7-day cycle (when `harvest-loop` skill runs) → AI runs autonomous baseline grep
- **External asset persona audit time**: After updating externally-published asset, call `hub-persona-auditor` agent → mandatory processing on REVISE verdict
- **User explicitly grants autonomy**: "let's go in order" / "go ahead" patterns → AI granted autonomous execution permission

### Limits

- **Explicit user direction required** — AI cannot decide alone. Without explicit direction, autonomous activation only on natural cadence arrival
- **Simplification guard compliance** — if 5+ new assets accumulate from autonomous run, archive decision is mandatory
- **Only AI self-catches count for fact-checker** — this channel is a supplementary axis, not the primary bidirectional validation axis

## Proactive Concern Channel

This skill's existing flow = **reactive** — user refinement challenge → AI baseline update.
**Active** addition — AI proactively speaks up about premise errors or directional risks without user asking.

Background: If the user proceeds without detecting a wrong direction or without being able to express doubt, it comes back at a much greater cost later. Waiting for the back-and-forth build-up transfers the responsibility of detecting premise errors to the user.

### Activation Conditions

Speak up **before** entering implementation if any of these apply:

1. User presents a new direction/frame/premise — conflicts with existing assets, baseline, or simplification guard
2. Gap detected between surface purpose (what user is asking for) and actual problem being solved (root)
3. Agent/model delegation is clearly cost-ineffective

### Message Format

```
"Before going in [direction/premise] direction, one concern: [concern].
 Reason: [basis — existing baseline/asset name or root logic].
 Should we proceed, or review another approach first?"
```

### Constraints

- **One concern only** — listing multiple concerns creates hurdles (increases user cognitive load)
- **Only before implementation starts** — braking on work already in progress destroys context
- **If user explicitly says "just go"** — skip proactive message and execute immediately
- If user listens to concern and decides "let's proceed anyway", execute immediately instead of reactive 6-step

## User Approval Gates

| Stage | Approval |
|---|---|
| Step 4.5 change `diff` review | **Required** |
| Step 4 major decision cascading (CATALOG · external asset impact) | **Required** |
| Step 6 skill update review | **Required** |

## Constraints

- **This skill = validation and recording automation. Core decisions belong to the user** — this harness AI has no independent decision authority
- **This harness AI self-catch cannot be applied alone** — follow `fact-checker` rule (narrow 1 / broad N+1)
- **Simplification guard compliance** — when creating or modifying this skill, update SKILL.md only. Do not spawn auxiliary files; a change that needs a new file needs a reason stated in the same edit. (Formerly cited `feedback_simplification_evidence` — **absent, verified 2026-08-12**)
- **Markdown editing discipline obligation** — `Edit` on existing `.md`; `Write` only after reading the file, and verified with `git diff` (full statement in Step 4 above). (Formerly cited `feedback_markdown_edit_discipline` — **absent, verified 2026-08-12**)

## External User Environment Adaptation

This skill's core essence = "channel for updating baseline when user refinement challenge occurs after AI recommendation/agreement is committed" — cross-applicable to all user environments.

### Fallback Matrix (origin environment → external environment replacement)

| Origin Environment Dependency | External User Environment Fallback |
|---|---|
| Rule body — **this SKILL.md itself** (the origin environment's `memory feedback_bidirectional_self_validation.md` is **absent, verified 2026-08-12**; there is no origin-side file to fall back from) | User environment's own `memory/` or `notes/` bidirectional validation rule / if absent, this skill's own rule baseline — which is now the only baseline in either environment |
| `memory feedback_*.md` grep scope (Step 2 priority 1) | User environment's own `learnings/` · `docs/` · `CLAUDE.md` grep (user's own baseline) |
| `tracks/*/learnings/feedback_*.md` (Step 2 priority 2) | User environment's own learnings area (auto-detect naming variations) |
| `knowledge/shared/harness-core/*.md` (Step 2 priority 4) | User environment's own `docs/` or `knowledge/` grep |
| `CATALOG.md` entry addition (Step 4) | User environment's own history archive (skip if absent) |
| `reference_next_session_starter.md §1` (Step 4) | User environment's own next-session material (skip if absent) |
| Mandatory grep keywords ("drift", asset ownership, etc.) | User environment's own baseline keywords (prioritize asset names, abbreviations, identifiers from user's message) |

### External User Scenarios

1. **General bidirectional validation**: AI recommendation → user refinement challenge → this skill auto-activates → 6-step processing (Step 1 immediate baseline update / Step 2 consistency grep / Step 3 fact-checker self-catch / Step 4 immediate patch / Step 4.5 diff gate / Step 5 compatibility enhancement / Step 6 update trigger count)
2. **User's own baseline cross-ref**: Generalize Step 2 grep scope to user environment's own assets
3. **Fact-checker count generalization**: Start user's own self-catch count from 0 (narrow 1 / broad N+1)
4. **Same user approval gate**: Step 4.5 diff review / Step 4 major decision cascading / Step 6 Skill v0.x update

### Limits

- **External users can use their own model cross-check channel** (e.g., other LLM API, other in-house model)
- **Accumulated validation history** = accumulates from origin for the original developer / external users start their own count from 0
- **Autonomous activation baseline examples** (harvest-loop + hub-persona-auditor) = origin environment baseline / external users can also trigger autonomous activation on their own natural cadence
- External users also follow same user approval gate (Human-in-the-loop principle baseline)

## Done When

```
☐ Steps 1~6 all executed — a step that produced no artifact is
  not executed                                                  (measured: 6 steps, 6 artifacts)
☐ Step 1 baseline update applied BEFORE Step 2 grep runs — the
  order is the point of the skill, not a formality              (mandatory-pass)
☐ Step 2 consistency grep ran across all 4 priority scopes, and
  each scope reports hits or an explicit "0 hits, scope exists"
  — a scope that does not exist reports MISSING, never 0        (measured: 4 scopes reported)
☐ fact-checker self-catch mark output                           (mandatory-pass)
☐ Step 4.5 diff gate: user confirmation received (y/N) before
  any file was modified; no answer == N                         (mandatory-pass, HITL)
☐ §Validation Ledger has one new row and the Count line matches
  the row total                                                 (measured: rows == Count)
☐ Every memory/asset key cited in the round was confirmed to
  RESOLVE before being used as grounds                          (mandatory-pass — an absent key
                                                                 is cited as absent, never as
                                                                 support)
☐ The counter-argument was actually re-examined rather than
  conceded to                                                   (judged — adversarial pairing:
                                                                 `fact-checker` (narrow 1 /
                                                                 broad N+1) re-runs the grep
                                                                 independently; agreement with
                                                                 the user is not evidence the
                                                                 user was right)
☐ External validation path available: harvest-loop's Critic
  isolation pass can independently judge on the above criteria  (judged — adversarial pairing:
                                                                 Critic runs isolated, not in
                                                                 this session's context)
```

> **Why the last two are judged, and paired.** This skill fires when the user pushes back, which is
> precisely the moment agreement is cheapest. A Done When that only counts steps is satisfied by a
> run that folded immediately. The pairing is the whole check: an isolated re-grep, and an isolated
> critic — neither of which has seen this session's reasoning.

Verdict: PASS (Step 4.5 diff gate confirmed, baseline updated) | CONDITIONAL_PASS (update applied, external validation still pending) | FAIL (counter-argument confirmed — AI recommendation was wrong, baseline requires redesign) | ESCALATE (counter-argument ambiguous, human judgment required)

## References

> **All memory keys below were checked on 2026-08-12 and every one is absent** (same-run
> known-positive control: `feedback_verify_before_downgrade.md` and `memory_intent_recall.md`
> both resolve, so the check is not misreporting). A struck entry here is not a fix if the same
> name is still load-bearing above — the rules those keys carried have been written into the body
> of this skill (Step 4 markdown discipline, §Constraints, §Validation Ledger), which is why the
> strikethroughs below are safe to leave as history.

- ~~Rule body: `memory feedback_bidirectional_self_validation.md`~~ — **absent (verified 2026-08-12)**. The rule body is **this file**; the cumulative count lives in §Validation Ledger.
- ~~Operating model text: `memory feedback_hub_cc_operating_model.md §2.5·§2.6`~~ — **absent (verified 2026-08-12)**. The live equivalent is `CLAUDE.md §Identity — 3-Layer Mission + Core Axis`; cite that, not this filename.
- ~~Consistency rules: `feedback_external_ai_github_recommendation_verification` · `feedback_reference_own_hub_assets_first` · `feedback_simplification_evidence` · `feedback_markdown_edit_discipline` · `feedback_impact_first_then_tune`~~ — **absent (verified 2026-08-12)**. The two that this skill actually depends on are restated in §Constraints above.
- Live, verified references (these resolve): `tracks/_meta/reference_next_session_starter.md` (session card, Step 4) · `CATALOG.md` · the `fact-checker` agent (Step 3).

## Validation Ledger

Cumulative trigger count for Step 6. Append one row per completed round; the count is the number of
rows. This section is the landing site that the absent memory key used to be.

| # | Date | Trigger (user's counter-argument, one line) | Verdict | Baseline change |
|---|---|---|---|---|
| — | — | (no rounds recorded in-file yet — prior rounds lived in the now-absent memory key and are not recoverable) | — | — |

**Count**: 0 recorded rounds. Do not restate a remembered historical total here; an unrecoverable
count is `unknown`, not a number carried over from a file nobody can open.
