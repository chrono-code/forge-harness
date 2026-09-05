---
name: qp-run
description: Automation stage of QP — executes the test cases from qp-plan against the live app through the session's adapter (Playwright MCP for web, computer-use MCP for desktop), records one verdict per step with a closed status, an MTM branch, whether the step was closed by machine evidence or left to judgment, and masks emails/tokens/passwords out of the evidence before saving. Triggers on "run these test cases", "execute the QA plan against the site", "drive the app through the TCs", "TC 실행해줘", "플랜대로 돌려줘".
user-invocable: true
allowed-tools: ["Read", "Bash", "Write", "Glob", "Grep"]
model: sonnet
origin: chamber run fh-qa-generic (2026-09-05)
---

# qp-run — Automation (execute → verdict → mask)

Input: `qp/plan/tcs.tsv` + the adapter/engine lines from `qp/plan/inventory.md`. Output dir: `qp/run/<YYYYMMDD-HHMM>/`.

## 0. MTM state — decide once, write it first
`#mtm:` is the first line of `verdicts.tsv`:
| value | when |
|---|---|
| `ACTIVE` | a plan document was given **and** you opened it (path recorded) |
| `UNAVAILABLE` | no plan document — expected values come from the inventory; the branch *differs from plan* is **unreachable** and the vocabulary collapses to AS_PLANNED / CODE_DIFFERS |
| `FAILED` | a plan document was given but could not be read — say so; do not fall back silently |
| `DISABLED` | the user turned it off (reason recorded) |
`UNAVAILABLE` and `FAILED` are different events; never merge them.

## 1. Precondition first — attribution, not blocking
Before step 1 of each TC, establish its `precondition`. Navigation you can do (`at:/about`) you do; state you cannot create (`logged-in`, `has-an-order`) you mark `UNMET_UNEXECUTABLE`. A step-1 failure under an unmet precondition is **`BLOCKED`**, not `FAIL` — you never reached the screen, so it is not a claim about the app. Only step 1 is re-attributed; later steps failed after arrival.

## 2. Execute each step, observe before and after
web: accessibility snapshot before → action → snapshot after. desktop: screenshot before/after. Save each observation as `<tc_id>_step<N>_{before,after}.{md,png}` and append its stable id from `bash plugins/fh-qp/scripts/qp_tools.sh screen-id <file>` (a content hash — Playwright MCP ref tokens change every navigation, so a raw file hash is NOT stable; measured 2026-09-05) to `evidence.tsv` (`tc_id<TAB>step<TAB>screen_hash`) — this file is what `qp-regress` reads.

## 3. Verdict row per step — `verdicts.tsv` (7 tab-separated fields)
```
tc_id	status	branch	closure	verb	assertion	expected_source
```
- `status` ∈ `PASS FAIL BLOCKED AMBIGUOUS` (AMBIGUOUS = could not map the step to one element: 0 candidates or a tie).
- `branch` ∈ `AS_PLANNED DIFFERS_FROM_PLAN CODE_DIFFERS NONE`. `DIFFERS_FROM_PLAN` only under `#mtm: ACTIVE` and only with `expected_source=PLAN_DOC`. `CODE_DIFFERS` needs `expected_source` `CODE` or `PLAN_DOC`. `NONE` only for BLOCKED/AMBIGUOUS.
- `closure` = `MACHINE` **only if** `assertion` names the check that closed it (`text-visible:About`, `url==…`, `element-count==3`). An empty assertion with `MACHINE` is invalid — that is the muscle-not-skeleton hole this field exists to close. Everything you decided by reading a screenshot is `JUDGMENT`.
- Validate before you finish: `bash plugins/fh-qp/scripts/qp_tools.sh mtm-check verdicts.tsv` must print `OK`; `run-verbs verdicts.tsv` must print `OK` (≥1 click/input actually executed).

## 4. Mask, then save — original 0
Every text artifact goes through `qp_tools.sh mask <in> <out>` and only `<out>` is kept; delete `<in>`. `RESIDUE` (rc 5) → do not keep the file; report which artifact. Typed secret values (from the profile's `*_env`) are read from the environment at type-time and never written. Screenshots that show a filled password field are kept only if the field is masked in the image (crop or overlay); otherwise drop the screenshot and say so.

## Done When
1. `verdicts.tsv` passes `mtm-check` and `run-verbs` · **[mandatory-pass]** — rc 0 both.
2. `evidence.tsv` has ≥1 row per executed TC · **[measured]**.
3. Masking: `grep -cE '@|Bearer|eyJ' <saved artifacts>` is 0 outside `__REDACTED_*__` markers · **[measured]** — the lane reproduces it on a known-dirty fixture.
4. Every BLOCKED verdict names its unmet precondition; every JUDGMENT closure says what was read · **[judged — pairing: `qp-regress` re-runs the same TCs and flags verdicts that flip without a DOM change; a second session reviews BLOCKED rows against the before-snapshots]**.

## Independently executable
Yes, given a `tcs.tsv` in the documented shape (hand-written is fine) and an adapter.
