#!/usr/bin/env bash
# test_target_freeze_lanes.sh — known pairs for scripts/target_freeze.sh
#
# 🟥 이 레인이 실제로 재는 것: 「대상이 움직였음을 **가르는가**」. 양성만 재면 «항상 다르다고
#    하는 계기» 와 구분되지 않고, 그 계기는 매 라운드 판정을 무효화해 아무도 안 쓰게 된다
#    (= 선행 실패 ①의 배경-소음 경로). 그래서 **복원 후 MATCH** 레인이 이 파일의 핵심이다.
#
# 🟥 그리고 이 스크립트가 존재하는 이유인 **선행 실패 2종**을 각각 한 레인으로 고정한다:
#    A  줄 수가 같은 in-place 편집  — `base-SHA + diff 줄 수` 지문이 못 잡던 것
#    B  untracked 파일 추가         — 같은 지문이 구조적으로 맹목이던 것
#    이 둘이 빠지면 3번째 시도도 같은 자리에서 무너진다.

set -u
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/target_freeze.sh"
pass=0; fail=0
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
R="$WORK/repo"

# run <label> <expect MATCH|WRONG|UNKNOWN> <cmd...>
run() {
  local label="$1" want="$2"; shift 2
  local out rc got
  out=$("$@" 2>&1); rc=$?
  case "$rc" in
    0)  got=MATCH ;;
    1)  got=WRONG ;;
    10) got=UNKNOWN ;;
    *)  got="rc$rc" ;;
  esac
  if [ "$got" = "$want" ]; then
    printf '  ✅ %-52s %s (expected %s)\n' "$label" "$got" "$want"; pass=$((pass+1))
  else
    printf '  ❌ %-52s %s (expected %s)\n     out: %s\n' "$label" "$got" "$want" "$out"; fail=$((fail+1))
  fi
}

echo "[target-freeze] fixture build"
mkdir -p "$R" && git init -q "$R"
git -C "$R" config user.email t@t; git -C "$R" config user.name t
printf 'a\n' >"$R/a.txt"
git -C "$R" add -A && git -C "$R" commit -qm init

echo "[target-freeze] lanes"
run "pin (최초)"                        MATCH   bash "$T" pin "$R" demo

# ── A. 선행 실패 ②-1: 줄 수 불변 in-place 편집 ─────────────────────────────
printf 'b\n' >"$R/a.txt"
run "A 줄 수 같은 in-place 편집 → WRONG"  WRONG   bash "$T" verify "$R" demo
printf 'a\n' >"$R/a.txt"

# ── C. 판별력 컨트롤 — 되돌리면 다시 MATCH («항상 다르다» 계기가 아님) ────────
run "C 복원 후 → MATCH (판별력 컨트롤)"   MATCH   bash "$T" verify "$R" demo

# ── B. 선행 실패 ②-2: untracked 추가 ────────────────────────────────────────
printf 'new\n' >"$R/untracked.txt"
run "B untracked 추가 → WRONG"          WRONG   bash "$T" verify "$R" demo
rm -f "$R/untracked.txt"
run "B 제거 후 → MATCH"                 MATCH   bash "$T" verify "$R" demo

# ── gitignore 된 파일은 대상이 아니다 (오탐 경로 — 산출물 디렉토리가 매 런 바뀐다) ──
printf 'out/\n' >"$R/.gitignore"
git -C "$R" add .gitignore && git -C "$R" commit -qm ignore
run "pin (ignore 커밋 후 재핀)"          MATCH   bash "$T" pin "$R" demo
mkdir -p "$R/out" && printf 'noise\n' >"$R/out/run.log"
run "ignored 산출물 생성 → MATCH (오탐 없음)" MATCH bash "$T" verify "$R" demo

# ── ⓑ 은폐 비트: 잴 수 없으면 «일치» 를 낼 자격이 없다 ──────────────────────
git -C "$R" update-index --assume-unchanged a.txt
printf 'HIDDEN\n' >"$R/a.txt"
run "assume-unchanged → UNKNOWN (통과 아님)" UNKNOWN bash "$T" verify "$R" demo
git -C "$R" update-index --no-assume-unchanged a.txt
printf 'a\n' >"$R/a.txt"

# ── ⓒ 미측정을 통과로 접지 않는다 ───────────────────────────────────────────
run "핀 없는 라벨 → UNKNOWN"             UNKNOWN bash "$T" verify "$R" nolabel
run "git 레포 아님 → UNKNOWN"            UNKNOWN bash "$T" verify "$WORK" demo

# ── 스테이징만 해도 대상은 움직인 것이다 ────────────────────────────────────
printf 'staged\n' >"$R/a.txt"; git -C "$R" add a.txt
run "staged 변경 → WRONG"                WRONG   bash "$T" verify "$R" demo

# ══════════════════════════════════════════════════════════════════════════════
# cross-family(codex, 2026-08-18)가 **뚫은** 경로들 — 전부 재현 확인 후 여기 고정한다.
# 🟥 위 11 레인이 초록인 채로 아래가 전부 통과했다: 컨트롤이 있다는 것과 판별력이 있다는
#    것은 다르다. 이 블록이 없으면 다음 수리가 같은 자리를 조용히 다시 연다.
# ══════════════════════════════════════════════════════════════════════════════
echo
echo "[target-freeze] cross-family 가 뚫은 경로 (fail-open 3 · 오탐 1)"

# ── S: 라벨 별칭 — `a/b` 와 `a_b` 가 같은 핀 파일이면 «핀한 적 없는 라벨» 이 MATCH ──
bash "$T" pin "$R" a_b >/dev/null 2>&1
run "S 라벨 별칭 a/b (핀 없음) → UNKNOWN"  UNKNOWN bash "$T" verify "$R" a/b

# ── S: `ls-files -o` 실패가 파이프에 먹혀 «untracked 없음» 으로 접히던 것 ──────────
FAKEBIN="$WORK/fakebin"; mkdir -p "$FAKEBIN"
REALGIT=$(command -v git)
printf '#!/usr/bin/env bash
if [ "$1" = "-C" ] && [ "$3" = "ls-files" ] && [ "$4" = "-o" ]; then exit 42; fi
exec %q "$@"
' "$REALGIT" >"$FAKEBIN/git"
chmod +x "$FAKEBIN/git"
bash "$T" pin "$R" lsfail >/dev/null
printf 'new
' >"$R/u2.txt"
run "S ls-files -o 고장 → UNKNOWN (MATCH 아님)" UNKNOWN env PATH="$FAKEBIN:$PATH" bash "$T" verify "$R" lsfail
rm -f "$R/u2.txt"

# ── S: untracked 중첩 git repo — 안의 내용 변경을 못 보므로 **fail-closed** ────────
mkdir -p "$R/nested" && git init -q "$R/nested"
git -C "$R/nested" config user.email t@t; git -C "$R/nested" config user.name t
printf 'one
' >"$R/nested/x.txt"
run "S untracked 디렉토리 → UNKNOWN (못 잰다고 말한다)" UNKNOWN bash "$T" pin "$R" nested
rm -rf "$R/nested"

# ── A: 깨진 심볼릭 링크 재지정 — 링크가 가리키는 문자열이 내용이다 ─────────────────
ln -s missing-one "$R/link"
run "A 심볼릭 링크 pin"                     MATCH   bash "$T" pin "$R" symlink
ln -sfn missing-two "$R/link"
run "A 링크 재지정 → WRONG"                 WRONG   bash "$T" verify "$R" symlink
ln -sfn missing-one "$R/link"
run "A 링크 복원 → MATCH (판별력 컨트롤)"    MATCH   bash "$T" verify "$R" symlink
rm -f "$R/link"

# ── S: 서브모듈 **워킹트리** 내용 변경 (커밋 없이) ────────────────────────────────
#    🟥 `submodule status` 만으로는 못 잡는다 — 그 줄은 서브모듈의 HEAD 를 말하므로,
#    커밋 없이 파일만 고치면 SHA 가 그대로다. 수리 1차본이 정확히 여기서 뚫렸다.
SUB="$WORK/sub"; mkdir -p "$SUB" && git init -q "$SUB"
git -C "$SUB" config user.email t@t; git -C "$SUB" config user.name t
printf 'v1\n' >"$SUB/s.txt"; git -C "$SUB" add -A; git -C "$SUB" commit -qm sub
SR="$WORK/subhost"; mkdir -p "$SR" && git init -q "$SR"
git -C "$SR" config user.email t@t; git -C "$SR" config user.name t
printf 'a\n' >"$SR/a.txt"; git -C "$SR" add -A; git -C "$SR" commit -qm init
if git -C "$SR" -c protocol.file.allow=always submodule add -q "$SUB" sub 2>/dev/null; then
  git -C "$SR" commit -qm addsub
  printf 'v2\n' >"$SR/sub/s.txt"
  run "S 서브모듈 pin"                        MATCH   bash "$T" pin "$SR" sm
  printf 'v3\n' >"$SR/sub/s.txt"
  run "S 서브모듈 워킹트리 변경 → WRONG"       WRONG   bash "$T" verify "$SR" sm
  printf 'v2\n' >"$SR/sub/s.txt"
  run "S 서브모듈 복원 → MATCH (판별력 컨트롤)" MATCH   bash "$T" verify "$SR" sm
else
  printf '  ⚠️  서브모듈 레인 skip — 이 git 이 file:// 서브모듈을 거부한다(미측정, 통과 아님)\n'
fi

# ── A: 오탐 — 빈 커밋은 **내용을 안 바꾼다**. 트리 해시를 쓰므로 MATCH 여야 한다 ────
# ★앞 레인이 스테이징을 남겨 뒀다. 그대로 `--allow-empty` 하면 **그 스테이징이 커밋되어**
#   트리가 실제로 바뀐다 — 초판에서 이 레인이 빨갰던 이유는 스크립트가 아니라 픽스처였다.
git -C "$R" reset -q --hard HEAD
bash "$T" pin "$R" emptycommit >/dev/null
git -C "$R" commit --allow-empty -qm noop
run "A 빈 커밋(같은 tree) → MATCH (오탐 아님)" MATCH  bash "$T" verify "$R" emptycommit

# ══════════════════════════════════════════════════════════════════════════════
# 2번째 계열(agy, 2026-08-18)이 **다른 축**에서 뚫은 것 — codex 지적 목록을 주고 «그 밖»을
# 요구했다. 계열을 나눈 것이 값을 냈다(같은 계열 둘이면 같은 사각이 남는다).
# ══════════════════════════════════════════════════════════════════════════════
echo
echo "[target-freeze] 2번째 계열이 뚫은 축"

# ── S: `GIT_DIR` 이 `git -C` 를 이긴다 — 엉뚱한 레포를 재고 «동결했다» 고 보고하던 것 ──
OTHER="$WORK/other"; mkdir -p "$OTHER" && git init -q "$OTHER"
git -C "$OTHER" config user.email t@t; git -C "$OTHER" config user.name t
printf 'other\n' >"$OTHER/o.txt"; git -C "$OTHER" add -A; git -C "$OTHER" commit -qm other
git -C "$R" reset -q --hard HEAD
bash "$T" pin "$R" gitdir >/dev/null
printf 'moved\n' >"$R/a.txt"
# 환경변수가 살아 있으면 $R 이 아니라 $OTHER 를 재서 «변화 없음»(MATCH)이 나왔다.
run "S GIT_DIR 오염 상태에서도 대상은 R → WRONG" WRONG \
    env GIT_DIR="$OTHER/.git" GIT_WORK_TREE="$OTHER" bash "$T" verify "$R" gitdir
git -C "$R" checkout -q -- a.txt
run "S 오염 제거 후 복원 → MATCH (판별력 컨트롤)" MATCH bash "$T" verify "$R" gitdir

# ── S: `_sha` 가 `| awk` 로 rc 를 잃던 것 — 해시 실패가 «빈 지문» 으로 접히면 MATCH ──────
#    🟥 이 레인은 **되돌림 프로브가 만들었다**: `_sha` 의 rc 검사를 되돌렸는데 26 레인이
#    전부 초록이었다 = 그 수리를 덮는 앵커가 하나도 없었다(장식 앵커). 계기가 스스로를
#    못 재는 자리를 되돌림이 짚어낸 것이다.
SHABIN="$WORK/shabin"; mkdir -p "$SHABIN"
REALSHA=$(command -v shasum || true)
if [ -n "$REALSHA" ]; then
  printf '#!/usr/bin/env bash\ninput=$(cat)\ncase "$input" in boom*) exit 7 ;; esac\nprintf %%s "$input" | %q "$@"\n' "$REALSHA" >"$SHABIN/shasum"
  chmod +x "$SHABIN/shasum"
  git -C "$R" reset -q --hard HEAD
  printf 'boom1\n' >"$R/u4.txt"
  run "S 해시 도구 실패 → UNKNOWN (pin)"      UNKNOWN env PATH="$SHABIN:$PATH" bash "$T" pin "$R" shafail
  rm -f "$R/u4.txt"
  run "S 정상 도구로는 pin 됨 (판별력 컨트롤)" MATCH   bash "$T" pin "$R" shafail
else
  printf '  ⚠️  _sha 레인 skip — shasum 부재(미측정, 통과 아님)\n'
fi

# ── B: untracked 파일의 실행 비트 — 이 레포가 이미 데인 축 ────────────────────────
printf '#!/bin/sh\necho hi\n' >"$R/u3.sh"; chmod 644 "$R/u3.sh"
run "B 실행비트 pin"                        MATCH   bash "$T" pin "$R" execbit
chmod +x "$R/u3.sh"
run "B chmod +x → WRONG (내용은 그대로다)"   WRONG   bash "$T" verify "$R" execbit
chmod 644 "$R/u3.sh"
run "B 비트 복원 → MATCH (판별력 컨트롤)"    MATCH   bash "$T" verify "$R" execbit
rm -f "$R/u3.sh"

printf '\n[target-freeze] pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
