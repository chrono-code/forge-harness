#!/usr/bin/env bash
# novelty_claim_check.sh — **신규성·부재 주장**이 외부 앵커 없이 서 있는지 기계로 잡는다.
#
# ── 왜 (실측된 결함) ──
# 2026-08-08 세션: 내부 grep 만 돌리고 `net-new` 를 단정했다가 철회했다. 외부 조회는 운영자가
# *"지금 물어봐"* 라고 해서 비로소 돌았다. `persona-innovator` Mode F 는 존재하지만
# **context-entry 제안**이지 짓기 직전 자동 발화가 아니다.
#
# "짓기 직전"은 **의도 트리거**라 훅으로 못 잡는다(go-public 표면과 같은 부류). 그래서 이 계기는
# 발화를 강제하지 않는다 — 대신 **안 물어본 흔적을 커밋 시점에 보이게** 만든다.
# `[[feedback_shift_left_ledger_not_rule]]`: 일반 규율은 살리언스 의존이라 이미 실패했고,
# 구체 목록은 놓칠 여지가 없다. 규율을 한 번 더 적는 대신 원장을 앞단에 놓는다.
#
# ── 왜 하필 이 주장 클래스인가 (방향 비대칭) ──
# `[[feedback_source_grounding_direction_asymmetry]]`: 결함 주장(FAIL)에는 소스 확인을 요구하면서
# 강점·신규성 주장(PASS)은 무검증으로 통과시켜 왔다 = **낙관 방향만 뚫린다.**
# 그리고 부재 주장은 구조적으로 더 나쁘다 — **인용할 대상이 없어서** 팬텀 검사가 원리적으로 안 걸린다
# (phantom-quench 는 *인용된 것이 주장을 지지하는가*를 보지, *인용이 아예 없는 부재 주장*은 못 본다).
# 이 스크립트는 그 빈칸 하나만 본다. 겹침 없음.
#
# ── 이 계기가 재는 것과 못 재는 것 ──
# 잰다:    신규성/부재 주장 옆에 외부 앵커가 있는가 (±N 줄)
# 못 잰다: 그 앵커가 **그 주장을 실제로 지지하는가** — 그건 phantom-quench 의 일이다.
#          앵커 존재가 진위를 못 본다(`[[feedback_metric_measures_presence_not_relation]]`).
#          즉 통과는 "물어는 봤다"까지지 "맞다"가 아니다.
#
# ── 사용 ──
#   bash scripts/novelty_claim_check.sh <file.md> [...]
#   bash scripts/novelty_claim_check.sh --self-test
# ── 종료 코드 ──
#   0  전건 앵커 있음    2  무앵커 주장 있음 (ADVISORY — 단독 차단 금지)    10  입력 불량

set -uo pipefail

# ⚠️ 레인에서 `cmd | grep -q` 를 쓰지 마라. `grep -q` 는 매치 즉시 파이프를 닫고, `pipefail` 이
# 그 SIGPIPE(141)를 파이프라인 실패로 렌더한다 — **출력이 맞는데 레인이 빨개지고, 경합이라 flaky 하다**
# (2026-08-08 실측: 같은 레인이 실행마다 갈렸다). 출력을 변수로 캡처한 뒤 `case` 로 검사한다.

WINDOW=6   # 앵커 탐색 반경(줄). 좁히면 오탐↑, 넓히면 미탐↑ — 6은 FH 문서의 문단 길이 기준

# 강한 신규성·부재 주장만. 일반 부정("없다")은 한국어 문서에 편재해서 넣으면 Grep-Collision
# Treadmill 이 된다(`[[feedback_typed_verdict_channel]]`). 단정 어휘만 좁게 잡는다.
# ⚠️ `net-new` 는 FH 내부 어휘에서 **두 뜻으로 과부하**돼 있다 (실측 2026-08-08, 손 확인 6/6 오탐):
#   ① 세상에 없다 = 신규성 주장 → 외부 앵커 필요
#   ② 이 레인이 새로 찾은 지적("cross-family 가 net-new finding 3건") → 앵커 불요, 로컬 카운트다
# 그래서 `net-new` 단독은 주장으로 안 센다 — **세계-스코프 한정어와 같은 줄일 때만** 센다.
# 나머지 문구(선례 없·상용 0개·no prior art…)는 그 자체로 세계-스코프라 단독으로 센다.
RE_WORLD='(시장|학계|외부|선례|전례|상용|업계|prior art|state of the art|SOTA|공개된|published)'
RE_CLAIM='(선례[[:space:]]*(가[[:space:]]*)?없|전례[[:space:]]*(가[[:space:]]*)?없|유일하|전무하|존재하지[[:space:]]*않는다|시장에[[:space:]]*(는[[:space:]]*)?없|학계엔?[[:space:]]*(는[[:space:]]*)?없|상용[[:space:]]*0개|no prior art|first of its kind|unprecedented|nothing comparable|does not exist anywhere)'

# 외부 앵커 — "세계에 물어본" 흔적
RE_ANCHOR='(arXiv|arxiv|DOI|doi:|https?://|WebSearch|WebFetch|서베이|외부[[:space:]]*(조회|앵커|문헌)|T1|T2|Sources?:|출처|원문[[:space:]]*확인)'

# 언급(mention) 마커 — 규칙 자체를 서술하는 줄
RE_META='(❌|🟥|🚫|금지|forbidden|never|안티패턴|anti-pattern|예:|example:|RE_CLAIM|RE_ANCHOR)'

scan_file() {
  local f="$1" total=0 bad=0 meta=0
  local -a HITS=()
  # `wc -l` 은 **개행을 센다** — 마지막 줄에 개행이 없으면 한 줄 적게 나오고, 앵커 창 상한이
  # 한 줄 짧아져 **주장 자기 줄을 창 밖으로 밀어낸다** → 거짓 무앵커(high 재리뷰 #10).
  # `git show :file` 이 blob 바이트를 그대로 쓰므로 pre-commit 경로에서 실제로 도달 가능하다.
  local nlines; nlines=$(awk 'END{print NR}' "$f" 2>/dev/null)
  [ -z "$nlines" ] && nlines=0

  while IFS= read -r ln; do
    local num="${ln%%:*}" txt="${ln#*:}"
    # ⚠️ 초판은 meta 줄을 **아무 데도 안 세고** continue 했다. 그래서 주장 3건이 전부 meta 어휘를
    # 동반하면 출력이 "주장 없음" 이 된다 — 부분 미스캔을 **깨끗한 코퍼스로** 렌더하는 것이고,
    # 이 계기가 막으라고 존재하는 `not found ≠ 0` 그 자체다(high 리뷰 #9).
    if printf '%s' "$txt" | grep -qE "$RE_META"; then meta=$((meta+1)); continue; fi
    # 인용부호 안의 주장은 지칭이지 발화가 아니다 (judgment_circuit_lint 와 동일 규칙)
    local bare; bare="$(printf '%s' "$txt" | sed -E 's/"[^"]*"/ /g; s/“[^”]*”/ /g; s/「[^」]*」/ /g; s/`[^`]*`/ /g')"
    if printf '%s' "$bare" | grep -qE "$RE_CLAIM"; then :
    elif printf '%s' "$bare" | grep -qE 'net-new' && printf '%s' "$bare" | grep -qE "$RE_WORLD"; then :
    else continue; fi
    total=$((total+1))
    local lo=$(( num - WINDOW )); [ "$lo" -lt 1 ] && lo=1
    local hi=$(( num + WINDOW )); [ "$hi" -gt "$nlines" ] && hi="$nlines"
    if sed -n "${lo},${hi}p" "$f" 2>/dev/null | grep -qE "$RE_ANCHOR"; then
      HITS+=("  ✅ 앵커있음  $f:$num  $(printf '%s' "$txt" | cut -c1-60)")
    else
      bad=$((bad+1))
      HITS+=("  🟥 무앵커    $f:$num  $(printf '%s' "$txt" | cut -c1-60)")
    fi
  done < <(grep -nE "$RE_CLAIM|net-new" "$f" 2>/dev/null)

  echo "── $f"
  if [ "$total" -eq 0 ]; then
    if [ "$meta" -gt 0 ]; then
      echo "   신규성·부재 주장 0건 — 단 ${meta}줄을 언급(meta)으로 제외했다. **전수 스캔이 아니다.**"
      echo "   제외된 줄에 실제 주장이 있을 수 있다 — 미스캔이지 깨끗함이 아니다."
    else
      echo "   신규성·부재 주장 없음"
    fi
    return 0
  fi
  printf '   주장 %d건 · 무앵커 %d건 · 언급제외 %d줄 (앵커 반경 ±%d줄)\n' "$total" "$bad" "$meta" "$WINDOW"
  local h; for h in "${HITS[@]:-}"; do [ -n "$h" ] && echo "$h"; done
  [ "$bad" -eq 0 ] && return 0 || return 2
}

self_test() {
  local T f=0 n=0 rc
  T=$(mktemp -d); trap 'rm -rf "$T"' RETURN
  t() { n=$((n+1)); if [ "$2" = "$3" ]; then echo "✅ $1 → $3"; else echo "❌ $1 → $3 (기대 $2)"; f=1; fi; }
  bad() { scan_file "$1" 2>/dev/null | awk '/무앵커 [0-9]+건/{for(i=1;i<=NF;i++) if($i=="·"){print $(i+2)}}' | tr -d '건'; }

  # known-positive: 앵커 없는 부재 주장
  printf '이 패턴은 선례가 없다.\n그래서 우리가 처음 만든다.\n' > "$T/ungrounded.md"
  scan_file "$T/ungrounded.md" >/dev/null 2>&1; rc=$?
  t "무앵커 부재 주장 → exit 2" 2 "$rc"

  # known-negative: 같은 주장 + 외부 앵커
  printf '이 패턴은 선례가 없다 (arXiv 2607.08032 서베이가 그렇게 진술한다).\n' > "$T/grounded.md"
  scan_file "$T/grounded.md" >/dev/null 2>&1; rc=$?
  t "앵커 동반 주장 → exit 0" 0 "$rc"

  # 앵커가 반경 안/밖일 때 갈리는가 (계기가 반경을 실제로 쓰는지)
  { printf '이 패턴은 선례가 없다.\n'; for i in $(seq 1 12); do echo "채움 $i"; done; echo "출처: https://example.org"; } > "$T/far.md"
  scan_file "$T/far.md" >/dev/null 2>&1; rc=$?
  t "앵커가 반경 밖 → 여전히 무앵커" 2 "$rc"
  { printf '이 패턴은 선례가 없다.\n'; echo "출처: https://example.org"; } > "$T/near.md"
  scan_file "$T/near.md" >/dev/null 2>&1; rc=$?
  t "앵커가 반경 안 → 통과" 0 "$rc"

  # 주장 자체가 없는 문서는 통과 (과발화 방지)
  printf '오늘은 훅을 배선했다. 캘리브레이션 8/8.\n' > "$T/plain.md"
  scan_file "$T/plain.md" >/dev/null 2>&1; rc=$?
  t "주장 없는 문서 → 무발화 통과" 0 "$rc"

  # 일반 부정은 잡으면 안 된다 (Grep-Collision 방지)
  printf '이 파일에는 마커가 없다. 훅은 차단하지 않는다.\n' > "$T/plainneg.md"
  _o="$(scan_file "$T/plainneg.md" 2>/dev/null)"; case "$_o" in *"주장 없음"*) rc=YES ;; *) rc=NO ;; esac
  t "일반 부정('마커가 없다')은 주장 아님" YES "$rc"

  # 인용 안의 주장은 지칭 (judgment_circuit_lint 와 같은 규칙)
  printf '초판은 "이 패턴은 선례가 없다" 고 적었다가 철회했다.\n' > "$T/quoted.md"
  _o="$(scan_file "$T/quoted.md" 2>/dev/null)"; case "$_o" in *"주장 없음"*) rc=YES ;; *) rc=NO ;; esac
  t "인용 안의 주장은 지칭으로 제외" YES "$rc"

  # ── 회귀 레인: `net-new` 과부하 (2026-08-08 실측, 손 확인 6/6 오탐) ──
  # 원문 그대로. 로컬 발견 라벨은 주장이 아니다.
  cat > "$T/netnew_local.md" <<'EOF'
The one net-new finding was the most severe one.
terra 6/6 known-positives + 5 net-new (approval-negation regex, heredoc tail-drop)
Second consecutive session where the cross-family leg produced net-new findings.
EOF
  _o="$(scan_file "$T/netnew_local.md" 2>/dev/null)"; case "$_o" in *"주장 없음"*) rc=YES ;; *) rc=NO ;; esac
  t "net-new 로컬 발견 라벨 3건 → 주장 아님" YES "$rc"

  # 반대편: 세계-스코프 net-new 는 여전히 잡혀야 한다 (완화가 진짜를 숨기면 안 된다)
  printf 'net-new 다 — 시장에 이런 상용 제품이 하나도 없다.\n' > "$T/netnew_world.md"
  scan_file "$T/netnew_world.md" >/dev/null 2>&1; rc=$?
  t "세계-스코프 net-new 는 여전히 주장" 2 "$rc"

  # 회귀 레인: #9 meta 제외분이 "주장 없음" 으로 렌더되면 안 된다 (high 리뷰 실측)
  cat > "$T/metahidden.md" <<'EOF'
이 아키텍처는 선례가 없다 — 그러니 절대 relabel 하지 마라, never.
시장에 이런 상용 제품은 존재하지 않는다. 금지 사항은 아래와 같다.
EOF
  _o="$(scan_file "$T/metahidden.md" 2>/dev/null)"; case "$_o" in *"전수 스캔이 아니다"*) rc=YES ;; *) rc=NO ;; esac
  t "#9 meta 제외분이 있으면 '깨끗함' 으로 렌더 안 한다" YES "$rc"
  case "$_o" in *"신규성·부재 주장 없음"*) rc=YES ;; *) rc=NO ;; esac
  t "#9 '주장 없음' 단독 출력은 안 나온다" NO "$rc"

  # #10 마지막 줄에 개행이 없어도 앵커 창이 자기 줄을 포함해야 한다 (high 재리뷰)
  printf '더미 줄\n이 패턴은 선례가 없다 (arXiv 2607.08032 서베이).' > "$T/nonl.md"
  scan_file "$T/nonl.md" >/dev/null 2>&1; rc=$?
  t "#10 개행 없는 마지막 줄도 앵커가 잡힌다" 0 "$rc"
  printf '더미 줄\n이 패턴은 선례가 없다 (arXiv 2607.08032 서베이).\n' > "$T/wnl.md"
  scan_file "$T/wnl.md" >/dev/null 2>&1; rc=$?
  t "#10 개행 있는 판본과 동일 판정" 0 "$rc"

  echo
  [ "$f" -eq 0 ] && echo "✅ 캘리브레이션 통과 ($n 쌍)" || echo "❌ 캘리브레이션 실패 ($n 쌍)"
  return "$f"
}

[ "${1:-}" = "--self-test" ] && { self_test; exit $?; }
[ "$#" -eq 0 ] && { echo "usage: $0 <file.md> [...]"; echo "       $0 --self-test"; exit 10; }

WORST=0
for target in "$@"; do
  [ -f "$target" ] || { echo "🟥 파일 없음: $target"; exit 10; }
  scan_file "$target" || WORST=2
done
[ "$WORST" -eq 2 ] && {
  echo
  echo "ⓘ ADVISORY — 차단하지 않는다. 무앵커 주장은 '틀렸다'가 아니라 **'아직 안 물어봤다'** 다."
  echo "   통과해도 앵커가 그 주장을 지지하는지는 별도(phantom-quench) — 존재가 진위를 못 본다."
}
exit "$WORST"
