#!/usr/bin/env bash
# env_purity_scan.sh — 공유층 환경-순도 계기 (2026-08-10, 운영자 제안 «자체점검기 모듈화»)
#
# 무엇을 재나: 공유층(scripts/ knowledge/shared/ templates/ plugins/ CLAUDE.md AGENTS.md)에
# **특정 환경에만 뜻이 있는 산문**(공개-환경: npm publish·레지스트리·launchd… / 조직-환경:
# 로컬 목록)이 몇 파일에 실려 있는지. 이 산문은 다른 환경에서 «깨지는» 게 아니라 **적용 불능인
# 죽은 텍스트**가 된다 — 동기화 때마다, 그리고 FH 큰 업그레이드 때 돌아볼 대상 목록이다.
#
# ADVISORY BY DESIGN: 목록을 내지 차단하지 않는다 (환경 서술이 본문에 있는 것 자체는 결함이
# 아니고, 포인터화 여부는 판단이다). exit 0 = 보고 완료 · exit 10 = 계기 오류(판정 불가).
#
# 토큰 2층 (public-surface-patterns 와 같은 패턴):
#   scripts/.env_purity_tokens.defaults   tracked — 공개-환경 토큰 (공개 사실만)
#   .claude/rules/.env-purity-tokens      gitignored — 환경별 추가 토큰 (조직 식별자는 여기만)
#
# Usage: scripts/env_purity_scan.sh [REPO_DIR]
set -uo pipefail
REPO="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DEF="$REPO/scripts/.env_purity_tokens.defaults"
LOCAL="$REPO/.claude/rules/.env-purity-tokens"

[ -f "$DEF" ] || { echo "⛔ env-purity: 기본 토큰 목록 부재($DEF) — 판정 불가"; exit 10; }
TOKENS=$(grep -v '^\s*#' "$DEF" | grep -v '^\s*$')
[ -f "$LOCAL" ] && TOKENS="$TOKENS
$(grep -v '^\s*#' "$LOCAL" | grep -v '^\s*$')"
[ -n "$TOKENS" ] || { echo "⛔ env-purity: 토큰 0개 — 판정 불가"; exit 10; }

LAYERS="CLAUDE.md AGENTS.md scripts knowledge/shared templates plugins"
total=0
echo "── env-purity: 공유층의 환경-전용 산문 (advisory — 포인터화/독해규칙 후보 목록) ──"
while IFS= read -r tok; do
  [ -z "$tok" ] && continue
  n=$(cd "$REPO" && git grep -l -F "$tok" -- $LAYERS 2>/dev/null | grep -cv "env_purity" ) || n=0
  case "$n" in (*[!0-9]*|'') n=0 ;; esac
  if [ "$n" -gt 0 ]; then
    echo "  '$tok': $n 파일"
    total=$((total+n))
  fi
done <<< "$TOKENS"
# 계기 생존 컨트롤: 공유 방법론 토큰은 반드시 잡혀야 한다 (0 이면 grep 자체가 죽은 것)
ctl=$(cd "$REPO" && git grep -l -F "steel-quench" -- knowledge/shared plugins 2>/dev/null | wc -l | tr -d ' ')
case "$ctl" in (*[!0-9]*|'') ctl=0 ;; esac
[ "$ctl" -gt 0 ] || { echo "⛔ env-purity: 컨트롤 사망(steel-quench 0히트) — 위 수치 무효"; exit 10; }
if [ "$total" -eq 0 ]; then
  echo "  ✅ 환경-전용 토큰 0 (컨트롤 생존 $ctl)"
else
  echo "  요약: 히트 합 $total (파일 단위, 토큰별 중복 포함) · 컨트롤 생존 $ctl"
  echo "  처방 방향: 본문 포인터화(큰 업그레이드 시) 또는 상대 환경의 독해규칙 1줄(company/env 블록)"
fi
exit 0
