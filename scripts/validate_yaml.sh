#!/usr/bin/env bash
# Validate YAML frontmatter in all SKILL.md files AND all agent definitions.
# Catches frontmatter that does not parse — the failure mode that breaks Codex/Gemini plugin parsers.
# Usage: ./scripts/validate_yaml.sh [--fix]
#
# ── 2026-07-26 rewrite: the checker was the defect, not the skills it flagged ──────────────────
# The previous version grepped the description VALUE for ': ' and reported an error on a hit. It never
# asked whether the value was QUOTED, so a correctly quoted description (which parses fine) was
# reported as broken — a false positive that cannot be cleared by fixing the file. Worse, `--fix`
# would then wrap the already-quoted value in a `>-` block scalar, folding the quote characters INTO
# the string: an auto-fix that corrupts a correct file. Its sed also ran over the whole file rather
# than the frontmatter, so any body line beginning with 'description: ' was a target too.
#
# Ground truth here is now the parser: does the frontmatter load? A heuristic about punctuation is
# not a substitute for parsing the thing whose parseability is the question. When no YAML parser is
# reachable the check does not silently degrade to the old guess — it reports UNCALIBRATED and exits
# non-zero, because "I could not measure" is not "it is fine" (CLAUDE.md §Instrument Calibration).
#
# ── 2026-08-11: agents added to the scanned surface ───────────────────────────────────────────
# The scan covered only `plugins/*/skills/*/SKILL.md`, so agent definitions were structurally
# invisible — and one of them was broken the whole time. `quench-challenger.md` carried an unquoted
# multi-line `description:` whose `user:`/`assistant:` lines parsed as new keys, which invalidated
# the `tools: Read, Grep, Glob` and the `model: opus` HARD FLOOR declared BELOW it. Measured in a
# live session agent list: it showed `(Tools: All tools)` and a fallback description while its
# siblings showed exactly what they declared — i.e. a read-only adversary was running with write
# and execute tools, and a hard tier floor was pinning nothing.
#
# Note what the check measures: **YAML validity**, not CC-tolerance. Claude Code's own loader is
# more lenient — `expert.md` had an unquoted description containing ": " and still loaded correctly
# there. That leniency is not portable, and this file's whole reason for existing is the parsers
# that are not lenient (Codex/Gemini plugin loaders). So a file CC accepts can still fail here, on
# purpose. Calibrated at wiring time on a known pair: `quench-challenger.md`/`expert.md` failed
# before their fixes, the other six passed — a checker that flagged everything or nothing would
# have proven nothing.
set -uo pipefail

FIX=${1:-}
ERRORS=0
UNCALIBRATED=0

# Parser availability is resolved ONCE, loudly, before any file is judged.
PARSER=""
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  PARSER=python3
fi

check_skill() {
  local file="$1"
  local skill; skill="${2:-$(basename "$(dirname "$file")")}"

  if [ -z "$PARSER" ]; then
    echo "  ⚠️  $skill: UNCALIBRATED — no YAML parser available, frontmatter NOT verified"
    UNCALIBRATED=$((UNCALIBRATED + 1))
    return 0
  fi

  local out rc
  out=$(python3 - "$file" <<'PY' 2>&1
import sys, yaml
path = sys.argv[1]
text = open(path, encoding='utf-8').read()
# Frontmatter = content between the first two '---' fence lines.
lines = text.split('\n')
if not lines or lines[0].strip() != '---':
    print('NOFRONTMATTER'); sys.exit(3)
end = next((i for i, l in enumerate(lines[1:], start=1) if l.strip() == '---'), None)
if end is None:
    print('UNTERMINATED'); sys.exit(3)
fm = '\n'.join(lines[1:end])
try:
    data = yaml.safe_load(fm)
except yaml.YAMLError as e:
    print('PARSE ' + str(e).replace('\n', ' ')[:160]); sys.exit(1)
if not isinstance(data, dict):
    print('NOTMAPPING'); sys.exit(2)
missing = [k for k in ('name', 'description') if not data.get(k)]
if missing:
    print('MISSING ' + ','.join(missing)); sys.exit(2)
print('OK')
PY
  ); rc=$?

  case "$rc" in
    0) return 0 ;;
    *)
      echo "  ❌ $skill: frontmatter does not validate — $out"
      ERRORS=$((ERRORS + 1))
      if [ "$FIX" = "--fix" ]; then
        # Only ONE repair is attempted, and only for the case it actually addresses: an unquoted
        # description scalar that fails to parse. Quoting is preferred over a `>-` block scalar
        # because it is a single-line, reversible edit that leaves the string bytes unchanged.
        # A value already containing a single quote is left alone — escaping it correctly is a
        # judgment call, and a wrong auto-fix on a parse error is worse than a reported one.
        local dline val
        dline=$(awk '/^---/{n++; if(n==2) exit} n==1' "$file" | grep -m1 '^description: ' || true)
        val="${dline#description: }"
        if [ -n "$dline" ] \
           && ! printf '%s' "$val" | grep -q "'" \
           && ! printf '%s' "$val" | grep -qE "^['\">|]"; then
          python3 - "$file" "$dline" "$val" <<'PY'
import sys
path, dline, val = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path, encoding='utf-8').read()
open(path, 'w', encoding='utf-8').write(s.replace(dline, "description: '" + val + "'", 1))
PY
          echo "     → quoted the description scalar; re-run to confirm"
        else
          echo "     → NOT auto-fixed (already quoted/blocked, or contains a single quote) — fix by hand"
        fi
      fi
      ;;
  esac
}

echo "=== SKILL.md + agent YAML validation ==="
[ -z "$PARSER" ] && echo "  ⚠️  no YAML parser (python3 + pyyaml) — this run cannot verify anything"
_skills=0
for dir in plugins/*/skills/*/; do
  file="${dir}SKILL.md"
  [ -f "$file" ] && { check_skill "$file"; _skills=$((_skills + 1)); }
done
_agents=0
for file in plugins/*/agents/*.md .claude/agents/*.md; do
  [ -f "$file" ] || continue          # unmatched glob is not a file — no nullglob assumption
  check_skill "$file" "agent:$(basename "$file" .md)"
  _agents=$((_agents + 1))
done
# A surface that scans zero files is an instrument error, not a pass — the exact shape this
# addition exists to close (agents were an empty set for the whole life of the checker).
if [ "$_skills" -eq 0 ] || [ "$_agents" -eq 0 ]; then
  echo "  ❌ INSTRUMENT ERROR — scanned skills=$_skills agents=$_agents; a zero surface cannot pass"
  exit 3
fi
echo "  (scanned: $_skills skill(s), $_agents agent(s))"

echo ""
if [ "$UNCALIBRATED" -gt 0 ]; then
  echo "  ⚠️  UNCALIBRATED — $UNCALIBRATED skill(s) unverified (no parser). Not a pass."
  exit 2
fi
if [ "$ERRORS" -eq 0 ]; then
  echo "  ✅ All skills + agents: frontmatter parses"
  exit 0
fi
echo "  $ERRORS error(s). Run with --fix for the unquoted-description case; others are by hand."
exit 1
