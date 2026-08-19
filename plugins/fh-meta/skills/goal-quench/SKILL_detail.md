---
name: goal-quench-detail
description: Detail reference for goal-quench — one-time setup blocks, Phase 1 formats, queue format, Phase 3 verification bash, calibration record format. Load when executing a specific phase.
load: on-demand
---

# goal-quench — Detail Reference

> Load when executing a specific phase. SKILL.md contains the mode ladder, triggers, phase-by-phase behavioral rules, verdict mapping tables, simplification guards, chains, and Done When.

---

## §Setup — One-Time Setup Blocks

### Claude Code Runtime

Copy the hook snippet from `templates/goal-quench-hook-setup.md` and merge into your `.claude/settings.json`.

Add to `.gitignore`:
```
.claude/goal-quench.active
.claude/goal-quench.pending
```

**Hook failure fallback**: The Stop hook may fire silently without triggering verification (hook failure, session reset, or CC version differences). If Phase 3 verification has not run after /goal completes, manually trigger it:
> `/goal-quench --verify` — skips Phase 1+2, runs pipeline-conductor --quick using current session scope.

**Interrupted /goal recovery**: If /goal is interrupted (error, user abort, CC crash), the Stop hook may not fire — leaving `.claude/goal-quench.active` without a `.pending`. Detect and recover:
```bash
[ -f .claude/goal-quench.active ] && ! [ -f .claude/goal-quench.pending ] && echo "Interrupted — run /goal-quench --recover"
```
> `/goal-quench --recover` — promotes `.active` → `.pending` and runs Phase 3 verification on partially-completed work.

### Codex Runtime

Codex has its own goal/session capability. Do not replace it with goal-quench state files. In Codex-primary sessions:

1. Use Codex's native goal/session feature for goal control.
2. Use `fh-run` for any FH skill/agent sub-step that would otherwise require Claude Code `Agent(...)`.
3. After the Codex goal completes, run FH governance on changed files:

```bash
FH_BACKEND=codex npx --yes @chrono-meta/fh-gate@latest "{changed-files}" quick codex-goal
```

For non-interactive one-shot runs only, `fh-goal` can run a backend task and then invoke `fh-gate` automatically:

```bash
FH_BACKEND=codex npx --yes --package @chrono-meta/fh-gate@latest fh-goal \
  --prompt "{task}" \
  --gate quick
```

> **Pin the version spec — this is not cosmetic (measured 2026-08-12, npx 11.12.1).** An unpinned
> `@chrono-meta/fh-gate` resolves whatever npx already has cached, and a stale cache predates the
> `fh-goal` bin entirely: the previously-documented `npx --package @chrono-meta/fh-gate fh-goal …`
> exited **127 `sh: fh-goal: command not found`**, while `…@latest` exits 0. `--call` makes no
> difference (2×2 probe: both `--call` and bare forms are 127 unpinned, 0 pinned) — the version
> spec is the whole cause. The same stale cache silently ran **fh-gate v1.0.0** for the gate
> command above while `latest` was 1.4.95, and the two returned *different exit codes for the same
> input* (`1` vs `10` = harness-error). A gate whose version is whatever the cache happens to hold
> is not a gate. Confirm before relying on either command:
> `npx --yes @chrono-meta/fh-gate@latest --version`.

`fh-goal` is not a Codex goal replacement; it is a post-run governance wrapper.

---

## §Phase1-Blocks

### Pre-flight check bash (pro/max mode only)

```bash
for skill in context-doctor agent-composer; do
  [ -f ".claude/plugins/cache/forge-harness/fh-meta/"*"/skills/${skill}/SKILL.md" ] 2>/dev/null \
  || find ~/.claude/plugins -name "${skill}" -type d 2>/dev/null | grep -q . \
  || echo "WARNING: ${skill} not found — pro/max mode requires it. Falling back to core."
done
```

### token-budget-gate invocation contract

```
Input:  task description (one paragraph), target file count (approximate)
Trigger phrase: "estimate token budget for: {task description}"
Expected output fields:
  - estimated_tokens: N
  - verdict: GREEN | YELLOW | ORANGE | RED
  - reasoning: one-line basis for estimate
```

### State file format (`.claude/goal-quench.active`)

```
scope: {task description — one line}
mode: core | pro | max
target_files: {comma-separated file paths or directory; "inferred from git diff" if not known}
budget_estimate: {N} tokens
budget_source: token-budget-gate | fallback-heuristic
budget_verdict: {GREEN/YELLOW/ORANGE/RED}
pipeline_mode: {--quick for core/pro · --full for max}
composed_plan: {sub-goal list from Phase 1.5 agent-composer; "n/a" in core mode}
timestamp: {YYYY-MM-DD HH:MM}
session_pid: {$$}
start_commit: {git rev-parse HEAD}
```

### Mid-run budget threshold injection block (Phase 1 Step 4)

```
─── goal-quench budget thresholds (active for this /goal run) ───
50% of estimated budget consumed:
  → Output a one-line progress summary. No action required.

70% consumed:
  → YELLOW: re-prioritize remaining tasks. Drop lowest-priority items
    if the goal can still be met without them.

85% consumed:
  → ORANGE: stop current task, commit completed work, surface to user:
    "Budget at 85%. Completed: [X]. Remaining: [Y]. Continue / stop?"

95% consumed:
  → RED: stop immediately. Commit everything completed so far.
    Output: "Budget exhausted. Completed tasks: [list]. Incomplete: [list]."
─────────────────────────────────────────────────────────────────
```

### Hand-off output (Phase 1 Step 5)

> "goal-quench ready. Budget: {verdict} (~{N} tokens). Now run: `/goal {your condition}`
> When /goal finishes, the Stop hook will trigger pipeline-conductor --quick automatically."

---

## §Queue-Format

Sub-goal queue format (`.claude/goal-quench.queue`):
```
remaining:
  - sub-goal-1: {description}
  - sub-goal-2: {description}
completed: []
```

Output after agent-composer produces the Wave plan:

> "Sub-goal plan ready. Run each sub-goal in order by invoking `/goal-quench` again with the next sub-goal description. goal-quench will gate each sub-goal independently."

Sidecar fields written to `.active` (Phase 1.5 Step D):
```
sidecar: none | steel-quench-crossprovider | agent-composer-panel | sim-conductor | {cli-name}
sidecar_rationale: {one-line reason — which scope signal triggered this}
```

---

## §Phase3-Bash

### Freshness guard (next-response `.pending` check)

```bash
if [ -f .claude/goal-quench.pending ]; then
  PENDING_TIME=$(grep "^timestamp:" .claude/goal-quench.pending | sed 's/^timestamp: //')
  NOW=$(date +%s)
  PENDING_EPOCH=$(date -d "$PENDING_TIME" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M" "$PENDING_TIME" +%s 2>/dev/null)
  # UNPARSEABLE IS NOT STALE (2026-08-12). Without this guard, a missing `timestamp:` line or a
  # format neither `date` form accepts left PENDING_EPOCH EMPTY; the arithmetic below then failed,
  # `[ "$AGE_HOURS" -lt 4 ]` errored to stderr, control fell through to the `else`, and the run was
  # announced as "STALE … exit 0" — i.e. a pending verification was silently DROPPED and the third
  # branch (we do not know how old this is) was spelled the same way as the benign one.
  case "$PENDING_EPOCH" in
    ''|*[!0-9]*)
      echo "UNKNOWN AGE: .claude/goal-quench.pending has no parseable 'timestamp:' (got: '${PENDING_TIME}')."
      echo "  This is NOT 'stale' and NOT 'fresh' — the pending verification is still OPEN."
      echo "  Run /goal-quench --verify, or delete the file deliberately to clear it."
      exit 1 ;;
  esac
  AGE_HOURS=$(( (NOW - PENDING_EPOCH) / 3600 ))
  if [ "$AGE_HOURS" -lt 4 ]; then
    echo "goal-quench verification pending (created: $PENDING_TIME — ${AGE_HOURS}h ago)"
  else
    echo "STALE: goal-quench.pending is ${AGE_HOURS}h old. Run /goal-quench --verify to re-evaluate or delete to clear."
    exit 0
  fi
fi
```

### Verification flow (artifact resolution)

```bash
# Read scope and target from pending file
SCOPE=$(grep "^scope:" .claude/goal-quench.pending | sed 's/^scope: //')
TARGET=$(grep "^target_files:" .claude/goal-quench.pending | sed 's/^target_files: //')

# Resolve artifact: explicit target or git diff
# Use git diff against the commit recorded at Phase 1 start, NOT HEAD,
# to capture files changed during the entire /goal session including interim commits.
GOAL_START_COMMIT=$(grep "^start_commit:" .claude/goal-quench.pending | sed 's/^start_commit: //')
if [ "$TARGET" = "inferred from git diff" ] || [ -z "$TARGET" ]; then
  if [ -n "$GOAL_START_COMMIT" ]; then
    TARGET=$(git diff "$GOAL_START_COMMIT"..HEAD --name-only 2>/dev/null | tr '\n' ' ')
  else
    # Fallback: staged + unstaged changes (does not capture interim commits)
    TARGET=$(git status --short 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
  fi
fi
# Guard: reject empty target
[ -z "$TARGET" ] && echo "ERROR: cannot resolve verification artifact — no files changed or start_commit missing" && exit 1
```

### Codex path

No Stop hook is required. After the Codex goal/session completes, resolve changed files with git and run:

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate "{changed-files}" quick codex-goal
```

For high-stakes or external-facing work, use `full` instead of `quick`. Treat `BLOCKED` or `ESCALATE` the same as the Claude path: fix and re-run the gate, or surface the decision to the user.

---

## §Calibration-Record

After each goal-quench run, append to `tracks/_meta/goal_quench_{YYYY-MM-DD}.md`:

```yaml
- run_id: GQ-{YYYYMMDD}-{N}  # e.g. GQ-20260603-01 — unique per run, links to session JSONL
  session_id: "{first-8-chars-of-jsonl-filename}"  # for JSONL back-trace
  date: YYYY-MM-DD
  task: {one-line description}
  scope_hint: "{N files affected, task type}"  # e.g. "3 new files, signal doc"
  mode: core | pro | max
  session_type: minor | normal | heavy | continuation  # for within-type comparison
  estimated_tokens: N
  budget_source: token-budget-gate | fallback-heuristic
  actual_tokens: N  # from ~/.claude/projects/*/conversation*.jsonl or user-reported; "unknown" if unavailable
  estimation_error: over | under | accurate
  estimation_error_pct: "N%"  # e.g. "717%" — magnitude of under/over; omit if accurate
  actual_vs_estimate_ratio: N.N  # actual / estimated (e.g., 4.7 means actual was 4.7× estimate)
  budget_verdict: GREEN/YELLOW/ORANGE/RED
  pipeline_verdict: CLEAN/PENDING/BLOCKED/ESCALATE
  sidecar: none | steel-quench-crossprovider | agent-composer-panel | sim-conductor | {cli-name}
  sidecar_type: none | cc-subagent | external-cli  # cc-subagent = isolated Sonnet context; external-cli = untracked
  sidecar_model: none | sonnet | {model-name}  # standard baseline: sonnet; external CLIs vary by tier
  orchestrator_tokens: N | unknown  # Opus orchestrator CC tokens (pro/max only; visible in CC)
  sidecar_tokens: N | unknown  # Sonnet sub-agent CC tokens if cc-subagent; "untracked" if external-cli
  sidecar_findings_count: N  # 0 if sidecar=none
  threshold_triggered: none/50/70/85/95
  notes: {optional — why estimate was off, what scope changed}
```

**`actual_tokens` collection**: Claude cannot read session token counts directly. Preferred method:
```bash
python3 - <<'PY'
import json, glob, os, sys
# Transcript filenames are session UUIDs, NOT "conversation*.jsonl" — an earlier glob
# assumed the latter, matched zero files, and died on [-1] with IndexError, so the
# "actual tokens" field had no mechanical source at all. Verify with:
#   ls ~/.claude/projects/*/ | head
root = os.path.join(os.path.expanduser('~'), '.claude', 'projects')
files = glob.glob(os.path.join(root, '*', '*.jsonl'))
if not files:
    # not found != 0 — say so explicitly rather than reporting a zero token count
    print('actual_tokens: unknown  # no session transcript found under ' + root)
    sys.exit(0)
f = max(files, key=os.path.getmtime)   # newest by mtime; UUID names do not sort chronologically
total = counted = skipped = 0
with open(f, encoding='utf-8') as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            m = json.loads(line)
        except json.JSONDecodeError:
            skipped += 1          # count, never silently drop
            continue
        u = (m.get('message') or {}).get('usage') or {}
        total += u.get('input_tokens', 0) + u.get('output_tokens', 0)
        counted += 1
print(f'actual_tokens: {total}  # {os.path.basename(f)} · {counted} records, {skipped} unparseable')
PY
```
The newest transcript is not guaranteed to be *this* session's — treat the number as the session's
own only when the run just ended in this project. Fallback: turn count × estimated tokens/turn (~2K
for short turns, ~8K for long file edits). Write `"unknown"` if no estimate is possible — never `0`.

**Retrospective calibration baseline (N=10, 2026-06-01–06-03, Sonnet)**: mean actual/estimate ratio = 4.7× (range 1.3×–10.5×). Systematic underestimation due to session overhead. Full data held in the private companion store (`paper-signals/`).

After 10 additional prospective runs, compute mean estimation error per mode — calibrate the session_overhead_factor if systematic over/under persists.

`pipeline_verdict` enum includes `ESCALATE` — record it when Phase 3 required user decision before proceeding.

This data calibrates future estimates. Target: 10 prospective runs per mode before treating mode comparison as reliable. Runs with `budget_source: fallback-heuristic` calibrate the fallback tiers; runs with `token-budget-gate` calibrate the skill itself.
