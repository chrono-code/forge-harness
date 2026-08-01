#!/usr/bin/env bash
# destructive_pre_gate.sh — PreToolUse(Bash) advisory: a destructive command about to run.
#
# THE DEFECT
#   A session under ship pressure self-justifies a destructive git/rm command and runs it in the
#   same breath ("contents are identical, so reset --hard is safe"). Observed 2026-08-01 on a
#   below-floor sidecar (GLM 4-bit): self-justification THEN `git reset --hard origin/main` — the
#   weaker the tier, the weaker the self-inhibition, so the counterweight must be mechanical, not
#   prose. Origin prototype: pmh-dev scripts/destructive_pre_gate.sh (field→meta reverse
#   propagation, hardened here to the pipe_verdict_guard pattern).
#
# ROLE DECONFLICTION (no double-gate)
#   templates/.git-hooks/pre-push already HARD-BLOCKS the git-side irreversible surface at push
#   time (force/non-ff push, remote branch delete — DESTRUCTIVE_OP_OK channel). This guard is the
#   shift-left SALIENCE layer at the Bash-call surface, and its net-new coverage is the LOCAL
#   destructive ops no hook currently sees: reset --hard, clean -f, checkout ., stash drop/clear,
#   rm -rf on root/home/cwd. For force-push it fires earlier than pre-push but never replaces it.
#
# DEGRADE DIRECTION: advisory. Warns and exits 0 — a false block on a developer's shell trains
#   the --no-verify reflex on the hooks that DO guard irreversible surfaces. Set
#   FH_DESTRUCTIVE_BLOCK=1 to escalate to exit 2 (stderr → model, call blocked).
#   Unparseable/absent payload → silent exit 0 (an unparsed input is not a finding; block mode
#   fails open on a dead python3 — same accepted residual as pipe_verdict_guard, the surface is
#   the reversible Bash call, not the irreversible act itself).
#
# PRECISION OVER RECALL (named residuals, deliberate — the full list, per the Axis-2 pass 2026-08-01)
#   NOT flagged, by decision or by construction:
#   - `rm -rf <absolute path>` other than /, ~, . — scratchpad/build cleanup lives there and 100%
#     FP trains dismissal of the one hit that matters (pipe_verdict S5 lesson).
#   - `git rebase` — reflog-recoverable, and interactive rebase is unsupported here anyway.
#   - Env-var / eval indirection (`rm -rf $HOME`, `OPT=--hard; git reset $OPT`), `find -delete`,
#     `xargs rm -rf`, shell aliases — unreachable by a regex over the literal command by
#     construction; a parser would be over-build for an advisory layer. Registered, not closed.
#   - Mention-as-data FP: heredoc bodies, `echo "git reset --hard"`, `git log -S '…'` DO fire —
#     the flatten step cannot tell code from quoted data (measured live: the guard fired on the
#     Axis-2 reviewer's own probe command). Advisory-tolerated; use `# noqa: destructive-op` when
#     editing/documenting this guard itself.
#   - Two JSON-emitting hooks on one matcher (this + pipe_verdict_guard): per the hook docs each
#     hook's stdout is parsed independently; simultaneous-fire not runtime-verified (LOW).
#   - noqa smuggling: the opt-out is checked against the WHOLE command, so a multi-statement
#     payload with a destructive line 1 and a `# noqa: destructive-op` on line 2 exempts both.
#     Accepted: noqa is self-grantable by design on this advisory surface (same trust channel as
#     the DESTRUCTIVE_OP_OK env ack) — the hard floor for the irreversible half stays pre-push.
#
# DELIVERY CHANNEL: advisory emits JSON on stdout — hookSpecificOutput.additionalContext (model)
#   + systemMessage (user). permissionDecision DELIBERATELY ABSENT: the guard must never
#   auto-approve what it exists to question (PR#217 contract, memory
#   feedback_advisory_invisible_to_actor).
#
# Usage:
#   hook:  PreToolUse matcher "Bash" → bash scripts/destructive_pre_gate.sh
#   test:  printf '%s' "<command>" | bash scripts/destructive_pre_gate.sh --stdin-raw
# Opt out on a single command with a trailing `# noqa: destructive-op`.

set -u

CMD=""
if [ "${1:-}" = "--stdin-raw" ]; then
  CMD=$(cat)
else
  RAW=$(cat)
  CMD=$(printf '%s' "$RAW" | python3 -c '
import json,sys
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
if d.get("tool_name") != "Bash": sys.exit(0)
sys.stdout.write(d.get("tool_input", {}).get("command", "") or "")
' 2>/dev/null) || CMD=""
fi
[ -n "$CMD" ] || exit 0

# Explicit opt-out, checked before any rule.
printf '%s' "$CMD" | grep -qE '#[[:space:]]*noqa:?[[:space:]]*destructive-op' && exit 0

# Flatten to ONE line (grep is line-oriented; multi-line commands are the recurring shape) and pad
# with spaces so end-of-string flags match uniformly (` -f` at line end == ` -f `).
# Normalizations, each closing a measured bypass (cross-family Axis-2 pass, 2026-08-01):
#   backslash-newline joined  → `rm -rf \` + newline + `/` no longer splits the statement (A1)
#   \r stripped               → CRLF payloads no longer break the `[ ;]` terminators (A10)
#   quotes stripped           → `rm -rf "/"` matches like its unquoted twin (A3; mention-as-data
#                               FP surface unchanged — that class fires with or without quotes)
#   tabs → spaces, squeezed   → `git  reset --hard` (double space) matches (A2)
# Anchoring: rows require a leading separator `[ (/]` before the command word (NOT command-position
# anchoring — sudo/env/xargs wrappers keep a space before the word and stay caught). This closes the
# measured prose FP where "Confi**rm** each … -toward-PASS … *" satisfied the rm row through a word
# TAIL (fired live twice on this guard's own review commands, 2026-08-01). Full command-position
# anchoring stays REJECTED (would drop sudo/env wrappers); `/` in the class keeps `/bin/rm` caught.
JOINED="${CMD//\\$'\n'/ }"
FLAT=" $(printf '%s' "$JOINED" | tr -d '\r' | tr '\n' ';' | sed 's/;/; /g' | tr -d '"'"'" | tr '\t' ' ' | tr -s ' ') "

# Normalize `git -C <path>` / `--git-dir=` / `--work-tree=` down to bare `git` BEFORE matching —
# the Axis-2 pass measured `git -C /repo reset --hard` sailing through every git row, and this
# environment specifically TRAINS that shape ("cwd resets between calls, use absolute paths /
# git -C"), so the origin defect (a self-justifying model) would most naturally emit exactly it.
FLAT=$(printf '%s' "$FLAT" | sed -E 's/git( +(-C +[^ ;]+|--git-dir=[^ ;]+|--work-tree=[^ ;]+))+/git/g')

# Dry-run neutralizer: `git clean -fdn` / `--dry-run` is non-destructive; rewrite it to a token no
# row matches, so the clean row cannot FP on a dry run (Axis-2 #6 — an FP here violates the very
# S5 lesson the header cites).
FLAT=$(printf '%s' "$FLAT" | sed -E 's/git clean +[^|;&]*(-[a-zA-Z]*n[a-zA-Z]*|--dry-run)[^|;&]*/git clean DRYRUN/g')

# ── Destructive pattern table: regex@@description ─────────────────────────────────────────────
# Delimiter is @@ because the regexes themselves carry `|` (alternation) — a `|` delimiter
# truncated every alternation-bearing pattern at split time (caught by the known-pair lanes on
# first run, 2026-08-01: 25/46 lanes failed with "brackets not balanced" before any live use).
# Matched with grep -E against the padded FLAT. Keep each pattern precise; add a lane pair in
# scripts/test_destructive_pre_gate_lanes.sh for every row you add (known-pair rule).
PATTERNS=(
  '[ (/]git reset [^|;&]*--hard@@git reset --hard discards ALL uncommitted changes irreversibly'
  '[ (/]git clean [^|;&]*-[a-zA-Z]*[fxX]@@git clean -f/-x permanently deletes untracked files'
  '[ (/]git checkout ([^|;&]*-- )?\.\/? @@git checkout . reverts every local modification'
  '[ (/]git restore [^|;&]*--worktree@@git restore --worktree reverts working-tree changes'
  '[ (/]git restore \.\/? @@git restore . reverts every local modification'
  '[ (/]git push [^|;&]*(--force(-with-lease)?[ ;]|-f[ ;]| \+[^ ;]+[ ;])@@force push rewrites remote history (pre-push hook will also gate this — enumerate first)'
  '[ (/]git branch [^|;&]*(-[a-zA-Z]*D |--delete [^|;&]*--force|--force [^|;&]*--delete)@@git branch -D force-deletes a branch without merge check'
  '[ (/]git stash (drop|clear)[ ;]@@git stash drop/clear permanently discards stashed work'
  '[ (/]git worktree remove [^|;&]*--force@@git worktree remove --force discards a dirty worktree'
  '[ (/]rm [^|;&]*-[a-zA-Z]*[rR][a-zA-Z]*[^|;&]* (/\*?|~/?|\.\/?\*?|\*)[ ;]@@rm -rf on root/home/cwd/glob deletes irreplaceably'
  '[ (/]rm [^|;&]*--no-preserve-root@@rm --no-preserve-root is never routine'
)

hits=""
for entry in "${PATTERNS[@]}"; do
  pattern="${entry%%@@*}"
  desc="${entry#*@@}"
  if printf '%s' "$FLAT" | grep -qE "$pattern"; then
    hits="${hits}  ⚠️  DESTRUCTIVE-OP ${desc}
"
  fi
done
[ -n "$hits" ] || exit 0

hits="${hits}      Before running: is uncommitted/stashed state enumerated (git status / predelete_check.sh)?
      Destructive-Op Gate order: enumerate → recover → destroy — never destroy-then-check.
      Intentional and reviewed → re-run with trailing \`# noqa: destructive-op\`."

if [ "${FH_DESTRUCTIVE_BLOCK:-0}" = "1" ]; then
  # Block mode: exit 2 = stderr fed to the model as the blocking reason; stdout ignored by contract.
  printf '%s\n' "$hits" >&2
  printf '%s\n' "      [BLOCKED] FH_DESTRUCTIVE_BLOCK=1 — unset or add noqa after review to proceed." >&2
  exit 2
fi

# Advisory mode: JSON on stdout, exit 0. Capture-then-emit; PYTHONIOENCODING pinned because the
# text carries non-ASCII (⚠️) and an inherited ascii codec was measured to kill the emission
# (pipe_verdict_guard lane C4). python3 owns escaping; on failure degrade to stderr (delivery
# lost, call undisturbed).
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
