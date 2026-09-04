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
# DELIVERY CHANNEL (added 2026-07-31 — closes N=8: detection 100%, delivery 0%)
#   The first shipped version wrote its warning to stderr and exited 0. Per the hook contract
#   (code.claude.com/docs/en/hooks), on exit 0 stderr is IGNORED and stdout is parsed for JSON —
#   so the warning reached the transcript, never the model. The actor making the mistake never saw
#   the guard fire (measured: the guard's own author repeated the guarded mistake twice the day
#   after shipping it, N=7/N=8).
#   Advisory now emits JSON on stdout: `hookSpecificOutput.additionalContext` (wrapped by CC in a
#   system-reminder and injected into MODEL context) + top-level `systemMessage` (shown to the
#   USER). Two audiences, two fields, one emission.
#   ⚠️ `permissionDecision` is DELIBERATELY ABSENT: emitting "allow" alongside the warning would
#   auto-approve the flagged command past the permission system — the guard must never grant what
#   it exists to question. Block mode keeps the exit-2 path (stderr → fed to Claude, call blocked);
#   on exit 2 stdout/JSON is ignored by contract, so stderr is the correct channel there.
#   NAMED RESIDUAL (terra round 3, 2026-08-01) — a shell COMMENT inside a wrapper group hides the
#   closer from R2's required-closer branch, so `| (tail -5; # note<newline>); rc=$?` MISSES.
#   Accepted, not fixed, and the reason is the trade direction: stripping `#…` in the flatten is
#   quote-blind, so `curl "https://x/a#frag" | tail -3; rc=$?` — which HITs today, measured — would
#   become a miss. That swaps a contrived miss for a realistic one. Recall loss on a shape that does
#   not occur in interactively-composed commands is the cheaper side; lane-pinned as a known miss.
#   NAMED RESIDUAL (cross-family, 2026-07-31): with python3 broken/absent, payload extraction
#   yields CMD="" and the guard exits 0 even under FH_PIPE_VERDICT_BLOCK=1 — block mode fails
#   open on a dead interpreter. Accepted, not fixed: the Bash-call surface is re-runnable
#   (reversible → degrade-to-advisory per the Surface-Class Degrade Invariant), and the
#   alternative — exit 2 whenever python3 is missing — would block EVERY Bash call on such a
#   machine, the exact false-block storm the advisory design exists to avoid.
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
sys.stdout.buffer.write((d.get("tool_input", {}).get("command", "") or "").encode("utf-8"))
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
# EXCEPT where the shell itself continues the statement (GPT leg-C MED, 2026-08-01): a newline
# after `|`/`&&`/`||` or a backslash-newline is a CONTINUATION, not a separator — the blanket
# `\n → ;` rewrite turned `cmd |\n tail; echo $?` into `cmd | ; tail…`, un-matching R2 on the
# exact multi-line shape the flatten exists to catch. Join those first (backslash-newline joins
# with the EMPTY string, matching shell semantics — the destructive_pre_gate R4 lesson), then
# separate the remaining newlines. \001 is the newline sentinel (never occurs in command text).
# terra round (2026-08-01): `|&` continuation and newline-after-`(`/`{` join too — both continue
# the statement in the shells this guard serves. KNOWN FP INHERITED: the join cannot see quotes,
# so a QUOTED multi-line string containing `false |\ntail; echo $?` now reads as a live pipeline
# (mention-as-data — same advisory-tolerated class destructive_pre_gate documents; a
# quote-aware parser is over-build for an advisory layer). Lane-pinned as expected-HIT.
NL=$'\001'
FLAT=$(printf '%s' "$CMD" | tr '\n' "$NL" | sed \
  -e "s/\\\\${NL}[[:space:]]*//g" \
  -e "s/|&[[:space:]]*${NL}[[:space:]]*/|\& /g" \
  -e "s/|[[:space:]]*${NL}[[:space:]]*/| /g" \
  -e "s/&&[[:space:]]*${NL}[[:space:]]*/\&\& /g" \
  -e "s/\([({]\)[[:space:]]*${NL}[[:space:]]*/\1 /g" \
  -e "s/${NL}/;/g" -e 's/;/; /g')

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
  # `[({]?` — a subshell/group wrapper around the filter (`| (tail -5); echo $?`) is the same
  # verdict mistake one paren deeper; without it the wrapper bypassed R2 (GPT leg-C MED, 2026-08-01).
  # The closing paren rides in the arg class (`)` ∈ [^|;&]) or the explicit `[)}]?` for the no-arg form.
  # `&?` after the pipe — `|&` (stderr-merged pipeline, zsh/bash4) is the same verdict mistake
  # with a merged stream; it evaded the whitespace-anchored matcher (terra round, 2026-08-01).
  # TWO BRANCHES, and the wrapped one REQUIRES A CLOSER (terra round 2, 2026-08-01): with the
  # closer optional, `| (tail -5; test -n "$x"); echo $?` matched on the `;` INSIDE the group —
  # but there `$?` is `test`'s status, which is exactly right, so the warning was a false positive
  # the pre-wrapper matcher never produced. The filter must be the wrapper's FINAL command:
  #   (a) bare filter, then a statement separator
  #   (b) wrapper open · optional earlier statements ending in `;` · filter · args (no `;`, no
  #       closer chars) · optional `;` · REQUIRED `)`/`}`
  # Branch (b)'s optional `([^|&]*;)?` prefix keeps `| (sort; tail -5); echo $?` caught — the
  # filter need not be the group's FIRST command, only its LAST — while the `;` requirement keeps
  # the filter at a statement start, so `| (echo cat); rc=$?` does not match through a bare word.
  _F='(tail|head|cat|less|more)'
  if printf '%s' "$NORM" \
     | grep -qE "\|&?[[:space:]]*(${_F}([[:space:]][^|;&]*)?|[({]([^|&]*;)?[[:space:]]*${_F}([[:space:]][^|;&()}]*)?[[:space:]]*;?[[:space:]]*[)}])[[:space:]]*[;&].*\\\$\?"; then
    add "R2 \$? after a display filter" \
        "\$? holds the filter's status (tail/head/cat almost always succeed), not the command's — a FAILED check reads as 0. Capture first: \`out=\$(cmd 2>&1); rc=\$?\` then print \"\$out\" | tail."
  fi
fi

# ── R3 — a line that is ONLY redirections (`2>&1` alone on the line after a heredoc). ─────────
# zsh runs a redirection-only line as `$NULLCMD` (= `cat` by default) — measured 2026-09-04 with
# `zsh -x`: `+zsh:1> cat`. That `cat` reads STDIN until EOF. In this Bash tool, stdin is `/dev/null`
# ONLY when the harness appends `< /dev/null`, and it does NOT append it when the top-level command
# already carries a stdin redirect (`<` or a `<<` heredoc) — then stdin is a pipe held open for the
# life of the command, and `cat` never returns. Measured 2026-09-04: 9 tasks in two sessions, all of
# the shape `out=$(git commit -q -F - <<'CEOF' … CEOF ⏎ 2>&1)`: every commit landed within 4 s, no
# push ever started, the shell sat in `$( )` with no git child, killed later (exit 144). The
# pre-push hook never ran — it was blamed for a hang that happened before it.
# Heredoc BODIES are stripped first: a one-word markdown blockquote line (`> 정본`) inside a commit
# message is data, not a redirection. Deterministic on the remaining lines; zero-FP by construction
# (a redirection-only line is never what the author meant outside a heredoc body).
_R3_HIT=$(printf '%s\n' "$CMD" | awk '
  BEGIN { inhd = 0; d = "" }
  inhd { if ($0 == d || $0 ~ ("^[[:space:]]*" d "$")) { inhd = 0 }; next }
  {
    if (match($0, /<<-?[[:space:]]*["'"'"']?[A-Za-z_][A-Za-z_0-9]*["'"'"']?/)) {
      d = substr($0, RSTART, RLENGTH); sub(/^<<-?[[:space:]]*/, "", d); gsub(/["'"'"']/, "", d); inhd = 1
    }
    # a STATEMENT at line start made only of redirections, ended by `)`, `;`, `}`, `&&`, `||` or EOL —
    # the measured shape is `2>&1); rc=$?`, where `)` closes the `$( )` and the last statement inside
    # it is the bare `2>&1`.
    if ($0 ~ /^[[:space:]]*[0-9]*(>>?|<)(&[0-9]+|[[:space:]]*[^[:space:];|&<>()]+)?([[:space:]]+[0-9]*(>>?|<)(&[0-9]+|[[:space:]]*[^[:space:];|&<>()]+)?)*[[:space:]]*([;)}]|&&|\|\||$)/) { print NR ": " $0; exit }
  }')
if [ -n "$_R3_HIT" ]; then
  add "R3 redirection-only line runs \`cat\` on stdin (line ${_R3_HIT})" \
      "zsh executes a line that is only redirections as \$NULLCMD=cat, which reads stdin to EOF. This command carries a top-level \`<\`/\`<<\`, so the harness leaves stdin as an OPEN PIPE — that cat never returns and everything after it (the push) never starts. Put the redirection on the command line: \`out=\$(git commit -q -F - 2>&1 <<'"'"'CEOF'"'"'\`."
fi

[ -n "$hits" ] || exit 0

if [ "${FH_PIPE_VERDICT_BLOCK:-0}" = "1" ]; then
  # Block mode: exit 2 = stderr fed to the model as the blocking reason; stdout ignored by contract.
  printf '%s' "$hits" >&2
  exit 2
fi

# Advisory mode: JSON on stdout, exit 0. additionalContext → model, systemMessage → user.
# NO permissionDecision — see DELIVERY CHANNEL header. python3 owns the JSON escaping; if it
# fails, degrade to the old stderr emission (delivery lost, but the call is never disturbed).
# Capture-then-emit, not stream: a producer that prints partial output and dies must never leave
# half a JSON object on the hook's stdout (cross-family finding, 2026-07-31). The codec pin must
# be PYTHONIOENCODING itself — the hits text carries non-ASCII (⚠️), an inherited
# PYTHONIOENCODING=ascii was measured to kill the emission (silently restoring the exact delivery
# loss this rewrite closes), and PYTHONUTF8=1 does NOT win over an explicit PYTHONIOENCODING
# (measured by lane C4: the UTF8-mode pin still emitted 0 bytes under the ascii env).
json_out=$(printf '%s' "$hits" | PYTHONIOENCODING=utf-8 python3 -c '
import json, sys
h = sys.stdin.read()
print(json.dumps({
    "systemMessage": h,
    "hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": h},
}))
' 2>/dev/null)
if [ -n "$json_out" ]; then
  printf '%s\n' "$json_out"
  exit 0
fi
printf '%s' "$hits" >&2
exit 0
