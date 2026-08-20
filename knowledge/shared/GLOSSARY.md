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

*Updated: 2026-08-20*
