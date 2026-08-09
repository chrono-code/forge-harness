#!/usr/bin/env bash
# hook_source_lib.sh — SessionStart 의 `source` 를 읽는 **단일 소스**.
#
# WHY: `/clear` 는 SessionStart 를 재발동시키고 `source: "clear"` 를 준다(startup·resume·compact·
# fork 와 구분되는 별개 값, 공식 hooks 문서). 그런데 FH 훅들은 stdin 페이로드를 안 읽어서 진짜
# 시작과 구분하지 못했고, 결과적으로 **캐던스 나그가 /clear 마다 재발화**했다(2026-08-09 운영자 지적).
#
# WHY A LIB: 파서를 두 스크립트에 복붙하면 한쪽만 고쳐지는 순간 같은 입력이 서로 다르게 분류된다
# — 이 레포가 이미 이름 붙인 «관대함 갈린 중복 정규화» 다. 여섯 줄이라도 단일 소스로 둔다.
#
# 판별 기준(호출부가 지켜야 하는 것): 「세션이 잃어버린 상태」는 다시 보여주고,
# 「사람이 이미 보고 결정한 나그」는 안 보여준다. freshness/state = 항상, cadence = startup 계열만.
#
# DEGRADE: source 를 못 읽으면 `unknown` 이고, unknown 은 **보여주는 쪽**이다.
# 중복 알림은 눈에 보이는 소음이지만 놓친 캐던스는 무음 누락이고, 이 레포는 무음 누락을 더 나쁘게
# 친다. `unknown` 을 조용히 `clear` 로 접는 것이 정확히 그 결함이다(not-found ≠ zero).
#
# 이식성: `timeout` 을 쓰지 않는다 — GNU coreutils 이고 stock macOS 에 없다(같은 날 selfcheck.sh
# 에서 실측으로 물린 defect). `head`/`sed` 만 쓴다.

# fh_hook_source — stdout 에 source 를 한 단어로 출력한다.
fh_hook_source() {
  # TTY = 사람이 손으로 돌린 것. 페이로드가 없으니 읽으려 하면 매달린다.
  if [ -t 0 ]; then printf 'unknown\n'; return 0; fi
  local _p _s
  _p="$(head -c 65536 2>/dev/null || true)"
  _s="$(printf '%s' "$_p" \
        | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([A-Za-z_]*\)".*/\1/p' \
        | head -1)"
  [ -n "$_s" ] || _s="unknown"
  printf '%s\n' "$_s"
}

# fh_cadence_due — 캐던스 나그를 띄워도 되는 source 인가. 0=띄운다 / 1=억제.
# 억제 대상은 «같은 세션의 연속»인 두 값뿐이다. resume 은 며칠 뒤일 수 있으므로 띄운다.
fh_cadence_due() {
  case "${1:-unknown}" in
    clear|compact) return 1 ;;
    *)             return 0 ;;
  esac
}
