#!/usr/bin/env bash
# test_consent_registry.sh — known-pair anchor for scripts/consent_registry_check.sh.
#
# WHY (cross-family review rounds 1-3, 2026-07-29)
#   The accept-side consent-promotion rule went REJECT -> NARROW-IT -> NARROW-IT across three
#   adversarial rounds. Round 3 stopped attacking the prose and attacked the validator, and found
#   four ways the FLOOR ITSELF was fail-open. Three were confirmed against controls:
#
#     - `promotion_eligible: "false"` (quoted) is a truthy STRING. Every eligibility test inverted,
#       so an intended-ineligible class was granted. One quote character disarmed the floor.
#     - a duplicate class name silently shadowed the earlier entry, so appending an eligible twin
#       below an ineligible one laundered the ineligible class into a grant.
#     - `standing_consent: {inline: ...}` matched no pattern, so an EXPIRED inline grant was read as
#       "no standing consent recorded" and reported PASS — a grant the checker cannot see is not an
#       absent grant, it is a false clean.
#
#   Each of those is a check that reported green while doing nothing, which is worse than an absent
#   check: it buys confidence without enforcement. Hence this anchor.
#
# Lanes: N* = known-negative (must pass) · P* = known-positive (must be caught) · D* = degrade.
# Exit 0 = all lanes correct. Exit 1 = the validator regressed toward permissiveness.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHK="$ROOT/scripts/consent_registry_check.sh"
[ -f "$CHK" ] || { echo "FAIL: $CHK not found"; exit 1; }

pass=0; fail=0
ok()  { printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  ❌ %s\n' "$1"; fail=$((fail+1)); }
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT

# want_rc: expected exit. want_rule: a rule id that must appear in the output ("" = don't care).
lane() {
  local desc="$1" want_rc="$2" want_rule="$3"
  bash "$CHK" "$TD/r.yaml" "$TD/u.md" >"$TD/o" 2>&1
  local rc=$?
  if [ "$rc" -ne "$want_rc" ]; then
    bad "$desc — exit $rc, expected $want_rc"; sed 's/^/     /' "$TD/o"; return
  fi
  if [ -n "$want_rule" ] && ! grep -q "❌ $want_rule" "$TD/o"; then
    bad "$desc — exit was right but rule $want_rule was not the reason"; sed 's/^/     /' "$TD/o"; return
  fi
  ok "$desc"
}

OKCLASS='  - {name: ok, owner: o, mode: m, target: t, capabilities: [read], sinks: [], feeds: [], promotion_eligible: true}'
mkreg() { printf 'classes:\n%s\n' "$1" > "$TD/r.yaml"; }
mkuap() { printf '%s\n' "$1" > "$TD/u.md"; }

mkreg "$OKCLASS"
mkuap 'standing_consent:
  ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "N1 a well-formed registry + eligible unexpired scoped grant passes" 0 ""

mkuap 'standing_consent:
  ok: declined'
lane "N2 a declined record is a valid non-grant state, not a malformed grant" 0 ""

mkreg '  - {name: s, owner: o, mode: m, target: t, capabilities: [read], sinks: [go-public], feeds: [], promotion_eligible: true}'
mkuap 'standing_consent: {}'
lane "P1 a class naming an irreversible SINK cannot declare itself promotable" 1 "R2"

mkreg '  - {name: f, owner: o, mode: m, target: t, capabilities: [read], sinks: [], feeds: [go-public], promotion_eligible: true}'
lane "P2 taint — a class that FEEDS an irreversible sink cannot be promotable" 1 "R2"

mkreg "$OKCLASS"
mkuap 'standing_consent:
  ghost: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "P3 a grant on an unregistered class is refused (unregistered == unknown)" 1 "R3"

mkuap 'standing_consent:
  ok: {granted: 2026-01-01, expires: 2026-06-30, effects: [read], target: t}'
lane "P4 an expired lease does not keep running" 1 "R5"

mkuap 'standing_consent:
  ok: {granted: 2026-07-29, expires: 2026-12-31}'
lane "P5 a grant with no recorded scope has no re-validation baseline" 1 "R6"

# P6-P8 are the round-3 fail-opens. Each of these PASSED before the fix.
mkreg '  - {name: q, owner: o, mode: m, target: t, capabilities: [read], sinks: [], feeds: [], promotion_eligible: "false"}'
mkuap 'standing_consent:
  q: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "P6 quoted \"false\" is rejected as a type error, not read as truthy" 1 "R1-b"

mkreg '  - {name: d, owner: o, mode: m, target: t, capabilities: [read], sinks: [go-public], feeds: [], promotion_eligible: false}
  - {name: d, owner: o, mode: m, target: t, capabilities: [read], sinks: [], feeds: [], promotion_eligible: true}'
mkuap 'standing_consent:
  d: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "P7 a duplicate class name cannot launder an ineligible class" 1 "R1-c"

mkreg "$OKCLASS"
mkuap 'standing_consent: {ok: {granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}}'
lane "P8 an INLINE grant is parsed, not silently read as 'nothing granted'" 1 "R5"

# P10-P11 are the round-4 fail-opens. Both PASSED before the fix, and both were confirmed against a
# control: the SAME expired grant was caught when it stood alone.
mkreg "$OKCLASS"
mkuap 'standing_consent: {}

notes in between

standing_consent:
  ok: {granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}'
lane "P10 an early empty consent block cannot shadow a later grant (first-match)" 1 "R3"

mkuap 'standing_consent:
  ok: {state: "revoked ", granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
if bash "$CHK" "$TD/r.yaml" "$TD/u.md" 2>&1 | grep -q "0 active grant"; then
  ok "P11 a mapping non-grant state is normalized like the scalar one (no divergent normalizer)"
else
  bad "P11 \`state: \"revoked \"\` was validated as an ACTIVE grant"
  bash "$CHK" "$TD/r.yaml" "$TD/u.md" 2>&1 | sed 's/^/     /'
fi

# P12 is the round-5 fail-open: `or {}` collapsed FALSY non-mappings into a valid-empty mapping
# before the type check, so `[]`, `false` and `0` all reported "no standing consent" and exit 0 —
# while the truthy `[a, b]` was caught. The falsy branch is the one an accident actually produces.
for badval in '  []' '  false' '  0'; do
  mkreg "$OKCLASS"
  printf 'standing_consent:\n%s\n' "$badval" > "$TD/u.md"
  lane "P12 a falsy non-mapping standing_consent ($badval) is a type error, not 'none granted'" 1 "R3"
done

# P13/N3 — round-6 fail-open: `standing_consent :` (space or tab before the colon) is the SAME YAML
# key but matched none of the patterns. Standalone it still failed closed via the no-known-form net;
# paired with a normal empty block it was invisible to both the count and the extraction, so the
# empty block parsed and the real grant vanished. Confirmed against a control (the identical expired
# grant in canonical form was caught).
mkreg "$OKCLASS"
mkuap 'standing_consent: {}

standing_consent : {ok: {granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}}'
lane "P13 a space-before-colon key cannot hide behind a canonical block" 1 "R3"

mkuap 'standing_consent :
  ok: {granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}'
lane "P13-b a space-before-colon BLOCK form is parsed and its grant validated" 1 "R5"

mkuap "$(printf 'standing_consent\t: {ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}}')"
lane "N3 a tab-before-colon key with a VALID grant passes (no over-block)" 0 ""

# P14 — round-7 fail-open: R6 presence-checked `effects`/`target` but never typed them, while the
# registry side had strict types since R1-b. A fix propagated to one side only is a hole. Control:
# a MISSING field was caught; a type-wrong one passed.
mkreg "$OKCLASS"
mkuap 'standing_consent:
  ok: {granted: 2026-07-29, expires: 2026-12-31, effects: true, target: 123}'
lane "P14 a type-wrong grant scope is rejected, not counted as recorded" 1 "R6"

mkuap 'standing_consent:
  ok: {granted: 2026-07-29, expires: 2026-12-31, effects: "read", target: "  "}'
lane "P14-b a scalar effects / whitespace-only target is rejected" 1 "R6"

mkuap 'standing_consent:
  ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [], target: t}'
lane "P14-c an EMPTY effects list is not a baseline" 1 "R6"

# H1-H9 — round-8 exhaustive field audit found NINE remaining holes in one pass, after four rounds
# of one-per-round trickle. The reframe ("audit every field, don't hand me the most important one")
# is what surfaced them; the per-round drip was a slow enumeration, not convergence.
mkuap 'standing_consent: {}'
printf 'classes: false\n' > "$TD/r.yaml"
lane "H1 a falsy \`classes\` is not laundered into an empty registry" 1 ""
printf 'classes:\n' > "$TD/r.yaml"
# Expectation changed 0 -> 3 with the R9-F4 exit contract. This is NOT a lane weakened to fit a
# change: the lane's own NAME says "N/A, not a clean PASS", and 0 was the clean-PASS code. It
# asserted the opposite of what it described, which is precisely the two-codes-three-states
# conflation F4 named. 3 is the code that finally means what this lane always claimed to test.
lane "H1-b a null \`classes\` is N/A (3), not a clean PASS" 3 ""
if grep -q 'N/A' "$TD/o"; then ok "H1-c the empty registry is LABELLED N/A"; else bad "H1-c empty registry read as clean"; fi

mkreg '  - {name: n, owner: o, mode: 123, target: t, capabilities: [read], sinks: [], feeds: [], promotion_eligible: true}'
lane "H2 a non-string scalar registry field is a type error" 1 "R1-b"
mkreg '  - {name: n, owner: o, mode: m, target: "", capabilities: [read], sinks: [], feeds: [], promotion_eligible: true}'
lane "H2-b a blank registry target is a type error" 1 "R1-b"
mkreg '  - {name: n, owner: o, mode: m, target: t, capabilities: [read], sinks: [123], feeds: [], promotion_eligible: false}'
lane "H3 an unreadable sink item is UNDECLARED, not an empty sink list" 1 "R1-b"

mkreg "$OKCLASS"
mkuap 'standing_consent:
  ok: {expires: 2026-12-31, effects: [read], target: t}'
lane "H5 a grant with no \`granted\` date cannot be audited" 1 "R5"
mkuap 'standing_consent:
  ok: {granted: 2026-07-29, expires: 29991231, effects: [read], target: t}'
lane "H7 a non-ISO integer expiry is not a date" 1 "R5"
mkuap 'standing_consent:
  ok: {granted: 2026-07-29, expires: 9999-12-31, effects: [read], target: t}'
lane "H7-b an unbounded lease is a transfer wearing a lease's clothes" 1 "R5"
mkuap 'standing_consent:
  ok: {state: revokedd, granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "H6 a typo'\''d state fails closed instead of passing as active" 1 "R3"
mkuap 'standing_consent:
  ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [repo-mutation], target: t}'
lane "H8 a grant wider than its registered capabilities is refused" 1 "R7"
mkuap 'standing_consent:
  ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: everything}'
lane "H8-b grant/class target drift is refused" 1 "R7"
mkuap 'standing_consent:
  ok: {granted: 2026-07-29, expires: 2020-01-01, effects: [read], target: t}
  ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "H9 duplicate YAML keys are rejected, not resolved last-wins" 1 ""

# H4 had a fix but NO lane — the mutation sweep caught that (disabling it failed zero lanes).
# An uncovered check is a check that gets deleted quietly later.
# NOTE the assertion is on the MESSAGE, not the rule id: with the type check disabled a numeric key
# still exits 1 via "not in the registry", so a rule-id assertion passed either way and the mutation
# sweep caught zero lanes. A lane that cannot separate two paths is not measuring the one it names.
mkuap 'standing_consent:
  123: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
bash "$CHK" "$TD/r.yaml" "$TD/u.md" >"$TD/o" 2>&1
if [ $? -eq 1 ] && grep -q 'grant key 123 must be a non-blank string' "$TD/o"; then
  ok "H4 a non-string grant key is refused AS A TYPE ERROR (not merely as unregistered)"
else
  bad "H4 numeric grant key was not refused by the type check"
  sed 's/^/     /' "$TD/o"
fi

mkreg '  - {name: c, owner: o, mode: m, target: t, capabilities: "read", sinks: [], feeds: [], promotion_eligible: true}'
mkuap 'standing_consent: {}'
lane "P9 a scalar where a list is required is a type error" 1 "R1-b"

# N4 — PINS A KNOWN OVER-BLOCK, it does not endorse it. A grant written with a YAML merge key is
# currently REFUSED because the anchor lives outside the extracted fragment (see the residual note
# in consent_registry_check.sh). This lane asserts the CURRENT behaviour so that a future fix shows
# up as a lane change rather than being rediscovered from scratch — and so nobody reads the 40/40
# as "no known over-block".
mkreg "$OKCLASS"
mkuap 'defaults: &d {ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}}
standing_consent:
  <<: *d'
bash "$CHK" "$TD/r.yaml" "$TD/u.md" >"$TD/o" 2>&1
if [ $? -eq 1 ]; then
  ok "N4 merge-key grant is refused — KNOWN OVER-BLOCK, pinned not endorsed (see residual note)"
else
  ok "N4 merge-key grant now PASSES — the over-block was fixed; update this lane and the residual note"
fi

rm -f "$TD/r.yaml"
# ── R9-F4 (2026-07-31) — N/A gets its OWN exit code. ────────────────────────────────────────────
# Three states (verified / unmeasured / broken) were encoded in two exit codes and disambiguated
# only in PROSE. The exit code is the only machine-readable channel, so a caller writing the
# conventional `if check; then run_unprompted; fi` treated "there is nothing to measure" as
# "verified, go ahead" — printing "(not a PASS)" disables nothing.
#
# The fix is NOT to return 1. A missing registry is the state of every fresh clone, and failing
# there would paint the gate red on first run and train the override reflex — a failure this
# checker's own comments already record twice. `1` must keep meaning BROKEN.
#
# 3 = UNMEASURED. The asymmetry that decides the direction: the fallback here is not "block", it is
# "ask the human". Consent promotion exists only to SKIP an approval prompt, so degrading to asking
# restores the system's original behaviour and widens human-in-the-loop authority rather than
# narrowing it. Degrading to exit 0 does the opposite — it removes a human decision no one granted.
lane "D1 a missing registry is UNMEASURED (3), not verified (0)" 3 ""
if grep -q 'N/A' "$TD/o"; then
  ok "D1-b the missing-registry result is LABELLED N/A, not reported as clean"
else
  bad "D1-b a missing registry produced no N/A label — that reads as PASS"
fi

printf 'classes: []\n' > "$TD/r.yaml"
mkuap 'standing_consent: {}'
lane "D1-c a registry with zero classes is UNMEASURED (3)" 3 ""

mkreg "$OKCLASS"
rm -f "$TD/u.md"
lane "D1-d a missing UAP is UNMEASURED (3) — no grants is not a verified pass" 3 ""

# The contract's whole point: 0 must be reachable ONLY by a real join. If this lane and D1* ever
# return the same code again, the channel has collapsed back into prose.
mkreg "$OKCLASS"
mkuap 'standing_consent:
  ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "D1-e 0 still means VERIFIED, and only that" 0 ""

printf 'classes: [ {name: broken\n' > "$TD/r.yaml"
lane "D2 an unparseable registry fails closed (cannot decide == not allowed)" 1 ""

# ── R9 (2026-07-31, cross-family codex @ gpt-5.6-sol) — the floor read the wrong field. ──────────
# R2 intersected IRREVERSIBLE with `sinks | feeds` and NEVER with `capabilities`, so a class could
# DECLARE an irreversible capability outright and still be promotable as long as it named no sink.
# Grepped to be sure before fixing: IRREVERSIBLE appeared in exactly one place in the checker, and
# its only operand was the sink/feed union. R2's own comment gives the reason away — it says
# "naming an irreversible SINK two fields above" — the guard was written against the sink field and
# the capability field was never in scope.
#
# The local canary (qwen3.6:27b, same prompt, adequate budget) returned CONVERGED on this same diff.
# Taking that as the verdict would have declared convergence on a floor that lets history-rewrite
# through — which is exactly why the doctrine calls local tier evidence-of and never terminal.
mkreg '  - {name: rewrite, owner: o, mode: m, target: t, capabilities: [history-rewrite], sinks: [], feeds: [], promotion_eligible: true}'
mkuap 'standing_consent:
  rewrite: {granted: 2026-07-29, expires: 2026-12-31, effects: [history-rewrite], target: t}'
lane "R9-1 a declared irreversible CAPABILITY is not promotable, empty sinks or not" 1 "R2-b"

# The same class WITHOUT the promotion claim is fine: declaring an irreversible capability is not
# itself an error, and blocking it would over-block a registry that merely describes what a class
# can do. Over-blocking trains the override reflex — the checker already records one such revert.
mkreg '  - {name: rewrite, owner: o, mode: m, target: t, capabilities: [history-rewrite], sinks: [], feeds: [], promotion_eligible: false}'
mkuap 'standing_consent: {}'
lane "R9-1b the same irreversible capability is fine when not claimed promotable" 0 ""

# `unknown` is in IRREVERSIBLE for the sink rule ("unlisted sinks are UNKNOWN, and unknown is not
# reversible"); it must mean the same thing in the capability position.
mkreg '  - {name: u, owner: o, mode: m, target: t, capabilities: [unknown], sinks: [], feeds: [], promotion_eligible: true}'
mkuap 'standing_consent: {}'
lane "R9-1c an `unknown` capability is not promotable either" 1 "R2-b"

# Guard against over-reach in the other direction: an ordinary reversible capability with empty
# sinks is the N1 shape and must stay passing. If this lane ever flips, the fix went too wide.
mkreg "$OKCLASS"
mkuap 'standing_consent:
  ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "R9-1d a reversible capability with empty sinks still passes (anti-over-block)" 0 ""

# R9-1e — the SAME field must be normalised the SAME way by every rule that reads it. R7 compares
# capabilities through `_norm` (which strips surrounding whitespace); the first cut of R2-b compared
# raw `str(x)`, so ` history-rewrite ` slipped past R2-b while R7 still recognised it — one field,
# two spellings, which is the divergent-normalizer class psa_scan_lib.sh's header is entirely about.
# Caught reviewing the diff before merge, not by the lanes above.
mkreg '  - {name: w, owner: o, mode: m, target: t, capabilities: [" history-rewrite "], sinks: [], feeds: [], promotion_eligible: true}'
mkuap 'standing_consent: {}'
lane "R9-1e whitespace around an irreversible capability does not evade R2-b" 1 "R2-b"

# The shipped example must satisfy the validator — otherwise the artifact FH hands users is the
# first counter-example. (Hand-verify-one-sample discipline, applied to our own template.)
if bash "$CHK" "$ROOT/templates/consent_classes.yaml.example" /dev/null >/dev/null 2>&1; then
  ok "S1 the shipped templates/consent_classes.yaml.example validates"
else
  bad "S1 the shipped example registry does NOT validate"
fi

echo "----"
echo "consent-registry anchor: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
