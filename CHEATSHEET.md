# forge-harness User Cheatsheet

Frequently used commands and phrases.

> **`<harness-root>`** = the path where you cloned this repo. Example: `~/projects/forge-harness`. Replace `<harness-root>` in the commands below with your actual path.
> Unfamiliar with a term (meta-harness, launch pad effect, transit acceleration…)? See `knowledge/shared/GLOSSARY.md`.

---

## 1. Memory check

```bash
# Local memory (currently active)
ls ~/.claude/projects/*/memory/

# Persistent memory (full history)
# <harness-root> replacement example: ls ~/projects/forge-harness/tracks/
ls <harness-root>/tracks/

# Find past sessions
ls <harness-root>/tracks/*/session_*.md
```

---

## 2. Domain knowledge

```bash
# Domain list
ls <harness-root>/knowledge/domain/

# Add new domain
mkdir -p <harness-root>/knowledge/domain/<domain-name>/{tc,knowledge}
```

---

## 3. Symbolic Link setup

```bash
# Project → domain knowledge
ln -s <harness-root>/knowledge/domain/<domain>/ <project>/docs/domain/<domain>

# New project → copy skeleton
cp -r <harness-root>/templates/.claude/ <project>/.claude/
cp <harness-root>/templates/CLAUDE.md <project>/CLAUDE.md
```

---

## 4. Common Claude Code phrases

### Universal (any project)
| What you want | What to say to Claude |
|-------------|---------------------|
| Start session (greeting) | "hi" → auto-reads CATALOG.md and guides today's work |
| Start session (fallback) | "read root memory" → reliable trigger when greeting doesn't work |
| Check past session | "read the 04-12 session from forge-harness" |
| Clean memory | "clean up local memory" |
| Save session | "save the current session" |
| Evaluate structure | "how do you evaluate this structure from an AI perspective" |
| Check duplicates | "check for duplicate or meaningless data" |
| Diagnose a mapped project's harness | "진단해줘" / "improve this harness" (inside the project) → ranked fix list, you approve per item |
| Recall past work | "what did we do last week?" → CATALOG-first search |

### Full autonomy — the whole contract in one line

> **"끝까지 해줘" / "run it to the end" removes the per-item *prompts*, never the *gates*.**
> A token budget is agreed up front (goal-quench), install/acceleration plans never overwrite your
> existing harness/config files (merges are proposed instead), and irreversible actions
> (publish · delete · history-rewrite) still stop for you.

---

## 5. Session Sync

| What you want | What to say to Claude |
|-------------|---------------------|
| Persist session record | "sync this session to forge-harness" |
| Clean local memory + sync | "clean local and sync forge-harness" |
| Check sync status | "check forge-harness sync status" |
| Search past work | "what did I do on 04-13?" (searches CATALOG.md) |

### Manual check
```bash
# Fast past work search via CATALOG.md
cat <harness-root>/CATALOG.md

# Check latest session per track
ls -1t <harness-root>/tracks/*/session_*.md | head -5
```

---

## 6. Git

```bash
cd ~/projects/forge-harness
git add -A && git commit -m "message"
```

### 4-Axis Gate (hub contributors only — one-time setup)

> **Only needed if you will modify FH's own assets** (skills, rules, templates, CLAUDE.md — i.e. hub
> contributions). If you just use FH with your projects, **skip this section**: the gate never fires
> on your own project's commits.

```bash
# Activate the pre-commit hook — run once after cloning
git config core.hooksPath templates/.git-hooks
chmod +x templates/.git-hooks/pre-commit
```

After running `/steel-quench` and `/phantom-quench` in your session, Claude creates the Axes 2+3 pass marker automatically. The marker must carry machine-readable floor fields — the hook validates them (a bare `touch` marker no longer passes; below-floor passes block unless an explicit `below-floor-ack:` line records operator acceptance, **quoting the operator's approval utterance verbatim** — an unquoted reason is rejected as agent-self-writable). It also requires an **`axis2-evidence:`** line recording what the pass actually found (a finding count or verdict token — `PASS no-S` / `1S/4A fixed` / `clean — 0 findings`); a vacuous "it ran" line is rejected. *Honest scope: this enforces the marker is non-vacuous + auditable, not that the pass truly ran — a fabricated attestation is the weekly audit's + operator's residual, by design (judge-robustness swarm, 2026-06-13).* If Claude doesn't create it (e.g., session interrupted), create it manually:

```bash
cat > "tracks/_meta/.axes_23_passed_$(git rev-parse --abbrev-ref HEAD | tr '/' '_')_$(date +%Y-%m-%d).marker" <<'EOF'
axis2-engine: quench-challenger
axis2-model: opus
floor-status: at-floor
axis2-evidence: PASS no-S
<scope / findings prose>
EOF
```

> **Migration note**: markers created before the floor-field upgrade are 0-byte legacy files — past-date ones are inert (the hook only reads today's marker), but a legacy marker for *today* must be regenerated in the structured format above before the first post-upgrade commit.

---

## 7. Weekly improvement cycle

The hub audits and improves itself weekly through `/harvest-loop` (the unified session-wrap + pattern-harvest pipeline).

| What you want | What to say to Claude |
|-------------|---------------------|
| Run session wrap + weekly harvest | `/harvest-loop` or "wrap up this week" → pattern scan + 3-tier improvement proposals + PR draft |
| Meta-simulation audit | `/sim-conductor B` → internal 3-persona audit + M/S/R backlog auto-generation (Area B weekly recommended) |
| Check status | "when was the last harvest?" |
| Apply improvements | "apply only 🟥 mandatory items now" |

**L1 auto-detection:** When hub cwd session starts, Claude auto-checks recent harvest file mtime → proposes `/harvest-loop` if 7+ days elapsed.

---

## 8. Sub-agent operations (optional · pilot phase)

Define custom sub-agents with Claude Code standard `.claude/agents/*.md`.

```bash
# Hub sub-agents list
ls <harness-root>/.claude/agents/

# Project sub-agents list (be careful with shared repos)
ls <project>/.claude/agents/

# Keep personal agents local-only in shared repos
echo '.claude/agents/' >> <project>/.git/info/exclude
```

### Agent-copy path — copy only agent files (minimal entry without plugin install)

```bash
# Copy only the agents you need to your project
cp <harness-root>/plugins/fh-meta/agents/fact-checker.md <my-project>/.claude/agents/
```

Copy just 1 agent without plugin install and it's immediately callable. Updates require manual re-copy.

| What you want | What to say to Claude |
|-------------|---------------------|
| Audit external reader asset | "run persona audit" → calls `hub-persona-auditor` |
| Code review | "review this diff" → calls project `code-reviewer` |
| Naming gap detection + ideation | `/persona-innovator` or "find naming candidates" → 6-type classification + external signal scan |
| Meta-simulation run | `/sim-conductor` (Area C default) · `/sim-conductor B` (internal audit) · `/sim-conductor A` (external user perspective) |

**Promotion gate (after 2+ week pilot):** accepted ≥ 60% → maintain · rejected ≥ 40% → deprecate.

---

## 9. Plugin management

| What you want | What to say to Claude |
|-------------|---------------------|
| Plugin recommendation | "what plugins do you recommend", "find a plugin for Jira ticket handling" |

```bash
# [Terminal] Update fh-meta (manual run required when new skills are added)
claude plugin update fh-meta@forge-harness

# [Terminal] Check installed plugin list
claude plugin list
```

> Plugins are not auto-updated. When you receive notification of skills/agents added to FH, update with the command above.

---

## 9.5. npx / CLI — zero-install governance gate (any repo, no Claude Code session)

The npm package `@chrono-meta/fh-gate` runs FH's governance gate as a plain CLI — no clone, no plugin, no `claude` session. Use it in CI or any repo. It shells out to a backend (`claude --print` or `codex exec`) and returns a machine-parseable verdict + exit code.

```bash
# Governance gate — wraps any coding agent's output as a post-generation check
npx --package @chrono-meta/fh-gate fh-gate                    # auto-detect from git diff
npx --package @chrono-meta/fh-gate fh-gate "src/foo.ts" full  # explicit files + level
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate   # Codex backend (default: claude)
# → FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE
# → exit: 0 PASS · 1 PENDING · 2 BLOCKED · 3 ESCALATE · 10 harness error · 11 arg error

# Run a skill or agent doc through a backend, outside Claude Code
npx --package @chrono-meta/fh-gate fh-run --skill <name>
npx --package @chrono-meta/fh-gate fh-goal "<goal text>"      # goal runner
npx --package @chrono-meta/fh-gate fh-codex-doctor --strict  # Codex adapter drift check
```

| Knob | Values | Effect |
|------|--------|--------|
| `FH_BACKEND` | `claude` \| `codex` \| `auto` | Backend CLI (`auto` prefers Codex when both present) |
| `FH_MODEL` | model id | Override backend model |
| level arg | `quick` \| `full` | Gate depth (default `quick`) |

> **vs the plugin path (§9):** the plugin gives you interactive `/slash-commands` inside a `claude` session (Claude-only). The npx path is a single-shot CLI that runs **without** Claude Code and works with Codex too — built for CI pipelines and non-Claude users. Exit codes make it gate-able in GitHub Actions.

---

## 10. Token efficiency best practices (AI collaboration guide)

4 levers to reduce context cost. Combine for amplified effect.

### Lever 1 — `.claudeignore` (token reduction)

Exclude unnecessary files from context. Create in project root.

```bash
# Basic recommended patterns
node_modules/
.git/
dist/
build/
*.log
*.lock
coverage/
__pycache__/
.venv/
```

> Tell Claude: `"apply standard .claudeignore"` → auto-generate proposal.

### Lever 2 — `/clear` (context reset)

Use when conversation has grown long and past context becomes noise. Clears context only without ending session.

```
/clear   ← context reset (session and file state maintained)
```

**When to use**: When direction has changed / when switching to a different track / when too much was accidentally read.

### Lever 3 — Model switching

| Situation | Recommended model | Command |
|---|---|---|
| Complex design/reasoning | Opus | `/model opus` |
| Code writing/editing | Sonnet (default) | `/model sonnet` |
| Fast simple tasks | Haiku | `/model haiku` |

> Using Opus continuously for the same task multiplies token cost 3–5x. Switching down strategically is a strategy.

### Lever 4 — Intent-based recall load (Context Isolate)

Only read necessary documents at the necessary time. MEMORY.md intent-based + associative recall (index→body; `knowledge/shared/dialogue/memory_intent_recall.md`).

```
✅ Only read CATALOG.md first at session start
✅ Delayed load of related files only when keyword is spoken
❌ Do not pre-load all knowledge files at session start
```

> Tier context as L1 always-on (~2–5K, CLAUDE.md core rules) · L2 session (~5–20K, active track) · L3 on-demand (`knowledge/` docs), and keep critical info at the **start and end** of a document, never the middle — mid-context info loses ~10–30% accuracy ("lost in the middle"). See `knowledge/shared/harness-core/harness_frontier_diagnosis_2026-06-02.md`.

### Combined effect measurement examples

| Before | After | Savings |
|---|---|---|
| No `.claudeignore` + Opus fixed | `.claudeignore` + model switching | Token/cost reduction (varies by environment) |
| Not using `/clear` even when session grows long | Habit of `/clear` when direction changes | Noise removal → accuracy improvement |

> **Core principle**: Everything loaded into context has a cost. Block it from the start if it doesn't need to be read.

### Lever 5 — `/goal` (session goal locking) — Claude Code v2.1.139+

Set a goal at session start and a separate **condition evaluation LLM** monitors Claude's text output in real-time and judges whether conditions are met.

```
/goal <condition>
```

#### Key to writing conditions: write as observable state

| Pattern | Example | Evaluation method |
|---|---|---|
| **Test result** | `86 tests green` | pytest output itself is the signal |
| **Quantity criterion** | `generate 20+ test cases` | Explicit number declaration |
| **Variable state** | `bin_b_output not None` | Observable from output |
| **Task completion declaration** | `implementation complete` | Claude's declaration sentence is the signal |

> **How it works**: The condition evaluation LLM reads Claude's **text output**. So Claude explicitly declaring a result matching the condition is itself the achievement signal. Even vague conditions can be satisfied by "wrote it" declaration — but more measurable conditions provide more accurate gating effects.

```
Example: /goal implementation complete + 86 tests green + /goal function verified working
Example: /goal 20+ test cases + all cases include verification link
Example: /goal weekly audit complete — pattern scan → through PR
```

**When to use**: Prevent mid-session drift in multi-step work / test/TC quantity gating / when you want to clearly define session completion conditions.

> `/goal` operates independently from CLAUDE.md. Suitable for per-session temporary goals.

### Lever 6 — Wrap-then-Compact (session state preservation)

Standard `/compact` lets the auto-algorithm decide what to preserve. **Wrap-then-Compact** gives you the control: you curate the summary → that summary *becomes* the compact basis.

> Use when you want to **preserve state** (vs. `/clear` which resets). Both free up context — the difference is what survives.

**Pattern** (CC subscription only — Bedrock/API throws 400 without warning, as of 2026-06):

| Step | Action |
|---|---|
| 1. Notice context approaching limit (~80%+) | CC UI shows the context meter |
| 2. Ask Claude to write a session wrap-up | `"정리해줘"` / `"wrap up — completed, modified files, pending tasks"` |
| 3. Run `/compact` | Claude's structured wrap-up strongly influences the compact output — tends to become the cold-start primer |
| 4. Next session resumes with full context | Pending tasks + key decisions + file paths explicitly preserved |

**Why it's better than blind `/compact`**:

| | Blind `/compact` | Wrap-then-Compact |
|---|---|---|
| Summary basis | Auto-algorithm selects snippets | Human-curated — you control what's preserved |
| Pending tasks | May be lost or fragmented | Explicitly listed before compact |
| Key decisions | Summarized generically | Preserved with rationale |
| Cold-start quality | Varies | Consistent — the wrap IS the summary |

**Ideal wrap includes** (tell Claude to include all of these):
- ✅ Completed items (with commit hashes)
- ✅ Modified files + key changes
- ✅ Pending tasks (explicit list)
- ✅ Next session entry point

> **CC subscription only**: Bedrock/API has no context meter warning — it fails silently with a 400 error. This pattern is CC subscription-specific.

> **context-doctor integration**: saying `"context is getting full"` or `"slow"` → context-doctor will propose this pattern automatically.

#### 6.1 — Disk-handoff: survive even a *forced* auto-compact

Wrap-then-Compact (above) only helps when **you** choose the moment. The dangerous case is the
**unplanned auto-compact at 100%+** — the harness summarizes on its own and your R&D nuance (the back-and-forth
that produced a decision) gets dropped. The wrap-summary trick can't save you, because there was no wrap.

The fix is to **stop relying on the conversation surviving at all**. Put the recoverable facts **on disk**
*before* you compact, so a fresh session reads a file — not the lossy summary:

| Step | Action |
|---|---|
| 1. Say **"compact"** (or notice ~80%) | Treat it as a trigger, not just a command |
| 2. Claude writes a **handoff file** first | A single file with: current status · the *one* next action · constraints to preserve · file paths + commit hashes |
| 3. Claude confirms `"backup written → <path>"` | Now the facts live on disk, independent of any summary |
| 4. You run `/compact` (or auto-compact fires) | Even a forced 100% compact can only blur dialogue nuance |
| 5. Next session lands on the handoff file | Conclusions + next step recovered from disk, not memory |

**Where the handoff lives**: a durable, non-gitignored location a fresh session will actually open —
a `handoff/NEXT_ACTION_<date>.md` in a companion store (Mode D), **or** for everyone else a note committed
to the working repo / a PR comment. **Never** a gitignored local file (it's wiped on an ephemeral reclaim).

> **Difference from Lever 6**: Wrap-then-Compact curates *what the summary says*; the disk-handoff makes the
> facts *not depend on the summary existing at all*. Use both — the handoff is the floor that holds when an
> auto-compact you didn't ask for fires. Say **"compact"** and Claude does step 2 automatically.

---

## 11. New technology introduction pipeline

Standard 3-step path for actually integrating new features, tools, and frameworks into FH.

```
Proposal → Simulation → Optimization
```

### Step 1. Proposal (detection)

Catch signals of new technology.

| Signal source | Tool |
|---|---|
| Claude Code new features (release notes) | `/frontier-digest` |
| Patterns discovered in field projects | `/field-harvest` |
| User direct utterance ("should we try this?") | Immediately to Step 2 |

→ Output: gap analysis of whether FH integration is possible + candidate list

### Step 2. Simulation

Explore integration possibility in advance without experimentation.

```
/sim-conductor Area C    # Ideation scan — idea × FH applicability
/sim-conductor Area A    # External user perspective — perspective of people who would actually use it
```

→ Output: Concrete proposal of how to attach it to which FH asset (SKILL.md / CHEATSHEET / agents)

### Step 3. Optimization (apply)

Actual integration after simulation approval.

| Output type | Application location |
|---|---|
| New command/feature guidance | `CHEATSHEET.md` corresponding section |
| Extend existing skill | Corresponding `SKILL.md` step addition |
| New workflow pattern | New skill candidate (if simplification guard passed) |
| Agent integration | `.claude/agents/` or plugin agents/ |

→ commit + push + CATALOG.md Decision record

### Application examples

```
/goal feature
  Proposal: after project experiment, propose introduction
  Simulation: measured in project session
  Optimization: CHEATSHEET Lever 5 updated ✅

Claude agents feature
  Proposal: insight received about parallel management
  Simulation: /sim-conductor Area C ← here now
  Optimization: TBD
```

| What to say to Claude | Action |
|---|---|
| "simulate how to use this in FH" | Immediately enter Step 2 |
| "scan CC new features" | Step 1 (`--cc-scan`) → Step 2 auto-proposal |
| "apply simulation results" | Immediately enter Step 3 |

---

## 12. Skills & agents — what each does and what to say

> You don't memorize skill names. **Say the plain-language phrase** and Claude routes to the right skill
> (the same trigger map lives in `CLAUDE.md`). The `/skill` form is the explicit fallback. Skills are
> independently runnable — `fh-commons` ones work even without the full hub.

### Verification & grounding — *"is this actually right?"*

| Skill | What it does | Say this |
|---|---|---|
| `steel-quench` | All-angle adversarial attack on a design/output, then defense, until a round finds nothing new AND needs no repair | "run the quench", "attack from the root", "shake out the design anxiety" |
| `phantom-quench` | Back-traces every claim to its declared source; flags **Phantom Claims** (present in the artifact, not in the source). *Old name: `source-grounding-audit`.* | "verify the source", "where did this come from", "grounding audit", "phantom check" |
| `verify-bidirectional` | Re-checks a decision from the opposite direction + folds your counter-argument into the baseline | "is that right?", "double-check this", "give me the counterargument" |
| `convergence-loop` *(commons)* | Re-runs a gate until a round adds zero new failures — "truly passed", not "passed once" | "a single pass seems suspicious", "loop until it converges" |
| `prompt-regression` | After a CLAUDE.md/rule/skill edit, probes for silent behavior regressions vs saved baselines | "did my rule change break anything", "regression-check the harness" |
| `return-path-gate` | Checks that a skill chain is **closed** (callee's verdict feeds the caller), not fire-and-forget | "is this chain closed", "does the result feed back" |

### Orchestration — *"coordinate the work"*

| Skill | What it does | Say this |
|---|---|---|
| `agent-composer` | Reads the work context and decides which agents to dispatch, when, and in what order | "run these in parallel", "which agents should handle this", "orchestrate agents" |
| `pipeline-conductor` | Chains the 4 verification pipelines into one gated sequence + a single aggregated report | "run the full quality gate", "end-to-end verification sweep" |
| `goal-quench` | Adds a token-budget ceiling + quality gate on top of an autonomous `/goal` run | "run this autonomously but cap the budget", "gate the goal run" |
| `meta-prompt-builder` | Designs *what to say* to each agent (pairs with agent-composer's *what to orchestrate*) | "help me write a prompt", "build a prompt for the agent" |
| `deliberation` *(commons)* | Innovator → Devil → Mediator 3-role structured debate to a synthesis | "deliberate this", "argue both sides then synthesize" |

### Diagnosis — *"something feels off"*

| Skill | What it does | Say this |
|---|---|---|
| `harness-doctor` | Diagnoses harness structure (L1–L4) on the principle "a good harness gets simpler over time" | "check my Claude setup", "the harness feels complex", "too many skills" |
| `context-doctor` | Finds the 3 main causes of token waste + prescribes `.claudeignore` / `/clear` timing | "session is slow", "context is getting full", "clean up context" |
| `install-doctor` | Diagnoses conflicts/duplicates/overwrite risks before installing plugins into a project | "check the install", "verify my setup", "will this overwrite anything" |
| `mcp-circuit-breaker` *(commons)* | Detects MCP failure loops, trips a breaker to stop retry waste, proposes alternatives | "MCP keeps failing", "same tool error is looping" |

### Harvesting & learning — *"keep what we learned"*

| Skill | What it does | Say this |
|---|---|---|
| `harvest-loop` | End-of-session weekly audit → pattern scan → 3-tier improvement proposals → PR draft | "wrap up this week", "harvest the session", "weekly review" |
| `field-harvest` | Back-propagates a reusable pattern found in a field project into the hub | "I could reuse this", "pull this pattern into the hub" |
| `memory-hygiene` | Catches "stale-but-confident" memory that drifted from reality; updates or prunes it | "memory feels bloated", "clean up memory", "is my memory still accurate" |
| `edit-manifest` | Records a predicted-impact line per edit, closing the predict-vs-verify loop for harvest-loop | "record this edit's predicted impact" *(usually auto, Axis 4 of the gate)* |
| `contention-layer` | When two skills conflict, harvests the missed validation angle instead of discarding one | "these two skills disagree", "harvest the conflict" |

### Gates & guards — *"safe to ship / publish?"*

| Skill | What it does | Say this |
|---|---|---|
| `token-budget-gate` *(commons)* | Estimates token cost before a multi-step task, then calibrates against actual after | "how expensive is this", "estimate the token budget first" |
| `ko-tech-writer` *(commons)* | Korean tech-writing pipeline — venue calibration, translationese scan, number/claim gate, perceptual QA | "기술문서 써줘", "테크블로그 초안", "번역투 고쳐줘" |
| `asset-placement-gate` | Routes a new skill/agent/plugin to the right place (hub vs project), no role overlap | "where does this go", "should this be shared", "hub or project" |
| `marketplace-gate` | Scores a repo against 5 listing criteria (README, zero-config, maintenance, dup, safety) | "is this OK to publish", "ready for the marketplace", "pre-publish check" |
| `public-surface-audit` | Scans git-tracked files for operator-private tokens (real username, corp names, home paths) | "did I leak anything", "scan for private tokens", "is my split clean" |
| `harness-doctor --lint` | Flags self-promotional / hype wording in descriptions (plain-text discipline) | "lint the marketing language", "is this description hyped" |

> **Going public?** Don't run these one at a time — say **"publish"** / **"make this repo public"** and Claude
> fires the **Pre-Publish Surface Gate** (CLAUDE.md), which runs `public-surface-audit` + `marketplace-gate`
> Check 5 *before* the irreversible action. Portable checklist: `templates/PRE-PUBLISH-CHECKLIST.md`.

### Discovery — *"what's out there?"*

| Skill | What it does | Say this |
|---|---|---|
| `plugin-recommender` | Searches marketplaces + open source for a task, ranks by quality, gives install commands | "what plugin should I use", "find a tool for Jira tickets", "recommend a plugin" |
| `cross-ecosystem-synergy-detection` | Finds cross-invocable pairs across your installed plugins/CLIs + a synergy ranking | "are my tools working together", "any synergy / overlap", "can these integrate" |
| `frontier-digest` | Pulls latest AI/agent/harness trends from HN + arXiv into actionable insights | "latest AI trends", "frontier digest", "what's new out there" |

### Simulation, review & clarification — *"pressure-test the thinking"*

| Skill | What it does | Say this |
|---|---|---|
| `sim-conductor` | Profiles a target → derives personas → parallel-agent audit → M/S/R triage. Areas: A external-user · B internal-audit · C ideation | "external user perspective", "run an internal audit", "simulate this" |
| `apex-review` | Reviews from a top-level decision-maker's lens, not a practitioner's | "will this hold up for leadership", "CTO-level review", "approval deck" |
| `deep-clarify` | Turns a vague request into an actionable spec through Socratic questioning | "I'm not sure what to build", "help me clarify the requirements" |

### Setup & onboarding — *"get started / keep it tidy"*

| Skill | What it does | Say this |
|---|---|---|
| `install-wizard` | First-install onboarding (zshrc, sentinels, the FH self-gate) | "first-time setup", "run the install wizard" |
| `hub-cc-pr-reviewer` | Reads a PR diff → 8-matrix baseline-consistency check → review comment + merge call | "review this PR", "check this diff" |
| `salience-splitter` | Splits an over-large SKILL.md that "does everything" into scoped files | "this skill is bloated", "SKILL.md too large", "split this skill" |

### Agents (sub-agents, dispatched — not slash commands)

| Agent | What it does | When it's used |
|---|---|---|
| `challenger` *(hub)* | Frontier-grade adversarial evaluator; adapts attack vectors to artifact type, cites evidence per attack | The heavy adversarial reviewer behind steel-quench / harvest-loop |
| `quench-challenger` *(commons)* | Devil (6-axis attack) + Innovator (alternative) + Prescriber (one-line fix) synthesis | steel-quench Wave 1 calls it first |
| `fact-checker` *(fh-meta)* | Greps the hub to confirm an asset/skill exists before you recommend it; catches stale facts | "does this already exist in the hub", duplicate-work suspicion |
| `hub-persona-auditor` *(fh-meta)* | 3+ persona × 4-axis (resonance/confusion/resistance/supplement) audit of an external-facing draft | Before publishing a briefing / card / guide |
| `persona-innovator` *(fh-meta)* | Generates naming candidates + frame proposals + external frontier signals | "find naming candidates", harness evolution ideation |

> **Don't see your need?** Describe it plainly — `plugin-recommender` searches beyond FH too. And if a
> phrase here doesn't route correctly, the explicit `/skill-name` form always works.
