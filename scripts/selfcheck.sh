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
# Package-mode guard: neither the test nor its subject (templates/.git-hooks/pre-push) is in
# package.json files[] — both are source-tree-only infra. Without this guard the SHIPPED selfcheck
# fails for every consumer running `npm test` on the installed package. Caught pre-publish 2026-07-20
# by reproducing package mode; mirrors the ref-path SKIP below.
if [ ! -f templates/.git-hooks/pre-push ]; then
  echo "SKIP  pre-push stdin integrity (package mode: templates/.git-hooks absent)"
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
  echo "SKIP  degrade-scan shell probes (subject scripts/degrade_direction_scan.sh absent)"
elif [ -f scripts/test_degrade_scan_shell_probes.sh ]; then
  if ! bash scripts/test_degrade_scan_shell_probes.sh; then
    fail=1
  fi
else
  # subject present, anchor gone => the calibration was deleted. Real failure, not a skip.
  echo "FAIL  degrade-scan shell probes: scan present but scripts/test_degrade_scan_shell_probes.sh missing"
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
  echo "SKIP  test_package_coverage_lanes.sh (subject scripts/package_coverage_check.sh absent)"
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

# embedded --self-test suites (compaction_probe · judgment_circuit_lint · novelty_claim_check).
# These three carry their lanes INSIDE the script (`--self-test`) rather than in a sibling
# test_*_lanes.sh, so the name-list wiring above skipped them silently: 48 lanes existed and ran
# only when a human typed the command. That is built-but-not-wired applied to the anchors themselves
# — a later edit that breaks a lane stays green everywhere the project actually checks
# (high re-review 2026-08-08). Same shape as the block above: subject absent → SKIP, subject present
# but self-test missing → FAIL, never a silent pass.
for _subj in compaction_probe judgment_circuit_lint novelty_claim_check; do
  if [ ! -f "scripts/$_subj.sh" ]; then
    echo "SKIP  $_subj --self-test (subject scripts/$_subj.sh absent)"
  else
    # ⚠️ **문자열 존재로 판정하지 마라.** 초판은 `grep -q -- '--self-test'` 였는데, 그 문자열은
    # 헤더 주석과 usage echo 에도 있어서 **디스패처 한 줄만 지워도 여전히 매치**한다. 그리고
    # 인식 못 한 모드에서 스크립트가 usage 를 찍고 exit 0 을 내므로, selfcheck 는 rc=0 을 보고
    # 조용히 통과했다 — 25개 레인이 통째로 사라져도 `npm test` 는 PASS (high 3차 리뷰 실측).
    # 존재검사가 진위를 못 본다는 그 클래스의 재발이다. **실행이 일어났다는 증거**를 요구한다.
    # `< /dev/null` 필수: 인식 못 한 모드로 떨어지면 스크립트가 stdin 을 기다려 **무한 대기**한다
    # (실측 — 디스패처 제거 known-negative 가 2분 타임아웃). CI 를 멈추는 건 조용한 통과보다 나쁘다.
    _st_out="$(timeout 120 bash "scripts/$_subj.sh" --self-test < /dev/null 2>&1)"; _st_rc=$?
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
  echo "SKIP  test_consent_registry.sh (subject scripts/consent_registry_check.sh absent)"
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
  echo "SKIP  test_sidecar_wait_stdin.sh (subject scripts/sidecar_wait.sh absent)"
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
  echo "SKIP  test_sidecar_calibrate_lanes.sh (subject scripts/sidecar_calibrate.sh absent)"
elif [ -f scripts/test_sidecar_calibrate_lanes.sh ]; then
  if ! bash scripts/test_sidecar_calibrate_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_sidecar_calibrate_lanes.sh: sidecar_calibrate.sh present but its anchor is missing"
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
  echo "SKIP  gate_pathspec_check.sh (subject absent: $_gps_missing) — not-checked, NOT a pass"
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
  echo "SKIP  test_node_check_lanes.sh (subject scripts/fh_node_check.sh absent)"
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
  echo "SKIP  test_node_infra_delta_lanes.sh (subject scripts/fh_node_check.sh absent)"
elif [ -f scripts/test_node_infra_delta_lanes.sh ]; then
  if ! bash scripts/test_node_infra_delta_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_node_infra_delta_lanes.sh: fh_node_check.sh present but its anchor is missing"
  fail=1
fi

# SessionStart multi-hook + install-wizard snippet merge. Subject for both = the shipped settings
# snippets; a clone without them is a legitimate SKIP, a clone with them and no anchor is not.
for _pair in \
  "templates/settings.SessionStart.snippet.json|scripts/test_sessionstart_multihook_lanes.sh" \
  "templates/settings.SessionStart.snippet.json|scripts/test_wizard_snippet_merge_lanes.sh"
do
  _subj="${_pair%%|*}"; _anc="${_pair#*|}"
  if [ ! -f "$_subj" ]; then
    echo "SKIP  ${_anc##*/} (subject $_subj absent)"
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
  else
    echo "FAIL  ${_anc##*/}: $_subj present but its anchor is missing"
    fail=1
  fi
done

# Two guards that read the AUTHOR's own actions rather than the repo's files. Both were added
# 2026-07-31; the pipe-verdict lane shipped in PR #209 WITHOUT this wiring, which is itself the
# half-fix class the second guard exists to catch — found by running that guard on this repo.
if [ ! -f scripts/sidecar_calibrate.sh ]; then
  echo "SKIP  test_ollama_panel_lanes.sh (subject scripts/sidecar_calibrate.sh absent)"
elif [ -f scripts/test_ollama_panel_lanes.sh ]; then
  if ! bash scripts/test_ollama_panel_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_ollama_panel_lanes.sh: sidecar_calibrate.sh present but its ollama-leg anchor is missing"
  fail=1
fi

if [ ! -f scripts/pipe_verdict_guard.sh ]; then
  echo "SKIP  test_pipe_verdict_guard_lanes.sh (subject scripts/pipe_verdict_guard.sh absent)"
elif [ -f scripts/test_pipe_verdict_guard_lanes.sh ]; then
  if ! bash scripts/test_pipe_verdict_guard_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_pipe_verdict_guard_lanes.sh: pipe_verdict_guard.sh present but its anchor is missing"
  fail=1
fi

if [ ! -f scripts/halffix_propagation_scan.sh ]; then
  echo "SKIP  test_halffix_lanes.sh (subject scripts/halffix_propagation_scan.sh absent)"
elif [ -f scripts/test_halffix_lanes.sh ]; then
  if ! bash scripts/test_halffix_lanes.sh; then
    fail=1
  fi
else
  echo "FAIL  test_halffix_lanes.sh: halffix_propagation_scan.sh present but its anchor is missing"
  fail=1
fi

for _anchor in scripts/test_session_close_lanes.sh scripts/test_card_drift_probe.sh scripts/test_session_close_chain_lanes.sh; do
  if [ ! -f scripts/session_close_check.sh ]; then
    echo "SKIP  ${_anchor##*/} (subject scripts/session_close_check.sh absent)"
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
  echo "SKIP  test_tag_version_lanes.sh (subject templates/.git-hooks/pre-push absent)"
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
  echo "SKIP  test_version_lockstep_lanes.sh (subject scripts/version_lockstep_check.sh absent)"
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
if [ -d ".claude/rules" ]; then
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
      else
        echo "FAIL  ref-path: $p — referenced in CLAUDE.md/.claude/rules but missing"
        fail=1
      fi
    done <<REFS
$_refs
REFS
  fi
else
  echo "SKIP  ref-path (package mode: .claude/rules absent)"
fi

if [ "$fail" -ne 0 ]; then
  echo "SELFCHECK: FAIL"
  exit 1
fi
echo "SELFCHECK: PASS"
