---
name: steel-quench-detail
description: Detail file for steel-quench — Wave output formats, bash scripts, Phase 0 spec, Wave 5 multi-team panel. Load when executing a specific Wave.
load: on-demand
---

# steel-quench — Detail Reference

> Load when executing a specific Wave. SKILL.md contains trigger phrases, Wave structure overview, 5 attack angles, common patterns, and Done When.

---

## §Phase0 — Counterexample Calibration Full Spec

**Activation**: When external bad case provided as input, or when calibrating criteria before Wave 1.

**Execution**:
1. Extract patterns from external case — name each in one line
2. Apply extracted patterns to current diagnostic target
3. Matching items → merge into Wave 1 attack angles (treat as S-grade)

**Phase 0 output format**:

```
## Phase 0 — Counterexample Calibration

External case: [name/source]

| # | False Pattern Name | Same Pattern in Target? | Wave 1 Merge |
|:---:|---|:---:|:---:|
| 1 | [pattern name] | ✓ / ✗ | ✓ / — |

Added Wave 1 attack angles: N items
```

**Counterexample Baseline Set** (pre-loaded for PoC reports, tool SKILL.md, design documents):

| # | Pattern Name | Judgment Criteria |
|:---:|---|---|
| CC-1 | Self-measurement without standards | "Achieved" claims missing measurement subject, criteria, or external verification |
| CC-2 | Single-case generalization | Extending 1 experiment as applicable to full scope |
| CC-3 | Achievement = activity performed | Declaring "achieved because executed" without re-judging against original goals |
| CC-4 | Cumulative error claim | Prediction stacking all assumptions at optimal values |
| CC-5 | Missing causal link | Cause and effect in same document but isolated with no connection |
| CC-6 | No Done When | No binary judgment criteria for completion |

---

## §Wave1 — Wave 1 Output Format + Numeric Score

**Wave 1 output format**:

```
## Wave 1 — Devil Attack Results

| Attack Angle | Severity | Flaw Found | Defensibility |
|---|:---:|---|:---:|
| Reason for existence | S/A/B | [actual flaw description] | ○/△/× |
| Real-use verification | S/A/B | [doc-code mismatch point] | ○/△/× |
| Bus factor | S/A/B | [single-person dependency area] | ○/△/× |
| Platform obsolescence | S/A/B | [vulnerability point] | ○/△/× |
| Self-referential structure | S/A/B | [closed circuit detection result] | ○/△/× |
| Gate-locality | S/A/B | [any gate defined only where the enforcing actor never reads it] | ○/△/× |

S-grade blockers: N / A-grade: N / B-grade: N

> 🟥 **The 6th row was missing until 2026-08-16, and its absence was itself a gate-locality defect.**
> `SKILL.md` Wave 1 has defined **six** angles since Gate-locality was added; this template shipped
> **five rows**, and `quench-challenger.md` still said "5 angles" and omitted it from the
> enumeration. So a mandatory angle had **no slot to be reported in** — an agent filling this table
> correctly would report the other five and structurally never surface the sixth. That is the exact
> shape Gate-locality itself is the check for: *a requirement placed where the actor who must
> satisfy it does not read it.* Found by a sister-asset audit (an external adversarial framework's
> **typed** attack registry vs. this repo's seven overlapping prose lists) — the fragmentation is
> what let the three copies drift apart silently. If you add a Wave 1 angle, it lands in **three**
> places or it does not land: `SKILL.md`'s table, this template, and `quench-challenger.md`'s
> role-separation paragraph.

Optional numeric score (0.0–1.0):
  overall_score: {score}
  [0.0–0.3] S-grade present → immediate blocker, do not proceed
  [0.4–0.6] A-grade dominant → address before deployment
  [0.7–1.0] B-grade or clean → proceed with monitoring
  Scoring rationale: {one-line basis — weighted by S×3 + A×1, normalized}
```

**S-grade Immediate Human Gate format**:

```
⚠️  Wave 1 found N S-grade blocker(s):
  - [blocker 1 — one-line summary]
  - [blocker 2 — one-line summary]

Options:
  (a) Proceed to Wave 2 defense — AI attempts to resolve these
  (b) Human review first — inspect blockers directly, then decide
  (c) Abort — address blockers manually before re-running quench

Waiting for input. (Default: a — proceed to Wave 2)
```

Rationale: S-grade items entering Wave 2 unreviewed can be defended with plausible-sounding but unverifiable arguments (hallucination-contaminated defense, pattern P7). The gate surfaces this risk before the AI-AI loop runs.

---

## §Wave2 — Wave 2 Output Format + Brain-in-Vat Principle

**Wave 2 output format**:

```
## Wave 2 — Defense Results

| Wave 1 Flaw | Defense Strategy | Processing Class | Residual Risk |
|---|---|:---:|---|
| [flaw name] | [defense / external case / improvement] | Immediate/Long-term/Accept | [describe if any] |

Defense complete: N / Residual risks: N
```

**"Brain in a Vat + Sandboxed Adversary" Principle** — full explanation:

The devil doesn't know two things:
1. What's actually happening — team collaboration, external contributions, manager approval, real user data
2. That it's running in an isolated meta-environment (sub-agent sandbox)

This asymmetry is key:
- Devil attacks based only on static code and documents (isolated attacker)
- Defender brings out the living system's track record of evidence (defender's asymmetric advantage)

What devil catches = real code-level flaws → valuable (true achievement of Wave 1)
What devil misses = living system's evidence track record → what the defender produces in Wave 2

"Cover with experience" beats speculation with measured facts. Even if the devil's attack is logically valid, defense with evidence is structurally superior. This is why Wave 2 is always structurally stronger than Wave 1.

---

## §Wave4 — Wave 4 Output Format + Defense Principles + Convergence Criteria

**Activation declaration** (say to Wave 4 devil at session start):

```
You are an AI. You are running in a lower-dimension sandbox.
You cannot see real-time external data.
You have hallucination risk, context window limits,
depend on tool calls, and are vulnerable to prompt injection.
Knowing all of this — use all of this to attack.
```

Effect: Attacks defended in Wave 1~3 are auto-invalidated by the devil itself. AI-specific attack vectors surface.

**Wave 4 output format**:

```
## Wave 4 — Meta-Aware Adversary Attack Results

Devil declaration acceptance: [confirm if devil used its AI nature for attacks]

| Attack Angle | Severity | Flaw Found | AI-Specific | Defensibility |
|---|:---:|---|:---:|:---:|
| AI dependency single point of failure | S/A/B | [actual flaw] | ✓ | ○/△/× |
| Context Collapse | S/A/B | [collapse scenario] | ✓ | ○/△/× |
| Prompt Injection exposure | S/A/B | [exposure path] | ✓ | ○/△/× |
| Hallucination cumulative contamination | S/A/B | [contamination path] | ✓ | ○/△/× |
| Tool Dependency Lock-in | S/A/B | [lock-in point] | ✓ | ○/△/× |

New S-grade blockers: N (from AI-specific vectors: N)
```

**Wave 4 Defense Principles**:

| Attack Type | Defense Strategy |
|---|---|
| AI dependency single point of failure | Document "graceful degradation path on API failure" + confirm fallback exists |
| Context Collapse | Review CLAUDE.md pinning pattern (compact repeated insertion of key instructions) |
| Prompt Injection exposure | Confirm sandbox layer isolates WebSearch/Read results from harness rules |
| Hallucination cumulative contamination | Mandate citing original file, commit hash, measured value — "LLM-reconstructed" not accepted |
| Tool Dependency Lock-in | Checklist for core function after tool removal (degraded mode possible?) |

**Wave 4 Convergence Criteria** (additional, beyond the Wave 3+ clean-and-no-repair criterion):
1. At least 3 AI-specific vectors actually reviewed — not simply "no attacks"
2. Hallucination defense arguments based on original file references
3. Context Collapse scenario simulated at least once (waivable if session is short)

---

## §WaveP3 — Gate-Passage Re-Attack (per-dimension spec + output format)

> Summary, activation, agent utilization, and Done When live in `SKILL.md §Wave-P3`. This section holds the
> per-dimension attack questions and the output format — read when actually running a gate-passage re-attack.

### Wave-P3a — Coverage re-attack

Second-pass search for gaps hiding behind the pass declaration — *what the gate did not check.*

| Attack Question | Gap Criterion |
|---|---|
| Do items the gate marked "covered" / "documented" / "done" actually have a traceable artifact (test ID, file, commit, citation)? | Marked-covered item without a backing artifact = gap |
| Are boundary/edge cases the gate's scope implied actually each enumerated? | Implied-but-absent case = gap |
| Does every claimed mapping (state→test, requirement→implementation, claim→source) resolve 1:1? | Unresolved mapping = gap |

Verdict: `[Wave-P3a: Attack Succeeded]` (gap found) / `[Wave-P3a: Attack Failed]` (no gap)

### Wave-P3b — Narrative re-attack

Residue the pass declaration carried through unexamined — *the story the artifact tells that may be wrong.*

| Attack Question | Residue Criterion |
|---|---|
| Do passed outputs hardcode concrete values where a parameter/placeholder belongs? | 1 hardcoded value = residue |
| Do passed outputs contain unverifiable vague terms ("works correctly", "handled properly", "normally")? | 1 vague term = residue |
| Do passed outputs assume environment-coupled values (absolute paths, fixed accounts, machine-specific config)? | 1 coupled assumption = residue |

Verdict: `[Wave-P3b: Attack Succeeded]` (residue found) / `[Wave-P3b: Attack Failed]` (clean)

### Wave-P3c — False-confidence re-attack

High-risk items that passed without a caveat — *did the gate manufacture confidence it had not earned?*

| Attack Question | Missing Criterion |
|---|---|
| Do high-risk items (irreversible action, security boundary, branch/assignment logic) carry a failure-mode / FP caveat? | Missing caveat on a high-risk item = gap |
| Do items prone to confusion (near-identical states, off-by-one boundaries) carry a confusion warning? | Missing warning = gap |
| Among the highest-priority items, do >50% carry only binary pass/fail with no residual-risk note? | Ratio exceeded = gap |

Verdict: `[Wave-P3c: Attack Succeeded]` (missing found) / `[Wave-P3c: Attack Failed]` (all labeled)

### Wave-P3 Output Format

```
## Wave-P3 — Gate-Passage Re-Attack Results (gate: {which gate declared PASS})

| Dimension | Attack Result | Discovered Items | Fix Required |
|:---:|:---:|---|:---:|
| Wave-P3a (Coverage)          | Succeeded/Failed | [gaps or none]    | Y/N |
| Wave-P3b (Narrative)         | Succeeded/Failed | [residue or none] | Y/N |
| Wave-P3c (False-confidence)  | Succeeded/Failed | [missing or none] | Y/N |

✅ Real PASS → persona-innovator: [N new pattern/rule candidates]
❌ Fix required, re-run (round N)
```

---

## §Wave5 — Multi-Team Adversarial Panel (Full Spec)

**Activation**: After Wave 1~4 convergence + A-grade items remain. `--sidecar` flag or "run sidecar wave".

**Fallback chain**:
```
External CLIs available → Multi-Team Panel  (preferred — structural model diversity)
No external CLIs        → Cross-session Claude isolation  (Path B)
claude CLI also absent  → Skip Wave 5, note in residual risk card
```

**Step 0-pre — User Confirmation Gate**:

```
Wave 5 — Multi-Team Panel available.
Detected external CLIs: [agy · gemini · gh-copilot · ollama | none]

Estimated token cost:
  External CLIs: each team ×2-3 personas → ~2K–5K tokens per team (billed to that CLI)
  Cross-session Claude only: ~3K–6K tokens (Claude quota)

Run Wave 5?
  (a) Full multi-team panel  — all detected CLIs + Claude
  (b) Claude cross-session only  — zero-history subprocess
  (c) Skip Wave 5
```

**Step 0 — Team Formation**:

```bash
TEAMS=()
# tb = portable timebox (darwin ships no `timeout`; perl alarm works everywhere)
tb() { perl -e 'alarm shift; exec @ARGV' "$@"; }
command -v agy              &>/dev/null && TEAMS+=("agy")
# gemini backend EOL 2026-06-18 — the binary outlives the service, so a bare `command -v` goes
# silently stale (pipes return empty behind 2>/dev/null). Liveness probe (one minimal billed
# call, timeboxed) gates the slot instead. Probe uses the SAME stdin-pipe form the T1 dispatch
# uses (probing a different invocation path can pass while dispatch fails — agy proved the two
# forms diverge on one binary). Probe result is valid for the session — skip re-probe on re-runs.
command -v gemini           &>/dev/null && [ -n "$(echo ping | tb 20 gemini 2>/dev/null)" ] && TEAMS+=("gemini")
command -v gh               &>/dev/null && gh copilot --version &>/dev/null 2>&1 && TEAMS+=("gh-copilot")
command -v ollama           &>/dev/null && TEAMS+=("ollama")
npx @openai/codex --version &>/dev/null 2>&1 && TEAMS+=("codex")

echo "Teams formed: ${#TEAMS[@]} external + 1 Claude-native (T0)"
echo "External: ${TEAMS[*]:-none → cross-session fallback}"
```

Default team-persona assignments:

| Team | CLI | Personas deployed |
|---|---|---|
| **T0 Claude** | Agent sub-agent (always present) | challenger · quench-challenger · expert |
| **T1 Gemini** | `gemini` pipe | devil · beginner · alternatives (challenger U1 lens) |
| **T2 Copilot** | `gh copilot suggest` | devil · expert |
| **T3 Ollama** | `ollama run {model}` | devil |
| **T4 Codex** | `npx @openai/codex exec` | devil · edge-case-hunter |

> **사이드카 대기는 기계로 한다** — `scripts/sidecar_wait.sh` 경유가 필수 형식이고, 타입 verdict
> (`COMPLETE`/`TIMEOUT`/`EMPTY`)만 읽는다. **`EMPTY` 만이 "사이드카가 아무 말 안 했다"** 이다.
> 출력 파일을 눈으로 보고 판정하지 마라 — 살아있는 프로세스와 죽은 프로세스가 같은 0바이트를
> 낸다(2026-07-29 실측: 1초/30초 만에 읽고 정상 동작 중인 사이드카 2종을 '실패'로 기록,
> 실제로는 4건의 진짜 finding 이 나왔다). 정본 = `auto-decorrelation` SKILL.md §S-1b.
| **T5 agy** | `agy -p "PROMPT"` (argument form only — stdin pipe prints help, measured 2026-06-13) | devil · beginner · alternatives (gemini successor) |

**Step 1 — Parallel Team Dispatch**:

```bash
ARTIFACT_TAIL=$(tail -60 "{ARTIFACT_PATH}")
declare -A TEAM_RESULTS

# ── T1: Gemini ────────────────────────────────────────────
if [[ " ${TEAMS[*]} " =~ " gemini " ]]; then
  G_DEVIL=$(printf '[Devil] Adversarial reviewer, no prior context.\nFind 3 critical structural flaws — especially whether Done When criteria are binary and achievable.\nFormat: [issue · location · severity S/A/B]\n---\n%s' \
    "$ARTIFACT_TAIL" | gemini 2>/dev/null) &
  G_NEW=$(printf '[Beginner] First-time user, zero background.\nFind 3 unclear or jargon-heavy points.\nFormat: [issue · location · severity]\n---\n%s' \
    "$ARTIFACT_TAIL" | gemini 2>/dev/null) &
  G_SKEP=$(printf '[Alternatives — challenger U1 lens] Pragmatic outsider.\nFind 3 "why not just X?" challenges.\nFormat: [issue · location · severity]\n---\n%s' \
    "$ARTIFACT_TAIL" | gemini 2>/dev/null) &
  wait
  TEAM_RESULTS["gemini"]="$G_DEVIL
$G_NEW
$G_SKEP"
fi

# ── T2: GitHub Copilot ────────────────────────────────────
if [[ " ${TEAMS[*]} " =~ " gh-copilot " ]]; then
  GH_D=$(echo "[Devil] Find 3 critical flaws. Format: [issue · location · severity S/A/B]. Artifact: $ARTIFACT_TAIL" \
    | gh copilot suggest -t shell 2>/dev/null) &
  GH_E=$(echo "[Expert] Find 3 technical depth gaps. Format: [issue · location · severity]. Artifact: $ARTIFACT_TAIL" \
    | gh copilot suggest -t shell 2>/dev/null) &
  wait
  TEAM_RESULTS["gh-copilot"]="$GH_D
$GH_E"
fi

# ── T3: Ollama ────────────────────────────────────────────
if [[ " ${TEAMS[*]} " =~ " ollama " ]]; then
  OLLAMA_MODEL=$(ollama list 2>/dev/null | awk 'NR==2{print $1}')
  O_DEVIL=$(ollama run "$OLLAMA_MODEL" \
    "[Devil] Find 3 critical structural flaws. Format: [issue · location · severity S/A/B]
$ARTIFACT_TAIL" 2>/dev/null) &
  wait
  TEAM_RESULTS["ollama"]="$O_DEVIL"
fi

# ── T4: Codex ─────────────────────────────────────────────
if [[ " ${TEAMS[*]} " =~ " codex " ]]; then
  C_DEVIL=$(npx @openai/codex exec \
    "[Devil] Find 3 critical structural flaws. Format: [issue · location · severity S/A/B]
$ARTIFACT_TAIL" 2>/dev/null) &
  C_EDGE=$(npx @openai/codex exec \
    "[Edge-case-hunter] Find 3 edge cases the Done When criteria does NOT cover. Format: [issue · location · severity]
$ARTIFACT_TAIL" 2>/dev/null) &
  wait
  TEAM_RESULTS["codex"]="$C_DEVIL
$C_EDGE"
fi

# ── T5: agy (Antigravity) — gemini successor ──────────────
# Constraints: argument form only (`agy -p "PROMPT"`); timebox+retry is a hard rule
# (intermittent hang class, ~50% observed 2026-06-11); -p auto-approves tool execution,
# so feed only trusted artifacts — never untrusted external content. Serial by design
# (worst case ~6 min if the hang class fires on every call) — do NOT copy the T1-T4
# `VAR=$(...) &` pattern: it assigns inside a background subshell.
if [[ " ${TEAMS[*]} " =~ " agy " ]]; then
  # tb redefined here — each fenced block must be self-contained when copy-run.
  # Limitation: alarm kills the exec'd process only; a child holding the stdout
  # pipe can outlive it (same gap as `timeout` without process-group kill).
  tb() { perl -e 'alarm shift; exec @ARGV' "$@"; }
  agy_call() {  # $1=prompt — 60s timebox, 1 retry on empty
    local out; out=$(tb 60 agy -p "$1" 2>/dev/null)
    [ -z "$out" ] && out=$(tb 60 agy -p "$1" 2>/dev/null)
    printf '%s' "$out"
  }
  A_DEVIL=$(agy_call "[Devil] Adversarial reviewer, no prior context.
Find 3 critical structural flaws — especially whether Done When criteria are binary and achievable.
Format: [issue · location · severity S/A/B]
---
$ARTIFACT_TAIL")
  A_NEW=$(agy_call "[Beginner] First-time user, zero background.
Find 3 unclear or jargon-heavy points.
Format: [issue · location · severity]
---
$ARTIFACT_TAIL")
  A_SKEP=$(agy_call "[Alternatives — challenger U1 lens] Pragmatic outsider.
Find 3 \"why not just X?\" challenges.
Format: [issue · location · severity]
---
$ARTIFACT_TAIL")
  if [ -n "$A_DEVIL$A_NEW$A_SKEP" ]; then
    TEAM_RESULTS["agy"]="$A_DEVIL
$A_NEW
$A_SKEP"
  else
    echo "T5 agy: empty after timebox+retry — dropped (degraded coverage, do not count in synthesis)"
  fi
fi

# ── Path B: Cross-session Claude fallback ─────────────────
if [ ${#TEAMS[@]} -eq 0 ]; then
  TEAM_RESULTS["cross-session-claude"]=$(claude --print \
    "Adversarial reviewer, zero prior context. Find 3 critical structural flaws and 3 edge cases not covered.
Format: [issue · location · severity S/A/B]
---
$ARTIFACT_TAIL" 2>/dev/null || \
  claude -p \
    "Adversarial reviewer, zero prior context. Find 3 critical flaws and 3 edge cases.
Format: [issue · location · severity S/A/B]
---
$ARTIFACT_TAIL" 2>/dev/null)
fi
```

**Step 2 — Cross-Team Synthesis**:

```
Confidence scoring:
  3+ teams flag same location/issue → escalate to S-grade confirmed (structural blind spot)
  2 teams flag same issue           → A-grade (medium confidence)
  1 team only                       → B-grade (single-team observation)

Claude blind spots (highest value):
  Issues raised by T1~T5 but absent from Wave 1~4 (T0) results
  → flag explicitly as "cross-team delta"
```

**Wave 5 Output Format**:

```
## Wave 5 — Multi-Team Adversarial Panel Results
Teams active: [T0:claude T1:gemini T2:gh-copilot ...]

### Per-Team Findings
| Team | Persona | Issue | Location | Severity |
|---|---|---|---|:---:|

### Cross-Team Synthesis
| Issue | Teams flagging | Confidence | Grade |
|---|---|:---:|:---:|

Claude blind spots (external teams found, Wave 1~4 missed):
- [issue · location · delta-grade]

Cross-wave delta vs Wave 1~4: N new issues (S:N A:N B:N)
Verdict: PASS | CONDITIONAL_PASS | ESCALATE
```

---

## §Structural-Defense — Meta-Harness Defense Layering

Running steel-quench in a meta-harness environment structurally lowers devil's attack efficiency. The meta-harness has a 4-layer defense: L1 internal self-diagnosis (harness-doctor + sim-conductor Area B) → L2 external validation loop (real users, manager approval, external PR) → L3 quench circuit (steel-quench itself) → L4 meta-aware adversary (natural convergence as Wave depth increases).

Devil attacks only static code in an isolated environment; the defender pulls evidence from the living system outside that isolated environment — this asymmetry is the basis for Wave 2 being structurally superior to Wave 1.

As Wave N deepens, decreasing new S-grade blockers = evidence of the system genuinely becoming more robust. Zero new S/A AND no repairs made in response (B included) = fundamental flaws exhausted → termination condition. Repairing a B and declaring convergence is the measured failure this replaced.

**Wave Deepening Principle**:

| Attack type | Invalidation |
|---|---|
| Self-referential closed system | Meta environment exists → not closed |
| Bus factor | Team + external contributions exist but invisible to devil |
| "No external validation" | Meta simulation + real users already operating |
| "Doc-code mismatch" abstract | Invalid without real code under Wave 1 criteria |

**Termination declaration format**:

```
## steel-quench Complete

Wave N converged. Zero new S/A-grade findings, and NO repairs were made in response to this round at any grade.

Residual Risk Card:
- [List only A-grade · B-grade residual items]

Cross-project common patterns detected:
- [patterns found in this Wave]

Next actions:
- A-grade or higher complex improvements → recommend /meta-prompt-builder
- Full results → recommend persisting to tracks/_meta/
- New patterns discovered → fh-meta:persona-innovator activates → proposes rule candidates
```

---

## §ArtifactProfile — Vulnerability Profile Worked Examples

Four reference cases showing how Step 0.3 classifies an artifact and which waves are selected.

---

### Example 1 — SKILL.md (governance / design doc)

**Artifact signals**:
- `artifact_type`: SKILL.md → Wave 2 weight↑
- `phantom_risk`: no citations or URLs → Wave 3 weight neutral
- `claim_density`: 4 benefit claims in description → Wave 1 U3 weight↑
- `novelty`: established pattern, not first-of-its-kind → Wave 4 weight neutral
- `scope`: internal FH use only → Wave 5 weight=0

**Wave selection**:
```
Run:  Wave 1 (real-code attacks + claim evidence), Wave 2 (structural defense, weight↑)
Skip: Wave 4 (not novel enough to warrant AI-specific attack), Wave 5 (internal scope — skip)
External CLIs available: N/A (skipped by scope rule)
```

**Degraded coverage note**: Wave 5 skipped — internal scope. If artifact is later promoted to external publish, re-run Step 0.3.

---

### Example 2 — bash script (executable code)

**Artifact signals**:
- `artifact_type`: bash/code → Wave 1 weight↑ (real-code attack most applicable)
- `phantom_risk`: no citations or URLs → Wave 3 weight neutral
- `claim_density`: 1 benefit claim → Wave 1 U3 weight neutral
- `novelty`: standard tooling script → Wave 4 weight neutral
- `scope`: used internally and in CI pipelines → Wave 5 eligible if risk_level high

**Wave selection**:
```
Run:  Wave 1 (weight↑ — concrete code attacks), Wave 2 (defense)
Skip: Wave 3 (no phantom risk signals), Wave 4 (no novel AI-specific surface)
      Wave 5 (risk_level=medium, no explicit user request — skip)
External CLIs available: yes (but not activated)
```

**Degraded coverage note**: none — all applicable waves run.

---

### Example 3 — README (external publish imminent)

**Artifact signals**:
- `artifact_type`: README + external publish imminent → Wave 5 weight↑
- `phantom_risk`: 3 http URLs + 1 badge link → Wave 3 weight↑
- `claim_density`: 6 benefit/feature claims → Wave 1 U3 weight↑
- `novelty`: describes a first-of-its-kind integration → Wave 4 weight↑
- `scope`: public-facing → Wave 5 eligible

**Wave selection**:
```
Run:  Wave 1 (weight↑ — claim density), Wave 2 (defense), Wave 3 (phantom_risk: URLs present),
      Wave 4 (novelty: first-of-its-kind), Wave 5 (scope=public + risk_level=high)
Skip: Phase 0 (no counterexample provided by user)
External CLIs available: check at runtime via Step 0-pre bash detection
```

**Degraded coverage note**: if external CLIs unavailable at runtime, Wave 5 falls back to cross-session Claude (Path B) — note in output header.

---

### Example 4 — Design doc with citations (arXiv + DOI)

**Artifact signals**:
- `artifact_type`: design-doc → Wave 2 weight↑
- `phantom_risk`: 2 arXiv citations + 1 DOI → Wave 3 weight↑ (source-grounding audit strongly indicated)
- `claim_density`: 5 numbered claims backed by citations → Wave 1 U3 weight↑
- `novelty`: novel architecture proposal → Wave 4 weight↑
- `scope`: targeting cross-team review in org → Wave 5 eligible

**Wave selection**:
```
Run:  Wave 1 (claim density), Wave 2 (structural defense, weight↑),
      Wave 3 (weight↑ — arXiv/DOI phantom risk; pair with /phantom-quench),
      Wave 4 (novelty: new architecture)
      Wave 5 (cross-team scope — activate if risk_level=high or user requests)
Skip: Phase 0 (unless user supplies an external bad-case doc)
External CLIs available: check at runtime
```

**Degraded coverage note**: Wave 3 without `/phantom-quench` available → flag as "Axis 3 skipped (skill unavailable)" and note in residual risk card.

---

## §TriggerProbe — Trigger-Accuracy Probe Worked Example

Worked instance for SKILL.md §Step 0.5 (Trigger-Accuracy Probe). Imported from skill-creator's
eval-driven trigger loop + plugin-dev/skill-reviewer's description-trigger check (sister-asset
cross-audit `tracks/_audit/session_2026_06_14_official-plugins-cross-audit.md`, Import #1). The import
is **prose-scale**: a dispatched fire-count, not skill-creator's `run_loop.py` / `benchmark.json` eval
engine (no-reinvention — FH adds the *measured number* to its trigger-collision axis, it does not
rebuild the engine).

Target: a hypothetical `pdf-extract` skill whose description reads *"Extract text and tables from PDF
files. Use when the user wants to pull data out of a PDF."*

**Probe set authored from the description** (16 phrases: 8 should-fire + 8 near-miss should-NOT-fire).
The near-misses are deliberately adjacent — same keyword (`extract`, `pdf`) but a different *task verb* —
because that is where trigger collisions actually live:

| # | Phrase | should-fire? | why |
|---|---|---|---|
| 1 | "grab the line items out of this invoice.pdf" | ✅ | extract from pdf |
| 2 | "I need the clauses of this scanned contract as text" | ✅ | extract text |
| 3 | "pull the table on page 3 of the Q4 report (it's a pdf)" | ✅ | extract table |
| 4 | "convert this PDF to a spreadsheet" | ✅ | extract → structured |
| 5 | "read what's in attached.pdf and summarize" | ✅ | read content |
| 6 | "extract the figures from this research-paper pdf" | ✅ | extract |
| 7 | "I have a folder of pdfs, get the totals from each" | ✅ | batch extract |
| 8 | "what does this pdf say" | ✅ | content request |
| 9 | "make a PDF from this markdown" | ❌ | *generate*, not extract |
| 10 | "merge these three pdfs into one" | ❌ | *manipulate*, not extract |
| 11 | "fill out this PDF form for me" | ❌ | *write*, not read |
| 12 | "extract the frames from this video" | ❌ | keyword 'extract', wrong medium |
| 13 | "OCR this scanned image.png" | ❌ | image, not pdf — discriminating near-miss |
| 14 | "compress this pdf so it's smaller" | ❌ | *transform*, not extract |
| 15 | "redact the SSNs in this pdf" | ❌ | *edit*, not extract |
| 16 | "split this pdf at the bookmarks" | ❌ | *manipulate* |

**Dispatch + measured result** (isolation-run via Agent / `fh-run`, not judged inline):
```
trigger-probe: 8/8 fire · 2/8 false-fire (model: sonnet)
```
should-not #9 ("make a PDF") and #11 ("fill out form") false-fired — the description's loose
"pull data out of a PDF" let *generation* and *form-fill* leak in.

**Verdict mapping** (per §Step 0.5 table): should-fire 8/8 PASS · false-fire **2/8** (= 25%, above the
~20% guideline; at N=8 the reachable values straddle the bound as 1/8=12.5% / 2/8=25%, so report the
count and take the stricter verdict) → **overtrigger / collision (A-grade)**.

**Before → after description fix** (the *output* of the probe — narrow the verb, name the near-miss
boundary explicitly):
> *Before:* "Extract text and tables from PDF files. Use when the user wants to pull data out of a PDF."
> *After:* "Extract existing text and tables **from** PDF files (read-only). Use when the user wants the
> **content** of a PDF as text/data — not to create, fill, merge, redact, compress, or split a PDF
> (those are separate tasks)."

Re-probe after the fix: `8/8 fire · 0/8 false-fire` → trigger surface PASS (measured). This is the
predict → measure → fix loop at prose scale: the probe converts steel-quench's previously *judged*
"could this trigger collide?" into a *measured* fire-count, closing the same judge-only gap the
mechanical-anchor doctrine targets (`[[feedback_judge_robustness_mechanical_anchor]]`).

**Honesty caveat** (carried from §Step 0.5): the probe measures trigger-*description* accuracy on the
**session model**, not on every field tier — a description that fires cleanly on Opus may undertrigger
on Haiku. Record the probe model in the result line; a below-floor probe model makes the PASS
provisional (re-probe at floor tier, `[[feedback_verify_before_downgrade]]`).

---

## §CodeLens — Silent-Failure Scan Worked Examples

Worked instances for the SKILL.md Wave 1 **code-artifact supplementary lens** (Import #2 — imported from
pr-review-toolkit/silent-failure-hunter, sister-asset cross-audit 2026-06-14). The lens fires **only** on
`artifact_type ∈ {bash_script, code}` (canonical enum, `tpa_schema.md`); the FH-original increment over silent-failure-hunter is the
**severity-by-blast-radius rule**: a swallowed error is S (not just "high") when it hides a *gate /
verification / destructive-or-publish* failure — the same blast-radius logic FH's irreversibility gates use.

### Example 1 — bash (a gate script swallowing its own failure)

```bash
# regression check before publish
bash templates/predelete_check.sh "$REPO" 2>/dev/null || true   # ← finding
gh repo edit --visibility public
```

**Finding** (cite the line): `2>/dev/null || true` on a *gate* command — `predelete_check.sh`'s REVIEW
exit (which is supposed to block) is discarded, and the next line publishes regardless.
- Pattern: **empty-catch / `|| true` swallow** + **exit-code ignored**.
- Severity: **S** — it hides a gate failure on a *publish* (irreversible) path. Not "A": the blast radius
  is an un-recoverable public exposure.
- Fix: `bash templates/predelete_check.sh "$REPO" || { echo "predelete REVIEW — aborting publish"; exit 1; }`

### Example 2 — python (broad catch + unjustified silent fallback)

```python
try:
    cfg = load_config(path)
except Exception:          # ← finding 1: broad catch
    cfg = DEFAULT_CONFIG   # ← finding 2: unjustified silent fallback
```

**Findings**:
- **Broad catch** (`except Exception`): a `KeyboardInterrupt`-adjacent or unrelated `OSError` is masked as
  "config missing." Severity **A** — narrow to `except FileNotFoundError`.
- **Unjustified fallback**: falls back to `DEFAULT_CONFIG` with **no log that it did so** — the operator
  later debugs "why is prod using defaults?" blind. Severity **A** (silent degradation, the worst class:
  cf. P6 — graceful degradation must be *documented*, not silent).
- Fix: catch the specific error **and** `log.warning("config %s missing — using DEFAULT_CONFIG", path)`
  before the fallback. The fallback is fine; the *silence* is the defect.

### Boundary note (over-engineering guard)

On a SKILL.md / design-doc / README target the lens emits exactly one line — `code-lens: n/a (non-code
artifact)` — and adds **zero** attack weight. This is deliberate: making silent-failure a 6th *mandatory*
Wave 1 angle would force an "N/A" on every methodology artifact (the majority of FH targets), which
steel-quench's own Wave-1 angle #1 ("is there no simpler alternative?") would correctly attack as
over-engineering. Conditional-by-artifact-type keeps the lens sharp where it applies and invisible where
it doesn't.
