#!/usr/bin/env bash
# test_revert_probe_lanes.sh — known-pair calibration for scripts/revert_probe.sh
#
# WHY THESE LANES. revert_probe.sh exists to replace 15+ hand-written revert-and-observe scripts
# with one generic tool. The two failure modes that would make it worse than the hand-rolled
# scripts it replaces are exactly the two known-pair lanes below:
#   L1  DECORATIVE anchor — a suite whose lanes never actually depend on the target file's content
#       must be reported as decorative (exit 1), not silently scored as "passed".
#   L2  REAL anchor        — the mirror-image known-positive: a suite that DOES catch the revert
#       must report the exact flipped lane and exit 0. Without this half, L1 proves nothing
#       ([[feedback_control_presence_is_not_discrimination]]).
#   L3  RESTORE GUARANTEED — the target file must come back byte-identical after the probe, in
#       BOTH the normal-completion path and the harness-error path (suite crashes / produces no
#       parseable output). A revert tool that leaves the baseline content sitting in the working
#       tree on the failure path is strictly worse than not having the tool.
#   L4+ usage guards, harness-error detection, and the git-show (not git-checkout) restore path.
#
# Fixtures are throwaway git repos + throwaway suite scripts, never this repo's own assets — a
# lane suite that references a repo-specific path fails on a fresh clone (portability_lint P9).
#
# Usage: bash scripts/test_revert_probe_lanes.sh

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUT="${FH_REVERT_PROBE_BIN:-$ROOT/scripts/revert_probe.sh}"
pass=0; fail=0
ok()  { printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
no()  { printf '  ❌ %s\n' "$1"; fail=$((fail+1)); }

if [ ! -f "$SUT" ]; then
  echo "FAIL  test_revert_probe_lanes.sh: subject absent ($SUT) — skipped is not passed"
  exit 1
fi

WORKROOT="$(mktemp -d "${TMPDIR:-/tmp}/revertlane-XXXXXX")"
trap 'rm -rf "$WORKROOT"' EXIT

# ── throwaway repo: commit 1 = baseline (missing the fix) · commit 2/HEAD = current (has the fix)
SRC="$WORKROOT/src"; mkdir -p "$SRC"
(
  cd "$SRC" && git init -q . && git config user.email l@l && git config user.name l
  printf 'value = old_and_broken\n' > guard.txt
  git add guard.txt && git commit -qm "baseline (no fix)"
  printf 'value = MARKER_OK\n' > guard.txt
  git add guard.txt && git commit -qm "current (has the fix)"
) >/dev/null 2>&1
TARGET="$SRC/guard.txt"
TARGET_SHA_BEFORE() { shasum -a 256 "$TARGET" 2>/dev/null | awk '{print $1}'; }

# ── fixture suites ──────────────────────────────────────────────────────────────────────────
# REAL anchor: the lane's pass/fail genuinely depends on the target file's content.
REAL_SUITE="$WORKROOT/real_suite.sh"
cat > "$REAL_SUITE" <<'EOF'
#!/usr/bin/env bash
if grep -q MARKER_OK "$FIXTURE_TARGET" 2>/dev/null; then
  printf '  %s %s\n' "✅" "marker present in guard.txt"
else
  printf '  %s %s\n' "❌" "marker present in guard.txt"
fi
exit 0
EOF
chmod +x "$REAL_SUITE"

# DECORATIVE anchor: always ✅, never actually reads the target file.
DECO_SUITE="$WORKROOT/deco_suite.sh"
cat > "$DECO_SUITE" <<'EOF'
#!/usr/bin/env bash
printf '  %s %s\n' "✅" "unrelated check that never reads guard.txt"
exit 0
EOF
chmod +x "$DECO_SUITE"

# HARNESS-ERROR suite: crashes before printing any ✅/❌ line at all.
CRASH_SUITE="$WORKROOT/crash_suite.sh"
cat > "$CRASH_SUITE" <<'EOF'
#!/usr/bin/env bash
echo "no verdict lines here, just noise" >&2
exit 1
EOF
chmod +x "$CRASH_SUITE"

echo "── revert_probe known-pair lanes ──────────────────────────────────"

# L1 — DECORATIVE anchor → exit 1, 0 flipped lanes
BEFORE1="$(TARGET_SHA_BEFORE)"
OUT1=$(FIXTURE_TARGET="$TARGET" bash "$SUT" "$TARGET" "$DECO_SUITE" --baseline HEAD~1 2>&1); RC1=$?
[ "$RC1" -eq 1 ] && ok "L1 decorative anchor → exit 1" || no "L1 decorative anchor: rc=$RC1 (want 1)"
printf '%s' "$OUT1" | grep -q "되돌린 레인 (✅→❌, 앵커가 실제로 잡은 것): 0개" \
  && ok "L1b report states 0 flipped lanes" || no "L1b report did not state 0 flipped lanes"
AFTER1="$(TARGET_SHA_BEFORE)"
[ "$BEFORE1" = "$AFTER1" ] && ok "L1c target file restored after decorative run" \
  || no "L1c target file NOT restored (before=$BEFORE1 after=$AFTER1)"

# L2 — REAL anchor → exit 0, exactly 1 flipped lane, names it
BEFORE2="$(TARGET_SHA_BEFORE)"
OUT2=$(FIXTURE_TARGET="$TARGET" bash "$SUT" "$TARGET" "$REAL_SUITE" --baseline HEAD~1 2>&1); RC2=$?
[ "$RC2" -eq 0 ] && ok "L2 real anchor → exit 0" || no "L2 real anchor: rc=$RC2 (want 0)"
printf '%s' "$OUT2" | grep -q "되돌린 레인 (✅→❌, 앵커가 실제로 잡은 것): 1개" \
  && ok "L2b report states exactly 1 flipped lane" || no "L2b report did not state 1 flipped lane"
printf '%s' "$OUT2" | grep -q "marker present in guard.txt" \
  && ok "L2c report names the exact flipped label" || no "L2c flipped label not named in report"
AFTER2="$(TARGET_SHA_BEFORE)"
[ "$BEFORE2" = "$AFTER2" ] && ok "L2d target file restored after real-anchor run" \
  || no "L2d target file NOT restored (before=$BEFORE2 after=$AFTER2)"

# L3 — frontier warning header always present (both suites above already exercised it; assert once)
printf '%s' "$OUT2" | grep -q "2607.22880" && ok "L3 frontier-warning citation present in output" \
  || no "L3 frontier-warning citation missing"
printf '%s' "$OUT2" | grep -q "되돌린 파일(뮤턴트) 수: 1" \
  && ok "L3b mutant-count line present (n=1 caveat)" || no "L3b mutant-count line missing"

# L4 — HARNESS ERROR: suite produces zero ✅/❌ lines → exit 10, and restore STILL happens.
# This is the lane that matters most: a crash on the baseline run is exactly the moment a naive
# implementation would leave the baseline content sitting in the working tree.
BEFORE4="$(TARGET_SHA_BEFORE)"
OUT4=$(FIXTURE_TARGET="$TARGET" bash "$SUT" "$TARGET" "$CRASH_SUITE" --baseline HEAD~1 2>&1); RC4=$?
[ "$RC4" -eq 10 ] && ok "L4 zero-label suite → exit 10 (harness error, not a silent pass)" \
  || no "L4 zero-label suite: rc=$RC4 (want 10)"
AFTER4="$(TARGET_SHA_BEFORE)"
[ "$BEFORE4" = "$AFTER4" ] && ok "L4b target file restored even on the harness-error path" \
  || no "L4b RESTORE FAILED ON HARNESS-ERROR PATH (before=$BEFORE4 after=$AFTER4) — this is the defect class this suite exists to catch"

# L5 — usage guards
OUT5=$(bash "$SUT" 2>&1); RC5=$?
[ "$RC5" -eq 2 ] && ok "L5 no args → exit 2" || no "L5 no args: rc=$RC5"
OUT5b=$(bash "$SUT" "$TARGET" 2>&1); RC5b=$?
[ "$RC5b" -eq 2 ] && ok "L5b missing suite arg → exit 2" || no "L5b missing suite arg: rc=$RC5b"
OUT5c=$(bash "$SUT" "$WORKROOT/does_not_exist.txt" "$REAL_SUITE" 2>&1); RC5c=$?
[ "$RC5c" -eq 2 ] && ok "L5c missing target file → exit 2" || no "L5c missing target file: rc=$RC5c"
OUT5d=$(bash "$SUT" "$TARGET" "$WORKROOT/does_not_exist.sh" 2>&1); RC5d=$?
[ "$RC5d" -eq 2 ] && ok "L5d missing suite file → exit 2" || no "L5d missing suite file: rc=$RC5d"
OUT5e=$(bash "$SUT" "$TARGET" "$REAL_SUITE" --baseline totally-bogus-ref 2>&1); RC5e=$?
[ "$RC5e" -eq 2 ] && ok "L5e bad --baseline ref → exit 2" || no "L5e bad baseline ref: rc=$RC5e"

# L6 — the restore path uses `git show`, never `git checkout <ref> -- <path>` (the latter STAGES
# the revert into the index — [[feedback_git_checkout_path_stages_the_revert]]). Assert the repo's
# index carries no staged change after a probe run, both directions.
( cd "$SRC" && git diff --cached --quiet ) \
  && ok "L6 no staged changes left in the index after any probe run" \
  || no "L6 the index has staged changes — a checkout-based restore would do this"
( cd "$SRC" && git status --porcelain ) | grep -q . \
  && no "L6b working tree not clean after probes (git status is non-empty)" \
  || ok "L6b working tree clean after all probes (file content == committed HEAD)"

echo "revert_probe lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
