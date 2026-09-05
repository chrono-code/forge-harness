# fh-qp — QP (Quality Platform)

QP(Quality Platform) — qasp 의 PAR 를 도메인 상수 0 으로 옮긴 FH 동봉 플러그인.

> Namespace note: in the field harness's own documents «QP» has meant *QA-Prism* (a roadmap label). This plugin's QP is **Quality Platform** — a different name space; nothing here refers to that roadmap.

**What it is for**: you are inside Claude Code, you have a web page or a desktop app in front of you, and you want a repeatable **plan → run → regress** loop with a QA lens — not a one-off "click around for me".

## Install / prerequisites (read this first — the first run fails without them)

| you test | you need connected in this session | how QP detects it |
|---|---|---|
| a **web** page | Playwright MCP (`mcp__playwright__*`) — or the Claude-in-Chrome extension | `qp_tools.sh adapter-probe --need web` |
| a **desktop** app | computer-use MCP (`mcp__computer-use__*`) | `qp_tools.sh adapter-probe --need desktop` |
| a **mobile** app | — deferred; not supported | — |

No adapter → every stage stops with `HARNESS_ERROR` (exit 10, plus a `qp/HARNESS_ERROR.txt`). That is a typed non-pass, never a skip.
Nothing else to install: the plugin is four skills + one bash script; no Python, no npm packages.

## First command

```
/qp https://app.example.com/          # plan → run → regress, stops at the first HARNESS_ERROR
/qp plan https://app.example.com/     # one stage
/qp app:"Example App"                 # desktop (needs a profile — see below)
```
You get files under `qp/`: `plan/inventory.md` · `plan/tcs.tsv` · `run/<ts>/verdicts.tsv` + masked evidence · `regress/<ts>/surface_reach.txt` + `delta.tsv` + `report.md`. You succeeded when `report.md` exists and its first 8 lines name the engine, the MTM state and a surface_reach line.

## Public vs profile-required targets (zero domain constants)

The plugin ships **no** host names, app names, credentials or organisation words. A target that is not public (private IP, `localhost`, `*.internal`/`*.lan`/`*.local`, a bare hostname, or any desktop app) is `PROFILE_REQUIRED` (exit 4) until you supply a profile:

```
cp plugins/fh-qp/qp_profile.example.yaml <a gitignored path>/qp_profile.yaml   # fill hosts/apps, reference env vars for secrets
/qp https://private.example.internal/ --profile <that path>
```
The profile is the only place a target-specific constant may live, and it is yours, never the plugin's.

## Engine — form C (skills are canonical; machinery is pluggable)

1. **Typed capability** — if a QA harness registers a capability whose id ends in `:par`, QP calls its entry and merges constraints strictest-wins (`knowledge/shared/harness-core/capability_composition_contract.md`). **Status 2026-09-05: no such capability is registered anywhere** (FH registry and the field harness both checked — zero cap files). Registration is the field harness's move; until then this bridge is a declared slot. Asking for it explicitly (`--engine capability`) returns `HARNESS_ERROR reason=capability-not-registered`, not a silent fallback.
2. **MCP fallback** — the path that exists today. Every artifact header says `engine=mcp-fallback adapter=<name> evidence=dom|pixel`, so a reader can tell which edition produced the report.
3. Desktop through computer-use is the **weaker edition** (pixel evidence, no DOM): `verify` steps close by readable screenshot text only, surface_reach hashes screenshots. The report header says so.

## What is mechanical vs what is prose (honest boundary)

| check | where | closed by |
|---|---|---|
| target public / profile-required | `scripts/qp_tools.sh target-class` | exit enum 0/4/10 |
| adapter present | `adapter-probe` | exit 0/10 (unknown ≠ present) |
| evidence masking, residue 0 | `mask` | exit 0/5 |
| surface_reach (TCs beyond entry / all TCs) | `surface-reach` | REACHED · PARTIAL · NOT_REACHED · UNMEASURED |
| verdict record shape — status/branch/closure/verb enums, `MACHINE` needs an assertion, branch↔`expected_source` binding | `mtm-check` | exit 0/10 |
| ≥1 state-changing verb executed | `run-verbs` | exit 0/5 |
| **whether a label is TRUE** (is this really *code differs*?) | prose in `qp-run` | judgment — paired, not mechanised (a frozen rule would be tomorrow's ceiling) |

The last row is the honest residual: QP types *that* a verdict is attributable and non-vacuous, not *that* it is correct.

## Skills
| skill | stage | Done When (summary) |
|---|---|---|
| `qp` | router | target classified · adapter probed · every artifact carries `engine=`/`evidence=` |
| `qp-plan` | Prepare | inventory ≥1 observed surface · `tcs.tsv` 8 fields with `expected_source` · ≥1 click/input TC |
| `qp-run` | Automation | `verdicts.tsv` passes `mtm-check` + `run-verbs` · evidence masked, residue 0 |
| `qp-regress` | Regression | `surface_reach.txt` from the tool · one delta row per TC · NOT_REACHED sentence present |

## Lane
`bash scripts/test_fh_qp_lanes.sh` — known pairs for the three negatives (profile-required → refuse · no adapter → HARNESS_ERROR · dirty evidence → masked, residue 0), surface_reach four states, mtm-check good/bad, run-verbs, and a residency scan of the whole plugin (fail-closed if the scanner cannot run).

## Prior art this is built on (curated, not reinvented)
Playwright Test Agents (planner / generator / healer) and Playwright MCP do the exploring and the driving; Cypress UI Coverage and mabl cover page-level coverage; `page.screenshot({mask})` covers web masking. QP adds only the judgment layer on top: the verdict record contract (`mtm-check`), first-step BLOCKED attribution, surface_reach as a ratio over all TCs, and profile-gated targets.
