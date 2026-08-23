#!/usr/bin/env bash
# mapped_tracks.sh — the ONE mechanical answer to "how many field harnesses are mapped in this hub?"
#
# WHY THIS EXISTS (measured 2026-08-22, known-pair in one run):
#   main checkout : 11 mapped tracks
#   a worktree    :  1
# The mapping signal is the PRESENCE of `tracks/<name>/`, and that signal cannot survive into a
# worktree for two independent reasons: (a) `tracks/**` is gitignored, and (b) at least one mapped
# track (`pmh-dev`) is an EMPTY directory, which git cannot carry even if it were tracked. So a
# worktree does not have a smaller count — it has a STRUCTURALLY BLIND one.
#
# WHY THAT WAS SILENT: the synergy skill's Step 3-b closes as `run(n pairs)` or
# `skipped(<2 mapped tracks)`, and BOTH are mandatory-pass values. A worktree run therefore closed
# GREEN while blind — the same shape as the ①-c peer-detection defect fixed the same day, on the
# instrument that grades identity ④ itself.
#
# MECHANIZED AT N=2 BY CLASS, NOT BY COUNT: `operations.md` allows mechanization at "N>=3 **or the
# same class recurring on another surface**". This class (a count over gitignored, un-committable
# state read from cwd instead of the repo's common root) hit two distinct surfaces on 2026-08-22 —
# ①-c peer placement and Step 3-b mapped-track counting. Recorded here so the threshold is not
# claimed loosely.
#
# NOT-FOUND IS NOT ZERO. If the root cannot be resolved or `tracks/` is not there, this exits 3 with
# status=UNMEASURED. It never prints `count=0` for a question it could not ask.
#
# Usage: bash scripts/mapped_tracks.sh [--count-only]
# Exit:  0 = measured · 3 = UNMEASURED (a NON-PASS; never fold into "0 mapped") · 2 = bad usage

set -uo pipefail

COUNT_ONLY=0
case "${1:-}" in
  --count-only) COUNT_ONLY=1 ;;
  "") ;;
  *) echo "usage: $0 [--count-only]" >&2; exit 2 ;;
esac

_die_unmeasured() {
  echo "status=UNMEASURED"
  echo "reason=$1"
  echo "# not-found != zero — do NOT read this as 'no mapped tracks'"
  exit 3
}

command -v git >/dev/null 2>&1 || _die_unmeasured "git-absent"

# Resolve the hub root the way this repo already sanctions for worktree-reachable evidence
# (`templates/.git-hooks/pre-commit` §EVIDENCE_ROOT): `--git-common-dir` returns the MAIN tree's .git
# from inside any worktree.
#   ⚠️ Deliberately NOT the `$(cmd || echo "")` form used there. Under a `cmd || fallback` the guard
#   depends on the failing command leaving stdout empty; the canonical form separates the value from
#   the status so a command that fails WHILE printing cannot be mistaken for a success.
_repo_root=$(git rev-parse --show-toplevel 2>/dev/null); _rc_root=$?
[ "$_rc_root" -eq 0 ] && [ -n "$_repo_root" ] || _die_unmeasured "not-in-a-git-repo"

_gcd=$(git rev-parse --git-common-dir 2>/dev/null); _rc_gcd=$?
if [ "$_rc_gcd" -ne 0 ] || [ -z "$_gcd" ]; then
  HUB_ROOT="$_repo_root"          # degraded but named below, not silently
  ROOT_SRC="repo-root(common-dir-unresolved)"
else
  case "$_gcd" in
    # `--git-common-dir` returns a RELATIVE path ('.git') at a repo root and an ABSOLUTE one inside a
    # worktree. Comparing or using it raw is exactly the bug this script exists to close.
    /*) HUB_ROOT=$(dirname "$_gcd") ;;
    *)  HUB_ROOT=$(dirname "$_repo_root/$_gcd") ;;
  esac
  ROOT_SRC="git-common-dir"
fi
# Normalise both sides before comparing — a raw string compare would reproduce the defect.
HUB_ROOT=$(cd "$HUB_ROOT" 2>/dev/null && pwd -P) || _die_unmeasured "hub-root-unreadable"
CWD_ROOT=$(cd "$_repo_root" 2>/dev/null && pwd -P) || CWD_ROOT="$_repo_root"

IN_WORKTREE=no
[ "$HUB_ROOT" != "$CWD_ROOT" ] && IN_WORKTREE=yes

[ -d "$HUB_ROOT/tracks" ] || _die_unmeasured "no-tracks-dir-at:$HUB_ROOT"

# 🟥 존재만 보면 부족하다 — «못 읽었다» 가 «없다» 로 접힌다 (2026-08-23 실측, 4케이스).
# 이 파일 머리가 "not-found != zero" 를 이유로 존재하는데, 초판은 그 규율을 **존재 검사 한 분기에만**
# 적용했다: 디렉터리가 있는데 읽을 수 없으면 아래 글롭이 조용히 0건을 내고 `status=OK count=0` 이
# 나간다 — 진짜로 매핑이 0개인 경우와 **출력이 글자 하나 안 다르다.** 그리고 하류(Step 3-b)에서
# 그 0 은 `skipped(<2 mapped tracks)` = **pass 값**으로 접히므로, 권한 문제가 초록으로 닫힌다.
#   chmod 755 → -r ✓ -x ✓  글롭 1     chmod 111 → -r ✗ -x ✓  글롭 0   ← `-x` 만 보면 통과시킨다
#   chmod 500 → -r ✓ -x ✓  글롭 1     chmod 000 → -r ✗ -x ✗  글롭 0
# ⇒ 둘 다 요구한다. 이 조합이 «글롭이 셀 수 있는가» 와 네 케이스 전부에서 일치한다(레인 P-1·P-2).
{ [ -r "$HUB_ROOT/tracks" ] && [ -x "$HUB_ROOT/tracks" ]; } || _die_unmeasured "tracks-dir-unreadable-at:$HUB_ROOT"

# Count. Underscore-prefixed dirs are META (_meta/_audit/_contrib/_chamber…) and are not mapped
# projects — the test is a LEADING underscore only.
#   ⚠️ Measured slip, kept as a comment because it cost a re-measure: a `case "$n" in *_*)` filter
#   also eats `the_bible`, whose underscore is in the middle. Anchor the pattern.
NAMES=""; COUNT=0
for _d in "$HUB_ROOT"/tracks/*/; do
  [ -d "$_d" ] || continue                  # unmatched glob stays literal in sh
  _n=$(basename "$_d")
  case "$_n" in _*) continue ;; esac
  COUNT=$((COUNT + 1))
  NAMES="$NAMES $_n"
done

if [ "$COUNT_ONLY" = "1" ]; then echo "$COUNT"; exit 0; fi

echo "status=OK"
echo "hub_root=$HUB_ROOT"
echo "root_source=$ROOT_SRC"
echo "in_worktree=$IN_WORKTREE"
echo "count=$COUNT"
echo "names=${NAMES# }"
if [ "$IN_WORKTREE" = "yes" ]; then
  echo "# NOTE: running from a worktree; the count above is the MAIN tree's, resolved via"
  echo "#       --git-common-dir. The worktree's own tracks/ is NOT the answer to this question."
fi
exit 0
