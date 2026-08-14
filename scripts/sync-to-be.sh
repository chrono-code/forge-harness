#!/usr/bin/env bash
# sync-to-be.sh — hub local (gitignored) → private companion store.
# Mirrors the irreplaceable private half so that: public repo + companion = one complete project.
#   tracks/_meta    → <companion>/tracks-meta   (session meta, signals, manifests)
#   tracks/_audit   → <companion>/tracks-audit  (sister-asset cross-audit records)
#   tracks/the_bible → <companion>/tracks/the_bible (mapped project — nested; projects nest, only hub-meta _meta/_audit flatten)
#   memory/         → <companion>/memory        (durable CC memory — else lost on machine reclaim)
#   CLAUDE.local.md → <companion>/hub-owner     (operator-specific wiring)
# This script is shared verbatim with recognized sibling hubs (e.g. PMH) that mirror to the SAME
# companion store. A non-FH hub's destination dirs get a "-<tag>" suffix (tracks-meta-pmh/, etc.)
# so two hubs never collide on one shared path — see the HUB_SUFFIX guard below. A hub not on that
# list refuses (non-zero exit) rather than writing anywhere.
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
# WRITE/push path. Refuse to mirror if $FH is not a recognized hub — e.g. the Stop hook is
# registered globally, or CLAUDE_PROJECT_DIR points at a field project — else a wrong project's
# memory / CLAUDE.local.md would be pushed into the companion store. (Axis-2 challenger 2026-07-05 [B].)
# A refusal exits NON-ZERO — the earlier `exit 0` made a refusal indistinguishable from success to
# every caller (Stop hook, close-chain gate), so a rejected sync silently never ran (pmh-dev#68 ①).
# The code is 10, not 1: this branch now only fires for a hub that is genuinely neither FH nor PMH
# (both of THOSE proceed normally below), so it is the same "not applicable here" case
# sync-from-be.sh already gives its own dedicated code — reserving 1 for a recognized hub that
# errors mid-run (via this script's `set -e`). The distinction matters to the Stop hook specifically:
# it gates its cooldown stamp on this script's exit status (`sync-to-be.sh --quiet && echo $NOW >
# $FLAG`, .claude/settings.json), so an UNDIFFERENTIATED non-zero here — in any project that happens
# to carry this exact hook line but is neither hub — would never stamp the cooldown and re-run this
# guard on every single Stop, forever (Wave-1 review, pmh-dev#68). The hook is updated to treat 10
# the same as 0 for stamping purposes; a real failure (1, or any `set -e` exit) still doesn't stamp.
#
# HUB_SUFFIX namespaces this hub's destination paths under $BE. Two hubs sharing one companion
# store (FH + a sibling, siblings on the same machine, BE derived the same way from each) would
# otherwise both write "tracks-meta/" — the sibling's card would silently overwrite FH's card in the
# exact same file (pmh-dev#68 ②). FH keeps the unsuffixed legacy paths (canonical, oldest, most
# tooling depends on them); a recognized sibling hub gets its own "-<tag>" namespace. A hub this
# script cannot identify refuses rather than guessing a namespace for it.
#
# A sibling hub's identifying text (its CLAUDE.md first line) is NOT hardcoded here — this script
# ships in the PUBLIC forge-harness repo, and a sibling hub's name/header is an operator-private
# token in that context (confirmed: the confidentiality gate blocked the first draft of this fix,
# which hardcoded one directly — `git grep` showed zero prior occurrences anywhere in this repo's
# history, i.e. a genuinely new leak, not an already-accepted one). Sibling identity instead comes
# from a LOCAL, gitignored (`.git/info/exclude`, same convention as `.fh-be-tracks.local` just below)
# config file — `key=value` lines, read as DATA (not sourced as shell, to avoid handing arbitrary
# code execution to a config file): HUB_HEADER_MATCH (a prefix of the sibling's CLAUDE.md first
# line), HUB_SUFFIX, HUB_NAME. Each operator who runs a sibling hub sets this once, locally; the
# public script never learns or ships that hub's name.
HUB1="$(head -1 "$FH/CLAUDE.md" 2>/dev/null)"
case "$HUB1" in
  "# forge-harness — Persistent Knowledge Hub"*) HUB_SUFFIX=""; HUB_NAME="forge-harness" ;;
  *)
    HUB_IDFILE="${FH_HUB_IDENTITY_FILE:-$FH/.fh-hub-identity.local}"
    # Always exits 0 — under `set -eo pipefail`, a bare `var="$(fn)"` assignment aborts the whole
    # script if `fn`'s pipeline exits nonzero, and both "no local identity file" AND "file exists but
    # key absent" (grep finds 0 matches → pipefail propagates grep's 1) must fall through to the
    # ordinary refuse-with-exit-10 path below, not crash here with an unrelated exit code (caught in
    # testing: the no-file case exited 1 before this fix, never reaching the intended message — the
    # `|| true` on the pipeline itself is required, a trailing `return 0` on its own line is NOT
    # enough, since `set -e` aborts on the failing pipeline before that line is ever reached).
    _hub_id_get() {
      [ -f "$HUB_IDFILE" ] || return 0
      grep "^$1=" "$HUB_IDFILE" 2>/dev/null | head -1 | cut -d= -f2- || true
    }
    HUB_MATCH="$(_hub_id_get HUB_HEADER_MATCH)"
    if [ -n "$HUB_MATCH" ] && [ "${HUB1#"$HUB_MATCH"}" != "$HUB1" ]; then
      HUB_SUFFIX="$(_hub_id_get HUB_SUFFIX)"
      HUB_NAME="$(_hub_id_get HUB_NAME)"
    fi
    if [ -z "${HUB_SUFFIX:-}" ] || [ -z "${HUB_NAME:-}" ]; then
      # 10 means "not my hub" ONLY, here and in sync-from-be.sh's own use of the same code — never
      # repurpose it for a genuine mid-run failure elsewhere in this script. The Stop hook (below)
      # stamps its cooldown on 0 OR 10; reusing 10 for a real error would make that hook treat the
      # failure as a quiet success (Wave-2 review, [B]).
      echo "[sync-to-be] refuse: \$FH ($FH) is not a recognized hub — abort" >&2
      exit 10
    fi
    ;;
esac
TM="tracks-meta$HUB_SUFFIX"; TA="tracks-audit$HUB_SUFFIX"; TCH="tracks-chamber$HUB_SUFFIX"
TR="tracks$HUB_SUFFIX"; MMD="memory$HUB_SUFFIX"; HO="hub-owner$HUB_SUFFIX"

# Cross-hub mutual exclusion (Wave-1 review, pmh-dev#68 [S]; lock ordering hardened by codex
# cross-family review [A]). Before HUB_SUFFIX, a non-FH hub always refused above and never reached
# any of this, so $BE only ever had ONE writer (this hub's own Stop hook, throttled to one run per
# 300s). Now FH and PMH can both be inside it at once — un-serialized, that lets one hub's `git
# rebase --abort` (in maybe_push, below) tear down the OTHER hub's live `git pull --rebase`, or let
# one hub's add/commit land mid-write of the other's. The lock is acquired HERE — before the mirror
# phase below ever touches $BE — not later next to the git operations: git add/commit only stage
# what THIS run explicitly adds, so a same-namespace collision there was already narrow, but the
# mirror phase (`sync_dir`/`sync_file`, all rsync/tar/cp) writes files on disk with no such
# scoping, and codex's review is right that letting it run lock-free just moves the race earlier
# instead of closing it — a busy-lock timeout used to return 0 *after* dirtying the shared tree.
# `flock` would be the obvious tool but ships on neither stock macOS (this operator's platform) nor
# BSD — `mkdir` is atomic on every POSIX filesystem and needs no external binary. Shared (unsuffixed)
# lock path: both hubs must serialize against EACH OTHER, not just themselves.
mkdir -p "$BE"
LOCKDIR="$BE/.sync.lock.d"
LOCK_WAIT=0
while ! mkdir "$LOCKDIR" 2>/dev/null; do
  # A lock older than 120s did not come from a live run of this script (it finishes in seconds under
  # normal conditions) — it is a killed process's leftover. Reclaim rather than wait forever.
  if [ -d "$LOCKDIR" ]; then
    # `date -r` failing (non-BSD date, or the dir vanishing between the -d test and this call) must
    # NOT read as "epoch 0" — that would make age ~55 years and every lock look stale, disarming the
    # lock entirely on the very run this staleness check exists to protect (Wave-2 review, [A], and
    # independently corroborated by codex's cross-family review: "not found ≠ 0"). Unreadable mtime
    # → assume NOW (freshest possible reading; worst case is one extra wait cycle, never a false steal).
    lock_age=$(( $(date +%s) - $(date -r "$LOCKDIR" +%s 2>/dev/null || date +%s) ))
    if [ "$lock_age" -gt 120 ]; then
      # `rmdir` here (plain, unconditional) is the exact bug this line replaces: two processes can
      # BOTH read the same lock as stale and BOTH `rmdir` + loop back to `mkdir` — the second one to
      # arrive removes the FIRST one's brand-new, live lock, and mutual exclusion is broken by the
      # code that exists to protect it (Wave-2 review, [S]). `mv` on a shared source is atomic: only
      # one racer's rename can succeed (the source is gone for everyone else the instant it wins), so
      # exactly one process reclaims and the rest fall through to a normal (now-fresh) staleness read.
      if mv "$LOCKDIR" "$LOCKDIR.stale.$$" 2>/dev/null; then
        rmdir "$LOCKDIR.stale.$$" 2>/dev/null || true
        log "reclaimed a stale sync lock (${lock_age}s old — a prior run's leftover)"
      fi
      continue
    fi
  fi
  LOCK_WAIT=$((LOCK_WAIT + 1))
  [ "$LOCK_WAIT" -le 15 ] || { log "companion store busy (another hub is syncing) — next run will retry"; exit 0; }
  sleep 1
done
# EXIT alone does not fire on an uncaught SIGTERM/HUP (bash kills the process outright) — and this
# script IS killed mid-run by its own Stop-hook throttle window on occasion (see maybe_push's rebase
# cleanup below, which exists for exactly that). Catch the common terminating signals too so a killed
# run's lock still gets released instead of waiting out the 120s reclaim (Wave-2 review, [B]).
trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT INT TERM HUP

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
# `.fh_node_state` 는 **기계 고유** 상태다(노드 id·마지막 세션 시각·그 노드가 본 HEAD).
# 컴패니언 스토어로 흘려보내면 노드마다 값이 엇갈려, 역방향 sync 가 생기는 순간 NODE_ID 가
# 번갈아 뒤집히며 모든 세션에서 재점검 배너가 뜬다(cross-family 리뷰 2026-07-30, 전방 투기적).
SYNC_EXCLUDES=('.gitkeep' '*.marker' 'logs/' '.fh_node_state')

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
  done < <(find "$src" -type f ! -name '.gitkeep' ! -name '*.marker' ! -name '.fh_node_state' ! -path '*/logs/*' 2>/dev/null)
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
BANNER="<!-- MIRROR COPY — synced from the $HUB_NAME hub. Do NOT edit here; the next sync overwrites it. Edit the canonical file under the hub instead. -->"
stamp_banner() {   # $1 = dst dir, $2 = src dir (for mtime restore)
  local dst="$1" src="$2" f rel s tmp skipped=0
  [ -d "$dst" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # $f can vanish between the find snapshot above and here — e.g. a machine-scoped file this
    # same run retires right after mirroring it (memory/MEMORY.md, tracks-meta/edit_manifest.yaml),
    # or a second concurrent run of this script. Skip rather than let `cat` fail into a tmp file
    # nothing ever cleans up (pmh-dev#68 ③ — 4 such orphans found committed in the companion store).
    [ -f "$f" ] || { skipped=$((skipped + 1)); continue; }
    head -1 "$f" 2>/dev/null | grep -q 'MIRROR COPY' && continue
    rel="${f#$dst/}"; s="$src/$rel"
    tmp="$f.tmp$$"
    if { printf '%s\n' "$BANNER"; cat "$f"; } > "$tmp" 2>/dev/null && mv "$tmp" "$f" 2>/dev/null; then
      [ -f "$s" ] && touch -r "$s" "$f"   # keep the guard from firing on our own banner
    else
      rm -f "$tmp"   # never leave a partial banner-stamp behind for `git add` to pick up
      skipped=$((skipped + 1))
    fi
  done < <(find "$dst" -type f -name '*.md' ! -path '*/logs/*' 2>/dev/null)
  # A silent skip hides a real failure (permission, ENOSPC) behind the benign TOCTOU case above —
  # both look identical from outside. Not fatal (banner stamping is best-effort by design, see
  # below), but must be visible rather than absorbed. (pmh-dev#68 Wave-1 review)
  [ "$skipped" -eq 0 ] || log "banner: $skipped file(s) unstamped in $dst (vanished mid-run or write failed)"
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
    [ -f "$f" ] || continue   # vanished since the find snapshot — see stamp_banner's note above
    head -1 "$f" 2>/dev/null | grep -q 'MIRROR COPY' || continue
    # mtime must survive the strip: rsync's quick-check is size+mtime, so a strip that bumps
    # mtime to NOW makes every file look changed and the churn returns by another door.
    if tail -n +2 "$f" > "$f.tmp$$" 2>/dev/null && touch -r "$f" "$f.tmp$$"; then
      mv "$f.tmp$$" "$f"
    else
      rm -f "$f.tmp$$"
    fi
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
        >> "$BE/$TM/.sync_overwrite_override_log" 2>/dev/null || true
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
    if ( cd "$src" && tar cf - --exclude='.gitkeep' --exclude='*.marker' --exclude='.fh_node_state' --exclude='logs' . ) \
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
        >> "$BE/$TM/.sync_overwrite_override_log" 2>/dev/null || true
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

sync_dir  "$FH/tracks/_meta"      "$BE/$TM"
# ...then re-home the two machine-scoped files out of the shared namespace.
if [ -f "$FH/tracks/_meta/edit_manifest.yaml" ]; then
  mkdir -p "$BE/$TM/manifests"
  cp "$FH/tracks/_meta/edit_manifest.yaml" "$BE/$TM/manifests/$MID.yaml" \
    && log "manifest → $TM/manifests/$MID.yaml (machine-scoped)"
  rm -f "$BE/$TM/edit_manifest.yaml"   # shared copy retired; history keeps every machine's
fi
sync_dir  "$FH/tracks/_audit"     "$BE/$TA"
sync_dir  "$FH/tracks/_chamber"   "$BE/$TCH"   # incubation chamber runs (INTENT/SIM_NOTES/verdict/INDEX ledger) — local-only (gitignored in public FH), made durable + cross-machine here
sync_dir  "$FH/tracks/the_bible"  "$BE/$TR/the_bible"    # mapped project — NESTED under tracks/ (like livedeck; projects nest, only hub-meta _meta/_audit flatten): local-only (untracked in public FH), watched in companion

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
    sync_dir "$FH/tracks/$_t" "$BE/$TR/$_t"
  done < "$EXTRA_LIST"
fi

sync_dir  "$MEM"               "$BE/$MMD"
# memory TOPIC files are machine-agnostic and merge fine (203/203 identical across machines,
# measured 2026-07-15). The INDEX is not: it lists only what THIS machine's memory dir holds,
# so a shared MEMORY.md is whichever machine synced last and can never cover the union.
# (This retirement is deliberate design, not a bug — pmh-dev#68 ④ raised it as an unexplained
# deletion; it is not one. Added 2026-07-15, commit 2ecc45d2.)
if [ -f "$MEM/MEMORY.md" ]; then
  mkdir -p "$BE/$MMD/_index"
  cp "$MEM/MEMORY.md" "$BE/$MMD/_index/$MID.md" \
    && log "memory index → $MMD/_index/$MID.md (machine-scoped)"
  rm -f "$BE/$MMD/MEMORY.md"                 # shared copy retired; history keeps every machine's
fi
sync_file "$FH/CLAUDE.local.md" "$BE/$HO"

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
# mkdir -p every namespace dir first: sync_dir() only creates $dst once its $src exists (line ~200
# above), so a dir this hub never populated (PMH's first run typically has no tracks/_chamber or
# tracks/the_bible) is simply absent here. `git add` on a pathspec that matches nothing at all is a
# hard error under `set -e` — the OLD `|| git add -A` fallback existed to survive exactly that, but
# now that two hubs can share this worktree (the lock above), `git add -A` staging EVERYTHING
# includes the OTHER hub's mid-sync files (Wave-1 review, pmh-dev#68 [A]). mkdir -p removes the actual
# cause instead: `git add` on an existing-but-empty dir is a normal no-op, so the fallback is dropped.
mkdir -p "$TM" "$TA" "$TCH" "$TR" "$MMD" "$HO"
# Sweep any *.md.tmp<pid> banner-stamp leftovers before staging — belt-and-suspenders for the TOCTOU
# case above (already made non-orphaning) AND for a hard kill mid-write (SIGKILL between the write
# and the mv, which no in-process guard can catch). `git add dir/` stages everything under dir/
# regardless of extension, which is exactly how the 4 orphans pmh-dev#68 found got committed.
# The glob is anchored to `*.md.tmp[0-9]*`, NOT the broader `*.tmp[0-9]*` — $TR mirrors arbitrary
# mapped-project content (the_bible, anything in .fh-be-tracks.local), and a project file that
# genuinely happens to be named e.g. `notes.tmp2_draft.md` would match the broader glob and get
# silently deleted every single sync, forever, with no trace (Wave-2 review, [A]). stamp_banner and
# strip_banner only ever create `<file>.md.tmp$$` (both operate on `find … -name '*.md'` results), so
# the narrower anchor still catches every real orphan and nothing else.
find "$TM" "$TA" "$TCH" "$TR" "$MMD" "$HO" -name '*.md.tmp[0-9]*' -delete 2>/dev/null || true
git add "$TM/" "$TA/" "$TCH/" "$TR/" "$MMD/" "$HO/"
if git diff --cached --quiet; then
  log "nothing new to commit in companion store"
  maybe_push
  exit 0
fi

DATE=$(date +"%Y-%m-%d %H:%M")
MSG="sync: $HUB_NAME private half → companion store ($DATE)"
git commit -m "$MSG" --no-gpg-sign 2>/dev/null || git commit -m "$MSG"

log "companion store committed"
maybe_push
