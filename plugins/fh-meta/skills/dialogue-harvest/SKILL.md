---
name: dialogue-harvest
description: Mines improvement insights from long-form AI dialogue logs and long texts — an external or pasted corpus, not the current session (current-session wrap-up belongs to harvest-loop). First operation is sycophancy removal — separates speakers, strips the counterpart's agreement/restatement spans, converts the user's own utterances into falsifiable propositions, and labels each proposition induced (frame first introduced by the counterpart) or independent (originated with the user). Ships a drop counter so removed material is visible, never silently lost. Triggered by "mine insights from this chat log", "이 대화록에서 통찰 캐줘", "strip the agreement and show me what's actually mine", "동조 걷어내고 알맹이만", "what did I actually contribute in this thread".
user-invocable: true
allowed-tools: ["Read", "Grep", "Glob"]
model: sonnet
---

# dialogue-harvest

Extracts the load-bearing propositions from a long AI-human dialogue (or long text) after
removing the counterpart's sycophancy. Fills the gap between FH's loading assets
(corpus-grounding-expander, video-ingest) and its mining assets (frontier-digest = feed items,
field-harvest = git history, harvest-loop = session records): none of those mines an *argument-shaped*
corpus, and a naive summarizer run on an AI dialogue returns "the user made several excellent
points" — worthless, because most of the volume is agreement.

**Why the first operation is sycophancy removal**: AI dialogue logs are dominated by agreement and
restatement. Without stripping them first, extraction inflates the user's contribution; without
provenance labeling (Step 4), "my insight" and "a frame the counterpart planted" are
indistinguishable — which is exactly the failure this skill exists to prevent.

## Triggers
- "mine insights from this chat log" / "이 대화록에서 통찰 캐줘"
- "strip the agreement and show me what's actually mine" / "동조 걷어내고 알맹이만"
- "what did I actually contribute in this thread" / "이 대화에서 내 몫이 뭐였지"
- "turn this dialogue into propositions" / "이 대담 명제로 정리해줘"
- `/dialogue-harvest {path or pasted log}`

**Boundary**: wrapping up the *current session* → `harvest-loop`; this skill mines an
external/pasted dialogue corpus.

## Step 0. Input Acquisition

1. **Path provided** → Read the file.
2. **Pasted log** → use as-is.
3. **No speaker structure detectable** (no turn markers, no names, no quoting pattern) → stop and ask:
   > Speaker separation is the first operation and it needs turn boundaries. Who said what?
   > (Provide turn markers, or confirm the text is single-author — single-author texts skip
   > Steps 1–2 and go straight to proposition-ization.)

**Single-author path**: skip Steps 1–2, Step 4 stamps every proposition **independent** (no
counterpart exists), and the Step 6 counterpart sections read `n/a`.

## Step 1. Speaker Separation (mechanical when markers exist)

Split the log into turns and attribute each to USER or COUNTERPART. If markers are absent but
inference is possible, proceed and stamp the output header `speaker-inference: judged` — never
present inferred attribution as given.

## Step 2. Sycophancy Strip (one grep-able + two judged classes, drop-counted)

Remove COUNTERPART spans in these classes, **counting every removal by class**. Only the first
class is mechanical; the other two are judgment calls and their drops are marked `(judged)` in the
counter — never presented as grep certainty:

| Class | Check | Detection |
|---|---|---|
| Praise/agreement lexicon | grep-able | grep for praise-class tokens (sharp/brilliant/exactly right/정확한 지적/탁월한/완벽한 …) — extend the pattern list per corpus language |
| Restatement | judged | counterpart paragraph whose content substantially re-says the user's immediately-preceding utterance (high term overlap, no new claim) |
| Closing filler | judged | session pleasantries carrying no claim |

**Multi-class span**: a span matching more than one class is counted **once**, under the first
matching class in the table order above.

**Drop counter is mandatory**: silent drops are material loss (the qasp loader precedent — unused
material does not scream). Every stripped span and every non-propositional user turn appears in the
Step 6 accounting. Counterpart turns that *introduce a frame or claim* are **retained** — they are
the provenance source for Step 4, not noise.

**Language note**: the praise-token list is language-specific. On a corpus language not yet in the
list, extend the patterns first, then **construct (or use, if shipped) a known pair in that
language** and re-run calibration — re-running an English-only pair after adding Korean tokens
exercises nothing (vacuous pass). An ASCII-token scan over a Korean corpus is the measured
false-positive precedent. `calibration_pair.md` ships English + Korean sections.

## Step 3. Proposition-ization (user utterances only)

Convert each remaining USER utterance into a falsifiable statement (a form you can ask true/false
of), keeping a source reference (turn id / line) per proposition. Meaning must not drift: the
proposition is a compression of the user's claim, not an improvement of it.

## Step 4. Provenance Labeling — induced vs independent (the differentiator)

For each proposition, find the **first occurrence** of its core frame/key terms in the log:

- First occurrence is in a USER turn → **independent**.
- First occurrence is in a COUNTERPART turn (the user then adopted/echoed it) → **induced**.
- Ambiguous (shared vocabulary, gradual convergence) → label **induced?** — the degrade direction
  is toward the induced flag, because mislabeling a planted frame as "my insight" is the harm this
  skill exists to catch; the reverse error only costs modesty.

Counterpart-authored content the user *selected* as valuable is listed separately, marked
"selection, not authorship" — selection is a real act but must not be recorded as the user's claim.

## Step 4-b. Cross-Corpus Provenance — the single-author mode (measured need, 2026-07-26)

Step 4 asks *"who first said this — the user or the counterpart?"* On a **single-author corpus**
(a video transcript, an article, a talk) there is no counterpart, so every proposition is stamped
`independent` **for free** and the differentiator does not fire at all. The first real-corpus run
measured exactly that: 12 propositions, 12 free labels, zero discrimination.

On a single-author corpus the load-bearing provenance axis is not *within* the document — it is
**between the corpus and the assets that were supposed to consume it**:

> *Which of these propositions reached our own assets, and which did we hold and never use?*

**Run it when** the corpus is single-author AND a downstream asset on the same topic exists.
Skip (and say so) when there is no plausible consumer — the question is meaningless without one.

1. **Name the consumer asset(s)** explicitly in the output header. Guessing is not allowed;
   an unnamed consumer makes every verdict unfalsifiable.
2. **Grep locates candidates; the label is assigned by reading them.** A hit count is never a
   verdict — a consumer that says *"we do not use kill switches"* matches the same pattern as one
   that adopts them. So:
   - **absorbed** — requires **quoting the supporting span** from the consumer. No quote, no
     `absorbed`. (A count-only `absorbed` is the same defect as a whole-file parity grep going
     green on a line that says "excluded" — measured in this repo the same day.)
   - **held-unused** — absent from the consumer though the corpus has been in-house since {date}.
     Before writing it, **try at least two term variants** (synonym / abbreviation / the concept
     re-said in the consumer's own vocabulary). Concepts get absorbed under different words; a
     literal-match zero is weak evidence of absence.
   - **declined** — absent *because a named asset records a decision against it*. Cite the decision.
     This tier is mandatory and load-bearing: without it, a re-proposal reopens a settled call
     as if it were an oversight. (First run hit this immediately — stagnation-triggered stopping
     was `held-unused` by grep and `declined` in fact, recorded in `hub_maturity_roadmap.md`.)
   **Automation is prohibited here**: the first run produced 2 false positives out of 12, both
   caught only by opening the matched line.
3. **Report the ingestion-to-citation gap** — corpus in-house date vs first citation by any asset.
   A corpus with **zero citations** is the finding, not a null result.

**Instrument discipline (mandatory-pass, learned on the first run — four failures in one session):**
a **known-positive control** runs beside every measurement and its result is printed. A bare zero is
not publishable.

⚠️ **The control must be a separate search, not an alternation bolted onto the target pattern.**
`grep -E "core_term|title"` satisfies "a control ran" while proving nothing: `title` matches, the
command exits 0, and a malformed `core_term` still silently matches nothing. That is a vacuous pass.
The control's job is to prove **this pattern form, on this target, through this shell** can return a
hit at all — so run the *same pattern shape* against something you know contains it, as its own
command, and print both numbers. The four measured failure modes:
BRE `\|` inside an ERE pattern · unquoted `$VAR` under zsh (no word-splitting) · a stale `cd` making
paths unresolvable · substring collision (`install` contains `stall`). Each produced a *confident,
wrong* zero; each was caught only by the control. Do not redirect stderr away — three of the four
announced themselves there.

**Degrade direction — and the skip/degrade boundary, which must not be a matter of taste.**
`skip (N/A)` and `UNCALIBRATED` are **different states with different triggers**, and the boundary is
mechanical because otherwise the cheaper exit wins under time pressure:

| Situation | State | Why |
|---|---|---|
| Corpus is multi-speaker | **N/A** | Step 4 already answered provenance; 4-b's question does not arise |
| A consumer search was **run and recorded**, and no asset on the topic exists | **N/A**, quoting the search | A real negative, not a failure |
| A consumer is **named but does not resolve** (bad path, missing file) | **UNCALIBRATED** | Never N/A — a broken pointer is a tooling failure wearing absence's clothes |
| The known-positive control returns zero | **UNCALIBRATED** | The instrument is not measuring |
| No search was run | **UNCALIBRATED** | "I didn't look" is not "nothing is there" |

Under `UNCALIBRATED` the step emits **no** absorbed/held-unused/declined labels at all — a provenance
verdict is a claim about what an organization did with knowledge, and an uncalibrated one is worse
than none. Under `N/A` the step states the reason **and the search that established it**.

⚠️ **Known weakness, stated rather than papered over**: a hurried session's natural pull is to grep a
nearby-but-plausible file and report against it without flagging the substitution. The Sonnet
floor-sim of this step reached `UNCALIBRATED` correctly *and* named that same failure as the more
likely one in practice. The forcing function is the control returning zero alongside the
measurement — which is why the control is mandatory-pass and not advice.

## Step 5. Verification-Status Column

Each proposition gets a status: mechanically checkable / falsifiable-but-untested /
unfalsifiable (axiom-only use) / speculation. Unfalsifiable propositions are still listed — flagged
so they are never later cited as established facts.

## Step 6. Output + Accounting + Routing (proposal-only)

```
[dialogue-harvest output]
Corpus: {source}  |  speaker-inference: given | judged
calibration: run-this-session | previously-verified {date}   ← declare every run (L2 guard)
── Propositions ──
| # | proposition | source ref | provenance | verification status |
── Counterpart-originated (selection ≠ authorship) ──
| item | first-occurrence ref |
── Accounting (mandatory identity, turn-based) ──
user turns N = propositionized turns + dropped turns (dropped listed by reason)
propositions total: P (a turn may yield several — counted separately, never forced 1:1)
counterpart spans stripped: {count by class, judged classes marked} · retained as frame-source: {count}
── Routing proposals (no auto-write) ──
{insight → fh_signal / memory / CHAMBER-CANDIDATE / project track — one line each, operator decides}
```

Routing is **proposal-only**: this skill writes nothing outside its output block.

## Done When

- **Accounting identity holds** — user turns = propositionized turns + dropped turns, both lists
  visible; proposition total reported separately (a turn may carry multiple propositions)
  (check-class: **mandatory-pass**, mechanical count).
- **Every proposition carries a source ref + provenance label** (independent / induced / induced?)
  (check-class: **mandatory-pass**).
- **Calibration pair separates** — running the skill on `calibration_pair.md` (shipped beside this
  file, English + Korean sections) reproduces its known answers: known-independent → independent,
  known-induced → induced, drop counted. Required on first use and whenever the praise-pattern list
  changes; a corpus language with no shipped section requires **constructing that language's known
  pair first** — re-running an existing-language pair for a new language is a vacuous pass, not a
  measurement (check-class: **measured**; declare the result in the output header
  `calibration:` field).
- **Single-author corpus with a named consumer ran Step 4-b** — each proposition carries
  absorbed / held-unused / declined, the consumer asset is named, and the ingestion-to-citation gap
  is reported; every grep in the step shows its known-positive control result inline, or the step
  reports `UNCALIBRATED` and emits no labels (check-class: **mandatory-pass** — the control result
  is either printed or the labels are absent; N/A when the corpus is multi-speaker or no consumer
  asset exists, and the N/A must be stated).
- **Propositions are faithful to source spans** — no meaning drift (check-class: **judged**;
  adversarial pairing: `phantom-quench` back-trace of each proposition to its source ref — a
  proposition whose source span does not support it is an Unsupported finding).

## Independence

Independently executable: Read/Grep only, no other FH skill required. `phantom-quench` is the
adversarial pairing for the judged condition, not a runtime dependency. Works standalone
(plugin-only install).
