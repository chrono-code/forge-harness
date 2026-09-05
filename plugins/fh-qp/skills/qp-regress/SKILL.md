---
name: qp-regress
description: Regression stage of QP — re-executes a previous run's test cases unchanged, computes surface_reach (how many TCs left the entry screen, as a ratio over ALL TCs), and reports the per-TC delta against the earlier run so a "no change" claim is per case, not an aggregate. Triggers on "did anything regress since last run", "re-run last week's QA pass", "compare this run with the previous one", "회귀 확인해줘", "지난 런이랑 비교해줘".
user-invocable: true
allowed-tools: ["Read", "Bash", "Write", "Glob", "Grep"]
model: sonnet
origin: chamber run fh-qa-generic (2026-09-05)
---

# qp-regress — Regression (re-run unchanged → surface_reach → delta)

Input: a baseline `qp/run/<ts>/` and the same `qp/plan/tcs.tsv`. Output: `qp/regress/<ts>/`.

## 1. Re-run unchanged
Execute the baseline's TCs with `qp-run` **without editing them**. Editing a TC to make it pass is a new run, not a regression — say so if the user asks for it.

## 2. surface_reach — did the batch leave the entry screen?
```
bash plugins/fh-qp/scripts/qp_tools.sh surface-reach qp/run/<new-ts>/evidence.tsv
```
| result | meaning |
|---|---|
| `REACHED n/n` | every TC observed a screen other than the modal (entry) one |
| `PARTIAL k/n` | some did — report **which** did not, by tc_id |
| `NOT_REACHED 0/n` | the whole batch sat on one screen (a login wall, a dead env). Every FAIL in that run is **unmeasured**, not a detection — write that sentence in the report |
| `UNMEASURED` (rc 10) | no evidence file / empty — not a zero |
Denominator is **all TCs**, including ones that never executed; write `surface_reach.txt` with the raw line.

## 3. Per-TC delta — `delta.tsv`
```
tc_id	baseline_status	new_status	changed	note
```
One row per TC. `changed=yes` on any status change **or** on a same-status verdict whose `closure` moved from MACHINE to JUDGMENT (the check got weaker). A run where every row is `changed=no` may say "no regression"; a run reported only as "12 PASS both times" may not — the aggregate hides a swap.

## 4. Report — `report.md`
First 8 lines: target · engine/adapter/evidence · `#mtm:` state · surface_reach line · counts PASS/FAIL/BLOCKED/AMBIGUOUS new vs baseline · number of `changed=yes` · the sentence for NOT_REACHED if it applies · what was **not** measured (unexecuted TCs, dropped screenshots).

## Done When
1. `surface_reach.txt` holds a `REACHED|PARTIAL|NOT_REACHED|UNMEASURED` line produced by the tool · **[mandatory-pass]**.
2. `delta.tsv` has one row per TC in the baseline · **[measured]** — row count equals distinct tc_ids.
3. A NOT_REACHED run's report contains the "FAILs are unmeasured" sentence · **[measured]** — grep.
4. The delta's `changed` column reflects real behavior change, not selector drift · **[judged — pairing: for each `changed=yes`, the before/after DOM snapshots are attached and a second session confirms the element moved, not the locator]**.

## Independently executable
Yes — needs a baseline run dir in the documented shape and bash.
