#!/usr/bin/env bash
# push_zone_check.sh — enumerate every repo you are about to push to, and say which channel each
# one requires. Run it BEFORE a multi-repo push round, not per-push.
#
# WHY THIS SHAPE
# The operator's account rule (a push under a non-owner account goes through the REST Contents API,
# new files only, never overwriting or deleting) is not hard to remember — it was read and correctly
# applied on 2026-07-26. It was applied to ONE org repo and missed on ANOTHER org repo in the same
# round. The failure was not ignorance of the rule; it was applying it at the point of discovery
# instead of across every repo in scope — the half-fix / propagation-boundary class.
#
# A per-push guard would not have caught that either: each individual push looks locally fine. What
# was missing is the ENUMERATION — "here are all the remotes in play tonight, and here is the
# channel each one needs". So this tool lists, it does not block.
#
# Usage:
#   bash scripts/push_zone_check.sh                 # scan sibling repos under the projects root
#   bash scripts/push_zone_check.sh ~/p/a ~/p/b     # scan the given repos
#
# Zone rule is intentionally NOT hardcoded here: the owner account and org names are
# operator-private. It reads them from the same gitignored source the surface scan uses, and says
# UNCALIBRATED if that source is missing rather than guessing (a guessed zone verdict is worse than
# no verdict — it would authorise the wrong channel).
set -uo pipefail

FH="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel 2>/dev/null || pwd)"
ZONE_SRC="${PUSH_ZONE_OWNERS:-$FH/.claude/rules/.push-zone-owners}"

owner_accounts=""
if [ -f "$ZONE_SRC" ]; then
  owner_accounts="$(grep -vE '^\s*(#|$)' "$ZONE_SRC" | tr '\n' ' ')"
fi

if [ -z "$owner_accounts" ]; then
  echo "push_zone_check: UNCALIBRATED — no owner-account list at $ZONE_SRC"
  echo "  Create it (gitignored, one account/org per line: the accounts whose repos you may push to"
  echo "  with plain git). Without it this tool cannot tell a personal remote from an org remote,"
  echo "  and a guessed verdict would authorise the wrong channel."
  exit 2
fi

active="$(gh auth status 2>/dev/null | sed -n 's/.*Logged in to github.com account \([^ ]*\).*/\1/p' | head -1)"
[ -n "$active" ] || active="(unknown)"

echo "push_zone_check — active gh account: $active"
echo "owner accounts (plain git allowed): $owner_accounts"
echo

targets=("$@")
if [ "${#targets[@]}" -eq 0 ]; then
  root="$(dirname "$FH")"
  while IFS= read -r d; do targets+=("$(dirname "$d")"); done < <(find "$root" -maxdepth 2 -name .git -type d 2>/dev/null | sort)
fi

need_rest=0
for repo in "${targets[@]}"; do
  [ -d "$repo/.git" ] || continue
  url="$(git -C "$repo" remote get-url origin 2>/dev/null)"
  [ -n "$url" ] || continue
  # owner = the path segment before the repo name, for both ssh and https forms
  owner="$(printf '%s' "$url" | sed -E 's#^.*[:/]([^/]+)/[^/]+$#\1#')"
  ahead="$(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null || echo '?')"
  channel="REST Contents API (new files only, no overwrite/delete)"
  mark="🔶"
  for o in $owner_accounts; do
    if [ "$owner" = "$o" ]; then channel="plain git push"; mark="✅"; break; fi
  done
  [ "$mark" = "🔶" ] && need_rest=$((need_rest + 1))
  printf '%s %-26s owner=%-18s unpushed=%-3s → %s\n' "$mark" "$(basename "$repo")" "$owner" "$ahead" "$channel"
done

echo
if [ "$need_rest" -gt 0 ]; then
  echo "⚠️  $need_rest repo(s) are outside the owner accounts — those need the REST channel."
  echo "    Decide the channel for ALL of them now, in one pass. The 2026-07-26 miss was exactly"
  echo "    this: the rule was applied to one such repo and forgotten on another in the same round."
fi
echo "This tool lists; it does not block. The blocking floor for THIS repo stays templates/.git-hooks/pre-push."
