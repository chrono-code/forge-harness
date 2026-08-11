---
name: plugin-recommender-detail
description: Detail reference for plugin-recommender — bash discovery scripts, install procedures, recommendation examples. Load when executing specific steps.
load: on-demand
---

# plugin-recommender — Detail Reference

## §Discovery-Bash

### Step 0 — GitHub Auth Check Commands

**Check command (run before Step 2 search):**
```bash
gh auth status
```

**Internal GHE unauthenticated — PAT setup:**
```bash
# 1. Generate PAT at https://<your-ghe-url>/settings/tokens
#    Scopes: repo, read:org (minimum)

# 2. Save to gh CLI
gh auth login --hostname <your-ghe-url>
# Prompt: Select HTTPS → Paste an authentication token → enter token

# 3. Verify
GH_HOST=<your-ghe-url> gh api /user --jq '.login'
```

**External GitHub unauthenticated — PAT setup:**
```bash
# 1. Generate PAT at https://github.com/settings/tokens
#    Scopes: repo, read:org

# 2. Save to gh CLI
gh auth login --hostname github.com
# (or default: gh auth login)
```

**Search call host branching:**
```bash
# Internal GHE search
GH_HOST=<your-ghe-url> gh api ...
# or
gh search repos --owner <your-ghe-org> --hostname <your-ghe-url> [keywords]

# External GitHub search
gh search repos [keywords]  # default host
```

**External user Step 0 skip branch:**
```bash
# External user Step 0 replacement (no internal GHE access)
gh auth status  # default host (github.com) only
# Authenticated → proceed to Step 1 immediately
# Unauthenticated → guide github.com PAT generation above
```

**Claude Code marketplace discovery** (there is **no** `search` subcommand — `claude mcp search` does not
exist and exits 1 with `unknown command 'search'`; list, then filter yourself):
```bash
claude plugin marketplace list --json      # which marketplaces are configured at all
claude plugin list --available --json      # installed + available marketplace plugins (--available REQUIRES --json)
```

**Codex marketplace discovery** (`list-agents` does not exist either — the real noun is `plugin`):
```bash
npx --yes @openai/codex plugin marketplace list
npx --yes @openai/codex plugin list --available --json      # add -m <marketplace> to scope
```

> **Lane-state reporting (mandatory).** Neither CLI supports a keyword query, and both see only
> *configured* marketplaces. Record each lane as `EXECUTED` / `EMPTY` / `FAILED: <stderr>` and carry
> that state into the recommendation. **A `FAILED` lane must never be rendered as "no candidates"** —
> re-run it or fall back to Priority 3 web search before reporting an empty result.

**npm ecosystem search (scoped packages):**
```bash
npm search @chrono-meta [keyword]
npm search @anthropic [keyword]
```

---

## §Install-Procedure

### Step 5 — Full Install and Configuration Details

#### 5-0. Pre-install Duplicate Detection

```bash
claude plugin list
```

Three things to verify:
- **Manual install status**: If target plugin name exists in output → reinstall unnecessary
- **Repo-level activation**: If plugin is in `.claude/settings.json` `enabledPlugins` → already active
- **Same-name different-function conflict**: Same name but different origin/function → conflict handling below

**Same-name Conflict Handling procedure:**

1. Compare existing skill description vs recommended skill description
2. **Feature match** → report "Equivalent feature already installed" + skip reinstall
3. **Feature mismatch** → issue conflict warning:
   ```
   ⚠️ Name conflict: `<skill-name>` is already installed but has different functionality.

   Currently installed: <summary of existing skill description>
   Recommendation target: <summary of new skill description>

   Options:
   A. Keep existing (skip install)
   B. Install with namespace qualifier — e.g., `fh-<skill-name>`
   C. Remove existing and install new (⚠️ existing skill will be removed)
   ```
4. If user selects Option B: guide adding prefix to `name` field in plugin.json + present modification path

If either duplicate condition met → skip install → report "Already active" → proceed to Step 5-3 config only.

#### 5-1 through 5-3. Install Steps

1. Confirm intent: "Would you like to install the `[plugin-name]` plugin?"
2. On agreement — **the two commands take different arguments**: `marketplace add` takes a *source*
   (`<owner/repo>`, a URL, or a local path), never a plugin name; only `install` takes the plugin name.
   ```bash
   # Usage: claude plugin marketplace add [options] SOURCE
   #   SOURCE = owner/repo, a URL, or a local path — NEVER a plugin name
   SOURCE="owner/repo"
   PLUGIN="plugin-name"        # optionally "plugin-name@marketplace" to disambiguate

   claude plugin marketplace add "$SOURCE"
   # Usage: claude plugin install|i [options] PLUGIN
   claude plugin install "$PLUGIN"
   ```
   Skip the `marketplace add` line when the plugin already resolves from a configured marketplace
   (check `claude plugin marketplace list`).
3. Post-install initial configuration guidance:
   - **API token input**: Guide token generation path for external service APIs (Jira/Confluence/Slack — specify each service's token page URL + env var or plugin config storage location)
   - **MCP connection**: If plugin uses MCP server, guide auto-update of `.mcp.json` or `claude mcp add` command
   - **Verify**: `claude plugin list` or `/plugin` UI + recommend first-call dry-run

#### 5-B. External Asset Migration Path (when non-plugin asset is found)

Activation condition: Step 3 found a promising external asset lacking `plugin.json` or `claude plugin install` support — install not possible but pattern has value.

**5-B-1. Migration Suitability Assessment (quick 3-criteria check):**

| Criteria | OK | NG |
|---|---|---|
| **Single purpose** | Clearly performs 1 task | Complex framework/SDK level |
| **Dependency complexity** | Standard CLI tools only (bash, gh, grep etc.) | Requires custom runtime/database |
| **FH gap coverage** | No similar skill currently in FH | Existing skill covers 95%+ |

All 3 OK → recommend migration. Any NG → report "Recommend referencing rather than installing" then guide Step 2 [Priority 2.5] contribution path.

**5-B-2. SKILL.md Conversion Template:**

```markdown
---
name: {1-3 words for the external asset's core action}
description: {one sentence, plain text only — first line is the core spec}
user-invocable: true
allowed-tools: ["Read", "Bash", "Grep"]  # only actually needed tools
model: sonnet
---

# {name} — {one-line description}

## Activation Triggers
- When user says "{core action}"

## Execution Steps

### Step 1. ...
### Step 2. ...
```

Conversion checklist:
- [ ] description first line = core spec (no marketing language)
- [ ] allowed-tools = only actually called tools (no over-declaration)
- [ ] External asset original URL → explicitly stated in `## Source` section (license check mandatory)

**5-B-3. Migration Location Guidance:**

| Purpose | Path | Notes |
|---|---|---|
| FH official skill (org-wide distribution) | `plugins/fh-meta/skills/{name}/SKILL.md` | PR mandatory — must pass team review |
| Local experiment (own environment only) | `.claude/rules/{name}.md` | No plugin install needed |
| Mode D standalone deployment | `.claude/agents/{name}.md` | Only when operating as agent form |

> FH official skill inclusion criteria: recommend PR after confirming 2+ actual uses (simplification guard — immediate inclusion after 1 experiment is prohibited).

---

## §Examples

### Recommendation Table — Output Example

Full format with Tier + Platform columns:

| Rank | Plugin Name | Tier | Platform | Recommendation Reason | Key Features | Synergy Effect |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | `jira-automator` | Tier 1 | CC marketplace | Fully satisfies Jira ticket create/modify/query. Production usage evidence (5k+ installs). | Ticket creation, status change, comment addition | ★★★ (auto-links docs when used with `confluence-linker`) |
| **2** | `agile-sprint-board` | Tier 2 | GHE | Specialized for Jira-integrated sprint board visualization. Marketplace-listed, no benchmark data. | Sprint visualization, burndown chart | ★ (standalone use) |
| **3** | `issue-tracker-cli` | Tier 3 | GitHub only | Repo-only tool, no marketplace listing. Covers edge case not in Tier 1/2 options. | Bulk status updates via CLI | ★ (standalone use) |

### Persona Discovery (sim-conductor chain) — Return Example

```
plugin-recommender result to sim-conductor:
  Searched: CC marketplace, Codex marketplace, FH native
  Found:
    - deep-insight (Tier 1, CC marketplace) — adversarial reviewer persona
    - persona-devil-advocate (Tier 1, FH native, already installed)
  Installed: deep-insight
  Available personas: [devil-advocate, innovator, deep-insight, conservative-critic]
  → Return control to sim-conductor
```

### Quality Tier Assignment — Walk-through Example

Candidate: `@anthropic/code-review-agent`
- Published benchmark: accuracy 94% on HumanEval — **High** signal present
- GitHub stars: 2,400 — **Medium** signal present
- CC marketplace listing confirmed — **Medium** signal present
- Not FH-reviewed — no High signal from community

Result: 1 High + 2 Medium → **Tier 1**

Candidate: `random-org/bash-linter-plugin`
- No benchmark data
- GitHub stars: 45 (below 100 threshold)
- Not on any marketplace
- Unknown author

Result: no signals → **Tier 3** (source-available, GitHub only)
