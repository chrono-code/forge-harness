#!/usr/bin/env bash
# outbound_query_hook.sh — PreToolUse(WebSearch|WebFetch): the WIRING for the outbound-query
# hygiene lint. 🟥 This is the FIRST hook in this repo that can emit a `deny`, so its degrade
# direction is the design, not a footnote.
#
# ── WHY A HOOK, AND WHY NOW ────────────────────────────────────────────────────────────────────
# `scripts/outbound_query_guard.sh` has owned this lint since 2026-08-21 and its own header says
# it "is wired to no outbound executor at all". A lint with zero callers is prose in a .sh file
# ([[feedback_built_but_not_wired]]); the question «did it work» was answered by EXISTENCE, which
# is the half-externalization shape ([[feedback_half_externalization_slot_without_consumer]]).
# The session's own WebSearch/WebFetch call IS the outbound executor, and PreToolUse is the only
# place that sits ON that path — a repo scanner never reads an interactively-composed query
# ([[feedback_instrument_not_on_the_path]], same reasoning as pipe_verdict_guard's).
#
# ── WHY IT IS NOT «just run the guard» ─────────────────────────────────────────────────────────
# The guard fail-closes (exit 3) when the operator's gitignored override layer is absent. That is
# RIGHT for a CLI the operator types, and WRONG for a hook: in a consumer install that layer is
# absent BY CONSTRUCTION, so importing the guard's contract would deny every consumer's WebSearch.
# CLAUDE.md: «a gate that blocks every new install is not a strict gate, it is a bypass trainer»,
# and the bypass it trains is disabling hooks — the same channel the destructive-op and
# confidentiality gates ride on. So the verdict is split BY LAYER:
#
#   override layer hit  → deny      the operator's own internal literals. This is the leak class
#                                   the guard exists for, and it is irreversible once sent.
#   defaults layer hit  → advisory  universal shapes (emails, home paths, key formats). FP-prone,
#                                   and it is ALL a consumer has — blocking on it would be the
#                                   over-block above.
#   no override present → advisory only, plus a once-per-session UNCALIBRATED notice: a
#                                   defaults-only scan CANNOT say «no internal tokens», it can
#                                   only say «no universal shapes» ([[feedback_not_found_is_not_zero_family]]).
#   instrument incomplete → deny    (lib absent · defaults broken · dropped pattern rows · dead
#                                   canary · scanner returned a non-verdict). NOT SCANNED is not
#                                   clean, and this surface is irreversible
#                                   (CLAUDE.md §Irreversibility Gates: fail CLOSED).
#   not an FH checkout   → silent   applicability is MECHANICAL (is the tracked defaults file
#                                   here?), never self-judged — and in that tree we create nothing.
#
# 🟥 THE LAYER IS DECIDED BY COUNTS, NOT BY A BOOLEAN. Scan twice — full set, then defaults-only —
#    and compare hit COUNTS. With booleans, «both layers hit» is indistinguishable from «defaults
#    hit», which silently downgrades a real deny to an advisory. `n_full < n_def` is impossible
#    (the full stream is a superset) and is therefore treated as instrument anomaly → deny.
#
# 🟥 THE OUTPUT MUST NEVER CARRY THE TOKEN VALUE. psa_scan_tagged prints `SEV leak — path: 'tok'`.
#    Echoing that into a deny reason, a systemMessage, or the event log would make the leak guard
#    the leak channel — and CLAUDE.md's residency rule names logs and comments explicitly. Only
#    the COUNT and the SEVERITY LABEL leave this script, and a label that is not plain ASCII
#    letters is rendered `?`. Lane H10 asserts the fixture token appears on no output surface.
#
# ── STDIN SHAPE: WHY KEY NAMES ARE NOT HARDCODED ───────────────────────────────────────────────
# The official hooks reference (code.claude.com/docs/en/hooks-guide.md, read 2026-09-05) documents
# `tool_name` and `tool_input` but does NOT document WebSearch's / WebFetch's `tool_input` keys.
# Hardcoding `query` / `url` / `prompt` on an unverified schema fails SILENTLY OPEN the day the
# schema changes. So every STRING VALUE in `tool_input` is collected recursively and scanned as
# one record. The key NAMES (schema, never user content) are recorded in the event log so the
# real shape becomes measured rather than assumed.
#   MEASURED 2026-09-05, disposable clone, sonnet, real WebSearch call: the logged key column read
#   `query` — so WebSearch's key is `query` today. Recorded as an OBSERVATION, not as a contract to
#   depend on: the scan still walks every string value, so a renamed or added key stays covered.
#
# ── WHAT A CLEAN-CLONE RUN FOUND THAT THE LANES COULD NOT ──────────────────────────────────────
# First run: both evidence files landed as UNTRACKED paths and the runner flagged tree
# contamination — .gitignore had explicit entries for the other hooks' event files and none for
# these two. Every lane passed throughout; nothing in a fixture tree can see a repo's .gitignore.
# That is the «adversarial review is not a substitute for first use» shape
# ([[feedback_adversarial_review_not_substitute_for_first_use]]). Fixed in .gitignore, and the
# consumer-facing twin of it is called out in templates/settings.PreToolUse.snippet.json.
#
# ── DEGRADE CONTRACT ───────────────────────────────────────────────────────────────────────────
#   unparseable payload / python3 absent → SILENT exit 0. A dead interpreter must not block tool
#   calls (same contract as pipe_verdict_guard / proposal_hook). This is the one place where
#   «cannot measure» does not deny, and it is deliberate: the failure is in OUR harness, it is
#   loud in no direction, and denying on it would take the session's web access away whenever
#   python3 hiccups. Named as a residual, not defended as complete.
#   Every other «cannot measure» state DENIES, because there the scanner ran and did not certify.
#   exit code is ALWAYS 0 — the JSON carries the verdict (docs: "Exit 0 with JSON output: parsed
#   JSON controls behavior"). exit 2 would work too but discards the structured reason.
#
# Opt out on one call by putting `# noqa: outbound` in the query. 🟥 That channel is gameable —
# which is exactly why it writes a log row. An invisible bypass is worse than a recorded one.
#
# Wiring: templates/settings.PreToolUse.snippet.json (SIXTH GUARD). Lanes:
#   bash scripts/test_outbound_query_hook_lanes.sh
# Manual smoke:
#   printf '%s' '{"tool_name":"WebSearch","tool_input":{"query":"hello"}}' | bash scripts/outbound_query_hook.sh
set -uo pipefail

# 🟥 TWO ROOTS, AND THEY ARE NOT THE SAME ROOT. The library ships NEXT TO this script, so it is
# resolved from $0 — a hook is invoked by absolute path and must find its own scanner regardless
# of what CLAUDE_PROJECT_DIR points at. The pattern layers and the event log belong to the
# PROJECT being guarded, so they are resolved from CLAUDE_PROJECT_DIR. In a normal install the
# two coincide; conflating them made every lane fixture (project root ≠ repo root) deny on
# "library absent" — caught by the lanes on the first run, which is what they are for.
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
FH="${CLAUDE_PROJECT_DIR:-}"
[ -n "$FH" ] || FH="$(cd "$SELF_DIR/.." && pwd)"
# Injection points — the lanes must not move the real library or the real pattern files
# (test_outbound_query_lanes.sh L7 learned that the hard way).
LIB="${PSA_LIB_FILE:-$SELF_DIR/psa_scan_lib.sh}"
DEFAULTS="${PSA_DEFAULTS_FILE:-$FH/.claude/rules/.public-surface-patterns.defaults}"
OVERRIDE="${PSA_OVERRIDE_FILE:-$FH/.claude/rules/.public-surface-patterns}"
EVDIR="$FH/.claude"
EVFILE="$EVDIR/.outbound_hook_events.tsv"
SENTINEL="$EVDIR/.outbound_hook_uncalibrated_notice"
# A path that can never exist: /dev/null is not a directory, so any child of it is ENOTDIR.
NO_OVERRIDE="/dev/null/__fh_no_override__"

TOOL=""; SESS=""; KEYS=""; FLAGS=""; QTEXT=""

_py_extract() { cat <<'PY'
import json,sys,re
def out(a,b,c,f,d):
    # ONE line, exactly four TABs. `text` is flattened below, so no field can contain a TAB and
    # the split in bash is exact. A temp file used to carry this; mktemp's failure branch was a
    # silent `exit 0` on an outbound call (degrade_direction_scan S1, 2026-09-05) — removing the
    # file removed the branch rather than arguing about it.
    sys.stdout.write("OQH2\t"+a+"\t"+b+"\t"+c+"\t"+f+"\t"+d+"\n"); sys.exit(0)
try:
    d=json.load(sys.stdin)
except Exception:
    out("","","","-","")
if not isinstance(d,dict): out("","","","-","")
tn=re.sub(r"[^A-Za-z0-9_-]","",str(d.get("tool_name","") or ""))[:32]
sid=re.sub(r"[^A-Za-z0-9_-]","",str(d.get("session_id","") or ""))[:64]
ti=d.get("tool_input",{})
# A non-object tool_input is NOT replaced by {} — a bare string is still an outbound value and is
# scanned like any other (codex finding 1, 2026-09-05). Key NAMES: the log carries only the KNOWN
# schema names; anything else renders as `other`, so a token used as a key never lands in the
# event file (finding 4) — and keys are scanned too (walk below), because they leave as well.
keys=""
if isinstance(ti,dict):
    keys=",".join(sorted(set(k if k in ("query","url","prompt") else "other" for k in map(str,ti.keys()))))
vals=[]; trunc=[False]
def walk(x,depth):
    # Past the limits the extractor STOPS and SAYS SO — a token below the cut would otherwise leave
    # as "clean" (findings 2·3). bash turns the flag into a deny (unmeasured), never a partial scan.
    if depth>8 or len(vals)>4096:
        trunc[0]=True; return
    if isinstance(x,str): vals.append(x)
    elif isinstance(x,dict):
        for k,v in x.items():
            if isinstance(k,str): vals.append(k)
            walk(v,depth+1)
    elif isinstance(x,list):
        for v in x: walk(v,depth+1)
walk(ti,0)
text=re.sub(r"[\r\n\t]"," "," ".join(vals))
out(tn,sid,keys,("T" if trunc[0] else "-"),text)
PY
}

_py_json() { cat <<'PY'
import json,sys
mode=sys.argv[1]; msg=sys.argv[2]
h={"hookEventName":"PreToolUse"}
if mode=="deny":
    h["permissionDecision"]="deny"; h["permissionDecisionReason"]=msg
else:
    h["additionalContext"]=msg
print(json.dumps({"hookSpecificOutput":h,"systemMessage":msg},ensure_ascii=False))
PY
}

_log() {   # $1=verdict $2=layer
  mkdir -p "$EVDIR" 2>/dev/null || return 1
  # Returns 1 when the row could not be written. Only the noqa path acts on that (see below):
  # for every other verdict a lost log line is a lost record, not a lost block.
  if printf '%s\t%s\t%s\t%s\t%s\n' \
       "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${TOOL:-?}" "$1" "$2" "${KEYS:-}" >> "$EVFILE" 2>/dev/null
  then return 0; else return 1; fi
}

# 🟥 A DENY THAT CANNOT BE RENDERED MUST NOT BECOME A SILENT ALLOW.
#    The first build ended this function with `|| true`, so a failed JSON build emitted nothing —
#    and "no output" is how this hook says ALLOW. degrade_direction_scan S1 flagged the line and
#    it was a real default-toward-PASS on an irreversible surface, not a false positive.
#    Fallback is the documented second channel: "Exit 2: blocks action, uses stderr as reason".
#    An ADVISORY that cannot be rendered is a lost warning, not a lost block — it stays exit 0.
# OQH_PY exists so that branch is ANCHORED rather than asserted: the lane points it at a
# non-interpreter while the parse above still runs on the real python3. Same justification as
# PSA_LIB_FILE in outbound_query_guard.sh — a branch no lane can reach is decorative.
_emit() {  # $1=deny|advisory $2=message
  local _j
  _j="$("${OQH_PY:-python3}" -c "$(_py_json)" "$1" "$2" 2>/dev/null)" || _j=""
  if [ -n "$_j" ]; then printf '%s\n' "$_j"; return 0; fi
  if [ "$1" = deny ]; then
    printf '%s\n' "$2" >&2
    exit 2
  fi
  return 0
}

# Severity histogram with NO token values. The label is the pattern file's first column, so it is
# operator-authored text: anything that is not 1-8 plain ASCII letters is rendered `?`.
_sev_summary() {  # $1 = raw scan output
  printf '%s\n' "$1" \
    | grep -F ' leak — ' 2>/dev/null \
    | awk '{ s=$2; if (s=="HIGH" || s=="MED" || s=="LOW") print s; else print "?" }' \
    | sort | uniq -c \
    | awk '{ printf "%s x%s ", $2, $1 }'
  return 0
}
_hits() {  # $1 = raw scan output → count of reportable hit lines
  # noqa: degrade — `grep -c` exits 1 when the count is ZERO, which is the normal clean case, and
  # it still PRINTS "0". The `|| true` protects the function's rc, not its value; a genuine grep
  # error prints NOTHING, and the empty value fails closed at the `case` guard below. Verified by
  # reading both paths, 2026-09-05; the guard it lands on is labelled unanchored there.
  printf '%s\n' "$1" | grep -cF ' leak — ' 2>/dev/null || true   # noqa: degrade (see above)
}

_deny_unmeasured() {  # $1 = what is incomplete (no token values, ever)
  _log deny -
  _emit deny "🚫 outbound 차단 — 미측정(계기 불완전: $1). 나가는 질의는 되돌릴 수 없으므로 «못 쟀다»를 «깨끗하다»로 접지 않는다(CLAUDE.md §Irreversibility Gates). 고쳐야 할 것: 위 계기. 확인 후 강행하려면 질의에 '# noqa: outbound' 를 넣어라 — 통과하지만 로그에 남는다."
  exit 0
}

# ── 1. parse ───────────────────────────────────────────────────────────────────────────────────
# python3 absent / crashed / payload unparseable → empty → silent exit 0. That is the ONE named
# fail-open in this script (see DEGRADE CONTRACT above): a dead interpreter is our defect, not the
# session's, and taking web access away on it would train the hook off.
_META="$(python3 -c "$(_py_extract)" 2>/dev/null)"
[ -n "$_META" ] || exit 0
# 🟥 Do NOT use `IFS=$'\t' read` here: TAB is an IFS whitespace character, so consecutive
#    separators MERGE and an empty field SHIFTS every later field left — a session with no
#    session_id would silently read its KEYS as SESS ([[feedback_ifs_read_collapses_empty_fields]]).
#    Positional splits cannot collapse. (An earlier draft said "exact-count validation, then
#    positional splits"; the count is gone — see the next paragraph — and leaving that sentence
#    would be a rule describing a machine it no longer has.)
# 🟥 VALIDATE WITH A PREFIX, NOT BY COUNTING — the count was a DoS that degraded into a BYPASS.
#    The first build validated the field count with `_TABS="${_META//[!$'\t']/}"`. Measured on
#    bash 3.2 (macOS /bin/bash, the shell this hook actually runs under): that ONE substitution
#    takes **47.7s on a 10,000-char line**, and the whole hook went 0.23s @0.5KB → 6.6s @5KB →
#    49.7s @10KB. With `"timeout": 5` in settings the hook is KILLED, and a killed PreToolUse hook
#    is a non-blocking error — **the tool proceeds**. So a long enough query walked straight past
#    the guard: a bypass by PADDING, needing no override and leaving no row. The library was never
#    the cost (psa_scan_tagged does the same 10,000 chars in 0.15s); the guard was.
#    The extractor already builds the line and controls every field, so the invariant belongs
#    there: it emits a magic first field, and bash checks a PREFIX (O(1)) instead of scanning the
#    whole string. Positional splits are 0.02s at the same size. Anchored by lane H23.
case "$_META" in "OQH2"$'\t'*) ;; *) exit 0 ;; esac
_R0="${_META#*$'\t'}"
TOOL="${_R0%%$'\t'*}";  _R1="${_R0#*$'\t'}"
SESS="${_R1%%$'\t'*}";  _R2="${_R1#*$'\t'}"
KEYS="${_R2%%$'\t'*}";  _R3="${_R2#*$'\t'}"
FLAGS="${_R3%%$'\t'*}"; QTEXT="${_R3#*$'\t'}"

# ── 2. scope: only the two outbound tools, and nothing else is logged ──────────────────────────
case "$TOOL" in WebSearch|WebFetch) ;; *) exit 0 ;; esac

# ── 3. applicability — MECHANICAL, never self-judged (CLAUDE.md §Surface-Class Degrade) ────────
# The tracked defaults layer ships with this repo. Absent ⇒ this is not an FH-derived checkout,
# so the guard has no target here. `applicable-but-tooling-down` is handled below, not here.
# 🟥 THIS RUNS BEFORE THE OPT-OUT, and the order is load-bearing. With the opt-out first, a
#    `# noqa: outbound` query in a NON-FH tree would try to write a log row, and the fail-closed
#    rule below would then DENY a call this hook has no business judging at all — over-blocking a
#    stranger's repo. Applicability first means the bypass rule only binds where the guard is live.
# N/A is silent AND unrecorded — an earlier build appended an `na` row whenever `.claude/` already
# existed, which is every Claude Code project, so a user-level hook wrote into stranger repos
# (codex finding 7, 2026-09-05). Lane H4b now asserts the file is NOT created.
[ -r "$DEFAULTS" ] || exit 0

# ── 4. opt-out, recorded ───────────────────────────────────────────────────────────────────────
if printf '%s' "$QTEXT" | grep -qE '#[[:space:]]*noqa:?[[:space:]]*outbound' 2>/dev/null; then
  # 🟥 THE RECORD IS THE PRICE OF THE BYPASS. This channel is gameable by design; what keeps it
  #    honest is that it leaves a row. If the row cannot be written, the bypass becomes INVISIBLE,
  #    and an unrecorded bypass on an irreversible surface is worse than no bypass at all — so the
  #    opt-out itself fails closed here. Every other verdict tolerates a lost log line.
  _log noqa - && exit 0
  _deny_unmeasured "opt-out(# noqa: outbound)을 기록할 수 없다 — 기록 못 하는 우회는 보이지 않는 우회다"
fi

# ── 5. nothing to scan ─────────────────────────────────────────────────────────────────────────
# 🟥 The extractor reports TRUNCATION (nesting deeper than 8, or more than 4096 string values) as a
#    flag instead of scanning what it could reach — a token below the cut would leave as "clean"
#    (codex findings 2·3). Unmeasured ⇒ deny, like every other incomplete-instrument branch. H26/H27.
case "$FLAGS" in *T*) _deny_unmeasured "입력 구조가 추출 한계(깊이 8 · 값 4096)를 넘어 일부를 못 봤다" ;; esac
# Emptiness is a bash pattern, not an external `tr`: on a PATH without `tr` the substitution came
# back empty and that read as "nothing to scan" = clean allow (codex finding 6). Lane H30.
case "$QTEXT" in *[![:space:]]*) ;; *) _log clean -; exit 0 ;; esac

# ── 6. instrument ──────────────────────────────────────────────────────────────────────────────
[ -r "$LIB" ] || _deny_unmeasured "스캐너 라이브러리 부재"
# shellcheck source=/dev/null
. "$LIB" 2>/dev/null || _deny_unmeasured "스캐너 라이브러리 로드 실패"
# Pin the allowlist root: without it psa_pair_allowlisted falls back to `git rev-parse` or `.`,
# which in a hook can resolve to a DIFFERENT repo than the one being scanned.
PSA_REPO_ROOT="$FH"; export PSA_REPO_ROOT

# 🟥 FLATTENING LIVES IN THE EXTRACTOR, NOT HERE — measured, and the belt was dead.
#    psa_scan_tagged reads `path<TAB>body` per LINE, so a newline+tab in the query would push the
#    token into the PATH field and out of the scan (the bypass test_outbound_query_lanes.sh L9
#    pins for the CLI). A `tr` belt stood here; a revert probe removed it and lane H8 stayed
#    GREEN (mutant M7) — the extractor's `re.sub` had already done it. Removing THAT (M8) turned
#    H8 into `none`, i.e. SILENT pass-through, because the 4-line read protocol below also
#    depends on the text being one line. One owner, anchored by H8. The duplicate is deleted
#    rather than kept as reassurance ([[feedback_anchor_can_be_decorative]]).
QFLAT="$QTEXT"

_load_and_check() {  # $1=defaults $2=override ; state via case, never [ -ne ] (non-numeric → fail-open)
  psa_load "$1" "$2" >/dev/null 2>&1 || true
  case "${PSA_DEFAULTS_OK:-}" in 1) ;; *) return 1 ;; esac
  case "${PSA_BAD_ROWS:-}" in 0) ;; *) return 2 ;; esac
  return 0
}

_load_and_check "$DEFAULTS" "$OVERRIDE"; _lc=$?
case "$_lc" in
  0) ;;
  1) _deny_unmeasured "공용 패턴층(defaults)이 비었거나 못 읽는다" ;;
  *) _deny_unmeasured "패턴 파일에 형식오류 행이 있어 검출기 집합이 부분적이다" ;;
esac
OVR="${PSA_OVERRIDE_PRESENT:-0}"
psa_require_live >/dev/null 2>&1 || _deny_unmeasured "psa_require_live 실패 — 스캐너가 알려진 토큰도 못 잡는다"

if FULL="$(printf 'outbound-query\t%s' "$QFLAT" | psa_scan_tagged 2>&1)"; then FRC=0; else FRC=$?; fi
case "$FRC" in 0|1) ;; *) _deny_unmeasured "스캐너가 측정값을 안 냈다 (rc=$FRC)" ;; esac
printf '%s' "$FULL" | grep -qF 'INSTRUMENT DEAD' 2>/dev/null && _deny_unmeasured "스캐너가 INSTRUMENT DEAD 를 보고했다"
N_FULL="$(_hits "$FULL")"

# ── 7. defaults-only re-scan → which LAYER produced the hits ───────────────────────────────────
if [ "$OVR" = 1 ]; then
  _load_and_check "$DEFAULTS" "$NO_OVERRIDE"; _lc=$?
  [ "$_lc" -eq 0 ] || _deny_unmeasured "defaults 전용 재로드 실패 (층 판별 불가)"
  if DEFONLY="$(printf 'outbound-query\t%s' "$QFLAT" | psa_scan_tagged 2>&1)"; then DRC=0; else DRC=$?; fi
  case "$DRC" in 0|1) ;; *) _deny_unmeasured "defaults 전용 스캔이 측정값을 안 냈다 (rc=$DRC)" ;; esac
  N_DEF="$(_hits "$DEFONLY")"
else
  DEFONLY="$FULL"; N_DEF="$N_FULL"
fi
# ⚠️ UNANCHORED, DELIBERATELY KEPT (measured 2026-09-05, mutant M11): removing both lines leaves
#    all 64 lanes green. The only realistic way `_hits` returns a non-number is a broken grep, and
#    `psa_require_live` above dies on that first — so this branch is unreachable today. Kept as the
#    guard for a refactor that removes the canary; labelled, because an unlabelled unreachable
#    guard reads as a control it is not ([[feedback_anchor_can_be_decorative]]).
case "$N_FULL" in ''|*[!0-9]*) _deny_unmeasured "히트 계수 실패(full)" ;; esac
case "$N_DEF"  in ''|*[!0-9]*) _deny_unmeasured "히트 계수 실패(defaults)" ;; esac
# A superset cannot produce fewer hits than its subset. If it did, the two scans did not see the
# same instrument — that is an anomaly, and an anomaly on an irreversible surface is a deny.
[ "$N_FULL" -ge "$N_DEF" ] || _deny_unmeasured "층 비교 이상 (full=$N_FULL < defaults=$N_DEF)"

# ── 8. once-per-session UNCALIBRATED notice (consumer installs) ────────────────────────────────
_uncal_due() {
  local key cur
  key="${SESS:-}"; [ -n "$key" ] || key="$(date -u +%Y-%m-%d)"
  cur=""; [ -r "$SENTINEL" ] && cur="$(cat "$SENTINEL" 2>/dev/null || true)"
  [ "${cur%% *}" = "$key" ] && return 1
  mkdir -p "$EVDIR" 2>/dev/null || true
  # noqa: degrade — a failed sentinel write makes the UNCALIBRATED notice REPEAT on every call.
  # That degrades toward more noise, never toward silence, so the permissive short-circuit is in
  # the safe direction here. (Contrast `_log` on the noqa path, where the same shape was NOT safe
  # and was changed to fail closed.)
  printf '%s %s\n' "$key" "$(date -u +%Y-%m-%d)" > "$SENTINEL" 2>/dev/null || true   # noqa: degrade (see above)
  return 0
}
UNCAL=""
if [ "$OVR" != 1 ]; then
  if _uncal_due; then
    UNCAL=" 🟥 UNCALIBRATED — 운영자 내부 패턴층(.claude/rules/.public-surface-patterns)이 이 설치에 없다. 공용 층만 본 결과라 «내부 토큰 없음»은 말할 수 없다(미측정). 이 고지는 세션당 1회."
  fi
fi

# ── 9. verdict ─────────────────────────────────────────────────────────────────────────────────
if [ "$N_FULL" -eq 0 ]; then
  _log clean -
  exit 0
elif [ "$N_FULL" -gt "$N_DEF" ]; then
  _log deny override
  _emit deny "🚫 outbound 차단 — 나가는 질의에 «운영자 내부 패턴층» 히트 $N_FULL 건 (심각도: $(_sev_summary "$FULL")). 🟥 토큰 값은 여기 적지 않는다 — 유출 가드가 유출 채널이 되면 안 되니까. 나간 질의는 되돌릴 수 없다. 고쳐라: 내부 이름 대신 그 이름이 가리키는 «형태»를 일반 어휘로 써라 (예: «우리 X 게이트가…» → «커밋 전에 근거 필드를 강제하는 훅 패턴»). 확인 후 강행: 질의에 '# noqa: outbound' 를 넣어라 — 통과하지만 로그에 남는다."
  exit 0
else
  _log advisory defaults
  _emit advisory "⚠️ outbound 위생 — 나가는 질의가 «공용(defaults)» 패턴에 $N_DEF 건 걸린다 (심각도: $(_sev_summary "$DEFONLY")). 차단은 안 한다: 공용 층은 보편 형태라 오탐이 잦고, 여기서 막으면 훅을 끄게 만든다. 토큰 값은 적지 않는다 — 질의를 사람 눈으로 한 번 보고, 내부 이름이면 일반 어휘로 바꿔 다시 불러라.$UNCAL"
  exit 0
fi
