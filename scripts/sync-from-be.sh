#!/usr/bin/env bash
# sync-from-be.sh — RETURN PATH: companion store → hub (the reverse of sync-to-be.sh).
#
# WHY THIS EXISTS (measured 2026-08-02, pro node):
#   sync-to-be.sh is deliberately ONE-WAY (hub = canonical, companion = mirror), and its
#   destination-newer guard fail-closes so a mirror edit is never silently clobbered. That guard is
#   correct and stays. What was missing is the other half: when a SECOND machine is the one that
#   advanced, its work reaches this hub's *gitignored* half (tracks/_meta, memory/) ONLY through
#   the companion store — and nothing pulled it back down. So the lagging machine could not catch
#   up, every sync attempt aborted on the same files forever, and the only documented escape was
#   SYNC_OVERWRITE_OK=1 — which would have DESTROYED the other machine's work.
#   That day the pro node was behind on three layers at once. Two of those figures are MEASURED and
#   re-checkable: the public repo was **23 commits** behind (git rev-list, reflog-anchored), and
#   **~70** companion files had no local counterpart (re-derivable by --dry-run). The per-file
#   counts for the tracks/_meta and memory repairs are an OPERATOR FIELD REPORT, not a measurement:
#   they were fixed by hand, which left no artifact to re-derive them from. They are labelled rather
#   than dropped, because a mixed list where two numbers are solid and two are recollection reads as
#   four equally solid numbers. (grounding audit F4, 2026-08-02.)
#   A guard whose only escape hatch is the data-loss button trains the data-loss button.
#   (Related: memory feedback_oneway_mirror_needs_destination_guard — the forward guard's origin.
#    An operator may also have shell helpers that sync the companion store BETWEEN MACHINES over a
#    private network; those move the store itself and never touch the hub's gitignored files, so
#    they are not this path. Verified on this setup 2026-08-02, not assumed.)
#
# DEGRADE DIRECTION — why auto-apply is legitimate here:
#   Overwriting a hub file is only irreversible if the previous bytes are gone. This script backs
#   up EVERY file it overwrites, under tracks/_meta/logs/sync_restore/<UTC>/, BEFORE writing.
#   CITED: CLAUDE.md §Irreversibility Gates — Surface-Class Degrade Invariant classifies SURFACES —
#   irreversible → fail-closed, reversible → degrade-to-advisory.
#   DERIVED (this script's own argument, not a quote): taking the backup first is what makes the
#   overwrite reversible, so the surface lands on the advisory side of that rule rather than
#   arriving there by assertion. The support is the Destructive-Op gate's own shape,
#   `enumerate → recover → destroy`, where the backup is the *recover* leg. Stating this as a
#   derivation matters: presenting an inference in the voice of a quoted floor is how a convenient
#   reading becomes doctrine. (grounding audit F3, 2026-08-02.)
#   Backup failure is therefore fail-CLOSED: no backup → no overwrite, full stop.
#
# WHAT IT DOES NOT DO (deliberate, not oversight):
#   - New files present in the companion but absent here are NOT created by default. On the pro
#     node that set was ~70 files, a substantial share of them originating in a restricted/corp
#     context. Landing corp-origin content on a personal machine is a RESIDENCY decision the
#     operator makes, not a transport default. `--include-new` opts in; the count is reported.
#   - A PEER's machine-scoped files (tracks-meta/manifests/*, memory/_index/*) are never pulled —
#     they belong to whichever machine wrote them. THIS machine's own two (edit_manifest.yaml,
#     MEMORY.md) DO come back, by exact <machine-id> match: on a re-imaged or fresh clone the
#     companion holds the only copy, and excluding the tree wholesale stranded them there.
#   - CLAUDE.local.md is never pulled — it is this operator's local binding for THIS machine.
#
# USAGE: sync-from-be.sh [--dry-run] [--include-new] [--quiet] [--no-git]
# EXIT:  0 = clean (nothing to do, or applied)   10 = harness error (never a silent pass)

set -uo pipefail

FH="${HUB_DIR:-${CLAUDE_PROJECT_DIR:-$HOME/projects/forge-harness}}"
BE="${BE_DIR:-$FH/../fh-be}"

DRY=0; INCLUDE_NEW=0; NEW_SCOPE=""; QUIET=0; DO_GIT=1
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    # --include-new[=AREA] — AREA is a prefix of the area label ("tracks", "memory",
    # "tracks/_meta"…). Scoped because the two areas differ in what creating a file DOES: a
    # tracks/ record is inert until read, while a memory/ file joins the auto-recall surface. The
    # bytes already sit in the companion store either way, so this flag governs EXPOSURE, not
    # storage — and those deserve separate answers.
    --include-new) INCLUDE_NEW=1 ;;
    --include-new=*) INCLUDE_NEW=1; NEW_SCOPE="${a#--include-new=}" ;;
    --quiet) QUIET=1 ;;
    --no-git) DO_GIT=0 ;;
    *) echo "sync-from-be: unknown arg: $a" >&2; exit 10 ;;
  esac
done

# log() = routine chatter (per-dir skips, "already up to date"), silenced by --quiet.
# say() = the outcome, NEVER silenced. --quiet exists so a SessionStart hook stays invisible on a
# no-op run — not so a run that MOVED FILES can do it silently. A transport that writes without
# saying so is the same failure shape as a wait-wrapper that reports COMPLETE without ever
# reaching its child (measured 2026-07-29): silence read as success.
log()  { [ "$QUIET" = "1" ] || echo "[sync-from-be] $*"; }
say()  { echo "[sync-from-be] $*"; }
warn() { echo "[sync-from-be] $*" >&2; }

# Hub-identity guard (fail-closed) — this is a WRITE path into the hub; refuse if $FH is not a
# recognized hub. Resolution (and the HUB_SUFFIX namespace under $BE — see below) is shared with
# sync-to-be.sh and fh_session_load.sh via fh_hub_identity.sh: a namespace fix that only lands on
# the write side and not here is exactly the gap a PR review caught (pmh-dev#68 PR #368) — a
# sibling hub reading these UNSUFFIXED paths would pull FH's own tracks-meta/ back as if it were
# its own, and the two machine-scoped legs below (keyed by machine id, not hub id) would round-trip
# FH's and a sibling's manifest/memory-index through the identical filename on a shared machine.
_FH_IDLIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fh_hub_identity.sh"
# shellcheck source=scripts/fh_hub_identity.sh
. "$_FH_IDLIB"
if ! fh_resolve_hub_identity; then
  warn "refuse: \$FH ($FH) is not a recognized hub — abort"; exit 10
fi
[ -d "$BE" ] || { log "no companion store at $BE — nothing to pull (no-op)"; exit 0; }

# Companion-state gate (fail-CLOSED). The forward script can leave the store mid-rebase when a
# concurrent push conflicts. A rebase re-checks-out the tree, stamping every touched file with
# `now` — so on the next session start EVERY file here looks newer, content differs (conflict
# markers), and this script would faithfully copy `<<<<<<< HEAD` over the hub's metadata before
# reporting anything. Backups would exist, but an unattended hook must not corrupt first and
# explain second. Read the source, not just the directory. (cross-family M3, 2026-08-02.)
if command -v git >/dev/null 2>&1 && git -C "$BE" rev-parse --git-dir >/dev/null 2>&1; then
  # Resolved INSIDE the store for the same reason as git_ff below (R2 #7): --git-path is repo-relative.
  _gd="$( cd "$BE" 2>/dev/null && git rev-parse --git-path rebase-merge 2>/dev/null )"
  _ga="$( cd "$BE" 2>/dev/null && git rev-parse --git-path rebase-apply 2>/dev/null )"
  if ( cd "$BE" 2>/dev/null && { [ -d "$_gd" ] || [ -d "$_ga" ]; } ) \
     || git -C "$BE" status --porcelain 2>/dev/null | grep -q '^\(UU\|AA\|DD\|AU\|UA\|DU\|UD\)'; then
    warn "companion store is mid-rebase or has unmerged paths — refusing to pull (nothing written)."
    warn "  resolve it there first: git -C \"$BE\" status"
    exit 10
  fi
fi

# Portable mtime. GNU-first: on GNU/coreutils `stat -f %m` exits 0 with filesystem-format output
# and would never reach a BSD fallback, so probe `stat -c %Y` FIRST (same fix as fh_session_load.sh).
_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

# Portable permission bits — SAME ordering rule as _mtime, and it was missed here first time round.
# `stat -f` on GNU means --file-system: it SUCCEEDS on a regular file and emits filesystem fields, so
# a BSD-first chain never reaches the GNU branch on Linux. The octal sanitizer below then blanks the
# result, which means the mode-preservation hardening directly under this line was a **silent no-op
# on every Linux run** — including CI. It read as working because its 4 lanes only ever ran on macOS
# (they had no automated caller until this change wired them). Fix is ordering, not a new mechanism.
# Returns '' when the mode cannot be read; every caller already treats '' as "do not chmod".
_mode() {
  local m
  m="$(stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null || echo '')"
  case "$m" in ''|*[!0-7]*) echo '' ;; *) echo "$m" ;; esac
}

# ── Layer 1: public repo freshness ────────────────────────────────────────────
# The tracked half travels by git, not by this transport — but "am I behind?" is one question, so
# it is answered here too. NEVER touches a dirty tree, and never leaves the current branch.
git_ff() {
  command -v git >/dev/null 2>&1 || { log "git: not installed — skipped"; return 0; }
  git -C "$FH" rev-parse --git-dir >/dev/null 2>&1 || { log "git: hub is not a repo — skipped"; return 0; }
  # Never let git block on a credential prompt: this runs inside a SessionStart hook with a wall
  # budget, and a fetch that sits waiting on stdin eats the whole budget — the hook is then SIGTERMed
  # partway through Layer 2. Bounded + non-interactive, so a private remote degrades to "skipped"
  # instead of to a half-finished write. (cross-family M6, 2026-08-02.)
  local _to=""; command -v timeout >/dev/null 2>&1 && _to="timeout 15"
  GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true GIT_SSH_COMMAND="ssh -oBatchMode=yes" \
    $_to git -C "$FH" fetch origin --quiet 2>/dev/null \
    || { log "git: fetch failed or timed out (offline / auth required?) — skipped"; return 0; }
  local br behind
  br="$(git -C "$FH" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  behind="$(git -C "$FH" rev-list --count main..origin/main 2>/dev/null || echo 0)"
  case "$behind" in ''|*[!0-9]*) behind=0 ;; esac   # integer-sanitize: a non-numeric would break -gt
  [ "$behind" -gt 0 ] || { log "git: main up to date with origin"; return 0; }
  if [ "$DRY" = "1" ]; then log "git: main is $behind commit(s) behind origin (dry-run, not applied)"; return 0; fi
  if [ "$br" = "main" ]; then
    if [ -n "$(git -C "$FH" status --porcelain 2>/dev/null)" ]; then
      warn "git: main is $behind behind but the tree is DIRTY — not touching it. Commit/stash, then: git merge --ff-only origin/main"
    else
      git -C "$FH" merge --ff-only origin/main >/dev/null 2>&1 \
        && log "git: main fast-forwarded ($behind commit(s))" \
        || warn "git: --ff-only refused (main has diverged) — resolve by hand"
    fi
  else
    # Not on main: move the local ref only. Never checks out, never touches the worktree — but a ref
    # move is still a mutation, so it is gated on repo state too. The dirty-tree guard above only
    # covered the on-main path, which left an unattended hook free to move refs during a detached
    # HEAD or a half-finished rebase/merge/cherry-pick. (cross-family MED #9, 2026-08-02.)
    if [ "$br" = "HEAD" ]; then warn "git: detached HEAD — not moving refs"; return 0; fi
    # `git -C X rev-parse --git-path` prints a path relative to X, so testing it from THIS cwd
    # silently found nothing and the ref move proceeded mid-merge. Resolve inside the repo.
    # (R2 #7, reproduced 2026-08-02: `.git/MERGE_HEAD` returned from a foreign cwd.)
    for _st in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD BISECT_LOG; do
      if ( cd "$FH" 2>/dev/null && [ -e "$(git rev-parse --git-path "$_st" 2>/dev/null)" ] ); then
        warn "git: repo is mid-$_st — not moving refs"; return 0
      fi
    done
    git -C "$FH" fetch origin main:main >/dev/null 2>&1 \
      && log "git: local main ref fast-forwarded ($behind commit(s)); you are on '$br'" \
      || warn "git: could not fast-forward local main ($behind behind) — diverged, resolve by hand"
  fi
}

# ── Layer 2: gitignored half (the actual return path) ─────────────────────────
STAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
# PID-suffixed: two runs inside the same second would otherwise share a restore root, and the
# no-clobber check below would then refuse the second run's legitimate backup. (R2 #6.)
RESTORE_ROOT="$FH/tracks/_meta/logs/sync_restore/$STAMP.$$"   # logs/ is excluded from the FORWARD sync

N_CLEAN=0; N_REVIEW=0; N_NEW=0; N_CREATED=0; N_SKIP_NEW=0; N_SKIP_DIR=0; N_MACHINE=0
NEW_LIST=""; REVIEW_LIST=""; SKIP_DIR_LIST=""; ERRORS=0

# A mirrored .md carries the sync banner on line 1; every read of a mirror file goes through this,
# so the banner never lands in the hub copy. (Same predicate as sync-to-be.sh _dest_content_differs.)
# The exact banner the forward script injects. Substring matching ('contains MIRROR COPY') would
# silently delete line 1 of any legitimate file that merely mentions the phrase — and this file is
# read INTO the hub, so that deletion is the payload. Byte-identical to sync-to-be.sh's BANNER.
MIRROR_BANNER='<!-- MIRROR COPY — synced from the forge-harness hub. Do NOT edit here; the next sync overwrites it. Edit the canonical file under the hub instead. -->'

# Banner handling must match the forward script's SCOPE, not just its predicate: the forward stamps
# the banner on `*.md` only, so de-bannering everything would silently delete a first line that
# merely happens to contain the string in a non-md file. (cross-family L3.)
_debanner() {
  case "$1" in
    *.md) if [ "$(head -1 "$1" 2>/dev/null)" = "$MIRROR_BANNER" ]; then tail -n +2 "$1"; else cat "$1"; fi ;;
    *)    cat "$1" ;;
  esac
}

# Write via temp + rename. `> "$h"` truncates the destination BEFORE the source is read, so a read
# error, a full disk, or the hook's own SIGTERM leaves the hub file empty or half-written — while
# the report still said the file was left untouched. rename(2) is atomic within a filesystem, so the
# hub file is either the old bytes or the complete new bytes, never a fragment. (Same pattern the
# forward script already uses for banner stamping.) (cross-family S3 + M6, 2026-08-02.)
# The temp file must live in the DESTINATION directory (rename is only atomic within a filesystem),
# which puts it inside a tree the FORWARD sync mirrors outward. So it is named with a `.marker`
# suffix — already excluded by both scripts — and a trap sweeps it if this process is killed
# mid-write. Belt and braces on purpose: a leaked temp that propagates to the companion store would
# be a defect created by the fix for S3. (self-caught 2026-08-02, before the round-2 audit.)
_TMP_INFLIGHT=""
_sfb_cleanup() { [ -n "$_TMP_INFLIGHT" ] && rm -f "$_TMP_INFLIGHT" 2>/dev/null; }
trap '_sfb_cleanup' EXIT HUP INT TERM

_write_atomic() {   # $1 = source file, $2 = destination path  → 0 ok, 1 failed (dest untouched)
  local src="$1" dst="$2" tmp="$2.sfb.$$.marker" mode=""
  # A DETERMINISTIC temp path can be pre-created (as a symlink, by accident or otherwise): the
  # redirect would then follow it and write outside, and the mv would install that link as the hub
  # file. Refuse any pre-existing temp path rather than trusting it. (R2 #2.)
  if [ -e "$tmp" ] || [ -L "$tmp" ]; then
    warn "temp path already exists — refusing to write $dst"; return 1
  fi
  _TMP_INFLIGHT="$tmp"
  _debanner "$src" > "$tmp" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; _TMP_INFLIGHT=""; return 1; }
  # Permission preservation: the temp is created under the caller's umask, so a rename would quietly
  # relax a 0600 destination to 0644. Measured 2026-08-02 (R2 #4). Widening permissions is a
  # silent-loss class of its own, so it is copied from the destination before the swap.
  # Reference mode: the destination's if it exists (preserve what is there), otherwise the SOURCE's
  # (do not relax what the companion protected). Creating new files under the bare umask widened a
  # 0600 companion file to 0644 on an ordinary run. (R6 #2.)
  local _ref="$dst"; [ -f "$dst" ] || _ref="$src"
  if [ -f "$_ref" ]; then
    mode="$(_mode "$_ref")"
    if [ -n "$mode" ] && ! chmod "$mode" "$tmp" 2>/dev/null; then
      # Abort only if the failure would actually WIDEN the destination. Making every chmod failure
      # fatal turned a hardening step into an outage on filesystems that do not implement modes
      # (FAT/exFAT, some mounted shares), where nothing was being protected in the first place.
      # Compare, then decide. (R4 NEW-A: hardening must not create its own failure mode.)
      local tmode
      tmode="$(_mode "$tmp")"
      # Widening = the temp grants any permission bit the destination does not. Bitwise, not numeric:
      # `tmode AND NOT dmode` must be empty. (R5 #3 — reproduced 0755 -> 0666 passing as "not wider".)
      local _extra=0
      if [ -n "$tmode" ]; then _extra=$(( (8#$tmode) & ~(8#$mode) & 07777 )); fi
      if [ -z "$tmode" ] || [ "$_extra" -ne 0 ]; then
        warn "could not preserve mode $mode on $dst (ref: $_ref) — refusing rather than widening it"
        rm -f "$tmp" 2>/dev/null; _TMP_INFLIGHT=""; return 1
      fi
      log "note: chmod unsupported here; mode $tmode is not wider than $mode — proceeding"
    fi
  fi
  [ -f "$tmp" ] && [ ! -L "$tmp" ] || { rm -f "$tmp" 2>/dev/null; _TMP_INFLIGHT=""; return 1; }
  if mv -f "$tmp" "$dst" 2>/dev/null; then _TMP_INFLIGHT=""; return 0; fi
  rm -f "$tmp" 2>/dev/null; _TMP_INFLIGHT=""
  return 1
}

# A symlinked PARENT directory escapes the hub just as a symlinked file does, and only the final
# path was being checked. An operator relocating a track dir to another volume is the accidental
# version of this. Refuse when the resolved destination directory leaves its intended root. (R2 #1.)
# Containment is decided by RESOLUTION, not by banning symlinks. Refusing every path with a
# symlinked ancestor over-blocked instantly: on macOS `/var` is itself a symlink, so every path
# under a temp dir "crossed a symlink" and the whole transport refused to write. An over-blocking
# guard is not a strict guard — it is one the operator learns to bypass, which is how a gate becomes
# decoration. So: resolve the area root once, require it to land where it belongs, and below it
# refuse only the symlinks that would take a write back out. (R4 fix, over-block caught by the lanes
# on the first run — which is what they are for.)
_prospective_inside() {   # $1 = path that may not exist yet, $2 = dir it must live inside
  # Resolves the nearest existing ANCESTOR and checks containment there, so the verdict is available
  # before any mkdir. Without this, `mkdir -p "$dst"` created directories outside the hub and the
  # refusal arrived afterwards — no bytes escaped, but the filesystem mutation did. (R5 #1.)
  local p="$1" want="$2" rin anc
  rin="$(cd "$want" 2>/dev/null && pwd -P)" || return 1
  anc="$p"
  while [ ! -d "$anc" ] && [ "$anc" != "/" ] && [ -n "$anc" ]; do anc="${anc%/*}"; [ -z "$anc" ] && anc="/"; done
  anc="$(cd "$anc" 2>/dev/null && pwd -P)" || return 1
  case "$anc/" in "$rin"/*|"$rin"/) return 0 ;; esac
  return 1
}

_resolve_root() {   # $1 = area root, $2 = dir it must resolve inside ("" = no containment req.)
  local rroot rin
  rroot="$(cd "$1" 2>/dev/null && pwd -P)" || return 1
  if [ -n "$2" ]; then
    rin="$(cd "$2" 2>/dev/null && pwd -P)" || return 1
    case "$rroot/" in "$rin"/*|"$rin"/) : ;; *) return 1 ;; esac
  fi
  printf '%s' "$rroot"
}

_rel_escapes() {   # $1 = RESOLVED root, $2 = relative path → 0 if a component below the root escapes
  local cur="$1" rest="${2%/*}" part
  [ "$rest" = "$2" ] && rest=""            # a top-level filename has nothing to walk
  case "$2" in /*) return 0 ;; esac                      # absolute never belongs in a rel path
  case "/$2/" in */../*) return 0 ;; esac                # a `..` COMPONENT — not the substring, so
                                                         # `valid..name.md` stays legal (R5 #4)
  while [ -n "$rest" ]; do
    part="${rest%%/*}"
    case "$rest" in */*) rest="${rest#*/}" ;; *) rest="" ;; esac
    [ -n "$part" ] || continue
    cur="$cur/$part"
    [ -L "$cur" ] && return 0
  done
  return 1
}

# The backup root and the held marker both live under tracks/_meta and were simply ASSUMED to be
# inside the hub. When that path resolves outward, backups — the entire reversibility argument — and
# the marker were written outside while the run still reported success. Decided once, here. (R5 #2.)
META_SAFE=1
_prospective_inside "$FH/tracks/_meta" "$FH" || META_SAFE=0

# THE single write funnel. Every byte this script puts into the hub goes through here — the new-file
# path, the overwrite path, and the machine-scoped restore. Round 4's second S-finding was simply
# that the machine-scoped leg had its own private write and therefore its own missing guard; the
# answer to "another call site was forgotten" is one call site, not a third guard.
#   $1 companion source · $2 hub destination · $3 label (for messages) · $4 backup basename ("" = none)
# → 0 written · 1 refused/failed (destination keeps its original bytes either way)
#   $1 companion source · $2 hub destination · $3 label · $4 backup basename ("" = none)
#   $5 RESOLVED area root · $6 relative path under it
_install_file() {
  local src="$1" dst="$2" label="$3" bname="$4" rroot="$5" rel="$6" bdir
  if [ -n "$rroot" ] && _rel_escapes "$rroot" "$rel"; then
    warn "path escapes $label via a symlinked directory — refusing: $dst"; return 1
  fi
  [ -L "$src" ] && { warn "companion-side symlink — skipped ($label): $src"; return 1; }
  [ -L "$dst" ] && { warn "destination is a symlink — never written through ($label): $dst"; return 1; }
  # mkdir lives HERE, after validation. Twice now the ordering broke because the call site created
  # the directory first and the guard spoke afterwards — so the guard no longer has a call site to
  # be out of order with.
  mkdir -p "$(dirname "$dst")" 2>/dev/null || { warn "cannot create parent dir ($label): $dst"; return 1; }
  if [ -f "$dst" ] && [ -n "$bname" ]; then
    [ "$META_SAFE" = "1" ] || { warn "backup root resolves outside the hub — refusing to overwrite $dst"; return 1; }
    # The backup path MIRRORS the source path instead of flattening it. Flattening `/`→`~` made
    # `a/b.md` and an ordinary `a~b.md` share one backup name, and the collision guard then refused a
    # perfectly normal second overwrite. Mirroring cannot collide, because distinct sources have
    # distinct paths by construction. (R6 #1 — an over-block on a normal layout, self-inflicted.)
    local _bsub _bfile
    case "$bname" in */*) _bsub="${bname%/*}"; _bfile="${bname##*/}" ;; *) _bsub="."; _bfile="$bname" ;; esac
    bdir="$RESTORE_ROOT/$label/$_bsub"
    mkdir -p "$bdir" || { warn "BACKUP FAILED (mkdir) — refusing to overwrite $dst"; return 1; }
    [ -e "$bdir/$_bfile" ] && { warn "BACKUP PATH COLLISION — refusing to overwrite $dst"; return 1; }
    cp -p "$dst" "$bdir/$_bfile" || { warn "BACKUP FAILED (cp) — refusing to overwrite $dst"; return 1; }
  fi
  _write_atomic "$src" "$dst" || { warn "WRITE FAILED — $dst left as-is${bname:+; backup at $bdir/$_bfile}"; return 1; }
  return 0
}

pull_dir() {   # $1 = companion (source) dir, $2 = hub (destination) dir, $3 = label
  local src="$1" dst="$2" label="$3" f rel h bdir seen=0 listing ROOT_R
  [ -d "$src" ] || return 0
  if [ ! -d "$dst" ]; then
    # The forward script CREATES a missing destination (mkdir -p). Silently skipping here would
    # make the pair lenient in one direction only: an area the hub mirrors outward could never come
    # back, and under --quiet the skip left no trace at all. Creating the dir is the same residency
    # decision as creating a file, so it rides --include-new; otherwise it is SAID, not whispered.
    # (cross-family M2, 2026-08-02.)
    if [ "$INCLUDE_NEW" = "1" ] && [ "$DRY" = "0" ]; then
      # Validate the ROOT before creating it: `mkdir -p` through a symlinked ancestor materialises
      # directories outside the hub before any per-file guard can speak. (R4 NEW-S / R5 #1 — the
      # first version checked AFTER mkdir, so no bytes escaped but directories did.)
      case "$dst" in
        "$FH"/*) _prospective_inside "$dst" "$FH" || { warn "$label would be created outside the hub — refusing"; ERRORS=$((ERRORS+1)); return 0; } ;;
      esac
      mkdir -p "$dst" 2>/dev/null || { warn "cannot create hub dir for $label — skipped"; ERRORS=$((ERRORS+1)); return 0; }
    else
      N_SKIP_DIR=$((N_SKIP_DIR+1)); SKIP_DIR_LIST="$SKIP_DIR_LIST    $label
"
      return 0
    fi
  fi
  # Resolve the area root ONCE. An area under the hub must RESOLVE inside the hub — that is what
  # catches `tracks -> /outside`, without banning the ordinary system symlinks above it. The memory
  # dir legitimately lives outside the hub, so it carries no containment requirement, only the
  # below-root walk. (R4 NEW-S, over-block-free form.)
  case "$dst" in
    "$FH"/*) ROOT_R="$(_resolve_root "$dst" "$FH")" || { warn "$label resolves outside the hub — refusing"; ERRORS=$((ERRORS+1)); return 0; } ;;
    *)       ROOT_R="$(_resolve_root "$dst" "")"    || { warn "$label cannot be resolved — refusing"; ERRORS=$((ERRORS+1)); return 0; } ;;
  esac
  # `find` failure must not read as "nothing to do". Its exit status is invisible through process
  # substitution, so collect first and check. An unreadable mount or a permission error otherwise
  # produced zero lines and a cheerful all-clear — the absence-without-a-control trap.
  # (cross-family M1, 2026-08-02.) -print0/-d '' so newlines in filenames cannot split a path.
  listing="$(mktemp)" || { warn "mktemp failed — cannot enumerate $label"; ERRORS=$((ERRORS+1)); return 0; }
  if ! find "$src" -type f ! -name '.gitkeep' ! -name '*.marker' \
         ! -path '*/logs/*' ! -path '*/manifests/*' ! -path '*/_index/*' \
         ! -path '*/substrate/*' \
         ! -name '.fh_node_state' ! -name 'MEMORY.md' ! -name 'edit_manifest.yaml' \
         ! -name '.substrate_versions' \
         ! -name '.sync_from_be_held.marker' ! -name '.sync_overwrite_override_log' \
         -print0 > "$listing" 2>/dev/null; then
    warn "enumeration FAILED for $label — not treating that as 'nothing to pull'"
    ERRORS=$((ERRORS+1)); rm -f "$listing"; return 0
  fi
  while IFS= read -r -d '' f; do
    [ -n "$f" ] || continue
    seen=$((seen+1))
    rel="${f#"$src"/}"                      # quoted: a glob char in $BE would break the prefix strip
    h="$dst/$rel"
    if [ -L "$h" ]; then
      # cp -p backs up the CONTENT while a write follows the LINK — restoring would silently turn a
      # symlink into a regular file, and a dangling link would be written outside the hub entirely.
      # Refuse rather than guess. (cross-family M5, 2026-08-02.)
      warn "symlink in the hub — skipped (never written through): $h"; ERRORS=$((ERRORS+1)); continue
    fi
    if [ ! -f "$h" ]; then
      # Present in the companion, absent here → new. Residency decision, not a transport default.
      N_NEW=$((N_NEW+1))
      # In scope only when --include-new was given AND (no AREA, or this label starts with AREA).
      local in_scope=0
      if [ "$INCLUDE_NEW" = "1" ]; then
        case "$label" in "${NEW_SCOPE}"*) in_scope=1 ;; esac
      fi
      if [ "$in_scope" = "1" ] && [ "$DRY" = "0" ]; then
        _install_file "$f" "$h" "$label" "" "$ROOT_R" "$rel" || { ERRORS=$((ERRORS+1)); continue; }
        N_CREATED=$((N_CREATED+1))
      else
        # Listed ONLY when actually skipped. Collecting every new file here and printing it under
        # a "NOT created" heading reported files that had just been created — the count was right
        # and the list was a lie, which is worse than either alone. (Caught 2026-08-02 by checking
        # the filesystem instead of believing the summary.)
        N_SKIP_NEW=$((N_SKIP_NEW+1)); NEW_LIST="$NEW_LIST    $label/$rel
"
      fi
      continue
    fi
    # Only pull when the companion is BOTH newer and different. Content is the discriminator:
    # if the bytes match, pulling transfers nothing (mtime churn from git checkout/rebase is the
    # known false signal — see sync-to-be.sh's `_dest_content_differs` and the rebase-mtime-churn
    # note above it, which documents the same trap in the other direction).
    # `! -ot` (newer-or-EQUAL), not `-nt`. The forward script restores the source mtime after
    # stamping its banner, so a healthy mirror sits at exactly equal mtimes — and with a strict `-nt`
    # any file that then diverged in content without advancing mtime (1s filesystem granularity,
    # clock skew between machines, another `touch -r`) would be silently and PERMANENTLY unpullable.
    # Equality is decided by content on the next line, so widening here costs a cmp, not a wrong
    # overwrite; a genuinely hub-newer file is still excluded. (cross-family L1, 2026-08-02.)
    [ ! "$f" -ot "$h" ] || continue
    _debanner "$f" | cmp -s - "$h" && continue
    # Classify for the OPERATOR'S EYE, not for the control flow: pure-addition (the companion only
    # adds lines) vs divergent (lines exist here that the companion lacks — a rewrite, or possibly
    # local work). Both are applied, because the backup makes both reversible; the divergent ones
    # are printed so a real conflict is seen rather than buried.
    local uniq tie=0
    uniq=$(diff "$h" <(_debanner "$f") 2>/dev/null | grep -c '^<')
    case "$uniq" in ''|*[!0-9]*) uniq=0 ;; esac
    # Widening the mtime predicate to `! -ot` bought back the permanently-unpullable case, but it
    # also means an EQUAL mtime with different content now resolves toward the companion — and that
    # direction is a guess, not a fact (a hub edit whose mtime was preserved looks identical to a
    # stale companion). So a tie is never silently "clean": it is forced into REVIEW, where it is
    # printed with its backup path. (R2 #9.)
    [ "$f" -nt "$h" ] || tie=1
    if [ "$DRY" = "0" ]; then
      # Backup basename carries the relative path flattened, so two files with the same basename in
      # different subdirectories cannot collide in the restore tree.
      _install_file "$f" "$h" "$label" "$rel" "$ROOT_R" "$rel" \
        || { ERRORS=$((ERRORS+1)); continue; }
    fi
    if [ "$uniq" -gt 0 ] || [ "$tie" = "1" ]; then
      N_REVIEW=$((N_REVIEW+1))
      if [ "$tie" = "1" ]; then
        REVIEW_LIST="$REVIEW_LIST    $label/$rel  (SAME mtime, different content — direction was a guess)
"
      else
        REVIEW_LIST="$REVIEW_LIST    $label/$rel  (${uniq} line(s) here were not in the companion)
"
      fi
    else
      N_CLEAN=$((N_CLEAN+1))
    fi
  done < "$listing"
  rm -f "$listing"
  # Instrument alarm, not a verdict: a non-empty source that yields zero candidates is far more
  # often a broken predicate than a healthy no-op (all-of-them-zero is a calibration signal).
  if [ "$seen" -eq 0 ] && [ -n "$(find "$src" -type f -print -quit 2>/dev/null)" ]; then
    log "note: $label — source has files but the filter matched none (expected if it holds only excluded names)"
  fi
  return 0
}

# ── Exclusions (the list above, stated once in prose) ─────────────────────────
# These must MATCH THE FORWARD SCRIPT's, or a file it refuses to mirror outward gets pulled inward
# and the pair is lenient in exactly one direction.
#   .fh_node_state       — MEASURED failure. sync-to-be.sh already excludes it (SYNC_EXCLUDES), but a
#                          copy pushed BEFORE that exclusion existed still sits in the store (rsync
#                          runs without --delete, so a retired file is never reaped). Omitting it
#                          here pulled one machine's node identity onto another — verified
#                          2026-08-02, this hub briefly carried a peer's hostname as its own.
#   MEMORY.md            — the live auto-recall INDEX. It is machine-scoped by CONTENT (it lists what
#   edit_manifest.yaml     THIS machine holds) while living at a SHARED path, so a path-based
#   .substrate_versions    exclusion cannot catch it. The forward script re-homes all three into
#                          manifests/, _index/, and substrate/, and deletes the shared copy — but
#                          only on a machine that HAS the local file, so a leftover shared copy is
#                          reachable. Excluded by NAME. (cross-family M4, 2026-08-02 for the first
#                          two; `.substrate_versions` added 2026-08-14, pmh-dev#69.)
#   .close_stamps_<date> — machine-scoped in nature (a local close counter) but has no
#                          companion-store consumer at all, so it is excluded ENTIRELY by the
#                          forward script (SYNC_EXCLUDES) rather than re-homed — nothing to pull
#                          back on this side either; listed here for the same reason `.fh_node_state`
#                          is: a belt-and-suspenders name exclusion in case a stale copy ever lands.
# ⚠️ scripts/sync_guard_check.sh asserts the forward script's two copies of this list stay
# equivalent. This is the THIRD copy; it is covered there too — do not edit one without the others.

# ── Machine-scoped return leg (same machine ONLY) ────────────────────────────
# The forward script re-homes three files out of the shared namespace into a per-machine name:
#   tracks/_meta/edit_manifest.yaml     → tracks-meta/manifests/<MID>.yaml
#   memory/MEMORY.md                    → memory/_index/<MID>.md
#   tracks/_meta/.substrate_versions    → tracks-meta/substrate/<MID>
# Excluding those trees wholesale (correct, so a PEER's copy never lands here) also made this
# machine unable to recover ITS OWN — the one case where the companion holds the only copy, e.g. a
# re-imaged or freshly cloned node. So: pull back only the file whose name IS this machine's id.
# Same backup + atomic-write rules; never creates one that does not already exist upstream.
# (cross-family HIGH #7, 2026-08-02.)
machine_id() {
  if [ -n "${FH_MACHINE_ID:-}" ]; then
    # REJECT rather than sanitize. Stripping turns `../../etc` into `etc`, which is not a traversal
    # but IS an impersonation: this machine would restore a file belonging to the id `etc`. A
    # malformed id is a configuration error, and a configuration error must not resolve to some
    # other machine's identity. (R2 #8.)
    case "$FH_MACHINE_ID" in
      *[!A-Za-z0-9_-]*|'') warn "FH_MACHINE_ID is not [A-Za-z0-9_-]+ — machine-scoped restore skipped"; return 1 ;;
    esac
    printf '%s' "$FH_MACHINE_ID" | cut -c1-32; return 0
  fi
  local h
  h=$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'unknown')
  printf 'm%s' "$(printf '%s' "$h" | shasum 2>/dev/null | cut -c1-8)"
}

pull_machine_scoped() {   # $1 = companion file, $2 = hub destination, $3 = label
  local f="$1" h="$2" label="$3"
  [ -f "$f" ] || return 0
  if [ -f "$h" ]; then
    [ ! "$f" -ot "$h" ] || return 0
    _debanner "$f" | cmp -s - "$h" && return 0
  fi
  [ "$DRY" = "1" ] && { say "(dry-run) would restore this machine's $label"; return 0; }
  # Routed through the SAME funnel as everything else — its private write path is exactly what let
  # round 4 walk out of the hub through a symlinked ancestor. (R4 NEW-S.)
  # Containment applies HERE TOO. Resolving this leg's own root with no containment requirement is
  # how it still wrote outside the hub after the refactor: the lanes were green and a hand-probe
  # found it. A destination under $FH must resolve inside $FH; the memory dir legitimately lives
  # outside, so it carries only the below-root walk. (R4 NEW-S, second half — caught by probe.)
  local _r _parent; _parent="$(dirname "$h")"
  case "$h" in
    "$FH"/*) _r="$(_resolve_root "$_parent" "$FH")" || { warn "machine-scoped $label resolves outside the hub — refusing"; ERRORS=$((ERRORS+1)); return 0; } ;;
    *)       _r="$(_resolve_root "$_parent" "")"    || { warn "machine-scoped $label cannot be resolved — refusing"; ERRORS=$((ERRORS+1)); return 0; } ;;
  esac
  _install_file "$f" "$h" "machine-scoped" "$label" "$_r" "$(basename "$h")" \
    || { ERRORS=$((ERRORS+1)); return 0; }
  N_MACHINE=$((N_MACHINE+1))
  say "restored this machine's $label from the companion store"
}

resolve_mem_dir() {   # the first-loop half of sync-to-be.sh's resolution — its permissive second
                      # loop (accept a matching dir even with no memory/ inside) is deliberately
                      # omitted: the reverse path must not invent a memory dir that does not exist.
  local root="$1" projects="$HOME/.claude/projects" tail d
  [ -d "$projects" ] || return 0
  tail="$(basename "$(dirname "$root")")-$(basename "$root")"
  for d in "$projects"/*"$tail"/; do [ -d "${d}memory" ] && { printf '%s' "${d}memory"; return 0; }; done
  return 0
}
MEM="$(resolve_mem_dir "$FH")"

[ "$DO_GIT" = "1" ] && git_ff

# Pair list — the inverse of sync-to-be.sh's for every SHARED area. Three outward legs are
# deliberately one-way and are named here rather than left to look like omissions (the earlier
# "exact inverse" wording promised more than the code delivers — cross-family MED #8):
#   CLAUDE.local.md                : this machine's own local binding; pulling a peer's would
#                                    silently repoint this machine's operator config.
#   edit_manifest.yaml, MEMORY.md  : machine-scoped by content. They DO get a return leg, but a
#                                    same-machine one only — see pull_machine_scoped() below.
# Keep the shared pairs in step: an outward pair with no return leg is the gap this script closes.
pull_dir "$BE/$TM"    "$FH/tracks/_meta"     "tracks/_meta"
pull_dir "$BE/$TA"   "$FH/tracks/_audit"    "tracks/_audit"
pull_dir "$BE/$TCH" "$FH/tracks/_chamber"  "tracks/_chamber"
pull_dir "$BE/$TR/the_bible" "$FH/tracks/the_bible" "tracks/the_bible"
EXTRA_LIST="${FH_BE_TRACKS_FILE:-$FH/.fh-be-tracks.local}"
if [ -f "$EXTRA_LIST" ]; then
  while IFS= read -r _t || [ -n "$_t" ]; do
    _t="${_t%%#*}"; _t="$(printf '%s' "$_t" | tr -d '[:space:]')"
    [ -n "$_t" ] || continue
    case "$_t" in */*|.|..|..*) continue;; esac
    pull_dir "$BE/$TR/$_t" "$FH/tracks/$_t" "tracks/$_t"
  done < "$EXTRA_LIST"
fi
[ -n "$MEM" ] && pull_dir "$BE/$MMD" "$MEM" "memory"

# Machine-scoped, same-machine only (see pull_machine_scoped above). Namespaced under $TM/$MMD too
# (not just $MID) — $MID alone is machine-scoped, not hub-scoped, so FH and a sibling hub sharing a
# machine would otherwise round-trip each other's manifest/memory-index through the identical
# filename (pmh-dev#68 PR #368 review — the sharpest form of the read-side gap this fix closes).
# NO "unknown" fallback. machine_id() returns non-zero for a malformed FH_MACHINE_ID; substituting a
# placeholder here re-enabled the exact import the rejection had just announced it was skipping — a
# warning followed by the forbidden action is worse than either alone. (R3 regression of R2 #8.)
MID="$(machine_id)" || MID=""
if [ -n "$MID" ]; then
  pull_machine_scoped "$BE/$TM/manifests/$MID.yaml" "$FH/tracks/_meta/edit_manifest.yaml" "edit_manifest.yaml"
  [ -n "$MEM" ] && pull_machine_scoped "$BE/$MMD/_index/$MID.md" "$MEM/MEMORY.md" "MEMORY.md"
  pull_machine_scoped "$BE/$TM/substrate/$MID" "$FH/tracks/_meta/.substrate_versions" ".substrate_versions"
fi

# ── Report ───────────────────────────────────────────────────────────────────
TOTAL=$((N_CLEAN + N_REVIEW))
WROTE=$((TOTAL + N_CREATED + N_MACHINE))     # everything that actually touched the hub
PFX=""; [ "$DRY" = "1" ] && PFX="(dry-run) "
# Creation is an OUTCOME: announced before any suppression logic can reach it, and independently of
# the held-count notice. Folding it in let a --quiet hook write files and print nothing.
[ "$N_CREATED" -gt 0 ] && say "${PFX}created $N_CREATED new file(s) in the hub (--include-new)"
if [ "$N_SKIP_DIR" -gt 0 ]; then
  say "ℹ️  $N_SKIP_DIR area(s) have no hub directory — not created (use --include-new to create them):"
  printf '%s' "$SKIP_DIR_LIST"
fi
if [ "$ERRORS" -gt 0 ] && [ "$WROTE" -eq 0 ]; then
  # Never print the all-clear line on a run that transferred nothing BECAUSE it failed. A count of
  # zero has two causes — "nothing to do" and "everything errored" — and reporting them with the
  # same sentence is exactly how a failure gets read as a healthy run.
  warn "nothing was transferred — every candidate errored (see above)"
elif [ "$TOTAL" -eq 0 ] && [ "$N_NEW" -eq 0 ]; then
  log "hub is current with the companion store — nothing to pull"
else
  [ "$TOTAL" -gt 0 ] && say "${PFX}pulled $TOTAL file(s) companion → hub  (clean $N_CLEAN · review $N_REVIEW)"
  if [ "$N_REVIEW" -gt 0 ]; then
    say "⚠️  these had local-only lines — applied, but LOOK (originals in ${RESTORE_ROOT#$FH/}/):"
    printf '%s' "$REVIEW_LIST"
  fi
  if [ "$N_NEW" -gt 0 ]; then
    if [ "$N_SKIP_NEW" -gt 0 ]; then
      # Under --quiet (the SessionStart hook), announce the held set only when the COUNT CHANGES.
      # A standing pending-decision printed identically every session stops being read — the
      # operator learns to skip the line, and the one session where the number jumps looks like
      # every other session. A nag that trains blindness is worse than no nag. Interactive runs
      # (no --quiet) always print it: there the operator asked.
      _held_stamp="$FH/tracks/_meta/.sync_from_be_held.marker"   # *.marker = excluded from forward sync
      _prev="$(cat "$_held_stamp" 2>/dev/null || echo -1)"
      case "$_prev" in ''|*[!0-9-]*) _prev=-1 ;; esac
      [ "$DRY" = "0" ] && [ "$META_SAFE" = "1" ] && printf '%s' "$N_SKIP_NEW" > "$_held_stamp" 2>/dev/null
      if [ "$QUIET" = "1" ] && [ "$N_SKIP_NEW" = "$_prev" ]; then
        : # unchanged pending decision, hook context — stay quiet
      else
      say "ℹ️  $N_SKIP_NEW file(s) exist in the companion but not here — NOT created (residency decision)."
      say "    Review them, then apply with: sync-from-be.sh --include-new"
        [ "$QUIET" = "1" ] || printf '%s' "$NEW_LIST" | head -20
        [ "$N_SKIP_NEW" -gt 20 ] && log "    … and $((N_SKIP_NEW - 20)) more"
      fi
    fi
  fi
  [ "$TOTAL" -gt 0 ] && [ "$DRY" = "0" ] && log "backups: ${RESTORE_ROOT#$FH/}/"
fi

if [ "$ERRORS" -gt 0 ]; then
  # Say what is TRUE of every error path, not what is true of the convenient one. Each failure above
  # either refused before writing (backup failure) or wrote via temp+rename (so the destination kept
  # its original bytes) or skipped a symlink/enumeration — in all of them the hub file was not left
  # half-written. The earlier wording claimed "left untouched" for a path that used `>` and could
  # truncate; the claim and the code have been made to agree rather than the claim restated.
  warn "$ERRORS item(s) FAILED (enumeration, backup, symlink, or write). Each is named above; none"
  warn "  was left partially written — writes go through a temp file and an atomic rename."
  exit 10
fi
exit 0
