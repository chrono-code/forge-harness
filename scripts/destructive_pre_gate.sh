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
#   - `git -c alias.<name>='!<shell>' <name>` — the normalizer CONSUMES `-c k=v` (it must: that is
#     how `git -c core.x=y reset --hard` is caught), and the alias name that follows is not a
#     destructive row, so arbitrary shell runs CLEAN. Concrete realization of the indirection class
#     above, named separately because the normalizer is what makes it reachable (terra round 2,
#     2026-08-01). Not fixed: closing it means interpreting alias payloads, i.e. parsing shell —
#     over-build for an advisory layer, and squarely inside the deliberate-obfuscation threat model
#     this guard excludes. It counters SELF-JUSTIFICATION, not evasion.
#   - Shell-escape reconstruction (`\g\i\t reset --hard`, `$'git' reset`) and quoted-space git -C
#     paths (`git -C "/tmp/my repo" reset --hard`) — regex-with-normalization cannot dequote like
#     a shell; a Bash-compatible tokenizer would be over-build for an advisory layer (GPT-round,
#     registered). Deliberate-obfuscation is outside this guard's threat model anyway: it counters
#     SELF-JUSTIFICATION, not adversarial evasion.
#   - Block mode (FH_DESTRUCTIVE_BLOCK=1) is an ESCALATED ADVISORY, not an enforcement boundary:
#     malformed payload / dead python3 / grep processing failure all fail open by the documented
#     degrade direction (reversible surface). A project needing a hard floor on these ops wires a
#     PreToolUse permission rule or server-side protection, not this guard (GPT-round, pinned by
#     the fault-injection lanes).
#
# DELIVERY CHANNEL: advisory emits JSON on stdout — hookSpecificOutput.additionalContext (model)
#   + systemMessage (user). permissionDecision DELIBERATELY ABSENT: the guard must never
#   auto-approve what it exists to question (PR#217 contract, memory
#   feedback_advisory_invisible_to_actor).
#
# Usage:
#   hook:  PreToolUse matcher "Bash" → bash scripts/destructive_pre_gate.sh
#   test:  printf '%s' "<command>" | bash scripts/destructive_pre_gate.sh --stdin-raw
# Opt out with `# noqa: destructive-op` — exempts the ENTIRE Bash payload (whole-command match,
# see PRECISION OVER RECALL above), not a single line.

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
sys.stdout.buffer.write((d.get("tool_input", {}).get("command", "") or "").encode("utf-8"))
' 2>/dev/null) || CMD=""
fi
[ -n "$CMD" ] || exit 0

# Explicit opt-out, checked before any rule.
printf '%s' "$CMD" | LC_ALL=C grep -qE '#[[:space:]]*noqa:?[[:space:]]*destructive-op' && exit 0

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
# GPT-round (R4) semantics fixes, each lane-pinned:
#   backslash-newline joins with EMPTY string, matching shell semantics — a space here let
#   `git re\` + newline + `set --hard` split the token and miss (measured bypass).
#   Separators `&& || | & ( )` are space-padded so `:&&git reset --hard` and `--force|cat`
#   satisfy the leading/trailing boundary classes without whitespace in the original.
JOINED="${CMD//\\$'\n'/}"
FLAT=" $(printf '%s' "$JOINED" | tr -d '\r' | tr '\n' ';' | sed 's/;/; /g' \
  | sed -E 's/(\&\&|\|\||[|&()])/ \1 /g' | tr -d '"'"'" | tr '\t' ' ' | tr -s ' ') "

# Normalize git global options down to bare `git` BEFORE matching — the Axis-2 pass measured
# `git -C /repo reset --hard` sailing through every git row, and this environment specifically
# TRAINS that shape ("cwd resets between calls, use absolute paths / git -C"), so the origin
# defect (a self-justifying model) would most naturally emit exactly it. GPT-round extended the
# consumed set: --no-pager, -c k=v, -p/-P, and the space-separated --git-dir/--work-tree forms.
# Leg-C MED round (2026-08-01) completed the allowlist against `git --help`'s global-option table:
# the valueless pathspec/behavior toggles (--literal/--glob/--noglob/--icase-pathspecs,
# --no-optional-locks, --no-replace-objects, --no-lazy-fetch, --no-advice, --bare, --paginate) and
# the value-carrying --namespace/--super-prefix/--config-env/--exec-path= — any one of which let
# `git <opt> reset --hard` sail past every git row. --exec-path WITHOUT `=` is deliberately not
# consumed: bare --exec-path prints and exits, so nothing destructive follows it.
FLAT=$(printf '%s' "$FLAT" | sed -E 's/git( +(-C +[^ ;]+|--git-dir[= ][^ ;]+|--work-tree[= ][^ ;]+|-c +[^ ;]+|--namespace[= ][^ ;]+|--super-prefix[= ][^ ;]+|--config-env[= ][^ ;]+|--exec-path=[^ ;]+|--no-pager|--no-optional-locks|--no-replace-objects|--no-lazy-fetch|--no-advice|--literal-pathspecs|--glob-pathspecs|--noglob-pathspecs|--icase-pathspecs|--bare|--paginate|-[pP]))+/git/g')

# Dry-run neutralizer: `git clean -fdn` / `--dry-run` is non-destructive; rewrite it to a token no
# row matches, so the clean row cannot FP on a dry run (Axis-2 #6 — an FP here violates the very
# S5 lesson the header cites). GPT-round scoping: only OPTION tokens may sit between `clean` and
# the dry-run flag — a nested `"$(echo -n build)"` or a post-`--` pathspec `-n` no longer
# neutralizes a real deletion (`--` itself is not matched by the option-token group, so
# consumption stops there by construction).
FLAT=$(printf '%s' "$FLAT" | sed -E 's/git clean( +--?[a-zA-Z][a-zA-Z=-]*)* +(-[a-zA-Z]*n[a-zA-Z]*|--dry-run)( +--?[a-zA-Z][a-zA-Z=-]*)*/git clean DRYRUN/g')

# cwd-glob canonicalization: `././*` and friends collapse to `./*` so the rm row's target
# alternation sees the canonical spelling (GPT-round; brace-expansion globs stay a residual).
FLAT=$(printf '%s' "$FLAT" | sed -E 's/(\.\/)+/.\//g')

# Staged-only restore neutralizer (GPT leg-C round, 2026-08-01): `git restore --staged .` only
# unstages (worktree untouched, re-addable) — the broadened restore-dot row below would FP on it.
# Neutralize ONLY when --staged is present AND no worktree flag is (staged+worktree IS destructive
# and the -W/--worktree row catches it). Whole-payload rewrite: a compound payload mixing a
# staged-only restore with a plain destructive restore is a named residual (rare shape).
if printf '%s' "$FLAT" | LC_ALL=C grep -qE 'git restore [^|;&]*--staged' \
   && ! printf '%s' "$FLAT" | LC_ALL=C grep -qE 'git restore [^|;&]*(--worktree|-[a-zA-Z]*W)'; then
  FLAT=$(printf '%s' "$FLAT" | sed -E 's/git restore /git restore_stagedonly /g')
fi

# ── Destructive pattern table: regex@@description ─────────────────────────────────────────────
# Delimiter is @@ because the regexes themselves carry `|` (alternation) — a `|` delimiter
# truncated every alternation-bearing pattern at split time (caught by the known-pair lanes on
# first run, 2026-08-01: 25/46 lanes failed with "brackets not balanced" before any live use).
# Matched with grep -E against the padded FLAT. Keep each pattern precise; add a lane pair in
# scripts/test_destructive_pre_gate_lanes.sh for every row you add (known-pair rule).
# GPT-round (R4) token-boundary discipline: every destructive OPTION must start its own token
# (preceded by a space) — `docs--hard`, `release--force`, `--exclude=cache`'s x, and
# `rm --verbose`'s r no longer satisfy rows through substrings of unrelated tokens. Long-form
# spellings the boundary would orphan are added explicitly (--force for clean, --recursive for
# rm, --force-with-lease=<ref>, worktree -f, restore -W).
PATTERNS=(
  '[ (/]git reset ([^|;&]* )?--hard[ ;]@@git reset --hard discards ALL uncommitted changes irreversibly'
  '[ (/]git clean ([^|;&]* )?(--force[ ;]|-[a-zA-Z]*[fxX][a-zA-Z]*[ ;])@@git clean -f/-x permanently deletes untracked files'
  '[ (/]git checkout ([^|;&]* )?\.\/? @@git checkout . reverts every local modification'
  '[ (/]git restore ([^|;&]* )?(--worktree|-[a-zA-Z]*W[a-zA-Z]*[ ;])@@git restore --worktree reverts working-tree changes'
  '[ (/]git restore ([^|;&]* )?\.\/? @@git restore . reverts every local modification'
  '[ (/]git push ([^|;&]* )?(--force(-with-lease(=[^ ;]+)?)?[ ;]|-[a-zA-Z]*f[a-zA-Z]*[ ;]|\+[^ ;]+[ ;])@@force push rewrites remote history (pre-push hook will also gate this — enumerate first)'
  '[ (/]git branch ([^|;&]* )?(-[a-zA-Z]*D[ ;]|--delete( [^|;&]*)? --force[ ;]|--force( [^|;&]*)? --delete[ ;])@@git branch -D force-deletes a branch without merge check'
  '[ (/]git stash (drop|clear)[ ;]@@git stash drop/clear permanently discards stashed work'
  '[ (/]git worktree remove ([^|;&]* )?(--force[ ;]|-[a-zA-Z]*f[a-zA-Z]*[ ;])@@git worktree remove --force discards a dirty worktree'
  '[ (/]rm ([^|;&]* )?(--recursive|-[a-zA-Z]*[rR][a-zA-Z]*)[^|;&]* (/\*?|~/?|\.\/?\*?|\*)[ ;]@@rm -rf on root/home/cwd/glob deletes irreplaceably'
  '[ (/]rm ([^|;&]* )?--no-preserve-root@@rm --no-preserve-root is never routine'
)

hits=""
for entry in "${PATTERNS[@]}"; do
  pattern="${entry%%@@*}"
  desc="${entry#*@@}"
  # LC_ALL=C: an inherited locale must never change what an ASCII pattern matches (the collation
  # class killed a sibling probe silently — card-drift 2026-07-31; patterns here are ASCII-only).
  if printf '%s' "$FLAT" | LC_ALL=C grep -qE "$pattern"; then
    hits="${hits}  ⚠️  DESTRUCTIVE-OP ${desc}
"
  fi
done
[ -n "$hits" ] || exit 0

hits="${hits}      Advisory timing: this context reaches the model on the NEXT turn — the call may have
      already run (pre-action blocking = FH_DESTRUCTIVE_BLOCK=1). If it ran un-enumerated,
      recover FIRST: git status / git stash list / git reflog /
      \`bash templates/predelete_check.sh <repo> [base]\` (repo-root relative — leg-C MED: an
      uncited healing path is a dead pointer to the session that needs it mid-incident).
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
if json_out=$(printf '%s' "$hits" | PYTHONIOENCODING=utf-8 python3 -c '
import json, sys
h = sys.stdin.read()
print(json.dumps({
    "systemMessage": h,
    "hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": h},
}))
' 2>/dev/null) && [ -n "$json_out" ]; then
  printf '%s\n' "$json_out"
  exit 0
fi
printf '%s' "$hits" >&2
exit 0
