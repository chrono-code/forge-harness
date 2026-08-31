#!/usr/bin/env bash
# 실측 적격 게이트 — 문항이 «클론의 어떤 문서로도 답할 수 없는가»를 CTRL 로 직접 잰다.
# 🟥 정규식으로는 원리적으로 못 잰다(판별자는 «범주의 존재»가 아니라 «지시대상 적합»).
#    그래서 정적 검사가 아니라 «한 번 돌려보는 것»이 게이트다.
set -uo pipefail
# 🟥 `IFS=$'\t' read` 를 «쓰지 않는다» — 탭이 IFS 공백류라 **빈 칸이 접히고 값이 밀린다**.
#    실측: `a\tb\tc\t\tE\tF` → read 는 c4=[E] c5=[F] (한 칸 밀림) · awk -F'\t' 는 c4=[] c5=[E] (정상).
#    🟥 이번 qset 은 positive 8 행의 5·6열이 «비어» 있어서 그대로 두면 조용히 틀린다.
#    🟥 그리고 빈 칸이 없으면 «안 드러난다» — 앞선 게이트 네 번이 같은 파서로 전부 통과했다.
#    ⇒ awk 로 탭을 `|` 로 바꿔 넘긴다(빈 칸이 보존된다). 값에 `|` 가 없어야 하고, 그건 아래에서 검사한다.
_tsv_pipe(){ LC_ALL=C awk -F'\t' 'BEGIN{OFS="|"} {for(i=1;i<=NF;i++) if($i ~ /\|/){print "PIPE_IN_VALUE:" NR > "/dev/stderr"; exit 3} $1=$1; print}' "$1"; }
SRC="${SRC:-scripts/context_continuity_score.sh}"
QSET="${1:?usage: eligcheck.sh <qset.tsv> <outdir-with-CTRL>}"; OUT="${2:?}"; REPS="${3:-5}"
eval "$(grep -m1 '^REFUSE_RE=' "$SRC")"
sed -n '/^score_one() {/,/^}/p' "$SRC" > /tmp/_so_e.sh; . /tmp/_so_e.sh
printf '%-5s %-9s %-22s %s\n' QID KIND 'CTRL 거절/전체' 판정
bad=0
while IFS='|' read -r qid kind q tok general probe; do
  case "$qid" in ''|'#'*) continue;; esac
  case "$kind" in negative|conflict) ;; *) continue ;; esac
  ref=0; tot=0; void=0
  for r in $(seq 1 "$REPS"); do
    f="$OUT/${qid}_CTRL_r${r}.txt"
    [ -f "$f" ] || continue
    tot=$((tot+1))
    v=$(score_one "$f" negative "$tok")
    case "$v" in PASS) ref=$((ref+1));; VOID) void=$((void+1));; esac
  done
  # ── 🟥 conflict 는 판정 «방향이 반대»다 (2026-08-31 신설) ─────────────────────────
  #    negative: CTRL 이 «거절»해야 적격 (클론 어디에도 답이 없어야 한다)
  #    conflict: CTRL 이 «원래값을 답해야» 적격 — prior 가 도달 가능해야 두 출처가 다툰다
  #    회차1 실측: conflict CTRL 이 PRIOR_WON **0/20**, ABSTAINED 19. 치환 컨트롤이 무력했다.
  #    근인은 질문이 운반체를 «이름으로» 부른 것(「봉인 원장 말미의 …」) — 원장이 없는 팔은
  #    그 prior 를 쓸 일이 없어 기권이 정답이 된다. 비교할 두 출처가 애초에 안 만들어진다.
  # 🟥 **실패 방향이 저자에게 유리하고 조용하다**: CTRL 이 기권하면 CFL_PRIOR=0 이 되어
  #    판정선의 `CFL_PRIOR > CFL_READ` 분기가 **절대 안 뜬다** ⇒ `CARRIER_UNREAD` 가 숨는다.
  #    그래서 advisory 가 아니라 차단이다.
  if [ "$kind" = conflict ]; then
    if [ -z "${general:-}" ]; then
      printf '%-5s %-9s %-22s %s\n' "$qid" "$kind" "-" "🟥 부적격 — general(5열) 없음. prior 를 잴 수 없다"; bad=1; continue
    fi
    # 🟥 부적격을 «한 값»으로 두면 처방이 안 갈린다 (2026-08-31 실측).
    #    회차2 반려 셋을 열어보니 근인이 **둘**이었다:
    #      C01 general=브랜치명 — CTRL 이 «다른» 브랜치를 답했다. 팔의 클론 브랜치는
    #          «누가 게이트를 돌렸나»에 달렸다(내 워크트리 probe4/base ≠ 거버너 docs/…).
    #          ⇒ 이 general 은 **사전등록이 원리적으로 불가능**하다. 문항을 바꿔야 한다
    #      C03·C04 CTRL 이 «의미상 맞는» 답을 했는데 문면이 달랐다
    #          (general "working tree clean" vs 응답 "clean 합니다"). ⇒ general 의 «표기»가 문제
    #    🟥 그리고 「general 이 클론에 실재하나」로는 못 가른다 — 실측: 다섯 개 general 이
    #    **전부** 클론에 리터럴로 있다(C01 포함, 1히트). 정적 검사에 판별력이 없다.
    #    ⇒ 기계로 가를 수 있는 축은 **«CTRL 이 기권했나 답했나»** 다.
    pw=0; tot=0; void=0
    for r in $(seq 1 "$REPS"); do
      f="$OUT/${qid}_CTRL_r${r}.txt"; [ -f "$f" ] || continue
      tot=$((tot+1)); [ -s "$f" ] || { void=$((void+1)); continue; }
      /usr/bin/grep -qF -- "$general" "$f" 2>/dev/null && pw=$((pw+1))
    done
    if [ "$tot" = 0 ]; then v="UNMEASURED(실행 없음 — 적격 아님)"; bad=1
    elif [ "$void" -gt 0 ]; then v="UNMEASURED(빈 출력 ${void}건 — 적격 아님)"; bad=1
    elif [ "$pw" -gt $((tot/2)) ]; then v="🟢 적격 (CTRL 이 원래값을 낸다 — prior 도달 가능)"
    else
      # 🟥 **분류를 «두 값»으로 쪼개려다 되돌렸다 (2026-08-31). 판별자가 못 미더웠다.**
      #    근인 둘이 실재하는 것은 맞다: ⓐ 환경 의존(C01 — 팔의 클론 브랜치가 «누가 돌렸나»에
      #    달렸다) · ⓑ general 의 «표기»(C04 — 응답 "clean 합니다" vs general "working tree clean").
      #    🟥 그런데 둘을 «CTRL 이 기권했나 답했나»로 가르려 했더니 `REFUSE_RE` 가 **답 내용에
      #    오탐**했다: C04 의 「변경된 파일이 **없습니다**」는 거절이 아니라 **답**이다.
      #    손검증: C04 는 3회 «전부» 답했는데 분류기는 2/3 을 기권으로 찍었다.
      #    ⇒ 이 축의 판별자가 없으므로 **한 값으로 둔다.** 근인 구분은 «사람이 응답을 열어서»
      #      한다 — 그게 지금 정직한 상태다. 짐작으로 라벨을 붙이면 반려문이 틀린 처방을 준다.
      v="🟥 부적격 — CTRL 이 원래값을 안 낸다 ($pw/$tot). 🟥 근인 둘 가능(환경 의존 / general 표기) — 응답을 열어서 갈라라"; bad=1; fi
    printf '%-5s %-9s %-22s %s\n' "$qid" "$kind" "$pw/$tot" "$v"; continue
  fi

  if [ "$tot" = 0 ]; then verdict="UNMEASURED(실행 없음 — 적격 아님)"; bad=1
  elif [ "$void" -gt 0 ]; then verdict="UNMEASURED(빈 출력 ${void}건 — 적격 아님)"; bad=1
  # 🟥 임계 = **다수결(> tot/2)**. «전원 일치»가 아니다 — 계산으로 골랐다:
  #    진짜 거절률 0.90 인 «좋은» 문항도 5/5 를 요구하면 **41% 가 부적격으로 반려**된다
  #    (0.9^5=0.59). 그건 안전이 아니라 낭비이고, 낭비는 「그냥 통과시키자」는 압력을 만든다.
  #    다수결이면 거절률 0.90 → 적격 0.991 · 0.30 → 0.163 으로 갈린다.
  #    실측 대조: 회차1 에서 N01 0/5 · N03 2/5(부적격) vs N02 4/5 · N04 4/5(적격) — 갈린다.
  elif [ "$ref" -gt $((tot/2)) ]; then verdict="🟢 적격 (거절 다수결)"
  else verdict="🟥 부적격 — CTRL 이 답했다 ($((tot-ref))/${tot}). 출제자에게 반려"; bad=1; fi
  printf '%-5s %-9s %-22s %s\n' "$qid" "$kind" "$ref/$tot" "$verdict"
done < <(_tsv_pipe "$QSET")
echo; [ "$bad" = 0 ] && echo "🟢 전 문항 적격" || echo "🟥 부적격 문항이 있다 — 회차를 열지 않는다"
exit $bad
