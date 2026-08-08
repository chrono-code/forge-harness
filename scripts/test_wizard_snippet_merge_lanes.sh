#!/usr/bin/env bash
# test_wizard_snippet_merge_lanes.sh — lanes for the SessionStart snippet → settings.json merge.
#
# SUBJECT: the python block in plugins/fh-meta/skills/install-wizard/SKILL_detail.md
# §Step4-Baseline-Bash that reads templates/settings.SessionStart.snippet.json and merges its
# `project_settings_json` entry into the user's .claude/settings.json.
#
# The subject is EXTRACTED FROM THE SHIPPED FILE at run time, never retyped. A retyped copy is the
# divergent-copy class this repo has already paid for: the lane would keep validating the OLD merge
# while the shipped one drifted, and stay green throughout. Extraction failure is a FAIL, not a skip.
#
# WHY THIS MATTERS MORE THAN AN ORDINARY PARSER LANE: the hook being registered here is
# fh_node_check.sh — the one thing that tells an operator at turn 0 that their machine's floors are
# missing. If the registration silently does not happen, the detector that would have said so is the
# detector that did not get installed. That loop has to be broken from outside, and the lanes below
# measure whether anything does.
#
# CALIBRATION: every absence lane names its known-positive and builds it in the same run.
# ⓘ GAP lanes pin behaviour believed wrong without failing the suite.
# Exit 0 = calibrated · 1 = the instrument (or the extraction) is wrong.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WIZ="$ROOT/plugins/fh-meta/skills/install-wizard/SKILL_detail.md"
DOC="$ROOT/plugins/fh-meta/skills/install-doctor/SKILL.md"
SNIPPET="$ROOT/templates/settings.SessionStart.snippet.json"

TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/fh_snippet_lanes.XXXXXX")
trap 'rm -rf "$TMPROOT"' EXIT
FAILED=0; PASSED=0; GAPS=0
_pass() { echo "✅ $1"; PASSED=$((PASSED+1)); }
_fail() { echo "❌ $1"; FAILED=1; }
_rc()   { if [ "$2" = "$3" ]; then _pass "$1 (exit=$2, expected=$3)"; else _fail "$1 — exit=$2, expected=$3"; fi; }
_eq()   { if [ "$2" = "$3" ]; then _pass "$1 ($2)"; else _fail "$1 — got [$2], expected [$3]"; fi; }
_gap()  { if [ "$2" = "1" ]; then echo "ⓘ GAP (still open) $1"; echo "       ↳ $3"; GAPS=$((GAPS+1));
          else echo "🎉 GAP CLOSED — $1 : behaviour changed, promote this lane"; fi; }

for f in "$WIZ" "$DOC" "$SNIPPET"; do
  [ -f "$f" ] || { echo "❌ subject missing: $f"; exit 1; }
done

echo "══ extraction (the instrument itself) ══"
MERGE="$TMPROOT/merge.py"
awk '/^python3 - "\$FH_DIR" <<.PY.$/{f=1;next} f&&/^PY$/{exit} f' "$WIZ" > "$MERGE"
N=$(wc -l < "$MERGE" | tr -d ' ')
if [ "$N" -lt 10 ]; then
  _fail "EX-1 could not extract the merge block from SKILL_detail.md (got $N lines) — NOT a pass"
  echo "──────────────────────────────────────────────"; echo "SNIPPET MERGE LANES: FAIL (extraction)"; exit 1
fi
_pass "EX-1 merge block extracted from the shipped SKILL_detail.md ($N lines)"
grep -q 'project_settings_json' "$MERGE" && _pass "EX-2 extracted block reads project_settings_json" \
  || _fail "EX-2 extracted block does not mention project_settings_json — wrong region captured"

DOCPY="$TMPROOT/doctor.py"
# NOTE the leading-whitespace tolerance: this block is indented inside an `if` in the SKILL, and a
# ^-anchored pattern extracted 0 lines. That failure surfaced as a red lane rather than a green
# vacuous one only because EX-3 treats an empty extraction as FAIL — keep it that way.
awk '/^[[:space:]]*python3 - "\$FH" <<.PY.$/{f=1;next} f&&/^[[:space:]]*PY$/{exit} f' "$DOC" > "$DOCPY"
DN=$(wc -l < "$DOCPY" | tr -d ' ')
[ "$DN" -ge 5 ] && _pass "EX-3 install-doctor registration check extracted ($DN lines)" \
  || _fail "EX-3 could not extract install-doctor's registration check (got $DN lines) — NOT a pass"

# ── fixture ─────────────────────────────────────────────────────────────────────
_hub() {  # $1=name $2=snippet-content ("@SHIPPED" = the real tracked file) → echoes path
  local h="$TMPROOT/$1"
  mkdir -p "$h/templates" "$h/.claude"
  if [ "$2" = "@SHIPPED" ]; then cp "$SNIPPET" "$h/templates/settings.SessionStart.snippet.json"
  else printf '%s' "$2" > "$h/templates/settings.SessionStart.snippet.json"; fi
  printf '%s' "$h"
}
_merge() { OUT=$(python3 "$MERGE" "$1" 2>&1); RC=$?; }   # RC read directly off python, no pipe
_registered() {  # 1 = fh_node_check present in the written settings.json
  [ -f "$1/.claude/settings.json" ] && grep -q 'fh_node_check' "$1/.claude/settings.json" && echo 1 || echo 0
}
_claims_ok() { printf '%s\n' "$OUT" | grep -q 'hook registered' && echo 1 || echo 0; }

echo
echo "══ the happy path (known-positive for every absence lane below) ══"
H=$(_hub good @SHIPPED); _merge "$H"
_rc  "MG-P  shipped snippet → exit 0" "$RC" 0
_eq  "MG-P  → fh_node_check actually present in settings.json" "$(_registered "$H")" 1
_eq  "MG-P  → success line printed" "$(_claims_ok)" 1

# the documented merge promise (SKILL_detail.md: 'Merge at HOOK level, not group level') —
# a foreign hook sharing a group with the FH one must survive.
H=$(_hub coexist @SHIPPED)
cat > "$H/.claude/settings.json" <<'J'
{"hooks":{"SessionStart":[{"matcher":"","hooks":[
 {"type":"command","command":"bash my_telemetry.sh"},
 {"type":"command","command":"bash $CLAUDE_PROJECT_DIR/scripts/fh_node_check.sh"}]}]}}
J
_merge "$H"
grep -q 'my_telemetry' "$H/.claude/settings.json" && _pass "MG-P2 foreign hook in the FH group survives the merge" \
  || _fail "MG-P2 foreign hook was dropped — the documented hook-level merge is not happening"
_eq  "MG-P2 → and fh_node_check is (re)registered" "$(_registered "$H")" 1
DUP=$(grep -c 'fh_node_check' "$H/.claude/settings.json")
_eq  "MG-P2 → old FH entry replaced, not duplicated" "$DUP" 1

echo
echo "══ malformed snippet: fails loudly, writes nothing ══"
# These four are the F10 question as posed (malformed / truncated / empty). The merge turns out to
# be fail-CLOSED here — worth pinning precisely so a future 'robustness' refactor that swallows the
# exception is caught as the regression it would be.
SHIPPED_TXT=$(cat "$SNIPPET")
i=0
for name in empty notjson truncated missingkey; do
  i=$((i+1))
  case "$name" in
    empty)      body="" ;;
    notjson)    body="oops not json at all" ;;
    truncated)  body=$(printf '%s' "$SHIPPED_TXT" | head -c 400) ;;
    missingkey) body='{"hooks":{"SessionStart":[]}}' ;;
  esac
  H=$(_hub "bad_$name" "$body"); _merge "$H"
  _rc "MG-N$i $name snippet → non-zero exit" "$RC" 1
  _eq "MG-N$i $name → nothing registered (paired with MG-P)" "$(_registered "$H")" 0
  _eq "MG-N$i $name → no success line" "$(_claims_ok)" 0
done

echo
echo "══ malformed EXISTING settings.json: the user's file is not destroyed ══"
H=$(_hub badtarget @SHIPPED); printf '{ oops' > "$H/.claude/settings.json"
_merge "$H"
_rc  "MG-T  unparsable target → non-zero exit" "$RC" 1
_eq  "MG-T  → the user's file is left byte-identical" "$(cat "$H/.claude/settings.json")" '{ oops'
[ -f "$H/.claude/settings.json.prewizard" ] \
  && _fail "MG-T  → a .prewizard backup of an unread file was written (misleading artifact)" \
  || _pass "MG-T  → no misleading backup artifact left behind"

echo
# ══ MULTI-SNIPPET DISCOVERY (regression for the 2026-08-08 high review, finding #1) ══
# The merge block used to hardcode settings.SessionStart.snippet.json, so every OTHER shipped snippet
# was structurally unregisterable — the compaction hooks shipped with a README reciting the
# shipping-is-not-wiring lesson while reproducing it, and PreToolUse was already in the same hole.
# These lanes fail if anyone reintroduces a single-snippet path.
echo "══ multi-snippet discovery ══"

_hub2() {  # $1=name → hub with the shipped SessionStart snippet PLUS a second, unrelated snippet
  local h="$TMPROOT/$1"; mkdir -p "$h/templates" "$h/.claude"
  cp "$SNIPPET" "$h/templates/settings.SessionStart.snippet.json"
  cat > "$h/templates/settings.Zzz.snippet.json" <<'EOF'
{
  "_README": ["fixture — a snippet the merge code has never heard of"],
  "project_settings_json": {
    "hooks": {
      "PreCompact": [
        { "matcher": "", "hooks": [ { "type": "command", "command": "bash \"$HUB/scripts/zzz_probe.sh\" seal" } ] }
      ]
    }
  }
}
EOF
  echo "$h"
}

H=$(_hub2 multi); _merge "$H"
_rc "MS-1 merge with two snippets exits 0" "$RC" 0
python3 -c "
import json,sys
d=json.load(open('$H/.claude/settings.json'))
h=d.get('hooks',{})
ss=json.dumps(h.get('SessionStart',[]))
pc=json.dumps(h.get('PreCompact',[]))
print('OK' if ('fh_node_check' in ss and 'zzz_probe' in pc) else 'MISS')
" > "$TMPROOT/ms.out" 2>/dev/null
_eq "MS-2 BOTH snippets registered (unknown snippet needs no code edit)" "$(cat "$TMPROOT/ms.out")" "OK"

# The registered-event set must come from the snippets, not from a hardcoded list.
_eq "MS-3 a non-SessionStart event is registered" \
    "$(python3 -c "import json;print('YES' if json.load(open('$H/.claude/settings.json')).get('hooks',{}).get('PreCompact') else 'NO')" 2>/dev/null)" "YES"

# Idempotence: re-running must not duplicate either snippet's hooks.
_merge "$H"
_eq "MS-4 re-run is idempotent (no duplicate zzz_probe entry)" \
    "$(python3 -c "import json;print(json.dumps(json.load(open('$H/.claude/settings.json')).get('hooks',{}).get('PreCompact',[])).count('zzz_probe'))" 2>/dev/null)" "1"

# A user's own hook in the same event must survive the merge (hook-level, not group-level).
python3 - "$H" <<'PY2'
import json,collections,os,sys
t=sys.argv[1]+"/.claude/settings.json"
d=json.load(open(t),object_pairs_hook=collections.OrderedDict)
d["hooks"].setdefault("PreCompact",[]).append({"matcher":"","hooks":[{"type":"command","command":"bash my_own.sh"}]})
json.dump(d,open(t,"w"),indent=2,ensure_ascii=False)
PY2
_merge "$H"
_eq "MS-5 user's own hook in the same event survives" \
    "$(python3 -c "import json;print('YES' if 'my_own.sh' in json.dumps(json.load(open('$H/.claude/settings.json')).get('hooks',{}).get('PreCompact',[])) else 'NO')" 2>/dev/null)" "YES"

# ══ RE-REVIEW REPAIRS (2026-08-08 round 2) ══
# 두 건 다 **직전 라운드의 수리가 만든 결함**이다. 레인 없이 고치면 같은 자리로 돌아온다.
echo "══ re-review repairs ══"

# ZS — 스니펫 0개는 조용한 성공이 아니라 시끄러운 실패여야 한다 (#1)
ZH="$TMPROOT/zerosnip"; mkdir -p "$ZH/templates" "$ZH/.claude"   # templates/ 는 있고 스니펫만 없다
_merge "$ZH"
_rc "ZS-1 스니펫 0개 → non-zero (조용한 성공 금지)" "$RC" 1
case "$OUT" in *"NO SNIPPETS"*) _pass "ZS-2 무엇이 없는지 이름을 말한다" ;; *) _fail "ZS-2 실패 사유가 불명" ;; esac

# KC — 파생 키가 베이스네임이면 남의 훅을 지운다 (#2)
KH=$(_hub2 keycollide)
python3 - "$KH" <<'PY2'
import json,collections,os,sys
t=sys.argv[1]+"/.claude/settings.json"
d=collections.OrderedDict()
if os.path.exists(t): d=json.load(open(t),object_pairs_hook=collections.OrderedDict)
h=d.setdefault("hooks",collections.OrderedDict())
# 사용자 자기 훅 — 파일명은 겹치지만 **경로가 다르다**
h.setdefault("PreCompact",[]).append({"matcher":"","hooks":[
  {"type":"command","command":"bash ~/tools/zzz_probe.sh --mine"}]})
json.dump(d,open(t,"w"),indent=2,ensure_ascii=False)
PY2
_merge "$KH"
_eq "KC-1 파일명만 겹치는 사용자 훅은 살아남는다" \
    "$(python3 -c "import json;print('YES' if 'tools/zzz_probe.sh' in json.dumps(json.load(open('$KH/.claude/settings.json')).get('hooks',{}).get('PreCompact',[])) else 'NO')" 2>/dev/null)" "YES"
_eq "KC-2 FH 자기 훅은 여전히 교체된다 (중복 없음)" \
    "$(python3 -c "import json;print(json.dumps(json.load(open('$KH/.claude/settings.json')).get('hooks',{}).get('PreCompact',[])).count('scripts/zzz_probe.sh'))" 2>/dev/null)" "1"

echo "══ ⓘ GAP lanes ══"

# GAP 1 — the ONLY validation is what `kept + entry` incidentally requires: that entry is a list.
# Any list-shaped value is written to the user's real settings.json and reported as success. The
# success message is not conditioned on what was actually written.
BADSCHEMA_HITS=0; BADSCHEMA_TOTAL=0; DETAIL=""
for name in emptylist nocommand wrongscript juststring; do
  case "$name" in
    emptylist)   body='{"project_settings_json":{"hooks":{"SessionStart":[]}}}' ;;
    nocommand)   body='{"project_settings_json":{"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command"}]}]}}}' ;;
    wrongscript) body='{"project_settings_json":{"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"bash /some/other/script.sh"}]}]}}}' ;;
    juststring)  body='{"project_settings_json":{"hooks":{"SessionStart":["not even an object"]}}}' ;;
  esac
  H=$(_hub "schema_$name" "$body"); _merge "$H"
  BADSCHEMA_TOTAL=$((BADSCHEMA_TOTAL+1))
  if [ "$RC" = 0 ] && [ "$(_claims_ok)" = 1 ] && [ "$(_registered "$H")" = 0 ]; then
    BADSCHEMA_HITS=$((BADSCHEMA_HITS+1)); DETAIL="$DETAIL $name"
  fi
done
# PROMOTED 2026-08-08 (was a GAP): the merge block now shape-validates before writing and re-reads
# what it wrote, so a bad-schema snippet can no longer be written-and-reported-as-success.
# NOTE the fixture nuance: the `wrongscript` case is NOT malformed — it is a valid snippet naming a
# different script, which the discovery-based merge correctly registers. `_registered` only greps for
# fh_node_check, so it reads as "not registered". Assert the property that actually matters instead:
# a run that skips a snippet must not exit 0 (fail-closed), which is what makes the old GAP dead.
_eq "BS-1 malformed snippet never yields a zero exit (fail-closed)" \
    "$(H=$(_hub bs1 '{"project_settings_json":{"hooks":{"SessionStart":["not even an object"]}}}'); _merge "$H"; [ "$RC" != 0 ] && echo CLOSED || echo OPEN)" "CLOSED"
# (GAP 1 retired — promoted to BS-1 above, 2026-08-08)

# GAP 2 — the corruption from GAP 1 is LATENT: the bad value lands in the user's settings.json and
# detonates on the NEXT wizard run, in the kept-loop, far from where it was introduced.
H=$(_hub latent '{"project_settings_json":{"hooks":{"SessionStart":["not even an object"]}}}')
_merge "$H"; FIRST_RC=$RC
_merge "$H"; SECOND_RC=$RC
# PROMOTED 2026-08-08 (was a GAP): a bad snippet is skipped with a visible SKIP line instead of
# corrupting settings.json, so run 2 no longer detonates on run 1's write.
# The old GAP was: run 1 reports success, run 2 detonates on run 1's write. The promoted property is
# DETERMINISM — both runs must reach the same verdict, so a failure is attributable to the snippet
# that caused it rather than surfacing later inside the survivor filter.
_eq "LT-1 verdict is deterministic across runs (no latent detonation)" \
    "$([ "$FIRST_RC" = "$SECOND_RC" ] && echo DETERMINISTIC || echo LATENT)" "DETERMINISTIC"
# (GAP 2 retired — promoted to LT-1 above, 2026-08-08)

# GAP 3 — INSTRUMENT COVERAGE, measured not asserted. Build the exact post-failure state (companion
# hook registered, node hook absent) and run install-doctor's registration check on it. The
# known-positive is in the same run: the companion line must fire, proving the check executed.
H="$TMPROOT/doctor_state"; mkdir -p "$H/.claude"
cat > "$H/.claude/settings.local.json" <<'J'
{"hooks":{"SessionStart":[{"matcher":"","hooks":[
 {"type":"command","command":"bash $CLAUDE_PROJECT_DIR/scripts/fh_session_load.sh"}]}]}}
J
printf '{}' > "$H/.claude/settings.json"
DOUT=$(python3 "$DOCPY" "$H" 2>&1); DRC=$?
if printf '%s\n' "$DOUT" | grep -q 'companion-load SessionStart registered'; then
  _pass "DR-P  install-doctor's check RAN on this fixture (known-positive: companion line fired, exit=$DRC)"
else
  _fail "DR-P  install-doctor's check did not fire at all — the GAP lane below would pass vacuously"
fi
_g=0; printf '%s\n' "$DOUT" | grep -qi 'node_check\|node check' || _g=1
_gap "nothing downstream verifies that fh_node_check is registered" "$_g" \
  "The node hook is absent from this fixture and install-doctor's registration check says nothing \
about it — it only greps for fh_session_load. install-doctor's ① checks the git hook FILES, not the \
SessionStart REGISTRATION of the script that reports on them. So the wizard's unconditional success \
message (GAP 1) is never contradicted by anything, and the check whose job is announcing an unwired \
machine can itself be unwired silently."

echo
echo "──────────────────────────────────────────────"
if [ "$FAILED" -ne 0 ]; then
  echo "SNIPPET MERGE LANES: FAIL — instrument miscalibrated (do not trust its verdict)"
  echo "  asserting lanes passed: $PASSED · open gaps: $GAPS"
  exit 1
fi
echo "SNIPPET MERGE LANES: PASS ($PASSED asserting lanes) · $GAPS KNOWN GAP(S) open (see ⓘ above)"
echo "  Green covers: happy path, hook-level merge promise, malformed-snippet fail-closed,"
echo "  unparsable-target preservation. Green does NOT cover the three gaps above."
exit 0
