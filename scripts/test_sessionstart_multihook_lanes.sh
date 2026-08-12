#!/usr/bin/env bash
# test_sessionstart_multihook_lanes.sh — what actually happens when SEVERAL SessionStart hooks are
# registered on ONE matcher.
#
# WHY: this repo's .claude/settings.local.json registers three SessionStart commands on a single
# matcher, and CLAUDE.md leans on that wiring ("hook-backed via scripts/fh_session_load.sh"), yet the
# multi-hook behaviour had never been demonstrated. Four questions were open: ORDER, whether one
# failing hook blocks the others, whether stdout INTERLEAVES or is CONCATENATED, and whether a
# non-zero exit is visible at all. They are answered here by running the real `claude` CLI, because
# no amount of reading settings.json answers any of them.
#
# INSTRUMENT — two channels, deliberately:
#   (a) TYPED: `--output-format stream-json --verbose` emits one `hook_response` object per hook with
#       {exit_code, outcome, stdout, stderr}. This is a machine channel, not prose-grep.
#   (b) DELIVERED: the assistant's own final text, which measures what reached the AGENT. (a) and (b)
#       are different propositions — the harness capturing a hook's output is not the same as the
#       session receiving it — and the gap between them is the finding.
#   Channel (b) is model-mediated, so it is only trusted through an IN-RUN control: the same reply
#   must list its sibling markers. A model that simply answered lazily would drop all of them.
#
# COST: two `claude -p` calls on the cheapest model, a few hundred tokens each. Network + auth
# required.
#
# EXIT CODES — three-valued on purpose:
#   0 = every lane calibrated · 1 = a lane FAILED · 2 = NOT EXERCISED (no CLI / no auth / opted out).
# 2 is never a pass. A suite that cannot run must not be readable as a green one.
#   Opt out with FH_SKIP_LIVE_CLAUDE=1 (still exits 2).

set -uo pipefail
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/fh_multihook.XXXXXX")
trap 'rm -rf "$TMPROOT"' EXIT
FAILED=0; PASSED=0; GAPS=0
_pass() { echo "✅ $1"; PASSED=$((PASSED+1)); }
_fail() { echo "❌ $1"; FAILED=1; }
_eq()   { if [ "$2" = "$3" ]; then _pass "$1 ($2)"; else _fail "$1 — got [$2], expected [$3]"; fi; }
_gap()  { if [ "$2" = "1" ]; then echo "ⓘ GAP (still open) $1"; echo "       ↳ $3"; GAPS=$((GAPS+1));
          else echo "🎉 GAP CLOSED — $1 : behaviour changed, promote this lane"; fi; }
_unexercised() { echo; echo "══════════════════════════════════════════════"; echo "MULTI-HOOK LANES: NOT EXERCISED — $1"; echo "  This is exit 2, not a pass. Nothing below was measured."; exit 2; }

[ -n "${FH_SKIP_LIVE_CLAUDE:-}" ] && _unexercised "FH_SKIP_LIVE_CLAUDE is set (explicit opt-out)"
command -v claude >/dev/null 2>&1 || _unexercised "the \`claude\` CLI is not on PATH"

# ── fixture ─────────────────────────────────────────────────────────────────────
# A: slow (0.4s) + exit 0 — its lateness is what makes concurrency observable.
# B: instant + configurable exit — the hook under test.
# C: instant + exit 0 — the sibling that must survive B.
# D: a command pointing at a script that DOES NOT EXIST (bash exits 127). This is not hypothetical:
#    it is the shape of a stale settings.json entry, and this repo has one today.
_fixture() {  # $1=name $2=B's exit code → echoes project dir
  local P="$TMPROOT/$1" n ec slp
  mkdir -p "$P/.claude" "$P/h"
  local L="$P/hooklog.txt"
  for n in A B C; do
    ec=0; slp=0
    [ "$n" = A ] && slp=0.4
    [ "$n" = B ] && ec="$2"
    cat > "$P/h/$n.sh" <<EOF
#!/usr/bin/env bash
python3 -c 'import time;print("%.6f"%time.time())' | sed 's/^/$n START /' >> "$L"
sleep $slp
echo "HOOK_${n}_STDOUT_MARKER"
echo "HOOK_${n}_ERRSTREAM_MARKER" >&2
python3 -c 'import time;print("%.6f"%time.time())' | sed 's/^/$n END /' >> "$L"
exit $ec
EOF
    chmod +x "$P/h/$n.sh"
  done
  cat > "$P/.claude/settings.json" <<EOF
{"hooks":{"SessionStart":[{"matcher":"","hooks":[
 {"type":"command","command":"bash $P/h/A.sh","timeout":15},
 {"type":"command","command":"bash $P/h/B.sh","timeout":15},
 {"type":"command","command":"bash $P/h/C.sh","timeout":15},
 {"type":"command","command":"bash \"$P/h/MISSING_ON_PURPOSE.sh\" --quiet","timeout":15}]}]}}
EOF
  printf '%s' "$P"
}

PROMPT='List verbatim, one per line, every line in your session-start context that contains the string MARKER. If there are none, reply exactly NONE.'

# Timeout guard (2026-08-12, cross-family review flagged the unbounded call as the only genuinely
# blocking point this suite's two `claude -p` invocations reach — a hung/slow CLI call had no upper
# bound, so a source-tree `selfcheck.sh` run could hang indefinitely on this lane alone. `timeout` is
# GNU coreutils and stock macOS does not ship it — same availability gap compaction_probe.sh's
# --self-test already guards for, same fix shape: probe once, use it if present, run unguarded (the
# pre-existing residual) if not, rather than hard-failing on a missing tool this lane does not own.
_TO=""; command -v timeout >/dev/null 2>&1 && _TO="timeout 120"

_run() {  # $1=project dir → writes $1/stream.jsonl ; sets CLI_RC
  ( cd "$1" && $_TO claude -p "$PROMPT" --model haiku --dangerously-skip-permissions \
      --output-format stream-json --verbose </dev/null >"$1/stream.jsonl" 2>"$1/cli.err" )
  CLI_RC=$?   # read DIRECTLY off the subshell, never through a pipe
  # A `timeout`-killed call exits 124 and leaves stream.jsonl empty — the existing
  # `[ ! -s stream.jsonl ]` branches at both call sites already route that to _unexercised/_fail
  # correctly (empty stream, not a crash to diagnose), so 124 needs no separate branch here. Named so
  # a future reader does not add one on the mistaken belief 124 is unhandled.
}

# typed-channel query. $1=stream file $2=one of: markers|exit:<marker>|outcome:<marker>|
#                                                 err127|order|count
_q() { python3 - "$1" "$2" <<'PY'
import sys, json
rows = []
for line in open(sys.argv[1], errors="replace"):
    try: d = json.loads(line)
    except Exception: continue
    if d.get("subtype") == "hook_response" and d.get("hook_event") == "SessionStart":
        rows.append(d)
    if d.get("type") == "result":
        rows.append({"__result__": d.get("result") or ""})
res  = "".join(r["__result__"] for r in rows if "__result__" in r)
hks  = [r for r in rows if "__result__" not in r]
def find(m): return [h for h in hks if m in (h.get("stdout") or "") or m in (h.get("stderr") or "")]
q = sys.argv[2]
if q == "count":                      # how many of OUR hooks reported at all
    print(sum(1 for m in ("HOOK_A_", "HOOK_B_", "HOOK_C_") if find(m)))
elif q == "order":                    # arrival order of our markers in the typed stream
    print(",".join(n for h in hks for n in ("A", "B", "C") if "HOOK_%s_STDOUT" % n in (h.get("stdout") or "")))
elif q == "err127":                   # the nonexistent-script hook
    e = [h for h in hks if "MISSING_ON_PURPOSE" in (h.get("stderr") or "")]
    print("%s|%s" % (e[0].get("exit_code"), e[0].get("outcome")) if e else "ABSENT|ABSENT")
elif q.startswith("exit:"):
    f = find(q[5:]); print(f[0].get("exit_code") if f else "ABSENT")
elif q.startswith("outcome:"):
    f = find(q[8:]); print(f[0].get("outcome") if f else "ABSENT")
elif q.startswith("stderrcap:"):
    f = find(q[10:]); print("1" if f and (f[0].get("stderr") or "").strip() else "0")
elif q.startswith("delivered:"):      # did the marker reach the AGENT's reply
    print("1" if q[10:] in res else "0")
elif q == "reply":
    print(res.replace("\n", " ⏎ ")[:300])
PY
}

echo "══ RUN-N — four hooks, one matcher: B exits 2, D's script does not exist ══"
PN=$(_fixture neg 2); _run "$PN"
if [ ! -s "$PN/stream.jsonl" ]; then
  echo "   cli stderr: $(head -c 300 "$PN/cli.err")"
  _unexercised "the claude CLI produced no stream (rc=$CLI_RC) — auth/network, not a result"
fi

_eq "MH-1 all three instrumented hooks RAN (nothing was short-circuited)" "$(_q "$PN/stream.jsonl" count)" 3
LOG="$PN/hooklog.txt"
if [ -f "$LOG" ]; then
  # concurrency, measured: A sleeps 0.4s. If execution were serial in declared order, B and C could
  # not START before A ENDs.
  AEND=$(awk '$1=="A"&&$2=="END"{print $3}' "$LOG" | head -1)
  BST=$(awk  '$1=="B"&&$2=="START"{print $3}' "$LOG" | head -1)
  CST=$(awk  '$1=="C"&&$2=="START"{print $3}' "$LOG" | head -1)
  CONC=$(python3 -c "import sys;a,b,c=map(float,sys.argv[1:4]);print(1 if b<a and c<a else 0)" "$AEND" "$BST" "$CST" 2>/dev/null || echo x)
  _eq "MH-2 hooks run CONCURRENTLY (B and C start before the 0.4s hook A ends)" "$CONC" 1
else
  _fail "MH-2 hooklog absent — hooks did not execute; every lane below would be vacuous"
fi
echo "   ↳ typed-channel arrival order of our markers: [$(_q "$PN/stream.jsonl" order)] (declared order is A,B,C)"

_eq "MH-3 the failing hook's exit code IS captured on the typed channel" "$(_q "$PN/stream.jsonl" exit:HOOK_B_STDOUT_MARKER)" 2
_eq "MH-3 → and it is labelled an error there"        "$(_q "$PN/stream.jsonl" outcome:HOOK_B_STDOUT_MARKER)" error
_eq "MH-3 → sibling A is labelled success (paired)"   "$(_q "$PN/stream.jsonl" outcome:HOOK_A_STDOUT_MARKER)" success
_eq "MH-3 → sibling C is labelled success (paired)"   "$(_q "$PN/stream.jsonl" outcome:HOOK_C_STDOUT_MARKER)" success

_eq "MH-4 nonexistent hook script → exit 127 / error on the typed channel" "$(_q "$PN/stream.jsonl" err127)" "127|error"

# DELIVERY — the separate proposition. In-run control: A and C must be present in the same reply.
_eq "MH-5 sibling A's output reached the agent (in-run control)" "$(_q "$PN/stream.jsonl" delivered:HOOK_A_STDOUT_MARKER)" 1
_eq "MH-5 sibling C's output reached the agent (in-run control)" "$(_q "$PN/stream.jsonl" delivered:HOOK_C_STDOUT_MARKER)" 1
_gB=0; [ "$(_q "$PN/stream.jsonl" delivered:HOOK_B_STDOUT_MARKER)" = 0 ] && _gB=1
_gap "a hook that exits non-zero has its stdout DISCARDED from the agent's context" "$_gB" \
  "B's stdout is captured on the typed channel (MH-3) and is NOT in the agent's reply, while its two \
siblings from the same run ARE. So the loss is delivery, not the model. Any FH SessionStart script \
that exits non-zero — via set -u, a missing dependency, a bad path — reports NOTHING and looks \
identical to a clean session."

_gE=0; [ "$(_q "$PN/stream.jsonl" delivered:HOOK_A_ERRSTREAM_MARKER)" = 0 ] && _gE=1
_gap "stderr is never delivered, even from a SUCCEEDING hook" "$_gE" \
  "Hook A exited 0 and its stdout reached the agent; its stderr did not. A hook that warns on stderr \
(the conventional stream for warnings) is writing to a channel with no reader."

_eq "MH-6 the CLI's own exit code is unaffected by a failing hook" "$CLI_RC" 0
_gap "nothing surfaces the failure to a human in normal use" 1 \
  "claude exits 0, the failing hook's output is dropped, and the only place the failure exists is a \
hook_response object visible solely under --output-format stream-json --verbose. In an ordinary \
interactive or -p session there is no line, no banner, and no non-zero status. Agent reply for the \
record: $(_q "$PN/stream.jsonl" reply)"

echo
echo "══ RUN-P — CONTROL: identical fixture, B exits 0 ══"
PP=$(_fixture pos 0); _run "$PP"
if [ ! -s "$PP/stream.jsonl" ]; then _fail "MH-C control run produced no stream (rc=$CLI_RC) — RUN-N's gaps are UNCONFIRMED"; else
  _eq "MH-C  B now exits 0 on the typed channel"                     "$(_q "$PP/stream.jsonl" exit:HOOK_B_STDOUT_MARKER)" 0
  _eq "MH-C  → and B's output NOW reaches the agent (closes MH-5)"   "$(_q "$PP/stream.jsonl" delivered:HOOK_B_STDOUT_MARKER)" 1
  _eq "MH-C  → A still delivered"                                    "$(_q "$PP/stream.jsonl" delivered:HOOK_A_STDOUT_MARKER)" 1
  _eq "MH-C  → C still delivered"                                    "$(_q "$PP/stream.jsonl" delivered:HOOK_C_STDOUT_MARKER)" 1
  _eq "MH-C  the missing-script hook still fails, independently"     "$(_q "$PP/stream.jsonl" err127)" "127|error"
fi

echo
echo "──────────────────────────────────────────────"
if [ "$FAILED" -ne 0 ]; then
  echo "MULTI-HOOK LANES: FAIL — instrument miscalibrated (do not trust its verdict)"
  echo "  asserting lanes passed: $PASSED · open gaps: $GAPS"
  exit 1
fi
echo "MULTI-HOOK LANES: PASS ($PASSED asserting lanes) · $GAPS KNOWN GAP(S) open (see ⓘ above)"
echo "  ANSWERS: hooks on one matcher run CONCURRENTLY, in no guaranteed order; a failing hook does"
echo "  NOT block its siblings; outputs are delivered as separate blocks in COMPLETION order, not"
echo "  concatenated in declaration order; a non-zero exit is invisible outside stream-json."
exit 0
