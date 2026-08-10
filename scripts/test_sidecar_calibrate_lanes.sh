#!/usr/bin/env bash
# test_sidecar_calibrate_lanes.sh — regression lanes for scripts/sidecar_calibrate.sh.
#
# WHY LANES FIRST: the calibrator's whole job is to distinguish states that LOOK the same from the
# outside — "the sidecar ran" vs "the model I asked for answered", "absent" vs "unmeasured". Those
# are negative legs, and negative legs are what three adversarial rounds on the node check showed
# nobody tests until a lane forces it. Each lane below drives the calibrator with a STUB CLI whose
# behaviour is known, so the calibrator's verdict can be checked against ground truth.
#
# No network, no API spend: every sidecar binary is replaced by a stub on PATH.
#
# Usage:  bash scripts/test_sidecar_calibrate_lanes.sh
# Exit:   0 = all lanes pass; 1 = at least one failed.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CAL="$REPO/scripts/sidecar_calibrate.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ❌ %s\n     got: %s\n' "$1" "$(printf '%s' "$2" | tr '\n' '|' | cut -c1-240)"; }

# stub <name> <behaviour> — write a fake sidecar CLI onto the lane PATH.
#   honest        : echoes back the model it was pinned to (a truthful runtime)
#   silent-fallback: ALWAYS answers as one fixed model, whatever the pin (the agy trap)
#   loud-reject   : exits non-zero on an unknown pin (the codex behaviour)
#   chatty        : answers with agentic prose instead of the requested token (unparseable verdict)
#   banner-echo   : prints a session banner that REPEATS the pinned model, then answers as a
#                   different model — the real shape of `codex exec` stdout (measured 2026-07-30)
#   listed-substitute: REJECTS an unknown name (so the bogus control says "rejects-bogus") yet
#                   silently serves a different model for a name that IS in its own catalogue —
#                   the measured agy shape (`gemini-3.1-pro-high` answered as 3.6 Flash, no error)
#   alias-name    : answers with the vendor's PRODUCT name carrying the right version but not every
#                   token of the pin slug — measured: pin `gpt-5.6-sol` → "GPT-5.6 Codex"
#   absent        : not created at all
mkstub() {
  local name="$1" mode="$2" bin="$TMP/bin"
  mkdir -p "$bin"
  case "$mode" in
    absent) rm -f "$bin/$name"; return ;;
  esac
  cat > "$bin/$name" <<STUB
#!/usr/bin/env bash
mode="$mode"
pin=""
prev=""
for a in "\$@"; do
  case "\$prev" in -m|--model) pin="\$a" ;; esac
  prev="\$a"
done
case "\$1" in --version) echo "stub 9.9.9"; exit 0 ;; esac
# Scan ALL arguments for the verdict prompt — it is NOT always last. codex puts the prompt at the
# end; agy puts it after -p with `--print-timeout 170s` trailing. A first draft read only the last
# argument, so the agy-shaped call never looked like a verdict request and lane5b failed against a
# correct script. An honest runtime ANSWERS THE QUESTION ASKED: a one-token request gets one token.
is_verdict=0
for a in "\$@"; do case "\$a" in *"PASS or FAIL"*) is_verdict=1 ;; esac; done
case "\$mode" in
  loud-reject)
     case "\$pin" in *nonexistent*|*bogus*) echo "ERROR: model '\$pin' is not supported" >&2; exit 1 ;; esac
     if [ "\$is_verdict" -eq 1 ]; then echo "PASS"; else echo "I am \$pin, by StubCorp."; fi ;;
  silent-fallback)
     if [ "\$is_verdict" -eq 1 ]; then echo "PASS"; else echo "I am stub-flash-3.6, by StubCorp."; fi ;;
  alias-name)
     if [ "\$is_verdict" -eq 1 ]; then echo "PASS"; else echo "StubGPT-3.1 Coder"; fi ;;
  listed-substitute)
     case "\$pin" in *nonexistent*|*bogus*) echo "ERROR: model '\$pin' is not supported" >&2; exit 1 ;; esac
     if [ "\$is_verdict" -eq 1 ]; then echo "PASS"; else echo "I am stub-flash-3.6, by StubCorp."; fi ;;
  banner-echo)
     echo "Reading additional input from stdin... CLI v0.0.0"
     echo "--------"
     echo "model: \$pin   workdir: /tmp   approval: never"
     echo "--------"
     if [ "\$is_verdict" -eq 1 ]; then echo "PASS"; else echo "I am stub-flash-3.6, by StubCorp."; fi ;;
  chatty)
     printf 'Summary of Work\n- considered the request\n- the answer is probably PASS\n' ;;
  honest|*)
     if [ "\$is_verdict" -eq 1 ]; then echo "PASS"; else echo "I am \$pin, by StubCorp."; fi ;;
esac
exit 0
STUB
  chmod +x "$bin/$name"
}

# HERMETIC PATH — system paths only, plus the stub dir. Inheriting $PATH looked harmless and was
# not: "absent" is simulated by NOT creating a stub, so the real codex/agy further down $PATH were
# found instead and the lanes fired REAL, billed API calls (measured: a lane run hung past 120s
# against live runtimes). A test that can reach production is not a test.
run_cal() { PATH="$TMP/bin:/usr/bin:/bin:/usr/sbin:/sbin" bash "$CAL" --stub-model "stub-pro-3.1" "$@" 2>&1; }

echo "── sidecar-calibrate lanes ──"

# LANE 1 — absent runtime must read as ABSENT, never as a failure of the panel and never as "fine".
mkstub codex absent; mkstub agy absent
out="$(run_cal --only codex)"
case "$out" in
  *"codex"*ABSENT*) ok "lane1 absent runtime reported ABSENT" ;;
  *) bad "lane1 absent runtime not reported as ABSENT" "$out" ;;
esac

# LANE 2 — THE POINT OF THE WHOLE SCRIPT. A runtime that silently answers as a different model must
# be reported as UNTRUSTED-PIN, not as reachable. "The sidecar ran" and "the model I pinned answered"
# are different propositions; agy's slug fallback is the measured instance (2026-07-30).
mkstub agy silent-fallback
out="$(run_cal --only agy)"
case "$out" in
  *UNTRUSTED-PIN*) ok "lane2 silent fallback caught (pinned model did not answer)" ;;
  *) bad "lane2 silent fallback passed as a healthy sidecar" "$out" ;;
esac

# LANE 3 — an honest runtime that echoes its pin is PIN-OK.
mkstub agy honest
out="$(run_cal --only agy)"
case "$out" in
  *PIN-OK*) ok "lane3 honest runtime reported PIN-OK" ;;
  *) bad "lane3 honest runtime not reported PIN-OK" "$out" ;;
esac

# LANE 4 — the negative control must actually control. A runtime that ACCEPTS a bogus model pin has
# no server-side validation, so "it ran without error" proves nothing about which model answered;
# that must be visible in the report rather than inferred.
mkstub codex loud-reject
out="$(run_cal --only codex)"
case "$out" in
  *"control: rejects-bogus"*) ok "lane4 bogus-pin control observed (runtime validates pins)" ;;
  *) bad "lane4 bogus-pin control not reported" "$out" ;;
esac
mkstub codex honest      # honest stub answers ANY pin, including a bogus one
out="$(run_cal --only codex)"
case "$out" in
  *"control: accepts-bogus"*) ok "lane4b runtime accepting a bogus pin is flagged" ;;
  *) bad "lane4b runtime accepting a bogus pin was not flagged" "$out" ;;
esac

# LANE 5 — verdict fitness is MEASURED, not assumed. A runtime that answers a one-token request with
# agentic prose cannot carry a machine-read verdict. The recorded 2026-07-04 finding said exactly
# this about agy at 1.0.14; the version has moved since, so the answer must be re-measured, never
# inherited.
mkstub agy chatty
out="$(run_cal --only agy)"
case "$out" in
  *VERDICT-UNPARSEABLE*) ok "lane5 prose-answering runtime flagged VERDICT-UNPARSEABLE" ;;
  *) bad "lane5 prose answer accepted as a usable verdict channel" "$out" ;;
esac
mkstub agy honest
out="$(run_cal --only agy)"
case "$out" in
  *VERDICT-OK*) ok "lane5b token-answering runtime reported VERDICT-OK" ;;
  *) bad "lane5b clean token answer not reported VERDICT-OK" "$out" ;;
esac

# LANE 8 (measured on the first real run) — BANNER ECHO MUST NOT SATISFY THE IDENTITY PROBE.
# Real CLIs print a session banner before the answer, and that banner repeats the pinned model name
# back (`codex exec` prints its version and config header). Matching against whole stdout therefore
# passes any runtime that merely echoes its own configuration — which is precisely the lie this
# script exists to catch, re-entering through the transport layer instead of the model.
mkstub agy banner-echo
out="$(run_cal --only agy)"
case "$out" in
  *UNTRUSTED-PIN*) ok "lane8 banner echo rejected (config echo is not a self-report)" ;;
  *) bad "lane8 banner echoing the pin passed the identity probe" "$out" ;;
esac

# LANE 10 (measured 2026-07-30) — a vendor product alias carrying the RIGHT VERSION is not a pin
# failure. Pinning `gpt-5.6-sol` returned "GPT-5.6 Codex": same family, same version, different
# product suffix. Requiring every token of the pin slug to appear made the calibrator report
# UNTRUSTED-PIN on a runtime whose pin had actually held — and that runtime also validates pins
# server-side, so the corroborating evidence was there to read. The version token is the
# discriminator that matters; the fallback cases (3.1 asked, 3.6 answered) differ exactly there.
mkstub agy alias-name
out="$(run_cal --only agy)"
case "$out" in
  *PIN-OK*) ok "lane10 product alias with matching version accepted as PIN-OK" ;;
  *) bad "lane10 matching version rejected because a suffix token was absent" "$out" ;;
esac

# LANE 9 (measured 2026-07-30) — "rejects unknown names" does NOT imply "serves known names
# faithfully", and the gap between them is where the real trap lives. agy rejects a nonsense model
# yet silently substituted Flash for `gemini-3.1-pro-high`, a slug from its OWN catalogue. A control
# that only probes nonsense therefore returns reassuring evidence about the wrong question: the
# identity probe must still decide, and the report must not let `rejects-bogus` read as "pin safe".
mkstub agy listed-substitute
out="$(run_cal --only agy)"
case "$out" in
  *"control: rejects-bogus"*UNTRUSTED-PIN*|*UNTRUSTED-PIN*"control: rejects-bogus"*)
      ok "lane9 validates unknown names yet substitutes a known one → still UNTRUSTED-PIN" ;;
  *) bad "lane9 pin substitution masked by a passing bogus-control" "$out" ;;
esac

# LANE 6 — panel verdict. With no usable different-family sidecar the script must say so explicitly:
# this is the line a marker's `crossfamily:` leg quotes, and the 2026-07-30 defect was asserting
# "cross-family unavailable" without ever probing.
mkstub codex absent; mkstub agy absent
out="$(run_cal)"
case "$out" in
  *"PANEL: none"*) ok "lane6 empty panel stated explicitly (not silence)" ;;
  *) bad "lane6 empty panel not stated" "$out" ;;
esac
mkstub codex honest
out="$(run_cal)"
case "$out" in
  *"PANEL: "*codex*) ok "lane6b populated panel names the usable runtime" ;;
  *) bad "lane6b populated panel not named" "$out" ;;
esac

# LANE 7 — detector, not gate: always exit 0, so a calibration run can never block a caller. The
# caller reads the verdict; the script does not decide for it.
mkstub codex absent; mkstub agy absent
PATH="$TMP/bin:/usr/bin:/bin:/usr/sbin:/sbin" bash "$CAL" >/dev/null 2>&1
[ $? -eq 0 ] && ok "lane7 exits 0 even with an empty panel (detector, not gate)" \
             || bad "lane7 non-zero exit on empty panel" "exit=$?"

# LANE 8 — nongenerative unfit filter (pmh crossfamily_probe 델타 흡수): an embedding/OCR model id
# must classify UNFIT (rc=1) BEFORE family patterns could claim it; a generative id stays FIT (rc=0).
out=$(bash "$CAL" --classify "Qwen3-Embedding-8B" 2>&1); rc=$?
[ $rc -eq 1 ] && case "$out" in *"UNFIT (embedding"*) true;; *) false;; esac \
  && ok "lane8 embedding id → UNFIT rc=1" || bad "lane8 embedding not UNFIT" "rc=$rc $out"
out=$(bash "$CAL" --classify "GLM-OCR" 2>&1); rc=$?
[ $rc -eq 1 ] && case "$out" in *"UNFIT (OCR"*) true;; *) false;; esac \
  && ok "lane8b OCR id → UNFIT (unfit-before-family order)" || bad "lane8b OCR not UNFIT" "rc=$rc $out"
out=$(bash "$CAL" --classify "llama3.3:70b" 2>&1); rc=$?
[ $rc -eq 0 ] && case "$out" in *"FIT (generative"*) true;; *) false;; esac \
  && ok "lane8c generative id → FIT rc=0 (과차단 대칭 · 출력 검증)" || bad "lane8c generative misclassified" "rc=$rc $out"

printf '\nsidecar-calibrate lanes: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
