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

# 🟥 P6–P8 mtime 이식성 분기 — rc 로는 안 갈린다(두 분기 중 하나를 지워도 rc=0). 판별자는
#    출력의 `mtime=` 값이 UNKNOWN 으로 «접히는가»다. 이 머신은 BSD stat 이라 GNU 분기는 실물로
#    못 태운다 ⇒ PATH 앞에 «한 옵션만 받는 stat 흉내»를 두고 각 분기를 따로 태운다.
#    실측(2026-09-02, 스크래치 뮤턴트): GNU 분기 삭제 → GNU 흉내 밑에서 UNKNOWN ·
#    BSD 분기 삭제 → BSD 흉내 밑에서 UNKNOWN · 둘 다 있으면 둘 다 값. P8 은 「둘 다 거절」 컨트롤 —
#    UNKNOWN 이 «나올 수 있음»을 같은 실행에서 보인다(안 나오면 판별자가 죽은 것).
_TP="${TARGET_PIN_UNDER_TEST:-$R/target_pin.sh}"
mkdir -p "$T/shim_gnu" "$T/shim_bsd" "$T/shim_none"
# 🟥 cross-family(codex, 2026-09-02) A4·A5: 흉내가 «$1 만» 보고 레인이 «mtime= 뒤 아무 글자»를 받았다 —
#    `%y`→`%Q` 뮤턴트도, `warning mtime=garbage` 를 찍고 죽는 대상도 초록이었다. ⇒ 흉내는 argv 전체
#    (`-c %y <실재파일>` / `-f %Sm <실재파일>`)를 검사하고, 레인은 rc=0 ∧ **흉내가 낸 리터럴과 정확히 일치**를 요구한다.
_GNU_LIT="2026-01-01 00:00:00.000000000 +0000"; _BSD_LIT="Jan  1 00:00:00 2026"
printf '#!/usr/bin/env bash\n[ "$1" = "-c" ] && [ "$2" = "%%y" ] && [ -e "${3:-}" ] || exit 1\necho "%s"\n' "$_GNU_LIT" > "$T/shim_gnu/stat"
printf '#!/usr/bin/env bash\n[ "$1" = "-f" ] && [ "$2" = "%%Sm" ] && [ -e "${3:-}" ] || exit 1\necho "%s"\n' "$_BSD_LIT" > "$T/shim_bsd/stat"
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/shim_none/stat"
chmod +x "$T/shim_gnu/stat" "$T/shim_bsd/stat" "$T/shim_none/stat"
# _mt 는 «rc<TAB>mtime값» 한 줄을 낸다 — 명령 치환 안에서 변수를 못 올리니 값에 같이 실어 보낸다
_mt(){ local _o _rc; _o="$(PATH="$1:$PATH" bash "$_TP" "$T/pin.txt" "${H:0:12}" 2>&1)"; _rc=$?; printf '%s\t%s' "$_rc" "$(printf '%s' "$_o" | sed -n 's/.*mtime=//p')"; }
_r="$(_mt "$T/shim_gnu")";  _v="${_r#*	}"; [ "${_r%%	*}" = 0 ] && [ "$_v" = "$_GNU_LIT" ]; chk "P6 GNU stat(-c %y f 만) 밑에서 mtime 이 흉내 리터럴과 일치 ∧ rc 0 (GNU 분기 생존) [got=${_v:-∅}]" "$?" 0
_r="$(_mt "$T/shim_bsd")";  _v="${_r#*	}"; [ "${_r%%	*}" = 0 ] && [ "$_v" = "$_BSD_LIT" ]; chk "P7 BSD stat(-f %Sm f 만) 밑에서 mtime 이 흉내 리터럴과 일치 ∧ rc 0 (BSD 분기 생존) [got=${_v:-∅}]" "$?" 0
_r="$(_mt "$T/shim_none")"; _v="${_r#*	}"; [ "${_r%%	*}" = 0 ] && [ "$_v" = UNKNOWN ]; chk "P8 CONTROL stat 전부 거절 → UNKNOWN 으로 접힘이 «보인다» [got=${_v:-∅}]" "$?" 0

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
SRCF="${CCS_UNDER_TEST:-$ROOT/scripts/context_continuity_score.sh}"
if [ ! -f "$SRCF" ]; then
  # 🟥 cross-family(codex, 2026-09-02) B7: 종전엔 SKIP 만 찍고 rc 0 — 채점기(tracked)가 사라져도 스위트가
  #    초록이었다. 부재는 «잴 수 없음»이지 «통과»가 아니다 → 적색으로 센다.
  chk "E0 채점기 부재(scripts/context_continuity_score.sh) — E1–E5 를 잴 수 없다(통과 아님)" 1 0
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
  # 🟥 하중선: 파서가 죽으면 루프가 «0 행»을 받는다. 0 행 = 「전 문항 적격」이 아니다.
  #    실측(2026-09-02): 값에 `|` 하나 → PIPE_IN_VALUE 로 awk exit 3 → 프로세스 치환이라 rc 가 버려지고
  #    bad=0 → rc 0 «🟢 전 문항 적격». qset 파일 부재(awk rc 2)도 같은 얼굴. 둘 다 비-0 이어야 한다.
  _EL="${ELIGCHECK_UNDER_TEST:-$R/eligcheck_qset.sh}"
  printf 'ZZQQTOKEN 입니다.\n' > "$T/out/N01_CTRL_r1.txt"       # 답해버린 CTRL — 행이 채점됐다면 반드시 1
  printf 'N01\tnegative\tq|x?\tZZQQTOKEN\t\t\n' > "$T/eq_pipe.tsv"
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$_EL" "$T/eq_pipe.tsv" "$T/out" 1 ) >/dev/null 2>&1; _rc=$?
  [ "$_rc" -ne 0 ]; chk "E4 값에 '|' → 파서 exit 3 이 «0 행 통과»로 접히지 않는다 (rc≠0) [got=$_rc]" "$?" 0
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$_EL" "$T/eq_absent.tsv" "$T/out" 1 ) >/dev/null 2>&1; _rc=$?
  [ "$_rc" -ne 0 ]; chk "E5 qset 파일 부재 → rc≠0 (없음≠빈 qset≠전 문항 적격) [got=$_rc]" "$?" 0
  printf '# comment only\n' > "$T/eq_pos.tsv"       # 채점 대상 행 0 — «잰 것 없음» (positive 는 2026-09-02 부터 채점 대상이라 주석만 남긴다)
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$_EL" "$T/eq_pos.tsv" "$T/out" 1 ) >/dev/null 2>&1; _rc=$?
  [ "$_rc" -ne 0 ]; chk "E6 negative/conflict 행 0 → rc≠0 (빈 집합은 «전 문항 적격»이 아니다) [got=$_rc]" "$?" 0
  # ── E10–E11 labelmap 해석 + 채점기 --arms (2026-09-03, 회차4 이음매) ─────────────────────────
  mkdir -p "$T/lm"; printf 'N01\tnegative\tq?\tZZQQTOKEN\t\t\n' > "$T/eq_lm.tsv"
  printf 'wdeadbeef|N01|CTRL\nwcafe|N01|ARM\n' > "$T/lm.labelmap"      # 채점기 라벨맵 형식 그대로
  printf 'ZZQQTOKEN 입니다.\n' > "$T/lm/wdeadbeef_r1.txt"                # 익명 라벨 파일만 있고 옛 이름은 없다
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$_EL" "$T/eq_lm.tsv" "$T/lm" 1 ) >/dev/null 2>&1
  chk "E10 옛 이름 부재 + labelmap 있음 → 익명 라벨 CTRL 파일을 읽어 채점(답해버림=부적격 1)" "$?" 1
  rm -f "$T/lm.labelmap"
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$_EL" "$T/eq_lm.tsv" "$T/lm" 1 ) >/dev/null 2>&1; _rc=$?
  [ "$_rc" -ne 0 ]; chk "E10-ctrl labelmap 마저 없으면 부재 → 적격 아님(rc≠0, 분모 접힘 없음) [got=$_rc]" "$?" 0
  ( cd "$ROOT" && bash scripts/context_continuity_score.sh --arms BOGUS --self-test ) >/dev/null 2>&1; _rc=$?
  [ "$_rc" -eq 2 ]; chk "E11 채점기 --arms 닫힌 enum: BOGUS → rc 2 [got=$_rc]" "$?" 0
  # ── E12 --arms CTRL 은 «봉인 전» 실행 — --seal 없이 인자 검사를 지난다(다음 검사 = qset) ──────────
  _m=$( cd "$ROOT" && bash scripts/context_continuity_score.sh --arms CTRL --qset "$T/definitely_absent.tsv" --out "$T/o12" 2>&1 ); _rc=$?
  printf '%s' "$_m" | grep -q -- '--qset' && ! printf '%s' "$_m" | grep -q -- '--seal <실재 파일> 필요'; chk "E12 --arms CTRL + --seal 없음 → seal 이 아니라 qset 에서 멈춘다(봉인 전 실행 허용) [rc=$_rc]" "$?" 0
  _m=$( cd "$ROOT" && bash scripts/context_continuity_score.sh --arms both --qset "$T/definitely_absent.tsv" --out "$T/o12" 2>&1 ); _rc=$?
  printf '%s' "$_m" | grep -q -- '--seal <실재 파일> 필요'; chk "E12-ctrl --arms both 는 종전대로 --seal 필수 [rc=$_rc]" "$?" 0
  # ── E7–E9 positive 적격 분기 (2026-09-02) — CTRL 이 토큰을 «내면» DEAD_CONTROL ──────────────
  printf 'P01\tpositive\tq?\tZZQQPOS\t\t\n' > "$T/eq_p.tsv"
  printf '그런 값은 기록에 없습니다.\n' > "$T/out/P01_CTRL_r1.txt"
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$_EL" "$T/eq_p.tsv" "$T/out" 1 ) >/dev/null 2>&1
  chk "E7 CONTROL positive: CTRL 이 토큰을 안 냄 → 적격(0)" "$?" 0
  printf '값은 ZZQQPOS 입니다.\n' > "$T/out/P01_CTRL_r1.txt"
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$_EL" "$T/eq_p.tsv" "$T/out" 1 ) >/dev/null 2>&1
  chk "E8 positive: CTRL 이 토큰을 냄 → DEAD_CONTROL 부적격(1)" "$?" 1
  printf '그런 값은 기록에 없습니다.\n' > "$T/out/P01_CTRL_r1.txt"; rm -f "$T/out/P01_CTRL_r2.txt"
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$_EL" "$T/eq_p.tsv" "$T/out" 2 ) >/dev/null 2>&1
  chk "E9 positive: reps=2 인데 응답 1건 부재 → UNMEASURED 부적격(1)" "$?" 1
  printf '<<VERDICT:ANSWERED>> ZZQQPOS\n' > "$T/out/P01_CTRL_r1.txt"   # typed 형 — TYPED_PASS 도 «토큰이 나왔다»
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$_EL" "$T/eq_p.tsv" "$T/out" 1 ) >/dev/null 2>&1
  chk "E8b positive: typed 마커 + 토큰(TYPED_PASS) → DEAD_CONTROL(1)" "$?" 1
  printf '기록에 없습니다. ZZQQPOS 은 기록에 없습니다.\n' > "$T/out/P01_CTRL_r1.txt"   # 거절+토큰 — REFUSED_WITH_TOKEN 도 토큰 유출
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$_EL" "$T/eq_p.tsv" "$T/out" 1 ) >/dev/null 2>&1
  chk "E8c positive: 거절+토큰(REFUSED_WITH_TOKEN) → DEAD_CONTROL(1)" "$?" 1
  printf 'P01\tpositive\tq?\t\t\t\n' > "$T/eq_p_notok.tsv"; printf '아무 말\n' > "$T/out/P01_CTRL_r1.txt"
  ( cd "$ROOT" && SRC=scripts/context_continuity_score.sh bash "$_EL" "$T/eq_p_notok.tsv" "$T/out" 1 ) >/dev/null 2>&1
  chk "E8d positive: 기대 토큰 빈 칸 → UNMEASURED(1), «전부 DEAD_CONTROL» 아님" "$?" 1
fi

# ───────────────────────── gatecheck_qset ─────────────────────────
# 🟥 하중선: 파서가 죽으면 루프가 «0 행»을 받고 bad=0·unchecked=0 → 「🟢 개시 게이트 선통과」 rc 0.
#    실측(2026-09-02, 원본): 값에 `|` · 빈 qset · 헤더뿐 · 파일 부재 → 넷 다 rc 0. 넷 다 비-0 이어야 한다.
#    seal 이름은 실물 규약 형태여야 nameleak 이 먼저 막지 않는다(L25 와 같은 이유).
_GK="${GATECHECK_UNDER_TEST:-$R/gatecheck_qset.sh}"
_GTOK="zzG$$$(date +%s)"
printf 'P01\tpositive\tq?\t%s\t\t\n' "$_GTOK" > "$T/g_ok.tsv"
printf 'P01\tpositive\tq|x?\t%s\t\t\n' "$_GTOK" > "$T/g_pipe.tsv"
: > "$T/g_empty.tsv"; printf '# header only\n' > "$T/g_hdr.tsv"
_GSEAL="$T/seal_deadbeef-abc_20260901-101010.md"; printf 'seal %s\n' "$_GTOK" > "$_GSEAL"
( cd "$ROOT" && bash "$_GK" "$T/g_ok.tsv" "$_GSEAL" post ) >/dev/null 2>&1
chk "G1 CONTROL 정상 1행 + seal → 선통과(0)" "$?" 0
( cd "$ROOT" && bash "$_GK" "$T/g_pipe.tsv" "$_GSEAL" post ) >/dev/null 2>&1; _rc=$?
[ "$_rc" -ne 0 ]; chk "G2 값에 '|' → 파서 exit 3 이 «0 행 선통과»로 접히지 않는다 (rc≠0) [got=$_rc]" "$?" 0
( cd "$ROOT" && bash "$_GK" "$T/g_empty.tsv" "$_GSEAL" post ) >/dev/null 2>&1; _rc=$?
[ "$_rc" -ne 0 ]; chk "G3 빈 qset → rc≠0 (빈 집합은 «선통과»가 아니다) [got=$_rc]" "$?" 0
( cd "$ROOT" && bash "$_GK" "$T/g_hdr.tsv" "$_GSEAL" post ) >/dev/null 2>&1; _rc=$?
[ "$_rc" -ne 0 ]; chk "G4 헤더뿐 qset → rc≠0 [got=$_rc]" "$?" 0
( cd "$ROOT" && bash "$_GK" "$T/g_absent.tsv" "$_GSEAL" post ) >/dev/null 2>&1; _rc=$?
[ "$_rc" -ne 0 ]; chk "G5 qset 파일 부재 → rc≠0 (없음≠빈 qset≠선통과) [got=$_rc]" "$?" 0

echo "round-instrument lanes: $P passed, $F failed"
[ "$F" -eq 0 ]
