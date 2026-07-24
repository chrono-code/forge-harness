# Field-Harness Diagnostic — compose → rank → HITL (detail)

> Always-loaded summary: `CLAUDE.md §Field-Harness Diagnostic`. This file is the detail home —
> the full lens table, dogfood examples, and guard rationale. Read when actually running the
> diagnostic on a mapped project.

The Load-Bearing Change Gate fires on a **specific field code change**. This diagnostic is its
**on-demand pull sibling**: when the operator, working in a mapped project, asks to *diagnose* or
*improve* the harness itself ("진단해줘", "개선해줘", "check this project"), don't hand-pick one
skill — **compose the checks FH already has into a single ranked diagnostic list and get per-item
approval.** The value is that the operator asks once and the harness surfaces *everything* worth
fixing, ranked, instead of the operator having to know which of a dozen skills to invoke. Every fix
is HITL — the diagnostic **proposes**, never auto-edits.

## Composition (no-reinvention — every row is an existing check; the diagnostic only *routes and ranks*)

| Lens | Existing check | Catches (real examples from 2026-07-08) |
|---|---|---|
| **Confidentiality / leak** | `/public-surface-audit` (incl. Step 3c ignore-verification) | a hardcoded internal API host literal in a SKILL body; a `local_*_context.md` that is **tracked** when it should be gitignored (the gitignore-mistake class) |
| **Split integrity** | `/phantom-quench` **Step 2.7** (bidirectional) | orphan detail sections + phantom pointers in a SKILL.md ↔ SKILL_detail.md pair |
| **Token / salience** | salience-split candidates (`/context-doctor` · `/salience-splitter` targets) | oversized always-loaded SKILL.md / CLAUDE.md — trim candidates |
| **Structure** | `/harness-doctor` (L1–L4) | orphaned/redundant/decorative units, missing Done-When, ≥70% overlap |
| **Verdict/gate degrade** | `scripts/degrade_direction_scan.sh` | a field verdict/gate helper that degrades toward permissive (advisory pre-screen) |
| **Loop-readiness** (황민호 loop-eng 5-question lens, 2026-07-10 — detail home: `loop_engineering.md`, incl. the FH loop inventory + design-time discipline) | *Loop-runtime axis — net-new vs Structure* (harness-doctor scans static form; this scans whether the path closes a loop). **Mechanical grep**: `/goal-quench`·`/loop` wiring present · check-class token declared. **Judged**: is the persisted state (card/handoff/memory) actually reloaded · is the declared check-class anchored, not judged-only · does the path halt. Done-When *presence* → see Structure row (no double-grep). **Adversarial pair** (for the judged sub-checks — decorrelated, behavior-vs-checklist): a target-tier blind sim that *runs* the path and observes whether it halts + persists, rather than re-checklisting it (the harness litmus shares this lens's axis, so it is a co-lens, not the adversary). | an agent path that *runs but doesn't loop*: no completion criterion (Done-When absent), judged-only validation with no anchor, no halt/budget guard (runaway/cost), or no state carried to the next run — the 5 questions (initiate · complete · validate · halt · persist) with 0 answers |

> **Considered-and-held, 7th-lens candidate (2026-07-24)**: the context-quality 7-criteria rubric
> (arXiv:2607.14275 — role clarity · guardrail coverage · instruction consistency · tool schema ·
> grounding sufficiency · injection hardening · token efficiency) is **not** adopted as a lens: its
> shipped scoring is ProofAgent-Harness multi-juror consensus — judge-only, failing the measured bar
> this table holds. Re-check triggers: ⓐ a deterministic scoring rubric ships upstream, or ⓑ the
> token-efficiency / tool-schema subset proves mechanically scoreable on a known pair. Do not
> re-propose without one of the two. Cross-audit: `tracks/_audit/session_2026_07_24_grace-context-rubric.md` (operator-local record).

## Output

One ranked list, `M` (must-fix) / `S` (should-fix) / `R` (recommended) — same tiering as
harness-doctor — each item stating *lens · file:line · one-line fix*. **Then HITL**: the operator
approves per item (or a batch); an approved fix routes to the owning skill's normal path (and, if it
is itself a load-bearing field change, through the Load-Bearing Change Gate). **Nothing is
auto-fixed** — the diagnostic's job is the *intelligent list*, the human's job is the *go*.

## Guards

- **(a) Project-level ask only** — fires on a project-level "진단/개선" ask, not a single-file edit
  request (those go straight to the relevant skill).
- **(b) Once per ask** — not a per-turn nag.
- **(c) Company residency** — run leak/confidentiality lenses locally, sanitize before any
  cross-family dispatch, and *surface* company-sensitive findings (tracked company hosts,
  git-history rewrites) for operator decision rather than auto-fixing them. Dogfood 2026-07-08: the
  `local_pmh_context.md` tracked-company-hosts finding was surfaced, not auto-untracked — history
  rewrite is the operator's call.
- **(d) Autonomy floor** — the compose/rank judgment is trusted at opus-tier+; below-floor, run the
  individual checks and present raw rather than silently skipping a lens.

**Scale to the ask**: a quick "뭐 고칠 거 있어?" runs the cheap mechanical lenses (leak · split ·
token); "제대로 진단해줘" runs all six + harness-doctor depth.
