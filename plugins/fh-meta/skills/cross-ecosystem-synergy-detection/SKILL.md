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
| "Do my harnesses have synergy with each other?" | **Step 3-b standalone** — harness-level scan |
| "Can I transplant a governance pattern from another project?" | **Step 3-b standalone** |
| "Could I bring that project's gate over here?" | **Step 3-b standalone** |
| "하네스끼리 시너지" · "거버넌스 패턴 이식" · "다른 프로젝트 게이트 가져올 수 있나" | **Step 3-b standalone** |
| "이 하네스에 시너지 몰아줘" · "focus the synergy on this one" · "이거 하나 집중해서 강화" | **focus mode** — Step 3-b **+ Step 3-c by default** |
| "밖에도 이런 거 있나" · "더 강화할 방법 있어?" · "is there prior art that would make this stronger?" | **Step 3-c** |

> **Step 3-b fires standalone.** The last four rows call that step alone; they do not require the full
> door-④ pass. A request about *harnesses* is not a request about *installed plugins*.

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

### Step 3-b. Harness-level pattern-transplant scan (conditional default)

**Condition**: 2+ mapped field-harness tracks exist. 🟥 **Establish the count by running
`bash scripts/mapped_tracks.sh` — never by listing `tracks/` from the session's cwd.** The mapping
signal is the *presence* of `tracks/<name>/`, and that signal cannot reach a worktree: `tracks/**` is
gitignored, and at least one mapped track is an **empty directory** git could not carry even if it
were not. Measured 2026-08-22, one run: **main checkout 11 · worktree 1** — a cwd listing does not
return a smaller count, it returns a structurally blind one, and `skipped(<2 mapped tracks)` is a
*pass* value, so the blind run closes green. The script resolves the hub root through
`git rev-parse --git-common-dir` (the `EVIDENCE_ROOT` pattern this repo already sanctions in
`templates/.git-hooks/pre-commit`) so both standpoints answer alike.
🟥 **`status=UNMEASURED` (exit 3) is NOT a skip** — it means the count could not be taken, which is a
different value from "fewer than two". Close it as `external-error` (non-pass); never as
`skipped(<2 mapped tracks)`. Underscore-prefixed meta dirs (`_meta`/`_audit`/`_contrib`/`_chamber`)
do not count — the test is a **leading** underscore, so a track like `the_bible` is counted.
Otherwise skip with one line.

Steps 1–3 look at **installed plugins/skills**. This step looks one layer up: the **governance
mechanisms of the mapped field harnesses themselves** — verification axes, verdict enums, gate exit
codes, persona systems — and finds pairs where one harness's mechanism is transplantable into another.

- Read each mapped track's **canon** (`CLAUDE.md` / `README.md`), not its code. Field-harness
  vocabulary must not be normalized into general concepts — that is this repo's habitual failure.
- Emit **transplantable pairs only**: the two must share the *same problem shape*. Merely overlapping
  subject matter is excluded.
- 🟥 Declare the read depth. "Read the top ~150 lines of CLAUDE.md" is a different claim from "read the
  file"; say which, and mark anything not opened as **unverified**, never as absent.
- Store under its **own section** in the Step 6 result file, separate from the skill/agent pair table —
  the two layers answer different questions and merging them hides which one produced a finding.

> **Boundary with Step 7**: Step 7 (proactive) may *trigger* Step 3-b; it does not replace its scan.
> Step 7 decides *when to offer*, Step 3-b decides *what to read and which transplant pairs come out*.
>
> **Why this is a default and not an extra**: door ④ was run live on 2026-08-21 and 2026-08-22 and both
> times produced only the skill/agent layer, while the operator was asking for this one. The wiring
> existed; its target was pinned to the old object. Provenance: `tracks/_meta/fh_signal_2026-08-21_unused-skills-are-unwired.md`
> (cause ⓓ) and `tracks/_meta/fh_signal_2026-08-22_operator.md`.
> ⚠️ **Mechanized at N=2 by explicit operator instruction; do not count as threshold-triggered
> mechanization** (`[[feedback_mechanize_at_repetition_prose_before]]`).

### Step 3-c. Outward pass — strengthen the pairs (identity ④ loop)

**Condition (default is scoped, not always-on)**: runs by default only in **focus mode** — when the
operator names one harness to concentrate synergy on. In whole-environment mode it is **offered, not
run** (operator, 2026-08-22: *"로컬 내 플젝 간 시너지는 딱히 영향이 크게 없겠지만 이후 세션에는 또
새로운 정보를 얻을 수 있겠지"* — worth doing, not worth doing every time).

This is identity ④ (**프런티어 답습**) applied to synergy, and its purpose is the same as that
identity's: **block reinvention.** 📚 *bookshelf = don't rebuild what we already have* ·
🌍 *library = don't rebuild what the world already made.*

**The loop** — ② is a judgment and stays with the session; no hook decides it:

```
Steps 1–3-b produced pairs (📚 bookshelf: our own components + mapped harnesses)
      ↓  ② is there ANYTHING you cannot assert confidently about a pair?
         (threshold is «even slightly» — «I'm fairly sure» is the setting where this never fires)
      ↓  three outcomes, and COUNT THEM SEPARATELY
   ⓐ closed by thinking     — **no tool call was made**; reasoning settled it
   ⓑ closed at the bookshelf — **a Read/Grep against local canon actually ran** and answered it
   ⓒ went to the library     — an outward call was made (below)
```
🟥 **The three are separated by TOOL CALLS, not by how it felt.** ⓐ = zero calls · ⓑ = a local read
happened · ⓒ = an outward call happened. Written that way the split is checkable against the session's
own tool history instead of being self-reported — which is what an earlier draft left it as.
⚠️ **Never fold ⓐ into ⓑ.** «I already knew it from the bookshelf» with no Read is **ⓐ**, not ⓑ.
Folding inflates the "closed at the bookshelf" column, and that column is the one that says whether
this loop works at all.

**Record it per pair, not as a total.** A bare `run(2/3/1)` cannot be checked — it says the three were
counted without showing which pair went where. Step 3-c emits a **pair ledger**:

```
pair | what I could not assert | outcome ⓐ/ⓑ/ⓒ/withheld | bookshelf pointer or query shape | note
```
and the arithmetic has to close: **ⓐ + ⓑ + ⓒ + withheld == in-scope pair count.** A pair that appears
in no row is a dropped pair, not a passing scan.

**Two result types — keep them apart** (they feed different steps):
- `strengthener` — a technique or prior art that makes an existing pair better. **This is what
  Step 3-c is for.**
- `equivalent-risk` — the outside already has the whole thing. That is **Step 6's question**, not this
  one; hand it down rather than acting on it here. Mixing them is how «강화» quietly becomes «폐기».

**Residency — narrow, and stated at its real size.**
Searching does **not** leak by itself. The only **semantic payload we intentionally send** is the query
string — ⚠️ not the only surface at all (account and tool logs, which results were opened, any follow-up
fetch path all exist); it is the one carrying meaning we chose. And the natural way to look for prior art
is already abstract — nobody searches for a technique by typing their own repo name.
So this is one careless-phrasing case, not a reason to fear the step:
- **Keep harness names, repo names, paths and internal codenames out of the query.** Send the **problem
  shape** — «a gate whose verdict is a typed enum, transplanted into a repo that greps prose».
- It bites unevenly: some mapped harnesses are **company assets**, and `internal repo/asset names` is on
  the residency prohibition list by name. Public ones are not. **Check which side a pair sits on before
  wording the query**, rather than treating every name as equally sensitive.
- A pair that genuinely cannot be abstracted without naming a private asset stays home — record
  `outward: withheld (residency)`, a *recorded* skip rather than a silent one.
- Results come back and are matched to pairs **locally**; the matching never goes out.

**What comes back, and what it is for**: not «who else built this» trivia — a **prior art or a
technique that would make an existing pair stronger**. If the outward pass produces no such thing,
that is a normal result: record `outward: run, 0 applicable`. 🟥 Do **not** manufacture a finding to
justify having looked.

**Boundary with Step 6** — do not merge these, they answer opposite questions:

| | question | when |
|---|---|---|
| **Step 3-c** (this) | *is there something outside that would **strengthen** these pairs?* | during derivation |
| **Step 6** «Confirm absence of equivalent external tools» | *does an equivalent already exist, i.e. are we **reinventing**?* | at persistence |

Both are «external»; only one of them is asking whether to keep going.

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
| **Step 3-b reported as `run(n pairs)` or `skipped(<2 mapped tracks)`** — never silently omitted; read depth declared per track. 🟥 **The count comes from `bash scripts/mapped_tracks.sh`, and its `hub_root` / `in_worktree` line is quoted with the verdict** — a count taken by listing cwd is not evidence, it is the defect (main 11 vs worktree 1, measured 2026-08-22). `status=UNMEASURED` closes as `external-error`, **never** as `skipped` | **measured** (the count is a tool-call result, not a recollection) |
| **Step 3-c closes as exactly one of `run(ⓐ=N ⓑ=N ⓒ=N)` · `offered(whole-environment mode)` · `withheld(residency)`** — 🟥 **there is deliberately no open `skipped(<reason>)` value.** A free-text reason is an escape hatch: «skipped — pair obvious» would satisfy a presence check while doing none of the work. Deciding a lookup is unnecessary is not a skip, it is **ⓐ**, and it gets counted. A lookup or tool **failure** closes as `external-error` — a **NON-PASS**, never one of the three above | **mandatory-pass** |
| **Step 3-c pair ledger closes: `ⓐ + ⓑ + ⓒ + withheld == in-scope pair count`**, and ⓐ/ⓑ/ⓒ are assigned by tool-call evidence (none / local read / outward call), not by recollection | **measured** (counts come from the ledger and the session's tool history, not from memory) |
| **Step 3-c queries carried problem shapes, not harness/repo/path names** — and any pair that genuinely could not be abstracted is recorded as `withheld (residency)`, never dropped silently | **mandatory-pass** |
| **`harness-error` is a NON-PASS, not a third accepted state.** Reporting the error satisfies the anti-silence rule and nothing else — it does not clear this row. Surface it and stop; do not let a status string stand in for a result | **mandatory-pass** |
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
