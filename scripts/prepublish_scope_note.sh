#!/usr/bin/env bash
# prepublish_scope_note.sh — the publish gate must test the ARTIFACT, not this machine.
#
# ── 왜 이 파일이 있나 (package.json 은 주석을 못 단다) ────────────────────────────
# 2026-08-17 실측: `prepublishOnly` 체인이 `scripts/selfcheck.sh` 를 통과 조건으로 삼고
# 있었고, 그 안의 **peer 하네스 어댑터 레인**은 «이 머신에 어떤 레포가 깔려 있는가» 에 따라
# 판정이 갈린다. 결과:
#
#     CI (peer 레포 0개)      selfcheck 초록 — PEER_ABSENT 로 SKIP  → 출하 가능
#     클러스터를 쓰는 노드     selfcheck 적색 — 어댑터 없는 peer 계기 → 출하 차단
#
# **peer 를 안 깐 머신은 출하할 수 있고, 실제로 클러스터를 쓰는 머신은 출하할 수 없다.**
# 방향이 거꾸로다. 그리고 이 클래스는 같은 날 반대 방향으로도 밟혔다(픽스처가 gitignored
# 파일을 인용 → 로컬 초록·CI 적색). 뿌리는 하나다:
#
#   > 검정이 «저장소에 무엇이 있는가» 가 아니라 «이 머신에 무엇이 있는가» 를 재고 있었다.
#
# ── 처방 (`fh_signal_2026-08-17_publish-depends-on-local-env.md` ⓑ) ─────────────
# `prepublishOnly` 는 **출하물의 성질만** 본다:
#     publish_freshness_check · version_lockstep_check · package_coverage --vs-tarball
#     · public_surface_scan_files
# peer 클러스터 상태는 출하물의 성질이 아니다. 그래서 selfcheck 는 이 체인에서 빠졌다.
#
# 🟥 **빠진 것이 «커버리지 상실» 이 되지 않게 하는 것이 이 스크립트의 실제 일이다.**
# selfcheck 는 여전히 `npm test` 이고, **CI `validate` 잡이 매 푸시마다 돌린다** — 그리고
# `validate` 는 main 의 **required check** 다(2026-08-12 실측: legacy
# `required_status_checks.contexts = ["validate"]`). 즉 출하되는 커밋은 이미 selfcheck 를
# 통과한 커밋이다. 그 전제가 참인지를 **여기서 기계로 확인한다** — 워크플로에서
# selfcheck 호출이 사라지면 이 스크립트가 출하를 막는다. 산문 약속이 아니라 채널 검사다.
#
# ⚠️ **명시 잔여 — 축소해서 읽지 마라. 아래 넷은 cross-family 실측으로 확정된 구멍이다.**
#   ⓐ 이 검사는 «워크플로가 selfcheck 를 호출한다» 는 **존재**를 볼 뿐, 그 잡이 이 커밋에서
#      실제로 **초록이었는지**는 안 본다. 그건 ⓒ(CI 태그 출하 배선)의 일이고 미구축이다.
#   ⓐ-2 🟥 **`if: false` 로 꺼진 잡은 못 잡는다**(codex 지적 #2, S). 호출 문자열은 살아 있고
#      잡은 절대 안 돈다 — 이 게이트는 «커버리지 있음» 을 낸다. YAML 파서 없이는 조건식을
#      평가할 수 없고, 파서를 여기 넣는 것은 이 스크립트의 일이 아니다. **미봉이라 적는다.**
#   ⓐ-3 🟥 **어느 잡인지 안 본다**(codex 지적 #4, A). 위 주석은 `validate` 잡을 말하는데
#      술어는 **파일 안 아무 잡이나** 받는다. required check 는 `validate` 하나뿐이므로
#      다른 잡에 옮겨진 selfcheck 는 필수가 아니게 되지만 이 검사는 통과시킨다.
#   ⓐ-4 🟥 **트리거를 안 본다**(codex 지적 #3, A). `on: pull_request` 만 있어도 통과한다 —
#      그러면 출하되는 main 커밋 자체는 selfcheck 를 한 번도 안 탄다.
#   ⇒ ⓐ-2~4 를 닫는 정직한 형태는 문자열 검사가 아니라 **`gh api` 로 실제 required check 와
#      그 커밋의 conclusion 을 읽는 것**이다. 그건 네트워크 의존이라 출하 경로에 넣을지가
#      별도 결정이고(오프라인 fail-closed 는 또 다른 과차단), 여기서 정하지 않는다.
#   ⓑ `validate` 의 `strict: false` 는 그대로다 — 초록인 체크가 지금의 main 을 본 적이
#      없을 수 있다(CLAUDE.md §4축 게이트 기계층에 이미 기록된 잔여).
#   ⓒ 어댑터 레인 자체의 수리(레인 분리, 계기 부재 → SKIP)는 **qasp AX-ready 세션으로
#      라우팅**됐다(`fh_signal_2026-08-17_qasp-adapter-phantom-air.md`). 여기서 손대지 않는다.
#
# 종료코드: 0 통과 · 1 커버리지 전제 파손(출하 차단) · 3 계기가 측정 불가(fail-closed)

set -u

WF=".github/workflows/validate.yml"
SUBJ="scripts/selfcheck.sh"

_note() {
  echo "── prepublish scope ─────────────────────────────────────────────"
  echo "   이 체인은 **출하물의 성질만** 검사한다 (freshness · lockstep ·"
  echo "   tarball coverage · public surface). peer 클러스터 상태는 출하물의"
  echo "   성질이 아니므로 selfcheck 는 여기 없다 — CI 'validate' 가 돌린다."
}

check() {
  if [ ! -f "$WF" ]; then
    echo "❌ INSTRUMENT ERROR  $WF 가 없다 — selfcheck 의 CI 커버리지를 확인할 수 없다."
    echo "   측정 불가는 통과가 아니다(미측정 ≠ 0). 출하를 막는다."
    return 3
  fi
  # 🟥 주석을 먼저 벗긴다. cross-family(codex/gpt-5.5) 실측 지적 #1(S): 초판은 `grep -qE
  # "selfcheck\.sh"` 였고 **주석 처리된 호출에도 매칭**됐다 — 즉 `# - run: bash
  # scripts/selfcheck.sh` 로 레인을 꺼놓아도 이 게이트는 «커버리지 있음» 을 냈다.
  # 그리고 **언급이 아니라 호출**이어야 한다 — `echo "… scripts/selfcheck.sh …"` 는 실행이
  # 아니다(실물 워크플로에 그런 줄이 실제로 있다). 그래서 줄의 **첫 토큰이 실행자**인 것만 센다.
  # 🟥 첫 수리는 `run:` 을 같은 줄에서 요구했고 **실물에서 즉시 적색**이었다 — 실물은
  #    `run: |` 블록 스칼라 안에서 호출한다(`validate.yml:150`). self-test 6/6 초록인데
  #    실물이 빨간 상태였고, 그게 «픽스처가 실물을 대표하지 못한다» 의 교과서 형태다.
  #    그래서 아래 known-pair 는 **실물 형태(블록 스칼라)를 그대로 뜬다.**
  if ! sed 's/#.*//' "$WF" \
     | grep -qE '^[[:space:]]*(-[[:space:]]+run:[[:space:]]*)?(bash|sh|source|\.)[[:space:]]+[^[:space:]]*selfcheck\.sh'; then
    echo "❌ PUBLISH BLOCKED  $WF 가 더 이상 $SUBJ 를 호출하지 않는다."
    echo ""
    echo "   prepublishOnly 에서 selfcheck 를 뺀 근거는 «CI 가 대신 돌린다» 였다."
    echo "   그 전제가 깨졌으므로 지금 출하하면 selfcheck 커버리지가 **어디에도 없다**."
    echo ""
    echo "   고르는 길 둘:"
    echo "     ① $WF 에 selfcheck 호출을 복구한다 (원래 자리)"
    echo "     ② selfcheck 를 prepublishOnly 로 되돌린다 — 단 그러면 2026-08-17 의"
    echo "        «출하 가능 여부 = 이 머신의 디렉터리 구성» 결함이 함께 돌아온다"
    return 1
  fi
  _note
  echo "   ✅ CI 커버리지 확인: $WF 가 $SUBJ 를 호출한다"
  return 0
}

# ── known-pair self-test — 컨트롤이 살아 있는지 보여주는 실행 출력 ────────────────
if [ "${1:-}" = "--self-test" ]; then
  t=$(mktemp -d) || exit 3
  trap 'rm -rf "$t"' EXIT
  pass=0; fail=0
  _lane() { # $1 = 이름, $2 = 기대 rc, $3 = 워크플로 내용(빈 문자열이면 파일 없음)
    local name="$1" want="$2" body="$3" got
    ( cd "$t" && rm -rf .github && if [ -n "$body" ]; then
        mkdir -p .github/workflows && printf '%s\n' "$body" > "$WF"
      fi
      WF="$WF" SUBJ="$SUBJ"; check >/dev/null 2>&1 ); got=$?
    if [ "$got" = "$want" ]; then pass=$((pass+1)); echo "  PASS $name (rc=$got)"
    else fail=$((fail+1)); echo "  FAIL $name — 기대 rc=$want, 실제 rc=$got"; fi
  }
  echo "prepublish_scope_note.sh --self-test"
  _lane "known-positive: 워크플로가 selfcheck 호출"  0 "      - run: bash scripts/selfcheck.sh"
  _lane "known-negative: 호출이 사라짐"              1 "      - run: echo hi"
  _lane "계기 부재: 워크플로 파일 자체가 없음"        3 ""
  # ★ cross-family 지적 #1(S) 회귀 앵커 — 주석 처리된 호출은 커버리지가 아니다.
  _lane "★주석 처리된 호출은 커버리지 아님"          1 "      # - run: bash scripts/selfcheck.sh
      - run: echo no selfcheck"
  # ★ 과차단 컨트롤 — 주석을 벗기는 수리가 **정상 호출까지** 죽이지 않았는지. 이게 없으면
  #   위 레인은 «전부 차단하는 계기» 로도 초록이 된다(컨트롤 있음 ≠ 판별력 있음).
  _lane "★컨트롤: 주석과 실호출이 같이 있으면 통과"  0 "      # - run: bash scripts/selfcheck.sh   (구버전)
      - run: bash scripts/selfcheck.sh"
  # ★ 실물 형태 — `run: |` 블록 스칼라 안에서의 호출. 이게 실제 validate.yml 의 모양이고,
  #   초판 정규식은 여기서 죽었다(self-test 는 초록인데 실물이 적색이었다).
  _lane "★실물 형태: run: | 블록 안 호출"            0 "      - name: Selfcheck
        run: |
          echo \"=== scripts/selfcheck.sh ===\"
          bash scripts/selfcheck.sh"
  # ★ 언급 ≠ 실행. 같은 블록 안에 echo 로만 이름이 있으면 커버리지가 아니다.
  _lane "★echo 언급만 있으면 커버리지 아님"          1 "      - name: Selfcheck
        run: |
          echo \"=== scripts/selfcheck.sh 는 로컬에서 돌린다 ===\"
          echo done"
  echo "  ── $pass pass / $fail fail"
  [ "$fail" -eq 0 ] || exit 1
  exit 0
fi

check
exit $?
