#!/usr/bin/env bash
# test_outbound_query_hook_lanes.sh — known pairs for scripts/outbound_query_hook.sh.
# 🟥 WRITTEN BEFORE THE HOOK. The fail-before run is recorded in
#    tracks/_meta/dispatch/2026-09-05_outbound-hook/REPORT.md — a lane whose red was never
#    observed is not an anchor ([[feedback_anchor_can_be_decorative]]).
#
# WHAT IS BEING GUARDED
#   A session's WebSearch/WebFetch call is an OUTBOUND, IRREVERSIBLE act: once the query string
#   leaves, it cannot be recalled. If the string names an internal asset, the query IS the leak
#   (CLAUDE.md §Field-Harness Diagnostic: internal names never reach a log, a comment, or a paste;
#   §Irreversibility Gates: an irreversible surface fails CLOSED).
#   scripts/outbound_query_guard.sh has owned that lint since 2026-08-21 with ZERO callers. This
#   hook is its wiring — and it is the FIRST hook in this repo that can emit `permissionDecision:
#   "deny"`, so its degrade direction is the whole design, not a detail.
#
# THE TWO LAYERS (the reason this is not just "run the guard from a hook")
#   The guard fail-closes when the operator's gitignored override layer is absent — correct for a
#   CLI the operator invokes, and WRONG for a hook in a consumer install, where that layer is
#   absent by construction. Blocking every consumer's WebSearch trains the hook OFF, which is the
#   "bypass trainer" CLAUDE.md names. So the hook splits the verdict by LAYER:
#     override-layer hit  → deny      (operator's own internal literals — the real leak class)
#     defaults-layer hit  → advisory  (universal shapes; FP-prone, and a consumer has only this)
#     no override present → advisory only + a once-per-session UNCALIBRATED notice
#   The layer is decided MECHANICALLY: scan twice (full set, then defaults-only) and compare the
#   hit COUNTS. A boolean would collapse "both layers hit" into "defaults hit" and silently
#   downgrade a real deny ([[feedback_not_found_is_not_zero_family]]).
#
# 🟥 THE OUTPUT MUST NOT CARRY THE TOKEN. psa_scan_tagged prints `SEV leak — path: 'token'`.
#    A deny reason or a log row echoing that would make the LEAK GUARD ITSELF the leak channel.
#    H10 asserts the fixture token appears in NO output surface. That lane is load-bearing.
set -uo pipefail
FH="$(cd "$(dirname "$0")/.." && pwd)"
H="$FH/scripts/outbound_query_hook.sh"
PASS=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "  ✅ $1 → $2"; PASS=$((PASS+1));
       else echo "  ❌ $1 → got=$2 expect=$3"; FAIL=$((FAIL+1)); fi; }

# 🟥 subject-absent → the suite is NOT green. "skipped is not passed" — a suite that passes when
#    its subject is missing is the decorative anchor this repo keeps re-finding.
if [ ! -f "$H" ]; then
  echo "🟥 SUBJECT ABSENT — $H"
  echo "   skipped is not passed: with no hook there is nothing to anchor. exit 1."
  exit 1
fi

T="$(mktemp -d -t oqh.XXXXXX)" || exit 3
trap 'rm -rf "$T"' EXIT INT TERM

# ── fixture tree: the REAL relative layout, under a temp root ─────────────────────────────────
# 🟥 Deliberately NOT via PSA_*_FILE injection for the main lanes. Injecting every path would make
#    a typo in the hook's own default path (→ N/A everywhere → silent fail-open) invisible to the
#    whole suite. H14 exercises the injection point separately.
mk_root(){  # $1=root  $2=with_override(1/0)  $3=defaults_content(optional)
  rm -rf "$1"; mkdir -p "$1/.claude/rules"
  printf '%s' "${3:-$(printf 'HIGH\tZZDEFAULTSTOKEN\n')}" > "$1/.claude/rules/.public-surface-patterns.defaults"
  [ "$2" = 1 ] && printf 'HIGH\tZZOVERRIDETOKEN\n' > "$1/.claude/rules/.public-surface-patterns"
  return 0
}

# run <root> <json> [extra env assignments...]  → sets OUT / RC / ERR
run(){
  local root="$1" json="$2"; shift 2
  ERR="$T/err.txt"
  OUT="$(printf '%s' "$json" | env CLAUDE_PROJECT_DIR="$root" "$@" bash "$H" 2>"$ERR")"; RC=$?
  return 0
}
verdict(){  # classify the hook's stdout
  if [ -z "${OUT:-}" ]; then echo none
  elif printf '%s' "$OUT" | grep -q '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"'; then echo deny
  elif printf '%s' "$OUT" | grep -q 'additionalContext'; then echo advisory
  else echo other; fi
}
logrow(){ [ -f "$1/.claude/.outbound_hook_events.tsv" ] && tail -1 "$1/.claude/.outbound_hook_events.tsv" || echo NOLOG; }
logcol(){ logrow "$1" | awk -F'\t' -v n="$2" '{print $n}'; }
logcount(){ [ -f "$1/.claude/.outbound_hook_events.tsv" ] && wc -l < "$1/.claude/.outbound_hook_events.tsv" | tr -d ' ' || echo 0; }

WS(){ printf '{"session_id":"%s","tool_name":"WebSearch","tool_input":{"query":"%s"}}' "${2:-sessA}" "$1"; }
WF(){ printf '{"session_id":"sessA","tool_name":"WebFetch","tool_input":{"url":"%s","prompt":"%s"}}' "$1" "$2"; }

echo "── H1 known-POSITIVE — override 층 히트는 DENY 다 ──"
R="$T/r1"; mk_root "$R" 1
run "$R" "$(WS 'how do I fix ZZOVERRIDETOKEN in prod')"
chk "H1 override 토큰 → deny"        "$(verdict)" deny
chk "H1 exit 0 (JSON 이 판정을 나른다)" "$RC" 0
chk "H1 로그 verdict=deny"           "$(logcol "$R" 3)" deny
chk "H1 로그 layer=override"         "$(logcol "$R" 4)" override

echo "── H2 LAYER CONTROL — defaults 층만 히트하면 ADVISORY, deny 아니다 ──"
# 🟥 이것이 두 층 설계의 판별 레인이다. 여기서 deny 가 나오면 소비자 install 이 통째로 막힌다.
R="$T/r2"; mk_root "$R" 1
run "$R" "$(WS 'why does ZZDEFAULTSTOKEN appear here')"
chk "H2 defaults 토큰(override 존재) → advisory" "$(verdict)" advisory
chk "H2 exit 0"                                   "$RC" 0
chk "H2 로그 verdict=advisory"                    "$(logcol "$R" 3)" advisory
chk "H2 로그 layer=defaults"                      "$(logcol "$R" 4)" defaults

echo "── H3 known-NEGATIVE — 평범한 질의는 아무 출력도 없다 (과차단 방지) ──"
R="$T/r3"; mk_root "$R" 1
run "$R" "$(WS 'bash printf portability posix')"
chk "H3 일반 질의 → 무음"      "$(verdict)" none
chk "H3 exit 0"                "$RC" 0
chk "H3 로그 verdict=clean"    "$(logcol "$R" 3)" clean

echo "── H4 N/A — FH 체크아웃이 아니면 무음이고, 그 트리에 파일을 만들지 않는다 ──"
R="$T/r4"; rm -rf "$R"; mkdir -p "$R"
run "$R" "$(WS 'ZZOVERRIDETOKEN and ZZDEFAULTSTOKEN')"
chk "H4 defaults 부재 → 무음"          "$(verdict)" none
chk "H4 exit 0"                        "$RC" 0
chk "H4 남의 트리에 .claude 를 안 만든다" "$( [ -e "$R/.claude" ] && echo created || echo untouched )" untouched

echo "── H4b N/A + 트리에 .claude 가 이미 있어도 아무것도 쓰지 않는다 (codex #7 — 사용자 수준 훅은 모든 레포에서 돈다) ──"
R="$T/r4b"; rm -rf "$R"; mkdir -p "$R/.claude"
run "$R" "$(WS 'anything')"
chk "H4b defaults 부재 + .claude 존재 → 무음" "$(verdict)" none
chk "H4b 이벤트 파일을 만들지 않는다"          "$( [ -e "$R/.claude/.outbound_hook_events.tsv" ] && echo written || echo untouched )" untouched

echo "── H5 🟥 계기 불완전 = 미측정 = DENY (통과가 아니다) ──"
# 🟥 이 레인은 «판정»만이 아니라 «어느 가지가 냈는지»를 본다. 되돌림 프로브(2026-09-05)에서
#    PSA_BAD_ROWS 검사를 지웠는데 47/47 이 그대로 초록이었다 — 라이브러리 자신의 같은 검사가
#    rc=3 으로 잡아 «같은 deny» 를 냈기 때문이다. 판정만 보는 앵커는 그래서 장식이었다
#    ([[feedback_anchor_can_be_decorative]] · [[feedback_three_reasons_a_lane_is_green]]).
#    사유 문구를 박아야 가지가 갈린다.
reason(){ printf '%s' "$OUT" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("hookSpecificOutput",{}).get("permissionDecisionReason",""))
except Exception: print("")' 2>/dev/null; }
R="$T/r5"; mk_root "$R" 1 "$(printf 'HIGH_NO_TAB_ROW\nHIGH\tZZDEFAULTSTOKEN\n')"
run "$R" "$(WS 'a perfectly innocent question')"
chk "H5 패턴 형식오류 행 → deny"  "$(verdict)" deny
chk "H5 사유가 «형식오류 행» 가지" "$(reason | /usr/bin/grep -c '형식오류 행' || true)" 1
chk "H5 로그 verdict=deny"        "$(logcol "$R" 3)" deny
chk "H5 로그 layer=-(미측정)"      "$(logcol "$R" 4)" -

echo "── H5b 🟥 라이브러리가 «안 보는» 가지 — defaults 가 비었는데 override 는 있다 ──"
# psa_scan_tagged 는 PSA_STREAM 이 비었는지·BAD_ROWS 가 있는지는 보지만 **PSA_DEFAULTS_OK 는
# 안 본다**. override 만 실린 스트림은 비어 있지 않으므로 라이브러리는 그대로 «스캔»하고,
# 보편 패턴층이 통째로 빠진 결과를 «깨끗»으로 렌더한다 — 호출자만 막을 수 있는 fail-open 이다.
R="$T/r5b"; mk_root "$R" 1 "$(printf '# only a comment, no rows\n')"
run "$R" "$(WS 'a perfectly innocent question')"
chk "H5b defaults 공백 + override 존재 → deny" "$(verdict)" deny
chk "H5b 사유가 «공용 패턴층» 가지"             "$(reason | /usr/bin/grep -c '공용 패턴층' || true)" 1

echo '── H6 opt-out — (# noqa: outbound) 는 통과시키되 «로그를 남긴다» ──'
# 🟥 게임 가능한 채널이다. 그래서 보이지 않는 우회로가 되지 않도록 행이 남는다.
R="$T/r6"; mk_root "$R" 1
run "$R" "$(WS 'ZZOVERRIDETOKEN please # noqa: outbound')"
chk "H6 noqa → 무음 통과"      "$(verdict)" none
chk "H6 exit 0"                "$RC" 0
chk "H6 로그 verdict=noqa"     "$(logcol "$R" 3)" noqa

echo "── H6b CONTROL — 남의 트리에서는 noqa 규율이 «발동조차» 안 한다 ──"
# 🟥 순서가 하중이다. opt-out 이 적용성보다 «앞»에 있으면, FH 가 아닌 트리에서 noqa 질의가
#    로그를 쓰려다 실패하고 → fail-closed 규칙이 **남의 레포 호출을 막는다.** 과차단이다.
R="$T/r6b"; rm -rf "$R"; mkdir -p "$R"
run "$R" "$(WS 'anything # noqa: outbound')"
chk "H6b 비-FH 트리 + noqa → 무음"          "$(verdict)" none
chk "H6b exit 0"                             "$RC" 0
chk "H6b 그 트리에 .claude 를 안 만든다"     "$( [ -e "$R/.claude" ] && echo created || echo untouched )" untouched

echo "── H7 WebFetch — url 과 prompt 를 «둘 다» 본다 (prompt 쪽 토큰 적발) ──"
R="$T/r7"; mk_root "$R" 1
run "$R" "$(WF 'https://example.com/docs' 'summarize how ZZOVERRIDETOKEN is wired')"
chk "H7 WebFetch prompt 토큰 → deny" "$(verdict)" deny
chk "H7 로그 tool=WebFetch"          "$(logcol "$R" 2)" WebFetch

echo "── H7b WebFetch — url 쪽 토큰도 본다 ──"
R="$T/r7b"; mk_root "$R" 1
run "$R" "$(WF 'https://example.com/ZZOVERRIDETOKEN/x' 'summarize')"
chk "H7b WebFetch url 토큰 → deny" "$(verdict)" deny

echo "── H8 🟥 개행+탭 우회 — 토큰을 path 필드에 숨길 수 없다 ──"
R="$T/r8"; mk_root "$R" 1
run "$R" '{"session_id":"sessA","tool_name":"WebSearch","tool_input":{"query":"safe question\nZZOVERRIDETOKEN\tdecoy"}}'
chk "H8 개행+탭 뒤 토큰 → deny" "$(verdict)" deny

echo "── H9 CONTROL — 대상이 아닌 도구는 건드리지 않는다 (무음 · 로그도 없음) ──"
R="$T/r9"; mk_root "$R" 1
run "$R" '{"session_id":"sessA","tool_name":"Bash","tool_input":{"command":"echo ZZOVERRIDETOKEN"}}'
chk "H9 Bash → 무음"        "$(verdict)" none
chk "H9 Bash → 로그 0행"    "$(logcount "$R")" 0

echo "── H10 🟥 유출 금지 — 어떤 출력면에도 토큰 «값» 이 없다 ──"
# 이 레인이 이 훅의 존재 이유를 지킨다: 유출 가드가 유출 채널이 되면 안 된다.
R="$T/r10"; mk_root "$R" 1
run "$R" "$(WS 'leak ZZOVERRIDETOKEN and ZZDEFAULTSTOKEN together')"
ALL="$OUT
$(cat "$ERR" 2>/dev/null)
$(cat "$R/.claude/.outbound_hook_events.tsv" 2>/dev/null)"
chk "H10 stdout+stderr+로그에 override 토큰 없음" \
    "$(printf '%s' "$ALL" | /usr/bin/grep -c 'ZZOVERRIDETOKEN' || true)" 0
chk "H10 stdout+stderr+로그에 defaults 토큰 없음" \
    "$(printf '%s' "$ALL" | /usr/bin/grep -c 'ZZDEFAULTSTOKEN' || true)" 0
chk "H10 그래도 판정은 deny (침묵이 아니라 무해한 사유)" "$(verdict)" deny

echo "── H11 CONTROL — 스캐너 라이브러리가 없으면 DENY (미측정) ──"
R="$T/r11"; mk_root "$R" 1
run "$R" "$(WS 'harmless')" PSA_LIB_FILE="$T/does_not_exist.sh"
chk "H11 라이브러리 부재 → deny" "$(verdict)" deny

echo "── H12 소비자 install — override 층 부재: advisory 만, 그리고 UNCALIBRATED 1회 ──"
R="$T/r12"; mk_root "$R" 0
run "$R" "$(WS 'about ZZDEFAULTSTOKEN' sess1)"
chk "H12 override 부재 + defaults 히트 → advisory(deny 아님)" "$(verdict)" advisory
chk "H12 첫 호출에 UNCALIBRATED 고지" \
    "$(printf '%s' "$OUT" | /usr/bin/grep -c 'UNCALIBRATED' || true)" 1
run "$R" "$(WS 'about ZZDEFAULTSTOKEN again' sess1)"
chk "H12 같은 세션 2번째 → 고지 없음(세션당 1회)" \
    "$(printf '%s' "$OUT" | /usr/bin/grep -c 'UNCALIBRATED' || true)" 0
run "$R" "$(WS 'about ZZDEFAULTSTOKEN again' sess2)"
chk "H12 다른 세션 → 고지 다시" \
    "$(printf '%s' "$OUT" | /usr/bin/grep -c 'UNCALIBRATED' || true)" 1
chk "H12 로그 layer=defaults" "$(logcol "$R" 4)" defaults

echo "── H12b 소비자 install + 깨끗한 질의 → 완전 무음 (고지도 안 뜬다) ──"
# 🟥 고지를 히트에만 붙인다. 모든 WebSearch 에 붙이면 그게 소음이고, 소음은 훅을 끄게 만든다.
R="$T/r12b"; mk_root "$R" 0
run "$R" "$(WS 'bash printf portability' sess9)"
chk "H12b 소비자 + 깨끗 → 무음" "$(verdict)" none
chk "H12b 로그 verdict=clean"   "$(logcol "$R" 3)" clean

echo "── H13 DEGRADE — 파싱 불가 payload 는 무음 통과 (죽은 해석기가 도구를 막지 않는다) ──"
R="$T/r13"; mk_root "$R" 1
run "$R" 'this is not json at all {{{'
chk "H13 비-JSON → 무음" "$(verdict)" none
chk "H13 exit 0"         "$RC" 0

echo "── H14 주입점 — PSA_DEFAULTS_FILE / PSA_OVERRIDE_FILE 가 실제로 먹는다 ──"
R="$T/r14"; rm -rf "$R"; mkdir -p "$R/.claude"
printf 'HIGH\tZZINJECTED\n' > "$T/inj_def"
printf 'HIGH\tZZINJOVR\n'   > "$T/inj_ovr"
run "$R" "$(WS 'contains ZZINJOVR here')" PSA_DEFAULTS_FILE="$T/inj_def" PSA_OVERRIDE_FILE="$T/inj_ovr"
chk "H14 주입된 override 토큰 → deny" "$(verdict)" deny

echo "── H15 CONTROL — 빈 질의는 막지 않는다 ──"
R="$T/r15"; mk_root "$R" 1
run "$R" '{"session_id":"sessA","tool_name":"WebSearch","tool_input":{"query":"   "}}'
chk "H15 빈 질의 → 무음" "$(verdict)" none
chk "H15 exit 0"         "$RC" 0

echo "── H16 🟥 미지의 tool_input 키 형태에서도 스캔한다 (문서 미기재 = 하드코딩 금지) ──"
# 공식 hooks 문서는 WebSearch/WebFetch 의 tool_input 키 이름을 «명시하지 않는다»(2026-09-05 확인).
# 키 이름을 박으면 스키마가 바뀌는 순간 조용히 fail-OPEN 한다 — 그래서 «모든 문자열 값»을 본다.
R="$T/r16"; mk_root "$R" 1
run "$R" '{"session_id":"sessA","tool_name":"WebSearch","tool_input":{"q":"ZZOVERRIDETOKEN","opts":{"deep":["also ZZOVERRIDETOKEN"]}}}'
chk "H16 미지 키 안의 토큰 → deny" "$(verdict)" deny

echo "── H17 CONTROL — deny 사유가 «비어 있지 않다» (침묵 deny 금지) ──"
R="$T/r17"; mk_root "$R" 1
run "$R" "$(WS 'ZZOVERRIDETOKEN')"
chk "H17 permissionDecisionReason 비어있지 않음" \
    "$(printf '%s' "$OUT" | python3 -c 'import json,sys;
try:
    d=json.load(sys.stdin); r=d.get("hookSpecificOutput",{}).get("permissionDecisionReason","")
    print("nonempty" if isinstance(r,str) and len(r.strip())>10 else "empty")
except Exception: print("unparseable")' 2>/dev/null)" nonempty
chk "H17 hookEventName 이 PreToolUse" \
    "$(printf '%s' "$OUT" | python3 -c 'import json,sys;
try: print(json.load(sys.stdin).get("hookSpecificOutput",{}).get("hookEventName",""))
except Exception: print("unparseable")' 2>/dev/null)" PreToolUse

echo "── H18 🟥 렌더 못 한 DENY 는 무음 통과가 되면 안 된다 (fail-closed 2차 채널) ──"
# degrade_direction_scan S1 이 `_emit` 의 `|| true` 를 지목했고 **진짜였다**: JSON 을 못 만들면
# 출력이 비고, 이 훅에서 «출력 없음» 은 곧 ALLOW 다. OQH_PY 로 렌더러만 죽여 그 가지에 도달한다
# (파싱은 진짜 python3 로 그대로 돈다 — 변수는 하나다).
R="$T/r18"; mk_root "$R" 1
run "$R" "$(WS 'ZZOVERRIDETOKEN')" OQH_PY="$T/not_an_interpreter"
chk "H18 렌더 실패 → exit 2 (차단)"        "$RC" 2
chk "H18 사유가 stderr 로 나간다"          "$( [ -s "$ERR" ] && echo nonempty || echo empty )" nonempty
chk "H18 stdout 은 비어 있다(허용 아님)"   "$(verdict)" none
chk "H18 🟥 그 stderr 에도 토큰 값은 없다" \
    "$(/usr/bin/grep -c 'ZZOVERRIDETOKEN' "$ERR" || true)" 0

echo "── H18b CONTROL — 같은 렌더 실패라도 ADVISORY 는 막지 않는다 (잃은 것은 경고뿐) ──"
R="$T/r18b"; mk_root "$R" 1
run "$R" "$(WS 'ZZDEFAULTSTOKEN')" OQH_PY="$T/not_an_interpreter"
chk "H18b advisory 렌더 실패 → exit 0" "$RC" 0
chk "H18b 로그는 advisory 로 남는다"    "$(logcol "$R" 3)" advisory

echo "── H19 🟥 기록 못 하는 opt-out 은 통과시키지 않는다 ──"
# noqa 의 정당성은 «행이 남는다» 하나뿐이다. 못 남기면 보이지 않는 우회가 된다.
R="$T/r19"; mk_root "$R" 1
chmod 500 "$R/.claude"
run "$R" "$(WS 'ZZOVERRIDETOKEN # noqa: outbound')"
chmod 700 "$R/.claude"
chk "H19 로그 불가 + noqa → deny"     "$(verdict)" deny
chk "H19 사유가 «기록» 가지"          "$(reason | /usr/bin/grep -c '기록 못 하는 우회' || true)" 1

echo "── H19b CONTROL — 쓸 수 있으면 같은 질의가 통과한다 (H19 가 chmod 때문만은 아니다) ──"
R="$T/r19b"; mk_root "$R" 1
run "$R" "$(WS 'ZZOVERRIDETOKEN # noqa: outbound')"
chk "H19b 로그 가능 + noqa → 무음 통과" "$(verdict)" none
chk "H19b 로그 verdict=noqa"            "$(logcol "$R" 3)" noqa

echo "── H20 🟥 session_id 가 없어도 필드가 밀리지 않는다 (IFS 접힘 회귀 앵커) ──"
# `IFS=$'"'"'\t'"'"' read` 였다면 빈 session_id 에서 KEYS 가 SESS 자리로 밀려 로그 5번째 칼럼이
# 비고 판정 입력이 통째로 어긋난다 ([[feedback_ifs_read_collapses_empty_fields]]).
R="$T/r20"; mk_root "$R" 1
run "$R" '{"tool_name":"WebSearch","tool_input":{"query":"ZZOVERRIDETOKEN"}}'
chk "H20 session_id 부재 → 여전히 deny" "$(verdict)" deny
chk "H20 KEYS 칼럼이 제자리(query)"      "$(logcol "$R" 5)" query
chk "H20 tool 칼럼이 제자리"             "$(logcol "$R" 2)" WebSearch

echo "── H21 CONTROL — 필드가 3탭이 아니면 무음 (조립 실패를 판정으로 읽지 않는다) ──"
R="$T/r21"; mk_root "$R" 1
run "$R" '{"tool_name":"WebSearch","tool_input":{"query":"ZZOVERRIDETOKEN"}}' OQH_PY=python3
chk "H21 정상 payload 는 여전히 deny (컨트롤이 살아 있다)" "$(verdict)" deny

echo "── H22 🟥 심각도 «라벨» 도 운영자가 쓴 텍스트다 — 그대로 내보내지 않는다 ──"
# 패턴 파일 1열은 관례가 HIGH/MED/LOW 일 뿐 강제되지 않는다. 사유 문구에 그 열을 그대로 실으면
# 토큰 값은 안 나가도 «라벨» 로 내부 낱말이 새어나갈 수 있다. 평범한 ASCII 대문자 1~8자가
# 아니면 `?` 로 렌더한다. 되돌림 프로브 M13 이 이 레인 없이 초록이었다 — 그래서 생겼다.
R="$T/r22"; rm -rf "$R"; mkdir -p "$R/.claude/rules"
printf 'HIGH\tZZDEFAULTSTOKEN\n' > "$R/.claude/rules/.public-surface-patterns.defaults"
printf 'ZZ_SEC1\tZZOVERRIDETOKEN\n' > "$R/.claude/rules/.public-surface-patterns"
run "$R" "$(WS 'ZZOVERRIDETOKEN')"
chk "H22 이상한 라벨 → deny 는 그대로"   "$(verdict)" deny
chk "H22 라벨이 사유에 안 실린다"        "$(reason | /usr/bin/grep -c 'ZZ_SEC1' || true)" 0
chk "H22 대신 ? 로 렌더된다"             "$(reason | /usr/bin/grep -c '? x1' || true)" 1

echo "── H22b CONTROL — 정상 라벨은 그대로 보인다 (H22 가 «전부 ?» 라서 통과한 게 아니다) ──"
R="$T/r22b"; mk_root "$R" 1
run "$R" "$(WS 'ZZOVERRIDETOKEN')"
chk "H22b HIGH 라벨은 사유에 그대로" "$(reason | /usr/bin/grep -c 'HIGH x1' || true)" 1

echo "── H22c 전부-글자 라벨도 enum(HIGH/MED/LOW) 밖이면 ? (codex #5 — «8자 이하 글자» 규칙으로는 내부 낱말이 샌다) ──"
R="$T/r22c"; rm -rf "$R"; mkdir -p "$R/.claude/rules"
printf 'HIGH\tZZDEFAULTSTOKEN\n' > "$R/.claude/rules/.public-surface-patterns.defaults"
printf 'ACMEKEY\tZZOVERRIDETOKEN\n' > "$R/.claude/rules/.public-surface-patterns"
run "$R" "$(WS 'ZZOVERRIDETOKEN')"
chk "H22c ACMEKEY 라벨 → deny 그대로"   "$(verdict)" deny
chk "H22c 라벨이 사유에 안 실린다"       "$(reason | /usr/bin/grep -c 'ACMEKEY' || true)" 0
chk "H22c ? 로 렌더"                     "$(reason | /usr/bin/grep -c '? x1' || true)" 1

echo "── H23 🟥 «패딩으로 우회» 금지 — 긴 질의가 훅을 죽여서 통과하면 안 된다 ──"
# 실측 2026-09-05: 필드 개수 검증을 `${_META//[!\t]/}` 로 하던 초판은 bash 3.2 에서 10,000자에
# **47.7초**가 걸렸다(라이브러리는 같은 크기를 0.15초에 처리한다 — 비용은 가드였다).
# settings 의 `"timeout": 5` 에 걸려 훅이 **죽고**, 죽은 PreToolUse 훅은 non-blocking error 라
# **도구가 그대로 실행된다** — override 도 필요 없고 로그도 안 남는 우회다. 시간 상한을 박는다.
# 🟥 The lane runs the hook under the SAME timeout the shipped snippet configures — a lane that
#    allowed 15s while production kills at 5s would pass a hook that production lets through
#    (codex finding 10, 2026-09-05). The value is READ from the snippet, and H23c pins it.
SNIP_TO="$(python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
for h in d["project_settings_json"]["hooks"]["PreToolUse"]:
    if h.get("matcher")=="WebSearch|WebFetch": print(h["hooks"][0]["timeout"]); break' "$FH/templates/settings.PreToolUse.snippet.json" 2>/dev/null)"
chk "H23c 스니펫의 이 훅 timeout 을 읽었다(레인은 그 값으로 잰다)" "$SNIP_TO" 5
[ -n "$SNIP_TO" ] || SNIP_TO=5
LONG="$(python3 -c 'print("lorem ipsum dolor sit amet "*800)')"
mkjson(){ python3 -c 'import json,sys; print(json.dumps({"session_id":"sX","tool_name":"WebSearch","tool_input":{"query":sys.argv[1]}}))' "$1"; }
R="$T/r23"; mk_root "$R" 1
t0=$(date +%s)
OUT="$(mkjson "$LONG" | env CLAUDE_PROJECT_DIR="$R" timeout "$SNIP_TO" bash "$H" 2>"$T/err23")"; RC=$?
t1=$(date +%s)
chk "H23 21KB 깨끗한 질의 → 스니펫 timeout(${SNIP_TO}s) 안에 끝난다(죽지 않음)" "$( [ "$RC" -ne 124 ] && echo alive || echo KILLED )" alive
chk "H23 그리고 판정은 clean(무음)"                        "$(verdict)" none
chk "H23 로그 verdict=clean"                               "$(logcol "$R" 3)" clean
echo "     (측정: $((t1-t0))초)"

echo "── H23b CONTROL — 길다고 스캔을 건너뛰지 않는다 (패딩 뒤의 토큰도 잡는다) ──"
R="$T/r23b"; mk_root "$R" 1
OUT="$(mkjson "$LONG ZZOVERRIDETOKEN" | env CLAUDE_PROJECT_DIR="$R" timeout "$SNIP_TO" bash "$H" 2>"$T/err23b")"; RC=$?
chk "H23b 21KB 패딩 + 토큰 → deny"      "$(verdict)" deny
chk "H23b 죽어서 통과한 게 아니다"       "$( [ "$RC" -ne 124 ] && echo alive || echo KILLED )" alive

echo "── H24 같은 토큰이 두 층에 다 있어도 deny — 계수 비교가 dedup 에 안 무너진다 (codex #11 을 실측으로 반증하고 고정) ──"
R="$T/r24"; rm -rf "$R"; mkdir -p "$R/.claude/rules"
printf 'HIGH\tZZSAMETOKEN\n' > "$R/.claude/rules/.public-surface-patterns.defaults"
printf 'HIGH\tZZSAMETOKEN\n' > "$R/.claude/rules/.public-surface-patterns"
run "$R" "$(WS 'hello ZZSAMETOKEN')"
chk "H24 양층 동일 토큰 → deny"  "$(verdict)" deny
chk "H24 로그 layer=override"     "$(logcol "$R" 4)" override

echo "── H25 tool_input 이 객체가 아니라 문자열이어도 스캔한다 (codex #1) ──"
R="$T/r25"; mk_root "$R" 1
run "$R" '{"tool_name":"WebSearch","tool_input":"ZZOVERRIDETOKEN"}'
chk "H25 문자열 tool_input 의 토큰 → deny" "$(verdict)" deny

echo "── H26 깊이 8 초과 = «못 봤다» = deny (codex #2) · CONTROL 깊이 3 은 정상 판정 ──"
R="$T/r26"; mk_root "$R" 1
run "$R" '{"tool_name":"WebSearch","tool_input":{"a":{"b":{"c":{"d":{"e":{"f":{"g":{"h":{"i":{"j":"ZZOVERRIDETOKEN"}}}}}}}}}}}'
chk "H26 깊이 10 토큰 → deny"                          "$(verdict)" deny
chk "H26 사유 = 추출 한계(미측정)"                      "$(reason | /usr/bin/grep -c '추출 한계' || true)" 1
run "$R" '{"tool_name":"WebSearch","tool_input":{"a":{"b":{"query":"ZZOVERRIDETOKEN"}}}}'
chk "H26 CONTROL 깊이 3 토큰 → deny(override 층)"       "$(logcol "$R" 4)" override
run "$R" '{"tool_name":"WebSearch","tool_input":{"a":{"b":{"c":{"d":{"e":{"f":{"g":{"h":{"i":{"j":"clean"}}}}}}}}}}}'
chk "H26 깊이 10 «깨끗한» 값도 deny — 못 본 것은 깨끗한 것이 아니다" "$(verdict)" deny

echo "── H27 값 4096 개 초과 → deny (codex #3) · CONTROL 101 개는 정상 ──"
R="$T/r27"; mk_root "$R" 1
MANY="$(python3 -c 'import json; print(json.dumps({"tool_name":"WebSearch","tool_input":{"query":["x"]*4100+["ZZOVERRIDETOKEN"]}}))')"
run "$R" "$MANY"
chk "H27 4101 값, 토큰이 맨 뒤 → deny"   "$(verdict)" deny
chk "H27 사유 = 추출 한계"                "$(reason | /usr/bin/grep -c '추출 한계' || true)" 1
FEW="$(python3 -c 'import json; print(json.dumps({"tool_name":"WebSearch","tool_input":{"query":["x"]*100+["fine"]}}))')"
run "$R" "$FEW"
chk "H27 CONTROL 101 값 깨끗 → 무음"      "$(verdict)" none

echo "── H28 키 이름도 스캔하고, 로그에는 원문 키를 안 남긴다 (codex #4) ──"
R="$T/r28"; mk_root "$R" 1
run "$R" '{"tool_name":"WebSearch","tool_input":{"ZZOVERRIDETOKEN":"benign"}}'
chk "H28 토큰이 키 자리 → deny"                "$(verdict)" deny
chk "H28 로그 행에 토큰 없음"                   "$(logrow "$R" | /usr/bin/grep -c 'ZZOVERRIDETOKEN' || true)" 0
chk "H28 로그 5열은 other"                      "$(logcol "$R" 5)" other
run "$R" '{"tool_name":"WebSearch","tool_input":{"query":"fine","extra_key":"fine"}}'
chk "H28 CONTROL 아는 키는 이름 그대로 · 모르는 키는 other" "$(logcol "$R" 5)" other,query

echo "── H30 tr 없는 PATH 에서도 판정이 산다 (codex #6) — 빈 값 판정이 외부 명령에 안 기댄다 ──"
SHADOW_NOTR="$T/shadow_notr"; mkdir -p "$SHADOW_NOTR"
IFS=':' read -r -a _pdirs <<< "$PATH"
for _d in "${_pdirs[@]}"; do
  [ -d "$_d" ] || continue
  for _f in "$_d"/*; do
    [ -x "$_f" ] && [ ! -d "$_f" ] || continue
    _b="${_f##*/}"; [ "$_b" = tr ] && continue
    [ -e "$SHADOW_NOTR/$_b" ] || ln -s "$_f" "$SHADOW_NOTR/$_b"
  done
done
if PATH="$SHADOW_NOTR" command -v tr >/dev/null 2>&1; then
  chk "H30-FIXTURE shadow PATH 에서 tr 이 숨었다" visible hidden
else
  R="$T/r30"; mk_root "$R" 1
  run "$R" "$(WS 'ZZOVERRIDETOKEN')" PATH="$SHADOW_NOTR"
  chk "H30 tr 부재 + 토큰 → deny (clean 으로 안 접힌다)" "$(verdict)" deny
  # 🟥 control shape = an EMPTY tool_input — not a whitespace query. Key names are scanned too
  #    (H28), so a WebSearch call with a `query` key is never an empty scan text; the emptiness path
  #    is reachable only when there is nothing at all to scan.
  run "$R" '{"tool_name":"WebSearch","tool_input":{}}' PATH="$SHADOW_NOTR"
  chk "H30 CONTROL tr 부재 + 빈 tool_input → 무음(clean, 라이브러리를 안 거친다)" "$(verdict)" none
  chk "H30 CONTROL 로그 verdict=clean"                     "$(logcol "$R" 3)" clean
fi

echo
if [ "$FAIL" -eq 0 ]; then echo "════ outbound-query-hook lanes: $PASS passed · 0 failed ════"; exit 0
else echo "🟥 outbound-query-hook lanes: $FAIL 실패 / $((PASS+FAIL))"; exit 1; fi
