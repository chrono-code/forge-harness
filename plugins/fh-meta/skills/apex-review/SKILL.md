---
name: apex-review
description: Reviews a technical proposal from the perspective of organizational decision-makers (CTO, technical lead, QA lead, conference reviewers, etc.) and generates an HTML presentation deck. Outputs approval gate results per persona and connects to sim-conductor for improvement suggestions.
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Agent"]
model-note: session-inherit — Sonnet base is first-class (sonnet_floor_doctrine.md); depth-critical judged steps route to dispatch (opus agent / cross-family sidecar, consent-gated), never a substrate requirement
---

# apex-review — Decision-Maker Review Layer

> Reviews proposals from the perspective of **top-level organizational decision-makers**, not field practitioners.
> Technically excellent and "this person will approve it" are different things.

**Role distinction from hub-persona-auditor**
- hub-persona-auditor: Validates **reader comprehension** of a finished asset (reading experience)
- apex-review: Evaluates **decision-maker approval likelihood** of a technical proposal (decision-making experience)

---

## Triggers

- `/apex-review`
- "Will this work for the decision-maker?", "Will the CTO approve this?", "What do I need to present to the team lead?"
- "Review from an executive perspective", "Generate presentation slides" (when decision-maker audience is specified)
- When agent-composer identifies a task requiring a decision-maker approval gate
- "Check this before I report to my manager"
- "Does this look convincing?"
- "Find objections they might raise in advance"
- "Review before the executive briefing"
- "Do you think this will pass?"

---

## Built-in Decision-Maker Personas

| Code | Role | Core Evaluation Criteria | Auto-Reject Triggers |
|:---:|---|---|---|
| `CTO` | Chief Technology Officer | Strategic alignment · competitive advantage · tech vision | "Everyone else is already doing this" / "Feels like a personal project" |
| `TD` | Technical Lead / Team Lead | Implementation risk · team capability · operational burden · cost | Vague timelines / conflicts with existing stack |
| `QAL` | QA Lead / Quality Owner | Quality standards · testability · rollback plan · compliance | No validation plan / failure scenarios not documented |
| `CONF` | Conference Organizer / External Reviewer | Novelty · demo-readiness · audience value · reproducibility | Overloaded with internal jargon / demo not possible |

If the user does not specify a target persona, it will be confirmed in Step 0.

---

## Step 0. Receive Topic + Target

If no input is provided:

```
Please provide the apex-review target.

  Proposal summary: (What are you seeking approval for?)
  Target decision-maker: [CTO / TD (Technical Lead) / QAL (QA Lead) / CONF (Conference)] — multiple allowed
  Proposal file: (provide path or paste content if available)
  Output format: [HTML presentation deck (recommended) / Markdown report]
```

If no proposal file is provided, collect content through conversation.

---

## Step 1. Structure the Proposal

Organize the received content into the following slide structure.

```
[S1] One-line thesis      — "What needs to be done and why"
[S2] Current state / problem — What is not working right now
[S3] Proposal             — What changes and how
[S4] Expected outcomes    — Quantified or verifiable change
[S5] Implementation plan  — Phases, timeline, ownership
[S6] Risks + mitigations  — Failure scenarios + rollback
[S7] Requests             — What is needed from the decision-maker
```

If any slide is missing during structuring, request the user to fill it in.

---

## Step 2. Generate HTML Presentation Deck

Generate as `apex_review_deck_YYYYMMDD.html`.

HTML structure rules:
- Each slide = `<section class="slide">` block
- Per slide: title + body + (if applicable) decision-maker attention note
- Navigation: keyboard ←→ or buttons
- Style: clean dark background / large headlines / emphasized key figures

```html
<!-- Slide example -->
<section class="slide">
  <h2>Current State · Problem</h2>
  <p class="body">…</p>
  <aside class="exec-note CTO">CTO attention: …</aside>
</section>
```

Notify the user of the file path after saving.

---

## Step 3. Persona Review

Evaluate the proposal for each target decision-maker.

Output format:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
apex-review — Decision-Maker Review Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[CTO Review]
  Verdict: ✅ Approved / ⚠️ Conditional / ❌ Rejected
  Rationale: …
  Conditions (if conditional): …
  Critical weaknesses: …

[TD Review]
  Verdict: …
  …
```

---

## Step 4. Approval Gate

**All ✅ Approved**: Gate passed → proceed to Step 5
**1+ ⚠️ Conditional**: Output condition list → request user decision
**1+ ❌ Rejected**: Output rejection rationale + improvement directions → suggest revision and re-review

After gate verdict:

```
Gate result: {Passed / Conditionally passed / Rejected}

Choose your next step:
  A. Revise and re-review
  B. Proceed to sim-conductor in current state (deep validation)
     ← strongly recommended when verdict is "Conditionally passed"
  C. Use HTML deck only (as reference)
  D. Exit
```

> **"Conditionally passed" → option B is the default path**: Conditions listed by personas remain unresolved until sim-conductor Area E runs challenger/beginner/main-player validation against them. Choosing C or D without sim-conductor leaves those conditions unverified — present B as the default choice and require explicit opt-out.

---

## Step 5. Deep Validation (Optional)

When option B is selected:

```
Connect to sim-conductor Area E.
  Target: apex_review_deck_YYYYMMDD.html
  Evaluation criteria: Decision-maker perspective (CTO / TD / QAL / CONF personas)
  Output: Improvement recommendations by M/S/R tier
```

Incorporate sim-conductor results into the HTML deck and save the revised version.

---

## Operating Notes

- **Invocable without input**: Content collected through conversation in Step 0
- **Customizable personas**: If the user specifies "our executives prioritize X", it will be reflected
- **Iterative review**: After revision, re-run from Step 3 (HTML decks distinguished by version date)
- **Standalone or within agent-composer**: In complex tasks, agent-composer will automatically include this skill

## Done When

```
All steps 0–4 completed
+ Verdict (✅/⚠️/❌) output for all target decision-makers
+ Gate verdict (Passed / Conditionally passed / Rejected) stated
+ Deck artifact exists on disk: `apex_review_deck_YYYYMMDD.html` (Step 2) — confirm by printing its
  path and byte size; this is the skill's only durable output, so "reviewed but no deck" is NOT done
+ If the gate verdict is `Conditionally passed`: the `/sim-conductor Area E` verdict has been
  RECEIVED and folded in (the mandatory-next gate below). Without that verdict the run is not done,
  regardless of the A/B/C/D selection
+ User next step selection (A/B/C/D) confirmed
```

**→ Mandatory next (Conditionally passed verdict): `/sim-conductor Area E`** — run against `apex_review_deck_YYYYMMDD.html` before the proposal is considered ready for submission. Skipping sim-conductor on a conditional pass means unresolved persona conditions go unverified; present option B as default and require the user to explicitly choose A/C/D to override.

Wait for sim-conductor Area E verdict before declaring the proposal submission-ready. (Conditionally passed path: proposal is not done until sim-conductor verdict folds back.)
