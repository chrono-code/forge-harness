---
name: install-wizard-detail
description: Detail reference for install-wizard — Mode D companion setup, detection bash, report/proposal formats, execution blocks, baseline bash. Load when executing a specific step.
load: on-demand
---

# install-wizard — Detail Reference

> Load when executing a specific step. SKILL.md contains key terms, execution modes, core principles, the step overview, behavioral rules per step, environment adaptation, cluster loading, and Done When.

---

## §Mode-D-Companion-Setup

Guide companion-store setup before Step 1 when Mode D (FH developer/researcher) is detected.

**Ask the backend question FIRST — do not assume a `*-be` git repo.** The companion store is a
*role* (durable private home for drafts · signals · handoffs · gitignored-session mirror), not a
fixed technology. FH emits the same artifact for every backend — **markdown output files** — so the
only thing that changes is where those files land. Branch on what the user already runs (see
`modes_and_value.md §Pluggable backends`):

```
You're developing FH itself — you need a durable PRIVATE companion store
alongside the public mirror. Where should research artifacts live?

Q: Do you already run a durable knowledge store?

 ┌─ Already garden knowledge in Obsidian
 │    → point the output path AT the vault. Obsidian IS markdown, so drafts
 │      are backlinked instantly — zero new infra, nothing to git init.
 │      Set BE_DIR=/path/to/vault/fh   (the sync target is just a folder)
 │      ⚠ use a NON-git vault subfolder: if BE_DIR lands inside a git-backed
 │        vault (Obsidian Git plugin), the sync script auto-commits private
 │        session-meta (incl. CLAUDE.local.md) into the vault's remote.
 │
 ├─ Run a queryable memory brain (gbrain / LLM-wiki)
 │    → your gbrain INGESTS the emitted markdown (`gbrain ingest <path>`).
 │      Set BE_DIR=/path/to/staging   (same env var as the other backends — FH
 │      writes markdown there; your brain then `gbrain ingest`s that path).
 │      (A deeper FH→gbrain MCP integration is a future candidate — not wired today.)
 │
 └─ None of the above (DEFAULT) → a private *-be git repo
      Quick setup (remote-backed):
        gh repo create {org}/{hub}-be --private
        git clone https://github.com/{org}/{hub}-be ~/path/to/{hub}-be
        mkdir -p {hub}-be/{paper-drafts,paper-signals,digests,handoff}
      Local-only variant (no GitHub — data never leaves the machine):
        git init ~/path/to/{hub}-be      # no remote needed
        mkdir -p ~/path/to/{hub}-be/{paper-drafts,paper-signals,digests,handoff}
        → the sync script detects the missing upstream and skips push
          automatically; local git history carries durability.

Any store name/path works — set BE_DIR (and HUB_DIR) env vars to your paths.

Invariant across ALL backends:
  · methodology stays in the public mirror (single-source guard) — NEVER copied
    into the store; the store holds only OUTPUTS, never a rule copy
  · knowledge/shared/ drafts stay local via .gitignore glob
  · push/ingest snapshots explicitly — never auto-push
  · handoff/ files bridge cloud session → local without exposing content
```

**Queryable-wiki scaffold (all backends — the store is a wiki, not a dump):** after BE_DIR is set,
scaffold so the agent can *read the store well* (this is the recommended form's Observability answer —
the agent queries the wiki, vs a visual graph). `INDEX.md` here is the **`CATALOG.md` read-first pattern
applied to the store** (same semantics; named INDEX, not CATALOG, only to avoid two `CATALOG.md` across
the public mirror + the private store):

```bash
# 1. INDEX.md — wiki home (read FIRST at session start). The section MAP is static (low rot);
#    the volatile "latest" pointers are DERIVED at read time, never hand-maintained (a stale
#    "latest" mis-routes the very read it exists to guide — worse than none).
cat > "$BE_DIR/INDEX.md" <<'IDX'
# <store> — Wiki Home (READ ME FIRST at session start)
> Read this store AS a wiki (relevance-query the right section), not pull + file-dump.
## How to read at session start
1. This INDEX first → pick the section for the session intent.
2. DERIVE the latest pointers live (do NOT trust a hand-written "latest" line):
     ls -t paper-signals/ handoff/ digests/ 2>/dev/null | head
   then open anything newer than the session card (card=pointer, store commit=truth).
## Sections (static map)
| Section | Holds | Read when |
|---|---|---|
| paper-signals/ | completed results + research signals | any measurement (check for a prior result first) |
| handoff/ | cross-machine/session bridges (entry points, run recipes) | resuming work started elsewhere |
| digests/ | frontier digests (cadence source) | cadence/frontier scan |
| (add your sections) | | |
IDX

# 2. session-start read wiring → IDEMPOTENT append to the user's CLAUDE.local.md (grep-guarded
#    so a re-run never duplicates it; this is a REAL write, not a note):
WIRING="At session start: read \$BE_DIR/INDEX.md first; then ls -t paper-signals/ handoff/ digests/ and open anything newer than the session card (card=pointer, store commit=truth) — not only handoffs."
grep -qF "read \$BE_DIR/INDEX.md first" "$HUB_DIR/CLAUDE.local.md" 2>/dev/null \
  || printf '\n## Companion-store session-start read\n%s\n' "$WIRING" >> "$HUB_DIR/CLAUDE.local.md"

# 3. MECHANICAL FLOOR over that prose — register the SessionStart hooks (REQUIRED, not optional).
#    WHY: step 2 writes an INSTRUCTION into CLAUDE.local.md. An instruction is salience: on task-first
#    entry (the user's first message is a task, so the onboarding menu is correctly suppressed) or on a
#    weaker tier, it silently does not fire and the session runs on stale local state. The two hooks
#    below fire BEFORE turn 0 regardless of what the user types.
#      - fh_session_load.sh   → companion freshness (this section's own load)
#      - fh_env_delta_scan.sh → undeployed-sibling-repo discovery (CLAUDE.md claim ②; rated
#                               PARTIAL/THEATER by the 2026-07-06 three-family audit while prose-only)
#    Registration lives in the GITIGNORED .claude/settings.local.json — BE_DIR is an operator-private
#    path and must never land in the project-shared settings.json. Idempotent: re-running replaces, never dups.
#    Measured miss 2026-07-30 (n=2, a freshly installed second machine): neither hook was registered,
#    so the Mode D load ran only because the operator happened to open with a greeting. A task-first
#    first message would have skipped it entirely — on Opus, not merely on a weak tier.
if [ -n "${BE_DIR:-}" ] && [ -d "$HUB_DIR/scripts" ]; then
  # The real $BE_DIR is passed IN and baked into the command — never a "<your-store>" placeholder
  # for the user to swap later. A placeholder written into a config file is a hook that reports
  # "registered" and then silently resolves to a nonexistent path; the Sonnet target-tier sim
  # (2026-07-30) named exactly this failure — the script prints success, the operator stops, the
  # hook is dead. If a value must be substituted, substitute it at write time or do not write.
  python3 - "$HUB_DIR" "$BE_DIR" <<'PY'
import json, os, sys, collections
hub, be = sys.argv[1], sys.argv[2]
p = os.path.join(hub, ".claude", "settings.local.json")
d = collections.OrderedDict()
if os.path.exists(p):
    with open(p) as fh:
        d = json.load(fh, object_pairs_hook=collections.OrderedDict)
cmd = lambda s: {"type": "command",
                 "command": f'BE_DIR="{be}" bash "$CLAUDE_PROJECT_DIR/scripts/{s}"',
                 "timeout": 20}
if os.path.exists(p):   # back up before rewriting someone's config; a traceback mid-write truncates
    import shutil; shutil.copy2(p, p + ".prewizard")
hooks = d.setdefault("hooks", collections.OrderedDict())
# Filter at HOOK level, not GROUP level: a user hook sharing a group with an FH hook would otherwise
# be deleted with the group (cross-family review 2026-07-30 reproduced that loss).
FH_HOOKS = ("fh_session_load.sh", "fh_env_delta_scan.sh")
existing = []
for g in hooks.get("SessionStart", []):
    survivors = [h for h in g.get("hooks", [])
                 if not any(n in h.get("command", "") for n in FH_HOOKS)]
    if survivors:
        g = dict(g); g["hooks"] = survivors; existing.append(g)
hooks["SessionStart"] = existing + [
    {"matcher": "", "hooks": [cmd("fh_session_load.sh"), cmd("fh_env_delta_scan.sh")]}]
with open(p, "w") as fh:
    json.dump(d, fh, indent=2, ensure_ascii=False); fh.write("\n")
print("SessionStart hooks registered ->", p, "(backup: .prewizard)")
PY
  # VERIFY by running it once — a registration that was never executed is not a floor.
  # Expected: a "companion-store freshness" line on stdout. If it prints nothing, BE_DIR is wrong.
  BE_DIR="$BE_DIR" bash "$HUB_DIR/scripts/fh_session_load.sh" | head -3
fi
```

> **Known-pair check before calling this done** (per `measurement-integrity-checklist.md
> §Instrument-Calibration`) — **run both legs, do not copy this verdict**:
> - **known-positive** — `BE_DIR` set → a `companion-store freshness` line prints.
> - **known-negative** — `BE_DIR` unset → **no companion block prints** and the script exits 0.
>   It is *not* fully silent: the frontier-digest section runs above the Mode-D guard and speaks to
>   every user about their own local digest. That is intended. An earlier draft of this note claimed
>   the negative leg was silent and made that a ship-blocker; running it showed 171 bytes of correct
>   frontier output — the note was written without executing the check it prescribed.
> If the negative leg prints anything referencing the **companion store**, do not ship.

- **Raw / Wiki / Conversation ingest axis** (`sync_push_protocols.md`): classify each artifact by
  processing stage — Raw (unprocessed capture) → stays raw; Wiki (distilled + `[[linked]]`) → the
  compounding layer; Conversation (dialogue/decision log). The Raw→Wiki distill is where linking earns
  its keep. Mention it so the store accumulates as a wiki, not a heap.
- **Backend note**: for an **Obsidian** backend the graph view is the *visual* observability surface
  (free for that backend); for the recommended **git `*-be`** form, observability is the agent querying
  INDEX + sections (no visualization needed). gbrain ingests the same markdown.
- **Salience → mechanical (corrected 2026-07-30)**: this used to read *"the session-start read is prose
  (no SessionStart hook) — accepted limitation; revisit if a target-tier sim measures a miss."* **Both
  halves were wrong by then.** The hook exists (`scripts/fh_session_load.sh`, shipped 2026-07-05), and
  the revisit-trigger has fired: a freshly installed second machine ran with **neither** SessionStart
  hook registered, on Opus — the load fired only because that session happened to open with a greeting
  instead of a task. So step 3 above **registers the hooks**; the CLAUDE.local.md prose stays as the
  human-readable layer *over* that floor, never as the floor itself.
  **Residual (named, not closed)**: registration lives in the gitignored `settings.local.json`, so a
  user who re-clones the hub without re-running the wizard silently loses it again — the honest
  backstop is `install-doctor`'s check item, not the wizard alone.


---

## §Token-Injection

**Method A — One-time injection per session (recommended):**
```bash
# In terminal before starting CC
export GH_TOKEN=ghp_xxxx        # GitHub Personal Access Token
export GITHUB_TOKEN=$GH_TOKEN   # Some CLIs read GITHUB_TOKEN
claude                           # gh / git commands will automatically use token afterward
```

**Method B — Permanent local secret file:**
```bash
mkdir -p ~/.cc_secrets
echo 'export GH_TOKEN=ghp_xxxx' >> ~/.cc_secrets/tokens.env
chmod 600 ~/.cc_secrets/tokens.env
echo 'source ~/.cc_secrets/tokens.env' >> ~/.zshrc
```

> `~/.cc_secrets/` is a local-only path outside git management — not a commit target for team repos.

---

## §Step0-Detection-Bash

Environment detection procedures that CC executes automatically. No need for users to run manually.

```bash
# Prompt injection pre-flight: scan config AND the project's AI-instruction surfaces — CLAUDE.md,
# AGENTS.md, .claude/rules/* — which are the higher-risk vectors in an unknown repo (not just shell/settings).
# Injection-SPECIFIC patterns only (override/exfil), since instruction files legitimately carry directives;
# advisory (recommend manual review), never an auto-block.
if grep -rIE "ignore (all )?previous|disregard (the )?above|exfiltrat|^# CLAUDE:|^# AI:|<instructions>" \
     ~/.zshrc .claude/settings.json CLAUDE.md AGENTS.md .claude/rules/ 2>/dev/null | grep -q .; then
  echo "⚠️  AI-instruction / override pattern detected in config or instruction files — injection risk in an unknown repo. Review the listed files manually before proceeding."; fi

# FH location
echo "FH_DIR=${FH_DIR:-not set}"
echo "CC_HUB_DIR=${CC_HUB_DIR:-not set}"

# cwd project info
basename "$(pwd)"
ls .claude/ 2>/dev/null

# CC settings (handle both dict and list for plugins).
# Split existence from parseability FIRST. The old `cat file | python3 … || echo "not found"` read
# $? from python, so a CORRUPT settings.json printed "settings.json not found" — the wizard would
# then happily create a fresh one and silently clobber the user's real (broken) config.
if [ ! -f .claude/settings.json ]; then
  echo "settings.json: ABSENT"
else
  python3 - <<'PY' || echo "settings.json: UNPARSEABLE (present but unreadable — NOT the same as absent; do NOT overwrite, ask the user)"
import json, sys
try:
    d = json.load(open('.claude/settings.json'))
except Exception as e:
    print(f'  parse error: {e}', file=sys.stderr); sys.exit(2)
p = d.get('plugins', {})
print('settings.json: OK — plugins:', list(p.keys()) if isinstance(p, dict) else p)
PY
fi

# MCP plugin connection status
python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.claude.json'))); print('MCP:', list(d.get('mcpServers',{}).keys()))" 2>/dev/null || echo "MCP config not found"

# zshrc hook status
grep -q "fh_audit_check.zsh" ~/.zshrc 2>/dev/null && echo "zshrc hook: present" || echo "zshrc hook: absent"

# Framework detection (optional) — only used to look for a matching OPTIONAL domain pattern pack.
# Generic: capture the framework name; the pattern-pack path is derived as {framework}_patterns.md.
# No pattern pack ships by default — this is a user-supplied extension point, absence is the normal state.
FRAMEWORK=""
for fw in streamlit django fastapi flask; do
  if grep -qi "$fw" requirements.txt pyproject.toml 2>/dev/null; then FRAMEWORK="$fw"; echo "Framework: $fw detected"; break; fi
done

# Local LLM runtime (optional) — gates the conditional local-offload recommendation in Step 1.
# Ollama default :11434, LM Studio default :1234. Absence is the normal state (no offload item surfaced).
# Confirm the RESPONSE SHAPE, not just any HTTP 200 — Ollama /api/tags returns {"models":...},
# LM Studio /v1/models returns {"data":...}; this avoids a non-LLM service squatting the port.
for url in http://localhost:11434/api/tags http://localhost:1234/v1/models; do
  if curl -sf -m 1 "$url" 2>/dev/null | grep -q '"models"\|"data"'; then
    echo "Local LLM runtime: detected ($url)"; break
  fi
done
```

**Bootstrap guidance when FH_DIR is not set (stop immediately in Step 0):**
```
⚠️  FH_DIR not set — install FH first then rerun.

  1. Clone FH repo:
     git clone https://github.com/chrono-meta/forge-harness ~/forge-harness

  2. Set environment variables:
     export FH_DIR=~/forge-harness
     export CC_HUB_DIR=$FH_DIR   # FH hub dir (holds tracks/_audit for the weekly-audit mtime check);
                                 # equals FH_DIR unless you run a separate hub clone

  3. Install FH plugin in CC:
     Settings → Plugins → Add → {FH_DIR}/plugins/fh-meta

  4. Rerun /install-wizard after completion
```

---

## §Env-Card-Format

Output detection results as **environment card**. If a framework was detected AND you maintain a matching
optional domain pattern pack, reference it (none ship by default — absence is normal, never a gap):
```
📌 {FRAMEWORK} project detected → optional domain pattern pack check
   {CC_HUB_DIR}/knowledge/shared/{FRAMEWORK}_patterns.md loaded (only if you supplied it; not shipped by default)
   If absent: skip silently — no pack is the expected default state.
```

```
install-wizard — Environment Detection
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Project:      {cwd name}
  FH_DIR:       {path or not set}
  CC Hub:       {CC_HUB_DIR or not set}
  Plugins:      {installed plugin list}
  zshrc hook:   {present/absent}
  Local LLM:    {runtime + url if detected — omit this row when none}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## §Step0C-Integration

**Illustrative single-run measurements** (n=1 per project, `--dry-run` verified — not benchmarks; your numbers will differ):

| Project type | Example | Total volume | Reduction | Main cause |
|---|---|---|---|---|
| QA strategy platform (domain-specialized complete) | Project A | 324 lines | **14%** (46 lines) | Duplicate meta operation rules |
| Mobile QA automation framework | Project B | 2,448 lines (constant) | **32%** (~790 lines) | 2 unremoved duplicate files post-install |

Token savings: Project A ~0.5K/session, Project B ~15~20K/session

* QA strategy platform level = CLAUDE.md 200~400 lines, 5~10 rules files. Mobile QA automation level = 7+ rule files, 2,000+ lines of constant context.
* Check your own project numbers directly with `/install-wizard --dry-run`. (These numbers are from actual single measurements and may vary by environment.)

**How to read**: FH does not touch domain-specific rules (code guides, domain knowledge).
Reduction targets are only meta operation rules (PR procedures, commit guides, FH path duplicates, etc.).

**Detection bash:**

```bash
# Detect existing harness scale.
# `| wc -l || echo 0` is a conditional disarm, not a harmless idiom: with `set -o pipefail` active
# (which the caller's shell may well have) a failing upstream stage makes the pipeline exit non-zero
# AFTER wc has already printed its count, so the fallback appends a SECOND line, the value becomes
# "0\n0", and the `-ge 3` test below dies with "integer expression expected" — on stderr only —
# leaving the guard silent. Measured both directions 2026-08-12: single line without pipefail,
# two lines with it. Sanitize instead of falling back.
CLAUDE_MD_LINES=$(wc -l < CLAUDE.md 2>/dev/null || true)
RULES_COUNT=$(ls .claude/rules/*.md 2>/dev/null | wc -l || true)
# head -n1 FIRST, then strip: `tr -dc '0-9'` alone would fuse a two-line "12\n0" into "120".
CLAUDE_MD_LINES=$(printf '%s\n' "$CLAUDE_MD_LINES" | head -n1 | tr -dc '0-9'); CLAUDE_MD_LINES=${CLAUDE_MD_LINES:-0}
RULES_COUNT=$(printf '%s\n' "$RULES_COUNT" | head -n1 | tr -dc '0-9');         RULES_COUNT=${RULES_COUNT:-0}

echo "CLAUDE.md: ${CLAUDE_MD_LINES} lines"
echo ".claude/rules/: ${RULES_COUNT} files"

# Existing harness detected: CLAUDE.md > 50 lines OR 3+ rules
if [ "$CLAUDE_MD_LINES" -gt 50 ] || [ "$RULES_COUNT" -ge 3 ]; then
  echo "STATUS: Existing harness detected → proceeding with integration analysis"
else
  echo "STATUS: New install → move to Step 1"
fi
```

**Integration analysis output format:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Existing Harness Integration Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CLAUDE.md current:    {X} lines
  .claude/rules/:       {N} files

  Duplicates (FH-covered): {A} items → can be removed
  FH-delegatable:          {B} items → replaceable with skills
  Project-specific:        {C} items → keep

  Expected after integration: CLAUDE.md {X} → {Y} lines ({Z}% reduction)
  Token savings estimate:     ~{W}K tokens/session saved
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Show integration plan?
  Y — Per-item removal/delegation detailed proposal (applied in subsequent Step 1)
  N — Continue with add-only approach (keep existing rules)
  S — Skip for now, move directly to Step 1. Can reanalyze later with /install-wizard --dry-run
```

---

## §Step1-Checks

Auto-check the following items based on detected environment. Each item classified as PASS / MISS / FAIL.

| Check item | Criteria | Verification method |
|---|---|---|
| `.claudeignore` | Existence | `ls .claudeignore` |
| `local_fh_context.md` | Existence in `.claude/rules/` | `ls .claude/rules/local_fh_context.md` |
| `zshrc hook` | Contains `fh_audit_check.zsh` source line | `grep fh_audit_check.zsh ~/.zshrc` |
| `weekly_audit` latest | Within 7 days | CC_HUB_DIR/tracks/_audit/ mtime |
| `sentinel` setup | `~/.cc_sentinels/` exists | `ls ~/.cc_sentinels/` |
| FH plugin install | `installed_plugins.json` has `fh-meta` entry | `python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.claude/plugins/installed_plugins.json'))); print([k for k in d.get('plugins',{}) if 'fh-meta' in k])"` |
| `.git/info/exclude` | Personal files excluded | grep local_fh_context .git/info/exclude |
| MCP plugin | ~/.claude.json mcpServers contains entry | `python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.claude.json'))); print(list(d.get('mcpServers',{}).keys()))"` |
| `deep-insight plugin` | settings.json plugins contains deep-insight | `grep -r "deep-insight" .claude/settings.json 2>/dev/null` |
| `fh_env_context.jsonc` | `.claude/rules/fh_env_context.jsonc` exists | `ls .claude/rules/fh_env_context.jsonc` |
| `phantom-gate` | **(Python + AI-output projects only)** `phantom-gate` present in `requirements.txt` / `pyproject.toml` | `grep "phantom.gate" requirements.txt pyproject.toml 2>/dev/null` |
| `Domain pattern pack applied` | (optional — only when a `{framework}_patterns.md` pack is present; none ship by default) framework-specific pattern checks | `knowledge/shared/{framework}_patterns.md` check (skip if file absent — the normal default) |
| `local-LLM offload` | (optional — only when Step 0 detected a local LLM runtime) recommend local-model offload tooling, recommend-only | route to `/plugin-recommender` (no install performed here; skip silently if no runtime detected) |

---

## §Step2-Formats

**Diagnosis report + proposal list:**

```
install-wizard — Diagnosis Results ({score}/100)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ PASS  .claudeignore exists
⚠️  MISS  local_fh_context.md absent
⚠️  MISS  zshrc hook absent
❌ FAIL  weekly_audit 12 days elapsed
✅ PASS  FH plugin installed
⚠️  MISS  MCP plugin absent
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Proposal list (per-item approval required before execution):

  [1] Install local_fh_context.md — FH skill auto-recognition
  [2] Add zshrc hook — periodic audit notification on terminal start
  [3] Run weekly_audit immediately — call /harvest-loop (lightweight mode)
  [4] Initialize ~/.cc_sentinels/ — project audit tracking
  [5] Install fh-meta plugin — activate all FH skills (if FH plugin MISS)
      AI executes automatically via Bash — no manual terminal input needed:
        claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
        claude plugin install -s user fh-meta@forge-harness
      CC restart required after completion for skills to appear in /skills list
  [6] Add MCP plugin — activate integrations (if MCP plugin MISS)
      Run: claude mcp add <your-mcp-plugin> -- npx -y <your-mcp-plugin>
      CC restart required after completion
  [7] (Optional — field plugin, NOT required) Install deep-insight — adds the field's domain personas to sim-conductor
      deep-insight is a private/field marketplace plugin. sim-conductor already ships the built-in
      user-mastery spectrum (beginner · main-player · expert · challenger), so multi-persona simulation
      works WITHOUT it. If you have access: Settings → Plugins → Add → <your deep-insight path>.
      If not: skip — sim-conductor falls back to the built-in spectrum agents (no capability lost).
  [8] Create fh_env_context.jsonc — org/network/Git environment context file (if fh_env_context.jsonc MISS)
      Copy: {FH_DIR}/templates/fh_env_context.jsonc → .claude/rules/fh_env_context.jsonc
      Then manually update with actual values for org name, Jira URL, environment status, etc.
      Effect: Each skill references common environment context → eliminate individual setting duplication
  [9] Install phantom-gate — AI output hallucination detection (Python + AI-output projects only, if MISS)
      Run: pip install git+https://github.com/chrono-meta/phantom-gate.git
      Usage: phantom-gate scan output.txt / phantom-gate scan . --project
      Detectors: M1 (phantom claims) · M2 (self-reference loops) · M3 (unvalidated external-dep claims) · M4 (temporal) · M5 (cross-file version mismatch)
      Skip condition: non-Python project OR no AI-generated output in pipeline


Each item: Y (approve) / N (skip) / L (later) / A (approve all)
```

**cross-install detection output format:**
```
🔍 cross-install detected: {skill name} ({trigger keywords})
   → agent-composer mapping gap confirmed
   → auto-update proposal included in Step 3
```

**`--dry-run` exit message:**
```
install-wizard [dry-run] — Analysis complete ({score}/100)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MISS/FAIL items: {N} — rerun /install-wizard to execute
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## §Step3-Execution

**Action preview example (local_fh_context.md install):**
```
▶ [1] Install local_fh_context.md
  Copy: {FH_DIR}/templates/local_fh_context.md
    →   .claude/rules/local_fh_context.md
  Exclude: add pattern to .git/info/exclude
  Execute? (Y/N):
```

**FH plugin auto-install execution block** — when FH plugin is MISS, execute via Bash (no manual input required):

```bash
# Step A: register marketplace (idempotent — "already on disk" is OK)
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git 2>&1

# Step B: install plugin
claude plugin install -s user fh-meta@forge-harness 2>&1
```

**Error handling:**

| Output | Meaning | Action |
|---|---|---|
| `✔ Marketplace ... already on disk` | Already registered | Continue to Step B |
| `✔ Successfully installed` | Done | Report success, remind CC restart |
| `Plugin "fh-meta" not found` | Marketplace cache stale | Run `claude plugin marketplace update forge-harness` then retry Step B |
| Any other error | Unknown failure | Report error verbatim, ask user to retry manually |

**Output format on success:**
```
▶ [5] Install fh-meta plugin
  ✅ Marketplace: forge-harness registered
  ✅ Plugin: fh-meta@forge-harness installed (scope: user)
  ⚠️  CC restart needed — skills will appear in /skills after restart
```

**agent-composer mapping update** (when skills were added via cross-install):

For skills with confirmed agent-composer mapping gaps from Step 2 cross-install detection,
propose adding rows to `agent-composer/SKILL.md` Step 1 mapping table in this format:

```
| {skill name} related task | {skill name} (S) | — |
```

> **Verify this block against a temp file, never against `~/.zshrc`.** Set `ZSHRC_TARGET` to a
> scratch path and run the five arms: FH_DIR unset → rc=1, nothing written · CC_HUB_DIR unset →
> rc=1, nothing written · `$FH_DIR` without the script → ABORT, nothing written · consent absent →
> SKIPPED, nothing written · consent Y with both vars → block appended with values **substituted**
> and `$HOME`/`$FH_DIR` left literal, then `zsh -c 'source <temp>'` exits 0. Re-running must not
> duplicate the block. **Beware a contaminated control**: if your own shell already exports
> `FH_DIR`, the "unset" arm is not actually negative — isolate with `env -u FH_DIR`. That mistake
> made the first pass of this very verification report a false PASS.

Output preview before execution:
```
▶ agent-composer mapping update
  Add to: agent-composer/SKILL.md Step 1 table
    | {skill name} related task | {skill name} (S) | — |
  Execute? (Y/N):
```

---

## §Step4-Baseline-Bash

```bash
# zshrc hook — preview then confirm. The wizard is AI-mediated: SHOW the user the exact block
# below and ask in-chat "Append this to ~/.zshrc? (Y/N)" BEFORE running the append.
#
# TWO defects were fixed here (2026-08-12), both of which corrupt every future shell:
#  (1) The heredoc was QUOTED (<< 'EOF'), so the literal text `{FH_DIR}` was written to ~/.zshrc.
#      The resulting `source "$FH_DIR/templates/fh_audit_check.zsh"` then resolved to
#      `{FH_DIR}/templates/...` and every subsequent shell start failed with
#      `no such file or directory` (rc=127, reproduced in a sandbox against a temp file).
#      Fix: unquoted heredoc so FH_DIR/CC_HUB_DIR expand AT WRITE TIME, with `\$HOME` and
#      `\$FH_DIR` escaped so THOSE stay literal and resolve at shell-start.
#  (2) The consent gate was a COMMENT ("run only after an explicit in-chat Y"). A comment does
#      not gate anything — pasted or scripted, the block appended unconditionally. It is now a
#      real conditional on FH_WIZARD_ZSHRC_CONSENT, default N (fail-closed).
#
# Set FH_WIZARD_ZSHRC_CONSENT=Y only after the user answers Y in chat.
ZSHRC="${ZSHRC_TARGET:-$HOME/.zshrc}"
: "${FH_DIR:?FH_DIR is unset — refusing to write a broken source line into $ZSHRC}"
: "${CC_HUB_DIR:?CC_HUB_DIR is unset — refusing to write an incomplete block into $ZSHRC}"
if [ ! -f "$FH_DIR/templates/fh_audit_check.zsh" ]; then
  echo "ABORT: \$FH_DIR/templates/fh_audit_check.zsh does not exist — would wire a dead source line"
elif [ "${FH_WIZARD_ZSHRC_CONSENT:-N}" != "Y" ]; then
  echo "zshrc hook: SKIPPED (no explicit Y) — nothing written"
elif grep -q "fh_audit_check.zsh" "$ZSHRC" 2>/dev/null; then
  echo "zshrc hook: already present — no change"
else
  cat >> "$ZSHRC" <<EOF
export FH_DIR="$FH_DIR"
export CC_HUB_DIR="$CC_HUB_DIR"
export CC_SENTINELS_DIR="\$HOME/.cc_sentinels"
source "\$FH_DIR/templates/fh_audit_check.zsh"
EOF
  echo "zshrc hook: appended"
fi
# On N: do NOT append; record the decline and state its consequence in one line —
#   echo "zshrc_hook" >> "$HOME/.cc_sentinels/{project}_wizard_declined"
#   "declined — shell-side audit nag off; only session-start prose detection remains."

# Node floor check hook — ALL users, not Mode D only. Source of truth = the tracked snippet
# templates/settings.SessionStart.snippet.json (`project_settings_json` key). Registration itself
# cannot be tracked (every .claude/settings*.json path is gitignored), so the wizard is what wires it.
#
# ⚠️ Y/N GATE (added 2026-08-10 — decline-integrity sim finding D): this block WRITES to
# .claude/settings.json, so it gets the same explicit in-chat gate as the 4-axis block below —
# it was the only settings-writing step without one (structural asymmetry, and a violation of this
# skill's own Per-item-approval principle). Ask BEFORE running the python:
#   "Register the SessionStart hooks (floor check · env-delta · companion load) into
#    .claude/settings.json? (Y/N)
#    On N: you get no turn-0 mechanical signal — floor gaps, env changes and companion freshness
#    fall back to session prose, and some of FH's intended features will not run as designed.
#    The decline is recorded and a one-line per-session reminder will note the state
#    (re-run /install-wizard to change it; mute deliberately via
#    ~/.cc_sentinels/{project}_wizard_reminder_muted)."
# On N: echo "sessionstart_hooks" >> "$HOME/.cc_sentinels/{project}_wizard_declined" and SKIP the
# python below entirely. "Must not be skipped" in the earlier wording meant the wizard must not
# FORGET this step — it never licensed skipping the user's consent.
# NPM-INSTALL PRECONDITION: this block reads the snippet from disk, so both it and
# scripts/fh_node_check.sh must be in package.json `files[]`. They are (added 2026-07-30 after
# scripts/package_coverage_check.sh caught the omission — without it an npm-installed wizard hit
# FileNotFoundError here and registered nothing while reporting success upstream).
python3 - "$FH_DIR" <<'PY'
import json, os, sys, glob, collections, re, shutil
hub = sys.argv[1]
target = os.path.join(hub, ".claude", "settings.json")

# DISCOVER every shipped snippet, do not name one. Hardcoding a single snippet path is why the
# compaction hooks shipped unwired while their own README recited the shipping-is-not-wiring lesson
# (high review, 2026-08-08 — and PreToolUse was already sitting in the same hole, so N=2).
# A new templates/settings.*.snippet.json is picked up with zero edits here: generation, not detection.
snippets = sorted(glob.glob(os.path.join(hub, "templates", "settings.*.snippet.json")))
if not snippets:
    # exit 1, NOT 0. The pre-rewrite code raised FileNotFoundError here, and that loud failure is what
    # made a broken npm `files[]` detectable — the comment above records it happening for real once.
    # The first rewrite replaced it with a quiet exit 0, i.e. it deleted the detector while keeping the
    # bug (high re-review 2026-08-08 #1). Zero snippets means zero hooks registered; that is never a
    # success, and every other zero-registration path below already exits 1.
    print("NO SNIPPETS under templates/settings.*.snippet.json — zero hooks registered.")
    print("  → package `files[]` may have dropped templates/, or this is not an FH hub. NOT a success.")
    raise SystemExit(1)

d = collections.OrderedDict()
if os.path.exists(target):
    d = json.load(open(target), object_pairs_hook=collections.OrderedDict)
    shutil.copy2(target, target + ".prewizard")          # back up before rewriting
hooks = d.setdefault("hooks", collections.OrderedDict())

def fh_keys(entry_groups):
    """FH script basenames this snippet owns — the replace key is DERIVED from the snippet's own
    commands, never hardcoded, so it cannot drift from what is actually being installed."""
    # Key on the snippet's own PATH FORM (scripts/<name>.sh), not a bare basename. A bare basename
    # made the survivor filter delete a user's own hook that merely shared a filename — e.g. their
    # ~/tools/compaction_probe.sh — which is the exact loss the hook-level merge exists to prevent,
    # reintroduced through key derivation (high re-review 2026-08-08 #2).
    keys = set()
    for g in entry_groups:
        for h in g.get("hooks", []):
            for m in re.findall(r'((?:[A-Za-z0-9_\-]+/)*scripts/[A-Za-z0-9_\-]+\.sh)', h.get("command", "")):
                keys.add("scripts/" + m.rsplit("scripts/", 1)[1])
    return keys

registered, bad_schema, intended = [], [], {}
for snip in snippets:
    try:
        blob = json.load(open(snip))
    except Exception as e:
        print("SKIP (unparsable):", os.path.basename(snip), e); bad_schema.append(snip); continue
    proj = (blob.get("project_settings_json") or {}).get("hooks") or {}
    if not proj:
        # settings_local_json_MODE_D_ONLY entries carry private paths — never auto-written here.
        print("SKIP (no project_settings_json):", os.path.basename(snip)); bad_schema.append(snip); continue
    for event, entry in proj.items():
        # Shape-validate before touching the user's file. A valid-JSON / invalid-SCHEMA snippet used
        # to be written anyway and reported as success, then detonate on the NEXT run inside the
        # survivor filter — far from the snippet that caused it (lanes BS-*, LT-*).
        if not isinstance(entry, list) or not all(
                isinstance(g, dict) and isinstance(g.get("hooks"), list) for g in entry):
            print("SKIP (bad schema):", os.path.basename(snip), event); bad_schema.append(snip); continue
        keys = fh_keys(entry)
        if not keys:
            print("SKIP (no FH script in commands):", os.path.basename(snip), event)
            bad_schema.append(snip); continue
        intended[event] = intended.get(event, set()) | keys
        # Merge at HOOK level, not group level. A group-level filter drops the whole group when a
        # user's own hook shares a group with the FH one (cross-family review 2026-07-30 reproduced
        # the loss: [my_telemetry.sh, fh_session_load.sh] lost my_telemetry.sh entirely).
        kept = []
        for g in hooks.get(event, []):
            survivors = [h for h in g.get("hooks", [])
                         if not any(k in h.get("command", "") for k in keys)]
            if survivors:
                g = dict(g); g["hooks"] = survivors; kept.append(g)
        hooks[event] = kept + entry
        registered.append(f"{event}({','.join(sorted(keys)) or '?'})")

os.makedirs(os.path.dirname(target), exist_ok=True)
with open(target, "w") as fh:
    json.dump(d, fh, indent=2, ensure_ascii=False); fh.write("\n")
# RE-READ WHAT WE JUST WROTE. The success message used to be unconditional — it never checked the
# serialized result, so a snippet that failed to register still printed "registered ->". Verify, then
# claim (`[[feedback_gate_verification_must_execute]]`).
written = json.load(open(target))
missing = []
for event, keys in intended.items():
    blob = json.dumps(written.get("hooks", {}).get(event, []))
    for k in sorted(keys):
        if k not in blob:
            missing.append(f"{event}:{k}")
for r in registered: print("    hook registered ->", r)
print("snippets scanned:", len(snippets), "· hook entries registered:", len(registered),
      "· skipped:", len(bad_schema), "->", target)
if missing:
    print("FAILED to register:", ", ".join(missing)); raise SystemExit(1)
# FAIL CLOSED on any skipped snippet. The good ones are already written (a malformed sibling must not
# cost you the working hooks), but the RUN exits non-zero — an installer that skips a snippet and
# reports success leaves hooks unwired, which is the exact defect this rewrite exists to close.
# Lanes MG-N1..N4 caught this: the first draft skipped-and-exited-0 = fail-open.
if bad_schema:
    print("SKIPPED snippet(s):", ", ".join(sorted({os.path.basename(b) for b in bad_schema})))
    print("  → non-zero exit on purpose: a skipped snippet is unregistered hooks, not a warning.")
    raise SystemExit(1)
if not registered:
    print("no hook entries registered — nothing to claim"); raise SystemExit(1)
PY
# CONSUME the merge block's exit status. It raises SystemExit(1) on a skipped/failed registration,
# and the surrounding bash has no `set -e` — so without this check the wizard sailed past a failed
# registration and §Step5 still printed success, which is the exact "reports success while unwired"
# shape the fail-closed direction was added to prevent (high re-review 2026-08-08 #6).
# The failure is SURFACED, not swallowed: the operator sees which snippet did not register.
_MERGE_RC=$?
if [ "$_MERGE_RC" -ne 0 ]; then
  echo "🟥 hook registration FAILED (exit $_MERGE_RC) — one or more snippets are UNREGISTERED."
  echo "   Do not read the completion report below as 'hooks are wired'. Fix the snippet and re-run"
  echo "   this step; the rest of the wizard continues so the remaining setup is not lost."
  WIZARD_HOOK_REG_FAILED=1
fi
chmod +x "$FH_DIR/scripts/fh_node_check.sh" 2>/dev/null
# VERIFY against a THROWAWAY state file (FH_NODE_STATE). Verifying against the real state would
# consume the user's one-shot event report, so their actual first session goes quiet and the notice
# is buried in install output instead (cross-family review 2026-07-30).
# known-pair: healthy machine → run 1 prints an event line, run 2 is SILENT.
#             missing floor  → prints EVERY run (a floor gap is a condition, not an event).
_T="$(mktemp)"; FH_NODE_STATE="$_T" bash "$FH_DIR/scripts/fh_node_check.sh"
FH_NODE_STATE="$_T" bash "$FH_DIR/scripts/fh_node_check.sh"; rm -f "$_T"

# 4-axis verification gate (Mode D / FH-self-development only — OPT-IN, double-confirm required)
# SCOPE (state this before asking): this gates commits IN YOUR FH CLONE ($FH_DIR) — git commit there is
#   blocked until the 4-axis markers pass. It is FH-internal infra (hardcodes hub paths/markers) and is
#   NEVER installed into field projects (see auto_project_mapping.md §6). Skip unless you develop FH itself.
# Per Core Principles (Per-item approval + Double-confirm irreversible changes): this is NOT auto-run —
#   it is a separate explicit Y/N, not folded into the baseline-setup batch.
if [ -d "$FH_DIR/templates/.git-hooks" ]; then
  echo "Enable the 4-axis pre-commit gate on your FH clone ($FH_DIR)? It will block commits there until"
  echo "markers pass (Mode D / FH-development only). Skip if you are not developing FH itself. (Y/N)"
  # → On explicit Y only:
  git -C "$FH_DIR" config core.hooksPath templates/.git-hooks
  chmod +x "$FH_DIR/templates/.git-hooks/pre-commit" 2>/dev/null
  echo "4-axis pre-commit gate: installed (core.hooksPath -> templates/.git-hooks)"
fi

# sentinel initialization (per-project independent — prevent conflicts with other projects on same machine)
mkdir -p ~/.cc_sentinels
touch ~/.cc_sentinels/$(basename "$(pwd)")_wizard_done

# Weekly audit cadence — NO cron needed (a session-scoped scheduler cannot fire on a later day).
# Durable mechanism = the zshrc hook above (fh_audit_check.zsh warns on terminal start when 7+ days
# since last weekly_audit) + FH session-start detection (proposes /harvest-loop lightweight when overdue).
```

---

## §Step5-Completion-Report

```
install-wizard — Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✅ Executed: {N}  ⏭ Skipped: {N}  ⏳ Later: {N}

  From now on:
  · Periodic audit auto-check on terminal start
  · Yellow warning output when weekly_audit exceeds 7 days
  · /harvest-loop (lightweight) proposed at session start when 7+ days since last weekly_audit

  Next step skills:
  · Not sure which plugin you need → /plugin-recommender
  · Need complex task automation → /agent-composer
  · Quality audit before publishing external assets → hub-persona-auditor auto-run
    (select "external user entry point audit" task type when composing in agent-composer)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 If this setup helped, consider contributing to FH.
   Pattern discovered → return with /field-harvest
   New skill proposal → PR:
     https://github.com/chrono-meta/forge-harness

🔬 Developing FH itself? Set up a durable PRIVATE companion store.
   Backend is your choice — the store is a role, not a fixed tech (it holds
   research artifacts; methodology stays in the public mirror):
   · Obsidian user → point output path at your vault (zero new infra)
   · gbrain / memory-brain → it ingests FH's emitted markdown
   · neither (default) → gh repo create {org}/{hub}-be --private
                         (or local-only: git init ~/path/{hub}-be — push auto-skipped)
   → see install-wizard SKILL_detail §Mode-D-Companion-Setup for the full branch
   → field projects (internal harness) can use the same dual-store pattern

🔀 Don't want to lose your accumulated assets — fork as your own hub:
   Personal skills/rules/notes added directly to FH may be lost on FH updates.
   git clone <FH_URL> ~/my-forge   # name is up to you (my-forge, team-forge, etc.)
   → Build freely in your fork and preserve permanently with git
   → When you discover valuable patterns, /field-harvest to reverse-contribute to FH anytime
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
