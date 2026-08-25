# AGENTS.md — forge-harness Runtime Entry Point

> **Always-loaded layer.** Keep agent selection and rules that must govern every runtime here.
> Load execution examples, compatibility history, and conditional procedures only through the
> imperative pointers below.

## Relationship to CLAUDE.md

| File | Scope | Audience |
|---|---|---|
| `CLAUDE.md` | Session rules, protocols, orchestration flow | Claude Code |
| `AGENTS.md` | Portable runtime rules, agent roles, dispatch boundaries | AI runtimes + humans |

`CLAUDE.md` governs Claude-native automation. This file is the portable entry point for Codex and
other non-Claude runtimes, which do not auto-load `.claude/rules/*.md`.

## Agent Registry

forge-harness ships 8 tracked agents. The user-mastery spectrum (`beginner` · `main-player` ·
`expert`) plus `challenger` supplies multi-persona review; the remaining agents serve harness
operations or steel-quench.

| Agent | File | Role | Invoked by |
|---|---|---|---|
| `beginner` | `plugins/fh-meta/agents/beginner.md` | First-contact cold read; finds onboarding friction | `sim-conductor` Area A, `marketplace-gate`, `install-wizard`, direct |
| `main-player` | `plugins/fh-meta/agents/main-player.md` | Engaged-user view; scopes Light/Midcore/Heavy usage | `sim-conductor` Area A/D-code, direct |
| `expert` | `plugins/fh-meta/agents/expert.md` | Web-grounded domain accuracy and current practice | `sim-conductor` Area E/D, paper review, direct |
| `challenger` | `plugins/fh-meta/agents/challenger.md` | Evidence-cited adversarial evaluation | `steel-quench`, `harvest-loop`, `sim-conductor`, direct |
| `fact-checker` | `plugins/fh-meta/agents/fact-checker.md` | Pre-recommendation duplicate and stale-fact search | Before new asset creation or recommendation |
| `hub-persona-auditor` | `plugins/fh-meta/agents/hub-persona-auditor.md` | External-facing pre-publication persona audit | `hub-cc-pr-reviewer`, `sim-conductor`, direct |
| `quench-challenger` | `plugins/fh-commons/agents/quench-challenger.md` | Steel-quench attack plus concrete fix direction | `steel-quench` Wave 1, `install-doctor`, `marketplace-gate` |
| `persona-innovator` | `plugins/fh-meta/agents/persona-innovator.md` | Naming gaps, frame proposals, frontier signals | `sim-conductor` Area A, `harvest-loop`, direct |

Machine-readable mirror: `.claude/registry/agent_cards.json`.

> **Agent frontmatter must be valid YAML — and this bites non-Claude runtimes hardest.** Claude Code's
> loader is lenient (it accepted an unquoted `description:` containing `": "`); a strict YAML parser
> does not, and then **every key below the bad line is silently dropped** — including `tools:` and any
> `model:` floor. Measured 2026-08-11: one agent's multi-line unquoted `description` (with `user:` /
> `assistant:` lines inside it) invalidated its declared `tools: Read, Grep, Glob` and its `model: opus`
> floor; the agent ran with all tools and no pin. Keep `description:` to **one quoted line** and put
> examples in the body. `bash scripts/validate_yaml.sh` now covers `plugins/*/agents/*.md` as well as
> skills, and reports a zero-file scan as an instrument error rather than a pass.

### Tool restrictions

| Agent | Allowed tools |
|---|---|
| `challenger` | Read, Grep, Glob, WebSearch, WebFetch |
| `fact-checker` | Read, Grep, Glob |
| `hub-persona-auditor` | Read, Grep, Glob |
| `quench-challenger` | Read, Grep, Glob |
| `persona-innovator` | Read, Grep, Glob, WebSearch, WebFetch |
| `beginner` | Read |
| `main-player` | Read, Grep, Glob |
| `expert` | Read, WebSearch, WebFetch |

The table is the whole roster — all eight agents above appear here. *Three were missing until
2026-08-11; the omission read as "unrestricted" to anyone checking this page, which is the wrong
default for a table whose subject is restriction.* Cross-check with the files themselves rather
than trusting either side alone: the same audit found `challenger` documented here with a tool set
its file never declared at all.

## Runtime Boundaries

- **Two layers:** `tracks/`, `knowledge/`, and skill methodology are model-agnostic. Plugin agents,
  hooks, slash commands, and `.claude/rules/` automation are Claude-native.
- **Output residency:** reusable methodology and polished public guidance belong in `knowledge/`,
  `plugins/`, or `docs/`. Raw signals, operator observations, handoffs, audit logs, and private
  reasoning are private-first; do not infer that colocated directories share a repository.
- **Runtime authority:** a non-Claude sidecar returns evidence candidates, never the terminal verdict.
  The governor must source-close each finding against a local file hit, literal source span, or
  passing check. Governor agreement alone is not an anchor.
- **Sidecar write boundary:** a sidecar audits; it does not write to the target tree. Return
  findings, and at most a proposed patch as text — the governor applies it. This is not a
  courtesy: measured 2026-08-21, an auditor sidecar edited the tree directly and its own fix
  introduced a self-referential fail-open that 41 existing lanes passed.
- **Sidecar completion:** judge a sidecar only by the typed verdict from `scripts/sidecar_wait.sh`.
  Never infer completion or emptiness by looking at its output file.
- **Identity grades:** the five-identity grade table is canonical only in
  `knowledge/shared/harness-core/ship_readiness_gate.md`. Do not restate grades from memory or from
  a session card — cite that file's current state.

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Architecture-and-output-routing`
> — layer ownership and destination routing — read before routing work across a public/private workspace pair.

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Sidecar-routing-and-waiting`
> — capability routing, the required wait command, and typed verdict meanings — read before dispatching a sidecar.

## Mandatory Non-Claude Checklist

Because non-Claude runtimes do not auto-load Claude path rules, apply these rules explicitly:

1. **FH asset change:** before editing, read `.claude/rules/fh_4axis_gate.md`; before the first commit,
   run its required axes. Treat `templates/regression_guard.sh` exit 0 as PASS or SKIP; use its typed
   result channel and never report SKIP as checked.
2. **Company residency:** raw company source, secrets, hostnames, internal names, stack traces, and
   unredacted findings never leave the local machine, including to same-family cloud models. Only a
   sanitized summary may leave; exceptions require explicit operator approval and a gitignored note.
3. **Author exposure:** before calling a material work product done, identify the author's blind spot
   and run the matching `agent-composer` Author-Exposure lens. The lens supplies evidence, not a verdict;
   unclear exposure defaults to `challenger`.
4. **Intent marshaling:** general work is in scope. Enumerate installed skills, `LOCAL_SKILL_REGISTRY`,
   and mapped project assets before composing capability. Preserve each trust tier and each outward
   action gate. Declare a gap only with the scan cited, then route through internal registry search,
   external search, and in-session synthesis. Persist and install retain their existing gates.
5. **Measurement integrity:** before trusting a scan or count, run a known-positive and known-clean
   pair, then open one hit manually. An empty or failed scan is `UNMEASURED`, not zero; extreme results
   require instrument suspicion.
6. **Irreversible intent:** before publish, delete, or history rewrite, read and apply the
   Pre-Publish or Destructive-Op gate in `CLAUDE.md`. `pre-push` is only the git-side backstop.
7. **Self-contrast on asset touch:** the trigger for the three-layer self-contrast (process ·
   engines · identities) is *touching an FH/PMH asset*, not being asked. Pick verification axes by
   failure mode — running all six every time is not the rule. Record, in the existing Axes 2–3
   marker fields: the soul line written before design (or `none`), each axis run and not run — by
   name, and each axis's control with whether it survived. The minimum evidence that an axis ran is
   execution output with a live control; reporting an axis as run without one, or recording only a
   reason for not choosing it, is not compliance. The axes are named in
   `knowledge/shared/harness-core/fh_three_layer_canon.md` — **§1-a is the original four
   (2026-08-09) and §1-a-2 expanded them to six (2026-08-16)**: ⓐ different family · ⓑ standpoint ·
   ⓒ isolated grounding · ⓓ third-party encounter · ⓔ first real use · ⓕ revert-and-observe.
   Axes are separated by **what they received**, not by how adversarial they are — same input,
   same blind spot, however many reviewers you add. ✅ **The machine layer now carries all six**
   (2026-08-17): a marker dated on/after that day must write `axes-run:` with the **circled keys**
   `ⓐ=… ⓑ=→standpoint ⓒ=… ⓓ=… ⓔ=… ⓕ=…`; markers dated earlier keep the old **ASCII four**
   (`a b c d`) and are not retroactively blocked. 🟥 **The two arrays are not the same letters —
   old `b` (first real use) is now `ⓔ`, old `d` (revert probe) is now `ⓕ`.** Copying an old line
   forward silently swaps two axes and raises no error. **Which array a marker used is decided by
   the date in its filename** (`< 2026-08-17` = old four). ⚠️ The notation is NOT the discriminator
   — that claim stood in this file for part of 2026-08-17 and a hand-count of the corpus refuted it:
   2 of the 4 circled-key markers on disk are dated 2026-08-10 and carry the OLD meanings. Aligning
   the notation still helps going forward; it does not work backwards.
   `standpoint:` remains the canonical field for ⓑ (the `axes-run` entry
   is only a pointer to it, and a pointer at an empty field is blocked). 🟥 **CORRECTED 2026-08-20.** This used to say
   "its value enum is still validated by nothing" — FALSE. `validate_standpoint_leg()` in the
   pre-commit hook enforces a closed enum. Measured by varying one variable at a time:
   `standpoint: banana(qasp)` → **blocked (enum)** · `standpoint: tier2` without parens → **blocked
   (enum)** · `standpoint: tier2(qasp)` with no execution grounds → **passes with a warning** ·
   with grounds → **passes**. So the enum is enforced and the `tier2`+ execution grounds are
   **advisory** — a first version of this correction said grounds were required, which over-shot.
   The hook also cannot check whether `tier2` is **true**. Those two, together, are the gap. Format spec: `.claude/rules/fh_4axis_gate.md §Marker axis fields`.
   (Two drift corrections landed here on 2026-08-17: first this sentence said "four" while its own
   next clause described the +1 — caught by the session-close ④-b CC↔Codex parity check — and then
   the machine layer moved to six the same day.)
   ⚠️ Until 2026-08-17 this entry point added "**ⓓ has no field at all** — record it in prose".
   That is now **false**: `ⓓ=` is a required key like the rest. The retraction is kept visible
   rather than deleted, because a Codex-side reader who memorised the old line would otherwise
   keep writing markers without ⓓ and see them blocked with no idea why.
   🟥 ⓑ **standpoint is itself split** (2026-08-17): a STATIC read of the target's own files is
   `tier1b` and **executes nothing**; `tier2`+ asserts that something was RUN — the discriminator is
   mechanical, *name the command you ran and the output you saw*. Measured on one delta: the static
   arm found 1, running the target's own suite found 2 more, one of which printed neither `FAIL` nor
   `❌`. Execution is the half with no substitute; see `field_verdict_crossfamily_gate.md §7`. Read it before recording; §1-c
   holds the sample limits — read it before citing. This record is self-attested and has no hook
   behind it; it is closed by a different-family reader, not by writing it more carefully.
   🟥 **`axis2-defense:` — a marker field added 2026-08-20 that a Codex-side author WILL hit.**
   It is required when the marker records `floor-status: sonnet-floor` or `below-floor`, and it carries
   three sub-answers (on one line, or across continuation lines — the hook reads both) about **your own findings and numbers**:
   `axis2-defense: reproducibility=<exact command or file:line another session runs> fairness=<reps,
   inputs and environment named for BOTH arms> estimation-layer=<per number: measured | estimate |
   quotation; for a measurement, what showed the instrument works on this target>`.
   The hook (`validate_defense_leg`) checks **presence · completeness · non-vacuity** — `ok`/`yes`/
   `n/a` is rejected as a filled form rather than an answer, and all three sub-answers must exist.
   It cannot check whether the answers are true. Why it exists: measured n=6 in the origin field, a
   floor-tier pass runs the attack angles without defect but does **not** spontaneously ask these
   three; that is a checklist gap, not a capability gap, and a harness whose behaviour depends on
   which model drives it is defective by the Sonnet-Floor doctrine.
   Fixtures: `scripts/test_marker_defense_lanes.sh`. Spec: `plugins/fh-meta/skills/steel-quench/SKILL.md`
   §Wave 1-D. **Recorded here because a rule living in only one entry point is invisible to the other
   runtime** — that is the gate-locality principle, and this line is it being applied rather than cited.

8. **Branch-surface claims:** GitHub branch protection is two independent layers — legacy
   protection and rulesets coexist, and the strictest wins. Read both
   `/repos/{owner}/{repo}/branches/{branch}/protection` and
   `/repos/{owner}/{repo}/rules/branches/{branch}` before declaring any branch surface open or
   closed. In the reference repository (forge-harness), reading the protection object alone
   misjudged the force-push surface three times; the symmetric single-endpoint case is untested,
   but the same failure shape applies.

9. **Shared checkout:** when more than one session works in one clone, the working tree and `HEAD`
   are shared, so a branch switch moves the other session's ground. Before `git switch`, read the
   live head with `git branch --show-current`; immediately after cutting a branch, run
   `git log main..HEAD --oneline` — a non-empty result means the branch was cut on top of someone
   else's commits, and a later squash of the parent closes the child PR. The claim files under
   `.git/fh-claims/` are a snapshot written at claim time, not a lock: they do not update when
   somebody moves a branch, so they answer a different question than the two commands above.
   Record a switch with `scripts/branch_claim.sh claim`; the pre-commit hook blocks a commit whose
   claim does not match the live head. In a shared checkout `git add -A` and `git stash` both reach
   the whole tree, including another session's uncommitted work — stage by explicit path instead.

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Mandatory-checklist-procedures`
> — exact supporting procedures and canonical doctrine links — read when any checklist trigger fires.

## Invocation

Non-Claude runtimes apply methodology manually. Prefer `FH_BACKEND=codex ... fh-run` for skills and
agents. When a workflow references `Agent(subagent_type=...)` or a slash command, replace that step
with `fh-run` or a direct `codex exec` call that reads the relevant spec. Use Codex native goal/session
control; FH supplies the quality gate after goal completion.

| Tier | Definition | Skills |
|---|---|---|
| **M1 — Full** | No Claude-native dependency | `token-budget-gate`, `asset-placement-gate`, `phantom-quench`, `deep-clarify`, `convergence-loop`, `ko-tech-writer` (visual-QA degrades to text-only; the spoken register's Step 5-s renders audio through a shell TTS call — available here — but its **listening** pass is human in every runtime, so it degrades to declared-unmet, not to a Codex-specific gap) |
| **M2 — Partial** | Core works; native agent or slash-command steps need adaptation | `deliberation`, `steel-quench`, `harness-doctor`, `context-doctor`, `sim-conductor`, `harvest-loop` |
| **M3 — Claude-only** | Requires a Claude hook or session-scoped dispatch | `goal-quench`, `hub-cc-pr-reviewer`, `install-wizard` |

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Invocation-patterns`
> — single, parallel, and wave composition examples — read when choosing a dispatch shape.

### Before dispatching without being asked

FH treats isolated delegation as part of what a harness *is*, so it leans toward dispatching rather
than absorbing separable work inline. One boundary comes with that, and it is runtime-agnostic:

```
unprompted dispatch is available only when a standing request from the user is RECORDED —
  in a durable local file, carrying all three of:
    the user's own words, quoted   · a dated lease   · a scope line
no such record, or the lease has lapsed, or you cannot tell (fresh clone · a runtime whose
  own prompt may restrict this)
  → the request is absent, and absent is not granted → ask per invocation
```

Four notes for anyone porting this. A record is only a record if the *user* authored the quoted
words — an agent writing the file on its own initiative has produced nothing. Consent is **leased,
not owned**: past the lease date the record stops counting and you go back to asking. Every run that
proceeds *without* a prompt should say that it is doing so, so an unnoticed grant cannot accumulate
silently. And the request buys not-being-asked about the dispatch; it never relaxes a gate at what
the dispatched agent then touches (publish, delete, history rewrite).

The Claude-side rationale — including why the boundary is phrased around a *conditional* rather
than a prohibition — lives in `CLAUDE.md §Agent Dispatch Operation` and is specific to that runtime.
The constraint above is not.

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Codex-entry-points`
> — runnable `fh-run` and `codex exec` forms — read before invoking FH from Codex.

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Compatibility-tiers`
> — tier constraints and goal-handling limits — read before adapting an M2/M3 workflow.

## Conditional Procedures

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Beta-removal`
> — external-validation conditions and reporting route — read when evaluating or changing beta status.

> **Detail**: See `knowledge/shared/harness-core/agents_md_runtime_details.md §Adding-agents`
> — creation gate, registry synchronization, and post-use thresholds — read before adding an agent.

> **Removing resident text**: if you are considering deleting a section from `CLAUDE.md` (or any
> always-loaded asset) because it looks redundant, this repo settles that by measurement rather than
> by reading. The procedure — two arms, an isolated runtime, `reps>=3`, a question set fixed before
> the arms run — is documented in the header of `scripts/probe_scope_check.sh`; the runner must first
> pass `bash scripts/ablation_calibrate.sh` (exit 0), and verdicts are recorded in
> `.claude/regression/ablation_verdicts.md`. Worth knowing before you propose a cut: a section whose
> removal makes a reader answer *confidently wrong* counts as load-bearing, not as safe to drop.
> **And the trap that produces a wrong CUT most easily**: when both arms score the *same*, that is
> equally consistent with the section being redundant and with the scorer never having moved. The
> two are indistinguishable from the outcome alone. Before writing a CUT on equal scores, name an arm
> that MUST score differently and show the metric moved on *that* pair; if it did not, the verdict is
> `INSTRUMENT-UNCONFIRMED`, not `CUT` (added to the script header 2026-08-23, §7).
