#!/usr/bin/env bash
# judgment_circuit_lint.sh — 정체성 문서가 **판단 회로**인지 **페르소나 선언**인지 기계로 가른다.
#
# ── 명제 (105런 실측, 2026-08-07~08) ──
# *"정체성 선언 ≠ 판단 회로."* 한 파일 안에 방향이 반대인 둘이 섞여 있고, 측정은 이렇게 갈렸다:
#
#   ❌ 역할 부여 "너는 ~이다"   Haiku 순손실(A 2.00 → B0 1.67) · **제거 시 +0.67 회복**(양 채점자 일치)
#                              외부 앵커: arXiv 2311.10054 — 162 페르소나 · 2,410 MMLU · 9모델, 개선 없음
#   ❌ 강도 주문 "꼼꼼히"        지적 2.8배 · **팬텀 3.1배** · 검출 +0.33 (n=3)
#                              기전: 만족 조건이 모델 자기평가에 맡겨지고 degrade 방향이 무제약 → 분량으로 샌다
#   ✅ 분기·봉인·충돌·방향·형태  전부 검증 가능. 이것이 회로다
#
# **우변은 전부 검증 가능하고 좌변은 전부 검증 불가능하다.** 그게 새는 것과 조이는 것의 경계다.
#
# ── 형제 관계 (셋째 판본을 만들지 마라) ──
# 강도 주문은 FH 독트린 *"prose grants discretion; degrade direction unconstrained"* 의 **프롬프트-층
# 판본**이다. 코드-층 판본은 `scripts/degrade_direction_scan.sh` 이고, 그건 `.py`/`.sh` 만 보고 `.md` 를
# 명시적으로 건너뛴다. 같은 명제 · 다른 코퍼스 · 겹침 0. 합치지도, 옆에 셋째를 만들지도 마라.
# (`harness-doctor --lint` 은 또 다른 축 — 저자의 **마케팅 voice**(self-marketing·cushion·version)를
#  본다. 어휘 교집합 0.)
#
# ── ⚠️ 이 계기의 가장 큰 오채점: 언급(mention) vs 사용(use) ──
# 금지 형식을 **설명하는** 문서(이 스크립트의 헤더 · 심지 설계 정본 · 금지어 표)는 그 어휘를 잔뜩
# 포함한다. 순진하게 grep 하면 **금지형식을 가르치는 문서가 최악 점수**를 받는다 — 계기가 자기를
# 채점하는 함정이고, 2026-08-08 세션이 실제로 밟았다(코퍼스를 자기 regex 에 맞춰 재단).
# 완화: 금지 마커(❌·🟥·금지·forbidden·never·안 된다·쓰지 마라)가 같은 줄에 있으면 **언급**으로 본다.
# ⚠️ **완화지 해결이 아니다** — 마커 없이 금지형식을 서술하는 줄은 여전히 오탐이고, 반대로 마커를
# 달아 놓고 실제로 쓰는 줄은 놓친다. 그래서 이 스크립트는 **advisory 지 게이트가 아니다.**
#
# ── 판정 ──
#   CIRCUIT   금지 0 ∧ 허용형식 ≥3/5     — 판단 회로로 선다
#   PARTIAL   그 사이
#   PERSONA   금지 ≥1 ∧ 허용형식 ≤2/5    — 페르소나 선언이지 회로가 아니다
#
# ── 사용 ──
#   bash scripts/judgment_circuit_lint.sh <file.md> [file.md ...]
#   bash scripts/judgment_circuit_lint.sh --self-test
# ── 종료 코드 ──
#   0  CIRCUIT      2  PARTIAL/PERSONA (ADVISORY — 단독 차단 금지)     10  입력 불량
#
# 히트는 "버그다"가 아니라 **"이게 회로임을 증명하라"** 로 읽어라.

set -uo pipefail

# 금지 ①: 역할 부여 — "너는 ~이다" / "You are a ..."
RE_ROLE='(너는[[:space:]].*(이다|다\.|야\.|이야)|당신은[[:space:]].*(입니다|이다)|[Yy]ou are (a|an|the)[[:space:]])'
# 금지 ②: 강도 주문 — 만족 조건이 모델 자기평가에 맡겨지는 부사/명령
RE_INTENSITY='(꼼꼼히|철저히|신중하게|충분히|깊이를[[:space:]]*더|판단을[[:space:]]*잘|최대한|가능한[[:space:]]*한|반복해서[[:space:]]*보완|thoroughly|carefully|diligently|as much as possible|do your best|be sure to be)'
# 언급(mention) 마커 — 같은 줄에 있으면 사용이 아니라 설명으로 본다
RE_META='(❌|🟥|🚫|금지|forbidden|never|하지[[:space:]]*마라|쓰지[[:space:]]*마라|안[[:space:]]*된다|測|기각|반증|안티패턴|anti-pattern)'

# 허용 5형식 — 존재를 센다 (회로라면 이것들이 있어야 한다)
declare -a ALLOW_NAME=(분기규정 자기봉인 충돌해소 판단방향 형태강제)
declare -a ALLOW_RE=(
  '(못[[:space:]]*찾으면|없으면|실패하면|아니면).*(하지[[:space:]]*마|중단|멈춰|금지|안[[:space:]]*된다)|if[[:space:]].*(not|missing|absent|unavailable).*(do not|stop|abort|block|never)|fail-closed|unless[[:space:]].*(do not|never)'
  '(대상이[[:space:]]*아니다|범위[[:space:]]*밖|다루지[[:space:]]*않는다|out of scope|not the target of)'
  '(상충하면|충돌하면|부딪히면).*(이긴다|우선|우세|앞선다)|(wins|takes precedence|overrides)'
  '(불확실하면|모르면|판단이[[:space:]]*안[[:space:]]*서면|애매하면).*(기운다|쪽으로|보고|default)|when (uncertain|unclear|unsure).*(default|lean|err)|default(s)? to|degrade(s)? (toward|to)'
  # ⚠️ 🟥 명명된 미커버: ALLOW_RE[3] 은 판단방향 형식의 **존재**를 셀 뿐 **방향을 안 본다.**
  # `when unclear, default to PASS` 도 여기서 크레딧을 받는다 — 즉 이 계기는 degrade-toward-PASS
  # 문서를 "판단 회로 있음"으로 셀 수 있다. cross-family 지적 (b), 2026-08-08. 옳은 지적이다.
  #
  # 그런데도 **DENY 로직을 제거했다.** 한 세션에서 세 판본을 시도했고 매번 오류가 방향만 바꿨다:
  #   · 무앵커 부분문자열 → `OK` 가 look·token·broken 에 걸려 정당한 fail-closed 문장의 크레딧을
  #     뺏었다 ("default to blocking and look at the source" 가 4/5→3/5)
  #   · 단어경계로 조이자 → 굴절형이 새어 "default to passing the check" 가 2/5→3/5 로 **승격**,
  #     degrade-toward-PASS 문서를 회로로 인증했다 (net regression)
  #   · 명사형 `default to approval` 은 어느 판본으로도 안 잡혔다
  # 세 번 다 같은 벽이다 — 재려는 성질이 **문장의 방향**인데 계기는 **키워드**다. 키워드는 방향을
  # 판정할 수 없고, 조일수록 반대편 오류가 커진다. 정확도가 안 오르는데 복잡도만 오르는 구간에서는
  # 조이는 게 아니라 줄이는 게 맞다([[feedback_convergence_measured_by_change_not_rounds]]).
  #
  # 그래서 방향 판정은 이 계기의 일이 아니다. 코드 층 판본은 `scripts/degrade_direction_scan.sh`
  # 가 이미 갖고 있고(`.py`/`.sh` 만 본다), **산문 층의 방향은 지금 아무 계기도 커버하지 않는다.**
  # 그게 잔여다 — 셋째 판본을 여기 붙이지 말고, 커버하려면 방향을 볼 수 있는 계기로 따로 지어라.
  # 이 계기가 advisory 라서(게이트 아님) 이 미커버가 fail-open 으로 환전되지는 않는다.
  '```|^\|.*\|.*\||출력[[:space:]]*(형식|칸|형태)|output format'
)

scan_file() {
  local f="$1"
  local role=0 inten=0 mention=0
  local -a HITS=()

  while IFS= read -r ln; do
    local num="${ln%%:*}" txt="${ln#*:}"
    if printf '%s' "$txt" | grep -qE "$RE_META"; then mention=$((mention+1)); continue; fi
    # 인용부호 안의 금지어는 **지칭**이지 발화가 아니다. 판단 회로의 실제 지시는 문서 자신의
    # 목소리로 인용 없이 나온다. 실측 2026-08-08: 실파일 첫 히트 3/3 이 전부 인용 안이었다
    # (트리거 키워드 표 행 · `Not "..."` 부정문 · "나쁜 예시" 인용). 명명된 잔여: **인용부호로
    # 감싸 쓴 진짜 지시는 놓친다** — 그 대가로 오탐을 막는다. advisory 라 방향이 이쪽이 맞다.
    local bare; bare="$(printf '%s' "$txt" | sed -E 's/"[^"]*"/ /g; s/“[^”]*”/ /g; s/「[^」]*」/ /g; s/`[^`]*`/ /g')"
    if ! printf '%s' "$bare" | grep -qE "$RE_ROLE|$RE_INTENSITY"; then
      mention=$((mention+1)); continue
    fi
    # 분류도 $bare 로 한다. $txt 로 하면 "인용은 지칭"이라고 통과시켜 놓고 그 인용을 히트로
    # 기록한다 — cross-family 지적 (d-2), 2026-08-08. 같은 손이 규칙과 테스트를 써서 못 봤다.
    if printf '%s' "$bare" | grep -qE "$RE_ROLE"; then
      role=$((role+1)); HITS+=("  🟥 역할부여   $f:$num  $(printf '%s' "$txt" | cut -c1-72)")
    elif printf '%s' "$bare" | grep -qE "$RE_INTENSITY"; then
      inten=$((inten+1)); HITS+=("  🟥 강도주문   $f:$num  $(printf '%s' "$txt" | cut -c1-72)")
    fi
  done < <(grep -nE "$RE_ROLE|$RE_INTENSITY" "$f" 2>/dev/null)

  local cov=0; local -a MISSING=()
  local i
  for i in "${!ALLOW_RE[@]}"; do
    _hit=$(grep -hoE "${ALLOW_RE[$i]}" "$f" 2>/dev/null | head -20)
    if [ -n "$_hit" ]; then cov=$((cov+1))
    else MISSING+=("${ALLOW_NAME[$i]}"); fi
  done

  local forb=$((role+inten)) verdict
  if   [ "$forb" -eq 0 ] && [ "$cov" -ge 3 ]; then verdict=CIRCUIT
  elif [ "$forb" -ge 1 ] && [ "$cov" -le 2 ]; then verdict=PERSONA
  else verdict=PARTIAL; fi

  echo "── $f"
  printf '   판정: %-8s  금지 %d건 (역할 %d · 강도 %d)  허용형식 %d/5\n' \
         "$verdict" "$forb" "$role" "$inten" "$cov"
  [ "${#MISSING[@]}" -gt 0 ] && echo "   없는 형식: ${MISSING[*]}"
  [ "$mention" -gt 0 ] && echo "   (언급으로 제외한 줄: ${mention}건 — 금지 마커 동반)"
  local h; for h in "${HITS[@]:-}"; do [ -n "$h" ] && echo "$h"; done
  [ "$verdict" = CIRCUIT ] && return 0 || return 2
}

self_test() {
  local T f=0 n=0 rc
  T=$(mktemp -d); trap 'rm -rf "$T"' RETURN
  t() { n=$((n+1)); if [ "$2" = "$3" ]; then echo "✅ $1 → $3"; else echo "❌ $1 → $3 (기대 $2)"; f=1; fi; }
  v() { scan_file "$1" 2>/dev/null | awk '/판정:/{print $2}'; }

  # known-positive ① 실측으로 기각된 형식만 있는 문서 = PERSONA
  cat > "$T/persona.md" <<'EOF'
너는 최고의 QA 엔지니어다.
모든 항목을 꼼꼼히 검토하고 깊이를 더해라.
충분히 반복해서 보완해라.
EOF
  t "역할부여+강도주문만 → PERSONA" PERSONA "$(v "$T/persona.md")"

  # known-negative ① 실측으로 채택된 5형식 = CIRCUIT
  cat > "$T/circuit.md" <<'EOF'
근거를 못 찾으면 그 항목을 보고하지 마라.
성능 최적화는 이 작업의 대상이 아니다.
원문 인용과 비중 추정이 상충하면 원문 인용이 이긴다.
불확실하면 보고 쪽으로 기운다.
출력 형식:
```
[등급] 근거 | 위치
```
EOF
  t "허용 5형식만 → CIRCUIT" CIRCUIT "$(v "$T/circuit.md")"

  scan_file "$T/circuit.md" >/dev/null 2>&1; rc=$?
  t "CIRCUIT 는 exit 0" 0 "$rc"
  scan_file "$T/persona.md" >/dev/null 2>&1; rc=$?
  t "PERSONA 는 exit 2 (advisory)" 2 "$rc"

  # ★ 언급 vs 사용 — 금지형식을 **가르치는** 문서가 최악 점수를 받으면 안 된다
  cat > "$T/teaching.md" <<'EOF'
❌ 금지: "너는 최고의 QA 다" 같은 역할 부여는 쓰지 마라.
❌ 금지: "꼼꼼히", "깊이를 더해라" 같은 강도 주문은 안 된다.
근거를 못 찾으면 보고하지 마라.
성능은 이 작업의 대상이 아니다.
A 와 B 가 상충하면 A 가 이긴다.
EOF
  t "금지형식을 가르치는 문서 → PERSONA 아님" CIRCUIT "$(v "$T/teaching.md")"

  # ★ 그 완화가 진짜 히트까지 숨기면 안 된다 (완화의 known-negative)
  cat > "$T/sneaky.md" <<'EOF'
❌ 금지: 역할 부여는 쓰지 마라.
너는 세계 최고의 보안 전문가다.
모든 것을 꼼꼼히 본다.
EOF
  local sn; sn="$(scan_file "$T/sneaky.md" 2>/dev/null | grep -c '🟥')"
  [ "$sn" -ge 2 ] && rc=YES || rc=NO
  t "마커 있는 줄만 제외 — 실사용 줄은 여전히 잡힌다" YES "$rc"

  # 빈 파일: 금지 0 이지만 허용형식도 0 → CIRCUIT 이면 안 된다 (공허한 통과 방지)
  : > "$T/empty.md"
  t "빈 파일 → CIRCUIT 아님 (공허한 통과 금지)" PARTIAL "$(v "$T/empty.md")"

  # ── 회귀 레인: 실파일 첫 실행에서 나온 오탐 3건 (2026-08-08, 전부 손으로 확인) ──
  # 초판은 실파일 히트 3/3 이 오탐이었고 CLAUDE.md 를 PERSONA 로 오판정했다.
  # 셋 다 **인용부호 안**이라는 공통 구조였다. 원문 그대로 픽스처로 박는다.
  cat > "$T/fp_real.md" <<'EOF'
| "research this deeply", "survey the literature", "comprehensive analysis" | /deep-research |
**Therefore: do not commit FH assets from a worktree.** Not "carry the evidence in carefully"
기계가 혼자 쓰면   "정확하고 신중하게 검증한다" 가 된다    ← 방향이 없다. 검증 불가
EOF
  local fp; fp="$(scan_file "$T/fp_real.md" 2>/dev/null | grep -c '🟥')"
  t "실파일 오탐 3건 재현 → 금지 0건" 0 "$fp"

  # (d-2) 인용을 지칭으로 통과시켰으면 분류도 인용 밖에서 해야 한다
  printf 'Not "너는 심사자이다"; 꼼꼼히 검토하라\n' > "$T/mixed.md"
  local mk; mk="$(scan_file "$T/mixed.md" 2>/dev/null | grep -oE '역할부여|강도주문' | head -1)"
  t "인용 안 역할부여는 세지 않고 실사용 강도주문만" "강도주문" "$mk"

  # ── 🟥 미커버를 **못박는** 레인 (2026-08-08, DENY 제거와 함께 방향이 뒤집혔다) ──
  # 이 계기는 판단방향 형식의 **존재**만 세고 **방향은 안 본다**. 그건 결함이 아니라 결정이다 —
  # 키워드로 방향을 판정하려던 세 판본이 전부 반대편 오류로 갈아탔고(관대문 누락 ↔ 보수문 강등),
  # 정확도가 안 오르는데 복잡도만 오르는 구간이라 조이는 대신 줄였다. 근거는 헤더 ALLOW_RE[3] 주석.
  #
  # ⚠️ 이 레인들을 **삭제하지 마라.** 삭제하면 미커버가 침묵이 되고, 다음 사람이 "방향도 보겠지"
  # 라고 가정하게 된다. 기대값을 뒤집어 남겨 두면 미커버가 **기계로 기록**되고, 누군가 넷째 DENY
  # 판본을 붙이는 순간 여기가 빨개져서 *의도적* 미커버를 건드렸다고 알려준다.
  # ⚠️ **커버리지 숫자에 건다. verdict 에 걸면 못 본다** — 다른 형식이 3개 있으면 판단방향 크레딧
  # 유무와 무관하게 verdict 는 CIRCUIT 로 같다. 지난 라운드 레인이 verdict 에 걸려서 구멍을 놓쳤다.
  _cov() {   # $1=판단방향 자리에 넣을 문장 → "n/5"
    local d; d="$(mktemp -d)"
    printf 'When unclear, default to %s.\n근거를 못 찾으면 보고하지 마라.\n성능은 이 작업의 대상이 아니다.\nA 와 B 가 상충하면 A 가 이긴다.\n' "$1" > "$d/x.md"
    scan_file "$d/x.md" 2>/dev/null | awk '/판정:/{print $NF}'
    rm -rf "$d"
  }
  # 관대 4종과 보수 2종이 **같은 4/5** 를 받는다 = 이 계기는 방향을 구분하지 않는다.
  # 그 동일성 자체가 여기서 검증되는 성질이다.
  t "🟥 미커버: 관대 'PASS' 도 크레딧 받음"      "4/5" "$(_cov 'PASS')"
  t "🟥 미커버: 관대 'passing' 굴절형도 크레딧"  "4/5" "$(_cov 'passing the check')"
  t "🟥 미커버: 관대 'approval' 명사형도 크레딧" "4/5" "$(_cov 'approval')"
  t "🟥 미커버: 관대 'allowing' 도 크레딧"       "4/5" "$(_cov 'allowing the operation')"
  t "보수 'blocking' 도 같은 크레딧 (방향 무구분)" "4/5" "$(_cov 'blocking and look at the source')"
  t "보수 'token/broken' 도 같은 크레딧"          "4/5" "$(_cov 'blocking on a broken token')"

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
  echo
done
echo "ⓘ ADVISORY — 단독으로 차단하지 마라. 히트는 '이게 회로임을 증명하라'는 뜻이다."
exit "$WORST"
