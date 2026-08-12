---
name: harness-doctor-detail
description: Detail file for harness-doctor — bash scripts for Steps 1~6 (L1~L4 diagnostics), L5 pattern analysis bash, Step 11 PR consistency check bash. Load when running diagnostic commands.
load: on-demand
---

# harness-doctor — Detail Reference

> Load when running diagnostic commands. SKILL.md contains layer descriptions, verdict tables, Done When, and trigger phrases.

---

## §Step-1-3 — Bash Scripts for Steps 1~5 (L1~L3 Diagnostics)

### Step 1. Confirm Diagnostic Target

```bash
# Check current cwd harness file structure
ls -la .claude/ 2>/dev/null || echo "NO .claude DIR"
ls -la CLAUDE.md .claudeignore 2>/dev/null
ls .claude/rules/ 2>/dev/null
ls .claude/agents/ 2>/dev/null

# tracks/ present = FH or hub environment
ls -d tracks/ knowledge/ plugins/ 2>/dev/null
```

### Step 2. L1 — Structural Completeness

```bash
for f in CLAUDE.md .claudeignore; do
  [ -f "$f" ] && echo "OK: $f" || echo "MISSING: $f"
done
[ -d ".claude" ] && echo "OK: .claude/" || echo "MISSING: .claude/"
```

### Step 3. L2 — Complexity Diagnosis

#### 3-1. CLAUDE.md Line Count

```bash
wc -l CLAUDE.md 2>/dev/null
```

#### 3-2. Rules File Unreferenced Detection

```bash
ls .claude/rules/*.md 2>/dev/null

find .claude/rules -maxdepth 1 -name '*.md' 2>/dev/null | while read -r f; do
  fname=$(basename "$f")
  grep -l "$fname" CLAUDE.md 2>/dev/null \
    && echo "REFERENCED: $fname" \
    || echo "UNREFERENCED: $fname"
done
```

#### 3-3. Duplicate Section Detection

```bash
grep -c "^##" CLAUDE.md 2>/dev/null
# 15+ sections = S-tier warning
```

#### 3-4. Periodic Skill Activity Check

```bash
# Check date of last weekly_audit file
latest_audit=$(ls -1t tracks/_audit/weekly_audit_*.md 2>/dev/null | head -1)
if [ -z "$latest_audit" ]; then
  echo "MISSING: no weekly_audit files"
else
  days_ago=$(( ( $(date +%s) - $(stat -f %m "$latest_audit" 2>/dev/null || stat -c %Y "$latest_audit") ) / 86400 ))
  echo "LAST_AUDIT: $latest_audit (${days_ago} days ago)"
  [ "$days_ago" -gt 30 ] && echo "OVERDUE_M: 30+ days without running" \
    || { [ "$days_ago" -gt 14 ] && echo "OVERDUE_S: 14+ days without running" || echo "OK: cycle normal"; }
fi

# Check last sim-conductor result file
latest_sim=$(ls -1t tracks/_meta/sim_*.md 2>/dev/null | head -1)
[ -n "$latest_sim" ] && echo "LAST_SIM: $latest_sim" || echo "INFO: no sim record (optional)"
```

### Step 4. L3 — Drift Diagnosis

#### 4-1. Broken File References

```bash
grep -oE '`[./][^`]+`' CLAUDE.md 2>/dev/null | tr -d '`' \
  | grep -vE '\*|[[:space:]]|^/[^/]+$' \
  | sort -u | while read p; do
      [ -e "$p" ] && echo "OK: $p" || echo "BROKEN: $p"
    done
```

#### 4-2. Stale Rules Detection

```bash
find .claude/rules/ -name "*.md" -mtime +90 2>/dev/null \
  && echo "STALE: 90+ day unmodified rules files exist" \
  || echo "OK: no stale"
```

#### 4-3. settings.json Validity

```bash
[ -f ".claude/settings.json" ] \
  && python3 -c "import json,sys; json.load(open('.claude/settings.json'))" 2>/dev/null \
  && echo "OK: settings.json valid" \
  || echo "BROKEN: settings.json syntax error"
```

#### 4-4. Hook Divergence Diagnosis

```bash
if [ -f ".claude/settings.json" ]; then
  hook_count=$(python3 -c "
import json, sys
try:
    d = json.load(open('.claude/settings.json'))
    hooks = d.get('hooks', [])
    print(len(hooks))
except:
    print(0)
" 2>/dev/null || echo 0)
  if [ "$hook_count" -gt 0 ]; then
    echo "HOOKS_FOUND: ${hook_count} hooks detected in settings.json"
    python3 -c "
import json
d = json.load(open('.claude/settings.json'))
for h in d.get('hooks', []):
    event = h.get('event', 'unknown')
    cmds = [c.get('command','') for m in h.get('matchers',[{}]) for c in m.get('hooks',[])]
    print(f'  HOOK: event={event} | commands={cmds[:2]}')
" 2>/dev/null
    echo "AGENT_VIEW_WARN: above hooks do NOT fire in Agent View (claude agents)"
    echo "  Prescription: replace hook-dependent behavior with explicit skills"
  else
    echo "OK: no hooks configured"
  fi
else
  echo "INFO: no settings.json — hook divergence diagnosis skip"
fi
```

### Step 5. L4 — Connection Diagnosis (FH only)

#### 5-1. Field Project Tracks Freshness

```bash
for d in tracks/*/; do
  last=$(find "$d" -name "*.md" -newer "tracks/.gitkeep" 2>/dev/null | wc -l)
  echo "$d: $last files modified recently"
done
```

#### 5-2. CATALOG.md Open Item Count

```bash
# An ABSENT CATALOG.md must not render as "0 open items" — that is the not-found-as-zero class this
# whole file exists to close, and the old form produced it twice over: `2>/dev/null` swallowed awk's
# error, and `grep -c … || echo "0"` printed a SECOND "0" on no-match (the counter already prints
# its own "0" before exiting non-zero). `|| true` is the safe fallback — it prints nothing.
if [ ! -f CATALOG.md ]; then
  echo "5-2 UNMEASURED: CATALOG.md not found — absent is not 'no open items'"
else
  open_count=$(awk '/^### /{count++} count<=5{print}' CATALOG.md | grep -c "^- Open:" || true)
  open_count=$(( ${open_count:-0} + 0 ))
  echo "5-2 Open items (5 most recent sections): ${open_count}"
fi
```

> Do not use `grep -c "^- Open:" CATALOG.md` — returns hundreds as false positives counting entire history.

#### 5-3. Field Project CLAUDE.md Existence

```bash
# The index file may not exist at all. `not found` != `0 problems` — an absent
# index must print MISSING INDEX, never an empty (= "all OK") result.
field_index=.claude/memory/reference_field_projects.md
if [ ! -f "$field_index" ]; then
  echo "MISSING INDEX: $field_index (5-3 UNMEASURED — not a pass)"
else
  grep -oE '`~/[^`]+`' "$field_index" \
    | tr -d '`' | sed "s|~|$HOME|g" | while read p; do
      [ -f "$p/CLAUDE.md" ] && echo "OK: $p" || echo "MISSING CLAUDE.md: $p"
    done
fi
```

> Known-pair calibration for this block: a **known-positive** path that does exist
> (`.claude/rules/fh_4axis_gate.md`) must print its `OK:`/`MISSING CLAUDE.md:` verdict, while an
> absent index must print `MISSING INDEX`. Do not add `2>/dev/null` back — it was what turned a
> non-existent directory into a silent zero-byte "everything is fine".

---

## §L5-Detail — Bash Scripts for L5-A, L5-B, L5-C

### L5-A Skill Activity (bash)

```bash
# SHELL PORTABILITY (2026-08-12, measured): the earlier form used `for f in $recent_sessions`.
# bash word-splits an unquoted parameter expansion on IFS; **zsh does not** (SH_WORD_SPLIT is off by
# default, and zsh is the macOS login shell these fences get pasted into). Under zsh the loop ran
# ONCE with the entire newline-joined list as a single filename, every grep missed, and this block
# reported EVERY skill as INACTIVE_90D — the harness declaring its own skills dead. Note the
# direction: not a permissive false clean, a false ALARM, which is why no lane caught it.
# `printf | while IFS= read -r` is the portable iteration; it is also correct for names with spaces.
# `grep -qi` (not `-li`) — `-l` printed each matching filename into the report as noise.
# `count=$(... | grep -c x || true)`: `|| true` PRINTS NOTHING, so it cannot produce the "0\n0"
# two-line disarm that `|| echo 0` produces (see the L5-C note below). Do not "simplify" it back.
recent_sessions=$(find tracks/ -name "session_*.md" -mtime -30 2>/dev/null)
if [ -z "$recent_sessions" ]; then
  echo "L5-A SKIP: no session records — re-diagnose after 30 days"
else
  sessions_90d=$(find tracks/ -name "session_*.md" -mtime -90 2>/dev/null)

  ls plugins/fh-meta/skills/ 2>/dev/null | while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    count=$(printf '%s\n' "$recent_sessions" | while IFS= read -r f; do
              [ -f "$f" ] && grep -qi "$skill" "$f" 2>/dev/null && printf 'x\n'
            done | grep -c x || true)
    count=$(( ${count:-0} + 0 ))
    if [ "$count" -eq 0 ]; then
      count_90d=$(printf '%s\n' "$sessions_90d" | while IFS= read -r f; do
                    [ -f "$f" ] && grep -qi "$skill" "$f" 2>/dev/null && printf 'x\n'
                  done | grep -c x || true)
      count_90d=$(( ${count_90d:-0} + 0 ))
      if [ "$count_90d" -eq 0 ]; then
        echo "INACTIVE_90D: $skill (no call record in 90 days)"
      else
        echo "INACTIVE_30D: $skill (no call record in last 30 days)"
      fi
    elif [ "$count" -lt 2 ]; then
      echo "LOW_ACTIVE: $skill (${count} times)"
    else
      echo "ACTIVE: $skill (${count} times)"
    fi
  done
fi
```

### L5-B Call Context Appropriateness (bash)

```bash
recent_sessions=$(find tracks/ -name "session_*.md" -mtime -30 2>/dev/null)
[ -z "$recent_sessions" ] && echo "L5-B SKIP: no session records" && exit 0

# hub-persona-auditor misuse: code PR or internal refactoring context
# `printf | while read`, not `for f in $recent_sessions` — zsh does not word-split a parameter
# expansion, so the `for` form scanned one bogus blob filename and reported "no misuse" every time.
printf '%s\n' "$recent_sessions" | while IFS= read -r f; do
  [ -f "$f" ] || continue
  if grep -q "hub-persona-auditor" "$f" 2>/dev/null; then
    context=$(grep -n "hub-persona-auditor" "$f" | head -3)
    echo "$context" | while IFS=: read linenum rest; do
      snippet=$(sed -n "$((linenum-3)),$((linenum+3))p" "$f" 2>/dev/null)
      if echo "$snippet" | grep -qiE "code review|PR review|refactoring"; then
        echo "L5-B MISUSE (suspected): hub-persona-auditor @ $f:$linenum — code PR context (false positive possible)"
      fi
    done
  fi
done

# sim-conductor misuse: first run without onboarding context
printf '%s\n' "$recent_sessions" | while IFS= read -r f; do
  [ -f "$f" ] || continue
  if grep -q "sim-conductor" "$f" 2>/dev/null; then
    context=$(grep -n "sim-conductor" "$f" | head -3)
    echo "$context" | while IFS=: read linenum rest; do
      snippet=$(sed -n "$((linenum-3)),$((linenum+3))p" "$f" 2>/dev/null)
      if echo "$snippet" | grep -qiE "first time|how do I|not sure how"; then
        echo "L5-B MISUSE (suspected): sim-conductor @ $f:$linenum — first run / no onboarding context (false positive possible)"
      fi
    done
  fi
done

# harness-doctor self-loop misuse
printf '%s\n' "$recent_sessions" | while IFS= read -r f; do
  [ -f "$f" ] || continue
  # `grep -c` prints 0 AND exits 1 on no-match, so `|| echo 0` appends a SECOND line
  # ("0\n0") and every later [ -eq/-gt ] test dies with "integer expression expected".
  # `|| true` keeps the exit code from killing the assignment without corrupting the value.
  count=$(grep -c "harness-doctor" "$f" || true)
  count=$(( ${count:-0} + 0 ))
  if [ "$count" -gt 2 ]; then
    echo "L5-B MISUSE (suspected): harness-doctor @ $f — self-loop suspected (${count} mentions in same session)"
  fi
done
```

### L5-C Effect Metrics (bash)

```bash
# E1: CLAUDE.md line count change
current_lines=$(wc -l < CLAUDE.md 2>/dev/null || echo 0)
past_lines=$(git show "HEAD@{30 days ago}:CLAUDE.md" 2>/dev/null | wc -l || echo "N/A")
if [ "$past_lines" != "N/A" ] && [ "$past_lines" -gt 0 ]; then
  delta=$((current_lines - past_lines))
  if [ "$delta" -lt 0 ]; then
    echo "E1_OK: CLAUDE.md ${delta} lines reduced"
  elif [ "$delta" -gt 50 ]; then
    echo "E1_WARN: CLAUDE.md +${delta} lines increased"
  else
    echo "E1_STABLE: CLAUDE.md ±${delta} lines"
  fi
else
  echo "E1_SKIP: git history < 30 days or no CLAUDE.md"
fi

# E2: Skill complexity ratio
total_lines=$(cat plugins/fh-meta/skills/*/SKILL.md plugins/fh-commons/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
skill_count=$(ls -d plugins/fh-meta/skills/*/ plugins/fh-commons/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$skill_count" -gt 0 ]; then
  ratio=$((total_lines / skill_count))
  if   [ "$ratio" -le 100 ]; then echo "E2_OK:   avg ${ratio} lines/skill (healthy)"
  elif [ "$ratio" -le 200 ]; then echo "E2_WARN: avg ${ratio} lines/skill (caution)"
  else                             echo "E2_FAIL: avg ${ratio} lines/skill (overloaded — separation or compression needed)"
  fi
fi

# E3: CATALOG.md Open item consumption rate
# NEVER use `grep -c ... || echo N/A` here: grep -c prints "0" and exits 1 on no-match, so the
# fallback appends a second line ("0\nN/A"), the != "N/A" test passes, and $(( )) then dies with a
# syntax error — the E3 line vanishes entirely (silent non-measurement, not a skip).
# Separate the two questions: (a) is history reachable at all, (b) what is the count.
current_open=$(awk '/^### /{count++} count<=5{print}' CATALOG.md 2>/dev/null | grep -c "^- Open:" || true)
current_open=$(( ${current_open:-0} + 0 ))
past_catalog=$(git show "HEAD@{30 days ago}:CATALOG.md" 2>/dev/null || true)
if [ -z "$past_catalog" ]; then
  echo "E3_SKIP: git history < 30 days or CATALOG.md absent then (UNMEASURED — not zero)"
else
  past_open=$(printf '%s\n' "$past_catalog" \
    | awk '/^### /{count++} count<=5{print}' | grep -c "^- Open:" || true)
  past_open=$(( ${past_open:-0} + 0 ))
  consumed=$((past_open - current_open))
  echo "E3: Open items consumed ${consumed} (30 days ago: ${past_open} → now: ${current_open})"
fi

# E4: harvest signals
signal_dir=tracks/_meta
signal_count=$(find "$signal_dir" -name "fh_signal_*.md" -newer "$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)" 2>/dev/null | wc -l | tr -d ' ')
echo "E4: harvest signals in last 30 days: ${signal_count} (target: ≥3)"

# E5: SKILL.md last change
last_skill_change=$(git log -1 --format="%ad (%ar)" -- "plugins/fh-meta/skills/*/SKILL.md" 2>/dev/null || echo "N/A")
echo "E5: SKILL.md last change — $last_skill_change"

# E6: Cold Audit last execution
last_audit=$(find "$signal_dir" -name "*cold_audit*" -o -name "*audit*" 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
if [ -n "$last_audit" ]; then
  last_date=$(stat -f "%Sm" -t "%Y-%m-%d" "$last_audit" 2>/dev/null || stat -c "%y" "$last_audit" 2>/dev/null | cut -d' ' -f1)
  echo "E6: last cold audit — ${last_date}"
else
  echo "E6_WARN: no cold audit history (30-day SLA recommended)"
fi

# E7: Evolution-loop blindness
manifest=tracks/_meta/edit_manifest.yaml
recent_asset_edits=$(git log --since="14 days ago" --name-only --pretty=format: 2>/dev/null \
  | grep -E "SKILL\.md|\.claude/rules/|^CLAUDE\.md" | sort -u | wc -l | tr -d ' ')
if [ ! -f "$manifest" ]; then
  [ "$recent_asset_edits" -gt 0 ] \
    && echo "E7_WARN: ${recent_asset_edits} asset edit(s) in 14d but no edit_manifest.yaml" \
    || echo "E7: no recent asset edits"
else
  # `grep -c` on zero matches prints "0" and exits 1 → `|| echo 0` made this "0\n0", the
  # -eq test then errored out (non-zero = false), and control fell through to the `||` branch:
  # E7_OK. The evolution-loop blindness detector was structurally unable to raise its own alarm.
  # `|| true` + arithmetic normalisation is what makes the WARN arm reachable.
  manifest_recent=$(grep -c "$(date +%Y-%m)" "$manifest" || true)
  manifest_recent=$(( ${manifest_recent:-0} + 0 ))
  if [ "$recent_asset_edits" -gt 0 ] && [ "$manifest_recent" -eq 0 ]; then
    echo "E7_WARN: ${recent_asset_edits} asset edit(s) in 14d but no manifest entry this month"
  else
    echo "E7_OK: edit_manifest.yaml present with ${manifest_recent} entr(ies) this month"
  fi
fi
```

> **Known-pair calibration (mandatory before trusting E7).** Run both arms:
> **negative arm** — point `manifest` at a file with no current-month entries while asset edits
> exist → must print `E7_WARN`; **positive arm** — the real
> `tracks/_meta/edit_manifest.yaml` → must print `E7_OK` with a non-zero entry count.
> If the negative arm prints `E7_OK`, the detector is dead and its silence means nothing.
> Note the `if/else` form: the old `[ ... ] && echo A || echo B` chain also falls to `B`
> whenever the *first* test is false, which is a second route to the same false pass.

---

## §Step11 — PR Change Consistency Check Bash Scripts

### 11-1. Detect Changed Files

```bash
# Two defects lived here and both produced phantom downstream counts:
#  (1) `return 0` is only valid inside a function/sourced script. Run as a plain block it
#      printed "can only `return' from a function" to stderr and CARRIED ON into 11-2A/B/C.
#  (2) `echo "" | wc -l` is 1, not 0 — so "no changes" was announced as "1 total".
# `exit 0` actually stops the block, and `grep -c .` counts non-empty lines only.
changed=$(git diff main..HEAD --name-only 2>/dev/null)
[ -z "$changed" ] && changed=$(git diff --cached --name-only 2>/dev/null)
if [ -z "$changed" ]; then
  echo "PR_CHECK: no changes detected vs main — skip (Step 11 UNMEASURED, run nothing below)"
  exit 0
fi
changed_count=$(printf '%s\n' "$changed" | grep -c . || true)
echo "=== Changed files ($(( ${changed_count:-0} + 0 )) total) ==="
echo "$changed"
```

> Steps 11-2A/B/C consume `$changed` and must not run when it is empty. If you inline this
> into a larger function, swap `exit 0` for `return 0` — but never leave a bare `return` in a
> block that is executed directly, which is what silently disarmed the guard.

### 11-2A. SKILL.md Changes → Count Drift + README + CATALOG

```bash
skills_changed=$(echo "$changed" | grep "skills/.*/SKILL\.md" || true)
if [ -n "$skills_changed" ]; then
  cat > /tmp/_fh_count.py <<'PYEOF'
import json, glob, os, re
def claimed_count(desc):
    m = re.search(r'(\d+)\s*skills', desc)
    return int(m.group(1)) if m else None
for src in sorted(glob.glob('plugins/*')):
    if not os.path.isdir(os.path.join(src, 'skills')):
        continue
    pname = os.path.basename(src)
    actual = len(glob.glob(os.path.join(src, 'skills', '*/')))
    pj = os.path.join(src, '.claude-plugin', 'plugin.json')
    if os.path.exists(pj):
        c = claimed_count(json.load(open(pj)).get('description', ''))
        if c is not None and c != actual:
            print(f"DRIFT: {pname} plugin.json says '{c} skills' but {actual} dirs")
        elif c is not None:
            print(f"OK: {pname} plugin.json count {actual} matches")
mp = '.claude-plugin/marketplace.json'
if os.path.exists(mp):
    for p in json.load(open(mp)).get('plugins', []):
        src = p.get('source', '').lstrip('./')
        actual = len(glob.glob(os.path.join(src, 'skills', '*/')))
        c = claimed_count(p.get('description', ''))
        if c is not None and c != actual:
            print(f"DRIFT: marketplace.json[{p['name']}] says '{c} skills' but {actual} dirs")
PYEOF
  python3 /tmp/_fh_count.py

  echo "$skills_changed" | while read sp; do
    sname=$(basename "$(dirname "$sp")")
    grep -q "$sname" README.md 2>/dev/null \
      && echo "OK: $sname in README" \
      || echo "MISSING: '$sname' not in README.md"
    grep -q "$sname" CATALOG.md 2>/dev/null \
      && echo "OK: $sname in CATALOG" \
      || echo "MISSING: '$sname' not in CATALOG.md"
  done
fi
```

### 11-2B. Agent File Changes → README + agent_cards.json

```bash
agents_changed=$(echo "$changed" | grep -E "agents/.*\.md" || true)
if [ -n "$agents_changed" ]; then
  actual_agents=$(find .claude/agents plugins/*/agents -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  readme_agents=$(grep -oE '[0-9]+ (fh-meta \+ [0-9]+ fh-commons )?agents?' README.md 2>/dev/null | head -1 || echo "not found")
  echo "Agent files: $actual_agents | README mentions: $readme_agents"
  if [ -f .claude/registry/agent_cards.json ]; then
    cards_count=$(grep -oE '"agent_count":[[:space:]]*[0-9]+' .claude/registry/agent_cards.json | grep -oE '[0-9]+')
    canonical_agents=$(find .claude/agents plugins/fh-meta/agents plugins/fh-commons/agents -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    [ "$cards_count" = "$canonical_agents" ] \
      && echo "OK: agent_cards.json count ($cards_count) matches tracked agent files" \
      || echo "DRIFT: agent_cards.json says $cards_count but tracked agent files total $canonical_agents — regenerate registry"
  fi
fi
```

### 11-2C. knowledge/shared/ Changes → CATALOG

```bash
knowledge_changed=$(echo "$changed" | grep "^knowledge/" || true)
if [ -n "$knowledge_changed" ]; then
  echo "$knowledge_changed" | while read kf; do
    fname=$(basename "$kf" .md)
    grep -q "$fname" CATALOG.md 2>/dev/null \
      && echo "OK: $fname in CATALOG" \
      || echo "MISSING: '$fname' not in CATALOG.md"
  done
fi
```

### 11-2D. README.md Changed → Stale References

```bash
if echo "$changed" | grep -q "^README\.md$"; then
  actual=$(ls -d plugins/fh-meta/skills/*/ plugins/fh-commons/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
  readme_count=$(grep -oE '[0-9]+ (fh-meta[^)]+)?skills' README.md 2>/dev/null | head -1 || echo "not found")
  echo "Actual skills: $actual | README mentions: $readme_count"
fi
```

### 11-2E. AGENTS.md / CLAUDE.md Changed → Cross-Reference

```bash
if echo "$changed" | grep -qE "^AGENTS\.md$|^CLAUDE\.md$"; then
  if [ -f AGENTS.md ]; then
    agents_in_file=$(grep -c "^##\? " AGENTS.md 2>/dev/null || echo "?")
    actual_agents=$(find .claude/agents plugins/*/agents -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "AGENTS.md sections: $agents_in_file | Actual agent files: $actual_agents"
  fi
fi
```

### 11-3. Step 8 — harvest-loop Integration

```bash
ls -1t tracks/_audit/weekly_audit_*.md 2>/dev/null | head -1
```

If latest weekly_audit exists → propose adding:

```markdown
### Harness Structure Check (harness-doctor)
- [ ] CLAUDE.md line count within threshold
- [ ] No broken file references
- [ ] Unreferenced rules files cleaned up
- [ ] Check tracks with no sync in 30+ days
- [ ] Review INACTIVE_30D skills (L5-A)
- [ ] Check suspected misuse patterns (L5-B)
- [ ] Review effect metrics E1·E3·E5 (L5-C)
- [ ] Hook divergence — create alternative for Agent View
- [ ] Harness-defect taxonomy: Context Drift · Schema Misalignment · State Degradation
```

### Step 9 — Eval-First Quantitative Gate (v0.x → v1 only)

```bash
latest_sims=$(find tracks/_meta/ -name "sim_*.md" 2>/dev/null | sort -r | head -5)
[ -z "$latest_sims" ] && echo "EVAL_SKIP: run sim-conductor 5 times first" && exit 0
echo "Target sim files:"; echo "$latest_sims"
# Manual review — aggregate correct-skill-selections / total per sim file
```

Thresholds: Tool Selection Accuracy > 0.90 · Multi-Step Coherence > 0.85 · Clarification Rate < 0.30.

### Step 10.6 — Cross-Skill Capability (syntax verification reuse)

F7 (bash -n parse) is a general-purpose syntax capability. Other skills reuse it:

| Skill | Purpose | Axis |
|---|---|---|
| harness-doctor Step 10 (this) | Regression detection — new syntax errors from change | *Backward* |
| steel-quench | Attack vector — "SKILL.md claims bash runs but has syntax errors" | *Adversarial* |
| phantom-quench | Phantom claim — code in docs that doesn't parse = fabricated example | *Forward* |

For shared utility: `templates/regression_guard.sh` — extract `count_bad_blocks` function or invoke with ref pair.
