#!/usr/bin/env bash
# publish_freshness_check.sh — «지금 팩되는 트리가 커밋된 통합 브랜치인가».
#
# ─────────────────────────────────────────────────────────────────────────────
# 왜 지어졌나 — 같은 표면에서 두 번 터졌고, 둘 다 «출하 후»에 알았다
# ─────────────────────────────────────────────────────────────────────────────
# `npm publish` 는 **커밋이 아니라 워킹트리를 팩한다.** 그 한 줄이 두 사고를 만들었다:
#
#   2026-08-13  6세션 공유 체크아웃에서 publish → **남의 미커밋 초안이 출하됐다.**
#   2026-08-16  main 에 머지된 M6 가 tarball 에 없었다 — 출하한 트리가 그 커밋 이전이었다.
#               소비자가 받은 registry_check 에는 `M6` 가 **0회** 등장한다.
#
# 둘 다 «출하물이 main 보다 뒤처지거나 앞서는» 한 클래스다. 기존 publish 게이트
# (`version_lockstep_check` · `selfcheck` · `package_coverage_check --vs-tarball` ·
# `public_surface_scan_files`)는 전부 **파일 내용**을 본다 — 그 내용이 **어느 커밋의 것인가**를
# 묻는 검사는 하나도 없었다. 그래서 이 파일은 기존 검사의 중복이 아니다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 무엇을 보증하지 않는가 (과잉주장 금지)
# ─────────────────────────────────────────────────────────────────────────────
# · **내용이 옳다는 보증이 아니다.** «커밋됐고 origin 과 같다» 만 본다.
# · **gitignored 파일은 못 본다.** `git status` 가 안 보므로 dirty 로 안 잡힌다.
#   다만 gitignored 파일은 `files[]` 로 출하되지 않는 것이 정상이고, 그 축은
#   `package_coverage_check --vs-tarball` 이 본다.
# · **원격이 그 사이 움직이는 것은 못 막는다.** fetch 시점의 스냅샷이다.
#
# 비가역 표면(publish)이므로 **fail-CLOSED**: 판정할 수 없으면 막는다.
# 명시적 우회는 `PUBLISH_FRESHNESS_OK=1` — 로그를 남긴다.
#
# Usage:  bash scripts/publish_freshness_check.sh [--self-test]
# Exit:   0 = 출하해도 되는 상태 · 1 = 막힘 · 2 = 판정 불가(역시 막힘)
set -uo pipefail

INTEGRATION_BRANCH="${FH_INTEGRATION_BRANCH:-main}"
pass=0; fail=0
ok()  { printf '  \342\234\205 %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \342\235\214 %s\n' "$1"; fail=$((fail+1)); }

run_checks() {
  echo "publish freshness check (branch=$INTEGRATION_BRANCH)"

  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "  INSTRUMENT ERROR: not a git repository — freshness cannot be judged. NOT a pass."
    return 2; }

  # ── ① 워킹트리가 깨끗한가 ────────────────────────────────────────────────
  # `--porcelain` 은 추적 파일의 수정·스테이징·미추적을 전부 낸다. 미추적까지 세는 것은
  # 의도적이다 — 2026-08-13 사고는 **남의 미커밋 파일**이 팩된 것이었다.
  local dirty
  dirty=$(git status --porcelain 2>/dev/null | grep -vE '^\?\? tracks/' || true)
  if [ -n "$dirty" ]; then
    bad "워킹트리가 깨끗하지 않다 — publish 는 커밋이 아니라 이 트리를 팩한다:"
    printf '%s\n' "$dirty" | head -10 | sed 's/^/      /'
    local n; n=$(printf '%s\n' "$dirty" | grep -c . || true)
    [ "${n:-0}" -gt 10 ] && echo "      … 외 $(( n - 10 ))건"
  else
    ok "워킹트리 깨끗 (tracks/ 미추적은 gitignored 운영 산출물이라 제외)"
  fi

  # ── ② 통합 브랜치 위인가 ────────────────────────────────────────────────
  local head_branch
  head_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [ "$head_branch" = "$INTEGRATION_BRANCH" ]; then
    ok "HEAD 가 $INTEGRATION_BRANCH"
  else
    bad "HEAD 가 '$head_branch' — 통합 브랜치('$INTEGRATION_BRANCH')가 아니다. 피처 브랜치의 트리가 출하된다"
  fi

  # ── ③ origin 과 같은 커밋인가 ────────────────────────────────────────────
  # 앞서든 뒤처지든 둘 다 막는다. **뒤처짐**이 2026-08-16 사고(머지된 M6 미출하)이고,
  # **앞섬**은 «리뷰를 안 거친 로컬 커밋이 출하되는» 반대편 사고다. 방향이 아니라
  # 불일치 자체가 판정 대상이다.
  git fetch -q origin "$INTEGRATION_BRANCH" 2>/dev/null || {
    bad "origin/$INTEGRATION_BRANCH 를 fetch 할 수 없다 — 신선도를 **못 쟀다**. 비가역 표면이므로 막는다"
    return 1; }
  local local_sha remote_sha
  local_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
  remote_sha=$(git rev-parse "origin/$INTEGRATION_BRANCH" 2>/dev/null || echo "")
  if [ -z "$local_sha" ] || [ -z "$remote_sha" ]; then
    bad "커밋 해시를 읽을 수 없다 — 판정 불가"
  elif [ "$local_sha" = "$remote_sha" ]; then
    ok "HEAD == origin/$INTEGRATION_BRANCH (${local_sha:0:7})"
  else
    local ahead behind
    ahead=$(git rev-list --count "origin/$INTEGRATION_BRANCH..HEAD" 2>/dev/null || echo "?")
    behind=$(git rev-list --count "HEAD..origin/$INTEGRATION_BRANCH" 2>/dev/null || echo "?")
    bad "HEAD(${local_sha:0:7}) != origin/$INTEGRATION_BRANCH(${remote_sha:0:7}) — ahead $ahead · behind $behind. behind 면 머지된 변경이 출하에서 빠진다(2026-08-16 사고 형태)"
  fi

  echo "----"
  echo "publish freshness: $pass passed, $fail failed"
  [ "$fail" -eq 0 ] || return 1
  return 0
}

# ── self-test — known-pair. «막는가» 가 아니라 «옳게 막는가» 를 본다 ────────
self_test() {
  local T rc sp=0 sf=0
  T=$(mktemp -d)
  # $4(선택) = 출력에 반드시 있어야 할 문자열 = **차단 귀속**. rc 만 보는 레인은 «막혔는가» 만
  # 재고 «옳은 축이 막았는가» 를 못 잰다 — 오늘 이 레포에서 실제로, 사고 재현 픽스처가 엉뚱한
  # 축(M1)에 걸려 통과한 적이 있다. 기대 축의 문자열까지 확인해야 «막았다» 가 증거가 된다.
  _lane() { # $1=이름 $2=기대rc $3=실제rc $4=기대문자열(선택) $5=출력
    local why=""
    if [ -n "${4:-}" ] && ! printf '%s' "${5:-}" | grep -q -- "$4"; then
      why=" — rc 는 맞지만 귀속이 틀렸다: '$4' 가 출력에 없다"
    fi
    if [ "$3" = "$2" ] && [ -z "$why" ]; then sp=$((sp+1)); printf '  ✅ %-40s rc=%s\n' "$1" "$3"
    else sf=$((sf+1)); printf '  ❌ %-40s rc=%s (기대 %s)%s\n' "$1" "$3" "$2" "$why"; fi; }

  echo "publish_freshness_check --self-test"

  # 격리된 known-pair 레포를 만든다. 이 레포 자신을 대상으로 삼으면 «오늘 이 트리가 어떤
  # 상태인가» 에 따라 결과가 바뀌어 레인이 계기가 아니라 날씨가 된다.
  local UP="$T/upstream" WK="$T/work"
  git init -q --bare "$UP"
  # HEAD 를 명시적으로 main 에 건다. `-b main` 은 git>=2.28 전용이라 안 쓰고 symbolic-ref 로 건다.
  # 🟥 이 두 줄이 없으면 CI 에서만 깨진다(실측 2026-08-16): 이 머신은 전역
  # `init.defaultBranch=main` 이라 bare 의 HEAD 가 main 이지만, 러너는 보통 설정이 없어
  # HEAD 가 `master` 를 가리킨다. 그러면 아래 `git clone` 이 **존재하지 않는 브랜치를 가리키는
  # HEAD** 를 만나 체크아웃 없이 끝나고, 이어지는 커밋·푸시가 전부 실패하며, origin 이 전진하지
  # 않아 「뒤처짐」 arm 이 **rc=0 으로 조용히 통과**한다. 계기가 환경에 따라 다른 걸 재고 있었다.
  git -C "$UP" symbolic-ref HEAD refs/heads/main
  git init -q "$WK"
  ( cd "$WK"
    git config user.email t@t; git config user.name t
    echo one > a.txt; git add a.txt; git commit -qm one
    git branch -M main; git remote add origin "$UP"; git push -q -u origin main ) >/dev/null 2>&1
  # 셋업이 실제로 섰는지 **단언한다.** 위 블록은 출력을 버리므로 실패해도 조용하고, 그러면
  # 뒤따르는 모든 arm 이 «검사기가 통과시켰다» 가 아니라 «검사할 게 없었다» 로 초록이 된다
  # ([[feedback_absence_measurement_needs_control]] — 부재 측정엔 컨트롤을 동반한다).
  if ! git -C "$UP" rev-parse --verify -q refs/heads/main >/dev/null; then
    sf=$((sf+1)); echo "  ❌ SETUP 실패 — upstream 에 main 이 서지 않았다. 아래 레인들은 무의미하다"
    rm -rf "$T"; echo "── publish_freshness 캘리브레이션 실패: $sp PASS / $sf FAIL ──"; return 1
  fi

  # ── known-negative: 깨끗 · main · origin 과 동일 → 통과해야 한다 ──────────
  o=$( cd "$WK" && bash "$SELF" 2>&1 ); rc=$?
  _lane "깨끗한 main 은 통과" 0 "$rc" "" "$o"

  # ── known-positive A: 더러운 트리 ────────────────────────────────────────
  o=$( cd "$WK" && echo dirty > b.txt && bash "$SELF" 2>&1 ); rc=$?
  _lane "미추적 파일이 있으면 막는다" 1 "$rc" "워킹트리가 깨끗하지 않다" "$o"
  rm -f "$WK/b.txt"

  # ── known-positive B: 피처 브랜치 ────────────────────────────────────────
  o=$( cd "$WK" && git switch -q -c feat/x && bash "$SELF" 2>&1 ); rc=$?
  _lane "피처 브랜치에서는 막는다" 1 "$rc" "통합 브랜치" "$o"

  # ── known-positive C: main 이 origin 보다 뒤처짐 (2026-08-16 사고 형태) ──
  # 다른 클론에서 커밋을 올려 origin 을 전진시킨 뒤, 원래 워킹트리에서 검사한다.
  ( cd "$T" && git clone -q "$UP" other && cd other
    git config user.email t@t; git config user.name t
    git checkout -q -B main origin/main
    echo two > c.txt; git add c.txt; git commit -qm two; git push -q origin main ) >/dev/null 2>&1
  # 같은 이유로 **전진했는지 단언한다**. 이 arm 은 이 파일이 존재하는 이유(08-16 사고 형태)라
  # 조용히 통과하면 정확히 그 사고를 못 잡는 상태로 돌아간다.
  if [ "$(git -C "$UP" rev-list --count refs/heads/main)" -lt 2 ]; then
    sf=$((sf+1)); echo "  ❌ SETUP 실패 — origin 이 전진하지 않았다. 「뒤처짐」 arm 을 실행할 수 없다"
    rm -rf "$T"; echo "── publish_freshness 캘리브레이션 실패: $sp PASS / $sf FAIL ──"; return 1
  fi
  o=$( cd "$WK" && git switch -q main && bash "$SELF" 2>&1 ); rc=$?
  _lane "origin 보다 뒤처지면 막는다(08-16 사고형)" 1 "$rc" "behind" "$o"

  # ── 컨트롤: 따라잡으면 다시 통과해야 한다 (전부 막는 계기가 아님) ────────
  o=$( cd "$WK" && git pull -q --ff-only origin main && bash "$SELF" 2>&1 ); rc=$?
  _lane "따라잡으면 다시 통과 (컨트롤)" 0 "$rc" "" "$o"

  rm -rf "$T"
  # 이 줄은 `selfcheck.sh` 의 embedded --self-test 루프가 «실행이 실제로 일어났다» 를 판정하는
  # 앵커다(`*캘리브레이션*` 매치). 종단 판정줄이지 테스트 케이스 제목이 아니다 — 그 구분이
  # 중요한 이유는 `capability_registry_check` 가 정확히 그 이유로 이 루프에서 빠져 있기 때문이다
  # (그쪽의 캘리브레이션은 한국어 테스트 제목 안에만 있어서, 제목을 바꾸면 진짜 PASS 가
  # «디스패처 없음» 으로 뒤집힌다).
  echo "── publish_freshness 캘리브레이션 $([ "$sf" -eq 0 ] && echo 통과 || echo 실패): $sp PASS / $sf FAIL ──"
  [ "$sf" -eq 0 ]
}

SELF="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/$(basename "${BASH_SOURCE[0]:-$0}")"

case "${1:-}" in
  --self-test) self_test; exit $?;;
esac

if [ -n "${PUBLISH_FRESHNESS_OK:-}" ]; then
  echo "⚠️  publish-freshness: PUBLISH_FRESHNESS_OK=1 — 명시적 우회. 무엇을 우회했는지 아래에 남긴다:"
  run_checks || true
  echo "⚠️  우회하고 진행한다. 이 줄이 그 기록이다."
  exit 0
fi

run_checks
rc=$?
if [ "$rc" -ne 0 ]; then
  cat <<'EOF'

🚫 publish 중단 — 지금 팩되는 트리가 «커밋된 통합 브랜치» 가 아니다.
   publish 는 커밋이 아니라 워킹트리를 팩한다. 이 상태로 내보내면 출하물과 main 이 갈린다.

   ▸ 정상 경로   : 변경을 커밋 → PR → 머지 → main 에서 pull → 다시 publish
   ▸ 알고도 강행 : PUBLISH_FRESHNESS_OK=1 npm publish   (무엇을 우회했는지 출력에 남는다)
EOF
fi
exit "$rc"
