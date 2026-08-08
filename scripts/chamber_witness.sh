#!/usr/bin/env bash
# chamber_witness.sh — 챔버 런의 **순서 증인**. 내용은 비공개로 두고 순서만 증언한다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 무엇을 푸는가
# ─────────────────────────────────────────────────────────────────────────────
# `ship_readiness_gate.md §② promotion criteria` 의 P1 은 이렇게 적혀 있었다:
#
#   "An EMIT run leaves an ordering record that does not depend on trusting the
#    author — the intent/budget/sim record committed, hashed, or otherwise
#    witnessed OUTSIDE the gitignored workspace, before the verdict"
#   상태: **not buildable today** — no such channel exists for `tracks/**`
#
# 못 짓는다고 적힌 이유는 `tracks/**` 가 `.gitignore` 로 통째 무시라 챔버
# 아티팩트가 버전관리 밖이고, 남는 순서 증거가 **mtime 뿐인데 위조가 자명**하다는
# 것이었다. 그래서 *"게이트가 결과를 알기 전에 돌았는가"* 를 **정직한 런조차
# 증명할 수 없었다.**
#
# 이 스크립트가 여는 채널은 P1 문구가 이미 허용한 두 번째 형태다 — **hashed**.
# 내용(INTENT/BUDGET/SIM_NOTES)은 비공개 워크스페이스에 그대로 두고,
# **SHA-256 만** 추적되는 원장에 적어 커밋한다. 그러면:
#
#   · 본문 유출 0   — 해시는 내용을 복원하지 못한다(비공개 유지 요구 충족)
#   · 순서 증인 O   — 커밋 그래프가 "이 해시가 verdict 해시보다 먼저 들어왔다"를 증언
#
# ⚠️ **"유출 0" 이라고 쓰면 과장이다**(cross-family F9). 원장에는 `run` slug · 아티팩트
# 파일명 · 기록 시각 · 해시가 남는다 — 즉 *"어떤 이름의 런이 언제 돌았는가"* 는 공개된다.
# 그리고 INTENT/BUDGET 템플릿처럼 **저엔트로피 아티팩트는 SHA-256 도 사전 공격 대상**이다
# (후보 문자열을 만들어 해시를 맞춰보면 내용을 알아낼 수 있다). 숨는 것은 **본문**이지
# 런의 존재나 형식이 아니다.
#
# ★ 이 증인이 **실제로** 성립하는 조건(이 레포 한정):
#   `main` 에 `non_fast_forward` ruleset 이 active 라 **push 된 히스토리를 되쓸 수
#   없다**. 즉 커밋 순서는 저자가 사후에 바꿀 수 없다. ruleset 이 꺼지면 이 스크립트의
#   증인력도 같이 약해진다 — 배선이 아니라 **전제**라서 여기 적는다.
#
# ⚠️ **그 전제를 이 스크립트가 검사하지는 않는다**(cross-family F7). `verify` 가 보는 것은
#   **로컬 커밋 그래프**뿐이다: 브랜치가 `main` 인지 · 그 커밋이 push 됐는지 · ruleset 이
#   지금도 켜져 있는지 · ancestry 가 맞는지를 **확인하지 않는다.** 로컬에만 있는 커밋은
#   여전히 되쓸 수 있으므로, `WITNESSED` 는 *"로컬 이력상 먼저였다"* 까지가 정확한 뜻이고
#   되쓰기 불가는 **push 이후에** 서버 설정이 준다. 두 문장을 붙여 읽지 마라.
#
# ─────────────────────────────────────────────────────────────────────────────
# 이 계기가 증명하지 않는 것 (과잉주장 금지 — 명명된 잔여)
# ─────────────────────────────────────────────────────────────────────────────
# 커밋먼트는 **"그 시점에 이 내용이 고정됐다"** 를 증명한다.
# **"정직하게 썼다"** 는 증명하지 않는다. 저자는 여전히 결론을 먼저 정하고 INTENT 를
# 그에 맞춰 쓴 뒤 커밋할 수 있다. 그것은 이 채널이 겨누는 실패가 아니다 —
# 겨누는 것은 **사후 재작성**(verdict 를 보고 나서 INTENT 를 고쳐 "screened" 라고
# 주장하는 것)이고, 그건 닫힌다.
#
# 두 번째 잔여: 원장 자체가 공개 표면이라 **run slug 이 노출**된다. restricted-env·비공개
# 후보를 챔버에 넣을 때는 slug 을 익명화해서 넣어라(`--anon` 없음 — 호출자가
# 익명 slug 을 그냥 넘기면 된다). pre-commit 기밀 스캔이 뒤를 받치지만 그건
# 패턴 denylist 지 보편 스캐너가 아니다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 사용법
# ─────────────────────────────────────────────────────────────────────────────
#   chamber_witness.sh record <slug> <artifact-path>   # 해시를 원장에 append
#   chamber_witness.sh verify <slug>                   # 순서/무결 판정
#   chamber_witness.sh --self-test                     # known-pair 캘리브레이션
#
# verify 판정 (4-state — `not found ≠ 0` 을 지킨다):
#   WITNESSED    verdict 보다 먼저 커밋된 pre-verdict 아티팩트가 1건 이상 있다
#   UNWITNESSED  원장에 기록이 없다 (= 미측정. 위반이 아니다)
#   PENDING      기록은 있으나 아직 커밋 안 됨 (증인 미성립 — 아직은 아니다)
#   TAMPERED     기록된 해시와 현재 파일이 불일치
#   UNORDERED    verdict 가 pre-verdict 아티팩트보다 먼저 커밋됐다
#
# exit: 0 WITNESSED · 1 UNORDERED/TAMPERED · 2 UNWITNESSED/PENDING · 10 입력·환경 불량
#   ⚠️ **2 는 통과가 아니다.** 호출자는 0 만 통과로 읽어라. 2 를 통과로 읽으면
#      "기록이 없다" 가 "문제 없다" 로 렌더되고, 그게 이 파일이 막으려는 바로 그 결함이다.

set -u

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LEDGER_REL="knowledge/shared/learnings/chamber_ordering_witness.yaml"
LEDGER="$REPO_ROOT/$LEDGER_REL"

# verdict 파일명 — 이 이름만 "결과" 로 취급하고 나머지는 pre-verdict 로 본다.
VERDICT_NAME="EMISSION_VERDICT.md"

_sha() { # $1=path  → sha256 hex, 실패 시 빈 문자열
  [ -f "$1" ] || { echo ""; return 1; }
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" 2>/dev/null | awk '{print $1}'
  else
    echo ""; return 1
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# record — 해시를 원장에 append
# ─────────────────────────────────────────────────────────────────────────────
do_record() {
  local slug="$1" art="$2"
  [ -n "$slug" ] && [ -n "$art" ] || { echo "❌ usage: record <slug> <artifact-path>" >&2; return 10; }
  if [ ! -f "$art" ]; then
    echo "❌ 아티팩트 없음: $art" >&2; return 10
  fi
  local h; h="$(_sha "$art")"
  if [ -z "$h" ]; then
    # 해시 도구가 없으면 **조용히 넘어가지 않는다** — 증인 채널이 죽은 것이다.
    echo "❌ sha256 도구 없음 (shasum/sha256sum) — 증인 기록 불가" >&2; return 10
  fi
  local base; base="$(basename "$art")"
  # ⚠️ 원장은 공백 구분 positional 로 파싱된다. 공백·개행·콜론이 든 slug/파일명을 그대로
  # 박으면 **기록은 되고 파싱은 깨진다** — 즉 증인이 조용히 사라진다(cross-family F10).
  # 그래서 여기서 fail-closed 로 막는다. 러너는 이미 slug charset 을 제한하지만
  # 이 스크립트는 직접 호출도 가능하므로 러너의 검증에 기대지 않는다.
  case "$slug" in
    ""|*[!A-Za-z0-9._-]*) echo "❌ slug 문자셋 불량 '$slug' (허용: 영숫자 . _ -)" >&2; return 10 ;;
  esac
  case "$base" in
    ""|*[!A-Za-z0-9._-]*) echo "❌ 아티팩트 파일명 불량 '$base' (허용: 영숫자 . _ -)" >&2; return 10 ;;
  esac
  # ⚠️ mkdir/쓰기 실패를 **검사한다.** 초판은 `2>/dev/null` 로 삼키고 그대로 "witnessed" 를
  # 인쇄해 rc=0 을 냈다 — cross-family 가 `CLAUDE_PROJECT_DIR` 를 일반 파일로 걸어 실제로
  # 재현했다(원장 경로가 "Not a directory" 인데 witnessed + rc=0). 증인 채널이 아무것도
  # 기록하지 못한 채 성공을 보고하는 것은 이 파일이 막으려는 바로 그 형태다.
  if ! mkdir -p "$(dirname "$LEDGER")" 2>/dev/null; then
    echo "❌ 원장 디렉토리 생성 실패: $(dirname "$LEDGER")" >&2; return 10
  fi
  if [ ! -f "$LEDGER" ]; then
    if ! cat > "$LEDGER" 2>/dev/null <<'HDR'
# Chamber ordering witness — HASHES ONLY, never content.
#
# 이 파일은 챔버 런 아티팩트의 **순서 증인**이다. 내용은 gitignored
# `tracks/_chamber/<slug>/` 에 남고 여기에는 SHA-256 만 들어온다.
# 커밋 그래프가 "무엇이 verdict 보다 먼저 고정됐는가" 를 증언한다.
#
# 생성/검증: scripts/chamber_witness.sh (record | verify | --self-test)
# ⚠️ 손으로 고치지 마라 — 손편집은 증인을 무효화한다(해시 불일치 = TAMPERED).
# ⚠️ 비공개 후보는 slug 을 익명화해서 넣어라. 이 파일은 공개 표면이다.
HDR
    then
      echo "❌ 원장 헤더 쓰기 실패: $LEDGER" >&2; return 10
    fi
  fi
  if ! printf -- '- run: %s\n  artifact: %s\n  sha256: %s\n  recorded: %s\n' \
       "$slug" "$base" "$h" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LEDGER" 2>/dev/null; then
    echo "❌ 원장 append 실패: $LEDGER" >&2; return 10
  fi
  # **쓴 것을 다시 읽어 확인한다.** append 가 rc=0 이어도 파일에 없으면 증인은 없다.
  if ! grep -q "  sha256: $h" "$LEDGER" 2>/dev/null; then
    echo "❌ 원장에 기록이 확인되지 않는다 (쓰기는 성공했다고 보고됨): $LEDGER" >&2; return 10
  fi
  echo "witnessed: $slug/$base  sha256=${h%"${h#??????????}"}…"
  return 0
}

# 이 (run, artifact, sha) **엔트리**가 처음 커밋된 시각(epoch). 미커밋이면 빈 문자열.
#
# ⚠️ 초판은 `git log -S "$sha"` 로 **해시 문자열**만 찾았다. 해시는 내용 기반이라
# 서로 다른 run 이 같은 내용(템플릿 INTENT 등)을 기록하면 **같은 sha** 가 되고, 과거 run 의
# 커밋이 현재 run 의 **미커밋** 엔트리를 커밋된 것처럼 보이게 했다 — cross-family 가
# 실제로 재현(dup_pending_rc=0). 그래서 커밋된 원장을 실제로 열어 **세 값의 조합**을 본다.
_commit_ts_of_entry() { # $1=slug $2=artifact $3=sha
  local slug="$1" art="$2" sha="$3" h ts
  git -C "$REPO_ROOT" log --format='%H %ct' --reverse -- "$LEDGER_REL" 2>/dev/null |
  while read -r h ts; do
    if git -C "$REPO_ROOT" show "$h:$LEDGER_REL" 2>/dev/null |
       awk -v s="$slug" -v a="$art" -v x="$sha" '
         /^- run:/ { cur=$3; art=""; next }
         /^  artifact:/ { art=$2; next }
         /^  sha256:/ { if (cur==s && art==a && $2==x) { found=1; exit } }
         END { exit (found?0:1) }' ; then
      printf '%s' "$ts"; break   # 파이프 서브셸이라 `return` 은 함수를 빠져나가지 못한다
    fi
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# verify — 순서/무결 판정
# ─────────────────────────────────────────────────────────────────────────────
do_verify() {
  # ⚠️ 한 `local` 문에서 앞 변수를 뒤 기본값이 참조하면 `set -u` 하에서 unbound 로 죽는다.
  # self-test 가 항상 2인자로 불러서 **1인자 경로를 한 번도 안 덮었고**, 첫 실사용에서
  # 터졌다. 아래 N7 레인이 그 경로를 고정한다.
  local slug="$1"
  local wsdir="${2:-}"
  [ -n "$wsdir" ] || wsdir="$REPO_ROOT/tracks/_chamber/$slug"
  [ -n "$slug" ] || { echo "❌ usage: verify <slug> [workspace-dir]" >&2; return 10; }
  if [ ! -f "$LEDGER" ]; then
    echo "UNWITNESSED — 원장 자체가 없다 ($LEDGER_REL). 미측정이지 위반이 아니다."
    return 2
  fi

  # 이 slug 의 엔트리 수집 (bash 3.2 호환: 배열 대신 임시파일)
  local tmp; tmp="$(mktemp -t chwit.XXXXXX 2>/dev/null)" || { echo "❌ mktemp 실패" >&2; return 10; }
  awk -v s="$slug" '
    /^- run:/ { cur=$3; art=""; sha="" ; next }
    /^  artifact:/ { art=$2; next }
    /^  sha256:/   { sha=$2; if (cur==s && art!="" && sha!="") print art"\t"sha; next }
  ' "$LEDGER" > "$tmp" 2>/dev/null

  if [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    echo "UNWITNESSED — 원장에 '$slug' 기록이 없다. 미측정이지 위반이 아니다."
    return 2
  fi

  # 판정 상태. cross-family 지적 F1·F3·F4·F6 을 반영해 재작성했다.
  local tampered=0 pending=0 unverif=0 verdict_ts="" pre_max_ts="" pre_count=0 art sha ts cur
  local have_intent=0 have_budget=0 have_sim=0
  while IFS=$'\t' read -r art sha; do
    [ -n "$art" ] || continue
    # ① 무결 — 기록된 해시와 현재 파일이 같은가.
    if [ -f "$wsdir/$art" ]; then
      cur="$(_sha "$wsdir/$art")"
      if [ -z "$cur" ]; then
        # 해시 도구 장애를 "변조 아님" 으로 읽으면 fail-open 이다(F6). 비가역 주장을
        # 받치는 계기이므로 판정을 포기하지 **정상으로 넘기지 않는다.**
        echo "  ❌ 해시 재계산 실패: $art — 무결 판정 불가 (계기 장애)" >&2
        rm -f "$tmp"; return 10
      fi
      if [ "$cur" != "$sha" ]; then
        echo "  🟥 TAMPERED: $art — 기록된 해시와 현재 파일이 다르다"
        tampered=1
      fi
    else
      # 파일 부재는 변조가 아니다(다른 머신에서 검증할 수 있다). 다만 **무결을 못 봤다는
      # 사실을 말한다** — 침묵하면 "검증됨" 으로 읽힌다.
      unverif=$((unverif + 1))
      echo "  🟡 무결 미검증: $art — 워크스페이스에 파일이 없다(순서만 판정)"
    fi
    # ② 이 엔트리가 커밋됐는가 (sha 문자열이 아니라 run+artifact+sha 조합으로 — F5)
    ts="$(_commit_ts_of_entry "$slug" "$art" "$sha")"
    if [ -z "$ts" ]; then
      echo "  🟡 PENDING: $art — 원장에 적혔지만 아직 커밋 안 됨 (증인 미성립)"
      pending=1
      continue
    fi
    if [ "$art" = "$VERDICT_NAME" ]; then
      verdict_ts="$ts"
    else
      pre_count=$((pre_count + 1))
      # ⚠️ **최댓값**을 쓴다. 초판은 최솟값을 써서 "아무 pre 하나만 verdict 보다 앞서면"
      # 통과했다 — INTENT 만 먼저 커밋하고 BUDGET/SIM_NOTES 를 verdict 뒤에 커밋해도
      # WITNESSED 였다(F4, cross-family 가 mixed_rc=0 으로 재현).
      if [ -z "$pre_max_ts" ] || [ "$ts" -gt "$pre_max_ts" ]; then pre_max_ts="$ts"; fi
      case "$art" in
        INTENT.md)    have_intent=1 ;;
        BUDGET.md)    have_budget=1 ;;
        SIM_NOTES.md) have_sim=1 ;;
      esac
    fi
  done < "$tmp"
  rm -f "$tmp"

  [ "$tampered" -eq 1 ] && { echo "TAMPERED — 증인 무효."; return 1; }

  if [ "$pending" -eq 1 ]; then
    echo "PENDING — 원장에 적혔으나 커밋되지 않은 엔트리가 있다. 아직 증인이 아니다."
    return 2
  fi

  if [ "$pre_count" -eq 0 ]; then
    echo "UNWITNESSED — pre-verdict 아티팩트 기록이 없다. 미측정."
    return 2
  fi

  # ★ verdict 미기록은 **통과가 아니다**(F1). 초판은 여기서 rc=0 을 냈고, 러너가 그걸
  # "② 승격 근거로 사용 가능" 으로 렌더했다 — 증인 채널이 증인 없이 초록을 낸 것이다.
  if [ -z "$verdict_ts" ]; then
    echo "INCOMPLETE — pre-verdict $pre_count 건은 고정됐으나 **verdict 해시가 원장에 없다**."
    echo "  순서를 비교할 대상이 없으므로 증인이 성립하지 않는다. verdict 를 record 후 재실행."
    return 2
  fi

  # 챔버는 세 게이트를 모두 거친다. 하나라도 증인이 없으면 "게이트들이 결과 전에 돌았다" 를
  # 주장할 수 없다 — 부분 증인을 완전 증인으로 렌더하지 않는다(F4).
  if [ "$have_intent" -eq 0 ] || [ "$have_budget" -eq 0 ] || [ "$have_sim" -eq 0 ]; then
    echo "INCOMPLETE — 게이트 아티팩트 증인이 일부만 있다"
    echo "  INTENT=$have_intent BUDGET=$have_budget SIM_NOTES=$have_sim (셋 다 필요)"
    return 2
  fi

  # ⚠️ `-le` 다. 같은 커밋(또는 같은 초)에 들어온 verdict 는 "먼저" 를 증명하지 못한다 —
  # 초판은 `-lt` 만 봐서 same-second 역순을 통과시켰다(F3, same_commit_rc=0 으로 재현).
  if [ "$verdict_ts" -le "$pre_max_ts" ]; then
    echo "UNORDERED — verdict 가 pre-verdict 아티팩트보다 먼저이거나 같은 시점에 커밋됐다."
    echo "  verdict_commit=$verdict_ts  latest_pre=$pre_max_ts"
    return 1
  fi

  echo "WITNESSED — 게이트 아티팩트 $pre_count 건이 전부 verdict 보다 먼저 커밋으로 고정됐다."
  echo "  latest_pre=$pre_max_ts  verdict=$verdict_ts"
  [ "$unverif" -gt 0 ] && echo "  ⚠️ 그중 $unverif 건은 무결 미검증(파일 부재) — 순서만 증명됨"
  # 명명된 잔여: 이 판정은 **로컬 커밋 그래프**만 본다. 브랜치가 main 인지, push 됐는지,
  # ruleset 이 살아 있는지는 검사하지 않는다(F7). 되쓰기 방지는 서버 설정에 의존한다.
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# self-test — known-pair 캘리브레이션
#   계기가 **positive 와 negative 를 실제로 가르는지** 본다. 한쪽만 맞히는 계기는
#   재는 게 아니라 생성하는 것이다.
# ─────────────────────────────────────────────────────────────────────────────
do_self_test() {
  local T; T="$(mktemp -d -t chwit_t.XXXXXX)" || { echo "❌ mktemp -d 실패" >&2; return 10; }
  local pass=0 fail=0
  _t() { # $1=label $2=expected-rc $3=actual-rc
    if [ "$2" = "$3" ]; then echo "✅ $1 → rc=$3"; pass=$((pass+1));
    else echo "❌ $1 → rc=$3 (기대 $2)"; fail=$((fail+1)); fi
  }
  _tgrep() { # $1=label $2=needle $3=output
    case "$3" in *"$2"*) echo "✅ $1"; pass=$((pass+1)) ;;
      *) echo "❌ $1 — 출력에 '$2' 없음"; fail=$((fail+1)) ;; esac
  }

  # 격리된 임시 레포에서 **진짜 커밋 순서**로 잰다.
  ( cd "$T" && git init -q . && git config user.email t@t && git config user.name t ) || {
    echo "❌ 임시 레포 생성 실패" >&2; rm -rf "$T"; return 10; }
  mkdir -p "$T/knowledge/shared/learnings"

  # ⚠️ 절대경로여야 한다. 상대경로면 아래 `cd "$T"` 서브셸에서 스크립트를 못 찾아
  # **전 레인이 rc=127 로 죽는다**(첫 실행 실측). 그 방향은 fail-closed 라 7/7 실패로 드러났다.
  local SELF; SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  local rc out

  # 한 run 의 게이트 3종을 만들고 record+커밋 하는 헬퍼.
  _mkrun() { # $1=slug  $2=문구접미사
    mkdir -p "$T/ws/$1"
    printf 'intent %s\n' "$2"  > "$T/ws/$1/INTENT.md"
    printf 'budget %s\n' "$2"  > "$T/ws/$1/BUDGET.md"
    printf 'sim %s\n'    "$2"  > "$T/ws/$1/SIM_NOTES.md"
    printf 'verdict %s\n' "$2" > "$T/ws/$1/EMISSION_VERDICT.md"
  }
  _rec() { ( cd "$T" && CLAUDE_PROJECT_DIR="$T" bash "$SELF" record "$1" "$T/ws/$1/$2" >/dev/null 2>&1 ); }
  _commit() { ( cd "$T" && git add -A && git commit -qm "$1" ) >/dev/null 2>&1; }
  _verify() { ( cd "$T" && CLAUDE_PROJECT_DIR="$T" bash "$SELF" verify "$1" "$T/ws/$1" 2>&1 ); }

  # ── P1 정상: 게이트 3종 커밋 → (1초 후) verdict 커밋 → WITNESSED(0)
  _mkrun good g; _rec good INTENT.md; _rec good BUDGET.md; _rec good SIM_NOTES.md; _commit "gates"
  sleep 1
  _rec good EMISSION_VERDICT.md; _commit "verdict"
  out="$(_verify good)"; rc=$?
  _t "정상(게이트3 → verdict) → WITNESSED" 0 "$rc"

  # ── N1 역순: verdict 먼저 커밋 → UNORDERED(1)
  _mkrun bad b; _rec bad EMISSION_VERDICT.md; _commit "bad verdict first"
  sleep 1
  _rec bad INTENT.md; _rec bad BUDGET.md; _rec bad SIM_NOTES.md; _commit "bad gates later"
  out="$(_verify bad)"; rc=$?
  _t "역순(verdict 먼저) → UNORDERED" 1 "$rc"

  # ── N2 변조: 커밋 후 파일을 고침 → TAMPERED(1)
  _mkrun tamper t; _rec tamper INTENT.md; _rec tamper BUDGET.md; _rec tamper SIM_NOTES.md; _commit "tamper gates"
  sleep 1; _rec tamper EMISSION_VERDICT.md; _commit "tamper verdict"
  printf 'rewritten after the fact\n' > "$T/ws/tamper/INTENT.md"
  out="$(_verify tamper)"; rc=$?
  _t "사후 재작성 → TAMPERED" 1 "$rc"

  # ── N3 미기록 slug → UNWITNESSED(2). 0 아님.
  mkdir -p "$T/ws/nonexistent"
  out="$(_verify nonexistent)"; rc=$?
  _t "미기록 slug → UNWITNESSED(2, 통과 아님)" 2 "$rc"

  # ── N4 미커밋 → PENDING(2)
  _mkrun pend p; _rec pend INTENT.md
  out="$(_verify pend)"; rc=$?
  _t "기록만 하고 미커밋 → PENDING(2)" 2 "$rc"

  # ── N5 없는 아티팩트 record → 입력 불량(10)
  ( cd "$T" && CLAUDE_PROJECT_DIR="$T" bash "$SELF" record x "$T/ws/does-not-exist.md" >/dev/null 2>&1 ); rc=$?
  _t "없는 아티팩트 record → rc=10" 10 "$rc"

  # ── N6 1인자 호출(wsdir 생략) — 죽지 않고 판정. 워크스페이스 부재라 무결은 미검증.
  ( cd "$T" && CLAUDE_PROJECT_DIR="$T" bash "$SELF" verify good >/dev/null 2>&1 ); rc=$?
  _t "1인자 호출(wsdir 생략) → 죽지 않고 WITNESSED" 0 "$rc"

  # ── N7 ★ verdict 미기록 → INCOMPLETE(2). 초판은 여기서 rc=0 을 냈다 (cross-family F1).
  _mkrun noverd n; _rec noverd INTENT.md; _rec noverd BUDGET.md; _rec noverd SIM_NOTES.md; _commit "noverd gates"
  out="$(_verify noverd)"; rc=$?
  _t "★verdict 미기록 → INCOMPLETE(2), 통과 아님" 2 "$rc"
  _tgrep "  └ 사유가 'verdict 해시가 원장에 없다' 로 인쇄된다" "verdict 해시가 원장에 없다" "$out"

  # ── N8 ★ same-commit: 게이트와 verdict 가 같은 커밋 → UNORDERED(1). 초판은 통과시켰다 (F3).
  _mkrun same s
  _rec same INTENT.md; _rec same BUDGET.md; _rec same SIM_NOTES.md; _rec same EMISSION_VERDICT.md
  _commit "same commit both"
  out="$(_verify same)"; rc=$?
  _t "★같은 커밋(pre==verdict 시각) → UNORDERED" 1 "$rc"

  # ── N9 ★ 부분 게이트: INTENT 만 먼저, BUDGET/SIM 은 verdict 뒤 → INCOMPLETE 또는 UNORDERED (F4).
  #    초판은 pre 최솟값만 봐서 WITNESSED 였다.
  _mkrun mixed m; _rec mixed INTENT.md; _commit "mixed intent"
  sleep 1; _rec mixed EMISSION_VERDICT.md; _commit "mixed verdict"
  sleep 1; _rec mixed BUDGET.md; _rec mixed SIM_NOTES.md; _commit "mixed rest"
  out="$(_verify mixed)"; rc=$?
  _t "★부분 게이트(BUDGET/SIM 이 verdict 뒤) → 통과 아님" 1 "$rc"

  # ── N10 ★ 중복 해시: 다른 run 이 **같은 내용**을 먼저 커밋해도 현재 run 의 미커밋을
  #    커밋된 것으로 읽지 않는다 (F5). 초판은 sha 문자열만 봐서 숨겼다.
  mkdir -p "$T/ws/dupA" "$T/ws/dupB"
  printf 'identical body\n' > "$T/ws/dupA/INTENT.md"
  printf 'identical body\n' > "$T/ws/dupB/INTENT.md"
  _rec dupA INTENT.md; _commit "dupA committed"
  _rec dupB INTENT.md                     # 미커밋
  out="$(_verify dupB)"; rc=$?
  _t "★중복 해시가 PENDING 을 숨기지 않는다" 2 "$rc"
  _tgrep "  └ dupB 가 PENDING 으로 인쇄된다" "PENDING" "$out"

  # ── N11 ★ 원장 쓰기 실패 → rc=10 (F2). 초판은 witnessed + rc=0 이었다.
  printf 'not a dir\n' > "$T/rootfile"
  printf 'artifact\n'  > "$T/art.md"
  ( CLAUDE_PROJECT_DIR="$T/rootfile" bash "$SELF" record wf "$T/art.md" >/dev/null 2>&1 ); rc=$?
  _t "★원장 쓰기 실패 → rc=10 (성공 렌더 금지)" 10 "$rc"

  # ── N12 ★ slug 문자셋 불량 → rc=10 (F10, 원장 파싱 파괴 방지)
  ( cd "$T" && CLAUDE_PROJECT_DIR="$T" bash "$SELF" record "bad slug:x" "$T/art.md" >/dev/null 2>&1 ); rc=$?
  _t "★slug 에 공백/콜론 → rc=10" 10 "$rc"

  # ── N13 컨트롤: 정상 케이스가 여전히 0 인가 (앞 레인이 상태를 오염시키지 않았는지)
  out="$(_verify good)"; rc=$?
  _t "컨트롤 — 정상 케이스 재확인" 0 "$rc"

  rm -rf "$T"
  echo
  if [ "$fail" -eq 0 ]; then
    echo "✅ 캘리브레이션 통과 ($pass 레인) — positive/negative 를 실제로 가른다."
    return 0
  fi
  echo "🟥 캘리브레이션 실패 ($fail/$((pass+fail)))"
  return 1
}

case "${1:---help}" in
  record)      shift; do_record "${1:-}" "${2:-}" ;;
  verify)      shift; do_verify "${1:-}" "${2:-}" ;;
  --self-test) do_self_test ;;
  *)
    sed -n '1,60p' "${BASH_SOURCE[0]}" | grep -E '^#( |$)' | sed 's/^# \{0,1\}//'
    exit 0 ;;
esac
