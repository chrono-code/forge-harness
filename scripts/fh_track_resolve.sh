#!/usr/bin/env bash
# fh_track_resolve.sh — track 이름 → 레포 루트. **sourced 라이브러리다. 실행하지 마라.**
# (선례: scripts/fh_hub_identity.sh — 같은 형태로 훅/스크립트가 `.` 로 읽는다)
#
# 왜 있는가 (2026-08-21 harness-doctor 진단 F-1, 라이브 실측):
#   `tracks/` 이름과 레포 이름은 1:1 이 아니다 — `tracks/qasp` ↔ `~/projects/qasp-dev` ·
#   `tracks/the_bible` ↔ `~/projects/the-bible`. 그런데 이 해석을 **세 소비자가 각각 다르게**
#   구현하고 있었다:
#     scripts/cluster_capability_scan.sh  닫힌 별칭 3종 + 모호거부  → qasp ✅  the_bible ✅
#     scripts/field_canon_preload.sh      `-dev` 접미만            → qasp ✅  the_bible ❌ 무음 continue
#     scripts/fh_session_load.sh          별칭 없음                → qasp ❌  the_bible ❌
#   한 세션에서 동시에 관측됐다: 시작 배너가 «11개 중 2개 못 찾음» 을 내는 동안, 같은 세션의
#   field-canon 훅은 qasp 는 풀고 the-bible 만 빠뜨린 10개를 출력했다. 정규화기가 갈라지면
#   **한쪽만 통과하는 입력이 무음 드롭된다** ([[feedback_divergent_leniency_duplicate_normalizers]]).
#
# 🟥 **덮는 범위를 정직하게 적는다 — 「단일 소스」는 아직 부분 참이다**(적대검증 HIGH-3).
#    2026-08-21 호출 그래프 실측 기준 track→repo 정규화기는 최소 다섯 벌이었다:
#      ✅ fh_session_load.sh · field_canon_preload.sh · cluster_capability_scan.sh — 이 파일로 배선됨
#      ⏳ scripts/adapters/peer_resolve.sh — 같은 별칭 3종을 독립 구현. 배선 진행 중
#      🟥 scripts/fh_env_delta_scan.sh — **역방향**(레포명 → 트랙명), 별칭 0종. 이 파일이 안 덮는다
#         (실측: `tracks/qasp-dev`·`tracks/the-bible` 부재 → 실제 매핑된 레포 2건이 «미매핑 형제»로
#          계상되고, 지금은 `~/.cc_sentinels/*_mapping_skipped` 가 그 나그를 덮고 있다)
#    이 목록이 닫히기 전에는 "모든 해석은 여기서 한다" 고 쓰지 마라.
#
# 🟥 이 파일은 «새 기계» 가 아니다. cluster_capability_scan.sh 가 이미 정답 형태를 갖고 있었고,
#    그걸 단일 소스로 뽑아 나머지 둘이 같이 쓰게 하는 것이다. 별칭 목록은 **닫혀 있고**,
#    맞은 별칭은 호출자에게 **표면화**되며, 여럿이 동시에 맞으면 **고르지 않고 모호로 낸다** —
#    둘 중 하나를 조용히 고르는 것이 이 파일이 막으려는 접힘 그 자체다.
#
# 🟥 존재 술어는 통일하지 않는다 — 소비자마다 다른 것이 **의도**다.
#    cluster 는 «디렉토리가 있나»(`dir`)를, field-canon 은 «git 레포인가»(`git`)를 묻는다.
#    갈라진 것은 별칭 목록이지 술어가 아니었으므로, 술어를 통일하면 한쪽을 조용히 느슨하게
#    (또는 빡빡하게) 만든다. 그건 이 수리가 고치려는 결함과 같은 종류의 결함이다.
#
# ⚠️ 다만 술어가 가르는 것은 **엄격도만이 아니다 — 판정 «클래스» 도 갈린다**(적대검증 MED-5).
#    예: `~/projects/foo`(git 아님) + `~/projects/foo-dev`(git) 가 동시에 있으면
#      pred=dir → 후보 2개 적중 → **AMBIGUOUS**(「매핑을 정리해라」)
#      pred=git → 후보 1개      → **alias 해소**(정상 동작)
#    즉 같은 트랙에 대해 두 소비자가 사람에게 **서로 모순되는 말**을 할 수 있다. 초판 헤더는
#    이 가능성을 안 적었다. 이 머신에서 실제로 갈리는 트랙은 (부분 확인) **못 찾았다** —
#    부재 확인이지 부재 증명이 아니다. [[feedback_rule_misdescribes_its_own_machine]]

# fh_resolve_track_root <track-name> <projects-root> [predicate]
#   predicate: dir (기본, 디렉토리 존재) | git (`.git` 이 있는 레포만)
# stdout: "<root>|<note>"
#   note = ""                    별칭 없이 이름 그대로 맞음
#        | "alias:<cand>"        별칭으로 맞음 — 호출자가 표면화해야 한다
#        | "AMBIGUOUS:<a,b,...>" 여럿이 맞음 — 고르지 않았다. 사람이 매핑을 정리해야 한다
#        | "UNRESOLVED"          아무것도 안 맞음. 🟥 «0» 이 아니라 **미측정**이다
#        | "ARGS:<why>"          전제 파손(빈 이름/빈 루트/경로탈출/알 수 없는 술어)
# 반환값 = 0 해소 · 1 UNRESOLVED · 2 AMBIGUOUS · 3 ARGS. note 와 **둘 다** 판정을 싣는다
#   (note 만 실었더니 종료코드만 읽는 호출자에게 셋이 전부 «성공» 이었다 — cross-family 지적).
fh_resolve_track_root() {
  local n="${1-}" root="${2-}" pred="${3:-dir}"
  local c hits="" first="" nh=0 list=""

  # ── 입력 검증. 🟥 2026-08-21 cross-family(codex/gpt-5.6-sol)가 **실행해서** 반증한 축들이고,
  #    전부 fail-open 방향이었다. 자력 적발 0. 각각이 왜 위험한지 이름으로 남긴다:
  #    ⓐ n="" 이면 첫 후보가 "" 라 `[ -d "$root/" ]` = `[ -d "/" ]` 가 **참**이 된다 → 후보를
  #       세어 놓고 first 는 비어서 UNRESOLVED 로 떨어지는데, **종료코드만 읽는 호출자에겐 통과**다.
  #    ⓑ root="" 이면 `$root/$n` = `/foo` — **의도한 루트가 아닌 파일시스템 루트**를 검사한다.
  #    ⓒ n 에 `/` 나 `..` 가 있으면 루트 **바깥으로 탈출**한 경로도 `-d` 만 참이면 해소된다.
  #       그리고 dedup 이 `/` 를 구분자로 쓰므로 그 불변식도 n 에 `/` 가 없어야 성립한다
  #       (구분자 자체는 codex 가 길이 9 전수 + 랜덤 300만으로 공격해 **거짓 중복을 못 찾았다** —
  #        여기서 막는 것은 구분자가 아니라 경로 탈출이다).
  #    ⓓ n 에 `|` 가 있으면 `"<root>|<note>"` 직렬화가 깨져 **손상된 결과가 정상 성공으로 승격**된다.
  #    ⓔ pred 오타(`gti`)가 `*)` 로 떨어져 조용히 `dir` 모드가 됐다 — **오타가 fail-open** 이었다.
  case "$n" in
    '' ) printf '|ARGS:empty-name'; return 3 ;;
    */*|*'|'*|.|..|*/..|../*|*/../* ) printf '|ARGS:bad-name'; return 3 ;;
  esac
  case "$n" in *'..'* ) printf '|ARGS:bad-name'; return 3 ;; esac
  [ -n "$root" ] || { printf '|ARGS:empty-root'; return 3; }
  case "$pred" in dir|git) ;; *) printf '|ARGS:bad-pred'; return 3 ;; esac

  for c in "$n" "${n}-dev" "$(printf '%s' "$n" | tr '_' '-')"; do
    case "$pred" in
      git) [ -d "$root/$c/.git" ] || continue ;;
      dir) [ -d "$root/$c" ]      || continue ;;
    esac
    # 중복 후보 제거. 🟥 구분자로 **공백을 쓰지 마라** — 이름에 공백이 있으면 한 후보가 둘로
    #    세어져 **거짓 AMBIGUOUS** 가 난다(실측: 실재하는 `a b` → `AMBIGUOUS:a,b`). `/` 는
    #    위 입력 검증이 n 에서 배제하므로 후보 안에도 없다 = 안전한 구분자다.
    case "$hits" in *"/$c/"*) continue ;; esac
    hits="$hits/$c/"
    nh=$((nh + 1))
    if [ -n "$list" ]; then list="$list,$c"; else list="$c"; fi
    [ -n "$first" ] || first="$c"
  done

  # 🟥 «빈 출력 = 깨끗함» 이 되면 안 된다. 그리고 **종료코드도 판정을 실어야 한다** —
  #    초판은 «항상 0, 판정은 note 로» 였는데 cross-family 가 지목했다: 종료코드만 읽는 호출자에게
  #    AMBIGUOUS 와 UNRESOLVED 가 **둘 다 성공**으로 보였다. note 는 그대로 두되 rc 를 타입화한다.
  #      0 = 해소 · 1 = UNRESOLVED · 2 = AMBIGUOUS · 3 = ARGS(전제 파손, «peer 없음» 이 아니다)
  if [ "$nh" -gt 1 ]; then
    printf '%s|AMBIGUOUS:%s' "$root/$n" "$list"
    return 2
  fi
  if [ "$nh" -eq 0 ] || [ -z "$first" ]; then
    printf '%s|UNRESOLVED' "$root/$n"
    return 1
  fi
  if [ "$first" != "$n" ]; then
    printf '%s|alias:%s' "$root/$first" "$first"
    return 0
  fi
  printf '%s|' "$root/$n"
  return 0
}

# 🟥 API 버전 선언 — 소비자의 `type` 가드는 **존재**만 재고 **정합**은 못 잰다(잘린 파일·
#    구버전·환경에서 `export -f` 된 동명 함수가 전부 통과한다). 소비자는 이 값을 확인하고,
#    안 맞으면 강등 + 큰 소리로 알린다. 계약이 바뀌면 이 숫자를 올려라.
FH_TRACK_RESOLVE_API=1
