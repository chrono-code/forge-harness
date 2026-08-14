#!/usr/bin/env bash
# test_lane_runner_lanes.sh — behavioural lanes for scripts/lane_runner_check.sh
#
# Why this file exists at all: until 2026-08-13 the checker that detects unrun lane suites had
# **no lane suite of its own**. It guarded its own WIRING (it fails if selfcheck.sh stops calling
# it) but nothing measured its BEHAVIOUR. That is the same shape it exists to catch, one level up —
# a check whose verdicts nobody exercises is prose with an exit code.
#
# The lanes below drive it against SYNTHETIC fixture trees, not against this repo. Driving it
# against the live tree would make every lane depend on today's suite list, so a lane would go red
# for reasons that have nothing to do with the predicate under test.
#
# Script-relative, NOT `git rev-parse --show-toplevel`: in a vendored tree rev-parse returns the
# OUTER repo and this suite would then test someone else's checkout.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$REPO_ROOT/scripts/lane_runner_check.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  ❌ %s\n' "$1"; fail=$((fail+1)); }

# ── fixture: a tree with ONE unwired suite and a selfcheck.sh that calls the checker ──────────
# The `bash scripts/lane_runner_check.sh` line is load-bearing: the checker refuses to run in a
# tree whose selfcheck.sh does not invoke it (its self-reference guard).
mkfixture() { # $1 = dir
  local d="$1"
  mkdir -p "$d/scripts"
  cp "$CHECK" "$d/scripts/lane_runner_check.sh"
  printf '#!/usr/bin/env bash\nbash scripts/lane_runner_check.sh\n' > "$d/scripts/selfcheck.sh"
  printf '#!/usr/bin/env bash\n: orphan lane suite\n'  > "$d/scripts/test_orphan_lanes.sh"
}
run() { ( cd "$1" && bash scripts/lane_runner_check.sh 2>&1 ); }
rcof() { ( cd "$1" && bash scripts/lane_runner_check.sh >/dev/null 2>&1; echo $? ); }

# ── L1 known-POSITIVE: an undeclared orphan suite must FAIL ───────────────────────────────────
# Without this arm every lane below proves nothing: a checker that passed unconditionally would
# satisfy all the "declaration suppresses it" lanes.
D="$T/l1"; mkfixture "$D"
out=$(run "$D"); rc=$(rcof "$D")
if [ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'test_orphan_lanes.sh'; then
  ok "L1 known-positive: undeclared orphan suite → rc=1 and it is named"
else
  bad "L1 known-positive did not fire (rc=$rc) — every lane below is meaningless without it"
fi

# ── L2 NO-OP: no declaration file → behaviour is exactly the L1 behaviour ─────────────────────
# This is the arm that protects THIS repo, which ships no company/ directory.
D="$T/l2"; mkfixture "$D"
out=$(run "$D")
if ! printf '%s' "$out" | grep -q 'lane_declarations'; then
  ok "L2 no-op: absent declaration file is silent (no mention in output)"
else
  bad "L2 no-op: output mentions the declaration file when none exists"
fi

# ── L3 org EXEMPT suppresses the orphan ───────────────────────────────────────────────────────
D="$T/l3"; mkfixture "$D"; mkdir -p "$D/company"
printf 'exempt:\n  - test_orphan_lanes.sh   # org-owned, runs in the org CI only\n' > "$D/company/lane_declarations.yaml"
out=$(run "$D"); rc=$(rcof "$D")
if [ "$rc" = "0" ] && printf '%s' "$out" | grep -q '1 exempt'; then
  ok "L3 org exempt: declared suite no longer fails the check (rc=0, counted exempt)"
else
  bad "L3 org exempt did not suppress (rc=$rc) — out: $(printf '%s' "$out" | tail -1)"
fi

# ── L4 org DEBT suppresses AND is counted as debt ─────────────────────────────────────────────
D="$T/l4"; mkfixture "$D"; mkdir -p "$D/company"
printf 'debt:\n  - test_orphan_lanes.sh\n' > "$D/company/lane_declarations.yaml"
out=$(run "$D"); rc=$(rcof "$D")
if [ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'declared debt'; then
  ok "L4 org debt: declared suite suppressed and reported as debt"
else
  bad "L4 org debt did not land (rc=$rc)"
fi

# ── L5 VISIBILITY: an org-declared list must never look like this repo's own zero ─────────────
D="$T/l5"; mkfixture "$D"; mkdir -p "$D/company"
printf 'debt:\n  - test_orphan_lanes.sh\n' > "$D/company/lane_declarations.yaml"
out=$(run "$D")
if printf '%s' "$out" | grep -q 'org-declared'; then
  ok "L5 visibility: output names the org file and its counts"
else
  bad "L5 visibility: org declarations are invisible in the output"
fi

# ── L6 FAIL-CLOSED on an unparseable file ─────────────────────────────────────────────────────
# The load-bearing distinction. A malformed file must NOT read as "nothing declared" — that would
# render UNMEASURED as ZERO, and it would do so on the arm where a fork is relying on the file.
D="$T/l6"; mkfixture "$D"; mkdir -p "$D/company"
printf 'exempt:\n  this line is not an entry\n' > "$D/company/lane_declarations.yaml"
out=$(run "$D"); rc=$(rcof "$D")
if [ "$rc" = "2" ] && printf '%s' "$out" | grep -q 'UNMEASURED'; then
  ok "L6 fail-closed: unparseable declaration file → rc=2 and says UNMEASURED"
else
  bad "L6 fail-closed FAILED (rc=$rc) — a malformed file was read as 'no declarations'"
fi

# ── L6b control for L6: the SAME orphan tree with a WELL-FORMED file must not exit 2 ──────────
# Without this, L6 would also pass on a checker that exits 2 for any declaration file at all.
D="$T/l6b"; mkfixture "$D"; mkdir -p "$D/company"
printf 'exempt:\n  - test_orphan_lanes.sh\n' > "$D/company/lane_declarations.yaml"
if [ "$(rcof "$D")" != "2" ]; then
  ok "L6b control: a well-formed file does NOT trip the fail-closed arm"
else
  bad "L6b control: every declaration file exits 2 — L6 proved nothing"
fi

# ── L7 unknown section is a parse failure, not a silent skip ──────────────────────────────────
D="$T/l7"; mkfixture "$D"; mkdir -p "$D/company"
printf 'allowed:\n  - test_orphan_lanes.sh\n' > "$D/company/lane_declarations.yaml"
out=$(run "$D")
if [ "$(rcof "$D")" = "2" ] && printf '%s' "$out" | grep -q "unknown section"; then
  ok "L7 unknown section → rc=2 and names the section"
else
  bad "L7 unknown section was tolerated — a typo'd header would silently declare nothing"
fi

# ── L8 the same name in both sections is ambiguous, not last-wins ─────────────────────────────
D="$T/l8"; mkfixture "$D"; mkdir -p "$D/company"
printf 'exempt:\n  - test_orphan_lanes.sh\ndebt:\n  - test_orphan_lanes.sh\n' > "$D/company/lane_declarations.yaml"
out=$(run "$D")
if [ "$(rcof "$D")" = "2" ] && printf '%s' "$out" | grep -q "both exempt and debt"; then
  ok "L8 same suite in both sections → rc=2 (ambiguous, not silently resolved)"
else
  bad "L8 double declaration was silently resolved"
fi

# ── L9 a stale entry WARNS but does not block (same voice as upstream DEBT hygiene) ───────────
# Deliberately advisory: making the downstream mirror stricter than the upstream rule it mirrors
# would train forks to delete the file, which costs more than a stale line.
D="$T/l9"; mkfixture "$D"; mkdir -p "$D/company"
printf 'exempt:\n  - test_orphan_lanes.sh\n  - test_deleted_lanes.sh\n' > "$D/company/lane_declarations.yaml"
out=$(run "$D"); rc=$(rcof "$D")
if [ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'test_deleted_lanes.sh'; then
  ok "L9 stale entry: warns and names it, does not block (rc=0)"
else
  bad "L9 stale entry handling wrong (rc=$rc)"
fi

# ── L10 comments and blank lines are not entries ──────────────────────────────────────────────
D="$T/l10"; mkfixture "$D"; mkdir -p "$D/company"
printf '# org lane declarations\n\nexempt:\n\n  - test_orphan_lanes.sh   # reason lives here\n' > "$D/company/lane_declarations.yaml"
if [ "$(rcof "$D")" = "0" ]; then
  ok "L10 comments/blank lines tolerated (a file people can annotate)"
else
  bad "L10 a commented, spaced file failed to parse"
fi

# ── L11/L12 embedded --self-test subjects (found→extend, 2026-08-14) ──────────────────────────
# A lane suite living INSIDE its subject as a `--self-test` flag has no `test_*.sh`/`*_lanes.sh`
# filename, so the suites glob above cannot see it at all — measured on this repo's own
# lane_runner_check.sh header before this feature existed: 4 such subjects had zero callers and
# nothing here said so. mkfixture without the orphan file, so these lanes isolate the self-test
# behaviour from L1's own blocking orphan.
mkfixture_clean() { # $1 = dir
  local d="$1"
  mkdir -p "$d/scripts"
  cp "$CHECK" "$d/scripts/lane_runner_check.sh"
  # A wired ordinary suite so the `suites` set is non-empty — an empty tree fails EXTRACTOR_BROKE
  # before the self-test report section runs at all, which would make L11/L12 pass vacuously.
  printf '#!/usr/bin/env bash\n: wired lane suite\n' > "$d/scripts/test_ok_lanes.sh"
  printf '#!/usr/bin/env bash\nbash scripts/lane_runner_check.sh\nbash scripts/test_ok_lanes.sh\n' > "$d/scripts/selfcheck.sh"
}

# L11 known-POSITIVE: an unwired --self-test subject is reported, advisory (rc stays 0).
D="$T/l11"; mkfixture_clean "$D"
printf '#!/usr/bin/env bash\n[ "${1:-}" = "--self-test" ] && { echo ok; exit 0; }\n' > "$D/scripts/orphan_probe.sh"
out=$(run "$D"); rc=$(rcof "$D")
if [ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'orphan_probe'; then
  ok "L11 known-positive: unwired --self-test subject named, advisory (rc=0)"
else
  bad "L11 known-positive did not fire (rc=$rc) — self-test subject not reported"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# L12 known-NEGATIVE: the SAME subject, wired through selfcheck.sh's _subj for-loop idiom, is
# NOT reported — the exact shape scripts/selfcheck.sh:478 actually uses.
D="$T/l12"; mkfixture_clean "$D"
printf '#!/usr/bin/env bash\n[ "${1:-}" = "--self-test" ] && { echo ok; exit 0; }\n' > "$D/scripts/orphan_probe.sh"
cat > "$D/scripts/selfcheck.sh" <<'SC'
#!/usr/bin/env bash
bash scripts/lane_runner_check.sh
bash scripts/test_ok_lanes.sh
for _subj in orphan_probe; do
  bash "scripts/$_subj.sh" --self-test
done
SC
out=$(run "$D")
if ! printf '%s' "$out" | grep -q 'orphan_probe'; then
  ok "L12 known-negative: --self-test subject wired via _subj for-loop is not reported"
else
  bad "L12 known-negative: wired subject still reported as unwired"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

echo "----"
echo "lane-runner lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
