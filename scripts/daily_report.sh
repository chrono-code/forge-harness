#!/usr/bin/env bash
# daily_report.sh — 어제 무엇을 했는지 **LLM 없이** 집계한다.
#
# ── 왜 (복원 기록) ──
#   이 스크립트는 2026-08-29 에 한 번 돌아 `tracks/_meta/daily_report_2026-08-28.md` 를 냈고,
#   그 뒤 **사라졌다** — git 이력에 추가된 적이 없고(`--diff-filter=A --all` 0건) plist 도
#   설치돼 있지 않았다. 그런데 운영자의 로컬 바인딩은 「매일 07:30 launchd」로 적어두고 있었다.
#   🟥 **규칙이 자기 기계를 잘못 서술하는** 형태다(`[[feedback_rule_misdescribes_its_own_machine]]`).
#   `launchd_wiring_check.sh` 를 지은 날 그 검사가 이걸 찾아냈다. 이 파일은 그 복원이고,
#   명세는 둘에서 왔다 — 운영자 바인딩(집계 대상·경로·오버라이드)과 **살아남은 산출물 1건**(포맷).
#
# ── 하는 것 / 안 하는 것 ──
#   ✅ `~/projects/*` 의 git 레포에서 **어제 하루** 본인 커밋을 모은다 (LLM 호출 0)
#   ✅ 그날의 `tracks/_meta/fh_completed_<날짜>.md` 를 통째로 싣는다
#   🟥 판단하지 않는다. 요약하지 않는다. **집계만** 한다 — 판단이 섞이면 그날의 기록이 아니라
#      그날에 대한 «해석»이 되고, 나중에 인용할 때 무엇이 사실인지 안 갈린다.
#
# ── 멱등 ──
#   「어제」는 **실행 시각 기준으로 매번 재계산**한다. 같은 날 여러 번 돌려도 같은 파일을
#   덮어쓸 뿐이다. 그래서 재실행이 안전하고, launchd 가 밀린 잡을 깨어나서 돌려도 문제없다.
#
# ── 사용 ──
#   bash scripts/daily_report.sh              # 어제분
#   DR_DATE=2026-08-28 bash scripts/daily_report.sh   # 특정 날짜(테스트/보정)
#   DR_AUTHOR=<email> bash scripts/daily_report.sh    # author 필터 오버라이드
#   bash scripts/daily_report.sh --self-test

set -uo pipefail
FH="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECTS="${DR_PROJECTS:-$HOME/projects}"

# ─────────────────────────────────────────────────────────────────────
# yesterday — 🟥 date(1) 은 GNU/BSD 가 문법이 다르다. 순서만으로 고치면 플랫폼이 하나 더
#   늘 때 또 깨지므로, **결과가 YYYY-MM-DD 인지 검증**까지 한다. 못 얻으면 빈 문자열을
#   돌려주고 호출부가 죽는다 — 틀린 날짜로 조용히 도는 것보다 낫다.
#   (같은 함정을 sync-from-be.sh:116 · digest_landing_check.sh 가 이미 주석으로 남겼다.)
# ─────────────────────────────────────────────────────────────────────
yesterday() {
  local d
  d="$(date -v-1d +%Y-%m-%d 2>/dev/null)" || d=""          # BSD/macOS
  case "$d" in ????-??-??) printf '%s' "$d"; return 0 ;; esac
  d="$(date -d 'yesterday' +%Y-%m-%d 2>/dev/null)" || d=""  # GNU
  case "$d" in ????-??-??) printf '%s' "$d"; return 0 ;; esac
  printf ''
}

# author_filter — 누구의 커밋을 모으나.
#   🟥 **레포 로컬 user.email 이 전역과 다를 수 있다** — 실측 2026-08-30: 이 레포는
#   `test@example.com` 인데 전역은 다른 값이고, 원래 리포트는 전역 쪽으로 걸러져 있었다.
#   조용히 틀린 사람으로 거르면 「그날 커밋 0건」이 나오고 그건 **미측정을 0 으로 렌더**하는 것이다.
#   그래서 값을 고르되 **불일치를 헤더에 표면화**한다(고르는 건 기계, 판단은 사람).
author_filter() {
  [ -n "${DR_AUTHOR:-}" ] && { printf '%s' "$DR_AUTHOR"; return 0; }
  git -C "$FH" config user.email 2>/dev/null || true
}
author_note() {
  [ -n "${DR_AUTHOR:-}" ] && { printf 'DR_AUTHOR 지정'; return 0; }
  local loc glob
  loc="$(git -C "$FH" config --local user.email 2>/dev/null || true)"
  glob="$(git config --global user.email 2>/dev/null || true)"
  if [ -n "$loc" ] && [ -n "$glob" ] && [ "$loc" != "$glob" ]; then
    printf '🟥 레포 로컬(%s) ≠ 전역(%s) — 의도한 쪽이 아니면 DR_AUTHOR 로 지정해라' "$loc" "$glob"
  else
    printf '레포 설정'
  fi
}

# repo_commits — 한 레포의 그날 커밋. 없으면 **빈 출력**이고, 호출부가 「없음」을 적는다.
#   🟥 «커밋 0건»과 «레포가 아님»을 같은 침묵으로 내지 않는다 — 호출부에서 갈라 적는다.
repo_commits() {
  local repo="$1" day="$2" who="$3"
  git -C "$repo" log --all --no-merges \
      --since="${day} 00:00:00" --until="${day} 23:59:59" \
      ${who:+--author="$who"} \
      --pretty=format:'  - %h %s (%cr)' 2>/dev/null
}

build() {
  local day="$1" out="$2" who; who="$(author_filter)"
  {
    printf '# Daily Report — %s (어제)\n\n' "$day"
    printf '> Generated %s by scripts/daily_report.sh · author filter: %s (%s)\n\n' \
           "$(date '+%Y-%m-%d %H:%M')" "${who:-<없음 — 전체 author>}" "$(author_note)"
    printf '## Git commits\n\n'
    local any=0 d name c
    for d in "$PROJECTS"/*/; do
      [ -d "$d/.git" ] || continue
      name="$(basename "$d")"
      c="$(repo_commits "$d" "$day" "$who")"
      [ -n "$c" ] || continue
      any=1
      printf '### %s\n%s\n\n' "$name" "$c"
    done
    [ "$any" = 1 ] || printf '_그날 %s 명의 커밋이 없다._\n\n' "${who:-(전체)}"

    local fc="$FH/tracks/_meta/fh_completed_${day}.md"
    printf '## FH 완료 로그 (fh_completed_%s.md)\n\n' "$day"
    if [ -f "$fc" ]; then
      cat "$fc"
    else
      # 🟥 부재를 「한 일이 없다」로 렌더하지 않는다. 파일이 없는 것과 빈 것은 다르다.
      printf '_파일 없음: `tracks/_meta/fh_completed_%s.md` — 기록이 «없다»이지 «일이 없었다»가 아니다._\n' "$day"
    fi
  } > "$out"
}

notify() {  # best-effort. 실패해도 리포트는 이미 디스크에 있다.
  command -v osascript >/dev/null 2>&1 || return 0
  osascript -e "display notification \"$1\" with title \"FH Daily Report\"" >/dev/null 2>&1 || true
}

self_test() {
  local T; T="$(mktemp -d)" || return 10
  local P=0 F=0
  chk(){ if [ "$2" = "$3" ]; then P=$((P+1)); echo "  ✅ $1"; else F=$((F+1)); echo "  ❌ $1 (got=$2 want=$3)"; fi; }

  local y; y="$(yesterday)"
  case "$y" in ????-??-??) chk "L1 yesterday 가 YYYY-MM-DD 를 낸다(플랫폼 무관)" ok ok ;;
               *)          chk "L1 yesterday 가 YYYY-MM-DD 를 낸다(플랫폼 무관)" "[$y]" ok ;; esac
  # 컨트롤: 오늘과 «달라야» 한다. 같으면 -v-1d/-d 가 무시된 것이고 그건 조용한 실패다.
  local today; today="$(date +%Y-%m-%d)"
  if [ "$y" != "$today" ]; then chk "L1-CTRL 어제 ≠ 오늘 (오프셋이 실제로 먹었다)" diff diff
  else chk "L1-CTRL 어제 ≠ 오늘 (오프셋이 실제로 먹었다)" same diff; fi

  # 픽스처 레포 — 실제 커밋을 만들어 집계가 «잡는지» 본다(빈 레포로는 아무것도 증명 못 한다)
  mkdir -p "$T/projects/demo" && ( cd "$T/projects/demo" && git init -q . \
    && git config user.email me@t && git config user.name me \
    && echo x > a.txt && git add a.txt && GIT_AUTHOR_DATE="$y 12:00:00" \
       GIT_COMMITTER_DATE="$y 12:00:00" git commit -qm "fixture: 어제 커밋" ) >/dev/null 2>&1
  local got; got="$(repo_commits "$T/projects/demo" "$y" "me@t")"
  case "$got" in *"fixture: 어제 커밋"*) chk "L2 known-positive: 어제 커밋을 잡는다" hit hit ;;
                 *)                      chk "L2 known-positive: 어제 커밋을 잡는다" miss hit ;; esac
  # known-negative — 다른 author 로 필터하면 안 잡혀야 한다. 없으면 「항상 잡는다」와 구분 안 됨
  local none; none="$(repo_commits "$T/projects/demo" "$y" "someone-else@t")"
  [ -z "$none" ] && chk "L3 known-negative: 다른 author 는 안 잡는다(판별력)" empty empty \
                 || chk "L3 known-negative: 다른 author 는 안 잡는다(판별력)" "nonempty" empty
  # 날짜 창 — 그저께로 물으면 안 잡혀야 한다
  local other; other="$(repo_commits "$T/projects/demo" "1999-01-01" "me@t")"
  [ -z "$other" ] && chk "L4 다른 날짜 창은 안 잡는다" empty empty \
                  || chk "L4 다른 날짜 창은 안 잡는다" nonempty empty

  # 멱등 — 두 번 돌려 바이트 동일
  DR_PROJECTS="$T/projects" PROJECTS="$T/projects"
  build "$y" "$T/r1.md"; build "$y" "$T/r2.md"
  # Generated 시각 줄만 빼고 비교(그 줄은 의도적으로 매번 다르다)
  if diff <(grep -v '^> Generated' "$T/r1.md") <(grep -v '^> Generated' "$T/r2.md") >/dev/null 2>&1; then
    chk "L5 멱등: 재실행이 같은 내용을 낸다(시각 줄 제외)" same same
  else chk "L5 멱등: 재실행이 같은 내용을 낸다(시각 줄 제외)" diff same; fi

  # author 불일치 표면화 — 조용히 틀린 사람으로 거르는 것이 이 스크립트의 최대 실패다
  local _n; _n="$(DR_AUTHOR=x@y author_note)"
  [ "$_n" = "DR_AUTHOR 지정" ] && chk "L7 DR_AUTHOR 가 있으면 그렇게 표기한다" ok ok \
                               || chk "L7 DR_AUTHOR 가 있으면 그렇게 표기한다" "$_n" ok
  build "$y" "$T/r4.md"
  grep -q 'author filter:' "$T/r4.md" && chk "L8 헤더가 필터를 «항상» 명시한다(침묵 금지)" ok ok \
                                      || chk "L8 헤더가 필터를 «항상» 명시한다(침묵 금지)" missing ok

  # 🟥 부재를 「일이 없었다」로 렌더하지 않는다.
  #    초판은 «어제» 날짜로 검사했는데 이 레포엔 어제자 fh_completed 가 **실재**해서
  #    부재 분기를 한 번도 안 탔다 — 픽스처가 조건 위에 있지 않은 판
  #    (`[[feedback_anchor_can_be_decorative]]` 원인 5). 없는 날짜로 강제한다.
  build "1999-01-01" "$T/r3.md"
  grep -q '기록이 «없다»이지 «일이 없었다»가 아니다' "$T/r3.md" \
    && chk "L6 fh_completed 부재를 «일이 없었다»로 안 적는다" ok ok \
    || chk "L6 fh_completed 부재를 «일이 없었다»로 안 적는다" missing ok
  # 컨트롤: 실재하는 날짜면 그 문구가 «안» 나와야 한다. 없으면 「항상 그 문구」와 구분 안 됨.
  local _real; _real="$FH/tracks/_meta/fh_completed_${y}.md"
  if [ -f "$_real" ]; then
    grep -q '기록이 «없다»이지' "$T/r1.md" \
      && chk "L6-CTRL 실재하면 부재 문구가 안 나온다(판별력)" 나옴 안나옴 \
      || chk "L6-CTRL 실재하면 부재 문구가 안 나온다(판별력)" 안나옴 안나옴
  else
    echo "  ⏭  L6-CTRL SKIP — 어제자 fh_completed 가 없어 컨트롤 성립 불가 (**통과 아님**)"
  fi

  rm -rf "$T"
  echo; echo "SELFTEST: $P passed, $F failed"
  [ "$F" = 0 ] || return 1
  return 0
}

case "${1:-run}" in
  --self-test) self_test ;;
  run)
    DAY="${DR_DATE:-$(yesterday)}"
    case "$DAY" in
      ????-??-??) ;;
      *) echo "🟥 날짜를 못 만들었다 — date(1) 이 GNU 도 BSD 도 아니다. 중단한다." >&2; exit 10 ;;
    esac
    mkdir -p "$FH/tracks/_meta"
    OUT="$FH/tracks/_meta/daily_report_${DAY}.md"
    build "$DAY" "$OUT"
    echo "✅ $OUT"
    notify "$DAY 리포트 — $(basename "$OUT")"
    ;;
  *) echo "usage: daily_report.sh [run|--self-test]" >&2; exit 2 ;;
esac
