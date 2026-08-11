---
name: fh
description: Renders the FH hub map on demand — the door menu, a starter set of skills, and the most-used trigger phrases — without requiring a greeting. State-aware; composes live candidates from the session card and tracks.
user-invocable: true
allowed-tools: ["Read", "Grep", "Glob"]
# /fh is read-only by construction: it detects state and renders a map. It was the only one of
# the 40 SKILL.md files with no allowed-tools declaration at all. Read/Grep/Glob is the full set
# its body needs — no Bash, Write, Edit, or Agent appears anywhere in it.
---

# /fh — hub map on demand

The greeting flow (CLAUDE.md §Active Onboarding) fires on greetings, start intents, new-task and
discovery utterances — but it is salience-dependent, once-per-session, and skipped entirely when the
user opens with a task. This command is the **explicit, deterministic** route to the same map: slash
autocomplete discoverability, invocable mid-session any number of times, no reliance on the model
catching a phrase. Same map, different guarantee — /fh does not claim a gap in *which utterances*
fire onboarding; it closes the *how-reliably-and-when* gap.

## Execution Steps

### Step 1. State detection (reuse, don't re-derive)

Run the same mechanical branch test as §Active Onboarding: session files / mapped project tracks
under `tracks/` (underscore dirs don't count) → new / returning; FH-dev state (session card ·
open `fh_signal_*` · `CLAUDE.local.md`) → operator. Do not invent a separate test — the canonical
branch rules live in CLAUDE.md §Active Onboarding and `fh_detail_protocols.md` Step 2.

### Step 2. Render the door menu

Output the door skeleton for the detected branch **verbatim from the canonical source** (CLAUDE.md
§Active Onboarding — including the 🐿️ same-line welcome). Compose door ③ / 🔧 candidates live from
the session card and CATALOG, exactly as the greeting path would.

### Step 3. Render the quick map (below the menu)

- **Starter set**: the curated first-five from `templates/starter_profile.md` (read it — do not
  hardcode a list that can go stale), one line each.
- **Most-used phrases**: 5-8 rows from CHEATSHEET §4 (universal phrases + the full-autonomy
  contract line).
- If cwd is a mapped field project: one line noting "진단해줘" routes to the Field-Harness
  Diagnostic here.

### Step 4. Hand off

End with "pick a door, say a phrase, or just state your task". Do not auto-run anything — this
command is a map, not a dispatcher.

## Done When

| Condition | Check class |
|---|---|
| Door menu rendered for the correct state branch (new/returning/operator) | mandatory-pass (output exists; branch test is the mechanical §Active Onboarding rule) |
| Menu text matches the canonical skeleton (no drifted fork of the door labels) | measured — at render time, diff the rendered labels against CLAUDE.md §Active Onboarding (the render-vs-source diff IS the check; the canonical-side 4-axis guard only protects the source, not this skill's rendering) |
| Starter set and phrases sourced from their canonical files, not hardcoded | judged — paired with `/phantom-quench` back-trace (each rendered item must exist in its source file) |

## Trigger Phrases

- `/fh` (primary — explicit slash command)
- "show me the menu" · "메뉴 보여줘"
- "what can this hub do" · "여기서 뭘 할 수 있어"
- "지도 보여줘" · "skill map"

Natural-language triggers deliberately overlap the §Active Onboarding discovery triggers — both
routes render the same map from the same canonical source, so whichever route catches first, the
outcome is identical (collision-safe by construction, not by luck). Baseline Step 0.5 trigger-probe:
due at the next harness-doctor run (this skill is a routing surface — obligation per CLAUDE.md
§New Skill Creation Pre-Commit Gate).

## Constraints

- Never duplicates the menu skeleton into this file — CLAUDE.md is the single source; this skill
  only *renders* it. (The 2026-07-17 audit found label-drift risk across duplicated menu copies;
  this skill must not add a third copy.)
- Read-only: no state writes, no dispatch.
