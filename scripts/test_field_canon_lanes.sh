#!/usr/bin/env bash
# field_canon_preload.sh 레인 — known-pair 교정.
#
# 이 파일이 있는 이유: 2026-08-09 에 한 세션이 종일 qasp 를 파면서 그 레포 정본(README 604줄 ·
# docs/governance 32개)을 **하나도 안 읽고** 코드 역추론했고 **네 번 정정당했다(자력 적발 0)**.
# ①은 그날의 **첫 메시지를 그대로** 넣는다 — 훅이 있었다면 그 자리에서 걸렸어야 한다.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
H="$HERE/field_canon_preload.sh"
TMP=$(mktemp -d) || exit 10
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "$2"; }

# ── DEBT fix (2026-08-14) — several lanes below depended on the OPERATOR'S REAL
# `${HOME}/projects/qasp-dev` mapping to resolve a repo and emit anything at all. On a
# machine/CI runner without that exact local layout, `repo` resolution in field_canon_preload.sh
# silently fails (`continue`), `emitted` stays 0, and EVERY assertion that checks "is output
# non-empty" trivially reads as the WRONG kind of empty — reproduced locally: PASS 12 / FAIL 7 with
# HOME pointed at an empty dir, exactly the CI split. The fix reuses the fixture shape lane ⑭
# already demonstrates below (a throwaway hub + a throwaway project root with a real `.git` and
# README.md) instead of depending on the operator's real filesystem — `found→extend`, not a new
# mechanism. This also turns ⑧'s prior "PASS" honest: before this fix it passed because repo
# resolution ALWAYS failed (output always empty regardless of dedup), not because dedup worked
# ([[feedback_anchor_can_be_decorative]]) — with a real resolvable repo, ⑧ now exercises the actual
# same-session dedup path.
FHUB="$TMP/fhub"; mkdir -p "$FHUB/tracks/qasp"
FPROJ="$TMP/fproj"; mkdir -p "$FPROJ/qasp-dev/.git" "$FPROJ/qasp-dev/docs/governance"
printf '# qasp fixture\n' > "$FPROJ/qasp-dev/README.md"
printf 'x\n' > "$FPROJ/qasp-dev/docs/governance/g1.md"

# ★`${3:+VAR=v}` 는 파라미터 확장이라 bash 가 **환경 할당으로 안 읽는다** — env 로 넘긴다.
#   (이 파일 초판이 그렇게 써서 「레포 부재」 레인이 거짓 적색을 냈다. 계기 결함이었다.)
# $3, when given, overrides FIELD_CANON_PROJECT_ROOT (the "레포 부재" control at line ~35 uses this
# to deliberately point at /nonexistent — CLAUDE_PROJECT_DIR still resolves via the fixture so that
# control lane is testing "repo absent", not accidentally "mapped name absent" too).
run(){ local root="$FPROJ"; [ -n "${3:-}" ] && root="$3"
  printf '%s' "$1" | env CLAUDE_PROJECT_DIR="$FHUB" FIELD_CANON_PROJECT_ROOT="$root" \
    FIELD_CANON_SENTINEL_DIR="$2" bash "$H" 2>&1; }

echo "== field-canon preload 레인 =="

out=$(run '{"prompt":"세션 시작하자 qasp 병렬세션"}' "$TMP/1")
case "$out" in *qasp*README.md*) ok "① 그날의 첫 메시지 → 정본 경로 제시" ;;
  *) no "① 그날의 첫 메시지" "정본 경로 미출력" ;; esac
case "$out" in *docs/governance*) ok "①-b governance 정본 수를 함께 낸다" ;;
  *) no "①-b governance" "미출력" ;; esac

run '{"prompt":"qasp 시작"}' "$TMP/2" >/dev/null
out=$(run '{"prompt":"qasp 또"}' "$TMP/2")
[ -z "$out" ] && ok "② 세션당 1회 — 재나그 없음" || no "②" "2회차에 또 출력(무시를 학습시킨다)"

out=$(run '{"prompt":"오늘 날씨 어때"}' "$TMP/3")
[ -z "$out" ] && ok "★컨트롤: 매핑 밖 프롬프트는 조용" || no "컨트롤" "오탐 출력"

out=$(run '{"prompt":"qasp"}' "$TMP/4" /nonexistent)
[ -z "$out" ] && ok "★컨트롤: 레포 부재 → 조용(허위 지시 금지)" || no "레포 부재" "없는 경로를 가리켰다"

printf 'not-json' | FIELD_CANON_SENTINEL_DIR="$TMP/5" bash "$H" >/dev/null 2>&1
[ $? = 0 ] && ok "깨진 입력도 rc=0 (비영종료는 stdout 폐기 = 무음)" || no "깨진 입력" "rc≠0"
printf '' | FIELD_CANON_SENTINEL_DIR="$TMP/6" bash "$H" >/dev/null 2>&1
[ $? = 0 ] && ok "빈 입력 rc=0" || no "빈 입력" "rc≠0"

# ── ⑦~⑩ 기본 센티넬 경로 (2026-08-09 추가) ─────────────────────────────────────
# 🟥 **위 ①~⑥ 은 전부 `FIELD_CANON_SENTINEL_DIR` 를 명시로 주입한다** — 즉 실제로 깨져 있던
#    **기본 경로를 구조적으로 우회**했고, 그래서 결함이 초록으로 출하됐다. 여기서부터는 그 변수를
#    **주지 않고** `TMPDIR` 만 격리해 기본 키 산출 로직 자체를 때린다.
#    (`[[feedback_anchor_can_be_decorative]]` — 레인이 결함 지점을 비켜 가면 초록은 정보가 아니다.)
# ⚠️ macOS 는 bash **3.2** 다. `set -u` 아래서 빈 배열 `"${a[@]}"` 는 unbound variable 로 죽는다
#    — 초판 레인이 정확히 그렇게 죽어 ⑦⑨⑩ 이 **거짓 적색**을 냈다(대상이 아니라 계기의 사망).
#    배열 없이 분기한다. (FHUB/FPROJ fixture — see the DEBT-fix comment near the top of this file.)
runD(){ # $1=payload  $2=TMPDIR  [$3=CLAUDE_SESSION_ID 를 환경에 심을지]
  if [ -n "${3:-}" ]; then
    printf '%s' "$1" | env TMPDIR="$2" CLAUDE_PROJECT_DIR="$FHUB" FIELD_CANON_PROJECT_ROOT="$FPROJ" \
      CLAUDE_SESSION_ID="$3" bash "$H" 2>&1
  else
    printf '%s' "$1" | env TMPDIR="$2" CLAUDE_PROJECT_DIR="$FHUB" FIELD_CANON_PROJECT_ROOT="$FPROJ" \
      bash "$H" 2>&1
  fi; }
T7="$TMP/def"; mkdir -p "$T7"

a=$(runD '{"session_id":"AAAA","prompt":"qasp 가자"}' "$T7")
b=$(runD '{"session_id":"BBBB","prompt":"qasp 가자"}' "$T7")
if [ -n "$a" ] && [ -n "$b" ]; then ok "⑦ 세션이 다르면 **둘 다** 안내한다(머신당 1회가 아니다)"
else no "⑦ 세션별 분리" "두 번째 세션이 침묵했다 — 센티넬이 세션을 안 가른다"; fi

c=$(runD '{"session_id":"AAAA","prompt":"qasp 또"}' "$T7")
[ -z "$c" ] && ok "⑧ 같은 세션 2회차는 조용(재나그 없음)" || no "⑧ 동일 세션 dedup" "또 출력"

# ★ peer 조언 채택 — 다만 **판별력 있는 형태로** 짠다.
#   초안은 두 팔을 **다른 TMPDIR** 에서 돌렸는데, 그러면 수리 전 코드도 두 팔 다 발화해서
#   레인이 **원본에서도 초록**이었다(되돌림 실측으로 잡았다 — 존재만 재고 관계를 안 보는 형태).
#   진짜 판별자: **같은 TMPDIR · 같은 payload `session_id` · 다른 환경변수** → 키를 페이로드가
#   정한다면 **두 번째는 침묵**해야 한다. 환경을 읽고 있으면 키가 갈려서 또 발화한다.
T9="$TMP/env"; mkdir -p "$T9"
e1=$(runD '{"session_id":"CCCC","prompt":"qasp 환경팔"}' "$T9")
e2=$(runD '{"session_id":"CCCC","prompt":"qasp 환경팔"}' "$T9" "ZZZZ-환경에서-온-값")
if [ -n "$e1" ] && [ -z "$e2" ]; then ok "⑨ ★키를 페이로드가 정한다(환경변수를 바꿔도 같은 세션)"
else no "⑨ 환경 의존" "환경변수를 바꾸니 같은 세션이 다른 세션으로 갈렸다 — 환경을 읽고 있다"; fi

# session_id 가 아예 없는 페이로드 → **침묵하면 안 된다**(과다 알림 쪽으로 폴백).
# 🟡 명명된 한계: 이 레인은 수리 전 코드에서도 초록이다(literal `shared` 도 첫 발화는 한다).
#    폴백 **방향**만 못박고 **키의 유일성**은 못 잰다 — 그건 ⑦ 과 아래 컨트롤이 맡는다.
T10="$TMP/nosid"; mkdir -p "$T10"
f1=$(runD '{"prompt":"qasp sid 없음"}' "$T10")
[ -n "$f1" ] && ok "⑩ session_id 부재에도 안내한다(폴백 방향 = 과다알림)" \
              || no "⑩ sid 부재 폴백" "조용히 삼켰다 — 초판이 실패한 방향 그대로다"

# ★컨트롤: 기본 경로 레인이 **실제로 기본 경로를 탄다**는 증명.
#   (안 그러면 위 넷은 여전히 우회 레인이다.)
if find "$T7" -maxdepth 1 -name 'fh_field_canon_sid_*' | grep -q . ; then
  ok "★컨트롤: 기본 센티넬 디렉토리가 TMPDIR 아래 실제로 생성됨(우회 아님)"
else
  no "★컨트롤 기본경로" "센티넬이 TMPDIR 에 안 생겼다 — 이 레인들이 무엇을 쟀는지 불명"
fi
if find "$T7" -maxdepth 1 -name 'fh_field_canon_shared' | grep -q . ; then
  no "★컨트롤 literal shared" "전 세션 공유 키가 다시 생겼다(초판 결함 재발)"
else
  ok "★컨트롤: literal 'shared' 키가 생기지 않는다"
fi

# ── ⑪~⑭ cross-family(gpt-5.5) 가 **이 수리에서** 잡은 4건의 회귀 앵커 ──────────────
# 자력 적발 0 이었다. 넷 다 재현된 것이고, 특히 ⑪ 은 **원래 버그와 같은 일가를 수리가 다시 연** 것이다.

# ⑪ [S] 키 충돌 — 정규화/절단이 서로 다른 세션을 같은 칸으로 접으면 안 된다.
T11="$TMP/coll"; mkdir -p "$T11"
x1=$(runD '{"session_id":"A/B","prompt":"qasp 충돌"}' "$T11")
x2=$(runD '{"session_id":"A_B","prompt":"qasp 충돌"}' "$T11")
if [ -n "$x1" ] && [ -n "$x2" ]; then ok "⑪ ★'A/B' 와 'A_B' 는 다른 세션이다(치환 충돌 없음)"
else no "⑪ 키 충돌" "정규화가 두 세션을 같은 센티넬로 접었다 — 원래 버그 재개방"; fi
L1=$(printf 'S%.0s' $(seq 1 70))"-alpha"; L2=$(printf 'S%.0s' $(seq 1 70))"-beta"
y1=$(runD "{\"session_id\":\"$L1\",\"prompt\":\"qasp 길이\"}" "$T11")
y2=$(runD "{\"session_id\":\"$L2\",\"prompt\":\"qasp 길이\"}" "$T11")
if [ -n "$y1" ] && [ -n "$y2" ]; then ok "⑪-b ★긴 session_id 의 접두 절단 충돌 없음"
else no "⑪-b 절단 충돌" "앞 N자가 같은 두 세션이 한 칸을 공유한다"; fi

# ⑫ [A] 개행 오염 — session_id 의 개행이 프롬프트 파싱으로 새면 안 된다.
T12="$TMP/nl"; mkdir -p "$T12"
z=$(runD '{"session_id":"AA\nqasp","prompt":"오늘 날씨 어때"}' "$T12")
[ -z "$z" ] && ok "⑫ ★session_id 의 개행이 프롬프트로 새지 않는다" \
             || no "⑫ 개행 오염" "무관 프롬프트인데 발화했다 — SID 개행이 PROMPT 로 샜다"

# ⑬ [A] HOME 부재에서도 rc=0 (헤더의 "항상 0" 계약)
env -u HOME -u CLAUDE_PROJECT_DIR -u FIELD_CANON_PROJECT_DIR TMPDIR="$TMP/nh" \
  bash "$H" </dev/null >/dev/null 2>&1
[ $? = 0 ] && ok "⑬ ★HOME 부재에서도 rc=0(set -u unbound 로 안 죽는다)" \
            || no "⑬ HOME 부재" "rc≠0 — 비영종료는 stdout 폐기라 무음 실패가 된다"

# ⑭ [B] 매핑 이름의 regex 문자 — 고정문자열 매칭이어야 한다.
# ⚠️ 초판 ⑭ 는 **양쪽에서 초록**이었다(약한 레인) — grep 이 매칭돼도 그 다음 «레포 해석» 단계가
#    막아서 결과가 안 드러났다. 레포와 README 까지 실제로 만들어 **grep 이 유일한 판별 지점**이 되게 한다.
HUB14="$TMP/hub14"; mkdir -p "$HUB14/tracks/q.sp"
P14="$TMP/proj14"; mkdir -p "$P14/q.sp/.git"; printf 'x\n' > "$P14/q.sp/README.md"
w=$(printf '%s' '{"session_id":"RX","prompt":"qXsp 를 보자"}' \
    | env TMPDIR="$TMP/rx" CLAUDE_PROJECT_DIR="$HUB14" FIELD_CANON_PROJECT_ROOT="$P14" bash "$H" 2>&1)
[ -z "$w" ] && ok "⑭ ★'q.sp' 트랙이 'qXsp' 에 오탐하지 않는다(grep -F)" \
             || no "⑭ regex 오탐" "이름의 '.' 가 임의문자로 매칭됐다"
# ★컨트롤 — 정확히 일치하는 이름은 **반드시** 잡혀야 한다(위 침묵이 공허하지 않음을 증명).
w2=$(printf '%s' '{"session_id":"RX2","prompt":"q.sp 를 보자"}' \
    | env TMPDIR="$TMP/rx2" CLAUDE_PROJECT_DIR="$HUB14" FIELD_CANON_PROJECT_ROOT="$P14" bash "$H" 2>&1)
[ -n "$w2" ] && ok "⑭-b ★컨트롤: 정확히 'q.sp' 는 잡힌다(⑭ 의 침묵이 공허하지 않다)" \
              || no "⑭-b 컨트롤" "정확한 이름도 못 잡는다 — ⑭ 는 무엇도 증명하지 않는다"

echo "── PASS $PASS · FAIL $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
