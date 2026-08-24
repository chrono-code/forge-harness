# ETHOS — what forge-harness believes

> The compressed identity. Six named principles that travel as quotable units.
> For *what it is* see [`README.md`](../README.md); for *why it exists* see [`WHY.md`](WHY.md);
> for the *evidence* see [`OUTPUT_EVIDENCE.md`](OUTPUT_EVIDENCE.md).

forge-harness (FH) is a **quality-harness**: a practitioner's meta-harness for Claude Code that
optimizes for *whether the work holds up*, not how fast it leaves the building. Where a speed-harness
asks "how quickly can the agent ship?", FH asks "what survives a cold, independent pass?" — and makes
running that pass routine instead of a chore you skip.

A note on the word: "harness" is also used, commonly and correctly, for the *runtime
substrate* — prompts, tools, the agentic loop, the adapter across models. FH uses it for
what that substrate is **for**: turning intent into machinery you can hold someone to.
The substrate sense is a layer FH sits on, not a rival definition.

Everything below is **copyable**. None of it is a secret. The principles are the product.

---

## The forge

FH treats a project like steel — heat, shape, and shock, in named movements. The metaphor is literal,
not decoration:

**Three at the anvil:**

| The smith's word | The stage | What it does | Today |
|---|---|---|---|
| **Forge** | ① plant the circuit | shape the raw project into a harness, and settle *what counts as success / what it will never do* — **before** the design | `install-wizard` · `deep-clarify` · the marker's mandatory `①영혼` line |
| **Quench** | ② parallel decorrelation | cool it fast: many attempts in parallel from decorrelated angles. It hardens quickly — **and it makes the asset brittle**, which is what quenching does to steel | `auto-decorrelation` · `agent-composer` · cross-family sidecars · isolated worktree lanes |
| **Temper** | ③ burn it on six axes | reheat and draw the brittleness back out while keeping the hardness — **where the attacking passes actually belong** | `steel-quench` · `phantom-quench` · `sim-conductor` · `fh-meta:challenger` · revert probes · `templates/temper_check.sh` |

**⟹ And then it accelerates.** A blade that survived the forge cuts faster — `goal-quench`,
*Pass → Accelerate*. Three at the anvil, and speed is what those three **produce**; it is not a
fourth thing you do at the anvil. Quality is the lever, speed is the result.

Every command named above ships today. (🟥 **Corrected 2026-08-22.** This used to read *"a vocabulary, not a
stage list, and a different layer from the three-stage process … do not count them against those."*
That was wrong: the two diagrams are the same shape — three steps and an arrow into **⟹ accelerate** —
so the smith's words **are** the three-stage process, said differently. One layer told twice, not two
layers. The four engines, the four-axis commit gate and the six verification axes remain different
counts and still do not line up here. ⚠️ The skill names keep the older reading: `steel-quench` and
`phantom-quench` say *quench* but do *temper* work; renaming shipped skills to fix a metaphor would be
the more expensive lie.) **Temper** spent its first months named-but-unbuilt — deliberately, per
principle 5 — and shipped only after measurement runs on independent quench convergences validated that
the check flags over-hardening without punishing simplification. Quenched steel is hard but brittle;
no smith ships it un-tempered, and now neither does FH: after convergence, Wave-T measures the complexity
the quench itself added and hands over-built constructs back for de-brittling.

---

## 1. Pass → Accelerate

The gate is not friction to be tolerated; **surviving it is the speedup.** A project that has passed the
quench can be moved on with confidence — and that confidence, not a skipped step, is what acceleration
actually is.

> *Forge your projects, pass them through — they come out faster.*

## 2. The cold reviewer

After a long co-authoring session, you and your AI share the same context — and the same blind spots.
The reviewer worth having is the one who **never saw your reasoning**. You can get that by hand: paste
the work into a fresh, empty chat. FH turns that chore into one routine command (`steel-quench`,
`phantom-quench`, sidecar dispatch).

This is **de-bias, not detection.** FH adds no detection engine — a plain prompt to a fresh model does
much of the same. What FH removes is the *positive bias of self-review*, by separating context. It is
symmetric across models: whoever sat outside the collaboration is your cold reviewer, not whichever
model ranks higher.

> *The reviewer worth having is the one who never saw your reasoning.*

## 3. Utility, not moat

The methodology is copyable; what FH packages is the **workflow, not a secret sauce.** Its value is
narrow and honest: coverage of standpoints, plus a method that makes running them routine. There is no
cognitive moat here to defend, and FH does not pretend otherwise.

> *Fork it. Rename it. Make it yours.*

## 4. Value = f(task demand)

FH's techniques scale with what the task requires. Isolation pays off in proportion to how much you
co-developed the artifact; separation pays off in proportion to your integrity target. On a trivial task
the gain is negligible — and **saying so is part of the method.** On a demanding, deeply co-authored one
it is essential. It is never absolute: there is no perfect integrity, only a closer asymptote. Knowing
when *not* to reach for the harness is as much the ethos as knowing when to.

> *Run the cold pass when the stakes earn it — not as a ritual.*

## 5. Claims earn their words

Stock phrases — "isolated", "unique", "unrivaled", "guaranteed" — smuggle strong dictionary claims past
a warm reader who fills in charitable meaning. Every claim FH makes must survive a **cold, literal
reading**: would it still be true to someone who refuses to be generous? FH lints its own language for
this, and corrects itself when a phrase claims more than the evidence carries.

> *A claim that only survives a charitable reading is not yet true.*

## 6. A harness is a means, not an end

For a *field* harness, the target is to get **simpler over time** — rising complexity is a warning
signal. For a *meta*-harness like FH, the target is to *optimize*, not necessarily simplify: complexity
earns its place when it earns its scope. The red flags are not size but **orphaned, redundant, and
decorative** units. Every improvement ships with its own verification circuit (backward / adversarial /
forward), so the harness audits itself and the learnings compound session over session.

> *Complexity must earn its scope; the rest is debt.*

---

## What FH does not claim

- It is **not** a detection engine, an accuracy multiplier, or a model ranking. The cold pass is your
  base model's own ability, surfaced by isolation.
- It is **not** a moat. The methodology travels; copying it is the intended outcome, not a leak.
- It gates for **correctness** — does the work hold up — which is distinct from a security scan.
- Its empirical results are **worked examples, not benchmarks.** The gain is an empirical, per-task
  question, and an isolated reviewer also adds false positives you must triage.

The honesty is not a disclaimer bolted on at the end. It *is* the positioning.

---

## Who this line is for

> **Quality gates that catch you, not just your agent.**

That sentence is the first thing on the README, and it was **chosen against two alternatives**. Both
rejections are recorded because a line with no recorded reason gets rewritten by whoever edits next,
and the reason is the part that does not survive in the artifact.

**Rejected — "a reliable ally when you're unsure before opening a PR."** It names a *feeling*, and a
feeling cannot be checked. What FH actually does is a set of things you can name and run: it blocks a
commit, it refuses a publish, it makes an absent measurement say `UNMEASURED` instead of `0`. A
first line should say **what you can do with it**, because that is the only half a reader can verify
before installing. Warmth that outruns the verifiable is the same defect this file's §"What FH does
not claim" exists to prevent — one register up.

**Rejected — the solo-developer framing.** An earlier draft aimed the line at "a solo developer, before
they open a PR". It reads narrower than the thing is. FH's gates fire the same way for one person and
for a team; nothing in the machinery keys on team size. Naming an audience the machinery does not
distinguish trades reach for nothing, and it invites the reader who *is* on a team to conclude the
tool is not theirs.

**And the surviving half is deliberately awkward: "catch *you*."** The natural sentence is "catches
your agent" — that is what a reader expects and what most tools in this space promise. It is also the
easier claim, and FH's own record refutes it as sufficient: on the day this line was written, the
gates blocked the *author* seven times with **zero** self-catches ([`GATE_DAY.md`](GATE_DAY.md)). The
person driving the agent is inside the surface being gated, and a first line that omits them is
describing a smaller tool than the one that ships.

⚠️ **Scope of this record.** These are positioning decisions, not measurements. The `GATE_DAY.md`
figure is measured; "which sentence reads better" is not, and no reader study was run. What is being
preserved here is *why the choice was made*, so a future rewrite argues with the reason rather than
rediscovering it.
