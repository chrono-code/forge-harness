# FH Starter Profile — Mode C (plugin only, no clone)

> **The one opinionated front door.** FH has 39 skills and a full hub you can clone — but you
> don't need any of that to get value today. This profile is the *single strong default*: one
> install command, a curated first-five skills, and a zero-install governance gate. Pick up the
> rest later if you want it.
>
> This is **Mode C** (see `knowledge/shared/rules/modes_and_value.md`): you install the plugin/skills only,
> you do **not** clone the hub. That trade-off is spelled out under *What Mode C does not include*.

---

## 1. Install — one command

**Prerequisite**: Claude Code CLI (`claude --version`).

```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness
```

That's it — no clone, no shell hooks, no machine setup. Open Claude Code in *your own* project and
the skills are available as slash commands.

```bash
cd ~/your-project && claude
```

## 2. Governance gate — zero install (no plugin needed either)

The core FH value — **"pass → accelerate"**: code that clears the gate ships faster. You can run it
on any file with nothing installed but `npx`:

```bash
npx --package @chrono-meta/fh-gate fh-gate                    # default: Claude backend
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate   # Codex backend
# → FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE
```

This wraps any coding agent (Claude, Codex) as a post-generation governance gate. It is the single
highest-leverage thing to try first if you only do one thing.

## 3. The opinionated first five (start here, ignore the other 28)

A new user dropped into 39 skills stalls. These five cover the common path; reach for the rest only
when a real need shows up.

| Skill | Run it when | One line |
|---|---|---|
| `/plugin-recommender` | "what tools should I even use?" | Discovery — classifies tools, checks token cost |
| `/context-doctor` | session feels slow / token-heavy | Generates `.claudeignore`, flags large files, `/clear` timing |
| `/harness-doctor` | "is my setup sane?" | L1–L4 structure diagnosis + prescription |
| `/goal-quench` | before executing a risky/long task | Gated execution — the acceleration gate in skill form |
| `/frontier-digest` | "what's new out there?" | External/frontier trend cross-reference |

Natural language works too — you don't need to memorize slash commands. "manage my context",
"recommend a plugin", "check my harness structure" route to the same skills.

## 4. What Mode C does *not* include (honest boundary)

Plugin-only install gives you **Layer 2 (the skills)**. It does **not** give you **Layer 1**, which
only activates when you clone the hub (Mode A/B):

- **No active onboarding cascade** — no greeting-triggered 5-skill auto-run. You invoke skills yourself.
- **No acceleration baseline** — no zshrc notification hook, no sentinels, no weekly-audit schedule,
  no 4-axis pre-commit gate. Those are hub-internal infra and are deliberately not shipped to Mode C.
- **No automatic harness signals** — history accumulation happens on *your* project side; FH won't
  prompt you. (FH absorbs Mode-C contributions through issue monitoring + PR cadence, not a daemon.)

If you later want Layer 1, clone the hub and run `/install-wizard` — the full path. The README's
"Get started in 2 minutes" covers it.

## 5. Want to go further?

- **Clone the hub** (Mode A/B) → persistent cross-project knowledge, `tracks/`, the compounding loop.
- **Contribute back** → a Mode-C PR is exactly the external validation FH is looking for. Open an
  issue or PR on `chrono-meta/forge-harness`.

---

*Design note: this profile follows the frictionless-distribution + opinionated-front-door pattern
seen in field harnesses like [gstack](https://github.com/garrytan/gstack) — a single strong default
as the public entry point, full meta-flexibility kept behind it.*
