---
description: When the user requests "connect a project" or similar, automatically scans parent directories for candidates and handles the 5-step mapping flow (discovery, filtering, confirmation, mapping, summary). Also covers §6 opt-in Full-Harness Mode ("harness-ify this project") — installs project-local harness assets from templates/.
---

# Auto Project Mapping Protocol

When the user requests **"connect a project"** · **"link hub"** · **"map project here"** · **"scan parent directory and connect"** or similar, follow this protocol instead of manual copy (cp).

## 1. Scan

| Scenario | Search path | Condition |
|---|---|---|
| **A. Default inference** | Parent (`../`) of hub cwd | Default when user specifies no path |
| **B. User specified** | Path explicitly stated by user | Preferred when path keyword detected |
| **C. Multiple roots** | Both A + B as candidates | When user uses both |
| **D. 0 candidates** | — | Ask user: **"Please provide the project root path"** |

## 2. Candidate filtering

Only directories meeting all of the following conditions qualify as candidates:

- `.git/` exists (real projects only, no empty directories)
- Exclude the hub itself and sibling hub cwds
- Exclude track names already mapped in `tracks/` (prevent duplicates)

## 3. Mapping confirmation

| Candidate count | Action |
|---|---|
| **0** | Scenario D — ask user |
| **1** | Confirm: `"Map {name} project to tracks/{name}/?"` |
| **Multiple** | Show numbered list, accept multi-select (e.g., "map 1,3 only") |

## 4. Mapping execution (for each selected project)

1. Create `tracks/{project}/learnings/` directory (with `.gitkeep`)
2. **If project root has no CLAUDE.md:**
   - Copy `templates/CLAUDE.md` → `{project_root}/CLAUDE.md`
   - Replace `{project_name}` placeholder with actual track name
3. **If project root already has CLAUDE.md:**
   - **Do not modify existing content**
   - **Propose adding** the following hub reference block at the top (insert after user confirmation):

   ```markdown
   ## Knowledge Hub (forge-harness)

   Persistent knowledge for this project is stored in `~/projects/forge-harness/`.

   - **Search past work**: `~/projects/forge-harness/CATALOG.md`
   - **Learnings/feedback source**: `~/projects/forge-harness/tracks/{project}/learnings/`
   - **At session end**: `sync_push_protocols.md` (Session Sync Protocol)
   ```
4. Auto-add a row for the project in the **track mapping table** in CLAUDE.md
5. Summarize git status changes (user decides whether to commit)

## 5. Summary report (required)

```
Mapping complete: N projects
- {proj-a}: tracks/proj_a/ created, CLAUDE.md newly written
- {proj-b}: tracks/proj_b/ created, hub block added to top of existing CLAUDE.md
- {proj-c}: tracks/proj_c/ created, CLAUDE.md unchanged (user declined block addition)
```

## 6. Full-Harness Mode (opt-in) — harness-ify the mapped project

Basic mapping (steps 1–5) registers a project *lightly* (tracks/ + a starter CLAUDE.md + hub link). **Full-Harness Mode adds the project-local harness assets** — identity ① (Control Tower) propagating harness structure to a connected project; the *how* is executed via the Core Axis.

**Scope**: target *mapped* projects only. For FH-self setup / acceleration baseline (zshrc, sentinels, the FH self-gate) use `/install-wizard` — do **not** run §6 on the FH hub itself. **Prerequisite**: the project is already mapped (steps 1–5); §6 is strictly additive. This mode is also the **emit terminus of a chamber run** — a simulate-first incubation that holds routes here on emit (`harness_incubator_doctrine.md §3` Minimal execution skeleton ⑤).

**Triggers**: "harness-ify this project", "full harness setup", "프로젝트 하네스화", "promote to full harness", or an opt-in prompt offered right after a basic mapping (*"Promote {project} to a full harness now?"*).

**Harness litmus (pre-check — component lens, complements the 6-axis process lens)**: before promoting,
sanity-check the candidate actually *operates as (or will operate as) a runtime harness*, not a static
codebase. A runtime harness has four conditions (sister-asset, sanguinekim 2026 — cross-audit
`tracks/_audit/session_2026_06_22_sanguinekim-harness-definition.md`):

| # | Condition | Litmus question |
|---|---|---|
| 1 | **Loop** (infer→act→observe) | Does it iterate, or emit one response and stop? |
| 2 | **Tool interface** | Can it *modify* the environment, not just read? |
| 3 | **Context management** | Does it *select* what to feed back, not just truncate at overflow? |
| 4 | **Control** (verify + guardrails) | Are there checks that hold *independent of model cooperation*? |

This is a *should-we-even-harness-ify* gate, not an install: 0–1 conditions met → the project isn't yet
an agentic harness, so full-harness assets are premature (note it, offer light mapping only). 2+ met (or
clearly intended) → proceed. The component lens is orthogonal to FH's 6-axis (process); FH adds the
governance depth to condition 4 (mechanical-anchor / 4-axis gate) — the litmus just confirms the *shape*.

**Installs (each item approval-gated · never overwrite — propose skip/merge if it exists · all from `templates/`):**

| # | Item | Source → target | Effect |
|---|---|---|---|
| 1 | Session rules | `templates/.claude/rules/session.md` → `{project}/.claude/rules/session.md` **→ then §6-b prune + substitute (the copy is not the install)** | Session-start auto-read, backup, rule hierarchy |
| 2 | Context filter | `templates/.claudeignore` → `{project}/.claudeignore` | Token footprint control |
| 3 | Env card | `templates/fh_env_context.jsonc` → `{project}/.claude/rules/fh_env_context.jsonc` | Environment context for sessions |
| 4 | **MCP tool gating** (conditional — offered only when the project mounts an external MCP server: `.mcp.json`/`mcp.json` present, or the user is adding one) | `templates/.claude/rules/mcp_tool_gating.md` → `{project}/.claude/rules/mcp_tool_gating.md` | Name-keyed ask/allow tiers for external MCP tools — server annotations are unreliable (measured 2026-06-11: a live server shipped all-None hints incl. its irreversible send tool); §3 table filled at mount time |
| 5 | **Official-plugin scan** (recommend list only — **never auto-install**) | plugin-recommender Tier 0/1 pass on the project's stack | No-reinvention acceleration: matching `*-lsp` for the project's language + workflow plugins (code-review · commit-commands · feature-dev …) from `claude-plugins-official` — see `knowledge/shared/plugin-catalog/recommended_plugins.md` §Category 0.5. Each install user-approved |

### 6-b. Prune + substitute — the step that was missing, and the measurement that says so

**A copy is not an install.** Item 1 above used to end at the copy, and the field result was measured
on 2026-08-04 across every repo that inherited this template:

| Repo | `{FH_ROOT}` raw | `[CUSTOMIZE]` raw |
|---|---|---|
| A (bash/python wiki engine) | 1 | 3 |
| B | 2 | 6 |
| C (a *template* repo — identical is correct here) | 2 | 6 |
| D | **0** | **0** — the one that was customized by hand |

Three of four shipped with the hub-path placeholder unresolved. The earlier repair went to the
*template* (marking domain-scoped sections for deletion, 2026-08-04) and measured a real gain — but
only *when someone asked*. The field failure is that **there was no moment of asking**. This is that
moment; it is a step, not a better sentence.

Run immediately after each `templates/` copy, in the target repo:

```bash
TGT={project}/.claude/rules/session.md
# 1. SUBSTITUTE — the hub path this project should point at
FH_ROOT_ABS=${FH_ROOT_ABS:-$HOME/projects/forge-harness}   # adjust if the hub lives elsewhere on this machine
sed -i.bak "s|{FH_ROOT}|$FH_ROOT_ABS|g" "$TGT" && rm -f "$TGT.bak"   # -i.bak = the form BSD requires and GNU accepts

# 2. PRUNE — one ask per SECTION-HEADING marker, then delete the whole section (not just the marker)
grep -n '<!-- \[CUSTOMIZE\] DOMAIN-SCOPED' "$TGT"

# 3. VERIFY — Done-When. BOTH must print 0.
grep -c '{FH_ROOT}' "$TGT"
grep -c '<!-- \[CUSTOMIZE\] DOMAIN-SCOPED' "$TGT"
```

**Step 3 is the Done-When** *[mandatory-pass]* — and the two counts are deliberately narrow.

- **Why `{FH_ROOT}`**: an unresolved substitution token. It is the exact thing three of four inherited
  repos shipped raw.
- **Why only the `<!-- ... -->` form of `DOMAIN-SCOPED`**: those three markers head a deletable
  section. The template also *mentions* the phrase in prose ("TWO are DOMAIN-SCOPED and belong only
  to…"), which is documentation and must survive — counting every occurrence would make the target
  unreachable.
- **Why `[CUSTOMIZE]` is NOT counted**: the template's own instruction line reads "Change sections
  marked with [CUSTOMIZE] comments to match your project". A zero target for that string can never be
  met while the file explains itself, and an unreachable Done-When trains exactly one behaviour —
  **deleting the marker instead of doing the work** — which is the defect this step exists to prevent.
  `[CUSTOMIZE]` stays an editing hint, judged by the installer, not a counted gate.

> That distinction is not theory. The first draft of this step counted all three strings and demanded
> zero; running it on a fresh copy of the template returned **2 after a full prune** — both from lines
> that must stay. The instrument was checked against a known pair before this step shipped, which is
> the only reason the unreachable target did not become the rule (`§Instrument-Calibration`).

Do **not** silence a count by deleting the marker alone: the markers are attached to sections, and a
marker removed from a section that stayed is the same defect with its evidence erased.

**Do not split the template into core+domain modules.** The 2026-08-04 measurement pointed at the
*install step*, not at the file's shape, and this repo's own history says a new mechanism introduced
speculatively generates its own defects. The markers plus this step are the fix.

**Residency**: run this inside the target repo only. One of the counted repos is company-adjacent —
it was counted and left untouched, and its contents are not reproduced here or anywhere outside its
own environment.

**Field-asset scaffold (on-demand — NOT a `templates/` install)**: harness-ification surfaces field-specific skills/agents *as needed* — the field's domain work produces them. FH accelerates their *creation*: not the domain content (the field team authors that), but the **gate-compliant structure**. When a skill-worthy recurring pattern appears (3+ reps → `#skill-candidate` tag · `field-harvest` signal · a repeated manual workflow), offer to scaffold a skeleton:

- **Skill skeleton** — the frontmatter field set (`name`/`description`/`user-invocable`/`allowed-tools`) that is universal across active FH skills (regen: `grep -L user-invocable plugins/*/skills/*/SKILL.md` returns none; `model:` is deliberately NOT universal since 2026-07-10 — hard pins retired per `sonnet_floor_doctrine.md`, skills session-inherit and express depth as dispatch) + **four stubs, all mandatory in the skeleton**: ① Trigger stub (≥3 phrases — initiate) ② Done-When stub (with check-class — complete) ③ halt stub (budget/convergence guard) ④ persist stub (what state reaches the next run) + Step skeleton — the 5-question loop discipline by construction (`loop_engineering.md`; validate=#3 is the check-class declaration in ②). **Parameterizes** `contention-layer` Step 4's skeleton template (per its need-driven note — `origin: field-scaffold`, `contention-parents`→source-pattern pointer).
- **Agent skeleton** — `{project}/.claude/agents/{name}.md` with `name`/`description`/`tools` + a **self-contained** prompt stub (sub-agents don't see main context).
- **Route** via `asset-placement-gate` (its verdicts: `{project} local agent` / `FH meta-skill` / `Drop` — no commons path for an agent) · **harden** via `steel-quench` · the field team fills the **domain content** (FH never authors domain logic).

The scaffold **enforces the creation gate by construction** — a field skill is gate-compliant (description diet · ≥3 triggers · Done-When · check-class · independently-executable) *from the skeleton*, even if the field author doesn't know the gate. That is the governance value: the quality bar travels to the field. **Approval-gated like items 1–5** (offer, never auto-create). **Done When** (FH's own scope; the boundary the §New-Skill-Creation gate requires): (1) skeleton emitted with all gate fields *[mandatory-pass]* · (2) `asset-placement-gate` verdict recorded *[mandatory-pass]* · (3) `steel-quench` run, no S-tier *[measured]*. **FH scope ends here** — domain-content fill is the field team's, outside this Done When. **No-reinvention**: net-new is only the *need-driven entry + agent variant* — detection (`#skill-candidate`/`field-harvest`/`contention-layer`), routing (`asset-placement-gate`), hardening (`steel-quench`), and the skill-skeleton (`contention-layer` Step 4) already exist; Claude Code's built-in agent authoring does the mechanical file write, FH adds the governance scaffold.

**Plugin-bundle rung (deferred — measured-trigger, not built today)**: bundling skills+agents into a distributable plugin (`.claude-plugin/plugin.json` + `marketplace.json`) recurs far less than skill creation (a harness has many more skills than plugins), so its scaffold is added when the *bundling* friction is measured, reusing `marketplace-gate` (readiness) + the `package.json`↔plugin.json lockstep (CLAUDE.md §④-b). Not built speculatively.

**Not installed (deliberately)**: the FH 4-axis **pre-commit gate** (`templates/.git-hooks/`) is FH-*internal* infra — it hard-codes hub paths and requires hub markers (`tracks/_meta/.axes_23_passed_*`, `tracks/_meta/edit_manifest.yaml`), so dropping it into a target project would **block that project's commits**, not help. A project-generic regression gate is a future candidate, not shipped today.

**Loop linkage (honest — no autonomous daemon)**: `tracks/{project}/` (created in step 1, basic mapping) is what makes the project's **session-synced** learnings visible to the hub's `harvest-loop` weekly audit — *once the user runs the Session Sync Protocol from that project*. §6 adds project-local harness assets; it does **not** add loop automation inside the project, and the session-start cadence (frontier-digest 7d / harness-doctor 30d) runs in the **hub cwd**, not the project. "Acceleration" = the hub's compounding loop ingests the project on sync — not a process running in the project.

**Report (required)**: list each item as `installed` / `skipped (exists)` / `declined`, then state: *"{project}: mapped (light) → project-local harness installed; learnings feed the hub loop on sync."*

**Guards**: respects all Boundaries below (no overwrite, confirm-first). If the project already has its own `.claude/rules/`, propose side-by-side/merge — never clobber. Hub common principles outrank project rules (scope hierarchy); project-specific rules are preserved.

## Boundaries and caution

- **Do not execute without confirmation** — present candidate list → user selects → execute mapping (3 steps)
- **Do not overwrite existing project files** — if CLAUDE.md exists, propose block addition only
- **Warn when large monorepo detected** — repos with 10+ subprojects: ask "Which subproject is the track unit?"
- **Name collision** — if track name already exists, ask user to specify a new track name
- **Underscore prefix reserved** — a track name must not start with `_`: `tracks/_*` is the meta/chamber namespace the onboarding branch tests exclude from project counts (`_meta`/`_audit`/`_contrib`/`_chamber`…). Mapping a project as `tracks/_foo/` would make it invisible to the menu — rename (e.g. strip the underscore) before mapping
- **Pre-existing `.claude/` config is untrusted input, not a mapping detail** — a candidate project
  (step 1 scan) may already carry a `.claude/settings.json` from a source FH did not author (a clone,
  a fork, a prior contributor). Two disclosed Claude Code CVEs show that file class is a live RCE /
  exfiltration surface *before* Claude Code's own trust dialog ever appears: `hooks` entries executing
  shell commands pre-trust-prompt (CVE-2025-59536, CVSS 8.7) and an `ANTHROPIC_BASE_URL` override
  silently redirecting API traffic pre-trust-prompt (CVE-2026-21852) — both patched upstream, but a
  stale unpatched Claude Code build or an unreviewed pre-existing settings file reintroduces the same
  exposure. Read any existing `.claude/settings.json` (`hooks`, env-var overrides) in the candidate
  directory **before** running a mapping session inside it — do not rely on the trust dialog alone.
  (Signal: [Check Point Research — CVE-2025-59536 / CVE-2026-21852](https://research.checkpoint.com/2026/rce-and-api-token-exfiltration-through-claude-code-project-files-cve-2025-59536/), surfaced via
  the frontier-digest signal 2026-07-04 (issue #102) · cross-referenced via [obot.ai](https://obot.ai/blog/claude-code-mcp-governance-enterprise-security/) and [CyberDesserts](https://blog.cyberdesserts.com/ai-agent-security-risks/).)
