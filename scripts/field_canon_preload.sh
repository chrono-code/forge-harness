#!/usr/bin/env bash
# field_canon_preload.sh — 매핑된 필드 하네스가 언급되면 **그 하네스의 정본 경로**를 띄운다.
#
# WHY (2026-08-09 실측, 하루 4회 정정 · 자력 적발 0):
#   FH 세션 시작 자동 적재는 **FH 자기 정본만** 싣는다(`fh_session_load.sh` = 동반자 저장소).
#   그런데 한 세션이 종일 qasp 를 파면서 qasp `README.md`(604줄) · `docs/governance/`(32개)를
#   **하나도 안 읽고** 코드에서 역추론했다. 네 번 정정당했고 네 번 다 **정본에 답이 있었다**:
#     · MTM 을 "조건부 화이트박스 모드" 로 요약   → 정본은 블박+화박 **동시**(이중시야)
#     · "매트릭스 = 축이 여럿"                  → 영화 매트릭스에서 **네오가 보는 시야**
#     · 3막 본체가 act2 에 있는 걸 배치 결함 판정 → README 가 **의도**라고 명시(L1 공유·중복 0)
#     · 전수조사 모수를 src/act2 로 한정         → b레인·mate 는 모수 밖
#   README 는 그중 하나를 *"이 축이 안 보이면 3막을 mate 판정 전용으로 오해한다"* 로
#   **경고까지 하고 있었다.** 산문 규율로는 안 읽힌다 — `fh_session_load.sh` 헤더가 이미 같은
#   결론을 적었다("prose is salience-dependent"). 같은 처방을 필드 하네스에 적용한다.
#
# WHAT: 프롬프트에 매핑된 프로젝트 이름이 나오면, **실재하는 정본 파일 경로만** 골라 한 번 띄운다.
#   ★ 일반 훈계("정본을 읽어라")가 아니라 **이 레포의 이 파일들**이어야 한다 — 오늘의 실패는
#     규율을 몰라서가 아니라 **그 파일들이 거기 있는 줄 몰라서**였다.
#
# 프로젝트당 세션당 1회. 센티넬로 재나그 방지 — 반복 알림은 무시를 학습시킨다.
#
# 종료: 항상 0 · 보고는 stdout. (비영 종료는 stdout 이 폐기되고 stderr 도 안 전달된다 —
#       `[[feedback_hook_nonzero_exit_is_silent]]`.)
# ── track→repo 해석: 단일 소스 = scripts/fh_track_resolve.sh ──────────────────
# 🟥 강등 블록은 세 소비자(fh_session_load · field_canon_preload · cluster_capability_scan)에
#    **문자 그대로 동일**해야 한다. 2026-08-21 적대검증 HIGH-2: 초판은 파일마다 별칭을
#    1종/2종/3종으로 다르게 봤고, 그건 «강등 경로가 F-1 결함(갈라진 정규화기)의 완전한
#    복제본» 이라는 뜻이었다. 이제 강등은 **별칭 0종 + 큰 소리**다 — 덜 유용하지만
#    세 파일이 같은 답을 내고, 무엇보다 **조용하지 않다**. skipped 를 passed 로 렌더하지
#    않는다는 이 저장소 규율 그대로다. [[feedback_not_found_is_not_zero_family]]
_FH_TRLIB="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/fh_track_resolve.sh"
# shellcheck source=scripts/fh_track_resolve.sh
[ -f "$_FH_TRLIB" ] && . "$_FH_TRLIB"
# 🟥 `type` 는 **존재**만 재고 **정합**은 못 잰다(잘린 파일·구버전·환경에서 export -f 된 동명
#    함수는 전부 통과한다 — 적대검증 LOW-3). 그래서 라이브러리가 API 버전을 선언하고
#    소비자가 그걸 확인한다. 채널을 타입으로 만드는 것이지 성실성에 기대는 게 아니다.
if ! type fh_resolve_track_root >/dev/null 2>&1 || [ "${FH_TRACK_RESOLVE_API:-}" != "1" ]; then
  printf '⚠️  [track-resolve] DEGRADED — fh_track_resolve.sh 부재 또는 API 불일치. 별칭 해석 없음(밑줄→하이픈·-dev 접미 미적용). 이건 «해당 없음»이 아니라 **미해석**이다.\n'
  fh_resolve_track_root() {
    case "${1-}" in '' |*/*|*'|'*|*'..'* ) printf '|ARGS:bad-name'; return 3 ;; esac
    [ -n "${2-}" ] || { printf '|ARGS:empty-root'; return 3; }
    case "${3:-dir}" in
      git) [ -d "$2/$1/.git" ] && { printf '%s|' "$2/$1"; return 0; } ;;
      dir) [ -d "$2/$1" ]      && { printf '%s|' "$2/$1"; return 0; } ;;
      *)   printf '|ARGS:bad-pred'; return 3 ;;
    esac
    printf '%s|UNRESOLVED' "$2/$1"
    return 1
  }
fi

set -uo pipefail

HUB="${CLAUDE_PROJECT_DIR:-${HOME:-}/projects/forge-harness}"
PROJ_ROOT="${FIELD_CANON_PROJECT_ROOT:-${HOME:-}/projects}"
# ★ `${HOME:-}` — `set -u` 아래서 HOME 부재 시 여기가 unbound 로 죽어 rc=1 이 됐다.
#   비영 종료는 stdout 이 폐기되므로 헤더의 "항상 0" 계약이 깨진다(cross-family 지적, 재현됨).
[ -n "${HUB:-}" ] && [ "$HUB" != "/projects/forge-harness" ] || exit 0
# stdin 은 훅 페이로드(JSON). prompt 를 못 뽑아도 **조용히 죽지 않는다** — 원문 전체로 폴백한다.
# ★ `session_id` 를 **같은 페이로드에서** 뽑는다. 센티넬 키가 여기 달려 있다(바로 아래).
# 🟥 SID 는 **자르거나 치환하지 않고 해시한다.** 초판 수리가 슬래시 치환 + 64자 절단이었는데
#    cross-family(gpt-5.5)가 재현했다: 'A/B' 와 'A_B' 가 같은 키 · 65자 이상은 접두 충돌 ·
#    session_id 에 개행이 들어오면 아래 「1행=SID · 2행이후=PROMPT」 프로토콜이 깨져
#    **프롬프트까지 오염**된다(무관 프롬프트로 발화 실증). 원래 버그(전 세션이 한 칸 공유)와
#    **같은 일가를 수리가 다시 연** 것이다. 해시가 충돌·개행·길이·경로문자를 한 번에 없앤다.
# ⚠️ 아래 python 은 **큰따옴표 문자열**이다 — 주석에 백틱을 넣으면 bash 명령치환이 터진다
#    (이 파일에서 실제로 터뜨렸다. 설명은 여기 bash 주석에 둔다).
RAW=$(cat 2>/dev/null || true)
FIELDS=$(printf '%s' "$RAW" | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
    import hashlib
    sid = d.get('session_id') or ''
    print(hashlib.sha1(sid.encode('utf-8','surrogatepass')).hexdigest()[:16] if sid else '')
    print(d.get('prompt') or '')
except Exception:
    print(''); print('')
" 2>/dev/null)
SID=$(printf '%s' "$FIELDS" | sed -n '1p')
PROMPT=$(printf '%s' "$FIELDS" | sed -n '2,$p')
[ -n "$PROMPT" ] || PROMPT="$RAW"
[ -n "$PROMPT" ] || exit 0

# ── 센티넬 키 — 초판이 여기서 틀렸다 (2026-08-09 첫 실사용 실측으로 수리) ──
# 초판: `${TMPDIR}/fh_field_canon_${CLAUDE_SESSION_ID:-shared}`
#   🟥 **훅 환경에 `CLAUDE_SESSION_ID` 가 없다.** 전 세션이 literal `shared` 한 칸으로 접혔고
#      TMPDIR 는 재부팅까지 산다 → "프로젝트당 **세션당** 1회" 가 실제로는 **"머신당 1회"** 였다.
#      실측: 21:18 의 세션이 qasp 센티넬을 소비 → 21:40 에 실제로 qasp 를 파기 시작한 세션은
#      안내를 **못 받았다**. 이 훅이 막으려던 바로 그 상황에서 침묵했다.
#   ★ 같은 얼굴이 같은 날 다른 스크립트에서도 났다(`branch_claim.sh` 의 `CLAUDE_PID` — 저자 셸엔
#     있고 CI 엔 없어 검사가 무력화). **환경변수 부재가 조용한 폴백으로 접히고 그 폴백이 검사를
#     무력화한다** — 처방은 같다: **페이로드에서 읽고 환경에서 빌리지 않는다.**
#     (`session_id` 는 훅 페이로드 필드다 — `compaction_probe.sh:415` 가 이미 그렇게 읽는다.)
#
# 폴백 방향은 **과다 알림 쪽**이다: 세션을 못 가르면 `$PPID`(CC 프로세스별로 갈린다)로,
# 그것도 없으면 dedup 을 **포기**한다. 침묵보다 중복이 낫다 — 초판 폴백은 조용한 쪽이었고
# 그래서 실패가 안 보였다(`[[feedback_not_found_is_not_zero_family]]`).
# 🟥 **literal 상수로 폴백하지 마라.** 그 순간 전 세션이 한 칸을 공유한다.
if [ -n "${FIELD_CANON_SENTINEL_DIR:-}" ]; then
  SENT_DIR="$FIELD_CANON_SENTINEL_DIR"
elif [ -n "$SID" ]; then
  SENT_DIR="${TMPDIR:-/tmp}/fh_field_canon_sid_${SID}"
elif [ -n "${PPID:-}" ] && [ "${PPID:-0}" != "0" ]; then
  SENT_DIR="${TMPDIR:-/tmp}/fh_field_canon_ppid_${PPID}"
else
  SENT_DIR=""                       # 못 가른다 → dedup 포기(매번 알린다). 침묵 금지.
fi
[ -z "$SENT_DIR" ] || mkdir -p "$SENT_DIR" 2>/dev/null || true

# ── 스킬-정본 분기 (2026-08-29 신설) ─────────────────────────────────────────
# 🟥 왜 «매핑된 프로젝트» 만으로는 부족한가 — 실측이 있다.
#   덱 세션이 `preprep/presentation_checklist.md`(274줄 · A0~M) 와 레인 L1~L6, 용어 파일을
#   **하나도 열지 않고 44판을 구웠다.** 결과: C1 선 굵기 토큰 위반 388/907 = 43%, 그중
#   ~329곳이 그 세션이 **눈대중으로 «발명한» 값**이었다. 그리고 리뷰가 걷어낸 낱말이
#   재유입됐는데 **아무 검사도 안 울렸다**(운영자가 잡았다).
#   🟥 진단이 뒤집힌 자리다: «자산화가 안 됐다» 가 아니라 **«자산은 있는데 안 읽힌다»** 였다.
#   그리고 그 세션의 처방(«진입 트리거를 새로 짓자»)도 반쯤 틀렸다 — 이 훅이 이미 그 기계다.
#   `grep preprep` → 0 · 컨트롤 `grep qasp` → 2 ⇒ 계기는 살아 있고 **커버리지 경계가 빠뜨렸다.**
#   ⇒ 새 트리거를 짓지 않고 **경계를 넓힌다.** 이게 no-reinvention 이 실제로 값을 내는 형태다.
#
# 대상은 «레포» 가 아니라 «허브 안의 스킬»이라 위 해석기(fh_resolve_track_root)를 안 탄다.
# 공유 해석기는 세 소비자가 문자 그대로 같아야 하므로 **건드리지 않고 분기를 덧붙인다.**
# 오탐 정책은 위 루프와 같다: 짧은 낱말의 오탐은 감수한다(세션당 1회라 상한이 한 줄이다).
skill_canon_emit() {
  _sk="$1"; _dir="$HUB/$2"; shift 2
  [ -d "$_dir" ] || return 0
  [ -n "$SENT_DIR" ] && [ -e "$SENT_DIR/skill-$_sk" ] && return 0
  _hit=0
  for _w in "$@"; do
    printf '%s' "$PROMPT" | grep -qiF -- "$_w" && { _hit=1; break; }
  done
  [ "$_hit" -eq 1 ] || return 0
  _lines=""
  for _f in SKILL.md presentation_checklist.md README.md surfaces.example.yaml; do
    [ -f "$_dir/$_f" ] || continue
    _n=$(wc -l < "$_dir/$_f" | tr -d " ")
    _lines="$_lines\n     $_f (${_n}줄)"
  done
  [ -n "$_lines" ] || return 0
  echo ""
  echo "📚 [skill-canon] 발표 작업이 언급됐다 — **눈대중으로 값을 발명하기 전에 이 파일들을 열어라.**"
  echo "  ▸ $_sk  →  $_dir"
  printf "%b\n" "$_lines"
  cat <<'SKEOF'
  ⚠️ 세션당 1회. 실측(2026-08-28): 어느 세션이 이 파일들을 **하나도 안 열고 44판을 구웠고**,
     선 굵기 토큰 위반이 388/907(43%) 났다 — 그중 ~329곳이 그 세션이 발명한 값이다.
     🟥 «자산이 없다» 가 아니라 «있는데 안 읽힌다» 가 이 안내의 존재 이유다.
SKEOF
  [ -z "$SENT_DIR" ] || : > "$SENT_DIR/skill-$_sk" 2>/dev/null || true
}
skill_canon_emit preprep "plugins/fh-commons/skills/preprep" \
  "발표" "장표" "슬라이드" "덱" "대본" "리허설" "presentation" "keynote"

# 매핑된 프로젝트 = tracks/ 하위 디렉토리(언더스코어 접두는 메타라 제외)
mapped=$(ls -d "$HUB"/tracks/*/ 2>/dev/null | while read -r d; do
  b=$(basename "$d")
  [ "${b#_}" = "$b" ] || continue          # 언더스코어 접두 = 메타 디렉토리, 제외
  printf '%s\n' "$b"
done)
[ -n "$mapped" ] || exit 0

emitted=0
for name in $mapped; do
  # 프롬프트에 이름이 나오는가 (대소문자 무시). 짧은 이름의 오탐은 감수 — 과소보다 낫다.
  printf '%s' "$PROMPT" | grep -qiF -- "$name" || continue   # -F: 이름의 regex 문자 오탐/미탐 방지
  [ -n "$SENT_DIR" ] && [ -e "$SENT_DIR/$name" ] && continue   # 이 세션에서 이미 띄웠다

  # 레포 해석은 scripts/fh_track_resolve.sh 가 단일 소스다 (2026-08-21 F-1).
  # 여기 있던 «이름 그대로 → -dev 접미» 2종은 `tracks/the_bible`(→the-bible)을 **무음으로
  # 버렸다** — 밑줄→하이픈 별칭이 없었기 때문이다. 같은 세션에서 cluster_capability_scan.sh 는
  # 그걸 풀고 있었으므로, 갈라진 정규화기가 «한쪽만 통과하는 입력» 을 만든 형태였다.
  # 술어는 `git` 을 유지한다 — 이 훅은 정본 파일을 읽히므로 실제 레포여야 한다.
  rr=$(fh_resolve_track_root "$name" "$PROJ_ROOT" git)
  repo="${rr%|*}"; rnote="${rr##*|}"
  case "$rnote" in
    UNRESOLVED)  continue ;;
    ARGS:*)
      printf '⚠️  [field-canon] 트랙 이름 «%s» 거부(%s) — «레포 없음» 이 아니라 **전제 파손**이다.\n' \
        "$name" "${rnote#ARGS:}"
      continue ;;
    # 🟥 여럿이 맞으면 고르지 않는다 — 어느 레포의 정본을 실었는지 모르게 되는 게 더 나쁘다.
    #    그러나 **고르지 않는 것과 말하지 않는 것은 다르다** (적대검증 MED-3). 라이브러리가
    #    이 값을 «사람이 매핑을 정리해야 한다» 로 정의했는데 그 판정을 사람에게 안 전달하면
    #    판정이 없는 것과 같다 — 이 훅의 계약은 「항상 exit 0 · stdout 보고」라 말할 자리가 있다.
    AMBIGUOUS:*)
      printf '⚠️  [field-canon] 트랙 «%s» 에 레포가 여럿 맞는다(%s) — 고르지 않았다. 정본을 안 실었으니 «없음»이 아니라 **미해석**이다. 매핑을 정리해라.\n' \
        "$name" "${rnote#AMBIGUOUS:}"
      continue ;;
  esac
  [ -n "$repo" ] || continue

  # **실재하는 것만** 싣는다. 없는 파일을 가리키면 다음 사람이 그 지시를 못 믿게 된다.
  lines=""
  [ -f "$repo/README.md" ] && lines="$lines\n     README.md ($(wc -l < "$repo/README.md" | tr -d ' ')줄) — §구조·§지도 절 먼저"
  [ -f "$repo/CLAUDE.md" ] && lines="$lines\n     CLAUDE.md ($(wc -l < "$repo/CLAUDE.md" | tr -d ' ')줄)"
  gov=$(ls "$repo/docs/governance" 2>/dev/null | wc -l | tr -d ' ')
  [ "${gov:-0}" -gt 0 ] && lines="$lines\n     docs/governance/ — 정본 ${gov}개 (용어·모드·계약의 출처)"
  [ -n "$lines" ] || continue

  if [ "$emitted" -eq 0 ]; then
    echo ""
    echo "📚 [field-canon] 매핑된 필드 하네스가 언급됐다 — **코드 역추론 전에 그쪽 정본을 읽어라.**"
    emitted=1
  fi
  echo "  ▸ $name  →  $repo"
  printf '%b\n' "$lines"
  [ -z "$SENT_DIR" ] || : > "$SENT_DIR/$name" 2>/dev/null || true
done

if [ "$emitted" -eq 1 ]; then
  cat <<'EOF'
  ⚠️ 이 안내는 프로젝트당 세션당 1회다. 2026-08-09 실측: 정본 미독으로 하루 4회 정정,
     자력 적발 0 — 네 번 다 답이 정본에 있었고 그중 하나는 README 가 그 오해를 경고까지 했다.
     ★ 필드 하네스 용어를 일반 개념으로 정규화하지 마라(「MTM=화이트박스 모드」가 그 실패다).
EOF
fi
exit 0
