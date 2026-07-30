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

# CC settings (handle both dict and list for plugins)
cat .claude/settings.json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
p=d.get('plugins',{})
print('plugins:', list(p.keys()) if isinstance(p,dict) else p)
" 2>/dev/null || echo "settings.json not found"

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
# Detect existing harness scale
CLAUDE_MD_LINES=$(wc -l < CLAUDE.md 2>/dev/null || echo 0)
RULES_COUNT=$(ls .claude/rules/*.md 2>/dev/null | wc -l || echo 0)

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
# zshrc hook (if not installed — preview then confirm, idempotent)
if ! grep -q "fh_audit_check.zsh" ~/.zshrc 2>/dev/null; then
  cat >> ~/.zshrc << 'EOF'
export FH_DIR="{FH_DIR}"
export CC_HUB_DIR="{CC_HUB_DIR}"
export CC_SENTINELS_DIR="$HOME/.cc_sentinels"
source "$FH_DIR/templates/fh_audit_check.zsh"
EOF
fi

# Node floor check hook — ALL users, not Mode D only. Source of truth = the tracked snippet
# templates/settings.SessionStart.snippet.json (`project_settings_json` key). Registration itself
# cannot be tracked (every .claude/settings*.json path is gitignored), so the wizard is what wires it
# — which is exactly why this must not be skipped: without it, a user on a fresh machine gets no
# turn-0 signal that their floors are missing.
# NPM-INSTALL PRECONDITION: this block reads the snippet from disk, so both it and
# scripts/fh_node_check.sh must be in package.json `files[]`. They are (added 2026-07-30 after
# scripts/package_coverage_check.sh caught the omission — without it an npm-installed wizard hit
# FileNotFoundError here and registered nothing while reporting success upstream).
python3 - "$FH_DIR" <<'PY'
import json, os, sys, collections
hub = sys.argv[1]
snippet = os.path.join(hub, "templates", "settings.SessionStart.snippet.json")
target = os.path.join(hub, ".claude", "settings.json")
entry = json.load(open(snippet))["project_settings_json"]["hooks"]["SessionStart"]
d = collections.OrderedDict()
if os.path.exists(target):
    d = json.load(open(target), object_pairs_hook=collections.OrderedDict)
    import shutil; shutil.copy2(target, target + ".prewizard")   # back up before rewriting
hooks = d.setdefault("hooks", collections.OrderedDict())
# Merge at HOOK level, not group level. A group-level filter drops the whole group when a user's own
# hook shares a group with the FH one — the common shape when someone hand-edits or appends to an
# older wizard's output. (Cross-family review 2026-07-30 reproduced the loss: a group holding
# [my_telemetry.sh, fh_session_load.sh] lost my_telemetry.sh entirely.)
kept = []
for g in hooks.get("SessionStart", []):
    survivors = [h for h in g.get("hooks", []) if "fh_node_check" not in h.get("command", "")]
    if survivors:
        g = dict(g); g["hooks"] = survivors; kept.append(g)
hooks["SessionStart"] = kept + entry
os.makedirs(os.path.dirname(target), exist_ok=True)
with open(target, "w") as fh:
    json.dump(d, fh, indent=2, ensure_ascii=False); fh.write("\n")
print("node-check SessionStart hook registered ->", target)
PY
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
