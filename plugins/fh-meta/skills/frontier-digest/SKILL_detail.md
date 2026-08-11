---
name: frontier-digest-detail
description: Detail reference for frontier-digest — collection bash per source, synthesis prompt, video-harvest tier detail, output/save/signal formats. Load when executing a specific step.
load: on-demand
---

# frontier-digest — Detail Reference

> Load when executing a specific step. SKILL.md contains triggers, engine priority, operator intake rules, mode selection, chaining logic, guards, and Done When.

---

## §Collection-Bash

> **Execution form — canonical (revised 2026-08-10, operator decision ⓑ).** The default runtime path
> is **WebFetch (+WebSearch) against the endpoints below** — not `curl`. Measured: **13 consecutive
> unattended runs** executed via WebFetch while this section documented only the curl form (the digest
> reported the mismatch on every run — spec debt N=13). `curl` requires an allowlist entry that a
> default install does not carry; the bash blocks below are kept as the **endpoint/parameter spec**
> (query shapes, filters, item caps, refresh rules — all still authoritative), and a run applies them
> through WebFetch on the same URLs. If an environment *does* allow the curl form, it is equivalent —
> the transport is not the contract, the endpoints and criteria are.
>
> **arXiv HTTP 429 is a separate item, not part of this revision**: it is a remote rate limit
> (N=11 consecutive, transport-independent). On 429: back off once, then fall back to per-item
> `https://arxiv.org/abs/{id}` reads; record `FAILED (429)`, never 0 items.

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
# Category-scoped since 2026-07-26. Unscoped `all:` full-text matching drifted off-axis: the 07-26 run
# returned 6/6 fresh-but-irrelevant papers (diffusion world models, embodied QA, medical-education
# gamification, RF fingerprinting). Freshness was fine; relevance was not — so the staleness rule below
# could not catch it.
for Q in "LLM agent" "agent harness" "context engineering"; do
  curl -s --max-time 8 \
    "https://export.arxiv.org/api/query?search_query=cat:cs.SE+AND+all:%22${Q// /+}%22&max_results=2&sortBy=submittedDate&sortOrder=descending"
done
```

Max 6 items.

**Refresh rule — two independent triggers (both required, neither sufficient alone):**
- **Staleness**: a query's newest hit is >6 months old, two runs in a row → replace the query.
- **Relevance** (added 2026-07-26): ≥4 of 6 returned items are off-axis (not about LLM agents /
  harnesses / agent evaluation / context engineering) → the query is drifting even though it is fresh.
  Staleness and relevance fail independently; a fresh-but-irrelevant query passes the staleness check.

**Before adopting a replacement query, calibrate it on a known pair** (`measurement-integrity-checklist.md
§Instrument-Calibration`): pick one paper FH would clearly want and one it clearly would not, and confirm
the new query returns the first and excludes the second. A query that cannot separate a pair you already
know the answer to is not filtering — it is generating.

> Calibration on record (2026-07-26, for the `cat:cs.SE` scoping above):
> **positive** = *"Understanding Agent-Reactive Bugs at the Model-Harness Boundary"* → `cs.SE`, returned.
> **negative** = *"MedGame: Storytelling Gamification … Medical Education"* → `cs.CL`/`cs.HC`, excluded.
> `cat:cs.MA` was tested against the same pair and **rejected** — it kept roughly half the off-axis items.

### TLDR AI (RSS)

```bash
curl -s --max-time 8 "https://tldr.tech/api/rss/ai"
```

Parse `<item>` → title + link. Max 5 items.

### The Batch — deeplearning.ai (HTML scraping)

```bash
curl -s --max-time 10 -L "https://www.deeplearning.ai/the-batch"
```

⚠️ **No trailing slash.** `…/the-batch/` returns **HTTP 308** redirecting to the slash-less path (verified
2026-07-26); the 07-26 automated run read that 308 as a dead endpoint and skipped the leg. The slash-less
URL returns 200 directly, so the leg no longer depends on redirect-following at all — which matters
because the fetch path is not always `curl -L` (a WebFetch-based run does not follow redirects the same
way). Second collection endpoint to churn, after GeekNews `/rss/news` (2026-06-20).

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
**[Title]** `<source-id>` — FH connection point in one sentence
<!-- source-id is MANDATORY (SKILL.md §Citation anchors): arXiv:NNNN.NNNNN | HN:<item-id> | <url>.
     No id → drop the item and count the drop. A recognized title is not a citation. -->


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
# Filename is FIXED — the cadence detector in CLAUDE.md globs
# tracks/_meta/frontier_digest_*.md, and scripts/frontier_digest_daily.sh writes this
# exact name. Underscores in the date; `date +%Y_%m_%d`, not %Y-%m-%d.
today = datetime.date.today().strftime("%Y_%m_%d")
name  = f"frontier_digest_{today}.md"

# Directory priority (the filename above does not change between them)
# 1. resolved FH install root  -> {FH}/tracks/_meta/
# 2. ~/.claude/forge-harness/tracks/_meta/
# 3. cwd                       -> ./tracks/_meta/
path = os.path.join(fh_root, "tracks", "_meta", name)
```

After saving: `✅ Saved: {path}`

> **Do not "simplify" this back to `digests/frontier_{today}.md`.** That was the documented path until
> 2026-08-11 and it produced **0** files (measured: `digests/` absent, `~/.claude/frontier-digest`
> absent, `frontier_2*.md` = 0 matches repo-wide) while 53 real digests sat in `tracks/_meta/` written
> by the daily runner. A digest saved outside this glob never satisfies the 7-day cadence check.

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
