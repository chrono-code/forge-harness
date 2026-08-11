#!/usr/bin/env bash
# test_count_check_readme_format_lanes.sh — known-pair anchor for the README format override guard
# in `scripts/count_check.sh`.
#
# WHY THIS EXISTS
# `count_check.sh` is a **mandatory-pass** gate wired into selfcheck → prepublishOnly, pre-commit
# and CI. Its README check renders a caller-supplied printf template and uses the RESULT as a
# `grep -qE` pattern. Two ways that goes wrong, both measured 2026-08-12:
#   · a template rendering a NEWLINE turns the pattern into an OR search — a stale README (99/99)
#     PASSED because the trailing fragment "8" matched "Node 18" elsewhere in the file;
#   · `printf` failure and value-swallowing directives (`%.0s`) produced partial patterns, unchecked.
# The guard that closes this shipped with **zero** anchors in the same commit that added four
# anchors for a sibling fix — the exact "you can delete the feature and stay green" class that
# commit was closing. This file is that missing half.
#
# SCOPE, stated honestly: these lanes exercise the guard's DECISION LOGIC in isolation (render →
# inspect → accept/reject), not the whole count_check run. The full script needs a git worktree
# with a populated plugin tree; a fixture that lacks one fails for an unrelated reason ("0 active
# fh-meta skills") and every arm goes red for the SAME wrong cause — which is how a first attempt
# at this test nearly certified a guard that had not been exercised at all.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBJECT="$REPO_ROOT/scripts/count_check.sh"
pass=0; fail=0
ok()  { printf '  \342\234\205 %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \342\235\214 %s\n' "$1"; fail=$((fail+1)); }

# The guard block is extracted from the subject rather than restated here: a copy drifts from the
# thing it claims to verify, which is the divergent-normalizer defect this repo has hit before.
GUARD=$(awk '/^  README_STR=\$\(printf/,/^  \[ -n "\$README_STR" \] && count_check/' "$SUBJECT")
if [ -z "$GUARD" ]; then
  bad "guard block not found in count_check.sh — the anchor cannot verify what it cannot locate"
  echo "----"; echo "count_check README-format lanes: $pass passed, $fail failed"; exit 1
fi

probe() {   # $1 = template ; echoes rc + a reason token
  local fmt="$1"
  bash -c '
    set -uo pipefail
    total_sk=40; total_ag=8; fail=0
    README_FMT="$1"
    count_check() { echo "ACCEPTED:$3"; }
    '"$GUARD"'
    exit $fail
  ' _ "$fmt" 2>&1
  return $?
}

run() {   # $1 = label ; $2 = template ; $3 = expect (accept|reject)
  local out rc; out=$(probe "$2"); rc=$?
  case "$3" in
    accept) if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'ACCEPTED:'; then
              ok "$1 — accepted (no over-block)"
            else bad "$1 — legitimate template was REJECTED (rc=$rc): $out"; fi ;;
    reject) if [ "$rc" -ne 0 ]; then ok "$1 — rejected (rc=$rc)"
            else bad "$1 — a broken template PASSED the gate: $out"; fi ;;
  esac
}

echo "== count_check README format override — known pair =="
# Accept arms. Two of them on purpose: the default and a localized one. The whole point of the
# override is downstream harnesses writing their own wording, so an English-only accept arm would
# not notice a guard that rejects every non-ASCII template.
run "A1 default English"      '%s skills · %s agents'   accept
run "A2 localized (Korean)"   '스킬 %s개 · 에이전트 %s개'  accept
run "A3 markdown decoration"  '**%s** skills / **%s** agents' accept
# Reject arms — each must fail for its OWN reason, not a shared incidental one.
run "R1 renders a newline"    '%s
%s'                                                     reject
run "R2 swallows a value"     '%.0s%s agents'           reject

echo "----"
echo "count_check README-format lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
