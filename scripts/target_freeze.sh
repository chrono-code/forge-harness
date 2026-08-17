#!/usr/bin/env bash
# target_freeze.sh — 발주한 감사의 **대상을 동결**하고, 회수 시 그게 같은 대상인지 대조한다.
#
# ## 왜 (N=3, 2026-08-17 운영자 승인)
#
# 같은 결함이 하루에 세 번 났다: ① cross-family 리뷰에 **수리 이전** diff 발송 ② 리뷰 출력을
# `tail` 로 잘라 지적·핀 유실 ③ 스캔 후 파일 편집으로 라인 번호 밀림. 셋 다 「보낸 것/읽은
# 것이 지금 트리가 맞나」를 안 찍어서 생겼고, **산문 규율은 이미 있었는데 세 번 다 안 걸렸다**
# (`steel-quench/SKILL.md §PIN THE TARGET`). 그래서 산문이 아니라 스크립트다.
#
# ## 🟥 선행 실패 2종을 피한다 — 이건 3번째 시도다
#
# 같은 SKILL.md 가 두 번의 기계화 실패를 이미 기록해 뒀다:
#   ① 훅 advisory  → 마커 100% 에서 발화 = 배경 소음, 수렴 탐지기가 어휘를 못 맞춤 → 제거
#   ② `base-SHA + diff 줄 수` 지문 → **in-place 편집에 불변**(산문 수리의 기본 형태!)이고
#      untracked 에 구조적으로 맹목 → 제거
# ⇒ 그래서 여기서는 **줄 수가 아니라 내용을 해시**하고(①의 반대), untracked 를 **따로**
#   센다(②의 반대). 훅에 안 건다 — 발주자가 명시적으로 부르는 두 커맨드다.
#
# ## 설계 제약 (전부 이 레포의 기존 실패에서 나왔다)
#   ⓐ tracked 변경 + untracked 를 **content-address** (steel-quench L450)
#   ⓑ `assume-unchanged`/`skip-worktree` 은폐 검사 필수 (publish_freshness_check.sh:61)
#   ⓒ git 실패 = **UNKNOWN**, 절대 clean 아님 (session_close_check.sh:38-48)
#   ⓓ `.git` 전체를 지문에 넣지 않는다 — `index` 가 정당하게 갱신돼 거짓 불일치
#      (capability_effect_probe.sh:253)
#   ⓔ 판정 키는 트리가 아니라 **세션** (branch_claim.sh:13-20)
#   ⓕ 사이드카는 트리를 못 읽는 경우가 많다 → **발주자 측 대조**여야 한다
#      (auto-decorrelation/SKILL.md:191)
#
# ## 사용
#   bash scripts/target_freeze.sh pin    <repo> <label>   # 발주 직전. 지문 토큰을 stdout 에
#   bash scripts/target_freeze.sh verify <repo> <label>   # 회수 직후. 불일치면 WRONG-TARGET
#   bash scripts/target_freeze.sh show   <repo> <label>
#
# ## 종료 코드
#   0   MATCH        — 대상이 그대로다
#   1   WRONG-TARGET — 대상이 움직였다. **그 라운드의 판정을 무효화하라**
#   10  UNKNOWN      — 잴 수 없었다(git 실패·해시 도구 부재·핀 없음). 미측정이지 통과 아님
#
# 🟥 **이 스크립트는 «내가 보낸 내용»이 아니라 «대상 트리»를 잰다.** 사이드카에 파일을
#    인라인해 보냈다면 그 인라인 내용의 해시도 따로 결박해야 한다(ⓕ) — 여기서는 안 한다.
#    범위를 넓게 주장하지 않으려고 명시한다.

set -u

_die_unknown() { printf 'UNKNOWN — %s\n' "$1" >&2; exit 10; }

# 🟥 **`git -C` 는 `GIT_DIR`/`GIT_WORK_TREE` 를 못 이긴다** (cross-family agy, 2026-08-18).
#    호출자 환경에 그 변수가 남아 있으면 이 스크립트는 **엉뚱한 레포**를 재고도 «정상 경로를
#    동결했다» 고 보고한다. 지문 계기가 대상을 틀리는 형태라 다른 모든 지적보다 상위다.
_git() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE git "$@"; }

_sha() {
  # chamber_witness.sh:84 와 같은 형태(macOS/linux 폴백). 도구 없으면 fail-closed.
  #
  # 🟥 **`| awk` 로 잘라내지 않는다** (cross-family codex, 2026-08-18, 재현 확인).
  #    `shasum | awk` 는 shasum 의 rc 를 잃는다 — 해시 도구가 특정 입력에서 실패해도
  #    awk 는 rc 0 을 내고 stdout 이 비어, 서로 다른 내용이 **같은 빈 지문**을 받아 MATCH 가
  #    된다. 게이트 안에서 이 형태가 fail-open 이다.
  local out rc
  if command -v shasum >/dev/null 2>&1; then out=$(shasum -a 256); rc=$?
  elif command -v sha256sum >/dev/null 2>&1; then out=$(sha256sum); rc=$?
  else return 3; fi
  [ "$rc" -eq 0 ] || return 3
  out=${out%% *}
  [ -n "$out" ] || return 3
  printf '%s\n' "$out"
}

_label_key() {
  # 🟥 문자 치환으로 파일명을 만들지 않는다 — `a/b` 와 `a_b` 가 **같은 핀 파일**이 되어,
  #    핀한 적 없는 라벨을 verify 하면 MATCH 가 나온다(cross-family codex, 재현 확인).
  #    해시는 충돌하지 않으므로 라벨 공간이 파일명 공간에 안전하게 들어간다.
  printf '%s' "$1" | _sha
}

_fingerprint() {
  # stdout: <64자 해시>  ·  실패 시 비영 종료 + stdout 은 **빈다**
  # 🟥 명령이 실패하면서 stdout 에 무언가를 뱉는 형태를 만들지 않는다 — 그러면 폴백 없이도
  #    쓰레기 값이 지문이 되고, 대조가 «항상 일치» 로 조용히 무너진다.
  local repo="$1" head diff_patch untracked hidden combined subs files rc

  # 🟥 `HEAD` 가 아니라 **트리 해시**를 쓴다 (cross-family codex, 재현 확인). 이 지문의
  #    주장은 «감사한 내용이 그대로인가» 이고, 빈 커밋(`--allow-empty`)은 내용을 안 바꾸는데
  #    HEAD 만 움직여 **정상 조작이 WRONG-TARGET** 이 됐다. 오탐이 잦으면 이 게이트는
  #    override 를 습관화시키고 그건 폐기 경로다.
  head=$(_git -C "$repo" rev-parse "HEAD^{tree}" 2>&1) || { printf '%s\n' "$head" >&2; return 1; }

  # ⓑ 은폐 비트 — 이게 켜져 있으면 tracked 변경이 diff 에 안 나온다. 지문이 거짓말을 하므로
  #    「일치」를 낼 자격이 없다.
  hidden=$(_git -C "$repo" ls-files -v 2>&1) || { printf '%s\n' "$hidden" >&2; return 1; }
  if printf '%s\n' "$hidden" | grep -qE '^[hS]'; then
    printf 'assume-unchanged/skip-worktree 비트가 켜져 있다 — 지문이 변경을 못 본다\n' >&2
    return 2
  fi

  # ⓐ-1 tracked 변경: **줄 수가 아니라 패치 내용**. staged 포함(HEAD 기준).
  diff_patch=$(_git -C "$repo" diff HEAD 2>&1) || { printf '%s\n' "$diff_patch" >&2; return 1; }

  # ⓐ-2 서브모듈: `git diff HEAD` 는 서브모듈 포인터만 보고 **그 안의 dirty 내용은 못 본다**
  #      (cross-family codex, 재현 확인 — 서브모듈 파일을 고쳐도 MATCH 였다).
  #      `--recursive` 상태 문자열이 dirty 표식(`+`)과 SHA 를 함께 낸다.
  #      🟥 `submodule status` **만으로는 부족하다**: 그 줄은 서브모듈의 HEAD 를 말하므로,
  #      서브모듈 워킹트리를 고치기만 하면(커밋 없이) SHA 가 안 바뀌어 여전히 MATCH 였다
  #      (수리 1차본이 그랬고, 재현으로 잡았다). 각 서브모듈 **안으로 내려가** 상태와
  #      패치 내용을 함께 해시에 넣는다.
  subs=$(_git -C "$repo" submodule status --recursive 2>&1) || { printf '%s\n' "$subs" >&2; return 1; }
  if [ -n "$subs" ]; then
    # 🟥 미초기화 서브모듈(`-<sha> path`)은 `foreach` 가 **건너뛴다**(agy 지적). 그 안의
    #    내용은 지문에 한 글자도 안 들어가므로 «같다» 를 낼 자격이 없다.
    if printf '%s\n' "$subs" | grep -q '^-'; then
      printf '미초기화 서브모듈이 있다 — 그 안을 못 잰다(git submodule update --init 후 재시도)\n' >&2
      return 2
    fi
    local subdetail
    subdetail=$(_git -C "$repo" submodule foreach --recursive --quiet \
                  'git status --porcelain --untracked-files=all && git diff HEAD' 2>&1) \
      || { printf '%s\n' "$subdetail" >&2; return 1; }
    subs="${subs}"$'\n'"${subdetail}"
  fi

  # ⓐ-3 untracked(무시되지 않은 것): 경로 + 내용 해시.
  # 🟥 **파이프 안에서 목록을 만들지 않는다** — `git ls-files -o | while … | sort` 는 git 의
  #    rc 를 마지막 `sort` 의 rc 로 덮는다. 목록 취득이 실패해도 «untracked 없음» 으로 접혀
  #    MATCH 가 나왔다(재현 확인). 목록을 먼저 변수로 받고 rc 를 본다.
  # ★NUL 구분자는 `$( )` 가 삼킨다 — 목록은 **임시 파일**로 받아야 rc 도 보고 구분자도 산다.
  files=$(mktemp) || return 3
  _git -C "$repo" ls-files -o --exclude-standard -z >"$files" 2>/dev/null; rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -f "$files"
    printf 'ls-files -o 실패(rc=%s) — untracked 를 못 쟀다\n' "$rc" >&2
    return 1
  fi

  untracked=""
  while IFS= read -r -d '' f; do
    local entry
    if [ -L "$repo/$f" ]; then
      # 🟥 심볼릭 링크는 **가리키는 문자열**이 내용이다. `-f` 로만 보면 깨진 링크의
      #    재지정(retarget)을 통째로 놓친다(재현 확인).
      entry="LINK $(readlink "$repo/$f" 2>/dev/null || printf 'UNREADABLE')"
    elif [ -d "$repo/$f" ]; then
      # 🟥 untracked **디렉토리**는 `ls-files -o` 가 한 항목으로 접는다(중첩 git repo 가
      #    대표 사례). 그 안의 내용 변경을 이 지문은 못 본다 ⇒ «놓쳤다» 를 «같다» 로
      #    렌더하지 않고 **잴 수 없음(UNKNOWN)으로 fail-closed** 한다.
      printf 'untracked 디렉토리를 만났다(%s) — 내용까지 못 잰다\n' "$f" >&2
      rm -f "$files"; return 2
    elif [ -f "$repo/$f" ]; then
      # 🟥 **모드도 내용이다** (agy 지적). tracked 파일은 `git diff` 가 `old mode/new mode`
      #    를 내지만 untracked 는 스트림만 해시해서, `chmod +x` 가 지문에 안 잡혔다.
      #    이 레포는 실행 비트 소실로 훅이 조용히 무장해제된 이력이 있다
      #    ([[feedback_exec_bit_loss_disarms_hooks_silently]]).
      local mode; if [ -x "$repo/$f" ]; then mode=x; else mode=-; fi
      entry="$mode $(_sha <"$repo/$f")" || { rm -f "$files"; return 3; }
      case "$entry" in "$mode ") rm -f "$files"; return 3 ;; esac
    else
      entry="NOTAFILE"
    fi
    untracked="${untracked}${f} ${entry}"$'\n'
  done <"$files"
  rm -f "$files"
  untracked=$(printf '%s' "$untracked" | LC_ALL=C sort)

  # 🟥 **필드를 이어붙이고 한 번 해시하지 않는다** (agy 지적): `---` 는 diff 패치의 표준
  #    헤더(`--- a/file`)라 필드 경계가 내용에 나타날 수 있고, 그러면 서로 다른 상태가 같은
  #    결합 문자열을 만들 여지가 생긴다. 각 필드를 **먼저 해시**해 길이를 고정한 뒤 잇는다.
  local h_head h_diff h_subs h_untracked
  h_head=$(printf '%s' "$head" | _sha) || return 3
  h_diff=$(printf '%s' "$diff_patch" | _sha) || return 3
  h_subs=$(printf '%s' "$subs" | _sha) || return 3
  h_untracked=$(printf '%s' "$untracked" | _sha) || return 3

  # 🟥 **TOCTOU** (agy 지적): 위 단계들은 원자적 스냅샷이 아니다. 1단계 뒤에 누가
  #    `git commit -a` 를 하면 «옛 트리 + 빈 diff» 라는 **한 순간도 존재한 적 없는 상태**가
  #    핀으로 저장되고, 그 뒤 아무 변경이 없어도 verify 가 WRONG-TARGET 을 낸다.
  #    ⇒ 끝에서 트리를 다시 읽어 **읽는 동안 움직였으면 지문을 내지 않는다**(fail-closed).
  local head2
  head2=$(_git -C "$repo" rev-parse "HEAD^{tree}" 2>/dev/null) || return 1
  if [ "$head2" != "$head" ]; then
    printf '지문 계산 도중 트리가 움직였다 — 스냅샷이 일관되지 않는다\n' >&2
    return 2
  fi

  combined=$(printf '%s %s %s %s\n' "$h_head" "$h_diff" "$h_subs" "$h_untracked" | _sha) || return 3
  [ -n "$combined" ] || return 3
  printf '%s\n' "$combined"
}

_pin_path() {
  local repo="$1" label="$2" gitdir sid
  gitdir=$(_git -C "$repo" rev-parse --git-common-dir 2>/dev/null) || return 1
  case "$gitdir" in /*) : ;; *) gitdir="$repo/$gitdir" ;; esac
  # ⓔ 세션 키 — branch_claim.sh:86-91 과 같은 상속 경로.
  sid="${CLAUDE_CODE_SESSION_ID:-${CLAUDE_SESSION_ID:-local}}"
  printf '%s/fh-targets/%s\n' "$gitdir" "$sid"
}

main() {
  local cmd="${1:-}" repo="${2:-}" label="${3:-}"
  [ -n "$cmd" ] && [ -n "$repo" ] && [ -n "$label" ] || {
    printf 'usage: target_freeze.sh {pin|verify|show} <repo> <label>\n' >&2; exit 10; }
  [ -d "$repo" ] || _die_unknown "레포 경로가 없다: $repo"
  _git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || _die_unknown "git 레포가 아니다: $repo"

  local dir fp rc
  dir=$(_pin_path "$repo" "$label") || _die_unknown "git-common-dir 를 못 읽었다"
  local lkey; lkey=$(_label_key "$label") || _die_unknown "라벨 키를 못 만들었다(해시 도구 부재)"
  local file="$dir/${lkey}.fp"

  case "$cmd" in
    pin)
      fp=$(_fingerprint "$repo"); rc=$?
      [ "$rc" -eq 0 ] && [ -n "$fp" ] || _die_unknown "지문을 못 냈다 (rc=$rc)"
      mkdir -p "$dir" || _die_unknown "핀 저장 디렉토리를 못 만들었다"
      printf '%s\n' "$fp" >"$file" || _die_unknown "핀을 못 썼다"
      # 발주 프롬프트에 그대로 박을 한 줄.
      printf 'TARGET-FINGERPRINT %s %s\n' "$label" "${fp:0:16}"
      ;;
    verify)
      [ -f "$file" ] || _die_unknown "핀이 없다 — 발주 전에 pin 을 안 했다 ($label)"
      local pinned; pinned=$(cat "$file") || _die_unknown "핀을 못 읽었다"
      fp=$(_fingerprint "$repo"); rc=$?
      [ "$rc" -eq 0 ] && [ -n "$fp" ] || _die_unknown "지문을 못 냈다 (rc=$rc)"
      if [ "$fp" = "$pinned" ]; then
        printf 'MATCH %s %s\n' "$label" "${fp:0:16}"; exit 0
      fi
      printf 'WRONG-TARGET %s — 핀 %s / 현재 %s\n' "$label" "${pinned:0:16}" "${fp:0:16}" >&2
      printf '🟥 이 라운드의 판정을 **무효화**하라. 대상이 발주 이후 움직였다.\n' >&2
      exit 1
      ;;
    show)
      [ -f "$file" ] || _die_unknown "핀이 없다 ($label)"
      printf 'PINNED %s %s\n' "$label" "$(cat "$file")"
      ;;
    *) _die_unknown "알 수 없는 커맨드: $cmd" ;;
  esac
}

main "$@"
