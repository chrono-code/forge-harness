<!--
session.md — Claude Code Session Rules Template

Purpose of this file:
- Define Claude's session operating rules (how to behave)
- Behavioral guidelines applied across the entire project
- Commit to Git and share with the team
- Edited and managed directly by the user

Difference from MEMORY.md:
- MEMORY.md: Stores data/experience learned during conversation (auto-managed by Claude)
- session.md: Defines procedures/rules for Claude to follow (edited directly by the user)

Usage:
- Copy this file to your project's .claude/rules/session.md
- Add, remove, or modify sections to fit your project
- Change sections marked with [CUSTOMIZE] comments to match your project
-->

### Automatic Actions at Session Start

#### Root Memory (Knowledge Hub) Connection

At the start of a conversation ("hello", "let's start", "load root memory"), perform the following:

1. Read `{FH_ROOT}/CATALOG.md`
   - Understand recent work context
   - Check today's tasks (todo/plan)

2. Load project memory index
   - Check `.claude/projects/.../memory/MEMORY.md`
   - Prioritize loading memory most relevant to current work
   - Proceed naturally without notifying the user that memory was loaded

#### Exceptions
- If the user explicitly requests not to use memory
- For simple one-off questions, load is optional

---

### Session Backup Before Tests

<!-- [CUSTOMIZE] Adjust trigger conditions to match your test framework -->

#### Automatic Backup Trigger

At any point when tests could be run, **automatically** perform a session backup:

1. **When I recommend running tests** — **immediately before** the recommendation message
2. **When the user signals intent to start tests** — **before** running the test command

#### Why Backup
- Sessions can be forcibly terminated when tests start
- Prevents loss of conversation context, analysis results, and change history

#### How to Backup

```bash
cat > .claude/session_backup_$(date +%Y%m%d_%H%M%S).md << 'EOF'
# Session Backup - [Task Title]

## Problem
- [Issue currently being resolved]

## Changes Made
- [filename:line]
- [before/after]

## Next Steps
- [Things to verify after tests]
EOF
```

#### Important
- Perform **automatically** even without an explicit user request
- Never recommend tests without first creating a backup

---

### Automatic Response to Issues

<!-- [CUSTOMIZE] DOMAIN-SCOPED — delete this whole section if the project has no test-report
     artifact to analyse. The old wording here said "adjust report tool/path", which assumes the
     tool exists and reads as a config note rather than a delete instruction; the same measurement
     that found the two sections below inert found this one inert for the same reason. -->

#### Automatic Check Trigger

When the user mentions a problem, **automatically** locate and analyze the latest test report:

1. **Trigger keywords**
   - "something broke", "got an error", "it failed", "not working"
   - "issue occurred", "test failed", "broken", "failed"

2. **Analyze and report**
   - Names of failing test cases
   - Error messages and stack traces
   - Summarize in a concise format

---

### Code Writing Principles

<!-- [CUSTOMIZE] Adjust to match your project's coding conventions.
     THREE of the five below are universal (#1 #2 #5). TWO are DOMAIN-SCOPED and belong only to
     UI/mobile-QA projects (#3 locator stability, #4 flakiness) — DELETE them outright if this
     project has no UI automation. Do not keep them "just in case": measured 2026-08-03 across
     THREE repos that inherited this file. One (a bash/python wiki engine) carried both for its
     entire 11-day life before being pruned; the other two are byte-identical to this template
     right now and still carry them.
     If you delete a section, also fix any sentence that counts them — the wiki engine shipped
     "all 5 principles" over three for an hour before an outside reviewer caught it.
     What the fix here does and does NOT do, measured as a before/after pair (Sonnet, reps=3).
     The gain depends on how explicitly the asker names what the project lacks:
       * question naming no-UI/no-mobile only  -> before: #3 3/3, #4 **1/3**;  after: both 3/3
       * question also naming no-test-reports  -> before: 8 of 9 cells;        after: 9 of 9
     So the honest claim is narrow: the old wording is mostly adequate for someone who spells out
     every absence, and loses a section for someone who does not. Both numbers are recorded because
     citing only the first would overstate this edit.
     THE FIELD CAUSE IS STILL OPEN, and it is a different moment: the wiki engine did not prune
     either section, which means nobody was asked. `light-harness init` copies this file whole,
     with no pruning step. A marker only works on a reader who has stopped to read it. -->

Be conscious of every principle below **before** writing code — directly reduces back-and-forth where Claude rushes to create something and the user has to correct it.

#### 1. Reference Existing Code (Consistency First)

- **Reference targets**: Code with similar functionality or in the same layer within the project
- **No introducing new patterns** — follow existing patterns first; only abstract when the same pattern repeats 3+ times and needs consolidation
- **Follow framework Core/Base class patterns** — if the project has `.claude/rules/`, that hierarchy takes precedence

#### 2. Independence and Regression Prevention

- Verify that new code **does not break existing tests or functionality**
- Manage side effects (shared state, global variables, file locks)
- Use `git grep` before changes to understand the impact surface — check for unexpected callers

#### 3. Locator and Identifier Stability (UI code only)

<!-- [CUSTOMIZE] DOMAIN-SCOPED — delete this whole section for non-UI projects (see the note above #1) -->

- Do not depend on dynamically generated attributes (auto-generated id, timestamps in content-desc)
- Avoid absolute XPath — fragile to structural changes
- Consider i18n for text-based identifiers (multilingual projects)
- If the project has `.claude/rules/LOCATOR_*` guides, those take precedence

#### 4. Flakiness Risk Management

<!-- [CUSTOMIZE] DOMAIN-SCOPED — delete this whole section for projects without UI automation -->

- **No `time.sleep`** — use explicit waits (implicit/explicit wait) + condition-based polling
- No unbounded waits without a timeout
- Allow tolerance in screenshot-based assertions
- Minimize assumptions about device/environment state (keyboard visibility, previous screen state, etc.)

#### 5. Mandatory grep Before Design (Prevent Missing Own Assets)

**Before** designing a new feature or pattern:

1. grep for similar implementations in the project — reuse if already present
2. grep learnings from sibling projects in the hub (e.g., `{FH_ROOT}/`) — prevent reinventing solutions already solved elsewhere
3. Re-read the project's CLAUDE.md and rules/*.md — check for overlooked constraints

Starting design with zero cited references is a warning signal for **missing own assets**. Always present at least 1 grep result before beginning design.

---

### Rule Hierarchy and Priority

<!-- [CUSTOMIZE] Define rule sources and priority for your project -->

**Priority when conflicts arise:**
1. **Framework rules** — code patterns (non-negotiable)
2. **Test design philosophy** — "what to test" (QA Identity, etc.)
3. **Learned feedback** — rules based on user experience
4. **Operational rules** — session backup, report analysis, and other work processes
