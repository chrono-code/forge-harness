#!/usr/bin/env bash
# test_gate_shape_scan_lanes.sh — scripts/gate_shape_scan.sh 회귀 앵커.
# 지키는 것은 «판별력»: known-pair 가 갈리는가, 주석만 있는 파일이 안 걸리는가, 바이너리가
# «아님» 으로 접히지 않는가, Promise `reject(` 가 게이트로 읽히지 않는가(실측 오탐).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; SCAN="$HERE/gate_shape_scan.sh"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "${2:-}"; }
echo "── test_gate_shape_scan_lanes ──"
[ -x "$SCAN" ] || { no "L1 실행비트" "$SCAN"; echo "FAILED=1"; exit 1; }
bash -n "$SCAN" && ok "L1 구문" || no "L1 구문"
OUT=$(bash "$HERE/gate_shape_scan.sh" --selftest 2>&1); RC=$?   # 직접 호출(변수 경유 아님) — new-code-anchor 가 실행으로 센다
[ "$RC" -eq 0 ] && ok "L2 selftest rc=0 (known-pair 5)" || no "L2 selftest" "rc=$RC · $OUT"
D="$(mktemp -d 2>/dev/null)" || D=""; [ -n "$D" ] && [ -w "$D" ] || { no "L3 환경" "mktemp -d 불가 — 레인 미측정(통과 아님)"; echo "PASS=$PASS FAIL=$FAIL"; echo "FAILED=1"; exit 1; }
printf 'export function up(p) {\n  return new Promise((resolve, reject) => {\n    if (!p) reject(new Error("x"));\n    resolve(p);\n  });\n}\n' > "$D/promise.ts"
bash "$SCAN" "$D/promise.ts" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 1 ] && ok "L3 Promise reject( 는 게이트가 아니다 (실측 오탐 앵커)" || no "L3 Promise reject" "rc=$RC"
printf 'func main() {\n  http.ListenAndServe("0.0.0.0:8080", nil)\n}\n' > "$D/serve.go"
bash "$SCAN" "$D/serve.go" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "L4 Go ListenAndServe → GATE-SHAPED" || no "L4 Go exposure" "rc=$RC"
printf 'def f():\n    return "PASS"\n' > "$D/enum.py"; printf 'def g():\n    pass\n' > "$D/lower.py"
bash "$SCAN" "$D/enum.py" >/dev/null 2>&1; R1=$?; bash "$SCAN" "$D/lower.py" >/dev/null 2>&1; R2=$?
[ "$R1" -eq 0 ] && [ "$R2" -eq 1 ] && ok "L5 대문자 PASS 만 enum (소문자 pass 는 키워드)" || no "L5 enum case" "PASS rc=$R1 pass rc=$R2"
bash "$SCAN" >/dev/null 2>&1; RC=$?; [ "$RC" -eq 3 ] && ok "L6 인자 없음 → usage rc=3" || no "L6 usage" "rc=$RC"
printf '\x00\x01bin' > "$D/b.dat"; bash "$SCAN" "$D/serve.go" "$D/b.dat" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "L6b [gate-shaped, binary] → 3 이 0 을 이긴다 (무음 미스 금지)" || no "L6b 혼합 exit" "rc=$RC"
printf 'x = author\n' > "$D/au.py"; printf 'ok = authorize(u)\n' > "$D/az.py"
bash "$SCAN" "$D/au.py" >/dev/null 2>&1; R1=$?; bash "$SCAN" "$D/az.py" >/dev/null 2>&1; R2=$?
[ "$R1" -eq 1 ] && [ "$R2" -eq 0 ] && ok "L6c 경계: author 는 아니고 authorize 는 맞다" || no "L6c auth 경계" "author rc=$R1 authorize rc=$R2"
# L7 — 되돌림: 분류기의 EXPOSURE 클래스를 죽이면 L4 가 빨개지는가 (앵커가 장식이 아님을 실행으로)
MUT="$D/scan_mut.sh"; /usr/bin/sed 's/^EXPOSURE_RE=.*/EXPOSURE_RE='"'"'(NEVER_MATCHES_XYZ)'"'"'/' "$SCAN" > "$MUT"
bash "$MUT" "$D/serve.go" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 1 ] && ok "L7 되돌림: EXPOSURE 제거 → serve.go 가 NOT 로 떨어진다 (레인이 실물을 잰다)" || no "L7 되돌림" "rc=$RC (제거해도 초록이면 앵커가 장식)"
/bin/rm -rf "$D"
echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ] && { echo "FAILED=0"; exit 0; } || { echo "FAILED=1"; exit 1; }
