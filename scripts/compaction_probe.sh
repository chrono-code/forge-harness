#!/usr/bin/env bash
# compaction_probe.sh — 압축을 이벤트로 잡아 세션이 쥐고 있던 것을 **압축 전에 디스크로 봉인**하고,
#                       압축 후 첫 프롬프트에서 **포인터만** 되주입한다.
#
# ── 왜 (진단) ──
# 압축은 "질의를 알기 전에, 되돌릴 방법 없이 버린다"(rate-distortion 서베이). FH 는 여기서
# 구조적으로 유리하다 — **원본이 디스크에 있다. 잃은 건 컨텍스트가 아니라 포인터다.**
# 그래서 이 스크립트가 복원하는 것은 내용이 아니라 **어디를 열면 되는가**다.
#
# ── 이 스크립트가 하는 것과 안 하는 것 (경계를 흐리지 마라) ──
#   seal    PreCompact  — 세션이 쥔 것의 typed 원장을 디스크에 봉인. 압축을 **차단하지 않는다**
#   digest  UserPromptSubmit — 봉인분을 1회 되주입하고 소비 표시
#   score   advisory    — 🟥 **UNCALIBRATED**. 아래 §계기 타당성 참조
#
# ── §계기 타당성 — `score` 는 UNCALIBRATED 가 아니라 **반증됐다** (2026-08-08 실측) ──
# 채점하려면 *압축 후 transcript 파일이 무엇을 담는지* 를 알아야 했고, 두 가능성이 있었다:
#   ⓐ 파일이 히스토리를 그대로 보존하고 모델 컨텍스트만 압축된다
#   ⓑ 파일에 압축 요약 레코드가 남고 그 이후가 실컨텍스트다
#
# **첫 실압축 관측(2026-08-08 15:51:28, 이 훅이 스스로 남긴 seal 이 증거)에서 ⓐ로 확정됐다**:
# 압축 직후 전사본은 user 109 · assistant 238 레코드를 전부 보존하고 있었고 압축 구조 필드는
# 0건이었다. 즉 **전사본을 grep 하는 채점기는 손실 0 을 영원히 보고한다 — fail-open 계기다.**
# 설계 정본의 "압축 후 프로브 채점"은 이 경로로는 성립하지 않는다. 캘리브레이션이 덜 된 게
# 아니라 **가정이 틀렸다.** 채점을 하려면 전사본이 아니라 *모델이 여전히 답할 수 있는가*를
# 물어야 하고, 그건 훅이 못 한다(격리 채점자 필요 — 미건축).
# `score` 는 그 사실을 인쇄하는 자리로만 남긴다. 아무 판정도 여기에 의존하지 않는다.
#
# 추가로, 설령 ⓑ 라도 grep 이 재는 것은 **축자 생존**이지 의미 보존이 아니다. 요약되어 살아남은
# 항목은 미생존으로 잡힌다 — **과보고 방향**이라 안전하지만(fail-open 아님), 그 숫자를
# "압축이 N 건을 잃었다"로 읽으면 그것이 바로 `[[feedback_metric_measures_presence_not_relation]]` 이다.
#
# ── 배선 (설계 정본에서 한 군데 정정됨) ──
# 설계는 *"불합격은 PostCompact 에서 원본 포인터로 재주입"* 이라 적었다. **불가능하다** —
# `PostCompact` 는 `additionalContext` 를 지원하지 않는다(공식 훅 문서, 2026-08-08 확인).
# 되주입은 `UserPromptSubmit`(지원함) 으로 넘긴다. 산문대로 짰으면 배선해놓고 안 도는 걸 몰랐다.
#   PreCompact       → seal
#   UserPromptSubmit → digest   (봉인분이 있으면 1회 주입, 없으면 무출력)
#
# ⚠️ 훅은 **항상 exit 0** 이다. 비영 종료는 stdout 을 통째로 폐기한다
# (`[[feedback_hook_nonzero_exit_is_silent]]`). 압축은 절대 차단하지 않는다 — 가역 표면이고,
# 과차단은 override 를 습관화시킨다.
#
# ── 사용 ──
#   echo "$HOOK_JSON" | bash scripts/compaction_probe.sh seal
#   echo "$HOOK_JSON" | bash scripts/compaction_probe.sh digest
#   bash scripts/compaction_probe.sh seal --transcript <path> --dir <outdir>   # 테스트용
#   bash scripts/compaction_probe.sh --self-test

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEAL_DIR_DEFAULT="$REPO_ROOT/tracks/_meta/compaction"

# ─────────────────────────────────────────────────────────────────────────────
# seal — 압축 전에 세션이 쥔 것을 디스크로
# ─────────────────────────────────────────────────────────────────────────────
do_seal() {
  local transcript="$1" outdir="$2" session="$3"
  mkdir -p "$outdir" 2>/dev/null || { echo "seal: outdir 생성 실패: $outdir"; return 0; }

  local stamp; stamp="$(date +%Y%m%d-%H%M%S)"
  local out="$outdir/seal_${session}_${stamp}.md"

  {
    echo "# 압축 전 봉인 — session=${session} at ${stamp}"
    echo
    echo "> **포인터 원장이다. 내용 사본이 아니다.** 필요하면 아래 경로를 열어라."
    echo "> 압축이 잃는 것은 컨텍스트가 아니라 포인터라는 진단에 대한 직접 대응."
    echo

    echo "## 운영자 발화 (이 세션)"
    if [ -f "$transcript" ]; then
      python3 - "$transcript" <<'PY' 2>/dev/null || echo "- (전사본 파싱 실패 — 원본: $transcript)"
import json,sys
n=0
for line in open(sys.argv[1], errors='replace'):
    try: d=json.loads(line)
    except Exception: continue
    if d.get('type')!='user': continue
    m=d.get('message') or {}
    c=m.get('content')
    # 실발화는 content 가 str. 툴 결과는 list — 기계적으로 갈린다(실측 2026-08-08).
    if not isinstance(c,str): continue
    t=' '.join(c.split())
    if not t: continue
    if t.startswith('<') or t.startswith('/'):   # 슬래시 커맨드·메타 봉투 제외
        continue
    n+=1
    print(f"{n}. {t[:200]}")
print(f"\n합계: {n}건" if n else "- (발화 0건)")
PY
    else
      echo "- 🟥 전사본 경로 없음: $transcript"
    fi
    echo

    echo "## 이 세션이 건드린 파일"
    if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
      local changed; changed="$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null | sed 's/^/  /')"
      [ -n "$changed" ] && echo "$changed" || echo "  (working tree clean)"
      echo
      echo "  브랜치: $(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)"
      echo "  미푸시: $(git -C "$REPO_ROOT" log --oneline '@{u}..HEAD' 2>/dev/null | wc -l | tr -d ' ')건"
    else
      echo "  (git 레포 아님)"
    fi
    echo

    echo "## 열어야 할 정본 (존재하는 것만)"
    local today; today="$(date +%Y-%m-%d)"
    local p
    for p in "tracks/_meta/fh_completed_${today}.md" \
             "tracks/_meta/reference_next_session_starter.md"; do
      [ -f "$REPO_ROOT/$p" ] && echo "  - $p"
    done
    echo
    echo "---"
    echo "payload: ${PAYLOAD_STATUS:-unknown}   (parsed=훅 JSON · fallback-cwd=cwd로 자력 탐색 · unresolved=전사본 못 찾음)"
    echo "생성: scripts/compaction_probe.sh seal"
  } > "$out" 2>/dev/null

  # 되주입 대기 표시 — digest 가 소비한다
  echo "$out" > "$outdir/.pending" 2>/dev/null
  echo "sealed: $out"
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# digest — UserPromptSubmit 에서 1회 되주입 (없으면 무출력)
# ─────────────────────────────────────────────────────────────────────────────
do_digest() {
  local outdir="$1"
  local pending="$outdir/.pending"
  [ -f "$pending" ] || return 0
  local sealfile; sealfile="$(cat "$pending" 2>/dev/null)"
  # ⚠️ 인쇄 **전에** 소비한다. 소비를 뒤에 두면, 소비자가 파이프를 먼저 닫는 순간(SIGPIPE)
  # 마커가 안 지워지고 **매 프롬프트마다 무한 재주입**된다 — 실측 2026-08-08, `| head -12` 로 재현.
  # 트레이드오프는 의도적이다: 최악이 "한 번 못 보여줌"(복구 가능, 파일은 디스크에 남아 있다) 대
  # "영원히 소음"(사용자가 훅을 꺼버린다). 과차단이 override 를 습관화시키는 것과 같은 방향 판단.
  rm -f "$pending" 2>/dev/null
  if [ ! -f "$sealfile" ]; then return 0; fi

  echo "🧭 [FH 압축 복구] 직전 압축 전에 봉인된 포인터 원장이 있다 — 내용이 아니라 경로다."
  echo "   정본: $sealfile"
  echo
  sed -n '1,80p' "$sealfile" 2>/dev/null
  echo
  echo "   ⚠️ 이 원장은 **축자 기록**이다. 여기 있는 발화가 기록에 착지했는지는 별도 검증이다"
  echo "      (scripts/utterance_landing_check.sh)."

  rm -f "$pending" 2>/dev/null   # 1회성 — 매 프롬프트 재주입은 소음이다
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# score — 🟥 UNCALIBRATED advisory (§계기 타당성 참조)
# ─────────────────────────────────────────────────────────────────────────────
do_score() {
  local transcript="$1" outdir="$2"
  local latest; latest="$(ls -t "$outdir"/seal_*.md 2>/dev/null | head -1)"
  echo "🟥 REFUTED — 전사본 grep 채점은 성립하지 않는다. 아무 판정도 여기에 의존하지 않는다."
  echo "   실측(2026-08-08 첫 실압축): 압축 후에도 전사본이 전 레코드를 보존한다(ⓐ)."
  echo "   → grep 은 손실 0 을 영원히 보고한다 = fail-open 계기. 캘리브레이션 부족이 아니라 가정 오류."
  echo "   채점하려면 '모델이 여전히 답하는가'를 물어야 하고 훅은 못 한다 — 격리 채점자 필요(미건축)."
  [ -n "$latest" ] && echo "   최근 봉인: $latest" || echo "   봉인 없음."
  [ -f "$transcript" ] && echo "   대상 전사본: $transcript ($(wc -c < "$transcript" | tr -d ' ') bytes)"
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
self_test() {
  local T f=0 n=0 rc
  T=$(mktemp -d); trap 'rm -rf "$T"' RETURN
  t() { n=$((n+1)); if [ "$2" = "$3" ]; then echo "✅ $1 → $3"; else echo "❌ $1 → $3 (기대 $2)"; f=1; fi; }

  # 합성 전사본: 실발화 2건(str) + 툴결과 1건(list) + 슬래시커맨드 1건
  {
    printf '%s\n' '{"type":"user","message":{"content":"엔진 넷을 RC 까지 올린다"}}'
    printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","content":"툴 출력 본문"}]}}'
    printf '%s\n' '{"type":"user","message":{"content":"/clear"}}'
    printf '%s\n' '{"type":"assistant","message":{"content":"응답"}}'
    printf '%s\n' '{"type":"user","message":{"content":"곁가지는 병렬 세션에서"}}'
  } > "$T/tr.jsonl"

  do_seal "$T/tr.jsonl" "$T/out" "sess1" >/dev/null 2>&1; rc=$?
  t "seal 정상 종료" 0 "$rc"

  local sf; sf="$(ls "$T/out"/seal_*.md 2>/dev/null | head -1)"
  [ -n "$sf" ] && r=YES || r=NO
  t "봉인 파일 생성" YES "$r"

  # known-positive: 실발화 2건이 원장에 들어간다
  grep -q "엔진 넷을 RC 까지 올린다" "$sf" 2>/dev/null && r=YES || r=NO
  t "실발화 착지 (known-positive)" YES "$r"
  grep -q "곁가지는 병렬 세션에서" "$sf" 2>/dev/null && r=YES || r=NO
  t "실발화 2건째 착지 (known-positive)" YES "$r"

  # known-negative: 툴 결과와 슬래시 커맨드는 발화가 아니다 — 들어가면 안 된다
  grep -q "툴 출력 본문" "$sf" 2>/dev/null && r=YES || r=NO
  t "툴 결과 제외 (known-negative)" NO "$r"
  grep -q '^3\. /clear' "$sf" 2>/dev/null && r=YES || r=NO
  t "슬래시 커맨드 제외 (known-negative)" NO "$r"

  grep -q "합계: 2건" "$sf" 2>/dev/null && r=YES || r=NO
  t "발화 카운트 정확 (2건)" YES "$r"

  # digest: 1회만 나오고 두 번째는 무출력 — 매 프롬프트 재주입은 소음이다
  local d1 d2
  d1="$(do_digest "$T/out" 2>/dev/null | wc -c | tr -d ' ')"
  d2="$(do_digest "$T/out" 2>/dev/null | wc -c | tr -d ' ')"
  [ "$d1" -gt 100 ] && r=YES || r=NO
  t "digest 1회차 주입됨" YES "$r"
  t "digest 2회차 무출력 (소비됨)" 0 "$d2"

  # 봉인 없는 상태에서 digest 는 조용해야 한다 (신규 세션 오염 금지)
  d2="$(do_digest "$T/empty" 2>/dev/null | wc -c | tr -d ' ')"
  t "봉인 없으면 무출력" 0 "$d2"

  # ── 회귀 레인: SIGPIPE 소비 누락 (2026-08-08 실측 재현) ──
  # 소비자가 파이프를 먼저 닫아도 마커는 소비돼야 한다. 인쇄 뒤에 rm 을 두면 여기서 되돌아온다.
  do_seal "$T/tr.jsonl" "$T/out3" "sess3" >/dev/null 2>&1
  do_digest "$T/out3" 2>/dev/null | head -1 >/dev/null 2>&1
  d2="$(do_digest "$T/out3" 2>/dev/null | wc -c | tr -d ' ')"
  t "파이프 조기 종료 후에도 소비됨 (무한 재주입 방지)" 0 "$d2"

  # 전사본이 없어도 훅은 절대 죽지 않는다
  do_seal "$T/NOPE.jsonl" "$T/out2" "sess2" >/dev/null 2>&1; rc=$?
  t "전사본 부재에도 exit 0 (훅 안전)" 0 "$rc"

  # ── 회귀 레인: 빈/불량 페이로드 (2026-08-08 첫 실발화 실측) ──
  # 실발화가 session=unknown · transcript 빈 값으로 돌아 **빈 봉인**을 남겼다.
  # 훅 페이로드 모양은 런타임 버전에 딸린 외부 의존이라, 거기에 기능 전체를 걸면 안 된다.
  local out_empty
  out_empty="$(printf '%s' '{}' | bash "$0" seal --dir "$T/pl" 2>&1)"
  case "$out_empty" in *sealed:*) rc=YES ;; *) rc=NO ;; esac
  t "빈 페이로드에도 봉인은 생성된다" YES "$rc"
  [ -f "$T/pl/.last_payload" ] && rc=YES || rc=NO
  t "원본 페이로드가 기록된다 (원인 추적 가능)" YES "$rc"
  local sf2; sf2="$(ls -t "$T/pl"/seal_*.md 2>/dev/null | head -1)"
  grep -qE 'payload: (fallback-cwd|unresolved)' "$sf2" 2>/dev/null && rc=YES || rc=NO
  t "payload 상태가 typed 로 남는다 (무음 아님)" YES "$rc"

  echo
  [ "$f" -eq 0 ] && echo "✅ 캘리브레이션 통과 ($n 쌍) — seal/digest 레그 한정. score 는 실측으로 **반증**됐다(§계기 타당성)." \
                 || echo "❌ 캘리브레이션 실패 ($n 쌍)"
  return "$f"
}

# ─────────────────────────────────────────────────────────────────────────────
[ "${1:-}" = "--self-test" ] && { self_test; exit $?; }

MODE="${1:-}"; shift || true
TRANSCRIPT=""; OUTDIR="$SEAL_DIR_DEFAULT"; SESSION="unknown"

while [ "$#" -gt 0 ]; do
  case "$1" in
    # 값 없는 마지막 옵션에서 `shift 2` 는 실패하고, -e 가 없어 루프가 안 돌아 **무한루프**가 된다
    # — cross-family 지적 (c-2), 2026-08-08. 인자 수를 세고 shift 한다.
    --transcript) TRANSCRIPT="${2:-}"; [ "$#" -ge 2 ] && shift 2 || shift ;;
    --dir)        OUTDIR="${2:-$OUTDIR}"; [ "$#" -ge 2 ] && shift 2 || shift ;;
    --session)    SESSION="${2:-$SESSION}"; [ "$#" -ge 2 ] && shift 2 || shift ;;
    *) shift ;;
  esac
done

# 훅 경로: stdin 의 JSON 에서 읽는다. 인자로 준 값이 있으면 그쪽이 이긴다(테스트용).
PAYLOAD_STATUS="args"
if [ -z "$TRANSCRIPT" ] && [ ! -t 0 ]; then
  HOOK_JSON="$(cat 2>/dev/null)"
  # 원본 페이로드를 항상 남긴다. 2026-08-08 첫 실발화가 session=unknown · transcript 빈 값으로
  # 돌았는데, 원본을 안 남겨서 **왜 그런지 알 방법이 없었다.** 미측정을 빈 값으로 렌더하지 않는다.
  mkdir -p "$OUTDIR" 2>/dev/null && printf '%s' "$HOOK_JSON" > "$OUTDIR/.last_payload" 2>/dev/null
  if [ -n "$HOOK_JSON" ]; then
    eval "$(printf '%s' "$HOOK_JSON" | python3 -c '
import json,sys,shlex
try: d=json.load(sys.stdin)
except Exception: d={}
tp=d.get("transcript_path") or ""
sid=(d.get("session_id") or "unknown")[:12]
print(f"TRANSCRIPT={shlex.quote(tp)}; SESSION={shlex.quote(sid)}")
' 2>/dev/null)"
  fi
fi

# 페이로드에서 전사본을 못 얻었으면 **cwd 로 스스로 찾는다.** 빈 봉인은 봉인이 아니다 —
# 훅 페이로드 모양은 런타임 버전에 딸린 외부 의존이고, 거기에 기능 전체를 걸면 안 된다.
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  _slug="$(printf '%s' "$REPO_ROOT" | sed 's|/|-|g')"
  _cand="$(ls -t "$HOME/.claude/projects/$_slug"/*.jsonl 2>/dev/null | head -1)"
  if [ -n "$_cand" ] && [ -f "$_cand" ]; then
    TRANSCRIPT="$_cand"; PAYLOAD_STATUS="fallback-cwd"
    [ "$SESSION" = "unknown" ] && SESSION="$(basename "$_cand" .jsonl | cut -c1-12)"
  else
    PAYLOAD_STATUS="unresolved"
  fi
elif [ "$PAYLOAD_STATUS" = "args" ]; then
  PAYLOAD_STATUS="parsed"
fi

case "$MODE" in
  seal)   do_seal "$TRANSCRIPT" "$OUTDIR" "$SESSION" ;;
  digest) do_digest "$OUTDIR" ;;
  score)  do_score "$TRANSCRIPT" "$OUTDIR" ;;
  *) echo "usage: $0 {seal|digest|score} [--transcript P] [--dir D] [--session S]"
     echo "       $0 --self-test" ;;
esac

exit 0   # 훅은 절대 비영 종료하지 않는다 — stdout 이 통째로 폐기된다
