#!/usr/bin/env bash
# residency_closure_scan.py 레인 테스트 — known-pair 교정.
#
# 이 파일이 있는 이유: 초판이 cross-family 적대검증(gpt-5.5, 2026-08-09)에서 **false-CLEAN
# 다수**로 반증됐다. 아래 L1~L3 은 그때 재현한 실제 우회 경로이고, 되돌리면 이 레인들이
# 적색이 된다. 「고쳤다」를 주장으로 두지 않고 실행으로 남긴다.
#
# 각 레인 = (입력, 기대 rc). rc 계약: 0=CLEAN(스크리닝) · 1=TAINTED · 10=HARNESS(fail-closed)
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCAN="$HERE/residency_closure_scan.py"
TMP=$(mktemp -d) || exit 10
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
lane() { # lane <이름> <기대rc> <모듈> [패턴파일]
  local name=$1 want=$2 mod=$3 pat=${4:-$TMP/pat}
  RESIDENCY_PATTERNS="$pat" python3 "$SCAN" --repo "$TMP/repo" "$mod" >/dev/null 2>&1
  local got=$?
  if [ "$got" = "$want" ]; then PASS=$((PASS+1)); printf '  ✅ %-42s rc=%s\n' "$name" "$got"
  else FAIL=$((FAIL+1)); printf '  ❌ %-42s rc=%s (기대 %s)\n' "$name" "$got" "$want"; fi
}

R="$TMP/repo"
mkdir -p "$R"/{src/pkg,myapp,app,clean,deep/sub}
: > "$R/src/pkg/__init__.py"; : > "$R/app/__init__.py"; : > "$R/deep/__init__.py"
: > "$R/deep/sub/__init__.py"

# L1 상대 임포트 — 초판이 `level == 0` 으로 통째로 버렸다
printf 'from .secrets import HOST\n' > "$R/src/pkg/main.py"
printf 'HOST = "api.acme.corp"\n'    > "$R/src/pkg/secrets.py"
# L2 루트 화이트리스트 밖 레이아웃 — 초판은 ("src","scripts",…) 만 따라갔다
printf 'import myapp.config\n'    > "$R/myapp/main.py"
printf 'HOST = "api.acme.corp"\n' > "$R/myapp/config.py"
# L3 `from pkg import sub` — 초판은 pkg/__init__.py 만 훑었다
printf 'from app import secrets\n' > "$R/app/main.py"
printf 'HOST = "api.acme.corp"\n'  > "$R/app/secrets.py"
# L4 부모 패키지 __init__.py 오염 — payload 에 같이 나간다
printf 'HOST = "api.acme.corp"\n' > "$R/deep/__init__.py"
printf 'X = 1\n'                  > "$R/deep/sub/leaf.py"
# 과교정 컨트롤 — 진짜 깨끗한 모듈
printf 'X = 1\n' > "$R/clean/ok.py"

printf 'acme\n' > "$TMP/pat"
: > "$TMP/pat_empty"
printf '# 주석뿐\n' > "$TMP/pat_comment"

echo "== residency 폐포 스캔 레인 =="
lane "L1 상대 임포트 → TAINTED"          1  src.pkg.main
lane "L2 루트 화이트리스트 밖 → TAINTED"  1  myapp.main
lane "L3 from pkg import sub → TAINTED"  1  app.main
lane "L4 부모 __init__ 오염 → TAINTED"    1  deep.sub.leaf
lane "★컨트롤: 깨끗한 모듈 → CLEAN"       0  clean.ok
lane "빈 운영자 패턴 → HARNESS"           10 clean.ok "$TMP/pat_empty"
lane "주석뿐 운영자 패턴 → HARNESS"        10 clean.ok "$TMP/pat_comment"
lane "운영자 패턴 부재 → HARNESS"          10 clean.ok "$TMP/nonexistent"
lane "모듈 부재 → HARNESS"                10 no.such.module

# --files 모드: 실제 송신 목록만 잰다
RESIDENCY_PATTERNS="$TMP/pat" python3 "$SCAN" --repo "$R" --files src/pkg/secrets.py >/dev/null 2>&1
[ $? = 1 ] && { PASS=$((PASS+1)); echo "  ✅ --files 오염 파일 → TAINTED             rc=1"; } \
           || { FAIL=$((FAIL+1)); echo "  ❌ --files 오염 파일"; }
RESIDENCY_PATTERNS="$TMP/pat" python3 "$SCAN" --repo "$R" --files clean/ok.py >/dev/null 2>&1
[ $? = 0 ] && { PASS=$((PASS+1)); echo "  ✅ --files 깨끗한 파일 → CLEAN             rc=0"; } \
           || { FAIL=$((FAIL+1)); echo "  ❌ --files 깨끗한 파일"; }

echo "── PASS $PASS · FAIL $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
