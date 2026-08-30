#!/usr/bin/env bash
# launchd_wiring_check.sh — 「주기 실행이 실제로 배선됐나」를 typed 로 답한다.
#
# ── 왜 (진단) ──
#   `scripts/com.forge-harness.frontier-digest.plist` 는 **템플릿**이다 — 안에 `/path/to/...`
#   플레이스홀더가 있고 «설치 전에 네 절대경로로 바꿔라» 고 주석이 적혀 있다.
#   `script_caller_ratchet.sh:523-526` 도 그 사실을 기록해뒀다(추적본=템플릿, 실물=`~/Library/LaunchAgents`).
#   🟥 **그런데 «바꿨는지»도 «걸렸는지»도 보는 것이 0개였다.** 그래서 소비자는 digest 주기 실행이
#   있다고 믿으면서 한 번도 안 도는 상태로 지낼 수 있고, 그 부재는 **아무 신호도 안 낸다.**
#   `external-grounding` 엔진이 🟡 인 두 다리 중 하나가 정확히 이것이다.
#
# ── 이 스크립트가 하는 것과 «안» 하는 것 ──
#   check   설치 상태를 **typed verdict** 로 낸다. 부재를 「정상」으로 렌더하지 않는다
#   render  템플릿에 실제 경로를 채워 **stdout 으로 인쇄한다**
#   🟥 **설치는 안 한다.** `launchctl` 을 부르지 않고 `~/Library/LaunchAgents` 에 쓰지 않는다.
#      2026-08-29 에 sim 팔 하나가 요청 없이 launchd 에이전트를 등록한 사고가 있었다
#      (`[[feedback_sim_with_write_tools_is_a_fleet]]`). 주기 실행 등록은 **운영자 머신의 영속
#      설정 변경**이고, 그건 사람이 눈으로 보고 하는 것이다. 이 스크립트는 «채워서 보여줄» 뿐이다.
#
# ── verdict (닫힌 enum — 부재를 0 으로 접지 않는다) ──
#   NOT_APPLICABLE        launchd 가 없는 OS. 「안 걸림」이 아니라 「해당 없음」이다
#   TEMPLATE_ONLY         설치본 없음. 정직한 기본값이고 **결함 아님** — 다만 digest 는 안 돈다
#   INSTALLED_PLACEHOLDER 설치는 됐는데 `/path/to/` 가 남아 있다 🟥 이게 이 검사가 존재하는 이유
#   INSTALLED_BROKEN      경로는 치환됐는데 **가리키는 스크립트가 없다**
#   INSTALLED_OK          설치됐고 대상이 실재한다
#   UNKNOWN               읽을 수 없었다. 🟥 UNKNOWN 을 TEMPLATE_ONLY 로 접지 마라
#
# ── 사용 ──
#   bash scripts/launchd_wiring_check.sh check
#   bash scripts/launchd_wiring_check.sh render [<label>]   # 채운 plist 를 인쇄(설치 안 함)
#                                                          기본 = frontier-digest
#   bash scripts/launchd_wiring_check.sh --self-test
#   FH_LAUNCHD_DIR=<dir> 로 검사 대상 디렉터리를 바꾼다(테스트용)
#
# ⚠️ **범위: 라벨 하나다.** `com.forge-harness.frontier-digest` 만 본다. 같은 디렉터리에
#    `com.forge-harness.satellite-*` · `star-traffic` 등 다른 라벨이 걸려 있어도 **안 센다**
#    (실측 2026-08-30, 이 머신에 4개 더 있었다). 그것들을 「검사됨」으로 읽지 마라 — 미측정이다.
#    라벨을 늘리려면 이 상수를 배열로 바꾸고 레인을 같이 늘려야 한다.

set -uo pipefail
FH="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# 🟥 2026-08-30: 라벨 «둘» 로 확장. 초판은 하나만 보면서 그 사실을 범위로만 적어뒀는데,
#    바로 그 미측정 칸에서 실제 결함이 나왔다 — daily-report 가 로컬 바인딩엔 「설치됨」인데
#    plist 도 스크립트도 없었다. 범위를 적는 것과 재는 것은 다르다.
LABELS="com.forge-harness.frontier-digest com.forge-harness.daily-report"
TEMPLATE="$FH/scripts/com.forge-harness.frontier-digest.plist"
LABEL="com.forge-harness.frontier-digest"
LAUNCHD_DIR="${FH_LAUNCHD_DIR:-$HOME/Library/LaunchAgents}"
PLACEHOLDER_RE='/path/to/'

# ─────────────────────────────────────────────────────────────────────
# classify — 순수 함수. 파일 경로만 받고 부작용 없다. 이 분리가 self-test 를 가능하게 한다.
#   $1 = 설치본 경로(없어도 된다) · $2 = launchd 존재 여부(1/0)
# ─────────────────────────────────────────────────────────────────────
classify() {
  local installed="$1" has_launchd="$2"
  [ "$has_launchd" = "1" ] || { echo NOT_APPLICABLE; return 0; }
  [ -n "$installed" ] && [ -f "$installed" ] || { echo TEMPLATE_ONLY; return 0; }
  local body
  body="$(cat "$installed" 2>/dev/null)" || { echo UNKNOWN; return 0; }
  [ -n "$body" ] || { echo UNKNOWN; return 0; }
  case "$body" in *"$PLACEHOLDER_RE"*) echo INSTALLED_PLACEHOLDER; return 0 ;; esac
  # 치환은 됐다 — 가리키는 대상이 실재하나. plist 안의 절대경로 .sh 를 뽑아 확인한다.
  local sh missing=0 seen=0
  while IFS= read -r sh; do
    [ -n "$sh" ] || continue
    seen=$((seen+1))
    [ -f "$sh" ] || missing=1
  done < <(printf '%s\n' "$body" | sed -n 's|.*<string>\(/[^<]*\.sh\)</string>.*|\1|p')
  if [ "$seen" -eq 0 ]; then echo UNKNOWN; return 0; fi   # .sh 를 못 찾음 = 판정 불가
  [ "$missing" -eq 1 ] && echo INSTALLED_BROKEN || echo INSTALLED_OK
}

do_render() {
  [ -f "$TEMPLATE" ] || { echo "❌ 템플릿 부재: $TEMPLATE" >&2; return 10; }
  # 🟥 안내 «주석»도 치환 대상이다 — 2026-08-30 자기검사 L9 가 잡았다.
  #    그 주석에 '/path/to/...' 라는 문자열이 들어 있어서, 경로를 다 채운 뒤에도 파일 안에
  #    플레이스홀더 토큰이 남는다. 그러면 `classify` 가 **올바르게 설치한 사람을 영구히
  #    INSTALLED_PLACEHOLDER 로 찍는다** — 검사기가 거짓 경보 생성기가 되는 왕복 결함이다.
  #    레인이 없었으면 그대로 나갔고, 소비자는 이 검사를 믿지 않게 됐을 것이다.
  sed -e "s|<!-- Replace every /path/to/.* -->|<!-- rendered by scripts/launchd_wiring_check.sh render -->|" \
      -e "s|/path/to/forge-harness|$FH|g" \
      -e "s|/path/to/home|$HOME|g" "$TEMPLATE"
}

do_check_one() {
  LABEL="$1"
  TEMPLATE="$FH/scripts/$LABEL.plist"
  local has_launchd=0
  case "$(uname -s 2>/dev/null)" in Darwin) has_launchd=1 ;; esac
  local installed="$LAUNCHD_DIR/$LABEL.plist"
  [ -f "$installed" ] || installed=""
  local v; v="$(classify "$installed" "$has_launchd")"
  echo "── $LABEL"
  echo "verdict: $v"
  case "$v" in
    NOT_APPLICABLE)        echo "  launchd 가 없는 OS 다. 「안 걸림」이 아니라 «해당 없음»이다." ;;
    TEMPLATE_ONLY)         echo "  설치본이 없다 — 결함은 아니지만 **이 잡은 안 돈다.**"
                           echo "  걸려면:  bash scripts/launchd_wiring_check.sh render > ~/Library/LaunchAgents/$LABEL.plist"
                           echo "           launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/$LABEL.plist"
                           echo "  🟥 이 스크립트는 그 두 줄을 **대신 실행하지 않는다**(운영자 머신의 영속 설정)." ;;
    INSTALLED_PLACEHOLDER) echo "  🟥 설치본에 '/path/to/' 가 남아 있다 — **걸려 있는데 안 돈다.**"
                           echo "  가장 조용한 실패다: launchd 는 등록돼 보이고 로그는 비어 있다." ;;
    INSTALLED_BROKEN)      echo "  🟥 경로는 치환됐는데 가리키는 스크립트가 실재하지 않는다." ;;
    INSTALLED_OK)          echo "  ✅ 설치됨 · 대상 실재. (실제로 «돌았나»는 이 검사의 범위 밖이다 —"
                           echo "     그건 tracks/_meta/frontier_digest_*.md 의 존재로 본다.)" ;;
    UNKNOWN)               echo "  🟥 읽을 수 없었다. UNKNOWN 을 TEMPLATE_ONLY 로 접지 마라." ;;
  esac
  case "$v" in INSTALLED_PLACEHOLDER|INSTALLED_BROKEN) return 1 ;; *) return 0 ;; esac
}

do_check() {
  local rc=0 l
  for l in $LABELS; do
    do_check_one "$l" || rc=1
    echo
  done
  return "$rc"
}

do_self_test() {
  local T; T="$(mktemp -d)" || return 10
  local P=0 F=0
  chk(){ if [ "$2" = "$3" ]; then P=$((P+1)); echo "  ✅ $1"; else F=$((F+1)); echo "  ❌ $1 (got=$2 want=$3)"; fi; }

  chk "L1 launchd 없는 OS → NOT_APPLICABLE (부재가 아니다)" "$(classify "" 0)" NOT_APPLICABLE
  chk "L2 설치본 없음 → TEMPLATE_ONLY" "$(classify "" 1)" TEMPLATE_ONLY
  chk "L3 없는 경로를 줘도 TEMPLATE_ONLY" "$(classify "$T/nope.plist" 1)" TEMPLATE_ONLY

  # known-POSITIVE — 이 검사가 존재하는 이유. 플레이스홀더가 남은 설치본.
  printf '<plist><string>/path/to/forge-harness/scripts/x.sh</string></plist>\n' > "$T/ph.plist"
  chk "L4 '/path/to/' 잔존 → INSTALLED_PLACEHOLDER (핵심 케이스)" \
      "$(classify "$T/ph.plist" 1)" INSTALLED_PLACEHOLDER

  # known-NEGATIVE — 치환됐고 대상이 실재하면 통과해야 한다. 없으면 「항상 PLACEHOLDER」와 구분 안 됨
  printf '#!/bin/sh\n' > "$T/real.sh"
  printf '<plist><string>%s/real.sh</string></plist>\n' "$T" > "$T/ok.plist"
  chk "L5 치환됨 ∧ 대상 실재 → INSTALLED_OK (판별력 컨트롤)" \
      "$(classify "$T/ok.plist" 1)" INSTALLED_OK

  # 치환은 됐는데 대상이 없다 — PLACEHOLDER 와 «다른» 실패다. 접지 않는다.
  printf '<plist><string>%s/gone.sh</string></plist>\n' "$T" > "$T/broken.plist"
  chk "L6 치환됨 ∧ 대상 부재 → INSTALLED_BROKEN (PLACEHOLDER 와 다른 값)" \
      "$(classify "$T/broken.plist" 1)" INSTALLED_BROKEN

  : > "$T/empty.plist"
  chk "L7 빈 파일 → UNKNOWN (TEMPLATE_ONLY 로 접지 않는다)" \
      "$(classify "$T/empty.plist" 1)" UNKNOWN

  printf '<plist><string>no-shell-path-here</string></plist>\n' > "$T/nosh.plist"
  chk "L8 .sh 를 못 찾음 → UNKNOWN (「대상 0개니까 OK」가 아니다)" \
      "$(classify "$T/nosh.plist" 1)" UNKNOWN

  # 🟥 render 가 실제로 플레이스홀더를 없애나 — 안 그러면 위 판정 전부가 무의미하다
  if [ -f "$TEMPLATE" ]; then
    local r; r="$(do_render 2>/dev/null)"
    case "$r" in
      *"/path/to/"*) chk "L9 render 결과에 '/path/to/' 없음" "잔존" "없음" ;;
      "")            chk "L9 render 결과에 '/path/to/' 없음" "빈출력" "없음" ;;
      *)             chk "L9 render 결과에 '/path/to/' 없음" "없음" "없음" ;;
    esac
    # 컨트롤: 템플릿 «원본»에는 반드시 있어야 한다. 없으면 L9 는 아무것도 증명 못 한다.
    if grep -q '/path/to/' "$TEMPLATE"; then
      chk "L9-CTRL 템플릿 원본엔 '/path/to/' 가 있다(L9 가 뭔가를 재는 증거)" 있음 있음
    else
      chk "L9-CTRL 템플릿 원본엔 '/path/to/' 가 있다(L9 가 뭔가를 재는 증거)" 없음 있음
    fi
  fi

  rm -rf "$T"
  echo; echo "SELFTEST: $P passed, $F failed"
  [ "$F" = 0 ] || return 1
  return 0
}

case "${1:-check}" in
  check)       do_check ;;
  render)      LABEL="${2:-com.forge-harness.frontier-digest}"
               TEMPLATE="$FH/scripts/$LABEL.plist"; do_render ;;
  --self-test) do_self_test ;;
  *) echo "usage: launchd_wiring_check.sh [check|render|--self-test]" >&2; exit 2 ;;
esac
