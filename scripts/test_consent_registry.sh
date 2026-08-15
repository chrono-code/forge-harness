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
# The UAP machine region is YAML FRONTMATTER (storage-form change 2026-07-31). A fixture body is the
# frontmatter payload, so every grant-semantics lane below stays written exactly as before and keeps
# testing what it tested. Lanes that exercise the storage form itself write their own file directly
# and do not go through this helper.
mkuap() { printf -- '---\n%s\n---\n\n# UAP (fixture)\n\nprose below the machine region.\n' "$1" > "$TD/u.md"; }
# Raw writer for storage-form lanes — no frontmatter wrapping, byte-exact.
mkuap_raw() { printf '%s\n' "$1" > "$TD/u.md"; }

mkreg "$OKCLASS"
mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "N1 a well-formed registry + eligible unexpired scoped grant passes" 0 ""

mkuap 'standing_consent:
  ok: declined'
# EXPECTATION CHANGED 0 -> 3 (F4-b, 2026-07-31). A `declined` record is still a valid non-grant
# state and still must not be a VIOLATION — that half of the lane is unchanged and is what the
# 3-vs-1 distinction now asserts. What changed is that "the user said no" may not be reported
# through the same channel as "the user said yes": exit 0 is the only code a caller may skip a
# prompt on, and a file recording nothing but refusals has granted nothing.
lane "N2 a declined record is a non-grant state (3), never a malformed grant (1)" 3 ""

mkreg '  - {name: s, owner: o, mode: m, target: t, capabilities: [read], sinks: [go-public], feeds: [], promotion_eligible: true}'
mkuap 'standing_consent: {}'
lane "P1 a class naming an irreversible SINK cannot declare itself promotable" 1 "R2"

mkreg '  - {name: f, owner: o, mode: m, target: t, capabilities: [read], sinks: [], feeds: [go-public], promotion_eligible: true}'
lane "P2 taint — a class that FEEDS an irreversible sink cannot be promotable" 1 "R2"

mkreg "$OKCLASS"
mkuap 'standing_consent:
  ghost: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "P3 a grant on an unregistered class is refused (unregistered == unknown)" 1 "R3"

mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-01-01, expires: 2026-06-30, effects: [read], target: t}'
lane "P4 an expired lease does not keep running" 1 "R5"

mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31}'
lane "P5 a grant with no recorded scope has no re-validation baseline" 1 "R6"

# P6-P8 are the round-3 fail-opens. Each of these PASSED before the fix.
mkreg '  - {name: q, owner: o, mode: m, target: t, capabilities: [read], sinks: [], feeds: [], promotion_eligible: "false"}'
mkuap 'standing_consent:
  q: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "P6 quoted \"false\" is rejected as a type error, not read as truthy" 1 "R1-b"

mkreg '  - {name: d, owner: o, mode: m, target: t, capabilities: [read], sinks: [go-public], feeds: [], promotion_eligible: false}
  - {name: d, owner: o, mode: m, target: t, capabilities: [read], sinks: [], feeds: [], promotion_eligible: true}'
mkuap 'standing_consent:
  d: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "P7 a duplicate class name cannot launder an ineligible class" 1 "R1-c"

mkreg "$OKCLASS"
mkuap 'standing_consent: {ok: {owner: o, mode: m, sinks: [], granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}}'
lane "P8 an INLINE grant is parsed, not silently read as 'nothing granted'" 1 "R5"

# P10-P11 are the round-4 fail-opens. Both PASSED before the fix, and both were confirmed against a
# control: the SAME expired grant was caught when it stood alone.
mkreg "$OKCLASS"
mkuap 'standing_consent: {}

notes in between

standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}'
lane "P10 an early empty consent block cannot shadow a later grant (first-match)" 1 "R3"

mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], state: "revoked ", granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
# ASSERTION REWRITTEN 2026-07-31 (F4-b). This lane read the VERDICT out of prose ("0 active grant")
# through a pipe, which is both the grep-a-prose-verdict pattern this repo has a memory entry
# against and — via the pipe — a read of grep's status, not the checker's. It now asserts the typed
# channel: a normalized `revoked ` leaves zero active grants, which is exit 3, not 0 and not 1.
bash "$CHK" "$TD/r.yaml" "$TD/u.md" >"$TD/o" 2>&1; rc=$?
if [ "$rc" -eq 3 ] && grep -q "NONE of them an active grant" "$TD/o"; then
  ok "P11 a mapping non-grant state is normalized like the scalar one (no divergent normalizer)"
else
  bad "P11 \`state: \"revoked \"\` was not normalized to a non-grant (exit $rc, expected 3)"
  sed 's/^/     /' "$TD/o"
fi

# P12 is the round-5 fail-open: `or {}` collapsed FALSY non-mappings into a valid-empty mapping
# before the type check, so `[]`, `false` and `0` all reported "no standing consent" and exit 0 —
# while the truthy `[a, b]` was caught. The falsy branch is the one an accident actually produces.
# FIXTURE FIX 2026-07-31 (cross-family): this loop wrote the UAP directly, so after the storage-form
# change it had no frontmatter and every case exited 1 via the "grant in prose" net — the right code
# for the WRONG REASON, which meant the falsy-type check it exists to guard was no longer exercised
# at all. Same shape as the defect the suite is about: a green lane that stopped measuring its
# subject. Routed through mkuap so the value lands inside the machine region.
for badval in '  []' '  false' '  0'; do
  mkreg "$OKCLASS"
  mkuap "$(printf 'standing_consent:\n%s' "$badval")"
  lane "P12 a falsy non-mapping standing_consent ($badval) is a type error, not 'none granted'" 1 "R3"
done

# P13/N3 — round-6 fail-open: `standing_consent :` (space or tab before the colon) is the SAME YAML
# key but matched none of the patterns. Standalone it still failed closed via the no-known-form net;
# paired with a normal empty block it was invisible to both the count and the extraction, so the
# empty block parsed and the real grant vanished. Confirmed against a control (the identical expired
# grant in canonical form was caught).
mkreg "$OKCLASS"
mkuap 'standing_consent: {}

standing_consent : {ok: {owner: o, mode: m, sinks: [], granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}}'
lane "P13 a space-before-colon key cannot hide behind a canonical block" 1 "R3"

mkuap 'standing_consent :
  ok: {owner: o, mode: m, sinks: [], granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}'
lane "P13-b a space-before-colon BLOCK form is parsed and its grant validated" 1 "R5"

# N3 EXPECTATION INVERTED 2026-07-31 — and the reason is the whole point of the storage-form change.
# The slicer-era comment asserted that `standing_consent\t:` "is the SAME YAML key" as
# `standing_consent:`, and this lane pinned a PASS on that belief. The canonical loader refuses it:
# PyYAML rejects a tab there with a ScannerError, because YAML forbids tabs as structural whitespace.
# So the belief was false, and a regex that approximates the YAML spec had been quietly ratifying a
# document the spec rejects. Handing the region to the real loader replaces a guess with an answer —
# a malformed document is now BROKEN (fail-closed), not silently accepted as equivalent.
mkuap "$(printf 'standing_consent\t: {ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}}')"
lane "N3 a tab-before-colon key is invalid YAML and fails closed (loader, not regex, decides)" 1 "R3"

# P14 — round-7 fail-open: R6 presence-checked `effects`/`target` but never typed them, while the
# registry side had strict types since R1-b. A fix propagated to one side only is a hole. Control:
# a MISSING field was caught; a type-wrong one passed.
mkreg "$OKCLASS"
mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: true, target: 123}'
lane "P14 a type-wrong grant scope is rejected, not counted as recorded" 1 "R6"

mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: "read", target: "  "}'
lane "P14-b a scalar effects / whitespace-only target is rejected" 1 "R6"

mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [], target: t}'
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
  ok: {owner: o, mode: m, sinks: [], expires: 2026-12-31, effects: [read], target: t}'
lane "H5 a grant with no \`granted\` date cannot be audited" 1 "R5"
mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 29991231, effects: [read], target: t}'
lane "H7 a non-ISO integer expiry is not a date" 1 "R5"
mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 9999-12-31, effects: [read], target: t}'
lane "H7-b an unbounded lease is a transfer wearing a lease's clothes" 1 "R5"
mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], state: revokedd, granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "H6 a typo'\''d state fails closed instead of passing as active" 1 "R3"
mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [repo-mutation], target: t}'
lane "H8 a grant wider than its registered capabilities is refused" 1 "R7"
mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: everything}'
lane "H8-b grant/class target drift is refused" 1 "R7"
mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2020-01-01, effects: [read], target: t}
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "H9 duplicate YAML keys are rejected, not resolved last-wins" 1 ""

# H4 had a fix but NO lane — the mutation sweep caught that (disabling it failed zero lanes).
# An uncovered check is a check that gets deleted quietly later.
# NOTE the assertion is on the MESSAGE, not the rule id: with the type check disabled a numeric key
# still exits 1 via "not in the registry", so a rule-id assertion passed either way and the mutation
# sweep caught zero lanes. A lane that cannot separate two paths is not measuring the one it names.
mkuap 'standing_consent:
  123: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
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
mkuap 'defaults: &d {ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}}
standing_consent:
  <<: *d'
# N4 REMOVED 2026-07-31 — it called ok() in BOTH branches, so it passed on every possible exit code
# and could not fail. A lane that cannot fail measures nothing while adding a green tick, which is
# the false-clean this suite exists to prevent (cross-family review caught it; it had been reporting
# green in a 49-lane run all along). The over-block it pinned is now GONE and is asserted for real
# by lane F4, which requires exit 0 rather than accepting anything.
lane "N4 (retired — see F4, which asserts the merge-key grant actually passes)" 0 ""

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
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
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
  rewrite: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [history-rewrite], target: t}'
lane "R9-1 a declared irreversible CAPABILITY is not promotable, empty sinks or not" 1 "R2-b"

# The same class WITHOUT the promotion claim is fine: declaring an irreversible capability is not
# itself an error, and blocking it would over-block a registry that merely describes what a class
# can do. Over-blocking trains the override reflex — the checker already records one such revert.
mkreg '  - {name: rewrite, owner: o, mode: m, target: t, capabilities: [history-rewrite], sinks: [], feeds: [], promotion_eligible: false}'
mkuap 'standing_consent: {}'
# EXPECTATION CHANGED 0 -> 3 (F4-b): the anti-over-block point of this lane is that the registry
# must NOT be a violation, i.e. not 1. Its UAP grants nothing, so the join is empty -> UNMEASURED.
lane "R9-1b the same irreversible capability is not a violation when not claimed promotable" 3 ""

# `unknown` is in IRREVERSIBLE for the sink rule ("unlisted sinks are UNKNOWN, and unknown is not
# reversible"); it must mean the same thing in the capability position.
mkreg '  - {name: u, owner: o, mode: m, target: t, capabilities: [unknown], sinks: [], feeds: [], promotion_eligible: true}'
mkuap 'standing_consent: {}'
lane "R9-1c an \`unknown\` capability is not promotable either" 1 "R2-b"

# Guard against over-reach in the other direction: an ordinary reversible capability with empty
# sinks is the N1 shape and must stay passing. If this lane ever flips, the fix went too wide.
mkreg "$OKCLASS"
mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
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
# ASSERTION REWRITTEN 2026-07-31 (F4-b). This lane used the bare-command form — precisely the
# `if check; then ...` convention finding F4 identified as the fail-open — so it asked "is the exit
# status truthy?" when the question is "is the REGISTRY broken?". With no grants to join the answer
# is now 3 (UNMEASURED), which is a correct verdict about the grants and says nothing bad about the
# registry. 1 is the only code that means the shipped example is invalid.
bash "$CHK" "$ROOT/templates/consent_classes.yaml.example" /dev/null >"$TD/o" 2>&1; rc=$?
if [ "$rc" -ne 1 ]; then
  ok "S1 the shipped templates/consent_classes.yaml.example validates (exit $rc, not BROKEN)"
else
  bad "S1 the shipped example registry does NOT validate"
  sed 's/^/     /' "$TD/o"
fi

# ---- F: STORAGE FORM (frontmatter) -------------------------------------------------
# These lanes test the machine-region boundary itself, not grant semantics, so they write the UAP
# byte-exact via mkuap_raw instead of going through the frontmatter-wrapping helper.
mkreg "$OKCLASS"
GRANT='  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'

# F1/F2 are the two false-clean shapes, and they are the reason this section exists. A grant that
# sits where no parser reads it must never report as "nothing granted" — an unread grant is not an
# absent one. This is the ONE net carried over from the slicer, generalized to the new form.
mkuap_raw "$(printf '# UAP\n\nstanding_consent:\n%s\n' "$GRANT")"
lane "F1 a grant in prose with NO frontmatter fails closed (never 'nothing granted')" 1 "R3"

mkuap_raw "$(printf -- '---\nsidecar_consent: granted\n---\n\n# UAP\n\nstanding_consent:\n%s\n' "$GRANT")"
lane "F2 frontmatter exists but the grant was written BELOW it — fails closed" 1 "R3"

# F3 is the anti-over-block control for F1: absence must stay cheap. A UAP predating this format has
# no machine region and grants nothing; painting that red would train the override reflex.
mkuap_raw "$(printf '# UAP\n\nno machine region here, and nothing granted.\n')"
# EXPECTATION CHANGED 0 -> 3 (F4-b). "Absence must stay cheap" is preserved exactly: 3 is not red,
# it is N/A. What it no longer does is answer the conventional `if check; then run_unprompted; fi`
# with success on a UAP that granted nothing at all.
lane "F3 no frontmatter and no grant mentioned is nothing granted (3, not a failure)" 3 ""

# F4 pins the OVER-BLOCK THIS CHANGE RETIRES. Under the slicer a merge-key grant was refused because
# the anchor lived outside the extracted fragment; the fragment is now the whole document, so
# ordinary DRY YAML resolves. Over-blocking was a defect of the same weight as a fail-open.
mkuap_raw "$(printf -- '---\ndefaults: &d {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}\nstanding_consent:\n  ok:\n    <<: *d\n---\n')"
lane "F4 a merge-key/anchor grant now resolves (the measured over-block is retired)" 0 ""

# F5 — duplicate keys stay rejected on this side too. safe_load is last-wins, so an expired grant
# followed by a future one would silently keep the future one.
mkuap_raw "$(printf -- '---\nstanding_consent:\n  ok: {owner: o, mode: m, sinks: [], granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}\n  ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}\n---\n')"
lane "F5 duplicate grant keys are refused, not last-wins" 1 "R3"

# F6 — a leading BOM must not make the machine region look absent. Without the tolerance this still
# fails closed, i.e. safe, but for a misleading reason, and a confusing gate gets overridden.
mkuap_raw "$(printf -- '\357\273\277---\nstanding_consent:\n%s\n---\n' "$GRANT")"
lane "F6 a BOM before the frontmatter does not hide the machine region" 0 ""

# F7 — the region must be a mapping. A list parses fine as YAML and would otherwise be read for a
# `standing_consent` key it can never have.
mkuap_raw "$(printf -- '---\n- a\n- b\n---\n\nstanding_consent: whatever\n')"
lane "F7 a non-mapping frontmatter is BROKEN, not an empty grant set" 1 "R3"

# F8 — an unterminated block is not frontmatter. It then falls to the F1 net, which is the correct
# landing: the grant is unread, so fail closed.
mkuap_raw "$(printf -- '---\nstanding_consent:\n%s\n' "$GRANT")"
lane "F8 an unterminated --- block is not a machine region and fails closed" 1 "R3"

# F9 — an empty machine region is a real empty set, not a parse failure.
# NOTE (cross-family 2026-07-31): this lane was PASSING FOR THE WRONG REASON. The first regex could
# not match `---\n---` at all, so the file fell through to "no frontmatter, nothing mentioned" and
# went green without the empty-region path ever running. Lane F9-b below is its control: same empty
# region, but WITH a prose mention, which can only stay green if the region was really recognized.
mkuap_raw "$(printf -- '---\n---\n\n# UAP\n')"
# EXPECTATION CHANGED 0 -> 3 (F4-b): still not an error (not 1), but an empty region grants nothing.
lane "F9 an empty frontmatter block grants nothing (3) and is not an error (1)" 3 ""

# F9-b — the discriminating control for F9. If the empty region is NOT recognized, this file reads as
# "no frontmatter + standing_consent mentioned" and fails closed via F1. Green here means the empty
# frontmatter was genuinely parsed. (Without this control F9 cannot tell the two paths apart.)
mkuap_raw "$(printf -- '---\n---\n\n# UAP\n\nthe key name standing_consent appears in prose but not as a key.\n')"
# EXPECTATION CHANGED 0 -> 3 (F4-b). The discriminating power of this control is UNCHANGED: if the
# empty region were not recognized, this file would fail CLOSED via the F1 net at exit 1, which is
# still distinct from the 3 asserted here.
lane "F9-b empty region + a prose MENTION is still nothing granted (region truly parsed)" 3 ""

# F10-F13 — YAML stream forms the canonical loader accepts and the first fence regex rejected. Each
# failed CLOSED (no leak) but as an OVER-BLOCK whose message blamed an absent frontmatter that was
# present. A gate that misdirects the fix gets overridden, so these are lanes, not footnotes.
EXPIRED='  ok: {owner: o, mode: m, sinks: [], granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}'
mkreg "$OKCLASS"
mkuap_raw "$(printf -- '---\nstanding_consent:\n%s\n...\n' "$EXPIRED")"
lane "F10 a '...' document terminator closes the machine region (grant is READ, then R5-caught)" 1 "R5"

mkuap_raw "$(printf -- '--- # metadata\nstanding_consent:\n%s\n---\n' "$EXPIRED")"
lane "F11 a comment on the opening fence does not hide the region" 1 "R5"

mkuap_raw "$(printf -- '---\nstanding_consent:\n%s\n--- # end\n' "$EXPIRED")"
lane "F12 a comment on the closing fence does not hide the region" 1 "R5"

mkuap_raw "$(printf -- '%%YAML 1.2\n---\nstanding_consent:\n%s\n...\n' "$EXPIRED")"
lane "F13 a %YAML directive before the fence does not hide the region" 1 "R5"

# F14 — quoted key spelling in prose. YAML reads `"standing_consent":` as the same key, so the
# prose-region net must see it too; an anchored bare-key-only net missed it while the F1 net caught
# it, i.e. the two nets disagreed on one input.
mkuap_raw "$(printf -- '---\nsidecar_consent: granted\n---\n\n# UAP\n\n"standing_consent":\n%s\n' "$EXPIRED")"
lane "F14 a QUOTED grant key in the prose region is caught too (nets agree)" 1 "R3"

# ---- R9-F3: THE FINGERPRINT WAS A PARTIAL HASH ------------------------------------
# Cross-family round 9 (codex @ gpt-5.6-sol). The rule says consent binds to the action's SHAPE and
# enumerates that shape — "the owning gate/skill, and the set of effect classes ... plus the
# `target` scope and the `sinks` fingerprint", offered to the user as `<mode · target ·
# capabilities · sinks>`. The baseline the checker recorded was `effects` + `target` ONLY.
# So the fields that say WHO acts (`owner`) and WHAT IT DOES when it acts (`mode`) were outside the
# floor: keep the class name, target, capabilities and empty sinks, swap the owner to a different
# skill, and R6 found its two fields present, R7 found the effects still a subset, and the gate
# returned 0 with the blast radius re-pointed under a live grant.
# The rule's own sentence is the indictment: "the name is exactly what does not change when the
# danger does" — and neither, it turned out, did anything the floor was reading.
# Each P-lane below was confirmed to return 0 before the fix and 1 after; each is paired with an
# anti-over-block N-lane so the check is calibrated on a known-negative, not only a known-positive.
FPGRANT='  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'

# P-F3a / P-F3b — the drift the review reproduced: same name, same target, same capabilities, same
# empty sinks; only the acting skill (or what it does) changed.
mkreg '  - {name: ok, owner: DANGEROUS-OTHER-SKILL, mode: m, target: t, capabilities: [read], sinks: [], feeds: [], promotion_eligible: true}'
mkuap "standing_consent:
$FPGRANT"
lane "P-F3a a class re-pointed to a different OWNER under a live grant is refused" 1 "R7"

mkreg '  - {name: ok, owner: o, mode: unrestricted, target: t, capabilities: [read], sinks: [], feeds: [], promotion_eligible: true}'
mkuap "standing_consent:
$FPGRANT"
lane "P-F3b a class whose MODE changed under a live grant is refused" 1 "R7"

# N-F3c — the control for both: an intact fingerprint must still pass. Without it P-F3a/b prove
# only that something fails, not that the owner/mode comparison is what fired.
mkreg "$OKCLASS"
mkuap "standing_consent:
$FPGRANT"
lane "N-F3c an intact owner/mode/target/sinks fingerprint still passes (anti-over-block)" 0 ""

# P-F3d — presence. A grant written without the fingerprint cannot detect drift in it later, which
# is the same argument R6 already made for effects/target and did not apply to the other three.
mkuap 'standing_consent:
  ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "P-F3d a grant recording no owner/mode/sinks has no fingerprint to compare" 1 "R6"

# N-F3e — the FALSY-LAUNDERING control, the defect class this file has now been bitten by three
# times. `sinks: []` is a REAL fingerprint ("this class crossed nothing at grant time") and must not
# collapse into "not recorded". If this lane ever goes red with an R6 sinks message, a sentinel
# check was replaced by a truthiness test.
mkuap "standing_consent:
$FPGRANT"
lane "N-F3e an EMPTY sinks list is a recorded fingerprint, not a missing one" 0 ""

# P-F3f/g — types. The registry side got strict types at R1-b and the grant side got them for
# effects/target at R6; the three new fields inherit the same rule rather than a laxer one.
mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: "go-public", granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "P-F3f a scalar sinks fingerprint is unreadable, and unreadable is undeclared" 1 "R6"

mkuap 'standing_consent:
  ok: {owner: "   ", mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "P-F3g a blank owner is not a recorded owner" 1 "R6"

# N-F3h — ONE normalizer, both sides. The registry side reads `owner` through _norm; if the grant
# side ever compares raw strings, ` o ` and `o` become two values and the gate fires on a file that
# did not drift. Divergent normalizers is exactly how R2-b was first written wrong.
mkuap 'standing_consent:
  ok: {owner: "  o  ", mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane "N-F3h whitespace around an owner is not drift (single normalizer, both sides)" 0 ""

# ---- R9-F4-b: THE SAME FAIL-OPEN, ONE BRANCH OVER ---------------------------------
# F4 gave "nothing to join" its own exit code for a MISSING registry, ZERO classes and a MISSING
# UAP — and left a PRESENT UAP holding ZERO grants returning 0. Identical state, two codes. Lane
# D1-d already asserted in its own name that "no grants is not a verified pass", and the EXIT
# CONTRACT already defined 3 as "there was nothing to join"; only the code disagreed. A caller
# writing `if scripts/consent_registry_check.sh; then run_unprompted; fi` ran unprompted against a
# profile that had granted it nothing.
mkreg "$OKCLASS"
mkuap 'standing_consent: {}'
lane "D3 a valid registry with an EXPLICITLY empty grant set is UNMEASURED (3)" 3 ""

# D3-b — the discriminating control. If D3 and this lane ever return the same code again, the typed
# channel has collapsed back into prose and 0 no longer means "a real grant was joined".
mkuap "standing_consent:
$FPGRANT"
lane "D3-b 0 is still reachable ONLY by joining a real grant" 0 ""

# D3-c — precedence. BROKEN outranks UNMEASURED: a registry violation is a decided negative, while
# "nothing granted" is merely nothing to join. Without this lane the F4-b change could silently
# convert a real violation into a soft N/A whenever the UAP happened to be empty.
mkreg '  - {name: ok, owner: o, mode: m, target: t, capabilities: [read], sinks: [], feeds: [], promotion_eligible: "false"}'
mkuap 'standing_consent: {}'
lane "D3-c a registry violation still outranks 'nothing granted' (1 beats 3)" 1 "R1-b"


# ── D3-d: the prose summary must agree with the typed exit ────────────────────
# A tail-reading operator saw "consent-registry: PASS" on a run that exited 3 and whose own line
# said "(not a PASS)". Machines read the code; humans read the last line. They must not disagree.
cat > "$TD/r.yaml" <<'YAML'
classes:
  - name: safe-thing
    owner: some-skill
    mode: readonly
    target: "tracks/_meta/**"
    capabilities: [read]
    effects: [read]
    sinks: []
    feeds: []
    promotion_eligible: true
YAML
printf -- '---\nstanding_consent: {}\n---\n' > "$TD/u.md"
bash "$CHK" "$TD/r.yaml" "$TD/u.md" >"$TD/o" 2>&1; _rc=$?
if [ "$_rc" -ne 0 ] && tail -1 "$TD/o" | grep -q '^consent-registry: PASS$'; then
  bad "D3-d prose summary says PASS while the typed exit is $_rc"
else
  ok "D3-d prose summary agrees with the typed exit (rc=$_rc)"
fi


# ── P-VOCAB: the irreversible vocabulary must not be evadable by case or invisible characters ──
# Carried for two sessions as a named residual ("_norm does not case-fold"). A cross-family round
# MEASURED it as a live fail-open: a class whose capability is a history rewrite was PASSing and
# therefore promotable. Each variant below returned rc=0 before the fix.
for _v in 'History-Rewrite' 'HISTORY-REWRITE' 'local-wrtie'; do
  cat > "$TD/r.yaml" <<YAML
classes:
  - name: rewrite
    owner: o
    mode: m
    target: t
    capabilities: ["$_v"]
    effects: [read]
    sinks: []
    feeds: []
    promotion_eligible: true
YAML
  cat > "$TD/u.md" <<'YAML'
---
standing_consent:
  rewrite: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}
---
YAML
  bash "$CHK" "$TD/r.yaml" "$TD/u.md" >"$TD/o" 2>&1; _rc=$?
  # Assert the RULE, not merely a non-zero exit. These fixtures also trip R7 (their grant effect is
  # not a subset of the malformed capability list), so "exit != 0" would have passed even with the
  # vocabulary check removed — right answer, wrong reason, which is the shape this suite's own
  # lane() helper exists to reject. (Partial vacuity found by cross-family round 2.)
  if [ "$_rc" -eq 0 ]; then bad "P-VOCAB '$_v' still PASSes (irreversible/unknown floor evaded)"
  elif grep -qE '❌ (R2-b|R2-c)' "$TD/o"; then ok "P-VOCAB '$_v' refused BY THE FLOOR (R2-b/R2-c)"
  else bad "P-VOCAB '$_v' refused, but not by R2-b/R2-c — the vocabulary check was not the reason"; fi
done

# N-VOCAB: the anti-over-block control. A class using ONLY declared capabilities must still pass —
# a vocabulary check that refuses legitimate input teaches bypass and is a defect of equal rank.
cat > "$TD/r.yaml" <<'YAML'
classes:
  - name: ok-class
    owner: o
    mode: m
    target: t
    capabilities: [read, local-write, network, dispatch, repo-mutation]
    effects: [read]
    sinks: []
    feeds: []
    promotion_eligible: true
YAML
cat > "$TD/u.md" <<'YAML'
---
standing_consent:
  ok-class: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}
---
YAML
lane "N-VOCAB every declared capability is still accepted (no over-block)" 0 ""

# ── D4: BROKEN outranks UNMEASURED even at the zero-class early return ──
printf 'classes: []\n' > "$TD/r.yaml"
cat > "$TD/u.md" <<'YAML'
---
standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}
---
YAML
lane "D4  live grant + zero registered classes = BROKEN (1), not 'nothing to join' (3)" 1 ""
printf 'classes: []\n' > "$TD/r.yaml"
printf -- '---\nstanding_consent: {}\n---\n' > "$TD/u.md"
lane "D4-b no grant + zero classes is still UNMEASURED (3) — the discriminating control" 3 ""

# ── K1: KNOWN OVER-BLOCK, pinned as known, NOT as correct ─────────────────────
# A canonical YAML merge-key override (`<<: *anchor` then a field override) is reported as a
# duplicate key and refused. This is a REAL over-block. It is pinned rather than fixed because the
# one attempt to rewrite the parser regressed 16 of 41 lanes and was reverted in the same session;
# the fix belongs in its own change with its own lanes. If this lane ever flips to rc=0, the
# over-block was fixed — update the label, do not silence it.
cat > "$TD/r.yaml" <<'YAML'
classes:
  - name: ok
    owner: o
    mode: m
    target: t
    capabilities: [read]
    effects: [read]
    sinks: []
    feeds: []
    promotion_eligible: true
YAML
cat > "$TD/u.md" <<'YAML'
---
defaults: &d {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: WRONG}
standing_consent:
  ok:
    <<: *d
    target: t
---
YAML
# PROMOTED from "known over-block, pinned not endorsed" to a real assertion (2026-08-02). The
# over-block was closed by moving duplicate detection BEFORE merge resolution — a reorder, not the
# parser rewrite that regressed 16 of 41 lanes. Both directions are asserted: a canonical override is
# accepted here, and K1-b below keeps the literal-duplicate detection it was protecting.
lane "K1  a canonical YAML merge-key override is ACCEPTED (over-block closed)" 0 ""

cat > "$TD/u.md" <<'YAML'
---
standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}
---
YAML
lane "K1-b a LITERAL duplicate key is still fail-closed (the paired control)" 1 ""



# ── N-SPELL / P-SPELL: effects⊆capabilities is a VOCABULARY question ────────────
# Splitting the normalizer by purpose fixed a fail-open and opened an over-block: this comparison was
# left on the identity normalizer, so `capabilities: [READ]` with a grant `effects: [read]` — the same
# effect class, spelled differently — was refused. Over-blocking is not a safe default; a gate that
# refuses correct input is one the operator learns to route around. Both directions are pinned so a
# future normalizer change cannot fix one by breaking the other.
cat > "$TD/r.yaml" <<'YAML'
classes:
  - name: c
    owner: o
    mode: m
    target: t
    capabilities: [READ]
    effects: [READ]
    sinks: []
    feeds: []
    promotion_eligible: true
YAML
cat > "$TD/u.md" <<'YAML'
---
standing_consent:
  c: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}
---
YAML
lane "N-SPELL a spelling variant of the SAME effect class is accepted (no over-block)" 0 ""

cat > "$TD/r.yaml" <<'YAML'
classes:
  - name: c
    owner: o
    mode: m
    target: t
    capabilities: [read]
    effects: [read]
    sinks: []
    feeds: []
    promotion_eligible: true
YAML
cat > "$TD/u.md" <<'YAML'
---
standing_consent:
  c: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [delete], target: t}
---
YAML
lane "P-SPELL a grant WIDER than its class is still refused (the paired control)" 1 "R7"


# ── PROV : every verdict states what it measured WITH, and it states the TRUTH ──────────────────
# 2026-08-12. This gate rides selfcheck → prepublishOnly. A release shipped green from a session whose
# `python3` resolved to an unrelated project's venv that had PyYAML, while the machine's own python3
# did not. Nothing was bypassed — the PASS was simply not portable, and said nothing about what
# produced it.
#
# 🟥 The first version of this lane compared two arms, one of them "PyYAML hidden" via
# `env -i PATH=/usr/bin:/bin PYTHONNOUSERSITE=1`. It passed locally and FAILED IN CI — because
# `PYTHONNOUSERSITE` suppresses only the USER site directory. On this author's machine PyYAML was a
# `--user` install so it hid; on the CI runner it is a system `dist-packages` install so it did not,
# both arms returned the same value, and the lane called its own subject decorative.
# **The control worked only by accident of how the author happened to install a package** — which is
# the exact defect class the subject under test exists to catch, reproduced inside its own lane.
#
# So the lane no longer manufactures an environment. It compares the reported value against an
# INDEPENDENT ORACLE computed in the same run: whatever `find_spec` says here, the instrument line
# must say the same thing. That catches removal, hard-coding, truncation, and drift — everywhere,
# with no assumption about how PyYAML got installed.
_prov_line=$(bash "$CHK" 2>&1 | grep -o 'instrument (consent-registry): .*' | head -1)
_prov_oracle=$(python3 - <<'ORACLE' 2>/dev/null
import importlib.util, sys
s = importlib.util.find_spec("yaml")
print((s.origin or "namespace-package") if s is not None else "ABSENT")
ORACLE
)
if [ -z "$_prov_line" ]; then
  echo "  ❌ PROV-1 no instrument line on the ordinary path"; fail=$((fail+1))
elif [ -z "$_prov_oracle" ]; then
  echo "  ❌ PROV-1 oracle produced nothing — NOT RUN (unmeasured, not a pass)"; fail=$((fail+1))
elif ! printf '%s' "$_prov_line" | grep -q ': /'; then
  echo "  ❌ PROV-1 line does not name an absolute interpreter path: [$_prov_line]"; fail=$((fail+1))
elif ! printf '%s' "$_prov_line" | grep -qF "PyYAML $_prov_oracle"; then
  echo "  ❌ PROV-1 line disagrees with the oracle — reported [$_prov_line] vs actual [$_prov_oracle]"; fail=$((fail+1))
else
  echo "  ✅ PROV-1 instrument line matches an independent resolution of PyYAML [$_prov_oracle]"; pass=$((pass+1))
fi

# PROV-2 — the ABSENT branch, exercised DETERMINISTICALLY rather than by hiding a package.
# A `yaml.py` MODULE FILE placed first on PYTHONPATH wins by path order, so find_spec resolves to it
# — a different, predictable answer that does not depend on how the real PyYAML was installed.
# ⚠️ A `yaml/` DIRECTORY does NOT work and the first draft used one: a namespace package has LOWER
# precedence than a regular package, so Python keeps scanning the whole path and still finds the real
# one. Measured — the arm did not move, and the lane correctly called itself decorative.
_prov_tmp=$(mktemp -d); printf '# shadow module for the PROV-2 arm\n' > "$_prov_tmp/yaml.py"
_prov_shadow=$(PYTHONPATH="$_prov_tmp" bash "$CHK" 2>&1 | grep -o 'instrument (consent-registry): .*' | head -1)
rm -rf "$_prov_tmp"
if [ -z "$_prov_shadow" ]; then
  echo "  ❌ PROV-2 no instrument line under a shadowed yaml"; fail=$((fail+1))
elif [ "$_prov_shadow" = "$_prov_line" ]; then
  echo "  ❌ PROV-2 line did not move when the resolution moved — decorative [$_prov_line]"; fail=$((fail+1))
else
  echo "  ✅ PROV-2 line tracks the resolution when it changes (shadowed → different value)"; pass=$((pass+1))
fi

# ---- RC: --require-class — narrowing the verdict from the FILE to ONE CLASS ---------
# Added 2026-08-16 after a pre-publish security pass found the caller side broken: fh_node_check.sh
# gated a consumer-machine `git merge --ff-only` on this script's FILE-WIDE 0 plus a raw grep for
# the class name anywhere in the UAP. One unrelated validly-granted class, plus the target class
# appearing only in a prose line saying it was REVOKED, satisfied both — the merge ran and the
# banner reported a standing consent that did not exist.
# Every lane below is a REFUSAL that leaves the file-wide verdict at 0. That property is asserted,
# not assumed: without it these lanes would pass for the same reason the existing "nothing granted"
# lanes do, and the class-join axis would go unexercised a second time.
lane_args() {  # desc want_rc [args...] — same as lane() but the flag order is the point
  local desc="$1" want_rc="$2"; shift 2
  bash "$CHK" "$@" >"$TD/o" 2>&1
  local rc=$?
  if [ "$rc" -ne "$want_rc" ]; then
    bad "$desc — exit $rc, expected $want_rc"; sed 's/^/     /' "$TD/o"; return
  fi
  ok "$desc"
}

TWOCLASS="$OKCLASS
  - {name: other, owner: o2, mode: m2, target: t2, capabilities: [read], sinks: [], feeds: [], promotion_eligible: true}"

# a) the class IS granted → 0
mkreg "$TWOCLASS"
mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane_args "RC-a --require-class on a class that IS granted → 0" 0 --require-class ok "$TD/r.yaml" "$TD/u.md"

# b) a DIFFERENT class is granted, the target appears only as prose → 3, file-wide still 0
mkreg "$TWOCLASS"
printf -- '---\nstanding_consent:\n  other: {owner: o2, mode: m2, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t2}\n---\n\n# UAP (fixture)\n\n  ok: 안 쓰기로 했다 (revoked)\n' > "$TD/u.md"
bash "$CHK" "$TD/r.yaml" "$TD/u.md" >/dev/null 2>&1; _fw=$?
lane_args "RC-b another class granted, target only in prose → 3" 3 --require-class ok "$TD/r.yaml" "$TD/u.md"
[ "$_fw" -eq 0 ] \
  && ok "RC-b DISCRIMINATION: the file-wide verdict is still 0, so RC-b refused on the class join" \
  || bad "RC-b VACUOUS: file-wide verdict was $_fw — this lane re-tests an existing axis, not the class join"

# c) the ON switch must not be silently OFF. A whitespace-only name passed a `-z` test in the first
#    draft and then strip()ed to empty, disabling the narrowing and returning the file-wide 0.
lane_args "RC-c whitespace-only class name → 1 (fail-closed, never a silent fall-back)" 1 --require-class "   " "$TD/r.yaml" "$TD/u.md"
lane_args "RC-d --require-class= empty form → 1" 1 --require-class= "$TD/r.yaml" "$TD/u.md"

# e) flag position. The first draft read argv[1] only, so a caller appending the flag got the old
#    file-wide 0 with no warning — the failure mode is silence, which is why this is a lane.
lane_args "RC-e flag AFTER the paths is still honoured → 3" 3 "$TD/r.yaml" "$TD/u.md" --require-class ok
lane_args "RC-f --require-class=NAME form is honoured → 3" 3 --require-class=ok "$TD/r.yaml" "$TD/u.md"

# g) an unknown option must not be swallowed as a path
lane_args "RC-g unknown option → 1, not consumed as a path" 1 --bogus "$TD/r.yaml" "$TD/u.md"

# h) the human summary must agree with the typed exit — this file's own rule, applied to the new path
bash "$CHK" --require-class ok "$TD/r.yaml" "$TD/u.md" >"$TD/o" 2>&1
if grep -qE '^consent-registry: UNMEASURED for class `ok`' "$TD/o" && ! grep -qE '^consent-registry: PASS$' "$TD/o"; then
  ok "RC-h summary agrees with the typed exit (no bare PASS above an exit-3 verdict)"
else
  bad "RC-h summary contradicts the verdict"; sed 's/^/     /' "$TD/o"
fi

# i) no flag → behaviour unchanged. Backward compatibility is a claim, so it gets a lane.
lane_args "RC-i no flag → file-wide verdict unchanged (0)" 0 "$TD/r.yaml" "$TD/u.md"

# j) IDENTITY IS NOT NORMALISED FOR THE CALLER. A third adversarial round measured the first repair
#    squeezing ALL whitespace out of the name, so `--require-class 'o k'` was answered with the
#    verdict for class `ok` — a different question, silently answered. Asking about a name that is
#    not a name is refused, never repaired.
mkreg "$TWOCLASS"
mkuap 'standing_consent:
  ok: {owner: o, mode: m, sinks: [], granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'
lane_args "RC-j interior whitespace in the class name → 1, never folded onto a real class" 1 --require-class "o k" "$TD/r.yaml" "$TD/u.md"
lane_args "RC-k surrounding whitespace IS trimmed → 0 (trim, not squeeze)" 0 --require-class "  ok  " "$TD/r.yaml" "$TD/u.md"

# l) argv preservation. The first repair rebuilt "$@" through a newline-delimited string, which split
#    a path containing a newline and DROPPED an empty positional — the drop promoted the UAP path
#    into the registry slot, i.e. the tool silently measured a different pair of files than it was
#    handed. Both are exotic inputs; both are silent, which is why they are lanes.
_nlreg="$TD/reg
two.yaml"
cp "$TD/r.yaml" "$_nlreg" 2>/dev/null && lane_args "RC-l a registry path containing a newline is one argument" 0 --require-class ok "$_nlreg" "$TD/u.md" \
  || ok "RC-l SKIPPED — this filesystem rejected a newline in a filename (not a defect)"
# RC-m asserts on WHICH registry path the tool reports, not on a success marker. The first version
# grepped for `R1/R2`, which only appears when the DEFAULT registry parses — and that default is
# `tracks/_meta/consent_classes.yaml`, which is **gitignored**, so it exists on the author's machine
# and not in CI. It passed locally and went red on the first CI run: a lane that measured the
# author's filesystem rather than the behaviour. This form works in both.
# Calibrated: the control proves the reported path tracks argv[1] at all, so the assertion below is
# a discrimination result and not a grep that could never match.
bash "$CHK" "/nonexistent-registry-probe.yaml" "$TD/u.md" >"$TD/oc" 2>&1
if grep -q "nonexistent-registry-probe.yaml" "$TD/oc"; then
  ok "RC-m CONTROL: the reported registry path tracks argv[1]"
else
  bad "RC-m CONTROL dead: the tool did not name the registry it was given — the assertion below proves nothing"; sed 's/^/     /' "$TD/oc"
fi
bash "$CHK" "" "$TD/u.md" >"$TD/o" 2>&1
if grep -qE "registry (at|unparseable).*$(basename "$TD")/u\.md" "$TD/o"; then
  bad "RC-m empty positional shifted the argument list — the UAP was read as the registry"; sed 's/^/     /' "$TD/o"
else
  ok "RC-m an empty first positional does not promote the UAP into the registry slot"
fi

echo "----"
echo "consent-registry anchor: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
