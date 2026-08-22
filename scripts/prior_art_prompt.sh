#!/usr/bin/env bash
# prior_art_prompt.sh — T2 «새로 짓기 시작» 시점에 **내 컨텍스트로** 한 줄을 넣는다.
#
# ── 왜 이 자리인가 (2026-08-21, 챔버 런 consolidation-path-gate) ──
# 운영자 실경험이 준 두 시점: T1 착수(세션 갓 시작) · **T2 컨텍스트가 길어진 뒤 또 새로 빌드업할 때**.
# 이 훅이 T2 다. PreToolUse(Write) 는 «새 파일을 쓰기 직전» 이라 그 경계와 정확히 겹친다.
#
# ── 왜 산문이 아니라 훅인가 (실측) ──
# 같은 날 sim: **명시 지시 3/3 · advisory 0/3 · 프레이밍 0/3**. CLAUDE.md 에 규율을 더 적는 것은
# 프레이밍이라 0/3 자리다. `additionalContext` 는 훅이 **모델 컨텍스트에 지시로** 넣는 유일한
# 채널이고([[feedback_advisory_invisible_to_actor]]), 그게 3/3 자리다.
#
# ── 왜 서브에이전트가 아닌가 ──
# 같은 날 먼저 지은 `persona-innovator` Mode X 는 **불렀을 때** 돈다. 남에게 시킨 숙고는 그 순간의
# 세션을 안 바꾼다 — 오늘 자력 적발 0 · 외부(운영자5·codex·challenger·레인·CI) 적발 10+ 이 그 증거다.
#
# ── 이건 브레이크가 아니라 곱셈기다 (운영자, 2026-08-21) ──
# *"충분히 세상을 찾아봤으면 그 이후에는 가진 능력을 활용해서 개발을 해내야 한다. 이때 내부의
#  능력을 100% 활용해야지. 조합하면 배수는 지수적으로 올라갈 수 있고. 그게 가능한 이유는 바깥의
#  문제를 풀어낸 데이터들과 내부의 능력 오케스트레이션이 서로 엮이고 곱해지기 때문이다."*
# ⇒ 이 훅의 목적은 «짓지 마라» 가 아니라 «바깥을 입력으로 삼아 안을 100% 써라» 다.
# 금지로 읽히면 무시당하고, 곱셈기로 읽히면 쓰인다. 문안이 그렇게 끝나야 한다.
#
# ── 새 판단 0줄 ──
# 🟥 «명명 어휘» 가 이 훅의 실제 기전이다 (2026-08-21 실측). 같은 날 sim 에서 양팔 다 검색했는데
# 힌트 쥔 쪽만 정답에 닿았다(2/3 vs 0/3) — 차이는 검색 의지가 아니라 **무엇을 찾을지 이름 붙이는
# 능력**이었다. 운영자: *"늘 책을 읽는 사람이 AI 를 더 잘 다루어낸다."* 독서가 주는 것이 명명
# 어휘이고, 이 훅은 그걸 그 순간에 빌려주는 것이다. 그래서 문안이 «찾아라» 가 아니라
# «일반 어휘로 이름 붙여 찾아라» 로 끝난다.
#
# ── 사다리지 체크리스트가 아니다 (운영자, 2026-08-21) ──
# *"근처에 있는 책장 찾기 > 책장에도 없으면 도서관 가기"* — 순서가 하중이다. 셋이 그 순서를 지지한다:
# 코퍼스(ⓑ내부미조회 9 > ⓐ외부미조회 6) · 이 세션 sim(내부 부재판정 오류 6/6) · SAAS 2605.29796
# («internal knowledge suffices 인데 무턱대고 검색 = severe over-search»). 평평한 목록은 그 순서를
# 못 준다. 그리고 FH 자산 이름이 이미 `deep_research_capability_ladder` 다 — 사다리가 원래 형태다.
#
# 내용은 **이미 있는 스킬 넷을 가리키기만** 한다(운영자: *"우리 안에 그 스킬들이 있고 그 스킬들을
# 발휘하면 세계에 닿겠지"*). 내부=asset-placement-gate Step 0.6 · CATALOG · novelty_claim_check ·
# 외부=deep_research_capability_ladder · 숙고=fh-commons:deliberation.
#
# ── degrade ──
# 가역 표면(파일 쓰기)이라 **절대 안 막는다.** exit 0 고정, permissionDecision 없음.
# 판정도 안 한다 — 한 줄 제안이다. 조용한 실패(파싱 불가·python3 부재)는 무음 통과.
set -uo pipefail
RAW=$(cat 2>/dev/null || true)
# file_path 와 session_id 를 한 번에 뽑는다(파이프 두 번 안 탄다).
PARSED=$(printf '%s' "$RAW" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
ti=d.get("tool_input",{}) or {}
fp=(ti.get("file_path","") or "")
cmd=(ti.get("command","") or "").replace("\t"," ").replace("\n"," ")
sid=(d.get("session_id","") or "")
sys.stdout.buffer.write((fp+"\t"+sid+"\t"+cmd).encode("utf-8"))
' 2>/dev/null) || exit 0
FILE="${PARSED%%$'\t'*}"
_REST="${PARSED#*$'\t'}"
SID="${_REST%%$'\t'*}"
CMD="${_REST#*$'\t'}"
[ "$CMD" = "$_REST" ] && CMD=""

# ── 🟥 Bash 경로 (2026-08-21, 첫 실사용이 «비발화» 로 났다) ──
# 초판 matcher 는 `Write` 뿐이었다. 그런데 auto-mode 는 파일 생성을 **Bash 의 리다이렉트/heredoc**
# 으로 한다(이 저장소 CLAUDE.md 가 그렇게 지시한다: *"make file changes with sed, heredocs…"*).
# 즉 이 훅이 겨냥한 «새 메커니즘을 짓기 직전» 이 **구조적으로 Write 를 안 탄다.**
# ⇒ matcher 에 Bash 를 넣고, `file_path` 가 없으면 **명령의 리다이렉트 대상**에서 뽑는다.
#
# 🟥 heredoc 을 파싱하지 않는다 — 리다이렉트 «대상 경로» 만 본다. `cat > x.sh <<EOF` 든
#    `printf … > x.sh` 든 대상은 `> ` 뒤에 있고, 본문은 볼 필요가 없다. 놓치는 형태
#    (`tar x` · 에디터 · `cp`)는 **명시된 잔여**다 — 이 훅은 판정이 아니라 제안이라 미발화의
#    비용이 오발화보다 싸다.
if [ -z "$FILE" ] && [ -n "$CMD" ]; then
  # 🟥 cross-family 4 HIGH 를 받고 다시 지었다 (2026-08-21). 넷 다 **오발화**였고,
  #    이 훅에서 오발화는 미발화보다 훨씬 비싸다(소음 = 자기무력화 경로).
  #      ① `[[:space:]]tee` 에 **뒤 경계가 없어** `rg tee_probe.py` 가 tee 대상으로 읽혔다
  #      ② `>>?` 가 **`2>` 안의 `>`** 를 잡아 `pytest 2> /tmp/errors.sh` 가 발화했다
  #      ③ `git diff > /tmp/review_delta.sh` — 리포트인데 이름이 `.sh` 라 발화했다
  #      ④ `"$LOG_DIR/x.sh"` — 변수가 안 풀려 리터럴 `$LOG_DIR/...` 로 존재검사를 통과했다
  #    수리 셋: ⓐ 리다이렉트는 **앞이 «줄머리 또는 공백»** 이어야 한다(→ `2>`·`1>`·`&>` 배제)
  #             ⓑ `tee` 는 **앞뒤 공백**을 요구한다  ⓒ 대상은 **이 프로젝트 안**이어야 한다
  #    ⓒ 가 ②③ 의 현실적 형태를 함께 죽인다 — 새 «메커니즘» 은 /tmp 에 안 산다.
  for _c in $(printf '%s' "$CMD" \
      | grep -oE '(^|[[:space:]])(>>?|tee[[:space:]])[[:space:]]*"?'"'"'?[^ "'"'"'|;&)<>]+' 2>/dev/null \
      | sed -E 's/^[[:space:]]*(>>?|tee[[:space:]])[[:space:]]*//; s/^["'"'"']//'); do
    case "$_c" in
      ''|/dev/*|\&*|-) continue ;;
      *'$'*) continue ;;                       # ④ 미확장 변수 — 리터럴로 판정하면 거짓이다
      *..*) continue ;;                        # 상위 탈출 경로는 «이 프로젝트 안» 이 아니다
    esac
    # ⓒ 프로젝트 밖 절대경로는 대상이 아니다. 상대경로는 프로젝트 기준이라 통과시킨다.
    case "$_c" in
      /*) case "$_c" in
            "${CLAUDE_PROJECT_DIR:-/nonexistent-project-dir}"/*) ;;
            *) continue ;;
          esac ;;
    esac
    case "$_c" in
      *.sh|*/SKILL.md|*/SKILL_detail.md|*/agents/*.md|*/rules/*.md|*.py|*.js|*.ts) FILE="$_c"; break ;;
    esac
  done
fi
[ -n "$FILE" ] || exit 0

# ── 발동 조건 — 소음이 이 능력을 죽인다(냉독자 «자기무력화 경로») ──
# ① 이미 있는 파일 편집은 «새로 짓기» 가 아니다
[ -e "$FILE" ] && exit 0
# ② 기록·산출물은 대상이 아니다. «메커니즘» 만.
# 🟥 상대경로도 잡아야 한다 (2026-08-21 레인 D4). 초판 제외는 `*/tracks/*` 뿐이라
#    **절대경로만** 걸렀다 — Write 는 절대경로를 주지만 **Bash 는 상대경로를 준다**
#    (`cat > tracks/_meta/note.sh`). Bash 팔을 붙이면서 이 비대칭이 드러났고,
#    제외가 안 먹으면 이 훅은 산출물마다 뜨는 소음이 된다(=자기무력화 경로).
case "$FILE" in
  tracks/*|logs/*|.git/*|node_modules/*) exit 0 ;;
  */tracks/*|*/logs/*|*.log|*.json|*.lock|*/node_modules/*|*/.git/*) exit 0 ;;
esac
case "$FILE" in
  *.sh|*/SKILL.md|*/SKILL_detail.md|*/agents/*.md|*/rules/*.md|*.py|*.js|*.ts) ;;
  *) exit 0 ;;
esac
# ③ **세션당** 한 번. 매 Write 마다 뜨면 3회 거절로 조용히 죽는다.
# 🟥 초판은 스탬프를 **날짜**로 잡았다 — 주석은 «세션당» 인데 구현은 «하루당» 이었고, 하루에 세션을
# 여럿 도는 환경(이 운영자가 그렇다)에서는 **첫 세션만 뜨고 나머지는 전부 침묵**한다. 내 레인도
# 못 잡았다: 디렉터리만 갈랐지 날짜 의미론을 안 쟀다. 훅 입력의 `session_id` 로 고친다.
# session_id 가 없으면(구버전·수동 호출) 날짜로 degrade — 침묵이 아니라 «덜 자주» 쪽이다.
# 🟥 `session_id` 는 **신뢰할 수 없는 입력**이다 (cross-family HIGH#5). 실측: `x/../../../name`
#    이 접두 검사를 통과해 프로젝트 밖에 파일을 만들었고, 끝에 `/` 를 붙이면 스탬프가 아예
#    안 써져 **매번 발화**했다(세션당 1회가 무력화). 화이트리스트로 좁힌다 — 빈 값이 되면
#    날짜로 degrade(침묵이 아니라 «덜 자주» 쪽).
_SID_SAFE=$(printf '%s' "${SID:-}" | tr -cd 'A-Za-z0-9_-')
STAMP="${CLAUDE_PROJECT_DIR:-.}/.claude/.prior_art_prompted_${_SID_SAFE:-$(date +%Y%m%d)}"

# ③-b 🟥 **세션당 1회로는 T2 를 구조적으로 못 잡는다** (실측 2026-08-22, 한 세션 전수 재생).
# 이 훅의 존재 이유는 이 파일 머리가 적어둔 «T2 = 컨텍스트가 길어진 뒤 **또** 새로 빌드업할 때» 인데,
# 스탬프가 세션 스코프면 그 «또» 가 영원히 억제된다. 한 세션(08:29~13:33)에서 새 메커니즘 3건이
# 08:38 · 13:06 · 13:07 에 났고, 세션당 1회는 **첫 건만** 띄웠다 — 억제된 둘이 정확히 T2 다.
# ⇒ 시간 재무장으로 바꾼다. 마지막 **발화** 시각에서 N초가 지나면 다시 무장한다.
#
# 🟥 N 은 임의로 골랐다. 이 값은 데이터가 정한 것이 아니다 — 같은 실측에서 **N=1h·2h·4h 가 전부
#    같은 결과(2 발화)** 를 냈다. 즉 **데이터가 N 을 판별하지 않았다**, n=1 세션이고, 그 세션의
#    간극이 4.5시간이라 임계에 둔감했을 뿐이다. §Mechanization Boundary 의 «오늘의 판단을 내일의
#    천장으로 굳히지 마라» 에 걸리는 자리라, 상수를 박는 대신 **아래 로그를 남겨서 다음 세션들이
#    실제 분포를 쌓게 한다.** N 재정은 그 로그 위에서만 해라 — 이 주석을 지우지 말고.
# 왜 «대상 파일당 1회» 가 아닌가: 같은 실측에서 13:06 `mapped_tracks.sh` 와 13:07 그 레인 스위트는
#    **한 메커니즘**이다. 파일당이면 13:07 이 같은 메커니즘을 재질문하는 **오발화**가 된다. 이 파일
#    머리가 «오발화는 미발화보다 훨씬 비싸다(소음 = 자기무력화 경로)» 라고 못박은 방향과 반대다.
PRIOR_ART_REARM_SECONDS="${PRIOR_ART_REARM_SECONDS:-7200}"   # 2h — 위 단락이 이 값의 출처이자 한계다

# 시계는 주입 가능하다 — 픽스처가 4.5시간을 실시간으로 기다릴 수는 없다. 테스트 시임일 뿐이고
# 억제를 **끄지는** 못한다(값을 넣어도 아래 산술을 그대로 통과해야 한다).
_NOW="${PRIOR_ART_NOW:-$(date +%s)}"
case "$_NOW" in ''|*[!0-9]*) _NOW=$(date +%s) ;; esac

_LAST=""
if [ -f "$STAMP" ]; then
  _LAST=$(cat "$STAMP" 2>/dev/null | tr -cd '0-9')
fi

# 로그. 🟥 발화만이 아니라 **억제도** 남긴다 — 「몇 건 억제」만 세면 그것이 옳은 억제였는지 못
# 가른다. 그래서 무엇을(파일명) · 직전 발화로부터 얼마나(초) 를 같이 적는다.
# 실패해도 판정은 안 바뀐다(로깅은 게이트가 아니다).
_PA_LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/.prior_art_events.tsv"
_pa_log() { # $1=FIRE|SUPPRESS  $2=elapsed-or-dash
  mkdir -p "$(dirname "$_PA_LOG")" 2>/dev/null || true
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" "$1" "${_SID_SAFE:-nosid}" "$2" "$FILE" \
    >> "$_PA_LOG" 2>/dev/null || true
}

if [ -n "$_LAST" ]; then
  _ELAPSED=$(( _NOW - _LAST ))
  if [ "$_ELAPSED" -lt "$PRIOR_ART_REARM_SECONDS" ]; then
    _pa_log SUPPRESS "$_ELAPSED"
    exit 0
  fi
  _pa_log FIRE "$_ELAPSED"
else
  _pa_log FIRE -
fi
mkdir -p "$(dirname "$STAMP")" 2>/dev/null || true
printf '%s\n' "$_NOW" > "$STAMP" 2>/dev/null || true

MSG="🔎 새 메커니즘을 쓰려는 참이다 ($(basename "$FILE")). 짓기 전에 **책장부터, 없으면 도서관** —
안 했으면 지금 하고, 했으면 이 줄은 무시해라.

  ① 책장    바로 옆에 있나. **여기가 대부분이다.**
            우리 안 : CATALOG.md · .claude/registry/ · plugins/**/SKILL.md · scripts/ 를 실제로 grep
            옆 칸   : LOCAL_SKILL_REGISTRY · scripts/cluster_capability_scan.sh · §Cross-Project Skill Bus
                     🟥 여기서 나오면 «찾아온 것» 이 아니라 **바로 호출 가능한 능력**이다
            🟥 «grep 0건» 을 «없다» 로 확정하지 마라 — 오늘 실측에서 세션 6/6 이 이 자리에서 틀렸다.
               내 어휘로만 두드렸을 가능성을 먼저 의심해라.

  ② 도서관  **책장에 없을 때만** 간다. 있는데 가면 그건 over-search 다(arXiv 2605.29796 이 명명한 실패모드).
            갈 때는 문제를 **일반 어휘로 이름 붙여서** — 내부 어휘로는 세계에 안 닿는다.
            경로: knowledge/shared/harness-core/deep_research_capability_ladder.md

  ③ 숙고    ①②를 놓고 갈랐나 — fh-commons:deliberation (제안→반론→종합)

  ④ 짓기    🟥 **탐색은 끝이 아니라 입력이다.** 찾았으면 거기서 멈추지 말고 **가진 능력을 100% 써서
            지어라** — 바깥이 푼 데이터 × 내부 오케스트레이션은 더해지는 게 아니라 **곱해진다**
            (arXiv 2607.06906 실측: 품질/달러 +82%, 백만토큰당 완수 54.9→92.0).
            합주 형식은 이미 있다: CLAUDE.md §Intent Marshaling.

안 밟은 칸이 있으면 한 줄로 물어라: «이 문제 이름이 X 같은데 확인해볼까?»
판정이 아니라 제안이다. 이미 밟았으면 진행해라 — 단, 진행할 때 **내부 능력을 덜 쓰지 마라.**"

if json_out=$(printf '%s' "$MSG" | PYTHONIOENCODING=utf-8 python3 -c '
import json,sys
h=sys.stdin.read()
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":h}}))
' 2>/dev/null) && [ -n "$json_out" ]; then
  printf '%s\n' "$json_out"; exit 0
fi
printf '%s\n' "$MSG" >&2
exit 0
