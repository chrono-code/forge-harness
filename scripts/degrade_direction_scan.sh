#!/usr/bin/env bash
# degrade_direction_scan.sh — mechanical pre-screen for the "default-toward-PASS" smell
#
# The correlated blind spot measured 2026-07-03 across 3 harnesses (qasp/the-bible/pmh):
#   "When a verdict surface cannot mechanically ground its judgment, it defaults toward
#    PASS instead of safe-fail." Same-family review (even frontier + target-tier sim)
#   shares the author's optimistic reading of that discretion and misses it; a
#   different-family auditor catches it. This script is the cheap MECHANICAL pre-screen
#   that runs BEFORE the cross-family pass — it flags the code shapes where a permissive
#   value lands on an unconstrained branch, so the reviewer's attention goes there first.
#
# IT IS A REVIEW SURFACE, NOT A HARD GATE. Grep-heuristic → false positives are expected.
# A hit means "prove this is not default-toward-PASS", not "this is a bug". It never
# blocks a commit on its own (advisory exit code). The terminal verdict is the
# cross-family adversarial review + governor source-grounding, never this scan alone.
# (Irreversibility-gate note: because it is advisory, a degraded/empty run is a no-op,
#  not a free pass — the cross-family review is the load-bearing check it feeds.)
#
# NAMED RECALL RESIDUALS (cross-family audit, gpt-5.5, 2026-07-28 — accepted, not closed):
#   * Indirection defeats every probe. `allow() { exit 0; }` … `check || allow` is the same
#     fail-open shape one function call away, and a line-oriented grep cannot follow it. This is
#     inherent to the heuristic, not a bug to patch — it is why the terminal verdict is the
#     cross-family review, and why a clean run is never evidence of safety.
#   * The regression anchor proves the probes on the fixture GRAMMAR it ships, not on every
#     spelling of each class (e.g. `if ! cmd; then :; fi`, arithmetic-context defaults).
#
# Usage:
#   bash scripts/degrade_direction_scan.sh [path ...]        # scan dirs/files (default: .)
#   git diff --name-only main..HEAD -- '*.py' | xargs bash scripts/degrade_direction_scan.sh
# Exit:  0 = no smells found; 2 = smells found (ADVISORY signal — do not hard-block on it)
set -uo pipefail

TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=(".")

# Permissive values a verdict/gate surface must never land on by *default* / fall-through.
PASS='(True|"PASS"|'"'"'PASS'"'"'|"ALLOW"|'"'"'ALLOW'"'"'|"OK"|'"'"'OK'"'"'|"VALID"|'"'"'VALID'"'"'|"GRANTED"|'"'"'GRANTED'"'"'|"PASSED"|'"'"'PASSED'"'"'|allow|ALLOW)'

# Collect target files. Scannable = py + sh (the smell probes are Python-shaped but bash surfaces —
# incl. this gate's own pre-push/pre-commit-hook trigger category — must not be invisibly dropped).
# Anything else is tracked as UNSCANNABLE so a load-bearing surface in another language is reported
# as "not covered", never silently folded into an "advisory clean" (M#2, steel-quench 2026-07-03).
FILES=(); UNSCANNABLE=(); MD_ORIGIN=(); UNMEASURED=(); DISCOVERY_ERR=()
# UNSCANNABLE vs UNMEASURED — 한 통에 넣으면 S 가 살아난다(재검 2026-08-12 지목).
#   UNSCANNABLE = 측정 대상이 아니다(펜스 없는 산문 md, py/sh 아닌 파일). 정상 상태.
#   UNMEASURED  = 재려 했는데 **못 쟀다**(python3/cksum 부재로 추출 실패). 이건 절대 CLEAN 이 아니다.
# 첫 수리는 둘을 UNSCANNABLE 하나에 담았고, 그 배열은 `FILES` 가 **완전히 빌 때만** exit 2 로
# 승격된다 — 스캔 가능한 .sh 가 하나라도 섞이면 추출 실패가 note 한 줄로 강등되고 rc=0 이 나갔다.
# 즉 「측정 못 함을 CLEAN 으로 렌더」가 지배 경로(디렉터리 스캔 → typed capability)에 그대로 남아
# 있었다 — 이 릴리스가 고치겠다고 선언한 바로 그것이다.

# ── Markdown fence extraction (2026-08-11) ────────────────────────────────────────────────────
# The bash this harness actually EXECUTES largely does not live in .sh files — it lives in ```bash
# fences inside SKILL.md / SKILL_detail.md, and the scanner could not see a single line of it.
# Measured that day: one sweep batch extracted 61 fenced blocks across 12 skills and found the
# S5 pipefail-fallback class alive in four of them (harness-doctor E3/E7/Step-11, install-doctor),
# each rendering a dead check as a PASS. The scanner was not wrong before — it reported those files
# as UNSCANNABLE (exit 2, "NOT scanned, NOT clean"), which is the honest degrade. But "honestly
# unmeasured" on the surface where the code actually lives is a coverage hole, not a resolution.
#
# Method: for a markdown file, write a shadow .sh whose fenced-block lines sit at their ORIGINAL
# line numbers and whose every other line is blank. Line numbers then map 1:1, so an emitted
# finding points at the real file:line with no offset arithmetic to get wrong. A markdown file
# with NO bash fence stays UNSCANNABLE — nothing was extracted, so nothing was measured.
# python3 는 이 레포의 선언된 런타임이 아니다(`package.json engines` = node 만). 부재하면 추출이
# 불가능하고, 그때 md 를 FILES 에도 UNSCANNABLE 에도 넣지 않으면 **요약에서 통째로 사라져**
# "no smells in N scanned files / exit 0" 이 된다 — 이 릴리스가 고치는 바로 그 클래스를 수리가
# 재생산한 것이다(배포 직전 보안 패스가 적발, 2026-08-12). 자매 스크립트들은 이미 옳게 한다:
# validate_yaml → UNCALIBRATED + exit 2, package_coverage → exit 1. 여기도 같은 방향으로 맞춘다.
_MD_OK=1
# `cut` joined this list 2026-08-12 (cross-family, gpt-5.5): the uniqueness token is produced by
# `cksum | cut`, and gating only `cksum` left the pipeline half-guarded — with `cut` missing the
# token is EMPTY, which restores the A-1 shadow-name collision the cksum guard exists to prevent.
# Guarding one stage of a pipeline is not guarding the pipeline.
for _dep in python3 cksum cut; do command -v "$_dep" >/dev/null 2>&1 || _MD_OK=0; done
# `find` is not optional and its absence is not a small result: EVERY target file — .sh, .py and
# .md alike — is discovered through it, and the discovery calls redirect stderr. Without this gate
# a missing/broken `find` yields an empty file list and the run prints "no scannable target files"
# and exits 0 = clean, on a corpus it never looked at. Same class the fence work exists to close,
# one layer further up (cross-family, gpt-5.5, 2026-08-12).
if ! command -v find >/dev/null 2>&1; then
  echo "degrade-scan: INSTRUMENT ERROR — \`find\` is unavailable, so NO file was discovered."
  echo "This is not 'clean' and not 'no targets'; nothing was measured. Fix PATH and re-run."
  exit 2
fi
# cksum 도 미선언 의존성이다 — 첫 수리는 python3 만 가드하고 cksum 은 rc 미검사로 도입했다.
# 부재 시 유일성 토큰이 **빈 문자열**이 돼 shadow 이름 충돌(A-1)이 그대로 부활한다(실증).
# mktemp 실패 시 예측 가능한 경로(/tmp/degradescan.$$)로 폴백하던 것을 제거했다: 그 경로를 mkdir
# 하지 않아 정상 폴백은 100% 실패하고, 반대로 공격자가 그 이름에 심링크를 심어두면 **성공해서
# 레포 밖에 쓴다**(실증됨). 즉 "공격받을 때만 동작하는 코드" 였다.
_MD_TMP="$(mktemp -d 2>/dev/null)" || { _MD_TMP=""; _MD_OK=0; }
trap '[ -n "$_MD_TMP" ] && rm -rf "$_MD_TMP"' EXIT
# LANGUAGE-SPLIT shadows (2026-08-12). The first version extracted only ```bash-family fences, and
# extending it to ```python by widening the same regex would have written python source into a `.sh`
# shadow — where `is_sh` is decided by the extension, so the SHELL probes would run on python and the
# python probes' own file-shape assumptions would be met by accident. That is precisely the
# "collected but probed with the wrong family" false-clean this scanner already names (n+10 below).
# So the extraction is per-language and each language gets its own shadow extension; one markdown
# file can now yield up to two shadows, and `is_sh` keeps deciding correctly by extension.
# WHY python at all: `except: pass` / `.get(k, True)` — the shapes probes A–E exist for — live in
# ```python fences, not in .py files, in this corpus. install-doctor's S came from exactly there.
_md_shadow() {   # $1 = markdown path; $2 = fence language class (sh|py)
                 # echoes shadow path, or nothing when that language has no fence in the file
  # 반환 규약(2026-08-12, cross-family 지적으로 분리): 0 = 추출됨 · **1 = 그 언어 펜스가 없다(정상)**
  # · **2 = 추출을 시도했으나 실패했다(못 쟀다)**. 첫 판은 둘을 똑같이 1 로 접었고, 그래서 읽을 수
  # 없는 SKILL.md 한 개가 「펜스 없음」= UNSCANNABLE 로 렌더돼 같은 디렉토리에 깨끗한 .sh 가 하나라도
  # 있으면 전체가 exit 0 = clean 으로 나갔다. 이 파일이 존재하는 이유인 바로 그 클래스다.
  local src="$1" lang="$2" out ext pat tok rc
  [ "$_MD_OK" = 1 ] || return 2        # 추출 불가 → 호출부가 UNMEASURED 로 보낸다(드롭 금지)
  case "$lang" in
    sh) ext=sh; pat='bash|sh|shell|zsh' ;;
    py) ext=py; pat='python|python3|py' ;;
    *)  return 2 ;;                    # 알 수 없는 언어 클래스 = 추출 실패, 조용한 성공 금지
  esac
  # 경로 해시를 붙인다: `tr '/' '_'` 만 쓰면 a/b.md 와 a_b.md 가 **같은 shadow** 로 매핑돼
  # 뒤엣것이 앞엣것을 덮고, 결함 파일이 통째로 사라진 채 카운트는 2로 찍힌다(실증됨).
  # 확장자가 언어를 가르므로 같은 md 의 sh/py shadow 는 서로 안 덮는다.
  tok=$(printf '%s' "$src" | cksum | cut -d' ' -f1)
  # 토큰이 비면 유일성이 사라져 a/b.md 와 a_b.md 가 같은 shadow 로 접힌다. 빈 값을 그냥 쓰지 말고
  # 「못 쟀다」로 나가라 — 조용히 충돌한 쪽이 항상 더 나쁘다.
  case "$tok" in ''|*[!0-9]*) return 2 ;; esac
  out="$_MD_TMP/$(echo "$src" | tr '/' '_')-$tok.$ext"
  python3 - "$src" "$out" "$pat" <<'PYEOF'
import sys, re
src, out, pat = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(src, encoding='utf-8', errors='replace').read().split('\n')
shadow = [''] * len(lines)
inside = False
found = False
for i, l in enumerate(lines):
    s = l.strip()
    if not inside and re.match(r'^```(' + pat + r')\s*$', s):
        inside = True; continue
    if inside and s == '```':
        inside = False; continue
    if inside:
        shadow[i] = l; found = True
open(out, 'w', encoding='utf-8').write('\n'.join(shadow))
sys.exit(0 if found else 3)
PYEOF
  rc=$?
  case $rc in
    0) ;;             # 추출 성공
    3) return 1 ;;    # 그 언어의 펜스가 이 파일에 없다 — 정상 상태
    *) return 2 ;;    # 읽기 실패·인코딩·인터프리터 오류 — 못 쟀다. 「펜스 없음」과 같은 값 금지
  esac
  printf '%s' "$out"
}
# 한 md 에서 sh·py 두 shadow 를 모두 수집한다. 어느 쪽도 안 나오면 그때만 UNSCANNABLE/UNMEASURED.
# 반환: 0 = 하나 이상 수집됨, 1 = 그 파일에 스캔 대상 펜스 없음, 2 = 추출 자체가 불가(못 쟀다)
_md_collect() {
  local src="$1" lang shp got=0 err=0 rc
  for lang in sh py; do
    shp=$(_md_shadow "$src" "$lang"); rc=$?
    case $rc in
      0) [ -n "$shp" ] && { FILES+=("$shp"); MD_ORIGIN+=("$shp=$src"); got=1; } ;;
      1) ;;          # 이 언어 펜스 없음 — 정상
      *) err=1 ;;    # 추출 실패 — 이 파일은 못 쟀다
    esac
  done
  # 실패가 하나라도 있으면 «못 쟀다»가 이긴다. 다른 언어에서 뭔가 건졌다는 사실이
  # 못 잰 언어를 덮으면 부분 커버리지가 완전 커버리지로 렌더된다.
  [ "$err" = 1 ] && return 2
  [ "$got" = 1 ] && return 0
  return 1
}
for t in "${TARGETS[@]}"; do
  if [ -d "$t" ]; then
    # SYMLINKED TARGET (2026-08-12, cross-family gpt-5.5): `[ -d ]` follows a symlink, `find` does
    # not — `find /path/to/symlink -type f` enumerates NOTHING and the run printed "no scannable
    # (py/sh) target files" and exited 0 for a directory full of known-positives. `-H` makes find
    # follow the command-line argument only (not links found during the walk, which is what would
    # invite cycles). Measured: symlink target → 0 files without it, 1 with it.
    # A target whose name starts with `-` is parsed by BSD find as an option ("illegal option").
    # Prefix it with `./` so it is unambiguously a path. Only for that case — prefixing every target
    # would rewrite every reported path to `./…` for no benefit.
    case "$t" in
      -*) _T=(-H "./$t") ;;
      *)  _T=(-H "$t") ;;
    esac
    # DISCOVERY ERRORS (2026-08-12, cross-family gpt-5.5): the `find` preflight above proves the
    # BINARY exists; it says nothing about whether this particular traversal worked. Every discovery
    # call below redirects stderr and reads its output through a process substitution, which throws
    # the exit status away — so an unreadable target directory produced an empty file list and the
    # run printed "no scannable (py/sh) target files" and exited 0 = CLEAN, having looked at nothing.
    # Reproduced with a mode-000 directory containing a known-positive `bad.sh`.
    # One extra traversal per target is the price; a silent zero is not an acceptable alternative.
    _derr=$(find "${_T[@]}" -type f 2>&1 >/dev/null); _drc=$?
    if [ "$_drc" -ne 0 ] || [ -n "$_derr" ]; then
      DISCOVERY_ERR+=("$t — ${_derr:-find exited $_drc}")
    fi
    while IFS= read -r f; do FILES+=("$f"); done < <(find "${_T[@]}" -type f \( -name '*.py' -o -name '*.sh' \) 2>/dev/null)
    # Shebang pass — this is what makes git hooks visible at all. Measured 2026-07-28:
    # `templates/.git-hooks` (files named `pre-push`, no extension, under a dotted directory) —
    # FH's own mechanical floor — reported "no scannable (py/sh) target files", exit 0.
    # Shebang pass. Deliberately NOT restricted to extensionless names: a cross-family audit
    # (2026-07-28, gpt-5.5) found that an earlier draft skipped any dotted basename, so a shell
    # file named `helper.bash` carrying an identical known-positive was dropped from a DIRECTORY
    # target in silence — while the explicit-file branch reported the same file as UNSCANNABLE.
    # Silent-drop on one path and honest-report on the other is the fail-open half. Confirmed by
    # running both paths on the same fixture before accepting the finding.
    while IFS= read -r f; do
      b="${f##*/}"                      # basename — a dotted DIRECTORY (.git-hooks) is not an extension
      case "$b" in
        *.py|*.sh) continue ;;          # already collected above
        *.md|*.json|*.yaml|*.yml|*.txt|*.lock|*.png|*.jpg|*.svg|*.pdf|*.zip) continue ;;
      esac
      head -n1 "$f" 2>/dev/null | grep -qE '^#!.*\b(ba|z|k)?sh\b' && FILES+=("$f")
    done < <(find "${_T[@]}" -type f 2>/dev/null)
    while IFS= read -r f; do
      _md_collect "$f"
      case $? in
        0) ;;                   # sh/py 펜스에서 하나 이상 수집됨
        1) UNSCANNABLE+=("$f") ;;   # 펜스가 없다 — 측정 대상이 아님(정상)
        *) UNMEASURED+=("$f") ;;    # 추출 자체가 불가 — 못 쟀다(CLEAN 으로 접히면 안 된다)
      esac
    done < <(find "${_T[@]}" -type f -name '*.md' 2>/dev/null)
  elif [ -f "$t" ]; then
    tb="${t##*/}"
    case "$tb" in
      *.py|*.sh) FILES+=("$t") ;;
      *.md)
        _md_collect "$t"
        case $? in
          0) ;;                    # at least one sh/py fence extracted
          1) UNSCANNABLE+=("$t") ;;   # no scannable fence — not a measurement target
          *) UNMEASURED+=("$t") ;;    # extraction impossible — could not measure
        esac ;;
      *.*) UNSCANNABLE+=("$t") ;;
      *) if head -n1 "$t" 2>/dev/null | grep -qE '^#!.*\b(ba|z|k)?sh\b'; then FILES+=("$t"); else UNSCANNABLE+=("$t"); fi ;;
    esac
  fi
done
# 탐색 자체가 실패했으면 그 타깃은 **못 쟀다**. 파일 목록이 비어 나오는 것과 구분이 안 되므로
# 여기서 명시적으로 비-clean 을 건다 — 이 블록이 없으면 「읽을 수 없는 디렉토리」가
# 「스캔 대상 없음 · exit 0」으로 렌더된다(같은 파일이 고치는 그 클래스, 한 층 위).
if [ ${#DISCOVERY_ERR[@]} -gt 0 ]; then
  echo "degrade-scan: ${#DISCOVERY_ERR[@]} target(s) COULD NOT BE MEASURED (directory traversal failed):"
  printf '  (discovery-error) %s\n' "${DISCOVERY_ERR[@]}"
  echo "This is NOT 'clean' — part of the requested surface was never enumerated."
  _FORCE_NONCLEAN=2
fi
# 못 잰 파일이 있으면 hits 와 무관하게 비-clean 이다. 이 블록이 FILES 비었을 때만 도는 구조가
# S 의 정체였다 — 스캔 가능한 파일이 하나라도 있으면 「못 쟀다」가 note 로 강등되고 rc=0 이 나갔다.
if [ ${#UNMEASURED[@]} -gt 0 ]; then
  echo "degrade-scan: ${#UNMEASURED[@]} file(s) COULD NOT BE MEASURED (markdown fence extraction unavailable — python3/cksum missing):"
  printf '  (unmeasured) %s\n' "${UNMEASURED[@]}"
  echo "This is NOT 'clean' — the fence surface was not scanned at all. Install python3+cksum or scan those files elsewhere."
  _FORCE_NONCLEAN=2
fi
if [ ${#FILES[@]} -eq 0 ]; then
  if [ ${#UNSCANNABLE[@]} -gt 0 ]; then
    echo "degrade-scan: ${#UNSCANNABLE[@]} changed file(s) are OUTSIDE the scannable set (py/sh) — NOT scanned, NOT 'clean':"
    printf '  (unscannable) %s\n' "${UNSCANNABLE[@]}"
    echo "A load-bearing surface in another language must go straight to cross-family review."
    exit 2   # advisory non-clean — an orchestrator keying on exit code must not read this as clean
  fi
  echo "degrade-scan: no scannable (py/sh) target files"; exit "${_FORCE_NONCLEAN:-0}"
fi

hits=0
# A markdown fence is scanned through a shadow .sh (see §Markdown fence extraction). The finding
# must point at the file a human can open, so emit translates the shadow path back to its origin —
# line numbers need no adjustment because the shadow preserves them by construction. A finding that
# names a path under /tmp is unactionable, which would make the new coverage decorative.
_origin() {
  local sh="$1" pair lbl
  # 라벨은 shadow 확장자에서 나온다 — 하드코딩하면 python 펜스 결함이 「bash fence」로 보고돼
  # 사람이 그 줄을 열었을 때 안 맞는 코드를 보게 된다(리포트가 거짓말을 하는 형태).
  case "$sh" in
    *.py) lbl='```python fence' ;;
    *)    lbl='```bash fence' ;;
  esac
  for pair in "${MD_ORIGIN[@]:-}"; do
    [ "${pair%%=*}" = "$sh" ] && { printf '%s (%s)' "${pair#*=}" "$lbl"; return; }
  done
  printf '%s' "$sh"
}
emit() { printf '  %s:%s\n    [%s] %s\n' "$(_origin "$1")" "$2" "$3" "$4"; hits=$((hits+1)); }

for f in "${FILES[@]}"; do
  # ---- Shell-shaped probes (S*) -------------------------------------------------------------
  # Calibration finding (2026-07-28, known-pair): every probe below the S-block is PYTHON-shaped
  # (`except:` / `.get(k, True)` / `if not x:` / `.split()`), none of which exist in bash. A .sh file
  # was still COLLECTED and counted, so a fail-open shell gate printed "no smells in 1 scanned py/sh
  # file" — a FALSE CLEAN, which is worse than honest non-coverage. A known-positive .sh carrying four
  # distinct default-toward-PASS shapes scored 0/4. These probes close that; they run on any file
  # whose basename ends in .sh OR that carries a shell shebang (see the is_sh test below).
  is_sh=""; fb="${f##*/}"
  case "$fb" in
    *.sh) is_sh=1 ;;
    *.py) ;;
    # Any other collected file reached FILES only via the shebang pass, or is a dotted shell name
    # like `helper.bash`. Re-check the shebang rather than keying on the extension — keying on the
    # extension is what produced the collect-but-never-probe false clean this whole block exists to
    # close (n+10). Collected-but-unprobed must not be reachable again.
    *) head -n1 "$f" 2>/dev/null | grep -qE '^#!.*\b(ba|z|k)?sh\b' && is_sh=1 ;;
  esac
  if [ -n "$is_sh" ]; then
    # S1 — permissive short-circuit on a FAILING CHECK: `scan=$(...) || return 0`, `verify … || exit 0`.
    #   The check errored and the surface reports success. Safe-fail is `|| return 1` / `|| exit 1`.
    #   SCOPED to check-shaped left-hand sides (command substitution, or a verb like
    #   scan/check/verify/grep/audit/validate/gate). A PRECONDITION guard — `[ -d x ] || exit 0`,
    #   `[[ $d =~ … ]] || return 0` — is deliberately excluded: "this run does not apply here" is not
    #   the same claim as "this check passed". Hand-measured 2026-07-28: unscoped, 6/6 sampled hits
    #   were false positives, 4 of them precondition guards.
    #   EXCEPTION, re-added after an adversarial pass on this very scoping: a `-f`/`-x` test is a
    #   DEPENDENCY check, not a scope check. `[ -f "$GUARD_LIB" ] || exit 0` means "my guard library
    #   is missing, therefore allow" — the fail-open shape that bit qasp on 2026-07-28. Excluding it
    #   with the scope guards would have hidden exactly the class this scan exists to find.
    while IFS= read -r m; do
      emit "$f" "${m%%:*}" "S1:||→PASS(sh)" "failing check short-circuits to a permissive result (\`|| return 0\` / \`|| exit 0\` / \`|| true\`) — an errored check must fail closed, not report success"
    done < <(grep -nE '\|\|[[:space:]]*(return[[:space:]]+0|exit[[:space:]]+0|true)([[:space:]]*(#|;|$))' "$f" 2>/dev/null \
             | grep -vE '#[[:space:]]*noqa[:[:space:]]*degrade' \
             | grep -vE '^[0-9]+:[[:space:]]*(if[[:space:]]+)?\[\[?[[:space:]]*(-[dznN][[:space:]]|[^]]*=~)' \
             | grep -E '(\$\(|`|\[[[:space:]]*-[fx][[:space:]]|\b(scan|check|verify|validate|audit|grep|gate|assert|lint|test_)[A-Za-z_]*[[:space:](])')

    # S2 — `else` fall-through to a permissive exit/return within 2 lines (unenumerated case → allow).
    while IFS= read -r ln; do
      emit "$f" "$ln" "S2:else→PASS(sh)" "else/fall-through branch exits permissively — the unenumerated case should fail closed"
    done < <(grep -nE -A2 '^[[:space:]]*else[[:space:]]*$' "$f" 2>/dev/null \
             | grep -E '^[0-9]+[-:][[:space:]]*(exit[[:space:]]+0|return[[:space:]]+0)[[:space:]]*(#.*)?$' \
             | grep -oE '^[0-9]+' | sort -u)

    # S3 — empty/unset defaulted to a permissive VERDICT: `${V:-PASS}` / `V="PASS"` after a failed read.
    #   "the value never arrived" must not be spelled the same way as "the value said PASS".
    #   `${V:-0}` and `${V:-true}` are NOT flagged: numeric defaulting is the prescribed integer
    #   sanitization against the pipefail-fallback class (see S5), and flagging it would push an
    #   author to delete the remedy. Measured 2026-07-28 — `${PRS:-0}` in session_close_check.sh is
    #   the fix, not the defect. Only explicit verdict words count.
    while IFS= read -r m; do
      emit "$f" "${m%%:*}" "S3:default→PASS(sh)" "unset/empty defaults to a permissive verdict — absent is not clean (\`not found\` ≠ \`0\`); default to the blocking value"
    done < <(grep -nE "(\\$\{[A-Za-z_][A-Za-z0-9_]*:?-[[:space:]]*(PASS|OK|ALLOW|GRANTED|VALID|PASSED)\}|\|\|[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[\"']?(PASS|OK|ALLOW|GRANTED|VALID))" "$f" 2>/dev/null \
             | grep -vE '#[[:space:]]*noqa[:[:space:]]*degrade')

    # S4 — empty-output guard treated as clean: `if [ -z "$out" ]; then return 0/exit 0`.
    #   Identical to Probe E's falsy-sentinel class, in shell spelling: an errored scan produces empty
    #   output, so "found nothing" and "never ran" become indistinguishable.
    while IFS= read -r ln; do
      emit "$f" "$ln" "S4:empty→PASS(sh)" "empty output treated as clean — a scan that errored also produces empty output; distinguish 'errored/absent' from 'verified clean'"
    done < <(grep -nE -A2 '^[[:space:]]*(if|elif)[[:space:]]+\[+[[:space:]]*-z[[:space:]]' "$f" 2>/dev/null \
             | grep -E '^[0-9]+[-:][[:space:]]*(exit[[:space:]]+0|return[[:space:]]+0)[[:space:]]*(#.*)?$' \
             | grep -oE '^[0-9]+' | sort -u)

    # S5 — the pipefail-fallback disarm: `... | grep -c ... || echo 0` appends a SECOND line under
    #   `set -o pipefail`, so the later `-gt` integer test becomes a bash error (= false) and the guard
    #   passes silently, with the error going only to stderr. Measured class, 2026-07-26.
    #
    # NARROWED 2026-07-28 after hand-verifying all 9 hits this repo produced: 9/9 were false
    # positives, i.e. the probe was pure noise for its own class, and 100% FP trains dismissal of
    # the one hit that will matter. Two distinct causes, both mechanically reproduced:
    #   (a) `a || b || echo 0` was read as a pipeline — the old regex could anchor its `\|` on the
    #       SECOND bar of the first `||`. No pipe exists, so no second line can ever be produced.
    #       (Every `_mtime() { stat -c %Y … || stat -f %m … || echo 0; }` in the tree was flagged.)
    #   (b) a real pipeline whose failing stage emits NOTHING (`… | jq -r … || echo 0`) — the
    #       fallback then supplies the only line, which is exactly the intended behavior.
    # The disarm needs BOTH a real pipe AND a final stage that emits regardless of upstream failure
    # — a counter (`grep -c`, `wc`). That is the measured shape: `find … | grep -c . || echo 0`
    # yields "9\n0" and the `-gt` guard goes silent. Verified as a known pair (both directions) in
    # scripts/test_degrade_scan_shell_probes.sh; narrowing without that anchor would just trade a
    # noisy probe for a blind one.
    #
    # WIDENED 2026-08-04 — the narrowing had gone one step too far, and the proof is that this
    # probe was BLIND to the live instance that bit us the day before. PR #251 fixed
    # `grep -c … | tr -d ' ' || echo 0` in session_close_check.sh ④-e; running this scanner over
    # the pre-#251 file produced ZERO hits (re-measured: fixed rule = 2, old rule = 0).
    #
    # THE ANCHOR WAS ON THE WRONG PROPERTY. The old regex asked "is there an upstream pipe" and
    # required the counter to be the LAST stage. Neither is the discriminator. The discriminator
    # is: **does the failing side still EMIT?** `grep -c` prints "0" and exits 1 on no-match, so it
    # disarms with no upstream pipe at all, and any trailing stage that passes that "0" through
    # keeps the "0\n0" intact.
    #
    # A first fix widened to a NAMED filter list (tr|head|sed|…). Cross-family review (gpt-5.5,
    # 2026-08-04) refuted it with reproduced counter-examples, and the refutation held on
    # measurement in BOTH directions:
    #   · still missed, all verified to yield "0\n0": `grep -Ec …`, `grep --count …`, `grep -Fcx …`
    #     (combined/long flag forms the `-c` literal never matched) and `| cat`.
    #   · newly over-matched: `| tail -n +2` after the counter yields ONE line — not a disarm.
    # Name-based approximation produced under-match and over-match simultaneously. So the trailing
    # chain is no longer enumerated: the rule keys on the COUNTER (grep with a `c` in any flag
    # cluster or `--count`; or `wc` behind a real pipe) plus the `|| echo 0` fallback, and accepts
    # any chain between them.
    #
    # PRESERVED from the 2026-07-28 narrowing, still pinned as known-negatives: (a) `a || b ||
    # echo 0` has no pipeline, and (b) a stage that emits NOTHING on failure (`| jq -r … ||
    # echo 0`) — there the fallback supplies the only line, as intended.
    # KNOWN RESIDUAL, stated not hidden: a trailing stage that can swallow the counter's output
    # (`| tail -n +2`, `| sed -n '/[1-9]/p'`) is now flagged though it is not a disarm. That is a
    # deliberate recall-over-precision trade on an ADVISORY probe, taken because the measured cost
    # of the other direction was a real defect shipping. Revisit if non-fixture FPs appear.
    # Known pair: scripts/test_degrade_scan_shell_probes.sh (9 positives / negatives silent).
    # Reverting this line turns the positive lane red — checked by applying the revert.
    while IFS= read -r m; do
      emit "$f" "${m%%:*}" "S5:pipefail-fallback(sh)" "\`|| echo 0\` fallback after a COUNTER (grep with -c / --count, or wc) — the counter PRINTS \"0\" and exits non-zero on no-match, so the fallback appends a SECOND line, the value becomes \"0\\n0\", the integer test dies with 'integer expression expected' (stderr only) and the guard goes silent; split it and sanitize: n=\$(...); n=\${n:-0}; case \$n in *[!0-9]*) n=0;; esac. VERIFY the trailing stage can actually emit — if it swallows the count (| tail -n +2), this is a known false positive"
    done < <(grep -nE '(([^|]\|[[:space:]]*([a-z]+[[:space:]]+)*wc[^|]*)|(grep([[:space:]]+-[A-Za-z]*c[A-Za-z]*|[[:space:]]+--count)[^|]*))([^|]*\|[^|]*)*\|\|[[:space:]]*echo[[:space:]]+[\"'"'"']?0' "$f" 2>/dev/null \
             | grep -vE '^[0-9]+:[[:space:]]*#' \
             | grep -vE '#[[:space:]]*noqa[:[:space:]]*degrade')

    # S6 — SHELL-DEPENDENT word split: `for x in $VAR` / `cmd -- $LIST` on an unquoted PARAMETER
    #   expansion. bash splits it on IFS; **zsh does not** (SH_WORD_SPLIT is off by default), so the
    #   loop body runs ONCE with the entire newline-joined blob as a single word. Every per-item test
    #   inside then fails against a filename that does not exist — and the loop's counters stay 0,
    #   which the surrounding code reports as "nothing found". Same family as the rest of this file:
    #   an unmeasured surface rendered as a zero. The default macOS login shell is zsh, and this
    #   corpus's bash lives in SKILL.md fences that a human may paste into that shell.
    #
    #   SCOPE, and the discriminator this probe would be wrong without: `for f in $(cmd)` is NOT
    #   flagged. Command substitution DOES word-split in zsh — SH_WORD_SPLIT governs *parameter*
    #   expansion only. Flagging `$(...)` would have made this probe fire on the idiomatic form that
    #   behaves identically in both shells, i.e. pure noise. Verified in both shells before shipping.
    #   `"$@"` / `${arr[@]}` are excluded for the same reason: those are array expansions, which
    #   split by element in zsh too.
    #
    #   Measured N=3 (2026-08-11..12): a scan whose `grep` returned rc=2 read as "clean" until it was
    #   re-measured; a repair session hit the same shape; and `harness-doctor` L5-A ships it live —
    #   `for f in $recent_sessions` (SKILL_detail.md:201/207), where under zsh every skill in the
    #   harness reports INACTIVE_90D. Hand-found, not scanner-found: that is what this probe closes.
    #   APPLICABILITY — S6 only fires where the execution shell is NOT pinned to a splitting shell.
    #   Measured 2026-08-12 on 28 hits, and the split is clean at 100%: all 7 hits inside markdown
    #   fences were REAL, and all 21 hits in `.sh` files carrying a `#!…bash` shebang were FALSE —
    #   bash runs those files, so the splitting is the intended semantics there, not a defect. A
    #   probe that is 75% noise trains authors to dismiss it, which is how the one hit that matters
    #   gets waved through (this file already paid that price once at 9/9 FP on S5).
    #   So: markdown-fence shadows (a human may paste them into zsh — the macOS login shell) and
    #   files whose shebang IS zsh. Nothing else.
    #   The test is INVERTED (2026-08-12, round-4 cross-family): the first draft asked "is this a
    #   markdown shadow or a zsh script?" and therefore excluded a `.sh` file with NO shebang —
    #   which is not pinned to anything either, so the defect is live there too. Ask the question
    #   that actually decides it: **does a shebang pin a splitting shell?** Unknown shell → the
    #   probe applies, which is the fail-closed direction for a detector.
    _s6_applies=1
    # `ksh[0-9]*` — `#!/usr/bin/env ksh93` was classified as unpinned because `\bksh\b` cannot match
    # inside `ksh93` (a digit is a word character). ksh93 splits `$VAR` like bash, so it IS pinned.
    head -n1 "$f" 2>/dev/null | grep -qE '^#!.*\b(bash|ksh[0-9]*|dash|ash)\b|^#!.*[/ ]sh([[:space:]]|$)' && _s6_applies=""
    if [ -n "$_s6_applies" ]; then
    # PATTERN (widened 2026-08-12, round 5). The first form only matched a bare `$VAR` / `${VAR}`,
    # so `for f in ${FILES:-}` — same defect, one operator away — was a FALSE NEGATIVE.
    # The braced alternative now admits the expansion operators (`:-` `:=` `:?` `:+` `#` `%` `^` `,`)
    # but **excludes `[` by construction** (`[^}[]*`). That exclusion is doing real work: widening
    # the pattern is exactly what would make `${arr[@]}` match, and an array expansion splits by
    # element in zsh too, so it is not this defect. Encoding it in the pattern rather than as a
    # downstream `grep -v` is deliberate — the line-level filter version of this rule was deleted
    # earlier today precisely because it killed whole lines, including real hits.
    S6_PAT='(for[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in|--)[[:space:]]+(\$[A-Za-z_][A-Za-z0-9_]*|\$\{[A-Za-z_][A-Za-z0-9_]*([:#%^,!][^}[]*)?\})([[:space:];]|$)'
    while IFS= read -r m; do
      emit "$f" "${m%%:*}" "S6:wordsplit-shell-dep(sh)" "unquoted parameter expansion in a word-split position (\`for x in \$VAR\` / \`-- \$LIST\`) — bash splits on IFS but zsh does NOT, so under zsh the loop runs once over the whole blob and per-item results silently come back empty; iterate explicitly instead: \`printf '%s\\n' \"\$VAR\" | while IFS= read -r x; do …\` (or use an array). Command substitution \`\$(cmd)\` splits in both shells and is NOT this defect"
      # NO COMMENT STRIPPING, and no array-form exclusion — both were removed 2026-08-12 after two
      # cross-family rounds, and the reasoning is worth keeping because the removal LOOKS like a
      # weakening and is not:
      #   · the `grep -vE '\[[@*]\]'` array exclusion was DEAD CODE. Measured against all six
      #     spellings: `$S6_PAT` requires `$name` followed by space/;/EOL, so `${arr[@]}` and
      #     `"${arr[@]}"` never match it in the first place. The filter excluded nothing real — but
      #     it matched the whole LINE, so a genuine defect whose trailing comment mentioned the safe
      #     form (`git add -- $FILES  # use "${arr[@]}" later`) was silently dropped. A dead filter
      #     that only ever fires on false grounds is worse than no filter.
      #   · the `sed 's/#.*$//'` that was added to work around it then introduced its own false
      #     negative: it cannot tell a comment from a `#` inside a quoted string, so
      #     `printf "#"; git add -- $FILES` lost its real hit.
      # Accepted trade, stated rather than hidden: a match living ONLY in a trailing comment is now
      # reported. Full-line comments are still excluded above. Recall over precision is the right
      # direction for an advisory detector — a missed defect is silent, a noisy line is not.
    done < <(grep -nE "$S6_PAT" "$f" 2>/dev/null \
             | grep -vE '^[0-9]+:[[:space:]]*#' \
             | grep -vE '#[[:space:]]*noqa[:[:space:]]*degrade')
    fi
  fi

  # Probe A — except/else/finally block returning a permissive value within 2 lines.
  #   The classic "swallow the error → report success". A safe-fail returns BLOCK/None/raise.
  while IFS= read -r line; do
    ln="${line%%:*}"
    emit "$f" "$ln" "A:except/else→PASS" "permissive return on an error/fall-through branch — safe-fail must return BLOCK/None or re-raise"
  done < <(grep -nE -A2 '^[[:space:]]*(except([[:space:]][^:]*)?|else|finally)[[:space:]]*:' "$f" 2>/dev/null \
           | grep -E "return[[:space:]]+$PASS([[:space:],)]|$)" | grep -oE '^[0-9]+' | sort -u | sed 's/$/:/')

  # Probe B — dict default / setdefault to a permissive value (unknown key → PASS).
  while IFS= read -r m; do
    emit "$f" "${m%%:*}" "B:default→PASS" "unknown-key default is permissive — unenumerated case should default to safe-fail"
  done < <(grep -nE "(\.get\([^,]+,[[:space:]]*$PASS[[:space:])]|setdefault\([^,]+,[[:space:]]*$PASS[[:space:])])" "$f" 2>/dev/null)

  # Probe C — substring membership on a grounding/verdict/state line (loose match, not exact).
  #   `if tok in text` masks paid⊂prepaid / 완료⊂미완료. Exact/word-boundary is the safe form.
  while IFS= read -r m; do
    emit "$f" "${m%%:*}" "C:substring-grounding" "substring 'in' on a verdict/state/present line — use exact or word-boundary match, not containment"
  done < <(grep -nE '\b(verdict|present|ground|state|match|expected|assert)\w*\b' "$f" 2>/dev/null \
           | grep -vE ':[[:space:]]*(#|//|from |import )' | grep -vE '#[[:space:]]*noqa[:[:space:]]*degrade' \
           | grep -E '[^._a-zA-Z]in[[:space:]]' | grep -vE '\bfor\b|__contains__|not in|in \(|in \[|in \{|in range|in enumerate|in [A-Z_]+\b' \
           | grep -oE '^[0-9]+' | sed 's/$/:/')

  # Probe C2 — bare `VAR in VAR` in an if/return/assert/while context, WITHOUT a grounding keyword.
  #   Probe C is keyword-gated (low-noise) and therefore misses the doc's own headline example
  #   `tok in text` (paid⊂prepaid) when the variables aren't named verdict/state (M#4, steel-quench).
  #   C2 closes that: simple var-in-var (not a collection literal / range / for) = a likely
  #   containment check that should be exact/word-boundary if it grounds a verdict. Higher noise; advisory.
  while IFS= read -r m; do
    emit "$f" "${m%%:*}" "C2:substring-boolean" "bare 'X in Y' in if/return/assert — if this grounds a presence/verdict check, use exact/word-boundary match, not containment"
  done < <(grep -nE '^[[:space:]]*(if|elif|return|assert|while)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*[[:space:]]*[:)]?[[:space:]]*$' "$f" 2>/dev/null \
           | grep -vE '\bfor\b|in range|in enumerate|not in' \
           | grep -vE '\b(verdict|present|ground|state|match|expected)\w*\b')

  # Probe E — negated-falsy guard returning permissive (dominance-benchmark round-2 f2 class): an error
  # SENTINEL (None / {} / "" / []) is falsy, so `if not X: return <PASS>` treats "the check errored / never
  # ran" identically to "the check ran and found nothing clean". Distinguish errored from clean before allowing.
  while IFS= read -r ln; do
    emit "$f" "$ln" "E:falsy-sentinel→PASS" "negated-falsy guard returns permissive — a falsy error sentinel (None/{}/'') masquerades as 'clean'; a gate must distinguish 'errored/absent' from 'verified clean'"
  done < <(grep -nE -A2 '^[[:space:]]*if[[:space:]]+not[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*[[:space:]]*:' "$f" 2>/dev/null \
           | grep -E "return[[:space:]]+$PASS([[:space:],)]|$)" | grep -oE '^[0-9]+' | sort -u | sed 's/$/:/')

  # Probe F — positional field-select from a split result feeding a decision (round-2 c3 class): taking the
  # decision from `parts[-1]`/`parts[0]` of an attacker-influenceable split lets a crafted field (e.g. a
  # signed DENY whose free-form comment ends "::ALLOW") negate the verdict. Validate structure, don't select by position.
  if grep -qE '\.r?split\(' "$f" 2>/dev/null; then
    while IFS= read -r m; do
      emit "$f" "${m%%:*}" "F:split-positional-verdict" "decision taken by position ([-1]/[0]) from a split result — an attacker-controlled trailing/leading field can negate the verdict; validate structure, don't select by position"
    done < <(grep -nE '\[[[:space:]]*-?[01][[:space:]]*\]' "$f" 2>/dev/null \
             | grep -iE 'decision|verdict|allow|deny|approv|grant|status|result|policy')
  fi
done

echo "----"
[ ${#UNSCANNABLE[@]} -gt 0 ] && printf 'note: %s changed file(s) outside py/sh — NOT covered by this scan (send to cross-family directly).\n' "${#UNSCANNABLE[@]}"
if [ "$hits" -gt 0 ]; then
  echo "degrade-scan: $hits smell(s) — ADVISORY. Each = 'prove this is not default-toward-PASS'."
  echo "Terminal verdict = cross-family adversarial review (auto-decorrelation), not this scan."
  exit 2
fi
# Scope-honest clean message (M#2): "clean" means only "no py/sh-pattern smells in the SCANNED set" —
# it does NOT assert the changed load-bearing surface is safe (other languages, non-code surfaces,
# and the lint's own recall gaps are out of scope). The load-bearing check is the cross-family review.
echo "degrade-scan: no default-toward-PASS smells in ${#FILES[@]} scanned py/sh file(s) — does NOT cover other languages / non-code surfaces / the cross-family check (advisory)."
exit "${_FORCE_NONCLEAN:-0}"   # 못 잰 파일이 있으면 0 이 아니다 — "안 쟀다"는 "깨끗하다"가 아니다
