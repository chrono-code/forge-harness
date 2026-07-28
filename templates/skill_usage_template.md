---
name: skill_usage_leaderboard
description: forge-harness skill call frequency tracker — flags skills unused for 4 weeks as deprecation candidates
updated: 2026-05-26
---

# forge-harness Skill Usage Leaderboard

> **Update**: Enter manually after harvest-loop runs, or aggregate from session notes
> **Deprecation threshold**: `last_used` older than 28 days (4 weeks) → `⚠️ Deprecation candidate` flag
> **Revival threshold**: Keep any deprecation candidate that has at least 1 external user request

## Leaderboard

| Skill | Last Used | Est. 30-day Calls | Status |
|---|---|:---:|---|
| harness-doctor | 2026-05-26 | 12+ | ✅ Core Active |
| context-doctor | 2026-05-26 | 8+ | ✅ Active |
| sim-conductor | 2026-05-26 | 6+ | ✅ Active |
| phantom-quench | 2026-05-26 | 3 | 🆕 New |
| agent-composer | 2026-05-24 | 5+ | ✅ Active |
| steel-quench | 2026-05-26 | 4+ | ✅ Active |
| harvest-loop | 2026-05-25 | 6+ | ✅ Active |
| field-harvest | 2026-05-25 | 4+ | ✅ Active |
| install-wizard | 2026-05-15 | 2 | 🟡 Low Frequency |
| install-doctor | 2026-05-15 | 2 | 🟡 Low Frequency |
| plugin-recommender | 2026-05-12 | 2 | 🟡 Low Frequency |
| verify-bidirectional | 2026-05-20 | 3 | 🟡 Low Frequency |
| sim-conductor | 2026-05-26 | 6+ | ✅ Active |
| hub-cc-pr-reviewer | 2026-05-18 | 3 | 🟡 Low Frequency |
| apex-review | 2026-05-10 | 1 | ⚠️ Under Observation |
| deep-clarify | 2026-05-26 | 0 | 🆕 New |
| frontier-digest | 2026-05-24 | 3 | 🟡 Low Frequency |
| cross-ecosystem-synergy-detection | 2026-05-08 | 1 | ⚠️ Under Observation |
| meta-prompt-builder | 2026-05-10 | 1 | ⚠️ Under Observation |
| asset-placement-gate | 2026-05-10 | 1 | ⚠️ Under Observation |
| marketplace-gate | 2026-05-10 | 1 | ⚠️ Under Observation |
| contention-layer | 2026-05-15 | 2 | 🟡 Low Frequency |

## Status Criteria

| Status | Condition |
|---|---|
| ✅ Core Active | 8+ calls in 30 days, or part of Three-Doctor Loop |
| ✅ Active | 3+ calls in 30 days |
| 🆕 New | Created less than 4 weeks ago |
| 🟡 Low Frequency | 1-2 calls in 30 days — monitoring |
| ⚠️ Under Observation | 1 or fewer calls in 30 days — review for deprecation |
| ❌ Deprecation Candidate | No calls in 28 days + no external usage |

## How to Update

At the end of each harvest-loop, record the skills used this session in this file:

```
Session date: YYYY-MM-DD
Skills used: harness-doctor, context-doctor, steel-quench, ...
```

### Recent Session Log

| Date | Skills Used |
|---|---|
| 2026-05-26 | harness-doctor, context-doctor, sim-conductor, phantom-quench, steel-quench, agent-composer, harvest-loop, deep-clarify(new), plan(new) |
| 2026-05-25 | harvest-loop, field-harvest, harness-doctor, verify-bidirectional |
| 2026-05-22 | steel-quench, sim-conductor, phantom-quench(new) |

---

<!-- hub-link footer (issue #69 item6) — generic, no operator-specific paths.
     Resolve {FH_ROOT} to your own forge-harness install path. -->
> **Source of truth**: this leaderboard is a *local* template. Skill definitions live in
> `{FH_ROOT}/plugins/{plugin}/skills/{skill-name}/SKILL.md`; session logs that feed it are written
> by `field-harvest` Mode B to `{FH_ROOT}/tracks/{project}/`. Update this file after each
> `harvest-loop` run — see `{FH_ROOT}/CLAUDE.md` Session Sync Protocol.
