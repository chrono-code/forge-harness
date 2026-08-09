#!/usr/bin/env bash
# test_branch_claim_lanes.sh — branch_claim.sh known-pair 앵커.
#
# 왜 실행 테스트인가: `bash -n` 은 계기가 아니다 — 문법만 보고 exit 0 을 내므로
# «전부 통과»와 구분이 안 된다([[feedback_gate_verification_must_execute]]).
# «막혔다» ≠ «옳게 막혔다» 이므로 BLOCK 레인은 **완성 문장**으로 매칭한다 —
# 조각 매칭은 claim/HEAD 역할을 뒤집는 뮤테이션을 통과시켰다(적대검증 A-5 실측).
# 그 역할 뒤바뀜은 사용자를 반대 브랜치로 보내므로 게이트가 사고를 만드는 쪽이 된다.
#
# 격리: 레인마다 임시 저장소를 새로 판다. 실제 레포는 안 건드린다.
# 세션 시뮬레이션: FH_CLAIM_TEST=1 + FH_CLAIM_SESSION 으로 두 세션을 흉내낸다.
#
# usage: bash scripts/test_branch_claim_lanes.sh

set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")" && pwd)/branch_claim.sh"
PASS=0; FAIL=0; LIVE_PID=""

cleanup() {
  [ -n "$LIVE_PID" ] && kill "$LIVE_PID" 2>/dev/null
  [ -n "${SOCK_EMPTY:-}" ] && rm -rf "$SOCK_EMPTY"
  return 0
}
trap cleanup EXIT

_mkrepo() {
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/bclaim.XXXXXX")
  git -C "$d" init -q -b main
  git -C "$d" config user.email t@t; git -C "$d" config user.name t
  echo x > "$d/f"; git -C "$d" add f; git -C "$d" commit -qm init
  echo "$d"
}
# 살아있는 peer 세션 하나를 실제 프로세스로 만든다 (kill -0 이 참이 되도록)
# ⚠️ 반드시 fd 를 닫아서 띄운다: 백그라운드 프로세스가 stdout 을 물고 있으면
#    이 스크립트를 파이프에 물릴 때 파이프가 안 닫혀 무한 대기한다(실측: 120s 타임아웃).
_spawn_live() { sleep 900 >/dev/null 2>&1 & LIVE_PID=$!; echo "$LIVE_PID"; }

_lane() { # name expected_rc actual_rc [must_contain...]
  local name="$1" exp="$2" got="$3"; shift 3
  local out="$LANE_OUT" ok=1 pat
  [ "$got" = "$exp" ] || { ok=0; echo "  ❌ $name — rc=$got (기대 $exp)"; }
  for pat in "$@"; do
    case "$out" in *"$pat"*) ;; *) ok=0; echo "  ❌ $name — 출력에 «${pat}» 없음";; esac
  done
  if [ "$ok" = 1 ]; then echo "  ✅ $name"; PASS=$((PASS+1)); else FAIL=$((FAIL+1));
    echo "     ── 실제 출력 ──"; echo "$out" | sed 's/^/     /'; fi
}
_ok() { if [ "$2" = 1 ]; then echo "  ✅ $1"; PASS=$((PASS+1)); else echo "  ❌ $1"; FAIL=$((FAIL+1)); fi; }

# 세션 B(=peer)의 claim 을 살아있는 pid 로 직접 심는다
_plant_peer() { # repo branch pid
  mkdir -p "$1/.git/fh-claims"
  printf 'branch=%s\nlabel=peer\npid=%s\nat_epoch=%s\n' "$2" "$3" "$(date +%s)" \
    > "$1/.git/fh-claims/session-PEER"
}

# ⚠️ 주변 환경을 흡입하지 않는다 — 이 한 줄이 없어서 이 스위트는 «거짓 초록» 이었다.
# branch_claim.sh 의 `_session_pid() { echo "${CLAUDE_PID:-${PPID:-$$}}"; }` 때문에, 저자 셸에
# CLAUDE_PID 가 있으면 claim 이 **살아있는 pid**(그 Claude 프로세스)를 기록한다. 레인 ③ 은
# A 가 재-claim 해서 peer 기록을 덮는 시나리오라, 그 pid 가 살아있느냐가 판정을 통째로 뒤집는다.
# 실측 2026-08-09 (known-pair, 같은 트리·같은 커밋):
#   CLAUDE_PID 있음 → 24 PASS / 0 FAIL      (저자 로컬 — 초록)
#   CLAUDE_PID 없음 → 23 PASS / 1 FAIL ③   (CI — 적색, rc=0 기대 1)
# 즉 코드가 아니라 **저자 환경**을 재고 있었고, 그 초록이 S-1 재설계의 유일한 증명이었다.
# 앵커가 배선되기 전까지(=호출부 0개) 이 사실은 드러날 수 없었다.
unset CLAUDE_PID

# ⚠️ 같은 이유로 **소켓 경로도 환경에서 빌리지 않는다.** _unclaimed_risk 가 기본으로 실제
# `/tmp/cc-socks` 를 보므로, 그대로 두면 «지금 이 머신에 CC 세션이 몇 개 떠 있나» 가 레인
# 판정을 바꾼다 — 실측 2026-08-09: 이 수정을 넣자 레인 ④ 가 즉시 깨졌다(실제 세션 5개).
# **위의 CLAUDE_PID 와 같은 결함을 수리 그 자체가 재생산한 것**이라, 같은 처방을 붙인다.
# 개별 레인은 필요할 때 이 값을 인라인으로 덮는다.
SOCK_EMPTY=$(mktemp -d "${TMPDIR:-/tmp}/bcsock0.XXXXXX")
export FH_CLAIM_SOCK_DIR="$SOCK_EMPTY"

echo "[branch-claim] known-pair 앵커"
PEERPID=$(_spawn_live)

# ── ① 기록 없음 → 통과 (부재 ≠ 위반) ───────────────────────────────────────
R=$(_mkrepo); LANE_OUT=$(cd "$R" && bash "$SCRIPT" check 2>&1); rc=$?
_lane "① 기록 없음 → 통과" 0 "$rc"; rm -rf "$R"

# ── ② 내 기록 == HEAD → 통과, 그리고 at_epoch 이 갱신된다 (A-6) ────────────
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me FH_CLAIM_NOW=1000 bash "$SCRIPT" claim a >/dev/null 2>&1)
before=$(sed -n 's/^at_epoch=//p' "$R/.git/fh-claims/me")
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me FH_CLAIM_NOW=99000 bash "$SCRIPT" check 2>&1); rc=$?
after=$(sed -n 's/^at_epoch=//p' "$R/.git/fh-claims/me")
_lane "② 내 기록==HEAD → 통과" 0 "$rc"
_ok "②-b at_epoch 갱신됨 (${before} -> ${after}) — 나이가 «유휴»를 재게 된다" "$([ "$after" = 99000 ] && echo 1 || echo 0)"
rm -rf "$R"

# ── ③ ★ S-1 회귀: 양쪽 세션이 다 프로토콜을 지켜도 잡는다 ──────────────────
#    초판 설계는 여기서 통과했다(= 오늘 사고를 못 막았다). 이 레인이 그 반증이다.
#    타임라인: B가 main claim → A가 switch+claim(프로토콜 준수) → B가 커밋 시도
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=B bash "$SCRIPT" claim bee >/dev/null 2>&1)
_plant_peer "$R" main "$PEERPID"                        # A 를 살아있는 peer 로
git -C "$R" switch -q -c ifkakao                        # A 가 트리를 옮기고
# A 는 «살아있는» 세션이다 — 그 사실을 환경에서 빌리지 말고 레인이 직접 고정한다.
# CLAUDE_PID 를 안 주면 claim 이 곧 죽을 서브셸의 PPID 를 기록하고, B 의 check 는
# «살아있는 peer 0» 으로 통과한다 — 시나리오가 성립하지도 않은 채 초록이 된다.
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=session-PEER CLAUDE_PID="$PEERPID" bash "$SCRIPT" claim ay >/dev/null 2>&1)  # 프로토콜대로 claim
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=B bash "$SCRIPT" check 2>&1); rc=$?
_lane "③ ★S-1 회귀: 양쪽이 프로토콜을 지켜도 B 는 차단된다" 1 "$rc" \
      "이 세션은 'main' 로 기록돼 있는데 HEAD 는 'ifkakao' 다" "git switch -- 'main'"
rm -rf "$R"

# ── ④ 불일치인데 살아있는 peer 없음 → 경고만, 통과 (A-2 과차단 방지) ───────
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=solo bash "$SCRIPT" claim s >/dev/null 2>&1)
git -C "$R" switch -q -c next
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=solo bash "$SCRIPT" check 2>&1); rc=$?
_lane "④ 1인 세션(살아있는 peer 0) → 차단 안 함" 0 "$rc" "살아있는 peer 세션이 없어"
rm -rf "$R"

# ── ④-b 컨트롤: 같은 상황에 살아있는 peer 가 있으면 차단 ───────────────────
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=solo bash "$SCRIPT" claim s >/dev/null 2>&1)
_plant_peer "$R" whatever "$PEERPID"
git -C "$R" switch -q -c next
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=solo bash "$SCRIPT" check 2>&1); rc=$?
_lane "④-b 컨트롤: peer 살아있으면 차단 (④가 무조건 통과가 아님)" 1 "$rc"
rm -rf "$R"

# ── ④-c 죽은 peer 는 동시성 증거가 아니다 ──────────────────────────────────
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=solo bash "$SCRIPT" claim s >/dev/null 2>&1)
_plant_peer "$R" whatever 999999                        # 존재하지 않는 pid
git -C "$R" switch -q -c next
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=solo bash "$SCRIPT" check 2>&1); rc=$?
_lane "④-c 죽은 peer → 차단 안 함 (시간 상수 의존을 줄인다)" 0 "$rc"
rm -rf "$R"

# ── ⑤ STALE → 통과 / 임계 미만 → 차단 ──────────────────────────────────────
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me FH_CLAIM_NOW=0 bash "$SCRIPT" claim s >/dev/null 2>&1)
_plant_peer "$R" x "$PEERPID"; git -C "$R" switch -q -c other
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me FH_CLAIM_NOW=$((13*3600)) bash "$SCRIPT" check 2>&1); rc=$?
_lane "⑤ STALE(13h) → 통과" 0 "$rc" "STALE"
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me FH_CLAIM_NOW=$((11*3600)) bash "$SCRIPT" check 2>&1); rc=$?
_lane "⑤-b 컨트롤: 11h → 여전히 차단" 1 "$rc"
rm -rf "$R"

# ── ⑥ override → 통과 + **파일에 실제로 기록** (A-4 팬텀 주장 수리) ────────
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim s >/dev/null 2>&1)
_plant_peer "$R" x "$PEERPID"; git -C "$R" switch -q -c other
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me FH_BRANCH_CLAIM_OK=1 bash "$SCRIPT" check 2>&1); rc=$?
_lane "⑥ override → 통과" 0 "$rc" "FH_BRANCH_CLAIM_OK"
_ok "⑥-b override 로그 파일이 실제로 생성·append 됨" \
    "$([ -s "$R/.git/fh-branch-claim-overrides.log" ] && echo 1 || echo 0)"
rm -rf "$R"

# ── ⑦ detached / rebase 중 → 통과 (A-1 과차단 수리) ────────────────────────
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim s >/dev/null 2>&1)
_plant_peer "$R" x "$PEERPID"; git -C "$R" checkout -q --detach
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" check 2>&1); rc=$?
_lane "⑦ detached HEAD → 통과 (rebase/bisect 중 커밋을 막지 않는다)" 0 "$rc"
rm -rf "$R"
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim s >/dev/null 2>&1)
_plant_peer "$R" x "$PEERPID"; git -C "$R" switch -q -c other; mkdir -p "$R/.git/rebase-merge"
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" check 2>&1); rc=$?
_lane "⑦-b rebase 진행 중 → 통과" 0 "$rc"
rm -rf "$R"

# ── ⑧ 테스트 노브는 FH_CLAIM_TEST=1 없이 무시된다 (A-3 무음 우회 차단) ─────
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim s >/dev/null 2>&1)
_plant_peer "$R" x "$PEERPID"; git -C "$R" switch -q -c other
# 테스트 모드 없이 노브만 주면 → 세션ID 폴백이 달라 기록을 못 찾아 통과할 수 있으므로,
# 실제 세션ID를 고정해 두고 STALE/NOW 노브가 먹지 않는지만 본다
export CLAUDE_CODE_SESSION_ID=me
LANE_OUT=$(cd "$R" && FH_CLAIM_STALE_HOURS=0 FH_CLAIM_NOW=99999999999 bash "$SCRIPT" check 2>&1); rc=$?
_lane "⑧ FH_CLAIM_TEST 없이 STALE/NOW 노브 → 무시되고 차단 유지" 1 "$rc"
unset CLAUDE_CODE_SESSION_ID
rm -rf "$R"

# ── ⑨ 워크트리는 기록이 분리된다 ───────────────────────────────────────────
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim s >/dev/null 2>&1)
WT="$R-wt"; git -C "$R" worktree add -q -b wtb "$WT" >/dev/null 2>&1
if [ -d "$WT" ]; then
  LANE_OUT=$(cd "$WT" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" check 2>&1); rc=$?
  _lane "⑨ 워크트리는 기록 분리 → 통과" 0 "$rc"
  git -C "$R" worktree remove --force "$WT" >/dev/null 2>&1
else echo "  ⚠️  ⑨ 워크트리 생성 실패 — SKIPPED(통과로 세지 않음)"; fi
rm -rf "$R" "$WT"

# ── ⑩ 서브디렉터리에서도 같은 기록을 본다 (상대 .git 절대화) ───────────────
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim s >/dev/null 2>&1)
_plant_peer "$R" x "$PEERPID"; git -C "$R" switch -q -c other; mkdir -p "$R/deep/nested"
LANE_OUT=$(cd "$R/deep/nested" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" check 2>&1); rc=$?
_lane "⑩ 서브디렉터리에서도 차단" 1 "$rc"
_ok "⑩-b 기록이 저장소 .git 에만 생성됨" \
    "$([ -d "$R/.git/fh-claims" ] && [ ! -d "$R/deep/nested/.git" ] && echo 1 || echo 0)"
rm -rf "$R"

# ── ⑪ release / reap / show 도 앵커가 있다 (B-3 무앵커 경로 수리) ──────────
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim s >/dev/null 2>&1)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" release >/dev/null 2>&1)
_ok "⑪ release 가 실제로 기록을 지운다" "$([ ! -f "$R/.git/fh-claims/me" ] && echo 1 || echo 0)"
_plant_peer "$R" x 999999
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" reap >/dev/null 2>&1)
_ok "⑪-b reap 이 죽은 세션 기록을 지운다" "$([ ! -f "$R/.git/fh-claims/session-PEER" ] && echo 1 || echo 0)"
_plant_peer "$R" zzz "$PEERPID"
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" show 2>&1); rc=$?
_lane "⑪-c show 가 HEAD·세션·peer 를 낸다" 0 "$rc" "HEAD" "살아있는 peer claim: 1" "zzz"
rm -rf "$R"

# ── ⑫ 복구 명령의 브랜치명이 shell-quote 된다 (cross-family B-6) ──────────
#     git ref 는 공백은 못 쓰지만 `;` `$` 는 허용한다. 복붙 시 주입형 사고.
R=$(_mkrepo); B='a;touch$IFS/tmp/BCLAIM_PWNED'
git -C "$R" branch "$B" >/dev/null 2>&1 && git -C "$R" switch -q "$B"
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim s >/dev/null 2>&1)
_plant_peer "$R" x "$PEERPID"; git -C "$R" switch -q main
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" check 2>&1); rc=$?
EXPECT="git switch -- '${B}'"
_lane "⑫ metachar 브랜치명이 인용된 채 출력된다" 1 "$rc" "$EXPECT"
rm -rf "$R"

# ── ⑬ --if-absent: 없으면 만들고, 있으면 안 덮는다 (세션시작 훅이 부르는 형태) ──
#     훅 안에 같은 로직을 복제하면 앵커가 안 걸리므로 스크립트에 두고 여기서 잡는다.
R=$(_mkrepo)
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim --if-absent s 2>&1); rc=$?
_ok "⑬ --if-absent: 기록 없으면 생성" \
    "$([ "$rc" = 0 ] && [ -f "$R/.git/fh-claims/me" ] && echo 1 || echo 0)"
git -C "$R" switch -q -c moved            # 브랜치가 옮겨진 뒤 다시 불러도
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim --if-absent s 2>&1); rc=$?
kept=$(sed -n 's/^branch=//p' "$R/.git/fh-claims/me")
_lane "⑬-b --if-absent: 기록 있으면 덮지 않는다" 0 "$rc" "이미 있다"
_ok "⑬-c 기존 값 보존 (main 이어야 함 · 지금=$kept)" "$([ "$kept" = main ] && echo 1 || echo 0)"
# ★ 이게 중요한 이유: 덮으면 「내가 믿는 브랜치」가 매 세션시작마다 HEAD 로 갱신돼
#   게이트가 영원히 통과한다 — 자동화가 게이트를 무장해제하는 경로다
rm -rf "$R"

# ── ⑭ «peer 없음» 과 «못 가름» 을 나눈다 (2026-08-09 라이브 거짓 음성 N=2 회귀) ──
#     _live_peers 는 claim 기록만 센다 → claim 안 한 세션을 구조적으로 못 본다.
#     그걸 0 으로 렌더한 게 라이브 결함이었다. 세 값이 **각각 다른 문장**을 내야 한다.
#     ⚠️ 세 팔이 rc 는 전부 0(차단 안 함)이라 **rc 로는 구분이 안 된다** — 출력으로 잡는다.
#        이 레인이 rc 만 봤으면 세 팔 다 통과하고 아무것도 안 잡았을 것이다.
_sockdir() { local d; d=$(mktemp -d "${TMPDIR:-/tmp}/bcsock.XXXXXX"); echo "$d"; }

# ⑭ 소켓엔 살아있는 세션이 있는데 claim 은 0 → 「판정할 수 없다」
R=$(_mkrepo); S=$(_sockdir); : > "$S/${PEERPID}.sock"
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim a >/dev/null 2>&1)
git -C "$R" switch -q -c other
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me FH_CLAIM_SOCK_DIR="$S" bash "$SCRIPT" check 2>&1); rc=$?
_lane "⑭ claim 0 인데 살아있는 세션 있음 → «판정할 수 없다»" 0 "$rc" \
      "판정할 수 없다" "구분하지 못한다" "«안전» 이 아니라 «미판정»"
rm -rf "$R" "$S"

# ⑭-b 컨트롤: 소켓 디렉터리는 있는데 살아있는 세션이 없다 → 진짜 「peer 없음」
R=$(_mkrepo); S=$(_sockdir)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim a >/dev/null 2>&1)
git -C "$R" switch -q -c other
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me FH_CLAIM_SOCK_DIR="$S" bash "$SCRIPT" check 2>&1); rc=$?
_lane "⑭-b 컨트롤: 살아있는 세션 0 → «peer 없음» 이라고 단정한다" 0 "$rc" \
      "살아있는 peer 세션이 없어" "이 머신에 다른 CC 세션도 없다"
_ok "⑭-b′ 그 팔엔 «판정할 수 없다» 가 없다(문장이 갈린다)" \
    "$(printf '%s' "$LANE_OUT" | grep -q "판정할 수 없다" && echo 0 || echo 1)"
rm -rf "$R" "$S"

# ⑭-c 소켓 경로 자체가 없다 → 0 이 아니라 「교차 확인 불가」
#     런타임이 소켓 경로를 바꾸면 여기로 떨어진다. 그때 «peer 없음» 이라고 말하면 안 된다.
R=$(_mkrepo)
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim a >/dev/null 2>&1)
git -C "$R" switch -q -c other
LANE_OUT=$(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me FH_CLAIM_SOCK_DIR="/nonexistent-$$" bash "$SCRIPT" check 2>&1); rc=$?
_lane "⑭-c 소켓 경로 부재 → «교차 확인 불가»(0 아님)" 0 "$rc" "교차 확인 불가"
_ok "⑭-c′ 그 팔은 «peer 없음» 이라고 단정하지 않는다" \
    "$(printf '%s' "$LANE_OUT" | grep -q "이 머신에 다른 CC 세션도 없다" && echo 0 || echo 1)"
rm -rf "$R"

# ⑭-d 노브 게이팅: FH_CLAIM_TEST 없이 FH_CLAIM_SOCK_DIR 를 주면 **무시돼야** 한다.
#     안 그러면 프로덕션에서 소켓 경로를 갈아끼워 게이트를 무력화할 수 있다
#     (이 파일이 이미 같은 결함으로 한 번 수리된 적이 있다 — 테스트 노브 6종 무음 우회).
R=$(_mkrepo); S=$(_sockdir); : > "$S/${PEERPID}.sock"
(cd "$R" && FH_CLAIM_TEST=1 FH_CLAIM_SESSION=me bash "$SCRIPT" claim a >/dev/null 2>&1)
git -C "$R" switch -q -c other
LANE_OUT=$(cd "$R" && FH_CLAIM_SESSION=me FH_CLAIM_SOCK_DIR="$S" bash "$SCRIPT" check 2>&1); rc=$?
_ok "⑭-d 노브가 FH_CLAIM_TEST 없이는 무시된다(실경로를 본다)" \
    "$(printf '%s' "$LANE_OUT" | grep -qF -- "$S" && echo 0 || echo 1)"
rm -rf "$R" "$S"

echo
echo "[branch-claim] PASS=$PASS  FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
