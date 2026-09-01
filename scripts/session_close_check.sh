#!/usr/bin/env bash
# session_close_check.sh — mechanical checklist for the session close chain (CLAUDE.md §Session Wrap-up ①–⑥).
#
# WHY (loop_engineering.md census, 2026-07-10): the close chain's complete/persist legs were PROSE —
# card-last ordering and step coverage lived on salience alone, and the measured misses (card
# staleness class) all landed on exactly these legs. This script is the MECH floor: it VERIFIES
# state, it does not perform the steps (the session still runs them; the script catches skips).
# Built on operator instruction 2026-07-10 (strengthen-the-weak pass; evidence-threshold override
# recorded — the miss class was already measured, only the build trigger was overridden).
#
# READ-ONLY. Exit 0 = close state consistent · exit 1 = a close invariant is violated (card-last
# broken, or a required artifact missing). Advisory lines are prefixed ⚠️ , violations ❌ .
#
# Usage: bash scripts/session_close_check.sh [repo_root]   (run at close time, before ⑥ push)

set -uo pipefail

# 상속된 git 환경변수를 끊는다 — export 된 GIT_DIR 이 있으면 `git -C "$FH"` 가 인자로 받은
# 레포가 아니라 그 레포를 잰다(Axis 2 at-floor LOW, 2026-08-06). READ-ONLY 체커라 부작용 없음.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
FH="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TODAY=$(date +%Y-%m-%d)
CARD="$FH/tracks/_meta/reference_next_session_starter.md"
FAIL=0

_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

echo "── session close check: $FH ($TODAY) ──"

# ① status snapshot — uncommitted / unpushed work must be known, not forgotten
# DIRTY 도 같은 형태였다 — `status --porcelain 2>/dev/null | wc -l` 은 git 이 죽어도 0 을 세어
# "깨끗함"으로 승격된다(재현: `.git/index` 손상 → exit 128, 출력 0줄). 종료코드를 먼저 본다.
# ⚠️ 이 줄은 **바로 아래 UNPUSHED 수리와 같은 결함**이었고, 처음엔 아래만 고쳤다 —
# 반쪽 수리를 고치는 커밋에서 반쪽 수리를 할 뻔했다(Axis 2 챌린저가 잡음, 2026-08-06).
# `--untracked-files=all` 은 `status.showUntrackedFiles=no` config 를 덮어쓴다. 그 config 아래에서는
# git 이 **성공적으로 침묵**해(exit 0 · 빈 출력) 종료코드 가드로도 안 잡힌다 — 부재가 다시
# "깨끗함"으로 렌더된다(Axis 2 at-floor MED, 재현: 미추적 파일 1건이 0 으로 보고됨).
if _st=$(git -C "$FH" status --porcelain --untracked-files=all 2>/dev/null); then
  DIRTY_KNOWN=1
  DIRTY=$(printf '%s' "$_st" | grep -c . || true)
else
  DIRTY_KNOWN=0
  DIRTY=0
fi
# upstream 유무를 **먼저 판정**한다. `@{u}..` 는 upstream 이 없으면 실패해 0줄을 내고, 그 0을
# `wc -l` 이 0으로 세어 "nothing unpushed" 로 승격된다 — **한 번도 머신을 떠난 적 없는 커밋이
# '푸시할 것 없음'으로 읽히는 fail-open**. 부재를 깨끗함으로 읽는 것이라 0 을 신뢰하면 안 된다.
# (downstream fork's review lane caught it first; this file is the upstream original — 2026-08-06.)
if git -C "$FH" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  UPSTREAM_KNOWN=1
  UNPUSHED=$(git -C "$FH" log --oneline @{u}.. 2>/dev/null | wc -l | tr -d ' ')
else
  UPSTREAM_KNOWN=0
  UNPUSHED=0
fi
[ "$DIRTY_KNOWN" -eq 0 ] && echo "⚠️  ① UNMEASURED — git status failed; working-tree cleanliness is UNKNOWN, not clean"
[ "$DIRTY_KNOWN" -eq 1 ] && [ "$DIRTY" -gt 0 ] && echo "⚠️  ① $DIRTY uncommitted path(s) — decide: commit or leave deliberately"
[ "$UPSTREAM_KNOWN" -eq 0 ] && echo "⚠️  ① UNMEASURED — no upstream for this branch; unpushed count is UNKNOWN, not zero"
[ "$UPSTREAM_KNOWN" -eq 1 ] && [ "$UNPUSHED" -gt 0 ] && echo "⚠️  ① $UNPUSHED unpushed commit(s) — push before close or record why"
# "as of last fetch" — 원격을 조회하지 않는다. 로컬 remote-tracking ref 가 낡았으면 이 0 도 낡은 값이다
# (Axis 2 챌린저 MED, 2026-08-06). fetch 를 넣지 않은 것은 마감 체커가 READ-ONLY·오프라인 안전이기 때문.
# 추적 파일이 assume-unchanged/skip-worktree 로 마킹돼 있으면 그 수정은 porcelain 에 **안 뜬다** —
# `-uall` 로도 안 잡히는 별개 계기다(Axis 2 at-floor MED, 재현 확인).
MASKED=$(git -C "$FH" ls-files -v 2>/dev/null | grep -c '^[a-z]' || true)
[ "${MASKED:-0}" -gt 0 ] \
  && echo "⚠️  ① $MASKED file(s) assume-unchanged/skip-worktree — their edits are INVISIBLE here"

# ★ 잰 범위 ≠ 주장 범위 (Axis 2 at-floor HIGH, 2026-08-06).
# `@{u}..` 는 **현재 브랜치만** 잰다. 다른 로컬 브랜치에만 있는 미푸시 커밋은 통째로 안 보이는데
# 화면 문구는 "nothing unpushed"(레포 전체)라고 말한다 — 이 파일의 존재 이유 정중앙이다.
# 재현: 다른 브랜치에 미푸시 커밋 1건 → `✅ nothing unpushed` 가 그대로 떴다.
# 원격이 하나도 없으면 이 값이 전 커밋 수로 부풀므로 원격 존재를 먼저 가드한다.
OTHER_UNPUSHED=0
if [ -n "$(git -C "$FH" remote 2>/dev/null)" ]; then
  OTHER_UNPUSHED=$(git -C "$FH" log --branches --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')
fi
[ "${OTHER_UNPUSHED:-0}" -gt 0 ] \
  && echo "⚠️  ① $OTHER_UNPUSHED commit(s) on local branches never pushed anywhere (all-branch scan)"

[ "$DIRTY_KNOWN" -eq 1 ] && [ "$DIRTY" -eq 0 ] && [ "$UPSTREAM_KNOWN" -eq 1 ] && [ "$UNPUSHED" -eq 0 ] \
  && [ "${OTHER_UNPUSHED:-0}" -eq 0 ] && [ "${MASKED:-0}" -eq 0 ] \
  && echo "✅ ① working tree clean, nothing unpushed anywhere (as of last fetch)"

# ①-b open-PR sweep (surface-not-auto — requires gh; skip silently offline)
if command -v gh >/dev/null 2>&1; then
  # `gh --json` emits COMPACT single-line JSON when piped, so counting LINES returned 1 for ANY
  # non-zero number of open PRs — the sweep hid every PR after the first, in the exact step CLAUDE.md
  # pairs with count consistency. Count OCCURRENCES instead. Measured 2026-08-02 with a known pair:
  # `[{"number":227},{"number":226},{"number":225}]` → old 1, new 3; `[]` → 0 both ways — which is
  # why an environment with zero open PRs can never surface this, and why the 0-case alone is not a
  # calibration. Observed live the same day: 2 open PRs reported as 1.
  # Anchored by scripts/test_session_close_chain_lanes.sh lane ①-b-P3.
  PRS=$(gh pr list --author "@me" --state open --json number 2>/dev/null | grep -o '"number"' | wc -l | tr -d ' ' || true)
  [ "${PRS:-0}" -gt 0 ] && echo "⚠️  ①-b $PRS open PR(s) by you — classify: self-mergeable vs awaiting-external"
fi

# ── ①-d CLOSE RE-OPENED? ──────────────────────────────────────────────────────
# WHY: a session that closed cleanly and then kept working looks IDENTICAL to one that never
# closed — both read Completed from outside, and ①-c cannot separate them. Measured 2026-08-09:
# this session ran step 5 eleven times and a peer independently named the same gap. The two need
# opposite actions — an unfinished close must be FINISHED, a re-opened one must be RE-FOLDED.
# HOW: stamp each close-gated pass and count. Self-attested (whoever runs the check writes it):
# it detects the pattern, it does not prove it.
CLOSE_STAMP="$FH/tracks/_meta/.close_stamps_$TODAY"
if [ "${FH_SESSION_CLOSE:-0}" = "1" ]; then
  mkdir -p "$(dirname "$CLOSE_STAMP")" 2>/dev/null
  date -u +%Y-%m-%dT%H:%M:%SZ >> "$CLOSE_STAMP" 2>/dev/null || true
fi
if [ -f "$CLOSE_STAMP" ]; then
  CLOSE_N=$(grep -c . "$CLOSE_STAMP" 2>/dev/null | tr -d ' ')
  if [ "${CLOSE_N:-0}" -gt 1 ]; then
    echo "ℹ️  ①-d close ran $CLOSE_N times today — CLOSED-THEN-WORKED, not a stalled close."
    echo "     Both look Completed from outside; only this counter separates them."
    echo "     Every re-open owes a FULL step 5: append to fh_completed FIRST, then rewrite the card."
  fi
fi

# ── ①-c LIVE PEER SESSIONS in this same harness ─────────────────────────────────
# WHY: FH's close chain has an agreed two-axis order (peer appends → ping → **ask "더 있나" before
# folding** → fold → re-check merged PRs), and it lived only in the session card as prose. Measured
# 2026-08-09, the first two-axis close: the ping surfaced four deltas the closing session did not
# know about, and **two of them were structurally invisible to `gh pr list`** (an inheritance
# channel and a landing check — no PR exists for either). So a PR sweep is not a substitute; the
# question is. This block does the DETECTION half mechanically. It never merges anything and never
# blocks — the merge is where the loss risk is (two sessions writing one card is the shared-checkout
# hazard this repo already named), and one occurrence is below this repo's own mechanization bar.
#
# HOW: a live session owns /tmp/cc-socks/<pid>.sock. pid → cwd resolves the ONE thing that actually
# matters, "is this peer in MY harness" — which the agent-facing session list cannot answer, because
# it reports names, not directories. Stale sockets are detectable (pid gone), so absence here is a
# measurement rather than silence.
# SCOPE (operator, 2026-08-09): this is a **claude-agents / Agent-View** feature — the surface where
# sessions are deliberately run in parallel. A plain solo terminal must not be nagged because some
# other window happens to be open. Discriminator is env, set by the parent that spawns the session.
#   ⚠️ NEGATIVE ARM UNVERIFIED: a child session cannot observe a top-level session's environment, so
#   "a real top-level session lacks these vars" is asserted, not measured. The lane simulates absence
#   by unsetting them, which tests THIS SCRIPT'S logic — not that claim. Verify from a plain terminal.
if [ -z "${CLAUDE_CODE_CHILD_SESSION:-}${CLAUDE_CODE_AGENT:-}" ] && [ "${FH_PEER_SCAN_FORCE:-0}" != "1" ]; then
  : # solo/top-level surface — ①-c is out of scope here, and silence is the correct output
else
PEER_LIVE=0; PEER_UNKNOWN=0; PEER_STALE=0; PEER_SPARE=0; PEER_IDS=""
# Two more counters, added 2026-08-22. WHY they are SEPARATE values and not one bucket: a peer whose
# cwd resolves to a DIFFERENT repo has been placed — excluding it is a measurement. A peer whose cwd
# resolves to no repo at all has NOT been placed, and folding that into the same number would render
# an unmeasured thing as a decided one (not-found != zero, one level up from line 170's case).
PEER_OTHERREPO=0   # placed, and it is somebody else's repo → correctly excluded, stays quiet
PEER_OFFTREE=0     # cwd READ but placeable in neither this repo nor any repo → must not read as 0
SOCK_DIR="${FH_PEER_SOCK_DIR:-/tmp/cc-socks}"
# Self-exclusion must walk the ANCESTOR chain, not compare `$$`. This script is a grandchild of the
# session process that owns the socket, so `$$` never matches it — measured: the first run counted
# the calling session as its own peer, i.e. it would tell you to go ask yourself.
SELF_CHAIN=" $$ "
_p=$$
while :; do
  _p=$(ps -o ppid= -p "$_p" 2>/dev/null | tr -d ' ')
  case "$_p" in ''|0|1) break ;; esac
  SELF_CHAIN="$SELF_CHAIN$_p "
done
_peer_cwd() { # $1=pid → cwd on stdout, empty if unresolvable
  if [ -r "/proc/$1/cwd" ]; then readlink "/proc/$1/cwd" 2>/dev/null; return; fi
  command -v lsof >/dev/null 2>&1 || return 0
  lsof -a -p "$1" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1
}
# Repo identity, NOT directory prefix. Measured 2026-08-22 (probe_2026-08-22_A2_replication.md):
# `--show-toplevel` yields the WORKTREE's own path, and a worktree by definition lives outside the
# main tree — so `"$FH"/*` prefix matching fails STRUCTURALLY for every worktree of this repo, in
# both directions. From the main tree it silently dropped the worktree peer (no counter moved at
# all); from a worktree it printed a confident "✅ no live peer" with three live same-repo sessions
# running. `git rev-parse --git-common-dir` returns the MAIN tree's .git from inside any worktree,
# which is exactly the equality this question needs — the same property templates/.git-hooks/pre-commit
# already relies on to reach evidence from a worktree.
#   ⚠️ It can return a RELATIVE path (plain '.git' when run at a repo root — measured here, git 2.50),
#   so the raw output of the main tree and of its own worktree DIFFER as strings. Normalising to an
#   absolute real path is not tidiness; comparing raw output would reproduce the very bug being fixed.
_repo_id() { # $1=dir → absolute real path of the repo's COMMON .git, empty if not placeable in a repo
  ( cd "$1" 2>/dev/null || exit 0
    _c=$(git rev-parse --git-common-dir 2>/dev/null) || exit 0
    [ -n "$_c" ] || exit 0
    cd "$_c" 2>/dev/null || exit 0
    pwd -P )
}
# Computed once. Empty = $FH itself is not inside a git repo; then repo-identity cannot decide
# anything and every off-prefix peer falls through to PEER_OFFTREE (unplaceable), never to "absent".
FH_REPO_ID="$(_repo_id "$FH")"
if [ -d "$SOCK_DIR" ]; then
  for _s in "$SOCK_DIR"/*.sock; do
    [ -e "$_s" ] || continue
    _pid="${_s##*/}"; _pid="${_pid%.sock}"
    case "$_pid" in ''|*[!0-9]*) continue ;; esac
    case "$SELF_CHAIN" in *" $_pid "*) continue ;; esac   # 나 자신(조상 체인)
    if ! ps -p "$_pid" >/dev/null 2>&1; then PEER_STALE=$((PEER_STALE+1)); continue; fi
    # bg-spare = pre-warmed worker, NOT a session. It owns a socket and a cwd like everything else,
    # so cwd matching alone counts it as a peer — measured 2026-08-09, and it is a pure false
    # positive with a clean signature. Exclude mechanically rather than explaining it away.
    case "$(ps -p "$_pid" -o args= 2>/dev/null)" in *--bg-spare*) PEER_SPARE=$((PEER_SPARE+1)); continue ;; esac
    _pcwd="$(_peer_cwd "$_pid")"
    if [ -z "$_pcwd" ]; then
      # Alive but undirected. NOT zero — a peer we cannot place is exactly the case that must not
      # render as "no peers" (not-found != zero).
      PEER_UNKNOWN=$((PEER_UNKNOWN+1)); continue
    fi
    case "$_pcwd" in
      "$FH"|"$FH"/*) PEER_LIVE=$((PEER_LIVE+1)); PEER_IDS="$PEER_IDS $_pid" ;;
      *)
        # The `default` arm that was missing until 2026-08-22. Every peer that reaches here has a
        # READ cwd that is not under $FH, and previously left the loop without touching a single
        # counter — so the ladder below could not tell it from "there was nobody". Three outcomes,
        # and the point is that they are three, not two.
        _prepo="$(_repo_id "$_pcwd")"
        if [ -n "$FH_REPO_ID" ] && [ "$_prepo" = "$FH_REPO_ID" ]; then
          # Same repo, different worktree — a real peer of THIS harness. The case this fix exists for.
          PEER_LIVE=$((PEER_LIVE+1)); PEER_IDS="$PEER_IDS $_pid"
        elif [ -n "$_prepo" ]; then
          # Placed in a DIFFERENT repo. Excluding it is a measurement, so it stays quiet on purpose:
          # warning here would nag every close about unrelated projects, and an advisory that fires
          # on every close trains skimming past the lines that matter.
          PEER_OTHERREPO=$((PEER_OTHERREPO+1))
        else
          # cwd read, but it belongs to no repo we can name (or $FH is not in a repo). UNPLACEABLE —
          # routed to the existing UNPLACEABLE branch below rather than to a new verdict of its own.
          PEER_OFFTREE=$((PEER_OFFTREE+1))
        fi
        ;;
    esac
  done
else
  PEER_UNKNOWN=-1
fi
if [ "$PEER_UNKNOWN" = "-1" ]; then
  echo "ℹ️  ①-c peer scan UNMEASURED — no session-socket dir at $SOCK_DIR (not 'no peers')"
elif [ "$PEER_LIVE" -gt 0 ]; then
  echo "⚠️  ①-c $PEER_LIVE peer CANDIDATE(s) in THIS harness —$PEER_IDS"
  echo "     The surplus over the fleet view Working list is MIXED — do not read it as one thing."
  echo "     Measured 2026-08-09, three kinds land here and only the first needs a message:"
  echo "       working session   → ask before folding"
  echo "       idle terminal     → a real session sitting at a prompt. Not working. Usually skip."
  echo "       lingering process → a close that never finished (seen once, had to be killed by hand)"
  echo "     Only the fleet view separates them. An earlier version of this text called the whole"
  echo "     surplus unfinished closes; that was one case generalised, and it was wrong."
  echo "     Do NOT switch to the job state file to narrow it: it marked THIS session done"
  echo "     (firstTerminalAt set) while it was still running — it under-reports as hard as"
  echo "     sockets over-report. Cross-read with the fleet view; neither source alone is right."
  echo "     THIS IS A DETECTION LIST, NOT A RECIPIENT LIST — do not message all of them."
  echo "     What survives here is: a live PROCESS whose cwd is this harness, minus pre-warmed"
  echo "     spares. That still includes IDLE TERMINALS sitting at a prompt. It is NOT a list of"
  echo "     sessions that are working — nothing here can tell you that; the fleet view can."
  echo "     Notify only the ones actually WORKING/BUSY right now. Messaging a finished session"
  echo "     is noise, burns a recipient approval, and does not land in their record."
     echo "     Of those still working, ASK '지금부터 마감이다, 더 있나' — the question is wider than a"
  echo "     PR sweep: a peer's inheritance-channel or landing-check work has no PR to find."
  echo "     Then fold, then re-check \`gh pr list --merged\`. Merging their delta stays MANUAL."
  echo "     SENDING IS NOT DELIVERING — a cross-session message can be held for the recipient"
  echo "     user approval and never arrive; the send call still reports success. Measured"
  echo "     2026-08-09: 2 of 5 notices were held while the card already claimed all 5 informed."
  echo "     Record ANSWERS, not sends, and put the unanswered count in the card."
  [ "$PEER_UNKNOWN" -gt 0 ] && echo "     + $PEER_UNKNOWN live session(s) whose directory is UNKNOWN (counted, not dismissed)"
  [ "$PEER_OFFTREE" -gt 0 ] && echo "     + $PEER_OFFTREE live session(s) whose directory belongs to NO repo (counted, not dismissed)"
elif [ "$PEER_UNKNOWN" -gt 0 ] || [ "$PEER_OFFTREE" -gt 0 ]; then
  echo "⚠️  ①-c 0 peers placed in this harness, but $((PEER_UNKNOWN+PEER_OFFTREE)) live session(s) are UNPLACEABLE"
  echo "     ($PEER_UNKNOWN with no readable cwd · $PEER_OFFTREE whose cwd belongs to no repo)"
  echo "     — treat as possible peers and ask; do not read this as 'closing alone'."
else
  # The parenthetical must account for EVERY kind that was dropped, not only the flattering ones.
  # Before 2026-08-22 it listed stale+spare while silently discarding same-repo worktree peers, so
  # "0 stale · 0 spare" read as "three kinds swept, all empty" at the exact moment three real peers
  # had been thrown away. A green line is only allowed to be green about what it actually counted.
  echo "✅ ①-c no live peer in this harness (${PEER_STALE} stale · ${PEER_SPARE} pre-warmed spare(s) · ${PEER_OTHERREPO} in other repo(s) — all placed)"
fi

fi

# ② FH assets changed today → harvest-loop owed
# NOTE: no `grep -q` here — under `set -o pipefail`, -q's early exit SIGPIPEs git log (141),
# masking a real match as pipeline failure so the warning NEVER fired on true positives
# (caught by a Sonnet blind probe 2026-07-10, 5/5 deterministic repro). `grep -c` reads the
# whole stream; `|| true` guards its exit-1-on-zero.
#
# SATISFIABLE (2026-07-28): this warning used to fire on EVERY close that touched an FH asset, with
# no way for the session to discharge it — the script had no means of observing whether harvest-loop
# ran. A permanently-firing line is noise, and noise trains the runner to skim past the ❌ lines that
# do matter (the same objection raised against pre-push:484 on 2026-07-28 — one standard, both places).
# So the obligation now has a mechanical discharge: a `harvest-loop` mention in TODAY's fh_completed
# file. HONEST SCOPE: this tests ACKNOWLEDGMENT, not execution — the script cannot see a skill run.
# Recording "harvest-loop: skipped, <reason>" discharges it exactly as recording a run does, which is
# correct: CLAUDE.md ② accepts "harvest-loop (or an explicit skip note)". What it now catches is the
# real miss class — closing with FH assets changed and *no decision recorded either way*.
FH_CHANGED=$(git -C "$FH" log --since="today 00:00" --name-only --pretty=format: 2>/dev/null \
     | grep -cE '^(plugins/.*SKILL\.md|\.claude/rules/|templates/|CLAUDE\.md|knowledge/)' || true)
if [ "${FH_CHANGED:-0}" -gt 0 ]; then
  HL_NOTED=0
  [ -f "$FH/tracks/_meta/fh_completed_${TODAY}.md" ] \
    && HL_NOTED=$(grep -ciE 'harvest[-_]loop' "$FH/tracks/_meta/fh_completed_${TODAY}.md" || true)
  if [ "${HL_NOTED:-0}" -gt 0 ]; then
    echo "✅ ② FH assets changed today ($FH_CHANGED path-touch(es)) — harvest-loop decision recorded in fh_completed_${TODAY}.md"
  else
    echo "⚠️  ② FH assets changed today ($FH_CHANGED path-touch(es)) and fh_completed_${TODAY}.md records no"
    echo "     harvest-loop decision — run it, or write one line stating the skip and why (either discharges this)"
  fi
fi

# ④-log real-time completion log — required whenever any commit landed today.
# NAMING: this block does NOT implement CLAUDE.md's ④ (memory hygiene). It implements the
# "Real-time completion tracking" paragraph that sits above the chain. Labelling it ④ meant a green
# "④" told a reader memory hygiene had been verified when nothing had checked it — false coverage,
# the same class as a summary line that prints PASS while the exit code refuses. The label now says
# what it checks. (Numbering mismatch found 2026-08-02 by the lane-writing pass.)
COMMITS_TODAY=$(git -C "$FH" log --since="today 00:00" --oneline 2>/dev/null | wc -l | tr -d ' ')
FC="$FH/tracks/_meta/fh_completed_${TODAY}.md"
if [ "$COMMITS_TODAY" -gt 0 ] && [ ! -f "$FC" ]; then
  echo "❌ ④-log commits landed today but tracks/_meta/fh_completed_${TODAY}.md is missing"
  FAIL=1
fi

# ④-b npm freshness — files[] assets changed since last version tag → republish owed.
# Patterns are NARROWED to the actually-shipped subpaths (package.json files[]): knowledge/ ships only
# shared/{harness-core,dialogue,rules}; docs/ ships only {codex-compat,CONTRIBUTING,pillars}. A broad
# ^knowledge/ / ^docs/ over-matched git-tracked-but-UNshipped files (e.g. knowledge/shared/learnings/
# subagent_invocations_log.yaml, which changes almost every self-dev session) → guaranteed per-session
# false positive that trains the runner to ignore the line (Axis-2 challenger catch 2026-07-13).
SHIP_RE='^(plugins/|knowledge/shared/(harness-core|dialogue|rules)/|docs/(codex-compat|CONTRIBUTING|pillars)|README|AGENTS\.md|CLAUDE\.md|CHEATSHEET|CATALOG\.md)'
LAST_TAG=$(git -C "$FH" describe --tags --abbrev=0 2>/dev/null || true)
if [ -n "$LAST_TAG" ] && [ -f "$FH/package.json" ]; then
  CHANGED_SINCE_TAG=$(git -C "$FH" diff --name-only "$LAST_TAG"..HEAD 2>/dev/null)
  if printf '%s\n' "$CHANGED_SINCE_TAG" | grep -qE "$SHIP_RE"; then
    echo "⚠️  ④-b npm-shipped assets changed since $LAST_TAG — propose lockstep republish (never auto)"
    # env-purity advisory (2026-08-10, 운영자 «자체점검기 모듈화»): 큰 업그레이드 시점 = 출하자산
    # 변경 시점 — 공유층의 환경-전용 산문을 세서 포인터화/독해규칙 후보를 표면화한다 (advisory).
    [ -x scripts/env_purity_scan.sh ] && bash scripts/env_purity_scan.sh 2>/dev/null | tail -3
  fi
  # ④-b-drift: auto-FIRE a drift-CANDIDATE reminder (not a parity verdict) — **in BOTH directions**.
  # The two entry points are read by DIFFERENT runtimes (CLAUDE.md → Claude Code · AGENTS.md/codex-compat
  # → Codex/OpenCode and other non-CC runtimes). A rule that lands in only one is INVISIBLE to the other,
  # so either file changing alone is a candidate — not just the CC→Codex direction.
  # HONEST SCOPE: this tests file co-occurrence, not topical parity — false-positive (a genuinely
  # runtime-specific change needs no mirror) and false-negative (file touched for an unrelated reason)
  # are both possible. The reminder is mechanized; the drift DETERMINATION stays judged (sync, or record
  # drift:none).
  # Origin (2026-07-19): the REVERSE direction was unwired and a real miss slipped through — a field
  # harness's boundary-crossing behavior rules landed in AGENTS.md only, leaving Claude Code sessions
  # unaware of a rule whose violation destroys a downstream harness's identity. Half a check caught none
  # of it, because the miss happened to travel the unwired way.
  _ENTRY_CC='^(CLAUDE\.md|knowledge/shared/(harness-core|dialogue|rules)/)'
  _ENTRY_CX='^(AGENTS\.md|docs/codex-compat)'
  if printf '%s\n' "$CHANGED_SINCE_TAG" | grep -qE "$_ENTRY_CC" \
     && ! printf '%s\n' "$CHANGED_SINCE_TAG" | grep -qE "$_ENTRY_CX"; then
    echo "⚠️  ④-b drift candidate (CC→Codex): shipped CLAUDE.md/knowledge changed but AGENTS.md/docs/codex-compat did not — JUDGE entry-point parity (sync, or record drift:none if genuinely unaffected)"
  fi
  if printf '%s\n' "$CHANGED_SINCE_TAG" | grep -qE "$_ENTRY_CX" \
     && ! printf '%s\n' "$CHANGED_SINCE_TAG" | grep -qE "$_ENTRY_CC"; then
    echo "⚠️  ④-b drift candidate (Codex→CC): AGENTS.md/docs/codex-compat changed but CLAUDE.md/knowledge did not — JUDGE entry-point parity (a rule living only in AGENTS.md is invisible to Claude Code sessions)"
  fi
fi

# ④-e DISPATCH-LOG RECONCILIATION — mechanical, because prose failed completely.
# CLAUDE.md makes an invocation-log entry MANDATORY immediately after any custom sub-agent
# invocation (it feeds the 60/40 promotion gate and the UAP loop). Measured 2026-08-02: a single
# session dispatched 20+ subagents and logged ZERO — not a marginal lapse, a total one, in the same
# session that RECOVERED that very log file from a branch about to be deleted. An obligation that
# loses 20 times out of 20 is not under-emphasised; it is unmechanized. Per this repo's own rule
# (1-2 occurrences -> prose; N>=3 or a repeat on another surface -> mechanize), this is well past it.
#
# The check is a RECONCILIATION, not an auto-writer. A hook cannot fill `outcome` or `evidence`
# without fabricating judgment, and a fabricated log entry is worse than a missing one — it would
# poison the promotion gate with invented outcomes. So the hook only TALLIES (SubagentStop appends a
# date line) and this step compares the tally against today's entries.
#
# It deliberately does NOT demand 1:1. Consolidating twenty challenger rounds into one entry with
# measured counts is better bookkeeping than twenty stubs, and punishing it would train stub-spam.
# What it catches is the failure that actually happened: dispatches occurred and NOTHING was written.
# ABSENCE IS NOT ZERO. The tally comes from a SubagentStop hook configured in `.claude/settings.json`,
# which is GITIGNORED by design (it also carries local permissions). So a fresh clone, another
# machine, or a wiped settings file has no hook — and without this branch the check would read an
# empty tally as "no dispatches today" and pass in silence. That is the exact fail-open this whole
# step exists to close, re-created inside it; caught before commit by asking where the tally comes
# from. Installable snippet: templates/subagent-tally-hook.json.
TALLY="$FH/tracks/_meta/.subagent_dispatch_tally"
LOG="$FH/knowledge/shared/learnings/subagent_invocations_log.yaml"
HOOK_OK=0
if [ -f "$FH/.claude/settings.json" ]; then
  grep -q '"SubagentStop"' "$FH/.claude/settings.json" 2>/dev/null && HOOK_OK=1
fi
if [ "$HOOK_OK" -eq 0 ]; then
  echo "⚠️  ④-e dispatch log NOT MEASURED — no SubagentStop tally hook in .claude/settings.json"
  echo "     (that file is gitignored, so a fresh clone has none). An unmeasured dispatch count is"
  echo "     NOT a count of zero. Install: templates/subagent-tally-hook.json → .claude/settings.json"
fi
# `grep -c` PRINTS 0 and EXITS 1 when the count is zero. Under `set -o pipefail` (line 16) that
# makes the pipeline fail, `|| echo 0` appends a SECOND line, and the value becomes "0\n0" — which
# `[ -eq ]` rejects as a bash error, so the branch it guards is skipped. The guard was therefore
# disarmed in EXACTLY the case it exists for (zero log entries). Measured 2026-08-04 during a close:
# the check printed ✅ while `[: 0\n0: integer expression expected` went to stderr.
# Fix = no `|| echo`, plus integer sanitation. This is the documented prescription for this class
# ([[feedback_pipefail_fallback_disarms_guard]]) applied to the checker that cited it.
_int() { case "${1:-}" in (''|*[!0-9]*) echo 0 ;; (*) echo "$1" ;; esac; }
# 🟥 2026-08-26 (cross-family/codex) — the fix above closed the `0\n0` half and left the OTHER
# half open: `|| true` + `_int` folded a READ FAILURE into the same 0 as a genuine no-match, so an
# unreadable tally rendered as "✅ no sub-agent dispatches tallied today" — a green nobody measured.
# `grep -c` separates the three cleanly: rc 0 = matched, rc 1 = no match (a REAL zero), rc >= 2 =
# grep itself failed. Only the first two are counts; the third is UNMEASURED and must not be 0.
# ([[feedback_not_found_is_not_zero_family]] — `not found` != `0`, applied to this checker.)
# 🟥 Kept as a HELPER + a ONE-LINE assignment on purpose: test_dispatch_log_lanes.sh lifts the
# subject's own `^DISPATCHED=` / `^LOGGED=` line and evaluates it, precisely so the lane cannot go
# green on a needle that no longer matches real behaviour. A multi-line if/else defeats that lift.
_cnt() {  # $1 = a path that must EXIST (or "" to skip that test); rest = the reader command.
          # Three states, not two — the lane below pins all three:
          #   path absent        -> 0          a tally that was never written IS zero dispatches;
          #                                    calling that UNMEASURED false-blocks every clean
          #                                    close on a fresh install, and an over-blocking close
          #                                    gate trains the --no-verify reflex that disarms the
          #                                    Destructive-Op gate sharing that hook.
          #   reader rc 0 or 1   -> the count  (rc 1 = grep's honest "no match")
          #   reader rc >= 2     -> UNMEASURED the reader ITSELF failed; folding that into 0 printed
          #                                    "no dispatches tallied today" on something nobody read.
  _c_f="$1"; shift
  if [ -n "$_c_f" ] && [ ! -e "$_c_f" ]; then echo 0; return; fi
  _c_out=$("$@" 2>/dev/null); _c_rc=$?
  if [ "$_c_rc" -ge 2 ]; then echo UNMEASURED; else _int "$(printf '%s' "$_c_out" | tr -d ' ')"; fi
}
DISPATCHED=$(_cnt "$TALLY" grep -c "^$TODAY$" "$TALLY")
# Both quotings, because the file carries both: hand-written entries use `- date: 2026-08-02`
# while anything appended via yaml.dump renders `- date: '"'"'2026-08-02'"'"'`. Matching one form counted
# half the entries as absent — a divergent-normalizer miss inside the check that exists to catch
# missing records. Known-pair calibrated below in test_dispatch_log_lanes.sh.
# ── 전환 설계: 레거시 단일 파일 ∪ 세션별 디렉터리를 **둘 다** 읽는다 ────────────
# WHY: 같은 파일 끝에 여러 세션이 append 하면 브랜치 병합이 확정 충돌이고, 그 해소가
# 조용히 손상된다 — git 이 엔트리 헤더 한 줄을 공통 접두로 밀어내서 «양쪽 다 보존»이라는
# 정답 해소가 엔트리를 흡수시킨다(2026-08-09 재현: 항목 133/정답 134, 파싱은 통과).
# 처방은 세션당 한 파일. 다만 **마이그레이션과 배선을 같은 커밋에 묶으면** 아직 머지 안 된
# 원장 브랜치와 대형 충돌이 나므로, 소비자를 먼저 «둘 다 읽게» 만든다. 그러면 데이터가
# 언제 옮겨가든 이 검사는 안 깨진다. 두 상태 모두 known-pair 로 고정돼 있다.
LOGDIR="$FH/knowledge/shared/learnings/subagent_invocations"
_cat_logs() {  # 다중 파일에 grep -c 를 직접 걸면 파일별 `경로:개수` 를 찍어 합산이 깨진다(실측).
  { [ -f "$LOG" ] && cat "$LOG"; [ -d "$LOGDIR" ] && cat "$LOGDIR"/*.yaml; } 2>/dev/null
}
_log_grep() {  # 🟥 MUST stay multi-line: the lane lifts defs with /^_name\(\) \{/,/^\}/ and a
               # one-liner has no `}` at column 0, so the range never closes and the extraction
               # silently swallows the rest of the file (measured 2026-08-26).
  _cat_logs | grep -cE "^- date: *'?$TODAY'?"
}
LOGGED=$(_cnt "" _log_grep)   # _cat_logs already renders absence as empty, not as an error
if [ "$DISPATCHED" = UNMEASURED ] || [ "$LOGGED" = UNMEASURED ]; then
  echo "❌ ④-e dispatch log: COULD NOT MEASURE (tally=$DISPATCHED, log=$LOGGED) — a read error is"
  echo "     not a count of zero. Fix the read before closing; do not treat this as 'no dispatches'."
  FAIL=1
elif [ "${DISPATCHED:-0}" -gt 0 ] && [ "${LOGGED:-0}" -eq 0 ]; then
  echo "❌ ④-e $DISPATCHED sub-agent dispatch(es) today and ZERO invocation-log entries — the 60/40"
  echo "     promotion gate and the UAP loop both read that file; an unlogged session is invisible to"
  echo "     them. Append to knowledge/shared/learnings/subagent_invocations_log.yaml (consolidated"
  echo "     per class is fine — record counts and outcomes, not one stub per dispatch)."
  FAIL=1
elif [ "${DISPATCHED:-0}" -gt 0 ]; then
  echo "✅ ④-e dispatch log: $DISPATCHED dispatch(es) today, $LOGGED log entr(ies) recorded"
elif [ "$HOOK_OK" -eq 1 ]; then
  echo "✅ ④-e dispatch log: no sub-agent dispatches tallied today"
fi

# ⑤ CARD-LAST invariant — the card must be the NEWEST close artifact. A card older than
# fh_completed / signal files written this session = ⑤ ran before ①–④ finished (the bug class).
if [ -f "$CARD" ]; then
  CARD_E=$(_mtime "$CARD")
  NEWER=$(find "$FH/tracks/_meta" -maxdepth 1 -type f \( -name "fh_completed_*.md" -o -name "fh_signal_*.md" \) -newer "$CARD" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$NEWER" -gt 0 ]; then
    echo "❌ ⑤ card-last violated — $NEWER close artifact(s) newer than the session card; re-run ⑤ (delta update)"
    # NAME the offenders. Recurrence N=3 (2026-07-28, three closes in one day): every repair so far
    # was a prose vow ("next time I'll write the finding into the card first") and every one failed,
    # because the reflex fires mid-close. What is mechanizable is not the reflex but the COST of the
    # miss — a bare count makes ⑤ a re-read of the whole session, while naming the files and showing
    # what landed after the card makes the delta update a minute's work, which is what actually gets
    # done rather than deferred. Diagnosis, not prevention: this line does not claim to stop the miss.
    find "$FH/tracks/_meta" -maxdepth 1 -type f \( -name "fh_completed_*.md" -o -name "fh_signal_*.md" \) -newer "$CARD" 2>/dev/null \
      | while IFS= read -r f; do
          echo "     ↳ ${f#"$FH"/}"
          tail -n 3 "$f" 2>/dev/null | sed 's/^/         │ /'
        done
    echo "     → fold the above into the card, save the card LAST, then re-push."
    FAIL=1
  else
    echo "✅ ⑤ card is the newest close artifact (card-last holds)"
  fi

  # ⑤ tie probe (ADVISORY — never changes the verdict, never blocks).
  # `-newer` is a STRICT comparison, so an artifact whose mtime exactly equals the card's is invisible
  # to the check above: ⑤ reports card-last holds when the ordering was never actually established.
  # That is the same blind spot that made the ⑤-N *lane* flake in CI on 2026-08-02, one layer down —
  # and the lane repair hardened the fixture, not this production path, which still runs against
  # ordinary session writes with no deterministic separation.
  # Why advisory and not a verdict: tightening ⑤ to treat a tie as a violation would BLOCK a healthy
  # close whose two writes happened to land in one clock tick, and an over-blocking close gate trains
  # the override reflex that disarms it (the same reasoning the ⑤-P lane already encodes). Whether
  # real closes ever tie is UNMEASURED — so this line measures it instead of guessing at a fix.
  # Diagnosis, not prevention; promote it to a verdict only on evidence that ties actually occur.
  #
  # COST, measured before shipping (this runs on every push via the pre-push hook, so an unbounded
  # per-file cost is a live regression, not a design risk). `! -newer "$CARD"` does the only safe
  # narrowing: strictly-newer files are already reported by ⑤ above, so the in-loop "is it newer?"
  # check is redundant and dropped — one fork per candidate, not two.
  # A `-mtime -1` bound was tried and REMOVED: it scopes the window to *now*, but the invariant is
  # anchored to the *card*, and this script runs on every push — routinely against a card written
  # days ago. Two artifacts tied with an old card then fall outside the window and ⑤ reports
  # card-last holds on an ordering never established, with the probe scoped out of seeing it. Speed
  # that hides the thing being measured is not speed. Measured cost of the correct form on the
  # current corpus: 140 candidates, 0.57s. Linear in tracks/_meta; revisit if that reaches thousands.
  #
  # Both emitted lines start with the same literal `⚠️  ⑤ tie` on purpose — the pre-push hook greps
  # for it, and when the two lines carried different prefixes the hook surfaced the warning while
  # dropping the sentence that says what to do about it, leaving a reader with only "⑤'s strict
  # comparison cannot see it" — precisely the misreading the summary line exists to prevent.
  # Keep the shared prefix; test_session_close_lanes.sh ⑤-T asserts the hook's exact pattern.
  TIES=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -n "$(find "$CARD" -newer "$f" 2>/dev/null)" ] && continue      # strictly older → fine
    TIES=$((TIES + 1))
    echo "⚠️  ⑤ tie: ${f#"$FH"/} shares the card's exact mtime — ⑤'s strict comparison cannot see it"
  done <<EOF
$(find "$FH/tracks/_meta" -maxdepth 1 -type f \( -name "fh_completed_*.md" -o -name "fh_signal_*.md" \) ! -newer "$CARD" 2>/dev/null)
EOF
  # What a recurring tie would actually license (cross-family correction, 2026-08-02): NOT making ⑤'s
  # comparison non-strict. Ties do not show the comparison is too strict — they show **mtime is not a
  # reliable witness of close ordering on this machine**. A non-strict ⑤ would convert every same-tick
  # healthy close into a false block, which is the failure mode ⑤-P exists to prevent. The fix that
  # ties would justify is an explicit ordering record (the card writing a marker ①–④ can be compared
  # against) or a deterministic close write sequence — not a looser comparison.
  [ "$TIES" -gt 0 ] && echo "⚠️  ⑤ tie → $TIES artifact(s) ordering-ambiguous. If this recurs, mtime is not a sound ordering witness here; the fix is an explicit ordering record, NOT making ⑤ non-strict (that would false-block every healthy same-tick close)."
else
  echo "❌ ⑤ session card missing: $CARD"
  FAIL=1
fi

# ⑤-b card-drift probe — 카드의 "부재 주장"을 실물과 대조 (advisory, never FAIL).
# WHY (N=3, 2026-07-22 주간감사 🟥1): 카드 🔴 "frontier-digest 미가동 — 로그도 산출물도 0"이
# 오판정이었다(실측 launchd 14/14 발화·산출 12/14). 07-20 S-4 재발에 이어 3회째 →
# operations.md §Recurrence escalation: 습관 규칙이 아니라 기계 프로브.
# HONEST SCOPE: 카드 🔴/🟡 줄에서 부재-주장 키워드를 잡고, 그 줄의 이름/경로 토큰으로
# 실물을 글롭 검색한다. 어휘가 안 겹치면 못 잡는다(무음 FN) — 앵커지 floor 가 아니다.
# 방향은 advisory: 가역 표면에서 하드 블록은 --no-verify 를 학습시킨다(#165 HIGH-1 동일 원리).
# COLLATION-FREE BY CONSTRUCTION (2026-07-31, diagnosed ON the runner after two local hypotheses
# were refuted). This regex used to contain the Hangul RANGE `[^가-힣]`. A multibyte range inside a
# bracket expression is collation-dependent, and GNU grep in the C locale — the GitHub runner's
# default — rejects it outright:  `grep: Invalid collation character`.
# The failure mode is what makes it serious: grep writes that to stderr, exits 2, and emits NOTHING.
# Downstream this is indistinguishable from exit 1 "no match", so the pipeline produced zero lines
# and the probe concluded "no absence claims in the card" — CLEAN — on every input, positive and
# negative alike. Its 7 lanes had passed 3/3 on macOS for weeks because BSD grep accepts the range.
# Same shape as the pyyaml CI trigger caught earlier the same day: grep's ERROR status folded into
# its NO-MATCH branch. `not found != 0`, and neither is `could not look`.
# The replacement uses an ASCII-only class, which has no collation to be invalid. SEMANTIC SHIFT,
# stated rather than hidden: the original meant "산출물 then non-Hangul then 0" (keep the claim
# inside one clause); this means "산출물 then no DIGIT within 20 chars then 0". Slightly wider, and
# the lanes below are what pin that it did not become too wide.
_ABSENCE_RE='미가동|산출물[^0-9]{0,20}0|로그[^0-9]{0,20}0|0건|부재|안 돌|미생성|not running|no output|zero output'
# 부정/정정 문맥 가드 — 부재-주장을 **인용하며** 정정하는 줄만 건너뛴다. 판별자는 debunk
# 어휘 단독이 아니라 **부재-키워드가 인용부호 안에 있는가** — challenger A-1 실측: 살아있는
# 주장 + 무관한 '정정 필요' 가 같은 줄이면 debunk-단독 가드가 진짜 경고를 무음 삼켰다(FN).
_DEBUNK_RE='오판정|정정|거짓|아니었|반증'
_QUOTED_ABSENCE_RE='["“”'"'"'『][^"“”'"'"'』]*(미가동|부재|미생성)'
if [ -f "$CARD" ]; then
  DRIFT_HITS=0
  while IFS= read -r line; do
    # 부재-주장 줄에서 검증 가능한 토큰 2계층 추출:
    #  (a) 명시 경로/글롭 (슬래시나 * 포함) — 그대로 글롭 확장
    #  (b) 이름 토큰 (하이픈/언더스코어 포함 ≥6자, e.g. frontier-digest) — -/_ 정규화 후
    #      tracks/_meta{,/logs} 파일명 부분일치 검색
    # `*` 는 추출 클래스에서 제외 — 마크다운 강조(**tok**)가 토큰에 붙어 글롭 분기로
    # 오폭한다(known-pair P 픽스처가 잡은 계기 불량, 2026-07-23). 경로 판정은 슬래시로만.
    tokens=$(printf '%s\n' "$line" | grep -oE '[A-Za-z0-9_./-]+' \
             | sed 's/^[.-]*//; s/[.-]*$//' \
             | grep -E '(/|[A-Za-z0-9]+[-_][A-Za-z0-9]+)' | grep -E '.{6,}' \
             | grep -vE '^[0-9._-]+$' | sort -u)   # 날짜/숫자 토큰 제외 (실카드 FP)
    [ -z "$tokens" ] && continue
    while IFS= read -r tok; do
      found=0
      case "$tok" in
        */*)  # (a) 경로 — **파일만** 인정(-f). 디렉토리를 세면 카드의 위치-언급
              # (tracks/_meta/ 등)이 "실물"로 잡힌다(challenger A-2 FP). 인프라 루트 제외.
          case "$tok" in tracks/_meta|tracks/_meta/|tracks/_meta/logs|tracks/_meta/logs/) continue ;; esac
          # shellcheck disable=SC2086
          for f in $FH/$tok $FH/${tok}*; do [ -f "$f" ] && found=$((found+1)); done ;;
        *)         # (b) 이름 토큰 — 양쪽 구분자 변형으로 검색
          norm_u=$(printf '%s' "$tok" | tr '-' '_'); norm_h=$(printf '%s' "$tok" | tr '_' '-')
          found=$(find "$FH/tracks/_meta" -maxdepth 2 -type f ! -name "$(basename "$CARD")" \( -name "*${norm_u}*" -o -name "*${norm_h}*" \) 2>/dev/null | wc -l | tr -d ' ') ;;
      esac
      if [ "${found:-0}" -gt 0 ]; then
        echo "⚠️  ⑤-b card-drift: 카드가 부재를 주장하는데 실물이 있다 — 토큰 '$tok' 매치 ${found}건. 줄: $(printf '%s' "$line" | cut -c1-80)…"
        echo "     → 주장을 손검증하라 (미가동≠산출누락 — 07-22 오판정 클래스). advisory, 차단 아님."
        DRIFT_HITS=$((DRIFT_HITS+1)); break
      fi
    done <<CARD_TOK_EOF
$tokens
CARD_TOK_EOF
  done <<CARD_LINE_EOF
$(grep -E '(🔴|🟡)' "$CARD" 2>/dev/null | grep -E "$_ABSENCE_RE" | grep -v '^description:' \
   | while IFS= read -r _l; do
       if printf '%s\n' "$_l" | grep -qE "$_DEBUNK_RE" \
          && printf '%s\n' "$_l" | grep -qE "$_QUOTED_ABSENCE_RE"; then continue; fi
       printf '%s\n' "$_l"
     done || true)
CARD_LINE_EOF
  [ "$DRIFT_HITS" -eq 0 ] && echo "✅ ⑤-b no card absence-claim contradicted by on-disk artifacts"
fi

# ⑤-C CARRY-OVER probe — 카드 재작성이 «아직 안 온 기한» 을 날렸는가.
# WHY (2026-08-24, 실측 손실 1건): ⑤ 재작성이 delta update 가 아니라 새로 쓰기가 되어 미완·
# 시각박힌 항목이 통째로 사라졌다 — 그날 저녁 19:00 게시, 다음날 GeekNews, 14일 referrer 측정,
# 08-26 미팅. 세션은 "BEFORE 172 → AFTER 101" 이라는 diff 를 출력하고도 «줄었다» 만 말하고
# «무엇이 빠졌나» 는 보지 않았다. 운영자가 물어서 발견 — 자력 아니다.
# 🟥 이것은 tier 문제가 아니라 WIRING 문제다. 카드 규율(§Session Wrap-up)은 「완료 항목이
# 남는 게 버그」라고 한 방향만 적고 있고, 그 역방향(미완이 사라지는 것)은 검사가 0줄이었다.
# 규율이 한 방향만 적혀 있으면 그 반대는 안 보인다. base op 이 살리언스에만 얹혀 있었으므로
# sonnet_floor_doctrine §tier-gated base op = defect 에 해당한다 — N 을 세기 전에 닫는다.
#
# WHAT IT ASSERTS (채널이지 결론이 아니다 — CLAUDE.md §Mechanization Boundary):
#   「이전 카드에 있던 **미래 날짜**가 오늘 카드나 오늘 fh_completed 에 여전히 나타나는가」
#   = 기록의 성질(존재·귀속). 「이 항목을 지워도 되는가」는 **판정하지 않는다** — 그건 판단이고
#   얼리면 오늘의 판단이 내일의 천장이 된다. 완료 처리했으면 fh_completed 에 날짜가 남으므로
#   그 경로로 통과한다.
#
# HONEST SCOPE:
#   · 판별자는 `YYYY-MM-DD` / `MM-DD` 토큰뿐이다. 날짜 없이 적힌 미완(«4090 부팅 UNKNOWN»)은
#     구조적으로 못 잡는다 — 앵커지 floor 가 아니다.
#   · 이전 카드는 companion store 의 git 이력에서 온다. 그게 없는 install(대부분의 소비자)에서는
#     **SKIP 이고 PASS 가 아니다** — 미측정을 초록으로 접지 않는다.
#   · ASCII 클래스만 쓴다. 다국어 RANGE 를 bracket 안에 넣으면 C 로케일 GNU grep 이
#     `Invalid collation character` 로 exit 2 하고 **아무것도 안 뱉는다** → no-match 와 구분 불가
#     (⑤-b 가 2026-07-31 에 정확히 그렇게 무음 통과했다).
# DEGRADE: 이전 카드 못 구함 → SKIP(미측정 표기) · 구했는데 미래날짜 유실 → FAIL=1.
#   FAIL 은 FH_SESSION_CLOSE=1 인 close push 만 막고 일반 push 는 surface 한다(가역 표면 규율).
#   과차단 시 override: FH_CARRYOVER_OK=1 (무엇을 우회했는지 출력에 남는다).
# 기본값을 두지 않는다 — companion store 의 이름은 install 마다 다르고, 특정 이름을 공개
# 파일에 박으면 그 자체가 operator-private 토큰이다(이 줄은 실제로 그렇게 한 번 차단됐다).
# 설정은 각자의 로컬 바인딩에서 FH_COMPANION_STORE 로 준다.
_CARRY_STORE="${FH_COMPANION_STORE:-}"
_CARRY_MIRROR="tracks-meta/reference_next_session_starter.md"
if [ ! -f "$CARD" ]; then
  : # ⑤ 가 이미 카드 부재를 FAIL 로 보고했다 — 여기서 중복 보고하지 않는다
elif [ "${FH_CARRYOVER_OK:-0}" = "1" ]; then
  echo "⚠️  ⑤-C SKIPPED by FH_CARRYOVER_OK=1 — 이전 카드의 미래-날짜 유실 검사를 우회했다"
elif [ -z "$_CARRY_STORE" ] || [ ! -d "$_CARRY_STORE/.git" ]; then
  echo "⬜ ⑤-C SKIPPED (not PASS) — companion store 미설정/부재 (FH_COMPANION_STORE). 이전 카드를 못 구해 UNMEASURED"
else
  _TODAY_YMD=$(date +%Y-%m-%d)
  # 오늘 이전에 기록된 마지막 카드 버전. 오늘자 sync 커밋들은 이미 재작성본이라 제외한다.
  _PRIOR_SHA=$(git -C "$_CARRY_STORE" log --before="${_TODAY_YMD}T00:00:00" -1 --format=%H -- "$_CARRY_MIRROR" 2>/dev/null || true)
  if [ -z "$_PRIOR_SHA" ]; then
    echo "⬜ ⑤-C SKIPPED (not PASS) — 오늘 이전 카드 버전이 이력에 없다 (첫 세션?) — UNMEASURED"
  else
    _PRIOR_CARD=$(git -C "$_CARRY_STORE" show "$_PRIOR_SHA:$_CARRY_MIRROR" 2>/dev/null || true)
    if [ -z "$_PRIOR_CARD" ]; then
      echo "⬜ ⑤-C SKIPPED (not PASS) — 이전 카드를 읽지 못했다 ($_PRIOR_SHA) — UNMEASURED"
    else
      # 이전 카드의 날짜 토큰 중 «오늘 이상» 인 것만. YYYY-MM-DD 와 MM-DD 둘 다 본다.
      _TODAY_MD=$(date +%m-%d)
      _FUTURE_DATES=$(printf '%s\n' "$_PRIOR_CARD" \
        | grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}|(^|[^0-9])[01][0-9]-[0-3][0-9]([^0-9]|$)' 2>/dev/null \
        | grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}|[01][0-9]-[0-3][0-9]' 2>/dev/null \
        | sort -u | while IFS= read -r d; do
            # bash 3.2(macOS)는 $( ) 안의 case 패턴 ')' 를 오파싱한다 — 길이로 가른다
            _ref="$_TODAY_MD"
            if [ ${#d} -eq 10 ]; then _ref="$_TODAY_YMD"; fi
            if [ "$d" = "$_ref" ]; then printf '%s\n' "$d"
            elif [ "$d" \> "$_ref" ]; then printf '%s\n' "$d"
            fi
          done)
      _LOST=0
      if [ -n "$_FUTURE_DATES" ]; then
        _TODAY_LOG="$FH/tracks/_meta/fh_completed_${_TODAY_YMD}.md"
        while IFS= read -r d; do
          [ -z "$d" ] && continue
          if grep -qF "$d" "$CARD" 2>/dev/null; then continue; fi
          if [ -f "$_TODAY_LOG" ] && grep -qF "$d" "$_TODAY_LOG" 2>/dev/null; then continue; fi
          _CTX=$(printf '%s\n' "$_PRIOR_CARD" | grep -F "$d" | head -1 | cut -c1-90)
          echo "❌ ⑤-C carry-over 유실: 이전 카드의 미래 기한 '$d' 가 오늘 카드에도 fh_completed 에도 없다"
          echo "     이전 카드 원문: $_CTX"
          _LOST=$((_LOST+1))
        done <<CARRY_EOF
$_FUTURE_DATES
CARRY_EOF
      fi
      if [ "$_LOST" -gt 0 ]; then
        echo "   ⇒ ⑤ 는 delta update 다. 완료면 fh_completed 에 적고, 이월이면 카드에 남겨라."
        echo "     정당하게 취소된 항목이면: FH_CARRYOVER_OK=1 FH_SESSION_CLOSE=1 git push"
        FAIL=1
      else
        echo "✅ ⑤-C 이전 카드의 미래 기한이 전부 카드/완료로그에 살아 있다 (prior=${_PRIOR_SHA%%??????????????????????????????????})"
      fi
    fi
  fi
fi

# ── ①-e STRAY PATH (advisory) ────────────────────────────────────────────────
# 🟥 `git status` 는 **빈 디렉터리를 안 보여준다**(`--porcelain` 도 `-uall` 도 0; 파일 하나
#    넣으면 1 — known-pair 로 확인). 그래서 「트리 깨끗」이 이 클래스에 대해선 **부재 증명이
#    아니다.** 2026-08-31 하루에 세 번 났고(거버너 레포 2 · 병렬 팔 레포 1) 세 번 다 «깨끗»
#    보고 뒤에 발견됐다. 그중 하나는 채점기 레인의 전수 grep 을 rc=2 로 죽였다.
# 🟥 **advisory 다 — 막지 않는다.** 빈 디렉터리 하나로 push 를 막으면 그것이 `--no-verify` 를
#    훈련시키고, 같은 훅의 Destructive-Op 게이트를 무장해제한다. 시끄럽게 하되 안 막는다.
if [ -x "$FH/scripts/stray_path_scan.sh" ]; then
  _sp_out=$(bash "$FH/scripts/stray_path_scan.sh" "$FH" 2>&1); _sp_rc=$?
  case "$_sp_rc" in
    1) printf '%s\n' "$_sp_out" ;;
    2) echo "⚠️  ①-e stray-path 스캔 불가 — UNMEASURED (0 으로 읽지 마라)" ;;
  esac
else
  echo "⚠️  ①-e stray_path_scan.sh 없음 — skipped, not passed"
fi

echo "── close check: $([ "$FAIL" -eq 0 ] && echo CONSISTENT || echo VIOLATIONS) ──"
exit "$FAIL"
