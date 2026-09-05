#!/usr/bin/env bash
# test_fh_qp_lanes.sh — known-pair lanes for plugins/fh-qp (QP · Quality Platform).
#
# What it proves: the MECHANICAL half (plugins/fh-qp/scripts/qp_tools.sh) discriminates on fixtures
# shipped with the plugin — three negatives from the chamber oracle (profile-required target → refuse ·
# adapter absent → HARNESS_ERROR · dirty evidence → masked, residue 0), surface_reach four states,
# the verdict-record contract (mtm-check), the state-changing-verb floor, and a residency scan of the
# whole scaffold (fail-closed when the scanner cannot run — exit 10 is never read as clean).
# What it does NOT prove: that a session FOLLOWS the SKILL prose (that is the floor-tier sim's job),
# or that any verdict label is TRUE (judgment, deliberately unmechanised).
# Exit: 0 all lanes pass · 1 any lane fails · 10 harness error (plugin/tool missing).
set -uo pipefail
FH="$(cd "$(dirname "$0")/.." && pwd)"
T="$FH/plugins/fh-qp/scripts/qp_tools.sh"
X="$FH/plugins/fh-qp/fixtures"
[ -f "$T" ] || { echo "HARNESS-ERROR: $T missing"; exit 10; }
[ -d "$X" ] || { echo "HARNESS-ERROR: fixtures dir missing"; exit 10; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/fhqp.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
lane() { # $1 name · $2 expected rc · $3 expected stdout regex · rest = command
  local name="$1" want_rc="$2" want_re="$3"; shift 3
  local out rc; out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" = "$want_rc" ] && printf '%s' "$out" | /usr/bin/grep -qE "$want_re"; then
    PASS=$((PASS+1)); printf '  ✅ %-34s rc=%s  %s\n' "$name" "$rc" "$(printf '%s' "$out" | head -1 | cut -c1-70)"
  else
    FAIL=$((FAIL+1)); printf '  ❌ %-34s rc=%s (want %s /%s/)\n     %s\n' "$name" "$rc" "$want_rc" "$want_re" "$out"
  fi
}
echo "── fh-qp lanes ──"
# ── negative ① profile-required → refuse (and the positive pair: public passes, profile unlocks) ──
lane N1-private-host-refused      4  '^PROFILE_REQUIRED kind=web'          bash "$T" target-class https://private.example.internal/x
lane N1-rfc1918-refused           4  '^PROFILE_REQUIRED'                   bash "$T" target-class http://10.1.2.3/login
lane N1-desktop-needs-profile     4  '^PROFILE_REQUIRED kind=desktop'      bash "$T" target-class app:SomeApp
lane N1-public-passes             0  '^PUBLIC kind=web host=example\.com'  bash "$T" target-class https://example.com/
printf 'targets:\n  web:\n    - base_url: https://private.example.internal\n' > "$TMP/profile.yaml"
lane N1-profile-unlocks           0  '^PROFILE_OK'                         bash "$T" target-class https://private.example.internal/x --profile "$TMP/profile.yaml"
lane N1-bad-form-unknown         10  '^UNKNOWN'                            bash "$T" target-class ftp://x
# ── negative ② adapter absent → HARNESS_ERROR (pair: present → ADAPTER=) ──
lane N2-no-tools-harness-error   10  '^HARNESS_ERROR reason=tool-list-not-supplied' bash "$T" adapter-probe --need web
lane N2-wrong-kind-harness-error 10  '^HARNESS_ERROR reason=no-desktop-adapter'     bash "$T" adapter-probe --need desktop --tools "mcp__playwright__browser_navigate,Read"
lane N2-web-adapter-found         0  '^ADAPTER=playwright-mcp evidence=dom'         bash "$T" adapter-probe --need web --tools "Read,mcp__playwright__browser_navigate"
lane N2-desktop-adapter-found     0  '^ADAPTER=computer-use-mcp evidence=pixel'     bash "$T" adapter-probe --need desktop --tools "mcp__computer-use__screenshot"
# ── negative ③ dirty evidence → masked, residue 0 (pair: clean stays clean; raw never survives) ──
lane N3-dirty-masked              0  '^MASKED residue=0'                   bash "$T" mask "$X/evidence_known_dirty.txt" "$TMP/masked.txt"
if /usr/bin/grep -qE 'qa\.tester@|hunter2|eyJhbGci|abcdefghijklmnop' "$TMP/masked.txt"; then FAIL=$((FAIL+1)); echo "  ❌ N3-raw-survived-in-output"; else PASS=$((PASS+1)); echo "  ✅ N3-raw-absent-in-output"; fi
lane N3-clean-stays-clean         0  '^MASKED residue=0'                   bash "$T" mask "$X/evidence_known_clean.txt" "$TMP/masked2.txt"
lane N3-missing-input-harness    10  '^HARNESS_ERROR'                      bash "$T" mask "$X/does_not_exist.txt" "$TMP/m3.txt"
# ── surface_reach four states ──
lane SR-reached                   0  '^REACHED tcs_beyond_entry=2 tcs_total=2'      bash "$T" surface-reach "$X/reach_known_reached.tsv"
lane SR-partial                   5  '^PARTIAL tcs_beyond_entry=1 tcs_total=2'      bash "$T" surface-reach "$X/reach_known_partial.tsv"
lane SR-wall                      5  '^NOT_REACHED tcs_beyond_entry=0 tcs_total=3'  bash "$T" surface-reach "$X/reach_known_wall.tsv"
: > "$TMP/reach_empty.tsv"   # generated here — an empty file cannot travel in a diff (PATCH.diff dropped it; measured 2026-09-05)
lane SR-empty-unmeasured         10  '^UNMEASURED reason=evidence-empty'           bash "$T" surface-reach "$TMP/reach_empty.tsv"
lane SR-missing-unmeasured       10  '^UNMEASURED reason=evidence-missing'         bash "$T" surface-reach "$X/no_such_file.tsv"
# ── verdict record contract ──
lane MTM-good                     0  '^OK mtm=UNAVAILABLE rows=3 machine_closed=2 judgment_left=1' bash "$T" mtm-check "$X/verdicts_known_good.tsv"
lane MTM-branch-needs-active     10  'DIFFERS_FROM_PLAN-needs-mtm-ACTIVE'                        bash "$T" mtm-check "$X/verdicts_known_bad_branch.tsv"
lane MTM-vacuous-machine         10  'MACHINE-closure-without-assertion'                         bash "$T" mtm-check "$X/verdicts_known_bad_vacuous_machine.tsv"
printf '#mtm: ACTIVE\nTC-1\tFAIL\tDIFFERS_FROM_PLAN\tMACHINE\tverify\ttext-visible:x\tINVENTORY\n' > "$TMP/v_src.tsv"
lane MTM-branch-source-binding   10  'DIFFERS_FROM_PLAN-needs-expected_source=PLAN_DOC'          bash "$T" mtm-check "$TMP/v_src.tsv"
printf 'TC-1\tPASS\tAS_PLANNED\tMACHINE\tclick\tx\tINVENTORY\n' > "$TMP/v_nomtm.tsv"
lane MTM-state-line-required     10  'mtm-state-missing'                                         bash "$T" mtm-check "$TMP/v_nomtm.tsv"
lane VERBS-good                   0  '^OK state_changing_verbs=2'          bash "$T" run-verbs "$X/verdicts_known_good.tsv"
lane VERBS-verify-only            5  '^VERIFY_ONLY'                        bash "$T" run-verbs "$X/verdicts_verify_only.tsv"
# ── screen-id: same content with different ref tokens → same id; different content → different id ──
printf -- '- heading "Home" [level=1] [ref=e2]\n- link "About" [ref=e7]\n' > "$TMP/s1.md"
printf -- '- heading "Home" [level=1] [ref=f3e2]\n- link "About"   [ref=f3e7]\n' > "$TMP/s2.md"
printf -- '- heading "About" [level=1] [ref=e2]\n' > "$TMP/s3.md"
id1=$(bash "$T" screen-id "$TMP/s1.md"); id2=$(bash "$T" screen-id "$TMP/s2.md"); id3=$(bash "$T" screen-id "$TMP/s3.md")
if [ "$id1" = "$id2" ] && [ "$id1" != "$id3" ] && [ ${#id1} -eq 12 ]; then PASS=$((PASS+1)); echo "  ✅ SID-content-hash-stable-across-refs ($id1)"; else FAIL=$((FAIL+1)); echo "  ❌ SID-content-hash ($id1 / $id2 / $id3)"; fi
# ── residency: the whole scaffold, fail-closed ──
FILES="$(cd "$FH" && find plugins/fh-qp scripts/test_fh_qp_lanes.sh -type f | sort)"
# Worktrees do not carry the gitignored operator pattern file — fall back to the main checkout's copy
# (git-common-dir), else honour RESIDENCY_PATTERNS, else the scanner exits 10 and this lane FAILS (fail-closed).
if [ -z "${RESIDENCY_PATTERNS:-}" ] && [ ! -f "$FH/.claude/rules/.residency-patterns" ]; then
  _common="$(cd "$FH" && git rev-parse --git-common-dir 2>/dev/null)"
  [ -n "$_common" ] && [ -f "$_common/../.claude/rules/.residency-patterns" ] && export RESIDENCY_PATTERNS="$(cd "$_common/.." && pwd)/.claude/rules/.residency-patterns"
fi
if [ -f "$FH/scripts/residency_closure_scan.py" ]; then
  # shellcheck disable=SC2086
  out="$(cd "$FH" && python3 scripts/residency_closure_scan.py --files $FILES 2>&1)"; rc=$?
  case "$rc" in
    0)  PASS=$((PASS+1)); echo "  ✅ RES-closure-scan CLEAN ($(printf '%s' "$FILES" | wc -l | tr -d ' ') files)" ;;
    10) FAIL=$((FAIL+1)); echo "  ❌ RES-closure-scan HARNESS (rc=10 — patterns file missing; NOT clean)"; echo "$out" | tail -3 ;;
    *)  FAIL=$((FAIL+1)); echo "  ❌ RES-closure-scan TAINTED (rc=$rc)"; echo "$out" | tail -5 ;;
  esac
else
  FAIL=$((FAIL+1)); echo "  ❌ RES-closure-scan scanner missing (fail-closed)"
fi
# generic zero-constant grep (no scanner needed): private hosts / secrets shapes must not appear in shipped files
# except inside the profile EXAMPLE and fixtures, which exist to show the shapes.
# The lane itself is the instrument (its known-negative literals are the point) — scanned by residency above, excluded here.
SHIPPED="$(printf '%s' "$FILES" | /usr/bin/grep -vE 'fixtures/|qp_profile\.example\.yaml|test_fh_qp_lanes\.sh')"
# shellcheck disable=SC2086
hits="$(cd "$FH" && /usr/bin/grep -nE '\b(10|192\.168)\.[0-9]+\.[0-9]+\.[0-9]+\b|eyJ[A-Za-z0-9_-]{8,}\.|AKIA[A-Z0-9]{8,}' $SHIPPED 2>/dev/null | /usr/bin/grep -vE 'qp_tools\.sh:.*(_MASK_|case|10\.\*)' || true)"
if [ -z "$hits" ]; then PASS=$((PASS+1)); echo "  ✅ RES-zero-constant-grep (0 hits in shipped files)"; else FAIL=$((FAIL+1)); echo "  ❌ RES-zero-constant-grep"; echo "$hits"; fi
echo "── fh-qp lanes: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ]
