#!/usr/bin/env bash
# Known-pair lanes for scripts/utterance_skill_probe.sh (identity ④ measurement channel).
#
# 🟥 WHAT THESE PIN, and why each one is load-bearing:
#   SAFE-1/2  the probe injects NOTHING on stdout and always exits 0. PreToolUse stdout is parsed
#             as JSON by Claude Code; a stray byte there is a live hazard on every skill call.
#   DISC      the utterance/internal discriminator actually discriminates — without the induced=no
#             arm, "everything is utterance-induced" would look identical to a working probe.
#   CONSUME   one utterance marks only the FIRST skill. This is what structurally excludes the
#             over-firing that `prior_art_prompt.sh`'s own header warns is unrecoverable
#             («금지로 읽히면 무시당한다» — once dismissed, always dismissed).
#   ISOLATE   the operator runs parallel sessions on one checkout. A shared token would let session
#             A's utterance be consumed by session B's skill call and FABRICATE rows. This arm is
#             the reason the token is session-keyed at all.
#   CTRL      a non-Skill tool writes no row — proves rows are selected by tool_name, not emitted
#             for everything that passes through.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
P="$ROOT/scripts/utterance_skill_probe.sh"
PASS=0; FAIL=0
ok(){ printf '  ✅ %s\n' "$1"; PASS=$((PASS+1)); }
no(){ printf '  ❌ %s\n' "$1"; FAIL=$((FAIL+1)); }

[ -f "$P" ] || { echo "FAIL  subject 부재: $P — ④ 계측 채널이 사라졌다"; exit 1; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/tracks/_meta"
LOG="$T/tracks/_meta/utterance_skill_probe.log"
run(){ CLAUDE_PROJECT_DIR="$T" TMPDIR="$T" bash "$P" "$@"; }
mark(){ printf '{"session_id":"%s"}' "$1" | run --mark; }
call(){ printf '{"tool_name":"%s","session_id":"%s","tool_input":{"skill":"%s"}}' "${3:-Skill}" "$1" "$2" | run --check; }
# 🟥 NO `|| echo 0` HERE. `grep -c` PRINTS "0" and EXITS 1 on no-match, so the fallback appends a
# SECOND line, the value becomes "0\n0", and `[ -eq ]` dies with 'integer expression expected' —
# on stderr only, so the guarded branch is silently skipped. That is the pipefail-fallback disarm
# ([[feedback_pipefail_fallback_disarms_guard]]) that scripts/session_close_check.sh documents and
# the scanner's S5 probe exists to catch. First draft of THIS file used `|| echo 0` and the CTRL
# lane died in exactly that way — written down rather than quietly corrected, because knowing the
# class did not prevent it. Capture, then sanitize.
_num(){ local n; n=$(grep -c "$1" "$LOG" 2>/dev/null); n=${n:-0}
        case "$n" in *[!0-9]*) n=0 ;; esac; printf '%s' "$n"; }
rows(){ _num "skill=$1 "; }
ind(){ local n; n=$(grep "skill=$1 " "$LOG" 2>/dev/null | grep -c "induced=$2"); n=${n:-0}
       case "$n" in *[!0-9]*) n=0 ;; esac; printf '%s' "$n"; }

echo "utterance-skill probe known-pair"

# SAFE — the two properties that make this safe to wire at all
out=$(call sX s_safe); rc=$?
[ -z "$out" ] && ok "SAFE-1 stdout is empty (PreToolUse parses stdout as JSON)" \
              || no "SAFE-1 probe wrote to stdout: [$out] — this corrupts the hook contract"
[ "$rc" = "0" ] && ok "SAFE-2 exit 0" || no "SAFE-2 exit $rc (must never be non-zero)"
printf 'not json at all' | run --check >/dev/null 2>&1; rc=$?
[ "$rc" = "0" ] && ok "SAFE-3 unparseable input still exits 0" || no "SAFE-3 exit $rc on junk input"

# DISC / CONSUME — the discriminator and the once-per-utterance property
call sA s_noMark >/dev/null
[ "$(ind s_noMark no)" -eq 1 ] && ok "DISC-neg no token → induced=no" || no "DISC-neg expected induced=no"
mark sA; call sA s_marked >/dev/null
[ "$(ind s_marked YES)" -eq 1 ] && ok "DISC-pos after a mark → induced=YES" || no "DISC-pos expected induced=YES"
call sA s_second >/dev/null
[ "$(ind s_second no)" -eq 1 ] && ok "CONSUME second skill of the same utterance → induced=no" \
                               || no "CONSUME token was not consumed — this is the over-fire path"

# ISOLATE — parallel sessions must not eat each other's token
mark sA; call sB s_peer >/dev/null
[ "$(ind s_peer no)" -eq 1 ] && ok "ISOLATE peer session does not consume this session's token" \
                             || no "ISOLATE peer consumed the token — rows would be fabricated"
call sA s_mine >/dev/null
[ "$(ind s_mine YES)" -eq 1 ] && ok "ISOLATE the owner's token survived the peer call" \
                              || no "ISOLATE owner's token was destroyed by a peer"

# CTRL — rows are selected, not emitted for everything
call sA s_bash Bash >/dev/null
[ "$(rows s_bash)" -eq 0 ] && ok "CTRL a non-Skill tool writes no row" || no "CTRL logged a non-Skill tool"

# CTRL-2 — a missing log dir must not break the caller (degrade = do nothing, never fail)
out=$(CLAUDE_PROJECT_DIR="$T/nosuchroot" TMPDIR="$T" bash "$P" --check <<<'{"tool_name":"Skill","tool_input":{}}'); rc=$?
{ [ -z "$out" ] && [ "$rc" = "0" ]; } && ok "CTRL-2 unwritable/absent log root → silent no-op, exit 0" \
                                      || no "CTRL-2 broke on an absent log root (stdout=[$out] rc=$rc)"

echo "utterance-skill probe: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
