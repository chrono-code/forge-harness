#!/usr/bin/env bash
# finding_verifier.sh — the wrapper finding_verify.py's --verifier contract asks for, and which did
# not exist. Reads findings JSONL on stdin, writes verdict JSONL on stdout:
#     {"id","verdict":"confirmed|false-positive|needs-debate","why"}
# With --audit it answers the drop-audit protocol instead:
#     {"id","verdict":"correct-drop|wrong-drop|uncertain","why"}
#
# WHY THIS EXISTS: finding_verify.py runs whatever shell command you hand it. Until this file, the
# only commands that satisfied its protocol were the hardcoded stubs inside the lane suite, so the
# pipeline could only ever report status=UNVERIFIED (rc=3) against real findings. A pipeline whose
# only live path is its own fixture is not wired (CLAUDE.md §built-but-not-wired).
#
# 🟥 THE VERIFIER MUST SEE THE CODE, NOT ONLY THE CLAIM. A verdict on "is this finding real" that is
# reached from the claim text alone measures plausibility, not truth — the model agrees with a
# well-written wrong claim. So --target is REQUIRED and its content is put in front of the model.
#
# EXIT  0 answered · 2 usage · 3 the CLI failed or produced no parsable verdict (caller degrades;
#       finding_verify.py turns an empty answer into `unverified`, never into a silent pass)
set -uo pipefail

CODEX="${FH_CODEX_BIN:-$(command -v codex 2>/dev/null || echo "$HOME/.npm-global/bin/codex")}"
AGY="${FH_AGY_BIN:-$(command -v agy 2>/dev/null || echo "$HOME/.local/bin/agy")}"

FAMILY=""; TARGET=""; MODE="verify"; KEEP=""
usage() { echo "usage: finding_verifier.sh --family codex|gemini --target <file> [--audit] [--keep <dir>]" >&2; exit 2; }
# `shift 2` with only one word left FAILS and consumes nothing, so the loop spins forever. Under
# `set -uo pipefail` (no errexit) nothing stops it. codex reproduced a hang on a trailing --family.
need() { [ $# -ge 2 ] || { echo "finding_verifier: $1 needs a value" >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --family) need "$@"; FAMILY="$2"; shift 2 ;;
    --target) need "$@"; TARGET="$2"; shift 2 ;;
    --audit)  MODE="audit"; shift ;;
    --keep)   need "$@"; KEEP="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$FAMILY" ] || usage
# `-f` is a TYPE test, not a readability test: an unreadable regular file passes it, the later `cat`
# fails silently, and the model then judges claims WITHOUT the source — which is the one thing the
# header above says must never happen. Test readability, and check the read itself below.
[ -n "$TARGET" ] && [ -f "$TARGET" ] && [ -r "$TARGET" ] \
  || { echo "finding_verifier: --target must name a readable file" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "finding_verifier: mktemp failed" >&2; exit 3; }
cleanup() { [ -n "$KEEP" ] && cp "$WORK"/* "$KEEP"/ 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

cat > "$WORK/findings.jsonl"
if [ ! -s "$WORK/findings.jsonl" ]; then exit 0; fi   # nothing asked, nothing to answer

if [ "$MODE" = "verify" ]; then
  HEAD='You are an independent verifier from a different model family than the reviewer who wrote the
claims below. For EACH claim decide whether it is real, judged against the file itself.

Output ONLY JSON Lines, one object per claim id, nothing else — no prose, no code fences:
{"id":"<the id verbatim>","verdict":"confirmed|false-positive|needs-debate","why":"<one line, cite the line number you checked>"}

confirmed      = you read the cited location and the described failure can actually occur there.
false-positive = the location does not say what the claim says, or the failure cannot occur.
needs-debate   = it depends on a caller or config you cannot see from this file alone.

Answer for EVERY id. Do not invent ids. Do not add findings of your own.'
else
  HEAD='You are auditing DELETIONS made by a different reviewer. Each record below is a claim that was
dropped as a false positive. For EACH one decide whether dropping it was right, judged against the file.

Output ONLY JSON Lines, one object per id, nothing else — no prose, no code fences:
{"id":"<the id verbatim>","verdict":"correct-drop|wrong-drop|uncertain","why":"<one line, cite the line number you checked>"}

correct-drop = the claim really was wrong; deleting it was right.
wrong-drop   = the claim was true and was deleted in error (it will be reinstated).
uncertain    = you cannot tell from this file alone.

Answer for EVERY id. A drop you cannot justify is not "correct" by default.'
fi

{ printf '%s\n\n===== CLAIMS =====\n' "$HEAD"; cat "$WORK/findings.jsonl"
  printf '\n===== FILE: %s =====\n' "$(basename "$TARGET")"; cat "$TARGET"; } > "$WORK/prompt.txt" \
  || { echo "finding_verifier: could not build the prompt (source unreadable?)" >&2; exit 3; }
# A prompt that does not actually contain the file is a verdict reached from the claim text alone.
if ! grep -q "===== FILE: $(basename "$TARGET") =====" "$WORK/prompt.txt"; then
  echo "finding_verifier: source did not reach the prompt — refusing to ask" >&2; exit 3
fi

case "$FAMILY" in
  codex)  "$CODEX" exec --sandbox read-only --skip-git-repo-check -m gpt-6-astra \
            -c model_reasoning_effort="high" < "$WORK/prompt.txt" > "$WORK/raw.txt" 2>"$WORK/err.txt" ;;
  gemini) "$AGY" --model gemini-3.8-flash-high --output-format text --print-timeout 5m \
            -p "$(cat "$WORK/prompt.txt")" < /dev/null > "$WORK/raw.txt" 2>"$WORK/err.txt" ;;
  *) echo "finding_verifier: unknown family '$FAMILY' (codex|gemini)" >&2; exit 2 ;;
esac
RC=$?

# The CLI's own exit code is not the WHOLE verdict — codex has exited non-zero while still printing
# usable output, and zero while printing none — but the first draft used it for nothing at all, which
# made the "cli failed" guard decorative (cross-family finding, 2026-09-09). It is now one of two
# inputs: a non-zero CLI that nevertheless answered EVERY claim asked is reported and allowed; a
# non-zero CLI that answered only some is a degraded run (exit 3), because the missing answers and the
# crash have the same cause and "fewer verdicts" would otherwise read as "fewer problems".
ASKED=$(grep -c '^{' "$WORK/findings.jsonl" 2>/dev/null); ASKED=${ASKED:-0}
MODE="$MODE" /usr/bin/python3 - "$WORK/raw.txt" <<'PY'
import json, os, sys
allowed = (("confirmed", "false-positive", "needs-debate") if os.environ["MODE"] == "verify"
           else ("correct-drop", "wrong-drop", "uncertain"))
n = 0
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    line = line.strip().lstrip("﻿")
    if not line.startswith("{"):
        continue                       # tolerate banners and fences, same as finding_fleet.sh
    try:
        d = json.loads(line)
    except json.JSONDecodeError:
        continue
    if not d.get("id") or d.get("verdict") not in allowed:
        continue                       # an out-of-enum verdict is dropped, never coerced
    n += 1
    print(json.dumps({"id": d["id"], "verdict": d["verdict"], "why": d.get("why", "")},
                     ensure_ascii=False))
open(os.path.join(os.path.dirname(sys.argv[1]), "n_answered"), "w").write(str(n))
sys.exit(0 if n else 3)
PY
PRC=$?
if [ "$PRC" -ne 0 ]; then
  echo "finding_verifier: family=$FAMILY mode=$MODE cli_rc=$RC — no parsable verdict" >&2
  head -c 400 "$WORK/err.txt" >&2 2>/dev/null
  exit 3
fi
ANSWERED=$(cat "$WORK/n_answered" 2>/dev/null); ANSWERED=${ANSWERED:-0}
if [ "$RC" -ne 0 ] && [ "$ANSWERED" -lt "$ASKED" ]; then
  echo "finding_verifier: family=$FAMILY mode=$MODE cli_rc=$RC answered=$ANSWERED/$ASKED — partial answer from a failed CLI, degrading" >&2
  exit 3
fi
[ "$RC" -ne 0 ] && echo "finding_verifier: family=$FAMILY cli_rc=$RC but answered $ANSWERED/$ASKED — allowed, recorded" >&2
exit 0
