#!/usr/bin/env bash
# gate_anchor_check.sh — FH 게이트 앵커 하네스 (known-pair)
# provenance: pmh-dev@cbe3932 역수확(2026-08-10) — 규율 3종(문법검사≠계기 · 막힘≠옳게막힘 ·
#   부재≠통과)은 원래 FH 실측에서 태어나 pmh 에서 스크립트로 벼려진 것을 되가져온 것.
#
# 왜 이게 먼저인가:
#   이 레포는 지금까지 "게이트가 초록이다"를 잴 수단이 없었다. 훅이 설치되어 있는지,
#   설치돼 있다면 **옳은 이유로** 통과시키는지 — 둘 다 미측정이었다. 훅 본체를 옮기기
#   전에 이 앵커가 먼저 있어야 이식이 "됐다"가 아니라 "옳게 됐다"로 판정된다.
#
# 이 스크립트가 지키는 세 가지 규율 (전부 FH 에서 실측으로 얻어진 것):
#
#   1. **문법검사는 계기가 아니다.** `bash -n` 은 런타임 bad substitution 을 통과시킨다.
#      그 상태의 훅은 중단되면서 exit 0 을 남기고 — 즉 모든 push 가 허용된다.
#      그래서 여기서는 훅을 **실제로 실행**하고 출력에서 런타임 결함을 함께 본다.
#
#   2. **"막혔다" ≠ "옳게 막혔다".** 차단 쌍만 고정하면 과차단 게이트가 초록으로 채점된다.
#      과차단은 override 를 근육기억으로 만들어 게이트를 무장해제시킨다. 그래서 모든
#      검사는 known-positive(막혀야 함) 와 known-negative(통과해야 함) 쌍으로 둔다.
#
#   3. **부재는 통과가 아니다.** 훅이 없으면 PASS 도 FAIL 도 아닌 `NOT-INSTALLED` 로
#      보고하고 전용 exit code 를 낸다. 부재를 초록으로 읽는 순간 이 앵커 자체가
#      fail-open 이 된다.
#
# Exit: 0 = 모든 쌍 성립 · 1 = 쌍 붕괴(진짜 결함) · 10 = 하네스 오류/미설치(판정 불가)
#
# Usage: bash scripts/gate_anchor_check.sh [--quiet]

set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# ── cwd 가드 ──────────────────────────────────────────────────────────────
# `git rev-parse` 는 **현재 cwd** 의 레포를 답한다. 다른 레포에서 이 스크립트를
# 절대경로로 부르면 엉뚱한 대상을 재고, 그 결과가 그럴듯해서 알아채기 어렵다.
# (2026-07-28 실측: 다른 레포 cwd 에서 호출해 "미설치 0 · 패턴 유효" 라는 거짓 초록을 얻었다.)
SCRIPT_REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel 2>/dev/null || true)
if [ -n "$SCRIPT_REPO" ] && [ "$SCRIPT_REPO" != "$REPO_ROOT" ]; then
    echo "❌ harness-error: 스크립트와 cwd 가 서로 다른 레포다 — 측정 대상이 어긋난다."
    echo "   스크립트 레포: $SCRIPT_REPO"
    echo "   현재 cwd 레포: $REPO_ROOT"
    echo "   → cd \"$SCRIPT_REPO\" 후 다시 실행할 것."
    exit 10
fi

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

PAIRS_OK=0
PAIRS_BROKEN=0
NOT_INSTALLED=0

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
pass() { PAIRS_OK=$((PAIRS_OK+1));     say "  ✅ $*"; }
fail() { PAIRS_BROKEN=$((PAIRS_BROKEN+1)); say "  ❌ $*"; }
absent(){ NOT_INSTALLED=$((NOT_INSTALLED+1)); say "  ⛔ NOT-INSTALLED — $*"; }

# ---------------------------------------------------------------------------
# 0. 설치 상태 — 판정이 아니라 사실 보고. 여기서 거짓말하면 아래가 전부 무의미하다.
# ---------------------------------------------------------------------------
say "── 0. 설치 상태 ──────────────────────────────────────────"

HOOKS_PATH=$(git -C "$REPO_ROOT" config core.hooksPath 2>/dev/null || true)
if [ -n "$HOOKS_PATH" ]; then
    case "$HOOKS_PATH" in
        /*) ACTIVE_DIR="$HOOKS_PATH" ;;
        *)  ACTIVE_DIR="$REPO_ROOT/$HOOKS_PATH" ;;
    esac
    say "  core.hooksPath = $HOOKS_PATH"
    [ -d "$ACTIVE_DIR" ] || say "  ⚠️  그 경로가 존재하지 않는다 — 훅이 하나도 안 돈다"
else
    ACTIVE_DIR="$(git -C "$REPO_ROOT" rev-parse --absolute-git-dir)/hooks"
    say "  core.hooksPath 미설정 → $ACTIVE_DIR 사용"
fi

for h in pre-commit pre-push; do
    if [ -x "$ACTIVE_DIR/$h" ]; then
        say "  설치됨: $h ($(wc -l < "$ACTIVE_DIR/$h" | tr -d ' ') lines)"
    else
        say "  부재:   $h"
    fi
done

# 소스 디렉토리 — FH 는 templates/.git-hooks 를 쓴다.
# 추측하지 말고 실재하는 것을 고른다: 없는 경로를 이름으로 단정하면 "부재"를 잘못 보고한다.
SRC_DIR=""
for cand in "$REPO_ROOT/templates/.git-hooks" "$REPO_ROOT/.git-hooks"; do
    [ -d "$cand" ] && { SRC_DIR="$cand"; break; }
done
if [ -n "$SRC_DIR" ]; then
    say "  훅 소스 디렉토리: ${SRC_DIR#$REPO_ROOT/} ($(ls "$SRC_DIR" | tr '\n' ' '))"
else
    say "  훅 소스 디렉토리 부재 — templates/.git-hooks · .git-hooks 둘 다 없음"
fi

# ---------------------------------------------------------------------------
# 공통: 일회용 레포에서 훅을 실제로 실행한다. 이 레포의 index/worktree 는 건드리지 않는다.
# ---------------------------------------------------------------------------
SANDBOX=$(mktemp -d) || { echo "❌ harness-error: mktemp 실패"; exit 10; }
trap 'rm -rf "$SANDBOX"' EXIT

# run_hook <hook-path> <sandbox> [env assignments...]
#   훅을 실행하고 "exit코드 + 출력" 을 돌려준다. 런타임 결함 탐지가 목적이므로
#   stderr 를 버리지 않는다 — 과거 실측에서 세 종류의 무음 실패가 전부 stderr 에서 자백했다.
# 잔여(명명): 훅이 $BASH_SOURCE 기준으로 원레포 파일을 읽으면 sandbox 픽스처가 무의미해진다 —
# FH 훅 2종은 런타임 rev-parse(REPO_ROOT) 해석임을 실측 확인(2026-08-10). 새 훅 추가 시 재확인.
run_hook() {
    local hook="$1" dir="$2"; shift 2
    if [ -x "$hook" ]; then ( cd "$dir" && env "$@" "$hook" 2>&1 )   # shebang 존중
    else ( cd "$dir" && env "$@" bash "$hook" 2>&1 ); fi
    return $?
}

# 런타임 결함 문자열 — 이게 나오면 verdict 와 무관하게 계기 고장이다.
RUNTIME_FAULT='bad substitution|command not found|unbound variable|No such file or directory: .*\.sh|syntax error|Permission denied|grep: invalid|fatal: [^o]'
# 정책 태그 — 차단이 «옳은 이유»인지 본다. rc!=0 이기만 하면 infra 오류 차단도 초록이 된다
# (교차 계열 라운드 적발). 태그는 훅 출력 실측(2026-08-10)에서 채집.
PC_POLICY_TAG='HIGH leak|MED leak|Confidentiality'
PP_POLICY_TAG='MAIN_PUSH_OK|main.*직|direct.*main|integration branch'

# new_repo <name> — 일회용 레포. **초기 커밋을 반드시 만든다.**
#   HEAD 없는 레포에서는 훅의 `git diff --cached … HEAD` 가 fatal 로 죽고, 그 죽음이
#   exit 0 으로 읽혀 "게이트가 통과시켰다"는 거짓 판정이 나온다. 계기가 대상을 모함하는
#   전형적인 경로라 픽스처 쪽에서 먼저 막는다. (2026-07-28 실측: 이 결함으로 known-positive
#   2건이 잘못 채점됐다.)
#
#   의존 파일 동반 (2026-07-28 이식 실측): pre-commit 훅이 `scripts/psa_scan_lib.sh` 와
#   `.claude/rules/.public-surface-patterns.defaults` 를 참조한다. sandbox 레포에는 이들이
#   없어서 훅이 "스캐너 부재" 로 FAIL 하고, 그 FAIL 이 평문까지 차단하는 과차단으로 나타난다.
#   known-pair 가 "옳게 통과/옳게 차단" 을 재는 계기라면, 픽스처는 훅이 의존하는 파일을
#   그대로 제공해야만 계기 자체가 유효하다. 본 레포(psA_scan_lib.sh 가 있는 레포)에서
#   sandbox 로 복사한다.
_fixture_fail(){ echo "❌ harness-error: 픽스처 준비 실패 — $1"; exit 10; }
new_repo() {
    local d="$SANDBOX/$1"
    mkdir -p "$d" && git -C "$d" init -q 2>/dev/null || _fixture_fail "git init ($1)"
    git -C "$d" config user.email "anchor@example.invalid"
    git -C "$d" config user.name "anchor"
    # 훅이 참조하는 의존 파일을 sandbox 에 동반 — 부재 시 "스캐너 부재" FAIL 로 과차단.
    if [ -f "$REPO_ROOT/scripts/psa_scan_lib.sh" ]; then
        mkdir -p "$d/scripts" && cp "$REPO_ROOT/scripts/psa_scan_lib.sh" "$d/scripts/" 2>/dev/null
    fi
    if [ -f "$REPO_ROOT/.claude/rules/.public-surface-patterns.defaults" ]; then
        mkdir -p "$d/.claude/rules" \
            && cp "$REPO_ROOT/.claude/rules/.public-surface-patterns.defaults" "$d/.claude/rules/" 2>/dev/null
    fi
    ( cd "$d" && printf 'seed\n' > .anchor_seed && git add .anchor_seed \
        && git -c commit.gpgsign=false commit -qm "anchor seed" ) >/dev/null 2>&1 \
        || _fixture_fail "seed commit ($1)"
    git -C "$d" rev-parse --verify HEAD >/dev/null 2>&1 || _fixture_fail "HEAD 부재 ($1)"
    printf '%s\n' "$d"
}

# new_repo_with_remote <name> — 리모트 tip 이 fetch 된 상태의 레포.
#   pre-push 훅은 리모트 tip 을 모르면 force-push 와 fast-forward 를 구분할 수 없어
#   **옳게 fail-closed** 한다. 그 차단을 "과차단" 으로 채점하지 않으려면 픽스처가
#   분류 가능한 상태여야 한다.
new_repo_with_remote() {
    local d="$SANDBOX/$1" bare="$SANDBOX/$1.git"
    git init -q --bare "$bare" 2>/dev/null
    d=$(new_repo "$1")
    git -C "$d" remote add origin "$bare" 2>/dev/null || _fixture_fail "remote add ($1)"
    git -C "$d" push -q origin HEAD:refs/heads/main 2>/dev/null || _fixture_fail "seed push ($1)"
    git -C "$d" fetch -q origin 2>/dev/null || _fixture_fail "fetch ($1)"
    git -C "$d" rev-parse --verify 'origin/main^{commit}' >/dev/null 2>&1 \
        || _fixture_fail "origin/main 미확정 ($1) — 폴백 금지"
    printf '%s\n' "$d"
}

# ---------------------------------------------------------------------------
# 1. pre-commit — 기밀 스캔 known-pair
# ---------------------------------------------------------------------------
say ""
say "── 1. pre-commit 기밀 스캔 ───────────────────────────────"

# 활성 경로의 훅만 측정한다 — 소스 디렉토리 폴백은 «git 이 실제로 돌리지 않는 것»을 재서
# 미설치를 초록으로 가린다(교차 계열 라운드 적발). 소스는 §0 에서 정보로만 보고.
PRECOMMIT=""
[ -x "$ACTIVE_DIR/pre-commit" ] && PRECOMMIT="$ACTIVE_DIR/pre-commit"

if [ -z "$PRECOMMIT" ]; then
    absent "pre-commit 훅이 활성 경로에도 .git-hooks/ 에도 없다 — 기밀 스캔 미측정"
else
    # known-positive: 막혀야 한다
    # AWS access key ID 형태 (AKIA + 16자 영숫자) — .defaults 의 `AKIA[0-9A-Z]{16}` 패턴이 잡는다.
    # 예전 `AWS_SECRET_ACCESS_KEY=...` 형태는 .defaults 패턴이 잡지 못해 fail-open 으로 채점됐다
    # (2026-07-28 이식 실측). 패턴과 픽스처가 일치해야 known-pair 가 유효하다.
    d=$(new_repo pc_block)
    # 픽스처 리터럴은 소스에서 분할 조립 — 이 스크립트 자신이 기밀 스캔(같은 패턴)에 걸리지
    # 않게 하되, 런타임에는 온전한 자격증명 형태를 만든다(스캐너 회피가 아니라 자기-오탐 방지).
    printf 'aws_access_key_id=%s%s\n' 'AKIA' '1234567890ABCDEFGHIJKLMNOP' > "$d/leak.md"
    git -C "$d" add leak.md
    out=$(run_hook "$PRECOMMIT" "$d"); rc=$?
    if printf '%s' "$out" | grep -qE "$RUNTIME_FAULT"; then
        fail "known-positive: 런타임 결함으로 중단 — verdict 신뢰 불가"
        say "     $(printf '%s' "$out" | grep -E "$RUNTIME_FAULT" | head -2)"
    elif [ $rc -ne 0 ] && printf '%s' "$out" | grep -qE "$PC_POLICY_TAG"; then
        pass "known-positive: 자격증명 형태를 정책 태그와 함께 차단 (exit=$rc)"
    elif [ $rc -ne 0 ]; then
        fail "known-positive: 차단은 됐으나 정책 태그 미검출 — 이유 불명 차단(infra 오류 가능)"
    else
        fail "known-positive: 자격증명이 통과했다 (exit=0) — fail-open"
    fi

    # known-negative: 통과해야 한다 (과차단이면 override 가 근육기억이 된다)
    d=$(new_repo pc_pass)
    printf '# 평범한 문서\n\n일반적인 산문입니다.\n' > "$d/ok.md"
    git -C "$d" add ok.md
    out=$(run_hook "$PRECOMMIT" "$d"); rc=$?
    if printf '%s' "$out" | grep -qE "$RUNTIME_FAULT"; then
        fail "known-negative: 런타임 결함으로 중단"
    elif [ $rc -eq 0 ]; then
        pass "known-negative: 평문 문서를 통과 (과차단 아님)"
    else
        fail "known-negative: 평문 문서를 차단했다 (exit=$rc) — 과차단은 게이트를 무장해제시킨다"
    fi
fi

# ---------------------------------------------------------------------------
# 2. pre-push — main 직행 차단 known-pair
# ---------------------------------------------------------------------------
say ""
say "── 2. pre-push main 직행 차단 ────────────────────────────"

PREPUSH=""
[ -x "$ACTIVE_DIR/pre-push" ] && PREPUSH="$ACTIVE_DIR/pre-push"

if [ -z "$PREPUSH" ]; then
    absent "pre-push 훅이 없다 — main 직행/파괴적 op 차단 미측정"
else
    # known-positive: main 직행은 막혀야 한다
    d=$(new_repo_with_remote pp_main)
    git -C "$d" switch -q -c main 2>/dev/null || git -C "$d" switch -q main 2>/dev/null
    ( cd "$d" && printf 'delta\n' >> .anchor_seed && git add .anchor_seed \
        && git -c commit.gpgsign=false commit -qm "delta" ) >/dev/null 2>&1 \
        || _fixture_fail "main delta commit"
    local_sha=$(git -C "$d" rev-parse HEAD)
    remote_sha=$(git -C "$d" rev-parse --verify 'origin/main^{commit}' 2>/dev/null) \
        || _fixture_fail "origin/main 조회"
    out=$(printf 'refs/heads/main %s refs/heads/main %s\n' "$local_sha" "$remote_sha" \
          | ( cd "$d" && bash "$PREPUSH" origin "$(git -C "$d" remote get-url origin)" 2>&1 )); rc=$?
    if printf '%s' "$out" | grep -qE "$RUNTIME_FAULT"; then
        fail "known-positive: 런타임 결함으로 중단 — 이 상태의 훅은 모든 push 를 허용한다"
        say "     $(printf '%s' "$out" | grep -E "$RUNTIME_FAULT" | head -2)"
    elif [ $rc -ne 0 ] && printf '%s' "$out" | grep -qiE "$PP_POLICY_TAG"; then
        pass "known-positive: main 직행을 정책 태그와 함께 차단 (exit=$rc)"
    elif [ $rc -ne 0 ]; then
        fail "known-positive: 차단은 됐으나 정책 태그 미검출 — 이유 불명 차단"
    else
        fail "known-positive: main 직행이 통과했다 — PR-only 규약이 기계적으로 비어있다"
    fi

    # known-negative: feature 브랜치는 통과해야 한다 (신규 ref = 삭제도 force 도 아님)
    d=$(new_repo_with_remote pp_feat)
    git -C "$d" branch -q feat/x 2>/dev/null || _fixture_fail "feat/x 생성"
    git -C "$d" show-ref -q --verify refs/heads/feat/x || _fixture_fail "feat/x 검증"
    local_sha=$(git -C "$d" rev-parse refs/heads/feat/x)
    out=$(printf 'refs/heads/feat/x %s refs/heads/feat/x %s\n' "$local_sha" "0000000000000000000000000000000000000000" \
          | ( cd "$d" && bash "$PREPUSH" origin "$(git -C "$d" remote get-url origin)" 2>&1 )); rc=$?
    if printf '%s' "$out" | grep -qE "$RUNTIME_FAULT"; then
        fail "known-negative: 런타임 결함으로 중단"
    elif [ $rc -eq 0 ]; then
        pass "known-negative: feature 브랜치 push 통과 (과차단 아님)"
    else
        fail "known-negative: feature 브랜치를 차단했다 (exit=$rc) — 과차단"
    fi
fi

# ---------------------------------------------------------------------------
# 3. 패턴 소스
# ---------------------------------------------------------------------------
say ""
say "── 3. 기밀 스캔 배선 + 패턴 소스 ─────────────────────────"

# 순서가 중요하다: 패턴 파일 부재를 보고하기 전에 **스캔이 존재하는지** 먼저 본다.
# 스캔이 아예 없는데 "패턴이 없다" 고만 보고하면, 패턴만 채우면 닫힌다는 오독을 만든다.
if [ -n "$PRECOMMIT" ] && ! grep -qE 'public-surface-patterns|psa_scan|PUBLIC_SURFACE_OK' "$PRECOMMIT" 2>/dev/null; then
    absent "pre-commit 에 기밀 스캔 배선이 없다 — 패턴 파일 문제가 아니라 **스캔 자체가 부재**다.
        (grep: public-surface-patterns · psa_scan · PUBLIC_SURFACE_OK 전부 0건)
        패턴만 채워도 닫히지 않는다. 스캔 로직 이식이 선행되어야 한다."
fi

# 스캐너 라이브러리 실재 + 진입점 2종 — **실레포** 기준.
#
# 왜 별도 레인인가: #27 이 픽스처에 `psa_scan_lib.sh` 를 동반하도록 고친 것은 옳다(없으면 훅이
# "스캐너 부재" 로 fail-closed 하고, 그 차단이 known-positive 에선 탐지 성공으로 known-negative
# 에선 과차단으로 채점돼 계기가 대상을 양방향으로 모함한다). 다만 그 수리의 부작용으로
# **픽스처 런은 이제 실레포의 스캐너 부재를 구조적으로 감지할 수 없다** — 픽스처가 스스로
# 채워 넣기 때문이다. 그 케이스를 여기서 본다.
#
# 부재가 왜 조용한 사고인가: 배선 grep(§3 상단)은 통과한다. 훅은 매 커밋 fail-closed 한다.
# 즉 "게이트가 빡세다"로 보이지 "스캐너가 없다"로는 안 보인다. 그리고 상시 차단은
# PUBLIC_SURFACE_OK 를 근육기억으로 만들어, 정작 그 채널에 의존하는 push/publish 게이트까지
# 같이 무장해제시킨다. 과차단이 그 자체로 결함인 이유가 이거다.
PSA_LIB_PATH="$REPO_ROOT/scripts/psa_scan_lib.sh"
if [ ! -r "$PSA_LIB_PATH" ]; then
    absent "scripts/psa_scan_lib.sh 부재 — 배선은 있어도 스캐너가 없다(매 커밋 fail-closed)"
elif ! grep -q '^psa_load()' "$PSA_LIB_PATH" || ! grep -q '^psa_scan_tagged()' "$PSA_LIB_PATH"; then
    fail "psa_scan_lib.sh 가 진입점을 다 내보내지 않는다 (psa_load / psa_scan_tagged)"
else
    pass "스캐너 라이브러리 실재 + 진입점 2종"
fi

PAT_LOCAL="$REPO_ROOT/.claude/rules/.public-surface-patterns"
PAT_DEFAULTS="$REPO_ROOT/.claude/rules/.public-surface-patterns.defaults"

if [ -f "$PAT_LOCAL" ] || [ -f "$PAT_DEFAULTS" ]; then
    n=0; m=0
    [ -f "$PAT_LOCAL" ]    && n=$(awk 'NF && $0 !~ /^[[:space:]]*#/ {c++} END{print c+0}' "$PAT_LOCAL" 2>/dev/null)
    [ -f "$PAT_DEFAULTS" ] && m=$(awk 'NF && $0 !~ /^[[:space:]]*#/ {c++} END{print c+0}' "$PAT_DEFAULTS" 2>/dev/null)
    say "  로컬 패턴 ${n:-0}행 · 기본 패턴 ${m:-0}행"
    if [ "${n:-0}" -eq 0 ] && [ "${m:-0}" -eq 0 ]; then
        fail "패턴 파일은 있으나 유효 행이 0 — 스캔이 아무것도 안 잡는다(무음 무력화)"
    else
        pass "패턴 소스 유효"
    fi
else
    absent "기밀 패턴 소스 부재 — 로컬(.public-surface-patterns, gitignored)과 기본(.defaults) 둘 다 없음.
        그 전까지 기밀 스캔은 fail-closed 하거나(차단만 함) 무의미하다(아무것도 안 잡음)."
fi

# ---------------------------------------------------------------------------
# 요약
# ---------------------------------------------------------------------------
say ""
say "── 요약 ──────────────────────────────────────────────────"
say "  성립한 쌍: $PAIRS_OK · 붕괴한 쌍: $PAIRS_BROKEN · 미설치: $NOT_INSTALLED"

if [ "$PAIRS_BROKEN" -gt 0 ]; then
    say ""
    say "  ❌ 쌍이 붕괴했다 — 게이트가 있지만 옳게 동작하지 않는다."
    exit 1
fi

if [ "$NOT_INSTALLED" -gt 0 ]; then
    say ""
    say "  ⛔ 판정 불가 — 게이트 $NOT_INSTALLED 종이 미설치다."
    say "     부재는 통과가 아니다. 이식(C 단계) 후 이 앵커를 다시 돌려라."
    exit 10
fi

say ""
say "  ✅ 모든 known-pair 성립 — 게이트가 옳은 이유로 초록이다."
exit 0
