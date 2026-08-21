#!/usr/bin/env bash
# psa_scan_lib.sh — the ONE implementation of public-surface pattern loading and matching.
#
# WHY THIS FILE EXISTS
#   Three copies of this logic existed (pre-commit, pre-push, public_surface_scan_files.sh). Across a
#   single 2026-07-26 cross-family audit, EVERY confidentiality defect found was a divergence between
#   them, not a flaw in the idea:
#     • the publish copy checked that the override was readable and non-empty; the commit copy did not
#     • the commit copy failed closed when no patterns loaded; the publish copy did too; the push copy
#       had to be told separately
#     • a row with a SPACE instead of a TAB failed closed in two copies and was silently skipped in the third
#     • `head -1` per line (a placeholder shielding a real token) was fixed in one copy and not the others
#     • the LOW-severity file allowlist existed in one copy only — which is how the push gate blocked
#       its own first real push
#   Each was repaired where it was found. The prescription this repo already had recorded for that
#   pattern — [[feedback_divergent_leniency_duplicate_normalizers]]: single source, visible drops,
#   fail-closed — was quoted during that session and then not applied; the duplication was repaired
#   three times instead of removed. This file removes it.
#
# WHAT IS SHARED vs WHAT STAYS WITH THE CALLER — the split is deliberate, do not "unify" further:
#   SHARED (here): loading the two pattern layers, validating rows, and deciding whether a given
#                  token on a given path is a reportable hit.
#   CALLER'S:      WHICH content is scanned (staged diff / pushed range / packed file set), and the
#                  DEGRADE DIRECTION when the instrument is incomplete. Those genuinely differ:
#                  a commit is local and re-committable, so an absent operator override warns; a push
#                  and a publish are the acts that make content public, so the same state blocks.
#                  Collapsing that would either block every fresh clone's first commit (training the
#                  override into reflex) or let a real leak reach a public remote. This library
#                  therefore REPORTS state and never exits.
#
# Usage:
#   . "$REPO_ROOT/scripts/psa_scan_lib.sh"
#   psa_load "$defaults_path" "$override_path"     # sets PSA_STREAM + the three state flags below
#   psa_scan_tagged <<< "$path<TAB>line"…          # prints hits, returns 1 if any hit was reported
#
# State set by psa_load (read-only for callers):
#   PSA_STREAM            validated rows only (invalid/malformed rows are dropped AND counted)
#   PSA_DEFAULTS_OK       1 = committed defaults present, readable, non-empty
#   PSA_OVERRIDE_PRESENT  1 = operator override present, readable, non-empty
#   PSA_BAD_ROWS          count of rows dropped as unusable (uncompilable regex, or no TAB)
# State set by psa_detect_operator_context (separate call — see that function):
#   PSA_OPERATOR_CONTEXT  1 = an operator-configured checkout, where an absent override is missing
#                             evidence rather than a legitimate fresh-clone absence
# A caller that treats PSA_BAD_ROWS>0 or PSA_DEFAULTS_OK=0 as "clean" has a hole: those states mean
# the instrument is incomplete, and an incomplete instrument cannot certify anything.

# Placeholder shapes that must never count as a leak. Anchored whole-token: a substring match here
# would let a real token pass by merely CONTAINING a placeholder word.
PSA_PLACEHOLDER='^(<[a-z0-9_-]+>|\{[a-z_]+\}|EXAMPLE|dummy|changeme|REDACTED|xxxx|/Users/(EXAMPLE|yourname|\{[a-z_]+\}|<[a-z0-9_-]+>)/|AKIAIOSFODNN7EXAMPLE)$'

# ── file::token allowlist (ALL severities) — the SKILL's Step 2, finally implemented ────────────
#
# public-surface-audit SKILL.md §Step 2 has always specified a `file path :: token` allowlist whose
# rule is severity-agnostic ("a hit on file F matching token T is suppressed iff a row exists with
# file == F and T in that row's allowed tokens"). The library implemented only the LOW subset below,
# so spec and implementation disagreed: a HIGH hit that the operator had deliberately published had
# **no expressible disposition at all** — the only ways out were weakening a severity class or
# editing the artifact. That is the divergent-normalizer shape, and it surfaced for real on
# 2026-08-11 (a published paper's author-contact line and a rename changelog entry).
#
# Why this does not weaken the floor:
#   · rows live in a **gitignored** source (`.claude/rules/.public-surface-allowlist`), so writing one
#     never puts an operator token on the public surface — the same two-layer discipline as patterns.
#   · a row is `path<TAB>literal-token`. **Both sides are literal, whole-value comparisons** — the
#     path with `=`, the token with `grep -qxF`. Neither is a pattern, so one row suppresses exactly
#     one token on exactly one file.
#     ⚠️ Two versions of this got it wrong, and the second is the instructive one. v1 claimed a row
#     "cannot become a blanket mute" while the code used an UNANCHORED `grep -qE`: a `path<TAB>.*`
#     row muted every hit in that file, silently, at every severity (pre-publish security pass proved
#     it with a known pair). v2 force-anchored to `^(…)$` — and `^(.*)$` still matches everything, so
#     the blanket mute survived the "fix". Only making the field a **literal** actually closes it.
#     The lesson is the file's own doctrine: a claim is not a control, and neither is a repair that
#     was not re-measured against the same known pair.
#   · every suppression **prints a line**. A mute that leaves no trace is indistinguishable from a
#     clean scan — the same `not found ≠ 0` shape the verdict enum exists to prevent.
#   · absent file → no rows → behaviour is exactly as before (fail-closed by default).
# Each row is an operator decision, recorded where it can be audited, instead of an undocumented
# exception living in someone's head.
psa_pair_allowlisted() {   # $1=path $2=matched token
  local root="${PSA_REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || printf '.')}"
  local src="${PSA_ALLOWLIST:-$root/.claude/rules/.public-surface-allowlist}"
  [ -r "$src" ] || return 1
  local apath atok
  while IFS=$'\t' read -r apath atok || [ -n "$apath" ]; do
    case "$apath" in ''|'#'*) continue ;; esac
    [ -z "$atok" ] && continue
    [ "$apath" = "$1" ] || continue
    # LITERAL, whole-token (`-x -F`). Not a regex — anchoring alone was not enough: `^(.*)$` still
    # matches everything, so an anchored `.*` row remained a blanket mute. Treating the field as a
    # literal is what makes "one row = one token" true rather than merely asserted.
    if printf '%s' "$2" | grep -qxF "$atok" 2>/dev/null; then
      echo "  ⚪ allowlisted — ${1}: '${2}' (row: ${apath} :: ${atok})"
      return 0
    fi
  done < "$src"
  return 1
}

# Files that name wiring/companion tokens as part of doing their job. LOW severity only — HIGH/MED
# block everywhere, including here. Kept as a function so the list has exactly one definition.
psa_low_allowlisted() {
  case "$1" in
    # sync-from-be.sh 는 sync-to-be.sh 와 **같은 일의 반대 방향**인데 목록에 없어서
    # LOW 를 계속 냈다(2026-08-11, 두 렌즈 relay 런 첫 실사용에서 발화). 짝을 빠뜨린
    # 목록은 그 짝만 상시 오탐이 된다.
    .gitignore|scripts/sync-to-be.sh|scripts/sync-from-be.sh|.claude/rules/local_fh_context.md|templates/local_fh_context.md|templates/.claude/rules/*|templates/.git-hooks/*) return 0 ;;
    *) return 1 ;;
  esac
}

# psa_load <defaults_path> <override_path>
# Prints diagnostics for every degraded state; sets the flags above. NEVER exits — the caller owns
# the degrade direction, because it differs by surface (see the header).
psa_load() {
  local defaults="$1" override="$2" raw ov _tabtest
  # 🟥 R5-3: 이 라이브러리는 `$'\t'` (ANSI-C quoting) 에 의존한다 — **POSIX 가 아니다.**
  #    dash 에서는 리터럴 `$\t` 로 읽혀 정상 행이 «TAB 없음» 으로 떨어지고, 스트림이 통째로
  #    비면서 **bad=1 · stream=[] 로 조용히 무력화**됐다(cross-family 실측). 그건 미측정이지
  #    「패턴이 없다」가 아니다. 지원 범위는 bash/zsh 이고, 그걸 산문이 아니라 여기서 확인한다.
  #    판별은 길이다 — 실측: bash/zsh `len=1`(진짜 TAB) · dash `len=3`(리터럴 `$\t`).
  _tabtest=$'\t'
  if [ "${#_tabtest}" -ne 1 ]; then
    echo "  ❌ INSTRUMENT DEAD — this shell does not support \$'\\t' (ANSI-C quoting)." >&2
    echo "     psa_scan_lib.sh requires bash or zsh. Re-run under one of them; NOT SCANNED." >&2
    PSA_STREAM=""; PSA_DEFAULTS_OK=0; PSA_OVERRIDE_PRESENT=0; PSA_BAD_ROWS=1
    return 3
  fi
  PSA_STREAM=""; PSA_DEFAULTS_OK=0; PSA_OVERRIDE_PRESENT=0; PSA_BAD_ROWS=0

  # Layer 1 — committed defaults. This file ships with the repo, so missing/unreadable/empty is a
  # BROKEN INSTRUMENT, not a configuration choice. A valid override used to mask its absence, and the
  # scan then reported a clean "full pattern set" with every universal pattern silently gone.
  if [ -f "$defaults" ] && [ -r "$defaults" ]; then
    raw=$(cat "$defaults" 2>/dev/null || true)
    if [ -n "$(printf '%s' "$raw" | grep -vE '^[[:space:]]*(#|$)' || true)" ]; then
      PSA_STREAM="$raw"; PSA_DEFAULTS_OK=1
    fi
  fi
  [ "$PSA_DEFAULTS_OK" -eq 0 ] && \
    echo "  ❌ committed pattern defaults missing/unreadable/empty — universal patterns NOT loaded ($defaults)"

  # Layer 2 — the gitignored operator literals. Present ONLY when a readable, non-empty read actually
  # contributed patterns: an empty file must not masquerade as a configured gate.
  if [ -f "$override" ]; then
    if [ -r "$override" ]; then
      ov=$(cat "$override" 2>/dev/null || true)
      if [ -n "$(printf '%s' "$ov" | grep -vE '^[[:space:]]*(#|$)' || true)" ]; then
        PSA_STREAM="$PSA_STREAM
$ov"; PSA_OVERRIDE_PRESENT=1
      else
        echo "  ⚠️  operator pattern override is EMPTY — treated as absent."
      fi
    else
      echo "  ⚠️  operator pattern override exists but is UNREADABLE — treated as absent."
    fi
  fi

  # Row validation. Two ways a row can be present and still protect nothing, both previously silent:
  #   • no TAB  → the whole line lands in the severity field and no detector is defined
  #   • bad ERE → grep exits >=2 and the error is swallowed downstream as a no-match
  # Both are DROPPED and COUNTED here so the caller can fail closed on an incomplete instrument.
  local valid="" line re rc
  while IFS= read -r line; do
    line="${line%$'\r'}"                 # CRLF: a trailing CR welds onto the regex and it matches nothing
    case "$line" in ''|\#*) continue;; esac
    re="${line#*$'\t'}"
    if [ "$re" = "$line" ]; then
      echo "  ❌ unusable pattern row (no TAB between severity and regex): ${line%%$'\t'*}"
      PSA_BAD_ROWS=$((PSA_BAD_ROWS+1)); continue
    fi
    # 🟥 R4-1: 여기도 `cmd; rc=$?` 였다 — P3 를 스캔 경로에서만 고치고 **로더 경로로 전파를 안 봤다**.
    #    정상 패턴은 빈 입력에 rc=1 을 내므로 `set -e` 호출자는 psa_load 에서 죽는다(선재, 양 셸 실측).
    if printf '' | grep -E "$re" >/dev/null 2>&1; then rc=0; else rc=$?; fi    # >=2 = regex error
    if [ "$rc" -ge 2 ]; then
      echo "  ❌ unusable pattern (invalid regex) — this detector would match nothing: [${line%%$'\t'*}]"
      PSA_BAD_ROWS=$((PSA_BAD_ROWS+1)); continue
    fi
    # 🟥 P4 (선재 결함): 판별력 없는 패턴을 거부한다 — 빈 패턴 · `^` · `a*` · `SECRET|^$`.
    #    모든 입력에 매치하므로 검출기로 **쓸 수 없는데** 초판 로더는 유효로 받아들였다.
    #    🟥 그리고 이 검사는 **위의 컴파일 검사로는 못 한다**: `printf ''` 는 줄을 0개 주므로
    #    grep 이 매치할 대상 자체가 없어 **어떤 패턴이든 rc=1** 이다(실측). 위 주석의
    #    「0 = 컴파일됨」은 도달 불가능한 값을 서술한 것이었다. 빈 «줄» 을 따로 먹인다.
    if printf '\n' | grep -E "$re" >/dev/null 2>&1; then rc=0; else rc=$?; fi
    if [ "$rc" -eq 0 ]; then
      echo "  ❌ unusable pattern (matches the EMPTY string — no discrimination): [${line%%$'\t'*}]"
      PSA_BAD_ROWS=$((PSA_BAD_ROWS+1)); continue
    fi
    valid="$valid
$line"
  done <<PSA_ROWS
$PSA_STREAM
PSA_ROWS
  PSA_STREAM="$valid"
}

# psa_detect_operator_context <repo_root>   → sets PSA_OPERATOR_CONTEXT (0/1)
#
# Answers ONE question: is an absent operator override a *legitimate absence* (fresh clone, CI
# runner, worktree — the file is gitignored, so it is absent there by construction) or *evidence
# missing where evidence is expected* (a checkout the operator has configured, whose literals should
# be there and are not)?
#
# 2026-07-26 changed pre-push from BLOCK to WARN on an absent override, and that change was right for
# the first case: this repo's own selfcheck flagged the block as over-firing, and over-blocking trains
# PUBLIC_SURFACE_OK into a reflex, which disarms the same channel the publish gate depends on. It was
# wrong for the second case, which the flag could not distinguish. This function is that distinction —
# it does not reopen the reverted block, it scopes it.
#
# Signal: CLAUDE.local.md — the operator's own gitignored binding file. Chosen because it is
# gitignored (verified: `.gitignore:17`), so no clone, CI checkout or worktree carries it.
#
# CALIBRATED, and one candidate was REJECTED by that calibration: "tracks/_meta is non-empty" looks
# like the same signal and is not — `tracks/_meta/.gitkeep` and one more file are TRACKED, so a fresh
# clone satisfies it and would have been blocked. The discriminator was measured against a known
# pair before it was trusted, not reasoned about.
#
# NAMED RESIDUAL (deliberate, and in the safe direction): an operator who never created a
# CLAUDE.local.md stays in the WARN arm. This under-blocks rather than over-blocks — the failure mode
# this scoping exists to avoid is the reflex, not the miss, and the push gate's content scan still
# runs on the committed defaults in that arm.
psa_detect_operator_context() {
  local root="$1"
  PSA_OPERATOR_CONTEXT=0
  [ -n "$root" ] || return 0
  [ -f "$root/CLAUDE.local.md" ] && PSA_OPERATOR_CONTEXT=1
  return 0
}

# psa_scan_tagged  — reads "path<TAB>content" lines on stdin, prints one line per reportable hit.
# Returns 0 = nothing reportable, 1 = at least one hit.
#
# Why path-tagged input: the LOW allowlist is per FILE, so a scanner that flattens content loses the
# only information needed to apply it. The push copy did exactly that and blocked its own first real
# push on a companion-store name inside the script whose job is to sync to the companion store.
# _psa_in_selftest — «지금 psa_require_live 안에서 불린 것인가»를 **호출 스택**으로 판별한다.
# 🟥 변수 표식을 쓰면 안 된다: 외부가 `_PSA_IN_SELFTEST=1` 을 미리 export 하는 것만으로
#    자가검사가 통째로 생략된다(cross-family 반례 1b, 실행 재현). 전역 상태를 권한 표식처럼
#    믿는 형태다. 호출 스택은 **호출자가 미리 심을 수 없다.**
# bash=FUNCNAME · zsh=funcstack. 둘 다 없으면 판별 불가이므로 **재진입이 아니라고 답한다** —
# 그러면 자가검사가 한 번 더 돌 뿐(무한재귀는 psa_require_live 가 이 함수를 한 겹만 부르므로
# 발생하지 않는다), 반대로 «재진입이다」로 접으면 그게 fail-open 이다.
_psa_in_selftest() {
  local _st=""
  # shellcheck disable=SC2154
  if [ -n "${FUNCNAME[*]:-}" ]; then _st=" ${FUNCNAME[*]} "
  elif [ -n "${funcstack[*]:-}" ]; then _st=" ${funcstack[*]} "
  else return 1; fi
  case "$_st" in *" psa_require_live "*) return 0 ;; esac
  return 1
}

psa_scan_tagged() {
  # 🟥 `path` 를 지역선언하지 마라 — zsh 에서 `path` 는 `PATH` 와 **tied 된 특수 배열**이라
  #    `local path` 하는 순간 그 스코프의 `PATH` 가 빈 문자열이 되고, 바로 다음 줄의
  #    `$(cat)` 부터 `command not found: cat` 으로 죽는다. 그런데 이 함수의 계약이
  #    「빈 입력 = 신고할 것 없음 = return 0」이라 **계기 사망이 «깨끗한 스캔»과 바이트 단위로
  #    같은 출력**이 된다 — 이 저장소가 이름 붙인 «미측정을 0으로 렌더» 의 가장 조용한 얼굴이다.
  #    실측 2026-08-21: zsh 에서 known-positive·known-negative 가 **둘 다 rc=0** 이었다.
  #    형제 특수변수(`fpath` `status` `argv` `cdpath` …)도 같은 함정이다.
  local input hit=0 row sev re _psa_path body tok _line_hits _tok_hits _lg _tg

  # ── E: 진입 생존성 가드 (2026-08-21, cross-family FAIL 판정 후 재작성) ─────────────
  # 🟥 **초판 E 는 fail-open 을 못 닫았다.** codex/gpt-5.6-sol 이 반례 6개를 전부 실행으로
  #    재현했고 판정은 FAIL 이었다. 초판의 구조적 맹점: **«자가검사가 한 번 통과했다»를
  #    «그 뒤의 실제 스캔도 실행됐다»로 확장**한 것. 그 사이엔 시간·전역상태·파이프라인
  #    상태라는 단절점이 셋 있다. 재작성이 닫는 것과 못 닫는 것을 아래에 이름으로 적는다.
  #
  # 🟥 **캐시 제거.** 초판은 `_PSA_LIVE_OK` 로 프로세스당 1회만 검사했다 — 첫 양성 뒤
  #    grep 을 죽이면 같은 양성이 rc=0 이 됐다(codex 재현). 그리고 **캐시는 뚫린 쪽(긴
  #    스킬 세션)에서만 위험하고 안전한 쪽(짧은 훅)에서만 이득**이라 방향이 반대였다.
  #    비용은 **실측했다: psa_require_live 1회 ≈ 64ms** (훅 경로 최대 4회 = 0.26초).
  #    초판은 이 비용을 **안 재고** 캐시를 정당화했다 — 그게 진짜 결함이었다.
  #
  # 🟥 **재진입 표식은 `local` 로 «동적 스코프»에 둔다.** 초판은 전역 변수를 권한 표식처럼
  #    믿어서, 외부가 `_PSA_IN_SELFTEST=1` 을 미리 export 하면 자가검사가 **통째로 생략**됐다
  #    (codex 재현: `grep(){ return 127; }` 상태에서 known-positive 가 rc=0 무출력).
  #    `local` 선언은 외부 값을 **가리고**, 함수가 끝나면 **자동 복구**된다 — unset 실패나
  #    시그널·트랩으로 값이 남는 경로가 없어진다.
  if ! _psa_in_selftest; then
    # 🟥 실제 패턴 스트림을 여기서 본다. 자가검사는 PSA_STREAM 을 카나리아로 **바꿔치기**
    #    하므로 «진짜 패턴이 비었거나 깨졌는지»를 구조적으로 못 본다(codex 반례 3).
    if [ -z "${PSA_STREAM:-}" ]; then
      echo "  ❌ INSTRUMENT DEAD — PSA_STREAM is empty; nothing to match against. NOT SCANNED."
      echo "  ❌ INSTRUMENT DEAD — PSA_STREAM is empty; NOT SCANNED (call psa_load first)." >&2
      return 3
    fi
    # 🟥 R4-6: **부분 로드된 패턴 집합으로 «깨끗»을 말하지 않는다.** 초판은 이것을 «호출자
    #    계약»으로 두었고(헤더가 그렇게 적어뒀다), cross-family 가 그 계약을 안 지키는 호출자를
    #    실측 재현했다 — `SECRET|^$` 한 행이 떨어져 나간 집합으로 `SECRET` 입력이 rc=0 «깨끗».
    #    산문 계약을 라이브러리 층으로 내린다: 안 실린 검출기가 있으면 그건 미측정이다.
    #    (psa_load 를 안 부른 호출자는 PSA_BAD_ROWS 가 미설정이고, 그 경로는 위 빈-스트림
    #     검사가 이미 잡는다. `case` 로 보는 이유는 비수치 오염에서 fail-open 하지 않기 위해서다.)
    case "${PSA_BAD_ROWS:-0}" in
      0) ;;
      *) echo "  ❌ INSTRUMENT DEAD — ${PSA_BAD_ROWS} pattern row(s) were dropped; the detector set is PARTIAL. NOT SCANNED."
         echo "  ❌ INSTRUMENT DEAD — ${PSA_BAD_ROWS} pattern row(s) dropped — a partial set cannot report clean." >&2
         return 3 ;;
    esac
    if ! psa_require_live >/dev/null 2>&1; then
      echo "  ❌ INSTRUMENT DEAD — psa_scan_tagged self-test failed. NOT SCANNED."
      echo "  ❌ INSTRUMENT DEAD — psa_scan_tagged self-test failed. NOT SCANNED." >&2
      echo "     A 0 from this scanner is UNMEASURED, not clean. Re-run under bash." >&2
      return 3
    fi
  fi

  # 🟥 `cat` 의 상태를 버리지 마라 (codex 반례 1). 초판은 `input=$(cat)` 로 대입만 하고
  #    rc 를 버려서, cat 이 죽어 입력이 비면 그게 곧 «신고할 것 없음»이 됐다.
  if ! input=$(cat); then
    echo "  ❌ INSTRUMENT DEAD — could not read stdin. NOT SCANNED."
    echo "  ❌ INSTRUMENT DEAD — could not read stdin. NOT SCANNED." >&2
    return 3
  fi
  [ -n "$input" ] || return 0
  while IFS= read -r row; do
    case "$row" in ''|\#*) continue;; esac
    re="${row#*$'\t'}"; [ "$re" = "$row" ] && continue
    sev="${row%%$'\t'*}"
    # 🟥 grep 상태를 «매치 없음» 으로 접지 마라 (cross-family 반례 2, 2026-08-21).
    #    `2>/dev/null || true` 는 rc 0(매치)·1(없음)·**2 이상(계기 오류)**을 하나로 뭉갠다.
    #    실측 도달 경로: 패턴 파일에 **깨진 정규식**이 한 줄 있으면 그 행만 조용히 아무것도
    #    안 잡고 스캔은 rc=0 «깨끗» 을 낸다. 자가검사는 자기 카나리아 패턴을 쓰므로
    #    **진짜 패턴의 깨짐을 구조적으로 못 본다** — 그래서 여기서 봐야 한다.
    # 🟥 P3 동형: grep 의 정상 «미매치»(rc=1)가 `set -e` 호출자를 죽인다.
    if _line_hits=$(printf '%s\n' "$input" | grep -iE "$re" 2>/dev/null); then _lg=0; else _lg=$?; fi
    if [ "$_lg" -gt 1 ]; then
      echo "  ❌ INSTRUMENT DEAD — grep failed (rc=$_lg) on pattern: $re"
      echo "  ❌ INSTRUMENT DEAD — grep failed (rc=$_lg) on pattern: $re" >&2
      echo "     A broken pattern row scans NOTHING and reads as clean. NOT SCANNED." >&2
      return 3
    fi
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      _psa_path="${line%%$'\t'*}"; body="${line#*$'\t'}"
      # EVERY match on the line. Taking only the first let a documented placeholder earlier on the
      # line shield a real token later on it.
      if _tok_hits=$(printf '%s' "$body" | grep -oiE "$re" 2>/dev/null); then _tg=0; else _tg=$?; fi
      if [ "$_tg" -gt 1 ]; then
        echo "  ❌ INSTRUMENT DEAD — grep -o failed (rc=$_tg) on pattern: $re"
        echo "  ❌ INSTRUMENT DEAD — grep -o failed (rc=$_tg) on pattern: $re" >&2
        return 3
      fi
      while IFS= read -r tok; do
        [ -z "$tok" ] && continue
        printf '%s' "$tok" | grep -qiE "$PSA_PLACEHOLDER" && continue
        if [ "$sev" = "LOW" ] && psa_low_allowlisted "$_psa_path"; then continue; fi
        if psa_pair_allowlisted "$_psa_path" "$tok"; then continue; fi
        # 🟥 P5: zsh 의 `echo` 는 백슬래시를 해석한다 — 경로 `dir\two` 가 탭으로 변해
        #    증거 문자열이 손상됐다(실측). fail-open 은 아니나 증거는 증거여야 한다.
        printf '  ❌ %s leak — %s: \x27%s\x27\n' "$sev" "${_psa_path}" "$tok"
        hit=1
      done <<PSA_TOK
$_tok_hits
PSA_TOK
    done <<PSA_LINES
$_line_hits
PSA_LINES
  done <<PSA_PAT
$PSA_STREAM
PSA_PAT
  return $hit
}

# _psa_can_assign <name> <value> — 0 = "this exact assignment will succeed", 1 = it will not.
#
# Rounds 4→7 walked this from a declaration parse to a proxy probe to the real thing:
#   R4  parsed `readonly -p` for `NAME=` — missed `readonly FOO` (prints `declare -r FOO`, no `=`)
#       and false-positived on an unrelated readonly whose VALUE contained the string.
#   R5  replaced it with a behavioural probe — but the probe assigned the variable's OWN CURRENT
#       VALUE, while the caller then assigns something else.
#   R7  found the gap that leaves: `declare -i PSA_ALLOWLIST` makes the self-assignment succeed and
#       `PSA_ALLOWLIST=/dev/null` fail. Measured — probe=writable, real=FAIL. The caller then died
#       mid-run, and on the psa_scan_file path a hit that psa_scan_tagged WOULD have reported was
#       lost with it.
# So the probe now takes the value: it tests the operation that is actually about to happen, in a
# subshell where failure cannot reach the caller. Every earlier version tested a stand-in for it.
_psa_can_assign() {
  case "$1" in
    ''|*[!A-Za-z0-9_]*|[0-9]*)
      echo "  ❌ _psa_can_assign: refusing non-identifier argument" >&2
      return 1 ;;   # cannot-assign → the caller refuses to mutate. Degrades away from mutating.
  esac
  ( eval "$1=\"\$2\"" ) 2>/dev/null
}

# psa_require_live — prove the scanner actually RUNS before a 0 from it is allowed to mean "clean".
# Returns 0 = alive, 1 = dead (and says so on stderr).
#
# Why this exists (measured 2026-08-12): a caller hand-built the path-tagged stream and piped it into
# psa_scan_tagged from a shell whose PATH lacked `cat`. The function died on its first line, printed
# `command not found` into the captured output, and returned 0 — so the caller's known-positive
# (a file dense with operator literals) reported **0 hits**, indistinguishable from clean. The control
# is what caught it: the run was only recognisable as dead because a file that MUST hit did not.
# This function makes that control intrinsic instead of remembered — it does not check that binaries
# exist (a presence check is the weaker instrument this repo keeps re-learning), it checks that a
# synthetic token which MUST be reported IS reported, end to end through the real matcher.
#
# Cross-family round 1 (2026-08-12) refuted three things about the first draft; all three are fixed
# here and named so the next reader does not re-introduce them:
#   · it exercised only the stdin path, so a missing `awk` — the binary the file path actually needs —
#     was outside what "alive" certified. The self-test now goes through the SAME tagging path
#     `psa_scan_file` uses, from a real temp file.
#   · the canary was allowlistable: a `psa/selftest<TAB>PSA_SELFTEST_CANARY` row would mute it and a
#     healthy scanner would report itself dead. The self-test now runs with the allowlist disabled.
#   · it was not `errexit`-safe: under `set -e` the nonzero return from the hit-reporting path exited
#     the caller's shell before the restore line. Status capture is now inside an `if`.
psa_require_live() {
  local saved_stream saved_allow saved_stream_set saved_allow_set tmpd out rc _canary
  local _nonce _tag_rc
  saved_stream="${PSA_STREAM-}"; saved_allow="${PSA_ALLOWLIST-}"
  saved_stream_set=""; saved_allow_set=""
  [ "${PSA_STREAM+x}" = "x" ] && saved_stream_set=1
  [ "${PSA_ALLOWLIST+x}" = "x" ] && saved_allow_set=1
  tmpd=$(mktemp -d 2>/dev/null) || { echo "  ❌ INSTRUMENT DEAD — mktemp unavailable." >&2; return 1; }
  # 🟥 P1 (cross-family 3라운드): 카나리아가 **고정 문자열**이면, 입력을 읽지도 않고
  #    그 문자열을 rc=0 으로 뱉는 위조 생산자가 자가검사를 통과한다. 세 라운드가 공유한
  #    얼굴 —「상태(rc=0)를 의미(생산이 유효하다)로 확장」— 의 마지막 잔재다.
  #    실행마다 새 nonce 를 만들면 **하드코딩된 위조는 그 값을 알 수 없다.**
  _nonce=$(head -c 12 /dev/urandom 2>/dev/null | od -An -tx1 2>/dev/null | tr -d ' \n')
  # 🟥 **신뢰 경계 — 여기서 라운드를 멈추는 이유(2026-08-21, 6라운드 후 판정).**
  #    이 자가검사가 막는 것: 생산자가 **깨졌거나**(awk 부재·crash·출력 훼손), **PATH 로
  #    가려졌거나**(외부 바이너리 shadowing), 입력을 **안 읽고** 고정/유도값을 뱉는 경우.
  #    이 자가검사가 **못** 막는 것: 이 라이브러리를 **소싱한 셸 안에서 함수를 정의할 수 있는**
  #    상대. 그 상대는 `psa_scan_tagged(){ return 0; }` 한 줄이면 끝이라 nonce·cmp·심링크를
  #    아무리 조여도 소용이 없다 — **이미 신뢰 안쪽**이다. 6라운드 반례 둘이 정확히 그 부류였고
  #    (`cmp(){ return 0; }` · `ln -sf` 로 tagged 바꿔치기), 값싼 두 수리(`command cmp` ·
  #    심링크 거부)는 했지만 **그 축을 닫았다고 주장하지 않는다.**
  # 🟥 R5-1: **fallback 을 없앴다.** 5라운드 실측 —
  #      `${tmpd##*/}` 파생 → 생산자가 경로를 인자로 받으므로 유도 가능 (4라운드에서 교체)
  #      `${RANDOM}${RANDOM}$$${SECONDS}` → **생산자가 같은 셸에서 그대로 재계산해 통과**(zsh 실측 rc=0),
  #      `RANDOM`/`SECONDS` 가 unset 이면 사실상 `$$` 하나라 `ps` 로도 읽힌다(bash 실측 rc=0)
  #    ⇒ 「예측 불가한 값」은 **커널 엔트로피에서만** 나온다. 못 얻으면 그건 약한 nonce 가 아니라
  #      **미측정**이다. 두 번째 출처(openssl)까지 시도하고, 그것도 없으면 fail-closed.
  [ -n "$_nonce" ] || _nonce=$(openssl rand -hex 12 2>/dev/null | tr -cd 'A-Za-z0-9')
  if [ -z "$_nonce" ]; then
    echo "  ❌ INSTRUMENT DEAD — no kernel entropy source (/dev/urandom, openssl); cannot mint an unguessable nonce." >&2
    echo "     A guessable nonce is not a weaker probe, it is NO probe — a producer can replay it." >&2
    rm -rf "$tmpd" 2>/dev/null || :
    return 1
  fi
  # Round 4 refuted the round-3 fix: `|| :` does NOT rescue an assignment to a readonly variable —
  # bash aborts the shell before the `||` is ever considered. So the only safe move is to REFUSE
  # before mutating anything. Detected, reported as DEAD, and the caller survives.
  _canary=$(printf 'HIGH\tPSA_SELFTEST_CANARY_%s' "$_nonce")
  if ! _psa_can_assign PSA_STREAM "$_canary" || ! _psa_can_assign PSA_ALLOWLIST /dev/null; then
    echo "  ❌ INSTRUMENT DEAD — PSA_STREAM/PSA_ALLOWLIST cannot take the values the self-test needs." >&2
    echo "     (readonly, or an attribute such as \`declare -i\` that rejects the value)" >&2
    echo "     Not attempting it: a failed assignment aborts an errexit caller outright." >&2
    rm -rf "$tmpd" 2>/dev/null || :
    return 1
  fi
  PSA_STREAM="$_canary"
  PSA_ALLOWLIST=/dev/null
  printf 'PSA_SELFTEST_CANARY_%s\n' "$_nonce" > "$tmpd/canary" 2>/dev/null
  # 🟥 생산자와 매처를 **분리해서** 상태를 각각 본다 (cross-family 반례 4, 2026-08-21).
  #    초판은 `awk … | psa_scan_tagged` 한 파이프의 최종 rc 만 봤는데, 그러면
  #    **«생산자 실패의 rc=1»** 과 **«스캐너가 유출을 찾음의 rc=1»** 이 같은 값으로 합쳐진다.
  #    실측 위조: 실패하는 `awk` 가 카나리아 행을 인쇄하고 `return 1` 하게 만들면
  #    양 셸에서 `psa_require_live` 가 **rc=0(살아있음)** 을 냈다. 즉 자가검사 판정 자체가
  #    위조 가능했다. 태깅 결과를 먼저 **물질화**하고 그 rc 를 따로 확인한다.
  # 🟥 P3: `x=$(cmd); rc=$?` 는 `set -e` 아래서 **셸을 즉시 죽인다** — 아래 복원문과
  #    `rm -rf` 에 도달하지 못하고 PSA_STREAM 이 **카나리아인 채로 남는다**(실측, bash).
  #    조건문 안의 대입은 errexit 면제다.
  # 🟥 R4-3: `$(...)` 는 **후행 개행을 지운다** — 정답 줄 뒤에 빈 줄을 아무리 붙여도
  #    문자열 비교가 통과했다(실측 rc=0). 「정확한 문자열 대조」라고 적어놓고 정확하지 않았다.
  #    생산자 출력을 **파일로 물질화**해서 `cmp` 로 바이트 비교한다. stderr 는 따로 받는다.
  if awk -v P="psa/selftest" '{print P "\t" $0}' "$tmpd/canary" > "$tmpd/tagged" 2>"$tmpd/err"; then _tag_rc=0; else _tag_rc=$?; fi
  # 🟥 P1: 상태(rc)만이 아니라 **내용**을 대조한다. 생산자가 «입력을 읽어서 태깅했는가» 는
  #    rc 로 알 수 없고, nonce 를 포함한 정확한 문자열 일치로만 알 수 있다.
  # 🟥 R5-2: 초판은 기대값도 `$tmpd/expect` 파일에 뒀는데, **생산자는 `$tmpd/canary` 를 인자로
  #    받으므로 `$tmpd` 를 알고 expect 를 덮어쓸 수 있다** — 틀린 바이트를 양쪽에 써넣으면
  #    `cmp` 가 통과했다(양 셸 실측 rc=0). 기대값은 **프로세스 안에만** 두고 파이프로 먹인다.
  #    (`cmp file -` 는 stdin 을 두 번째 피연산자로 읽는다. cmp 부재는 rc≠0 → fail-closed, 실측.)
  # 🟥 R6-1: `cmp` 를 셸이 해석하면 **함수로 가려진다** — `cmp(){ return 0; }` 하나로 대조가
  #    통째로 무력화됐다(양 셸 실측 rc=0). `command` 는 함수를 건너뛴다.
  # 🟥 R6-2: 생산자는 `$tmpd` 를 알므로 stdout 에는 틀린 바이트를 쓰고 `tagged` 를 **정답 파일로
  #    가는 심링크로 바꿔치기**할 수 있다(양 셸 실측 rc=0). 비교 대상이 «awk 가 실제로 쓴 파일»
  #    인지 먼저 확인한다 — 심링크가 아닌 보통 파일이어야 한다.
  if [ -L "$tmpd/tagged" ] || [ ! -f "$tmpd/tagged" ]; then
    rm -rf "$tmpd" 2>/dev/null || :
    if [ -n "${saved_stream_set:-}" ]; then PSA_STREAM="$saved_stream"; else unset PSA_STREAM; fi
    if [ -n "${saved_allow_set:-}" ]; then PSA_ALLOWLIST="$saved_allow"; else unset PSA_ALLOWLIST; fi
    echo "  ❌ INSTRUMENT DEAD — the self-test output was replaced (symlink or non-regular file)." >&2
    return 1
  fi
  if [ "$_tag_rc" -ne 0 ] || ! printf 'psa/selftest\tPSA_SELFTEST_CANARY_%s\n' "$_nonce" | command cmp -s "$tmpd/tagged" -; then
    rm -rf "$tmpd" 2>/dev/null || :
    if [ -n "${saved_stream_set:-}" ]; then PSA_STREAM="$saved_stream"; else unset PSA_STREAM; fi
    if [ -n "${saved_allow_set:-}" ]; then PSA_ALLOWLIST="$saved_allow"; else unset PSA_ALLOWLIST; fi
    echo "  ❌ INSTRUMENT DEAD — the self-test PRODUCER did not tag this run's nonce (rc=$_tag_rc)." >&2
    echo "     A canary printed by a failing — or input-ignoring — producer is not evidence the matcher ran." >&2
    return 1
  fi
  if out=$(psa_scan_tagged < "$tmpd/tagged" 2>&1); then
    rc=0
  else
    rc=$?
  fi
  rm -rf "$tmpd" 2>/dev/null || :
  # Restore EXACTLY, including the difference between unset and set-empty (round 2): the first draft
  # always re-set PSA_STREAM, turning an unset variable into an empty one — which the very guard in
  # psa_scan_file below keys on. A restore that changes state is not a restore.
  if [ -n "${saved_stream_set:-}" ]; then PSA_STREAM="$saved_stream"; else unset PSA_STREAM; fi
  if [ -n "${saved_allow_set:-}" ]; then PSA_ALLOWLIST="$saved_allow"; else unset PSA_ALLOWLIST; fi
  case "$out" in
    *"PSA_SELFTEST_CANARY_$_nonce"*) [ "$rc" -eq 1 ] && return 0 ;;
  esac
  echo "  ❌ INSTRUMENT DEAD — the scanner did not report a synthetic known-positive." >&2
  echo "     self-test rc=$rc out=[$out]" >&2
  echo "     A 0 from this scanner is UNMEASURED, not clean — do not report or publish a count from it." >&2
  return 1
}

# psa_scan_file <path> — scan ONE file through the shared matcher.
#
# Three-valued on purpose: 0 = scanned, nothing reportable · 1 = scanned, hit(s) reported ·
# 3 = NOT SCANNED (instrument dead, bad usage, or missing file). Folding 3 into 0 is the exact defect
# this repo keeps meeting — `not found` is not `0`, and a file that does not exist is not an empty file.
# Callers that only branch on `if psa_scan_file f; then clean; fi` would read 3 as dirty (safe) and
# never as clean; callers that check `-eq 0` must treat 3 as unmeasured.
#
# ⚠️ The caller still owns the DISPLAY. A hit line (❌) and an allowlisted line (⚪) are different
# outcomes, and a display filter that greps only ❌ renders "allowlisted" as "no match" — measured
# on 2026-08-12, which is how an existing operator allowlist decision was misread as an absent
# pattern. If you filter this function's output, keep both markers or state which you dropped.
psa_scan_file() {
  local out rc
  if [ "$#" -ne 1 ]; then
    echo "  ⚠️  USAGE — psa_scan_file <path> (got $# argument(s)); NOT SCANNED" >&2
    return 3
  fi
  # Patterns-not-loaded is the highest-value guard here, and it was missing from the first draft.
  # Cross-family round 1 found it by simply following THIS FILE'S OWN advertised usage line, which
  # said `. psa_scan_lib.sh && psa_scan_file <path>` and omitted psa_load — reproduced: a file dense
  # with a known-positive token returned rc=0 with empty output. An empty pattern stream scans
  # everything and reports nothing, which is the false-clean this whole change exists to remove.
  if [ -z "${PSA_STREAM:-}" ]; then
    echo "  ⚠️  PATTERNS NOT LOADED — call psa_load <defaults> <override> first; NOT SCANNED" >&2
    echo "     (an empty pattern stream reports nothing, which is indistinguishable from clean)" >&2
    return 3
  fi
  # A NON-EMPTY stream is not a COMPLETE one (round 2). If the committed defaults failed to load, or
  # rows were dropped as unusable, the stream still matches *something* and a clean verdict from it
  # is a verdict about a partial instrument.
  #
  # `case`, not `[ -ne ]` (round 3): a non-numeric value made `[` return 2, the `if` read that as
  # false, and the guard fell through — reproduced with PSA_DEFAULTS_OK=x, which scanned a file to
  # rc=0 CLEAN using a stream that did not contain the token. A guard that a garbage value walks
  # straight past is not a guard, and the shell's own error line scrolled by unnoticed.
  local _incomplete=""
  case "${PSA_DEFAULTS_OK:-}" in 1) ;; *) _incomplete="defaults_ok=${PSA_DEFAULTS_OK:-unset}" ;; esac
  case "${PSA_BAD_ROWS:-0}" in 0) ;; *) _incomplete="${_incomplete:+$_incomplete }bad_rows=${PSA_BAD_ROWS}" ;; esac
  # The operator override carries the HIGH company/companion literals. Its absence is survivable for a
  # single-file query (the committed defaults still apply) but the caller must never read the result as
  # a full clean — so it is announced, not silently folded in.
  # Round 4: this used to WARN and still return 0. That is the exact false-clean this change exists to
  # remove — the override carries the HIGH company/companion literals, so without it the scan did not
  # look at the highest-severity class at all, and "clean" is a claim the run cannot support. It now
  # joins _incomplete. (No existing caller breaks: psa_scan_file is new in this change.)
  case "${PSA_OVERRIDE_PRESENT:-}" in
    1) ;;
    *) _incomplete="${_incomplete:+$_incomplete }override_absent(HIGH operator literals unscanned)" ;;
  esac
  psa_require_live || return 3
  if [ ! -f "$1" ]; then
    echo "  ⚠️  MISSING — $1 : NOT SCANNED (unmeasured, not 0 hits)" >&2
    return 3
  fi
  # `awk | psa_scan_tagged` hides an awk read failure when the caller has no pipefail: awk fails,
  # psa_scan_tagged sees an empty stream and returns 0 = clean. Materialise the tagged stream first
  # so the read is a checkable step of its own (cross-family round 1).
  local tmpf
  tmpf=$(mktemp 2>/dev/null) || { echo "  ⚠️  mktemp failed; NOT SCANNED" >&2; return 3; }
  if ! awk -v P="$1" '{print P "\t" $0}' "$1" > "$tmpf" 2>/dev/null; then
    rm -f "$tmpf" || :
    echo "  ⚠️  READ FAILED — $1 could not be tagged for scanning; NOT SCANNED" >&2
    return 3
  fi
  if out=$(psa_scan_tagged < "$tmpf"); then rc=0; else rc=$?; fi
  rm -f "$tmpf" || :
  # Print findings FIRST, verdict second — round 3 caught the previous order suppressing real hits:
  # an incomplete instrument returned 3 and emitted nothing, so a token the loaded patterns DID match
  # was lost. "I could not certify this" and "I saw nothing" are different, and the fix for the second
  # must not create the first. Partial evidence is reported; the verdict still refuses to say clean.
  [ -n "$out" ] && printf '%s\n' "$out"
  if [ -n "$_incomplete" ]; then
    echo "  ⚠️  INCOMPLETE PATTERN INSTRUMENT — $_incomplete : verdict is NOT SCANNED (any hits above are partial)" >&2
    return 3
  fi
  return "$rc"
}
