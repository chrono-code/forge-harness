---
name: fh-ecosystem-positioning
description: FH's structural position in the AI agent framework ecosystem vs Hermes, OpenCode, OpenHuman — gap analysis, synergy map, and layered readiness verdict from 3-model adversarial audit (Claude + Gemini + Codex).
date: 2026-05-31
tags: [ecosystem, positioning, synergy, opencode, opencode, hermes, openhuman, readiness, v2-paper]
---

# FH Ecosystem Positioning

## Source

3-model orchestrator-swap adversarial audit (2026-05-31).
- Orchestrator: Claude Opus (synthesis)
- Sidecar 1: Gemini (structural + security lens)
- Sidecar 2: Codex (ecosystem + distribution lens)

Target: FH full structure vs Hermes-type agent frameworks, OpenCode-style coding agents, OpenHuman-style human-in-loop systems.

**Cross-ref**: `fh_global_positioning_and_distribution_roadmap.md` (2026-08-15) covers adjacent ground — same "FH vs bare execution coders" positioning question, but scoped to npm/Homebrew distribution mechanics rather than this doc's 3-model ecosystem-structure audit. Read together, not as duplicates.

---

## Gap Analysis — Where FH Falls Short

| Gap | Gemini finding | Codex finding | Convergence |
|---|---|---|---|
| **Runtime / Distribution** | — | No standalone binary, no package-manager path; peers (OpenCode, Hermes IDE, OpenHuman) ship signed installers | Codex only |
| **Execution sandboxing** | No WASM/Docker isolation — destructive bash commands possible inside skill steps | — | Gemini only |
| **Concurrent state** | File-system bottleneck — no event-bus; parallel agents on same `tracks/` risk state corruption | — | Gemini only |
| **HITL granularity** | Binary confirm/deny — no capability-based fine-grained delegation (OpenHuman standard) | — | Gemini only |
| **Gate enforcement** | — | Gates are advisory (instructional thresholds, not mechanical block) | Codex only |
| **Registry coherence** | — | Count drift: 33 skills, 6 agents vs declared values → fixed in this session | Codex only (fixed) |

**No gap converged across both models** — each lens found distinct weaknesses. This itself is a cross-wave delta finding: Gemini sees architecture risk, Codex sees distribution/ecosystem risk.

---

## Synergy Map — Where Integration Produces N-Fold Value

### 1. FH + OpenCode: Governance Layer on Execution Speed

| Layer | Provider | What it contributes |
|---|---|---|
| Execution | OpenCode | High-volume autonomous coding, CLI/desktop distribution, broad language support |
| Governance | FH | `pipeline-conductor` (4-axis gated sweep) + `steel-quench` (adversarial review) + `phantom-quench` |

**N-fold mechanism**: OpenCode is criticized for "automation-drift" — valid code that doesn't solve the core problem. FH's adversarial + grounding verification layer catches this. The combined result is an autonomous coder that must survive structured critique before the human sees it: "fast coder" → "rigorous engineer."

**Integration path**: Route OpenCode PRs through FH `pipeline-conductor --full` as a post-generation gate. No runtime adapter needed — FH reads any file-based output.

### 2. FH + OpenHuman / Hermes: Memory → Audited Methodology

| System | OpenHuman / Hermes | FH |
|---|---|---|
| Provides | Local Memory Tree, persistent conversations, workspace config, cost dashboard, UI/UX | `tracks/`, `knowledge/`, `harvest-loop`, `phantom-quench`, `memory-hygiene` |

**N-fold mechanism**: OpenHuman/Hermes stores memory but treats it as passive recall (context stuffing). FH's harvest-loop + source-grounding turns that memory into *audited institutional process* — patterns are reviewed, grounded, and promoted. Memory becomes methodology, not just storage.

**Integration path**: FH `harvest-loop` runs on the host system's Memory Tree as its audit target. No runtime adapter needed for the methodology layer.

### 3. FH + Hermes IDE: SKILL.md as Portable Instruction Set

**Gemini's framing**: Hermes provides the "seat" (delivery, UI, local context); FH provides the "controls" (vendor-agnostic methodology). Embedding FH's SKILL.md parser into the Hermes sidecar gives **model portability** — switch from Claude to Gemini mid-task without re-teaching the UI how to run a `harness-doctor` audit. FH becomes the "instruction set" for the UI's "processor."

---

## Readiness Verdict (Layered)

**Verdict diverged by lens** — both are correct, different layers:

| Layer | Gemini verdict | Codex verdict | Synthesis |
|---|---|---|---|
| Methodology | "Fully-Prepared Hermit" — deep internal maturity, can engage | Strong claim, best-in-class in process integrity | **Peer-ready NOW** |
| Framework/Runtime | "Externally illiterate" — lacks API, event system, sandbox | "Not peer-level" — no binary, no canonical registry, no distribution | **v0.x — needs bridge layer** |

**The hermit metaphor holds, precisely**: FH has meditated deeply (adversarial review, harvest loops, calibration, sidecar orchestration). It can engage any framework on methodology. It cannot yet *integrate as a framework peer* without forcing the other system to adopt its file-heavy, CLI-centric worldview.

**What "bridge layer" means concretely**:
1. Host-agnostic CLI adapter — methodology layer runs without Claude Code automation layer
2. Canonical machine-readable registry — `plugin.json` + actual file counts synchronized, test status, compatibility matrix
3. Integration contract — OpenCode/OpenHuman calls FH gates, receives structured verdicts, persists reports

---

## Immediate Action (No Bridge Layer Required)

FH + OpenCode governance integration is executable **today** at the methodology layer:

```bash
# After OpenCode generates a PR:
# 1. Capture the diff
git diff main..HEAD > /tmp/opencode_output.diff
CHANGED=$(git diff main..HEAD --name-only | tr '\n' ' ')

# 2. steel-quench adversarial pass on changed files
# → finds behavioral edge cases, untested contracts, security assumptions

# 3. pipeline-conductor --quick on changed files
# → 4-axis gate: backward / adversarial / forward / record

# 4. phantom-quench on any new documentation claims
# → catches phantom references and stale citations
```

This requires no OpenCode API integration — FH reads files, OpenCode writes files. The protocol is the interface.

See `fh_opencode_governance_wrapper.md` for the full step-by-step guide and Stop hook automation.

### Empirical result (2026-05-31)

Applied the 3-step governance pass to OpenCode's own AI-generated `permission/arity.ts` (163 lines). CI verdict: DONE (6/6 tests pass). FH governance verdict: PENDING — 2 A-grade findings CI did not cover:

1. Short-token overflow in `prefix()` — allowlist pattern may not cover bare commands previously approved
2. `npx`, `opencode`, `claude` absent from arity table — `npx <anything>` receives the same broad `"npx *"` pattern, weakening the permission model

The delta is attributable to the methodology layer, not the model. Both passes read identical code.

---

## v2 Paper Connection

The ecosystem positioning audit surfaces a testable claim for v2:

> "A harness-structured workflow integrated as a governance layer on top of a bare coding agent produces qualitatively different outputs from either system alone — not because the model changed, but because the methodology layer enforces structured verification that the agent alone cannot generate."

This is the N-fold synergy claim stated precisely. The controlled experiment design: OpenCode alone vs OpenCode + FH governance on the same task. Measure: findings caught by governance that CI missed, rework cycles prevented.

**Empirical pilot (2026-05-31)**: Applied to OpenCode's own AI-generated `permission/arity.ts`. Governance caught 2 A-grade security-adjacent issues that 6 CI tests missed. Causal attribution is clean: same code, same model, different methodology layer.

**v2 scope**: This experiment, combined with the 3-round orchestrator-swap finding (`multi_model_sidecar_strategy.md`), constitutes novel empirical contribution — not a version update. Proposed framing:

| Experiment | Claim tested | Evidence produced |
|---|---|---|
| 3-round orchestrator-swap | Process diverges, results converge; harness is activation condition | Cross-wave delta synthesized across Claude/Gemini/Codex |
| FH + OpenCode governance | Methodology layer catches what bare coding + CI misses | DONE → PENDING verdict flip on AI-generated code |
| Tier comparison (pending) | Divergence quality stable across model tiers | Needs replication with all-premium models |

**OpenCode as citation**: The governance experiment uses OpenCode's codebase as the subject. OpenCode should be cited as the target system in the v2 experimental section. Citation candidate: the OpenCode GitHub repository + any associated paper/technical report.

---

## References

- `fh_opencode_governance_wrapper.md` — step-by-step usage guide with empirical findings
- `fh_synergy_playbook.md` — concrete FH×OpenCode/Hermes/OpenHuman workflow specs that operationalize this positioning
- `multi_model_sidecar_strategy.md` — orchestrator-swap experiment that generated this audit
- `README.md §Architecture` — 2-layer design (methodology vs automation)
- `AGENTS.md` — 6-agent registry (fact-checker added after this audit)
- FH paper (Zenodo: 10.5281/zenodo.20397565) — harness-as-durable-layer thesis this positioning extends
