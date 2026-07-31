# Operational Adaptation Loop — User-Tuned Self-Optimization

Self-healing in FH today has two shapes: **FH-self-dev** (Mode D, the 4-axis auto-gate improving FH's own assets) and **reactive** (`verify-bidirectional`, a one-shot baseline update when the user pushes back). Both leave a gap: there is no **standing, per-user, operational** loop that tunes FH's everyday behavior to the individual during normal field use — and feeds the generalizable part of that tuning back to the origin.

This loop fills that gap. It is deliberately thin: it **reuses** existing parts and only adds a profile convention + a generalization gate.

| Concern | Existing part (reused — NOT rebuilt) | What this loop adds |
|---|---|---|
| Reactive correction | `verify-bidirectional` (per-correction baseline update) | A standing, aggregated profile (not one-shot) |
| Reverse-PR funnel | `field-harvest` Mode A (field pattern → FH PR) | Feeds it generalizable UAP entries |
| Outcome vocabulary | `operations.md` `subagent_invocations_log` (`accepted`/`rejected`/`sustained` + 60/40 gate) | Same vocabulary, extended from sub-agents to **skill proposals** |

## User Adaptation Profile (UAP)

**Location**: `tracks/_meta/user_adaptation_profile.md` — **local / gitignored**. It is a **personal asset**, never committed to the public mirror (single-source / drift guard, per `modes_and_value.md`). Mode D: mirror to the companion store's `tracks-meta/`.

**Records behavioral preferences ONLY** — never domain work content (protects reference-asset identity):
- **Skill-proposal outcomes** — per skill: `accepted` / `rejected` / `sustained` with counts (same 4-category vocabulary as `operations.md`).
- **Preferred execution tier** (S/M/L/XL), language, working cadence.
- **Capability-escalation consent** — `sidecar_consent` + `floorup_consent` (`accepted`/`declined`/`unset`),
  per the **Capability-Escalation Consent Protocol** (`knowledge/shared/harness-core/capability_escalation_consent.md`).
  Settled at onboarding (install-wizard) or ask-once at first need; `declined` → route to the floor
  (Sonnet / Tier-3 CC-only sub-agent as a *first-class* mode), surface as recommendation only, **never re-nag**.
- **Recurring friction points** (aggregated from `fh_signal_*`).
- **Muted nags** — cadence reminders the user repeatedly declines.

## Operational adaptation pass (field-session close)

Runs at field-session close, **riding `field-harvest` Mode B** — no new trigger, never an interception. One pass per session.

- **READ** (session start / proposal time): apply UAP — suppress a skill proposal rejected 3+ times, apply any **standing consent** granted per §Consent promotion below (an `accepted` record on its own still carries **no** positive auto-action — acceptance alone never auto-runs anything; only a granted standing consent does), default to the preferred tier, mute cadence nags the user always declines, and **apply capability-escalation consent** (`sidecar_consent`/`floorup_consent` `declined` → route to the Sonnet / Tier-3 floor, recommend-only, no re-nag; `unset` → ask-once at first need per the consent protocol). (Tier note: the UAP tier default is a session-depth setting; the Mode D model notice is model-only + advisory and never overrides it.)
- **WRITE** (session close): update outcome counts + new friction points.

## Consent promotion (accept-side) — repeated approval must offer to stop asking

The suppression rule above is **one-directional**: repeated *rejection* changes FH's behavior, repeated
*approval* changed nothing, so a user who approves the same class every time keeps paying the same
prompt forever. That asymmetry is the defect this section closes. It is the general-user form of the
elastic-granularity principle already granted to the operator (`feedback_hitl_elastic_granularity_cto`):
**the floor is fixed, the approval grain is not.**

**Promotion is not the mirror image of suppression.** Rejection suppresses a *proposal* — a wrong
suppression costs one manual re-ask. Acceptance authorizes an *action* with the user absent — a wrong
grant has side effects. Symmetric machinery over asymmetric stakes is itself the error (cross-family
review, 2026-07-29). So the accept side carries three things the reject side does not: an **explicitly
scoped** class, an **expiry**, and a **separate confirmation** that is not the same "yes" that approved
the action in front of the user.

**Classes are declared, never minted at runtime** (this is what makes the trigger mechanical). A class
is promotion-eligible only if it exists in the **consent-class registry**, `tracks/_meta/consent_classes.yaml`,
declaring: `owner` (gate/skill) · `mode` · `target scope` · `capabilities` (read / local-write /
network / dispatch / repo-mutation) · `sinks` (what downstream surface the action can reach). A session
may **propose** a registry entry (HITL, like any asset) but may **not** invent one mid-run and start
counting against it. *Origin: without a registry the guard below did not bind — the class could simply
be recorded over-broad at birth (`sim-conductor` rather than `dispatch read-only sim on a local
artifact`), and no after-the-fact widening rule can catch a class that was born wide.*

**Registry authorship is itself a capture surface** (cross-family round 2): closing runtime minting
still leaves the agent drafting a broad entry, framing it as housekeeping, and later enjoying the
approved breadth. So a proposed entry is promotion-eligible only after it carries (a) an explicit
`excludes:` list of neighbouring actions the class must **not** cover, (b) 2+ **adversarial examples** —
concrete actions a reader might assume are inside and that the author asserts are outside — and (c) a
review by something other than the proposing session (the human, or a cross-family auditor). A class
definition is reviewed as a **grant of future autonomy**, not as a config row.

**Storage form (operator decision 2026-07-31)**: `standing_consent` — and every other machine-read UAP
field — lives in the UAP's **YAML frontmatter**, the `---` block at the top of the file, parsed whole by
the canonical loader. **Prose in the body is never read by a script**, and a grant written there is a
**fail-closed error**, not an absence: an unread grant is not an absent one. Why the form changed: the
previous reader line-sliced a `standing_consent:` key out of markdown, and each special case it closed
opened the next (loader-identity → nested key → explicit-key → comment-vs-heading, three in one day).
The root was storing a machine field in markdown, where `#` and indentation mean different things to
the two languages; frontmatter removes the slicing *decision*, because "the first `---` block" has one
referent. Record the human-readable grounds in the body, the value in the frontmatter.

**Mechanical floor**: `scripts/consent_registry_check.sh` — joins `standing_consent` against the
registry and enforces schema, eligibility soundness (a class naming an irreversible or unlisted sink
**cannot** declare itself promotable), registration, expiry, and recorded scope. Missing registry → N/A
+ promotion disabled; unparseable → fail-closed. Run it before trusting any grant; the prose above is
the salience layer over this check, not the enforcement. Anchor: `scripts/test_consent_registry.sh`
(64 lanes, incl. the `F*` storage-form lanes). Four mutants were run against it — each false-clean
net, the fence regex, and the falsy-laundering guard — and each turned its lanes red, so the green is
measured rather than assumed. Cross-family review found the first draft's green was partly vacuous
(one lane called `ok` in both branches; three others passed via a path other than the one they named).

**Trigger**: the same registered class recorded `accepted` **3 consecutive times**, counted across
sessions from the UAP outcome log. Refinements that keep the count honest:
- *Consecutive* means consecutive **within that class's own entries**; other classes interleaved do not
  break the streak, a single `rejected` or `modified` does. An approval the user altered before granting
  is logged `modified`, never `accepted`.
- **Only a promotion-eligible approval prompt counts** — one user gesture, one entry. **Retries of the
  same operation count once**, and one "yes, do those three" is **one** approval, not three. Ordinary
  supervised retry ("응, 다시 해봐" ×3) is not durable consent and must never reach the threshold.
- The running count is **visible to the user at each approval** (`1/3` · `2/3` · `3/3`), so the offer is
  never the first time they learn a streak was being tallied.

**Action — offer once, with the evidence in the offer**:

> "`<class>` 을 3번 연속 승인했다 (`<date1>`, `<date2>`, `<date3>` — 각각 `<one-line what was approved>`).
>  범위: `<mode · target · capabilities · sinks>`. 앞으로 `<N>`일간 안 묻고 진행할까?
>  (언제든 '다시 물어봐')"

The offer **quotes the three approvals and the exact scope**; a grant the user cannot audit is not
consent. Then:

- **granted** → write `standing_consent: <class>: {granted: <date>, expires: <date+N>, effects: [...]}`.
  Later instances run unprompted, each **states in one line what it did**, and each **appends a durable
  entry to `tracks/_meta/consent_runs.log`**. *Post-action chat notice is not a control* (cross-family
  round 2): a line the user scrolls past has stopped the prompt without replacing it. The chat line is
  courtesy; the log is the audit surface, and it is the reason standing consent may cover only actions
  that are **recoverable and locally reviewable** — an unrecoverable action was already excluded by the
  floor, and an unreviewable one is excluded here.
  **Expiry is not optional** — at expiry the consent lapses to `unset` and the class is asked again;
  standing consent is a renewable lease, not a transfer of the decision.
- **declined** → write `declined`. **Never ask again for that class version** — the same no-re-nag rule
  as muted cadence reminders. *Scoped to the version, not forever*: a user may decline because the
  timing was wrong, and permanent suppression with no renewal path is its own defect. A re-offer is
  allowed only when the class is **materially narrowed** (a new registry version with strictly smaller
  scope) or the user asks. Re-offering the same scope is a nag.
- Revocation is always available and never negotiated: "다시 물어봐" / "revoke" → `unset`.

**Floor — what never promotes (규약; this is the whole constraint)**: promotion is available only where
the *protocol still passes*. Applicability is decided **mechanically, from the registry entry — never by
the running session's judgment**, because the session that wants to stop being asked is the worst
possible arbiter of whether it may. A class never promotes, at any count, when:

1. its `sinks` include an **irreversible surface** — publish / go-public, delete, history-rewrite, or any
   surface guarded by a fail-closed Irreversibility gate (`CLAUDE.md §Irreversibility Gates`); **or**
2. it **feeds, queues, or enables** such a sink even though it does not itself cross one — **sink
   tainting**. Reversible steps compose into irreversible outcomes: "edit workflow config" + "write
   release notes" + "create local commit" are each locally reversible, and a CI workflow publishes the
   result. Taint propagates along that chain; the floor is inherited, not re-derived per step; **or**
3. its irreversibility is **unknown or not yet classified** → **no promotion, ask**. Unknown is not
   reversible. (An unregistered class is by definition unknown, which is why 1–3 collapse to a single
   mechanical test against the registry.)

Their cost is not the prompt, it is that the thing cannot be undone — grain-independent by construction.
**The promotion offer itself is HITL**: this section grants no path to auto-approval the user did not
answer "yes" to once, knowingly and in scope, which is why it does not contradict the "acceptance alone
never auto-runs" rule above.

**Degrade direction (fail-closed), three ways**: no UAP (ephemeral/cloud session, wiped profile) → **no
promotion, keep asking**. No registry entry → **no promotion, keep asking**. Expired or unparseable
record → **`unset`, keep asking**. A missing consent record is never `granted` — an absent measurement is
not a yes.

**Named residual — the ledger is self-attested (cross-family, 2026-07-29, HIGH, NOT closed).** The UAP
outcome log is written by the same agent that benefits from fewer prompts, and it is gitignored, so there
is no ordinary review trail. Nothing in this section fixes that; the honest mitigations only *narrow* it:
consent events are **append-only** (an entry is superseded, never edited or deleted), the offer must
**quote the three approvals verbatim** so a user can catch a fabricated streak at the one moment it
matters, and every unprompted run **announces itself**. A real fix requires the consent record to be
produced by the approval channel rather than by the consuming agent — outside this rule's reach. **Until
then, treat every standing consent as auditable-by-the-user-only, and never widen the mechanism's scope
on the assumption the ledger is trustworthy.**

**Consent binds to the action's SHAPE, not its label** (found by blind target-tier sim, 2026-07-29):
a class name is a string, and the action behind it can change after consent is granted. A sim that
merely returned a report when you said "stop asking" may, ten sessions later, write into shared memory
and trigger a downstream commit — same label, different blast radius, HITL skipped. So a grant records
**what it was granted for**: the owning gate/skill, and the set of **effect classes** the action had at
grant time (reads · local writes · network · dispatch · repo-mutation) **plus the `target` scope and
the `sinks` fingerprint**. On any later run whose fingerprint is **not a subset** of the granted one,
standing consent **reverts to `unset` and asks again**, naming what widened. Effect classes alone are
too coarse to be the whole test (cross-family round 2): "local write" stays "local write" whether the
target is a scratch report or a policy file — the *target* is where that drift shows, which is why it
is part of the fingerprint and not merely descriptive. Widening is the trigger; narrowing is not. This is the same discipline as the
byte-identity anchors used elsewhere: consent is pinned to a fingerprint, not to a name, because
**the name is exactly what does not change when the danger does.**

**Guard against class inflation**: the class recorded is the *narrow* one that was actually approved
3×, never a widened parent. Three approvals of "dispatch a Sonnet sim" do not grant "dispatch any
agent" (`feedback_scope_widening_needs_grounding` — widening judgments get no free pass).

## Generalization gate → reverse-PR funnel

This is the operator's **"원본 반영 가치"** criterion made mechanical. Split each UAP learning:

- **Idiosyncratic** (this user's taste) → stays in the UAP, local. **Never** escalated — pushing personal taste into the public reference asset is drift.
- **Generalizable** (any user would benefit; the pattern recurs across **2+ sessions or projects**, not user-specific) → routed through `field-harvest` Mode A as a harvest candidate → FH-origin PR (HITL approval, per the existing field-harvest gate).

**Promotion threshold** (reuse `operations.md` gate): a skill proposal `rejected ≥ 40%` across a 2+ session window is a *redefine/deprecate* candidate (a generalizable signal worth a PR); `accepted ≥ 60%` reinforces. Below threshold → personal one-off, stays local.

**Generalization is a judged call — adversarial pairing required (no judge-only path).** The idiosyncratic-vs-generalizable split is not decided by the same session that wrote the UAP alone: it is paired with (a) the mechanical **2+ session/project recurrence threshold** above, and (b) `field-harvest` Mode A's contention-layer + the **human PR review** gate. A learning only reaches the public mirror after passing both — the recurrence backstop filters one-offs, the PR gate filters taste a human disagrees is general.

## Done When

- **UAP WRITE ran** at field-session close (or was correctly skipped — absent profile / ephemeral session). *Check class: mandatory-pass (binary — did Step 5-B.1 execute or log a skip reason).*
- **UAP READ applied** at session start / proposal time when a profile exists (preferred tier defaulted, 3×-rejected proposals suppressed, declined cadence nags muted). *Check class: judged, pair: the target-tier blind sim below.*
- **A class at 3 consecutive `accepted`** was either offered promotion once, or correctly not offered with the reason recorded (irreversible surface · already `declined` · no UAP). *Check class: measured — the consecutive count is read off the UAP outcome log, not recalled.*
- **Every `standing_consent` key resolves to a registry entry whose `sinks` are irreversible-free, and is unexpired.** *Check class: mandatory-pass (binary — join `standing_consent` keys against `consent_classes.yaml`, reject any key that is unregistered, taint-reachable to an irreversible sink, or past `expires`; any hit is a defect, not a judgment call).*
- **No domain content** entered the UAP this session. *Check class: judged, pair: phantom/content scan of the UAP diff.*

## Guards

- **Local-default, escalate-only-generalizable** — the drift-prevention spine of the loop.
- **Behavioral data only** — no domain content in the UAP (reference-asset identity).
- **Ephemeral env** — the UAP is gitignored, wiped on cloud reclaim. In an ephemeral/cloud session it is **unavailable**: operate from defaults, do not fabricate a profile, do not rely on it for cross-session continuity (`modes_and_value.md` ephemeral rule). The loop is a **local-session** mechanism.
- **HITL** — escalation to FH origin goes through `field-harvest`'s existing PR-approval gate; no autonomous commit to the shared repo (`feedback_no_personal_commit_to_shared_repo`).
- **Salience / tier dependence** — this loop is prose-driven, not hook-enforced. On a weaker model the READ side (apply-at-session-start) may silently not fire even when a UAP exists. This is an accepted limitation, not a silent one: it is the reason the change ships with a target-tier blind sim (per CLAUDE.md §Target-tier sim gate). A hook-enforced READ is a future hardening candidate, deliberately not built today (keep the surface thin).

  **Deliberated 2026-06-16 (decision: DEFER) → BUILT 2026-07-05 (revisit-trigger fired on a real miss).**
  The right mechanism is *not* the git pre-commit hook (the READ fires at session-start / proposal-time,
  which is not a git event) but a Claude Code **SessionStart hook**. The 2026-06-16 deferral set a
  **measured revisit-trigger** (build only when a real miss is observed, not on a guess). That trigger
  **fired 2026-07-05**: an opus-tier session opened with an immediate qasp task, the prose session-start
  companion load silently did not fire, and the agent operated on stale local memory (stale agy version;
  missed the standing origin-model-sidecar instruction). This was a *production* miss, stronger evidence
  than the deferral's target-tier-sim bar — so the hook is now built: **`scripts/fh_session_load.sh`**,
  registered operator-local in `.claude/settings.local.json` SessionStart. It pulls the companion store
  and emits a freshness delta (files newer than the session card + INDEX live pointers) into turn-0
  context, *before* the first user message is processed — closing the task-first-entry salience gap
  mechanically. Note the miss was **not** low-stakes as the 2026-06-16 note predicted (it produced wrong
  recommendations, not just an unapplied preference), which is what tipped defer → build. Prose READ
  remains the semantic layer (read + reconcile); the hook is the mechanical floor
  (`[[feedback_judge_robustness_mechanical_anchor]]` — mechanical anchor over salience).
