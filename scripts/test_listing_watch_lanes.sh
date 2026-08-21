#!/usr/bin/env bash
# test_listing_watch_lanes.sh — listing_watch.sh 의 레인.
# 🟥 네트워크를 안 쓴다: PATH 앞에 `gh` 스텁을 놓아 응답을 고정한다.
#    (실망 사용 검증은 `--selftest` 가 known-pair 로 따로 한다 — 그건 네트워크가 필요하다)
HUB="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
SUT="$HUB/scripts/listing_watch.sh"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
ng(){ FAIL=$((FAIL+1)); printf '  ❌ %s\n     기대: %s\n     실제: %s\n' "$1" "$2" "$3"; }

SB=$(mktemp -d); trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/tracks/_meta" "$SB/bin"

mkstub(){ # $1 = state|merged|badexit
  cat > "$SB/bin/gh" <<STUB
#!/usr/bin/env bash
case "\$*" in
  *"contents/README.md"*) printf '%s' "\$(printf 'chrono-meta/forge-harness' | base64)" ;;
  # 🟥 본체 jq 는 4필드다: state|merged|라벨개수|라벨목록. 스텁이 3필드면 계기가 대상과 어긋난다.
  *"issues/33"*)   [ "$1" = "merged" ] && printf 'open|2026-08-19T06:48:10Z|0|' || printf 'open|null|1|validation-passed' ;;
  *"issues/999"*)  exit 1 ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$SB/bin/gh"
}

run(){ CLAUDE_PROJECT_DIR="$SB" PATH="$SB/bin:$PATH" bash "$SUT" "$@" 2>&1; }

# ── L1: gh 부재 → SKIPPED (pass 아님) ─────────────────────────────
printf 'walkinglabs/x\t33\tpr\tchrono-meta/forge-harness\n' > "$SB/tracks/_meta/listing_watch_channels.tsv"
# 🟥 두 번 틀린 자리다. ① 초판: `PATH=/nonexistent` 가 `bash` 까지 지워 «계기» 를 시험했다.
#    ② 2판: `/bin:/usr/bin` 은 **호스트 의존**이다 — 리눅스에선 거기 진짜 gh 가 있을 수 있고
#    그러면 이 레인이 «대상» 이 아니라 «그 머신» 을 재게 된다(cross-family 지목).
#    ③ 정본: 본체에 주입 seam(`LISTING_WATCH_GH`)을 두고 존재하지 않는 이름을 넣는다.
o=$(CLAUDE_PROJECT_DIR="$SB" LISTING_WATCH_GH="gh-does-not-exist-$$" bash "$SUT" --force 2>&1); r=$?
case "$o" in *SKIPPED*) ok "L1 gh 부재 → SKIPPED (not passed)" ;; *) ng "L1" "SKIPPED" "$o" ;; esac
[ "$r" = "0" ] && ok "L1b gh 부재여도 exit 0 (훅 무음 방지)" || ng "L1b" "0" "$r"

# ── L2: 매니페스트 부재 → DISABLED (실패 아님) ────────────────────
mkstub state
mv "$SB/tracks/_meta/listing_watch_channels.tsv" "$SB/m.bak"
o=$(run --force); case "$o" in *DISABLED*) ok "L2 매니페스트 부재 → DISABLED" ;; *) ng "L2" "DISABLED" "$o" ;; esac
mv "$SB/m.bak" "$SB/tracks/_meta/listing_watch_channels.tsv"

# ── L3: 주석만 있는 매니페스트 → DISABLED (0행을 «정상»으로 안 읽는다) ──
cp "$SB/tracks/_meta/listing_watch_channels.tsv" "$SB/m.bak"
printf '# only a comment\n' > "$SB/tracks/_meta/listing_watch_channels.tsv"
o=$(run --force); case "$o" in *DISABLED*) ok "L3 유효행 0 → DISABLED" ;; *) ng "L3" "DISABLED" "$o" ;; esac
cp "$SB/m.bak" "$SB/tracks/_meta/listing_watch_channels.tsv"

# ── L4: 최초 실행 → 스냅샷 생성 + 변화 «없음» ─────────────────────
rm -f "$SB/tracks/_meta/.listing_watch_state.tsv"
o=$(run --force)
case "$o" in *최초*) ok "L4 최초 실행을 «변화» 로 오보하지 않는다" ;; *) ng "L4" "최초 실행 안내" "$o" ;; esac
[ -s "$SB/tracks/_meta/.listing_watch_state.tsv" ] && ok "L4b 스냅샷 파일 생성" || ng "L4b" "비어있지 않은 스냅샷" "(없음)"

# ── L5: 무변화 → 무출력 (오탐 0) ──────────────────────────────────
o=$(run --force)
[ -z "$o" ] && ok "L5 무변화 → 무출력" || ng "L5" "(빈 출력)" "$o"

# ── L6: 상태 전이 → 검출 ★ 이 레인이 본체다 ──────────────────────
mkstub merged
o=$(run --force)
# 🟥 배너 문구만 보면 «라벨만 바뀐 버그» 도 통과한다 — **관측된 전이 자체**를 단언한다.
case "$o" in *"바뀌었다"*) ok "L6 변화 배너 발화" ;; *) ng "L6" "변화 보고" "$o" ;; esac
case "$o" in *MERGED*) ok "L6b 전이 «내용»이 MERGED 로 찍힌다" ;; *) ng "L6b" "지금: … MERGED" "$o" ;; esac
case "$o" in *"이전:"*) ok "L6c 이전 상태도 같이 보여준다" ;; *) ng "L6c" "이전: …" "$o" ;; esac

# ── L7: 스로틀 — 24h 안이면 조용 ──────────────────────────────────
o=$(run)   # --force 없음
[ -z "$o" ] && ok "L7 스로틀 동작 (24h 내 재실행 조용)" || ng "L7" "(빈 출력)" "$o"

# ── L8: API 실패를 «없음» 이 아니라 FAILED 로 ─────────────────────
printf 'walkinglabs/x\t999\tpr\t-\n' > "$SB/tracks/_meta/listing_watch_channels.tsv"
rm -f "$SB/tracks/_meta/.listing_watch_state.tsv"
run --force >/dev/null
s=$(cat "$SB/tracks/_meta/.listing_watch_state.tsv" 2>/dev/null)
case "$s" in *FAILED*) ok "L8 API 실패 → FAILED (0 으로 안 접는다)" ;; *) ng "L8" "FAILED" "$s" ;; esac

# ── L9: 🟥 FAILED 반복이 «무출력» 이 되면 안 된다 (자기 헤더 배반 방지) ──
cat > "$SB/bin/gh" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$SB/bin/gh"
printf 'r/x\t1\tpr\t-\n' > "$SB/tracks/_meta/listing_watch_channels.tsv"
rm -f "$SB/tracks/_meta/.listing_watch_state.tsv"
run --force >/dev/null 2>&1          # 1회차: 스냅샷이 FAILED 로 굳는다
o=$(run --force)                      # 2회차: 변화는 «없다» — 그래도 말해야 한다
case "$o" in *FAILED*|*"읽지 못했다"*) ok "L9 FAILED 반복도 매번 보고 (인증만료≠변화없음)" ;; *) ng "L9" "FAILED 보고" "${o:-（무출력）}" ;; esac

# ── L10: 연속 탭(빈 필드)에서 needle 이 밀리지 않는다 ──
mkstub state
printf 'walkinglabs/x\t33\t\tchrono-meta/forge-harness\n' > "$SB/tracks/_meta/listing_watch_channels.tsv"
rm -f "$SB/tracks/_meta/.listing_watch_state.tsv"
run --force >/dev/null 2>&1
s9=$(cat "$SB/tracks/_meta/.listing_watch_state.tsv" 2>/dev/null)
case "$s9" in *LISTED*) ok "L10 빈 필드 있어도 needle 이 제자리 (IFS 탭 축약 방지)" ;; *) ng "L10" "LISTED" "$s9" ;; esac

# ── L11: 개행 없는 마지막 행도 읽는다 ──
printf 'walkinglabs/x\t33\tpr\tchrono-meta/forge-harness\nwalkinglabs/y\t33\tpr\tchrono-meta/forge-harness' > "$SB/tracks/_meta/listing_watch_channels.tsv"
rm -f "$SB/tracks/_meta/.listing_watch_state.tsv"
run --force >/dev/null 2>&1
n=$(grep -c . "$SB/tracks/_meta/.listing_watch_state.tsv" 2>/dev/null || echo 0)
[ "$n" = "2" ] && ok "L11 개행 없는 마지막 행 누락 안 함 (2/2)" || ng "L11" "2행" "${n}행"

# ── L12: 라벨 개수를 실어 ["a,b"] 와 ["a","b"] 를 가른다 ──
case "$s9" in *"	"[0-9]*:*) ok "L12 라벨 필드가 «개수:목록» 형태" ;; *) ng "L12" "N:labels" "$s9" ;; esac

printf '\nLISTING_WATCH_LANES: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
