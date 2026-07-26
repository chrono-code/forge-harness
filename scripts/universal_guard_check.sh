#!/usr/bin/env bash
# universal_guard_check.sh — known-pair anchor for the pre-commit UNIVERSAL guards.
#
# WHAT IT PINS (2026-07-26, N=5 of the gate-locality class):
#   The confidentiality/privacy guards in templates/.git-hooks/pre-commit are SURFACE-scoped
#   ("content is being committed to a public repo"), NOT 4-axis-scoped ("an FH asset changed").
#   They used to be authored below the `exit 0  # No FH assets staged` line, so their scope
#   silently inherited the 4-axis classifier's asset pathspec: a commit staging only non-asset
#   paths skipped the confidentiality scan entirely. Measured then: 46/241 tracked files (19.1%)
#   unscannable that way, 32 also outside npm files[] (no publish-time backstop either).
#   This anchor fails if that coupling is ever reintroduced.
#
#   It also pins the credential-SHAPE patterns imported the same day from the cross-audited sister
#   asset PromptPartner/agentsmith (tracks/_audit/session_2026_07_26_agentsmith-sister.md), and the
#   single measured false positive they carry (the AWS documentation key), so a future pattern edit
#   cannot silently re-open either direction.
#
# WHY BOTH DIRECTIONS ARE PINNED: a gate is only calibrated if it separates a known-positive from
# a known-negative. Pinning blocks alone would let an over-broad pattern pass this check while
# training PUBLIC_SURFACE_OK into muscle memory — an over-blocking gate is a disarmed gate.
#
# Runs in a THROWAWAY git repo (mktemp): it never touches this repo's index or worktree.
# Usage: bash scripts/universal_guard_check.sh    → exit 0 all pairs hold, 1 otherwise.
set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
DEFAULTS="$REPO_ROOT/.claude/rules/.public-surface-patterns.defaults"

[ -f "$HOOK" ]     || { echo "❌ FAIL — hook not found: $HOOK"; exit 1; }
[ -f "$DEFAULTS" ] || { echo "❌ FAIL — pattern defaults not found: $DEFAULTS"; exit 1; }

SANDBOX=$(mktemp -d) || { echo "❌ FAIL — mktemp"; exit 1; }
trap 'rm -rf "$SANDBOX"' EXIT

# ── Test the STAGED blob, not the worktree copy (cross-family audit finding, 2026-07-26) ──
# A pre-commit anchor that reads the worktree is bypassable: stage a regressed hook or pattern
# file, restore the worktree copy, and the anchor validates content the commit will not contain.
# When a path is staged, extract its staged blob and test THAT. Falls back to the worktree copy
# when the path is not staged (the ordinary "just run the check" case). Fails CLOSED if a staged
# blob exists but cannot be read — an unreadable subject is not a passing subject.
#
# `-c core.quotePath=false --no-renames` for the same two reasons the hook uses them: git quotes
# non-ASCII paths (so a name-match silently fails), and with rename detection ON a `git mv` of a
# protected file reports only the DESTINATION — the anchor then found the old path "not staged",
# fell back to the intact worktree copy, and passed a commit that deletes the very hook it guards
# (cross-family audit R2, 2026-07-26). With --no-renames the move shows up as a deletion of the
# protected path, which is caught below and fails closed.
stage_or_worktree() {  # <repo-relative path> <dest> ; echoes the source used
  local rel="$1" dest="$2" status
  status=$(git -C "$REPO_ROOT" -c core.quotePath=false diff --cached --name-status --no-renames 2>/dev/null \
           | awk -F'\t' -v f="$rel" '$2 == f { print $1; exit }')
  case "$status" in
    D) echo deleted-from-index; return 1 ;;   # the protected file is being REMOVED — never a pass
    '') : ;;                                  # not staged → worktree copy is what a commit keeps
    *)
      if git -C "$REPO_ROOT" show ":$rel" > "$dest" 2>/dev/null && [ -s "$dest" ]; then
        echo staged; return 0
      fi
      echo unreadable-staged; return 1 ;;
  esac
  cp "$REPO_ROOT/$rel" "$dest" 2>/dev/null && { echo worktree; return 0; }
  echo missing; return 1
}

HOOK_SRC=$(stage_or_worktree "templates/.git-hooks/pre-commit" "$SANDBOX/.hook-under-test") || {
  echo "❌ FAIL — pre-commit blob unreadable ($HOOK_SRC) — fail-closed."; exit 1; }
DEF_SRC=$(stage_or_worktree ".claude/rules/.public-surface-patterns.defaults" "$SANDBOX/.defaults-under-test") || {
  echo "❌ FAIL — pattern defaults blob unreadable ($DEF_SRC) — fail-closed."; exit 1; }
HOOK="$SANDBOX/.hook-under-test"
DEFAULTS="$SANDBOX/.defaults-under-test"

git -C "$SANDBOX" init -q 2>/dev/null
git -C "$SANDBOX" config user.email "test@example.com"
git -C "$SANDBOX" config user.name "test"
mkdir -p "$SANDBOX/.claude/rules" "$SANDBOX/scripts"
cp "$DEFAULTS" "$SANDBOX/.claude/rules/.public-surface-patterns.defaults"
# The hook now sources the shared scan library, so the sandbox needs it too. When it was missing,
# the gate correctly failed closed — and 3 of the "clean" pairs still scored PASS because the oracle
# below did not recognise "scanner cannot run" as a not-armed state. Both were fixed together.
cp "$REPO_ROOT/scripts/psa_scan_lib.sh" "$SANDBOX/scripts/psa_scan_lib.sh" 2>/dev/null \
  || { echo "❌ FAIL — scripts/psa_scan_lib.sh missing — fail-closed."; exit 1; }
# An initial commit so the hook's staged-vs-HEAD steps have a HEAD to diff against. Without it
# they emit "fatal: ambiguous argument 'HEAD'" — harmless to the verdicts here, but noise in a
# check whose whole job is to make a real signal legible.
printf 'sandbox\n' > "$SANDBOX/.seed"
git -C "$SANDBOX" add .seed >/dev/null 2>&1
git -C "$SANDBOX" commit -qm seed >/dev/null 2>&1

# Synthetic operator literal — this file is public, so the anchor must NOT name the real one.
OVERRIDE="$SANDBOX/.psa_override"
printf 'HIGH\tzzsynthoperator\n' > "$OVERRIDE"

FAILED=0

# run_case <name> <path> <content> <expect: leak|clean>
run_case() {
  local name="$1" path="$2" content="$3" expect="$4" out hasleak
  mkdir -p "$SANDBOX/$(dirname "$path")" 2>/dev/null
  printf '%s\n' "$content" > "$SANDBOX/$path"
  git -C "$SANDBOX" add -- "$path" >/dev/null 2>&1
  out=$(cd "$SANDBOX" && PSA_PATTERNS="$OVERRIDE" bash "$HOOK" 2>&1); local rc=$?
  # ORACLE (hardened after a cross-family audit, 2026-07-26): "no leak line" alone is NOT a safe
  # proxy for "verified clean" — it also describes a hook that errored, exited early, or never
  # reached the scan. That conflation would score an un-run gate as a passing one, which is the
  # exact failure mode this anchor exists to detect. So a `clean` verdict additionally REQUIRES
  # proof that the confidentiality scan actually ran and reported a pass. Anything else is
  # INCONCLUSIVE, and inconclusive fails.
  if printf '%s' "$out" | grep -qE '❌ (HIGH|MED|LOW) leak'; then
    # A printed finding that still exits 0 is a REPORT, not a gate (R3 audit, 2026-07-26). Dropping
    # a FAILED=1 would keep every leak line intact while the commit sails through, and an oracle
    # that reads only the text would call that a pass. The leak verdict therefore requires the
    # hook to have actually blocked.
    if [ "$rc" -ne 0 ]; then hasleak=leak; else hasleak=leak-printed-but-NOT-blocked; fi
  elif printf '%s' "$out" | grep -qF '[Confidentiality] public-surface scan'; then
    if printf '%s' "$out" | grep -qE '(INACTIVE|INCOMPLETE|unusable pattern|cannot run|scanner cannot)'; then
      hasleak=inconclusive-gate-not-armed
    else
      hasleak=clean
    fi
  else
    hasleak=inconclusive-scan-never-ran
  fi
  git -C "$SANDBOX" rm -q --cached -- "$path" >/dev/null 2>&1
  rm -f "$SANDBOX/$path"
  if [ "$hasleak" = "$expect" ]; then
    echo "  ✅ $name (expected $expect)"
  else
    echo "  ❌ $name — expected $expect, got $hasleak"
    printf '%s\n' "$out" | sed 's/^/       | /' | head -12
    FAILED=1
  fi
}

echo "[universal-guard] known-pair anchor (throwaway repo: $SANDBOX)"

# ── Pair 1: the closed hole. Same private token, asset vs non-asset path. ──
# README.md is NOT in the 4-axis classifier's pathspec; before the 2026-07-26 fix this case
# produced zero output and exit 0. If the guards are ever moved back below the early exit,
# THIS is the case that goes clean and fails the anchor.
run_case "non-asset path, private token   → BLOCK" \
         "README.md" "see zzsynthoperator/home" "leak"
run_case "asset path,     private token   → BLOCK" \
         "CATALOG.md" "see zzsynthoperator/home" "leak"

# ── Pair 2: no over-blocking. Ordinary content on both path classes stays clean. ──
run_case "non-asset path, clean content   → PASS " \
         "README.md" "ordinary documentation, nothing private" "clean"
run_case "asset path,     clean content   → PASS " \
         "CATALOG.md" "ordinary catalog entry, nothing private" "clean"

# ── Pair 3: credential shapes (imported 2026-07-26) vs the documentation key that must not fire. ──
# The BLOCK fixtures are ASSEMBLED AT RUNTIME from split literals, so this file's own bytes never
# contain a matching shape. Same trick the repo already uses to keep a scanner scannable (see
# .public-surface-patterns.defaults §self-match, and agentsmith's leak-gate TERMS): a fixture file
# excluded from the scan would be a hole a real secret could sit in, so it is not excluded — it is
# written so there is nothing to find. Do not "simplify" these back into single literals.
AWS_FIXTURE="AKIA""1234567890ABCDEF"
PAT_FIXTURE="ghp""_abcdefghijklmnopqrstuvwxyz012345"
run_case "AWS key shape                   → BLOCK" \
         "README.md" "aws_key = $AWS_FIXTURE" "leak"
# The documentation key is left as a plain literal on purpose: it MUST be exempted by
# PSA_PLACEHOLDER, so its presence here is itself part of the test.
run_case "AWS DOC example key             → PASS " \
         "README.md" "example only: AKIAIOSFODNN7EXAMPLE" "clean"
run_case "GitHub PAT shape                → BLOCK" \
         "README.md" "token $PAT_FIXTURE" "leak"
run_case "documented PAT placeholder      → PASS " \
         "README.md" "export GH_TOKEN=ghp_xxxx" "clean"

# ── Pair 4: MODERN token formats. Every one of these scanned CLEAN against the first import —
# the borrowed pattern list predates them. Same runtime-assembly rule as above.
FGPAT_FIXTURE="github""_pat_11ABCDEFGHIJKLMNOPQRST_abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGH"
XAPP_FIXTURE="xapp""-1-A1234567890-B1234567890-abcdefghijklmnop"
SKPROJ_FIXTURE="sk""-proj-abcdefghijklmnopqrstuvwxyz1234567890"
run_case "GitHub fine-grained PAT         → BLOCK" \
         "README.md" "gh = $FGPAT_FIXTURE" "leak"
run_case "Slack app-level token           → BLOCK" \
         "README.md" "slack = $XAPP_FIXTURE" "leak"
run_case "OpenAI project key              → BLOCK" \
         "README.md" "openai = $SKPROJ_FIXTURE" "leak"

# ── Pair 5: the exemption must be the EXACT documented key, not "anything ending in EXAMPLE".
# A shape-shaped exemption let a validly-shaped key pass merely by ending in EXAMPLE.
NEAR_MISS="AKIA""000000000EXAMPLE"
run_case "AWS key merely ENDING 'EXAMPLE'  → BLOCK" \
         "README.md" "aws = $NEAR_MISS" "leak"

# ── Pair 5-b: a placeholder must not SHIELD a real token later on the same line. pre-commit took
# only the first match per line, so `<doc key> then <real key>` scanned clean — fixed in the
# pre-push copy first and not propagated here until an R7 sweep found it. Pinned in both anchors now.
run_case "placeholder BEFORE real, one line → BLOCK" \
         "README.md" "AKIAIOSFODNN7EXAMPLE then $AWS_FIXTURE" "leak"

# ── Pair 6: instrument-fault states must FAIL CLOSED, not print a warning and pass. ──
# Each of these previously passed at commit time while BLOCKING at publish time — the two copies
# of this logic had diverged in leniency. run_state_case swaps the pattern source rather than the
# staged content, so it needs its own runner.
run_state_case() {  # <name> <override-content|__NONE__> <defaults:keep|drop> <expect-exit: block|pass>
  local name="$1" ovc="$2" defmode="$3" expect="$4" out rc got
  printf 'operator literal zzsynthoperator\n' > "$SANDBOX/README.md"
  git -C "$SANDBOX" add -- README.md >/dev/null 2>&1
  local ov="$SANDBOX/.psa_state_override"
  if [ "$ovc" = "__NONE__" ]; then rm -f "$ov"; else printf '%s\n' "$ovc" > "$ov"; fi
  local defbak="$SANDBOX/.defaults.bak"
  if [ "$defmode" = drop ]; then mv "$SANDBOX/.claude/rules/.public-surface-patterns.defaults" "$defbak" 2>/dev/null; fi
  out=$(cd "$SANDBOX" && PSA_PATTERNS="$ov" bash "$HOOK" 2>&1); rc=$?
  if [ "$defmode" = drop ]; then mv "$defbak" "$SANDBOX/.claude/rules/.public-surface-patterns.defaults" 2>/dev/null; fi
  git -C "$SANDBOX" rm -q --cached -- README.md >/dev/null 2>&1; rm -f "$SANDBOX/README.md" "$ov"
  if [ "$rc" -ne 0 ]; then got=block; else got=pass; fi
  if [ "$got" = "$expect" ]; then
    echo "  ✅ $name (expected $expect)"
  else
    echo "  ❌ $name — expected $expect, got $got (exit $rc)"
    printf '%s\n' "$out" | sed 's/^/       | /' | head -10
    FAILED=1
  fi
}
run_state_case "no patterns at all (instrument down) → BLOCK" "__NONE__" drop  block
run_state_case "malformed regex in override          → BLOCK" "HIGH	zzsynth[" keep block
run_state_case "empty override + defaults present    → PASS " ""              keep pass

# ── Pair 7: pattern-ROW malformations that are not invalid regex. Each of these used to be skipped
# in silence, i.e. a detector the author believed in that never existed, and a scan that certified
# clean. Both forms are trivially produced by hand-editing the gitignored override.
run_state_case "row with a SPACE instead of a TAB    → BLOCK" "HIGH zzsynthoperator" keep block
run_state_case "row with a CRLF line ending          → BLOCK" "HIGH	zzsynth[$(printf '\r')" keep block

# ── Pair 8: non-ASCII staged filename. git quotes it by default; a quoted name matches no real
# file, so the scan skipped the file entirely. This repo's operator works in Korean — the class is
# routine here, not exotic.
run_case "non-ASCII filename, credential  → BLOCK" \
         "유출.md" "aws = $AWS_FIXTURE" "leak"
run_case "non-ASCII filename, clean       → PASS " \
         "유출.md" "평범한 문서, 비밀 없음" "clean"

# ── Pair 8-b: a C-QUOTED path (backslash in the name). `core.quotePath=false` handles non-ASCII,
# but git still C-quotes a backslash, and a quoted spelling matches no real file — so the file was
# never scanned. R5 closed this with NUL-delimited iteration; a later refactor silently reverted the
# loop to a line-oriented read and reopened it, which its own cross-family pass caught. Pinned so the
# next refactor cannot revert it quietly.
run_case "backslash in filename, credential → BLOCK" \
         'back\slash.md' "aws = $AWS_FIXTURE" "leak"

# ── Pair 9: rename-AWAY of the protected file. `git mv`-ing the hook out of its gated path used to
# report only the DESTINATION, so the classifier saw no gate edit and the anchor fell back to the
# intact worktree copy — a commit could delete the gate while the gate reported PASS.
echo "  … rename-away of the protected path:"
RA=$(mktemp -d)
mkdir -p "$RA/templates/.git-hooks" "$RA/.claude/rules" "$RA/scripts"
cp "$HOOK" "$RA/templates/.git-hooks/pre-commit"
cp "$DEFAULTS" "$RA/.claude/rules/.public-surface-patterns.defaults"
cp "$0" "$RA/scripts/universal_guard_check.sh" 2>/dev/null || true
( cd "$RA" && git init -q && git config user.email t@example.com && git config user.name t \
  && git add -A >/dev/null 2>&1 && git commit -qm seed >/dev/null 2>&1 \
  && git mv templates/.git-hooks/pre-commit pre-commit.disabled >/dev/null 2>&1 \
  && git show HEAD:templates/.git-hooks/pre-commit > templates/.git-hooks/pre-commit 2>/dev/null \
  && chmod +x templates/.git-hooks/pre-commit ) || true
# The worktree copy is RESTORED after staging the move — that is the actual bypass being pinned
# (index says "gate deleted", worktree says "gate intact"). Without the restore the nested anchor
# aborts earlier on "hook not found" and the pair would pass for the wrong reason, leaving the
# staged-blob rename logic unpinned (R3 audit, 2026-07-26).
if ( cd "$RA" && bash scripts/universal_guard_check.sh >/dev/null 2>&1 ); then
  echo "  ❌ rename-away of the gate                → expected BLOCK, anchor PASSED"
  FAILED=1
else
  echo "  ✅ rename-away of the gate                (expected BLOCK)"
fi
rm -rf "$RA"

echo
if [ "$FAILED" -eq 0 ]; then
  echo "[universal-guard] ✅ all known pairs hold"
  exit 0
fi
echo "[universal-guard] ❌ BLOCKED — a known pair broke."
echo "  A BLOCK→PASS flip means the guard stopped covering a surface it declares it covers."
echo "  A PASS→BLOCK flip means a pattern got over-broad; over-blocking disarms the gate by"
echo "  training the PUBLIC_SURFACE_OK override into routine use. Fix the cause, not the pair."
exit 1
