#!/usr/bin/env bash
# utterance_skill_probe.sh — MEASUREMENT ONLY. Injects nothing, blocks nothing, decides nothing.
#
# ── WHY THIS EXISTS (2026-08-27, operator proposal) ──────────────────────────────────────────
# Identity ④ (프런티어 답습) triggers on: ① the operator's utterance is a request/question/proposal
# ∧ ② the session is even slightly unsure. CLAUDE.md §Mechanization Boundary already splits these:
# «①은 채널이고 ②는 판정». ① is mechanizable; ② must stay with the session or the check starts
# asserting a conclusion.
#
# The operator's proposal mechanizes ① exactly: *a skill the user's utterance naturally induced*.
# `PreToolUse(Skill)` alone CANNOT see that — it sees the tool call, not whether an utterance or an
# internal chain caused it. Two hooks decide it:
#     UserPromptSubmit  --mark   → write a fresh-utterance token
#     PreToolUse(Skill) --check  → token alive? this call is utterance-induced. consume it (once).
# One utterance calling five skills therefore marks only the FIRST. Over-firing is structurally
# excluded rather than tuned away.
#
# ── WHY MEASUREMENT-ONLY, FOR NOW ────────────────────────────────────────────────────────────
# We do NOT yet know which skills are the real T2 («짓기 시작») moment, nor how often this fires.
# Writing the prompt text now would be guessing, and the wired-then-green-without-measuring trap is
# the one this session already stepped in three times. So: log first, author the wording later, on
# the log. `prior_art_prompt.sh`'s own header warns that an over-firing hook «금지로 읽히면
# 무시당한다» — that failure is unrecoverable (once dismissed, always dismissed), so the frequency
# has to be known BEFORE anything is injected.
#
# ── SAFETY PROPERTIES (all three are load-bearing) ───────────────────────────────────────────
#   1. NOTHING on stdout. PreToolUse stdout is parsed as JSON; junk there is a live hazard.
#   2. exit 0 unconditionally, on every path including its own errors.
#   3. python3 missing / unparseable input / unwritable log → silently do nothing. A measurement
#      probe that breaks the session it measures is worse than no measurement.
#
# ── SESSION SCOPING (not optional here) ──────────────────────────────────────────────────────
# The operator runs parallel sessions on one checkout. A single shared token would let session A's
# utterance be consumed by session B's skill call, which would fabricate «utterance-induced» rows.
# Token is keyed by session_id when the hook contract supplies one; when it does not, the row is
# logged as `sid=NONE` so the gap is visible in the data instead of silently corrupting it.
#
# test:  printf '{"tool_name":"Skill","tool_input":{}}' | bash scripts/utterance_skill_probe.sh --check
set -u
MODE="${1:---check}"
RAW=$(cat 2>/dev/null || true)
command -v python3 >/dev/null 2>&1 || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LOG="$ROOT/tracks/_meta/utterance_skill_probe.log"
[ -d "$ROOT/tracks/_meta" ] || exit 0

printf '%s' "$RAW" | MODE="$MODE" LOG="$LOG" python3 -c '
import json, os, sys, time
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
mode = os.environ.get("MODE", "--check")
log  = os.environ["LOG"]
sid  = str(d.get("session_id") or "NONE")[:16]
tok  = os.path.join(os.environ.get("TMPDIR", "/tmp"), "fh_utt_token_" + sid)
now  = time.strftime("%Y-%m-%dT%H:%M:%S")

def note(line):
    try:
        with open(log, "a") as f: f.write(line + "\n")
    except Exception:
        pass

if mode == "--mark":
    try:
        open(tok, "w").write(now)
    except Exception:
        pass
    sys.exit(0)

if d.get("tool_name") != "Skill":
    sys.exit(0)

ti = d.get("tool_input") or {}
# The Skill tool_input shape is NOT in the public docs (verified 2026-08-27), so record the KEYS to
# learn it. Values are not logged — an arg can carry arbitrary user text and this log syncs to a
# store; keys are enough to find the name field, and the named field alone is enough to classify.
keys = ",".join(sorted(ti.keys())) if isinstance(ti, dict) else type(ti).__name__
name = ""
for k in ("skill", "skill_name", "name", "command"):
    v = ti.get(k) if isinstance(ti, dict) else None
    if isinstance(v, str) and v:
        name = v[:60]; break

induced = os.path.exists(tok)
if induced:
    try: os.remove(tok)          # consume: only the FIRST skill of an utterance counts
    except Exception: pass

note("%s sid=%s induced=%s skill=%s keys=[%s]"
     % (now, sid, "YES" if induced else "no", name or "?", keys))
' 2>/dev/null || true
exit 0
