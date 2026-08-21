#!/usr/bin/env bash
# fh_hub_identity.sh — shared hub-identity + companion-store namespace resolution.
#
# Sourced by sync-to-be.sh, sync-from-be.sh, and fh_session_load.sh — the write path, the return
# path, and the SessionStart reader all touch the SAME companion-store directories, and all three
# must agree on which namespace ("tracks-meta/" vs "tracks-meta-pmh/", etc.) belongs to THIS hub.
#
# Origin (pmh-dev#68 PR #368 review, 2026-08-14): sync-to-be.sh shipped the write-side namespace
# split, but sync-from-be.sh and fh_session_load.sh kept reading/writing the UNSUFFIXED paths
# unconditionally. A sibling hub (PMH) that successfully wrote to `tracks-meta-pmh/` would, on its
# very next SessionStart or `sync-from-be.sh` pull, read FH's own unsuffixed `tracks-meta/` back as
# if it were its own — and worse, the two machine-scoped legs (`tracks-meta/manifests/$MID.yaml`,
# `memory/_index/$MID.md`) are keyed by MACHINE id, not hub id, so FH and a sibling hub running on
# the SAME machine would round-trip each other's manifest/memory-index through the identical
# filename. Factoring identity resolution into one sourced file (found→extend on the existing
# hook_source_lib.sh pattern already used by fh_session_load.sh) means all three callers can never
# drift out of sync on what "this hub's namespace" means — a job three separate hand-copies of the
# same case-statement could not guarantee.
#
# CALLER CONTRACT: set $FH before sourcing this file, then call `fh_resolve_hub_identity`.
#   Success (recognized hub) → sets HUB_SUFFIX / HUB_NAME / TM / TA / TCH / TR / MMD / HO, returns 0.
#   Failure (unrecognized hub) → returns 1, leaves those variables UNSET. The caller decides how to
#     fail (sync-to-be.sh / sync-from-be.sh both refuse with exit 10 — "not my hub" only, never
#     reused for a real error; see either script's own comment on that code).
#
# A sibling hub's identifying text is NOT hardcoded here — this file ships in the PUBLIC
# forge-harness repo, and a sibling hub's name/header is an operator-private token in that context
# (the confidentiality gate blocked the first draft of sync-to-be.sh's fix for hardcoding one
# directly; `git grep` showed zero prior occurrences anywhere in this repo, i.e. a genuinely new
# leak, not an already-accepted pattern). Sibling identity instead comes from a LOCAL, gitignored
# config file (`.git/info/exclude`, same convention as the sibling's own local tracks config) — `key=value` lines,
# read as DATA (never sourced as shell, to avoid handing arbitrary code execution to a config file):
# HUB_HEADER_MATCH (a prefix of the sibling's CLAUDE.md first line), HUB_SUFFIX, HUB_NAME.

fh_resolve_hub_identity() {
  local hub1
  hub1="$(head -1 "$FH/CLAUDE.md" 2>/dev/null)"
  case "$hub1" in
    "# forge-harness — Persistent Knowledge Hub"*)
      HUB_SUFFIX=""; HUB_NAME="forge-harness"
      ;;
    *)
      local idfile match
      idfile="${FH_HUB_IDENTITY_FILE:-$FH/.fh-hub-identity.local}"
      # Always exits 0 (return via $? of the LAST command only) — under `set -eo pipefail` in a
      # caller, an unguarded `var="$(fn)"` assignment aborts the whole script if `fn`'s pipeline
      # exits nonzero, and both "no local identity file" AND "file exists but key absent" (grep
      # finds 0 matches → pipefail propagates grep's 1) must fall through to the caller's own
      # refuse path, not crash here (self-caught in testing when this lived inline in
      # sync-to-be.sh — a `return 0` on its own trailing line does NOT suffice, `set -e` aborts on
      # the failing pipeline before that line is ever reached; the `|| true` on the pipeline itself
      # is required). $2=1 additionally strips ALL whitespace (for value fields with no legitimate
      # internal spaces — HUB_SUFFIX/HUB_NAME become directory-name fragments, so a stray trailing
      # CR from a CRLF-authored file silently mints a second namespace, reproduced in review); the
      # header-match text keeps internal spaces (it legitimately contains them) and only a trailing
      # CR is stripped, matching the sibling's local-tracks-config reader's own trim (line ~338 of
      # sync-to-be.sh) applied to the field that actually needs it.
      _fh_hub_id_get() {
        [ -f "$idfile" ] || return 0
        local v
        v="$(grep "^$1=" "$idfile" 2>/dev/null | head -1 | cut -d= -f2- || true)"
        v="${v%$'\r'}"
        [ "${2:-}" = "1" ] && v="$(printf '%s' "$v" | tr -d '[:space:]')"
        printf '%s' "$v"
      }
      match="$(_fh_hub_id_get HUB_HEADER_MATCH)"
      if [ -n "$match" ] && [ "${hub1#"$match"}" != "$hub1" ]; then
        HUB_SUFFIX="$(_fh_hub_id_get HUB_SUFFIX 1)"
        HUB_NAME="$(_fh_hub_id_get HUB_NAME 1)"
      fi
      [ -n "${HUB_SUFFIX:-}" ] && [ -n "${HUB_NAME:-}" ] || return 1
      ;;
  esac
  TM="tracks-meta$HUB_SUFFIX"; TA="tracks-audit$HUB_SUFFIX"; TCH="tracks-chamber$HUB_SUFFIX"
  TR="tracks$HUB_SUFFIX"; MMD="memory$HUB_SUFFIX"
  # NOTE: the operator-private area's directory name is deliberately NOT set here.
  #   This file ships in the PUBLIC npm package (files[]), and that name is an operator-private
  #   token in that context — the same reason the sibling hub's name is read from local config
  #   rather than hardcoded (see the header). The only consumer is sync-to-be.sh, which does NOT
  #   ship, so it defines the name itself. Measured 2026-08-21: the pre-publish confidentiality
  #   scan blocked `npm publish` on this exact literal.
  return 0
}
