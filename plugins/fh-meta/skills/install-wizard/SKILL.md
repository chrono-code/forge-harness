---
name: install-wizard
description: Run when setting up a new project for the first time or onboarding after installing FH (first setup, initial configuration, onboarding start, configure project, help me set up). Performs environment detection → gap diagnosis → item-by-item suggestions → user approval → execution → acceleration baseline setup in sequence. Use --dry-run to output diagnosis report only (bg dispatch compatible).
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep", "Edit"]
model-note: session-inherit — Sonnet base is first-class (sonnet_floor_doctrine.md); depth-critical judged steps route to dispatch (opus agent / cross-family sidecar, consent-gated), never a substrate requirement
category: Composability Gate
---

# install-wizard — Onboarding Setup Wizard

> ⚠️ **Prerequisite — Read first if this is your first install**
>
> This skill is available **after the fh-meta plugin is registered in Claude Code**.
> If you type `/install-wizard` and CC doesn't respond, the plugin hasn't been registered yet.
>
> **When running Claude Code from the FH directory**: the AI detects the MISS automatically
> and installs the plugin via Bash — no manual input needed. Just say "install the plugin."
>
> **Manual fallback (if needed):**
> ```bash
> claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
> claude plugin install -s user fh-meta@forge-harness
> ```
> After install, if `install-wizard` appears in `/skills` list in CC chat, you're ready.
> See `README.md > Advanced Settings > Plugin Install` for detailed guide.

Run immediately after cloning forge-harness (FH), or when setting up a new project for the first time.
Sets up the periodic-audit notification structure: a permanent zshrc hook (`fh_audit_check.zsh`, runs on terminal start) plus FH's session-start mtime detection. Both surface a weekly-audit reminder when 7+ days have elapsed since the last `weekly_audit` — no persistent cron is used (a session-scoped scheduler cannot survive to fire on a later day).

## Key Terms

| Term | Definition |
|---|---|
| **sentinel** | An empty file that records whether a specific event (audit complete, install complete, etc.) has occurred. Created in `~/.cc_sentinels/`. |
| **zshrc hook** | Shell function added to `~/.zshrc`. Automatically runs on terminal start and applies permanently. |
| **session-start detection** | FH's durable weekly-audit cadence — at session start the mtime of the latest `weekly_audit_*` is checked and `/harvest-loop` is proposed if 7+ days elapsed (see CLAUDE.md Cadence Rules). No persistent scheduler required. |

## Execution Modes

| Mode | Trigger | Action |
|---|---|---|
| **Normal mode** (default) | `/install-wizard` | Gap diagnosis → per-item approval → execution → zshrc/sentinel install (interactive) |
| **Analysis mode** | `/install-wizard --dry-run` | Gap diagnosis + report output only. No approval gate or execution. bg dispatch compatible |

> On `--dry-run`, outputs Step 2 report then skips Steps 3~4 and exits early.

## Core Principles

- **Propose-First**: Show proposal list and get approval before any changes
- **Per-item approval**: Select each item individually (Y approve / N skip / L later)
- **Double-confirm irreversible changes**: Preview before file writes and zshrc modifications
- **User review before PR creation**: Output PR parameters (title, base branch, included files, body) and get approval before execution. No automatic submission.
- **Periodic audit structure setup**: zshrc hook (permanently applied on terminal start) + sentinel initialization + session-start mtime detection (7-day threshold)

## Execution Steps

> Overall flow summary (guide for first-time readers):
>
> | Stage | Name | Condition |
> |---|---|---|
> | **Step 0-A** | FH suitability pre-check (pre-flight) | Always run |
> | **Step 0-B** | Git token pre-injection | When repo creation/fork/push included |
> | **Step 0** | Auto environment detection + environment card output | Always run (after 0-A/B) |
> | **Step 0-C** | Existing harness detection + integration proposal | Auto-run when CLAUDE.md >50 lines or 3+ rules |
> | **Step 1** | Gap diagnosis | Always run |
> | **Step 2** | Diagnosis report + proposal list | Always run (`--dry-run` exits here) |
> | **Step 3** | User approval → per-item execution | Normal mode only |
> | **Step 4** | Acceleration baseline setup | Normal mode only |
> | **Step 5** | Completion report + contribution guidance | Normal mode only |
>
> **Sub-step vs Main step**: Steps 0-A/B/C are sub-steps of Step 0 environment detection.
> Proceed in order 0-A → 0-B → 0 (environment card) → 0-C, then move to Step 1.

### Step 0-A. FH Suitability Pre-check (pre-flight)

If this is your first time with FH, confirm 3 things before install. All should apply for maximum effect.

| Check item | Optimal situation | If not |
|---|---|---|
| **Are you using Claude Code as your primary tool?** | ✅ Using CC daily | FH only works on top of CC. Need to adopt CC first |
| **Are you running 2+ projects in parallel or have a meta-hub?** | ✅ Multiple projects or team shared environment | FH may not be needed for a single small project |
| **Do you want to structurally improve AI collaboration quality?** | ✅ Repeatedly performing verification/simulation/diagnosis | If you only want simple coding automation, deeper skills after install-wizard are optional |
| **Are you developing or researching FH itself?** | ✅ Extending skills, writing papers, running experiments on FH | → **Mode D** — companion-store setup needed |

Fewer than 2 of 3 (first three) → Proceed with install but recommend using only core skills (`context-doctor`, `harness-doctor`) first.
All 3 → Proceed in order: Step 0-B (token injection) → Step 0 (environment card) → Step 0-C (existing harness).

**Mode D detected (FH developer/researcher)**: Guide companion-store setup before Step 1. **Ask the backend first** — the store is a role (durable private home for artifacts), not a fixed `*-be` git repo: Obsidian vault / gbrain-ingest / `*-be` git repo (default) all qualify. Do not assume the repo path.

**Set the store up as a queryable WIKI, not an empty folder** — the store earns its value when the agent can *read it well*, so the scaffold includes: an `INDEX.md` wiki-home (**the `CATALOG.md` read-first pattern applied to the store** — named INDEX to avoid two CATALOG.md across the public + private repos; section map + **read-time-derived** pointers, never hand-maintained placeholders that rot) · session-start read wiring the AI **idempotently adds** to `CLAUDE.local.md` (grep-guarded against duplication: read INDEX → open result/signal files newer than the session card, not only handoffs) · the Raw/Wiki/Conversation ingest axis (`sync_push_protocols.md`). The git `*-be` form is the **default within the no-existing-store branch** (it stays an ask-first choice — see the backend question; SKILL.md does not override the detail file's neutral ordering), recommended *there* because for a non-visual user *observability is the agent querying the wiki* (INDEX + session-start read) — git-versioned, agent-native (grep/Read), no cloud egress; FH's answer to its weak Observability layer. Obsidian (graph-view = the visual observability surface) and cloud are equal options when the user already runs one. **Mechanical floor (corrected 2026-07-30)**: the `CLAUDE.local.md` read is prose, so the wizard **also registers the `SessionStart` hooks** (`fh_session_load.sh` companion freshness + `fh_env_delta_scan.sh` env-delta) into the gitignored `settings.local.json` — see `SKILL_detail.md §Mode-D-Companion-Setup` step 3. The earlier text here claimed no such hook existed and marked the gap "accepted"; both were wrong, and a clean second-machine install measured the miss (turn-0 load skipped on a task-first entry, on Opus). Prose is the layer **over** the floor, never the floor.

**Beyond Mode D (not forced)**: a non-developer user who accumulates their own context into FH and keeps no separate local store benefits too — but since accumulation is unobservable at *first* install, surface this offer only on a **re-run where FH-written artifacts already exist** (e.g. non-empty `tracks/*/session_*.md`), not preemptively at first setup. A user with a local store, or with no FH artifacts, is not prompted.

> **Detail**: See `SKILL_detail.md §Mode-D-Companion-Setup` — backend-branching question (Obsidian / gbrain / *-be git default), the queryable-wiki scaffold (INDEX.md + session-start wiring), remote-backed and local-only setup commands, cross-backend invariants — read when Mode D is detected.

### Step 0-B. Git Token Pre-injection (when repo creation/fork/push included)

When the work involves Git authentication needs like GitHub repo creation, fork, push, etc.,
inject the token as an environment variable in the terminal **before starting the CC session**.
Pasting tokens directly in chat exposes them in conversation history; environment-variable injection keeps them out of the record while gh / git CLI automatically recognizes them.

> **Detail**: See `SKILL_detail.md §Token-Injection` — Method A (per-session export) and Method B (permanent local secret file) — read when executing Step 0-B.

### Step 0. Auto Environment Detection — Environment Card Output

*(Run after Step 0-A·B pre-checks. Output results as environment card, then continue to Step 0-C.)*

CC runs the detection bash automatically (injection pre-flight scan → FH_DIR/CC_HUB_DIR → cwd project info → plugins → MCP → zshrc hook → optional framework detection → local LLM runtime, optional), then outputs the environment card.

**Stop rule (behavioral)**: if `FH_DIR` is not set, output the bootstrap guidance and **do not proceed to subsequent Steps** — install FH first, then rerun.

> **Detail**: See `SKILL_detail.md §Step0-Detection-Bash` (detection script + FH_DIR bootstrap guidance) · `§Env-Card-Format` (card template + optional pattern-pack note) — read when executing Step 0.

### Step 0-C. Existing Harness Detection + Integration Proposal

> **Safe**: This step is analysis/proposal output only. No file writes. Runs safely regardless of `--dry-run` flag.

> **Core message**: FH is not something placed on top of an existing harness.
> It analyzes existing rules to remove duplicates — making things lighter.

**Detection condition (behavioral)**: run integration analysis when `CLAUDE.md > 50 lines` OR `3+ .claude/rules/*.md files`. Otherwise → new install, move to Step 1.

**When existing harness detected — analyze existing CLAUDE.md + rules along 3 axes:**

| Analysis axis | What to check | FH response |
|---|---|---|
| **Duplicate rules** | Patterns already covered by FH standard skills (context-doctor, harness-doctor, verify-bidirectional, etc.) | Classify as removable items |
| **Project-specific** | Rules valid only for this project/domain | Keep (FH does not touch these) |
| **FH-delegatable** | Manually written recurring patterns (commit format, review checklists, audit schedule, etc.) | Classify as delegatable to FH skills |

**Respect user judgment**: FH mapping (duplicate removal, skill delegation) is not forced.
If FH is truly frontier, it will be chosen naturally. The choice is the user's.
Y (add integration plan items to Step 1) / N (add-only, keep existing rules) / S (skip, reanalyze later) — any choice continues to Step 1.

> **Detail**: See `SKILL_detail.md §Step0C-Integration` — illustrative single-run measurements, detection bash, integration analysis output format — read when executing Step 0-C.

### Step 1. Gap Diagnosis

**[Prerequisite] install-doctor conflict diagnosis (only in environments without install history)**: if `~/.cc_sentinels/{project-name}_wizard_done` doesn't exist (first install), call `/install-doctor --plugin fh-meta` first. CONFLICT/WARNING items → add ❗ markers to Step 2 proposal list. Items the doctor already diagnosed (`FH plugin install` · `zshrc hook` · `.claudeignore`) → map results directly, skip re-diagnosis; all other items → check directly.

Auto-check each item as PASS / MISS / FAIL. Check items: `.claudeignore` · `local_fh_context.md` · `zshrc hook` · `weekly_audit` freshness · `sentinel` setup · FH plugin install · `.git/info/exclude` · MCP plugin · `deep-insight` plugin (optional) · `fh_env_context.jsonc` · `phantom-gate` (Python + AI-output projects only) · domain pattern pack (optional, none ship by default) · local-LLM offload (optional — surface ONLY if the Step 0 bash emitted the literal line `Local LLM runtime: detected`; absent that line, this item does not exist) · **`env-delta SessionStart hook`** (Mode D — `scripts/fh_env_delta_scan.sh` registered in SessionStart; MISS if absent when the hub has sibling repos) · **`capability-escalation consent`** (per `[[capability_escalation_consent]]` — negotiate BOTH axes at onboarding so no later escalation is a surprise: *"Allow cross-family sidecars (external billing) for load-bearing verification?"* → `sidecar_consent`, and *"Allow Sonnet→Opus floor-up on depth-heavy turns (~3–5× cost)? Decline = stay at the Sonnet floor, asked per-occasion instead."* → `floorup_consent`; record both to the UAP. MISS if the UAP lacks either field — a skipped user is asked-once at first need, never sprung).

**env-delta detection (Mode D — the mechanical floor for claim ② auto-trigger)**: FH's "undeployed-asset discovery + auto-mapping" (CLAUDE.md claim ②) previously fired **only on explicit invocation** — a new sibling repo pulled, or a task-first session in an unmapped project, was **not** self-detected (the onboarding menu is suppressed on task-first entry by the metadata-is-not-intent / task-first guards, which are load-bearing and must stay). The `scripts/fh_env_delta_scan.sh` SessionStart hook (sibling of `fh_session_load.sh`) closes this **mechanically**: it scans the projects root for git repos that are neither mapped (`tracks/{name}/`) nor wizard-done nor skip-sentineled, and emits a **one-line PROPOSAL** into turn-0 context, firing regardless of task-first entry. It **proposes only** — mapping/install stays HITL; a skipped repo is recorded via a `{name}_mapping_skipped` sentinel so it never re-nags. This is the mechanical anchor over the prose/salience layer (three-family audit 2026-07-06 rated ② PARTIAL/THEATER precisely because the auto-trigger lived only in prose).

**Local-LLM offload (conditional, recommend-only)**: when Step 0 detected a local LLM runtime (Ollama / LM Studio), surface one optional item — route to `/plugin-recommender` for local-model offload tooling. FH recommends, never rebuilds (no-reinvention). Two complementary offload shapes the user picks per workload: **input-side context routing** (a small local model returns line ranges, so the cloud model receives only the dense slices instead of whole files) and **output-side generation delegation** (the local model generates and self-reviews code while the frontier model decomposes and validates). The benefit is tier-dependent — largest in headless/scripted pipelines and on weaker cloud tiers; an interactive session already triages via targeted reads. Local models suit **bounded, well-specified** work (triage, codebase explanation, instructed maintenance), not long-horizon autonomous tasks where small models loop or hallucinate — so the frontier model keeps decomposition and validation. Skip silently when no local runtime is present.

> **Detail**: See `SKILL_detail.md §Step1-Checks` — full check table with criteria and verification commands per item — read when executing Step 1.

**Score calculation (behavioral)**: PASS = 1 / MISS = 0.5 / FAIL = 0. Formula: `score = round( Σ(points) ÷ (applicable item count) × 100 )`. Conditional items (domain pattern pack / phantom-gate / MCP / deep-insight) are excluded from the denominator when not relevant, so always print the denominator next to the score (e.g. `{score}/100 over {n} applicable items`) — the percentage is reproducible only when the item count is shown.

### Step 2. Diagnosis Report + Proposal List

Output diagnosis results and generate per-item proposals. Each item: **Y (approve) / N (skip) / L (later) / A (approve all)**.

**cross-install detection → agent-composer auto-update proposal**: when external plugins are cross-installed, collect their trigger keywords, check against `agent-composer/SKILL.md` Step 1 mapping table, and propose an update for missing triggers (included in Step 3). No gaps → output "agent-composer mapping up to date".

**`--dry-run` branch point (behavioral)**: if the flag is set, output the dry-run summary and **exit here** (skip Steps 3~4).

> **Detail**: See `SKILL_detail.md §Step2-Formats` — diagnosis report template, 9-item proposal list with per-item commands, cross-install output format, dry-run exit message — read when executing Step 2.

### Step 3. User Approval → Per-item Execution

After receiving approval input, execute in order. **Output actual action preview before each execution.**

Execution priority (behavioral):
1. FAIL items (immediate effect)
2. MISS items (configuration supplementation)
3. Optimization items (optional)

> **Detail**: See `SKILL_detail.md §Step3-Execution` — action preview example, FH plugin auto-install bash + error handling table + success format, agent-composer mapping update format — read when executing Step 3.

### Step 3-D. Dispatch Standing Request — the one moment this is cheap to settle

FH/PMH treat isolated delegation as part of what the harness is, so **parallel dispatch is the
intended default for anyone running them**. It is not default *by assertion*: some runtimes ship a
line making unprompted dispatch conditional on a user request, and `CLAUDE.md §Agent Dispatch
Operation` will not read that condition as met unless a standing request is on disk. **A session with
no such record asks before every dispatch** — which is the friction this step exists to remove, once,
here, instead of in every future session.

So ask, and write the answer down. Three parts, all required — a record missing one is not a record,
and a session may never supply the missing part itself:

```
① the user's own words, quoted   — ask them to say it, then quote what they said
② a lease                        — THE USER picks the length. Do not suggest a default and
                                   do not fill it in. Renewal needs a fresh utterance later
③ a scope                        — which prohibition line this covers. Granting one never
                                   grants another (agents ≠ workflows ≠ deep-research):
                                   name each one the user actually intends
```

Write it into `CLAUDE.local.md` (gitignored). **Declined is a valid, recorded answer** — write that
down too, so later sessions stop re-asking rather than reading silence as an unanswered question.

**Any mechanical settings change belongs here as well**, under the same consent: if enabling the
intended default needs a `settings.json` edit, propose it in this step with the diff shown, and apply
it only on approval. Do not change settings silently on the strength of the doctrine alone — the
doctrine says dispatch is the default posture, not that the wizard may edit a user's config unasked.

⚠️ **The lease is honoured by reading, not by machinery.** `scripts/consent_registry_check.sh`
enforces leases for *registered consent classes*, and this grant is not one of those — say so when
recording it rather than implying an expiry alarm exists.

### Step 4. Acceleration Baseline Setup

After executing approved items, offer the automatic maintenance structure — **each piece is its own
Y/N, none is folded into an unconditional batch** (decline-integrity sim 2026-08-10: the earlier
"batch" wording had the zshrc hook and the SessionStart registration running without a gate, which
contradicted this skill's own Per-item-approval principle): zshrc hook (idempotent, **preview the
exact block, then Y/N**) + SessionStart floor-check hook registration (**Y/N — it writes to
`.claude/settings.json`**) + sentinel initialization (per-project) + weekly-audit cadence (no cron —
zshrc hook + session-start detection are the durable mechanisms).

**Every N is recorded, not just skipped**: append the item key to
`~/.cc_sentinels/{project}_wizard_declined`. A declined item means the corresponding intended FH
feature does not run (declined zshrc = no shell-side audit nag · declined SessionStart hooks = no
turn-0 floor/env-delta/companion signal — those fall back to session prose, which is
salience-dependent). State this at decline time in one line.

**4-axis pre-commit gate (behavioral — OPT-IN, double-confirm)**: Mode D / FH-self-development only. It gates commits **in the user's FH clone** and is **never installed into field projects** (FH-internal infra — see `auto_project_mapping.md §6`). Not auto-run: a separate explicit Y/N, never folded into the baseline-setup batch.

> **Detail**: See `SKILL_detail.md §Step4-Baseline-Bash` — zshrc hook block, 4-axis gate install commands with scope statement, sentinel init — read when executing Step 4.

### Step 5. Completion Report + Contribution Guidance

Output the completion summary (executed/skipped/later counts + what runs automatically from now on) followed by next-step skill suggestions, FH contribution guidance, Mode D companion-store pointer, and the fork-your-own-hub option.

**If any item was declined or deferred, the summary MUST also carry a consequences block**
(operator requirement 2026-08-10 — a decline is respected, never silent):
- the declined items by name, and the plain statement that **the corresponding intended FH features
  will not run in this state** (which gates/hooks/automation are off);
- how to change your mind: re-run `/install-wizard` (declined items are re-proposed, approved ones
  are not re-asked);
- that a **one-line per-session reminder** will note the not-installed state until resolved —
  mechanical via the env-delta SessionStart hook where hooks were accepted, session prose where they
  were declined (an unwired node has no hook to remind with — named residual: a task-first entry on
  a fully-unwired node has no reminder surface at all);
- how to silence the reminder deliberately: `touch ~/.cc_sentinels/{project}_wizard_reminder_muted`
  (recorded as its own decision, not a default).

> **Detail**: See `SKILL_detail.md §Step5-Completion-Report` — full completion report template — read when executing Step 5.

## Re-run (Inspection Mode)

When run again in an environment that has already passed the wizard (`~/.cc_sentinels/{project-name}_wizard_done` exists — per-project independent), operates in **inspection mode**:
- Only runs Step 1 gap diagnosis
- Proposes only newly found MISS/FAIL items
- No full reinstall

## External User Environment Adaptation

| Mode | Environment | Action |
|---|---|---|
| **A** (full) | FH clone + CC hub (your-hub etc.) present | Run all Steps 0~5 |
| **B** (FH standalone) | FH clone + no CC hub | Skip CC_HUB_DIR-related items, focus on FH setup |
| **C** (plugin only) | CC plugin install only (no FH clone) | Steps 0~2 diagnosis + guide output / no file writes |

## Activation Triggers

> **CC auto-detection**: Based on description field keywords (list below is for human reference).

- `/install-wizard`
- "first setup", "initial configuration", "onboarding start", "help me set up"
- "configure project", "onboarding start", "help me set up"
- "wizard" (when used standalone, confirm FH context before activating)

## Three-Doctor Loop Integration

| Situation | Integrated skill |
|---|---|
| Structural anomaly detected | `/harness-doctor` |
| Token waste pattern detected | `/context-doctor` |
| External user simulation needed | `/sim-conductor` |
| Install conflict suspected | `/install-doctor` |

## Per-Cluster Deferred Loading (Progressive Disclosure)

Only activate the cluster matching the utterance — loading all skills degrades selection quality.

| Cluster | Trigger keywords | Skills |
|---|---|---|
| **A — Harvest/Evolution** | harvest · session wrap-up · pattern · reverse absorption · fh evolution | field-harvest · harvest-loop · contention-layer · verify-bidirectional |
| **B — Diagnosis (doctor)** | diagnose · health · check · inspect · token waste · install conflict · doctor | harness-doctor · context-doctor · sim-conductor · install-doctor · install-wizard |
| **C — Compose (composer)** | agent composition · parallel · compose prompt · context card | agent-composer · meta-prompt-builder |
| **D — Audit/Review** | review · audit · PR review · steel quench · adversarial · lint · placement | hub-cc-pr-reviewer · steel-quench · apex-review · harness-doctor (--lint) · marketplace-gate · asset-placement-gate |
| **E — Explore/Frontier** | trends · plugin recommendation · synergy · frontier | frontier-digest · plugin-recommender · cross-ecosystem-synergy-detection |
| **F — Common (always-on)** | — | convergence-loop · deliberation (fh-commons) |

Rules: single match → that cluster only · multi-match → all matched · unclear → default B + delegate to agent-composer.

---

## Failure Response

On Claude API / MCP failure → refer to [`references/fallback-guide.md`](../../references/fallback-guide.md) manual checklist.

---

## Done When

```
☐ Environment detection complete: shell, CC version, OS, project type
  identified — each field carries a value or the literal "unknown",
  never blank                                                    (measured: 4 fields resolved)
☐ Settings probe distinguished ABSENT / UNPARSEABLE / OK — an
  unparseable config is never treated as absent                  (mandatory-pass)
☐ Gap diagnosis output: present vs missing items listed          (measured: count of items
                                                                  present + missing == items
                                                                  scanned)
☐ User approval/decline recorded for each suggested item —
  a missing answer is a decline, never an assumed yes            (measured: recorded answers
                                                                  == suggested items)
☐ All approved items installed with no failure state; every
  failure surfaced to the user, not silently skipped             (mandatory-pass)
☐ Acceleration baseline: zshrc block either appended with
  SUBSTITUTED values (no literal "{FH_DIR}" in the target file)
  or explicitly declined and the decline recorded                (mandatory-pass)
☐ Step 3-D dispatch consent recorded in the three-part form
  (quoted words · dated lease · scope) or a recorded decline —
  a two-part record is invalid and counts as absent              (mandatory-pass)
☐ Summary output: "N items installed, M items skipped" where
  N + M equals the number of items offered                       (measured: N + M == offered)
☐ Nothing was overwritten that the user did not approve          (judged — adversarial pairing:
                                                                  re-run the wizard on a
                                                                  populated .claude/ and diff
                                                                  the tree before/after; any
                                                                  unapproved delta is a FAIL)
```

`--dry-run` mode Done When: gap diagnosis report written, no installation executed.

---

## Hub Orchestration Hint

After setup, **where you work** significantly affects efficiency:

| Work type | Recommended location |
|---|---|
| Single project coding/debugging | That project's cwd |
| Meta/audit/simulation / 2+ projects simultaneously | Meta-harness cwd → Agent parallel dispatch |

Dispatching multiple tasks simultaneously using the `Agent` tool from the meta-harness cwd enables 5-6x acceleration vs sequential. However, this isn't forced — focused work on a single project is best done at each project's own cwd.
