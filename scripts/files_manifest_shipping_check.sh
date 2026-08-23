#!/usr/bin/env bash
# files_manifest_shipping_check.sh — every path package.json declares in files[] must actually
# exist on disk AND actually land in the real npm tarball.
#
# WHY THIS EXISTS (gap named but not closed elsewhere, found 2026-08-23):
# `package_coverage_check.sh` walks REFERENCES — a shipped doc names a path, does that path ship —
# but it never iterates package.json's files[] array itself. `selfcheck.sh` (~:1065) says so in its
# own comment: "measured 2026-08-09, package_coverage_check.sh returns PASS on a files[] entry whose
# file does not exist, so a deleted subject would be green on every surface (SKIP here + PASS there
# + npm silently omitting it)." selfcheck.sh works around this for a HANDFUL of hand-picked subjects
# (branch_claim.sh, marker axes lanes, sidecar_calibrate.sh, ...), each guarded by its own
# `if [ ! -f ... ]` block, and its own comment names the remainder as a residual: "the sibling blocks
# above carry the same hole for their own shipped subjects. Fixing them is a separate change."
# This script is that separate change, done ONCE for the full 200+-entry list instead of per-subject.
#
# TWO FAILURE SHAPES THIS CATCHES, NEITHER CAUGHT ELSEWHERE:
#   (a) a files[] entry whose file was deleted (rename, cleanup, a stale exception) but the
#       declaration was never removed — package_coverage_check.sh reads files[] as a coverage
#       ORACLE, so an entry naming nothing is invisible to it by construction.
#   (b) a files[] entry that exists on disk but does not actually pack — .npmignore precedence,
#       a directory that npm's own default-ignore rules (e.g. nested .git, node_modules) hollow
#       out, or a git-tracked file under a declared DIRECTORY that silently fails to tar. This is
#       the disk-vs-declaration gap the tarball oracle in package_coverage_check.sh was built to
#       close for referenced paths; this script applies the same tarball oracle to files[] itself.
#
# SCOPE (deliberately narrow — see cross-family review 2026-08-23): this checks LITERAL paths only.
# It does NOT resolve npm glob patterns (`dist/*.js`) or normalize a leading `./` beyond a literal
# strip — an entry containing glob metacharacters is reported as OUT-OF-SCOPE, never as phantom or
# unpacked, because this script cannot know what a glob resolves to without re-implementing npm's
# own pattern matcher. Widening to real glob support is a scope increase, not a bug fix; it is
# deliberately left undone rather than guessed at.
#
# Usage:  bash scripts/files_manifest_shipping_check.sh              # disk-existence only, offline
#         bash scripts/files_manifest_shipping_check.sh --vs-tarball # + real `npm pack` check
# Exit:   0 = every files[] entry exists on disk (and, with --vs-tarball, ships in the real
#             tarball); 1 = at least one entry is a phantom declaration or an oracle failure.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || { echo "FAIL: cannot cd to repo root"; exit 1; }

# Argument validation FIRST, before anything else can silently downgrade behavior. An unrecognized
# argument (e.g. a `--vs-tarbll` typo) used to fall through to the declaration-mode default, which
# on the publish path (the ONLY caller of --vs-tarball, see prepublishOnly) means "I asked for the
# strict tarball oracle and silently got the weak one instead" — a false PASS on exactly the surface
# this script exists to guard. Unrecognized input is now a hard error, not a silent mode switch.
if [ -n "${1:-}" ] && [ "${1:-}" != "--vs-tarball" ]; then
  echo "FAIL  files-manifest-shipping: unrecognized argument '${1}' — did you mean --vs-tarball?"
  echo "      Refusing to silently fall back to a weaker check mode."
  exit 1
fi
MODE="declaration"
if [ "${1:-}" = "--vs-tarball" ]; then
  MODE="tarball"
fi

if [ ! -f package.json ]; then
  echo "FAIL  files-manifest-shipping: no package.json at repo root — declared coverage is"
  echo "      UNMEASURED, not clean"
  exit 1
fi
command -v node >/dev/null 2>&1 || {
  echo "FAIL  files-manifest-shipping: node unavailable — files[] cannot be read"; exit 1; }

# Source-tree predicate, same idea package_coverage_check.sh uses: an installed package has no
# comparable files[] to self-audit against (it IS the audited output, not the declaration).
#
# BUT the degrade direction differs BY MODE, and that split is deliberate (cross-family review
# 2026-08-23, S1). `--vs-tarball` has exactly one caller in this repo: prepublishOnly. There is no
# legitimate "installed package" scenario on that path — `npm publish`/`npm pack` only make sense
# run from the source checkout that IS being published, so a missing `.git` there means the
# environment is not what the publish path expects, not that the check has nothing to do. Per the
# Irreversibility Surface-Class Degrade Invariant (CLAUDE.md): an irreversible surface (publish)
# fails CLOSED when its tooling/environment is off-shape, it does not get a free skip. Declaration
# mode keeps the original SKIP — it runs from more places (e.g. a routine sweep against an
# installed/vendored copy) where "no .git" genuinely does mean "nothing comparable to check".
if [ ! -d .git ] && [ ! -f .git ]; then
  if [ "$MODE" = "tarball" ]; then
    echo "FAIL  files-manifest-shipping (--vs-tarball): no .git at repo root on the publish path —"
    echo "      this check has exactly one caller (prepublishOnly) and it always runs from the"
    echo "      source checkout being published. Fail-closed: an off-shape publish environment is"
    echo "      not a legitimate reason to skip an irreversible-surface check."
    exit 1
  fi
  echo "SKIP  files-manifest-shipping (no .git — looks like an installed package, not a source checkout)"
  exit 0
fi

echo "files-manifest shipping check ($MODE)"

if [ "$MODE" = "tarball" ]; then
  command -v npm >/dev/null 2>&1 || {
    echo "FAIL  files-manifest-shipping (--vs-tarball): npm is not on PATH — the tarball oracle is"
    echo "      UNAVAILABLE. Fail-closed: this is an irreversible-surface check (publish path), and"
    echo "      an unreadable oracle must never render as pass."
    exit 1
  }
  # git is also required for the tarball-mode directory walk (walkTracked, below, via `git
  # ls-files`). Checked here rather than left to fail mid-walk so a missing binary renders as an
  # explicit instrument-unavailable FAIL, not as a per-directory "zero tracked files" phantom
  # (cross-family review 2026-08-23, A4: a `git ls-files` failure must never be reported as if the
  # TARGET were empty — it means the INSTRUMENT could not look).
  command -v git >/dev/null 2>&1 || {
    echo "FAIL  files-manifest-shipping (--vs-tarball): git is not on PATH — the declared-directory"
    echo "      tracked-file walk is UNAVAILABLE. Fail-closed, same reasoning as the npm check above."
    exit 1
  }
fi

# Scratch directory, not a predictable /tmp/*.$$ filename. A predictable per-PID temp path is
# guessable and writable by any other local process before this one gets to read it back (cross-
# family review 2026-08-23, A2). `mktemp -d` gives a directory only this process's owner can see
# (mode 0700 by default on both GNU and BSD mktemp), and every write into it below is check-marked —
# a write that silently failed used to be indistinguishable from "nothing to report".
FMSC_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fmsc.XXXXXXXX")" || {
  echo "FAIL  files-manifest-shipping: mktemp -d failed — cannot allocate a private scratch dir"
  exit 1
}
trap 'rm -rf "$FMSC_DIR"' EXIT
FMSC_JS="$FMSC_DIR/check.js"
FMSC_PACK_JSON="$FMSC_DIR/pack.json"
FMSC_PACK_ERR="$FMSC_DIR/pack.err"

if [ "$MODE" = "tarball" ]; then
  PACK_JSON=$(npm pack --dry-run --json 2>"$FMSC_PACK_ERR")
  PACK_RC=$?
  if [ "$PACK_RC" -ne 0 ] || [ -z "$PACK_JSON" ]; then
    echo "FAIL  files-manifest-shipping (--vs-tarball): npm pack exited $PACK_RC — tarball UNKNOWN"
    sed 's/^/      /' "$FMSC_PACK_ERR" 2>/dev/null
    exit 1
  fi
  printf '%s' "$PACK_JSON" > "$FMSC_PACK_JSON" || {
    echo "FAIL  files-manifest-shipping (--vs-tarball): could not write pack output to scratch dir"
    exit 1
  }
fi

# bash 3.2 (macOS system bash) has a documented heredoc-inside-command-substitution bug: a quoted
# heredoc (`<<'NODE'`) body containing single quotes can still desync `$( ... )`'s own quote count,
# producing a false "unexpected EOF" parse error even though the heredoc itself is syntactically
# correct. Writing the JS to a real file and invoking it by path sidesteps the bug entirely.
cat > "$FMSC_JS" <<'NODE'
const fs = require('fs');

const mode = process.argv[2];
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));

// Malformed `files` field must FAIL, not silently coerce to an empty/single-entry list (cross-
// family review 2026-08-23, A1: `pkg.files || []` let `"files": "."` pass as "1 entry checked").
// npm's own contract is that `files` is an array of path/glob strings; anything else is an invalid
// manifest, and an invalid manifest is not a clean result.
if (pkg.files !== undefined && !Array.isArray(pkg.files)) {
  console.log(`FAIL\tpackage.json files[] is not an array (got ${typeof pkg.files}) — invalid`
    + ' manifest, not a clean result');
  process.exit(1);
}
const declared = pkg.files || [];

if (declared.length === 0) {
  console.log('FAIL\tpackage.json files[] is EMPTY or missing — that is not a clean result, it is an\n\tinstrument that found nothing to check');
  process.exit(1);
}

// Line-protocol sanitizer: every string emitted below goes through this first. Without it, a path
// containing a literal newline (attacker-controlled files[] entry, or a corrupted manifest) can
// inject a line that itself starts with "PASS" or another verdict token, which a naive human or
// grep-based reader downstream could mistake for the real verdict (cross-family review 2026-08-23,
// A3). JSON.stringify turns any control character, including \n and \t, into a visible escape and
// wraps the value in quotes, so an injected line can never masquerade as line-protocol output.
function safe(s) { return JSON.stringify(s); }

// SCOPE GUARD (cross-family review 2026-08-23, B1/B2): this script checks LITERAL paths only. An
// entry containing npm glob metacharacters cannot be resolved to a real filesystem path without
// re-implementing npm's own matcher, so treating a glob as a literal-and-missing path is a false
// PHANTOM, not a scope limitation being honest about itself. `./`-prefixed entries are npm's own
// documented way of writing a literal (npm strips the prefix when building the tarball), so THAT
// case is safe to normalize rather than punt out of scope.
const GLOB_RE = /[*?{}\[\]]/;
function normalizeLiteral(entry) {
  return entry.startsWith('./') ? entry.slice(2) : entry;
}

let tarballSet = null;
if (mode === 'tarball') {
  const packPath = process.argv[3];
  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(packPath, 'utf8'));
  } catch (e) {
    console.log(`FAIL\tnpm pack --json did not parse (${e.constructor.name}) — tarball UNKNOWN`);
    process.exit(1);
  }
  const entry = Array.isArray(parsed) ? parsed[0] : null;
  const list = entry && Array.isArray(entry.files) ? entry.files : null;
  if (!list || list.length === 0) {
    // Impossible-zero guard, same rule package_coverage_check.sh applies to this same oracle:
    // a genuinely empty tarball means the instrument broke, not that the package shrank to nothing.
    console.log(`FAIL\tnpm pack reported ${list ? list.length : 0} files — implausible, oracle UNAVAILABLE`);
    process.exit(1);
  }
  // Below-threshold is now an ADVISORY, not an automatic FAIL (cross-family review 2026-08-23, B3:
  // a legitimately tiny package — package.json + README + LICENSE + one file — used to hard-fail on
  // count alone). A near-empty tarball is still worth a human's eyes, so it is surfaced as its own
  // line-protocol kind rather than silently accepted, but it no longer blocks by itself; only the
  // phantom/unpacked findings computed below can still FAIL the run.
  if (list.length < 10) {
    console.log(`ADVISORY\tnpm pack reported only ${list.length} files — small package, or a`
      + ' shrunk oracle. Not auto-failed; verify by eye if this package is not meant to be tiny.');
  }
  tarballSet = new Set(list.map(f => normalizeLiteral(f.path)));
}

function walkTracked(dir) {
  // git-tracked descendants only — untracked/gitignored files under a declared directory are not
  // this check's business (they are correctly absent from both git and the tarball).
  //
  // INSTRUMENT FAILURE vs TARGET EMPTY (cross-family review 2026-08-23, A4): the git binary itself
  // is checked for availability before this function is ever called (bash side, above), so an error
  // reaching here means `git ls-files` itself failed against a directory that IS tracked in git
  // (the .git-presence check upstream already established this is a real git checkout) — a
  // corrupted index, a pathspec git rejects, or similar. That is the INSTRUMENT breaking, not the
  // target having zero files, so it must not be folded into "zero tracked files" and reported as a
  // phantom declared-directory. It throws instead, and the caller renders it as its own kind.
  const { execFileSync } = require('child_process');
  return execFileSync('git', ['ls-files', '--', dir], { encoding: 'utf8' })
    .split('\n').filter(Boolean);
}

const phantoms = [];    // declared, absent on disk
const unpacked = [];    // exists on disk, declared, but did not make the real tarball (tarball mode only)
const outOfScope = [];  // glob entry — this checker does not resolve glob patterns
const instrumentErrors = []; // the oracle itself failed while examining a specific entry

for (const rawEntry of declared) {
  if (typeof rawEntry !== 'string') {
    instrumentErrors.push(`non-string files[] entry: ${safe(rawEntry)}`);
    continue;
  }
  if (GLOB_RE.test(rawEntry)) {
    outOfScope.push(rawEntry);
    continue;
  }
  const entry = normalizeLiteral(rawEntry);
  let stat;
  try {
    stat = fs.statSync(entry);
  } catch (e) {
    phantoms.push(rawEntry);
    continue;
  }
  if (mode !== 'tarball') continue;

  if (stat.isDirectory()) {
    let tracked;
    try {
      tracked = walkTracked(entry);
    } catch (e) {
      instrumentErrors.push(`git ls-files failed for declared dir '${rawEntry}': ${e.message}`);
      continue;
    }
    if (tracked.length === 0) {
      // A declared directory with zero git-tracked files under it is its own phantom shape —
      // shipping an empty directory declaration gives the consumer nothing either way. This is
      // reached only when `git ls-files` itself SUCCEEDED and reported nothing, so it is a real
      // target finding, not an instrument failure (see walkTracked's comment above).
      phantoms.push(rawEntry + '/ (declared directory, zero git-tracked files under it)');
      continue;
    }
    for (const t of tracked) {
      if (!tarballSet.has(normalizeLiteral(t))) unpacked.push(t + '  (under declared dir ' + rawEntry + ')');
    }
  } else {
    if (!tarballSet.has(entry)) unpacked.push(rawEntry);
  }
}

const hasFailure = phantoms.length > 0 || unpacked.length > 0 || instrumentErrors.length > 0;

if (!hasFailure) {
  const scopeNote = outOfScope.length > 0 ? `, ${outOfScope.length} out-of-scope (glob)` : '';
  console.log(`PASS\t${declared.length} files[] entries checked, 0 phantom, 0 unpacked${scopeNote}`);
  process.exit(0);
}

for (const s of outOfScope) console.log('SCOPE\t' + safe(s));
for (const p of phantoms) console.log('PHANTOM\t' + safe(p));
for (const u of unpacked) console.log('UNPACKED\t' + safe(u));
for (const ie of instrumentErrors) console.log('INSTRUMENT-ERROR\t' + ie);
console.log(`FAIL\t${phantoms.length} phantom declaration(s), ${unpacked.length} declared-but-unpacked`
  + ` path(s), ${instrumentErrors.length} instrument error(s)`);
process.exit(1)
NODE

if [ "$MODE" = "tarball" ]; then
  RESULT=$(node "$FMSC_JS" "$MODE" "$FMSC_PACK_JSON")
else
  RESULT=$(node "$FMSC_JS" "$MODE")
fi
RC=$?

echo "$RESULT" | while IFS=$'\t' read -r kind detail; do
  case "$kind" in
    PASS)             echo "PASS  files-manifest-shipping: $detail" ;;
    ADVISORY)         echo "  ⚠️  $detail" ;;
    FAIL)             printf 'FAIL  files-manifest-shipping: %s\n' "$detail" ;;
    SCOPE)            echo "  ⏭️  out of scope (glob pattern, not resolved): $detail" ;;
    PHANTOM)          echo "  ❌ declared in files[] but ABSENT on disk: $detail" ;;
    UNPACKED)         echo "  ❌ declared, present on disk, but NOT in the real npm tarball: $detail" ;;
    INSTRUMENT-ERROR) echo "  🛑 instrument failure examining this entry (target unproven, not clean): $detail" ;;
    *)                echo "$kind	$detail" ;;
  esac
done

exit "$RC"
