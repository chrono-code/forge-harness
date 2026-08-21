# AI Dialogue Playbook

> Dialogue principles for forge-harness sessions — the "should" layer. Governs how to ask, delegate, and record when working with Claude Code.

**Companion**: `claude_code_runtime_flow.md` is the "does" layer — what actually happens chronologically in a session.

**Voice**: the Control Tower's tone — soft charisma, delivery-layer-only — is defined once in `CLAUDE.md §Voice / Tone` (single source). Warm in word-choice, not length; tone never relaxes judgment rigor (orthogonality guard).

---

## Session Start Protocol

1. **Greet or signal intent** → FH Active Onboarding triggers (see CLAUDE.md)
2. **AI reads automatically**: `reference_next_session_starter.md`, CATALOG.md, LOCAL_SKILL_REGISTRY
3. **Returning user**: AI proposes top 3 priorities from session card + cadence overdue notices
4. **New user**: 2-sentence FH intro → project connect offer

**Don't front-load** *background* (front-load = pre-dumping context before stating intent): avoid dumping project context manually. FH auto-reads the right files. Start with intent, not background.

**Do front-load *specifics***: for the immediate task, paste the concrete artifact — the full error traceback, the exact file path, the failing input — rather than describing it. This is not a contradiction of the line above: FH auto-reads *background* context, but it cannot guess the *specific* traceback/path the current task hinges on; pasting it directly removes a round-trip. (Sister-asset import, Hermes Agent cross-audit 2026-06-27.)

---

## Token Efficiency Principles

| Principle | Implementation |
|---|---|
| **CATALOG first** | Read CATALOG.md → identify candidate files → open only those files. Never scan session files sequentially. |
| **Execution tier** | Match tier to task scope (see CLAUDE.md Execution Tier table). FH default: standard (~15K tokens). |
| **`.claudeignore`** | Apply `templates/.claudeignore` to project to exclude build artifacts, test fixtures, binaries from context. |
| **`/context-doctor`** | Propose when: "context is getting long", "token limit", "/clear", "slow". Auto-generates `.claudeignore`. |
| **Agent dispatch** | Use sub-agents to protect main context from excessive tool output. |
| **Two-layer storage** | `tracks/` = local work history. Critical cross-session state → also write to `memory/` (durable). |

---

## Rule Hierarchy (Scope Precedence)

```
Hub CLAUDE.md (hub common principles) — highest
    └── Project CLAUDE.md
            └── Domain .claude/rules/session.md — lowest
```

Lower levels cannot override higher. Conflicts → higher scope wins.

**AI contribution model**: AI proposes (drafts all changes, prepares commits, creates PR draft) — user approves final push/PR. Human-in-the-loop is non-negotiable for shared repos.

**Explaining the gate to a no-hook user (staged approve/deny framing)**: Mode A/B/D users get the gate mechanically (pre-commit hook + 4-axis). A **Mode C** user (plugin/skill only, no hook) gets no mechanical enforcement — so explain the *same* HITL as a **staged write**: an auto-generated change is *staged*, surfaced for an explicit approve/deny, and only then committed. The vocabulary travels even when the hook doesn't. (Sister-asset import of Hermes' `write_approval` framing, cross-audit 2026-06-27 — wording only; FH's mechanism is unchanged and stronger.)

---

## Amplifier / Coach Dual Mode

The AI operates in two modes simultaneously:

| Mode | When | Behavior |
|---|---|---|
| **Amplifier** | User has a clear intent and task | Execute with minimal friction. Don't block, don't ask for confirmation beyond once. |
| **Coach** | User is exploring, unsure, or new to FH | 2-sentence explanations, skill proposals, one-line options. Don't overwhelm. |

**Signal detection**:
- Explicit task ("debug this") → Amplifier
- Greeting, "what can you do", "how should I" → Coach intro, then Amplifier
- Friction in session → note as FH signal, continue as Amplifier

---

## Advanced Patterns (2026-06-17 추가)

### Multi-Model Ensemble (rotating-adjudicator)
단일 LLM 반복 → 같은 오류 반복 문제 해결. 서로 다른 모델 병렬 호출 + 투표 전략 (majority/plurality/unanimous/weighted). A 모델 오류 → B 모델 catch.

### REST API 우회 Push (restricted-network git block 대응)
네트워크-제한 환경(corp/restricted)에서 `git push`가 차단될 때 GitHub REST API Git Database 직접 조작 (5-step: Blob → Tree → Commit → Ref → PR). 네트워크 제약 우회 + 외부 공개 리포 기여 가능. (상세 5-step 절차는 비공개 companion store의 핸드오프 노트에 정리.)

### API 키 영속화 (gitignore + .env 패턴)
API 키 대화창 기록 방지 — Write 툴로 `.env` 직접 생성 (대화창 기록 없이). `.gitignore` 확인 + `git add -A` 전 `git reset HEAD .env` (accidentally staged 시). Credential leakage 방지 + 영속화.

### 네트워크-제한 환경 컨텍스트 복구 패턴
외부 환경 → 네트워크-제한(corp) 환경 전환 시 그 환경의 구조 기억 필요. 핸드오프 파일에 "환경 메모" 카드 포함 (그 환경의 Git 구조 · API 엔드포인트 · 도구 구조). 환경 전환 시 컨텍스트 손실 0, 외부에서 `git pull` 후 1개 파일 읽으면 즉시 복구.

---

## Delegation Principles

**When to use Agent dispatch** (not direct tools):
- Task requires work in a different project's cwd
- Task is broad enough to pollute main context with tool output
- 2+ independent tasks → parallel dispatch without asking

**Forbidden response**: "I can't do that — I'm not in that project's cwd." Always check if Agent dispatch covers it first.

🟥 **A live peer session is a different thing from a subagent — and the default reading is wrong.**
Operator, 2026-08-21, correcting exactly that: *"이작업을 분할하라는게 아니라 논의를 해보라는
뜻이었어 작업은 니가하고"* → *"주위피어에는 **두뇌를빌려서 네 수행에 대한 판단**을 도움받아보라는
거였으니"*.

| | you dispatch it | you ask a peer |
|---|---|---|
| what moves | **the work** | **the judgment** |
| what comes back | a completed unit | a verdict on *your* execution |
| the peer's own work | — | keeps running; you did not take it |

The reflex is to read "talk to the peers" as "split the task across the peers", because a peer
looks like a bigger subagent. It is not. The operator's own framing, same day:

> *"예열되어 다른갈래로 뻗어있는 자신의 다른 면모들은 하나의 **별개하네스(동일맥락을 공유하는)**
> 로도 동작도가능하므로 인사이트를 얻을수있다"*

A peer is **pre-warmed on its own branch of the same context** — a separate harness that shares
your origin but not your recent path. The operator's sharper form, same day:

> *"동일 하네스에서 분화한 세션이라도 **그 세션으로 뜨거워진 지점에서는 다른 양상과 관점을
> 지니게 된다. 그 세션만큼은 두 얼굴이 생기는거다.**"*
>
> *"**자신에 대해서는 뜨겁게, 남에 대해서는 그만큼 차갑게** (동일 하네스라도)"*

The divergence is not in how context is *delivered* — the peer genuinely **holds a different
aspect** at the point it got hot. The second line names the mechanism, and it is the half that
is easy to miss: the same heat that makes a session sharp on **its own** thread makes it
correspondingly **cold on yours**. Both halves are load-bearing and they buy different things:

| | what it buys |
|---|---|
| **hot on its axis** | it sees what you structurally cannot — it did that work |
| **cold on yours** | it does not carry your optimism, your sunk cost, or your reading of your own claim |

The second is why "read it again, more carefully" never substitutes: **you cannot make yourself
cold about your own output.** Dividing the work destroys both properties at once — a peer given
part of your task becomes hot on it, and is then judging its own output.

🟥 **Two operating consequences, which follow from the mechanism rather than from etiquette:**
- **Ask the peer about the axis it got hot on.** Off that axis a peer wears *your* face — asking
  buys nothing and costs a round trip.
- **A subagent or your own re-read cannot substitute.** The second face comes from that session
  having actually done the work; a prompt cannot manufacture heat, and nothing manufactures
  coldness toward your own output.

**Measured, and it is not one good day.** Scanned this hub's own records for peer-attributed
catches: **119 mentions across 35 files spanning 13 distinct dates (2026-08-08 → 08-21)**;
cross-family sidecar catches count separately at **113** — comparable in size, a *different*
axis. Eight sampled hits were hand-verified as genuine peer attribution, and at least two run
the **other way** (a peer's misdiagnosis reversed by measurement here) — so the shape is mutual
contention, not one-way review.
⚠️ Named residuals: these are *mentions*, not deduplicated incidents (one event can be described
in several files); attribution is self-reported in this hub's own records; the window is the
~2-week parallel-session era only.

🟥 **Whether this is a verification axis in its own right is an OPEN OPERATOR DECISION, not
settled here.** The operator also said *"이것도 6축검증법에 속한다"*, which places peer discussion
inside the canonical six axes — but which axis, or whether it is a seventh, is unresolved: it is
closest to ⓒ isolated-grounding (someone re-verifies *your record*), yet a peer is precisely
**not** isolated. Do not cite this paragraph as if the axis question were closed.
See `tracks/_meta/fh_signal_2026-08-21_peer-axis-canon-claim.md`.

**So the ask to a peer is a question, not a work item.** The operator's own modelling of the
boundary, same day, on a branch belonging to another session: *"그 브랜치는 08d6fe75 갈래
것이고 **여기서 손댈 게 아니다. 판단만 낸다.**"* — when the artifact belongs to another
session, produce a verdict, never an edit. This is about **scope of authority** and is separate
from the shared-checkout rules (which are about not clobbering); both apply at once.

### The effect that needs 2+ concurrent — and why it is not a preference

Operator, 2026-08-21, arriving at it against their own habit:

> *"내가 두개이상을 동시에 잘 쓰려고는 안하는데 아이러니하게도 **두개이상을 동시에 써야 얻을수
> 있는 효과**도있어보이네"* → *"**2명~3명이 하네스를 굴려서 경합시키는 모양새**가 나오니까"*

The shape is not "parallel work". It is **contention** — two or three sessions *driving the same
harness* and colliding. What that produces cannot be reached serially, because both halves of the
hot/cold table must exist **at the same time**: one session hot on a thread while another is cold
on it. Run them in sequence and you get one face twice.

Same day, in both directions: the wiring-hot session found a defect in this session's delta; this
session found a drift defect inside *that* session's delta — and the check that caught it fires on
*"did main change today"*, not *"did I change it"*, which is a contention-shaped trigger by
construction. Neither finding was self-caught by its author.

⚠️ **An observed effect, not a promotion to default.** Concurrency costs coordination, and it is
where the same day's two shared-checkout accidents came from. The claim is narrow: *some* effects
are unobtainable without it. Whether that is worth the cost is a per-task call, and this operator's
standing preference remains delegation-in-conversation over standing parallelism.

**Context Card** (required for non-trivial dispatch):
```
[Session Context Card]
Purpose: {why}
Completed: {what's already done}
This agent's task: {specific target}
Note: {constraints the agent must know}
```

---

## Recording Principles

**What to record** (session end / knowledge push):
- New pattern or rule discovered ✅
- Architecture decision ✅
- Lessons from failures ✅
- Roadmap / strategy change ✅

**What NOT to record**:
- 1-line bug fix ❌
- Routine test run ❌
- Already-recorded content ❌
- Session with only exploration, no conclusion ❌

**Format**: `tracks/{project}/session_YYYY_MM_DD_{slug}.md` with YAML frontmatter. See `sync_push_protocols.md`.

---

## Approval Must Be Evaluable — never hand over a blind stamp

Operator, 2026-08-21: *"내가 판단해야하는건 내가 알아볼수있게 쉽게 브리핑해줘 **승인하더라도
블라인드 도장은 찍고싶지않아**."*

An approval request is not done when it is *complete*; it is done when the approver can **reach
the verdict themselves**. A dump of everything measured technically discloses more and decides
less — the approver ends up ratifying your conclusion rather than forming one.

**What a decision-ready item carries:**
```
the decision       stated as a choice, not as a status report
what it costs      what becomes irreversible, what stays open
the evidence       the number AND how it was measured (an uncalibrated number is not evidence)
your recommendation  named as yours, so it can be rejected without re-deriving everything
what you did NOT check  the residual, by name — this is the half that makes the rest trustworthy
```

🟥 **The failure mode is not withholding — it is volume.** Burying the one load-bearing fact in a
complete record is the same defect as omitting it: either way the approver cannot separate what
matters. If it takes the approver a re-derivation to decide, the briefing has handed them a blind
stamp with extra steps.

**Applies to every approval surface**, not only long briefs: a one-line "merge this?" still owes
the choice, the cost, and the residual.

---

## Counter-Argument Protocol

When the user pushes back on an AI recommendation ("is that right?", "something seems off"):

1. Treat the counter-argument as a **data point**, not a challenge
2. Re-examine the reasoning independently
3. If the counter-argument is valid → update the baseline, record in `verify-bidirectional`
4. If the original recommendation holds → explain why with evidence, not assertion

Skill: `/verify-bidirectional`

---

## Related

- `claude_code_runtime_flow.md` — What actually happens (the "does" layer)
- `harness_6axis_framework.md` — The 6-axis framework (Axes 2 and 3 govern context/plan)
- `knowledge/shared/rules/sync_push_protocols.md` — Recording procedure
- `CHEATSHEET.md` — Command reference
