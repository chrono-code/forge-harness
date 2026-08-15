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

# ── lane10 — consent-gated auto-pull: the APPLY arm and every REFUSE arm ─────────────────────
# Added 2026-08-15 with the feature. These lanes exist because the feature's whole safety claim is
# about what it does NOT do, and "does not" is exactly what a green run cannot demonstrate by
# itself — every refuse arm below is paired against an apply arm in the same fixture, so a lane
# that goes silently inert fails the CONTROL rather than passing everything.
# 🟥 The load-bearing one is lane10-b: in a shared checkout a branch switch yanks the ground out
# from under a peer session (measured 2026-08-09, two sessions/one worktree). If this feature ever
# switches branches, that lane is what says so.
_ap_root="$(mktemp -d)"
(
  cd "$_ap_root" || exit 1
  # Pin the branch name: `git init` uses init.defaultBranch, which is main on this
  # operator's machine and master on a stock Ubuntu (CI). Hardcoding "main" in the
  # assertions below made lane10-b pass VACUOUSLY there (`rev-parse "$_DEF"` returned
  # empty, and empty==empty compared true) while CONTROL's reset silently no-op'd.
  git -c init.defaultBranch=main init -q up && cd up
  git config user.email t@t; git config user.name t; git config commit.gpgsign false
  mkdir -p scripts tracks/_meta
  cp "$FH_REPO/scripts/fh_node_check.sh" "$FH_REPO/scripts/consent_registry_check.sh" scripts/
  # Build the consent fixture from the SHIPPED TEMPLATE, never from the operator's local
  # tracks/_meta/ — those are gitignored, so on CI (and on any fresh clone) they do not exist and
  # the lanes would report a red FAIL for a file whose absence is correct by design. Measured on
  # CI 2026-08-15: exactly that, "registry/UAP absent — lanes not run". Sourcing the template
  # instead is strictly better than degrading to SKIP: the lanes then actually run everywhere, and
  # they validate the very block a consumer is told to copy.
  cp "$FH_REPO/templates/consent_classes.yaml.example" tracks/_meta/consent_classes.yaml
  # The grant side has no shipped template (a UAP is per-operator by nature), so synthesize the
  # minimum the registry check requires: the full R6 fingerprint, far-future expiry so the fixture
  # never rots into a false refusal, joined to the template's own class name.
  # Dates are computed at fixture-build time, not hardcoded, for two reasons that pull opposite
  # ways: a fixed past date rots into a false REFUSE, and a far-future one is refused outright —
  # R5 caps a lease at 365 days ("an unbounded expiry is a transfer, not a lease"), and the first
  # version of this fixture used 2099-01-01 and was correctly rejected by the very floor the
  # feature depends on. GNU-first with validation, same discipline as every _mtime helper here:
  # `date -d` is GNU, `date -v` is BSD, and neither failing silently is acceptable.
  _g="$(date +%Y-%m-%d)"
  _e="$(date -d '+300 days' +%Y-%m-%d 2>/dev/null || date -v+300d +%Y-%m-%d 2>/dev/null || echo '')"
  case "$_e" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) : ;;
    *) bad "lane10 fixture: could not compute a lease expiry (neither GNU nor BSD date worked)" "$_e"; _e="$_g" ;;
  esac
  cat > tracks/_meta/user_adaptation_profile.md <<UAPEOF
---
standing_consent:
  repo-freshness-autopull:
    granted: $_g
    expires: $_e
    owner: scripts/fh_node_check.sh
    mode: ff-only-merge-on-default-branch
    target: this repo's own default branch, in the local clone, when it is already checked out
    effects: [network, repo-mutation]
    sinks: []
---
lane fixture — not a real profile
UAPEOF
  echo base > f.txt; git add -A >/dev/null; git commit -qm base
  cd ..; git clone -q up dn; cd up; echo newer > f.txt; git commit -qam ahead
) >/dev/null 2>&1
_dn="$_ap_root/dn"
if [ ! -d "$_dn/.git" ] || [ ! -f "$_dn/tracks/_meta/consent_classes.yaml" ]; then
  bad "lane10 fixture: could not build the consent fixture (registry/UAP absent — lanes not run)" "$_ap_root"
else
  git -C "$_dn" config user.email t@t >/dev/null 2>&1; git -C "$_dn" config user.name t >/dev/null 2>&1
  # Derive rather than assume — belt-and-braces over the pin above, so a future git
  # whose init behaviour changes again cannot make these lanes vacuous a second time.
  _DEF="$(git -C "$_dn" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  [ -n "$_DEF" ] || _DEF=main
  if ! git -C "$_dn" show-ref --verify --quiet "refs/heads/$_DEF"; then
    bad "lane10 fixture: default branch '$_DEF' has no local ref — assertions below would be vacuous" "$(git -C "$_dn" branch -a)"
  fi
  git -C "$_dn" fetch -q origin >/dev/null 2>&1
  _h0="$(git -C "$_dn" rev-parse HEAD)"
  run "$_dn" "$_ap_root/s_a" >/dev/null 2>&1
  if [ "$(git -C "$_dn" rev-parse HEAD)" != "$_h0" ]; then
    ok "lane10-a APPLY: consented + on default branch → fast-forwarded"
  else
    bad "lane10-a APPLY: consented + on default branch did NOT fast-forward (feature inert — every refuse lane below is then vacuous)" "$_h0"
  fi

  # b — the envelope. Never applies off the default branch, and NEVER switches branches.
  (cd "$_ap_root/up" && echo newer2 > f.txt && git commit -qam ahead2) >/dev/null 2>&1
  git -C "$_dn" fetch -q origin >/dev/null 2>&1
  git -C "$_dn" switch -c feat-x -q >/dev/null 2>&1
  _m0="$(git -C "$_dn" rev-parse "$_DEF")"
  # ⚠️ CHECKING main AND THE BRANCH NAME IS NOT ENOUGH — measured by a revert probe 2026-08-15.
  # With the envelope deliberately broken, `merge --ff-only origin/main` fast-forwards THE BRANCH
  # YOU ARE ON, so feat-x moved while `main` sat still and the branch name never changed. The first
  # version of this lane asserted only those two and stayed green against a defeated envelope —
  # decorative. The tip that must not move is the CURRENT branch's own.
  _f0="$(git -C "$_dn" rev-parse feat-x)"
  run "$_dn" "$_ap_root/s_b" >/dev/null 2>&1
  if [ "$(git -C "$_dn" rev-parse "$_DEF")" = "$_m0" ] \
     && [ "$(git -C "$_dn" rev-parse feat-x)" = "$_f0" ] \
     && [ "$(git -C "$_dn" branch --show-current)" = "feat-x" ]; then
    ok "lane10-b ENVELOPE: off default branch → no apply on EITHER branch, no switch"
  else
    bad "lane10-b ENVELOPE: a branch tip moved off the default branch — the shared-checkout hazard" "main=$_m0->$(git -C "$_dn" rev-parse "$_DEF") feat-x=$_f0->$(git -C "$_dn" rev-parse feat-x) branch=$(git -C "$_dn" branch --show-current)"
  fi
  git -C "$_dn" switch -q "$_DEF" >/dev/null 2>&1

  # c — no grant. absent ≠ granted.
  cp "$_dn/tracks/_meta/user_adaptation_profile.md" "$_ap_root/uap.bak"
  python3 - "$_dn/tracks/_meta/user_adaptation_profile.md" <<'PYX'
import re,sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
open(p,'w',encoding='utf-8').write(re.sub(r'\nstanding_consent:\n(?:  .*\n|    .*\n)*', '\n', s, count=1))
PYX
  _h1="$(git -C "$_dn" rev-parse HEAD)"
  run "$_dn" "$_ap_root/s_c" >/dev/null 2>&1
  [ "$(git -C "$_dn" rev-parse HEAD)" = "$_h1" ] \
    && ok "lane10-c NO-GRANT: absent standing_consent → no apply" \
    || bad "lane10-c NO-GRANT: applied without a grant" "$_h1"

  # d — expired lease. A lease nobody enforces is not a lease.
  cp "$_ap_root/uap.bak" "$_dn/tracks/_meta/user_adaptation_profile.md"
  sed -i.bak2 's/expires: [0-9-]*/expires: 2020-01-01/' "$_dn/tracks/_meta/user_adaptation_profile.md"
  _h2="$(git -C "$_dn" rev-parse HEAD)"
  run "$_dn" "$_ap_root/s_d" >/dev/null 2>&1
  [ "$(git -C "$_dn" rev-parse HEAD)" = "$_h2" ] \
    && ok "lane10-d EXPIRED: past-dated lease → no apply" \
    || bad "lane10-d EXPIRED: applied under an expired lease" "$_h2"
  cp "$_ap_root/uap.bak" "$_dn/tracks/_meta/user_adaptation_profile.md"

  # e — divergence. --ff-only must refuse rather than absorb, and local work must survive.
  (cd "$_dn" && echo local-only > mine.txt && git add -A && git commit -qm diverge) >/dev/null 2>&1
  _h3="$(git -C "$_dn" rev-parse HEAD)"
  run "$_dn" "$_ap_root/s_e" >/dev/null 2>&1
  if [ "$(git -C "$_dn" rev-parse HEAD)" = "$_h3" ] && [ -f "$_dn/mine.txt" ]; then
    ok "lane10-e DIVERGED: ff refused, local commit survives"
  else
    bad "lane10-e DIVERGED: local history was moved or lost" "$_h3 -> $(git -C "$_dn" rev-parse HEAD)"
  fi

  # CONTROL — after all the refuse arms, prove the apply arm still fires. Without this, a lane
  # suite where the feature has gone inert reports 4 clean refusals and looks perfect.
  git -C "$_dn" reset -q --hard "origin/$_DEF" >/dev/null 2>&1   # noqa: destructive-op (throwaway fixture)
  (cd "$_ap_root/up" && echo newer3 > f.txt && git commit -qam ahead3) >/dev/null 2>&1
  git -C "$_dn" fetch -q origin >/dev/null 2>&1
  _h4="$(git -C "$_dn" rev-parse HEAD)"
  run "$_dn" "$_ap_root/s_f" >/dev/null 2>&1
  [ "$(git -C "$_dn" rev-parse HEAD)" != "$_h4" ] \
    && ok "lane10-CONTROL: apply arm still fires after the refuse arms (instrument alive)" \
    || bad "lane10-CONTROL: apply arm went inert — the refuse lanes above prove nothing" "$_h4"
fi
rm -rf "$_ap_root"

printf '\nnode-check lanes: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
