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

FH="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TODAY=$(date +%Y-%m-%d)
CARD="$FH/tracks/_meta/reference_next_session_starter.md"
FAIL=0

_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

echo "── session close check: $FH ($TODAY) ──"

# ① status snapshot — uncommitted / unpushed work must be known, not forgotten
DIRTY=$(git -C "$FH" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
UNPUSHED=$(git -C "$FH" log --oneline @{u}.. 2>/dev/null | wc -l | tr -d ' ')
[ "$DIRTY" -gt 0 ] && echo "⚠️  ① $DIRTY uncommitted path(s) — decide: commit or leave deliberately"
[ "$UNPUSHED" -gt 0 ] && echo "⚠️  ① $UNPUSHED unpushed commit(s) — push before close or record why"
[ "$DIRTY" -eq 0 ] && [ "$UNPUSHED" -eq 0 ] && echo "✅ ① working tree clean, nothing unpushed"

# ①-b open-PR sweep (surface-not-auto — requires gh; skip silently offline)
if command -v gh >/dev/null 2>&1; then
  # `gh --json` emits COMPACT single-line JSON when piped, so counting LINES returned 1 for ANY
  # non-zero number of open PRs — the sweep hid every PR after the first, in the exact step CLAUDE.md
  # pairs with count consistency. Count OCCURRENCES instead. Measured 2026-08-02 with a known pair:
  # `[{"number":227},{"number":226},{"number":225}]` → old 1, new 3; `[]` → 0 both ways — which is
  # why an environment with zero open PRs can never surface this, and why the 0-case alone is not a
  # calibration. Observed live the same day: 2 open PRs reported as 1.
  PRS=$(gh pr list --author "@me" --state open --json number 2>/dev/null | grep -o '"number"' | wc -l | tr -d ' ' || true)
  [ "${PRS:-0}" -gt 0 ] && echo "⚠️  ①-b $PRS open PR(s) by you — classify: self-mergeable vs awaiting-external"
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

# ④ real-time completion log — required whenever any commit landed today
COMMITS_TODAY=$(git -C "$FH" log --since="today 00:00" --oneline 2>/dev/null | wc -l | tr -d ' ')
FC="$FH/tracks/_meta/fh_completed_${TODAY}.md"
if [ "$COMMITS_TODAY" -gt 0 ] && [ ! -f "$FC" ]; then
  echo "❌ ④ commits landed today but tracks/_meta/fh_completed_${TODAY}.md is missing"
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

echo "── close check: $([ "$FAIL" -eq 0 ] && echo CONSISTENT || echo VIOLATIONS) ──"
exit "$FAIL"
