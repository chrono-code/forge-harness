#!/usr/bin/env bash
# test_sidecar_wait_stdin.sh — known-pair anchor for scripts/sidecar_wait.sh's stdin plumbing.
#
# WHY (measured 2026-07-29)
#   `sidecar_wait.sh` shipped in v1.4.76 documenting this invocation in its own header:
#       printf '%s' "$prompt" | bash scripts/sidecar_wait.sh out.txt 600 -- codex exec -m gpt-5.5 -
#   It did not work. `"$@" > "$OUT" 2>&1 &` gives the child /dev/null for stdin in a
#   non-interactive shell, so codex received no prompt, answered "No prompt provided via stdin",
#   and the wrapper reported SIDECAR_VERDICT=COMPLETE — a sidecar that never ran, reported as
#   complete. That is the exact misjudgment the script exists to prevent, produced by the script.
#
#   The FIRST repair was worse than the bug, and adversarial review caught it before it shipped.
#   It spooled stdin to a tempfile; reproduced consequences:
#     - the unbounded `cat` ran BEFORE the child, so an inherited never-EOF stdin hung the wrapper
#       forever and the timeout budget never applied (`-- true` with inherited stdin → rc=124);
#     - it CONSUMED the caller's stdin (a caller reading 3 lines afterwards read 0).
#   The correct fix is one token: `<&0`. POSIX substitutes /dev/null only when stdin is NOT
#   explicitly redirected. Lanes P2/P3 exist because the anchor's first version reported 4/4 green
#   in the same shell where the argv form returned rc=124 — it bound only P1.
#
# Lanes
#   P1  piped stdin REACHES the child                        (the original hole)
#   P2  argv-form with an inherited never-EOF stdin does NOT hang   (spool regression)
#   P3  the caller's own stdin is NOT consumed by the wrapper       (spool regression)
#   P4  verdict codes: TIMEOUT=1 · EMPTY=0 · COMPLETE=0, and EMPTY/COMPLETE are distinguished
#   P5  an unwritable outfile is exit 2, not "EMPTY" (a false clean on the typed channel)
#
# Verdicts are read by running the wrapper DIRECTLY — piping it into `tail` and reading `$?`
# answers with tail's status and turns a real exit 1 green.
#
# Exit 0 = all lanes correct. Exit 1 = the plumbing regressed.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SW="$ROOT/scripts/sidecar_wait.sh"
[ -f "$SW" ] || { echo "FAIL: $SW not found"; exit 1; }
# NOTE: SIDECAR_POLL is set PER LANE, never exported globally. A global export pinned the knob for
# every lane and thereby MASKED a bad default — a regression to `SIDECAR_POLL:-0` passed 5/5.
FAST="SIDECAR_POLL=1"

pass=0; fail=0
ok()  { printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  ❌ %s\n' "$1"; fail=$((fail+1)); }
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT

# P1 — `cat` echoes whatever it receives; an empty outfile means stdin was swallowed, which is
# exactly what the shipped version did.
printf 'MARKER_STDIN_ARRIVED' | SIDECAR_POLL=1 bash "$SW" "$TD/p1.out" 20 -- cat >/dev/null 2>&1
if grep -q 'MARKER_STDIN_ARRIVED' "$TD/p1.out" 2>/dev/null; then
  ok "P1 piped stdin reaches the child process"
else
  bad "P1 STDIN HOLE IS BACK — child saw no stdin (got: '$(head -c 60 "$TD/p1.out" 2>/dev/null)')"
fi

# P2 — the lane the first anchor lacked. A never-EOF stdin must not block the wrapper: the child is
# launched immediately and the budget governs. `sleep 20 |` keeps the pipe open with no data.
( sleep 6 | SIDECAR_POLL=1 timeout 5 bash "$SW" "$TD/p2.out" 3 -- echo ARGV_OK ) >/dev/null 2>&1
rc_hang=$?
if [ "$rc_hang" -ne 124 ] && grep -q 'ARGV_OK' "$TD/p2.out" 2>/dev/null; then
  ok "P2 an inherited never-EOF stdin does not hang the wrapper (child still runs)"
else
  bad "P2 the wrapper HUNG or never ran the child on inherited stdin (rc=$rc_hang, out='$(head -c 40 "$TD/p2.out" 2>/dev/null)')"
fi

# P3 — the wrapper must not eat the caller's stream. `echo` reads nothing, so all three lines must
# remain readable afterwards. The spool version left zero.
n=$(printf 'l1\nl2\nl3\n' | { SIDECAR_POLL=1 bash "$SW" "$TD/p3.out" 20 -- echo x >/dev/null 2>&1
                              c=0; while read -r _; do c=$((c+1)); done; echo "$c"; })
if [ "$n" = "3" ]; then
  ok "P3 the caller's own stdin survives the call (3/3 lines still readable)"
else
  bad "P3 the wrapper consumed the caller's stdin ($n of 3 lines left)"
fi

# P4 — verdict channel. `-- true` writes nothing and is EMPTY, NOT COMPLETE; the first anchor
# labelled that lane "COMPLETE" and so never exercised COMPLETE at all.
SIDECAR_POLL=1 bash "$SW" "$TD/p4t.out" 2 -- sleep 30 >"$TD/p4t.txt" 2>&1 </dev/null; rc_t=$?
SIDECAR_POLL=1 bash "$SW" "$TD/p4e.out" 20 -- true      >"$TD/p4e.txt" 2>&1 </dev/null; rc_e=$?
SIDECAR_POLL=1 bash "$SW" "$TD/p4c.out" 20 -- echo hi   >"$TD/p4c.txt" 2>&1 </dev/null; rc_c=$?
if [ "$rc_t" -eq 1 ] && [ "$rc_e" -eq 0 ] && [ "$rc_c" -eq 0 ] \
   && grep -q 'SIDECAR_VERDICT=TIMEOUT'  "$TD/p4t.txt" \
   && grep -q 'SIDECAR_VERDICT=EMPTY'    "$TD/p4e.txt" \
   && grep -q 'SIDECAR_VERDICT=COMPLETE' "$TD/p4c.txt"; then
  ok "P4 verdicts intact and distinguished (TIMEOUT=1 · EMPTY=0 · COMPLETE=0)"
else
  bad "P4 verdict channel drifted (timeout rc=$rc_t, empty rc=$rc_e, complete rc=$rc_c)"
  head -1 "$TD/p4t.txt" "$TD/p4e.txt" "$TD/p4c.txt" 2>/dev/null | sed 's/^/     /'
fi

# P5 — an outfile that cannot be written made `wc -c` fail, `${size:-0}` read 0, and the wrapper
# announce EMPTY with exit 0. The sidecar had in fact produced output. Same false-clean class as
# the bug this file anchors, on the typed channel itself.
SIDECAR_POLL=1 bash "$SW" "$TD/nodir/x.out" 10 -- echo hi >/dev/null 2>&1 </dev/null
rc_w=$?
if [ "$rc_w" -eq 2 ]; then
  ok "P5 an unwritable outfile fails closed (exit 2), never 'EMPTY'"
else
  bad "P5 an unwritable outfile returned rc=$rc_w — a sidecar that ran reported as saying nothing"
fi

# P6 — the knob added while making this anchor cheap re-opened the unbounded wait. Each bad value
# must still produce a bounded TIMEOUT. Deliberately NOT using $FAST: the point is a bad POLL.
p6=0
for badpoll in 0 0.5 abc 08 09 600; do
  SIDECAR_POLL="$badpoll" timeout 12 bash "$SW" "$TD/p6.out" 2 -- sleep 30 >"$TD/p6.txt" 2>&1
  rc6=$?
  if [ "$rc6" -eq 1 ] && grep -q 'SIDECAR_VERDICT=TIMEOUT' "$TD/p6.txt"; then p6=$((p6+1)); fi
done
if [ "$p6" -eq 6 ]; then
  ok "P6 a malformed SIDECAR_POLL (0·0.5·abc·08·09·600) still times out — the budget is not disarmable"
else
  bad "P6 only $p6/6 malformed poll values produced a bounded TIMEOUT (unbounded wait is reachable)"
fi

# P7 — TIMEOUT must not orphan the sidecar, INCLUDING grandchildren: `kill "$PID"` reached only the
# direct child, so `sh -c 'sleep N & wait'` survived while this lane stayed green. The marker is
# per-run: a machine-global `pgrep -f 'sleep 25'` false-FAILs on any concurrent sleep and its
# failure branch would kill unrelated host processes.
MARK="p7_$$_$(date +%s 2>/dev/null || echo x)"
SIDECAR_POLL=1 bash "$SW" "$TD/p7.out" 2 -- sh -c "sleep 25 & wait # $MARK" >"$TD/p7.txt" 2>&1 </dev/null
sleep 1
if ! pgrep -f "$MARK" >/dev/null 2>&1; then
  ok "P7 a timed-out sidecar is killed with its grandchildren, not orphaned past our exit"
else
  bad "P7 a grandchild survived TIMEOUT (orphan restored)"; pkill -f "$MARK" 2>/dev/null
fi

# P9 — the tty path. HONEST SCOPE, do not read this lane as more than it is.
#
# It asserts that a stdin-reading child under an allocated pty still produces a bounded verdict. It
# does NOT bind the `if [ -t 0 ]` branch: removing that branch entirely leaves this lane GREEN
# (measured 2026-07-29). Cross-family review reproduced a SIGTTIN stop (rc=124, no verdict) under a
# pty before `set -m` was added for the group-kill; this harness cannot reproduce that condition,
# so whether the branch is still load-bearing is UNMEASURED — the branch is kept as defensive, not
# as something this anchor proves.
#
# A lane that cannot separate a known-positive from a known-negative is not measuring; it is
# generating. Shipping it as a plain green would manufacture exactly the false confidence this
# file exists to prevent, so it is labelled instead of silently counted.
if command -v script >/dev/null 2>&1; then
  # `< /dev/null` on `script` itself: with the harness's inherited stdin it could not allocate a pty
  # at all and wrote no rc file, so the lane failed identically with AND without the fix under test
  # — it discriminated nothing. The pty it allocates for the inner command is what matters.
  # The inner shell writes its rc to a FILE. Parsing `script`'s own stdout fails: it emits ^D and
  # CRLF, and the first version of this lane read rc as empty and reported a defect that did not
  # exist — the target was fine, the instrument was not.
  script -q /dev/null bash -c "SIDECAR_POLL=1 timeout 12 bash '$SW' '$TD/p9.out' 3 -- cat >'$TD/p9.txt' 2>&1; echo \$? > '$TD/p9rc'" >/dev/null 2>&1 < /dev/null
  rc9=$(tr -dc '0-9' < "$TD/p9rc" 2>/dev/null)
  if [ -n "$rc9" ] && [ "$rc9" != "124" ] && grep -q 'SIDECAR_VERDICT=' "$TD/p9.txt" 2>/dev/null; then
    ok "P9 the tty path runs and emits a verdict (UNCALIBRATED — see note; does NOT bind the branch)"
  else
    bad "P9 tty case rc='${rc9:-<unread>}' verdict='$(head -1 "$TD/p9.txt" 2>/dev/null)'"
  fi
else
  bad "P9 UNCALIBRATED — \`script\` unavailable, the tty branch cannot be exercised here"
fi

# P8 — the child's stderr AND its exit code must reach the typed channel. Dropping `2>&1` or
# hardcoding rc=0 both passed the earlier anchor: it grepped the verdict WORD and the wrapper's
# own rc, never the child's.
SIDECAR_POLL=1 bash "$SW" "$TD/p8.out" 20 -- sh -c 'echo STDERR_MARK >&2; exit 3' >"$TD/p8.txt" 2>&1 </dev/null
if grep -q 'STDERR_MARK' "$TD/p8.out" 2>/dev/null && grep -q 'exit=3' "$TD/p8.txt"; then
  ok "P8 child stderr is captured and its exit code reaches the verdict line"
else
  bad "P8 stderr or child exit code lost (out='$(head -c 40 "$TD/p8.out" 2>/dev/null)' verdict='$(head -1 "$TD/p8.txt")')"
fi

echo "----"
echo "sidecar_wait stdin anchor: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
