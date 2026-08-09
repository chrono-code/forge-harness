#!/usr/bin/env bash
# field_canon_preload.sh — 매핑된 필드 하네스가 언급되면 **그 하네스의 정본 경로**를 띄운다.
#
# WHY (2026-08-09 실측, 하루 4회 정정 · 자력 적발 0):
#   FH 세션 시작 자동 적재는 **FH 자기 정본만** 싣는다(`fh_session_load.sh` = 동반자 저장소).
#   그런데 한 세션이 종일 qasp 를 파면서 qasp `README.md`(604줄) · `docs/governance/`(32개)를
#   **하나도 안 읽고** 코드에서 역추론했다. 네 번 정정당했고 네 번 다 **정본에 답이 있었다**:
#     · MTM 을 "조건부 화이트박스 모드" 로 요약   → 정본은 블박+화박 **동시**(이중시야)
#     · "매트릭스 = 축이 여럿"                  → 영화 매트릭스에서 **네오가 보는 시야**
#     · 3막 본체가 act2 에 있는 걸 배치 결함 판정 → README 가 **의도**라고 명시(L1 공유·중복 0)
#     · 전수조사 모수를 src/act2 로 한정         → b레인·mate 는 모수 밖
#   README 는 그중 하나를 *"이 축이 안 보이면 3막을 mate 판정 전용으로 오해한다"* 로
#   **경고까지 하고 있었다.** 산문 규율로는 안 읽힌다 — `fh_session_load.sh` 헤더가 이미 같은
#   결론을 적었다("prose is salience-dependent"). 같은 처방을 필드 하네스에 적용한다.
#
# WHAT: 프롬프트에 매핑된 프로젝트 이름이 나오면, **실재하는 정본 파일 경로만** 골라 한 번 띄운다.
#   ★ 일반 훈계("정본을 읽어라")가 아니라 **이 레포의 이 파일들**이어야 한다 — 오늘의 실패는
#     규율을 몰라서가 아니라 **그 파일들이 거기 있는 줄 몰라서**였다.
#
# 프로젝트당 세션당 1회. 센티넬로 재나그 방지 — 반복 알림은 무시를 학습시킨다.
#
# 종료: 항상 0 · 보고는 stdout. (비영 종료는 stdout 이 폐기되고 stderr 도 안 전달된다 —
#       `[[feedback_hook_nonzero_exit_is_silent]]`.)
set -uo pipefail

HUB="${CLAUDE_PROJECT_DIR:-$HOME/projects/forge-harness}"
PROJ_ROOT="${FIELD_CANON_PROJECT_ROOT:-$HOME/projects}"
SENT_DIR="${FIELD_CANON_SENTINEL_DIR:-${TMPDIR:-/tmp}/fh_field_canon_$$}"
[ -n "${FIELD_CANON_SENTINEL_DIR:-}" ] || SENT_DIR="${TMPDIR:-/tmp}/fh_field_canon_${CLAUDE_SESSION_ID:-shared}"
mkdir -p "$SENT_DIR" 2>/dev/null || true

# stdin 은 훅 페이로드(JSON). prompt 를 못 뽑아도 **조용히 죽지 않는다** — 원문 전체로 폴백한다.
RAW=$(cat 2>/dev/null || true)
PROMPT=$(printf '%s' "$RAW" | python3 -c "
import json,sys
try: print(json.load(sys.stdin).get('prompt',''))
except Exception: print('')
" 2>/dev/null)
[ -n "$PROMPT" ] || PROMPT="$RAW"
[ -n "$PROMPT" ] || exit 0

# 매핑된 프로젝트 = tracks/ 하위 디렉토리(언더스코어 접두는 메타라 제외)
mapped=$(ls -d "$HUB"/tracks/*/ 2>/dev/null | while read -r d; do
  b=$(basename "$d")
  [ "${b#_}" = "$b" ] || continue          # 언더스코어 접두 = 메타 디렉토리, 제외
  printf '%s\n' "$b"
done)
[ -n "$mapped" ] || exit 0

emitted=0
for name in $mapped; do
  # 프롬프트에 이름이 나오는가 (대소문자 무시). 짧은 이름의 오탐은 감수 — 과소보다 낫다.
  printf '%s' "$PROMPT" | grep -qi -- "$name" || continue
  [ -e "$SENT_DIR/$name" ] && continue          # 이 세션에서 이미 띄웠다

  # 레포 해석: tracks 이름 그대로 → 없으면 `-dev` 접미 (qasp → qasp-dev 실측 사례)
  repo=""
  for cand in "$PROJ_ROOT/$name" "$PROJ_ROOT/${name}-dev"; do
    [ -d "$cand/.git" ] && { repo="$cand"; break; }
  done
  [ -n "$repo" ] || continue

  # **실재하는 것만** 싣는다. 없는 파일을 가리키면 다음 사람이 그 지시를 못 믿게 된다.
  lines=""
  [ -f "$repo/README.md" ] && lines="$lines\n     README.md ($(wc -l < "$repo/README.md" | tr -d ' ')줄) — §구조·§지도 절 먼저"
  [ -f "$repo/CLAUDE.md" ] && lines="$lines\n     CLAUDE.md ($(wc -l < "$repo/CLAUDE.md" | tr -d ' ')줄)"
  gov=$(ls "$repo/docs/governance" 2>/dev/null | wc -l | tr -d ' ')
  [ "${gov:-0}" -gt 0 ] && lines="$lines\n     docs/governance/ — 정본 ${gov}개 (용어·모드·계약의 출처)"
  [ -n "$lines" ] || continue

  if [ "$emitted" -eq 0 ]; then
    echo ""
    echo "📚 [field-canon] 매핑된 필드 하네스가 언급됐다 — **코드 역추론 전에 그쪽 정본을 읽어라.**"
    emitted=1
  fi
  echo "  ▸ $name  →  $repo"
  printf '%b\n' "$lines"
  : > "$SENT_DIR/$name" 2>/dev/null || true
done

if [ "$emitted" -eq 1 ]; then
  cat <<'EOF'
  ⚠️ 이 안내는 프로젝트당 세션당 1회다. 2026-08-09 실측: 정본 미독으로 하루 4회 정정,
     자력 적발 0 — 네 번 다 답이 정본에 있었고 그중 하나는 README 가 그 오해를 경고까지 했다.
     ★ 필드 하네스 용어를 일반 개념으로 정규화하지 마라(「MTM=화이트박스 모드」가 그 실패다).
EOF
fi
exit 0
