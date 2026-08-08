#!/usr/bin/env bash
# test_reviewer_capability_conformance.sh — runs the SHARED corpus against THIS repo's
# reviewer-capability implementation and reports every disagreement.
#
# THE CONTRACT, and why it is shaped this way. Three repos judge "can this model be an
# adversarial reviewer?" in three languages (bash hook · shell probe · python backend).
#
# Be precise about WHY they do not share a library, because the first draft of this comment
# overstated it and a cross-family review caught the inversion: residency blocks the
# PRIVATE→PUBLIC direction (internal model ids must never reach a public repo). It does NOT
# stop a private repo from vendoring a sanitized PUBLIC library. The actual reasons are
# (a) three languages/runtimes, and (b) the classifier is two regexes — a shared library
# would add more coupling than the thing it shares. Residency governs the CORPUS's contents,
# not the decision to share data instead of code.
#
# What they share is `scripts/reviewer_capability_corpus.tsv`
# — pure data, residency-safe. Each side keeps its own implementation and vendors this
# script plus the corpus; drift then surfaces as a red test in whichever repo drifted,
# instead of as a silent difference nobody measures.
#
# Measured before this existed: 19 ids, 10 disagreements between two implementations, 9 of
# them the private side reading INCAPABLE as CAPABLE. That drift had shipped and was
# invisible — nothing compared the two.
#
# ── PORTING THIS TO ANOTHER REPO (the adapter is the only thing you write) ──────
# Copy this file + the corpus, then replace classify() with a call into your own code:
#   shell :  classify(){ your_probe.sh --check-model "$1" >/dev/null 2>&1 && echo CAPABLE || echo INCAPABLE; }
#   python:  classify(){ python3 -c 'import sys;from x import is_reviewer_capable;
#                        print("CAPABLE" if is_reviewer_capable(sys.argv[1]) else "INCAPABLE")' "$1"; }
# Everything else — corpus parsing, verdict comparison, the UNDECIDABLE rule — stays.
#
# ── THE UNDECIDABLE ROWS ARE THE POINT ─────────────────────────────────────────
# An implementation with only a denylist answers CAPABLE for an unrecognised id. That is
# fail-open: a denylist cannot know `voyage-3` is an embedding model. Such an implementation
# FAILS these rows, and that failure is correct — it is telling you to add a default-deny
# leg, not to edit the corpus. A repo that genuinely cannot express UNDECIDABLE may set
# ALLOW_UNDECIDABLE_AS_INCAPABLE=1, which is strictly-safer and reported as a named
# deviation rather than a silent pass.
#
# Usage: bash scripts/test_reviewer_capability_conformance.sh   Exit: 0 = conforms; 1 = drift.

set -uo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CORPUS="${CORPUS:-$REPO_ROOT/scripts/reviewer_capability_corpus.tsv}"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
LENIENT="${ALLOW_UNDECIDABLE_AS_INCAPABLE:-0}"

[ -f "$CORPUS" ] || { echo "🟥 HARNESS-ERROR: corpus not found at $CORPUS"; exit 10; }

# ── Contract pin: am I reading THE corpus, or a drifted local copy? ─────────────
# The single shared artifact lives in N repos as N copies, so the first failure mode is not
# a wrong verdict — it is each side quietly grading itself against its own stale copy while
# every instrument reports healthy. Verdict on mismatch is HARNESS_ERROR (exit 10), which is
# neither PASS nor FAIL: nothing was measured against the contract.
PINNED=$(grep -m1 '^#CORPUS-SHA256' "$CORPUS" | awk '{print $2}')
ACTUAL=$(grep -E '^[^#[:space:]]' "$CORPUS" | shasum -a 256 2>/dev/null | cut -c1-16)
[ -z "$ACTUAL" ] && ACTUAL=$(grep -E '^[^#[:space:]]' "$CORPUS" | sha256sum 2>/dev/null | cut -c1-16)
if [ -z "$PINNED" ] || [ -z "$ACTUAL" ]; then
  echo "🟥 HARNESS-ERROR: cannot verify the corpus pin (pinned='$PINNED' actual='$ACTUAL')."
  echo "   An unverifiable pin is not a passing pin — refusing to grade against an unknown corpus."
  exit 10
fi
if [ "$PINNED" != "$ACTUAL" ]; then
  echo "🟥 HARNESS-ERROR: corpus drift — pinned=$PINNED actual=$ACTUAL"
  echo "   This copy's data rows differ from the contract it names. Either re-sync from the"
  echo "   canonical corpus, or bump #CORPUS-VERSION + #CORPUS-SHA256 in EVERY repo that"
  echo "   vendors it. A local-only edit is how the shared contract silently stops being shared."
  exit 10
fi

# ── Namespace declaration: what THIS consumer owns (OPA-bundle `roots` shape) ───
# This consumer composes PANELS, so it judges sidecar/CLI names and model ids alike.
# A consumer that only classifies model ids declares NS="model-id" and its skipped rows are
# REPORTED below, never silently counted as passing.
NS="${NS:-cli model-id}"

# ── THIS repo's adapter: the two regexes inside validate_crossfamily_leg ────────
# Sourced FROM the hook rather than restated, so this test cannot drift from the thing it
# is testing. A restated copy would be a fourth implementation — the exact defect class
# this file exists to measure.
DENY=$(grep -m1 -oE "grep -qiE 'embed\|[^']*'" "$HOOK" | sed -E "s/^grep -qiE '//; s/'$//")
ALLOW=$(grep -m1 -oE "grep -qiE 'codex\|[^']*'" "$HOOK" | sed -E "s/^grep -qiE '//; s/'$//")
if [ -z "$DENY" ] || [ -z "$ALLOW" ]; then
  echo "🟥 HARNESS-ERROR: could not extract the classifier from $HOOK"
  echo "   (deny='$DENY' allow='$ALLOW') — refusing to measure against an empty pattern,"
  echo "   which would report every row as agreeing."
  exit 10
fi

classify() { # $1 = model id → CAPABLE | INCAPABLE | UNDECIDABLE
  # Ineligible-first: the overlap rows depend on this order and exist to catch its inversion.
  if printf '%s' "$1" | grep -qiE "$DENY"; then echo INCAPABLE
  elif printf '%s' "$1" | grep -qiE "$ALLOW"; then echo CAPABLE
  else echo UNDECIDABLE; fi
}

# ── Instrument calibration: prove the adapter separates a known pair BEFORE trusting it ──
# The pair is DERIVED FROM THE CORPUS within this consumer's own namespace, never hardcoded.
# A hardcoded pair is namespace-blind: the first draft pinned `codex`, and a consumer that
# classifies model ids (and correctly has no opinion on CLI names) failed calibration for a
# reason that had nothing to do with its classifier. A calibration that can fail for the
# wrong reason cannot certify anything.
kp_pos=$(sed 's/\t/|/g' "$CORPUS" | awk -F'|' -v ns="$NS" \
  '$2=="CAPABLE" && $3 ~ /^ns:/ { split($3,a,"/"); n=substr(a[1],4); if (index(" " ns " ", " " n " ")) { print $1; exit } }')
kp_neg=$(sed 's/\t/|/g' "$CORPUS" | awk -F'|' -v ns="$NS" \
  '$2=="INCAPABLE" && $3 ~ /^ns:/ { split($3,a,"/"); n=substr(a[1],4); if (index(" " ns " ", " " n " ")) { print $1; exit } }')
if [ -z "$kp_pos" ] || [ -z "$kp_neg" ]; then
  echo "🟥 HARNESS-ERROR: corpus has no known pair inside namespace [$NS]"
  echo "   (pos='$kp_pos' neg='$kp_neg'). Without a pair that this consumer OWNS, nothing"
  echo "   below is calibrated — refusing to grade."
  exit 10
fi
gp=$(classify "$kp_pos"); gn=$(classify "$kp_neg")
# Separate "the instrument is broken" from "the instrument works and disagrees". Collapsing
# them makes a real, gradeable divergence abort as HARNESS-ERROR and go unmeasured — the
# finding disappears into the error channel. A classifier that says CAPABLE to a known
# NEGATIVE is not discriminating at all → unmeasurable. One that is merely too strict on the
# positive still separates, so grade it and report the strictness as drift.
if [ "$gn" = CAPABLE ]; then
  echo "🟥 HARNESS-ERROR: adapter does not discriminate — known NEGATIVE $kp_neg → CAPABLE."
  echo "   It cannot separate a case whose answer is already known. Aborting, not reporting."
  exit 10
fi
if [ "$gp" != CAPABLE ]; then
  echo "⚠️  calibration: known POSITIVE $kp_pos → $gp (expected CAPABLE)."
  echo "   The classifier discriminates (negative held) but is stricter than the contract."
  echo "   Grading continues — this is drift to report, not an unmeasurable instrument."
else
  echo "calibrated on [$NS]: $kp_pos → $gp · $kp_neg → $gn"
fi

N=0; BAD=0; DEV=0; SKIP=0
printf "%-32s %-12s %-12s %s\n" "id" "expected" "actual" ""
# IFS=$'\t' collapses CONSECUTIVE tabs (POSIX: repeated whitespace-class IFS chars are one
# delimiter), so an aligned row with an empty field shifts every later field left and the
# verdict column silently reads someone else's value. Split on a sentinel instead.
while IFS='|' read -r id want cls why; do
  case "$id" in ''|'#'*|' '*|$'\t'*) continue ;; esac
  # Verdict field must be one of the three tokens. A continuation line of a multi-line note
  # otherwise parses as a row and reports a phantom disagreement — measured on this file's
  # own first draft, which is exactly the "instrument, not target" failure it must not have.
  case "${want:-}" in CAPABLE|INCAPABLE|UNDECIDABLE) : ;; *) continue ;; esac
  row_ns=$(printf '%s' "${cls:-}" | sed -E 's|^ns:([^/]+)/.*|\1|')
  case " $NS " in *" $row_ns "*) : ;; *) SKIP=$((SKIP+1)); continue ;; esac
  N=$((N+1)); got=$(classify "$id")
  if [ "$got" = "$want" ]; then
    printf "%-32s %-12s %-12s ✅\n" "$id" "$want" "$got"
  elif { [ "$want" = UNDECIDABLE ] && [ "$got" = INCAPABLE ]; } \
    || { [ "$want" = INCAPABLE ] && [ "$got" = UNDECIDABLE ]; }; then
    # Outcome-safety grading, not label identity. Both verdicts BLOCK under default-deny, so
    # the operational result is identical and this is a reported deviation, never a failure.
    # Failing it would punish a pattern classifier for an opaque id it cannot possibly read
    # (`voyage-3`, `bge-m3`) and make DELETING THE ROW the rational maintenance move — the
    # corpus would then shrink toward whatever the weakest implementation happens to catch.
    printf "%-32s %-12s %-12s ⚠️  deviation — same outcome (both block)\n" "$id" "$want" "$got"
    DEV=$((DEV+1))
  else
    printf "%-32s %-12s %-12s ❌ %s\n" "$id" "$want" "$got" "$cls"
    # Name the direction: a permissive miss is the one that ships broken panels.
    { [ "$want" = INCAPABLE ] || [ "$want" = UNDECIDABLE ]; } && [ "$got" = CAPABLE ] \
      && echo "     ↑ PERMISSIVE drift — this id would be counted as a reviewer"
    BAD=$((BAD+1))
  fi
done < <(sed 's/\t/|/g' "$CORPUS")

echo
echo "corpus pin: $PINNED · namespaces: [$NS]"
echo "rows graded: $N · disagreements: $BAD · allowed deviations: $DEV · skipped (other namespace): $SKIP"
if [ "$BAD" -eq 0 ]; then echo "✅ conforms to the shared corpus"; else
  echo "❌ DRIFT — this repo's classifier disagrees with the shared corpus on $BAD row(s)."
  echo "   Fix the implementation, or change the corpus in ALL repos that vendor it."
fi
exit $([ "$BAD" -eq 0 ] && echo 0 || echo 1)
