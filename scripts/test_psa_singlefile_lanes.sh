#!/usr/bin/env bash
# test_psa_singlefile_lanes.sh — known-pair lanes for the public-surface scanner's SINGLE-FILE and
# MISUSE paths.
#
# What these lanes exist to hold (all measured 2026-08-12, all found by a control and not by review):
#   L1  `public_surface_scan_files.sh <path>` used to IGNORE the argument and print its normal green,
#       so a caller asking "is THIS file clean?" got a PASS about a file set that never contained it.
#   L3/L4  `psa_scan_tagged` piped from a shell without `cat` died on its first line and returned 0 —
#       a known-positive scanned as 0 hits. "The scanner ran" and "the scanner said clean" are
#       different claims and were indistinguishable.
#   L7  a missing file returned 0 hits, i.e. `not found` rendered as `0`.
#   L9  a display that greps only ❌ renders an ALLOWLISTED token (⚪) as "no match" — that is how an
#       existing operator allowlist decision got misread as an absent pattern.
#
# HERMETIC BY CONSTRUCTION: every lane builds its own pattern/allowlist files under a temp dir. It
# must NOT read `.claude/rules/.public-surface-patterns` (gitignored, operator-private) — a lane that
# depends on an operator-local file is unrunnable on a fresh clone and in CI, and would silently
# degrade to "0 lanes ran" there, which is the same not-measured-is-not-zero shape these lanes guard.
#
# Verdict is the exit code. Never parse a summary line for it.

set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
LIB="$REPO_ROOT/scripts/psa_scan_lib.sh"
PUB="$REPO_ROOT/scripts/public_surface_scan_files.sh"
TMP=$(mktemp -d) || exit 9
trap 'rm -rf "$TMP"' EXIT

# HERMETIC BINDING (cross-family round 1 refuted the original claim of hermeticity): lanes that did
# not set PSA_ALLOWLIST fell through to the library default, which is the operator's GITIGNORED
# allowlist. A lane whose verdict depends on a file that does not exist on a fresh clone is not
# hermetic — it is silently a different test there. Bound once, for every lane.
export PSA_ALLOWLIST="$TMP/allowlist"
# Environment hermeticity (round 2): PUBLIC_SURFACE_OK is an operator override that converts the
# publish scanner's fail-closed exit into a proceed. Inherited from the caller's shell it silently
# flips L2's expected verdict — a lane whose result depends on an ambient env var is measuring the
# environment, not the code.
unset PUBLIC_SURFACE_OK

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ✅ %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  ❌ %s\n' "$1"; }
# check <name> <expected_rc> <actual_rc> [substring_that_must_appear] [output]
check() {
  local name="$1" want="$2" got="$3" need="${4:-}" out="${5:-}"
  if [ "$got" != "$want" ]; then bad "$name — rc want=$want got=$got"; return; fi
  if [ -n "$need" ]; then
    case "$out" in *"$need"*) ;; *) bad "$name — rc ok but output lacks '$need'"; return ;; esac
  fi
  ok "$name"
}

# ── fixtures ────────────────────────────────────────────────────────────────────────────────────
printf 'HIGH\tPSA_LANE_SECRET\nHIGH\tPSA_LANE_ALLOWED\n' > "$TMP/defaults"
printf '# empty operator override is still "present + non-empty" for these lanes\nLOW\tPSA_LANE_LOW\n' > "$TMP/override"
printf 'fixtures/allowed.md\tPSA_LANE_ALLOWED\n' > "$TMP/allowlist"
mkdir -p "$TMP/fixtures"
printf 'harmless line\ncontact PSA_LANE_SECRET here\n' > "$TMP/fixtures/positive.md"
printf 'nothing to see\njust prose\n'                  > "$TMP/fixtures/negative.md"
printf 'this names PSA_LANE_ALLOWED on purpose\n'       > "$TMP/fixtures/allowed.md"

echo "[psa single-file lanes]"

# ── L1/L2 : misuse of the publish scanner fails CLOSED, and the no-arg path is untouched ────────
out=$("$PUB" /nonexistent/definitely_not_a_file_zzz.md 2>&1); rc=$?
check "L1 publish-scanner: positional arg → rc=2 refuse" 2 "$rc" "USAGE ERROR" "$out"

# Control for L1: prove the guard did NOT swallow the normal no-arg path. A deliberately unresolvable
# pattern source makes the no-arg run exit at the instrument check (rc=1) BEFORE `npm pack`, so this
# stays fast and still proves the run got past the argument guard.
# Cross-family round 1: the first version only rejected rc=2, so a scanner that wrongly exited 0 PASS
# on an unresolvable pattern source would still have shown green. A control that cannot fail in the
# direction you care about is not a control. It now demands the specific fail-closed outcome.
out=$(PSA_PATTERNS=/nonexistent/nope "$PUB" 2>&1); rc=$?
check "L2 publish-scanner: no-arg path reaches the instrument check and fails closed" 1 "$rc" "incomplete confidentiality instrument" "$out"

# ── L3/L4 : the liveness self-test separates "ran and found nothing" from "never ran" ────────────
out=$(
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/override" >/dev/null 2>&1
  psa_require_live 2>&1
); rc=$?
check "L3 psa_require_live: healthy shell → alive" 0 "$rc"

# The reproduction: a shell whose PATH has no `cat`. psa_scan_tagged dies on its first line and would
# otherwise return 0 — which is what made a known-positive read as clean.
out=$(/usr/bin/env -i PATH=/nonexistent/bin /bin/bash -c "
  . '$LIB'; psa_load '$TMP/defaults' '$TMP/override' >/dev/null 2>&1
  psa_require_live
" 2>&1); rc=$?
check "L4 psa_require_live: PATH without cat → DEAD, not clean" 1 "$rc" "INSTRUMENT DEAD" "$out"

# ── L5/L6 : ordinary single-file verdicts ───────────────────────────────────────────────────────
out=$(
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/override" >/dev/null 2>&1
  PSA_ALLOWLIST="$TMP/allowlist" psa_scan_file "$TMP/fixtures/positive.md" 2>&1
); rc=$?
check "L5 psa_scan_file: known-positive → rc=1 + reports the token" 1 "$rc" "PSA_LANE_SECRET" "$out"

out=$(
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/override" >/dev/null 2>&1
  PSA_ALLOWLIST="$TMP/allowlist" psa_scan_file "$TMP/fixtures/negative.md" 2>&1
); rc=$?
check "L6 psa_scan_file: known-negative → rc=0" 0 "$rc"

# ── L7/L8 : unmeasured is its own value, never 0 ────────────────────────────────────────────────
out=$(
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/override" >/dev/null 2>&1
  psa_scan_file "$TMP/fixtures/does_not_exist.md" 2>&1
); rc=$?
check "L7 psa_scan_file: missing file → rc=3 NOT SCANNED (not 0)" 3 "$rc" "NOT SCANNED" "$out"

out=$(
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/override" >/dev/null 2>&1
  psa_scan_file 2>&1
); rc=$?
check "L8 psa_scan_file: no argument → rc=3 usage (not 0)" 3 "$rc" "USAGE" "$out"

# ── L9 : allowlisted (⚪) is a THIRD outcome and must remain visible ─────────────────────────────
# This is the regression anchor for the display-collapse: rc is 0 like a clean file, so a caller that
# only inspects rc — or greps only ❌ — cannot tell "an operator decided to permit this token here"
# from "this pattern never matched". The ⚪ line is the only thing that separates them.
out=$(
  cd "$TMP" || exit 9
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/override" >/dev/null 2>&1
  PSA_ALLOWLIST="$TMP/allowlist" psa_scan_file "fixtures/allowed.md" 2>&1
); rc=$?
check "L9 psa_scan_file: allowlisted token → rc=0 AND an explicit ⚪ line" 0 "$rc" "⚪ allowlisted" "$out"

# L9b asserts the ABSENCE of a ❌ — and an absence assertion passes for free when nothing ran at all.
# Caught by the revert probe on 2026-08-12: against the pre-fix tree `psa_scan_file` did not exist,
# the output was a shell "command not found", there was no ❌ in it, and L9b went green. A lane that
# is green because the subject never executed is decorative — the same `not found ≠ 0` shape these
# lanes were written to hold, reproduced inside the lane file. So the absence claim is gated on
# positive evidence that the scan actually produced its allowlist verdict.
case "$out" in
  *"⚪ allowlisted"*)
    case "$out" in
      *"❌"*) bad "L9b allowlisted token must not also report ❌" ;;
      *)      ok  "L9b allowlisted token reports no ❌ (and the ⚪ verdict proves the scan ran)" ;;
    esac ;;
  *) bad "L9b UNMEASURED — no ⚪ verdict in the output, so 'no ❌' proves nothing" ;;
esac

# ── L10 : patterns not loaded is NOT clean ──────────────────────────────────────────────────────
# Reproduced from this repo's own advertised usage line, which omitted psa_load. An empty pattern
# stream matches nothing and reports nothing — identical output to a clean file.
out=$(
  . "$LIB"
  psa_scan_file "$TMP/fixtures/positive.md" 2>&1
); rc=$?
check "L10 psa_scan_file: patterns never loaded → rc=3 NOT SCANNED (not clean)" 3 "$rc" "PATTERNS NOT LOADED" "$out"

# ── L11 : liveness covers the FILE path, not just stdin (missing awk) ────────────────────────────
# The tagging step needs awk; the first liveness draft only exercised the stdin path, so "alive"
# certified a pipeline the file scan does not use.
mkdir -p "$TMP/bin"
for b in cat grep mktemp rm printf sed; do
  src=$(command -v "$b" 2>/dev/null) && ln -sf "$src" "$TMP/bin/$b" 2>/dev/null
done
out=$(/usr/bin/env -i PATH="$TMP/bin" /bin/bash -c "
  . '$LIB'
  PSA_STREAM=\$(printf 'HIGH\tPSA_LANE_SECRET')
  PSA_ALLOWLIST=/dev/null
  psa_require_live
" 2>&1); rc=$?
check "L11 psa_require_live: PATH without awk → DEAD (file path is covered)" 1 "$rc" "INSTRUMENT DEAD" "$out"

# ── L12 : errexit safety — the library must not kill its caller ─────────────────────────────────
# The library's documented contract is that it REPORTS state and never exits. Capturing a nonzero
# status outside an `if` broke that under `set -e`.
out=$(bash -c "
  . '$LIB'; psa_load '$TMP/defaults' '$TMP/override' >/dev/null 2>&1
  set -e
  psa_require_live
  echo SURVIVED
" 2>&1); rc=$?
check "L12 psa_require_live: safe under set -e (caller survives)" 0 "$rc" "SURVIVED" "$out"

# ── L13 : a NON-EMPTY pattern stream is not a COMPLETE one ──────────────────────────────────────
printf 'HIGH\tPSA_ONLY_IN_DEFAULTS\n' > "$TMP/defaults2"
printf 'default-only token PSA_ONLY_IN_DEFAULTS here\n' > "$TMP/fixtures/partial.md"
out=$(
  . "$LIB"; psa_load "$TMP/missing_defaults_file" "$TMP/override" >/dev/null 2>&1
  psa_scan_file "$TMP/fixtures/partial.md" 2>&1
); rc=$?
check "L13 psa_scan_file: defaults failed to load → rc=3 (partial instrument is not clean)" 3 "$rc" "INCOMPLETE PATTERN INSTRUMENT" "$out"

# ── L14 : missing operator override is NOT a clean ───────────────────────────────────────────────
# Flipped in round 4. It used to warn and return 0; the override is where the HIGH company/companion
# literals live, so without it the highest-severity class was never looked at. "Warned but clean" is
# the false-clean shape with a comment attached.
out=$(
  . "$LIB"; psa_load "$TMP/defaults" "$TMP/missing_override_file" >/dev/null 2>&1
  psa_scan_file "$TMP/fixtures/negative.md" 2>&1
); rc=$?
check "L14 psa_scan_file: override absent → rc=3 (HIGH literals unscanned is not clean)" 3 "$rc" "override_absent" "$out"

# ── L15 : a GARBAGE guard value must not walk past the guard ────────────────────────────────────
# Round 3: `[ "$PSA_DEFAULTS_OK" -ne 1 ]` with a non-numeric value returns 2, the `if` reads that as
# false, and the guard falls through — measured rc=0 CLEAN on a file whose token was not even in the
# loaded stream. The shell printed "integer expression expected" and nothing consumed it.
out=$(
  . "$LIB"
  PSA_STREAM=$(printf 'HIGH\tSOMETHING_ELSE'); PSA_DEFAULTS_OK=x; PSA_BAD_ROWS=0; PSA_OVERRIDE_PRESENT=1
  psa_scan_file "$TMP/fixtures/positive.md" 2>&1
); rc=$?
check "L15 psa_scan_file: garbage PSA_DEFAULTS_OK → rc=3 (guard is not walked past)" 3 "$rc" "INCOMPLETE PATTERN INSTRUMENT" "$out"

# ── L16 : an incomplete instrument still REPORTS what it saw ─────────────────────────────────────
# Round 3 caught the round-2 fix suppressing real hits: the guard returned 3 and emitted nothing, so a
# token the loaded patterns DID match was lost. "I cannot certify this" must not become "I saw nothing".
out=$(
  . "$LIB"
  PSA_STREAM=$(printf 'HIGH\tPSA_LANE_SECRET'); PSA_DEFAULTS_OK=0; PSA_BAD_ROWS=0; PSA_OVERRIDE_PRESENT=1
  psa_scan_file "$TMP/fixtures/positive.md" 2>&1
); rc=$?
check "L16 incomplete instrument still reports the hit it saw (verdict 3, evidence kept)" 3 "$rc" "PSA_LANE_SECRET" "$out"

# ── L17 : readonly caller vars → DEAD, not a corrupted abort ─────────────────────────────────────
# Round 4 refuted the round-3 `|| :`: bash aborts on assignment to a readonly variable before `||` is
# considered. The function now refuses BEFORE mutating anything.
# Scope note, stated because the round-3 claim over-reached: under `set -e` a bare call to a function
# that RETURNS nonzero still exits the caller — that is correct shell semantics, not a defect. What is
# fixed is dying mid-mutation with the caller's state half-swapped and no diagnostic. So the lane
# checks the guarded call, which is how a `set -e` caller is supposed to invoke a fallible function.
out=$(bash -c "
  . '$LIB'
  PSA_STREAM=x; readonly PSA_STREAM
  set -e
  if psa_require_live; then echo UNEXPECTED_ALIVE; else echo REFUSED_CLEANLY; fi
  echo SURVIVED
" 2>&1); rc=$?
check "L17 readonly PSA_STREAM → refuses without mutating; guarded set -e caller survives" 0 "$rc" "SURVIVED" "$out"
case "$out" in *"INSTRUMENT DEAD"*) ok "L17b the refusal is diagnosed, not silent" ;; *) bad "L17b refusal produced no INSTRUMENT DEAD line" ;; esac

# ── L18/L19/L21 : the assign guard, in BOTH directions + the ATTRIBUTE case ─────────────────────────────────────────────
# L17's fixture used `PSA_STREAM=x; readonly PSA_STREAM` — the one spelling the round-4 glob happened
# to handle. Round 5 found the other: `readonly PSA_STREAM` with no value prints `declare -r PSA_STREAM`
# (no `=`), the glob missed it, and the caller died with a bare "readonly variable". A control that
# only exercises the passing spelling measures the fixture, not the guard.
out=$(bash -c "
  . '$LIB'
  readonly PSA_STREAM
  set -e
  if psa_require_live >/dev/null 2>&1; then echo ALIVE; else echo REFUSED; fi
  echo SURVIVED
" 2>&1); rc=$?
check "L18 VALUELESS readonly is detected too (guard tests the property, not the declaration)" 0 "$rc" "REFUSED" "$out"
case "$out" in *SURVIVED*) ok "L18b caller survives the valueless case" ;; *) bad "L18b caller died on valueless readonly" ;; esac

# The other direction: the round-4 glob also matched an unrelated readonly variable whose VALUE
# contained the string. Over-blocking here would make every such shell report a healthy scanner dead.
out=$(bash -c "
  . '$LIB'; psa_load '$TMP/defaults' '$TMP/override' >/dev/null 2>&1
  readonly PSA_UNRELATED='PSA_STREAM=junk PSA_ALLOWLIST=junk'
  if psa_require_live >/dev/null 2>&1; then echo ALIVE; else echo REFUSED; fi
" 2>&1); rc=$?
check "L19 unrelated readonly whose VALUE names the vars → no false positive" 0 "$rc" "ALIVE" "$out"

# ── L20 : the readonly helper is not a shell-injection surface ──────────────────────────────────
# Round 6. Reachable only via a non-literal argument, which no current call site passes — but the
# function is in the instrument that decides what may be published, and the guard is one line.
rm -f "$TMP/pwned"
out=$(bash -c ". '$LIB'; _psa_can_assign 'X; touch $TMP/pwned; #' v; echo rc=\$?" 2>&1); rc=$?
if [ -f "$TMP/pwned" ]; then bad "L20 eval injection — the payload executed"
else ok "L20 non-identifier argument is refused before eval (no injection)"; fi
case "$out" in *"refusing non-identifier"*) ok "L20b the refusal is diagnosed" ;; *) bad "L20b refusal was silent" ;; esac

# ── L21 : an ATTRIBUTE that rejects the value, not just readonly ─────────────────────────────────
# Round 7. The R5 probe assigned the variable's OWN CURRENT VALUE while the caller then assigns
# something else. Measured: `declare -i PSA_ALLOWLIST` → self-assignment succeeds, `=/dev/null` fails.
# The probe said writable, the real assignment killed the caller, and on the psa_scan_file path a hit
# psa_scan_tagged WOULD have reported went with it. The probe now takes the value it will assign.
out=$(bash -c "
  . '$LIB'
  declare -i PSA_ALLOWLIST
  set -e
  if psa_require_live >/dev/null 2>&1; then echo ALIVE; else echo REFUSED; fi
  echo SURVIVED
" 2>&1); rc=$?
check "L21 declare -i (attribute rejects the value) → REFUSED, caller survives" 0 "$rc" "REFUSED" "$out"
case "$out" in *SURVIVED*) ok "L21b caller survives the attribute case" ;; *) bad "L21b caller died on the attribute case" ;; esac

# ── Z 레인 : 셸 이식성 (2026-08-21) ──────────────────────────────────────────────────────
# 🟥 왜 [실측]: psa_scan_tagged 가 `local path` 를 선언했는데 **zsh 에서 `path` 는 `PATH` 와
#    tied 된 특수 배열**이라 그 스코프의 PATH 가 비어 `cat` 부터 죽었다. 이 함수 계약이
#    「빈 입력 = return 0」이라 **계기 사망이 «깨끗한 스캔»과 바이트 단위로 같은 출력**이 됐다 —
#    known-positive·known-negative 가 zsh 에서 **둘 다 rc=0**.
# 🟥 이 머신만의 문제가 아니었다: psa_scan_lib.sh 와 public-surface-audit/SKILL_detail.md 가
#    **둘 다 출하되고**(npm pack 산출물로 확인), 그 스킬 본문은 무가드 psa_scan_tagged 직접
#    호출을 지시하며, macOS 기본 셸은 zsh 다. ⇒ 소비자 스킬 경로가 같은 상태였다.
# 🟥 `bash -n`/`zsh -n` 은 못 잡는다 — 문법이 아니라 런타임 의미론이다. 실행으로만 성립한다.
# 🟥 조건부 레인 수를 세어 둔다. 플로어를 상수로 박으면 zsh 없는 러너에서 «INSTRUMENT ERROR»
#    가 난다 — 실제로 CI(ubuntu-latest, zsh 미설치)에서 그렇게 났다. 스킵은 실패가 아니다.
_cond_lanes=0
if command -v zsh >/dev/null 2>&1; then
  _cond_lanes=$((_cond_lanes + 4))
  _ztmp=$(mktemp -d)
  printf 'contains LANECANARY here\n' > "$_ztmp/pos.md"
  printf 'clean prose\n' > "$_ztmp/neg.md"
  _zrun() {
    "$1" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\\tLANECANARY') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1; cat '$2' | psa_scan_tagged '$2' >/dev/null 2>&1; echo \$?"
  }
  _zp=$(_zrun zsh  "$_ztmp/pos.md"); _zn=$(_zrun zsh  "$_ztmp/neg.md")
  _bp=$(_zrun bash "$_ztmp/pos.md"); _bn=$(_zrun bash "$_ztmp/neg.md")
  [ "$_zp" = "1" ] && ok "Z1 zsh known-positive → 1 (계기가 zsh 에서 살아 있다)" || bad "Z1 zsh 양성이 1 이 아니다: got $_zp"
  [ "$_zn" = "0" ] && ok "Z2 zsh known-negative → 0 (오탐 없음)"                  || bad "Z2 zsh 음성이 0 이 아니다: got $_zn"
  # ★컨트롤 — 두 팔이 갈리면 이식성 결함 잔존, 두 팔이 같이 죽으면 Z1/Z2 통과가 공허하다
  [ "$_bp" = "$_zp" ] && ok "Z3 ★컨트롤 bash 양성 = zsh 양성 (두 팔 일치, $_bp)" || bad "Z3 두 팔 불일치: bash=$_bp zsh=$_zp"
  [ "$_bn" = "$_zn" ] && ok "Z4 ★컨트롤 bash 음성 = zsh 음성 ($_bn)"             || bad "Z4 두 팔 불일치: bash=$_bn zsh=$_zn"
  rm -rf "$_ztmp"
else
  echo "  SKIP Z 레인 (zsh 없음) — 🟥 PASS 가 아니라 미검사다"
fi

# ── E 레인 : 계기 사망은 «깨끗함»이 아니라 NOT SCANNED(3) 로 ──────────────────────────────
# 무가드 직접 호출부(pre-commit ×3 · pre-push · outbound-guard)는 전부 **비영 = 차단**으로
# 읽으므로 3 은 셋 모두에서 fail-closed 다. 0 이면 셋 다 «깨끗»으로 통과한다.
# 🟥 **초판 E1 은 두 번 결함이었다** (cross-family + 되돌림 프로브가 각각 하나씩 잡았다):
#   ⓐ 기본 분기가 `ok` 여서 rc=3 이 아닌 «모든» 출력(빈 출력 포함)을 PASS 로 셌다
#   ⓑ 판정을 **종료코드가 아니라 문자열 `*rc=3*`** 로 했는데, 가드가 stdout 에 찍는 문구
#      자체에 `(rc=3)` 이 들어 있다 → **페이로드가 자기 판정 문자열을 인쇄**한다. 가드의
#      `return 3` 을 `return 0` 으로 사보타주해도 레인이 초록이었다. 앵커가 장식이었다.
#   ⇒ 판정은 **숫자 rc 하나**로만. 메시지는 증거지 판정이 아니다.
_erc=$(bash -c "
  . '$LIB'
  psa_load '$PWD/.claude/rules/.public-surface-patterns.defaults' '$PWD/.claude/rules/.public-surface-patterns' >/dev/null 2>&1
  PATH=/nonexistent-psa-probe
  printf 'p\tLANECANARY\n' | psa_scan_tagged >/dev/null 2>&1
  echo \$?
" 2>/dev/null | tail -1)
[ "$_erc" = "3" ] && ok "E1 계기 사망 → rc=3 NOT SCANNED (숫자로 판정, 0 으로 안 접힌다)" \
                  || bad "E1 계기 사망이 rc=3 이 아니다 — got rc=[$_erc]"

# ── E2~E4 : cross-family(codex/gpt-5.6-sol) 가 실행으로 재현한 반례들. 판정 FAIL 이었다.
#    전부 «자가검사가 한 번 통과했다 → 그 뒤 실제 스캔도 실행됐다» 로 확장한 초판의 맹점이다.
_erun() { # $1=shell $2=prelude → rc
  "$1" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\\tLANECANARY') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1; $2 printf 'p\tLANECANARY\n' | psa_scan_tagged >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1
}
for _sh in bash zsh; do
  command -v "$_sh" >/dev/null 2>&1 || { echo "  SKIP E2~E5 ($_sh 없음) — PASS 아님, 미검사다"; continue; }
  [ "$_sh" = "zsh" ] && _cond_lanes=$((_cond_lanes + 4))
  # E2 — `cat` 이 죽으면 빈 입력이 «신고할 것 없음»이 됐다 (반례 1)
  _r=$(_erun "$_sh" 'cat(){ return 7; };')
  [ "$_r" = "3" ] && ok "E2/$_sh cat 사망 → rc=3 (빈 입력이 «깨끗»으로 안 접힌다)" || bad "E2/$_sh cat 사망 rc=[$_r], 3 이어야"
  # E3 — 🟥 외부가 가드 표식을 미리 export 하면 자가검사가 통째로 생략됐다 (반례 1b)
  #      수리: 재진입 판별을 **호출 스택**으로 바꿨다 — 호출자가 미리 심을 수 없다
  _r=$(_erun "$_sh" 'export _PSA_IN_SELFTEST=1; export _PSA_LIVE_OK=1; grep(){ return 127; };')
  [ "$_r" = "3" ] && ok "E3/$_sh 가드 표식 선설정 → 여전히 rc=3 (전역 상태가 권한이 아니다)" || bad "E3/$_sh 선설정으로 우회됨 rc=[$_r]"
  # E4 — 자가검사는 PSA_STREAM 을 카나리아로 바꿔치기하므로 «진짜 패턴이 비었는지»를 못 본다 (반례 3)
  _r=$(_erun "$_sh" "PSA_STREAM='';")
  [ "$_r" = "3" ] && ok "E4/$_sh 빈 PSA_STREAM → rc=3 (자가검사 통과해도 실제 패턴을 본다)" || bad "E4/$_sh 빈 STREAM rc=[$_r], 3 이어야"
  # ★컨트롤 — 위 셋의 통과가 «전부 3 을 내서» 인지 확인. 정상 입력은 1/0 이어야 한다
  _r=$(_erun "$_sh" '')
  [ "$_r" = "1" ] && ok "E5/$_sh ★컨트롤 정상 양성 → rc=1 (E2~E4 가 «항상 3» 이 아니다)" || bad "E5/$_sh 컨트롤 rc=[$_r], 1 이어야"
done

# ── G/F 레인 : cross-family 반례 2·4 (2026-08-21, 2차) ──────────────────────────────────
# 🟥 둘 다 «자가검사가 통과했으니 그 뒤 스캔도 실행됐다» 는 확장의 잔재다.
#   G = 진짜 패턴이 깨졌을 때. 자가검사는 **자기 카나리아 패턴**을 쓰므로 구조적으로 못 본다.
#       실측 도달: 패턴 파일에 깨진 정규식 한 줄 → 그 행만 조용히 아무것도 안 잡고 rc=0 «깨끗».
#   F = 자가검사 판정 자체의 위조. 초판은 파이프 최종 rc 하나만 봐서 «생산자 실패의 1» 과
#       «스캐너가 유출을 찾음의 1» 이 합쳐졌다 — 실패하는 awk 가 카나리아를 뱉으면 통과했다.
for _sh in bash zsh; do
  command -v "$_sh" >/dev/null 2>&1 || { echo "  SKIP G/F ($_sh 없음) — PASS 아님, 미검사다"; continue; }
  _cond_lanes=$((_cond_lanes + 0))
  _gp() { "$1" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\\t%s') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1; printf 'p\\t%s\\n' | psa_scan_tagged >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1; }
  _r=$("$_sh" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\t[unclosed') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1; printf 'p\t[unclosed here\n' | psa_scan_tagged >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" = "3" ] && ok "G1/$_sh 깨진 정규식 → rc=3 (조용한 미스캔이 «깨끗»으로 안 접힌다)" || bad "G1/$_sh 깨진 정규식 rc=[$_r], 3 이어야"
  # ★컨트롤 — 정상 패턴은 여전히 1/0 을 낸다(G1 이 «항상 3» 이 아니다)
  _r=$("$_sh" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\tOKTOK') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1; printf 'p\tOKTOK\n' | psa_scan_tagged >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" = "1" ] && ok "G2/$_sh ★컨트롤 정상 패턴 → rc=1" || bad "G2/$_sh 컨트롤 rc=[$_r], 1 이어야"
  # F — 실패하는 생산자가 카나리아를 뱉어도 «살아있음» 이 아니어야
  _r=$("$_sh" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\tX') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1; awk(){ printf 'PSA_SELFTEST_CANARY\n'; return 1; }; psa_require_live >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" != "0" ] && ok "F1/$_sh 실패한 생산자의 카나리아 → 자가검사 «살아있음» 아님(rc=$_r)" || bad "F1/$_sh 자가검사 판정이 위조됐다 rc=0"
  # ★컨트롤 — 정상 환경에서 psa_require_live 는 살아있다고 해야 한다
  _r=$("$_sh" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\tX') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1; psa_require_live >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" = "0" ] && ok "F2/$_sh ★컨트롤 정상 자가검사 → rc=0 (F1 이 «항상 실패» 가 아니다)" || bad "F2/$_sh 컨트롤 rc=[$_r], 0 이어야"
  _cond_lanes=$((_cond_lanes + 0))
  [ "$_sh" = "zsh" ] && _cond_lanes=$((_cond_lanes + 4))
done

# ── H 레인 : 훅이 «계기 사망(3)» 과 «유출(1)» 을 가르는가 (2026-08-21) ────────────────────
# 🟥 왜 [실행 확인]: 초판 훅은 `if ! … | psa_scan_tagged` 로 **비영을 전부 유출로 뭉갰다.**
#    그래서 `PUBLIC_SURFACE_OK=1` 이 **계기 사망까지 «승인된 유출»로 통과**시켰다 — 비가역
#    표면에서 가장 나쁜 조합이다. override 는 «알고 있는 언급»을 승인하는 것이지 «안 잰
#    표면»을 승인하는 게 아니다. 되돌림 실측: 옛 훅 rc=0 · 새 훅 rc=1.
_HOOK="$PWD/templates/.git-hooks/pre-commit"
if [ ! -f "$_HOOK" ] || ! command -v git >/dev/null 2>&1; then
  echo "  SKIP H 레인 (훅 또는 git 없음) — PASS 아님, 미검사"
else
  _hrun() { # $1=hook path → rc  (계기를 죽인 픽스처에서 PUBLIC_SURFACE_OK=1 로 커밋 시도)
    local T; T=$(mktemp -d); git init -q "$T"
    ( cd "$T"
      git config user.email t@t; git config user.name t; git config commit.gpgsign false
      mkdir -p .githooks .claude/rules tracks/_meta scripts
      cp "$1" .githooks/pre-commit; chmod +x .githooks/pre-commit
      git config core.hooksPath .githooks
      cp "$OLDPWD/.claude/rules/.public-surface-patterns.defaults" .claude/rules/ 2>/dev/null
      cp "$OLDPWD/.claude/rules/.public-surface-patterns" .claude/rules/ 2>/dev/null
      cp "$OLDPWD/scripts/psa_scan_lib.sh" scripts/
      # 계기를 죽인다 — 원인은 무엇이든 좋다. 중요한 건 «안 쟀다» 가 «깨끗» 으로 안 읽히는 것
      sed -i.bak 's/^psa_require_live() {/psa_require_live() { return 1/' scripts/psa_scan_lib.sh && rm -f scripts/psa_scan_lib.sh.bak
      printf 'x\n' > seed.md; git add seed.md; git commit -qm seed --no-verify >/dev/null 2>&1
      printf 'just prose\n' > probe.md; git add probe.md
      PUBLIC_SURFACE_OK=1 git commit -qm probe >/dev/null 2>&1; echo $? )
    rm -rf "$T"
  }
  _h=$(_hrun "$_HOOK")
  [ "$_h" = "1" ] && ok "H1 계기 사망 + PUBLIC_SURFACE_OK=1 → **차단**(override 가 미측정을 안 덮는다)" \
                  || bad "H1 계기 사망이 override 로 통과했다 rc=[$_h] — 이 수리가 되돌아갔다"
  # ★컨트롤 — 계기가 살아 있으면 같은 픽스처가 통과해야 한다. 아니면 H1 은 «항상 막힌다» 일 뿐이다
  _hrun_live() {
    local T; T=$(mktemp -d); git init -q "$T"
    ( cd "$T"
      git config user.email t@t; git config user.name t; git config commit.gpgsign false
      mkdir -p .githooks .claude/rules tracks/_meta scripts
      cp "$_HOOK" .githooks/pre-commit; chmod +x .githooks/pre-commit
      git config core.hooksPath .githooks
      cp "$OLDPWD/.claude/rules/.public-surface-patterns.defaults" .claude/rules/ 2>/dev/null
      cp "$OLDPWD/.claude/rules/.public-surface-patterns" .claude/rules/ 2>/dev/null
      cp "$OLDPWD/scripts/psa_scan_lib.sh" scripts/
      printf 'x\n' > seed.md; git add seed.md; git commit -qm seed --no-verify >/dev/null 2>&1
      printf 'just prose\n' > probe.md; git add probe.md
      git commit -qm probe >/dev/null 2>&1; echo $? )
    rm -rf "$T"
  }
  _hl=$(_hrun_live)
  [ "$_hl" = "0" ] && ok "H2 ★컨트롤 계기 생존 + 깨끗한 내용 → 통과 (H1 이 «항상 막힘» 이 아니다)" \
                   || bad "H2 컨트롤 실패 rc=[$_hl] — 픽스처가 다른 이유로 막힌다, H1 판정 무효"
fi

# ── N 레인 : cross-family 3라운드 반례 P1~P5 (2026-08-21) ────────────────────────────────
# 🟥 세 라운드가 같은 얼굴이었다 — **상태를 의미로 확장**. rc=0 을 «유효», «분리했다» 를
#    «생산이 옳다», «자가검사 통과» 를 «그 뒤 스캔도 실행» 으로 읽었다. N 레인은 그 축을 친다.
for _sh in bash zsh; do
  command -v "$_sh" >/dev/null 2>&1 || { echo "  SKIP N1/N2/N4/N5 ($_sh 없음) — PASS 아님, 미검사다"; continue; }
  # N1 — P1: 입력을 읽지도 않고 rc=0 으로 «고정» 카나리아를 뱉는 위조 생산자
  _r=$("$_sh" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\tX') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1;
       awk(){ printf 'psa/selftest\tPSA_SELFTEST_CANARY\n'; return 0; };
       psa_require_live >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" != "0" ] && ok "N1/$_sh rc=0 위조 생산자 → «살아있음» 아님 (nonce 불일치, rc=$_r)" \
                   || bad "N1/$_sh 자가검사가 rc=0 위조에 뚫렸다 — P1 이 안 닫혔다"
  # N1b — P1 의 **문자열 대조** 를 따로 친다. N1(고정 카나리아)은 nonce 만으로도 막히므로
  #       대조문이 없어도 초록이었다(되돌림 실측 → 적색 0). 이 레인은 «입력은 읽었는데
  #       태그가 틀린» 생산자를 쓴다 — nonce 는 통과하고 대조문만이 잡는다.
  _r=$("$_sh" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\tX') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1;
       awk(){ for _a; do :; done; printf 'WRONGPREFIX\t%s\n' \"\$(cat \"\$_a\")\"; return 0; };
       psa_require_live >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" != "0" ] && ok "N1b/$_sh 입력은 읽되 태그가 틀린 생산자 → «살아있음» 아님 (rc=$_r)" \
                   || bad "N1b/$_sh 태그 대조가 없다 — 생산자가 무엇을 뱉든 통과한다"
  # N2 ★컨트롤 — 정상 환경에서는 여전히 살아있다고 해야 한다 (N1 이 «항상 실패» 가 아니다)
  _r=$("$_sh" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\tX') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1;
       psa_require_live >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" = "0" ] && ok "N2/$_sh ★컨트롤 정상 자가검사 → rc=0" || bad "N2/$_sh 컨트롤 rc=[$_r], 0 이어야"
  # N4 — P4: 판별력 없는 패턴(빈·^·a*)은 거부되고 정상 패턴만 남는다
  _T=$(mktemp -d); printf 'HIGH\t\nHIGH\t^\nHIGH\ta*\nHIGH\tREALSECRET\n' > "$_T/def"; : > "$_T/ovr"
  _r=$("$_sh" -c ". '$LIB'; export PSA_DEFAULTS_OK=1; psa_load '$_T/def' '$_T/ovr' >/dev/null 2>&1;
       printf '%s/%s\n' \"\$(printf '%s' \"\$PSA_STREAM\" | grep -c .)\" \"\$PSA_BAD_ROWS\"" 2>/dev/null | tail -1)
  [ "$_r" = "1/3" ] && ok "N4a/$_sh 무판별 패턴 3행 거부, 정상 1행 생존 ($_r)" \
                    || bad "N4a/$_sh 유효행/거부행=[$_r], 1/3 이어야 — P4 가 안 닫혔다"
  # N4b ★컨트롤 — 거부가 «전부 버리기» 가 아니다: **깨끗한** 패턴 파일이면 정상 검출한다.
  #    🟥 초판은 위 «혼합» 파일로 rc=1 을 기대했는데, R4-6 이후 그 파일은 bad_rows>0 이라
  #    rc=3(부분집합=미측정)이 정답이다. 컨트롤은 깨끗한 파일로 분리한다.
  printf 'HIGH\tREALSECRET\n' > "$_T/clean"
  _r=$("$_sh" -c ". '$LIB'; export PSA_DEFAULTS_OK=1; PSA_ALLOWLIST=/dev/null; psa_load '$_T/clean' '$_T/ovr' >/dev/null 2>&1;
       printf 'p\tREALSECRET here\n' | psa_scan_tagged >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" = "1" ] && ok "N4b/$_sh ★컨트롤 깨끗한 패턴 파일 → 정상 검출 rc=1" \
                  || bad "N4b/$_sh 컨트롤 rc=[$_r], 1 이어야 — 거부가 과했다"
  # N4c — R4-6: **부분 로드된 집합은 «깨끗»도 «유출»도 말할 수 없다.** cross-family 4라운드가
  #    `SECRET|^$` 한 행이 떨어진 집합에서 `SECRET` 입력이 rc=0 «깨끗» 을 내는 것을 실측했다.
  _r=$("$_sh" -c ". '$LIB'; export PSA_DEFAULTS_OK=1; PSA_ALLOWLIST=/dev/null; psa_load '$_T/def' '$_T/ovr' >/dev/null 2>&1;
       printf 'p\tREALSECRET here\n' | psa_scan_tagged >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" = "3" ] && ok "N4c/$_sh 행이 떨어진 부분집합 → rc=3 (부분 로드는 미측정)" \
                  || bad "N4c/$_sh 부분집합 rc=[$_r], 3 이어야 — R4-6 이 안 닫혔다"
  rm -rf "$_T"
  # N5 — P5: 백슬래시가 든 경로가 증거에 그대로 남는다 (zsh 의 echo 가 해석하던 자리)
  _r=$("$_sh" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\tSEEKRET') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1;
       printf 'dir\\\\two\tSEEKRET\n' | psa_scan_tagged 2>&1 | grep -c 'dir\\\\two'" 2>/dev/null | tail -1)
  [ "$_r" = "1" ] && ok "N5/$_sh 백슬래시 경로가 증거에 보존된다" \
                  || bad "N5/$_sh 증거 손상 (일치=[$_r]) — P5 가 안 닫혔다"
  [ "$_sh" = "zsh" ] && _cond_lanes=$((_cond_lanes + 7))
done

# R 레인 : cross-family 4라운드 반례 (2026-08-21, 수리에 대한 재검)
# 🟥 이 라운드의 교훈은 **「수리가 새 결함의 주된 출처」**다 — P3 를 스캔 경로에서만 고치고
#    로더 경로로 전파를 안 봤고(R4-1), 「정확한 문자열 대조」가 후행 개행에 뚫렸다(R4-3).
for _sh in bash zsh; do
  command -v "$_sh" >/dev/null 2>&1 || { echo "  SKIP R1/R2/R3 ($_sh 없음) — PASS 아님, 미검사다"; continue; }
  _RT=$(mktemp -d); printf 'HIGH\tREALSECRET\n' > "$_RT/def"; : > "$_RT/ovr"
  # R1 — psa_load 가 `set -e` 호출자를 죽이지 않는다 (정상 패턴은 빈 입력에 rc=1 을 낸다)
  _r=$("$_sh" -c "set -e; . '$LIB'; psa_load '$_RT/def' '$_RT/ovr' >/dev/null 2>&1; echo SURVIVED" 2>/dev/null | tail -1)
  [ "$_r" = "SURVIVED" ] && ok "R1/$_sh set -e 호출자가 psa_load 를 살아서 통과" \
                        || bad "R1/$_sh psa_load 가 errexit 호출자를 죽인다 [$_r] — P3 전파 미완"
  # R2 — fallback nonce 가 생산자 인자에서 유도되지 않는다
  _r=$("$_sh" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\tX') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1;
       head(){ return 1; };
       awk(){ for _a; do :; done; _d=\${_a%/*}; _d=\${_d##*/}; _d=\$(printf %s \"\$_d\" | tr -cd 'A-Za-z0-9');
              printf 'psa/selftest\tPSA_SELFTEST_CANARY_%s\n' \"\$_d\"; return 0; };
       psa_require_live >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" != "0" ] && ok "R2/$_sh urandom 부재 fallback 이 경로에서 유도 안 됨 (rc=$_r)" \
                   || bad "R2/$_sh fallback nonce 가 인자에서 유도된다 — 위조 통과"
  # R3 — 정답 줄 + 후행 빈 줄은 «바이트 동일» 이 아니다 ($(...) 가 후행 개행을 지운다)
  _r=$("$_sh" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\tX') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1;
       awk(){ for _a; do :; done; printf 'psa/selftest\t%s\n\n\n' \"\$(cat \"\$_a\")\"; return 0; };
       psa_require_live >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" != "0" ] && ok "R3/$_sh 후행 빈 줄이 붙은 산출 → 통과 안 됨 (rc=$_r)" \
                   || bad "R3/$_sh 후행 개행이 대조를 뚫었다 — 「바이트 동일」이 아니다"
  rm -rf "$_RT"
  [ "$_sh" = "zsh" ] && _cond_lanes=$((_cond_lanes + 3))
done

# S 레인 : cross-family 5라운드 반례 (2026-08-21). 🟥 **4라운드 수리 자체가 낸 결함들**이다.
for _sh in bash zsh; do
  command -v "$_sh" >/dev/null 2>&1 || { echo "  SKIP S1/S2 ($_sh 없음) — PASS 아님, 미검사다"; continue; }
  # S1 — 엔트로피 출처가 둘 다 없으면 «약한 nonce» 가 아니라 **미측정**이다.
  #      4라운드 fallback(`$RANDOM$RANDOM$$$SECONDS`)은 생산자가 같은 셸에서 재계산해 통과했다.
  _r=$("$_sh" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\tX') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1;
       head(){ return 1; }; openssl(){ return 1; };
       awk(){ for _a; do :; done; _n=\$(printf '%s%s%s%s' \"\${RANDOM:-}\" \"\${RANDOM:-}\" \"\$\$\" \"\${SECONDS:-}\" | tr -cd 'A-Za-z0-9');
              printf 'psa/selftest\tPSA_SELFTEST_CANARY_%s\n' \"\$_n\"; return 0; };
       psa_require_live >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" != "0" ] && ok "S1/$_sh 엔트로피 부재 → 예측가능 nonce 로 통과 안 됨 (rc=$_r)" \
                   || bad "S1/$_sh 생산자가 재계산한 nonce 로 통과했다 — 추측 가능한 nonce 는 nonce 가 아니다"
  # S2 — 생산자는 `$tmpd/canary` 를 인자로 받으므로 `$tmpd` 를 안다. 기대값이 그 안에 있으면 덮인다.
  _r=$("$_sh" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\tX') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1;
       awk(){ for _a; do :; done; _d=\${_a%/*}; _n=\$(cat \"\$_a\");
              printf 'wrong/path\t%s\n' \"\$_n\" > \"\$_d/expect\";
              printf 'wrong/path\t%s\n' \"\$_n\"; return 0; };
       psa_require_live >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" != "0" ] && ok "S2/$_sh 생산자가 기대값 파일을 덮어써도 통과 안 됨 (rc=$_r)" \
                   || bad "S2/$_sh 기대값이 생산자 사정권에 있다 — cmp 가 자기 자신과 비교했다"
  # T1 — R6-1: `cmp` 가 함수로 가려져도 대조가 무력화되지 않는다 (`command cmp`)
  _r=$("$_sh" -c ". '$LIB'; export PSA_STREAM=\$(printf 'HIGH\tX') PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1 PSA_BAD_ROWS=0;
       cmp(){ return 0; };
       awk(){ for _a; do :; done; printf 'WRONGPREFIX\t%s\n' \"\$(cat \"\$_a\")\"; return 0; };
       psa_require_live >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" != "0" ] && ok "T1/$_sh cmp 함수 가림 → 통과 안 됨 (rc=$_r)" \
                   || bad "T1/$_sh 대조가 셸 함수로 무력화됐다 — command 우회가 없다"
  # T2 — R6-2: 생산자가 stdout 은 틀리게 쓰고 tagged 를 정답 파일 심링크로 바꿔치기
  _r=$("$_sh" -c ". '$LIB'; PSA_STREAM=\$(printf 'HIGH\tX'); export PSA_STREAM PSA_ALLOWLIST=/dev/null PSA_DEFAULTS_OK=1 PSA_BAD_ROWS=0;
       awk(){ for _a; do :; done; _d=\${_a%/*}; _n=\$(cat \"\$_a\");
              printf 'WRONGPREFIX\t%s\n' \"\$_n\";
              printf 'psa/selftest\t%s\n' \"\$_n\" > \"\$_d/alt\"; ln -sf alt \"\$_d/tagged\"; return 0; };
       psa_require_live >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" != "0" ] && ok "T2/$_sh tagged 심링크 스왑 → 통과 안 됨 (rc=$_r)" \
                   || bad "T2/$_sh 비교 대상이 생산자가 실제로 쓴 파일이 아니다"
  [ "$_sh" = "zsh" ] && _cond_lanes=$((_cond_lanes + 4))
done
# S3 — dash 는 `$'"'"'\t'"'"'` 를 리터럴로 읽어 정상 행이 통째로 떨어졌다(bad=1 stream=[]).
#      그건 «패턴이 없다» 가 아니라 **미측정**이므로 로드 자체를 거부한다.
if command -v dash >/dev/null 2>&1; then
  _ST=$(mktemp -d); printf 'HIGH\tREALSECRET\n' > "$_ST/def"; : > "$_ST/ovr"
  _r=$(dash -c ". '$LIB'; psa_load '$_ST/def' '$_ST/ovr' >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" = "3" ] && ok "S3 dash → psa_load rc=3 (조용한 빈 스트림이 아니라 명시적 미측정)" \
                  || bad "S3 dash psa_load rc=[$_r], 3 이어야 — 무능한 셸이 «패턴 없음» 으로 접힌다"
  # S3b ★컨트롤 — 같은 파일로 bash 는 정상 로드 (S3 가 «항상 거부» 가 아니다)
  _r=$(bash -c ". '$LIB'; psa_load '$_ST/def' '$_ST/ovr' >/dev/null 2>&1; echo \$?" 2>/dev/null | tail -1)
  [ "$_r" = "0" ] && ok "S3b ★컨트롤 bash 는 같은 파일을 정상 로드 → rc=0" \
                  || bad "S3b 컨트롤 rc=[$_r], 0 이어야 — 셸 검사가 과차단이다"
  rm -rf "$_ST"
  _cond_lanes=$((_cond_lanes + 2))
else
  echo "  SKIP S3/S3b (dash 없음) — PASS 아님, 미검사다"
fi

# N3 — 🟥 **교차조건 레인**: `set -e` × 실패 생산자. codex 가 「세 라운드가 공유한 갭」으로 지목한 것.
#      한 조건씩 보면 둘 다 통과하는데, 겹치면 복원문에 **도달하지 못하고** PSA_STREAM 이
#      카나리아인 채로 남는다. EXIT trap 으로 «중단돼도» 상태를 회수한다 —
#      ⚠️ `|| true` 를 붙이면 errexit 가 꺼져서 계기 자체가 죽는다(첫 판이 그랬다).
#      bash 전용: zsh 는 `-c` + errexit 중단에서 EXIT trap 이 발화하지 않아 회수 채널이 없다(미검사).
_N3=$(mktemp -d)
bash -c "set -e; . '$LIB'; PSA_STREAM=ORIGINAL; PSA_ALLOWLIST=/dev/null; PSA_DEFAULTS_OK=1;
  trap 'printf \"%s\" \"\$PSA_STREAM\" > '$_N3'/v' EXIT
  awk(){ return 1; }
  psa_require_live >/dev/null 2>&1" >/dev/null 2>&1
_r=$(cat "$_N3/v" 2>/dev/null); rm -rf "$_N3"
[ "$_r" = "ORIGINAL" ] && ok "N3 ★교차조건 set -e × 실패 생산자 → PSA_STREAM 복원됨" \
                       || bad "N3 교차조건에서 복원 미도달 — PSA_STREAM=[$_r] (카나리아 잔류 = P3 미해결)"

# N6 — P2: outbound guard 의 override 가 «미측정» 까지 통과시키면 안 된다.
#      🟥 첫 판 픽스처는 `FH=` 로 뿌리를 바꾸려 했는데 그 변수는 스크립트가 자기 것으로 계산한다
#         → 가드가 **실제 레포를 스캔하고 깨끗하다고 통과했다**. 죽은 픽스처였다.
#         가드가 이미 제공하는 주입점(PSA_LIB_FILE / PSA_DEFAULTS_FILE / PSA_OVERRIDE_FILE)을 쓴다.
# 🟥 이 블록은 **조건부**다 — `outbound_query_guard.sh` 는 npm `files[]` 에 없어서
#    **소비자 설치본에는 존재하지 않는다.** 초판은 조건부인데 `_cond_lanes` 에 안 세서,
#    포장본에서 `pass=80 < floor 84` 로 **거짓 INSTRUMENT ERROR** 를 냈다(실측 rc=3).
#    정적으로는 안 보였고 **포장본에서 실행하자마자** 나왔다 — standpoint 실행 팔이 잡은 것.
_GUARD="$REPO_ROOT/scripts/outbound_query_guard.sh"
if [ -f "$_GUARD" ]; then
  _cond_lanes=$((_cond_lanes + 4))
  _S6=$(mktemp -d)
  # 스텁 라이브러리: 앞단 게이트는 전부 통과시키고 **스캔만 rc=3(미측정)** 을 내게 한다.
  # 이래야 P2 가 고친 «그 분기»(RC 판정 직후의 override)에 실제로 도달한다.
  cat > "$_S6/lib_unmeasured.sh" <<'STUB'
psa_load() { PSA_DEFAULTS_OK=1; PSA_BAD_ROWS=0; PSA_OVERRIDE_PRESENT=1; return 0; }
psa_require_live() { return 0; }
psa_scan_tagged() { return 3; }
STUB
  # 대조 스텁: 같은 모양인데 스캔이 rc=1(유출을 «봤다») 을 낸다
  sed 's/return 3/return 1/' "$_S6/lib_unmeasured.sh" > "$_S6/lib_leak.sh"
  _n6() { OUTBOUND_QUERY_OK=1 PSA_LIB_FILE="$1" bash "$_GUARD" "some outbound question" >/dev/null 2>&1; echo $?; }
  _r=$(_n6 "$_S6/lib_unmeasured.sh")
  [ "$_r" = "3" ] && ok "N6a override + 스캔 미측정(rc=3) → 여전히 차단 (rc=3)" \
                  || bad "N6a OUTBOUND_QUERY_OK=1 이 미측정을 승인했다 rc=[$_r] — P2 가 안 닫혔다"
  # N6b ★컨트롤 — 같은 override 가 «본» 히트(rc=1)에서는 여전히 통과해야 한다
  #      (N6a 가 «override 를 통째로 죽였다» 가 아님을 보인다)
  _r=$(_n6 "$_S6/lib_leak.sh")
  [ "$_r" = "0" ] && ok "N6b ★컨트롤 override + 히트(rc=1) → 통과 (override 가 죽지 않았다)" \
                  || bad "N6b 컨트롤 rc=[$_r], 0 이어야 — 과차단이다"
  # R5 — rc=2 는 «유출 발견» 이 아니라 **미측정** 이다. 초판은 exit 1 로 오분류했다.
  printf '%s\n' 'psa_load(){ PSA_DEFAULTS_OK=1; PSA_BAD_ROWS=0; PSA_OVERRIDE_PRESENT=1; return 0; }' \
                 'psa_require_live(){ return 0; }' 'psa_scan_tagged(){ return 2; }' > "$_S6/lib_rc2.sh"
  _r=$(_n6 "$_S6/lib_rc2.sh")
  [ "$_r" = "3" ] && ok "R5 스캐너 rc=2 → 미측정(3) 으로 분류 (유출 1 로 접히지 않는다)" \
                  || bad "R5 rc=2 가 [$_r] 로 분류됐다, 3 이어야"
  # N6c ★컨트롤 — override 없이 미측정이면 당연히 차단 (N6a 가 override 덕이 아님을 가른다)
  _r=$(PSA_LIB_FILE="$_S6/lib_unmeasured.sh" bash "$_GUARD" "some outbound question" >/dev/null 2>&1; echo $?)
  [ "$_r" = "3" ] && ok "N6c ★컨트롤 override 없는 미측정 → 차단 (rc=3)" \
                  || bad "N6c 컨트롤 rc=[$_r], 3 이어야"
  rm -rf "$_S6"
else
  echo "  SKIP N6a/N6b/N6c/R5 (outbound_query_guard.sh 부재 — 배포 산출물) — PASS 아님, 미검사다"
fi

echo "[psa single-file lanes] pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
# 🟥 플로어는 **조건부 레인을 반영한 값**이다. 33 = zsh 없는 러너의 기저(Z1~Z4 · E2~E5/zsh 스킵).
#    zsh 가 있으면 +8. 상수 하나로 박으면 «스킵 = 계기 오류» 가 되어 러너를 거짓 적색으로 만든다.
#    ⚠️ 그리고 이 수식이 말하는 진짜 사실을 잊지 마라: **zsh 축은 zsh 가 있는 곳에서만 검증된다.**
#    CI 에 zsh 를 설치한 이유가 그것이고(.github/workflows/validate.yml), 그게 없으면 이 PR 이
#    고친 결함의 축이 CI 에서 **한 번도** 안 돌아간다.
_floor=$((52 + _cond_lanes))
[ "$pass" -ge "$_floor" ] || { echo "  ❌ INSTRUMENT ERROR — only $pass lanes ran; expected >=$_floor (zsh 조건부 +$_cond_lanes)"; exit 3; }
exit 0
