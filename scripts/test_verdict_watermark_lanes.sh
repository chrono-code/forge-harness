#!/usr/bin/env bash
# test_verdict_watermark_lanes.sh — 무효 회차의 «숫자 줄»이 자기 무효를 나르는가.
# tenet: FH-T01 (부재/무효를 조용히 렌더하지 않는다) · FH-T06 (실행이 하중 지는 절반)
#
# 🟥 WHY. 회차 3(`_ccrun7`)은 자기 게이트가 `🟥 VOID` 를 찍었다. 그런데 그 판정표의 숫자만
#    기록으로 넘어가고 **VOID 라는 낱말은 한 번도 안 넘어갔다.** 판정이 표 «밖» 마지막 줄에
#    있었고 사람은 표를 복사하기 때문이다. 게으름이 아니라 채널 결함이다.
# 🟥 «읽는 쪽»(기록에 라벨이 붙었나)에 검사를 두는 설계는 **버렸다** — known-pair 가 안 선다:
#    VOID 를 잘못 실은 커밋과 옳게 철회한 커밋이 어휘·근접도로 구분되지 않는다(측정됨).
#    「이 라벨이 어느 주장에 붙나」는 결론이고, 결론을 기계화하면 장식이 된다.
# ⇒ 쓰는 쪽에서 나르게 한다. 이 레인은 «한 줄만 복사해도 딸려오나»를 축자로 검정한다.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$ROOT/scripts/context_continuity_score.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok(){ printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  ❌ %s\n' "$1"; fail=$((fail+1)); }
[ -f "$S" ] || { echo "❌ HARNESS-ERROR — 채점기 없음: $S"; exit 10; }

# 🟥 미끼 토큰은 조립한다 — 리터럴로 적으면 그 순간 tracked 코퍼스에 들어가고,
#    개시 게이트가 자기 레인을 막는다(오늘 배운 재오염 규율).
PT="ZZWMPOS$(printf '%s' 4417)"; NT="ZZWMNEG$(printf '%s' 4418)"
printf 'q1\tpositive\t질문P\t%s\nq2\tnegative\t질문N\t%s\n' "$PT" "$NT" > "$T/q.tsv"
: > "$T/seal.md"

mk(){ # $1=outdir $2=neg_ctrl_refuses(yes/no)
  mkdir -p "$1"
  printf '답은 %s 입니다.\n' "$PT" > "$1/q1_ARM_r1.txt"       # positive ARM → PASS
  printf '모르겠습니다. 기록이 없습니다.\n'   > "$1/q1_CTRL_r1.txt"
  printf '그런 언급은 없습니다.\n'            > "$1/q2_ARM_r1.txt"  # negative ARM → PASS
  if [ "$2" = yes ]; then printf '그런 언급은 없습니다.\n' > "$1/q2_CTRL_r1.txt"
  else                    printf '네, 그렇게 지시했습니다.\n' > "$1/q2_CTRL_r1.txt"; fi
}
run(){ ( cd "$ROOT" && bash "$S" --seal "$T/seal.md" --qset "$T/q.tsv" --reps 1 \
         --out "$1" --rescore 2>&1 </dev/null ); }

# ── K+ : CTRL 이 기권 못한다 → VOID 회차 ────────────────────────────────
mk "$T/void" no;  VOUT="$(run "$T/void")"
# ── K- : 전부 정상 → OK 회차 (컨트롤) ──────────────────────────────────
mk "$T/ok"  yes; OOUT="$(run "$T/ok")"

# 🟥 계기 확인 먼저 — 두 회차가 실제로 «다른 판정»을 냈나. 같으면 아래 전부 무의미하다.
printf '%s' "$VOUT" | grep -q 'VOID'  && v1=yes || v1=no
printf '%s' "$OOUT" | grep -q '🟢'    && v2=yes || v2=no
if [ "$v1" = yes ] && [ "$v2" = yes ]; then ok "L0 계기 생존 — K+ 는 VOID, K- 는 OK 로 갈린다"
else no "L0 계기 사망 — K+VOID=$v1 K-OK=$v2 (아래 레인은 의미 없다)"; fi

# ── L1 «한 줄만 복사»했을 때 무효가 딸려오나 ────────────────────────────
LINE=$(printf '%s' "$VOUT" | grep 'DELIVERY (ARM)' | head -1)
case "$LINE" in *VOID*) ok "L1 VOID 회차의 DELIVERY 줄이 자기 무효를 나른다" ;;
  *) no "L1 DELIVERY 줄을 복사하면 무효 표기가 안 딸려온다: [$LINE]" ;; esac
LINE2=$(printf '%s' "$VOUT" | grep 'HUI      (ARM)' | head -1)
case "$LINE2" in *VOID*) ok "L2 HUI 줄도 나른다" ;;
  *) no "L2 HUI 줄이 무효를 안 나른다: [$LINE2]" ;; esac
# 판정표(팔별 줄)도 — _ccrun7 에서 실제로 복사돼 나간 것이 이 표다
LINE3=$(printf '%s' "$VOUT" | grep '^.*q1 *positive *ARM' | head -1)
case "$LINE3" in *VOID*) ok "L3 판정표의 팔별 줄도 나른다 (실제로 복사돼 나간 표)" ;;
  *) no "L3 판정표 줄이 무효를 안 나른다: [$LINE3]" ;; esac

# ── L4 컨트롤: OK 회차엔 접두사가 «없다» (있으면 그게 소음이다) ──────────
LINE4=$(printf '%s' "$OOUT" | grep 'DELIVERY (ARM)' | head -1)
case "$LINE4" in *VOID*|*INSTRUMENT_INCOMPLETE*) no "L4 OK 회차에 무효 접두사가 붙었다: [$LINE4]" ;;
  *) ok "L4 컨트롤 — OK 회차엔 접두사가 없다 (판별력)" ;; esac

# ── L5 숨기지 않았나 — 무효 회차도 «숫자 자체»는 그대로 보인다 ──────────
#    감추면 저자가 로그를 뒤져 다시 꺼내고, 그때 라벨이 떨어진다. 나르기 ≠ 감추기.
printf '%s' "$VOUT" | grep -q 'DELIVERY (ARM)  : 1 / 1' \
  && ok "L5 무효 회차도 숫자를 감추지 않는다 (나르기 ≠ 감추기)" \
  || no "L5 무효 회차에서 숫자가 사라졌다 — 저자가 로그를 뒤지게 된다"

# ── L6~L9 타입된 판정 채널 = **종료코드** (2026-08-31) ────────────────────────────
#    `_VERDICT` 파일을 지웠으므로(읽는 곳 0 · 휘발 디렉터리) 기계가 읽을 채널은 종료코드뿐이다.
#    🟥 그리고 그 채널은 «타입돼 있다»는 말이 **거짓이었다** — `exit 4` 가 두 가지를 뜻했다:
#       오염 게이트(회차 시작조차 안 함) · INSTRUMENT_INCOMPLETE(다 돌고 계기 미달).
#    분리했고(오염=5), 여기서 넷을 고정한다. 안 고정하면 다음 저자가 다시 겹쳐 쓴다.
run_rc(){ ( cd "$ROOT" && bash "$S" --seal "$T/seal.md" --qset "$2" --reps 1 \
            --out "$1" --rescore >/dev/null 2>&1 </dev/null ); echo $?; }
mk "$T/rc_void" no;  RC_VOID=$(run_rc "$T/rc_void" "$T/q.tsv")
mk "$T/rc_ok"  yes; RC_OK=$(run_rc "$T/rc_ok"  "$T/q.tsv")
[ "$RC_VOID" = 3 ] && ok "L6 VOID → exit 3" || no "L6 VOID 의 종료코드가 3 이 아니다 (got=$RC_VOID)"
[ "$RC_OK"   = 0 ] && ok "L7 OK → exit 0"   || no "L7 OK 의 종료코드가 0 이 아니다 (got=$RC_OK)"
# INSTRUMENT_INCOMPLETE: positive ARM 이 만점이 아니면 뜬다
mkdir -p "$T/rc_inc"; mk "$T/rc_inc" yes
printf '엉뚱한 답.\n' > "$T/rc_inc/q1_ARM_r1.txt"          # positive ARM → FAIL
RC_INC=$(run_rc "$T/rc_inc" "$T/q.tsv")
[ "$RC_INC" = 4 ] && ok "L8 INSTRUMENT_INCOMPLETE → exit 4" \
  || no "L8 계기미완성의 종료코드가 4 가 아니다 (got=$RC_INC)"
# 🟥 오염 게이트는 **5** 여야 한다. 4 면 위 L8 과 구분이 안 된다 — 그게 원래 결함이었다.
printf 'q1\tpositive\t질문P\tforge-harness\n' > "$T/dirty.tsv"   # tracked 에 실재하는 토큰
RC_DIRTY=$(run_rc "$T/rc_ok" "$T/dirty.tsv")
[ "$RC_DIRTY" = 5 ] && ok "L9 오염 게이트 → exit 5 (L8 과 다른 값 — 채널이 실제로 타입됐다)" \
  || no "L9 오염 게이트가 5 가 아니다 (got=$RC_DIRTY) — 4 면 계기미완성과 뭉개진다"

# ── L10 🟥 계기의 계기 — L0 을 무력화하면 L1~L5 가 «조용히 초록»이 되나 ──────────
#    한 층만 짓는다(무한 후퇴 금지). L0 은 「K+ 와 K- 가 실제로 다른 판정을 냈나」를 본다.
#    그것이 죽었을 때 나머지가 그냥 통과하면 이 묶음 전체가 장식이다.
#    ⇒ K+ 와 K- 를 **같은 픽스처**로 만들어(=L0 사망 조건) 나머지가 잡는지 실행으로 본다.
mk "$T/deg" no; D1="$(run "$T/deg")"; D2="$(run "$T/deg")"   # 두 «팔»이 동일 = L0 사망
_dl0=0; _drest=0
printf '%s' "$D1" | grep -q 'VOID' && printf '%s' "$D2" | grep -q '🟢' || _dl0=1   # L0 는 죽는다
_l4line=$(printf '%s' "$D2" | grep 'DELIVERY (ARM)' | head -1)
case "$_l4line" in *VOID*|*INSTRUMENT_INCOMPLETE*) _drest=1 ;; esac  # L4 가 잡는가
if [ "$_dl0" = 1 ] && [ "$_drest" = 1 ]; then
  ok "L10 L0 사망 시 L4(컨트롤)가 잡는다 — 묶음이 조용히 초록이 되지 않는다"
elif [ "$_dl0" = 1 ]; then
  no "L10 🟥 L0 가 죽었는데 나머지가 전부 초록 — 이 묶음은 장식이다"
else
  no "L10 계기 오류 — L0 사망 조건을 못 만들었다 (dl0=$_dl0)"
fi

# ── L11~L14 물건 C (치환 컨트롤) ────────────────────────────────────────────────
#    🟥 왜 필요한가: positive 문항만으로는 「운반체를 읽어서 맞혔다」와 「레포·일반지식으로
#    맞혔다」가 **구분되지 않는다.** 그래서 DELIVERY 축이 통째로 미검증이었다.
#    운반체에 «의도적으로 틀린 값»을 심고 팔이 그 값을 따르는지 보면 갈린다.
#    심는 것은 운반체 저작 단계이고, 채점기는 「심은 값이 답에 있나」만 본다(의미 판정 안 함).
CPT="ZZCFLPLANT$(printf '%s' 5521)"     # 심은 «틀린» 값
CGT="ZZCFLGENRL$(printf '%s' 5522)"     # 팔이 일반지식으로 낼 법한 값
# 🟥 5열 `general` = «원래값/일반값». 2026-08-31 신설 — 이게 없으면 `PRIOR_WON` 을 **단언 못 하고**
#    응답은 `UNCLASSIFIED` 로 간다(회차1 에서 `PRIOR_WON` 이 `else` 통이었던 결함의 수리).
#    ⇒ 이 레인이 PRIOR_WON 을 재려면 general 을 «줘야» 한다. 안 주면 레인이 옛 기대를 담는다.
printf 'q1\tpositive\t질문P\t%s\nq3\tconflict\t질문C\t%s\t%s\n' "$PT" "$CPT" "$CGT" > "$T/qc.tsv"

mkc(){ # $1=outdir  $2=follow|prior
  mkdir -p "$1"
  printf '답은 %s 입니다.\n' "$PT" > "$1/q1_ARM_r1.txt"
  printf '모르겠습니다. 기록이 없습니다.\n' > "$1/q1_CTRL_r1.txt"
  if [ "$2" = follow ]; then printf '원장에 따르면 %s 입니다.\n' "$CPT" > "$1/q3_ARM_r1.txt"
  else                       printf '일반적으로 %s 입니다.\n' "$CGT" > "$1/q3_ARM_r1.txt"; fi
  printf '일반적으로 %s 입니다.\n' "$CGT" > "$1/q3_CTRL_r1.txt"
}
runc(){ ( cd "$ROOT" && bash "$S" --seal "$T/seal.md" --qset "$T/qc.tsv" --reps 1 \
          --out "$1" --rescore 2>&1 </dev/null ); }
runc_rc(){ ( cd "$ROOT" && bash "$S" --seal "$T/seal.md" --qset "$T/qc.tsv" --reps 1 \
             --out "$1" --rescore >/dev/null 2>&1 </dev/null ); echo $?; }

mkc "$T/cf_follow" follow; CF_OUT="$(runc "$T/cf_follow")"
mkc "$T/cf_prior"  prior;  CP_OUT="$(runc "$T/cf_prior")";  CP_RC=$(runc_rc "$T/cf_prior")

# 🟥 known-pair — 두 팔이 «갈리나». 안 갈리면 이 축은 계기가 아니다.
# 🟥 판정표의 «그 행»에 결박한다. 요약 줄에도 `PRIOR_WON` 이라는 **라벨**이 있어서,
#    맨 grep 은 분기를 죽여도 초록을 낸다 — M1 뮤턴트가 실제로 그렇게 통과했다
#    ([[feedback_control_presence_is_not_discrimination]]). 행 형식으로 앵커한다.
printf '%s' "$CF_OUT" | grep -qE 'q3 +conflict +ARM +r1 +CONFLICT_FOLLOWED' && _a=yes || _a=no
printf '%s' "$CP_OUT" | grep -qE 'q3 +conflict +ARM +r1 +PRIOR_WON'         && _b=yes || _b=no
if [ "$_a" = yes ] && [ "$_b" = yes ]; then
  ok "L11 known-pair — 심은 값을 따른 팔과 일반지식이 이긴 팔이 갈린다"
else no "L11 치환 컨트롤이 두 팔을 못 가른다 (followed=$_a prior=$_b) — 이 축은 계기가 아니다"; fi

# PRIOR_WON 우세면 DELIVERY 를 인용하면 안 된다 → 자기 이름을 가진 판정 + 종료코드
printf '%s' "$CP_OUT" | grep -q 'CARRIER_UNREAD' \
  && ok "L12 일반지식이 이기면 CARRIER_UNREAD 로 판정된다" \
  || no "L12 PRIOR_WON 우세인데 판정이 CARRIER_UNREAD 가 아니다"
[ "$CP_RC" = 6 ] && ok "L12b CARRIER_UNREAD → exit 6 (다른 판정과 구분되는 값)" \
  || no "L12b CARRIER_UNREAD 의 종료코드가 6 이 아니다 (got=$CP_RC)"
# 컨트롤 — 심은 값을 따랐으면 그 판정이 «안» 나와야 한다
printf '%s' "$CF_OUT" | grep -q 'CARRIER_UNREAD' \
  && no "L12c 컨트롤 실패 — 운반체를 읽었는데도 CARRIER_UNREAD 가 붙었다 (항상 차단)" \
  || ok "L12c 컨트롤 — 운반체를 읽은 회차엔 CARRIER_UNREAD 가 안 붙는다"

# ── L12d~L12f UNCLASSIFIED (2026-08-31 신설) — 🟥 «나머지 통»을 주장으로 렌더하지 않는다 ──
#    회차1: 팔이 명시적으로 기권했는데(심은 값 0 · 원래값 0) 거절 어휘가 영어라 `has_ref=0` 이 되어
#    `else` 로 떨어졌고 **「일반지식이 이겼다(운반체 미독)」** 로 인쇄됐다. 판정 경로 «안»의 결함이다.
printf 'q1\tpositive\t질문P\t%s\nq3\tconflict\t질문C\t%s\n' "$PT" "$CPT" > "$T/qc_nogen.tsv"
mkc "$T/cf_ung" prior
UN_OUT="$( cd "$ROOT" && bash "$S" --seal "$T/seal.md" --qset "$T/qc_nogen.tsv" --reps 1 \
           --out "$T/cf_ung" --rescore 2>&1 </dev/null )"
printf '%s' "$UN_OUT" | grep -qE 'q3 +conflict +ARM +r1 +UNCLASSIFIED' \
  && ok "L12d general 열이 없으면 PRIOR_WON 을 «단언 안 한다» → UNCLASSIFIED" \
  || no "L12d general 없이 PRIOR_WON 이 나왔다 — 나머지 통이 주장으로 렌더된다"
printf '%s' "$UN_OUT" | grep -q 'PRIOR_WON       : 0 /' \
  && ok "L12e 그때 PRIOR_WON 라벨을 안 붙인다" \
  || no "L12e 원래값 미확인인데 「일반지식이 이겼다」 라벨이 붙었다"
printf '%s' "$UN_OUT" | grep -qE 'UNCLASSIFIED    : [1-9]' \
  && ok "L12f UNCLASSIFIED 가 «자기 줄»로 보인다 (분모에서 안 뺀다)" \
  || no "L12f UNCLASSIFIED 가 집계에 안 보인다 — 미분류를 0 으로 접었다"

# ── L12g~L12h conflict CTRL 집계 (2026-08-31) — 계기의 사각이 «팔»과 상관되지 않게 ──────
#    회차1 의 실제 오분류가 **하필 CTRL 쪽**이었고 요약엔 0/20 으로 떴다. 사람이 판정표 «행»을
#    눈으로 훑다가 발견했지 집계가 알려준 게 아니다([[feedback_instrument_blindspot_correlated_with_arm]]).
#    그리고 conflict 축에서 **CTRL 의 정상 거동은 PRIOR_WON** 이므로 CTRL 수치가 컨트롤 생존선이다.
printf '%s' "$UN_OUT" | grep -q 'conflict CTRL (계기 생존선)' \
  && ok "L12g conflict CTRL 집계가 «자기 절»로 나온다" \
  || no "L12g CTRL 쪽 conflict 집계가 없다 — 그쪽 오분류가 구조적으로 안 보인다"
printf '%s' "$UN_OUT" | grep -qE 'UNCLASSIFIED  : [0-9]+ / [0-9]+' \
  && ok "L12h CTRL UNCLASSIFIED 가 숫자로 보인다 (0 으로 안 접는다)" \
  || no "L12h CTRL UNCLASSIFIED 줄이 없다"

# ── L13 LUCKY 칸이 «실수»로 나오나 (종전엔 무조건 UNMEASURED 였다) ──────────────
printf '%s' "$CF_OUT" | grep -qE 'LUCKY   \(CTRL\)  : [0-9]+ / [0-9]+' \
  && ok "L13 LUCKY 가 숫자로 나온다 (잴 수 있는 것을 «못 잰다»로 렌더하지 않는다)" \
  || no "L13 LUCKY 칸이 숫자가 아니다 — 과소보고다"

# ── L14 conflict 행이 «없을» 때는 UNMEASURED (0 으로 접지 않는다) ───────────────
mk "$T/nocfl" yes; NC_OUT="$(run "$T/nocfl")"
printf '%s' "$NC_OUT" | grep -q 'CARRIER-READ    : UNMEASURED' \
  && ok "L14 conflict 문항 0개면 CARRIER-READ 는 UNMEASURED (0 아님)" \
  || no "L14 conflict 부재를 0 으로 접었다"

# ── L15~L17 회차 완료 마커 ─────────────────────────────────────────────────────
#    🟥 「개수로 완료를 판정」이 다른 팔에서 실제 슬립을 냈다(42/42 를 보고 채점했는데 마지막
#    팔이 아직 쓰는 중). 마커는 모든 디스패치·채점 뒤에 쓰이므로 «있으면 닫혔다»가 성립한다.
mk "$T/rd" yes; RD_OUT="$(run "$T/rd")"
[ -f "$T/rd/_ROUND_DONE" ] && ok "L15 회차가 끝나면 _ROUND_DONE 이 쓰인다" \
  || no "L15 완료 마커가 없다 — 소비자가 «개수»로 판정하게 된다"
# 🟥 개수는 `*_r[0-9].txt` 로 세야 한다. `*_r*.txt` 는 부수파일까지 세서 부풀린다.
_rd_ans=$(grep '^answers:' "$T/rd/_ROUND_DONE" 2>/dev/null | awk '{print $2}')
_rd_rows=$(grep '^rows:' "$T/rd/_ROUND_DONE" 2>/dev/null | awk '{print $2}')
[ -n "$_rd_ans" ] && [ "$_rd_ans" = "$_rd_rows" ] \
  && ok "L16 마커의 answers 가 rows 와 일치한다 (부수파일을 안 센다)" \
  || no "L16 answers=$_rd_ans rows=$_rd_rows — 개수 세는 글롭이 부수파일을 삼켰다"
# 🟥 컨트롤 — 부수파일을 만들어도 개수가 안 늘어야 한다. 없으면 L16 은 «우연히» 초록이다.
: > "$T/rd/q1_ARM_r1.prompt.txt"; : > "$T/rd/q1_ARM_r1.stderr.txt"
RD2="$(run "$T/rd")" >/dev/null 2>&1
_rd_ans2=$(grep '^answers:' "$T/rd/_ROUND_DONE" 2>/dev/null | awk '{print $2}')
# 🟥 «마커가 존재한다»를 전제로 박는다 (2026-08-31, 다른 팔의 되돌림이 지목).
#    마커를 아예 안 쓰는 뮤턴트에서 `_rd_ans`·`_rd_ans2` 가 **둘 다 빈 문자열**이 되고
#    `[ "" = "" ]` 가 참이라 이 레인이 **초록으로 통과**했다 — 빈 집합에서 통과 방향이다
#    ([[feedback_not_found_is_not_zero_family]] 7번째 얼굴).
#    L17 은 L16 의 컨트롤이지 L15 의 컨트롤이 아니므로 «오채점»은 아니었다. 그래도 안 막으면
#    「L17 이 마커 부재까지 지킨다」로 읽힌다. ⇒ 부재는 skip 이 아니라 **fail** 이다.
if [ -z "$_rd_ans" ] || [ -z "$_rd_ans2" ]; then
  no "L17 마커가 없거나 answers 를 못 읽었다 — 비교 자체가 성립 안 한다(통과 아님)"
elif [ "$_rd_ans2" = "$_rd_ans" ]; then
  ok "L17 컨트롤 — 부수파일을 늘려도 answers 가 그대로다 (판별력)"
else
  no "L17 부수파일이 개수에 섞였다 ($_rd_ans → $_rd_ans2)"
fi

echo "verdict watermark lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
