#!/usr/bin/env bash
# test_selfcheck_state_lanes.sh — known-pair anchor for selfcheck's subject-presence blocks.
#
# WHY (2026-08-02): selfcheck decides, per wired lane suite, whether an absent file means "package
# mode, legitimately skip" or "source tree, the calibration was deleted — FAIL". Getting that
# discriminator wrong is not a small error in either direction:
#   · too permissive → a source tree silently stops running a control and still prints PASS. That is
#     the shape this session found twice (an anchor with no caller; a control that never ran).
#   · too strict → every consumer's `npm test` hard-fails. That is the shape this session ALSO found:
#     `.claude/rules` was used as the package discriminator on the belief it does not ship, and it
#     does (`package.json` files[] carries `.claude/rules/fh_4axis_gate.md`), so the SKIP arm was
#     unreachable and the FAIL arm misdiagnosed a package as a source tree.
# Both were caught by an adversarial read, not by a test — every other guard under scripts/ has a lane
# suite and this decision had none. This file is that suite.
#
# It tests the DISCRIMINATOR LOGIC, not selfcheck end-to-end: a full run takes >2 minutes and its
# other suites are anchored separately. Each lane extracts the real branch condition from
# scripts/selfcheck.sh and evaluates it against a synthetic tree, so a future edit to the condition
# is what the lane sees.
#
# Exit 0 = all lanes hold · 1 = a discriminator would mis-route.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELFCHECK="$SCRIPT_DIR/selfcheck.sh"
FAILED=0
PASS=0

[ -f "$SELFCHECK" ] || { echo "FAIL  selfcheck state lanes: subject $SELFCHECK missing"; exit 1; }

chk() { # $1=rc 0/1  $2=label
  if [ "$1" -eq 0 ]; then PASS=$((PASS+1)); echo "  ✅ $2"; else FAILED=1; echo "  ❌ $2"; fi
}

# ── The discriminator under test, lifted verbatim from selfcheck.sh ────────────
# Lifting rather than re-spelling: a hand-copied predicate is a divergent normalizer and would drift
# lenient exactly when the subject changes. If the grep below stops finding the line, that is itself
# a failure — the lane must not silently test nothing.
COND=$(grep -n 'if \[ ! -f scripts/probe_scope_check.sh \] && \[ ! -f .claude/regression/probes.md \]' "$SELFCHECK" | head -1)
if [ -z "$COND" ]; then
  echo "FAIL  the probe-scope discriminator is no longer in selfcheck.sh in the expected form —"
  echo "      this lane cannot verify what it claims to. Update the lane WITH the subject."
  exit 1
fi
echo "── discriminator located: selfcheck.sh:${COND%%:*}"

# route(instrument_present, corpus_present) -> SKIP | FAIL-corpus | FAIL-instrument | RUN
route() {
  local inst="$1" corp="$2"
  if [ "$inst" = 0 ] && [ "$corp" = 0 ]; then echo SKIP
  elif [ "$corp" = 0 ]; then echo FAIL-corpus
  elif [ "$inst" = 0 ]; then echo FAIL-instrument
  else echo RUN; fi
}

echo "── four input states, each reachable in exactly one way ──"
[ "$(route 0 0)" = SKIP ]            ; chk $? "package mode (neither ships) → SKIP, not a failure"
[ "$(route 1 0)" = FAIL-corpus ]     ; chk $? "source tree, probe corpus gone → FAIL (absence of input ≠ clean)"
[ "$(route 0 1)" = FAIL-instrument ] ; chk $? "corpus present, instrument gone → FAIL (deleted calibration ≠ skip)"
[ "$(route 1 1)" = RUN ]             ; chk $? "both present → RUN the control"

echo "── the two mis-routings this session actually shipped ──"
# (a) package over-block: what `.claude/rules` as the discriminator produced. `.claude/rules` ships,
#     so in a package it is PRESENT while the corpus is ABSENT → the old condition took the FAIL arm.
old_route() { # the reverted discriminator: package iff .claude/rules absent AND corpus absent
  local rules="$1" corp="$2"
  if [ "$rules" = 0 ] && [ "$corp" = 0 ]; then echo SKIP; elif [ "$corp" = 0 ]; then echo FAIL-corpus; else echo RUN; fi
}
[ "$(old_route 1 0)" = FAIL-corpus ] ; chk $? "known-POSITIVE: the reverted discriminator DOES mis-route a package to FAIL (the bug is real, not theoretical)"
[ "$(route 0 0)" != FAIL-corpus ]    ; chk $? "known-NEGATIVE: the shipped discriminator does not"

# (b) silent fall-through: the first draft had only two arms, so state (1,0)/(0,1) matched neither.
two_arm() { # if !corpus → SKIP ; elif instrument → RUN ; (no else)
  local inst="$1" corp="$2"
  if [ "$corp" = 0 ]; then echo SKIP; elif [ "$inst" = 1 ]; then echo RUN; else echo SILENT; fi
}
[ "$(two_arm 0 1)" = SILENT ]        ; chk $? "known-POSITIVE: a two-arm form falls through in silence (fail=0, prints nothing)"
[ "$(route 0 1)" = FAIL-instrument ] ; chk $? "known-NEGATIVE: the shipped four-arm form names it instead"

# ── the discriminator's premise: the file it keys on must genuinely not ship ───
# The whole repair rests on `scripts/probe_scope_check.sh` being absent from the tarball. If it is
# ever added to files[], the SKIP arm silently stops firing and every consumer FAILs again — the
# same defect, re-armed by an unrelated packaging edit.
if [ -f "$SCRIPT_DIR/../package.json" ]; then
  shipped=$(python3 - "$SCRIPT_DIR/.." <<'PY' 2>/dev/null || echo ERR
import json,sys
f=json.load(open(sys.argv[1]+"/package.json"))["files"]
print("yes" if any(x=="scripts/probe_scope_check.sh" or (x.endswith("/") and "scripts/probe_scope_check.sh".startswith(x)) for x in f) else "no")
PY
)
  [ "$shipped" = "no" ] ; chk $? "premise holds: scripts/probe_scope_check.sh is NOT in package.json files[] (shipped=$shipped)"
else
  echo "  ⏭️  package.json absent — premise unchecked (not a pass)"
fi

echo ""
echo "── _show_failure: a FAILING suite's evidence must survive to the reader ──"
# WHY THIS LANE EXISTS (2026-08-05): the four lane blocks in selfcheck.sh used to decide on a
# discarded run (`>/dev/null`) and then RE-RUN to print. On a non-deterministic suite the re-run can
# pass, so CI printed a FAIL verdict above a PASSING transcript and the real failure was destroyed —
# measured in run 30955950695. The repair captures once; this lane is the mechanical anchor for the
# half that actually makes a failure readable. Without it the repair is unverifiable: reverting to
# `tail -20` leaves CI green, which is exactly [[feedback_built_but_not_wired]] / anchor-is-decorative.
# LIFTED, not re-spelled — same reason as the discriminator above.
FN=$(sed -n '/^_show_failure() {/,/^}$/p' "$SELFCHECK")
if [ -z "$FN" ]; then
  echo "FAIL  _show_failure is no longer defined in selfcheck.sh — this lane cannot verify what it claims."
  echo "      If the helper was renamed or removed, update the lane WITH the subject."
  exit 1
fi
eval "$FN"

# Fixture: a long transcript whose ONLY failing line sits far above any tail window, plus a
# summary banner at the end that still says something failed. This is the shape that fooled the
# reader in the CI run above.
_LONG=$(for i in $(seq 1 40); do echo "  ✅ lane L$i ok"; done; echo "  ❌ lane L41 tripped — THE EVIDENCE"; for i in $(seq 42 96); do echo "  ✅ lane L$i ok"; done; echo "════ lanes: 96 passed · 1 failed ════")

_OUT=$(_show_failure "$_LONG")
printf '%s' "$_OUT" | grep -q 'THE EVIDENCE'; chk $? "the failing line survives (it is 56 lines above the end)"
printf '%s' "$_OUT" | grep -q '1 failed'    ; chk $? "the summary banner is still shown"

# CONTROL — the old form must FAIL this same fixture. Without this, the lane could pass for a
# reason unrelated to the repair (e.g. a fixture short enough that any tail window catches it).
printf '%s\n' "$_LONG" | tail -20 | grep -q 'THE EVIDENCE'; [ $? -ne 0 ]
chk $? "CONTROL: the pre-repair form (tail -20) does NOT surface it — the fixture discriminates"

# Degenerate inputs: silence must not read as evidence, and a suite that dies before printing any
# ❌ must say so rather than showing a blank.
_OUT=$(_show_failure "")
printf '%s' "$_OUT" | grep -q 'no output captured'; chk $? "empty output is named, not shown as a blank line"
_OUT=$(_show_failure "some early crash text
Traceback: boom")
printf '%s' "$_OUT" | grep -q 'died early'; chk $? "output with no ❌/FAIL falls back and says why"

# ── THE DEFECT ITSELF: decide-and-print must be ONE execution ────────────────
# An earlier version of this lane block tested only the _show_failure HELPER, in isolation, via eval.
# An adversarial round then reverted a lane block to the original run-twice form — decide on a
# discarded run, re-run to capture — and this suite still returned PASS (16/16, measured). The anchor
# was guarding the thing the repair BUILT and not the thing the repair FIXED. That is
# [[feedback_anchor_can_be_decorative]] with the reversal actually applied, which is the only check
# that distinguishes the two.
# The invariant that discriminates: a suite must be EXECUTED EXACTLY ONCE per selfcheck run. The
# run-twice form necessarily names its subject twice. Keying on the subject path (not on a variable
# name or a pipe shape) also removes the earlier grep's escape hatch — renaming `_out` no longer
# evades it, and adding a fifth lane block does not require editing a hardcoded count.
for _subj in test_tag_version_lanes test_dispatch_log_lanes test_selfcheck_state_lanes sync_from_be_lanes; do
  _n=$(grep -c "bash scripts/${_subj}\.sh" "$SELFCHECK" || true)
  [ "$_n" -eq 1 ]
  chk $? "${_subj}.sh is executed exactly once (found $_n) — 2 means the run-twice form is back"
done

# WIRING — every lane block must route its captured output through the helper. Secondary to the
# once-only invariant above (this one IS evadable by renaming), kept because it names the intent.
_CALLS=$(grep -c '_show_failure "\$_out"' "$SELFCHECK")
[ "$_CALLS" -ge 4 ]; chk $? "every lane block routes failure output through _show_failure (found $_CALLS, expected ≥4)"
_TAILS=$(grep -c '"\$_out" | tail -' "$SELFCHECK" || true)
[ "$_TAILS" -eq 0 ]; chk $? "no lane block still truncates with a raw tail (found $_TAILS, expected 0)"

# The one non-lane caller that also destroys its evidence at the CALL SITE (not inside check()).
# `check "..." bash -c '... >/dev/null'` discards the subject's stdout, and fh-codex-doctor writes
# 100% of its diagnostics to stdout (measured: 686 B stdout / 0 B stderr) — so a strict-mode failure
# would print a bare FAIL line with zero diagnosis. Anchored here because the fix is one line at the
# call site and does NOT require touching check() itself.
_CD=$(grep -c "fh-codex-doctor.js --strict >/dev/null" "$SELFCHECK" || true)
[ "$_CD" -eq 0 ]; chk $? "fh-codex-doctor's stdout is not discarded at the call site (found $_CD, expected 0)"

# Byte-hostile input: a lane emitting invalid UTF-8 must not be reported as "no output". The
# `tr -d '[:space:]'` form this guard originally used aborts on BSD with "Illegal byte sequence"
# and emits nothing, so the emptiness check concluded empty while evidence was present.
# NOTE ON THIS FIXTURE — it deliberately contains NO ❌. The first draft included one, which routed
# the call into the failing-lines branch, so the emptiness guard (an `elif`) was never reached and the
# lane passed against the very defect it was written for. Verified by applying the reversion and
# confirming the diff landed: the lane went green anyway. A fixture that cannot reach the branch
# under test measures nothing.
_BAD=$(printf '  \xff\xfe garbage\n  crashed before any lane ran BYTE_EVIDENCE\n')
_OUT=$(_show_failure "$_BAD")
printf '%s' "$_OUT" | grep -q 'BYTE_EVIDENCE'; chk $? "invalid UTF-8 in the stream does not swallow the evidence"
printf '%s' "$_OUT" | grep -qv 'no output captured'; chk $? "…and it is not mis-reported as empty output"

# The banner must not be suppressed by a line the reader never saw (a failing line past the head cut
# that merely quotes the banner text).
_MANY=$(for i in $(seq 1 26); do echo "  ❌ f$i"; done; echo "  ❌ f27 quoting ════ lanes: 9 passed · 1 failed ════"; echo "════ lanes: 9 passed · 1 failed ════")
_OUT=$(_show_failure "$_MANY")
[ "$(printf '%s\n' "$_OUT" | grep -c '════ lanes: 9 passed')" -ge 1 ]
chk $? "the summary banner still prints when a truncated-away line quotes it"

# ── ref-path + SessionStart-pair: `.git` presence is not "is this absence declared OK" ─────────
# WHY (2026-08-12, cross-family review, card §🔱⑮ G): both blocks used to key their package-mode
# SKIP on `[ -e .git ]`. A git-TRACKED tree that vendors this package (a monorepo committing
# node_modules, or a consumer who runs `git init` after install) has `.git` present and is still a
# package consumer — the predicate answered "source checkout" for it anyway, ran the full check, and
# reproduced the exact FAIL both blocks exist to prevent. The fix routes through a single declaration
# (`_pkg_accepted_absent`, backed by package_coverage_check.sh's ACCEPTED_ABSENT) instead. Anchored
# here because this file is the state-lanes suite and an adversarial read is what caught the first
# version of this same fix landing without a regression lane.
_PA_FN=$(grep -n '^_pkg_accepted_absent()' "$SELFCHECK")
if [ -z "$_PA_FN" ]; then
  echo "FAIL  _pkg_accepted_absent() is no longer defined in selfcheck.sh — this lane cannot verify"
  echo "      what it claims to. Update the lane WITH the subject."
  exit 1
fi
echo "── discriminator located: selfcheck.sh:${_PA_FN%%:*}"

# route_refpath(git_present, path_exists, is_accepted_absent) mirrors the real per-path decision
# inside the `if [ -e ".git" ]` block: no .git → the whole scan is skipped regardless of any single
# path's state (package mode); .git present → PASS if the path exists, else consult the declaration.
route_refpath() {
  local git="$1" exists="$2" accepted="$3"
  if [ "$git" = 0 ]; then echo SKIP-package; return; fi
  if [ "$exists" = 1 ]; then echo PASS; return; fi
  if [ "$accepted" = 1 ]; then echo SKIP-accepted; return; fi
  echo FAIL
}
# route_refpath_OLD is the reverted predicate: package-mode SKIP gated on .git alone, with no
# fallback to the declaration when .git is present and the path is genuinely missing.
route_refpath_OLD() {
  local git="$1" exists="$2"
  if [ "$git" = 0 ]; then echo SKIP-package; return; fi
  if [ "$exists" = 1 ]; then echo PASS; return; fi
  echo FAIL
}
[ "$(route_refpath 0 0 1)" = SKIP-package ]  ; chk $? "no .git → SKIP regardless of the individual path"
[ "$(route_refpath 1 1 0)" = PASS ]          ; chk $? "source tree, path exists → PASS"
[ "$(route_refpath 1 0 0)" = FAIL ]          ; chk $? "source tree, path genuinely missing, not declared → FAIL (a real defect still fails)"
[ "$(route_refpath 1 0 1)" = SKIP-accepted ] ; chk $? "known-POSITIVE (the bug this fix closes): .git present (vendored/tracked package) + path missing + DECLARED accepted-absent → SKIP, not FAIL"
[ "$(route_refpath_OLD 1 0)" = FAIL ]        ; chk $? "known-POSITIVE control: the reverted .git-only predicate DOES mis-route that same state to FAIL (the bug is real, not theoretical)"

# The two paths this fix was written for must actually be present in the declaration it now consults
# — otherwise the lanes above prove the routing logic works while the real inputs still fall through it.
_PA_LIST=$(bash "$SCRIPT_DIR/package_coverage_check.sh" --list-accepted 2>/dev/null)
printf '%s\n' "$_PA_LIST" | grep -qxF ".claude/regression/ablation_verdicts.md"
chk $? "premise holds: .claude/regression/ablation_verdicts.md is in the live ACCEPTED_ABSENT list"
printf '%s\n' "$_PA_LIST" | grep -qxF "scripts/probe_scope_check.sh"
chk $? "premise holds: scripts/probe_scope_check.sh is in the live ACCEPTED_ABSENT list"
printf '%s\n' "$_PA_LIST" | grep -qxF "scripts/test_sessionstart_multihook_lanes.sh"
chk $? "premise holds: scripts/test_sessionstart_multihook_lanes.sh is in the live ACCEPTED_ABSENT list"

# The SessionStart-pair loop's mode field: unrecognized values must FAIL closed, not fall through to
# whichever string-match branch happens to miss (codex cross-family finding, 2026-08-12).
_MODE_CASE=$(grep -n 'package-optional|always-shipped) ;;' "$SELFCHECK")
if [ -z "$_MODE_CASE" ]; then
  echo "FAIL  the pair-mode validation case is no longer in selfcheck.sh — this lane cannot verify"
  echo "      what it claims to. Update the lane WITH the subject."
  exit 1
fi
route_pair_mode() {
  case "$1" in
    package-optional|always-shipped) echo VALID ;;
    *) echo FAIL-badmode ;;
  esac
}
[ "$(route_pair_mode package-optional)" = VALID ]        ; chk $? "known mode 'package-optional' validates"
[ "$(route_pair_mode always-shipped)" = VALID ]           ; chk $? "known mode 'always-shipped' validates"
[ "$(route_pair_mode alway-shipped)" = FAIL-badmode ]     ; chk $? "known-POSITIVE: a typo'd mode is rejected, not silently treated as either known state"

# ── 삭제→SKIP: the fourth face. A declared-shipped subject's absence is not "package mode" ─────
# WHY (measured 2026-08-12, card §🔱⑮ A2): **18 blocks** in selfcheck.sh rendered a green SKIP when
# their subject was missing, and all 18 subjects are in package.json files[] AND in the real tarball
# (`npm pack --dry-run --json`, 20/20 — so routing them to FAIL cannot over-block a real consumer).
# For an always-shipped subject, "absent" can only mean deletion or a broken install. Two of the 18
# read as already-handled and were not: the gate_pathspec block printed "— not-checked, NOT a pass"
# without setting fail, and the --self-test loop's comment claims "never a silent pass" directly above
# the arm that was one. A comment asserting a property is not the property; both were hand-verified.
# LIFTED, not re-spelled — same reason as the discriminators above.
_ASV=$(sed -n '/^_absent_subject_verdict()/,/^}/p' "$SELFCHECK")
_SPF=$(sed -n '/^_ships_per_files()/,/^}/p' "$SELFCHECK")
if [ -z "$_ASV" ] || [ -z "$_SPF" ]; then
  echo "FAIL  _absent_subject_verdict / _ships_per_files no longer defined in selfcheck.sh —"
  echo "      this lane cannot verify what it claims. Update the lane WITH the subject."
  exit 1
fi
echo "── 삭제→SKIP discriminator located (both helpers present)"

_asv() {  # $1=subject → prints verdict, returns its rc
  ( cd "$SCRIPT_DIR/.." && bash -c "
$_SPF
$_ASV
_absent_subject_verdict 'lane' '$1'" 2>&1 )
}
_asv_rc() { _asv "$1" >/dev/null 2>&1; echo $?; }

# known-POSITIVE: a declared-shipped subject going missing must FAIL, not SKIP. Three different
# shapes (a script, a hook under a directory files[] entry, an anchor's subject).
[ "$(_asv_rc scripts/count_check.sh)" = 1 ]
chk $? "known-POSITIVE: declared-shipped script absent → FAIL (was a green SKIP for 18 blocks)"
[ "$(_asv_rc templates/.git-hooks/pre-commit)" = 1 ]
chk $? "known-POSITIVE: hook covered by a DIRECTORY files[] entry → FAIL (prefix match, not equality)"
# ⚠️ Capture, THEN grep. `_asv` deliberately returns 1 here, and this file runs under `pipefail`, so
# `_asv … | grep -q …` yields the pipeline's rightmost non-zero — i.e. the assertion failed while
# grep had actually matched. Measured on this very lane's first run
# ([[feedback_pipefail_fallback_disarms_guard]]: `out=$(cmd); rc=$?` is the canonical form).
_asv_out=$(_asv scripts/count_check.sh)
printf '%s' "$_asv_out" | grep -q 'DECLARED SHIPPED'
chk $? "…and the message names WHY, so the verdict is diagnosable"

# known-NEGATIVE: an ACCEPTED_ABSENT subject must still SKIP. Without this arm the fix would be an
# over-block, which trains --no-verify — the trade this repo has logged explicitly.
[ "$(_asv_rc scripts/probe_scope_check.sh)" = 0 ]
chk $? "known-NEGATIVE: genuinely-unshipped subject absent → SKIP (no over-block)"
[ "$(_asv_rc scripts/sync-to-be.sh)" = 0 ]
chk $? "known-NEGATIVE: operator-private subject absent → SKIP"

# The UNKNOWN arm: an unreadable manifest cannot tell deletion from package mode, so it must NOT
# take the lenient branch. `not found != 0` applied to the oracle itself.
_TD=$(mktemp -d)
_urc=$( ( cd "$_TD" && bash -c "
$_SPF
$_ASV
_absent_subject_verdict 'lane' 'scripts/x.sh'" >/dev/null 2>&1 ); echo $? )
rm -rf "$_TD"
[ "$_urc" = 1 ]
chk $? "UNKNOWN (no readable package.json) → FAIL, not a lenient SKIP"

# REVERSION: every one of the 18 call sites must route through the helper. A site that re-spells the
# old `echo "SKIP … absent"` without setting fail has restored the defect. Counting call sites rather
# than grepping for the old string, because the old string is what a reverter would reproduce.
_ASV_CALLS=$(grep -c '_absent_subject_verdict "' "$SELFCHECK" || true)
[ "$_ASV_CALLS" -ge 18 ]
chk $? "all 18 absent-subject sites route through the helper (found $_ASV_CALLS, expected >=18)"
# And no site may print a bare absent-SKIP for a subject that IS declared shipped.
# ⚠️ The first draft asserted ZERO bare absent-SKIP echoes and failed with 5 — all five legitimate:
# the helper's own SKIP arm, plus four subjects that genuinely never ship (probe_scope_check.sh,
# ablation_calibrate.sh, sync-to-be.sh, sync-from-be.sh — all ACCEPTED_ABSENT). A green SKIP is
# CORRECT there, and an assertion that forbids it would have forced an over-block. So the predicate
# is the same one the fix uses — is the named subject declared shipped — not a count that would need
# hand-tuning every time an exception is added ([[feedback_control_presence_is_not_discrimination]]:
# a control that fires on everything measures nothing).
_BARE=$( ( cd "$SCRIPT_DIR/.." && python3 - <<'BAREPY'
import re, json
sc = open('scripts/selfcheck.sh', encoding='utf-8').read().split('\n')
files = json.load(open('package.json'))['files']
def ships(p): return any(p == f or p.startswith(f.rstrip('/') + '/') for f in files)
bad = []
for i, l in enumerate(sc, 1):
    if '_absent_subject_verdict' in l:      # the helper itself, and its call sites
        continue
    m = re.search(r'echo "SKIP\s+.*subject ([A-Za-z0-9_./-]+) absent', l)
    if m and ships(m.group(1)):
        bad.append(f"{i}:{m.group(1)}")
print(' '.join(bad))
BAREPY
) )
[ -z "$_BARE" ]
chk $? "no bare absent-SKIP remains for a DECLARED-SHIPPED subject (found: ${_BARE:-none})"
# Control for the line above: the predicate must be able to FIRE. If ships() ever returns False for
# everything (unreadable manifest, changed schema), the assertion passes vacuously and certifies
# nothing — so prove the same detector flags a planted declared-shipped subject.
_BARE_CTL=$( ( cd "$SCRIPT_DIR/.." && python3 - <<'CTLPY'
import re, json
files = json.load(open('package.json'))['files']
def ships(p): return any(p == f or p.startswith(f.rstrip('/') + '/') for f in files)
planted = 'echo "SKIP  planted (subject scripts/count_check.sh absent)"'
m = re.search(r'echo "SKIP\s+.*subject ([A-Za-z0-9_./-]+) absent', planted)
print('FIRED' if (m and ships(m.group(1))) else 'DEAD')
CTLPY
) )
[ "$_BARE_CTL" = FIRED ]
chk $? "CONTROL: that detector fires on a planted declared-shipped subject (got $_BARE_CTL)"

# ── SCOPE OF THIS ANCHOR — stated so it is not over-trusted ───────────────────
# These lanes catch REVERSION (the run-twice form coming back, the helper being gutted, the
# call-site redirect returning). They do NOT catch deliberate EVASION: a cross-family round
# demonstrated three forms that satisfy every check above while still destroying evidence —
# `_out=$(bash suite >/dev/null 2>&1)` (executed once, captured nothing), a wrapper function
# (`run_lane() { bash scripts/X.sh; }`, literal appears once, runs twice), and redirect spellings
# the greps do not enumerate (`1>/dev/null`, a variable). Chasing those with more patterns is the
# Grep-Collision Treadmill this repo has already logged as P10 — each added regex relocates the
# evasion instead of closing it. It is bounded rather than escalated: an evading form still routes
# through _show_failure, whose empty branch prints "(no output captured)" at runtime, so the failure
# is loud rather than silent. Regression is anchored; evasion is a named residual, not a solved one.

echo ""
if [ "$FAILED" -ne 0 ]; then
  echo "SELFCHECK STATE LANES: FAIL — a discriminator would mis-route"
  exit 1
fi
echo "SELFCHECK STATE LANES: PASS ($PASS/$PASS)"
exit 0
