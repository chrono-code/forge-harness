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
#   P4  착지 증언이 **실제로 로그에 찍힌다** — 직전 digest 가 없으면 «SKIPPED (not a pass)».
#       배선했다 ≠ 발화한다. 그리고 SKIP 을 통과로 렌더하지 않는 것까지 주장한다
#
#   R1  착지 증언이 **살아 있다** — 러너가 부르는 형태로 rc=10(계기 사망)이 아니어야 한다
#   R1n CONTROL — 옛 형태(디렉터리를 타깃으로)는 지금도 rc=10 이다. 고친 게 이거라는 증명
#   R2  공개 대상이면 로그가 **OUT_DIR 밖**이다 / R2n CONTROL — 비공개면 종전 자리 그대로
#   R2b LEAK 로그에 **토큰 원문이 없다**(리댁션) — 유출을 격리하며 같은 자리에 복사하지 않는다
#   R3  같은 날 파일이 둘이고 **뒤엣것이 LEAK** 이면 rc=2 — head -1 이면 CLEAN 이 나온다
#
# Exit 0 = 전 레인.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# 🟥 arm 간 전달 파일을 **고정 `/tmp` 이름**으로 쓰면 안 된다 (보안 패스 2026-08-18, MED·재현됨).
#    `/tmp/.lw_clean` · `/tmp/.lg_leak` 처럼 이름이 6개 전부 고정이라 심볼릭 링크 선점으로
#    임의 파일이 덮인다(`cp` 가 링크를 따라간다). 게다가 정리 코드가 없어 게이트 **로그 사본**이
#    `/tmp` 에 644 로 영구히 남았다 — 기밀성 축의 정반대 방향이다.
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/fh_satlane.XXXXXX")" || exit 1
trap 'rm -rf "$SCRATCH"' EXIT
pass=0; fail=0
t() { if [ "$2" = "$3" ]; then echo "  ✅ $1"; pass=$((pass+1)); else echo "  ❌ $1 — got [$3] want [$2]"; fail=$((fail+1)); fi }

run() { # $1 = digest body · $2 = psa_lib override ("dead") · $3 = arm 이름 → echoes "rc|state"
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
  # R2 이후 공개 대상의 로그는 OUT_DIR 밖이다 — arm 은 자기 위치를 명시한다(레인이 로그를 읽어야 하므로)
  out=$(cd "$td" && FD_FH_DIR="$td" FD_OUT_DIR="out" FD_PUBLIC_TARGET=1 \
        FD_LOG_DIR="$td/logs" \
        FD_CLAUDE_BIN="$td/scripts/stub-claude" FD_MAX_ATTEMPTS=1 FD_ATTEMPT_TIMEOUT_SECS=20 \
        FD_POLL_SECS=1 bash scripts/frontier_digest_daily.sh 2>&1); rc=$?
  local state=none
  ls "$td/out/"*.QUARANTINE >/dev/null 2>&1 && state=quarantine
  ls "$td/out/"*.UNSCANNED  >/dev/null 2>&1 && state=unscanned
  ls "$td/out/"*.md         >/dev/null 2>&1 && [ "$state" = none ] && state=published
  # 착지 증언이 로그에 남았는지 (P4 가 읽는다)
  # 🟥 arm 마다 따로 남긴다. 초판은 단일 파일에 덮어써서 **마지막 arm(P3, 스캐너 사망)** 것을
  # 잡았는데, 거기선 게이트가 실패해 증언이 안 도는 게 정상이다 — 레인이 정상 동작을 실패로
  # 렌더할 뻔했다. 판정 대상 arm 을 이름으로 고른다.
  grep -h "landing witness" "$td/logs/"*.log 2>/dev/null | head -1 > "$SCRATCH/lw_$3" || : 
  # R2 레인이 읽는다: LEAK arm 의 로그에 토큰 원문이 남았나
  cp "$td/logs/"*.log "$SCRATCH/lg_$3" 2>/dev/null || : 
  echo "$rc|$state"
  rm -rf "$td"
}

CLEAN_BODY="# digest
A clean digest with no operator-private tokens. $(head -c 1200 /dev/zero | tr '\0' 'x')"
LEAK_BODY="# digest
this line carries ZZ_SYNTHETIC_LEAK_TOKEN_ZZ which the fixture pattern file flags HIGH. $(head -c 1200 /dev/zero | tr '\0' 'x')"

r=$(run "$CLEAN_BODY" live clean); t "P1 CLEAN → 게시"            "0|published"  "$r"
r=$(run "$LEAK_BODY"  live leak);  t "P2 LEAK → 격리(.QUARANTINE)" "2|quarantine" "$r"; P2RC=${r%%|*}
r=$(run "$CLEAN_BODY" dead dead);  t "P3 스캐너 사망 → 보류(.UNSCANNED)" "3|unscanned" "$r"; P3RC=${r%%|*}

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

lw=$(cat "$SCRATCH/lw_clean" 2>/dev/null)   # 게이트가 CLEAN 인 arm 에서만 증언이 돈다
case "$lw" in *"landing witness"*) r=logged ;; *) r=absent ;; esac
t "P4 착지 증언이 로그에 찍힌다(배선했다≠발화한다)" "logged" "$r"
case "$lw" in *"SKIPPED (not a pass)"*) r=honest ;; *"ALL-LANDED"*) r=honest ;; *"SOME-UNLANDED"*) r=honest ;; *"HARNESS-ERROR"*) r=honest ;; *) r=other ;; esac
t "P4b SKIP 을 통과로 렌더하지 않는다"          "honest" "$r"

t "N2 control — LEAK 과 NOT-SCANNED 의 rc 가 다르다" "different" "$([ "${P2RC:-x}" != "${P3RC:-y}" ] && echo different || echo collapsed)"

# ── FD_PROFILE 갈래 (2026-08-18) ──────────────────────────────────────────
# 🟥 이 배선은 **한 번 소실됐다.** forge-wiki 워킹 사본에만 넣었다가 PR 정리 때 rm 했고,
# 그 사실을 몰라 다음 대상의 약한 산출을 «입장 티어가 낮다»·«스킬을 못 불렀다»로 오진했다.
# 산출물은 커밋됐는데 그걸 만든 코드가 없던 상태 — 그래서 레인으로 못 박는다.
_prompt() { FH_DIR="$1" OUT_DIR=out HUMAN_DATE=2026-08-18 TODAY=2026_08_18 PROFILE_PATH="$2" \
  bash -c "$(sed -n '/^_build_prompt()/,/^}/p' "$ROOT/scripts/frontier_digest_daily.sh")
_build_prompt"; }
pd=$(mktemp -d); printf 'PROFILE_CANARY_BODY
' > "$pd/p.md"
case "$(_prompt "$pd" "p.md")" in *"PROFILE_CANARY_BODY"*) r=in ;; *) r=missing ;; esac
t "P5 프로필이 프롬프트에 실제로 실린다"        "in" "$r"
case "$(_prompt "$pd" "p.md")" in *"STANDPOINT"*) r=yes ;; *) r=no ;; esac
t "P5b 입장 지시(대상 소스를 열어라)가 실린다"   "yes" "$r"
case "$(_prompt "$pd" "")" in *"STANDPOINT"*|*"TARGET HARNESS"*) r=leaked ;; *) r=clean ;; esac
t "N3 control — 프로필 미설정이면 종전 문자열 그대로(FH 경로 무변경)" "clean" "$r"
case "$(_prompt "$pd" "nonexistent.md")" in *"STANDPOINT"*) r=leaked ;; *) r=clean ;; esac
t "N4 control — 프로필 경로가 없으면 조용히 종전 경로(존재하지 않는 파일을 실었다고 안 한다)" "clean" "$r"
rm -rf "$pd"


# ── R1~R3 (2026-08-18) · 압축 후 수리분 앵커 ───────────────────────────────
# 🟥 세 결함 다 **내가 같은 날 만들었고**, 셋 다 레인이 없어서 「배선 완료」로 보고됐다.

# R2 · 공개 대상이면 로그가 OUT_DIR **밖**이다
_logloc() { # $1 = FD_PUBLIC_TARGET 값 → echoes inside|outside
  local td; td=$(mktemp -d); mkdir -p "$td/scripts" "$td/out" "$td/.claude/rules"
  cp "$ROOT/scripts/frontier_digest_daily.sh" "$td/scripts/"
  cp "$ROOT/scripts/psa_scan_lib.sh" "$td/scripts/"
  cp "$ROOT/.claude/rules/.public-surface-patterns.defaults" "$td/.claude/rules/" 2>/dev/null
  printf 'HIGH\tZZ_SYNTHETIC_LEAK_TOKEN_ZZ\n' > "$td/.claude/rules/.public-surface-patterns"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$td/scripts/stub-claude"; chmod +x "$td/scripts/stub-claude"
  printf 'clean body — 아무 토큰도 없다\n%s\n' "$(head -c 1200 /dev/zero | tr '\0' 'x')" \
    > "$td/out/frontier_digest_$(date +%Y_%m_%d).md"
  ( cd "$td" && FD_FH_DIR="$td" FD_OUT_DIR="out" FD_PUBLIC_TARGET="$1" \
    FD_CLAUDE_BIN="$td/scripts/stub-claude" FD_MAX_ATTEMPTS=1 FD_POLL_SECS=1 \
    bash scripts/frontier_digest_daily.sh ) >/dev/null 2>&1
  local r=outside
  [ -d "$td/out/logs" ] && r=inside
  echo "$r"; rm -rf "$td"
}
t "R2 공개 대상이면 로그가 OUT_DIR 밖에 앉는다"  "outside" "$(_logloc 1)"
t "R2n control — 비공개면 종전 자리 그대로(FH 경로 무변경)" "inside"  "$(_logloc 0)"

# R2b · LEAK 로그에 토큰 원문이 남지 않는다 (run() 이 "$SCRATCH/lg_leak" 에 복사해 둔다)
if [ -f "$SCRATCH/lg_leak" ]; then
  if grep -q 'ZZ_SYNTHETIC_LEAK_TOKEN_ZZ' "$SCRATCH/lg_leak"; then r=raw
  elif grep -q 'REDACTED' "$SCRATCH/lg_leak"; then r=redacted
  else r=nofinding; fi
else r=nolog; fi
t "R2b LEAK 로그가 토큰 원문을 안 적는다(리댁션)" "redacted" "$r"
# R2c · 리댁션이 **allowlist 줄 형태**(끝이 `)`)도 가린다 — 초판은 줄 끝 앵커라 놓쳤다
_red() { bash -c "$(sed -n '/^_redact()/,/^}/p' "$ROOT/scripts/frontier_digest_daily.sh")
_redact \"\$1\"" _ "$1"; }
case "$(_red "  ⚪ allowlisted — f.md: 'ZZ_TOK_ZZ' (row: f.md :: ZZ_TOK_ZZ)")" in
  *ZZ_TOK_ZZ*) r=raw ;; *REDACTED*) r=redacted ;; *) r=other ;;
esac
t "R2c 리댁션이 allowlist 줄 형태도 가린다"      "redacted" "$r"
case "$(_red "  ❌ HIGH leak — f.md: 'ZZ_TOK_ZZ'")" in
  *ZZ_TOK_ZZ*) r=raw ;; *REDACTED*) r=redacted ;; *) r=other ;;
esac
t "R2c-n control — 종전 형태(줄 끝 인용)도 여전히 가린다" "redacted" "$r"

# R2d · **경로 쪽** 토큰 (cross-family/codex F2) — 파일명에 토큰이 들어가면 왼쪽이 남았다
_leaky_name() {
  local td; td=$(mktemp -d); mkdir -p "$td/scripts" "$td/out" "$td/.claude/rules"
  cp "$ROOT/scripts/frontier_digest_daily.sh" "$ROOT/scripts/psa_scan_lib.sh" "$td/scripts/"
  cp "$ROOT/.claude/rules/.public-surface-patterns.defaults" "$td/.claude/rules/" 2>/dev/null
  printf 'HIGH\tZZ_SYNTHETIC_LEAK_TOKEN_ZZ\n' > "$td/.claude/rules/.public-surface-patterns"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$td/scripts/stub-claude"; chmod +x "$td/scripts/stub-claude"
  local d; d=$(date +%Y_%m_%d)
  # 🟥 파일명 자체에 토큰이 들어간 케이스. 본문에도 넣어야 스캐너가 히트를 낸다.
  printf 'ZZ_SYNTHETIC_LEAK_TOKEN_ZZ\n%s\n' "$(head -c 1200 /dev/zero | tr '\0' 'x')" \
    > "$td/out/frontier_digest_${d}-ZZ_SYNTHETIC_LEAK_TOKEN_ZZ.md"
  ( cd "$td" && FD_FH_DIR="$td" FD_OUT_DIR="out" FD_PUBLIC_TARGET=1 FD_LOG_DIR="$td/logs" \
    FD_CLAUDE_BIN="$td/scripts/stub-claude" FD_MAX_ATTEMPTS=1 FD_POLL_SECS=1 \
    bash scripts/frontier_digest_daily.sh ) >/dev/null 2>&1
  if grep -q 'ZZ_SYNTHETIC_LEAK_TOKEN_ZZ' "$td/logs/"*.log 2>/dev/null; then echo raw
  elif grep -q 'FILENAME REDACTED' "$td/logs/"*.log 2>/dev/null; then echo redacted
  else echo other; fi
  rm -rf "$td"
}
t "R2d 파일명에 든 토큰도 로그에 안 남는다"       "redacted" "$(_leaky_name)"

# R3 · 같은 날 파일이 둘이면 **전부** 스캔한다 (head -1 이면 앞엣것만 보고 CLEAN 을 낸다)
_two_files() {
  local td; td=$(mktemp -d); mkdir -p "$td/scripts" "$td/out" "$td/.claude/rules"
  cp "$ROOT/scripts/frontier_digest_daily.sh" "$td/scripts/"
  cp "$ROOT/scripts/psa_scan_lib.sh" "$td/scripts/"
  cp "$ROOT/.claude/rules/.public-surface-patterns.defaults" "$td/.claude/rules/" 2>/dev/null
  printf 'HIGH\tZZ_SYNTHETIC_LEAK_TOKEN_ZZ\n' > "$td/.claude/rules/.public-surface-patterns"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$td/scripts/stub-claude"; chmod +x "$td/scripts/stub-claude"
  local d; d=$(date +%Y_%m_%d)
  # 🟥 «먼저 걸리는» 쪽을 깨끗하게 둔다 — 초판(head -1)이면 이쪽만 보고 CLEAN 을 냈다.
  printf 'aaa clean\n%s\n' "$(head -c 1200 /dev/zero | tr '\0' 'x')" > "$td/out/frontier_digest_${d}.md"
  printf 'zzz ZZ_SYNTHETIC_LEAK_TOKEN_ZZ\n%s\n' "$(head -c 1200 /dev/zero | tr '\0' 'x')" \
    > "$td/out/frontier_digest_${d}_b.md"
  local rc
  ( cd "$td" && FD_FH_DIR="$td" FD_OUT_DIR="out" FD_PUBLIC_TARGET=1 FD_LOG_DIR="$td/logs" \
    FD_CLAUDE_BIN="$td/scripts/stub-claude" FD_MAX_ATTEMPTS=1 FD_POLL_SECS=1 \
    bash scripts/frontier_digest_daily.sh ) >/dev/null 2>&1; rc=$?
  local q=no; ls "$td/out/"*_b.md.QUARANTINE >/dev/null 2>&1 && q=yes
  echo "$rc|$q"; rm -rf "$td"
}
r=$(_two_files)
t "R3 둘째 파일의 LEAK 을 놓치지 않는다(rc)"      "2"   "${r%%|*}"
t "R3b 둘째 파일이 실제로 격리된다"               "yes" "${r##*|}"

# R3c · 선택자 자기모순(digest_ready 참인데 게이트가 볼 파일 0건) → **보류**, 게시 아님
_selector_race() {
  local td; td=$(mktemp -d); mkdir -p "$td/scripts" "$td/out" "$td/.claude/rules"
  cp "$ROOT/scripts/frontier_digest_daily.sh" "$ROOT/scripts/psa_scan_lib.sh" "$td/scripts/"
  cp "$ROOT/.claude/rules/.public-surface-patterns.defaults" "$td/.claude/rules/" 2>/dev/null
  printf 'HIGH\tZZ_SYNTHETIC_LEAK_TOKEN_ZZ\n' > "$td/.claude/rules/.public-surface-patterns"
  # digest_files 를 «참이라 말하고 목록은 비게» 만든다 — 레이스의 최소 재현
  cat > "$td/drv.sh" <<'EOD'
FD_FH_DIR="$PWD"; export FD_FH_DIR
eval "$(sed -n '/^publish_gate()/,/^}/p' scripts/frontier_digest_daily.sh)"
eval "$(sed -n '/^_redact()/,/^}/p' scripts/frontier_digest_daily.sh)"
digest_files() { :; }               # 0건
FH_DIR="$PWD"; OUT_DIR=out; LOG_FILE=/dev/null; FD_PUBLIC_TARGET=1
publish_gate; echo "rc=$?"
EOD
  local o; o=$(cd "$td" && bash drv.sh 2>&1); rm -rf "$td"; echo "${o##*rc=}"
}
t "R3c 선택자 자기모순은 게시가 아니라 보류(3)" "3" "$(_selector_race)"

# R1 · 착지 증언이 **러너를 통해** 살아 있다
# 🟥 초판 레인은 checker 를 **직접** 불러서, R1 을 원복해도 초록이었다 — 호출부를 우회한
#    장식 앵커다([[feedback_anchor_can_be_decorative]]). 되돌림 프로브가 그걸 잡았다.
#    지금은 **러너를 돌리고 그 로그**를 읽는다. 러너가 어떻게 부르는지가 판정 대상이다.
_runner_witness() { # echoes verdict-word from the log
  local td; td=$(mktemp -d)
  ( cd "$td" && git init -q . && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
  mkdir -p "$td/scripts" "$td/out" "$td/knowledge"
  cp "$ROOT/scripts/frontier_digest_daily.sh" "$ROOT/scripts/digest_landing_check.sh" \
     "$ROOT/scripts/utterance_landing_check.sh" "$td/scripts/"
  chmod +x "$td/scripts/digest_landing_check.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$td/scripts/stub-claude"; chmod +x "$td/scripts/stub-claude"
  local d; d=$(date +%Y_%m_%d)
  cat > "$td/out/frontier_digest_2001_01_01.md" <<'EOF'
# prev digest
## 📌 FH Immediate Application Candidates

| # | 티어 | 내용 |
|---|---|---|
| **M1** | **M** | `ZZ_LANDED_TOKEN_ZZ` 를 배선한다 |
EOF
  sleep 1
  printf 'ZZ_LANDED_TOKEN_ZZ 배선함 · ZZ_CTL_ZZ\n' > "$td/out/landed.md"
  printf 'today body\n%s\n' "$(head -c 1200 /dev/zero | tr '\0' 'x')" > "$td/out/frontier_digest_${d}.md"
  ( cd "$td" && FD_FH_DIR="$td" FD_OUT_DIR="out" FD_LOG_DIR="$td/logs" \
    FD_LANDING_TRACKED="knowledge" FD_LANDING_IGNORED="out" FD_LANDING_CONTROLS="ZZ_CTL_ZZ" \
    FD_CLAUDE_BIN="$td/scripts/stub-claude" FD_MAX_ATTEMPTS=1 FD_POLL_SECS=1 \
    bash scripts/frontier_digest_daily.sh ) >/dev/null 2>&1
  local lw; lw=$(grep -h "landing witness" "$td/logs/"*.log 2>/dev/null | tail -1)
  case "$lw" in
    *HARNESS-ERROR*) echo dead ;;
    *ALL-LANDED*)    echo landed ;;
    *SOME-UNLANDED*) echo measured ;;
    *SKIPPED*)       echo skipped ;;
    *)               echo none ;;
  esac
  rm -rf "$td"
}
t "R1 러너가 부르는 형태에서 계기가 살아 있다(HARNESS-ERROR 아님)" "landed" "$(_runner_witness)"

# R5 · «직전 다이제스트» 선택이 **표기 혼재**에서도 옳은가 (첫 실사용 발견)
# 🟥 실물 코퍼스에는 `2026-06-02`(대시)와 `2026_08_17`(언더바)가 **섞여 있다.** 로케일 정렬은
#    대시본을 뒤로 보내 **두 달 전 파일**을 직전으로 골랐고, 그 파일엔 후보 절이 없어 매 런
#    HARNESS-ERROR 였다. 픽스처가 한 표기만 쓰면 레인 21개가 다 초록인 채로 이게 산다.
_prev_pick() {
  local td; td=$(mktemp -d); mkdir -p "$td/out"
  # 🟥 **같은 연도**여야 재현된다. 첫 픽스처는 `2020-06-02` 를 썼는데 그건 로케일 정렬에서도
  #    올바르게 뒤로 가서 **버그 판본도 초록**이었다(되돌림 프로브가 잡은 세 번째 장식 앵커).
  #    실물 코퍼스의 표기를 그대로 쓴다: `2026-06-02` vs `2026_08_17`.
  : > "$td/out/frontier_digest_2026-06-02.md"     # 옛 대시 표기, 날짜상 더 과거
  : > "$td/out/frontier_digest_2026_08_17.md"     # 언더바 표기, 더 최근
  local d; d=$(date +%Y_%m_%d)
  : > "$td/out/frontier_digest_${d}.md"           # 오늘 것 (제외 대상)
  # 러너의 선택 표현을 그대로 떼어 쓴다 — 우회하면 앵커가 장식이 된다
  local expr; expr=$(sed -n '/prev=\$(find/,/tail -1)/p' "$ROOT/scripts/frontier_digest_daily.sh")
  local got; got=$( cd "$td" && FH_DIR="$td" OUT_DIR=out TODAY="$d" bash -c "$expr; basename \"\$prev\"" )
  rm -rf "$td"; echo "$got"
}
t "R5 표기가 섞여도 «직전»은 날짜상 최신이다" "frontier_digest_2026_08_17.md" "$(_prev_pick)"

echo "----"; echo "satellite publish gate: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
