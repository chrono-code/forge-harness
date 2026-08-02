#!/usr/bin/env bash
# test_session_close_lanes.sh — known-pair anchor for session_close_check.sh ② (harvest-loop
# obligation) and ⑤ (card-last invariant).
#
# WHY (2026-07-28): ② used to be an UNSATISFIABLE warning — it fired whenever an FH asset was
# touched today and the script had no way to observe whether harvest-loop ran, so no session could
# ever discharge it. A line that fires on every healthy close is noise, and noise trains the runner
# to skim past the ❌ lines that matter. The repair gave it a mechanical discharge (a harvest-loop
# decision recorded in TODAY's fh_completed file). This file is that repair's regression anchor:
# the fix is only real if the ⚠️ still fires when NOTHING is recorded, and stops firing when it is.
#
# Lanes (each is a decision the gate must get right, not a smoke test):
#   ②-N   FH asset touched today, no harvest-loop line anywhere  → ⚠️  MUST fire
#   ②-P1  same, plus "harvest-loop 실행 완료"                     → ✅  must NOT fire
#   ②-P2  same, plus an explicit SKIP note                        → ✅  must NOT fire
#         (CLAUDE.md ② accepts "harvest-loop (or an explicit skip note)" — a recorded skip is
#          a discharged obligation, not an evaded one)
#   ②-C   no FH asset touched today                               → neither line appears at all
#         (over-firing is a defect in its own right — the whole reason this repair exists)
#   ⑤-N   a close artifact newer than the card                    → ❌ card-last MUST fire (exit 1)
#   ⑤-P   card is the newest artifact                             → ✅ card-last holds
#   ⑤-T   card and artifact share an EXACT mtime                  → ⚠️  tie surfaced as advisory, exit 0
#
# Exit 0 = 8/8 lanes calibrated · exit 1 = the gate's instrument is wrong (do not trust its verdict)
# exit 3 = FIXTURE ERROR — a lane's premise never obtained, so this run's verdicts prove nothing

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/session_close_check.sh"
TODAY=$(date +%Y-%m-%d)
FAILED=0

if [ ! -f "$CHECK" ]; then
  echo "FAIL  session-close lanes: subject $CHECK missing"
  exit 1
fi

# Builds a throwaway repo whose HEAD commit touches (or does not touch) an FH asset path.
_fixture() {  # $1=touch_fh_asset(0/1)  $2=completed-file body (empty = no file)
  local touch_fh="$1" body="$2" T
  T=$(mktemp -d)
  ( cd "$T" \
    && git init -q . \
    && git config user.email anchor@local && git config user.name anchor \
    && if [ "$touch_fh" = 1 ]; then echo x > CLAUDE.md; else echo x > unrelated.txt; fi \
    && git add -A && git commit -qm "fixture" ) >/dev/null 2>&1
  mkdir -p "$T/tracks/_meta"
  [ -n "$body" ] && printf '%s\n' "$body" > "$T/tracks/_meta/fh_completed_${TODAY}.md"
  printf '# card\n' > "$T/tracks/_meta/reference_next_session_starter.md"
  printf '%s' "$T"
}

_lane() {  # $1=name  $2=grep-pattern  $3=expect(0/1)  $4=fixture dir
  local name="$1" pat="$2" expect="$3" T="$4" out hit
  out=$(bash "$CHECK" "$T" 2>/dev/null)
  hit=0
  printf '%s\n' "$out" | grep -q "$pat" && hit=1
  rm -rf "$T"
  if [ "$hit" = "$expect" ]; then
    echo "✅ $name (hit=$hit, expected=$expect)"
  else
    echo "❌ $name — hit=$hit, expected=$expect"
    printf '%s\n' "$out" | sed 's/^/     /'
    FAILED=1
  fi
}

WARN2='⚠️  ② FH assets changed today'
OK2='✅ ② FH assets changed today'

_lane "②-N  no harvest-loop decision recorded → warns" "$WARN2" 1 "$(_fixture 1 '- 항목 하나')"
_lane "②-P1 harvest-loop run recorded → silent"        "$WARN2" 0 "$(_fixture 1 '- harvest-loop 실행 완료')"
_lane "②-P2 explicit skip note → silent"               "$WARN2" 0 "$(_fixture 1 '- harvest-loop: skipped — 3-repo session, deferred')"
_lane "②-P1 run recorded → prints the ✅ form"          "$OK2"   1 "$(_fixture 1 '- harvest-loop 실행 완료')"
_lane "②-C  no FH asset touched → no ② line at all"    ' ② '    0 "$(_fixture 0 '- 항목 하나')"

# ⑤ card-last fixture premise — the two ⑤ lanes are ORDERING lanes: each asserts what the subject
# does when one file is strictly newer than another. Establishing that ordering by writing one file
# after the other is not establishing it — it is hoping for it.
#
# WHY (2026-08-02, measured): ⑤-N flaked in CI — same headSha 41743c0, 36s apart, run 30732624697
# success / 30732642673 failure ("expected exit 1, got 0"), while the same commit passed locally.
# Two consecutive writes land 1.435–2.773ms apart (measured here, macOS/APFS).
#
# MECHANISM — MEASURED 2026-08-02, run 30734832234 (this file's own probe, below):
#     Linux  (ubuntu-latest, CI): 187/200 consecutive write-pairs INDISTINGUISHABLE to find -newer
#     Darwin (APFS, this laptop):   0/200
# The runner's mtime granularity is coarser than the gap between two back-to-back writes, so both
# files receive the same stamp, `find -newer` returns nothing, ⑤ correctly reports no violation, and
# the old lane read that as "the gate is broken". Confirmed with a known-positive control in the same
# run. It was carried as an explicit hypothesis until this number existed — the earlier text said so,
# and the declared source still does (fh_signal_2026-08-02_fh-direct.md §S2).
#
# READ THE NUMBER NARROWLY: the probe measures the TIGHTEST possible gap (two writes in one loop
# iteration). The fixture that actually flaked had a wider gap, so 187/200 establishes that the
# mechanism is real on this runner — NOT that the old lane failed 93.5% of the time. Same SHA
# flipping verdict 36s apart is consistent with that gap sitting near a tick boundary (inference,
# not measurement).
#
# Independent of the mechanism: the lane could not distinguish "no violation detected" from "no
# violation state created", so its verdict was unsafe whatever the cause. The repair below does not
# depend on the mechanism, which is why it shipped before the number arrived.
#
# Two repairs, both required:
#   (a) DETERMINISTIC separation — stamp the older file with an absolute past time via `touch -t`
#       (portable across BSD/GNU) instead of relying on write order inside one clock tick.
#   (b) an IN-RUN PREMISE CONTROL — before trusting either verdict, assert with the same `find -newer`
#       primitive the subject uses (NOT its exact glob/scope — the subject sweeps two filename
#       patterns across the directory, this checks one literal basename; the control validates
#       fixture STATE, not the subject's query) that the ordering actually holds, and print the
#       measured mtimes. An absence measurement without a control is how (a)'s absence went unnoticed
#       for a whole day: "no violation reported" and "no violation state created" are different facts
#       and the old lane could not tell them apart.
#
# A premise that does not obtain is a FIXTURE ERROR and exits **3** — not 1, and deliberately not 2
# (bash returns 2 for a script SYNTAX ERROR; squatting on it would make a rotted anchor announce
# itself as a benign fixture issue and send the reader hunting mtimes instead of reading the parse
# error — the same triage misdirection this file exists to remove). The first draft of this
# repair printed a distinct message and then folded it into the same `FAILED` flag as a real verdict
# mismatch — i.e. it reproduced, one layer up, the exact defect it was fixing: the two states were
# distinguishable in the log and identical at the interface CI actually gates on (the exit code / red
# X). Someone triaging from the run summary would land back in the ambiguity this file exists to
# remove. Caught by an isolated Wave-1 challenger, 2026-08-02.
PAST_STAMP=200001010000.00   # absolute, deterministic, unambiguously before any file written now
PREMISE_FAILED=0

# Human-readable on both platforms: GNU prints a date for %y, BSD's %Fm prints a raw epoch, so the
# BSD branch asks for a formatted date instead — the whole point of this line is eyeballing.
_mtime_h() {
  stat -c %y "$1" 2>/dev/null \
    || stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$1" 2>/dev/null \
    || echo "?"
}

_assert_newer() {  # $1=expected-newer  $2=reference  $3=lane label — returns 1 if premise fails
  local newer="$1" ref="$2" label="$3" hits
  hits=$(find "$(dirname "$newer")" -maxdepth 1 -type f -name "$(basename "$newer")" \
           -newer "$ref" 2>/dev/null | wc -l | tr -d ' ')
  echo "   ↳ premise $label: $(basename "$newer")=$(_mtime_h "$newer")  vs  $(basename "$ref")=$(_mtime_h "$ref")  → newer-hits=$hits"
  if [ "$hits" -ne 1 ]; then
    echo "❌ $label — FIXTURE PREMISE NOT ESTABLISHED: $(basename "$newer") is not newer than $(basename "$ref")"
    echo "     the lane's input state was never created, so its verdict would mean nothing (not a gate defect)"
    PREMISE_FAILED=1
    return 1
  fi
  return 0
}

# MECHANISM MEASUREMENT (diagnostic — always prints, never a verdict, never sets FAILED).
# The repair above makes the lanes deterministic regardless of why the old ones flaked, which is
# correct but leaves the original question open: did ubuntu-latest ever actually hand two
# back-to-back writes the SAME mtime? The repaired lanes cannot answer it — they stamp the files
# explicitly, so they measure the fixture, not the platform. This reproduces the OLD two-write shape
# in a loop and counts how often `find -newer` (the subject's own instrument) sees no separation.
# It costs one loop and settles a hypothesis the code otherwise has to keep labelling UNMEASURED.
# Reading it: ties=0 on the runner where the flake happened refutes the coarse-granularity story and
# the real cause is still open; ties>0 confirms it. Either way the number is the point, not a pass.
#
# The probe carries its own CONTROL, because its failure direction is the confirming one:
# "both find calls returned nothing" is what a TIE looks like — and also what a BROKEN find looks
# like (missing dir, failed mktemp, permission error; stderr is discarded). Without a control, any
# breakage of the instrument would print a large tie count and read as confirmation of the very
# hypothesis it was built to test. So a known-POSITIVE pair (deterministically separated by
# `touch -t`) is measured on the same instrument, before and after the loop. Control failure →
# the count is withheld and the probe reports UNCALIBRATED. A number is never printed without it.
_probe_control() {  # $1=dir — returns 0 iff find -newer can separate a deliberately separated pair
  printf 'x\n' > "$1/ctl_old"; printf 'y\n' > "$1/ctl_new"
  touch -t "$PAST_STAMP" "$1/ctl_old"
  [ "$(find "$1" -maxdepth 1 -name ctl_new -newer "$1/ctl_old" 2>/dev/null | wc -l | tr -d ' ')" = "1" ] \
    && [ "$(find "$1" -maxdepth 1 -name ctl_old -newer "$1/ctl_new" 2>/dev/null | wc -l | tr -d ' ')" = "0" ]
}
_granularity_probe() {
  local reps=200 ties=0 i P a b
  P=$(mktemp -d) || { echo "   ↳ mtime granularity probe: UNCALIBRATED (mktemp -d failed) — no count reported"; return 0; }
  if ! _probe_control "$P"; then
    rm -rf "$P"
    echo "   ↳ mtime granularity probe: UNCALIBRATED (find -newer could not separate a deliberately separated pair) — no count reported"
    return 0
  fi
  for i in $(seq 1 "$reps"); do
    printf 'a\n' > "$P/a"; printf 'b\n' > "$P/b"     # the old shape: two consecutive writes
    a=$(find "$P" -maxdepth 1 -name b -newer "$P/a" 2>/dev/null | wc -l | tr -d ' ')
    b=$(find "$P" -maxdepth 1 -name a -newer "$P/b" 2>/dev/null | wc -l | tr -d ' ')
    [ "$a" = "0" ] && [ "$b" = "0" ] && ties=$((ties + 1))
  done
  if ! _probe_control "$P"; then     # still working at the END — a mid-loop break cannot pass silently
    rm -rf "$P"
    echo "   ↳ mtime granularity probe: UNCALIBRATED (control failed after the loop) — no count reported"
    return 0
  fi
  rm -rf "$P"
  echo "   ↳ mtime granularity probe ($(uname -s), control OK): $ties/$reps consecutive write-pairs were INDISTINGUISHABLE to find -newer"
}
_granularity_probe

T=$(_fixture 1 '- harvest-loop 실행 완료')
CARD_F="$T/tracks/_meta/reference_next_session_starter.md"
ART_F="$T/tracks/_meta/fh_completed_${TODAY}.md"

# ⑤-N: an artifact newer than the card is the bug class the invariant exists to catch.
touch -t "$PAST_STAMP" "$CARD_F"   # push the CARD into the past — separation no longer racy
if _assert_newer "$ART_F" "$CARD_F" "⑤-N"; then
  if bash "$CHECK" "$T" >/dev/null 2>&1; then
    echo "❌ ⑤-N  artifact newer than card → expected exit 1, got 0 (card-last not enforced)"
    FAILED=1
  else
    echo "✅ ⑤-N  artifact newer than card → exit 1 (card-last enforced)"
  fi
fi

# ⑤-P: the negative control. Same premise hazard mirrored — if the two files tie here the lane
# passes for the WRONG reason (a false clean), which is why this direction needs the control too.
touch -t "$PAST_STAMP" "$ART_F"    # now push the ARTIFACT into the past; card becomes newest
touch "$CARD_F"
if _assert_newer "$CARD_F" "$ART_F" "⑤-P"; then
  if bash "$CHECK" "$T" >/dev/null 2>&1; then
    echo "✅ ⑤-P  card newest → exit 0"
  else
    echo "❌ ⑤-P  card newest → expected exit 0, got 1 (over-blocking: trains --no-verify)"
    bash "$CHECK" "$T" 2>&1 | sed 's/^/     /'
    FAILED=1
  fi
fi

# ⑤-T: the tie. This is the state neither ⑤ lane above can produce and neither the old fixture nor
# the new one exercises — card and artifact with the EXACT same mtime, where `-newer` is false in
# both directions and ⑤ therefore reports card-last holds without the ordering ever having been
# established. The subject now surfaces it as an advisory. Two things are asserted, and the second
# matters as much as the first: the tie is REPORTED, and it does NOT block (a close gate that
# blocks on a healthy same-tick write trains the override reflex that disarms it).
touch -r "$CARD_F" "$ART_F"   # copy the card's mtime exactly — the tie, deterministically
if [ -n "$(find "$ART_F" -newer "$CARD_F" 2>/dev/null)" ] || [ -n "$(find "$CARD_F" -newer "$ART_F" 2>/dev/null)" ]; then
  echo "❌ ⑤-T — FIXTURE PREMISE NOT ESTABLISHED: touch -r did not produce an exact mtime tie"
  PREMISE_FAILED=1
else
  echo "   ↳ premise ⑤-T: exact mtime tie established ($(_mtime_h "$CARD_F"))"
  out=$(bash "$CHECK" "$T" 2>/dev/null); rc=$?
  # Assert the EXACT literal the pre-push hook greps ('⚠️  ⑤ tie'), and that BOTH lines carry it —
  # the per-file warning and the summary that says what to do about it. Grepping a looser string
  # here would let an emitter edit keep this lane green while the advisory vanished from, or arrived
  # decapitated at, the production push surface. The anchor must assert what the caller depends on,
  # not merely what the subject happens to print (cross-family finding, 2026-08-02).
  tie_lines=$(printf '%s\n' "$out" | grep -c '⚠️  ⑤ tie')
  if [ "$tie_lines" -ge 2 ]; then
    if [ "$rc" -eq 0 ]; then
      echo "✅ ⑤-T  exact mtime tie → surfaced as advisory, exit 0 (diagnosed, not blocked)"
    else
      echo "❌ ⑤-T  tie surfaced but exit $rc — the probe is blocking; it is advisory by design"
      FAILED=1
    fi
  else
    echo "❌ ⑤-T  exact mtime tie NOT surfaced — ⑤ reports card-last holds on an ordering it never established"
    printf '%s\n' "$out" | sed 's/^/     /'
    FAILED=1
  fi
fi
rm -rf "$T"

# Premise failure is reported FIRST and with its own exit code: it says "this run's verdicts are
# meaningless", which is a different instruction to the reader than "the gate is broken". Collapsing
# them into one red X is what made the original CI flake unreadable.
if [ "$PREMISE_FAILED" -ne 0 ]; then
  echo "SESSION-CLOSE LANES: FIXTURE ERROR — a lane's input state was never created; this run's ⑤ verdicts prove nothing (exit 3 ≠ gate failure)"
  exit 3
fi
if [ "$FAILED" -ne 0 ]; then
  echo "SESSION-CLOSE LANES: FAIL — the gate's instrument is miscalibrated"
  exit 1
fi
echo "SESSION-CLOSE LANES: PASS (8/8)"
exit 0
