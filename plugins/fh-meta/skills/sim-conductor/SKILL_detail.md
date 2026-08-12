---
name: sim-conductor-detail
description: Detail reference for sim-conductor — bash scripts, multi-team panel, Area B baseline methods, D-consumer execution, Area E execution, report template, PR bash, Path B. Load when executing a specific step.
load: on-demand
---

# sim-conductor — Detail Reference

> Load when executing a specific step. SKILL.md contains triggers, target profile analysis, precondition table, area summaries with persona routing, human gate, and Done When.

---

## §Step0-Bash — Environment Sync Scripts

```bash
HARNESS_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SIM_CLONE=~/sim/your-hub-sim/forge-harness-via-clone
[ -d "$SIM_CLONE" ] && (cd "$SIM_CLONE" && git pull origin main) || SIM_CLONE="$HARNESS_ROOT"

# Report storage path
REPORT_DIR=$(find "$(dirname "$HARNESS_ROOT")" -maxdepth 2 -name "tracks" -type d 2>/dev/null | head -1)
REPORT_DIR="${REPORT_DIR:-$HARNESS_ROOT/tracks}/_meta"
mkdir -p "$REPORT_DIR"
```

**Area B frequency check bash**:
```bash
ls "$REPORT_DIR"/sim_*_area_B*.md 2>/dev/null | sort | tail -1
# If date within 7 days → output warning + stop
```

---

## §PersonaDiscovery — Plugin-Recommender Integration

### Query format for plugin-recommender

When a GAP is detected for a high-weight perspective:

```
/plugin-recommender query:
  context: "sim-conductor persona gap"
  needed_perspective: [perspective name, e.g. "security-auditor"]
  artifact_type: [from profile, e.g. "Python auth code"]
  audience: [from profile]
  constraints: "must work as Agent sub-agent dispatch (no interactive CLI)"
```

plugin-recommender returns: ranked candidates with name · source (FH native / marketplace / external) · install command · token cost estimate · fit rationale.

### Gap resolution decision tree

```
GAP detected for [perspective X]:
  Is it high-weight (profile score ≥ 0.7)?
    YES → present plugin-recommender result → user: install / skip / substitute
          install: run install cmd → register → continue Step 0.3
          skip: auto-fill with ② built-in fallback, flag as "degraded coverage"
          substitute: user names alternative agent → use it
    NO  → auto-fill with ② built-in fallback, no prompt
```

### Persona map by artifact type (typical optimal)

| Artifact type | Optimal personas | Likely GAP (not in FH native) |
|---|---|---|
| SKILL.md / governance doc | challenger · beginner · expert | deep org-specific governance role → query plugin-recommender |
| README / marketing copy | beginner · challenger · expert | none native (challenger U1 covers the skeptic lens); niche field depth → query |
| Python / JS code | challenger/Code · main-player (Heavy) · security-auditor | security-auditor → query if auth/data |
| Auth / security-sensitive code | security-auditor · challenger/Code · main-player (Heavy) | security-auditor → block if GAP (high-weight) |
| Design doc + citations | challenger · expert | expert web-grounds citations natively; deep niche subfield → query |

### Degraded coverage flag

When any high-weight persona is substituted with built-in fallback (user chose "skip"):
```
⚠️ Degraded coverage: [perspective X] substituted with built-in [fallback name].
   Risk: [what this perspective would have caught that built-in may miss].
   Recommendation: install [plugin name] before external publish.
```

Degraded coverage persists in Step 3 report under "Persona composition used."

---

## §Profile-Examples — Target Profile Worked Examples

### Example 1: SKILL.md (governance doc)

```
Target Profile:
  artifact_type: SKILL.md (governance doc)
  audience: mixed (internal FH users + potential external installers)
  claim_density: medium (2 stated benefits, 1 "autonomous" claim)
  risk_level: medium (not yet externally published)

Recommendation:
  Areas: B (internal meta audit) + D-skill (cold-start validation)
  Persona composition: challenger (high — claim verification), beginner (medium — onboarding), expert (medium — governance accuracy)
  Scale: Minimum (3)
  Prerequisites: none (not yet external publish)
```

### Example 2: README (pre-publish)

```
Target Profile:
  artifact_type: README (external entry point)
  audience: external installer (first-time user)
  claim_density: high (5+ capability claims, "automatic", "zero config")
  risk_level: high (marketplace / external publish imminent)

Recommendation:
  Areas: A (external user perspective — primary) + C (naming gap scan)
  Persona composition: beginner (high), challenger (high — claim density), main-player (medium)
  Scale: Extended (4–5)
  Prerequisites: steel-quench REQUIRED before Area A proceeds
```

### Example 3: Bash script / Python code

```
Target Profile:
  artifact_type: bash script (50 lines, 3 external commands)
  audience: internal developer
  claim_density: low (technical spec only)
  risk_level: low (pre-PR, internal)

Recommendation:
  Areas: D-code (primary)
  Persona composition: challenger/Code (edge cases, security surface), main-player (Heavy — performance, limits)
  Scale: Minimum (2 — third persona adds minimal value for bash)
  Prerequisites: none
```

### Example 4: Design doc with arXiv citations

```
Target Profile:
  artifact_type: design doc (contains arXiv references + code blocks)
  audience: internal team
  claim_density: high (3 arXiv claims, 2 quantitative benchmarks cited)
  risk_level: medium
  novelty: high (references recent paper)

Recommendation:
  Areas: D-code + phantom-quench (quantitative claims)
  Persona composition: challenger (claim-evidence), expert (arXiv validity, web-grounded)
  Scale: Minimum (3)
  Prerequisites: phantom-quench recommended (novelty + citations)
```

---

## §MultiTeam — Multi-Team Panel Execution

### Pre-entry confirmation dialog

```
Area A — Multi-Team Mode available.
Detected external CLIs: [list or "none"]
Estimated additional token cost: ~2K–5K per external team (billed to that CLI's quota).
Run multi-team? (a) Full panel  (b) Claude sub-agents only  (c) Skip to Area B
```

### Team → Persona mapping

| Team | CLI | Personas | Dispatch method |
|---|---|---|---|
| T0 Claude | Agent sub-agent | hub-persona-auditor · challenger · expert | Agent() call |
| T1 Gemini | `gemini` pipe | beginner · main-player · challenger | `echo PROMPT \| gemini` |
| T2 Copilot | `gh copilot suggest` | challenger · expert | `gh copilot suggest -t shell` |
| T3 Ollama | `ollama run` | challenger | `ollama run llama3 PROMPT` |
| T4 Codex | `npx @openai/codex exec` | challenger · edge-case-hunter | `echo PROMPT \| npx @openai/codex exec -m gpt-5 -` |

> **사이드카 대기는 기계로 한다** — `scripts/sidecar_wait.sh` 경유가 필수 형식이고, 타입 verdict
> (`COMPLETE`/`TIMEOUT`/`EMPTY`)만 읽는다. **`EMPTY` 만이 "사이드카가 아무 말 안 했다"** 이다.
> 출력 파일을 눈으로 보고 판정하지 마라 — 살아있는 프로세스와 죽은 프로세스가 같은 0바이트를
> 낸다(2026-07-29 실측: 1초/30초 만에 읽고 정상 동작 중인 사이드카 2종을 '실패'로 기록,
> 실제로는 4건의 진짜 finding 이 나왔다). 정본 = `auto-decorrelation` SKILL.md §S-1b.
| T5 agy | `agy -p` (gemini successor) | challenger · beginner | `agy -p "PROMPT"` — argument form only (stdin pipe prints help); timebox+retry hard rule (intermittent hang class); -p auto-approves tools → trusted artifacts only |

### CLI detection bash

```bash
# Detect available external CLIs
AVAILABLE_CLIS=""
tb() { perl -e 'alarm shift; exec @ARGV' "$@"; }   # portable timebox — darwin ships no `timeout`
command -v agy      &>/dev/null && AVAILABLE_CLIS="$AVAILABLE_CLIS agy"
# gemini backend EOL 2026-06-18 — binary outlives the service; liveness probe (timeboxed minimal
# call) replaces the bare `command -v`, which would pass while pipes silently return empty.
# Probe uses the same stdin-pipe form T1 dispatch uses; result valid per session (no re-probe).
command -v gemini   &>/dev/null && [ -n "$(echo ping | tb 20 gemini 2>/dev/null)" ] && AVAILABLE_CLIS="$AVAILABLE_CLIS gemini"
command -v gh       &>/dev/null && gh copilot --version &>/dev/null && AVAILABLE_CLIS="$AVAILABLE_CLIS copilot"
command -v ollama   &>/dev/null && AVAILABLE_CLIS="$AVAILABLE_CLIS ollama"
command -v npx      &>/dev/null && npx @openai/codex --version &>/dev/null 2>&1 && AVAILABLE_CLIS="$AVAILABLE_CLIS codex"
echo "Available: ${AVAILABLE_CLIS:-none}"
```

### Cross-team synthesis format

```
Cross-Team Synthesis:
| Issue | Teams | Grade |
|---|---|---|
| [issue description] | [T0+T1 / T1+T2 / etc.] | S-confirmed / A-confirmed |

Claude blind spots (external-only findings):
- [T1 found X, T0 missed → Claude blind spot: ...]
```

**Path B fallback**: No external CLIs → cross-session `claude --print` as T0 cold-read variant.

---

## §AreaB-Baseline — External Baseline Injection Methods

Structural methods to reduce self-reference risk in Area B:

1. **Regular adversarial attacks**: Area B once/month + `challenger` attack once/quarter. Route challenger → defense results directly into SKILL.md via steel-quench handoff after Area B ends.
2. **Direct external user validation**: Non-owner attempts install + invocation → collect reactions. (cascade β validated: first autonomous external run confirmed.)
3. **steel-quench integration**: After Area B ends, hand off challenger findings to `/steel-quench` for deeper adversarial review + SKILL.md inscription.
4. **Dual validation principle**: Internal validation (Area B) alone is insufficient — minimized only when combined with external install reaction collection or cross-model validation. **For risk≥medium targets this is no longer advisory: it is the hard Cross-Model Coverage Gate** (SKILL.md Step 0.6) — at least one persona from outside the orchestrator's session context (external CLI → cross-session Claude → else `cross_model_coverage: NONE` withdraws auto-commit). Promoted from advisory to gate by the judge-robustness swarm (2026-06-13): a homogeneous same-session panel shares blind spots, so its clean verdict cannot self-certify.

**Dispatch template for Area B parallel**:
```
Agent A (hub-persona-auditor): target=[files], task="3+ persona simulation, 4-axis review, 3-tier suggestions"
Agent B (persona-innovator, Mode I): target=[files], task="naming gaps + structural gaps + 3-5 candidates"
→ both complete → 
Agent C (challenger, artifact_type="SKILL"): input=[A output + B output], task="what was missed? angles U2, D3, U5"
```

---

## §AreaD-Consumer — D-consumer Execution Detail

### D-session — Session Card Cold-Start

Auto-detect target (when `--target` not specified):
MEMORY.md → check `reference_next_session_starter.md` → if absent: search latest session-starter in `tracks/_meta/` or `memory/`.

Provide only that file to consumer agent (no context). Ask:
1. The most important thing to do today
2. Current work-in-progress status
3. Events/deadlines that must not be missed
4. Parts that are unclear or lack context

**Verdict**: Top priority matches + context reconstructable → F / Context reconstructed but gaps → P / Wrong top priority or key item missing → B.
B/P items: fix directly in session card + commit.

### D-skill — Skill Trigger Utterance Consumer Simulation

Provide only one SKILL.md to consumer agent (no context, no SKILL_detail.md).
Assume first trigger sentence from Trigger Phrases was input → attempt to complete from Step 1.
Record: where it stalled, why, whether core task completes, what needs fixing.

**Verdict**: Core task completes → F / Partial completion (stalled mid-step) → P / Blocked at Step 1 → B.

### D-memory — Memory File Cold-Start Validation

Provide only one memory file to consumer agent. Check:
① When should this be applied?
② Can current validity be determined from this file alone?
③ Can the behavior guideline be executed from this file alone?
④ Any stale or contradictory information?

**Verdict**: ③ executable + ④ none → F / Some unclear parts → P / Stale/contradiction found → B.

---

## §AreaE-Detail — Area E Execution

### E-1 — Domain Expert Objection

Agent (subagent_type="challenger", artifact_type="Design"): false positive patterns (clearly wrong judgments) + false negative patterns (should-have-caught-but-didn't). Angles: U3 (evidence grounding), D4 (failure mode coverage).

Findings format: `[judgment type · pattern · root cause · fix direction]`

### E-2 — Practitioner Confusion

Agent (`beginner` brief): confusing items, fix suggestions more awkward than original, classification criteria consistency breaks.

Findings format: `[item · confusion cause · improvement direction]`

### E-3 — Pattern Structuring (direct execution)

Integrate E-1/E-2 → group false positives by root cause → assign pattern name → pinpoint fix location → M/S/R classification → fix target code/prompt → commit.

---

## §Report-Format — Report Template

```markdown
---
name: [date] sim-conductor — Area [X]
type: simulation-report
date: YYYY-MM-DD
areas: [A|B|C|D|E|all]
target_profile: [artifact_type | audience | risk_level]
cross_model_coverage: [external | cross-session | NONE | n/a-low-risk]   # Step 0.6 — recorded from dispatch path
m_count: N
s_count: N
r_count: N
---

## Target Profile
artifact_type: [type] · audience: [internal|external|mixed] · risk_level: [low|medium|high]

## Coverage map (Step 1.5 — every profile standpoint marked covered/ZERO)
[verbatim zero-coverage map; ⚠️ on each ZERO]
cross_model_coverage: [external | cross-session | NONE]   # NONE on risk≥medium → auto-commit withdrawn (Step 4)

## M-tier ([N] items)
| # | Issue | Location | Prescription |
...

## S-tier ([N] items)
| # | Issue | Location | Priority |
...

## R-tier ([N] items)
...

## Emerging asset candidates
...

## Persona composition used
[list of personas used + which were task-derived vs built-in]
```

---

## §PR-Bash — PR Creation Scripts

```bash
cd "$HARNESS_ROOT"
BRANCH="fix/sim-$(date +%Y%m%d)-m-tier"
git switch -c "$BRANCH"
# [process M-tier items] — collect the files this run actually edited
# Explicit list; never a glob, never -A, never `.`. Use an ARRAY, not a space-separated string:
# `git add -- $FILES` relies on bash word-splitting an unquoted parameter expansion, and zsh does
# NOT split one (SH_WORD_SPLIT off by default). Under zsh the whole string arrives as ONE pathspec,
# git errors "did not match any files", and the commit that follows stages nothing — the explicit-
# path discipline this line exists to enforce silently stops applying in the operator's own shell.
FILES=(path/to/edited1.md path/to/edited2.md)
git add -- "${FILES[@]}"
git diff --cached --name-only    # confirm the staged set IS the intended set before committing
git commit -m "fix(sim-conductor): resolve M-tier findings from simulation YYYY-MM-DD"
git push -u origin "$BRANCH"
# PR creation requires explicit user request per CLAUDE.md PR principle
```

> **Never `git add -p` here — this skill runs to completion unattended.** `-p` is interactive: with
> no TTY it either blocks forever, or (with stdin closed) exits **0 having staged nothing**. Measured
> 2026-08-12 on the documented chain: `add -p` → rc 0, nothing staged → `git commit` → **rc 1**,
> while `git switch -c` had **already created the branch** — so the run leaves a branch behind, the
> fixes uncommitted, and a success-shaped exit on the staging step. A silent no-op in the middle of
> an auto-commit chain is worse than a hang, because only the hang is visible.
>
> **Why an explicit list rather than `-A` or `.`**: `sim-conductor` frequently runs in a checkout
> shared with other work. `git add -A` sweeps up whatever else is dirty — measured above: a
> co-resident `b.txt` was left untouched by `git add -- a.txt` and would have been swallowed by
> `-A`. Note the boundary: `git add -- <file>` stages **the whole file**, including lines this run
> did not write, so if another session has appended to a file you also edited, commit that append
> first rather than absorbing it.
>
> `git diff --cached --name-only` before the commit is the mechanical check that the staged set
> equals the intended set. Do not skip it — it is what turns "I passed the right paths" from a
> belief into an observation.

---

## §PathB-Detail — External Environment Fallback

When `~/sim/` is absent:
- Step 0: `SIM_CLONE="$HARNESS_ROOT"` (skip git clone)
- Logical isolation only: inject "Treat the following as if you have no prior development context" into each Agent prompt
- **Area B only recommended**: Area A/C technically executable but physical isolation not guaranteed (direct path references). Logical isolation via prompt directive is the only available control.
- Area D/E: fully functional (target-file-based, no sim clone needed)
