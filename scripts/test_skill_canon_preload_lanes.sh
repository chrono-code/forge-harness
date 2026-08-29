#!/usr/bin/env bash
# test_skill_canon_preload_lanes.sh — field_canon_preload.sh 의 «스킬-정본» 분기 앵커.
#
# 이 분기가 존재하는 이유(실측 2026-08-28): 어느 세션이 preprep 의 정본 파일을 **하나도 안
# 열고 44판을 구웠고**, 선 굵기 토큰 위반이 388/907(43%) 났다. 자산이 없어서가 아니라
# **안 읽혀서**다. 훅은 이미 있었고 preprep 이 커버리지 경계 밖이었다.
#
# 재는 것 넷:
#   S1 발화        발표 어휘가 오면 preprep 정본을 띄우나
#   S2 오탐 0      무관한 프롬프트에는 조용한가
#   S3 파일 이름   «정본을 읽어라» 훈계가 아니라 **파일 이름 + 줄 수**를 내나
#                  🟥 이게 없으면 원 훅이 자기 헤더에서 금지한 «일반 훈계»가 된다
#   S4 세션 1회    두 번째 호출은 조용한가 (반복 알림은 무시를 학습시킨다)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$HERE/scripts/field_canon_preload.sh"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }
[ -f "$HOOK" ] || { echo "  ❌ INSTRUMENT ERROR — 훅 부재: $HOOK"; exit 1; }

SD=$(mktemp -d); trap 'rm -rf "$SD"' EXIT
# 🟥 `CLAUDE_PROJECT_DIR` 을 «반드시» 준다. 안 주면 훅이 `$HOME/projects/forge-harness` 로
#    떨어지는데 CI 러너엔 그 경로가 없어 **조용히 침묵**한다 — 로컬 4/4 · CI 2/4 가 그렇게 났다.
#    S2·S4 는 아무것도 안 나와도 통과하는 검사라, 그 조합이 «훅이 통째로 안 돈다»의 서명이다.
run(){ rm -rf "$SD/s"; mkdir -p "$SD/s"
       CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/s" bash "$HOOK" <<EOF 2>&1
{"prompt":"$1"}
EOF
}

pos=$(run "발표 자료 만들어줘")
neg=$(run "오늘 날씨 어때")
echo "$pos" | grep -q "skill-canon" && ok "S1 발화: 발표 어휘 → preprep 정본 안내" \
                                    || ng "S1 미발화 — 배선 안 된 코드는 산문이다"
# 🟥 S0 먼저 — «훅이 아예 안 돈다» 를 S2·S4 가 조용히 통과시키는 구멍을 막는다.
#    둘은 «아무 출력도 없음» 에서도 초록이라, 그 조합만으로는 침묵과 정상을 못 가른다.
[ -n "$pos" ] && ok "S0 훅이 출력을 냈다 (침묵을 통과로 안 읽는다)" \
              || ng "S0 훅이 아무것도 안 냈다 — 환경(CLAUDE_PROJECT_DIR)이나 배선을 봐라"
echo "$neg" | grep -q "skill-canon" && ng "S2 오탐: 무관한 프롬프트에도 뜬다" \
                                    || ok "S2 오탐 0"
echo "$pos" | grep -qE "presentation_checklist\.md \([0-9]+줄\)" \
  && ok "S3 파일 이름 + 줄 수를 낸다 (일반 훈계가 아니다)" \
  || ng "S3 실패 — 파일을 안 짚으면 «정본을 읽어라» 훈계이고, 그건 이 훅이 금지한 형태다"

rm -rf "$SD/t"; mkdir -p "$SD/t"
CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/t" bash "$HOOK" <<'EOF' >/dev/null 2>&1
{"prompt":"발표 준비"}
EOF
again=$(CLAUDE_PROJECT_DIR="$HERE" FIELD_CANON_SENTINEL_DIR="$SD/t" bash "$HOOK" <<'EOF' 2>&1
{"prompt":"발표 준비"}
EOF
)
echo "$again" | grep -q "skill-canon" && ng "S4 재나그: 두 번째도 뜬다 — 무시를 학습시킨다" \
                                      || ok "S4 세션당 1회"

echo "skill-canon lanes: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
