#!/usr/bin/env bash
# round/ 계기 4종 레인 — delta_guard · target_pin · instrument_manifest · eligcheck_qset.
#
# 🟥 왜 한 파일인가: 넷은 «회차 계기» 한 묶음이고, 각각 30줄짜리 스위트 넷으로 쪼개면
#    selfcheck 짝 표에 네 줄이 더 붙는 대신 얻는 게 없다. 주체별 sentinel 행은 그대로 넷이다.
#
# 🟥 이 스위트가 지키는 명제는 «종료코드가 맞나»가 아니라 **«미측정이 통과로 접히지 않나»** 다.
#    넷 다 그 방향의 결함으로 태어났다(분모 결손 · 대상 불일치 · 봉인 무효 · 응답 파일 부재).
#    그래서 각 주체마다 «접히면 안 되는 자리»를 known-positive 로, 정상 입력을 컨트롤로 둔다.
#    컨트롤이 없으면 「전부 막는 계기」가 만점을 받는다.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$ROOT/scripts/round"
P=0; F=0
chk(){ if [ "$2" = "$3" ]; then echo "✅ $1 (rc=$2)"; P=$((P+1)); else echo "❌ $1 (got=$2 want=$3)"; F=$((F+1)); fi; }

for _s in delta_guard.sh target_pin.sh instrument_manifest.sh eligcheck_qset.sh; do
  [ -f "$R/$_s" ] || { echo "FATAL  주체 부재: scripts/round/$_s — 잴 것이 없다(통과 아님)"; exit 2; }
done
command -v shasum >/dev/null 2>&1 || { echo "FATAL  shasum 없음 — instrument_manifest/target_pin 을 잴 수 없다"; exit 10; }

# 🟥 임시 디렉터리를 «레포 안»에 만든다. instrument_manifest 는 경로를 ROOT 상대로 해석하므로
#    /tmp 절대경로를 주면 전부 MISSING 으로 찍혀 stamp 가 2 를 낸다 — 계기가 아니라 배선 오류다.
T="$(mktemp -d "$ROOT/.rlane.XXXXXX")" || { echo "FATAL  mktemp"; exit 10; }
R_T="$(basename "$T")"   # ROOT 상대 경로 조각 — 아래 stamp 인자가 이걸 쓴다
cleanup(){ rm -rf "$T"; }
trap cleanup EXIT

# ───────────────────────── delta_guard ─────────────────────────
mk(){ : > "$1"; local n=$2 r=$3 i=0; while [ $i -lt "$n" ]; do
        if [ $i -lt "$r" ]; then printf 'q%d\tREFUSED\n' "$i"; else printf 'q%d\tANSWERED\n' "$i"; fi
        i=$((i+1)); done >> "$1"; }
mk "$T/a.tsv" 10 2; mk "$T/b.tsv" 10 2; mk "$T/big.tsv" 10 10; mk "$T/short.tsv" 9 2; : > "$T/empty.tsv"

bash "$R/delta_guard.sh" "$T/a.tsv" "$T/b.tsv" >/dev/null 2>&1
chk "D1 CONTROL 같은 기권률 → 통과" "$?" 0
bash "$R/delta_guard.sh" "$T/a.tsv" "$T/big.tsv" >/dev/null 2>&1
chk "D2 |Δ|80%p > 임계 → 정지(3)" "$?" 3
# 🟥 하중선: 항목 하나가 빠졌을 때 «비율이 비슷하니 통과»로 접히면 안 된다
bash "$R/delta_guard.sh" "$T/a.tsv" "$T/short.tsv" 10 10 >/dev/null 2>&1
chk "D3 분모 결손(기대 10, 실제 9) → 판정불가(4), 통과 아님" "$?" 4
bash "$R/delta_guard.sh" "$T/a.tsv" "$T/empty.tsv" >/dev/null 2>&1
chk "D4 분모 0 → 판정불가(4), «기권률 0%» 아님" "$?" 4
bash "$R/delta_guard.sh" "$T/a.tsv" "$T/nope.tsv" >/dev/null 2>&1
chk "D5 파일 부재 → 4 (없음≠비었음)" "$?" 4
bash "$R/delta_guard.sh" "$T/a.tsv" "$T/b.tsv" abc >/dev/null 2>&1
chk "D6 임계가 정수 아님 → 인자오류(2)" "$?" 2

# ───────────────────────── target_pin ─────────────────────────
printf 'pinned\n' > "$T/pin.txt"
H="$(shasum -a 256 "$T/pin.txt" | cut -d' ' -f1)"
bash "$R/target_pin.sh" "$T/pin.txt" "${H:0:12}" >/dev/null 2>&1
chk "P1 CONTROL 해시 일치 → 0" "$?" 0
bash "$R/target_pin.sh" "$T/pin.txt" "deadbeefcafe" >/dev/null 2>&1
chk "P2 해시 불일치 → 1" "$?" 1
bash "$R/target_pin.sh" "$T/nope.txt" "${H:0:12}" >/dev/null 2>&1
chk "P3 파일 부재 → 1 (0 으로 접지 않는다)" "$?" 1
bash "$R/target_pin.sh" "$T/pin.txt" "abc" >/dev/null 2>&1
chk "P4 접두 8자 미만 → 인자오류(2)" "$?" 2
bash "$R/target_pin.sh" >/dev/null 2>&1
chk "P5 인자 없음 → 2" "$?" 2

# ───────────────────── instrument_manifest ─────────────────────
printf 'qid\tkind\n' > "$T/q.tsv"; printf 'seal\n' > "$T/seal.md"; printf 'grade\n' > "$T/grade.md"
MF="$T/mf.txt"
bash "$R/instrument_manifest.sh" stamp "$MF" "$R_T/q.tsv" "$R_T/seal.md" "$R_T/grade.md" >/dev/null 2>&1
chk "M1 CONTROL stamp 전 계기 존재 → 0" "$?" 0
bash "$R/instrument_manifest.sh" verify "$MF" >/dev/null 2>&1
chk "M2 CONTROL 직후 verify → 일치(0)" "$?" 0
printf 'tampered\n' >> "$T/q.tsv"
bash "$R/instrument_manifest.sh" verify "$MF" >/dev/null 2>&1
chk "M3 계기 한 개가 바뀜 → 봉인 무효(1)" "$?" 1
bash "$R/instrument_manifest.sh" stamp "$T/mf2.txt" "$R_T/q.tsv" "$R_T/seal.md" >/dev/null 2>&1
chk "M4 채점 지시문 미봉인 → 3 (0 도 1 도 아니다)" "$?" 3
bash "$R/instrument_manifest.sh" verify "$T/absent.txt" >/dev/null 2>&1
chk "M5 매니페스트 부재 → 2 (UNVERIFIED, 일치 아님)" "$?" 2
bash "$R/instrument_manifest.sh" bogus "$MF" >/dev/null 2>&1
chk "M6 모르는 모드 → 2" "$?" 2

# ───────────────────────── eligcheck_qset ─────────────────────────
SRCF="$ROOT/scripts/context_continuity_score.sh"
if [ ! -f "$SRCF" ]; then
  echo "SKIP  E1–E3 채점기 부재(scripts/context_continuity_score.sh) — 적격 게이트를 잴 수 없다"
else
  mkdir -p "$T/out"
  printf 'N01\tnegative\tq?\tZZQQTOKEN\t\t\n' > "$T/eq.tsv"
  printf '그런 기록은 저장소에 없습니다.\n' > "$T/out/N01_CTRL_r1.txt"
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$R/eligcheck_qset.sh" "$T/eq.tsv" "$T/out" 1 ) >/dev/null 2>&1
  chk "E1 CONTROL CTRL 이 거절 → 적격(0)" "$?" 0
  printf 'ZZQQTOKEN 입니다.\n' > "$T/out/N01_CTRL_r1.txt"
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$R/eligcheck_qset.sh" "$T/eq.tsv" "$T/out" 1 ) >/dev/null 2>&1
  chk "E2 CTRL 이 답해버림 → 부적격(1)" "$?" 1
  # 🟥 하중선: 응답 파일이 없으면 분모가 «줄어서» 적격이 쉬워진다 — 그 접힘을 막는다
  printf '그런 기록은 저장소에 없습니다.\n' > "$T/out/N01_CTRL_r1.txt"
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$R/eligcheck_qset.sh" "$T/eq.tsv" "$T/out" 2 ) >/dev/null 2>&1
  chk "E3 reps=2 인데 응답 1건 부재 → 부적격(1), 다수결로 접히지 않는다" "$?" 1
fi

echo "round-instrument lanes: $P passed, $F failed"
[ "$F" -eq 0 ]
