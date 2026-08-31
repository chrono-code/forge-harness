#!/usr/bin/env bash
# 대상 고정 — «내가 지금 재는 파일이 상대가 말한 그 파일인가».
# 🟥 2026-09-01 에 같은 얼굴로 3회 났다: ⓐ 낡은 qset 에 게이트 → 거짓 «선통과»
#    ⓑ 도는 중인 작업을 채점 → 「빈 출력」 오보  ⓒ task-completed 알림을 완료로 읽음.
#    셋 다 출력이 «정상 형식»이라 안 걸렸다. N=3 ⇒ 산문이 아니라 코드다.
# 사용: bash target_pin.sh <파일> <기대 sha256 접두(8자+)>   → 0=일치 · 1=불일치 · 2=인자오류
set -uo pipefail
F="${1:-}"; WANT="${2:-}"
[ -n "$F" ] && [ -n "$WANT" ] || { echo "usage: target_pin.sh <file> <sha256-prefix>" >&2; exit 2; }
case "${#WANT}" in [0-7]) echo "🟥 접두가 너무 짧다(${#WANT}자) — 8자 이상" >&2; exit 2 ;; esac
if [ ! -f "$F" ]; then
  echo "🟥 PIN FAIL — 파일이 없다: $F" >&2
  echo "   🟥 «없음»은 «비었음»도 «옛것»도 아니다. 상대에게 경로를 다시 받아라" >&2
  exit 1
fi
GOT=$(shasum -a 256 "$F" | cut -d' ' -f1)
case "$GOT" in
  "$WANT"*) printf '🟢 PIN OK   %s\n   sha256=%s  mtime=%s\n' "$F" "${GOT:0:16}" "$(stat -f '%Sm' "$F")"; exit 0 ;;
  *) { printf '🟥 PIN FAIL — 내가 든 파일이 그 파일이 아니다\n'
       printf '   파일 : %s\n   기대 : %s…\n   실제 : %s\n   mtime: %s\n' "$F" "$WANT" "${GOT:0:${#WANT}}" "$(stat -f '%Sm' "$F")"
       printf '   ⇒ gitignored 파일은 워크트리 간 자동 전파가 «없다». 최신본을 받아라\n'; } >&2
     exit 1 ;;
esac
