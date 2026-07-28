#!/usr/bin/env bash
# selfcheck.sh — mandatory-pass (deterministic) checks on FH's own executable surface.
# Class: mandatory-pass (harness_6axis_framework.md §Axis 5 check classes) — blocks on fail.
# Scope: executables shipped via npm files[] + the bash infra driving the FH gate chain.
# Syntax-only (node --check / bash -n): zero side effects, no network, runs anywhere.
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

# Node executables (npm-shipped)
for f in bin/*.js; do
  check "node --check $f" node --check "$f"
done

# Codex adapter drift: the thin Codex runtime must keep reading canonical FH
# skill/agent surfaces without silently accepting Claude-native primitives as
# Codex-native.
check "fh-codex-doctor --strict" bash -c 'node bin/fh-codex-doctor.js --strict >/dev/null'

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
if [ -f scripts/package_coverage_check.sh ]; then
  if ! bash scripts/package_coverage_check.sh; then
    fail=1
  fi
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
  _refs=$(grep -hoE '\`[^\` ]+\`' CLAUDE.md .claude/rules/*.md 2>/dev/null \
    | sed 's/\`//g' \
    | grep -E '^(knowledge|templates|scripts|docs|plugins|\.claude)/[^*{}<>$]+\.(md|sh|ya?ml|jsonc|json)$' \
    | sort -u)
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
