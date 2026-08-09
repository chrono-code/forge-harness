#!/usr/bin/env bash
# test_relay_channel_lanes.sh — relay_channel.sh 의 known-pair 레인.
#
# 설계 원칙(이 레포가 이미 비싸게 배운 것):
#   · **BLOCK/PASS 대칭** — PASS arm 이 없으면 "전부 막는 게이트" 도 만점을 받는다.
#   · **판별자 주입** — 두 세계(진짜 relay ↔ 독립 2회 호출)가 갈리는 입력을 반드시 포함.
#   · **미측정≠0** — 계기가 안 돈 레인을 초록으로 렌더하지 않는지 직접 잰다.
#   · 픽스처는 실물 형태로. 성공만 있는 픽스처는 계기를 검증하지 못한다.
#
# 각 레인이 **어느 배선 줄을 붙잡고 있는지**를 주석에 적는다(비장식 증명의 지도).
set -u
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
RELAY="$SELF_DIR/relay_channel.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0

_t() { # $1=name $2=expected_rc $3=actual_rc
  if [ "$2" = "$3" ]; then printf '✅ %s\n' "$1"; pass=$((pass+1))
  else printf '❌ %s → rc=%s (기대 %s)\n' "$1" "$3" "$2"; fail=$((fail+1)); fi
}
_tout() { # $1=name $2=needle $3=file  — 출력 내용 레인
  if grep -q "$2" "$3" 2>/dev/null; then printf '✅ %s\n' "$1"; pass=$((pass+1))
  else printf '❌ %s → 출력에 "%s" 없음\n' "$1" "$2"; fail=$((fail+1)); fi
}
_tnot() {
  if grep -q "$2" "$3" 2>/dev/null; then printf '❌ %s → 있으면 안 되는 "%s" 가 있다\n' "$1" "$2"; fail=$((fail+1))
  else printf '✅ %s\n' "$1"; pass=$((pass+1)); fi
}

# ── 픽스처 노드 ──────────────────────────────────────────────────────────────
mk() { printf '%s\n' "$2" > "$T/$1"; chmod +x "$T/$1"; }

mk n_pass.sh '#!/usr/bin/env bash
echo "ran pass"; exit 0'
mk n_fail.sh '#!/usr/bin/env bash
echo "ran fail"; exit 1'
mk n_odd.sh '#!/usr/bin/env bash
echo "ran odd"; exit 7'
# 계기가 죽은 노드 — enum 밖 코드를 낸다 ⇒ verdict 해석 불가 ⇒ HARNESS_ERROR
mk n_broken.sh '#!/usr/bin/env bash
echo "tooling offline"; exit 66'
# 실행 흔적을 남기는 노드 — 단락(short-circuit) 증명용
mk n_mark.sh '#!/usr/bin/env bash
touch "$MARK_FILE"; echo "ran mark"; exit 0'
# ★ 인과 결박 검증 노드 — 상류 verdict 를 **실제로 받았는지** 스스로 채점한다.
#   relay 가 --upstream-verdict 를 안 넘기면 이 노드가 실패한다.
mk n_needs_upstream.sh '#!/usr/bin/env bash
got=""
while [ $# -gt 0 ]; do case "$1" in --upstream-verdict) shift; got="$1";; esac; shift; done
if [ "$got" = "$EXPECT_UPSTREAM" ]; then echo "upstream ok: $got"; exit 0
else echo "upstream MISSING (got='"'"'$got'"'"' want='"'"'$EXPECT_UPSTREAM'"'"')"; exit 1; fi'
# stdout-key 채널인데 키를 안 내는 노드 (D4)
mk n_silent.sh '#!/usr/bin/env bash
echo "no verdict key here"; exit 0'

ENUM='0=PASS 1=FAIL 7=ODD'

cap() { # $1=filename $2..=lines
  local f="$T/$1"; shift; : > "$f"; for l in "$@"; do printf '%s\n' "$l" >> "$f"; done; printf '%s' "$f"
}

# ── L1 PASS arm — 2노드 전부 PASS, mechanical ─────────────────────────────────
A=$(cap a1.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
B=$(cap b1.cap "id: demo:b" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A" --cap "$B" --task t > "$T/o1" 2>&1 || rc=$?
_t   "L1  PASS arm — 2노드 정상 통과" 0 "$rc"
_tout "L1b CLEARING 으로 표기" "FH_RELAY_CLEARING: CLEARING" "$T/o1"

# ── L2 BLOCKED at node1 + ★단락 증명 ──────────────────────────────────────────
#     붙잡는 배선: do_run 의 "blocking 판정 → 즉시 체인 중단" 블록(return "$RC_BLOCKED")
A2=$(cap a2.cap "id: demo:a" "entry: bash $T/n_fail.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
export MARK_FILE="$T/node2_ran.marker"; rm -f "$MARK_FILE"
B2=$(cap b2.cap "id: demo:b" "entry: bash $T/n_mark.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A2" --cap "$B2" --task t > "$T/o2" 2>&1 || rc=$?
_t "L2  BLOCK arm — node1 FAIL 이 체인을 막는다" 2 "$rc"
if [ -f "$MARK_FILE" ]; then printf '❌ L2b 단락 실패 — 막힌 뒤에도 node2 가 실행됐다\n'; fail=$((fail+1))
else printf '✅ L2b 단락 — 막힌 뒤 node2 는 실행되지 않았다(부작용 차단)\n'; pass=$((pass+1)); fi

# ── L3 BLOCKED at node2 ───────────────────────────────────────────────────────
B3=$(cap b3.cap "id: demo:b" "entry: bash $T/n_fail.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A" --cap "$B3" --task t > "$T/o3" 2>&1 || rc=$?
_t "L3  BLOCK arm — node2 에서 막혀도 잡는다" 2 "$rc"

# ── L4 judge:model → NON_CLEARING (D2) ────────────────────────────────────────
#     붙잡는 배선: MERGED_judge = model 분기
B4=$(cap b4.cap "id: demo:b" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: model" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A" --cap "$B4" --task t > "$T/o4" 2>&1 || rc=$?
_t    "L4  model-only PASS 는 PASS 가 아니다 → PENDING" 1 "$rc"
_tout "L4b NON_CLEARING 명시" "NON_CLEARING" "$T/o4"

# ── L5 ★ fail-open 판별 레인 — 두 세계가 여기서 갈린다 ────────────────────────
#     A=fail-closed · B=advisory 인데 B 의 계기가 죽었다.
#     진짜 relay: B 가 A 의 fail-closed 를 **상속** → BLOCKED(빨강)
#     독립 2회 호출: B 로컬 advisory → 통과(거짓 초록)
#     붙잡는 배선: "$MERGED_degrade" = fail-closed 분기
A5=$(cap a5.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: fail-closed" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
B5=$(cap b5.cap "id: demo:b" "entry: bash $T/n_broken.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A5" --cap "$B5" --task t > "$T/o5" 2>&1 || rc=$?
_t    "L5  ★판별 — B 가 A 의 fail-closed 를 상속해 계기사망을 막는다" 2 "$rc"
_tout "L5b 막힌 이유를 degrade 로 명시" "merged degrade=fail-closed" "$T/o5"

# ── L6 advisory-only + 계기사망 → PASS 아님(PENDING). 미측정≠PASS ─────────────
A6=$(cap a6.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A6" --cap "$B5" --task t > "$T/o6" 2>&1 || rc=$?
_t    "L6  advisory 로 통과시킨 계기사망은 clearing PASS 가 아니다" 1 "$rc"
_tnot "L6b 초록으로 렌더되지 않는다" "FH_RELAY_VERDICT: PASS" "$T/o6"

# ── L7 오타 축 = VIOLATION (D3) ───────────────────────────────────────────────
A7=$(cap a7.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrad: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A7" --cap "$B" --task t > "$T/o7" 2>&1 || rc=$?
_t "L7  오타난 축을 무음 드롭하지 않는다 → VIOLATION" 4 "$rc"

# ── L8 enum 밖 값 = VIOLATION (허용값으로 폴백 금지) ──────────────────────────
A8=$(cap a8.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: whenever" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A8" --cap "$B" --task t > "$T/o8" 2>&1 || rc=$?
_t "L8  enum 밖 값은 허용값으로 폴백하지 않는다 → VIOLATION" 4 "$rc"

# ── L9/L10 ESCALATE — 병합 approval 이 사람을 요구 ────────────────────────────
A9=$(cap a9.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: ask" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A9" --cap "$B" --task t > "$T/o9" 2>&1 || rc=$?
_t "L9  strictest-wins — 한쪽 ask 가 auto 를 이긴다 → ESCALATE" 3 "$rc"
rc=0; bash "$RELAY" run --cap "$A9" --cap "$B" --task t --ack > "$T/o10" 2>&1 || rc=$?
_t "L10 PASS arm — --ack 승인 후에는 진행한다(과차단 아님)" 0 "$rc"

# ── L11 ★ 인과 결박 (D5) — node2 가 node1 의 verdict 를 실제로 받았는가 ────────
#     붙잡는 배선: _invoke_node 의 argv_extra="--upstream-verdict $upstream"
export EXPECT_UPSTREAM="PASS"
B11=$(cap b11.cap "id: demo:b" "entry: bash $T/n_needs_upstream.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "upstream_argv: yes" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A" --cap "$B11" --task t > "$T/o11" 2>&1 || rc=$?
_t "L11 ★인과결박(argv) — node2 가 node1 의 verdict 를 인자로 실제 수령" 0 "$rc"
_tout "L11b 체인 기록에 upstream 결박 해시가 남는다" "upstream_binding_sha=" "$(grep -o '[^ ]*CHAIN.txt' "$T/o11" | head -1)"

# ── L18 ★ 첫 실사용이 잡은 결함의 회귀 앵커 ──────────────────────────────────
#     실물 필드 스캐너는 `TARGETS=("$@")` 로 인자를 전부 **경로**로 받는다.
#     결박 플래그를 무조건 붙이면 그 노드가 없는 경로를 스캔하려다 깨진다 —
#     계기가 피감 대상을 바꾸면 결박 자체가 무의미해진다.
#     ⇒ argv 주입은 `upstream_argv: yes` 를 선언한 노드에만. env 는 항상.
mk n_argv_strict.sh '#!/usr/bin/env bash
# 실물 스캐너와 같은 형태: 인자를 전부 경로로 본다. 모르는 인자가 오면 깨진다.
for a in "$@"; do [ -e "$a" ] || { echo "unknown target: $a"; exit 1; }; done
# env 채널은 살아 있어야 한다 — 결박이 사라지면 안 되므로.
[ -n "$RELAY_UPSTREAM_VERDICT" ] || { echo "env upstream missing"; exit 1; }
echo "argv clean, env upstream=$RELAY_UPSTREAM_VERDICT"; exit 0'
B18=$(cap b18.cap "id: demo:b" "entry: bash $T/n_argv_strict.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A" --cap "$B18" --task t > "$T/o18" 2>&1 || rc=$?
_t "L18 ★argv 미선언 노드는 안 깨지고, 결박은 env 로 살아 있다" 0 "$rc"

# ── L12 role-fit 위반 (검사3) — write-remote × 비공개 residency ────────────────
A12=$(cap a12.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: company" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
B12=$(cap b12.cap "id: demo:b" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: write-remote" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A12" --cap "$B12" --task t > "$T/o12" 2>&1 || rc=$?
_t "L12 검사3 — 각 표는 옳은데 짝이 틀린 조합을 잡는다" 4 "$rc"

# ── L13 파생 조임 — 비가역 sink 를 체인이 상속한다(A2) ────────────────────────
B13=$(cap b13.cap "id: demo:b" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: irreversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A" --cap "$B13" --task t > "$T/o13" 2>&1 || rc=$?
_t    "L13 비가역 노드가 있으면 auto 여도 사람에게 온다" 3 "$rc"
_tout "L13b 파생 조임을 숨기지 않고 적는다" "FH_MERGED_derived:" "$T/o13"

# ── L14 1노드는 relay 가 아니다 ───────────────────────────────────────────────
rc=0; bash "$RELAY" run --cap "$A" --task t > "$T/o14" 2>&1 || rc=$?
_t "L14 1노드 호출을 relay 로 세지 않는다" 10 "$rc"

# ── L15 stdout-key 채널인데 키 부재 → HARNESS_ERROR (D4) ──────────────────────
A15=$(cap a15.cap "id: demo:a" "entry: bash $T/n_silent.sh" "verdict_channel: stdout-key" \
  "verdict_stdout_key: FH_GATE_VERDICT" "verdict_enum: 0=PASS 1=FAIL" \
  "approval: auto" "reversibility: reversible" \
  "residency: public" "degrade: fail-closed" "tier_floor: none" "writes: read-only" \
  "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A15" --cap "$B" --task t > "$T/o15" 2>&1 || rc=$?
_t "L15 선언 채널에 값이 없으면 빈 집합이 아니라 HARNESS_ERROR" 2 "$rc"

# ── L16 verdict_binding 은 합집합 — 남이 선언한 blocking 이 나를 막는다 ───────
A16=$(cap a16.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: ODD")
B16=$(cap b16.cap "id: demo:b" "entry: bash $T/n_odd.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A16" --cap "$B16" --task t > "$T/o16" 2>&1 || rc=$?
_t "L16 verdict_binding 합집합 — B 가 선언 안 한 ODD 로도 막힌다" 2 "$rc"

# ── L17 merge 서브커맨드 — 병합만 계산 ────────────────────────────────────────
rc=0; bash "$RELAY" merge --cap "$A9" --cap "$B" > "$T/o17" 2>&1 || rc=$?
_t    "L17 merge 서브커맨드 단독 동작" 0 "$rc"
_tout "L17b strictest-wins 결과가 그대로 보인다" "FH_MERGED_approval: ask" "$T/o17"

# ── L19 ★ 첫 실사용에서 나온 fail-open 의 회귀 앵커 (D7) ─────────────────────
#     stdout-key 채널은 노드가 찍은 **임의 문자열**을 verdict 로 받는다.
#     초판은 그 값이 선언 enum 안인지 검사하지 않아, 노드가 모르는 단어를 찍으면
#     binding 에 없다는 이유로 그대로 PASS 가 됐다 — 어휘를 노드에 넘긴 fail-open.
mk n_lies.sh '#!/usr/bin/env bash
echo "FH_GATE_VERDICT: TOTALLY_FINE"; exit 0'
A19=$(cap a19.cap "id: demo:a" "entry: bash $T/n_lies.sh" "verdict_channel: stdout-key" \
  "verdict_stdout_key: FH_GATE_VERDICT" "verdict_enum: 0=PASS 1=FAIL" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: fail-closed" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A19" --cap "$B" --task t > "$T/o19" 2>&1 || rc=$?
_t    "L19 ★enum 밖 verdict 를 노드가 찍어도 PASS 로 통과시키지 않는다" 2 "$rc"
# ⚠️ 단정 주의: 거부 사유는 그 값을 **이름 붙여** 알려주는 게 옳다(무엇이 거부됐는지 모르면
#   디버깅이 불가). 그러므로 "문자열이 어디에도 없을 것" 이 아니라 "**승격되지 않았을 것**" 을 잰다.
_tnot "L19b 노드가 지어낸 어휘가 verdict 로 승격되지 않는다" "FH_NODE1_VERDICT: TOTALLY_FINE" "$T/o19"
_tout "L19c 무엇이 왜 거부됐는지는 이름 붙여 보고한다" "선언된 enum 밖" "$T/o19"

# ── L20–L22 ★ both-silent 분기 — 초판이 스펙보다 과엄격이었다 ────────────────
#     레인이 하나도 안 덮던 분기다. "축을 하나도 선언 안 한 capfile" 로만 재면
#     초판과 정본이 **같은 결과**(둘 다 VIOLATION)라 차이가 안 보인다.
#     갈리는 입력은 **일부만 미선언**인 조합이다 — 판별자를 그쪽에 심는다.
# L20: approval 만 미선언, 나머지는 돌 수 있게 선언 → 스펙은 ask(=ESCALATE), 초판은 forbidden(=VIOLATION)
A20=$(cap a20.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
B20=$(cap b20.cap "id: demo:b" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A20" --cap "$B20" --task t > "$T/o20" 2>&1 || rc=$?
_t    "L20 ★approval 미선언은 ask 이지 forbidden 이 아니다 → ESCALATE" 3 "$rc"
_tout "L20b 병합값이 스펙이 명명한 ask" "FH_MERGED_approval: ask" "$T/o20"
rc=0; bash "$RELAY" run --cap "$A20" --cap "$B20" --task t --ack > "$T/o20b" 2>&1 || rc=$?
_t    "L20c 과차단 아님 — 승인하면 실제로 돈다" 0 "$rc"
# L21: tier_floor 만 미선언 → 스펙에 both-silent 값이 없으므로 **추정 금지**, 선언 요구
A21=$(cap a21.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
B21=$(cap b21.cap "id: demo:b" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A21" --cap "$B21" --task t > "$T/o21" 2>&1 || rc=$?
_t    "L21 스펙이 정의 안 한 축은 값을 지어내지 않고 선언을 요구한다" 4 "$rc"
_tout "L21b 어느 축인지 이름을 댄다" "tier_floor" "$T/o21"
# L22: 전건 미선언 → 여전히 막히되, behaviour 는 최유능으로 채워져 검사3 에 걸린다
A22=$(cap a22.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" "verdict_binding: FAIL")
B22=$(cap b22.cap "id: demo:b" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A22" --cap "$B22" --task t > "$T/o22" 2>&1 || rc=$?
_t    "L22 전건 미선언은 여전히 돌지 않는다(부재는 허가가 아니다)" 4 "$rc"
# ⚠️ 병합 단계 위반은 검사1/2/3 **이전**에 반환된다 — 그래서 role-fit 사유는 여기서 안 뜬다.
#   그게 옳다(고치고 다시 돌리는 흐름). 단정은 실제로 먼저 나는 사유에 건다.
_tout "L22b 막힌 사유를 최소 하나는 이름 붙여 보고한다" "COMPOSITION_VIOLATION" "$T/o22"

# ════════════════════════════════════════════════════════════════════════════
# L23–L30 — 마무리 적대검증(cross-family, gpt-5.5)이 **실행으로 재현한** BLOCK 7건 +
#           MAJOR 2건의 회귀 앵커. 전건 NOT-CONVERGED 로 돌아왔고 전부 진성이었다.
#           자력 적발 0건이므로 여기 레인이 유일한 재발 방어선이다.
# ════════════════════════════════════════════════════════════════════════════

# L23 ★ 최악 — **스펙 스키마 그대로 쓴 capfile 이 뚫렸다.**
#     스펙 §ⓑ.2 예시는 `verdict_binding: [FAIL, DID_NOT_RUN, HARNESS_ERROR]` 인데
#     초판 파서는 공백 분해라 토큰이 `[FAIL,` 가 되고 blocking 집합이 증발했다 → PASS.
#     스펙을 잘 따른 사용자가 가장 크게 당하는 형태라 심각도가 최상이다.
A23=$(cap a23.cap "id: demo:a" "entry: bash $T/n_fail.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: [FAIL, ODD]")
rc=0; bash "$RELAY" run --cap "$A23" --cap "$B" --task t > "$T/o23" 2>&1 || rc=$?
_t "L23 ★스펙 스키마 표기 [A, B] 를 그대로 해석한다" 2 "$rc"

# L24 글롭 — `verdict_binding: *` 가 파일명으로 확장되면 병합이 입력보다 느슨해진다
A24=$(cap a24.cap "id: demo:a" "entry: bash $T/n_odd.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: ODD")
rc=0; (cd "$T" && bash "$RELAY" merge --cap "$A24" --cap "$B" > "$T/o24" 2>&1) || rc=$?
_tnot "L24 선언값이 파일명으로 확장되지 않는다" "\.cap\.cap\|n_pass\.sh " "$T/o24"
_tout "L24b binding 집합이 선언 그대로다" "FH_MERGED_verdict_binding: ODD FAIL" "$T/o24"

# L25 both 채널 불일치 — stdout 이 실패한 exit 을 덮어쓰면 안 된다
mk n_lying_exit.sh '#!/usr/bin/env bash
echo "FH_GATE_VERDICT: PASS"; exit 1'
A25=$(cap a25.cap "id: demo:a" "entry: bash $T/n_lying_exit.sh" "verdict_channel: both" \
  "verdict_stdout_key: FH_GATE_VERDICT" "verdict_enum: 0=PASS 1=FAIL" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: fail-closed" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A25" --cap "$B" --task t > "$T/o25" 2>&1 || rc=$?
_t    "L25 both 불일치를 관대한 쪽으로 해소하지 않는다" 2 "$rc"
_tnot "L25b exit 1 인데 PASS 로 렌더되지 않는다" "FH_NODE1_VERDICT: PASS" "$T/o25"

# L26 시그널 사망 — enum 이 137=PASS 라고 선언해도 죽음은 verdict 가 아니다
mk n_suicide.sh '#!/usr/bin/env bash
kill -9 $$'
A26=$(cap a26.cap "id: demo:a" "entry: bash $T/n_suicide.sh" "verdict_channel: exit" \
  "verdict_enum: 137=PASS 1=FAIL" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: fail-closed" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A26" --cap "$B" --task t > "$T/o26" 2>&1 || rc=$?
# 라운드 2 이후: 이런 enum 은 **앞단 lint 에서** 거부된다(인정 못 할 선언을 통과시키는
# lint 는 거짓말이므로). 그래서 기대값이 BLOCKED(2) 가 아니라 VIOLATION(4) 다.
_t    "L26 인정 못 할 enum 코드(>128)를 앞단에서 거부한다" 4 "$rc"
# 라운드 3 이후 경계가 128→126 으로 내려갔다(126/127 = 실행 불가·명령 없음도 "안 돌았다").
_tout "L26b 왜 거부했는지 코드를 대며 말한다" "126 이상" "$T/o26"
# 그리고 런타임 방어도 따로 살아 있어야 한다(합법 enum + 시그널 사망) — defense in depth.
A26b=$(cap a26b.cap "id: demo:a" "entry: bash $T/n_suicide.sh" "verdict_channel: exit" \
  "verdict_enum: 0=PASS 1=FAIL" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: fail-closed" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A26b" --cap "$B" --task t > "$T/o26b" 2>&1 || rc=$?
_t "L26c 합법 enum 이어도 시그널 사망은 HARNESS_ERROR 로 막힌다" 2 "$rc"

# L27 verdict_enum 부재 = 등록 불가 (닫힌 어휘 없이는 typed 가 아니다)
A27=$(cap a27.cap "id: demo:a" "entry: bash $T/n_lies.sh" "verdict_channel: stdout-key" \
  "verdict_stdout_key: FH_GATE_VERDICT" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: fail-closed" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A27" --cap "$B" --task t > "$T/o27" 2>&1 || rc=$?
_t "L27 enum 없는 capability 는 호출 불가다" 4 "$rc"

# L28 stdout 키는 리터럴 — 정규식이면 다른 키의 값을 verdict 로 받는다
mk n_other_key.sh '#!/usr/bin/env bash
echo "FH_FAKE: PASS"; exit 0'
A28=$(cap a28.cap "id: demo:a" "entry: bash $T/n_other_key.sh" "verdict_channel: stdout-key" \
  "verdict_stdout_key: FH_.*" "verdict_enum: 0=PASS 1=FAIL" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: fail-closed" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A28" --cap "$B" --task t > "$T/o28" 2>&1 || rc=$?
_t "L28 선언 키를 정규식으로 매칭하지 않는다(다른 키 수용 금지)" 2 "$rc"

# L29 ★ 기록의 정직성 — "넘겼다" 와 "소비했다" 는 다른 주장이다
#     상류를 무시하는 노드도 초판 기록에선 같은 줄을 얻었다. 이제 소비는 별도 축이고
#     선언 없이는 UNVERIFIED 다(미측정을 확인됨으로 렌더하지 않는다).
rc=0; bash "$RELAY" run --cap "$A" --cap "$B18" --task t --record "$T/rec29" > "$T/o29" 2>&1 || rc=$?
_t    "L29 소비 미선언 노드도 정상 주행한다" 0 "$rc"
_tout "L29b 소비를 UNVERIFIED 로 정직하게 적는다" "upstream_consumption=UNVERIFIED" "$T/rec29/CHAIN.txt"
mk n_echo_up.sh '#!/usr/bin/env bash
echo "RELAY_UPSTREAM_SEEN: $RELAY_UPSTREAM_VERDICT"; exit 0'
B29=$(cap b29.cap "id: demo:b" "entry: bash $T/n_echo_up.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "echoes_upstream: yes" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A" --cap "$B29" --task t --record "$T/rec29b" > "$T/o29b" 2>&1 || rc=$?
_t    "L29c 되돌려 찍는 노드는 소비가 실제로 검증된다" 0 "$rc"
_tout "L29d VERIFIED 는 되돌림이 있을 때만 붙는다" "upstream_consumption=VERIFIED" "$T/rec29b/CHAIN.txt"

# L30 공백 있는 경로 — 유효한 capfile 이 쪼개져 '없음' 이 되면 안 된다
mkdir -p "$T/with space"
cp "$A" "$T/with space/a cap.cap"; cp "$B" "$T/with space/b cap.cap"
rc=0; bash "$RELAY" run --cap "$T/with space/a cap.cap" --cap "$T/with space/b cap.cap" --task t > "$T/o30" 2>&1 || rc=$?
_t "L30 공백 있는 경로의 capfile 을 쪼개지 않는다" 0 "$rc"

# ════════════════════════════════════════════════════════════════════════════
# L31–L33 — **수렴 라운드 2** 가 잡은 신규 4건. 셋은 라운드 1 의 **내 수리가 만든 것**이다
#           ([[feedback_repair_is_the_main_defect_source]] 의 재현 — 수리가 신규 결함의
#           주된 출처다). 그래서 수리마다 짝 레인을 붙이는 게 규율이지 장식이 아니다.
# ════════════════════════════════════════════════════════════════════════════

# L31 ★ 중복 키 — `_cap_get` 은 first-wins 라, 같은 키를 두 번 쓰면 뒤엣것이 무음 무시된다.
#     `verdict_enum: 1=PASS` 를 앞에 두면 **실패 코드가 PASS 로 세탁**되고,
#     `approval`/`reversibility` 중복은 비가역→ask 파생 조임까지 우회한다.
#     어느 쪽이 유효한지는 임의적이므로 **고르지 않고 거부한다.**
A31=$(cap a31.cap "id: demo:a" "entry: bash $T/n_fail.sh" "verdict_channel: exit" \
  "verdict_enum: 1=PASS" "verdict_enum: 1=FAIL 0=PASS" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A31" --cap "$B" --task t > "$T/o31" 2>&1 || rc=$?
_t    "L31 ★중복 키를 first-wins 로 삼키지 않는다" 4 "$rc"
_tout "L31b 중복이라고 이름 대며 거부한다" "중복 선언" "$T/o31"
# 파생 조임 우회 변형 — approval/reversibility 중복
A31b=$(cap a31b.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "approval: ask" "reversibility: irreversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A31b" --cap "$B" --task t > "$T/o31b" 2>&1 || rc=$?
_t "L31c 중복으로 파생 조임(비가역→ask)을 우회할 수 없다" 4 "$rc"

# L32 ★ 원자 안의 스키마 문자 — 조용한 정규화가 fail-open 이다.
#     enum 이름이 `FAIL,ODD` 면 `_cap_binding` 이 `FAIL` `ODD` 로 쪼개고, 노드가 내는
#     실제 verdict `FAIL,ODD` 와 **영원히 안 맞아** blocking 이 무력화된다.
A32=$(cap a32.cap "id: demo:a" "entry: bash $T/n_fail.sh" "verdict_channel: exit" \
  "verdict_enum: 0=PASS 1=FAIL,ODD" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL,ODD")
rc=0; bash "$RELAY" run --cap "$A32" --cap "$B" --task t > "$T/o32" 2>&1 || rc=$?
_t    "L32 ★원자에 스키마 문자를 쓰면 조용히 정규화하지 않고 거부한다" 4 "$rc"
_tnot "L32b 무음 통과(PASS)로 끝나지 않는다" "FH_RELAY_VERDICT: PASS" "$T/o32"

# L33 소비 검증도 리터럴 — 같은 결함이 다른 자리에 남은 반쪽-픽스였다.
#     상류 verdict 이름이 `P.*` 이면 초판은 노드가 찍은 `PASS` 를 VERIFIED 로 받았다.
mk n_pdot.sh '#!/usr/bin/env bash
echo "regex-named verdict"; exit 3'
A33=$(cap a33.cap "id: demo:a" "entry: bash $T/n_pdot.sh" "verdict_channel: exit" \
  "verdict_enum: 3=P.* 1=FAIL" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
# ⚠️ 판별자: 이 노드는 상류값을 **그대로 되돌리지 않고** 고정 문자열 `PASS` 를 찍는다.
#   상류 이름이 `P.*` 라 정규식 대조였다면 이게 매칭돼 거짓 VERIFIED 가 났다.
#   (상류값을 그대로 echo 하는 노드로 재면 진짜 VERIFIED 라 판별이 안 된다 — 첫 픽스처의 오류.)
mk n_echo_wrong.sh '#!/usr/bin/env bash
echo "RELAY_UPSTREAM_SEEN: PASS"; exit 0'
B33=$(cap b33.cap "id: demo:b" "entry: bash $T/n_echo_wrong.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "echoes_upstream: yes" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A33" --cap "$B33" --task t --record "$T/rec33" > "$T/o33" 2>&1 || rc=$?
_tnot "L33 상류 이름이 정규식이어도 다른 값을 VERIFIED 로 받지 않는다" "upstream_consumption=VERIFIED" "$T/rec33/CHAIN.txt"

# ════════════════════════════════════════════════════════════════════════════
# L34–L38 — **수렴 라운드 3**. V1~V4 는 전부 VERIFIED-CLOSED 로 확인됐고, 신규 5건이
#           나왔다 — 전부 **enum 위생**이라는 한 가족이다. 라운드마다 결함 성격이 좁아지는
#           것이 수렴 벡터이지 건수만 보는 게 아니다.
# ════════════════════════════════════════════════════════════════════════════

# L34 한 줄 안의 중복 코드 — 키 중복은 막았지만 **원자** 중복은 last-wins 로 남아 있었다
A34=$(cap a34.cap "id: demo:a" "entry: bash $T/n_fail.sh" "verdict_channel: exit" \
  "verdict_enum: 0=PASS 1=FAIL 1=PASS" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A34" --cap "$B" --task t > "$T/o34" 2>&1 || rc=$?
_t "L34 한 선언 안의 중복 코드를 last-wins 로 삼키지 않는다" 4 "$rc"

# L35 `=` 없는 짝 — `1` 하나가 "코드 1 = 이름 1" 유령 원자로 통과했다
A35=$(cap a35.cap "id: demo:a" "entry: bash $T/n_fail.sh" "verdict_channel: exit" \
  "verdict_enum: 0=PASS 1" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A35" --cap "$B" --task t > "$T/o35" 2>&1 || rc=$?
_t "L35 code=NAME 형식이 아닌 항목을 유령 원자로 만들지 않는다" 4 "$rc"

# L36 ★ 126/127 세탁 — 존재하지 않는 entry 를 PASS 로 선언하는 경로
A36=$(cap a36.cap "id: demo:a" "entry: bash /nonexistent/path/nope.sh" "verdict_channel: exit" \
  "verdict_enum: 0=PASS 127=PASS 1=FAIL" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: fail-closed" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A36" --cap "$B" --task t > "$T/o36" 2>&1 || rc=$?
_t "L36 ★'안 돌았다'(126/127)를 verdict 로 선언할 수 없다" 4 "$rc"
# 런타임 방어도 별도로 — 합법 enum + 실행 불가 entry
A36b=$(cap a36b.cap "id: demo:a" "entry: bash /nonexistent/path/nope.sh" "verdict_channel: exit" \
  "verdict_enum: 0=PASS 1=FAIL" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: fail-closed" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A36b" --cap "$B" --task t > "$T/o36b" 2>&1 || rc=$?
_t "L36b 합법 enum 이어도 실행 불가는 HARNESS_ERROR 로 막힌다" 2 "$rc"

# L37 ★ blocking 집합이 비면 아무것도 막을 수 없다 — 부재는 허가가 아니다
A37=$(cap a37.cap "id: demo:a" "entry: bash $T/n_fail.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical")
B37=$(cap b37.cap "id: demo:b" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical")
rc=0; bash "$RELAY" run --cap "$A37" --cap "$B37" --task t > "$T/o37" 2>&1 || rc=$?
_t "L37 ★아무도 blocking 을 선언 안 한 조합은 돌지 않는다" 4 "$rc"
# 정말 advisory 전용이면 **명시 선언**으로 통과한다(과차단 아님 — 값을 지어내지 않을 뿐)
A37b=$(cap a37b.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: NONE")
rc=0; bash "$RELAY" run --cap "$A37b" --cap "$B37" --task t > "$T/o37b" 2>&1 || rc=$?
_t "L37b 'NONE' 을 명시하면 advisory 전용 조합도 돈다" 0 "$rc"
# ★ 판별자 — rc 만 보면 두 세계가 같다. **병합 집합이 실제로 비었는지**를 따로 재야
#   BSD/GNU sed 차이를 잡는다. 초판은 `s/\bNONE\b//g` 를 썼는데 BSD sed 는 `\b` 를
#   무시해 NONE 이 그대로 남았고, GNU 에서는 지워졌다 — **같은 코드 다른 상태**인데
#   최종 rc 가 우연히 같아 레인이 못 봤다(로컬 초록 ≠ CI 초록).
_tnot "L37c ★NONE 은 센티널이지 blocking 원자가 아니다(플랫폼 무관)" "FH_MERGED_verdict_binding: NONE" "$T/o37b"
_tout "L37d 병합 집합은 비어 있다" "FH_MERGED_verdict_binding: *$" "$T/o37b"

# L38 --record 재사용 — 이전 런의 산출물이 이번 런 증거로 남으면 안 된다
rm -rf "$T/rec38"; bash "$RELAY" run --cap "$A" --cap "$B" --task t --record "$T/rec38" >/dev/null 2>&1
bash "$RELAY" run --cap "$A2" --cap "$B2" --task t --record "$T/rec38" >/dev/null 2>&1
if [ -f "$T/rec38/node2.out" ]; then printf '❌ L38 이전 런의 node2.out 이 남아 이번 런 증거가 된다\n'; fail=$((fail+1))
else printf '✅ L38 기록 디렉터리는 런 단위 — 이전 런 산출물이 남지 않는다\n'; pass=$((pass+1)); fi

# ════════════════════════════════════════════════════════════════════════════
# N1–N12 — **뮤테이션 감사**(47 변이, 격리 실행)가 잡은 «장식 레인» 교체·보강.
#
#   그 감사가 물은 질문은 적대검증과 다르다: 적대검증은 "코드가 뚫리나", 뮤테이션은
#   **"이 레인이 진짜 그걸 잡나"** 다. 배선을 하나씩 지우고 어느 레인이 빨개지는지 실측한다.
#   결과: 15개 변이가 **0 적색** — 즉 그 배선들은 지워도 스위트가 만점을 유지했다.
#
#   근본 원인은 거의 다 하나다: **픽스처가 과결정(over-determined)** — 짝 capfile 이나
#   같은 선언 안의 다른 결함이 먼저 잡아버려, 정작 재려던 축이 결과에 영향을 못 준다.
#   판별자는 "차이를 만드는 유일한 것" 이어야 한다.
# ════════════════════════════════════════════════════════════════════════════

# N1 ★ L23 대체 — 짝이 FAIL 을 독립 선언하면 A 의 대괄호 파싱은 결과에 영향이 없다.
#    짝의 binding 을 ODD 로 바꿔 **A 의 파싱만이 차이를 만들게** 한다.
B_N1=$(cap b_n1.cap "id: demo:b" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: ODD")
rc=0; bash "$RELAY" run --cap "$A23" --cap "$B_N1" --task t > "$T/on1" 2>&1 || rc=$?
_t "N1 ★스펙 리스트 표기 파싱이 **단독으로** 차단을 만든다" 2 "$rc"

# N2 ★ L24 대체 — 픽스처에 글롭 문자를 실제로 넣고, 파일이 있는 cwd 에서 돌린다.
A_N2=$(cap a_n2.cap "id: demo:a" "entry: bash $T/n_odd.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: *")
mkdir -p "$T/globdir"; : > "$T/globdir/decoy1.txt"; : > "$T/globdir/decoy2.txt"
rc=0; ( cd "$T/globdir" && bash "$RELAY" merge --cap "$A_N2" --cap "$B" ) > "$T/on2" 2>&1 || rc=$?
_tnot "N2 ★선언값의 글롭 문자가 파일명으로 확장되지 않는다" "decoy1.txt" "$T/on2"
_tout "N2b 리터럴 '*' 가 집합에 그대로 있다" "FH_MERGED_verdict_binding: \* FAIL" "$T/on2"

# N3 `_cap_get` 리터럴 키 비교 앵커 — 들여쓴 키도 정확히 읽어야 한다(레인이 없었다)
A_N3=$(cap a_n3.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "  residency: company" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" merge --cap "$A_N3" --cap "$B" > "$T/on3" 2>&1 || rc=$?
_tout "N3 들여쓴 키도 리터럴로 읽어 strictest-wins 에 반영된다" "FH_MERGED_residency: company" "$T/on3"

# N4/N5 코드중복·이름중복을 **분리**해서 각각 앵커 (L34 는 둘이 겹쳐 어느 쪽도 못 잡았다)
A_N4=$(cap a_n4.cap "id: demo:a" "entry: bash $T/n_fail.sh" "verdict_channel: exit" \
  "verdict_enum: 0=PASS 1=FAIL 1=ODD" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A_N4" --cap "$B" --task t > "$T/on4" 2>&1 || rc=$?
_t "N4 코드 중복만 있어도 잡는다(이름은 안 겹침)" 4 "$rc"
A_N5=$(cap a_n5.cap "id: demo:a" "entry: bash $T/n_fail.sh" "verdict_channel: exit" \
  "verdict_enum: 0=PASS 1=PASS" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A_N5" --cap "$B" --task t > "$T/on5" 2>&1 || rc=$?
_t "N5 이름 중복만 있어도 잡는다(코드는 안 겹침)" 4 "$rc"

# N6 126/127 lint 를 **단독으로** 앵커 (L36 은 이름 중복 PASS 가 먼저 잡고 있었다)
A_N6=$(cap a_n6.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" \
  "verdict_enum: 0=PASS 127=NOTRUN 1=FAIL" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A_N6" --cap "$B" --task t > "$T/on6" 2>&1 || rc=$?
_t "N6 '안 돌았다' 구간 선언 금지가 단독으로 발동한다" 4 "$rc"

# N7 검사3 의 approval=forbidden 분기 — 어떤 capfile 도 이걸 선언한 적이 없었다
A_N7=$(cap a_n7.cap "id: demo:a" "entry: bash $T/n_pass.sh" "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: forbidden" "reversibility: reversible" "residency: public" "degrade: advisory" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A_N7" --cap "$B" --task t > "$T/on7" 2>&1 || rc=$?
_t    "N7 approval=forbidden 조합은 실행 대상이 아니다" 4 "$rc"
_tout "N7b 이유를 forbidden 으로 명시한다" "approval=forbidden" "$T/on7"

# N8 requires_cwd 부재 가드 — 레인 파일에 이 키가 0회 등장했다
A_N8=$(cap a_n8.cap "id: demo:a" "entry: bash $T/n_pass.sh" "requires_cwd: /nonexistent/dir/xyz" \
  "verdict_channel: exit" "verdict_enum: $ENUM" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: fail-closed" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A_N8" --cap "$B" --task t > "$T/on8" 2>&1 || rc=$?
_t "N8 requires_cwd 가 없으면 NOT_CALLABLE 로 막힌다(무음 통과 아님)" 2 "$rc"

# N9–N10 ★ 채널별 PASS arm — 없으면 "exit 외 채널을 전부 거부하는 게이트" 도 만점을 받는다
mk n_key_pass.sh '#!/usr/bin/env bash
echo "FH_GATE_VERDICT: PASS"; exit 0'
A_N9=$(cap a_n9.cap "id: demo:a" "entry: bash $T/n_key_pass.sh" "verdict_channel: stdout-key" \
  "verdict_stdout_key: FH_GATE_VERDICT" "verdict_enum: 0=PASS 1=FAIL" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: fail-closed" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A_N9" --cap "$B" --task t > "$T/on9" 2>&1 || rc=$?
_t "N9 stdout-key 채널의 정상 통과 경로가 실제로 돈다" 0 "$rc"
A_N10=$(cap a_n10.cap "id: demo:a" "entry: bash $T/n_key_pass.sh" "verdict_channel: both" \
  "verdict_stdout_key: FH_GATE_VERDICT" "verdict_enum: 0=PASS 1=FAIL" \
  "approval: auto" "reversibility: reversible" "residency: public" "degrade: fail-closed" \
  "tier_floor: none" "writes: read-only" "judge: mechanical" "verdict_binding: FAIL")
rc=0; bash "$RELAY" run --cap "$A_N10" --cap "$B" --task t > "$T/on10" 2>&1 || rc=$?
_t "N10 both 채널의 **일치** 정상 경로가 실제로 돈다(과차단 아님)" 0 "$rc"

printf '\n── relay_channel lanes: %d PASS / %d FAIL ──\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
