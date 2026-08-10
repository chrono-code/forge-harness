---
name: context-doctor
description: Reduces token waste in Claude Code sessions across two axes — context footprint (auto-generates .claudeignore, guides over-read files and /clear timing) and command output (routes to a command-output proxy/hook such as rtk to trim verbose CLI stdout). In hub environments, regularly audits bloated CLAUDE.md/MEMORY.md/memory/*.md files and proposes compression. Usable standalone without a hub clone.
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - cold_start
    - cross_project
---

# context-doctor — Token Efficiency Diagnosis + Automatic Prescription

Diagnoses the main causes of session token waste and prescribes immediate remedies:
1. No `.claudeignore` → unnecessary files loaded wholesale into context
2. Repeated full reads of large files → paying the same cost N times
3. Not using `/clear` after direction changes → continuing work with accumulated noise
4. Verbose CLI output → every `git`/`ls`/build/test call floods context with stdout (a *different* layer from 1–3 — see §Command-Output Reduction)

**Two reduction axes — keep them distinct.** Causes 1–3 are the **context-footprint** axis (what gets read *into* context: files, history). Cause 4 is the **command-output** axis (tokens produced *by* the tools you run). `.claudeignore` cannot touch command output, and a command-output proxy cannot touch file reads — they are complementary, not substitutes. (Step 3.5 below adds an optional **third**, orthogonal lever — provider-side cache billing — distinct from both.)

**Standalone install** — this skill works normally with plugin install only, without cloning the full meta-harness.

**Built-in `/doctor` first (sister anchor, 2026-07-25)**: since the Claude 5 generation, the official
`/doctor` command claims skill/CLAUDE.md rightsizing ("The new rules of context engineering for Claude 5
generation models" — https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models).
Run the built-in first when available — its scope is skills + CLAUDE.md rightsizing only. This skill's
increment over it = `.claudeignore` diagnosis/generation (Step 1), `/clear` timing guidance,
command-output proxying (§Command-Output Reduction), hub-wide memory/CLAUDE.md audits, and the
measurement discipline (resident footprint is measured only via a fresh top-level `/context`, and any
diet is followed by a `prompt-regression` probe — the blog's own "no measurable loss" claim ships no
method, so treat that number as a vendor claim). Triage record:
`tracks/_audit/session_2026_07_25_claude5-context-rules-sister.md`.

## Execution Steps

### Step 1. `.claudeignore` Diagnosis + Generation

Check whether `.claudeignore` exists in the project root (bash in §Step-Bash).

**If absent**: Scan project structure and auto-generate.

**If already present**: Keep existing content + suggest additional patterns only (no overwrite). Check for sentinel comment (`# context-doctor:`) and add to first line if absent.

Generation criteria — by project type:

| Detected type | Additional patterns |
|---|---|
| Node.js (`package.json`) | `node_modules/` · `dist/` · `build/` · `.next/` · `coverage/` |
| Python (`pyproject.toml` / `setup.py`) | `__pycache__/` · `.venv/` · `*.egg-info/` · `dist/` · `.pytest_cache/` |
| Java (`pom.xml` / `build.gradle`) | `target/` · `build/` · `.gradle/` |
| Common (always include) | `.git/` · `*.log` · `*.lock` · `*.min.js` · `*.min.css` |

Present preview to user after generation → save after confirmation.

Automatically add sentinel comment to first line when generating/updating:
```
# context-doctor: configured YYYY-MM-DD
```
→ Suppresses auto-invocation in subsequent sessions.

> **Detail**: See `SKILL_detail.md §Step-Bash` — detection bash for Steps 1/2/4/5, large-file warning format, audit report format — read when executing any step's commands.

### Step 2. Large File Detection + Split Strategy Guidance

Detect files exceeding 500 lines (top 10 — bash in §Step-Bash) and output the split-read guidance per file (offset + limit, section by section).

**Repeated full-read pattern** (burst pattern) detection criteria (behavioral):
- 3+ files over 500 lines exist and `.claudeignore` was absent
- User mentions "read it all at once" / "re-read the whole thing every time"

When burst pattern is detected → **trigger harvest-loop integration in Step 4**.

### Step 3. `/clear` + Model Switching Timing Guide

Check session state with the user, then prescribe according to context:

**Wrap-then-Compact** (when approaching context limit — CC subscription only):

When context is near the limit and you want to *preserve state* rather than reset:
1. Ask Claude: `"wrap up — completed items, modified files, pending tasks"`
2. Claude writes a structured summary → that summary anchors the `/compact` output
3. Run `/compact` — the wrap becomes the cold-start primer for next session

> This is superior to blind `/compact` because you control what's preserved. Bedrock/API has no meter warning — CC subscription only.

→ Full pattern + table: `CHEATSHEET.md §10 Lever 6`

**`/clear` recommended situations** (reset, not preserve):
```
□ Work direction has changed significantly (exploration → implementation, bug fix → refactor, etc.)
□ Switching to a different track/project
□ Error debugging has gone long and noise has accumulated
□ Previous attempts are unrelated to current work
□ Context has grown large (context rot — measurable quality degradation as input length grows,
  well before the window fills; threshold varies by model/task. Chroma 2025 context-rot research)
```

→ Recommend immediate `/clear` and restart in fresh context.

**Model switching criteria**:

| Current task | Recommended | Command |
|---|---|---|
| Complex design decisions · architecture review | Opus — dispatch-first: package into an opus/sidecar agent dispatch (consent-gated); session pin secondary | dispatch · or `/model opus` |
| Code writing · file editing · refactoring | Sonnet (default) | — |
| Simple file lookup · short Q&A | Haiku | `/model haiku` |

> Models are tools for allocating the right expertise to complexity. Opus for simple tasks = wasted expertise; Haiku for design decisions = insufficient expertise. Switch models when task nature changes.

### Step 3.5. Cache-Boundary Audit (prompt caching, optional third lever)

Distinct from both axes above: Steps 1–3 reduce what occupies the context *window*; this
reduces what the provider re-bills as **fresh input tokens** on each turn by preserving
prompt-cache hits. **Optional** — run it when a metered/quota-limited backend makes cache
cost the binding constraint (same gating logic as §Command-Output Reduction: diagnose and
recommend, do not chase this when tokens are merely plentiful).

**Audit checklist**:
- Is the system prompt / CLAUDE.md content **stable byte-for-byte** across turns in a
  session? Any turn-to-turn diff in the fixed prefix invalidates the cache for that prefix —
  which is in tension with Step 5's CLAUDE.md-compression prescription: compress at session
  boundaries (before a fresh cache is built), never mid-session (which would invalidate one
  already warm).
- Is session-specific / dynamic content (task state, recent results) placed at the
  **end of the user message**, not interleaved into the system prompt or early context?

**Reported, UNCALIBRATED by FH** (2026-07-27 frontier digest, issue #102): input:output token
ratio **> 10:1** favors cache/context engineering over model-level optimization; **> 50:1**,
prefix caching dominates; cache-boundary control reportedly raised hit rate ~7%→84% in one
production case (arXiv:2603.09619 *Context Engineering: From Prompts to Corporate Multi-Agent
Architecture* · appscale.blog).

**What is and is not verified** — the two are separate checks and only one has been run:
the cited paper's **existence** was confirmed 2026-07-28 (arxiv.org/abs/2603.09619 → HTTP 200,
title matches; measured alongside a known-real control ID, so the check itself is calibrated).
The **figures** above were not read out of the paper — they are still traced only to the digest
comment. Treat the ratio thresholds as illustrative, not a calibrated gate, until the source
text is read directly.

> **Detail**: See `SKILL_detail.md §CacheBoundary` — full citation text and the 403 grounding
> note — read before citing these figures elsewhere.

### Step 4. harvest-loop Integration (burst pattern recording)

When burst pattern is detected and `tracks/_audit/` exists: locate the latest weekly_audit file and suggest adding the Token Efficiency Check items to it (bash + checklist block in §Step-Bash).

Environments without `tracks/_audit/` (Mode C — plugin only): → output items to terminal only, skip file writes.

### Step 5. CC Context Structure Regular Audit (Hub Environment Only)

**Hub environment detection condition**: CLAUDE.md contains "your-hub" or "meta hub" + `memory/MEMORY.md` exists. Skip Step 5 when not in a hub environment.

Run the audit bash (§Step-Bash) and apply thresholds:

| Target | Threshold | Prescription |
|---|---|---|
| CLAUDE.md | Exceeds 300 lines | Section-by-section compression / move completed sections to archive |
| MEMORY.md | Exceeds 180 lines | Check entry count + move `✅ CLOSED` items to archive section |
| memory/*.md single file | Exceeds 30K (300 lines) | Suggest splitting accumulated history into separate files |
| SKILL.md (any) | > 300 lines AND no SKILL_detail.md | Propose `/salience-splitter` — governance-semantic split (not compression); compression removes content, splitting routes it on-demand |

**Frequency**: When explicitly called with `/context-doctor` or auto-invoked at session start when MEMORY.md is detected at 180+ lines.

**Cache-boundary note**: apply CLAUDE.md compression (above) at a session boundary, not mid-session — see Step 3.5's cache-invalidation tension if that step is also in scope.

## Context Hierarchy (L1/L2/L3)

Information buried in the middle of a long context window suffers measurable accuracy loss — the "lost in the middle" effect, ~10–30% degradation for mid-context information (see `../../../../knowledge/shared/harness-core/harness_frontier_diagnosis_2026-06-02.md`). The remedy is two-fold: tier the context, and place the most important instructions at the **start and end**, never buried in the middle.

**Three tiers — keep each within its band**:

| Tier | What lives here | Rough budget | FH example |
|---|---|---|---|
| **L1 — always-on** | System / critical instructions that must hold every turn | ~2–5K tokens | `CLAUDE.md` core rules, active session.md header |
| **L2 — session summary** | Current task state, decisions made this session | ~5–20K tokens | active track session file, `reference_next_session_starter.md` |
| **L3 — on-demand** | Reference material retrieved only when needed | unbounded, loaded then dropped | `knowledge/` docs, large source files via Read offset/limit |

**Placement norm** (applies to CLAUDE.md, prompts, and dispatched Context Cards):
- Put the load-bearing rule or task goal in the **first lines and restate it in the last lines**.
- Do not park a critical constraint in the middle of a long document — it is the most likely place to be missed.
- Promote frequently-needed L3 docs to L2 summaries; demote stale L1/L2 content to L3 (load on demand) rather than keeping it always-on.

When auditing CLAUDE.md / MEMORY.md in Step 5, check tier placement too: a critical rule sitting mid-file is a placement defect even if the file is within its line budget.

**Measured anchor — select what to feed back, don't truncate at overflow.** *Less Context, Better Agents* (arXiv:2606.10209) measures this: pruning the fed-back context to the last 5 tool-call/response pairs raises **complete itemization to 79.0%** (vs 71.0% keeping full history, 8.0% naive truncation) while cutting total token use to 535,274; adding summarization reaches **91.6%**. Evidence that selective retention beats a blind `/compact` or overflow truncation — measured on agent tool-call history (a runtime analogue of the L1/L2/L3 tiering above, not a direct test of it).

## Compression Pass

Optional step, run when context is large (e.g. after Step 5 flags a bloated file, or an L3 doc is long but must be loaded). This goes **beyond** `.claudeignore` — `.claudeignore` blocks files from loading; compression shrinks content that does need to load. LLMLingua-style compression is reported to reach ~100K→20K token reductions with minimal loss on long retrieved context (see `../../../../knowledge/shared/harness-core/harness_frontier_diagnosis_2026-06-02.md` Provenance).

Advisory and tool-agnostic — recommend (and, where a doc is being authored/edited in-session, apply) these reductions:

- Strip boilerplate: repeated headers/footers, navigation, license blocks, generated banners.
- Collapse repeated or near-duplicate sections into a single canonical statement plus a pointer.
- Summarize long retrieved docs to the task-relevant slice before pinning them into context; keep the full doc as an L3 file to re-read only if needed.
- Prefer Read offset/limit over full-file reads for large files (ties back to Step 2).

Keep it reversible: compress the *working copy* in context, not the source of truth on disk, unless the user is explicitly editing that file.

> **Detail**: See `SKILL_detail.md §Headroom` — external tooling option (redundancy-category targeting, integration surfaces, caveats) — read when executing a compression pass and considering tooling.

## Command-Output Reduction (the command-output axis)

The reductions above all act on the **context-footprint** axis (files, history read *into* context). They do nothing for the **command-output** axis: the stdout of every shell call. A single `git log`, `npm test`, `ls -R`, or build run can dump thousands of tokens per call, and an agent makes dozens of calls per session — often the *largest* single token sink, and invisible to `.claudeignore`.

**This axis is risk-gated — reduce it only when token cost is the binding constraint.** Unlike `.claudeignore` (which blocks provably-irrelevant *files* — near-lossless and reversible), command-output reduction works by **filtering live output, which is lossy by design**: a dropped middle line — an error inside build output, one file in a long listing — is invisible to the agent, which cannot know what it did not see. So the **default is to do nothing here**. Turn it on only in a genuinely token-scarce setting (a metered / quota-limited backend where token budget is the *binding* constraint — not where tokens are merely plentiful); there the savings outweigh the information-loss risk, and **everywhere else they do not**.

**Two ways to reduce, safest first:**
1. **Per-call narrow flags (default — non-lossy, no install).** Prefer narrow commands: `git log --oneline -N` over bare `git log`, `--quiet` on noisy tools, `head`/`tail` on long output. The agent chooses what to drop, per call — no blind heuristic. This suffices for almost every session.
2. **A command-output proxy/hook (only under token scarcity).** A **Claude Code hook that rewrites verbose commands through a token-reducing proxy**, transparent (0 prompt-side overhead). Recommended tool: **`rtk` (Rust Token Killer)**, a CLI proxy that filters dev-command output (the tool reports ~60–90% savings on dev operations), wired so `git status` → `rtk git status` happens automatically.
   - **Measure, don't quote**: `bash scripts/rtk_gross_ablation.sh [repo]` measures the actual gross
     cut on YOUR env's command-output slice (instrument-check first — a dead filter emits stubs that
     fake 82–100% cuts). The vendor band above is a claim; the script returns a local measurement — a char/4 approximation whose error direction is toward OVER-stating the cut
     (e.g. 68.3% on the FH repo slice, 2026-08-10 — your number will differ; measure yours). NET (context-loss) stays unmeasured either way.
   - ⚠️ **Name collision**: there is an unrelated `reachingforthejack/rtk` (Rust Type Kit). Verify the Token-Killer build — `rtk gain` (savings analytics) should work; "command not found" means the wrong binary.
   - **No-reinvention**: FH **routes to** this tool; it does not rebuild a token-killer. Install + hook wiring live in the user's own config (global `CLAUDE.md` / `settings.json`), never reimplemented here.
   - ⚠️ **Never filter a command whose output a mechanical gate parses.** FH gates read raw command output (a pre-commit hook greps, `regression_guard` diffs). A filtered `git diff` / `git log` feeding a gate gives the gate wrong input — the same trap as grepping filtered prose for a verdict (typed-verdict-channel). Keep filtering off gate-input paths, and keep a raw escape hatch (`rtk proxy <cmd>`).

**Prescription**: in a normal token environment, recommend the per-call flags (#1) and **do not** suggest installing a proxy — the lossy risk is not worth it. Only when the user states or exhibits a binding token constraint, surface #2 with the gate-input caveat above. Diagnosis + recommendation, never an auto-install.

## External User Environment Adaptation

| Environment | Behavior |
|---|---|
| Meta-harness cloned (Mode A) | Perform full Steps 1–5 (+ optional Step 3.5) / integrate with harvest-loop files |
| Plugin only (Mode C) | Perform Steps 1–3 (+ optional Step 3.5, no file writes needed) / Step 4 output only (no file writes) |
| External general environment | Focus on `.claudeignore` generation + large file guidance |

## Invocation Triggers

### Auto-Invocation Conditions (at session start)

Invokes **only when `.claudeignore` is absent**:
```
"This project has no .claudeignore. Token waste may be occurring. Check with /context-doctor?"
```

When `.claudeignore` exists → skip auto-invocation (treated as already configured).

> **Burst pattern auto-detection (500+ line files) is excluded from auto-invocation** — only performs on explicit call. Firing every session becomes noise.

### Suppress Mechanism

context-doctor adds a sentinel comment to the first line when generating or updating `.claudeignore`:

```
# context-doctor: configured 2026-05-10
```

Auto-invocation decision order:
1. `.claudeignore` absent → auto-invoke O
2. `.claudeignore` present + sentinel present → auto-invoke X (fully suppressed)
3. `.claudeignore` present + sentinel absent (manually written) → auto-invoke X (file existence itself is suppress signal)

**Manual suppress**: User adds the following to the first line of `.claudeignore` for permanent suppress:
```
# context-doctor: suppress
```

Explicit invocation (`/context-doctor`) always runs regardless of suppress state.

### Explicit Triggers

- `/context-doctor`
- "token waste", "session is slow", "reading the whole file", "claudeignore", "context cleanup"
- "context diet", "memory audit", "CLAUDE.md is heavy", "MEMORY.md size"
- "context engineering", "context rot", "context collapse"
- "command output is huge", "verbose output", "rtk", "token killer", "trim command output"
- "prompt caching", "cache hit rate", "cache boundary", "why are my API costs so high"

### Natural Language Triggers (activates without internal vocabulary)

Also activates when an external user expresses without token/context terminology:

| Example utterance | Intent | Mapped diagnosis |
|---|---|---|
| "The context seems to be getting too large" | Suspected context bloat | Step 5 (hub) / Step 2 |
| "Tokens are being wasted" | Suspected token efficiency degradation | Step 1 + Step 2 |
| "The conversation feels inefficient" | Suspected accumulated session noise | Step 3 (/clear timing) |
| "Why is Claude so slow?" | Burst pattern or context overload | Step 2 |
| "Seems like it keeps re-reading the same thing" | Repeated full-read detected | Step 2 (burst pattern) |
| "Answers get weird as the session gets longer" | Accumulated context noise | Step 3 (/clear recommended) |
| "Context is getting full", "context meter is high" | Approaching context limit | Step 3 — propose Wrap-then-Compact pattern |
| "context engineering", "doing context engineering", "context rot setting in" | 2026 industry term for context discipline (Chroma 2025 / Anthropic) | Step 2 + Step 3 |
| "every git command dumps a wall of text", "the build output eats my context" | Verbose command output flooding context | §Command-Output Reduction (route to proxy/hook) |
| "our token bill is high but context looks fine", "cache keeps missing" | Suspected cache-boundary invalidation, not context bloat | Step 3.5 (optional) |

## Three-Doctor Loop Integration

### context-doctor's Role in Three-Doctor Loop

```
harness-doctor   → current skeleton diagnosis   "Is the structure correct? Any drift/complexity/broken references?"
context-doctor   → current context diagnosis    "Is Context Collapse occurring?"
sim-conductor    → future behavior prediction   "What happens when a real person uses this system?"
```

context-doctor is the **current context diagnostic role** among the three skills. It detects token waste/burst patterns/context contamination and presents prescriptions (.claudeignore/clear timing), which harness-doctor (skeleton) and sim-conductor (future behavior) then pick up to complete the closed loop.

---

> **Context Anxiety**: Agents make uncertain inferences when relevant context is absent — this is the engineering rationale behind the context-doctor/bridge structure. (Anthropic official naming 2025)

context-doctor (token/context) · harness-doctor (structure) · sim-conductor (simulation/ideation) — the three skills form a **diagnosis→prescription→re-diagnosis** closed loop.

| Situation | Next skill |
|---|---|
| Want to also check structure after resolving token waste | `/harness-doctor` |
| Want to validate prescription results from external user perspective | `/sim-conductor Area A` |
| SKILL.md diagnosed as over-loaded (> 300 lines, no SKILL_detail.md) | `/salience-splitter` — governance-semantic split |
| All three skills mentioned simultaneously | Three-Doctor Loop circuit activated — diagnosis→prescription→re-diagnosis cycle

## Done When

| Condition | Completion verdict |
|---|---|
| Diagnosis results output to conversation (relevant stages among Steps 1~5, incl. optional 3.5) | ✅ Diagnosis complete |
| `.claudeignore` created or modified + path output | ✅ Prescription complete |
| Large file detected with split strategy guidance output | ✅ Step 2 complete |
| Step 3.5 run: checklist findings output, thresholds labeled UNCALIBRATED per source above | ✅ Cache-boundary audit complete (only when Step 3.5 was triggered) |
| "No context structure issues" judgment output | ✅ Health check complete |

**This skill's Done When = "diagnosis report output complete"**. Actual resolution of prescription items is in the user's or follow-up work domain and is not included in this skill's completion criteria.

**External validation path**: harvest-loop Step 3.75 Critic isolated Agent can independently judge against the above criteria (`skill_quality_rubric.md` verifiable criteria). Automatically linked when subsequent steel-quench runs.

**→ Three-Doctor Loop chain (auto-propose after diagnosis):**
- Prescription modifies SKILL.md / rules / CLAUDE.md → **propose `/harness-doctor`** re-check after fix (structural integrity)
- Prescription addresses user-facing context (onboarding, README, install guides) → **propose `/sim-conductor Area A`** (external user impact validation)
- SKILL.md detected as over-loaded → **auto-propose `/salience-splitter`**: `"I see [skill-name] SKILL.md is [N] lines with no SKILL_detail.md. Want me to run /salience-splitter to do a governance-semantic split?"`
