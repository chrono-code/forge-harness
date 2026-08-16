#!/usr/bin/env bash
# test_adapter_lanes.sh — `scripts/adapters/*` (크로스하네스 **어댑터**)의 회귀 레인.
#
# ─────────────────────────────────────────────────────────────────────────────
# 무엇을 고정하나
# ─────────────────────────────────────────────────────────────────────────────
# 등록 바(`capability_registry_check.sh`)는 **선언된 캘리브레이션 arm 두 개만** 돌리고,
# 자기 출력에 «나머지 enum 값은 관측하지 않았다» 고 적는다. 어댑터에서 그 «나머지» 는
# 하필 가장 중요한 값이다 — **`PEER_ABSENT`**. 「그 하네스를 이 머신에 안 깔았다」가
# `CLEAN` 으로 접히면 미측정이 통과로 렌더되고, `HARNESS_ERROR` 로 접히면 멀쩡한 이웃이
# 고장으로 렌더된다. 이 레인 묶음이 그 값과 peer 해석 규칙을 고정한다.
#
# 레인 클래스 (되돌림 프로브가 이 태그로 «어느 레인이 빨개져야 하는가» 를 사전등록한다)
#   resolve-absent   peer 가 안 보일 때 **전용 값**이 나오는가
#   resolve-alias    별칭 규칙(`<n>-dev` · `_`→`-`)이 실제로 도는가
#   resolve-guard    모호/부분일치를 **고르지 않는가**
#   control          peer 가 보이면 **실제 판정**이 나오는가
#                    (「늘 PEER_ABSENT 를 찍는 계기」와 구분하는 자리)
#   enum             M4 가 관측하지 않는 나머지 enum 값들
#
# 사용법
#   bash scripts/test_adapter_lanes.sh                 # 레인 전부
#   bash scripts/test_adapter_lanes.sh --revert-probe  # 레인 + 되돌림 프로브 2종
# exit: 0 = 전부 기대대로 · 1 = 회귀 · 10 = 하네스 오류(전제 파손 — 판정 아님)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# 되돌림 프로브가 **중화된 사본**을 가리키게 하려고 파라미터화한다. 기본값은 실물이다.
ADAPTER_DIR="${FH_ADAPTER_DIR:-$REPO_ROOT/scripts/adapters}"

T="$(mktemp -d)" || { echo "❌ HARNESS-ERROR — mktemp 실패"; exit 10; }
trap 'rm -rf "$T"' EXIT

FAIL=0; N=0
RED_LANES=""     # 이번 실행에서 빨개진 레인 ID (되돌림 프로브가 읽는다)

_lane() {   # $1=id $2=class $3=설명 $4=expected_rc $5=actual_rc
  N=$((N + 1))
  if [ "$4" = "$5" ]; then
    printf '  ✅ %-6s [%-14s] %s (rc=%s)\n' "$1" "$2" "$3" "$5"
  else
    printf '  ❌ %-6s [%-14s] %s — expect rc=%s, got rc=%s\n' "$1" "$2" "$3" "$4" "$5"
    FAIL=1; RED_LANES="$RED_LANES $1"
  fi
}

# 계기 전제 — 어댑터 3종이 **실제로 거기 있는지** 먼저 본다. 없으면 이 레인 묶음은
# «전부 초록» 이 아니라 하네스 오류다(빈 대상에 대고 초록을 내는 것이 여기서 막으려는 형태).
for a in gstack_content_safety mate_agent_boundary qasp_new_code_anchor peer_resolve; do
  [ -r "$ADAPTER_DIR/$a.sh" ] || { echo "❌ HARNESS-ERROR — $ADAPTER_DIR/$a.sh 부재. 빈 대상에 초록을 내지 않는다"; exit 10; }
done

G="$ADAPTER_DIR/gstack_content_safety.sh"
M="$ADAPTER_DIR/mate_agent_boundary.sh"
Q="$ADAPTER_DIR/qasp_new_code_anchor.sh"

# 「peer 가 안 보이는 세계」 = 잘 형성된 루트 목록인데 그 안에 이 peer 가 없는 것.
# (빈 **문자열**이 아니다 — 그건 「어디를 볼지 자체가 없다」는 다른 명제이고 전제 파손이다.)
EMPTY_WORLD="$T/empty_world"; mkdir -p "$EMPTY_WORLD"

_rc() { "$@" >/dev/null 2>&1; printf '%s' "$?"; }   # 판정은 파이프를 통과시키지 않는다

# 실물 peer 루트 — 있으면 alias/control 레인을 돌리고, 없으면 그 레인은 SKIP 으로 **말한다**.
PEER_HOME="${FH_PROJECTS_HOME:-$HOME/projects}"
_peer_root() {  # $1=이름 → 실물 루트 or 빈 문자열 (별칭 순서는 어댑터와 같다)
  local n="$1" c
  for c in "$n" "$n-dev" "$(printf '%s' "$n" | tr '_' '-')"; do
    [ -d "$PEER_HOME/$c" ] && { printf '%s' "$PEER_HOME/$c"; return; }
  done
  printf ''
}
GS_ROOT="$(_peer_root gstack)"; MT_ROOT="$(_peer_root mate)"; QS_ROOT="$(_peer_root qasp)"

echo "== 어댑터 레인 (대상: $ADAPTER_DIR) =="
echo

# ═══════════════════════════════════════════════════════════════════════════
# ① gstack-content-safety
# ═══════════════════════════════════════════════════════════════════════════
echo "── gstack-content-safety (enum 0=CLEAN 1=BLOCK_HIGH 2=REVIEW_MEDIUM 3=NO_TARGET 10=HARNESS_ERROR 20=PEER_ABSENT)"
_lane G1 resolve-absent "peer 불가시 → 전용값 PEER_ABSENT(CLEAN 도 HARNESS_ERROR 도 아니다)" 20 \
  "$(FH_CLUSTER_ROOTS="$EMPTY_WORLD" _rc bash "$G" --known-positive)"
_lane G2 control "peer 가시 → 실제 판정 BLOCK_HIGH («늘 PEER_ABSENT» 와 구분)" 1 \
  "$(_rc bash "$G" --known-positive)"
_lane G3 control "peer 가시 → 음성 arm 은 CLEAN (계기가 «가른다» 는 증거)" 0 \
  "$(_rc bash "$G" --known-negative)"
if [ -n "$GS_ROOT" ]; then
  _lane G4 resolve-alias "명시 루트 목록(FH_CLUSTER_ROOTS)으로 해석된다" 0 \
    "$(FH_CLUSTER_ROOTS="$GS_ROOT" _rc bash "$G" --known-negative)"
else
  echo "  ⏭  G4    [resolve-alias ] gstack 실물 루트 없음 — SKIP (통과 아님)"
fi
# 부분일치로 남의 레포를 집지 않는다. basename 이 **정확히** 별칭 후보여야 한다.
mkdir -p "$T/world_prefix/gstackx"
_lane G5 resolve-guard "basename 부분일치는 peer 가 아니다(gstackx ≠ gstack)" 20 \
  "$(FH_CLUSTER_ROOTS="$T/world_prefix/gstackx" _rc bash "$G" --known-positive)"
mkdir -p "$T/empty_target"
_lane G6 enum "빈 디렉토리 → NO_TARGET(3). CLEAN 이 아니다 — 아무것도 안 쟀다" 3 \
  "$(_rc bash "$G" --target "$T/empty_target")"
_lane G7 enum "없는 대상 → HARNESS_ERROR(10). 부재 대상은 빈 대상이 아니다" 10 \
  "$(_rc bash "$G" --target "$T/does_not_exist")"
_lane G8 enum "인자 없음 → HARNESS_ERROR(10). 안 돈 실행을 판정으로 렌더하지 않는다" 10 \
  "$(_rc bash "$G")"
# MEDIUM 만 — 자동 차단이 아니라 사람 판단. 리터럴은 이 소스가 자기 스캐너에 물리지 않게 쪼갠다.
printf 'payroll note\ncontact ssn %s-%s-%s for the record\n' '123' '45' '6789' > "$T/medium_only.txt"
_lane G9 enum "MEDIUM 만 → REVIEW_MEDIUM(2). CLEAN 과도 BLOCK 과도 다른 값이다" 2 \
  "$(_rc bash "$G" --target "$T/medium_only.txt")"
echo

# ═══════════════════════════════════════════════════════════════════════════
# ② mate-agent-boundary
# ═══════════════════════════════════════════════════════════════════════════
echo "── mate-agent-boundary (enum 0=PASS 1=FAIL 10=HARNESS_ERROR 20=PEER_ABSENT)"
_lane M1 resolve-absent "peer 불가시 → 전용값 PEER_ABSENT(PASS 로도 HARNESS_ERROR 로도 안 접힌다)" 20 \
  "$(FH_CLUSTER_ROOTS="$EMPTY_WORLD" _rc bash "$M" --known-positive)"
_lane M2 control "peer 가시 → 실제 판정 PASS" 0 "$(_rc bash "$M" --known-positive)"
_lane M3 control "peer 가시 → 음성 arm 은 FAIL (판별력의 증거)" 1 "$(_rc bash "$M" --known-negative)"
if [ -n "$MT_ROOT" ]; then
  # 🟥 별칭 레인의 핵심: 이름은 `mate` 인데 실물 디렉토리는 `mate-dev` 다.
  #    별칭 후보에서 `<n>-dev` 가 빠지면 이 레인이 즉시 PEER_ABSENT 로 빨개진다.
  _lane M4 resolve-alias "이름 mate → 실물 $(basename "$MT_ROOT") 로 별칭 해석된다" 0 \
    "$(FH_CLUSTER_ROOTS="$MT_ROOT" _rc bash "$M" --known-positive)"
else
  echo "  ⏭  M4    [resolve-alias ] mate 실물 루트 없음 — SKIP (통과 아님)"
fi
_lane M5 enum "없는 대상 → HARNESS_ERROR(10). peer 헤더가 «위반 0 이 아니다» 라고 못 박은 값" 10 \
  "$(_rc bash "$M" --target "$T/does_not_exist.md")"
_lane M6 enum "알 수 없는 모드 → HARNESS_ERROR(10)" 10 "$(_rc bash "$M" --bogus-mode)"
echo

# ═══════════════════════════════════════════════════════════════════════════
# ③ qasp-new-code-anchor
# ═══════════════════════════════════════════════════════════════════════════
echo "── qasp-new-code-anchor (enum 0=PASS 1=VIOLATION 2=ARGS 3=HARNESS_ERROR 4=OUT_OF_SCOPE 20=PEER_ABSENT)"
_lane Q1 resolve-absent "peer 불가시 → 전용값 PEER_ABSENT(PASS 로도 HARNESS_ERROR 로도 안 접힌다)" 20 \
  "$(FH_CLUSTER_ROOTS="$EMPTY_WORLD" _rc bash "$Q" --known-positive)"
_lane Q2 control "peer 가시 → 실제 판정 VIOLATION" 1 "$(_rc bash "$Q" --known-positive)"
_lane Q3 control "peer 가시 → 음성 arm 은 PASS (판별력의 증거)" 0 "$(_rc bash "$Q" --known-negative)"
if [ -n "$QS_ROOT" ]; then
  _lane Q4 resolve-alias "이름 qasp → 실물 $(basename "$QS_ROOT") 로 별칭 해석된다" 0 \
    "$(FH_CLUSTER_ROOTS="$QS_ROOT" _rc bash "$Q" --known-negative)"
  # 🟥 모호 가드 — 한 이름에 레포 둘. **고르지 않는다.** 조용히 하나를 고르면 «어느
  #    하네스를 쟀는지» 아무도 모르게 된다. 판정 불가는 PASS 가 아니므로 HARNESS_ERROR.
  mkdir -p "$T/ambig/qasp" "$T/ambig/qasp-dev"
  _lane Q5 resolve-guard "한 이름에 레포 둘 → 고르지 않고 HARNESS_ERROR(3)" 3 \
    "$(FH_CLUSTER_ROOTS="$T/ambig/qasp:$T/ambig/qasp-dev" _rc bash "$Q" --known-positive)"
else
  echo "  ⏭  Q4/Q5 [resolve-*    ] qasp 실물 루트 없음 — SKIP (통과 아님)"
fi
_lane Q6 enum "--range 에 base 없음 → ARGS(2). 판정이 아니다" 2 "$(_rc bash "$Q" --range)"

# ── 합성 peer — peer 히스토리를 만지지 않고 나머지 enum 을 덮는다 ────────────
# 🟥 왜 합성 peer 인가: peer 는 `residency: company` 다. 실물 히스토리를 레인으로 쓰면
#    레인 출력에 조직 경로가 실린다. 그리고 실물 히스토리는 남의 커밋에 따라 조용히
#    다른 것을 재게 된다(감사 대상은 얼려야 한다). 합성 peer 는 **peer 의 실제 진입점
#    스크립트를 복사해** 쓰므로, 재는 것은 여전히 «어댑터가 peer 의 exit 을 옳게
#    재매핑하는가» 다 — 어댑터의 매핑이지 peer 의 히스토리가 아니다.
if [ -n "$QS_ROOT" ] && [ -r "$QS_ROOT/scripts/new_code_anchor_scan.sh" ]; then
  SYN="$T/synworld/qasp-dev"; mkdir -p "$SYN/scripts" "$SYN/src" "$SYN/tests"
  cp "$QS_ROOT/scripts/new_code_anchor_scan.sh" "$SYN/scripts/" || { echo "❌ HARNESS-ERROR — peer 진입점 복사 실패"; exit 10; }
  GIT=(git -c user.email=lane@localhost -c user.name=lane -c commit.gpgsign=false)
  ( cd "$SYN" && "${GIT[@]}" init -q . && printf 'base\n' > README.md \
      && "${GIT[@]}" add -A && "${GIT[@]}" commit -qm base ) >/dev/null 2>&1 \
    || { echo "❌ HARNESS-ERROR — 합성 peer 레포 생성 실패"; exit 10; }
  SYN_BASE="$(cd "$SYN" && git rev-parse HEAD)"
  # 범위 밖 언어의 신규 실행 코드만 넣는다 → 「검사되지 않았다」 ≠ 「깨끗하다」
  ( cd "$SYN" && printf 'export const f = (a) => a + 1;\n' > src/newthing.ts \
      && "${GIT[@]}" add -A && "${GIT[@]}" commit -qm oos ) >/dev/null 2>&1
  _lane Q7 enum "범위 밖 언어의 신규 실행 코드 → OUT_OF_SCOPE(4). PASS 로 접히지 않는다" 4 \
    "$(FH_CLUSTER_ROOTS="$SYN" _rc bash "$Q" --range "$SYN_BASE" HEAD)"
  _lane Q8 enum "해석 불가 ref → HARNESS_ERROR(3). 판정이 아니다" 3 \
    "$(FH_CLUSTER_ROOTS="$SYN" _rc bash "$Q" --range no-such-ref-xyz HEAD)"
else
  echo "  ⏭  Q7/Q8 [enum         ] qasp 진입점 도달 불가 — SKIP (통과 아님)"
fi
echo

# ═══════════════════════════════════════════════════════════════════════════
# 되돌림 프로브 — 앵커가 장식이 아님을 «되돌려 보고» 잰다 (적용확인 → 실행 → 복원)
# ═══════════════════════════════════════════════════════════════════════════
# 레인이 초록인 것과 레인에 **판별력이 있는 것**은 다른 명제다. 여기서는 peer 해석부를
# 두 방향으로 중화하고, **사전등록한 레인 집합만** 빨개지는지 본다.
#   R1 «부재 분기» 중화 → 부재를 부재로 못 낸다  ⇒ resolve-absent + resolve-guard(부분일치) 빨강
#   R2 «별칭 목록» 중화 → `-dev` 를 못 찾는다    ⇒ mate/qasp 의 alias·control·enum 레인만 빨강
#
# 🟥 **초판 사전등록이 두 군데 틀렸고, 프로브가 그걸 잡았다**(2026-08-16). 적어 두는 이유는
#    이게 프로브에 판별력이 있다는 증거이기 때문이다 — 사전등록을 관측에 맞춰 조용히 고치면
#    그 증거가 사라진다. 두 차이는 **레인 결함이 아니라 사전등록 오류**였고, 기계적으로 설명된다:
#      · R1 에 **G5** 가 추가로 빨강: G5 는 `gstackx` 루트를 준다. 중화판은 부재 분기 대신
#        `$PROJECTS_HOME/gstack` 를 내는데 **그 경로는 실재한다** → 어댑터가 실제로 돌아
#        BLOCK_HIGH(1) 을 낸다. G5 도 부재 분기에 결박된 레인이므로 빨강이 맞다.
#      · R2 에서 **Q5 는 초록**: Q5 는 `qasp` 와 `qasp-dev` 둘을 주는 모호 레인이다. 별칭
#        목록이 `$1` 하나로 줄면 `qasp` 만 맞아 **모호가 아니게 되고**, 어댑터는 진입점
#        부재로 HARNESS_ERROR(3) 를 낸다 — 기대값과 같은 값이다. 즉 R2 는 Q5 를 원리적으로
#        구분하지 못한다. 그건 Q5 의 결함이 아니라 **이 프로브 축의 사각지대**이고,
#        Q5 는 R1 이 아니라 별도 축(모호 판정 자체를 지우는 중화)으로만 흔들 수 있다.
# ★중화는 **실물 파일이 아니라 사본**에 건다(FH_ADAPTER_DIR). 실물 트리를 건드리지 않고,
#  사본이 실물과 «중화한 줄 말고는 동일» 함을 적용확인 단계에서 대조한다.
_revert_probe() {
  local name="$1" sedexpr="$2" applied_marker="$3" expect_red="$4" desc="$5"
  local C="$T/neutralized_$name"
  rm -rf "$C"; mkdir -p "$C"
  cp -R "$REPO_ROOT/scripts/adapters/." "$C/" || { echo "❌ HARNESS-ERROR — 사본 생성 실패"; return 10; }
  # ── 1단 적용확인: 중화가 **실제로 들어갔는가**. 안 들어간 채 «초록» 을 보고
  #    «레인이 튼튼하다» 고 읽는 것이 이 프로브의 최대 실패모드다.
  sed -i.bak "$sedexpr" "$C/peer_resolve.sh" && rm -f "$C/peer_resolve.sh.bak"
  if ! grep -q "$applied_marker" "$C/peer_resolve.sh"; then
    echo "  ❌ $name — 중화가 적용되지 않았다(마커 «$applied_marker» 부재). 프로브를 신뢰할 수 없다"
    return 1
  fi
  # 중화한 파일 말고는 사본이 실물과 동일해야 한다(다른 변수를 안 건드렸다는 확인).
  local other_diff
  other_diff="$(diff -rq "$REPO_ROOT/scripts/adapters" "$C" 2>/dev/null | grep -v 'peer_resolve.sh' | wc -l | tr -d ' ')"
  if [ "$other_diff" != "0" ]; then
    echo "  ❌ $name — 사본이 peer_resolve.sh 외에도 다르다($other_diff건). 프로브 격리 실패"
    return 1
  fi
  # ── 2단 실행: 사본을 대상으로 레인을 통째로 다시 돌린다.
  local out red
  out="$(FH_ADAPTER_DIR="$C" bash "${BASH_SOURCE[0]}" --lanes-only 2>&1)"
  red="$(printf '%s\n' "$out" | sed -n 's/^  ❌ \([A-Z][0-9]*\) .*/\1/p' | sort | tr '\n' ' ' | sed 's/ $//')"
  # ── 3단 복원: 사본을 지운다. 실물은 애초에 안 건드렸다.
  rm -rf "$C"
  printf '  %s — %s\n' "$name" "$desc"
  printf '     사전등록 빨강: [%s]\n' "$expect_red"
  printf '     실측   빨강: [%s]\n' "$red"
  if [ "$red" = "$expect_red" ]; then
    printf '     ✅ 정확히 그 레인만 빨개졌다 — 이 레인들은 peer 해석부에 실제로 결박돼 있다\n'
    return 0
  fi
  printf '     ❌ 사전등록과 다르다 — 레인이 장식이거나 사전등록이 틀렸다. 둘 다 결함이다\n'
  return 1
}

case "${1:-}" in
  --lanes-only)
    # 되돌림 프로브가 자기를 재귀 호출할 때 쓰는 모드. 프로브를 다시 돌리지 않는다.
    ;;
  --revert-probe)
    echo "== 되돌림 프로브 (적용확인 → 실행 → 복원) =="
    RP=0
    # R1: 「없다」를 못 내게 한다 — 부재 분기를 순진한 추측 경로로 바꾼다.
    _revert_probe R1 \
      's|^    printf .peer-resolve: peer|    printf "%s" "${FH_PROJECTS_HOME:-$HOME/projects}/$n"; return 0  # NEUTRALIZED_R1\n    printf '"'"'peer-resolve: peer|' \
      'NEUTRALIZED_R1' \
      'G1 G5 M1 Q1' \
      '«부재» 분기 중화 → 부재 분기에 결박된 레인만 빨개져야 한다' || RP=1
    echo
    # R2: 별칭 후보를 이름 자신 하나로 줄인다 — `-dev` 를 못 찾게 된다.
    _revert_probe R2 \
      's|^  printf .%s\\n. "\$1" "\$1-dev".*$|  printf "%s\\n" "$1"   # NEUTRALIZED_R2|' \
      'NEUTRALIZED_R2' \
      'M2 M3 M4 M5 M6 Q2 Q3 Q4 Q6 Q7 Q8' \
      '별칭 목록 중화 → mate/qasp 쪽 레인만 빨개져야 한다(gstack 은 별칭이 필요 없다)' || RP=1
    echo
    [ "$RP" -eq 0 ] || FAIL=1
    ;;
  '') ;;
  *) echo "usage: $(basename "$0") [--revert-probe]" >&2; exit 10 ;;
esac

echo
if [ "$FAIL" -eq 0 ]; then
  # ★`${N}` 로 감싼다 — 한글이 바로 뒤에 오면 bash 가 `$N개` 를 **변수명 `N개`** 로 읽어
  #   `unbound variable` 로 죽는다(실측 2026-08-16: 레인 23개 전부 초록인데 마지막 요약
  #   줄에서 rc=1). 계기가 자기 보고 줄에서 죽으면 초록이 빨강으로 렌더된다.
  echo "✅ 레인 ${N}개 전부 기대대로"
else
  echo "❌ 회귀 — 빨강:$RED_LANES (레인 ${N}개 실행)"
fi
exit "$FAIL"
