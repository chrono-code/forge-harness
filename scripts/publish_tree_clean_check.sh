#!/usr/bin/env bash
# publish_tree_clean_check.sh — publish 직전, 워킹트리가 깨끗한지 검문한다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 왜 이게 게이트인가 — npm publish 는 커밋이 아니라 **워킹트리**를 판다
# ─────────────────────────────────────────────────────────────────────────────
# 이 레포는 공유 체크아웃에서 여러 세션이 동시에 돈다. 그 조합에서 publish 하는 세션은
# **다른 세션의 미커밋 초안을 그대로 출하한다.** 실측 사고가 이미 기록돼 있고(카드
# 2026-08-13 «최대 발견»), 2026-08-17 에는 같은 뿌리로 커밋 경계에서 한 번 더 부딪혔다
# (세션 A 가 세션 B 의 미커밋 원장 append 를 자기 커밋에 실었다).
#
# 🟥 커밋 경계의 사고는 **사후에 보인다**(diff 에 남는다). 출하 경계의 사고는 **사후에도
# 안 보인다** — tarball 은 이미 레지스트리에 있고 되돌릴 수 없다. 그래서 여기 기계를 둔다.
# 정본 §Mechanization Boundary: *"기계는 비가역 경계와 채널에만 두고, 판단은 진화에 맡긴다."*
# publish 가 그 «비가역 경계» 다. 재발 횟수를 셀 자리가 아니다.
#
# 이 검사는 **판단을 하지 않는다** — 「이 변경이 출하돼도 되는가」를 묻지 않고
# 「출하물이 커밋된 상태와 일치하는가」만 묻는다. 채널 검사이지 내용 검사가 아니다.
#
# 우회: PUBLISH_DIRTY_OK=1 (명시 ACK. 다른 비가역 게이트의 DESTRUCTIVE_OP_OK /
#       PUBLIC_SURFACE_OK 와 같은 형태이고, 우회해도 **무엇이 더러웠는지 인쇄한다**).
#
# 사용: bash scripts/publish_tree_clean_check.sh
# exit: 0 clean(또는 명시 ACK) · 1 더럽다 · 10 harness error(git 부재/레포 밖)

set -uo pipefail

command -v git >/dev/null 2>&1 || { echo "❌ publish-tree-clean: git 부재 — 검사 불가(미측정은 통과가 아니다)" >&2; exit 10; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "❌ publish-tree-clean: git 워킹트리 밖 — 검사 불가" >&2; exit 10; }

echo "[Pre-Publish] working tree clean check (publish packs the TREE, not the commit)..."

# --porcelain 은 tracked 변경 + untracked 를 모두 낸다. 둘 다 tarball 에 실릴 수 있으므로
# 둘 다 본다 (files[] 밖 파일은 어차피 안 실리지만, 그 판정은 이 검사의 일이 아니다 —
# package_coverage_check 가 별도로 본다. 여기서는 «트리가 커밋과 다르다» 만 판정한다).
DIRTY="$(git status --porcelain 2>/dev/null)"

if [ -z "$DIRTY" ]; then
  echo "  ✅ PASS — working tree matches HEAD (no uncommitted or untracked content to ship)"
  exit 0
fi

_n=$(printf '%s\n' "$DIRTY" | grep -c .)
echo "  ❌ BLOCKED — ${_n} uncommitted/untracked path(s). publish would ship the TREE, including these:"
printf '%s\n' "$DIRTY" | sed 's/^/       /'
echo ""
echo "     🟥 공유 체크아웃이면 이 중 일부는 **다른 세션의 초안**일 수 있다."
echo "        커밋 경계의 사고는 사후에 보이지만, 출하 경계의 사고는 사후에도 안 보인다."
echo "     처방 — 커밋하거나 stash 하거나, 깨끗한 worktree 에서 publish 하라."
echo "        ⚠️ 공유 체크아웃에서 \`git stash\` 는 **남의 미커밋분을 통째로 삼킨다**. 쓰지 마라."
echo "     알고도 강행: PUBLISH_DIRTY_OK=1 npm publish …"

if [ "${PUBLISH_DIRTY_OK:-}" = "1" ]; then
  echo ""
  echo "  ⚠️ PUBLISH_DIRTY_OK=1 — 명시 ACK 로 통과시킨다. 위 목록이 tarball 에 실린다."
  exit 0
fi
exit 1
