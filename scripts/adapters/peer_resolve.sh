#!/usr/bin/env bash
# peer_resolve.sh — **어댑터 공용** peer 레포 해석. `source` 전용(직접 실행하지 않는다).
#
# ─────────────────────────────────────────────────────────────────────────────
# 왜 이 파일이 따로 있나 — divergent-normalizer 를 안 만들기 위해
# ─────────────────────────────────────────────────────────────────────────────
# `scripts/cluster_capability_scan.sh` 가 이미 «track 이름 → 레포 루트» 를 푼다
# (`_resolve_root`, `_enumerate_harnesses`). 어댑터가 자기 규칙을 따로 쓰면 **두 계기가
# 서로 다른 트리를 본다** — 스캐너는 `~/projects/qasp-dev` 를 보고 어댑터는 못 찾는 식이다.
# 이 레포는 그 결함 계열을 «관대함 갈린 중복 정규화» 로 이름 붙여 두고 있다.
# 그래서 규칙을 **여기 한 벌만** 두고 세 어댑터가 전부 이걸 부른다.
#
# 🟥 규칙은 `cluster_capability_scan.sh` 를 읽고 그대로 옮긴 것이다:
#   · 루트 목록 : `FH_CLUSTER_ROOTS`(콜론 구분 **레포 루트** 절대경로 목록)가 있으면 그것이
#                 전부다. 없으면 `FH_PROJECTS_HOME`(기본 `$HOME/projects`) 아래를 본다.
#   · 별칭      : `<name>` · `<name>-dev` · `<name>` 의 `_`→`-` — **닫힌 목록**.
#   · 모호      : 둘 이상이 동시에 맞으면 **고르지 않는다.** 조용히 하나를 고르면 «어느
#                 하네스를 쟀는지» 아무도 모르게 된다.
#
# ⚠️ 한 곳에서 의도적으로 갈린다 — 그리고 갈리는 이유를 적는다.
#    스캐너는 «루트 목록이 비었다» 를 `HARNESS_ERROR`(전제 파손)로 낸다. 어댑터도 같다.
#    다만 스캐너는 track 디렉토리를 열거하는 반면 어댑터는 **이름 하나를 찾는다** —
#    그래서 어댑터에는 「루트 목록은 멀쩡한데 그 안에 이 peer 가 없다」는 상태가 따로 있고,
#    그게 `PEER_ABSENT` 다. 스캐너에는 그 자리가 `UNREACHABLE` 로 있다(같은 명제, 다른 이름).
#
# 사용법
#   . "$(dirname "${BASH_SOURCE[0]}")/peer_resolve.sh"
#   if root="$(fh_peer_resolve gstack)"; then ... ; else rc=$?; ... ; fi
#
# fh_peer_resolve <name>
#   stdout : 해석된 레포 루트 (rc=0 일 때만)
#   rc=0   FOUND
#   rc=1   ABSENT      — 루트 목록은 읽었는데 이 peer 가 그 안에 없다
#   rc=2   AMBIGUOUS   — 별칭 여럿이 동시에 맞는다. 고르지 않는다
#   rc=3   NO_ROOTS    — 루트 목록 자체가 비었다(전제 파손. 「없다」가 아니다)
#   stderr : rc!=0 일 때 한 줄 사유

# ── 단일 소스 배선 (2026-08-21 F-1) ──────────────────────────────────────────
# 🟥 위 주석이 «스캐너와 같은 순서여야 한다» 고 **관례로** 적어 두었던 그 중복을 여기서 닫는다.
#    `scripts/fh_track_resolve.sh` 가 track 이름 → 레포 루트 해석의 단일 소스이고,
#    아래 `FH_PROJECTS_HOME` 팔은 그 라이브러리를 부른다.
#
# ⚠️ **`FH_CLUSTER_ROOTS` 팔은 닫히지 않는다 — 조회 모델이 다르기 때문이다.**
#    라이브러리는 «루트 하나 밑의 `$root/$c`» 를 묻는다. 이 팔은 «임의 절대경로 목록의
#    `basename` 이 별칭인가» 를 묻는다. 이름만 같고 의미가 다른 둘을 억지로 합치면 그건
#    이 수리가 막으려는 결함과 같은 종류다. 그래서 그 팔은 자기 열거를 유지한다
#    (⇒ `fh_peer_alias_candidates` 는 남는다. 부재 메시지와 강등 폴백도 이걸 쓴다).
#
# 라이브러리가 없으면 **수리 이전 동작**으로 강등한다 — 다른 세 소비자와 같은 형태다.
# (폴백은 의도적으로 옛 구현 그대로다. 공백 결함까지 포함해서 «수리 이전» 이다.)
_FH_TRLIB="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")/.." 2>/dev/null && pwd)/fh_track_resolve.sh"
# shellcheck source=scripts/fh_track_resolve.sh
[ -f "$_FH_TRLIB" ] && . "$_FH_TRLIB"
type fh_resolve_track_root >/dev/null 2>&1 || fh_resolve_track_root() {
  local n="$1" root="$2" c hits="" first="" nh
  for c in "$n" "${n}-dev" "$(printf '%s' "$n" | tr '_' '-')"; do
    [ -d "$root/$c" ] || continue
    case " $hits " in *" $c "*) continue ;; esac
    hits="$hits $c"; [ -n "$first" ] || first="$c"
  done
  nh=$(printf '%s' "$hits" | wc -w | tr -d ' ')
  if [ "${nh:-0}" -gt 1 ]; then
    printf '%s|AMBIGUOUS:%s' "$root/$n" "$(printf '%s' "$hits" | sed 's/^ //; s/ /,/g')"; return 0
  fi
  [ -n "$first" ] || { printf '%s|UNRESOLVED' "$root/$n"; return 0; }
  [ "$first" = "$n" ] && { printf '%s|' "$root/$n"; return 0; }
  printf '%s|alias:%s' "$root/$first" "$first"
}

# 별칭 후보 — 닫힌 목록. 스캐너의 `_resolve_root` 와 **같은 순서**여야 한다.
fh_peer_alias_candidates() {   # $1=name → 후보를 줄 단위로
  printf '%s\n' "$1" "$1-dev" "$(printf '%s' "$1" | tr '_' '-')"
}

fh_peer_resolve() {   # $1=peer 이름
  local n="${1:-}" c hits="" first="" nh
  [ -n "$n" ] || { printf 'peer-resolve: 이름이 비었다\n' >&2; return 3; }

  if [ -n "${FH_CLUSTER_ROOTS:-}" ]; then
    # 명시 루트 목록. 각 항목이 **레포 루트 자체**다(스캐너와 같은 의미).
    local r b usable=0
    while IFS= read -r r; do
      # 공백만 있는 항목은 항목이 아니다 — 스캐너가 자기 self-test 로 잡은 그 접힘.
      r="$(printf '%s' "$r" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      [ -n "$r" ] || continue
      usable=$((usable + 1))
      b="$(basename "$r")"
      while IFS= read -r c; do
        [ "$b" = "$c" ] || continue
        [ -d "$r" ] || continue
        case " $hits " in *" $r "*) continue ;; esac
        hits="$hits $r"; [ -n "$first" ] || first="$r"
      done <<EOF
$(fh_peer_alias_candidates "$n")
EOF
    done <<EOF
$(printf '%s\n' "$FH_CLUSTER_ROOTS" | tr ':' '\n')
EOF
    if [ "$usable" -eq 0 ]; then
      printf 'peer-resolve: FH_CLUSTER_ROOTS 에 쓸 수 있는 항목이 0개 — 어디를 볼지 자체가 없다(전제 파손이지 «peer 없음» 이 아니다)\n' >&2
      return 3
    fi
  else
    local home="${FH_PROJECTS_HOME:-$HOME/projects}"
    if [ ! -d "$home" ]; then
      printf 'peer-resolve: 프로젝트 홈이 없다: %s (전제 파손이지 «peer 없음» 이 아니다)\n' "$home" >&2
      return 3
    fi
    # 🟥 여기가 단일 소스로 닫힌 자리다. 옛 인라인 루프(별칭 3종 + 공백 구분자 dedup)를
    #    `fh_resolve_track_root` 로 대체한다. 출력 계약은 **아래에서 옛 표기로 복원**한다 —
    #    소비자 4종과 레인은 여전히 rc(0/1/2/3) + 옛 stderr 문구를 읽는다.
    local rr note
    rr="$(fh_resolve_track_root "$n" "$home" dir)"
    note="${rr##*|}"
    case "$note" in
      AMBIGUOUS:*)
        # 옛 표기 복원: 라이브러리는 **후보 이름**을 콤마로 주고, 옛 메시지는 **절대경로**를
        # «, » 로 이어 붙였다. 공백 없는 이름에서는 바이트 동일하다.
        local _l="${note#AMBIGUOUS:}" _c _paths=""
        while IFS= read -r _c; do
          [ -n "$_c" ] || continue
          if [ -n "$_paths" ]; then _paths="$_paths, $home/$_c"; else _paths="$home/$_c"; fi
        done <<EOF
$(printf '%s' "$_l" | tr ',' '\n')
EOF
        printf 'peer-resolve: 한 이름에 레포 여럿 — 고르지 않는다: %s\n' "$_paths" >&2
        return 2
        ;;
      UNRESOLVED)
        first=""   # 아래 공통 «부재» 분기로 떨어진다 (rc=1 · 옛 문구 그대로)
        ;;
      *)
        first="${rr%|*}"
        ;;
    esac
  fi

  nh=$(printf '%s' "$hits" | wc -w | tr -d ' ')
  if [ "${nh:-0}" -gt 1 ]; then
    printf 'peer-resolve: 한 이름에 레포 여럿 — 고르지 않는다: %s\n' \
      "$(printf '%s' "$hits" | sed 's/^ //; s/ /, /g')" >&2
    return 2
  fi
  if [ -z "$first" ]; then
    printf 'peer-resolve: peer «%s» 가 이 머신에 없다(별칭 %s 전부 미해석)\n' \
      "$n" "$(fh_peer_alias_candidates "$n" | tr '\n' '/' | sed 's|/$||')" >&2
    return 1
  fi
  printf '%s' "$first"
  return 0
}
