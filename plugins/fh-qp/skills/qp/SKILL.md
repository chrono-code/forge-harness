---
name: qp
description: QP (Quality Platform) router — takes a web URL or a desktop app name and runs the plan → run → regress loop (qp-plan, qp-run, qp-regress) end to end, or routes to one stage. Classifies the target (public vs profile-required), probes which adapter the session has (Playwright MCP for web, computer-use MCP for desktop), and writes every artifact with a typed engine/adapter marker. Triggers on "test this website for me", "run a QA pass on this app", "check the app end to end", "이 사이트 QA 돌려줘", "이 앱 테스트해줘", "회귀 돌려줘".
user-invocable: true
allowed-tools: ["Read", "Bash", "Write", "Glob", "Grep"]
model: sonnet
origin: chamber run fh-qa-generic (2026-09-05) — generic edition of a field QA harness's P·A·R loop; zero domain constants
---

# qp — Quality Platform router

One entry point for people who want to **dynamically test a web or desktop app with a QA lens from inside Claude Code**.
Three stages, each its own skill, each leaving files:

| stage | skill | you get |
|---|---|---|
| **P**lan | `qp-plan` | `qp/plan/inventory.md` (surfaces the app exposes) + `qp/plan/tcs.tsv` (test cases) |
| **A**utomation (run) | `qp-run` | `qp/run/<ts>/verdicts.tsv` + masked evidence (DOM snapshots or screenshots) |
| **R**egression | `qp-regress` | `qp/regress/<ts>/surface_reach.txt` + per-TC delta vs the previous run |

Glossary (one line each, because a first-time reader asked): **TC** = test case · **inventory** = the list of screens/routes/menus the app exposes · **MTM** = each finding is labeled *as planned* / *differs from the plan document* / *code differs* · **precondition** = what must already be true before a step runs (logged in, page loaded), checked not assumed — a failure before it is met is `BLOCKED`, not `FAIL` · **surface_reach** = how many TCs actually left the entry screen · **engine** = which machinery drove the run (see §Engine).

## Step 0 — classify the target (mechanical, never by eye)

```
bash plugins/fh-qp/scripts/qp_tools.sh target-class <https://… | app:NAME> [--profile <file>]
```
| result | rc | what you do |
|---|---|---|
| `PUBLIC` | 0 | proceed |
| `PROFILE_OK` | 0 | proceed with the profile |
| `PROFILE_REQUIRED` | 4 | **stop.** Say: *"this target is not public; QP needs a profile file — copy `plugins/fh-qp/qp_profile.example.yaml` to a gitignored path, fill the host/app, and re-run with `--profile`."* Do not improvise a run against a private host. |
| `UNKNOWN` | 10 | stop, report the target form QP accepts |

## Step 1 — probe the adapter (mechanical; unknown ≠ present)

List the MCP tool names this session actually has (from your tool list — do not guess), then:
```
bash plugins/fh-qp/scripts/qp_tools.sh adapter-probe --need web|desktop --tools "<comma-separated tool names>"
```
`ADAPTER=… evidence=dom|pixel` → proceed and **write that line into every artifact header**.
`HARNESS_ERROR` (rc 10) → **stop.** Write `qp/HARNESS_ERROR.txt` with the reason and tell the user which MCP to connect (Playwright MCP for web · computer-use MCP for desktop). This is not a pass and not a skip.

## Engine — typed capability vs MCP fallback (form C)

- If a QA harness has **registered** a typed capability whose id ends in `:par` (check `.claude/capabilities/**/*.cap` and `bash scripts/cluster_capability_scan.sh` when in an FH hub), call its `entry` and merge constraints **strictest-wins** (`capability_composition_contract.md`). Engine marker: `engine=capability:<id>`.
- Otherwise drive the target yourself through the adapter from Step 1. Engine marker: `engine=mcp-fallback adapter=<name> evidence=dom|pixel`.
- **As of 2026-09-05 no such capability is registered anywhere** — the fallback is the only path that exists. If the user explicitly asks for the capability engine (`--engine capability`) and none is registered → `HARNESS_ERROR reason=capability-not-registered`, never a silent fallback.
- Desktop (`evidence=pixel`) is the **weaker edition**: no DOM, so `verify` closes only by screenshot text you can read, and surface_reach hashes screenshots, not DOM. Say so in the report header.

## Step 2 — run the stages

`qp <target>` = plan → run → regress in order, stopping at the first `HARNESS_ERROR`. `qp plan|run|regress <target>` = one stage. Each stage skill carries its own Done When.

## Done When
1. Target classified with a `target-class` line recorded in `qp/plan/inventory.md` header · **[mandatory-pass]** — rc is the check.
2. Adapter probed and `ADAPTER=` or `HARNESS_ERROR` written to a file · **[mandatory-pass]** — file exists and matches the probe output.
3. Every artifact header carries `engine=` and `evidence=` · **[measured]** — `grep -L 'engine=' qp/**/*.md qp/**/*.tsv` is empty.
4. Stages chained in P→A→R order with no stage skipped silently · **[judged — pairing: the lane `scripts/test_fh_qp_lanes.sh` and the per-stage Done When files]**.

## Independently executable
Needs only `bash` + the session's MCP adapter. No other FH skill is required. Inside an FH hub the capability scan is optional.

## Not this skill
Mobile (deferred). Verifying FH itself (use FH's own gates). Fixing the app.
