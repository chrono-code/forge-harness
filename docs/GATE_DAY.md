# A day inside the gates — 2026-08-22, measured

> A worked example, not a benchmark. Two kinds of number appear below and they are **not**
> interchangeable: *reproducible* ones, which any reader can re-run from the commands at the bottom, and
> *attested* ones, which come from local operating records this repo deliberately does not ship. Every
> attested figure is marked as such. Where something was **not** measured, it says so instead of showing
> a zero.
>
> This document exists to answer one question concretely: *what does "a meta-harness with quality
> gates" actually do on an ordinary working day?* The answer is not flattering, which is the point.

## 0. This document was itself blocked, twice, by the thing it describes

Before publishing, this page was sent to a reviewer from a **different model family** with one
instruction: *does it practice what it sells?* It came back **BLOCK**, with two blockers that were both
correct:

- **A count was stale.** The section below originally said "six commits, seven PRs (six merged, one
  open)." Re-running the command returns **seven commits and seven PRs, all merged.** The harvesting
  pass had been correct *when it ran* — one PR merged in the interval — and the author copied the
  number forward without re-running the command. In a document whose first line promises command
  output, the flagship count was a recollection.
- **A "zero" was wrong in the flattering direction.** It claimed there are "zero lines of code
  validating `standpoint:` values." There are: a validator exists in the pre-commit hook and is called
  (control: a nonexistent function name returns zero hits). The true statement is narrower — the
  hook validates the **form**, not the **truth** — and the author had collapsed the two while
  translating, which made the repo look *less* mechanized than it is.

Author self-catches on both: **zero**. The second one matters more than the first: it shows the
collapse does not only run toward self-flattery — it runs toward whatever the author already believed.

## 1. What shipped

Seven commits merged to `main` across seven PRs — all seven merged — and six 4-axis markers. By kind:
two documentation corrections, one new gate, one wiring change, one release, two fixes. *(Six markers
against seven commits is not a discrepancy: the release commit carries no marker.)*

## 2. The gates blocked the author seven times — and the author caught none of them

The claim this section sells is **not** "we are careful." It is **the machine catches us.**

*(**Attested**: this table is read from the local completion log, not from shipped state.)*

| # | What caught it | What it caught |
|---|---|---|
| 1 | Resident-text admission gate | 11 lines added to an always-loaded rule file without stating *why* they must be resident |
| 2 | ①Soul field | The first delta had no success definition. Rather than backfill one, the marker records that it was missing |
| 3 | pre-commit confidentiality scan | The operator's real username reached a tracked file that is also an npm ship surface. From the commit body: *"without the gate this would have gone out"* |
| 4 | CHANGELOG format checker | The human-written heading and the format the checker reads had diverged. Commit body: *"the checker caught it, not my eyes"* |
| 5 | branch-claim gate | A branch was moved without refreshing its claim — at exactly the spot where the operator's own local rule says "if you moved, refresh" |
| 6 | Resident-text admission gate (2nd time, same day) | 13 lines of onboarding commentary |
| 7 | Marker residency lane | The `residency:` field appeared twice and the gate reads only the first line — so the second was not *rejected*, it was **invisible** |

An eighth defect was found the same day, and both the actor and the verb matter: **the author pushed
with a new lane left unwired, and CI was the first thing to notice.** CI did not block it — the
workflow is not a required status check — it reported it, after the push. That is simultaneously a
catch and a **violation of our own rule** — `CLAUDE.md §Local Execution First` says CI is a backstop,
never the discovery mechanism. The session recorded that against itself.

**All eight were external machinery or a different lens. Author diligence caught zero of them.**

What this eight does **not** count: there is reason to think the gates blocked us more times that day
than the record shows, but **the count is unmeasured** — no file records them. The absence check was
run with a control (the same grep does find the recorded items), so the instrument is alive and those
blocks are genuinely unrecorded. **They are not added to the eight, and no number is invented for
them.** ("Not found" is not zero.)

## 3. Six-axis verification — what the name promises vs. what actually ran

FH records a **status for each of six axes** on a change — including the axes it skipped, and why.
Axes are separated by **what the reviewer receives**, not by how
adversarial the reviewer is — if two reviewers receive the same thing, adding a third leaves the same
blind spot.

ⓐ model family · ⓑ standpoint (executed from the target harness's own position) · ⓒ isolated grounding
· ⓓ third-party confrontation · ⓔ first real use · ⓕ revert-and-observe.

Reading the `axes-run:` line of that day's six markers verbatim (**attested** — markers are local):

```
ⓐ family            3 / 6
ⓑ standpoint        value present 6 / 6 — but only 1 reached EXECUTION
                    (tier2 ×1 · tier1b ×2 · not-applicable ×3)
ⓒ isolated ground   2 / 6
ⓓ third-party       0 / 6
ⓔ first real use    3 / 6
ⓕ revert            2 / 6
```

The most any single delta burned was four axes; the least was zero.

**So "we verify every change on six axes" is false as a claim about that day's record.** Zero deltas
burned all six. What is true is narrower and is the actual product: **the six axes are a
discrimination table, and which axes a delta burned — and which it left empty — is committed as a
typed value.** The canon itself says *"you do not run all of them every time. Choose them against the
failure mode. Do not multiply — choose."*

*(The per-axis counts above are read from six markers against seven merged commits — see §1. The
release commit carries no marker, which is why the two sets differ.)*

### "Did not" is stored as a different value from "could not" and "did not look"

This is the mechanism, not the slogan. The cross-family field is a closed enum, and three different
failures get three different values: `DEGRADED_SINGLE_FAMILY` (could not) · `DEGRADED_PANEL_UNUSED`
(chose not to) · `UNKNOWN` (did not look). Free prose collapses all three — and once collapsed, **a
probe that was never run renders as "zero findings."**

That day's six: `panel(...)` ×3 and `DEGRADED_PANEL_UNUSED` ×3. Each of the three degraded ones wrote
grounds naming what was *not* probed. One added this to itself:

> 🟥 Even so, this is an unexamined axis — in other deltas the same session the sidecar kept
> producing "defects the repair left behind" in rounds 2 and 3, and there is no reason to think this
> delta was the exception.

The standpoint field on the same marker takes the same shape: *"what was skipped here was skipped by
choice, not by inability."*

### ⓓ is zero — and two of the entries claiming it were mislabeled

Two markers wrote `ⓓ = operator's direct proposal (third party)`. Under the canon that is not ⓓ. What
ⓓ receives is *a problem plus someone else's codebase*; operator input belongs to the ①Soul/intent
layer. The typed field (`thirdparty:`) is empty on all six, verified with a control — markers from
other dates do carry that field, so the grep is not dead. **Those two mislabels were caught by writing
this document, not by that day's machinery.**

## 4. Governor separation — required by the canon, and not followed that day

🟥 **The dominant fact about that day is that this separation was *not* observed.** By the session's
own record: the governor hand-edited six files, hand-dispatched subagents more than ten times and
stitched the results together by hand, and used the deterministic orchestration tool **zero times** —
in a session where at least three points needed it. One of the resulting defects is the CI-found one
above. The operator's verbatim assessment: *"I don't want a governor operated with this little
slack."* The canon already required the separation; the behavior did not follow. **The four cases
below are the exceptions, not the day's norm.**

**(a) The sidecar refused to converge, and the governor obeyed that verdict.**
Three rounds: R1 8 findings (S1 · A4 · B3) → R2 6 (S0 · A3 · B3) → R3 4 (S0 · A3 · B1). R3 returned
`not converged` **even though the finding count had dropped**, with the reason *"each repair is
creating fresh review surface — land one gate at a time."* Acting on that verdict, **only one of the
three gates built that round was landed.** The other two remain in the tree with one A-grade and one
B-grade finding open each. Convergence is judged by *whether anything changed that round*, not by
round count. *(Honest scope: those three rounds were a **single** model family. Other families saw
only the claims, never the code — that axis is unexamined, not clean.)*

**(b) A B-grade finding turned out to be A-grade while being repaired.**
Changing directory to an empty string is a no-op **SUCCESS** in bash — so a lane that was supposed to
run in an isolated tree was running **in the real repository**. The underlying "zero results means a
dead instrument" control is structurally blind to this shape: the lane *did* run. It ran against the
wrong target.

**(c) A control was always false.**
One control asked whether a string equals *itself plus a suffix*. That cannot happen. Proven by 1000
random inputs firing zero times, with a control-for-the-control in the same run showing that an
ordinary equality comparison does fire. The old control had been passing a degraded state as green,
silently.

**(d) A blind simulation overruled the governor's own judgment.**
Forge metaphors were added to the onboarding door subtitles. A blind sim (floor tier, cwd outside the
repo, reps=3 × 2 arms): routing did not break — option count and intent-routing were **3/3 identical**
between arm and control. But on *"what was confusing?"* the **arm alone named that vocabulary 3/3**.
It was reverted. The sim also reported its own defect: it asked a "first-time user" question while
showing the returning-user menu, so the returning door is **unmeasured**.

*(Word choice note: "blind sim" here means the review procedure, run by hand. It is not the
orchestration tool named in the paragraph above — that tool ran zero times.)*

## 5. What honesty cost that day — including the parts with a person as the subject

Four items where the subject is an instrument:

- **`UNCALIBRATED` was left standing.** A checker returned PASS in an isolated tree, but the
  known-positive planted for it never fired (that checker does not scan the workflow directory). So
  the record says **that PASS says nothing about this delta**, and the verdict was carried by a
  different checker instead.
- **A completeness claim was retracted** — "reachable executing runner" was narrowed to "runner(s)
  matching the reachable-invocation **form**," with a §NAMED LIMITS block attached.
- **A 191-line evidence passage was cut to 41 lines** in a separate delta, because measurement
  refuted it. The rule itself was kept; only its grounds were withdrawn.
- **`panel(...)` does not mean uniform quality.** One sidecar that day had a scratchpad as its working
  directory and read **stale files**. The marker's controls field records it.

And four where the subject is **us** — recorded because a self-failure list with only instruments in
it is the softer, less useful kind of honesty:

- **A measurement with zero discriminating power was planted in three files at once.** The control had
  been chosen as "does it exist," so the known-negative that mattered was never measured. Self-caught:
  **zero** — a different-family review named it.
- **The same disease recurred within the hour** — asserting which process had produced a copy, without
  separating two competing hypotheses. It was the exact shape that had been pointed out one turn
  earlier.
- **A negation was inverted while quoting a rule** — "this is sequencing, **not** parallelism" was
  written back as "it is." The rule now reads as its own opposite; the slip changes nothing mechanical
  and everything semantic.
- **The dispatch ledger was written in bulk at close.** The rule says *immediately after each
  dispatch*. It sat at zero for the whole session — 66 entries — and the close check caught it.

## 6. Remaining holes, by name

- **`standpoint:` is validated for form, not for truth.** A validator in the pre-commit hook checks that
  the value is in the closed enum and that its grounds are non-empty. Nothing checks whether the value
  is *correct* — a delta that reads a target's files and records `tier2` (which asserts execution) will
  pass. (An earlier draft of this line said "zero lines of code," which was wrong; see §0.)
- **The hook closed the form, not the truth.** It checks that a value is in the list and that grounds
  are non-empty; it does not check whether the value is *true*. The direction that closes it is a
  different model family reading the marker — not scoring ourselves more diligently.
- **A wrong `git switch` is still unblocked.** The gate sits at commit time; the accident happens
  before it.
- **`thirdparty:` is an optional field**, so the ⓓ=0 above is not a gate violation. Not-a-violation and
  measured are different things — this is unmeasured, not zero.

## 7. One line

In one day the gates blocked the author seven times and the author self-caught zero, and an eighth
defect was found late, by CI, in violation of our own rule about CI. The record of all of that was
also produced by machinery, not by the author's memory. That is the entire claim of this document.

---

**Sources.** Reproducible by any reader with the repo:

```bash
# Pin the timezone explicitly — a bare date is resolved against the reader's local zone,
# and this day's boundary commits land on either side of it depending on where you are.
git log --after='2026-08-22T00:00:00+09:00' --before='2026-08-23T00:00:00+09:00' \
        --oneline main                                             # 7 commits: b750491..c67900f
gh pr list --state all --search "created:2026-08-22"               # 7 PRs, all MERGED (#498–#504)
bash scripts/lane_runner_check.sh
# → PASS lane-runner: 67 suites — 67 wired · 1 exempt · 0 declared debt · self-test: 14/16 wired
```

⚠️ The per-axis counts, the gate-block table and the self-failure list come from `tracks/_meta/`
(4-axis markers, the completion log, the session signal file). **That directory is gitignored** — it
is local operating record, not shipped state — so a reader cannot open those files. The three commands
above are the reproducible part; the rest is attested, and this note exists so the difference is not
blurred.
