#!/usr/bin/env bash
# soul_trace.sh — 심지 원칙(tenet) ↔ 기계 앵커의 **양방향 추적성**.
#
# 외부 근거: DO-178C bidirectional traceability —
#   forward  : 모든 요구가 최소 1개 구현/검증에 걸렸나          (미구현 탐지)
#   backward : 모든 구현/검증이 어떤 요구를 근거로 존재하나      (**장식·고아 유닛 탐지**)
# backward 가 값이 큰 쪽이다: 아무 원칙도 근거로 대지 못하는 레인은 «있으니까 있는» 레인이다.
#
# 🟥 **갭은 FAIL 이 아니다.** 갭을 FAIL 로 찍으면 «모든 레인이 tenet 을 가져야 한다»는 결론을
#    코드로 굳히는 것이고, 그건 CLAUDE.md §Mechanization Boundary 가 금지하는 형태다
#    (오늘의 판단 → 내일의 천장). 그래서 갭은 **남은 태스크로 append** 한다
#    (GitHub Spec Kit `/speckit.converge` 형태). append 는 채널이고 FAIL 은 결론이다.
#
# SCOPE — backward 는 «마커 다리»(hook 의 validate_*_leg + scripts/test_marker_*.sh) 로 좁혀져
#    있다. 81개 레인 전부에 걸면 태스크 74건이 쏟아져 목록이 소음이 되고, 소음이 된 목록은 꺼진다.
#    넓힐 거면 `TRACE_BACKWARD_GLOBS` 를 늘려라 — 지금 범위는 «심지 엔진 자신의 표면»이다.
#
# Usage: bash scripts/soul_trace.sh [--quiet]
# Exit : 0 정상(갭이 있어도 0 — advisory) · 10 계기 불량(레지스트리 부재/파싱 실패)
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REG="$REPO_ROOT/.claude/soul_tenets.txt"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
TASKS="$REPO_ROOT/tracks/_meta/soul_trace_tasks.md"
TRACE_BACKWARD_GLOBS=("$REPO_ROOT"/scripts/test_marker_*.sh)

if [ ! -f "$REG" ]; then
  echo "❌ HARNESS-ERROR — tenet registry not found: .claude/soul_tenets.txt"
  echo "   부재를 0 으로 렌더하지 않는다 ([[feedback_not_found_is_not_zero_family]] · FH-T01)."
  exit 10
fi
# 🟥 bash 3.2 (macOS 기본) 에는 `mapfile` 이 없다 — while-read 로 채운다.
TENETS=()
while IFS= read -r _t; do TENETS+=("$_t"); done < <(grep -oE '^FH-T[0-9]{2}' "$REG" | sort -u)
if [ "${#TENETS[@]:-0}" -eq 0 ] || [ -z "${TENETS[0]:-}" ]; then
  echo "❌ HARNESS-ERROR — registry parsed to ZERO tenets. 계기가 빈 집합을 «통과»로 렌더하려던 참이다."
  exit 10
fi
# 계기 캘리브레이션 — known-positive: 이 스크립트 자신이 레지스트리에서 ID 를 실제로 뽑았고,
# known-negative: 실재하지 않는 ID 는 안 잡혀야 한다.
if printf '%s\n' "${TENETS[@]}" | grep -q '^FH-T99$'; then
  echo "❌ HARNESS-ERROR — known-negative FH-T99 가 잡혔다. 추출 정규식이 과광범위하다."; exit 10
fi

echo "== soul trace — tenets: ${#TENETS[@]} (${TENETS[*]}) =="
GAPS=()

echo
echo "-- forward: 각 tenet 이 최소 1개 기계 앵커에 걸렸나 --"
for t in "${TENETS[@]}"; do
  hits=$(grep -rlF "$t" "$REPO_ROOT/scripts" "$REPO_ROOT/templates" "$REPO_ROOT/.claude" 2>/dev/null \
         | grep -v '/soul_tenets.txt$' | grep -v '/soul_trace.sh$' | sort -u)
  n=$(printf '%s' "$hits" | grep -c . )
  if [ "$n" -gt 0 ]; then
    printf '  ✅ %-8s %s anchor(s): %s\n' "$t" "$n" "$(printf '%s' "$hits" | sed "s|$REPO_ROOT/||" | tr '\n' ' ')"
  else
    printf '  ⬜ %-8s 0 anchor — 아직 어떤 레인/훅도 이 원칙을 근거로 대지 않는다\n' "$t"
    GAPS+=("forward · $t · 이 tenet 을 근거로 대는 레인/훅이 0개. 앵커를 붙이거나, 이 tenet 이 기계화 대상이 아님을 «기계는 비가역 경계에만»(FH-T02)로 명시하라.")
  fi
done

echo
echo "-- backward: 각 마커-다리가 어떤 tenet 을 근거로 존재하나 --"
declare -a UNITS=()
while IFS= read -r fn; do UNITS+=("hook:$fn"); done < <(grep -oE '^validate_[a-z_]+_leg' "$HOOK" | sort -u)
for f in "${TRACE_BACKWARD_GLOBS[@]}"; do [ -f "$f" ] && UNITS+=("lane:${f#"$REPO_ROOT"/}"); done
if [ "${#UNITS[@]}" -eq 0 ]; then
  echo "❌ HARNESS-ERROR — backward 대상이 0개. 빈 집합은 «전부 추적됨»이 아니다."; exit 10
fi
for u in "${UNITS[@]}"; do
  kind="${u%%:*}"; name="${u#*:}"
  case "$kind" in
    hook) blob=$(sed -n "/^${name}()/,/^}/p" "$HOOK") ;;
    lane) blob=$(cat "$REPO_ROOT/$name" 2>/dev/null) ;;
  esac
  # 🟥 인용을 **등록부와 교집합** 낸다 (2026-08-30 첫 실사용이 잡은 오탐):
  #    레인 파일에는 known-negative 픽스처(`FH-T88`/`FH-T99`)가 들어 있는데, 초판은 그것을
  #    «이 레인이 근거로 대는 tenet» 으로 셌다. 즉 **존재하지 않는 원칙을 근거로 인정**했다.
  #    참조 무결성은 훅의 tenet-refs 다리가 마커에 대해 하는 것과 같은 검사다 — 여기도 같아야 한다.
  _raw=$(printf '%s' "$blob" | grep -oE 'FH-T[0-9]{2}' | sort -u)
  cited=""; unreg=""
  for _c in $_raw; do
    if printf '%s\n' "${TENETS[@]}" | grep -qx -- "$_c"; then cited="$cited$_c "; else unreg="$unreg$_c "; fi
  done
  if [ -n "$cited" ]; then
    [ -z "$unreg" ] || printf '     ⚠️  미등록 인용 무시: %s(픽스처거나 오타다)\n' "$unreg"
    printf '  ✅ %-46s ← %s\n' "$name" "$cited"
  else
    [ -z "$unreg" ] || printf '     ⚠️  미등록 인용만 있다: %s— 근거로 안 센다\n' "$unreg"
    printf '  ⬜ %-46s ← (근거 tenet 없음)\n' "$name"
    GAPS+=("backward · $name · 이 유닛이 어느 원칙을 근거로 존재하는지 없다. 헤더에 «# tenet: FH-Txx» 한 줄을 붙이거나, 그 원칙이 목록에 없다면 등록을 검토하라(최대 7개 — 넣으려면 하나를 빼라).")
  fi
done

echo
if [ "${#GAPS[@]}" -eq 0 ]; then
  echo "TRACE: 갭 0 — forward/backward 양방향 닫힘"
  exit 0
fi
echo "TRACE: 갭 ${#GAPS[@]}건 — FAIL 아님. 남은 태스크로 append 한다: ${TASKS#"$REPO_ROOT"/}"
mkdir -p "$(dirname "$TASKS")"
{
  printf '\n## %s — soul_trace 남은 태스크 (%s건)\n\n' "$(date +%Y-%m-%d\ %H:%M)" "${#GAPS[@]}"
  printf '> 🟥 이것은 FAIL 목록이 아니라 **converge 큐**다. 갭이 있는 것 자체는 정상이고,\n'
  printf '> 「이 유닛은 기계화 대상이 아니다」로 닫는 것도 정당한 처분이다(FH-T02).\n\n'
  for g in "${GAPS[@]}"; do printf -- '- [ ] %s\n' "$g"; done
} >> "$TASKS"
exit 0
