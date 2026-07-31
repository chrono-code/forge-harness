#!/usr/bin/env bash
# test_ollama_panel_lanes.sh — hermetic known pairs for the ollama panel leg of sidecar_calibrate.sh
#
# Hermetic by construction: every lane runs against a stub HTTP server on loopback. No network, no
# spend, no dependence on a node being powered on — the same property the CLI lanes get from stub
# binaries. A calibrator whose own tests need the thing it calibrates cannot fail honestly.
#
# WHAT MAKES THIS LEG DIFFERENT FROM codex/agy, AND WHY IT NEEDED ITS OWN LANES
#   The CLI legs anchor PIN-OK on the model's SELF-REPORT. That anchor is invalid here and the
#   measurement says so: asked which model it was, `gpt-oss:20b` answered "The underlying model is
#   GPT-4 (likely)" (2026-07-31). Open-weight models do not reliably know their own name, so a
#   self-report anchor would mark an EXACT pin as UNTRUSTED and drop it from the panel — an
#   instrument that cannot separate known-positive from known-negative on its target. The anchor is
#   therefore the SERVER's response envelope: a server-side fact, not a model's claim.
#   Lane S2 is the reason that distinction has teeth — it is the agy failure in this protocol's
#   spelling: the server quietly answers as a different model than the one pinned.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CAL="$ROOT/scripts/sidecar_calibrate.sh"
pass=0; fail=0
PORT="${FH_LANE_PORT:-18011}"
SRV_PID=""

# `wait` after the kill, so bash reaps the child quietly instead of printing "Terminated: 15" into
# the lane output — a harness that litters CI logs teaches people to stop reading them.
stop_stub() {
  [ -n "$SRV_PID" ] || return 0
  kill "$SRV_PID" 2>/dev/null
  wait "$SRV_PID" 2>/dev/null
  SRV_PID=""
}
trap 'stop_stub' EXIT

# The stub is written to a file so the heredoc cannot collide with the lane script's own quoting.
STUB="$(mktemp -d)/stub.py"
cat > "$STUB" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
PORT = int(sys.argv[1]); MODE = sys.argv[2]

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, obj, code=200):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.path == "/api/version": self._send({"version": "stub"})
        elif self.path == "/api/tags": self._send({"models": [{"name": "stub-model:1b"}]})
        else: self._send({}, 404)
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        req = json.loads(self.rfile.read(n) or b"{}")
        m = req.get("model", "")
        if m.startswith("fh-calib-nonexistent"):
            # BOGUS control. 'accept' mode is the dangerous server: it serves SOMETHING for a name
            # that cannot exist, so the pin is never validated at all.
            if MODE == "accept": self._send({"model": m, "response": "PASS"})
            else: self._send({"error": f"model '{m}' not found"})
            return
        if MODE == "substitute":  # the agy failure, in this protocol
            self._send({"model": "some-other-model:9b", "response": "PASS"}); return
        if MODE == "starved":     # reasoning model spent the whole budget thinking
            self._send({"model": m, "response": "", "thinking": "x" * 780}); return
        if MODE == "prose":       # cannot carry a machine-read verdict
            self._send({"model": m, "response": "Well, I would say this looks like a PASS overall."}); return
        self._send({"model": m, "response": "PASS"})
HTTPServer(("127.0.0.1", PORT), H).serve_forever()
PY
# shellcheck disable=SC2016
start_stub() {
  stop_stub
  python3 "$STUB" "$PORT" "$1" >/dev/null 2>&1 &
  SRV_PID=$!
  for _ in $(seq 1 40); do
    curl -sf --max-time 1 "http://127.0.0.1:$PORT/api/version" >/dev/null 2>&1 && return 0
    sleep 0.25
  done
  return 1
}

# expect <label> <mode> <expect-in-panel: YES|NO> [needle]
expect() {
  local label="$1" mode="$2" want="$3" needle="${4:-}" out inpanel
  start_stub "$mode" || { printf '  ❌ %-44s stub failed to start\n' "$label"; fail=$((fail+1)); return; }
  out=$( FH_OLLAMA_HOST="http://127.0.0.1:$PORT" FH_OLLAMA_MODELS="stub-model:1b" \
         bash "$CAL" --only ollama --quiet 2>&1 )
  stop_stub
  if printf '%s' "$out" | grep -q 'PANEL:.*ollama:stub-model:1b'; then inpanel=YES; else inpanel=NO; fi
  if [ "$inpanel" = "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -q "$needle"; }; then
    printf '  ✅ %-44s in-panel=%s\n' "$label" "$inpanel"; pass=$((pass+1))
  else
    printf '  ❌ %-44s in-panel=%s (expected %s%s)\n' "$label" "$inpanel" "$want" "${needle:+, needle '$needle'}"
    printf '     out: %s\n' "$(printf '%s' "$out" | head -4)"; fail=$((fail+1))
  fi
}

echo "[ollama-panel] known pairs (hermetic stub server)"
expect "S1 envelope matches pin, verdict parses" ok         YES "PIN-OK(envelope)"
expect "S2 server substitutes a DIFFERENT model" substitute NO  "UNTRUSTED-PIN"
expect "S3 empty answer (budget starvation)"     starved    NO  "larger FH_OLLAMA_NUM_PREDICT"
expect "S4 prose answer cannot carry a verdict"  prose      NO  "VERDICT-UNPARSEABLE"
expect "S5 server accepts a bogus model name"    accept     YES "accepts-bogus"

# S6 — absence must be MEASURED, never assumed. No server at the host at all.
out=$( FH_OLLAMA_HOST="http://127.0.0.1:$((PORT+7))" bash "$CAL" --only ollama --quiet 2>&1 )
if printf '%s' "$out" | grep -q 'ABSENT — no server at the configured host'; then
  printf '  ✅ %-44s reported ABSENT\n' "S6 no server at host"; pass=$((pass+1))
else
  printf '  ❌ %-44s (expected a measured ABSENT line)\n' "S6 no server at host"
  printf '     out: %s\n' "$(printf '%s' "$out" | head -3)"; fail=$((fail+1))
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "[ollama-panel] ✅ all $pass known pairs hold"; exit 0
else
  echo "[ollama-panel] ❌ $fail/$((pass+fail)) lanes failed"; exit 1
fi
