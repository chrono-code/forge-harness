#!/usr/bin/env bash
# test_precommit_pointer_index_lanes.sh — known pair for templates/.git-hooks/pre-commit [Pointers]:
# the Detail-pointer gate must read the STAGED blob, not the working tree. Found 2026-09-03 (arm C
# wt2, A3 triage): `[ -f "$REPO_ROOT/$f" ] || continue` let a staged .md with a broken
# `**Detail**: See §X` pointer land silently when the file was rm'd from disk after staging
# (git commits the INDEX). Runs in a disposable shallow clone — never touches this checkout.
#   P1 staged broken pointer, file rm'd from disk       → commit BLOCKED (❌ pointer line printed)
#   N1 staged VALID pointer, file rm'd from disk        → [Pointers] block runs with no ❌ (control: index read works)
#   N2 staged broken pointer, file still on disk        → BLOCKED (the pre-fix path also caught this — control)
# Usage: bash scripts/test_precommit_pointer_index_lanes.sh [--hook <path>]   (default = templates/.git-hooks/pre-commit)
set -u; ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; HOOK="$ROOT/templates/.git-hooks/pre-commit"
[ "${1:-}" = "--hook" ] && HOOK="$2"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT; pass=0; fail=0
git clone -q --depth 1 "file://$ROOT" "$T/r" 2>/dev/null || { echo "❌ clone failed"; exit 10; }
cd "$T/r" && git config user.email t@t && git config user.name t && mkdir -p .git/hooks && cp "$HOOK" .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
mkdir -p docs/lanefix; printf '## §Alive\ntext\n' > docs/lanefix/target.md; git add docs/lanefix/target.md; git -c core.hooksPath=/dev/null commit -qm base 2>/dev/null
run_case(){ local label="$1" want="$2" ptr="$3" rm_after="$4"
  printf '# probe\n\n> **Detail**: See `docs/lanefix/target.md §%s`\n' "$ptr" > docs/lanefix/probe.md
  git add docs/lanefix/probe.md; [ "$rm_after" = 1 ] && rm -f docs/lanefix/probe.md
  out=$(FH_SKIP_GATE_AXES=1 git commit -qm probe 2>&1); rc=$?
  # Discriminate on the [Pointers] block itself, not on commit rc: the fixture clone carries no
  # marker/manifest, so OTHER axes block every commit here — rc is not this lane's signal.
  if printf '%s' "$out" | grep -q "Detail pointer §"; then got=BLOCK_PTR
  elif printf '%s' "$out" | grep -q "unreadable from the index"; then got=BLOCK_INDEX
  elif printf '%s' "$out" | grep -q "\[Pointers\]"; then got=PTR_OK
  else got=PTR_NOT_RUN; fi
  git reset -q --hard HEAD 2>/dev/null;  # noqa: destructive-op — disposable clone under mktemp git rm -q --cached docs/lanefix/probe.md 2>/dev/null; rm -f docs/lanefix/probe.md
  if [ "$got" = "$want" ]; then printf '  ✅ %-48s %s\n' "$label" "$got"; pass=$((pass+1)); else printf '  ❌ %-48s %s (expected %s)\n' "$label" "$got" "$want"; fail=$((fail+1)); printf '%s\n' "$out" | grep -E "Pointers|❌" | head -4 | sed 's/^/       /'; fi; }
echo "[precommit-pointer-index] hook=$HOOK"
run_case "P1 broken pointer, staged then rm'd from disk"  BLOCK_PTR Ghost 1
run_case "N1 valid pointer, staged then rm'd (index read)" PTR_OK    Alive 1
run_case "N2 broken pointer, still on disk (old path too)" BLOCK_PTR Ghost 0
echo "[precommit-pointer-index] $pass passed, $fail failed"; [ "$fail" -eq 0 ]
