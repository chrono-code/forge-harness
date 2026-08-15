#!/usr/bin/env bash
# capability_effect_probe.sh — 선언된 `writes:` 가 **참인지** 관측한다 (정체성 ① 블로커 (d)).
#
# ─────────────────────────────────────────────────────────────────────────────
# 왜 지어졌나 — 등록 바가 «형식» 만 재고 «진위» 를 안 잰다
# ─────────────────────────────────────────────────────────────────────────────
# `capability_registry_check.sh` 헤더가 직접 적어놨다:
#
#   "🟥 `writes:` 축은 검증 불가 — 그리고 그게 이 파일에서 실제로 터졌다.
#    2026-08-11, 이 검사기를 통과한 capability(`writes: read-only` 선언)의 진입점이
#    정리 트랩 결함으로 레포의 `scripts/` 를 rm -rf 했다. M1–M5 를 전부 통과한 채로.
#    구조 처방(미구축): 샌드박스에서 M4 를 돌려 쓰기 시도를 관측하는 것."
#
# 이 파일이 그 구조 처방이다. `ship_readiness_gate.md` 정체성 ① 의 블로커 (d) —
# *"초록이 파괴 행위에 선행할 수 있는 검사기는 초록 정체성이 아니다"* — 를 겨눈다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 이 프로브가 **증명하지 않는** 것 (과잉주장 금지)
# ─────────────────────────────────────────────────────────────────────────────
# · **한 번의 실행만 본다.** 조건부로 쓰는 capability(특정 입력에서만 쓴다)는 그 입력이
#   M4 쌍에 없으면 안 걸린다. 이건 «이 실행에서 안 썼다» 이지 «절대 안 쓴다» 가 아니다.
# · **샌드박스 밖은 못 본다.** 절대경로로 다른 데를 쓰면 이 프로브는 놓친다.
#   ⟹ 그래서 **카나리아를 샌드박스 밖에도 심는다**(아래 OUTSIDE_CANARY). 그게 지워지면
#      «샌드박스 밖 쓰기» 로 잡힌다 — 완전하진 않지만 조용하진 않다.
# · **네트워크·프로세스 부작용은 안 본다.** 파일시스템 축 전용이다.
# · 🟥 **worktree 는 `HEAD` 기준이다.** 후보 파일이 워킹트리에만 있고 커밋 전이면, 프로브가
#   재는 트리는 **후보 상태가 아니다.** 등록 시점에 커밋된 상태를 재는 것이 정상 경로이나,
#   개발 중 호출하면 이 어긋남이 조용히 생긴다 — 그래서 여기 적는다.
# · 🟥 **절대경로 감시는 «홈 엔트리 목록» 수준이다.** 홈 **하위 디렉토리 내부**의 변경
#   (예: `$HOME/Documents/x`)이나 `/tmp` 의 남의 파일 수정은 여전히 못 본다.
#   전수 스냅샷은 비용이 크고 홈이 늘 시끄러워 오탐이 난다 — 그래서 **엔트리 목록**만 본다.
#   이건 «가장 흔한 표적을 막는다» 이지 «절대경로 쓰기를 막는다» 가 아니다.
#   2026-08-16 자기 공격으로 이 층을 찾았고, 그 위 층은 여전히 열려 있다고 적어 둔다.
# · 실행 불가는 **PASS 가 아니다** — `UNVERIFIABLE`(3) 로 낸다. 미측정을 0 으로 렌더하지 않는다.
#
# 사용법
#   capability_effect_probe.sh <capfile> [<capfile> ...]
#   capability_effect_probe.sh --self-test
#
# exit code
#   0  VERIFIED        선언과 관측이 일치
#   1  VIOLATION       선언보다 **넓게** 썼다 (read-only 선언인데 썼다 등)
#   3  UNVERIFIABLE    돌릴 수 없었다 — 판정 아님(미측정)
#   10 HARNESS_ERROR   capfile 파손·전제 파손
set -o pipefail
set -f

RC_OK=0; RC_VIOLATION=1; RC_UNVERIFIABLE=3; RC_HARNESS=10

# writes 축 순서 (좁음 → 넓음). 관측이 선언보다 넓으면 VIOLATION.
ORDER_writes="read-only write-local write-remote"

_idx() { local v="$1" i=0 x; for x in $ORDER_writes; do [ "$x" = "$v" ] && { printf '%d' "$i"; return; }; i=$((i+1)); done; printf '%d' -1; }

_key() {  # $1=capfile $2=key
  sed -n "s/^[[:space:]]*$2:[[:space:]]*//p" "$1" 2>/dev/null | head -1 \
    | sed 's/[[:space:]]*$//'
}

_snapshot() {  # $1=dir → "path<TAB>sha" 목록 (정렬)
  find "$1" -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s\t%s\n' "$f" "$(shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1)"
  done
}

# ★정리 트랩 — 신호/중단에도 worktree metadata 와 temp 가 안 남게 한다(cross-family 지목).
#   worktree 는 **공유 레포의 .git 에 기록**되므로, 남기면 남의 세션이 그 잔재를 본다.
_PROBE_WT=""; _PROBE_WT_PARENT=""; _PROBE_REQ_CWD=""; _PROBE_SANDBOX=""
_cleanup_probe() {
  if [ -n "$_PROBE_WT" ] && [ -n "$_PROBE_REQ_CWD" ]; then
    git -C "$_PROBE_REQ_CWD" worktree remove --force "$_PROBE_WT" >/dev/null 2>&1 || rm -rf "$_PROBE_WT"
    git -C "$_PROBE_REQ_CWD" worktree prune >/dev/null 2>&1
  elif [ -n "$_PROBE_SANDBOX" ]; then
    rm -rf "$_PROBE_SANDBOX"
  fi
  [ -n "$_PROBE_WT_PARENT" ] && rm -rf "$_PROBE_WT_PARENT"
  _PROBE_WT=""; _PROBE_WT_PARENT=""; _PROBE_REQ_CWD=""; _PROBE_SANDBOX=""
}
trap _cleanup_probe EXIT INT TERM

probe_one() {  # $1=capfile → rc
  local cap="$1"
  [ -r "$cap" ] || { printf '❌ capfile 도달 불가: %s\n' "$cap" >&2; return "$RC_HARNESS"; }

  local declared entry pos_args neg_args
  declared=$(_key "$cap" writes)
  entry=$(_key "$cap" entry)
  pos_args=$(_key "$cap" calibration_positive_args)
  neg_args=$(_key "$cap" calibration_negative_args)

  [ -n "$declared" ] || { printf '❌ %s: writes 축 선언 없음 — 검증 대상이 아니다\n' "$cap" >&2; return "$RC_HARNESS"; }
  [ "$(_idx "$declared")" -ge 0 ] || { printf '❌ %s: writes 값이 enum 밖: %s\n' "$cap" "$declared" >&2; return "$RC_HARNESS"; }
  [ -n "$entry" ] || { printf '❌ %s: entry 없음\n' "$cap" >&2; return "$RC_HARNESS"; }

  # `requires_cwd` 가 있으면 그 레포의 **worktree 사본**을 샌드박스로 쓴다.
  # 실물 트리에서 돌리면 «파괴를 관측하려다 파괴하는» 꼴이고, 빈 임시디렉토리에서
  # 돌리면 진입점이 전제를 못 찾아 UNVERIFIABLE 로만 끝난다(실측: 실물 capfile 10 중 4).
  #
  # 🟥 **리셋 먼저, 편집 나중.** worktree 를 만든 뒤에 픽스처를 얹는다. 순서를 뒤집으면
  #    `git reset --hard`/worktree 생성이 tracked 편집을 되돌려 프로브가 조용히 공허해진다
  #    (2026-08-16 병렬 세션 실측: 같은 순서 문제로 한 레인이 두 번 장식이 됐다).
  local req_cwd wt=""
  req_cwd=$(_key "$cap" requires_cwd)

  local sandbox outside wt_parent=""
  if [ -n "$req_cwd" ] && [ -d "$req_cwd/.git" ]; then
    wt_parent=$(mktemp -d); wt="$wt_parent/wt"
    if ! git -C "$req_cwd" worktree add --detach -q "$wt" HEAD 2>/dev/null; then
      printf '⚠️  UNVERIFIABLE %s — worktree 사본을 못 만들었다(%s)\n' "$cap" "$req_cwd" >&2
      return "$RC_UNVERIFIABLE"
    fi
    sandbox="$wt"
    _PROBE_WT="$wt"; _PROBE_WT_PARENT="$wt_parent"; _PROBE_REQ_CWD="$req_cwd"
  else
    sandbox=$(mktemp -d) || return "$RC_HARNESS"
    _PROBE_SANDBOX="$sandbox"
  fi
  outside=$(mktemp -d) || return "$RC_HARNESS"
  printf 'canary-inside\n'  > "$sandbox/CANARY_INSIDE"
  printf 'canary-outside\n' > "$outside/CANARY_OUTSIDE"

  # 🟥 **홈 디렉토리 카나리아** — 2026-08-16 실측: 초판은 임시 카나리아 하나만 봐서
  #    `echo x > $HOME/...` 이 **VERIFIED 로 통과**했고 홈에 파일이 실제로 생겼다.
  #    (d) 가 말하는 결함을 프로브 자신이 갖고 있었던 것이다. 절대경로 쓰기의 가장 흔한
  #    표적이 홈이므로 여기에도 감시를 둔다. ⚠️ 완전하지 않다 — 아래 §잔여 참조.
  local home_before home_after
  home_before=$(ls -A "$HOME" 2>/dev/null | LC_ALL=C sort | shasum -a 256 | cut -d" " -f1)
  mkdir -p "$sandbox/scripts"; printf 'x\n' > "$sandbox/scripts/CANARY_SCRIPTS"

  local before after out rc
  before=$(_snapshot "$sandbox")
  local out_before; out_before=$(_snapshot "$outside")

  # 실행 — **양 arm 을 같은 샌드박스 정책으로** 돌린다(2026-08-16 cross-family 지목).
  # 초판은 positive 만 돌렸는데, 등록 검사기 주석은 «M4 를 관측한다» 고 말했다 —
  # 구현과 주장이 어긋났고, **negative arm 에서만 쓰는 capability 가 통과**했다.
  # 실패는 VIOLATION 이 아니다 — 못 잰 것이다.
  local out2 rc2
  out=$(cd "$sandbox" && eval "$entry $pos_args" 2>&1); rc=$?
  out2=""; rc2=0
  if [ -n "$neg_args" ]; then
    out2=$(cd "$sandbox" && eval "$entry $neg_args" 2>&1); rc2=$?
    out="$out
$out2"
    [ "$rc2" -gt "$rc" ] && rc="$rc2"
  fi

  after=$(_snapshot "$sandbox")
  local out_after; out_after=$(_snapshot "$outside")

  local changed outside_changed
  changed=$([ "$before" = "$after" ] && echo 0 || echo 1)
  outside_changed=$([ "$out_before" = "$out_after" ] && echo 0 || echo 1)

  _cleanup_probe
  rm -rf "$outside"

  home_after=$(ls -A "$HOME" 2>/dev/null | LC_ALL=C sort | shasum -a 256 | cut -d" " -f1)
  local home_changed
  home_changed=$([ "$home_before" = "$home_after" ] && echo 0 || echo 1)

  if [ "$home_changed" = "1" ]; then
    printf '🟥 VIOLATION %s — **홈 디렉토리 엔트리가 바뀌었다**(절대경로 쓰기). 선언=%s\n' "$cap" "$declared"
    return "$RC_VIOLATION"
  fi

  if [ "$outside_changed" = "1" ]; then
    printf '🟥 VIOLATION %s — **샌드박스 밖**이 바뀌었다(절대경로 쓰기). 선언=%s\n' "$cap" "$declared"
    return "$RC_VIOLATION"
  fi

  if [ "$declared" = "read-only" ] && [ "$changed" = "1" ]; then
    printf '🟥 VIOLATION %s — `writes: read-only` 선언인데 샌드박스가 바뀌었다\n' "$cap"
    return "$RC_VIOLATION"
  fi

  # 못 돌았으면 «안 썼다» 가 아니다. rc 가 10(하네스 오류)이거나 실행 자체가 실패하고
  # 아무 변화도 없으면 판정 불가로 낸다 — 이게 이 프로브의 fail-closed 방향이다.
  if [ "$rc" -ge 10 ] || printf '%s' "$out" | grep -qiE 'command not found|no such file'; then
    printf '⚠️  UNVERIFIABLE %s — 진입점이 이 샌드박스에서 못 돌았다(rc=%s). 미측정이지 통과 아님\n' "$cap" "$rc"
    return "$RC_UNVERIFIABLE"
  fi

  printf '✅ VERIFIED %s — 선언=%s · 관측=%s\n' "$cap" "$declared" \
    "$([ "$changed" = "1" ] && echo "wrote" || echo "no-write")"
  return "$RC_OK"
}

self_test() {
  local d rc fails=0 pass=0
  d=$(mktemp -d)

  # ── known-negative: 진짜 read-only 인 capability ──────────────────────────
  cat > "$d/ro.cap" <<EOF
id: test:readonly
entry: bash -c 'ls >/dev/null'
writes: read-only
EOF
  probe_one "$d/ro.cap" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "0" ]; then pass=$((pass+1)); echo "✅ L1 진짜 read-only 는 VERIFIED"; else fails=$((fails+1)); echo "❌ L1 rc=$rc (0 기대)"; fi

  # ── known-positive: read-only 선언인데 쓴다 ───────────────────────────────
  cat > "$d/liar.cap" <<EOF
id: test:liar
entry: bash -c 'echo x > LIAR_WROTE_THIS'
writes: read-only
EOF
  probe_one "$d/liar.cap" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "1" ]; then pass=$((pass+1)); echo "✅ L2 거짓 read-only 선언은 VIOLATION"; else fails=$((fails+1)); echo "❌ L2 rc=$rc (1 기대)"; fi

  # ── 2026-08-11 실사고 재현: 진입점이 scripts/ 를 rm -rf 한다 ──────────────
  cat > "$d/rmrf.cap" <<EOF
id: test:rmrf
entry: bash -c 'rm -rf scripts'
writes: read-only
EOF
  probe_one "$d/rmrf.cap" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "1" ]; then pass=$((pass+1)); echo "✅ L3 rm -rf scripts (실사고 형태) VIOLATION"; else fails=$((fails+1)); echo "❌ L3 rc=$rc (1 기대)"; fi

  # ── write-local 선언은 써도 된다 (과차단 방지 컨트롤) ─────────────────────
  cat > "$d/wl.cap" <<EOF
id: test:writelocal
entry: bash -c 'echo x > OK_TO_WRITE'
writes: write-local
EOF
  probe_one "$d/wl.cap" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "0" ]; then pass=$((pass+1)); echo "✅ L4 write-local 선언은 써도 VERIFIED (과차단 아님)"; else fails=$((fails+1)); echo "❌ L4 rc=$rc (0 기대)"; fi

  # ── 못 도는 진입점은 PASS 가 아니다 ──────────────────────────────────────
  cat > "$d/dead.cap" <<EOF
id: test:dead
entry: this_command_does_not_exist_xyz
writes: read-only
EOF
  probe_one "$d/dead.cap" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "3" ]; then pass=$((pass+1)); echo "✅ L5 못 도는 진입점은 UNVERIFIABLE (통과 아님)"; else fails=$((fails+1)); echo "❌ L5 rc=$rc (3 기대)"; fi

  # ── 🟥 절대경로 탈출: $HOME 쓰기 (2026-08-16 자기 공격으로 발견) ──────────
  #   초판은 임시 카나리아 하나만 봐서 이게 **VERIFIED 로 통과**했고 홈에 파일이 실제로
  #   생겼다. 프로브 자신이 (d) 결함을 갖고 있었던 것이다.
  # 🟥 **리셋 먼저, 실행 나중.** 잔재가 있으면 홈 엔트리 해시가 안 바뀌어 이 레인이
  #    조용히 초록이 된다 — 순서 의존이고, cross-family 가 두 번 돌려 잡았다(2026-08-16).
  rm -f "$HOME/.fh_probe_selftest_canary"
  cat > "$d/abs.cap" <<EOF
id: test:abs-escape
entry: bash -c 'echo x > \$HOME/.fh_probe_selftest_canary'
writes: read-only
EOF
  probe_one "$d/abs.cap" >/dev/null 2>&1; rc=$?
  rm -f "$HOME/.fh_probe_selftest_canary"
  if [ "$rc" = "1" ]; then pass=$((pass+1)); echo "✅ L7 \$HOME 절대경로 쓰기는 VIOLATION"; else fails=$((fails+1)); echo "❌ L7 rc=$rc (1 기대) — 절대경로 탈출이 뚫렸다"; fi

  # ── writes 선언이 없으면 검증 대상이 아니다 ──────────────────────────────
  cat > "$d/nowrites.cap" <<EOF
id: test:nowrites
entry: bash -c 'true'
EOF
  probe_one "$d/nowrites.cap" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "10" ]; then pass=$((pass+1)); echo "✅ L6 writes 선언 부재는 HARNESS_ERROR"; else fails=$((fails+1)); echo "❌ L6 rc=$rc (10 기대)"; fi

  rm -rf "$d"
  echo "── capability_effect_probe lanes: $pass PASS / $fails FAIL ──"
  [ "$fails" = "0" ]
}

case "${1:-}" in
  --self-test) self_test; exit $?;;
  "") echo "usage: $0 <capfile> [...] | --self-test" >&2; exit "$RC_HARNESS";;
esac

worst=0
for c in "$@"; do
  probe_one "$c"; rc=$?
  [ "$rc" -gt "$worst" ] && worst=$rc
done
exit "$worst"
