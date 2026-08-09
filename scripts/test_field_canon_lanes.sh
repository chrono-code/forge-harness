#!/usr/bin/env bash
# field_canon_preload.sh 레인 — known-pair 교정.
#
# 이 파일이 있는 이유: 2026-08-09 에 한 세션이 종일 qasp 를 파면서 그 레포 정본(README 604줄 ·
# docs/governance 32개)을 **하나도 안 읽고** 코드 역추론했고 **네 번 정정당했다(자력 적발 0)**.
# ①은 그날의 **첫 메시지를 그대로** 넣는다 — 훅이 있었다면 그 자리에서 걸렸어야 한다.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
H="$HERE/field_canon_preload.sh"
TMP=$(mktemp -d) || exit 10
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "$2"; }
# ★`${3:+VAR=v}` 는 파라미터 확장이라 bash 가 **환경 할당으로 안 읽는다** — env 로 넘긴다.
#   (이 파일 초판이 그렇게 써서 「레포 부재」 레인이 거짓 적색을 냈다. 계기 결함이었다.)
run(){ local extra=""; [ -n "${3:-}" ] && extra="FIELD_CANON_PROJECT_ROOT=$3"
  printf '%s' "$1" | env FIELD_CANON_SENTINEL_DIR="$2" $extra bash "$H" 2>&1; }

echo "== field-canon preload 레인 =="

out=$(run '{"prompt":"세션 시작하자 qasp 병렬세션"}' "$TMP/1")
case "$out" in *qasp*README.md*) ok "① 그날의 첫 메시지 → 정본 경로 제시" ;;
  *) no "① 그날의 첫 메시지" "정본 경로 미출력" ;; esac
case "$out" in *docs/governance*) ok "①-b governance 정본 수를 함께 낸다" ;;
  *) no "①-b governance" "미출력" ;; esac

run '{"prompt":"qasp 시작"}' "$TMP/2" >/dev/null
out=$(run '{"prompt":"qasp 또"}' "$TMP/2")
[ -z "$out" ] && ok "② 세션당 1회 — 재나그 없음" || no "②" "2회차에 또 출력(무시를 학습시킨다)"

out=$(run '{"prompt":"오늘 날씨 어때"}' "$TMP/3")
[ -z "$out" ] && ok "★컨트롤: 매핑 밖 프롬프트는 조용" || no "컨트롤" "오탐 출력"

out=$(run '{"prompt":"qasp"}' "$TMP/4" /nonexistent)
[ -z "$out" ] && ok "★컨트롤: 레포 부재 → 조용(허위 지시 금지)" || no "레포 부재" "없는 경로를 가리켰다"

printf 'not-json' | FIELD_CANON_SENTINEL_DIR="$TMP/5" bash "$H" >/dev/null 2>&1
[ $? = 0 ] && ok "깨진 입력도 rc=0 (비영종료는 stdout 폐기 = 무음)" || no "깨진 입력" "rc≠0"
printf '' | FIELD_CANON_SENTINEL_DIR="$TMP/6" bash "$H" >/dev/null 2>&1
[ $? = 0 ] && ok "빈 입력 rc=0" || no "빈 입력" "rc≠0"

echo "── PASS $PASS · FAIL $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
