#!/usr/bin/env bash
# test_capability_entrypoint_shipping.sh — every typed CAPABILITY ENTRY POINT must be in the
# npm published file set.
#
# WHY THIS EXISTS (measured 2026-08-12, cross-family gpt-5.5 + governor widening)
# `scripts/degrade_probe_capability.sh` AND `scripts/psa_probe_capability.sh` were both absent from
# `package.json` `files[]`, while their VALIDATOR (`capability_registry_check.sh`) shipped. An npm
# consumer therefore received the thing that checks capabilities and none of the capabilities — the
# release's headline feature (scanning ```bash/```python fences) was unreachable on the typed path
# it advertises.
#
# WHY `package_coverage_check.sh` DID NOT CATCH IT — and why this is a separate check rather than a
# rule added there: that checker walks *references* (a shipped doc names a path → the path must
# ship). These two files are referenced by NOTHING but their own header. A reference-follower is
# structurally blind to an ORPHAN; you cannot fix that by adding another pattern to it. The
# discriminator here is not "is it referenced" but "is it an entry point", which is knowable from
# the filename convention alone.
#
# CLASS: third occurrence of "a shipped surface points outside files[]" in this release cycle
#   1. SKILL.md pointed at a runner that was not shipped        (caught by CI only)
#   2. AGENTS.md pointed at validate_yaml.sh, not shipped       (caught by CI only)
#   3. the capability entry points themselves, not shipped      (caught by cross-family only)
# The standing rule is N>=3 → mechanize at the front instead of relying on the next reviewer.
#
# Usage:  bash scripts/test_capability_entrypoint_shipping.sh
# Exit:   0 = every entry point ships; 1 = at least one is missing (or the check could not run).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }

pass=0; fail=0
ok()  { printf '  \342\234\205 %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \342\235\214 %s\n' "$1"; fail=$((fail+1)); }

echo "capability entry-point shipping check"

command -v node >/dev/null 2>&1 || {
  echo "  INSTRUMENT ERROR: node unavailable — files[] cannot be read. NOT a pass."; exit 1; }

# Discover entry points by convention. A DISCOVERY of zero is an instrument failure, not a clean
# result: this check exists precisely because the surface it guards is invisible to reference
# walking, so "found nothing to check" must never render as "everything ships".
ENTRIES=$(find scripts -maxdepth 1 -type f -name '*_capability.sh' 2>/dev/null | sort)
n=$(printf '%s\n' "$ENTRIES" | grep -c . || true)
n=$(( ${n:-0} + 0 ))
if [ "$n" -eq 0 ]; then
  echo "  INSTRUMENT ERROR: zero *_capability.sh files discovered — the scan did not reach its target."
  echo "  (A real zero is possible only if this repo has no typed capabilities; verify by hand before believing it.)"
  exit 1
fi

FILES_JSON=$(node -e 'process.stdout.write(JSON.stringify(require("./package.json").files||[]))' 2>/dev/null) || {
  echo "  INSTRUMENT ERROR: could not read package.json files[]"; exit 1; }

printf '%s\n' "$ENTRIES" | while IFS= read -r e; do
  [ -n "$e" ] || continue
  if node -e 'const f=JSON.parse(process.argv[1]);process.exit(f.includes(process.argv[2])?0:1)' "$FILES_JSON" "$e"; then
    echo "  ok $e"
  else
    echo "  MISSING $e"
  fi
done > "${TMPDIR:-/tmp}/cap_entry_$$.txt"

missing=$(grep -c '^  MISSING ' "${TMPDIR:-/tmp}/cap_entry_$$.txt" || true)
missing=$(( ${missing:-0} + 0 ))
shipped=$(grep -c '^  ok ' "${TMPDIR:-/tmp}/cap_entry_$$.txt" || true)
shipped=$(( ${shipped:-0} + 0 ))
cat "${TMPDIR:-/tmp}/cap_entry_$$.txt"
rm -f "${TMPDIR:-/tmp}/cap_entry_$$.txt"

if [ "$missing" -eq 0 ]; then
  ok "all $shipped capability entry point(s) are in package.json files[]"
else
  bad "$missing capability entry point(s) absent from files[] — npm consumers get the validator without the capability"
fi

# REVERSE DIRECTION (added 2026-08-12 after a cross-family round broke the first version).
# The check above walks disk → files[]. That direction alone is blind to the failure that actually
# loses a capability: MOVE OR DELETE the entry-point file. Discovery then simply does not see it,
# every remaining entry is still listed, and the lane goes green while `npm pack` ships one fewer
# capability. So also walk files[] → disk: anything declared as a capability entry point must exist.
# (A capability removed from BOTH sides is an intentional deletion and correctly flags nothing.)
DECLARED=$(node -e '
  const f=JSON.parse(process.argv[1]);
  process.stdout.write(f.filter(p=>/^scripts\/.*_capability\.sh$/.test(p)).join("\n"));
' "$FILES_JSON")
dangling=0
if [ -n "$DECLARED" ]; then
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    # `-f` alone is not enough, and both gaps were demonstrated (round 5): a SYMLINK satisfies `-f`
    # but `npm pack` does not follow it — the tarball simply omits the file — and a ZERO-BYTE file
    # satisfies every existence test while shipping an empty capability. Existence is the weakest
    # of the three properties; assert all of them.
    if [ ! -e "$d" ]; then
      echo "  DANGLING $d (declared in files[], absent on disk)"; dangling=$((dangling+1))
    elif [ -L "$d" ]; then
      echo "  SYMLINK $d (npm pack does not follow symlinks — the tarball would omit it)"; dangling=$((dangling+1))
    elif [ ! -f "$d" ]; then
      # A DIRECTORY passes -e, is not a symlink, and `-s` reports non-zero size for it — so the
      # three tests above all agreed a directory was a fine entry point (round 6). Regular-file-ness
      # is the property actually being claimed; assert it rather than three proxies for it.
      echo "  NOT-A-FILE $d (declared as an entry point but is not a regular file)"; dangling=$((dangling+1))
    elif [ ! -s "$d" ]; then
      echo "  EMPTY $d (zero bytes — ships an entry point that cannot run)"; dangling=$((dangling+1))
    fi
  done <<EOF
$DECLARED
EOF
fi
declared_n=$(printf '%s\n' "$DECLARED" | grep -c . || true); declared_n=$(( ${declared_n:-0} + 0 ))
if [ "$declared_n" -eq 0 ]; then
  bad "files[] declares ZERO capability entry points — either the convention changed or the list was gutted; a disk-only check cannot notice that"
elif [ "$dangling" -eq 0 ]; then
  ok "all $declared_n declared capability entry point(s) exist on disk (move/delete would be caught)"
else
  bad "$dangling declared capability entry point(s) missing from disk — npm would ship a broken files[] and the disk-side check alone stays green"
fi

# CONTROL — the check must be able to say NO. A checker that only ever prints ok is indistinguishable
# from a checker that is not looking; assert the negative arm on a name that cannot be in files[].
if node -e 'const f=JSON.parse(process.argv[1]);process.exit(f.includes(process.argv[2])?0:1)' \
     "$FILES_JSON" "scripts/definitely_not_shipped_$$.sh"; then
  bad "CONTROL DEAD — a nonexistent path reported as shipped; the membership test is not testing"
else
  ok "control alive — a nonexistent path is correctly reported as not shipped"
fi

echo "----"
echo "capability entry-point shipping: $pass passed, $fail failed (entries=$n, missing=$missing)"
[ "$fail" -eq 0 ] || exit 1
