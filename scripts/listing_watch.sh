#!/usr/bin/env bash
# listing_watch.sh — 외부 큐레이션 목록에 낸 제출의 «조용한 상태 전이»를 잡는다.
#
# 왜 있나 (실측 근거, 2026-08-19):
#   `awesome-claude-code` #1961 이 2026-06-07 에 validation-PASSED 였다가, 우리가 아무것도
#   안 건드린 채 2026-08-15 에 **validation-FAILED 로 뒤집혔다** — 그쪽이 허용 카테고리
#   목록을 바꾸고 봇이 기존 이슈를 재검증하면서 떨어진 것이다. 아무도 안 알려줬고,
#   `validation-failed` 는 «리뷰 대기열에서 빠진» 상태다. 4일 뒤 **우연히** 발견했다.
#   ⇒ 통과는 영구적이지 않고, 알림은 오지 않는다. 그래서 이쪽에서 스냅샷을 떠서 대조한다.
#
# 설계 규율 (전부 이 저장소의 실측에서 나온 것):
#   · **항상 exit 0 + stdout 보고** — 훅은 비영 종료 시 stdout 이 버려지고 stderr 도 안 온다
#     (`feedback_hook_nonzero_exit_is_silent`). 이 스크립트는 판정을 «출력»하지 종료코드로
#     말하지 않는다.
#   · **미측정을 0 으로 접지 않는다** — 상태는 넷이다: DISABLED / SKIPPED / FAILED / EXECUTED
#     (`feedback_not_found_is_not_zero_family`). `gh` 가 없으면 «통과» 가 아니라 «SKIPPED» 다.
#   · **파이프로 판정하지 않는다** — `out=$(cmd); rc=$?` 형태만 쓴다
#     (`feedback_pipefail_fallback_disarms_guard`).
#   · **부재 주장엔 컨트롤** — `--selftest` 가 known-positive/known-negative 를 돌린다
#     (`feedback_absence_measurement_needs_control`).
#   · bash 3.2 (macOS 기본) 호환 — 연관배열 안 쓴다.
#
# 채널 목록은 **이 파일에 안 박는다** — 운영자의 실제 제출은 사설 정보다.
#   매니페스트: tracks/_meta/listing_watch_channels.tsv   (gitignored)
#   형식(TAB 구분, `#` 주석):   owner/repo <TAB> number <TAB> pr|issue <TAB> 목록에서_찾을_문자열
#
# 사용:  bash scripts/listing_watch.sh [--force] [--selftest]

HUB="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
MANIFEST="$HUB/tracks/_meta/listing_watch_channels.tsv"
STATE="$HUB/tracks/_meta/.listing_watch_state.tsv"
THROTTLE_H=24
FORCE=0; SELFTEST=0
for a in "$@"; do
  case "$a" in --force) FORCE=1 ;; --selftest) SELFTEST=1 ;; esac
done

say() { printf '%s\n' "$*"; }

# 🟥 **`stat -f %m` 을 «먼저» 쓰면 리눅스에서 조용히 깨진다** — GNU stat 의 `-f` 는
#    «파일시스템 정보»라 **실패가 아니라 성공하며 다른 값을 뱉고**, 그래서 `||` 폴백이 안 탄다.
#    CI 가 실제로 그렇게 잡았다(`Type: ext2/ext3 … syntax error in expression`).
#    ⇒ 순서를 뒤집는 것으로 끝내지 않고 **숫자인지 검증**한다. 순서만 바꾸면 반대 플랫폼에서
#    같은 얼굴이 다시 난다. `[[feedback_wiring_surfaces_hidden_failures]]`
_mtime() {
  local m
  m=$(stat -c %Y "$1" 2>/dev/null)
  case "$m" in ''|*[!0-9]*) m=$(stat -f %m "$1" 2>/dev/null) ;; esac
  case "$m" in ''|*[!0-9]*) m=0 ;; esac
  printf '%s' "$m"
}

# 🟥 grep 패턴의 `\t` 는 **이식되지 않는다** — GNU grep 은 리터럴 `t` 로 읽어 0건이 되고,
#    그러면 「FAILED 를 매번 보고한다」는 규율이 리눅스에서만 조용히 죽는다(CI 적발).
#    실제 탭 문자를 만들어 `-F` 로 쓴다.
TAB=$(printf '\t')

# 🟥 테스트 seam: 레인이 «gh 없는 호스트» 를 흉내내려고 PATH 를 깎으면 호스트에 따라
#    결과가 갈린다(리눅스의 /usr/bin 에 gh 가 있을 수 있다 — cross-family 지목).
#    명령 이름을 주입 가능하게 두면 레인이 호스트와 무관해진다.
GH="${LISTING_WATCH_GH:-gh}"

# ── 도구 가용성: 없으면 «SKIPPED, not passed» ─────────────────────────────
if ! command -v "$GH" >/dev/null 2>&1; then
  say "  ⚠️  [listing-watch] SKIPPED (not passed) — \`$GH\` 없음. 등재 상태를 **확인하지 못했다**."
  exit 0
fi

# ── 한 채널의 현재 상태를 한 줄로 (owner/repo#num<TAB>STATE<TAB>labels<TAB>listed) ──
probe() {  # $1=repo $2=num $3=kind $4=needle
  local repo="$1" num="$2" kind="$3" needle="$4" st lab listed out rc
  # 🟥 라벨 «개수» 를 같이 싣는다 — join(",") 만으로는 ["a,b"](1개) 와 ["a","b"](2개) 가
  #    구분이 안 돼 진짜 라벨 전이가 스냅샷에서 같게 비친다(cross-family 지목).
  out=$($GH api "repos/$repo/issues/$num" --jq '"\(.state)|\(.pull_request.merged_at // "null")|\([.labels[].name]|length)|\([.labels[].name] | sort | join(","))"' 2>&1); rc=$?
  if [ $rc -ne 0 ]; then printf '%s#%s\tFAILED\t-\t-\n' "$repo" "$num"; return 0; fi
  st=$(printf '%s' "$out" | cut -d'|' -f1)
  local merged n_lab; merged=$(printf '%s' "$out" | cut -d'|' -f2); n_lab=$(printf '%s' "$out" | cut -d'|' -f3)
  lab=$(printf '%s' "$out" | cut -d'|' -f4-)
  [ "$merged" != "null" ] && st="MERGED"
  [ -z "$lab" ] && lab="-"
  lab="${n_lab}:${lab}"
  listed="unknown"
  if [ -n "$needle" ] && [ "$needle" != "-" ]; then
    local body brc dec
    body=$($GH api "repos/$repo/contents/README.md" --jq '.content' 2>/dev/null); brc=$?
    if [ $brc -eq 0 ] && [ -n "$body" ]; then
      # base64 플래그가 갈린다: GNU/신 macOS 는 -d, 구 macOS 는 -D. 둘 다 시도한다.
      dec=$(printf '%s' "$body" | base64 -d 2>/dev/null) || true
      [ -z "$dec" ] && dec=$(printf '%s' "$body" | base64 -D 2>/dev/null) || true
      if [ -z "$dec" ]; then
        listed="unreadable"   # 🟥 디코드 실패를 «absent» 로 접으면 계기 고장이 «미등재» 로 읽힌다
      elif printf '%s' "$dec" | grep -qF -- "$needle"; then listed="LISTED"
      else listed="absent"; fi
    else
      listed="unreadable"   # ← «없음» 이 아니라 «못 읽었음». 접지 않는다
    fi
  fi
  printf '%s#%s\t%s\t%s\t%s\n' "$repo" "$num" "$st" "$lab" "$listed"
}

# ── 컨트롤: 계기가 살아 있는지 (known-positive / known-negative) ──────────
if [ "$SELFTEST" = "1" ]; then
  say "[listing-watch selftest] 컨트롤 2종"
  kp=$(probe "walkinglabs/awesome-harness-engineering" 33 pr "forge-harness")
  say "  known-positive  walkinglabs#33 (MERGED 로 알려짐): $kp"
  case "$kp" in *MERGED*) say "    ✅ 양성 검출" ;; *) say "    ❌ 계기 고장 — 알려진 MERGED 를 못 읽었다" ;; esac
  kn=$(probe "walkinglabs/awesome-harness-engineering" 99999999 pr "-")
  say "  known-negative  없는 번호 #99999999: $kn"
  case "$kn" in *FAILED*) say "    ✅ 없는 것을 «없다»로 (지어내지 않음)" ;; *) say "    ❌ 없는 것에 상태를 만들어냈다" ;; esac
  exit 0
fi

# ── 매니페스트 없으면 DISABLED (기능 자체가 안 켜진 것 — 실패가 아니다) ──
if [ ! -f "$MANIFEST" ]; then
  say "  ℹ️  [listing-watch] DISABLED — 채널 매니페스트 없음 ($MANIFEST)."
  say "     켜려면 TAB 구분으로: owner/repo <TAB> 번호 <TAB> pr|issue <TAB> 목록에서_찾을_문자열"
  exit 0
fi

# ── 스로틀: 24h 안에 돌았으면 조용히 넘어간다 ────────────────────────────
if [ "$FORCE" != "1" ] && [ -f "$STATE" ]; then
  now=$(date +%s)
  mt=$(_mtime "$STATE")
  if [ $(( (now - mt) / 3600 )) -lt "$THROTTLE_H" ]; then exit 0; fi
fi

NEW=$(mktemp); CHANGED=0; ROWS=0
# 🟥 `IFS=$'\t' read` 를 쓰지 않는다 — 탭은 IFS 공백류라 **연속 탭이 합쳐져** 빈 칸이 있는
#    행에서 필드가 밀린다(cross-family 재현). 줄을 통째로 읽고 `cut` 으로 자른다.
# 🟥 `|| [ -n "$line" ]` 이 없으면 **개행 없는 마지막 행이 통째로 누락**된다(재현: 2행 중 1행).
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|\#*) continue ;; esac
  repo=$(printf '%s' "$line" | cut -f1)
  num=$(printf '%s' "$line" | cut -f2)
  kind=$(printf '%s' "$line" | cut -f3)
  needle=$(printf '%s' "$line" | cut -f4)
  case "$repo" in ''|\#*) continue ;; esac
  [ -z "$num" ] && continue
  ROWS=$((ROWS+1))
  line=$(probe "$repo" "$num" "${kind:-pr}" "${needle:--}")
  printf '%s\n' "$line" >> "$NEW"
  key=$(printf '%s' "$line" | cut -f1)
  if [ -f "$STATE" ]; then
    old=$(grep -F "$key	" "$STATE" 2>/dev/null | head -1)
    if [ -n "$old" ] && [ "$old" != "$line" ]; then
      [ "$CHANGED" = "0" ] && say "" && say "🔔 [listing-watch] **등재 채널 상태가 바뀌었다** — 아무도 안 알려주는 종류다"
      CHANGED=$((CHANGED+1))
      say "   $key"
      say "     이전: $(printf '%s' "$old"  | cut -f2-)"
      say "     지금: $(printf '%s' "$line" | cut -f2-)"
    fi
  fi
done < "$MANIFEST"

if [ "$ROWS" = "0" ]; then
  say "  ℹ️  [listing-watch] DISABLED — 매니페스트에 유효한 채널 행이 0개다."
  rm -f "$NEW"; exit 0
fi

# 🟥 **FAILED 는 «변화» 가 아니라 «상태» 로 매번 보고한다.** 안 그러면 인증 만료가 첫 실행에
#    스냅샷으로 굳고, 이후 FAILED==FAILED 라 **영구 무출력**이 된다 — 이 스크립트 헤더가
#    스스로 금지한 `not_found ≠ 0` 을 스크립트 자신이 저지르고 있었다(cross-family 지목, 재현됨).
# 🟥 `grep -c ... || echo 0` 을 쓰지 않는다: grep -c 는 무매치에서 **"0" 을 출력하고 exit 1** 이라
#    폴백이 "0\n0" 을 만들고 `[` 가 «integer expression expected» 로 죽는다(내 수리가 낸 결함).
#    `[[feedback_pipefail_fallback_disarms_guard]]` 일가 — 값을 먼저 잡고 따로 판정한다.
NFAIL=$(grep -cF "${TAB}FAILED${TAB}" "$NEW" 2>/dev/null)
case "$NFAIL" in ''|*[!0-9]*) NFAIL=0 ;; esac
if [ "$NFAIL" -gt 0 ]; then
  say ""
  say "  ⚠️  [listing-watch] 채널 $NFAIL 개를 **읽지 못했다**(FAILED) — «변화 없음» 이 아니다."
  grep -F "${TAB}FAILED${TAB}" "$NEW" 2>/dev/null | while IFS= read -r l; do say "       $(printf '%s' "$l" | cut -f1)"; done
  say "       흔한 원인: gh 인증 만료(\`gh auth status\`) · 레포/번호 오타 · 비공개 전환."
  say "       🟥 이 줄이 안 보일 때까지는 그 채널의 상태를 **모르는 것**이다."
fi

if [ ! -f "$STATE" ]; then
  say "  ℹ️  [listing-watch] 최초 실행 — 채널 $ROWS 개 스냅샷을 떴다. 다음 실행부터 «변화»를 낸다."
elif [ "$CHANGED" -gt 0 ]; then
  say "   ⚠️  통과는 영구적이지 않다 — 남의 스키마가 바뀌면 과거 제출이 소급 무효가 된다."
  say "      새로 내기 전에 라벨 이력부터: gh api repos/<r>/issues/<n>/timeline"
fi
if ! mv "$NEW" "$STATE" 2>/dev/null; then
  say "  ⚠️  [listing-watch] 스냅샷 **저장 실패** ($STATE) — 다음 실행이 이번 관측을 못 본다."
  say "       변화 검출이 이 시점부터 **멈춘 것**이지 «변화 없음» 이 아니다."
  rm -f "$NEW"
fi
exit 0
