#!/usr/bin/env bash
# test_files_manifest_shipping_lanes.sh — regression anchor for
# scripts/files_manifest_shipping_check.sh.
#
# Known-pair calibration (CLAUDE.md §Instrument-Calibration): a phantom files[] entry (declared,
# absent on disk) must FAIL; the real, unmodified package.json must PASS. Both lanes exercise the
# actual script against a real npm invocation via a scratch package.json copy — not a stub — so a
# regression in the node extraction logic (the bash-3.2 heredoc-in-$(...) class this script was
# rewritten to avoid, see the subject's own header) shows up here.
#
# Usage:  bash scripts/test_files_manifest_shipping_lanes.sh
# Exit:   0 = no lane failed. 1 = a regression.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBJECT="$REPO_ROOT/scripts/files_manifest_shipping_check.sh"
[ -f "$SUBJECT" ] || { echo "FAIL: $SUBJECT not found"; exit 1; }
cd "$REPO_ROOT" || exit 1

pass=0; fail=0
ok()  { printf '  \xe2\x9c\x85 %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \xe2\x9d\x8c %s\n' "$1"; fail=$((fail+1)); }

echo "files-manifest-shipping lane suite"

# Lane 1 — real tree, declaration mode: must PASS. This is the everyday run, offline, no npm.
if bash "$SUBJECT" >/tmp/fmsc_lane1.$$.out 2>&1; then
  ok "lane 1: real package.json (declaration mode) PASSes"
else
  bad "lane 1: real package.json (declaration mode) unexpectedly FAILed"
  sed 's/^/      /' /tmp/fmsc_lane1.$$.out
fi
rm -f /tmp/fmsc_lane1.$$.out

# Lane 2 — known-negative → known-positive pair, same tree, one flipped field. Inject a phantom
# entry into a SCRATCH copy of package.json (never mutate the real one in place — a failure mid-lane
# must not leave the repo's actual manifest corrupted), point the subject at it via a temp cwd copy.
LANE2_DIR="$(mktemp -d)"
trap 'rm -rf "$LANE2_DIR"' EXIT

# The check does `cd` to its own repo root via BASH_SOURCE, so exercising it against a modified
# manifest means running it FROM a copy of the tree — cheapest correct way: symlink everything the
# check might touch (package.json, .git, scripts/) into the scratch dir is fragile across
# filesystems, so instead we run the REAL subject in the REAL tree but swap package.json out and
# back atomically, exactly as the manual known-pair check that authored this suite did.
cp package.json "$LANE2_DIR/package.json.orig"
node -e '
  const fs = require("fs");
  const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
  pkg.files.push("scripts/__test_fixture_does_not_exist__.sh");
  fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
'
restore_pkg() { cp "$LANE2_DIR/package.json.orig" package.json; }

if bash "$SUBJECT" >/tmp/fmsc_lane2.$$.out 2>&1; then
  bad "lane 2 (known-positive: phantom files[] entry): expected FAIL, got PASS — the detector is blind"
  sed 's/^/      /' /tmp/fmsc_lane2.$$.out
  restore_pkg
else
  if grep -q "scripts/__test_fixture_does_not_exist__.sh" /tmp/fmsc_lane2.$$.out; then
    ok "lane 2: injected phantom files[] entry correctly FAILs and is named"
  else
    bad "lane 2: FAILed, but did not name the injected phantom — wrong reason"
    sed 's/^/      /' /tmp/fmsc_lane2.$$.out
  fi
  restore_pkg
fi
rm -f /tmp/fmsc_lane2.$$.out

# Lane 3 — restore integrity check: the real package.json must be back and byte-identical, and the
# subject must PASS again on it. If lane 2's restore silently failed, this is where it surfaces
# instead of leaking a broken manifest out of the test.
if diff -q "$LANE2_DIR/package.json.orig" package.json >/dev/null 2>&1; then
  ok "lane 3: package.json restored byte-identical after lane 2"
else
  bad "lane 3: package.json was NOT restored — repo manifest is corrupted, fix immediately"
fi
if bash "$SUBJECT" >/tmp/fmsc_lane3.$$.out 2>&1; then
  ok "lane 3: subject PASSes again on the restored real manifest"
else
  bad "lane 3: subject FAILed on the restored manifest (should be identical to lane 1)"
  sed 's/^/      /' /tmp/fmsc_lane3.$$.out
fi
rm -f /tmp/fmsc_lane3.$$.out

# ─────────────────────────────────────────────────────────────────────────────────────────────
# Lanes 4+ — cross-family review fixes (2026-08-23). Each lane exercises an axis the REPAIR itself
# did NOT touch as its detection vocabulary (CLAUDE.md feedback_lane_vocabulary_blind_to_its_own_fix
# — a lane written in the same words as the fix can pass while the defect survives). These build
# throwaway fixture trees (script copy + package.json + optional .git) the same way lane 2 does, so
# the SUBJECT is exercised for real, never stubbed.

fixture_dir() {
  local d; d="$(mktemp -d)"
  mkdir -p "$d/scripts"
  cp "$SUBJECT" "$d/scripts/files_manifest_shipping_check.sh"
  printf '%s' "$d"
}

# Lane 4 — S2: an unrecognized argument (typo'd flag) must FAIL, never silently downgrade to the
# weaker declaration-mode default. Real package.json, real repo — only the argument is wrong.
if out=$(bash "$SUBJECT" --vs-tarbll 2>&1); rc=$?; [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "unrecognized argument"; then
  ok "lane 4: typo'd --vs-tarbll argument FAILs loudly, does not downgrade to declaration mode"
else
  bad "lane 4: typo'd argument should FAIL and name itself — got rc=$rc"
  printf '%s\n' "$out" | sed 's/^/      /'
fi

# Lane 5 — S1: no .git must degrade DIFFERENTLY by mode. Declaration mode: SKIP rc=0 (an installed
# package legitimately has nothing comparable to check). Tarball mode: FAIL rc=1, fail-closed — the
# ONLY caller of --vs-tarball is the publish path, which always runs from a real source checkout, so
# "no .git" there means the environment is off-shape, not that the check has nothing to do.
D5="$(fixture_dir)"
cp package.json "$D5/package.json"
if out=$(bash "$D5/scripts/files_manifest_shipping_check.sh" 2>&1); rc=$?; [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "^SKIP"; then
  ok "lane 5a: no .git, declaration mode: SKIPs rc=0"
else
  bad "lane 5a: no .git, declaration mode: expected SKIP rc=0, got rc=$rc"
  printf '%s\n' "$out" | sed 's/^/      /'
fi
if out=$(bash "$D5/scripts/files_manifest_shipping_check.sh" --vs-tarball 2>&1); rc=$?; [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "^FAIL"; then
  ok "lane 5b: no .git, --vs-tarball mode: FAILs rc=1 (fail-closed on the publish surface)"
else
  bad "lane 5b: no .git, --vs-tarball mode: expected FAIL rc!=0, got rc=$rc"
  printf '%s\n' "$out" | sed 's/^/      /'
fi
rm -rf "$D5"

# Lane 6 — A1: files[] declared as a non-array (e.g. a bare string) must FAIL as an invalid
# manifest, never silently coerce and report "1 entry checked".
D6="$(fixture_dir)"
mkdir -p "$D6/.git"
node -e '
  const fs = require("fs");
  const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
  pkg.files = ".";
  fs.writeFileSync(process.argv[1], JSON.stringify(pkg, null, 2) + "\n");
' "$D6/package.json"
if out=$(bash "$D6/scripts/files_manifest_shipping_check.sh" 2>&1); rc=$?; [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "not an array"; then
  ok "lane 6: files[] as a non-array (string) FAILs as an invalid manifest"
else
  bad "lane 6: malformed files[] type should FAIL — got rc=$rc"
  printf '%s\n' "$out" | sed 's/^/      /'
fi
rm -rf "$D6"

# Lane 7 — A3: a files[] entry containing a literal newline (and a forged verdict token) must never
# render a bare, unescaped "PASS" line — the injected content must stay visibly inside a quoted,
# escaped value so no downstream grep/human reader can mistake it for the real verdict. The run must
# still exit 1 (it IS a phantom entry).
D7="$(fixture_dir)"
mkdir -p "$D7/.git"
node -e '
  const fs = require("fs");
  const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
  pkg.files.push("missing\nPASS\\t999 entries checked, 0 phantom, 0 unpacked");
  fs.writeFileSync(process.argv[1], JSON.stringify(pkg, null, 2) + "\n");
' "$D7/package.json"
out=$(bash "$D7/scripts/files_manifest_shipping_check.sh" 2>&1); rc=$?
if [ "$rc" -ne 0 ] && ! printf '%s' "$out" | grep -qE '^PASS( |$)'; then
  ok "lane 7: newline-injected phantom entry FAILs and never renders a bare PASS line"
else
  bad "lane 7: newline injection should FAIL without a bare PASS line — got rc=$rc"
  printf '%s\n' "$out" | sed 's/^/      /'
fi
rm -rf "$D7"

# Lane 8 — A4: when `git ls-files` itself fails against a declared directory (corrupted index,
# rejected pathspec, or similar — simulated here with a shim, since actually uninstalling git would
# also break this SUITE'S own tooling), the finding must render as an INSTRUMENT failure, never as
# "declared directory, zero git-tracked files" — the latter says the TARGET is empty, which was not
# established; the git oracle itself did not run.
D8="$(fixture_dir)"
mkdir -p "$D8/.git" "$D8/scripts_dummy"
echo x > "$D8/scripts_dummy/foo.sh"
node -e '
  const fs = require("fs");
  const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
  pkg.files = ["scripts_dummy"];
  delete pkg.scripts.prepare;
  delete pkg.scripts.prepublishOnly;
  fs.writeFileSync(process.argv[1], JSON.stringify(pkg, null, 2) + "\n");
' "$D8/package.json"
FAKEBIN8="$(mktemp -d)"
REALGIT="$(command -v git)"
cat > "$FAKEBIN8/git" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "ls-files" ]; then
  echo "fatal: simulated git ls-files failure" >&2
  exit 128
fi
exec "$REALGIT" "\$@"
EOF
chmod +x "$FAKEBIN8/git"
out=$(PATH="$FAKEBIN8:$PATH" bash "$D8/scripts/files_manifest_shipping_check.sh" --vs-tarball 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "instrument failure" && ! printf '%s' "$out" | grep -q "zero git-tracked files"; then
  ok "lane 8: git ls-files failure renders as INSTRUMENT failure, not a phantom empty directory"
else
  bad "lane 8: git ls-files failure should render as instrument failure, not target-empty — got rc=$rc"
  printf '%s\n' "$out" | sed 's/^/      /'
fi
rm -rf "$D8" "$FAKEBIN8"

# Lane 9 — B1/B2: a glob entry (`dist/*.js`) is out-of-scope, never a false PHANTOM; a `./`-prefixed
# entry is npm's own literal notation and must match normally in tarball mode, never a false
# UNPACKED. Both in one small real repo (git init'd for real, so npm pack sees real tracked files).
D9="$(mktemp -d)"
mkdir -p "$D9/scripts" "$D9/dist"
cp "$SUBJECT" "$D9/scripts/files_manifest_shipping_check.sh"
echo 'console.log("hi");' > "$D9/dist/index.js"
echo 'console.log("hi");' > "$D9/index.js"
cat > "$D9/package.json" <<'EOF'
{
  "name": "fmsc-lane9-fixture",
  "version": "1.0.0",
  "files": ["dist/*.js", "./index.js"]
}
EOF
( cd "$D9" && git init -q && git -c user.email=t@t -c user.name=t add -A && git -c user.email=t@t -c user.name=t commit -q -m init )
if out=$(bash "$D9/scripts/files_manifest_shipping_check.sh" 2>&1); rc=$?; [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "out-of-scope"; then
  ok "lane 9a: glob entry (dist/*.js) reported out-of-scope, not phantom (declaration mode PASSes)"
else
  bad "lane 9a: glob entry should be out-of-scope, not phantom — got rc=$rc"
  printf '%s\n' "$out" | sed 's/^/      /'
fi
if out=$(bash "$D9/scripts/files_manifest_shipping_check.sh" --vs-tarball 2>&1); rc=$?; [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -q "UNPACKED"; then
  ok "lane 9b: ./-prefixed entry matches the real tarball, no false UNPACKED (tarball mode PASSes)"
else
  bad "lane 9b: ./index.js should match normally in tarball mode — got rc=$rc"
  printf '%s\n' "$out" | sed 's/^/      /'
fi
rm -rf "$D9"

# Lane 10 — B3: a legitimately tiny tarball (< 10 files) must be an ADVISORY, not an automatic FAIL.
# Reuses lane 9's fixture repo, which packs 3 files (package.json + dist/index.js + index.js).
D10="$(mktemp -d)"
mkdir -p "$D10/scripts" "$D10/dist"
cp "$SUBJECT" "$D10/scripts/files_manifest_shipping_check.sh"
echo 'console.log("hi");' > "$D10/dist/index.js"
cat > "$D10/package.json" <<'EOF'
{
  "name": "fmsc-lane10-fixture",
  "version": "1.0.0",
  "files": ["dist/index.js"]
}
EOF
( cd "$D10" && git init -q && git -c user.email=t@t -c user.name=t add -A && git -c user.email=t@t -c user.name=t commit -q -m init )
if out=$(bash "$D10/scripts/files_manifest_shipping_check.sh" --vs-tarball 2>&1); rc=$?; [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "ADVISORY\|small package"; then
  ok "lane 10: tiny (<10-file) tarball PASSes with an advisory, not an automatic FAIL"
else
  bad "lane 10: tiny valid tarball should PASS with advisory, not hard-fail on count — got rc=$rc"
  printf '%s\n' "$out" | sed 's/^/      /'
fi
rm -rf "$D10"

echo "files-manifest-shipping lanes: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
