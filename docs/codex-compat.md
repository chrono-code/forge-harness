# Codex Compatibility — Known Limitations & Validated Patterns

> Status: **beta** — in the *validation-maturity* sense (ⓑ below), not the *scope* sense (ⓐ). This
> document is a beta-removal condition (see
> `knowledge/shared/harness-core/agents_md_runtime_details.md §Beta-removal`). It lists what works,
> what breaks, and what to expect when applying forge-harness (FH) methodology through OpenAI Codex
> (`codex exec`) instead of Claude Code.

FH is a 2-layer system: a **methodology layer** (`tracks/`, `knowledge/`, `SKILL.md` docs) that is model-agnostic, and an **automation layer** (Claude Code hooks, plugin-channel agents under `plugins/*/agents/`, field-project overrides under `.claude/agents/`, `/model`, settings.json) that is Claude-native. Codex users run the methodology layer by reading `SKILL.md` files directly; automation steps either run through runtime adapters (`fh-gate`, `fh-run`) or require manual substitution.

## Validated invocation pattern

```bash
# headless, stdin — codex-cli >= 0.135.0
cat plugins/fh-meta/skills/<skill>/SKILL.md path/to/artifact \
  | codex exec -m gpt-5.5 -
```

- `codex exec -m gpt-5.5 -` reads the combined prompt from stdin and runs headless.
- `npx @openai/codex` (interactive) requires a TTY and is **not** suitable for piped skill application.
- Inside a git repository (e.g. a clone of this repo) no extra flag is needed. **Outside** a git repo (e.g. running from `/tmp`), add `--skip-git-repo-check`.
- `codex exec` has its own file-read tools, so a skill that back-traces claims to source files (e.g. `phantom-quench`) can verify paths itself — it produced real `file:line` citations in validation.

## Runtime adapters

### `fh-gate`

`fh-gate` supports both Claude and Codex backends with the same governance prompt and verdict parser:

```bash
# Default, backward-compatible Claude path
npx --package @chrono-meta/fh-gate fh-gate "src/foo.ts" quick ci

# Codex as the primary reviewer
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate "src/foo.ts" quick ci

# Prefer Codex if installed, otherwise fall back to Claude
FH_BACKEND=auto npx --package @chrono-meta/fh-gate fh-gate "src/foo.ts" quick ci
```

Backend defaults:

| `FH_BACKEND` | Command | Default model |
|---|---|---|
| `claude` | `claude --print --model "$FH_MODEL"` | `claude-sonnet-4-6` |
| `codex` | `codex exec -m "$FH_MODEL" -` | `gpt-5.5` |
| `auto` | `codex` if present, otherwise `claude` | backend default |

### `fh-run`

`fh-run` bridges skill and agent execution that previously assumed Claude Code slash commands or `Agent(...)` dispatch:

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run \
  --skill phantom-quench \
  --file docs/foo.md

FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run \
  --agent fh-commons:quench-challenger \
  --file plugins/fh-meta/skills/foo/SKILL.md
```

Resolution order:

| Unit type | Lookup |
|---|---|
| `--skill name` | `plugins/fh-meta/skills/name/SKILL.md`, then `plugins/fh-commons/skills/name/SKILL.md` |
| `--agent name` | `.claude/agents/name.md`, then `plugins/fh-meta/agents/name.md`, then `plugins/fh-commons/agents/name.md` |
| `--agent plugin:name` | `plugins/plugin/agents/name.md` first |
| `--unit path` | explicit file path |

### `fh-codex-doctor`

`fh-codex-doctor` is the drift detector for the thin Codex adapter boundary. It reads the canonical
FH skill/agent files plus the documented M1/M2/M3 tier table, then reports which surfaces are
Codex-native, adapter-required, Claude-native, or unclassified:

```bash
npx --package @chrono-meta/fh-gate fh-codex-doctor --strict
```

Use it before promoting a new Codex automation path. Unknown Claude-native primitives fail closed as
"manual adaptation required" instead of being treated as compatible by default. When run from an FH
checkout it scans the current working tree; outside a checkout it scans the installed package.

### `fh-goal`

Codex has native goal/session features. Use those directly when they fit. `fh-goal` is not a replacement for Codex goal; it is a non-interactive wrapper for "run backend task, then run FH governance on changed files":

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-goal \
  --prompt "Implement X and update tests" \
  --gate quick
```

## Author-run M1 validations (2026-06-04)

These are **author** runs — they confirm the M1 tier assignments are accurate and ground the limitations below. They do **not** count toward the external-validation gate (conditions #1 and #3 below), which by definition requires non-author users.

| Skill | Tier | Method | Result |
|---|---|---|---|
| `phantom-quench` | M1 | Fed a fixture with 2 real + 2 phantom claims (a non-existent skill path, a fabricated "47 M1 skills" count) | **4/4 correct** — both real claims Grounded with `file:line` citations, both phantoms caught (the fabricated count corrected against the actual `AGENTS.md`) |
| `asset-placement-gate` | M1 | Fed a proposed `phantom-checker` skill that duplicates `phantom-quench` | **Correct** — applied the 4-criteria bar, flagged criterion ④ overlap, routed to **Drop** with "route intent to phantom-quench" |

Both ran end-to-end with no Claude-native dependency. The M1 tier claim holds for the two skills tested.

## Known limitations

### 1. CC-native hooks fire and fail (noise, not breakage)
When `codex exec` runs **inside this repo**, FH's Claude-native git/Stop/PostToolUse hooks attempt to fire and emit `hook: Stop Failed` / `hook: PostToolUse Failed` lines interleaved with output. These are **harmless to the skill result** — the skill's verdict is produced correctly — but they are visible noise. Running from a directory **without** FH's `.claude/settings.json` (the normal Codex-user case) avoids them entirely. Filter with `grep -vE "^hook:"` if needed.

### 2. M2 skills need manual agent substitution
M2 skills (`deliberation`, `steel-quench`, `harness-doctor`, `context-doctor`, `sim-conductor`, `harvest-loop`) have a core workflow that runs under Codex, but any step that dispatches `Agent(subagent_type=...)` or a slash command must be replaced by `fh-run` or a direct `codex exec` call reading the sub-agent's `SKILL.md`/agent `.md` — same workflow, different runtime (the "M2 adaptation pattern" in `AGENTS.md`). Example: `steel-quench` Waves 1–3 run; the `quench-challenger` agent step becomes `fh-run --agent fh-commons:quench-challenger`.

### 3. M3 skills do not run automatically under Codex
M3 skills (`goal-quench` Phase-3 Stop hook, `hub-cc-pr-reviewer` CC session context, `install-wizard` settings.json write) require Claude-Code-native runtime and are **methodology reference only** under Codex unless a dedicated adapter exists. Use Codex's native goal/session features for goal control, and use `fh-gate` after completion for FH quality gating.

### 4. No token accounting
Codex token usage is billed in the Codex CLI quota and is **not** recorded in any FH session log or orchestrator measurement. Cross-family runs (Gemini/Codex) are invisible to FH's token-budget tooling by construction.

### 5. Cross-family sibling note (Gemini)
The sibling pattern for Gemini is `gemini -p "$(cat <skill+artifact>)"`. Outside a trusted directory Gemini requires `--skip-trust` (or `GEMINI_CLI_TRUST_WORKSPACE=true`). Gemini's headless output may bracket identifiers (`[ID]:`) where Codex does not — parse tolerantly.

## Per-tier expectation summary

| Tier | Under Codex | Action |
|---|---|---|
| **M1** | Runs fully (`token-budget-gate`, `asset-placement-gate`, `phantom-quench`, `deep-clarify`, `convergence-loop`, `ko-tech-writer` (visual-QA degrades to text-only; the spoken register's Step 5-s renders audio through a shell TTS call — available here — but its **listening** pass is human in every runtime, so it degrades to declared-unmet, not to a Codex-specific gap)) | `cat SKILL.md artifact \| codex exec -m gpt-5.5 -` |
| **M2** | Core runs; agent/slash steps via adapter (`deliberation`, `steel-quench`, `harness-doctor`, `context-doctor`, `sim-conductor`, `harvest-loop`) | Substitute each dispatch with `fh-run` or a direct `codex exec` on the sub-agent's `.md` |
| **M3** | Does not run automatically | Use native Codex session features where available; otherwise read as methodology reference or use a dedicated adapter |

## Beta removal — remaining (external-blocked)

🟥 **"Beta" can mean two different things here, and only one of them is a condition to be completed.**

| Sense | What it says | Is it a removal condition? |
|---|---|---|
| ⓐ **Scope** — partial support | The automation layer (hooks, sub-agent dispatch, slash commands) is Claude-Code-native *by construction*. Codex runs the methodology layer plus adapters. | **No.** This is the intended two-layer boundary, not a gap to be closed — the READMEs say exactly that. 100% parity is not a state this document is working toward, so do not write completion conditions against it. |
| ⓑ **Validation maturity** — thin external evidence | Everything validated so far is author-run (see the M1 table above). No non-author has reproduced it. | **Yes.** This is what the `Status: beta` header means, and **every condition in the table below is a ⓑ condition.** |

| Condition | Status |
|---|---|
| Known limitation list published (this doc) | ✅ done (2026-06-04) |
| 5+ externally validated M1 skill runs (not FH author) | ⬜ pending — needs external Codex users |
| At least 1 external Codex user confirms methodology reproduces | ⬜ pending — needs external Codex users |
| ~~README badge updated (`Codex-compatible` without `beta`)~~ | 🚫 **RETRACTED 2026-08-23 — no longer a condition.** The `Codex-beta · help validate` badge was removed from all four README variants that day (operator decision), so this condition named an artifact that no longer exists — a completion condition pointing at nothing. Beta status is now carried by this document's own `Status:` header, which every README links to from its Codex section. Struck through rather than deleted: a silently dropped condition is indistinguishable from one that was quietly met. |

To report a validated run, open an issue at `chrono-meta/forge-harness` with label `codex-validation`.
