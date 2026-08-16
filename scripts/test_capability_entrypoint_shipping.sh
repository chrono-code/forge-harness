#!/usr/bin/env bash
# test_capability_entrypoint_shipping.sh — every typed CAPABILITY ENTRY POINT must be in the
# npm published file set.
#
# WHY THIS EXISTS (measured 2026-08-12, cross-family gpt-5.5 + governor widening)
# `scripts/degrade_probe_capability.sh` AND `scripts/psa_probe_capability.sh` were both absent from
# `package.json` `files[]`, while their VALIDATOR (`capability_registry_check.sh`) shipped. An npm
# consumer therefore received the thing that checks capabilities and none of the capabilities — the
# release's headline feature (scanning ```bash/```python fences) was unreachable on the typed path
# it advertises.
#
# WHY `package_coverage_check.sh` DID NOT CATCH IT — and why this is a separate check rather than a
# rule added there: that checker walks *references* (a shipped doc names a path → the path must
# ship). These two files are referenced by NOTHING but their own header. A reference-follower is
# structurally blind to an ORPHAN; you cannot fix that by adding another pattern to it. The
# discriminator here is not "is it referenced" but "is it an entry point", which is knowable from
# the filename convention alone.
#
# CLASS: third occurrence of "a shipped surface points outside files[]" in this release cycle
#   1. SKILL.md pointed at a runner that was not shipped        (caught by CI only)
#   2. AGENTS.md pointed at validate_yaml.sh, not shipped       (caught by CI only)
#   3. the capability entry points themselves, not shipped      (caught by cross-family only)
# The standing rule is N>=3 → mechanize at the front instead of relying on the next reviewer.
#
# Usage:  bash scripts/test_capability_entrypoint_shipping.sh
# Exit:   0 = every entry point ships; 1 = at least one is missing (or the check could not run).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }

pass=0; fail=0
ok()  { printf '  \342\234\205 %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \342\235\214 %s\n' "$1"; fail=$((fail+1)); }

echo "capability entry-point shipping check"

command -v node >/dev/null 2>&1 || {
  echo "  INSTRUMENT ERROR: node unavailable — files[] cannot be read. NOT a pass."; exit 1; }

# Discover entry points by convention. A DISCOVERY of zero is an instrument failure, not a clean
# result: this check exists precisely because the surface it guards is invisible to reference
# walking, so "found nothing to check" must never render as "everything ships".
# 🟥 2026-08-16: 발견 규약이 **한 벌뿐**이었다(`scripts/*_capability.sh`, maxdepth 1). 같은 날
# 도입된 **어댑터 진입점**(`scripts/adapters/*.sh` — 남의 하네스 능력을 FH 안에서 부르는 기본
# 경로)은 이름도 위치도 그 규약 밖이라 **이 검사에 구조적으로 안 보였다.** 즉 어댑터 스크립트가
# `files[]` 에서 빠져도 이 검사는 초록이었다 — 검사기가 지키려던 바로 그 결함이 검사기 자신의
# 사각에서 재현될 수 있었다. 두 규약을 **합집합**으로 본다(빼지 말고 더한다).
ENTRIES=$( { find scripts -maxdepth 1 -type f -name '*_capability.sh' 2>/dev/null
             find scripts/adapters -maxdepth 1 -type f -name '*.sh' 2>/dev/null
           } | LC_ALL=C sort -u )
n=$(printf '%s\n' "$ENTRIES" | grep -c . || true)
n=$(( ${n:-0} + 0 ))
if [ "$n" -eq 0 ]; then
  echo "  INSTRUMENT ERROR: zero *_capability.sh files discovered — the scan did not reach its target."
  echo "  (A real zero is possible only if this repo has no typed capabilities; verify by hand before believing it.)"
  exit 1
fi

FILES_JSON=$(node -e 'process.stdout.write(JSON.stringify(require("./package.json").files||[]))' 2>/dev/null) || {
  echo "  INSTRUMENT ERROR: could not read package.json files[]"; exit 1; }

# ★`mktemp` — 초판은 `${TMPDIR:-/tmp}/cap_entry_$$.txt` 였다. TMPDIR 없는 환경(리눅스 CI·
# 컨테이너가 흔하다)에서 공용 `/tmp` + PID 기반 **예측 가능한 이름**이라, 미리 심어둔 심링크를
# `>` 리다이렉트가 따라가 대상 파일을 덮어쓴다(CWE-377, 보안 패스 [B]). 이 파일은 selfcheck 에
# 배선돼 **소비자 머신에서 `npm test` 로 돈다**.
# ⚠️ `mktemp -t <prefix>` 는 **BSD 전용**이다 — GNU 는 템플릿에 X 를 요구하고
# `mktemp: too few X's in template` 로 죽는다(2026-08-16 CI 실측: 로컬 macOS 초록 · ubuntu 적색).
# 이 레포가 이미 기록한 `stat -f` BSD-first 와 같은 얼굴이다. 양쪽에서 도는 형태는
# **명시 템플릿 + X 다수**뿐이다. (계기가 fail-closed 로 막아 준 덕에 조용히 안 지나갔다.)
_CAP_TMP=$(mktemp "${TMPDIR:-/tmp}/cap_entry.XXXXXXXX") || { echo "  INSTRUMENT ERROR: mktemp 실패"; exit 1; }
trap 'rm -f "$_CAP_TMP"' EXIT INT TERM
printf '%s\n' "$ENTRIES" | while IFS= read -r e; do
  [ -n "$e" ] || continue
  if node -e 'const f=JSON.parse(process.argv[1]);process.exit(f.includes(process.argv[2])?0:1)' "$FILES_JSON" "$e"; then
    echo "  ok $e"
  else
    echo "  MISSING $e"
  fi
done > "$_CAP_TMP"

missing=$(grep -c '^  MISSING ' "$_CAP_TMP" || true)
missing=$(( ${missing:-0} + 0 ))
shipped=$(grep -c '^  ok ' "$_CAP_TMP" || true)
shipped=$(( ${shipped:-0} + 0 ))
cat "$_CAP_TMP"
rm -f "$_CAP_TMP"

if [ "$missing" -eq 0 ]; then
  ok "all $shipped capability entry point(s) are in package.json files[]"
else
  bad "$missing capability entry point(s) absent from files[] — npm consumers get the validator without the capability"
fi

# REVERSE DIRECTION (added 2026-08-12 after a cross-family round broke the first version).
# The check above walks disk → files[]. That direction alone is blind to the failure that actually
# loses a capability: MOVE OR DELETE the entry-point file. Discovery then simply does not see it,
# every remaining entry is still listed, and the lane goes green while `npm pack` ships one fewer
# capability. So also walk files[] → disk: anything declared as a capability entry point must exist.
# (A capability removed from BOTH sides is an intentional deletion and correctly flags nothing.)
DECLARED=$(node -e '
  const f=JSON.parse(process.argv[1]);
  process.stdout.write(f.filter(p=>/^scripts\/.*_capability\.sh$/.test(p)).join("\n"));
' "$FILES_JSON")
dangling=0
if [ -n "$DECLARED" ]; then
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    # `-f` alone is not enough, and both gaps were demonstrated (round 5): a SYMLINK satisfies `-f`
    # but `npm pack` does not follow it — the tarball simply omits the file — and a ZERO-BYTE file
    # satisfies every existence test while shipping an empty capability. Existence is the weakest
    # of the three properties; assert all of them.
    if [ ! -e "$d" ]; then
      echo "  DANGLING $d (declared in files[], absent on disk)"; dangling=$((dangling+1))
    elif [ -L "$d" ]; then
      echo "  SYMLINK $d (npm pack does not follow symlinks — the tarball would omit it)"; dangling=$((dangling+1))
    elif [ ! -f "$d" ]; then
      # A DIRECTORY passes -e, is not a symlink, and `-s` reports non-zero size for it — so the
      # three tests above all agreed a directory was a fine entry point (round 6). Regular-file-ness
      # is the property actually being claimed; assert it rather than three proxies for it.
      echo "  NOT-A-FILE $d (declared as an entry point but is not a regular file)"; dangling=$((dangling+1))
    elif [ ! -s "$d" ]; then
      echo "  EMPTY $d (zero bytes — ships an entry point that cannot run)"; dangling=$((dangling+1))
    fi
  done <<EOF
$DECLARED
EOF
fi
declared_n=$(printf '%s\n' "$DECLARED" | grep -c . || true); declared_n=$(( ${declared_n:-0} + 0 ))
if [ "$declared_n" -eq 0 ]; then
  bad "files[] declares ZERO capability entry points — either the convention changed or the list was gutted; a disk-only check cannot notice that"
elif [ "$dangling" -eq 0 ]; then
  ok "all $declared_n declared capability entry point(s) exist on disk (move/delete would be caught)"
else
  bad "$dangling declared capability entry point(s) missing from disk — npm would ship a broken files[] and the disk-side check alone stays green"
fi

# SIBLING DEPENDENCIES (added 2026-08-16 — occurrence #4 of the class this file's header names).
# The two directions above both key on the ENTRY-POINT convention (`*_capability.sh`). That is
# structurally blind to the failure that actually happened this time: a shipped script called a
# NON-entry-point sibling that did not ship. `capability_registry_check.sh` shipped, its new M6 axis
# ran `${0%/*}/capability_effect_probe.sh`, and that probe was absent from files[] — so on a consumer
# install M6 would hit its fail-closed branch and reject every registration, blaming a "missing probe"
# that exists in the repo.
#
# WHY `package_coverage_check.sh` IS BLIND TO IT — and why the fix belongs here, not there: that
# checker's extraction regex requires a reference to START with a shipped top-level directory
# (`scripts|templates|bin|docs|knowledge|plugins|.claude`). A script naming its own sibling writes
# `${0%/*}/name.sh` or `$(dirname "$0")/name.sh` — the path is BUILT AT RUNTIME and no literal
# `scripts/` appears. The reference-follower cannot see a path that does not textually exist.
#
# Scope kept narrow on purpose: only SELF-DIRECTORY forms. `$REPO_ROOT/scripts/x.sh` already contains
# the literal `scripts/x.sh` and is caught upstream; widening past that would duplicate that checker.
SIB_PAT='(\$\{0%/\*\}|\$\(dirname [^)]*\)|\$\{BASH_SOURCE[^}]*%/\*\})/[A-Za-z0-9_.-]+\.(sh|py|js)'
SHIPPED_SH=$(node -e '
  const f=JSON.parse(process.argv[1]);
  process.stdout.write(f.filter(p=>/^scripts\/.*\.sh$/.test(p)).join("\n"));
' "$FILES_JSON")

sib_refs=0; sib_missing=0
if [ -n "$SHIPPED_SH" ]; then
  while IFS= read -r s; do
    [ -n "$s" ] && [ -f "$s" ] || continue
    # `grep -o` yields the whole matched expression; the sibling NAME is its last path segment.
    # COMMENT LINES ARE STRIPPED FIRST, and that is not cosmetic: the finding's text asserts the
    # callee is "called at runtime". A file whose PROSE names a sibling (this file's own header does)
    # would be reported under a claim that is false about it — the right defect attributed to the
    # wrong caller. Caught during this lane's own known-pair calibration, where the positive arm
    # named two callers and only one of them actually calls anything.
    for ref in $(sed 's/^[[:space:]]*#.*//' "$s" | grep -oE "$SIB_PAT" 2>/dev/null | sed 's|.*/||' | sort -u); do
      sib_refs=$((sib_refs+1))
      # Only assert on siblings that EXIST in the repo. A reference to a name that is absent from
      # disk too is a different defect (a dead call), and it belongs to the dangling check above —
      # claiming it here would report one defect as two.
      [ -f "scripts/$ref" ] || continue
      if node -e 'const f=JSON.parse(process.argv[1]);process.exit(f.includes(process.argv[2])?0:1)' \
           "$FILES_JSON" "scripts/$ref"; then :; else
        echo "  SIBLING-MISSING scripts/$ref (called by $s at runtime, absent from files[])"
        sib_missing=$((sib_missing+1))
      fi
    done
  done <<EOF
$SHIPPED_SH
EOF
fi

# Discovery-zero is an instrument failure here for the same reason as above: this repo is KNOWN to
# contain at least one self-directory sibling call (that is why this block exists). Zero means the
# pattern stopped matching — a silent scanner, not a clean repo.
if [ "$sib_refs" -eq 0 ]; then
  bad "INSTRUMENT DEAD — zero self-directory sibling references found across $(printf '%s\n' "$SHIPPED_SH" | grep -c .) shipped scripts; the pattern is no longer matching anything"
elif [ "$sib_missing" -eq 0 ]; then
  ok "all $sib_refs runtime sibling dependenc(ies) of shipped scripts are themselves in files[]"
else
  bad "$sib_missing runtime sibling dependenc(ies) absent from files[] — the consumer gets a caller whose callee is missing"
fi

# CONTROL — the check must be able to say NO. A checker that only ever prints ok is indistinguishable
# from a checker that is not looking; assert the negative arm on a name that cannot be in files[].
if node -e 'const f=JSON.parse(process.argv[1]);process.exit(f.includes(process.argv[2])?0:1)' \
     "$FILES_JSON" "scripts/definitely_not_shipped_$$.sh"; then
  bad "CONTROL DEAD — a nonexistent path reported as shipped; the membership test is not testing"
else
  ok "control alive — a nonexistent path is correctly reported as not shipped"
fi

echo "----"
echo "capability entry-point shipping: $pass passed, $fail failed (entries=$n, missing=$missing)"
[ "$fail" -eq 0 ] || exit 1
