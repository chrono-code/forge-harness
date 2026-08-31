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

echo "verdict watermark lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
