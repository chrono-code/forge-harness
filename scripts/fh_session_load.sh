#!/usr/bin/env bash
# fh_session_load.sh — Mode D SessionStart companion-store freshness load (mechanical).
#
# WHY: the session-start companion-store load (refresh the private companion store + read its
# INDEX + card-vs-commit freshness) is documented in CLAUDE.local.md / modes_and_value.md
# §Session-start freshness as PROSE. Prose is salience-dependent: when the operator opens a
# session with an immediate task, the load silently does not fire and the agent operates on
# stale local memory. (Measured miss 2026-07-05: stale sidecar-tool version + a missed standing
# instruction, both because the companion refresh was skipped on task-first entry.) A
# SessionStart hook fires BEFORE the first user turn regardless of what the user types — so it
# closes the salience gap mechanically. This is the deferred hook in operational_adaptation.md
# §Guards whose measured revisit-trigger has now fired.
#
# WHAT: refresh the companion store, then emit a SHORT, IMPERATIVE freshness delta to stdout.
# A SessionStart hook's stdout is injected into the session context, so this block becomes
# unavoidable context the agent sees at turn 0.
#
# Graceful: if no companion store is configured (non-Mode-D user / ephemeral clone), emit
# nothing and exit 0 — this hook is a silent no-op outside Mode D. Offline-safe: refresh
# failure never blocks the session.
#
# Config (operator-local, opt-in): register in .claude/settings.local.json SessionStart and pass
# the companion-store path via the BE_DIR env in that gitignored registration (the public script
# hard-codes no private path). HUB_DIR overrides the hub path. Never commit the registration to
# the public settings.json — the hook is Mode-D-only.


# ── SessionStart source (단일 소스 lib) ─────────────────────────────────────────
# stdin 페이로드는 **한 번만** 읽을 수 있으므로 맨 앞에서 소비하고 변수로 들고 간다.
_FH_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hook_source_lib.sh"
# shellcheck source=scripts/hook_source_lib.sh
if [ -f "$_FH_LIB" ]; then . "$_FH_LIB"; else
  # lib 부재 = 파싱 불가. 무음으로 억제하지 말고 unknown(=띄운다) 으로 degrade 한다.
  fh_hook_source() { printf 'unknown\n'; }; fh_cadence_due() { return 0; }
fi
_FH_HOOK_SRC="$(fh_hook_source)"
set -uo pipefail

FH="${HUB_DIR:-${CLAUDE_PROJECT_DIR:-$HOME/projects/forge-harness}}"
BE="${BE_DIR:-}"   # companion-store path — supplied by the gitignored hook registration; no public default.
                   # Resolved HERE (not at the Mode-D block below) because the frontier-digest check
                   # needs it: on a multi-node setup the digest producer may be a DIFFERENT machine.

# TM = this hub's tracks-meta namespace under $BE (pmh-dev#68 PR #368 review): this reader used to
# hardcode "tracks-meta" unconditionally, so a sibling hub reading it after sync-to-be.sh's
# namespace fix would load FH's own session card/freshness data as if it were its own. Resolution
# is shared with sync-to-be.sh/sync-from-be.sh via fh_hub_identity.sh. This hook's own contract is
# "never block the first turn" (see header), so an unresolved identity degrades to the historical
# unsuffixed "tracks-meta" rather than erroring — that is the pre-fix behavior, not a new failure
# mode, and it only matters for a hub this file cannot even identify in the first place.
if [ -n "$BE" ]; then
  _FH_IDLIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fh_hub_identity.sh"
  # shellcheck source=scripts/fh_hub_identity.sh
  [ -f "$_FH_IDLIB" ] && . "$_FH_IDLIB" && fh_resolve_hub_identity 2>/dev/null
fi
TM="${TM:-tracks-meta}"

# ── node re-entry floor check ────────────────────────────────────────────────
# 이 검사는 scripts/fh_node_check.sh 로 분리했다. 이유: 이 파일(fh_session_load.sh)은 gitignored
# settings.local.json 에 등록되므로 새 클론/새 기계에선 애초에 안 돈다 — 검사가 존재 이유가 되는
# 상황에서 도달 불가였다(Sonnet 타깃-티어 심 2026-07-30 지적).
# ⚠️ 분리해도 자동 배선은 아니다: .claude/settings.json 도 gitignored 라(.gitignore:3-4) 등록 자체는
# 추적될 수 없다. 추적되는 건 templates/settings.SessionStart.snippet.json 이고, 배선은 위자드가 한다.
# 여기서 다시 호출하지 않는다: 두 곳에서 부르면 같은 이벤트를 두 번 찍는다.

# ── §early-refresh: 컴패니언 refresh 를 frontier 판정보다 먼저 한다 ─────────────
# 왜 순서가 문제인가: frontier 판정은 러너가 아닌 노드에서 $BE/tracks-meta 를 본다. refresh 가
# 그 뒤에 있으면 **그날의 첫 세션**은 아직 안 끌어온 워킹트리를 읽어 오늘 digest 를 못 보고,
# 이 수정이 없애려던 바로 그 오경보를 그대로 낸다(하루 한 번, 가장 값진 시점에서 실패).
# cross-family 리뷰 2026-07-30 [HIGH] 지적. 비-Mode-D(공개) 사용자는 BE 가 비어 통째로 건너뛴다.
PULL_NOTE="(no companion store configured)"
if [ -d "$BE/.git" ]; then
  export GIT_TERMINAL_PROMPT=0
  export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new}"

  # Hard wall-clock deadline on the ONLY network step. ConnectTimeout bounds the handshake, but a
  # slow/stalled TRANSFER after connect has no bound — measured 2026-07-12: SessionStart worst-case
  # 17.5s with 2 hook-timeout kills, all attributable to the fetch. perl-alarm is the portable
  # watchdog (macOS ships no coreutils `timeout`); on overrun the fetch dies and the offline branch
  # reports honestly. FH_FETCH_DEADLINE overrides (seconds). If perl is absent the wrapper degrades
  # to running the command with NO deadline — a missing watchdog must never become a permanently
  # skipped fetch misreported as "offline" (challenger catch 2026-07-12).
  if command -v perl >/dev/null 2>&1; then
    _deadline() { perl -e 'alarm shift @ARGV; exec @ARGV' "$@"; }
  else
    _deadline() { shift; "$@"; }
  fi
  PULL_NOTE=""
  if _deadline "${FH_FETCH_DEADLINE:-8}" git -C "$BE" fetch --quiet >/dev/null 2>&1; then
    if git -C "$BE" merge --ff-only --quiet >/dev/null 2>&1; then
      PULL_NOTE="fetched + fast-forwarded"
    else
      PULL_NOTE="fetched but NOT fast-forward (companion diverged — read local + newest remote)"
    fi
  else
    PULL_NOTE="fetch skipped (offline or deadline hit — read local state)"
  fi
fi

# ── frontier-digest: 부재를 0으로 읽지 않는다 ────────────────────────────────────
# 왜: digest 는 launchd 로 매일 09:00 에 돌지만 **31회 중 6회(19%) 산출물 없이 끝났다**
# (2026-07-21 실측: exit 1 / 재시도 후에도 없음 / Attempt 에서 hang — 세 형태).
# 그런데 세션 시작은 "있으면 읽는다"만 했다 → **실패가 '오늘은 뉴스 없음'으로 읽혔다.**
# 부재와 실패는 0이 아니다. 로그가 있는데 산출물이 없으면 그건 부재가 아니라 FAILED 다.
# Portable mtime (epoch). GNU-first: on GNU/coreutils `stat -f %m` exits 0 with filesystem-format
# output (never reaching a BSD fallback), so probe `stat -c %Y` FIRST — on BSD/macOS it errors and
# falls through to `-f %m`. Always echoes a numeric value (0 on total failure) so `-gt` never breaks.
# (codex cross-family review 2026-07-05 [MED]: BSD-first order silently mis-parsed on GNU.)
_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

_FD_LOG="$FH/tracks/_meta/logs/frontier_digest_$(date +%Y_%m_%d).log"
_FD_LOCK="$FH/tracks/_meta/logs/.frontier_digest.lock"
# 스케줄 전 부재 ≠ 실패: 잡은 launchd 로 09:00 에 돈다(com.forge-harness.frontier-digest.plist).
# 2026-07-23 08:07 세션이 "잡이 안 돌았을 수 있다" 경고를 받았고 잡은 09:00 에 정상 완주 —
# 경고가 나중에 읽히면 오보처럼 보인다. 그래서 ① 스케줄 전엔 경고하지 않고 ② 모든 분기에
# 발화 시각을 스탬프하고 ③ 러너 생존 신호(로그 갱신 or 락)가 있는 동안은 실패 판정을 보류한다.
_FD_SCHED=900                              # 09:00, HHMM 를 10진 정수로
_FD_NOW="${FD_NOW_HHMM:-$(date +%H%M)}"    # FD_NOW_HHMM = known-pair 캘리브레이션 전용(숫자 4자리만)
_FD_STAMP="$(date +%H:%M) 기준"
# 존재 판정은 러너 digest_ready 와 동일 술어(glob + -size +1k). 정확명 [ -f ] 는 러너와 관대함이
# 갈린다 — partial 파일(>0 <1k)이 성공으로 오독되고, suffix 착지가 영구 오경보가 된다
# (divergent-leniency: 같은 상태를 두 술어가 다르게 읽으면 한쪽 결과가 무음으로 샌다).
_fd_hit() { find "$1" -maxdepth 1 -name "frontier_digest_$(date +%Y_%m_%d)*.md" -size +1k 2>/dev/null | grep -q .; }
# 노드-로컬만 보면 **다른 머신이 만든 산출물이 구조적으로 안 보인다**. 멀티머신에선 러너가 한 대이고
# 나머지 노드는 컴패니언 스토어로만 그 산출물을 받는다 → 러너 아닌 노드가 매일 "실패다" 오경보를 낸다.
# (2026-07-30 실측: 프로가 07-24~30 매일 정상 생산 중인데 에어는 7일 연속 FAILED 를 띄웠다.
# 계기의 스코프가 대상보다 좁았던 케이스 — 대상은 '오늘 digest 가 있나'지 '이 디스크에 있나'가 아니다.)
# 술어는 로컬과 **동일**(glob + -size +1k) — divergent-leniency 를 만들지 않는다.
_fd_ready() { _fd_hit "$FH/tracks/_meta" || { [ -n "$BE" ] && _fd_hit "$BE/$TM"; }; }
# THE SECOND HALF OF THE SAME SCOPE BUG (2026-07-31). The comment above got the principle right —
# "대상은 '오늘 digest 가 있나'지 '이 디스크에 있나'가 아니다" — and then widened the predicate by
# exactly ONE surface (the companion store), leaving it file-only. There are TWO live producers:
# the launchd file runner AND an app routine that posts the digest as a comment on GitHub issue
# #102 (measured 2026-07-31: 47 comments, one per day, including today's at 09:09 KST). So on a day
# when the file runner fails, today's digest EXISTS and the hook said "부재가 아니라 실패다" — a
# true statement about this disk stated as a claim about the digest.
# The fix is NOT to call the network from a SessionStart hook (it must never block turn 0 and must
# never fail on an offline node). It is to stop over-claiming: report the scope actually measured
# ("this node's file output failed") and NAME the surface not measured, so the reader checks it in
# one step instead of re-running a job whose output already exists elsewhere.
_fd_issue_note() {
  echo "    ⓘ 파일만 본 판정이다 — 오늘치는 **GH issue #102**(앱 routine, 매일 ~09:09 KST)에 이미 있을 수 있다."
  echo "      확인: gh issue view 102 --repo chrono-meta/forge-harness --comments | tail -40"
  echo "      → 파일 재생성이 필요한지는 그걸 보고 판단하라. '오늘은 뉴스 없음'으로 읽지 말 것."
}
if _fd_ready; then
  # 로컬엔 없고 컴패니언에만 있으면 = 이 노드는 러너가 아니다. 침묵하면 토폴로지가 안 보이므로 한 줄 알린다.
  if ! _fd_hit "$FH/tracks/_meta"; then
    echo "ℹ️  [frontier-digest] 오늘 digest 는 **다른 노드**가 생산했다(컴패니언 스토어 경유) — 이 노드는 러너가 아니다."
    echo "    읽을 것: \$BE_DIR/tracks-meta/frontier_digest_$(date +%Y_%m_%d)*.md"
  fi
elif [ "$((10#$_FD_NOW))" -lt "$_FD_SCHED" ]; then
  echo "ℹ️  [frontier-digest] 오늘 digest 는 09:00 예정 — 아직 전이다($_FD_STAMP). 부재는 정상."
elif [ -f "$_FD_LOG" ]; then
  _FD_LOG_AGE=$(( $(date +%s) - $(_mtime "$_FD_LOG") ))
  # 러너 생존 신호 2종 — 어느 쪽이든 있으면 FAILED 대신 보류:
  #   ① 로그 최근 갱신(임계 2100s > 러너 최장 침묵창 = watchdog 1800s)
  #   ② 락 존재이면서 비-stale — stale 임계는 러너 자신의 락-브레이크 술어(-mmin +240)와 동일.
  #      락은 슬립-복귀 직후(로그는 오래됐지만 러너가 살아 재개하는 케이스)를 커버한다.
  _FD_ALIVE=""
  if [ -d "$_FD_LOCK" ] && [ -z "$(find "$_FD_LOCK" -maxdepth 0 -mmin +240 2>/dev/null)" ]; then
    _FD_ALIVE="락 존재"
  fi
  [ "$_FD_LOG_AGE" -lt 2100 ] && _FD_ALIVE="${_FD_ALIVE:+$_FD_ALIVE · }로그 ${_FD_LOG_AGE}s 전 갱신"
  if [ -n "$_FD_ALIVE" ]; then
    echo "ℹ️  [frontier-digest] 잡이 아직 돌고 있는 중일 수 있다($_FD_STAMP, $_FD_ALIVE) — 실패 판정 보류, 나중에 재확인."
  else
    echo "⚠️  [frontier-digest] **이 노드의 파일 산출**이 실패했다($_FD_STAMP) — 부재가 아니라 실패다."
    echo "    마지막 로그: $(tail -1 "$_FD_LOG" 2>/dev/null | cut -c1-90)"
    _fd_issue_note
  fi
else
  echo "⚠️  [frontier-digest] 스케줄(09:00) 지났는데 로그도 파일 산출물도 없다($_FD_STAMP) — 이 노드에서 잡이 아예 안 돌았을 수 있다(launchd 확인)."
  _fd_issue_note
fi
# (BE is resolved at the top of this script — the frontier-digest block above needs it too.)

# 1-b) Weekly-audit cadence — mechanical, for the same reason the frontier-digest block above is.
# MEASURED 2026-07-31: operations.md §Session start auto-detection (L1) promises "propose the audit
# if 7+ days elapsed", and the audit had not run for FIFTY days. The frontier-digest cadence, which
# is instrumented, never went a day unnoticed over the same window. The difference is not
# importance; it is that one cadence is a hook and the other is prose, and this repo's own N=3
# escalation rule says to instrument rather than to add a habit. One line in a hook that already
# runs, not a new mechanism. Advisory by design: an overdue audit is not an irreversible surface,
# so it surfaces and never blocks. Silent when current, and silent when the dir does not exist
# (a fresh clone has no audit history and must not be nagged about one).
_AUDIT_DIR="$FH/tracks/_audit"
# ── /clear 게이팅: 이 나그는 «사람이 이미 보고 결정한» 것이라 같은 세션에서 다시 띄우지 않는다.
#    위의 companion freshness 는 반대로 게이팅하지 않는다 — 그건 «세션이 잃어버린 상태» 라
#    /clear 직후에 오히려 필요하다. 기준은 그 둘의 구분이지 "시작이냐" 가 아니다.
if [ -d "$_AUDIT_DIR" ] && fh_cadence_due "$_FH_HOOK_SRC"; then
  _LATEST_AUDIT="$(find "$_AUDIT_DIR" -maxdepth 1 -name 'weekly_audit_*.md' -print 2>/dev/null \
                   | sort | tail -1)"
  if [ -n "$_LATEST_AUDIT" ]; then
    _AUDIT_AGE_D=$(( ( $(date +%s) - $(_mtime "$_LATEST_AUDIT") ) / 86400 ))
    if [ "$_AUDIT_AGE_D" -ge 7 ]; then
      echo "🗓️  [weekly-audit] 마지막 감사가 ${_AUDIT_AGE_D}일 전이다($(basename "$_LATEST_AUDIT")) — 캐던스는 7일."
      echo "    → /harvest-loop (lightweight) 또는 operations.md §Weekly Improvement Cycle 수동 절차."
    fi
  fi
fi

# 1-c) harness-doctor cadence — 위 1-b 와 같은 이유로, 같은 훅에서, 한 블록 더.
# MEASURED 2026-08-16 (weekly_audit_2026-08-16.md 🟥-3): 직전 감사(07-31)가 «산문 캐던스 미이행»을
# N=2 로 집계하면서 **주간감사(50일)와 harness-doctor(당시 ~49일) 둘을 함께** 지목했다. 그 뒤 16일
# 동안 주간감사는 50→16일로 움직였고 — 그건 1-b 가 기계화돼 있기 때문이다 — harness-doctor 는
# **한 번도 돌지 않아 65일**이 됐다(캐던스 30). 즉 같은 세션이 같은 날 같은 문서에서 지목한 두
# 캐던스가, 하나는 훅이고 하나는 산문이라는 차이만으로 정반대로 갔다. 그것이 N=3 이고,
# `operations.md §Recurrence escalation` 은 그때 «새 습관 규칙이 아니라 계기»를 만들라고 한다.
# 1-b 와 동일하게 **advisory** 다: 밀린 진단은 비가역 표면이 아니므로 표면화하고 절대 막지 않는다.
#
# 🟥 not-found ≠ 0 — 이 블록이 1-b 와 다른 유일한 지점이다. 1-b 는 파일이 없으면 조용하고, 그건
# 갓 클론한 설치를 나그하지 않기 위해 옳다. 그러나 harness-doctor 는 **한 번도 안 돌린 상태가
# 실재하는 결함**이고(이 레포가 2026-06-12 이후 정확히 그 상태였다), 파일 부재를 침묵으로 렌더하면
# 「없음」과 「0일 경과」가 같은 출력이 된다 — 이 레포가 반복해 배운 그 클래스다. 그래서 부재를
# **다른 문장으로** 말하되, «이미 굴러가는 설치인가»를 `fh_completed_*.md` 존재로 판별해 갓
# 클론한 설치에는 여전히 침묵한다. 그 판별은 1-b 의 audit-dir 존재 검사와 같은 역할이다.
#
# 🟥 스코프와 정렬, 둘 다 위 1-b 를 그대로 베끼면 틀린다 — 적대검증 2026-08-16 이 둘 다 잡았다.
#
# (1) **노드-로컬만 보면 안 된다.** `tracks/` 는 gitignored 라 노드 간에 안 따라오고, 진단은
#     `sync-to-be.sh` 로 `$BE/$TM` 에 실린다. 프로에서 돌리고 에어에서 세션을 열면 에어엔
#     `fh_completed_*.md` 는 있고 진단 리포트만 없어서 **「기록 0건」이라는 거짓 단언**이 난다.
#     그리고 이건 1-b 보다 나쁘다: 1-b 는 부재를 침묵으로 렌더해 «틀린 말을 안 하는» 쪽으로
#     degrade 하는데, 이 블록은 부재를 **큰 소리 단언으로 승격**시켰기 때문이다. 스코프가 틀린
#     채로 소리를 키우면 오보 비용도 같이 커진다. 바로 위 `_fd_ready()`(:129)가 이미 같은 버그를
#     한 번 겪고 합집합으로 고쳤다 — **같은 형태를 쓴다**(divergent-leniency 금지).
#
# (2) **`sort | tail -1` 은 사전순이지 시간순이 아니다.** 1-b 의 글롭 `weekly_audit_*.md` 는
#     접두어가 고정이라 사전순≈시간순이지만, 여기 글롭은 `*harness_doctor*.md` 로 **양쪽
#     와일드카드**다. `reference_harness_doctor_notes.md` 가 `harness_doctor_2026-08-16.md` 를
#     사전순으로 이기고, 그 파일의 mtime 이 나이가 된다 → 거짓 나그 또는 거짓 침묵. **mtime
#     최대값으로 뽑는다.** (`ls -t` 는 이식성 때문에 안 쓴다 — 이 커밋이 짓는 린트의 P-클래스다.)
_hd_latest() {  # stdout: 가장 최근 리포트의 mtime (없으면 빈 문자열)
  _best=""; _bestm=0
  for _d in "$FH/tracks/_meta" ${BE:+"$BE/$TM"}; do
    [ -d "$_d" ] || continue
    while IFS= read -r _f; do
      [ -n "$_f" ] || continue
      _m=$(_mtime "$_f")
      [ "$_m" -gt "$_bestm" ] && { _bestm="$_m"; _best="$_f"; }
    done < <(find "$_d" -maxdepth 1 -name '*harness_doctor*.md' -print 2>/dev/null)
  done
  [ -n "$_best" ] && printf '%s\t%s\n' "$_bestm" "$_best"
}
_hd_has_history() {  # «굴러가는 설치인가» — 이것도 합집합으로 본다
  for _d in "$FH/tracks/_meta" ${BE:+"$BE/$TM"}; do
    [ -d "$_d" ] || continue
    find "$_d" -maxdepth 1 -name 'fh_completed_*.md' -print 2>/dev/null | grep -q . && return 0
  done
  return 1
}
_HD_DIR="$FH/tracks/_meta"
if [ -d "$_HD_DIR" ] && fh_cadence_due "$_FH_HOOK_SRC"; then
  _HD_ROW="$(_hd_latest)"
  _LATEST_HD="${_HD_ROW#*	}"; _HD_MTIME="${_HD_ROW%%	*}"
  if [ -n "$_HD_ROW" ]; then
    _HD_AGE_D=$(( ( $(date +%s) - _HD_MTIME ) / 86400 ))
    if [ "$_HD_AGE_D" -ge 30 ]; then
      echo "🩺 [harness-doctor] 마지막 구조 진단이 ${_HD_AGE_D}일 전이다($(basename "$_LATEST_HD")) — 캐던스는 30일."
      echo "    → /harness-doctor (구조·드리프트·끊긴 참조). --lint 는 언어 패턴까지."
    fi
  # `-print | grep -q` 이지 `-quit` 이 아니다: `-quit` 은 GNU/BSD 양쪽에 있으나 버전 편차가 있고,
  # 이 파일이 고치는 결함군에 BSD/GNU 이식성이 들어 있다(감사 🟧-3). 최적화 한 톨을 위해 그 클래스를
  # 새로 들이지 않는다 — 여기 모집단은 디렉터리 하나이므로 얻을 것도 없다.
  elif _hd_has_history; then
    # 세션 이력은 있는데 진단 기록이 0건 = «한 번도 안 돌렸다». 부재를 0 으로 읽지 않는다.
    echo "🩺 [harness-doctor] 구조 진단 기록이 **0건**이다 — 캐던스 30일이 한 번도 발화한 적 없다."
    echo "    → /harness-doctor (첫 베이스라인). 부재는 «최신»이 아니다."
  fi
fi

# ── branch-claim 자동 기록 (2026-08-09) ────────────────────────────────────────
# WHY HERE, ABOVE THE COMPANION-STORE EARLY EXIT: 공유 체크아웃 사고는 Mode D 와 무관하다.
# companion store 가 없는 설치에서도 병렬 세션은 돌고, 그때도 `.git/HEAD` 는 트리당 하나다.
# 아래 `[ -d "$BE/.git" ] || exit 0` 뒤에 두면 **공개 사용자에게는 게이트가 통째로 죽는다.**
#
# WHY AUTO AT ALL: 게이트(templates/.git-hooks/pre-commit → scripts/branch_claim.sh)는
# **기록이 없으면 «의견 없음»으로 통과**한다. 아무도 `claim` 을 안 하면 장식이 된다 —
# 오늘 하루 반복해서 본 «만들고 배선 안 함» 의 얼굴. 세션 시작이 유일한 자연스러운 배선점이다.
#
# WHY IT IS SAFE (마찰 0):
#   · **없을 때만 기록한다** — 이미 있으면 손대지 않는다. 남의 기록은 애초에 파일이 다르다
#     (`.git/fh-claims/<session_id>`), 그래서 steal 이 구조적으로 불가능하다
#   · **1인 세션은 차단을 안 만난다** — check 는 «살아있는 peer claim 0» 이면 경고만 낸다
#   · detached/rebase/bisect 중이면 `claim` 이 스스로 거부한다(rc=2) → 무해
#   · 실패해도 세션을 막지 않는다(|| true · 출력 억제)
[ -x "$FH/scripts/branch_claim.sh" ] && {
  ( cd "$FH" && bash scripts/branch_claim.sh claim --if-absent session >/dev/null 2>&1 ) || true
  ( cd "$FH" && bash scripts/branch_claim.sh reap                     >/dev/null 2>&1 ) || true
}

# ── 매핑된 프로젝트의 capability 표면화 (2026-08-18) ───────────────────────────
# WHY HERE (branch-claim 과 같은 자리, early exit **위**): 이건 Mode D 전용이 아니다.
# companion store 가 없는 설치에서도 프로젝트는 매핑되고, 그때도 형제 하네스의 스킬은
# 안 보인다. 아래 early exit 밑에 두면 그 설치에서 통째로 죽는다 — 바로 위 branch-claim
# 블록이 같은 이유로 여기 있다.
# ⚠️ **정밀화(cross-family 적발)**: `tracks/` 는 npm 산출물에 **안 들어간다**(per-install 데이터).
#    그러니 «갓 설치한» 소비자에게는 이 블록이 아무것도 안 찍는다 — 값은 그 사람이 프로젝트를
#    **매핑한 뒤부터** 생긴다. 「공개 사용자에게도 산다」는 그런 뜻이지 «설치 즉시 값이 있다» 가
#    아니다. (실측: 팩 산출물에 tracks 없음 → 침묵 · tracks/someproject 생성 후 → 발화)
#
# WHY AT ALL: `CLAUDE.md §Cross-Project Skill Bus` 는 registry 를 **온보딩 Step 1-c** 에서
# 읽는데, §Active Onboarding 의 Guards 가 «explicit task-entry → skip onboarding menu» 다.
# 첫 발화가 task 면 메뉴와 함께 **데이터 로드까지 같이 꺼진다.** 메뉴는 UI 고 registry 는
# 데이터인데 한 단계에 묶여 있어서 UI 를 끄면 데이터도 꺼진다.
#   → Mode D companion-store 로드는 이 병을 이미 한 번 고쳤다(«이건 메뉴가 아니라 데이터
#     로드다» carve-out + 이 스크립트). **registry 엔 그 처방이 안 붙었다** = 반쪽-픽스
#     전파경계.
# 실측(2026-08-18): `tracks/gstack` 이 매핑돼 있고 SKILL.md 가 55개인데, 운영자가 이름을
# 댈 때까지 세션이 그 존재를 몰랐다. CATALOG·CLAUDE.md·sim-conductor 에 전부 등록돼 있었다.
#
# 비용 경계: 이름과 개수만. 목록 전량 로드는 안 한다(토큰). 실물이 없거나 스킬이 0인 트랙은
# 아예 안 찍는다 — 매 세션 13줄이 뜨면 그건 배경 소음이고 아무도 안 읽는다.
# 🟥 0 을 «없다» 로 렌더하지 않는다: 프로젝트 루트를 못 찾으면 그렇게 적고, 개수를 0 으로
#    적지 않는다(부재 ≠ 0).
_PROJ_ROOT="${FH_PROJECTS_ROOT:-$(dirname "$FH")}"
# ── track→repo 해석: 단일 소스 = scripts/fh_track_resolve.sh ──────────────────
# 🟥 강등 블록은 세 소비자(fh_session_load · field_canon_preload · cluster_capability_scan)에
#    **문자 그대로 동일**해야 한다. 2026-08-21 적대검증 HIGH-2: 초판은 파일마다 별칭을
#    1종/2종/3종으로 다르게 봤고, 그건 «강등 경로가 F-1 결함(갈라진 정규화기)의 완전한
#    복제본» 이라는 뜻이었다. 이제 강등은 **별칭 0종 + 큰 소리**다 — 덜 유용하지만
#    세 파일이 같은 답을 내고, 무엇보다 **조용하지 않다**. skipped 를 passed 로 렌더하지
#    않는다는 이 저장소 규율 그대로다. [[feedback_not_found_is_not_zero_family]]
_FH_TRLIB="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/fh_track_resolve.sh"
# shellcheck source=scripts/fh_track_resolve.sh
[ -f "$_FH_TRLIB" ] && . "$_FH_TRLIB"
# 🟥 `type` 는 **존재**만 재고 **정합**은 못 잰다(잘린 파일·구버전·환경에서 export -f 된 동명
#    함수는 전부 통과한다 — 적대검증 LOW-3). 그래서 라이브러리가 API 버전을 선언하고
#    소비자가 그걸 확인한다. 채널을 타입으로 만드는 것이지 성실성에 기대는 게 아니다.
if ! type fh_resolve_track_root >/dev/null 2>&1 || [ "${FH_TRACK_RESOLVE_API:-}" != "1" ]; then
  printf '⚠️  [track-resolve] DEGRADED — fh_track_resolve.sh 부재 또는 API 불일치. 별칭 해석 없음(밑줄→하이픈·-dev 접미 미적용). 이건 «해당 없음»이 아니라 **미해석**이다.\n'
  fh_resolve_track_root() {
    case "${1-}" in '' |*/*|*'|'*|*'..'* ) printf '|ARGS:bad-name'; return 3 ;; esac
    [ -n "${2-}" ] || { printf '|ARGS:empty-root'; return 3; }
    case "${3:-dir}" in
      git) [ -d "$2/$1/.git" ] && { printf '%s|' "$2/$1"; return 0; } ;;
      dir) [ -d "$2/$1" ]      && { printf '%s|' "$2/$1"; return 0; } ;;
      *)   printf '|ARGS:bad-pred'; return 3 ;;
    esac
    printf '%s|UNRESOLVED' "$2/$1"
    return 1
  }
fi
if [ -d "$FH/tracks" ]; then
  _reg=""; _mapped=0; _resolved=0; _ambig=0
  for _t in "$FH"/tracks/*/; do
    _n=$(basename "$_t")
    case "$_n" in _*) continue ;; esac
    [ "$_n" = "*" ] && continue
    _mapped=$((_mapped + 1))
    _rr=$(fh_resolve_track_root "$_n" "$_PROJ_ROOT" dir)
    _d="${_rr%|*}"; _note="${_rr##*|}"
    # 🟥 모호는 «못 찾음» 이 아니다 — 여럿이 맞은 것이다. 조용히 하나를 고르지 않고 따로 센다.
    case "$_note" in
      AMBIGUOUS:*) _ambig=$((_ambig + 1)); continue ;;
      UNRESOLVED)  continue ;;
      # 🟥 ARGS = 전제 파손(빈 이름·경로 탈출·알 수 없는 술어)이지 «못 찾음» 이 아니다.
      #    미해소로 접으면 그것도 미측정을 0 으로 렌더하는 형태다 — 따로 말한다.
      ARGS:*)      printf '%s' "⚠️  [track-resolve] 트랙 이름 «$_n» 이 거부됐다(${_note#ARGS:}) — 이건 «레포 없음» 이 아니라 **전제 파손**이다.
"; continue ;;
    esac
    _resolved=$((_resolved + 1))
    # 무거운 디렉터리를 쳐낸다 — 비용 주장이 «내 머신의 내 프로젝트 집합» 위에 서 있으면
      # 안 된다(cross-family 지적). node_modules/.venv/.git 이 depth 3 안에 있으면 선형으로 는다.
      _sk=$(find "$_d" -maxdepth 3 \( -name node_modules -o -name .git -o -name .venv \
              -o -name venv -o -name target -o -name dist \) -prune -o \
              -name SKILL.md -print 2>/dev/null | wc -l | tr -d ' ')
    [ "${_sk:-0}" -gt 0 ] || continue
    _reg="${_reg}  ▸ ${_n} — SKILL.md ${_sk}개  (${_d})
"
  done
  # 🟥 **부재 ≠ 0.** 판별자는 «루트 디렉터리가 있나»가 아니다 — `dirname "$FH"` 는 거의 항상
  #    존재해서 그 분기는 발화 불가한 장식이었다(초판 결함, 같은 커밋에서 자력 적발).
  #    실질 판별자는 **매핑된 트랙이 있는데 하나도 실물로 해소되지 않았다** 이고, 그때만
  #    「못 쟀다」를 말한다. 소비자의 레포가 다른 경로에 있으면 정확히 이 상태가 된다.
  # 🟥 **all-or-nothing 이면 안 된다** (cross-family 적발, 초판 결함): «전부 못 찾았을 때만»
  #    말하면 13개 중 1개만 해소되고 12개가 없을 때 그 12개가 **완전히 침묵**한다 — 이 블록이
  #    없애려는 «부재를 0으로 렌더» 를 블록 자신이 재현한다. 미해소가 하나라도 있으면 말한다.
  _unres=$((_mapped - _resolved - _ambig))
  if [ "$_ambig" -gt 0 ]; then
    _reg="${_reg}  ⚠️ 트랙 ${_ambig}개는 «${_PROJ_ROOT}» 밑에서 **레포 여럿이 동시에 맞았다** — 고르지 않았다. 매핑을 정리해야 한다.
"
  fi
  if [ "$_unres" -gt 0 ]; then
    _reg="${_reg}  ⚠️ 매핑된 트랙 ${_mapped}개 중 ${_unres}개는 «${_PROJ_ROOT}» 밑에서 실물을 못 찾았다 — 그 ${_unres}개는 «0» 이 아니라 **미측정**이다 (경로가 다르면 FH_PROJECTS_ROOT).
"
  fi
  if [ -n "$_reg" ]; then
    # 🟥 판별자는 `_resolved` 가 아니라 **▸ 행이 실제로 있는가** 다 (적대검증 MED-2).
    #    `_resolved` 는 SKILL.md 를 세기 **전에** 증가하고, `_sk == 0` 이면 ▸ 행이 안 들어간다.
    #    그래서 해소된 트랙이 전부 SKILL.md 0개면 «있다» 배너가 **▸ 행 0개 위에** 붙는다 —
    #    바로 아래 주석이 금지한 그 형태다. 이 수리는 별칭 해소를 늘리므로 그 도달성을 높인다.
    case "$_reg" in
      *"▸"*) _FH_HAS_ROWS=1 ;;
      *)     _FH_HAS_ROWS=0 ;;
    esac
    if [ "$_FH_HAS_ROWS" -eq 1 ]; then
      echo "🧩 [cross-project skill bus] 매핑된 프로젝트에 SKILL.md 가 있다 — 파일 개수만 센 것이지 «지금 세션에서 호출 가능하다» 는 확인이 아니다."
      printf "%s" "$_reg"
      # 목록이 실제로 있을 때만 낸다. 강등(못 찾음) 케이스에 이 안내가 붙으면 «읽을 것이 있다» 는
      # 인상을 주는데 목록은 비어 있다 — 없는 것을 있다고 말하는 쪽이다.
      echo "   ⚠️ 이 줄은 «있다» 만 말한다. 쓰기 전에 그쪽 SKILL.md 를 읽어라 — 필드 하네스 용어를"
      echo "      일반 개념으로 정규화하는 것이 이 레포의 상습 실패다."
    else
      echo "🧩 [cross-project skill bus] 매핑은 있는데 실물을 못 찾았다 — 아래는 **미측정**이다."
      printf "%s" "$_reg"
    fi
  fi
fi

# Non-Mode-D / no companion store → silent no-op (this is the majority path for public users).
[ -d "$BE/.git" ] || exit 0

# (_mtime is defined above the frontier-digest block — single definition, both sections use it.)

# 1) Refresh the companion store — fail-fast, never block the first turn, never mutate into a
#    merge/conflict. (codex cross-family review 2026-07-05 [HIGH]/[MED].)
#    - fail-fast env: no credential/SSH/host-key prompts can hang SessionStart.
#    - fetch + merge --ff-only: a fast-forward is the only safe hook mutation; a diverged companion
#      simply does not advance (no merge commit, no conflict state left behind) and we say so.
# (컴패니언 refresh 는 위 §early-refresh 로 올렸다 — frontier 판정이 최신 트리를 보게 하려고.)

# 2) Session card date (the pointer the operator's close chain writes last).
CARD="$FH/tracks/_meta/reference_next_session_starter.md"
CARD_EPOCH=0
[ -f "$CARD" ] && CARD_EPOCH="$(_mtime "$CARD")"

# 3) Companion files NEWER than the card, in the surfaces that carry landed results/handoffs.
#    (paper-signals = completed experiments; handoff = cross-session/cross-machine; tracks-meta
#    = synced session meta.) These are exactly what a stale card fails to point at.
# ★ "$TM" (not the literal "tracks-meta") — paper-signals/handoff/digests are FH-exclusive areas
# sync-to-be.sh never namespaces (it does not write them for any hub), only tracks-meta needs the
# suffix here (pmh-dev#68 PR #368 review).
NEWER=""
for sub in paper-signals handoff "$TM" digests; do
  d="$BE/$sub"
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    fe="$(_mtime "$f")"
    if [ "${fe:-0}" -gt "${CARD_EPOCH:-0}" ]; then
      NEWER="${NEWER}  - ${f#$BE/}\n"
    fi
  done <<EOF
$(find "$d" -type f -name '*.md' -maxdepth 2 2>/dev/null)
EOF
done

# 3b) Handoff/signal STATUS map — mtime-INDEPENDENT (patched 2026-07-10).
#     WHY: the NEWER-than-card list (step 3) has a permanent blind spot — a status stamp
#     (DONE/SUPERSEDED/RESOLVED) can land in the companion store, then the card gets rewritten
#     WITHOUT reconciling that item; from then on the stamped file is "older than the card"
#     forever and step 3 never surfaces it again. (Measured miss 2026-07-10: a Qwen heavy
#     handoff stamped DONE 07-09 stayed listed as "awaiting RUN" in the card through a later
#     card rewrite — company sessions push results to the companion store but never run the
#     local close chain, so the card's ⑤ update is the ONLY reconcile point and it was prose.)
#     FIX: emit ALL frontmatter status lines from handoff/ + paper-signals/ every session,
#     regardless of mtime, so the turn-0 agent can mechanically cross-check card carry items.
STATUS_MAP=""
for sub in handoff paper-signals; do
  d="$BE/$sub"
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    s="$(head -15 "$f" 2>/dev/null | grep -iE '^ *status:' | head -1 | sed 's/^ *//')"
    [ -n "$s" ] || continue
    # Match on the status VALUE's leading word only — a substring match anywhere in the line
    # false-positives on prose like "Remaining for DONE:" inside a PARTIAL status.
    v="$(printf '%s' "$s" | sed -E 's/^[Ss][Tt][Aa][Tt][Uu][Ss]: *//')"
    case "$v" in
      DONE*|SUPERSEDED*|RESOLVED*|CLOSED*) STATUS_MAP="${STATUS_MAP}  - ${f#$BE/} → ${s}\n" ;;
    esac
  done <<EOF
$(find "$d" -type f -name '*.md' -maxdepth 2 2>/dev/null)
EOF
done

# 4) INDEX.md live pointers (the operator's wiki TOC — read-first per CLAUDE.local.md).
# Deliberately UNSUFFIXED: this is a single shared companion-store index, not a per-hub write
# target — sync-to-be.sh never writes a $TM-namespaced copy of it, so there is nothing to namespace
# here either (unlike tracks-meta above, which pmh-dev#68 PR #368 review flagged for exactly this).
INDEX_HEAD=""
if [ -f "$BE/INDEX.md" ]; then
  INDEX_HEAD="$(grep -iE 'live pointer|Live pointers' -A 8 "$BE/INDEX.md" 2>/dev/null | head -10)"
fi

# 5) Emit the freshness block (short + imperative). Only speak if there is something to say.
{
  # 🟥 NODE NAME rides this line on purpose (2026-08-27, measured N=2). fh_node_check.sh computes
  # NODE_ID and prints it — but only when something is WRONG or on the once-per-node identity event
  # (its `[ -n "$MISS$...$IDENTITY$..." ] || exit 0` guard). That silence is the right call for a
  # nag; the cost is that in the STEADY state the session cannot see which machine it is on.
  # What that cost actually bought, same day: a session on the air node read three air-local
  # absences and nearly published them as global — a "sealed corpus lost" (it is intact on pro), an
  # M-tier "granted capability never fires" (all three files are on pro), and a 347-file hub/mirror
  # gap. Recurrence 2 (2026-07-31 was the same shape, same node, already in memory as
  # [[feedback_frontier_digest_auto_catch]]) — the rule was recorded and did not fire, because the
  # trigger is "I observed an absence" and what a session checks at that moment is whether its
  # INSTRUMENT is alive, not which NODE it is standing on. Those are different checks.
  # So: no new hook, no new line, no nag — the node name is appended to a banner that already
  # prints every single session. `hostname -s`, the same source fh_node_check.sh uses.
  echo "🔄 [FH SessionStart] companion-store freshness — $PULL_NOTE. · node: $(hostname -s 2>/dev/null || echo unknown)"
  if [ -n "$NEWER" ]; then
    echo "⚠️ NEWER THAN SESSION CARD — READ THESE BEFORE ACTING (card may be stale):"
    printf "%b" "$NEWER"
  else
    echo "   (no companion files newer than the session card)"
  fi
  if [ -n "$STATUS_MAP" ]; then
    echo "── handoff/signal STATUS map (mtime-independent — closed items) ──"
    printf "%b" "$STATUS_MAP"
    echo "→ CROSS-CHECK: any item above that the session card still lists as open/awaiting = stale card line. Fix it in this session's card update (⑤)."
  fi
  if [ -n "$INDEX_HEAD" ]; then
    echo "── INDEX.md live pointers ──"
    echo "$INDEX_HEAD"
  fi
  echo "Reminder: this is the Mode D auto-read (CLAUDE.local.md §Session-start companion load) —"
  echo "it fires even when the first user message is a task. Do not treat 'pulled' as 'read'."
} 2>/dev/null

# 6) Substrate-jump detection (structure-enforcing — version drift lives outside any session's
#    context boundary; silent when nothing changed). Detector, never a gate.
[ -x "$FH/scripts/substrate_jump_detector.sh" ] && bash "$FH/scripts/substrate_jump_detector.sh" "$FH" 2>/dev/null

exit 0
