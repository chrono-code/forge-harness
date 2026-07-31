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

standing_consent : {ok: {granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}}'
lane "P13 a space-before-colon key cannot hide behind a canonical block" 1 "R3"

mkuap 'standing_consent :
  ok: {granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}'
lane "P13-b a space-before-colon BLOCK form is parsed and its grant validated" 1 "R5"

# N3 EXPECTATION INVERTED 2026-07-31 — and the reason is the whole point of the storage-form change.
# The slicer-era comment asserted that `standing_consent\t:` "is the SAME YAML key" as
# `standing_consent:`, and this lane pinned a PASS on that belief. The canonical loader refuses it:
# PyYAML rejects a tab there with a ScannerError, because YAML forbids tabs as structural whitespace.
# So the belief was false, and a regex that approximates the YAML spec had been quietly ratifying a
# document the spec rejects. Handing the region to the real loader replaces a guess with an answer —
# a malformed document is now BROKEN (fail-closed), not silently accepted as equivalent.
mkuap "$(printf 'standing_consent\t: {ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}}')"
lane "N3 a tab-before-colon key is invalid YAML and fails closed (loader, not regex, decides)" 1 "R3"

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
lane "R9-1c an \`unknown\` capability is not promotable either" 1 "R2-b"

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

# ---- F: STORAGE FORM (frontmatter) -------------------------------------------------
# These lanes test the machine-region boundary itself, not grant semantics, so they write the UAP
# byte-exact via mkuap_raw instead of going through the frontmatter-wrapping helper.
mkreg "$OKCLASS"
GRANT='  ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}'

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
lane "F3 no frontmatter and no grant mentioned is simply nothing granted (not a failure)" 0 ""

# F4 pins the OVER-BLOCK THIS CHANGE RETIRES. Under the slicer a merge-key grant was refused because
# the anchor lived outside the extracted fragment; the fragment is now the whole document, so
# ordinary DRY YAML resolves. Over-blocking was a defect of the same weight as a fail-open.
mkuap_raw "$(printf -- '---\ndefaults: &d {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}\nstanding_consent:\n  ok:\n    <<: *d\n---\n')"
lane "F4 a merge-key/anchor grant now resolves (the measured over-block is retired)" 0 ""

# F5 — duplicate keys stay rejected on this side too. safe_load is last-wins, so an expired grant
# followed by a future one would silently keep the future one.
mkuap_raw "$(printf -- '---\nstanding_consent:\n  ok: {granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}\n  ok: {granted: 2026-07-29, expires: 2026-12-31, effects: [read], target: t}\n---\n')"
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
lane "F9 an empty frontmatter block grants nothing and is not an error" 0 ""

# F9-b — the discriminating control for F9. If the empty region is NOT recognized, this file reads as
# "no frontmatter + standing_consent mentioned" and fails closed via F1. Green here means the empty
# frontmatter was genuinely parsed. (Without this control F9 cannot tell the two paths apart.)
mkuap_raw "$(printf -- '---\n---\n\n# UAP\n\nthe key name standing_consent appears in prose but not as a key.\n')"
lane "F9-b empty region + a prose MENTION is still nothing granted (region truly parsed)" 0 ""

# F10-F13 — YAML stream forms the canonical loader accepts and the first fence regex rejected. Each
# failed CLOSED (no leak) but as an OVER-BLOCK whose message blamed an absent frontmatter that was
# present. A gate that misdirects the fix gets overridden, so these are lanes, not footnotes.
EXPIRED='  ok: {granted: 2026-01-01, expires: 2020-01-01, effects: [read], target: t}'
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

echo "----"
echo "consent-registry anchor: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
