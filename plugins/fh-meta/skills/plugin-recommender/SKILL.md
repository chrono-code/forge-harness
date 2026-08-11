---
name: plugin-recommender
description: Given a task description, searches internal and external open-source ecosystems (including Codex marketplace and Claude Code marketplace) to find and recommend suitable plugins with installation guidance. Recommendation is quality-validation based (marketplace-listed + performance-validated), not source-origin based. Activates on "recommend a plugin", "what tool should I use?", "is there a plugin for this?", "recommend a tool". Also checks for duplicate installations.
user-invocable: true
allowed-tools: ["Read", "Grep", "Bash", "WebSearch", "WebFetch"]
model: sonnet
---

> **Note:** In external user install environments, the internal GHE org inventory and sister asset clusters are organization-specific examples from the original developer's environment. Adapt the core of this skill (multi-layer search + synergy evaluation + install support) to your own environment (see `## External User Environment Adaptation Path` §).

# plugin-recommender

Takes a task description as input, searches internal GHE, Claude Code marketplace, Codex marketplace, and external open-source ecosystems, then outputs a ranked list of suitable plugins and install commands. Ranking is quality-validation based — not source-origin based. Also reports duplicate installs and potential conflicts.

## Activation Triggers

Activates on the following types of phrasing.

1. **Direct recommendation request**: "Recommend a plugin", "What plugin should I use?", "Find a useful tool"
2. **Task-based implicit request**: "I want to handle Jira tickets", "I need to visualize DB data", "I want to auto-generate API docs"
3. **Environment setup questions**: "How do I integrate with Confluence?", "Set up plugins needed for a new project"
4. **Chained from sim-conductor** (persona/simulation amplification): "Find a persona/simulation validation plugin", "Install stronger personas for the review". When invoked this way, scope the search to persona/simulation/review-oriented plugins (e.g., deep-insight) and **return control to sim-conductor after install** so the simulation can re-run with the installed personas — see `## Return Path` §.

## Processing Steps (Step 0 Pre-check + 5-Step)

### Step 0: Search Pre-check — GitHub Token Auth Status

Before entering Step 2 multi-layer search, **gh CLI auth status check is mandatory**. Internal GHE + external GitHub auth are separate — if unauthenticated, guide user on how to generate and store tokens.

Run `gh auth status`. For full PAT setup commands and host-branching scripts, see `SKILL_detail.md §Discovery-Bash`.

**External users** (no internal GHE): skip internal GHE auth check — verify `gh auth status` for github.com only, then proceed to Step 1.

**Internal non-hub users**: run Step 0 as-is, but remap Step 2 [Priority 1.5] sister asset clusters to your own org. See `## External User Environment Adaptation Path`.

### Step 1: User Goal Analysis and Core Keyword Extraction

Analyze the user's natural language request to extract core **domain** and **task** keywords.
- `"I want to create Jira tickets and update their status"` → `domain: jira`, `task: create, update`
- `"I want to auto-generate API docs"` → `domain: api, documentation`, `task: generate, auto`

### Step 2: Multi-Layer Search Space Setup

Search in priority order based on extracted keywords.

#### Tier Classification Table (Quality-Validation Based)

Tier is **independent of platform origin** (Anthropic / OpenAI / community). A well-benchmarked community plugin ranks higher than an official plugin with no performance data.

| Tier | Criteria | Sources |
|---|---|---|
| **Tier 0** | Platform built-in — ships with the runtime, zero install, zero token cost to discover | Claude Code built-in skills/commands (e.g. `/deep-research`, `/code-review`, `/review`, `/security-review`, `/batch`, `/loop`, `/fewer-permission-prompts`, `/goal`, `/rewind`, `/team-onboarding`) — inventory varies by version/environment: enumerate from the live session, do not assume |
| **Tier 1** | Marketplace-listed + performance-validated (benchmark data or production usage evidence) | Anthropic official · Codex marketplace verified · CC marketplace verified · FH community reviewed (steel-quench + sim-conductor validated) |
| **Tier 2** | Marketplace-listed, no explicit performance data | Any marketplace source (CC marketplace · Codex marketplace · npm · GHE) |
| **Tier 3** | Not marketplace-listed, source-available (GitHub/npm) | Repo-only agents/plugins |
| **Tier 4** | Not verified, private/internal | Internal team builds · unreviewed local experiments |

1. **[Priority 1] Internal Curated List**: `knowledge/shared/plugin-catalog/recommended_plugins.md` — check this first for verified internal/external plugin list + Tier 1·2·3·4 classification. If user's task domain already appears in catalog, use results immediately.

2. **[Priority 1.5] Internal GHE Sister Assets (partially completed work — Tier 2)**: Check if user's task domain already exists in internal sister asset clusters. Prioritize direct use or adoption of sister assets if the user's task falls within these cluster domains.

3. **[Priority 2] Organization's Internal GHE (Tier 1–4)**: Search internal GHE with keywords like `claude-plugin`, `gemini-plugin` + user keywords / API search. Replace with your organization's internal GHE orgs.

4. **[Priority 2.5] Project Reference/Contribution Path**:

    For cases where referencing or contributing to the project itself is more appropriate than installing a plugin. Provide guidance when there's intent for medium-term contribution rather than immediate use.

    - **Fork reference**: Fork a similar project and customize for your environment
    - **PR contribution**: Propose a PR to the relevant project if the desired feature is missing
    - **Issue filing**: Guide on how to file a feature request issue

    **Role separation (boundary with cross-ecosystem-synergy-detection)**:
    - `plugin-recommender` [Priority 2.5]: When no immediately usable plugin is available → guide to project-level reference/contribution path (alternative to installing)
    - `cross-ecosystem-synergy-detection`: Discover hidden synergies among already-installed skills (post-install utilization optimization)

    Activation condition: Automatically entered when Step 2 [Priority 1]~[Priority 2] search yields no suitable plugin. **This block therefore runs only after [Priority 2] has actually been executed** — the list above is in execution order (1 → 1.5 → 2 → 2.5 → 3), and the priority labels are names, not the run sequence.

5. **[Priority 3] External Open-Source Ecosystem**: WebSearch / WebFetch — "best github actions for X", "claude plugin for Y", etc. Simplification guard: defer external install if internal assets suffice.

   **Verified external search targets (as of 2026-05):**
   - [`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) — Anthropic-curated official plugin directory. Search here first for any task domain.
   - [`Chat2AnyLLM/awesome-claude-plugins`](https://github.com/Chat2AnyLLM/awesome-claude-plugins) — Community aggregator: 75+ marketplaces, 1,196+ plugins catalogued (2026-05-25). Use for broad discovery.
   - [`anthropics/claude-code/plugins/`](https://github.com/anthropics/claude-code/tree/main/plugins) — Anthropic first-party plugins bundled with Claude Code (e.g., `code-review` with 5 parallel Sonnet agents).

### Step 2.5: Platform-Aware Discovery

When queried for a specific capability (e.g., "adversarial reviewer for bash code"), search across all platforms before narrowing to candidates.

**Discovery order (stop when sufficient Tier 1 candidates found):**

0. **Platform built-ins (Tier 0)** — does a built-in skill/command already cover the capability? Check the live session's available-skills list before any plugin search. A built-in that covers ~80% beats installing a plugin for the rest
1. **Installed locally** — `.claude/agents/`, `plugins/` in current cwd
2. **FH native skills** — always-loaded knowledge in `plugins/fh-meta/` and `plugins/fh-commons/`
3. **Claude Code marketplace** — `claude plugin list --available --json` (marketplace plugins; `--available` **requires** `--json`) + `claude plugin marketplace list` to see which marketplaces are even configured. There is **no** CLI keyword-search subcommand — filter the JSON yourself, and fall back to the known CC registry (see verified targets above) for anything not in a configured marketplace
4. **Codex marketplace** — `npx --yes @openai/codex plugin list --available --json` (optionally `-m <marketplace>`) + `npx --yes @openai/codex plugin marketplace list`. Same limitation: no keyword search, filter the JSON
5. **npm ecosystem** — `@chrono-meta/`, `@anthropic/`, and other known-quality scoped packages

⚠️ **A failed or empty discovery lane is NOT "no candidates".** Both CLIs above list only *configured* marketplaces, and a non-zero exit / empty array means the lane did not answer — not that nothing exists. Report each lane's state explicitly (`EXECUTED` / `EMPTY` / `FAILED: <stderr>`) and never render a `FAILED` lane as a zero result; a lane that could not run must be re-run or replaced by the web-search fallback (Priority 3) before you tell the user nothing was found.

**Discovery priority**: built-in (Tier 0) > installed > FH native > Tier 1 (any platform) > Tier 2 > Tier 3 > Tier 4
**Tier 0 guard**: FH native wins over a built-in only when the FH skill adds governance the built-in lacks (e.g. `/goal` → `goal-quench` adds budget+quality gates; code diff review stays with built-in `/code-review`, FH-asset coherence with `hub-cc-pr-reviewer`)

**When sim-conductor chains here for persona discovery**: apply the same platform-aware search scoped to persona/simulation/review capability tags. Return discovered agents with their Tier rating so sim-conductor can decide whether to install or use a built-in brief.

For discovery bash commands (`claude plugin list --available --json`, `npx --yes @openai/codex plugin list --available --json`, npm scoped search), see `SKILL_detail.md §Discovery-Bash`.

### Step 2.6: Quality Validation Signals

Use this table to determine Tier placement when a candidate's tier is ambiguous.

| Quality signal | Weight |
|---|---|
| Published benchmark (accuracy/precision, reproducible) | High |
| Production usage evidence (download count, GitHub stars > 100) | Medium |
| Marketplace listing (official review process passed) | Medium |
| FH community reviewed (steel-quench + sim-conductor validated) | High |
| Author reputation (known team: Anthropic, chrono-meta, etc.) | Low |

**Tier assignment rule**: two or more High-weight signals → Tier 1. One High or two Medium → Tier 2. Listed but no signals → Tier 2. Not listed, source-only → Tier 3. No external presence → Tier 4.

### Step 3: Candidate Plugin Analysis and Ranking

Analyze each candidate plugin's `README.md` and `plugin.json` to score and rank based on:

- **Feature relevance**: How well does the description and keywords match user goals?
- **Reliability and recency**: Recent commit date, star/fork count (external), internal usage frequency, etc.
- **Install convenience**: Does it support `claude plugin install` directly?
- **Synergy effect**: Call `cross-ecosystem-synergy-detection` to check synergy grade (★~★★★) with other currently installed plugins.
- **Tier** (from §Tier Classification Table): report each candidate's Tier in the recommendation table.

### Step 4: Present Recommendation List

Output top 2-3 plugins in the following table format. Include Tier and Platform so the user can see the quality-validation basis at a glance. For full example outputs, see `SKILL_detail.md §Examples`.

| Rank | Plugin Name | Tier | Platform | Recommendation Reason | Key Features | Synergy Effect |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `[name]` | Tier N | [source] | [reason + evidence] | [features] | [synergy grade] |

### Step 5: Install and Configuration Support

When user selects desired plugin from recommendation list, help with installation.

**5-0. Pre-install Duplicate Detection (pre-check — mandatory)**: check `claude plugin list`, `.claude/settings.json` `enabledPlugins`, and same-name conflict. For full duplicate detection procedure and same-name conflict handling steps, see `SKILL_detail.md §Install-Procedure`.

**5-1 through 5-3. Install**: confirm intent → run install command → post-install configuration (API token, MCP connection, verify). Full install commands and configuration guidance at `SKILL_detail.md §Install-Procedure`.

**5-B. External Asset Migration Path** (when non-plugin asset found): migration suitability check (3 criteria) → SKILL.md conversion template → location guidance. Full procedure at `SKILL_detail.md §Install-Procedure`.

---

## Constraints

- **Recommendations, not guarantees**: Does not guarantee plugin performance, stability, or security.
- **Inbound supply-chain risk — EVERY tier, not just 3/4**: public skill registries have shipped malicious skills at scale (pointers: [HN 47370624](https://news.ycombinator.com/item?id=47370624) — 824 malicious skills reported on ClawHub; [HN 48678603](https://news.ycombinator.com/item?id=48678603) — Snyk ToxicSkills study. Secondary sources — verify before quoting figures). ⚠️ **The channel in both incidents was the marketplace listing itself — i.e. Tier 1/2.** An earlier version of this bullet scoped the warning to Tier 3/4, which inverted its own evidence: it warned loudest exactly where vetting exists and stayed silent where the cited attacks landed. Flag the risk before recommending **any** candidate; a high Tier means *listed and maintained*, never *audited for intent*.
- **Install string must be resolved, not relayed**: the `<name>` in an install command frequently comes from a web-search result. Before surfacing it, confirm the name resolves to the intended repository (owner/repo matches the source you are citing) — a plausible near-name is the cheapest form of this attack, and installation is irreversible on the machine that runs it.
- **User consent required**: Does not auto-install without explicit consent.
- **Search scope limitations**: Only searches within configured search space.

## External User Environment Adaptation Path

The internal GHE org inventory + sister asset clusters in this skill are examples from the original developer's environment. External user (mode C install) environment adaptation path — following forge-harness core proposition *"Beta + public release = obligation to have practical capabilities"*.

### External User Environment Assumptions

External users in 2 tiers:

| Type | Internal GHE access | Applicable path |
|---|---|---|
| **Internal non-hub** (org employee, not owner) | Yes — run Step 0 as-is / remap Step 2 [1.5 priority] to own org sister assets | Use original developer environment as reference baseline / search based on own sister assets/org |
| **External** (outside org) | No — apply entire Fallback Matrix below | Auto-skip internal GHE steps / search based on external GitHub |

The core 5-step procedure (goal analysis → multi-layer search → candidate analysis → recommendation → install support) is cross-applicable to both types.

> The Fallback Matrix below is for **external users**. Internal non-hub users can use Step 0·2 as-is.

### Fallback Matrix (Original Developer Environment → External Environment Replacement)

| Original developer environment dependency | External user environment fallback |
|---|---|
| **Step 0** internal GHE auth check | Check external GitHub auth only (`gh auth status` default host) — auto-skip internal GHE step |
| **Step 2 [Priority 1.5]** internal sister asset clusters | User's own sister assets (personal/team GitHub org · internal marketplace) — this skill auto-maps user's own sister asset matrix |
| **Step 2 [Priority 2]** internal GHE org inventory | External GitHub default org inventory (`anthropics` · `oh-my-claudecode` etc. plugin ecosystem marketplace) |
| **Step 2 Tier table** Tier 1·2·3·4 classification | User's own Tier classification — use the quality-validation signals table (§Step 2.6) to assign tiers in your environment |

### External User Usage Scenarios

1. **External GitHub priority recommendations**: In environments without internal GHE access, call only Step 2 [Priority 1] curated list + [Priority 3] external GitHub search / auto-skip [Priority 1.5]·[Priority 2] internal GHE steps
2. **Plugin marketplace discovery assistance**: Auto-search external ecosystems like `anthropics/claude-code` marketplaces · `oh-my-claudecode` · personal/team marketplaces
3. **Core synergy evaluation**: Step 3 synergy evaluation + auto-calling cross-ecosystem-synergy-detection is cross-applicable to all environments
4. **Same install support baseline**: Step 5 token generation path · MCP connection · 3 verification sub-paths work the same in external GitHub environments

### Limitations (Explicit)

- **Internal GHE org inventory** (Step 0 / Step 2 [Priority 2]) = original developer's organization-specific environment / external users should treat as reference baseline (auto-skipped)
- **Sister asset clusters** (Step 2 [Priority 1.5]) = original developer's own environment / external users should map their own sister assets
- **Core 5-step of this skill** (goal analysis + multi-layer search + candidate analysis + recommendation + install) = cross-applicable to all user environments / original developer examples are for reference
- **catalog `recommended_plugins.md`** = original developer environment accumulated operation baseline / external users should create their own catalog or use this as reference baseline

## Return Path (when chained from sim-conductor)

When invoked as sim-conductor's **③ external-fetch branch** (Activation Trigger 4), this skill hands control back after install so the simulation can run with the new personas.

```
sim-conductor needs persona X (no installed/built-in match)
  → plugin-recommender: scope search to persona/simulation/review plugins (e.g., deep-insight)
  → recommend → install (user approval)
  → RETURN to sim-conductor: report "[plugin] installed, personas [list] now available"
  → sim-conductor re-runs the Area with persona X
```

**Done When (chained mode)**: install complete **AND** control returned to sim-conductor with the available-persona list. Ending at install without the return handoff = incomplete chain.

**Simplification guard**: If a suitable persona is already installed or a built-in role brief covers the need, do not search/install — report the existing match and return immediately. The cheapest persona is the one already present.

## Done When

```
All Steps 0~5 completed
  — mandatory-pass: each step produced its stated output, or is
    explicitly marked N/A with the reason

+ Recommendation list table output (top 2~3 items, Tier + Platform + synergy
  grade included)
  — mandatory-pass: the table exists with all three columns populated

+ Every discovery lane reported with an explicit state
  (EXECUTED / EMPTY / FAILED: <stderr>)
  — measured: count lanes attempted vs lanes reporting a state; the two
    numbers must match. A FAILED lane rendered as "no candidates" is a FAIL
    of this condition, not a pass — the CLI lanes have no keyword search and
    see only configured marketplaces, so an empty result is routinely a
    non-answer rather than an absence (`not found` != `0`)

+ Install completed after user selection (or install skipped / 5-B migration
  path guided)
  — mandatory-pass: explicit user consent recorded before any install ran

+ Duplicate detection results reported
  — mandatory-pass: `claude plugin list` output consulted in this run

+ Every install string surfaced to the user resolves to the repository it is
  cited from (§Constraints — resolved, not relayed)
  — judged; adversarial pairing: in the same run, resolve one candidate name
    you already know is correct AND check one near-name variant. If the
    procedure cannot separate that pair, the resolution check is
    UNCALIBRATED and no install string may be presented as verified
```

## Failure Response

On Claude API / MCP failure → refer to [`references/fallback-guide.md`](../../references/fallback-guide.md) manual checklist.

---
