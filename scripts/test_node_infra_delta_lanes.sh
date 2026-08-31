#!/usr/bin/env bash
# test_node_infra_delta_lanes.sh — lanes for the INFRA-DELTA branch of scripts/fh_node_check.sh.
#
# WHY A SEPARATE FILE FROM test_node_check_lanes.sh: that suite covers the floor probes (git hooks,
# Mode D companion detection, emission model) and never enters the infra-delta branch — every one of
# its fixtures runs against a state file whose PREV_HEAD is either empty (first session) or equal to
# HEAD. The branch that reacts to `git pull` moving install-relevant files was unexercised, which is
# how the four items below survived. Keeping it separate also keeps the two suites' fixture families
# from colliding: this one must CHANGE HEAD between runs, which breaks the "event once then silent"
# lane in the other file.
#
# CALIBRATION RULE OBSERVED THROUGHOUT: every lane asserting an ABSENCE names its known-positive in
# the lane title and builds it from the SAME fixture family in the SAME run. Exit codes are read
# DIRECTLY off the subject, never through a pipe.
#
# ⓘ GAP lanes pin behaviour believed WRONG without failing the suite; if the behaviour changes they
# announce "GAP CLOSED" so the lane gets promoted instead of silently rotting.
#
# Exit 0 = every asserting lane calibrated · 1 = the instrument is wrong.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # 픽스처는 실레포에 쓰지 않는다
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/fh_node_check.sh"
[ -f "$CHECK" ] || { echo "FAIL  subject missing: $CHECK"; exit 1; }

TMPROOT="$(fh_fixture_root "$(mktemp -d "${TMPDIR:-/tmp}/fh_infra_lanes.XXXXXX")")"
trap 'rm -rf "$TMPROOT"' EXIT
FAILED=0; PASSED=0; GAPS=0

_pass() { echo "✅ $1"; PASSED=$((PASSED+1)); }
_fail() { echo "❌ $1"; FAILED=1; }
_line() {  # $1=name $2=pattern $3=expect(0/1) $4=output
  local hit=0
  printf '%s\n' "$4" | grep -q -- "$2" && hit=1
  if [ "$hit" = "$3" ]; then _pass "$1 (hit=$hit, expected=$3)"
  else _fail "$1 — hit=$hit, expected=$3"; printf '%s\n' "$4" | sed 's/^/       │ /'; fi
}
_rc() { if [ "$2" = "$3" ]; then _pass "$1 (exit=$2, expected=$3)"; else _fail "$1 — exit=$2, expected=$3"; fi; }
_gap() {  # $1=name $2=observed(1=still open) $3=note
  if [ "$2" = "1" ]; then echo "ⓘ GAP (still open) $1"; echo "       ↳ $3"; GAPS=$((GAPS+1))
  else echo "🎉 GAP CLOSED — $1 : behaviour changed, promote this lane to an asserting one"; fi
}

# ── fixtures ────────────────────────────────────────────────────────────────────
# A hub with FH's own gate sentinel in both hooks, so MISS is empty and any output is attributable
# to the infra-delta branch alone (instrument-discrimination: a lane that cannot tell which leg
# fired is not measuring that leg).
_hub() {  # $1=name → echoes path
  local d="$TMPROOT/$1"
  mkdir -p "$d/.git" || true
  git -C "$d" init -q 2>/dev/null || { mkdir -p "$d"; git -C "$d" init -q; }
  git -C "$d" config user.email anchor@local; git -C "$d" config user.name anchor
  mkdir -p "$d/.git/hooks"
  printf '#!/bin/sh\n# FH 4-Axis Gate\nexit 0\n' > "$d/.git/hooks/pre-commit"
  cp "$d/.git/hooks/pre-commit" "$d/.git/hooks/pre-push"
  chmod +x "$d/.git/hooks/pre-commit" "$d/.git/hooks/pre-push"
  echo seed > "$d/seed.txt"
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" -c commit.gpgsign=false commit -qm seed >/dev/null 2>&1
  printf '%s' "$d"
}
_commit() {  # $1=hub $2..=paths to create
  local d="$1" p; shift
  for p in "$@"; do mkdir -p "$d/$(dirname "$p")"; echo changed >> "$d/$p"; done
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" -c commit.gpgsign=false commit -qm change >/dev/null 2>&1
}
_run() {  # $1=hub $2=statefile ; sets OUT/RC (RC read directly, no pipe)
  OUT=$(HUB_DIR="$1" FH_NODE_STATE="$2" FH_MACHINE_ID=lanebox bash "$CHECK" 2>&1); RC=$?
}
# seed the state so PREV_HEAD is the pre-change commit (this is the ONLY way into the branch)
_seed_state() { _run "$1" "$2" >/dev/null 2>&1; }

NEW='🆕 Install-relevant assets changed'
HDR='🖥️  \[node\]'

echo "══ infra delta: fires on an install-relevant change, silent otherwise ══"
H=$(_hub p_pos); _seed_state "$H" "$TMPROOT/st_pos"
_commit "$H" scripts/fh_env_delta_scan.sh
_run "$H" "$TMPROOT/st_pos"
_line "ID-P  install-relevant file changed → 🆕 block fires" "$NEW" 1 "$OUT"
_line "ID-P  → names the changed path"  'scripts/fh_env_delta_scan.sh' 1 "$OUT"
_line "ID-P  → routes to the wizard"    'Re-run /install-wizard'       1 "$OUT"
_rc   "ID-P  detector never gates (exit 0)" "$RC" 0

# CONTROL for ID-P, same fixture family, same run-shape: HEAD advances by exactly one commit, but
# the changed path is outside the install surface. Silence here is only meaningful BECAUSE ID-P
# above spoke on an otherwise identical fixture.
H=$(_hub p_ctl); _seed_state "$H" "$TMPROOT/st_ctl"
_commit "$H" README.md
_run "$H" "$TMPROOT/st_ctl"
_line "ID-C  non-install path changed → no 🆕 block (over-fire ctl for ID-P)" "$NEW" 0 "$OUT"
_rc   "ID-C  → exit 0" "$RC" 0

echo
echo "══ one fixture PER regex alternative (an untested alternative is an untested branch) ══"
# Deliberately one path per alternative: a single fixture touching several at once would let any
# alternative be deleted with the suite staying green — the lane4c lesson from test_node_check_lanes.
i=0
for p in "templates/.git-hooks/pre-push" \
         "templates/settings.SessionStart.snippet.json" \
         "scripts/fh_session_load.sh" \
         "plugins/fh-meta/skills/install-wizard/SKILL.md" \
         "plugins/fh-meta/skills/install-doctor/SKILL.md"; do
  i=$((i+1))
  H=$(_hub "alt$i"); _seed_state "$H" "$TMPROOT/st_alt$i"
  _commit "$H" "$p"
  _run "$H" "$TMPROOT/st_alt$i"
  _line "ID-R$i alternative covered: $p" "$NEW" 1 "$OUT"
done

# NEGATIVE for the regex: install-adjacent-LOOKING paths that the pattern deliberately does not
# cover. Without this leg "the regex matches everything" would also pass ID-R1..5.
H=$(_hub alt_neg); _seed_state "$H" "$TMPROOT/st_altneg"
_commit "$H" "plugins/fh-meta/skills/harvest-loop/SKILL.md"
_run "$H" "$TMPROOT/st_altneg"
_line "ID-Rn non-install skill path → not treated as infra (paired with ID-R4/5)" "$NEW" 0 "$OUT"

echo
echo "══ unreachable PREV_HEAD: UNMEASURED, not silence ══"
H=$(_hub p_unreach); _commit "$H" scripts/fh_env_delta_scan.sh
printf 'lanebox|1700000000|deadbee' > "$TMPROOT/st_unreach"
_run "$H" "$TMPROOT/st_unreach"
_line "ID-U  gc/rebase/shallow → UNMEASURED is stated" 'UNMEASURED'  1 "$OUT"
_line "ID-U  → does NOT claim the 🆕 delta (not found ≠ 0)" "$NEW"   0 "$OUT"
_rc   "ID-U  → exit 0" "$RC" 0

echo
echo "══ co-reporting: a missing floor does not suppress the infra delta ══"
H=$(_hub p_both); _seed_state "$H" "$TMPROOT/st_both"
rm -f "$H/.git/hooks/pre-commit"
_commit "$H" scripts/fh_node_check.sh
_run "$H" "$TMPROOT/st_both"
_line "ID-B  missing floor reported"            'Missing mechanical floor' 1 "$OUT"
_line "ID-B  AND infra delta reported (paired)" "$NEW"                     1 "$OUT"

echo
echo "══ ⓘ GAP lanes — believed-wrong behaviour, pinned not asserted ══"

# GAP 1 — attribution. Every other emission path prints the 🖥️ [node] header; the infra-only and
# UNMEASURED-only paths print 4-space-indented CONTINUATION lines under a header that was never
# printed. This is not cosmetic in situ: SessionStart hooks on one matcher have their outputs
# delivered as separate, unordered, unlabelled blocks (measured in
# scripts/test_sessionstart_multihook_lanes.sh), so an unattributed indented block genuinely cannot
# be traced to the hook that emitted it.
H=$(_hub g_hdr); _seed_state "$H" "$TMPROOT/st_hdr"
_commit "$H" scripts/fh_env_delta_scan.sh
_run "$H" "$TMPROOT/st_hdr"
_g=0
{ printf '%s\n' "$OUT" | grep -q "$NEW"; } && ! printf '%s\n' "$OUT" | grep -q "$HDR" && _g=1
_gap "infra-only emission has NO 🖥️ [node] header" "$_g" \
  "Output is 4-space-indented continuation lines with no parent line. MISS and IDENTITY both print a \
header; the infra and UNMEASURED paths do not, because they hang off an if/elif that both fail."

# GAP 2 — silent truncation. `head -6` with no count. The script's own header argues 'not found ≠ 0'
# and 'distinguish no-change from could-not-measure'; an omitted-3-of-9 list is the same class of
# hidden omission, one layer in.
H=$(_hub g_trunc); _seed_state "$H" "$TMPROOT/st_trunc"
_commit "$H" scripts/fh_a.sh scripts/fh_b.sh scripts/fh_c.sh scripts/fh_d.sh \
             scripts/fh_e.sh scripts/fh_f.sh scripts/fh_g.sh scripts/fh_h.sh scripts/fh_i.sh
_run "$H" "$TMPROOT/st_trunc"
LISTED=$(printf '%s\n' "$OUT" | grep -c '^       - ')
_g=0; { [ "$LISTED" = "6" ] && ! printf '%s\n' "$OUT" | grep -qiE 'more|[0-9]+ of [0-9]+|truncat'; } && _g=1
_gap "9 install-relevant files changed → 6 listed, 3 dropped with no count" "$_g" \
  "listed=$LISTED, and no '…and N more'. A big pull (exactly when re-running the wizard matters most) \
silently hides the tail. Cheap fix: append the residual count."

# GAP 3 — the one-shot consumes an UNRESOLVED unknown. State is written UNCONDITIONALLY to HEAD_NOW,
# including on the run that could not compute the delta. Next session PREV_HEAD == HEAD, so the
# delta across that pull is never attempted again and never mentioned again. The script's header
# says events report once and CONDITIONS report until they stop being true — an un-computed delta is
# an unresolved condition, and it is being treated as a discharged event.
H=$(_hub g_once); _commit "$H" scripts/fh_env_delta_scan.sh
printf 'lanebox|1700000000|deadbee' > "$TMPROOT/st_once"
SPOKE=0
for _i in 1 2 3; do
  _run "$H" "$TMPROOT/st_once"
  printf '%s\n' "$OUT" | grep -q 'UNMEASURED' && SPOKE=$((SPOKE+1))
done
_g=0; [ "$SPOKE" = "1" ] && _g=1
_gap "UNMEASURED spoken once, then permanently forgotten (state advanced anyway)" "$_g" \
  "spoke on $SPOKE of 3 consecutive runs. Same shape as the failure the state-based design was \
introduced to fix ('a broken machine reported once then went quiet forever') — the fix reached MISS \
but not the infra branch. CODE-vs-DOC: fh_node_check.sh's own header claims it distinguishes \
'no change' from 'could not measure', yet after run 1 the two are indistinguishable forever."

# GAP 4 — the event is consumed even when nobody saw it. State advances before/independently of
# whether the emission reached anyone. Pairs directly with the F11 measurement: a SessionStart hook
# whose sibling ordering, delivery, or exit handling drops its output loses the notice permanently.
H=$(_hub g_unseen); _seed_state "$H" "$TMPROOT/st_unseen"
_commit "$H" scripts/fh_env_delta_scan.sh
HUB_DIR="$H" FH_NODE_STATE="$TMPROOT/st_unseen" FH_MACHINE_ID=lanebox bash "$CHECK" >/dev/null 2>&1
_run "$H" "$TMPROOT/st_unseen"
_g=0; printf '%s\n' "$OUT" | grep -q "$NEW" || _g=1
_gap "infra event is consumed by a run whose output nobody received" "$_g" \
  "One discarded-stdout run and the notice is gone for good. The write is deliberately unconditional \
(so the timestamp does not mean 'last time it spoke'), but that argument covers the TIMESTAMP, not \
the HEAD field. Recording HEAD only when the delta was successfully computed AND emitted would keep \
the timestamp honest and stop discharging unseen events."

echo
echo "──────────────────────────────────────────────"
if [ "$FAILED" -ne 0 ]; then
  echo "NODE INFRA-DELTA LANES: FAIL — instrument miscalibrated (do not trust its verdict)"
  echo "  asserting lanes passed: $PASSED · open gaps: $GAPS"
  exit 1
fi
echo "NODE INFRA-DELTA LANES: PASS ($PASSED asserting lanes) · $GAPS KNOWN GAP(S) open (see ⓘ above)"
echo "  Green covers: fires/does-not-fire, per-alternative regex coverage, UNMEASURED, co-reporting."
echo "  Green does NOT cover the four gaps above."
exit 0
