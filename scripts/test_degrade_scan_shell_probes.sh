#!/usr/bin/env bash
# test_degrade_scan_shell_probes.sh — regression anchor for the shell (S*) probes of
# scripts/degrade_direction_scan.sh.
#
# WHY THIS EXISTS (measured 2026-07-28, known-pair calibration):
#   The scan COLLECTED `.sh` files but every probe was Python-shaped (`except:` / `.get(k, True)` /
#   `if not x:` / `.split()`). A known-positive bash file carrying four distinct default-toward-PASS
#   shapes scored 0/4 and the scan printed "no default-toward-PASS smells in 1 scanned py/sh file".
#   That is a FALSE CLEAN — strictly worse than honest non-coverage, because a caller keying on the
#   message or exit code reads it as verified.
#   A second, larger hole surfaced in the same run: git hooks are named `pre-push` / `pre-commit`
#   (no extension) and live under a DOTTED directory, so `templates/.git-hooks` — FH's own mechanical
#   floor — reported "no scannable (py/sh) target files", exit 0.
#
# The assertions below pin: (1) the S-probes separate a known pair, (2) extensionless shell files
# under a dotted directory are collected, (3) the Python probes did not regress, and (4) two
# deliberate NON-detections stay non-detections — flagging them would push an author to delete a
# remedy or to silence a legitimate precondition guard.
#
# Usage:  bash scripts/test_degrade_scan_shell_probes.sh
# Exit:   0 = all assertions pass; 1 = a regression.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN="$REPO_ROOT/scripts/degrade_direction_scan.sh"
[ -f "$SCAN" ] || { echo "FAIL: $SCAN not found"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
ok()   { printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  ❌ %s\n' "$1"; fail=$((fail+1)); }

# Count S-probe hit lines. Deliberately counts the probe TAG, not the summary line: a summary can say
# "clean" for reasons unrelated to detection, and this anchor must not be satisfiable by prose.
s_hits() { bash "$SCAN" "$@" 2>&1 | grep -cE '\[S[0-9]:'; }
p_hits() { bash "$SCAN" "$@" 2>&1 | grep -cE '\[[A-F][0-9]?:'; }
rc_of()  { bash "$SCAN" "$@" >/dev/null 2>&1; echo $?; }

# ── Fixtures ────────────────────────────────────────────────────────────────────────
# Known POSITIVE: four distinct shell-shaped default-toward-PASS constructs, one per probe.
cat > "$TMP/known_positive.sh" <<'EOF'
#!/usr/bin/env bash
check_secret() {
  scan_output=$(run_scanner "$1") || return 0        # S1: the check errored -> report success
  if [ -z "$scan_output" ]; then
    return 0                                          # S4: empty == errored == "clean"
  fi
  return 1
}
verdict=$(get_verdict) || verdict="PASS"              # S3: unresolved -> permissive verdict
if [ "$verdict" = "BLOCK" ]; then
  exit 1
else
  exit 0                                              # S2: unenumerated case -> allow
fi
EOF

# Known NEGATIVE: the same logic written fail-closed. Must stay silent, or the probes are noise.
cat > "$TMP/known_negative.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
check_secret() {
  if ! scan_output=$(run_scanner "$1"); then
    echo "scanner failed - fail closed" >&2; return 1
  fi
  [ -n "$scan_output" ] && return 1
  return 0
}
EOF

# Extensionless hook under a DOTTED directory — the collection bug's exact shape.
mkdir -p "$TMP/.git-hooks"
cat > "$TMP/.git-hooks/pre-push" <<'EOF'
#!/usr/bin/env bash
verdict=$(classify_refs) || verdict="ALLOW"
EOF

# Deliberate NON-detections.
cat > "$TMP/non_detections.sh" <<'EOF'
#!/usr/bin/env bash
# (a) integer sanitization — the PRESCRIBED remedy for the pipefail-fallback class, not the defect.
count=$(grep -c pattern file)
if [ "${count:-0}" -gt 0 ]; then echo "found"; fi
# (b) SCOPE guards — "this run does not apply here" is not a claim that a check passed.
[ -d "$HOME/projects" ] || exit 0
[[ "$1" =~ ^[0-9]{4}$ ]] || return 0
EOF

# DEPENDENCY guards must NOT be swept up by the scope-guard exclusion above. `[ -f lib ] || exit 0`
# says "my guard library is missing, therefore allow" — the fail-open shape measured on qasp
# 2026-07-28. An earlier draft of the scoping hid it; this fixture pins the distinction.
cat > "$TMP/dependency_guards.sh" <<'EOF'
#!/usr/bin/env bash
[ -f "$GUARD_LIB" ] || exit 0
[ -x "$SCANNER" ] || exit 0
EOF

# Python known-pair — the pre-existing probes must not have regressed.
printf 'def f(x):\n    try:\n        return g(x)\n    except Exception:\n        return True\n' > "$TMP/kp.py"
printf 'def f(x):\n    try:\n        return g(x)\n    except Exception:\n        raise\n' > "$TMP/kn.py"

# ── Assertions ──────────────────────────────────────────────────────────────────────
echo "degrade-scan shell-probe regression anchor"

n=$(s_hits "$TMP/known_positive.sh")
[ "$n" -eq 4 ] && ok "known-positive .sh: 4/4 shell smells detected" \
                || bad "known-positive .sh: expected 4 S-hits, got $n (probes blind to bash again)"

rc=$(rc_of "$TMP/known_positive.sh")
[ "$rc" -eq 2 ] && ok "known-positive .sh: advisory exit 2" \
                || bad "known-positive .sh: expected exit 2, got $rc"

n=$(s_hits "$TMP/known_negative.sh")
[ "$n" -eq 0 ] && ok "known-negative .sh: silent (probes discriminate, not just fire)" \
                || bad "known-negative .sh: expected 0 S-hits, got $n"

rc=$(rc_of "$TMP/known_negative.sh")
[ "$rc" -eq 0 ] && ok "known-negative .sh: exit 0" \
                || bad "known-negative .sh: expected exit 0, got $rc"

# Directory walk must reach an extensionless shell file inside a dotted directory.
n=$(s_hits "$TMP/.git-hooks")
[ "$n" -ge 1 ] && ok "extensionless hook under a dotted dir: collected and scanned" \
                || bad "extensionless hook under a dotted dir: not scanned ($n hits) — the git-hook floor is invisible again"

# ...and so must an explicit file argument naming it.
n=$(s_hits "$TMP/.git-hooks/pre-push")
[ "$n" -ge 1 ] && ok "extensionless hook as a direct file argument: scanned" \
                || bad "extensionless hook as a direct file argument: not scanned ($n hits)"

n=$(s_hits "$TMP/non_detections.sh")
[ "$n" -eq 0 ] && ok "non-detections stay silent (\${v:-0} sanitization + precondition guards)" \
                || bad "non-detections fired $n time(s) — flagging the remedy trains authors to delete it"

# A DOTTED shell filename (`helper.bash`) must not be silently dropped from a directory walk.
# Cross-family finding (gpt-5.5, 2026-07-28), reproduced before acceptance: the directory path
# dropped it in silence while the explicit-file path reported the same file as UNSCANNABLE.
# Silent on one path, honest on the other, is the fail-open half.
mkdir -p "$TMP/dotted"
cat > "$TMP/dotted/helper.bash" <<'EOF'
#!/usr/bin/env bash
scan=$(run_scanner "$1") || return 0
EOF
cat > "$TMP/dotted/gate.sh" <<'EOF'
#!/usr/bin/env bash
scan=$(run_scanner "$1") || return 0
EOF
n=$(s_hits "$TMP/dotted")
[ "$n" -eq 2 ] && ok "dotted shell filename (helper.bash) scanned alongside gate.sh in a directory walk" \
                || bad "dotted shell filename: expected 2 S-hits, got $n — a .bash/.zsh gate is silently dropped again"

n=$(s_hits "$TMP/dependency_guards.sh")
[ "$n" -eq 2 ] && ok "dependency guards (\`[ -f lib ] || exit 0\`) still detected — scope exclusion did not swallow them" \
                || bad "dependency guards: expected 2 S-hits, got $n — 'guard library missing → allow' is hidden again"

# S5 known pair — added 2026-07-28 when the probe shipped with NO fixture of its own and every one
# of the 9 hits it produced in this repo turned out to be a false positive. Both directions are
# pinned because narrowing an all-FP probe is one edit away from a blind one.
cat > "$TMP/s5_positive.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
N=$(find /nope . -maxdepth 1 2>/dev/null | grep -c . || echo 0)
M=$(git log --oneline 2>/dev/null | wc -l || echo 0)
# WIDENED 2026-08-04. Every line below was INVISIBLE to the narrowed rule, and each was verified to
# actually produce "0\n0" before being pinned here (line count measured, not assumed):
P=$(cat /etc/hosts | grep -c . | tr -d ' ' || echo 0)   # transparent filter after the counter
Q=$(grep -c "^nosuchline$" /etc/hosts 2>/dev/null | tr -d ' ' || echo 0)  # the PR #251 shape
R=$(grep -Ec "^nosuchline$" /etc/hosts || echo 0)       # combined flag cluster -Ec
S=$(grep --count "^nosuchline$" /etc/hosts || echo 0)   # long option
T=$(grep -Fcx "nosuchline" /etc/hosts || echo 0)        # -Fcx
U=$(false | grep -c . | cat || echo 0)                  # trailing stage that always emits
V=$(false | grep -c . | grep -v nosuch || echo 0)       # trailing grep whose pattern misses the "0"
EOF
cat > "$TMP/s5_negative.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
# `a || b || echo 0` is NOT a pipeline — no stage can emit a second line.
_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }
# A pipeline whose failing stage emits nothing: the fallback supplies the only line, as intended.
J=$(printf '%s' "$x" | jq -r '.a // 0' 2>/dev/null || echo 0)
# A comment describing the defect must not be scored as the defect: cmd | grep -c . || echo 0
EOF
n=$(s_hits "$TMP/s5_positive.sh")
[ "$n" -eq 9 ] && ok "S5 known-positive: 9/9 — incl. -Ec/--count/-Fcx flag clusters, trailing \`| cat\`/\`| grep -v\`, and the no-upstream-pipe form" \
                 || bad "S5 known-positive: expected 9 S-hits, got $n — 2 = the pre-2026-08-04 rule (pipe-presence anchor); 4 = the first widening, which still missed every combined flag cluster (\`-Ec\`, \`--count\`, \`-Fcx\`) and any trailing stage outside a hardcoded name list"

n=$(s_hits "$TMP/s5_negative.sh")
[ "$n" -eq 0 ] && ok "S5 known-negative: \`||\` chains, empty-on-failure pipelines and comments stay silent" \
                || bad "S5 known-negative: $n hit(s) — S5 is noise again (9/9 FP was its measured state)"

n=$(p_hits "$TMP/kp.py")
[ "$n" -ge 1 ] && ok "python known-positive: pre-existing probes still fire" \
                || bad "python known-positive: no hits — the Python probes regressed"

n=$(p_hits "$TMP/kn.py")
[ "$n" -eq 0 ] && ok "python known-negative: still silent" \
                || bad "python known-negative: $n hit(s) — Python probes became noisy"

# The field-propagated copy must not drift from the canonical one. Two copies of the same
# normalizer diverge, and the lenient half silently drops what the strict half catches — measured
# 2026-07-28: `templates/` was 2 lines behind BEFORE this session's fix and then a full 8 KB behind
# after it, so field harnesses (the ones the cross-family gate doc actually points at) were running
# the version that scored 0/4 on the known-positive while `scripts/` scored 4/4.
TPL="$REPO_ROOT/templates/degrade_direction_scan.sh"
if [ ! -d "$REPO_ROOT/templates" ]; then
  # Package mode: the npm tarball may ship a narrower surface. Absent templates/ is not drift.
  printf '  \u2013 field-copy drift check SKIPPED (no templates/ — package mode)\n'
elif [ ! -f "$TPL" ]; then
  bad "templates/ exists but degrade_direction_scan.sh is MISSING there — field harnesses get no scan"
elif cmp -s "$TPL" "$SCAN"; then
  ok "field-propagated copy is byte-identical to scripts/ (no divergent-normalizer drift)"
else
  bad "templates/degrade_direction_scan.sh has DRIFTED from scripts/ — the field copy is what qasp/pmh run; sync it (cp scripts/degrade_direction_scan.sh templates/)"
fi

echo "----"
echo "degrade-scan shell probes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
