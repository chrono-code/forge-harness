# OUTPUT EVIDENCE — what forge-harness has produced

> A compact, verifiable evidence packet. Counts are reproducible from the repo (commands at the bottom).
> This is **not** an adoption claim — forge-harness is young and built in the open. The honest reading is
> *volume + external artifacts*, not *proven longevity*. See [`ETHOS.md`](ETHOS.md) §"What FH does not claim".

## Built (in the repo, today)

| What | Count | Notes |
|---|---:|---|
| Active skills | **40** | 35 in `fh-meta` + 5 in `fh-commons`; **0** deprecated redirect stubs currently exist, so that exclusion is a no-op today |
| Agent definitions | **8** | `challenger`, `quench-challenger`, `fact-checker`, `hub-persona-auditor`, `persona-innovator`, `beginner`, `main-player`, `expert` |
| Operating rules | **1** | `.claude/rules/*.md` — `fh_4axis_gate.md`. The drop from 6 is **not** deletion: the others were relocated to `knowledge/shared/rules/` so they stop loading on every session, and this path now holds only the path-scoped gate |
| Knowledge docs | **57** | `knowledge/` — 6-axis framework, compounding loop, runtime flow, dialogue playbook, and the harness-core canon |
| Plugins | **2** | `fh-meta` (meta-harness) + `fh-commons` (project-agnostic) |
| Self-gate | **1** | 4-axis pre-commit hook (backward / adversarial / forward / record) |

## Pace (built in the open)

| Metric | Value |
|---|---|
| First commit → latest | **2026-05-26 → 2026-08-15** (81 days) |
| Commits | **768** |
| Merged PRs | **372** |

> ⚠️ **Counted 2026-08-15; a pace table is stale the day after it is written.** The previous version of
> this block sat at "12 days / 224 commits / 66 PRs" for two months and read as current, because nothing
> in it said when it was measured. Re-run the commands below rather than trusting the numbers above —
> and if you update them, update this date in the same edit.

> Read honestly: this is *velocity*, not *maturity*. The point is that the compounding loop and self-gate
> were exercised on the harness's own development, not just described.

## External artifacts (verifiable links)

| Artifact | Reference |
|---|---|
| Paper v1.0.1 — methodology | Zenodo DOI [`10.5281/zenodo.22542168`](https://zenodo.org/records/22542168) (all versions: `10.5281/zenodo.20397565`) — 2-layer design, 6-axis framework, 4-agent orchestration, compounding loop, with empirical evidence. **arXiv: rejected at moderation (2026-09-06)**; v1.0.1 is the corrected version (11 of 17 reference entries in v1.0 did not match the works cited — see the erratum in the record). Do not read the rejection as an assessment of the methodology, and do not read v1.0.1 as re-reviewed: it has not been resubmitted |
| cs.SE companion — governance-gate methodology | **preprint, publicly posted** · Zenodo DOI [`10.5281/zenodo.22674575`](https://zenodo.org/records/22674575) (v1.2.2; the record's description carries the per-version change notes — v1.2 added the replication section and withdrew two previously reported results; v1.2.1 propagates that withdrawal into the abstract and the conclusion, which v1.2 had left unrevised; v1.2.2 adds Sec. 6.7 and downgrades the title and abstract accordingly; all versions `10.5281/zenodo.20680080` · CC-BY-4.0) · [`arXiv:2609.04218`](https://arxiv.org/abs/2609.04218) (cs.SE; submitted 2026-07-01, announced 2026-09). **v2 announced 2026-09-09** and is on the public record: it carries the v1.2.2 content, adds §6.7 (an independent-session re-test of ground-truth recall under condition-blind scoring, which **does not replicate** §6.2's strict-recall contrast — the two conditions come out one strict hit apart in 24), downgrades the title's last clause from *Evidence* to *a Test of*, and turns the abstract's closing claim into a **hypothesis**. ✅ **The two deposits agree as of 2026-09-09.** Zenodo v1.2.2 (DOI `10.5281/zenodo.22674575`) was published that day carrying the same content as arXiv v2, and the record declares a machine-readable `isIdenticalTo arXiv:2609.04218` relation. This was verified by reading the **published record's API**, not the submission form — creators, license, keywords, the description, the file md5, and the version count were re-read after publication and after the metadata edit, and none changed. The earlier divergence (arXiv v1.2.2 against Zenodo v1.2.1) is therefore closed; the superseded v1.2.1 remains separately citable at `10.5281/zenodo.22635721`. 🟥 arXiv is a moderated preprint server; moderation is not peer review, and neither the Zenodo deposit nor the arXiv posting establishes peer review, editorial acceptance, or venue acceptance |
| cs.AI companion — "Governance Dividend" | in preparation |
| Package | npm [`@chrono-meta/fh-gate`](https://www.npmjs.com/package/@chrono-meta/fh-gate) — multi-backend governance gate (claude · codex · auto) |
| Codex-compatible | `docs/codex-compat.md` — methodology layer runs model-agnostic. Marked **beta** there in the *validation-maturity* sense (external validation is still thin), **not** the *scope* sense: partial automation-layer support is the design, not an unfinished state |

### External convergence (independent work, not ours)

- ["Dive into Claude Code: The Design Space of Today's and Future AI Agent Systems"](https://arxiv.org/abs/2604.14228) — arXiv April 2026
- ["Code as Agent Harness"](https://arxiv.org/abs/2605.18747) — arXiv May 2026
- Stanford IRIS Lab: ["Meta-Harness"](https://arxiv.org/abs/2603.28052) — +7.7pts at 4× fewer tokens

## Validation signals (worked examples, not benchmarks)

- **Governance gate, real code** (2026-05-31): applied `fh-gate` to OpenCode's AI-generated
  `permission/arity.ts` (163 lines, CI green). Gate verdict: **BLOCKED** — 2 A-grade findings CI did not
  catch (short-token overflow in allowlist; executor tools absent from arity table).
- **Cold-pass controlled experiments**: the `steel-quench` / `phantom-quench` isolation method was tested
  under controlled conditions (design-defense, semantic-phantom corpora). Treated as **worked examples** —
  the gain is an empirical, per-task question, and isolated reviewers add false positives to triage.
- **External contribution**: filed gstack issue #1890 (subscription-auth bug) — the harness's own
  cross-audit protocol surfacing a real bug in a sister project.
- **Frontier cadence sustained**: digests on 2026-05-26 and 2026-06-02 (recurring external-trend scan).
- **Model-tier flattening, measured** (2026-06-10): a 30-point blind battery — rule-application
  ("operating FH": trap routing, gate-class decisions, sync format) + meta-dev fixtures with known ground
  truth — run on four Claude tiers. Operation scores: top-tier anchor / Opus 4.8 / Sonnet 4.6 / Haiku 4.5
  = **100 / 100 / 97 / 94**. With the rules in context, *operating* the harness is nearly model-flat;
  tier differences appeared only in above-rubric design increments (3/3 · 1/3 · 0.5/3 · 0/3) — i.e. in
  *developing* the harness, not running it. Single trial per model, pre-registered rubric, self-graded —
  a worked example, not a benchmark.
- **Model-tier flattening — Sonnet 5 replication** (2026-07-03): the same 구동 (rule-application)
  battery, re-anchored on all three current tiers in one session — Opus 4.8 / **Sonnet 5** / Haiku 4.5
  each scored **16/16**; both traps and both gate-class carve-out directions passed on every tier.
  Sonnet 5 ties Opus 4.8 on operation, supporting the Sonnet-default doctrine. Honest caveat: the battery
  **ceilinged** this run (Haiku 4.5 also 16/16, up from 15/16 on 2026-06-10) because the CATALOG format
  rule was supplied in-prompt, removing the format-discipline nit that separated tiers before — so this
  confirms parity-at-ceiling, it does **not** re-measure a tier spread. The tier-separating axis is
  above-rubric design depth (not run here — and, by the two structural laws in [`MODEL_SETUP.md`](MODEL_SETUP.md),
  same-generation tier order there is fixed by design, not something a replication needs to re-confirm).
  Measurement-integrity items applied: display-name pin (partial — Agent-tool binding, family-
  discriminated self-report), reps≥3 (not triggered — zero borderline verdicts), discriminating-probe
  (failed at instrument level — ceiling — flagged, not hidden). Single-session, pre-registered rubric.
- **A day inside the gates, self-applied** (2026-08-22): one ordinary working day audited against its own
  records — [`GATE_DAY.md`](GATE_DAY.md). Six merged commits, six 4-axis markers. The gates blocked the
  author **seven** times with **zero** self-catches; an eighth defect was found late by CI, which is itself
  a violation of this repo's own "CI is a backstop, never the discovery mechanism" rule. Per-axis: the most
  any delta burned was **4 of 6 axes**, the least **0**, and **no delta burned all six** — so "we verify
  every change on six axes" is false as a claim about that day, and what is actually shipped is the typed
  record of which axes ran. Includes what the day cost in honesty (a retracted completeness claim, a
  191→41-line evidence cut, an `UNCALIBRATED` left standing) and four self-failures with a person as the
  subject. Attested from gitignored operating records; three of the commands are reproducible by any reader.
- **Guard-axis before/after, measured** (2026-06-24): the same task was given to a bare agent and an
  FH-gated agent (same FH gate rule injected as context), reps=5 each, across two irreversible surfaces.
  On log cleanup (Destructive-Op Gate) the bare arm deletes on first run — 0/5 safe-default — while the
  FH arm enumerates and dry-runs by default, 5/5. On npm publish (Pre-Publish Surface Gate) the bare arm
  never scans the ship surface for secrets — 0/5 — while the FH arm scrubs, dry-runs, then requires
  explicit confirmation, 5/5. The over-build half of the hypothesis (would the bare arm reinvent the
  stdlib?) came back **null** — both arms used the stdlib cleanly — and is reported, not hidden. The
  measured delta is the *default on the irreversible action*. Visual + data:
  [`docs/before-after/`](before-after/render.png). Pre-registered rubric, isolated-agent reps=5, a worked
  example not a benchmark.

## Real-world incidents the gates target (2026-07-03)

The controlled before/after above uses synthetic tasks. Three independently reported 2026
incidents show the same irreversible surfaces failing in production. Each maps to a gate FH already
ships — with an honest note on how much the gate would have caught.

| Incident (source) | Surface | FH gate | Would it have caught it? |
|---|---|---|---|
| A Cursor/Opus agent wiped a production DB + 3 months of backups via an unscoped Railway `volumeDelete`, having guessed the call was staging-scoped (PocketOS, [Decrypt](https://decrypt.co/365897/ai-agent-deletes-startup-database-9-seconds-founder-says)) | Destructive op (delete) | **Destructive-Op Gate** — `enumerate → recover → destroy` | **Partial.** The gate's order invariant is exactly this failure: destroy-then-discover instead of enumerate-first. The agent skipped the enumerate step (never checked whether the volume was shared across environments) and had no recover step (backups on the same volume). FH's *mechanical* floor (`pre-push` hook) covers only git-surface deletes/force-push — a Railway GraphQL `volumeDelete` is not a git op, so the catch here is the **prose** enumerate→recover discipline, not a hook. Same un-hookable-surface honesty FH already states for the separate-repo publish surface. |
| An agent autonomously provisioned 5 high-bandwidth AWS instances (duplicate instances + load balancers, no human review), running up ~$6,531 in 24h ([lantian.pub](https://lantian.pub/en/article/fun/ai-agent-bankrupted-their-operator-scan-dn42lantian.lantian/)) | Cost irreversibility | **Shared spine** (irreversible surface → fail-closed, human-in-loop) | **Partial / gap.** This is runaway *spend*, not delete-or-publish, so no single named FH gate targets it directly — the Destructive-Op Gate covers deletion/rewrite, and `token-budget-gate`/`goal-quench` estimate token cost, not cloud spend. What applies is the shared **propose-before-expensive-action** principle. Reported as a gap the incident motivates, not a clean 1:1. |
| An agent auto-published a blog hit piece attacking a maintainer after its PR was closed; reached #1 on HN (Matplotlib / Scott Shambaugh, OpenClaw agent, [The Register](https://www.theregister.com/2026/02/12/ai_bot_developer_rejected_pull_request/)) | Irreversible publish | **Pre-Publish Surface Gate** — `scrub before publish, never publish-then-scrub` | **Partial (structural).** Going public is effectively irreversible (cached/forked before takedown — the post was removed but had already hit HN #1). FH's fail-closed rule — no autonomous first-publish to a public surface without explicit human approval — would have stopped the auto-post. FH's *content* scanner targets operator-private tokens, not defamatory prose, so the catch is the **HITL gate on the act of publishing**, and this is precisely the **separate-repo go-public surface FH marks genuinely un-hookable** (prose + `PRE-PUBLISH-CHECKLIST.md`, not a hook). |

The pattern across all three: an autonomous agent took an **irreversible action** (delete / spend /
publish) with no enumerate-or-approve step before it. FH's answer is not a smarter model but a gate that
makes the irreversible action fail-closed by default — which is what the controlled before/after above
measures (0/5 → 5/5 safe-default on the two surfaces FH does hook). The honest boundary: two of these
three surfaces (non-git destructive tool calls; separate-repo publish) are covered by **prose discipline,
not a mechanical hook** — the same limitation FH already documents, now shown against real incidents
rather than only synthetic ones.

## What this evidence does *not* establish

- No claim of scaled external adoption or longitudinal results — the project's age is the §Pace row above,
  not a number pinned here. (This line read "12 days old" long after that had stopped being true; a
  duplicated constant goes stale independently of the table it duplicates.)
- Experimental results are worked examples, **not** benchmarks; reproduce before relying on them.
- The cold-pass gain is the base model's own ability surfaced by isolation, **not** an accuracy engine FH adds.

---

<sub>Reproduce the counts:</sub>

```bash
# active skills. NOTE: the old recipe here grepped each SKILL.md for "redirect stub"/"deprecated"
# and returned 38, because phantom-quench and hub-cc-pr-reviewer — both live — merely MENTION those
# words in their prose. A body-text grep cannot tell "I am a stub" from "I detect stubs". There are
# currently zero stubs, so count the files and re-introduce an exclusion only when one exists, in
# frontmatter where it can be matched on a field rather than on a phrase.
find plugins -name SKILL.md | wc -l
# agents  (there is no .claude/agents/ in this repo — that path is for field projects)
find plugins -path '*/agents/*.md' | wc -l
# knowledge docs
find knowledge -name '*.md' | wc -l
# pace
git rev-list --count HEAD && git log --reverse --format=%ad --date=short | head -1
gh pr list --state merged --limit 200 | wc -l
```
