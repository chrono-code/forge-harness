---
name: fh-integration-contract
description: FH governance gate interface specification — inputs, verdict format, findings schema, invocation patterns. Bridge layer item 3. Defines how OpenCode, OpenHuman, Hermes, and CI systems call FH gates and receive structured verdicts.
date: 2026-05-31
tags: [integration-contract, governance, opencode, hermes, openhuman, bridge-layer, v2-paper]
---

# FH Integration Contract

## Status

**v1.2 — Binary available.** `scripts/fh-gate.sh` executes governance review end-to-end via a selectable backend: `claude --print` or `codex exec`.
CI-ready: machine-parseable verdict + exit codes (0=PASS / 1=PENDING / 2=BLOCKED / 3=ESCALATE / 10=harness error).
Backward-compatible: `FH_DRY_RUN=1` restores prompt-only (v0.1) behavior.

---

## The Interface in One Diagram

```
Caller (OpenCode / OpenHuman / Hermes / CI)
    │
    │  provides: file list + diff path + gate level + caller ID
    ▼
FH governance gate (steel-quench + pipeline-conductor)
    │
    │  returns: verdict + findings list + record path
    ▼
Caller reads verdict, decides: merge / hold / escalate
```

---

## Input Specification

### Required

| Input | Form | Description |
|---|---|---|
| `FH_TARGET_FILES` | newline-separated file paths (one per line) | Files to review (changed by caller). Use newlines, not spaces — space-separation breaks on paths with spaces. |
| `FH_CALLER` | string | Identifier of calling system (`opencode` · `hermes` · `openhuman` · `ci`) |
| `FH_GATE_LEVEL` | `quick` or `full` | `quick` = Axes 2+3 only; `full` = all 4 axes |

### Optional

| Input | Form | Description |
|---|---|---|
| `FH_DIFF_PATH` | file path | Pre-generated diff file included as additional caller context |
| `FH_TASK_DESCRIPTION` | string | What the caller was trying to accomplish (context for adversarial pass) |
| `FH_SECURITY_LENS` | `on` or `off` (default `off`) | Force security-adjacent focus in steel-quench |
| `FH_BACKEND` | `claude`, `codex`, or `auto` (default `claude`) | Runtime backend. `auto` prefers Codex if installed, otherwise Claude |
| `FH_MODEL` | model id | Overrides backend default (`claude-sonnet-4-6` for Claude, `gpt-5.5` for Codex) |

### Capture pattern (caller's responsibility)

```bash
# Caller generates these before invoking FH:
# Note: newline-separated — do NOT use tr '\n' ' ' (breaks on paths with spaces)
FH_TARGET_FILES=$(git diff main..HEAD --name-only)
FH_DIFF_PATH=/tmp/fh_input_${FH_CALLER}_$(date +%Y%m%d_%H%M%S).diff
git diff main..HEAD > "$FH_DIFF_PATH"
FH_GATE_LEVEL=quick
FH_CALLER=opencode
```

---

## Verdict Specification

### Verdict values

| Verdict | Meaning | Caller action |
|---|---|---|
| `PASS` | No findings. Axes all green. | Proceed to merge / ship |
| `PENDING` | 1+ B-grade findings, or Axis 3/4 weak. No A-grade. | Proceed with awareness; log findings |
| `BLOCKED` | 1+ A-grade findings. Structural or security-critical. | Do not merge. Surface to developer. Re-run governance after fix. |
| `ESCALATE` | Ambiguous A-grade or out-of-scope for automated verdict. | Human decision required before merge. |

### Output format

FH writes verdict to stdout as structured text (human-readable + machine-parseable).
`FH_STATUS` is MANDATORY — it MUST precede the verdict so callers detect harness failures (LLM timeout, token exhaustion) that would otherwise silently appear as PASS.

```
FH_STATUS: SUCCESS
FH_GATE_VERDICT: PENDING
FH_CALLER: opencode
FH_TIMESTAMP: 2026-05-31T12:00:00Z
FH_FINDINGS_COUNT: 3
FH_FINDINGS_A: 2
FH_FINDINGS_B: 1
FH_RECORD_PATH: tracks/_meta/governance_log_2026-05-31.yaml
---
findings:
  - grade: A
    location: "prefix() lines 1-9"
    title: "Short-token overflow — allowlist pattern may not cover bare commands"
    evidence: "tokens.slice(0, arity) with arity=3 and len=2 returns 2 tokens; pattern 'git stash *' may not match bare 'git stash'"
    fix: "Add test: expect(BashArity.prefix(['git', 'stash'])).toEqual(['git', 'stash']); add explicit comment that slice handles overflow"
  - grade: A
    location: "ARITY table lines 24-161"
    title: "npx/opencode/claude absent — overly broad permission patterns"
    evidence: "All npx <package> commands receive same 'npx *' pattern; security model weakened"
    fix: "Add: npx: 2, opencode: 2, claude: 2, bunx: 2, uvx: 2"
```

**Key design decisions** (addressing Gemini Finding 1+2):
- Findings use YAML block (under `findings:` key) — NOT flat `FINDING_N_KEY: value`. This prevents delimiter ambiguity when `evidence` or `fix` spans multiple lines.
- `FH_STATUS: SUCCESS|ERROR` is mandatory first field — a missing or `ERROR` status means the harness itself failed (do NOT interpret as PASS).

### Parse recipe (for CI/CD integration)

```bash
# Parse verdict from FH output (file or stdin)
FH_OUT=$(cat /tmp/fh_verdict.txt)
STATUS=$(echo "$FH_OUT" | grep "^FH_STATUS:" | awk '{print $2}')
VERDICT=$(echo "$FH_OUT" | grep "^FH_GATE_VERDICT:" | awk '{print $2}')
A_COUNT=$(echo "$FH_OUT" | grep "^FH_FINDINGS_A:" | awk '{print $2}')

# Guard: treat harness failure as BLOCKED (fail-safe)
if [ "$STATUS" != "SUCCESS" ]; then
  echo "FH harness error — treating as BLOCKED (fail-safe)"
  exit 1
fi

if [ "$VERDICT" = "BLOCKED" ] || [ "${A_COUNT:-0}" -gt "0" ]; then
  echo "FH governance: BLOCKED — do not merge"
  exit 1
fi
```

---

## Invocation Patterns

### Pattern 1 — Manual invocation from Claude Code session

The primary form until binary is available. Run inside a Claude Code session:

```
Run FH governance pass (gate level: quick):
  Target files: $FH_TARGET_FILES
  Caller: opencode
  Security lens: on (arity.ts is permission-adjacent)

Steps:
  1. Read each file in target list
  2. Run steel-quench adversarial pass — behavioral edge cases, untested contracts, security assumptions
  3. Run pipeline-conductor --quick — 4-axis verdict
  4. Output structured verdict in FH_GATE_VERDICT format
  5. Log to tracks/_meta/governance_log_{date}.yaml
```

### Pattern 2 — Bash wrapper (approximation, no binary)

```bash
#!/usr/bin/env bash
# scripts/fh-gate.sh — FH governance wrapper (methodology layer only)
# Outputs a governance prompt to stdout for Claude Code to execute

set -euo pipefail

FH_TARGET_FILES="${FH_TARGET_FILES:-${1:-$(git diff main..HEAD --name-only)}}"
FH_GATE_LEVEL="${2:-quick}"
FH_CALLER="${3:-unknown}"

cat <<EOF
Run FH governance pass on: $FH_TARGET_FILES
Gate level: $FH_GATE_LEVEL | Caller: $FH_CALLER

Step 1: Read all target files
Step 2: steel-quench adversarial pass (behavioral edge cases, untested contracts, security assumptions)
Step 3: pipeline-conductor --$FH_GATE_LEVEL (4-axis: backward / adversarial / forward / record)
Step 4: Output in FH_GATE_VERDICT format (PASS / PENDING / BLOCKED / ESCALATE)
Step 5: Write findings to tracks/_meta/governance_log_$(date +%Y-%m-%d).yaml
EOF
```

Usage: `./scripts/fh-gate.sh "src/permission/arity.ts" quick opencode`

### Pattern 2-b — Binary wrapper with runtime backend

```bash
# Claude backend, backward-compatible default
npx --package @chrono-meta/fh-gate fh-gate "src/permission/arity.ts" quick ci

# Codex backend as primary reviewer
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate "src/permission/arity.ts" quick ci

# Portable wrapper: prefer Codex when installed, otherwise Claude
FH_BACKEND=auto npx --package @chrono-meta/fh-gate fh-gate "src/permission/arity.ts" quick ci
```

All backends must produce the same `FH_STATUS` / `FH_GATE_VERDICT` header. Missing or malformed output is a harness failure and must be treated as blocked by the caller.

### Pattern 2-c — Direct skill or agent run

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run --skill phantom-quench --file docs/foo.md
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run --agent fh-commons:quench-challenger --file plugins/fh-meta/skills/foo/SKILL.md
```

Use `fh-run` when a FH workflow references a Claude Code slash command or `Agent(...)` dispatch and the current orchestrator is Codex.

### Pattern 3 — Stop hook (automated post-session)

Add to project's `.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "FH_BACKEND=auto FH_TARGET_FILES=\"$(git diff main..HEAD --name-only)\" bash ~/projects/forge-harness/scripts/fh-gate.sh \"\" quick stop-hook >> /tmp/fh-governance-queue.txt"
      }]
    }]
  }
}
```

Check queue on next session start: `cat /tmp/fh-governance-queue.txt`

---

## Caller-Specific Guidance

### OpenCode → FH

OpenCode generates code fast. FH governance runs after generation, before review.

```bash
# After opencode run completes:
FH_TARGET_FILES=$(git diff main..HEAD --name-only)
FH_SECURITY_LENS=on  # OpenCode touches broad surfaces; security lens default on
FH_GATE_LEVEL=quick
```

Full chain: `hermes.opencode` → code generated → `fh-gate.sh` → verdict → `hermes.github-code-review` → PR with governance findings inline.

### Hermes → FH

Hermes dispatches FH governance as a step in multi-agent pipelines:

```
# In hermes skill workflow:
After code generation step:
  → Dispatch FH governance: Read fh-gate.sh, execute with target_files=$CHANGED
  → If verdict=BLOCKED: halt pipeline, surface findings to user
  → If verdict=PENDING: attach findings to PR body, continue
  → If verdict=PASS: proceed to github-code-review step
```

See `hermes-agent/skills/autonomous-ai-agents/opencode/SKILL.md` for the full Hermes→OpenCode→FH chain.

### OpenHuman → FH

OpenHuman's Memory Tree stores conversation history. FH audit target: memory entries that reference code paths or technical decisions.

```bash
# FH harvest-loop on OpenHuman memory:
FH_TARGET_FILES=$(find ~/.openhuman/memory -name "*.md" -newer tracks/_meta/last_harvest.marker)
FH_GATE_LEVEL=quick
FH_CALLER=openhuman
```

FH validates: are memory entries grounded? Do referenced paths still exist? Are technical claims still accurate?

### CI/CD → FH

Post-merge governance for AI-generated modules:

```yaml
# .github/workflows/fh-governance.yml (future)
on:
  pull_request:
    paths: ['**/*.ts', '**/*.py']

jobs:
  fh-governance:
    steps:
      - uses: actions/checkout@v4
      - name: FH governance gate
        run: |
          FH_TARGET_FILES="$(git diff origin/main..HEAD --name-only)" \
            bash scripts/fh-gate.sh "" quick ci
```

---

## Record Specification

Every binary governance pass writes a compact record entry for calibration and audit indexing. The complete findings block remains in stdout and should be captured by the caller or CI artifact when full detail is required.

```yaml
# tracks/_meta/governance_log_YYYY-MM-DD.yaml
- timestamp: 2026-05-31T12:00:00Z
  caller: opencode
  backend: codex
  model: gpt-5.5
  gate_level: quick
  verdict: BLOCKED
  findings_total: 3
  findings_a: 2
  findings_b: 1
  files:
    - packages/opencode/src/permission/arity.ts
```

Record path is included in every verdict output as `FH_RECORD_PATH`. This feeds `harvest-loop` calibration; full finding text should be retained from stdout when needed.

---

## What This Contract Does NOT Specify (Bridge Layer)

The following require a bridge/runtime layer beyond the file-based gate:

| Feature | Why deferred |
|---|---|
| REST API or webhook | Would require a server process — FH is file-based |
| Streaming verdict updates | Requires runtime; methodology layer is synchronous |
| Multi-file parallel governance | Possible via agent dispatch today; not formalized here |
| Verdict caching | No state store beyond `tracks/`; governance runs fresh each time |

The bridge layer (v1.0) will implement these. This contract is the specification they implement against.

---

## Version History

| Version | Date | Change |
|---|---|---|
| v0.1 | 2026-05-31 | Initial specification. Bash invocation patterns + structured verdict format. Empirical basis: arity.ts controlled trial. |
| v1.0 | 2026-06-01 | Binary available as `@chrono-meta/fh-gate` on npm. JS wrapper + fh-gate.sh CI-ready binary. |
| v1.1 | 2026-06-03 | Large-scale harness improvements. Banner update. Version alignment. |
| v1.2 | 2026-06-04 | Selectable Claude/Codex backend, `fh-run`/`fh-goal` runtime adapters, newline-preserving `FH_TARGET_FILES`, and implemented task/diff/security-lens inputs. |

---

## References

- `fh_opencode_governance_wrapper.md` — step-by-step usage guide (less formal, more tutorial)
- `fh_ecosystem_positioning.md` — ecosystem context + synergy map + v2 paper connection
- `tracks/_meta/` — governance logs written here on each gate run
- `multi_model_sidecar_strategy.md` — multi-model orchestration (related pattern)
- FH paper (Zenodo: 10.5281/zenodo.20397565) — harness-as-durable-layer thesis this contract operationalizes
