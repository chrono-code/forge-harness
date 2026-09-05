#!/usr/bin/env bash
# utterance_intake.sh — 전사본의 운영자 발화를 **자동으로** 프로브로 만들어 기록 착지를 검증한다.
#
# ── 왜 (진단, 2026-09-05) ────────────────────────────────────────────────────
# FH 의 «질문하기» 엔진은 external-grounding 엔진인데 **수용 절반이 산문이다**
# (`fh_three_layer_canon.md §2`: *"묻는 경로는 있고 들어온 통찰을 자산화하는 경로가 약하다"*).
# 계기는 이미 둘 다 있었다:
#     compaction_probe.sh seal        전사본 → 운영자 발화 축자 원장        (돈다)
#     utterance_landing_check.sh      probes.tsv → 기록 파일 grep          (돈다, 호출부 0)
# 그런데 **probes.tsv 를 만드는 기계가 없었다.** 손으로 짜야 하니 아무도 안 짰고,
# `session_close_check.sh` 어디에서도 두 번째가 호출되지 않았다(grep 0). 두 계기 사이의
# 한 칸이 비어 있어서 채널이 아니라 산문으로 남아 있던 것 — 이 스크립트가 그 칸이다.
#
# 실측 근거(같은 날): 운영자가 세션 중 던진 교리·설계급 발화 6 건이 착지한 경로는 전부
# **거버너의 손**이었다(signal 파일 2 · UAP 블록 2 · fh_completed). 기계는 한 건도 안 잡았다.
#
# ── 이 스크립트가 하는 것 / 안 하는 것 ──────────────────────────────────────
#   한다   : 발화 추출 → 키 낱말 프로브 생성 → 컨트롤 2 종 삽입 → 착지 검증 → 미착지 목록
#   안 한다: 기록을 **쓰지 않는다.** 무엇을 어디에 적을지는 판단이고, 판단을 코드로 굳히면
#            그게 천장이 된다(`CLAUDE.md §Mechanization Boundary`). 이건 «채널이 값을
#            나르는가» 만 본다 — «그 값이 옳은가» 는 사람 몫이다.
#
# ── 🟥 명명된 잔여 셋. 인용하기 전에 읽어라 ─────────────────────────────────
# ⓐ **이름표는 측정이 아니다** — 프로브는 «키 낱말» 이라서, 기록이 같은 뜻을 **다른 낱말로**
#    적었으면 착지했는데 미착지로 뜬다. 상속: `utterance_landing_check.sh` 헤더의
#    *"rc=1 은 «기록하라»가 아니라 «확인하라»로 읽어야 한다"*. 이 방향은 **과차단이라 안전**하다.
# ⓑ **토큰마다 한 행, 발화는 과반으로 판정한다.** 초판은 한 행 `(낱말1|낱말2|낱말3)` 이라
#    **하나만 겹쳐도** 착지였다 — 같은 주제어 하나(«쿠버네티스»)가 든 기록이 정책 발화를 «착지»
#    로 렌더했다(cross-family codex, 2026-09-05). 이제 발화의 최장 토큰(≤3)을 **각각 한 행**으로
#    내고, 발화는 착지 행이 ⌈n/2⌉ 이상일 때만 착지다(3 키 → 2 · 2 키 → 1 · 1 키 → 1).
#    🟥 남은 fail-open: 키가 2 개뿐인 발화는 여전히 하나만 겹쳐도 착지다(OR). rc=0 은 여전히
#    «제대로 적혔다» 의 증명이 아니다. 발화 단위 계상은 map 의 n_keys 로 이 스크립트가 집계한다.
# ⓒ **advisory 다** — `session_close_check.sh ①-f` 는 이걸 차단으로 쓰지 않는다. 노출 사다리
#    (`fh_three_layer_canon §1-a-2 ⓔ` shadow) 로 몇 세션 관찰한 뒤 승격 여부는 운영자 결정.
#
# ── 컨트롤 두 종 (한 종이 아니다) ───────────────────────────────────────────
# `utterance_landing_check.sh` 의 CONTROL 은 **양성만** 있다 — 「계기가 죽었나」는 재고
# 「계기가 아무거나 다 잡나」는 못 잰다(`[[feedback_control_presence_is_not_discrimination]]`).
#   POSITIVE  **기록 내용에서 뽑은 최장 토큰.** 거기 실제로 있으니 정의상 잡혀야 하고,
#             안 잡히면 파이프라인이 죽은 것이다(word-split · 경로 · 인코딩) → rc=10.
#             🟥 초판은 «오늘 날짜» 였는데 **날짜는 파일명에 있지 내용에 있을 의무가 없다** —
#             그러면 정상 마감마다 거짓 경보가 뜬다. 실측 근거는 아래 `_control_rows` 주석.
#             날짜는 «있을 때만» 보조 컨트롤로 더한다.
#   NEGATIVE  무작위 토큰 — **없어야 마땅하다.** 잡히면 계기가 아무거나 잡는 것이므로 역시 rc=10
# NEGATIVE 는 이 래퍼가 직접 검사한다(하위 도구가 모르는 종류라 그 행은 무시하고 지나간다).
#
# ── 사용 ────────────────────────────────────────────────────────────────────
#   bash scripts/utterance_intake.sh <transcript.jsonl> <record-file> [<record-file>...]
#   env:
#     FH_INTAKE_MIN_CHARS    기본 20 — 아래 §문턱 참조
#     FH_INTAKE_NEG_TOKEN    음성 컨트롤 토큰 고정(레인용). 미설정이면 매 실행 무작위
#     FH_INTAKE_DUMP_PROBES  생성된 probes.tsv 를 이 경로로도 남긴다(레인/디버그용)
#
# ── §문턱: 왜 40 이 아니라 20 인가 (실측 2026-09-05) ────────────────────────
# 이 레포 전사본 전수 3191 발화(봉투·툴결과 제외)의 길이 분포:
#     00-09  524  ·  10-19  329  ·  20-29  284  ·  30-39  187  ·  40+  1867
# 30–39 구간 표본에 하중 지는 발화가 산다 — «그리고 입장리뷰는 정적 동적 모두 수행해야해» ·
# «4는 초록으로 올리도록 하자». 한글은 자당 정보량이 커서 **40 자 바닥은 교리 발화를 조용히
# 버린다**(위험한 방향). 20 = 853 제외 · 2338 보존. 과포함은 소음(안전), 과소포함은 무음 손실.
#
# ── 종료코드 ────────────────────────────────────────────────────────────────
#   0   전건 착지            1   미착지 있음 (목록 인쇄)
#  10   HARNESS-ERROR / UNMEASURED — **PASS 도 FAIL 도 아니다**
#       (전사본 부재 · 추출 발화 0 · 기록 파일 0 · 컨트롤 사망 · 프로브 오류 · rc↔목록 불일치)
#
# 이식성: bash 3.2 · 백틱 없음 · heredoc 은 함수 안 + 인용 구분자. python3 표준 라이브러리만.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTRACTOR="$REPO_ROOT/scripts/transcript_utterances.py"
LANDING="$REPO_ROOT/scripts/utterance_landing_check.sh"
MIN_CHARS="${FH_INTAKE_MIN_CHARS:-20}"

_die10() { echo "$1"; exit 10; }

# 🟥 `grep -c x f || echo 0` 은 무매치일 때 «0» 을 **두 번** 낸다 — grep 이 0 을 찍고 rc=1 을
#    내므로 폴백까지 붙는다. `[ "0\n0" -eq 0 ]` 은 «integer expression expected» 로 죽고,
#    그 죽음이 계기 사망으로 렌더된다(레인이 L1/L4b/L8b 에서 잡았다).
#    `[[feedback_pipefail_fallback_disarms_guard]]` 의 사촌 — 폴백이 값을 오염시키는 형태.
_num() { case "${1:-}" in ''|*[!0-9]*) echo 0 ;; *) printf '%s' "$1" ;; esac; }

# ── 양성 컨트롤 ───────────────────────────────────────────
# 🟥 초판은 «오늘 날짜» 를 양성 컨트롤로 썼다 — «오늘자 기록 파일에는 오늘 날짜가
#    반드시 있다» 는 가정이었고, **거짓이다.** 날짜는 파일명에 있지 내용에 있을 의무가 없다.
#    실측(2026-09-05 sim): 플로어 티어 세션이 만든 `fh_completed_2026-09-05.md` 내용은
#    «- ✅ 계기 확인 — 클론 안 쓰기 가능» 한 줄뿐이다. 그러면 컨트롤이 죽어 rc=10 이 나고,
#    정상 마감에 거짓 경보가 뜬다 — 그것이 바로 스키밍을 훈련시키는 소음이다.
#    ⇒ 컨트롤을 **기록 내용에서 뽑는다**: 거기 실제로 있는 긴 토큰은 정의상 잡혀야 하므로,
#    안 잡히면 **파이프라인이 죽은 것**(word-split · 경로 · 인코딩)이다 — 원래 재려던 바로 그 실패다.
#    날짜는 «있을 때만» 두 번째 컨트롤로 더한다(있으면 더 강하고, 없어도 치명적이지 않다).
_control_rows() {  # $1=오늘날짜  $2=스크래치  $3...=기록 파일들
  local _today="$1" _scratch="$2"; shift 2
  local _py="$_scratch/mkcontrol.py"
  cat > "$_py" <<'CTLPY'
import re, sys

today = sys.argv[1]
best = ''
seen_today = False
for path in sys.argv[2:]:
    try:
        txt = open(path, errors='replace').read()
    except OSError:
        continue
    # degrade-scan C2(substring-boolean) 대응: 이 포함검사는 **가산적**이다 — 맞으면 보조
    # 컨트롤이 하나 늘고, 틀리면 안 늘 뿐이다. 하중은 아래 `best`(파생 컨트롤)가 진다.
    # 어느 방향으로 틀려도 PASS 로 기울지 않으므로 정확 일치로 좁힐 이유가 없다.
    if today in txt:  # noqa: degrade — additive only: ADDS a secondary control row, never grounds a verdict
        seen_today = True
    for tok in re.findall(r'[\uac00-\ud7a3]{4,}|[A-Za-z0-9_]{5,}', txt):
        if len(tok) > len(best):
            best = tok
if best:
    print("CONTROL\t%s\t기록파생(양성컨트롤)" % best)
if seen_today:
    print("CONTROL\t%s\t오늘날짜(보조컨트롤)" % today)
CTLPY
  python3 "$_py" "$_today" "$@"
}

# ── 키 낱말 프로브 생성 ──────────────────────────────────────────────────────
# 한글/영숫자 토큰 중 **가장 긴** 것 3 개. 조사를 벗기고, 불용어와 짧은 토큰을 뺀다.
# 정규식 메타문자가 섞이지 않도록 토큰 문자군을 [\uac00-\ud7a3]·[A-Za-z0-9_] 로 **닫아 둔다** —
# `.` `-` 를 허용하면 ERE 에서 각각 와일드카드/범위로 새고, 이스케이프를 손으로 하는 순간
# 「관대함 갈린 중복 정규화」가 시작된다.
# 🟥 `python3 - <<'PY'` 를 쓰면 **heredoc 이 python 의 stdin 이 되어** 발화 tsv 가 통째로
#    안 읽힌다(첫 판본이 그랬고, 레인 L4b 가 « TARGET 0 건 » 으로 잡았다). 프로그램은 파일로
#    떨어뜨리고 stdin 은 호출부의 리다이렉트가 그대로 나르게 둔다.
_build_probes() {  # stdin: n<TAB>ts<TAB>text   stdout: probes rows   $1=map 경로  $2=스크래치 디렉터리
  local _py="$2/mkprobes.py"
  cat > "$_py" <<'PY'
import os, re, sys

MAP = open(sys.argv[1], 'w')

# 🟥 사설 토큰 마스킹 — **토큰화 전에** 한다. 이 출력은 마감 화면에 찍히고 사람이 카드에
#    붙여넣는다. 첫 실사용(2026-09-05)에서 실제로 `[Image: source: /var/folders/3h/…]` 가
#    라벨로 나왔다 — 머신 고유 임시경로다. 마스킹을 라벨에만 걸면 키 낱말 쪽으로 새므로
#    (사용자명 같은 것이 그대로 토큰이 된다) 앞단에서 지운다.
# 🟥 한글 범위를 `[\uac00-\ud7a3]` 로 적는다 — `[가-힣]` 과 **의미는 같지만**
#    (파이썬 `re` 에서 동치, known-pair 로 확인), 이 파일은 `.sh` 라
#    `test_card_drift_probe.sh` 의 locale-range 린트가 스캔한다. 그 린트는 셸의 `grep` 을
#    겨냥한 것이고(C 로케일에서 비ASCII 범위는 exit 2 → «무매치» 로 읽힌다), heredoc 안의
#    python 인지 구분하지 못한다. 린트를 끄는 대신 **표기를 바꾼다** — 로케일 함정에 대한
#    그 경계는 살아 있어야 한다.
#    (`transcript_utterances.py` 는 `.sh` 가 아니라 스캔 대상이 아니므로 가독성 표기를 쓴다.)
_HOME = os.environ.get('HOME', '')
_TMP_RE = re.compile(r'/(?:var/folders|private/var/folders)/[^\s\]\)]*')


_PATH_RE = re.compile(r'(?<![\w])/(?:[\w.@+-]+/)+[\w.@+-]*')          # any absolute path, 2+ segments
_KV_RE   = re.compile(r'\b([A-Z][A-Z0-9_]{2,})=[^\s]+')                 # KEY=value → KEY=<v>
_HOST_RE = re.compile(r'\b[a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:internal|local|corp|lan|intra)\b')
def mask(t):
    # Labels and probe tokens are an OUTPUT surface (close-check stdout, pasted into cards) — so
    # the masking is not "the operator's own paths" but every absolute path, every KEY=value and
    # every host-like name (codex finding 5, 2026-09-05). The suffix list is a small frozen
    # judgment; it fails loud (an unmasked host shows up in a label), not silent.
    t = _TMP_RE.sub('<tmp>', t)
    if _HOME and len(_HOME) > 4:
        t = t.replace(_HOME, '$HOME')
    t = _PATH_RE.sub('<path>', t)
    t = _KV_RE.sub(r'\1=<v>', t)
    t = _HOST_RE.sub('<host>', t)
    return t

# 조사/어미 — 토큰 끝에서 벗긴다. 긴 것부터 시도한다(짧은 게 먼저 맞으면 덜 벗겨진다).
PARTICLES = ['으로는', '에서는', '에게는', '이라고', '으로도', '까지는', '부터는',
             '으로', '에서', '에게', '한테', '처럼', '보다', '라고', '하고', '까지',
             '부터', '이나', '든지', '마다', '조차', '밖에', '이란', '이든',
             '은', '는', '이', '가', '을', '를', '에', '의', '로', '도', '만', '과', '와']

# 불용어 — 이 코퍼스에서 흔해서 «우연 일치» 를 만드는 것들. OR 결합이라 여기가 fail-open 의
# 주된 입구다(§명명된 잔여 ⓑ). 길이 규칙만으로는 안 걸러진다.
STOP = set('''그리고 그러니까 그래서 그러면 그런데 이렇게 그렇게 어떻게 하지만 그러나
마찬가지 이야기 생각 경우 부분 내용 확인 진행 작업 파일 세션 지금 다음 이번 정도
사람 방법 이유 상태 결과 문제 대해 위해 통해 우리 너는 나는 것을 것이 거기 여기 저기
해줘 하자 하는 되는 있는 없는 같은 같이 좋은 다시 먼저 아직 이제 조금 그냥 바로
this that with from have been will your about would should could there which their
path host tmp home HOME
then than when what where because those these into over under more most only just'''.split())

def strip_particle(tok):
    if not re.match(r'^[\uac00-\ud7a3]+$', tok):
        return tok
    for p in PARTICLES:
        if tok.endswith(p) and len(tok) - len(p) >= 2:
            return tok[:-len(p)]
    return tok

n_rows = 0
n_unprobeable = 0
for line in sys.stdin:
    line = line.rstrip('\n')
    if not line:
        continue
    parts = line.split('\t', 2)
    if len(parts) < 3:
        continue
    idx, _ts, text = parts
    text = mask(text)
    toks = re.findall(r'[\uac00-\ud7a3]+|[A-Za-z0-9_]+', text)
    cand = []
    seen = set()
    for t in toks:
        s = strip_particle(t)
        if s in seen or s in STOP or s.lower() in STOP:
            continue
        if re.match(r'^[\uac00-\ud7a3]+$', s):
            if len(s) < 3:
                continue
        else:
            if len(s) < 4 or s.isdigit():
                continue
        seen.add(s)
        cand.append(s)
    # 가장 긴 것부터 3 개. 동률은 먼저 나온 것(발화 앞쪽이 대개 주제어).
    cand.sort(key=lambda s: -len(s))
    keys = cand[:3]
    if not keys:
        # 프로브를 만들 수 없는 발화 — **버리지 않고 센다**(not found != 0).
        n_unprobeable += 1
        MAP.write("%s\tUNPROBEABLE\t%s\t0\n" % (idx, text[:60]))
        continue
    label = "#%s %s" % (idx, text[:40])
    # One TARGET row per key: `#<idx>.<k>/<n> <text>` — the wrapper re-aggregates per utterance
    # (codex finding 1). Keys are bare tokens ([가-힣]+ / [A-Za-z0-9_]+): no ERE metacharacters,
    # never dash-first, so the landing checker reads them as literals.
    for k_i, key in enumerate(keys, 1):
        print("TARGET\t%s\t#%s.%d/%d %s" % (key, idx, k_i, len(keys), text[:36]))
    MAP.write("%s\t%s\t%s\t%d\n" % (idx, label, text[:60], len(keys)))
    n_rows += 1
MAP.close()
sys.stderr.write("probe utterances=%d · 프로브불가=%d\n" % (n_rows, n_unprobeable))
PY
  python3 "$_py" "$1"
}

# ── 인자 ────────────────────────────────────────────────────────────────────
if [ "$#" -lt 2 ]; then
  echo "usage: $0 <transcript.jsonl> <record-file> [<record-file>...]" >&2
  exit 10
fi
TRANSCRIPT="$1"; shift
RECORDS=()                       # 배열 — zsh word-split 에 의존하지 않는다
MISSING_RECORDS=0
for f in "$@"; do
  if [ -f "$f" ]; then RECORDS+=("$f"); else MISSING_RECORDS=$((MISSING_RECORDS+1)); fi
done

[ -f "$EXTRACTOR" ] || _die10 "🟥 HARNESS-ERROR: 추출기 없음: $EXTRACTOR"
[ -f "$LANDING" ]   || _die10 "🟥 HARNESS-ERROR: 착지 검사기 없음: $LANDING"

if [ ! -f "$TRANSCRIPT" ]; then
  echo "ℹ️  UNMEASURED — 전사본 부재: $TRANSCRIPT"
  # 🟥 성공 판정 리터럴(«전부 착지»)을 **부정문 안에도** 쓰지 마라 — grep 하는 쪽이
  #    성공으로 읽는다(Grep-Collision Treadmill). 레인 L7c 가 실제로 그렇게 오독했다.
  echo "    부재를 0 으로 접지 마라 — 발화가 없었다는 뜻도, 다 적혔다는 뜻도 아니다."
  exit 10
fi
if [ "${#RECORDS[@]}" -eq 0 ]; then
  echo "ℹ️  UNMEASURED — 검사할 기록 파일이 하나도 없다 (인자 $# 건 중 $MISSING_RECORDS 건 부재)"
  echo "    기록이 없는 것과 발화가 안 적힌 것은 다른 명제다."
  exit 10
fi

WORK="$(mktemp -d 2>/dev/null)" || _die10 "🟥 HARNESS-ERROR: mktemp -d 실패 (환경 부재이지 계기 결함이 아니다)"
trap 'rm -rf "$WORK"' EXIT INT TERM

# ── 1. 발화 추출 ────────────────────────────────────────────────────────────
# `--strip-system-markers`: peer 알림 · 무인 실행 · 이미지 마커는 **운영자 발화가 아니다**.
# seal 은 이 플래그를 안 주므로 기존 원장 출력은 그대로다(레인 L10 골든이 그걸 고정한다).
python3 "$EXTRACTOR" "$TRANSCRIPT" --min-chars "$MIN_CHARS" --strip-system-markers \
  > "$WORK/utts.tsv" 2> "$WORK/extract.err"
_erc=$?
if [ "$_erc" -ne 0 ]; then
  echo "🟥 HARNESS-ERROR: 발화 추출 실패 (rc=$_erc)"; sed 's/^/    /' "$WORK/extract.err"; exit 10
fi
N_UTT=$(_num "$(grep -c . "$WORK/utts.tsv" 2>/dev/null)")
if [ "${N_UTT:-0}" -eq 0 ]; then
  echo "ℹ️  UNMEASURED — 추출된 발화 0 건 (min-chars=$MIN_CHARS)"
  sed 's/^/    /' "$WORK/extract.err"
  echo "    빈 프로브 세트는 합격이 아니다 — «아무것도 안 쟀다» 다."
  exit 10
fi

# ── 2. 프로브 생성 (컨트롤 2 종 먼저) ───────────────────────────────────────
TODAY="$(date +%Y-%m-%d)"
NEG_TOKEN="${FH_INTAKE_NEG_TOKEN:-}"
if [ -z "$NEG_TOKEN" ]; then
  # 무작위. `date +%N` 은 BSD 에 없으므로 쓰지 않는다.
  NEG_TOKEN="FHNEG$(od -An -N6 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' | tr 'a-f' 'A-F')"
  case "$NEG_TOKEN" in FHNEG) NEG_TOKEN="FHNEG$$X$(date +%s)" ;; esac
fi
{
  _control_rows "$TODAY" "$WORK" "${RECORDS[@]}"
  printf 'NEGATIVE\t%s\t무작위토큰(음성컨트롤)\n' "$NEG_TOKEN"
} > "$WORK/probes.tsv"
_build_probes "$WORK/probes.map" "$WORK" < "$WORK/utts.tsv" >> "$WORK/probes.tsv" 2> "$WORK/build.err"
[ -n "${FH_INTAKE_DUMP_PROBES:-}" ] && cp "$WORK/probes.tsv" "$FH_INTAKE_DUMP_PROBES" 2>/dev/null
N_TARGET=$(_num "$(grep -c "^TARGET$(printf '\t')" "$WORK/probes.tsv" 2>/dev/null)")
N_PROBED=$(_num "$(LC_ALL=C awk -F'\t' '$2!="UNPROBEABLE"' "$WORK/probes.map" 2>/dev/null | grep -c .)")
UNPROBE=$(_num "$(LC_ALL=C awk -F'\t' '$2=="UNPROBEABLE"' "$WORK/probes.map" 2>/dev/null | grep -c .)")
if [ "${N_TARGET:-0}" -eq 0 ]; then
  echo "ℹ️  UNMEASURED — 발화 $N_UTT 건에서 프로브를 하나도 못 만들었다"
  sed 's/^/    /' "$WORK/build.err"
  exit 10
fi
# 양성 컨트롤이 하나도 안 나왔으면(기록이 짧아 4자+ 한글 / 5자+ 영숫자 토큰이 없다) 계기를 돌리지
# 않는다 — 착지 검사기도 CONTROL 부재에 rc=10 을 내지만, 그 메시지는 «계기 사망» 이고 여기 원인은
# «컨트롤을 만들 재료가 없다» 라 다르다(codex finding 7). 둘 다 UNMEASURED 다.
N_CTL=$(_num "$(grep -c "^CONTROL$(printf '\t')" "$WORK/probes.tsv" 2>/dev/null)")
if [ "${N_CTL:-0}" -eq 0 ]; then
  echo "ℹ️  UNMEASURED — 기록에서 양성 컨트롤 토큰을 못 뽑았다(4자+ 한글 · 5자+ 영숫자 토큰 부재, 오늘 날짜도 없음)"
  echo "    컨트롤 없는 착지 판정은 근거가 아니다 — 기록이 너무 짧다."
  exit 10
fi

# ── 3. 음성 컨트롤 — 하위 도구가 모르는 종류라 여기서 검사한다 ─────────────
# `grep -F` : 토큰을 리터럴로 본다. 정규식으로 해석되면 «없어야 할 것» 의 의미가 바뀐다.
if grep -qF -- "$NEG_TOKEN" "${RECORDS[@]}" 2>/dev/null; then
  echo "🟥 HARNESS-ERROR: 음성 컨트롤이 기록에서 잡혔다 — [$NEG_TOKEN]"
  echo "    없어야 마땅한 토큰이 잡힌다 = 계기가 아무거나 잡고 있다. 타깃 결과는 인쇄하지 않는다."
  exit 10
fi

# ── 4. 착지 검증 (양성 컨트롤은 하위 도구가 본다) ───────────────────────────
LAND_OUT="$WORK/land.txt"
bash "$LANDING" "$WORK/probes.tsv" "${RECORDS[@]}" > "$LAND_OUT" 2>&1
LRC=$?

# 🟥 판정은 **종료코드**로 낸다. 아래 파싱은 «사람이 읽을 목록» 을 만들 뿐이고, 둘이 어긋나면
#    그 자체가 신호다(`[[feedback_summary_parsing_hides_failure]]` · 두 신호의 어긋남).
ROW_MISS=$(_num "$(grep -c '미착지$' "$LAND_OUT" 2>/dev/null)")
# 발화 단위 집계 — 행(토큰)의 착지/미착지를 `#idx.k/n` 라벨로 발화에 되돌리고, ⌈n/2⌉ 이상 착지면
# 그 발화는 착지다. 출력: LANDED / UNLANDED 개수 + 미착지 발화 idx 목록.
_AGG="$WORK/agg.py"
cat > "$_AGG" <<'AGGPY'
import re, sys
land, mapf = sys.argv[1], sys.argv[2]
n_keys = {}
for line in open(mapf, errors='replace'):
    parts = line.rstrip('\n').split('\t')
    if len(parts) >= 4 and parts[1] != 'UNPROBEABLE':
        n_keys[parts[0]] = int(parts[3])
hits = {}
row_re = re.compile(r'^\s*(✅|🟥)\s+#(\d+)\.(\d+)/(\d+)\s')
for line in open(land, errors='replace'):
    m = row_re.match(line)
    if not m:
        continue
    idx = m.group(2)
    n_keys.setdefault(idx, int(m.group(4)))
    if m.group(1) == '✅':
        hits[idx] = hits.get(idx, 0) + 1
landed, unlanded = [], []
for idx in sorted(n_keys, key=int):
    n = n_keys[idx]
    need = (n + 1) // 2
    (landed if hits.get(idx, 0) >= need else unlanded).append(idx)
print("LANDED=%d" % len(landed))
print("UNLANDED=%d" % len(unlanded))
print("UNLANDED_IDX=%s" % " ".join(unlanded))
AGGPY
_AGG_OUT="$(python3 "$_AGG" "$LAND_OUT" "$WORK/probes.map" 2>/dev/null)"
HIT_N=$(_num "$(printf '%s\n' "$_AGG_OUT" | sed -n 's/^LANDED=//p')")
MISS_N=$(_num "$(printf '%s\n' "$_AGG_OUT" | sed -n 's/^UNLANDED=//p')")
MISS_IDX="$(printf '%s\n' "$_AGG_OUT" | sed -n 's/^UNLANDED_IDX=//p')"

echo "── 발화 착지 검사 ──"
echo "   전사본   : $TRANSCRIPT"
echo "   기록 대상: ${#RECORDS[@]} 파일$([ "$MISSING_RECORDS" -gt 0 ] && printf ' (부재 %s 건 제외)' "$MISSING_RECORDS")"
echo "   추출     : 발화 $N_UTT 건 (min-chars=$MIN_CHARS) → 프로브 발화 $N_PROBED 건 (토큰 행 $N_TARGET) · 프로브불가 $UNPROBE 건"
sed 's/^/   /' "$WORK/build.err" 2>/dev/null
sed 's/^/   /' "$WORK/extract.err" 2>/dev/null

case "$LRC" in
  10)
    echo
    sed 's/^/   /' "$LAND_OUT"
    echo "   🟥 계기 사망 — 착지 판정을 내지 않는다(죽은 계기의 출력은 데이터가 아니다)."
    exit 10 ;;
esac

if [ "$LRC" -eq 0 ] && [ "$ROW_MISS" -ne 0 ]; then
  echo "🟥 HARNESS-ERROR: rc=0 인데 미착지 행이 $ROW_MISS 개 — 두 신호가 어긋난다. 원문:"
  sed 's/^/   /' "$LAND_OUT"; exit 10
fi
if [ "$LRC" -eq 1 ] && [ "$ROW_MISS" -eq 0 ]; then
  echo "🟥 HARNESS-ERROR: rc=1 인데 미착지 행이 0 개 — 두 신호가 어긋난다. 원문:"
  sed 's/^/   /' "$LAND_OUT"; exit 10
fi
if [ $((HIT_N + MISS_N)) -ne "$N_PROBED" ]; then
  echo "🟥 HARNESS-ERROR: 발화 집계 $HIT_N+$MISS_N ≠ 프로브 발화 $N_PROBED — 집계기가 행을 잃었다. 원문:"
  sed 's/^/   /' "$LAND_OUT"; exit 10
fi

echo "   착지 $HIT_N · 미착지 $MISS_N · 프로브불가 $UNPROBE   (행: 착지 $((N_TARGET - ROW_MISS)) · 미착지 $ROW_MISS · 판정 = 발화 토큰 ⌈n/2⌉ 이상)"
if [ "$MISS_N" -gt 0 ]; then
  echo
  echo "   미착지 목록 (발화 앞 60자):"
  # 라벨의 `#<n>` 으로 map 을 되짚는다. 숫자 비교라 비ASCII 동등성 함정에 안 걸린다
  # (`[[feedback_locale_string_equality_breaks_nonascii]]`).
  for _k in $MISS_IDX; do
    LC_ALL=C awk -F'\t' -v k="$_k" '$1==k{printf "     · %s\n", $3}' "$WORK/probes.map"
  done
fi
# 프로브불가 발화는 «못 쟀다» 지 «착지» 가 아니다 — 미착지와 별개로 세되 rc 에는 같이 든다
# (codex finding 2: MISS_N=0 이면 조용히 rc=0 이던 것을 닫음). 사람이 확인할 목록으로 낸다.
if [ "${UNPROBE:-0}" -gt 0 ]; then
  echo
  echo "   프로브불가 $UNPROBE 건 (키 낱말을 못 뽑은 발화 — 미측정, 착지 아님. 눈으로 확인):"
  LC_ALL=C awk -F'\t' '$2=="UNPROBEABLE"{printf "     · %s\n", $3}' "$WORK/probes.map"
fi
if [ "$MISS_N" -gt 0 ] || [ "${UNPROBE:-0}" -gt 0 ]; then
  echo
  echo "   ⚠️ rc=1 은 «기록하라» 가 아니라 «확인하라» 다 — 프로브 노후가 첫 번째 의심 대상이다."
  echo "      가장 잘 빠지는 것은 잊은 발화가 아니라 **행동으로 대응한 발화**다."
  exit 1
fi
echo "   ✅ 프로브 발화 $N_PROBED 건 전부 착지 (발화별 최장 토큰 ≤3 중 ⌈n/2⌉ 이상 일치)"
echo "   ⚠️ 키 2 개 이하 발화는 하나만 겹쳐도 착지다 — «제대로 적혔다» 의 증명이 아니다."
exit 0
