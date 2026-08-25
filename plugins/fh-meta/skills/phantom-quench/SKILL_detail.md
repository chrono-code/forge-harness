# phantom-quench — Execution Detail

On-demand reference. Load the section indicated by the pointer in SKILL.md.

---

## §Step0-Detail

**Step 0 — Audit Target Confirmation**

If not provided by user, explicitly confirm all three items:

1. **Artifact file**: Path to audit target file (TC file, analysis report, design document, etc.)
2. **Declared source files**: List of source file paths that should be the basis for artifact generation
3. **When source not declared**: Source not declared itself is registered as an S-grade blocker

Output format:

```
Audit target:
  Artifact: {file path}
  Declared source: {file path list or "not declared"}
  Audit scope: {full / specific section / specific claim type}
```

**Simplification guard**: If source is clear and audit scope is single section, skip Step 0 output and go straight to Step 1.

---

## §Step1-Detail

**Step 1 — Claim Extraction Full Reference**

**Claim types to extract**:

| Type | Examples | Priority |
|---|---|:---:|
| **Proper nouns** | API endpoint names, field names, status values, screen names | Highest |
| **Numerical/range values** | Amounts, time, ratios, counts, thresholds | Highest |
| **Branching conditions** | if/else branches, exception cases, error codes | Highest |
| **State transitions** | Conditions for A state → B state, allowed/forbidden combinations | High |
| **Preconditions** | "only when ~", "when ~ is active" | High |
| **Actors** | System, user, external API role distinctions | Medium |

**Exclude from extraction** (no source back-tracing needed):
- General test methodology descriptions ("using boundary value analysis")
- Generic UI patterns ("click button then verify result")

**Step 1 output format**:

```
## Step 1 — Claim Extraction Results

| # | Claim | Type | Location (artifact file:line) |
|:---:|---|:---:|---|
| 1 | [claim content] | Proper noun/Numerical/Branch | [filename:line N] |
...

Total {N} extracted (Proper nouns N / Numerical N / Branch N / State transition N / Precondition N / Actor N)
```

---

## §Step2-Detail

**Step 2 — Source Read + Back-Trace Execution Detail**

**Back-tracing principles**:
- Read source files directly with the Read tool — do not judge from memory or inference
- Use Grep to confirm exact value, keyword, or pattern match
- **Partial match is not treated as match** — e.g., if source has "5 minutes" and TC has "300 seconds", treat as requiring separate confirmation

**Classification decision rules**:

| Classification | Criteria | Marking |
|---|---|:---:|
| **Grounded** | Claim directly confirmed in source | ✅ |
| **Partial** | Similar content in source but not exact match — needs re-confirmation | ⚠️ |
| **Phantom** | Cannot be found in source | ❌ |
| **Source-Missing** | Source itself cannot be Read or was not declared | 🔴 |

**Step 2 output format**:

```
## Step 2 — Source Back-Trace Results

| # | Claim | Back-Trace Result | Source Evidence (file:line) | Notes |
|:---:|---|:---:|---|---|
| 1 | [claim] | ✅/⚠️/❌/🔴 | [filename:line N or "none"] | [modifications, etc.] |
...

Grounded: N / Partial: N / Phantom: N / Source-Missing: N
```

---

## §Step2E-Detail

**Step 2-E — External Claim Fetch + Support Execution Detail**

Fires only for external-cited claims (when Step 0.5 flags `risk_level:external` or `external_citation`).
The principle: **existence ≠ support**. Check that the fetched source *states the claim*, anchored on a
literal span — never on a model's agreement.

**Identifier normalization** (resolve to a fetchable URL before WebFetch):

| Citation form | Resolved URL |
|---|---|
| `arXiv:NNNN.NNNNN` / `arXiv:NNNN.NNNNNvK` | `https://arxiv.org/abs/NNNN.NNNNN` (abstract — the **canonical identifier** surface). For a section-/body-cited claim, prefer full text **first**, falling back in order `https://arxiv.org/html/NNNN.NNNNN` → `https://arxiv.org/pdf/NNNN.NNNNN` → `/abs/` (HTML is a *partial* backfill — see *Surface selection* below) |
| bare DOI `10.xxxx/...` | `https://doi.org/10.xxxx/...` |
| `http(s)://...` | use as-is (HTTPS-upgrade handled by WebFetch) |
| Named source, no URL ("paper X shows Y") | **one** `WebSearch` to locate the canonical URL → then WebFetch it. Do **not** verify against the search snippet alone — the snippet is not the source. |
| version token `pkg x.y.z` | the package registry/release page (npm/PyPI/GitHub releases) for that exact version |

**Surface selection — the abstract is the wrong surface for a §-cited mechanism.** The `/abs/` page
carries only the abstract; a claim that cites a section or attributes a *named body-level mechanism* to
the paper (e.g. "§4.2 stale-but-confident", "the paper's Change Manifest") returns NONE / MENTIONS on
`/abs/` even when fully supported in the body — an **artificial Unsupported** (measured 2026-06-17
in-the-wild dogfood: a `/abs/`-only fetch falsely flagged a body-supported claim; it resolved only after
escalating to full text). Two mechanical, judgment-free rules cover this:

1. **Mechanical first-surface trigger** — if the claim text carries a section/figure marker (`§N`,
   "section N", "Table N", "Figure N") → fetch full text **first**. Otherwise fetch `/abs/` first. (Do
   *not* pre-decide "is this a body-level mechanism?" — that is a salience-dependent judgment; the
   `§`-marker is the only mechanical signal, and the NONE-escalation below catches the rest.)
2. **Abstract NONE/MENTIONS escalates** (the self-correcting backstop) — *any* `/abs/` fetch that
   returns **NONE or MENTIONS** escalates once to full text before an Unsupported verdict (see Decision
   rules). A true headline claim already returned ASSERTS on `/abs/`, so it never escalates; only a
   NONE/MENTIONS does, and the escalation is cheap insurance. (A MENTIONS on the abstract is the common
   case — the body may ASSERT what the abstract only named; measured 2026-06-17 wild case 2604.25850 was
   a /abs MENTIONS that became a full-text ASSERTS. A **NEGATES** does *not* escalate — it is
   polarity-final: a body span asserting the same relation cannot coexist with an abstract that refutes
   it; a *different, narrower* body claim is a citation-granularity error, still Unsupported, not an
   escalation target.) This subsumes rule 1's misses — a body claim that *didn't* carry a `§` marker
   still gets full text via its abstract NONE/MENTIONS.

**HTML is a partial backfill — fall back, never Phantom.** arXiv HTML exists only for LaTeX-source
papers (roughly post-2023) and some conversions fail, so `/html/{id}` can 404 for a perfectly real
paper. A 404 on `/html/` (or `/pdf/`) is **surface-absence, not identifier-absence**: fall back
`/html/` → `/pdf/` → `/abs/`. Only a 404 on **`/abs/`** (the canonical identifier surface) is Phantom.

**Anchor the full-text fetch.** Full text is large; pass the cited section number / mechanism term *into*
the WebFetch prompt (`"…the span in §4.2 that states…"`) so the span search is anchored, not whole-paper
— this makes the `§`-citation the retrieval anchor, not merely a routing flag, and guards against a long
paper's relevant span falling outside the fetch model's attention (a full-text false-NONE).

Reserve `/abs/` for claims the abstract itself states (headline numbers, the paper's stated contribution
— e.g. a top-line stat like "39–77% factual support" is abstract-level and `/abs/` is correct).

**WebFetch prompt template** (ask for a *span*, not a *verdict* — this keeps the anchor non-model):

```
From this page, quote verbatim the sentence or span that states: "<the exact claim being checked>",
and label it: ASSERTS (the page states the claim is true) / NEGATES (the page states it is false, or
attributes it to refuted prior work) / MENTIONS (the words appear but do not assert the claim).
If no relevant span exists, reply exactly: NONE.
Do not summarize, infer, or judge support — only quote a present span with its label, or reply NONE.
```

Polarity is load-bearing: a page saying "X does NOT hold" or "earlier work claimed X — we refute it"
contains a span lexically matching the claim. Asking for the label keeps the *retriever* mechanical while
surfacing the stance the *judge* needs — a NEGATES/MENTIONS span is **not** grounding.

**Coinage at fetch time:** when the claim's key term is a known FH coinage (a name FH invented that the
source does *not* use — e.g. a label like "Drift Gate" for a mechanism the paper describes only in its
own words), pass the *mechanism description* — not the coinage string — into the `<exact claim>` slot, so
the retriever searches for the **relation**, not a label that isn't on the page. The Coinage-vs-source-term decision rule (below) then only adjudicates the returned
span; it never has to overturn a NONE the prompt itself caused.

**Span-evidence format** (a Grounded external verdict is invalid without this):

```
✅ Grounded — <claim>
   source: <resolved URL>
   span: "<verbatim quoted span from fetched content>"
```

**Step 2-E output format**:

```
## Step 2-E — External Source Support Results

| # | Claim | Cited source | Result | Span / reason |
|:---:|---|---|:---:|---|
| 1 | [claim] | [arXiv:.../URL] | ✅/🟠/⏳/❌ | "[quoted span]" or "NONE" or "403 — env-blocked" or "id does not resolve" |
...

Grounded: N / Unsupported: N / Unreachable: N / Phantom: N
```

**Decision rules**:
- Span labelled **ASSERTS** that expresses the claimed relation → **Grounded ✅** (record span).
- Span labelled **NEGATES or MENTIONS** → **Unsupported 🟠** (a negating or merely-mentioning span is not
  grounding — the false-Grounded trap). **One exception — a MENTIONS from the abstract (`/abs/`) surface
  escalates first** (per the NONE/MENTIONS escalation below) before being finalized: the body may ASSERT
  what the abstract only mentioned. A **NEGATES** is final (the source refutes the claim — the body will
  not undo it); a MENTIONS from a full-text surface is also final.
- Fetch succeeded, content readable, span = NONE or off-claim → **Unsupported 🟠** (cited-but-not-verified).
  **Surface-escalation first — an abstract NONE/MENTIONS is the mechanical trigger (no judgment):** if the
  only surface fetched was the abstract (`/abs/`), re-fetch full text (fall back `/html/{id}` → `/pdf/{id}`)
  before classifying — *any* abstract NONE/MENTIONS escalates once, you do **not** first decide whether the
  claim "looks body-level" (that judgment is the salience leak this rule removes). A body-supported claim
  must not be failed on an abstract-only NONE/MENTIONS. This is the second-surface escalation, **extended
  from Unreachable to Unsupported-on-abstract** (2026-06-17 dogfood finding #2). Only after a full-text
  surface *also* returns NONE/MENTIONS is the verdict Unsupported. (Single-pass: escalate once, then
  classify — no loop.)
- Identifier does not resolve on the **canonical** surface (`/abs/` 404, dead DOI, fabricated id) →
  **Phantom ❌**. A 404 on `/html/` or `/pdf/` while `/abs/` resolves is **surface-absence, not
  identifier-absence** — fall back per *Surface selection*, never Phantom.
- Identifier plausibly real but fetch blocked in this environment (paywall/403/timeout/cross-host) →
  **Unreachable ⏳** — provisional; note the limit, route to a second surface or the human gate; never auto-Phantom.
- `WebFetch`/`WebSearch` **absent/disabled in the environment** (not one source — the capability) → Step 2-E
  cannot run: report "external grounding NOT PERFORMED — no fetch capability" and set verdict **ESCALATE**
  (do not mark every claim Unreachable + CONDITIONAL_PASS — that falsely implies grounding was attempted).
- **Never** upgrade NONE to Grounded because a second model "thinks it's probably right" (agreement bias).

**Coinage-vs-source-term (the external analogue of Step 2's format normalization — but *judged*, not
mechanical).** FH sometimes attributes a *coined* name to an external source (e.g. "the paper's Drift
Gate") when the paper uses different words for the same mechanism. A name
mismatch alone is not automatically Unsupported — but the path to rescuing it is **deliberately narrow**,
because this is one rationalization away from the agreement-bias trap above. The failure direction must
stay conservative (over-flag, never false-Grounded):

- **Possessive/attributive phrasing is presumed a terminology claim.** "the paper's X", "its X",
  "X, per [paper]" → literal absence of the coinage on the source = **Unsupported 🟠**, *unless the FH
  artifact separately states the underlying relation in non-coinage words* — "separately" means
  **anywhere in the artifact, including an inline gloss of the coined term** (e.g. "**X** (the spec's
  accept-only-on-improvement rule)"); proximity does not matter, only that the relation is stated in
  non-coinage words, so the mechanism is independently legible without the label. A runner may **not**
  reclassify a bare "the paper's X" (a coinage with *no* such gloss anywhere) as a mechanism claim on its
  own reading — the mechanism claim must already be spelled out **in the artifact** before the span-judged
  path opens. (Closes the laundering move: relabeling a terminology claim as a mechanism claim to save it.)
  An inline gloss grants only *eligibility* for that path — Grounded still comes **only from the fetched
  source span** (de-label test below), never from the gloss itself; a gloss the source does not support
  is artifact-internal, fails de-label, and cannot launder a coinage into Grounded.
- **When the mechanism IS spelled out, ground on the relation, not the string — mechanical de-label
  test:** blank out *both* labels (FH's coinage and the source's term); the span must still literally
  state the operative relation the claim asserts — the same inputs→outputs / the same conditional / the
  same action. If, with both names blanked, the span no longer states the claim, the equivalence was
  reader-supplied → **Unsupported 🟠**. (Worked shape: blank FH's coined label *and* the source's own
  term; a fetched span that still literally states the operative relation — e.g. "accepted only when the
  score strictly improves" — in the source's own words is Grounded; if the equivalence only holds once
  you read FH's label back in, it was reader-supplied → Unsupported.)
- **No self-granted Grounded on a contested match.** If the de-label test is contested rather than clean,
  the runner may **not** write Grounded — the *only* path to Grounded for a disputed term-match is
  **escalate to `/steel-quench` Wave 1** and let the isolated adversary surface the span or reject it.
  Default otherwise = Unsupported. (Removes the runner's discretion to self-select the lenient branch.)
- **Recommended conservative resolution (publish-facing).** For a publish-facing citation the safer fix
  is to require the artifact to **quote the source's own term** (e.g. "what the source itself calls X")
  instead of asserting an unverified label as the source's — removing the judgment entirely. Reserve the
  judged de-label path for low-stakes internal claims; match effort to stakes.

Unlike Step 2's value-format normalization (mechanical: `300s` ≡ `300 seconds`), coinage-vs-term is
**judged** — Grounded only via a clean de-label span or a passed steel-quench escalation, never a
reader's semantic equivalence assertion.

---

## §Step3-Detail

**Step 3 — Prescription Procedures + Output Format**

**3 Prescriptions — detailed execution**:

1. **Source Re-read**: Precisely Read the relevant section of that source file again → fix the claim. Use Read with line-range targeting if the source is large.
2. **Request source specification**: When source doesn't exist or wasn't declared → ask user to specify source file. Do not proceed until source is provided for S-grade items.
3. **Delete/rewrite**: TCs/claims without source grounding should be deleted and rewritten based on source. Rewrite must start from source Read, not from the existing artifact text.

**Step 3 output format**:

```
## Step 3 — Phantom Classification + Prescription

### S-grade Immediate Blockers

| # | Claim (Phantom) | Prescription | Evidence |
|:---:|---|---|---|
| 1 | [claim] | Source Re-read / Request source specification / Delete rewrite | [source file specified or reason for absence] |

### A-grade Must Fix

| # | Claim (Phantom/Partial) | Prescription | Notes |
|:---:|---|---|---|
...

### B-grade Improvement Recommended

| # | Claim (Partial) | Prescription | Notes |
|:---:|---|---|---|
...

S-grade: N / A-grade: N / B-grade: N
```

---

## §Step4-Detail

**Step 4 — Pattern Diagnosis Output Format**

```
## Step 4 — Source Not-Read Pattern Diagnosis

Detected pattern: {pattern name or "none"}
Evidence: {Phantom/Partial distribution analysis}

Process prescription:
- [specific process improvement suggestions]
```

---

## §Report-Template

**Completion Declaration Format**

```
## phantom-quench Complete

Audit scope: {artifact file} / source {N files}
Axes traced: {claim classes actually traced — e.g. 경로 참조 · 인용 · 버전 주장} / not run: {e.g. 외부 fetch(Step 2-E)} 
{N} total claims audited

Result summary:
  ✅ Grounded: N
  ⚠️ Partial: N (fix recommended)
  ❌ Phantom: N (S: N / A: N / B: N)
  🟠 Unsupported: N (external source fetched but does not support claim — S/A/B)
  ⏳ Unreachable: N (external source un-fetchable here — second surface pending)
  🔴 Source-Missing: N

Process pattern: {detected pattern or "none"}

Next actions:
  - S-grade Phantom → immediately Source Re-read then fix
  - Source not-read pattern detected → add source Read prerequisite to artifact generation process
  - 3+ Phantoms → recommend using with steel-quench Wave 1 "real-use verification" angle
  - Repeated pattern detected → persist to tracks/_meta/ + propose as rule candidate
```

---

## §Evidence

**Evidence Record**

- **Verified in practice**: TC generation without reading source files → steel-quench passes → phantom-quench back-trace detects numerous Phantoms (notifications vs. push notifications, version names vs. non-enrolled, bottom sheet vs. screen navigation). **Procedure**: Read sources in order then regenerate → replace with source-based TCs. **Recurrence prevention**: Source gate implementation — FileNotFoundError if required source files absent. steel-quench misses this because: outputs look logically sound so pattern attacks cannot identify Phantoms — only source back-tracing can detect them.

---

## §Step2-7-Detail — Split-Pair Bidirectional Integrity Procedure

Runs when the audit target is a split pair (`SKILL.md` + sibling `SKILL_detail.md`, or any doc with
`§`-pointers into a sibling detail file). Two greps, both mandatory:

```bash
SKILL="path/to/SKILL.md"
DETAIL="$(dirname "$SKILL")/SKILL_detail.md"
[ -f "$DETAIL" ] || { echo "n/a — no sibling SKILL_detail.md (not a split pair)"; exit 0; }

# FORWARD (phantom): every '§X' pointer in SKILL.md must resolve to a '## §X' header in the detail file.
# Placeholder guard: a skill that DOCUMENTS pointer syntax (like this one) contains meta-examples
# (§X, §SectionName, §Section). Skip them — they are prose, not real pointers. Heuristic: a real
# section name is multi-char AND not a known meta-placeholder.
echo "── forward: pointer → section ──"
grep -oE 'SKILL_detail\.md §[A-Za-z0-9._-]+' "$SKILL" | sed -E 's/.*§//' | sort -u | while IFS= read -r sec; do
  case "$sec" in X|Y|Z|N|SectionName|Section|Name) continue;; esac   # documentation placeholders
  if grep -qE "^## §${sec}([[:space:]]|$)" "$DETAIL"; then
    echo "  OK      §$sec"
  else
    echo "  PHANTOM §$sec — pointer resolves to no section (grade A)"
  fi
done

# REVERSE (orphan): every '## §X' section in the detail file must have >=1 inbound pointer from SKILL.md.
echo "── reverse: section → pointer ──"
grep -oE '^## §[A-Za-z0-9._-]+' "$DETAIL" | sed -E 's/^## §//' | sort -u | while IFS= read -r sec; do
  if grep -qE "SKILL_detail\.md §${sec}([[:space:]]|\`|$|,|\.)" "$SKILL"; then
    echo "  OK     §$sec"
  else
    echo "  ORPHAN §$sec — detail section no pointer reaches (grade A: dead weight / maintenance trap)"
  fi
done
```

**Output table**:

```
Split-pair integrity — {SKILL.md} ↔ {SKILL_detail.md}
  Forward (pointer→section): {N} pointers, {P} phantom
  Reverse (section→pointer): {M} sections, {O} orphan
  Verdict: CLEAN (P=0 && O=0) | DEFECT ({P} phantom + {O} orphan — grade A each)
```

**Prescription per finding**:
- **PHANTOM pointer** → either add the missing `## §X` section to the detail file, or fix/remove the
  pointer in SKILL.md (whichever matches intent — usually the section was renamed or never written).
- **ORPHAN section** → decide by governance-semantic criterion: if the content is genuinely detail-tier,
  add an imperative pointer from SKILL.md at the point of removal; if the content is *also still inline*
  in SKILL.md (the duplicate-copy defect), delete the orphan from the detail file — do not leave both.

**Why grade A (not B)**: a phantom pointer sends a consumer agent to nothing (execution breaks); an
orphan section is content the always-loaded file can never route to, so it silently rots out of sync with
the inline version. Both are reference-integrity failures on the split surface, not cosmetic.
