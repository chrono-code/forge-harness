#!/usr/bin/env bash
# ratchet_base_resolve.sh — pick the base commit scripts/script_caller_ratchet.sh diffs `baseline:`
# against, and REFUSE to substitute a different one when the named base is gone.
#
# ── WHY THIS IS A SCRIPT AND NOT TEN LINES OF YAML ────────────────────────────────────────────
# It was ten lines of YAML, inside .github/workflows/caller-zero-ratchet.yml, and that is precisely
# why the defect below survived three adversarial review rounds: no lane can execute a `run:` block.
# The ratchet's own doctrine is that a claim with no executable anchor is prose, so the base
# resolver — the component that decides whether the gate measures anything at all — was the one
# part of this gate with no anchor on it. Extracting it is the repair that makes it testable;
# scripts/test_script_caller_ratchet_lanes.sh L24–L26 are the lanes that could not exist before.
#
# ── THE DEFECT, REPRODUCED 2026-08-22 BEFORE THIS FILE EXISTED ────────────────────────────────
# The YAML resolved a candidate, tested it with `git cat-file -e`, and on failure set `B=""` and
# fell through to `HEAD~1`. Measured on a three-commit fixture (A base · B = a callerless script
# AND its new `baseline:` line, the illegal move · C an unrelated later commit), driving the step
# body verbatim:
#
#   PUSH_BEFORE=<A, reachable>          -> base=A       -> checker exit 1, names scripts/newdebt.sh
#   PUSH_BEFORE=<a force-pushed-away sha> -> base=HEAD~1 -> checker exit 0,
#                                          "shrink-only ENFORCED — no new `baseline:` entry"
#
# Both properties are the failure, and they compound:
#   ① the substitution is SILENT — nothing in the output says the requested comparison was refused;
#   ② the substitute is NARROWER (one commit), so growth landed anywhere earlier in the same push
#      is invisible — and the run still prints ENFORCED, the strongest word this gate owns.
# It also contradicted the checker's own header, which already said in as many words that a named
# base that does not resolve is exit 2 and "NEVER a silent fall-through to auto-detection". The
# rule was true in the checker and false in the workflow that drives it — the same
# rule-misdescribes-its-own-machine shape the shrink-only half was written to close.
#
# 🟥 A FORCE-PUSH IS EXACTLY WHEN THE COMPARISON MATTERS MOST AND EXACTLY WHEN IT DISAPPEARS.
# That is why the fallback direction is the whole question: the base going missing is not a random
# infrastructure hiccup, it is correlated with history being rewritten under the gate.
#
# ── THE RULE ──────────────────────────────────────────────────────────────────────────────────
#   a candidate was NAMED by the event and does not resolve here  -> exit 3, degrade CLOSED.
#       No substitution. "I could not make the comparison you asked for" and "I made it and found
#       nothing" are different facts, and only one of them may be printed as a pass.
#   NO candidate was named at all (workflow_dispatch · a branch's first push, before=all-zeros)
#       -> HEAD~1 if it exists, ANNOUNCED as a one-commit window; else BOOTSTRAP (require=0).
#       Nothing was asked for, so nothing is being substituted. This half is UNCHANGED from the
#       YAML it replaces and is deliberately not widened here — see the residual note below.
#
# ⚠️ NAMED RESIDUAL, not silently absent: the no-candidate HEAD~1 window is still one commit wide,
# and the checker will call a clean result there ENFORCED. That is a weaker version of ② above and
# it is left open on purpose — closing it needs a fifth shrink-state in the checker, which is a
# separate change to a separate file. It is not the reproduced defect and is not fixed here.
#
# Usage:  bash scripts/ratchet_base_resolve.sh [--root DIR]
# Env in:   BASE_BRANCH   github.base_ref                       (pull_request)
#           PR_BASE_SHA   github.event.pull_request.base.sha    (pull_request)
#           PUSH_BEFORE   github.event.before                   (push)
#           RATCHET_OUTPUT  file to append `base=`/`require=` to; defaults to $GITHUB_OUTPUT.
#                           Absent -> the answer is printed and nothing is written.
# Exit:   0 = an answer was produced (base+require written; require=0 means BOOTSTRAP)
#         2 = instrument error — --root is not a directory, or not a git work tree
#         3 = a NAMED base does not resolve in this checkout — degrade CLOSED, no substitution
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 || exit 2 ;;
    -h|--help) sed -n '/^# Usage:/,/^# Exit:/p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "usage: $0 [--root DIR]" >&2; exit 2 ;;
  esac
done
[ -d "$ROOT" ] || { echo "FAIL  ratchet-base: --root '$ROOT' is not a directory"; exit 2; }

if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "FAIL  ratchet-base: '$ROOT' is not a git work tree, so no base can be resolved."
  echo "      That is an instrument error, not a bootstrap: a checkout that should be a repo and"
  echo "      is not means the step ran somewhere nobody intended."
  exit 2
fi

OUT="${RATCHET_OUTPUT:-${GITHUB_OUTPUT:-}}"
emit() {   # emit <base> <require>
  echo "base=$1"
  echo "require=$2"
  if [ -n "$OUT" ]; then { echo "base=$1"; echo "require=$2"; } >> "$OUT"; fi
}

ZEROS=0000000000000000000000000000000000000000

# 🟥 `out=$(cmd)` then `rc=$?` on its OWN line, every time. A `|| echo` fallback anywhere in this
# file would hand an empty string to a `[ -n ... ]` test as though it were an answer, which is the
# whole failure mode being repaired ([[feedback_pipefail_fallback_disarms_guard]]).
_rev() {   # _rev <ref> -> prints the commit sha, rc 0; prints nothing, rc nonzero
  _o=$(git -C "$ROOT" rev-parse --verify --quiet "${1}^{commit}" 2>/dev/null)
  _r=$?
  [ "$_r" -eq 0 ] && [ -n "$_o" ] || return 1
  printf '%s' "$_o"
}

# ── ① WAS A BASE NAMED BY THE EVENT? ──────────────────────────────────────────────────────────
# "Named" is about the EVENT PAYLOAD, not about whether the ref happens to be present. That
# distinction is the entire fix: the old code asked "did it resolve", got no, and could no longer
# tell "nobody asked" apart from "what was asked for is gone".
NAMED=""; NAMED_FROM=""
if [ -n "${BASE_BRANCH:-}" ]; then
  NAMED="origin/${BASE_BRANCH}"; NAMED_FROM="github.base_ref"
elif [ -n "${PR_BASE_SHA:-}" ]; then
  NAMED="${PR_BASE_SHA}"; NAMED_FROM="github.event.pull_request.base.sha"
elif [ -n "${PUSH_BEFORE:-}" ] && [ "$PUSH_BEFORE" != "$ZEROS" ]; then
  NAMED="${PUSH_BEFORE}"; NAMED_FROM="github.event.before"
fi

if [ -n "$NAMED" ]; then
  # WHY MERGE-BASE ON A BRANCH AND A PLAIN RESOLVE ON A SHA. A PR checkout is the MERGE ref, so it
  # already carries whatever main gained since the PR opened; diffing against the base branch TIP
  # would report main's own additions as this PR's — a false block. merge-base asks the question
  # the gate means. A sha candidate is already immutable and needs no merge-base.
  BASE=""
  case "$NAMED" in
    origin/*)
      _o=$(git -C "$ROOT" merge-base HEAD "$NAMED" 2>/dev/null)
      _r=$?
      [ "$_r" -eq 0 ] && BASE="$_o"
      # A PR whose base-branch tracking ref is missing still has base.sha; that is a DIFFERENT
      # naming of the same intent, not a substitution, so it is tried before giving up.
      if [ -z "$BASE" ] && [ -n "${PR_BASE_SHA:-}" ]; then
        BASE="$(_rev "$PR_BASE_SHA")" || BASE=""
        [ -n "$BASE" ] && NAMED="$PR_BASE_SHA" && NAMED_FROM="github.event.pull_request.base.sha"
      fi
      ;;
    *)
      BASE="$(_rev "$NAMED")" || BASE=""
      ;;
  esac

  if [ -z "$BASE" ]; then
    # 🟥 DEGRADE CLOSED. No HEAD~1, no auto-detection, no labelled UNMEASURED. The event named a
    # comparison; answering a different question and reporting it under the same word is how an
    # instrument speaks confidently about the wrong target.
    echo "FAIL  ratchet-base: the base named by this event does not resolve in this checkout."
    echo "        named by : $NAMED_FROM"
    echo "        value    : $NAMED"
    echo "      This is the force-push / rewritten-history shape, which is exactly when the"
    echo "      shrink-only comparison matters and exactly when its base disappears. Substituting"
    echo "      HEAD~1 here would compare a ONE-COMMIT window and print ENFORCED over it."
    echo "      Fix by ONE of:"
    echo "        ① fetch the missing history (actions/checkout fetch-depth: 0)"
    echo "        ② re-run via workflow_dispatch — no base is named there, so the shrink-only half"
    echo "           reports BOOTSTRAP instead of a comparison it cannot make"
    echo "        ③ if history really was rewritten, re-baseline deliberately and say so"
    echo "::error title=caller-zero-ratchet::base named by $NAMED_FROM ($NAMED) is unreachable; refusing to substitute a narrower base"
    exit 3
  fi

  emit "$BASE" 1
  echo "ratchet-base: $BASE (named by $NAMED_FROM)"
  exit 0
fi

# ── ② NOTHING WAS NAMED ───────────────────────────────────────────────────────────────────────
# workflow_dispatch, or a branch's very first push (before = all-zeros). Nothing is being
# substituted for anything, because nothing was requested.
BASE="$(_rev 'HEAD~1')" || BASE=""
if [ -n "$BASE" ]; then
  emit "$BASE" 1
  echo "ratchet-base: $BASE (HEAD~1 — no base was named by this event)"
  echo "::warning title=caller-zero-ratchet::No base named by this event; comparing against HEAD~1, a ONE-COMMIT window. Growth landed in an earlier commit of this push would not be seen."
  exit 0
fi

# 🟥 require=0 with an EMPTY base, never require=1 with an empty base — the empty-input case.
# A require=1 paired with an empty base would reach the checker as "compare against nothing while
# refusing to accept nothing", i.e. exit 2 for a repo whose only sin is having one commit. A gate
# no author action can satisfy is an override-trainer and disarms the hooks beside it.
emit "" 0
echo "ratchet-base: BOOTSTRAP — no prior commit exists at all; the shrink-only half is unjudged."
echo "      The UNDECLARED-callerless half is independent of the base and still enforces fully."
echo "::warning title=caller-zero-ratchet::No prior commit resolvable; shrink-only half is BOOTSTRAP for this run."
exit 0
