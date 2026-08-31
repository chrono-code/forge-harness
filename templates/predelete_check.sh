#!/usr/bin/env bash
# predelete_check.sh — Destructive-Op Gate step 1: enumerate what branch deletion would lose.
# Class: measured (mechanical enumeration) — the verdicts feed the gate's judged recovery step.
# Usage: predelete_check.sh <repo-path> [<base-ref>=origin/main]
# For every remote branch except the base: commits absent from base + paths absent from base.
#   SAFE   — fully merged (0 commits off base)
#   CHECK  — commits off base but 0 unique paths: content may still be NEWER than base on shared
#            files (e.g. an unmerged session card) — needs a content-direction look before delete
#   REVIEW — unique paths exist: recover/integrate BEFORE any deletion
# Exit 1 when any REVIEW exists (blocks a scripted delete chain).
#
# DEGRADE DIRECTION — irreversible surface → fail-CLOSED (CLAUDE.md §Irreversibility Surface-Class
# Degrade Invariant). A FAILED enumeration is NOT an empty (safe) enumeration. Fixed 2026-07-03
# (cross-family sweep, default-toward-PASS class): the prior version degraded OPEN in three ways —
#   (a) `git branch -r` failing / the repo not resolving → empty for-loop → exit 0 (green-light);
#   (b) a branch or base ref that does not resolve → git errors swallowed by 2>/dev/null → n=0,uniq=0
#       → printed SAFE (an errored ref is not "merged");
#   (c) substring exclusion `grep -vE "origin/(main|HEAD)"` also skipped `origin/main-backup` etc.
# Each is now closed: a resolution/enumeration failure exits non-zero (exit 2 = harness error, distinct
# from exit 1 = REVIEW pending); an unresolvable branch ref is classified REVIEW (fail-closed); base/HEAD
# exclusion is EXACT. A fetch failure is surfaced (stale enumeration is a real risk on this surface),
# never silently swallowed.
set -u
repo="${1:?repo path}"; base="${2:-origin/main}"
cd "$repo" || { echo "FAIL: cannot cd to repo '$repo'" >&2; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "FAIL: '$repo' is not a git repo" >&2; exit 2; }

# Fetch: surface failure (stale enumeration on an irreversible surface is a real risk), do not swallow.
if ! git fetch origin --quiet 2>/dev/null; then
  echo "WARN: 'git fetch origin' failed — enumerating against possibly-STALE remote refs" >&2
fi

# Base must resolve, else every comparison is bogus and the old code would misclassify SAFE → fail-closed.
git rev-parse --verify --quiet "${base}^{commit}" >/dev/null || {
  echo "FAIL: base ref '$base' does not resolve — cannot enumerate; refusing to green-light delete" >&2
  exit 2; }

# Branch list: distinguish "command failed" (fail-closed) from "0 remote branches" (legitimately nothing).
if ! branches_raw=$(git branch -r 2>/dev/null); then
  echo "FAIL: 'git branch -r' failed — cannot enumerate remote branches" >&2; exit 2
fi

fail=0
while IFS= read -r ref; do
  ref="${ref#"${ref%%[![:space:]]*}"}"     # left-trim leading whitespace
  ref="${ref%% *}"                          # drop any '-> origin/main' HEAD annotation
  [ -z "$ref" ] && continue
  # EXACT base/HEAD exclusion — a substring test would wrongly skip 'origin/main-backup'.
  [ "$ref" = "$base" ] && continue
  [ "$ref" = "origin/main" ] && continue
  [ "$ref" = "origin/HEAD" ] && continue
  b="${ref#origin/}"
  # Ref must resolve, else classify REVIEW (fail-closed) — an errored ref is NOT 'merged/SAFE'.
  if ! git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null; then
    echo "REVIEW  $b — ref does not resolve (enumeration error) → do NOT delete blind"
    fail=1; continue
  fi
  n=$(git log --oneline "${base}..${ref}" 2>/dev/null | wc -l | tr -d ' ')
  # 🟥 2026-08-31 — 로케일 접힘 방지. 여기가 접히면 unique path 가 줄어 REVIEW 판정이
  #    CHECK/SAFE 로 강등된다(비가역 표면). [[feedback_locale_string_equality_breaks_nonascii]]
  uniq=$(LC_ALL=C comm -23 <(git ls-tree -r --name-only "$ref" 2>/dev/null | LC_ALL=C sort) \
                  <(git ls-tree -r --name-only "$base" 2>/dev/null | LC_ALL=C sort) | wc -l | tr -d ' ')
  if [ "$uniq" -gt 0 ]; then
    echo "REVIEW  $b — unique paths: $uniq, commits off base: $n → recover/integrate BEFORE delete"
    fail=1
  elif [ "$n" -gt 0 ]; then
    echo "CHECK   $b — $n commits off base, 0 unique paths → verify content superseded (newer-version-on-shared-file risk; tip: compare tip date vs base coverage)"
  else
    echo "SAFE    $b — fully merged"
  fi
done <<< "$branches_raw"
echo "--"
echo "Gate order: enumerate -> recover -> destroy. REVIEW blocks; CHECK needs a judged look; only then delete."
exit $fail
