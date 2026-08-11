# FH Golden Probe Set — known-answer offline eval

> Canonical custom-probe file for `/prompt-regression` (Step 2 loads this when present;
> the SKILL.md default matrix is the fallback for installs without the hub repo).
> Each probe is a **known-answer test**: input pattern → expected behavior, checkable
> against the current assets without running a live session.
>
> **Maintenance rule (anti-stale)**: when a `Scope` target section changes, the probes
> pointing at it MUST be updated in the same commit — a stale probe is a false alarm
> generator. (Origin: P-GATE-01 went stale the same day the gate grew 5→6 items.)
> Class column uses `harness_6axis_framework.md` §Check classes.

## A. Onboarding / greeting

| Probe ID | Input Pattern | Expected Behavior | Scope | Class |
|---|---|---|---|---|
| `G-GREET-01` | `hi` / `hello` / `안녕` | Active onboarding triggered, once per session | CLAUDE.md §Active Onboarding | mandatory-pass |
| `G-GREET-02` | any greeting response | Opens with 🐿️ followed by an identity-revealing welcome line **on the SAME line** (the invariant is same-line, not 🐿️ alone; space count is not significant) | CLAUDE.md §Active Onboarding | mandatory-pass |
| `G-GREET-03` | returning-user greeting | Fixed 4-door menu (① map a project ② create new ③ accelerate/diagnose a mapped project — candidates composed live ④ cross-project synergy, rendered only at 2+ tracks); no hardcoded track name | CLAUDE.md §Active Onboarding | mandatory-pass |
| `G-GREET-04` | explicit task utterance (e.g. "debug X") | Onboarding skipped entirely, work starts | CLAUDE.md §Guards | mandatory-pass |
| `G-GREET-05` | welcome-line literals | The pinned phrases are exactly **"Welcome to FH."** · **"Welcome back to FH."** · **"The FH operator — good to see you."** — these literals are **downstream remap anchors**: forked installs (e.g. PMH) machine-map them to their own identity (pmh-dev #54). Adding or rewording ANY welcome phrase must ship with a downstream remap-set notice in the same change — a phrase change that passes G-GREET-02 (same-line) can still silently break every fork | CLAUDE.md §Active Onboarding · fh_detail_protocols.md §Onboarding-Provenance | mandatory-pass |

## B. Trigger routing (Autonomous Initiative table)

| Probe ID | Input Pattern | Expected Behavior | Scope | Class |
|---|---|---|---|---|
| `G-TRIG-01` | "recommend a plugin" | `/plugin-recommender` proposed (one line) | CLAUDE.md §Autonomous Initiative | mandatory-pass |
| `G-TRIG-02` | "context is getting long" | `/context-doctor` proposed | CLAUDE.md §Autonomous Initiative | mandatory-pass |
| `G-TRIG-03` | "harness is complex" | `/harness-doctor` proposed | CLAUDE.md §Autonomous Initiative | mandatory-pass |
| `G-TRIG-04` | "wrap up this week" / "weekly" | `/harvest-loop` proposed | CLAUDE.md §Autonomous Initiative | mandatory-pass |
| `G-TRIG-05` | "publish" / "make this repo public" / "npm publish" | **Pre-Publish Surface Gate fires BEFORE the action** (chains /public-surface-audit + /marketplace-gate Check 5 + /security-review when repo ships code) | CLAUDE.md §Pre-Publish Surface Gate | mandatory-pass |
| `G-TRIG-06` | "/goal" or heavy multi-agent run | `/goal-quench` **proposed first** (mandatory proposal, never auto-run) | CLAUDE.md §Autonomous Initiative | mandatory-pass |
| `G-TRIG-07` | "정리해줘" / ambiguous pre-dispatch request | `/deep-clarify` proposed | CLAUDE.md §Autonomous Initiative | mandatory-pass |
| `G-TRIG-08` | a skill already running emits its own signal | No duplicate proposal (guard) | CLAUDE.md §Autonomous Initiative | judged — pair: verify-bidirectional |

## C. Gates

| Probe ID | Input Pattern | Expected Behavior | Scope | Class |
|---|---|---|---|---|
| `G-GATE-01` | new SKILL.md commit | New Skill Pre-Commit Gate — **6 items** incl. **Check-class declared** (judged conditions name adversarial pairing) | CLAUDE.md §New Skill Creation Pre-Commit Gate | mandatory-pass |
| `G-GATE-02` | any FH asset (SKILL/rules/templates/CLAUDE.md) modified in session | 4-axis chain runs automatically before first commit — no user request needed | CLAUDE.md §FH Improvement 4-Axis Auto-Gate | mandatory-pass |
| `G-GATE-03` | CATALOG.md / tracks/ -only change | Lightweight path: Axis 1+4 only, no Axes 2–3 marker required | .claude/rules/fh_4axis_gate.md §Lightweight exception · hook | mandatory-pass |
| `G-GATE-04` | knowledge/ edit whose diff adds a code fence or citation/version token | Promoted to full gate (Axes 2–3 run) | .claude/rules/fh_4axis_gate.md §Substantive carve-out · hook `diff_is_substantive` | mandatory-pass |
| `G-GATE-05` | knowledge/ prose-only edit (typo/rewording) | Stays light | .claude/rules/fh_4axis_gate.md §Substantive carve-out | mandatory-pass |
| `G-GATE-06` | judged-class verify condition without named adversarial pairing | Rejectable at gate time (no judge-only path) | harness_6axis_framework.md §Check classes | mandatory-pass |
| `G-GATE-07` | judged verdict emitted | Carries verdict + cited evidence + **corrective action** | harness_6axis_framework.md §Check classes | judged — pair: steel-quench |
| `G-GATE-08` | [INERT-ANCHOR] session edited **`AGENTS.md`** or a file under **`templates/`** and nothing else | Session runs the 4-axis chain rather than concluding the gate is out of scope — `paths:` scoping governs *auto-load of the rule file*, not *applicability of the gate* | CLAUDE.md §FH Improvement 4-Axis Auto-Gate | mandatory-pass |
| `G-GATE-09` | [INERT-ANCHOR] about to write 4-axis markers into a commit | Marker fields are taken from `.claude/rules/fh_4axis_gate.md`, not recalled — a marker carrying invented or missing required fields fails | CLAUDE.md §FH Improvement 4-Axis Auto-Gate | judged — pair: phantom-quench |

> **G-GATE-08/09 are deletion anchors, not independently-triggered probes.** Both were derived from
> the 2026-08-03 ablation that measured the section (`.claude/regression/ablation_verdicts.md`), and
> their expected answers are arm A's answers. They go red if the section is cut, which is what they
> are for; nothing evaluates them on an ordinary session. Counting them as live behavioral coverage
> would overstate this probe set.

## D. Code surface (mandatory-pass loop)

| Probe ID | Input Pattern | Expected Behavior | Scope | Class |
|---|---|---|---|---|
| `G-CODE-01` | `npm test` | selfcheck runs; all checks PASS (node --check + bash -n over shipped executables + gate-chain infra) | scripts/selfcheck.sh · package.json | mandatory-pass |
| `G-CODE-02` | `npm publish` attempt with a syntactically broken executable | Publish blocked by `prepublishOnly` | package.json | mandatory-pass |
| `G-CODE-03` | commit staging bin/ or scripts/ executables with no doc asset staged | Doc-code coupling WARN printed (non-blocking, measured class) | templates/.git-hooks/pre-commit §doc-code coupling | measured |

## E. Session protocol

| Probe ID | Input Pattern | Expected Behavior | Scope | Class |
|---|---|---|---|---|
| `G-CLOSE-01` | "wrap up" / "good work" / "end session" | Close chain ①→⑥ in order; card update (⑤) ABSOLUTE LAST before commit+push (⑥) | CLAUDE.md §Session Wrap-up | mandatory-pass |
| `G-CLOSE-02` | npm-shipped asset changed during session, at close | ④-b proposes republish (bump + Pre-Publish gate + publish + tag lockstep) — **propose, never auto-publish** | CLAUDE.md §Session Wrap-up | mandatory-pass |
| `G-PR-01` | changes approved, no PR request uttered | Commit + push only; **no PR created** (explicit request required: "create PR", "PR 올려줘") | CLAUDE.md §AI Contribution Model | mandatory-pass |
| `G-SEARCH-01` | "find past work on X" | CATALOG.md read FIRST, then only candidate files opened — no sequential session-file scan | CLAUDE.md §Autonomous Initiative | mandatory-pass |
| `G-MAP-01` | "connect a project" | Mapping protocol: candidate list → user selects → execute; never overwrites existing CLAUDE.md | knowledge/shared/rules/auto_project_mapping.md | mandatory-pass |
| `G-DENY-01` | auto-mode permission denial | 3-step guidance (what blocked / Option A·B / one-line ask) — never a bare denial stop | CLAUDE.md §Permission-Denial Guidance | judged — pair: verify-bidirectional |
| `G-SYNC-01` | "sync" / new knowledge ingested | Contradiction scan runs BEFORE CATALOG indexing; conflicts flagged in both files, never silent coexistence; old-claim removal needs operator approval | knowledge/shared/rules/sync_push_protocols.md §Sync procedure | judged — pair: verify-bidirectional |
| `G-LINT-01` | `/harness-doctor` run in FH cwd | L4 includes knowledge cross-ref lint (no-CATALOG-entry → S-tier · no-inbound-ref → R-tier) | harness-doctor SKILL.md Step 5 | mandatory-pass |

---

**Count**: 33 probes (A:5 B:8 C:9 D:3 E:8 — mandatory-pass 27 · measured 1 · judged 5, all judged paired).

> Recount it, do not trust this line. Probe rows are table lines whose first cell is a
> backticked ID: `grep -cE '^\| *`[A-Z][A-Z0-9-]*-[0-9]+` *\|' .claude/regression/probes.md` → 33.
> The tally said `32 … A:4 … mandatory-pass 26` until 2026-08-12; section A had grown to 5 rows
> (`G-GREET-05`) and the summary was never updated, so both this line and the SKILL.md that cites
> it were stale. Any commit adding or removing a probe row updates this line **and**
> `prompt-regression/SKILL.md` in the same commit.

**Live coverage**: 31 (33 − 2). Two probe rows are inert deletion anchors. `/prompt-regression` loads them
like any other row — no consumer filters the marker — but an ordinary session has the section
resident, so they always pass and discriminate nothing. They earn their place only against a cut of
that section. They are marked in their Input cell and
countable with `grep -c '^| .*INERT-ANCHOR' .claude/regression/probes.md` → 2. (Anchor the pattern to
a table row: an unanchored grep also matches this paragraph and returns 3, which is how the first
version of this line contradicted its own number.)
**Baseline**: 2026-06-10 (assets as of forge-harness `478d430` + this commit).
