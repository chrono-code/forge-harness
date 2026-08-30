#!/usr/bin/env bash
# test_hook_leg_wiring_lanes.sh — «그 다리가 호출되는가» 를 잰다. «그 다리가 옳은가» 가 아니다.
#
# WHY (실측 2026-08-30, 되돌림 프로브):
#   `templates/.git-hooks/pre-commit` 의 soul 호출부 두 줄을 `: ;` 로 지워도
#   `bash scripts/test_marker_soul_check_lanes.sh` 는 `SOUL LANES: PASS` 를 낸다.
#   그 스위트는 `sed -n '/^validate_..._leg()/,/^}/p'` 로 **함수만 추출**해 격리 실행하므로,
#   구조적으로 «호출되는가» 를 볼 수 없다. 함수는 옳고, 게이트는 죽어 있다.
#   → [[feedback_built_but_not_wired]] · [[feedback_anchor_can_be_decorative]]
#
# 방법 — grep 이 아니라 **실행**이다. 합성 레포에서 진짜 훅을 돌리고, 다리의 판정 문구가
# 실제 실행 출력에 나오는지 본다. 그리고 **known-negative** 로 호출부만 제거한 사본을 같은
# 입력으로 돌려 그 문구가 사라지는지 확인한다. 사라지지 않으면 이 계기는 호출부가 아니라
# 다른 것을 재고 있는 것이므로 HARNESS-ERROR 로 중단한다(초록 보고 금지).
#
# SCOPE — 기록/배선의 속성이지 결론이 아니다. 「그 다리의 판정이 옳은가」는 안 묻는다.
#
# Usage: bash scripts/test_hook_leg_wiring_lanes.sh    Exit: 0 = 전부 배선됨 · 1 = 회귀 · 10 = 계기 불량
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
[ -f "$HOOK" ] || { echo "❌ HARNESS-ERROR — hook not found: $HOOK"; exit 10; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
FAIL=0

# ── 합성 레포 하나를 만들어 재사용한다 (FH 자산 1개 staged + 오늘자 마커) ─────────────
WP="$T/wp"; mkdir -p "$WP"
( cd "$WP" && git init -q . && git config user.email t@example.invalid && git config user.name t ) || { echo "❌ HARNESS-ERROR — git init failed"; exit 10; }
ln -s "$REPO_ROOT/scripts" "$WP/scripts"
mkdir -p "$WP/tracks/_meta" "$WP/plugins/p/skills/s" "$WP/.claude"
# 🟥 등록부를 합성 레포에 **깔아야** tenet 다리가 «인용한 ID 가 없다» 가지를 탄다. 안 깔면
# «등록부가 없다» 라는 **다른 가지**를 타고, 그러면 이 레인은 배선이 아니라 파일 부재를 재게 된다
# (실측 2026-08-30: W3 이 needle 을 못 찾아 NOT REACHED 로 빨개졌다 — 계기 결함이었지 배선 결함이 아니었다).
if [ -f "$REPO_ROOT/.claude/soul_tenets.txt" ]; then
  cp "$REPO_ROOT/.claude/soul_tenets.txt" "$WP/.claude/soul_tenets.txt"
else
  echo "⚠️  .claude/soul_tenets.txt 부재 — W3 은 등록부-부재 가지를 잰다(배선은 여전히 판별된다)."
fi
printf '# x\n' > "$WP/CATALOG.md"
( cd "$WP" && git add CATALOG.md && git commit -qm init ) >/dev/null 2>&1
printf '# SKILL\n' > "$WP/plugins/p/skills/s/SKILL.md"
( cd "$WP" && git add plugins/p/skills/s/SKILL.md ) >/dev/null 2>&1
WP_BRANCH=$( cd "$WP" && git rev-parse --abbrev-ref HEAD )
WP_MARKER="$WP/tracks/_meta/.axes_23_passed_${WP_BRANCH//\//_}_$(date +%Y-%m-%d).marker"

run_hook() { # $1 = hook path, $2 = marker body → stdout+stderr of the run
  printf '%s\n' "$2" > "$WP_MARKER"
  ( cd "$WP" && bash "$1" 2>&1 )
}

neuter() { # $1 = function name → prints path to a hook copy with that call site removed
  local fn="$1" out="$T/hook_no_${fn}.sh"
  sed -E "s/^([[:space:]]*)${fn} \"\\\$MARKER\".*/\1: ;/" "$HOOK" > "$out"
  printf '%s' "$out"
}

wiring_lane() { # $1=id  $2=leg function  $3=marker body  $4=verdict substring the leg emits
  local id="$1" fn="$2" body="$3" needle="$4" nh live dead sites_before sites_after
  sites_before=$(grep -cE "^[[:space:]]*${fn} \"\\\$MARKER\"" "$HOOK")
  if [ "$sites_before" -eq 0 ]; then
    printf '  ❌ %-34s NOT WIRED — no `%s "$MARKER"` call site in the hook\n' "$id" "$fn"; FAIL=1; return
  fi
  nh=$(neuter "$fn")
  sites_after=$(grep -cE "^[[:space:]]*${fn} \"\\\$MARKER\"" "$nh")
  if [ "$sites_after" -ne 0 ] || ! bash -n "$nh" 2>/dev/null; then
    printf '  ❌ %-34s HARNESS-ERROR — neuter left %s call site(s) or broke syntax\n' "$id" "$sites_after"
    FAIL=1; return
  fi
  live=$(run_hook "$HOOK" "$body" | grep -cF "$needle")
  dead=$(run_hook "$nh"   "$body" | grep -cF "$needle")
  if [ "$live" -gt 0 ] && [ "$dead" -eq 0 ]; then
    printf '  ✅ %-34s WIRED (live=%s dead=%s)\n' "$id" "$live" "$dead"
  elif [ "$live" -eq 0 ]; then
    printf '  ❌ %-34s NOT REACHED — the real hook never printed «%s»\n' "$id" "$needle"; FAIL=1
  else
    printf '  ❌ %-34s HARNESS-ERROR — verdict survives call-site removal; this probe is not\n' "$id"
    printf '     measuring wiring (live=%s dead=%s). Refusing to report green.\n' "$live" "$dead"; FAIL=1
  fi
}

SOUL_OK='①영혼: 성공 정의 = «소비자 경로에서 완주해 rc=0 을 내고 컨트롤로 가른다». 절대 안 함 = «FAIL 을 SKIP 으로 바꾸는 것»'

echo "== hook leg wiring lanes — 실행 프로브 (호출부 되돌림 known-pair) =="
wiring_lane W1-soul-present validate_soul_present_leg \
  '①영혼: ok
axes-run: ⓐ=codex' \
  '①영혼 line is vacuous'
wiring_lane W2-soul-check validate_soul_check_leg \
  "$SOUL_OK
soul-check: done" \
  "is not a member"

# 아래 둘은 2026-08-30 신설 다리. 훅에 아직 없으면 «NOT WIRED» 로 빨개진다 — 그것이 의도다.
wiring_lane W3-soul-tenet-refs validate_soul_tenet_refs \
  "$SOUL_OK
tenets: FH-T99" \
  '등록부에 없는 tenet'
wiring_lane W4-defeater validate_defeater_leg \
  "$SOUL_OK
defeater: 틀렸을 수도" \
  'defeater 가 공허하다'

echo
if [ $FAIL -eq 0 ]; then echo "HOOK LEG WIRING LANES: PASS"; else echo "HOOK LEG WIRING LANES: FAIL"; fi
exit $FAIL
