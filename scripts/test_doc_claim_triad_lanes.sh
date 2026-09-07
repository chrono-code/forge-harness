#!/usr/bin/env bash
# test_doc_claim_triad_lanes.sh — scripts/doc_claim_triad_scan.py 회귀 앵커.
#
# 🟥 이 레인이 지키는 것은 «숫자»가 아니라 «판별력»이다. 그 계기는 세션 중 세 번 뚫렸고
#    (공존≠관계 · 방향 미해결 · 나열 통과) 세 번 다 손검증이 잡았다. 레인은 그 셋이
#    되돌아오는지를 본다 — 픽스처는 실제로 뚫렸던 표기를 그대로 쓴다.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(dirname "$HERE")"
SCAN="$HERE/doc_claim_triad_scan.py"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "${2:-}"; }

echo "── test_doc_claim_triad_lanes ──"

# L1 — 파일 실재 + 실행 가능
[ -f "$SCAN" ] || { no "L1 파일 실재" "$SCAN 없음"; echo "FAILED=1"; exit 1; }
python3 -c "import ast,sys;ast.parse(open(sys.argv[1],encoding='utf-8').read())" "$SCAN" >/dev/null 2>&1 \
  && ok "L1 구문" || no "L1 구문" "ast.parse 실패"

# L2 — 계기 보정이 통과한다 (양쪽 절반)
OUT=$(python3 "$SCAN" --selftest "$ROOT" 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "L2 selftest rc=0" || no "L2 selftest" "rc=$RC"
printf '%s' "$OUT" | grep -q "주장 추출기" && ok "L2b 추출기 보정 실행됨" || no "L2b 추출기 보정" "절이 없다"
printf '%s' "$OUT" | grep -q "실행 판별기" && ok "L2c 실행판별 보정 실행됨" || no "L2c 실행판별 보정" "절이 없다"

# L3 — 🟥 나열을 주장으로 세지 않는다 (v1 이 뚫린 자리, 실제 표기)
python3 - "$SCAN" <<'PY' && ok "L3 나열 거부" || no "L3 나열 거부" "나열이 주장으로 셰짐"
import importlib.util,sys
spec=importlib.util.spec_from_file_location("m",sys.argv[1]); m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
A,B="scripts/foo.sh","scripts/bar.sh"
# 🟥 cross-family codex [B]: 가운뎃점·백틱·쉼표만 막으면 «and/plus/인용부호» 로 뚫린다.
# 그 표기를 픽스처에 넣는다 — 실제로 CATALOG.md:137 이 `X (pre-commit) and Y (pre-push)` 였다.
lists=[f"**File:** {A} · {B} · templates/.git-hooks/pre-commit",
       f"Fixtures: `{A}` · `{B}`.", f"Anchors: `{A}`, `{B}`",
       f"Anchors: `{A}` and `{B}`", f"see `{A}` plus `{B}`",
       f'"{A}" "{B}"']
sys.exit(0 if not any(m.asserts_relation(l,A,B) for l in lists) else 1)
PY

# L4 — 관계 주장은 잡는다 (한/영 둘 다 — 언어 중립 요구)
python3 - "$SCAN" <<'PY' && ok "L4 관계 포착(한·영)" || no "L4 관계 포착" "관계를 놓쳤다"
import importlib.util,sys
spec=importlib.util.spec_from_file_location("m",sys.argv[1]); m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
A,B="scripts/foo.sh","scripts/bar.sh"
rel=[f"{A} 는 {B} 를 호출한다", f"`{A}` is wired into `{B}`", f"the hook {A} blocks by running {B}"]
sys.exit(0 if all(m.asserts_relation(l,A,B) for l in rel) else 1)
PY

# L5 — 🟥 실행 vs 언급. 실제로 뚫렸던 표기(grep 대안식 안의 `name)\.sh`)를 픽스처로 쓴다
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/hook_exec.sh" <<'EOF'
#!/usr/bin/env bash
bash "$REPO_ROOT/scripts/target_thing.sh" "$REPO_ROOT"
EOF
cat > "$TMP/hook_mention.sh" <<'EOF'
#!/usr/bin/env bash
# target_thing.sh is only named here, never run
git diff --name-only | grep -E '(scripts/(other|target_thing)\.sh)' || true
EOF
# 🟥 cross-family codex [A]: 출력 구문 안의 인터프리터 호출은 «실행처럼 보이지만» 아무것도 안 돌린다
cat > "$TMP/hook_echo.sh" <<'EOF'
#!/usr/bin/env bash
echo "run it yourself:  bash scripts/target_thing.sh"
EOF
python3 - "$SCAN" "$TMP" <<'PY' && ok "L5 실행/언급 판별" || no "L5 실행/언급 판별" "둘을 못 가른다"
import importlib.util,sys,os
spec=importlib.util.spec_from_file_location("m",sys.argv[1]); m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
t=sys.argv[2]
v1,_=m.executes(os.path.join(t,"hook_exec.sh"),"target_thing.sh")
v2,_=m.executes(os.path.join(t,"hook_mention.sh"),"target_thing.sh")
v3,_=m.executes(os.path.join(t,"hook_echo.sh"),"target_thing.sh")
sys.exit(0 if (v1=="EXECUTES" and v2=="MENTIONS-ONLY" and v3=="MENTIONS-ONLY") else 1)
PY

# L6 — 🟥 보정 실패 시 «스캔을 거부»한다 (fail-closed). 뮤턴트로 확인하고 되돌린다
CP="$TMP/mutant.py"; cp "$SCAN" "$CP"
python3 - "$CP" <<'PY'
import sys
p=sys.argv[1]; L=open(p,encoding="utf-8").read().split("\n")
i=[k for k,l in enumerate(L) if l.startswith("def asserts_relation(")][0]
L.insert(i+1,"    return True  # MUTANT: 모든 것을 주장이라 한다")
open(p,"w",encoding="utf-8").write("\n".join(L))
PY
MOUT=$(python3 "$CP" --selftest "$ROOT" 2>&1); MRC=$?
[ "$MRC" -eq 2 ] && ok "L6 뮤턴트 → rc=2 거부" || no "L6 뮤턴트 거부" "rc=$MRC (기대 2)"
MS=$(python3 "$CP" "$ROOT" 2>&1); MSRC=$?
[ "$MSRC" -eq 2 ] && ok "L6b 뮤턴트는 스캔도 거부" || no "L6b 뮤턴트 스캔거부" "rc=$MSRC (기대 2)"

# L8 — 🟥 known-pair 가 «낡으면» 보정이 실패한다 (cross-family codex [S]).
#      B 가 삭제·이동돼도 A 가 이름만 언급하면 통과하던 자리.
cat > "$TMP/fakeroot_probe.py" <<'PY8'
import importlib.util,sys,os
spec=importlib.util.spec_from_file_location("m",sys.argv[1]); m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
sys.exit(0 if m.resolve(sys.argv[2], "scripts/zzq_nonexistent_target.sh") is None else 1)
PY8
python3 "$TMP/fakeroot_probe.py" "$SCAN" "$ROOT" && ok "L8 부재 대상은 resolve=None" || no "L8 resolve" "없는 파일을 찾았다고 했다"

# L7 — 🟥 «진짜» 되돌림: 원본 자리에 뮤턴트를 넣었다 뺀다. 빨강→초록 전이를 본다
cp "$SCAN" "$TMP/orig_backup.py"
python3 - "$SCAN" <<'PY7'
import sys
p=sys.argv[1]; L=open(p,encoding="utf-8").read().split("\n")
i=[k for k,l in enumerate(L) if l.startswith("def asserts_relation(")][0]
L.insert(i+1,"    return True  # MUTANT-INPLACE")
open(p,"w",encoding="utf-8").write("\n".join(L))
PY7
python3 "$SCAN" --selftest "$ROOT" >/dev/null 2>&1; INJ=$?
cp "$TMP/orig_backup.py" "$SCAN"
python3 "$SCAN" --selftest "$ROOT" >/dev/null 2>&1; RST=$?
LEFT=$(grep -c "MUTANT-INPLACE" "$SCAN" || true)
if [ "$INJ" -eq 2 ] && [ "$RST" -eq 0 ] && [ "$LEFT" -eq 0 ]; then
  ok "L7 되돌림 전이 (주입 rc=2 → 복원 rc=0, 잔존 0)"
else
  no "L7 되돌림 전이" "주입rc=$INJ 복원rc=$RST 잔존=$LEFT"
fi

echo "── PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ] || { echo "FAILED=1"; exit 1; }
echo "FAILED=0"
