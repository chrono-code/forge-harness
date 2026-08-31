#!/usr/bin/env bash
# fixture_guard_lib.sh — 레인 픽스처 루트의 **단일 소스** 가드.
#
# tenet: FH-T02 (기계는 비가역 경계와 채널에만 — 여기서는 «쓰기 대상이 실레포인가»라는 경계)
#
# WHY: 2026-08-31, `test_script_caller_ratchet_lanes.sh` 의 `d="$(cd "$d" && pwd)"` 가 빈 값으로
# 붕괴해 `git -C "" ` = **cwd = 라이브 레포**가 됐고, `commit --no-verify` +
# `core.hooksPath=/nonexistent-fixture-hooks` 라 어떤 훅도 안 걸렸다. 실제로 커밋 하나가
# 작업 브랜치에 얹혔다(`lane <lane@example.invalid> "base"`). 열거→회수 0→`reset --mixed` 로 회수.
#
# WHY A LIB (재발명 점검 결과, 2026-08-31 실측):
#   · `hook_source_lib.sh` = SessionStart 페이로드 파서 — **도메인이 다르다**. 여기 붙이면
#     「훅 소스 파싱」 lib 이 픽스처 안전을 겸하게 되어 두 관심사가 한 파일에 산다.
#   · `psa_scan_lib.sh` = public-surface 스캔. 무관.
#   · 레인 12개 전수 조사: `source`/`.` 를 쓰는 파일 **0개** — 공용 레인 lib 이 **없다**.
#   ⇒ 새 파일이 정당하다. 사본을 11벌 두는 것은 «관대함 갈린 중복 정규화» 를 예약하는 것이다.
#
# 🟥 불변식은 «증상»이 아니라 «원인»이다: `[ -n "$d" ]` 는 빈 값만 보고, **비어 있지 않은데
# 실레포를 가리키는** 경우를 못 잡는다. 이 가드가 보는 것은 **「픽스처는 실레포에 쓰지 않는다」**.
#
# 🟥 값을 반환한다(해석된 절대경로). 호출부가 `d="$(fh_fixture_root "$d")"` 로 쓰므로,
# 이 함수가 죽거나 스텁이 되면 `d` 가 비고 **호출 레인이 즉시 빨개진다** — 가드가 장식이 아님을
# 되돌림으로 잴 수 있게 하는 설계다(순수 부작용 가드는 스텁으로 바꿔도 아무도 안 빨개진다).
#
# 사용:
#   . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"
#   T="$(fh_fixture_root "$(mktemp -d)")"
#
# 이식성: bash 3.2 (stock macOS). `realpath`/`readlink -f` 를 쓰지 않는다 — 둘 다 미보장.

fh_fixture_root() {   # $1 = 후보 픽스처 루트 → stdout: 해석된 절대경로. 위반이면 exit 1.
  [ -n "${1:-}" ] || { echo "FIXTURE-GUARD: empty root — refusing (git -C \"\" would target cwd)" >&2; exit 1; }
  [ -d "$1" ]     || { echo "FIXTURE-GUARD: root does not exist: $1" >&2; exit 1; }
  case "$1" in /|"$HOME") echo "FIXTURE-GUARD: refusing root $1" >&2; exit 1 ;; esac
  _fg_real="$(cd "$1" 2>/dev/null && pwd -P)" || { echo "FIXTURE-GUARD: cannot resolve $1" >&2; exit 1; }
  case "$_fg_real" in /|"$HOME") echo "FIXTURE-GUARD: refusing resolved root $_fg_real" >&2; exit 1 ;; esac
  # 🟥 `BASH_SOURCE[0]` 은 **이 함수가 정의된 파일**(= 이 lib)을 가리킨다. lib 이 scripts/ 에
  #    살므로 `../` 가 레포 루트다. 호출부 위치와 무관하게 같은 답이 나온다 — L4 앵커가 이것을 잰다.
  _fg_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)" || _fg_repo=""
  if [ -n "$_fg_repo" ]; then
    if [ "$_fg_real" = "$_fg_repo" ]; then
      echo "FIXTURE-GUARD: root IS the live repo ($_fg_real) — refusing" >&2; exit 1
    fi
    case "$_fg_real" in
      "$_fg_repo"/*) echo "FIXTURE-GUARD: root is inside the live repo ($_fg_real) — refusing" >&2; exit 1 ;;
    esac
  fi
  printf '%s\n' "$_fg_real"
}
