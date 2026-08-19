---
name: fh-detail-protocols
description: On-demand detail for FH operational protocols — load when triggered, not at session start
load: on-demand
---

# FH Detail Protocols

> **Load strategy**: on-demand only. CLAUDE.md contains pointers and trigger conditions.
> Read this file when executing the relevant protocol step-by-step.

---

## Active Onboarding Protocol — Full 4-Step

When a user gives a greeting/session-start utterance, the AI enters active initiative mode.

### Step 1 — Auto Read + Duplicate Install Detection

**1-a. Auto read**:
- `CLAUDE.md` · `CATALOG.md` · active track directory (if present) · `reference_next_session_starter` (if present)

**1-b. Duplicate install detection**:

Scan parent (`../`) for sibling harness clones:
```bash
ls ../ | grep -iE '(forge-harness|meta-harness|-harness|-hub)'
```
- Multiple forge-harness installs detected → ask user: "(a) Use existing / (b) Proceed with new / (c) Archive old"
- Sibling assets detected → notify + present synergy path
- 0 catches → proceed to Step 2
- Known non-managed: `harness_framework` — suppress report

**1-c. Local skill registry**:

```bash
ls .claude/registry/LOCAL_SKILL_REGISTRY.md 2>/dev/null
```
- File exists and modified within 7 days → load into session
- Missing or older than 7 days → regenerate.
- **Typed-capability entries** (a field harness's mechanical layer, callable rather than dispatched)
  carry the extra schema in `knowledge/shared/harness-core/capability_composition_contract.md §ⓑ.2`
  and must clear its M1–M5 registration bar. An entry that cannot show a typed channel stays
  dispatch-only — registering it as callable is what makes a model-synthesized verdict look mechanical.

**No hardcoded root — derive the install location (users install FH anywhere).** The projects root is
the *parent of the FH repo*, discovered at runtime, never a literal `~/projects` / `~/PycharmProjects`
(a hardcoded root silently returns 0 on any machine whose layout differs — the 2026-07-05 dead-path
`fail-open` bug: `find ~/projects` on a `~/PycharmProjects` machine → 0 catches → the registry is
overwritten empty and cross-project summon goes dark):
```bash
HUB="${CLAUDE_PROJECT_DIR:-$(pwd)}"          # FH 레포 위치 (설치 위치 무관, 감지)
ROOT="$(cd "$HUB/.." 2>/dev/null && pwd)"     # 형제 프로젝트가 사는 부모 = 프로젝트 루트
# 두 레이아웃 모두 포착: .claude/skills/*/SKILL.md AND 루트-레벨 */SKILL.md (예: gstack).
# vendored(.venv·site-packages·node_modules·.git) 제외 — 없으면 playwright/streamlit 스킬까지 삼킴.
FOUND="$(find "$ROOT" -name SKILL.md \
  -not -path "*/.venv/*"  -not -path "*/site-packages/*" \
  -not -path "*/node_modules/*"  -not -path "*/.git/*" \
  -not -path "$HUB/*" 2>/dev/null)"    # exclude FH's own subtree by DERIVED path, not a name-literal (works when FH is cloned under any dir name)
```
Then **fail-closed** (irreversible-ish: a silent empty overwrite blinds the bus): if `$FOUND` is empty
**and** the existing registry has >0 entries, do **not** overwrite — flag `⚠️ scan returned 0 (root=$ROOT);
kept existing registry` and skip the rewrite. Only rewrite when the scan is non-empty (or the registry
was absent). Group by project (parent dir name). Record per skill: name · path · description · trigger
phrases · `requires_cwd` · `direct-executable` · `origin(FH|project|external)`+trust ·
**`residency(public|company|operator-private)`** · **`generality(general-purpose|project-specific)`**.
**Non-FH skills are propose-only (ask-tier), never auto-run** — a cross-project skill body is an
injection surface. Propose cross-project skills when a request maps to the registry. Scan once per
session. (Detection belongs at install too — `/install-wizard` records HUB/ROOT so the runtime never
guesses; see install-wizard.)

**`residency` derivation (mechanical, not asserted)** — from the project's git remote at scan time:
company org/account (e.g. a known company-dev namespace) → `company`; the operator's own account, repo
not `public` on the host → `operator-private`; else → `public`. **`generality` derivation (judged, not
mechanical — the scan flags a candidate, a session confirms)**: a skill whose description names no
project/company-specific noun and needs no project-local context to run elsewhere → `general-purpose`
candidate; confirmed only when a session actually reads the skill body and judges it works outside its
origin project (never auto-confirmed from the tag alone — chamber run #7, 2026-07-14, found the
generality field itself absent and the confirmed-general-purpose seed count effectively 0, which is
exactly the gap these two fields close). **Output landing-surface rule** (residency-restricted
combinations must never reach a public surface): any derived recommendation, "better-together" list, or
synergy output that names a `company`/`operator-private` residency entry lands **only** in gitignored
`tracks/_meta/` (or the private companion store) — **never** in tracked `tracks/{project}/` or any other
public-tracked file. A `public`-only combination may land in tracked docs.

### Step 2 — Active Proposal

Identity marker: every greeting response opens with **🐿️ then an identity-revealing welcome line on the same line** (a space after 🐿️; exact count not significant — the renderer collapses multiple mid-line spaces — the invariant is *same-line*, not 🐿️ alone) — new / exploratory = "Welcome to FH." · returning = "Welcome back to FH." · operator (FH-dev state) = "The FH operator — good to see you." This is FH's session-start signal — friendly, consistent, distinct; the onboarding-smoothness / lid matters even though it is not the substance. The marker + welcome are **part of each skeleton itself** (one salience unit with the menu — do not strip it when composing doors; mirrored in CLAUDE.md §Active Onboarding).

**Branch test (mechanical — local state only)**: returning = session files exist (any `tracks/**/session_*.md` or `tracks/_meta/*.md` beyond `.gitkeep`) **OR** mapped project tracks exist (`tracks/{name}/` dirs — **any underscore-prefixed dir doesn't count** (`tracks/_*`, general rule not a closed list: `_meta`/`_audit`/`_contrib`/`_chamber`…); covers mapped-but-not-yet-synced users). **Never infer the branch from git log or CATALOG residue** — a fresh clone carries full commit history but zero session files: it is a NEW install (origin: fresh-clone sonnet sim rendered the returning menu off commit messages, `fh_signal_2026-06-11` FP8).

**New user** (neither condition holds — fresh clone/install): 2-door starter, never the returning menu —
> 🐿️  **Welcome to FH.** *Looks like you're new here! What would you like to do?*
> - **①  Create your first project** — guided
> - **②  Map an existing project**
> - **📖  Read the guide / ask me anything**
>
> *…and I can run `/install-wizard` to finish initial setup.*

- **① Create your first project** → Step 3-0 (guided: name → `tracks/` → `.claudeignore` → cascade)
- **② Map an existing project** → `auto_project_mapping.md`; after a successful mapping, offer the §6 Full-Harness promotion prompt
- Either door: if initial setup looks incomplete (no hooks, no registry), offer `/install-wizard` once

**Exploratory trigger** (`what is this` / `first time here`):
> 🐿️  **Welcome to FH.** *forge-harness is a tool hub for rapidly setting up Claude Code projects. It supports plugin recommendations, project setup, and harness diagnostics. What would you like to work on?*

**Returning user** (branch test above) — open with the fixed 4-door menu (the doors are stable; the contents are composed live). A summary copy lives in CLAUDE.md §Active Onboarding — keep branch tests and door labels in sync when editing:
> 🐿️  **Welcome back to FH.** *What would you like to start?*
> - **①  Map a project**
> - **②  Create a new project**
> - **③  Accelerate or diagnose a mapped project** (work · Full-Harness · skills/agents/plugins · 진단) — {field candidates}
> - **④  Cross-project synergy**
> - **📖  Guide / Q&A**
>
🟥 **One door per line — never join them with `·` into a single run-on line** (operator, 2026-08-20).
A `·`-joined menu wraps at an arbitrary terminal width, so the reader cannot see where one door ends
and the next begins. The vertical list satisfies **G-GREET-02** (🐿️ + welcome on the SAME line),
**G-GREET-03** (fixed 4-door set) and **G-GREET-05** (welcome literals) unchanged — those probes pin
the door *set*, the *literals*, and the *welcome line*, **not the menu's line count**. Layout is the
render layer; the probes are the verdict layer. The 🔧 developer door is likewise its own row at the
bottom of the list, never appended to another line.

**📖 door (unnumbered, always rendered)** — opens `docs/USER_GUIDE.md` and takes FH-usage questions.
🟥 **Do not renumber.** ①–④ are the fixed set; 🔧 was the only unnumbered exception and 📖 joins it at
that layer. A guide is *reference before work*, not *the start of work*, so it does not belong in the
numbered set. **G-GREET-03 (fixed 4-door) and G-GREET-05 (welcome literals) both stay satisfied** — no
number was added and no welcome phrase was touched.
🟥 **"Open" means path + a 3-line table of contents FIRST.** Never dump the file inline — burning tokens
every session is precisely what this door exists to avoid. Then, and only then, branch on `uname -s`
to *suggest* an opener (Darwin→`open` · Linux→`xdg-open` · MINGW/MSYS→`start`); if none exists, skip
silently — the path already landed, so nothing is lost. ⚠️ `open` is macOS-only and FH ships via npm,
so it must never be the default path. Operating detail (allowed corpus · say "not found" when absent)
lives in `/fh` Step 3.5.

> (When **FH-dev state exists** — the operator — the welcome line is **"The FH operator — good to see you."** in place of "Welcome back to FH.")

- **① Map a project** → routes to `auto_project_mapping.md`; after a successful mapping, offer the §6 Full-Harness promotion prompt
- **② Create a new project** → Step 3-0 (new project setup)
- **③ Accelerate or diagnose a mapped project** → compose live from `CATALOG.md` / active tracks / the session card's **field-side** candidates — never hardcode a track name; read current state each time so the menu cannot go stale. Picking ③ with a *fix/diagnose* intent ("고칠 거 있나", "점검") routes to the **Field-Harness Diagnostic** (CLAUDE.md §Field-Harness Diagnostic) rather than the install plan. **Acceleration levers** (offer per project state, each user-approved):
  - **Full-Harness promotion** for projects still on light mapping (`auto_project_mapping.md` §6)
  - **Skill-ification** of repeated patterns (`#skill-candidate` tag at 3+ recurrences → SKILL.md draft; FH skill gates — diet · Done When · triggers — apply to field skills too)
  - **Sub-agent proposals** (`.claude/agents/*.md`, invocation rules in `operations.md`)
  - **Plugin adoption / plugin-ification — no-reinvention order**: platform built-ins (Tier 0) and `claude-plugins-official` (Tier 1) **first**, via `/plugin-recommender` — FH builds only the governance increment on top (mirrors §6 item 5: recommend-only, never auto-install)
- **④ Cross-project synergy** → render **only when 2+ project tracks exist** (underscore meta dirs don't count); runs `cross-ecosystem-synergy-detection` across mapped tracks. Findings flow back into each project (skills/patterns each project can adopt); when a finding fills an FH gap or repeats across 2+ projects, *propose* an FH contribution (`/field-harvest` → `tracks/_contrib` consent lane) — contribution is an **outcome of findings, never a standing door**
- **🔧 FH self-development (developer door — unnumbered, conditional)** → append ` · 🔧 FH self-development — {FH worklist}` to the menu line **only when FH-dev state exists**: session card `tracks/_meta/reference_next_session_starter.md` · open `fh_signal_*` files · `CLAUDE.local.md`. The hub operator always has this state (owner always sees it — no flag). Compose live from the card's **FH-side** candidates + open `fh_signal_*` items + open handoffs — picking it surfaces the in-progress FH dev worklist, never a blank prompt. Without dev state the door is **silently absent**; the user typing `developer` / `개발자` **as a standalone utterance or menu reply** (never a substring of a task sentence — "I'm a developer at X" does not open it) opens it on demand → route to `docs/CONTRIBUTING.md` + `tracks/_contrib/` + open `fh_signal_*` items (the contribution entry path)

**Routing rule**: session-card candidates are classified into ③ (field project work) vs 🔧 (FH self-dev) at composition time — one card feeds both doors.

**Precedence guards** (menu is the default, not the override):
- An **urgent open item** (e.g. a time-windowed handoff, a blocking external deadline) is proposed *instead of* the menu — urgency outranks the scaffold; mention the menu doors only after the urgent item is addressed or declined.
- An **explicit task utterance** skips the menu entirely (Active Onboarding guard — code/debug requests start directly). The old "jump straight into a task" door is intentionally gone: free task entry never needed a door, the guard already handles it.

Keep the door set fixed; compose each door's contents per situation. Do not expose internal code names — use action-oriented descriptions.

### Step 3 — 5-Skill Cascade

**Step 3-0. New Project Setup** (when user says "new project" / "new task"):
1. Confirm project name
2. `mkdir -p tracks/{project_name}` (on approval)
3. Recommend `.claudeignore` copy → `cp templates/.claudeignore <project>/.claudeignore`
4. Enter Step 3-1
   - Guard: if `tracks/{name}/` exists → report "Already set up" → jump to Step 3-1

| # | Skill | Trigger |
|:--:|---|---|
| 1 | `plugin-recommender` | Always on new task entry (after 3-0) |
| 2 | `cross-ecosystem-synergy-detection` | After plugin candidates found |
| 3 | `.claudeignore` proposal | New project mapping |
| 4 | Model switching guidance | After analyzing task nature |
| 5 | `verify-bidirectional` · `harvest-loop` | Emerge naturally during work |

### Step 4 — Approval → Setup
Plugin install · skill pre-activation · `.claudeignore` copy (on approval) · model switch guidance.

### Step 5 — Project cwd Option (Not Forced)
> *"Setup complete. Switching to the project cwd gives easier file access. You're welcome to keep working here."*

### Timing / Code Requests
- Pre-mapping: mapping + recommendation simultaneously. Post-mapping: recognize active track + augment.
- Code/debug requests from FH cwd → **start working directly**. Project routing is a suggestion, mention at most once after the task.

### Simplification Guards
- Explicit task-entry utterance → skip onboarding entirely
- Once per session · on user refusal, switch to standard mode immediately

---

## FH Improvement Signal Recording — Full Format

Create: `tracks/_meta/fh_signal_{YYYY-MM-DD}_{source}.md` (hub-relative path)

`{source}` = current cwd (e.g., `project-a` · `fh-direct`)

```markdown
---
type: fh-signal
date: YYYY-MM-DD
source: {source}
priority: high|medium|low
---
# FH Improvement Signal — {date} ({source})

## Session Retrospective        ← 마감 회고로 생성된 신호만. 상한 8줄. 이벤트 신호는 이 절 없음
- 정정: {운영자가 나를 정정한 건수} — 각 한 줄, 무엇을 어떻게 틀렸나
- 자력 {N} / 타력 {M} — 타력은 **잡은 축 이름**으로 (레인 · 되돌림 · cross-family · 첫실사용 · ⓓ · 운영자 · CI)
- 안 돌린 축: {이름, 또는 「없음」}
- 반복: {이번이 N번째인 실수 — memory 키 또는 「신규」}

🟥 **등급을 적지 마라.** «세션이 잘 됐다/못 됐다» 는 자평이고 게임 가능하다. 적는 것은 **사건과
그것을 잡은 축의 이름**뿐이다. 판정을 안 적으면 자평할 대상이 없다. 「정정 건수」는 트랜스크립트
사실이지 판단이 아니라서 게임이 어렵고, 자력/타력 분리는 «내가 다 잡았다» 를 쓰기 불편하게 만든다.
⚠️ 셋 다 자평을 **어렵게** 할 뿐 **닫지 않는다** — 닫히는 것은 peer 나 cross-family 가 이 회고를
읽을 때이고 그건 이 형식의 범위 밖이다.

## Friction Point
-

## FH Registration Candidate
-

## Status
- [ ] Pending hub review
```

**Guards**: 1 file per session (append if same date+source) · structural candidates only (exclude typos, resolved-in-session issues).

---

## Execution Tier Settings — Full Table

| Tier | Name | Tokens | Comparative Effect |
|:---:|---|---:|---|
| **S** | light | ~5K | Single agent orchestration + context alignment |
| **M** | standard | ~15K | **FH default — 80% effect at 25% token cost** |
| **L** | full | ~30K | Complex cross-project tasks + pattern harvesting |
| **XL** | max | ~60K+ | Full harness evolution cycle — architecture decisions + session wrap-up |

**forge-harness is not meant to use more tokens** — standard tier delivers meaningful improvements while minimizing token usage.

> Terminology guard: the S/M/L/XL **execution tier is a token-depth budget, NOT a model tier** — it is
> orthogonal to the Sonnet-floor / model-floor axis (`sonnet_floor_doctrine.md`); an XL run on Sonnet and
> an S run on Opus are both legal combinations.

```yaml
EXECUTION_TIER: standard   # light / standard / full / max
```

Temporary session change: say "use light mode for this one" or "switch to max".

---

## §Onboarding-Provenance

> Relocated from always-loaded `CLAUDE.md` on 2026-07-20 (residency-ledger rank 3). The **rules** these
> stories justify stay resident in CLAUDE.md; only the archaeology moved. Read this when you are about to
> *change* one of those rules — the failure that produced each one is the reason it reads the way it does.

**하류 remap 소유 규약 (2026-08-10, pmh-dev #54 — 임시방편이 아니라 정본 설계다)**: 인사
발화 문구와 규약 파일명(`fh_completed_*` 등)의 **문자열 정본은 FH가 소유**하고, 분기 설치
(조직 내부 반입 등)는 그 문자열을 자기 정체성으로 변환하는 **remap 집합을 자기 쪽에서
소유**한다 — 공유층 본문은 불변이며, 하류가 본문을 직접 고치면 드리프트로 계상된다. 따라서
FH에서 발화 문구·규약 파일명을 **추가하거나 바꾸는 변경은 하류 remap 통지를 같은 변경에
동반**해야 한다 — 프로브 `G-GREET-05`가 문구 리터럴을 고정해 무음 변경을 막는다(하류
설치에서 ④-log 검사기가 존재 불가능한 파일명을 3개월 보고 있던 오귀인이 이 규약의 실측
근거다 — pmh-dev #54).
갈림 판별 기준: **사용자-대면 발화이거나 게이트가 찾는 파일명이면 remap 대상, 환경변수·훅
스크립트명·npm bin 같은 기계 결합 이름은 불변**(변환하면 파손된다).

⚠️ **「게이트가 찾는」이 두 뜻으로 읽힌다 — 기계적으로 가른다** (pmh-dev #54 보류 2건 판정이
이 구분을 요구했다). 「찾는다」가 *런타임 탐색*인지 *정적 참조*인지가 판정을 뒤집는다:

| 「찾는」의 종류 | 판정 | 실례 | 왜 |
|---|---|---|---|
| **런타임 패턴 매칭 산물** — 검사기가 디렉토리에서 글롭/정규식으로 훑어 찾는 *산출물* 파일명 | **remap 대상** | `fh_completed_*` · `fh_signal_*` | 하류 실물이 `pmh_completed_*` 인데 검사기가 `fh_completed_*` 를 훑으면 **거짓 실패**(위 ④-log 3개월 오귀인이 그 사례) |
| **정적 경로 참조** — 스크립트가 **상수로 들고 있는** 규약/설정 파일명 | **불변(기계 결합)** | `.claude/rules/fh_4axis_gate.md` (`gate_pathspec_check.sh` 의 `CANON=` · `selfcheck.sh` · pre-commit 이 같은 경로) · `scripts/fh-gate.sh` (npm bin · 테스트가 못박은 경로) | 이름을 바꾸면 스크립트가 **대상을 못 찾아 파손**된다 |

판별 절차(1줄): **그 이름이 코드에 리터럴 상수로 박혀 있으면 불변**, **패턴의 일부로 훑이는
대상이면 remap**. `grep -n '<이름>' scripts/ templates/` 한 번이면 갈린다 — 상수 대입
(`X="…<이름>…"`)으로 나오면 전자, 글롭/정규식 안에 있으면 후자다.

### Why the greeting branch test is session files, never git history

A fresh-clone Sonnet simulation rendered the **returning-user menu** to a brand-new install, because it
inferred "returning" from commit messages and CATALOG residue. A fresh clone carries the full history and
**zero session files** — history is therefore evidence of the *project's* past, not *this user's*. Logged as
`fh_signal_2026-06-11` FP8. Hence the resident rule: the branch test is **mechanical local state — session
files under `tracks/`** — and underscore-prefixed dirs (`tracks/_*`) never count as mapped projects.

### Why the 🐿️ invariant is "same line", not a space count

An earlier phrasing pinned the number of spaces after 🐿️. That is unverifiable: a markdown renderer
**collapses multiple mid-line spaces to one**, so any assertion about the count is untestable in the
rendered output the user actually sees. The verifiable invariant is that the emoji and the welcome line are
on the **same line** (🐿️ alone on its own line was the defect being corrected).

### Why the welcome line must be a plain translation, not a coinage

Rendering the pinned welcome phrase in the user's language once produced an invented Korean coinage
(`안 조종실…`), caught by the operator. The line is a **plain, natural translation of the pinned phrase** —
onboarding smoothness is the lid, not the substance, but a wrong lid still reads as a broken product.

### Why a task-first entry still runs the companion-store load

Measured miss **2026-07-05**: the first message was a task, the session skipped the onboarding menu
*and* the Mode D companion-store pull along with it, ran on stale memory, and produced wrong
recommendations. The menu is a *menu*; the companion load is a *data load*. They were separated, and the
data load is now hook-backed via `scripts/fh_session_load.sh` (see `modes_and_value.md
§Session-start freshness`).

### Why the initiative table was diet-ed (2026-07-17)

A Step 0.5 trigger probe scored **13/18**. Rows whose skill-frontmatter `description` already caught the
utterance at high confidence were removed, because platform-native skill matching owns those: plugin-recommender ·
harness-doctor · synergy · frontier-digest · sim-conductor · install-wizard · asset-placement-gate ·
marketplace-gate · public-surface-audit · verify-bidirectional · mcp-circuit-breaker · token-budget-gate ·
salience-splitter (the last earned removal by a description strengthening made in the same change, not by
its original description). What the table deliberately KEEPS: proactive safety gates (publish · destructive ·
MCP-mount) · non-skill protocol routes (gates, doctrine sections, the deep-research ladder) · disambiguators
and weak-description rows. **Operative rule (resident):** before adding a row back, probe whether the
skill's description alone already catches it.
