#!/usr/bin/env bash
# new_code_anchor_check.sh — a NEWLY ADDED executable must not ship with zero lanes exercising it.
#
# provenance: transplanted 2026-08-22 from qasp's `new-code-anchor` CI job via the door-④ synergy
#   scan (`tracks/_meta/synergy_scan_2026-08-22.md`, pair T3). Origin incident there: 123 tests
#   green, and not one of them touched the file the PR added. The aggregate was green; the new file
#   was unmeasured. FH has named that failure class for itself ever since
#   [[feedback_anchor_can_be_decorative]] — «앵커가 장식일 수 있다» — but had no gate on it.
#   The outward pass (Step 3-c) found the mainstream name for the shape: **diff / patch coverage**.
#   This is that pattern, spelled for a shell-centric repo where "test" means a lane suite.
#
# ── WHAT THIS IS NOT — the bookshelf, checked before building (no-reinvention) ────────────────
#   scripts/lane_runner_check.sh   asks the INVERSE question: "does anything RUN this lane suite?"
#       (subject = the lane; it globs `test_*.sh` / `*_lanes.sh` and looks for a runner). A brand
#       new `scripts/foo.sh` with no lane at all is invisible to it — there is no suite to be
#       unwired. The two checks are mirror images and neither substitutes for the other.
#   scripts/selfcheck.sh           carries a `subject|anchor` pair table — the right DIRECTION, but
#       HAND-CURATED. Adding a new script does not add a row, so nothing goes red. This check is
#       what makes that table's omissions visible; it does not replace it.
#   scripts/package_coverage_check.sh  is SHIPPING coverage (does a referenced path make the
#       tarball), not test coverage.
#   scripts/gate_anchor_check.sh   is a known-pair harness for the git HOOKS specifically.
#   .github/workflows/regression-guard.yml  is Axis 1, `paths:`-filtered to docs/rules.
#   ⇒ Nothing in the repo asked "is this NEW executable exercised by anything". That is the hole.
#
# ── THE TRAP THIS FILE IS BUILT AROUND: anchor EXISTENCE ≠ anchor OPERATION ───────────────────
# The cheap version of this check greps the lane corpus for the new file's name and passes on a
# hit. That version certifies its own decoration: a name inside a comment, inside a grep PATTERN,
# inside an echoed string, or inside `bash -n` (a SYNTAX check — this repo has measured that
# `bash -n` passes a runtime bad-substitution that leaves the gate fail-open,
# [[feedback_gate_verification_must_execute]]) all satisfy "the name appears" and none of them
# execute one line of the subject. So a mention is reported as its own verdict, MENTION_ONLY, and
# MENTION_ONLY BLOCKS — loudly, and by a different name than "no anchor at all", because the two
# send a reader to different places.
# 🟥 HONEST CEILING, stated here rather than implied: this scans LINES, it does not parse shell.
# See §NAMED RESIDUALS at the bottom. It is strictly stronger than a name grep and strictly weaker
# than execution tracing, and it says so instead of claiming the strong form.
#
# ── SCOPE: the diff, not the repo ────────────────────────────────────────────────────────────
# Only files ADDED between the base ref and HEAD are in scope. Everything already in the tree is
# grandfathered on purpose: a gate that opens red on 80 pre-existing files is not a strict gate,
# it is a bypass trainer (this repo has logged that trade — [[feedback_overblock_traded_for_failopen]]).
#
# Usage:  bash scripts/new_code_anchor_check.sh [--list-exempt]
# Env:    NEW_CODE_ANCHOR_BASE=<ref|sha>   base to diff against (CI passes the PR base sha)
#         NEW_CODE_ANCHOR_OK=1             explicit, LOGGED operator override
# Exit:   0 = every added in-scope file is anchored, exempt, or there were none
#         1 = an added file ships with no working anchor (NO_ANCHOR or MENTION_ONLY)
#        10 = the instrument could not measure (no resolvable base, git unavailable, no python3).
#             10 IS NOT A PASS. Unmeasured is not zero — [[feedback_not_found_is_not_zero_family]].
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 10

# ── EXEMPT — an added file that legitimately CANNOT have a lane, with the reason ──────────────
# Same discipline as package_coverage_check.sh's ACCEPTED_ABSENT and lane_runner_check.sh's EXEMPT:
# if you cannot write the sentence, the file probably needs a lane instead of an entry here. The
# array lives in the CHECKER, not in the exempted file, on purpose — a self-declared exemption is
# a permission slip the beneficiary writes ([[feedback_declared_side_effect_is_unverified]]);
# putting it here forces the exemption into the checker's own diff, where a reviewer meets it.
#
# 🟥 FORMAT IS `path|reason`, AND THE REASON IS ENFORCED, NOT REQUESTED.
# The first version of this array was a bare string set whose comment said "with the reason" — the
# reason had no channel to live in, so the very first user would have satisfied a documented bar by
# typing a path, and the gate's own lane suite asserted a pass on an entry labelled "with a reason"
# that carried none. That is a rule lying about its own machinery
# ([[feedback_rule_misdescribes_its_own_machine]]), and it was found by cross-family review
# (codex, 2026-08-22), not here. A malformed entry now REFUSES to run — exit 10, HARNESS ERROR —
# rather than blocking or passing the code, because a checker configured wrong is not evidence in
# either direction ([[feedback_not_found_is_not_zero_family]]).
#   "scripts/foo.sh|generated by build.sh; running it rewrites the tree"     ← valid
#   "scripts/foo.sh"            ← refused, no reason channel used
#   "scripts/foo.sh|n/a"        ← refused, vacuous (MIN_REASON_CHARS below)
#   "foo.sh|<any reason>"       ← refused, BARE BASENAME (see below)
#
# 🟥 THE PATH IS A REPO-RELATIVE PATH, NOT A BASENAME — AND THAT IS ENFORCED (codex, 2026-08-22).
# The first version matched `subj in exempt or name in exempt`, so a bare-basename entry exempted
# EVERY file with that name in any directory: with `"fixture_subject.sh|<reason>"` declared, a newly
# added `scripts/nested/fixture_subject.sh` with zero anchors — and an EMPTY lane corpus — exited 0
# (reproduced here before the fix). That is a false PASS on a blocking gate reached by writing one
# plausible-looking config line.
# It was also DIVERGENT LENIENCY against the sibling gate: scripts/script_caller_ratchet.sh matches
# `path in exempt` exactly and additionally reports ghost entries, so one and the same file was
# exempt here and blocked there ([[feedback_divergent_leniency_duplicate_normalizers]] — two
# normalizers for one judgment means the input that only one of them accepts drops silently).
# A basename entry is now REFUSED (exit 10) rather than ignored: with the leniency removed it would
# otherwise become an inert line that the author reads as an active exemption.
#
# 🟥 WHICH HALF IS LOAD-BEARING — MEASURED BY REVERT PROBE, NOT ASSERTED. Two guards went in
# (exact-path matching at the classify site, and the refusal here), and reverting them one at a time
# says they are not equals:
#   · revert BOTH                      → lane X3 exits 0 — the original false PASS is back
#   · revert only the FATAL            → X3 exits 1: the file is correctly blocked, but the reader is
#                                        told "add a lane" about a config line that is the real fault
#   · revert only `name in exempt`     → NO lane changes (42/42 either way)
# So exact-path matching is what closes the false PASS, the refusal is what makes the diagnosis
# right, and the `or name in exempt` removal is unreachable belt-and-braces once the refusal stands —
# no lane can distinguish it, and this comment says so rather than letting a future reader assume the
# green covers it ([[feedback_anchor_can_be_decorative]]).
# The 12-character floor matches the sibling gate scripts/script_caller_ratchet.sh, deliberately:
# two thresholds for the same judgment in one repo is a coin-flip for whoever writes the next entry.
#
# EMPTY AT SHIP, and that is a measurement, not an oversight: this gate is diff-scoped, so on the
# commit that introduces it the in-scope set is only the files that commit adds.
EXEMPT=(
)

if [ "${1:-}" = "--list-exempt" ]; then
  printf '%s\n' "${EXEMPT[@]+"${EXEMPT[@]}"}"
  exit 0
fi

command -v git     >/dev/null 2>&1 || { echo "⛔ UNMEASURED: git not available"; exit 10; }
command -v python3 >/dev/null 2>&1 || { echo "⛔ UNMEASURED: python3 not available"; exit 10; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "⛔ UNMEASURED: not inside a git work tree"; exit 10; }

# ── BASE RESOLUTION — and the failure arm is 10, never "assume nothing was added" ─────────────
# An unresolvable base yields an EMPTY added-file set from `git diff`, which is byte-identical to
# "this change added nothing". Folding those together is the single most dangerous thing this
# script could do: every future PR would pass for the reason that the instrument was blind.
BASE=""
_base_src=""
if [ -n "${NEW_CODE_ANCHOR_BASE:-}" ]; then
  if git rev-parse --verify --quiet "${NEW_CODE_ANCHOR_BASE}^{commit}" >/dev/null; then
    BASE="$NEW_CODE_ANCHOR_BASE"; _base_src="NEW_CODE_ANCHOR_BASE"
  else
    echo "⛔ UNMEASURED: NEW_CODE_ANCHOR_BASE='${NEW_CODE_ANCHOR_BASE}' does not resolve to a commit."
    echo "   Refusing to fall back to a default base — a silently-substituted base measures a"
    echo "   different change than the one you asked about."
    exit 10
  fi
else
  for _cand in origin/main main origin/master master; do
    if git rev-parse --verify --quiet "${_cand}^{commit}" >/dev/null; then
      BASE="$_cand"; _base_src="auto:${_cand}"; break
    fi
  done
fi
if [ -z "$BASE" ]; then
  echo "⛔ UNMEASURED: no base ref resolved (tried NEW_CODE_ANCHOR_BASE, origin/main, main,"
  echo "   origin/master, master). Set NEW_CODE_ANCHOR_BASE=<ref> explicitly."
  echo "   This is exit 10, NOT a pass: an unresolvable base and an empty diff look identical."
  exit 10
fi

# merge-base, so a stale local main does not report every commit on main since your branch as
# "added by you". `--fork-point` is deliberately NOT used — it consults the reflog, which is empty
# on a CI checkout, so it answers differently on the two surfaces this gate runs on.
MB="$(git merge-base "$BASE" HEAD 2>/dev/null || true)"
if [ -z "$MB" ]; then
  echo "⛔ UNMEASURED: no merge-base between '$BASE' and HEAD (unrelated histories / shallow clone)."
  echo "   On CI use actions/checkout with fetch-depth: 0."
  exit 10
fi

ADDED="$(git diff --diff-filter=A --name-only "$MB" HEAD 2>/dev/null)"
_diff_rc=$?
if [ "$_diff_rc" -ne 0 ]; then
  echo "⛔ UNMEASURED: git diff failed (rc=$_diff_rc) against base '$BASE' ($MB)."
  exit 10
fi

# ── THE SCAN ─────────────────────────────────────────────────────────────────────────────────
# python3, not grep, and that is a portability decision with a measured precedent in this repo:
# a BRE `\t` means a literal `t` to GNU grep and a tab to BSD grep, which made a sibling check's
# fail-closed arm silently dead on the platform that gates merges (lane_runner_check.sh, 2026-08-13).
# This gate must answer identically on macOS (BSD, where it is authored) and Linux (GNU, where CI
# runs it), so the predicate lives somewhere that has one spelling.
#
# 🟥 THE HEREDOC BELOW IS **NOT** INSIDE A COMMAND SUBSTITUTION, AND THAT IS LOAD-BEARING.
# Measured here 2026-08-22 while writing this file: with the scan written as
# `out="$(... <<'PY' ... PY)"`, bash's close-paren-matching scan for the `$( )` wrapper is not
# fully heredoc-blind, so an ordinary unbalanced paren inside a PYTHON COMMENT broke the parse of
# the whole file — `bash -n` reported the failure ~270 lines later at an unrelated-looking spot.
# scripts/lane_runner_check.sh carries a paragraph on the identical trap (2026-08-14), which is
# how it was diagnosed in one step instead of by bisection. Redirecting to a temp file instead of
# capturing means no wrapper is scanning for a paren, so python comments can contain whatever they
# need to. Do not "simplify" this back into a `$(...)`.
#
# 🟥 THE FILE LIST GOES THROUGH THE ENVIRONMENT, NOT THROUGH A PIPE. `python3 -` reads the PROGRAM
# from stdin, so `printf … | python3 - <<'PY'` hands python the heredoc and leaves `sys.stdin.read()`
# empty — the scan then sees ZERO added files and prints a confident green. Measured here
# 2026-08-22: every known-positive lane passed the exit code but reported "added in scope: 0",
# i.e. the instrument was dead in the PASS direction while looking perfectly healthy. The lanes
# caught it because they assert the VERDICT LABEL and not only the exit code — asserting rc alone
# would have shipped this ([[feedback_broken_parser_reports_a_verdict]]).
_scan_out="$(mktemp 2>/dev/null)" || { echo "⛔ UNMEASURED: mktemp failed"; exit 10; }
NCA_ADDED="$ADDED" python3 - "${EXEMPT[@]+"${EXEMPT[@]}"}" > "$_scan_out" <<'PY'
import os, re, sys, glob

MIN_REASON_CHARS = 12

# ── EXEMPT PARSING — a malformed entry stops the run, it does not degrade to "not exempt" ──────
# Degrading to "not exempt" would look safe (the file blocks) and would be wrong for the reader:
# the author WOULD see a red gate, would read it as "my lane is missing", and would go add a
# decoration instead of fixing the entry. Refusing names the actual fault.
exempt = set()
_bad_exempt = []
for _e in sys.argv[1:]:
    if '|' not in _e:
        _bad_exempt.append((_e, 'no `|reason` — the entry names a path and no reason at all'))
        continue
    _p, _r = _e.split('|', 1)
    _p, _r = _p.strip(), _r.strip()
    if not _p:
        _bad_exempt.append((_e, 'empty path'))
    elif '/' not in _p:
        _bad_exempt.append((_e, 'bare basename — EXEMPT takes a repo-relative PATH. A basename '
                                'would exempt every file with that name in ANY directory, and the '
                                'sibling gate script_caller_ratchet.sh would still block it'))
    elif len(_r) < MIN_REASON_CHARS:
        _bad_exempt.append((_e, 'reason is %d chars, under the %d-char floor — write the sentence'
                                % (len(_r), MIN_REASON_CHARS)))
    else:
        exempt.add(_p)
if _bad_exempt:
    for _e, _why in _bad_exempt:
        print('FATAL_EXEMPT\t%s\t%s' % (_e, _why))
    sys.exit(4)

if 'NCA_ADDED' not in os.environ:
    # Fail LOUD, never silently empty. An absent variable and an empty change set are the same
    # bytes to `.get(…, '')`, and the empty one prints a green.
    print('FATAL\tNCA_ADDED unset — the file list never reached the scan')
    sys.exit(3)
added = [l.strip() for l in os.environ['NCA_ADDED'].split('\n') if l.strip()]

LANE_NAME = re.compile(r'^(test_.*|.*_lanes)\.(sh|py)$')

def is_lane(path):
    return LANE_NAME.match(os.path.basename(path)) is not None

# ── IN-SCOPE: what counts as "code" for this repo ─────────────────────────────────────────────
# Shell and python under scripts/, plus the git hooks in templates/. Deliberately NOT every
# executable in the tree: a scope claim wider than what the anchor corpus can actually cover would
# report coverage it does not have. Anything outside is reported as OUT_OF_SCOPE, by name, so a
# reader can see what the gate declined to judge rather than inferring a clean sheet from silence.
def in_scope(path):
    if is_lane(path):
        return False          # a lane IS an anchor; whether anything runs IT is lane_runner_check's question
    if path.startswith('scripts/') and path.endswith(('.sh', '.py')):
        return True
    if path.startswith('templates/.git-hooks/'):
        return True
    return False

subjects = [p for p in added if in_scope(p)]
skipped  = [p for p in added if not in_scope(p)]

# ── ANCHOR CORPUS ─────────────────────────────────────────────────────────────────────────────
lanes = sorted({p for p in glob.glob('scripts/**/*.sh', recursive=True) if is_lane(p)} |
               {p for p in glob.glob('scripts/**/*.py', recursive=True) if is_lane(p)})

# Runner surfaces — the same three lane_runner_check.sh enumerates, and enumerated for the same
# reason: they were checked by hand rather than assumed.
# 🟥 BOTH WORKFLOW SPELLINGS. GitHub accepts `.yml` and `.yaml`; this repo happens to use only
# `.yml`, which is exactly the condition under which the omission stays invisible here and blocks
# somebody else's PR ([[feedback_candidate_list_completeness]] — "we can't tell them apart" is not
# the same claim as "the candidate list is complete"). Found by cross-family review (agy, 2026-08-22).
runner_surfaces = []
for pat in ('scripts/*.sh', 'templates/.git-hooks/*',
            '.github/workflows/*.yml', '.github/workflows/*.yaml'):
    runner_surfaces += [p for p in glob.glob(pat) if os.path.isfile(p)]

def read(path):
    try:
        return open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return ''

# ── DEAD BRANCHES — a dispatch that provably never runs is not an anchor ──────────────────────
# 🟥 CROSS-FAMILY FINDING (codex, 2026-08-22). A lane containing
#     CHECK="scripts/foo.sh"; if false; then bash "$CHECK"; fi
# scored `EXECUTED(via var)` and exited 0. The subject runs ZERO times. Reproduced here before the
# fix in THREE spellings, not the one reported — the multi-line `if false` block, the one-liner, and
# the DIRECT form `if false; then bash scripts/foo.sh; fi`, which has the identical hole and was not
# in the report. Fixing only the arm that was demonstrated would have left the twin open
# ([[feedback_half_fix_propagation_boundary]]), so the mask is applied to every predicate at once
# rather than inside the variable resolver.
#
# 🟥 THE PREDICATE IS "SYNTACTICALLY CONSTANT-FALSE", NOT "CONDITIONAL", AND THE DIFFERENCE IS THE
# WHOLE DESIGN. `if [ -f "$CHECK" ]; then bash "$CHECK"; fi` is an ordinary, correct guard and the
# commonest real spelling in this repo's own lanes; treating every guarded dispatch as unproven
# would block most legitimate anchors and train the override into muscle memory, which is how the
# channel gets disarmed ([[feedback_overblock_traded_for_failopen]]). So only a condition that is a
# literal constant — `false`, `[ 1 -eq 0 ]` and its spellings — is judged dead. That is decidable by
# reading the line; anything requiring a value is not, and is deliberately left live (see residual 3c).
#
# EVERY AMBIGUITY RESOLVES TOWARD *LIVE*, i.e. toward the current behaviour, never toward a new
# block: a nested block inside the branch body abandons the marking entirely, and an `else` arm
# (one-line or multi-line) leaves the construct untouched because that arm does run.
_FALSE_COND = (r'(?:false'
               r'|\[\[?\s*1\s*-eq\s*0\s*\]\]?'
               r'|\[\[?\s*0\s*-eq\s*1\s*\]\]?'
               r'|\[\[?\s*0\s*-ne\s*0\s*\]\]?)')
# One-liner, at ANY position on the line — `CHECK=x.sh; if false; then bash "$CHECK"; fi` does not
# start with `if`, and anchoring at line start is exactly how the first draft of this fix missed it.
_DEAD_INLINE = re.compile(
    r'((?:^|[;&|]\s*)(?:if|while)\s+' + _FALSE_COND + r'\s*;\s*(?:then|do)\b)(.*?)(;\s*(?:fi|done)\b)')
# Multi-line opener: nothing but `then`/`do` after the constant, since every closed-on-one-line form
# is already handled above.
_DEAD_OPEN  = re.compile(r'^\s*(?:if|while)\s+' + _FALSE_COND + r'\s*;?\s*(?:then|do)\s*$')
_BLOCK_OPEN = re.compile(r'(?:^|[;&|]\s*|\bthen\s+|\bdo\s+)(?:if|while|until|for|case)\b')
_BLOCK_END  = re.compile(r'^\s*(?:fi|done|esac|else\b|elif\b)')

def _scrub_inline(ln):
    def rep(m):
        if re.search(r'(?:^|[;&\s])(?:else|elif)\b', m.group(2)):
            return m.group(0)          # the else arm is live — leave the line alone
        return m.group(1) + ' ' + m.group(3)
    return _DEAD_INLINE.sub(rep, ln)

def live_text(txt):
    """`txt` with the bodies of provably-dead branches blanked. Line COUNT and line INDICES are
    preserved, because assigned_then_invoked() reasons about `after` and `before the next
    assignment` by index — collapsing the lines would silently re-order that analysis."""
    lines = [_scrub_inline(l) for l in txt.split('\n')]
    n = len(lines)
    mask = [False] * n
    i = 0
    while i < n:
        if not _DEAD_OPEN.match(lines[i]):
            i += 1
            continue
        j, body, closed = i + 1, [], False
        while j < n:
            if _BLOCK_END.match(lines[j]):
                closed = True
                break
            if _BLOCK_OPEN.search(lines[j]):
                break              # nested block — abandon, mark nothing, stay live
            body.append(j)
            j += 1
        if closed:
            mask[i] = True
            for b in body:
                mask[b] = True
            i = j + 1
        else:
            i += 1
    return '\n'.join('' if mask[k] else lines[k] for k in range(n))

# ── THE EXECUTION PREDICATE — the whole point of the file ─────────────────────────────────────
# A line EXECUTES the subject if it invokes it. It does NOT execute the subject if it merely names
# it. The four spellings that make a naive grep certify a decoration are each excluded by name:
#
#   1. line comment            `# scripts/foo.sh does the thing`
#   2. syntax check            `bash -n scripts/foo.sh`    ← runs zero lines of foo.sh
#   3. grep / search pattern   `grep -q 'scripts/foo.sh' scripts/selfcheck.sh`
#   4. echoed prose            `echo "next: bash scripts/foo.sh"`
#
# 🟥 (2) is the sharpest and is the one this repo has already been burned by: `bash -n` passes a
# runtime bad-substitution, so a hook in that state ABORTS and exits 0 — every push allowed. A
# check that scored `bash -n` as coverage would be certifying the exact instrument this repo
# already ruled is not one.
#
# The `-n` exclusion is spelled as "any short-flag cluster containing n", not as the literal
# `-n`, because `bash -en`, `bash -nu` and `sh -n` are the same non-execution.
INVOKERS = r'(?:exec\s+)?(?:bash|sh|zsh|python3?|source|\.)'
FLAGS    = r'(?:\s+-[A-Za-z]+)*'

# ── 🟥 THE NAME IS A TOKEN, NOT A SUBSTRING ───────────────────────────────────────────────────
# `re.escape(name)` alone matched `foo.sh` inside `foo.sh.bak`, `foo.sh2` and `xfoo.sh`, so a lane
# that runs a NEIGHBOURING file scored the subject EXECUTED and the gate exited 0 — a false PASS on
# a blocking gate, found by cross-family review (codex, 2026-08-22), not by the then-green 17-lane
# known-pair set ([[feedback_control_presence_is_not_discrimination]]).
#
# The boundary is spelled as "not adjacent to a word char, dot or dash" rather than "followed by
# whitespace", and the difference is the whole repair: whitespace would have rejected the two
# commonest real spellings, `bash "…/foo.sh"` and `$(bash …/foo.sh)`, turning a false-pass into a
# false-block. Both directions are pinned by lanes (P10–P12 positive, N13–N14 negative).
def _name_pat(name):
    return r'(?<![\w.-])' + re.escape(name) + r'(?![\w.-])'

def mentions(name, text):
    return re.search(_name_pat(name), text) is not None

def _flags_have_n(seg):
    return any('n' in f for f in re.findall(r'-([A-Za-z]+)', seg))

def executes(name, line):
    """Does THIS line run the subject? `name` is the basename; the path may be spelled with any
    prefix (scripts/, $REPO_ROOT/scripts/, ./scripts/, "$ROOT"/scripts/)."""
    stripped = line.strip()
    if stripped.startswith('#'):
        return False                                  # (1)
    npat = _name_pat(name)
    if not re.search(npat, line):
        return False
    # (4) echoed prose — the name lives inside an echo/printf argument
    if re.search(r'\b(?:echo|printf)\b[^;&|]*' + npat, line):
        return False
    # (3) the name is the ARGUMENT of a search tool, i.e. a pattern, not a command
    if re.search(r'\b(?:grep|egrep|fgrep|rg|ag|sed|awk)\b[^;&|]*' + npat, line):
        return False
    # (2) + the direct invocation form
    for m in re.finditer(INVOKERS + r'(' + FLAGS + r')\s+[^\s;&|]{0,80}?' + npat, line):
        if _flags_have_n(m.group(1)):
            continue                                  # (2) syntax check only
        return True
    # command-position form:  ./scripts/foo.sh   |   "$ROOT/scripts/foo.sh" --flag
    if re.search(r'(?:^|[;&|]|\$\(|\bthen\b|\bdo\b|\bif\s+!?\s*)\s*"?\$?[\w{}/$.-]*' +
                 npat + r'"?(?:\s|$|")', line):
        return True
    return False

# ── ASSIGNED, THEN INVOKED — the spelling nearly every real lane in this repo uses ────────────
#     CHECK="$ROOT/scripts/foo.sh"
#     ...
#     bash "$CHECK" --quiet
# 🟥 THIS WAS A MEASURED FALSE POSITIVE, not a foreseen case. The first version of this file had
# only the direct and heuristic-list predicates, and on its first run against real work in progress
# it called a peer's freshly-written lane suite MENTION_ONLY — a suite that does execute its
# subject, through exactly this two-line form. Hand-checking that one case is what found it
# (CLAUDE.md §Instrument-Calibration, hand-verify-one-sample); the 17-lane known-pair set was green
# and could not have found it, because every fixture in it used a spelling the predicate already
# knew ([[feedback_control_presence_is_not_discrimination]] — a control measures whether there are
# false positives, not which KINDS exist).
#
# This resolves the variable rather than guessing: the assignment must name the subject AND that
# same variable must be invoked. The `-n` exclusion is applied at the invocation site too, so
# `CHECK=…; bash -n "$CHECK"` is still MENTION_ONLY — a syntax check does not become an execution
# by being routed through a variable.
#
# 🟥 REASSIGNMENT IS RESOLVED, NOT DOCUMENTED AWAY (codex, 2026-08-22). The first version asked
# "does SOME line assign it and SOME line invoke that variable", with a residual note calling the
# result "flow-insensitive". It was worse than imprecise: on
#     CHECK="scripts/foo.sh"; CHECK="scripts/bar.sh"; bash "$CHECK"
# it scored foo.sh — a file that runs zero times — as EXECUTED and exited 0. An imprecision that
# manufactures a false PASS on a blocking gate is a hole; writing the ceiling down does not close
# it, and "I declared the limitation" is not a reason to pass a file with no anchor.
#
# What replaces it is a REACHING-DEFINITION check over line order: an assignment that names the
# subject counts only if the variable is invoked AFTER it and BEFORE the next assignment to that
# same variable. That is what makes both twins land correctly, which a blunter fix does not:
#   P9  assign foo → reassign bar → invoke   ⇒ foo never reaches the invocation  → MENTION_ONLY
#   N11 assign foo → reassign foo → invoke   ⇒ still reaches                     → EXECUTED
#   N12 assign foo → invoke → assign bar → invoke ⇒ foo reaches its own invoke   → EXECUTED
# "any reassignment ⇒ MENTION_ONLY" fails N11+N12 and "last assignment wins" fails N12 — both would
# be false blocks, which is not the safe direction here ([[feedback_overblock_traded_for_failopen]]).
def assigned_then_invoked(name, txt):
    npat = _name_pat(name)
    ASSIGN = re.compile(
        r'\s*(?:local\s+|export\s+|declare\s+(?:-\w+\s+)?|readonly\s+)?([A-Za-z_]\w*)=')
    # (index, text, assignment-match-or-None) for every non-comment line, index preserved so
    # "after" and "before the next assignment" are answerable at all.
    body = []
    for i, ln in enumerate(txt.split('\n')):
        if ln.strip().startswith('#'):
            continue
        body.append((i, ln, ASSIGN.match(ln)))

    assigns = {}       # var -> [(line index, does this assignment name the subject, match end)]
    for i, ln, m in body:
        if m:
            assigns.setdefault(m.group(1), []).append(
                (i, re.search(npat, ln) is not None, m.end()))

    def invoked_in(seg, v):
        ref = r'"?\$\{?' + re.escape(v) + r'\}?"?'
        for m in re.finditer(INVOKERS + r'(' + FLAGS + r')\s+' + ref, seg):
            if not _flags_have_n(m.group(1)):
                return True
        return re.search(r'(?:^|[;&|]|\$\(|\bthen\b|\bdo\b|\bif\s+!?\s*)\s*' + ref + r'(?:\s|$)',
                         seg) is not None

    for v, alist in assigns.items():
        for pos, (i, names_subject, end) in enumerate(alist):
            if not names_subject:
                continue
            nxt = alist[pos + 1][0] if pos + 1 < len(alist) else None
            # the remainder of the assignment's OWN line first: `CHECK=x.sh; bash "$CHECK"`
            own = [ln for (j, ln, _m) in body if j == i]
            if own and invoked_in(own[0][end:], v):
                return True
            for j, ln, _m in body:
                if j <= i:
                    continue
                if nxt is not None and j >= nxt:
                    break
                if invoked_in(ln, v):
                    return True
    return False

# INDIRECT dispatch: `for f in scripts/a.sh scripts/b.sh; do bash "$f"; done`. The literal name is
# in a list; the invocation goes through a variable, so the direct predicate structurally cannot
# see it. Mirrors lane_runner_check.sh's `indirect_dispatch`, including its gate — the file must
# actually invoke SOMETHING through a variable, so a prose mention in a file that never dispatches
# indirectly gets no free pass. Reported under its own label so it is never mistaken for a
# hand-verified direct call.
def indirect(name, txt):
    lines = txt.split('\n')
    if not any(re.search(r'\b(?:exec\s+)?(?:bash|sh|zsh|python3?)\s+"?\$', ln)
               for ln in lines if not ln.strip().startswith('#')):
        return False
    for ln in lines:
        if not mentions(name, ln) or ln.strip().startswith('#'):
            continue
        if re.match(r'\s*(?:for\s+\w+\s+in\b|["\']?\S*\|)', ln):
            return True
        if re.match(r'\s*"?[\w./$-]*' + re.escape(name) + r'"?\s*$', ln):   # bare array element
            return True
    return False

# ── EMBEDDED --self-test: an anchor that is not a separate file ───────────────────────────────
# A subject may carry its own known-pair behind `--self-test`. That counts as an anchor ONLY if a
# runner surface actually dispatches it — otherwise it is a lane suite nobody runs, which is
# precisely the decoration this whole check is about. Two propositions, kept separate.
_CP = chr(41)
SELFTEST_FORMS = ('"--self-test"', '--self-test' + _CP)

def selftest_wired(path):
    txt = read(path)
    if not any(f in txt for f in SELFTEST_FORMS):
        return False
    name = os.path.basename(path)
    for r in runner_surfaces:
        if os.path.abspath(r) == os.path.abspath(path):
            continue
        rt = live_text(read(r))     # a --self-test dispatch inside `if false` is not a dispatch
        for ln in rt.split('\n'):
            if mentions(name, ln) and '--self-test' in ln and executes(name, ln):
                return True
    return False

# ── CLASSIFY ──────────────────────────────────────────────────────────────────────────────────
verdicts = []
for subj in subjects:
    name = os.path.basename(subj)
    if subj in exempt:          # EXACT repo-relative path only — see the EXEMPT header block
        verdicts.append(('EXEMPT', subj, 'declared in the checker EXEMPT array'))
        continue
    hit_exec, hit_var, hit_indirect, hit_mention = [], [], [], []
    for lane in lanes:
        if os.path.abspath(lane) == os.path.abspath(subj):
            continue
        txt = read(lane)
        # The MENTION test runs on the raw text and the EXECUTION tests on the live text, on
        # purpose: a dispatch buried in a dead branch is still a mention of the file, so it lands as
        # MENTION_ONLY ("named but never executed") rather than NO_ANCHOR ("no lane names it at
        # all"). Both block; they send the reader to different places.
        if not mentions(name, txt):
            continue
        ltxt = live_text(txt)
        if any(executes(name, ln) for ln in ltxt.split('\n')):
            hit_exec.append(lane)
        elif assigned_then_invoked(name, ltxt):
            hit_var.append(lane)
        elif indirect(name, ltxt):
            hit_indirect.append(lane)
        else:
            hit_mention.append(lane)
    if hit_exec:
        verdicts.append(('EXECUTED', subj, 'run by ' + ', '.join(hit_exec[:3])))
    elif hit_var:
        verdicts.append(('EXECUTED_VIA_VAR', subj,
                         'assigned to a variable and that variable is invoked, in ' +
                         ', '.join(hit_var[:3])))
    elif hit_indirect:
        verdicts.append(('EXECUTED_INDIRECT', subj,
                         'dispatched through a variable by ' + ', '.join(hit_indirect[:3]) +
                         ' — weaker evidence than a direct call, verify by hand once'))
    elif selftest_wired(subj):
        verdicts.append(('SELFTEST_WIRED', subj, 'embedded --self-test, dispatched by a runner surface'))
    elif hit_mention:
        verdicts.append(('MENTION_ONLY', subj,
                         'named but never executed in ' + ', '.join(hit_mention[:3]) +
                         ' (comment / grep pattern / echoed string / `bash -n`)'))
    else:
        verdicts.append(('NO_ANCHOR', subj, 'no lane suite names it at all'))

# ── REPORT ────────────────────────────────────────────────────────────────────────────────────
# The corpus size is printed unconditionally. A zero-lane corpus makes every subject NO_ANCHOR for
# a reason that is about the instrument, not about the subject, and the reader has to be able to
# see that from the output alone.
print(f'CORPUS\t{len(lanes)}')
print(f'SCOPE\t{len(subjects)}\t{len(skipped)}')
for p in skipped:
    print(f'OUT_OF_SCOPE\t{p}\tnot scripts/*.{{sh,py}} or templates/.git-hooks/* (or is itself a lane)')
for v, p, why in verdicts:
    print(f'{v}\t{p}\t{why}')
PY
_py_rc=$?
out="$(cat "$_scan_out")"
rm -f "$_scan_out"
if [ "$_py_rc" -eq 4 ]; then
  # A malformed EXEMPT entry. Reported under its own message because the fix is in THIS file's
  # array, not in anybody's lane — routing it through the generic "the scan failed" text would send
  # the reader to look for a python bug that is not there.
  echo "⛔ HARNESS ERROR: the EXEMPT array in this checker is malformed. Not a pass, and not a"
  echo "   verdict about your code — the gate refused to run with a broken configuration."
  printf '%s\n' "$out" | awk -F'\t' '$1=="FATAL_EXEMPT"{printf "   ✗ %s — %s\n", $2, $3}'
  echo "   Required form:  \"repo/relative/path.sh|reason\"  — a repo-relative path (not a bare"
  echo "   basename), and the reason must be a real sentence (12+ chars)."
  exit 10
fi
if [ "$_py_rc" -ne 0 ]; then
  echo "⛔ UNMEASURED: the scan itself failed (python3 rc=$_py_rc). Not a pass."
  printf '%s\n' "$out"
  exit 10
fi

echo "── new-code-anchor ─────────────────────────────────────────────────────────────"
echo "   base: $BASE ($_base_src) · merge-base: ${MB:0:12}"

_corpus="$(printf '%s\n' "$out" | awk -F'\t' '$1=="CORPUS"{print $2}')"
_nsubj="$(printf '%s\n'  "$out" | awk -F'\t' '$1=="SCOPE"{print $2}')"
_nskip="$(printf '%s\n'  "$out" | awk -F'\t' '$1=="SCOPE"{print $3}')"
echo "   lane corpus: ${_corpus:-?} suites · added in scope: ${_nsubj:-?} · added out of scope: ${_nskip:-?}"

if [ "${_corpus:-0}" = "0" ] && [ "${_nsubj:-0}" != "0" ]; then
  echo "   🟥 the lane corpus is EMPTY — every verdict below is about the instrument, not the code."
fi

printf '%s\n' "$out" | awk -F'\t' '
  $1=="OUT_OF_SCOPE"      { printf "   ·  %-18s %s\n", "out-of-scope", $2 }
  $1=="EXEMPT"            { printf "   ✅ %-18s %s — %s\n", "EXEMPT", $2, $3 }
  $1=="EXECUTED"          { printf "   ✅ %-18s %s — %s\n", "EXECUTED", $2, $3 }
  $1=="EXECUTED_VIA_VAR"  { printf "   ✅ %-18s %s — %s\n", "EXECUTED(via var)", $2, $3 }
  $1=="EXECUTED_INDIRECT" { printf "   ⚠️  %-18s %s — %s\n", "EXECUTED(indirect)", $2, $3 }
  $1=="SELFTEST_WIRED"    { printf "   ✅ %-18s %s — %s\n", "SELFTEST_WIRED", $2, $3 }
  $1=="MENTION_ONLY"      { printf "   ❌ %-18s %s — %s\n", "MENTION_ONLY", $2, $3 }
  $1=="NO_ANCHOR"         { printf "   ❌ %-18s %s — %s\n", "NO_ANCHOR", $2, $3 }
'

# `grep -c` returns 1 on zero matches, which under a naive `$(...)` capture is indistinguishable
# from a broken pipeline. Counted with awk so the empty case is a real 0 and not a swallowed error
# ([[feedback_pipefail_fallback_disarms_guard]] — the question is not "did I add a fallback" but
# "does this print an empty string when it fails").
_bad="$(printf '%s\n' "$out" | awk -F'\t' '$1=="MENTION_ONLY" || $1=="NO_ANCHOR"' | grep -c . || true)"
_bad="${_bad//[!0-9]/}"; _bad="${_bad:-0}"

# 🟥 2026-08-31 — `${_nsubj:-0}` 이 «SCOPE 줄이 아예 없다»(스캔 산출 파손/공백)를 «0»으로
#    렌더했다. 그러면 바로 아래 분기가 *"measured zero, not an unrun scan"* 이라고 **단언**하는데,
#    그건 정확히 이 경우에 못 대는 주장이다 — 미측정이 측정으로 승격된다.
#    ⇒ «SCOPE 줄 부재»는 0 이 아니라 UNMEASURED 이고, 게이트이므로 fail-closed(exit 10)다.
#    선례: session_close_check.sh:441(기본값 UNMEASURED) · test_chamber_sig_lanes.sh:94(비교 불가 기본값).
if [ -z "$_nsubj" ]; then
  echo "⛔ UNMEASURED: 스캔 산출에 SCOPE 줄이 없다 — 대상 개수를 «못 셌다»."
  echo "   이것은 «0 개»가 아니다. 0 으로 접으면 스캔이 죽은 회차가 PASS 로 나간다."
  exit 10
fi

if [ "$_nsubj" = "0" ]; then
  echo "   SCANNED, and the in-scope set is genuinely empty — this change adds no scripts/ executable."
  echo "   (That is a measured zero, not an unrun scan: the base resolved and the diff succeeded.)"
  echo "✅ new-code-anchor: PASS (0 in scope)"
  exit 0
fi

# 🟥 같은 축의 두 번째 자리 — `_bad` 도 «못 셌다»가 0 으로 접힌다. 위 SCOPE 가드가 대부분을
#    막지만, `out` 이 SCOPE 만 있고 뒤가 잘린 경우가 남는다. 여기서도 «비었다»를 갈라낸다.
if [ -z "$_bad" ]; then
  echo "⛔ UNMEASURED: 위반 건수를 «못 셌다» — 0 으로 접지 않는다."
  exit 10
fi

if [ "$_bad" -eq 0 ]; then
  echo "✅ new-code-anchor: PASS — every added executable has a lane that RUNS it."
  exit 0
fi

echo ""
echo "❌ new-code-anchor: $_bad added file(s) ship with no working anchor."
echo "   A green suite total does not mean these files were verified — it can mean nothing touched them."
echo "   Fix (in order of preference):"
echo "     1. add lanes to scripts/test_<name>_lanes.sh that actually EXECUTE the file"
echo "     2. if the file carries its own --self-test, wire that dispatch into a runner surface"
echo "        (scripts/selfcheck.sh · .github/workflows/*.yml|*.yaml · templates/.git-hooks/*)"
echo "     3. if it genuinely cannot be exercised, add it to EXEMPT in this file as"
echo "        \"path|reason\" — the reason is enforced (12+ chars), not merely requested"
echo "   🟥 MENTION_ONLY means a lane NAMES the file without running it. Adding another mention"
echo "      does not clear it — that is the decoration this gate exists to catch."

if [ "${NEW_CODE_ANCHOR_OK:-}" = "1" ]; then
  echo ""
  echo "⚠️  OVERRIDE ACCEPTED — NEW_CODE_ANCHOR_OK=1 was set. The findings above STAND; they were"
  echo "    acknowledged, not resolved. Recording this line is the point of the channel."
  exit 0
fi
exit 1

# ── NAMED RESIDUALS — what this instrument does NOT establish ─────────────────────────────────
# Written here rather than omitted, because silence in a checker reads as coverage.
#
# 1. LINE SCANNING, NOT SHELL PARSING. A dispatch line inside a heredoc body still counts as a
#    live call, and a `#`-comment is only detected at line PREFIX (a trailing comment on a real
#    command line is correctly ignored, but `foo && bash x.sh # note` is judged on the whole line).
#    Symmetric with lane_runner_check.sh, which carries the identical limit. Closing it means
#    parsing shell — the Grep-Collision Treadmill this repo has already logged. Fix on the first
#    case that actually bites, not before.
# 2. "A LANE RUNS IT" ≠ "A LANE VERIFIES IT". A lane that invokes the subject once and asserts
#    nothing scores EXECUTED. This gate closes the ZERO-coverage hole, which is the one the origin
#    incident was about; it does not measure assertion quality, and nothing here should be cited
#    as if it did.
# 3. EXECUTED_INDIRECT is heuristic. It exists because the strict predicate provably under-reports
#    (measured in the sibling check, 2026-08-12: two genuinely-run suites called UNWIRED). It is
#    labelled ⚠️ rather than ✅ so the weaker evidence is visible in the output.
# 3c. DEAD BRANCHES ARE CLOSED ONLY FOR *CONSTANT* CONDITIONS. `if false; then bash x.sh; fi` no
#    longer counts as an execution, in the direct, variable and --self-test arms alike (lanes
#    P13–P15). What is still scored as an execution is a branch that is dead for a reason a reader
#    cannot get from the line — `if [ "$NEVER_SET" = 1 ]; then bash x.sh; fi`. That is not a
#    documented-away version of the same hole: closing it means evaluating conditions, i.e. constant
#    propagation over shell, which is undecidable in general and would have to guess. The line drawn
#    here is "decidable by reading the line", and the guessing side is left LIVE so the gate never
#    blocks a legitimate guard (N18–N20 pin that direction).
#    Two known-narrow spots in the marking itself, both failing toward live: a nested block inside a
#    dead branch abandons the marking, and a one-line `if false; then A; else B; fi` is left entirely
#    alone rather than risking B.
# 3b. VARIABLE RESOLUTION IS SINGLE-FILE, ORDER-AWARE, BRANCH-BLIND. Since 2026-08-22 it is a
#    reaching-definition check over line order: an assignment naming the subject counts only if the
#    variable is invoked after it and before the next assignment to that variable (lanes P9 / N11 /
#    N12). What remains open, and is NOT a false-pass direction:
#      · branches — `if …; then CHECK=other.sh; fi; bash "$CHECK"` treats the branch body as a
#        plain reassignment, so the earlier subject is judged unreached. That direction BLOCKS;
#        the author clears it by adding a lane, not by arguing with the parser. (The opposite
#        direction — a branch that never runs being scored as an execution — was a false PASS, not
#        an over-block, and is closed for constant conditions; see 3c.)
#      · one-liners with two assignments to the same variable on a single line: only the first is
#        seen (`ASSIGN` anchors at line start), so the rest of that line is attributed to it.
#      · cross-file — a variable assigned in a sourced helper is invisible.
#    The previous version of this note said the resolution was flow-insensitive and left it there.
#    That was not an honest ceiling but a hole with a label on it: it produced a false PASS on a
#    blocking gate, and cross-family review (codex) found it by writing the two-line fixture the
#    note itself described. A stated limitation does not become acceptable by being stated.
# 4. RENAMES. `--diff-filter=A` sees a renamed file as added when git does not detect the rename
#    (it defaults to detecting them for `--name-only`, so this is a partial, not a total, gap).
#    A rename of an already-anchored file whose lane still names the OLD path will surface as
#    NO_ANCHOR — which is the correct direction (the lane is now stale), but the message will say
#    "new file" about something that is not new.
# 5. UNCOMMITTED WORK IS OUT OF SCOPE. The diff is base..HEAD. A file added but not yet committed
#    is not judged. This gate's binding point is CI/pre-merge, not the working tree
#    ([[feedback_gate_binding_point_not_check_point]]).
# 6b. THE NAME BOUNDARY IS LEXICAL. `foo.sh` no longer matches inside `foo.sh.bak` / `foo.sh2` /
#    `xfoo.sh`, but two DIFFERENT files with the SAME basename in different directories are still
#    one token to this scan — `a/run.sh` and `b/run.sh` are indistinguishable, and a lane running
#    either anchors both. Basename matching is what lets the four legitimate path spellings
#    (bare, ./, $ROOT/, "$VAR") work at all; narrowing it to full paths would trade this
#    false-pass for a large false-block. Named, not closed.
# 6. SCOPE IS scripts/ + templates/.git-hooks/. A new executable elsewhere (e.g. a plugin hook,
#    .github/scripts/) is reported OUT_OF_SCOPE by name and judged by nobody. Widening the scope
#    without widening what the lane corpus can reach would be a coverage claim this cannot back
#    ([[feedback_scope_widening_needs_grounding]]).
