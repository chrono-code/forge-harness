#!/usr/bin/env bash
# test_mapped_tracks_lanes.sh — regression anchor for mapped-track counting across WORKTREES.
#
# CLOSES: the mapped-harness signal is the PRESENCE of `tracks/<name>/`, which cannot reach a
# worktree (tracks/** is gitignored, and at least one mapped track is an EMPTY directory git could
# not carry regardless). Measured 2026-08-22: main = 11, worktree = 1 — and the synergy skill's
# Step 3-b closes `skipped(<2 mapped tracks)` as a MANDATORY-PASS value, so a worktree run went
# green while structurally blind, on the instrument that grades identity ④.
#
# HERMETIC: builds its own repo + worktree + tracks fixtures. Never reads the real hub.
#
# FIXTURES USE THE BREAKING SPELLINGS ON PURPOSE — an anchor that picks the easy spelling of the
# thing it guards does not guard it:
#   `the_bible`  — underscore in the MIDDLE. A `case *_*` filter eats it. That slip actually happened
#                  during the measurement and cost a re-measure; this fixture is why it cannot recur.
#   `pmh-dev`    — an EMPTY directory. It is the reason the signal cannot be committed at all, and a
#                  counter that skips empty dirs would silently under-report the real hub.
#   `_meta`      — LEADING underscore, the only thing that should be excluded.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # 픽스처는 실레포에 쓰지 않는다
cd "$(dirname "$0")/.." || exit 1
SUT="$(pwd -P)/scripts/mapped_tracks.sh"
PASS=0; FAIL=0
ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

# 🟥 종료코드는 selfcheck.sh 의 규약을 따른다 — 그 규약은 이미 있었고 초판이 그걸 안 따랐다:
#   0 = pass · 2 = 볼 때 주체가 없었다 · 10 = 이 스위트 자신의 setup 실패 · 126/127 = 앵커 실행 불가
#   selfcheck 는 2/10/126/127 을 "HARNESS ERROR … 측정 못 한 하네스는 통과한 게 아니다" 로 라벨하고
#   fail=1 을 세운다. 초판은 이 자리들에서 **exit 0** 을 냈고, 그래서 산문은 «not a pass» 라고
#   적혀 있는데 **기계는 pass 를 냈다** — 부재-단언 관용구가 레인 자신에게 난 형태다.
# ⚠️ 반대 방향 가드: 정상 통과 경로는 여전히 **exit 0** 이어야 한다. 모든 경로를 비영으로 만들면
#   그건 수리가 아니라 레인 사망이다(레인 P-4 가 그걸 지킨다).
[ -f "$SUT" ] || { echo "ⓘ mapped_tracks.sh absent — subject missing when we looked (NOT a pass)"; exit 2; }

TMP="$(fh_fixture_root "$(mktemp -d 2>/dev/null)")" || { echo "ⓘ mktemp failed — this suite's own setup broke (NOT a pass)"; exit 10; }
: "${TMP:?fixture root unset — refusing to run git in cwd}"
trap 'rm -rf "$TMP"' EXIT INT TERM

git init -q "$TMP/main" 2>/dev/null || { echo "ⓘ git init failed — this suite's own setup broke (NOT a pass)"; exit 10; }
git -C "$TMP/main" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null
git -C "$TMP/main" worktree add -q -b lanewt "$TMP/wt" 2>/dev/null \
  || { echo "ⓘ git worktree add failed — this suite's own setup broke (NOT a pass)"; exit 10; }

mkdir -p "$TMP/main/tracks/the_bible" "$TMP/main/tracks/pmh-dev" \
         "$TMP/main/tracks/qasp" "$TMP/main/tracks/_meta" "$TMP/main/tracks/_audit"
echo x > "$TMP/main/tracks/the_bible/a.md"
echo x > "$TMP/main/tracks/qasp/a.md"
# pmh-dev deliberately left EMPTY
echo x > "$TMP/main/tracks/_meta/m.md"
EXPECT=3   # the_bible + pmh-dev + qasp ; _meta and _audit excluded

# PREMISE — if the worktree can already see the fixtures, every verdict below is meaningless.
NAIVE_WT=0
for d in "$TMP/wt"/tracks/*/; do [ -d "$d" ] || continue; case "$(basename "$d")" in _*) continue;; esac; NAIVE_WT=$((NAIVE_WT+1)); done  # portability-noqa: the [ -d "$d" ] || continue guard is on this SAME line (right after 'do'), not the next 1-2 lines the P8 scanner checks
[ "$NAIVE_WT" -lt "$EXPECT" ] \
  && ok "premise: a naive cwd count from the worktree sees $NAIVE_WT of $EXPECT — the blindness is real here" \
  || ng "premise BROKEN: worktree already sees $NAIVE_WT — fixture does not reproduce the defect"

run_in() { ( cd "$1" 2>/dev/null && bash "$SUT" 2>&1 ); }

# M-1 / M-2: same answer from both standpoints.
OUT_MAIN=$(run_in "$TMP/main"); OUT_WT=$(run_in "$TMP/wt")
C_MAIN=$(printf '%s\n' "$OUT_MAIN" | sed -n 's/^count=//p')
C_WT=$(printf '%s\n'   "$OUT_WT"   | sed -n 's/^count=//p')
[ "$C_MAIN" = "$EXPECT" ] && ok "M-1 from MAIN tree → count=$C_MAIN" \
                          || ng "M-1 from MAIN tree → count=$C_MAIN, expected $EXPECT"
[ "$C_WT" = "$EXPECT" ]   && ok "M-2 from WORKTREE → count=$C_WT (blindness closed)" \
                          || ng "M-2 from WORKTREE → count=$C_WT, expected $EXPECT"

# M-3: the worktree says so, rather than passing off the main tree's number as its own.
case "$OUT_WT" in *in_worktree=yes*) ok "M-3 worktree run declares in_worktree=yes" ;;
                  *) ng "M-3 worktree run did not declare its standpoint" ;; esac
case "$OUT_MAIN" in *in_worktree=no*) ok "M-4 main-tree run declares in_worktree=no (control)" ;;
                    *) ng "M-4 main-tree run mislabelled its standpoint" ;; esac

# M-5: the breaking spellings are actually counted, not merely tolerated.
case "$OUT_WT" in *the_bible*) ok "M-5a mid-underscore track (the_bible) is counted" ;;
                  *) ng "M-5a the_bible dropped — the 'case *_*' slip has returned" ;; esac
case "$OUT_WT" in *pmh-dev*) ok "M-5b EMPTY track dir (pmh-dev) is counted" ;;
                  *) ng "M-5b empty track dir dropped — under-reports the real hub" ;; esac
case "$OUT_WT" in *_meta*) ng "M-5c leading-underscore meta dir leaked into the count" ;;
                  *) ok "M-5c leading-underscore meta dirs excluded (known-negative)" ;; esac

# M-6: not-found is not zero. THE point of the script.
OUT_OUT=$(cd /tmp && bash "$SUT" 2>&1); RC_OUT=$?
case "$OUT_OUT" in
  *UNMEASURED*) [ "$RC_OUT" = "3" ] && ok "M-6 outside a repo → UNMEASURED, exit 3 (never count=0)" \
                                    || ng "M-6 said UNMEASURED but exited $RC_OUT" ;;
  *count=0*) ng "M-6 RENDERED AN UNASKED QUESTION AS ZERO — the exact defect class" ;;
  *) ng "M-6 unexpected output: $OUT_OUT" ;;
esac

# M-7: --count-only stays machine-readable (it is what a caller greps).
CO=$(cd "$TMP/wt" && bash "$SUT" --count-only 2>&1)
[ "$CO" = "$EXPECT" ] && ok "M-7 --count-only prints a bare count ($CO)" \
                      || ng "M-7 --count-only printed '$CO'"

# ── 부재-단언 관용구: 「못 읽었다」가 「없다」로 접히나 (2026-08-23) ─────────────────
# 🟥 이 축이 초판 레인에 **아예 없었다.** known-negative 가 「레포 밖」 하나뿐이라 M-6 만 재고
# 있었고, 그래서 10/10 초록이면서 아래 결함이 살아 있었다 — 「컨트롤 있음 ≠ 판별력 있음」의 실물.
#
# 권한 조합 실측표 (2026-08-23, 이 레포 · macOS). `-r` 도 `-x` 도 단독으로는 부족하다:
#   chmod 755 → [-r]=r [-x]=x  글롭 항목수 1     ← 셀 수 있다
#   chmod 500 → [-r]=r [-x]=x  글롭 항목수 1     ← 셀 수 있다
#   chmod 111 → [-r]=-  [-x]=x  글롭 항목수 0     ← 🟥 `-x` 만 보면 통과시킨다
#   chmod 000 → [-r]=-  [-x]=-  글롭 항목수 0
# ⇒ `[ -r ] && [ -x ]` 가 «글롭이 셀 수 있는가» 와 네 케이스 전부에서 일치한다.
if [ "$(id -u)" = "0" ]; then
  echo "  ⓘ root 로 실행 중 — 권한 레인 UNMEASURED (root 는 퍼미션을 우회한다, 통과 아님)"
else
  PD="$(fh_fixture_root "$(mktemp -d)")"
  : "${PD:?fixture root unset — refusing to run git in cwd}"
  git init -q "$PD" 2>/dev/null
  git -C "$PD" -c user.email=t@t -c user.name=t commit -q --allow-empty -m i 2>/dev/null
  mkdir -p "$PD/tracks/qasp" "$PD/tracks/pmh"
  _perm_run() { ( cd "$PD" 2>/dev/null && bash "$SUT" 2>&1 ); }
  # 전제: 읽을 수 있을 때는 제대로 센다. 이게 아니면 아래 두 레인은 의미가 없다.
  chmod 755 "$PD/tracks"
  chk_c=$(_perm_run | sed -n 's/^count=//p')
  [ "$chk_c" = "2" ] && ok "P-0 전제: readable 일 때 count=2 (계기 판별력)"                      || ng "P-0 전제 BROKEN: readable 인데 count=$chk_c"
  # 🟥 본체: 못 읽는 디렉터리가 «없다» 로 렌더되면 안 된다.
  chmod 000 "$PD/tracks"; O000=$(_perm_run); chmod 755 "$PD/tracks"
  case "$O000" in
    *UNMEASURED*) ok "P-1 tracks/ 를 못 읽으면 UNMEASURED (count=0 아님)" ;;
    *count=0*)    ng "P-1 🔴 못 읽었는데 count=0 — 부재-단언 관용구" ;;
    *)            ng "P-1 예상 밖 출력: $(printf '%s' "$O000" | head -1)" ;;
  esac
  chmod 111 "$PD/tracks"; O111=$(_perm_run); chmod 755 "$PD/tracks"
  case "$O111" in
    *UNMEASURED*) ok "P-2 실행만 가능(111)해도 UNMEASURED — \`-x\` 단독 검사로는 못 잡는 자리" ;;
    *count=0*)    ng "P-2 🔴 111 에서 count=0 — 판별식이 -x 만 보고 있다" ;;
    *)            ng "P-2 예상 밖 출력: $(printf '%s' "$O111" | head -1)" ;;
  esac
  # 🟥 과차단 가드 — 「못 읽음」과 「진짜 0」은 갈려야 한다. 둘 다 막으면 수리가 아니라 회귀다.
  rm -rf "$PD/tracks/qasp" "$PD/tracks/pmh"
  OEMPTY=$(_perm_run); RCE=$?
  case "$OEMPTY" in
    *"status=OK"*count=0*) ok "P-3 과차단 가드: 진짜로 매핑 0개면 여전히 OK count=0 (UNMEASURED 아님)" ;;
    *) ng "P-3 회귀 — 진짜 0을 못 읽음으로 접었다: $(printf '%s' "$OEMPTY" | tr '\n' ' ')" ;;
  esac
  chmod -R 755 "$PD/tracks" 2>/dev/null; rm -rf "$PD"
fi

# 🟥 과차단 가드 — 위 수리가 «모든 경로를 비영으로» 만들지 않았는지. 정상 통과는 exit 0 이어야 한다.
#    이 레인이 없으면 「측정 못 함을 비영으로」 수리하다가 레인 자체를 죽여도 아무도 모른다.
#    🟥 재귀 가드 필수 — 이 레인은 자기 스위트를 다시 부른다. 가드가 없으면 중첩 실행이 다시
#    P-4 를 만나 **무한 재귀**한다(초판에서 실제로 그렇게 썼다가 바로 잡았다).
if [ -z "${MT_LANES_NESTED:-}" ]; then
  # 이 스크립트는 머리에서 레포 루트로 cd 한 상태다(21행). 상대경로가 그래서 성립한다.
  ( MT_LANES_NESTED=1 bash scripts/test_mapped_tracks_lanes.sh >/dev/null 2>&1 )
  _SELF_RC=$?
  [ "$_SELF_RC" = "0" ] && ok "P-4 과차단 가드: 정상 경로는 여전히 exit 0 ($_SELF_RC)" \
                        || ng "P-4 🔴 정상 경로가 exit $_SELF_RC — 레인 사망(수리가 아니라 회귀)"
fi

echo "──────────────────────────────────────────────"
# ── B-1 … B-5 — THE ONBOARDING BRANCH VERDICT ────────────────────────────────────────────────
# WHY THESE EXIST. The branch test has two halves: ⓑ (mapped tracks, the lanes above) and ⓐ
# (session files). ⓑ has been mechanical since 2026-08-22; ⓐ was a SENTENCE the session judged —
# and the sentence counted files that SHIP WITH THE REPO. Measured 2026-08-30 with a control
# (nonsense pattern = 0 hits): two tracked files satisfied ⓐ, so `git clone` alone rendered the
# RETURNING menu and the NEW-USER branch was unreachable for anyone who clones.
# The rule is now one sentence — **ⓐ counts only files that did NOT ship** — and these lanes pin
# BOTH directions, because a rule that answers `new` to everything would pass B-1 alone.
BR="$TMP/branch"; mkdir -p "$BR/scripts"
git init -q "$BR" 2>/dev/null || { echo "ⓘ git init failed (branch fixtures) — NOT a pass"; exit 10; }
cp "$SUT" "$BR/scripts/mapped_tracks.sh"
mkdir -p "$BR/tracks/_meta" "$BR/tracks/_contrib"
: > "$BR/tracks/.gitkeep"; : > "$BR/tracks/_meta/.gitkeep"
# The two SHIPPED shapes that caused the defect, committed exactly as the real repo carries them.
printf '# monitor\n' > "$BR/tracks/_meta/harness_bench_issue_monitor.md"
printf '# contrib\n' > "$BR/tracks/_contrib/session_2026_06_27_cross-audit.md"
git -C "$BR" add -A >/dev/null 2>&1
git -C "$BR" -c user.email=t@t -c user.name=t commit -q -m ship 2>/dev/null

_bv() { ( cd "$1" && bash scripts/mapped_tracks.sh 2>&1 | sed -n 's/^onboarding_branch=//p' ); }

v=$(_bv "$BR")
[ "$v" = "new" ] && ok "B-1 shipped files do NOT make a clone look returning (got new)" \
                 || ng "B-1 a fresh clone reported '$v' — shipped content is being counted as prior use"

# 🟥 CONTROL — without this, a rule that always answers `new` passes B-1. A file the USER made
# must still flip the verdict.
mkdir -p "$BR/tracks/myproj"; printf '# s\n' > "$BR/tracks/myproj/session_2026-08-30.md"
v=$(_bv "$BR")
[ "$v" = "returning" ] && ok "B-2 control — a user-made session file DOES make it returning" \
                       || ng "B-2 control — user file ignored (got '$v'); the rule is too wide"
rm -rf "$BR/tracks/myproj"

# ⓐ's own half: an UNTRACKED file in _meta counts (someone who worked and quit without closing).
printf '# c\n' > "$BR/tracks/_meta/fh_completed_2026-08-30.md"
v=$(_bv "$BR")
[ "$v" = "returning" ] && ok "B-3 an untracked _meta file counts (worked, never closed)" \
                       || ng "B-3 untracked _meta file ignored (got '$v')"
rm -f "$BR/tracks/_meta/fh_completed_2026-08-30.md"

# THREE-VALUED. Outside a git tree the two classes cannot be separated, and that is UNKNOWN —
# never the friendlier value. Rendering it as `new` tells a returning user they look new.
NG="$TMP/nogit"; mkdir -p "$NG/scripts" "$NG/tracks/_meta"
cp "$SUT" "$NG/scripts/mapped_tracks.sh"; : > "$NG/tracks/.gitkeep"; : > "$NG/tracks/_meta/.gitkeep"
v=$(_bv "$NG")
[ "$v" = "UNKNOWN" ] && ok "B-4 non-git tree → UNKNOWN (not 'new')" \
                     || ng "B-4 non-git tree reported '$v' — an unmeasured state took a real value"

# The key must be present on EVERY path, including the UNMEASURED exit. A consumer that greps for
# it and finds silence fills the blank in with the friendlier branch.
# 🟥 CAPTURE FIRST, THEN GREP. The subject exits 3 on this path, and under `pipefail` that exit
# code becomes the pipeline's — so `subject | grep -q` reports the SUBJECT's failure, not grep's.
# The repo's own pre-commit hook warns about this shape; this lane reproduced it on the first try.
_ngout=$( cd "$NG" && bash scripts/mapped_tracks.sh 2>&1 ) || true
printf '%s' "$_ngout" | grep -q '^onboarding_branch=' \
  && ok "B-5 the branch key is emitted even on the UNMEASURED path" \
  || ng "B-5 UNMEASURED path emits no branch key — silence is not an answer"

if [ "$FAIL" -eq 0 ]; then
  echo "MAPPED-TRACKS LANES: PASS ($PASS/$PASS)"
  echo "  NOT covered: whether the synergy skill (or any other consumer) actually CALLS this."
  echo "  A resolver with no caller is prose with a shebang — check the wiring separately."
  exit 0
else
  echo "MAPPED-TRACKS LANES: FAIL ($FAIL failed · $PASS passed)"; exit 1
fi
