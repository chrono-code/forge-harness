#!/usr/bin/env bash
# test_regression_guard_ci_lanes.sh — regression fixtures for Axis 1's CI path.
#
# WHY (measured 2026-08-17, and this is a production fail-open that ran silently):
# `Axis 1 — Backward Regression Check` reported a GREEN check on every PR it triggered on, while
# never once comparing anything. Two independent faults, both required:
#   ① templates/regression_guard.sh --pr took a bare BRANCH NAME and ran `git merge-base main
#      <branch>`. In a GitHub Actions PR checkout neither name resolves — actions/checkout lands
#      on a DETACHED HEAD and creates refs/remotes/origin/*, not local branches. `fetch-depth: 0`
#      was already set and is NOT the cause: the history was there, the NAMES were not. → exit 3.
#   ② the workflow's Evaluate step was `2 -> block · 1 -> warn · else -> "PASS"`, so exit 3
#      ("could not run") fell into `else` and printed a green PASS.
# Sample: 5 of 5 runs inspected (4 historical + the one that surfaced it) hit ① and rendered ②.
# Scope stated honestly: 5/5 SAMPLED, not an exhaustive audit of every run ever.
#
# ② is the load-bearing half. Fixing ① alone leaves the next instrument error just as green,
# because `else` swallows every code nobody enumerated.
#
# These lanes assert BOTH directions, and include a REVERT PROBE: the fail-closed branch is
# neutralized and the suite must go red at exactly that lane — an anchor nobody has watched fail
# is an anchor nobody knows is alive.
#
# Usage: bash scripts/test_regression_guard_ci_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF="$REPO_ROOT/.github/workflows/regression-guard.yml"
GUARD="$REPO_ROOT/templates/regression_guard.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
FAIL=0

# ── instrument calibration ───────────────────────────────────────────────────
# Extract the workflow's verdict logic and PROVE it arrived. An empty extraction would let every
# lane "pass" against nothing — the exact class this suite exists to close.
# Extracted with stdlib only. PyYAML is NOT a declared dependency of this repo, and this suite
# runs inside selfcheck.sh — a missing module here would block unrelated legitimate commits with
# an error about the wrong thing (cross-family finding, 2026-08-17).
python3 - "$WF" > "$T/eval.sh" <<'PYX'
import sys, re
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
try:
    i = next(k for k, l in enumerate(lines) if l.strip() == "- name: Evaluate result")
except StopIteration:
    sys.exit(0)                      # emit nothing -> the calibration check below aborts loudly
j = next(k for k in range(i, len(lines)) if lines[k].strip().startswith("run:"))
indent = len(lines[j + 1]) - len(lines[j + 1].lstrip())
body = []
for l in lines[j + 1:]:
    if l.strip() and (len(l) - len(l.lstrip())) < indent:
        break
    body.append(l[indent:])
run = "\n".join(body)
run = run.replace("${{ steps.guard.outputs.exit_code }}", "$EXIT_IN")
run = run.replace("${{ steps.guard.outputs.scanned }}", "$SCANNED_IN")
sys.stdout.write('EXIT="$EXIT_IN"\n' + re.sub(r"^EXIT=.*\n", "", run, count=1, flags=re.M))
PYX
if ! grep -q 'could NOT RUN' "$T/eval.sh"; then
  echo "❌ HARNESS-ERROR — the workflow's Evaluate logic did not extract from $WF."
  echo "   Lanes below would measure an empty script. Aborting rather than reporting green."
  exit 1
fi

verdict() { # $1=exit_code $2=scanned ; echoes rc + first line
  local out rc
  out=$(EXIT_IN="$1" SCANNED_IN="$2" bash "$T/eval.sh" 2>&1); rc=$?
  printf '%s|%s' "$rc" "$(printf '%s' "$out" | head -1)"
}
lane() { # $1=id $2=exit $3=scanned $4=expect(ok|fail) $5=substring
  local r; r=$(verdict "$2" "$3"); local rc="${r%%|*}" msg="${r#*|}"
  local got=ok; [ "$rc" -ne 0 ] && got=fail
  if [ "$got" = "$4" ] && printf '%s' "$msg" | grep -q "$5"; then
    printf '  ✅ %-30s rc=%s  %s\n' "$1" "$rc" "$(printf '%s' "$msg" | cut -c1-58)"
  else
    printf '  ❌ %-30s expected %s+/%s/, got rc=%s %s\n' "$1" "$4" "$5" "$rc" "$msg"; FAIL=1
  fi
}

echo "== Evaluate-step lanes =="
lane L1-clean-scanned   0 yes ok   "PASS — scanned"
lane L2-skip-not-a-pass 0 no  ok   "NOT a pass"
lane L2b-unknown-typed  0 unknown fail "wrote no typed result"
lane L3-s-tier-warn     1 yes ok   "warning"
lane L4-m-tier-block    2 yes fail "BLOCK"
lane L5-instrument-3    3 yes fail "could NOT RUN"
lane L6-unknown-99     99 yes fail "could NOT RUN"
lane L7-empty-output   ""  yes fail "could NOT RUN"

echo "== script lane — ref resolution under a CI-shaped checkout =="
# Real reproduction: a detached-HEAD clone with no local branch refs, which is what broke ①.
CL="$T/clone"
if git -C "$REPO_ROOT" clone -q --no-local "$REPO_ROOT" "$CL" 2>/dev/null; then
  git -C "$CL" checkout -q --detach HEAD
  # 🟥 The first version of this lane claimed "no local branch refs" and did NOT create that
  # state — `git clone` makes one, so the resolver matched the FIRST candidate and the lane never
  # exercised the CI shape it advertised (cross-family finding, 2026-08-17). Delete every local
  # branch so only refs/remotes/* remain — what actions/checkout actually leaves behind.
  for _b in $(git -C "$CL" for-each-ref --format='%(refname:short)' refs/heads); do
    git -C "$CL" branch -q -D "$_b" >/dev/null 2>&1 || true   # noqa: destructive-op (throwaway clone)
  done
  _left=$(git -C "$CL" for-each-ref --format='%(refname:short)' refs/heads | wc -l | tr -d ' ')
  cp "$GUARD" "$CL/templates/regression_guard.sh"
  BR=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)
  SHA=$(git -C "$REPO_ROOT" rev-parse HEAD)

  # L8a — a bare NAME must now be REFUSED. Name-guessing is what let a fork PR branch called
  # `main` resolve to this repo's main and compare it to itself.
  out=$(cd "$CL" && bash templates/regression_guard.sh --pr "$BR" "origin/main" 2>&1); rc=$?
  if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'does not resolve'; then
    printf '  ✅ %-30s bare name refused (local refs left: %s)\n' "L8a-name-refused" "$_left"
  else
    printf '  ❌ %-30s expected exit 3 refusal, got rc=%s: %s\n' "L8a-name-refused" "$rc" "$(printf '%s' "$out" | head -1)"; FAIL=1
  fi

  # L8b — an unambiguous SHA must resolve and actually compute a merge-base.
  out=$(cd "$CL" && bash templates/regression_guard.sh --pr "$SHA" "origin/main" 2>&1); rc=$?
  if printf '%s' "$out" | grep -q 'PR MODE: merge-base='; then
    printf '  ✅ %-30s %s\n' "L8b-sha-resolves" "$(printf '%s' "$out" | grep -o 'merge-base=[^ ]*')"
  else
    printf '  ❌ %-30s SHA did not resolve (rc=%s): %s\n' "L8b-sha-resolves" "$rc" "$(printf '%s' "$out" | head -1)"; FAIL=1
  fi
else
  printf '  ⚠️  %-30s clone unavailable — lanes SKIPPED (not passed)\n' "L8-ci-shape"
fi

echo "== revert probe — is the fail-closed branch load-bearing, or decoration? =="
# Neutralize ONLY the catch-all failure branch; L5/L6/L7 must go red and nothing else may move.
sed 's/exit 1 ;;/: ;;/' "$T/eval.sh" > "$T/eval_neutered.sh"
if ! diff -q "$T/eval.sh" "$T/eval_neutered.sh" >/dev/null; then
  r=$(EXIT_IN=3 SCANNED_IN=yes bash "$T/eval_neutered.sh" >/dev/null 2>&1; echo $?)
  if [ "$r" -eq 0 ]; then
    echo "  ✅ revert probe            neutralizing the catch-all makes exit 3 pass again → anchor is alive"
  else
    echo "  ❌ revert probe            neutralized branch STILL fails — the lane is not testing what it claims"; FAIL=1
  fi
else
  echo "  ❌ revert probe            neutralization was a no-op — the probe measured nothing"; FAIL=1
fi

[ $FAIL -eq 0 ] && { echo "✅ all regression-guard CI lanes behave"; exit 0; }
echo "❌ regression-guard CI lane regression"; exit 1
