# The conditional dispatch prohibition — what it actually is

> Detail file for `CLAUDE.md §Agent Dispatch Operation`. The resident summary carries the
> **behavioural rule**; this file carries the **measurement** behind it. Read this before citing any
> number here, before claiming the line is absent from a surface, and before re-running the probe.

## The two lines

Some runtimes ship these as a default addition to the session prompt:

```
Do not call the AgentTool unless the user requested it
Do not use workflows or deep-research unless the user requested it
```

## What was measured

**Scope of the measurement — state it before the numbers.** n=1 machine · macOS · install path
`~/.local/share/claude/versions/` · CLI versions 2.1.223–226, all four identical. Nothing here is a
claim about other platforms, other install paths, or later versions. Re-run before citing elsewhere.

```
occurrences of each line          3
CONTROL     "AgentTool"          37     ← instrument alive on this target
NEG-CONTROL "zzz_known_negative" 0      ← instrument not hallucinating hits
```

An unqualified `grep -c` (without `-a`) returns **empty** on this binary — it dies silently. That is
exactly the instrument death the control pair exists to catch; a bare `0` from it would have read as
a measurement.

### Resolution order — it is a fallback, not a constant

```js
function JWb(e){
  let t = wk()?.tengu_heron_brook;        // ① client-data string  → returned if non-empty
  if (typeof t === "string" && t.trim() !== "") return t.trim();
  let r = nt("tengu_heron_brook","");     // ② remote flag string  → returned if non-empty
  if (r.trim() !== "") return r.trim();
  if (Hbo(e)) return H3p;                 // ③ the two lines — only if the gate below passes
  return null;
}
function Hbo(e){
  if (e === void 0) return false;
  if (lB(Eo(e), "opus_5_prompt_bundle") !== true) return false;   // model-bundle gate
  return !nt(VE_, false);                                          // VE_ = "tengu_fennel_godwit"
}
```

Three consequences:

1. **Not hard-coded.** It is the third branch of a three-tier resolution — ① and ② replace it
   wholesale, and a remote kill-switch disables it.
2. **Not global — model-scoped.** It attaches only under `opus_5_prompt_bundle`. A session on another
   bundle never receives it. **Do not reason about this line without knowing which bundle you are on.**
3. **Genuinely conditional.** All 3 occurrences of each prefix carry `unless the user requested it`;
   no unconditional variant exists (checked with a live negative control on the phrasing regex).

### Where the text is *not* — two rows, kept apart on purpose

Merging these is the `not-found ≠ zero` defect this repo keeps naming
([[feedback_not_found_is_not_zero_family]]).

| Row | Targets |
|---|---|
| **MEASURED ZERO** — target exists, grep calibrated on that target | user + project `settings.json` · project `settings.local.json` · `~/.claude.json` · `~/.claude/plugins/**` · both launcher app bundles |
| **LAYER ABSENT** — nothing to search; silence, not a zero | user `settings.local.json` · `.claude/agents/**` (user and project) · output-styles (user and project) |

**INFERENCE, not measurement**: *"so it cannot be turned off from config."* Only the
**operator-facing** config layers were searched **for the text**. Branch ② above shows a *remote*
flag does control it. The honest statement is: the text is not in operator config, and no
operator-config key is known to gate it.

## Reproduction

```bash
cd ~/.local/share/claude/versions
V=2.1.226            # 실제 설치 버전으로 교체
grep -a -o "Do not call the AgentTool unless the user requested it" "$V" | wc -l   # 3
grep -a -o "AgentTool"               "$V" | wc -l                                  # 37  CONTROL
grep -a -o "zzz_known_negative_zzz"  "$V" | wc -l                                  # 0   NEG-CONTROL
off=$(grep -abo 'if(Hbo(e))return' "$V" | head -1 | cut -d: -f1)
dd if="$V" bs=1 skip=$((off-900)) count=1500 2>/dev/null | tr -d '\0'               # JWb
off=$(grep -abo 'function Hbo(' "$V" | head -1 | cut -d: -f1)
dd if="$V" bs=1 skip=$off count=420 2>/dev/null | tr -d '\0'                        # Hbo
```

## Two retractions this file exists to record

- **"A system prompt outranks both, by construction, so opening is impossible."** Right rule, wrong
  sentence. An *absolute* prohibition cannot be reopened from a lower layer; a *conditional* one is
  opened by its condition becoming true. Check whether the sentence is unconditional **before**
  reaching for the precedence rule.
- **"Reading the call site needs binary inspection, which was blocked."** False. Three plain `grep`
  calls resolved it; an adversarial reviewer demonstrated that by simply running them. One earlier
  attempt using a different tool had been denied, and that denial was generalised into *"this is
  unmeasurable"* — the same shape as [[feedback_impossible_verdict_may_be_unread_half]]. **A blocked
  tool is not a blocked question.** The honest label is *"not yet measured."*

## Named residuals

- The measurement is n=1 machine. Platform and install-path variance unmeasured.
- Whether any **operator-config** key gates the constant is unmeasured; only text-absence was checked.
- What ① (client-data) actually carries in this environment was not inspected — only that it takes
  precedence.

---

## §Hook-Floor-Unverified — 「어느 방향도 훅으로 안 막힌다」의 실측 근거

> CLAUDE.md §Agent Dispatch 는 결론 한 줄만 상주로 갖는다. 아래가 그 근거·미검증 항목이다.
> salience-split 2026-08-21.

⚠️ **Neither direction has a confirmed hook-level floor. Say that plainly rather than implying one.**
```
opening    salience only for the POSTURE. The prohibition met in the field is CONDITIONAL,
           which changes what "override" even means — see the measured block below.
blocking   ALSO not hook-enforced. `SubagentStart` fires on spawn but is **context-only** —
           it cannot block, exit 2 only surfaces stderr, and it has no decision field
           (official hooks reference, read 2026-08-08). It can INJECT context at the moment
           of dispatch, which is better-placed salience than this file, but still salience.
UNVERIFIED whether a `permissions` deny entry or a `PreToolUse` matcher can target subagent
           spawning at all — the reference does not name a tool for it, and this repo has no
           precedent. **Do not cite a blocking mechanism until someone runs the known pair**
           (configure the deny, attempt a dispatch, observe). Until then: unverified, not absent.
```

## §Retraction-SubagentStart — 이 블록이 두 번 틀렸던 기록

An earlier draft of this very block asserted "a `SubagentStart` hook can deny, and a denial there is a
real floor." That was false, taken on trust from an adjacent session and written here before the
reference was read. A second draft, on 2026-08-09, then wrote that the constant's call site "needs
binary inspection, which was blocked" — **also false**: three plain `grep` calls resolved it, and an
adversarial reviewer demonstrated that by doing it. Declaring something unmeasurable before trying the
cheap tool is [[feedback_impossible_verdict_may_be_unread_half]]; the honest label is *"not yet
measured,"* never *"blocked."* A blind target-tier sim then read it back correctly — which shows a sim measures
whether text is *followable*, never whether it is *true*. Both checks are needed; neither substitutes.


## §Worktree-Gate-Integrity — `core.hooksPath` 양팔 실측 (2026-08-05)

> 🟥 **운영 규칙은 CLAUDE.md 에 있다**: *워크트리에서 FH 자산을 커밋하지 않는다.*
> 아래는 그 규칙이 왜 조건부 사실 위에 서 있는지의 근거이고, **규칙을 실행하는 데는 필요 없다** —
> 「내 설치가 어느 팔인가」를 따져야 할 때만 읽어라. salience-split 2026-08-21.

**Fourth reason — gate-integrity in a worktree, and the answer is CONDITIONAL on how `core.hooksPath`
was set (measured 2026-08-05, both arms).** Do not carry a single verdict here; the two installs
behave differently:

| `core.hooksPath` | Which hook actually runs in a worktree | Consequence |
|---|---|---|
| **relative** — `templates/.git-hooks`, the form every FH doc installs (`CHEATSHEET.md`, `.claude/rules/fh_4axis_gate.md`, `install-wizard`, `self_evolution_routine.md`) | the **worktree's own copy** | Editing that copy *inside the worktree* disables the gate for that worktree — measured: neutralized hook → FH-asset commit with no marker succeeded (`rc=0`). The verifier becomes the verified, and the edit is invisible to `git status` in the main tree. |
| **absolute** — a hand-set full path (this operator's machine; **not** what any doc tells you to run) | the **main tree's copy** | A worktree-local edit has no effect; a known-positive is blocked there exactly as in the main tree (`rc=1`). |

An earlier draft of this section reported only the absolute-path arm and declared the
"worktree bypasses the gates" hypothesis *refuted* — from **n=1 on a non-canonical setting**, with a
do-not-revisit label attached. The relative-path arm, which is what everyone else runs, reproduces
the bypass. Freezing a conclusion is a defect when the measurement did not cover the shipped
configuration.

Separately and in **both** arms, the **evidence side** breaks: `tracks/` is gitignored, so it does not
follow into a worktree, so the Axis 2+3 marker and the Axis 4 `edit_manifest.yaml` are *structurally
absent* — an FH-asset commit in a worktree fails on evidence it has no way to have. That degrades
fail-closed (correct), but a gate that **cannot** be satisfied is what trains the bypass. Note the
hook itself prints `mkdir -p …/tracks/_meta` on that failure, i.e. the actor's own error message
teaches the marker-creation path — so "just don't fabricate it" is prose sitting under a machine
instruction pointing the other way.

