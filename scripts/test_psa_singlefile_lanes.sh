#!/usr/bin/env bash
# test_psa_singlefile_lanes.sh — known-pair lanes for the public-surface scanner's SINGLE-FILE and
# MISUSE paths.
#
# What these lanes exist to hold (all measured 2026-08-12, all found by a control and not by review):
#   L1  `public_surface_scan_files.sh <path>` used to IGNORE the argument and print its normal green,
#       so a caller asking "is THIS file clean?" got a PASS about a file set that never contained it.
#   L3/L4  `psa_scan_tagged` piped from a shell without `cat` died on its first line and returned 0 —
#       a known-positive scanned as 0 hits. "The scanner ran" and "the scanner said clean" are
#       different claims and were indistinguishable.
#   L7  a missing file returned 0 hits, i.e. `not found` rendered as `0`.
#   L9  a display that greps only ❌ renders an ALLOWLISTED token (⚪) as "no match" — that is how an
#       existing operator allowlist decision got misread as an absent pattern.
#
# HERMETIC BY CONSTRUCTION: every lane builds its own pattern/allowlist files under a temp dir. It
# must NOT read `.claude/rules/.public-surface-patterns` (gitignored, operator-private) — a lane that
# depends on an operator-local file is unrunnable on a fresh clone and in CI, and would silently
# degrade to "0 lanes ran" there, which is the same not-measured-is-not-zero shape these lanes guard.
#
# Verdict is the exit code. Never parse a summary line for it.

set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
LIB="$REPO_ROOT/scripts/psa_scan_lib.sh"
PUB="$REPO_ROOT/scripts/public_surface_scan_files.sh"
TMP=$(mktemp -d) || exit 9
trap 'rm -rf "$TMP"' EXIT

# HERMETIC BINDING (cross-family round 1 refuted the original claim of hermeticity): lanes that did
# not set PSA_ALLOWLIST fell through to the library default, which is the operator's GITIGNORED
# allowlist. A lane whose verdict depends on a file that does not exist on a fresh clone is not
# hermetic — it is silently a different test there. Bound once, for every lane.
export PSA_ALLOWLIST="$TMP/allowlist"
# Environment hermeticity (round 2): PUBLIC_SURFACE_OK is an operator override that converts the
# publish scanner's fail-closed exit into a proceed. Inherited from the caller's shell it silently
# flips L2's expected verdict — a lane whose result depends on an ambient env var is measuring the
# environment, not the code.
unset PUBLIC_SURFACE_OK

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ✅ %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  ❌ %s\n' "$1"; }
# check <name> <expected_rc> <actual_rc> [substring_that_must_appear] [output]
check() {
  local name="$1" want="$2" got="$3" need="${4:-}" out="${5:-}"
  if [ "$got" != "$want" ]; then bad "$name — rc want=$want got=$got"; return; fi
  if [ -n "$need" ]; then
    case "$out" in *"$need"*) ;; *) bad "$name — rc ok but output lacks '$need'"; return ;; esac
  fi
  ok "$name"
}

# ── fixtures ────────────────────────────────────────────────────────────────────────────────────
printf 'HIGH\tPSA_LANE_SECRET\nHIGH\tPSA_LANE_ALLOWED\n' > "$TMP/defaults"
printf '# empty operator override is still "present + non-empty" for these lanes\nLOW\tPSA_LANE_LOW\n' > "$TMP/override"
printf 'fixtures/allowed.md\tPSA_LANE_ALLOWED\n' > "$TMP/allowlist"
mkdir -p "$TMP/fixtures"
printf 'harmless line\ncontact PSA_LANE_SECRET here\n' > "$TMP/fixtures/positive.md"
printf 'nothing to see\njust prose\n'                  > "$TMP/fixtures/negative.md"
printf 'this names PSA_LANE_ALLOWED on purpose\n'       > "$TMP/fixtures/allowed.md"

echo "[psa single-file lanes]"

# ── L1/L2 : misuse of the publish scanner fails CLOSED, and the no-arg path is untouched ────────
out=$("$PUB" /nonexistent/definitely_not_a_file_zzz.md 2>&1); rc=$?
check "L1 publish-scanner: positional arg → rc=2 refuse" 2 "$rc" "USAGE ERROR" "$out"

# Control for L1: prove the guard did NOT swallow the normal no-arg path. A deliberately unresolvable
# pattern source makes the no-arg run exit at the instrument check (rc=1) BEFORE `npm pack`, so this
# stays fast and still proves the run got past the argument guard.
# Cross-family round 1: the first version only rejected rc=2, so a scanner that wrongly exited 0 PASS
# on an unresolvable pattern source would still have shown green. A control that cannot fail in the
# direction you care about is not a control. It now demands the specific fail-closed outcome.
out=$(PSA_PATTERNS=/nonexistent/nope "$PUB" 2>&1); rc=$?
check "L2 publish-scanner: no-arg path reaches the instrument check and fails closed" 1 "$rc" "incomplete confidentiality instrument" "$out"

# ── L3/L4 : the liveness self-test separates "ran and found nothing" from "never ran" ────────────
out=$(
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/override" >/dev/null 2>&1
  psa_require_live 2>&1
); rc=$?
check "L3 psa_require_live: healthy shell → alive" 0 "$rc"

# The reproduction: a shell whose PATH has no `cat`. psa_scan_tagged dies on its first line and would
# otherwise return 0 — which is what made a known-positive read as clean.
out=$(/usr/bin/env -i PATH=/nonexistent/bin /bin/bash -c "
  . '$LIB'; psa_load '$TMP/defaults' '$TMP/override' >/dev/null 2>&1
  psa_require_live
" 2>&1); rc=$?
check "L4 psa_require_live: PATH without cat → DEAD, not clean" 1 "$rc" "INSTRUMENT DEAD" "$out"

# ── L5/L6 : ordinary single-file verdicts ───────────────────────────────────────────────────────
out=$(
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/override" >/dev/null 2>&1
  PSA_ALLOWLIST="$TMP/allowlist" psa_scan_file "$TMP/fixtures/positive.md" 2>&1
); rc=$?
check "L5 psa_scan_file: known-positive → rc=1 + reports the token" 1 "$rc" "PSA_LANE_SECRET" "$out"

out=$(
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/override" >/dev/null 2>&1
  PSA_ALLOWLIST="$TMP/allowlist" psa_scan_file "$TMP/fixtures/negative.md" 2>&1
); rc=$?
check "L6 psa_scan_file: known-negative → rc=0" 0 "$rc"

# ── L7/L8 : unmeasured is its own value, never 0 ────────────────────────────────────────────────
out=$(
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/override" >/dev/null 2>&1
  psa_scan_file "$TMP/fixtures/does_not_exist.md" 2>&1
); rc=$?
check "L7 psa_scan_file: missing file → rc=3 NOT SCANNED (not 0)" 3 "$rc" "NOT SCANNED" "$out"

out=$(
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/override" >/dev/null 2>&1
  psa_scan_file 2>&1
); rc=$?
check "L8 psa_scan_file: no argument → rc=3 usage (not 0)" 3 "$rc" "USAGE" "$out"

# ── L9 : allowlisted (⚪) is a THIRD outcome and must remain visible ─────────────────────────────
# This is the regression anchor for the display-collapse: rc is 0 like a clean file, so a caller that
# only inspects rc — or greps only ❌ — cannot tell "an operator decided to permit this token here"
# from "this pattern never matched". The ⚪ line is the only thing that separates them.
out=$(
  cd "$TMP" || exit 9
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/override" >/dev/null 2>&1
  PSA_ALLOWLIST="$TMP/allowlist" psa_scan_file "fixtures/allowed.md" 2>&1
); rc=$?
check "L9 psa_scan_file: allowlisted token → rc=0 AND an explicit ⚪ line" 0 "$rc" "⚪ allowlisted" "$out"

# L9b asserts the ABSENCE of a ❌ — and an absence assertion passes for free when nothing ran at all.
# Caught by the revert probe on 2026-08-12: against the pre-fix tree `psa_scan_file` did not exist,
# the output was a shell "command not found", there was no ❌ in it, and L9b went green. A lane that
# is green because the subject never executed is decorative — the same `not found ≠ 0` shape these
# lanes were written to hold, reproduced inside the lane file. So the absence claim is gated on
# positive evidence that the scan actually produced its allowlist verdict.
case "$out" in
  *"⚪ allowlisted"*)
    case "$out" in
      *"❌"*) bad "L9b allowlisted token must not also report ❌" ;;
      *)      ok  "L9b allowlisted token reports no ❌ (and the ⚪ verdict proves the scan ran)" ;;
    esac ;;
  *) bad "L9b UNMEASURED — no ⚪ verdict in the output, so 'no ❌' proves nothing" ;;
esac

# ── L10 : patterns not loaded is NOT clean ──────────────────────────────────────────────────────
# Reproduced from this repo's own advertised usage line, which omitted psa_load. An empty pattern
# stream matches nothing and reports nothing — identical output to a clean file.
out=$(
  . "$LIB"
  psa_scan_file "$TMP/fixtures/positive.md" 2>&1
); rc=$?
check "L10 psa_scan_file: patterns never loaded → rc=3 NOT SCANNED (not clean)" 3 "$rc" "PATTERNS NOT LOADED" "$out"

# ── L11 : liveness covers the FILE path, not just stdin (missing awk) ────────────────────────────
# The tagging step needs awk; the first liveness draft only exercised the stdin path, so "alive"
# certified a pipeline the file scan does not use.
mkdir -p "$TMP/bin"
for b in cat grep mktemp rm printf sed; do
  src=$(command -v "$b" 2>/dev/null) && ln -sf "$src" "$TMP/bin/$b" 2>/dev/null
done
out=$(/usr/bin/env -i PATH="$TMP/bin" /bin/bash -c "
  . '$LIB'
  PSA_STREAM=\$(printf 'HIGH\tPSA_LANE_SECRET')
  PSA_ALLOWLIST=/dev/null
  psa_require_live
" 2>&1); rc=$?
check "L11 psa_require_live: PATH without awk → DEAD (file path is covered)" 1 "$rc" "INSTRUMENT DEAD" "$out"

# ── L12 : errexit safety — the library must not kill its caller ─────────────────────────────────
# The library's documented contract is that it REPORTS state and never exits. Capturing a nonzero
# status outside an `if` broke that under `set -e`.
out=$(bash -c "
  . '$LIB'; psa_load '$TMP/defaults' '$TMP/override' >/dev/null 2>&1
  set -e
  psa_require_live
  echo SURVIVED
" 2>&1); rc=$?
check "L12 psa_require_live: safe under set -e (caller survives)" 0 "$rc" "SURVIVED" "$out"

# ── L13 : a NON-EMPTY pattern stream is not a COMPLETE one ──────────────────────────────────────
printf 'HIGH\tPSA_ONLY_IN_DEFAULTS\n' > "$TMP/defaults2"
printf 'default-only token PSA_ONLY_IN_DEFAULTS here\n' > "$TMP/fixtures/partial.md"
out=$(
  . "$LIB"; psa_load "$TMP/missing_defaults_file" "$TMP/override" >/dev/null 2>&1
  psa_scan_file "$TMP/fixtures/partial.md" 2>&1
); rc=$?
check "L13 psa_scan_file: defaults failed to load → rc=3 (partial instrument is not clean)" 3 "$rc" "INCOMPLETE PATTERN INSTRUMENT" "$out"

# ── L14 : missing operator override is NOT a clean ───────────────────────────────────────────────
# Flipped in round 4. It used to warn and return 0; the override is where the HIGH company/companion
# literals live, so without it the highest-severity class was never looked at. "Warned but clean" is
# the false-clean shape with a comment attached.
out=$(
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/missing_override_file" >/dev/null 2>&1
  psa_scan_file "$TMP/fixtures/negative.md" 2>&1
); rc=$?
check "L14 psa_scan_file: override absent → rc=3 (HIGH literals unscanned is not clean)" 3 "$rc" "override_absent" "$out"

# ── L15 : a GARBAGE guard value must not walk past the guard ────────────────────────────────────
# Round 3: `[ "$PSA_DEFAULTS_OK" -ne 1 ]` with a non-numeric value returns 2, the `if` reads that as
# false, and the guard falls through — measured rc=0 CLEAN on a file whose token was not even in the
# loaded stream. The shell printed "integer expression expected" and nothing consumed it.
out=$(
  . "$LIB"
  PSA_STREAM=$(printf 'HIGH\tSOMETHING_ELSE'); PSA_DEFAULTS_OK=x; PSA_BAD_ROWS=0; PSA_OVERRIDE_PRESENT=1
  psa_scan_file "$TMP/fixtures/positive.md" 2>&1
); rc=$?
check "L15 psa_scan_file: garbage PSA_DEFAULTS_OK → rc=3 (guard is not walked past)" 3 "$rc" "INCOMPLETE PATTERN INSTRUMENT" "$out"

# ── L16 : an incomplete instrument still REPORTS what it saw ─────────────────────────────────────
# Round 3 caught the round-2 fix suppressing real hits: the guard returned 3 and emitted nothing, so a
# token the loaded patterns DID match was lost. "I cannot certify this" must not become "I saw nothing".
out=$(
  . "$LIB"
  PSA_STREAM=$(printf 'HIGH\tPSA_LANE_SECRET'); PSA_DEFAULTS_OK=0; PSA_BAD_ROWS=0; PSA_OVERRIDE_PRESENT=1
  psa_scan_file "$TMP/fixtures/positive.md" 2>&1
); rc=$?
check "L16 incomplete instrument still reports the hit it saw (verdict 3, evidence kept)" 3 "$rc" "PSA_LANE_SECRET" "$out"

# ── L17 : readonly caller vars → DEAD, not a corrupted abort ─────────────────────────────────────
# Round 4 refuted the round-3 `|| :`: bash aborts on assignment to a readonly variable before `||` is
# considered. The function now refuses BEFORE mutating anything.
# Scope note, stated because the round-3 claim over-reached: under `set -e` a bare call to a function
# that RETURNS nonzero still exits the caller — that is correct shell semantics, not a defect. What is
# fixed is dying mid-mutation with the caller's state half-swapped and no diagnostic. So the lane
# checks the guarded call, which is how a `set -e` caller is supposed to invoke a fallible function.
out=$(bash -c "
  . '$LIB'
  PSA_STREAM=x; readonly PSA_STREAM
  set -e
  if psa_require_live; then echo UNEXPECTED_ALIVE; else echo REFUSED_CLEANLY; fi
  echo SURVIVED
" 2>&1); rc=$?
check "L17 readonly PSA_STREAM → refuses without mutating; guarded set -e caller survives" 0 "$rc" "SURVIVED" "$out"
case "$out" in *"INSTRUMENT DEAD"*) ok "L17b the refusal is diagnosed, not silent" ;; *) bad "L17b refusal produced no INSTRUMENT DEAD line" ;; esac

# ── L18/L19/L21 : the assign guard, in BOTH directions + the ATTRIBUTE case ─────────────────────────────────────────────
# L17's fixture used `PSA_STREAM=x; readonly PSA_STREAM` — the one spelling the round-4 glob happened
# to handle. Round 5 found the other: `readonly PSA_STREAM` with no value prints `declare -r PSA_STREAM`
# (no `=`), the glob missed it, and the caller died with a bare "readonly variable". A control that
# only exercises the passing spelling measures the fixture, not the guard.
out=$(bash -c "
  . '$LIB'
  readonly PSA_STREAM
  set -e
  if psa_require_live >/dev/null 2>&1; then echo ALIVE; else echo REFUSED; fi
  echo SURVIVED
" 2>&1); rc=$?
check "L18 VALUELESS readonly is detected too (guard tests the property, not the declaration)" 0 "$rc" "REFUSED" "$out"
case "$out" in *SURVIVED*) ok "L18b caller survives the valueless case" ;; *) bad "L18b caller died on valueless readonly" ;; esac

# The other direction: the round-4 glob also matched an unrelated readonly variable whose VALUE
# contained the string. Over-blocking here would make every such shell report a healthy scanner dead.
out=$(bash -c "
  . '$LIB'; psa_load '$TMP/defaults' '$TMP/override' >/dev/null 2>&1
  readonly PSA_UNRELATED='PSA_STREAM=junk PSA_ALLOWLIST=junk'
  if psa_require_live >/dev/null 2>&1; then echo ALIVE; else echo REFUSED; fi
" 2>&1); rc=$?
check "L19 unrelated readonly whose VALUE names the vars → no false positive" 0 "$rc" "ALIVE" "$out"

# ── L20 : the readonly helper is not a shell-injection surface ──────────────────────────────────
# Round 6. Reachable only via a non-literal argument, which no current call site passes — but the
# function is in the instrument that decides what may be published, and the guard is one line.
rm -f "$TMP/pwned"
out=$(bash -c ". '$LIB'; _psa_can_assign 'X; touch $TMP/pwned; #' v; echo rc=\$?" 2>&1); rc=$?
if [ -f "$TMP/pwned" ]; then bad "L20 eval injection — the payload executed"
else ok "L20 non-identifier argument is refused before eval (no injection)"; fi
case "$out" in *"refusing non-identifier"*) ok "L20b the refusal is diagnosed" ;; *) bad "L20b refusal was silent" ;; esac

# ── L21 : an ATTRIBUTE that rejects the value, not just readonly ─────────────────────────────────
# Round 7. The R5 probe assigned the variable's OWN CURRENT VALUE while the caller then assigns
# something else. Measured: `declare -i PSA_ALLOWLIST` → self-assignment succeeds, `=/dev/null` fails.
# The probe said writable, the real assignment killed the caller, and on the psa_scan_file path a hit
# psa_scan_tagged WOULD have reported went with it. The probe now takes the value it will assign.
out=$(bash -c "
  . '$LIB'
  declare -i PSA_ALLOWLIST
  set -e
  if psa_require_live >/dev/null 2>&1; then echo ALIVE; else echo REFUSED; fi
  echo SURVIVED
" 2>&1); rc=$?
check "L21 declare -i (attribute rejects the value) → REFUSED, caller survives" 0 "$rc" "REFUSED" "$out"
case "$out" in *SURVIVED*) ok "L21b caller survives the attribute case" ;; *) bad "L21b caller died on the attribute case" ;; esac

echo "[psa single-file lanes] pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
[ "$pass" -ge 26 ] || { echo "  ❌ INSTRUMENT ERROR — only $pass lanes ran; expected >=26"; exit 3; }
exit 0
