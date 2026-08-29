#!/usr/bin/env bash
# test_marker_address_lanes.sh — fixtures for pre-commit's `unread_markers`.
#
# WHAT IT GUARDS. The Axes 2+3 gate reads exactly ONE file:
# `.axes_23_passed_<BRANCH_SLUG>_<TODAY>.marker`. A marker written under any other name is a valid
# RECORD and gets ZERO validation — yet its author believes "I wrote a marker" means "the evidence
# was checked". Measured 2026-08-30: one session wrote **8** markers at addresses the hook never
# reads; all 8 carried `floor-status: opus-tier`, which is not in the enum, and nothing caught it.
# The moment the name matched, the gate rejected two format errors in two attempts.
# This is [[feedback_half_externalization_slot_without_consumer]] applied to the gate's own evidence.
#
# 🟥 SCOPE — channel, never conclusion. The advisory asks "is your evidence at the address the
# reader uses", never "is that marker any good". It must NEVER block: writing extra records under
# descriptive names is legitimate practice, and blocking it would push authors toward writing
# fewer records, which is the opposite of the goal. L4 pins the non-blocking property.
#
# Usage: bash scripts/test_marker_address_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

sed -n '/^unread_markers()/,/^}/p' "$HOOK" > "$T/fn.sh"

# 🟥 CALIBRATE THE EXTRACTION FIRST. An empty function would let every lane below pass against
# nothing — the false-green this repo keeps closing elsewhere.
if ! grep -q 'grep -vxF' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — unread_markers did not extract from $HOOK."
  echo "   The lanes would measure an empty function. Aborting rather than reporting green."
  exit 1
fi
# shellcheck disable=SC1090
. "$T/fn.sh"

pass=0; fail=0
ok() { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
no() { fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        got: %s\n' "$(printf '%s' "${2:-}" | tr '\n' '|')"; }

ADDR=".axes_23_passed_docs_branch_2026-08-30.marker"

# L1 — the real shape: the read address plus two strays
o=$(unread_markers ".axes_23_passed_docs_branch_2026-08-30.marker
.axes_23_passed_fix_something_2026-08-30.marker
.axes_23_passed_feat_other_2026-08-30.marker" "$ADDR")
[ "$(printf '%s\n' "$o" | grep -c .)" = "2" ] && ok "L1 two strays reported, the read address excluded" || no "L1" "$o"

# L2 — known-negative: only the read address exists → silence. Without this the lane could pass
# by always printing everything.
o=$(unread_markers "$ADDR" "$ADDR")
[ -z "$o" ] && ok "L2 control — only the read address present reports nothing" || no "L2" "$o"

# L3 — empty list. "No markers at all" is already said by NOT CONFIRMED below the call site;
# repeating it here would be a duplicate, so empty must stay empty.
o=$(unread_markers "" "$ADDR")
[ -z "$o" ] && ok "L3 empty list is empty (no duplicate of NOT CONFIRMED)" || no "L3" "$o"

# L4 — THE ADVISORY MUST NOT BLOCK. Pinned in the source, because the whole design rests on it:
# a blocking version would push authors to write FEWER records, inverting the intent.
if sed -n '/_MK_UNREAD=/,/^    fi$/p' "$HOOK" | grep -qE 'FAILED=1|exit 1'; then
  no "L4 the unread-marker advisory sets FAILED/exit — it must stay advisory"
else
  ok "L4 the unread-marker advisory never blocks"
fi

# L5 — EXACT match, not substring. A prefix must not silence a longer name, or a stray whose name
# begins with the read address would vanish — the exact class the `-x` flag exists for.
o=$(unread_markers "$ADDR
${ADDR}.bak" "$ADDR")
[ "$o" = "${ADDR}.bak" ] && ok "L5 matching is exact — a superstring name is still reported" || no "L5" "$o"

# L6 — duplicates collapse; a doubled line would read as two separate strays.
o=$(unread_markers ".axes_23_passed_fix_x_2026-08-30.marker
.axes_23_passed_fix_x_2026-08-30.marker" "$ADDR")
[ "$(printf '%s\n' "$o" | grep -c .)" = "1" ] && ok "L6 duplicate stray reported once" || no "L6" "$o"

echo "marker-address lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
