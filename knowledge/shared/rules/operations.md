---
description: Defines sub-agent operating rules, weekly improvement cycle Phase 1.5~2, and the 3-phase maturity roadmap (Phase I~III).
---

# Operations Reference

## Sub-agent Operations (optional)

Custom sub-agents can be defined in hub or project `.claude/agents/*.md` (Claude Code standard).

**Invocation rules:**
- Prompts must be **self-contained** — sub-agents do not see main conversation context
- Immediately after invocation, append to `knowledge/shared/learnings/subagent_invocations_log.yaml` (8 fields · outcome 4 categories: `accepted`/`partial`/`rejected`/`sustained`)
- `sustained` (decided not to invoke) also recorded — negative sample for preventing over-engineering

**Shared repository caution:** For personal agents in team shared repos, add `.claude/agents/` to `.git/info/exclude` to keep local-only. `.gitignore` is committed to the repo — do not use it.

**Promotion gate (after 2+ week pilot):**
- `accepted ≥ 60%` → maintain + strengthen description
- `rejected ≥ 40%` → redefine scope or deprecate

---

## Weekly Improvement Cycle

The hub audits and improves itself weekly.

**Phase 1.5 (manual):**
1. Gather window data by hand — `git log --since="{window}" --oneline` (+ count), `git tag --sort=-creatordate`, tail of `knowledge/shared/learnings/subagent_invocations_log.yaml`, stale-file spot checks. (No `_scanner.sh` exists — a prior reference here was a phantom, fixed 2026-06-11; the automation path is Phase 2 harvest-loop, a standalone scanner script is deliberately not built.)
2. `bash scripts/below_floor_scan.sh` — below-floor marker re-run queue (the standing consumer §Floor governance promises: exit 1 = pending floor-tier re-validations, treat as S-tier; resolve via `floor-rerun:` / `floor-writeoff:` appended to the marker)
3. Write `tracks/_audit/weekly_audit_YYYY-MM-DD.md` mirroring the previous audit file's format (frontmatter + activity table + 🟥🟧🟩 + pattern table — no separate template file exists)
4. Propose 3-tier improvements (🟥mandatory/🟧strong/🟩recommended)

**Recurrence escalation** (N=3 threshold): Scanner output shows the same defect class in 3+ distinct commits or sessions within the audit window → S-tier signal; propose instrumenting as a CI probe (`npm test` extension or pre-commit hook) rather than adding a new habit rule. Three recurrences indicate the defect class is structural — habits don't hold.

**Phase 2 (skill-ized):** `/harvest-loop` (lightweight mode) automates the above procedure (manual ~10 min → auto ~3 min target). Scanner invocation, prediction vs measurement comparison, repetitive pattern detection, promotion/deprecation candidate proposal automated.

**Session start auto-detection (L1):** When Claude Code session starts in hub cwd, check mtime of recent `weekly_audit_*.md` file → propose audit if 7+ days elapsed.

**Phase 2~4 roadmap:** See `knowledge/shared/harness-core/hub_compounding_loop.md`.

---

## Flaky-lane triage — re-running erases the evidence you need

**Before you re-run a red CI job, pull the failing lane name out of its log.** A re-run overwrites the
run's `conclusion`, and GitHub's summary then shows the whole history as green — including the run
that failed. The failure is not hidden behind a filter; it no longer exists as a queryable state.

Measured 2026-08-03: a `sync_from_be_lanes.sh` flake was recorded and, when someone went looking the
next day, **all 14 runs that day reported `success`**. The re-runs had rewritten the conclusions and
the failing job's lane name had never been captured anywhere. There was nothing left to diagnose, so
nothing was diagnosed — a guessed diagnosis was correctly refused rather than written down.

Order, on the next occurrence:

```bash
gh run list --workflow <wf> --limit 30 --json databaseId,conclusion,headSha   # find the red run FIRST
gh run view <id> --log-failed | grep -E '❌|FAIL|not ok' | head -20           # capture the lane NAME
# only now consider re-running
```

Record the lane name in the session log even if the re-run goes green — **a flake that cannot be named
cannot be fixed**, and the second occurrence is the one that gets fixed only if the first was named.

This is prose on purpose. N=1: one flake, one lost diagnosis. The mechanization threshold in this repo
is N≥3 or the same class recurring on another surface; a scheduled log-capture job built on a single
occurrence would be the speculative build the evidence-threshold rule forbids.

## 3-Phase Maturity Roadmap

The hub's long-term evolution path is managed as a 3-stage model: **Phase I (entering maturity) → Phase II (frontier following) → Phase III (frontier leading)**. Phase transition gates have the simplification principle ("A good harness gets simpler over time") as a common condition.

**Detailed frame:** See `knowledge/shared/harness-core/hub_maturity_roadmap.md` (Phase I 5-criteria gate · Phase II (b) cadence · Phase III 6 indicators + operating guide for writing).
