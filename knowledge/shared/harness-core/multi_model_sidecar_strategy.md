---
name: multi-model-sidecar-strategy
description: Pattern for invoking other AI models (Gemini, Codex, Copilot CLI) as sidecars from within a Claude Code / FH session via Bash tool. Token economy, model-access fallback, and adversarial diversity use cases.
date: 2026-05-31
tags: [multi-model, sidecar, token-economy, model-access, adversarial, internally-validated]
status: mechanism-validated (cross-provider grader confirmed 2026-06-02)
---

> **Validation status** (updated 2026-06-02): mechanism validated by cross-provider grader.
>
> 2026-06-01 steel-quench (Issue #47): mechanism confirmed runnable — implementation shipped in PR #36/#37. Original empirical claims (Experiment 1·2) were an internal same-session self-report; raw transcripts not retained, codex grader blocked by network policy.

> **사이드카 대기는 기계로 한다** — `scripts/sidecar_wait.sh` 경유가 필수 형식이고, 타입 verdict
> (`COMPLETE`/`TIMEOUT`/`EMPTY`)만 읽는다. **`EMPTY` 만이 "사이드카가 아무 말 안 했다"** 이다.
> 출력 파일을 눈으로 보고 판정하지 마라 — 살아있는 프로세스와 죽은 프로세스가 같은 0바이트를
> 낸다(2026-07-29 실측: 1초/30초 만에 읽고 정상 동작 중인 사이드카 2종을 '실패'로 기록,
> 실제로는 4건의 진짜 finding 이 나왔다). 정본 = `auto-decorrelation` SKILL.md §S-1b.
>
> 2026-06-02 update: Gemini 0.41.2 cross-provider grader run on `pipeline-conductor/SKILL.md` (retained transcript: `tracks/_meta/grader_gemini_pipeline_conductor_2026_06_02.txt`). Gemini found 3 S-grade findings (interaction deadlock, PR-approval deadlock, cadence-lock deadlock); Claude Sonnet-4.6 previously found 3 different S-grade findings (model conflict, invocation contradiction, self-referential sweep). **Zero overlap across 6 S-grade findings** — validates the non-overlapping failure modes claim and perspective diversity mechanism. Provider-identity diversity is empirically confirmed; specific Experiment 2 finding counts on goal-quench (original target) are not directly re-run. Record: `tracks/_meta/grader_gemini_pipeline_conductor_2026_06_02.txt`.

# Multi-Model Sidecar Strategy

## Thesis grounding — hierarchy of differentiation

FH's paper thesis: **the harness (specialized shell) is the durable layer; the model (core) converges across providers.**

Empirical observation from 3-round orchestrator-swap experiment (Claude → Gemini → Codex as orchestrator, others as sidecars, same FH skill as target):
- **Process differs** — each orchestrator highlights different angles (Gemini: state machine + audit methodology; Codex: implementation-level parsing and dependency contracts).
- **Results converge** — 3 critical issues appeared in every round regardless of orchestrator identity (freshness guard pseudocode, BLOCKED deadlock, interim-commit false CLEAN).

This is precisely what the thesis predicts. But the experiment revealed a second-order effect not captured in the original framing:

**Process divergence → cross-wave delta → better convergence.**

The sidecar pattern's value is not parallelism — it is the *delta*. Each orchestrator's unique process angle produces non-overlapping findings. When synthesized, the combined result exceeds what any single-model run achieves. This is the mechanism by which the sidecar pattern compounds into a quality improvement, not just a coverage check.

The enabling condition for this entire chain is the harness:

```
Harness (FH)
  → consistent SKILL.md format loadable in all 3 CLIs
  → same skill runs under each orchestrator with comparable evaluation protocol
  → cross-wave delta is structurally comparable (apples-to-apples)
  → synthesis is valid
  → convergence improves
```

Without the harness, "multi-model adversarial review" is three separate unstructured prompts — no comparable protocol, no valid synthesis. The harness is not one of the differentiators in a hierarchy. **It is the activation condition that makes the hierarchy operate.**

Refined hierarchy:

| Level | What it is | Role |
|---|---|---|
| **Harness (present vs absent)** | Structured skill methodology, memory, verification protocol | **Activation condition** — makes all lower levels function |
| Orchestrator-swap sidecar | Process divergence → cross-wave delta → better convergence | Compounds quality via synthesis |
| Model A vs Model B (no harness) | Process differs, results converge weakly | Small, unstructured |

**The sidecar pattern is a quality compounding mechanism, not merely a process tool.** Process divergence produces insights that single-model runs miss. Those insights, when synthesized by the harness skill, produce a convergence that is richer than any single model's output. The harness is what makes this synthesis structurally valid.

Two shells — do not conflate:

| Shell | What it is | Layer |
|---|---|---|
| **Harness shell** (FH, forge-harness) | Methodology, rules, memory, skills — *specialization* accumulated over time | Durable orchestration layer — thesis subject |
| **Router shell** (Copilot CLI, Gemini CLI, Codex CLI) | Thin routing / access tool that selects and forwards to a model | Delivery / access mechanism — not a harness |

FH is the orchestrator. A router shell (or direct model CLI) is one kind of sidecar. Calling Copilot CLI "the harness" is a category error.

---

## Native cross-CLI portability (validated)

FH's SKILL.md format is shared across all three major AI CLIs. FH skills load natively in each environment without conversion or adaptation:

| CLI | Load mechanism | Status |
|---|---|---|
| **Claude Code** | `.claude/plugins/` native | ✅ Primary environment |
| **Codex CLI** | `SKILL.md` plugin (`fh-meta@forge-harness`) | ✅ Validated |
| **Gemini CLI** | `gemini skills install <path> --consent` | ✅ Validated — ⚠️ direct `gemini` CLI EOL 2026-06-18 |
| **Antigravity CLI** (`agy`) | `agy plugin install <local-path>` — Claude `.claude-plugin/` layout handled without conversion (bulk `agy plugin import claude` also exists) | ✅ Validated 2026-06-11 (agy 1.0.7) — fh-meta imported (32 skills + 7 agents); print-mode load probe reproduced phantom-quench purpose/trigger/Phantom-Claim definition from SKILL.md |

This means FH is not just model-agnostic in theory — the methodology layer physically runs in multiple CLI environments without modification. This is the empirical foundation for the cross-CLI portability claim.

> **Gemini-CLI → Antigravity migration (2026-06-18)**: **closed 2026-06-11, ahead of EOL** — same cheap
> gate Codex/Gemini passed. `agy plugin install ./plugins/fh-meta` (agy 1.0.7) imported 32 skills +
> 7 agents straight from the Claude `.claude-plugin/` layout (note: standalone `agy plugin validate`
> expects a root `plugin.json`, but `install` does not). Load probe in print mode answered
> phantom-quench's purpose, a trigger phrase, and the Phantom-Claim definition accurately and named
> steel-quench as a second visible skill. Two same-day measurements:
> (1) `agy -p` (print mode) **auto-approves tool calls** — it ran a shell command and read a file
> outside the workspace with no permission prompt (nonce-verified, not hallucinated). Headless sidecar
> dispatch therefore works like `codex exec` — no approval mode required; permission prompts belong to
> interactive mode.
> (2) Post-EOL caveat on the Gemini row: the binary outlives the backend, so `command -v gemini` keeps
> passing after 2026-06-18 while pipes degrade to empty output behind `2>/dev/null` guards — a silent
> degradation. Once EOL hits, sidecar team detection should probe `agy` first (follow-up:
> `fh_signal_2026-06-11_fh-direct`).

> **Load ≠ full parity**: "loads and lists as Enabled" means the SKILL.md *methodology* is readable and runnable as guidance. Skills whose steps dispatch a sub-agent (`Agent` tool, `fh-commons:*` challengers) or depend on slash-commands/hooks are **Claude-native** — on Gemini/Codex they degrade to manual methodology, not automated execution. Cross-CLI portability covers the *methodology layer*; the automation layer (sub-agents, hooks, slash commands) requires Claude Code as host. See `README.md §2-layer architecture`.

> **Check-class taxonomy = the model-portability map**: the Axis-5 check classes
> (`harness_6axis_framework.md` §Axis 5) double as the portability map. **Mandatory-pass** checks —
> and the mechanical subset of **measured** checks (scripts and greps that run with no model) — are
> model-independent *by construction*; model-produced measured scores (e.g. tier batteries) are
> tracked, not assumed flat. **Judged** checks are where model choice matters most, and
> judged-pairing bounds that sensitivity. Two consequences: (1) pushing a workflow's checks toward
> mechanical classes is a high-leverage portability move wherever mechanization is feasible — a
> mechanized check ports to any backend the moment it ships; (2) when auditing what survives a
> backend/tier swap, classify by check class first and re-validate the judged steps (the same
> discipline as §Floor governance's below-floor re-run rule, below) instead of re-testing
> everything. Judged-class tier sensitivity is what `docs/OUTPUT_EVIDENCE.md` actually measured —
> the "by construction" claim rests on the no-model property, not on that single trial.

## Orchestrator–sidecar model strategy

Use the strongest available model as orchestrator; delegate subsidiary tasks to lighter sidecar models for token economy:

| Role | Model selection | Rationale |
|---|---|---|
| **Orchestrator** | Strongest available (CC=Opus, Gemini=Pro, Codex=GPT-5.5) | Design, judgment, synthesis |
| **Sidecar** | Lighter versions (Gemini Flash, GPT-4o-mini, etc.) | Repetitive verification, adversarial passes, token-efficient delegation |

This combination can be freely mixed across CLIs — e.g., Gemini Pro orchestrating with Claude Haiku as sidecar, or CC Opus orchestrating with Gemini Flash. FH methodology works regardless of which combination is chosen.

## Runtime Authority — single governor + routed sidecars

> **Canonical doctrine (single source — runtime files point here, do not restate per-runtime).** The
> main/governor runtime is **context-specific and must be explicit**. Other models are
> **capability-routed sidecars** unless a document explicitly defines a limited-runtime entrypoint.
> **Sidecar findings are evidence candidates, not terminal verdicts, until source-closed by the governor
> *via a mechanical anchor* (a local hit / literal source span / passing gate) — never governor agreement
> alone** (the no-judge-only-path / mechanical-anchor principle, CLAUDE.md §FH Improvement 4-Axis Auto-Gate).

FH is a **multi-runtime harness with explicit runtime authority**, not Claude-only:

| Runtime | Authority | Fit task-class (aggressive *within* it, not blanket) |
|---|---|---|
| **Claude Code** | default **action/governor** — Claude-native automation, hooks, agents, MCP writeback, terminal verdict | orchestration · design-depth · synthesis · the writeback/commit path |
| **Codex** | **audit / repo-grounded sidecar** | file reads · grep/source-close · diff & patch · gate execution · phantom/backtrace (`fh-run` / `codex exec`). **NOT** discovery/design-depth — below-floor there |
| **Gemini / agy** | **breadth / multimodal sidecar** | wide alt-generation · multimodal/video/image · exploratory critique · non-code artifacts. Outputs stay **source candidates** until grounded |
| **Other runtimes** | **portable entrypoint only** (`AGENTS.md`) | apply FH methodology via adapter; do **not** inherit Claude-native automation or writeback authority unless explicitly scoped |

A sidecar is recruited where it adds *decorrelated* value; its ceiling is still set by the governor — the
harness lifts a model to its own ceiling, it does not move it ([[feedback_harness_ceiling_principle]]).
External causal anchor for *why* the ceiling sits in the weights (wsff.md, HumanLayer
`advanced-context-engineering-for-coding-agents` repo, Dex 2026, triaged 2026-07-24): RL rewards are pass/fail in seconds while architectural-decay costs surface over
weeks — *"maintainability has no fast oracle, so we can't reward for it during RL"* — hence the
human-review floor is structural, not a transitional patch. (Its Faros AI numbers are correlation-only;
the author's own caveat travels with any citation.)
"Aggressive" Codex/Gemini use is bounded by the fit task-class above, never a blanket main-seat swap.

### Decorrelation axes — model family AND authoring context (measured 2026-08-01)

Decorrelation has been treated as one axis (model family). A codex-outage session measured a second,
independent axis: **authoring-context share**. A 3-leg panel (agy/Gemini + local qwen3.6:35b + a
**same-family Claude challenger in an isolated context**) ran 3 rounds over qasp changes; the
distribution was sharp — the cheap local leg produced only refutable findings (2/2 source-rejected),
the cross-family leg caught real HIGHs, and the **context-independent same-family leg caught the
subtlest class** (a just-closed false-negative re-opened by an empty-canonical-key fall-through ·
a fabricated expected value · a doc insertion truncating a bullet). Author-optimism largely falls
away when the *context* is cut, even with the family held constant.

Operational rules this adds:
- A same-family isolated-context leg is a **legitimate decorrelation leg**, not a degraded
  substitute — count it as one axis covered (context), with family still uncovered. The honest
  disclosure when cross-family is unreachable is "family axis uncovered", not "no decorrelation".
- The two axes compose: cross-family + context-independent is stronger than either alone. The
  2026-08-01 follow-up run confirmed composition empirically — a GPT leg (OpenRouter, operator-directed
  codex substitute) surfaced whole defect classes that both a Gemini leg and a context-independent
  Claude leg had passed over (parser-bypass construction paths, duplicate-JSON-key ambiguity), while
  the earlier legs had caught classes GPT did not re-find.
- **Review-target pinning corollary** (accidental pattern, worth reproducing deliberately): pin the
  review target to a COMMIT while fixes proceed uncommitted in parallel — two legs then cross-confirm
  each other when their findings independently converge on the same defects, converting duplication
  into validation instead of waste.

### Vendor-native harness — the main layer stays multi-CLI, never Copilot-consolidated

The harness-depth thesis has a **per-vendor corollary**: a frontier model realizes its *highest effective
capability inside its own vendor-native CLI/harness* — Claude in Claude Code, GPT in the Codex CLI, Gemini
in Antigravity — because each vendor tunes its full agentic loop (infer→act→observe + tools + context +
control) for its own model. A **universal router that wraps all of them** (GitHub Copilot) is a *thin*
surface with no vendor-native harness depth, so routing any model through it **strips the native-harness
buff and degrades that model's realized intelligence** — not just Claude's. This makes the earlier
"router shell" row (Copilot / Gemini CLI / Codex CLI as one class) **too coarse**: the *native* CLIs
(`codex`, `agy`/Antigravity) are full vendor harnesses and belong at their fit task-class above; only the
*cross-vendor* router (Copilot) is the thin surface.

**Consequences (design-locked):**
- **Main orchestration stays as-is** — FH pipeline + each vendor's native agent (Claude Code + Codex +
  Antigravity), each on its own subscription/CLI. The synergy of that native-multi-CLI layer outweighs any
  cost-consolidation Copilot offers; do **not** collapse the main layer into one router.
- **Copilot's proper position = a harness-less sidecar** — lightweight inline autocomplete + simple Q&A.
  It is *not* an orchestration layer and *not* the preferred cross-family access when native CLIs reach.
- **Never route a model through Copilot when its native CLI is reachable** — copilot-Claude ⟪ native CC,
  copilot-GPT ⟪ native Codex, copilot-Gemini ⟪ native Antigravity (harness depth + no decorrelation gain
  if same family as governor + usage-credit cost).
- **The one legitimate Copilot cross-family use is egress-bounded** — in a *restricted corporate network*
  where the native `codex`/`agy` CLIs cannot reach out, Copilot's **enterprise Pro+ catalog** becomes the
  fallback *access* path to non-Claude frontier families (GPT/Gemini) for a one-shot decorrelation call —
  still a sidecar, never the main seat (company-env panel: [[reference_corp_env_decorrelation_panel]]).
  On a personal machine with a *free* Copilot tier this cross-family value does not even exist — free tier
  is autocomplete/QA only, which is exactly its demoted role. (Derived 2026-07-03, operator + cross-vendor
  Gemini concurrence; extends the governor=native-CC point to every vendor.)

### Batch-judging corollary — the native harness is for interactive/agentic work, not batch scoring

The vendor-native harness gives a model its highest capability for **interactive, agentic** tasks
(repo-grounded audit, multi-step design, tool-use) — but that *same* agentic loop is a **liability for
high-volume batch judging**: a deterministic verdict emitted over N fixtures, where there is nothing for a
tool-use loop to do. Measured 2026-07-04 (H1 verdict-invariance run): the native `codex exec` spins a full
agentic session per judge (hooks + reasoning ≈ an order of magnitude more tokens than a bare completion),
and native `agy -p` (once its headless permission-wait is cleared) returns *agentic prose* — a "Summary of
Work" — rather than a parseable last-line verdict. Both **complete**, but at a cost/parse profile wrong for
batch.

So the dispatch splits by *shape of the task*, not just by family:

- **Batch cross-family judging** (steel-quench Step 0.6 verdict-invariance, auto-decorrelation over many
  items, any fixed-fixture flip count) → **clean completion APIs** (OpenRouter, model pinned by
  *display-name* + `served`-field silent-route check) **+ free local** (a 4090 ollama endpoint). Clean,
  cheap, parseable, per-call pinnable. *Caveat*: a local thinking model needs a large enough output budget
  or it truncates inside `<think>` and emits an empty verdict — a config axis, not a capacity limit.
- **Interactive / agentic verification** (repo-grounded catching, the divergence audits where cross-family
  disagreement *localizes* a bug) → the **native CLIs** (`codex`, `agy`/Antigravity), where the harness
  earns its overhead.

This is **not** a contradiction of the harness-depth thesis — it *is* it. The harness lifts capability
exactly where judgment + tools + iteration matter; for a one-shot self-contained verdict the loop has no
work, so its depth becomes pure cost. Pick the naked API for batch scoring, the native harness for agentic
audit. (Derived 2026-07-04, operator + H1 measurement; the batch-side dual of the vendor-native thesis
above. The native-harness Gemini path via `agy` is headless-usable again once tool-permission auto-proceed
is set — see [[reference_agy_model_catalog]] for the pin/permission mechanics.)

**Maintenance-Cost Rule** — a compatibility layer is cheap as a *thin entrypoint*, expensive when it
*duplicates canonical knowledge*. The test:

| Pattern | Cost | Verdict |
|---|---|---|
| Runtime-specific `AGENTS.md` with capability routing + stop lines | Low | ✅ Good |
| Sidecar-invocation docs pointing to canonical skills/agents | Low | ✅ Good |
| Generated wrappers with drift checks | Medium | Use only if a need is proven |
| Manual copies of agent/skill bodies per runtime | High | ✗ Avoid |
| "Every model can be main" governance language | High (hidden) | ✗ Avoid |

Keep canonical assets **single-source**: the method/agent/skill body lives once; runtime-specific files
only describe *what auto-loads · what does not · allowed operations · handoff/sidecar invocation · hard
stop lines*.

## Scope vs steel-quench Wave 5

This document is the **rationale layer** (why sidecars, when, what value, what boundaries). `steel-quench/SKILL.md` Wave 5 (Multi-Team Adversarial Panel) is the **implementation layer** — the runnable team-formation + parallel-dispatch + cross-team-synthesis steps. They are not redundant: a skill cites this doc for *why* and *when*; Wave 5 (and any other caller) owns the *how*. If the how appears in two places, Wave 5 is canonical and this doc defers to it.

## The capability

**Any FH user can delegate tasks to other models as sidecars** from within a session. The host orchestrator is always the primary CLI + FH. The sidecar is invoked via `Bash` tool — no special integration required.

### Available sidecar paths (use whichever your environment allows)

| Sidecar | Invocation | Model access |
|---|---|---|
| **Gemini CLI** | `echo "prompt" \| gemini --skip-trust` or `gemini -p "prompt"` | Gemini family. ⚠️ **the direct `gemini` CLI is being sunset (vendor EOL 2026-06-18)** → its successor is the Antigravity router-shell (`agy`) or the Gemini API (Tier 2). `--skip-trust` is required outside a trusted directory (headless). A *pure-text* prompt needs no tool-permission flag. |
| **Antigravity CLI** (`agy`) | `echo "prompt" \| agy` or `agy -p "prompt" --model "<name>"` | **Router-shell** (route-to-model selector, same class as Copilot — *not* a harness): model-selectable across providers (e.g. Gemini 3.x · Claude Sonnet/Opus · GPT-OSS-120B). For cross-provider **diversity** pick a *non-Claude* model from a Claude host (Claude→Claude = no divergence — see §Boundaries). Agentic: `-p` pre-flights tool permission, so a headless tool-using run needs `--dangerously-skip-permissions` (or run under the host's approval mode); a pure-text run does not. |
| **Codex CLI** | `npx @openai/codex exec "prompt"` (or `codex exec --skip-git-repo-check -`) | GPT-4o / GPT-5.5 (non-interactive exec mode — true headless, no permission pre-flight) |
| **Copilot CLI** (`gh copilot`) | `gh copilot -- -p "prompt" --allow-all-tools` | Copilot model catalog — **subscription-dependent**: preview = claude-haiku-4.5 + gpt-5-mini; international/enterprise subscription = GPT-5.5, Claude Opus, etc. Verify: `gh copilot -- -p "list available models"`. Router-shell (agentic) — same permission-preflight note as `agy`. |

### Binary names churn — probe by capability, never pin a name

The Gemini-CLI→Antigravity migration (direct `gemini` EOL 2026-06-18) is the live proof: a Tier-1
entry pinned to the literal `gemini` binary goes stale on a fixed date. The resolution protocol below
therefore probes for *whichever route exists* (direct CLI · router-shell · API), and Gemini access
simply migrates `gemini` → (`agy` | API) without changing the methodology. **Router-shells (`agy`,
`gh copilot`) are a Tier-1 *class*, not a harness** (§Two shells) — they select+forward a model; FH
governs which/when.

---

## Sidecar Engine Resolution Protocol (Zero-Config default)

**Problem this solves**: skills across FH say *"Gemini sidecar if available"* / *"if external
CLIs available"* without a shared definition of how "available" is decided. This is the canonical
resolution recipe — every sidecar-invoking skill resolves engine availability through it, so a
user who configured nothing still gets intelligent multi-model use, and a plugin-only (Mode C)
user never hits a hard error.

**Core principle — discovery is automatic; invocation stays value-gated.** Probing the
environment is cheap (shell `command -v` + env-var check, near-zero cost), so it runs **by
default** on every sidecar-eligible step. *Actually invoking* a sidecar still passes the value
test in §When NOT to invoke — intelligent use, not indiscriminate fan-out. "Default multi-AI"
means FH auto-knows what is available and uses it when the task warrants it, never that every
task sprays calls to every model.

**Resolution order (Tier 1 → 2 → 3)** — bind the first tier that resolves:

```bash
# Tier 1 — subscription / logged-in CLI (zero marginal cost; preferred).
#   Probe by CAPABILITY, never pin a fixed binary name — names churn: the direct `gemini`
#   CLI is sunset 2026-06-18, its Tier-1 successor is the `agy` (Antigravity) router-shell.
#   Direct provider CLIs + router-shells (agy/gh-copilot) are all Tier-1 routes.
for cli in gemini agy codex aider; do command -v "$cli" >/dev/null 2>&1 && echo "tier1:$cli"; done
command -v gh >/dev/null 2>&1 && gh copilot --help >/dev/null 2>&1 && echo "tier1:gh-copilot"
#   (codex may be `npx @openai/codex` when not on PATH; agy/gh-copilot are router-shells —
#    model-selectable, so pick a non-Claude model from a Claude host for genuine diversity)

# Tier 2 — native API key (pay-per-use; only if no Tier-1 CLI)
for k in GEMINI_API_KEY OPENAI_API_KEY ANTHROPIC_API_KEY; do
  [ -n "${!k:-}" ] && echo "tier2:$k"
done

# Tier 1.5 — OAuth-proxy ("anti-api" class): a local OpenAI-compatible server that fronts a
#   logged-in CLI/OAuth session, letting any OpenAI-spec client use that subscription as a
#   backend. Verified instance: `hermes proxy start` ("forwards OpenAI-compatible requests to
#   an OAuth-authenticated provider; external apps point at the proxy with any bearer token" —
#   upstreams: Nous Portal, xAI Grok). Sits between Tier 1 (the session itself) and Tier 2
#   (a raw key): zero marginal cost like Tier 1, API-shaped like Tier 2.
#   Probe detects the capability only — login state is shown by `hermes proxy status` and a
#   non-logged-in upstream reads "not logged in" (substring-greps for "logged in" false-match it).
command -v hermes >/dev/null 2>&1 && echo "tier1.5:hermes-proxy (candidate — verify an upstream is logged in via: hermes proxy status)"
#   Two cautions, always surfaced when this rung binds: (a) wrapping an OAuth session into an
#   API surface may sit outside the provider's ToS — operator's call, per provider; (b) from
#   2026-06-15, proxied **Claude-subscription** usage = third-party-agent class = the metered
#   hard-capped credit pool, not the subscription pool — prefer non-Claude upstreams here.

# Tier 3 — guaranteed fallback: Claude Code's own isolated sub-agent (always available)
#   No external resource → orchestrator spawns an Agent(subagent_type=…) / prompt-chunking.
#   This tier never fails, so the chain has no hard-error state. Same-provider, so it serves
#   model-access/parallelism, NOT cross-provider diversity (see §Boundaries).
echo "tier3:claude-subagent"   # used when Tiers 1–2 resolve nothing
```

**Verdict mapping**:
- Tier 1/2 resolved **and cross-provider** → genuine diversity wave (primary use case).
- Only Tier 3 available → no diversity; proceed with the Claude sub-agent (no error, reduced value).
- The resolution result is **advisory** to the caller's own value test — a resolved engine is
  *usable*, not *mandatory*.

**Relation to the §Implementation-Patterns fallback chain**: that chain degrades *when a chosen
path is blocked* (network / quota); this protocol decides *what exists in the first place*. Same
fan-out, two moments — resolve first (this), degrade-on-failure second (that). Do not duplicate
the tier list into callers; cite this section.

**Skills that resolve through this protocol** (wired 2026-06-09): `goal-quench` (Step D sidecar
routing), `steel-quench` (Wave 5 / runtime-adapter fallback), `harvest-loop` (Step 3.5-X
cross-validation). Other sidecar-using skills (`sim-conductor`, `pipeline-conductor`,
`agent-composer`) inherit by reference — when they say "if available", availability = this
protocol's verdict.

### Video-extraction capability-gated router (added 2026-06-15)

Video understanding is a **task-specific specialization** of the resolution ladder above — the
general "which engine" question, narrowed to "which path can actually *watch* this video". Two axes
decide the route: **capability** (what's installed) and **length** (frame-extraction tools go sparse
past ~10 min).

| Condition (probe in order) | Route | Why |
|---|---|---|
| `command -v gemini` **or** `agy` (or `GEMINI_API_KEY`) | **Gemini / agy sidecar** — URL-native ingest, **no frame cap**, handles long/dense video | Native multimodal; the operator-verified YouTube-URL path (`gemini --skip-trust -p "<URL>"`). ⚠ direct `gemini` EOL 2026-06-18 → `agy` successor / Gemini API (same Tier-floor migration as the text ladder) |
| Claude-only host (no Gemini/agy), `ffmpeg`+`yt-dlp` present | **claude-video `/watch`** — ffmpeg frames (≤2fps/100, **best ≤10 min**) → Claude's own vision Read; captions via yt-dlp/Whisper | No separate multimodal runtime, **no Gemini-EOL exposure** — Claude watches natively. **3rd-party executable — review before install** (`/plugin marketplace add bradautomates/claude-video`; brew installs + Whisper egress) |
| Cloud / text-only sandbox (host blocks video) | **remote transcript MCP** | URL hosts 403 in cloud VMs; transcript-only is the floor (the daily-routine sandbox case) |

**2nd axis — length**: short/medium → claude-video is fine and keeps everything in-Claude; long or
visually-dense → prefer Gemini/agy (claude-video's frame cap goes sparse past ~10 min).

**Governance invariant (do not drop)**: whichever route runs, the **governor never trusts a
multimodal "comprehensive read"** as a terminal verdict — a video claim (timestamped summary) is a
*claim*, cross-checked on a second surface (e.g. Codex clicking the timestamp, or a caption grep)
before it anchors a decision (`cross_runtime_routing` debate-loop; judge-robustness "judged →
mechanical"). claude-video is the *executor* FH lacked; FH's cross-check discipline is the
*governance* claude-video has no equivalent for — compose, don't trust. (Sister-asset intake
recorded in the private companion store's sister-asset signals.)

### Tier-floor resolution — the model dimension (added 2026-06-10)

The ladder above resolves **which engine**; this subsection resolves **which model tier within it**.
Same shape: an asset declares a requirement, the environment resolves it, and resolution never
hard-fails.

**Asset-side floor**: an asset may declare a minimum model tier via its existing
`model:`/`complexity_routing` frontmatter — that declaration is a **floor, not a pin**. Floors are
measured-or-justified, never asserted (same discipline as check-class declaration): e.g.
`quench-challenger` floors at opus (adversarial increment-finding is the product — the
depth-sensitive class), while Wave-T and `harness-doctor` floor at sonnet (measured: T-3 blind
3/3 on both tiers, 2026-06-10), and mechanical scripts have no floor at all (measured tier-flat).

**Composition order — engine first, floor second (does NOT reorder the engine ladder)**: the Tier 1→2→3
Engine Resolution above keeps full authority over *which engine* runs — including its **perspective-
diversity-first** doctrine (a cross-provider Tier-1 CLI beats a same-provider Claude sub-agent whenever
diversity is the point, e.g. Wave 5). Tier-floor resolution then applies **within the chosen engine**:
it asks "does this engine reach the asset's floor?", never "should we switch to a Claude sub-agent
because it has opus?". A floor is satisfied by the chosen engine's **strongest floor-equivalent tier**
(e.g. an external CLI's top model for an opus-floored asset) — floors measure strength, not provider.

**Floor resolution within the chosen engine**:
- **F1 — engine reaches the floor**: dispatch at the floor tier (native CC `Agent(model=…)` when the
  chosen engine is the Claude sub-agent; the CLI/API's floor-equivalent tier when it is external).
  The session's default model stays untouched — FH **never switches the user's session model**;
  floors apply only to FH's own dispatches.
- **F2 — engine tops out below the floor** (e.g., a Sonnet-only API-routed environment, or an external
  CLI whose available tiers sit below floor-equivalent): **run anyway at the engine's best tier +
  mandatory below-floor flag.** Never hard-fail — the analog of Tier 3's no-hard-error guarantee.
  The output header carries e.g. `challenger: sonnet (below-floor; floor=opus)`, and a **judged verdict
  produced below floor is auto-tagged a re-quench candidate** for when a floor-tier becomes available —
  degraded delivery is explicit, never silent coverage. Do **not** abandon a diversity-chosen engine
  merely because it is below floor — a below-floor cross-provider pass still buys the diversity the
  step exists for; flag it and proceed.

**Floor governance** (from the design's own first quench — challenger findings, both tiers):
- **Cross-provider equivalence is opt-in with evidence, never assumed**: an external engine's tier
  counts as **below-floor by default** until a measured equivalence entry exists (recorded in the floor
  table above with its evidence citation, same discipline as the floor declarations themselves). The
  backend×tier ladder measurement is exactly what produces these entries — name-matching or vibes never
  satisfies a floor.
- **Below-floor judged verdicts are provisional, and the queue has a consumer**: a judged-class verdict
  produced below floor does **not** count as gate-PASS evidence for promotion/merge until either a
  floor-tier re-run or an explicit operator acceptance. The **weekly audit** (run at the highest
  available tier per the cadence-compensation policy) is the standing consumer: it scans recent quench
  records for `below-floor` markers and re-runs or explicitly writes them off — flags terminate, they
  do not decorate. For the hub's own 4-axis gate this is now **mechanically enforced**: the Axes 2+3
  pass marker must carry structured floor fields (engine / producing model / floor-status) and the
  pre-commit hook blocks a below-floor marker that lacks an explicit operator ack — self-flagging in
  prose proved salience-fragile at any tier (the adversarial-floor-enforcement signal's A/B finding).
- **`floor: hard` for depth-critical judged roles** (quench-challenger, apex-review): for these, the
  floor outranks diversity — prefer a floor-meeting engine (incl. the native Tier-3 sub-agent at floor)
  over a below-floor diversity engine. Only when *no* engine anywhere reaches the floor does F2 apply
  (never-hard-fail preserved). When a below-floor engine is deliberately chosen over an available
  floor-meeting one (diversity genuinely the point), record a one-line `diversity_rationale`
  (the existing `sidecar_rationale` convention) — no rationale, floor-meeting engine wins the tie.
- **Tier-flat / floor claims age**: no-floor and floor declarations cite their basis and are
  re-validated opportunistically when the asset next changes (the standing backfill rule) — a floor
  without a cited basis is treated as unjustified by reviewers.

**Human override is inviolable — and a pin is not a cap**: if the operator pins a session default
(stronger or weaker), FH follows it for **session turns**; floors govern FH's **own sub-agent
dispatches** and a session pin does not lower them — that separation *is* the Sonnet-main +
Opus-dispatch doctrine (pinned-sonnet sessions still dispatch floored agents at opus). Canonical
axiom + defect-class + prescription ladder: `sonnet_floor_doctrine.md` (2026-07-10) — this section
remains the operating mechanics (F1/F2, floor governance) under that axiom; SKILL.md hard `model:`
pins were retired the same day (session-inherit + dispatch recommendation), agent-side dispatch
floors unchanged.

**Field depth-escalation (the upward complement)**: floors push *dispatches* up automatically, but
main-thread depth on a field session has no floor — so the templates bundle carries a Field
Depth-Escalation Notice (templates CLAUDE.md): on strain signals (repeated correction loops,
non-decomposable design reasoning, user stuck), the session AI proposes the cheaper rung first —
an opus sidecar dispatch for packageable units — and a session pin only for inherently main-thread
depth. Advisory, once per session, never auto-switches; the symmetric counterpart of the hub's
Mode D Model Notice, placed field-side so the proposal does not depend on mid-session rule recall. If the operator
explicitly caps dispatches too ("sonnet only, everywhere"), that is an environment limit: F2 applies,
flags and all. Pinning a stronger-than-opus default strengthens harness *self-development* in
particular (measured: the tier cliff sits on design-increment work) — mostly relevant to harness
developers (Mode D), not field operation.

---

## Empirical validation

### Experiment 1 — Sidecar invocation (2026-05-31)

1. **Corporate network** — Copilot CLI sidecar (CC standalone = Sonnet-only on restricted network). Copilot CLI's model catalog provided access to Codex, Gemini, and Claude Opus.

2. **Direct Gemini CLI sidecar** — `echo "prompt" | gemini` inside a Claude Code session. Adversarial review of `pipeline-conductor` Done When: 3 structural gaps (Amnesia Loophole, Activity vs Integrity gap, Escalation Paradox).

3. **Direct Codex CLI sidecar** — `npx @openai/codex exec "prompt"`. Same target: 3 non-overlapping issues (scope definition gap, skip justification absent, report persistence).

4. **Gemini native skill load** — `gemini skills install <fh-skill-path> --consent`. All 32 FH skills loaded and listed as Enabled. FH SKILL.md format is natively compatible with Gemini CLI.

---

### Experiment 2 — 3-round orchestrator-swap (2026-05-31)

**Setup**: Same FH skill (`goal-quench/SKILL.md`, post-patch) reviewed under 3 orchestrator configurations. Each round: orchestrator runs Wave 1 (3 primary findings), sidecar adds 3 non-overlapping findings, orchestrator synthesizes final verdict.

| Round | Orchestrator | Sidecar | Verdict | Orchestrator focus |
|---|---|---|---|---|
| 1 (prior) | Claude Opus | Gemini + Codex | 6 issues → patched | State machine + hook reliability |
| 2 | Gemini | Codex | FAIL — 4A + 2H | State machine loop + audit methodology |
| 3 | Codex | Gemini | FAIL — 4A + 2B | Implementation parsing + dependency contract |

**Convergence (appeared in every round)**:
- Freshness guard is pseudocode — no actual timestamp comparison
- `.pending` surviving BLOCKED creates an infinite-loop deadlock
- `git diff HEAD` yields false CLEAN if `/goal` makes interim commits

**Divergence (orchestrator-specific)**:
- Gemini orchestrator: state-machine completeness, audit methodology validity, phantom telemetry
- Codex orchestrator: `grep/cut` parsing fragility, `token-budget-gate` invocation contract absent

**Cross-wave delta finding**: 3 common issues + 3 orchestrator-specific = 6 total per round. No round found all 6 on its own. Single-model review (Claude alone, Round 1 on original) found a different 3 — correct but incomplete. Multi-model synthesis identified 12 distinct issues across 3 rounds, with 3 confirmed-critical by convergence.

**Conclusion**: Process divergence is the mechanism by which sidecar diversity compounds into better convergence. The harness (FH skill format + consistent evaluation protocol) is the activation condition — without it, the three results are structurally incomparable and the delta cannot be synthesized.

```bash
# Minimal sidecar call pattern (validated)
echo "You are an adversarial reviewer. Identify the 3 most critical gaps in this SKILL.md Done When: $(tail -30 path/to/SKILL.md)" | gemini
```

This is **not a prototype** — it is a confirmed, runnable pattern.

---

## When to distribute

Three use cases, ordered by primacy under a **full-subscription environment** (Claude Max + Gemini Pro/Advanced + GPT-4o Plus — all strong models available simultaneously):

| Use case | Primacy | Sidecar role | Example |
|---|---|---|---|
| **Perspective diversity** | **Primary** — valid regardless of model tier | Each model's process angle produces non-overlapping findings; cross-wave delta improves convergence quality | steel-quench Wave 5: Claude primary → Gemini + Codex sidecars → synthesize delta |
| **Model-access fallback** | Secondary — situational | Reach a stronger model when the CC host is downgraded on a restricted network | CC standalone = Sonnet-only on a restricted network → Copilot sidecar reaches Opus |
| **Token economy** | Tertiary — relevant when models differ in cost tier | Offload subsidiary tasks to a lighter or separately-billed model | Delegate claim extraction to Gemini Flash while Opus handles synthesis |

**Full-subscription case (validated 2026-05-31)**: When all three providers are at premium tier (Claude Max / Gemini Pro / GPT-4o Plus), token economy is not the primary motivation. The orchestrator-swap experiment showed that even when all models are strong, **process divergence still produces non-overlapping findings** — Gemini focused on state-machine completeness, Codex on implementation parsing fragility. Neither found what the other found. This means perspective diversity is an intrinsic property of model identity, not a function of capability tier.

**Implication**: In a full-subscription environment, sidecar invocation should default to the strongest available sidecar model, not a lightweight one. The goal is maximum perspective divergence, not cost savings.

### Surface-Specialized Orchestration (operator observation, 2026-06-13)

Sidecar value has evolved from generic "model diversity" to **surface-specialized orchestration**. Routing is determined not by model capability alone, but by which runtime natively governs the **task surface**. Each runtime excels on its own surface, but FH fundamentally distrusts their self-reports (fluency) and binds them via gate/review.

Observed surface split across the Claude Code / Gemini / Codex family:

| Runtime | Surface & Role | FH routing criteria |
|---|---|---|
| **Claude Code / Opus** | **FH governor**. Public/private hygiene, hook/gate, claim-scope review, repo governance | The task depends on terminal/repository governance, `.claude/agents/` dispatch, or FH-native automation. |
| **Codex** | **Web-flow pilot**. Direct click, page navigation, login state, guest onboarding, browser UI iteration | The task depends on live web-flow automation (requires Codex app/runtime with Browser connectors). |
| **Gemini / Antigravity** | **Multimodal ingestion**. Video, screen recording, image-based UI/UX observation, time-flow data | The task surface is visual/temporal (video/recording/image). Among the three runtimes, **only Gemini natively ingests video/multimodal input** (CC and Codex do not) — an established capability boundary confirmed across prior experiments, not a self-report. The routing choice for visual/temporal surfaces. (FH states the capability boundary; specific performance benchmarks are a separate measurement.) |

**FH Governance Meta-Rule**: The orchestrating harness synthesizes these surfaces but **never trusts a runtime's self-report**. A live pilot's "success" or a multimodal ingestion's "comprehensive read" is always cross-checked by FH gates. 


This is **affordance routing, not provider ranking**. `codex exec` remains a headless text/CLI sidecar;
the web-automation value appears when the Codex session has a Browser/Chrome control surface. A Claude
Code host should therefore treat Codex as the preferred handoff for web-flow probes only after probing
that connector capability, and should fall back to the normal text sidecar role when it is absent.

**FH-local workspace note**: some operator setups load the public forge-harness mirror and a private
companion store (the `*-be` pattern) as sibling repositories inside one working folder to form a personal
FH environment. Capability routing should be resolved at the workspace level in that setup: preserve which
repository owns the artifact or change, but choose the runtime by the surface being tested (public FH docs
and governance in the mirror; backend/runtime/experiment work in the companion store; live web-flow probes
through a Browser/Chrome-capable Codex session when available).

> **v2 paper candidate**: Does model tier affect the quality of perspective divergence, or is the divergence pattern stable across tiers? The orchestrator-swap experiment used entry/mid-tier sidecars — replicating with all-premium models (Gemini Pro, GPT-4o, Claude Opus) would test whether diversity compounds further or plateaus. This is a natural follow-on experiment for the v2 empirical section.

### Debate Circulation Loop + governor source-verification (methodology, promoted 2026-06-14)

Surface-specialized routing answers *which runtime does the work*. The **Debate Circulation Loop**
answers *how to trust the result when several runtimes disagree* — it is the verification methodology
that rides on top of surface routing, and the model-level expression of the judge-robustness principle
(a judged verdict reached only by a judge is foolable; bind it to a mechanical anchor).

**The loop** — used when a question genuinely spans multiple runtimes (compatibility calls,
cross-surface mining, contested claims):

1. **Relay** the same question to each runtime (CC governor + the surface-appropriate sidecars).
2. **Mutual critique** — each runtime critiques the others' output. The key asymmetry: *a runtime's
   own blind spot is invisible to itself but visible to a peer.* Divergence is the signal, not noise.
3. **Governor closes with source** — CC/Opus does not average the opinions (a debate is *also* judged,
   so a vote is still judge-only). It **closes the loop against a source of ground truth**: re-reads
   the cited file, runs the command, checks the live surface. Only the source-verified residue is kept.
4. **Promote refined, quarantine raw** — only the governor-closed conclusion is eligible for public
   promotion; raw runtime output stays in the private companion store first (drift guard).

**Standing clause — distrust the self-report, the gate is the backstop.** A runtime's claim about its
*own* strength is the least reliable thing it emits. Origin: a sidecar self-reported "strong
public/private separation" and was then disproven by an actual private-store leak the *governor* caught
— after which the sidecar accepted the catch and self-modeled the blind spot. Fluency is not accuracy;
this is why every runtime output terminates at an FH gate/review, never at the runtime's own verdict.

**Cross-surface verification (the strongest form)** — make the *verifier* live on a different surface
than the *claimer*, so the check is mechanical rather than a second opinion:

| Role | Runtime | Why |
|---|---|---|
| Claim producer | Gemini (multimodal) | reads the video/image, emits a timestamped claim |
| Claim verifier | Codex (web-flow) | independently clicks that timestamp in a browser → ground-truth compare |
| Governor | CC / Opus | records, adjudicates, closes against source |

A timestamp *read by a model* is judged; the same timestamp *clicked on a different surface* is a
mechanical anchor. Verifier-≠-claimer is an independent verification path, not self-verification — the
multi-runtime realization of "judged → mechanical."

**When to run it (cost guard).** The loop is expensive (N runtime calls + governor close). Reserve it
for genuine multi-runtime decisions; trivial questions take a single runtime + a gate. Tier note:
trust the loop's *strategic* reasoning only from frontier-top sidecars (Codex/Gemini Pro high-reasoning
tiers); a below-floor model (e.g. a Flash backend) is a producer, not a trusted critic — its critique
is itself subject to §Floor governance.

> Live instance (this doc's own promotion, 2026-06-14): mining two external sources for FH-reinforcement
> ran *as* the loop — Gemini ingested a web book the governor's fetcher was 403-blocked from, Codex ran
> the adversarial governance critique of `oh-my-claudecode` import candidates, and CC closed both against
> FH's own asset inventory (most candidates resolved to ALREADY-HAVE, a healthy sister-asset result).

---

## Mechanism (how it works)

```
FH / Claude Code (orchestrator)
    │
    │  Bash tool
    ▼
Sidecar process
  ├── Gemini CLI        → Gemini model
  ├── OpenAI/Codex CLI  → GPT-4o / Codex model
  └── Copilot CLI       → model catalog (Codex / Gemini / Claude Opus)
    │
    └── stdout → back to Claude Code session → integrated by the skill
```

- **Host is always single**: Claude Code session owns the conversation, memory, and file state.
- **Sidecar is stateless**: each call is a one-shot prompt → response. No persistent sidecar context.
- **Integration is inline**: the skill reads stdout and folds it into its own output or verdict.
- **Not an agent dispatch**: sidecar calls bypass `.claude/agents/` entirely. No AGENTS.md entry needed.

---

## Integration with FH skills

Sidecar calls are coordinated inline by the calling skill, not by a central dispatcher. Recommended pattern:

```bash
# Inside a skill Step (AI executes this via Bash tool):
SIDECAR_RESULT=$(echo "${PROMPT}" | gemini 2>/dev/null)
# Then fold $SIDECAR_RESULT into the skill's output or verdict.
```

Suggested integration points:
- `steel-quench` — 2nd-challenger pass after Wave 1 (primary Claude challenger)
- `pipeline-conductor` — cross-check a verdict with a sidecar before elevating to CONDITIONAL_PASS
- `sim-conductor` — persona simulation from a different model's perspective
- `phantom-quench` — Gemini reads source files as a secondary back-tracer

---

## Boundaries

- The harness (FH) is the specialization layer. Do not treat the sidecar as a second harness.
- Each sidecar call is independent (no shared context with main session by default).
- Sidecar model output is **untrusted input** — the orchestrating skill validates before accepting.
- Cost: sidecar API calls are billed separately (Gemini API key, OpenAI key, Copilot subscription).
- **Provider identity gates perspective diversity** — the primary use case (diversity) only holds when the sidecar is a *different provider*. Reaching Claude Opus through Copilot CLI from a Claude host is **Claude → Claude**: it serves model-access fallback (secondary use case) but produces **no genuine process divergence** — same pre-training distribution, same blind spots. Do not count a same-provider sidecar as a diversity wave. Diversity requires a cross-provider sidecar (e.g. Claude host → Gemini/Codex).

---

## Implementation Patterns

**Context**: §1–8 establish *why* sidecar distribution works and its validated patterns. This section adds *executable* implementation guidance reverse-harvested from a sister-harness `sidecar-orchestrator` (2026-06-01), generalized for any environment. These are **reference** patterns for any caller — they do **not** supersede §Scope vs steel-quench Wave 5: for the steel-quench multi-team case specifically, Wave 5 remains the canonical implementation.

> **CLI-syntax caveat**: Exact sidecar invocation flags differ by CLI and version. The forms below use FH's validated baselines (`gh copilot suggest`, `echo … | gemini`, `npx @openai/codex exec` — see §The capability). Flags such as `--model` are catalog/version-dependent — verify with the CLI's own `--help` before relying on them.

### Three-tier fallback chain

When the primary sidecar path is blocked (network restrictions, API outages, rate limits), degrade to secondary/tertiary options so execution continues rather than failing silently.

| Priority | Sidecar | Access | Trigger condition |
|---|---|---|---|
| **1 (Primary)** | Copilot CLI (`gh copilot`) | Copilot model catalog | Default — widest catalog |
| **2 (Fallback)** | Corporate AI endpoint | Internal models (if any) | Priority 1 unreachable (503, timeout, quota) |
| **3 (Last resort)** | Direct CLI (Gemini / Codex) | Public API key | Priorities 1–2 unreachable + external network OK |

**Empirical grounding**: some corporate networks block direct LLM-provider APIs but allow GitHub CLI routing → `gh copilot` was the only path to premium models there. Without a fallback tier the workflow blocks entirely.

### Executable patterns

**Pattern 1 — Single-model sidecar**
```bash
SIDECAR_RESULT=$(gh copilot suggest "Adversarial reviewer: 3 most critical gaps in this Done When: $(tail -30 path/to/SKILL.md)" 2>&1)
EXIT_CODE=$?
[[ $EXIT_CODE -ne 0 ]] && echo "⚠️ sidecar failed (exit $EXIT_CODE): $SIDECAR_RESULT"   # escalate or fail gracefully
```
Model selection, if the CLI exposes it, is catalog-dependent — check `gh copilot --help`.

**Pattern 2 — Cross-provider parallel ensemble** (real diversity comes from *distinct providers*, not one router)
```bash
echo "$PROMPT" | gemini          > raw_gemini.txt  2>&1 &
npx @openai/codex exec "$PROMPT"  > raw_codex.txt   2>&1 &
gh copilot suggest "$PROMPT"      > raw_copilot.txt 2>&1 &
wait                                                          # block until all sidecars finish
# orchestrator synthesizes cross-wave delta from raw_*.txt
```
> Routing the *same* provider twice (e.g. Claude → Claude via Copilot) is model-access fallback, **not a diversity wave** — same pre-training, same blind spots (see §Boundaries). For divergence, use genuinely different providers.

**Orchestrator-swap variant** (FH Experiment 2): rotate orchestrator identity across waves — host runs Wave 1, a different-provider sidecar challenges Wave 1, a third challenges Wave 2, then the host synthesizes all three.

**Pattern 3 — Corporate endpoint fallback (Priority 2)**
```bash
CORPORATE_RESULT=$(curl -s -X POST "${CORPORATE_AI_ENDPOINT}" \
  -H "Authorization: Bearer ${CORPORATE_AI_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"${CORPORATE_MODEL}\",\"prompt\":\"${PROMPT}\"}" | jq -r .response)
[[ -z "$CORPORATE_RESULT" ]] && echo "❌ corporate endpoint failed — check token in .env"   # escalate to Priority 3
```
Configure `CORPORATE_AI_ENDPOINT` / `CORPORATE_MODEL` / `CORPORATE_AI_TOKEN` in `.env` (git-excluded).

**Pattern 4 — Direct Gemini/Codex CLI (Priority 3)**
```bash
echo "${PROMPT}" | gemini         > raw_gemini.txt
npx @openai/codex exec "${PROMPT}" > raw_codex.txt
```
Requires the respective CLI installed and authenticated.

### Error-handling checklist

```bash
RESULT=$(sidecar_command 2>&1); EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "⚠️ sidecar failed (exit $EXIT_CODE)"
  if   [[ "$RESULT" =~ (unknown|invalid)\ model ]];      then echo "   → model name error — check catalog: gh copilot --help"
  elif [[ "$RESULT" =~ (503|timeout) ]];                 then echo "   → network/API outage — escalate to Priority 2"
  elif [[ "$RESULT" =~ (rate\ limit|quota\ exceeded) ]]; then echo "   → rate limited — retry after delay or use Priority 3"
  else echo "   → unknown failure: $RESULT"; fi
fi
```
**Critical**: never assume sidecar success — always capture `$EXIT_CODE` and parse `stderr` for failure signals.

### Three-layer persistence protocol

Sidecar results are high-risk for **compression aging** (AgingBench, arXiv:2605.26302) — single-session outputs that vanish if not structurally anchored. Persist in 3 independent layers so at least one survives compression/refactoring:

1. **Full result file** — `tracks/_meta/sidecar_{target}_{YYYY_MM_DD}.md` with frontmatter (`type: sidecar-review`, `models`, `target`, `priority`) + tiered findings (M/S/R).
2. **Memory reference entry** — one applicability-phrased line in the durable memory store (`~/.claude/.../memory/`) so next session recalls it on intent match (`memory_intent_recall.md`).
3. **CATALOG search entry** — 3-line summary + Decision/Open, pointing at the Layer-1 file.

Missing any layer = compression risk. (Path conventions adapt per project — see Generalization below.)

### When NOT to invoke (simplification guard)

**Skip the sidecar** for: single-file review (host sufficient), simple design decisions (no architectural complexity), repetitive non-judgment tasks (shell faster than an AI sidecar). **Invoke** only when 2+ hold: complex/multi-skill architecture · external knowledge needed (arXiv, frontier, cross-domain) · genuine multi-model perspective diversity required.

> For *when to distribute by value tier* (perspective diversity / model-access / token economy), the canonical guidance is §When to distribute above — not repeated here.

### Generalization guidelines (sister-harness → FH)

1. **Corporate endpoint → generic fallback**: a sister-harness's internal gateway → user-configured `.env` endpoint.
2. **Approval mode → consent gate**: prompt the user before a sidecar sends internal code/patterns to an external API.
3. **Persistence paths → project structure**: the sister-harness's `tracks/_meta/`·`memory/`·`CATALOG.md` → adapt to the host project's equivalents.
4. **Model names → CLI-agnostic**: replace pinned names (`claude-opus-4.x`, `gpt-5.x`) with `{model-name}` placeholders + "check CLI help for catalog".

---

## References

- `README.md §Architecture — 2-layer design` — sidecar note in Automation layer section
- `knowledge/shared/harness-core/agents_md_runtime_details.md §Sidecar-routing-and-waiting` — sidecar note distinguishing adapter invocation from agent dispatch
- FH paper (Zenodo DOI: 10.5281/zenodo.20397566, arXiv: submit/7657304) — harness-as-durable-layer thesis
- A sister-harness `sidecar-orchestrator` SKILL.md (2026-06-01) — gh copilot + corporate endpoint + 3-tier fallback + 3-layer persistence
- arXiv:2605.26302 AgingBench — compression aging defense rationale
- `hybrid_orchestration_architecture_roadmap.md` — proposed (not-yet-implemented) architecture direction that would generalize this sidecar strategy into a hybrid orchestration engine
- **Sister asset** — `ponytail` (github DietrichGebert/ponytail@dedc97c; "lazy senior dev" minimal-code field skill, 14-host portable `AGENTS.md` + thin adapters) converges on the portable-`AGENTS.md`-as-entrypoint + thin-adapter distribution this doc codifies (portable-AGENTS.md is itself a recognized 2026 standard — convergence, not provably independent derivation). Cross-audit: `tracks/_audit/session_2026_06_24_ponytail-lazy-senior-dev.md`
