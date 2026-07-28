#!/usr/bin/env bash
# sync-to-be.sh — hub local (gitignored) → private companion store.
# Mirrors the irreplaceable private half so that: public repo + companion = one complete project.
#   tracks/_meta    → <companion>/tracks-meta   (session meta, signals, manifests)
#   tracks/_audit   → <companion>/tracks-audit  (sister-asset cross-audit records)
#   tracks/the_bible → <companion>/tracks/the_bible (mapped project — nested; projects nest, only hub-meta _meta/_audit flatten)
#   memory/         → <companion>/memory        (durable CC memory — else lost on machine reclaim)
#   CLAUDE.local.md → <companion>/hub-owner     (operator-specific wiring)
# Runs from a CC Stop hook (throttled) or manually.
# Override paths via env: HUB_DIR, BE_DIR.
# Usage: bash scripts/sync-to-be.sh [--quiet]
#
# ── WHO TURNS THIS ON, AND ITS SIBLING ────────────────────────────────────────
# This script is one of TWO one-way mirror modes. They differ by AUDIENCE, not mechanism, and
# naming them that way is the point — a reader should be able to tell in one line whether it is
# theirs:
#
#   sync-to-be   (this file) — for someone keeping a PERSONAL research wiki in separate storage.
#                Direction: hub (canonical) → private companion store. Nothing here is shared;
#                the store exists so the public repo + the private half together form one whole
#                project, and so a machine reclaim does not take the private half with it.
#
#   sync-to-org  (sibling, per-org) — for someone syncing an ORGANIZATION-SHARED wiki.
#                Direction: personal canonical → the shared surface the org reads. Same transport,
#                different blast radius: a bad write is visible to other people, so the org mode
#                additionally owes residency review of what crosses (format may cross; private
#                notes and personal directory layout may not).
#
# **Both modes inherit the destination-newer guard below.** That guard is not personal-mode
# housekeeping — it is the floor for one-way mirroring as such, and the org mode needs it MORE:
# in personal mode a silent overwrite loses your own note, in org mode it can lose someone
# else's. Any new mirror mode starts by inheriting it, not by re-deciding it.
#
# Choosing: personal store → this file. Org-shared surface → the org variant, and run a residency
# pass on the crossing set first. Both → run both; they have different destinations and the guard
# keeps them from fighting.

set -euo pipefail

FH="${HUB_DIR:-${CLAUDE_PROJECT_DIR:-$HOME/projects/forge-harness}}"
BE="${BE_DIR:-$FH/../fh-be}"          # companion = documented sibling of the hub (derive with $FH, not a pinned literal)
QUIET="${1:-}"

# Hub-identity guard (fail-closed): $FH is context-derived (CLAUDE_PROJECT_DIR), and this is the
# WRITE/push path. Refuse to mirror if $FH is not actually the FH hub — e.g. the Stop hook is
# registered globally, or CLAUDE_PROJECT_DIR points at a field project — else a wrong project's
# memory / CLAUDE.local.md would be pushed into the companion store. (Axis-2 challenger 2026-07-05 [B].)
head -1 "$FH/CLAUDE.md" 2>/dev/null | grep -q "forge-harness — Persistent Knowledge Hub" \
  || { echo "[sync-to-be] refuse: \$FH ($FH) is not the FH hub — abort" >&2; exit 0; }

# CC stores per-project memory under ~/.claude/projects/<encoded-abs-path>/memory.
# The encoding maps path separators (/ \ :) → '-', so it differs per OS, and git-bash's
# posix path ($HOME=/c/...) does NOT match CC's native-path encoding on Windows (C:\… →
# C--…). The dir therefore CANNOT be computed by sed-ing $FH — resolve it by globbing the
# encoded tail (parent + project folder), which is identical on macOS and Windows.
# (fh_signal 2026-06-19: Windows mis-encoded memory dir → Stop-hook never mirrored memory.)
HAVE_RSYNC=0; command -v rsync >/dev/null 2>&1 && HAVE_RSYNC=1
resolve_mem_dir() {
  local root="$1" projects="$HOME/.claude/projects" tail d
  [ -d "$projects" ] || return 0
  tail="$(basename "$(dirname "$root")")-$(basename "$root")"   # e.g. projects-forge-harness
  for d in "$projects"/*"$tail"/; do [ -d "${d}memory" ] && { printf '%s' "${d}memory"; return 0; }; done
  for d in "$projects"/*"$tail"/; do [ -d "$d" ] && { printf '%s' "${d}memory"; return 0; }; done
  return 0
}
MEM="$(resolve_mem_dir "$FH")"

log() { [ "$QUIET" = "--quiet" ] || echo "[sync-to-be] $*"; }

TOTAL=0   # files synced (rsync mode, countable)
DIRTY=0   # cp-fallback mode can't count cheaply → mark work done, let git-diff gate decide

# sync_dir SRC DST — append-only rsync (no --delete); skips silently if SRC missing.
# ── Destination-newer guard (fail-closed) ─────────────────────────────────────
# This transport is ONE-WAY: FH is canonical, the companion store is the mirror. rsync does not
# ask whether the destination is newer — it just overwrites. That is a SILENT data-loss path, and
# it fired twice: 2026-07-26, two consecutive sessions wrote a session card directly into the
# companion store (the session-start rule says "pull the companion store and read INDEX first",
# so the store is where an agent naturally starts reading — and therefore where it writes). The
# next sync replaced card v9 (7,567 B) with the older FH v8 (5,299 B); v10 went the same way.
# Neither loss was caught by a checker: the close-check reported "card-last violated", which is a
# TIMESTAMP-ORDER complaint, not an overwrite complaint — it was measuring an adjacent symptom.
# Discovery was accidental (someone noticed a byte count matching the old version).
#
# So: before overwriting, if the destination file is NEWER than its source, ABORT. Loss is
# irreversible; an unclear case stops rather than proceeds (§Irreversibility Surface-Class
# Degrade Invariant). Override channel matches the existing gates' shape: SYNC_OVERWRITE_OK=1,
# explicit and logged.
# SINGLE SOURCE for what this transport copies. The guard below and the rsync/tar calls MUST use
# the same set: a guard that inspects files the sync never writes produces false aborts, and one
# that misses files the sync does write produces false passes. (Measured on the first calibration
# run of this very guard: `logs/` is excluded from the copy but was being scanned, so a normal
# sync aborted on two launchd log files the transport never touches. Same divergence class the
# gate pathspec hit earlier the same day — two lists describing one thing.)
SYNC_EXCLUDES=('.gitkeep' '*.marker' 'logs/')

NEWER_HITS=""

# mtime-newer is the CHEAP screen, not the verdict. Measured 2026-07-28 (n=2 files, one run):
# after a successful sync this script COMMITS the companion store and, when another machine has
# pushed, REBASES it — and a rebase re-checks-out the working tree, stamping every touched file
# with `now`. The next run then aborted on two files whose content was byte-identical to their
# source. That is the same "guard fires on this script's own output" trap the banner logic warns
# about at line ~125, arriving by a different door (git, not the decorator), so the mtime restore
# there does not cover it.
#
# Why content is the right discriminator: the loss this guard prevents is "the mirror holds
# something the hub does not". If the bytes match, an overwrite transfers nothing and CANNOT lose
# anything — so skipping the abort is not a relaxation of the guard, it is the guard's own
# definition applied precisely. A real mirror edit still differs in content and still aborts
# (verified: the 2026-07-28 session card, where the mirror was a strict superset, still trips it).
#
# This matters beyond noise: an abort that fires on every healthy run trains `SYNC_OVERWRITE_OK=1`
# into muscle memory, and a reflex-overridden guard is a decoration on an irreversible surface.
_dest_content_differs() {   # $1 = src file, $2 = dst file  → 0 if they differ (real hit)
  local s="$1" d="$2"
  # A mirrored .md carries the injected banner on line 1; compare like-for-like by dropping it.
  if head -1 "$d" 2>/dev/null | grep -q 'MIRROR COPY'; then
    ! tail -n +2 "$d" 2>/dev/null | cmp -s - "$s"
  else
    ! cmp -s "$d" "$s"
  fi
}

check_dest_newer() {   # $1 = src dir, $2 = dst dir
  local src="$1" dst="$2" rel s d
  [ -d "$dst" ] || return 0
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    rel="${s#$src/}"
    d="$dst/$rel"
    [ -f "$d" ] || continue
    # newer destination AND divergent content = someone edited the mirror directly
    if [ "$d" -nt "$s" ] && _dest_content_differs "$s" "$d"; then
      NEWER_HITS="$NEWER_HITS  $d  (newer than $s)
"
    fi
    # shellcheck disable=SC2086
    # NOTE: these three predicates ARE SYNC_EXCLUDES, spelled as find syntax. They cannot be
    # array-expanded safely here, so they are duplicated — the one place this file tolerates it.
    # Changing SYNC_EXCLUDES without changing this line reopens the false-abort/false-pass gap;
    # scripts/sync_guard_check.sh asserts the two stay equivalent.
  done < <(find "$src" -type f ! -name '.gitkeep' ! -name '*.marker' ! -path '*/logs/*' 2>/dev/null)
}

# ── Mirror banner (salience layer over the guard above) ───────────────────────
# The guard stops the loss; this stops the *edit* that causes it. A directory-level README is too
# weak — an agent opens a FILE, and nothing in the content says "this is a copy". So the banner
# goes on line 1 of every mirrored markdown file, inserted mechanically at sync time (a
# hand-maintained banner drifts).
#
# ⚠️ Interaction trap, found while writing this: injecting the banner updates the destination's
# mtime, which would make the destination newer than its source — and the guard above would then
# abort on this script's OWN output, every run after the first. So the mtime is restored from the
# source after injection. A guard and a decorator that fight each other are worse than neither.
BANNER='<!-- MIRROR COPY — synced from the forge-harness hub. Do NOT edit here; the next sync overwrites it. Edit the canonical file under the hub instead. -->'
stamp_banner() {   # $1 = dst dir, $2 = src dir (for mtime restore)
  local dst="$1" src="$2" f rel s
  [ -d "$dst" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    head -1 "$f" 2>/dev/null | grep -q 'MIRROR COPY' && continue
    rel="${f#$dst/}"; s="$src/$rel"
    { printf '%s\n' "$BANNER"; cat "$f"; } > "$f.tmp$$" && mv "$f.tmp$$" "$f"
    [ -f "$s" ] && touch -r "$s" "$f"   # keep the guard from firing on our own banner
  done < <(find "$dst" -type f -name '*.md' ! -path '*/logs/*' 2>/dev/null)
  # A `while` loop returns the status of the LAST command run in its body. The line above is a
  # bare test, so a final iteration whose source file no longer exists in the hub (a mirror file
  # with no hub counterpart — normal, not an error) made this function return 1. That leaked all
  # the way out as the SCRIPT's exit status, so a fully successful sync reported failure — and
  # because the Stop hook runs it as `sync-to-be.sh --quiet && echo $NOW > $FLAG`, the cooldown
  # stamp was never written and the sync re-ran on EVERY Stop, each time reporting a hook failure
  # with no stderr. Banner stamping is best-effort by design; say so explicitly. (2026-07-26)
  return 0
}

# The banner makes the mirror's content differ from its source, so rsync would re-transfer every
# banner-bearing file on EVERY run — measured on the first live run: 265 files reported "synced"
# with nothing actually changed. That is not a loss, but it destroys the log as an instrument
# (a real change becomes invisible inside the noise). Fix: strip before the compare, re-stamp
# after. Content then matches on both sides and rsync moves only genuine changes.
strip_banner() {   # $1 = dst dir
  local dst="$1" f
  [ -d "$dst" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    head -1 "$f" 2>/dev/null | grep -q 'MIRROR COPY' || continue
    # mtime must survive the strip: rsync's quick-check is size+mtime, so a strip that bumps
    # mtime to NOW makes every file look changed and the churn returns by another door.
    tail -n +2 "$f" > "$f.tmp$$" && touch -r "$f" "$f.tmp$$" && mv "$f.tmp$$" "$f"
  done < <(find "$dst" -type f -name '*.md' ! -path '*/logs/*' 2>/dev/null)
  return 0   # same status-leak shape as stamp_banner above — best-effort, never the script's verdict
}

sync_dir() {
  local src="$1" dst="$2"
  [ -d "$src" ] || { log "skip (no source): $src"; return 0; }
  mkdir -p "$dst"
  # Guard runs BEFORE this directory's rsync, so a directory holding a newer mirror file is never
  # written. Directories already synced above it had no newer-destination files by definition, so
  # an abort here leaves no partial loss — only a partial (lossless) mirror.
  NEWER_HITS=""
  check_dest_newer "$src" "$dst"
  if [ -n "$NEWER_HITS" ]; then
    if [ "${SYNC_OVERWRITE_OK:-0}" = "1" ]; then
      log "⚠️  destination-newer OVERRIDE (SYNC_OVERWRITE_OK=1) — overwriting:"
      printf '%s' "$NEWER_HITS" >&2
      printf '%s\tSYNC_OVERWRITE_OK\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$dst" \
        >> "$BE/tracks-meta/.sync_overwrite_override_log" 2>/dev/null || true
    else
      echo "" >&2
      echo "🚫 SYNC ABORTED — the destination is NEWER than the source:" >&2
      printf '%s' "$NEWER_HITS" >&2
      echo "" >&2
      echo "   This transport is ONE-WAY. The canonical copy is under forge-harness; the" >&2
      echo "   companion store is a mirror. A newer file there means it was edited in the" >&2
      echo "   MIRROR — continuing would overwrite it silently, and that loss is irreversible." >&2
      echo "" >&2
      echo "   Fix: move the edit back to the canonical path, then re-run." >&2
      echo "   Deliberate overwrite (the mirror copy is genuinely stale): SYNC_OVERWRITE_OK=1 $0" >&2
      echo "" >&2
      exit 1
    fi
  fi
  if [ "$HAVE_RSYNC" -eq 1 ]; then
    local out n
    # capture separately so a no-match grep (exit 1) under pipefail can't kill the script
    strip_banner "$dst"   # compare like-for-like; banner is re-stamped after the transfer
    local -a rex=(); local e
    for e in "${SYNC_EXCLUDES[@]}"; do rex+=("--exclude=$e"); done
    out=$(rsync -a --itemize-changes "$src/" "$dst/" "${rex[@]}") || true
    n=$(printf '%s\n' "$out" | grep -c '^[>c]' || true)
    TOTAL=$((TOTAL + n))
    [ "$n" -eq 0 ] || log "$n file(s) synced → $dst"
    stamp_banner "$dst" "$src"
  else
    # rsync absent (default Windows git-bash): tar-pipe mirror with the same excludes,
    # no --delete (append-only). Source is canonical, so overwriting be's copy is correct.
    if ( cd "$src" && tar cf - --exclude='.gitkeep' --exclude='*.marker' --exclude='logs' . ) \
         | ( cd "$dst" && tar xf - ); then
      DIRTY=1; log "mirrored (cp mode) → $dst"; stamp_banner "$dst" "$src"
    else
      log "mirror failed (cp mode) → $dst"
    fi
  fi
}

# sync_file SRC DSTDIR — append-only rsync of a single file; skips silently if SRC missing.
sync_file() {
  local src="$1" dstdir="$2"
  [ -f "$src" ] || { log "skip (no file): $src"; return 0; }
  mkdir -p "$dstdir"
  # Same destination-newer guard as sync_dir. Added in the same pass, because the first cut
  # guarded only sync_dir and left this path open — and this path carries CLAUDE.local.md, the
  # operator's local bindings. A guard applied to some callers of a shared hazard is not a guard;
  # it just relocates the hole. (Half-fix / propagation-boundary class.)
  # Content check applies here for the same reason (see _dest_content_differs above): a rebase-
  # stamped mtime on a byte-identical file is not an edit, and half a fix is the class this
  # very comment block was written about.
  local dstf="$dstdir/$(basename "$src")"
  if [ -f "$dstf" ] && [ "$dstf" -nt "$src" ] && _dest_content_differs "$src" "$dstf"; then
    if [ "${SYNC_OVERWRITE_OK:-0}" = "1" ]; then
      log "⚠️  destination-newer OVERRIDE (SYNC_OVERWRITE_OK=1) — overwriting $dstf"
      printf '%s\tSYNC_OVERWRITE_OK\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$dstf" \
        >> "$BE/tracks-meta/.sync_overwrite_override_log" 2>/dev/null || true
    else
      echo "" >&2
      echo "🚫 SYNC ABORTED — the destination is NEWER than the source:" >&2
      echo "  $dstf  (newer than $src)" >&2
      echo "   One-way transport: the hub copy is canonical. Move the edit back, then re-run." >&2
      echo "   Deliberate overwrite: SYNC_OVERWRITE_OK=1 $0" >&2
      echo "" >&2
      exit 1
    fi
  fi
  if [ "$HAVE_RSYNC" -eq 1 ]; then
    local out n
    out=$(rsync -a --itemize-changes "$src" "$dstdir/") || true
    n=$(printf '%s\n' "$out" | grep -c '^[>c]' || true)
    TOTAL=$((TOTAL + n))
    [ "$n" -eq 0 ] || log "synced $(basename "$src") → $dstdir"
  else
    if cp -p "$src" "$dstdir/"; then
      DIRTY=1; log "copied (cp mode) $(basename "$src") → $dstdir"
    else
      log "copy failed (cp mode) $(basename "$src") → $dstdir"
    fi
  fi
}

# ── Machine-scoped files ──────────────────────────────────────────────────────
# Most of what we mirror is machine-AGNOSTIC (signals, audits, memory topic files: every
# machine writes the same content, and append-only rsync merges them harmlessly). Two files
# are NOT: each hub clone keeps its OWN edit_manifest.yaml and its OWN memory index, because
# they describe THAT machine's local state. Mirroring them to one shared path makes every
# machine silently overwrite the others' backup — measured 2026-07-15: three machines synced
# the same day and fh-be's manifest ended up 135 entries (one machine) while another held 175,
# with no file actually lost but the backup rendered ambiguous. So these two are keyed by
# machine. The session CARD is deliberately NOT keyed — it is the shared cross-machine handoff
# ("next session = <machine>"); splitting it would kill the function it exists for.
#
# FH_MACHINE_ID: set it in your local env to name the machine. Default = a short digest of the
# hostname — stable, and non-identifying (a raw hostname commonly embeds the operator's name).
machine_id() {
  if [ -n "${FH_MACHINE_ID:-}" ]; then
    printf '%s' "$FH_MACHINE_ID" | tr -cd '[:alnum:]_-' | cut -c1-32; return 0
  fi
  local h
  h=$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'unknown')
  printf 'm%s' "$(printf '%s' "$h" | shasum 2>/dev/null | cut -c1-8)"
}
MID="$(machine_id)"
[ -n "$MID" ] || MID="unknown"

sync_dir  "$FH/tracks/_meta"      "$BE/tracks-meta"
# ...then re-home the two machine-scoped files out of the shared namespace.
if [ -f "$FH/tracks/_meta/edit_manifest.yaml" ]; then
  mkdir -p "$BE/tracks-meta/manifests"
  cp "$FH/tracks/_meta/edit_manifest.yaml" "$BE/tracks-meta/manifests/$MID.yaml" \
    && log "manifest → tracks-meta/manifests/$MID.yaml (machine-scoped)"
  rm -f "$BE/tracks-meta/edit_manifest.yaml"   # shared copy retired; history keeps every machine's
fi
sync_dir  "$FH/tracks/_audit"     "$BE/tracks-audit"
sync_dir  "$FH/tracks/_chamber"   "$BE/tracks-chamber"   # incubation chamber runs (INTENT/SIM_NOTES/verdict/INDEX ledger) — local-only (gitignored in public FH), made durable + cross-machine here
sync_dir  "$FH/tracks/the_bible"  "$BE/tracks/the_bible"    # mapped project — NESTED under tracks/ (like livedeck; projects nest, only hub-meta _meta/_audit flatten): local-only (untracked in public FH), watched in companion

# Extra local-only project tracks to mirror are listed in a LOCAL, gitignored file
# ($FH/.fh-be-tracks.local — one track dir-name per line, # comments allowed). This keeps
# non-public track NAMES (e.g. company assets) OUT of this committed script: the list owns
# "what to mirror", this script is pure transport. local tracks/<name> <-> be tracks/<name>.
EXTRA_LIST="${FH_BE_TRACKS_FILE:-$FH/.fh-be-tracks.local}"
if [ -f "$EXTRA_LIST" ]; then
  while IFS= read -r _t || [ -n "$_t" ]; do
    _t="${_t%%#*}"                                   # strip inline comment
    _t="$(printf '%s' "$_t" | tr -d '[:space:]')"    # trim all whitespace
    [ -n "$_t" ] || continue
    case "$_t" in */*|.|..|..*) log "skip (unsafe track name): $_t"; continue;; esac
    sync_dir "$FH/tracks/$_t" "$BE/tracks/$_t"
  done < "$EXTRA_LIST"
fi

sync_dir  "$MEM"               "$BE/memory"
# memory TOPIC files are machine-agnostic and merge fine (203/203 identical across machines,
# measured 2026-07-15). The INDEX is not: it lists only what THIS machine's memory dir holds,
# so a shared MEMORY.md is whichever machine synced last and can never cover the union.
if [ -f "$MEM/MEMORY.md" ]; then
  mkdir -p "$BE/memory/_index"
  cp "$MEM/MEMORY.md" "$BE/memory/_index/$MID.md" \
    && log "memory index → memory/_index/$MID.md (machine-scoped)"
  rm -f "$BE/memory/MEMORY.md"                 # shared copy retired; history keeps every machine's
fi
sync_file "$FH/CLAUDE.local.md" "$BE/hub-owner"

cd "$BE"

# Mirror-only mode: a plain (non-git) companion directory is a valid local-only
# setup — files are already mirrored above; just skip the commit/push half.
# Without this guard, set -e kills the script at `git add` with a noisy error
# on every Stop-hook run (fh_signal_2026-06-10: companion-store portability).
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  log "companion store is not a git repo — mirror-only mode ($([ "$HAVE_RSYNC" -eq 1 ] && echo "$TOTAL file(s) synced" || echo "cp-mode mirror done"), no commit/push)"
  exit 0
}

# Push any commits ahead of upstream. Offline-safe: never aborts the script,
# so a failed push just leaves commits queued for the next run to flush.
#
# Concurrent-writer safety: two environments (e.g. company laptop + external
# machine) can write this store the same day. Without integrating the remote
# first, the second pusher's push is rejected non-fast-forward and — because
# the old code logged that as "offline?" — the commits piled up silently and
# never landed until a manual pull. So: fetch, and if behind, rebase local
# sync commits onto the remote BEFORE pushing. fetch-first lets us tell a
# genuinely-offline run (fetch fails) from a behind-remote run (fetch ok).
#
# We rebase ONLY when the working tree is clean, and deliberately do NOT use
# --autostash: an autostash pop-conflict completes the rebase but leaves the
# tree conflict-markered with the stash orphaned, and `rebase --abort` is then
# a no-op that can't recover it (the next run's `git add` would commit the
# garbage). A dirty tree just means the caller hasn't finished committing —
# hold the push and let the next run reconcile, preserving the old safe
# non-destructive behavior. (Hardened after an adversarial Axis-2 pass, 2026-07-01.)
maybe_push() {
  git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 || {
    log "no upstream set for companion store — skipping push"; return 0; }
  # Clean up any rebase left half-done by a killed prior run (Stop hook can be
  # terminated mid-rebase); otherwise a later behind==0 run would push on an
  # inconsistent HEAD.
  rebase_in_progress() {
    [ -d "$(git rev-parse --git-path rebase-merge 2>/dev/null)" ] \
      || [ -d "$(git rev-parse --git-path rebase-apply 2>/dev/null)" ]; }
  if rebase_in_progress; then
    git rebase --abort 2>/dev/null || true
    if rebase_in_progress; then
      # abort couldn't clear it (corrupt/partial state) — do NOT push on an
      # inconsistent HEAD; bail fail-closed and let the operator resolve.
      log "an interrupted rebase could not be auto-aborted — resolve manually: cd \"$BE\" && git status"
      return 0
    fi
    log "cleaned up an interrupted rebase from a prior run"
  fi
  if git fetch --quiet 2>/dev/null; then
    local behind
    behind=$(git rev-list --count '..@{u}' 2>/dev/null || echo 0)
    if [ "$behind" -gt 0 ]; then
      if ! { git diff --quiet && git diff --cached --quiet; }; then
        log "$behind remote commit(s) + uncommitted changes — holding push, next run will reconcile"
        return 0
      fi
      if git pull --rebase --quiet 2>/dev/null; then
        log "rebased onto $behind remote commit(s) from another env before push"
      else
        git rebase --abort 2>/dev/null || true
        log "REBASE CONFLICT with remote (concurrent edit of a shared file) — resolve manually: cd \"$BE\" && git pull --rebase"
        return 0
      fi
    fi
  fi
  local ahead
  ahead=$(git rev-list --count '@{u}..' 2>/dev/null || echo 0)
  [ "$ahead" -gt 0 ] || return 0
  if git push --quiet 2>/dev/null; then
    log "companion store pushed ($ahead commit(s))"
  else
    log "push failed (offline?) — $ahead commit(s) held locally, will retry next run"
  fi
}

if [ "$TOTAL" -eq 0 ] && [ "$DIRTY" -eq 0 ]; then
  log "already up to date"
  maybe_push   # flush any commits a previous run couldn't push
  exit 0
fi

# Commit in the companion store
git add tracks-meta/ tracks-audit/ tracks/ memory/ hub-owner/ 2>/dev/null || git add -A
if git diff --cached --quiet; then
  log "nothing new to commit in companion store"
  maybe_push
  exit 0
fi

DATE=$(date +"%Y-%m-%d %H:%M")
MSG="sync: hub private half → companion store ($DATE)"
git commit -m "$MSG" --no-gpg-sign 2>/dev/null || git commit -m "$MSG"

log "companion store committed"
maybe_push
