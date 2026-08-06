#!/usr/bin/env bash
# Known pairs for scripts/version_lockstep_check.sh.
#
# The lane this suite exists to prevent: on 2026-08-06 a 1.4.88 → 1.4.89 bump edited the FIRST
# marketplace plugin entry and left the SECOND at the old version. `test_tag_version_lanes.sh`
# reported 8/8 PASS through it — that lane compares the git tag to package.json and never opens
# marketplace.json. The drift was caught by an ad-hoc `sort | uniq -c`. Luck is not a floor.
#
# Every lane runs against a THROWAWAY fixture tree, never against this repo, so the suite is
# hermetic: a real bump in progress can neither turn it green nor turn it red.

set -uo pipefail
CHECK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/version_lockstep_check.sh"
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/fh_lockstep.XXXXXX")
trap 'rm -rf "$TMPROOT"' EXIT
PASS=0; FAIL=0

_fixture() {  # $1=name $2=pkg_ver $3=meta_ver $4=commons_ver $5=mk_entry0 $6=mk_entry1
  local T="$TMPROOT/$1"
  mkdir -p "$T/.claude-plugin" "$T/plugins/fh-meta/.claude-plugin" "$T/plugins/fh-commons/.claude-plugin"
  printf '{"name":"fh","version":"%s"}\n' "$2" > "$T/package.json"
  printf '{"name":"fh-meta","version":"%s"}\n' "$3" > "$T/plugins/fh-meta/.claude-plugin/plugin.json"
  printf '{"name":"fh-commons","version":"%s"}\n' "$4" > "$T/plugins/fh-commons/.claude-plugin/plugin.json"
  printf '{"plugins":[{"name":"fh-meta","version":"%s"},{"name":"fh-commons","version":"%s"}]}\n' \
    "$5" "$6" > "$T/.claude-plugin/marketplace.json"
  printf '%s' "$T"
}

_expect() {  # $1=label $2=expected_rc $3=repo ; also captures OUT
  OUT=$(bash "$CHECK" "$3" 2>&1); local rc=$?
  if [ "$rc" = "$2" ]; then echo "  ✅ $1 (rc=$rc)"; PASS=$((PASS+1))
  else echo "  ❌ $1 — rc=$rc, expected=$2"; printf '%s\n' "$OUT" | sed 's/^/       │ /'; FAIL=$((FAIL+1)); fi
}
_says() {  # $1=label $2=pattern $3=expected_hit(1|0)
  local h=0; printf '%s\n' "$OUT" | grep -q -- "$2" && h=1
  if [ "$h" = "$3" ]; then echo "  ✅ $1"; PASS=$((PASS+1))
  else echo "  ❌ $1 — hit=$h, expected=$3"; printf '%s\n' "$OUT" | sed 's/^/       │ /'; FAIL=$((FAIL+1)); fi
}

echo "══ version lockstep known pairs ══"

# KN — everything aligned. The control: without it, a checker that always reported DRIFT would
# still pass every positive lane below.
_expect "KN  all five strings aligned → exit 0" 0 "$(_fixture kn 1.4.89 1.4.89 1.4.89 1.4.89 1.4.89)"
_says   "KN  → names the count it actually checked" "4 shipped version string" 1

# KP-1 — the measured miss, byte for byte: second marketplace entry left behind.
_expect "KP-1 second marketplace entry stale → exit 1" 1 "$(_fixture kp1 1.4.89 1.4.89 1.4.89 1.4.89 1.4.88)"
_says   "KP-1 → names the offending entry by index+name" "plugins\[1\] fh-commons" 1
_says   "KP-1 → reports both versions, not just 'mismatch'" "1.4.88  (package.json = 1.4.89)" 1

# KP-2 — a plugin.json left behind. This is the shape the tag lane also cannot see.
_expect "KP-2 plugin.json stale → exit 1" 1 "$(_fixture kp2 1.4.89 1.4.88 1.4.89 1.4.89 1.4.89)"
_says   "KP-2 → names the file" "plugins/fh-meta/.claude-plugin/plugin.json" 1

# KP-3 — the reverse direction: package.json bumped alone. Same defect, opposite author error.
_expect "KP-3 only package.json bumped → exit 1" 1 "$(_fixture kp3 1.5.0 1.4.89 1.4.89 1.4.89 1.4.89)"
_says   "KP-3 → all four downstream strings flagged" "4 of 4" 1

# HARNESS-ERROR — an instrument that could not look has not looked. These must be a THIRD state,
# never folded into PASS: this gate guards `npm publish`, an irreversible surface.
T=$(_fixture he1 1.4.89 1.4.89 1.4.89 1.4.89 1.4.89); rm "$T/.claude-plugin/marketplace.json" "$T"/plugins/*/.claude-plugin/plugin.json
_expect "HE-1 no manifests at all → exit 2, NOT 0" 2 "$T"
_says   "HE-1 → says alignment is UNKNOWN, not aligned" "UNKNOWN, not aligned" 1

T=$(_fixture he2 1.4.89 1.4.89 1.4.89 1.4.89 1.4.89); printf '{ broken' > "$T/.claude-plugin/marketplace.json"
_expect "HE-2 unparseable manifest → exit 2, NOT 0" 2 "$T"

T=$(_fixture he3 1.4.89 1.4.89 1.4.89 1.4.89 1.4.89); rm "$T/package.json"
_expect "HE-3 missing package.json → exit 2, NOT 0" 2 "$T"

# A manifest present but carrying no version at all is absence, not agreement.
T=$(_fixture he4 1.4.89 1.4.89 1.4.89 1.4.89 1.4.89); printf '{"name":"fh-meta"}\n' > "$T/plugins/fh-meta/.claude-plugin/plugin.json"
_expect "HE-4 manifest with no version → exit 2, NOT 0" 2 "$T"
_says   "HE-4 → says which file carries none" "carries no version string" 1

echo
echo "──────────────────────────────────────────────"
if [ "$FAIL" -gt 0 ]; then
  echo "VERSION-LOCKSTEP LANES: FAIL ($PASS pass · $FAIL fail)"; exit 1
fi
echo "VERSION-LOCKSTEP LANES: PASS ($PASS/$PASS)"
