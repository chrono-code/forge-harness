#!/usr/bin/env bash
# test_leak_scan_control_lanes.sh — anchors for the ONE required check's leak scan.
#
# SUBJECT: the "Check for operator-private token residue" step of .github/workflows/validate.yml.
#
# WHY (measured 2026-08-22 — a production fail-open on the only required check of this repo):
# the step was `FOUND=$(grep … || true)` followed by `[ -n "$FOUND" ]`. Three arms, one variable
# changed at a time, run against the extracted step body:
#
#   leak present · instrument healthy      rc=1  FAIL: … residue found          ✅
#   clean tree                             rc=0  PASS: no … residue             ✅
#   leak present · grep exits 2 (broken)   rc=0  PASS: no … residue             🟥
#
# `|| true` folds grep's ERROR (2) into its NO-MATCH (1), so the PASS token is produced on the
# failure branch: a dead scanner renders byte-identically to a clean surface. This is the
# absence-assertion class, and it sat on an IRREVERSIBLE surface (a leak does not un-happen) with
# zero controls of any kind.
#
# The repair copies an instrument this repo already runs — scripts/env_purity_scan.sh's
# "컨트롤 사망 → 수치 무효, exit 10" — rather than inventing a second shape:
#   ① grep's exit code is READ; rc >= 2 is an instrument error, never a clean scan.
#   ② a known-positive control is planted in the scanned tree and MUST be found; zero control hits
#      means the scan never ran over this tree, so its zero findings are void.
#
# These lanes assert both closures AND include revert probes, because the two closures are
# independent fail-closed layers: neutralizing one alone leaves the other catching the same arm.
# The probe that matters is therefore R3 — neutralize BOTH and the original bug returns exactly.
#
# Usage: bash scripts/test_leak_scan_control_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF="$REPO_ROOT/.github/workflows/validate.yml"
T=$(mktemp -d) || { echo "❌ HARNESS-ERROR — mktemp failed"; exit 10; }
trap 'rm -rf "$T"' EXIT
FAIL=0

[ -f "$WF" ] || { echo "❌ HARNESS-ERROR — subject workflow missing: $WF"; exit 2; }

# ── instrument calibration: prove the step body actually extracted ───────────────────────────
# An empty extraction would let every lane "pass" against nothing — the exact class this suite
# exists to close. stdlib only (PyYAML is not a declared dependency and this suite runs inside
# selfcheck.sh, where a missing module would block unrelated commits with an error about the
# wrong thing).
python3 - "$WF" > "$T/body.sh" <<'PYX'
import sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
NAME = "- name: Check for operator-private token residue"
try:
    i = next(k for k, l in enumerate(lines) if l.strip() == NAME)
except StopIteration:
    sys.exit(0)                       # emit nothing -> the calibration check below aborts loudly
j = next(k for k in range(i, len(lines)) if lines[k].strip().startswith("run:"))
indent = len(lines[j + 1]) - len(lines[j + 1].lstrip())
body = []
for l in lines[j + 1:]:
    if l.strip() and (len(l) - len(l.lstrip())) < indent:
        break
    body.append(l[indent:])
sys.stdout.write("\n".join(body) + "\n")
PYX
for _need in 'INSTRUMENT DEAD' 'INSTRUMENT ERROR' 'PASS: no generic operator-private residue'; do
  if ! grep -qF -- "$_need" "$T/body.sh"; then
    echo "❌ HARNESS-ERROR — the leak-scan step body did not extract from $WF"
    echo "   (missing marker: '$_need'). Lanes below would measure an empty script. Aborting"
    echo "   rather than reporting green."
    exit 1
  fi
done

# ── fixtures ─────────────────────────────────────────────────────────────────────────────────
# Home-path literals are ASSEMBLED, never written out: a tracked file carrying the real shape is
# blocked by this repo's own pre-commit confidentiality scan (verified 2026-08-22, reports MED).
mkdir -p "$T/clean/docs" "$T/leaky/docs" "$T/shim"
printf '# nothing operator-private here\n' > "$T/clean/docs/x.md"
printf 'a planted leak for the FAIL arm:\n' > "$T/leaky/docs/x.md"
printf '/Users/%s/projects/secret\n' "plantedhome" >> "$T/leaky/docs/x.md"

# grep shim that breaks ONLY the recursive scan (the `-rIE` invocation). Breaking every grep would
# not attribute the failure to the branch under test.
REAL_GREP=$(command -v grep) || { echo "❌ HARNESS-ERROR — no grep on PATH"; exit 10; }
cat > "$T/shim/grep" <<SH
#!/bin/sh
for a in "\$@"; do case "\$a" in -rIE) exit 2 ;; esac; done
exec "$REAL_GREP" "\$@"
SH
chmod +x "$T/shim/grep"

run_body() { # $1=body file  $2=tree  $3=broken|ok ; echoes "rc|first verdict-ish line"
  local out rc
  if [ "$3" = "broken" ]; then
    out=$(cd "$2" && PATH="$T/shim:$PATH" bash "$1" 2>&1); rc=$?
  else
    out=$(cd "$2" && bash "$1" 2>&1); rc=$?
  fi
  printf '%s|%s' "$rc" "$(printf '%s\n' "$out" | grep -E '^(PASS|FAIL|❌|⛔)' | head -1)"
}
lane() { # $1=id $2=body $3=tree $4=broken|ok $5=expected rc $6=expected substring
  local r rc msg
  r=$(run_body "$2" "$3" "$4"); rc="${r%%|*}"; msg="${r#*|}"
  if [ "$rc" = "$5" ] && printf '%s' "$msg" | grep -qF -- "$6"; then
    printf '  ✅ %-28s rc=%s  %s\n' "$1" "$rc" "$(printf '%s' "$msg" | cut -c1-60)"
  else
    printf '  ❌ %-28s expected rc=%s /%s/, got rc=%s %s\n' "$1" "$5" "$6" "$rc" "$msg"; FAIL=1
  fi
}

echo "== leak-scan lanes (subject: validate.yml operator-private residue step) =="
lane L1-clean-tree      "$T/body.sh" "$T/clean" ok     0  "PASS: no generic operator-private residue"
lane L2-leak-detected   "$T/body.sh" "$T/leaky" ok     1  "FAIL: operator-private token residue found"
lane L3-instrument-dead "$T/body.sh" "$T/leaky" broken 10 "INSTRUMENT ERROR"

# L4 — the control fixture itself is the second anchor: remove its planting and the scan must
# refuse to certify, even though the tree is genuinely clean. "Clean" and "not looked at" must not
# render the same, which is the whole thesis of this file.
sed "s|^ *printf '/Users/%s/projects/example.*|:|" "$T/body.sh" > "$T/body_noctl.sh"
if diff -q "$T/body.sh" "$T/body_noctl.sh" >/dev/null; then
  echo "  ❌ L4-control-removed        neutralization was a no-op — the probe measured nothing"; FAIL=1
else
  lane L4-control-removed "$T/body_noctl.sh" "$T/clean" ok 10 "INSTRUMENT DEAD"
fi

echo "== revert probes — are the two closures load-bearing, or decoration? =="
# R1: disarm the exit-code read alone. The arm stays RED (the control layer catches it), but the
#     ATTRIBUTION must move — that is what proves this branch, not its neighbour, fires first.
sed 's|if \[ "$rc" -ge 2 \]; then|if false; then|' "$T/body.sh" > "$T/body_r1.sh"
if diff -q "$T/body.sh" "$T/body_r1.sh" >/dev/null; then
  echo "  ❌ R1-rc-branch             neutralization was a no-op — the probe measured nothing"; FAIL=1
else
  r=$(run_body "$T/body_r1.sh" "$T/leaky" broken)
  if ! printf '%s' "${r#*|}" | grep -qF 'grep exited'; then
    printf '  ✅ %-28s disarmed → verdict re-attributes to %s\n' "R1-rc-branch" "$(printf '%s' "${r#*|}" | cut -c1-40)"
  else
    echo "  ❌ R1-rc-branch             still reports 'grep exited' with the branch disarmed"; FAIL=1
  fi
fi

# R2: disarm the control-liveness branch alone → L4's arm must go GREEN again, i.e. a scan that
#     cannot find a planted leak once more certifies the surface as clean.
sed 's|if \[ "$ctl" -eq 0 \]; then|if false; then|' "$T/body_noctl.sh" > "$T/body_r2.sh"
if diff -q "$T/body_noctl.sh" "$T/body_r2.sh" >/dev/null; then
  echo "  ❌ R2-control-branch        neutralization was a no-op — the probe measured nothing"; FAIL=1
else
  r=$(run_body "$T/body_r2.sh" "$T/clean" ok)
  if [ "${r%%|*}" = "0" ]; then
    echo "  ✅ R2-control-branch        disarmed → dead-fixture scan passes again → anchor is alive"
  else
    echo "  ❌ R2-control-branch        disarmed branch STILL blocks — the lane is not testing it"; FAIL=1
  fi
fi

# R3: disarm BOTH → the ORIGINAL 2026-08-22 bug must return exactly: a real leak, a dead scanner,
#     and a green PASS. This is the fail-before measurement, mechanized so it cannot drift back.
sed 's|if \[ "$ctl" -eq 0 \]; then|if false; then|' "$T/body_r1.sh" > "$T/body_r3.sh"
r=$(run_body "$T/body_r3.sh" "$T/leaky" broken)
if [ "${r%%|*}" = "0" ] && printf '%s' "${r#*|}" | grep -qF 'PASS: no generic'; then
  echo "  ✅ R3-both-disarmed         both off → leak+dead scanner renders PASS (the closed hole)"
else
  echo "  ❌ R3-both-disarmed         expected rc=0 PASS, got $r — the lanes are not measuring the hole"; FAIL=1
fi

[ $FAIL -eq 0 ] && { echo "✅ all leak-scan control lanes behave"; exit 0; }
echo "❌ leak-scan control lane regression"; exit 1
