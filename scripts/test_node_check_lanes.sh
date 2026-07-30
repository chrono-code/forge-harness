#!/usr/bin/env bash
# test_node_check_lanes.sh — regression lanes for scripts/fh_node_check.sh.
#
# WHY THIS FILE EXISTS: across three adversarial rounds on the node check, every surviving defect
# was a NEGATIVE leg nobody was testing — "the floor does not apply here", "those are someone
# else's hooks", "that file is absent on a fresh clone". Each round's fix reverted a previous
# round's fix because no lane pinned it. The lanes below are that pin: they encode the *shape* of
# each defect, not just its instance.
#
# Usage:  bash scripts/test_node_check_lanes.sh
# Exit:   0 = all lanes pass; 1 = at least one lane failed (prints which and why).

set -uo pipefail

FH_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$FH_REPO/scripts/fh_node_check.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  ❌ %s\n     got: %s\n' "$1" "$(printf '%s' "$2" | tr '\n' '|' | cut -c1-220)"; }

# run <hubdir> <statefile> [env assignments...] → stdout of one check run
run() { local hub="$1" st="$2"; shift 2; env "$@" HUB_DIR="$hub" FH_NODE_STATE="$st" bash "$CHECK" 2>&1; }

mk_git_hub() {   # a git repo with FH-style hooks installed and executable
  local d="$1" fh_sentinel="${2:-yes}"
  mkdir -p "$d" && git -C "$d" init -q && git -C "$d" config user.email t@t && git -C "$d" config user.name t
  echo x > "$d/f" && git -C "$d" add f && git -C "$d" -c commit.gpgsign=false commit -qm init
  mkdir -p "$d/.git/hooks"
  local body='#!/bin/sh\nexit 0\n'
  [ "$fh_sentinel" = "yes" ] && body='#!/bin/sh\n# FH 4-Axis Gate Pre-Commit Hook\nfh-gate\nexit 0\n'
  printf "$body" > "$d/.git/hooks/pre-commit"; printf "$body" > "$d/.git/hooks/pre-push"
  chmod +x "$d/.git/hooks/pre-commit" "$d/.git/hooks/pre-push"
}

echo "── node-check lanes ──"

# LANE 1 (S3-1) — NOT a git repo. The git-hook floor cannot be installed here at all, so it is
# N/A, not missing. Reporting it would be an unfixable notice repeating every session forever.
mkdir -p "$TMP/nogit"
out="$(run "$TMP/nogit" "$TMP/s1" FH_MACHINE_ID=nogitbox)"
# POSITIVE CONTROL: assert what MUST appear alongside what must not. Absence-only lanes are
# satisfied by a script that prints nothing at all — an `exit 0` stub passed lanes 1, 4 and 7
# (cross-family mutation 2026-07-30), so each now pins an expected utterance too.
case "$out" in
  *"Missing mechanical floor"*) bad "lane1 non-git: must NOT claim a missing floor (N/A, unfixable)" "$out" ;;
  *"first session for this clone"*) ok "lane1 non-git: N/A on the git floor, but still reports the node event" ;;
  *) bad "lane1 non-git: silent — a stub would pass this lane" "$out" ;;
esac

# LANE 2 (S3-2) — hooks exist but belong to another framework (husky/pre-commit). Executable ≠ FH's
# gate. Silence here is the exact accident this check was built for: FH gates absent, machine quiet.
mk_git_hub "$TMP/husky" no
out="$(run "$TMP/husky" "$TMP/s2" FH_MACHINE_ID=huskybox)"
case "$out" in
  *"Missing mechanical floor"*) ok "lane2 foreign hooks: FH gate absence reported" ;;
  *) bad "lane2 foreign hooks: non-FH hooks were accepted as FH floors" "$out" ;;
esac

# LANE 3 (S3-3) — Mode D user on a FRESH clone: companion store present, settings.local.json absent
# (it is gitignored, so a clone never has it). This is the MEASURED 2026-07-30 incident. Must speak.
mk_git_hub "$TMP/moded" yes
mkdir -p "$TMP/companion/.git"
out="$(run "$TMP/moded" "$TMP/s3" FH_MACHINE_ID=modedbox BE_DIR="$TMP/companion")"
case "$out" in
  *companion-load*) ok "lane3 fresh Mode D clone: companion-load absence surfaced" ;;
  *) bad "lane3 fresh Mode D clone: SILENT — the measured incident would recur" "$out" ;;
esac

# LANE 4 (M2-4) — public non-Mode-D user: no companion store anywhere. The companion item must not
# appear, or the majority path gets a false positive for a feature it does not use.
mk_git_hub "$TMP/public" yes
out="$(run "$TMP/public" "$TMP/s4" FH_MACHINE_ID=publicbox)"
case "$out" in
  *companion-load*) bad "lane4a non-Mode-D: companion item shown to a user with no store" "$out" ;;
  *"first session for this clone"*) ok "lane4a non-Mode-D: companion absent, node event still reported" ;;
  *) bad "lane4a non-Mode-D: silent — a stub would pass this lane" "$out" ;;
esac

# LANE 4b (S4-1) — CLAUDE.local.md is Claude Code's STANDARD local-override file; anyone may keep
# one for any reason. Its mere EXISTENCE must not classify a user as Mode D, or the majority path
# gets a companion notice every session forever (state-based emission makes it permanent, not
# one-shot). Only the binding INSIDE the file counts.
printf '# my local notes\nuse tabs not spaces\n' > "$TMP/public/CLAUDE.local.md"
out="$(run "$TMP/public" "$TMP/s4b" FH_MACHINE_ID=publicbox)"
case "$out" in
  *companion-load*) bad "lane4b plain CLAUDE.local.md: existence alone classified the user as Mode D" "$out" ;;
  *) ok "lane4b plain CLAUDE.local.md: not treated as a Mode D signal" ;;
esac

# LANE 4c — the same file WITH a companion binding must classify as Mode D and speak. Without this
# leg, "never classify as Mode D" would also pass 4b.
# One fixture PER alternative: a single fixture like `BE_DIR=/some/companion-store` satisfies two
# alternatives at once, so either could be deleted and the lane would still pass. The store is a
# ROLE, not a repo layout (install-wizard SKILL.md: Obsidian vault / gbrain ingest target / *-be
# repo all qualify) — so the vocabulary variants are the documented user base, not hypotheticals.
i=0
# `backend: obsidian` carries no other keyword on purpose — with a `vault:` fixture only, the
# `obsidian` alternative is never exercised and could be deleted with the suite staying green
# (verified: removing it left 16/16). An untested alternative is an untested branch.
for binding in 'BE_DIR=/x/store' 'companion store: ~/notes' '컴패니언 스토어: ~/notes' \
               'vault: ~/vaults/notes' 'gbrain ingest target: ~/gbrain' 'backend: obsidian'; do
  i=$((i+1))
  printf '# local\n%s\n' "$binding" > "$TMP/public/CLAUDE.local.md"
  out="$(run "$TMP/public" "$TMP/s4c$i" FH_MACHINE_ID=publicbox)"
  case "$out" in
    *companion-load*) ok "lane4c.$i Mode D detected via: $binding" ;;
    *) bad "lane4c.$i binding present but Mode D not detected: $binding" "$out" ;;
  esac
done
rm -f "$TMP/public/CLAUDE.local.md"

# LANE 5 — emission model: a healthy machine speaks once (event) then goes silent.
mk_git_hub "$TMP/healthy" yes
r1="$(run "$TMP/healthy" "$TMP/s5" FH_MACHINE_ID=healthybox)"
r2="$(run "$TMP/healthy" "$TMP/s5" FH_MACHINE_ID=healthybox)"
if [ -n "$r1" ] && [ -z "$r2" ]; then ok "lane5 healthy: event once, then silent"
else bad "lane5 healthy: expected run1 non-empty and run2 empty" "r1=[$r1] r2=[$r2]"; fi

# LANE 6 (S2-4) — a missing floor is a CONDITION: it must be reported on every run, not once.
mk_git_hub "$TMP/broken" yes
rm -f "$TMP/broken/.git/hooks/pre-commit"
n=0
for i in 1 2 3; do
  o="$(run "$TMP/broken" "$TMP/s6" FH_MACHINE_ID=brokenbox)"
  case "$o" in *"Missing mechanical floor"*) n=$((n+1)) ;; esac
done
[ "$n" -eq 3 ] && ok "lane6 broken: reported on all 3 runs (condition, not event)" \
               || bad "lane6 broken: reported $n/3 runs — a broken machine went quiet" "n=$n"

# LANE 7 (M2-2) — linked worktree: .git is a FILE there, so a hand-built "$FH/.git/hooks" does not
# exist and working hooks read as missing.
mk_git_hub "$TMP/wt" yes
git -C "$TMP/wt" worktree add -q "$TMP/wt_linked" -b lane7 2>/dev/null
out="$(run "$TMP/wt_linked" "$TMP/s7" FH_MACHINE_ID=wtbox)"
case "$out" in
  *"Missing mechanical floor"*) bad "lane7 worktree: false missing-floor (hooks resolve to the main gitdir)" "$out" ;;
  *"first session for this clone"*) ok "lane7 worktree: hooks resolved correctly, node event reported" ;;
  *) bad "lane7 worktree: silent — a stub would pass this lane" "$out" ;;
esac

# LANE 8 (M3-3) — python3 unavailable: the companion verdict is UNMEASURED, never silently "fine".
# Simulated by a PATH with no python3, for a Mode D hub (so the check is applicable).
mk_git_hub "$TMP/nopy" yes
mkdir -p "$TMP/emptybin" "$TMP/companion2/.git"
out="$(PATH="$TMP/emptybin:/usr/bin:/bin" run "$TMP/nopy" "$TMP/s8" FH_MACHINE_ID=nopybox BE_DIR="$TMP/companion2")"
if command -v python3 >/dev/null 2>&1 && [ -x /usr/bin/python3 ]; then
  ok "lane8 skipped: /usr/bin/python3 exists so absence cannot be simulated via PATH"
else
  case "$out" in
    *UNMEASURED*|*unmeasured*) ok "lane8 no python3: reported UNMEASURED, not silence" ;;
    *) bad "lane8 no python3: absence read as pass" "$out" ;;
  esac
fi

# LANE 9 (S4-2) — the sentinel regex is coupled to PROSE THAT LIVES IN ANOTHER FILE. Every other
# lane hands it a fixture containing the string it expects, so the suite would stay fully green
# while a purely cosmetic edit to the real hook headers (which no gate checks) made every FH machine
# report "not FH's gate" every session. Calibrate the instrument against the shipped article.
# DERIVE the regex from the script — never retype it. A hardcoded copy is the divergent-copy class
# this repo already paid for once (SYNC_EXCLUDES in three places, which needed its own parity
# checker): tighten the script's regex and a duplicated lane keeps validating the SHIPPED hooks
# against the OLD pattern, staying green while the real check drifts.
SENT="$(sed -n "s/.*grep -qE '\([^']*\)'.*/\1/p" "$FH_REPO/scripts/fh_node_check.sh" | head -1)"
if [ -z "$SENT" ]; then
  bad "lane9 sentinel: could not derive the regex from fh_node_check.sh (extraction broke — not a pass)" "empty"
  SENT='__never_matches__'
fi
for h in "$FH_REPO"/templates/.git-hooks/pre-commit "$FH_REPO"/templates/.git-hooks/pre-push; do
  if [ ! -f "$h" ]; then bad "lane9 sentinel: shipped hook missing: $h" "absent"; continue; fi
  if grep -qE "$SENT" "$h"; then ok "lane9 sentinel matches shipped $(basename "$h")"
  else bad "lane9 sentinel does NOT match shipped $(basename "$h") — every FH machine would report 'not FH gate'" "$(head -3 "$h")"; fi
done

printf '\nnode-check lanes: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
