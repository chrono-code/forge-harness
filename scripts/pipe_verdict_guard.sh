#!/usr/bin/env bash
# pipe_verdict_guard.sh — PreToolUse(Bash) advisory: a verdict read from the wrong end of a pipe.
#
# THE DEFECT
#   `cmd | tail -5; echo "exit=$?"` reports TAIL's status, not cmd's. A gate that FAILED reads as
#   exit 0. The degrade direction is toward PASS, which is the direction that never announces
#   itself. Measured 6× in this project between 2026-07-29 and 2026-07-31.
#
# WHY A HOOK AND NOT A FILE LINTER (measured 2026-07-31, and it reversed the plan on record)
#   The session card prescribed "add an S6 class to scripts/degrade_direction_scan.sh". Every
#   `pipe + $?` occurrence in this repo's shell scripts was then hand-verified: 7 hits, 7 correct
#   — in all 7 the final stage WAS the command under test. True positives in shipped files: 0.
#   All 6 recurrences lived in interactively-composed commands, which a repo scanner never reads.
#   S6 would have shipped a probe with no true positives, the exact failure mode S5 records in
#   its own comment ("100% FP trains dismissal of the one hit that will matter"). So the guard
#   moved to the surface where the defect actually occurs: the Bash tool call itself.
#
# TWO RULES, DELIBERATELY UNEQUAL IN CONFIDENCE
#   R1 — deterministic, zero-FP. `${PIPESTATUS[…]}` is bash-only. This project's Bash tool runs
#        zsh, where that expands to the EMPTY STRING (zsh spells it `$pipestatus[1]`, 1-indexed).
#        A verdict read from it is not wrong, it is ABSENT. No judgment involved.
#   R2 — heuristic, narrowed to DISPLAY FILTERS as the final stage (tail/head/cat/less/more).
#        A final `grep -q`, a script, or a subshell is usually the thing whose status is wanted —
#        those are the 7 correct shapes above and are not flagged. Narrowing costs recall; the
#        alternative is a probe nobody reads.
#
# DEGRADE DIRECTION: advisory. This guard WARNS and exits 0 — it never blocks a Bash call, because
#   a mis-read verdict is re-runnable and a false block on a developer's shell trains --no-verify
#   reflexes on hooks that DO guard irreversible surfaces. Set FH_PIPE_VERDICT_BLOCK=1 to escalate.
#   If the command cannot be extracted, it stays silent: an unparsed input is not a finding.
#
# Usage:
#   hook:  PreToolUse matcher "Bash" → bash scripts/pipe_verdict_guard.sh
#   test:  printf '%s' "<command>" | bash scripts/pipe_verdict_guard.sh --stdin-raw
# Opt out on a single command with a trailing `# noqa: pipe-verdict`.

set -u

CMD=""
if [ "${1:-}" = "--stdin-raw" ]; then
  CMD=$(cat)
else
  RAW=$(cat)
  # PreToolUse payload. Absent/!Bash/unparseable → stay silent (see degrade direction above).
  CMD=$(printf '%s' "$RAW" | python3 -c '
import json,sys
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
if d.get("tool_name") != "Bash": sys.exit(0)
sys.stdout.write(d.get("tool_input", {}).get("command", "") or "")
' 2>/dev/null) || CMD=""
fi
[ -n "$CMD" ] || exit 0

# Explicit opt-outs, checked before any rule.
printf '%s' "$CMD" | grep -qE '#[[:space:]]*noqa:?[[:space:]]*pipe-verdict' && exit 0

hits=""
add() { hits="${hits}  ⚠️  PIPE-VERDICT $1
      $2
"; }

# Flatten to ONE line before any matching. grep is line-oriented, so `.*` never spans a newline and
# every multi-line command missed — which is the worse half, because the invocations that actually
# recur here are multi-line. A newline is a statement separator, so `; ` is the faithful substitute.
# (Found by the Axis-2 adversarial pass on this guard, 2026-07-31; lanes A* pin it.)
FLAT=$(printf '%s' "$CMD" | tr '\n' ';' | sed 's/;/; /g')

# ── R1 — PIPESTATUS under zsh: the value is empty, so the verdict is absent. ──────────────────
# Brace-optional: zsh accepts `$PIPESTATUS[0]` as well, and the brace-anchored form missed it (lane B*).
if printf '%s' "$FLAT" | grep -qE '\$\{?PIPESTATUS[[{]' ; then
  add "R1 \${PIPESTATUS[…]} is empty in zsh" \
      "This shell is zsh; the bash array does not exist here, so the verdict expands to \"\". Use zsh's \`\$pipestatus[1]\` (1-indexed), or drop the pipe and read \$? directly."
fi

# ── R2 — display filter as the final stage, then a read of $?. ────────────────────────────────
# `||` is neutralized first: `a || b || echo 0` contains no pipeline, and reading it as one is
# how the sibling S5 probe produced 9 false positives before it was narrowed (2026-07-28).
# `set -o pipefail` in the same command makes `$?` after a pipeline correct — not a finding.
NORM=$(printf '%s' "$FLAT" | sed 's/||/__OR__/g')
if ! printf '%s' "$NORM" | grep -qE 'set -o pipefail|set -[a-zA-Z]*o[a-zA-Z]* pipefail'; then
  if printf '%s' "$NORM" \
     | grep -qE '\|[[:space:]]*(tail|head|cat|less|more)([[:space:]][^|;&]*)?[[:space:]]*[;&].*\$\?'; then
    add "R2 \$? after a display filter" \
        "\$? holds the filter's status (tail/head/cat almost always succeed), not the command's — a FAILED check reads as 0. Capture first: \`out=\$(cmd 2>&1); rc=\$?\` then print \"\$out\" | tail."
  fi
fi

[ -n "$hits" ] || exit 0

printf '%s' "$hits" >&2
if [ "${FH_PIPE_VERDICT_BLOCK:-0}" = "1" ]; then exit 2; fi
exit 0
