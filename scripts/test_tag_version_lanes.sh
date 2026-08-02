#!/usr/bin/env bash
# test_tag_version_lanes.sh — known-pair anchor for the pre-push tag/version consistency guard.
#
# WHY (measured 2026-08-02): a release tag was pushed onto the WRONG commit. `git pull --ff-only`
# had failed with a diverging-branches error that went unread, so `main` was still the pre-release
# tree; the tag landed there and `npm publish` was then attempted from that same tree. The ONLY
# thing that stopped the publish was npm's own "cannot publish over 1.4.84" collision check.
# Publishing does not un-happen — being saved by the registry's bookkeeping is luck, not a floor.
#
# Built at N=1 on purpose. This repo's escalation rule ("1-2 occurrences -> prose, N>=3 -> mechanize")
# is scoped to REVERSIBLE surfaces; a wrong tag on a public repo plus a publish from the wrong tree
# is the irreversible class, where the Surface-Class Degrade Invariant says fail-CLOSED immediately.
#
# The lanes drive the REAL hook through its real stdin contract (`<local_ref> <local_sha>
# <remote_ref> <remote_sha>`), not a re-spelling of its predicate — a hand-copied condition is a
# divergent normalizer and drifts lenient.
#
# Exit 0 = the guard discriminates · 1 = it would let a mismatched tag through, or block a good one.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO/templates/.git-hooks/pre-push"
FAILED=0; PASS=0
chk() { if [ "$1" -eq 0 ]; then PASS=$((PASS+1)); echo "  ✅ $2"; else FAILED=1; echo "  ❌ $2"; fi; }

[ -f "$HOOK" ] || { echo "FAIL  tag-version lanes: subject $HOOK missing"; exit 1; }
ZERO=0000000000000000000000000000000000000000

# A throwaway repo so the lanes never depend on this repo's live history.
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
( cd "$T" && git init -q . && git config user.email a@b && git config user.name a
  printf '{\n  "name": "x",\n  "version": "1.0.0"\n}\n' > package.json
  git add -A && git commit -qm v100
  printf '{\n  "name": "x",\n  "version": "1.1.0"\n}\n' > package.json
  git add -A && git commit -qm v110
  printf 'no manifest here\n' > README.md && rm -f package.json
  git add -A && git commit -qm nomanifest ) >/dev/null 2>&1

C_100=$(cd "$T" && git rev-parse HEAD~2)
C_110=$(cd "$T" && git rev-parse HEAD~1)
C_NONE=$(cd "$T" && git rev-parse HEAD)

# Drive the hook exactly as git does. Run it INSIDE the scratch repo so its rev-parse/cat-file
# resolve against that history. Only the tag verdict is under test here, so a non-zero exit from an
# unrelated guard would be a false red — assert on the MESSAGE, and on rc only for the clean lane.
run() { # $1=tag  $2=sha   -> prints hook output
  printf '%s %s %s %s\n' "refs/tags/$1" "$2" "refs/tags/$1" "$ZERO" \
    | ( cd "$T" && bash "$HOOK" origin 2>&1 )
}
says_mismatch() { printf '%s' "$1" | grep -q "TAG/VERSION MISMATCH"; }
blocks()        { printf '%s' "$1" | grep -q "FH Tag/Version Consistency"; }

echo "── the measured failure, reproduced ──"
out=$(run v1.1.0 "$C_100")
says_mismatch "$out" ; chk $? "known-POSITIVE: v1.1.0 on a commit whose package.json says 1.0.0 → MISMATCH"
blocks "$out"        ; chk $? "…and it BLOCKS (detection wired to a blocker, not just printed)"

echo "── the good case must not be blocked (over-blocking trains the override) ──"
out=$(run v1.1.0 "$C_110")
if says_mismatch "$out"; then chk 1 "known-NEGATIVE: matching tag/version is silent"; else chk 0 "known-NEGATIVE: matching tag/version is silent"; fi
if blocks "$out"; then chk 1 "…and does not block"; else chk 0 "…and does not block"; fi

echo "── scope: not every tag is a release tag ──"
out=$(run v1.0.0 "$C_NONE")
if says_mismatch "$out"; then chk 1 "no package.json at that commit → not applicable, not a block"; else chk 0 "no package.json at that commit → not applicable, not a block"; fi
out=$(run sprint-42 "$C_100")
if says_mismatch "$out"; then chk 1 "non-version tag name (sprint-42) is out of scope"; else chk 0 "non-version tag name (sprint-42) is out of scope"; fi

echo "── the override channel exists and is explicit ──"
grep -q 'TAG_VERSION_OK' "$HOOK" ; chk $? "TAG_VERSION_OK override present (mirrors MAIN_PUSH_OK / DESTRUCTIVE_OP_OK)"
out=$(printf '%s %s %s %s\n' "refs/tags/v1.1.0" "$C_100" "refs/tags/v1.1.0" "$ZERO" \
      | ( cd "$T" && TAG_VERSION_OK=1 bash "$HOOK" origin 2>&1 ))
if blocks "$out"; then chk 1 "override actually lets the push through"; else chk 0 "override actually lets the push through"; fi

echo ""
if [ "$FAILED" -ne 0 ]; then echo "TAG-VERSION LANES: FAIL"; exit 1; fi
echo "TAG-VERSION LANES: PASS ($PASS/$PASS)"
exit 0
