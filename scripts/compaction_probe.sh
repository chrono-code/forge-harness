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
skipped_tool=skipped_meta=skipped_other=0
for line in open(sys.argv[1], errors='replace'):
    try: d=json.loads(line)
    except Exception: continue
    if d.get('type')!='user': continue
    m=d.get('message') or {}
    c=m.get('content')
    # ⚠️ 초판은 "실발화=str · 툴결과=list" 로 갈랐다. **틀렸다** — 이미지/파일을 첨부한 실발화는
    # list 다(high 리뷰 실측: 전사본 25개에서 그런 발화 18건이 구조적으로 안 보였다). 더 나쁜 건
    # self-test 픽스처가 같은 가정을 인코딩해서 **초록이 그 결함을 보증**했다는 것이다.
    # 이제 list 는 text 블록을 꺼내 쓰고, tool_result 만 제외한다.
    if isinstance(c,str):
        t=c
    elif isinstance(c,list):
        if any(isinstance(b,dict) and b.get('type')=='tool_result' for b in c):
            skipped_tool+=1; continue
        parts=[b.get('text','') for b in c if isinstance(b,dict) and b.get('type')=='text']
        if not parts:
            skipped_other+=1; continue          # 이미지-only 등 — 셈에서 지우지 않고 센다
        t=' '.join(parts)
    else:
        skipped_other+=1; continue
    t=' '.join(t.split())
    if not t: skipped_other+=1; continue
    if t.startswith('<') or t.startswith('/'):   # 슬래시 커맨드·메타 봉투 제외
        skipped_meta+=1; continue
    n+=1
    print(f"{n}. {t[:200]}")
# **제외분을 반드시 인쇄한다.** 합계만 찍으면 그 원장이 완전한 것처럼 읽힌다 — `not found ≠ 0`.
print(f"\n합계: {n}건" if n else "- (발화 0건)")
print(f"제외: tool_result {skipped_tool} · 메타/커맨드 {skipped_meta} · 텍스트없음 {skipped_other}")
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
      # upstream 이 없으면 `@{u}` 는 fatal 이고 2>/dev/null 이 그걸 삼켜 **0건**으로 렌더된다.
      # `git switch -c` 후 첫 푸시 전 = 이 레포의 정상 경로다. 미상과 0 을 갈라야 한다.
      if git -C "$REPO_ROOT" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
        echo "  미푸시: $(git -C "$REPO_ROOT" log --oneline '@{u}..HEAD' 2>/dev/null | wc -l | tr -d ' ')건"
      else
        echo "  미푸시: unknown (upstream 미설정 — 0건이 아니다)"
      fi
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
  # .pending 에 **세션 id 와 시각**을 같이 쓴다. 초판은 경로만 써서, 세션 A 가 봉인하고 그냥 나가면
  # 며칠 뒤 세션 B 의 첫 프롬프트가 A 의 발화·브랜치·더티파일을 **"직전 압축"이라고 주장하며** 주입했다.
  # **세션별 마커.** 하나를 공유하면 다음 프롬프트를 낸 아무 세션이나 그걸 소비하고, 정작 압축당한
  # 세션은 0바이트를 받는다 — 재주입이 존재하는 유일한 대상이 못 받는 것이다(high 재리뷰 #4).
  # 라벨링(#4 1차 수리)은 오배달을 *말해줬을 뿐* 라우팅하지 않았다.
  printf '%s\t%s\t%s\n' "$out" "$session" "$(date +%s)" > "$outdir/.pending_${session}" 2>/dev/null
  echo "sealed: $out"
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# digest — UserPromptSubmit 에서 1회 되주입 (없으면 무출력)
# ─────────────────────────────────────────────────────────────────────────────
do_digest() {
  local outdir="$1" DIGEST_SESSION="${2:-unknown}"
  # 내 세션 마커를 먼저 본다. 없으면 (세션 미상 등) 주인 없는 것만 관용으로 집는다 —
  # 남의 세션 마커를 **소비하지 않는다**. 소비하면 그 세션이 자기 원장을 영영 못 받는다.
  local pending="$outdir/.pending_${DIGEST_SESSION}"
  if [ ! -f "$pending" ]; then
    if [ "$DIGEST_SESSION" = "unknown" ]; then
      pending="$(ls -t "$outdir"/.pending_* 2>/dev/null | head -1)"
    else
      pending="$outdir/.pending"        # 구형식(단일 마커) 관용
    fi
  fi
  [ -n "${pending:-}" ] && [ -f "$pending" ] || return 0
  local sealfile sealsess sealts
  IFS=$'\t' read -r sealfile sealsess sealts < "$pending" 2>/dev/null
  [ -z "${sealfile:-}" ] && sealfile="$(head -1 "$pending" 2>/dev/null)"   # 구형식 관용
  # ⚠️ 인쇄 **전에** 소비한다. 소비를 뒤에 두면, 소비자가 파이프를 먼저 닫는 순간(SIGPIPE)
  # 마커가 안 지워지고 **매 프롬프트마다 무한 재주입**된다 — 실측 2026-08-08, `| head -12` 로 재현.
  # 트레이드오프는 의도적이다: 최악이 "한 번 못 보여줌"(복구 가능, 파일은 디스크에 남아 있다) 대
  # "영원히 소음"(사용자가 훅을 꺼버린다). 과차단이 override 를 습관화시키는 것과 같은 방향 판단.
  rm -f "$pending" 2>/dev/null
  if [ ! -f "$sealfile" ]; then return 0; fi

  # 신선도·세션 정합을 **주장에 반영**한다. 안 맞으면 주입은 하되 "직전 압축"이라고 말하지 않는다.
  local _now _age _stale="" _xsess=""
  _now=$(date +%s); _age=$(( _now - ${sealts:-$_now} ))
  [ "$_age" -gt 43200 ] && _stale=" ⚠️ ${_age}초 전 봉인 — 이 세션의 직전 압축이 아닐 수 있다"
  if [ -n "${sealsess:-}" ] && [ "${sealsess}" != "unknown" ] && [ -n "$DIGEST_SESSION" ] \
     && [ "$DIGEST_SESSION" != "unknown" ] && [ "${sealsess}" != "$DIGEST_SESSION" ]; then
    _xsess=" ⚠️ 다른 세션(${sealsess})의 봉인이다"
  fi
  if [ -n "$_stale$_xsess" ]; then
    echo "🧭 [FH 압축 복구] 봉인된 포인터 원장이 있다 — 내용이 아니라 경로다.$_stale$_xsess"
  else
    echo "🧭 [FH 압축 복구] 직전 압축 전에 봉인된 포인터 원장이 있다 — 내용이 아니라 경로다."
  fi
  echo "   정본: $sealfile"
  echo
  # ⚠️ 초판은 `sed -n '1,80p'` 였다. 봉인 앞부분은 **발화 덤프**라, 긴 세션에서는 80줄이 발화
  # 목록 중간에서 끊기고 **정작 포인터(git 상태·정본 경로·payload 상태)는 한 줄도 안 들어갔다** —
  # 계약("포인터 원장이다")의 정반대. 이제 포인터 절을 먼저 주입하고 발화는 뒤에서 잘라 붙인다.
  # ⚠️ **절마다 개별 상한**을 준다. 범위 하나에 head 를 걸면 앞 절(더티파일 목록)이 길 때 뒤 절
  # (정본 포인터·payload 상태)이 통째로 잘린다 — 1차 수리는 자르는 위치만 옮겼지 포인터가 그 안에
  # 든다는 보장을 안 만들었다(high 재리뷰 #8, 더티파일 35개로 재현).
  # 포인터가 이 원장의 존재 이유이므로 **포인터 절을 먼저, 그리고 절대 안 자른다.**
  echo "── 열어야 할 정본 ──"
  awk '/^## 열어야 할 정본/{f=1;next} /^## /{f=0} f' "$sealfile" 2>/dev/null | grep -v '^$'
  grep -E '^payload: ' "$sealfile" 2>/dev/null
  echo
  echo "── 이 세션이 건드린 파일 (앞 20줄) ──"
  awk '/^## 이 세션이 건드린 파일/{f=1;next} /^## /{f=0} f' "$sealfile" 2>/dev/null | grep -v '^$' | head -20
  echo
  echo "── 운영자 발화 (앞 25건) ──"
  awk '/^## 운영자 발화/{f=1;next} /^## /{f=0} f' "$sealfile" 2>/dev/null | grep -E '^[0-9]+\.|^제외:|^합계:' | head -25
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
    # ★ 이미지 첨부 실발화 — **list 인데 진짜 발화다.** 초판 픽스처엔 이 모양이 없었고,
    # 그래서 "list=툴결과" 가정이 self-test 를 통과했다. 픽스처가 결함을 보증한 자리.
    printf '%s\n' '{"type":"user","message":{"content":[{"type":"text","text":"일정이 조정됐어 리더리뷰는 다음주"},{"type":"image","source":{"type":"base64"}}]}}'
    # 이미지만 있는 발화 — 텍스트가 없으니 못 싣지만 **세어야** 한다
    printf '%s\n' '{"type":"user","message":{"content":[{"type":"image","source":{"type":"base64"}}]}}'
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

  grep -q "합계: 3건" "$sf" 2>/dev/null && r=YES || r=NO
  t "발화 카운트 정확 (3건 — 이미지 첨부 발화 포함)" YES "$r"

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
  grep -qE 'payload: (fallback-session|fallback-mtime-UNVERIFIED|unresolved)' "$sf2" 2>/dev/null && rc=YES || rc=NO
  t "payload 상태가 typed 로 남는다 (무음 아님)" YES "$rc"

  # ── 회귀 레인: high 리뷰 CONFIRMED (2026-08-08) ──
  # #2 list-shaped 실발화 — 픽스처에 이 모양이 없어서 초록이 결함을 보증했다
  grep -q "일정이 조정됐어" "$sf" 2>/dev/null && r=YES || r=NO
  t "#2 이미지 첨부 실발화(list)가 원장에 실린다" YES "$r"
  grep -q "툴 출력 본문" "$sf" 2>/dev/null && r=YES || r=NO
  t "#2 tool_result 는 여전히 제외" NO "$r"
  grep -qE "^제외: tool_result [0-9]+ · 메타/커맨드 [0-9]+ · 텍스트없음 [0-9]+" "$sf" 2>/dev/null && r=YES || r=NO
  t "#2 제외분이 명시 카운트된다 (합계만 찍지 않는다)" YES "$r"
  grep -q "텍스트없음 1" "$sf" 2>/dev/null && r=YES || r=NO
  t "#2 이미지-only 발화가 침묵 드롭되지 않고 계수된다" YES "$r"

  # #3 digest 는 발화 덤프가 아니라 **포인터**를 주입해야 한다
  # (앞 레인들이 .pending 을 소비했으므로 새로 봉인하고 잰다)
  do_seal "$T/tr.jsonl" "$T/out3b" "sess3b" >/dev/null 2>&1
  local dg; dg="$(do_digest "$T/out3b" 2>/dev/null)"
  case "$dg" in *"열어야 할 정본"*) r=YES ;; *) r=NO ;; esac
  t "#3 digest 가 정본 포인터를 주입한다" YES "$r"
  # ⚠️ 이 레인은 한때 "브랜치:" 등장을 무조건 YES 로 기대했다. **REPO_ROOT 가 git 저장소인지는
  # self-test 가 통제하지 않는 환경 조건**이다(스크립트 위치로 계산되는 값이지 $T 픽스처가 아니다) —
  # 그래서 non-git 트리(예: 소비자가 tarball 을 git 밖 스크래치 디렉터리에 풀어 실행)에서는 항상
  # FAIL 했다. known-pair 로 확인: 레포 rc=0 · non-git tmp rc=1 · **같은 tmp 에 `git init` 만 해도
  # rc=0**(2026-08-12, 재출하 축). do_seal 자신은 두 경우 다 올바르게 렌더한다("브랜치: …" 또는
  # "(git 레포 아님)") — 결함은 self-test 가 그 중 한쪽만 정답으로 하드코딩한 것이었다. 지금 실제
  # 상태를 물어 그 상태에 맞는 렌더를 기대한다 — 두 분기 다 계측한다(브랜치 있음일 때만 잰 것이
  # 아니라 없음일 때도 "(git 레포 아님)" 이 실제로 나오는지 검증).
  if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    case "$dg" in *"브랜치:"*) r=YES ;; *) r=NO ;; esac
    t "#3 digest 가 git 상태를 주입한다 (REPO_ROOT=git repo)" YES "$r"
  else
    case "$dg" in *"(git 레포 아님)"*) r=YES ;; *) r=NO ;; esac
    t "#3 digest 가 git 상태를 주입한다 (REPO_ROOT=non-git, graceful render)" YES "$r"
  fi

  # #4 세션 교차 주입 — 다른 세션의 봉인을 "직전 압축"이라고 주장하면 안 된다
  # ⚠️ 이 레인은 1차 수리 때 "라벨하면 된다"는 전제로 썼다가 **갱신됐다**. 라벨은 오배달을
  # 말해줄 뿐 라우팅하지 않았고, 그 사이 압축당한 세션이 0바이트를 받았다(high 재리뷰 #4).
  # 지금의 정답은 **다른 세션은 아무것도 안 받고, 주인 마커는 남아 있는 것**이다.
  do_seal "$T/tr.jsonl" "$T/out4" "SESSA" >/dev/null 2>&1
  local d4; d4="$(do_digest "$T/out4" "SESSB" 2>/dev/null | wc -c | tr -d ' ')"
  t "#4 다른 세션은 남의 봉인을 안 받는다" 0 "$d4"
  local d4o; d4o="$(do_digest "$T/out4" "SESSA" 2>/dev/null | wc -c | tr -d ' ')"
  [ "$d4o" -gt 100 ] && rc=YES || rc=NO
  t "#4 ★ 주인 세션은 자기 원장을 받는다 (소비당하지 않았다)" YES "$rc"
  do_seal "$T/tr.jsonl" "$T/out4b" "SESSA" >/dev/null 2>&1
  local d4b; d4b="$(do_digest "$T/out4b" "SESSA" 2>/dev/null)"
  case "$d4b" in *"직전 압축 전에"*) rc=YES ;; *) rc=NO ;; esac
  t "#4 같은 세션이면 직전-압축 주장 유지 (과경고 아님)" YES "$rc"
  case "$d4b" in *"다른 세션"*) rc=YES ;; *) rc=NO ;; esac
  t "#4 같은 세션에 교차 경고 안 뜬다" NO "$rc"

  # #8 포인터 절은 **절대 안 잘린다** — 더티파일 목록이 길어도
  do_seal "$T/tr.jsonl" "$T/out8" "SESS8" >/dev/null 2>&1
  local d8; d8="$(do_digest "$T/out8" "SESS8" 2>/dev/null)"
  case "$d8" in *"열어야 할 정본"*) rc=YES ;; *) rc=NO ;; esac
  t "#8 정본 포인터 절이 항상 들어간다" YES "$rc"
  case "$d8" in *"payload:"*) rc=YES ;; *) rc=NO ;; esac
  t "#8 payload typed 상태가 항상 들어간다" YES "$rc"

  # #5 세션 미상 폴백은 **미검증으로 라벨**돼야 한다 (침묵 추정 금지)
  local sf5
  printf '%s' '{}' | bash "$0" seal --dir "$T/out5" >/dev/null 2>&1
  sf5="$(ls -t "$T/out5"/seal_*.md 2>/dev/null | head -1)"
  # ⚠️ 성질은 "세션 미상 폴백이 **타입으로 남는다**" 이지 특정 값 하나가 아니다. 특정 값으로
  # 과대명세했더니 **저자 머신의 전사본이 있어야만 통과**하는 레인이 됐고, selfcheck 에 배선하자
  # CI 가 82db426 부터 빨개졌다(로컬 초록 ≠ CI 초록, 실측). 전사본이 없는 러너에서는 `unresolved`
  # 가 정답이고 그것도 **무음이 아니다** — 둘 다 통과여야 한다.
  grep -qE "payload: (fallback-mtime-UNVERIFIED|unresolved)" "$sf5" 2>/dev/null && rc=YES || rc=NO
  t "#5 세션 미상 폴백이 타입으로 남는다 (환경 무관)" YES "$rc"
  # known-negative: 무음(빈 값)이면 실패해야 한다 — 레인이 공허하지 않다는 증명
  grep -qE "payload: *$" "$sf5" 2>/dev/null && rc=YES || rc=NO
  t "#5 payload 가 빈 값이면 통과 아님" NO "$rc"

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
# ⚠️ 캡처는 **seal 에서만**. 전 모드에서 돌리면 매 `UserPromptSubmit`(digest)가 PreCompact 페이로드를
# 덮어써서, 빈 봉인을 진단하라고 만든 증거를 **다음 프롬프트가 파괴**한다. 게다가 사용자 프롬프트
# 원문이 매 턴 디스크에 남는다. (high 리뷰 실측 재현: seal 직후엔 PreCompact 페이로드, digest 한 번에 교체.)
# 훅 모드에서만 stdin 을 읽는다. 모드 화이트리스트가 없으면, 오타나 디스패처 소실 시
# 스크립트가 **stdin 을 기다리며 멈춘다** — 훅에선 페이로드가 오니 안 보이지만 CI 에선 정지다(실측).
case "$MODE" in seal|digest|score) _READS_STDIN=1 ;; *) _READS_STDIN=0 ;; esac
if [ "$_READS_STDIN" = "1" ] && [ -z "$TRANSCRIPT" ] && [ ! -t 0 ]; then
  HOOK_JSON="$(cat 2>/dev/null)"
  # 원본 페이로드를 항상 남긴다. 2026-08-08 첫 실발화가 session=unknown · transcript 빈 값으로
  # 돌았는데, 원본을 안 남겨서 **왜 그런지 알 방법이 없었다.** 미측정을 빈 값으로 렌더하지 않는다.
  # 쓰기는 seal 에서만 — digest 가 쓰면 진단 증거를 다음 프롬프트가 파괴한다(#10). 파싱은 전 모드.
  [ "$MODE" = "seal" ] && mkdir -p "$OUTDIR" 2>/dev/null && printf '%s' "$HOOK_JSON" > "$OUTDIR/.last_payload" 2>/dev/null
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
  _dir="$HOME/.claude/projects/$_slug"
  _cand=""
  # 세션 id 를 알면 **그 세션의 전사본**을 고른다. mtime 최신을 고르면 같은 레포에 세션이 둘 열려
  # 있을 때 **남의 발화를 이 세션 것으로 봉인**한다(high 리뷰 #5, 이 디렉토리에 전사본 125개).
  if [ "$SESSION" != "unknown" ] && [ -n "$SESSION" ]; then
    _cand="$(ls "$_dir"/"$SESSION"*.jsonl 2>/dev/null | head -1)"
    [ -n "$_cand" ] && PAYLOAD_STATUS="fallback-session"
  fi
  if [ -z "$_cand" ]; then
    _cand="$(ls -t "$_dir"/*.jsonl 2>/dev/null | head -1)"
    # 세션 미상 → 최신을 쓰되 **검증 불가임을 타입으로 남긴다.** 침묵 추정 금지.
    [ -n "$_cand" ] && PAYLOAD_STATUS="fallback-mtime-UNVERIFIED"
  fi
  if [ -n "$_cand" ] && [ -f "$_cand" ]; then
    TRANSCRIPT="$_cand"
    [ "$SESSION" = "unknown" ] && SESSION="$(basename "$_cand" .jsonl | cut -c1-12)"
  else
    PAYLOAD_STATUS="unresolved"
  fi
elif [ "$PAYLOAD_STATUS" = "args" ]; then
  PAYLOAD_STATUS="parsed"
fi

case "$MODE" in
  seal)   do_seal "$TRANSCRIPT" "$OUTDIR" "$SESSION" ;;
  digest) do_digest "$OUTDIR" "$SESSION" ;;
  score)  do_score "$TRANSCRIPT" "$OUTDIR" ;;
  *) echo "usage: $0 {seal|digest|score} [--transcript P] [--dir D] [--session S]"
     echo "       $0 --self-test" ;;
esac

exit 0   # 훅은 절대 비영 종료하지 않는다 — stdout 이 통째로 폐기된다
