#!/usr/bin/env bash
# stray_path_scan 레인 — 판별력과 degrade 방향을 못 박는다.
# 🟥 이 레인이 지키는 명제: **「빈 디렉터리 전수」로 잡으면 안 된다.** 이 레포의 빈 디렉터리
#    다수가 정당하다(`tracks/{name}/` 은 매핑 신호). 전수 스캔은 오탐 기계이고, 오탐은
#    무시를 훈련시킨다. 그래서 L3 컨트롤이 하중을 진다.
set -u
S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stray_path_scan.sh"
P=0; F=0
chk(){ if [ "$2" = "$3" ]; then echo "✅ $1 ($2)"; P=$((P+1)); else echo "❌ $1 (got=$2 want=$3)"; F=$((F+1)); fi; }
L=$(mktemp -d)

mkdir -p "$L/a/On branch main"
o=$(bash "$S" "$L" >/dev/null 2>&1); chk "L1 git 문구로 시작하는 디렉터리 → 검출" "$?" 1
rm -rf "$L"; L=$(mktemp -d)

mkdir -p "$L/b/$(printf 'On branch x\nYour branch is up')"
o=$(bash "$S" "$L" >/dev/null 2>&1); chk "L2 이름에 개행이 든 디렉터리 → 검출" "$?" 1
rm -rf "$L"; L=$(mktemp -d)

# 🟥 하중 지는 컨트롤 — 정당한 빈 디렉터리를 잡으면 이 계기는 못 쓴다
mkdir -p "$L/tracks/pmh-dev" "$L/.claude/worktrees" "$L/.claude-octopus/context"
o=$(bash "$S" "$L" >/dev/null 2>&1); chk "L3 CONTROL 정당한 빈 디렉터리 → 검출 안 함" "$?" 0
rm -rf "$L"

o=$(bash "$S" /no/such/dir/zz >/dev/null 2>&1); chk "L4 스캔 불가 → UNMEASURED(2), 0 아님" "$?" 2

L=$(mktemp -d); mkdir -p "$L/.git/On branch fake"
o=$(bash "$S" "$L" >/dev/null 2>&1); chk "L5 .git 내부는 제외 (git 자기 자료 오탐 방지)" "$?" 0
rm -rf "$L"

echo "stray-path lanes: $P passed, $F failed"
[ "$F" -eq 0 ]
