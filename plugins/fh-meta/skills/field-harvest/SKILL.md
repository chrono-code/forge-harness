---
name: field-harvest
description: Scans git history of field projects to detect patterns worth backporting to the meta-harness (Mode A), and logs session work to the knowledge hub when a session ends (Mode B). Triggers on "save this pattern", "make this reusable across projects", "can we automate this repetition?", "push this to FH", "reverse absorption", "harvest pattern", "session log", "log today's work", "sync to hub".
user-invocable: true
allowed-tools: ["Bash", "Read", "Edit", "Write", "WebFetch"]
model: sonnet
---

# field-harvest — Field Pattern Harvest → FH Backport + Session Logger

Dual-mode skill:
- **Mode A (Pattern Harvest)**: Scans recent commits in field projects to detect patterns worth backporting to FH. One-click flow from detection to PR creation.
- **Mode B (Session Log)**: Records session work from field projects to the knowledge hub when a session ends. Auto-generates a session markdown file with commits, learnings, and next steps.

## Mode Selection (Step 0-A)

Determine which mode to run based on user context:

| Condition | Mode | Priority |
|---|---|:---:|
| User message contains: "session log", "log today's work", "sync to hub", "sync session" | **Mode B (Session Log)** | 1 (highest) |
| **Session-end auto-trigger fires** (see below) and field commits exist today | **Mode B (Session Log)** — auto-proposed | 2 |
| Both Mode A and B applicable | Run Mode B first, then ask "Also run Mode A pattern harvest?" | 3 |
| Default or path specified | **Mode A (Pattern Harvest)** | 4 |

### Session-End Auto-Trigger (item1 — Mode B)

Mode B should not wait for an explicit "session log" phrase when a session is plainly ending with un-logged field work. **Auto-propose Mode B** (one line, never auto-run) when **all** hold:

1. A session-close signal is detected — the CLAUDE.md Session Wrap-up chain has begun, **or** the user says a closing phrase ("wrap up", "done", "good work", "end session", "that's it for today").
2. The current cwd is a **mapped field project** (not the FH hub itself — hub close is owned by harvest-loop / the Session Wrap-up chain).
3. `git log --since="today"` in that field project returns **1+ commits** by the session author that are **not yet logged** to the hub (cross-check via the detection-skip ledger, item2 below).

Proposal format (one line, then wait):
```
"Session is wrapping up and {project} has N un-logged commits today. Log them to the hub with Mode B? [y/n]"
```

**Collision guard (harvest-loop boundary)**: "wrap up" / "end session" in the **FH hub cwd** stay owned by the CLAUDE.md Session Wrap-up chain (which calls harvest-loop). This auto-trigger is **field-cwd only** and is a *proposal*, never an interception — if harvest-loop is already running for this session, do not also propose Mode B (harvest-loop calls field-harvest internally as Step H1). One proposal per session.

> **Note**: harvest-loop remains the owner of hub-side wrap-up. Mode B auto-trigger only covers the gap where a *field* session ends with un-logged commits and the user never typed an explicit session-log phrase.

**Execution order when both applicable**: Run git scan once, reuse results for both modes to avoid duplicate scans.

---

## Step 0. Field Project Path Detection

When no path is specified, auto-detect with 3-level priority: ① FH `auto_project_mapping.md` → ② auto-discover git repos in common dev directories (excluding the hub itself) → ③ scan parent of cwd. List discovered repos and ask the user to select; 0 repos → prompt for direct path input.

> **Detail**: See `SKILL_detail.md §ModeA-Blocks` — path-detection bash, commit scan, classification commands, candidate list format, PR creation bash — read when executing Mode A Steps 0–4.

## Step 1. Recent Commit Scan

Scan `git log --oneline --since="<N> days ago" --no-merges` in the field path. If commit count is 0, report "no changes within last <N> days" and exit.

## Step 2. Harvest Candidate Classification

Classify each commit using the following criteria (commit message + changed-file patterns first → read diff when needed):

### FH Reverse Absorption Candidate Conditions (when one or more apply)

| Signal | Example | FH absorption type |
|---|---|---|
| **New workflow pattern** | New CLI tool, pipeline automation | Skill candidate / SKILL.md improvement |
| **Cross-project feedback** | "This approach can apply to other projects too" | `.claude/rules/` improvement |
| **Prompt engineering pattern** | Few-shot additions, new CRITICAL RULE | knowledge/shared pattern |
| **Error pattern solution** | Recurring error → converted to rule | Skill guard addition |
| **Tool integration method** | MCP integration, API usage patterns | Skill Step expansion |

### Field-only (No FH Reverse Absorption Needed)

- Domain-specific code (insurance logic, UXW prompt content itself)
- Project-specific config/environment files
- Bug fixes (one-off non-reproducible)
- Simple documentation updates

## Step 3. Harvest Candidate List Presentation

Output the candidate list (format in §ModeA-Blocks): scanned count, FH absorption candidates with type/location/impact stars, field-only skipped count, then ask `[all / select number / skip]`. If 0 candidates, report "no absorption candidates" and exit.

## Step 3.5. contention-layer — Collision Gate (mandatory when candidates ≥ 1)

Run `contention-layer` on the confirmed candidate list **before any PR is created** — a new pattern
must be checked for collision with existing skill role clusters before registration. Skip only when
Step 3 found 0 candidates.

| contention-layer result | Behavior |
|---|---|
| No collision | Proceed to Step 4 |
| Collision / blocked registration | **No PR** — verdict `FAIL` per the enum below |
| Role collision needing a human call | **No PR** — verdict `ESCALATE` |

(This step previously existed only as a line *below* Done When — a cold executor reading Steps 0–4
had no occasion to see it before `gh pr create`. It is now in the execution path it gates.)

## Step 4. PR Creation (upon user approval, after Step 3.5)

Create a `harvest/{project}-{date}` branch in FH, apply approved patterns, commit, push, and `gh pr create` (bash + PR body checklist in §ModeA-Blocks).

## Step 5. Done (Mode A Complete)

Report harvest candidate list and PR creation status to user.

---

## Invocation Triggers

### Auto-Proposal Conditions (detecting user conversation context)

Propose `/field-harvest` proactively when these patterns are detected:

| Pattern | Example | Proposal strength |
|---|---|---|
| **FH absorption intent** | "Should we push this to FH?", "Is this worth absorbing?", "harvest this pattern" | Immediate proposal |
| **Field pattern discovery** | "Found this pattern in my project", "There's something repeating on that side" | Immediate proposal |
| **FH improvement idea** | "What if we made this a skill?", "We could turn this into a rule" | Immediate proposal |
| **Field git log mention** | "Looking at the commits", "Checking recent changes", "What did I do this week?" | Proposal |

### Natural Language Triggers (activates without internal vocabulary)

| Example utterance | Intent |
|---|---|
| "This approach could be reused in other projects" | Cross-project pattern harvest |
| "Would be good to save what we found somewhere" | Pattern persistence → absorption |
| "If our team uses this, other teams probably can too" | FH sharing value detection |
| "This seems repetitive — can we automate it?" | Repeating pattern harvest candidate |
| "I forgot what we did last week and had to look it up again" | git log scan trigger |
| "session log", "log today's work", "sync to hub" | Mode B session log |

Proposal format:
```
"There seems to be a field pattern worth absorbing to FH. Scan with `/field-harvest`?"
```

### Simplification Guard

- If user has already invoked `/field-harvest`, no duplicate proposals
- If only 1 trigger pattern detected → light 1-line suggestion only (avoid over-intervention)
- If field cwd cannot be confirmed before proposing → first ask "which field project do you mean?"

---

## Simplification Guard (Global)

- **Domain code absorption forbidden**: Field domain logic is not an FH target — auto-skip when detected
- **Duplicate detection**: When a similar pattern already exists in FH, replace with "cross-reference existing assets then suggest merge"
- **Minimum validation criteria**: One-off patterns show as candidate + ★ 1 → recommend proper absorption after 3+ accumulations
- **PRD/sensitive data**: Diffs containing field PRD content or personal information are auto-masked and only the pattern is extracted

---

## External User Environment Adaptation

When project paths from the original developer environment are not present:

> The original developer's project paths are examples. In external environments, replace with your own project names/paths — Step 0 auto-discover handles detection automatically, no manual replacement needed.

- Step 0: Fallback to user-specified path
- Step 4: `GH_HOST` auto-detection (internal GHE vs github.com)
- FH ROOT: Auto-detect with `git rev-parse --show-toplevel`

---

# Mode B: Session Log → Knowledge Hub Sync

Records session work from field projects to the knowledge hub when a session ends. Generates a session markdown file from git history only (no conversation context), then commits to the hub.

## Step 0-B. Locate Hub Path

Auto-detect knowledge hub location with 3-level priority: ① FH env vars (`FH_DIR`/`CC_HUB_DIR`) → ② auto-discover hub candidates near home → ③ ask user. Track subdirectory: field projects → `tracks/{project-name}/`, external collaborations → `tracks/external/{name}/`.

> **Detail**: See `SKILL_detail.md §ModeB-Blocks` — hub-locate bash, detection-skip inline-grep, session scan, session markdown template, hub commit bash, confirmation format — read when executing Mode B Steps 0-B–5-B.

## Step 0-B.1. Detection-Skip — Already-Logged Pattern Filter (item2)

Before scanning session work, build a **skip ledger** of commits already recorded in the hub so the same commit is not logged twice across sessions (re-runs, overlapping auto-trigger + explicit invocation, multi-session same-day work).

**Skip rule (behavioral)**: a field commit hash is **skipped** (excluded from Step 1-B scan output) if it already appears in any existing session file under the project's track directory.

> **Detection-skip style: stateless inline-grep (finalized).** FH uses the inline-grep form (bash in §ModeB-Blocks) rather than a persisted ledger file: it keeps no extra state to sync and is self-correcting — the hub session files *are* the ledger. Adequate at FH's scale.

If **all** of today's commits are already logged, report `"All N commits today are already logged to the hub — nothing new to record"` and exit (Mode B done, no empty session file written). This is also what the item1 auto-trigger consults to count *un-logged* commits — the auto-trigger must not fire on a session whose commits are all already logged.

**Limitations (honest)**: hash-prefix matching can collide on very short prefixes (use 7+ chars) and only catches commits that were logged with their hash listed in the `## Commits` section (Step 3-B always lists hashes, so hub-generated logs are covered). It does not dedupe *uncommitted* work — that is intentional, uncommitted changes have no stable identity to skip on.

## Step 1-B. Scan Current Session Work

Use the **detection-skip-filtered** commit set from Step 0-B.1 (already-logged hashes removed), not the raw `git log`. Also capture uncommitted changes via `git status --short`.

## Step 2-B. Extract Session Summary

**From git log only** (no conversation context — prevents hallucination):

1. **Context**: Infer from first commit message
2. **Solution**: Aggregate commit messages
3. **Commits**: List with hashes
4. **Next Session**: Parse TODO/FIXME via `git grep`
5. **Key Learnings**: Ask user (optional, 1–2 lines)
6. **FH Backport Points**: Auto-detect from "pattern"/"reusable" keywords in commits

## Step 3-B. Generate Session Markdown

Generate from the template in §ModeB-Blocks (Context / Solution / Commits / Next Session / Key Learnings / FH Backport Points / Tags). Filename: `session_YYYY_MM_DD_<slug>.md`.

## Step 4-B. Write + Commit to Hub

Write the session file and commit to the hub (bash in §ModeB-Blocks).

> **Push policy**: commit only. Push requires explicit user approval ("push해줘", "push it"). Do not auto-push — consistent with FH PR principle.

## Step 5-B. Confirmation

Output the confirmation block (file path + commit hash + push offer — format in §ModeB-Blocks).

## Step 5-B.1. UAP Update (Operational Adaptation Loop)

> Rule: `knowledge/shared/rules/operational_adaptation.md`

At field-session close, update the **User Adaptation Profile** (`tracks/_meta/user_adaptation_profile.md`, local/gitignored — skip silently if absent or in an ephemeral/cloud session):

1. **WRITE** — append this session's skill-proposal outcomes (`accepted`/`rejected`/`sustained`, same vocabulary as `operations.md`) + any new recurring friction. Behavioral prefs only — never domain content.
2. **Generalization check** — for any UAP entry that recurs across **2+ sessions/projects** (not user-specific), flag it as a **Mode A harvest candidate** (`≥40%` reject = redefine/deprecate candidate; `≥60%` accept = reinforce). Idiosyncratic entries stay local.

One pass per session; never blocks the Mode B commit.

---

## Done When

**Mode A (Pattern Harvest)**:
```
All stages through the exit point complete (Step 0~4; or
  Step 0~3 + the 0-candidate exit, which is a valid terminal)          — mandatory-pass
+ Step 3 harvest candidate list output (N candidates + M field-only)  — measured (counts)
+ Step 3.5 contention-layer ran on the confirmed list (or its
  0-candidate skip recorded) and its verdict gated Step 4             — mandatory-pass
+ Upon user approval, Step 4 PR creation complete (gh pr create ran)  — mandatory-pass
+ When 0 candidates, "no absorption candidates" reported then exit    — mandatory-pass
```

**Mode B (Session Log)**:
```
All Steps 0-B ~ 5-B executed                                          — mandatory-pass
+ Step 0-B.1 detection-skip ledger applied (already-logged filtered)  — mandatory-pass
+ Session markdown file generated from git log
  (or "all commits already logged" exit)                              — mandatory-pass
+ Hub commit created (no auto-push)                                   — mandatory-pass
+ Confirmation output with push offer                                 — mandatory-pass
```

The harvest-worthiness classification itself (Steps 1–2) is *judged* — its adversarial pairing is
Step 3.5 `contention-layer` plus the PR-side `asset-placement-gate`; no candidate registers on the
author's judgment alone.

Verdict: PASS (harvest candidates output and PR created, or 0 candidates confirmed) | CONDITIONAL_PASS (candidates found but PR pending user approval; or Mode B commit created, push pending) | FAIL (contention-layer blocked candidate registration; or hub path not found) | ESCALATE (role collision with existing skill requires human decision)

**→ Mandatory next: `contention-layer`** — executed as Step 3.5 above (kept here in closed-chain form for chain auditors: run after Step 3 candidate confirmation, before Step 4 PR creation; skip only at 0 candidates).

## Linked Skills

| Situation | Linked skill |
|---|---|
| Auto-pipeline on session wrap | `harvest-loop` — calls field-harvest internally as Step H1 |
| devil attack/innovator synthesis on harvest candidates | `harvest-loop` Steps H3~H3.5 |
| Need PR directly after standalone pattern extraction | This skill Step 4 direct execution |
| Session log to hub | This skill Mode B (standalone) |
