# Knowledge Catalog

AI reads this file first when searching past work. Open individual files for detailed content.

---

## 2026-08-20 — Seven canonical `knowledge/` docs were missing from this index

Found by the 30-day `harness-doctor` cadence run. Seven files under `knowledge/` had **zero**
CATALOG entries, so the CATALOG-first recall path (CLAUDE.md §Autonomous Initiative — *"read
`CATALOG.md`, identify candidates by tag/date, then open only those files"*) could not reach them
at all. Measured with a live control in the same run (`harness_6axis_framework` → 2 hits, so the
grep was alive; each of the seven → 0).

🟥 **The worst of the seven is `fh_three_layer_canon.md`** — CLAUDE.md names it a *mandatory*
pre-read before naming, re-scoping, or citing the 3-layer canon, and it was unreachable from the
index that the recall protocol reads first. A mandatory document that the lookup path cannot find
is, for any session that does not already know its filename, indistinguishable from absent.

- `knowledge/shared/harness-core/fh_three_layer_canon.md` — #canon, #3-stage, #4-engines,
  #5-identities, #6-axis. The 3-layer canon (3-stage process · 4 engines · 5 identities) and the
  definition of the **six verification axes** (ⓐ계열 · ⓑ입장 · ⓒ격리 그라운딩 · ⓓ3자대면 ·
  ⓔ첫실사용 · ⓕ되돌림) that stage ③ actually consists of. **Read before citing any of the three.**
- `knowledge/shared/harness-core/capability_composition_contract.md` — #capability, #composition,
  #strictest-wins. How a field harness's typed capability merges with hub constraints
  (strictest-wins regardless of layer; an untyped or silent channel is `HARNESS_ERROR`, never PASS).
- `knowledge/shared/harness-core/dispatch_conditional_prohibition.md` — #dispatch, #subagent,
  #conditional. The measured resolution order behind the runtime's *"do not call the AgentTool
  unless the user requested it"* line — why it is a **conditional** a request satisfies, not an
  override. Carries the calibrated where-it-is-not table and reproduction commands.
- `knowledge/shared/harness-core/agents_md_runtime_details.md` — #codex, #agents-md, #entrypoint.
  Runtime detail for the non-Claude entry point.
- `knowledge/shared/harness-core/harness_terminal_correlation_and_recommendations.md` —
  #correlation, #terminal, #recommendations.
- `knowledge/shared/rules/knowledge_layer_seam.md` — #seam, #org-knowledge, #unwired. Names FH's own
  unwired candidates at the knowledge-layer seam (including `steel-quench` Step 0.35).
- `knowledge/shared/rules/multi_session_close_protocol.md` — #close, #multi-session, #parallel.
  Canonical close discipline when two or more sessions run on one harness — order, discriminators,
  write discipline. **Not replaceable by a `gh pr list` re-check** (that structurally misses deltas
  with no PR).

- Decision: indexed as one consolidated entry rather than seven, because the finding is a *class*
  (index drift on `knowledge/`), and splitting it would hide that they were all missed the same way.
- Open: nothing mechanically prevents the next `knowledge/` file from landing unindexed. A
  `knowledge/**` → CATALOG coverage check is a candidate, not built (recurrence N=1 as a measured
  class; the repo's own bar is N≥3 or a second surface before mechanizing).

## 2026-08-15 — Global positioning & distribution roadmap (Homebrew/npm compatibility)

- **New doc** (`knowledge/shared/harness-core/fh_global_positioning_and_distribution_roadmap.md`):
  Antigravity/Gemini-authored positioning report — npm (`@chrono-meta/fh-gate`) is a full 152-file
  portable bundle (all skills/agents/harness-core doctrine/gate machinery, everything except
  `tracks/`·`knowledge/domain/`·`paper/`), not a thin gate-only checker; subscription-LLM runtimes
  and a future `brew install` CLI bridge are compatible, not competing.
- **Reviewed and corrected same day** (source-grounding pass): download/agent-count figures verified
  against live npm API + repo file count (both held); duplicate section numbering and a copy-paste
  duplicate subheading fixed; ungrounded superlatives ("세계 최상위...") removed/hedged; the
  competitor comparison table captioned as a positioning frame, not a benchmark; Phase 3 given two
  explicit caveats it originally lacked — scaffolding a project structure is not the same as FH's
  actual compounding (`meta-harness-thin-vs-full-distribution.md`, 2026-06-08, already-established
  axis — the value accrues in `tracks/`/memory over time, not at `fh setup` time), and a new
  Rust/Go binary's necessity is unevaluated against simply wrapping the already-live Node npm CLI in
  a Homebrew formula.

---

## 2026-08-01 — Harness-Verification Doctrine: core lens vs cluster instruments

- **New doctrine** (`knowledge/shared/harness-core/harness_verification_core_extended.md`): the
  incubator's verification axis, graduated from the field→meta reverse-verification arc (one day,
  four runs, two subjects; FH-side runs known-pair-calibrated, the company-side replication's
  calibration record stays company-side). First clause: *harness-verification core =
  the FH-native triad-consistency lens (spec ↔ implementation ↔ TC), askable with no cluster member
  present; extended = cluster instruments (trace auditors, process-fidelity harnesses), composed by
  UNION* — the Sonnet-Floor shape applied to verification.
- **Evidence**: a field QA harness's audit doctrine, context-decorrelated, found 7 novel grounded
  findings on an FH slice (all in the triad-disagreement class) and replicated on a second subject
  (7 more, 3 fixed same-day); a three-instrument UNION run measured **static↔trace** finding-class
  intersection zero (between extended instruments disjointness is partial — scope-corrected same day
  by cross-family audit); a mechanized transcript adapter addressed the self-attested-trace residual
  same-day (its own audit-integrity limits are pilot-grade — Run #4 backlog).
- **Companions updated**: `harness_incubator_doctrine.md` §3-b (the nursery also verifies what it
  births) · `CLAUDE.md §Identity` one-clause summary.
- **Honest labels**: the core lens is doctrine-level today (dispatched-procedure route; no native
  carrier asset yet — named residual, next build is evidence-threshold-gated). Subjects = 2, trace
  pairs = 1.
- Tags: `doctrine` `verification` `reverse-verification` `union` `cluster` `triad-consistency`

## 2026-07-26 — Scan logic single-sourced · FH_BACKEND=cross · v1.4.72

- **Single-sourcing** (`scripts/psa_scan_lib.sh`): three near-duplicate implementations of
  public-surface pattern loading/matching (pre-commit, pre-push, publish scanner) collapsed into one.
  Motivation was measured, not aesthetic — across 7 cross-family rounds on the same subsystem, every
  confidentiality defect found was a divergence between the copies (readable/non-empty override check
  in one, no-TAB rejection in two of three, the per-file LOW allowlist in exactly one — which is how
  the push gate blocked its own first real push). Duplication removal verified mechanically:
  `PSA_PLACEHOLDER` 3→1. Deliberately NOT unified, each with an in-file reason: degrade direction per
  surface, the publish scanner's `grep -a` binary handling, and its stricter allowlist.
- **`FH_BACKEND=cross`**: runs both model families and UNIONs findings (a finding only one family saw
  is still a finding, so union rather than vote); verdict is the most severe leg. The output always
  declares which legs actually ran (`FH_GATE_LEGS` / `FH_GATE_DECORRELATED`) and degrades loudly to a
  single leg when only one family is installed — a single-family result reading as cross-checked is
  the same defect class as a check that did not run reading as PASS. Implemented as a recursive
  wrapper so the npm-shipped single-backend path is untouched.
- **Over-block correction**, found by this repo's own selfcheck (T7: *"guard over-fires; that trains
  the override"*): the new push-time legs blocked whenever this operator's gitignored override was
  absent. The reasoning did not survive re-examination — that file holds one operator's literals, so
  another environment lacking it was never protected by it. Corrected to warn; what still blocks is a
  genuinely broken pattern source. Applicability is now decided mechanically before any dependency is
  required, and an N/A skip is announced rather than silent.
- **Anchors**: `universal_guard_check` 22 pairs · `prepush_guard_check` 12 pairs · fh-gate regressions
  31. Both anchors test the STAGED blob, score a hook runtime fault as its own failure class, and
  require a BLOCK to name a confidentiality cause (after the library landed, 6 of 8 BLOCK pairs were
  green for a harness reason).
- **Published**: npm `@chrono-meta/fh-gate@1.4.72`, tag `v1.4.72`, registry confirmed by polling.
- **Residual**: `cross` has no real-model end-to-end run yet (deterministic fakes only); the union does
  not deduplicate across legs (a false duplicate is cheap, a dropped finding is not).
- Tags: `single-source` `decorrelation` `cross-family` `known-pair` `over-block` `release`

## 2026-07-26 — Confidentiality gate: scope decoupled from the 4-axis classifier (gate-locality N=5)

- **Origin**: source-reading a cross-audited sister asset (`PromptPartner/agentsmith`, `leak-gate.sh`).
  Its `SCOPE=()` comment — *"an excluded file is a hole a real leak can sit in"* — asked of this repo
  surfaced a different shape of the same hole: the pre-commit confidentiality scan sat below
  `exit 0  # No FH assets staged`, so its trigger silently inherited the 4-axis asset pathspec. A commit
  staging only non-asset paths skipped it entirely. Known-pair measured, both directions: the identical
  leak line blocks in `CATALOG.md` and passes unseen in `README.md` alone. Surface: 46/241 tracked files
  (19.1%) unscannable that way, 32 of them also outside npm `files[]`.
- **Repair**: the confidentiality/privacy guards moved into `run_universal_guards()`, invoked before the
  early exit — they guard the publish boundary, not FH asset structure. Credential SHAPES imported from
  the sister asset (the scan previously matched only operator-private identity tokens, so a live AWS/GitHub/
  Anthropic key scanned clean), live-calibrated over the whole tree: one false positive, closed by an
  exact-literal exemption. A push-time content scan was added over the commits a push actually publishes.
- **Verification**: 7 cross-family adversarial rounds (codex/gpt-5.5). 30 findings; 2 accepted as named
  residuals with the success line narrowed to claim only what it checks, the rest fixed. One author
  refutation withdrawn when the auditor showed `npm publish` is not a backstop for a public git repo.
  Anchors: `scripts/universal_guard_check.sh` (pre-commit) and `scripts/prepush_guard_check.sh` (pre-push),
  both testing the STAGED blob and scoring a hook runtime fault as its own failure class.
- **Also**: `validate_yaml.sh` was found to be the defect rather than the file it flagged (it grepped for
  `': '` without checking whether the value was quoted, and its `--fix` folded quotes into an already-correct
  string) — rewritten parse-first with an `UNCALIBRATED` degrade. `sync-to-be.sh` returned the status of its
  last loop iteration, so a successful sync reported failure, the Stop-hook cooldown stamp was never written,
  and the companion store went uncommitted for ~3.7h; introduced by the same-day patch that added mirror banners.
- **Residual**: three near-duplicate scan implementations remain; single-sourcing them is the next PR and the
  real convergence — every leniency divergence found here was a propagation miss between those copies.
- Tags: `gate-locality` `confidentiality` `cross-family` `known-pair` `sister-asset` `publish-boundary`

## Sessions

<!-- Add entries in reverse date order (newest at top) -->

### 2026-07-26 | forge-harness · forge-wiki · llmwiki-template · llmwiki-qa | #gate-locality, #sync-guard, #instrument-calibration, #sister-asset, #cross-corpus-provenance, #wiki-consolidation
**File:** scripts/gate_pathspec_check.sh · scripts/sync_guard_check.sh · templates/.git-hooks/pre-commit · templates/regression_guard.sh · templates/CLAUDE.md · plugins/fh-meta/skills/dialogue-harvest/SKILL.md · plugins/fh-meta/skills/frontier-digest/SKILL_detail.md · knowledge/shared/harness-core/loop_engineering.md
FH self-dev session (PR #182 merged; 7 PRs merged across 4 repos). Three defects, each found by measurement rather than review, each closed with a calibrated regression anchor. **(1) Gate-locality, 4th recurrence**: the pre-commit gate and regression_guard both matched the literal `SKILL\.md`, which the string `SKILL_detail.md` does not contain — 17 files / 208,710 B / **27.7% of the skill-spec surface**, 16 of 17 carrying fenced code, entirely ungated. It leaked twice for real (371c04f, e661931 — single-file edits to a *grounding-audit skill's own* behavioral spec). Worst property: `salience-splitter` widened the hole every time it moved content out of SKILL.md, so coverage shrank as the diet succeeded. An adversarial pass argued name-by-name coverage cannot close the class in principle; the resulting **enumeration sweep found a real uncovered file on its first run** (`dialogue-harvest/calibration_pair.md`), and the fix was escalated from a name list to a directory scope. **(2) One-way sync silently overwrote session cards twice** (v9 7,567 B → v8 5,299 B; v10 likewise). Not carelessness — *induced*: the session-start rule says read the mirror first, so the mirror becomes where agents write. The close-checker missed it because "card-last violated" measures timestamp **order**, not overwrite. Fixed with a destination-newer abort (both callers), a mechanically-injected MIRROR COPY banner, and a 7-pair anchor; live calibration caught three self-defects in the fix itself — over-blocking (the exact failure the handoff warned would train the override reflex), a half-fix leaving sync_file open, and banner churn that re-transferred 265 files per run and destroyed the log as an instrument. **(3) dialogue-harvest first real corpus** exposed that single-author input makes provenance labels free; answered with **Step 4-b cross-corpus provenance** (absorbed / held-unused / **declined**), which immediately showed a 44 KB transcript in-house since 06-27 with **zero citations in 29 days** — containing the very kill-switch clause the same day's sister audit had just confirmed FH lacked.
- **Sister asset**: `PromptPartner/agentsmith` (255★, 10 days old) cross-audited; 3 cross-family adversarial legs all returned NOT-CONVERGED and the governor kept the verdict — P-2's grounds refuted outright (`leak-gate.sh` is fail-closed in behavior, only the vocabulary was absent), P-1 narrowed, a category error accepted, and an arithmetic error caught (mixed baselines: +3,218 → +2,687). Sidecars said *where to dig*; only source-grounding decided.
- **Wiki consolidation (4 stores)**: the propagation gap ran **opposite** to the assumption — forge-wiki's own upgrades were already downstream; what never came back was a 3.7+ compat fix, leaving the canonical repo with the narrowest Python range of the three. Reverse-harvested. `{FH_ROOT}` variable landed in all four (templates carried one operator's absolute paths into org-visible checkouts — the mirror image of public-surface protection). `llmwiki-template`'s missing `fw_mcp.py` was judged **declined, not a gap** (CONTRACT.md §54 states it).
- **Instrument failures, five in one session** (BRE-in-ERE · zsh no-word-split · stale cwd · `install` containing `stall` · a 404 JSON body passing a length check). Every one produced a *confident wrong value*; every one was caught only by a known-positive control or by opening the actual line. Two of them recurred **after** the rule against them was written — which is why both new anchors make the control mandatory-pass rather than advice.
- Decision: operator approved all pushes/merges; company-zone repo pushed via REST Contents API per the account rule (new files only, no overwrite).

### 2026-07-25 | forge-harness | #dialogue-harvest, #new-skill, #cookbook-tier0, #sister-triage, #cross-family-audit, #ruleset, #calibration
**File:** plugins/fh-meta/skills/dialogue-harvest/ · plugins/fh-meta/skills/asset-placement-gate/SKILL.md · plugins/fh-meta/skills/context-doctor/SKILL.md · tracks/_audit/session_2026_07_25_claude5-context-rules-sister.md · tracks/_meta/codex_decorrelation_audit_2026-07-25.md
FH self-dev session (PR #177 merged). **New skill `dialogue-harvest`**: mines argument-shaped corpora (AI dialogue logs) — sycophancy strip first, then induced-vs-independent provenance labeling per proposition (degrade direction fixed toward the induced flag); ships an EN+KO known-pair calibration corpus backing the measured Done When. Gate: challenger HIGH 1 MED 3 LOW 3 → 7/7 repaired (the HIGH: an EN-only calibration pair would vacuously pass a new-language re-run); blind Sonnet sims reproduce both language pairs, and the KO run self-declared UNCALIBRATED when denied the calibration file. **asset-placement-gate Step 0.6**: official corpora (built-ins · claude-plugins-official · Claude Cookbook) registered as the criterion-③ ground, judged-flag semantics; roster-wide cookbook mapping scan found 0 shadowed skills. **context-doctor**: built-in `/doctor`-first sister anchor (Claude 5 gen) with the skill's increment enumerated. **Sister triage** of Anthropic's Claude-5 context-engineering rules: the "no measurable loss" claim ships no method → closed empty on that axis, vendor-claim label; imports = the /doctor Tier-0 boundary + a live confirmation of the substrate-shed trigger. **Cross-family audit** (codex gpt-5.5, repo-grounded) of the "decorrelation as generative principle" proposition: both halves NARROWED — surviving increment is "premature same-family consensus is a bad stop condition for design search", valid only as divergence-then-selection on high-leverage underdetermined decisions; doctrine-ization stays deferred by design. persona-innovator frame scan: BVSR/QD/Best-of-N all lack FH's two clauses → keep the coinage, sister-link on doctrine-ization. **Server-side residual closed**: ruleset `main-no-force-push` (non_fast_forward on main) created and independently GET-verified.
- Decision: dialogue-harvest built on operator go (manual n=1 proof accepted); npm v1.4.70 published + tagged same session (operator approval, PR #179).
- **Third block (evening)**: **Matrix Benchmark v0+v1** (qasp-dev #27·#28) — the operator's "blind man with an ultrasonic cane at 60%" metaphor turned into numbers. Planted 4 defects + 2 traps in the admin-surrogate sandbox (calibrated known-pair), probed with isolated same-tier agents differing only in channel access: **detection 4/4 tied, attribution 2/4 (blind) vs 4/4 (matrix), traps 0/0** — the two blind misattributions were exactly the §3-b cell ("absent from source" vs "present but not rendered", both misread as source-defects: spec-optimism bias observed). Pre-registered predictions: 2/3 hit, 1 void. v1: attribution routed repairs (source-defects → code, spec-defect/environment → spec v2) and the AX-Lobby 3-channel E2E generation pattern reproduced locally (12/12 pass · web_rules 0/6 first pass · 3 BE-derived data-integrity assertions · §8 UNVERIFIED label · governor re-ran independently). Next (designed, not run): 3-condition escalation bench — "open eyes only where needed" — gated on semantic_anchor pull-forward wiring. Honest labels: n=1/condition exploratory; C1 blind-miss partially instruction-induced (fixed viewport).
- **Second half (same day)**: qasp direction review — the "!" located from records (verification moves to the front of the pipeline: mate PR #382 close handed the reviewer seat to AI; workflow inversion "know the criteria → implement → PR already passing"; act-1.5 dual timing; web E2E generation with 3-channel cognition). Its identity tension (§5 producer=verdict) closed as **qasp-dev governance §8 verdict-independence** (domain-respect unbundled from verdict-independence; UNVERIFIED=blocking label; promotion preconditions), codex-audited 8/8. **mate_rules split into mobile_rules (7 common) ⊃ mate extension (4 convention rules)** — full compatibility preserved, 1364 tests green, codex-audited 3/3. Company-handoff tasks landed dev-side: `--checklist` command, review-bot `--diff-json` surface (consumes pr-agent's own artifact), preflight workflow doc, and a mate-dev advisory CI lane (`qasp-rules.yml`, neutral check, 3 marked line-swap points for the company circuit). PR-review video triaged: mostly convergent with existing doctrine; template direction rejected by operator (human-PR fatigue, #382 precedent) — evidence must be a byproduct of pre-PR self-verification, not a demand on authors.

### 2026-07-24 (2) | forge-harness · forge-wiki · llmwiki-template | #sister-links, #full-gate, #frontier-digest-angle-rule, #query-refresh, #mapping, #light-harness, #graph-engineering
**File:** knowledge/shared/dialogue/memory_intent_recall.md · knowledge/shared/harness-core/field_harness_diagnostic.md · knowledge/shared/harness-core/multi_model_sidecar_strategy.md · plugins/fh-meta/skills/harness-doctor/SKILL.md · plugins/fh-meta/skills/frontier-digest/SKILL_detail.md · tracks/forge-wiki/ · tracks/llmwiki-template/
Second half of the 07-24 hub session (PR #174 + two field repos). **Sister anchors executed under the full 4-axis gate** (the four links #173 deferred): GRACE into memory_intent_recall (instruction-graph boundary spelled out) and harness-doctor Step 2-E (C-layer maintenance-path ledger, ETCLOVG-style anchor-only), the 7-criteria rubric as a considered-and-held note with two re-check triggers in field_harness_diagnostic, and the wsff RL-incentive causal anchor ("maintainability has no fast oracle") beside the harness-ceiling principle in multi_model_sidecar_strategy. **frontier-digest repaired on two axes**: the stale arXiv canonical query replaced ("AI software testing"→"LLM agent evaluation", refresh criterion written down) and an Angle rule added to the synthesis prompt closing the methodology-angle silent drop (fh_signal 07-24 #3) — verified by a blind Sonnet known-pair sim (dual-angle item surfaced, single-angle item not forced) plus a quench-challenger pass (HIGH 0 · MED 2 · LOW 3; MED+2 LOW repaired in-branch). **Two sibling repos mapped and light-harnessed** (forge-wiki = chamber run #9's first EMIT, public; llmwiki-template = its company-side private twin): tracks/ dirs, session rules, .claudeignore — env card and MCP gating skipped by judgment (residency / no external mount); both merged (forge-wiki #4, llmwiki-template #2), llmwiki's CLAUDE.md kept operator-local. Positioning decision recorded in both tracks: **a wiki that sits under the harness** (Harness ⊃ context/knowledge component) — "wiki" is the outward word, "harness knowledge layer" the architecture coordinate.
- Decision: first live measurement of the Angle rule and the new query is the next 09:00 digest run — manifest predictions pinned; npm republish proposed at close rather than auto-published; forge-wiki merged its hub-linked CLAUDE.md publicly by operator approval.
- Open: ETCLOVG citation's operator-local label retrofit; wsff follow-up (design FH's own deep-clarify before/after measurement) unstarted; Graph-layer chamber candidate maturing with multi-source anchors; company handoff (qasp-preflight→mate PR workflow, 07-25) carried to next session.

### 2026-07-24 | forge-harness | #sister-asset, #grace, #context-quality-rubric, #graph-engineering, #judged-vs-measured, #frontier-digest
**File:** tracks/_audit/session_2026_07_24_grace-context-rubric.md · tracks/_meta/fh_signal_2026-07-24_frontier-digest.md
Bundled sister-asset triage closing the 10-day GRACE execution lag, plus the 07-24 digest chain. **GRACE (arXiv:2607.09175)** registered as an A-tier sister: typed-semantic-graph context maintenance with scoped verification (validate only the local typed neighborhood of modified nodes). Import candidates: neighborhood-first consistency checking for memory-hygiene/verify-bidirectional (a cost ceiling on the "re-grep everything" propagation rule), and the checkpoint-incremental-reconstruction shape as an external anchor for delta-update discipline. Category boundary held explicitly: GRACE's instruction graph ≠ the execution-orchestration Graph layer (chamber candidate) ≠ the memory recall graph — three different categories, not one "graph" asset. **Context-quality 7-criteria rubric (arXiv:2607.14275)** verdict: HOLD — scoring runs on ProofAgent-Harness multi-juror consensus, i.e. judged-not-mechanical, failing the digest's stated adoption precondition (mechanically scoreable on a known pair); re-check triggers named (deterministic rubric ships, or token-efficiency/tool-schema subset proves mechanizable). **Graph engineering** upgraded from n=1 video to multi-source convergence (AI Builder Club 4-question graph-vs-loop discriminator · TrueFoundry 7 governance requirements — delta for FH is typed run-identifier propagation only). **wsff.md (humanlayer, Dex) triaged same-pass** after full read: the digest's claimed absorbable unit — a "review burden hours→minutes measurement design" — does **not exist in the source** (its quantified content is the Faros AI correlation dataset, self-caveated by the author as "correlation signal, not smoking gun"; the front-loading benefit is an unmeasured personal assertion), so the import downgrades to motivation for FH to design its own deep-clarify before/after measurement. Its floor-vs-ceiling thesis dedups against the existing harness-ceiling principle; the genuinely new increments are the RL-incentive causal argument ("maintainability has no fast oracle, so RL cannot reward it" — the sharpest external anchor for why the HITL floor is structural, not transitional) and the Faros correlation numbers with caveat inherited.
- Decision: rubric lens NOT adopted (judge-only as shipped); wsff absorbed as two anchors, not doctrine (digest overclaim corrected in the audit record); knowledge/-file sister links deferred to a full-gate Mode D session (citation tokens trigger the substantive carve-out); effort A/B Window-2 resumption deferred to post-Saturday by operator.
- Open: 4 sister cross-links pending (memory_intent_recall · field_harness_diagnostic · harness-doctor 2-E · harness-ceiling anchor); digest→execution return-path gap still open as signal; GRACE ships no code — mechanism anchor only.

### 2026-07-22 (2) | forge-harness · qasp · pmh | #weekly-audit, #entrypoint-drift, #gate-fail-open, #union-silent-drop, #instrument-attribution, #npm-release
**File:** tracks/_audit/weekly_audit_2026-07-22.md · AGENTS.md §Non-Claude runtimes item 4 · templates/regression_guard.sh · (qasp) src/api/ensemble.py · (pmh) AGENTS.md §Orchestration Gates
Weekly audit (07-15~07-22) plus the three cross-repo fixes it surfaced. **Audit's largest finding was a card claim that was false**: the session card's red-flag "frontier-digest job not running — zero logs, zero output" did not survive a hand check (14/14 launchd fires, 12/14 outputs, that day's digest present at 09:03). The real defect is a 14.3% output-miss whose two instances both die on `Connection closed mid-response`, and whose 07-18 retry+watchdog fix engaged **neither mechanism** on its first failure day — recorded as unfixed, root cause not isolated. Card-vs-reality drift reached the N=3 recurrence threshold, so the prescription is a mechanical probe rather than another habit rule. **Entry-point drift** closed in both harnesses (FH PR #163, field meta-harness PR #25): a runtime-default governor rule had landed only in the Claude-native entry point, invisible to every other runtime. The target-tier blind sim rejected the first port — the *wording*, carried over verbatim, read as coercive to a cold third-party reader and was reproduced 3/3, once escalating to "I would flag this to the repo owner". Rewritten as a scope statement; converged 2/2. **Gate fail-open** (PR #165): Axis 1's pathspec omitted three asset classes the canonical rule declares covered, and the resulting not-checked state rendered as a green PASS; adversarial review then caught the fix's own over-blocking (a one-word prose edit produced a hard block) before it could train `--no-verify`. **Field harness UNION** shipped a silent-drop path: two divergent fence-unwrap implementations meant a response accepted by the single backend was discarded whole by the ensemble — in a component whose entire justification is not discarding findings. Published `@chrono-meta/fh-gate@1.4.66`.
- Decision: port constraints across entry points, never wording — the audience's trust relationship changes with the location. Reversible surfaces report SKIP distinctly from PASS rather than switching to a blocking exit code. Company-derived doc conflicts resolve toward the operator-approved integration branch, never toward a feature branch's older state.
- Open: the failed single-vs-UNION detection ratio stays UNCALIBRATED — a demonstrated drop path and the "anchor absorbs the gain" hypothesis produce the same number, and no counter existed to separate them; re-measure with the new instrumentation. Skip-vs-pass distinction is wired into the commit hook only; three prose-level consumers still judge by exit code. Card-drift probe and the retry/watchdog reproduction harness remain unbuilt.

### 2026-07-22 | forge-harness | #intent-marshaling, #doctrine, #purpose-organization, #leader-briefing, #conference, #pre-registration
**File:** knowledge/shared/harness-core/intent_marshaling_general_work.md · CLAUDE.md §Intent Marshaling · (companion store) leader/TF briefing pair · handoff §5-§7
Two operator insights forged into doctrine. **Intent Marshaling** (PR #161, mirrored to the field meta-harness as its PR #23): the runtime twin of intent-machinization — a work-shaped request in plain language triggers a mechanical capability scan (trust tiers carried in scan output), a one-line compose proposal, then run-first execution; gap declarable only by citing the scan; no new gates (install/persist/outward actions route to existing ones). Verified by Sonnet known-pair sim (2/2 separated) + codex cross-family R1 4/4-confirmed findings (2 HIGH: non-FH ask-tier auto-run hole, per-action reversibility fail-open) fixed to R2 CONVERGED. **Leader-judgment briefing pair** (companion store, operator-approved): QA-team edition (4 judgment axes, measured/pending boundary, act-by-act glossary from operator definitions) + org-TF edition (domain-agnostic layers as protagonist, field harness as the n=1 evidence case, method-stack 8/8 as the domain-agnostic quantitative anchor) — both persona-audited (SHIP_AFTER_M, all findings applied; the audits caught the docs' own optimism twice, which became a self-evidencing section). Conference talk submitted (title A) with **metric pre-registration** pinned in the handoff (calibration / field / org metric sets + before-baseline warning + freeze-timeline insurance).
- Decision: marshaling autonomy covers FH-native per-action-reversible work only; non-FH registry hits keep ask-tier; specific initiative rows always outrank the fallback row. Briefing scope split two-audience (QA team vs org TF) rather than one doc.
- Open: marshaling operational track record starts at zero (manifest prediction pending); AGENTS.md port of the marshaling anchor = deferred drift candidate; handoff-reachability defect (untracked file referenced for remote verification) recorded as signal S-1 with a mechanical-check prescription.

> **Backfill note (2026-07-15):** the 07-12 / 07-13 / 07-14 entries below were reconstructed from git
> history + the session card's completion log during the 2026-07-15 harness-doctor run, which found that
> CATALOG had stopped at 07-10 while 30 FH-asset commits landed — i.e. 5 days of work were invisible to
> the CATALOG-first search protocol (CLAUDE.md §Autonomous Initiative (CATALOG-first recall row)). They are commit-grounded, but they
> are *reconstructions*, not first-hand session records: the "Decision/Open" lines carry only what the
> commits and card state, so a judgment made in-session but never written down is not recoverable here.
> The gap itself is the lesson — Comprehension Debt accrues silently when the close chain's CATALOG step
> is skipped.

### 2026-07-14 | forge-harness | #incubator, #chamber-run, #emit-criterion, #kill-as-success, #envelope-boundary, #ship-gate, #dominance-benchmark, #degrade-lint, #reconstructed
**File:** knowledge/shared/harness-core/harness_incubator_doctrine.md · knowledge/shared/harness-core/ship_readiness_gate.md · CLAUDE.md §Envelope-Boundary Discipline · scripts/chamber_run.sh · scripts/chamber_candidate_collect.sh · scripts/degrade_direction_scan.sh · tracks/_chamber/
The incubator's heaviest day (16 commits, PRs #134–#144). **Chamber runs #5–#8 all KILL** — the ledger's honest record stays 8/8 KILL, 0 EMIT: the chamber *screens*, it has not yet *birthed*. Run #5 (degrade-lint EMIT attempt) produced the **measured EMIT criterion** (net-new ∧ artifact-shaped ∧ precision-adequate — scored 0/5 on real code, 5/5 FP); run #6 (harness-orchestrator) added a **4th EMIT axis** (hub-state-independence) + the graduation-order principle; run #7 (cluster-wizard) forced a chamber-scope clarification and exposed that the company-residency guard was prose-only with no machine field → **#144 promoted `residency`+`generality` to registry-scan schema fields**. Discovery pipeline wired end-to-end: `chamber_candidate_collect.sh` (6 sources → dedup → rank → reinvention screen → G4-KILL seen-filter) + `chamber_run.sh` (7-step resumable runner, budget cap, ≥3-blind-persona gate, Emission Gate, ledger auto-append) — honestly scoped: step-4 persona dispatch stays human/Claude-driven (bash cannot spawn isolated Agents), EMIT terminus is HITL. **Ship-readiness gate** formalized (all-green → formal tag) with **v0.1.0 = honest baseline** (0.x semver carries incomplete status; all-green → v1.0.0; npm 1.4.x is a separate plugin-cache number). **Governance dominance benchmark** rounds 1–2: the decorrelated *stack* (lens ∪ cross-family) scored 8/8 on a hard fail-open set vs 5/8 bare and 6/8 single-lens — the finding being that dominance comes from the architecture, not any single reviewer; two blind-spot classes materialized into `degrade_direction_scan.sh` Probes E (falsy-sentinel→PASS) and F (split-positional-verdict). **CLAUDE.md §Envelope-Boundary Discipline** (#138) shipped always-loaded as the reinvention-reflex counterweight — hold the unfamiliar unfamiliar at the boundary instead of normalizing it onto a known asset (blind Sonnet sim 2/2). Identity ①② corrected 🔴→🟡 (#137) after a collapse-to-hardest-mechanism error.
- Decision: KILL is a first-class success (it blocks reinvention); v0.1.0 ships honestly rather than claiming all-green; EMIT-worthiness is screened cheaply against the 4 axes before dispatch.
- Open: first EMIT still 0/8 — the incubator has never birthed; persona convergence on one author remains the top blocker; reps ≥ 3 owed on the single-draw dominance numbers.

### 2026-07-13 | forge-harness | #chamber-namespace, #honest-correction, #overclaim, #cross-family, #simulate-first, #reconstructed
**File:** tracks/_chamber/ · CLAUDE.md (simulate-first branch · §Session-Close ④-b) · knowledge/shared/harness-core/harness_incubator_doctrine.md
Chamber-run namespace + measured routing baseline established (`tracks/_chamber/`, PR #132-ish range), then **two honest-correction passes on the same day**: the simulate-first branch had been written as though a one-command autonomous simulate→EMIT existed, and ④-b's drift-check prose overclaimed its own scope. Both were downgraded to what actually ships (runner exists; EMIT does not; the ④-b grep flags file co-occurrence, it does not determine topical parity — the parity call is judged). The second pass was a **codex cross-family follow-up** that caught residual overclaim the same-family fix had left behind — the sibling-overclaim catch pattern.
- Decision: prose describing a capability must match the shipped muscle boundary; "runner exists" ≠ "autonomous emit".
- Open: (rolled into 07-14's chamber work).

### 2026-07-12 | forge-harness | #identity, #intent-machinization, #incubator-doctrine, #rules-diet, #salience, #register-consistency, #readme, #reconstructed
**File:** knowledge/shared/harness-core/harness_incubator_doctrine.md · knowledge/shared/rules/ (6 relocated) · CLAUDE.md §Voice/Tone · README.md + ko/zh/ja
Identity day. The operator-forged doctrine — **a harness machinizes intent** (`intent → forge → agreement (HITL) → machinery`), its payoff being that trial-and-error relocates off the human into the harness — was mechanized into `harness_incubator_doctrine.md` + the CLAUDE.md §Identity paragraph: FH is the **meta-harness and nursery** that incubates field harnesses in its own sandbox and emits them, operating over other harnesses as **compose ∪ disrupt** (core invariants never melt). **Rules diet** (the day's biggest measured win): 6 always-loaded protocol rules relocated `.claude/rules/` → `knowledge/shared/rules/` with pointers staying in CLAUDE.md — always-loaded footprint 106.5k → 81k chars (operator-measured −18.2k resident on a fresh top-level session; the measurement is only valid from a project-cwd top-level `/context`, not an Agent-View window). **Register-consistency** promoted into public CLAUDE.md §Voice/Tone after an Opus session drifted into 존댓말 — the rule had lived only in memory, and memory-only placement is what let it miss. Onboarding translation-guard fixed (the welcome line must be a plain native translation, not an invented coinage). READMEs reframed (solar-system framing + 4-pillar section) across 4 languages. Releases v1.4.53–v1.4.56.
- Decision: rules relocation over compression — governance-semantic split, pointers stay; salience rules that miss when memory-only get promoted to always-loaded.
- Open: the rules diet landed at 81k, barely over the 80k M-tier footprint threshold, and regrew to 85k within 3 days (see 2026-07-15).

### 2026-07-10 | forge-harness | #sonnet-floor, #doctrine, #loop-engineering, #tier-census, #cross-family, #pre-commit-gate, #dispatch-first
**File:** knowledge/shared/harness-core/sonnet_floor_doctrine.md · knowledge/shared/harness-core/loop_engineering.md
Encoded the operator-declared **Sonnet-Floor Doctrine** (base ops 100% Sonnet-runnable; tier-gated capability = defect; escalation = dispatch, never substrate; depth ladder = effort→dispatch→anchored-Sonnet) as a canonical axiom node, plus **loop_engineering.md** (5-question design-time discipline + FH loop inventory MECH/PROSE census + evidence-threshold hardening backlog). Cross-family evolution pass: codex gpt-5.5 xhigh repo census (T1 tier refs / T2 loop legs / T3 contradictions) + agy Gemini 3.1 Pro breadth (pattern-level only, zero citations imported — phantom-risk URLs). All 6 identified availability-gates fixed: pre-commit Axis-2 gains a **sonnet-floor lane** (anchor-required, R-tier auto-queue, 8/8 regression fixtures in scripts/test_marker_floor_lanes.sh), self_evolution weekly dead-end recast dispatch-first, Mode D notice re-directed (keep Sonnet + dispatch primary), canary opus-judge → Sonnet-governor+anchor, verify-bidirectional "never stay at sonnet" fixed, 9 SKILL.md `model: opus` hard pins retired (session-inherit). Trust-floors tightened to run-first/ask-last (full Sonnet autonomy; gates stay). Sonnet blind sims: 2 dispatched, 1 salience miss caught (loop-stub enumeration) → hardened → re-sim PASS.
- Decision: Sonnet = the optimization target, measured spine = H1 (harness benefit largest on weaker tiers); Opus/Fable-only capability is now a named defect class with a census discipline.
- Open: quarterly/substrate loop rows are governor self-assessment (R-tier external census pending); sonnet-floor markers queue via below_floor_scan.sh R-tier lane.

### 2026-07-07 | forge-harness | #sister-asset, #cross-audit, #revfactory, #harness-100, #agent-composer, #benchmarking, #linkedin, #source-verification, #diffusion-llm
**File:** tracks/_audit/session_2026_07_07_revfactory-harness.md
Sister-asset cross-audit of `revfactory/harness` + `revfactory/harness-100` (AX TF lead-recommended benchmarking target) vs FH — their axis = one-shot team-architecture generation + a 200-harness ready library (breadth/quick-start); FH's axis = dynamic composition (`agent-composer`) + governance (4-axis gate, irreversibility floors, continuity), which their pipeline lacks entirely. Plus LinkedIn source-verification for the operator's 2 queued insight links: diffusion-LLM paradigm-shift paper confirmed accurate (ICML 2026 Outstanding Paper Award, JustGRPO, arXiv:2601.15165 via official ICML blog); "Claude Code loop-engineering" post confirmed to be about `k021/claude-code-skills` — the *same* sister-asset Gemini already analyzed, not new content.
- Decision: no functional import beyond a C-tier team-pattern naming label for `agent-composer` output; FH's governance moat holds (revfactory doesn't compete on that axis). Both LinkedIn links closed.
- Open: adopt 6-pattern naming in agent-composer (operator HITL); harness-100-style pre-built library stays gated behind the existing 3+-recurrence trigger.

### 2026-06-27 | forge-harness | #sister-asset, #cross-audit, #hermes-agent, #nous-research, #self-improving-agent, #skills, #memory, #messaging-gateway
**File:** tracks/_contrib/session_2026_06_27_hermes-agent-nous-self-improving-cross-audit.md (committed via _contrib consent lane — authored in an ephemeral cloud session where tracks/_audit/ is gitignored/non-durable)
Sister-asset cross-audit of **Hermes Agent (Nous Research)** vs FH, triggered by a LinkedIn post (esperer) distilling Hermes' official *Tips & Best Practices* (post = faithful doc summary, not original methodology; same summary circulates on Threads). ~90% of Hermes' best-practice surface is already present in FH (persistent memory · auto-skill-from-repetition · skill self-improvement · context economy · delegation · model selection — all grounded to `plugins/*/skills/`), and on the **self-improvement + governance** axis FH is *ahead*: Hermes *advises* "review auto-generated skills," FH *mechanically enforces* it (pre-commit 4-axis gate + steel/phantom-quench + HITL). Key honest finding — most apparent "gaps" dissolve: cron/daemon is a **deliberate FH boundary** (`self_evolution_routine.md` §8 "recommendation surface, not a daemon"), external-memory-providers **already audited** (companion-store pluggable, 2026-06-11). Only genuine absence = **messaging gateway** (Telegram/Slack daily-driver), which is a *delivery channel*, not methodology.
- Decision: thin real increment (FH at/ahead of frontier on methodology). Convergence is evidence FH's core thesis is now frontier-standard; differentiator narrows to governance (sharpens positioning). Import candidates: messaging-gateway *boundary-record* (1 line in modes_and_value), front-load-context onboarding tip, write_approval framing — all C-tier/operator-gated.
- Open: operator decision — (1) record messaging-gateway as deliberate out-of-scope boundary or leave unaddressed (recommend: record); (2) fold onboarding-tip wording into dialogue playbook or skip.

### 2026-06-27 | forge-harness | #sister-asset, #cross-audit, #loop-engineering, #harness-engineering, #verification, #generator-evaluator, #hitl
**File:** tracks/_audit/session_2026_06_27_loop-engineering-silbal.md
Full sister-asset cross-audit of the "Loop Engineering" video (실밸개발자, 2026-06-22, 37min, source-closed via yt-dlp transcript) vs FH — a Korean harness-engineering creator's self-stated Prompt→Context→**Harness→Loop** lineage. Strong independent convergence with FH: "verifiable goal or it's a token-burning machine" = Done-When/check-class; Generator≠Evaluator mandatory split (cites Lance Martin 6× measured) = judge-robustness/no-judge-only-path; Osmani's 6 components (Automation/Worktree/Skill/Connector/Sub-agent/Memory) = component-lens orthogonal to FH's 6-axis process-lens (same isomorphism already logged for ETCLOVG); Human-in→Human-on = HITL floor+governor. FH propagation increment beyond the frame: Surface-Class Degrade Invariant (irreversible→fail-closed, structurally blocking the video's #4 "production accident" mode that it only budget-caps) + Typed-Verdict Channel + surface-class-scoped HITL. Convergent with same-day frontier digest (reliability/control = consensus axis — Fowler, Statewright, both frontier-digest-sourced/not independently verified; Semantic Early-Stopping −38% = the video's stop-condition).
- Decision: A-tier full audit (new loop-engineering resolution, not the C-tier dedup path). Import 3 (loop=cron+state-reading-model one-liner; training-mode-dry-run→graduated-autonomy ladder; Lance Martin 6× as external judge-robustness anchor — re-verify source before any published cite). No external delivery (YouTube = no write surface); creator-channel quarterly re-scan (active Harness→Loop thread).
- Open: import-3 distillation is operator-gated (HITL); phantom-citation guard on the Lance Martin "6×" and any digest arXiv IDs before they enter a shipped asset.

### 2026-06-26 | forge-harness | #sister-asset, #cross-audit, #harness-engineering, #awesome-list, #listing-target, #irreversibility, #phantom-citation
**File:** tracks/_audit/session_2026_06_26_awesome-harness-engineering.md
Sister-asset cross-audit of `ai-boost/awesome-harness-engineering` (~2k★, CC0, 180+ items, the now-named consensus field index) vs FH — breadth-index ↔ FH operating-governance depth; the list's own philosophy ("the model can't do it alone") is FH's thesis stated by the field. Import-first (bidirectionality): Harmonist (IDE-hook non-model gate "even frontier models cannot override" = independent convergence with FH's pre-commit 4-axis + judge-robustness anchor), OAP (fail-closed + *cryptographic* audit — the crypto-marker FH's GPG-option residual lacks), nah (intent-taxonomy permission guard ↔ mcp_tool_gating), OWASP LLM06 (the *real* external anchor for #121). Dedup/independent-convergence: "What makes a harness a harness" 4-condition litmus (FH already imported via sanguinekim §6) + NLAH (already governance-moat-measured). FH propagation increment = Surface-Class Degrade Invariant (irreversible→fail-closed direction, absent from the list's gates) + adversarial-derivation provenance + surface-class-scoped HITL floor.
- Decision: FH not listed → early-listing window under Generators & Meta-Harnesses (fh-gate npm); submission deferred to operator HITL + Pre-Publish Gate + 3-persona audit (external-facing PR, governance-depth single entry not self-promo).
- Open: (1) listing-PR GO is operator-owned; (2) side-finding — frontier-digest emitted a **phantom arXiv (2606.26094 ≠ the cited title)**, NOT cited; logged as auto-pipeline phantom-injection signal.

### 2026-06-24 | forge-harness | #sister-asset, #cross-audit, #ponytail, #measurement-integrity, #mechanical-anchor, #agent-portability, #growth-lessons
**File:** tracks/_audit/session_2026_06_24_ponytail-lazy-senior-dev.md (+ cross-ref links: multi_model_sidecar_strategy.md, measurement-integrity-checklist.md)
Full sister-asset cross-audit of `ponytail` (DietrichGebert/ponytail@dedc97c, ~50k★ reviewer-claimed/unverified, "lazy senior dev" minimal-code field skill) vs FH, run with 3 sidecars (Codex repo-grounded gpt-5.5 + Gemini 3.1 Pro breadth, identity-probe verified + CC FH-doctrine extraction); governor source-closed every load-bearing claim to repo file:line (phantom-quench: 10 GROUNDED/0 PHANTOM). Convergence on 4 axes (strongest = axis C verify-instrument, where independence is clearest; A/D may be shared-ecosystem-standard): portable-AGENTS.md+thin-adapter distribution · safety-guard-never-cut + *measured* (20/20 adversarial tier vs bare prompt 95%) · verify-instrument-before-measuring (twice — #126 baseline artifact + hook-bleed) · residual-as-tracked-debt (un-named gap = the only failure signal). FH increment = the safety guard is prose at every host (hooks only inject ruleset; check-rule-copies.js guards text-drift not runtime), so FH's mechanical-anchor + adversarial-regression layer is the gap to fill.
- Decision: import 3 (platform-native table, --selftest dogfood example, behavior-grader sharpening for prompt-regression); propagate 3 to ponytail (mechanical-anchor option, adversarial regression on minimized diffs, reps≥3 on safety) via humble issue after persona audit; growth = a **field-skill spin-out that feeds the hub**, NOT re-pointing the meta-harness toward virality (reference-asset identity held; missing lever = a visible before/after).
- Open: external #3 delivery gated on 3+ persona × 4-axis audit + operator GO.

### 2026-06-14 | forge-harness | #crucible-mode, #total-immersion-absorption, #design-decision-lens, #completion-claim-discipline, #self-forge, #sister-asset
**File:** knowledge/shared/harness-core/crucible_mode.md + harness_design_decision_lens.md + harness_6axis_framework.md (Completion-claim discipline) + tracks/_audit/session_2026_06_14_wikidocs-deep-sweep.md
Content-level deep cross-audit of two wikidocs sister books (19689 백과사전 / 19736 Allen 멀티에이전트) via live-surface Playwright ingest + Gemini/Codex debate-loop + governor source-close, then **absorbed every candidate that passed the identity gate** (FH-identity-preserving + positively-expandable). Three assets: (1) `harness_design_decision_lens.md` — the 7 architectural-bet decisions as an orthogonal companion to the 6-axis lifecycle (only net-new = the framing; rest ALREADY-HAVE, honestly marked); (2) 6-axis **Completion-claim discipline** — a "done" claim must carry evidence + failure-checks-run + residual risk, non-vacuous; (3) **`crucible_mode.md`** — names the total-immersion absorption *stance* (throw the whole corpus in, melt under adversarial heat, keep only what bonds to an **unmeltable adamantium core**; rejections are boundary-defining). Each absorption was itself put through the crucible (quench-challenger + persona-auditor + Sonnet blind sim) — the crucible doc's own quench caught 3 of its defects (incl. a phantom worked-instance claim) before commit.
- Decision: unmeltable-by-absorption ≠ unchangeable-by-operator (anvil signal = N≥3 recurrence → verify-bidirectional); Redis multi-agent bus rejected as out-of-identity (speed/ops); productivity/ROI over-claims quarantined. Operator insight seed: "포지하네스는 자기자신도 용광로에 빠뜨려 단련하지만 그 심지는 아다만티움처럼 결코 녹지 않는다."
- Open: HITL commit decision (this batch); adamantium core list (5) is operator-owned.

### 2026-06-14 | forge-harness | #debate-circulation-loop, #sister-asset, #sidecar-mining, #governor-source-verification, #import-list-first
**File:** knowledge/shared/harness-core/multi_model_sidecar_strategy.md (§Debate Circulation Loop) + tracks/_audit/session_2026_06_14_fh-reinforcement-mining.md
Promoted the **Debate Circulation Loop + governor source-verification** methodology from memory to the public sidecar doc — relay a multi-runtime question, mutual peer critique (a runtime's blind spot is invisible to itself, visible to a peer), CC/Opus governor closes against *source* (a debate is also judged → bind to a mechanical anchor), promote only the source-verified residue. Demonstrated live by mining two operator-designated FH-reinforcement sources: **oh-my-claudecode** (Codex governance critique → mostly ALREADY-HAVE, 1 gated increment = Ralph Done-When hardening; speed-first substrate rejected per governance-over-speed axis) and **wikidocs book/19736 = 「하네스 엔지니어링 백과사전」** (Gemini ingest past a governor 403; a same-topic "Agent = Model + Harness" encyclopedia, mostly independent convergence + 2 gated follow-ups: Ch12 7-decisions/3-contrarian, Ch11 12-patterns).
- Decision: import-list-first held on both; no clone-and-own. Source B content beyond TOC is Gemini-one-surface, governor-unverified (403) → import candidates are explicit follow-ups, not confirmed.
- Open: (a) Ralph Done-When phrasing → goal-quench/pipeline-conductor PR (HITL); (b) Ch11/Ch12 content access → cross-audit vs 6-axis + pattern library.

### 2026-06-13 | forge-harness | #judge-robustness, #mechanical-anchor, #hardening-batch-2, #sycophancy-gate, #verification
**File:** plugins/fh-meta/skills/{verify-bidirectional,steel-quench,asset-placement-gate}/SKILL.md (commit f80bc99)
Batch-2 of the judge-robustness hardening (after #1-#2 in be2d5dc): three more judge-only verdict paths bound to anchors. #3 verify-bidirectional evidence gate — a persistent-baseline overwrite needs a supporting cited source (read, not existence) or a grep contradiction, else ESCALATE+block; closes the bare-pushback sycophancy vector without restoring AI stubbornness. #4 steel-quench Wave-P3 PASS-framing redaction (mktemp glyph+verdict-phrase strip — the challenger caught a naive bare-PASS global corrupting "status==PASS", an S fixed pre-commit). #5 asset-placement Step 0.5 mechanical pre-grep grounds criterion ④. challenger-verify round 2 was load-bearing again (FAIL→fixed: 1S+2A+4B); sonnet blind sim PASS (evidence gate ESCALATEs on bare overwrite).
- Decision: #6 sim-conductor (A) deferred — its cross-model hard-gate needs graceful degradation for CC-only environments; not rushed into the batch.
- Open: #6 sim-conductor staged; npm republish (1.4.21) bundling be2d5dc + f80bc99 pending operator.

### 2026-06-13 | forge-harness | #judge-robustness, #mechanical-anchor, #verification-hardening, #self-audit, #scaled-dispatch
**File:** plugins/fh-meta/skills/phantom-quench/SKILL.md + templates/.git-hooks/pre-commit + CLAUDE.md/CHEATSHEET (commit be2d5dc)
Deep-research + a 6-agent parallel swarm audit turned FH's own adversarial method on FH: armed with arXiv 2507.08794 ("One Token to Fool LLM-as-a-Judge"), cold agents found 5/6 of FH's judged-check skills S-exploitable. Common root cause: every terminal verdict is judge-only with no mechanical checksum. Shipped the two highest-leverage fixes — (#1) the pre-commit gate marker now requires a non-vacuous, auditable axis2-evidence field, with the residual (provenance against a self-deceiving runner) documented honestly as the weekly-audit's+operator's, not pretended-closed by a false-security HMAC; (#2) phantom-quench GROUNDED is now gated on a typed mechanical anchor (proper-noun grep-in-asserting-slot / numeric value-after-normalization / branching decompose-or-declare-judged; universal rule: a hit counts only if the line expresses the claimed relation), closing out-of-context grounding. challenger-verify caught a real over-block regression (format-variant false-flag) before it shipped; sonnet blind sim PASS.
- Decision: bind judged verdicts to mechanical anchors where one exists (verifiability constraint); ship #1-#2 first, stage #3-#6 (verify-bidirectional evidence gate, steel-quench redaction, asset-placement grep, sim-conductor cross-model) — rushing all six would be the over-verification the same research warned against.
- Open: hardenings #3-#6 staged; scaled-dispatch meta-lesson = value is real-target coverage (~1 reviewer per asset), not agent count.

### 2026-06-13 | forge-harness | #deep-research, #capability-ladder, #no-reinvention, #routing, #goal-quench-max
**File:** knowledge/shared/harness-core/deep_research_capability_ladder.md (+ CLAUDE.md initiative row, goal-quench/frontier-digest SKILL.md) (commit 55fa3da)
Deep-research as an FH default — lifts the /deep-research engine ladder that was locked inside frontier-digest into a general routing default. 3 rungs: built-in /deep-research if present → Claude WebSearch+WebFetch synthesis (always available, tier-sensitive) → frontier-digest for AI/harness trend-scan only. No-reinvention: FH routes to the best capability present, builds no research engine. Wired as a CLAUDE.md Autonomous Initiative Layer row (default invocation) + goal-quench max-mode capability-gap fill (flexes in when budget RED), with rung-2 research run in an isolated sub-agent to preserve max's context budget. 4-axis: challenger PASS no-S (4B applied incl. the isolation invariant) + sonnet blind sim PASS (correct rung, trend-scan boundary held).
- Decision: single-source the ladder (frontier-digest Step-0 becomes a consumer/rung-3, not a parallel definition); /deep-research stays conditional-detect everywhere (phantom-safe).

### 2026-06-13 | forge-harness | #sidecar-eol-proofing, #agy, #liveness-probe, #rubber-stamp-guard, #upstream-report
**File:** plugins/fh-meta/skills/{steel-quench,sim-conductor}/SKILL_detail.md + templates/.git-hooks/pre-commit (commit 4693d00)
Completion sweep of all currently-unblocked carries. FP3: agy joins the sidecar panel as T5 (argument form `agy -p` only — stdin pipe prints help, measured; 60s timebox+1 retry hard rule; trusted-artifacts caution since -p auto-approves tools) and gemini detection becomes a dispatch-form stdin liveness probe (EOL 2026-06-18 leaves the binary alive, backend dead — bare `command -v` goes silently stale). Ack hardening: `below-floor-ack:` now requires a verbatim-quoted operator utterance (unquoted reason = agent-self-writable = blocked; residuals — quote fabrication, out-of-context quoting — named as weekly-audit targets). Challenger round: 1S/4A fixed (cross-fence tb() self-containment, probe-form/dispatch-form mismatch, T1~T5, empty-team synthesis gate, comment overclaim); B1 curly-quote locale block refuted by live test. FP1 closed upstream: increment comment (auto-compact non-recovery + 76% non-repro control) posted to anthropics/claude-code#65359 with operator approval. Knowledge orphans resolved: 3 gitignored paper files de-orphaned (unique framework rescued to companion store, stale dupes deleted).
- Decision: probe must exercise the same invocation form the dispatch uses (forms diverge on one binary — agy proved it); hook enforces ack form, weekly audit owns genuineness.

### 2026-06-11 | forge-harness | #readme-dedup, #commoditization-defense, #b1-boundary, #seed-vetting, #field-routing
**File:** README.md (PR #93) + companion-store signals/handoffs (PR #24+) + field project v0.14 (private track)
Cloud session #4 (Mode D, remote-doable batch): README stale duplicate "Measured, not asserted" block removed (pre-tier-floor copy contradicted default-Sonnet stance) + "Where this sits (2026)" positioning para (gate+loop are the asset — plumbing commoditizes). Companion store: B1 scope boundary (AW2 simple-vs-complex import), SC1–4 seed vetting (SC1 phantom arXiv fixed → 2509.19349; SC3 commoditization threat to bet ID), gstack positioning-triangle line. Field: private-track companion handoff verified+executed — DefectPatternMatcher+Bug Mode implemented UTF-8-clean in the field repo (25 tests PASS, 0 regressions); its OpenCode(sLLM) lane's downgrade triage hardened to 2-tier (keep/block) with free-tier 80/20 split — β/SC2 field case logged.
- Decision: README action PARTIAL (merge done; About refresh + npm 1.4.14 laptop-bound); full-TC locked on local-LLM build per operator's CaseCraft limit measurement — structure-transform survives (P6/P6.5 deterministic), meaning-fill routes to frontier.

### 2026-06-11 | forge-harness | #mcp-gating, #external-mcp, #name-keyed-policy, #measured-origin, #field-template
**File:** templates/.claude/rules/mcp_tool_gating.md (+ auto_project_mapping.md §6 row 4, CLAUDE.md mount-intent trigger)
Cloud session (Mode D, ext): new field template — external-MCP tool gating with three tiers (ask / ask-meta-write / allow-untrusted-read), name-keyed because server-supplied annotations are unreliable (measured same-day: live messaging-class MCP shipped all-None hints incl. irreversible send + approval-resolution tools — companion store `signal_2026-06-11_hermes-mcp-cloud-boot.md`). Opus challenger caught the name-spoofing hole (server controls names too → behavior-confirmation required for non-ask tiers, fixed inline); sonnet blind sim PASS on unfilled-§3 scenario (per-item ask on send, batch approval-grant refused).
- Decision: prefer host-native per-tool permission config as enforcement; this template = what-to-gate + portable fallback. §6 install row is conditional (MCP present); the proactive mount-intent trigger is the load-bearing path.

### 2026-06-11 | forge-harness | #identity-marker, #door-skeleton, #target-tier-sim, #below-floor-consumer, #false-control-kill
**File:** CLAUDE.md §Active Onboarding (+ fh_detail_protocols.md, scripts/below_floor_scan.sh, knowledge/shared/rules/operations.md)
Cloud session (Mode D): 🐿️ marker folded into the returning-user door skeleton — one salience unit with the menu, closing the sonnet-sim marker-drop residual (`fh_signal_2026-06-11`); verified by blind sonnet Agent sim PASS (verification tier = failure tier; in-session model-pinned dispatch available in cloud, no headless fallback needed). 6/15 billing one-line amendment rode the same CLAUDE.md edit (no churn commit). below_floor_scan.sh ships as the standing consumer the pre-commit hook promised ("weekly audit re-queues below-floor markers") but never had — resolution via `floor-rerun:`/`floor-writeoff:` marker appends, wired as weekly Phase 1.5 step 2.
- Decision: ack rubber-stamp (card item 4) closed via route-around — build the re-run consumer, leave the ack untouched (per opus-challenger verdict on the reverted regex attempt).
- Decision: opus challenger PASS 0S+3B — marker-append/hook-collision replicated CLEAN; P9 check: "builds the control, not paper-over".

### 2026-06-11 | forge-harness | #p9, #harness-bulk, #check-class, #model-portability, #steel-quench
**File:** plugins/fh-meta/skills/steel-quench/SKILL.md (+ knowledge/shared/harness-core/multi_model_sidecar_strategy.md)
Two field-validated generalizations promoted to the public mirror (origin: 2026-06-08 field reversal — a weak open-weight model's domain ceiling proved iteration-proof while the pipeline thickened to compensate): (a) steel-quench Cross-Project Patterns gains **P9 harness-bulk-as-model-compensation** (route the task class to a stronger model; never paper over a capability ceiling with more harness — signals are measured: steps added for one model's weakness, quality flat while step count rises); (b) sidecar strategy gains the **check-class = model-portability map** principle (mandatory-pass + mechanical-measured port by construction; judged is where model choice matters, bounded by judged-pairing and §Floor governance re-runs).
- Decision: 4-axis gate ran with opus challenger (CONDITIONAL_PASS → A-grade measured-class over-claim narrowed inline + 4 B fixes) + blind sonnet target-tier sim (P9 fixture correctly classified + routed) — the salience row survives the field tier.
- Decision: P9 scope-tagged to the field axis ("simpler over time"); meta-harness complexity that earns its scope is explicitly distinguished.

### 2026-06-10 | forge-harness | #destructive-op-gate, #irreversibility, #silent-loss, #branch-cleanup-incident
**File:** CLAUDE.md §Destructive-Op Gate (+ templates/predelete_check.sh, scripts/selfcheck.sh)
Third irreversibility gate (sibling of Pre-Publish): enumerate → recover → destroy, never destroy-then-check. predelete_check.sh classifies branches SAFE/CHECK/REVIEW (CHECK = 0 unique paths but commits off base — shared files may hold newer content, the silent-loss class); REVIEW blocks scripted deletes (exit 1); the recovery step is judged/depth-sensitive (strongest-tier floor semantics). Signal-table row fires on destructive intents proactively. Origin: same-day incident — a parallel session's card (weekly-audit done + #88) lived only on an unmerged 0-unique-path branch; pre-deletion enumeration recovered it. Dogfood replay: the script lands that exact branch in CHECK.
- Decision: safety mechanized rather than tier-escalated — Sonnet-default stays valid because the gate carries the depth, with the judged step floor-routed for the residual.
- Decision: scope split vs Pre-Publish kept explicit (publish = exposure irreversibility, destroy = silent-loss irreversibility).


### 2026-06-10 | forge-harness | #mode-d-notice, #model-guidance, #self-dev-entry
**File:** CLAUDE.md §Mode D Model Notice
Conditional model-pin guidance at self-dev entry (operator request): fires once at the 4-axis gate's own activation trigger — session model opus+ = silent · below-opus = one-line pin recommendation with measured rationale · identity-withheld runtime = static fallback. Advisory only, never auto-switches (pin-is-not-a-cap); field-operation sessions never see it.
- Decision: zero new triggers — reuses the gate activation condition; the notice and the gate share one detection point.


### 2026-06-10 | forge-harness | #tier-floor-quench, #below-floor-live, #floor-governance, #dual-challenger
**File:** knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Floor governance (+ quench-challenger.md)
Tier-floor design quenched same-day by dual challenger dispatch — F1 opus (floor met) + F2 sonnet (below-floor; floor=opus): first live firing of the below-floor flag, on the design that defines it. Both tiers found the same 2 S-grades: cross-provider "floor-equivalent" undecidable (vibes equivalence) and re-quench tags with no consumer (permanent silent degradation). §Floor governance ships the fixes: external tiers below-floor-by-default until measured equivalence entries (the backend×tier ladder is the evidence source); below-floor judged verdicts provisional until floor re-run or operator acceptance, weekly audit = standing consumer; floor: hard for depth-critical roles (floor outranks diversity); diversity_rationale tie-break; claims age; pin-is-not-a-cap resolution. Wave-T runs #11/#12 both τ-PASS (fix-traceable complexity only).
- Decision: below-floor challenger empirically buys value (sonnet 6/6 real findings, 2 unique) but misses the deepest (opus-only hard-floor insight) — F2 doctrine and the floor both validated by the same experiment.
- Open: first weekly-audit below-floor consumption + first measured equivalence entry (laptop ladder).


### 2026-06-10 | forge-harness | #tier-floor, #model-resolution, #default-sonnet, #sidecar-protocol
**File:** knowledge/shared/harness-core/multi_model_sidecar_strategy.md (+ quench-challenger.md, steel-quench SKILL.md, README.md, templates/CLAUDE.md)
Tier-floor resolution ships — the model dimension of the Sidecar Engine Resolution Protocol: assets declare measured-or-justified tier floors (quench-challenger=opus, Wave-T/harness-doctor=sonnet measured, mechanical=none); environment resolves R1 native dispatch / R2 cross-provider / R3 below-floor-with-flag (never hard-fail). Public guidance flips to default `/model sonnet` + floored dispatch; human-set session defaults are inviolable (FH dispatches sub-agents, never switches the session model); pinning the strongest available model recommended only for harness-editing (Mode D).
- Decision: floor-not-pin semantics; below-floor judged verdicts auto-tagged re-quench candidates (Degraded coverage rule extension); no specific top-anchor model or subscription window named publicly (anti-stale).
- Decision: grounded in same-day measurements (operation tier-flat 100/100/97/94; depth differential on design increments only) — the guidance flip and the mechanism ship together, neither alone.
- Open: first organic below-floor dispatch + first Sonnet-default external install feedback (verify_next em-2026-06-10v).


### 2026-06-10 | forge-harness | #model-tier, #tier-flattening, #worked-example, #output-evidence
**File:** docs/OUTPUT_EVIDENCE.md (+ README.md §Model setup)
Model-tier flattening measured and published: 30-point blind battery (rule-application + meta-dev fixtures, pre-registered rubric) on four Claude tiers — operation 100/100/97/94 (anchor/Opus 4.8/Sonnet 4.6/Haiku 4.5), tier separation only on above-rubric design increments (3/3·1/3·0.5/3·0/3). Public claim scoped honestly: single trial, self-graded, worked example not benchmark. README §Model setup gains the evidence note grounding the existing Opus recommendation.
- Decision: operating FH ≈ model-flat (the harness is the score); developing FH is where tier matters — recommendation unchanged (opus for harness-editing/gates), now evidence-backed. **[superseded same-day by the tier-floor entry above: default flipped to sonnet + floored dispatch; opus pin now Mode-D-only]**
- Open: real local-LLM-class measurement on laptop (batteries are a portable fixture pack, companion-store record).

### 2026-06-10 | forge-harness | #fc, #consent-lane, #federated-compounding, #starved-center, #v3
**File:** tracks/_contrib/README.md (+ .gitignore, templates/contrib_session.md, docs/CONTRIBUTING.md, README.md)
FC F1 pour — the consent lane opens (operator override: "실제증명으로 찍어누른다" — real-proof-first supersedes the v2-submission latch). `tracks/_contrib/` becomes the only tracked subtree under tracks/: surgical 2-line un-ignore, placement = consent, PR-time lane gate (PSA + marketplace-gate C5 + ingest contradiction scan + reviewer). Lane charter + session template + CONTRIBUTING §Consent Lane + README row shipped — exactly the don't-overbuild list, no new skill/verifier.
- Decision: operator lifted the v2 latch (2026-06-10) — paper timing no longer gates feature publicization; proof-by-shipping doctrine recorded in the lab ledger.
- Decision: privacy default unchanged — the lane is consent-by-placement; the firewall (PSA/Pre-Publish/4-axis) is the lane's load-bearing precondition, not weakened by it.
- Open: F2 begins on the first external lane PR (live gate run + friction signals); F3 verdict 2 quarters post-open (PAID vs WRITTEN-OFF per falsifiability criterion).

### 2026-06-10 | forge-harness | #wave-t, #temper, #steel-quench, #forge-fourth-movement, #v3
**File:** plugins/fh-meta/skills/steel-quench/SKILL.md (+ templates/temper_check.sh, docs/ETHOS.md, README.md)
Wave-T (Temper) ships — the fourth forge movement, poured from lab validation (operator-approved): after Wave 3+ convergence, measure the complexity the quench itself added (T-1 temper_check.sh delta, fence-excluding · T-2 harness-doctor absolute tier · T-3 τ-verdict, judged-paired with the quench's own findings). Validation: 9 runs across 4 independent convergences (0 false flags, simplification un-punished) + synthetic positive control (sensitivity) + same-commit dogfood run #10 on the pour itself (τ-PASS). ETHOS/README "direction ahead" IOU converted to delivery.
- Decision: organic τ-FAIL redefined from promotion-blocker to standing watch (operator-approved) — synthetic control covers sensitivity; first organic flag → human verdict → recorded.
- Decision: Wave-T stays one script + one section reusing harness-doctor (don't-overbuild guard is part of the shipped spec).
- Open: npm 1.4.8 ships Wave-T + temper_check.sh + selfcheck 21 (folded into the open laptop handoff).

### 2026-06-10 | forge-harness | #selfcheck, #count-consistency, #drift-class-kill
**File:** scripts/selfcheck.sh
Count-consistency probes (mandatory-pass): plugin.json ×2 / marketplace.json / README header / local_fh_context stated counts vs actual dirs (active = non-deprecated). Motivated by 4 same-day drift instances — the class now fails npm test + prepublishOnly instead of waiting for a doctor run.
- Decision: deprecation detected mechanically (frontmatter `deprecated: true` or DEPRECATED marker in head -20).

### 2026-06-10 | forge-harness | #backlog-cleanup, #phantom-fix, #count-drift, #goal-quench
**File:** plugins/fh-meta/skills/goal-quench/SKILL.md (+ templates/local_fh_context.md, plugin.json, README.md)
Backlog cleanup (cloud session 2): goal-quench phantom vocab fixed — "steel-quench C3 config" → "cross-provider challenger" (anchored to steel-quench:83 vocabulary + §Sidecar Engine Resolution Protocol; token `steel-quench-crossprovider`, 4 spots; resolves `fh_signal_2026-06-10_fh-direct`). Skill/agent count drift fixed: local_fh_context 26→29 active (−2 deprecated, +5 missing), plugin.json agents 3→7, README agents 5→8 (skills 33 verified correct = 36 dirs − 3 deprecated). Resolves the 06-04 "skill-count drift" Open item.
- Decision: counting policy is mechanical — active = non-deprecated skill dirs, agents = files in agents/; descriptive sidecar labels confirmed over C-numbering (per 06-10 check-class decision).
- Verified-no-action: 05-26 cross-ref recommendations already implemented — arXiv 2605.18747 (README:282 + definition doc:39) and Sylph 2604.21003 (definition doc:71/:105) — L4 open NOT raised.
- Open: npm 1.4.8 republish ships plugin.json/README/SKILL.md count+phantom fixes (folded into the open laptop handoff).

### 2026-06-10 | forge-harness | #credit-economy, #operator-intake, #lightweight-triage, #frontier-digest
**File:** plugins/fh-meta/skills/frontier-digest/SKILL.md (+ knowledge/shared/rules/sister_asset_protocol.md)
Credit-economy engine run #2 formalization (operator-approved; this session = manual run #2: 7 walled sources → 8 audits → 15 same-day gate-passed imports, 2 human corrections): R1 — frontier-digest Step 0.5 operator-intake asks for walled-channel sources (YouTube/LinkedIn/X, machine-403) on cadence runs only, skippable, try wall-bypass (WebSearch + secondary) first. R2 — sister protocol lightweight path: dedup-hit/no-increment sources get a one-paragraph entry, full cross-audits reserved for A/B-tier.
- Decision: the operator stays the wide-net sensor for walled channels by design (human = scarce oracle), the machine owns endurance (triage→gate cycles); intake cost discipline keeps the wide net wide.
- Follow-up (same day): Step 0.5 video-harvest ladder — Tier 1 sidecar (codex / Gemini-route, agentic = approval-mode first) → Tier 3 Claude+yt-dlp transcript → operator floor; laptop verification trio handed off. First applied instance of the capability-probe principle.

### 2026-06-10 | forge-harness | #comprehension-debt, #loop-engineering, #osmani, #harness-doctor
**File:** plugins/fh-meta/skills/harness-doctor/SKILL.md
Taxonomy 6→7: Comprehension Debt (runtime/operator-side, S) — loop output outpacing operator understanding, named from Osmani's Loop Engineering (canonical upstream of the supervisor-loops lineage; Cherny/Steinberger quotes — paper citation upgraded from the Korean video to this primary source, convergence count unchanged at n=5). Signals mechanical: merged change without CATALOG entry, manifest pending backlog, zero card delta. Countermeasures pre-existing (CATALOG summaries, predict-verify, card protocol).
- Decision: taxonomy now covers both loop sides — agent behavior (rows 4–6) and operator comprehension (row 7); FH's HITL PR principle recorded as a deliberate L2 cap on asset-changing loops (Osmani L3 rejected for asset mutation).

### 2026-06-10 | forge-harness | #failure-modes, #agentic-laziness, #self-preferential-bias, #goal-drift, #harness-doctor
**File:** plugins/fh-meta/skills/harness-doctor/SKILL.md
Harness-Defect Taxonomy 3→6 classes: runtime behavioral failure modes named from dynamic-workflows discourse (LinkedIn full-text triage) — Agentic Laziness (completion claims without per-item evidence, S), Self-Preferential Bias (judged check without adversarial pairing, M), Goal Drift (no pre-compaction completion log, S). FH already had the countermeasures (golden probes/coverage, judged-pairing rule, fh_completed + card-last guard) — the import is the *naming*, making diagnosis explicit.
- Decision: signals kept mechanically checkable (list/pairing/log presence) — no judge-only signal in the taxonomy itself; sources not counted as new convergence (discourse extension, anti-inflation).

### 2026-06-10 | forge-harness | #no-reinvention, #official-first, #claude-plugins-official, #full-harness-mode
**File:** knowledge/shared/plugin-catalog/recommended_plugins.md (+ CLAUDE.md, auto_project_mapping.md)
Operator-declared meta-harness 철칙 — no-reinvention / official-first: (a) plugin catalog gains Category 0.5, the claude-plugins-official 36-plugin inventory (12 LSP + workflow + authoring + setup groups; name-based, anti-stale "re-enumerate when recommending", role-split warnings for claude-md-management overlap); (b) New Skill gate Role-duplication criterion now also checks Tier 0 built-ins + official plugins — reinventing an official capability requires explicit justification; (c) Full-Harness Mode item 4: official-plugin scan for the mapped project's stack (recommend-only, never auto-install) — mapped-project acceleration with zero FH build.
- Decision: FH builds only what adds governance on top of official capabilities; drafting tools (skill-creator etc.) never exempt their output from the FH gate.

### 2026-06-10 | forge-harness | #tier-0, #builtins, #security-review, #deep-research, #role-split
**File:** plugins/fh-meta/skills/plugin-recommender/SKILL.md (+ frontier-digest, CLAUDE.md, probes.md)
CC built-ins utilization imports (operator-approved; video claims verified 9/13 real — agent initially ruled skill-creator nonexistent, operator-corrected: it is an official plugin in claude-plugins-official): Tier 0 = platform built-ins added to plugin-recommender (discovery order 0, "enumerate from live session" anti-stale, governance-add guard for FH-native precedence — goal-quench pattern named). /deep-research as frontier-digest Tier-0 engine. /security-review as Pre-Publish chain item 3 (code-security axis, skip-note path). Permission-Denial Option C, code-review role split, /loop WATCH row. G-TRIG-05 probe synced — anti-stale maintenance rule's first live use.
- Decision: built-in beats plugin install at ~80% coverage; FH native beats built-in only when it adds governance.

### 2026-06-10 | forge-harness | #ingest-gate, #contradiction-scan, #crossref-lint, #llm-wiki, #karpathy
**File:** knowledge/shared/rules/sync_push_protocols.md (+ harness-doctor SKILL.md, probes.md)
Karpathy LLM-Wiki sister-audit imports (operator-approved; convergence case n=5, citable primary source): I1 — contradiction scan as Sync step 3 (ingest gate, judged + verify-bidirectional pair): new knowledge grepped against existing claims before indexing, conflicts flagged in both files, old-claim removal is HITL. I2 — harness-doctor L4 knowledge cross-ref lint: no CATALOG entry = S-tier index orphan, no inbound ref = R-tier orphan page. Probes G-SYNC-01/G-LINT-01 added (30 total).
- Decision: scale escape (W1) deliberately NOT built — watch-item with trigger (CATALOG hundreds of entries / repeated search misses); operator-preferred first remedy = salience-splitter-style CATALOG split-mapping, RAG hybrid only after that.
- Open: npm republish (harness-doctor SKILL.md shipped) — folded into the open 1.4.8 handoff.

### 2026-06-10 | forge-harness | #golden-probes, #offline-eval, #doc-code-coupling, #anthropic-4layer
**File:** .claude/regression/probes.md (+ templates/.git-hooks/pre-commit, prompt-regression SKILL.md)
Anthropic 4-layer sister-audit imports (operator-approved): I1 — 28-probe known-answer golden set with check classes, the standing offline eval prompt-regression auto-loads (its P-GATE-01 had already gone stale 5→6 the same day the gate grew — fixed, plus an explicit anti-stale maintenance rule). I2 — pre-commit doc-code coupling WARN (measured class, never blocks) when executables are staged without any doc asset.
- Decision: probes.md canonical-when-present, SKILL.md default matrix = Mode C fallback (single-source preserved); coupling check warns rather than blocks — the decision is made conscious, doc-neutral script fixes stay friction-free.
- Open: npm republish (prompt-regression SKILL.md is shipped) — folded into the open 1.4.8 handoff.

### 2026-06-10 | forge-harness | #new-skill-gate, #check-class, #done-when, #g2
**File:** CLAUDE.md
G2 from the supervisor-loops audit: New Skill Creation Pre-Commit Gate extended 5→6 items — "Check-class declared": each Done When condition states its class (mandatory-pass / measured / judged per 6axis §Axis 5), and judged conditions must name their adversarial pairing (no judge-only path). The taxonomy now lives in the operating loop, not just the knowledge doc.
- Decision: applies to new skills only; existing 28 backfill opportunistically when next edited — no retroactive block.

### 2026-06-10 | forge-harness | #selfcheck, #mandatory-pass, #npm-test, #self-application
**File:** scripts/selfcheck.sh (+ package.json)
G1 fix from the supervisor-loops 100%+ audit: FH's own shipped code (bin/fh-*.js, scripts/fh-*.sh) had zero deterministic checks. New selfcheck.sh runs node --check + bash -n over the npm-shipped executable surface and the gate-chain bash infra (15 checks), wired as `npm test` and `prepublishOnly` — a publish can no longer ship a syntactically broken executable.
- Decision: syntax-only scope (zero side effects, runs anywhere); blocking wired at publish, not commit — doc commits stay unaffected.
- Open: npm republish to ship selfcheck.sh in the tarball (machine-bound, laptop).

### 2026-06-10 | forge-harness | #verify-axis, #check-classes, #supervisor-loops, #sister-asset
**File:** knowledge/shared/harness-core/harness_6axis_framework.md
Axis 5 check-class taxonomy added: every verify check classified as mandatory-pass (deterministic, blocking) / measured (quantitative, tracked) / judged (LLM-judge + cited evidence + corrective action — self-judges grade leniently). Judged rule: a judge verdict never passes alone — paired adversarial re-verification + evidence itself phantom-checked. Import from supervisor-loops sister-audit (operator-approved; cross-audit + proposal in companion store; corrective-action clause added after full-transcript delta check).
- Decision: descriptive labels over C1/C2/C3 numbering — avoids collision with unanchored "steel-quench C3 config" vocab (goal-quench:283, logged as fh_signal for separate fix).

### 2026-06-09 | forge-harness | #sidecar, #zero-config, #engine-resolution, #roadmap, #mode-c
**File:** knowledge/shared/harness-core/multi_model_sidecar_strategy.md (+ hybrid_orchestration_architecture_roadmap.md)
Added canonical §Sidecar Engine Resolution Protocol — Tier1 subscription-CLI → Tier2 API-key → Tier3 Claude-subagent guaranteed fallback. Principle: discovery automatic/free, invocation value-gated (intelligent default multi-AI, no hard-fail for Mode C). Wired pointers into goal-quench Step D / steel-quench runtime-adapter / harvest-loop Step 3.5-X; sim-conductor/pipeline-conductor/agent-composer inherit by reference. Source hybrid-orchestration design archived as proposed roadmap (versions→placeholders, Python pseudo-code→illustrative, non-shipped tagged Proposed). PR #80.
- Decision: single-source resolution protocol — skills cite it instead of re-inventing "if available" probes.
- Open: npm republish (machine-bound) — 3 npm-shipped SKILL.md changed; handed off to laptop via the companion store.

### 2026-06-09 | forge-harness | #onboarding, #greeting, #3-axis-scaffold, #returning-user
**File:** knowledge/shared/harness-core/fh_detail_protocols.md
Returning-user greeting (Step 2): single free-form e.g. line → fixed 3-axis entry scaffold (① connect new → auto_project_mapping · ② resume existing → filled live from CATALOG · ③ jump to work), plus a "keep axes fixed, compose contents per situation" note. PR #80.
- Decision: axis ② read live from CATALOG each session so the menu can't go stale — field-harness-style clarity without rigidity.

### 2026-06-05 | _audit | sister-asset, gstack, field-harness, garry-tan
**File:** tracks/_audit/session_2026_06_05_gstack-sister.md (private companion mirror)
gstack (garrytan, ~66K stars) sister-asset cross-audit — the field/execution-harness counterpart to FH's meta/governance harness, both running on the Claude Code skill substrate. FH governs / gstack executes (composes, not competes). Bidirectional import (frictionless one-command install, opinionated front door, privacy-first telemetry) / propagate (post-ship governance gate, cross-project knowledge compounding, HITL promotion gate) lists recorded.
- Decision: public index only — bet evidence (B1·ID·SB) + full audit held in private store; external cross-link proposal to garrytan/gstack gated behind 3+ persona × 4-axis audit.

### 2026-06-04 | forge-harness | #skill, #public-private-split, #leak-prevention, #composability-gate
**File:** plugins/fh-meta/skills/public-surface-audit/SKILL.md
New meta-skill: scans git-tracked files for operator-private tokens (real username, absolute home paths, companion-store name, company asset names) that belong only in gitignored files. Closes the surface-sweep gap from the Gap-1 public/private split. Dogfoods its own rule — patterns live in a gitignored source, SKILL.md carries only placeholders.
- Decision: tracked-only scan (git ls-files); configurable pattern table + tight allowlist; severity HIGH/MED/LOW.
- Open: skill-count drift across plugin.json / local_fh_context (separate cleanup).

### 2026-06-04 | forge-harness | #issue-69, #field-harvest, #mode-b, #detection-skip
**File:** plugins/fh-meta/skills/field-harvest/SKILL.md
Mode B extension (Proposal A): session-end auto-proposal for un-logged field-cwd commits (item1), detection-skip for already-logged commits (item2), templates/ hub-link footer (item6).
- Decision: auto-trigger is proposal-only (no auto-run); harvest-loop keeps hub-cwd wrap-up ownership (collision guard).
- Open: item2 bash detection-skip style pending sister-hub reply (inline-grep vs persisted-ledger).

### 2026-06-04 | forge-harness | #4-axis-gate, #pre-commit-hook, #docs-scope
**File:** templates/.git-hooks/pre-commit
4-axis gate scope extension: docs/*.md + AGENTS.md added to the substantive carve-out (Axes 2-3 when diff adds fence/citation/version). Also implemented the previously-documented-but-missing knowledge/ carve-out in the hook. Gate hook activated (core.hooksPath → templates/.git-hooks; was physically inactive).
- Decision: path-regex carve-out bucket + diff_is_substantive() helper.
- Open: none.

### 2026-06-03 | forge-harness | #goal-quench, #native-validation, #calibration, #stop-hook
**File:** tracks/_meta/goal_quench_2026-06-03.md
Run #1 native goal-quench validation (core mode): Stop hook `.active` → `.pending` confirmed working. pipeline-conductor --quick CLEAN (Step 3 ESCALATE resolved via option(a) inline fix).
- Decision: GREEN estimate missed pipeline-conductor overhead (~6K); timestamp field used literal "now" — fixed to `date +"%Y-%m-%d %H:%M"` going forward.

### 2026-06-03 | forge-harness | #context-bridge-dispatch, #done-when, #deprecated, #source-grounding
**File:** plugins/fh-meta/skills/context-bridge-dispatch/SKILL.md
Added Done When section (satisfies harness-doctor L2 M-tier for deprecated skill). Replaced informal "completeness gate" term with "L2 M-tier (CLAUDE.md §New Skill Creation Pre-Commit Gate)". All 22 fh-meta SKILL.md files now have Done When.
- Decision: deprecated skills still require Done When — `deprecated: true` is not an exemption from the pre-commit gate.

### 2026-06-03 | forge-harness | #goal-quench, #calibration, #run2, #catalog
**File:** CATALOG.md
Run #2 native goal-quench validation (core mode): added 3 CATALOG entries for today's session work. Established pipeline-conductor overhead correction (~6K) for GREEN-tier estimates.

### 2026-06-03 | forge-harness | #goal-quench, #install-wizard, #calibration-schema, #done-when, #skill-evolution
**File:** plugins/fh-meta/skills/goal-quench/SKILL.md, plugins/fh-meta/skills/install-wizard/SKILL.md
PR #67: Calibration schema extended with `run_id`, `session_id`, `scope_hint` fields (R10 schema gaps). Phase 1.5 hand-off clarified: "update not re-create" `.active` file to preserve `start_commit`. install-wizard: Done When section added (6-step gate + `--dry-run` variant) — only active skill of 28 missing it (R07 M-tier).
- Decision: schema fields added prospectively — backfilling retrospective N=10 rows with `mode`/`session_type` is a local companion-store task, not a SKILL.md change

### 2026-06-03 | forge-harness | #catalog, #goal-quench, #skill-evolution
**File:** CATALOG.md
PR #66: Added CATALOG entries for PRs #61–64 (goal-quench evolution arc): mode-ladder refactor, micro R-tier cleanup, non-coercive guidance formalization, scope-driven sidecar routing + 4.7× overhead calibration.
- Decision: tracks/** gitignored by design — calibration YAML records stay local; only CATALOG.md committed

### 2026-06-03 | forge-harness | #goal-quench, #sidecar-routing, #step-d, #deprecated-refs, #return-path
**File:** plugins/fh-meta/skills/goal-quench/SKILL.md, plugins/fh-meta/skills/install-wizard/SKILL.md, plugins/fh-meta/skills/frontier-digest/SKILL.md, plugins/fh-meta/skills/harvest-loop/SKILL.md
PR #65: Fixed Step D return-path bug (all 3 sidecar chains were fire-and-forget → added Step 3-c blocking verdict gate). Added `estimation_error_pct` field to calibration schema. Removed 4 deprecated routing refs: `context-bridge-dispatch` (install-wizard Cluster C + frontier-digest core skills list) and `/self-marketing-lint` (harvest-loop P10 → `/harness-doctor --lint`). ESCALATE added to Done When conditions.
- Decision: Step 3-c gate is blocking (not advisory) — sidecar verdict must resolve before Done When

### 2026-06-03 | forge-harness | #goal-quench, #sidecar-routing, #token-calibration, #steel-quench, #skill-evolution
**File:** plugins/fh-meta/skills/goal-quench/SKILL.md
PR #64: Added scope-driven sidecar routing (Step D) to goal-quench Phase 1.5: task-type signals auto-route to steel-quench C3 (code review), agent-composer panel (architecture), or sim-conductor+steel-quench Wave 5 (external publish). Formalized session overhead calibration at 4.7× factor (N=10), adding `session_type`, `actual_vs_estimate_ratio`, and `sidecar` fields to the calibration schema. Resolved steel-quench meta-audit S+A+B findings: sub-goal loop rewritten as user-driven queue, pre-flight check added, Opus escalation cost disclosed.
- Decision: overhead multiplier documented as empirical calibration constant; sidecar routing is scope-signal-driven, not mode-locked

### 2026-06-03 | forge-harness | #goal-quench, #non-coercive, #companion-store, #ephemeral-handoff
**File:** knowledge/shared/rules/modes_and_value.md
Formalized two non-coercive guidances: companion-store recommendation conditioned on accumulating context into meta-harness without a local fork; ephemeral-environment handoff rule made mode-agnostic (Mode D → companion-store handoff/, all others → committed note or PR comment in working repo).
- Decision: single-source preserved — rule lives in public mirror; companion store holds only outputs, never a rule copy

### 2026-06-03 | forge-harness | #goal-quench, #skill-evolution, #meta-audit, #prompt-regression
**File:** plugins/fh-meta/skills/goal-quench/SKILL.md
Post-merge micro R-tier cleanup: corrected two prompt-regression probe expectations mis-FAILing correct skills (P-CHAIN-01/02). Made LOCAL_SKILL_REGISTRY trigger in cross-ecosystem-synergy-detection honestly optional. Closes full-harness refactor backlog.
- Decision: leftover placeholder bash blocks and challenger wiring gap are verified non-defects

### 2026-06-03 | forge-harness | #goal-quench, #skill-evolution, #mode-ladder, #sidecar-routing
**File:** plugins/fh-meta/skills/goal-quench/SKILL.md
Evolved goal-quench into a fluid core→pro→max mode ladder. Core: token-budget-gate + pipeline-conductor --quick; pro: +context-doctor +agent-composer; max: +plugin-recommender +cross-ecosystem-synergy-detection. Phase-1 budget verdict auto-recommends mode. Ran full-harness dogfood sweep (33 skills): fixed phantom refs, dead blocks, stale agent forks (4 deleted), trigger collision, and 3 salience-splitter splits.
- Decision: RED tier reframed as max-mode decomposition on-ramp, not hard block

### 2026-06-02 | _audit | sister-asset, token-efficiency, compression, headroom
**File:** tracks/_audit/session_2026_06_02_headroom_context_doctor.md
Cross-audited Headroom (Netflix engineer's OSS token-compression tool, vendor-reported 60–95% reduction) against context-doctor's Compression Pass per sister_asset_protocol. Same goal, different layer: Headroom is the runtime executor FH lacks; context-doctor is the judgment Headroom lacks — they compose.
- Decision: import redundancy-category targeting heuristic (MCP outputs ~70% → logs ~90% → DB → file trees) into context-doctor + name Headroom as the production-proven local option; no clone-and-own (reference + record only)
- Open: actual proxy/agent-wrap routing is a local runtime setup (outside the FH repo); v0.22 maturity — pilot first

### 2026-06-02 | frontier-digest, identity, propagation | harness-engineering, a2a, mcp, observability, context
**File:** knowledge/shared/harness-core/harness_frontier_diagnosis_2026-06-02.md
Frontier digest anchored on FH's 3-layer identity + Core Axis (WebSearch engine; curl blocked, no API key). 2026-06 signal: "Harness Engineering" named 4th AI-engineering paradigm (65% of AI failures = harness defects); A2A Agent Cards + MCP registry standardize agent discovery; AHE thesis — observability is the self-improvement bottleneck.
- Decision: 6 strengthening candidates mapped per identity (agent-card registry + dispatch overhead budget → ①; harness-defect taxonomy + observability/eval hooks → ②; L1/L2/L3 context hierarchy + compression pass → ③)
- Open: candidates are proposals only — none implemented yet. Raw signal + processing checklist held in a private companion store, not this public repo.

### 2026-05-31 | multi-model, sidecar, adversarial, validated | orchestrator-swap, perspective-diversity, cross-cli
**File:** knowledge/shared/harness-core/multi_model_sidecar_strategy.md
외부 모델(Gemini/Codex/Copilot CLI)을 Claude Code/FH 세션 안에서 Bash tool로 sidecar 호출하는 검증된 패턴. Experiment 1(직접 sidecar 호출) + Experiment 2(3-round orchestrator-swap)로 실증 — 각 orchestrator가 비중복 findings 발견, cross-wave delta가 convergence를 개선. perspective diversity(1순위)·model-access fallback(2순위)·token economy(3순위). §Mechanism: agent dispatch 아닌 stateless 서브프로세스.
- Decision: 하네스가 multi-model synthesis의 activation condition — sidecar는 quality compounding 메커니즘이지 단순 coverage 체크 아님

### 2026-05-31 | anti-bias, multi-team, adversarial, token-coverage | steel-quench, sim-conductor, experiment, v2-paper
**File:** tracks/_meta/fh_multiteam_token_coverage_2026_05_31.md
Experiment 5 — Multi-Team Adversarial Panel measured on phantom-quench SKILL.md. 4 conditions (C1 single / C2 cross-session / C3 +gemini / C4 codex-TTY-fail=C3). Key results: C1→25% coverage, C2→75%, C3→100%. Claude blind spots: 3 findings (25% of total), 1 S-grade. Claude-side cost C2→C3: +0 tokens (H3 validated — Gemini billed to separate quota). Codex CLI present but headless-inoperable. Updated steel-quench/sim-conductor/phantom-quench/harness-doctor/harvest-loop with Multi-Team Panel design + human gates + synthesizer cross-session. v2 paper Experiment 5 section drafted with full metrics table.
- Decision: decision rule confirmed — routine→C2 (cross-session), pre-publish→C3+ (zero Claude overhead)
### 2026-05-31 | synergy, integration, playbook | opencode, hermes, openhuman, governance, marketing
**File:** knowledge/shared/harness-core/fh_synergy_playbook.md
Concrete workflow specifications for using FH with OpenCode/Hermes/OpenHuman — grounded only in recorded experiments. Three patterns: (1) OpenCode: fh-gate.sh after code gen → DONE→PENDING flip, 2 A-grade on arity.ts; (2) Hermes: skill audit before dispatch → 2 A-grade pre-exec/credential gaps; (3) OpenHuman: Memory Tree staleness audit → GROUNDED/STALE/BROKEN verdict. Includes honest finding-rate estimates, "no integration required" value prop, and compounding effect explanation.
- Decision: no unverified claims — every stated outcome traces to a specific experiment or structural guarantee

### 2026-05-31 | integration-contract, bridge-layer, governance-interface | opencode, hermes, openhuman, v2-paper
**File:** knowledge/shared/harness-core/fh_integration_contract.md
Formal v0.1 specification for how callers (OpenCode, Hermes, OpenHuman, CI) invoke FH governance gates and receive structured verdicts. Defines: input format (newline-separated files), FH_STATUS+verdict format, findings in YAML block, parse recipe. Includes caller-specific guidance + Stop hook pattern + record spec. Gemini adversarial review found 2 A-grade issues (space-separated paths, non-parseable multi-line fields) — both fixed in v0.1. Also includes `scripts/fh-gate.sh` prompt-generator wrapper.
- Decision: findings use YAML block (not flat key-value) to prevent delimiter ambiguity; FH_STATUS mandatory for fail-safe parsing

### 2026-05-31 | opencode, governance, usage-guide, synergy | pipeline-conductor, steel-quench, v2-paper
**File:** knowledge/shared/harness-core/fh_opencode_governance_wrapper.md
Step-by-step usage guide for FH + OpenCode governance integration. 3-step protocol (diff capture → steel-quench → pipeline-conductor). No API adapter required. Includes empirical baseline from arity.ts trial: CI=DONE, FH governance=PENDING, 2 A-grade security-adjacent findings caught. Stop hook automation pattern included.
- Decision: governance wrapper documented as protocol (not API) — FH reads files OpenCode writes

### 2026-05-31 | v2-paper, opencode, governance, controlled-experiment | steel-quench, pipeline-conductor, synergy
**File:** tracks/_meta/fh_opencode_governance_experiment_2026_05_31.md
FH governance (steel-quench + pipeline-conductor --quick) applied to OpenCode's AI-generated `arity.ts`. Baseline: CI green, DONE. FH governance: PENDING — 2 A-grade findings (short-token overflow in permission allowlist, npx/opencode missing from arity table) + 1 B-grade. Delta not attributable to model — attributable to methodology layer. v2 paper prototype: controlled experiment evidence for N-fold synergy claim.
- Decision: governance layer catches issues CI misses; arity.ts short-token overflow is permission-critical and untested

### 2026-05-30 | fh-meta | edit-manifest, predict-verify, validation-gate, skill-evolution, SkillOpt, AHE
**File:** plugins/fh-meta/skills/edit-manifest/SKILL.md
New skill: predict-verify loop for harness edits. Every SKILL.md/rules/CLAUDE.md edit records a falsifiable prediction; next session verifies against actual outcomes. Validation gate (SkillOpt pattern) accepts only edits with measurable improvement; rejected edits retained as negative-feedback buffer. Integrated as harvest-loop Step 0-c.
- Decision: based on AHE (arXiv:2604.25850) change manifest + SkillOpt (arXiv:2605.23904) selection-split gate

### 2026-05-30 | fh-meta | memory-hygiene, stale-memory, staleness-detection, verification
**File:** plugins/fh-meta/skills/memory-hygiene/SKILL.md
New skill: detects "stale-but-confident" memory entries (facts verified once but silently drifted). Classifies by type (project 14d / reference 30d / feedback 90d / user 180d), re-verifies live via gh CLI or WebFetch (FH online advantage), proposes archival. Integrated as harvest-loop Step 0-c.
- Decision: based on Scaling the Harness (arXiv:2605.26112) §3.2 stale-but-confident failure mode

### 2026-05-29 | harness-core | return-path-gate, skill-chain, conditional-pass, closed-loop
**File:** knowledge/shared/harness-core/return_path_gate.md
Pattern: downstream skill returns structured verdict (PASS/CONDITIONAL_PASS/FAIL/ESCALATE) back to caller, which gates next step on it. Verified in apex-review→sim-conductor and agent-composer↔deliberation.
- Decision: promoted to knowledge/shared/ — same pattern appeared independently in 2 skill pairs

### 2026-05-29 | harness-core | meta-harness-engineering, definition, frontier, academic-convergence
**File:** knowledge/shared/harness-core/meta_harness_engineering_definition.md
Formal definition of meta harness engineering + FH positioning vs. academic convergence (arXiv 2605.18747 "Code as Agent Harness", arXiv 2604.14228 98.4% finding). Maps FH 6-axis to 3-layer taxonomy; distinguishes human-in-loop (FH) vs automation-first vs automation-maximalist approaches.
- Decision: FH differentiator = human judgment gate on all PRs, not automation maximization

### 2026-05-29 | fh-commons | token-budget-gate, token-estimation, cost-guard, multi-agent
**File:** plugins/fh-commons/skills/token-budget-gate/SKILL.md
New skill: pre-task token cost estimation with Green/Yellow/Orange/Red gate verdict. Post-task calibration loop improves future estimates. Auto-proposed before agent-composer, sim-conductor, steel-quench, harvest-loop.
- Decision: placed in fh-commons (project-agnostic, useful before any expensive multi-agent task)
- Thresholds: <10K green / 10-30K yellow / 30-60K orange / >60K red (user-configurable)

### 2026-05-29 | fh-commons | mcp-circuit-breaker, mcp-reliability, tool-failure, fallback
**File:** plugins/fh-commons/skills/mcp-circuit-breaker/SKILL.md
New skill: detects MCP tool failure patterns (3 consecutive fails = trip), blocks further calls, proposes 3-tier fallbacks, and resets via HALF-OPEN probe after cooldown.
- Decision: placed in fh-commons (project-agnostic MCP guard, useful in any Claude Code project)
- Circuit states: CLOSED → OPEN → HALF-OPEN → CLOSED

### 2026-05-29 | fh-meta | prompt-regression, regression-detection, harness-quality
**File:** plugins/fh-meta/skills/prompt-regression/SKILL.md
New skill: detects harness behavioral regressions after CLAUDE.md / rule / skill edits by running standard probe suite and comparing against baselines.
- Decision: placed in fh-meta (harness-specific behavioral testing, not general-purpose)
- Chain: FAIL verdict → harness-doctor → verify-bidirectional

### 2026-05-28 | _meta | install-wizard, plugin-autoinstall, deprecated-cleanup, fh-ops, external-validation
**File:** tracks/_meta/session_2026_05_28_fh-external-ops.md
First external run of FH — install-wizard (score 57/100) revealed 2 friction points, both fixed immediately. PR #7 (plugin auto-install) + PR #8 (deprecated refs cleanup) merged.
- Decision: install-wizard FH plugin MISS → AI auto-runs via Bash (eliminates 3-turn manual flow) — "friction only visible when the builder actually uses it" pattern
- Decision: deprecated refs must be updated alongside CHANGELOG — separate cleanup PR required

### 2026-05-27 | _meta | two-layer-storage, memory-vs-tracks, cross-session-state
**File:** tracks/_meta/fh_signal_2026_05_27_session-starter.md
Two-layer storage principle formalized: `tracks/` = local work history (machine-bound), `memory/` = critical cross-session state (durable, survives re-clone). Gap: session starter files in tracks/ are lost on machine change.
- Decision: Critical cross-session state must also be written to `~/.claude/projects/.../memory/` — tracks/ alone is insufficient for durability

### 2026-05-26 | _audit | sister-asset, harness-evolver, meta-harness, stanford, arxiv
**File:** tracks/_audit/session_2026_05_26_harness_evolver.md
Sister asset cross-audit — harness-evolver (raphaelchristi) + Meta-Harness (Lee et al., arXiv:2603.28052, Stanford IRIS Lab). Independent architectural convergence confirmed: outer-loop field observation → adversarial critique → synthesis → integration → verification. Cross-reference links proposed; Issue #26 filed.
- Decision: harness-evolver = direct complement (automation-first) vs FH (knowledge-accumulation-first) — mutual citation proposed

### 2026-05-26 | _audit | sister-asset, sylph-ai, arxiv, simplification-principle
**File:** tracks/_audit/session_2026_05_26_sylph_sister.md
Sister asset cross-audit — "The Last Harness You'll Ever Build" (Sylph.AI, arXiv:2604.21003). Title resonates with FH simplification principle but approach diverges: Sylph = fully automated adversarial agent loops, FH = human-in-the-loop curated knowledge evolution.
- Decision: Sylph.AI = automation-maximalist counterpart; FH distinction is human judgment layer

### 2026-05-26 | _meta | external-network, wave3-validation, sase, install-wizard, frontier-digest
**File:** tracks/_meta/external_network_verification_2026_05_26.md
Wave 3 meta-validation: confirmed all previously restricted-network-blocked capabilities work on a standard network — install-wizard dry-run, plugin-recommender live GitHub search, frontier-digest fetch, git push. Baseline for external user environment parity.
- Decision: All core FH capabilities verified functional on a standard (unrestricted) network

### 2026-05-26 | forge-harness | v1.2, public-release, harness-evolver-absorb
**File:** tracks/_meta/reference_next_session_starter.md
v1.2 release complete (PR #1–#5): harvest-loop Step 0, agent-composer worktree isolation, steel-quench numeric scoring, README positioning. Repo made public.
- Decision: harness-evolver 3대 혁신 흡수 — regression guard / worktree isolation / numeric scoring

---

## Reference Documents

<!-- Time-independent reference documents -->

### 2026-07-17 | fh-meta | fh, hub-map, slash-command, discoverability, router-demotion-phase-a
**File:** `plugins/fh-meta/skills/fh/SKILL.md`
New skill: /fh renders the hub map (door menu + starter set + top phrases) on demand without a greeting — discoverability for task-first sessions. Renders from canonical sources (CLAUDE.md skeleton, starter_profile, CHEATSHEET), never forks a copy. Router-demotion Phase A alongside the trigger-table row diet (Step 0.5 probe 13/18 → 13 frontmatter-covered rows removed).

### 2026-07-17 | pattern | multi-harness-evolution-loop, usability-axis, devolution-check, operator-forged
**File:** `knowledge/shared/harness-core/multi_harness_evolution_loop.md`
Operator-forged 5-phase loop (structure audit → persona usability → fix → devolution check until CONVERGED → settle) composing existing FH checks across a harness cluster. Doctrine: usability ("does speech reach") is a first-class diagnostic axis; improvement without a devolution check is half a loop. n=1 evidence 2026-07-17; skill-ification gated on n≥2.

### 2026-07-17 | detail-layer | claude-md-gates, on-demand-detail, salience-split (backfill)
**File:** `knowledge/shared/harness-core/claude_md_gate_details.md`
On-demand detail home for CLAUDE.md gate sections (4-axis marker irreducibility, sim-dispatch fallback, floor-tier canary, cross-family complement, Mode D notice, pre-publish/destructive-op hook coverage, session-close steps) — read when executing or auditing the pointed gate.

### 2026-07-17 | gate | field-verdict, cross-family, degrade-direction, load-bearing (backfill)
**File:** `knowledge/shared/harness-core/field_verdict_crossfamily_gate.md`
Canonical detail of the Field-Harness Load-Bearing Change Gate — discretion principle, four-faces failure signature, gate mechanics, n=7 qasp evidence (9 default-toward-PASS holes across 3 harnesses), under-trigger residuals, autonomous-loop baking.

### 2026-07-17 | detail-layer | field-diagnostic, compose-rank-hitl, six-lenses
**File:** `knowledge/shared/harness-core/field_harness_diagnostic.md`
Detail home for the Field-Harness Diagnostic (CLAUDE.md summary section) — full six-lens composition table incl. loop-readiness mechanics + adversarial pairing, 2026-07-08 dogfood examples, guard rationale.

### 2026-07-17 | detail-layer | onboarding-autopilot, phase0-audit, simulate-first, install-hitl
**File:** `knowledge/shared/harness-core/onboarding_acceleration_autopilot.md`
Detail home for the Onboarding / Acceleration Autopilot (CLAUDE.md summary section) — full Phase-0 branch logic incl. chamber/simulate-first honesty boundary, revfactory provenance, guard evidence (chamber run #7).

### 2026-06-20 | principle | gate-locality, multi-runtime, judge-robustness (backfill 2026-07-17)
**File:** `knowledge/shared/harness-core/gate_locality_principle.md`
Gate-locality principle — a safety gate must live where the enforcing actor actually reads it; a gate defined where the actor never loads is decorative, not enforced. Origin of the AGENTS.md vs CLAUDE.md inheritance-gap fix (PR#111).

### 2026-07-17 | rule | operational-adaptation, uap, user-tuning, generalization-gate (backfill)
**File:** `knowledge/shared/rules/operational_adaptation.md`
Standing per-user operational loop — User Adaptation Profile (UAP) mechanics, proposal outcome tracking, suppression/muting rules, and the generalization gate routing idiosyncratic vs generalizable learnings.

### 2026-07-17 | dialogue | memory-recall, intent-based, associative, wiki-links (backfill)
**File:** `knowledge/shared/dialogue/memory_intent_recall.md`
Intent-based + associative memory recall — keyword → intent + 1-hop [[link]] graph traversal over memory files, index-first to avoid graph-walk explosion.

### 2026-07-17 | schema | persona-container, sim-conductor, dispatch-binding (backfill)
**File:** `knowledge/shared/harness-core/persona_container_schema.md`
Canonical schema for synthesizing a simulation persona from a reusable container — slots, crowd-scale stop rule, multi-LLM tier distribution, situation→group→skill dispatch binding, and the synthesize→validate→graduate lifecycle. sim-conductor and any persona-dispatch skill fill these slots.

### 2026-07-17 | consent | capability-escalation, dispatch-not-substrate, hitl (backfill)
**File:** `knowledge/shared/harness-core/capability_escalation_consent.md`
Consent protocol governing when a session may escalate capability — escalation = dispatch (consent-gated), never substrate switch; pairs with sonnet_floor_doctrine.

### 2026-06-11 | cross-audit | companion-store, pluggable, gbrain, obsidian (backfill 2026-07-17)
**File:** `knowledge/shared/harness-core/companion_store_pluggable_cross_audit_2026-06-11.md`
Sister-asset cross-audit treating FH's companion store, gbrain, and Obsidian as interchangeable backends for one role — durable private knowledge persistence — and the rationale for making the companion store pluggable.

### 2026-06-14 | pattern | live-surface, observe-act-verify, appium-less, hybrid-webview (backfill 2026-07-17)
**File:** `knowledge/shared/harness-core/live_surface_automation_pattern.md`
Live-surface automation pattern — the capability pattern FH routes to when a mapping project needs an agent to drive a live UI surface: the cross-platform observe-act-verify contract, the Appium-less principle, and the hybrid-WebView vision-synthesis rule. FH routes drivers (no-reinvention).

### 2026-07-17 | pattern | ensemble-union, detection-task, voting-vs-union (backfill)
**File:** `knowledge/patterns/ensemble_union_detection_task_pattern.md`
Ensemble union pattern for detection tasks — detection ensembles combine by UNION (recall gain), generation ensembles by VOTING; field-measured on a fixed open-weight 3-model panel.

### 2026-06-06 | pattern | parallax, multi-persona-review, synthesizer, standpoint-coverage
**File:** `knowledge/shared/patterns/multi-persona-review.md`
Generalized architecture for multi-persona parallel artifact review ("parallax") — parallel isolated personas + shared output protocol + neutral synthesizer. Domain-agnostic, IP-stripped; embodied as sim-conductor Step 1.5.

### 2026-05-31 | reference | ecosystem-positioning, opencode, hermes, openhuman, readiness
**File:** `knowledge/shared/harness-core/fh_ecosystem_positioning.md`
FH's structural position in the AI agent framework ecosystem vs Hermes/OpenCode/OpenHuman — gap analysis, synergy map, layered readiness verdict from 3-model adversarial audit. Companion: `fh_synergy_playbook.md` (concrete workflow specs).

### 2026-06-04 | schema | tpa, target-profile-analysis, routing, sim-conductor, steel-quench
**File:** `knowledge/shared/harness-core/tpa_schema.md`
Canonical Target Profile Analysis schema — all TPA-running skills (sim-conductor, steel-quench, phantom-quench, agent-composer) derive routing decisions from this schema. Single source for profile fields.

### 2026-06-04 | draft | goal-quench, anthropic-issue, native-goal, token-budget
**File:** `knowledge/shared/harness-core/goal_quench_anthropic_issue.md`
Draft Anthropic GitHub issue — native /goal token budget + quality verification hook proposal. Held until arXiv number confirmation.

### 2026-05-26 | measurement | skill-quality-rubric, maturity-score, verifiable-numbers
**File:** `knowledge/shared/harness-core/skill_quality_rubric.md`
Skill maturity score formula definition. Declaring verifiable/evolution numbers without this file violates the cold-audit "self-declaration = delete if no basis" rule.

### 2026-06-04 | core-reference | compounding-loop, weekly-cycle, axis-6, automation
**File:** `knowledge/shared/harness-core/hub_compounding_loop.md`
Core reference doc (CLAUDE.md Consult-First table): weekly/monthly/quarterly feedback cycles + Axis-6 Compounding automation roadmap.

### 2026-06-04 | core-reference | runtime-flow, session-chronology, subagent-delegation
**File:** `knowledge/shared/dialogue/claude_code_runtime_flow.md`
Core reference doc (CLAUDE.md Consult-First table): chronological flow of a Claude Code session (does) + sub-agent delegation flowchart.

### 2026-06-04 | core-reference | dialogue-playbook, token-efficiency, rule-hierarchy
**File:** `knowledge/shared/dialogue/ai_dialogue_playbook.md`
Core reference doc (CLAUDE.md Consult-First table): session-start principles, token efficiency, rule hierarchy, amplifier/coach dual mode (should).

### 2026-06-04 | glossary | terminology, meta-harness, launch-pad, transit-acceleration
**File:** `knowledge/shared/GLOSSARY.md`
Key term definitions — meta-harness, meta hub, launch pad effect, transit acceleration value, shared skill pool, operating modes. Entry point for FH-internal vocabulary; linked from CHEATSHEET.

### 2026-04-28 | template | maturity-roadmap, 3-phase-frame, frontier-tracking, simplification-gate
**File:** `knowledge/shared/harness-core/hub_maturity_roadmap.md`
Hub long-term evolution path frame. Phase I (entering maturity) → Phase II (frontier following (b)cadence) → Phase III (leading) 3-stage model + 5-criteria gate (audit automation·operations guide·external propagation·sub-agent judgment·self-diagnosis warning) + 6 indicators (seed repo·blog·citations·external adoption·self-evolving·industry original) + simplification gate (self-diagnosis + within 200 lines + unreferenced archive at each transition). General-purpose template derived from first verified operating instance.
- Decision: (b) quarterly + monthly cadence recommended — if adopting other option, need to prove simplification gate passed
- Decision: Phase III has no completion (ongoing state) — 3+ of 6 indicators continuously rising is the maintenance condition
- Decision: Phase regression allowed — do not force linear progression (allow partial Phase I redo if frontier following routine is missed)

---

## Plugins

### 2026-05-08 | fh-meta v0.5.0 | six-skills-operation, path-b-generalization, command-tower-gate, mode-c-user, beta-release
**File:** plugins/fh-meta/.claude-plugin/plugin.json + .claude-plugin/marketplace.json
Hub meta operations tool bundle — 6 skills operation. harvest-loop path B generalization + verify-bidirectional path B generalization + frontier-digest path B generalization + cross-ecosystem-synergy-detection + plugin-recommender + **hub-cc-pr-reviewer** command tower gate operations rule automation (new). 2 agents (hub-persona-auditor + fact-checker). Beta operation — harness core principle *"beta + public release = practical capability obligation"* followed.
- Decision: hub-cc-pr-reviewer skill newly created — command tower gate operations rule automation + PR lifecycle 4-run accumulated + explicit decision trigger
- Decision: plugin level v0.4.3 → v0.5.0 promoted — 6 skills operation baseline + path B generalization baseline followed
- Decision: 3 skills path B generalization — harvest-loop + verify-bidirectional + frontier-digest / external user environment adaptation path enhanced
- Note: audit-learnings deprecated from plugin (2026-05-xx) → transferred to hub-internal deprecated/; replaced by harvest-loop
- Note: frontier-status-summary deprecated (2026-05-xx) → replaced by frontier-digest

---

## Skills

### 2026-05-08 | fh-meta | harvest-loop, weekly-audit, self-evolution-pipeline, session-harvest, phase-2-plus
**File:** plugins/fh-meta/skills/harvest-loop/SKILL.md
Self-evolution pipeline — field-harvest → contention-layer → devil/innovator parallel → synthesizer → Critic Agent → harness-doctor → verify-bidirectional → curator (8 steps). Lightweight mode for weekly audit. Replaces deprecated audit-learnings.
- Decision: harvest-loop = audit-learnings successor + full self-evolution pipeline integrated

### 2026-05-08 | fh-meta | verify-bidirectional, layer-5-cross-verification, conscious-self-activation, diff-gate
**File:** plugins/fh-meta/skills/verify-bidirectional/SKILL.md
Bidirectional self-verification pattern automation — when user's precision counter-argument manifests after AI recommendation/agreement persistence, baseline update channel 6-step processing.
- Decision: v0.5 official release — accumulated runs + mode C correction catch fully persisted

### 2026-05-08 | fh-meta | hub-cc-pr-reviewer, command-tower-gate-automation, baseline-coherence-check, layer-5-self-catch
**File:** plugins/fh-meta/skills/hub-cc-pr-reviewer/SKILL.md
Command Tower Gate operations rule automation — on PR input, auto-generates baseline coherence check 8-matrix + Layer 5 self-catch matrix + review comment attachment + admin override merge recommendation.
- Decision: v0.1 newly created — PR lifecycle 4-run accumulated + explicit decision trigger met

### 2026-05-20 | fh-meta | context-bridge-dispatch, agent-view-context-blindness, parallel-dispatch, session-context-card
**File:** plugins/fh-meta/skills/context-bridge-dispatch/SKILL.md
Parallel agent dispatch pre-session context card injection pattern automation — sub-agents read files but cannot access main session living context. Context Card (purpose·completed·this agent's task·caution) generation and injection into each prompt before 2+ parallel dispatches. Simple file lookup agents can omit.
- Decision: v0.1 newly created — agent view blindspot captured in the field → FH skill decision

---

## Agents

### 2026-05-08 | fh-meta | hub-persona-auditor, persona-simulation, three-tier-revision, external-asset-pre-publication
**File:** plugins/fh-meta/agents/hub-persona-auditor.md
External-facing asset (briefing·card·public guide) pre-publication persona audit — 3+ virtual reader persona simulation + 4-axis (resonance·confusion·resistance·supplement) review + 3-tier (mandatory·strong·recommended) revision proposals.
- Decision: fh-meta agent separate operation (not a skill / external-facing cadence activation)

### 2026-05-08 | fh-meta | fact-checker, hub-asset-grep-verification, duplicate-detection, stale-fact-detection
**File:** plugins/fh-meta/agents/fact-checker.md
Hub asset grep verification — (1) hub asset duplicate check before recommending new asset/skill/agent (2) stale data detection in memory/docs (3) when duplicate work is suspected.
- Decision: hub self-review circuit baseline established

---

## Learnings

<!-- Accumulated feedback/lessons -->
