#!/usr/bin/env bash
# test_prepush_stdin_integrity.sh — regression anchor for the 2026-07-20 fail-open hole.
#
# HOLE: the session-close block inserted at the TOP of templates/.git-hooks/pre-push starts a
# subprocess. git delivers the pushed ref list on the hook's STDIN, and the ref-reading loop runs
# AFTER that block. A stdin-inheriting subprocess drains the ref list → the loop sees zero refs →
# every DEL_/FORCED_ variable stays empty → the hook takes "nothing destructive → exit 0",
# silently disarming the Destructive-Op gate on a branch-delete / force push.
#
# This test reproduces the mechanism (not just greps for the fix), then asserts the fix is present.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/templates/.git-hooks/pre-push"
FAILED=0
_ok(){ echo "PASS  $1"; }
_no(){ echo "FAIL  $1"; FAILED=1; }

# T1 — the mechanism is real: a stdin-inheriting subprocess eats the ref list.
GOT=$(printf 'r1 a1 r2 b2\n' | { _=$(bash -c 'cat >/dev/null' 2>&1); while read -r a _b _c _d; do echo "$a"; done; })
[ -z "$GOT" ] && _ok "T1 mechanism reproduces (inheriting subprocess drains stdin)" \
              || _no "T1 mechanism did NOT reproduce — test is no longer meaningful, re-derive it"

# T2 — the fix works: redirecting the subprocess from /dev/null preserves the ref list.
GOT=$(printf 'r1 a1 r2 b2\n' | { _=$(bash -c 'cat >/dev/null' 2>&1 </dev/null); while read -r a _b _c _d; do echo "$a"; done; })
[ "$GOT" = "r1" ] && _ok "T2 '< /dev/null' preserves the ref list" \
                  || _no "T2 redirect did not preserve stdin (got: '$GOT')"

# T3 — the shipped hook actually carries the guard on the close-check invocation.
LINE=$(grep -n 'session_close_check\.sh' "$HOOK" | grep -v '^\s*#' | grep '_SC_OUT=' || true)
case "$LINE" in
  *"< /dev/null"*|*"</dev/null"*) _ok "T3 pre-push close-check invocation is stdin-guarded" ;;
  "") _no "T3 could not find the _SC_OUT invocation in $HOOK — hole may have been reintroduced under a new name" ;;
  *)  _no "T3 pre-push close-check invocation LACKS '< /dev/null' → Destructive-Op gate is fail-open: $LINE" ;;
esac

# T4 — STRUCTURAL FIX: ref classification must run BEFORE any helper subprocess.
# (Inverted 2026-07-20: the first draft asserted the opposite, because the block originally sat
#  above the loop. A cross-family audit called that a priority inversion — advisory check above a
#  blocking safety gate — so the block moved below classification and this assertion flipped with it.
#  Match CODE lines only; an earlier draft matched the hook's own explanatory COMMENT and
#  self-inverted. Instrument defect caught by the instrument.)
SC_LN=$(grep -n '_SC_OUT=' "$HOOK" | grep -v ':[[:space:]]*#' | head -1 | cut -d: -f1)
LOOP_LN=$(grep -n 'while read -r local_ref' "$HOOK" | grep -v ':[[:space:]]*#' | head -1 | cut -d: -f1)
if [ -n "$SC_LN" ] && [ -n "$LOOP_LN" ] && [ "$LOOP_LN" -lt "$SC_LN" ]; then
  _ok "T4 ref classification (:$LOOP_LN) precedes the close-check helper (:$SC_LN)"
else
  _no "T4 PRIORITY INVERSION — helper(:${SC_LN:-?}) runs at/before ref classification(:${LOOP_LN:-?}); a stdin-reading helper can disarm the Destructive-Op gate"
fi

# T5 — END-TO-END (the anchor a cross-family audit required): a helper that ACTUALLY reads stdin,
# plus a synthetic DESTRUCTIVE ref, must still BLOCK. This is what T1-T4 cannot prove on their own —
# they test the mechanism and the source layout; this tests the shipped hook's real behavior.
T5_TMP=$(mktemp -d 2>/dev/null || echo "/tmp/fh_t5_$$"); : "${T5_TMP:?fixture root unset — refusing to run git in cwd}" ; mkdir -p "$T5_TMP"
(
  cd "$T5_TMP" || exit 1
  git init -q . 2>/dev/null
  mkdir -p scripts
  # a DELIBERATELY hostile helper: it drains stdin, exactly the failure mode under test
  printf '#!/usr/bin/env bash
cat >/dev/null 2>&1 || true
exit 0
' > scripts/session_close_check.sh
  chmod +x scripts/session_close_check.sh
  cp "$HOOK" ./pre-push-under-test
  # synthetic destructive ref: local sha all-zero => DELETE of refs/heads/victim
  printf 'refs/heads/victim 0000000000000000000000000000000000000000 refs/heads/victim deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
'     | bash ./pre-push-under-test origin https://example.invalid/x.git >/dev/null 2>&1
  echo "$?" > rc.txt
)
T5_RC=$(cat "$T5_TMP/rc.txt" 2>/dev/null || echo "")
rm -rf "$T5_TMP" 2>/dev/null
if [ "$T5_RC" = "0" ]; then
  _no "T5 FAIL-OPEN REPRODUCED — a stdin-draining helper let a synthetic branch DELETE through (hook exited 0)"
elif [ -n "$T5_RC" ]; then
  _ok "T5 stdin-draining helper did NOT disarm the gate (synthetic delete still blocked, exit $T5_RC)"
else
  _no "T5 could not run end-to-end (no exit code captured) — treat as unverified, not as pass"
fi

# ── PR-only policy guard (2026-07-20 operator decision) ──────────────────────────
# KNOWN-PAIR calibration per CLAUDE.md §Instrument Calibration: a known-POSITIVE that must block
# and a known-NEGATIVE that must NOT. A guard that fires on everything is as broken as one that
# never fires — over-blocking trains MAIN_PUSH_OK=1 into muscle memory, which disarms it.
_pp_run() { # _pp_run <refline> [env...]  -> echoes exit code
  local refline="$1"; shift
  local d; d=$(mktemp -d 2>/dev/null || echo "/tmp/fh_pp_$$"); : "${d:?fixture root unset — refusing to run git in cwd}"; mkdir -p "$d/scripts"
  ( cd "$d" && git init -q . 2>/dev/null
    printf '#!/usr/bin/env bash\nexit 0\n' > scripts/session_close_check.sh
    chmod +x scripts/session_close_check.sh
    cp "$HOOK" ./h
    printf '%s\n' "$refline" | env "$@" bash ./h origin https://example.invalid/x.git >/dev/null 2>&1
    echo "$?" > rc )
  cat "$d/rc" 2>/dev/null; rm -rf "$d"
}
_SHA_A=1111111111111111111111111111111111111111
_ZERO=0000000000000000000000000000000000000000
# remote_sha = ZERO (new ref) ISOLATES the PR-only guard from the destructive classifier.
# First draft used two synthetic non-zero SHAs; the hook could not resolve remote_sha, marked the
# ref UNCLASSIFIED and fail-closed — so T7/T8 "failed" on the classifier, not on the guard under
# test. The instrument was measuring itself. (Calibration caught it: the known-NEGATIVE is what
# exposed it — CLAUDE.md §Instrument Calibration.)

# T6 known-POSITIVE: a non-delete push aimed at main MUST block
rc=$(_pp_run "refs/heads/main $_SHA_A refs/heads/main $_ZERO")
[ "$rc" = "1" ] && _ok "T6 direct push to main BLOCKED (known-positive)" \
                || _no "T6 direct push to main was NOT blocked (rc=$rc) — PR-only policy is fail-open"

# T7 known-NEGATIVE: a feature branch must pass untouched (no over-blocking)
rc=$(_pp_run "refs/heads/feat/x $_SHA_A refs/heads/feat/x $_ZERO")
[ "$rc" = "0" ] && _ok "T7 feature-branch push allowed (known-negative, no over-block)" \
                || _no "T7 feature-branch push was blocked (rc=$rc) — guard over-fires; that trains the override"

# T8 the override is honored and stays explicit
rc=$(_pp_run "refs/heads/main $_SHA_A refs/heads/main $_ZERO" MAIN_PUSH_OK=1)
[ "$rc" = "0" ] && _ok "T8 MAIN_PUSH_OK=1 override honored" \
                || _no "T8 override did not work (rc=$rc) — an unusable escape hatch gets --no-verify instead"

echo "── prepush stdin integrity: $([ "$FAILED" -eq 0 ] && echo PASS || echo FAIL) ──"
exit "$FAILED"
