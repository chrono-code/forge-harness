---
name: context-doctor-detail
description: Detail reference for context-doctor — per-step detection bash, audit report formats, Headroom tooling notes. Load when executing a specific step.
load: on-demand
---

# context-doctor — Detail Reference

> Load when executing a specific step. SKILL.md contains the diagnosis causes, per-step behavioral rules and thresholds, context hierarchy, compression pass principles, triggers/suppress mechanism, and Done When.

---

## §Step-Bash

### Step 1 — `.claudeignore` existence + project type detection

```bash
# Check whether .claudeignore exists in current project root
ls -la .claudeignore 2>/dev/null || echo "MISSING"
```

```bash
# Project type detection
ls package.json pyproject.toml build.gradle pom.xml 2>/dev/null | head -5
# Top-level directory list
ls -d */ 2>/dev/null | head -20
```

### Step 2 — Large file detection + warning format

```bash
# Detect files exceeding 500 lines (top 10)
find . -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.java" -o -name "*.kt" \
  | grep -v node_modules | grep -v .git \
  | xargs wc -l 2>/dev/null | sort -rn | head -11 | tail -10
```

When files exceeding 500 lines are found:

```
⚠️  Large file detected: {filename} ({N} lines)
    Full read cost: ~{token count} tokens
    Recommended: split reads with offset + limit
    Example: Read({filename}, offset=0, limit=100)  → proceed section by section
```

### Step 4 — weekly_audit lookup + check items block

```bash
# Check latest weekly_audit file
ls -1t tracks/_audit/weekly_audit_*.md 2>/dev/null | head -1
```

If found, suggest adding to the `## Check Items` or `## Token Efficiency` section:

```markdown
### Token Efficiency Check (context-doctor)
- [ ] .claudeignore is up to date
- [ ] 500+ line large files list and whether split reads are followed
- [ ] Whether burst pattern occurred (3+ full reads of same large file)
- [ ] Whether /clear was used after direction changes
```

### Step 5 — Hub context audit bash + report format

```bash
# CLAUDE.md line count
wc -l CLAUDE.md .claude/CLAUDE.md 2>/dev/null | sort -rn | head -3

# MEMORY.md line count (200-line limit)
wc -l memory/MEMORY.md 2>/dev/null

# memory/*.md files exceeding 30K
find memory -name "*.md" -size +30k 2>/dev/null | xargs wc -l | sort -rn | head -10

# SKILL.md files > 300 lines with no SKILL_detail.md (salience-splitter candidates)
find plugins -name "SKILL.md" 2>/dev/null | while read f; do
  lines=$(wc -l < "$f")
  detail=$(dirname "$f")/SKILL_detail.md
  [ "$lines" -gt 300 ] && [ ! -f "$detail" ] && echo "[salience-splitter candidate] $f ($lines lines)"
done
```

Audit result report format:
```
CC Context Audit Results
  CLAUDE.md: {N} lines {status}
  MEMORY.md: {N} lines / 200-line limit ({remaining} lines remaining)
  Bloated files ({30K+}):
    - {filename}: {N} lines → compression recommended
  Recommended actions: {summary}
```

---

## §CacheBoundary — prompt-caching evidence (Step 3.5, provisional)

Full citation for the Step 3.5 evidence line, kept out of the always-read SKILL.md body
per this file's own role (detail loads on-demand, SKILL.md stays lean).

**Source**: forge-harness GitHub issue #102 ("Frontier Digest Log"), 2026-07-27 daily comment,
itself citing:
- arXiv:2603.09619 — reported input:output token-ratio thresholds (>10:1 favors context/cache
  engineering over model-level optimization; >50:1, prefix caching dominates) and a
  41–80% cost reduction / 13–31% TTFT improvement range attributed to prompt caching.
- appscale.blog/en/blog/context-engineering-production-llm-agents-token-budget-compaction-2026
  — the ~7%→84% cache-hit-rate figure from cache-boundary control (fixed system prompt,
  dynamic content at the user-message end).

**Grounding status — UNCALIBRATED**: both URLs returned HTTP 403 when this session attempted
to fetch and verify the claimed spans directly (`WebFetch`), matching the same sandbox
network-policy limitation the daily frontier-digest routine logged on every run this week
(WebSearch fallback, no direct API access). The figures above are therefore traced only to
the digest comment's own text — a real, read GitHub source — and are **not** independently
re-verified against the original paper/post. Per the Instrument-Calibration doctrine
(`CLAUDE.md`), do not treat the 10:1 / 50:1 thresholds as a calibrated gate and do not cite
the ~7%→84% figure elsewhere without re-fetching from an environment with access first.

## §Headroom — Tooling (external option)

The compression pass in SKILL.md is tool-agnostic, but a concrete, reversible, local-first implementation exists: **Headroom** (`github.com/chopratejas/headroom`, open source, v0.22). It compresses tool outputs, logs, files, and RAG chunks before they reach the LLM — **vendor/coverage-reported** at 60–95% fewer tokens with the same answers ([The Register, 2026-05-31](https://www.theregister.com/ai-ml/2026/05/31/netflix-wiz-creates-app-to-slash-ai-bills-then-open-sources-it/5248702); figures unverified by FH). General token-efficiency basis: `../../../../knowledge/shared/harness-core/harness_frontier_diagnosis_2026-06-02.md`.

**Redundancy-category targeting** (its key insight — import this into the pass): the high-yield targets are *machine-generated, schema-repetitive* payloads, not prose. Prioritize compressing, in order:

1. **MCP tool outputs** — ~70% redundant JSON (most relevant to FH: heavy MCP sessions burn tokens here).
2. **Logs** — ~90% jettisonable.
3. **DB dumps / structured query output** — one schema, repeated rows.
4. **File trees / directory listings** — repeated path metadata.

Plain prose docs compress far less — spend the budget on the four categories above first.

**Integration surfaces** (all local, runtime-side — outside the FH repo, so for the user's local setup, not a hub asset):
- **Library** — `compress(messages)` inline (Python/TS).
- **Proxy** — `headroom proxy --port 8787`, zero code change, then point the client at it.
- **MCP server / agent-wrap** — wrap an MCP server or the agent CLI directly.

Caveats: v0.22 is still early — pilot before relying on it; compression carries a quality/accuracy tradeoff, so its local-first + reversible design (matching the reversibility rule in SKILL.md) is the safeguard. See the repo for exact config — do not assume flags.
