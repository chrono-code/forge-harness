# Pre-Publish Surface Gate — Portable Checklist

> **Run this before making ANY repo or package publicly visible for the first time** — on any machine,
> in any repo (not only forge-harness). Public exposure is irreversible: a repo is live the instant it
> flips public and may be cached or forked before you scrub.
>
> **Order invariant: scrub before publish, never publish-then-scrub.**
>
> Highest risk: a repo **derived from internal/company assets** (operator-IP that originated in a private
> harness). Origin of this checklist: `phantom-gate` shipped public, then needed a private →
> de-company-scrub → re-public round-trip. The scrub happened *post*-publish. This checklist inverts that.

> **Companion check — structure, not leak (값 스크럽 ≠ 구조 동일):** the inverse risk to the above — when
> the artifact was *built against a de-id / MOCK proxy* and you now drop it into the **real target**, verify
> its structural assumptions (column taxonomy, join / exclude rules, schema shape) against **one real-target
> sample** *before* drop-in. A scrubbed proxy can match on values yet diverge in shape, silently producing
> wrong output. `found→extend` (read the real target, don't overwrite blind) is the mechanism. This guards
> *malfunction*, not disclosure — orthogonal to the leak scan below, run both.

## When it applies

Any first-time public action:
- `gh repo create --public` / `gh repo create ... --public`
- `gh repo edit --visibility public` (private → public flip)
- first `git push` to a **new public remote**
- `npm publish` · `python -m build && twine upload dist/*` · any registry publish

## Step 0 — Cheap mechanical pre-flags (10 seconds)

Any single hit → **stop, do the full scan below.** These catch the common internal-asset leak class.

> ⚠️ **Step 0 is a *pre-filter*, never a clean bill of health.** The `<…>` below are placeholders. If you
> have **not** filled them from your gitignored source (`.claude/rules/.public-surface-patterns` or
> `CLAUDE.local.md`), the email line still works but the grep lines match *nothing* and a "no hits"
> result here means **nothing was scanned**, not "clean". Authority for the verdict is **Step 1 PSA**,
> which reports `NOT CONFIGURED` (≠ CLEAN) when its pattern source is absent. Never publish on Step 0 alone.

```bash
# author/commit email = corp domain?  (works without config — neutral = personal/noreply)
git log --format='%ae' | sort -u

# LICENSE / README carry a private harness name or internal codename?
# (substitute your real private values from the gitignored source — literal <…> matches nothing)
grep -rIE '<private-harness-name>|<internal-codename>|<corp-domain>' LICENSE README* 2>/dev/null

# module paths encode internal acronyms?  (e.g. detectors/<internal-acronym>/)
git ls-files | grep -iE '<internal-acronym>'
```

## Step 1 — Run both gates (must both be non-LEAK)

| Gate | Catches | Pass condition |
|---|---|---|
| `/public-surface-audit --target .` | operator-private tokens: real username, corp asset names, absolute home paths, companion-store name | verdict **CLEAN** (or REVIEW with LOW-only, your call) — **not** LEAK, **not** NOT CONFIGURED |
| `/marketplace-gate` Check 5 | broad public safety: API keys, internal domains, license correctness | Public Safety check passes |

- **NOT CONFIGURED ≠ CLEAN.** If PSA reports NOT CONFIGURED, the pattern source is missing — set it up
  (empty file = explicit "nothing to protect"). A missing scan is not a clean bill of health.
- **Tooling-down = fail-CLOSED, not a free skip.** Publish is an irreversible surface, so if a gate's
  tool is **applicable but unavailable** (skill uninstalled, command errors, backend unreachable), that
  is **not** a pass — do a **manual-equivalent pass** or take an **explicit operator override**, never
  silent-proceed. (A gate is only legitimately skipped when *genuinely not-applicable* — e.g. a
  code-security pass on a repo that ships no code; grep the file list, don't assert "docs-only".)
- **Generated artifacts count.** An exported HTML/PDF carrying a username is a real public-surface leak —
  fix = regenerate from a sanitized source, not hand-edit.

## Step 2 — If LEAK: scrub on a PRIVATE copy, then publish

Do **not** "publish then fix". If the repo is already created, keep it **private** until clean.

1. Keep/flip the repo **private** (`gh repo edit --visibility private` if already created).
2. Full de-identify: corp email → neutral, private names/codenames → neutral handle, internal module
   paths → generic, strip internal docs/logs. Re-run Step 1 until **non-LEAK**.
3. Only then flip public / push / `twine upload`.

## Step 3 — Record (if this was a near-miss or a real catch)

A pre-publish catch is a process win worth logging:
- forge-harness operator → `tracks/_meta/fh_signal_{date}_{source}.md` (or `field-harvest`).
- A recurring leak class → candidate `#rule-candidate` (tighten the mechanical pre-flags in Step 0).

---

**Done when**: Step 0 pre-flags clean (or escalated to full scan) · Step 1 both gates non-LEAK ·
publish executed *after* the gates passed, never before.

## Read it as a reader, once, before it goes out

Not a correctness check — the code can be right and this still fails. Open the thing a **reader**
opens and look at what they see:

- [ ] Is the **conclusion in the first ~8 lines**, or is it buried under banners, metadata and
      "how to read this table"?
- [ ] Does the **body survive the template**? (measured case: 3 lines of content under 21 lines of
      fixed boilerplate)
- [ ] What is the **last impression**? (measured case: the final line told the reader they could
      skip it)
- [ ] Does it say **what the reader should do next**?

A lens already exists — `/sim-conductor` A-1 (`beginner` cold-read) — or just render it and read it.

🟥 **Why this is a human step and not a scan**: a static check catches what is ABSENT, never what is
UNREADABLE. Two independent measurements arrived here the same day (2026-08-17): one harness axis
found 12 readability defects with **0** caught by static scanners; a third-harness review
(`harness_incubator_doctrine.md` §4-c) found a shipped report whose answer to "did it pass?" sat in
the fourth bullet. The pre-commit hook prints an advisory reminder when a reader-facing surface is
staged — it reminds, it does not certify.
