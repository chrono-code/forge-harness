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

echo "[psa single-file lanes] pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
# 🟥 플로어는 **조건부 레인을 반영한 값**이다. 33 = zsh 없는 러너의 기저(Z1~Z4 · E2~E5/zsh 스킵).
#    zsh 가 있으면 +8. 상수 하나로 박으면 «스킵 = 계기 오류» 가 되어 러너를 거짓 적색으로 만든다.
#    ⚠️ 그리고 이 수식이 말하는 진짜 사실을 잊지 마라: **zsh 축은 zsh 가 있는 곳에서만 검증된다.**
#    CI 에 zsh 를 설치한 이유가 그것이고(.github/workflows/validate.yml), 그게 없으면 이 PR 이
#    고친 결함의 축이 CI 에서 **한 번도** 안 돌아간다.
_floor=$((37 + _cond_lanes))
[ "$pass" -ge "$_floor" ] || { echo "  ❌ INSTRUMENT ERROR — only $pass lanes ran; expected >=$_floor (zsh 조건부 +$_cond_lanes)"; exit 3; }
exit 0
