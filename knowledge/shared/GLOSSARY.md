# GLOSSARY — forge-harness Key Term Definitions

> One-line definitions of FH-specific vocabulary appearing in skills, agents, and documentation.
> Reference point for new user onboarding. Keep in sync with the README key terms table.

---

## Hub Structure

| Term | Definition |
|---|---|
| **Meta-Harness** | A persistent hub in a Claude Code environment that connects the work, learnings, and patterns of N projects for mutual reinforcement. Not a simple storage — a connection layer through which knowledge flows between projects. |
| **Meta Hub** | The role of coordinating all field projects from the meta-harness cwd. Hub = common standards and feedback center / field projects = execution sites. |
| **Launch Pad Effect** | Using the meta-harness not as a final destination but as a launch pad — even a brief pass-through generates setup, pattern sharing, and speed-up effects. |
| **Transit Acceleration Value** | The meta-harness's core value — passing through itself accelerates the starting line. Acceleration effect occurs the moment you pass through, without requiring absorption or permanent setup. |
| **Shared Skill Pool** | Removes the cost of each team/harness independently reinventing the same skills/agents. The meta-harness provides a common pool and each project draws from it. |

---

## Operating Modes

| Term | Definition |
|---|---|
| **Mode A** | Full harness clone + use all skills/agents. Run directly from hub cwd. |
| **Mode B** | Partial harness clone or fork. Select and use specific skills/agents only. |
| **Mode C** | Install only fh-meta via `claude plugin install` without cloning hub. Independent plugin method. |
| **Path B generalization** | Generalizing skill behavior to work in external user environments without organization-specific infrastructure dependencies. |

---

## Diagnostic Skill Triangle

| Term | Definition |
|---|---|
| **Three-Doctor Loop** | Pattern where harness-doctor (structure diagnosis) + context-doctor (token/context diagnosis) + sim-conductor (simulation/ideation scan) form a self-renewing closed loop of diagnosis→prescription→re-diagnosis. |
| **harness-doctor** | Harness structure L1~L4 diagnostic skill. L1 structural completeness · L2 complexity · L3 Drift · L4 connection diagnosis. |
| **context-doctor** | Token waste diagnostic skill. `.claudeignore` auto-generation, large file detection, `/clear` timing guidance. |
| **sim-conductor** | Meta-simulation automation skill. Area A (external user) · B (internal audit) · C (ideation scan) · D (code/session/skill/memory verification) · E (quality examination). |
| **install-doctor** | Plugin install pre/post conflict, duplicate, and silent overwrite risk diagnostic skill. |

---

## Prescription Tiers

| Term | Definition |
|---|---|
| **M-tier (Mandatory)** | Requires immediate action. Risk of functional failure or data loss if left unaddressed. |
| **S-tier (Strongly recommended)** | Strongly recommended improvement. Quality degradation and drift accumulation if left unaddressed. |
| **R-tier (Recommended)** | Recommended optimization item. Efficiency improvement when resolved. |

---

## Design Principles

| Term | Definition |
|---|---|
| **Simplification Guard** | Mandatory matching of existing assets before adding new ones. Additions rejected without "N+ real-use observations". The execution mechanism of the "a good harness gets simpler over time" principle. |
| **Description diet** | Removing self-marketing vocabulary (iteration counts, version history, emphasis words, owner names) from skill frontmatter descriptions to make them readable by external users. |
| **Layer A auto-read** | The 4 files CLAUDE.md automatically reads at session start (CATALOG.md · latest track file · MEMORY.md · next session starter card). Only works in meta-harness cwd. |
| **Layer A fallback** | Alternate path when Layer A silent-skips in non-meta-harness cwd environments. Manual CATALOG.md read or adding Layer A reference to project CLAUDE.md. |
| **silent overwrite** | Risk of overwriting existing settings without user awareness. Detected in advance by install-doctor. |
| **drift** | Phenomenon of growing gap between design intent and actual behavior. Checked periodically as harness-doctor L3 item. |

---

## Evolution Concepts

| Term | Definition |
|---|---|
| **cascade α** | Stage where FH skills are first autonomously executed by internal users (including owner). |
| **cascade β** | Stage where FH skills are autonomously executed by users other than the owner (quasi-external). First achieved by an external user. |
| **cross-project skill bus** | Structure for centrally managing skills/agents of local projects through FH and enabling cross-project cross-calling. |
| **field harvest** | Process of feeding patterns discovered in field project work back (pull) to FH. Automated with `/field-harvest` skill. |

---

## Notation — `[[wikilink]]` in FH documents

FH documents (this package included) use `[[some_note_name]]` to cite a **provenance note in the
author's local memory store** — the per-project memory directory a Claude Code session keeps outside
the repository. Measured 2026-08-20 across the npm-published file set: **156 shipped `.md` files
carry 98 such references to 59 distinct targets, and none of those targets exist inside the
package** (hand-verified sample: `CLAUDE.md` cites `[[feedback_not_found_is_not_zero_family]]`,
which resolves only at the operator's memory path — `git ls-files` returns 0).

**So, for a reader who is not the author, these are not navigable links.** They are *attribution
markers*: they say "this sentence came from a recorded failure, not from taste", and they name that
failure so it can be discussed. Read them as footnote labels, not as paths.

🟥 **Do not treat one as a broken reference or try to repair it.** They are deliberately not
vendored — a memory store is per-operator, session-scoped, and frequently contains project-private
material, so shipping it would be a residency violation, not a fix. Equally, do not read a
`[[…]]`-cited claim as *unsourced*: the surrounding text always states the claim in full, and the
marker is provenance on top of it, never a substitute for it.

The convention is scoped to memory notes. A pointer to a file that **does** ship is written as an
ordinary path (`knowledge/shared/harness-core/…`), and those are checked mechanically by the
detail-pointer resolution gate at commit time.

---

## Recurring never-do invariants — names that point at machines

Every 4-axis marker carries a `절대 안 함` line: what the author committed, before designing, not to
do. **68 of them exist in this repo's marker corpus and no two are worded alike**, so the same
invariant is re-invented in fresh words each time, a later marker cannot cite an earlier one, and none
of them point at the machine that already enforces them.

This section gives the recurring ones a name. **A name here is a pointer to an existing mechanism, not
a rule.** It says *"this is already blocked over there"* — never *"this is what you must write."*

| Name | The invariant | Where it is already enforced |
|---|---|---|
| **NEVER-unmeasured-as-pass** | An absence, a skipped step, or a dead instrument is not a zero and is not a pass | `psa_scan_lib.sh` rc triad (0 clean · 1 hit · 3 **not scanned**) · `_absent_subject_verdict` (named SKIP, not silence) · the `DEGRADED_*` triads on `crossfamily:` / `standpoint:` / `soul-check:` — *could not* · *did not* · *did not look* stay three values |
| **NEVER-loosen-to-pass** | Do not relax a verdict, widen an exception, or blanket-mute to get green | `scripts/degrade_direction_scan.sh` — ⚠️ **advisory by design**, never a solo block: a commit is a reversible surface, and over-blocking trains `--no-verify`, which would disarm the Destructive-Op gate in the same hook |
| **NEVER-residency-leak** | Company identifiers, internal names, and operator-private tokens do not cross into public-tracked content | pre-commit confidentiality scan · `public_surface_scan_files.sh` at `prepublishOnly` · `/public-surface-audit` |
| **NEVER-new-surface** | Do not mint a new file, trigger, gate, or skill when an existing one can carry it | 🟥 **no machine, correctly.** `/asset-placement-gate` advises; the judgment stays human |
| **NEVER-freeze-the-verdict** | Do not encode a *conclusion* in code — only properties of the record | 🟥 **no machine, and there must not be one.** A checker for this would itself be the thing it forbids |

### Three rules that keep this from becoming a ceiling

1. **Names point at machines, not at correctness.** An entry answers *"where is this already caught?"*
   If the answer is "nowhere, and that is right", say so — two rows above do exactly that.
2. **It is open, and nothing enforces it.** A marker may cite a name or write free prose; free prose is
   where the next name comes from. 🟥 The moment this becomes an enum a hook validates, an unfamiliar
   invariant gets folded into the nearest existing row — the normalization reflex `CLAUDE.md
   §Envelope-Boundary Discipline` exists to counter, and the harness stops learning new *classes*.
3. **Loose on purpose, so it strengthens as models do** (operator, 2026-08-21). This harness is not
   built to make a weak model shuffle through a checklist. Tight coupling would cap the strong model at
   whatever the list froze. ⚠️ **This does not touch `sonnet_floor_doctrine.md`** — the two are
   different axes and conflating them is the two-layers-one-name defect this repo keeps recording:
   the floor is about a base op being **reachable** at the floor tier; this rule is about not building
   a **ceiling** above it. A name pointing at an existing mechanism is reachable *and* uncapped.

**Evidence, stated at its real strength**: the four clusters come from a hand-grouped pass over the 68
`절대 안 함` lines (concept clusters, not string match — string dedup returns ~1 each because the
wording never repeats; a control token returned 0). Counts: unmeasured-as-pass **7** · loosen-to-pass
**7** · new-surface **4** · freeze-the-verdict **4** · residency **4**.
🟥 **What was NOT measured: the cost of not having these names.** No case was counted where a marker
should have cited an earlier one and could not. The reason to add this is the orchestration argument —
you cannot route what has no name — which is a design argument, not a measurement. Do not cite this
section as evidence that the absence caused harm.

---

*Updated: 2026-08-21*
