#!/usr/bin/env bash
# test_peer_worktree_detect_lanes.sh — regression anchor for ①-c peer detection across WORKTREES.
#
# CLOSES: session_close_check.sh ①-c placed peers by DIRECTORY PREFIX ("$FH"/*), which fails
# structurally for every worktree of the same repo — a worktree lives outside the main tree by
# definition. Measured 2026-08-22 (tracks/_meta/probe_2026-08-22_A2_replication.md): from the main
# tree the worktree peer moved NO counter at all; from a worktree the script printed a confident
# "✅ no live peer" while three live same-repo sessions were running.
#
# HERMETIC ON PURPOSE: this builds its OWN throwaway repo + worktree + processes + socket dir. It
# never reads /tmp/cc-socks and never depends on this repo having a worktree, so it measures the
# script's logic rather than the machine it happens to run on.
#
# KNOWN PAIR — the lane is only trustworthy because it carries both halves:
#   known-POSITIVE : a live session in a different worktree of the SAME repo  → must be caught
#   known-NEGATIVE : a live session in a DIFFERENT repo                       → must NOT be caught,
#                    and must not nag (else every close is nagged about unrelated projects, which
#                    trains skimming past the lines that matter)
# A lane that only asserts the positive would pass on a script that flags literally everything.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO_ROOT="$(pwd -P)"
CC="$REPO_ROOT/scripts/session_close_check.sh"
PASS=0; FAIL=0
ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

if [ ! -f "$CC" ]; then
  echo "ⓘ session_close_check.sh absent — lanes UNMEASURED (not a pass)"; exit 0
fi

TMP="$(mktemp -d 2>/dev/null)" || { echo "ⓘ mktemp failed — UNMEASURED"; exit 0; }
PIDS=""
cleanup() { for p in $PIDS; do kill "$p" 2>/dev/null; done; rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

# ── fixtures ────────────────────────────────────────────────────────────────────
mkdir -p "$TMP/socks"
git init -q "$TMP/main" 2>/dev/null || { echo "ⓘ git init failed — UNMEASURED"; exit 0; }
git -C "$TMP/main" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null
git -C "$TMP/main" worktree add -q -b lanewt "$TMP/wt" 2>/dev/null \
  || { echo "ⓘ git worktree add failed — UNMEASURED"; exit 0; }
git init -q "$TMP/otherrepo" 2>/dev/null

spawn() { ( cd "$1" && exec sleep 900 >/dev/null 2>&1 </dev/null & echo $! ); }
P_MAIN=$(spawn "$TMP/main")       # known-positive, seen from the worktree's standpoint
P_WT=$(spawn "$TMP/wt")           # known-positive, seen from the main tree's standpoint
N_OTHER=$(spawn "$TMP/otherrepo") # known-negative
PIDS="$P_MAIN $P_WT $N_OTHER"
for p in $PIDS; do touch "$TMP/socks/$p.sock"; done

# INSTRUMENT CHECK — if the fixtures did not actually land in different directories, every verdict
# below is meaningless. Assert the premise before trusting the measurement.
_cwd_of() {
  if [ -r "/proc/$1/cwd" ]; then readlink "/proc/$1/cwd" 2>/dev/null; return; fi
  command -v lsof >/dev/null 2>&1 || return 0
  lsof -a -p "$1" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1
}
C_MAIN=$(_cwd_of "$P_MAIN"); C_WT=$(_cwd_of "$P_WT"); C_OTHER=$(_cwd_of "$N_OTHER")
if [ -z "$C_MAIN" ] || [ -z "$C_WT" ] || [ -z "$C_OTHER" ]; then
  echo "ⓘ cwd of a fixture process is unresolvable here (no /proc, no lsof) — lanes UNMEASURED"; exit 0
fi
[ "$C_MAIN" != "$C_WT" ] && [ "$C_WT" != "$C_OTHER" ] \
  && ok "premise: the three fixtures hold three distinct cwds" \
  || ng "premise BROKEN: fixture cwds collide — verdicts below mean nothing"

scan() { # $1 = the $FH standpoint to scan from
  FH_PEER_SCAN_FORCE=1 FH_PEER_SOCK_DIR="$TMP/socks" bash "$CC" "$1" 2>&1 | grep '①-c' | head -1
}

# ── W-1/W-2: the same-repo worktree peer is caught from BOTH standpoints ─────────
# Both directions are asserted because the defect was asymmetric: from the main tree the peer
# vanished silently; from the worktree the whole set vanished behind a green line.
OUT_MAIN=$(scan "$TMP/main")
case "$OUT_MAIN" in
  *"peer CANDIDATE"*"$P_WT"*) ok "W-1 from MAIN tree → the worktree peer ($P_WT) is caught" ;;
  *) ng "W-1 from MAIN tree → worktree peer ($P_WT) NOT caught — got: $OUT_MAIN" ;;
esac
OUT_WT=$(scan "$TMP/wt")
case "$OUT_WT" in
  *"peer CANDIDATE"*"$P_MAIN"*) ok "W-2 from WORKTREE → the main-tree peer ($P_MAIN) is caught" ;;
  *) ng "W-2 from WORKTREE → main-tree peer ($P_MAIN) NOT caught — got: $OUT_WT" ;;
esac

# ── W-3: known-negative — a different repo is NOT claimed as a peer ──────────────
case "$OUT_WT" in
  *"$N_OTHER"*) ng "W-3 known-negative FAILED — other-repo session ($N_OTHER) claimed as a peer" ;;
  *) ok "W-3 known-negative holds — other-repo session ($N_OTHER) is not claimed as a peer" ;;
esac

# ── W-4: an other-repo peer alone stays GREEN (over-block direction) ─────────────
# This lane exists to protect the FALSE-POSITIVE direction. A close that nags about every unrelated
# project trains the runner to skim ①-c, and the same hook carries the destructive-op gate.
mkdir -p "$TMP/socks_neg"; cp "$TMP/socks/$N_OTHER.sock" "$TMP/socks_neg/"
OUT_NEG=$(FH_PEER_SCAN_FORCE=1 FH_PEER_SOCK_DIR="$TMP/socks_neg" bash "$CC" "$TMP/wt" 2>&1 | grep '①-c' | head -1)
case "$OUT_NEG" in
  "✅"*"no live peer"*) ok "W-4 other-repo peer alone → stays green, no nag" ;;
  *) ng "W-4 OVER-BLOCK — other-repo peer alone produced: $OUT_NEG" ;;
esac
# ...and it is green about something it actually counted, not by discarding it silently.
case "$OUT_NEG" in
  *"in other repo(s)"*) ok "W-5 the green line ACCOUNTS for the excluded peer (measured, not dropped)" ;;
  *) ng "W-5 green line hides what it excluded — got: $OUT_NEG" ;;
esac

# ── W-6: cwd readable but in NO repo → UNPLACEABLE, never 'absent' ──────────────
# not-found != zero. This is the counter whose absence let the original `case` fall through.
mkdir -p "$TMP/norepo" "$TMP/socks_off"
N_OFF=$(spawn "$TMP/norepo"); PIDS="$PIDS $N_OFF"; touch "$TMP/socks_off/$N_OFF.sock"
OUT_OFF=$(FH_PEER_SCAN_FORCE=1 FH_PEER_SOCK_DIR="$TMP/socks_off" bash "$CC" "$TMP/wt" 2>&1 | grep '①-c' | head -1)
case "$OUT_OFF" in
  *UNPLACEABLE*) ok "W-6 no-repo peer → surfaced as UNPLACEABLE, not as 'no live peer'" ;;
  *) ng "W-6 no-repo peer rendered as absence — got: $OUT_OFF" ;;
esac

# ── W-7: ①-c stays ADVISORY — it must never change the exit code ────────────────
# The close push blocks on this script. Peer detection is a "go ask someone" signal, not a close
# invariant, and a new blocking source would train `--no-verify` on the hook that also carries the
# destructive-op gate. Same $FH, loud vs empty peer set → identical exit code.
mkdir -p "$TMP/socks_empty"
FH_PEER_SCAN_FORCE=1 FH_PEER_SOCK_DIR="$TMP/socks"       bash "$CC" "$TMP/wt" >/dev/null 2>&1; RC_LOUD=$?
FH_PEER_SCAN_FORCE=1 FH_PEER_SOCK_DIR="$TMP/socks_empty" bash "$CC" "$TMP/wt" >/dev/null 2>&1; RC_QUIET=$?
[ "$RC_LOUD" = "$RC_QUIET" ] \
  && ok "W-7 ①-c is advisory — exit code identical with peers ($RC_LOUD) and without ($RC_QUIET)" \
  || ng "W-7 ①-c CHANGED the exit code ($RC_QUIET → $RC_LOUD) — it must not block a close"

echo "──────────────────────────────────────────────"
if [ "$FAIL" -eq 0 ]; then
  echo "PEER-WORKTREE-DETECT LANES: PASS ($PASS/$PASS)"
  echo "  Scope: repo-identity placement + the over-block direction. NOT covered: whether the env"
  echo "  gate (CLAUDE_CODE_CHILD_SESSION) stands correctly in a real top-level session — every"
  echo "  lane here forces the scan with FH_PEER_SCAN_FORCE=1, the same residual ①-c already names."
  exit 0
else
  echo "PEER-WORKTREE-DETECT LANES: FAIL ($FAIL failed · $PASS passed)"
  exit 1
fi
