#!/usr/bin/env bash
# test_halffix_lanes.sh — known pairs for scripts/halffix_propagation_scan.sh
#
# WHY, AND WHY LANES FIRST
#   2026-07-30 harvest #1: rounds that wrote the lane BEFORE touching the code had zero
#   fix-reverts-fix regressions. Order made the convergence, not the patch.
#
# THE DEFECT BEING GUARDED — "반쪽-수리" (half-fix)
#   A defect class lives in N sibling copies. The fix lands in ONE. The siblings keep the bug, and
#   nothing says so. Measured 3x in this project, and the shape is worse than it sounds: every one
#   of the three occurred INSIDE an edit that was itself repairing an earlier half-fix.
#   scripts/psa_scan_lib.sh's header records five such divergences found in a single audit — the
#   override-readable check, the fail-closed-on-no-patterns branch, the SPACE-vs-TAB row, the
#   `head -1` shielding, and the LOW allowlist — each repaired where it was found and nowhere else.
#
# THE DISCRIMINATOR THAT MAKES THIS USEFUL INSTEAD OF NOISY (lane N3)
#   If BOTH copies are staged, the fix WAS propagated and the scan must stay silent. A detector that
#   fires on correct propagation is a detector that gets ignored — the S5 lesson (9/9 FP, narrowed
#   2026-07-28) and the S6 lesson (0 true positives on the planned surface, retargeted 2026-07-31)
#   are the two prior claims on this exact mistake in this repo.
#
# ADVISORY BY MANDATE, not by preference: the operator's spec for this debt says "표시(차단 아님 —
#   정당한 복제도 있다)" — mark, do not block, because legitimate duplication exists.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN="$ROOT/scripts/halffix_propagation_scan.sh"
pass=0; fail=0

# mkrepo <dir> — a throwaway git repo; caller populates and stages.
mkrepo() {
  rm -rf "$1"; mkdir -p "$1"; ( cd "$1" && git init -q . && git config user.email t@e && git config user.name t )
}

# expect <label> <FLAG|SILENT> <repo> [needle]
expect() {
  local label="$1" want="$2" repo="$3" needle="${4:-}" out got
  out=$( cd "$repo" && bash "$SCAN" 2>&1 )
  if printf '%s' "$out" | grep -q 'HALF-FIX'; then got=FLAG; else got=SILENT; fi
  if [ "$got" = "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q "$needle"; }; then
    printf '  ✅ %-50s %s\n' "$label" "$got"; pass=$((pass+1))
  else
    printf '  ❌ %-50s %s (expected %s%s)\n' "$label" "$got" "$want" \
      "${needle:+, needle '$needle'}"; fail=$((fail+1))
    printf '     out: %s\n' "$(printf '%s' "$out" | head -6)"
  fi
}

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
echo "[halffix] known pairs"

# ── P1: the canonical shape — a distinctive symbol duplicated in a sibling, only one staged ──
R="$T/p1"; mkrepo "$R"
printf 'psa_low_allowlisted() {\n  case "$1" in templates/*) return 0 ;; esac\n}\n' > "$R/a.sh"
printf 'psa_low_allowlisted() {\n  case "$1" in templates/*) return 0 ;; esac\n}\n' > "$R/b.sh"
( cd "$R" && git add . && git commit -qm base )
printf 'psa_low_allowlisted() {\n  case "$1" in templates/*|docs/*) return 0 ;; esac\n}\n' > "$R/a.sh"
( cd "$R" && git add a.sh )
expect "P1 sibling copy left unstaged" FLAG "$R" "b.sh"

# ── P2: three copies, one staged — both remaining siblings named ──
R="$T/p2"; mkrepo "$R"
for f in a b c; do printf 'validate_marker_fields_strictly() { :; }\n' > "$R/$f.sh"; done
( cd "$R" && git add . && git commit -qm base )
printf 'validate_marker_fields_strictly() { echo fixed; }\n' > "$R/a.sh"
( cd "$R" && git add a.sh )
expect "P2 two siblings, both named"   FLAG "$R" "c.sh"

# ── N3: THE DISCRIMINATOR — both copies staged means the fix propagated. Silence. ──
R="$T/n3"; mkrepo "$R"
printf 'psa_low_allowlisted() { :; }\n' > "$R/a.sh"; cp "$R/a.sh" "$R/b.sh"
( cd "$R" && git add . && git commit -qm base )
printf 'psa_low_allowlisted() { echo fixed; }\n' > "$R/a.sh"; cp "$R/a.sh" "$R/b.sh"
( cd "$R" && git add a.sh b.sh )
expect "N3 both staged = propagated"   SILENT "$R"

# ── N4: unique content — nothing to propagate to ──
R="$T/n4"; mkrepo "$R"
printf 'lonely_unique_helper_fn() { :; }\n' > "$R/a.sh"
printf 'something_entirely_different() { :; }\n' > "$R/b.sh"
( cd "$R" && git add . && git commit -qm base )
printf 'lonely_unique_helper_fn() { echo x; }\n' > "$R/a.sh"
( cd "$R" && git add a.sh )
expect "N4 no sibling holds the symbol"  SILENT "$R"

# ── N5: ubiquitous token — a word in 12 files is framework noise, not a half-fix ──
R="$T/n5"; mkrepo "$R"
for i in $(seq 1 12); do printf 'REPO_ROOT_DIRECTORY=/x\n' > "$R/f$i.sh"; done
( cd "$R" && git add . && git commit -qm base )
printf 'REPO_ROOT_DIRECTORY=/y\n' > "$R/f1.sh"
( cd "$R" && git add f1.sh )
expect "N5 ubiquitous token suppressed"  SILENT "$R"

# ── N6: short/common tokens must not anchor (would flag on `then`, `echo`, `return`) ──
R="$T/n6"; mkrepo "$R"
printf 'if [ -f x ]; then echo a; fi\n' > "$R/a.sh"
printf 'if [ -f y ]; then echo b; fi\n' > "$R/b.sh"
( cd "$R" && git add . && git commit -qm base )
printf 'if [ -f x ]; then echo c; fi\n' > "$R/a.sh"
( cd "$R" && git add a.sh )
expect "N6 short shell keywords ignored"  SILENT "$R"

# ── P7: filenames count as symbols too (the spec says "수정 심볼·파일명") ──
R="$T/p7"; mkrepo "$R"
printf 'bash scripts/sidecar_calibrate.sh --run\n' > "$R/a.sh"
printf 'bash scripts/sidecar_calibrate.sh --run\n' > "$R/doc.md"
( cd "$R" && git add . && git commit -qm base )
printf 'bash scripts/sidecar_calibrate.sh --run --strict\n' > "$R/a.sh"
( cd "$R" && git add a.sh )
expect "P7 filename token propagates"    FLAG "$R" "doc.md"

# ── N8: nothing staged at all ──
R="$T/n8"; mkrepo "$R"; printf 'x\n' > "$R/a.sh"; ( cd "$R" && git add . && git commit -qm base )
expect "N8 empty staging area"           SILENT "$R"

# ── N9: opt-out ──
R="$T/n9"; mkrepo "$R"
printf 'psa_low_allowlisted() { :; }\n' > "$R/a.sh"; cp "$R/a.sh" "$R/b.sh"
( cd "$R" && git add . && git commit -qm base )
printf 'psa_low_allowlisted() { echo x; }  # noqa: half-fix\n' > "$R/a.sh"
( cd "$R" && git add a.sh )
expect "N9 noqa suppresses"              SILENT "$R"

# ── N10: deleted file must not crash the scan ──
R="$T/n10"; mkrepo "$R"
printf 'psa_low_allowlisted() { :; }\n' > "$R/a.sh"; cp "$R/a.sh" "$R/b.sh"
( cd "$R" && git add . && git commit -qm base )
( cd "$R" && git rm -q a.sh )
expect "N10 deletion does not crash"     SILENT "$R"

echo "-- R2: whole-file copy divergence (found by LIVE calibration, not by the lanes above) --"
# The token rule alone MISSED this repo's real duplicate pair (scripts/degrade_direction_scan.sh ↔
# templates/degrade_direction_scan.sh) because a script's NAME appears in 11–18 files here — docs,
# CATALOG, the manifest, selfcheck references — so the ubiquity filter suppressed it, while an
# internal symbol like psa_low_allowlisted appears in 2. Measured 2026-07-31: the lanes were 10/10
# green and the live probe was silent. Lanes are necessary and not sufficient.
#
# The predicate is exact rather than heuristic: the sibling was BYTE-IDENTICAL at HEAD and only one
# side is staged. That is a divergence by construction, so it needs no threshold — and it stays
# silent for same-basename files that were never copies (CLAUDE.md vs templates/CLAUDE.md, the 40
# SKILL.md files), which a basename rule would have flooded.
R="$T/r2p"; mkrepo "$R"; mkdir -p "$R/scripts" "$R/templates"
printf 'a() { :; }\nb() { :; }\n' > "$R/scripts/x.sh"
cp "$R/scripts/x.sh" "$R/templates/x.sh"
( cd "$R" && git add . && git commit -qm base )
printf 'a() { echo fixed; }\nb() { :; }\n' > "$R/scripts/x.sh"
( cd "$R" && git add scripts/x.sh )
expect "R2 byte-identical copy diverges"  FLAG "$R" "templates/x.sh"

R="$T/r2n"; mkrepo "$R"; mkdir -p "$R/scripts" "$R/templates"
printf 'hub version, quite different\n' > "$R/scripts/x.sh"
printf 'template version, also different\n' > "$R/templates/x.sh"
( cd "$R" && git add . && git commit -qm base )
printf 'hub version, edited\n' > "$R/scripts/x.sh"
( cd "$R" && git add scripts/x.sh )
expect "R2 same name but never a copy"    SILENT "$R"

R="$T/r2b"; mkrepo "$R"; mkdir -p "$R/scripts" "$R/templates"
printf 'a() { :; }\n' > "$R/scripts/x.sh"; cp "$R/scripts/x.sh" "$R/templates/x.sh"
( cd "$R" && git add . && git commit -qm base )
printf 'a() { echo fixed; }\n' > "$R/scripts/x.sh"; cp "$R/scripts/x.sh" "$R/templates/x.sh"
( cd "$R" && git add scripts/x.sh templates/x.sh )
expect "R2 both staged = propagated"      SILENT "$R"

echo
if [ "$fail" -eq 0 ]; then
  echo "[halffix] ✅ all $pass known pairs hold"; exit 0
else
  echo "[halffix] ❌ $fail/$((pass+fail)) lanes failed"; exit 1
fi
