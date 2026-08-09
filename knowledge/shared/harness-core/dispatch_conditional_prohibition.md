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
