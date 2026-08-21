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
# Resolution itself lives in fh_hub_identity.sh, shared with sync-from-be.sh and
# fh_session_load.sh — see that file's header for why a sibling hub's identifying text is never
# hardcoded in a script that ships in the PUBLIC repo, and why factoring this out (rather than three
# hand-copies) is what a PR review caught was missing: a copy that fixes the write side and forgets
# to fix the two read sides in lockstep is exactly the drift a single sourced source-of-truth closes.
_FH_IDLIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fh_hub_identity.sh"
# shellcheck source=scripts/fh_hub_identity.sh
. "$_FH_IDLIB"
if ! fh_resolve_hub_identity; then
  # 10 means "not my hub" ONLY, here and in sync-from-be.sh's own use of the same code — never
  # repurpose it for a genuine mid-run failure elsewhere in this script. The Stop hook (below)
  # stamps its cooldown on 0 OR 10; reusing 10 for a real error would make that hook treat the
  # failure as a quiet success (Wave-2 review, [B]).
  echo "[sync-to-be] refuse: \$FH ($FH) is not a recognized hub — abort" >&2
  exit 10
fi
# The operator-private area's directory name lives HERE, not in fh_hub_identity.sh — that file
# ships in the public npm package and this name is an operator-private token there (the pre-publish
# confidentiality scan blocked `npm publish` on it, 2026-08-21). This script does not ship, and it
# is the only consumer of $HO, so the name belongs at the consumer.
HO="hub-owner$HUB_SUFFIX"

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

# DEFINED HERE, NOT AT ITS OLD SITE ~50 LINES BELOW (fixed 2026-08-16, reproduced first).
# The lock loop below calls `log`. Bash resolves an unknown name through PATH, and macOS ships
# `/usr/bin/log` — so on the CONTENTION path (and only there) `log "companion store busy…"` became
# a syslog invocation that exits 64, and `set -euo pipefail` then killed the script before the
# `exit 0` on that same line could run. The close chain saw a hard failure where the code says
# "next run will retry". Known-positive used to find and confirm it: hold the lock
# (`mkdir "$BE/.sync.lock.d"`) and run — rc was 64 with `log: Unknown subcommand`, now 0.
# The contention path only executes under contention, which is why two parallel sessions on one
# companion store were needed to surface a defect that had been shipping.
log() { [ "$QUIET" = "--quiet" ] || echo "[sync-to-be] $*"; }

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
# `.close_stamps_<date>` 도 같은 이유로 여기 합류한다(pmh-dev#69 리뷰가 잡은 A2) — 처음엔
# merge=union 대상으로 분류했었는데, session_close_check.sh 가 이 파일을 **로컬 카운트**로
# 읽는다(grep -c . → "오늘 몇 번 닫았나"). union 은 정확히 그 소비 패턴과 충돌한다: 되돌아오는
# pull_dir 경로가 이 파일을 배제 목록에 안 넣었더니, 두 노드가 같은 날 각자 한 번씩 닫아도
# 합집합이 내려와 "2번 닫음"으로 잘못 세고, session_close_check.sh 가 불필요한 재작업을
# 지시한다 — 흔한 케이스가 흔하게 오탐한다는 뜻. 이 파일은 크로스머신 소비자가 아예 없으므로
# (기계고유 카운터), .fh_node_state 처럼 통째로 sync 대상에서 뺀다 — 머신 스코프조차 불필요.
SYNC_EXCLUDES=('.gitkeep' '*.marker' 'logs/' '.fh_node_state' '.close_stamps_*')

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
  done < <(find "$src" -type f ! -name '.gitkeep' ! -name '*.marker' ! -name '.fh_node_state' ! -name '.close_stamps_*' ! -path '*/logs/*' 2>/dev/null)
}

# ── Shared abort message for BOTH destination-newer sites ─────────────────────
# ONE function, deliberately: the file-level guard below was added because "a guard applied to some
# callers of a shared hazard is not a guard; it just relocates the hole". The same argument applies
# to the guard's MESSAGE — the two copies had already drifted (the dir-level one named a remedy the
# file-level one did not), and a remedy that exists in one branch is invisible from the other.
#
# MEASURED 2026-08-20 (air node, n=4 files, one run) — why the old wording was wrong:
#   The old text asserted ONE cause: "A newer file there means it was edited in the MIRROR."
#   All four files that tripped it had last been written by a `sync:` commit from ANOTHER NODE
#   (git log -1 on each: the pro node's own forward sync), and every mirror copy was a strict
#   superset of the hub's. Nothing had been edited in the mirror. The message was 0/4 correct.
#   Worse, its only escape hatch — SYNC_OVERWRITE_OK=1 — would have pushed this node's STALE copy
#   over the peer's newer work: the exact loss this guard exists to prevent, delivered by the guard's
#   own override. sync-from-be.sh has existed since 2026-08-02 for precisely this case and its own
#   header names this trap ("a guard whose only escape hatch is the data-loss button trains the
#   data-loss button") — but the forward script never cited it, so the fix was unreachable from the
#   moment of need. Gate-locality on a healing path: the remedy must be legible where the block fires.
#   Calibrated before citing: sync-from-be.sh --dry-run was run against all four and covers all four
#   (3 in its silent `clean` set, 1 in `review`). It is cited as the discriminator because it IS one,
#   not because it is adjacent.
# $2 = "pullable" (the return path covers these files) | "local-binding" (it does NOT).
# The second argument exists because a cross-family review (codex/gpt-5.6-terra, 2026-08-20) caught
# this fix REPRODUCING the very defect it closes: sync_file() has exactly ONE call site — the
# `sync_file "$FH/CLAUDE.local.md"` line below — and sync-from-be.sh refuses that file BY NAME
# (grep it there: the "is never pulled" exclusion note and the pair-list comment above pull_dir).
# 🟥 Anchors are NAMES, not line numbers, on purpose: the first version of this comment cited
# `:551` / `:576` and BOTH had already drifted by the time this branch was reviewed — the same
# commit that added these lines pushed them down. A number in prose is a phantom waiting for the
# next edit; a greppable string survives it.
# So a shared message citing the return path there is dead advice at 100% of that site's invocations.
# One message for two sites was right; one *remedy* for two sites was not.
_abort_dest_newer() {   # $1 = pre-formatted hit list (one "  <path>  (newer than <path>)" per line)
  local rp="$FH/scripts/sync-from-be.sh" kind="${2:-pullable}"
  echo "" >&2
  echo "🚫 SYNC ABORTED — the destination is NEWER than the source:" >&2
  printf '%s' "$1" >&2
  echo "" >&2
  echo "   This transport is ONE-WAY: the hub is canonical, the companion store is a mirror." >&2
  echo "   A newer file there has TWO COMMON causes that take OPPOSITE remedies (the guard" >&2
  echo "   tests newer+divergent, NOT provenance — corruption or a stray copy land here too)." >&2
  echo "" >&2
  echo "   ⓐ ANOTHER NODE advanced. Its work reaches this hub's gitignored half ONLY through" >&2
  echo "      the store, so the mirror is legitimately ahead and THIS hub is the stale one." >&2
  if [ "$kind" = "local-binding" ]; then
    echo "      🟥 The return path does NOT cover this file. sync-from-be.sh refuses" >&2
    echo "         CLAUDE.local.md by name (a peer's local binding must never land here), so" >&2
    echo "         there is no scripted recovery: open BOTH copies and reconcile by hand." >&2
  elif [ -f "$rp" ]; then
    echo "      → bash \"$rp\" --dry-run" >&2
    echo "        Run this FIRST. It does not prove WHO wrote the file — it answers the" >&2
    echo "        question that decides the remedy: would the return path pull these?" >&2
    echo "        🟥 Read its COUNT line (\"pulled N ... clean C · review R\"), not only the" >&2
    echo "           names below it: the 'clean' set is COUNTED AND NOT LISTED, so a name" >&2
    echo "           missing from the printout is not a file missing from the pull. (This" >&2
    echo "           misread happened on 2026-08-20 — 3 of 4 hits were in the silent set.)" >&2
    echo "        Re-run without --dry-run to apply; it backs up every file it overwrites." >&2
  else
    echo "      ⚠️  the return path is NOT PRESENT at $rp" >&2
    echo "        — ⓐ cannot be applied on this node; recover by hand before overriding." >&2
  fi
  echo "" >&2
  echo "   ⓑ The mirror was EDITED IN PLACE. Move the edit back to the canonical path under" >&2
  echo "      the hub, then re-run this script." >&2
  echo "" >&2
  echo "   🟥 SYNC_OVERWRITE_OK=1 is NOT the fix for ⓐ. It overwrites the other node's newer" >&2
  echo "      work with this node's stale copy — the very loss this guard exists to stop," >&2
  echo "      delivered by its own override. Use it ONLY when the mirror copy is genuinely" >&2
  echo "      stale: SYNC_OVERWRITE_OK=1 \"$0\"" >&2
  echo "" >&2
  exit 1
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
      _abort_dest_newer "$NEWER_HITS"
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
    if ( cd "$src" && tar cf - --exclude='.gitkeep' --exclude='*.marker' --exclude='.fh_node_state' --exclude='.close_stamps_*' --exclude='logs' . ) \
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
      _abort_dest_newer "  $dstf  (newer than $src)
" local-binding
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
# machine writes the same content, and append-only rsync merges them harmlessly). Three files
# are NOT: each hub clone keeps its OWN edit_manifest.yaml, its OWN memory index, and its OWN
# `.substrate_versions` (installed tool versions — added 2026-08-14, pmh-dev#69), because they
# describe THAT machine's local state. Mirroring them to one shared path makes every machine
# silently overwrite the others' record — measured 2026-07-15 for the manifest (three machines
# synced the same day and fh-be's manifest ended up 135 entries on one machine, 175 on another,
# no file actually lost but the backup rendered ambiguous) and separately for `.substrate_versions`
# on pmh-dev#69 (two nodes, silent auto-merge, one node's record overwritten with the other's — see
# the copy block below). So these three are keyed by machine. `.close_stamps_<date>` joins
# `.fh_node_state` in being excluded from this sync ENTIRELY instead (SYNC_EXCLUDES above) — it is
# also machine-scoped in nature, but has no companion-store consumer at all, so there is nothing to
# key. The session CARD is deliberately NOT keyed — it is the shared cross-machine handoff
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

# One-time migration reap, BEFORE sync_dir runs: a companion store from before this fix may still
# hold an unscoped `.substrate_versions` from a PEER machine (pmh-dev#69's actual pre-fix state).
# sync_dir's destination-newer guard (check_dest_newer, above) walks tracks/_meta BEFORE rsync and
# would see that stale peer copy as differing content newer than this node's own file (rebase-stamp
# mtime) — and ABORT THE ENTIRE tracks/_meta SYNC, not just this one file, with a "move the edit
# back to canonical" remedy that is actively wrong for machine-fact content (it would tell you to
# copy a peer's tool versions into your own record). Reaping it first means the guard never sees it;
# nothing is lost — every machine's content is already in companion git history. One-shot: after the
# first post-fix sync on every node, no stale unscoped copy remains to reap (pmh-dev#69 review, A1).
rm -f "$BE/$TM/.substrate_versions"
sync_dir  "$FH/tracks/_meta"      "$BE/$TM"
# ...then re-home the machine-scoped files out of the shared namespace.
if [ -f "$FH/tracks/_meta/edit_manifest.yaml" ]; then
  mkdir -p "$BE/$TM/manifests"
  cp "$FH/tracks/_meta/edit_manifest.yaml" "$BE/$TM/manifests/$MID.yaml" \
    && log "manifest → $TM/manifests/$MID.yaml (machine-scoped)"
  rm -f "$BE/$TM/edit_manifest.yaml"   # shared copy retired; history keeps every machine's
fi
# `.substrate_versions` is machine-fact content (installed tool versions), not shared state — the
# same reason `.fh_node_state` above is excluded from this sync entirely, except this file legitimately
# needs a companion-store record (per-machine substrate drift is worth seeing across the hub), so it
# gets the manifest treatment instead of a bare exclude: mirror once for content, then re-home under a
# machine-scoped name so a second node's sync can never silently overwrite this node's record with its
# own (predicted 2026-08-14 from pmh-dev#69's measured add/add on the sibling
# `.destructive_op_override_log` — two PMH nodes hit that log's conflict directly; PMH's report says
# `.substrate_versions` auto-merged silently on the same run because one side was empty, which is
# consistent with this file class corrupting the same way without ever surfacing as a visible
# conflict — worse than the log-file case, but not independently confirmed as a corrupted value).
if [ -f "$FH/tracks/_meta/.substrate_versions" ]; then
  mkdir -p "$BE/$TM/substrate"
  cp "$FH/tracks/_meta/.substrate_versions" "$BE/$TM/substrate/$MID" \
    && log "substrate versions → $TM/substrate/$MID (machine-scoped)"
  rm -f "$BE/$TM/.substrate_versions"   # shared copy retired; history keeps every machine's
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
