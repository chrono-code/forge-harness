#!/usr/bin/env bash
# test_evidence_root_psa_lanes.sh — pre-commit 의 기밀성 스캐너가 **워크트리에서도 오버라이드를
# 찾는가** (R4, 2026-08-18).
#
# WHY
#   `tracks/` 는 `--git-common-dir` 기준 `EVIDENCE_ROOT` 로 옮겼는데, **똑같이 gitignored 인**
#   `.claude/rules/.public-surface-patterns` 는 `$REPO_ROOT` 에 남아 있었다. 그래서 워크트리
#   커밋이 매번 **defaults-only** 로 돌았다 — 회사명·실명 토큰 클래스가 통째로 UNSCANNED 고,
#   그 상태는 **비차단 경고**라 조용히 지나간다. 반쪽-픽스의 전형
#   ([[feedback_half_fix_propagation_boundary]]) 이고, EVIDENCE_ROOT 에는 **레인이 하나도
#   없었다** — 그래서 반쪽인 채로 출하됐다.
#
# Lanes
#   E1  워크트리에서 커밋해도 오버라이드를 찾는다 (경고 배너 없음)
#   E1n CONTROL — 오버라이드를 지우면 같은 실행에서 배너가 **뜬다**(계기가 살아 있다는 증거)
#   E2  CONTROL — 메인 트리는 종전 그대로 동작한다 (회귀 없음)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0
t() { if [ "$2" = "$3" ]; then echo "  ✅ $1"; pass=$((pass+1)); else echo "  ❌ $1 — got [$3] want [$2]"; fail=$((fail+1)); fi }

BANNER='CONFIDENTIALITY COVERAGE REDUCED'

setup() { # $1 = base dir
  local b="$1"
  mkdir -p "$b/main"
  ( cd "$b/main" && git init -q . && git config user.email t@t && git config user.name t
    mkdir -p .claude/rules scripts templates/.git-hooks tracks/_meta
    cp "$ROOT/scripts/psa_scan_lib.sh" scripts/
    cp "$ROOT/.claude/rules/.public-surface-patterns.defaults" .claude/rules/ 2>/dev/null
    cp "$ROOT/templates/.git-hooks/pre-commit" templates/.git-hooks/
    printf 'tracks/\n.claude/rules/.public-surface-patterns\n' > .gitignore
    printf 'x\n' > seed.md
    git add -A && git commit -qm base ) >/dev/null 2>&1
  # gitignored 오버라이드 — **메인 트리에만** 둔다 (실제 배치가 그렇다)
  printf 'HIGH\tZZ_R4_OVERRIDE_TOKEN_ZZ\n' > "$b/main/.claude/rules/.public-surface-patterns"
}

# 🟥 고정 `/tmp` 경로 금지 (보안 패스 2026-08-18, MED·재현됨). `>/tmp/.r4out` 은 이름이
#    완전 고정이라, 공유 `/tmp` 를 쓰는 CI 러너·다중사용자 호스트에서 공격자가 먼저 심볼릭
#    링크를 걸어두면 `>` 가 링크를 따라가 **호출자 권한으로 임의 파일을 truncate + overwrite**
#    한다(sticky bit 는 «남의 파일 삭제»만 막지 «먼저 만든 링크»는 못 막는다). 이 스위트는
#    출하되고 `selfcheck.sh` 에 배선돼 있어 소비자가 셀프체크만 돌려도 발동한다.
R4OUT="$(mktemp "${TMPDIR:-/tmp}/fh_r4out.XXXXXX")" || exit 1
trap 'rm -f "$R4OUT"' EXIT

run_hook() { # $1 = 실행 디렉터리 → echoes banner|clean
  local out
  ( cd "$1" && printf 'hello\n' > probe.md && git add probe.md \
    && bash templates/.git-hooks/pre-commit ) >"$R4OUT" 2>&1
  if grep -q "$BANNER" "$R4OUT"; then echo banner; else echo clean; fi
}

B=$(mktemp -d); setup "$B"
( cd "$B/main" && git worktree add -q "$B/wt" -b wtbranch ) >/dev/null 2>&1
# 워크트리에는 templates/ 가 체크아웃돼 있다(tracked). 오버라이드는 없다(gitignored).
t "E1 워크트리에서도 오버라이드를 찾는다"          "clean"  "$(run_hook "$B/wt")"
t "E2 control — 메인 트리 회귀 없음"               "clean"  "$(run_hook "$B/main")"
mv "$B/main/.claude/rules/.public-surface-patterns" "$B/main/.claude/rules/.psa.bak"
t "E1n control — 오버라이드가 진짜 없으면 배너가 뜬다" "banner" "$(run_hook "$B/wt")"

# ── E3 · «있지만 무효» (cross-family/codex 지적, 2026-08-18) ─────────────────
# 🟥 지적: E1/E1n 은 **파일 없음**만 재고, EVIDENCE_ROOT 쪽 파일이 «있지만 비었거나 손상»인
#    경로를 안 잰다. 실측해 보니 기존 기계가 이미 **소리내며** 처리한다 —
#      빈 파일  → PSA_OVERRIDE_PRESENT=0 → 커버리지 축소 배너
#      손상 행  → PSA_BAD_ROWS>0        → «gate INACTIVE/INCOMPLETE»
#    🟥 그리고 **폴백하지 않는 것이 옳은 방향**이다: 워크트리에 있는 다른 파일로 조용히
#    갈아타면 «어느 패턴셋으로 쟀는지»가 로그에서 사라진다. 시끄럽게 알리는 쪽을 고정한다.
printf 'HIGH\tZZ_WT_LOCAL_ZZ\n' > "$B/wt/.claude/rules/.public-surface-patterns"   # 워크트리 로컬본
: > "$B/main/.claude/rules/.public-surface-patterns"                                  # EVIDENCE_ROOT = 빈 파일
t "E3 EVIDENCE_ROOT 가 비었으면 조용히 폴백하지 않고 알린다" "banner" "$(run_hook "$B/wt")"
printf 'no-tab-garbage-row\n' > "$B/main/.claude/rules/.public-surface-patterns"
out3=$( ( cd "$B/wt" && printf 'z\n' > p2.md && git add p2.md && bash templates/.git-hooks/pre-commit ) 2>&1 )
case "$out3" in *"INACTIVE/INCOMPLETE"*) r=announced ;; *) r=silent ;; esac
t "E3b 손상 행은 «게이트 무효»로 알린다(조용한 통과 아님)" "announced" "$r"
rm -rf "$B"

echo "----"; echo "evidence-root psa: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
