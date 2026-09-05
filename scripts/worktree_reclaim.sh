#!/usr/bin/env bash
# worktree_reclaim.sh — reclaim gitignored `tracks/**` artifacts from a git worktree BEFORE it is removed.
#
# WHY (N=2, so a script — 2026-09-02 signal + 2026-09-05 push-zone dispatch): the Destructive-Op gate
# enumerates COMMITS, and `tracks/**` is gitignored, so a worktree removal can delete a session's only
# copy of a signal file / governance log / dispatch report without any gate ever seeing it. Both
# incidents lost real files (51-line signal · a day's governance log). The manual recipe that replaced
# them — `diff -rq <wt>/tracks tracks | grep "^Only in <wt>"` → list to a FILE → copy → only then
# remove — is exactly what this script does, in that order, because after the copy «never existed»
# and «already moved» are indistinguishable (the list file is the evidence).
#
# USAGE
#   bash scripts/worktree_reclaim.sh <worktree-path>            # enumerate only (writes the list file)
#   bash scripts/worktree_reclaim.sh <worktree-path> --apply    # enumerate + copy + verify
#
# EXIT  0 = nothing to reclaim, or everything reclaimed and byte-verified
#       1 = files exist on BOTH sides with different content — a human must merge (listed, not copied)
#       2 = usage / not a worktree of a main checkout
#       10 = harness error (list file unwritable, copy failed verification)
#
# NEVER removes the worktree. Removal stays an explicit `git worktree remove` after this exits 0.
set -uo pipefail
# bash 3.2 + `set -u`: expanding an EMPTY array with "${a[@]}" is a fatal unbound-variable error, so every
# array loop below uses the ${a[@]+"${a[@]}"} idiom (measured on the first fixture run, 2026-09-05).

WT="${1:-}"; MODE="${2:-}"
[ -n "$WT" ] || { echo "usage: $0 <worktree-path> [--apply]" >&2; exit 2; }
[ -d "$WT" ] || { echo "🟥 not a directory: $WT" >&2; exit 2; }
case "$MODE" in ''|--apply) ;; *) echo "usage: $0 <worktree-path> [--apply]" >&2; exit 2 ;; esac

COMMON="$(git -C "$WT" rev-parse --git-common-dir 2>/dev/null)" || { echo "🟥 not a git worktree: $WT" >&2; exit 2; }
GITDIR="$(git -C "$WT" rev-parse --git-dir 2>/dev/null)"
case "$COMMON" in /*) ;; *) COMMON="$WT/$COMMON" ;; esac
case "$GITDIR" in /*) ;; *) GITDIR="$WT/$GITDIR" ;; esac
COMMON="$(cd "$COMMON" && pwd -P)"; GITDIR="$(cd "$GITDIR" && pwd -P)"
if [ "$COMMON" = "$GITDIR" ]; then
  echo "🟥 $WT is the MAIN checkout (git-dir == git-common-dir), not a worktree — nothing to reclaim from itself" >&2; exit 2
fi
ROOT="$(dirname "$COMMON")"           # main checkout root = parent of the shared .git
WT="$(cd "$WT" && pwd -P)"
SRC="$WT/tracks"; DST="$ROOT/tracks"
[ -d "$SRC" ] || { echo "ℹ️  no tracks/ in worktree — nothing to reclaim (rc=0)"; exit 0; }
mkdir -p "$DST/_meta/dispatch" 2>/dev/null || { echo "🟥 cannot create $DST/_meta/dispatch" >&2; exit 10; }

NAME="$(basename "$WT")"; TS="$(date +%Y%m%d-%H%M%S)"
LIST="$DST/_meta/dispatch/reclaim_${NAME}_${TS}.txt"

# 1. ENUMERATE — the list lands in a file FIRST (the evidence that survives the copy)
ONLY=(); DIFF=()
while IFS= read -r line; do
  case "$line" in
    "Only in $SRC"*)
      d="${line#Only in }"; dir="${d%%: *}"; f="${d#*: }"
      rel="${dir#$SRC}"; rel="${rel#/}"
      p="${rel:+$rel/}$f"
      if [ -d "$SRC/$p" ]; then
        while IFS= read -r ff; do ONLY+=("${ff#$SRC/}"); done < <(find "$SRC/$p" -type f)
      else
        ONLY+=("$p")
      fi ;;
    "Files $SRC"*" differ") DIFF+=("$(printf '%s' "${line#Files }" | sed "s# and .*##; s#^$SRC/##")") ;;
  esac
done < <(diff -rq "$SRC" "$DST" 2>/dev/null)

{
  echo "# worktree_reclaim — $WT → $ROOT  ($TS)"
  echo "# only-in-worktree: ${#ONLY[@]}   differ-both-sides: ${#DIFF[@]}   mode: ${MODE:-enumerate}"
  for p in ${ONLY[@]+"${ONLY[@]}"}; do echo "ONLY	$p"; done
  for p in ${DIFF[@]+"${DIFF[@]}"}; do echo "DIFF	$p"; done
} > "$LIST" || { echo "🟥 cannot write list file $LIST" >&2; exit 10; }
echo "── worktree_reclaim: $NAME ──"
echo "   only-in-worktree: ${#ONLY[@]} · differ-both-sides: ${#DIFF[@]} · list: ${LIST#$ROOT/}"
for p in ${ONLY[@]+"${ONLY[@]}"}; do echo "   ONLY  $p"; done
for p in ${DIFF[@]+"${DIFF[@]}"}; do echo "   DIFF  $p   (both sides exist and differ — NOT copied, merge by hand)"; done

# 2. RECLAIM (--apply) — copy, then verify byte-identical; a copy that cannot be verified is a harness error
if [ "$MODE" = "--apply" ] && [ "${#ONLY[@]}" -gt 0 ]; then
  bad=0
  for p in ${ONLY[@]+"${ONLY[@]}"}; do
    mkdir -p "$(dirname "$DST/$p")" && cp -p "$SRC/$p" "$DST/$p" && cmp -s "$SRC/$p" "$DST/$p" \
      && echo "   ✅ reclaimed $p" || { echo "   🟥 copy/verify FAILED $p"; bad=$((bad+1)); }
  done
  [ "$bad" -eq 0 ] || { echo "🟥 $bad file(s) not reclaimed — do NOT remove the worktree" >&2; exit 10; }
fi

if [ "${#DIFF[@]}" -gt 0 ]; then
  echo "⚠️  ${#DIFF[@]} file(s) differ on both sides — reconcile by hand before removing the worktree (rc=1)"
  exit 1
fi
if [ "${#ONLY[@]}" -gt 0 ] && [ "$MODE" != "--apply" ]; then
  echo "ℹ️  ${#ONLY[@]} file(s) exist only in the worktree — re-run with --apply to copy them (rc=1 until reclaimed)"
  exit 1
fi
echo "✅ nothing left only in the worktree — safe to: git worktree remove $WT"
exit 0
