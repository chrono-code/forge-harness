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

# ── Markdown-fence lanes (added 2026-08-12) ───────────────────────────────────────────────────
# WHY THESE EXIST: the fence-extraction feature shipped with ZERO anchors, and a revert probe run
# by the pre-publish security pass proved it — neutralizing `_md_shadow()` entirely left this suite
# at "14 passed, 0 failed". A feature you can delete without reddening a lane is not covered, and
# that gap is exactly why the python3-absence hole below reached a release candidate.
MDT="$TMP/mdlanes"; mkdir -p "$MDT"
printf '# t\n\n```bash\nverify() { run || return 0; }\n```\n' > "$MDT/pos.md"
printf '# t\n\nprose only, no fence\n' > "$MDT/neg.md"

# L-MD1 known-positive: a defect inside a ```bash fence is FOUND (the whole point of the feature)
out=$(bash "$SCAN" "$MDT/pos.md" 2>&1); rc=$?
if printf '%s' "$out" | grep -q 'bash fence'; then
  ok "MD1 a defect inside a bash fence is detected and reported at the ORIGIN path"
else
  bad "MD1 fence extraction found nothing in a known-positive — feature is inert (rc=$rc)"
fi

# L-MD2 known-negative: a markdown file with NO fence must stay UNSCANNABLE, never 'clean'
out=$(bash "$SCAN" "$MDT/neg.md" 2>&1); rc=$?
if printf '%s' "$out" | grep -qi 'unscannable' && [ "$rc" -ne 0 ]; then
  ok "MD2 fence-less markdown reports UNSCANNABLE (not measured != clean)"
else
  bad "MD2 fence-less markdown did not report UNSCANNABLE (rc=$rc) — absence rendered as pass"
fi

# L-MD3 THE REGRESSION THIS SUITE WAS MISSING: with python3 unreachable, extraction is impossible.
# The file must land in UNSCANNABLE and the run must NOT exit 0. Before the fix it fell into
# neither set and vanished from the summary, so the scan reported "no smells ... exit 0".
MDBIN="$TMP/mdbin"; mkdir -p "$MDBIN"
for c in bash grep sed awk find cksum cut tr mktemp rm cat sort head wc; do
  src=$(command -v "$c" 2>/dev/null) && ln -sf "$src" "$MDBIN/$c"
done
# The stub must be CONTROLLED — a stub missing `find` makes the scan report "no scannable target
# files" and this lane would then pass for a reason unrelated to python3.
_mdbin_ok=$(env PATH="$MDBIN" bash -c 'command -v find >/dev/null 2>&1 && echo 1 || echo 0')
out=$(env PATH="$MDBIN" bash "$SCAN" "$MDT/pos.md" 2>&1); rc=$?
if [ "$_mdbin_ok" != "1" ]; then
  bad "MD3 stub PATH lacks find — lane NOT RUN (not a pass)"
elif [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'COULD NOT BE MEASURED'; then
  # NOTE the wording: this asserts UNMEASURED, not UNSCANNABLE. The two were one bucket in the
  # first fix and a re-verification round showed why that mattered — "no fence here" (a normal
  # state) and "extraction impossible" (a blind spot) must not share an exit path.
  ok "MD3 python3 unreachable -> markdown reports COULD-NOT-MEASURE and exit != 0 (never a silent clean)"
else
  bad "MD3 python3 unreachable produced rc=$rc without a could-not-measure signal — the not-found==0 hole is open"
fi

# L-MD4 shadow-name collision: `a/b.md` and `a_b.md` must not map to the same shadow file, or one
# of them is silently overwritten while the scanned COUNT still says 2 (coverage counted, detection
# impossible). Measured before the fix: the defective file disappeared and the run exited 0.
mkdir -p "$MDT/col/a"
printf '# c\n\n```bash\nverify() { run || return 0; }\n```\n' > "$MDT/col/a/b.md"
printf '# c\n\n```bash\nverify() { run || return 1; }\n```\n' > "$MDT/col/a_b.md"
out=$(bash "$SCAN" "$MDT/col/a/b.md" "$MDT/col/a_b.md" 2>&1); rc=$?
if printf '%s' "$out" | grep -q 'a/b.md'; then
  ok "MD4 colliding basenames keep separate shadows (the defective file is still reported)"
else
  bad "MD4 a/b.md vanished under collision with a_b.md — shadow name is not unique"
fi

# L-MD5/MD6 — THE DIRECTORY ARM. MD3 only exercises the single-file path, and a re-verification
# round proved that mattered: the first fix promoted "could not measure" to exit 2 ONLY when FILES
# was empty, so a directory containing one scannable .sh demoted the failure to a note line and the
# run exited 0 = CLEAN. That is the dominant path (typed capability scans directories), i.e. the
# defect this release claims to fix was still live where it actually runs.
# The stub PATH is CONTROLLED first: `command -v` under zsh can return a bare name, which produces
# a self-referential symlink and a stub with no `find` — then the scan reports "no scannable target
# files" and the lane would pass for a reason that has nothing to do with python3.
MDD="$TMP/mddir"; mkdir -p "$MDD/repo" "$MDD/bin"
printf '# t\n\n```bash\nverify() { run || return 0; }\n```\n' > "$MDD/repo/SKILL.md"
printf '#!/usr/bin/env bash\necho ok\n' > "$MDD/repo/helper.sh"
for c in bash sh grep sed awk find cut tr mktemp rm cat sort head wc printf cksum dirname basename; do
  p=$(command -v "$c" 2>/dev/null); case "$p" in /*) ln -sf "$p" "$MDD/bin/$c" ;; esac
done
_stub_md=$(env PATH="$MDD/bin" find "$MDD/repo" -type f -name '*.md' 2>/dev/null | grep -c .)
if [ "$_stub_md" != "1" ]; then
  bad "MD5/MD6 stub PATH is unusable (find missing) — lanes NOT RUN, which is not a pass"
else
  out=$(env PATH="$MDD/bin" bash "$SCAN" "$MDD/repo" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'COULD NOT BE MEASURED'; then
    ok "MD5 directory scan + python3 unreachable -> non-clean exit (not demoted to a note)"
  else
    bad "MD5 directory scan with python3 unreachable exited $rc — 'could not measure' rendered as clean"
  fi
  # cksum is the OTHER undeclared dependency: without it the uniqueness token is empty and the
  # shadow-name collision (MD4) silently returns, so it must gate the same way python3 does.
  cp -R "$MDD/bin" "$MDD/bin2"
  p=$(command -v python3 2>/dev/null); case "$p" in /*) ln -sf "$p" "$MDD/bin2/python3" ;; esac
  rm -f "$MDD/bin2/cksum"
  out=$(env PATH="$MDD/bin2" bash "$SCAN" "$MDD/repo" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'COULD NOT BE MEASURED'; then
    ok "MD6 cksum unreachable -> non-clean exit (collision guard cannot silently degrade)"
  else
    bad "MD6 cksum unreachable exited $rc — the A-1 collision returns without any signal"
  fi
  # MD8 — `cut` is the THIRD undeclared dependency of the same pipeline (`cksum | cut`). Guarding
  # cksum alone left it half-guarded: without `cut` the uniqueness token is empty and the MD4
  # collision returns. Cross-family finding (gpt-5.5, 2026-08-12); the guard shipped without an
  # anchor, so deleting it left every lane green — this is that missing half.
  cp -R "$MDD/bin" "$MDD/bin3"
  for c in python3 cksum; do
    p=$(command -v "$c" 2>/dev/null); case "$p" in /*) ln -sf "$p" "$MDD/bin3/$c" ;; esac
  done
  rm -f "$MDD/bin3/cut"
  out=$(env PATH="$MDD/bin3" bash "$SCAN" "$MDD/repo" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'COULD NOT BE MEASURED'; then
    ok "MD8 cut unreachable -> non-clean exit (the cksum|cut pipeline is guarded as a whole)"
  else
    bad "MD8 cut unreachable exited $rc — the uniqueness token silently empties and MD4's collision returns"
  fi
fi

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

# MD7 — "extraction FAILED" must not be spelled the same way as "this file has no fence".
# Cross-family finding (gpt-5.5, 2026-08-12) against the first language-split draft: an unreadable
# SKILL.md fell into UNSCANNABLE, and one clean .sh in the same directory then carried the run to
# exit 0 = clean. The scanner would have reported a corpus it could not open as verified.
MDE="$TMP/mderr"; mkdir -p "$MDE"
printf '# t\n\n```bash\nverify() { run || return 0; }\n```\n' > "$MDE/SKILL.md"
printf '#!/usr/bin/env bash\necho ok\n' > "$MDE/clean.sh"
chmod 000 "$MDE/SKILL.md" 2>/dev/null
# CONTROL: root (and some filesystems) ignore mode 000, and then this lane would pass or fail for a
# reason unrelated to the code. Prove unreadability before asserting on it.
if head -c1 "$MDE/SKILL.md" >/dev/null 2>&1; then
  printf '  – MD7 lane NOT RUN (file still readable at mode 000 — running as root?) — this is not a pass\n'
else
  out=$(bash "$SCAN" "$MDE" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'COULD NOT BE MEASURED'; then
    ok "MD7 unreadable markdown reports COULD-NOT-MEASURE even with a clean .sh beside it"
  else
    bad "MD7 unreadable markdown exited $rc without a could-not-measure signal — extraction failure is being read as 'no fence'"
  fi
fi
chmod 644 "$MDE/SKILL.md" 2>/dev/null

# ── S6 word-split lanes (added 2026-08-12) ────────────────────────────────────────────────────
# The probe claims a SHELL-BEHAVIOUR difference, so the fixtures are not enough on their own: a
# regex can look right while the premise is wrong. S6c measures the premise itself in both shells.
# The fixtures carry a ZSH shebang on purpose. S6 is scoped to surfaces whose execution shell is not
# pinned to a splitting shell (markdown fences, zsh scripts) — see S6d for the measurement that
# forced that scoping and for the bash-shebang arm that must stay silent.
cat > "$TMP/s6_positive.sh" <<'EOF'
#!/usr/bin/env zsh
for f in $recent_sessions; do echo "$f"; done
git add -- $FILES
EOF
cat > "$TMP/s6_negative.sh" <<'EOF'
#!/usr/bin/env zsh
# Command substitution DOES split in zsh — flagging it would be noise, not a finding.
for f in $(find . -name '*.md'); do echo "$f"; done
# Arrays split by element in both shells.
for f in "${FILES[@]}"; do echo "$f"; done
git add -- "${FILES[@]}"
# The portable form this probe prescribes.
printf '%s\n' "$recent_sessions" | while IFS= read -r f; do echo "$f"; done
EOF
n=$(bash "$SCAN" "$TMP/s6_positive.sh" 2>&1 | grep -cE '\[S6:')
[ "$n" -eq 2 ] && ok "S6 known-positive: 2/2 (\`for x in \$VAR\` and \`-- \$LIST\`)" \
                || bad "S6 known-positive: expected 2 hits, got $n — the zsh word-split class is invisible"

n=$(bash "$SCAN" "$TMP/s6_negative.sh" 2>&1 | grep -cE '\[S6:')
[ "$n" -eq 0 ] && ok "S6 known-negative: \$(cmd), \"\${arr[@]}\" and printf|while stay silent" \
                || bad "S6 known-negative: $n hit(s) — S6 fires on forms that behave identically in both shells"

# S6c — the PREMISE, measured rather than asserted. If zsh ever word-split a parameter expansion,
# this probe would be a style rule wearing a defect's clothes, and every finding it produced would
# be a false positive. Pinning the premise means a future zsh/bash change reddens a lane here
# instead of silently invalidating the probe.
if command -v zsh >/dev/null 2>&1; then
  _b=$(bash -c 'v="a b"; n=0; for x in $v; do n=$((n+1)); done; echo $n')
  _z=$(zsh  -c 'v="a b"; n=0; for x in $v; do n=$((n+1)); done; echo $n')
  _zc=$(zsh -c 'n=0; for x in $(echo a b); do n=$((n+1)); done; echo $n')
  if [ "$_b" = "2" ] && [ "$_z" = "1" ] && [ "$_zc" = "2" ]; then
    ok "S6c premise holds: bash splits \$VAR (2), zsh does not (1), zsh splits \$(cmd) (2)"
  else
    bad "S6c premise BROKEN: bash=\$VAR:$_b zsh=\$VAR:$_z zsh=\$(cmd):$_zc — S6's scope is no longer justified"
  fi
else
  printf '  – S6c premise lane NOT RUN (zsh unavailable) — this is not a pass\n'
fi

# S6d — APPLICABILITY. Measured 2026-08-12 across 28 hits: 7/7 real inside markdown fences,
# 21/21 false in `.sh` files with a bash shebang (bash runs those, so splitting is intended there).
# A 75%-noise probe trains dismissal — this file already paid that at 9/9 FP on S5. Both arms are
# pinned, because scoping a probe is one edit away from blinding it.
cat > "$TMP/s6_pinned_bash.sh" <<'EOF'
#!/usr/bin/env bash
for f in $recent_sessions; do echo "$f"; done
git add -- $FILES
EOF
n=$(bash "$SCAN" "$TMP/s6_pinned_bash.sh" 2>&1 | grep -cE '\[S6:')
[ "$n" -eq 0 ] && ok "S6d bash-shebang file: silent (execution shell is pinned — splitting is intended)" \
                || bad "S6d bash-shebang file fired $n time(s) — S6 is back to 21/28 noise"

# S6d-2 — a `.sh` with NO shebang is not pinned either, so the probe MUST apply. The first version
# of the scoping asked "is this a markdown shadow or a zsh script?" and therefore went silent here;
# the question that decides it is "does a shebang pin a splitting shell?" (cross-family, round 4).
cat > "$TMP/s6_no_shebang.sh" <<'EOF'
for f in $recent_sessions; do echo "$f"; done
git add -- $FILES
EOF
n=$(bash "$SCAN" "$TMP/s6_no_shebang.sh" 2>&1 | grep -cE '\[S6:')
[ "$n" -eq 2 ] && ok "S6d-2 shebang-less .sh: fires (unknown shell is not a pinned shell)" \
                || bad "S6d-2 shebang-less .sh produced $n S6 hit(s), expected 2 — the scoping excludes an unpinned surface"

# S6d-3 — /bin/sh pins a splitting shell too, so it must stay silent (the exclusion is about the
# SHELL, not about the presence of a shebang line).
cat > "$TMP/s6_posix.sh" <<'EOF'
#!/bin/sh
for f in $recent_sessions; do echo "$f"; done
EOF
n=$(bash "$SCAN" "$TMP/s6_posix.sh" 2>&1 | grep -cE '\[S6:')
[ "$n" -eq 0 ] && ok "S6d-3 /bin/sh shebang: silent (POSIX sh splits — intended semantics)" \
                || bad "S6d-3 /bin/sh file fired $n time(s) — the pinned-shell test does not recognize sh"

# SYM — a target that is a SYMLINK to a directory must still be traversed. `[ -d ]` follows the
# link but `find <link> -type f` does not, so the scan enumerated nothing and exited 0 = clean on a
# directory full of known-positives (cross-family repro, round 4). `-H` follows the argument only.
SYMREAL="$TMP/symreal"; mkdir -p "$SYMREAL"
printf '#!/usr/bin/env bash\nscan=$(run) || exit 0\n' > "$SYMREAL/bad.sh"
ln -sfn "$SYMREAL" "$TMP/symlink"
n=$(s_hits "$TMP/symlink")
[ "$n" -ge 1 ] && ok "SYM symlinked directory target is traversed (known-positive inside is found)" \
                || bad "SYM symlinked directory target produced $n hits — an entire target renders as 'no scannable files, exit 0'"

# ...and the same content in a markdown fence, where no shebang pins the shell, MUST still fire.
printf '# t\n\n```bash\nfor f in $recent_sessions; do echo "$f"; done\n```\n' > "$MDT/s6.md"
n=$(bash "$SCAN" "$MDT/s6.md" 2>&1 | grep -cE '\[S6:')
[ "$n" -eq 1 ] && ok "S6d markdown fence: still fires (the surface a human pastes into zsh)" \
                || bad "S6d markdown fence produced $n S6 hit(s), expected 1 — the scoping blinded the real class"

# S6e — a trailing COMMENT must not mask a real hit. Cross-family repro (gpt-5.5, 2026-08-12):
# `grep -vE '\[[@*]\]'` ran against the raw line, so a real defect whose comment mentioned the safe
# array form was suppressed entirely. The mirror arm is pinned too: a line matching ONLY inside its
# comment must stay silent.
cat > "$TMP/s6_comment.sh" <<'EOF'
#!/usr/bin/env zsh
git add -- $FILES # use "${arr[@]}" later
for x in $VAR; do :; done # "${arr[@]}" would be safe
echo hi   # for y in $OTHER  <- match lives only in this comment
EOF
n=$(bash "$SCAN" "$TMP/s6_comment.sh" 2>&1 | grep -cE '\[S6:')
# 3, not 2: the comment-only line IS reported. That is the accepted trade after both comment-aware
# filters were removed — the array exclusion was dead code that suppressed real hits, and the sed
# that replaced it could not tell a comment from a `#` inside a string. See the scanner's comment.
[ "$n" -eq 3 ] && ok "S6e trailing comments never mask a real hit (3/3, comment-only match reported by design)" \
                || bad "S6e expected 3 S6 hits, got $n — 2 means a comment-aware filter is masking a real defect again"

# S6f — a `#` inside a QUOTED STRING must not swallow the real hit that follows it. This is the
# defect the comment-stripping sed introduced and its removal closes (cross-family repro, round 4).
cat > "$TMP/s6_quoted_hash.sh" <<'EOF'
#!/usr/bin/env zsh
printf "#"; git add -- $FILES
printf "#"; for f in $recent_sessions; do :; done
EOF
n=$(bash "$SCAN" "$TMP/s6_quoted_hash.sh" 2>&1 | grep -cE '\[S6:')
[ "$n" -eq 2 ] && ok "S6f a quoted '#' before the defect does not hide it (2/2)" \
                || bad "S6f expected 2 S6 hits, got $n — comment stripping is back and it cannot see quotes"

# S6g — expansion OPERATORS. `for f in ${FILES:-}` is the same defect one operator away and was a
# false negative until round 5. The negative arm matters just as much: widening the pattern is what
# makes `${arr[@]}` reachable, and an array expansion splits by element in zsh too.
cat > "$TMP/s6_ops.sh" <<'EOF'
#!/usr/bin/env zsh
for f in ${FILES:-}; do :; done
for f in ${FILES:=x}; do :; done
for f in ${FILES#p}; do :; done
git add -- ${FILES:-}
EOF
n=$(bash "$SCAN" "$TMP/s6_ops.sh" 2>&1 | grep -cE '\[S6:')
[ "$n" -eq 4 ] && ok "S6g braced expansions with operators are detected (4/4)" \
                || bad "S6g expected 4 S6 hits, got $n — \${VAR:-} class is invisible again"

cat > "$TMP/s6_ops_neg.sh" <<'EOF'
#!/usr/bin/env zsh
for f in ${FILES[@]}; do :; done
for f in "${FILES[@]}"; do :; done
git add -- ${FILES[*]}
EOF
n=$(bash "$SCAN" "$TMP/s6_ops_neg.sh" 2>&1 | grep -cE '\[S6:')
[ "$n" -eq 0 ] && ok "S6g-neg array expansions stay silent even under the widened pattern" \
                || bad "S6g-neg fired $n time(s) on array expansions — the widening reintroduced the class it must exclude"

# S6i — the `/` (substitution) and `@` operators. `${FILES//old/new}` splits in bash and not in zsh
# exactly like a plain `$FILES`, and it was invisible until round 6 because `/` was missing from the
# operator class. Adding operators one incident at a time is why this lane enumerates them.
cat > "$TMP/s6_subst.sh" <<'EOF'
#!/usr/bin/env zsh
for f in ${FILES//old/new}; do :; done
for f in ${FILES/#p/q}; do :; done
git add -- ${FILES//,/ }
EOF
n=$(bash "$SCAN" "$TMP/s6_subst.sh" 2>&1 | grep -cE '\[S6:')
[ "$n" -eq 3 ] && ok "S6i substitution operators (\${V//a/b}) are detected (3/3)" \
                || bad "S6i expected 3 S6 hits, got $n — the substitution class is invisible again"

# HYPH — a target FILE whose name starts with `-`. Normalizing only the directory branch left the
# file branch feeding `-bad.sh` straight into `grep`, which parsed it as an option cluster and
# reported "no smells in 1 scanned file" (round 6). Both branches now normalize at the loop head.
HYPHD="$TMP/hyph"; mkdir -p "$HYPHD"
printf '#!/usr/bin/env bash\nscan=$(run) || exit 0\n' > "$HYPHD/-bad.sh"
( cd "$HYPHD" && bash "$SCAN" "-bad.sh" >/dev/null 2>&1 ); rc=$?
[ "$rc" -eq 2 ] && ok "HYPH a file target named -bad.sh is scanned, not swallowed as options (rc=2)" \
                || bad "HYPH file target starting with '-' returned rc=$rc — a known-positive renders as clean"
n=$(s_hits "$HYPHD")
[ "$n" -ge 1 ] && ok "HYPH-dir the same file is found through a directory walk" \
                || bad "HYPH-dir directory walk missed the hyphen-named file ($n hits)"

# S6h — `#!/usr/bin/env ksh93`: a digit is a word character, so `\bksh\b` could not match it and the
# file was treated as unpinned. ksh93 splits `$VAR`, so it is pinned and must stay silent.
cat > "$TMP/s6_ksh93.sh" <<'EOF'
#!/usr/bin/env ksh93
for f in $recent_sessions; do :; done
EOF
n=$(bash "$SCAN" "$TMP/s6_ksh93.sh" 2>&1 | grep -cE '\[S6:')
[ "$n" -eq 0 ] && ok "S6h ksh93 shebang recognized as a pinned splitting shell" \
                || bad "S6h ksh93 fired $n time(s) — versioned shell names escape the pinned-shell test"

# DISC — a directory that cannot be traversed must not render as "no scannable target files, exit 0".
# The `find` preflight proves the BINARY exists; it says nothing about THIS traversal. Cross-family
# repro used a mode-000 directory holding a known-positive.
DISCD="$TMP/discblind"; mkdir -p "$DISCD"
printf '#!/usr/bin/env bash\nscan=$(run) || exit 0\n' > "$DISCD/bad.sh"
chmod 000 "$DISCD" 2>/dev/null
if find "$DISCD" -type f >/dev/null 2>&1; then
  printf '  – DISC lane NOT RUN (directory still traversable at mode 000 — running as root?) — not a pass\n'
else
  out=$(bash "$SCAN" "$DISCD" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'COULD NOT BE MEASURED'; then
    ok "DISC unreadable directory reports COULD-NOT-MEASURE and exits non-zero"
  else
    bad "DISC unreadable directory exited $rc without a could-not-measure signal — an unenumerated surface renders clean"
  fi
fi
chmod 755 "$DISCD" 2>/dev/null

# CAP — the typed capability entry point must reach the scanner for a markdown-only target, and must
# not collapse "could not measure" into "found findings". Both were live defects on 2026-08-12.
CAPSH="$REPO_ROOT/scripts/degrade_probe_capability.sh"
if [ ! -f "$CAPSH" ]; then
  printf '  – CAP lanes NOT RUN (degrade_probe_capability.sh absent) — not a pass\n'
else
  CAPD="$TMP/capmd"; mkdir -p "$CAPD"
  printf '# t\n\n```bash\nverify() { run || return 0; }\n```\n' > "$CAPD/SKILL.md"
  bash "$CAPSH" --target "$CAPD" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 2 ] && ok "CAP1 markdown-only target reaches the scanner through the typed path (rc=2)" \
                  || bad "CAP1 markdown-only target returned rc=$rc — the headline feature is unreachable on the typed path (3 = the pre-fix NO_TARGET)"

  CAPD2="$TMP/capprose"; mkdir -p "$CAPD2"; printf '# prose only\n' > "$CAPD2/doc.md"
  bash "$CAPSH" --target "$CAPD2" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 3 ] && ok "CAP2 fence-less markdown-only target is NO_TARGET, not FINDINGS (rc=3)" \
                  || bad "CAP2 fence-less markdown returned rc=$rc, expected 3"

  # CAP3 — MIXED: one measurable finding + one unmeasurable file. "Could not measure" must win.
  CAPD3="$TMP/capmixed"; mkdir -p "$CAPD3"
  printf '# t\n\n```bash\nverify() { run || return 0; }\n```\n' > "$CAPD3/good.md"
  printf '# t\n\n```bash\nx=1\n```\n' > "$CAPD3/blind.md"
  chmod 000 "$CAPD3/blind.md" 2>/dev/null
  if head -c1 "$CAPD3/blind.md" >/dev/null 2>&1; then
    printf '  – CAP3 lane NOT RUN (file readable at mode 000 — running as root?) — not a pass\n'
  else
    bash "$CAPSH" --target "$CAPD3" >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 10 ] && ok "CAP3 findings + unmeasurable → HARNESS_ERROR (could-not-measure outranks findings)" \
                     || bad "CAP3 returned rc=$rc, expected 10 — a partly-unmeasured scan is being reported as a plain FINDINGS verdict"
  fi
  chmod 644 "$CAPD3/blind.md" 2>/dev/null

  # CAP4 — instrument absence must not be spelled as target absence. The wrapper's own pre-count
  # runs `find`; without it the count is 0 and the run reported NO_TARGET, making the HARNESS_ERROR
  # verdict unreachable for that failure while the scanner itself reports it correctly
  # (cross-family, round 4, A). The stub PATH is CONTROLLED first, as everywhere else in this file.
  CAPBIN="$TMP/capbin"; mkdir -p "$CAPBIN"
  for c in bash sh grep sed awk cut tr mktemp rm cat sort head wc printf cksum python3 dirname basename; do
    p=$(command -v "$c" 2>/dev/null); case "$p" in /*) ln -sf "$p" "$CAPBIN/$c" ;; esac
  done
  if env PATH="$CAPBIN" sh -c 'command -v bash >/dev/null 2>&1' && ! env PATH="$CAPBIN" sh -c 'command -v find >/dev/null 2>&1'; then
    env PATH="$CAPBIN" bash "$CAPSH" --target "$CAPD" >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 10 ] && ok "CAP4 find unavailable → HARNESS_ERROR (instrument absence is not target absence)" \
                     || bad "CAP4 returned rc=$rc, expected 10 — a missing instrument is reported as 'no targets' (3)"
  else
    printf '  – CAP4 lane NOT RUN (stub PATH unusable: bash missing or find still resolvable) — not a pass\n'
  fi
fi

# ── Python-fence lanes (added 2026-08-12) ─────────────────────────────────────────────────────
# ```python fences were outside the extractor, so `except: pass` — the exact shape probes A/B exist
# for — was unmeasured wherever it actually lives in this corpus (SKILL.md, not .py).
printf '# t\n\n```python\ndef f(x):\n    try:\n        return g(x)\n    except Exception:\n        return True\n```\n' > "$MDT/py.md"
out=$(bash "$SCAN" "$MDT/py.md" 2>&1)
if printf '%s' "$out" | grep -q 'python fence'; then
  ok "PY1 a defect inside a \`\`\`python fence is detected and LABELLED as a python fence"
else
  bad "PY1 python fence not scanned (or mislabelled as bash) — the surface where except/pass lives is unmeasured"
fi

# PY2 — the reason the shadow carries a .py extension instead of reusing .sh. `is_sh` keys on the
# extension, so a python fence written into a .sh shadow would be probed by the SHELL rules. The
# fixture below is python whose COMMENT contains a shell shape; a .sh shadow scores it S1.
printf '# t\n\n```python\n# scan=$(run) || exit 0\ndef f():\n    return None\n```\n' > "$MDT/py_shellish.md"
n=$(bash "$SCAN" "$MDT/py_shellish.md" 2>&1 | grep -cE '\[S[0-9]:')
[ "$n" -eq 0 ] && ok "PY2 python fences are NOT probed by the shell rules (language-split shadows hold)" \
                || bad "PY2 shell probes fired $n time(s) on python source — the shadow extension collapsed back to .sh"

# PY3 — a markdown file carrying BOTH fence languages must yield BOTH, at their own origin lines.
# NOTE the python half returns True, not `pass`: probe A keys on a permissive RETURN. The first
# draft of this lane used `pass` and went red against a correct implementation — the fixture was
# measuring nothing. Verified by running the extractor directly on both languages before editing
# any code (the shadows were fine; the assertion was not).
printf '# t\n\n```bash\nverify() { run || return 0; }\n```\n\n```python\ndef f(x):\n    try:\n        return g(x)\n    except Exception:\n        return True\n```\n' > "$MDT/both.md"
out=$(bash "$SCAN" "$MDT/both.md" 2>&1)
if printf '%s' "$out" | grep -q 'bash fence' && printf '%s' "$out" | grep -q 'python fence'; then
  ok "PY3 one markdown file yields both a bash and a python shadow (neither overwrites the other)"
else
  bad "PY3 mixed-language markdown lost one language — shadows collide by name or the loop stops at the first hit"
fi

# ── SCOPE: the scanner must HONOR its arguments ────────────────────────────────────────────────
# This is the contract templates/.git-hooks/pre-commit depends on since 2026-08-13. That hook used
# to invoke this scanner with NO ARGUMENTS — walking the whole repository — and then discard almost
# all of it through a `grep -Ff` over the staged load-bearing files it already had in hand.
# Measured: whole-repo 42s / 260 lines vs one staged file 0s / 2 lines; a sibling harness measured
# the same call at 2m07s inside a 7m54s–9m40s commit, one of which could not complete at all.
# The lane exists because the FIX IS SILENTLY REVERSIBLE: if this scanner ever stops honoring its
# arguments, the hook keeps working and simply becomes slow again — no verdict changes, nothing
# goes red, and the only symptom is a commit people start bypassing with --no-verify. The same hook
# carries the Destructive-Op gate, so a trained bypass disarms an irreversible-surface gate too.
# BEHAVIOURAL, not shape: it asserts the OUTPUT is confined to the named file, which is the property
# the hook relies on. A grep for "does the hook pass an argument" would pass on a scanner that
# accepts arguments and ignores them.
_scope_a="$TMP/scope_a.sh"; _scope_b="$TMP/scope_b.sh"
printf '#!/usr/bin/env bash\ncheck() { probe || return 0; }\n' > "$_scope_a"
printf '#!/usr/bin/env bash\nverify() { thing || exit 0; }\n' > "$_scope_b"
out=$(bash "$SCAN" "$_scope_a" 2>&1)
if printf '%s' "$out" | grep -q 'scope_a' && ! printf '%s' "$out" | grep -q 'scope_b'; then
  ok "SCOPE1 a named target is scanned and a sibling file is NOT (the scanner honors argv)"
else
  bad "SCOPE1 scanner did not confine itself to the named target — the pre-commit scoping fix is void"
fi
# The negative arm: with no argument at all it must NOT confine itself to nothing. Without this,
# a scanner that returned empty for every input would satisfy SCOPE1 and the lane would be theatre.
out=$(bash "$SCAN" "$TMP" 2>&1)
if printf '%s' "$out" | grep -q 'scope_a' && printf '%s' "$out" | grep -q 'scope_b'; then
  ok "SCOPE2 control: given the containing directory it finds BOTH (it is not simply blind)"
else
  bad "SCOPE2 control failed — the scanner found neither file, so SCOPE1 proved nothing"
fi

# ── C2: bare X-in-Y substring boolean, with the ALL-CAPS exclusion (2026-08-14) ────────────────
# Cross-family review found this exclusion shipped with zero fixtures anywhere in this repo —
# deleting the exclusion left every existing lane green, which is exactly the "advisory noise
# reduction with no anchor" class this repo's own 4-axis doctrine requires a mechanical test for.
# Two arms: the probe's own headline example (paid⊂prepaid style substring check) must still
# fire, and an ALL-CAPS collection-membership check — the shape the exclusion targets — must not.
_c2_pos="$TMP/c2_pos.sh"; _c2_neg="$TMP/c2_neg.sh"
printf 'if tok in text:\n    pass\n' > "$_c2_pos"
printf 'if name in PLACEHOLDERS:\n    pass\n' > "$_c2_neg"
out=$(bash "$SCAN" "$_c2_pos" 2>&1)
if printf '%s' "$out" | grep -q 'C2:substring-boolean'; then
  ok "C2-KP substring-boolean on a bare string var still fires"
else
  bad "C2-KP the probe's own headline shape (tok in text) no longer fires"
fi
out=$(bash "$SCAN" "$_c2_neg" 2>&1)
if ! printf '%s' "$out" | grep -q 'C2:substring-boolean'; then
  ok "C2-KN ALL-CAPS collection membership (name in PLACEHOLDERS) stays silent"
else
  bad "C2-KN the ALL-CAPS exclusion is not wired — a legitimate collection check still fires"
fi
# Revert probe, run inline rather than trusted by inspection: replace the exclusion clause's line
# in a COPY of the scanner with a bare closing paren (deleting the line outright would strand the
# preceding line's trailing backslash continuation and break the pipe chain) and confirm C2-KN
# flips to a hit — proves the exclusion is load-bearing for this specific fixture, not just
# present somewhere in the file.
_scan_reverted="$TMP/scan_reverted.sh"
_excl_line=$(grep -n "grep -vE 'in \[A-Z_\]" "$SCAN" | head -1 | cut -d: -f1)
if [ -z "$_excl_line" ]; then
  bad "C2-REVERT could not locate the exclusion line by its known text — fixture cannot run"
else
  sed "${_excl_line}s/.*/           )/" "$SCAN" > "$_scan_reverted"
  chmod +x "$_scan_reverted"
  # Captured, not piped directly — under `set -o pipefail` (this file's own top line) the scanner's
  # own advisory exit code (non-zero on any finding) would override grep's match result in a direct
  # pipe, reporting FAIL even when the fixture worked exactly as intended.
  _revert_out=$(bash "$_scan_reverted" "$_c2_neg" 2>&1)
  if printf '%s' "$_revert_out" | grep -q 'C2:substring-boolean'; then
    ok "C2-REVERT removing the exclusion line makes C2-KN fire again (the exclusion is load-bearing)"
  else
    bad "C2-REVERT removing the exclusion line did not flip C2-KN — the fixture proves nothing"
  fi
fi

echo "----"
echo "degrade-scan shell probes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
