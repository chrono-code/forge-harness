#!/usr/bin/env bash
# test_chamber_sig_lanes.sh — known-pair calibration for chamber_candidate_collect.sh's LAYER-2
# dedup signature (`_sig`/`_ksig`) on a NON-ASCII corpus.
#
# WHY (measured 2026-08-22, live corpus, this repo):
#   A freshly-registered candidate was grepped correctly by LAYER 1 and then VANISHED from the
#   ranked queue. The loss was LAYER 2. Root cause = **locale-dependent collation**, and it is not
#   one bug but a family, all in the same pipeline:
#     · `sort -u` in en_US.UTF-8 treats Hangul syllables as EQUAL to one another. Measured on
#       macOS/BSD sort: 8 distinct Korean tokens → 2 survivors (grouped by syllable count, first
#       one wins, input-order dependent). Measured on GNU coreutils 9.7 sort: same 8 → **1**.
#     · `comm -12` inherits that collation, so it reports two COMPLETELY DIFFERENT Korean tokens
#       as a common line. Measured: comm -12 <(레인) <(발주) → prints a line. The jaccard
#       numerator is therefore computed against a collation, not against the tokens.
#     · `awk 'length()>=4'` counts BYTES on BSD awk and CHARACTERS on gawk in a UTF-8 locale. The
#       same 2-syllable Korean token passes on macOS (6 bytes) and is DROPPED on Linux (2 chars),
#       so the two platforms disagree about the signature before any comparison happens.
#   Net effect on the live corpus (64 raw markers): unrelated candidates were folded into clusters
#   of 11, 7, 7, 4 and 3, and only each cluster's FIRST member reached the output. Everything else
#   was silently deleted from the queue while the run reported a healthy "deduped candidates: 31".
#
#   That is the [[feedback_not_found_is_not_zero_family]] shape — a silent fold rendered as a clean
#   number — which is why it needs a mechanical anchor rather than a note.
#
# WHAT IT PINS (the lanes below, in pairs, because a merge check with only one direction is not a
# measurement — over-merging and never-merging both produce a "correct" number on half the corpus):
#   L1 Korean, DIFFERENT   → must NOT merge  (known-positive: the actual live mis-merge)
#   L2 Korean, SAME        → must merge      (known-negative: the fix must not kill real dedup)
#   L3 English, DIFFERENT  → must NOT merge  (control: the defect is Hangul-only; if this lane ever
#                                             goes red the diagnosis above is wrong)
#   L4 English, SAME       → must merge      (control, other direction)
#   L5 Korean ×3 unrelated → must stay 3     ("does it collapse a set, not just a pair")
#   L6 Korean vs English   → must NOT merge  (mixed-script pair)
#
# 🟥 EVERY LANE DRIVES THE REAL SCRIPT. Nothing here re-implements `_sig`. A lane suite that carries
#   its own copy of the logic grades the copy ([[feedback_adversarial_review_not_substitute_for_first_use]]
#   — "초록의 출처를 물어라: 사본이 통과시키고 있었다").
#
# 🟥 FIXTURES ARE SELF-BUILT under mktemp, never this repo's own tracks/ — a suite that reads
#   repo-specific paths FAILs wholesale once the script is ported (portability_lint P9).
#
# Usage:  bash scripts/test_chamber_sig_lanes.sh
# Exit:   0 = all lanes pass · 1 = a lane failed · 10 = harness error (could not measure)

set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SUBJ="$REPO/scripts/chamber_candidate_collect.sh"
[ -f "$SUBJ" ] || { echo "HARNESS ERROR: subject missing: $SUBJ"; exit 10; }

TMP="$(mktemp -d 2>/dev/null)" || { echo "HARNESS ERROR: mktemp failed"; exit 10; }
trap 'rm -rf "$TMP"' EXIT

fail=0
lane=0

# Build a throwaway FH root holding exactly the given marker lines, run the REAL collector inside
# it, and echo "NRAW NDEDUP". The collector locates its own FH root from its dirname, so the copy
# has to live in <root>/scripts/ — that is also why this cannot be done by calling the repo copy
# with an env var: the script offers no such knob and inventing one for the test would move the
# measurement off the shipped path.
_run() { # $@ = marker descriptions
  local root="$TMP/fx.$lane"
  rm -rf "$root"
  mkdir -p "$root/scripts" "$root/tracks/_meta" "$root/plugins" || return 10
  cp "$SUBJ" "$root/scripts/" || return 10
  # NOTE: chamber_candidate_screen.sh is deliberately NOT copied. Its verdict column is irrelevant
  # here and its absence keeps the fixture independent of this repo's asset tree.
  local f="$root/tracks/_meta/fh_signal_2000-01-01_fixture.md"
  : > "$f"
  local d
  for d in "$@"; do printf 'CHAMBER-CANDIDATE: %s\n' "$d" >> "$f"; done
  local out
  out=$(bash "$root/scripts/chamber_candidate_collect.sh" 2>&1) || true
  local nraw ndedup
  nraw=$(printf '%s\n' "$out"   | sed -n 's/.*raw candidate markers found: \([0-9][0-9]*\).*/\1/p' | head -1)
  ndedup=$(printf '%s\n' "$out" | sed -n 's/^deduped candidates: \([0-9][0-9]*\) .*/\1/p' | head -1)
  printf '%s %s\n' "${nraw:-X}" "${ndedup:-X}"
}

# $1=label  $2=expected dedup count  $3..=descriptions
_lane() {
  lane=$((lane+1))
  local label="$1" want="$2"; shift 2
  local got nraw ndedup
  got=$(_run "$@")
  nraw="${got%% *}"; ndedup="${got##* }"
  # Instrument control BEFORE the verdict: if LAYER 1 did not even see the markers, a "correct"
  # dedup number would be an accident. `not found` is not a zero.
  if [ "$nraw" != "$#" ]; then
    echo "HARNESS ERROR  $label: collector saw $nraw raw markers, fixture planted $# — instrument dead, verdict void"
    fail=1; return
  fi
  if [ "$ndedup" = "$want" ]; then
    echo "PASS  $label (deduped=$ndedup, expected $want)"
  else
    echo "FAIL  $label: deduped=$ndedup, expected $want  ($nraw raw markers)"
    fail=1
  fi
}

echo "── chamber signature lanes (LAYER-2 dedup, non-ASCII corpus) ──"

# L1 — KNOWN-POSITIVE. Both strings are lifted VERBATIM from this repo's live corpus, and this is
# the exact pair that folded on 2026-08-22: the second was swallowed by the first and never reached
# the queue. Deliberately NOT a synthetic minimal pair — the punctuation soup («」·—/+()) is the
# "뚫리는 표기" that a clean two-word fixture would step over.
# ⚠️ The strings must stay VERBATIM. A first draft of this lane paraphrased six characters of the
# second string's tail ("행위로 굳힌다" for "행위자가 읽는 곳에.") and the pair stopped folding —
# the lane went green against the very code it was written to indict. Do not "tidy" these.
_lane "L1 ko/different (live mis-merge pair)" 2 \
  '「미사용 자산의 원인 3분할(값어치·배선·계기)」을 tier 전에 강제하는 렌즈 — 처분 tier 가 원인 판정을 앞서지 못하게 한다' \
  '병렬 레인 발주 계약 — 보고 의무 3줄 + 취향/판정/승인 3축 라우팅 + idle 구독을 카드 안에 박은 형태. 별도 규칙 파일 없이 행위자가 읽는 곳에.'

# L2 — KNOWN-NEGATIVE. Real duplicates must still collapse; a fix that merely stops merging would
# pass L1 and destroy the feature. Same candidate, re-listed with a trailing qualifier.
_lane "L2 ko/same (true duplicate must still merge)" 1 \
  'session-token-ledger — 세션 및 서브에이전트 토큰 실사용을 기계 출처에서 수집해 원장화하고 추정기가 역참조하는 계기' \
  'session-token-ledger — 세션 및 서브에이전트 토큰 실사용을 기계 출처에서 수집해 원장화하고 추정기가 역참조하는 계기 (동일 건 재등재, 앵커 보강만)'

# L3/L4 — ENGLISH CONTROL. These pin the diagnosis, not the feature: the defect is a Hangul
# collation defect, so both English lanes must be green BEFORE and AFTER the repair. If L3 or L4
# is ever red, the cause is somewhere other than where this header says it is.
_lane "L3 en/different (control)" 2 \
  'parallel lane dispatch contract — reporting duty condensed into three lines plus an idle subscription card' \
  'unused asset triage lens — forces value versus wiring versus instrument before any disposal tier is assigned'

_lane "L4 en/same (control)" 1 \
  'session token ledger — collect subagent token usage from a mechanical source and let the estimator dereference it' \
  'session token ledger — collect subagent token usage from a mechanical source and let the estimator dereference it, relisted'

# L5 — SET COLLAPSE, not just a pair. The live failure produced clusters of 11; a pairwise-only
# suite would have called a 3→1 fold "one merge" and moved on.
_lane "L5 ko/three unrelated" 3 \
  '낭독 렌즈 — 「소리 내어 읽히는가」를 재는 계기. 문서 린터가 구조적으로 못 보는 축이다' \
  'fh-router-demotion — salience 상시부하를 플랫폼 네이티브 메커니즘으로 이관하는 대수술' \
  '인물 시뮬레이터 하네스 — 닫힌 코퍼스 + 그라운딩 게이트 + 페르소나 캐스트를 한 틀로 묶는다'

# L6 — MIXED SCRIPT. A Korean signature that collapses to near-nothing can also collide with an
# unrelated ASCII one, which is a different failure path from ko↔ko.
_lane "L6 ko vs en" 2 \
  '원정 수련 — 세계 강력 레포에서 배워오는 반복 루틴. 탐색 판별 흡수 3단이다' \
  'entrypoint wiring generator — emit runtime-native hook settings from a single event manifest'

echo ""
if [ "$fail" -eq 0 ]; then
  echo "chamber signature lanes: ALL PASS ($lane lanes)"
else
  echo "chamber signature lanes: FAILURES PRESENT ($lane lanes run)"
fi
exit "$fail"
