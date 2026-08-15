#!/usr/bin/env bash
# digest_landing_check.sh — frontier digest 가 낸 **적용 후보가 실제로 착지했는지** 검증한다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 무엇을 푸는가 (identity ④: 프런티어→조직 전파)
# ─────────────────────────────────────────────────────────────────────────────
# `ship_readiness_gate.md` 의 ④ 는 이렇게 적혀 있었다:
#
#   "frontier-digest launchd auto + AX submission docs both real,
#    but digest→org **never closed as ONE pipeline**"
#
# 두 조각은 실재한다 — digest 는 매일 자동 생성되고, 조직 산출물도 실재한다.
# 없는 것은 **둘을 잇는 증거**다. 정확히 말하면 *"안 닫힌다"* 가 아니라
# **"닫히는데 증인이 없다"** 이다(identity ② 의 순서 증인과 같은 얼굴).
#
# 실측 근거 — 2026-08-08 digest 의 후보 `M2`(`allow_force_pushes` 잔여 재시도)는 같은 날
# 저녁 실측으로 다뤄졌고(그 잔여가 **거짓**임이 밝혀짐) 세션 카드에 최상단 항목으로 올라갔다.
# 즉 **파이프라인은 그날 실제로 관통했다.** 그런데 어디에도 *"이건 그 digest 후보가
# 발원지다"* 라는 연결이 없다 — 사람 기억으로만 이어졌다. 이 스크립트가 그 연결을 잰다.
#
# ─────────────────────────────────────────────────────────────────────────────
# no-reinvention — 검증 로직은 짓지 않는다
# ─────────────────────────────────────────────────────────────────────────────
# 착지 검증기는 이미 있다: `utterance_landing_check.sh` (probes.tsv + **컨트롤 필수** +
# rc 3분기). 이 스크립트가 새로 하는 일은 **추출뿐**이다 — digest 표를 probes.tsv 로 옮긴다.
# 검증 로직을 여기에 다시 쓰면 **중복 정규화기**가 되고, 두 벌의 관대함이 갈리는 순간
# 한쪽만 통과하는 입력이 무음 드롭된다([[feedback_divergent_leniency_duplicate_normalizers]]).
#
# ─────────────────────────────────────────────────────────────────────────────
# 판별자를 어떻게 고르나 — digest 자신이 답을 적어놨다
# ─────────────────────────────────────────────────────────────────────────────
# 2026-08-08 digest §Warning Signals: *"히트 수만 보고 판정하면 안 되고 히트를 열어야 한다.
# 판별자는 **사건 고유 토큰**(도메인·URL)으로 고르는 게 낫다."*
# 그래서 후보 본문의 **백틱 코드 스팬**과 **`[[위키링크]]`** 만 판별자로 쓴다. 산문 문구를
# 정규식으로 걸면 문구가 바뀌는 순간 죽는다(착지 검증기 헤더의 명명된 잔여와 같은 함정).
#
# ⚠️ **판별 토큰을 못 뽑은 후보는 `UNCHECKABLE` 로 인쇄한다.** 조용히 빼면 착지율이
# 부풀려진다 — 미검증을 분모에서 지우는 것은 `not found ≠ 0` 위반이다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 스코프 (운영자 결정, 2026-08-09)
# ─────────────────────────────────────────────────────────────────────────────
# 착지 대상 = **공개 FH 자산 + `tracks/`**. 비공개 companion store 는 **보지 않는다** —
# 스캔은 로컬에서 가능하지만 결과를 공개 파일에 쓰면 residency 위반이 된다.
# 따라서 이 계기가 재는 것은 *"조직 전체 전파"* 가 아니라 **"허브 내부 착지"** 다.
# 그 차이는 판정에 반드시 붙는다(아래 출력이 매번 스코프를 인쇄한다).
#
# ─────────────────────────────────────────────────────────────────────────────
# 🟡 알려진 한계 — RC 다. 단 **선별기이지 판정기가 아니다** (2026-08-09)
# ─────────────────────────────────────────────────────────────────────────────
# **닫힌 것 — mtime 오염.** 초판은 선후를 mtime 하나로 재서, 브랜치 전환이 갱신한 mtime 때문에
# *내용은 digest 이전인* 파일이 필터를 통과했다(실측: `CLAUDE.md` mtime 21:45 vs 내용은 그 전 →
# 원래 있던 토큰이 착지로 잡혀 미착지 2건이 초록으로 뒤집힘). 지금은 **두 축을 분리**한다:
#   git 추적 → `git log --since=@<digest mtime>` (커밋 시각)
#   gitignored(`tracks/**`) → mtime (그 축엔 다른 증거가 없다)
#   dirty tracked → **UNMEASURED** 로 셈에 남긴다(커밋 안 된 수정엔 git 시각 증거가 없다)
# 레인 2종이 그 분리를 고정한다 — mtime 만 새 tracked 는 **안 세고**(a), 커밋만 새 tracked 는
# mtime 이 옛것이어도 **잡는다**(b). (b)가 없으면 *"tracked 를 전부 버려 negative 만 통과하는
# 하네스"* 가 된다(cross-family/codex 지목).
#
# **안 닫힌 것 — `file-change ≠ token-introduction`.** 파일이 digest 이후 진짜 커밋됐어도
# 그 토큰은 원래 있던 것일 수 있다(실측: `CLAUDE.md` 는 챔버 실적 수정으로 커밋됐고 후보와
# 무관하다). 닫으려면 **토큰 수준 diff**(`git log -S`)가 필요한데 후보마다 타깃이 갈려
# 착지 검증기 인터페이스와 맞지 않는다 — 재설계 사안으로 남긴다.
#
# 📌 그래서 이 계기의 출력은 **선별기다.** 히트는 반드시 열어라. 실측 4회 중 4회 손검증이
#    무언가를 잡았다(자기참조 → 토큰 절단 → mtime 오염 → file-change≠token-introduction).
#
# ── 사용 ──
#   digest_landing_check.sh <digest.md> [target ...]   # 미지정 시 기본 타깃
#   digest_landing_check.sh --extract <digest.md>      # probes.tsv 만 출력
#   digest_landing_check.sh --self-test
#
# ── 종료 코드 (착지 검증기의 것을 그대로 물려받는다) ──
#   0  전건 착지 · 1 미착지 있음 · 10 HARNESS-ERROR(컨트롤 사망/입력 불량)
#   ⚠️ UNCHECKABLE 이 있으면 **0 을 내지 않는다** — 재지 못한 것을 통과로 렌더하지 않는다.

set -uo pipefail

# ⚠️ `CLAUDE_PROJECT_DIR` 를 우선한다. 초판은 스크립트 위치로만 루트를 잡아서,
# 격리 픽스처에서 **실제 레포를 봤다**(타깃 279건). 기존 레인은 타깃을 인자로 넘겼기 때문에
# **기본 타깃 선택 경로가 한 번도 테스트되지 않았다** — 자기 self-test 의 사각이었다.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FH="${CLAUDE_PROJECT_DIR:-$(cd "$SELF_DIR/.." && pwd)}"
# ⚠️ 검증기는 **도구**이고 FH 는 **대상**이다 — 두 축을 같은 변수로 묶으면 격리 픽스처에서
# 도구까지 임시 트리에서 찾다가 죽는다(실측). 도구는 언제나 이 스크립트 옆에 있다.
CHECKER="$SELF_DIR/utterance_landing_check.sh"
SECTION_RE='^## .*Immediate Application Candidates'

# 후보 표에서 (id, 판별토큰 OR 정규식) 을 뽑는다. 토큰 없으면 id 만 내고 정규식은 빈 값.
_extract() { # $1 = digest path
  awk -v sec="$SECTION_RE" '
    $0 ~ sec { inblk=1; next }
    inblk && /^## /  { inblk=0 }
    inblk && /^\|/ {
      line=$0
      # 헤더/구분선 제외
      if (line ~ /^\|[[:space:]]*#/) next
      if (line ~ /^\|[-:| ]+\|$/) next
      # 1열 = id (볼드 제거)
      n=split(line, cell, "|")
      if (n < 4) next
      id=cell[2]; gsub(/[*[:space:]]/, "", id)
      if (id == "") next
      body=""
      for (i=4; i<=n; i++) body = body cell[i] "|"
      # 판별자 = 백틱 스팬 + [[위키링크]]
      toks=""
      # 백틱 스팬을 [[위키링크]] 와 **같은 형태로** 모아 한 번에 훑는다.
      # 초판은 헤더에 "백틱 + 위키링크" 라고 적고 **코드는 백틱만** 뽑았다 —
      # 주석이 말하는데 코드가 안 하는 것(cross-family 가 어제 F7 로 지목한 클래스).
      tmp=body
      while (match(tmp, /\[\[[^]]+\]\]/)) {
        w=substr(tmp, RSTART+2, RLENGTH-4)
        tmp=substr(tmp, RSTART+RLENGTH)
        if (length(w) >= 5) toks = (toks == "" ? w : toks "|" w)
      }
      tmp=body
      while (match(tmp, /`[^`]+`/)) {
        t=substr(tmp, RSTART+1, RLENGTH-2)
        tmp=substr(tmp, RSTART+RLENGTH)
        # ⚠️ 콜론/공백 뒤를 자른다. `allow_force_pushes: true` 를 통째로 걸면 실제 착지문
        # (`allow_force_pushes` 만 쓴 카드)을 **놓친다** — 실측으로 확인된 오검출 방향.
        sub(/[: ].*$/, "", t)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
        # 판별력 없는 짧은/일반 토큰은 버린다
        if (length(t) < 5) continue
        # 정규식 메타는 통째로 버린다(escape 실패가 무음 오탐을 만든다)
        if (t ~ /[][(){}.*+?^$\\|]/) {
          # 점·언더스코어만 있는 파일명류는 살린다 (예: plugin.json)
          if (t ~ /^[A-Za-z0-9_.-]+$/) { } else continue
        }
        gsub(/\./, "\\.", t)
        toks = (toks == "" ? t : toks "|" t)
      }
      print id "\t" toks
    }
  ' "$1"
}

do_extract() { # $1 = digest
  local d="$1" id toks n=0 unchk=0
  [ -f "$d" ] || { echo "❌ digest 없음: $d" >&2; return 10; }
  # 컨트롤 — 이 계기가 살아 있는지 증명한다. 대상 트리에 확실히 존재하는 토큰.
  # 컨트롤이 죽으면 착지 검증기가 rc=10 을 내고 타깃 결과를 인쇄하지 않는다.
  printf 'CONTROL\tforge-harness\t컨트롤: 레포명\n'
  printf 'CONTROL\tsession\t컨트롤: 흔한 토큰\n'
  while IFS=$'\t' read -r id toks; do
    [ -n "${id:-}" ] || continue
    n=$((n+1))
    if [ -z "${toks:-}" ]; then
      unchk=$((unchk+1))
      printf '# UNCHECKABLE\t%s\t판별 토큰(백틱/위키링크) 없음 — 재지 못함\n' "$id"
      continue
    fi
    printf 'TARGET\t%s\t후보 %s\n' "$toks" "$id"
  done < <(_extract "$d")
  if [ "$n" -eq 0 ]; then
    echo "❌ 후보 절을 못 찾았다 (섹션 정규식 불일치?) — 0건과 미검출을 가르기 위해 실패로 낸다" >&2
    return 10
  fi
  return 0
}

do_check() {
  local d="${1:-}"; shift || true
  [ -n "$d" ] && [ -f "$d" ] || { echo "❌ usage: digest_landing_check.sh <digest.md> [target ...]" >&2; return 10; }
  [ -x "$CHECKER" ] || [ -f "$CHECKER" ] || {
    echo "❌ 착지 검증기 부재: $CHECKER (이 스크립트는 검증을 자체 구현하지 않는다)" >&2; return 10; }

  local -a targets
  if [ "$#" -gt 0 ]; then targets=("$@")
  else
    # 기본 스코프 = 공개 FH 자산 + tracks. **비공개 store 제외**(운영자 결정).
    targets=()
    # ⚠️ CLAUDE.md 도 **선후 필터를 거친다.** 초판은 무조건 추가했고, 그래서 이 파일 하나가
    # 필터를 우회해 오탐 원천이 됐다 — 손검증에서 "M1 착지 1파일" 의 그 1파일이 CLAUDE.md
    # 였고, 후보와 무관하게 원래 있던 토큰이었다. 예외 경로 하나가 필터 전체를 무력화한다.
    [ -f "$FH/CLAUDE.md" ] && [ "$FH/CLAUDE.md" -nt "$d" ] && targets+=("$FH/CLAUDE.md")
    # ★ **digest 보다 나중에 수정된 파일만** 본다. grep 은 "토큰이 있다" 만 재고
    # "이 후보 때문에 생겼다" 는 못 잰다 — 이미 있던 문서가 착지로 잡힌다(실측: 후보 하나가
    # 21파일 히트, 전부 무관한 기존 문서였다). 선후 필터가 인과를 주지는 않지만
    # **"그 뒤에 쓰였다"** 는 잡아서 판별력을 크게 올린다.
    # ⚠️ 명명된 잔여: mtime 기반이라 sync/checkout 으로 흔들린다. `tracks/**` 가 gitignored 라
    # git 시각을 못 쓰는 것이 원인이고, 이건 챔버 순서 증인이 만난 것과 같은 제약이다.
    # ★ **두 축을 분리한다** (cross-family/codex 설계, 2026-08-09).
    #   git 추적 파일 → **커밋 시각**(`git log --since=@epoch`). mtime 은 브랜치 전환·체크아웃으로
    #                   갱신되므로 tracked 에서는 신뢰할 수 없다 — 실측으로 확인된 오탐 원인.
    #   gitignored    → mtime 밖에 없다(`tracks/**`). 남는 취약면이고 아래에 명명한다.
    # ⚠️ **GNU-first, and then VALIDATE — 순서만으로는 부족하다.** 초판은 `stat -f %m || stat -c %Y`
    # (BSD-first)였고 **리눅스에서 조용히 fail-open 했다**: GNU 의 `-f` 는 `--file-system` 이라
    # 일반 파일에 대해 **exit 0** 으로 파일시스템 리포트(`File: … Blocks: …`)를 뱉는다. 즉 `||`
    # 폴백이 영영 안 돌고 `_dts` 에 epoch 대신 여러 줄 blob 이 들어간다 → `git log --since="@<blob>"`
    # 이 파싱 실패 → tracked 대상 **0개** → 「착지 0건」으로 렌더된다. 이 계기가 막으려고 존재하는
    # 바로 그 미측정-을-0으로 렌더가 계기 자신에게서 났다([[feedback_not_found_is_not_zero_family]]).
    # 아래 `[ -z ]` 가드는 blob 이 **비어 있지 않아서** 못 잡았다 — 존재검사는 진위를 못 본다.
    # 실측 2026-08-15: macOS 10/10 PASS · ubuntu:24.04 컨테이너 및 CI(ubuntu-latest) 1/10 FAIL
    # (positive arm `★N-git b` 만 죽는다 = negative 만 통과하는 하네스). 이 레인이 selfcheck 에
    # 배선되기 전에는 아무도 안 돌려서 비용이 0이었다 — 배선이 가정을 표면화한 판본
    # ([[feedback_wiring_surfaces_hidden_failures]], 같은 `stat -f` 원인의 재발).
    # 정수 검증까지 두는 이유: 순서는 플랫폼이 하나 더 늘면 다시 깨지지만, "정수가 아니면 에러"는
    # 안 깨진다. sync-from-be.sh:116 · fh_session_load.sh:105 가 같은 함정을 이미 주석으로 남겼다.
    local _dts; _dts="$(stat -c %Y "$d" 2>/dev/null || true)"
    case "${_dts:-}" in ''|*[!0-9]*) _dts="$(stat -f %m "$d" 2>/dev/null || true)" ;; esac
    case "${_dts:-}" in
      ''|*[!0-9]*)
        echo "❌ digest mtime 을 못 읽었다(stat 출력이 epoch 정수가 아니다) — 선후 판정 불가" >&2
        return 10 ;;
    esac
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      case "$f" in *.md) ;; *) continue ;; esac
      [ -f "$FH/$f" ] && targets+=("$FH/$f")
    done < <(git -C "$FH" log --since="@$_dts" --name-only --pretty=format: -- knowledge CLAUDE.md 2>/dev/null | sort -u)
    while IFS= read -r f; do targets+=("$f"); done < <(
      find "$FH/tracks/_meta" -name '*.md' -type f -newer "$d" 2>/dev/null | head -400)
    # dirty tracked — 커밋 안 된 수정본엔 git 시각 증거가 없다. 초록으로 만들지 않고 셈에 남긴다.
    DIRTY_TRACKED="$(git -C "$FH" diff --name-only -- knowledge CLAUDE.md 2>/dev/null | grep -c '[.]md$')" || true
    DIRTY_TRACKED="${DIRTY_TRACKED//[^0-9]/}"; DIRTY_TRACKED="${DIRTY_TRACKED:-0}"
  fi
  # ★ 자기참조 차단 — **이 계기의 첫 실물 실행에서 100% 오탐을 낸 원인**이다.
  # digest 자신(과 그 로그)이 타깃에 있으면 모든 후보 토큰이 거기서 발견되므로
  # **전건이 자동으로 "착지"** 가 된다. 손검증 전까지 3/3 초록이었고 실제 착지는 0이었다.
  local _dbase; _dbase="$(basename "$d")"
  local -a _filtered=()
  local _t
  for _t in "${targets[@]}"; do
    case "$_t" in
      *"$_dbase") continue ;;          # digest 자신
      */logs/*)   continue ;;          # 그 생성 로그
      *frontier_digest_*) continue ;;  # 다른 날짜 digest (후보가 이월되며 반복 등장한다)
    esac
    _filtered+=("$_t")
  done
  targets=("${_filtered[@]}")
  [ "${#targets[@]}" -gt 0 ] || { echo "❌ 타깃 0건" >&2; return 10; }

  local probes; probes="$(mktemp -t dlc.XXXXXX)" || return 10
  if ! do_extract "$d" > "$probes"; then rm -f "$probes"; return 10; fi

  # ⚠️ `grep -c … || echo 0` 은 **매치 0일 때 rc=1** 이라 폴백이 붙어 "0\n0" 을 만든다.
  # 그 두 줄짜리 값이 뒤의 `-gt` 비교를 bash 에러(=거짓)로 만들어 **가드를 무음 통과**시킨다
  # ([[feedback_pipefail_fallback_disarms_guard]]). 파이프를 분해하고 정수로 소독한다.
  local unchk; unchk="$(grep -c '^# UNCHECKABLE' "$probes" 2>/dev/null)" || true
  unchk="${unchk//[^0-9]/}"; unchk="${unchk:-0}"
  echo "── digest 착지 검증: $(basename "$d") ──"
  echo "   스코프: 공개 FH 자산 + tracks/ (비공개 companion store 제외 — '조직 전파'가 아니라 '허브 내부 착지')"
  echo "   타깃 파일 ${#targets[@]}건 (digest 이후 수정분만) · 판별불가 후보 ${unchk}건"
  echo "   축: git추적=커밋시각 · gitignored=mtime · dirty tracked ${DIRTY_TRACKED:-0}건=UNMEASURED"
  echo "   ⚠️ 이 계기는 **선후**를 잰다. 인과가 아니다 — 히트는 열어서 확인하라"
  echo

  bash "$CHECKER" "$probes" "${targets[@]}"
  local rc=$?
  rm -f "$probes"

  # ⚠️ 재지 못한 후보가 있으면 전건 착지라도 0 을 내지 않는다.
  if [ "$rc" -eq 0 ] && [ "${unchk:-0}" -gt 0 ]; then
    echo
    echo "🟡 착지한 것은 전부 착지했지만 **판별불가 후보 ${unchk}건은 재지 못했다.**"
    echo "   전건 통과로 렌더하지 않는다 (미측정 ≠ 0). rc=1"
    return 1
  fi
  return "$rc"
}

do_self_test() {
  local T; T="$(mktemp -d -t dlc_t.XXXXXX)" || return 10
  local pass=0 fail=0 rc
  _t() { if [ "$2" = "$3" ]; then echo "✅ $1 → rc=$3"; pass=$((pass+1));
         else echo "❌ $1 → rc=$3 (기대 $2)"; fail=$((fail+1)); fi }

  # known-pair 픽스처. 실물 2026-08-08 digest 의 구조를 그대로 본뜬다.
  cat > "$T/digest.md" <<'EOF'
# digest
## 📌 FH Immediate Application Candidates

| # | 티어 | 내용 |
|---|---|---|
| **M2** | **M** | `allow_force_pushes` 잔여 재시도 — 실측이 붙었다 |
| **R2** | R | `prime_agent_sister_asset` 기록 — 코드 직독 필요 |

## ⚠️ Warning Signals
EOF
  # positive 타깃: M2 토큰이 있다. negative(R2)는 없다.
  mkdir -p "$T/tgt"
  printf 'forge-harness session card\nallow_force_pushes 잔여가 거짓임을 실측했다\n' > "$T/tgt/card.md"

  # P1 — 착지분과 미착지분이 섞이면 rc=1 (미착지 있음)
  rc=0; bash "$SELF_DIR/$(basename "${BASH_SOURCE[0]}")" "$T/digest.md" "$T/tgt/card.md" >/dev/null 2>&1 || rc=$?
  _t "M2 착지 · R2 미착지 → 미착지 검출(1)" 1 "$rc"

  # P2 — 둘 다 착지시키면 0
  printf 'prime_agent_sister_asset 도 기록했다\n' >> "$T/tgt/card.md"
  rc=0; bash "$SELF_DIR/$(basename "${BASH_SOURCE[0]}")" "$T/digest.md" "$T/tgt/card.md" >/dev/null 2>&1 || rc=$?
  _t "둘 다 착지 → 전건 착지(0)" 0 "$rc"

  # N1 — 컨트롤 사망(타깃에 컨트롤 토큰이 없다) → HARNESS-ERROR(10), PASS 도 FAIL 도 아님
  printf 'allow_force_pushes\nprime_agent_sister_asset\n' > "$T/tgt/nocontrol.md"
  rc=0; bash "$SELF_DIR/$(basename "${BASH_SOURCE[0]}")" "$T/digest.md" "$T/tgt/nocontrol.md" >/dev/null 2>&1 || rc=$?
  _t "컨트롤 사망 → HARNESS-ERROR(10), 착지로 안 읽는다" 10 "$rc"

  # N2 — 판별 토큰 없는 후보는 UNCHECKABLE 이고, 전건 착지라도 0 을 내지 않는다
  cat > "$T/digest_unchk.md" <<'EOF'
# digest
## 📌 FH Immediate Application Candidates

| # | 티어 | 내용 |
|---|---|---|
| **S9** | S | 판별 토큰이 하나도 없는 산문 후보다 |

## end
EOF
  # ── N-git ★ 두 축 분리 검증 (cross-family/codex 설계) ──────────────────────
  # 임시 git 레포에서 **mtime 과 커밋시각이 어긋난** 두 상태를 만들어 각각 잰다.
  # 이 두 레인이 없으면 mtime 오염 수리가 회귀해도 초록이 난다.
  local G; G="$(mktemp -d -t dlc_g.XXXXXX)" || return 10
  (
    cd "$G" && git init -q . && git config user.email t@t && git config user.name t
    mkdir -p knowledge tracks/_meta
    printf 'forge-harness session\nstale_token_x\n' > knowledge/old.md
    git add -A && GIT_AUTHOR_DATE="2001-01-01T00:00:00+0000" \
      GIT_COMMITTER_DATE="2001-01-01T00:00:00+0000" git commit -qm base
    printf '# d\n## 📌 FH Immediate Application Candidates\n\n| # | 티어 | 내용 |\n|---|---|---|\n| **A1** | M | `stale_token_x` 후보 |\n| **B1** | M | `fresh_token_y` 후보 |\n\n## end\n' \
      > tracks/_meta/frontier_digest_2001_01_02.md
    touch -t 200101020000 tracks/_meta/frontier_digest_2001_01_02.md
    printf 'forge-harness session\nfresh_token_y\n' > knowledge/new.md
    git add -A && GIT_AUTHOR_DATE="2001-01-03T00:00:00+0000" \
      GIT_COMMITTER_DATE="2001-01-03T00:00:00+0000" git commit -qm later
    touch -t 200101010000 knowledge/new.md
    touch knowledge/old.md
    printf 'forge-harness session control\n' > tracks/_meta/card.md
  ) >/dev/null 2>&1
  out="$( cd "$G" && CLAUDE_PROJECT_DIR="$G" bash "$SELF_DIR/$(basename "${BASH_SOURCE[0]}")" \
          "$G/tracks/_meta/frontier_digest_2001_01_02.md" 2>&1 )"
  # ⚠️ **줄 단위로** 본다. `case *"A1"*"미착지"*` 는 마지막 요약줄("N건 중 M건 미착지")까지
  # 삼켜 오매칭한다 — 문자열 위치로 판정하는 prose-grep 함정([[feedback_typed_verdict_channel]]).
  if printf '%s\n' "$out" | grep -qE '후보 A1[[:space:]]+미착지'; then
    _t "★N-git a) mtime 만 새 tracked 는 착지로 안 센다" 0 0
  else
    echo "❌ N-git a) mtime 오염 파일이 착지로 잡혔다"; fail=$((fail+1))
  fi
  # b) 는 **positive arm** — 없으면 "tracked 를 전부 버려 negative 만 통과" 하는 하네스가 된다.
  if printf '%s\n' "$out" | grep -qE '후보 B1[[:space:]]+[0-9]+파일'; then
    _t "★N-git b) 커밋시각이 새 tracked 는 mtime 이 옛것이어도 잡는다" 0 0
  else
    echo "❌ N-git b) tracked 를 통째로 버렸다(negative 만 통과하는 하네스)"; fail=$((fail+1))
  fi
  rm -rf "$G"

  # N2a — 후보가 **전부** 판별불가면 TARGET 이 0건이다. 이건 "미착지" 가 아니라
  #        **계기 부적용**이고, 착지 검증기가 rc=10(PASS 도 FAIL 도 아님)을 낸다.
  #        초판은 여기 기대값을 1 로 적었는데 **내 기대가 틀렸다** — 전부 못 쟀으면 에러다.
  rc=0; bash "$SELF_DIR/$(basename "${BASH_SOURCE[0]}")" "$T/digest_unchk.md" "$T/tgt/card.md" >/dev/null 2>&1 || rc=$?
  _t "판별불가만 있는 digest → HARNESS-ERROR(10), '착지 0건' 아님" 10 "$rc"

  # N2b ★ 진짜 중요한 레인 — **혼합**. 잴 수 있는 건 전부 착지했는데 판별불가가 섞였다.
  #        여기서 0 을 내면 "전건 착지" 로 읽히고 **분모에서 미측정이 사라진다.**
  cat > "$T/digest_mixed.md" <<'EOF'
# digest
## 📌 FH Immediate Application Candidates

| # | 티어 | 내용 |
|---|---|---|
| **M2** | **M** | `allow_force_pushes` 잔여 재시도 |
| **S9** | S | 판별 토큰이 하나도 없는 산문 후보다 |

## end
EOF
  rc=0; bash "$SELF_DIR/$(basename "${BASH_SOURCE[0]}")" "$T/digest_mixed.md" "$T/tgt/card.md" >/dev/null 2>&1 || rc=$?
  _t "★혼합(착지 전건 + 판별불가 1) → 0 아님(미측정을 분모에서 안 지운다)" 1 "$rc"

  # N3 — 후보 절이 없는 digest → 10 (0건과 미검출을 가른다)
  printf '# digest\n## 다른 절\n내용\n' > "$T/nosection.md"
  rc=0; bash "$SELF_DIR/$(basename "${BASH_SOURCE[0]}")" "$T/nosection.md" "$T/tgt/card.md" >/dev/null 2>&1 || rc=$?
  _t "후보 절 부재 → HARNESS-ERROR(10), '0건 착지' 아님" 10 "$rc"

  # N4 — digest 파일 자체가 없음 → 10
  rc=0; bash "$SELF_DIR/$(basename "${BASH_SOURCE[0]}")" "$T/does-not-exist.md" >/dev/null 2>&1 || rc=$?
  _t "digest 부재 → rc=10" 10 "$rc"

  # N5 컨트롤 — P2 가 여전히 0 인가 (앞 레인이 상태를 오염시키지 않았는지)
  rc=0; bash "$SELF_DIR/$(basename "${BASH_SOURCE[0]}")" "$T/digest.md" "$T/tgt/card.md" >/dev/null 2>&1 || rc=$?
  _t "컨트롤 — 정상 케이스 재확인" 0 "$rc"

  rm -rf "$T"
  echo
  if [ "$fail" -eq 0 ]; then
    echo "✅ 캘리브레이션 통과 ($pass 레인) — 착지/미착지/계기사망/미측정을 각각 다른 값으로 가른다."
    return 0
  fi
  echo "🟥 캘리브레이션 실패 ($fail/$((pass+fail)))"
  return 1
}

case "${1:---help}" in
  --self-test) do_self_test ;;
  --extract)   shift; do_extract "${1:-}" ;;
  --help|-h)   sed -n '1,55p' "${BASH_SOURCE[0]}" | grep -E '^#( |$)' | sed 's/^# \{0,1\}//' ;;
  *)           do_check "$@" ;;
esac
