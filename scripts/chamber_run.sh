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

# ── 순서 증인 (ship_readiness_gate §② P1) ────────────────────────────────────
# 워크스페이스는 `tracks/**` 라 gitignored 다. 그래서 게이트 아티팩트의 **해시만**
# 추적되는 원장에 적어 커밋한다 — **본문** 유출 0(단 slug·파일명·시각·해시는 남는다),
# 순서는 로컬 커밋 그래프가 증언(되쓰기 방지는 push 후 서버 ruleset 이 준다).
# 기록 실패는 **런을 막지 않는다**(KILL 런까지 세우는 건 과차단이고, 과차단은
# override 를 습관화시킨다). 대신 증인 부재를 **말한다** — 조용히 넘어가지 않는다.
_WITNESS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/chamber_witness.sh"
_witness_record() { # $1 = artifact path
  if [ ! -x "$_WITNESS" ] && [ ! -f "$_WITNESS" ]; then
    echo "    ⚠️ 순서 증인 미기록 — chamber_witness.sh 부재 (이 런은 ② 승격 근거로 못 쓴다)"
    return 0
  fi
  if bash "$_WITNESS" record "$SLUG" "$1" >/dev/null 2>&1; then
    # 🟥 «커밋해야 된다» 로만 적으면 **틀린 처방을 가르친다**(2026-08-17 런 #12 실측:
    # 네 해시를 한 커밋에 배치했더니 브랜치에서부터 UNORDERED). verify 는
    # `[ verdict_ts -le pre_max_ts ]` 로 판정하므로 **같은 커밋 = 같은 초 = 실패**다.
    if [ "$(basename "$1")" = "EMISSION_VERDICT.md" ]; then
      echo "    ↳ 순서 증인: EMISSION_VERDICT.md 해시 기록됨"
      echo "       🟥 이 해시는 **게이트 해시들과 다른 커밋**으로 올려야 한다. 같이 커밋하면 UNORDERED 다."
    else
      echo "    ↳ 순서 증인: $(basename "$1") 해시 기록됨 — **verdict 보다 먼저, 별도 커밋으로** 올려라"
    fi
  else
    echo "    ⚠️ 순서 증인 기록 실패: $(basename "$1") (증인 없음 — 미측정이지 0이 아니다)"
  fi
}

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
_witness_record "$WS/INTENT.md"

# STEP 3 — budget-entry gate (G2). Cannot invoke goal-quench from bash; MECHANICALLY require a recorded
# estimate before any (expensive) simulation runs. No ESTIMATE = no run — that IS the entry cap.
if [ ! -f "$WS/BUDGET.md" ]; then
  cat > "$WS/BUDGET.md" <<EOF
# BUDGET — $SLUG (chamber run)

# Route through goal-quench's budget gate for an expensive run, then record here.
# Demo-scale runs may self-cap — but an ESTIMATE line is mandatory (this is the entry cap).
#
# 🟥 ACTUAL 은 이 파일에 적지 마라 — step 6 이 별도 ACTUAL.md 를 쓴다.
# 이유: 이 파일의 판정-전 해시가 순서 증인(ship_readiness_gate §② P1)이다. 사후에
# 이 파일을 고치면 증인이 TAMPERED 로 죽는다 (2026-08-17 런 #11 실측).
ESTIMATE: <e.g. ~3 persona dispatches, demo-scale, self-capped  |  or a token budget>
EOF
  echo "  ⛔ step 3 BLOCKED: record an ESTIMATE in $WS/BUDGET.md (budget-entry gate G2), then re-run."; exit 1
fi
if grep -qE '^ESTIMATE:[[:space:]]*<' "$WS/BUDGET.md" || ! grep -qE '^ESTIMATE:[[:space:]]*\S' "$WS/BUDGET.md"; then
  echo "  ⛔ step 3 BLOCKED: $WS/BUDGET.md ESTIMATE is empty/placeholder (G2 entry cap), then re-run."; exit 1
fi
_stamp "step-3-done"; echo "  ✓ step 3: budget ESTIMATE recorded (entry cap satisfied)"
_witness_record "$WS/BUDGET.md"

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
_witness_record "$WS/SIM_NOTES.md"

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
_witness_record "$WS/EMISSION_VERDICT.md"
# 순서 판정을 **여기서 인쇄한다.** verdict 가 나온 자리가 "게이트가 결과를 알기 전에
# 돌았는가" 를 물어야 하는 유일한 자리다. 차단하지 않는 이유: KILL 런까지 막으면
# 과차단이고, 과차단은 override 를 습관화시켜 게이트 전체를 무장해제한다.
# 대신 **EMIT 일 때는 승격 사용 가부를 명시적으로 말한다** — 침묵이 곧 승인으로
# 읽히는 것이 이 채널이 존재하는 이유다.
if [ -f "$_WITNESS" ]; then
  echo "  ── 순서 증인 판정 ──"
  bash "$_WITNESS" verify "$SLUG" "$WS" 2>&1 | sed 's/^/    /'
  _wrc="${PIPESTATUS[0]}"
  if [ "$VERDICT" = "EMIT" ] || [ "$VERDICT" = "PARTIAL-EMIT" ]; then
    if [ "${_wrc:-9}" = "0" ]; then
      echo "    ✅ 이 EMIT 은 순서 증인을 가진다 — identity ② 승격 근거로 사용 가능"
    else
      echo "    🟥 이 EMIT 에는 순서 증인이 없다(rc=${_wrc:-?}) — identity ② 승격 근거로 쓰지 마라."
      echo "       처방 — 커밋을 **합치지 마라**. 세 경로가 각각 증인을 죽인다(2026-08-17 실측):"
      echo "         ① 한 커밋에 배치        → 같은 초라 UNORDERED (런 #12 에서 재현)"
      echo "         ② --squash 머지          → 게이트+verdict 가 main 에서 한 커밋으로 접힌다 (런 #11)"
      echo "         ③ --delete-branch        → 순서를 담은 커밋이 도달 불가가 된다"
      echo "       올바른 형태: 게이트 해시 커밋 → (별도) verdict 해시 커밋, **두 PR 로 분리해 각각 머지**."
      echo "       그러면 squash 해도 main 에 2커밋이 남아 순서가 보존된다."
      # ★ 출력만 하고 exit 0 으로 끝내면, stdout 을 안 읽는 호출자에게는 증인 없는 EMIT 도
      # **성공**이다(cross-family F8). EMIT 은 승격 주장이므로 기계적으로 구분되어야 한다.
      WITNESS_EMIT_FAIL=1
    fi
  fi
fi

# STEP 6 — actual cost / carry-forward record.
# 🟥 별도 파일이다. BUDGET.md 가 아니다 — 그리고 그 분리가 이 게이트의 핵심이다.
# 2026-08-17 런 #11(첫 형식 완주)이 실측한 결함: step 3 이 BUDGET.md 의 해시를 순서 증인으로
# 기록하는데 step 6 이 같은 파일에 ACTUAL 을 요구하며 하드 차단했다 → 완주하면 반드시
# 증인 아티팩트가 사후 변경되고 verify 가 TAMPERED 를 낸다 → **완주한 런은 구조적으로
# ② 승급 근거가 될 수 없었다.** 대상 선정 실수가 아니라 한 파일에 두 역할(①불변 요구 =
# 증인 · ②변경 요구 = 사후 캘리브레이션)이 겹친 것이고, 개별로는 둘 다 옳아서 어느 쪽
# 코드를 읽어도 안 보였다. 그래서 스펙(P1 이 BUDGET 을 증인으로 지목)은 안 건드리고
# **변경 요구만** 빼낸다. ACTUAL.md 는 정의상 판정 후 산물이므로 **증인에 기록하지 않는다.**
if [ ! -f "$WS/ACTUAL.md" ]; then
  cat > "$WS/ACTUAL.md" <<EOF
# ACTUAL — $SLUG (chamber run, 판정 후 기록)
#
# 이 파일은 **순서 증인 대상이 아니다** — 판정 후에 쓰이는 것이 정상이므로 해시를 걸지 않는다.
# ESTIMATE 는 BUDGET.md 에 있고 그 파일은 판정 전에 얼어 있다. 대조는 사람이 한다.
ACTUAL: <number/summary — dispatch 수 · 토큰 · 예산 대비 편차>
EOF
fi
if grep -qE '^ACTUAL:[[:space:]]*<' "$WS/ACTUAL.md" || ! grep -qE '^ACTUAL:[[:space:]]*\S' "$WS/ACTUAL.md"; then
  echo "  ⛔ step 6 BLOCKED: record ACTUAL cost in $WS/ACTUAL.md (actual-vs-estimate calibration)."
  echo "     🟥 BUDGET.md 가 아니다 — 그 파일은 판정 전 증인이라 사후 변경하면 증인이 죽는다."
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
# EMIT/PARTIAL-EMIT 인데 순서 증인이 없으면 **비영 종료**한다. KILL 은 영향 없다 —
# KILL 까지 실패로 세우면 과차단이고, 과차단은 override 를 습관화시킨다.
if [ "${WITNESS_EMIT_FAIL:-0}" = "1" ]; then
  echo "⚠️ exit 3 — EMIT 이지만 순서 증인 미성립. 승격 주장에 쓰지 마라."
  exit 3
fi
exit 0
