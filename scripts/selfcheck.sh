#!/usr/bin/env bash
# selfcheck.sh — mandatory-pass (deterministic) checks on FH's own executable surface.
# Class: mandatory-pass (harness_6axis_framework.md §Check classes) — blocks on fail.
# Scope: executables shipped via npm files[] + the bash infra driving the FH gate chain.
# NOT syntax-only any more, and this line used to say it was. Syntax checks (node --check / bash -n)
# are only the first section; behavioural lane suites follow and they DO have side effects and
# environment needs: temp dirs, a loopback HTTP stub on 127.0.0.1:18011, git, `timeout`, and — via
# the session-close lanes — an optional `gh` call that reaches GitHub when the binary is present.
# Corrected 2026-07-31 (cross-family review): the stale "zero side effects, no network" claim
# survived the additions that falsified it, which is how a reader ends up trusting the wrong
# invariant. No remote network is REQUIRED; some is possible.
# Wiring: `npm test` for any session; `prepublishOnly` so a publish cannot ship a
# syntactically broken executable.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
fail=0

# Single source of "declared legitimately unshipped" — package_coverage_check.sh's ACCEPTED_ABSENT,
# read once via its --list-accepted flag. Two blocks below (ref-path, SessionStart anchor pairs) used
# to each re-derive "is this absence OK" from an environment predicate (`.git` presence) instead of
# consulting this declaration — which reproduces the exact bug the declaration exists to prevent in
# any git-TRACKED tree that vendors this package (a monorepo committing node_modules, or a consumer
# who runs `git init` after install): `.git` is present there, so the environment predicate answered
# "source checkout", ran the full check, and FAILed on paths the declaration had already said were
# fine to omit. Cross-family review, 2026-08-12 (reship axis, card §🔱⑮ G). `--list-accepted` has no
# git/package.json dependency itself, so this load is safe to attempt unconditionally.
_PKG_ACCEPTED_ABSENT=""
if [ -f scripts/package_coverage_check.sh ]; then
  _PKG_ACCEPTED_ABSENT="$(bash scripts/package_coverage_check.sh --list-accepted 2>/dev/null)"
fi
_pkg_accepted_absent() { printf '%s\n' "$_PKG_ACCEPTED_ABSENT" | grep -qxF "$1"; }

# Is this path DECLARED shipped by package.json files[]? The companion question to the one above:
# ACCEPTED_ABSENT answers "is this absence legitimate", this answers "should this be here at all".
# Together they turn a bare "file missing" into a routed verdict instead of a blanket SKIP.
# Directory entries in files[] cover everything under them, which is how `templates/.git-hooks`
# covers `templates/.git-hooks/pre-push` — a prefix test, not equality (getting this wrong is what
# made a comment claim the hook does not ship while package.json:117 declared its whole directory).
# NOTE ON WHAT THIS DOES *NOT* PROVE: files[] membership is a DECLARATION, not the tarball. This repo
# has already measured the two diverging (card §🔱⑮ G/C: repo ✅ / files[] ❌). Here the direction is
# safe — an over-declaration makes this check stricter, never more lenient — but do not reuse this
# helper anywhere the answer needs to be "what the consumer actually received"; that needs
# `npm pack --dry-run --json`.
_ships_per_files() {
  python3 - "$1" <<'SHIPPY' 2>/dev/null
import json, sys
p = sys.argv[1]
try:
    files = json.load(open('package.json'))['files']
except Exception:
    sys.exit(2)          # unreadable manifest: UNKNOWN, and the caller must not read that as "no"
sys.exit(0 if any(p == f or p.startswith(f.rstrip('/') + '/') for f in files) else 1)
SHIPPY
}

# ── The single verdict for "my subject is not here" ───────────────────────────────────────────
# Measured 2026-08-12 (card §🔱⑮ A2): **18 blocks in this file** rendered a green SKIP when their
# subject was absent, and **all 18 subjects are declared in package.json files[] and present in the
# real tarball** (verified with `npm pack --dry-run --json`, 20/20 — so routing them to FAIL cannot
# over-block a legitimate consumer). For a subject that always ships, "absent" cannot mean "package
# mode"; the only ways to reach it are DELETION or a broken install, and both were reported green.
# That is the fourth face of the axis the card names three of: 미측정→clean · 미측정→findings ·
# 해당없음→FAIL · **삭제→SKIP** — and it is the quiet one, which is why it survived longest.
#
# Two of the eighteen are worth naming because they read as already-handled and were not:
#   · the gate_pathspec block printed "— not-checked, NOT a pass" and then did not set fail. The
#     LABEL was honest and the VERDICT was green; a reader greps the message and believes it.
#   · the --self-test loop's comment says "never a silent pass" directly above the arm that was one.
# A comment asserting a property is not the property. Both were hand-verified by eye, not inferred.
#
# THE UNKNOWN ARM IS NOT A SKIP. `_ships_per_files` exits 2 when package.json is unreadable, and an
# unreadable manifest means we cannot tell deletion from package mode — `not found != 0`, so that
# case must not silently take the lenient branch (this repo's whole §Instrument-Calibration rule).
# Usage:  [ -f "$subj" ] || { _absent_subject_verdict "<label>" "$subj" || fail=1; }
_absent_subject_verdict() {
  local label="$1" subj="$2"
  _ships_per_files "$subj"
  case $? in
    0) echo "FAIL  $label: $subj is DECLARED SHIPPED (package.json files[]) but absent — that is a"
       echo "      deletion or a broken install, not package mode. The subject itself is missing."
       return 1 ;;
    1) echo "SKIP  $label (subject $subj not in package.json files[], and absent)"
       return 0 ;;
    *) echo "FAIL  $label: cannot read package.json, so '$subj absent' is UNDECIDABLE between a"
       echo "      deletion and package mode — unmeasured, not clean."
       return 1 ;;
  esac
}

check() { # check <label> <cmd...>
  local label="$1"; shift
  if "$@" 2>/dev/null; then
    echo "PASS  $label"
  else
    echo "FAIL  $label"
    "$@" || true
    fail=1
  fi
}
# ⚠️ KNOWN DEFECT, NOT FIXED HERE — `check()` above has the same evidence-discarding shape the
# lane blocks below were repaired for (2026-08-05): it decides on `"$@" 2>/dev/null` (stderr of the
# DECIDING run is destroyed) and then re-runs to print. It is left alone deliberately: `check()` is
# called by every `node --check` / `bash -n` line in this file, so changing it changes the whole
# surface at once, which is a different job from repairing the four lane blocks (CLAUDE.md
# §Added-Scope Gate question 2). `scripts/probe_scope_check.sh`'s caller near the probe-scope block
# carries the same shape. Both are tracked separately — do NOT read the lane-block repair below as
# having cleared this file.

# _show_failure <captured-output> — print a FAILING suite's evidence without truncating it away.
# Single source for all four lane blocks (a second copy would drift; the divergent-normalizer class).
# WHY NOT `tail -N`: measured 2026-08-05 on sync_from_be_lanes.sh — output is 98 lines and a planted
# lane failure at line ~22 is INVISIBLE to `tail -20` (0 hits), while the summary banner still reads
# "1 failed". The reader gets a FAIL verdict sitting on top of passing log lines — the exact shape
# this whole repair exists to remove. The failing-line extraction finds it (1 hit, known pair).
# All four suites mark failures with `❌` (`no()` in sync_from_be_lanes.sh:21, `chk()` in the other
# three) or an early `FAIL ` line when a subject is missing; grep handles the multi-byte glyph
# (known pair: 1 hit on a ❌ line, 0 on a ✅-only line — verified, not assumed).
_show_failure() {
  local out="$1" fails n banner shown nonblank
  # Whitespace-only counts as empty: guarding with [ -z "$out" ] alone let a suite emitting "   "
  # fall into the died-early branch and print indented blank lines — silence rendered as evidence.
  # SHELL PATTERN, NOT `tr`: the obvious `tr -d '[:space:]'` is a measured defect on BSD. Given a
  # line containing invalid UTF-8, macOS `tr` aborts with `tr: Illegal byte sequence` and emits
  # NOTHING, so the guard concludes "empty" and reports "no output captured" while real evidence is
  # sitting in $out — the exact mis-report this helper exists to prevent, reintroduced by the guard
  # against it. (GNU tr passes the bytes through; the arms disagree, and the failing arm is the
  # author's own machine.) Case-matching is a shell builtin: no subprocess, no charset decoding, so
  # invalid bytes cannot make it lie. Known pair: invalid-byte→nonblank, spaces/tabs/newlines→blank,
  # ""→blank, "hello"→nonblank (4/4), while the tr form returns 0 bytes on arm 1.
  case "$out" in *[![:space:]]*) nonblank=1 ;; *) nonblank= ;; esac
  # NO LOCALE PIN HERE, and its absence is a measured result — same disposition, and same reasoning,
  # as the pin `.github/workflows/validate.yml` removed after refuting its own locale hypothesis.
  # Two model families independently suspected that matching the multi-byte `❌` would break under a
  # C/POSIX locale (one filed it as UNCALIBRATED for the GNU arm, the other as an unpinned-locale
  # defect), so `LC_ALL=C` was added — then both arms were actually measured:
  #   BSD grep (macOS)      : C, UTF-8              → 1 hit each
  #   GNU grep 3.12 (Linux) : C, C.UTF-8, unset     → 1 hit each; and with invalid UTF-8 bytes mixed
  #                                                   in, the ❌ line still extracts (no binary-file
  #                                                   collapse, the specific feared mode)
  # The hypothesis is REFUTED on both arms, so the pin demonstrated nothing and was removed rather
  # than kept as insurance — a knob retained because it might help is indistinguishable from one
  # that does, and the next reader would inherit it as evidence that the danger is real.
  fails=$(printf '%s\n' "$out" | grep -E '❌|^FAIL ' || true)
  banner=$(printf '%s\n' "$out" | grep -E '════' | tail -1 || true)
  if [ -n "$fails" ]; then
    shown=$(printf '%s\n' "$fails" | head -25)
    printf '%s\n' "$shown" | sed 's/^/     /'
    n=$(printf '%s\n' "$fails" | wc -l | tr -d ' ')
    [ "$n" -gt 25 ] && echo "     … ($((n - 25)) more failing lines not shown)"
  elif [ -z "$nonblank" ]; then
    echo "     (no output captured — the suite produced nothing before failing)"
  else
    echo "     (no ❌/FAIL line found — suite likely died early; showing tail)"
    printf '%s\n' "$out" | tail -12 | sed 's/^/     /'
  fi
  # Summary banner: matched by shape, not by position. A blind `tail -2` re-printed lines already
  # shown above (measured: a ❌ within the last 2 lines appeared twice, and the "N more not shown"
  # notice was immediately followed by one of the lines it had just declined to show), and on empty
  # input it emitted a stray indented line. Print it only when it exists and is not already on screen.
  # Dedupe against what was ACTUALLY PRINTED ($shown), not against the full $fails set. Searching
  # $fails suppressed the banner whenever a failing line beyond the head -25 cut merely contained
  # the banner text — i.e. it hid the banner precisely because a line the reader never saw mentioned
  # it. $shown is empty in the non-fails branches, so the banner prints there as before.
  if [ -n "$banner" ] && ! printf '%s\n' "${shown:-}" | grep -qF -- "$banner"; then
    printf '     %s\n' "$banner"
  fi
}

# Node executables (npm-shipped)
for f in bin/*.js; do
  check "node --check $f" node --check "$f"
done

# Codex adapter drift: the thin Codex runtime must keep reading canonical FH
# skill/agent surfaces without silently accepting Claude-native primitives as
# Codex-native.
# NOT via check(): that helper decides on a run whose stderr is discarded, and this call site used to
# additionally discard the subject's STDOUT (`--strict >/dev/null`). fh-codex-doctor writes 100% of
# its drift diagnostics to stdout (measured 2026-08-05: 686 B stdout / 0 B stderr), so a failure
# printed a bare `FAIL` line carrying no diagnosis at all — worse than the truncation this session
# repaired in the lane blocks. Fixed at the call site; check() itself is a separate job (see above).
if _out=$(node bin/fh-codex-doctor.js --strict 2>&1); then
  echo "PASS  fh-codex-doctor --strict"
else
  echo "FAIL  fh-codex-doctor --strict"
  _show_failure "$_out"
  fail=1
fi

# Bash surface: npm-shipped scripts + local bin wrappers + gate-chain infra
for f in scripts/*.sh bin/fh-gate bin/fh-run bin/fh-goal \
         templates/regression_guard.sh templates/temper_check.sh templates/predelete_check.sh templates/.git-hooks/pre-commit; do
  [ -f "$f" ] || continue
  check "bash -n $f" bash -n "$f"
done

# Count consistency: stated skill/agent counts vs actual directories.
# Drift class recurred 4x on 2026-06-10 alone (local_fh_context 26, plugin.json "3 agents",
# README "5 agents", marketplace.json "3 agents") — this makes the check mechanical and permanent.
# Logic extracted to scripts/count_check.sh so the SAME check also runs at commit time in
# the pre-commit hook (shift-left, gated on a skills-dir add/remove — fh_signal_2026-06-21
# gate-locality gap: the check previously lived only here at the publish boundary, so a
# skill-adding PR could merge with stale counts undetected until the next publish).
if ! bash scripts/count_check.sh; then
  fail=1
fi

# Behavioural regressions on the verdict surface. Syntax checks above prove the scripts parse;
# these prove the gate still fails CLOSED on the holes confirmed open in v1.4.59 (model verdict
# contradicting its own findings, FH_TIMEOUT reaching command position, dry-run readable as
# PASS, an unperformed review reported as a verdict, a forgeable plaintext evidence fence).
# Wired here so `npm test` and prepublishOnly both run them: a publish must not be able to
# ship a gate that has quietly reopened one of them.
if [ -f scripts/test_fh_gate_regressions.sh ]; then
  if ! bash scripts/test_fh_gate_regressions.sh; then
    fail=1
  fi
else
  echo "FAIL  fh-gate regressions: scripts/test_fh_gate_regressions.sh missing"
  fail=1
fi

# pre-push stdin integrity — anchors the 2026-07-20 fail-open hole (a stdin-inheriting subprocess
# above the ref loop drains git's ref list → Destructive-Op gate silently allows a delete/force push).
# Wired here, not left standalone: an unwired checker is the exact defect this session found in
# session_close_check.sh — building the test and not running it repeats it one layer up.
# ⚠️ CORRECTED 2026-08-12 (innovator Mode F scan → resolved by measurement). This comment used to
# read: "neither the test nor its subject (templates/.git-hooks/pre-push) is in package.json files[]
# — both are source-tree-only infra." **That was false**, and it had been false long enough to be
# load-bearing. `npm pack --dry-run --json` on this tree returns 262 files including
# templates/.git-hooks/pre-push, templates/.git-hooks/pre-commit AND
# scripts/test_prepush_stdin_integrity.sh — subject and anchor both ship (package.json:117 declares
# the whole `templates/.git-hooks` directory).
# The consequence is what makes this worth fixing rather than just re-wording: if the subject always
# ships, then "subject absent" can no longer mean "package mode" — the only way to reach that arm is
# that **the hook was deleted**, and it was rendering that as a green SKIP. This is the fourth face
# of the axis the card names three of at §🔱⑮ (미측정→clean · 미측정→findings · 해당없음→FAIL):
# **삭제→SKIP**. A deleted Destructive-Op gate reporting green on every surface is the worst of the
# four, because the other three are loud.
# Kept as a three-valued check rather than a bare FAIL: a consumer's tree can legitimately lack the
# directory if they installed with --ignore-scripts and pruned, so the *declaration* is what decides,
# not the environment (same discipline as `_pkg_accepted_absent` above — consult what ships, do not
# re-derive it from what happens to be on disk).
if [ ! -f templates/.git-hooks/pre-push ]; then
  if _ships_per_files "templates/.git-hooks/pre-push"; then
    echo "FAIL  pre-push stdin integrity: templates/.git-hooks/pre-push is DECLARED SHIPPED but absent"
    echo "      — that is a deletion or a broken install, not package mode. The Destructive-Op gate"
    echo "      this anchors is the thing that is missing."
    fail=1
  else
    echo "SKIP  pre-push stdin integrity (not shipped per package.json files[], and absent)"
  fi
elif [ -f scripts/test_prepush_stdin_integrity.sh ]; then
  if ! bash scripts/test_prepush_stdin_integrity.sh; then
    fail=1
  fi
else
  # source tree HAS the hook but NOT the test => the anchor was deleted. That is a real failure.
  echo "FAIL  pre-push stdin integrity: hook present but scripts/test_prepush_stdin_integrity.sh missing"
  fail=1
fi

# degrade-scan shell probes — the anchor was written 2026-07-28 and shipped with ZERO callers,
# reproducing [[feedback_built_but_not_wired]] in the same session that cited it. The subject
# (scripts/degrade_direction_scan.sh) and the anchor both ship, so this runs in package mode too;
# only a missing SUBJECT is a legitimate skip.
if [ ! -f scripts/degrade_direction_scan.sh ]; then
  _absent_subject_verdict "degrade-scan shell probes" "scripts/degrade_direction_scan.sh" || fail=1
elif [ -f scripts/test_degrade_scan_shell_probes.sh ]; then
  if ! bash scripts/test_degrade_scan_shell_probes.sh; then
    fail=1
  fi
else
  # subject present, anchor gone => the calibration was deleted. Real failure, not a skip.
  echo "FAIL  degrade-scan shell probes: scan present but scripts/test_degrade_scan_shell_probes.sh missing"
  fail=1
fi

# count_check's README format override is a mandatory-pass gate whose pattern is caller-supplied.
# Same subject-present/anchor-gone shape as the block above: if the guard ships without its known
# pair, a template that defeats the gate (a rendered newline turns the pattern into an OR search)
# passes silently — measured 2026-08-12 on a stale README that the gate reported as PASS.
if [ ! -f scripts/count_check.sh ]; then
  _absent_subject_verdict "count_check README-format lanes" "scripts/count_check.sh" || fail=1
elif [ -f scripts/test_count_check_readme_format_lanes.sh ]; then
  if ! bash scripts/test_count_check_readme_format_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  count_check README-format lanes: count_check.sh present but its anchor is missing"
  fail=1
fi

# The public-surface scanner's SINGLE-FILE and MISUSE paths. Same subject-present/anchor-gone shape:
# the scanner is a fail-closed gate on an irreversible surface, and its failure mode is a green that
# was never earned — a misuse, an unloaded pattern set, or dead plumbing all used to render as clean.
# Wired here on purpose (cross-family round 2): the lane file existed and was syntax-checked only, so
# `npm test` and `prepublishOnly` never executed it. A checker nobody calls is prose.
if [ ! -f scripts/psa_scan_lib.sh ]; then
  _absent_subject_verdict "psa single-file lanes" "scripts/psa_scan_lib.sh" || fail=1
elif [ -f scripts/test_psa_singlefile_lanes.sh ]; then
  if ! bash scripts/test_psa_singlefile_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  psa single-file lanes: psa_scan_lib.sh present but its anchor is missing"
  fail=1
fi

# package-coverage — a shipped doc must not point at a file the tarball omits. Distinct from the
# ref-path check below: that one asks "does this path exist at all", this one asks "does the
# CONSUMER get it". Measured 2026-07-28: 35 paths existed, were named by a shipped doc, and were
# absent from the tarball — including templates/predelete_check.sh, which CLAUDE.md instructs you
# to run before a destructive op. Wired here in the same commit that created it, because the two
# previous anchors this session shipped with zero callers.
# Anchored 2026-07-31. Until then this was the ONE subject in this file exempt from the
# "subject present but anchor missing => FAIL" rule the eight blocks below enforce — and the
# exemption cost something real: its source-checkout predicate tested `-d .git`, so inside a git
# WORKTREE (where .git is a FILE) it printed SKIP and returned 0 without scanning. A worktree is
# how a fresh CI checkout gets approximated, so the check was absent from exactly the tree used
# to reason about CI. scripts/test_package_coverage_lanes.sh pins the predicate across all four
# tree shapes plus a known pair.
if [ ! -f scripts/package_coverage_check.sh ]; then
  _absent_subject_verdict "test_package_coverage_lanes.sh" "scripts/package_coverage_check.sh" || fail=1
elif [ -f scripts/test_package_coverage_lanes.sh ]; then
  if ! bash scripts/test_package_coverage_lanes.sh; then
    fail=1
  fi
  if ! bash scripts/package_coverage_check.sh; then
    fail=1
  fi
else
  echo "FAIL  test_package_coverage_lanes.sh: package_coverage_check.sh present but its anchor is missing"
  fail=1
fi

# lane-runner — sibling of package-coverage one level up: that one asks "does the CONSUMER get the
# file a shipped doc names", this one asks "does ANYTHING execute the lane suite we wrote". Measured
# 2026-08-12 (reship axis, card §🔱⑮ A): 12 of 43 suites under scripts/ had no runner in selfcheck,
# the git hooks, or CI — including scripts/test_marker_crossfamily_lanes.sh, whose subject is a
# marker field that hard-blocks commits, and scripts/test_marker_floor_lanes.sh, whose subject is
# pre-commit's live validate_marker_floor(). Both gates ship; neither calibration had ever run.
# The card recorded this as three specific repairs needing "one anchor each"; wiring three anchors
# would have closed those three and stayed blind to the other nine and to the thirteenth. This runs
# unconditionally when present because its own absence is the defect class it exists to detect —
# there is no package-mode arm to skip into (a consumer running `npm test` should learn that a
# shipped suite of theirs is dead code just as much as we should).
# THREE-VALUED, and the third value exists because the two-valued version was this session's own
# instance of the defect it detects. The first draft was `if [ -f … ]; then run; fi` — an absent
# checker fell through to nothing, silently. That is "미측정을 0으로 렌더" reproduced by the commit
# that closed it: a 1.4.96 consumer has no lane_runner_check.sh (it was added to files[] AFTER that
# publish), so on their machine this block would have printed nothing at all and `npm test` would
# have reported a clean run of a check that never existed there.
# The three states are distinguished by the DECLARATION, not by the environment (same discipline as
# the pre-push block above): present → run · absent-but-declared-shipped → FAIL (deletion or broken
# install) · absent-and-not-declared → SKIP, saying so. For a 1.4.96 consumer the third arm is the
# correct and honest answer, and it names itself rather than being silent.
if [ -f scripts/lane_runner_check.sh ]; then
  if ! bash scripts/lane_runner_check.sh; then
    fail=1
  fi
elif _ships_per_files "scripts/lane_runner_check.sh"; then
  echo "FAIL  lane-runner: scripts/lane_runner_check.sh is DECLARED SHIPPED but absent — deletion or"
  echo "      broken install. The check that detects unrun lane suites is itself missing."
  fail=1
else
  echo "SKIP  lane-runner (not in this package's files[] — predates the version that ships it)"
fi

# ── the twelve suites lane_runner_check.sh measured as having NO runner (2026-08-12) ───────────
# The check directly above COUNTS them; this block is what makes the count go down. Until now the
# repo shipped a checker that reported its own todo list every run and nothing that discharged it,
# which is a decision surface only for as long as someone acts on it.
#
# What was actually measured before this wiring existed, because the size of the fact is the reason
# the block is here: all twelve pass when run by hand (rc=0, ~40s total), and NINE OF THE TWELVE
# ARE IN THE PUBLISHED TARBALL (`npm pack --dry-run --json`, 263 files). So a consumer running
# `npm test` was shipping-and-carrying nine test suites that nothing on their machine ever called.
# The two that hurt most: test_marker_crossfamily_lanes.sh calibrates the `crossfamily:` marker enum
# that hard-blocks commits, and test_marker_floor_lanes.sh calibrates pre-commit's live
# validate_marker_floor(). Both gates ship and block; neither calibration had ever executed.
#
# ONE loop, not twelve blocks, and that is deliberate: the four-value routing below would otherwise
# be hand-copied twelve times, and this repo has already measured what that produces — two copies of
# a normalizer drifting in leniency until one of them silently drops its input
# ([[feedback_divergent_leniency_duplicate_normalizers]]). The pair table is data; the verdict logic
# exists once. The existing SessionStart pair-loop below/above uses the same shape.
#
# FOUR values, and every arm is reachable on a real machine:
#   subject absent        → _absent_subject_verdict (deletion vs package mode, decided by files[])
#   anchor present        → run it. exit 10 is called out separately: several of these suites use it
#                           for "I could not set myself up" (mktemp failure), which is not a lane
#                           failure and must not be reported as one — it still sets fail, because a
#                           harness that could not measure did not pass ([[not_found_is_not_zero]]).
#   anchor absent+shipped → FAIL. Deletion or broken install, exactly like the block above.
#   anchor absent+unshipped → SKIP, naming itself. Three anchors genuinely do not ship
#                           (chamber_run · frontier_digest_retry · residency_closure), so for a
#                           consumer this arm is the honest answer, not a dodge.
#
# Subject choice is the file whose behaviour the suite pins, so that deleting the subject routes to
# "your install is broken" rather than to a green run of a test about nothing.
# test_capability_entrypoint_shipping.sh pins two (degrade_probe_capability.sh and
# psa_probe_capability.sh); degrade is named here as the sentinel — the suite itself checks both and
# fails if either is gone, so nothing is lost by not listing both in this table.
_LANE_TO=""; command -v timeout >/dev/null 2>&1 && _LANE_TO="timeout 300"
for _pair in \
  "scripts/degrade_probe_capability.sh|scripts/test_capability_entrypoint_shipping.sh" \
  "scripts/chamber_run.sh|scripts/test_chamber_run_lanes.sh" \
  "scripts/destructive_pre_gate.sh|scripts/test_destructive_pre_gate_lanes.sh" \
  "scripts/env_purity_scan.sh|scripts/test_env_purity_lanes.sh" \
  "scripts/frontier_digest_daily.sh|scripts/test_frontier_digest_retry.sh" \
  "scripts/knowledge_seam_check.sh|scripts/test_knowledge_seam_lanes.sh" \
  "templates/.git-hooks/pre-commit|scripts/test_marker_crossfamily_lanes.sh" \
  "templates/.git-hooks/pre-commit|scripts/test_marker_floor_lanes.sh" \
  "scripts/residency_closure_scan.py|scripts/test_residency_closure_lanes.sh" \
  "scripts/reviewer_capability_corpus.tsv|scripts/test_reviewer_capability_conformance.sh" \
  "scripts/field_canon_preload.sh|scripts/test_field_canon_lanes.sh" \
  "scripts/stale_clone_guard.sh|scripts/test_stale_clone_guard_lanes.sh"
do
  _subj="${_pair%%|*}"; _anc="${_pair##*|}"; _lbl="${_anc##*/}"
  if [ ! -f "$_subj" ]; then
    _absent_subject_verdict "$_lbl" "$_subj" || fail=1
  elif [ -f "$_anc" ]; then
    # `< /dev/null` and the timeout are not decoration: test_frontier_digest_retry.sh deliberately
    # plants a `sleep 300` stub and asserts a 3s watchdog kills it. If that watchdog ever regresses
    # — which is the single defect this suite exists to catch — an unguarded call does not go RED,
    # it HANGS, and CI dies on a job timeout with the cause unattributable. The suite that detects
    # a broken watchdog must not be able to inherit the hang. Same `command -v timeout` guard as the
    # --self-test loop below, because `timeout` is GNU coreutils and stock macOS has neither it nor
    # a substitute; without it `< /dev/null` is the whole defence and a suite that reads stdin ends
    # immediately instead of waiting forever.
    $_LANE_TO bash "$_anc" < /dev/null; _rc=$?
    case "$_rc" in
      0) ;;
      # The suite could not MEASURE. Distinguished from "the lane failed" because the two send a
      # reader to different places, and a bare fail=1 sends them to the wrong one. 10 = the suite's
      # own setup failed (mktemp, used by several of these); 2 = its subject was missing when it
      # looked (test_knowledge_seam_lanes.sh:7 FATALs this way); 126/127 = the anchor is not
      # executable or not found at all, i.e. a broken install that reached this arm anyway.
      # Every one of them still sets fail — a harness that could not measure did not pass — but it
      # is LABELLED, so the next reader debugs the instrument instead of the lane.
      # The first draft of this loop routed only 10 and let everything else fall into an unlabelled
      # fail=1. That is the same "assumed impossible rather than routed" shape that the sibling
      # commit in lane_runner_check.sh had just written a paragraph against; adversarial review
      # caught the inconsistency between the two files.
      10|2|126|127)
        echo "HARNESS ERROR  $_lbl: the suite exited $_rc — it could not measure, so its verdicts"
        echo "      prove nothing about $_subj. Not a lane failure, and not a pass either."
        fail=1 ;;
      *) fail=1 ;;
    esac
  elif _pkg_accepted_absent "$_anc"; then
    # DECLARED legitimately unshipped — the single source for that answer, not a guess from the
    # environment. The first draft printed "this package predates it", which is a WRONG DIAGNOSIS
    # printed forever on every consumer machine: these anchors do not lag the package, they are
    # deliberately not in it (their subjects do not ship either). A confident wrong reason in a
    # verdict line is worse than no reason, because it is the line the next person greps.
    echo "SKIP  $_lbl (declared legitimately unshipped — package_coverage_check.sh ACCEPTED_ABSENT)"
  else
    # Not present, and NOT declared absent — so either it should be here (deletion / broken
    # install) or the declaration is stale. Routed through the same three-valued helper as the
    # subject arm above, and for the identical reason: `elif _ships_per_files "$_anc"` was a
    # BOOLEAN test over a THREE-valued function, so its exit 2 (package.json unreadable = UNKNOWN)
    # fell through to a green SKIP. That is the lenient branch the helper's own comment forbids
    # ("THE UNKNOWN ARM IS NOT A SKIP"), rebuilt twelve times in one loop, thirty lines under the
    # helper that exists to prevent it. Found by adversarial review; I had written both.
    _absent_subject_verdict "$_lbl (anchor)" "$_anc" || fail=1
  fi
done

# embedded --self-test suites (compaction_probe · judgment_circuit_lint · novelty_claim_check).
# These three carry their lanes INSIDE the script (`--self-test`) rather than in a sibling
# test_*_lanes.sh, so the name-list wiring above skipped them silently: 48 lanes existed and ran
# only when a human typed the command. That is built-but-not-wired applied to the anchors themselves
# — a later edit that breaks a lane stays green everywhere the project actually checks
# (high re-review 2026-08-08). Same shape as the block above: subject absent → SKIP, subject present
# but self-test missing → FAIL, never a silent pass.
for _subj in compaction_probe judgment_circuit_lint novelty_claim_check; do
  if [ ! -f "scripts/$_subj.sh" ]; then
    _absent_subject_verdict "$_subj --self-test" "scripts/$_subj.sh" || fail=1
  else
    # ⚠️ **문자열 존재로 판정하지 마라.** 초판은 `grep -q -- '--self-test'` 였는데, 그 문자열은
    # 헤더 주석과 usage echo 에도 있어서 **디스패처 한 줄만 지워도 여전히 매치**한다. 그리고
    # 인식 못 한 모드에서 스크립트가 usage 를 찍고 exit 0 을 내므로, selfcheck 는 rc=0 을 보고
    # 조용히 통과했다 — 25개 레인이 통째로 사라져도 `npm test` 는 PASS (high 3차 리뷰 실측).
    # 존재검사가 진위를 못 본다는 그 클래스의 재발이다. **실행이 일어났다는 증거**를 요구한다.
    # `< /dev/null` 필수: 인식 못 한 모드로 떨어지면 스크립트가 stdin 을 기다려 **무한 대기**한다
    # (실측 — 디스패처 제거 known-negative 가 2분 타임아웃). CI 를 멈추는 건 조용한 통과보다 나쁘다.
    # `timeout` 은 GNU coreutils 이고 **stock macOS 에 없다**. 가용성 확인 없이 부르면 rc=127 +
    # 빈 출력 → 아래 `*)` 가 발동해 "dispatcher missing?" 이라는 **틀린 원인**으로 거짓 FAIL 이
    # 난다(실측: homebrew 없는 PATH 에서 3개 subject 전부). 소비자 머신에서 `npm test` 와
    # `prepublishOnly` 를 깨뜨리는 경로다. 정답 폼은 이미 레포에 있다(sync-from-be.sh:134).
    # 없으면 무한대기 방지를 잃는 대신 도는 쪽을 택한다 — `< /dev/null` 이 그 방어의 본체다.
    # `local` OUTSIDE A FUNCTION, which this loop is. bash prints
    #   "selfcheck.sh: line N: local: can only be used in a function"
    # on stderr, the assignment never happens, and `_to` stays empty — so the timeout this line
    # exists to install was NEVER INSTALLED. The guard has been decoration since it was written;
    # the comment above it describing what it protects against was true and unimplemented. Measured
    # 2026-08-13: the error printed three times (once per subject) in a full run, and had been
    # printing in every run before that, unread, because stderr scrolls past a 240-second check.
    # ★ A guard that announces its own failure every single run is still a silent failure if
    # nothing reads the announcement. Fixed by deleting one word.
    _to=""; command -v timeout >/dev/null 2>&1 && _to="timeout 120"
    _st_out="$($_to bash "scripts/$_subj.sh" --self-test < /dev/null 2>&1)"; _st_rc=$?
    case "$_st_out" in
      *캘리브레이션*) : ;;
      *) echo "FAIL  $_subj: --self-test produced no calibration verdict (dispatcher missing?)"
         printf '%s\n' "$_st_out" | head -3 | sed 's/^/      /'
         fail=1; _st_rc=0 ;;   # 이미 FAIL 로 셌으니 아래서 중복 계상 안 한다
    esac
    if [ "$_st_rc" -ne 0 ]; then
      echo "FAIL  $_subj --self-test (exit $_st_rc)"
      printf '%s\n' "$_st_out" | tail -6 | sed 's/^/      /'
      fail=1
    fi
  fi
done

# memory-link-check — the memory store is a GRAPH (memory_intent_recall.md: nodes=files,
# edges=[[links]], recall walks one hop). Measured 2026-07-28: 50 of 872 edges pointed at a note
# that existed under a different separator and 22 at nothing — a dead edge returns nothing and is
# indistinguishable from "nothing is related", so the doctrine degraded silently. The checker's
# --fix-separators path WRITES, so its anchor runs here rather than being invoked by hand.
# Package/other-machine mode: the checker self-SKIPs when no memory dir exists.
if [ -f scripts/test_memory_link_check.sh ] && [ -f scripts/memory_link_check.py ]; then
  if ! bash scripts/test_memory_link_check.sh; then
    fail=1
  fi
elif [ -f scripts/memory_link_check.py ]; then
  echo "FAIL  memory-link-check: checker present but scripts/test_memory_link_check.sh missing"
  fail=1
fi

# session-close gate lanes (② harvest-loop discharge + ⑤ card-last) and the ⑤-b card-drift probe.
# Both anchors calibrate scripts/session_close_check.sh, which the pre-push hook runs on every push
# — an uncalibrated instrument there produces exactly the false verdicts the close chain exists to
# prevent. test_card_drift_probe.sh had shipped with ZERO callers since it was written; wiring it
# here closes that, and the anchors are added to files[] in the same change so package mode runs
# them too rather than reporting a deleted anchor.
# consent-class registry floor. Its subject decides whether standing consent may skip an approval
# prompt, so an uncalibrated instrument there hands out autonomy the operator never granted. The
# anchor was written into tests/ with ZERO callers first — the same defect this file already
# records twice above; wiring it here is the fix, not a note about the fix.
if [ ! -f scripts/consent_registry_check.sh ]; then
  _absent_subject_verdict "test_consent_registry.sh" "scripts/consent_registry_check.sh" || fail=1
elif [ -f scripts/test_consent_registry.sh ]; then
  if ! bash scripts/test_consent_registry.sh; then
    fail=1
  fi
else
  echo "FAIL  test_consent_registry.sh: consent_registry_check.sh present but its anchor is missing"
  fail=1
fi

# sidecar_wait stdin plumbing. Its subject is dispatched by auto-decorrelation / steel-quench /
# sim-conductor / AGENTS.md as the REQUIRED wait form, so a regression there silently empties every
# cross-family verification. The anchor's first version shipped in tests/ with ZERO callers — the
# same defect the comment above records for test_card_drift_probe.sh, repeated one file later.
if [ ! -f scripts/sidecar_wait.sh ]; then
  _absent_subject_verdict "test_sidecar_wait_stdin.sh" "scripts/sidecar_wait.sh" || fail=1
elif [ -f scripts/test_sidecar_wait_stdin.sh ]; then
  if ! bash scripts/test_sidecar_wait_stdin.sh; then
    fail=1
  fi
else
  echo "FAIL  test_sidecar_wait_stdin.sh: sidecar_wait.sh present but its anchor is missing"
  fail=1
fi

# fh_node_check.sh gets the same treatment, and for the same reason: three adversarial rounds on it
# produced defects that were ALL negative legs (floor N/A on a non-git install · another framework's
# hooks counted as ours · the Mode D applicability gate silencing its own flagship case), and each
# round's fix reverted a previous one because no anchor pinned it. Subject-present-but-anchor-absent
# is a FAIL, not a skip — that is how an anchor gets quietly dropped.
# Same treatment for the sidecar calibrator, same reason: its verdicts are all distinctions between
# states that look identical from outside ("the sidecar ran" vs "the model I pinned answered",
# "absent" vs "unmeasured"), and its lanes are hermetic stubs, so running them costs nothing.
if [ ! -f scripts/sidecar_calibrate.sh ]; then
  _absent_subject_verdict "test_sidecar_calibrate_lanes.sh" "scripts/sidecar_calibrate.sh" || fail=1
elif [ -f scripts/test_sidecar_calibrate_lanes.sh ]; then
  if ! bash scripts/test_sidecar_calibrate_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_sidecar_calibrate_lanes.sh: sidecar_calibrate.sh present but its anchor is missing"
  fail=1
fi

# marker axes-run lanes — 훅의 4축 자기대조 형식 검사(§CLAUDE.md 3층 자기 대조)의 앵커.
# subject 부재를 FAIL 로 두는 이유는 branch-claim 블록과 같다: 이 subject 는 pre-commit 훅
# 자체이고 files[] 에 있으므로 «정당한 부재» 가 없다. 부재 = 삭제다.
if [ ! -f templates/.git-hooks/pre-commit ]; then
  echo "FAIL  templates/.git-hooks/pre-commit absent — the gate itself is missing, not a skip"
  fail=1
elif [ -f scripts/test_marker_axes_run_lanes.sh ]; then
  if ! bash scripts/test_marker_axes_run_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_marker_axes_run_lanes.sh: pre-commit present but its axes-run anchor is missing"
  fail=1
fi

# branch-claim lanes — shipped with 27 hand-run lanes and ZERO callers, so CI never ran one of them.
# That is the exact defect its own subject guards against (a gate nobody claims against passes
# forever), reproduced one layer up in its anchor. Same SKIP/FAIL shape: a missing subject is a
# legitimate skip, a present subject with a missing anchor is a real failure. The lanes are hermetic
# (per-PID temp dirs under the worktree, no network, no API spend), so running them here costs
# nothing.
#
# ⚠️ Subject-absent is a FAIL here, NOT the SKIP the sibling blocks use. The SKIP arm exists for
# subjects that may legitimately not ship; branch_claim.sh IS in package.json files[], so it is
# present in the source checkout AND in the published package — absence can only mean deletion.
# Nothing else catches that: measured 2026-08-09, package_coverage_check.sh returns PASS on a
# files[] entry whose file does not exist, so a deleted subject would be green on every surface
# (SKIP here + PASS there + npm silently omitting it). A cross-family reviewer caught this; the
# first draft of this block used SKIP and would have silenced exactly that case.
# Named residual, deliberately not fixed here: the sibling blocks above carry the same hole for
# their own shipped subjects. Fixing them is a separate change with its own verification.
if [ ! -f scripts/branch_claim.sh ]; then
  echo "FAIL  scripts/branch_claim.sh is in package.json files[] but absent — a deleted subject, not a skip"
  fail=1
elif [ -f scripts/test_branch_claim_lanes.sh ]; then
  if ! bash scripts/test_branch_claim_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_branch_claim_lanes.sh: branch_claim.sh present but its anchor is missing"
  fail=1
fi

# And the ablation calibrator, for the third instance of the same reason. Its whole job is telling
# apart states that look identical from outside — "the arm could not answer" vs "the runner is dead"
# vs "the runner read the answer off disk" — and round 2 of its own adversarial review found that
# three of its round-1 fixes had no discriminating lane at all. Unwired lanes are green on one
# machine and nowhere else, which is the case this file exists to prevent. Stub runners, no API
# spend, so running them here costs nothing. Not hermetic w.r.t. the filesystem: two isolation lanes
# create and remove an empty, per-PID, git-invisible directory in the worktree.
# probe-scope lanes — the subject had 15 sibling checkers with an anchor and none of its own, so
# three repairs shipped on 2026-08-03 that could each be reverted with nothing turning red. Same
# SKIP/FAIL shape as the blocks above: a missing SUBJECT is a legitimate skip, a present subject with
# a missing anchor is a real failure.
if [ ! -f scripts/probe_scope_check.sh ]; then
  echo "SKIP  test_probe_scope_lanes.sh (subject scripts/probe_scope_check.sh absent)"
elif [ -f scripts/test_probe_scope_lanes.sh ]; then
  if ! bash scripts/test_probe_scope_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_probe_scope_lanes.sh: probe_scope_check.sh present but its anchor is missing"
  fail=1
fi

# gate-pathspec anchor — wired here 2026-08-04. It was reachable ONLY from templates/.git-hooks/
# pre-commit, i.e. only in a clone where the operator had run `git config core.hooksPath`. Every
# other clone, every CI run, and the npm package carried the anchor file and never executed it —
# the built-but-not-wired shape, one layer up: the anchor for the gate had no anchor of its own.
# That mattered the same day: PR #254 added five known-pairs to it, all of which would have been
# unexecuted outside the author's machine.
# Subject = the two implementations it reads (the hook's HEAVY term and the guard's GUARD_PATHSPEC).
# Absent subject → package/partial surface → legitimate SKIP; present subject with the anchor gone
# → FAIL, same shape as every block above.
# NAMED RESIDUAL (cross-family, gpt-5.5, 2026-08-04): if a distribution that SHOULD be complete
# accidentally drops one subject, this reports SKIP, not FAIL — silent non-coverage. Measured the
# same day: removing `templates/.git-hooks` from package.json `files[]` and running
# scripts/package_coverage_check.sh still PASSED, so no existing anchor catches that omission
# either. Deliberately NOT patched with a stricter branch: the only discriminator available
# ("templates/ exists but the hook does not") would be built on an UNMEASURED assumption about how
# a narrower package is shaped, and this repo's rule is not to build before the constraint is
# measured. What is cheap and honest is naming WHICH subject is missing, so a SKIP is diagnosable
# instead of opaque. Revisit when a real partial distribution is observed.
_gps_missing=""
[ -f templates/.git-hooks/pre-commit ] || _gps_missing="templates/.git-hooks/pre-commit"
[ -f templates/regression_guard.sh ] || _gps_missing="${_gps_missing:+$_gps_missing, }templates/regression_guard.sh"
if [ -n "$_gps_missing" ]; then
  _absent_subject_verdict "gate_pathspec_check.sh" "$_gps_missing" || fail=1
elif [ -f scripts/gate_pathspec_check.sh ]; then
  if ! bash scripts/gate_pathspec_check.sh; then
    fail=1
  fi
else
  echo "FAIL  gate_pathspec_check.sh: the gate implementations are present but their coverage anchor is missing"
  fail=1
fi

if [ ! -f scripts/ablation_calibrate.sh ]; then
  echo "SKIP  test_ablation_calibrate_lanes.sh (subject scripts/ablation_calibrate.sh absent)"
elif [ -f scripts/test_ablation_calibrate_lanes.sh ]; then
  if ! bash scripts/test_ablation_calibrate_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_ablation_calibrate_lanes.sh: ablation_calibrate.sh present but its anchor is missing"
  fail=1
fi

if [ ! -f scripts/fh_node_check.sh ]; then
  _absent_subject_verdict "test_node_check_lanes.sh" "scripts/fh_node_check.sh" || fail=1
elif [ -f scripts/test_node_check_lanes.sh ]; then
  if ! bash scripts/test_node_check_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_node_check_lanes.sh: fh_node_check.sh present but its anchor is missing"
  fail=1
fi

# The infra-delta half of the same subject. Separate suite, same pairing rule: it exists only because
# fh_node_check.sh does, so its absence beside a present subject is a FAIL, not a skip.
if [ ! -f scripts/fh_node_check.sh ]; then
  _absent_subject_verdict "test_node_infra_delta_lanes.sh" "scripts/fh_node_check.sh" || fail=1
elif [ -f scripts/test_node_infra_delta_lanes.sh ]; then
  if ! bash scripts/test_node_infra_delta_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_node_infra_delta_lanes.sh: fh_node_check.sh present but its anchor is missing"
  fail=1
fi

# SessionStart multi-hook + install-wizard snippet merge. Subject for both = the shipped settings
# snippets; a clone without them is a legitimate SKIP, a clone with them and no anchor is not —
# UNLESS the anchor itself is declared package-mode-optional. test_sessionstart_multihook_lanes.sh
# is exactly that. Its ACCEPTED_ABSENT entry (package_coverage_check.sh) covers a DIFFERENT case than
# this loop implements: that entry's "selfcheck reports it NOT EXERCISED (exit 2)" describes the
# anchor RUNNING and finding no CLI (handled a few lines below, rc==2). It never claimed anything
# about the anchor FILE being missing — a real consumer never gets to run it at all (the file is not
# in files[]), and this loop had no branch for that at all, so every installed package hit
# "FAIL … anchor is missing" (corrected 2026-08-12, cross-family review — an earlier revision of this
# comment miscited the ACCEPTED_ABSENT entry as already covering the missing-file case). Fixed by
# consulting the SAME declaration (`_pkg_accepted_absent`, loaded once near the top of this file) that
# the ref-path block above uses — not an environment predicate — because `.git` presence answers "is
# there a git repo here", not "was this anchor declared intentionally unshipped", and the two diverge
# in a git-tracked vendored tree (a monorepo committing node_modules, `git init` after install): `.git`
# exists there too, which would silently reproduce the original FAIL.
# test_wizard_snippet_merge_lanes.sh is NOT in ACCEPTED_ABSENT (it does ship, per files[]) — routing
# both anchors through the same declaration lookup, rather than hardcoding one as always-FAIL, means a
# future person who genuinely needs to exempt it does so by editing ONE list, not by finding this loop.
for _pair in \
  "templates/settings.SessionStart.snippet.json|scripts/test_sessionstart_multihook_lanes.sh|package-optional" \
  "templates/settings.SessionStart.snippet.json|scripts/test_wizard_snippet_merge_lanes.sh|always-shipped"
do
  _subj="${_pair%%|*}"; _rest="${_pair#*|}"; _anc="${_rest%%|*}"; _mode="${_rest#*|}"
  # This mode field is a gate-verdict policy value (does a missing anchor FAIL or SKIP), not free
  # text — an unrecognized value must not silently fall through to whichever branch string-matching
  # happens to miss. Cross-family review, 2026-08-12: the two known values were previously the only
  # ones exercised, so a typo (e.g. "alway-shipped") landed in the `else` FAIL branch by accident of
  # string mismatch rather than by a checked policy — fail-closed in practice, but undeclared.
  case "$_mode" in
    package-optional|always-shipped) ;;
    *)
      echo "FAIL  ${_anc##*/}: unrecognized pair mode '$_mode' (expected package-optional or always-shipped)"
      fail=1
      continue
      ;;
  esac
  if [ ! -f "$_subj" ]; then
    _absent_subject_verdict "${_anc##*/}" "$_subj" || fail=1
  elif [ -f "$_anc" ]; then
    # THREE-valued, like the session-close anchors above — and for a third reason they do not have.
    # test_sessionstart_multihook_lanes.sh measures what the LIVE `claude` CLI does with several
    # SessionStart hooks on one matcher. It declares exit 2 = NOT EXERCISED (no CLI / no auth /
    # opt-out). A CI runner structurally cannot have that CLI, so collapsing 2 into fail=1 makes
    # every Linux run red forever — over-blocking, which is how a red CI stops being read at all
    # (the same reasoning that keeps the session-close check advisory on ordinary pushes).
    # 2 does NOT set fail, and it prints a line that cannot be misread as a pass. On a machine that
    # DOES have the CLI the suite runs in full and a real failure still exits 1.
    # Measured 2026-08-04: the first draft of this wiring flattened 2 into fail=1 and turned CI red
    # while the suite had correctly reported "NOT EXERCISED — the `claude` CLI is not on PATH" —
    # i.e. it rebuilt, ten lines below the comment warning against it, the exact flattening defect.
    bash "$_anc"; _rc=$?
    if [ "$_rc" -eq 2 ]; then
      echo "NOT EXERCISED  ${_anc##*/}: this environment cannot run the measurement (exit 2 — never a pass)"
    elif [ "$_rc" -ne 0 ]; then
      fail=1
    fi
  elif [ "$_mode" = "package-optional" ] && _pkg_accepted_absent "$_anc"; then
    echo "SKIP  ${_anc##*/} (declared ACCEPTED_ABSENT — CLI/cost-gated, see package_coverage_check.sh)"
  else
    echo "FAIL  ${_anc##*/}: $_subj present but its anchor is missing"
    fail=1
  fi
done

# Two guards that read the AUTHOR's own actions rather than the repo's files. Both were added
# 2026-07-31; the pipe-verdict lane shipped in PR #209 WITHOUT this wiring, which is itself the
# half-fix class the second guard exists to catch — found by running that guard on this repo.
if [ ! -f scripts/sidecar_calibrate.sh ]; then
  _absent_subject_verdict "test_ollama_panel_lanes.sh" "scripts/sidecar_calibrate.sh" || fail=1
elif [ -f scripts/test_ollama_panel_lanes.sh ]; then
  if ! bash scripts/test_ollama_panel_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_ollama_panel_lanes.sh: sidecar_calibrate.sh present but its ollama-leg anchor is missing"
  fail=1
fi

if [ ! -f scripts/pipe_verdict_guard.sh ]; then
  _absent_subject_verdict "test_pipe_verdict_guard_lanes.sh" "scripts/pipe_verdict_guard.sh" || fail=1
elif [ -f scripts/test_pipe_verdict_guard_lanes.sh ]; then
  if ! bash scripts/test_pipe_verdict_guard_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_pipe_verdict_guard_lanes.sh: pipe_verdict_guard.sh present but its anchor is missing"
  fail=1
fi

if [ ! -f scripts/halffix_propagation_scan.sh ]; then
  _absent_subject_verdict "test_halffix_lanes.sh" "scripts/halffix_propagation_scan.sh" || fail=1
elif [ -f scripts/test_halffix_lanes.sh ]; then
  if ! bash scripts/test_halffix_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_halffix_lanes.sh: halffix_propagation_scan.sh present but its anchor is missing"
  fail=1
fi

# hook_source_gate 는 subject 가 session_close_check.sh 가 아니라 별도로 돌린다 — 위 루프의
# SKIP 조건(subject 부재)에 얹으면 엉뚱한 이유로 건너뛴다.
if [ -f scripts/test_hook_source_gate_lanes.sh ]; then
  if bash scripts/test_hook_source_gate_lanes.sh >/dev/null 2>&1; then
    echo "PASS  test_hook_source_gate_lanes.sh"
  else
    echo "FAIL  test_hook_source_gate_lanes.sh (SessionStart source 게이트 쌍 붕괴)"
    bash scripts/test_hook_source_gate_lanes.sh 2>&1 | grep "❌" | head -5 | sed "s/^/      /"
    fail=1
  fi
fi

for _anchor in scripts/test_session_close_lanes.sh scripts/test_card_drift_probe.sh scripts/test_session_close_chain_lanes.sh; do
  if [ ! -f scripts/session_close_check.sh ]; then
    _absent_subject_verdict "${_anchor##*/}" "scripts/session_close_check.sh" || fail=1
  elif [ -f "$_anchor" ]; then
    # Preserve the anchor's two failure CLASSES instead of flattening them into one `fail=1`.
    # An anchor exits 3 when a fixture's premise never obtained — "this run's verdicts prove
    # nothing" — which is a different instruction to whoever reads the CI summary than exit 1's
    # "the gate is broken". Collapsing them here would rebuild, at the only wired caller, the
    # triage ambiguity the anchors' own exit codes exist to remove (Wave-3, 2026-08-02).
    # 3 and not 2: bash itself returns 2 on a syntax error, so a rotted anchor must not be able to
    # impersonate a fixture premise failure. Both classes still set fail=1 — a fixture error is a
    # failed run, it is just a differently-diagnosed one.
    bash "$_anchor"; _rc=$?
    if [ "$_rc" -eq 3 ]; then
      echo "FIXTURE ERROR  ${_anchor##*/}: a lane premise never obtained — its verdicts prove nothing (exit 3, not a gate failure)"
      fail=1
    elif [ "$_rc" -ne 0 ]; then
      fail=1
    fi
  else
    # subject present, anchor gone => the calibration was deleted. Real failure, not a skip.
    echo "FAIL  ${_anchor##*/}: session_close_check.sh present but its anchor is missing"
    fail=1
  fi
done

# sync_guard_check.sh — same anchor contract, wired here for the first time (2026-08-02). It had NO
# automated caller at all: a known-pair anchor for the destination-newer guard that only ever ran
# when a human remembered to type it. "A guard nobody re-tests degrades into a comment" is that
# file's own opening argument, and it applied to the anchor itself. Guarded on its subject's
# presence because the npm package ships a narrower surface than the source tree.
if [ ! -f scripts/sync-to-be.sh ]; then
  echo "SKIP  sync_guard_check.sh (subject scripts/sync-to-be.sh absent)"
elif [ -f scripts/sync_guard_check.sh ]; then
  bash scripts/sync_guard_check.sh; _rc=$?
  if [ "$_rc" -eq 3 ]; then
    echo "FIXTURE ERROR  sync_guard_check.sh: a lane premise never obtained — its verdicts prove nothing (exit 3, not a guard failure)"
    fail=1
  elif [ "$_rc" -ne 0 ]; then
    fail=1
  fi
else
  echo "FAIL  sync_guard_check.sh: sync-to-be.sh present but its anchor is missing"
  fail=1
fi

# probe_scope_check.sh — its known-pair controls. Wired here because the probe set is hand-maintained and
# nothing else enforces its own anti-stale rule: a heading-direction
# bug scored a 7-probe section as UNMEASURED (98% vs the true 51%), then a narrow anchor regex reported
# 7 live probe scopes as stale. Control B now walks EVERY scope in probes.md and fails closed (exit 3,
# number withheld) when one no longer resolves — which is also the anti-stale rule probes.md already
# states for itself, finally given a checker.
# Package mode is decided by the SUBJECT's own absence. The first draft used `.claude/rules` as the
# discriminator on the belief that it does not ship — measured false: package.json files[] carries
# `.claude/rules/fh_4axis_gate.md`, so in an installed package `.claude/rules` EXISTS while the probe
# corpus does not. That made the SKIP arm unreachable and every consumer's `npm test` hard-fail with a
# message misdiagnosing the package as a source tree. Avoiding a silent pass is not a licence to
# over-block the normal case. `scripts/probe_scope_check.sh` is ACCEPTED_ABSENT and genuinely never
# ships, so its absence is the one honest package signal here.
if [ ! -f scripts/probe_scope_check.sh ] && [ ! -f .claude/regression/probes.md ]; then
  echo "SKIP  probe_scope_check.sh (package mode: neither the instrument nor its corpus ships)"
elif [ ! -f .claude/regression/probes.md ]; then
  echo "FAIL  probe_scope_check.sh: source tree but .claude/regression/probes.md is missing — the check cannot run — UNVERIFIED, not clean"
  fail=1
elif [ -f scripts/probe_scope_check.sh ]; then
  bash scripts/probe_scope_check.sh --self-test >/dev/null 2>&1; _rc=$?
  if [ "$_rc" -eq 3 ]; then
    echo "FAIL  probe_scope_check.sh: CONTROL FAILED — a probe Scope no longer resolves to a section (the probe set no longer says what it defends)"
    bash scripts/probe_scope_check.sh --self-test 2>&1 | grep -E "STALE|NOFILE|control" | head -12
    fail=1
  elif [ "$_rc" -ne 0 ]; then
    echo "FAIL  probe_scope_check.sh: self-test exited $_rc"
    fail=1
  else
    echo "PASS  probe_scope_check.sh (known-pair + scope-resolution controls hold)"
  fi
else
  echo "FAIL  probe_scope_check.sh: probe set present but the scope checker is missing"
  fail=1
fi

# utterance landing check — the close chain's CONTENT anchor, and it has to be RUN, not parsed.
# Measured 2026-08-08 on the branch that introduced it: the only thing in this file that touched
# `scripts/utterance_landing_check.sh` was the `bash -n` syntax sweep at the top. Syntax passing is
# not the instrument working, so the script shipped via files[] with zero behavioural callers —
# [[feedback_built_but_not_wired]] in its purest form, where the sole caller is prose in CLAUDE.md.
#
# What the self-test defends is specifically the DEGRADE DIRECTION. This checker's whole reason for
# existing is that a dead grep prints zero hits and zero hits read as "nothing landed" — a fail-open
# that manufactures a clean verdict out of a broken instrument. Its known-pair set pins that apart:
# a genuine miss must exit 1 while a dead control must exit 10, and 10 must never collapse into 1.
# Left unrun, the file rots exactly where it is load-bearing and nothing here would notice.
# Absence is a FAIL, not a SKIP — and the distinction is mechanical, not stylistic. The SKIP arm
# above for `probe_scope_check.sh` is correct because that file genuinely never ships; this one is
# listed in package.json files[], so in BOTH a source tree and an installed package it must be here.
# A SKIP would convert `rm scripts/utterance_landing_check.sh` into a green run — deletion as a
# clean bill of health, which is the same fail-open shape the checker itself exists to refuse.
if [ ! -f scripts/utterance_landing_check.sh ]; then
  echo "FAIL  utterance_landing_check.sh: missing — it ships via package.json files[], so absence is deletion, not package mode"
  fail=1
elif _out=$(bash scripts/utterance_landing_check.sh --self-test 2>&1); then
  echo "PASS  utterance_landing_check.sh (known-pair self-test: control-death → 10, target-miss → 1)"
else
  echo "FAIL  utterance_landing_check.sh: self-test failed — the close-chain content anchor cannot be trusted"
  _show_failure "$_out"
  fail=1
fi

# tag/version consistency guard. Wired with the guard it anchors: the guard exists because a wrong
# tag reached the remote and a publish from the wrong tree was stopped only by npm's own collision
# check, so an unrun anchor here would be the same luck-as-floor arrangement one layer up.
if [ ! -f templates/.git-hooks/pre-push ]; then
  _absent_subject_verdict "test_tag_version_lanes.sh" "templates/.git-hooks/pre-push" || fail=1
elif [ -f scripts/test_tag_version_lanes.sh ]; then
  # RUN-ONCE, CAPTURE (2026-08-05) — rationale in the sync_from_be_lanes block later in this file.
  if _out=$(bash scripts/test_tag_version_lanes.sh 2>&1); then
    echo "PASS  test_tag_version_lanes.sh (mismatch blocks · match silent · scope · override)"
  else
    echo "FAIL  test_tag_version_lanes.sh: the tag/version guard would mis-route"
    _show_failure "$_out"
    fail=1
  fi
else
  echo "FAIL  test_tag_version_lanes.sh: pre-push present but its anchor is missing"
  fail=1
fi

# Shipped-manifest version lockstep. Distinct from the tag lane above: that one compares the git TAG
# to package.json; this one compares package.json to every version string it SHIPS — including the
# per-plugin entries inside marketplace.json, which the tag lane never opens. Measured 2026-08-06:
# a bump left the second marketplace entry behind and the tag lane passed 8/8 straight through it.
if [ ! -f scripts/version_lockstep_check.sh ]; then
  _absent_subject_verdict "test_version_lockstep_lanes.sh" "scripts/version_lockstep_check.sh" || fail=1
elif [ -f scripts/test_version_lockstep_lanes.sh ]; then
  if _out=$(bash scripts/test_version_lockstep_lanes.sh 2>&1); then
    echo "PASS  test_version_lockstep_lanes.sh (drift blocks · aligned silent · unreadable = exit 2, not pass)"
  else
    echo "FAIL  test_version_lockstep_lanes.sh: the shipped-manifest lockstep guard would mis-route"
    _show_failure "$_out"
    fail=1
  fi
else
  echo "FAIL  test_version_lockstep_lanes.sh: version_lockstep_check.sh present but its anchor is missing"
  fail=1
fi

# ④-e dispatch-log reconciliation + its tally hook. Wired in the same commit that ships them: the
# obligation they mechanize lost 20/20 in a single session, so leaving the checker itself unrun
# would be the same defect one layer up.
if [ -f scripts/test_dispatch_log_lanes.sh ]; then
  if _out=$(bash scripts/test_dispatch_log_lanes.sh 2>&1); then
    echo "PASS  test_dispatch_log_lanes.sh (date-spelling + verdict + tally-hook lanes)"
  else
    echo "FAIL  test_dispatch_log_lanes.sh: the dispatch-log reconciliation would mis-report"
    _show_failure "$_out"
    fail=1
  fi
fi

# selfcheck's own subject-presence discriminators. Every other guard under scripts/ has a lane suite;
# this decision had none, and it shipped two mis-routings in one session — a two-arm form that fell
# through in silence, then a package discriminator keyed on a file that actually ships. Both are
# known-POSITIVEs in the suite, so neither can come back green.
if [ -f scripts/test_selfcheck_state_lanes.sh ]; then
  if _out=$(bash scripts/test_selfcheck_state_lanes.sh 2>&1); then
    echo "PASS  test_selfcheck_state_lanes.sh (four input states + both shipped mis-routings)"
  else
    echo "FAIL  test_selfcheck_state_lanes.sh: a subject-presence discriminator would mis-route"
    _show_failure "$_out"
    fail=1
  fi
fi

# test_lane_runner_lanes.sh — the checker that finds unrun suites had no suite of its own until
# 2026-08-13. It guarded its own WIRING (it fails when selfcheck stops calling it) and nothing
# measured its BEHAVIOUR — the shape it exists to catch, one level up. Wired in the same change
# that ships it, for the reason the block above states: a suite landed unwired is the defect.
if [ -f scripts/test_lane_runner_lanes.sh ]; then
  if _out=$(bash scripts/test_lane_runner_lanes.sh 2>&1); then
    echo "PASS  test_lane_runner_lanes.sh (org seam: no-op · suppression · fail-closed · controls)"
  else
    echo "FAIL  test_lane_runner_lanes.sh: the unrun-suite detector's own verdicts have drifted"
    _show_failure "$_out"
    fail=1
  fi
elif _ships_per_files "scripts/test_lane_runner_lanes.sh"; then
  echo "FAIL  test_lane_runner_lanes.sh is DECLARED SHIPPED but absent — deletion or broken install"
  fail=1
fi

# sync_from_be_lanes.sh — the RETURN path's anchor. Wired in the same change that ships it: the
# script had an operator-side caller (a SessionStart hook outside this repo) while its 70 lanes had
# NO caller anywhere, which is the shape this repo keeps re-finding — a transport that writes into
# the hub, guarded by a suite nothing runs. Same subject-presence idiom as the block above: the
# subject is operator-private and does not ship, so package mode legitimately skips; subject present
# with the anchor gone is a deleted calibration, not a skip.
if [ ! -f scripts/sync-from-be.sh ]; then
  echo "SKIP  sync_from_be_lanes.sh (subject scripts/sync-from-be.sh absent)"
elif [ -f scripts/sync_from_be_lanes.sh ]; then
  # ── RUN-ONCE, CAPTURE — canonical note for the four LANE BLOCKS (2026-08-05) ─────────────────
  # SCOPE, stated precisely because the first draft of this note over-claimed: this covers the four
  # lane blocks only (tag-version · dispatch-log · selfcheck-state · sync_from_be). The same
  # evidence-discarding shape SURVIVES in `check()` at the top of this file and in the
  # probe_scope_check caller — both named there, both deliberately out of scope, both still open.
  # An adversarial round caught the original "all four sites in this file" wording as a false
  # completion claim: it would have stopped the next reader from re-searching. Half a fix with a
  # done-label on it is worse than half a fix.
  # The old form ran the suite twice: once discarded to /dev/null to decide, once re-run to print.
  # For a DETERMINISTIC suite that is merely wasteful. For a non-deterministic one it destroys the
  # evidence: the failing run's output goes to /dev/null and the reader is shown the SECOND run,
  # which may pass. Measured here 2026-08-04 (run 30955950695) — CI printed
  #     FAIL  sync_from_be_lanes.sh: return-path lanes failed
  #     ════ lanes: 70 passed · 0 failed ════
  # i.e. a FAIL verdict over a PASSING transcript, and the actual failure was never recorded
  # anywhere. That is why this lane sat "flaky, cause unknown" on the session card for two days:
  # the instrument was discarding the only evidence that could close it. Reproduced as a known
  # pair before this edit (arm A run-twice → evidence lost + self-contradiction; arm B run-once →
  # evidence preserved), so the fix is anchored, not asserted.
  # NOTE this does NOT make the suite deterministic — the underlying non-determinism is still
  # UNDIAGNOSED and stays an open item. It makes the next occurrence diagnosable instead of
  # self-erasing. Do not read a green CI after this change as the flake being fixed.
  if _out=$(bash scripts/sync_from_be_lanes.sh 2>&1); then
    echo "PASS  sync_from_be_lanes.sh (return-path lanes)"
  else
    echo "FAIL  sync_from_be_lanes.sh: return-path lanes failed"
    _show_failure "$_out"
    fail=1
  fi
else
  echo "FAIL  sync_from_be_lanes.sh: sync-from-be.sh present but its anchor is missing"
  fail=1
fi

# Referenced-path existence is a source-tree check. The npm package intentionally
# ships a narrower runtime surface, so package-mode selfcheck skips this section.
# ⚠️ The skip predicate used to be `[ -d ".claude/rules" ]`. That broke the moment the tarball
# started shipping PART of that directory (`.claude/rules/fh_4axis_gate.md` etc. are in files[]) —
# the directory then exists in BOTH source and package mode, so the check never skipped in package
# mode at all. It ran, extracted refs from the shipped CLAUDE.md/.claude/rules/*.md (which still
# name `.claude/regression/ablation_verdicts.md` and `scripts/probe_scope_check.sh` — both
# deliberately unshipped, per package_coverage_check.sh's own ACCEPTED_ABSENT list), then tried
# `git check-ignore` against a tree with no `.git` at all (a real `npm pack` tarball is not a git
# repo) — that call errors rather than confirming "ignored", so the fallback `[ -f "$p" ]` ran and
# correctly found nothing, and the check reported FAIL on two paths it had already been told, one
# check over, were fine to omit. First fix (2026-08-12, reship axis, card §🔱⑮ G/D) swapped the skip
# predicate for `[ -e .git ]`. Cross-family review then caught that `[ -e .git ]` answers a different
# question than the one this check needs: a git-TRACKED vendor of this package (a monorepo that
# commits node_modules, or a consumer who runs `git init` after installing) has `.git` and IS a
# legitimate package consumer, yet the predicate would route it into the full extraction and
# reproduce the exact original FAIL on these same two paths — the fix would have closed the bug only
# in the one shape it was tested against. The general fix is not a better environment predicate; it
# is not re-deriving "is this legitimately absent" from the environment at all when a DECLARED answer
# already exists — `_pkg_accepted_absent()`, loaded once near the top of this file — this block now
# consults it before FAILing, so the two paths render SKIP regardless of how `.git` happens to be
# shaped in the consumer's tree. `[ -e .git ]` still gates whether the SCAN runs at all (an installed
# package with no tracked-refs source to lint), which is a real and unrelated question.
if [ -e ".git" ]; then
  # Backtick-quoted repo-relative file refs in the always-loaded governance surface
  # (CLAUDE.md + .claude/rules/*.md) must exist. Phantom-reference class recurred
  # N>=3 in the 2026-06-11 audit window — instrument-not-habit.
  # Extract first, then count. Streaming the extractor straight into the loop meant an
  # extractor that produced nothing (CLAUDE.md absent, 2>/dev/null swallowing a grep error,
  # the backtick convention changing) ran the loop zero times, printed nothing, and left
  # fail=0 → SELFCHECK: PASS. The check would have silently ceased to exist while still
  # reporting a pass — the same shape count_check.sh:71 already guards against with its
  # impossible-zero rule. fh-meta always has refs; zero means the instrument broke.
  # EXTRACTION MOVED OFF grep (2026-07-31, measured on the first real CI run). The pipeline used to
  # be `grep -hoE` + sed + `grep -E` over CLAUDE.md, which is Korean-heavy. On macOS (BSD grep, UTF-8
  # locale) it returned ~50 refs; on the ubuntu runner (GNU grep, LANG unset => C locale) it returned
  # ZERO, and the impossible-zero guard below is the only reason that surfaced as a failure instead
  # of "no refs, all clean". Same root cause as the card-drift probe failing its positive lanes in
  # the same run: multibyte text through locale-dependent grep.
  # python3 reads the files as UTF-8 explicitly, so this extractor no longer has a locale at all.
  # It is already a hard dependency of selfcheck (validate_plugins/marketplace, memory_link_check),
  # so this adds nothing to the requirement set. The regex is the same one, transcribed.
  _refs=$(python3 - <<'REFPY' 2>/dev/null
import re, glob
pat = re.compile(r'^(knowledge|templates|scripts|docs|plugins|\.claude)/[^*{}<>$]+\.(md|sh|ya?ml|jsonc|json)$')
seen = set()
for f in ['CLAUDE.md'] + sorted(glob.glob('.claude/rules/*.md')):
    try:
        text = open(f, encoding='utf-8', errors='replace').read()
    except OSError:
        continue
    for tok in re.findall(r'`([^` ]+)`', text):
        if pat.match(tok):
            seen.add(tok)
for p in sorted(seen):
    print(p)
REFPY
)
  if [ -z "$_refs" ]; then
    echo "FAIL  ref-path: extractor produced 0 refs — the scan broke, it did not pass"
    fail=1
  else
    while IFS= read -r p; do
      [ -z "$p" ] && continue
      if git check-ignore -q "$p" 2>/dev/null; then
        echo "SKIP  ref-path (gitignored): $p"
      elif [ -f "$p" ]; then
        echo "PASS  ref-path: $p"
      elif _pkg_accepted_absent "$p"; then
        echo "SKIP  ref-path (declared ACCEPTED_ABSENT — see package_coverage_check.sh): $p"
      else
        echo "FAIL  ref-path: $p — referenced in CLAUDE.md/.claude/rules but missing"
        fail=1
      fi
    done <<REFS
$_refs
REFS
  fi
else
  echo "SKIP  ref-path (package mode: no .git at package root — source-tree-only check)"
fi

if [ "$fail" -ne 0 ]; then
  echo "SELFCHECK: FAIL"
  exit 1
fi
echo "SELFCHECK: PASS"
