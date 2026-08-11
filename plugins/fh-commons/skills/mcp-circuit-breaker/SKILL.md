---
name: mcp-circuit-breaker
description: Detects MCP tool failure patterns and trips a circuit breaker to stop cascading retries. Proposes fallback alternatives and resets when the tool recovers. Triggers on "MCP failing", "tool keeps erroring", "circuit-breaker", repeated tool call failures.
user-invocable: true
allowed-tools: ["Read", "Bash", "Write"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - multi_server_failure
    - unknown_mcp_server
---

# mcp-circuit-breaker — MCP Tool Failure Guard

MCP tools can fail silently or return partial results, leading to cascading retry loops that waste tokens and degrade session quality. This skill detects failure patterns, trips a circuit breaker to halt retries, proposes alternatives, and resets when the tool recovers.

> **Scope distinction**
> - Claude Code native retry: low-level transport retries (transparent, fast)
> - mcp-circuit-breaker: **session-level guard** — detects repeated semantic failures, intervenes before token waste compounds

---

## Triggers

- `/mcp-circuit-breaker`
- "MCP failing", "MCP keeps erroring", "tool isn't working", "circuit-breaker"
- "same error keeps happening", "tool call looping", "MCP timeout"
- Automatic: when the same MCP tool name appears in 3+ consecutive failed calls within a session

---

## Circuit States

```
CLOSED   → Normal operation (tool calls pass through)
OPEN     → Circuit tripped (calls blocked, alternatives proposed)
HALF-OPEN → Recovery probe (1 test call allowed, resets if success)
```

Default thresholds:
- **Trip threshold**: 3 consecutive failures of the same tool
- **Half-open probe**: after 60s cooldown (or explicit user command)
- **Reset**: 1 successful call in HALF-OPEN state → back to CLOSED

---

## Execution Steps

### Step 1. Detect Failure Pattern

Identify the failing tool and failure mode:

```bash
# MCP mounts live in SEVERAL scopes — check all that this shell can see. Project settings.json is
# usually NOT one of them (it commonly holds hooks only), so a single-file read renders "no config"
# on a session with live MCP servers — a wrong-location instrument, not a measurement.
for f in .mcp.json .claude/settings.json .claude/settings.local.json; do
  [ -e "$f" ] && { echo "== $f =="; grep -A5 '"mcpServers"' "$f" 2>/dev/null || echo "(present, no mcpServers key)"; }
done
[ -e ~/.claude.json ] && grep -c '"mcpServers"' ~/.claude.json | xargs echo "user-scope ~/.claude.json mcpServers blocks:"
```

An empty result above means **"no project/user-scope config found"** — never "no MCP mounted":
plugin-provided and remotely-managed servers appear in no local file. The live mount evidence is the
failing tool call itself (`mcp__{server}__{tool}` in this session); classify from that name even when
every config read comes back empty.

Classify failure type:

| Type | Symptom | Likely Cause |
|---|---|---|
| `TIMEOUT` | Tool call hangs >30s | Server overload / network |
| `AUTH` | 401 / 403 response | Credentials expired or missing |
| `NOT_FOUND` | 404 / tool not available | Server down / tool removed |
| `MALFORMED` | Parse error on response | Schema mismatch / API change |
| `RATE_LIMIT` | 429 / quota exceeded | Too many calls |
| `ADMIN_GATED` | "instance admin approval required" / server pending org enablement / tool unavailable until approved | Capability exists; the **MCP mount** is gated behind instance/admin permission — not a transport failure. Retrying never recovers it (an admin must act) |

If failure type cannot be determined: classify as `UNKNOWN`.

> **`ADMIN_GATED` is not a retry case.** Distinguish *capability unavailable* from *MCP transport
> unavailable*: when the block is an org/admin approval dependency, do not burn retries — route straight
> to the lower-permission substitute in Step 4 (Priority 1b).

---

### Step 2. Trip Decision

Count consecutive failures of the identified tool in the current session context.

| Count | Action |
|---|---|
| 1 | Log warning. Continue — *"MCP tool {name} failed once. Monitoring."* |
| 2 | Escalate warning. Suggest checking server status. |
| 3+ | **TRIP CIRCUIT** → output circuit open notice, block further calls to this tool |

> **Non-transient types trip at count 1, not 3.** `ADMIN_GATED`, `AUTH`, and `NOT_FOUND` do not recover
> on retry (an admin must act / credentials must change / the tool is gone), so counting to 3 only wastes
> calls. On the first failure of one of these types, trip immediately and go to Step 4. The 1→2→3 ramp is
> for *transient* types (`TIMEOUT`, `RATE_LIMIT`) where a later call may succeed.

Circuit open notice format:
```
⚡ CIRCUIT OPEN — {tool-name}
Failure type: {TYPE}  |  Consecutive failures: {N}
Further calls to this tool are blocked until circuit resets.
```

(Blocking is **session-level discipline** — this skill's protocol, not a mechanical hook; no
PreToolUse gate enforces it. State it that way if asked — a protocol honestly labeled beats a
phantom enforcement claim.)

---

### Step 3. Log Circuit State

Write state to session-local file (in-memory is insufficient — logs survive /clear):

```bash
mkdir -p .claude/mcp_circuit/
grep -qxF '.claude/mcp_circuit/' .gitignore 2>/dev/null \
  || echo "NOTE: add '.claude/mcp_circuit/' to .gitignore — session state must not become a tracked file (the ignored-but-committed class public-surface-audit Step 3c hunts)"
cat >> .claude/mcp_circuit/circuit_log.yaml << EOF
- tool: {tool-name}
  state: OPEN            # OPEN | HALF-OPEN | CLOSED — same enum as Done When
  failure_type: {TYPE}
  failure_count: {N}
  tripped_at: {ISO-8601}
  reset_at: null
EOF
```

---

### Step 4. Propose Alternatives

Present the relevant fallback options ranked by effort (at least 3):

| Priority | Alternative | When to Use |
|---|---|---|
| **1 — Substitute tool** | Use a different MCP tool or built-in tool that covers the same task | Tool-specific failure (NOT_FOUND, AUTH) |
| **1b — Lower-permission API / workflow substitute** | The MCP mount is gated, but the underlying capability is usually still reachable through a member-scoped path: a Personal-Access-Token REST API call, or a workflow-automation runner. Before relying on it, confirm **credential scope** (a member-level token suffices?), **audit parity** (logged where the MCP path would log?), and **behavior gap** (what the MCP path does that this does not — e.g. natural-language workflow creation vs hand-written JSON). | `ADMIN_GATED` |
| **2 — Degrade gracefully** | Skip the MCP step, note the gap, continue with available information | TIMEOUT / RATE_LIMIT |
| **3 — Pause and retry** | Wait for server recovery (HALF-OPEN probe after cooldown) | Transient failure (TIMEOUT, RATE_LIMIT) |

> **Gating carries over to the substitute** (cross-ref the external-MCP tool-gating rule
> `templates/.claude/rules/mcp_tool_gating.md` — template path; if installed live, your repo's
> `.claude/rules/` copy). A REST/API or
> workflow-automation tool adopted under Priority 1b is still an external-action surface: classify its
> calls under the same ask/allow tiers — reads are `allow (untrusted-read)` only after behavior
> confirmation; any write / send / delete / permission-change stays `ask`. Trading a gated MCP mount for
> an ungated REST token does not lower the action's risk — only its permission barrier.

Output format:
```
## Fallback Options for {tool-name}

Option 1 — Substitute: Use {alternative-tool} instead
  → Command: [specific invocation]
  → Gap: [what's different vs. original tool]

Option 2 — Degrade: Skip this step, continue without {capability}
  → Impact: [what is missing from the output]

Option 3 — Retry after cooldown (60s)
  → Run: /mcp-circuit-breaker reset {tool-name}
```

---

### Step 5. Recovery Probe (HALF-OPEN)

When user requests reset or after cooldown:

```
Sending HALF-OPEN probe to {tool-name}...
```

- 1 minimal test call is allowed through
- If success: circuit → CLOSED, log updated
- If fail: circuit remains OPEN, cooldown resets

Reset log entry — **append as a NEW list item (`- tool:`), never as bare indented keys**:
```yaml
- tool: {tool-name}
  state: CLOSED
  reset_at: {ISO-8601}
  reset_method: probe_success | user_forced
```

> **Why the leading `- tool:` is load-bearing.** The Step 3 log is a YAML *list*. Appending indented
> keys with no `-` merges them into the **previous** item instead of adding one, and PyYAML resolves
> duplicate keys silently by keeping the last value — so `state: OPEN` is overwritten by `CLOSED` and
> the trip record disappears. Measured 2026-08-11: trip entry + bare-key reset entry parses to
> **1 item** with `state: CLOSED` (the OPEN row is gone); the same pair written as two list items
> parses to **2 items** with the trip history intact. The state history is what Step 6 reports on, so
> a merged entry silently zeroes the failure record.

---

### Step 6. Report

At session end or on demand:

```
## MCP Circuit Breaker Report

| Tool | State | Failures | Tripped | Reset |
|---|---|---|---|---|
| {tool} | OPEN | 4 | 14:23 | — |
| {tool} | CLOSED | 1 | 14:10 | 14:15 (probe) |

Recommendations:
- {tool}: AUTH failure → refresh credentials in .claude/settings.json
```

---

## Done When

- Failure pattern classified (type + count) — *judged* (adversarial pairing: an `UNKNOWN`
  classification must state which Step 1 config reads ran and came back empty — "couldn't determine"
  without the read evidence is not a classification)
- Circuit state logged to `.claude/mcp_circuit/circuit_log.yaml` (OPEN / HALF-OPEN / CLOSED) —
  *mandatory-pass*
- At least 3 fallback alternatives proposed when circuit is OPEN — *measured* (count ≥3)
- Recovery probe offered with reset path — *mandatory-pass*

---

## Chains

**Upstream** (can trigger this skill):
- Automatically activates on 3+ consecutive MCP failures during any task

**Downstream** (after circuit open):
- No mandatory chain — fallback options are presented, user decides
- Optional: `context-doctor` if MCP failure is due to large context degrading tool calls
