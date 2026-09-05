#!/usr/bin/env bash
# test_worktree_reclaim_lanes.sh — known pairs for scripts/worktree_reclaim.sh (2026-09-05).
# Fixture: a real `git init` main checkout + a real `git worktree add`, gitignored tracks/ on both sides.
# The lanes assert the ORDER (list file before copy) as well as the verdicts — the list is the evidence
# that survives the copy, which is the whole reason the script exists.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd -P)"
SUT="$ROOT/scripts/worktree_reclaim.sh"   # own line: new_code_anchor_check resolves the variable per line
PASS=0; FAIL=0
ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
ng() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
[ -f "$SUT" ] || { echo "ⓘ worktree_reclaim.sh absent — subject missing when we looked (NOT a pass)"; exit 2; }
T="$(mktemp -d 2>/dev/null)" || { echo "ⓘ mktemp failed (NOT a pass)"; exit 10; }
trap 'rm -rf "$T"' EXIT INT TERM

mk_pair() {  # $1=root → creates $1/main (checkout) + $1/wt (worktree); echoes nothing
  mkdir -p "$1" && ( cd "$1" && git init -q main && cd main \
    && git config user.email l@example.invalid && git config user.name lane \
    && mkdir -p tracks/_meta && printf 'tracks/\n' > .gitignore && echo x > README.md \
    && git add .gitignore README.md && git commit -qm init && git worktree add -q ../wt -b wt-branch ) 2>/dev/null
}

echo "── W1 enumerate: only-in files are listed, list file written, rc=1, nothing copied ──"
mk_pair "$T/a"; M="$T/a/main"; W="$T/a/wt"
mkdir -p "$W/tracks/_meta/sub"; echo "signal body" > "$W/tracks/_meta/fh_signal_lost.md"; echo nested > "$W/tracks/_meta/sub/deep.yaml"
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && ok "W1 rc=1 (only-in exists, not yet reclaimed)" || { ng "W1 rc=$RC (기대 1)"; printf '%s\n' "$OUT" | sed 's/^/     /'; }
N=$(printf '%s\n' "$OUT" | grep -c '   ONLY  '); [ "$N" -eq 2 ] && ok "W1b 2 only-in files listed (nested dir walked)" || ng "W1b listed $N (기대 2)"
L=$(ls "$M"/tracks/_meta/dispatch/reclaim_wt_*.txt 2>/dev/null | wc -l | tr -d ' '); [ "$L" -eq 1 ] && ok "W1c list file written in MAIN tracks/_meta/dispatch" || ng "W1c list files: $L (기대 1)"
grep -q $'^ONLY\t_meta/sub/deep.yaml' "$M"/tracks/_meta/dispatch/reclaim_wt_*.txt && ok "W1d list carries the relative path" || ng "W1d list lacks the nested path"
[ ! -e "$M/tracks/_meta/fh_signal_lost.md" ] && ok "W1e enumerate mode copies nothing (known-negative)" || ng "W1e enumerate mode copied a file"

echo "── W2 --apply: copied, byte-verified, rc=0; re-run says nothing left ──"
OUT="$(bash "$SUT" "$W" --apply 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "W2 --apply rc=0" || { ng "W2 rc=$RC (기대 0)"; printf '%s\n' "$OUT" | sed 's/^/     /'; }
cmp -s "$W/tracks/_meta/fh_signal_lost.md" "$M/tracks/_meta/fh_signal_lost.md" && cmp -s "$W/tracks/_meta/sub/deep.yaml" "$M/tracks/_meta/sub/deep.yaml" \
  && ok "W2b both files byte-identical in main" || ng "W2b copies differ or missing"
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "W2c re-run after reclaim → rc=0 (idempotent)" || ng "W2c re-run rc=$RC"
case "$OUT" in *"safe to: git worktree remove"*) ok "W2d prints the next (human) step, never runs it" ;; *) ng "W2d no next-step line" ;; esac
[ -d "$W" ] && ok "W2e worktree still exists (script never removes)" || ng "W2e worktree vanished"

echo "── W3 differ-both-sides: listed, NOT copied, rc=1 even with --apply ──"
echo same > "$M/tracks/_meta/shared.md"; echo "changed in wt" > "$W/tracks/_meta/shared.md"
OUT="$(bash "$SUT" "$W" --apply 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && ok "W3 rc=1 (needs a human)" || ng "W3 rc=$RC (기대 1)"
case "$OUT" in *"DIFF  _meta/shared.md"*) ok "W3b the differing file is named" ;; *) ng "W3b DIFF not listed" ;; esac
grep -q '^same$' "$M/tracks/_meta/shared.md" && ok "W3c main copy untouched (known-negative: no overwrite)" || ng "W3c main copy was overwritten"

echo "── W4 list-before-copy: unwritable list dir → rc=10 and NO copy happened ──"
mk_pair "$T/b"; M="$T/b/main"; W="$T/b/wt"
mkdir -p "$W/tracks/_meta" && echo body > "$W/tracks/_meta/only.md"; rm -rf "$M/tracks/_meta/dispatch"; touch "$M/tracks/_meta/dispatch"   # a FILE where the dir must be
[ -f "$W/tracks/_meta/only.md" ] && ok "W4-FIXTURE the only-in file exists in the worktree (potency)" || ng "W4-FIXTURE fixture file missing — W4b would pass vacuously"
OUT="$(bash "$SUT" "$W" --apply 2>&1)"; RC=$?
[ "$RC" -eq 10 ] && ok "W4 rc=10 when the evidence file cannot be written" || ng "W4 rc=$RC (기대 10)"
[ ! -e "$M/tracks/_meta/only.md" ] && ok "W4b nothing was copied before the list failed (order holds)" || ng "W4b copy happened without a list"

echo "── W5 argument guards ──"
OUT="$(bash "$SUT" "$M" 2>&1)"; RC=$?; [ "$RC" -eq 2 ] && ok "W5 main checkout as argument → rc=2" || ng "W5 rc=$RC (기대 2)"
OUT="$(bash "$SUT" "$T" 2>&1)"; RC=$?; [ "$RC" -eq 2 ] && ok "W5b non-repo dir → rc=2" || ng "W5b rc=$RC (기대 2)"
OUT="$(bash "$SUT" "$W" --bogus 2>&1)"; RC=$?; [ "$RC" -eq 2 ] && ok "W5c unknown flag → rc=2" || ng "W5c rc=$RC (기대 2)"
OUT="$(bash "$SUT" 2>&1)"; RC=$?; [ "$RC" -eq 2 ] && ok "W5d no argument → rc=2" || ng "W5d rc=$RC (기대 2)"
mk_pair "$T/c"; rm -rf "$T/c/wt/tracks"; OUT="$(bash "$SUT" "$T/c/wt" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "W5e worktree without tracks/ → rc=0 nothing to reclaim" || ng "W5e rc=$RC (기대 0)"

echo
echo "── worktree-reclaim lanes: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
