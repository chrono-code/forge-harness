#!/usr/bin/env bash
# test_stale_clone_guard_lanes.sh — known pairs for scripts/stale_clone_guard.sh
#
# Fixture: a bare origin + clone A (pushes 2 extra commits) + clone B (stays behind).
# Lanes run with FH_STALE_CLONE_NO_FETCH=1 (remote state already local via clone-time fetch is
# NOT enough — B must explicitly fetch to know it is behind, so the fixture fetches for it; the
# no-fetch env only skips the guard's own network call) and a private marker dir per lane.

set -u
G="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stale_clone_guard.sh"
pass=0; fail=0
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

payload() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1]}}))' "$1"; }

# run <label> <expect HIT|CLEAN> <file_path>
run() {
  local label="$1" want="$2" fpath="$3" got out
  local mdir; mdir=$(mktemp -d "$WORK/marker.XXXXXX")
  out=$(payload "$fpath" | FH_STALE_CLONE_NO_FETCH=1 FH_STALE_CLONE_MARKER_DIR="$mdir" bash "$G" 2>&1)
  if printf '%s' "$out" | grep -q 'STALE-CLONE'; then got=HIT; else got=CLEAN; fi
  if [ "$got" = "$want" ]; then
    printf '  ✅ %-52s %s (expected %s)\n' "$label" "$got" "$want"; pass=$((pass+1))
  else
    printf '  ❌ %-52s %s (expected %s)\n     out: %s\n' "$label" "$got" "$want" "$out"; fail=$((fail+1))
  fi
}

echo "[stale-clone-guard] fixture build"
git init -q --bare "$WORK/origin.git"
# Default-branch portability (GPT pass): pin the bare repo's HEAD to main BEFORE cloning B —
# on master-default machines clone B otherwise has no checked-out branch and upstream setup fails.
git --git-dir="$WORK/origin.git" symbolic-ref HEAD refs/heads/main
git clone -q "$WORK/origin.git" "$WORK/A" 2>/dev/null
( cd "$WORK/A" && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m base \
  && git push -q origin HEAD:main && git branch -q --set-upstream-to=origin/main ) 2>/dev/null
git clone -q "$WORK/origin.git" "$WORK/B" 2>/dev/null
( cd "$WORK/B" && git branch -q --set-upstream-to=origin/main ) 2>/dev/null
( cd "$WORK/A" && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m one \
  && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m two && git push -q origin HEAD:main ) 2>/dev/null
( cd "$WORK/B" && git fetch -q origin ) 2>/dev/null   # B now KNOWS it is behind 2

echo "[stale-clone-guard] known pairs"
run "behind clone fires"                  HIT   "$WORK/B/newfile.py"
run "up-to-date clone stays silent"       CLEAN "$WORK/A/newfile.py"
run "non-repo path stays silent"          CLEAN "$WORK/newfile.py"
run "new nested dir in behind clone"      HIT   "$WORK/B/sub/dir/newfile.py"

# Creation-only scope: overwriting an EXISTING file must not fire (GPT pass).
touch "$WORK/B/existing.py"
run "overwrite of existing file is CLEAN" CLEAN "$WORK/B/existing.py"

# Non-origin remote name: @{u}-derived remote, no hardcoded origin (GPT pass).
git clone -q "$WORK/origin.git" "$WORK/C" 2>/dev/null
( cd "$WORK/C" && git remote rename origin up && git fetch -q up \
  && git branch -q --set-upstream-to=up/main && git reset -q --hard HEAD~2 ) 2>/dev/null  # noqa: destructive-op (fixture repo)
run "non-origin remote name still fires"  HIT   "$WORK/C/newfile.py"

# Throttle: SAME marker dir, two calls — second must be silent.
mdir=$(mktemp -d "$WORK/marker.throttle")
o1=$(payload "$WORK/B/x.py" | FH_STALE_CLONE_NO_FETCH=1 FH_STALE_CLONE_MARKER_DIR="$mdir" bash "$G" 2>&1)
o2=$(payload "$WORK/B/y.py" | FH_STALE_CLONE_NO_FETCH=1 FH_STALE_CLONE_MARKER_DIR="$mdir" bash "$G" 2>&1)
if printf '%s' "$o1" | grep -q STALE-CLONE && [ -z "$o2" ]; then
  printf '  ✅ %-52s OK\n' "throttle: 2nd call same repo+day silent"; pass=$((pass+1))
else
  printf '  ❌ %-52s o1=%s o2=%s\n' "throttle: 2nd call same repo+day silent" "$o1" "$o2"; fail=$((fail+1))
fi

# Contract: HIT emits one JSON object with both channels and no permissionDecision.
mdir=$(mktemp -d "$WORK/marker.json")
jo=$(payload "$WORK/B/z.py" | FH_STALE_CLONE_NO_FETCH=1 FH_STALE_CLONE_MARKER_DIR="$mdir" bash "$G" 2>/dev/null)
if printf '%s' "$jo" | python3 -c '
import json,sys
d=json.load(sys.stdin)
h=d["hookSpecificOutput"]
assert h["hookEventName"]=="PreToolUse"
assert "STALE-CLONE" in h["additionalContext"] and "STALE-CLONE" in d["systemMessage"]
assert "permissionDecision" not in h and "permissionDecision" not in d
' 2>/dev/null; then
  printf '  ✅ %-52s OK\n' "C1 JSON dual-channel, no permissionDecision"; pass=$((pass+1))
else
  printf '  ❌ %-52s out=%s\n' "C1 JSON dual-channel, no permissionDecision" "$jo"; fail=$((fail+1))
fi

# Fail-open lanes.
o=$(printf '%s' 'not json' | bash "$G" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$o" ]; then
  printf '  ✅ %-52s OK\n' "malformed payload: silent exit 0"; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s\n' "malformed payload: silent exit 0" "$rc" "$o"; fail=$((fail+1))
fi
o=$(python3 -c 'import json;print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":"/x"}}))' | bash "$G" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$o" ]; then
  printf '  ✅ %-52s OK\n' "non-Write tool: silent"; pass=$((pass+1))
else
  printf '  ❌ %-52s rc=%s out=%s\n' "non-Write tool: silent" "$rc" "$o"; fail=$((fail+1))
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "[stale-clone-guard] ✅ all $pass known pairs hold"; exit 0
else
  echo "[stale-clone-guard] ❌ $fail/$((pass+fail)) lanes failed"; exit 1
fi
