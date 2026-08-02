#!/usr/bin/env bash
# probe_scope_check.sh — every `Scope` in the probe set must still name a real section.
#
# WHY (2026-08-02). `.claude/regression/probes.md` states its own maintenance rule: "when a Scope
# target section changes, the probes pointing at it MUST be updated in the same commit — a stale probe
# is a false alarm generator." Nothing enforced it. First run found **8 stale scopes**: two had been
# relocated into `.claude/rules/fh_4axis_gate.md` when the 4-axis section was split out of CLAUDE.md,
# and five named sub-steps or notations that are not section anchors at all. A probe whose Scope points
# nowhere still runs, but nobody can tell what it defends — and the drift is invisible until someone
# reasons from the probe set about which assets are protected.
#
# WHAT THIS IS NOT, AND WHY (the honest part). This began as an *ablation coverage* reporter: it also
# printed "how much of CLAUDE.md is defended by no probe", to give the shed/advance pass something to
# act on. That number was wrong four times in a row (98% -> 51% -> 51% -> 46%, plus a confident
# "100% unmeasured" on an asset three probes defended), each time for a different reason, and each
# repair produced the next defect. The convergence rule this repo now runs says a yield that stops
# falling means the design is manufacturing its own findings — cut it, do not tighten it. So the
# number is GONE and only the check that kept proving useful remains. Coverage measurement is a
# separate problem; it is NOT solved here and should not be reported as if it were.
#
# Usage:  bash scripts/probe_scope_check.sh [--self-test]     (both forms run the same checks)
# Exit 0 = every Scope resolves · 1 = instrument error (missing input) · 3 = a Scope does not resolve.

set -uo pipefail
FH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBES="$FH/.claude/regression/probes.md"

# ── Section matching ──────────────────────────────────────────────────────────
# A probe writes a section SHORT (`CLAUDE.md §Autonomous Initiative`); the asset's real anchor may be
# a long `## ` heading, a `### ` sub-heading, or a bold-lead paragraph (`**Guards**:`). Matching only
# `## ` headings scored 9 of 16 scopes as unmatched and put a 7-probe section at UNMEASURED — a false
# zero a narrow control passed straight over, because that control fed the short name in directly and
# never exercised the heading-derived path the scan uses. Direction matters too: the probe's name is a
# PREFIX of the anchor, never the reverse.
_anchors() {  # $1=asset file — every section-ish anchor text, one per line
  # awk, not a regex alternation: a bold-lead anchor can contain `*` itself
  # (`**Substantive carve-out — `docs/*.md` · …**`), which defeats a `[^*]+` class and made that
  # anchor invisible — reported as a STALE scope when the section was right there. Cut from the
  # opening `**` to the NEXT `**`, which is exact regardless of what sits between them.
  awk '
    /^```/      { fence = !fence; next }
    fence       { next }
    /^##+ /     { sub(/^#+ /, ""); print; next }
    /^\*\*/     { l = substr($0, 3); i = index(l, "**"); if (i > 1) print substr(l, 1, i - 1) }
  ' "$1" 2>/dev/null
}

# ONE extractor feeds the control and every count taken from the probe set. `_scope_rows` emits one
# line per probe ROW, un-deduped; `_all_scopes` (control B) is that list deduped, and `_scope_hits`
# matches over the same list. The earlier split — control on a table parser, matcher on a free-text scan —
# left the control certifying a number it did not govern: a prose line ending in `CLAUDE.md §Autonomous
# Initiative` (a retirement note, a see-also — probes.md:11 is already such a line) inflated the count
# by 1 while control B reported stale=0 and selfcheck said PASS. That is the two-code-paths defect the
# comment below R2 declares closed, re-created on the other axis, and in the worse direction: the
# loose path is the one that produces the output.
# Dedup belongs ONLY to the control: eight probes legitimately share one Scope, so `sort -u` in the
# matcher would collapse them to 1 and under-report.
_scope_rows() {  # one "asset<TAB>section" per probe row; unparseable cells -> stderr
  awk -F'|' 'NF>=6 && $2 ~ /`/ { print $5 }' "$PROBES" 2>/dev/null \
  | sed -E 's/`//g; s/^[[:space:]]+//; s/[[:space:]]+$//' \
  | while IFS= read -r cell; do
      [ -n "$cell" ] || continue
      case "$cell" in
        *" §"*)
          _a="${cell%% §*}"; _n="${cell#* §}"
          case "$_n" in *" · "*) _n="${_n%% · *}" ;; esac
          printf '%s\t%s\n' "$_a" "$_n" ;;
        *)      printf 'UNPARSED\t%s\n' "$cell" >&2 ;;
      esac
    done
}

_scope_hits() {  # $1=asset basename  $2=anchor -> matching probe rows (control A only)
  # Normalize BOTH sides to a basename. The caller passes a bare asset name while a Scope cell
  # may write a full path (`knowledge/shared/rules/sync_push_protocols.md §…`), so a raw `$1 == asset`
  # dropped every path-qualified scope — and control B, which resolves assets path-agnostically, was
  # green throughout. Running the script on `.claude/rules/fh_4axis_gate.md` printed a confident
  # "100% unmeasured" while three probes defended it. Sharing an extractor is not enough; the KEY has
  # to be shared too. Collisions are the control's job (_resolve_asset returns AMBIGUOUS).
  _scope_rows 2>/dev/null | awk -F'\t' -v asset="$1" -v anchor="$2" '
    { p = $1; sub(/^.*\//, "", p) }
    p == asset && $2 != "" && substr(anchor, 1, length($2)) == $2 { n++ }
    END { print n + 0 }'
}

# Every Scope CELL in the probe table, as "asset<TAB>name" — plus, on stderr, every cell this parser
# could not decompose. The first version grepped `<x>.md §` and silently dropped 7 of 20 cells (assets
# that are not .md, cells written without `§`, and one wrapped in backticks). It then printed
# `stale=0 · unresolvable=0`, which reads as "every scope resolves" while covering 65% of them —
# absence measured without a counter for what was skipped, the exact defect this repo names.
_all_scopes() { _scope_rows | sort -u; }

_resolve_asset() {  # $1=asset name -> a real path, 'AMBIGUOUS', or empty
  # -print -quit picked an arbitrary same-named file, which would validate a scope against the WRONG
  # file and hide a stale one. `templates/` is precisely where identically-named copies live.
  [ -f "$FH/$1" ] && { echo "$FH/$1"; return; }
  local n hits
  hits=$(find "$FH" -name "$(basename "$1")" -not -path '*/node_modules/*' 2>/dev/null)
  n=$(printf '%s\n' "$hits" | grep -c . )
  [ "$n" -eq 1 ] && { printf '%s\n' "$hits"; return; }
  [ "$n" -gt 1 ] && { echo AMBIGUOUS; return; }
  echo ""
}

# ── CONTROLS ──────────────────────────────────────────────────────────────────
# Two arms, because the first version only had the easy one. A known-negative ("garbage must not
# match") tests that the parser is not indiscriminate; it says nothing about whether real scopes
# resolve. Control B catches this instrument's actual failure mode: a section gets renamed or
# relocated (salience-splitter moves content out of CLAUDE.md routinely) and its probes silently stop
# matching, so the corpus reads as LESS covered than it is — an error that points the reader at
# deleting a section which is in fact defended.
_control() {
  local pos neg head rc=0 stale=0 nofile=0 nonmd=0 ambig=0 path a n
  head=$(grep -m1 '^## Autonomous Initiative' "$FH/CLAUDE.md" 2>/dev/null); head="${head#\#\# }"
  [ -n "$head" ] || { echo "  control A: FIXTURE — the anchor heading is gone from CLAUDE.md"; return 1; }
  pos=$(_scope_hits "CLAUDE.md" "$head")
  neg=$(_scope_hits "CLAUDE.md" "Zzz No Such Section Exists")
  # A SECOND positive arm, path-qualified on purpose. The first arm asks only about `CLAUDE.md`,
  # which every probe writes unqualified — so it never exercises the basename normalization in
  # _scope_hits, and reverting that normalization left both controls green (measured). A repair with
  # no arm that goes red when it is undone is not anchored; this is that arm.
  local pos2; pos2=$(_scope_hits "fh_4axis_gate.md" "Lightweight exception")
  # Third arm: a basename that really is duplicated in-tree must resolve to AMBIGUOUS. This anchors
  # the RESOLVER (reverting it to "pick the first hit" now turns this red — measured), which guards
  # the fail-open of validating a scope against the WRONG same-named file.
  # NAMED RESIDUAL: the `[ "$ambig" -eq 0 ]` term in the exit gate below is NOT anchored — no live
  # Scope uses a duplicated basename, so nothing drives `ambig` above 0, and dropping that term keeps
  # the controls green (measured). Anchoring it would mean mutating the probe corpus from inside the
  # control, which is not the control's business. Stated rather than papered over.
  local dup; dup=$(_resolve_asset "plugin.json")
  echo "  control A (known pair): positive='${head:0:34}…'=$pos (need >0) · path-qualified positive=$pos2 (need >0) · negative=$neg (need 0)"
  echo "  control A (duplicate-basename): plugin.json → ${dup:-<empty>} (need AMBIGUOUS)"
  { [ "${pos:-0}" -gt 0 ] && [ "${pos2:-0}" -gt 0 ] && [ "${neg:-0}" -eq 0 ] && [ "$dup" = AMBIGUOUS ]; } || rc=1

  while IFS=$'\t' read -r a n; do
    [ -n "$a" ] && [ -n "$n" ] || continue
    path=$(_resolve_asset "$a")
    if [ -z "$path" ]; then
      echo "  ⚠️  NOFILE  $a §$n — probe names an asset that does not resolve"
      nofile=$((nofile+1)); continue
    fi
    if [ "$path" = AMBIGUOUS ]; then
      echo "  ⚠️  AMBIGUOUS $a §$n — more than one file shares this basename; qualify the Scope with a path"
      ambig=$((ambig+1)); continue
    fi
    case "$a" in
      *.md) ;;
      *)  # A shell/JSON asset has no markdown anchors, so this extractor cannot decide. Saying
          # "stale" would be a false accusation; saying nothing would be a silent gap. Count it.
          echo "  ⚠️  UNCHECKABLE $a §$n — not a markdown asset; this extractor cannot resolve section anchors in it"
          nonmd=$((nonmd+1)); continue ;;
    esac
    if ! _anchors "$path" | awk -v n="$n" 'substr($0,1,length(n))==n{f=1} END{exit !f}'; then
      echo "  ❌ STALE   $a §$n — no section by that name in the asset (renamed, or relocated by a split)"
      stale=$((stale+1))
    fi
  done < <(_all_scopes)
  local skipped; skipped=$(_all_scopes 2>&1 >/dev/null | grep -c '^UNPARSED' || true)
  echo "  control B (scope resolution): stale=$stale · unresolvable-asset=$nofile · ambiguous-basename: $ambig (these three need 0) · non-markdown assets (undecidable here): $nonmd · scope cells this parser could NOT decompose: $skipped (reported, not silently dropped — this parser only splits on '§', so a scope written in another notation is UNVALIDATED here, not sectionless)"
  # `ambig` gates too. Without it an ambiguous basename printed a warning and then let the number
  # publish anyway — a caveated publish, which this script's own rule forbids ("the coverage number is
  # WITHHELD, not printed with a caveat"). It belongs with nofile, not with nonmd: non-markdown is
  # permanently undecidable here, whereas an ambiguous basename has a stated fix (qualify the Scope).
  { [ "$stale" -eq 0 ] && [ "$nofile" -eq 0 ] && [ "$ambig" -eq 0 ]; } || rc=1
  return $rc
}

[ -f "$PROBES" ] || { echo "❌ probe-scope: probe set missing: $PROBES — instrument error, NOT an empty result"; exit 1; }

echo "── probe-scope check — does every Scope still name a real section? ──"
if ! _control; then
  echo "❌ SCOPE CHECK FAILED (exit 3) — a probe points at a section that is not there."
  echo "   Fix the scope strings (or the probe) named above, then re-run. probes.md's own maintenance"
  echo "   rule already requires this: when a Scope target moves, its probes move in the same commit."
  exit 3
fi

echo "✅ every probe Scope resolves to a real section"
exit 0
