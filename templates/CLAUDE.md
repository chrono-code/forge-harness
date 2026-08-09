# CLAUDE.md

> **Role-matched self-inspection (incubator bequest, 2026-08-10)**: this harness should carry at
> least ONE self-check instrument matched to *its own role* — something that answers "is what this
> harness verifies still aligned with what it is for?" — run at sync/upgrade moments, not only at
> incidents. The parent hub's instance is an env-purity scan (does shared prose still apply here?);
> a QA harness's is spec↔implementation↔TC triad consistency; yours follows YOUR role. An
> instrument the harness never runs on itself is decoration — wire it to a recurring moment.

## Session Start

When a user starts a session with greetings like "hello", "let's start", "resume", "continuing from where we left off", or says "read root memory", **both layers must activate**:

### Layer A — Auto read (4 steps required)

1. **Read CATALOG.md** — `~/projects/forge-harness/CATALOG.md` (recent work context + latest meta cwd work cross-link)
2. **Read latest session file** — `~/projects/forge-harness/tracks/{project}/` most recent mtime item (last work on domain + next round reverse-injection intent persistence location / use `ls -lat` or `find -mtime`)
3. **Check MEMORY.md next-session trigger** — if project memory `MEMORY.md` auto-load is truncated, explicitly Read to supplement the next-session trigger section
4. **Check todo/plan files if present** — `*todo*`/`*plan*` pattern (supplementary materials)
5. **Search for duplicate installs in same root** — `ls ../ | grep -iE '(harness|forge)'` to catch sibling assets in parent directory. If found, report to user + delegate branching decision (use existing install / proceed with new / archive then proceed)

### Layer B — Proactive initiative (active onboarding 5-skill cascade)

After Layer A completes, **when the user enters a task**, activate AI proactive initiative mode:

1. **Auto-initiative (1-line question)** — *"What task/project would you like to start? (e.g., 'Spring Boot API development', 'React component refactoring', 'continue existing [X] track')"* (if active track exists: *"Would you like to continue active track [X], or enter a new task?"*)
2. **5-skill cascade** — `plugin-recommender` (internal GHE → external → built-in candidates) → `cross-ecosystem-synergy-detection` (synergy grade table) → `.claudeignore` standard initiative (`cp templates/.claudeignore`) → model switching guidance (default `/model sonnet` — FH dispatches floored skills/agents at higher tiers itself; pin a stronger model for harness-editing sessions, or when the Field Depth-Escalation Notice below fires — see README §Model setup) → `verify-bidirectional`·`harvest-loop` natural emergence waiting
3. **User consent → actual setup** — plugin install / skill pre-activation / `.claudeignore` application / model switch
4. **Project cwd handover guidance** — *"Setup complete. Move to the project cwd and call `claude` to start working."*

**Simplification guard**: When an explicit task utterance is made (e.g., "debug X code"), enter task immediately (skip onboarding). Activates once per session.

### Field Depth-Escalation Notice (advisory — once per session)

The Sonnet default covers routine field work because FH dispatches floored skills/agents at higher
tiers itself. But when **main-thread development visibly strains the session tier**, surface a
one-line escalation proposal — do not leave it to recall:

**Triggers** (any one): the same problem survives 2–3 correction loops · the work enters
architecture/design reasoning that cannot be decomposed into a dispatchable unit · the user
signals being stuck ("keeps failing", "why is this still wrong").

**Two-step ladder** (propose the cheaper rung first):
1. **Opus dispatch (sidecar)** — if the heavy reasoning packages into a unit (a design review, a
   root-cause hunt, an adversarial pass), propose dispatching it to an Opus agent: the session
   stays on Sonnet, cost stays local to the unit.
2. **Session pin** — if the work is inherently main-thread (iterative dialogue design, repeated
   whole-context reasoning), propose: *"This work demands session-level design depth — pinning
   `/model opus` is recommended. Proceeding as-is also works: dispatches still cover floored units."*
3. **No higher tier available** — common in metered API routing (a Bedrock-style Sonnet-only
   deployment) or alternative runtimes (Hermes / OpenCode-class) that don't offer higher Claude
   tiers: skip the proposal, proceed at the available tier, and **flag depth-sensitive
   deliverables with an explicit below-floor limitation note** (F2 semantics — tier-floor
   resolution, `multi_model_sidecar_strategy.md §Tier-floor`). Silent proceeding is the failure
   mode this rung exists to prevent; the note makes the deliverable a re-review candidate when a
   floor tier becomes reachable.

**Guards** (mirrors the hub's Mode D Model Notice): once per session · advisory only — **never
switch the session model autonomously** (human override is inviolable) · sessions where nothing
strains never see it — the Sonnet default stays friction-free.

**Basis**: Meta-harness mission *"easy and convenient + no setup burden + token savings"* direct implementation mechanism. Natural hub/action-leader division (single trigger in meta-harness cwd → handover to action-leader cwd).

**3 usage modes — "don't block those who come, don't stop those who leave"** (meta-harness operating philosophy):
- **Mode A (standard)**: meta-harness cwd setup → handover to separate project cwd (4 steps above)
- **Mode B (resident)**: create **separate project directory** within the forge-harness install environment and work there. Keep the forge-harness directory itself as reference only — use `.gitignore` to block forge-harness assets from mixing into the project
- **Mode C (plugin/skill only)**: install only plugins/skills without going through forge-harness (available via marketplace without cloning). Skill output accumulates as history within the user's own project. No automatic signals from the forge-harness side expected — indirect contribution depends on user's active communication (issues · PR · channels)

If the user explicitly states a mode, immediately guide that mode. Do not force standard mode. Do not accumulate personal work artifacts in the forge-harness directory itself (protect reference asset identity).

## Asset Synergy Branching Decision (meta vs. action-leader)

When persisting new assets (memory · feedback · patterns · rules) during a session, asset location determination is required:

| Location | Nature | Examples |
|---|---|---|
| **Meta-harness side seed** | Useful as-is when installed in other projects (cross-project synergy) | User baseline propositions, environment common conventions, common action rules for all personas, session operation patterns |
| **Action-leader project side persistence** | Meaningful only in this project's domain/session context | Domain knowledge, session records, domain-specific validation loop outputs, per-project identity |

When the judgment is ambiguous, the AI **states synergy potential first** then delegates the location decision to the user.

## Knowledge Hub (forge-harness)

Persistent knowledge for this project is stored at `~/projects/forge-harness/`.

- **Past work search**: First read `~/projects/forge-harness/CATALOG.md`, identify related files by tags
- **Learnings/feedback originals**: `~/projects/forge-harness/tracks/{project_name}/`
- **At session end**: follow the Sync Protocol in `~/projects/forge-harness/CLAUDE.md` to sync
- **When new patterns are found**: follow the Push Protocol in `~/projects/forge-harness/CLAUDE.md` to feed back

<!-- [CUSTOMIZE] Replace {project_name} with the actual project name -->
<!-- [CUSTOMIZE] If there is a domain knowledge path, add:
- **Domain knowledge**: `~/projects/forge-harness/knowledge/domain/{domain}/`
-->
