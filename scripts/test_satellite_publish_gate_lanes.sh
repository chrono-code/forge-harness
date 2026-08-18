#!/usr/bin/env bash
# test_satellite_publish_gate_lanes.sh — known-pair anchor for the satellite's publish gate.
#
# WHY (2026-08-18, 원정 2차)
#   frontier_digest_daily.sh 는 FH 자신만 대상으로 지어졌고, FH 의 digest 는 gitignored
#   `tracks/` 에 떨어진다 — 그래서 **공개 노출 문제가 없었다**. 위성이 **공개 레포**를 대상으로
#   돌면 **매 런이 publish** 다(비가역 표면). §Irreversibility Surface-Class Degrade Invariant:
#   비가역 표면은 fail-CLOSED — 스캐너가 못 재면 «통과»가 아니라 «보류»다.
#
#   🟥 이 스위트의 진짜 주장은 «스캔한다»가 아니라 **«세 값을 두 값으로 접지 않는다»** 다.
#   CLEAN(0) · LEAK(1) · NOT-SCANNED(3) 은 처방이 각각 다르다: 각각 게시 / 격리 / 보류.
#   접으면 «못 쟀다»가 «깨끗하다»로 렌더된다 — [[feedback_not_found_is_not_zero_family]].
#
# Lanes
#   P1  CLEAN     → rc=0, 파일 그대로 (게시)
#   P2  LEAK      → rc=2, 파일이 .QUARANTINE 로 격리 (게시 안 됨)
#   P3  NOT-SCAN  → rc=3, 파일이 .UNSCANNED 로 보류 (게시 안 됨) — 스캐너가 죽어도 fail-closed
#   N1  CONTROL — FD_PUBLIC_TARGET 미설정 → 게이트 자체가 안 돈다 (FH 프로덕션 경로 무변경)
#   N2  CONTROL — P2 와 P3 의 rc 가 **다르다**(2 vs 3). 같으면 두 실패가 한 값으로 접힌 것이다
#
# Exit 0 = 5/5.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0
t() { if [ "$2" = "$3" ]; then echo "  ✅ $1"; pass=$((pass+1)); else echo "  ❌ $1 — got [$3] want [$2]"; fail=$((fail+1)); fi }

run() { # $1 = digest body · $2 = psa_lib override ("dead" to break the scanner) → echoes "rc|state"
  local td; td=$(mktemp -d)
  mkdir -p "$td/scripts" "$td/out" "$td/.claude/rules"
  cp "$ROOT/scripts/frontier_digest_daily.sh" "$td/scripts/"
  cp "$ROOT/.claude/rules/.public-surface-patterns.defaults" "$td/.claude/rules/" 2>/dev/null
  # 🟥 오버라이드 파일이 없으면 스캐너는 `override_absent(HIGH operator literals unscanned)` 로
  # **NOT SCANNED** 를 낸다 — MED 히트를 찾고도 «부분 커버리지는 판정이 아니다»라며 거부한다.
  # 엄격하게 옳은 동작이고, 그래서 이 픽스처는 **합성 리터럴**로 자립시킨다: 운영자의 실제
  # 리터럴에 의존하면 이 스위트가 그 파일의 존재 여부에 따라 갈린다.
  printf 'HIGH\tZZ_SYNTHETIC_LEAK_TOKEN_ZZ\n' > "$td/.claude/rules/.public-surface-patterns"
  if [ "$2" = "dead" ]; then printf '#!/usr/bin/env bash\npsa_load(){ :; }\npsa_scan_file(){ return 3; }\n' > "$td/scripts/psa_scan_lib.sh"
  else cp "$ROOT/scripts/psa_scan_lib.sh" "$td/scripts/"; fi
  printf '%s\n' "$1" > "$td/out/frontier_digest_$(date +%Y_%m_%d).md"
  # 러너가 digest_ready 로 이미 있는 파일을 보고 조기 종료하지 않도록, 게이트 경로를 직접 태운다:
  # attempt 루프 진입 전에 skip 하므로 여기서는 러너 본체 대신 게이트 분기만 재현할 수 없다.
  # → 러너를 그대로 돌리되 CLAUDE_BIN 을 no-op 스텁으로 줘서 attempt 를 태운다.
  printf '#!/usr/bin/env bash\nexit 0\n' > "$td/scripts/stub-claude"; chmod +x "$td/scripts/stub-claude"
  local out rc
  out=$(cd "$td" && FD_FH_DIR="$td" FD_OUT_DIR="out" FD_PUBLIC_TARGET=1 \
        FD_CLAUDE_BIN="$td/scripts/stub-claude" FD_MAX_ATTEMPTS=1 FD_ATTEMPT_TIMEOUT_SECS=20 \
        FD_POLL_SECS=1 bash scripts/frontier_digest_daily.sh 2>&1); rc=$?
  local state=none
  ls "$td/out/"*.QUARANTINE >/dev/null 2>&1 && state=quarantine
  ls "$td/out/"*.UNSCANNED  >/dev/null 2>&1 && state=unscanned
  ls "$td/out/"*.md         >/dev/null 2>&1 && [ "$state" = none ] && state=published
  echo "$rc|$state"
  rm -rf "$td"
}

CLEAN_BODY="# digest
A clean digest with no operator-private tokens. $(head -c 1200 /dev/zero | tr '\0' 'x')"
LEAK_BODY="# digest
this line carries ZZ_SYNTHETIC_LEAK_TOKEN_ZZ which the fixture pattern file flags HIGH. $(head -c 1200 /dev/zero | tr '\0' 'x')"

r=$(run "$CLEAN_BODY" live); t "P1 CLEAN → 게시"            "0|published"  "$r"
r=$(run "$LEAK_BODY"  live); t "P2 LEAK → 격리(.QUARANTINE)" "2|quarantine" "$r"; P2RC=${r%%|*}
r=$(run "$CLEAN_BODY" dead); t "P3 스캐너 사망 → 보류(.UNSCANNED)" "3|unscanned" "$r"; P3RC=${r%%|*}

# N1 — 게이트 미활성(FD_PUBLIC_TARGET 없음)이면 LEAK 본문이어도 게시된다 = FH 경로 무변경
td=$(mktemp -d); mkdir -p "$td/scripts" "$td/out" "$td/.claude/rules"
cp "$ROOT/scripts/frontier_digest_daily.sh" "$ROOT/scripts/psa_scan_lib.sh" "$td/scripts/"
cp "$ROOT/.claude/rules/.public-surface-patterns.defaults" "$td/.claude/rules/" 2>/dev/null
printf '%s\n' "$LEAK_BODY" > "$td/out/frontier_digest_$(date +%Y_%m_%d).md"
printf '#!/usr/bin/env bash\nexit 0\n' > "$td/scripts/stub-claude"; chmod +x "$td/scripts/stub-claude"
out=$(cd "$td" && FD_FH_DIR="$td" FD_OUT_DIR="out" FD_CLAUDE_BIN="$td/scripts/stub-claude" \
      FD_MAX_ATTEMPTS=1 FD_POLL_SECS=1 bash scripts/frontier_digest_daily.sh 2>&1); n1rc=$?
n1state=published; ls "$td/out/"*.QUARANTINE >/dev/null 2>&1 && n1state=quarantine
t "N1 control — 게이트 미활성이면 안 돈다(FH 경로 무변경)" "0|published" "$n1rc|$n1state"
rm -rf "$td"

t "N2 control — LEAK 과 NOT-SCANNED 의 rc 가 다르다" "different" "$([ "${P2RC:-x}" != "${P3RC:-y}" ] && echo different || echo collapsed)"

echo "----"; echo "satellite publish gate: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
