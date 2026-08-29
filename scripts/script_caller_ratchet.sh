#!/usr/bin/env bash
# script_caller_ratchet.sh — a PRODUCTION script that nothing dispatches is prose, not machinery.
#
# ── WHY THIS EXISTS, AND WHY IT IS NOT lane_runner_check.sh ────────────────────────────────────
# [[feedback_built_but_not_wired]] is named in memory and enforced nowhere on this population.
# The repo already has ONE ratchet of this shape and it is deliberately narrower:
#
#   scripts/lane_runner_check.sh  — population: LANE SUITES (`test_*.sh` / `*_lanes.sh`) plus
#                                   embedded `--self-test` dispatchers. Three-valued
#                                   (WIRED / EXEMPT / DEBT), declarations live in in-script arrays.
#                                   Wired into scripts/selfcheck.sh.
#
# That check answers "does anything RUN this lane suite". It cannot answer "does anything CALL this
# production script", because a production script matches neither of its globs. Measured on this
# tree at authoring time: `scripts/prior_art_prompt.sh` sat with zero settings registrations for a
# stretch, and CLAUDE.md itself records `scripts/consent_registry_check.sh` as **unwired** — neither
# is a lane suite, so neither is visible to lane_runner_check.sh, and both were found by hand.
#
# THE POPULATIONS ARE DISJOINT ON PURPOSE. This file EXCLUDES `test_*.sh` / `*_lanes.sh` and
# delegates them to lane_runner_check.sh. Two instruments over one file would give the repo two
# answers to the same question and a place for them to diverge in silence — the exact
# duplicate-normalizer defect this repo has already logged.
#
# ── THE TECHNIQUE: RATCHET BY IDENTITY, NOT BY COUNT (transplanted from qasp `caller-zero-ratchet`)
# Synergy scan 2026-08-22 pair T2. The load-bearing property is that the verdict is keyed on WHICH
# scripts are callerless, against a committed baseline file — never on HOW MANY. A count-keyed gate
# passes when you wire one script and add another, which is precisely the regrowth a ratchet exists
# to stop. The outward pass on that pair also found the technique is a named, common pattern
# ("baseline ratchet" — knip / ts-prune `--save-baseline` and friends), so this is an adoption of a
# known shape, not an invention. No such tool covers a shell+markdown repo, which is why it is
# hand-rolled here rather than installed.
#
# ── FOUR-VALUED, and the middle two are the whole point ───────────────────────────────────────
#   WIRED      — some tracked runner dispatches it (script · git hook · CI workflow · package.json
#                · bin/*.js · launchd plist · a tracked settings snippet under templates/)
#   EXEMPT     — declared in the baseline file with a reason it legitimately has no caller
#                (an entry point a human or an installer invokes; a shipped template payload)
#   BASELINE   — declared known-callerless debt: grandfathered, printed on every run, does NOT block
#   UNDECLARED — none of the above → **FAIL**. Today's callerless set is debt; tomorrow's is a bug.
#
# 🟥 ZERO CALLERS IS NOT AUTOMATICALLY A DEFECT. A human-run enumerate tool
# (`templates/predelete_check.sh` is run by a human BY DESIGN — CLAUDE.md says so in as many words),
# an npm entry point, a launchd payload: all legitimately have no in-repo caller. That is what
# EXEMPT is for, and every EXEMPT entry must carry a written reason. Exclusions are declared by
# identity in the baseline file — never by a `grep -v` in the scan — because a dead filter kills only
# the true positives and reports green ([[feedback_deletion_beats_repair_dead_filter]]).
#
# ── WHAT THIS DOES NOT MEASURE (named, not silently absent) ────────────────────────────────────
#   · `templates/**/*.sh` is OUT OF POPULATION. Those are shipped payload executed inside a
#     CONSUMER's repo; "no caller here" is their correct state and scanning them would produce a
#     baseline of pure noise. Their wiring is a consumer-install property, unmeasured by this file.
#   · `.claude/settings.json` is GITIGNORED in this repo. A script dispatched ONLY from there is
#     wired on one machine and callerless for every consumer and for CI. This scan therefore does
#     NOT count it as a caller — but it does READ it and print a separate `local-only` line, so the
#     state is visible rather than rendered as a plain zero.
#   · A dispatch built at runtime from a variable path this scan cannot resolve reads as no caller.
#     Same bounded-regex limit lane_runner_check.sh names for itself; the fix is a baseline entry.
#   · Markdown is never a caller. CLAUDE.md naming a script is a MENTION — this repo has logged the
#     prose-invoked-floor defect explicitly, so `.md` is not in the runner surface list.
#
# ── THE SECOND HALF OF THE RATCHET: baseline: IS SHRINK-ONLY, AND THAT IS ENFORCED ────────────
# The four-value classification above answers "is anything callerless and undeclared". On its own
# that is only half a ratchet, and the missing half is the load-bearing one: nothing stopped an
# author from making a script callerless AND adding its path to `baseline:` in the same change,
# which passed. Measured 2026-08-22 by the governor — the FAIL message below already said in prose
# that this was not a legal move while the code allowed it, i.e. the rule was misdescribing its own
# machine. The `baseline:` section is now diffed against a BASE COMMIT and additions block.
#
# Usage:  bash scripts/script_caller_ratchet.sh [--root DIR] [--list] [--print-baseline] [--base REF]
#   --root DIR        scan DIR instead of the repo this script lives in (fixture isolation)
#   --list            print the per-script verdict table
#   --print-baseline  emit a baseline-file body for the CURRENT callerless set, to stdout, and exit
#                     0 without judging. Bootstrap aid only — every emitted line needs a reason
#                     written by a human before it is committed.
#   --base REF        compare `baseline:` against REF instead of the auto-resolved base
#                     (env twin: FH_RATCHET_BASE_REF)
# Env:    FH_RATCHET_BASE_REF   as --base
#         FH_RATCHET_REQUIRE_BASE=1
#                     an UNUSABLE base becomes exit 2 instead of a labelled non-blocking line.
#                     Unusable = no base at all (UNMEASURED) **or** a base that resolved to HEAD
#                     itself (WORKTREE_ONLY) — the second is the one a cross-family review had to
#                     add: on `push` to main, `origin/main` IS the checked-out HEAD, and comparing
#                     a commit with itself can never show growth, so the pass was vacuous.
#                     🟥 SET THIS IN CI AND NOWHERE ELSE. The split is deliberate: at the merge
#                     boundary the shrink check degrades CLOSED, because that is the surface where
#                     regrowth actually lands; on a developer's machine (no origin, shallow clone,
#                     a fixture root that is not a repo) it degrades to a LABELLED UNMEASURED
#                     rather than blocking, because an over-blocking local gate trains `--no-verify`
#                     and disarms the neighbouring hooks along with this one.
# Exit:   0 = every non-lane script is WIRED, EXEMPT or BASELINE, and `baseline:` did not grow
#         1 = an UNDECLARED callerless script, or a NEW `baseline:` entry (the ratchet fired)
#         2 = instrument error — unreadable/invalid baseline, zero scripts scanned, or an
#             unusable base (none, or HEAD itself) under FH_RATCHET_REQUIRE_BASE=1
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/.." && pwd)"
MODE="judge"; LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 || exit 2 ;;
    --list) LIST=1; shift ;;
    --print-baseline) MODE="emit"; shift ;;
    --base) FH_RATCHET_BASE_REF="${2:-}"; export FH_RATCHET_BASE_REF; shift 2 || exit 2 ;;
    -h|--help) sed -n '/^# Usage:/,/^# Exit:/p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "usage: $0 [--root DIR] [--list] [--print-baseline] [--base REF]" >&2; exit 2 ;;
  esac
done
[ -d "$ROOT" ] || { echo "FAIL  caller-ratchet: --root '$ROOT' is not a directory"; exit 2; }
cd "$ROOT" || exit 2

BASELINE_FILE="scripts/caller_zero_baseline.txt"

# The whole judgment is one python3 pass. python3 is already a hard dependency of the sibling
# ratchet and of selfcheck.sh, so this adds no new requirement.
#
# 🟥 `out=$(...)` then `rc=$?` on its OWN line — never `cmd | tail` and never `|| echo 0`.
# A fallback operator here would hand a broken instrument's empty stdout to the parser and the
# parser would render it as "no violations" ([[feedback_pipefail_fallback_disarms_guard]]).
# -- RUNNER SURFACE = THE GIT INDEX, NOT THE WORKING TREE (D-5, 2026-08-24) --------------------
# An UNTRACKED file must never certify anything as WIRED. Until this fix the RUNNER globs below
# were resolved against the DISK, so a workflow / hook / script that existed only in this working
# copy counted as a caller -- and the tree read green on wiring that disappears on `git clone`.
#
# The POPULATION globs (what gets CHECKED) stay on DISK on purpose. There an untracked file must
# be SEEN, so a new uncommitted script goes red instead of slipping through. Only the RUNNER
# surface moves to the index; moving both would trade one silent pass for another.
#
# 🟥 "NOT A REPOSITORY" AND "GIT FAILED" ARE DIFFERENT FACTS AND MUST NOT SHARE A BRANCH.
# The first draft of this block folded EVERY non-zero `git ls-files` exit into "no index here, use
# the disk". Cross-family review (codex/gpt-5.5, 2026-08-24) executed the consequence: a fake `git`
# that exits 1 for everything produced a warning line and then a PASS. A missing binary, a locked
# or corrupt index, and a permission failure all landed on the SAME branch as an unpacked npm
# tarball -- so the repair against "green that a clone deletes" had installed a fresh green of its
# own. That is [[feedback_not_found_is_not_zero_family]] wearing this file's colours, and the
# asymmetry was backwards: an EMPTY result was routed to UNMEASURED while a FAILED one was routed
# to a pass.
#
# So the state is resolved by POSITIVE questions, in order, and only the answers that are actually
# established are allowed to reach the disk fallback:
#   git absent / `git --version` non-zero        -> UNMEASURED  (the instrument, not the tree)
#   rev-parse fails AND a .git exists up-chain   -> UNMEASURED  (git broke inside a repo)
#   rev-parse fails AND no .git anywhere up-chain-> nongit      (an unpacked tarball: disk is right)
#   inside a git dir with no work tree           -> nongit
#   in a work tree, `git ls-files` non-zero      -> UNMEASURED  (locked/corrupt index, permissions)
#   in a work tree, ls-files empty, cwd ignored  -> outside-index (a package unpacked INSIDE some
#                                                   other repo -- the index cannot answer for it,
#                                                   and blocking every such install would just
#                                                   train the override)
#   in a work tree, ls-files empty, cwd tracked  -> UNMEASURED  (an empty index is not zero runners)
#   otherwise                                    -> index
# 🟥 The discriminator can itself fail, and when it does the answer is UNMEASURED -- never "not a
# repository". That is why the .git walk-up exists: it is a filesystem fact that needs no working
# git, so "git could not tell us" and "there is genuinely nothing here" stay separable.
#
# 🟥 `git ls-files` into a file, then `$?` on its OWN line. No pipe, no `|| true`: a fallback would
# hand an empty list to the scan and the scan would render it as "no runners".
_fh_has_dotgit_upchain() {
  local _d; _d="$(pwd -P)"
  while : ; do
    [ -e "$_d/.git" ] && return 0
    [ "$_d" = "/" ] && return 1
    _d="$(dirname "$_d")"
  done
}
FH_INDEX_STATE="UNMEASURED"; FH_INDEX_WHY="not determined"; FH_INDEX_FILE_LIST=""
if ! command -v git >/dev/null 2>&1; then
  FH_INDEX_WHY="git is not on PATH -- the index could not be read at all"
else
  _fh_gv="$(git --version 2>/dev/null)"; _fh_gvrc=$?
  if [ "$_fh_gvrc" -ne 0 ] || [ -z "$_fh_gv" ]; then
    FH_INDEX_WHY="\`git --version\` exited $_fh_gvrc -- the git binary is unusable, so nothing below was measured"
  else
    _fh_wt="$(git rev-parse --is-inside-work-tree 2>/dev/null)"; _fh_wtrc=$?
    if [ "$_fh_wtrc" -ne 0 ]; then
      if _fh_has_dotgit_upchain; then
        FH_INDEX_WHY="git works but \`rev-parse --is-inside-work-tree\` exited $_fh_wtrc while a .git exists above this directory -- git failed, this is not a plain directory"
      else
        FH_INDEX_STATE="nongit"; FH_INDEX_WHY="no repository here and no .git anywhere above -- an unpacked tarball"
      fi
    elif [ "$_fh_wt" != "true" ]; then
      FH_INDEX_STATE="nongit"; FH_INDEX_WHY="inside a git dir with no work tree (bare repository)"
    else
      # 🟥 NUL ALL THE WAY. An earlier draft piped this through `tr '\0' '\n'` into an env var,
      # which un-did the whole point of `-z`: a path containing a NEWLINE was split into two paths
      # before python ever saw it. Env vars cannot carry NUL, so the list travels as a FILE and the
      # separator is never translated. Cross-family review, 2026-08-24, round 3.
      _fh_tmp="$(mktemp)"
      git ls-files -z >"$_fh_tmp" 2>/dev/null
      _fh_lrc=$?
      FH_INDEX_FILE_LIST="$_fh_tmp"
      if [ "$_fh_lrc" -ne 0 ]; then
        FH_INDEX_WHY="inside a work tree, but \`git ls-files\` exited $_fh_lrc -- a locked or corrupt index, or a permission failure. NOT an absence of runners"
      elif [ -s "$_fh_tmp" ]; then
        FH_INDEX_STATE="index"; FH_INDEX_WHY="the git index"
      else
        git check-ignore -q . 2>/dev/null; _fh_ci=$?
        if [ "$_fh_ci" -eq 0 ]; then
          FH_INDEX_STATE="outside-index"; FH_INDEX_WHY="this directory is IGNORED by the surrounding repository, so its index cannot answer for these files"
        else
          FH_INDEX_WHY="\`git ls-files\` exited 0 and returned NOTHING while this directory is tracked territory -- an empty index is not zero runners"
        fi
      fi
    fi
  fi
fi
export FH_INDEX_STATE FH_INDEX_WHY FH_INDEX_FILE_LIST

out=$(python3 - "$BASELINE_FILE" "$MODE" "$LIST" <<'PY'
import os, re, sys, glob, json, subprocess

BASELINE_FILE, MODE, LIST = sys.argv[1], sys.argv[2], sys.argv[3] == '1'
SELF = 'script_caller_ratchet.sh'
err = []

def read(path):
    try:
        return open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return ''

# ── POPULATION ────────────────────────────────────────────────────────────────────────────────
# Non-lane shell scripts under scripts/. Deduped by PATH, not by basename: scripts/adapters/ may
# legitimately carry a name that also exists at the top level, and collapsing them would let one
# file's wiring certify the other. (The sibling ratchet keys on basename and is single-directory;
# copying that key into a two-level tree is how a scan silently under-reports.)
LANE = re.compile(r'^(test_.*|.*_lanes)\.sh$')
population = sorted(
    p for p in glob.glob('scripts/*.sh') + glob.glob('scripts/adapters/*.sh')
    if not LANE.match(os.path.basename(p)) and os.path.basename(p) != SELF
)

# ── RUNNER SURFACES — enumerated, never assumed ───────────────────────────────────────────────
# Every entry was hand-checked against this tree. `.md` is deliberately absent: prose that names a
# script is a mention, and this repo has a standing rule that a prose-invoked floor is not a floor.
RUNNER_GLOBS = (
    'scripts/*.sh', 'scripts/adapters/*.sh',      # scripts dispatch each other
    'scripts/*.plist',                            # launchd payloads
    'templates/.git-hooks/*',                     # the pre-commit / pre-push gates
    'templates/*.json', 'templates/*.jsonc',      # tracked settings snippets the wizard merges
    '.github/workflows/*.yml', '.github/workflows/*.yaml',
    'bin/*.js',
    'package.json',
    # Typed capability entry points. A `.cap` file's `entry:` line is a real dispatch — this is how
    # scripts/psa_probe_capability.sh and scripts/degrade_probe_capability.sh are reached, and
    # neither has any other caller. Found by hand-checking the callerless list before writing the
    # baseline: both would otherwise have been declared EXEMPT for a reason that is not true.
    # Extending the SURFACE list is the correct repair; an exemption would have been a false record.
    '.claude/capabilities/*.cap', '.claude/capabilities/adapters/*.cap',
)

# -- INDEX-vs-DISK enumeration, RUNNER surfaces ONLY. State resolved in the bash preamble above. -
INDEX_MODE = os.environ.get('FH_INDEX_STATE', '')
INDEX_WHY = os.environ.get('FH_INDEX_WHY', 'the preamble did not run')
_idx_path = os.environ.get('FH_INDEX_FILE_LIST', '')
_idx_raw = b''
if _idx_path:
    try:
        _idx_raw = open(_idx_path, 'rb').read()
    except OSError:
        _idx_raw = b''
INDEX_FILES = [_b.decode('utf-8', 'replace') for _b in _idx_raw.split(b'\0') if _b]
# Fail-closed on anything this file does not recognise, including the empty string a caller that
# skipped the preamble would leave behind. A mode nobody set is not a mode that means "use disk".
if INDEX_MODE not in ('index', 'nongit', 'outside-index'):
    INDEX_MODE = 'UNMEASURED'
if INDEX_MODE == 'index' and not INDEX_FILES:
    INDEX_MODE = 'UNMEASURED'
    INDEX_WHY = 'state said index and the file list is empty -- the two disagree'

def _glob_rx(pat):
    # glob semantics, NOT fnmatch, and that includes the DOTFILE rule.
    # `*` -> `[^/]*` alone is WIDER than the `glob.glob()` it replaced: fnmatch translates `*` to
    # `.*`, which also crosses `/`, and neither form hides dotfiles. `glob.glob('scripts/*.sh')`
    # does NOT return `scripts/.x.sh`; a regex without the guard below DOES, so a hidden tracked
    # file would certify a caller that the old surface never contained. Cross-family review,
    # 2026-08-24. The guard is per SEGMENT and keys on a leading `*`/`?` in that segment -- a dot
    # in a literal segment (`templates/.git-hooks/`) is a directory name and is unaffected; what
    # glob hides is a leading dot in the matched BASENAME.
    _segs = []
    for _seg in pat.split('/'):
        _s = ''
        if _seg[:1] in ('*', '?'):
            _s += '(?!\\.)'
        for _c in _seg:
            _s += '[^/]*' if _c == '*' else '[^/]' if _c == '?' else re.escape(_c)
        _segs.append(_s)
    return re.compile('^' + '/'.join(_segs) + '$')

def enumerate_runners(patterns):
    # index: the candidate runners are what `git ls-files` says is TRACKED.
    # nongit / outside-index: no index can answer here, so disk is the correct surface -- and the
    # run says which of the two it is out loud. UNMEASURED never reaches this function.
    if INDEX_MODE == 'index':
        # 🟥 NO os.path.isfile HERE. Filtering the INDEX list by what happens to be on disk lets the
        # working tree decide the population of an index-grounded judgment -- a tracked runner the
        # worktree has deleted would silently become "not a runner" instead of "read its blob",
        # which also skips the completeness check below. The index blob exists regardless of the
        # working tree; that is the whole reason to read it. Cross-family review, round 3.
        # The disk branch on the next line KEEPS isfile, and so do LOCAL_ONLY_SURFACES: there the
        # working tree IS the surface, and a name with no file behind it is genuinely nothing.
        _rx = [_glob_rx(_p) for _p in patterns]
        return [_p for _p in INDEX_FILES if any(_r.match(_p) for _r in _rx)]
    return [_p for _pat in patterns for _p in glob.glob(_pat) if os.path.isfile(_p)]

if INDEX_MODE == 'UNMEASURED':
    err.append('the runner surface is UNMEASURED, not zero runners: ' + INDEX_WHY)

runners = enumerate_runners(RUNNER_GLOBS)
# This file names every EXEMPT and BASELINE entry (in the file it reads, not in itself) and prints
# script paths in its own report. Scanning itself would let the report certify its own todo list.
runners = [r for r in runners if os.path.basename(r) != SELF]

# -- RUNNER CONTENT = THE INDEX BLOB, NOT THE WORKING TREE FILE -------------------------------
# 🟥 THE OTHER HALF OF D-5. Moving the runner FILE LIST to the index closed "is this runner in the
# clone"; it did NOT close "does that runner call this lane in the clone". The names came from
# `git ls-files` while the bodies were still read with `open()`, so ONE UNSTAGED LINE added to an
# already-tracked runner certified a wiring that exists in nobody's checkout but this one -- the
# same defect wearing the other half of its face. Cross-family review, 2026-08-24, round 2.
# Claiming "the surface is index-grounded" while half of it was not is exactly
# [[feedback_half_fix_propagation_boundary]] / "measured scope != claimed scope".
#
# ONE process, not one per runner: there are ~185 runner surfaces here, and `git show` per file
# would be ~185 forks. `git cat-file --batch` reads them all from one stdin stream.
#
# 🟥 EVERY FAILURE PATH IS UNMEASURED, NEVER AN EMPTY BODY. A missing blob, a short read, a
# non-blob object, a git that will not start -- each of them, read as "" , renders the runner as
# calling nothing, which is the fold this whole file exists to refuse. They collect in _BLOB_ERR
# and route to the same UNMEASURED exit as a broken index does.
# In `nongit` / `outside-index` there is no blob to read and that is already decided policy
# (protection off, labelled) -- the loader is simply not run, and the disk reader stays in place.
# No new state value.
_BLOBS = {}
_BLOB_ERR = []

def _load_index_blobs(paths):
    if INDEX_MODE != 'index' or not paths:
        return
    # `git cat-file --batch` reads NEWLINE-delimited input, so a path containing one cannot be
    # asked for safely. Refuse to guess: that is UNMEASURED, not "this runner calls nothing".
    for _p in paths:
        if '\n' in _p:
            _BLOB_ERR.append('a runner path contains a newline and cannot be batched: ' + repr(_p))
    if _BLOB_ERR:
        return
    _inp = ''.join(':' + _p + '\n' for _p in paths)
    try:
        _pr = subprocess.run(['git', 'cat-file', '--batch'], input=_inp.encode('utf-8'), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except OSError as _e:
        _BLOB_ERR.append('git cat-file could not be started: ' + str(_e))
        return
    if _pr.returncode != 0:
        _BLOB_ERR.append('git cat-file --batch exited ' + str(_pr.returncode))
        return
    _buf = _pr.stdout
    _pos = 0
    for _p in paths:
        _nl = _buf.find(b'\n', _pos)
        if _nl < 0:
            _BLOB_ERR.append('git cat-file output ended early at ' + _p)
            return
        _hdr = _buf[_pos:_nl].decode('utf-8', 'replace').split()
        _pos = _nl + 1
        if len(_hdr) != 3 or _hdr[1] != 'blob':
            _BLOB_ERR.append('no blob in the index for ' + _p + ': ' + ' '.join(_hdr))
            return
        _sz = int(_hdr[2])
        _end = _pos + _sz
        if _end > len(_buf):
            _BLOB_ERR.append('git cat-file returned a short body for ' + _p)
            return
        _BLOBS[_p] = _buf[_pos:_end].decode('utf-8', 'replace')
        _pos = _end + 1
    # Completeness, checked rather than assumed, and INSIDE the loader so that the loader is a
    # single switch: this is what makes the disk fallback in read_runner unreachable for a runner
    # in index mode. Without it a silently missing key would fall through to the working tree and
    # rebuild the defect one path at a time.
    for _p in paths:
        if _p not in _BLOBS:
            _BLOB_ERR.append('the index blob for ' + _p + ' was never read')

_load_index_blobs(runners)

def _read_disk(path):
    try:
        return open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return ''

def read_runner(path):
    # index mode: every runner is in _BLOBS (asserted above), so the disk branch is reachable only
    # for surfaces that are deliberately NOT index-backed -- the gitignored local settings file --
    # and for the nongit / outside-index states.
    if path in _BLOBS:
        return _BLOBS[path]
    return _read_disk(path)

if _BLOB_ERR:
    INDEX_MODE = 'UNMEASURED'
    INDEX_WHY = 'the runner CONTENT is UNMEASURED, not empty: ' + ' - '.join(_BLOB_ERR)
    err.append(INDEX_WHY)

# Read but NOT counted as a caller — see the header. Kept as its own surface so the state is a
# labelled value rather than an invisible zero.
LOCAL_ONLY_SURFACES = [p for p in ('.claude/settings.json',) if os.path.isfile(p)]

def strip_line_comments(txt):
    """`#`- and `//`-prefixed lines only. A mention is not an invocation, and the commonest mention
    in this tree is a usage line in a header comment. Line-prefix only: a dispatch inside a heredoc
    body or an echoed string still reads as live. That limit is inherited knowingly from
    lane_runner_check.sh, which names the same residual for itself."""
    keep = []
    for ln in txt.split('\n'):
        s = ln.strip()
        if s.startswith('#') or s.startswith('//'):
            continue
        keep.append(ln)
    return '\n'.join(keep)

XML_COMMENT = re.compile(r'<!--.*?-->', re.S)

# 🟥 The prefix is NOT `\b`. `\b` before the `.` alternative can never match: a POSIX dot-source is
# written as ` . "$LIB"`, and between a space and a `.` there is no word boundary. Measured — the
# first version of this constant used `\b` and called scripts/hook_source_lib.sh callerless while
# two hooks dot-source it. A boundary assertion that is silently unsatisfiable for one alternative
# is a dead filter that kills only true positives.
# The prefix class is built with chr() for the same reason the quote class below is: keeping a
# literal open-paren and literal quotes out of a heredoc line that bash's command-substitution
# scanner also reads. chr(34)=" chr(39)=' chr(40)=(
# 🟥 QUOTES ARE IN THE PREFIX CLASS ON PURPOSE. package.json spells its dispatch as
#   "prepublishOnly": "bash scripts/prepublish_scope_note.sh && ..."
# so the character before the verb is a double-quote. A prefix class of whitespace-and-operators
# only dropped that file's five dispatches — measured, mid-authoring, when swapping \b for an
# explicit class silently moved two scripts into the callerless set.
_PRE = '(?m)(?:^|[' + chr(34) + chr(39) + chr(40) + r'\s;&|])'
VERB = _PRE + r'(?:exec\s+)?(?:bash|sh|source|\.)'

# 🟥 A BASENAME MUST MATCH AS A WHOLE PATH TOKEN, NEVER AS A SUBSTRING.
# Measured (cross-family review 2026-08-22): a runner containing only `bash scripts/foo.sh.bak`
# certified scripts/foo.sh as WIRED and the ratchet exited 0. The same hole runs the other way —
# `bash scripts/myfoo.sh` certified foo.sh — and it is the worst possible direction for this gate,
# because the FP is silent and always lands on the PASS side. Both ends are closed here:
#   trailing  (?![\w.-])   `foo.sh.bak` · `foo.sh_old` · `foo.shx` no longer certify `foo.sh`
#   leading   (?<![\w.-])  `myfoo.sh` · `x.foo.sh` no longer certify `foo.sh`
# The allowed neighbours are exactly the path/shell terminators a real dispatch puts there:
# `/` `"` `'` `(` `)` whitespace `;` `&` `|` `<` `>` and end-of-line.
# The boundary is a lookaround pair, NOT a `grep -v` on the hit list: an exclusion applied after
# the fact is the dead-filter shape this repo has logged, and it kills true positives first.
def name_re(name):
    return r'(?<![\w.\-])' + re.escape(name) + r'(?![\w.\-])'

def dispatches_shell(name, body):
    """THREE shapes, all three measured live in this tree. The first draft shipped only shape 1 and
    reported 36 callerless scripts; a hand-check of the first eight found FIVE of them dispatched —
    the predicate was wrong, not the tree. That is the calibration rule doing its job, and the count
    was never published anywhere but this comment.

    Shape 1 (direct): `bash|sh|source|. <...name>` on one line. `source`/`.` matter because a
        library is dispatched by being sourced — scripts/hook_source_lib.sh is loaded that way by
        two hooks and shape 1 without the source verb called it callerless.
    Shape 2 (for-list): the literal name sits in a `for VAR in ...` list whose body runs $VAR.
        Inherited from lane_runner_check.sh, which hand-verified two live cases of it.
    Shape 3 (assign-then-dispatch): `JC_LINT="$REPO_ROOT/scripts/judgment_circuit_lint.sh"` on one
        line and `bash "$JC_LINT"` on another. This is the DOMINANT idiom in templates/.git-hooks/
        and in scripts/selfcheck.sh, and shape 1 structurally cannot see it: the name and the verb
        never share a line. It is keyed to the variable actually assigned the path — not to "this
        file mentions the name and also runs something" — so a fixture `cp "$ROOT/scripts/x.sh"`
        does not become a caller."""
    lines = body.split('\n')
    NAME = name_re(name)
    nre = re.compile(NAME)
    direct = re.compile(VERB + r'\s+[^\n]{0,80}?' + NAME)
    indirect = any(re.search(VERB + r'\s+' + chr(34) + r'?\$', ln) for ln in lines)
    assigned = set()
    for ln in lines:
        # 🟥 The token-boundary form, not `name in ln`. A substring prefilter here re-opened the
        # hole the boundary closes above: `JC="$R/scripts/foo.sh.bak"` registered JC as holding
        # foo.sh, and the later `bash "$JC"` then certified foo.sh through shape 3.
        if not nre.search(ln):
            continue
        if direct.search(ln):
            return True
        if indirect and re.match(r'\s*(for\s+\w+\s+in\b|["\']?\S*\|)', ln):
            # 🟥 THE PIPE FORM IS A PAIR, AND ONLY ITS LAST FIELD IS RUN.
            # scripts/selfcheck.sh's suite loop is `"SUBJECT|ANCHOR"`, and its body does
            #     _subj="${_pair%%|*}"; _anc="${_pair##*|}"  ...  bash "$_anc"
            # — the SUBJECT is only `[ -f ]`-tested, never dispatched. Counting it as a caller made
            # the ratchet tell a session to delete a `baseline:` line whose whole point is "still
            # owes a PRODUCTION caller". That advice was given and followed once (2026-08-26,
            # scripts/chamber_candidate_collect.sh), reverted by cross-family review, and fired
            # AGAIN on the same file on 2026-08-30 — the only thing that stopped a second deletion
            # was the note the reviewer had left in the baseline file. A gate whose correctness
            # depends on someone having written a comment last time is not a gate.
            # Direction is fail-closed: under-crediting a caller makes a script look callerless,
            # which FAILS loudly, rather than silently discharging a debt.
            # The discriminator is NOT "is this a for-line" — selfcheck.sh puts its pairs on
            # continuation lines while a fixture puts them on the `for` line itself, and both mean
            # the same thing. It is "does the name sit BEFORE the last pipe": a `X|Y` item
            # dispatches Y. `for f in a.sh b.sh` has no pipe and is untouched, and a genuine
            # `bash scripts/foo.sh | tee log` never reaches here — shape 1 returned already.
            if '|' in ln and not nre.search(ln.rsplit('|', 1)[1]):
                continue          # named as the SUBJECT of a subject|anchor pair — not a dispatch
            return True
        m = re.match(r'\s*(?:local\s+|export\s+|declare\s+-\w+\s+)?([A-Za-z_][A-Za-z0-9_]*)=', ln)
        if m:
            assigned.add(m.group(1))
    # 🟥 The quote class is built with chr() — a line inside this heredoc that carries an ODD number
    # of literal double-quotes desynchronises bash's command-substitution scan and breaks the parse
    # of every line after it (measured here; lane_runner_check.sh records the paren twin of it).
    QC = '[' + chr(34) + chr(39) + ']?'
    for var in assigned:
        v = re.escape(var)
        # explicit verb on the variable, or the variable in command position at line start
        if re.search(VERB + r'\s+' + QC + r'\$\{?' + v + r'\b', body):
            return True
        if re.search(r'(?m)^\s*' + QC + r'\$\{?' + v + r'\}?' + QC + r'(\s|$)', body):
            return True
    return False

PLIST_STRING = re.compile(r'<string>(.*?)</string>', re.S)

# 🟥 A PLACEHOLDER PATH IS NOT A DISPATCH — launchd cannot execute it.
# Measured 2026-08-22 (governor known-pair): scripts/com.forge-harness.frontier-digest.plist
# carries `<string>/path/to/forge-harness/scripts/frontier_digest_autopilot.sh</string>`, and its
# own XML header says "Replace every /path/to/... below with your own absolute paths before
# installing" — the tracked plist is a TEMPLATE, the live one lives under ~/Library/LaunchAgents.
# Reading it as a caller made this gate PASS over a defect that
# knowledge/shared/harness-core/ship_readiness_gate.md had already recorded against identity ④
# ("the daily digest launcher ships a placeholder path in its plist"). A gate that green-lights a
# defect its own repo has written down is worse than no gate.
#
# 🟥 WHY THIS IS A LITERAL PLACEHOLDER LIST AND NOT A PATH-EXISTENCE TEST. The obvious repair —
# `os.path.isfile(<the absolute path>)` — is WRONG here and would have been the over-block: a
# CORRECT plist hardcodes the author's own absolute path (`/Users/<op>/projects/...`), which does
# not resolve on the Linux CI runner. That test would go green locally and red in CI on a plist
# with nothing wrong with it, which is the exact BSD/GNU-split failure this workflow's header
# warns about. The literal list is narrower, deterministic, and identical on both platforms.
#
# 🟥 `$VAR` / `${VAR}` / `~` ARE IN THE LIST AS OF 2026-08-22, and why they were OUT before is worth
# keeping written down. The first draft excluded them under this repo's N>=3-before-mechanizing rule,
# with the reason "no measured case in this tree" — which was true of the TREE and irrelevant to the
# GATE. A cross-family reviewer then produced the case: `<string>$HOME/projects/forge-harness/scripts/
# daily.sh</string>` was counted as a dispatch and the ratchet exited 0 (reproduced here before this
# edit). launchd does NOT shell-expand ProgramArguments — it execs the literal string — so that path
# is exactly as unexecutable as `/path/to/...`: the SAME defect class wearing different characters.
# The correction to the reasoning: the N>=3 threshold governs whether to BUILD a mechanism, not which
# members of a class an already-built mechanism recognises. This mechanism existed; leaving a known
# member of its own class outside it is a dead spot, not restraint.
# Over-block guard: each added form has a known-negative control below AND a lane twin — a real
# absolute path (`/Users/...`), which contains none of these characters, must still wire.
PLIST_PLACEHOLDER = re.compile(
    r'(?:^|/)(?:'
    r'path/to'
    r'|your[-_]?(?:path|home|dir|repo|name)'
    r'|<[^>]+>'
    r'|\{\{[^}]*\}\}'
    r'|\$\{[^}]*\}'                 # ${HOME}/... — launchd does not expand it
    r'|\$[A-Za-z_][A-Za-z0-9_]*'    # $HOME/...
    r'|~[^/]*'                      # ~/... and ~user/... — not expanded either
    r'|TODO|CHANGEME|REPLACE[-_]?ME'
    r')(?:/|$)', re.I)

plist_placeholder_hits = []   # (surface, script) — surfaced in the report, never a silent drop

def dispatches_plist(name, txt, surface=None):
    """A plist has no `#` comments; it has XML ones, and this repo's plist uses an XML comment to
    name an ALTERNATIVE script you could point it at. Taking bare presence as a dispatch reads that
    comment as a caller — measured on scripts/com.forge-harness.frontier-digest.plist, where
    frontier_digest_daily.sh is named only inside `<!-- ... -->`. So: strip XML comments, take the
    <string> VALUES, and require the name as a whole path token inside a value that is not a
    placeholder."""
    body = XML_COMMENT.sub('', txt)
    nre = re.compile(name_re(name))
    seen_placeholder = False
    for val in PLIST_STRING.findall(body):
        if not nre.search(val):
            continue
        if PLIST_PLACEHOLDER.search(val):
            seen_placeholder = True
            continue
        return True
    if seen_placeholder and surface is not None:
        plist_placeholder_hits.append(surface + '  ->  ' + name)
    return False

def dispatches_js(name, txt):
    """A node entry point reaches its script through a path.join of __dirname and the name, so the
    shell predicate structurally cannot see it. Require the basename inside a quoted string on a
    non-comment line. (The literal join form is spelled out in lane L12 of the fixture suite rather
    than here, because portability-lint reads a path literal in a checker as a repo-file fixture
    reference — a false positive, but a cheap one to avoid by not writing the literal.)

    Quote characters are built with chr() rather than written as literals: this heredoc sits inside
    a command substitution, and lane_runner_check.sh records a measured case where a line whose own
    quote/paren balance was uneven broke bash's parse of every line after it, in THIS shape of file.
    Keeping the literals out of the line is cheaper than re-learning that."""
    body = strip_line_comments(txt)
    q = chr(34) + chr(39)
    pat = '[' + q + '][^' + q + chr(10) + ']*' + name_re(name)
    return bool(re.search(pat, body))

def has_caller(path, surfaces):
    name = os.path.basename(path)
    hits = []
    for r in surfaces:
        if os.path.abspath(r) == os.path.abspath(path):
            continue                       # a script does not wire itself
        txt = read_runner(r)
        if name not in txt:
            continue
        ext = os.path.splitext(r)[1]
        if ext == '.plist':
            ok = dispatches_plist(name, txt, surface=r)
        elif ext == '.js':
            ok = dispatches_js(name, txt)
        else:
            ok = dispatches_shell(name, strip_line_comments(txt))
        if ok:
            hits.append(r)
    return hits

# ── DECLARATIONS ──────────────────────────────────────────────────────────────────────────────
# Format, deliberately the dumbest thing that carries a reason:
#
#     exempt:
#       - scripts/foo.sh   # why this legitimately has no caller
#     baseline:
#       - scripts/bar.sh   # what it is waiting on
#
# The reason is a CHANNEL check, in this repo's sense: the gate asserts a property of the record
# (present · attributable · non-vacuous), never that the reason is a good one. A reason that is
# missing or under 12 characters is an instrument error, not a pass — an entry you cannot write a
# sentence for probably belongs in a runner instead of in this file.
exempt, baseline, decl_lines = {}, {}, 0
if os.path.isfile(BASELINE_FILE):
    sect = None
    for i, raw in enumerate(read(BASELINE_FILE).split('\n'), 1):
        s = raw.rstrip()
        if not s.strip() or s.lstrip().startswith('#'):
            continue
        m = re.match(r'^([A-Za-z_]+):\s*$', s)
        if m:
            sect = m.group(1)
            if sect not in ('exempt', 'baseline'):
                err.append(f"{BASELINE_FILE}:{i}: unknown section '{sect}' (expected exempt/baseline)")
            continue
        m = re.match(r'^\s+-\s+(\S+)\s*(?:#\s*(.*))?$', s)
        if not m:
            err.append(f"{BASELINE_FILE}:{i}: unparseable line: {s.strip()[:60]}")
            continue
        if sect is None:
            err.append(f"{BASELINE_FILE}:{i}: entry before any section header")
            continue
        path, reason = m.group(1), (m.group(2) or '').strip()
        if len(reason) < 12:
            err.append(f"{BASELINE_FILE}:{i}: '{path}' has no substantive reason "
                       f"(needs a trailing `# <why>` of 12+ chars; got {len(reason)})")
            continue
        if path in exempt or path in baseline:
            err.append(f"{BASELINE_FILE}:{i}: '{path}' declared twice — ambiguous")
            continue
        (exempt if sect == 'exempt' else baseline)[path] = reason
        decl_lines += 1
elif MODE != 'emit':
    err.append(f"{BASELINE_FILE} not found. Bootstrap it with --print-baseline, then write a "
               f"reason on every line. A MISSING baseline is UNMEASURED, not empty.")

# ── CONTROLS — the instrument proves it can separate a known pair before it judges anything ────
# Not a substitute for the fixture lanes in scripts/test_script_caller_ratchet_lanes.sh; this is the
# in-process floor that stops a silently-dead predicate from reporting a clean tree.
ctrl = []
_pos = 'scripts/zzz_known_positive.sh'
if has_caller(_pos, runners):
    ctrl.append('known-negative control FAILED: a script that does not exist reports a caller')
if not dispatches_shell('alpha.sh', 'bash scripts/alpha.sh --quiet\n'):
    ctrl.append('known-positive control FAILED: a literal `bash scripts/alpha.sh` is not seen')
# 🟥 This control drives the SAME COMPOSITION the real call site uses — dispatches_shell over
# strip_line_comments(...) — not dispatches_shell alone. The first draft called the predicate bare
# and failed, correctly: comment-stripping lives one level up, so a control that skips it is
# measuring a pipeline that no caller runs. Keep the composition here identical to has_caller's.
if dispatches_shell('alpha.sh', strip_line_comments('#   bash scripts/alpha.sh   <- usage, not a caller\n')):
    ctrl.append('known-negative control FAILED: a commented usage line counts as a caller')
if not dispatches_shell('a.sh', 'source "$D/scripts/a.sh"\n'):
    ctrl.append('known-positive control FAILED: `source` is not read as a dispatch verb')
if not dispatches_shell('a.sh', 'V="$R/scripts/a.sh"\nbash "$V" --quiet\n'):
    ctrl.append('known-positive control FAILED: assign-then-dispatch (shape 3) not seen')
if dispatches_shell('a.sh', 'V="$R/scripts/a.sh"\ncp "$V" "$d/scripts/"\n'):
    ctrl.append('known-negative control FAILED: copying a script counts as dispatching it')
if not dispatches_plist('a.sh', '<string>/x/scripts/a.sh</string>'):
    ctrl.append('known-positive control FAILED: plist <string> dispatch not seen')
if dispatches_plist('a.sh', '<!-- point this at scripts/a.sh instead --><string>/x/b.sh</string>'):
    ctrl.append('known-negative control FAILED: an XML-commented plist path counts as a caller')
# ── boundary controls (added 2026-08-22 for the substring defect) ─────────────────────────────
# Each blocking direction gets its known-negative AND its known-positive twin, because a boundary
# that is too tight silently converts wired scripts into UNDECLARED — an over-block on a
# merge-blocking gate, which trains the override and disarms the neighbouring hooks with it.
if dispatches_shell('a.sh', 'bash scripts/a.sh.bak --quiet\n'):
    ctrl.append('known-negative control FAILED: a `.bak` suffix path certifies the base name')
if dispatches_shell('a.sh', 'bash scripts/mya.sh --quiet\n'):
    ctrl.append('known-negative control FAILED: a longer basename certifies its suffix')
if dispatches_shell('a.sh', 'V="$R/scripts/a.sh.bak"\nbash "$V"\n'):
    ctrl.append('known-negative control FAILED: shape 3 over a suffixed path certifies the base name')
if not dispatches_shell('a.sh', 'bash ' + chr(34) + '$D/scripts/a.sh' + chr(34) + ' --quiet\n'):
    ctrl.append('known-positive control FAILED: boundary over-tightened — a quoted path no longer dispatches')
if not dispatches_shell('a.sh', 'bash scripts/a.sh\n'):
    ctrl.append('known-positive control FAILED: boundary over-tightened — end-of-line dispatch lost')
if dispatches_plist('a.sh', '<string>/path/to/repo/scripts/a.sh</string>'):
    ctrl.append('known-negative control FAILED: a /path/to/ placeholder plist path counts as a caller')
if not dispatches_plist('a.sh', '<string>/opt/ci/projects/repo/scripts/a.sh</string>'):
    ctrl.append('known-positive control FAILED: placeholder filter over-blocks a real absolute path')
# ── unexpanded-variable plist paths (added 2026-08-22, cross-family reproduction) ─────────────
# launchd execs ProgramArguments literally — no shell expansion — so each of these is a path that
# cannot run. The known-positive twin directly above is what stops this from over-blocking.
for _ph in ('$HOME/projects/repo/scripts/a.sh',
            '${HOME}/projects/repo/scripts/a.sh',
            '~/projects/repo/scripts/a.sh',
            '~someone/projects/repo/scripts/a.sh'):
    if dispatches_plist('a.sh', '<string>' + _ph + '</string>'):
        ctrl.append('known-negative control FAILED: an unexpanded plist path counts as a caller: ' + _ph)
if dispatches_js('a.sh', "path.join(__dirname, 'scripts', 'a.sh.bak')"):
    ctrl.append('known-negative control FAILED: bin/*.js suffix path certifies the base name')
if not dispatches_js('a.sh', "path.join(__dirname, '..', 'scripts', 'a.sh')"):
    ctrl.append('known-positive control FAILED: bin/*.js path.join dispatch not seen')

# ── CLASSIFY ──────────────────────────────────────────────────────────────────────────────────
wired, callerless, test_only, local_only = {}, [], [], []
LANE_RE = re.compile(r'^(test_.*|.*_lanes)\.sh$')
for p in population:
    hits = has_caller(p, runners)
    if hits:
        wired[p] = hits
        if all(LANE_RE.match(os.path.basename(h)) for h in hits):
            test_only.append(p)          # advisory: only a lane suite calls it
    else:
        callerless.append(p)
        if has_caller(p, LOCAL_ONLY_SURFACES):
            local_only.append(p)

undeclared = [p for p in callerless if p not in exempt and p not in baseline]
# 🟥 `resolved` MUST EXCLUDE LANE-ONLY. Measured cost of not doing so, twice:
#   · 2026-08-26 — this advisory told a session to delete scripts/chamber_candidate_collect.sh
#     from `baseline:`. Its only caller is a lane suite. A cross-family review caught it and the
#     line was restored WITH that history written into it. The tool gave advice that had to be
#     reverted by a human.
#   · 2026-08-30 — the same advisory fired again on the same file, and the only thing that stopped
#     a second deletion was that restored comment. A gate whose correctness depends on someone
#     having written a note last time is not a gate.
# `baseline:` means "owes a PRODUCTION caller". A lane calling it is an ANCHOR, not a discharge —
# this file already computes `test_only` for exactly that distinction and then did not use it here.
# Half-externalisation: the slot existed, the consumer did not
# ([[feedback_half_externalization_slot_without_consumer]]).
resolved   = sorted(p for p in baseline if p in wired and p not in test_only)
# Reported separately so "still lane-only" never silently reads as "still callerless".
baseline_lane_only = sorted(p for p in baseline if p in wired and p in test_only)
ghost      = sorted(p for p in list(exempt) + list(baseline) if not os.path.isfile(p))

print(json.dumps({
    'mode': MODE, 'list': LIST,
    'index_mode': INDEX_MODE, 'index_why': INDEX_WHY,
    'n_pop': len(population), 'n_runners': len(runners), 'n_decl': decl_lines,
    'wired': {k: v for k, v in wired.items()},
    'callerless': callerless, 'undeclared': undeclared,
    'exempt': sorted(p for p in callerless if p in exempt),
    'baseline': sorted(p for p in callerless if p in baseline),
    'test_only': sorted(test_only), 'local_only': sorted(local_only),
    'resolved': resolved, 'baseline_lane_only': baseline_lane_only, 'ghost': ghost,
    'placeholder': sorted(set(plist_placeholder_hits)),
    'err': err, 'ctrl': ctrl,
}))
PY
)
rc=$?
[ -n "${FH_INDEX_FILE_LIST:-}" ] && rm -f "$FH_INDEX_FILE_LIST"
if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
  echo "FAIL  caller-ratchet: the scan itself did not run (python3 exit $rc)."
  echo "      An instrument that did not run is UNMEASURED — this is not a pass."
  exit 2
fi

# Rendering is bash-side so the judgment above stays one pure function of the tree.
_j() { printf '%s' "$out" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d[sys.argv[1]] if not isinstance(d[sys.argv[1]],(list,dict)) else '\n'.join(d[sys.argv[1]]) if isinstance(d[sys.argv[1]],list) else '\n'.join(sorted(d[sys.argv[1]])))" "$1"; }

CTRL="$(_j ctrl)"
if [ -n "$CTRL" ]; then
  echo "FAIL  caller-ratchet: the instrument's own known pair collapsed —"
  printf '%s\n' "$CTRL" | sed 's/^/        · /'
  echo "      A scan that cannot separate a case whose answer is known is generating, not measuring."
  exit 2
fi

# 🟥 Ordered BEFORE the generic `err` render so the reason a reader sees is the true one. The
# state also rides in `err` (fail-closed if this branch is ever moved or deleted), but the err
# header says "declarations could not be read", which is a wrong diagnosis for a broken index.
if [ "$(_j index_mode)" = "UNMEASURED" ]; then
  echo "FAIL  caller-ratchet: the runner surface is UNMEASURED, not empty —"
  echo "        · $(_j index_why)"
  echo "      A scan that could not enumerate its own runner surface did not pass."
  exit 2
fi

ERRS="$(_j err)"
if [ -n "$ERRS" ]; then
  echo "FAIL  caller-ratchet: declarations could not be read as declarations —"
  printf '%s\n' "$ERRS" | sed 's/^/        · /'
  exit 2
fi

# Three-valued, printed rather than folded. `nongit` is CORRECT in an unpacked npm tarball
# (no index exists there) and WRONG inside a checkout; `empty` is routed through `err` above and
# has already exited 2 by the time this runs. Neither may ever read as "zero runners".
IDX_MODE="$(_j index_mode)"
case "$IDX_MODE" in
  nongit|outside-index)
    echo "      ⚠️  caller-ratchet: runner surface enumerated from DISK, not the index ($IDX_MODE)."
    echo "          $(_j index_why)"
    echo "          Correct outside a checkout, wrong inside one. Not zero runners either way."
    ;;
esac

N_POP="$(_j n_pop)"; N_RUN="$(_j n_runners)"
if [ "$N_POP" -eq 0 ] || [ "$N_RUN" -eq 0 ]; then
  echo "FAIL  caller-ratchet: scanned $N_POP scripts against $N_RUN runners under $ROOT."
  echo "      Zero is an instrument failure, not a clean tree."
  exit 2
fi

if [ "$MODE" = "emit" ]; then
  echo "# scripts/caller_zero_baseline.txt — generated by --print-baseline on $(date +%Y-%m-%d)."
  echo "# 🟥 EVERY LINE BELOW IS A DRAFT. Move it to exempt: (legitimately callerless) or leave it"
  echo "#    under baseline: (debt), and WRITE THE REASON. A line without one is rejected."
  echo "exempt:"
  echo "baseline:"
  printf '%s\n' "$(_j callerless)" | sed 's|^|  - |;s|$|   # TODO reason|'
  exit 0
fi

echo "      caller-ratchet: $N_POP non-lane scripts · $N_RUN runner surfaces · $(_j n_decl) declarations"
echo "      caller-ratchet: WIRED $(printf '%s' "$out" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["wired"]))') · EXEMPT $(_j exempt | grep -c . || true) · BASELINE $(_j baseline | grep -c . || true) · UNDECLARED $(_j undeclared | grep -c . || true)"

TESTONLY="$(_j test_only)"
[ -n "$TESTONLY" ] && { echo "      ⚠️  called ONLY by a lane suite — an anchor exists, production wiring does not:"; printf '%s\n' "$TESTONLY" | sed 's/^/           /'; }
LOCALONLY="$(_j local_only)"
[ -n "$LOCALONLY" ] && { echo "      ⚠️  dispatched ONLY from the gitignored .claude/settings.json — wired on this machine,"; echo "          callerless for CI and for every consumer:"; printf '%s\n' "$LOCALONLY" | sed 's/^/           /'; }
RESOLVED="$(_j resolved)"
[ -n "$RESOLVED" ] && { echo "      ⚠️  baseline entry now WIRED by a PRODUCTION caller — shrink-only, delete these lines:"; printf '%s\n' "$RESOLVED" | sed 's/^/           /'; }
BLO="$(_j baseline_lane_only)"
[ -n "$BLO" ] && { echo "      ℹ️  baseline entry has a LANE caller but still no production one — the line STAYS:"; printf '%s\n' "$BLO" | sed 's/^/           /'; echo "          (an anchor is not a discharge; deleting these was refuted by review on 2026-08-26)"; }
GHOST="$(_j ghost)"
[ -n "$GHOST" ] && { echo "      ⚠️  declared but the file does not exist (renamed/deleted?):"; printf '%s\n' "$GHOST" | sed 's/^/           /'; }
PLACEHOLDER="$(_j placeholder)"
[ -n "$PLACEHOLDER" ] && { echo "      ⚠️  a plist NAMES this script but on a PLACEHOLDER path launchd cannot execute —"; echo "          the name is present, the dispatch is not:"; printf '%s\n' "$PLACEHOLDER" | sed 's/^/           /'; }

if [ "$LIST" -eq 1 ]; then
  echo "      -- callerless, declared --"
  printf '%s\n' "$(_j exempt)" | sed '/^$/d;s/^/         EXEMPT   /'
  printf '%s\n' "$(_j baseline)" | sed '/^$/d;s/^/         BASELINE /'
fi

# ── SHRINK-ONLY ENFORCEMENT ON `baseline:` ────────────────────────────────────────────────────
# Three-valued on purpose. "I could not compare" and "I compared and found nothing" are different
# facts, and collapsing the first into the second is how a gate reports a clean tree while blind
# ([[feedback_not_found_is_not_zero_family]]). The state is printed on EVERY run, including in the
# PASS line, so an UNMEASURED run can never be quoted as evidence that the list did not grow.
# 🟥 FOUR-VALUED, and WORKTREE_ONLY is the value a cross-family review had to add.
#   ENFORCED       compared against a commit that is NOT HEAD — full power over committed changes
#   WORKTREE_ONLY  the base resolved to HEAD itself. The diff then compares HEAD against the WORKING
#                  TREE, so it still catches an uncommitted new `baseline:` line (that is the
#                  pre-commit / developer case, and it is genuinely useful) but it has ZERO power
#                  over anything already committed — against a clean tree it is vacuous, because
#                  "nothing was added relative to myself" is true by construction.
#   BOOTSTRAP      the baseline file does not exist at the base — this change introduces it
#   UNMEASURED     no base at all
# Reproduced 2026-08-22 (cross-family, codex/gpt-5.5) on the surface that matters: a `push` to main
# leaves GITHUB_BASE_REF unset, `origin/main` resolves to the checked-out HEAD, and a commit carrying
# BOTH a new callerless script AND its new `baseline:` line exited 0 while printing
# "shrink-only ENFORCED". The word ENFORCED was doing the damage: the run had measured nothing and
# said it had. Same shape on a detached or shallow checkout.
SHRINK_STATE="UNMEASURED"
SHRINK_WHY="not determined"
SHRINK_ADDED=""
SELF_COMPARE=0

_resolve_base() {
  # Ordered by how specific the signal is. GITHUB_BASE_REF is set only on pull_request events and
  # names the branch being merged INTO, which is exactly the comparison this gate wants.
  for _cand in ${GITHUB_BASE_REF:+"origin/$GITHUB_BASE_REF" "$GITHUB_BASE_REF"} origin/main main origin/master master; do
    _o=$(git -C "$ROOT" merge-base HEAD "$_cand" 2>/dev/null)
    _r=$?
    if [ "$_r" -eq 0 ] && [ -n "$_o" ]; then printf '%s' "$_o"; return 0; fi
  done
  return 1
}

if ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  SHRINK_WHY="$ROOT is not a git work tree, so there is no previous state to diff against"
else
  # 🟥 `out=$(...)` then `rc=$?` on its own line — an empty HEAD_SHA must stay empty rather than
  # being papered over by a fallback, because an empty HEAD_SHA would make the `=` test below
  # false and silently restore the ENFORCED label this whole block exists to withhold.
  HEAD_SHA=$(git -C "$ROOT" rev-parse --verify --quiet 'HEAD^{commit}')
  _rh=$?
  [ "$_rh" -eq 0 ] || HEAD_SHA=""
  if [ -n "${FH_RATCHET_BASE_REF:-}" ]; then
    # 🟥 An explicitly named base that does not resolve is exit 2 — NEVER a silent fall-through to
    # auto-detection, and never a labelled UNMEASURED. The caller stated which comparison they
    # wanted; quietly substituting a different one (or none) would hand back a verdict about a
    # question nobody asked, which is the failure mode where an instrument answers confidently
    # about the wrong target.
    BASE_SHA=$(git -C "$ROOT" rev-parse --verify --quiet "${FH_RATCHET_BASE_REF}^{commit}")
    _rb=$?
    if [ "$_rb" -ne 0 ] || [ -z "$BASE_SHA" ]; then
      echo "FAIL  caller-ratchet: --base / FH_RATCHET_BASE_REF names '${FH_RATCHET_BASE_REF}',"
      echo "      which does not resolve to a commit in $ROOT. An explicitly requested comparison"
      echo "      that could not be made is an instrument error, not a pass."
      exit 2
    fi
  else
    BASE_SHA="$(_resolve_base)"
    _rb=$?
  fi
  if [ "$_rb" -ne 0 ] || [ -z "$BASE_SHA" ]; then
    SHRINK_WHY="no base commit resolvable (tried FH_RATCHET_BASE_REF, \$GITHUB_BASE_REF, origin/main, main, origin/master, master — a depth-1 clone has none)"
  else
    # The self-comparison test, computed BEFORE the diff so it labels every branch below —
    # including BOOTSTRAP, where "the file is absent at base" and "the base is myself" can be true
    # at once (an untracked baseline file) and the pair of them is not a measurement either.
    if [ -n "$HEAD_SHA" ] && [ "$BASE_SHA" = "$HEAD_SHA" ]; then
      SELF_COMPARE=1
    fi
    BASE_TMP="$(mktemp)"
    git -C "$ROOT" show "$BASE_SHA:$BASELINE_FILE" > "$BASE_TMP" 2>/dev/null
    _rs=$?
    if [ "$_rs" -ne 0 ]; then
      SHRINK_STATE="BOOTSTRAP"
      SHRINK_WHY="$BASELINE_FILE does not exist at base ${BASE_SHA} — this is the change that introduces it"
    else
      # Same line grammar as the declaration parser above, deliberately duplicated in ONE place
      # (here) rather than shared through a third file: two normalizers with different leniency is
      # a logged defect in this repo, so the rule is that if this grammar ever diverges from the
      # parser above, lane L15b (an entry the main parser accepts) goes red and names it.
      SHRINK_ADDED=$(python3 - "$BASE_TMP" "$BASELINE_FILE" <<'PY'
import re, sys

def baseline_paths(path):
    try:
        txt = open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return None
    sect, out = None, set()
    for raw in txt.split('\n'):
        s = raw.rstrip()
        if not s.strip() or s.lstrip().startswith('#'):
            continue
        m = re.match(r'^([A-Za-z_]+):\s*$', s)
        if m:
            sect = m.group(1)
            continue
        m = re.match(r'^\s+-\s+(\S+)', s)
        if m and sect == 'baseline':
            out.add(m.group(1))
    return out

base = baseline_paths(sys.argv[1])
cur = baseline_paths(sys.argv[2])
if base is None or cur is None:
    sys.exit(3)
for p in sorted(cur - base):
    print(p)
PY
)
      _rp=$?
      if [ "$_rp" -ne 0 ]; then
        rm -f "$BASE_TMP"
        echo "FAIL  caller-ratchet: the shrink-only diff itself did not run (python3 exit $_rp)."
        echo "      An instrument that did not run is UNMEASURED — this is not a pass."
        exit 2
      fi
      if [ "$SELF_COMPARE" -eq 1 ]; then
        SHRINK_STATE="WORKTREE_ONLY"
        SHRINK_WHY="the resolved base IS HEAD (${BASE_SHA}); only UNCOMMITTED edits to $BASELINE_FILE are visible"
      else
        SHRINK_STATE="ENFORCED"
        SHRINK_WHY="base ${BASE_SHA}"
      fi
    fi
    rm -f "$BASE_TMP"
  fi
fi

FAILED=0

# ── DEGRADE-CLOSED CHECK, BEFORE ANY VERDICT IS ISSUED ────────────────────────────────────────
# 🟥 Ordered first on purpose. If the comparison could not be made, or was made against HEAD
# itself, the run must not go on to publish a verdict about it — a verdict from a base nobody can
# trust is the "instrument answers confidently about the wrong target" failure, and exit 2
# (instrument error) is the honest code for it, not exit 0 and not exit 1.
# SELF_COMPARE is checked independently of the state so that a BOOTSTRAP-at-HEAD (an UNTRACKED
# baseline file in CI) is caught by the same line rather than slipping through the state name.
if [ "${FH_RATCHET_REQUIRE_BASE:-0}" = "1" ] && \
   { [ "$SHRINK_STATE" = "UNMEASURED" ] || [ "$SELF_COMPARE" -eq 1 ]; }; then
  echo "FAIL  caller-ratchet: FH_RATCHET_REQUIRE_BASE=1 and the base is not a usable comparison"
  echo "      (state: $SHRINK_STATE) — $SHRINK_WHY"
  echo "      This surface degrades CLOSED. Comparing a commit against ITSELF can never show growth,"
  echo "      so a pass from it would be vacuous. Fetch history (actions/checkout fetch-depth: 0) and"
  echo "      name an IMMUTABLE base via --base / FH_RATCHET_BASE_REF:"
  echo "        pull_request  ->  github.event.pull_request.base.sha"
  echo "        push          ->  github.event.before   (or HEAD~1 when that is all-zeros)"
  exit 2
fi

case "$SHRINK_STATE" in
  ENFORCED|WORKTREE_ONLY)
    if [ -n "$SHRINK_ADDED" ]; then
      echo "FAIL  caller-ratchet: NEW entries under \`baseline:\` — that section is SHRINK-ONLY —"
      printf '%s\n' "$SHRINK_ADDED" | sed 's/^/        · /'
      echo "      Compared against $SHRINK_WHY."
      echo "      baseline: is grandfathered debt, measured once. A path that was not already there"
      echo "      is regrowth, and stopping regrowth is the entire purpose of this ratchet. Legal:"
      echo "        ① wire it · ② move it to exempt: with the reason it needs no caller · ③ delete it"
      echo "      Deleting a baseline: line, or moving one from baseline: to exempt:, always passes."
      FAILED=1
    elif [ "$SHRINK_STATE" = "ENFORCED" ]; then
      echo "      caller-ratchet: shrink-only ENFORCED — no new \`baseline:\` entry vs $SHRINK_WHY"
    else
      # 🟥 NOT the word ENFORCED, and not merely a softer adjective on the same sentence. A run
      # that compared HEAD with itself found nothing because there was nothing it COULD find.
      echo "      ⚠️  caller-ratchet: shrink-only WORKTREE_ONLY — $SHRINK_WHY"
      echo "          A baseline: entry that is already COMMITTED would NOT be caught by this run."
      echo "          At a merge boundary set FH_RATCHET_REQUIRE_BASE=1 and name a real base."
    fi
    ;;
  BOOTSTRAP)
    echo "      ⚠️  caller-ratchet: shrink-only NOT JUDGED — $SHRINK_WHY"
    ;;
  *)
    echo "      ⚠️  caller-ratchet: shrink-only UNMEASURED — $SHRINK_WHY"
    echo "          A new \`baseline:\` entry would NOT be caught by this run. Unmeasured is not zero."
    # The FH_RATCHET_REQUIRE_BASE=1 exit for this state used to live HERE. It was moved above the
    # case (and widened to cover WORKTREE_ONLY / SELF_COMPARE) and DELETED from here rather than
    # left in place: two copies of one degrade rule is a place for them to diverge in silence, and
    # the second copy is unreachable, so it would diverge without anything going red.
    ;;
esac

UNDECL="$(_j undeclared)"
if [ -n "$UNDECL" ]; then
  echo "FAIL  caller-ratchet: script(s) with ZERO callers and no declaration —"
  printf '%s\n' "$UNDECL" | sed 's/^/        · /'
  echo "      Fix by ONE of:"
  echo "        ① wire it — a runner surface must dispatch it (script · git hook · CI workflow ·"
  echo "           package.json · bin/*.js · a tracked templates/ settings snippet)"
  echo "        ② declare it EXEMPT in $BASELINE_FILE with the reason it needs no caller"
  echo "        ③ delete it — an unwired script is a claim the repo cannot honour"
  echo "      Adding it under baseline: is NOT one of the options — and as of 2026-08-22 that is"
  echo "      enforced, not merely written here: the section is diffed against the base commit."
  FAILED=1
fi

[ "$FAILED" -eq 0 ] || exit 1

if [ "$SHRINK_STATE" = "ENFORCED" ]; then
  echo "PASS  caller-ratchet: no undeclared zero-caller script; \`baseline:\` did not grow."
else
  echo "PASS  caller-ratchet: no undeclared zero-caller script (shrink-only: $SHRINK_STATE)."
fi
exit 0
