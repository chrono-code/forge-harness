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
    while IFS= read -r c; do
      [ -d "$home/$c" ] || continue
      case " $hits " in *" $home/$c "*) continue ;; esac
      hits="$hits $home/$c"; [ -n "$first" ] || first="$home/$c"
    done <<EOF
$(fh_peer_alias_candidates "$n")
EOF
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
