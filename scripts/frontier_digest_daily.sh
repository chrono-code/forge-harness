#!/bin/bash
# frontier_digest_daily.sh — Daily frontier-digest runner for forge-harness
# Invoked by launchd (install: see scripts/com.forge-harness.frontier-digest.plist)
#
# Required: claude CLI at ~/.local/bin/claude
# Tool permissions: pre-approved in .claude/settings.json (no interactive prompts needed)

# Auto-detect repo root from this script's location (scripts/ → repo root) and the claude CLI.
# 🟥 **엔진 루트와 대상 루트는 다르다** (R6, 2026-08-18 — 첫 실사용 발견). 위성은 이 스크립트를
#    복사하지 않고 **FH 의 것을 그대로** 돌린다(launchd 가 FH 경로를 가리킨다). 그런데 초판은
#    스캐너·패턴·checker 를 전부 `$FH_DIR`(= **대상 레포**)에서 찾았다 ⇒ forge-wiki 에는
#    `scripts/psa_scan_lib.sh` 가 없으므로 **publish gate 가 영영 fail-closed** 였다.
#    실측: 위성 설정 그대로 돌리면 `🚫 publish gate: psa_scan_lib.sh 부재 — fail-closed` (rc=3).
#    ⇒ **도구는 언제나 이 스크립트 옆에**, 대상만 env 로 바뀐다(`digest_landing_check.sh` 가
#      같은 이유로 `SELF_DIR` 과 `FH` 를 이미 갈라 놨다 — 그 교훈을 여기 옮긴다).
ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FH_DIR="${FD_FH_DIR:-$ENGINE_DIR}"
# FD_* env 오버라이드: 재현 하네스(test_frontier_digest_retry.sh)가 스텁/짧은 타임아웃을
# 주입하기 위한 것. 미설정 시 기본값 그대로 — 프로덕션 경로 무변.
CLAUDE_BIN="${FD_CLAUDE_BIN:-$(command -v claude || echo "${HOME}/.local/bin/claude")}"
TODAY=$(date +%Y_%m_%d)
HUMAN_DATE=$(date +%Y-%m-%d)   # pinned once with TODAY — a wake-fired run crossing midnight must not drift (filename date ≠ prompt date)
# ── 위성 축 (2026-08-18, 원정 2차) ──────────────────────────────────────────
# 정체성 ④ 「프런티어→조직 전파」의 조직 = **레포**다(운영자 정의). 이 러너는 FH 한 곳만
# 대상으로 지어졌고, 그래서 ④ 는 «자기 소비»에 머물렀다. 아래 두 변수가 대상 축이다.
#   FD_FH_DIR   — 어느 레포에서 도는가 (기존)
#   FD_OUT_DIR  — 그 레포의 **어디에** 떨어뜨리는가 (신설). FH 는 tracks/_meta 지만
#                 대상 하네스는 자기 문법이 있다(forge-wiki 는 frontmatter 달린 위키 노드).
#   FD_MODEL    — 어느 티어로 도는가 (신설). 위성마다 도메인 난이도가 다르다.
#   FD_LOG_DIR  — 로그를 어디에 파는가 (R2). 공개 대상이면 기본값이 **대상 트리 밖**이다.
#   FD_LANDING_{TRACKED,IGNORED,CONTROLS} — 착지 증언의 스코프·컨트롤 (R1). 미설정이면
#                 checker 기본값(= FH 문법 + 레포명 컨트롤) 그대로.
# 🟥 기본값은 **전부 종전 그대로**다 — FH 프로덕션 경로 무변경.
OUT_DIR="${FD_OUT_DIR:-tracks/_meta}"          # FH_DIR 기준 상대경로
# FD_PROFILE — 대상 하네스가 **자기를 설명하는** 파일(FH_DIR 기준 상대경로).
# 🟥 이게 없으면 위성은 «프런티어 신호 목록»을 남의 폴더에 복사한다 — 실측 2026-08-18:
#   FD_OUT_DIR 만 옮긴 런의 산출물이 "signals relevant to forge-harness (FH) operations" 였다
#   (대상 어휘 0히트 · FH 어휘 11히트 · frontmatter 0). 파이프는 관통했으나 **복제**였다.
# 운영자 정의: *"프런티어 동향을 파악해서 그 하네스에 개선할 포인트를 찾아 남기는 것 —
#   복제가 아니라 **응용**"* ⇒ 대상 축은 «어디에 쓰나»만이 아니라 «누구를 위해 읽나»다.
PROFILE_PATH="${FD_PROFILE:-}"
# ── R2 (2026-08-18) · 로그는 **공개 대상 트리 밖**에 판다 ───────────────────
# `FD_PUBLIC_TARGET=1` 은 «이 OUT_DIR 이 공개표면»이라는 선언인데 초판은 그 밑에 로그를 팠다.
# 스캐너 findings 는 **매치된 토큰 원문**을 찍고(`psa_scan_lib.sh`: `❌ $sev leak — path: 'tok'`)
# `publish_gate` 는 `-maxdepth 1 -name '*.md'` 만 보므로 그 로그는 **구조적으로 스캔 밖**이다.
# ⇒ 유출을 격리하면서 그 유출을 같은 공개 트리에 적는 형태였다. 내 위성 2대는 `logs/` 를
#   gitignore 해뒀지만 **코드가 그걸 보장하지 않는다** — 소비자가 당한다.
# 🟥 기본값은 종전 그대로(FH 는 tracks/ 가 gitignored 라 무변경). 공개 대상일 때만 밖으로.
if [ -n "${FD_LOG_DIR:-}" ]; then
    LOG_DIR="$FD_LOG_DIR"
elif [ "${FD_PUBLIC_TARGET:-0}" = "1" ]; then
    LOG_DIR="${HOME}/.cache/fh/frontier_digest/$(basename "$FH_DIR")"
else
    LOG_DIR="${FH_DIR}/${OUT_DIR}/logs"
fi
LOG_FILE="${LOG_DIR}/frontier_digest_${TODAY}.log"

mkdir -p "$LOG_DIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] frontier-digest daily run starting" >> "$LOG_FILE"

# Cap log accumulation (up to 3 attempts/day append full claude output into this dir)
find "$LOG_DIR" -name 'frontier_digest_*.log' -mtime +30 -delete 2>/dev/null

# Success = a non-trivial digest file exists. Mere existence is not enough: the dominant failure
# class is "connection closed mid-response", which can leave a partial/empty file — that must not
# count as done (it would also lock out every later run today via the skip-check below).
# 🟥 선택자는 **한 함수**다 (R3, 2026-08-18). 초판은 `digest_ready` 가 `-size +1k`,
# `publish_gate` 가 필터 없이 `head -1` 이었다 — 같은 날짜 파일이 둘이면 부산물이 CLEAN 을
# 내고 **진짜 다이제스트는 미스캔으로 게시**된다(두 계열 독립 수렴).
# 두 벌의 관대함이 갈리는 그 형태다([[feedback_divergent_leniency_duplicate_normalizers]]).
digest_files() {
    find "${FH_DIR}/${OUT_DIR}" -maxdepth 1 -name "frontier_digest_${TODAY}*.md" -size +1k 2>/dev/null
}

digest_ready() {
    digest_files | grep -q .
}

# ── 공개표면 게이트 (2026-08-18, 원정 2차) ──────────────────────────────────
# 위성이 **공개 레포**를 대상으로 돌면 **매 런이 publish** 다(비가역 표면). FH 자신은
# tracks/ 가 gitignored 라 이 문제가 없었고, 그래서 이 러너에 게이트가 없었다.
# §Irreversibility Surface-Class Degrade Invariant: 비가역 표면은 **fail-CLOSED** —
# 스캐너가 못 재면 «통과»가 아니라 «보류»다.
#
# 🟥 **성공 종료 경로가 셋이라 함수로 뺐다.** 초판은 attempt 루프의 성공 분기에만 달았고,
# 그러면 ⓐ「오늘 이미 돌았다」조기 스킵과 ⓑ「외부에서 나타났다」로 나가는 digest 가
# **스캔 없이 게시**된다. 레인 P2·P3 이 그 fail-open 을 잡았다.
#
# 🟥 rc 3값을 두 값으로 접지 않는다 — 0 게시 / 1 격리 / 그 외 보류. 스캐너는 자기 죽음을
#    rc=3(NOT SCANNED)으로 신고하므로 그 값을 존중한다.
# 🟥 findings 를 **원문 그대로 로그에 적지 않는다** (R2). 스캐너는 매치된 토큰을 인용부호로
# 찍는데, 그걸 그대로 남기면 «유출을 격리하면서 같은 자리에 유출을 복사»하는 꼴이다.
# 심각도·경로·패턴 히트 사실은 남기고 **토큰 본문만** 가린다 — 진단은 격리된 파일을 열어서.
# 🟥 초판은 `s/: '.*'$/…/` 로 **줄 끝의 인용부호만** 잡았다. 스캐너의 allowlist 줄은
#    `⚪ allowlisted — path: 'tok' (row: … :: …)` 이라 `)` 로 끝나서 **안 가려졌다** — 같은
#    함수가 잡아야 할 두 형태 중 하나만 잡는 상태였다(자체 격리 대조로 발견, 레인 R2c).
#    그래서 **줄 안의 모든 인용 스팬**을 가린다. 판정(심각도·경로)은 남고 페이로드만 사라진다.
# 🟥 두 번째 정정: 인용 스팬만 가려도 allowlist 줄의 `(row: f.md :: <토큰>)` 꼬리는 **인용
#    없이** 토큰을 또 적는다. 레인 R2c 가 그걸 잡았다(내 첫 수리는 절반이었다).
# 🟥 세 번째 정정 (cross-family/codex F2): 인용 스팬과 row 꼬리를 가려도 **경로 쪽**이 남는다.
#    스캐너 출력은 `❌ HIGH leak — <path>: '<tok>'` 이고, 모델이 저장한 **파일명 자체에** 토큰이
#    들어가면 그 왼쪽은 그대로 로그에 적힌다. 파일명은 우리가 프롬프트로 정하지만 **강제하지는
#    않는다** — 강제 안 되는 것을 안전 근거로 쓰지 않는다.
#  ⇒ 경로는 **정규 이름일 때만** 그대로 적고, 아니면 통째로 가린다. 진단 가치(어느 파일인지)는
#    정규 이름 케이스에서 유지되고, 비정규 이름은 «그 사실 자체»가 진단 정보가 된다.
_safe_name() {
    case "$(basename "$1")" in
        # 🟥 `[0-9_]*` 는 **너무 헐겁다** — 첫 글자만 검사하고 나머지는 `*` 가 다 삼킨다.
        #    `frontier_digest_2026_08_18-<토큰>.md` 가 정규 이름으로 통과했다(레인 R2d 가 잡음).
        #    날짜 자릿수를 **전부** 고정한다.
        frontier_digest_[0-9][0-9][0-9][0-9]_[0-9][0-9]_[0-9][0-9].md) basename "$1" ;;
        frontier_digest_[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md) basename "$1" ;;
        *) echo "[FILENAME REDACTED — 비정규 이름]" ;;
    esac
}
# 🟥 마지막 sed 는 **벨트 앤 브레이스**다: $2 없이 불리거나 치환이 빗나가면 절대경로가 남는데,
#    그 경로에는 운영자 실명(홈 디렉터리)이 들어 있다(타계열 실측이 `/Users/<이름>/…` 노출을
#    재현했다). 지금 호출부는 전부 2인자지만, **호출부가 옳다는 것을 안전 근거로 쓰지 않는다.**
_redact() { # $1 = 출력 · $2 = (선택) 그 출력이 가리키는 실제 경로
    local body="$1" path="${2:-}"
    if [ -n "$path" ]; then
        body="${body//$path/$(_safe_name "$path")}"
        body="${body//$(basename "$path")/$(_safe_name "$path")}"
    fi
    printf '%s\n' "$body" \
      | sed -e "s/'[^']*'/'[REDACTED — 격리 파일을 열어라]'/g" \
            -e "s/(row:[^)]*)/(row: [REDACTED])/g" \
            -e "s#— /[^ :]*:#— [PATH REDACTED]:#g"
}

publish_gate() {
    [ "${FD_PUBLIC_TARGET:-0}" = "1" ] || return 0
    local lib="${ENGINE_DIR}/scripts/psa_scan_lib.sh"
    # 🟥 초판은 여기서 «게시 안 함» 이라 적고 **파일은 그대로 뒀다** — 그 시점에 digest 는 이미
    #    공개 트리에 쓰여 있으므로 그 문장이 **거짓**이었다. 다른 NOT-SCANNED 경로와 같이 격리한다.
    if [ ! -f "$lib" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚫 publish gate: psa_scan_lib.sh 부재 — fail-closed, 격리" >> "$LOG_FILE"
        local q; while IFS= read -r q; do
            [ -n "$q" ] || continue
            mv "$q" "${q}.UNSCANNED" 2>/dev/null
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]   격리: $(_safe_name "$q").UNSCANNED" >> "$LOG_FILE"
        done < <(digest_files)
        return 3
    fi
    local f out rc worst=0 n=0
    # 🟥 글롭 전 파일을 **순회**한다. 하나라도 비-0 이면 그 값을 물고 나간다(최악 우선:
    #    3 NOT-SCANNED > 2 LEAK > 0). 한 파일만 보고 나머지를 게시하면 fail-open 이다.
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        n=$((n+1))
        out=$(bash -c '. "$1"; psa_load "$2/.claude/rules/.public-surface-patterns.defaults" "$2/.claude/rules/.public-surface-patterns" >/dev/null 2>&1; psa_scan_file "$3"' _ "$lib" "$ENGINE_DIR" "$f" 2>&1)
        rc=$?
        case "$rc" in
            0) echo "[$(date '+%Y-%m-%d %H:%M:%S')] publish gate: CLEAN [$(_safe_name "$f")]" >> "$LOG_FILE" ;;
            1) echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚫 publish gate: LEAK [$(_safe_name "$f")] — 격리, 게시 안 함" >> "$LOG_FILE"
               _redact "$out" "$f" >> "$LOG_FILE"; mv "$f" "${f}.QUARANTINE" 2>/dev/null
               [ "$worst" -lt 2 ] && worst=2 ;;
            *) echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚫 publish gate: NOT SCANNED (rc=$rc) [$(_safe_name "$f")] — fail-closed, 게시 안 함" >> "$LOG_FILE"
               _redact "$out" "$f" >> "$LOG_FILE"; mv "$f" "${f}.UNSCANNED" 2>/dev/null
               worst=3 ;;
        esac
    done < <(digest_files)
    # 🟥 n==0 은 **자기모순**이다 — 이 함수는 `digest_ready` 가 참인 뒤에만 불린다. 파일이
    #    사라졌거나 선택자가 서로 어긋난 것이고, 둘 다 «게시해도 좋다»의 근거가 아니다.
    #    초판은 여기서 0(게시)을 냈다(종전 `[ -n "$f" ] || return 0` 를 그대로 옮긴 것).
    #    degrade-scan 이 S2 로 지목했고, 비가역 표면이므로 **보류(3)** 로 닫는다.
    if [ "$n" -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚫 publish gate: 대상 파일 0건인데 digest_ready 는 참이었다 — 보류(fail-closed)" >> "$LOG_FILE"
        return 3
    fi
    return "$worst"
}

# ── 착지 증언 (2026-08-18, 원정 2차 ⓑ) ────────────────────────────────────
# `digest_landing_check.sh` 는 10 레인을 갖고 selfcheck 루프가 그 self-test 를 돌리는데,
# **프로덕션 호출부가 0 이었다** — 「후보가 실제로 착지했나」를 아무도 재지 않았다. 그 스크립트
# 헤더 자신의 표현으로 *"닫히는데 증인이 없다"*. 파이프는 관통하는데 그 사실이 사람 기억으로만.
#
# 🟥 **오늘 것이 아니라 직전 다이제스트를 잰다.** 오늘 후보는 착지할 시간이 없었다 — 오늘 것을
#    재면 «전건 미착지»가 매일 나오고 그건 계기가 아니라 소음이다.
# 🟥 **차단하지 않는다. 게이트가 아니라 계측이다.** 헤더가 스스로 «선별기»라 적었고
#    (`file-change ≠ token-introduction` 잔여) 히트는 손으로 열어야 한다. 목적은 **착지율 시계열**
#    을 파일로 남기는 것 — 세션 시작 노티가 **네트워크 없이 그 파일만 읽게** 하려면 이게 먼저다
#    (peer: SessionStart 에 원격 호출은 지연·행 위험 · `--author @me` 는 계정 공유 시 오귀속).
landing_witness() {
    local checker="${ENGINE_DIR}/scripts/digest_landing_check.sh"
    [ -x "$checker" ] || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] landing witness: checker 부재 — SKIPPED (not a pass)" >> "$LOG_FILE"; return 0; }
    local prev
    # 🟥 R5 (2026-08-18, **첫 실사용에서 발견**) — `sort` 가 로케일 의존이라 «직전»을 틀리게
    #    고른다. 실측: 기본 로케일에서 `frontier_digest_2026-06-02.md`(대시 표기 옛 파일)가
    #    `frontier_digest_2026_08_17.md` 보다 뒤에 정렬돼, **두 달 전 파일**이 직전으로 뽑혔고
    #    그 파일엔 후보 절이 없어 매 런 HARNESS-ERROR 였다. `LC_ALL=C` 로 바이트 순서를 고정한다.
    #    (레인 21개가 전부 초록인 채로 이게 살아 있었다 — 픽스처가 한 가지 표기만 썼기 때문이다.)
    prev=$(find "${FH_DIR}/${OUT_DIR}" -maxdepth 1 -name 'frontier_digest_*.md' 2>/dev/null \
           | grep -v "frontier_digest_${TODAY}" | LC_ALL=C sort | tail -1)
    [ -n "$prev" ] || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] landing witness: 직전 digest 없음 — SKIPPED (not a pass)" >> "$LOG_FILE"; return 0; }
    local out rc
    # 🟥 R1 (2026-08-18) — 초판은 `bash "$checker" "$prev" "$FH_DIR"` 였다. 두 번째 인자는
    # **«타깃 파일 목록»** 이지 루트가 아니어서, 디렉터리가 타깃으로 들어가 **매 런 rc=10** 이
    # 찍혔다(실측: 2인자 rc=10 컨트롤 사망 / 1인자 rc=1 컨트롤 2/2). 「배선 완료」라고 보고한
    # 계기가 배선 첫날부터 죽어 있었다 — 손으로 부른 형태와 러너가 부르는 형태가 달랐다.
    # 루트는 `CLAUDE_PROJECT_DIR` 로 넘기고, **무엇을 볼지**는 스코프 변수로 넘긴다.
    # ⚠️ env 접두 할당으로 넘기면 **값의 공백에서 단어분리**된다(기본 스코프가
    #    `knowledge CLAUDE.md` — 공백이 들어 있다). export 를 서브셸에 가둔다.
    out=$( export CLAUDE_PROJECT_DIR="$FH_DIR"
           [ -n "${FD_LANDING_TRACKED:-}" ] && export DLC_TRACKED_PATHS="$FD_LANDING_TRACKED"
           [ -n "${FD_LANDING_IGNORED+x}" ] && export DLC_IGNORED_DIR="$FD_LANDING_IGNORED"
           # 🟥 컨트롤 토큰도 대상축이다 — 기본값은 레포 이름이라 FH 는 무변경이지만,
           #    대상 레포에 확실히 있는 토큰을 위성이 지정할 수 있어야 계기가 산다.
           [ -n "${FD_LANDING_CONTROLS:-}" ] && export DLC_CONTROLS="$FD_LANDING_CONTROLS"
           bash "$checker" "$prev" 2>&1 ); rc=$?
    case "$rc" in
        0)  echo "[$(date '+%Y-%m-%d %H:%M:%S')] landing witness [$(basename "$prev")]: ALL-LANDED (rc=0)" >> "$LOG_FILE" ;;
        1)  echo "[$(date '+%Y-%m-%d %H:%M:%S')] landing witness [$(basename "$prev")]: SOME-UNLANDED (rc=1) — 선별기다, 히트를 손으로 열어라" >> "$LOG_FILE" ;;
        10) echo "[$(date '+%Y-%m-%d %H:%M:%S')] landing witness [$(basename "$prev")]: HARNESS-ERROR (rc=10) — 못 쟀다, 미착지 0 이 아니다" >> "$LOG_FILE" ;;
        *)  echo "[$(date '+%Y-%m-%d %H:%M:%S')] landing witness [$(basename "$prev")]: UNEXPECTED rc=$rc — 못 쟀다" >> "$LOG_FILE" ;;
    esac
    printf '%s\n' "$out" | sed 's/^/    /' >> "$LOG_FILE"
    return 0   # 🟥 항상 0 — 계측이 러너의 종료 의미를 바꾸면 안 된다
}

# 프롬프트는 프로필 유무로 **형태가 갈린다**. 미설정이면 종전 문자열 그대로(FH 경로 무변경).
_build_prompt() {
    local base="[automated-run: launchd] Run /frontier-digest for today (${HUMAN_DATE}). Fetch latest signals from HN, arXiv, and GitHub."
    local prof="${FH_DIR}/${PROFILE_PATH}"
    if [ -n "$PROFILE_PATH" ] && [ -f "$prof" ]; then
        printf '%s\n\n%s\n\n%s\n\n%s\n\n%s\n' \
"${base}" \
"🟥 TARGET HARNESS — this digest is NOT for forge-harness. Read the profile below and write for THAT harness. Copying a generic frontier list here is replication, not propagation; the deliverable is **what THIS harness should change**, each point naming a file or behavior in it." \
"🟥 STANDPOINT — do not write from forge-harness's chair. OPEN AND READ the target's own files that the profile names: its canon docs AND its actual source. Cite them by path + line number or function name. A point you cannot anchor to something you actually opened is a trend statement, not an application. (This is the standpoint axis applied to frontier input: reading the profile is tier1b, reading the real code is tier2 — the measured difference is whether any Route line appears at all.)" \
"$(cat "$prof")" \
"Save the digest to ${OUT_DIR}/frontier_digest_${TODAY}.md, in the node grammar the profile specifies. Do NOT regenerate any index. If a source cannot be fetched, say so — never invent a citation, and cite specific items, not listing pages."
    else
        printf '%s %s\n' "${base}" "Save the digest to ${OUT_DIR}/frontier_digest_${TODAY}.md."
    fi
}

# Skip if already ran today
if digest_ready; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Already ran today — skipping" >> "$LOG_FILE"
    publish_gate; _pg=$?; [ "$_pg" -eq 0 ] && landing_witness; exit "$_pg"
fi

# Single-instance lock (mkdir = atomic on bash 3.2). Guards launchd-vs-manual double dispatch:
# a manual run during the retry sleep would otherwise race a second claude onto the same file.
# Stale-lock steal after 4h (crash mid-run must not brick every future day).
LOCK_DIR="${LOG_DIR}/.frontier_digest.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    if [ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +240 2>/dev/null)" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stealing stale lock (>4h)" >> "$LOG_FILE"
        rmdir "$LOCK_DIR" 2>/dev/null
        mkdir "$LOCK_DIR" 2>/dev/null || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lock race lost — exiting" >> "$LOG_FILE"; exit 0; }
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Another run in progress — exiting" >> "$LOG_FILE"
        exit 0
    fi
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

cd "$FH_DIR"

# --permission-mode acceptEdits: headless runs have no human to approve the Write, so the digest
# Write to tracks/_meta/ was silently denied (claude still exits 0) — the runner fired daily but
# persisted nothing. acceptEdits auto-accepts the file Write only (not arbitrary tool calls), which
# is the minimal fix; read/fetch tools stay pre-approved via .claude/settings.json. (fixed 2026-06-19)
#
# Retry + watchdog (added 2026-07-18): 8 days between 05-31 and 07-17 lost their digest to transient
# API/network errors right after machine wake (connection closed / ConnectionRefused; one hang of
# 65 min before dying). 3 attempts, 10 min apart; each attempt runs under a 30-min watchdog so the
# hang variant also reaches the retry path — a foreground call would block the loop forever.
# [automated-run: launchd] in the prompt = run-provenance token (proposed by the 07-16 digest) so a
# digest can mechanically distinguish an automated run from a manual /frontier-digest invocation.
MAX_ATTEMPTS="${FD_MAX_ATTEMPTS:-3}"
ATTEMPT_TIMEOUT_SECS="${FD_ATTEMPT_TIMEOUT_SECS:-1800}"
RETRY_SLEEP_SECS="${FD_RETRY_SLEEP_SECS:-600}"
POLL_SECS="${FD_POLL_SECS:-30}"

# ── 판별 계측 (2026-07-23, 주간감사 🟧2) ─────────────────────────────────────
# 07-19 실측: attempt 1 이 56분 53초 돌았는데 30분 watchdog 미발화 + Attempt 2/3 미진행,
# 로그 4줄로 끝. 경쟁 가설 ⓐ 시스템 슬립(폴링 sleep 이 통째로 정지 → 프로세스도 같이 자다
# 깨어나 죽은 채 발견, 신호 없음) ⓑ launchd 잡 회수(backoff sleep 중 TERM). 로그만으로
# 판별 불가였다 — **신호 trap + 단계 로깅**이 그 판별 계기다:
#   · TERM/INT/HUP 수신 → 로그에 남김 → 다음 실발화가 ⓑ면 이 줄이 찍힌다
#   · 각 sleep 진입/복귀를 로그 → ⓐ면 진입-복귀 사이 벽시계 갭이 sleep 길이를 초과한다
# (재현 하네스는 로직 검증까지 — 환경 원인은 이 계측이 라이브에서 잡는다)
# trap 은 **로그 후 재발사** — trap-without-exit 는 신호를 삼켜 러너가 TERM 을 무시하고
# 최대 ~110분 더 돈다(challenger B-1 실측: TERM 2발 무시, Attempt 3 완주). 재발사 전에
# lock 을 직접 정리한다(재발사된 TERM 은 기본 핸들러라 EXIT trap 을 안 태울 수 있음).
trap 'echo "[$(date "+%Y-%m-%d %H:%M:%S")] SIGNAL: runner received TERM — launchd reclaim? (hypothesis-b evidence)" >> "$LOG_FILE"; rmdir "$LOCK_DIR" 2>/dev/null; trap - TERM; kill -TERM $$' TERM
trap 'echo "[$(date "+%Y-%m-%d %H:%M:%S")] SIGNAL: runner received INT/HUP" >> "$LOG_FILE"; rmdir "$LOCK_DIR" 2>/dev/null; trap - INT HUP; kill -INT $$' INT HUP

# 인터럽터블 sleep — foreground sleep 은 끝나야 trap 이 돌아 신호 수신이 sleep 잔여시간만큼
# 늦는다(challenger B-1: launchd 의 TERM→~20s→KILL 창에서 backoff 600s 기준 기록 확률 ~3%).
# `sleep & wait` 는 wait 가 builtin 이라 신호를 즉시 받는다 → trap 즉발.
_isleep() { sleep "$1" & wait $!; }
for ATTEMPT in $(seq 1 $MAX_ATTEMPTS); do
    # Re-check before spending an attempt (a manual run may have landed the digest during the sleep)
    if digest_ready; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Digest appeared externally before attempt ${ATTEMPT} — success" >> "$LOG_FILE"
        publish_gate; _pg=$?; [ "$_pg" -eq 0 ] && landing_witness; exit "$_pg"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt ${ATTEMPT}/${MAX_ATTEMPTS}" >> "$LOG_FILE"
    "$CLAUDE_BIN" -p --permission-mode acceptEdits \
        ${FD_MODEL:+--model "$FD_MODEL"} \
        "$(_build_prompt)" \
        >> "$LOG_FILE" 2>&1 &
    CLAUDE_PID=$!
    DEADLINE=$((SECONDS + ATTEMPT_TIMEOUT_SECS))
    while kill -0 "$CLAUDE_PID" 2>/dev/null && [ "$SECONDS" -lt "$DEADLINE" ]; do
        _isleep "$POLL_SECS"
    done
    if kill -0 "$CLAUDE_PID" 2>/dev/null; then
        # 자식까지 — 부모만 죽이면 claude 의 자식(MCP 서버 등)이 고아로 남는다
        # (challenger B-2 실측: 하네스 1회에 고아 sleep 3개). bash 3.2 호환 2단 kill.
        pkill -P "$CLAUDE_PID" 2>/dev/null
        kill "$CLAUDE_PID" 2>/dev/null
        wait "$CLAUDE_PID" 2>/dev/null
        EXIT_CODE=124
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt ${ATTEMPT} killed by watchdog (${ATTEMPT_TIMEOUT_SECS}s)" >> "$LOG_FILE"
    else
        wait "$CLAUDE_PID"
        EXIT_CODE=$?
    fi
    if digest_ready; then
        publish_gate; _pg=$?
        [ "$_pg" -eq 0 ] || exit "$_pg"
        landing_witness
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Digest file present after attempt ${ATTEMPT} (claude exit ${EXIT_CODE}) — success" >> "$LOG_FILE"
        exit 0
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] No digest file after attempt ${ATTEMPT} (claude exit ${EXIT_CODE})" >> "$LOG_FILE"
    if [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backoff: sleeping ${RETRY_SLEEP_SECS}s before attempt $((ATTEMPT+1)) (wake-gap > sleep length ⇒ hypothesis-a system-sleep evidence)" >> "$LOG_FILE"
        _isleep "$RETRY_SLEEP_SECS"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backoff: woke for attempt $((ATTEMPT+1))" >> "$LOG_FILE"
    fi
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All ${MAX_ATTEMPTS} attempts failed — no digest for ${TODAY}" >> "$LOG_FILE"
exit 1
