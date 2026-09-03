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
# ONE execution per fixture, stdout AND rc from the SAME run — never two separate invocations.
# Until 2026-09-03 this was split into run()+rcof(), each running lane_runner_check.sh on its own.
# lane_runner_check.sh reads live filesystem/git state on every invocation (its own mktemp, a
# `.git` up-chain walk, `git ls-files -z`, a python3 subprocess) and is not guaranteed to answer
# identically twice in a row under CI resource pressure — so a call site combining `$(run "$D")`
# with a SEPARATE `$(rcof "$D")` could silently pair stdout from one run with the exit code of a
# DIFFERENT run. That produced an impossible-looking CI flake: rc=0 with the literal substring
# "declared debt" absent from $out, even though every rc=0 exit path in lane_runner_check.sh
# unconditionally prints that substring (traced exhaustively — see
# tracks/_meta/armC_armC-wt2_report2_2026-09-03.md). Sets LRC_OUT/LRC_RC as globals: this file is
# flat top-level (no `local` scoping across call sites), and bash functions cannot return two
# values through their exit status alone.
run_check() {   # $1 = fixture dir
  LRC_OUT="$(cd "$1" && bash scripts/lane_runner_check.sh 2>&1)"; LRC_RC=$?
}

# ── L1 known-POSITIVE: an undeclared orphan suite must FAIL ───────────────────────────────────
# Without this arm every lane below proves nothing: a checker that passed unconditionally would
# satisfy all the "declaration suppresses it" lanes.
D="$T/l1"; mkfixture "$D"
run_check "$D"; out="$LRC_OUT"; rc="$LRC_RC"
if [ "$rc" = "1" ] && printf '%s' "$out" | grep -q 'test_orphan_lanes.sh'; then
  ok "L1 known-positive: undeclared orphan suite → rc=1 and it is named"
else
  bad "L1 known-positive did not fire (rc=$rc) — every lane below is meaningless without it"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# ── IDX7 the FAIL path must EXECUTE the provenance note, not merely contain a call to it ──────
# 🟥 THIS IS THE LANE THAT THE OTHER SIX SHOULD HAVE BEEN. IDX1–IDX6 source the function and call
# it with literals, and IDX6 asserts the call site by GREP. All six were green while the real FAIL
# path died twice in a row under `set -u`:
#     line 880: INDEX_MODE: unbound variable        (the value was extracted BELOW its use)
#     line 886: index_source_note: command not found (the function was DEFINED below its use)
# Both were found by running the thing, not by the lanes. A grep that a call exists is not a test
# that the call works ([[feedback_anchor_can_be_decorative]]). This lane executes the branch.
# It asserts the SHAPE of provenance, not the exact sentence: the fixture is a non-git dir, so the
# honest answer there is the DISK one, and pinning the index wording would make the lane wrong.
D="$T/idx7"; mkfixture "$D"
run_check "$D"; out="$LRC_OUT"
if printf '%s' "$out" | grep -qE 'unbound variable|command not found|syntax error'; then
  bad "IDX7 the FAIL path errored: $(printf '%s' "$out" | grep -E 'unbound|not found|syntax' | head -1)"
elif printf '%s' "$out" | grep -qE 'ⓘ|🟥'; then
  ok "IDX7 the FAIL path actually emits a provenance line (executed, not grepped)"
else
  bad "IDX7 no provenance line on the FAIL path — the note is defined but never reached"
fi

# ── L2 NO-OP: no declaration file → behaviour is exactly the L1 behaviour ─────────────────────
# This is the arm that protects THIS repo, which ships no company/ directory.
D="$T/l2"; mkfixture "$D"
run_check "$D"; out="$LRC_OUT"
if ! printf '%s' "$out" | grep -q 'lane_declarations'; then
  ok "L2 no-op: absent declaration file is silent (no mention in output)"
else
  bad "L2 no-op: output mentions the declaration file when none exists"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# ── L3 org EXEMPT suppresses the orphan ───────────────────────────────────────────────────────
D="$T/l3"; mkfixture "$D"; mkdir -p "$D/company"
printf 'exempt:\n  - test_orphan_lanes.sh   # org-owned, runs in the org CI only\n' > "$D/company/lane_declarations.yaml"
run_check "$D"; out="$LRC_OUT"; rc="$LRC_RC"
if [ "$rc" = "0" ] && printf '%s' "$out" | grep -q '1 exempt'; then
  ok "L3 org exempt: declared suite no longer fails the check (rc=0, counted exempt)"
else
  bad "L3 org exempt did not suppress (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# ── L4 org DEBT suppresses AND is counted as debt ─────────────────────────────────────────────
D="$T/l4"; mkfixture "$D"; mkdir -p "$D/company"
printf 'debt:\n  - test_orphan_lanes.sh\n' > "$D/company/lane_declarations.yaml"
run_check "$D"; out="$LRC_OUT"; rc="$LRC_RC"
if [ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'declared debt'; then
  ok "L4 org debt: declared suite suppressed and reported as debt"
else
  bad "L4 org debt did not land (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# ── L5 VISIBILITY: an org-declared list must never look like this repo's own zero ─────────────
D="$T/l5"; mkfixture "$D"; mkdir -p "$D/company"
printf 'debt:\n  - test_orphan_lanes.sh\n' > "$D/company/lane_declarations.yaml"
run_check "$D"; out="$LRC_OUT"
if printf '%s' "$out" | grep -q 'org-declared'; then
  ok "L5 visibility: output names the org file and its counts"
else
  bad "L5 visibility: org declarations are invisible in the output"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# ── L6 FAIL-CLOSED on an unparseable file ─────────────────────────────────────────────────────
# The load-bearing distinction. A malformed file must NOT read as "nothing declared" — that would
# render UNMEASURED as ZERO, and it would do so on the arm where a fork is relying on the file.
D="$T/l6"; mkfixture "$D"; mkdir -p "$D/company"
printf 'exempt:\n  this line is not an entry\n' > "$D/company/lane_declarations.yaml"
run_check "$D"; out="$LRC_OUT"; rc="$LRC_RC"
if [ "$rc" = "2" ] && printf '%s' "$out" | grep -q 'UNMEASURED'; then
  ok "L6 fail-closed: unparseable declaration file → rc=2 and says UNMEASURED"
else
  bad "L6 fail-closed FAILED (rc=$rc) — a malformed file was read as 'no declarations'"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# ── L6b control for L6: the SAME orphan tree with a WELL-FORMED file must not exit 2 ──────────
# Without this, L6 would also pass on a checker that exits 2 for any declaration file at all.
D="$T/l6b"; mkfixture "$D"; mkdir -p "$D/company"
printf 'exempt:\n  - test_orphan_lanes.sh\n' > "$D/company/lane_declarations.yaml"
run_check "$D"; out="$LRC_OUT"; rc="$LRC_RC"
if [ "$rc" != "2" ]; then
  ok "L6b control: a well-formed file does NOT trip the fail-closed arm"
else
  bad "L6b control: every declaration file exits 2 — L6 proved nothing"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# ── L7 unknown section is a parse failure, not a silent skip ──────────────────────────────────
D="$T/l7"; mkfixture "$D"; mkdir -p "$D/company"
printf 'allowed:\n  - test_orphan_lanes.sh\n' > "$D/company/lane_declarations.yaml"
run_check "$D"; out="$LRC_OUT"; rc="$LRC_RC"
if [ "$rc" = "2" ] && printf '%s' "$out" | grep -q "unknown section"; then
  ok "L7 unknown section → rc=2 and names the section"
else
  bad "L7 unknown section was tolerated — a typo'd header would silently declare nothing (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# ── L8 the same name in both sections is ambiguous, not last-wins ─────────────────────────────
D="$T/l8"; mkfixture "$D"; mkdir -p "$D/company"
printf 'exempt:\n  - test_orphan_lanes.sh\ndebt:\n  - test_orphan_lanes.sh\n' > "$D/company/lane_declarations.yaml"
run_check "$D"; out="$LRC_OUT"; rc="$LRC_RC"
if [ "$rc" = "2" ] && printf '%s' "$out" | grep -q "both exempt and debt"; then
  ok "L8 same suite in both sections → rc=2 (ambiguous, not silently resolved)"
else
  bad "L8 double declaration was silently resolved (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# ── L9 a stale entry WARNS but does not block (same voice as upstream DEBT hygiene) ───────────
# Deliberately advisory: making the downstream mirror stricter than the upstream rule it mirrors
# would train forks to delete the file, which costs more than a stale line.
D="$T/l9"; mkfixture "$D"; mkdir -p "$D/company"
printf 'exempt:\n  - test_orphan_lanes.sh\n  - test_deleted_lanes.sh\n' > "$D/company/lane_declarations.yaml"
run_check "$D"; out="$LRC_OUT"; rc="$LRC_RC"
if [ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'test_deleted_lanes.sh'; then
  ok "L9 stale entry: warns and names it, does not block (rc=0)"
else
  bad "L9 stale entry handling wrong (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# ── L10 comments and blank lines are not entries ──────────────────────────────────────────────
D="$T/l10"; mkfixture "$D"; mkdir -p "$D/company"
printf '# org lane declarations\n\nexempt:\n\n  - test_orphan_lanes.sh   # reason lives here\n' > "$D/company/lane_declarations.yaml"
run_check "$D"; out="$LRC_OUT"; rc="$LRC_RC"
if [ "$rc" = "0" ]; then
  ok "L10 comments/blank lines tolerated (a file people can annotate)"
else
  bad "L10 a commented, spaced file failed to parse (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/       │ /'
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
run_check "$D"; out="$LRC_OUT"; rc="$LRC_RC"
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
run_check "$D"; out="$LRC_OUT"
if ! printf '%s' "$out" | grep -q 'orphan_probe'; then
  ok "L12 known-negative: --self-test subject wired via _subj for-loop is not reported"
else
  bad "L12 known-negative: wired subject still reported as unwired"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# L13 known-NEGATIVE: the SAME subject, wired through a DIRECT dispatch line — the shape
# scripts/selfcheck.sh:898/933 actually use (`bash scripts/<name>.sh ... --self-test`), no
# for-loop at all. Cross-family review 2026-08-14 caught the first draft shipping only the
# for-loop branch, which meant probe_scope_check.sh and utterance_landing_check.sh — both wired
# directly, both real — were reported UNDECLARED. This lane pins that class so it cannot silently
# come back: without it, L11/L12 alone only ever exercise the for-loop shape.
D="$T/l13"; mkfixture_clean "$D"
printf '#!/usr/bin/env bash\n[ "${1:-}" = "--self-test" ] && { echo ok; exit 0; }\n' > "$D/scripts/orphan_probe.sh"
cat > "$D/scripts/selfcheck.sh" <<'SC'
#!/usr/bin/env bash
bash scripts/lane_runner_check.sh
bash scripts/test_ok_lanes.sh
bash scripts/orphan_probe.sh --self-test >/dev/null 2>&1
SC
run_check "$D"; out="$LRC_OUT"
if ! printf '%s' "$out" | grep -q 'orphan_probe'; then
  ok "L13 known-negative: --self-test subject wired via direct dispatch is not reported"
else
  bad "L13 known-negative: directly-wired subject still reported as unwired"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# ── L14/L15 the SUBJECT'S OWN documentation is not a caller (2026-08-15) ──────────────────────
# Measured on this repo: `self-test: 10/10 wired` while directional_diff_gate.sh had ZERO callers
# (`grep -rn directional_diff_gate scripts/*.sh templates/.git-hooks/* .github/workflows/*.yml`,
# excluding the checker and the subject itself → nothing). The subject's own usage comment
# (`#   bash scripts/directional_diff_gate.sh --self-test`) matched the direct-dispatch regex, so
# the checker read the file's documentation of itself as evidence that something ran it.
#
# This is the SAME class the checker already closes one level up and, until now, only there:
# `runners` drops lane_runner_check.sh so the tool cannot certify its own DEBT list as done, and
# has_runner() skips a suite's own file, and runner_dispatches() skips comment lines. None of the
# three guards reached the --self-test branch — has_selftest_runner() scanned every runner
# including the subject, over raw text including comments. A guard that exists in one predicate
# and not in its sibling is not a guard, it is a coincidence.
#
# Two lanes because the two halves fail independently: self-exclusion alone still lets a COMMENT
# in a third file certify a subject, and comment-skipping alone still lets a subject's own
# non-comment self-reference do it.

# L14 known-POSITIVE: the subject's OWN usage comment must not count as a caller.
D="$T/l14"; mkfixture_clean "$D"
cat > "$D/scripts/orphan_probe.sh" <<'SUBJ'
#!/usr/bin/env bash
# Usage:
#   bash scripts/orphan_probe.sh --self-test        # known-pair calibration
[ "${1:-}" = "--self-test" ] && { echo ok; exit 0; }
SUBJ
run_check "$D"; out="$LRC_OUT"; rc="$LRC_RC"
if [ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'orphan_probe'; then
  ok "L14 known-positive: subject's own usage comment is not a caller — still reported unwired"
else
  bad "L14 known-positive did not fire (rc=$rc) — self-referential comment read as a dispatcher"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# L15 known-POSITIVE: a comment in a DIFFERENT file must not count either. Same discipline
# runner_dispatches() already applies to ordinary suites ("a mention is not an invocation").
D="$T/l15"; mkfixture_clean "$D"
printf '#!/usr/bin/env bash\n[ "${1:-}" = "--self-test" ] && { echo ok; exit 0; }\n' > "$D/scripts/orphan_probe.sh"
cat > "$D/scripts/selfcheck.sh" <<'SC'
#!/usr/bin/env bash
bash scripts/lane_runner_check.sh
bash scripts/test_ok_lanes.sh
# historical note: we used to run `bash scripts/orphan_probe.sh --self-test` here, removed 2026-01-01
SC
run_check "$D"; out="$LRC_OUT"; rc="$LRC_RC"
if [ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'orphan_probe'; then
  ok "L15 known-positive: a commented-out dispatch in another file is not a caller"
else
  bad "L15 known-positive did not fire (rc=$rc) — a comment read as a live dispatcher"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# L16 known-POSITIVE: a subject that names its own dispatch on a NON-comment line. This is the only
# lane that actually pins the self-exclusion guard, and it exists because a cross-family round
# (2026-08-15) showed L14/L15 do not: both of their fixtures put the self-reference in a `#` line,
# so comment-stripping alone already satisfies them and the guard could be deleted with all lanes
# still green — a repair with no control, which is the exact failure this file was written to name.
# The shape is a usage helper, because that is how a real subject names its own flag in live code
# rather than in a header comment.
D="$T/l16"; mkfixture_clean "$D"
cat > "$D/scripts/orphan_probe.sh" <<'SUBJ'
#!/usr/bin/env bash
usage() { echo "run: bash scripts/orphan_probe.sh --self-test"; }
[ "${1:-}" = "--self-test" ] && { echo ok; exit 0; }
usage
SUBJ
run_check "$D"; out="$LRC_OUT"; rc="$LRC_RC"
if [ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'orphan_probe'; then
  ok "L16 known-positive: a subject's own NON-comment self-reference is not a caller"
else
  bad "L16 known-positive did not fire (rc=$rc) — self-exclusion guard is unanchored"
  printf '%s\n' "$out" | sed 's/^/       │ /'
fi

# ── INDEX-SOURCE DISCLOSURE (2026-08-30) ──────────────────────────────────────────────────────
# WHY. This check enumerates runners from the git INDEX. In the normal (index) mode it used to say
# nothing about that, and the disclosure fired only in the anomalous DISK modes — so an author who
# had wired a suite but not staged it got "a suite nothing executes is prose" with no hint that the
# wiring existed on disk. Measured 2026-08-30: that happened, and it was the FIFTH instance in one
# day of «the tree I verified is not the tree the tool read». The note now fires on the FAIL path.
#
# 🟥 THREE STATES, NOT TWO. "read the index" · "read the disk" · "could not count" send a reader to
# three different places. Folding UNMEASURED into the index branch would render a thing that was
# never counted as a thing that was counted and found empty
# ([[feedback_not_found_is_not_zero_family]]).
_ISN=$(mktemp); sed -n '/^index_source_note()/,/^}/p' "$CHECK" > "$_ISN"
if ! grep -q 'UNMEASURED' "$_ISN"; then
  bad "IDX-harness — index_source_note did not extract from $CHECK (lanes would measure nothing)"
else
  # shellcheck disable=SC1090
  . "$_ISN"
  o=$(index_source_note "index")
  printf '%s' "$o" | grep -q "INDEX 기준" && printf '%s' "$o" | grep -q "스테이징" \
    && ok "IDX1 index mode names the index AND the staging remedy" \
    || bad "IDX1 index mode note missing/incomplete: $o"

  o=$(index_source_note "nongit")
  printf '%s' "$o" | grep -q "DISK" && ok "IDX2 nongit mode says DISK, not index" \
                                    || bad "IDX2 nongit: $o"

  o=$(index_source_note "UNMEASURED")
  printf '%s' "$o" | grep -q "못 셌다" && ok "IDX3 UNMEASURED says «could not count», not «none»" \
                                       || bad "IDX3 UNMEASURED: $o"

  # 🟥 CONTROL — an unknown/empty mode must stay SILENT. Inventing a source line for a state the
  # check does not recognise is worse than saying nothing, and without this lane the function
  # could pass IDX1–IDX3 while emitting the index sentence for every input.
  o=$(index_source_note "")
  [ -z "$o" ] && ok "IDX4 control — empty mode is silent (no invented provenance)" \
              || bad "IDX4 control — empty mode spoke: $o"

  # 🟥 CONTROL 2 — the three states must be DISTINGUISHABLE from each other, not merely non-empty.
  a=$(index_source_note "index"); b=$(index_source_note "nongit"); c=$(index_source_note "UNMEASURED")
  if [ "$a" != "$b" ] && [ "$b" != "$c" ] && [ "$a" != "$c" ]; then
    ok "IDX5 control — the three states produce three different sentences"
  else
    bad "IDX5 control — states collapsed into the same sentence"
  fi
fi
rm -f "$_ISN"

# The note must fire on the FAIL path — a function nothing calls is the very defect this file names.
if sed -n '/lane suite(s) with no runner and no declaration/,/Fix by ONE of/p' "$CHECK" \
     | grep -q 'index_source_note'; then
  ok "IDX6 the note is CALLED on the FAIL path (not just defined)"
else
  bad "IDX6 index_source_note is defined but the FAIL path does not call it"
fi

echo "----"
echo "lane-runner lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
