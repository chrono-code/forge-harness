#!/usr/bin/env bash
# test_push_zone_lanes.sh — known-pair anchor for the pre-push hook's Push-Zone verdict, and for
# the session-close ①-f advisory that mirrors it.
#
# ── WHY THIS FILE EXISTS ───────────────────────────────────────────────────────────────────────
# 2026-09-05: templates/.git-hooks/pre-push gained a new verdict path and scripts/session_close_
# check.sh gained a new ①-f advisory, both implementing CLAUDE.local.md §REST API push 계정규칙
# mechanically — a push to a github.com remote whose owner is NOT on the operator's owner-account
# list needs the REST Contents API channel, not plain git push. Before this suite the new code had
# no known-pair anchor at all. Per CLAUDE.md §Instrument Calibration, a gate is not trusted until
# calibrated on at least one known-positive and one known-negative, hand-verified.
#
# ── DISCIPLINE INHERITED FROM THE SIBLING SUITE (test_prepush_destructive_lanes.sh) ────────────
#  (a) Run the hook FOR REAL — `bash -n` is not an instrument (a runtime fault can parse clean,
#      abort the hook, and still exit 0).
#  (b) A runtime fault is checked BEFORE the verdict, else an aborted hook scores as a clean pass.
#  (c) "It blocked" is NOT "it blocked correctly" — a block must be ATTRIBUTED to a named FH gate.
#  (d) NEVER read or assert on the operator's real owner-account list
#      (.claude/rules/.push-zone-owners). Every lane below builds its own throwaway fixture list
#      via the PUSH_ZONE_OWNERS override, with fictitious account names. The real file, if present
#      on this machine, is never opened by this suite in either direction.
#
# Runs entirely in mktemp throwaway repos: never touches this repo's index, worktree, refs, or its
# real .claude/rules/.push-zone-owners.
#
# Usage: bash scripts/test_push_zone_lanes.sh
#   FH_PUSH_ZONE_HOOK_SRC=<path>  → test a DIFFERENT copy of the pre-push hook (fail-before proof).
#   FH_PUSH_ZONE_SCC_SRC=<path>   → same, for session_close_check.sh.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOK_SRC="${FH_PUSH_ZONE_HOOK_SRC:-$REPO_ROOT/templates/.git-hooks/pre-push}"
SCC_SRC="${FH_PUSH_ZONE_SCC_SRC:-$REPO_ROOT/scripts/session_close_check.sh}"
DEF_SRC="$REPO_ROOT/.claude/rules/.public-surface-patterns.defaults"
ZERO="0000000000000000000000000000000000000000"

if [ ! -f "$HOOK_SRC" ]; then
  echo "HARNESS_ERROR — pre-push hook not found at $HOOK_SRC (subject absent; NOT a pass)"; exit 1
fi

WORK="$(fh_fixture_root "$(mktemp -d)")" || exit 1
: "${WORK:?fixture root unset — refusing to run git in cwd}"
trap 'rm -rf "$WORK"' EXIT
cp "$HOOK_SRC" "$WORK/hook" || exit 1
HOOK="$WORK/hook"

# Fictitious owner-account fixture — NEVER the operator's real list. The second entry
# (acme-shared-org) is asserted to never appear in any captured output — it is a decoy for the
# "list content is never printed" requirement, not used by any URL in this suite.
OWNERS_OK="$WORK/owners-ok.txt"
printf '# fixture owner list — test only, not the operator real list\nknown-owner\nacme-shared-org\n' > "$OWNERS_OK"

PASSED=0; FAILED=0; ALL_OUT=""

# ── fixture: same shape as test_prepush_destructive_lanes.sh's newrepo() ───────────────────────
newrepo() {
  local d; d="$(fh_fixture_root "$(mktemp -d)")" || return 1
  : "${d:?fixture root unset — refusing to run git in cwd}"
  mkdir -p "$d/.claude/rules" "$d/templates/.git-hooks" "$d/tracks/_meta" "$d/scripts" || return 1
  [ -f "$DEF_SRC" ] && cp "$DEF_SRC" "$d/.claude/rules/.public-surface-patterns.defaults"
  [ -f "$REPO_ROOT/scripts/psa_scan_lib.sh" ] && cp "$REPO_ROOT/scripts/psa_scan_lib.sh" "$d/scripts/psa_scan_lib.sh"
  printf '.claude/rules/.public-surface-patterns\n' > "$d/.gitignore"
  cp "$HOOK" "$d/templates/.git-hooks/pre-push" || return 1
  printf 'base\n' > "$d/a.txt"
  (
    cd "$d" || exit 1
    git init -q                                  || exit 1
    git symbolic-ref HEAD refs/heads/main        || exit 1
    git config user.email t@example.com          || exit 1
    git config user.name t                       || exit 1
    git add -A >/dev/null 2>&1                   || exit 1
    git commit -qm base >/dev/null 2>&1          || exit 1
    git update-ref refs/remotes/origin/main HEAD || exit 1
  ) || return 1
  printf '%s' "$d"
}

require_repo() {   # $1 = candidate repo path, $2 = lane name
  if [ -z "${1:-}" ] || [ ! -d "$1/.git" ]; then
    echo "HARNESS_ERROR — fixture repo not built for $2 (setup failed; NOT a pass)"
    exit 1
  fi
}

# check_zone <name> <repo> <owners-file|""> <url> <push_zone_ok:0|1> <expect:block|pass> <cause-regex|""> <refline>
check_zone() {
  local name="$1" repo="$2" owners="$3" url="$4" pzok="$5" expect="$6" cause="$7"; shift 7
  local out rc got _pzsrc
  require_repo "$repo" "$name"
  _pzsrc="${owners:-$WORK/nonexistent-owners-file-for-zone-test}"
  out=$(printf '%s\n' "$@" | ( cd "$repo" && PUSH_ZONE_OWNERS="$_pzsrc" PUSH_ZONE_OK="$pzok" \
        bash templates/.git-hooks/pre-push origin "$url" 2>&1 )); rc=$?
  ALL_OUT="$ALL_OUT
$out"

  if printf '%s' "$out" | grep -qiE 'bad substitution|unbound variable|syntax error|command not found'; then
    echo "  ❌ $name — RUNTIME FAULT in the hook (aborted, not passed)"
    printf '%s\n' "$out" | grep -iE 'bad substitution|unbound|syntax error|command not found' | sed 's/^/       /' | head -3
    FAILED=$((FAILED+1)); return
  fi

  if [ "$rc" -ne 0 ]; then
    if printf '%s' "$out" | grep -qE 'FH (Push-Zone Gate|Destructive-Op Gate)'; then
      got=block
    else
      echo "  ❌ $name — blocked, but NOT by a named FH gate (harness reason ≠ finding)"
      printf '%s\n' "$out" | sed 's/^/       | /' | head -8
      FAILED=$((FAILED+1)); return
    fi
  else
    got=pass
  fi

  if [ "$got" != "$expect" ]; then
    echo "  ❌ $name — expected $expect, got $got"
    printf '%s\n' "$out" | sed 's/^/       | /' | head -10
    FAILED=$((FAILED+1)); return
  fi

  if [ -n "$cause" ] && ! printf '%s' "$out" | grep -qE "$cause"; then
    echo "  ❌ $name — verdict $got is correct but UNATTRIBUTED (missing: $cause)"
    printf '%s\n' "$out" | sed 's/^/       | /' | head -10
    FAILED=$((FAILED+1)); return
  fi

  echo "  ✅ $name (expected $expect)"
  PASSED=$((PASSED+1))
}

echo "[push-zone] known-pair anchor for the pre-push Push-Zone verdict (hook: $HOOK_SRC)"
echo ""

# Z0 — no owner-account list at all → UNCALIBRATED, plain push allowed.
R=$(newrepo); require_repo "$R" "Z0"
BASESHA=$(cd "$R" && git rev-parse HEAD)
NEWSHA=$(cd "$R" && printf 'x\n' >> a.txt && git commit -qam ff >/dev/null && git rev-parse HEAD)
check_zone "Z0 no owner-account list         → PASS " "$R" "" \
  "https://github.com/known-owner/repo.git" 0 pass 'push-zone: UNCALIBRATED' \
  "refs/heads/feat $NEWSHA refs/heads/feat $BASESHA"
rm -rf "$R"

# Z1 — owner IN the list, https → silent pass; the rest of the hook (confidentiality) still runs.
R=$(newrepo); require_repo "$R" "Z1"
BASESHA=$(cd "$R" && git rev-parse HEAD)
NEWSHA=$(cd "$R" && printf 'x\n' >> a.txt && git commit -qam ff >/dev/null && git rev-parse HEAD)
check_zone "Z1 owner IN list, https          → PASS " "$R" "$OWNERS_OK" \
  "https://github.com/known-owner/repo.git" 0 pass 'FH Pre-Publish' \
  "refs/heads/feat $NEWSHA refs/heads/feat $BASESHA"
rm -rf "$R"

# Z2 — owner OUT of the list, https → BLOCK, attributed, names the URL's (fictitious) owner.
R=$(newrepo); require_repo "$R" "Z2"
BASESHA=$(cd "$R" && git rev-parse HEAD)
NEWSHA=$(cd "$R" && printf 'x\n' >> a.txt && git commit -qam ff >/dev/null && git rev-parse HEAD)
check_zone "Z2 owner OUT of list, https      → BLOCK" "$R" "$OWNERS_OK" \
  "https://github.com/someone-else/repo.git" 0 block 'FH Push-Zone Gate' \
  "refs/heads/feat $NEWSHA refs/heads/feat $BASESHA"
if printf '%s' "$ALL_OUT" | grep -qF 'github.com/someone-else'; then
  echo "  ✅ Z2b block message names the URL's owner"; PASSED=$((PASSED+1))
else
  echo "  ❌ Z2b — block message did not name the URL's owner (someone-else)"; FAILED=$((FAILED+1))
fi
rm -rf "$R"

# Z3 — owner OUT of the list, scp-like ssh (git@github.com:owner/repo) → BLOCK.
R=$(newrepo); require_repo "$R" "Z3"
BASESHA=$(cd "$R" && git rev-parse HEAD)
NEWSHA=$(cd "$R" && printf 'x\n' >> a.txt && git commit -qam ff >/dev/null && git rev-parse HEAD)
check_zone "Z3 owner OUT of list, ssh scp    → BLOCK" "$R" "$OWNERS_OK" \
  "git@github.com:someone-else/repo.git" 0 block 'FH Push-Zone Gate' \
  "refs/heads/feat $NEWSHA refs/heads/feat $BASESHA"
rm -rf "$R"

# Z4 — remote host is not github.com → out of scope for this axis, pass allowed, says so.
R=$(newrepo); require_repo "$R" "Z4"
BASESHA=$(cd "$R" && git rev-parse HEAD)
NEWSHA=$(cd "$R" && printf 'x\n' >> a.txt && git commit -qam ff >/dev/null && git rev-parse HEAD)
check_zone "Z4 non-github host              → PASS " "$R" "$OWNERS_OK" \
  "https://ghe.example.com/x/y" 0 pass 'not github.com' \
  "refs/heads/feat $NEWSHA refs/heads/feat $BASESHA"
rm -rf "$R"

# Z5 — PUSH_ZONE_OK=1 override on an out-of-list push → allowed, conscious, LOGGED.
R=$(newrepo); require_repo "$R" "Z5"
BASESHA=$(cd "$R" && git rev-parse HEAD)
NEWSHA=$(cd "$R" && printf 'x\n' >> a.txt && git commit -qam ff >/dev/null && git rev-parse HEAD)
check_zone "Z5 PUSH_ZONE_OK=1 override       → PASS " "$R" "$OWNERS_OK" \
  "https://github.com/someone-else/repo.git" 1 pass 'PUSH_ZONE_OK=1' \
  "refs/heads/feat $NEWSHA refs/heads/feat $BASESHA"
LOG="$R/tracks/_meta/.push_zone_override_log"
if [ -f "$LOG" ] && grep -qF 'owner:someone-else' "$LOG"; then
  echo "  ✅ Z5b override logged to tracks/_meta/.push_zone_override_log"; PASSED=$((PASSED+1))
else
  echo "  ❌ Z5b override NOT logged (wanted a line inside $LOG)"; FAILED=$((FAILED+1))
fi
rm -rf "$R"

# Z6 — existing destructive verdict (branch DELETE, unique paths → REVIEW → BLOCK) still stands
#      AFTER a silent zone PASS. Same shape as the sibling suite's P2, through an owner-matching
#      github.com URL — proves the zone block, inserted near the TOP of the hook, does not shadow
#      or reorder the destructive checks further down.
R=$(newrepo); require_repo "$R" "Z6"
( cd "$R" && git checkout -q -b unique-work && printf 'only here\n' > unique.txt \
   && git add unique.txt && git commit -qm unique >/dev/null && git checkout -q main )
TIP=$(cd "$R" && git rev-parse unique-work)
check_zone "Z6 zone PASS, then BRANCH DELETE → BLOCK" "$R" "$OWNERS_OK" \
  "https://github.com/known-owner/repo.git" 0 block 'REVIEW: .* unique path' \
  "(delete) $ZERO refs/heads/unique-work $TIP"
rm -rf "$R"

# ── Residency: the owner-list's OTHER entries must never appear in any captured output ─────────
if printf '%s' "$ALL_OUT" | grep -qF 'acme-shared-org'; then
  echo "  ❌ RESIDENCY — the fixture owner-list's second entry leaked into hook output"
  FAILED=$((FAILED+1))
else
  echo "  ✅ RESIDENCY — owner-list content never appears in any captured hook output"
  PASSED=$((PASSED+1))
fi

echo ""
# ── Z7–Z14 (cross-family codex gpt-5.5, 2026-09-05): the first draft accepted three literal URL
# prefixes and read every other github.com shape as "unrecognized → allow" — four real shapes were
# failing OPEN; an inline comment in the owner list authorised pushes; CRLF / trailing slash blocked
# the operator's own remotes. Each lane below is one of those exact inputs.
OWNERS_CRLF="$WORK/owners-crlf.txt";   printf 'known-owner\r\nacme-shared-org\r\n' > "$OWNERS_CRLF"
OWNERS_COMMENT="$WORK/owners-comment.txt"; printf 'known-owner   # someone-else is NOT allowed\nacme-shared-org\n' > "$OWNERS_COMMENT"
OWNERS_SLASH="$WORK/owners-slash.txt"; printf 'known-owner/\nacme-shared-org\n' > "$OWNERS_SLASH"

_zone_ff_lane() {  # $1=id $2=desc $3=owners $4=url $5=expect $6=cause
  local R BASESHA NEWSHA
  R=$(newrepo); require_repo "$R" "$1"
  BASESHA=$(cd "$R" && git rev-parse HEAD)
  NEWSHA=$(cd "$R" && printf 'x\n' >> a.txt && git commit -qam ff >/dev/null && git rev-parse HEAD)
  check_zone "$1 $2" "$R" "$3" "$4" 0 "$5" "$6" "refs/heads/feat $NEWSHA refs/heads/feat $BASESHA"
  rm -rf "$R"
}
_zone_ff_lane Z7  "userinfo https (user@github.com), owner OUT → BLOCK" "$OWNERS_OK" "https://user@github.com/someone-else/repo.git" block 'FH Push-Zone Gate'
_zone_ff_lane Z8  "https with :443 port, owner OUT → BLOCK"           "$OWNERS_OK" "https://github.com:443/someone-else/repo.git" block 'FH Push-Zone Gate'
_zone_ff_lane Z9  "ssh:// with :22 port, owner OUT → BLOCK"           "$OWNERS_OK" "ssh://git@github.com:22/someone-else/repo.git" block 'FH Push-Zone Gate'
_zone_ff_lane Z10 "scp form with leading slash (git@github.com:/o/r), owner OUT → BLOCK" "$OWNERS_OK" "git@github.com:/someone-else/repo.git" block 'FH Push-Zone Gate'
_zone_ff_lane Z11 "inline comment in owner list must NOT authorise the commented name → BLOCK" "$OWNERS_COMMENT" "https://github.com/someone-else/repo.git" block 'FH Push-Zone Gate'
_zone_ff_lane Z12 "CRLF owner list, owner IN → pass (no over-block)"  "$OWNERS_CRLF" "https://github.com/known-owner/repo.git" pass ''
_zone_ff_lane Z13 "trailing-slash owner entry, owner IN → pass"       "$OWNERS_SLASH" "https://github.com/known-owner/repo.git" pass ''
_zone_ff_lane Z13b "uppercase host/owner in URL, owner IN → pass (case-insensitive)" "$OWNERS_OK" "https://GitHub.com/Known-Owner/repo.git" pass ''
# Z14 — $2 is a bare remote NAME (alias/insteadOf edge): the hook must resolve it, not read it as a host.
R=$(newrepo); require_repo "$R" "Z14"
( cd "$R" && git remote add origin https://github.com/someone-else/repo.git ) 2>/dev/null
BASESHA=$(cd "$R" && git rev-parse HEAD)
NEWSHA=$(cd "$R" && printf 'x\n' >> a.txt && git commit -qam ff >/dev/null && git rev-parse HEAD)
check_zone "Z14 \$2 is the remote NAME → resolved via git remote get-url → BLOCK" "$R" "$OWNERS_OK" \
  "origin" 0 block 'FH Push-Zone Gate' "refs/heads/feat $NEWSHA refs/heads/feat $BASESHA"
rm -rf "$R"

echo "── session-close ①-f wiring (scripts/session_close_check.sh) ──"
if [ ! -f "$SCC_SRC" ]; then
  echo "HARNESS_ERROR — session_close_check.sh not found at $SCC_SRC"; FAILED=$((FAILED+1))
else
  SR="$(fh_fixture_root "$(mktemp -d)")" || exit 1
  mkdir -p "$SR/tracks/_meta" "$SR/scripts" "$SR/.claude/rules"
  cp "$REPO_ROOT/scripts/push_zone_check.sh" "$SR/scripts/push_zone_check.sh" 2>/dev/null
  chmod +x "$SR/scripts/push_zone_check.sh" 2>/dev/null
  ( cd "$SR" && git init -q && git symbolic-ref HEAD refs/heads/main \
      && git config user.email t@example.com && git config user.name t \
      && git commit -q --allow-empty -m base >/dev/null ) >/dev/null 2>&1

  if [ -x "$SR/scripts/push_zone_check.sh" ]; then
    SC_OUT=$(PUSH_ZONE_OWNERS="$OWNERS_OK" bash "$SCC_SRC" "$SR" 2>&1)
    if printf '%s' "$SC_OUT" | grep -qE '①-f push-zone: '; then
      echo "  ✅ ①-f prints advisory-prefixed push_zone_check.sh output when both files exist"
      PASSED=$((PASSED+1))
    else
      echo "  ❌ ①-f did not print the expected advisory prefix"; FAILED=$((FAILED+1))
    fi
    # RESIDENCY (codex #9, 2026-09-05): the enumerator prints owner-account names, and a close's
    # output lands in transcripts and session cards. ①-f therefore prints COUNTS only — the decoy
    # list entry must never appear, and the summary line must.
    if printf '%s' "$SC_OUT" | grep -qF 'acme-shared-org'; then
      echo "  ❌ ①-f leaked an owner-account list entry into the close output"; FAILED=$((FAILED+1))
    else
      echo "  ✅ ①-f withholds owner-account names (counts only)"; PASSED=$((PASSED+1))
    fi
    if printf '%s' "$SC_OUT" | grep -qE '①-f push-zone: [0-9]+ repo\(s\) enumerated'; then
      echo "  ✅ ①-f prints the enumeration summary (repo count · outside-list count)"; PASSED=$((PASSED+1))
    else
      echo "  ❌ ①-f summary line missing"; FAILED=$((FAILED+1))
    fi
  else
    echo "  ❌ Z-SC setup — fixture push_zone_check.sh not executable"; FAILED=$((FAILED+1))
  fi

  # Owner-account list absent → UNCALIBRATED, one line, never silent.
  SC_OUT2=$(PUSH_ZONE_OWNERS="$SR/no-such-owners-file" bash "$SCC_SRC" "$SR" 2>&1)
  if printf '%s' "$SC_OUT2" | grep -qE '①-f push-zone UNCALIBRATED'; then
    echo "  ✅ ①-f UNCALIBRATED when the owner-account list is absent"; PASSED=$((PASSED+1))
  else
    echo "  ❌ ①-f did not report UNCALIBRATED with no owner-account list"; FAILED=$((FAILED+1))
  fi
  rm -rf "$SR"
fi

echo ""
echo "[push-zone] $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
