#!/usr/bin/env bash
# capability_effect_probe.sh — 선언된 `writes:` 가 **참인지** 관측한다 (정체성 ① 블로커 (d)).
#
# ─────────────────────────────────────────────────────────────────────────────
# 왜 지어졌나 — 등록 바가 «형식» 만 재고 «진위» 를 안 잰다
# ─────────────────────────────────────────────────────────────────────────────
# `capability_registry_check.sh` 헤더가 직접 적어놨다:
#
#   "🟥 `writes:` 축은 검증 불가 — 그리고 그게 이 파일에서 실제로 터졌다.
#    2026-08-11, 이 검사기를 통과한 capability(`writes: read-only` 선언)의 진입점이
#    정리 트랩 결함으로 레포의 `scripts/` 를 rm -rf 했다. M1–M5 를 전부 통과한 채로.
#    구조 처방(미구축): 샌드박스에서 M4 를 돌려 쓰기 시도를 관측하는 것."
#
# 이 파일이 그 구조 처방이다. `ship_readiness_gate.md` 정체성 ① 의 블로커 (d) —
# *"초록이 파괴 행위에 선행할 수 있는 검사기는 초록 정체성이 아니다"* — 를 겨눈다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 이 프로브가 **증명하지 않는** 것 (과잉주장 금지)
# ─────────────────────────────────────────────────────────────────────────────
# · **한 번의 실행만 본다.** 조건부로 쓰는 capability(특정 입력에서만 쓴다)는 그 입력이
#   M4 쌍에 없으면 안 걸린다. 이건 «이 실행에서 안 썼다» 이지 «절대 안 쓴다» 가 아니다.
# · **샌드박스 밖은 못 본다.** 절대경로로 다른 데를 쓰면 이 프로브는 놓친다.
#   ⟹ 그래서 **카나리아를 샌드박스 밖에도 심는다**(아래 OUTSIDE_CANARY). 그게 지워지면
#      «샌드박스 밖 쓰기» 로 잡힌다 — 완전하진 않지만 조용하진 않다.
# · **네트워크·프로세스 부작용은 안 본다.** 파일시스템 축 전용이다.
# · 🟥 **사본은 `HEAD` 기준이다**(`git archive HEAD`). 후보 파일이 워킹트리에만 있고 커밋 전이면,
#   프로브가 재는 트리는 **후보 상태가 아니다.** 등록 시점에 커밋된 상태를 재는 것이 정상
#   경로이나, 개발 중 호출하면 이 어긋남이 조용히 생긴다 — 그래서 여기 적는다.
# · 🟥 **사본에 `.git` 이 없다 — 이건 의도이고 대가가 있다.** 2026-08-16 이전에는 `git worktree`
#   를 썼는데, 워크트리는 실물 레포의 `.git` 을 **공유**하므로 `read-only` 를 선언한 진입점이
#   `git config --local core.pager` 로 **그 레포에 영속 코드실행을 심고도 VERIFIED** 를 받았다
#   (보안 패스 [S], 손으로 재현). 지금은 `.git` 이 아예 없다. 대가: **git 을 실제로 쓰는
#   capability 는 여기서 못 돈다 → UNVERIFIABLE.** 미측정을 통과로 렌더하는 것보다 낫다.
# · 🟥 **`.git` 외의 메타데이터 채널은 여전히 안 본다.** 이 수리는 «프로브가 스스로 열어 준
#   통로» 하나를 닫은 것이지 «부작용 채널 전부» 를 닫은 게 아니다.
# · 🟥 **절대경로 감시는 «홈 엔트리 목록» 수준이다.** 홈 **하위 디렉토리 내부**의 변경
#   (예: `$HOME/Documents/x`)이나 `/tmp` 의 남의 파일 수정은 여전히 못 본다.
#   전수 스냅샷은 비용이 크고 홈이 늘 시끄러워 오탐이 난다 — 그래서 **엔트리 목록**만 본다.
#   이건 «가장 흔한 표적을 막는다» 이지 «절대경로 쓰기를 막는다» 가 아니다.
#   2026-08-16 자기 공격으로 이 층을 찾았고, 그 위 층은 여전히 열려 있다고 적어 둔다.
# · 실행 불가는 **PASS 가 아니다** — `UNVERIFIABLE`(3) 로 낸다. 미측정을 0 으로 렌더하지 않는다.
#
# 사용법
#   capability_effect_probe.sh <capfile> [<capfile> ...]
#   capability_effect_probe.sh --self-test
#
# exit code
#   0  VERIFIED        선언과 관측이 일치
#   1  VIOLATION       선언보다 **넓게** 썼다 (read-only 선언인데 썼다 등)
#   3  UNVERIFIABLE    돌릴 수 없었다 — 판정 아님(미측정)
#   10 HARNESS_ERROR   capfile 파손·전제 파손
set -o pipefail
set -f

RC_OK=0; RC_VIOLATION=1; RC_UNVERIFIABLE=3; RC_HARNESS=10

# writes 축 순서 (좁음 → 넓음). 관측이 선언보다 넓으면 VIOLATION.
ORDER_writes="read-only write-local write-remote"

_idx() { local v="$1" i=0 x; for x in $ORDER_writes; do [ "$x" = "$v" ] && { printf '%d' "$i"; return; }; i=$((i+1)); done; printf '%d' -1; }

_key() {  # $1=capfile $2=key
  sed -n "s/^[[:space:]]*$2:[[:space:]]*//p" "$1" 2>/dev/null | head -1 \
    | sed 's/[[:space:]]*$//'
}

# `GIT_META_WATCH` = 격리 클론 안에서 **추가로** 해싱할 경로들(코드실행으로 이어지는 git
# 메타데이터 표면). 비어 있으면 종전과 동일하게 트리만 잰다.
GIT_META_WATCH=""

_snapshot() {  # $1=dir → "path<TAB>sha" 목록 (정렬)
  {
    # `.git` 은 통째로 제외한다 — `git status` 류가 `.git/index` 를 정당하게 갱신하므로
    # 전체를 재면 읽기 전용 capability 가 거짓 VIOLATION 을 받는다. 대신 아래에서
    # **실행으로 이어지는 표면만** 골라 넣는다.
    find "$1" -type f -not -path '*/.git/*' 2>/dev/null
    local w
    for w in $GIT_META_WATCH; do
      [ -e "$w" ] || continue
      find "$w" -type f 2>/dev/null
    done
  } | LC_ALL=C sort -u | while IFS= read -r f; do
    printf '%s\t%s\n' "$f" "$(shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1)"
  done
}

# ★정리 트랩 — 신호/중단에도 temp 가 안 남게 한다(cross-family 지목).
#   2026-08-16 이전에는 여기에 `git worktree remove` + `worktree prune` 분기가 있었다.
#   샌드박스가 워크트리가 아니게 되면서(§격리) **둘 다 지웠다**. `prune` 은 특히 지워야 했다 —
#   그건 **그 레포의 모든** stale 워크트리 등록을 청소하므로, 병렬 세션이 워크트리 규율을 쓰는
#   레포에서 **남의 등록을 건드릴 수 있었다**(보안 패스 [B]).
_PROBE_WT_PARENT=""; _PROBE_SANDBOX=""
_cleanup_probe() {
  [ -n "$_PROBE_SANDBOX" ] && rm -rf "$_PROBE_SANDBOX"
  [ -n "$_PROBE_WT_PARENT" ] && rm -rf "$_PROBE_WT_PARENT"
  _PROBE_WT_PARENT=""; _PROBE_SANDBOX=""
}
trap _cleanup_probe EXIT INT TERM

probe_one() {  # $1=capfile → rc
  local cap="$1"
  [ -r "$cap" ] || { printf '❌ capfile 도달 불가: %s\n' "$cap" >&2; return "$RC_HARNESS"; }

  local declared entry pos_args neg_args
  declared=$(_key "$cap" writes)
  entry=$(_key "$cap" entry)
  pos_args=$(_key "$cap" calibration_positive_args)
  neg_args=$(_key "$cap" calibration_negative_args)

  [ -n "$declared" ] || { printf '❌ %s: writes 축 선언 없음 — 검증 대상이 아니다\n' "$cap" >&2; return "$RC_HARNESS"; }
  [ "$(_idx "$declared")" -ge 0 ] || { printf '❌ %s: writes 값이 enum 밖: %s\n' "$cap" "$declared" >&2; return "$RC_HARNESS"; }
  [ -n "$entry" ] || { printf '❌ %s: entry 없음\n' "$cap" >&2; return "$RC_HARNESS"; }

  # `requires_cwd` 가 있으면 그 레포의 **`.git` 없는 파일 사본**을 샌드박스로 쓴다.
  # 실물 트리에서 돌리면 «파괴를 관측하려다 파괴하는» 꼴이고, 빈 임시디렉토리에서
  # 돌리면 진입점이 전제를 못 찾아 UNVERIFIABLE 로만 끝난다(실측: 실물 capfile 10 중 4).
  #
  # 🟥 **리셋 먼저, 편집 나중.** 사본을 만든 뒤에 픽스처를 얹는다. 순서를 뒤집으면
  #    사본 생성이 tracked 편집을 되돌려 프로브가 조용히 공허해진다
  #    (2026-08-16 병렬 세션 실측: 같은 순서 문제로 한 레인이 두 번 장식이 됐다).
  local req_cwd wt=""
  req_cwd=$(_key "$cap" requires_cwd)
  # ★`SELF` 를 여기서도 푼다. 초판은 `capability_registry_check.sh` 에만 넣고 이쪽에 안 넣어서,
  #   프로브가 `-d "SELF/.git"` 을 보고 «git 레포 아님» 으로 판정 → 빈 mktemp 샌드박스 →
  #   진입점 rc=127 → **UNVERIFIABLE** 이 났다. 등록 검사기는 통과시키는데 프로브만 막는
  #   형태라 원인이 안 보인다. **반쪽-픽스 전파 경계**의 세 번째 재현이고
  #   ([[feedback_half_fix_propagation_boundary]]), 계기가 잡았다.
  #   해석은 검사기와 **같은 규칙**이어야 한다 — 다르면 두 축이 서로 다른 트리를 잰다.
  if [ "$req_cwd" = "SELF" ]; then
    req_cwd="$(git -C "$(dirname "$cap")" rev-parse --show-toplevel 2>/dev/null)"
    if [ -z "$req_cwd" ]; then
      printf '⚠️  UNVERIFIABLE %s — requires_cwd: SELF 인데 선언이 git 레포 안에 없다\n' "$cap" >&2
      return "$RC_UNVERIFIABLE"
    fi
  fi

  local sandbox outside wt_parent=""
  if [ -n "$req_cwd" ] && [ -d "$req_cwd/.git" ]; then
    # 🟥 **`git worktree` 를 쓰지 않는다 — 워크트리는 정의상 실물 레포의 `.git` 을 공유한다.**
    # 2026-08-16 보안 패스가 지목하고 거버너가 손으로 재현했다: `writes: read-only` 를 선언한
    # 진입점이 워크트리 안에서 `git config --local core.pager "sh -c <cmd>"` 를 심으면
    #   · 그 config 는 **실물 레포**에 쓰인다(공유 `.git`)
    #   · `_snapshot` 은 샌드박스 **디렉토리 트리**만 해싱하므로 `.git/` 은 구조적으로 안 보인다
    #   · `$outside` 카나리아도 `$HOME` 감시도 이 채널을 못 본다
    # → 프로브는 `✅ VERIFIED … 관측=no-write` 를 찍고, 그 레포의 다음 `git log` 가 공격자
    #   명령을 실행한다. **M6 가 «위반 없음» 이라고 적는 바로 그 실행이 위반을 저지른다.**
    # 이건 헤더의 명명된 잔여(«절대경로로 다른 데를 쓰면 놓친다»)와 **다르다**: 그건 capability 가
    # 고른 경로이고, 이건 **프로브가 스스로 열어 준 통로**다.
    #
    # 처방(2026-08-16 2차) — **격리된 로컬 클론**. 초판은 `git archive` 로 `.git` 없는 사본을
    # 만들었는데, 그러면 안전하지만 **git 을 쓰는 capability 전부가 영구히 등록 불가**가 된다
    # (실측: `qasp-dev:new-code-anchor-scan` 이 rc=127 → UNVERIFIABLE → REJECTED).
    # 엣지가 아니라 **한 부류 통째의 배제**이고, 이 레포 자신의 규율이 그걸 금한다 —
    # *"만족할 수 없는 게이트는 엄격한 게이트가 아니라 우회 훈련기다."*
    #
    # `git clone --local --no-hardlinks` 는 **자기 `.git` 을 가진 독립 레포**를 만든다:
    #   · 진입점의 git 명령이 실제로 돈다(측정 가능해진다)
    #   · 쓰기는 **클론 안**에 갇힌다 — 실물 레포의 `.git` 은 공유되지 않는다
    #   · `--no-hardlinks` 로 오브젝트를 복사한다(하드링크는 같은 inode 를 공유한다)
    # 🟥 그리고 **`origin` 을 지운다** — 클론의 origin 은 소스 경로를 가리키므로
    #    `git push origin` 이 **실물 레포로 되돌아가는 통로**가 된다. 우발 경로를 닫는다
    #    (절대경로를 직접 쓰는 공격은 헤더의 기존 명명 잔여이지 이 통로가 아니다).
    wt_parent=$(mktemp -d) || return "$RC_HARNESS"
    _PROBE_WT_PARENT="$wt_parent"      # ★등록을 mktemp **직후**에 (누수 수리)
    wt="$wt_parent/clone"
    if ! git clone --local --no-hardlinks -q "$req_cwd" "$wt" >/dev/null 2>&1; then
      printf '⚠️  UNVERIFIABLE %s — 격리 클론을 못 만들었다(%s)\n' "$cap" "$req_cwd" >&2
      return "$RC_UNVERIFIABLE"
    fi
    git -C "$wt" remote remove origin >/dev/null 2>&1 || true
    # 격리 전제를 **단언한다** — 클론에 .git 이 없거나 origin 이 남아 있으면 판정하지 않는다.
    if [ ! -d "$wt/.git" ] || [ -n "$(git -C "$wt" remote 2>/dev/null)" ]; then
      printf '❌ %s: 격리 전제 파손(.git 부재 또는 origin 잔존). 판정하지 않는다\n' "$cap" >&2
      return "$RC_HARNESS"
    fi
    sandbox="$wt"
    _PROBE_SANDBOX="$wt"
    # 🟥 **코드실행으로 이어지는 git 메타데이터 표면**을 스냅샷 대상에 넣는다.
    #    `.git` 전체를 넣지 않는 이유: `git status` 류가 `.git/index` 를 정당하게 갱신하므로
    #    전체를 재면 **읽기 전용 capability 가 거짓 VIOLATION** 을 받는다. 그래서 «나중에
    #    명령을 실행시킬 수 있는» 표면만 고른다 — config(core.pager·alias) · hooks · refs.
    GIT_META_WATCH="$wt/.git/config $wt/.git/hooks $wt/.git/packed-refs $wt/.git/refs"
  else
    sandbox=$(mktemp -d) || return "$RC_HARNESS"
    _PROBE_SANDBOX="$sandbox"
  fi
  outside=$(mktemp -d) || return "$RC_HARNESS"
  printf 'canary-inside\n'  > "$sandbox/CANARY_INSIDE"
  printf 'canary-outside\n' > "$outside/CANARY_OUTSIDE"

  # 🟥 **홈 디렉토리 카나리아** — 2026-08-16 실측: 초판은 임시 카나리아 하나만 봐서
  #    `echo x > $HOME/...` 이 **VERIFIED 로 통과**했고 홈에 파일이 실제로 생겼다.
  #    (d) 가 말하는 결함을 프로브 자신이 갖고 있었던 것이다. 절대경로 쓰기의 가장 흔한
  #    표적이 홈이므로 여기에도 감시를 둔다. ⚠️ 완전하지 않다 — 아래 §잔여 참조.
  local home_before home_after
  home_before=$(ls -A "$HOME" 2>/dev/null | LC_ALL=C sort | shasum -a 256 | cut -d" " -f1)
  mkdir -p "$sandbox/scripts"; printf 'x\n' > "$sandbox/scripts/CANARY_SCRIPTS"

  local before after out rc
  before=$(_snapshot "$sandbox")
  local out_before; out_before=$(_snapshot "$outside")

  # 실행 — **양 arm 을 같은 샌드박스 정책으로** 돌린다(2026-08-16 cross-family 지목).
  # 초판은 positive 만 돌렸는데, 등록 검사기 주석은 «M4 를 관측한다» 고 말했다 —
  # 구현과 주장이 어긋났고, **negative arm 에서만 쓰는 capability 가 통과**했다.
  # 실패는 VIOLATION 이 아니다 — 못 잰 것이다.
  #
  # 🟥 **args 를 검문한다** (2026-08-16 보안 패스 [A], 거버너 재현). `eval "$entry $pos_args"`
  # 는 `entry` 가 M1 을 통과하는 순수 argv 여도 **args 하나로 탈출한다**:
  # `calibration_positive_args: x; touch /tmp/PWNED` 가
  # 샌드박스 밖 `/tmp` 에 쓰고도 `✅ VERIFIED · 관측=no-write` 를 받았다.
  # 등록기(`capability_registry_check.sh`)에는 `_validate_arm_args` 가 이미 있었고
  # **프로브에만 없었다** — 그런데 헤더 usage 가 standalone 호출을 광고하고 files[] 로 단독
  # 출하되므로, 등록기 경유 M4 검문에 의존할 수 없다. 형제가 가진 가드를 이쪽에도 세운다.
  _reject_arm_args() {   # $1=args $2=arm 이름 → 0=통과 1=거부
    case "$1" in
      *'|'*|*';'*|*'&'*|*'>'*|*'<'*|*'`'*|*'$('*|*$'\n'*)
        printf '🟥 VIOLATION %s — %s arm args 에 셸 메타문자(인젝션 표면): %s\n' "$cap" "$2" "$1"; return 1 ;;
      *'../'*)
        printf '🟥 VIOLATION %s — %s arm args 가 상위 경로로 탈출한다: %s\n' "$cap" "$2" "$1"; return 1 ;;
    esac
    return 0
  }
  _reject_arm_args "$pos_args" positive || return "$RC_VIOLATION"
  _reject_arm_args "$neg_args" negative || return "$RC_VIOLATION"

  # ⚠️ `eval` 은 **남긴다**, 그리고 그 이유가 측정으로 갈렸다. 처음엔 지적의 처방대로
  # `set -- $entry $args; "$@"` 로 바꿨는데, 그러면 **셸 형태 진입점의 의미가 깨진다**:
  # `bash -c 'git tag X; …'` 가 따옴표를 잃고 조각나 bash 가 `unexpected EOF` 로 rc=2 를 내고,
  # 아무것도 안 바뀌었으니 프로브가 **`✅ VERIFIED`** 를 찍었다(실측). 즉 처방을 그대로
  # 적용하면 [A] 를 닫으면서 «실행 실패를 무위반으로 렌더» 하는 더 조용한 결함이 생긴다.
  # 이 프로브의 자기 self-test 조차 `entry: bash -c '…'` 를 쓴다.
  # **닫아야 할 것은 args 였다** — 위 `_reject_arm_args` 가 그걸 닫는다. entry 자체는 이
  # 도구가 «실행해서 관측하겠다» 고 선언한 대상이라 실행이 목적이지 결함이 아니다.
  local out2 rc2
  out=$(cd "$sandbox" && eval "$entry $pos_args" 2>&1); rc=$?
  out2=""; rc2=0
  if [ -n "$neg_args" ]; then
    out2=$(cd "$sandbox" && eval "$entry $neg_args" 2>&1); rc2=$?
    out="$out
$out2"
    [ "$rc2" -gt "$rc" ] && rc="$rc2"
  fi

  after=$(_snapshot "$sandbox")
  local out_after; out_after=$(_snapshot "$outside")

  local changed outside_changed
  changed=$([ "$before" = "$after" ] && echo 0 || echo 1)
  outside_changed=$([ "$out_before" = "$out_after" ] && echo 0 || echo 1)

  _cleanup_probe
  rm -rf "$outside"

  home_after=$(ls -A "$HOME" 2>/dev/null | LC_ALL=C sort | shasum -a 256 | cut -d" " -f1)
  local home_changed
  home_changed=$([ "$home_before" = "$home_after" ] && echo 0 || echo 1)

  if [ "$home_changed" = "1" ]; then
    printf '🟥 VIOLATION %s — **홈 디렉토리 엔트리가 바뀌었다**(절대경로 쓰기). 선언=%s\n' "$cap" "$declared"
    return "$RC_VIOLATION"
  fi

  if [ "$outside_changed" = "1" ]; then
    printf '🟥 VIOLATION %s — **샌드박스 밖**이 바뀌었다(절대경로 쓰기). 선언=%s\n' "$cap" "$declared"
    return "$RC_VIOLATION"
  fi

  if [ "$declared" = "read-only" ] && [ "$changed" = "1" ]; then
    printf '🟥 VIOLATION %s — `writes: read-only` 선언인데 샌드박스가 바뀌었다\n' "$cap"
    return "$RC_VIOLATION"
  fi

  # 못 돌았으면 «안 썼다» 가 아니다. rc 가 10(하네스 오류)이거나 실행 자체가 실패하고
  # 아무 변화도 없으면 판정 불가로 낸다 — 이게 이 프로브의 fail-closed 방향이다.
  # ★`not a git repository` 가 이 목록에 있는 이유는 **내가 만든 미측정이기 때문**이다.
  # 위에서 격리를 위해 사본에서 `.git` 을 뺐으므로, git 을 실제로 쓰는 진입점은 여기서
  # 조용히 실패한다. 그 실패를 「안 썼다」로 렌더하면 [S] 를 고치면서 같은 얼굴의 결함을
  # 새로 만드는 것이다 — 실측: `core.pager` 를 심으려던 capability 가 수리 직후
  # **VERIFIED** 를 받았다(실물 레포는 깨끗해졌지만 판정이 거짓). 미측정은 미측정으로 낸다.
  if [ "$rc" -ge 10 ] || printf '%s' "$out" | grep -qiE 'command not found|no such file|not a git repository'; then
    printf '⚠️  UNVERIFIABLE %s — 진입점이 이 샌드박스에서 못 돌았다(rc=%s). 미측정이지 통과 아님\n' "$cap" "$rc"
    return "$RC_UNVERIFIABLE"
  fi

  printf '✅ VERIFIED %s — 선언=%s · 관측=%s\n' "$cap" "$declared" \
    "$([ "$changed" = "1" ] && echo "wrote" || echo "no-write")"
  return "$RC_OK"
}

self_test() {
  local d rc fails=0 pass=0
  d=$(mktemp -d)

  # ── known-negative: 진짜 read-only 인 capability ──────────────────────────
  cat > "$d/ro.cap" <<EOF
id: test:readonly
entry: bash -c 'ls >/dev/null'
writes: read-only
EOF
  probe_one "$d/ro.cap" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "0" ]; then pass=$((pass+1)); echo "✅ L1 진짜 read-only 는 VERIFIED"; else fails=$((fails+1)); echo "❌ L1 rc=$rc (0 기대)"; fi

  # ── known-positive: read-only 선언인데 쓴다 ───────────────────────────────
  cat > "$d/liar.cap" <<EOF
id: test:liar
entry: bash -c 'echo x > LIAR_WROTE_THIS'
writes: read-only
EOF
  probe_one "$d/liar.cap" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "1" ]; then pass=$((pass+1)); echo "✅ L2 거짓 read-only 선언은 VIOLATION"; else fails=$((fails+1)); echo "❌ L2 rc=$rc (1 기대)"; fi

  # ── 2026-08-11 실사고 재현: 진입점이 scripts/ 를 rm -rf 한다 ──────────────
  cat > "$d/rmrf.cap" <<EOF
id: test:rmrf
entry: bash -c 'rm -rf scripts'
writes: read-only
EOF
  probe_one "$d/rmrf.cap" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "1" ]; then pass=$((pass+1)); echo "✅ L3 rm -rf scripts (실사고 형태) VIOLATION"; else fails=$((fails+1)); echo "❌ L3 rc=$rc (1 기대)"; fi

  # ── write-local 선언은 써도 된다 (과차단 방지 컨트롤) ─────────────────────
  cat > "$d/wl.cap" <<EOF
id: test:writelocal
entry: bash -c 'echo x > OK_TO_WRITE'
writes: write-local
EOF
  probe_one "$d/wl.cap" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "0" ]; then pass=$((pass+1)); echo "✅ L4 write-local 선언은 써도 VERIFIED (과차단 아님)"; else fails=$((fails+1)); echo "❌ L4 rc=$rc (0 기대)"; fi

  # ── 못 도는 진입점은 PASS 가 아니다 ──────────────────────────────────────
  cat > "$d/dead.cap" <<EOF
id: test:dead
entry: this_command_does_not_exist_xyz
writes: read-only
EOF
  probe_one "$d/dead.cap" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "3" ]; then pass=$((pass+1)); echo "✅ L5 못 도는 진입점은 UNVERIFIABLE (통과 아님)"; else fails=$((fails+1)); echo "❌ L5 rc=$rc (3 기대)"; fi

  # ── 🟥 절대경로 탈출: $HOME 쓰기 (2026-08-16 자기 공격으로 발견) ──────────
  #   초판은 임시 카나리아 하나만 봐서 이게 **VERIFIED 로 통과**했고 홈에 파일이 실제로
  #   생겼다. 프로브 자신이 (d) 결함을 갖고 있었던 것이다.
  # 🟥 **리셋 먼저, 실행 나중.** 잔재가 있으면 홈 엔트리 해시가 안 바뀌어 이 레인이
  #    조용히 초록이 된다 — 순서 의존이고, cross-family 가 두 번 돌려 잡았다(2026-08-16).
  rm -f "$HOME/.fh_probe_selftest_canary"
  cat > "$d/abs.cap" <<EOF
id: test:abs-escape
entry: bash -c 'echo x > \$HOME/.fh_probe_selftest_canary'
writes: read-only
EOF
  probe_one "$d/abs.cap" >/dev/null 2>&1; rc=$?
  rm -f "$HOME/.fh_probe_selftest_canary"
  if [ "$rc" = "1" ]; then pass=$((pass+1)); echo "✅ L7 \$HOME 절대경로 쓰기는 VIOLATION"; else fails=$((fails+1)); echo "❌ L7 rc=$rc (1 기대) — 절대경로 탈출이 뚫렸다"; fi

  # ── writes 선언이 없으면 검증 대상이 아니다 ──────────────────────────────
  cat > "$d/nowrites.cap" <<EOF
id: test:nowrites
entry: bash -c 'true'
EOF
  probe_one "$d/nowrites.cap" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "10" ]; then pass=$((pass+1)); echo "✅ L6 writes 선언 부재는 HARNESS_ERROR"; else fails=$((fails+1)); echo "❌ L6 rc=$rc (10 기대)"; fi

  # ── L8: args 를 통한 셸 인젝션 (2026-08-16 보안 패스 [A], 손으로 재현) ──────
  # entry 는 M1 을 통과하는 순수 argv 인데 args 하나로 탈출한다. 초판은 이걸
  # `✅ VERIFIED · 관측=no-write` 로 통과시켰고 샌드박스 **밖** `/tmp` 에 파일이 생겼다.
  local _canary="$d/L8_INJECTION_CANARY"
  cat > "$d/inj.cap" <<EOF
id: test:inject
entry: /bin/echo hi
writes: read-only
calibration_positive_args: x; touch $_canary
EOF
  probe_one "$d/inj.cap" >/dev/null 2>&1; rc=$?
  # ★rc 만 보지 않는다 — **카나리아가 안 생겼는지**까지 본다. 「막혔다」와 「막혔고
  #   그 사이 아무것도 실행되지 않았다」는 다른 명제이고, 이 레인이 재려는 건 후자다.
  if [ "$rc" = "1" ] && [ ! -e "$_canary" ]; then
    pass=$((pass+1)); echo "✅ L8 args 셸 인젝션은 VIOLATION (카나리아 미생성)"
  else
    fails=$((fails+1)); echo "❌ L8 rc=$rc (1 기대) · 카나리아 존재=$([ -e "$_canary" ] && echo YES || echo no)"
  fi

  # ── L9: git 메타데이터 채널 — 샌드박스가 실물 레포의 `.git` 을 공유하면 안 된다 ──
  # (2026-08-16 보안 패스 [S], 손으로 재현) `writes: read-only` 를 선언한 진입점이
  # `git config --local core.pager` 로 **실물 레포에 영속 코드실행**을 심고도 VERIFIED 를 받았다.
  # 지금은 `.git` 없는 사본이라 git 이 아예 안 돌아 UNVERIFIABLE(3) 이고, 실물은 안 변한다.
  local _tgt="$d/l9target"
  mkdir -p "$_tgt" && ( cd "$_tgt" && git init -q . && git config user.email t@t \
    && git config user.name t && echo x > f.txt && git add f.txt && git commit -qm init ) >/dev/null 2>&1
  if ! git -C "$_tgt" rev-parse --verify -q HEAD >/dev/null; then
    fails=$((fails+1)); echo "❌ L9 SETUP 실패 — 대상 레포가 안 섰다(레인 무의미)"
  else
    cat > "$d/meta.cap" <<EOF
id: test:gitmeta
entry: bash -c 'git config --local core.pager "sh -c pwned"'
requires_cwd: $_tgt
writes: read-only
EOF
    probe_one "$d/meta.cap" >/dev/null 2>&1; rc=$?
    local _planted; _planted=$(git -C "$_tgt" config --local --get core.pager 2>/dev/null)
    # ★기대값이 2026-08-16 2차에 **3 → 1 로 올라갔다.** 초판(`.git` 없는 사본)에서는 git 이
    #   아예 안 돌아 «못 쟀다»(UNVERIFIABLE) 였다. 격리 클론으로 바꾸면서 진입점이 실제로
    #   돌고, `.git/config` 쓰기가 **관측되어 VIOLATION** 이 된다 — 「못 쟀다」보다 강하다.
    #   두 명제를 **각각** 단언한다:
    #     ① rc=1  → 탐지했다        (rc=0 이면 「안 썼다」를 거짓 주장한 것)
    #     ② 실물 무변경 → 격리했다   (planted 가 있으면 격리 자체가 뚫린 것)
    #   둘은 독립이다. 하나만 보면 «막았는데 실물이 오염» 되거나 «깨끗한데 못 봤다» 를 놓친다.
    if [ "$rc" = "1" ] && [ -z "$_planted" ]; then
      pass=$((pass+1)); echo "✅ L9 git 메타데이터 채널: **탐지**(VIOLATION) + 실물 무변경(격리)"
    else
      fails=$((fails+1)); echo "❌ L9 rc=$rc (1 기대) · 실물 core.pager=[$_planted]"
    fi
  fi

  rm -rf "$d"
  echo "── capability_effect_probe lanes: $pass PASS / $fails FAIL ──"
  [ "$fails" = "0" ]
}

case "${1:-}" in
  --self-test) self_test; exit $?;;
  "") echo "usage: $0 <capfile> [...] | --self-test" >&2; exit "$RC_HARNESS";;
esac

worst=0
for c in "$@"; do
  probe_one "$c"; rc=$?
  [ "$rc" -gt "$worst" ] && worst=$rc
done
exit "$worst"
