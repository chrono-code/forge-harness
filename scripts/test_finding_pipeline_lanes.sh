#!/usr/bin/env bash
# test_finding_pipeline_lanes.sh — regression anchor for the typed-finding pipeline
# (scripts/finding_fleet.sh → scripts/finding_verify.py).
#
# 🟥 What these lanes protect is the DIRECTION OF FAILURE, not a count. Every defect this pipeline can
#    have makes an unreviewed or unverified run look like a clean one: a member that returns prose, a
#    verifier that cannot be reached, a family grading its own findings. Each lane below pins one of
#    those, and the mutant lane checks that removing the guard actually turns a lane red.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FLEET="$HERE/finding_fleet.sh"; VERIFY="$HERE/finding_verify.py"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "${2:-}"; }
echo "── test_finding_pipeline_lanes ──"

[ -f "$FLEET" ] && [ -f "$VERIFY" ] || { no "L0 파일 실재" "fleet/verify 없음"; echo "FAILED=1"; exit 1; }
bash -n "$FLEET" && ok "L1a fleet 구문" || no "L1a fleet 구문"
python3 -c "import ast,sys;ast.parse(open(sys.argv[1],encoding='utf-8').read())" "$VERIFY" \
  && ok "L1b verify 구문" || no "L1b verify 구문"

OUT=$(bash "$HERE/finding_fleet.sh" --selftest 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "L2 fleet selftest (known-pair 4)" || no "L2 fleet selftest" "rc=$RC · $OUT"

D="$(mktemp -d 2>/dev/null)" || D=""
[ -n "$D" ] && [ -w "$D" ] || { no "L3 환경" "mktemp -d 불가 — 레인 미측정(통과 아님)"; echo "PASS=$PASS FAIL=$FAIL"; echo "FAILED=1"; exit 1; }

cat > "$D/f.jsonl" <<'EOS'
{"id":"a1","title":"real defect","file":"x.py","line":3,"severity":"A","producer_family":"alpha"}
{"id":"a2","title":"bogus claim","file":"x.py","line":9,"severity":"S","producer_family":"alpha"}
EOS

# known-pair for the reject stage: a verifier that confirms a1 and rejects a2 must drop exactly a2
cat > "$D/v_ok.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"a1","verdict":"confirmed","why":"holds against source"}'
echo '{"id":"a2","verdict":"false-positive","why":"code does not do this"}'
EOS
chmod +x "$D/v_ok.sh"
python3 "$HERE/finding_verify.py" "$D/f.jsonl" --out "$D/o1" --verifier "sh $D/v_ok.sh" --family beta >"$D/s1" 2>&1; RC=$?   # 리터럴 경로 — new-code-anchor 가 «실행» 으로 센다
C=$(wc -l < "$D/o1/confirmed.jsonl" | tr -d ' '); DR=$(wc -l < "$D/o1/dropped.jsonl" | tr -d ' ')
{ [ "$RC" -eq 0 ] && [ "$C" = 1 ] && [ "$DR" = 1 ] && grep -q '"id": "a2"' "$D/o1/dropped.jsonl"; } \
  && ok "L4 거부 단계: false-positive 를 «코드가» 지운다 (confirmed 1 / dropped 1)" \
  || no "L4 거부 단계" "rc=$RC confirmed=$C dropped=$DR"

# 🟥 degrade: no verifier must NOT drop anything, must mark UNVERIFIED, must not exit 0
python3 "$VERIFY" "$D/f.jsonl" --out "$D/o2" --verifier "" --family none >"$D/s2" 2>&1; RC=$?
C=$(wc -l < "$D/o2/confirmed.jsonl" | tr -d ' '); DR=$(wc -l < "$D/o2/dropped.jsonl" | tr -d ' ')
{ [ "$RC" -eq 3 ] && [ "$C" = 2 ] && [ "$DR" = 0 ] && grep -q 'status=UNVERIFIED' "$D/s2"; } \
  && ok "L5 degrade: 검증기 없음 → 아무것도 안 지우고 UNVERIFIED · rc=3 (빈 dropped 가 «깨끗함»으로 안 읽힌다)" \
  || no "L5 degrade" "rc=$RC confirmed=$C dropped=$DR"

# a verifier that fails must degrade the same way, never drop
cat > "$D/v_fail.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
exit 7
EOS
chmod +x "$D/v_fail.sh"
python3 "$VERIFY" "$D/f.jsonl" --out "$D/o3" --verifier "sh $D/v_fail.sh" --family beta >"$D/s3" 2>&1; RC=$?
{ [ "$RC" -eq 3 ] && [ "$(wc -l < "$D/o3/dropped.jsonl" | tr -d ' ')" = 0 ] && grep -q 'verifier exit 7' "$D/s3"; } \
  && ok "L6 검증기 실패 → degrade + 사유가 요약줄에 남는다" || no "L6 검증기 실패" "rc=$RC · $(cat "$D/s3")"

# 🟥 the channel rule: a family never verifies its own findings, even when it answers
python3 "$VERIFY" "$D/f.jsonl" --out "$D/o4" --verifier "sh $D/v_ok.sh" --family alpha >"$D/s4" 2>&1; RC=$?
{ [ "$(wc -l < "$D/o4/dropped.jsonl" | tr -d ' ')" = 0 ] && grep -q 'unverified=2' "$D/s4"; } \
  && ok "L7 자기 계열은 자기 산출을 검증 못 한다 (verdict 있어도 드롭 0 · unverified 2)" \
  || no "L7 자기검증 차단" "rc=$RC · $(cat "$D/s4")"

# schema is enforced: a finding without a title is a usage error, not a silently skipped row
printf '{"id":"x1","file":"x.py"}\n' > "$D/bad.jsonl"
python3 "$VERIFY" "$D/bad.jsonl" --out "$D/o5" --verifier "sh $D/v_ok.sh" --family beta >"$D/s5" 2>&1; RC=$?
{ [ "$RC" -ne 0 ] && grep -q "missing required field" "$D/s5"; } \
  && ok "L8 스키마 위반은 «조용히 건너뛰기» 가 아니라 오류" || no "L8 스키마" "rc=$RC · $(cat "$D/s5")"

# L9 revert probe — remove the never-self-verify guard and L7 must go red
MUT="$D/verify_mut.py"
python3 - "$VERIFY" "$MUT" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
key = '        if f.get("producer_family") and f["producer_family"] == a.family:'
assert key in s, "guard line not found — the revert probe is pinned to a line that moved"
s = s.replace(key, '        if False:')
open(dst, "w", encoding="utf-8").write(s)
PY
python3 "$MUT" "$D/f.jsonl" --out "$D/o6" --verifier "sh $D/v_ok.sh" --family alpha >"$D/s6" 2>&1
{ [ "$(wc -l < "$D/o6/dropped.jsonl" | tr -d ' ')" = 1 ]; } \
  && ok "L9 되돌림: 가드를 지우면 자기 계열이 자기 것을 지운다 (레인이 실물을 잰다)" \
  || no "L9 되돌림" "가드를 지워도 드롭 0 — L7 은 장식이다"

/bin/rm -rf "$D"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && { echo "FAILED=0"; exit 0; } || { echo "FAILED=1"; exit 1; }
