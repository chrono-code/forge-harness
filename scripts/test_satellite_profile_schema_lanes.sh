#!/usr/bin/env bash
# 위성 프로필 스키마 게이트 레인 (2026-08-19, 처방 1+3 · C-2)
#
# 🟥 레인은 **실제 러너를 실행**한다. 함수만 따로 부르면 호출부 우회가 되고, 그건 어제
#    되돌림이 적발한 장식 앵커 3건과 같은 형태다.
# 🟥 `--settings` 가 **실제 argv 에 닿았는지**를 스텁이 기록해서 확인한다 —
#    「만들었다」가 아니라 「전달됐다」를 잰다([[feedback_built_but_not_wired]]).
set -u
RUNNER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/frontier_digest_daily.sh"
PASS=0; FAIL=0
# 🟥 스텁은 다이제스트를 안 만든다 → 러너는 정상적으로 «실패»로 끝난다. 프로덕션 백오프
#    (3회 × 600s)를 그대로 돌면 레인이 30분이 되므로 여기서만 줄인다. **러너 기본값 무변경.**
export FD_MAX_ATTEMPTS=1 FD_RETRY_SLEEP_SECS=1 FD_POLL_SECS=1 FD_ATTEMPT_TIMEOUT_SECS=30
TMPROOT=$(mktemp -d); trap 'rm -rf "$TMPROOT"' EXIT

ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
ng(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "$2"; }

# argv 를 기록하는 claude 스텁. 다이제스트는 안 만든다(= 러너는 결국 실패로 끝난다).
mk_stub(){ cat > "$1" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${STUB_ARGV_OUT}"
exit 0
EOF
chmod +x "$1"; }

# 대상 레포 하나를 만든다. $1=프로필 내용(없으면 프로필 파일 자체를 안 만든다)
mk_repo(){
    local d="$TMPROOT/repo.$RANDOM$RANDOM"; mkdir -p "$d/signals"
    [ $# -ge 1 ] && printf '%s' "$1" > "$d/.satellite-profile.md"
    printf '%s' "$d"
}

run_runner(){  # $1=repo  → rc, 로그는 $LOGD
    LOGD="$TMPROOT/log.$RANDOM"; mkdir -p "$LOGD"
    STUB="$TMPROOT/claude.stub"; mk_stub "$STUB"
    STUB_ARGV_OUT="$TMPROOT/argv.$RANDOM"; export STUB_ARGV_OUT
    FD_FH_DIR="$1" FD_OUT_DIR=signals FD_PROFILE=.satellite-profile.md \
    FD_LOG_DIR="$LOGD" FD_CLAUDE_BIN="$STUB" FD_MODEL=sonnet \
    bash "$RUNNER" >/dev/null 2>&1
    RC=$?
}

FM_FULL='---
satellite_profile: v1
forbidden_paths: [ETHOS.md, LICENSE]
output_location: signals
egress_sinks: [.env, secrets/**]
---

# 본문 산문
'

echo "── A. 필수 필드 ──"
# A1 frontmatter 자체가 없다 (현행 프로필 두 개가 이 상태다)
r=$(mk_repo '# 위성 프로필

산문만 있다'); run_runner "$r"
[ "$RC" -eq 4 ] && ok "A1 frontmatter 부재 → rc=4" || ng "A1 frontmatter 부재" "rc=$RC (기대 4)"
grep -q 'frontmatter 블록 없음' "$LOGD"/*.log && ok "A1b 사유가 로그에 이름으로" || ng "A1b 사유 로그" "미기록"

# A2~A5 필드별 누락
for miss in satellite_profile forbidden_paths output_location egress_sinks; do
    fm=$(printf '%s' "$FM_FULL" | grep -v "^${miss}:")
    r=$(mk_repo "$fm"); run_runner "$r"
    [ "$RC" -eq 4 ] && ok "A:$miss 누락 → rc=4" || ng "A:$miss 누락" "rc=$RC (기대 4)"
    grep -q "필수 필드 누락.*$miss" "$LOGD"/*.log && ok "A:$miss 이름이 로그에" || ng "A:$miss 로그" "이름 없음"
done

# A6 빈 값은 누락과 같다 (명시적 none 을 요구한다)
r=$(mk_repo '---
satellite_profile: v1
forbidden_paths:
output_location: signals
egress_sinks: [none]
---
'); run_runner "$r"
[ "$RC" -eq 4 ] && ok "A6 빈 값 → rc=4 (none 을 명시해야)" || ng "A6 빈 값" "rc=$RC (기대 4)"

echo "── B. 통과 + deny 물질화 ──"
r=$(mk_repo "$FM_FULL"); run_runner "$r"
[ "$RC" -ne 4 ] && ok "B1 완전한 프로필 → 게이트 통과" || ng "B1 완전 프로필" "rc=4 (과차단)"
# 🟥 F9 (cross-family A9): 문자열 grep 은 **깨진 JSON 도 초록**으로 만든다. argv 에서
#    --settings 인자를 꺼내 **JSON 으로 파싱**하고 `.permissions.deny[]` 멤버십을 본다.
deny_has(){ python3 -c '
import json,sys
argv=open(sys.argv[1],encoding="utf-8").read().split("\n")
try: i=argv.index("--settings")
except ValueError: sys.exit(2)
d=json.loads(argv[i+1])["permissions"]["deny"]
sys.exit(0 if sys.argv[2] in d else 1)' "$STUB_ARGV_OUT" "$1" 2>/dev/null; }
grep -qx -- '--settings' "$STUB_ARGV_OUT" && ok "B2 --settings 가 실제 argv 에 닿았다" || ng "B2 argv 배선" "--settings 없음"
deny_has 'Read(./.env)'      && ok "B3 egress_sinks → Read deny (JSON 파싱)" || ng "B3 Read deny" "deny[] 에 없음/JSON 파손"
deny_has 'Edit(./ETHOS.md)'  && ok "B4 forbidden_paths → Edit deny (JSON 파싱)" || ng "B4 Edit deny" "deny[] 에 없음"
deny_has 'Write(./ETHOS.md)' && ok "B5 forbidden_paths → Write deny (JSON 파싱)" || ng "B5 Write deny" "deny[] 에 없음"
deny_has 'Bash(sed:*)'       && ok "B5b acceptEdits 자동승인 변이 Bash 도 deny" || ng "B5b Bash deny" "sed 가 안 막혔다"

# B6 known-negative — 전부 none 이면 규칙 0건이고 --settings 를 안 붙인다
r=$(mk_repo '---
satellite_profile: v1
forbidden_paths: [none]
output_location: signals
egress_sinks: [none]
---
'); run_runner "$r"
[ "$RC" -ne 4 ] && ok "B6 명시적 none → 통과" || ng "B6 none" "rc=4 (과차단)"
grep -qx -- '--settings' "$STUB_ARGV_OUT" 2>/dev/null \
    && ng "B7 none 인데 --settings" "빈 deny 를 붙였다" || ok "B7 none → --settings 안 붙음"

echo "── C. block list 표기 ──"
r=$(mk_repo '---
satellite_profile: v1
forbidden_paths:
  - ETHOS.md
output_location: signals
egress_sinks:
  - .env
---
'); run_runner "$r"
deny_has 'Read(./.env)' && ok "C1 block list 도 파싱된다" || ng "C1 block list" "미파싱"

echo "── B8. 산출 자리 대조 (선언 ≠ 실제) ──"
r=$(mk_repo "$FM_FULL"); LOGD="$TMPROOT/log.b8"; mkdir -p "$LOGD"
STUB_ARGV_OUT="$TMPROOT/argv.b8"; export STUB_ARGV_OUT
# 프로필은 signals 라고 선언했는데 러너는 elsewhere 로 떨어뜨린다
FD_FH_DIR="$r" FD_OUT_DIR=elsewhere FD_PROFILE=.satellite-profile.md \
  FD_LOG_DIR="$LOGD" FD_CLAUDE_BIN="$TMPROOT/claude.stub" bash "$RUNNER" >/dev/null 2>&1
[ $? -eq 4 ] && ok "B8 선언≠실제 → fail-closed" || ng "B8 산출자리 대조" "불일치를 통과시켰다"
grep -q '산출 자리 불일치' "$LOGD"/*.log 2>/dev/null && ok "B8b 양쪽 값이 로그에" || ng "B8b 로그" "미기록"

echo "── D. JSON 조립 방어 ──"
r=$(mk_repo '---
satellite_profile: v1
forbidden_paths: [bad"quote.md]
output_location: signals
egress_sinks: [none]
---
'); run_runner "$r"
[ "$RC" -eq 4 ] && ok "D1 인용부호 → fail-closed" || ng "D1 인용부호" "rc=$RC (기대 4)"

echo "── E. 프로필 부재/미설정 ──"
r=$(mk_repo); LOGD="$TMPROOT/log.e"; mkdir -p "$LOGD"; STUB="$TMPROOT/claude.stub"; mk_stub "$STUB"
STUB_ARGV_OUT="$TMPROOT/argv.e"; export STUB_ARGV_OUT
FD_FH_DIR="$r" FD_OUT_DIR=signals FD_PROFILE=.satellite-profile.md \
  FD_LOG_DIR="$LOGD" FD_CLAUDE_BIN="$STUB" bash "$RUNNER" >/dev/null 2>&1
[ $? -eq 4 ] && ok "E1 FD_PROFILE 지정인데 파일 부재 → rc=4" || ng "E1 파일 부재" "rc≠4"

# E2 — FD_PROFILE 미설정 **+ 엔진 자기 레포**(= FH 자기 런) 만 게이트를 건너뛴다.
# 🟥 초판은 여기서 **임시 레포**를 썼다 — 그건 «FH 자기 런»이 아니라 **위성 모양**이고,
#    그래서 이 레인이 S1 우회(프로필 없이 dispatch)를 «정상»으로 초록 고정하고 있었다.
#    판정 대상이 «FD_PROFILE 유무»가 아니라 «어느 레포에서 도는가»로 바뀌었으므로 픽스처도 바뀐다.
# 실제 FH 레포를 FD_FH_DIR 로 쓰되, 산출·로그는 임시 절대경로로 빼서 실트리를 안 건드린다.
ENGDIR="$(cd "$(dirname "$RUNNER")/.." && pwd -P)"
OUTTMP="$TMPROOT/fhrun.out"; mkdir -p "$OUTTMP"
LOGD="$TMPROOT/log.e2"; mkdir -p "$LOGD"
STUB_ARGV_OUT="$TMPROOT/argv.e2"; export STUB_ARGV_OUT
FD_FH_DIR="$ENGDIR" FD_OUT_DIR="$OUTTMP" FD_LOG_DIR="$LOGD" FD_CLAUDE_BIN="$STUB" \
  bash "$RUNNER" >/dev/null 2>&1
rc=$?
[ "$rc" -ne 4 ] && ok "E2 프로필 미설정 → 게이트 skip (FH 경로 무변경)" || ng "E2 미설정" "rc=4 (FH 런을 막았다)"
grep -q 'profile gate' "$LOGD"/*.log 2>/dev/null && ng "E2b" "미설정인데 게이트가 발화" || ok "E2b 미설정이면 게이트 침묵"

echo "── F. 산출 자리 절대경로 (처방 2) ──"
OUTABS="$TMPROOT/outside.$RANDOM"; mkdir -p "$OUTABS"
# 🟥 프로필의 output_location 도 같은 절대경로여야 한다 — B8 대조가 이제 살아 있어서,
#    선언과 실제가 갈리면(초판 픽스처가 그랬다) 이 레인은 산출자리 불일치로 죽는다.
FM_ABS="---
satellite_profile: v1
forbidden_paths: [none]
output_location: $OUTABS
egress_sinks: [none]
---
"
r=$(mk_repo "$FM_ABS"); LOGD="$TMPROOT/log.f"; mkdir -p "$LOGD"
STUB_ARGV_OUT="$TMPROOT/argv.f"; export STUB_ARGV_OUT
FD_FH_DIR="$r" FD_OUT_DIR="$OUTABS" FD_PROFILE=.satellite-profile.md \
  FD_LOG_DIR="$LOGD" FD_CLAUDE_BIN="$STUB" bash "$RUNNER" >/dev/null 2>&1
grep -q "Save the digest to ${OUTABS}/" "$STUB_ARGV_OUT" 2>/dev/null \
    && ok "F1 절대 FD_OUT_DIR 가 레포 밖으로 간다" || ng "F1 절대경로" "프롬프트가 레포 안을 가리킨다"
[ -d "$r/$OUTABS" ] && ng "F2" "레포 안에 중첩 경로가 생겼다" || ok "F2 레포 트리에 중첩 안 생김"

echo "── G. cross-family 지적 회귀 앵커 (2026-08-19) ──"
# G1 [S1] 위성 런인데 FD_PROFILE 미설정 → 이제 fail-closed 여야 한다.
#    초판은 여기서 통과했고, 레인 E2 가 그걸 «FH 경로 무변경»으로 초록 고정하고 있었다.
r=$(mk_repo "$FM_FULL"); LOGD="$TMPROOT/log.g1"; mkdir -p "$LOGD"
STUB_ARGV_OUT="$TMPROOT/argv.g1"; export STUB_ARGV_OUT
FD_FH_DIR="$r" FD_OUT_DIR=signals FD_LOG_DIR="$LOGD" FD_CLAUDE_BIN="$TMPROOT/claude.stub" \
  bash "$RUNNER" >/dev/null 2>&1
[ $? -eq 4 ] && ok "G1 위성인데 프로필 미설정 → fail-closed" || ng "G1 위성 우회" "프로필 없이 dispatch 까지 갔다"
[ -s "$TMPROOT/argv.g1" ] && ng "G1b" "claude 가 실제로 떴다" || ok "G1b dispatch 자체가 안 일어남"

# G2 [A6] 프로필에 절대경로 → `.//abs` 가 되면 안 된다
ABSSINK="/etc/hosts"
r=$(mk_repo "---
satellite_profile: v1
forbidden_paths: [none]
output_location: signals
egress_sinks: [$ABSSINK]
---
"); run_runner "$r"
deny_has "Read($ABSSINK)" && ok "G2 절대경로 sink → Read(/abs)" || ng "G2 절대경로" "'.//' 이중 접두 또는 미생성"

# G3 [B8] control char → fail-closed
r=$(mk_repo "$(printf -- '---\nsatellite_profile: v1\nforbidden_paths: [bad\tTAB.md]\noutput_location: signals\negress_sinks: [none]\n---\n')"); run_runner "$r"
[ "$RC" -eq 4 ] && ok "G3 control char → fail-closed" || ng "G3 control char" "rc=$RC (기대 4)"

echo
printf 'PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
