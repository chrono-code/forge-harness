---
name: harvest-loop
description: An 8-step self-evolution pipeline that runs after field sessions end (field-harvest → contention-layer → challenger + persona-innovator → synthesizer → Critic agent → harness-doctor → verify-bidirectional → curator), absorbing session learnings back into the FH ecosystem. Runs automatically at session end in the main dev environment; proposes execution first for external users. Triggered by "session harvest", "learning absorption", "fh evolution", or "harvest-loop". (The phrase "run the pipeline" is ceded to pipeline-conductor — use that for end-to-end verification sweeps.)
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Grep", "Glob", "Agent"]
model-note: session-inherit — Sonnet base is first-class (sonnet_floor_doctrine.md); depth-critical judged steps route to dispatch (opus agent / cross-family sidecar, consent-gated), never a substrate requirement
---

# harvest-loop — Field Session → FH Self-Evolution Pipeline

> Automatically absorbs patterns/conflicts/discoveries from field sessions back into the FH ecosystem.
> Internalizes as a pipeline the return loop from field projects to the harness that was previously done manually.
> One of the core functions is real-time detection and blocking of **Semantic Drift** — where agent terminology gradually diverges in meaning as sessions grow longer.

## Operation Modes

| Mode | Description | Trigger |
|---|---|---|
| **Forced mode** | Auto-runs at end of local development session. Executes without approval, only confirms final suggestions | Session wrap-up rules in hub CLAUDE.md |
| **Lightweight mode** | Immediate harvest after Wave completion. Skip Steps 3/3.5/4 — prioritize fast recording | agent-composer Step 4-c (2+ new files or 3+ existing files changed, **or M-tier resolved**) |
| **Proposal mode** | External FH users — confirms "run harvest-loop?" before executing | User utterance or `/harvest-loop` |

**Simplification guard**: Sessions that only browsed/explored (no code changes or outputs) auto-skip even in forced mode.

**Lightweight mode Done When**:
```
Step 0 (Regression Guard) + Step 1 (field-harvest) + Step 2 (contention-layer) + Step 5 (verify-bidirectional) complete
+ record artifact path printed + final `Verdict:` line emitted — lightweight mode promises the SAME
  consumer contract as full mode (agent-composer Step 4-c gates on artifact + verdict; codex M1 2026-08-10)
+ harvested pattern summary 1~3 lines output
+ "run full harvest-loop?" proposed (if patterns found)
+ [Card update prohibited] Do NOT update reference_next_session_starter.md in lightweight mode alone
```

**Early Trigger** (mid-session): Same pattern 3+ times · same skill fails 2+ consecutive times · session 2+ hours elapsed → "Early harvest condition detected. Run mid-session harvest?" If Y → field-harvest → contention-layer → verify-bidirectional only.

---

## Pipeline Structure

```
Session end
    │
[Step 0-a] FH asset change detection → auto-quench
    │  git diff --name-only HEAD | grep -E "SKILL\.md|\.claude/rules/|knowledge/shared/rules/|templates/|CLAUDE\.md"
    │  → 1+ FH assets changed: run full 3-axis gate
    │  → No changes: proceed to Step 0-b immediately
    │
[Step 0-b] Card cross-check — reconstruct completed items (no memory dependency)
    │  Read reference_next_session_starter.md + fh_completed_{today}.md + git log
    │  → Generate removal candidate list from 3-source cross-check
    │
[Step 0-c] Edit Manifest Verification + Memory Hygiene
    │  edit-manifest VERIFY: check pending predictions in edit_manifest.yaml
    │  memory-hygiene scan: staleness check on memory/*.md entries (skip if < 7 days)
    │
[Step 0-d] Session Retrospective (close_retro 가 granted 일 때만)
  🟥 새 스킬을 만들지 않는다 — 회고 산출은 그대로 Step 2(contention-layer) → Step 3 → 3.5(등급)
     로 **이미 있는 파이프라인**을 탄다. 「개선포인트 정리」가 거기서 공짜로 붙는다.

  진입 조건 (기계적, 이 순서로):
    1. `tracks/_meta/user_adaptation_profile.md` frontmatter 의 `close_retro`
         granted  → 실행
         declined → 건너뛴다. **다시 묻지 않는다**(operational_adaptation.md no-re-nag)
         unset / UAP 부재 / ephemeral → **실행하지 않고, 지어내지도 않는다.**
           운영자 맥락이면(= `CLAUDE.local.md` 존재, `psa_detect_operator_context()` 와 같은
           판별자) **최초 마감 1회만** 제안하고 답을 UAP 에 기록한다. 그 이상 묻지 않는다.
    🟥 `CLAUDE.local.md` 존재가 판별자인 이유는 그것이 **gitignored** 라 fresh clone·CI 체크아웃·
       워크트리 어디에도 안 따라오기 때문이다. 기각된 후보: 「tracks/_meta 가 비어있지 않음」 —
       `.gitkeep` 이 tracked 라 **fresh clone 이 만족시킨다**(psa_scan_lib.sh 주석의 실측).
    🟥 **운영자 맥락이라고 자동 granted 가 아니다.** 파일이 존재해서 승인되는 게 아니라
       **운영자 발화가 인용돼 기록되는 순간** 승인된다. 전자는 세션이 자기 권한을 넓히는 형태다.

  산출: 오늘자 `tracks/_meta/fh_signal_{date}_{source}.md` 에 `retro: close` 를 달고
        `## Session Retrospective` 4필드를 채운다(형식 정본 = fh_detail_protocols.md).
        「없음」·「0」도 유효한 값이고, **비우는 것만 안 된다.**

  Done When:
    + 오늘자 signal 파일이 존재하고 `retro: close` 를 달고 있다              — mandatory-pass
    + Session Retrospective 4필드가 전부 채워졌다                             — mandatory-pass
    + 정정 건수는 **세었지 회상하지 않았다**                                   — measured
    + FH Registration Candidate 가 비면 그 이유가 한 줄 적혀 있다             — mandatory-pass

  ⚠️ `session_close_check.sh` 에 기계 검사를 **붙이지 않는다.** 값싸게 붙일 수 있는 형태는
     «오늘자 signal 이 있나» 인데 그건 *존재*만 재고 *회고했나*는 못 잰다 — CLAUDE.md 가 ④ 메모리
     위생에 대해 같은 이유로 검사를 뺐다(«a check that can be satisfied without doing the work
     is a decoration»). 같은 판단을 그대로 적용한다.

[Step 0] Regression Guard
    │  Check: does anything from this session conflict with or regress a validated skill?
    │  → Regression detected: flag, route to contention-layer
    │  → No regression: proceed
    │
[Step 1] field-harvest
    │  Scan field git diff / outputs → extract patterns (proceed if 3+, skip if fewer)
    │
[Step 2] contention-layer
    │  Compare patterns ↔ existing FH skills → collision = new skill candidate signal
    │
[Step 3a] challenger (Agent)     [Step 3b] persona-innovator  ← parallel
    │  Attack existing skills         Propose new skill candidates
    │
[Step 3.5] synthesizer
    │  Cross-synthesize attack ↔ proposal → readjust grades (HIGH/MED/LOW)
    │
[Step 3.75] Critic (isolated Agent — SAGE pattern)
    │  Independent critique of synthesizer proposals → PASS / CONDITIONAL PASS / FAIL
    │
[Step 4] harness-doctor
    │  Health check when adding candidates (Done When exists? ≥70% overlap?)
    │
[Step 5] verify-bidirectional
    │  Bidirectional consistency check on candidate skill
    │
Output final proposal list → Y: PR creation / N: persist to tracks/_meta/fh_signal
    │
[Step 6] Curator lifecycle review (auto-run after Y)
    │  SKILL.md STALE/merge candidates + Memory self-correction
```

---

## Execution Instructions

### Step 1 — field-harvest
`/field-harvest --since 1d` — Fewer than 3 patterns → auto-skip + output "no session harvest targets".

### Step 2 — contention-layer
`/contention-layer [field-harvest output patterns]`

| Collision type | Routing |
|---|---|
| Overlaps with existing skill | Existing skill enhancement candidate |
| New area not covered | New skill candidate |
| Two skills conflict | Mediation skill candidate |

### Step 3 — Parallel challenger + innovator
**3a challenger**: "Does this discovery overturn existing skill X?" / "Doesn't existing skill already handle this?" / "Does adding this simplify or complicate FH?"
**3b innovator**: Field pattern → abstraction → naming candidates + Done When draft required.

### Step 3.5 — synthesizer

| devil attack | innovator proposal | synthesizer verdict |
|:---:|:---:|---|
| S-tier attack | Proposal for that area | **HIGH** — immediate reflection candidate |
| S-tier attack | No proposal | **HIGH** — fix existing skill weakness immediately |
| No attack | Proposal exists | **MED** — re-review in next wave |
| Attack overturns proposal | — | Proposal **rejected** — persist as fh_signal on hold |

**Fallback** (deep-insight not installed): Inline synthesis. Apply same judgment matrix. If quality low → Step 3.75 Critic processes as CONDITIONAL PASS.

**Step 3.5-X** (optional): Cross-session 2nd validation when 2+ HIGH-grade items exist. External CLI (gemini/codex) or cross-session Claude. Items flagged as over-promoted → downgrade HIGH → MED. External CLI availability is resolved via `knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Sidecar Engine Resolution Protocol` (Tier 1→2→3; Tier 3 = cross-session Claude — no hard-fail when no external CLI exists).

> **Detail**: See `SKILL_detail.md §Step3-5X` — bash execution scripts for external CLI and cross-session Claude fallback — read when running Step 3.5-X validation.

### Step 3.75 — Critic (Isolated Agent)

> Isolation = the Critic does not inherit the synthesizer's reasoning chain. **This is an FH design
> decision, not a borrowed one.** Its evidence is arXiv 2605.00914 (*The Cost of Consensus*): plurality
> voting discards correct answers already present in the pool (oracle gap ≤32.3pp) and peer rationales
> destabilize previously-correct reasoning (≤70.0%) — so the reviewer must not stand inside the
> generator's chain. *Corrected 2026-08-11: this line previously cited SAGE (arXiv 2603.15255) as the
> isolation source. SAGE's four agents **co-evolve from a shared backbone** — the opposite structure.*

Critic evaluation: Done When logic validation · failure mode exploration (2+ edge cases) · claim vs. implementation alignment · scope appropriateness (Too Narrow / Too Broad).

FAIL routing: First FAIL → 1 re-synthesis allowed. FAIL after re-synthesis → auto-persist as `fh_signal` on hold. Maximum retries: **1**.

> **Detail**: See `SKILL_detail.md §Step3-75` — Critic isolated Agent() call format, evaluation items table, FAIL routing, Post-Core-Skill Critic connection — read when executing Step 3.75.

### Step 4 — harness-doctor
`/harness-doctor --scope new-candidates` — Check: Done When exists · ≥70% overlap with existing skills · self-reference structure.

### Step 5 — verify-bidirectional
`/verify-bidirectional [new skill draft]` — If A references B, does B back-reference A?

### Step 6 — Curator Lifecycle Review

**6-1 SKILL.md Lifecycle**: 30+ day unused → [STALE] candidate. `pinned: true` → never touch. ≥70% overlap → merge candidate suggestion. **> 300 lines AND no `SKILL_detail.md`** → propose `/salience-splitter` (governance-semantic split — not compression; the grew-through-harvest pattern is a natural split trigger).

**6-1-a Archive-candidate auto-tag**: When 0 invocations in 30 days detected (cross-check `tracks/_meta/skill_usage.md`), auto-append `#archive-candidate` tag to that skill's CATALOG.md entry. No file deletion — tag only. User reviews tagged entries at next session start.

**6-2 Memory Self-Correction**: INDEX-ORPHAN (in MEMORY.md but file missing → auto-remove) · FILE-ORPHAN (file exists, not indexed → confirm with user) · MEM-STALE (30+ day unmodified → confirm with user).

**Memory curator safety**: Only INDEX-ORPHAN removal is auto-allowed. Actual file deletion absolutely prohibited without explicit approval. `type: reference` items with 🔑 keywords excluded from STALE detection.

**6-a Skill Usage Leaderboard**: Record skills called this session in `tracks/_meta/skill_usage.md`. Flag 4+ weeks no-call → deprecation candidate.

**6-b Harness Evolution Cadence** (4-week cycle): Scan skills with `complexity_routing`. Aggregate escalation records from `fh_signal_*.md`. Valid conditions = keep; never activated in 4 weeks = removal candidate; pattern in fh_signal = addition candidate. No auto-modification — output candidates then require user approval.

> **Detail**: See `SKILL_detail.md §Step6-Detail` — bash scripts for STALE detection, memory scan, skill usage leaderboard, evolution cadence aggregation — read when executing Step 6.

---

## Observability Hook (glass-box self-improvement)

Every evolution decision must leave a 3-part trace in `tracks/_meta/edit_manifest.yaml`:
- **(a) what changed** — file + diff summary
- **(b) predicted effect** — `predicted_impact` + `predicted_measurable_by`
- **(c) verify checkpoint** — `validation_status` flipped at next Step 0-c VERIFY

A proposal accepted without a recorded prediction is a black-box edit — flag, do not silently apply.

> **Detail**: See `SKILL_detail.md §Observability` — full observability hook spec and trace format.

---

## Output Format

```
## harvest-loop Execution Results

Session: [date] [project name]
field-harvest: [N patterns extracted]
contention-layer: [N collision signals]
synthesizer: [HIGH N / MED N / rejected N]

### Final Proposals (sorted by synthesizer grade)
| # | Type | Target | Grade | devil | innovator | synthesizer verdict |
|:---:|---|---|:---:|---|---|---|

→ Y: Create PR / draft skill file
→ N: Persist to tracks/_meta/fh_signal_YYYY_MM_DD_{slug}.md

### [Required final step] Session card update (proof gate)
Read reference_next_session_starter.md → apply Step 0-b removal list → add new priorities
→ output "BEFORE N items → AFTER M items (removed: [list])" — required
→ No diff (N=M) = warning + Step 0-b re-check obligation

**Natural-language close (4th source)**: Even without git log match, items with these patterns stated in session → treated as closed, remove immediately:
- "not possible / confirmed impossible" · "no response + N weeks elapsed" → abandoned
- "mutual citation confirmed" · "merged" · "cancelled" · "no longer needed"
- User says "stop monitoring" · "close this" · "remove it"
```

> **Detail**: See `SKILL_detail.md §Output-Detail` — 2-source mode (when fh_completed absent), exact match criteria, natural-language close edge cases — read when reconstructing session card without fh_completed file.

---

## Linked Skills

| Situation | Linked skill |
|---|---|
| 3+ new skill candidates | `/agent-composer` for dispatch plan |
| Design existing skill enhancement direction | `/meta-prompt-builder` |
| Validate candidates from external user perspective | `fh-meta:hub-persona-auditor` |
| Review before sharing with team | `/apex-review` |
| Self-marketing pattern discovered as HIGH P10 | `/harness-doctor --lint` auto-propose |
| Edit predictions to verify / rejected buffer | `fh-meta:edit-manifest` (Step 0-c) |
| Stale memory entries to re-verify | `fh-meta:memory-hygiene` (Step 0-c) |

---

## Done When

```
All stages Step 0-c → 0 → 1 → 2 → 3 (parallel) → 3.5 → 3.75 → 4 → 5 complete
+ Step 0-c: edit-manifest verdict received (rejected buffer non-empty → surfaced as an
  Observability flag in the final list, never silently passed) + memory-hygiene scan run
  (scheduling-only — callee self-contained via its own HITL; no verdict folds back BY DESIGN,
  declared here so the absence reads as intent, not omission)
+ Step 3.75 Critic verdict received (PASS/CONDITIONAL PASS/FAIL stated) before Step 4
+ Step 4 harness-doctor verdict received — M-tier findings demote/separate the affected
  candidates (same routing as Critic FAIL), never proceed unread
+ Step 5 verify-bidirectional verdict received — FAIL (= baseline requires redesign) routes the
  affected baseline to redesign, never into the proposal list
+ synthesizer grade readjustment complete (rejected candidates separated)
+ Final proposal list output (sorted by HIGH/MED)
+ User Y/N approval gate complete
+ (If Y) Step 6 Curator complete
  → 6-1: STALE candidate list + merge candidates
  → 6-2: INDEX-ORPHAN/FILE-ORPHAN/MEM-STALE detection results
+ [Required] reference_next_session_starter.md delta update complete

**Typed verdict — the last output line, consumed by callers (pipeline-conductor Step 1 ·
agent-composer Step 4-c):**
`Verdict: PASS` (all steps green) | `CONDITIONAL_PASS` (sub-threshold skips/held patterns — list
them on the same line) | `FAIL` (Critic FAIL unresolved after one re-synthesis · drift detected) |
`ESCALATE` (operator decision required). Callers gate on this line, not on prose — harvest-loop
was the only core pipeline skill without a typed verdict and made 5 chains fire-and-forget
(return-path audit 2026-08-10). **The `Verdict:` line is the FINAL output line — emit nothing
after it; consumers read a missing/malformed final `Verdict:` line as `ESCALATE`, never as pass.**
  → BEFORE N items → AFTER M items diff output required (proof gate)
  → No diff (N=M) = warning + Step 0-b re-check
  → Completed items remaining = bug (Done When not met)
```
