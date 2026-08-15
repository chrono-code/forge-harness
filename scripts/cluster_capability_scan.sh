#!/usr/bin/env bash
# cluster_capability_scan.sh — 클러스터에 **무엇이 있는지 기계로 발견**하고 필요에 맞춰 순위를 낸다.
#                              (정체성 ① 블로커 (a) — external-harness recommend / cluster-wizard)
#
# ─────────────────────────────────────────────────────────────────────────────
# 왜 지어졌나 — 「FH 가 발견하는 게 아니라 단언하고 있었다」
# ─────────────────────────────────────────────────────────────────────────────
# `ship_readiness_gate.md` ①행이 (a) 를 *"the one that is a **build**, not a check"* 로 남겨뒀고,
# 2026-08-16 실측이 그 이유를 물리적으로 보여줬다:
#
#   · 선언된 capability `.cap` **10개가 전부 FH 자신의 `tracks/_meta/relay/`** 에 있다.
#     이름만 `qasp_*`·`pmh_*` 이고 **FH 가 손으로 쓴 사본**이며, 남의 스크립트로 가는
#     **절대경로를 하드코딩**한다.
#   · 그 하네스들 자신의 레포에 능력 선언은 **0건**이다(qasp-dev 0 · pmh-dev 0).
#   · `relay_channel.sh` 는 `--cap <capfile>` 을 **받기만** 한다 — 발견 기제가 아예 없다.
#
# 그래서 ①행이 (c) 에 대해 적어둔 *"both new nodes live inside FH"* 는 수사가 아니라
# **파일 위치의 사실**이었다. 이 파일은 그 반쪽을 짓는다: **하네스가 자기 레포에서 선언하고,
# FH 는 읽는다.**
#
# ─────────────────────────────────────────────────────────────────────────────
# 이음매 — 무엇을 하고 무엇을 안 하나 (no-reinvention)
# ─────────────────────────────────────────────────────────────────────────────
#   발견 + 순위        ← 이 파일 (신규)
#   합성 + 실행        ← `relay_channel.sh` (이미 있다. 게이트도 그쪽이 갖고 있다)
#   등록 바 검증       ← `capability_registry_check.sh` (M1–M6)
#   선언 진위 관측     ← `capability_effect_probe.sh`
#
# 🟥 **이 파일은 어떤 경로로도 남의 진입점을 실행하지 않는다.** 추천은 목록이지 실행이 아니다.
#    실행이 되는 순간 비가역 표면 게이트를 우회하는 자동 디스패처가 된다.
# 🟥 **읽기 전용이다.** 남의 레포에 선언을 «심어주는» 편의 기능은 만들지 않는다 —
#    선언은 그 하네스가 PR 로 받아들이는 것이지 FH 가 쓰는 게 아니다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 선언 규약 — 새 스키마를 만들지 않는다
# ─────────────────────────────────────────────────────────────────────────────
#   위치:  <harness-repo>/.claude/capabilities/*.cap      ← **tracked**(하네스 소유)
#   스키마: `capability_composition_contract.md` 의 기존 `.cap` 그대로.
#           `id:`·`entry:` 는 필수. 추천에 쓰는 선택 키: `summary:` · `tags:`
#
#   ⚠️ `.claude/registry/LOCAL_SKILL_REGISTRY.md`(gitignored·FH 로컬)와 **다른 자리**다.
#      그쪽은 «이 머신의 FH 가 아는 것», 이쪽은 «그 하네스가 스스로 주장하는 것».
#      둘을 합치지 않는 이유: 전자는 로컬이라 다른 노드가 못 읽고, 그게 (c) 가 안 서던 이유다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 이 스캔이 **증명하지 않는** 것 (과잉주장 금지)
# ─────────────────────────────────────────────────────────────────────────────
# · 후보를 냈다고 그 후보가 **옳다**는 뜻이 아니다. 순위는 **선언된 메타데이터의 함수**이고
#   선언이 틀리면 순위도 틀린다. 선언 진위는 `capability_effect_probe.sh` 의 축이다.
# · 「클러스터에 N개 능력이 있다」는 **선언된 것**의 수이지 **존재하는 것**의 수가 아니다.
# · 매칭은 **어휘**다. 선언이 다른 낱말을 쓰면 못 찾는다 — 그래서 무매칭은 «없다» 가 아니라
#   «이 어휘로는 못 찾았다» 로 출력한다.
#
# Usage:
#   cluster_capability_scan.sh discover                 클러스터 전수 스캔 → 상태표
#   cluster_capability_scan.sh recommend <term> [...]   필요 → 순위 붙은 후보
#   cluster_capability_scan.sh --self-test
#
# Exit:
#   0  COMPLETE   매핑된 하네스 전부가 OK 또는 NONE 으로 해석됐다
#   4  PARTIAL    하나 이상이 UNREACHABLE/MALFORMED — **결과는 불완전하고 그렇게 말한다**
#   10 HARNESS_ERROR  전제 파손(스캔을 시작조차 못 함)
#
# 🟥 4 가 별도 값인 이유: PARTIAL 은 UNVERIFIABLE(3) 이 아니다. 일부는 **실제로 쟀다**.
#    셋을 한 값으로 접으면 «다 봤는데 없다» 와 «절반만 봤다» 가 같은 얼굴이 된다
#    ([[feedback_not_found_is_not_zero_family]]).
set -uo pipefail

RC_COMPLETE=0; RC_PARTIAL=4; RC_HARNESS=10

FH_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
CAP_SUBDIR=".claude/capabilities"

# 프로젝트 루트 규약. `auto_project_mapping.md` 의 매핑 신호는 **빈 `tracks/{name}/` 디렉토리**이고
# ([[feedback_tracks_dir_is_mapped_signal]]), 실물 루트는 `~/projects/{name}` 이다.
# 테스트·다른 배치를 위해 `FH_CLUSTER_ROOTS`(콜론 구분 절대경로 목록)로 통째 대체할 수 있다.
PROJECTS_HOME="${FH_PROJECTS_HOME:-$HOME/projects}"

_die() { printf '❌ %s\n' "$1" >&2; exit "$RC_HARNESS"; }

_key() {  # $1=capfile $2=key → 첫 값 (없으면 빈 문자열)
  sed -n "s/^[[:space:]]*$2:[[:space:]]*//p" "$1" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//'
}

# 매핑된 하네스 열거. 출력: "<name>\t<root>" 줄 목록.
_enumerate_harnesses() {
  if [ -n "${FH_CLUSTER_ROOTS:-}" ]; then
    # 명시 목록(테스트/비표준 배치). 경로 자체가 이름을 준다.
    printf '%s\n' "$FH_CLUSTER_ROOTS" | tr ':' '\n' | while IFS= read -r r; do
      # ★공백만 있는 항목은 **항목이 아니다.** 초판은 `[ -n "$r" ]` 만 봐서 " " 를 하네스 하나로
      #   셌고, 그러면 「대상이 아예 없다」(전제 파손)가 「도달 못 한 하네스 1건」(PARTIAL)로
      #   렌더된다 — 이 파일이 통째로 반대하는 그 접힘이다. 자기 self-test 가 잡았다.
      r="$(printf '%s' "$r" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      [ -n "$r" ] || continue
      printf '%s\t%s\t\n' "$(basename "$r")" "$r"
    done
    return 0
  fi
  # 테스트는 **실제 코드 경로를 그대로 타야 한다** — 함수만 떼어내 재면 그 함수는 초록인데
  # 호출 경로가 깨져 있을 수 있다(초판이 그 형태로 두 레인을 헛돌렸다).
  local TR="${FH_TRACKS_ROOT:-$FH_ROOT/tracks}"
  [ -d "$TR" ] || return 1
  # ★**허브 자신을 먼저 넣는다.** FH 는 `tracks/` 에 자기를 매핑하지 않는다(자기 자신은
  #   «연결된 프로젝트» 가 아니므로 그게 맞다). 그런데 그러면 스캔이 **자기 선언을 못 본다** —
  #   허브도 클러스터의 노드이고, 다른 하네스가 FH 능력을 발견할 수 있어야 방향이 양쪽이 된다.
  #   초판은 이 행이 없어 FH 의 tracked 선언 2건이 시야에서 통째로 빠졌다(실측).
  #   `FH_TRACKS_ROOT` 로 픽스처를 쓸 때는 넣지 않는다 — 그때 대상은 그 픽스처 세계다.
  [ -n "${FH_TRACKS_ROOT:-}" ] || printf '%s\t%s\t%s\n' "forge-harness(hub)" "$FH_ROOT" "self:허브 자신"
  # `_` 접두 디렉토리는 메타(`_meta`/`_audit`/`_chamber`…)이지 매핑 프로젝트가 아니다.
  # 일반 규칙이지 닫힌 목록이 아니다 — CLAUDE.md §Active Onboarding 과 같은 판정.
  for d in "$TR"/*/; do
    [ -d "$d" ] || continue
    local n; n="$(basename "$d")"
    case "$n" in _*) continue ;; esac
    # ★alias 를 **출력 필드로** 싣는다. 초판은 전역 `_ALIAS_USED` 에 담았는데, 이 루프와
    #   소비자(`_harness_status`)가 **다른 서브셸**이라 값이 안 넘어갔다 — 그래서 별칭 표시가
    #   비고 AMBIGUOUS 가드는 **발동 불가능한 죽은 코드**가 됐다. 실제 출력(별칭이 적용된 행의
    #   DETAIL 이 비어 있음)을 보고 잡았다. 가드는 값이 도달해야 가드다.
    local rr; rr="$(_resolve_root "$n")"
    printf '%s\t%s\t%s\n' "$n" "${rr%%|*}" "${rr#*|}"
  done
}

# track 이름 → 레포 루트. **별칭을 명시적으로 시도하고, 어느 것이 맞았는지 상태에 남긴다.**
#
# 왜 필요한가(2026-08-16 실측 — 이 스캐너의 첫 실사용이 잡았다): track 이름과 레포 이름이
# 1:1 이 아니다. `tracks/qasp` ↔ `~/projects/qasp-dev` · `tracks/the_bible` ↔ `~/projects/the-bible`.
# 초판은 이 둘을 UNREACHABLE 로 냈고, 그건 **정직했지만 쓸모가 덜했다** — 실물이 있는데 못 찾은
# 것이기 때문이다.
# 🟥 그래도 «조용히 추측» 하지는 않는다. 별칭은 **닫힌 목록**이고, 맞은 별칭은
#    `_ALIAS_USED` 로 표면화된다. 여러 개가 동시에 맞으면 **고르지 않고 모호로 낸다** —
#    둘 중 하나를 조용히 고르는 것이 이 파일이 반대하는 그 접힘이다.
_resolve_root() {  # $1=track 이름 → "<root>|<alias-note>"
  local n="$1" c hits="" first="" note=""
  for c in "$n" "$n-dev" "$(printf '%s' "$n" | tr '_' '-')"; do
    [ -d "$PROJECTS_HOME/$c" ] || continue
    case " $hits " in *" $c "*) continue ;; esac
    hits="$hits $c"; [ -n "$first" ] || first="$c"
  done
  local nh; nh=$(printf '%s' "$hits" | wc -w | tr -d ' ')
  if [ "${nh:-0}" -gt 1 ]; then
    printf '%s|AMBIGUOUS:%s' "$PROJECTS_HOME/$n" "$(printf '%s' "$hits" | sed 's/^ //;s/ /,/g')"
    return
  fi
  [ -n "$first" ] && [ "$first" != "$n" ] && note="경로 별칭 — alias:$first"
  printf '%s|%s' "$PROJECTS_HOME/${first:-$n}" "$note"
}

# 한 하네스의 상태를 판정한다. 출력 한 줄: "<name>\t<STATUS>\t<n>\t<detail>"
#   OK / NONE / UNREACHABLE / MALFORMED
_harness_status() {  # $1=name $2=root $3=alias-note
  local name="$1" root="$2" dir="$2/$CAP_SUBDIR" alias_note="${3:-}"
  case "$alias_note" in
    AMBIGUOUS:*)
      # 🟥 여러 레포가 한 track 이름에 맞는다. 고르지 않는다 — 고르면 «어느 하네스를 쟀는지»
      #    아무도 모르게 된다. 사람이 매핑을 정리해야 한다.
      printf '%s\tAMBIGUOUS\t0\t한 track 이름에 레포 여럿: %s — 매핑을 정리해야 한다\n' \
        "$name" "${alias_note#AMBIGUOUS:}"; return ;;
  esac
  if [ ! -d "$root" ]; then
    printf '%s\tUNREACHABLE\t0\t레포 루트 없음: %s\n' "$name" "$root"; return
  fi
  if [ ! -d "$dir" ]; then
    printf '%s\tNONE\t0\t선언 디렉토리 없음: %s\n' "$name" "$CAP_SUBDIR"; return
  fi
  local n=0 bad=0 f
  for f in "$dir"/*.cap; do
    [ -f "$f" ] || continue
    if [ -z "$(_key "$f" id)" ] || [ -z "$(_key "$f" entry)" ]; then
      bad=$((bad+1))
    else
      n=$((n+1))
    fi
  done
  if [ "$bad" -gt 0 ]; then
    printf '%s\tMALFORMED\t%d\t%d개 선언이 id 또는 entry 를 빠뜨렸다\n' "$name" "$n" "$bad"; return
  fi
  if [ "$n" -eq 0 ]; then
    printf '%s\tNONE\t0\t디렉토리는 있으나 유효한 .cap 0건\n' "$name"; return
  fi
  printf '%s\tOK\t%d\t%s\n' "$name" "$n" "${alias_note:+$alias_note}"
}

# ── discover ────────────────────────────────────────────────────────────────
cmd_discover() {
  local rows; rows="$(_enumerate_harnesses)" || _die "tracks/ 를 못 읽는다 — 매핑 목록이 전제다"
  [ -n "$rows" ] || _die "매핑된 하네스 0건 — 스캔 대상이 없다(전제 파손이지 «능력 0» 이 아니다)"

  printf 'cluster capability scan — 선언 위치: <repo>/%s\n' "$CAP_SUBDIR"
  printf '%-18s %-12s %5s  %s\n' "HARNESS" "STATUS" "CAPS" "DETAIL"
  printf -- '---------------------------------------------------------------\n'

  local partial=0 total=0 okn=0
  while IFS=$'\t' read -r name root alias_note; do
    [ -n "$name" ] || continue
    local line; line="$(_harness_status "$name" "$root" "$alias_note")"
    local st cnt detail
    st="$(printf '%s' "$line" | cut -f2)"
    cnt="$(printf '%s' "$line" | cut -f3)"
    detail="$(printf '%s' "$line" | cut -f4)"
    printf '%-18s %-12s %5s  %s\n' "$name" "$st" "$cnt" "$detail"
    total=$((total+1))
    case "$st" in
      OK) okn=$((okn+cnt)) ;;
      UNREACHABLE|MALFORMED|AMBIGUOUS) partial=1 ;;
    esac
  done <<EOF
$rows
EOF

  printf -- '---------------------------------------------------------------\n'
  printf '하네스 %d개 · 선언된 능력 %d개\n' "$total" "$okn"
  if [ "$partial" = "1" ]; then
    printf '⚠️  PARTIAL — 도달 못 했거나 파손된 선언이 있다. **이 목록은 클러스터의 전부가 아니다.**\n'
    return "$RC_PARTIAL"
  fi
  printf '✅ COMPLETE — 매핑된 하네스 전부를 해석했다(«없음» 도 해석 결과다)\n'
  return "$RC_COMPLETE"
}

# ── recommend ───────────────────────────────────────────────────────────────
# 매칭은 선언 텍스트(id · summary · tags)에 대한 **어휘 일치 개수**다. 판정이 아니라 후보다.
cmd_recommend() {
  [ "$#" -ge 1 ] || _die "usage: recommend <term> [term ...]"
  local rows; rows="$(_enumerate_harnesses)" || _die "tracks/ 를 못 읽는다"
  [ -n "$rows" ] || _die "매핑된 하네스 0건"

  local tmp; tmp="$(mktemp -d)" || _die "mktemp 실패"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT INT TERM
  local hits="$tmp/hits"; : > "$hits"

  local partial=0 scanned=0
  while IFS=$'\t' read -r name root alias_note; do
    [ -n "$name" ] || continue
    local dir="$root/$CAP_SUBDIR"
    if [ ! -d "$root" ] || [ ! -d "$dir" ]; then
      [ -d "$root" ] || partial=1
      continue
    fi
    local f
    for f in "$dir"/*.cap; do
      [ -f "$f" ] || continue
      local id; id="$(_key "$f" id)"
      [ -n "$id" ] || { partial=1; continue; }
      scanned=$((scanned+1))
      local hay score=0 t
      hay="$(printf '%s %s %s' "$id" "$(_key "$f" summary)" "$(_key "$f" tags)" | tr '[:upper:]' '[:lower:]')"
      for t in "$@"; do
        case "$hay" in *"$(printf '%s' "$t" | tr '[:upper:]' '[:lower:]')"*) score=$((score+1)) ;; esac
      done
      [ "$score" -gt 0 ] || continue
      printf '%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$score" "$name" "$id" \
        "$(_key "$f" residency)" "$(_key "$f" approval)" "$(_key "$f" reversibility)" \
        "$(_key "$f" writes)" "$f" >> "$hits"
    done
  done <<EOF
$rows
EOF

  printf 'cluster recommend — 검색어: %s\n' "$*"
  printf -- '---------------------------------------------------------------\n'
  local nh; nh="$(grep -c . "$hits" 2>/dev/null || true)"; nh=$(( ${nh:-0} + 0 ))
  if [ "$nh" -eq 0 ]; then
    # 🟥 무매칭을 «없다» 로 렌더하지 않는다. 무엇을 얼마나 봤는지 같이 말한다.
    printf '후보 0건 — 다만 이것은 «클러스터에 그런 능력이 없다» 가 아니다:\n'
    printf '  · 스캔한 선언 수: %d\n' "$scanned"
    printf '  · 매칭은 **어휘 일치**다. 선언이 다른 낱말을 쓰면 못 찾는다\n'
    printf '  · 선언 자체가 없는 하네스는 `discover` 가 NONE 으로 구분해 보여준다\n'
  else
    printf '%-5s %-14s %-34s %-16s %s\n' "SCORE" "HARNESS" "ID" "RESIDENCY" "제약(approval/rev/writes)"
    # 점수 내림차순. `sort -rn` 은 첫 필드 기준.
    sort -rn "$hits" | while IFS=$'\t' read -r score name id residency approval rev writes path; do
      # 🟥 residency 가드 — company/operator-private 는 **id 와 점수만** 내보낸다.
      #    경로·스크립트명은 조직 식별자가 될 수 있고, 이 출력은 붙여넣기 되는 표면이다.
      case "$residency" in
        company|operator-private)
          printf '%-5s %-14s %-34s %-16s %s\n' "$score" "$name" "$id" "$residency" \
            "🔒 제약·경로 비표시(residency)"
          ;;
        *)
          printf '%-5s %-14s %-34s %-16s %s/%s/%s\n' "$score" "$name" "$id" "${residency:-unset}" \
            "${approval:-?}" "${rev:-?}" "${writes:-?}"
          ;;
      esac
    done
    printf -- '---------------------------------------------------------------\n'
    printf '후보 %d건 · 스캔한 선언 %d건\n' "$nh" "$scanned"
  fi
  printf '\n🟥 이 출력은 **추천이지 실행이 아니다.** 합성·실행은 `relay_channel.sh --cap <capfile>` 소관이고\n'
  printf '   등록 바(M1–M6)와 비가역 표면 게이트는 그쪽에 있다. 여기서 진입점을 돌리지 않는다.\n'
  if [ "$partial" = "1" ]; then
    printf '⚠️  PARTIAL — 도달 못 한 하네스나 파손된 선언이 있다. `discover` 로 무엇이 빠졌는지 봐라.\n'
    return "$RC_PARTIAL"
  fi
  return "$RC_COMPLETE"
}

# ── self-test ───────────────────────────────────────────────────────────────
self_test() {
  local T rc out p=0 f=0
  T="$(mktemp -d)" || { echo "❌ mktemp 실패"; return 10; }
  _lane() {  # $1=이름 $2=기대rc $3=실제rc $4=출력에 있어야 할 문자열(선택) $5=출력
    local why=""
    if [ -n "${4:-}" ] && ! printf '%s' "${5:-}" | grep -q -- "$4"; then
      why=" — rc 는 맞지만 귀속이 틀렸다: '$4' 가 출력에 없다"
    fi
    if [ "$3" = "$2" ] && [ -z "$why" ]; then p=$((p+1)); printf '  ✅ %-46s rc=%s\n' "$1" "$3"
    else f=$((f+1)); printf '  ❌ %-46s rc=%s (기대 %s)%s\n' "$1" "$3" "$2" "$why"; fi
  }

  echo "cluster_capability_scan --self-test"

  # 픽스처: 하네스 4종 — OK / NONE(디렉토리 없음) / MALFORMED / UNREACHABLE
  mkdir -p "$T/alpha/$CAP_SUBDIR" "$T/beta" "$T/gamma/$CAP_SUBDIR"
  cat > "$T/alpha/$CAP_SUBDIR/leak.cap" <<'EOF'
id: alpha:leak-scan
entry: bash scripts/leak.sh
summary: public surface leak detection for shipped files
tags: leak security publish
residency: public
approval: auto
reversibility: reversible
writes: read-only
EOF
  cat > "$T/alpha/$CAP_SUBDIR/secret.cap" <<'EOF'
id: alpha:corp-lint
entry: bash scripts/corp.sh
summary: internal corporate lint
tags: lint company
residency: company
approval: ask
reversibility: reversible
writes: read-only
EOF
  cat > "$T/gamma/$CAP_SUBDIR/broken.cap" <<'EOF'
summary: 이 선언은 id 도 entry 도 없다
tags: leak
EOF
  local ROOTS="$T/alpha:$T/beta:$T/gamma:$T/delta-does-not-exist"

  # ── L1 discover: 네 상태를 **각각의 이름으로** 구분하는가 ──────────────────
  out="$(FH_CLUSTER_ROOTS="$ROOTS" bash "$SELF" discover 2>&1)"; rc=$?
  _lane "L1 discover 는 UNREACHABLE 을 이름으로 낸다" 4 "$rc" "UNREACHABLE" "$out"
  _lane "L2 discover 는 MALFORMED 를 이름으로 낸다" 4 "$rc" "MALFORMED" "$out"
  _lane "L3 discover 는 NONE 을 이름으로 낸다" 4 "$rc" "NONE" "$out"
  # ★핵심 컨트롤: 넷을 「0건」으로 접지 않는다. PARTIAL 문구가 살아 있어야 한다.
  _lane "L4 불완전 스캔은 PARTIAL 로 말한다(0으로 접지 않음)" 4 "$rc" "이 목록은 클러스터의 전부가 아니다" "$out"

  # ── L5 known-negative: 전부 해석되면 COMPLETE(0) 여야 한다 ────────────────
  out="$(FH_CLUSTER_ROOTS="$T/alpha:$T/beta" bash "$SELF" discover 2>&1)"; rc=$?
  _lane "L5 전부 해석되면 COMPLETE (과차단 아님)" 0 "$rc" "COMPLETE" "$out"

  # ── L6 recommend: 어휘가 맞으면 후보를 낸다 ───────────────────────────────
  out="$(FH_CLUSTER_ROOTS="$T/alpha:$T/beta" bash "$SELF" recommend leak 2>&1)"; rc=$?
  _lane "L6 recommend 가 매칭 후보를 낸다" 0 "$rc" "alpha:leak-scan" "$out"

  # ── L7 residency 가드: company 선언은 제약·경로를 안 내보낸다 ─────────────
  out="$(FH_CLUSTER_ROOTS="$T/alpha:$T/beta" bash "$SELF" recommend lint 2>&1)"; rc=$?
  _lane "L7 company 선언은 비표시로 나온다" 0 "$rc" "🔒 제약·경로 비표시" "$out"
  # 그리고 **경로가 실제로 안 새는지** 별도로 단언한다 — 문구가 있는 것과 유출이 없는 것은 다른 명제다.
  if printf '%s' "$out" | grep -q 'scripts/corp.sh'; then
    f=$((f+1)); printf '  ❌ %-46s (company 경로가 출력에 샜다)\n' "L7b residency 유출 없음"
  else
    p=$((p+1)); printf '  ✅ %-46s\n' "L7b residency 유출 없음"
  fi

  # ── L8 무매칭을 «없다» 로 렌더하지 않는다 ─────────────────────────────────
  out="$(FH_CLUSTER_ROOTS="$T/alpha:$T/beta" bash "$SELF" recommend zzzznotathing 2>&1)"; rc=$?
  _lane "L8 무매칭은 «없다» 가 아니라 «못 찾았다»" 0 "$rc" "«클러스터에 그런 능력이 없다» 가 아니다" "$out"

  # ── L9 실행하지 않는다 — 진입점이 돌면 즉시 알 수 있는 카나리아 ───────────
  # 이 레인이 이 파일의 **가장 중요한 안전 불변식**을 잰다: 추천은 실행이 아니다.
  local CANARY="$T/EXECUTED_CANARY"
  mkdir -p "$T/epsilon/$CAP_SUBDIR"
  cat > "$T/epsilon/$CAP_SUBDIR/x.cap" <<EOF
id: epsilon:tripwire
entry: /usr/bin/touch $CANARY
summary: leak tripwire
tags: leak
residency: public
EOF
  out="$(FH_CLUSTER_ROOTS="$T/epsilon" bash "$SELF" recommend leak 2>&1)"; rc=$?
  if [ "$rc" = "0" ] && [ ! -e "$CANARY" ]; then
    p=$((p+1)); printf '  ✅ %-46s (진입점 미실행)\n' "L9 추천은 실행이 아니다"
  else
    f=$((f+1)); printf '  ❌ %-46s rc=%s · 카나리아=%s\n' "L9 추천은 실행이 아니다" "$rc" \
      "$([ -e "$CANARY" ] && echo 실행됨 || echo 미실행)"
  fi

  # ── L11 별칭 해석: 이름이 안 맞아도 찾고, **찾았다는 사실을 말한다** ──────
  #   `tracks/foo` ↔ `~/projects/foo-dev` 는 이 환경의 실제 규약이다.
  #   ★함수를 떼어내 재지 않고 **실물 discover 를 그대로 태운다** — 초판은 함수만 추출해
  #     재려다 두 레인이 헛돌았다(호출 경로가 아니라 발췌를 잰 것이다).
  local PH="$T/projects" TR="$T/tracks"
  mkdir -p "$PH/zeta-dev/$CAP_SUBDIR" "$TR/zeta"
  cat > "$PH/zeta-dev/$CAP_SUBDIR/z.cap" <<'EOF'
id: zeta:thing
entry: /bin/true
summary: alias probe
tags: alias
residency: public
EOF
  out="$(FH_PROJECTS_HOME="$PH" FH_TRACKS_ROOT="$TR" bash "$SELF" discover 2>&1)"; rc=$?
  _lane "L11 별칭으로 찾고 그 사실을 표면화한다" 0 "$rc" "alias:zeta-dev" "$out"

  # ── L12 모호는 **고르지 않는다** — 죽은 가드였던 자리를 레인으로 고정한다 ──
  #   초판은 이 판정을 전역 변수에 담았고 소비자가 **다른 서브셸**이라 값이 안 넘어갔다.
  #   가드는 있었는데 **발동 불가능**했고, 그건 실제 출력(별칭 칸이 빔)을 보고서야 드러났다.
  mkdir -p "$PH/eta" "$PH/eta-dev" "$TR/eta"
  out="$(FH_PROJECTS_HOME="$PH" FH_TRACKS_ROOT="$TR" bash "$SELF" discover 2>&1)"; rc=$?
  _lane "L12 후보 둘이면 고르지 않고 AMBIGUOUS" 4 "$rc" "AMBIGUOUS" "$out"

  # ── L10 전제 파손은 «능력 0» 이 아니다 ────────────────────────────────────
  out="$(FH_CLUSTER_ROOTS=" " bash "$SELF" discover 2>&1)"; rc=$?
  _lane "L10 대상 0건은 HARNESS_ERROR(«능력 0» 아님)" 10 "$rc" "전제 파손" "$out"

  rm -rf "$T"
  echo "── cluster_capability_scan 캘리브레이션 $([ "$f" -eq 0 ] && echo 통과 || echo 실패): $p PASS / $f FAIL ──"
  [ "$f" -eq 0 ]
}

SELF="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/$(basename "${BASH_SOURCE[0]:-$0}")"

case "${1:-}" in
  discover)   shift; cmd_discover "$@"; exit $? ;;
  recommend)  shift; cmd_recommend "$@"; exit $? ;;
  --self-test) self_test; exit $? ;;
  *) printf 'usage: %s discover | recommend <term> [...] | --self-test\n' "$0" >&2; exit "$RC_HARNESS" ;;
esac
