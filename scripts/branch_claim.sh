#!/usr/bin/env bash
# branch_claim.sh — 공유 체크아웃에서 «내가 믿는 브랜치»와 «실제 HEAD»가 갈린 채 커밋되는 것을 막는다.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHY (2026-08-09 실측, FH 병렬 세션 2개, 한 체크아웃)
#   `.git/HEAD` 는 워킹트리당 하나다. 세션 A 의 `git switch` 는 세션 B 의 발밑도 옮긴다.
#     17:35  B 가 브랜치를 땄다        (B 는 «작업 시작할 때 브랜치부터 따기»를 이미 했다)
#     17:54  A 가 브랜치를 따며 트리 이동
#     18:10  B 가 자기 브랜치인 줄 알고 **A 의 브랜치에 커밋**
#   → 브랜치를 언제 따느냐는 무관하다. **HEAD 가 트리당 하나**인 게 원인이다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 판정 키 = «세션» 이지 «트리» 가 아니다  ★ 이게 이 스크립트의 핵심이고, 초판은 틀렸다
#   초판은 트리 단위 claim 하나를 두고 그것과 HEAD 를 비교했다. 적대검증이 실행으로 반증:
#   **양쪽 세션이 다 프로토콜을 지키면 정확히 그 사고를 못 잡는다** — A 가 switch 후 claim 하면
#   claim==HEAD 가 되어 B 의 check 가 통과한다. 채택률이 오를수록 무력해지는 게이트였다.
#   그래서 claim 을 **세션마다** 따로 둔다: `.git/fh-claims/<session_id>`.
#   비교는 **내 claim vs HEAD** 만 한다 — 남의 claim 은 내 판정에 안 들어오므로
#   peer 로 인한 과차단이 구조적으로 없다.
#
#   세션 정체성은 배관이 필요 없다. 실측(2026-08-09): git 훅은 Claude Code 가 주입한
#   `CLAUDE_CODE_SESSION_ID` · `CLAUDE_PID` 를 그대로 상속한다.
#
# WHAT THIS DOES / DOESN'T
#   막는다     : «내가 마지막으로 claim 한 브랜치» ≠ HEAD 인 채로 커밋
#   안 막는다  : `git switch` 자체 (git 에 switch 훅이 없다 — 막을 자리가 없다)
#   🟥 근본 해결이 아니다. 이건 **완화책**이다. 공유 체크아웃은 미커밋 워킹트리 혼입/유실도
#      낳고(그건 커밋 게이트로 안 닫힌다), 근본 처방은 **세션당 worktree** 다.
#      (worktree 를 쓰면 이 claim 도 자동으로 트리별로 갈린다 — `--git-dir` 이 갈리므로.
#       단 FH 자산 커밋은 worktree 에서 4축 증거가 구조적으로 부재하다는 별개 문제가 있다.)
#
# 🟥 TOCTOU 잔여 (cross-family 지적, 미해결): `check` 와 git 이 실제로 ref 를 갱신하는 순간
#    사이에 창이 있다. 그 사이 peer 가 switch 하면 이 게이트를 통과한 채 사고가 난다.
#    창은 «35분»에서 «훅 실행시간»으로 줄지만 0 이 아니다. 정통 처방은 pre-commit 이 아니라
#    **`reference-transaction` 훅** — 갱신 대상 ref 를 stdin 으로 받으므로 원자적으로 판정된다.
#    지금은 짓지 않았다(별개 훅 = 별개 변경). 완화로 훅 말미에 재검사를 한 번 더 돌린다.
#
# DEGRADE DIRECTION
#   claim 없음 / 손상 / detached·rebase·bisect 중  → **통과**.
#   근거는 **«과차단은 override 를 습관화시켜 게이트를 죽인다»** 하나다(FH 실측 반복 기록).
#   ⚠️ «커밋은 가역이니까» 를 근거로 쓰지 않는다 — 이 사고의 실제 복구는 공유 브랜치
#   history rewrite 로 갔고, 그건 Surface-Class Degrade Invariant 가 fail-closed 로 두는 표면이다.
#   근거를 하나로 좁히지 않으면 나중에 «가역이니 여기도 완화하자» 로 잘못 일반화된다.
#
#   동시성 증거 없음(살아있는 peer 세션 claim 0개) → **경고만, 차단 안 함.**
#   1인 작업자에겐 이 게이트의 편익이 0이고 비용만 있다.
#   불일치 + 살아있는 peer 존재 → **차단.** override = FH_BRANCH_CLAIM_OK=1 (파일에 기록된다).
#
# USAGE
#   bash scripts/branch_claim.sh claim [<label>]   # 현재 HEAD 를 «내 브랜치»로 기록
#   bash scripts/branch_claim.sh check             # pre-commit 이 부르는 것 (0=통과 1=차단)
#   bash scripts/branch_claim.sh show | release | reap
#
# ENV (운영)
#   FH_BRANCH_CLAIM_OK=1   차단 1회 우회 — override 로그에 append 된다
# ENV (테스트 전용 — FH_CLAIM_TEST=1 없이는 전부 무시된다)
#   FH_CLAIM_TEST=1  FH_CLAIM_DIR  FH_CLAIM_NOW  FH_CLAIM_STALE_HOURS  FH_CLAIM_SESSION
#   ↑ 게이팅하는 이유: 초판은 이 노브들이 프로덕션에서도 먹어서 **정직한 override 보다
#     조용한 우회가 더 쉬웠다**(FH_CLAIM_FILE=/dev/null → rc=0, 화면에 아무 표시 없음).
#
# bash 3.2(macOS) 호환: 연관배열·${v^^}·mapfile 안 씀.
# `stat` 안 씀 — epoch 을 파일 안에 적는다(BSD/GNU `stat -f` 분기 회피).

set -uo pipefail

_test_mode() { [ "${FH_CLAIM_TEST:-}" = "1" ]; }
_now()   { if _test_mode && [ -n "${FH_CLAIM_NOW:-}" ]; then echo "$FH_CLAIM_NOW"; else date +%s; fi; }
_stale_hours() { if _test_mode && [ -n "${FH_CLAIM_STALE_HOURS:-}" ]; then echo "$FH_CLAIM_STALE_HOURS"; else echo 12; fi; }

# 세션 정체성. Claude Code 가 주입한다(실측). 없으면 셸 PID 로 폴백 — 그 경우
# «세션»은 사실상 «이 프로세스 트리»가 되고, 게이트는 여전히 동작하되 범위가 좁아진다.
_session_id() {
  if _test_mode && [ -n "${FH_CLAIM_SESSION:-}" ]; then echo "$FH_CLAIM_SESSION"; return; fi
  if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ]; then echo "$CLAUDE_CODE_SESSION_ID"; return; fi
  echo "pid-${PPID:-$$}"
}
_session_pid() { echo "${CLAUDE_PID:-${PPID:-$$}}"; }

# 절대경로 강제: 본 트리에서 `--git-dir` 은 상대 ".git" 이라, 서브디렉터리에서 실행하면
# 엉뚱한 곳에 claim 을 만들어 «점유 없음»으로 조용히 통과한다 = 게이트 무력화.
_git_dir() {
  local d
  d=$(git rev-parse --absolute-git-dir 2>/dev/null) && [ -n "$d" ] && { echo "$d"; return 0; }
  local top; top=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  d=$(git rev-parse --git-dir 2>/dev/null) || return 1
  case "$d" in /*) echo "$d" ;; *) echo "$top/$d" ;; esac
}

_claim_dir() {
  if _test_mode && [ -n "${FH_CLAIM_DIR:-}" ]; then echo "$FH_CLAIM_DIR"; return 0; fi
  local gd; gd=$(_git_dir) || return 1
  echo "$gd/fh-claims"
}
_my_claim() { local d; d=$(_claim_dir) || return 1; echo "$d/$(_session_id)"; }

_head_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null; }
_field() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -1; }

# 출력하는 복구 명령에 브랜치명을 그대로 박으면 안 된다: git ref 는 공백은 못 쓰지만
# `;` `$` `(` `)` `&` `|` 백틱은 **허용**한다. 복붙하면 주입형 사고가 난다(cross-family 지적).
# bash 3.2 라 printf %q 대신 single-quote escape 로 감싼다.
_shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# 브랜치가 «지금 어디에 얹히는가»의 질문이 성립하지 않는 상태들.
# 초판은 detached 를 차단해서 rebase --edit 중 커밋을 막았고, 제시한 세 선택지 중
# 하나는 실행 불가(claim 이 detached 를 거부), 하나는 rebase 를 깨는 switch 였다.
# 남는 게 override 뿐이면 그건 override 훈련이다.
_inapplicable_state() {
  local b gd; b=$(_head_branch); gd=$(_git_dir) || return 1
  [ "$b" = "HEAD" ] && return 0
  for m in rebase-merge rebase-apply BISECT_LOG MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD; do
    [ -e "$gd/$m" ] && return 0
  done
  return 1
}

# 살아있는 **다른** 세션의 claim 개수 (동시성 증거). 죽은 세션 claim 은 안 센다.
_live_peers() {
  local d me n=0 f sid pid
  d=$(_claim_dir) || { echo 0; return; }
  [ -d "$d" ] || { echo 0; return; }
  me=$(_session_id)
  for f in "$d"/*; do
    [ -f "$f" ] || continue
    sid=$(basename "$f"); [ "$sid" = "$me" ] && continue
    pid=$(_field "$f" pid)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then n=$((n+1)); fi
  done
  echo "$n"
}

_override_log() { local gd; gd=$(_git_dir) || return 1; echo "$gd/fh-branch-claim-overrides.log"; }

cmd_claim() {
  local label="${1:-${USER:-unknown}}" d f b now
  d=$(_claim_dir) || { echo "branch-claim: git 저장소가 아니다 — 아무것도 안 한다"; return 0; }
  b=$(_head_branch)
  if [ -z "$b" ] || [ "$b" = "HEAD" ]; then
    echo "branch-claim: HEAD 가 detached 라 기록하지 않는다 (브랜치 위에서 실행해라)" >&2
    return 2
  fi
  mkdir -p "$d" || return 1
  f=$(_my_claim); now=$(_now)
  # 원자적 교체: 같은 디렉터리 내 rename. in-place truncate 는 동시 read 에서 필드가 찢어진다
  # (실측: 동시 claim 300회 중 9회 owner 필드 파손).
  printf 'branch=%s\nlabel=%s\npid=%s\nat_epoch=%s\n' "$b" "$label" "$(_session_pid)" "$now" \
    > "$f.tmp.$$" && mv -f "$f.tmp.$$" "$f" || return 1
  echo "✅ branch-claim: 이 세션의 브랜치를 '$b' 로 기록했다 (label=$label)"
  local peers; peers=$(_live_peers)
  [ "$peers" -gt 0 ] && echo "   살아있는 peer 세션 claim: $peers 개 — 게이트 활성"
  return 0
}

cmd_release() {
  local f; f=$(_my_claim) 2>/dev/null || return 0
  if [ -f "$f" ]; then rm -f "$f"; echo "branch-claim: 이 세션의 기록을 지웠다"; else echo "branch-claim: 기록 없음"; fi
  return 0
}

# 죽은 세션의 claim 정리
cmd_reap() {
  local d f sid pid n=0
  d=$(_claim_dir) || return 0; [ -d "$d" ] || { echo "branch-claim: 기록 디렉터리 없음"; return 0; }
  for f in "$d"/*; do
    [ -f "$f" ] || continue
    pid=$(_field "$f" pid)
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then rm -f "$f"; n=$((n+1)); fi
  done
  echo "branch-claim: 죽은 세션 기록 $n 개 정리"
}

cmd_show() {
  local d f me; d=$(_claim_dir) || { echo "(git 저장소 아님)"; return 0; }
  me=$(_session_id)
  echo "HEAD      $(_head_branch)"
  echo "세션ID    $me"
  echo "살아있는 peer claim: $(_live_peers)"
  if [ -d "$d" ]; then
    for f in "$d"/*; do
      [ -f "$f" ] || continue
      local sid pid alive; sid=$(basename "$f"); pid=$(_field "$f" pid)
      if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then alive=live; else alive=dead; fi
      printf '  %s %s  branch=%s label=%s (%s)\n' \
        "$([ "$sid" = "$me" ] && echo '→' || echo ' ')" "$sid" \
        "$(_field "$f" branch)" "$(_field "$f" label)" "$alive"
    done
  else echo "  (기록 없음)"; fi
}

# 0 = 통과, 1 = 차단
cmd_check() {
  local f b cb cl ca now age lim peers
  f=$(_my_claim) 2>/dev/null || return 0
  b=$(_head_branch); [ -n "$b" ] || return 0
  if _inapplicable_state; then return 0; fi        # detached·rebase·bisect·merge 중 → 질문이 성립 안 함
  [ -f "$f" ] || return 0                          # 이 세션의 기록 없음 → 의견 없음 (부재 ≠ 위반)

  cb=$(_field "$f" branch); cl=$(_field "$f" label); ca=$(_field "$f" at_epoch)
  if [ -z "$cb" ]; then
    echo "  ⚠️  branch-claim: 내 기록을 파싱 못 했다 — 통과시킨다 (fail-open, 과차단 회피)"
    return 0
  fi
  if [ "$cb" = "$b" ]; then
    # 일치 → 갱신해서 나이가 «재임 기간»이 아니라 «유휴 시간»을 재게 한다.
    # (초판은 갱신을 안 해서, 오래 붙어 있는 세션일수록 STALE 로 무방비가 됐다.)
    now=$(_now)
    printf 'branch=%s\nlabel=%s\npid=%s\nat_epoch=%s\n' "$cb" "$cl" "$(_session_pid)" "$now" \
      > "$f.tmp.$$" 2>/dev/null && mv -f "$f.tmp.$$" "$f" 2>/dev/null
    return 0
  fi

  now=$(_now); lim=$(_stale_hours)
  if [ -n "$ca" ] && [ "$ca" -eq "$ca" ] 2>/dev/null; then
    age=$(( (now - ca) / 3600 ))
    if [ "$age" -ge "$lim" ]; then
      echo "  ⚠️  branch-claim: 내 기록이 STALE(${age}h ≥ ${lim}h) — 차단하지 않는다."
      echo "      기록='$cb' · HEAD='$b'   →  맞으면: bash scripts/branch_claim.sh claim"
      return 0
    fi
  fi

  peers=$(_live_peers)
  if [ "$peers" -eq 0 ]; then
    echo "  ⚠️  branch-claim: 기록('$cb')과 HEAD('$b')가 다르다 — 살아있는 peer 세션이 없어 차단하지 않는다."
    echo "      의도한 전환이면:  bash scripts/branch_claim.sh claim"
    return 0
  fi

  if [ "${FH_BRANCH_CLAIM_OK:-}" = "1" ]; then
    local lg; lg=$(_override_log 2>/dev/null)
    [ -n "$lg" ] && printf '%s override claim=%s head=%s session=%s peers=%s\n' \
      "$(_now)" "$cb" "$b" "$(_session_id)" "$peers" >> "$lg" 2>/dev/null
    echo "  ⚠️  branch-claim: 불일치인데 FH_BRANCH_CLAIM_OK=1 로 우회한다."
    echo "      기록='$cb' · HEAD='$b' · 로그: ${lg:-<기록 실패>}"
    return 0
  fi

  echo "  ❌ branch-claim: 이 세션은 '$cb' 로 기록돼 있는데 HEAD 는 '$b' 다."
  echo "     살아있는 peer 세션 $peers 개가 이 체크아웃을 같이 쓴다 — 그 중 하나가 브랜치를 옮겼다."
  echo "     ⚠️  지금 커밋하면 '$b' 브랜치에 얹힌다 — 2026-08-09 에 실제로 난 사고다."
  echo
  echo "     ▸ '$b' 가 맞다       :  bash scripts/branch_claim.sh claim"
  echo "     ▸ '$cb' 로 돌아간다  :  git switch -- $(_shq "$cb")"
  echo "        ⚠️  돌아가면 지금 '$b' 를 쓰는 세션의 발밑을 뺀다. 먼저 한 줄 알려라."
  echo "     ▸ 근본 해결        :  세션당 worktree (이 게이트는 완화책이다)"
  echo "     ▸ 알고도 강행      :  FH_BRANCH_CLAIM_OK=1 git commit …"
  return 1
}

case "${1:-check}" in
  claim)   shift; cmd_claim "${1:-}" ;;
  release) cmd_release ;;
  reap)    cmd_reap ;;
  show)    cmd_show ;;
  check)   cmd_check ;;
  *) echo "usage: $0 {claim [label]|check|show|release|reap}" >&2; exit 2 ;;
esac
