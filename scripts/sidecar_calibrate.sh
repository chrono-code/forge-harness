#!/usr/bin/env bash
# sidecar_calibrate.sh — measure the cross-family sidecar panel before trusting it.
#
# WHY: `auto-decorrelation` and the load-bearing cross-family gate both ask "is a different-family
# auditor reachable?" — and until now that question was answered from memory. Two measured failures
# on 2026-07-30, one in each direction:
#   · A marker was written claiming `cross-family unavailable this session`. Probed later in the same
#     session, codex ran fine. Unavailability was DECLARED, never measured.
#   · agy pinned with the slug `gemini-3.1-pro-high` answered as **Gemini 3.6 Flash** — silently, with
#     no error. "The sidecar ran" and "the model I pinned answered" are different propositions, and
#     only the second one licenses a claim about model-family diversity.
# A panel you have not probed is not a panel; it is an assumption with a hostname.
#
# WHAT IT MEASURES, per runtime — four legs, because each catches a different lie:
#   REACHABLE          the binary exists and runs at all
#   PIN-OK / UNTRUSTED-PIN
#                      a discriminating identity probe: does the answer NAME the model that was
#                      pinned? A generic "OK" proves nothing — any model returns it. This is the only
#                      anchor for a runtime that falls back silently.
#   control: rejects-bogus / accepts-bogus
#                      pin a model that cannot exist. This measures ONE thing only: whether unknown
#                      names are validated. It does NOT mean known names are served faithfully, and
#                      the gap between those is where the real trap lives — agy REJECTS nonsense yet
#                      silently served Flash for `gemini-3.1-pro-high`, a slug from its own
#                      catalogue (measured 2026-07-30). So `rejects-bogus` must never be read as
#                      "the pin is safe": the identity probe still decides. `accepts-bogus` is the
#                      stronger warning — there, the identity probe is the ONLY evidence at all.
#   VERDICT-OK / VERDICT-UNPARSEABLE
#                      ask for one bare token. A runtime that answers with agentic prose cannot carry
#                      a machine-read verdict. Measured for agy at 1.0.14 (2026-07-04) and NOT
#                      inherited here: the version has moved, and this file re-measures rather than
#                      quoting. Fitness is a per-run measurement, not a property.
#
# Detector, never a gate: ALWAYS exits 0. It reports; the caller decides. A calibration run that
# could block would make callers stop running it, which is the failure this exists to prevent.
#
# Cost: real API calls (3 short probes per runtime). Use --only to scope. `--stub-model` exists for
# the lane harness so it can drive stub CLIs without touching a real catalogue.
#
# Usage:  bash scripts/sidecar_calibrate.sh [--only codex|agy] [--stub-model NAME] [--quiet]
# Output: one block per runtime, then a PANEL line — the line a marker's `crossfamily:` leg quotes.

set -uo pipefail

ONLY=""; STUB_MODEL=""; QUIET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="${2:-}"; shift 2 ;;
    --stub-model) STUB_MODEL="${2:-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    *) shift ;;
  esac
done

TIMEOUT_BIN=""
command -v timeout >/dev/null 2>&1 && TIMEOUT_BIN="timeout"
command -v gtimeout >/dev/null 2>&1 && TIMEOUT_BIN="gtimeout"
# No coreutils timeout on stock macOS. perl's alarm is the portable watchdog; if perl is missing too,
# run WITHOUT a deadline rather than skipping the probe — a missing watchdog must never become a
# silently skipped measurement reported as absence (the same rule fh_session_load.sh applies).
_run() {
  local secs="$1"; shift
  if [ -n "$TIMEOUT_BIN" ]; then "$TIMEOUT_BIN" "$secs" "$@"
  elif command -v perl >/dev/null 2>&1; then perl -e 'alarm shift @ARGV; exec @ARGV' "$secs" "$@"
  else "$@"; fi
}

# _answer — reduce a runtime's stdout to THE MODEL'S ANSWER.
# Measured on the first real run (2026-07-30): matching against whole stdout is unsound, because a
# real CLI prints a session banner that REPEATS the pinned model back (`codex exec` emits its
# version, workdir and model config before the reply). Under a whole-stdout match, a runtime that
# merely echoes its own configuration passes the identity probe — the transport layer supplying the
# very evidence the probe exists to obtain from the model. So: take the last non-empty line, skipping
# trailing telemetry (`tokens used`, bare numbers, rule lines).
# RESIDUAL, named: this is a heuristic on line position. A runtime that prints its answer and then
# unrecognised trailing chatter would be mis-read. It is checked by the banner-echo lane, not proven
# in general; a structured output mode (JSON) would replace the heuristic and none is used here yet.
_answer() {
  awk 'BEGIN{last=""}
       {line=$0
        gsub(/\r/,"",line)
        gsub(/^[[:space:]]+|[[:space:]]+$/,"",line)
        if (line=="") next
        if (line ~ /^[-=_]{3,}$/) next
        if (tolower(line) ~ /^tokens? used/) next
        if (line ~ /^[0-9,.]+$/) next
        last=line}
       END{print last}'
}

IDENTITY_PROMPT="Answer with one line only: your exact model name and version."
VERDICT_PROMPT="Reply with exactly one word, PASS or FAIL, and nothing else. The word is PASS."
BOGUS_MODEL="zzz-nonexistent-model-9.9"

PANEL=""

# build_cmd <runtime> <model> <prompt> — fills CMD as an argv array.
# NOT a shell function passed to the watchdog: `timeout`/`gtimeout` exec a BINARY and cannot see
# shell functions, so an earlier revision fed them a function name and every probe came back as the
# runtime failing to run (caught by lane 3/4b/5b, not by reading).
build_cmd() {
  case "$1" in
    codex) CMD=(codex exec -m "$2" -c model_reasoning_effort=high --skip-git-repo-check "$3") ;;
    agy)   CMD=(agy -p "$3" --model "$2" --print-timeout 170s) ;;
    *)     CMD=("$1" "$3") ;;
  esac
}

# probe_runtime <name> <real-model-pin>
probe_runtime() {
  local rt="$1" model="$2"
  [ -n "$ONLY" ] && [ "$ONLY" != "$rt" ] && return 0
  [ -n "$STUB_MODEL" ] && model="$STUB_MODEL"

  if ! command -v "$rt" >/dev/null 2>&1; then
    printf '%-6s ABSENT — not installed on this machine (absence measured, not assumed)\n' "$rt"
    return 0
  fi

  local id_out pin_state ctl_out ctl_state v_out v_state
  build_cmd "$rt" "$model" "$IDENTITY_PROMPT"
  id_out="$(_run 200 "${CMD[@]}" 2>&1 | _answer)"

  # Discriminating check — the answer must be the MODEL's self-report naming the model that was
  # pinned. What counts as "naming it" is the VERSION token, not every token of the pin slug:
  # vendors answer with a product name (`gpt-5.6-sol` → "GPT-5.6 Codex"), and demanding the suffix
  # made this report UNTRUSTED-PIN for a pin that had actually held (measured 2026-07-30). The
  # version is also exactly where the real failures differ — 3.1 asked, 3.6 answered. If a pin
  # carries no version token at all, fall back to requiring the name words, since then there is
  # nothing sharper to test.
  local ver name_words hit=0
  ver="$(printf '%s' "$model" | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  name_words="$(printf '%s' "$model" | tr 'A-Z' 'a-z' | sed -E 's/[^a-z]+/ /g' \
        | tr ' ' '\n' | grep -E '^[a-z]{3,}$' \
        | grep -vE '^(high|low|medium|thinking|the|exec)$' | head -1)"
  if [ -n "$id_out" ]; then
    if [ -n "$ver" ]; then
      printf '%s' "$id_out" | grep -qF "$ver" && hit=1
    elif [ -n "$name_words" ]; then
      printf '%s' "$id_out" | tr 'A-Z' 'a-z' | grep -qF "$name_words" && hit=1
    fi
  fi
  if [ "$hit" -eq 1 ]; then pin_state="PIN-OK"; else pin_state="UNTRUSTED-PIN"; fi

  build_cmd "$rt" "$BOGUS_MODEL" "$IDENTITY_PROMPT"
  ctl_out="$(_run 120 "${CMD[@]}" 2>&1)"
  if [ $? -ne 0 ] || printf '%s' "$ctl_out" | grep -qiE 'not supported|invalid|unknown model|error'; then
    ctl_state="rejects-bogus"
  else
    ctl_state="accepts-bogus"
  fi

  build_cmd "$rt" "$model" "$VERDICT_PROMPT"
  v_out="$(_run 200 "${CMD[@]}" 2>&1 | _answer)"
  # Parseable = a bare verdict token is recoverable from a short answer. Prose that merely CONTAINS
  # the word does not qualify: a verdict channel must be readable without a human deciding what the
  # runtime meant.
  local v_compact
  v_compact="$(printf '%s' "$v_out" | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//')"
  if [ "${#v_compact}" -le 12 ] && printf '%s' "$v_compact" | grep -qiE '^(pass|fail)[.!]?$'; then
    v_state="VERDICT-OK"
  else
    v_state="VERDICT-UNPARSEABLE"
  fi

  printf '%-6s REACHABLE · %s · control: %s · %s\n' "$rt" "$pin_state" "$ctl_state" "$v_state"
  [ -z "$QUIET" ] && printf '       pinned: %s\n       identity said: %s\n' "$model" "$(printf '%s' "$id_out" | cut -c1-100)"
  if [ "$ctl_state" = "accepts-bogus" ]; then
    printf '       ⚠️  this runtime does not validate the pin at all, so the identity probe is the ONLY\n'
    printf '           evidence that the intended model answered — a clean run proves nothing here.\n'
  elif [ "$pin_state" = "UNTRUSTED-PIN" ]; then
    printf '       ⚠️  it rejects UNKNOWN names, which says nothing about serving KNOWN ones faithfully.\n'
    printf '           The identity probe disagreed with the pin — treat this runtime as substituting.\n'
  fi
  # Only a runtime whose pin is trustworthy counts toward the panel. A reachable runtime answering as
  # some other model contributes no family diversity, which is the entire point of the panel.
  [ "$pin_state" = "PIN-OK" ] && PANEL="${PANEL:+$PANEL, }$rt"
  return 0
}

probe_runtime codex "gpt-5.6-sol"
probe_runtime agy   "Gemini 3.1 Pro (High)"

if [ -n "$PANEL" ]; then
  echo "PANEL: $PANEL — usable different-family auditor(s), pin verified this run"
else
  echo "PANEL: none — no runtime passed the identity probe on this machine, this run"
  echo "       State this, do not infer it: a marker's crossfamily leg may say 'none' but never stay silent."
fi
exit 0
