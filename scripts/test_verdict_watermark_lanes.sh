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

# ── L18~L20 마커의 complete (2026-08-31) — «무엇을 보증하나»를 마커가 스스로 적는다 ────────
#    3층 수리: ①개수로 판정 → ②마커 → ③마커가 «루프가 끝났다»만 보증 → ④정의를 마커 안에.
#    🟥 `.err` 조건이 하중이다: 실제 사고(적격 실행 16/48)는 **답변 파일이 있으면서** 클론
#    에러가 16건이었다. 개수만 맞추면 같은 사고가 또 통과한다.
mk "$T/cmp" yes; run "$T/cmp" >/dev/null 2>&1
grep -q 'complete: yes' "$T/cmp/_ROUND_DONE" \
  && ok "L18 정상 회차 → complete: yes" || no "L18 정상인데 complete 가 yes 가 아니다"
grep -qE 'complete: .*정의: answers==rows' "$T/cmp/_ROUND_DONE" \
  && ok "L19 complete 의 «정의»가 마커 안에 적힌다" \
  || no "L19 정의가 없다 — 다음 사람이 «complete 면 데이터가 옳다»로 읽는다"
# 🟥 실물 사고 형태: 개수는 맞는데 클론 에러가 있다
printf 'fatal: destination path already exists\n' > "$T/cmp/_clone_q1_ARM_r1.err"
run "$T/cmp" >/dev/null 2>&1
grep -q 'complete: NO' "$T/cmp/_ROUND_DONE" \
  && ok "L20 개수는 맞는데 클론 에러가 있으면 → complete: NO (판별력)" \
  || no "L20 클론 에러를 무시했다 — 16/48 사고가 그대로 통과한다"

# ── L21~L23 봉인 대조 (2026-08-31) — verify 가 «구조적으로» 못 잡는 자리 ──────────────
#    재stamp 때 인자를 안 바꾸면 «회차1 문항»을 봉인해놓고 «회차2»를 돌린다. 그때
#    `instrument_manifest.sh verify` 는 **rc=0** 이다 — 자기가 찍은 것과 같으니 자기 일관하다.
#    🟥 판별자는 «경로»가 아니라 «해시»여야 한다: 같은 경로에 다른 내용이 오면 경로 비교는 통과한다.
_MF="$ROOT/tracks/_meta/instrument_manifest_2026-08-31_round.txt"
_SQ="$ROOT/tracks/_meta/qset_2026-08-31_round.tsv"
_SS="$ROOT/tracks/_meta/seal_PLANTED_2026-08-31_round.md"
if [ ! -s "$_MF" ] || [ ! -s "$_SQ" ]; then
  no "L21 픽스처 부재 — 봉인 대조 레인을 검정할 수 없다(스킵 아님)"
else
  ( cd "$ROOT" && bash "$S" --seal "$_SS" --qset "$_SQ" --reps 5 --out /private/tmp/_run_0831 \
      --rescore --manifest "$_MF" >/dev/null 2>&1 </dev/null ); _r=$?
  [ "$_r" != 10 ] && ok "L21 봉인된 qset → 통과 (rc=$_r)" || no "L21 봉인된 qset 인데 막혔다"
  # 🟥 같은 «경로», 다른 «내용» — 경로 비교였으면 뚫리는 자리
  cp "$_SQ" "$T/q.bak"; printf '# probe\n' >> "$_SQ"
  ( cd "$ROOT" && bash "$S" --seal "$_SS" --qset "$_SQ" --reps 5 --out /private/tmp/_run_0831 \
      --rescore --manifest "$_MF" >/dev/null 2>&1 </dev/null ); _r2=$?
  cp "$T/q.bak" "$_SQ"
  [ "$_r2" = 10 ] && ok "L22 같은 경로·다른 내용 → 차단 (해시 비교임을 증명)" \
    || no "L22 내용이 바뀌었는데 통과했다 (rc=$_r2) — 경로만 보고 있다"
  # 🟥 미지정은 «통과»가 아니라 UNVERIFIED 로 «남아야» 한다
  ( cd "$ROOT" && bash "$S" --seal "$_SS" --qset "$_SQ" --reps 5 --out /private/tmp/_run_0831 \
      --rescore >/dev/null 2>&1 </dev/null )
  grep -q 'qset_matches_manifest: UNVERIFIED' /private/tmp/_run_0831/_ROUND_DONE \
    && ok "L23 --manifest 미지정 → 마커에 UNVERIFIED (통과로 안 접는다)" \
    || no "L23 미지정인데 UNVERIFIED 가 기록에 없다"
fi

# ── L24 🟥 셸 이름-경계 스캐너를 «회귀에» 배선한다 ────────────────────────────────
#    이 스캐너를 짓고도 «안 돌려서» 같은 날 같은 결함을 다시 넣었다(`«$_rel»`).
#    도구를 만드는 것과 «부르는 것»은 다른 일이다 — 그래서 레인이 부른다.
if [ -x "$ROOT/scripts/shell_name_boundary_scan.sh" ]; then
  bash "$ROOT/scripts/shell_name_boundary_scan.sh" "$S" >/dev/null 2>&1 \
    && ok "L24 채점기에 «이름 경계» 결함 0" \
    || no "L24 채점기에 \$VAR+비ASCII 또는 \"\$VAR: 가 있다 — 조용히 틀린다"
else no "L24 스캐너 없음 — 검사 못 함(스킵 아님)"; fi

# ── L25 🟥 «게이트가 이름 누출 검사를 부르나» — «검사기가 있나»가 아니다 ─────────────
#    회차2 는 검사기가 없어서 뚫린 게 아니다. 아무도 «안 물어서» 뚫렸다. 그리고 그 다음엔
#    검사기가 생겼는데 **호출부가 0개**였다(실측). ⇒ 존재를 묻는 레인은 그 둘을 다 놓친다.
#    확인법: 검사기를 «통과만 하게» 스텁으로 바꾸면 게이트가 초록이 되나(되돌림 3단).
# 🟥 두 경로를 «갈라» 잡지 않는다. 2026-09-01 에 이 한 줄 때문에 같은 정정을 두 번 했다 —
#    저자 워크트리에선 검사기와 게이트가 같은 폴더(tracks/_meta)라 통했고, 거버너 트리에선
#    게이트만 scripts/round/ 라 짝이 안 맞아 L25 넷이 죽었다. **레인이 자기 트리에서만 초록**.
#    ⇒ 한 디렉터리 변수에서 «둘 다» 꺼낸다. 갈라 적을 수 있으면 다시 갈린다.
_RD="$ROOT/scripts/round"
_NLK="$_RD/nameleak_check.sh"; _GK="$_RD/gatecheck_qset.sh"
_QK="$ROOT/tracks/_meta/qset_2026-09-01_round2.tsv"; _SK="$ROOT/tracks/_meta/seal_PLANTED_2026-09-01_round2.md"
if [ -x "$_NLK" ] && [ -f "$_GK" ] && [ -f "$_QK" ] && [ -f "$_SK" ]; then
  bash "$_GK" "$_QK" "$_SK" post '' '' '_run_0901' 'C01_ARM' >/dev/null 2>&1
  [ "$?" = 5 ] && ok "L25a 누출 이름 → 게이트 차단(exit 5)" || no "L25a 누출 이름인데 게이트가 안 막는다"
  cp "$_NLK" "$_NLK.lanebak"
  printf '#!/usr/bin/env bash\n[ "${1:-}" = gen ] && { echo wdeadbeef01; exit 0; }\nexit 0\n' > "$_NLK"
  if grep -q '^exit 0$' "$_NLK"; then
    bash "$_GK" "$_QK" "$_SK" post '' '' '_run_0901' 'C01_ARM' >/dev/null 2>&1
    [ "$?" = 0 ] && ok "L25b 스텁이면 게이트 통과 → 게이트가 «실제로 부른다»" \
                 || no "L25b 스텁인데도 차단 — 게이트가 검사기를 안 부르고 딴 걸로 막는다"
  else no "L25b 스텁 적용 실패 — 되돌림 무효"; fi
  mv -f "$_NLK.lanebak" "$_NLK"; chmod +x "$_NLK"
  bash "$_GK" "$_QK" "$_SK" post '' '' '_run_0901' 'C01_ARM' >/dev/null 2>&1
  [ "$?" = 5 ] && ok "L25c 복원 → 다시 차단" || no "L25c 복원 실패 — 스텁이 남았다"
  _mv="$_NLK.moved"; mv "$_NLK" "$_mv"
  bash "$_GK" "$_QK" "$_SK" post '' '' 'w12345678' 'w87654321' >/dev/null 2>&1
  [ "$?" = 5 ] && ok "L25d 검사기 부재 → 실패(스킵 아님)" || no "L25d 부재를 스킵으로 접는다"
  mv "$_mv" "$_NLK"; chmod +x "$_NLK"
else no "L25 픽스처 없음 — 검사 못 함(스킵 아님)"; fi

# ── L26 §7-7 — «두 숫자를 곱하지 않는다»를 «코드로» 검사한다 ────────────────────
#    🟥 「곱하지 마라」를 주석에 적는 것은 오늘 세 번 실패한 형태다. 레인이 소스를 본다:
#    TYPED_N 과 FALLBACK_N 을 결합하는 식(`*`·`/`·비율)이 존재하면 실패.
if grep -q 'TYPED_N=' "$S"; then
  # 🟥 초판 정규식은 `$TYPED_N / $TOTAL_N` 이라는 **표시용 구분자**를 나눗셈으로 오탐했다.
  #    (오늘 그 축: 계기가 «형태»만 보고 «문맥»을 안 봤다.) ⇒ 산술 문맥 `$((…))` 안만 본다.
  if grep -oE '\$\(\([^)]*\)\)' "$S" 2>/dev/null | grep -E '(TYPED_N|FALLBACK_N)' | grep -qE '[*/]'; then
    no "L26a 두 숫자를 결합하는 식이 있다 — 곱하면 어느 쪽이 나빠졌는지 못 본다"
  else ok "L26a 두 숫자 결합식 없음 (곱한 값이 소스에 없다)"; fi
  grep -q '② 규약 준수' "$S" && grep -q '① 폴백 도달' "$S" \
    && ok "L26b 두 숫자가 «따로» 출력된다" || no "L26b 두 숫자 중 하나가 안 찍힌다"
  # 🟥 되돌림: 결합식을 «넣으면» L26a 가 실제로 무나
  cp "$S" "$S.l26bak"
  printf '\nBAD_RATIO=$((TYPED_N * 100))\n' >> "$S"
  if grep -q 'TYPED_N \* 100' "$S"; then
    if grep -oE '\$\(\([^)]*\)\)' "$S" 2>/dev/null | grep -E 'TYPED_N' | grep -qE '[*/]'; then ok "L26c [되돌림] 결합식을 넣으면 검사가 문다"
    else no "L26c 결합식을 넣었는데 검사가 안 문다 — L26a 는 장식이다"; fi
  else no "L26c 되돌림 적용 실패"; fi
  mv -f "$S.l26bak" "$S"
else no "L26 TYPED_N 이 채점기에 없다 — §7-7 미배선(스킵 아님)"; fi

# ── L27 §7-7-ⓑ 폴백 도달 프로브를 «회귀에» 배선한다 ─────────────────────────────
if [ -x "$ROOT/scripts/round/fallback_reach_probe.sh" ]; then
  bash "$ROOT/scripts/round/fallback_reach_probe.sh" >/dev/null 2>&1 \
    && ok "L27 폴백이 실제로 탄다 (깨진 토큰 3종)" \
    || no "L27 폴백 미도달 — 폴백은 장식이고 48 바는 «인쇄»다"
else no "L27 프로브 없음 — 검사 못 함(스킵 아님)"; fi

# ── L28 🟥 «처치 둘을 곱했을 때» — deliver 분기가 누적된 $q 를 버리면 안 된다 ───
#    2026-09-01 사고: deliver 분기가 `$question` 을 다시 읽어 위에서 붙인 규약을 버렸다.
#    → ③(규약×deliver) 의 ARM 은 실제로는 «규약없음×deliver» 였고, ARM 0/72 · CTRL 72/72 를
#    「deliver 가 규약 준수를 죽인다」는 «발견» 으로 낼 뻔했다.
#    🟥 known-pair 를 «한 인자씩» 만 돌리면 조합이 여는 경로를 구조적으로 못 본다.
if grep -q 'DELIVER" = 1 \] && \[ "$arm" = ARM' "$S"; then
  _dl=$(grep -n 'DELIVER" = 1 \] && \[ "$arm" = ARM' "$S" | head -1 | cut -d: -f1)
  _blk=$(sed -n "${_dl},$((_dl+4))p" "$S")
  if printf '%s' "$_blk" | grep -q '^\$question"$'; then
    no "L28 deliver 분기가 \$question 을 다시 읽는다 — 규약이 버려진다"
  else ok "L28 deliver 분기가 누적된 \$q 위에 붙인다"; fi
  # 🟥 되돌림: 버그를 다시 넣으면 L28 이 실제로 무나
  #    🟥 **사본에서** 돌린다. $S 는 라이브 채점기이고 이 뮤턴트는 «실제 버그»다 —
  #    테스트가 중간에 죽으면 채점기가 조용히 망가진 채 남는다(L26c 의 덧붙임과 등급이 다르다).
  # 🟥 `mktemp -t l28copy` 는 macOS 에서 통하고 **GNU 에서 죽는다**(too few X's).
  #    P11 에서 같은 결함을 고치면서 **이 형제를 안 봤다** — 반쪽-픽스 전파경계.
  _l28c=$(mktemp -t l28copy.XXXXXX 2>/dev/null || mktemp) || _l28c=""
  if [ -n "$_l28c" ] && cp "$S" "$_l28c"; then
    _mut=$((_dl+2))   # 블록의 셋째 줄이 그 자리다 (정규식 곡예 대신 줄번호로)
    awk -v n="$_mut" 'NR==n{print "$question\""; next} {print}' "$_l28c" > "$_l28c.m" && mv -f "$_l28c.m" "$_l28c"
    _blk2=$(sed -n "${_dl},$((_dl+4))p" "$_l28c")
    if printf '%s' "$_blk2" | grep -q '^\$question"$'; then
      ok "L28b [되돌림] 버그를 넣으면 검사가 문다 (사본에서)"
    else no "L28b 되돌림 적용 실패 — L28 은 미검증이다(장식 가능)"; fi
    rm -f "$_l28c" "$_l28c.m"
  else no "L28b 사본을 못 만들었다 — 되돌림 미검증(스킵 아님)"; fi
else no "L28 deliver 분기를 못 찾았다 — 검사 못 함(스킵 아님)"; fi

echo "verdict watermark lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
