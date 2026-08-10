#!/usr/bin/env bash
# test_env_purity_lanes.sh — env_purity_scan known-pair (샌드박스 픽스처)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB=$(mktemp -d); trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/scripts" "$SB/knowledge/shared" "$SB/templates" "$SB/plugins" "$SB/.claude/rules"
cp "$HERE/env_purity_scan.sh" "$SB/scripts/"
printf 'planted-env-token\n' > "$SB/scripts/.env_purity_tokens.defaults"
echo 'methodology steel-quench doc' > "$SB/knowledge/shared/doc.md"
git -C "$SB" init -q && git -C "$SB" add -A && git -C "$SB" -c user.email=t@t -c user.name=t commit -qm f

pass=0; fail=0
lane(){ local name="$1" want_rc="$2" want_grep="$3"; shift 3
  out=$("$@" 2>&1); rc=$?
  if [ "$rc" = "$want_rc" ] && { [ -z "$want_grep" ] || echo "$out" | grep -q "$want_grep"; }; then
    echo "  ✅ $name"; pass=$((pass+1))
  else echo "  ❌ $name (rc=$rc)"; echo "$out" | tail -2; fail=$((fail+1)); fi
}
lane "①음성(토큰 무히트)=0+✅" 0 "환경-전용 토큰 0" bash "$SB/scripts/env_purity_scan.sh" "$SB"
echo 'uses planted-env-token here' >> "$SB/knowledge/shared/doc.md"; git -C "$SB" add -A; git -C "$SB" -c user.email=t@t -c user.name=t commit -qm p
lane "②양성(토큰 1파일)=보고" 0 "planted-env-token.*1 파일" bash "$SB/scripts/env_purity_scan.sh" "$SB"
printf 'local-org-token\n' > "$SB/.claude/rules/.env-purity-tokens"
echo 'has local-org-token' > "$SB/templates/t.md"; git -C "$SB" add templates; git -C "$SB" -c user.email=t@t -c user.name=t commit -qm l
lane "③로컬 토큰층 합산" 0 "local-org-token.*1 파일" bash "$SB/scripts/env_purity_scan.sh" "$SB"
rm "$SB/scripts/.env_purity_tokens.defaults"
lane "④기본목록 부재=판정불가" 10 "판정 불가" bash "$SB/scripts/env_purity_scan.sh" "$SB"
printf 'x\n' > "$SB/scripts/.env_purity_tokens.defaults"
rm "$SB/knowledge/shared/doc.md"; git -C "$SB" add -A; git -C "$SB" -c user.email=t@t -c user.name=t commit -qm c
lane "⑤컨트롤 사망=판정불가(무효 선언)" 10 "컨트롤 사망" bash "$SB/scripts/env_purity_scan.sh" "$SB"
echo "env-purity lanes: $pass pass / $fail fail"; [ "$fail" = 0 ]
