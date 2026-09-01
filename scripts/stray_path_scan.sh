#!/usr/bin/env bash
# stray_path_scan — «명령 출력이 경로가 된» 디렉터리를 찾는다.
#
# 🟥 왜 별도 계기가 필요한가 (2026-08-31 실측):
#   `git status --porcelain` 도 `-uall` 도 **빈 디렉터리를 안 보여준다.**
#   known-pair: 빈 디렉터리 → 히트 0 · 파일 하나 넣으면 → 히트 1(컨트롤, git 은 살아 있다).
#   그래서 이 클래스는 `git status` 로 «부재 증명»이 안 된다 — 하루에 세 번 났고
#   (거버너 레포 2 · 병렬 팔 레포 1) 세 번 다 «트리 깨끗» 보고 뒤에 발견됐다.
#
# 기전: 픽스처가 `d="$(... )"` 로 경로를 잡는데 그 명령이 실패하면 stdout(예: `git -C ""`
#   의 «On branch …» 상태블록)이 그대로 «경로»가 되어 `mkdir -p` 가 그 이름으로 트리를 판다.
#   `git commit -q` 는 성공 요약만 죽이고 실패 상태블록은 안 죽인다.
#   짝: [[feedback_not_found_is_not_zero_family]] — 빈 값을 기대한 자리에 내용이 들어왔다.
#
# 판별 (union 둘 — 하나로는 못 덮는다):
#   ⓐ 이름에 **개행**이 든 디렉터리 — 정당한 경우가 없다
#   ⓑ 이름이 **git 상태 문구로 시작** — 출력이 한 줄만 남아 ⓐ 로는 안 잡히는 경우
# 🟥 «빈 디렉터리 전수»로 잡지 않는다. 이 레포의 빈 디렉터리 다수가 **정당**하다
#   (`tracks/{name}/` 은 매핑 신호 · `.claude/worktrees` 등은 도구 자리). 전수는 오탐 기계다.
#
# 종료: 0 = 없음 · 1 = 발견(경로 출력) · 2 = 스캔 불가(미측정 — 0 으로 렌더하지 않는다)
set -u
ROOT="${1:-.}"
[ -d "$ROOT" ] || { echo "STRAY-SCAN: cannot scan '$ROOT'" >&2; exit 2; }

_nl=$(find "$ROOT" -type d -name '*
*' -not -path '*/.git/*' 2>/dev/null)
_kw=$(find "$ROOT" -type d \( -name 'On branch*' -o -name 'nothing to commit*' \
        -o -name 'Your branch*' -o -name 'Changes not staged*' -o -name 'untracked files*' \) \
        -not -path '*/.git/*' 2>/dev/null)
_rc_find=$?
[ "$_rc_find" -ge 2 ] && { echo "STRAY-SCAN: find error rc=$_rc_find — UNMEASURED" >&2; exit 2; }

_hits=$(printf '%s\n%s\n' "$_nl" "$_kw" | sed '/^$/d' | sort -u)
if [ -n "$_hits" ]; then
  echo "🟥 STRAY PATH — 명령 출력이 경로가 된 디렉터리가 있다 (git status 는 이걸 못 본다):"
  printf '%s\n' "$_hits" | sed 's/^/     /'
  echo "     기전: 픽스처의 경로 조립이 실패하고 그 stdout 이 경로가 됐다."
  echo "     처분: 열거 → 파일 유무 확인 → 파기. 그리고 그 픽스처의 경로 조립에 || return 1 을."
  exit 1
fi
exit 0
