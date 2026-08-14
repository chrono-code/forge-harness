#!/usr/bin/env bash
# sync_to_be_lanes.sh — mechanical regression lanes for scripts/sync-to-be.sh (the FORWARD path)
#
# WHY: sync_from_be_lanes.sh covers the RETURN path exhaustively, but nothing asserted the forward
# path's own re-homing behavior — the exact side pmh-dev#69 reported a real defect on
# (.substrate_versions colliding between two nodes of the same hub). Each lane below reproduces
# one measured or predicted defect from that review and asserts it stays closed.
#
# CONTROL DISCIPLINE: same as sync_from_be_lanes.sh — an absence assertion is paired with a
# known-positive in the same run, and each fixture is checked to exist before the run that is
# supposed to consume it.
#
# USAGE: bash scripts/sync_to_be_lanes.sh          → runs all lanes, exit 0 = all pass, 1 = any fail
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/sync-to-be.sh"
[ -f "$SCRIPT" ] || { echo "missing target: $SCRIPT" >&2; exit 10; }
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s\n' "$1"; }
chk(){ if [ "$1" = "0" ]; then ok "$2"; else no "$2"; fi; }

# fresh sandbox — HUB must carry the real identity header (fh_hub_identity.sh reads it), and BE
# must be a real (if remote-less) git repo: sync-to-be.sh has no --no-git escape hatch, and a
# non-repo BE leaves `git add`/`git diff --cached` in an undefined state. fetch/pull/push against
# a missing remote fail silently (the script itself guards each with `2>/dev/null`), so a bare
# local init is sufficient and never reaches out to the network.
new_env(){
  ENV_DIR="$ROOT/$1"; rm -rf "$ENV_DIR"
  HUB="$ENV_DIR/hubx"; BEX="$ENV_DIR/be"
  mkdir -p "$HUB/tracks/_meta" "$BEX"
  printf '# forge-harness — Persistent Knowledge Hub\n' > "$HUB/CLAUDE.md"
  git -C "$BEX" init -q
  git -C "$BEX" config user.email "lane@test.local"
  git -C "$BEX" config user.name "lane-test"
}
run(){ HOME="$ENV_DIR/home" HUB_DIR="$HUB" BE_DIR="$BEX" FH_MACHINE_ID="${MID:-lanea}" bash "$SCRIPT" --quiet "$@"; }

echo "── L1 .substrate_versions is re-homed under substrate/\$MID, never left at the shared path ──"
new_env l1
printf 'claude=1.0\ncodex=2.0\n' > "$HUB/tracks/_meta/.substrate_versions"
printf 'ordinary\n' > "$HUB/tracks/_meta/normal.md"
MID=lanea run >/dev/null 2>&1
[ -f "$BEX/tracks-meta/normal.md" ]; chk $? "CONTROL: an ordinary file synced at all (run actually executed)"
[ -f "$BEX/tracks-meta/substrate/lanea" ]; chk $? "own substrate record landed machine-scoped"
[ "$(cat "$BEX/tracks-meta/substrate/lanea")" = "$(printf 'claude=1.0\ncodex=2.0')" ]; chk $? "content survived the re-home intact"
[ ! -f "$BEX/tracks-meta/.substrate_versions" ]; chk $? "shared unscoped copy retired, not left behind"

echo "── L2 a second machine's sync never overwrites the first's substrate record (pmh-dev#69 known-positive) ──"
new_env l2
printf 'claude=1.0\n' > "$HUB/tracks/_meta/.substrate_versions"
MID=lanea run >/dev/null 2>&1
[ -f "$BEX/tracks-meta/substrate/lanea" ]; chk $? "CONTROL: machine A's own record landed first"
printf 'claude=9.9-DIFFERENT\n' > "$HUB/tracks/_meta/.substrate_versions"
MID=laneb run >/dev/null 2>&1
[ "$(cat "$BEX/tracks-meta/substrate/lanea")" = "claude=1.0" ]; chk $? "machine A's record byte-unchanged after machine B's sync (the actual pmh-dev#69 collision, closed)"
[ "$(cat "$BEX/tracks-meta/substrate/laneb")" = "claude=9.9-DIFFERENT" ]; chk $? "machine B got its own distinct record"

echo "── L3 a PRE-FIX stale unscoped copy is reaped, not treated as a destination-newer conflict (pmh-dev#69 A1) ──"
new_env l3
# Wall-clock ordering, not touch -d (portability: BSD touch on macOS rejects GNU-style -d offsets —
# the exact class of bug this repo's own mktemp GNU/BSD incident already named). The hub's file must
# be written to its FINAL content BEFORE the companion's stale copy — writing to the hub file again
# afterward (even to the same content) re-stamps its mtime and can collapse the ordering back to the
# same second, silently defeating the fixture (measured while writing this lane: an earlier version
# rewrote the hub file a third time right before `run`, and the guard never tripped — not because
# the fix was unnecessary, but because the fixture no longer exercised it).
printf 'claude=fresh\n' > "$HUB/tracks/_meta/.substrate_versions"
mkdir -p "$BEX/tracks-meta"
sleep 2
printf 'stale-peer-content\n' > "$BEX/tracks-meta/.substrate_versions"
git -C "$BEX" add tracks-meta/.substrate_versions; git -C "$BEX" commit -q -m seed
[ "$BEX/tracks-meta/.substrate_versions" -nt "$HUB/tracks/_meta/.substrate_versions" ]
chk $? "CONTROL: the companion copy really is newer than the hub's (fixture ordering worked)"
out="$(MID=lanea run 2>&1)"
[ -f "$BEX/tracks-meta/substrate/lanea" ] && [ "$(cat "$BEX/tracks-meta/substrate/lanea")" = "claude=fresh" ]
chk $? "sync completed and re-homed correctly despite a stale, newer pre-fix shared copy (did not abort — pmh-dev#69 A1)"
printf '%s' "$out" | grep -qi 'refuse\|abort\|newer'; [ $? -ne 0 ]
chk $? "no destination-newer abort was printed for the reaped file"

echo "── L4 .close_stamps_<date> never leaves the hub at all (excluded, not machine-scoped — pmh-dev#69 A2) ──"
new_env l4
printf '2026-08-14T00:00:00Z\n' > "$HUB/tracks/_meta/.close_stamps_2026-08-14"
printf 'ordinary\n' > "$HUB/tracks/_meta/normal2.md"
MID=lanea run >/dev/null 2>&1
[ -f "$BEX/tracks-meta/normal2.md" ]; chk $? "CONTROL: an ordinary file synced (run actually executed)"
[ ! -f "$BEX/tracks-meta/.close_stamps_2026-08-14" ]; chk $? "close-stamp file never landed in the companion store at all"

echo ""
echo "════ lanes: $PASS passed · $FAIL failed ════"
[ "$FAIL" -eq 0 ]
