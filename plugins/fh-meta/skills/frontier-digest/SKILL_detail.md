---
name: frontier-digest-detail
description: Detail reference for frontier-digest — collection bash per source, synthesis prompt, video-harvest tier detail, output/save/signal formats. Load when executing a specific step.
load: on-demand
---

# frontier-digest — Detail Reference

> Load when executing a specific step. SKILL.md contains triggers, engine priority, operator intake rules, mode selection, chaining logic, guards, and Done When.

---

## §Collection-Bash

### HackerNews (Algolia API)

```bash
for KW in "AI agent" "LLM harness" "Claude" "multi-agent" "context engineering"; do
  curl -s --max-time 8 \
    "https://hn.algolia.com/api/v1/search?query=$(echo $KW | tr ' ' '+')&tags=story&hitsPerPage=5&numericFilters=points>10"
done
```

Collection criteria: score > 10, keyword-relevant items only. Max 15 items.

### arxiv

```bash
# query refresh 2026-07-24: "AI software testing" (exact-phrase) went stale — newest hit was Sept 2024
# (07-24 run instrument note). Replaced with "LLM agent evaluation"; refresh again when a query's
# newest hit is >6 months old two runs in a row.
for Q in "multi-agent LLM" "LLM agent evaluation" "context engineering agents"; do
  curl -s --max-time 8 \
    "https://export.arxiv.org/api/query?search_query=all:${Q// /+}&max_results=2&sortBy=submittedDate&sortOrder=descending"
done
```

Max 6 items.

### TLDR AI (RSS)

```bash
curl -s --max-time 8 "https://tldr.tech/api/rss/ai"
```

Parse `<item>` → title + link. Max 5 items.

### The Batch — deeplearning.ai (HTML scraping)

```bash
curl -s --max-time 10 -L "https://www.deeplearning.ai/the-batch/"
```

Extract `"title":"..."` + `"slug":"issue-\d+"` pattern → URL: `https://www.deeplearning.ai/the-batch/{slug}/`. Max 5 items.

### GeekNews — news.hada.io (RSS)

```bash
curl -s --max-time 8 "https://news.hada.io/rss/news"
```

Korean dev-news aggregator (HN-equivalent), AI-heavy. **The `/rss/news` path serves an Atom feed** (`<feed>`/`<entry>`, NOT RSS `<item>` — verified 2026-06-20: 50 `<entry>` elements, 0 `<item>`). Parse `<entry>` → `<title>` + `<link href>`; keep AI/agent/LLM/harness-relevant items only. `/rss/news` is a *general* dev-news feed, so if 0 AI-relevant items remain after filtering, **drop GeekNews from this run's progress line rather than padding to 5**. Endpoint verified HTTP 200 (2026-06-20); `/rss/new` and `/rss/topics` 404 — use `/rss/news`. Max 5 items.

Report progress: `📡 HN 15 items · arxiv 5 items · TLDR 5 items · Batch 5 items · GeekNews 5 items collected`

---

## §Video-Harvest — Tier Detail (Step 0.5)

Resolve a *video-harvest* capability via the Sidecar Engine Resolution Protocol (`multi_model_sidecar_strategy.md`) — probe by **capability, not engine name**. A CLI that is a valid sidecar for other tasks is not automatically a video-harvest engine.

- **Tier 1 — a natively multimodal CLI that ingests the URL directly**: probe for one, then route to it (pre-EOL example invocation: `gemini --skip-trust -p "{URL}"` → timestamped summary). ⚠️ **the direct `gemini` CLI is being sunset (vendor EOL 2026-06-18)** — after that probe `agy` (the Antigravity router-shell successor, same class) or the Gemini API; see `multi_model_sidecar_strategy.md §Binary names churn`. A coding-agent CLI with **no native video/transcript access** (e.g. `codex`) cannot do this — it burns tokens, recovers only metadata (title), then asks for a pasted transcript; do not route video to it. Agentic router-shells (`agy`) get approval-mode first.
- **Tier 2** = router-shell / Gemini API (see the protocol).
- **Tier 3 — conditional fallback (not guaranteed)**: `yt-dlp --write-auto-subs --skip-download` then summarize the transcript — fine for talk-style content. **Probe the environment first**: `yt-dlp --version && python3 -c "import curl_cffi" && command -v ffmpeg` — Tier 3 needs all three (`yt-dlp`, `curl_cffi` impersonation target, `ffmpeg`), and the timedtext endpoint may return HTTP 429; if the probe fails, fall through rather than assuming it works.
- Unresolvable (cloud, no sidecar; or all tiers blocked) → operator summary remains the path, as today.

---

## §Synthesis-Prompt

> Angle-rule provenance: added 2026-07-24 (fh_signal 07-24 #3 — Bun-Rust methodology-angle silent
> drop; scope limited to collection-filtered items per Axis-2 challenger cost finding). Provenance
> lives here, outside the fenced prompt — the synthesis model gets only the bare rule.

### With Anthropic API

```
You are an AI harness engineering expert.
Analyze the collected external data below and extract insights
directly relevant to forge-harness (FH) operations and improvement.

FH Context:
- FH = AI collaboration meta-harness (skill · plugin · agent system)
- Core skills: steel-quench, harness-doctor, sim-conductor,
               agent-composer, apex-review
- Areas of interest: multi-agent orchestration, context engineering,
                     self-check gate, frontier cross-diagnosis

[Insert collected data]

Angle rule: an item you reject on its primary angle (e.g. substrate/model/runtime news),
if it passed collection filtering, gets ONE explicit second look before discarding: does it
carry a separate methodology/harness angle (orchestration pattern, workflow scale,
operational practice)? If yes, judge that angle on its own merits; if no, discard silently —
no output line about the discard, and never force an angle that isn't there.

Output format:
## This Week's Frontier Highlights (max 3)
**[Title]** — FH connection point in one sentence

## FH Immediate Application Candidates
2-3 specific ideas

## Warning Signals
Noise or excessive complexity alerts (if any)

Length: within 400 characters. Start directly with content, no preamble.
```

### WebSearch Mode (no API key)

Search directly with WebSearch tool, then synthesize in context:

```
Search: "AI agent harness 2025 site:news.ycombinator.com"
Search: "multi-agent LLM orchestration latest"
```

---

## §Output-Formats

### Step 3 — Conversation output

```markdown
## 🔭 FH Frontier Digest — YYYY-MM-DD

🔑 [Engine used: Claude Sonnet / WebSearch]

## This Week's Frontier Highlights
...

## FH Immediate Application Candidates
...

## Warning Signals
...

---
📊 Collected: HN N items · arxiv N items · TLDR N items · Batch N items | [View sources →]
```

### --save path priority

```python
# Save path priority
# 1. FH install path digests/
# 2. ~/.claude/frontier-digest/digests/
# 3. current cwd/digests/

path = f"digests/frontier_{today}.md"
```

After saving: `✅ Saved: {path}`

### Step 4 [3] — fh_signal file format

```markdown
---
date: YYYY-MM-DD
source: frontier-digest
engine: [Claude Sonnet / WebSearch]
---

# FH Improvement Signal — YYYY-MM-DD

## Sources
HN N items + arxiv N items collected

## Immediate Application Candidates
[Copy Step 2 "FH Immediate Application Candidates" items here]

## Processing Status
- [ ] Pending review
```

### Environment setup guide (first run, no API key)

```
🔑 No API key detected — running in WebSearch mode.

For more precise synthesis:
  Anthropic: export ANTHROPIC_API_KEY=sk-ant-xxx

To save key permanently (~/.cc_secrets pattern):
  echo 'export ANTHROPIC_API_KEY=sk-ant-xxx' > ~/.cc_secrets
  chmod 600 ~/.cc_secrets
```
