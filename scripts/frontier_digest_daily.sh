#!/bin/bash
# frontier_digest_daily.sh — Daily frontier-digest runner for forge-harness
# Invoked by launchd (install: see scripts/com.forge-harness.frontier-digest.plist)
#
# Required: claude CLI at ~/.local/bin/claude
# Tool permissions: pre-approved in .claude/settings.json (no interactive prompts needed)

# Auto-detect repo root from this script's location (scripts/ → repo root) and the claude CLI.
FH_DIR="${FD_FH_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# FD_* env 오버라이드: 재현 하네스(test_frontier_digest_retry.sh)가 스텁/짧은 타임아웃을
# 주입하기 위한 것. 미설정 시 기본값 그대로 — 프로덕션 경로 무변.
CLAUDE_BIN="${FD_CLAUDE_BIN:-$(command -v claude || echo "${HOME}/.local/bin/claude")}"
TODAY=$(date +%Y_%m_%d)
HUMAN_DATE=$(date +%Y-%m-%d)   # pinned once with TODAY — a wake-fired run crossing midnight must not drift (filename date ≠ prompt date)
# ── 위성 축 (2026-08-18, 원정 2차) ──────────────────────────────────────────
# 정체성 ④ 「프런티어→조직 전파」의 조직 = **레포**다(운영자 정의). 이 러너는 FH 한 곳만
# 대상으로 지어졌고, 그래서 ④ 는 «자기 소비»에 머물렀다. 아래 두 변수가 대상 축이다.
#   FD_FH_DIR   — 어느 레포에서 도는가 (기존)
#   FD_OUT_DIR  — 그 레포의 **어디에** 떨어뜨리는가 (신설). FH 는 tracks/_meta 지만
#                 대상 하네스는 자기 문법이 있다(forge-wiki 는 frontmatter 달린 위키 노드).
#   FD_MODEL    — 어느 티어로 도는가 (신설). 위성마다 도메인 난이도가 다르다.
# 🟥 기본값은 **전부 종전 그대로**다 — FH 프로덕션 경로 무변경.
OUT_DIR="${FD_OUT_DIR:-tracks/_meta}"          # FH_DIR 기준 상대경로
LOG_DIR="${FH_DIR}/${OUT_DIR}/logs"
LOG_FILE="${LOG_DIR}/frontier_digest_${TODAY}.log"

mkdir -p "$LOG_DIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] frontier-digest daily run starting" >> "$LOG_FILE"

# Cap log accumulation (up to 3 attempts/day append full claude output into this dir)
find "$LOG_DIR" -name 'frontier_digest_*.log' -mtime +30 -delete 2>/dev/null

# Success = a non-trivial digest file exists. Mere existence is not enough: the dominant failure
# class is "connection closed mid-response", which can leave a partial/empty file — that must not
# count as done (it would also lock out every later run today via the skip-check below).
digest_ready() {
    find "${FH_DIR}/${OUT_DIR}" -maxdepth 1 -name "frontier_digest_${TODAY}*.md" -size +1k 2>/dev/null | grep -q .
}

# ── 공개표면 게이트 (2026-08-18, 원정 2차) ──────────────────────────────────
# 위성이 **공개 레포**를 대상으로 돌면 **매 런이 publish** 다(비가역 표면). FH 자신은
# tracks/ 가 gitignored 라 이 문제가 없었고, 그래서 이 러너에 게이트가 없었다.
# §Irreversibility Surface-Class Degrade Invariant: 비가역 표면은 **fail-CLOSED** —
# 스캐너가 못 재면 «통과»가 아니라 «보류»다.
#
# 🟥 **성공 종료 경로가 셋이라 함수로 뺐다.** 초판은 attempt 루프의 성공 분기에만 달았고,
# 그러면 ⓐ「오늘 이미 돌았다」조기 스킵과 ⓑ「외부에서 나타났다」로 나가는 digest 가
# **스캔 없이 게시**된다. 레인 P2·P3 이 그 fail-open 을 잡았다.
#
# 🟥 rc 3값을 두 값으로 접지 않는다 — 0 게시 / 1 격리 / 그 외 보류. 스캐너는 자기 죽음을
#    rc=3(NOT SCANNED)으로 신고하므로 그 값을 존중한다.
publish_gate() {
    [ "${FD_PUBLIC_TARGET:-0}" = "1" ] || return 0
    local lib="${FH_DIR}/scripts/psa_scan_lib.sh"
    [ -f "$lib" ] || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚫 publish gate: psa_scan_lib.sh 부재 — fail-closed" >> "$LOG_FILE"; return 3; }
    local f out rc
    f=$(find "${FH_DIR}/${OUT_DIR}" -maxdepth 1 -name "frontier_digest_${TODAY}*.md" 2>/dev/null | head -1)
    [ -n "$f" ] || return 0
    out=$(bash -c '. "$1"; psa_load "$2/.claude/rules/.public-surface-patterns.defaults" "$2/.claude/rules/.public-surface-patterns" >/dev/null 2>&1; psa_scan_file "$3"' _ "$lib" "$FH_DIR" "$f" 2>&1)
    rc=$?
    case "$rc" in
        0) echo "[$(date '+%Y-%m-%d %H:%M:%S')] publish gate: CLEAN" >> "$LOG_FILE"; return 0 ;;
        1) echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚫 publish gate: LEAK — 격리, 게시 안 함" >> "$LOG_FILE"
           printf '%s\n' "$out" >> "$LOG_FILE"; mv "$f" "${f}.QUARANTINE" 2>/dev/null; return 2 ;;
        *) echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚫 publish gate: NOT SCANNED (rc=$rc) — fail-closed, 게시 안 함" >> "$LOG_FILE"
           printf '%s\n' "$out" >> "$LOG_FILE"; mv "$f" "${f}.UNSCANNED" 2>/dev/null; return 3 ;;
    esac
}

# ── 착지 증언 (2026-08-18, 원정 2차 ⓑ) ────────────────────────────────────
# `digest_landing_check.sh` 는 10 레인을 갖고 selfcheck 루프가 그 self-test 를 돌리는데,
# **프로덕션 호출부가 0 이었다** — 「후보가 실제로 착지했나」를 아무도 재지 않았다. 그 스크립트
# 헤더 자신의 표현으로 *"닫히는데 증인이 없다"*. 파이프는 관통하는데 그 사실이 사람 기억으로만.
#
# 🟥 **오늘 것이 아니라 직전 다이제스트를 잰다.** 오늘 후보는 착지할 시간이 없었다 — 오늘 것을
#    재면 «전건 미착지»가 매일 나오고 그건 계기가 아니라 소음이다.
# 🟥 **차단하지 않는다. 게이트가 아니라 계측이다.** 헤더가 스스로 «선별기»라 적었고
#    (`file-change ≠ token-introduction` 잔여) 히트는 손으로 열어야 한다. 목적은 **착지율 시계열**
#    을 파일로 남기는 것 — 세션 시작 노티가 **네트워크 없이 그 파일만 읽게** 하려면 이게 먼저다
#    (peer: SessionStart 에 원격 호출은 지연·행 위험 · `--author @me` 는 계정 공유 시 오귀속).
landing_witness() {
    local checker="${FH_DIR}/scripts/digest_landing_check.sh"
    [ -x "$checker" ] || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] landing witness: checker 부재 — SKIPPED (not a pass)" >> "$LOG_FILE"; return 0; }
    local prev
    prev=$(find "${FH_DIR}/${OUT_DIR}" -maxdepth 1 -name 'frontier_digest_*.md' 2>/dev/null \
           | grep -v "frontier_digest_${TODAY}" | sort | tail -1)
    [ -n "$prev" ] || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] landing witness: 직전 digest 없음 — SKIPPED (not a pass)" >> "$LOG_FILE"; return 0; }
    local out rc
    out=$(bash "$checker" "$prev" "$FH_DIR" 2>&1); rc=$?
    case "$rc" in
        0)  echo "[$(date '+%Y-%m-%d %H:%M:%S')] landing witness [$(basename "$prev")]: ALL-LANDED (rc=0)" >> "$LOG_FILE" ;;
        1)  echo "[$(date '+%Y-%m-%d %H:%M:%S')] landing witness [$(basename "$prev")]: SOME-UNLANDED (rc=1) — 선별기다, 히트를 손으로 열어라" >> "$LOG_FILE" ;;
        10) echo "[$(date '+%Y-%m-%d %H:%M:%S')] landing witness [$(basename "$prev")]: HARNESS-ERROR (rc=10) — 못 쟀다, 미착지 0 이 아니다" >> "$LOG_FILE" ;;
        *)  echo "[$(date '+%Y-%m-%d %H:%M:%S')] landing witness [$(basename "$prev")]: UNEXPECTED rc=$rc — 못 쟀다" >> "$LOG_FILE" ;;
    esac
    printf '%s\n' "$out" | sed 's/^/    /' >> "$LOG_FILE"
    return 0   # 🟥 항상 0 — 계측이 러너의 종료 의미를 바꾸면 안 된다
}

# Skip if already ran today
if digest_ready; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Already ran today — skipping" >> "$LOG_FILE"
    publish_gate; _pg=$?; [ "$_pg" -eq 0 ] && landing_witness; exit "$_pg"
fi

# Single-instance lock (mkdir = atomic on bash 3.2). Guards launchd-vs-manual double dispatch:
# a manual run during the retry sleep would otherwise race a second claude onto the same file.
# Stale-lock steal after 4h (crash mid-run must not brick every future day).
LOCK_DIR="${LOG_DIR}/.frontier_digest.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    if [ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +240 2>/dev/null)" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stealing stale lock (>4h)" >> "$LOG_FILE"
        rmdir "$LOCK_DIR" 2>/dev/null
        mkdir "$LOCK_DIR" 2>/dev/null || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lock race lost — exiting" >> "$LOG_FILE"; exit 0; }
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Another run in progress — exiting" >> "$LOG_FILE"
        exit 0
    fi
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

cd "$FH_DIR"

# --permission-mode acceptEdits: headless runs have no human to approve the Write, so the digest
# Write to tracks/_meta/ was silently denied (claude still exits 0) — the runner fired daily but
# persisted nothing. acceptEdits auto-accepts the file Write only (not arbitrary tool calls), which
# is the minimal fix; read/fetch tools stay pre-approved via .claude/settings.json. (fixed 2026-06-19)
#
# Retry + watchdog (added 2026-07-18): 8 days between 05-31 and 07-17 lost their digest to transient
# API/network errors right after machine wake (connection closed / ConnectionRefused; one hang of
# 65 min before dying). 3 attempts, 10 min apart; each attempt runs under a 30-min watchdog so the
# hang variant also reaches the retry path — a foreground call would block the loop forever.
# [automated-run: launchd] in the prompt = run-provenance token (proposed by the 07-16 digest) so a
# digest can mechanically distinguish an automated run from a manual /frontier-digest invocation.
MAX_ATTEMPTS="${FD_MAX_ATTEMPTS:-3}"
ATTEMPT_TIMEOUT_SECS="${FD_ATTEMPT_TIMEOUT_SECS:-1800}"
RETRY_SLEEP_SECS="${FD_RETRY_SLEEP_SECS:-600}"
POLL_SECS="${FD_POLL_SECS:-30}"

# ── 판별 계측 (2026-07-23, 주간감사 🟧2) ─────────────────────────────────────
# 07-19 실측: attempt 1 이 56분 53초 돌았는데 30분 watchdog 미발화 + Attempt 2/3 미진행,
# 로그 4줄로 끝. 경쟁 가설 ⓐ 시스템 슬립(폴링 sleep 이 통째로 정지 → 프로세스도 같이 자다
# 깨어나 죽은 채 발견, 신호 없음) ⓑ launchd 잡 회수(backoff sleep 중 TERM). 로그만으로
# 판별 불가였다 — **신호 trap + 단계 로깅**이 그 판별 계기다:
#   · TERM/INT/HUP 수신 → 로그에 남김 → 다음 실발화가 ⓑ면 이 줄이 찍힌다
#   · 각 sleep 진입/복귀를 로그 → ⓐ면 진입-복귀 사이 벽시계 갭이 sleep 길이를 초과한다
# (재현 하네스는 로직 검증까지 — 환경 원인은 이 계측이 라이브에서 잡는다)
# trap 은 **로그 후 재발사** — trap-without-exit 는 신호를 삼켜 러너가 TERM 을 무시하고
# 최대 ~110분 더 돈다(challenger B-1 실측: TERM 2발 무시, Attempt 3 완주). 재발사 전에
# lock 을 직접 정리한다(재발사된 TERM 은 기본 핸들러라 EXIT trap 을 안 태울 수 있음).
trap 'echo "[$(date "+%Y-%m-%d %H:%M:%S")] SIGNAL: runner received TERM — launchd reclaim? (hypothesis-b evidence)" >> "$LOG_FILE"; rmdir "$LOCK_DIR" 2>/dev/null; trap - TERM; kill -TERM $$' TERM
trap 'echo "[$(date "+%Y-%m-%d %H:%M:%S")] SIGNAL: runner received INT/HUP" >> "$LOG_FILE"; rmdir "$LOCK_DIR" 2>/dev/null; trap - INT HUP; kill -INT $$' INT HUP

# 인터럽터블 sleep — foreground sleep 은 끝나야 trap 이 돌아 신호 수신이 sleep 잔여시간만큼
# 늦는다(challenger B-1: launchd 의 TERM→~20s→KILL 창에서 backoff 600s 기준 기록 확률 ~3%).
# `sleep & wait` 는 wait 가 builtin 이라 신호를 즉시 받는다 → trap 즉발.
_isleep() { sleep "$1" & wait $!; }
for ATTEMPT in $(seq 1 $MAX_ATTEMPTS); do
    # Re-check before spending an attempt (a manual run may have landed the digest during the sleep)
    if digest_ready; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Digest appeared externally before attempt ${ATTEMPT} — success" >> "$LOG_FILE"
        publish_gate; _pg=$?; [ "$_pg" -eq 0 ] && landing_witness; exit "$_pg"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt ${ATTEMPT}/${MAX_ATTEMPTS}" >> "$LOG_FILE"
    "$CLAUDE_BIN" -p --permission-mode acceptEdits \
        ${FD_MODEL:+--model "$FD_MODEL"} \
        "[automated-run: launchd] Run /frontier-digest for today (${HUMAN_DATE}). Fetch latest signals from HN, arXiv, and GitHub. Save the digest to ${OUT_DIR}/frontier_digest_${TODAY}.md." \
        >> "$LOG_FILE" 2>&1 &
    CLAUDE_PID=$!
    DEADLINE=$((SECONDS + ATTEMPT_TIMEOUT_SECS))
    while kill -0 "$CLAUDE_PID" 2>/dev/null && [ "$SECONDS" -lt "$DEADLINE" ]; do
        _isleep "$POLL_SECS"
    done
    if kill -0 "$CLAUDE_PID" 2>/dev/null; then
        # 자식까지 — 부모만 죽이면 claude 의 자식(MCP 서버 등)이 고아로 남는다
        # (challenger B-2 실측: 하네스 1회에 고아 sleep 3개). bash 3.2 호환 2단 kill.
        pkill -P "$CLAUDE_PID" 2>/dev/null
        kill "$CLAUDE_PID" 2>/dev/null
        wait "$CLAUDE_PID" 2>/dev/null
        EXIT_CODE=124
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt ${ATTEMPT} killed by watchdog (${ATTEMPT_TIMEOUT_SECS}s)" >> "$LOG_FILE"
    else
        wait "$CLAUDE_PID"
        EXIT_CODE=$?
    fi
    if digest_ready; then
        publish_gate; _pg=$?
        [ "$_pg" -eq 0 ] || exit "$_pg"
        landing_witness
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Digest file present after attempt ${ATTEMPT} (claude exit ${EXIT_CODE}) — success" >> "$LOG_FILE"
        exit 0
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] No digest file after attempt ${ATTEMPT} (claude exit ${EXIT_CODE})" >> "$LOG_FILE"
    if [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backoff: sleeping ${RETRY_SLEEP_SECS}s before attempt $((ATTEMPT+1)) (wake-gap > sleep length ⇒ hypothesis-a system-sleep evidence)" >> "$LOG_FILE"
        _isleep "$RETRY_SLEEP_SECS"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backoff: woke for attempt $((ATTEMPT+1))" >> "$LOG_FILE"
    fi
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All ${MAX_ATTEMPTS} attempts failed — no digest for ${TODAY}" >> "$LOG_FILE"
exit 1
