#!/usr/bin/env bash
# regression_guard.sh — verifies SKILL.md / .claude/rules changes preserve operational content.
#
# Usage:
#   bash templates/regression_guard.sh [BASE_REF]
#   bash templates/regression_guard.sh main                    # compare working tree vs main
#   bash templates/regression_guard.sh origin/main HEAD        # compare HEAD vs origin/main
#   bash templates/regression_guard.sh --pr BRANCH             # PR mode: auto merge-base (recommended)
#   bash templates/regression_guard.sh --staged                # pre-commit: staged index vs HEAD
#   bash templates/regression_guard.sh --verbose --staged      # include suppression reasons
#
# Exit codes: 0=PASS **또는 SKIP** / 1=S-tier warnings / 2=M-tier block / 3=usage error
#
# ⚠️ exit 0 은 두 의미를 갖는다 — 검사해서 통과(PASS)와 **검사 대상이 없었음(SKIP)**.
#    구분하려면 stdout 의 `REGRESSION_GUARD_RESULT=skip` 을 보라. 종료코드만 보는 호출자는
#    미검사를 통과로 읽는다(2026-07-22: pre-commit 이 정확히 그랬고, AGENTS.md 변경이
#    그 경로로 '✅ PASS' 를 받고 지나갔다).
#    배선 현황: pre-commit ✅ / harness-doctor · harvest-loop · hub-cc-pr-reviewer ·
#    self_evolution_routine = **미배선(종료코드만 판정)** — 알려진 잔여.
#
# PR mode rationale: using 'main' as BASE_REF for a PR branch includes changes from OTHER
# merged PRs as false positives. --pr computes the fork-point (merge-base) automatically,
# so only THIS branch's own changes are evaluated.
#
# Called by:
#   - harness-doctor Step 10 (Regression Guard)
#   - harvest-loop Step 4 (harness-doctor invocation)
#   - CLAUDE.md §3-axis auto-gate (Axis 1) — use --pr mode for PRs
#   - manual pre-merge gate
#
# Self-test note: when editing this guard, verify in a disposable git repo that (1) a trigger
# heading rename, (2) a SKILL.md → SKILL_detail.md section/code/token move, and (3) a short
# deprecation tombstone do not M-block, while a real Done When deletion still exits 2.

set -u

STAGED_MODE=0
VERBOSE=0

ARGS=()
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--verbose" ]; then
    VERBOSE=1
    shift
    continue
  fi
  ARGS[${#ARGS[@]}]="$1"
  shift
done
# bash 3.2 (macOS default /bin/bash) treats "${empty_array[@]}" as unbound under `set -u` and
# aborts — a bare `bash regression_guard.sh` (no flags, ARGS stays empty) crashed here before this
# guard (cross-family self-test, 2026-07-07). Only reset the positional params when ARGS is non-empty.
[ "${#ARGS[@]}" -gt 0 ] && set -- "${ARGS[@]}"

verbose() {
  [ "$VERBOSE" -eq 1 ] && echo "  [verbose] $*"
}

# --pr mode: compute merge-base automatically
if [ "${1:-}" = "--pr" ]; then
  if [ -z "${2:-}" ]; then
    echo "Usage: regression_guard.sh --pr BRANCH" >&2
    exit 3
  fi
  PR_BRANCH="$2"
  BASE_BRANCH="${3:-main}"
  # Resolve each side to a ref that actually EXISTS in this checkout.
  #
  # WHY (measured 2026-08-17, 5 of 5 SAMPLED CI runs — not an exhaustive audit): a bare branch
  # NAME does not resolve in a GitHub Actions PR checkout. actions/checkout lands on a DETACHED
  # HEAD and creates refs/remotes/origin/*, not local branches — so `git merge-base main <branch>`
  # found neither side, returned empty, and this block exited 3. `fetch-depth: 0` was already set
  # and is NOT the cause; the history was present, the NAMES were not. The workflow then rendered
  # that instrument error as a green PASS (fixed in the same commit).
  #
  # 🟥 THE FIRST FIX FOR THIS INTRODUCED A WORSE HOLE, caught by cross-family review before it
  # shipped. It resolved `ref -> origin/ref -> refs/remotes/origin/ref` and fell back to HEAD.
  # `github.head_ref` is only a branch NAME, not owner-qualified, so a **fork PR whose branch is
  # named `main`** resolved the PR side to the BASE repo's `main` — merge-base(main, main) = main,
  # empty diff, SKIP, green. A guard silently comparing a branch to itself is worse than one that
  # errors. So: NO name-guessing and NO silent HEAD fallback. Callers pass something
  # unambiguous (a SHA, or an explicit `origin/<ref>`); anything that does not resolve EXACTLY
  # is an instrument error, and the workflow now fails closed on that.
  _rg_resolve_ref() { # $1 = ref-ish; echoes it iff it resolves EXACTLY as given (rc=1 otherwise)
    git rev-parse --verify --quiet "${1}^{commit}" >/dev/null 2>&1 && printf '%s' "$1"
  }
  _BASE_RESOLVED=$(_rg_resolve_ref "$BASE_BRANCH") || _BASE_RESOLVED=""
  _HEAD_RESOLVED=$(_rg_resolve_ref "$PR_BRANCH")  || _HEAD_RESOLVED=""
  if [ -z "$_BASE_RESOLVED" ] || [ -z "$_HEAD_RESOLVED" ]; then
    echo "ERROR: ref does not resolve — base='$BASE_BRANCH'->'${_BASE_RESOLVED:-<none>}' head='$PR_BRANCH'->'${_HEAD_RESOLVED:-<none>}'" >&2
    echo "       Pass an unambiguous ref (a SHA, or origin/<branch>). Guessing is how a fork PR" >&2
    echo "       branch named 'main' silently compared the base repo's main to itself." >&2
    exit 3
  fi
  BASE_REF=$(git merge-base "$_BASE_RESOLVED" "$_HEAD_RESOLVED" 2>/dev/null)
  if [ -z "$BASE_REF" ]; then
    echo "ERROR: cannot compute merge-base for $_HEAD_RESOLVED vs $_BASE_RESOLVED" >&2
    exit 3
  fi
  HEAD_REF="$_HEAD_RESOLVED"
  echo "PR MODE: merge-base=$(git rev-parse --short "$BASE_REF") base=$_BASE_RESOLVED head=$_HEAD_RESOLVED"
elif [ "${1:-}" = "--staged" ]; then
  # Pre-commit context: evaluate the staged index against HEAD. On a direct-to-main
  # workflow, --pr's merge-base(main,main)=HEAD yields an empty diff, so staged changes
  # — exactly what a pre-commit hook must check — are invisible. --staged compares the
  # index (what is about to be committed) against HEAD instead.
  STAGED_MODE=1
  BASE_REF="HEAD"
  HEAD_REF=""
  echo "STAGED MODE: index vs HEAD"
else
  BASE_REF="${1:-main}"
  HEAD_REF="${2:-}"   # empty = working tree
fi

# 게이트 커버 자산 = 4축 정본(.claude/rules/fh_4axis_gate.md §48)이 선언한 목록과 맞춘다.
# 2026-07-22 수리: AGENTS.md · knowledge/** · docs/*.md 가 여기 없어서, 정본이 "커버한다"고
# 선언한 자산을 Axis 1 이 **아예 보지 못했다**. 그리고 그 미검사가 호출부(pre-commit)에서
# `✅ PASS` 로 렌더됐다 = 검사 안 함이 통과로 보고되는 fail-open.
# 새 경로를 추가할 때는 반드시 fh_4axis_gate.md §48 과 대조할 것 — 두 목록이 갈리면
# 갈린 쪽이 조용히 무검사 구간이 된다.
# 2026-07-26 수리 (2차 — 이름 열거에서 디렉토리 스코프로): 처음엔 `SKILL_detail.md` 를 이름으로
# 추가했으나, Axis-2 적대 패스가 "이름을 하나씩 막는 방식은 원리적으로 이 클래스를 못 닫는다"고
# 지적했고 맞다. 그래서 scripts/gate_pathspec_check.sh 에 **열거 스윕**(plugins/*/skills/ 밑 실제
# .md 를 전부 세어 미커버를 찾는 검사)을 넣었더니 첫 실행에서 실물을 잡았다 —
# `dialogue-harvest/calibration_pair.md`(known-pair 캘리브레이션 코퍼스, 07-25 출하). 이름 목록엔
# 영영 안 올랐을 파일이다. 결론: 스킬 디렉토리의 **모든 .md** 를 덮는다. 새 동반파일 관례가
# 생겨도 자동 커버되고, 열거 스윕이 그걸 도입 시점에 확인한다.
#
# (1차 기록) SKILL_detail.md 가 여기 없어서 **양쪽 게이트 모두** 이 파일을 못 봤다.
# 원인은 리터럴이다 — 게이트는 `SKILL.md` 를 찾는데 `SKILL_detail.md` 라는 문자열엔 `SKILL.md` 가
# 들어있지 않다(밑줄이 끊는다). 실측: detail 17파일 208,710B = 스킬 명세 표면의 27.7%,
# 16/17 이 펜스 코드블록 보유. 실제 누출 2건(371c04f · e661931 — 둘 다 단일파일
# phantom-quench/SKILL_detail.md, 4축 0회). 이 구멍은 salience-splitter 가 상주층을 줄이려
# SKILL.md → SKILL_detail.md 로 컨텐츠를 옮길 때마다 **넓어졌다** — 다이어트가 진행될수록
# 커버리지가 줄어드는 구조였다(gate-locality).
GUARD_PATHSPEC=(
  'plugins/*/skills/*/*.md'
  '.claude/rules/*.md'
  'knowledge/shared/rules/*.md'
  'knowledge/*.md'
  'knowledge/*/*.md'
  'knowledge/*/*/*.md'
  'CLAUDE.md'
  'AGENTS.md'
  'docs/*.md'
  'templates/*.md'
  # ── Added 2026-08-04 — the pathspec had drifted from the 4-axis ASSET LIST it exists to gate.
  # Measured that day by mechanically walking every asset class in CLAUDE.md §FH Improvement
  # 4-Axis against this array: four classes had NO covering pattern, and two of them are this
  # repo's own mechanical floor — `templates/.git-hooks/*` (the hook that hard-blocks commits)
  # and `templates/*.sh` (THIS FILE — the guard could not guard itself). The pre-commit HEAVY
  # classifier already listed `^scripts/.*\.sh$`, so a scripts-only change entered the heavy
  # path and then met Axis 1 returning `SKIP (not-checked, NOT a pass)`. Observed three times
  # on 2026-08-04 alone, the third being the S5 fix (PR #253) — a change to a verdict-surface
  # scanner that shipped with zero Axis-1 coverage.
  #
  # Calibrated before shipping, both directions (a widened copy, run against real history):
  #   · 12 consecutive historical commits touching scripts/*.sh → M=0 S=0 (no FP storm), and a
  #     control confirmed the files were actually SELECTED (4 files checked) rather than the
  #     zero coming from an inert pathspec — the unwired-instrument reading of a clean 0.
  #   · known-positive: truncating a shipped .sh by 60% → M-TIER BLOCK (`BLOCK` token dropped
  #     100%, 60% line reduction). The md-shaped checks (F1 frontmatter, F2 sections, F3 fences)
  #     are inert on shell files; F4 keyword / F5 xref / F6 line-loss / F7 syntax are the ones
  #     that carry, and they are exactly the regressions that matter in a gate script.
  # NOTE on globbing: git pathspec `*` crosses `/` (verified here — `templates/*.md` matches
  # `templates/.claude/rules/session.md`), so these single-star forms are recursive.
  'scripts/*.sh'
  'templates/*.sh'
  'templates/.git-hooks/*'
  'plugins/*/agents/*.md'
  '.claude/agents/*.md'
  # ── Added 2026-08-29 — 세 번의 SKIP 을 추적해 보니 «진짜 갭 1 · 계기 오용 2» 였다.
  # 계기 오용: `--pr` 는 커밋된 ref 를 비교하는데 커밋 «전에» 불렀다 → merge-base==HEAD → 빈 diff
  # → skip. (--staged 가 그 자리에 있는 이유이고, 위 --staged 주석이 이미 그렇게 적고 있었다.)
  # 진짜 갭: README 4종. 공개 첫 화면인데 Axis 1 이 구조적으로 안 돌았다 — PR #550 이 실물이다.
  # 같이 들어온 나머지는 4축 자산 목록과 이 배열을 기계로 대조해 나온 미커버분이다.
  # 캘리브레이션(양방향, 넓힌 사본으로 실제 이력에 실행):
  #   · 이력 20 커밋(README·CHEATSHEET·package.json 등을 건드린 것) → M=0 S=0, 전부 pass.
  #     오탐 폭풍 없음. 그리고 SKIP 이 아니라 pass 라는 것이 «파일이 실제로 선택됐다»의 컨트롤이다
  #     (무기력한 pathspec 에서 오는 깨끗한 0 을 배제한다 — 2026-08-04 항목과 같은 규율).
  #   · known-positive: README.md 를 60% 절단 → ❌ BLOCK (M-tier 2, 'BLOCK' 토큰 66% 소실, rc=2).
  # package.json 은 md/sh 형 검사 대부분이 무력하지만 F6 줄-감소가 살아 있다 — files[] 항목이
  # 대량 삭제되는 회귀가 이 저장소에서 실제로 있었던 클래스다.
  'README*.md'
  'CHEATSHEET.md'
  'CATALOG.md'
  '.github/workflows/*.yml'
  'scripts/*.py'
  '.claude/registry/*.md'
  'package.json'
)

# 계기 무결: base ref 가 안 풀리면 diff 실패가 2>/dev/null 로 삼켜져 CHANGED 공백 →
# `result=skip` 으로 세탁된다(challenger C-2 실측: no-such-ref → 확신형 skip + exit 0).
# shallow clone / detached CI 에서 실제로 나는 경로 — 계기 에러는 skip 이 아니라 error 다.
if [ "$STAGED_MODE" -ne 1 ]; then
  if ! git rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
    echo "REGRESSION_GUARD: base ref '$BASE_REF' does not resolve — instrument error, NOT a skip" >&2
    if [ -n "${REGRESSION_GUARD_RESULT_FILE:-}" ]; then
      printf 'result=error\nm_tier=0\ns_tier=0\nfiles_checked=0\n' > "$REGRESSION_GUARD_RESULT_FILE"
    fi
    exit 3
  fi
fi

# Discover changed files
if [ "$STAGED_MODE" -eq 1 ]; then
  CHANGED=$(git diff --cached --name-only -- "${GUARD_PATHSPEC[@]}" 2>/dev/null)
elif [ -z "$HEAD_REF" ]; then
  CHANGED=$(git diff --name-only "$BASE_REF" -- "${GUARD_PATHSPEC[@]}" 2>/dev/null)
else
  CHANGED=$(git diff --name-only "$BASE_REF" "$HEAD_REF" -- "${GUARD_PATHSPEC[@]}" 2>/dev/null)
fi

if [ -z "$CHANGED" ]; then
  # ★ SKIP 은 PASS 가 아니다. 이 스크립트는 exit 0 을 유지하지만(가역 표면 · 호출부 호환),
  #   **문구로 통과와 구분**한다 — 과거 호출부가 이 줄을 받고 `✅ PASS` 를 찍어
  #   "검사 안 함"이 "통과"로 보고됐다(2026-07-22 수리).
  echo "REGRESSION_GUARD: SKIP (not-checked, NOT a pass) — no file matched the gate pathspec"
  echo "REGRESSION_GUARD_RESULT=skip"
  if [ -n "${REGRESSION_GUARD_RESULT_FILE:-}" ]; then
    printf 'result=skip
m_tier=0
s_tier=0
files_checked=0
' > "$REGRESSION_GUARD_RESULT_FILE"
  fi
  exit 0
fi

M_TIER=0
S_TIER=0
echo "REGRESSION_GUARD vs $BASE_REF${HEAD_REF:+ ($HEAD_REF)}"
echo "Files changed: $(echo "$CHANGED" | wc -l | tr -d ' ')"
echo "----"

# ── deleted-file set, asked of git DIRECTLY (2026-08-22) ────────────────────────────────────
# This guard used to infer "deleted" from a FAILED READ (`read_after "$f" >/dev/null || continue`
# plus `[ -z "$(read_after "$f")" ] && continue`). That is the absence-assertion idiom this repo
# keeps closing: three different states — *deleted* (intentional), *emptied to 0 bytes* (the
# strongest possible content loss), and *unreadable* (instrument error) — were folded into ONE
# branch, and the folded direction was PASS.
#
# Measured 2026-08-22 in a disposable repo, `--staged`, one variable at a time:
#   CONTROL   harmless addition to a SKILL.md      rc=0  M-tier 0  ✅ PASS
#   POSITIVE  its `## Done When` section deleted   rc=2  M-tier 2  ❌ BLOCK   (instrument discriminates)
#   🟥        the SAME file truncated to 0 bytes   rc=0  M-tier 0  ✅ PASS    (everything lost, green)
# CLAUDE.md classifies a skill with no `Done When` as harness-doctor L2 M-tier; a skill with
# NOTHING passed.
#
# The prescription is not new — it is this file's OWN header (lines 12-19): exit 0 means PASS *or*
# not-checked, and the two are separated by a typed channel, never by silence. Line 263 was
# violating the contract printed at the top of the file it lives in.
#
# So deletion is now decided by `--diff-filter=D` — git's own answer to "was this deleted?" — and
# the other two states get their own verdicts. The original comment's intent is preserved exactly:
# a real deletion is still skipped, because a real deletion is still intentional.
if [ "$STAGED_MODE" -eq 1 ]; then
  DELETED=$(git diff --cached --name-only --diff-filter=D -- "${GUARD_PATHSPEC[@]}" 2>/dev/null)
elif [ -z "$HEAD_REF" ]; then
  DELETED=$(git diff --name-only --diff-filter=D "$BASE_REF" -- "${GUARD_PATHSPEC[@]}" 2>/dev/null)
else
  DELETED=$(git diff --name-only --diff-filter=D "$BASE_REF" "$HEAD_REF" -- "${GUARD_PATHSPEC[@]}" 2>/dev/null)
fi
# Empty-input behaviour, asked explicitly rather than inherited: DELETED="" means "nothing was
# deleted", so is_deleted returns 1 for every path — no file is silently exempted by an empty set.
# The failure direction of a broken DELETED computation is therefore fail-CLOSED: real deletions
# stop matching, their after-side read fails, and they surface as loud instrument errors instead of
# quietly passing.
is_deleted() {
  [ -n "$DELETED" ] || return 1
  printf '%s\n' "$DELETED" | grep -qxF -- "$1"
}

read_before() { git show "$BASE_REF:$1" 2>/dev/null; }
read_after() {
  if [ "$STAGED_MODE" -eq 1 ]; then git show ":$1" 2>/dev/null   # staged blob from the index
  elif [ -z "$HEAD_REF" ]; then cat "$1" 2>/dev/null
  else git show "$HEAD_REF:$1" 2>/dev/null; fi
}
# Clean integer count — grep -c outputs "0" + exit 1 when no match, which collides with `|| echo 0`
count_in() {
  local n
  n=$(echo "$1" | grep -c "$2" 2>/dev/null) || true
  echo "${n:-0}"
}
count_regex_in() {
  local n
  n=$(printf '%s\n' "$1" | grep -cE "$2" 2>/dev/null) || true
  echo "${n:-0}"
}
count_exact_line_in() {
  printf '%s\n' "$1" | awk -v needle="$2" '$0 == needle { n++ } END { print n + 0 }'
}
# Extract a resolvable path token near a tombstone phrase and verify it exists on disk (repo root
# or the tombstone file's own directory). Closes a demonstrated bypass: a bare phrase like "merged
# into nothing" with no real target previously exempted F2/F3/F4/F6 on any <=80-line file, including
# a still-live asset with its Done When section gutted (cross-family audit 2026-07-07: agy static
# trace + Sonnet-pinned self-test both reproduced it independently). Requires an actual citation —
# backtick path, markdown-link target, or bare path with a known extension — not just the phrase.
resolve_tombstone_target() {
  local body="$1" src_file="$2" tok=""
  tok=$(printf '%s\n' "$body" | grep -oE '`[^`]+`' | head -1 | tr -d '`')
  if [ -z "$tok" ]; then
    tok=$(printf '%s\n' "$body" | grep -oE '\]\([^)]+\)' | head -1 | sed -E 's/^\]\(//; s/\)$//')
  fi
  if [ -z "$tok" ]; then
    tok=$(printf '%s\n' "$body" | grep -oE '[A-Za-z0-9_./-]+\.(md|sh|py|ts|js|json)' | head -1)
  fi
  [ -z "$tok" ] && return 1
  if [ -e "$tok" ] || [ -e "$(dirname "$src_file")/$tok" ]; then
    printf '%s\n' "$tok"
    return 0
  fi
  return 1
}

for f in $CHANGED; do
  # ① Deletion is intentional, not regression — and it is now git that says so (see is_deleted).
  if is_deleted "$f"; then
    verbose "skipped '$f': git reports it DELETED in this diff — intentional removal, not content loss"
    continue
  fi

  after_probe=$(read_after "$f"); read_rc=$?

  # ② Not deleted, yet unreadable → the instrument failed on this file. NOT a pass.
  if [ "$read_rc" -ne 0 ]; then
    echo
    echo "=== $f ==="
    echo "  ❌ M-TIER  instrument error: file is in the diff, git does NOT report it deleted, and its"
    echo "            after-side blob could not be read (rc=$read_rc). NOT CHECKED — an unchecked file"
    echo "            is not a passing file."
    M_TIER=$((M_TIER + 1))
    continue
  fi

  # ③ Not deleted, readable, and EMPTY. Split by direction so an over-block is not traded for the
  #    fail-open: content that existed and is now gone is the regression this guard is for; a file
  #    that was already empty is suspicious but is not a *loss*, so it warns instead of blocking.
  if [ -z "$after_probe" ]; then
    echo
    echo "=== $f ==="
    if [ -n "$(read_before "$f")" ]; then
      echo "  ❌ M-TIER  emptied: after-side content is 0 bytes while the before side had content."
      echo "            Total content loss is the strongest regression this guard exists to catch."
      echo "            If removal is the intent, DELETE the file — a real deletion is skipped."
      M_TIER=$((M_TIER + 1))
    else
      echo "  ⚠️  S-TIER  empty file in a gated path (before side was empty/absent too) — not content"
      echo "            loss, so it does not block, but an empty gated asset is rarely intended."
      S_TIER=$((S_TIER + 1))
    fi
    continue
  fi

  echo
  echo "=== $f ==="

  # F1. Frontmatter integrity — SKILL.md ONLY, deliberately.
  # `name:`/`description:` are the skill's ROUTING surface; a detail file is referenced, never
  # routed, so the contract does not apply to it. Before 2026-07-26 this exclusion was ACCIDENTAL
  # (detail files simply were not in the pathspec, and this regex never matched them); it is now
  # explicit. Observation, NOT gated: 16 of 17 detail files carry frontmatter anyway as convention —
  # the lone exception is phantom-quench/SKILL_detail.md. Gating that convention would M-TIER a
  # working file for a contract it does not owe, so it stays an observation.
  if echo "$f" | grep -qE "(^|/)SKILL\.md$"; then
    fm_check=$(read_after "$f" | python3 -c "
import sys
c = sys.stdin.read()
if not c.startswith('---'):
    print('FAIL: no frontmatter')
    sys.exit(1)
parts = c.split('---', 2)
if len(parts) < 3:
    print('FAIL: unclosed frontmatter')
    sys.exit(1)
fm = parts[1]
for req in ('name:', 'description:'):
    if req not in fm:
        print(f'FAIL: missing {req}')
        sys.exit(1)
print('OK')
" 2>&1)
    if echo "$fm_check" | grep -q FAIL; then
      echo "  ❌ M-TIER  frontmatter: $fm_check"
      M_TIER=$((M_TIER + 1))
    else
      echo "  ✅ frontmatter intact"
    fi
  fi

  before_content=$(read_before "$f")
  after_content=$(read_after "$f")
  # Sibling lookup — content that MOVED between the pair is not content LOST.
  # Must be SYMMETRIC (2026-07-26): before this file was gated, only SKILL.md was ever the checked
  # file, so a one-way lookup (SKILL.md → its detail) sufficed. Now that SKILL_detail.md is gated
  # too, the reverse consolidation (detail → SKILL.md, e.g. un-splitting a skill) would otherwise
  # read as content loss in the detail file and fire a false positive on exactly the refactor
  # salience-splitter is designed to reverse.
  detail_content=""
  case "$f" in
    */SKILL.md)        detail_content=$(read_after "$(dirname "$f")/SKILL_detail.md") ;;
    */SKILL_detail.md) detail_content=$(read_after "$(dirname "$f")/SKILL.md") ;;
  esac

  # Deprecation/tombstone exemption (stub-shaped): a file soft-deleted into a small pointer
  # stub. Content loss is the INTENT (mirrors the file-deletion skip above), so content-
  # preservation checks (F2 sections, F3 code blocks, F4 tokens, F6 line reduction) are skipped.
  # Structural-integrity checks a stub must STILL satisfy keep running: F1 frontmatter, F5 ref
  # resolution, F7 bash syntax.
  #
  # Guarded so it cannot be abused to gut a LIVE asset (Axis-2 challenger 2026-06-16):
  #   (a) frontmatter must start at line 1 AND be CLOSED — kills the `---` horizontal-rule
  #       collision in non-SKILL files (CLAUDE.md / rules have HRs but no real frontmatter, so
  #       a body line `deprecated: true` could otherwise self-exempt them);
  #   (b) `deprecated: true` in canonical YAML (one+ space) inside that block;
  #   (c) a non-empty `successor:` pointer (enforces what this comment promises — no dead-end stub);
  #   (d) the result is actually stub-sized (<= 50 lines) — a "deprecated" 200-line file is not a
  #       soft-delete and runs the full checks.
  # Tombstone-body mode additionally accepts <= 80-line files whose body says DEPRECATED,
  # renamed to, or merged into — BUT ONLY when the body also cites a target path that actually
  # resolves on disk (resolve_tombstone_target). A bare phrase with no real target does NOT
  # exempt: this was a demonstrated bypass (a still-live asset could drop its Done When section
  # and dodge M-tier detection just by adding "renamed to X" for a nonexistent X) caught by
  # cross-family review before merge (2026-07-07) — fixed by requiring the same auditable
  # short-pointer discipline the frontmatter path already enforces via `successor:`.
  # (We deliberately do NOT also require deprecated-in-BOTH-before+after: that would block the
  # common one-commit "deprecate + stub" flow with no safety gain once (a)-(d) hold — the residual
  # is a loud, reviewable, git-recoverable deprecation declaration, not silent content loss.)
  is_deprecated=0
  after_line_count=$(printf '%s\n' "$after_content" | wc -l | tr -d ' ')
  if [ "$(printf '%s\n' "$after_content" | head -1)" = "---" ]; then
    fm=$(printf '%s\n' "$after_content" | awk 'NR==1{next} /^---$/{exit} {print}')
    has_close=$(printf '%s\n' "$after_content" | awk 'NR==1{next} /^---$/{print "yes"; exit}')
    if [ "$has_close" = "yes" ] \
       && printf '%s\n' "$fm" | grep -qE '^deprecated:[[:space:]]+true[[:space:]]*$' \
       && printf '%s\n' "$fm" | grep -qE '^successor:[[:space:]]+[^[:space:]]' \
       && [ "$after_line_count" -le 50 ]; then
      is_deprecated=1
      echo "  ℹ️  deprecated stub — content-loss checks (F2/F3/F4/F6) exempted (F1/F5/F7 still enforced)"
      verbose "suppressed content-loss checks: frontmatter tombstone has deprecated:true, successor, and $after_line_count lines"
    fi
  fi
  if [ "$is_deprecated" -eq 0 ] \
     && [ "$after_line_count" -le 80 ] \
     && printf '%s\n' "$after_content" | grep -qiE 'DEPRECATED|renamed to|merged into'; then
    tombstone_target=$(resolve_tombstone_target "$after_content" "$f") || tombstone_target=""
    if [ -n "$tombstone_target" ]; then
      is_deprecated=1
      echo "  ℹ️  deprecation tombstone — content-loss checks (F2/F3/F4/F6) exempted (F1/F5/F7 still enforced); target: $tombstone_target"
      verbose "suppressed content-loss checks: tombstone body contains DEPRECATED/renamed to/merged into, resolvable target '$tombstone_target', and $after_line_count lines"
    else
      echo "  ⚠️  tombstone phrase found but no resolvable target path — content-loss checks NOT exempted (fail-closed; cite an existing path, e.g. \`plugins/x/y/SKILL.md\`, so this stub can be trusted)"
    fi
  fi

  check_section_group() {
    local label="$1"
    local pattern="$2"
    local before after detail combined
    before=$(count_regex_in "$before_content" "$pattern")
    after=$(count_regex_in "$after_content" "$pattern")
    detail=0
    [ -n "$detail_content" ] && detail=$(count_regex_in "$detail_content" "$pattern")
    combined=$((after + detail))
    if [ "$before" -gt 0 ] && [ "$combined" -lt "$before" ]; then
      echo "  ❌ M-TIER  '$label' section group dropped ($before → $combined)"
      M_TIER=$((M_TIER + 1))
    elif [ "$before" -gt 0 ] && [ "$after" -lt "$before" ]; then
      if [ "$detail" -gt 0 ]; then
        echo "  ℹ️  '$label' section moved to SKILL_detail.md ($before → $after + $detail in detail)"
        verbose "suppressed section loss: sibling SKILL_detail.md preserves '$label' section header count"
      else
        echo "  ℹ️  '$label' section heading renamed within known synonym group ($before → $after)"
        verbose "suppressed section loss: known synonym heading preserves '$label' section semantics"
      fi
    fi
  }

  explain_section_rename() {
    local group_label="$1"
    local group_pattern="$2"
    shift 2
    local group_before group_after group_detail group_combined name before after detail exact_pattern
    group_before=$(count_regex_in "$before_content" "$group_pattern")
    group_after=$(count_regex_in "$after_content" "$group_pattern")
    group_detail=0
    [ -n "$detail_content" ] && group_detail=$(count_regex_in "$detail_content" "$group_pattern")
    group_combined=$((group_after + group_detail))
    [ "$group_before" -gt 0 ] && [ "$group_combined" -ge "$group_before" ] || return
    for name in "$@"; do
      exact_pattern="^##[[:space:]]+$name([[:space:]].*)?$"
      before=$(count_regex_in "$before_content" "$exact_pattern")
      after=$(count_regex_in "$after_content" "$exact_pattern")
      detail=0
      [ -n "$detail_content" ] && detail=$(count_regex_in "$detail_content" "$exact_pattern")
      if [ "$before" -gt 0 ] && [ $((after + detail)) -lt "$before" ]; then
        verbose "suppressed dropped heading '$name': '$group_label' known-synonym group is preserved ($group_before → $group_combined)"
      fi
    done
  }

  # F2. Critical section preservation
  if [ "$is_deprecated" -eq 0 ]; then
    execution_pattern='^##[[:space:]]+(Execution Steps|Steps)([[:space:]].*)?$'
    done_when_pattern='^##[[:space:]]+(Done When|Completion Criteria)([[:space:]].*)?$'
    triggers_pattern='^##[[:space:]]+(Triggers|Trigger Phrases|Activation Triggers|Invocation Triggers|Natural Language Triggers)([[:space:]].*)?$'

    check_section_group "Execution Steps" "$execution_pattern"
    check_section_group "Done When" "$done_when_pattern"
    check_section_group "Triggers" "$triggers_pattern"

    explain_section_rename "Execution Steps" "$execution_pattern" "Execution Steps" "Steps"
    explain_section_rename "Done When" "$done_when_pattern" "Done When" "Completion Criteria"
    explain_section_rename "Triggers" "$triggers_pattern" "Triggers" "Trigger Phrases" "Activation Triggers" "Invocation Triggers" "Natural Language Triggers"

    if [ -n "$detail_content" ]; then
      printf '%s\n' "$before_content" | grep -E '^##[[:space:]]+' | sort -u | while IFS= read -r header; do
        [ -n "$header" ] || continue
        before=$(count_exact_line_in "$before_content" "$header")
        after=$(count_exact_line_in "$after_content" "$header")
        detail=$(count_exact_line_in "$detail_content" "$header")
        if [ "$before" -gt 0 ] && [ "$after" -lt "$before" ] && [ $((after + detail)) -ge "$before" ]; then
          verbose "suppressed section-header reduction: '$header' moved to sibling SKILL_detail.md"
        fi
      done
    fi
  fi

  # F3. Code block count
  if [ "$is_deprecated" -eq 0 ]; then
  before_code=$(count_in "$before_content" '^```')
  after_code=$(count_in "$after_content" '^```')
  detail_code=0
  [ -n "$detail_content" ] && detail_code=$(count_in "$detail_content" '^```')
  if [ "$before_code" -gt 0 ]; then
    combined_code=$((after_code + detail_code))
    delta=$((before_code - combined_code))
    if [ "$after_code" -lt "$before_code" ] && [ "$combined_code" -ge "$before_code" ]; then
      echo "  ℹ️  code blocks moved to SKILL_detail.md ($before_code → $after_code + $detail_code in detail)"
      verbose "suppressed code-block reduction: sibling SKILL_detail.md preserves fenced-block count"
    fi
    if [ "$delta" -gt 4 ]; then
      echo "  ⚠️  S-TIER  code blocks reduced ($before_code → $combined_code, -$delta)"
      S_TIER=$((S_TIER + 1))
    fi
  fi
  fi

  # F4. Operational keyword preservation
  # Split-awareness: a skill-splitter split moves content to the sibling
  # SKILL_detail.md — a token still present in SKILL.md + SKILL_detail.md combined
  # is a MOVE, not a loss. Only the combined shortfall is a regression signal.
  # NOTE: combined-count is a PRESENCE heuristic, not semantic equivalence — an
  # unrelated detail-file line can absorb the count. True equivalence is owned by
  # F2 (critical sections) + the Axis 2/3 review, not this counter.
  if [ "$is_deprecated" -eq 0 ]; then
  for token in "M-tier" "S-tier" "R-tier" "PASS" "BLOCK" "Wave 0" "Wave 1" "Wave 4" "Step 0" "Step 1" "Step 2" "Step 3" "Step 4" "fan-in" "Done When"; do
    before=$(count_in "$before_content" "$token")
    after=$(count_in "$after_content" "$token")
    if [ "$before" -gt 0 ] && [ "$after" -lt "$before" ]; then
      if [ -n "$detail_content" ]; then
        in_detail=$(count_in "$detail_content" "$token")
        if [ $((after + in_detail)) -ge "$before" ]; then
          echo "  ℹ️  token '$token' moved to SKILL_detail.md ($before → $after + $in_detail in detail)"
          verbose "suppressed token reduction: sibling SKILL_detail.md preserves '$token' count"
          continue
        fi
        after=$((after + in_detail))   # genuine combined shortfall → evaluate on combined count
      fi
      diff=$((before - after))
      ratio=$((diff * 100 / before))
      if [ "$ratio" -ge 50 ]; then
        echo "  ❌ M-TIER  token '$token' dropped ${ratio}% ($before → $after)"
        M_TIER=$((M_TIER + 1))
      elif [ "$ratio" -ge 20 ]; then
        echo "  ⚠️  S-TIER  token '$token' dropped ${ratio}% ($before → $after)"
        S_TIER=$((S_TIER + 1))
      fi
    fi
  done
  fi

  # F5. Cross-reference integrity (broken file paths)
  # Use process substitution to avoid subshell — M_TIER must update in parent shell
  # Skip placeholder patterns ending in `...` or `/...`
  while read -r ref; do
    [ -z "$ref" ] && continue
    echo "$ref" | grep -qE '/\.\.\.|^`\{FH_ROOT\}/\.\.\.' && continue
    path=$(echo "$ref" | sed "s|{FH_ROOT}|.|g" | tr -d '`')
    # Skip paths that still contain {placeholder} tokens after substitution (template files)
    echo "$path" | grep -qE '\{[^}]+\}' && continue
    if [ ! -e "$path" ]; then
      echo "  ❌ M-TIER  broken ref: $ref"
      M_TIER=$((M_TIER + 1))
    fi
  done < <(echo "$after_content" | grep -oE '`\{FH_ROOT\}/[^`]+`' | sort -u)

  # F7. Bash block syntax regression — per-block bash -n
  # bash -n stops at first error per file; split each ```bash block into its own file
  # so multiple errors are countable. Catches: new error added to a previously-clean block,
  # or a new bad block introduced.
  count_bad_blocks() {
    local content="$1"
    local tmpdir; tmpdir=$(mktemp -d)
    echo "$content" | awk -v d="$tmpdir" '
      /^```bash$/ { in_b=1; n++; out=d"/blk_"n".sh"; next }
      /^```$/ && in_b { in_b=0; next }
      in_b { print > out }
    '
    local bad=0
    for blk in "$tmpdir"/blk_*.sh; do
      [ -e "$blk" ] && [ -s "$blk" ] || continue
      bash -n "$blk" 2>/dev/null || bad=$((bad + 1))
    done
    rm -rf "$tmpdir"
    echo "$bad"
  }
  before_bash_err=$(count_bad_blocks "$before_content")
  after_bash_err=$(count_bad_blocks "$after_content")
  if [ "$after_bash_err" -gt "$before_bash_err" ]; then
    diff=$((after_bash_err - before_bash_err))
    echo "  ❌ M-TIER  bash blocks with syntax errors increased ($before_bash_err → $after_bash_err, +$diff)"
    M_TIER=$((M_TIER + 1))
  elif [ "$before_bash_err" -gt 0 ] && [ "$after_bash_err" = "$before_bash_err" ]; then
    echo "  ℹ️  pre-existing bash syntax errors: $before_bash_err block(s) (no change — separate fix)"
  fi

  # F6. Line reduction percentage
  before_lines=$(read_before "$f" | wc -l | tr -d ' ')
  after_lines=$(read_after "$f" | wc -l | tr -d ' ')
  if [ "$before_lines" -gt 0 ]; then
    if [ "$after_lines" -lt "$before_lines" ]; then
      delta=$((before_lines - after_lines))
      pct=$((delta * 100 / before_lines))
      if [ "$pct" -ge 30 ] && [ "$is_deprecated" -eq 0 ]; then
        echo "  ⚠️  S-TIER  reduced ${pct}% ($before_lines → $after_lines lines, -$delta)"
        S_TIER=$((S_TIER + 1))
      else
        echo "  ✅ -${delta} lines (-${pct}%, safe)"
      fi
    else
      echo "  ✅ ${after_lines} lines (+$((after_lines - before_lines)))"
    fi
  fi
done

echo
echo "===================="
echo "VERDICT"
echo "===================="
# ── carve-out 경로 강등 (2026-07-22, challenger HIGH-1) ──────────────────────
# knowledge/ · docs/ · AGENTS.md 는 **커버되어야 하지만 산문이 본체**다. 이 경로에
# 내용-손실 검사(토큰 카운트·섹션 그룹)를 그대로 걸면 동의어 교체 한 번에 M-tier 가
# 뜬다(실측: 산문 한 단어 교체 → 토큰 2→1, 50% 드롭 → 하드 블록).
# 과차단은 이론 비용이 아니다 — `--no-verify` 를 근육에 새기고, 그러면 **같은 훅의
# Destructive-Op 게이트까지 함께 무장해제**된다. 그래서 이 경로는 차단이 아니라 경고다.
# 호출부(pre-commit)의 CARVEOUT 분류기와 **같은 방향**이되, 여기서 substantive 판정을
# 재구현하지는 않는다 — 판정 로직을 두 벌 두면 관대함이 갈리고, 그게 이번 주에
# qasp 에서 고친 바로 그 결함 클래스다(divergent-leniency).
if [ "$M_TIER" -gt 0 ] && [ -n "$CHANGED" ]; then
  NON_CARVEOUT=$(printf '%s\n' "$CHANGED" \
    | grep -vE '(^knowledge/.*\.md$|^docs/.*\.md$|(^|/)AGENTS\.md$)' \
    | grep -vE '^\s*$' || true)
  if [ -z "$NON_CARVEOUT" ]; then
    echo "  ⚠️  carve-out 경로만 변경 — M-tier ${M_TIER}건을 S-tier 로 강등한다"
    echo "      (산문 자산에 내용-손실 검사를 하드 블록으로 걸면 과차단 → --no-verify 학습)"
    S_TIER=$((S_TIER + M_TIER))
    M_TIER=0
  fi
fi

echo "M-tier blockers: $M_TIER"
echo "S-tier warnings: $S_TIER"

# ── typed verdict 채널 (2026-07-23, #165 잔여 폐쇄) ──────────────────────────
# 종료코드는 다의적이고(0=pass|skip) stdout grep 은 prose-grep 채널이라 취약하다
# ([[feedback_typed_verdict_channel]]). REGRESSION_GUARD_RESULT_FILE 이 설정돼 있으면
# 기계 판독용 typed verdict 를 그 파일에 쓴다 — 소비자는 stdout 을 파싱할 필요가 없다.
# stdout 의 REGRESSION_GUARD_RESULT= 줄은 파일 채널 없는 소비자용 폴백(전 결과에 방출).
_emit_result() {  # $1=verdict
  echo "REGRESSION_GUARD_RESULT=$1"
  if [ -n "${REGRESSION_GUARD_RESULT_FILE:-}" ]; then
    printf 'result=%s
m_tier=%s
s_tier=%s
files_checked=%s
'       "$1" "$M_TIER" "$S_TIER" "$(printf '%s
' "$CHANGED" | grep -c . || true)"       > "$REGRESSION_GUARD_RESULT_FILE"
  fi
}

if [ "$M_TIER" -gt 0 ]; then
  echo "❌ BLOCK — fix M-tier issues before merge"
  _emit_result block
  exit 2
elif [ "$S_TIER" -gt 0 ]; then
  echo "⚠️  REVIEW — S-tier warnings present (merge allowed but verify intent)"
  _emit_result review
  exit 1
else
  echo "✅ PASS — safe to merge"
  _emit_result pass
  exit 0
fi
