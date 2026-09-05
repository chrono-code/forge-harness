#!/usr/bin/env bash
# test_action_yml_lanes.sh — behavioural lanes for action.yml's exit-code mapping.
#
# WHY: `action.yml` is the only place where the gate's SEVEN typed exit codes get turned into a
# GitHub step outcome. That translation is exactly where a typed verdict silently becomes a
# boolean — the failure this repo names in `[[feedback_not_found_is_not_zero_family]]`. Two
# properties carry the weight and neither is visible by reading the YAML:
#   A. an UNKNOWN exit code (a future gate version adding one) must land on HARNESS_ERROR-class
#      handling, never on PASS. A `case` whose `*)` arm is missing would default to... nothing,
#      and `verdict` would be unset — which under `set -u` is a crash, but under a careless edit
#      could become an empty string that matches no fail-on entry and exits 0. That is the leak.
#   B. `reviewed` must be false for every code where no review ran (10 · 11 · 12 · unknown).
#      «did not run» reported as «passed» is the same defect class as a skipped check scored green.
#
# HOW: the mapping is extracted from action.yml and executed as shell — the lanes run the REAL
# case block, not a copy. A copy would drift and every lane would stay green while the shipped
# file rotted (that is `[[feedback_built_but_not_wired]]` wearing a test's clothes).
#
# USAGE: bash scripts/test_action_yml_lanes.sh   → exit 0 all pass · 1 any fail · 10 harness error
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
A="$ROOT/action.yml"
[ -f "$A" ] || { echo "❌ HARNESS: action.yml absent at $A"; exit 10; }
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s\n' "$1"; }
chk(){ if [ "$1" = "0" ]; then ok "$2"; else no "$2"; fi; }

# ── extract the real case block from the shipped file ────────────────────────────────────────
MAP="$(awk '/^ *case "\$rc" in/{f=1} f{print} /^ *esac/{if(f){exit}}' "$A" | sed 's/^ *//')"
[ -n "$MAP" ] || { echo "❌ HARNESS: could not extract the case block from action.yml"; exit 10; }
printf '%s' "$MAP" | grep -q 'esac' || { echo "❌ HARNESS: extracted block has no esac (truncated)"; exit 10; }

verdict_for(){ # $1 = rc → prints "verdict reviewed"
  rc="$1"; verdict=""; reviewed=""
  eval "$MAP"
  printf '%s %s' "${verdict:-<UNSET>}" "${reviewed:-<UNSET>}"
}

echo "── L1 documented exit codes map to their documented verdict ──"
while read -r rc want_v want_r; do
  got="$(verdict_for "$rc")"
  [ "$got" = "$want_v $want_r" ]; chk $? "rc=$rc → $want_v (reviewed=$want_r) [got: $got]"
done <<'CASES'
0 PASS true
1 PENDING true
2 BLOCKED true
3 ESCALATE true
10 HARNESS_ERROR false
11 ARG_ERROR false
12 DRY_RUN false
CASES

echo "── L2 KNOWN-NEGATIVE: an undocumented exit code is never PASS and never reviewed=true ──"
for rc in 4 5 9 13 42 127 255; do
  got="$(verdict_for "$rc")"; v="${got%% *}"; r="${got##* }"
  { [ "$v" != "PASS" ] && [ "$v" != "PENDING" ] && [ "$v" != "<UNSET>" ] && [ "$r" = "false" ]; }
  chk $? "rc=$rc → $v (reviewed=$r) — not a pass, not unset"
done

echo "── L3 the mapping is TOTAL: no rc leaves verdict unset (the silent-green hole) ──"
_unset=0
for rc in $(seq 0 20) 42 100 127 255; do
  got="$(verdict_for "$rc")"; case "$got" in "<UNSET>"*) _unset=$((_unset+1)) ;; esac
done
[ "$_unset" -eq 0 ]; chk $? "0 of 28 sampled codes leave verdict unset (found $_unset)"

echo "── L4 CONTROL: a mutated mapping without the catch-all IS caught (the lane can fail) ──"
_MUT="$(printf '%s' "$MAP" | grep -v '^\*)')"
verdict_mut(){ rc="$1"; verdict=""; reviewed=""; eval "$_MUT"; printf '%s' "${verdict:-<UNSET>}"; }
[ "$(verdict_mut 42)" = "<UNSET>" ]; chk $? "catch-all removed → rc=42 leaves verdict unset (control is alive)"
[ "$(verdict_mut 0)" = "PASS" ]; chk $? "…and the mutant still maps documented codes (mutation is surgical)"

echo "── L5 action.yml's documented codes match scripts/fh-gate.sh's exit contract ──"
G="$ROOT/scripts/fh-gate.sh"
if [ -f "$G" ]; then
  _gate_codes="$(grep -oE '^#   [0-9]+ +—' "$G" | grep -oE '[0-9]+' | sort -un | tr '\n' ' ')"
  _act_codes="$(printf '%s' "$MAP" | grep -oE '^[0-9]+\)' | grep -oE '[0-9]+' | sort -un | tr '\n' ' ')"
  [ -n "$_gate_codes" ]; chk $? "CONTROL: the gate's exit contract was actually parsed (got: $_gate_codes)"
  [ "$_gate_codes" = "$_act_codes" ]; chk $? "every documented gate code has an action arm [gate: $_gate_codes | action: $_act_codes]"
else
  echo "  ⬜ L5 SKIPPED (not PASS) — scripts/fh-gate.sh absent, contract un-cross-checked"
fi

echo "── L6 fail-on default is fail-closed: every non-reviewed verdict is in it ──"
_failon="$(grep -A3 "^  fail-on:" "$A" | grep "default:" | sed "s/.*default: *'//; s/'.*//")"
[ -n "$_failon" ]; chk $? "CONTROL: fail-on default parsed (got: $_failon)"
for v in BLOCKED ESCALATE HARNESS_ERROR ARG_ERROR DRY_RUN UNKNOWN; do
  case ",$_failon," in *",$v,"*) ok "fail-on default contains $v" ;; *) no "fail-on default is MISSING $v — that verdict would exit 0" ;; esac
done
for v in PASS PENDING; do
  case ",$_failon," in *",$v,"*) no "fail-on default contains $v (over-blocks a reviewed pass)" ;; *) ok "fail-on default correctly omits $v" ;; esac
done

echo ""
echo "── action.yml lanes: $PASS passed · $FAIL failed ──"
[ "$FAIL" -eq 0 ]
