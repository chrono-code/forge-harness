---
name: qp-plan
description: Prepare stage of QP — builds a surface inventory of a web page or desktop app (routes, menus, forms, dialogs), checks it is MECE (no overlap, nothing missing that is visible), and designs test cases as a TSV with preconditions and expected values whose SOURCE is named. Works without a spec document (then expected values come from the inventory, not a plan). Triggers on "what should I test on this page", "make a test plan for this app", "list the screens of this app", "테스트 케이스 뽑아줘", "이 화면 인벤토리 만들어줘".
user-invocable: true
allowed-tools: ["Read", "Bash", "Write", "Glob", "Grep"]
model: sonnet
origin: chamber run fh-qa-generic (2026-09-05)
---

# qp-plan — Prepare (inventory → MECE → TCs)

Input: a target that passed `qp_tools.sh target-class` (PUBLIC or PROFILE_OK) and an adapter line from `adapter-probe`. Optional: a plan/spec document path (`--plan <file>`). Optional profile.

## 1. Surface inventory — observe, do not guess
Open the entry route with the adapter (web: navigate + accessibility snapshot; desktop: screenshot). Record every **navigable surface** you can see: links/routes, menu items, buttons that open a dialog, forms, tabs. One row each:

```
| id | kind (route·menu·dialog·form·tab) | label as shown | how reached (from which surface, which action) | observed? (yes/no) |
```
Rules: ⓐ **do not invent routes** — a surface is listed only if you saw its trigger; ⓑ parameterised routes (`/item/:id`) are listed as `ROUTE_PARAMETERIZED`, not filled with a made-up id; ⓒ if the entry route did not load → stop with `HARNESS_ERROR reason=entry-unreachable`. Write `qp/plan/inventory.md` with the header lines `target-class: …` (the tool's literal output), `ADAPTER=… evidence=dom|pixel` (the probe's literal output), `engine=mcp-fallback` (or `engine=capability:<id>` only if the `qp` router found a registered capability — never a browser name; a floor-tier sim wrote `engine=chromium` when this line did not say so, 2026-09-05), `plan_doc: <path|NONE>`.

## 2. MECE check
Walk the inventory once more against the snapshot: any visible navigable element not in the list → add it (**missing**); any two rows reaching the same surface → merge (**overlap**). Write the count of each fix under `## MECE` in inventory.md. Zero fixes is a legitimate value; an unstated count is not.

## 3. Test-case design — `qp/plan/tcs.tsv`
Tab-separated, header row:
```
tc_id	surface_id	precondition	step_verb	step_target	expected	expected_source	priority
```
- `step_verb` ∈ `navigate click input verify` (one verb per row; a multi-step TC is several rows sharing `tc_id`).
- `expected_source` ∈ `PLAN_DOC INVENTORY CODE HUMAN` — **where the expected value came from**. With no plan document every row is `INVENTORY` (or `HUMAN` if the user told you). This field is what lets `qp-run` label a finding *differs from plan* vs *code differs*; a TC without it cannot be run.
- `precondition` is what must be true before step 1 (e.g. `at:/`, `logged-in`). Write `none` explicitly when there is none.
- **At least one TC must carry a state-changing verb (`click` or `input`)** — a verify-only plan never exercises the runner (`qp_tools.sh run-verbs` enforces this on the run output).
- Minimum: inventory ≥ 5 surfaces, TCs ≥ 3 for a first pass; say when the target is too small to reach that (a one-page site can be).

## Done When
1. `qp/plan/inventory.md` exists with the four header lines and ≥1 observed surface · **[mandatory-pass]**.
2. `qp/plan/tcs.tsv` parses: every row has 8 fields, `step_verb` and `expected_source` in their enums, ≥1 click/input row · **[measured]** — `awk -F'\t' 'NF!=8' tcs.tsv` prints nothing; `run-verbs` on the later verdicts is OK.
3. No surface in the inventory was invented (each has `observed? yes` or a `ROUTE_PARAMETERIZED` mark) · **[judged — pairing: a second session re-opens the entry route and diffs the inventory; the lane's residency/zero-constant grep on the plan files]**.

## Independently executable
Yes — bash + adapter. Does not need `qp-run`.
