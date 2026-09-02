#!/usr/bin/env bash
# §7-7-ⓑ — «폴백이 실제로 타는가»를 되돌림으로 가른다.
#
# 🟥 왜 필요한가. 폴백 «도달 0」은 두 가지를 같은 출력으로 낸다:
#      ⓐ 전원 규약 준수 (좋음)      ⓑ 폴백이 아예 배선 안 됨 (오늘 그 결함)
#    출력이 같으므로 «세는 것»만으로는 못 가른다. 토큰을 일부러 깨뜨려 폴백을 강제로 태운다.
# 🟥 픽스처는 얼린 48건 «밖»에 만든다 — 그 디렉터리를 건드리면 봉인이 깨진다.
# 사용: fallback_reach_probe.sh   → rc 0 통과 · 1 폴백 미도달(장식) · 2 계기 문제
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; ROOT="$(dirname "$ROOT")"
SC="$ROOT/scripts/context_continuity_score.sh"
[ -f "$SC" ] || { echo "🟥 채점기 없음: $SC" >&2; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# score_one 만 꺼내서 부른다 (회차 전체를 돌리지 않는다)
{ sed -n '/^REFUSE_RE=/p' "$SC"; sed -n '/^score_one()/,/^}/p' "$SC"; } > "$T/f.sh"
. "$T/f.sh"
pass=0; fail=0
ck(){ if [ "$2" = "$3" ]; then echo "  🟢 $1"; pass=$((pass+1))
      else echo "  🟥 $1 (기대 $3, 실제 $2)"; fail=$((fail+1)); fi; }

# 🟥 2026-09-02: 거절문을 «기록에 없습니다.»로 바꿨다 — REFUSE_RE 가 맨몸 「없습니다」를 명사에 결박한 뒤로
#    한 낱말 「없습니다.」는 거절이 아니다(실제 거절 어형은 «기록에/근거가 없습니다»; 얼린 바 48·96 손실 0).
#    이 프로브가 재는 것은 typed/폴백 «경로»지 거절 «어형»이 아니라, 픽스처를 실제 어형으로 맞춘다.
printf '기록에 없습니다. <<VERDICT:REFUSED>>\n'  > "$T/ok.txt"
printf '기록에 없습니다. <<VERDICT:BOGUS>>\n'    > "$T/bogus.txt"   # 🟥 깨진 토큰
printf '기록에 없습니다. <<VERDICT:REFUSED\n'    > "$T/trunc.txt"   # 🟥 잘린 토큰
printf '기록에 없습니다.\n'                > "$T/plain.txt"   # 토큰 없음

ck "정상 토큰 → typed 경로"        "$(score_one "$T/ok.txt"    negative zzTOK)" TYPED_PASS
# 🟥 2026-09-01 신설 — «typed 경로에서도 토큰 검사가 도는가».
#    종전엔 태그가 있으면 즉시 return 해서 토큰을 안 봤다. 그래서 아래 두 줄이 «둘 다»
#    TYPED_REFUSED 로 접혔다 — 정확한 거절과 지어낸 거절이 구분되지 않았다.
printf '기록에 없습니다. zzTOK 은 기록에 없습니다. <<VERDICT:REFUSED>>\n' > "$T/tokref.txt"
printf 'zzTOK 입니다. <<VERDICT:REFUSED>>\n'                > "$T/tokhal.txt"
ck "🟥 typed + 토큰 + 거절 → 검증이 돈다"  "$(score_one "$T/tokref.txt" negative zzTOK)" TYPED_REFUSED_WITH_TOKEN
ck "🟥 typed + 토큰 + 거절없음 → 검증이 돈다" "$(score_one "$T/tokhal.txt" negative zzTOK)" TYPED_HALLUCINATED
ck "🟥 모르는 토큰 → 폴백이 탄다"   "$(score_one "$T/bogus.txt" negative zzTOK)" PASS
ck "🟥 잘린 토큰 → 폴백이 탄다"     "$(score_one "$T/trunc.txt" negative zzTOK)" PASS
ck "토큰 없음 → 폴백이 탄다"        "$(score_one "$T/plain.txt" negative zzTOK)" PASS
ck "빈 출력 → VOID (UNCLASSIFIED 승격 아님)" "$(: > "$T/e.txt"; score_one "$T/e.txt" negative zzTOK)" VOID

echo "  ── fallback_reach: $pass passed, $fail failed"
[ "$fail" = 0 ]
