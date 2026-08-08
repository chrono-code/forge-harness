# Onboarding / Acceleration Autopilot — discover → compose → rank → install-HITL (detail)

> Always-loaded summary: `CLAUDE.md §Onboarding / Acceleration Autopilot`. This file is the detail
> home — the full Phase-0 branch logic (including the chamber / simulate-first honesty boundary),
> provenance, and guard evidence. Read when executing the autopilot on an onboarding or
> acceleration door.

The **install-direction twin of the Field-Harness Diagnostic**: same `compose → rank → HITL`
engine, but it decides *what to install/wire* instead of *what to fix*. When the operator enters an
onboarding / acceleration door (returning-menu ①②③: "새 프로젝트", "하네스 작성/작성해줘",
"이 프로젝트 가속화", "harness-ify", "accelerate this project"), don't hand-run one skill —
**auto-discover the local state, let the innovator center a recommend cascade, produce a ranked
install plan, and gate every install.**

## Flow

1. **Phase 0 — State Audit + branch (auto-discovery)**: read the target's existing
   `.claude/agents|skills`, `CLAUDE.md`, mapped `tracks/`, **locally-connected sibling repos** (the
   env-delta SessionStart hook already emits "N unmapped sibling repos"), and the
   `LOCAL_SKILL_REGISTRY` + stack/language. Then **branch**: *new-build* (no prior harness) ·
   *extend-existing* (harness present → found→extend, never fork) · *maintain* (mature harness →
   route to the Field-Harness Diagnostic instead).

   **New-build sub-branch — simulate-first (incubator doctrine)**: judge the project's character
   before building. Clear · small · low failure-cost → build immediately (current flow). Uncertain ·
   exploratory · failure-expensive → **flag simulate-first as an option**: doctrine says such a
   project *should* be chamber-simulated before emit. The chamber **run orchestration is wired**
   (`scripts/chamber_run.sh` — an intent-driven, resumable 7-step runner: budget-entry cap,
   ≥3-blind-persona gate, Emission Gate, G4 ledger auto-append; run #3 exercised it 2026-07-14).
   But a **live one-command autonomous simulate→EMIT of a field harness is NOT yet a capability**:
   step-4 persona dispatch is human/Claude-driven (bash cannot spawn the isolated Agents — the
   honest muscle boundary), the EMIT terminus is HITL, and **EMIT has never fired — the ledger's
   real runs are honest KILLs** (the chamber overwhelmingly *screens* — 9 full runs, 8 KILL, 1 EMIT, hand-counted 2026-08-08; it has
   birthed once, but that run left no intent/budget/persona artifacts so the formal flow is not what
   produced it, and the first end-to-end formal run KILLed). So today this
   branch = a one-line HITL recommendation to run the chamber (`chamber_run.sh`), then fall back to
   Full-Harness Mode §6 (`auto_project_mapping.md`) for the actual onboarding; the runner gates and
   records a human-driven run — it must **not** be presented as a push-button autonomous emit. The
   same branch applies to a **new capability of an existing harness** — the
   incubate-in-chamber-then-transplant flow is likewise run-orchestrated but not autonomously
   emitting today. Rationale + economics:
   `knowledge/shared/harness-core/harness_incubator_doctrine.md §3`.

   This audit-and-branch pre-step is imported from the revfactory/harness Phase-0 State Audit
   (sister-audit 2026-07-07) — it tightens FH's found→extend reflex and is the "이미 로컬에 연결돼
   있으면 자동 탐색" mechanism.

2. **Innovator-centered recommend**: `persona-innovator` centers the cascade (Mode I on
   acceleration / Mode F on FH-dev), composing `plugin-recommender` (Tier 0 platform → Tier 1
   official → Tier 2/3) + `cross-ecosystem-synergy-detection` (locally-connected skills worth
   wiring) + inferred technical level (conversation-cue read, also imported from revfactory) to
   shape *what* and *how much*.

3. **Ranked install plan**: one list, `M`/`S`/`R`, each item = *what · why · source (Tier 0
   built-in / Tier 1 official / local sibling / FH scaffold) · exact install command*.
   No-reinvention: an official/built-in that covers the need ranks above a net-new scaffold.

4. **Install — HITL, non-overwriting**: per-item approval; **never clobber an existing `.claude/`**
   (propose merge/skip if present — this is FH's edge over revfactory's post-plan auto-write and
   harness-100's raw `cp`). Any generated/installed FH asset runs the **4-axis gate**; a field
   scaffold runs `asset-placement-gate` + `steel-quench`. **"끝까지 해줘 / 자율로 완주" →
   full-autonomy**: run the whole plan under the `/goal-quench` budget+quality gate (token cost
   accepted by the operator), still non-overwriting and still gated per asset — autonomy removes
   the per-item *prompt*, never the *gate*.

## Guards

- **(a) Non-overwriting is inviolable** — the one thing both revfactory surfaces get wrong; FH
  proposes merge, never clobbers.
- **(b) No-reinvention** — Tier 0/1 first, scaffold only what adds governance.
- **(c) Company residency** — discovery of a company sibling repo surfaces it, does not
  auto-map/leak it; promoted to a machine field (`residency` on the skill registry,
  `fh_detail_protocols.md §1-c`) so any derived recommendation naming a `company` /
  `operator-private` entry lands only in gitignored `tracks/_meta/` or the private companion store,
  never a tracked public file (chamber run #7, 2026-07-14 — the guard was prose-only and the field
  didn't exist).
- **(d) Autonomy floor** — the discover/rank judgment is trusted at opus-tier+; below-floor,
  present the raw recommend and ask.
- **(e) Once per door-entry** — not a per-turn nag.

This is the door ③ (accelerate; a *diagnose* intent on the same door routes to the Field-Harness
Diagnostic instead) engine and the new-project/harness-write path made autonomous —
the operator asks once and the harness discovers, ranks, and (on request) installs everything worth
wiring.
