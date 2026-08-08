#!/usr/bin/env bash
# chamber_run.sh — chamber run orchestrator (the runner the skeleton's gaps G1-forcing/G2/G4/STATUS all
# hung on). GLUE ONLY: it wires the pieces that already exist (workspace convention · budget gate notion ·
# the isolated persona agents · the Emission Gate · the G4 ledger) into one intent-driven, resumable flow
# so a chamber run can be *completed by intent* rather than hand-followed from the skeleton doc.
#
# What it MECHANIZES: workspace + INTENT/BUDGET templates · STATUS stamping (resumable — re-run to advance) ·
# the budget-entry gate (G2: blocks step 4 until an ESTIMATE is recorded — no uncapped run) · the step-4
# isolation gate (G1-forcing: blocks step 5 until SIM_NOTES has ≥3 blind persona sections) · the Emission
# Gate verdict capture · actual-cost record · and the G4 ledger auto-append (idempotent).
#
# What it CANNOT mechanize (honest muscle boundary, documented in CHAMBER_RUN_SKELETON.md): bash cannot
# spawn the isolated Agents itself. Step 4 PRINTS the exact dispatch and GATES on the ≥3 persona artifact —
# the human/Claude does the actual `fh-meta:{beginner,challenger,main-player}` dispatch. Isolation stays a
# salience+artifact gate, not a spawn. Budget/cost numbers calibrate only across real runs (muscle, not wiring).
#
# Usage:  bash scripts/chamber_run.sh <candidate-slug>          # create/advance the run (idempotent)
#         bash scripts/chamber_run.sh <candidate-slug> status    # show where the run is
#   exit 0 = advanced or already complete · exit 1 = blocked on a missing artifact (message says which)
#   exit 2 = harness error (FH root / bad slug)

set -uo pipefail

FH="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -d "$FH/tracks" ] || [ ! -d "$FH/plugins" ]; then
  echo "❌ FH root not found at '$FH' — run from the FH repo." >&2; exit 2
fi

SLUG="${1:-}"
[ -z "$SLUG" ] && { echo "usage: chamber_run.sh <candidate-slug> [status]" >&2; exit 2; }
# slug charset: [A-Za-z0-9-] only, no leading dash. Rejecting regex metachars (`.` `+` `[` `*`) is
# load-bearing — $SLUG is interpolated raw into an ERE idempotency grep below; `a.b` would let `.` match
# any char (idempotency mismatch → duplicate ledger row), `a+b` would break the ERE (Axis-2 LOW-5).
case "$SLUG" in -*) echo "❌ bad slug '$SLUG' (no leading dash)" >&2; exit 2 ;; esac
case "$SLUG" in *[!A-Za-z0-9-]*) echo "❌ bad slug '$SLUG' (allowed: letters, digits, hyphen)" >&2; exit 2 ;; esac
CMD="${2:-advance}"

WS="$FH/tracks/_chamber/$SLUG"
LEDGER="$FH/tracks/_chamber/INDEX.md"
STATUS_F="$WS/STATUS"
TODAY="$(date +%Y-%m-%d)"

_status() { [ -f "$STATUS_F" ] && cat "$STATUS_F" || echo "step-0"; }
_stamp()  { printf '%s\n' "$1" > "$STATUS_F"; }

if [ "$CMD" = "status" ]; then
  echo "chamber run '$SLUG' → STATUS: $(_status)"
  [ -d "$WS" ] && ls -1 "$WS" 2>/dev/null | sed 's/^/    /'
  exit 0
fi

echo "── chamber run: $SLUG (STATUS: $(_status)) ──"

# STEP 1 — workspace
if [ ! -d "$WS" ]; then
  mkdir -p "$WS" 2>/dev/null || { echo "❌ cannot create workspace $WS" >&2; exit 2; }
  echo "  ✓ step 1: workspace created ($WS)"
fi
_stamp "step-1-done"

# STEP 2 — INTENT.md (template if absent; block until it has real content)
if [ ! -f "$WS/INTENT.md" ]; then
  cat > "$WS/INTENT.md" <<EOF
# INTENT — $SLUG (chamber run)

## Candidate intent
<one line: the capability/project to incubate>

## Success conditions (each with a check class: mandatory-pass / measured / judged)
1.
2.

## Failure cost (blast radius AND reinvention risk)
-

## Chamber metadata
- entry reason: <uncertain | exploratory | failure-expensive | high-reinvention-risk>
- date: $TODAY
EOF
  echo "  ⛔ step 2 BLOCKED: fill in $WS/INTENT.md (template written), then re-run."; exit 1
fi
if grep -q '<one line: the capability' "$WS/INTENT.md"; then
  echo "  ⛔ step 2 BLOCKED: $WS/INTENT.md still has the placeholder — fill it, then re-run."; exit 1
fi
# gate (a) is "artifact exists WITH real content", not just "placeholder removed" (Axis-2 LOW-6): require
# at least one non-empty numbered success condition so a gutted INTENT.md doesn't pass.
if ! awk '/^## Success conditions/{f=1;next} /^## /{f=0} f && /^[0-9]+\.[[:space:]]*[^[:space:]]/{print; exit}' "$WS/INTENT.md" | grep -q .; then
  # 계약을 **에러 메시지가 가르친다.** 이 형식은 CHAMBER_RUN_SKELETON.md 에 한 글자도 없어서,
  # 스켈레톤만 읽고 쓴 INTENT 가 반려됐다 — gate-locality(계약이 게이트 구현에만 산다).
  # 같은 런에서 step 6 도 같은 이유로 막혔다(N=2). 문서는 드리프트하지만 에러는 코드와 같이 산다.
  echo "  ⛔ step 2 BLOCKED: $WS/INTENT.md has no filled success condition."
  echo "     Expected — an English heading, then NUMBERED lines with content:"
  echo "       ## Success conditions"
  echo "       1. <condition> · [measured|mandatory-pass|judged]"
  echo "       2. ..."
  echo "     A table alone does NOT satisfy this check. Re-run after adding it."; exit 1
fi
_stamp "step-2-done"; echo "  ✓ step 2: INTENT.md present"

# STEP 3 — budget-entry gate (G2). Cannot invoke goal-quench from bash; MECHANICALLY require a recorded
# estimate before any (expensive) simulation runs. No ESTIMATE = no run — that IS the entry cap.
if [ ! -f "$WS/BUDGET.md" ]; then
  cat > "$WS/BUDGET.md" <<EOF
# BUDGET — $SLUG (chamber run)

# Route through goal-quench's budget gate for an expensive run, then record here.
# Demo-scale runs may self-cap — but an ESTIMATE line is mandatory (this is the entry cap).
ESTIMATE: <e.g. ~3 persona dispatches, demo-scale, self-capped  |  or a token budget>
ACTUAL:   <filled at step 6>
EOF
  echo "  ⛔ step 3 BLOCKED: record an ESTIMATE in $WS/BUDGET.md (budget-entry gate G2), then re-run."; exit 1
fi
if grep -qE '^ESTIMATE:[[:space:]]*<' "$WS/BUDGET.md" || ! grep -qE '^ESTIMATE:[[:space:]]*\S' "$WS/BUDGET.md"; then
  echo "  ⛔ step 3 BLOCKED: $WS/BUDGET.md ESTIMATE is empty/placeholder (G2 entry cap), then re-run."; exit 1
fi
_stamp "step-3-done"; echo "  ✓ step 3: budget ESTIMATE recorded (entry cap satisfied)"

# STEP 4 — persona simulation (G1-forcing gate). Dispatch is human/Claude-side (bash can't spawn Agents);
# gate on the ≥3 blind persona artifact. Isolation is the mechanism — the runner enforces the artifact, not the spawn.
if [ ! -f "$WS/SIM_NOTES.md" ]; then
  echo "  ⛔ step 4 BLOCKED: dispatch 3 BLIND ISOLATED Agents and record each in $WS/SIM_NOTES.md:"
  echo "        Agent fh-meta:beginner      → first-contact friction"
  echo "        Agent fh-meta:main-player   → daily-use / target-user value"
  echo "        Agent fh-meta:challenger    → skeptic: emit value? failure cost? what's invisible?"
  echo "     Each as '## <persona> ...' section. (sim-conductor fills persona_container_schema's 6 slots.)"
  exit 1
fi
# count DISTINCT personas (not raw lines — 3×"## beginner" must NOT satisfy the 3-blind-persona gate).
NPERS=0
for _p in beginner main-player challenger; do
  grep -iqE "^##[[:space:]].*$_p" "$WS/SIM_NOTES.md" 2>/dev/null && NPERS=$((NPERS+1))
done
if [ "$NPERS" -lt 3 ]; then
  echo "  ⛔ step 4 BLOCKED: SIM_NOTES.md has $NPERS/3 DISTINCT blind persona sections (need all of beginner + main-player + challenger)."; exit 1
fi
_stamp "step-4-done"; echo "  ✓ step 4: $NPERS blind persona sections present (isolation-gate satisfied)"

# STEP 5 — Emission Gate. Require a VERDICT: EMIT | PARTIAL-EMIT | KILL.
if [ ! -f "$WS/EMISSION_VERDICT.md" ]; then
  cat > "$WS/EMISSION_VERDICT.md" <<EOF
# Emission Gate Verdict — $SLUG (chamber run)

VERDICT: <EMIT | PARTIAL-EMIT | KILL>

## Judged: does the simulation hold?  (+ mechanical anchor: overlap grep / gate verdicts / reproduced flows)

## Carry-forward (what compounds into the next run)
-
EOF
  echo "  ⛔ step 5 BLOCKED: decide WITH the operator (HITL), record VERDICT in $WS/EMISSION_VERDICT.md, re-run."; exit 1
fi
# PARTIAL-EMIT listed FIRST in every alternation so it is never mis-extracted as its EMIT substring.
VERDICT=$(grep -ioE '^VERDICT:[[:space:]]*(PARTIAL-EMIT|EMIT|KILL)' "$WS/EMISSION_VERDICT.md" 2>/dev/null | head -1 | grep -ioE 'PARTIAL-EMIT|EMIT|KILL' | head -1 | tr 'a-z' 'A-Z')
# a bare "## Verdict:" prose line (run #3 style) also counts if it names KILL/EMIT
[ -z "$VERDICT" ] && VERDICT=$(grep -ioE 'VERDICT[: *]+\**(PARTIAL-EMIT|EMIT|KILL)' "$WS/EMISSION_VERDICT.md" 2>/dev/null | grep -ioE 'PARTIAL-EMIT|EMIT|KILL' | head -1 | tr 'a-z' 'A-Z')
if [ -z "$VERDICT" ]; then
  echo "  ⛔ step 5 BLOCKED: no VERDICT (EMIT|PARTIAL-EMIT|KILL) found in $WS/EMISSION_VERDICT.md, re-run."; exit 1
fi
_stamp "step-5-done"; echo "  ✓ step 5: Emission Gate verdict = $VERDICT"

# STEP 6 — actual cost / carry-forward record.
if grep -qE '^ACTUAL:[[:space:]]*<' "$WS/BUDGET.md" || ! grep -qE '^ACTUAL:[[:space:]]*\S' "$WS/BUDGET.md"; then
  echo "  ⛔ step 6 BLOCKED: record ACTUAL cost in $WS/BUDGET.md (actual-vs-estimate calibration)."
  echo "     Expected — a LINE PREFIX, not a heading:"
  echo "       ACTUAL: <number/summary>        ← this form is checked"
  echo "       ## ACTUAL                       ← a heading does NOT satisfy it"
  echo "     Re-run after adding the line."; exit 1
fi
_stamp "step-6-done"; echo "  ✓ step 6: actual cost recorded"

# STEP 7 — terminus + G4 ledger auto-append (idempotent).
if [ ! -f "$LEDGER" ]; then
  echo "  ⚠ step 7: no ledger at $LEDGER — skipping auto-append (fail-visible)."
elif grep -qE "^\|[^|]*\|[^|]*\|[^|]*\`$SLUG\`" "$LEDGER"; then
  echo "  ✓ step 7: ledger already has a row for '$SLUG' (idempotent — no duplicate append)."
else
  NEXT=$(grep -oE '^\|[[:space:]]*#([0-9]+)' "$LEDGER" | grep -oE '[0-9]+' | sort -n | tail -1)
  NEXT=$(( ${NEXT:-0} + 1 ))
  CARRY=$(grep -A2 -iE '^##[[:space:]]*Carry-forward' "$WS/EMISSION_VERDICT.md" 2>/dev/null | grep -E '^-[[:space:]]*\S' | head -1 | sed 's/^-[[:space:]]*//; s/|/·/g')
  [ -z "$CARRY" ] && CARRY="see $SLUG/EMISSION_VERDICT.md"
  printf '| #%s | %s | `%s` | **%s** | %s | `%s/` |\n' "$NEXT" "$TODAY" "$SLUG" "$VERDICT" "$CARRY" "$SLUG" >> "$LEDGER"
  echo "  ✓ step 7: appended run #$NEXT ($VERDICT) to the G4 ledger."
fi
_stamp "step-7-done"

echo ""
case "$VERDICT" in
  EMIT) echo "TERMINUS (EMIT): route by class — field harness → Full-Harness Mode (auto_project_mapping.md §6);"
        echo "                 FH-internal utility → New-Skill Pre-Commit gate + asset-placement-gate." ;;
  PARTIAL-EMIT) echo "TERMINUS (PARTIAL-EMIT): the standing candidate is killed; fold the surviving sliver into an"
                echo "                 existing asset / the skeleton (no new asset). Workspace stays as evidence." ;;
  KILL) echo "TERMINUS (KILL): first-class success — a cheap run prevented a speculative/reinvention build."
        echo "                 No emit. Workspace stays as the evidence record; seen-filter will skip re-listing it." ;;
esac
echo "chamber run '$SLUG' COMPLETE (STATUS: step-7-done, verdict $VERDICT)."
exit 0
