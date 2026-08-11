---
name: install-doctor
description: Scans the existing environment before and after meta-harness plugin install to diagnose conflicts, duplicates, and silent overwrite risks. Reports potential conflict areas with existing CLAUDE.md, skills, hooks, and audit practices. Activates on "install conflict", "any overlaps?", "is it safe to install?".
user-invocable: true
allowed-tools: ["Read", "Bash", "Glob", "Grep"]
model: sonnet
category: Composability Gate
---

# install-doctor — Plugin Install Conflict Diagnosis

Diagnoses potential conflicts, duplicates, and overwrite risks that may occur when installing meta-harness plugins into an existing project.

**Can be installed standalone** — works correctly with plugin install alone, without cloning the full meta-harness.

## Triggers

```
/install-doctor                        # Full diagnosis of current environment
/install-doctor --plugin fh-meta       # Diagnose targeting a specific plugin
```

## Step 0. Runtime Environment Requirements Check

FH operates on the assumption of a large context window. If the environment is unsuitable, `Input is too long` 400 errors may occur during skill execution.

### Supported Environments

| Environment | Support | Notes |
|---|---|---|
| Claude Code + Anthropic API Key | ✅ Recommended | 200K context · officially supported |
| claude.ai Pro / Team Plan | ✅ Recommended | 200K context · officially supported |
| AWS Bedrock (direct API) | ⚠️ Conditional | Possible with sufficient account quota — default quota may be low |
| Bedrock + claude-code-router + LiteLLM | ⚠️ Unofficial | Context limit exceeded frequently · not recommended |
| Internal AI API proxy | ⚠️ Conditional | Depends on max_input_tokens setting |

### Environment Check

```bash
# Detect community router (Bedrock bypass)
ls /opt/homebrew/lib/node_modules/@musistudio/ 2>/dev/null \
  && echo "⚠️  claude-code-router detected — routing via Bedrock/external proxy" \
  || echo "✅ No community router"

# Claude Code version
claude --version 2>/dev/null || echo "Claude Code not installed"
```

**⚠️ When Bedrock routing confirmed**: Request AWS quota increase (TPM/RPM increase) or raise LiteLLM `max_input_tokens`, then retry. Fundamental solution is switching to direct Anthropic API access.

### Node floor check — run on EVERY machine, not once per user

A user's context (companion store, memory, session card) travels between machines; **the machine's
own setup does not**. A rich context makes a fresh laptop read as "already configured", so the two
mechanical floors below must be checked per node — this is the check `scripts/fh_node_check.sh`
points at when it reports a missing floor at turn 0.

```bash
# HUB_DIR — the same variable the hook scripts use. Do NOT invent a second name (an earlier draft
# read FH_DIR, which nothing sets, so an operator with HUB_DIR set would have been silently told
# about a different repo).
FH="${HUB_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# ① git-side floor. Probe the EXECUTABLE HOOK, not the config key — `core.hooksPath` unset is a
#    normal, working install when hooks sit in .git/hooks, and a set-but-empty path is a broken
#    install that the key alone reports as fine. Both directions are wrong; the file is the truth.
#    Resolve the directory with `git rev-parse --git-path` rather than assembling "$FH/.git/hooks":
#    in a LINKED WORKTREE `.git` is a file, so the assembled path does not exist and every hook
#    reads as missing (verified: a worktree with working hooks reported ❌❌ under the old form).
#    Same resolution the script uses — one predicate, not two.
# --path-format needs git >= 2.31; on older git fall back to the RELATIVE --git-path form resolved
# against the toplevel, never to a hand-built "$FH/.git/hooks" (which is the worktree bug above).
HD="$(git -C "$FH" rev-parse --path-format=absolute --git-path hooks 2>/dev/null)"
if [ -z "$HD" ]; then
  _rel="$(git -C "$FH" rev-parse --git-path hooks 2>/dev/null || echo .git/hooks)"
  case "$_rel" in /*) HD="$_rel" ;; *) HD="$(git -C "$FH" rev-parse --show-toplevel 2>/dev/null || echo "$FH")/$_rel" ;; esac
fi
for h in pre-commit pre-push; do
  if [ -x "$HD/$h" ]; then echo "✅ $h executable ($HD)"
  else echo "❌ $h MISSING or not executable at $HD — that gate is not running on this node"; fi
done

# ② turn-0 load floor (Mode D only): the companion-load hook. Its registration lives in the
#    GITIGNORED settings.local.json, so it does NOT survive a re-clone — hence a per-node check.
#    Parse the JSON and match the SCRIPT NAME inside hooks.SessionStart — not a bare grep for the
#    key. settings.json also carries a SessionStart entry (fh_node_check), so keying on the key
#    alone passes on a machine where the companion load is absent; and a plain substring grep also
#    hits commented-out lines, other hook events, and permission strings. Same predicate the script
#    uses — two predicates reading one state differently is how a result leaks silently.
#    Applicability gate FIRST, and keyed the same way the script keys it: a Mode D user is one with
#    an exported BE_DIR, or a CLAUDE.local.md that MENTIONS a companion binding — NOT one who merely
#    HAS a CLAUDE.local.md (that is Claude Code's standard local-override file; anyone may keep one),
#    and NOT one who has a settings.local.json (gitignored, so a fresh clone lacks it — and a fresh
#    clone with a full companion store is the exact case this must not silence). The vocabulary
#    covers every backend the wizard documents (vault · gbrain · *-be repo), because an FH-flavoured
#    regex would silence two first-class backends. It is a MENTION test, not semantic: "I do not use
#    a companion store" also matches, and that over-match costs one informational line — the cheap
#    direction, since the expensive direction is silence.
if { [ -n "${BE_DIR:-}" ] && [ -d "$BE_DIR" ]; } \
   || { [ -f "$FH/CLAUDE.local.md" ] && grep -qiE 'BE_DIR|companion[ -]store|컴패니언|vault|gbrain|obsidian' "$FH/CLAUDE.local.md"; }; then
  python3 - "$FH" <<'PY'
import json, os, sys
hub = sys.argv[1]
for p in (os.path.join(hub, ".claude", "settings.local.json"),
          os.path.expanduser("~/.claude/settings.json")):
    try: groups = json.load(open(p)).get("hooks", {}).get("SessionStart", [])
    except Exception: continue
    if any("fh_session_load" in h.get("command", "")
           for g in groups for h in g.get("hooks", [])):
        print("✅ companion-load SessionStart registered"); sys.exit(0)
print("❌ companion-load SessionStart MISSING — freshness + env-delta do not fire at turn 0")
PY
else
  echo "N/A  companion-load SessionStart (not a Mode D setup — no companion store configured)"
fi
```

**Bootstrap note — honest scope**: `scripts/fh_node_check.sh` (the check that *reports* a missing
floor at turn 0) ships with the clone, but its **registration does not**: every
`.claude/settings*.json` path in this repo is gitignored (confirm with `git check-ignore -v
.claude/settings.json` — don't trust a line number, they move), so no SessionStart entry can be
tracked. The tracked artifact is `templates/settings.SessionStart.snippet.json`; `/install-wizard`
merges it. A user who never runs the wizard still gets no turn-0 signal — that residual is reduced,
not closed, and this check item is the backstop for it.

**Emission model** (so the output is read correctly): a **missing floor is reported every session**
until it is fixed — it is a persistent condition, not an event. A healthy machine is silent. So
seeing this banner twice is not a bug, and seeing it once then never again means it was an *event*
line (identity change / infra delta), not a floor complaint.

**Fix for either ❌**: re-run `/install-wizard` (it registers both — `install-wizard/SKILL_detail.md`
§Mode-D-Companion-Setup step 3 and the 4-axis gate block), or apply the two commands it uses directly.

**Why this is a check item and not a note** (measured 2026-07-30): a second machine held the full
companion store and memory, yet ran with **both** SessionStart hooks absent. Nothing surfaced it —
the miss was found by accident. A weak tier is where this bites hardest: a mechanized floor is
tier-independent, while the prose it replaces is exactly what a weaker model drops first.

---

## Step 1. Existing Asset Inventory

```bash
# CLAUDE.md existence
[ -f "CLAUDE.md" ] && echo "CLAUDE.md exists: $(wc -l < CLAUDE.md) lines" || echo "CLAUDE.md absent"

# Existing skills
ls .claude/skills/ 2>/dev/null && echo "Existing skills present" || echo "No existing skills"

# Existing hooks
[ -f ".claude/settings.json" ] \
  && python3 -c "import json; d=json.load(open('.claude/settings.json')); print('hook events:', list(d.get('hooks',{}).keys()))" \
  || echo "settings.json absent"

# .claudeignore
[ -f ".claudeignore" ] && echo ".claudeignore exists" || echo ".claudeignore absent"

# Existing audit/log files
find . -maxdepth 3 -name "*audit*" -o -name "*weekly*" 2>/dev/null \
  | grep -v "node_modules\|\.git" | head -5
```

## Step 2. Conflict Diagnosis (5 Areas)

### 2-1. CLAUDE.md Rule Conflicts

```bash
grep -i -n "pr\|pull request\|audit\|review\|weekly" CLAUDE.md 2>/dev/null | head -15
```

Judgment:
- Existing PR convention present → possible priority conflict with `hub-cc-pr-reviewer` ⚠️
- Existing weekly audit present → possible format conflict with `harvest-loop` ⚠️

### 2-2. Skill Trigger Conflicts

```bash
find .claude/skills -name "SKILL.md" 2>/dev/null | while read f; do
  name=$(grep "^name:" "$f" | head -1)
  desc=$(grep "^description:" "$f" | head -1)
  echo "--- $name"
  echo "$desc"
done
```

If same trigger vocabulary exists in a meta-harness skill → unclear which skill will activate ⚠️

### 2-3. Hook Event Conflicts

```bash
[ -f ".claude/settings.json" ] && python3 -c "
import json
d = json.load(open('.claude/settings.json'))
for event, hooks in d.get('hooks', {}).items():
    print(f'{event}: {len(hooks)} hook(s)')
" || echo "No settings found"
```

Multiple hooks on same event → execution order unclear ⚠️

### 2-4. .claudeignore Scope Conflicts

```bash
cat .claudeignore 2>/dev/null | grep -v "^#" | grep -v "^$"
```

If .claudeignore blocks files that meta-harness skills read for diagnosis (CATALOG.md, tracks/, CLAUDE.md) → inaccurate skill results ⚠️

### 2-5. Audit/Log Practice Conflicts

```bash
find . -maxdepth 3 \( -name "*audit*" -o -name "*weekly*" -o -name "*retrospect*" \) \
  -not -path "./.git/*" -not -path "./node_modules/*" | head -10
```

If existing retrospective/audit files exist → `harvest-loop` will create files in separate format → dual management ⚠️

### 2-6. MCP HTTP Transport Security Check

```bash
# Check MCP server transport settings
grep -r "\"transport\"" .mcp.json 2>/dev/null | grep -i "http\|sse"

# List MCP servers using HTTP transport.
# `except: pass` made this exit 0 on ANY failure, so the `|| echo` fallback was dead code and a
# corrupt .mcp.json rendered identically to "no risky servers" — a silent pass on a security check.
# Four states, four distinct exits: absent(0) · unparseable(2) · risky(1) · all-stdio(0).
python3 - <<'PY'
import json, os, sys
p = '.mcp.json'
if not os.path.exists(p):
    print('  MCP-CHECK: NOT-APPLICABLE — .mcp.json absent (no MCP servers configured)')
    sys.exit(0)
try:
    d = json.load(open(p))
except Exception as e:
    print(f'  MCP-CHECK: UNPARSEABLE — {p}: {e}')
    print('  Transport risk UNMEASURED — this is NOT a pass. Fix the file and re-run.')
    sys.exit(2)
servers = (d.get('mcpServers') or {})
risky = [(n, (c or {}).get('transport', 'stdio')) for n, c in servers.items()
         if (c or {}).get('transport', 'stdio') != 'stdio']
if risky:
    for n, t in risky:
        print(f'  WARNING  {n}: transport={t} — verify localhost binding + auth')
    sys.exit(1)
print(f'  MCP-CHECK: PASS — {len(servers)} server(s), all stdio')
PY
```

> **Read the exit code, not just the text.** `2` (unparseable) is an *unmeasured* check and must be
> reported 🟧 in Step 3, never folded into 🟩. Known-pair calibration for this block: a deliberately
> truncated `.mcp.json` must yield `2`, and a config with one `transport: http` server must yield `1`.
> If both print nothing, the check is dead.

**Known MCP HTTP transport vulnerability patterns** (based on HTTP port exposure security principles): When MCP servers using HTTP/SSE transport expose ports without authentication, remote access risk within local networks may occur. stdio transport is not affected.

| Transport | Risk |
|---|---|
| `stdio` (default) | Safe — not subject to vulnerability pattern |
| `http` / `sse` | ⚠️ Risk if port exposed without authentication — verify firewall rules + access control |

**Recommendation**: HTTP transport MCP servers must confirm localhost binding + access control.

## Step 3. Diagnosis Report

```
## install-doctor Diagnosis Results

### 🟥 Immediate Action Required
- [empty if none]

### 🟧 Recommended to Check After Install
- [empty if none]

### 🟩 No Conflicts
- [safe confirmed items]

---
Diagnosis scope: CLAUDE.md rules · Skill triggers · Hook events · .claudeignore · Audit practices
```

**0 conflicts**: "Plugin install is safe in the current environment."

## Step 4. Layer A Fallback Guidance

The meta-harness CLAUDE.md's `## Session Start` Layer A auto-read (CATALOG.md · tracks/ · MEMORY.md) only works in the **meta-harness cwd**.

If you installed only the plugin in a different project cwd:
- Layer A auto-read = silent skip
- Alternative: Directly add `## Session Start` section to that project's CLAUDE.md, or manually read CATALOG.md

## Activation Triggers

| Phrasing pattern | Examples |
|---|---|
| **Pre-install check** | "Can I add this plugin?", "Will it conflict with my existing setup?" |
| **Post-install anomaly** | "Something seems off after install", "Things seem different than before" |
| **Explicit diagnosis request** | "Check for install conflicts", "Run environment check", "Any overlaps?" |

## Done When

```
Steps 0~4 completed                                              (mandatory-pass)
+ Step 0 node-floor results recorded per check, each as one of
  PASS / FAIL / UNMEASURED — never blank                          (measured: 2 floors —
                                                                   hook exec-bit, SessionStart
                                                                   registration)
+ Step 2-6 MCP transport check exited 0/1/2 and the exit code is
  carried into the Step 3 tier (2 = UNMEASURED → 🟧, never 🟩)     (mandatory-pass)
+ Step 3 diagnosis report emitted with a tier per area
  (🟥 immediate action / 🟧 check recommended / 🟩 no conflicts)   (mandatory-pass)
+ Verdict is derived from the recorded per-area tiers: 🟩 only if
  every area is 🟩 AND none is UNMEASURED                          (measured: count of
                                                                   non-🟩 areas == 0)
```

**Why `Steps 0~4`, not `1~4`**: Step 0 holds the only *mechanical floor* checks in this skill (hook
exec-bit, SessionStart registration, Node floor). Leaving it outside the completion condition let a
run report "done" having never touched the one part that is not judgement.

**Why the verdict is counted, not stated**: the previous condition was `"Plugin install is safe in
current environment" confirmed` — that measures whether a *sentence was printed*, which a run
satisfies by printing it. An unmeasured area (e.g. an unparseable `.mcp.json`) must not be
absorbed into 🟩; absence of a finding is not a finding of absence.

## Simplification Guard

- 0 existing assets (new environment) → output "New environment. No conflicts." and exit immediately in Step 1
- Scope separation from harness-doctor (harness structure) · context-doctor (token efficiency): this skill = install-time conflict diagnosis only
- Call `/harness-doctor` for structural checks needed after plugin install
