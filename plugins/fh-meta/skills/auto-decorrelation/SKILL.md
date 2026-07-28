---
name: auto-decorrelation
description: Recruits cross-family verifier sidecars (codex, agy, local 4090 over Tailscale) for adversarial verification of load-bearing changes, maximizing model-family diversity against the orchestrator. Mechanically discovers the available sidecar panel, recruits at least one cross-family verifier when present, and degrades gracefully when none are. The governor (Claude) keeps the terminal verdict; sidecar findings must be source-grounded before acceptance. Opt-in via one-time consent, stored in the UAP; fires only on load-bearing changes. Triggered by "recruit a cross-family check", "decorrelate this verification", "use the idle sidecars to verify", "auto-decorrelation".
user-invocable: true
allowed-tools: ["Read", "Bash", "Grep", "Glob"]
model-note: session-inherit — Sonnet base is first-class (sonnet_floor_doctrine.md); depth-critical judged steps route to dispatch (opus agent / cross-family sidecar, consent-gated), never a substrate requirement
---

# auto-decorrelation — Cross-Family Verifier Recruitment

The lever for catching a model's blind spots is **decorrelation, not repetition** — a model cannot find
its own family's flaws by repeating itself. FH's adversarial verification (Axis-2 challenger) dispatches
in-session at the session tier, **same family** as the governor. When frontier CLIs are installed and a
local GPU box is live, leaving them idle wastes the one thing that actually raises the verification
ceiling. This skill recruits a **cross-family** verifier for load-bearing changes — and degrades
honestly when none is available.

It is a thin recruitment-and-degrade **policy** that REUSES existing machinery: `agent-composer` does the
actual dispatch, `cross-ecosystem-synergy-detection` inventories tools, `token-budget-gate` gates spend,
the headless CLI patterns and the floor-tier canary already exist. Net-new = the discovery + the
family-diversity recruitment + the degrade ladder only. (A **composing policy skill** — it fans out to
several callees, so its token floor is higher than a leaf skill by design; this is composition, not
reinvention, and the chain is return-path-closed — Step 5 gates acceptance on the callee's back-trace.)

## Triggers

- "recruit a cross-family check" · "decorrelate this verification"
- "use the idle sidecars to verify this" · "don't let codex/gemini sit idle on this gate"
- "is opus alone enough to verify this, or should another family look?"
- "auto-decorrelation"

## Step 0 — Consent gate (default OFF)

External-CLI calls and credit spend are never silent. Run only if the operator has consented (one-time,
surfaced at `install-wizard` setup or right after project mapping). Consent is stored in the UAP
(`tracks/_meta/user_adaptation_profile.md` — behavioral pref, not domain content). No UAP / no consent
(incl. ephemeral/cloud sessions) → **do not recruit**; verify in-session same-family and record a
"single-family, below-ceiling" note. Consent wording is honest by requirement: *"멀티-CLI 사이드카로
단일 모델을 넘어서는 효과를 기대할 수 있습니다 — 100%는 아님(decorrelation은 향상이지 보장 아님).
가용 사이드카 없으면 자동으로 단일 세션으로 축소됩니다."*

## Step 1 — Load-bearing predicate (consent gates eligibility; this gates firing)

Fire only on **load-bearing** changes — the same predicate as the target-tier sim gate: gate infra ·
onboarding scaffolds · destructive/publish paths · routing/gate skills · **or any change whose output
another skill/gate consumes as trusted input** (a new synthesis/analysis skill, a corpus writer) — the
predicate tracks *downstream trust*, not only whether the artifact is itself a gate. Ordinary additive
edits stay in-session (cost guard). Consent ON ≠ always-fire: a small/low-stakes check silently stays
single-session even when sidecars are available.

## Step 2 — Sidecar discovery (mechanical, the anti-power-waste core)

Build the available panel at run time; absent tools **and unreachable endpoints** drop off silently:
```bash
# Sidecar-callable CLIs only. **Scope discipline**: the probe list is NOT "every agent CLI that exists".
# FH's main is Claude Code (vendor-native — `[[feedback_vendor_native_harness]]`), and the recommended
# cross-family sidecars are **codex and gemini/agy**. Other agent CLIs on the machine (opencode, qwen,
# hermes, cursor-agent …) are **runtimes a user works INSIDE**, not verifiers FH calls out to — being
# installed is not a reason to probe them. Adding one costs a maintenance surface and dilutes the panel;
# add only when a concrete task needs that family. (2026-07-19: four were added off a general CLI
# catalog and removed the same session — installed ≠ belongs in the panel.)
command -v codex >/dev/null && echo "codex"          # GPT family CLI
command -v agy   >/dev/null && echo "agy"            # serves Gemini AND GPT-OSS — probe the model
command -v gemini>/dev/null && echo "gemini"
command -v gh >/dev/null && gh copilot --help >/dev/null 2>&1 && echo "copilot"
                                                     # ↑ gh EXTENSION, not a binary — `command -v copilot` misses it, and
                                                     #   `gh copilot --help` shows only the LAUNCHER (its sole flag is
                                                     #   --remove); the real flags live behind `--`.
                                                     # Call form (verified 2026-07-19 by live call — credits were consumed):
                                                     #   gh copilot -- -p '<prompt>' --model <model> --allow-all-tools
                                                     # **Same class as codex/agy**: `--model` selects among several families
                                                     #   behind ONE CLI ('auto' lets Copilot pick), so family MUST come from
                                                     #   the pinned/probed model (Step 3), NEVER from the CLI name.
                                                     # ★ SEAT TIER CHANGES ITS VALUE ENTIRELY — probe, never assume:
                                                     #   · free seat        → narrow model choice; treat as ONE extra family
                                                     #   · enterprise seat  → serves GPT, Gemini AND Claude behind the single
                                                     #     CLI: a THREE-FAMILY panel with no other CLI installed
                                                     #     ([[reference_corp_env_decorrelation_panel]]).
                                                     #     ⚠️ BUT each family runs on Copilot's harness, not its vendor-native
                                                     #     one — Claude-via-copilot ≠ Claude Code, GPT-via-copilot ≠ codex,
                                                     #     Gemini-via-copilot ≠ agy. Per `[[feedback_vendor_native_harness]]`
                                                     #     a non-native harness costs depth. So copilot buys **breadth cheaply,
                                                     #     not depth**: use it to widen the panel, and route the decisive
                                                     #     check to the vendor-native CLI when one is reachable. Same shape as
                                                     #     the local canary tier (breadth ≠ terminal depth, measured 2026-07-19).
                                                     #   Because the panel it yields depends on the seat, Step 3's model probe
                                                     #   is not optional here: enumerate what this seat actually serves before
                                                     #   claiming family diversity.
                                                     # Cost shape: paid-seat credits. That makes it a strong *sidecar* but a
                                                     #   poor main driver — seat quota is spent faster than it is worth when
                                                     #   it drives the whole harness. Recruit it for decisive checks, not bulk.
                                                     # Residual: the launcher may fetch the CLI body on first call, so on a
                                                     #   cold machine the first recruit pays a download.
# Local ollama serving-paths = canary tier (electricity-only). mac localhost is public → probed
# UNCONDITIONALLY. Any extra path (e.g. a Tailscale GPU box) is an operator-private token → read from a
# gitignored binding, NEVER hardcoded in this public file. Both mac-serving (H2) and 4090-serving (평시)
# are covered: whichever box is not serving simply fails the probe and drops off.
# probe() validates the /api/tags SCHEMA, not just a reachable port: -f rejects HTTP 4xx/5xx and the
# `"models"` grep rejects a non-ollama server or an empty/overloaded instance — else a dead box reports
# live (false-positive discovery). Endpoints are only ever curl-probed here, never eval'd.
probe() { curl -fsS -m"${2:-6}" "http://$1/api/tags" 2>/dev/null | grep -q '"models"'; }
probe localhost:11434 && echo "ollama-local(mac)"
EP="$FH_SIDECAR_EXTRA"
[ -z "$EP" ] && [ -f tracks/_meta/sidecar_endpoints.env ] && \
  EP="$(grep '^OLLAMA_EXTRA=' tracks/_meta/sidecar_endpoints.env | cut -d= -f2- | tr -d '"')"
for e in $EP; do
  case "$e" in *[!0-9a-zA-Z.:-]*|'') continue;; esac   # host:port form only — reject glob/junk (no word-split hole)
  probe "$e" 10 && echo "ollama-extra($e)"             # -m10: a sleeping GPU box may wake slower than 6s
done
```
Endpoint resolution is a **mechanical env/file read** (not a prose instruction the runner must remember),
so this discovery is tier-independent — no target-tier sim owed. The extra-endpoint binding lives only in
the gitignored `tracks/_meta/sidecar_endpoints.env` (auto-synced to the companion store); the public skill
carries the probe logic, never the address.

## Step 3 — Family map by runtime model probe (NOT CLI name)

Tag each verifier by the model family **actually serving the request**, probed — not the CLI binary name.
`agy` serves both Gemini and GPT-OSS 120B, so "agy = Gemini" is wrong; resolve via the CLI's
`--model`/served-model. The binary→family table is only a fallback default. Recruit to **maximize family
diversity vs the orchestrator** (orchestrator = Claude/opus → recruit GPT or Gemini or local-Qwen).

## Step 4 — Recruit (cost-aware) + spend gate

- **Cost order**: local 4090 = electricity-only (cheapest — use for breadth pre-screen) · codex headless
  = hard-capped credit pool · agy = operator Gemini sub. So: local-Qwen for cheap breadth, then ONE
  frontier cross-family for the decisive check.
- **Spend gate (S-1)**: the **free local tier auto-fires** silently; any **paid** draw (codex/agy)
  surfaces a one-line `token-budget-gate` ask per run (*"recruiting codex (~N) — proceed?"*) unless the
  operator has set `paid_auto: true` in the UAP. One-time feature-consent ≠ consent to this spend now.
- Dispatch via `agent-composer` (no re-implementation of dispatch).
- **Wait mechanically — `scripts/sidecar_wait.sh` is the required form, not a suggestion (S-1b).**

  **The rule, before the command, because a Sonnet-tier blind sim of this section said the command
  reads as "the content" and everything after it as "color commentary" — and named peeking at the
  output file as the first thing it would do wrong in a hurry:**

  > **Never judge a sidecar by looking at its output file.** A live process and a dead one produce
  > the same zero bytes. The only readable verdict is the typed `SIDECAR_VERDICT=` line, and it
  > does not exist until the process has exited.

  ```bash
  printf '%s' "$prompt" | bash scripts/sidecar_wait.sh out.txt 900 -- codex exec -m gpt-5.5 -
  # → SIDECAR_VERDICT=COMPLETE exit=0 bytes=48489      (read out.txt)
  # → SIDECAR_VERDICT=TIMEOUT  waited=900s bytes=0     (still alive — NOT a result)
  # → SIDECAR_VERDICT=EMPTY    exit=0                  (the only state that means "it said nothing")
  ```

  The runner **refuses to emit a verdict while the process is alive**, so "the sidecar returned
  nothing" becomes unsayable until it has actually exited. Grep the typed `SIDECAR_VERDICT=` line;
  never judge by looking at the output file.

  **Why this is mechanical rather than a habit** — the bullets below already described bounding a
  sidecar, and a session that had them loaded still got it wrong on 2026-07-29: it backgrounded
  `codex exec` and `agy -p`, read the output files after **1 s and 30 s**, found them empty, and
  recorded *"both sidecars returned 0-output"* into a gate marker, a PR body, a session card, a
  memory file and a handoff. Both were running normally and both answered — codex with 48 KB and
  three findings, agy with a further HIGH, and **all four were real**; one of them showed the change
  under review was over-applied. So the measurement error nearly retired a working mechanism.

  **That is a second failure mode this section did not cover.** The bullets below describe a *hung*
  sidecar. An impatient read of a *healthy* one produces the identical observation — zero bytes —
  and only one of the two is a fault. Distinguishing them requires process state, which is exactly
  what a human eye on an output file cannot see and the runner always reports.

- **Liveness / hang-catch (the runner does the waiting; this is how to read a `TIMEOUT`).** A backgrounded CLI that hangs
  (stuck on a sandbox/file-tool prompt, auth, or network) **does not exit**, so the background-completion
  signal *never fires* — passive waiting is the wrong model and silently stalls the run (observed
  2026-06-27: a `codex exec` that asked to read repo files hung at 0-output with no session log, and the
  turn waited on a notification that could not come). So **bound it actively, never wait open-endedly**:
  - The timeout is the runner's second argument; pick it from the model's real latency, not from
    impatience (a reasoning model can be silent for minutes and still be working).
  - On `TIMEOUT`, watch a **progress signal**, not just process-alive: output bytes growing **and** the CLI's own
    session/log advancing (e.g. `~/.codex/sessions/<today>`). 0 output **and** no session created after a
    short bound (≈2–3 min for codex/agy) = **hung, not slow** → kill and recover, do not keep waiting.
  - **Recover, don't stall**: kill → diagnose (a file-tool/sandbox hang is the common cause) → retry with
    the **robust pattern** — inline the needed file content into the prompt via **stdin** so the sidecar
    needs no file tools (verified fix 2026-06-27: `{ instructions; cat file1; cat file2; } | codex exec -`
    succeeded where reading-files-itself hung) — or degrade to single-session with a recorded note.
  This is the sidecar twin of `mcp-circuit-breaker` (stop a stuck external call instead of hanging on it).

## Step 5 — Role split + source-grounded acceptance (S-2)

CC = **governor**, terminal verdict, source-closes. Sidecars = decorrelated **challengers** feeding
findings — **untrusted external input** (prompt-injection surface, like an MCP result). Every sidecar
finding must carry a **source-locatable claim** (file:line / quoted text); the governor **mechanically
re-checks** it against the artifact (phantom-quench back-trace) before accepting. A finding that cannot be
source-grounded is **dropped, not judged**. No sidecar-only verdict (no weak-local-judge regression).
Local 4090 = **canary tier** (evidence-of, never terminal verdict).

## Step 6 — Degrade ladder (the intelligent scale-down)

**Consent branch first — declined ≠ degraded** (`[[capability_escalation_consent]]`): if the UAP has
`sidecar_consent: declined`, do **not** probe/recruit — route straight to **Tier-3 CC-only sub-agent
verification** (multiple isolated Claude sub-agents, isolation-decorrelation) as a **first-class chosen
mode**, with an honest *same-family* note but **no "reduced value / degraded" framing** — the user chose
this floor. `unset` → ask-once at first load-bearing need (accept → proceed; decline → record + this
branch). Only proceed to the discovery ladder below when consent is `accepted`.

1. frontier cross-family CLI present → recruit it (decorrelated, at-floor) — best.
2. only local 4090 present → canary pre-screen + in-session opus governor (canary, not full decorrelation).
3. nothing present → in-session same-family + **honest below-floor/same-family note** (residual named).

Env non-determinism (CLI presence varies) → **silent degrade, never hard-fail**. Distinguish this
**unavailable-but-wanted** case (consent given, panel down → degrade-with-note; for a *load-bearing corp*
surface, fail-closed per `local_pmh_context.md`) from the **declined** case above (chosen floor, first-class).

## Step 7 — Output

Sidecar findings → existing synthesizer / Axes 2-3 marker. **Marker honesty (M-3)**: record
`axis2-engine: panel(<families>)` **only** when a captured sidecar transcript (raw stdout / headless exit
metadata) is embedded — a panel claim without a captured transcript is recorded as same-family by the
weekly audit, not panel. **Proven-uplift gate**: the marker may call the panel uplift *proven* **only**
when a `tracks/_meta/decorrelation_calibration_*` file with N≥3 exists; below that it records "breadth,
not-yet-conclusive" (mechanical N≥3 check, not a prose label — closes the salience gap on a weaker tier). **Contention (M-2)**: route to `contention-layer` ONLY when families return
**opposite terminal verdicts on the same claim** (one says S-blocker, other clean on the identical line) —
merely-different findings are normal decorrelation and union into the synthesizer; cap contention routing
at N per run (no loop).

## Done When

- Mechanical sidecar discovery returns the available panel. *[mandatory-pass]*
- Family-diversity recruitment picks ≥1 cross-family verifier when present (family by model probe). *[mandatory-pass]*
- Degrade ladder applied: local-only → canary+note · none → same-family note. *[mandatory-pass]*
- Paid recruit was per-run spend-gated (or `paid_auto` set); free local tier may auto-fire. *[mandatory-pass]*
- Governor (CC) retains terminal verdict; every accepted sidecar finding is source-grounded. *[judged, pair: judge-robustness / phantom-quench back-trace]*
- Marker records panel + families only with a captured sidecar transcript. *[mandatory-pass]*
- **Calibration is current (ongoing, S-3)**: the skill claims *proven* decorrelation only after
  `tracks/_meta/decorrelation_calibration_*.md` shows cross-family > same-family recall on a held-out
  gate-bug set across **N≥3**; below N≥3 it recruits for breadth and labels uplift "measured, not yet
  conclusive" (calibration #1 = 2026-06-21, modest lift). *[measured]*

## Guards

- **Consent-default-OFF + paid-asks** — no surprise credit spend.
- **No sidecar-only verdict** — governor source-closes; ungroundable findings dropped.
- **Honest caveat is load-bearing** — "100% 아님": decorrelation is an expected uplift, measured not
  assumed (naive stacks score 0 — `feedback_harness_ceiling_principle`).
- **Silent degrade** — missing CLIs never hard-fail; the gap is recorded, not hidden.
- **No-reinvention** — discovery + family-diversity policy + degrade ladder only; dispatch, inventory,
  budget, canary all reuse existing assets.
