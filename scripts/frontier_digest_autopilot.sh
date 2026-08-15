#!/bin/bash
# frontier_digest_autopilot.sh — daily digest + autonomous improvement pipeline, PR-only.
#
# WHY: frontier-digest itself has run unattended (launchd) since 2026-06 — collecting signal
# needs no approval. Turning a signal into an actual FH change was, until now, always a session
# the operator had to start by hand. Operator decision (2026-08-15): push automation one stage
# further — digest → persona-innovator → harvest-loop → 4-axis gate → PR, entirely unattended —
# but stop at the PR. Merge stays a human decision, per CLAUDE.md §AI Contribution Model ("AI does
# not commit directly to shared repositories") and §PR-Only Policy on main. This script is the
# proposal-only half of that split, not an exception to it.
#
# THIS IS STAGE 2 OF THE EXISTING DAILY JOB, NOT A SEPARATE CRON:
#   Stage 1 (unchanged) = frontier_digest_daily.sh — collects the digest, hardened with its own
#   retry/watchdog/lock (see that file's header). This script calls it first, then only proceeds
#   to Stage 2 if Stage 1 actually produced today's digest.
#   Stage 2 (new) = a single headless `claude -p` invocation that reads the digest and, ONLY IF a
#   concrete change survives harvest-loop's own 4-axis gate, opens a PR. No gate-passing candidate
#   → no PR, no forced busywork (operator's explicit threshold choice: "harvest-loop이 실제 게이트를
#   통과한 때만"). This mirrors the digest's own honesty rule (absence ≠ zero, but also: a thin
#   signal is not manufactured into a change just to have shipped something today).
#
#   BACK-END SHIPPING DOCTRINE (operator, 2026-08-15): "개발의 앞단-영혼심기, 중간단-탈상관 가속화,
#   뒷단 출하전-4단검증 및 하네스오너 리뷰" — the back end of shipping is 4-axis verification AND a
#   standpoint-axis review, not 4-axis alone. CORRECTED same session (an earlier draft of this
#   header named fh-meta:hub-cc-pr-reviewer here — wrong skill, caught by the operator: "내가 말한건
#   하네스오너(너) 아니라 그 하네스에 에이전트가 들어가서 그 입장에서 리뷰한다는거야"). "하네스오너
#   리뷰" is NOT the human operator (that gate is merge, unconditionally human, unchanged) NOR
#   hub-cc-pr-reviewer (which checks FH's diff against FH's OWN conventions — same-repo
#   self-consistency, a different question). It is the STANDPOINT AXIS
#   (`knowledge/shared/harness-core/field_verdict_crossfamily_gate.md §7`, the mechanism behind the
#   if(kakao)26 keynote's p15 "(c) 탈상관의 확장" slide — "계열을 늘려도 못 잡는 결함이 있습니다,
#   입장을 바꾸면 보입니다"): an agent actually running the diff's effect from ANOTHER harness's own
#   repo/standpoint, which is orthogonal to family diversity and catches a documented, distinct class
#   of defect family diversity alone does not. Wired into the Stage-2 prompt as two back-end
#   checkpoints beyond the ordinary 4-axis gate: (1) an irreversible/load-bearing-surface diff holds —
#   no PR, branch+signal only, operator decides whether a PR should even exist; (2) a diff that meets
#   §7's own BEHAVIORAL trigger (alters another harness's actual behavior/gate-outcome/interaction
#   contract — not merely a file-class match) gets a standpoint-axis pass, recorded on the closed
#   tier1/tier2/tier2b/tier3/not-applicable/DEGRADED_* enum, before a PR opens (or folded into the
#   held signal, if both checkpoints fire). Most ordinary digest-driven self-improvement will
#   correctly land on `not-applicable` — that is the expected common case, not a shortfall.
# SAFETY RAILS (why each exists) — hardened by fh-meta:challenger 2026-08-15 [S×2 fixed]:
#   ① git status must be clean before Stage 2 starts. A shared checkout may have another session's
#      in-progress uncommitted work — Stage 2 must never commit, stash, or otherwise touch state
#      it did not create. Dirty tree → skip, log why, leave everything untouched.
#   ② skip if a LIVE PEER SESSION CLAIM exists at all (branch_claim.sh show), not just if the tree
#      is dirty. FIXED 2026-08-15: an earlier revision's header claimed branch_claim.sh protection
#      but never actually called it — a human could have a clean-but-mid-thought tree (branch
#      switched, nothing edited yet) and this script would have force-checked-out their branch out
#      from under them in the EXIT trap with zero warning (challenger [S], confirmed real: the
#      45-min Stage 2 window has no lock held the whole time — this check narrows, does not close,
#      that TOCTOU; a peer session starting mid-run is a named residual, not fully closed). Any
#      live peer at entry → skip Stage 2 entirely, log it, touch nothing.
#   ③ skip if an autopilot PR is already open (branch prefix `auto/digest-improve-`) — one at a
#      time, so a quiet week of "nothing concrete" backlog does not pile into an open-PR queue the
#      operator has to triage. FIXED 2026-08-15: an earlier revision used
#      `gh pr list --search 'head:auto/digest-improve-'` — GitHub's `head:` search qualifier is an
#      EXACT branch-name match, not a prefix match, against branches that are actually named
#      `auto/digest-improve-<full-date>` — the check would almost always find nothing and silently
#      let PRs pile up unbounded (challenger [S], confirmed: verified via a live gh pr list --json
#      call against this repo, see verify_next in edit_manifest.yaml). Fixed to filter headRefName
#      client-side with jq's startswith(), which cannot have this exact-vs-prefix mismatch.
#   ④ working tree is restored to the pre-run branch on exit (trap) ONLY IF still no live peer
#      claim differs from where we started — re-checked at exit, not just at entry, because rail ②
#      only guards the START of the window. If a peer claim appeared during the run, the trap logs
#      a warning and leaves the tree where Stage 2 left it rather than yanking a now-live session's
#      ground (mirrors branch_claim.sh's own printed guidance: "먼저 한 줄 알려라" — an unattended
#      script cannot tell them first, so the fail-safe direction is: don't act, not: act anyway).
#   ⑤ Stage 2 runs with --permission-mode bypassPermissions (no human present to answer a Bash
#      approval prompt — acceptEdits, used by Stage 1, only covers Write/Edit, not git/gh). The
#      actual floor is NOT this permission mode — it is the git hooks (pre-commit 4-axis gate,
#      pre-push main-block, pre-push force-push block), which fire regardless of CC's own
#      permission layer, plus merge being structurally impossible (this script and its prompt never
#      invoke `gh pr merge`). NAMED RESIDUAL (challenger [S], not mitigated in v1 — accepted, not
#      silently assumed covered): bypassPermissions removes CC's own approval layer for
#      EVERYTHING, not just git in this repo — nothing here technically stops the subprocess from
#      touching files elsewhere under this OS user (~/.ssh, other repos, arbitrary rm) or making
#      outbound network calls beyond the git hooks' scope. The prompt instructs it not to; that is
#      an instruction, not an enforcement boundary. Accepted for v1 because Stage 2 only fires after
#      rails ①–③ pass and the blast radius is bounded by what a headless single-purpose prompt
#      would plausibly do, not by a technical sandbox — revisit if this is ever wired to a more
#      capability-rich prompt.
#   ⑥ NAMED RESIDUAL — prompt injection via digest content (challenger [S], unmitigated): the
#      digest ingests HN/arXiv content verbatim, and Stage 2 reads that digest under
#      bypassPermissions with git-push/PR-create ability. Adversarial text embedded in fetched
#      content could in principle steer the unattended session toward a misleading PR. No
#      sanitization pass exists. Mitigant in practice: the PR is proposal-only (never merges
#      itself) and still has to pass a real 4-axis gate with real challenger evidence — but that
#      gate is text-based judgment, not a hard technical filter against this class.
#   ⑦ NAMED RESIDUAL — log/secret exposure (challenger [A]): stdout+stderr of the Stage 2 claude
#      process is captured verbatim into tracks/_meta/logs/, which a Stop hook may sync to a private
#      companion store unattended, if one is configured. Any secret the agent happens to touch
#      during the run propagates into a second store with no redaction pass. Accepted for v1 (same
#      log-capture pattern as
#      Stage 1's frontier_digest_daily.sh, already running this way since 2026-06) — revisit if
#      Stage 2 is ever given credentials Stage 1 never touched.
#
# WHAT THIS DOES NOT DO: pick a "topic of the day" to force a contribution, retry on a NOT-CONVERGED
# outcome, touch anything if Stage 1 (digest) itself failed today, or act while any live peer
# session is claimed in this checkout.

FH_DIR="${FD_FH_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CLAUDE_BIN="${FD_CLAUDE_BIN:-$(command -v claude || echo "${HOME}/.local/bin/claude")}"
TODAY=$(date +%Y_%m_%d)
HUMAN_DATE=$(date +%Y-%m-%d)
LOG_DIR="${FH_DIR}/tracks/_meta/logs"
LOG_FILE="${LOG_DIR}/frontier_digest_autopilot_${TODAY}.log"
mkdir -p "$LOG_DIR"
_log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# ── Stage 1: unchanged digest run ───────────────────────────────────────────
bash "${FH_DIR}/scripts/frontier_digest_daily.sh"
DIGEST_EXIT=$?
if [ "$DIGEST_EXIT" -ne 0 ]; then
  _log "Stage 1 (digest) failed (exit ${DIGEST_EXIT}) — Stage 2 skipped, nothing to act on."
  exit "$DIGEST_EXIT"
fi
_log "Stage 1 (digest) OK for ${HUMAN_DATE}."

cd "$FH_DIR" || { _log "cannot cd to \$FH_DIR ($FH_DIR)"; exit 1; }

# ── Stage 2 preconditions (rails ① ② ③) ─────────────────────────────────────
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  _log "Stage 2 SKIPPED: working tree is dirty (another session's uncommitted work may be live) — never touching it unattended."
  exit 0
fi

# rail ②: any LIVE peer claim at all → skip. branch_claim.sh's own "show" lists each recorded
# claim with a live/dead tag (dead = the recording session's PID no longer exists). We do not try
# to be clever about "does the peer's branch differ from ours" here — any live peer means a human
# is plausibly mid-thought in this exact checkout right now, full stop.
if [ -x "${FH_DIR}/scripts/branch_claim.sh" ]; then
  if bash "${FH_DIR}/scripts/branch_claim.sh" show 2>/dev/null | grep -q '(live)'; then
    _log "Stage 2 SKIPPED: a live peer session claim exists in this checkout — not touching HEAD/committing while a human may be mid-thought here. Will try again on the next scheduled run."
    exit 0
  fi
else
  _log "Stage 2 SKIPPED: scripts/branch_claim.sh not found or not executable — cannot verify no live peer session, so refusing to touch the shared checkout unattended."
  exit 0
fi

# rail ③: fixed 2026-08-15 — `gh pr list --search 'head:...'` is an EXACT-match qualifier, not a
# prefix match, so it silently never matched our date-suffixed branch names (challenger [S]).
# Filter client-side instead: list open PRs' head branch names, test the prefix ourselves.
if ! command -v gh >/dev/null 2>&1; then
  _log "Stage 2 SKIPPED: gh CLI not found — cannot check for an existing open autopilot PR, and cannot open one."
  exit 0
fi
OPEN_AUTO_COUNT="$(gh pr list --state open --json headRefName \
  -q '[.[] | select(.headRefName | startswith("auto/digest-improve-"))] | length' 2>/dev/null)"
case "$OPEN_AUTO_COUNT" in
  ''|*[!0-9]*)
    _log "Stage 2 SKIPPED: could not measure open-autopilot-PR count (gh call failed/unparseable) — not measurable is not the same as zero, refusing to risk piling up a PR unseen."
    exit 0
    ;;
  0) ;; # clear to proceed
  *)
    _log "Stage 2 SKIPPED: ${OPEN_AUTO_COUNT} autopilot PR(s) already open (branch prefix auto/digest-improve-) — one at a time, operator has not triaged it yet."
    exit 0
    ;;
esac

ORIG_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo main)"
# rail ④: re-check for a live peer at exit time too — a peer starting mid-run must not get its
# ground yanked by our restorative checkout. This narrows, not closes, the TOCTOU window (see
# header rail ② note) — a peer appearing in the few seconds between this check and the actual
# `git checkout` call below is a residual, not claimed as fully closed.
_fh_autopilot_exit_trap() {
  if [ -x "${FH_DIR}/scripts/branch_claim.sh" ] \
     && bash "${FH_DIR}/scripts/branch_claim.sh" show 2>/dev/null | grep -q '(live)'; then
    _log "EXIT: a live peer session claim appeared during this run — leaving the tree as Stage 2 left it, NOT force-checking-out ${ORIG_BRANCH} (would yank a now-live session's ground)."
  else
    _log "EXIT: restoring working tree to ${ORIG_BRANCH}"
    git checkout --quiet "$ORIG_BRANCH" 2>/dev/null
  fi
}
trap _fh_autopilot_exit_trap EXIT

ATTEMPT_TIMEOUT_SECS="${FD_AUTOPILOT_TIMEOUT_SECS:-2700}"

# bash 3.2 (macOS default, confirmed this machine) has a known parser bug: a heredoc directly
# inside a `$(...)` command substitution mis-tracks quote balance once the heredoc BODY contains an
# unescaped apostrophe (e.g. "Today's") — `bash -n` fails with "unexpected EOF while looking for
# matching `'". Writing the heredoc to a plain file first, then capturing that file's content via
# `$(cat ...)` (a command substitution with NO heredoc inside it), sidesteps the bug entirely.
PROMPT_FILE="${LOG_DIR}/.autopilot_prompt_${TODAY}.txt"
cat > "$PROMPT_FILE" <<PROMPT_EOF
[automated-run: launchd, unattended — no human present to answer prompts] Today's frontier digest just landed at tracks/_meta/frontier_digest_${TODAY}.md (or the companion-store mirror if this node is not the digest runner). Run the digest -> persona-innovator (Mode F, full: internal gap scan + external frontier) -> harvest-loop pipeline against it, exactly as documented in CLAUDE.md and the relevant SKILL.md files - do not shortcut the 4-axis gate (edit-manifest entry, a real fh-meta:challenger adversarial pass with actual evidence, not a fabricated marker).

Threshold (operator's explicit choice, 2026-08-15): only act if a CONCRETE, well-scoped candidate survives harvest-loop and actually passes the 4-axis gate as a real committable diff. If nothing concrete surfaces today, do nothing further - do not manufacture a change to have shipped something. A quiet day is a correct outcome, not a failure.

BACK-END CHECKPOINTS (operator instruction, 2026-08-15 - required steps on this pipeline's shipping stage, not suggestions; this is the "뒷단 출하전 = 4축검증 + 하네스오너 리뷰" doctrine, applied to an unattended run):

1. IRREVERSIBILITY CHECK: does the gate-passing diff touch an IRREVERSIBLE surface per CLAUDE.md's Irreversibility Gates section (a publish/delete/history-rewrite path) OR a load-bearing surface per the Field-Harness Load-Bearing Change Gate (a verdict/gate enum or exit code, an irreversible-op path, or a safety invariant such as a floor, verdict-binding, or a pre-push/pre-commit hook)? This includes changes to the git hooks themselves (templates/.git-hooks/*), scripts a hook calls, or anything in the Irreversibility Gates / Destructive-Op Gate / Pre-Publish Gate sections of CLAUDE.md.
   - If YES: do NOT run gh pr create at all. Create the branch, commit, push it (so the work is not lost), write a signal file at tracks/_meta/fh_signal_${HUMAN_DATE}_autopilot-irreversible-hold.md with frontmatter 'status: NEEDS-OWNER-REVIEW' naming the branch, exactly which surface it touches and why, and what the change does - then stop. No PR exists yet; the operator decides whether one should even be opened.

2. STANDPOINT AXIS (knowledge/shared/harness-core/field_verdict_crossfamily_gate.md §7 - read it before applying this step, this summary is not the full spec): does the diff alter ANOTHER harness's actual behavior, gate outcome, or interaction contract (not merely touch a path that happens to be synced elsewhere - the trigger is behavioral, not file-class)? Most ordinary FH self-improvement from a digest signal will correctly land on standpoint: not-applicable - that is a correct, expected answer, not a shortfall to fix. This is a genuinely different axis from "harness-owner reviewing FH's own conventions" - it means an agent actually running the diff's effect FROM the standpoint of the OTHER harness's own repo (family diversity alone does not catch this: the mechanism behind the if(kakao)26 keynote's p15 slide "(c) 탈상관의 확장" - "계열을 늘려도 못 잡는 결함이 있습니다, 입장을 바꾸면 보입니다" - §7 is built on three field incidents where full cross-family review missed a defect that only one execution-from-the-target's-own-repo caught).
   - If NOT applicable (the common case): record standpoint: not-applicable in the marker/signal, state briefly what was checked (per the spec's own discipline - asserting non-applicability without naming what was checked is indistinguishable from not having looked at all), and move on.
   - If applicable: check whether a local clone of the target harness exists on this machine (e.g. under the parent of ${FH_DIR} - sibling directories like pmh-dev, qasp-dev, or similar). If one exists, run the change against THAT repo's own content/rules from its own standpoint (tier2) - this must happen BEFORE any push or gh pr create for THIS diff, same non-negotiable pre-push timing as the irreversibility check above and for the identical reason (PR #370, 2026-08-14: a post-PR standpoint review still caught 2 residency leaks that had already sat in public view before the fix - public exposure is effectively irreversible, so this cannot run after the diff is visible). If it finds anything, fix it in the local diff and re-run until clean - only then push and open the PR (or, if step 1 already routed to hold, fold the finding into that signal file instead). If no local clone of the target harness is reachable, record standpoint: DEGRADED_NO_TARGET_ACCESS (could not, not did not) and proceed - do not block indefinitely on a target you structurally cannot reach, but do not silently claim not-applicable either when it actually is applicable and merely unreachable.
   Do NOT conflate this with fh-meta:challenger (family/adversarial-correctness axis, already required by the 4-axis gate above) or with fh-meta:hub-cc-pr-reviewer (checks FH's own diff against FH's OWN baseline conventions - a same-repo self-consistency check, not a standpoint-axis review at all). All three are different lenses; running one is not a substitute for another.

3. If the diff is neither irreversible/load-bearing (step 1: NO) nor standpoint-applicable (step 2: NO or DEGRADED) - the common case, ordinary small reversible self-improvement: skip straight to branch/commit/push/PR below.

In every case that reaches a PR: create branch auto/digest-improve-${HUMAN_DATE}, commit there, push it, open with gh pr create --fill, noting in the PR body which digest item motivated it. Never commit to main (the pre-push hook enforces this regardless). Do NOT run gh pr merge under any circumstances - merge is always the operator's decision. Do NOT push to main directly. Do NOT force-push. Do NOT touch any file outside what this specific candidate change requires.

If you are blocked (git status was unexpectedly dirty, gh auth failed, the gate genuinely cannot converge in one pass), stop and log why - do not retry, do not fall back to a weaker gate, do not touch main.
PROMPT_EOF

PROMPT="$(cat "$PROMPT_FILE")"
rm -f "$PROMPT_FILE"

_log "Stage 2 starting (timeout ${ATTEMPT_TIMEOUT_SECS}s)"
"$CLAUDE_BIN" -p --permission-mode bypassPermissions "$PROMPT" >> "$LOG_FILE" 2>&1 &
CLAUDE_PID=$!
DEADLINE=$((SECONDS + ATTEMPT_TIMEOUT_SECS))
while kill -0 "$CLAUDE_PID" 2>/dev/null && [ "$SECONDS" -lt "$DEADLINE" ]; do
  sleep 30 & wait $!
done
if kill -0 "$CLAUDE_PID" 2>/dev/null; then
  pkill -P "$CLAUDE_PID" 2>/dev/null
  kill "$CLAUDE_PID" 2>/dev/null
  wait "$CLAUDE_PID" 2>/dev/null
  _log "Stage 2 killed by watchdog (${ATTEMPT_TIMEOUT_SECS}s) — no retry (this is not the digest's hard-realtime path)."
else
  wait "$CLAUDE_PID"
  _log "Stage 2 finished (exit $?)."
fi

exit 0
