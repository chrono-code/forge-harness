---
name: cross-ecosystem-synergy-detection
description: Automatically discovers useful combinations (synergy pairs) across multiple installed plugins and skills, and presents them as a ranked table. Proactively suggests undiscovered synergies when new projects or skills are registered in the registry. Activates on phrases like "do my installed tools work well together?", "they seem to work in isolation", "find synergies".
user-invocable: true
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - cross_project
    - cold_start
---

# cross-ecosystem-synergy-detection — Multi-Ecosystem Automatic Synergy Discovery

Automatically discovers cross-invocable pairs in environments with multiple installed plugins and cross-CLI tools, and derives a synergy ranking table.

## Activation Triggers

1. **Multi-ecosystem component environment specified**: "multiple plugins/cross-CLI installed", "synergy with other components", "cross-ecosystem", "run together"
2. **New component added/removed**: "component install", "add/remove component"
3. **Synergy check phrasing**: "are they working in isolation?", "can they be integrated?", "environment check", "combination effect"
4. **Registry change detected** (optional): If a user-maintained `LOCAL_SKILL_REGISTRY.md` is present, Step 7 runs when a new project/skill is registered. The registry is not auto-created — absent file → Step 7 reports `[NOT-CONFIGURED]` and skips its body (see Step 7-1 outcome table).

**Exception**: Single-component environments (1 or fewer installed → no meaningful activation)

### Natural Language Triggers (General user phrasing — activates without internal vocabulary)

| Example phrasing | Intent |
|---|---|
| "Do my installed tools work well together?" | Check synergy of installed plugins/skills |
| "Would using this and that together be better?" | Explore cross-invocation possibilities |
| "I have multiple plugins installed in Claude — am I using them well?" | Diagnose installation ecosystem utilization |
| "My tools seem to be working in isolation" | Detect namespace/cwd fragmentation |
| "I just installed something new — check for conflicts with existing setup" | Check after adding new component |
| "I have multiple installs but not sure if I'm using them right" | Diagnose installation ecosystem utilization |
| "Wouldn't this and that work better together?" | Explore cross-invocation possibilities |
| "My tools feel disconnected and inconvenient" | Detect namespace/cwd fragmentation |
| "Wouldn't combining these plugins be more powerful?" | Explore component combination synergies |
| "I feel like there's synergy here — find it" | Automatic cross-invocation pair discovery |

## Processing Steps (7-step)

### Step 1. Installation Inventory Direct Inspection

```bash
cat ~/.claude/plugins/installed_plugins.json
```

**Schema (measured 2026-08-11, `version: 2`)** — read this before writing any parser:

```
{"version": 2,
 "plugins": {                       # DICT, not a list
   "<plugin>@<marketplace>": [      # value is a LIST of entries
     {"gitCommitSha": …, "installPath": …, "installedAt": …,
      "lastUpdated": …, "scope": …, "version": …}
   ]}}
```

The plugin **name is the dict key**, not an entry field — `entry.get('name')` is always `None`,
and iterating `for pl in data['plugins']` yields **key strings**, not entry dicts.
`gitCommitSha` is **optional** (measured: present on 5 of 11 installs) — see Step 5 drift.

Additional checks:
- `~/.claude/settings.json` `enabledPlugins` (actually active assets)
- Check `installed_plugins.json` ↔ `enabledPlugins` consistency (catch drift)

### Step 2. Asset Matrix Extraction per Component

```bash
for T in skills agents commands .mcp.json hooks; do
  if [ -e "$IP/$T" ]; then echo "PRESENT $T"; ls "$IP/$T"; else echo "ABSENT  $T"; fi
done
```

Extract each asset's frontmatter `description` + `allowed-tools` + `model`. Merge `plugin.json keywords`.

**`ABSENT` is a state, not a zero.** Most plugins ship only a subset (measured on `fh-meta`:
`skills`/`agents` present, `commands`/`.mcp.json`/`hooks` absent). Carry `ABSENT` through to
the matrix — an absent asset class must not be counted as "0 assets found", which would read as
an inspected-and-empty component.

### Step 3. Cross-Invocation Possible Pair Matrix Derivation

Call mechanism compatibility:
- **Skill**: Can be called directly as `{component-name}:{skill-name}`
- **Agent**: Can be called directly as `{component-name}:{agent-name}` via subagent_type
- **Hook**: Auto-triggered (no direct cross-component calls)
- **MCP**: Per-tool calls (namespace separated)

### Step 4. Synergy Grade Derivation (★~★★★)

| Grade | Compatibility conditions |
|---|---|
| **★★★** | Directly complementary work areas + immediate cross-invocation compatible |
| **★★** | Complementary work areas + callable but cwd mismatch at certain points |
| **⚠️★** | Cross-invocable but risk of work area conflict |

★★★ found → candidate for automatic cross-invocation documentation  
⚠️★ found → document risk + explicitly state avoidance rules

### Step 5. Risk Catch

- **cwd fragmentation**: Component A and B operating in different cwds → work area separation
- **Namespace conflict**: Same skill name exposed across multiple components simultaneously
- **Drift**: Install path commit SHA ↔ original repo HEAD mismatch. **Three states, not two** —
  `gitCommitSha` is absent on marketplace installs (measured: 6 of 11), and an absent SHA is
  **`DRIFT-UNKNOWN` (cannot be checked)**, never "matches". Report `MATCH / DRIFTED /
  DRIFT-UNKNOWN(n=…)` and **never fold `DRIFT-UNKNOWN` into the match count**
- **Hook conflict**: Same event matcher across multiple components → inspect settings.json integration

When risk found → user explicit decision gate (no automatic patching)

### Step 6. Result Persistence (Optional)

**Canonical result file** (the "synergy reference file" referenced throughout this skill):

```
tracks/_meta/synergy_scan_{YYYY-MM-DD}.md      # local, gitignored by design
```

Verified 2026-08-11 against the two on-disk candidates:
`tracks/_meta/synergy_scan_2026-07-31.md` **is** a synergy-pair ranking record and is the canon;
`knowledge/shared/harness-core/fh_synergy_playbook.md` is **not** — it is a tracked, public
integration playbook (FH × OpenCode / Hermes / OpenHuman workflows) with no pair registry.

**Residency**: a scan output enumerates the operator's installed components and mapped field
harnesses, which can carry company asset names. It belongs on a gitignored path only —
never append discovered pairs to a tracked file such as the playbook.

When persisting results:
- Record discovered synergy pairs in the canonical result file above
- Confirm absence of equivalent external tools (environment comparison verification)

### Step 7. Proactive Discovery — Proactive Mode

> Trigger: Runs when a new section/skill is registered in a user-maintained `LOCAL_SKILL_REGISTRY.md` (optional, user-created; absent → self-skip)

**Purpose**: FH proactively discovers and proposes synergies that previously required human ideas to find.

#### 7-1. Dynamically Discover and Read Registry Path

The registry is a **per-machine, gitignored** artifact (regenerated by the session scan). It therefore
lives in the **working project**, not in the plugin cache — a plugin install path ships no `.claude/`
directory at all, so searching only there yields a permanent false skip on every external install.

```bash
# Resolve FH install path (fallback root only). stderr is deliberately NOT discarded.
FH_INSTALL=$(python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.claude/plugins/installed_plugins.json'
if p.exists():
    data = json.loads(p.read_text())
    raw = data.get('plugins', data) if isinstance(data, dict) else data
    # version 2 = dict keyed by name; legacy = list of entries carrying 'name'
    items = raw.items() if isinstance(raw, dict) else [(e.get('name',''), [e]) for e in raw]
    for name, entries in items:
        entry = entries[0] if isinstance(entries, list) else entries
        if 'forge-harness' in name:
            print(entry.get('installPath',''))
            break
")
py_rc=$?

if [ "$py_rc" -ne 0 ]; then
  echo "[HARNESS_ERROR] installed_plugins.json read failed (python rc=$py_rc)."
  echo "  Step 7 state = UNMEASURED. Do NOT report this as '[SKIP] no registry' — the inventory was never read."
else
  REGISTRY=""
  for CAND in "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/registry/LOCAL_SKILL_REGISTRY.md" \
              "${FH_INSTALL:+$FH_INSTALL/.claude/registry/LOCAL_SKILL_REGISTRY.md}"; do
    if [ -n "$CAND" ] && [ -f "$CAND" ]; then REGISTRY="$CAND"; break; fi
  done
  if [ -n "$REGISTRY" ]; then
    cat "$REGISTRY"
  else
    echo "[NOT-CONFIGURED] LOCAL_SKILL_REGISTRY.md absent (searched \$CLAUDE_PROJECT_DIR/.claude/registry/ then \$FH_INSTALL/.claude/registry/)."
    echo "  Create: mkdir -p \"\${CLAUDE_PROJECT_DIR:-\$PWD}/.claude/registry\" and write LOCAL_SKILL_REGISTRY.md there (per-machine, gitignored by design)."
  fi
fi
```

**Three outcomes, reported distinctly** (a missing measurement is not a zero):

| Outcome | Meaning | Step 7 body |
|---|---|---|
| registry printed | configured and read | run 7-2 ~ 7-5 |
| `[NOT-CONFIGURED]` | inventory read fine, no registry exists | skip 7-2 ~ 7-5, report this state + the creation hint |
| `[HARNESS_ERROR]` | inventory could not be read | skip 7-2 ~ 7-5, report **UNMEASURED** — never as a skip or a clean result |

If the registry was printed, extract `one-line description` + `example phrases` from newly registered projects/skills.

#### 7-2. Load Existing Synergy Pair List

Load already-registered synergy pairs (including ★ grade) → prevent duplicate proposals.

#### 7-3. Derive Undiscovered Synergy Candidates

Compare domain of new skill/project against entire existing registry:

| Decision criteria | Synergy grade candidate |
|---|---|
| Output of one becomes input of another | ★★★ |
| Different layers in same domain (generate↔analyze, build↔verify) | ★★★ |
| Can run sequentially in same cwd | ★★ |
| Domain overlap but different perspectives | ★ |

#### 7-4. Proactive Proposal Output Format

```
## Undiscovered Synergy Candidates (Proactive Detection)

| # | Pair | Grade Candidate | Discovery basis |
|---|---|---|---|
| 1 | `{new skill}` ↔ `{existing skill}` | ★★★ | {one-line description} |

→ Add to the canonical result file (Step 6: `tracks/_meta/synergy_scan_{YYYY-MM-DD}.md`)? [Y / N]
```

- **Y** → Append to that file as a new pair section (gitignored path only — see Step 6 Residency)
- **N** → Collect reason and discard or defer recording

#### 7-5. Guards

- 0 candidates → Output "No new synergy pairs found between newly registered skills and existing assets." then exit
- No duplicate proposals of already-registered pairs (cross-check with 7-2 load results)

---

## External Environment Adaptation

The internal GHE org inventory and cluster classifications shown in original developer environment are organization-specific examples.  
External users automatically derive their own inventory via Step 1 `installed_plugins.json` inspection alone.

| Original developer environment | External environment fallback |
|---|---|
| Internal GHE org inventory | Direct inspection of user's install ecosystem |
| Cluster classification | Auto-clustering by `keywords` distribution |
| Synergy grade baseline (8 items) | Auto-accumulated from user environment simulation results |

## Done When

| Condition | Check class |
|---|---|
| Steps 1~6 completed | **mandatory-pass** |
| Synergy ranking table (★~★★★) output | **mandatory-pass** |
| **Step 7 state reported as one of `run` / `not-configured` / `harness-error`** — never silently omitted, and `harness-error` never reported as a skip | **mandatory-pass** |
| Step 5 drift reported as `MATCH / DRIFTED / DRIFT-UNKNOWN(n=…)`, with `DRIFT-UNKNOWN` excluded from the match count; Step 2 `ABSENT` asset classes carried through as `ABSENT`, not `0` | **measured** (counts come from the Step 1/2 output, not from recall) |
| User explicit decision gate completed if risk catch items exist | **mandatory-pass** |
| Synergy grades are defensible (★ assignment per the Step 4 table) | **judged** — adversarial pairing: `fh-meta:challenger` re-reads the pair list and attacks each ★★★ for "would these two actually chain, or do they merely sound adjacent?" |
| User confirmed whether to persist results | **mandatory-pass** |

## Constraints

- No editing of external component asset bodies
- Automatic cross-invocation documentation / new risk avoidance rule creation = only on user's explicit decision
- For organization-specific environment examples, maintain a local reference file

## References

- `feedback_tool_output_direct_inspection_first` (Step 1·2 direct inspection obligation)
- `feedback_simplification_evidence` (simplification guard justified concession)
- `feedback_no_personal_commit_to_shared_repo` (no editing external plugin bodies)
