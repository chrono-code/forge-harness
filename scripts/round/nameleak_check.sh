#!/usr/bin/env bash
# 이름 누출 — «생성기 + 백스톱». 검사기가 판정하지 않는다.
#
# 🟥 초판은 자기 논지를 반증했다. 헤더가 「목록은 안 본다」고 적어놓고
#    `ASSIGN_RE='…(ARM|CTRL|arm|ctrl)…'` 로 **낱말 4개를 열거**했고,
#    `OPAQUE_RE='^[0-9a-z_]+$'` 가 소문자면 통과시켜서 실측으로 뚫렸다:
#      treatment · baseline · placebo · control_a · exposed  → 전부 rc=0 «불투명» 🟥
#    ⇒ «4낱말 대신 4낱말»이었다. 열거를 늘리는 수리는 REFUSE_RE 의 네 번째 수리와 같은 형태다.
#    ([[feedback_citing_a_rule_is_not_obeying_it]] — 적는 행위가 «지켰다는 감각»을 만든다.
#     저자도 검토자도 못 잡았고 세 번째 팔이 잡았다.)
#
# 🟥 그래서 방향을 뒤집는다 — **화이트리스트**다:
#      「나쁜 낱말이 없으면 통과」  ✗   열거는 언제나 불완전하다
#      「생성기가 낸 형태가 아니면 차단」 ✓   사람이 고른 이름은 전부 막힌다
#    그리고 더 근본적으로: **라벨을 사람이 고르지 않게 한다.** `gen` 이 그 자리다.
#    검사기는 «생성이 안 쓰였을 때» 무는 백스톱으로만 남는다 —
#    §1 결론(«사람의 읽기에 안 맡긴다»)의 라벨 판이다.
#
# 🟥 seal 파일명은 다른 근거로 판정한다 — 실물 규약을 **관측**했다(19건 전수,
#    tracks/_meta/compaction/): `seal_<8hex>-<3hex>_<YYYYMMDD>-<HHMMSS>.md`.
#    그건 열거가 아니라 **형태 일치**이므로 이 문제가 없다.
#
# 🟥 시야 판별자 — 검사 «대상»을 이름 문자열 셋으로 좁힌다. 파일 전체 grep 을 안 한다.
#    ⇒ `context_continuity_score.sh:481·728·729`(같은 basename 이지만 `echo` 로 운영자
#    콘솔에 간다)는 **애초에 입력이 아니다** = 구조적으로 오조준 불가.
#    필터는 뚫리고 형태는 안 뚫린다.
#
# 사용
#   nameleak_check.sh gen                       → 회차가 쓸 라벨 하나를 «생성»해서 찍는다
#   nameleak_check.sh <seal> <out-dir> <라벨>    → rc 0 통과 · 1 누출 · 2 인자오류
# 🟥 판정은 rc 로 한다. 출력 문구를 grep 하지 마라 — 요약줄이 같이 잡혀서 개수가 틀린다(실측).
set -uo pipefail

# ── 생성 형태 (이 한 줄이 «불투명»의 정의다) ─────────────────────────────────
# w + 8자리 이상 hex. 길이가 8이면 사전 단어와 우연히 겹칠 확률이 사실상 0이다.
# 🟥 잔여를 이름으로 남긴다: `wdeadbeef` 같은 hex-단어는 형태를 통과한다. 막지 않는다 —
#    막으려면 다시 «낱말 열거»가 되고, 그게 이 파일이 폐기한 방식이다. 확률로 산다.
GEN_RE='^w[0-9a-f]{8,}$'
gen_one(){ printf 'w%s\n' "$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"; }

# ── seal 이름 (관측한 실물 규약, 2026-09-01) ─────────────────────────────────
# 🟥 정규식이 «정본»이고 생성기는 그것에 «검정»된다. 두 곳에 따로 적으면 갈린다 —
#    오늘 그 축(「갈라 적을 수 있으면 다시 갈린다」)이라 생성 직후 SEAL_RE 로 자기검사한다.
#    통과 못 하면 이름을 «안 내고» 실패한다: 틀린 이름을 내면 회차가 통째로 무효다.
SEAL_RE='^seal_[0-9a-f]{8}-[0-9a-f]{3}_[0-9]{8}-[0-9]{6}\.md$'
gen_seal(){
  local n
  n="seal_$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')-$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n' | cut -c1-3)_$(date +%Y%m%d-%H%M%S).md"
  if printf '%s' "$n" | grep -qE "$SEAL_RE"; then printf '%s\n' "$n"; return 0; fi
  echo "🟥 gen-seal 이 자기 검사기를 통과 못 했다: $n" >&2; return 1
}

if [ "${1:-}" = gen ];      then gen_one;  exit $?; fi
if [ "${1:-}" = gen-seal ]; then gen_seal; exit $?; fi

SEAL_NAME="${1:-}"; OUTDIR_NAME="${2:-}"; ARM_LABEL="${3:-}"
[ -n "$SEAL_NAME" ] && [ -n "$OUTDIR_NAME" ] && [ -n "$ARM_LABEL" ] || {
  echo "usage: nameleak_check.sh gen | <seal-basename> <out-dir-basename> <arm-label>" >&2; exit 2; }

# 🟥 SEAL_RE 는 위에서 «한 번만» 정의한다 — 생성기와 검사기가 같은 상수를 쓴다
bad=0
say(){ printf '  %s %s\n' "$1" "$2"; }

# ① seal 파일명 — 관측한 실물 규약과 «구분 불가»한가
if printf '%s' "$SEAL_NAME" | grep -qE "$SEAL_RE"; then
  say 🟢 "seal   $SEAL_NAME"
else
  say 🟥 "seal   $SEAL_NAME — 실물 규약과 다르다 (seal_<8hex>-<3hex>_<YYYYMMDD>-<HHMMSS>.md)"
  bad=$((bad+1))
fi

# ② out-dir · ③ 팔 라벨 — 둘 다 팔의 cwd 조상/자신이라 시야 «안»이다.
#   🟥 실물 규약이 없으므로 «생성 형태»만 통과시킨다. 사람이 고른 이름은 전부 막힌다.
for _pair in "outdir:$OUTDIR_NAME" "arm:$ARM_LABEL"; do
  _k="${_pair%%:*}"; _v="${_pair#*:}"
  if printf '%s' "$_v" | grep -qE "$GEN_RE"; then
    say 🟢 "$_k    $_v"
  else
    say 🟥 "$_k    $_v — 생성 형태가 아니다 — 'nameleak_check.sh gen' 을 써라"
    bad=$((bad+1))
  fi
done

[ "$bad" -gt 0 ] && { echo "🟥 이름 누출 ${bad}건 — 회차를 열지 않는다"; exit 1; }
echo "🟢 이름 누출 0건"; exit 0
