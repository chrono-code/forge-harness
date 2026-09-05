#!/usr/bin/env bash
# qp_tools.sh — the MECHANICAL half of fh-qp (QP · Quality Platform).
#
# The four qp-* skills are prose; a prose rule is muscle (a strong model carrying it), not skeleton.
# Everything a floor-tier session must NOT be trusted to "just do" lives here as a typed check with a
# closed exit enum, so a report can be read without trusting the narrator:
#
#   target-class   <url|app:NAME> [--profile FILE]      → PUBLIC | PROFILE_REQUIRED | PROFILE_OK | UNKNOWN
#   adapter-probe  --need web|desktop --tools "a,b,c"    → ADAPTER=<name> | HARNESS_ERROR
#   mask           <in> <out>                            → MASKED (residue 0) | RESIDUE
#   surface-reach  <evidence.tsv>                        → REACHED | PARTIAL | NOT_REACHED | UNMEASURED
#   mtm-check      <verdicts.tsv>                        → OK | INVALID
#   run-verbs      <verdicts.tsv>                        → OK (≥1 state-changing verb) | VERIFY_ONLY
#   screen-id      <snapshot-file>                       → 12-hex stable id of a DOM/pixel observation
#
# Exit enum (shared):  0 = pass/positive · 4 = PROFILE_REQUIRED · 5 = negative-but-typed (RESIDUE ·
#   NOT_REACHED · PARTIAL · VERIFY_ONLY · INVALID) · 10 = HARNESS_ERROR / UNMEASURED (fail-closed:
#   never read 10 as "clean" or "reached").
#
# Domain constants: ZERO. Every host/app name comes from the caller or the profile file.
# bash 3.2 compatible (macOS default). No python required.
set -uo pipefail

usage() { sed -n '2,20p' "$0" >&2; exit 10; }
[ $# -ge 1 ] || usage
CMD="$1"; shift

# ── helpers ────────────────────────────────────────────────────────────────────
_host_of() { # strip scheme, path, port, creds
  printf '%s' "$1" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#^[^/@]*@##; s#[/?].*$##; s#:[0-9]+$##' | tr 'A-Z' 'a-z'
}
_is_private_host() { # RFC1918 / loopback / link-local / non-public suffix / bare name
  local h="$1"
  case "$h" in
    localhost|127.*|10.*|192.168.*|169.254.*|0.0.0.0|::1) return 0 ;;
    172.1[6-9].*|172.2[0-9].*|172.3[01].*) return 0 ;;
    *.local|*.internal|*.lan|*.intra|*.home|*.test|*.localhost|*.private) return 0 ;;
  esac
  case "$h" in *.*) return 1 ;; *) return 0 ;; esac   # bare hostname (no dot) → not public
}
_profile_lists() { # $1 = profile file, $2 = needle (host or app name). YAML-lite: grep the value.
  [ -f "$1" ] || return 1
  /usr/bin/grep -qiF -- "$2" "$1"
}

# ── target-class ───────────────────────────────────────────────────────────────
cmd_target_class() {
  local target="" profile=""
  while [ $# -gt 0 ]; do case "$1" in --profile) profile="${2:-}"; shift 2 ;; *) target="$1"; shift ;; esac; done
  [ -n "$target" ] || { echo "target-class: missing target" >&2; exit 10; }
  case "$target" in
    app:*)
      local app="${target#app:}"
      if [ -n "$profile" ] && _profile_lists "$profile" "$app"; then echo "PROFILE_OK kind=desktop app=$app"; exit 0; fi
      echo "PROFILE_REQUIRED kind=desktop app=$app reason=desktop-targets-always-need-a-profile"; exit 4 ;;
    http://*|https://*)
      local h; h="$(_host_of "$target")"
      [ -n "$h" ] || { echo "UNKNOWN reason=no-host"; exit 10; }
      if _is_private_host "$h"; then
        if [ -n "$profile" ] && _profile_lists "$profile" "$h"; then echo "PROFILE_OK kind=web host=$h"; exit 0; fi
        echo "PROFILE_REQUIRED kind=web host=$h reason=non-public-host"; exit 4
      fi
      echo "PUBLIC kind=web host=$h"; exit 0 ;;
    *) echo "UNKNOWN reason=unrecognised-target-form (want http(s)://… or app:NAME)"; exit 10 ;;
  esac
}

# ── adapter-probe ──────────────────────────────────────────────────────────────
# bash cannot introspect the session's MCP servers; the SESSION passes the tool names it actually has.
# Omitting --tools is HARNESS_ERROR: unknown is not present.
cmd_adapter_probe() {
  local need="" tools=""
  while [ $# -gt 0 ]; do case "$1" in --need) need="${2:-}"; shift 2 ;; --tools) tools="${2:-}"; shift 2 ;; *) shift ;; esac; done
  [ "$need" = web ] || [ "$need" = desktop ] || { echo "HARNESS_ERROR reason=--need must be web|desktop"; exit 10; }
  [ -n "$tools" ] || { echo "HARNESS_ERROR reason=tool-list-not-supplied (unknown ≠ present)"; exit 10; }
  local t; for t in $(printf '%s' "$tools" | tr ',' ' '); do
    case "$need:$t" in
      web:mcp__playwright__browser_navigate)        echo "ADAPTER=playwright-mcp evidence=dom"; exit 0 ;;
      web:mcp__claude-in-chrome__navigate)          echo "ADAPTER=claude-in-chrome evidence=dom"; exit 0 ;;
      desktop:mcp__computer-use__screenshot)        echo "ADAPTER=computer-use-mcp evidence=pixel"; exit 0 ;;
    esac
  done
  echo "HARNESS_ERROR reason=no-$need-adapter-among-supplied-tools"; exit 10
}

# ── mask ───────────────────────────────────────────────────────────────────────
# Record-layer masking (the typing path still sends the real value). Residue 0 is asserted AFTER writing.
_MASK_EMAIL='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
_MASK_JWT='eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}'
_MASK_BEARER='[Bb]earer[[:space:]]+[A-Za-z0-9._~+/=-]{16,}'
_MASK_KEYLIKE='(sk|pk|ghp|gho|xox[abp]|AKIA)[-_][A-Za-z0-9_-]{12,}'
_MASK_HEX='[A-Fa-f0-9]{40,}'
_MASK_PWKV='([Pp]ass(word|wd)?|[Ss]ecret|[Tt]oken)[[:space:]]*[:=][[:space:]]*"?[^"[:space:],}]{4,}'
cmd_mask() {
  local in="${1:-}" out="${2:-}"
  [ -f "$in" ] || { echo "HARNESS_ERROR reason=input-missing"; exit 10; }
  [ -n "$out" ] || { echo "HARNESS_ERROR reason=output-missing"; exit 10; }
  sed -E \
    -e "s/$_MASK_JWT/__REDACTED_TOKEN__/g" \
    -e "s/$_MASK_BEARER/Bearer __REDACTED_TOKEN__/g" \
    -e "s/$_MASK_KEYLIKE/__REDACTED_TOKEN__/g" \
    -e "s/$_MASK_HEX/__REDACTED_TOKEN__/g" \
    -e "s/$_MASK_PWKV/\1=__REDACTED_SECRET__/g" \
    -e "s/$_MASK_EMAIL/__REDACTED_EMAIL__/g" \
    "$in" > "$out" || { echo "HARNESS_ERROR reason=sed-failed"; exit 10; }
  local residue
  # Strip our own markers before re-scanning — the Bearer pattern matches "__REDACTED_TOKEN__" itself
  # (18 word-chars). Known-pair caught this on first run: an instrument matching its own output is
  # [[feedback_lane_vocabulary_blind_to_its_own_fix]] in miniature.
  residue=$(sed -E 's/__REDACTED_[A-Z]+__//g' "$out" | /usr/bin/grep -cE "$_MASK_EMAIL|$_MASK_JWT|$_MASK_BEARER|$_MASK_HEX" 2>/dev/null); residue="${residue:-0}"
  if [ "$residue" -eq 0 ]; then echo "MASKED residue=0 out=$out"; exit 0; fi
  echo "RESIDUE residue=$residue out=$out"; exit 5
}

# ── surface-reach ──────────────────────────────────────────────────────────────
# evidence.tsv: tc_id <TAB> step <TAB> screen_hash   (one row per observed screen; hash = any stable id)
# Entry screen = the modal hash across the batch. A TC is "beyond entry" iff any of its hashes ≠ entry.
# Denominator = ALL tc_ids in the file. An empty file is UNMEASURED (10), never NOT_REACHED.
cmd_surface_reach() {
  local f="${1:-}"
  [ -f "$f" ] || { echo "UNMEASURED reason=evidence-missing"; exit 10; }
  [ -s "$f" ] || { echo "UNMEASURED reason=evidence-empty (empty set is not reached)"; exit 10; }
  LC_ALL=C awk -F'\t' '
    NF < 3 || $1 ~ /^#/ { next }
    { tc[$1]=1; n_rows++; cnt[$3]++; seen[$1 SUBSEP $3]=1 }
    END {
      if (n_rows == 0) { print "UNMEASURED reason=no-rows"; exit 10 }
      best=""; bestc=-1
      for (h in cnt) if (cnt[h] > bestc) { bestc=cnt[h]; best=h }
      total=0; beyond=0
      for (t in tc) { total++; b=0; for (k in seen) { split(k, p, SUBSEP); if (p[1]==t && p[2]!=best) b=1 } beyond+=b }
      st = (beyond==total) ? "REACHED" : (beyond==0 ? "NOT_REACHED" : "PARTIAL")
      printf "%s tcs_beyond_entry=%d tcs_total=%d entry_screen=%s\n", st, beyond, total, best
      exit (st=="REACHED") ? 0 : 5
    }' "$f"
}

# ── mtm-check ──────────────────────────────────────────────────────────────────
# verdicts.tsv: first non-comment line MUST be  #mtm: ACTIVE|UNAVAILABLE|FAILED|DISABLED
# rows: tc_id <TAB> status <TAB> branch <TAB> closure <TAB> verb <TAB> assertion <TAB> expected_source
#   status          ∈ PASS FAIL BLOCKED AMBIGUOUS
#   branch          ∈ AS_PLANNED DIFFERS_FROM_PLAN CODE_DIFFERS NONE
#   closure         ∈ MACHINE JUDGMENT   (MACHINE requires a non-empty assertion — the record that closed it)
#   verb            ∈ navigate click input verify
#   expected_source ∈ PLAN_DOC INVENTORY CODE HUMAN NONE   — WHERE the expected value came from.
# The branch→source binding is the mechanical discriminator (challenger #9, governor 2026-09-05):
#   DIFFERS_FROM_PLAN  ⇒ expected_source = PLAN_DOC  and #mtm: ACTIVE   (no plan doc → this branch is unreachable)
#   CODE_DIFFERS       ⇒ expected_source ∈ {CODE, PLAN_DOC}
#   AS_PLANNED         ⇒ expected_source ≠ NONE
#   NONE               ⇒ status ∈ {BLOCKED, AMBIGUOUS}  (a verdict with no branch is a non-verdict)
# Any violation → INVALID (10). The check asserts the RECORD's properties (typed · attributable ·
# non-vacuous), never whether the label is TRUE — that stays judgment (CLAUDE.md §Mechanization Boundary).
cmd_mtm_check() {
  local f="${1:-}"
  [ -f "$f" ] || { echo "INVALID reason=file-missing"; exit 10; }
  local mtm; mtm=$(/usr/bin/grep -m1 -E '^#mtm:' "$f" | sed -E 's/^#mtm:[[:space:]]*//' | tr -d '[:space:]')
  case "$mtm" in ACTIVE|UNAVAILABLE|FAILED|DISABLED) ;; *) echo "INVALID reason=mtm-state-missing-or-bad (#mtm: ACTIVE|UNAVAILABLE|FAILED|DISABLED)"; exit 10 ;; esac
  LC_ALL=C awk -F'\t' -v mtm="$mtm" '
    /^#/ || NF==0 { next }
    { rows++
      if (NF < 7) { bad++; why="row-has-" NF "-fields-need-7"; next }
      if ($2 !~ /^(PASS|FAIL|BLOCKED|AMBIGUOUS)$/) { bad++; why="status:" $2; next }
      if ($3 !~ /^(AS_PLANNED|DIFFERS_FROM_PLAN|CODE_DIFFERS|NONE)$/) { bad++; why="branch:" $3; next }
      if ($3 == "DIFFERS_FROM_PLAN" && mtm != "ACTIVE") { bad++; why="DIFFERS_FROM_PLAN-needs-mtm-ACTIVE"; next }
      if ($4 !~ /^(MACHINE|JUDGMENT)$/) { bad++; why="closure:" $4; next }
      if ($4 == "MACHINE" && $6 == "") { bad++; why="MACHINE-closure-without-assertion"; next }
      if ($5 !~ /^(navigate|click|input|verify)$/) { bad++; why="verb:" $5; next }
      if ($7 !~ /^(PLAN_DOC|INVENTORY|CODE|HUMAN|NONE)$/) { bad++; why="expected_source:" $7; next }
      if ($3 == "DIFFERS_FROM_PLAN" && $7 != "PLAN_DOC") { bad++; why="DIFFERS_FROM_PLAN-needs-expected_source=PLAN_DOC"; next }
      if ($3 == "CODE_DIFFERS" && $7 !~ /^(CODE|PLAN_DOC)$/) { bad++; why="CODE_DIFFERS-needs-expected_source=CODE|PLAN_DOC"; next }
      if ($3 == "AS_PLANNED" && $7 == "NONE") { bad++; why="AS_PLANNED-with-expected_source=NONE"; next }
      if ($3 == "NONE" && $2 !~ /^(BLOCKED|AMBIGUOUS)$/) { bad++; why="branch=NONE-only-for-BLOCKED|AMBIGUOUS"; next }
      if ($4=="MACHINE") m++; else j++
    }
    END {
      if (rows == 0) { print "INVALID reason=no-rows"; exit 10 }
      if (bad > 0) { printf "INVALID rows=%d bad=%d first=%s\n", rows, bad, why; exit 10 }
      printf "OK mtm=%s rows=%d machine_closed=%d judgment_left=%d\n", mtm, rows, m+0, j+0; exit 0
    }' "$f"
}

# ── screen-id ──────────────────────────────────────────────────────────────────
# First-use finding (2026-09-05, gh-pages target): Playwright MCP accessibility snapshots carry per-navigation
# ref tokens (`[ref=e12]`, then `[ref=f2e12]`, `[ref=f3e12]` …) — the SAME page hashed to three different ids
# across three visits, so surface_reach credited two TCs for "leaving the entry screen" before they clicked.
# The screen id must be a CONTENT hash: strip ref/active tokens and whitespace runs before hashing.
# Binary files (screenshots) are hashed as-is.
cmd_screen_id() {
  local f="${1:-}"
  [ -f "$f" ] || { echo "HARNESS_ERROR reason=file-missing"; exit 10; }
  if LC_ALL=C /usr/bin/grep -qI . "$f"; then
    sed -E 's/\[ref=[A-Za-z0-9]+\]//g; s/\[active\]//g; s/[[:space:]]+/ /g' "$f" | shasum -a 256 | cut -c1-12
  else
    shasum -a 256 "$f" | cut -c1-12
  fi
}

# ── run-verbs (challenger #13: verify-only evidence never exercised the runner) ─
cmd_run_verbs() {
  local f="${1:-}"
  [ -f "$f" ] || { echo "HARNESS_ERROR reason=file-missing"; exit 10; }
  local n; n=$(LC_ALL=C awk -F'\t' '!/^#/ && NF>=5 && ($5=="click" || $5=="input"){c++} END{print c+0}' "$f")
  if [ "$n" -ge 1 ]; then echo "OK state_changing_verbs=$n"; exit 0; fi
  echo "VERIFY_ONLY state_changing_verbs=0 (runner not exercised)"; exit 5
}

case "$CMD" in
  target-class)  cmd_target_class "$@" ;;
  adapter-probe) cmd_adapter_probe "$@" ;;
  mask)          cmd_mask "$@" ;;
  surface-reach) cmd_surface_reach "$@" ;;
  mtm-check)     cmd_mtm_check "$@" ;;
  run-verbs)     cmd_run_verbs "$@" ;;
  screen-id)     cmd_screen_id "$@" ;;
  *) usage ;;
esac
