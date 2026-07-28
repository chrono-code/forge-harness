# AGENTS.md — forge-harness Sub-Agent Specs

> **This file is the runtime agent specification registry for forge-harness.**
> For session rules and orchestration protocol, see `CLAUDE.md`.
> For skill descriptions and natural language triggers, see `plugins/fh-meta/` and `plugins/fh-commons/`.

---

## Relationship to CLAUDE.md

| File | Scope | Audience |
|---|---|---|
| `CLAUDE.md` | Session rules, protocols, orchestration flow | AI (Claude Code) — operational ruleset |
| `AGENTS.md` | Runtime agent specs — roles, tools, invocation | AI + humans — agent registry |

CLAUDE.md governs *how* the session runs. AGENTS.md defines *what each agent does* when dispatched.

---

## Agent Registry

forge-harness ships 8 tracked agents across plugin `agents/` directories. The **user-mastery spectrum** (`beginner` · `main-player` · `expert`) plus `challenger` (adversarial axis) supply multi-persona review; `fact-checker`, `hub-persona-auditor`, and `persona-innovator` serve general harness operations; `quench-challenger` is steel-quench-dedicated.

| Agent | File | Role | Invoked by |
|---|---|---|---|
| `beginner` | `plugins/fh-meta/agents/beginner.md` | First-contact cold-read standpoint (spectrum entry tier) — onboarding friction a fluent author cannot feel; constructive, not adversarial | `sim-conductor` Area A, `marketplace-gate`, `install-wizard`, or direct dispatch |
| `main-player` | `plugins/fh-meta/agents/main-player.md` | Engaged-user standpoint (spectrum core tier) — intelligently scopes Light/Midcore/Heavy; Heavy = classic power-user edge/limit lens | `sim-conductor` Area A/D-code, or direct dispatch |
| `expert` | `plugins/fh-meta/agents/expert.md` | Domain-authority standpoint (spectrum frontier tier) — web-grounded accuracy + SOTA currency, citation-enforced | `sim-conductor` Area E/D, paper review, or direct dispatch |
| `challenger` | `plugins/fh-meta/agents/challenger.md` | Frontier-grade adversarial evaluator — adapts attack vectors to artifact type, enforces evidence citation, models its own information asymmetry; U1 absorbs the skeptic "why not just X?" lens | `steel-quench`, `harvest-loop`, `sim-conductor`, or direct dispatch |
| `fact-checker` | `plugins/fh-meta/agents/fact-checker.md` | Pre-recommendation deduplication — greps hub assets for existing skills/agents/patterns before main agent commits to a new recommendation; catches stale facts and duplicate work | Main agent before any new asset creation or recommendation |
| `hub-persona-auditor` | `plugins/fh-meta/agents/hub-persona-auditor.md` | Pre-publication audit of external-facing assets — 3+ persona simulation, 4-axis review (resonance/confusion/resistance/supplement), 3-tier revision proposals | `hub-cc-pr-reviewer`, `sim-conductor`, or direct dispatch |
| `quench-challenger` | `plugins/fh-commons/agents/quench-challenger.md` | Steel-quench dedicated adversary — 3-DNA synthesis of Devil + Innovator + Prescriber; every attack paired with a concrete fix direction | `steel-quench` Wave 1 (primary), `install-doctor`, `marketplace-gate` |
| `persona-innovator` | `plugins/fh-meta/agents/persona-innovator.md` | Naming gap detection + frame proposals + external frontier absorption signals | `sim-conductor` Area A, `harvest-loop`, or direct dispatch |

> Machine-readable mirror: `.claude/registry/agent_cards.json` (canonical capability cards, count-synced to tracked agent files — A2A Agent Card pattern).

### Tool restrictions per agent

| Agent | Allowed tools | Rationale |
|---|---|---|
| `challenger` | Read, Grep, Glob, WebSearch, WebFetch | Needs external evidence; no writes |
| `fact-checker` | Read, Grep, Glob | Deduplication grep only — no modification |
| `hub-persona-auditor` | Read, Grep, Glob | Audit only — no modification |
| `quench-challenger` | Read, Grep, Glob | Attack+prescription only — no modification |
| `persona-innovator` | Read, Grep, Glob, WebSearch, WebFetch | Frontier scanning requires web access |

---

## 2-Layer Architecture Context

forge-harness is structured as two distinct layers:

| Layer | Contents | AI compatibility |
|---|---|---|
| **Methodology layer** (model-agnostic) | `tracks/`, `knowledge/`, `SKILL.md` documents, session protocols | Any AI model |
| **Automation layer** (Claude-native) | `plugins/*/agents/` (plugin channel — FH's own agents, auto-loaded when the plugin is enabled), hooks, slash commands, `CLAUDE.md` rules; `.claude/agents/` is the field-project local/override slot, unused by FH itself | Claude Code only |

Agents in this registry belong to the **Automation layer**. Skills (in `plugins/`) straddle both layers — their methodology is model-agnostic, but their invocation mechanism is Claude Code-native.

> **Codex-compatible beta**: The Methodology layer (`tracks/`, `knowledge/`, skill documentation) is designated Codex-compatible beta. Gemini, Codex, and other AI users can apply FH methodology without the Automation layer — manual invocation replaces hook/agent dispatch.

> **Directory → destination routing (where your outputs belong)**: not everything in the methodology layer is public-shareable. `knowledge/` and `SKILL.md` docs are the **public, reusable** methodology. `tracks/` is **local / private by convention** — work history, session records, `fh_signal_*`, audit logs — and is gitignored on the public mirror. An AI working in a local workspace that pairs the public mirror with a private companion store (the `*-be` pattern) must **not** infer "same folder ⇒ same repository"; route by content type:
>
> | Content | Default destination |
> |---|---|
> | reusable methodology · docs · skills · public guidance · polished external-facing conclusions | public mirror (`knowledge/`, `plugins/`, `docs/`) |
> | raw signal · operator observation · private validation · handoff · paper draft · PR-background reasoning log | private companion store (`*-be` pattern) — or keep local; do **not** commit to the public mirror |
>
> When unsure, treat raw / observational / operator-specific material as **private-first** and promote only the polished result to public. (Concrete per-operator bindings — exact companion-store path, sync mechanism — live in the operator's local config, not here.)

> **Multi-model sidecar (validated)**: Any FH user can delegate to other models via sidecar — Gemini CLI, OpenAI/Codex CLI, or Copilot CLI's model catalog — invoked with `Bash` from within the Claude Code session. FH is the orchestrating harness; the sidecar is a routing/access layer (not a second harness — different layer entirely). Validated empirically: `echo "prompt" | gemini` works inside a CC session and produces usable output. Sidecar calls are Bash invocations, not agent dispatches — they bypass this registry and are coordinated inline by the skill. Capability routing matters too: Gemini/Antigravity is the natural breadth/multimodal sidecar, while Codex's primary cast is the **repo-grounded audit** sidecar (file reads · grep/source-close · diff & patch · gate execution · phantom/backtrace) — **not** discovery/design-depth; a Codex session with Browser/Chrome connectors mounted can additionally take live web-flow automation as a capability-routed handoff. In a local FH workspace that pairs the public methodology mirror with a private companion store (the `*-be` pattern), route by workspace capability while preserving each repository's ownership boundary. See `knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Runtime Authority` for the authority model and the full pattern.

> **Waiting on a sidecar — mechanical, not by eye (2026-07-29).** A sidecar you dispatched is judged
> ONLY by the typed verdict line from `scripts/sidecar_wait.sh`:
>
> ```bash
> printf '%s' "$prompt" | bash scripts/sidecar_wait.sh out.txt 900 -- codex exec -m gpt-5.5 -
> #   SIDECAR_VERDICT=COMPLETE exit=0 bytes=48489   → read out.txt
> #   SIDECAR_VERDICT=TIMEOUT  waited=900s bytes=0  → STILL ALIVE, not a result
> #   SIDECAR_VERDICT=EMPTY    exit=0               → the only state meaning "it said nothing"
> ```
>
> **Never judge a sidecar by looking at its output file.** A live process and a dead one produce the
> same zero bytes, and only process state separates them. Measured here: a session backgrounded two
> sidecars, read their files after 1 s and 30 s, recorded *"both returned 0-output"* into five
> records — and both had answered, with four real findings, one of which showed the change under
> review was over-applied. The mis-read nearly retired a working mechanism. This rule is repeated in
> this file because line 71 tells you to invoke sidecars with `Bash`; a runtime reading only that
> would dispatch with no waiting discipline at all. Canonical: `auto-decorrelation` SKILL.md §S-1b.

> **Runtime authority — hard stop line (Codex / non-Claude runtimes):** your findings are **evidence candidates, not terminal verdicts**. They are not final until the governor source-closes them against a **mechanical anchor** (a local file hit · a literal source span · a passing check) — **never governor agreement alone**. You are a capability-routed **sidecar**, not a co-governor: there is one explicit governor per context. Full doctrine: `knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Runtime Authority`.

---

## Invocation patterns

### Single agent dispatch

```
Analyze this SKILL.md for structural flaws before I commit it.
```

→ Claude dispatches `quench-challenger` automatically (description-triggered).

### Parallel dispatch (2+ independent tasks)

```
Run fact-checker and persona-innovator in parallel.
  First: check [asset path] for duplicates
  Second: scan for naming gaps in the current harness
```

→ Both agents run concurrently in Agent View; results are integrated by the orchestrator.

### Wave-based composition (via agent-composer)

For complex multi-step tasks, run `/agent-composer` first to plan which agents to dispatch in which order (Wave 0 reconnaissance → Wave 1 execution → Wave 2 synthesis).

---

## Codex Compatibility (beta)

The methodology layer (`tracks/`, `knowledge/`, `SKILL.md` docs) is Codex-compatible beta. Any AI model can follow skill workflows by reading SKILL.md files directly; the automation layer (hooks, plugin-channel agents under `plugins/*/agents/`, `/model`) is Claude Code-native and requires manual adaptation. FH's own agents are auto-loaded via the plugin channel when the plugin is enabled — `.claude/agents/` is the field-project override slot, not where FH ships its agents. Non-Claude runtimes use this `AGENTS.md`, `plugins/*/agents/*.md`, and `scripts/fh-run.sh` to apply the same methodology via adapter.

### Non-Claude runtimes: five things CLAUDE.md holds that you will not auto-load

`.claude/rules/*.md` with `paths:` frontmatter is a **Claude Code platform feature** — those files are
auto-loaded into a Claude Code session when it reads a matching file, and **your runtime has no equivalent**.
So five things that govern behavior are not going to reach you on their own. Read them explicitly:

1. **FH asset changes run a mandatory 4-axis verification chain before the session's first commit.**
   Detail (axis definitions · marker required fields · lightweight exception · substantive carve-out):
   `.claude/rules/fh_4axis_gate.md` — **open it directly**; nothing will load it for you. The commit is
   hard-blocked by `templates/.git-hooks/pre-commit` regardless of runtime, so skipping the read does not
   skip the gate — it just means you meet the block without knowing what it wants.
   ⚠️ If you run `templates/regression_guard.sh` (Axis 1) yourself, **`exit 0` means PASS *or* SKIP** —
   SKIP being "no staged file matched the gate's pathspec", which is *not checked*, not *checked and
   clean*. Prefer the typed file channel — set `REGRESSION_GUARD_RESULT_FILE=<path>` and read
   `result=pass|review|block|skip|error` from that file (stdout's `REGRESSION_GUARD_RESULT=` line is
   the no-env fallback). Judging by exit code
   alone lets an unexamined change report as a pass (measured 2026-07-22: that is exactly what the
   commit hook did until it was fixed).
2. **Company residency is absolute** (CLAUDE.md §Field-Harness Diagnostic): raw company source, secrets,
   hostnames, internal repo/asset names, stack traces, and unredacted findings **never leave the local
   machine** — not to an external *or same-family* cloud model, not through a browser/API tool, not into a
   log, comment, or paste. Outbound gets a **sanitized summary only**; exceptions need explicit operator
   approval plus a gitignored audit note. This binds every runtime, not just Claude Code — a leak does not
   un-happen, and the guard is worth nothing if it only lives where one runtime reads.

3. **Before calling a material work product done, name what you are blind to.** CLAUDE.md routes the
   everyday "commit and merge this" moment to `agent-composer` **§Author-Exposure Table** — a review
   pass keyed on *what the author cannot self-detect* (cold entry → `beginner` · everyday friction →
   `main-player` · outside currency → `expert` · optimistic self-verification → `challenger` +
   cross-family · rebuilding what exists → `fact-checker` · ungrounded numbers → `phantom-quench`),
   with a materiality gate and an `Exposure-unclear → challenger` default so "no row applies" is not
   an exit. **This row exists because the triggering utterance names no agent** — nothing will fire it
   for you. Your runtime *can* run these lenses: substitute `Agent(subagent_type=...)` per §M2 above
   (`fh-run`, or `codex exec` reading the agent spec). The lens returns evidence, never the verdict.

4. **General work is in scope here, and the mechanism for serving it is to marshal installed
   capability.** CLAUDE.md §Intent Marshaling makes this the runtime default. It settles a *category*
   question only — whether non-harness work belongs in this environment at all. Every ordinary check
   about a specific request (is it safe, sensible, well-formed, worth doing) is yours and is unaffected.

   The category answer is yes, for a concrete reason: the skill registry, the mapped field harnesses,
   and the memory store exist **only** in this environment. So when the operator states a work intent in
   plain language (write this doc, build this wiki page, organize this material — **any work-shaped ask,
   not only harness building**), the scan below is what tells you whether capability for it is actually
   present. An empty scan, reported with the scan cited, is a correct answer — see the third bullet.

   Three constraints carry over unchanged to your runtime:
   - **Enumerate rather than recall.** List the available skills, `LOCAL_SKILL_REGISTRY`, and the mapped
     project assets. Recall under-reports what is installed, which is why the scan is a listing step.
   - **Marshaling never upgrades a trust tier.** Run-first autonomy covers **FH-native capability whose
     steps are per-action reversible**. A non-FH sibling capability stays at its registry `ask-tier`
     (propose only), and an outward-mutating action (send · post · deploy · delete) keeps its own gate.
   - **A capability gap is declared by citing the scan result**, not as a bare "nothing fits" — then
     route at request scale (internal scan → external search → in-session synthesis). *Persist* routes
     to the New-Skill gate; *install* routes to plugin-recommender's HITL. No new gates.

   **This item exists because the triggering utterance is ordinary work language that names no skill and
   no agent** — like item 3, no automatic trigger covers it; read it explicitly.

> **Detail**: See `knowledge/shared/harness-core/intent_marshaling_general_work.md` — the 5-step loop,
> the gate-routing table, the Sonnet-floor boundaries, and the origin defect — **open it directly**
> before applying the ladder or when a gap appears.

5. **A scan, checker, or metric in this repo is not evidence until it has been shown to work on the
   target you are pointing it at.** This one is easy to skip because the tooling looks finished, so it
   is worth two cheap steps before you rely on a number it produces:

   - **Run it against one case you already know the answer to, and one you know is clean.** A tool that
     cannot separate those two has not been shown to measure anything, so its output cannot ground a
     claim about the target — it may still be right, you just have no way to tell. This
     repo has produced that exact result more than once — an ASCII-token scanner run over a Korean
     corpus scored ~96% false positives, and a shell-shape scanner reported a fail-open script as
     "clean" because every one of its probes was written for Python syntax.
   - **Open one hit by hand before you state a count anywhere** — including in chat, not only in a file.
     An unverified figure is anchored the moment it is said, and then has to be corrected everywhere it
     travelled.

   Two conventions that follow from this, and that the rest of the repo assumes you are using:
   *an empty result is not a zero* — a scan that found no target files, or died mid-run, reports
   `UNMEASURED`, never `0` — and *an extreme result (everything passed, everything failed) is a reason
   to suspect the instrument before the target.*

   Nothing enforces this mechanically; the trigger is your own intent to trust an output, which no hook
   can see. Detail, including the known-pair procedure and the failure catalogue:
   `knowledge/shared/harness-core/measurement-integrity-checklist.md` — **open it directly** before
   running a scan whose count you will report.

The irreversible-surface gates (Pre-Publish · Destructive-Op) likewise live in CLAUDE.md and fire on
**intent**, not on a file — read them before any publish, delete, or history-rewrite. `pre-push` enforces
the git-side destructive surface mechanically for every runtime.

### Entry point for Codex users

AGENTS.md is your starting point. Navigate from here to skill workflows:

```bash
# Read a skill's full workflow
cat plugins/fh-meta/skills/steel-quench/SKILL.md

# Apply via codex exec (validated pattern — codex-cli ≥ 0.135.0)
cat plugins/fh-meta/skills/steel-quench/SKILL.md path/to/artifact.md \
  | codex exec -m gpt-5.5 -

# Or use FH's runtime adapter (preferred for Codex-primary workflows)
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run \
  --skill steel-quench \
  --file path/to/artifact.md

# Agent substitution for Claude Code Agent(...) calls
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run \
  --agent fh-commons:quench-challenger \
  --file path/to/artifact.md

# Or pipe explicitly
echo "Apply the following skill to the artifact below." | \
  cat - plugins/fh-meta/skills/{skill}/SKILL.md target.md \
  | codex exec -m gpt-5.5 -
```

`codex exec -m gpt-5.5 -` reads from stdin in headless mode. `npx @openai/codex` (interactive) is not suitable — it requires TTY.

### Skill compatibility tiers

| Tier | Definition | Examples |
|---|---|---|
| **M1 — Full** | All phases run without CC-native dependencies — no Stop hook, no `.claude/agents/` dispatch, no `/model` | `token-budget-gate`, `asset-placement-gate`, `phantom-quench`, `deep-clarify`, `convergence-loop` |
| **M2 — Partial** | Core workflow runs; CC-native phases require manual adaptation or skip | `deliberation` (Mediator/Jury Agent steps = manual), `steel-quench` (Wave 1–3 ✅; quench-challenger agent = manual), `harness-doctor`, `context-doctor`, `sim-conductor`, `harvest-loop` (git scan phase ✅; PR auto-proposal = manual) |
| **M3 — CC-only** | Requires CC Stop hook or session-scoped agent dispatch; methodology reference only | `goal-quench` (Phase 3 Stop hook), `hub-cc-pr-reviewer` (CC session context), `install-wizard` (settings.json write) |

**M2 adaptation pattern**: when a step references `Agent(subagent_type=...)` or a slash command, substitute with `fh-run` (preferred) or a direct `codex exec` call reading the sub-agent's SKILL.md — same workflow, different runtime.

**Goal handling under Codex**: use Codex's native goal/session feature when available. FH's portable role is the quality gate after the goal completes: `FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate ...`. `fh-goal` exists only for non-interactive one-shot runs that should be followed automatically by `fh-gate`; it is not a replacement for Codex-native goal control.

### Beta removal conditions

| Condition | Status |
|---|---|
| Known limitation list published (`docs/codex-compat.md`) | ✅ done (2026-06-04) |
| 5+ externally validated M1 skill runs (not FH author) | ⬜ pending — needs external users |
| At least 1 external Codex user confirms methodology reproduces | ⬜ pending — needs external users |
| README badge updated (`Codex-compatible` without `beta`) | ⬜ blocked on above |

**Author M1 validation (2026-06-04, internal — does not satisfy the external conditions above):** `phantom-quench` (4/4 on a phantom-seeded fixture) and `asset-placement-gate` (correct Drop routing on a duplicate-skill proposal) ran end-to-end via `codex exec -m gpt-5.5 -` with no CC-native dependency, confirming the M1 tier assignments. Limitations observed (CC-native hook noise, no token accounting, etc.) are documented in `docs/codex-compat.md`.

Tracking: open an issue at `chrono-meta/forge-harness` with label `codex-validation` to report a validated run.

---

## Adding new agents

New agents must pass the **New Skill Creation Pre-Commit Gate** defined in `CLAUDE.md` before committing. Key requirements:

1. Role duplication check via `/asset-placement-gate`
2. Plain description — no self-marketing language
3. At least 1 explicit `Done When` condition
4. At least 3 natural language trigger examples
5. Independently executable (or dependencies explicitly documented)

After 2+ weeks of use: if `accepted ≥ 60%` of invocations → strengthen; if `rejected ≥ 40%` → redefine scope or deprecate. See `CLAUDE.md > Sub-agent Operations`.
