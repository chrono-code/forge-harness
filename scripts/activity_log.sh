#!/usr/bin/env bash
# activity_log.sh — on-demand chronological assembler (the portable LLM-Wiki `log.md`).
#
# WHY: the LLM-Wiki pattern (Karpathy; wikidocs book/19830) pairs an index (FH already has =
# CATALOG.md + MEMORY.md) with a `log.md` — a single time-ordered trail of every ingest/check the
# agent performed. FH's activity is scattered across 5+ record stores (edit_manifest, fh_signal,
# _audit, gate markers, subagent log). Rather than add a 6th always-write file, this ASSEMBLES the
# chronological view on demand from what already exists. Honest trade (not a free lunch): this MOVES
# the maintenance cost from "every writer must remember to append" (drift-prone — the fh_completed
# card-bug class) to "one parser branch per store format, here" (centralized, but silent on format
# drift). Mitigation: dates are pulled by regex after a prefix-strip, not by hardcoded character
# offsets, so a renamed prefix degrades toward an empty date (which emit_line drops) rather than
# silently slicing garbage. Zero new write obligation; backend-agnostic (plain stdout — runs in a
# bare terminal / air-gapped / ephemeral cloud, no Obsidian or any app required).
#
# Obsidian/gbrain are OPTIONAL frontends: `--emit <path>` writes the same view as a markdown file
# (e.g. a companion store's log.md) only when such a frontend exists. The portable core is the stdout default.
#
# Usage:
#   bash scripts/activity_log.sh                  # full chronological view (newest first) to stdout
#   bash scripts/activity_log.sh --since 2026-06-15
#   bash scripts/activity_log.sh --emit /path/to/store/log.md   # also write a markdown frontend file
#   bash scripts/activity_log.sh --asc            # oldest first
#
# NOTE: this is a best-effort assembler — many greps legitimately return no-match (a record store
# without a `date:` frontmatter line falls back to the filename date). So NO `set -e`: a non-matching
# grep must not abort the assembly. `set -u` (unset-var guard) is kept.
set -uo pipefail

HUB="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HUB"

SINCE=""
EMIT=""
ORDER="-r"   # newest first by default
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --emit)  EMIT="$2";  shift 2 ;;
    --asc)   ORDER="";   shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

emit_line() { # date  type  label  source
  local d="${1//_/-}"                                   # normalize _ date-separators -> -
  [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 0   # skip empty / malformed dates
  printf '%s\t%-7s %s\t[%s]\n' "$d" "$2" "$3" "$4" >> "$TMP"
}

# 1. edit_manifest.yaml — pair each "- id:" with its following "  date:"
if [[ -f tracks/_meta/edit_manifest.yaml ]]; then
  awk '
    /^- id:/      { id=$3 }
    /^  date:/    { if (id!="") { print $2 "\t" id; id="" } }
  ' tracks/_meta/edit_manifest.yaml | while IFS=$'\t' read -r d id; do
    emit_line "$d" "edit" "${id#em-}" "manifest"
  done
fi

# 2. fh_signal_<date>_<slug>.md
for f in tracks/_meta/fh_signal_*.md; do
  [[ -e "$f" ]] || continue
  base="$(basename "$f" .md)"; rest="${base#fh_signal_}"   # strip prefix (no hardcoded offset)
  d="$(printf '%s' "$rest" | grep -oE '^[0-9]{4}[-_][0-9]{2}[-_][0-9]{2}' | head -1)"
  slug="${rest:11}"
  emit_line "$d" "signal" "$slug" "fh_signal"
done

# 3. fh_completed_<date>.md
for f in tracks/_meta/fh_completed_*.md; do
  [[ -e "$f" ]] || continue
  base="$(basename "$f" .md)"; rest="${base#fh_completed_}"   # strip prefix (no hardcoded offset)
  d="$(printf '%s' "$rest" | grep -oE '^[0-9]{4}[-_][0-9]{2}[-_][0-9]{2}' | head -1)"
  emit_line "$d" "done" "session completions" "fh_completed"
done

# 4. gate markers (.axes_*_<date>.marker)
for f in tracks/_meta/.axes_*.marker; do
  [[ -e "$f" ]] || continue
  base="$(basename "$f")"; d="$(printf '%s' "$base" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
  [[ -n "$d" ]] && emit_line "$d" "gate" "4-axis marker" "axes_marker"
done

# 5. _audit/*.md — date from frontmatter; weekly_audit tagged distinctly
for f in tracks/_audit/*.md; do
  [[ -e "$f" ]] || continue
  d="$(grep -m1 '^date:' "$f" | awk '{print $2}')"
  [[ -z "$d" ]] && d="$(basename "$f" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
  [[ -z "$d" ]] && continue
  name="$(grep -m1 '^name:' "$f" | sed 's/^name:[[:space:]]*//')"
  [[ -z "$name" ]] && name="$(basename "$f" .md)"
  case "$(basename "$f")" in
    weekly_audit_*) emit_line "$d" "weekly" "$name" "_audit" ;;
    *)              emit_line "$d" "audit"  "$name" "_audit" ;;
  esac
done

# 6. subagent_invocations_log.yaml — dispatch events (date: field per entry)
# 전환 설계: 레거시 단일 파일 ∪ 세션별 디렉터리를 둘 다 읽는다 (session_close_check.sh 와 동일)
_SAL=knowledge/shared/learnings/subagent_invocations_log.yaml
_SAD=knowledge/shared/learnings/subagent_invocations
if [[ -f "$_SAL" || -d "$_SAD" ]]; then
  { [[ -f "$_SAL" ]] && cat "$_SAL"; [[ -d "$_SAD" ]] && cat "$_SAD"/*.yaml; } 2>/dev/null \
    | grep -E '^[[:space:]]*-?[[:space:]]*date:' \
    | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort | uniq -c | while read -r n d; do
      emit_line "$d" "dispatch" "$n agent invocation(s)" "subagent_log"
  done
fi

# 7. cadence artifacts (harness_doctor / frontier_digest in _meta)
for f in tracks/_meta/harness_doctor_*.md tracks/_meta/frontier_digest_*.md; do
  [[ -e "$f" ]] || continue
  d="$(basename "$f" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
  case "$(basename "$f")" in
    harness_doctor_*) emit_line "$d" "doctor"  "harness-doctor run" "_meta" ;;
    frontier_*)       emit_line "$d" "digest"  "frontier-digest"    "_meta" ;;
  esac
done

# --- assemble: filter by --since, sort chronologically ---
OUT="$(sort $ORDER "$TMP" | { [[ -n "$SINCE" ]] && awk -v s="$SINCE" '$1 >= s' || cat; })"

render() {
  echo "# FH Activity Log — assembled $(date +%Y-%m-%d) (portable LLM-Wiki core, on-demand)"
  echo "# index = CATALOG.md + MEMORY.md  |  this = chronological log over 5 record stores"
  [[ -n "$SINCE" ]] && echo "# since: $SINCE"
  echo
  echo "$OUT"
}

if [[ -n "$EMIT" ]]; then
  render > "$EMIT"
  echo "emitted $(printf '%s\n' "$OUT" | grep -c . ) events → $EMIT"
else
  render
fi
