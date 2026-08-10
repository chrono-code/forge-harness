#!/usr/bin/env bash
# rtk_gross_ablation.sh — RTK gross-savings ablation
# provenance: pmh-dev@cbe3932 역수확(2026-08-10). FH 의 context-doctor 가 벤더 주장(~60-90%)만
#   인용하던 자리에 실측 계기를 공급 — Step 0 계기검증(필터가 에러로 죽어 스텁을 뱉으면
#   허위 절감률이 나오는 실측 사례) 내장.
# RTK gross-savings ablation — run in an env where RTK ACTUALLY filters (rtk gain 이 실절감을 보이는 곳).
# Measures raw vs rtk-filtered output TOKENS across representative read-only dev commands.
#
# ⚠️ INSTRUMENT CHECK included: FH 외부 세션(2026-07-07)서 rtk 필터가 "No such file"로
#    에러 죽으며 46자 스텁을 뱉어 "82~100% cut" 허위결과가 나왔음. 계측기부터 검증한다.
# ⚠️ NET(맥락손실)은 이 스크립트가 아님 — graded 품질 프로브(턴수·교정·정답률) 별도.
# ⚠️ 판정/검증 태스크엔 RTK 미적용(verdict 오염) — 여기 태스크셋은 전부 read-only non-verdict.
set -u
# 근사 주의: wc -c / 4 = char 근사(밀도 균일 가정) — 필터 출력은 경로·해시 위주라 절감률이
# **과대측 방향**으로 치우칠 수 있다. 부호는 안전하나 «밴드 정합» 판정엔 오차 감안.
# 해석부 상수(~20-30% 슬라이스 비중 · 15-25% 밴드 · RATE)는 원 필드 보고서 유래의 «가정» — 출처: provenance 커밋.
RTK="${RTK:-$(command -v rtk || echo "$HOME/.headroom/bin/rtk")}"
REPO="${1:-$PWD}"
RATE="${RATE:-1.82}"   # $/1M tokens — 측정 블렌디드(Token Checker). 필요시 override.
cd "$REPO" 2>/dev/null || { echo "repo 없음: $REPO"; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "git 레포 아님: $REPO — git 커맨드 태스크셋이 무의미(과소측 방향 오결론)"; exit 1; }

# --- 0. 계측기 검증: rtk가 실제로 FILTER하나 (에러 아님) ---
praw=$(git status 2>&1); prtk=$("$RTK" git status 2>&1)
if echo "$prtk" | grep -qiE "no such file|os error|not found|error\]" \
   && ! echo "$praw" | grep -qiE "no such file"; then
  echo "❌ RTK 필터 비작동 (rtk git status 에러): $prtk"
  echo "   → rtk 설정/환경 의존. 'rtk gain' 이 실절감을 보이는 env 에서 돌려라."
  exit 2
fi
echo "✅ rtk 필터 작동 확인 — 진행."; echo ""

# --- 태스크셋 (read-only, non-verdict, RTK가 타깃하는 dev 출력) ---
# ⚠️ CMDS 에 quote/pipe/glob 든 커맨드 추가 금지 — raw(eval) 와 rtk(word-split) 실행 경로가
#    비대칭이라 다른 커맨드를 재게 된다.
CMDS=("git status" "git log --oneline -150" "git diff HEAD~20" "git branch -a" "ls -la")
tot_r=0; tot_k=0
printf "%-28s %9s %9s %6s\n" "command" "raw_tok" "rtk_tok" "cut%"
printf -- "----\n"
for c in "${CMDS[@]}"; do
  r=$(( $(eval "$c" 2>&1 | wc -c) / 4 ))      # ~4 chars/token 근사(헤더 주의 참조)
  kout=$("$RTK" $c 2>&1)
  # per-command 계기검증 — Step 0 은 env 고장만 닫는다. 행 단위 rtk 에러/스텁은 여기서 잡아
  # 총계에서 제외(허위 절감의 역사적 형태: 에러 스텁 → 82~100% 허위 컷).
  if echo "$kout" | grep -qiE "no such file|os error|not found|error\]|panicked at" \
     && ! eval "$c" 2>&1 | grep -qiE "no such file|os error|not found"; then
    printf "%-28s %9d %9s %6s\n" "$c" "$r" "FAIL" "제외"
    continue
  fi
  k=$(( $(printf '%s' "$kout" | wc -c) / 4 ))
  cut=$(awk "BEGIN{if($r>0)printf \"%.0f\",($r-$k)/$r*100;else print 0}")
  printf "%-28s %9d %9d %5s%%\n" "$c" "$r" "$k" "$cut"
  tot_r=$((tot_r+r)); tot_k=$((tot_k+k))
done
printf -- "----\n"
gross=$(awk "BEGIN{if($tot_r>0)printf \"%.1f\",($tot_r-$tot_k)/$tot_r*100;else print 0}")
saved_tok=$((tot_r-tot_k))
echo "GROSS (커맨드/툴-출력 슬라이스): raw=$tot_r tok · rtk=$tot_k tok · 절감=$gross%"
echo ""
echo "해석:"
echo "  • 이건 커맨드/툴-출력 *슬라이스만*의 절감률 (세션 전체의 ~20-30%)."
echo "  • 청구서 전체 gross ≈ (슬라이스 비중) × $gross%  → 보고서 15-25% 밴드와 대조."
echo "  • \$ 환산: 절감 토큰 × \$$RATE/1M = 슬라이스 절감액."
echo "  • NET(맥락손실)은 미측정 — gross만으론 net+ 단정 금지(조용한 오답 리스크)."
