#!/usr/bin/env bash
# outbound_query_guard.sh — 나가는 질의의 **위생 린트(accidental-leak lint)**.
# 🟥 **보안 통제가 아니다.** cross-family(codex, 2026-08-21) 지적: 토큰 분할·동의어·경로 일부·
# base64 는 전부 통과하고, 이 가드는 **어떤 outbound 실행기에도 배선돼 있지 않다.** 즉 «우연한
# 유출»은 잡고 «의도적 우회»는 못 잡는다. 보안 경계라 부르려면 실제 실행기에 강제 연결하고
# 정규화·승인·로깅의 우회 모델을 따로 설계해야 한다 — 하지 않았다. 그렇게 문서화한다.
#
# ── 왜 (챔버 런 consolidation-path-gate, S#6) ──
# 세션이 «세계에 물어본다» 를 하려면 문제를 이름으로 불러야 한다. 그 이름이 내부 자산명이면
# 질의 자체가 **유출**이다. 후보 스펙에 이 가드가 0줄이었고 블라인드 challenger 가 S 등급으로 지목했다.
# `CLAUDE.md §Field-Harness Diagnostic` 의 절대 규칙: 내부 자산명·경로는 로그·코멘트·붙여넣기에도
# 안 나간다. 외부 질의는 그 목록의 «붙여넣기» 와 같은 급이고, **되돌릴 수 없다.**
#
# ── 새 로직 0줄 ──
# `scripts/psa_scan_lib.sh` 가 이미 «패턴 두 층 로딩 · 행 검증 · 토큰 판정» 을 소유한다. 그 헤더가
# caller 의 몫을 명시했다: **무엇을 스캔하는가**, 그리고 **계기 불완전 시 degrade 방향**.
# 이 파일은 그 둘만 정한다 — 스캔 대상 = 질의 문자열, degrade = **fail-closed**.
#
# ── degrade 가 왜 block 인가 (커밋 caller 와 반대) ──
# 같은 라이브러리를 쓰는 pre-commit 은 override 부재 시 **경고**한다 — 커밋은 로컬이고 되돌릴 수
# 있으니까. 외부 질의는 push/publish 와 같은 부류다: 나가면 끝이다.
# `CLAUDE.md §Irreversibility Gates` 의 표면-클래스 degrade 불변식 그대로.
#
# Usage:  bash scripts/outbound_query_guard.sh "<질의 문자열>"
#         echo "<질의>" | bash scripts/outbound_query_guard.sh
# Exit:   0 = clean(내보내도 된다) · 1 = HIT(차단) · 3 = NOT SCANNED(계기 불완전 → 차단)
# Override: OUTBOUND_QUERY_OK=1 — 명시 승인. 로그를 남긴다. 🟥 유출이 없다고 «확인했을 때만».
set -uo pipefail
FH="$(cd "$(dirname "$0")/.." && pwd)"
# 🟥 주입 가능하게 둔다 — cross-family 가 «레인이 실물 라이브러리를 옮긴다» 를 HIGH 로 지목했다.
# 주입점이 있으면 레인이 레포를 안 건드리고, 오염 상태 분기에도 도달할 수 있다.
LIB="${PSA_LIB_FILE:-$FH/scripts/psa_scan_lib.sh}"
DEFAULTS="${PSA_DEFAULTS_FILE:-$FH/.claude/rules/.public-surface-patterns.defaults}"
OVERRIDE="${PSA_OVERRIDE_FILE:-$FH/.claude/rules/.public-surface-patterns}"
# 🟥 주입점 하나 더 — **같은 논거의 네 번째 적용**이다(위 세 개가 «레인이 레포를 안 건드리게»
# 있는 것과 동일). 실측 2026-09-05: 이 로그 경로가 박혀 있어서 L4 는 ⓐ 매 selfcheck 마다 실제
# 레포의 tracks/_meta 에 행을 쌓았고 ⓑ tracks/ 가 없는 트리(= npm 설치본)에서는 append 가
# 조용히 실패해 **`+1` 단언이 그대로 빨개졌다**. 즉 이 가드를 출하하려면 이 줄이 먼저다.
# 기본값은 안 바뀐다.
# ⚠️ 우회 채널로 읽지 마라: OUTBOUND_QUERY_OK 자체가 이미 env 로 켜는 것이라, 로그 경로를
#    옮기는 것이 «없던 우회»를 만들지는 않는다. 다만 «강행은 기록된다»는 성질이 env 하나에
#    더 의존하게 된 것은 사실이고, 그건 잔여로 이름 붙인다.
OVERRIDE_LOG="${OUTBOUND_QUERY_LOG:-$FH/tracks/_meta/.outbound_query_override_log}"

Q="${1:-}"; [ -n "$Q" ] || Q="$(cat)"
if [ -z "${Q// /}" ]; then echo "  ⏭  빈 질의 — 스캔할 것이 없다" >&2; exit 0; fi

if [ ! -r "$LIB" ]; then
  echo "🚫 OUTBOUND BLOCKED — 스캐너 라이브러리 부재: $LIB" >&2
  echo "   계기가 없으면 «유출 없음» 이 아니라 **미측정**이다. 비가역 표면이라 막는다." >&2
  exit 3
fi
# shellcheck source=/dev/null
. "$LIB"

psa_load "$DEFAULTS" "$OVERRIDE" >/dev/null 2>&1 || true
# 🟥 **반환값이 아니라 상태 변수를 본다.** psa_scan_lib.sh 헤더가 이 함정을 명시한다:
#   "A caller that treats PSA_BAD_ROWS>0 or PSA_DEFAULTS_OK=0 as 'clean' has a hole"
# 초판이 정확히 그 caller 였고 — `psa_load` 의 rc 만 보고 defaults 부재를 통과시켰다.
# known-pair 레인 L3 가 잡았다(`defaults 부재 → got=0 expect=3`). 레인이 없었으면 조용히 fail-open.
# 🟥 상태값은 `case` 로 본다. `[ -ne ]` 는 비수치 값에서 셸 에러 후 조건 false 로 흘러
# **fail-open** 이 된다 — 공유 라이브러리가 같은 결함을 이미 겪고 `case` 로 막아뒀다(psa_scan_lib.sh).
case "${PSA_DEFAULTS_OK:-}" in
  1) ;;
  *)
  echo "🚫 OUTBOUND BLOCKED — 공용 패턴층(defaults)이 없거나 비었다: $DEFAULTS" >&2
  echo "   라이브러리 규정: 이 상태는 «설정 선택» 이 아니라 **BROKEN INSTRUMENT** 다." >&2
     echo "   fail-closed: 커밋 caller 는 경고하지만 외부 질의는 되돌릴 수 없다." >&2
     exit 3 ;;
esac
case "${PSA_BAD_ROWS:-}" in
  0) ;;
  *) echo "🚫 OUTBOUND BLOCKED — 패턴 파일 형식오류 행 '${PSA_BAD_ROWS:-?}' — 부분 로드는 미측정이다" >&2
     exit 3 ;;
esac
# 🟥 **운영자 내부층(override)이 없으면 clean 을 말할 수 없다** (cross-family HIGH#1).
# 라이브러리 규정상 HIGH 내부 리터럴은 그 층에 산다. defaults 만으로 통과시키면 «보편 패턴만
# 본 것» 을 «내부 토큰 없음» 으로 렌더한다 — 초판이 그 caller 였다.
case "${PSA_OVERRIDE_PRESENT:-}" in
  1) ;;
  *) echo "🚫 OUTBOUND BLOCKED — 운영자 내부 패턴층(override) 부재: $OVERRIDE" >&2
     echo "   defaults 만으로는 «내부 토큰 없음» 을 말할 수 없다 — 미측정이다." >&2
     exit 3 ;;
esac
# 🟥 계기 생사 — 라이브러리가 카나리아 자체검증을 갖고 있다. 「초록인데 대상을 안 잰다」를 막는다.
if ! psa_require_live >/dev/null 2>&1; then
  echo "🚫 OUTBOUND BLOCKED — psa_require_live 실패: 스캐너가 알려진 토큰도 못 잡는다" >&2
  echo "   계기가 죽었다. 통과가 아니라 **미측정**이다." >&2
  exit 3
fi

# 🟥 **개행·탭을 먼저 죽인다** (cross-family HIGH#3). `psa_scan_tagged` 는 줄마다 `path<TAB>body`
# 로 읽으므로, 질의에 개행+탭이 있으면 **토큰이 path 필드로 들어가 스캔 대상에서 빠진다.**
# 실제 우회 경로였다. 한 레코드로 눌러 넣는다.
Q_FLAT="$(printf '%s' "$Q" | tr '\n\t\r' '   ')"
# 🟥 P3 동형: 조건문 안의 대입이라야 `set -e` 아래서 안 죽는다.
if OUT="$(printf 'outbound-query\t%s' "$Q_FLAT" | psa_scan_tagged 2>&1)"; then RC=0; else RC=$?; fi
# 🟥 P2 (cross-family 3라운드): 초판은 «비영이면 override 로 통과» 였다. 그러면 **rc=3 미측정**
#    까지 승인된 것처럼 지나간다 — pre-commit·pre-push 에서 닫은 바로 그 구멍이 **세 번째
#    호출부에 그대로** 있었고, 나는 그것을 「호출부 셋 다 닫혔다」고 적었다(전수 주장이 틀렸다).
#    override 는 «봤고 괜찮다» 는 뜻이라 **본 것(rc=1)에만** 쓸 수 있다. 안 본 것(rc=3)엔 못 쓴다.
# 🟥 R4-4/5: 판정점을 **하나로** 만든다. 초판은 «rc=3 선차단» + «override 에 `-le 1` 조건»
#    두 겹이었는데, 앞이 막아버려 뒤 술어는 **되돌려도 레인이 안 빨개졌다**(장식 앵커).
#    그리고 rc=2 는 어느 쪽도 안 잡아 **«유출 발견»(exit 1)으로 오분류**됐다 — 안 본 것을
#    본 것으로 렌더하는 방향이다. 「측정된 값」은 0 과 1 뿐이고 **나머지는 전부 미측정**이다.
case "$RC" in
  0|1) ;;
  *) echo "🚫 OUTBOUND BLOCKED — 스캐너가 측정값을 안 냈다 (rc=$RC). NOT SCANNED 는 깨끗함이 아니다." >&2
     echo "   OUTBOUND_QUERY_OK 로도 통과 못 한다 — 승인은 «봤다» 는 뜻이고, 이건 안 본 것이다." >&2
     echo "$OUT" >&2
     exit 3 ;;
esac
if [ "$RC" -ne 0 ] || [ -n "$OUT" ]; then
  # 여기 도달했다는 것은 위 `case` 에 의해 RC ∈ {0,1} 이 **구조적으로 보장**된 상태다.
  # 초판의 `&& [ "$RC" -le 1 ]` 는 그래서 중복이었고, 중복은 앵커가 안 붙는다 — 지운다.
  if [ "${OUTBOUND_QUERY_OK:-0}" = "1" ]; then
    printf '%s\tOUTBOUND_QUERY_OK\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${Q:0:60}" \
      >> "$OVERRIDE_LOG" 2>/dev/null || true
    echo "⚠️  OUTBOUND — 히트가 있었으나 OUTBOUND_QUERY_OK=1 로 강행됨 (로그 기록됨)" >&2
    echo "$OUT" >&2
    exit 0
  fi
  echo "🚫 OUTBOUND BLOCKED — 나가는 질의에 내부 토큰이 있다:" >&2
  echo "$OUT" >&2
  echo "   고쳐라: 문제를 **일반 어휘**로 다시 써라 (내부 이름 대신 그 이름이 가리키는 «형태»)." >&2
  echo "   예) «우리 X 게이트가…» → «커밋 전에 근거 필드를 강제하는 훅 패턴»" >&2
  echo "   확인 후 강행: OUTBOUND_QUERY_OK=1 bash scripts/outbound_query_guard.sh \"<질의>\"" >&2
  exit 1
fi
echo "  ✅ outbound clean — 내부 토큰 없음" >&2
exit 0
