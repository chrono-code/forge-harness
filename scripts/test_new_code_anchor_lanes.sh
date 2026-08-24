#!/usr/bin/env bash
# test_new_code_anchor_lanes.sh — known-pair calibration for scripts/new_code_anchor_check.sh.
#
# 🟥 EVERY LANE BUILDS A REAL, THROWAWAY GIT REPO UNDER mktemp AND RUNS THE CHECKER THERE.
# Not one lane scans this repository. That is not tidiness — a fixture that reads the live tree
# measures whatever the tree happens to look like today, so the lane's verdict drifts with
# unrelated commits and the known-pair stops being known ([[feedback_audit_target_must_be_frozen]]).
# It also means the lanes exercise the REAL git path (merge-base, --diff-filter=A) instead of an
# injected file list, so there is no test-only seam that production does not take.
#
# ── HOW THE KNOWN-POSITIVES WERE CHOSEN ───────────────────────────────────────────────────────
# The trivial positive (a new script no lane mentions at all) is included, but it is NOT the
# load-bearing one — any name-grep would catch it. The lanes that decide whether this gate is real
# are P2–P5: the file IS named in a lane suite, in each of the four spellings that satisfy a name
# grep while executing zero lines of the subject. Those are the "뚫리는 표기"
# ([[feedback_fixture_must_use_the_breaking_spelling]]): if the fixture only used the easiest
# positive, a checker that greps for the name would score 100% here and ship as a decoration.
#   P2 comment · P3 grep pattern · P4 `bash -n` (syntax check) · P5 echoed string
#   P8 assigned to a variable, then only syntax-checked through it (added after N8's false positive)
# P4 is the sharpest: this repo has measured that `bash -n` passes a runtime bad-substitution that
# leaves a hook fail-open, so scoring it as coverage would certify the very instrument FH already
# ruled is not one ([[feedback_gate_verification_must_execute]]).
#
# Exit: 0 = every pair held · 1 = a pair collapsed · 10 = the harness could not set itself up.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBJECT="$REPO_ROOT/scripts/new_code_anchor_check.sh"

[ -f "$SUBJECT" ] || { echo "FATAL: subject missing: $SUBJECT"; exit 2; }
command -v git     >/dev/null 2>&1 || { echo "FATAL: git unavailable";     exit 10; }
command -v python3 >/dev/null 2>&1 || { echo "FATAL: python3 unavailable"; exit 10; }

TMPROOT="$(mktemp -d 2>/dev/null)" || { echo "FATAL: mktemp failed"; exit 10; }
cleanup() { [ -n "${TMPROOT:-}" ] && rm -rf "$TMPROOT"; }
trap cleanup EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ✅ %s\n' "$*"; }
bad()  { FAIL=$((FAIL+1)); printf '  ❌ %s\n' "$*"; }

# ── fixture builders ──────────────────────────────────────────────────────────────────────────
# `-c` flags rather than global config writes: this suite must not touch the runner's git identity,
# and on a shared checkout it must not touch anything outside its own mktemp dir.
_git() { git -C "$1" -c user.name=fixture -c user.email=fixture@example.invalid \
                     -c commit.gpgsign=false "${@:2}"; }

new_repo() {  # $1 = name → echoes the repo path
  local d="$TMPROOT/$1"
  mkdir -p "$d/scripts" || return 1
  git init -q "$d" >/dev/null 2>&1 || return 1
  # symbolic-ref instead of `git init -b main`: -b needs git >= 2.28 and this suite runs on
  # whatever the CI image and the operator's macOS ship.
  git -C "$d" symbolic-ref HEAD refs/heads/main >/dev/null 2>&1 || return 1
  cp "$SUBJECT" "$d/scripts/new_code_anchor_check.sh" || return 1
  # A pre-existing, UNANCHORED script on the base commit. It is the grandfather control: if it
  # ever shows up in a verdict, the gate has stopped being diff-scoped and is auditing the tree.
  printf '#!/usr/bin/env bash\necho legacy\n' > "$d/scripts/legacy_thing.sh"
  _git "$d" add -A >/dev/null 2>&1 || return 1
  _git "$d" commit -qm base >/dev/null 2>&1 || return 1
  printf '%s' "$d"
}

branch_and_commit() {  # $1 = repo
  _git "$1" checkout -q -b feat >/dev/null 2>&1 || return 1
  _git "$1" add -A >/dev/null 2>&1 || return 1
  _git "$1" commit -qm change >/dev/null 2>&1 || return 1
}

run_check() {  # $1 = repo  → sets OUT / RC
  # 🟥 THE FIXTURE-ROOT GUARD IS NOT DEFENSIVE PADDING. `cd ""` is a NO-OP that exits 0, so an empty
  # or missing fixture path would silently run the checker against the REAL repository — a sibling
  # lane suite in this repo did exactly that on 2026-08-22 and the suite stayed green while
  # measuring the live tree ([[feedback_audit_target_must_be_frozen]]). Refuse instead.
  case "${1:-}" in
    "$TMPROOT"/*) : ;;
    *) echo "FATAL: run_check called with a path outside the fixture root: '${1:-}'"; exit 10 ;;
  esac
  [ -d "$1/.git" ] || { echo "FATAL: not a fixture repo: '$1'"; exit 10; }
  OUT="$(cd "$1" && bash scripts/new_code_anchor_check.sh 2>&1)"
  RC=$?
}

# The subject file every lane adds. Named distinctly so a stray match against a real repo file is
# impossible even if a lane were ever mis-rooted.
NEWSCRIPT='#!/usr/bin/env bash
echo "fixture subject"
'

expect() {  # $1 label  $2 expected_rc  $3 expected_marker(regex, "" to skip)
  if [ "$RC" != "$2" ]; then
    bad "$1 — expected rc=$2, got rc=$RC"
    printf '%s\n' "$OUT" | sed 's/^/        /'
    return
  fi
  if [ -n "${3:-}" ] && ! printf '%s' "$OUT" | grep -qE "$3"; then
    bad "$1 — rc=$2 as expected, but the verdict label did not match /$3/"
    printf '%s\n' "$OUT" | sed 's/^/        /'
    return
  fi
  ok "$1 (rc=$RC)"
}

echo "── known-POSITIVES: an added executable with no working anchor must BLOCK ──────────"

# P1 — the trivial positive. No lane names it at all.
d="$(new_repo p1)" || { echo "FATAL: fixture p1"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
branch_and_commit "$d" || { echo "FATAL: commit p1"; exit 10; }
run_check "$d"; expect "P1 NO_ANCHOR — nothing names it" 1 'NO_ANCHOR.*fixture_subject\.sh'

# P2 — 🟥 breaking spelling: named in a lane, inside a COMMENT.
d="$(new_repo p2)" || { echo "FATAL: fixture p2"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
# covers scripts/fixture_subject.sh end to end
echo "lane ran"
LANE
branch_and_commit "$d" || { echo "FATAL: commit p2"; exit 10; }
run_check "$d"; expect "P2 MENTION_ONLY — comment" 1 'MENTION_ONLY.*fixture_subject\.sh'

# P3 — 🟥 breaking spelling: the name is a GREP PATTERN, not a command.
d="$(new_repo p3)" || { echo "FATAL: fixture p3"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
if grep -q 'scripts/fixture_subject.sh' scripts/legacy_thing.sh; then
  echo wired
fi
LANE
branch_and_commit "$d" || { echo "FATAL: commit p3"; exit 10; }
run_check "$d"; expect "P3 MENTION_ONLY — grep pattern" 1 'MENTION_ONLY.*fixture_subject\.sh'

# P4 — 🟥 the sharpest one: `bash -n` is a SYNTAX check. Zero lines of the subject execute.
d="$(new_repo p4)" || { echo "FATAL: fixture p4"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
bash -n scripts/fixture_subject.sh || exit 1
echo "syntax ok"
LANE
branch_and_commit "$d" || { echo "FATAL: commit p4"; exit 10; }
run_check "$d"; expect "P4 MENTION_ONLY — bash -n (syntax check, not execution)" 1 'MENTION_ONLY.*fixture_subject\.sh'

# P5 — 🟥 breaking spelling: the invocation lives inside an ECHOED STRING.
d="$(new_repo p5)" || { echo "FATAL: fixture p5"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
echo "to reproduce: bash scripts/fixture_subject.sh --verbose"
LANE
branch_and_commit "$d" || { echo "FATAL: commit p5"; exit 10; }
run_check "$d"; expect "P5 MENTION_ONLY — echoed string" 1 'MENTION_ONLY.*fixture_subject\.sh'

# P8 — 🟥 the same two-line form N8 passes on, but with `bash -n` at the invocation site. Routing a
# syntax check through a variable does not make it an execution. This lane exists because the
# variable-resolution predicate was added AFTER a measured false positive, and a predicate added
# under pressure to stop blocking is exactly the one that gets written too permissive
# ([[feedback_repair_is_the_main_defect_source]]).
d="$(new_repo p8)" || { echo "FATAL: fixture p8"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/scripts/fixture_subject.sh"
bash -n "$CHECK" || exit 1
LANE
branch_and_commit "$d" || { echo "FATAL: commit p8"; exit 10; }
run_check "$d"; expect "P8 MENTION_ONLY — assigned, then only \`bash -n \$VAR\`" 1 'MENTION_ONLY.*fixture_subject\.sh'

# P9 — 🟥 REGRESSION ANCHOR (cross-family finding, codex 2026-08-22): the variable is REASSIGNED
# before it is ever invoked, so the first path never runs. The first version of this checker scored
# BOTH paths `EXECUTED(via var)` and exited 0 — i.e. a file with zero anchors shipped green. The
# residual note said the resolution was "flow-insensitive", which is true and is exactly why this is
# a defect and not a documented limit: an imprecision that produces a false PASS on a blocking gate
# is a hole, and writing the ceiling down does not close it.
d="$(new_repo p9)" || { echo "FATAL: fixture p9"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
CHECK="scripts/fixture_subject.sh"
CHECK="scripts/legacy_thing.sh"
bash "$CHECK" || exit 1
LANE
branch_and_commit "$d" || { echo "FATAL: commit p9"; exit 10; }
run_check "$d"; expect "P9 MENTION_ONLY — reassigned before the invocation (never runs)" 1 'MENTION_ONLY.*fixture_subject\.sh'

# P10–P12 — 🟥 REGRESSION ANCHORS (codex 2026-08-22): the predicate matched the basename as a bare
# SUBSTRING, so a lane naming a NEIGHBOURING file scored the subject as EXECUTED. Three spellings,
# not one, because a boundary fix that only handles the suffix leaves the prefix open and vice
# versa ([[feedback_fixture_must_use_the_breaking_spelling]] — the easiest positive proves least):
#   P10 suffix, punctuation  `fixture_subject.sh.bak`
#   P11 suffix, word char    `fixture_subject.sh2`   (command position, the other predicate arm)
#   P12 prefix               `xfixture_subject.sh`
d="$(new_repo p10)" || { echo "FATAL: fixture p10"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh.bak"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
bash scripts/fixture_subject.sh.bak || exit 1
LANE
branch_and_commit "$d" || { echo "FATAL: commit p10"; exit 10; }
run_check "$d"; expect "P10 substring — .bak neighbour is not the subject" 1 '(NO_ANCHOR|MENTION_ONLY).*fixture_subject\.sh —'

d="$(new_repo p11)" || { echo "FATAL: fixture p11"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh2"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
./scripts/fixture_subject.sh2
LANE
branch_and_commit "$d" || { echo "FATAL: commit p11"; exit 10; }
run_check "$d"; expect "P11 substring — .sh2 neighbour, command position" 1 '(NO_ANCHOR|MENTION_ONLY).*fixture_subject\.sh —'

d="$(new_repo p12)" || { echo "FATAL: fixture p12"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
printf '%s' "$NEWSCRIPT" > "$d/scripts/xfixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
bash scripts/xfixture_subject.sh || exit 1
LANE
branch_and_commit "$d" || { echo "FATAL: commit p12"; exit 10; }
run_check "$d"; expect "P12 substring — x-prefixed neighbour is not the subject" 1 '(NO_ANCHOR|MENTION_ONLY).*fixture_subject\.sh —'

# P13–P15 — 🟥 REGRESSION ANCHORS (cross-family finding, codex 2026-08-22): a dispatch inside a
# provably DEAD branch was scored as an execution. The reported repro was P13; P14 and P15 are the
# same hole in spellings the report did not name, and they are here because a repair that only
# closes the demonstrated arm leaves its twins open ([[feedback_half_fix_propagation_boundary]]).
#   P13 multi-line `if false` block, variable dispatch   → was EXECUTED(via var), rc=0
#   P14 the same collapsed onto ONE line, NOT at line start (a line-anchored fix misses this)
#   P15 DIRECT dispatch in a dead branch                 → was EXECUTED, rc=0
# All three are false PASSes on a blocking gate: the subject runs zero times.
d="$(new_repo p13)" || { echo "FATAL: fixture p13"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
CHECK="scripts/fixture_subject.sh"
if false; then
  bash "$CHECK"
fi
LANE
branch_and_commit "$d" || { echo "FATAL: commit p13"; exit 10; }
run_check "$d"; expect "P13 dead branch (\`if false\`), variable dispatch — never runs" 1 'MENTION_ONLY.*fixture_subject\.sh'

d="$(new_repo p14)" || { echo "FATAL: fixture p14"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
CHECK="scripts/fixture_subject.sh"; if false; then bash "$CHECK"; fi
LANE
branch_and_commit "$d" || { echo "FATAL: commit p14"; exit 10; }
run_check "$d"; expect "P14 dead branch on one line, mid-line (not at line start)" 1 'MENTION_ONLY.*fixture_subject\.sh'

d="$(new_repo p15)" || { echo "FATAL: fixture p15"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
if false; then
  bash scripts/fixture_subject.sh
fi
LANE
branch_and_commit "$d" || { echo "FATAL: commit p15"; exit 10; }
run_check "$d"; expect "P15 dead branch, DIRECT dispatch (the unreported twin)" 1 'MENTION_ONLY.*fixture_subject\.sh'

# P16 — 🟥 A CONTROL, NOT AN ANCHOR, AND IT IS LABELLED THAT WAY BECAUSE THE REVERT PROBE SAID SO.
# It was written as the regression anchor for the EXEMPT basename-leniency hole (codex 2026-08-22)
# and it is not one: reverting the fix leaves this lane GREEN, because the leniency only fires when
# the ENTRY is a bare basename, and this entry is a full path. A lane that passes with and without
# the fix measures nothing about it ([[feedback_anchor_can_be_decorative]] — an anchor can be a
# decoration, and only reverting finds out which). X3 below is the discriminating lane.
# It is kept because it does pin the intended semantics — one path's exemption does not travel to a
# same-basename file in another directory, which is also the point on which this gate had diverged
# from scripts/script_caller_ratchet.sh ([[feedback_divergent_leniency_duplicate_normalizers]]).
d="$(new_repo p16)" || { echo "FATAL: fixture p16"; exit 10; }
mkdir -p "$d/scripts/nested"
printf '%s' "$NEWSCRIPT" > "$d/scripts/nested/fixture_subject.sh"
python3 - "$d/scripts/new_code_anchor_check.sh" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
marker = 'EXEMPT=(\n)'
assert marker in t, "EXEMPT array shape changed — this lane edits a form that no longer exists"
open(p, 'w', encoding='utf-8').write(t.replace(
    marker,
    'EXEMPT=(\n  "scripts/fixture_subject.sh|fixture-only stub, exercised by the lane harness itself"\n)',
    1))
PY
branch_and_commit "$d" || { echo "FATAL: commit p16"; exit 10; }
run_check "$d"; expect "P16 same basename, different directory is NOT exempt" 1 'NO_ANCHOR.*nested/fixture_subject\.sh'

# X3 — the bare-basename EXEMPT entry itself. With the leniency removed such an entry would become
# an inert line the author reads as an active exemption, so it is refused as a harness error (10)
# rather than ignored ([[feedback_not_found_is_not_zero_family]] — a silently-inert config is the
# quietest face of "unmeasured rendered as fine").
d="$(new_repo x3)" || { echo "FATAL: fixture x3"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
python3 - "$d/scripts/new_code_anchor_check.sh" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
marker = 'EXEMPT=(\n)'
assert marker in t
open(p, 'w', encoding='utf-8').write(t.replace(
    marker, 'EXEMPT=(\n  "fixture_subject.sh|fixture-only exemption with a real reason"\n)', 1))
PY
branch_and_commit "$d" || { echo "FATAL: commit x3"; exit 10; }
run_check "$d"; expect "X3 bare-basename EXEMPT entry → refused (10), never a silent pass" 10 'bare basename'

# X1 — 🟥 REGRESSION ANCHOR (codex 2026-08-22): the EXEMPT array documented itself as "with the
# reason" while being a bare string-membership set — the reason had NO CHANNEL to live in, so the
# first user of the array would have satisfied the documented bar by writing a path. That is the
# «규칙이 자기 기계에 대해 거짓을 말한다» shape ([[feedback_rule_misdescribes_its_own_machine]]).
# A reason-less entry must now be REFUSED, and refused as a harness error (10) rather than a code
# verdict: the checker's own configuration is malformed, so nothing it says about the code is
# evidence either way.
d="$(new_repo x1)" || { echo "FATAL: fixture x1"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
python3 - "$d/scripts/new_code_anchor_check.sh" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
marker = 'EXEMPT=(\n)'
assert marker in t, "EXEMPT array shape changed — this lane edits a form that no longer exists"
open(p, 'w', encoding='utf-8').write(
    t.replace(marker, 'EXEMPT=(\n  "scripts/fixture_subject.sh"\n)', 1))
PY
branch_and_commit "$d" || { echo "FATAL: commit x1"; exit 10; }
run_check "$d"; expect "X1 EXEMPT without a reason → refused (10), never a silent pass" 10 'EXEMPT'

# X2 — the same refusal for a VACUOUS reason. Without this the fix would be "any character after the
# pipe", and `foo.sh|x` would clear a bar whose whole content is that someone had to write a sentence.
d="$(new_repo x2)" || { echo "FATAL: fixture x2"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
python3 - "$d/scripts/new_code_anchor_check.sh" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
marker = 'EXEMPT=(\n)'
assert marker in t
open(p, 'w', encoding='utf-8').write(
    t.replace(marker, 'EXEMPT=(\n  "scripts/fixture_subject.sh|n/a"\n)', 1))
PY
branch_and_commit "$d" || { echo "FATAL: commit x2"; exit 10; }
run_check "$d"; expect "X2 EXEMPT with a vacuous reason → refused (10)" 10 'EXEMPT'

# P6 — a python subject, to pin that scope is not shell-only.
d="$(new_repo p6)" || { echo "FATAL: fixture p6"; exit 10; }
printf 'print("fixture")\n' > "$d/scripts/fixture_subject.py"
branch_and_commit "$d" || { echo "FATAL: commit p6"; exit 10; }
run_check "$d"; expect "P6 NO_ANCHOR — added .py" 1 'NO_ANCHOR.*fixture_subject\.py'

# P7 — a git hook, the other in-scope surface.
d="$(new_repo p7)" || { echo "FATAL: fixture p7"; exit 10; }
mkdir -p "$d/templates/.git-hooks"
printf '%s' "$NEWSCRIPT" > "$d/templates/.git-hooks/pre-merge-commit"
branch_and_commit "$d" || { echo "FATAL: commit p7"; exit 10; }
run_check "$d"; expect "P7 NO_ANCHOR — added git hook" 1 'NO_ANCHOR.*pre-merge-commit'

echo ""
echo "── known-NEGATIVES: an anchored / out-of-scope / pre-existing file must PASS ───────"
# Without these, the suite measures only "does it block", and an always-block gate would score
# 7/7 above. Over-blocking is not a safe failure: it trains the override into muscle memory and
# disarms the channel ([[feedback_overblock_traded_for_failopen]]).

# N1 — a lane that actually runs it, plain spelling.
d="$(new_repo n1)" || { echo "FATAL: fixture n1"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
bash scripts/fixture_subject.sh || exit 1
LANE
branch_and_commit "$d" || { echo "FATAL: commit n1"; exit 10; }
run_check "$d"; expect "N1 EXECUTED — bash scripts/x.sh" 0 'EXECUTED.*fixture_subject\.sh'

# N2 — run through an absolute-path variable, the way every real lane in this repo spells it.
d="$(new_repo n2)" || { echo "FATAL: fixture n2"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT/scripts/fixture_subject.sh" --quiet
LANE
branch_and_commit "$d" || { echo "FATAL: commit n2"; exit 10; }
run_check "$d"; expect "N2 EXECUTED — bash \"\$ROOT/scripts/x.sh\"" 0 'EXECUTED.*fixture_subject\.sh'

# N3 — command-position invocation.
d="$(new_repo n3)" || { echo "FATAL: fixture n3"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
./scripts/fixture_subject.sh
LANE
branch_and_commit "$d" || { echo "FATAL: commit n3"; exit 10; }
run_check "$d"; expect "N3 EXECUTED — ./scripts/x.sh" 0 'EXECUTED.*fixture_subject\.sh'

# N8 — 🟥 THE MEASURED FALSE POSITIVE, frozen as a lane. Assign the path to a variable on one line,
# invoke the variable on another. This is how nearly every real lane suite in scripts/ spells it,
# and the first version of this checker called it MENTION_ONLY — caught by hand-checking one live
# case, not by the (then fully green) known-pair set. The fixture reproduces the exact two-line
# shape rather than a tidied approximation.
d="$(new_repo n8)" || { echo "FATAL: fixture n8"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/scripts/fixture_subject.sh"
bash "$CHECK" --quiet || exit 1
LANE
branch_and_commit "$d" || { echo "FATAL: commit n8"; exit 10; }
run_check "$d"; expect "N8 EXECUTED(via var) — assigned then invoked" 0 'EXECUTED\(via var\).*fixture_subject\.sh'

# N9 — the variable invoked in COMMAND POSITION rather than after `bash`. Same resolution, other
# spelling; without it the predicate would be pinned to one of its two arms.
d="$(new_repo n9)" || { echo "FATAL: fixture n9"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
CHECK="scripts/fixture_subject.sh"
if "$CHECK" --quiet; then echo ok; fi
LANE
branch_and_commit "$d" || { echo "FATAL: commit n9"; exit 10; }
run_check "$d"; expect "N9 EXECUTED(via var) — variable in command position" 0 'EXECUTED\(via var\).*fixture_subject\.sh'

# N10 — 🟥 the OVER-PERMISSIVE direction of the same repair: a variable that is assigned the path
# and then NEVER invoked must stay MENTION_ONLY. Without this lane, "resolve the variable" could
# have been implemented as "an assignment counts", which would pass every fixture above while
# certifying a decoration — the exact thing this gate exists to stop.
d="$(new_repo n10)" || { echo "FATAL: fixture n10"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
CHECK="scripts/fixture_subject.sh"
echo "the subject under test is $CHECK"
LANE
branch_and_commit "$d" || { echo "FATAL: commit n10"; exit 10; }
run_check "$d"; expect "N10 assigned but never invoked stays MENTION_ONLY" 1 'MENTION_ONLY.*fixture_subject\.sh'

# N11 — 🟥 THE KNOWN-NEGATIVE TWIN OF P9, and the reason the P9 repair is a reaching-definition
# check rather than a blunt "any reassignment ⇒ MENTION_ONLY". The variable IS reassigned, but the
# reassignment names the SAME subject (the conditional-override spelling), so the invocation still
# runs it. The blunt fix would block this — and an over-blocking gate trains the override into
# muscle memory, which is how the channel gets disarmed ([[feedback_overblock_traded_for_failopen]]).
d="$(new_repo n11)" || { echo "FATAL: fixture n11"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
CHECK="scripts/fixture_subject.sh"
if [ -n "${ALT:-}" ]; then CHECK="./scripts/fixture_subject.sh"; fi
bash "$CHECK" || exit 1
LANE
branch_and_commit "$d" || { echo "FATAL: commit n11"; exit 10; }
run_check "$d"; expect "N11 reassigned to the SAME subject still EXECUTED(via var)" 0 'EXECUTED\(via var\).*fixture_subject\.sh'

# N12 — the second known-negative twin of P9: the sequential-reuse spelling one variable, two
# subjects, each invoked after its own assignment. A "last assignment wins" repair would have called
# the FIRST subject unanchored here, which is a false block on a file that genuinely runs.
d="$(new_repo n12)" || { echo "FATAL: fixture n12"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
CHECK="scripts/fixture_subject.sh"
bash "$CHECK" || exit 1
CHECK="scripts/legacy_thing.sh"
bash "$CHECK" || exit 1
LANE
branch_and_commit "$d" || { echo "FATAL: commit n12"; exit 10; }
run_check "$d"; expect "N12 sequential reuse — invoked before the reassignment" 0 'EXECUTED\(via var\).*fixture_subject\.sh'

# N13/N14 — 🟥 the known-negative twins of the SUBSTRING repair (P10–P12). A boundary that is drawn
# too tight breaks the two commonest real spellings, where the character after the name is a closing
# quote or a closing paren rather than whitespace. Without these, "require a boundary" could ship as
# "require whitespace" and block most of the repo's own lanes.
d="$(new_repo n13)" || { echo "FATAL: fixture n13"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
if bash "scripts/fixture_subject.sh"; then echo ok; fi
LANE
branch_and_commit "$d" || { echo "FATAL: commit n13"; exit 10; }
run_check "$d"; expect "N13 quoted path still EXECUTED (boundary = quote)" 0 'EXECUTED.*fixture_subject\.sh'

d="$(new_repo n14)" || { echo "FATAL: fixture n14"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
out="$(bash scripts/fixture_subject.sh)"
echo "$out"
LANE
branch_and_commit "$d" || { echo "FATAL: commit n14"; exit 10; }
run_check "$d"; expect "N14 command substitution still EXECUTED (boundary = close paren)" 0 'EXECUTED.*fixture_subject\.sh'

# N15 — 🟥 REGRESSION ANCHOR (agy/gemini 2026-08-22): the runner-surface enumeration listed
# `.github/workflows/*.yml` and NOT `*.yaml`, so a subject whose embedded --self-test is dispatched
# from a `.yaml` workflow was classified unanchored. GitHub accepts both spellings; this repo
# happens to use only `.yml`, which is exactly the condition under which the gap stays invisible
# until it blocks someone else's PR ([[feedback_candidate_list_completeness]]).
d="$(new_repo n15)" || { echo "FATAL: fixture n15"; exit 10; }
mkdir -p "$d/.github/workflows"
cat > "$d/scripts/fixture_selftest.sh" <<'SUBJ'
#!/usr/bin/env bash
if [ "${1:-}" = "--self-test" ]; then echo "self-test ok"; exit 0; fi
echo "normal run"
SUBJ
cat > "$d/.github/workflows/anchor.yaml" <<'WF'
name: anchor
jobs:
  t:
    runs-on: ubuntu-latest
    steps:
      - run: bash scripts/fixture_selftest.sh --self-test
WF
branch_and_commit "$d" || { echo "FATAL: commit n15"; exit 10; }
run_check "$d"; expect "N15 SELFTEST_WIRED — dispatched from a .yaml workflow" 0 'SELFTEST_WIRED.*fixture_selftest\.sh'

# N16 — the `.yml` control for N15. It pins that the fix ADDED a spelling rather than swapping one
# for the other — a repair that moves the hole instead of closing it would still score N15 green.
d="$(new_repo n16)" || { echo "FATAL: fixture n16"; exit 10; }
mkdir -p "$d/.github/workflows"
cat > "$d/scripts/fixture_selftest.sh" <<'SUBJ'
#!/usr/bin/env bash
if [ "${1:-}" = "--self-test" ]; then echo "self-test ok"; exit 0; fi
echo "normal run"
SUBJ
cat > "$d/.github/workflows/anchor.yml" <<'WF'
name: anchor
jobs:
  t:
    runs-on: ubuntu-latest
    steps:
      - run: bash scripts/fixture_selftest.sh --self-test
WF
branch_and_commit "$d" || { echo "FATAL: commit n16"; exit 10; }
run_check "$d"; expect "N16 SELFTEST_WIRED — .yml control for N15" 0 'SELFTEST_WIRED.*fixture_selftest\.sh'

# N17 — the known-negative twin of X1/X2: an EXEMPT entry that DOES carry a substantive reason must
# still pass. Refusing everything would be the same defect wearing the other sign.
d="$(new_repo n17)" || { echo "FATAL: fixture n17"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
python3 - "$d/scripts/new_code_anchor_check.sh" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
marker = 'EXEMPT=(\n)'
assert marker in t, "EXEMPT array shape changed — this lane edits a form that no longer exists"
open(p, 'w', encoding='utf-8').write(t.replace(
    marker,
    'EXEMPT=(\n  "scripts/fixture_subject.sh|fixture-only stub, exercised by the lane harness itself"\n)',
    1))
PY
branch_and_commit "$d" || { echo "FATAL: commit n17"; exit 10; }
run_check "$d"; expect "N17 EXEMPT with a substantive reason passes" 0 'EXEMPT.*fixture_subject\.sh'

# N18–N21 — 🟥 THE KNOWN-NEGATIVE TWINS OF P13–P15, and the reason the repair keys on
# "syntactically constant-false" rather than on "conditional". A guarded dispatch is the commonest
# real spelling in this repo's own lanes; a fix that treated every branch body as unproven would
# score P13–P15 green while blocking most legitimate anchors, and an over-blocking gate trains the
# override into muscle memory ([[feedback_overblock_traded_for_failopen]]). Each of these four ran
# GREEN before the repair too — that is the point: they pin that the repair moved nothing else.
#   N18 the ordinary `[ -f … ]` guard      N19 `if true` — a CONSTANT condition that is not false,
#   so the discriminator is falseness and not constant-ness (without it, "any literal condition is
#   suspect" would pass every positive above)
#   N20/N21 a dead `then` arm with a LIVE `else` arm — the dispatch in the else runs, multi-line and
#   one-line. A masker that killed the whole construct would false-block both.
d="$(new_repo n18)" || { echo "FATAL: fixture n18"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
CHECK="scripts/fixture_subject.sh"
if [ -f "$CHECK" ]; then
  bash "$CHECK"
fi
LANE
branch_and_commit "$d" || { echo "FATAL: commit n18"; exit 10; }
run_check "$d"; expect "N18 ordinary [ -f ] guard is still EXECUTED (no over-block)" 0 'EXECUTED\(via var\).*fixture_subject\.sh'

d="$(new_repo n19)" || { echo "FATAL: fixture n19"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
if true; then
  bash scripts/fixture_subject.sh
fi
LANE
branch_and_commit "$d" || { echo "FATAL: commit n19"; exit 10; }
run_check "$d"; expect "N19 \`if true\` — constant but not false, still EXECUTED" 0 'EXECUTED.*fixture_subject\.sh'

d="$(new_repo n20)" || { echo "FATAL: fixture n20"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
if false; then
  bash scripts/legacy_thing.sh
else
  bash scripts/fixture_subject.sh
fi
LANE
branch_and_commit "$d" || { echo "FATAL: commit n20"; exit 10; }
run_check "$d"; expect "N20 dead then-arm, LIVE else-arm (multi-line) still EXECUTED" 0 'EXECUTED.*fixture_subject\.sh'

d="$(new_repo n21)" || { echo "FATAL: fixture n21"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
cat > "$d/scripts/test_fixture_lanes.sh" <<'LANE'
#!/usr/bin/env bash
if false; then bash scripts/legacy_thing.sh; else bash scripts/fixture_subject.sh; fi
LANE
branch_and_commit "$d" || { echo "FATAL: commit n21"; exit 10; }
run_check "$d"; expect "N21 dead then-arm, LIVE else-arm (one line) still EXECUTED" 0 'EXECUTED.*fixture_subject\.sh'

# N4 — GRANDFATHER control. A pre-existing unanchored script is MODIFIED, not added. If this ever
# blocks, the gate has silently become a whole-tree audit and the diff scope is a fiction.
d="$(new_repo n4)" || { echo "FATAL: fixture n4"; exit 10; }
printf '#!/usr/bin/env bash\necho legacy v2\n' > "$d/scripts/legacy_thing.sh"
branch_and_commit "$d" || { echo "FATAL: commit n4"; exit 10; }
run_check "$d"; expect "N4 grandfathered — modified-not-added stays out of scope" 0 'PASS \(0 in scope\)'

# N5 — EMPTY INPUT, asked as its own question. `all()` over an empty set is True and every
# aggregate predicate passes vacuously ([[feedback_not_found_is_not_zero_family]]), so the lane
# pins that the output SAYS the set was measured-and-empty rather than printing a bare green.
d="$(new_repo n5)" || { echo "FATAL: fixture n5"; exit 10; }
printf 'unrelated\n' > "$d/README.md"
branch_and_commit "$d" || { echo "FATAL: commit n5"; exit 10; }
run_check "$d"; expect "N5 empty scope — measured zero, labelled as such" 0 'measured zero, not an unrun scan'

# N6 — an added LANE FILE is not a subject. Whether anything runs IT is lane_runner_check.sh's
# question; double-owning it here would make the two checks disagree on the same file.
d="$(new_repo n6)" || { echo "FATAL: fixture n6"; exit 10; }
cat > "$d/scripts/test_orphan_lanes.sh" <<'LANE'
#!/usr/bin/env bash
echo "a lane nobody runs"
LANE
branch_and_commit "$d" || { echo "FATAL: commit n6"; exit 10; }
run_check "$d"; expect "N6 added lane file is out of subject scope" 0 'PASS \(0 in scope\)'

# N7 was the EXEMPT arm. It injected a BARE PATH and asserted a pass while its own label claimed
# "declared with a reason" — the lane was itself the evidence that the reason had no channel
# (codex, 2026-08-22). It is superseded by X1/X2 (reason-less and vacuous entries are refused) and
# N17 (a substantive reason passes), and is not kept as a duplicate.

echo ""
echo "── instrument-death lanes: could-not-measure must be 10, never 0 ───────────────────"
# The failure this repo keeps re-finding: an unresolvable base yields an empty diff, which is
# byte-identical to "nothing was added". If that folded to PASS, every future run would be green
# for the reason that the instrument was blind.

# E1 — an explicitly-set base that does not resolve.
d="$(new_repo e1)" || { echo "FATAL: fixture e1"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
branch_and_commit "$d" || { echo "FATAL: commit e1"; exit 10; }
OUT="$(cd "$d" && NEW_CODE_ANCHOR_BASE=no-such-ref bash scripts/new_code_anchor_check.sh 2>&1)"; RC=$?
expect "E1 unresolvable base → UNMEASURED, not PASS" 10 'UNMEASURED'

# E2 — no main/master at all. Same principle, reached by a different road.
d="$(new_repo e2)" || { echo "FATAL: fixture e2"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
branch_and_commit "$d" || { echo "FATAL: commit e2"; exit 10; }
git -C "$d" branch -m main not-a-default-name >/dev/null 2>&1
run_check "$d"; expect "E2 no resolvable default base → UNMEASURED" 10 'no base ref resolved'

echo ""
echo "── override channel: acknowledged is not resolved ──────────────────────────────────"
# The override must exit 0 AND still print the findings. An override that silences the output
# converts an acknowledgment into an erasure.
d="$(new_repo o1)" || { echo "FATAL: fixture o1"; exit 10; }
printf '%s' "$NEWSCRIPT" > "$d/scripts/fixture_subject.sh"
branch_and_commit "$d" || { echo "FATAL: commit o1"; exit 10; }
OUT="$(cd "$d" && NEW_CODE_ANCHOR_OK=1 bash scripts/new_code_anchor_check.sh 2>&1)"; RC=$?
if [ "$RC" = "0" ] && printf '%s' "$OUT" | grep -q 'NO_ANCHOR' && \
   printf '%s' "$OUT" | grep -q 'OVERRIDE ACCEPTED'; then
  ok "O1 override exits 0 but the findings still print"
else
  bad "O1 override arm — rc=$RC, or the findings/ack line were missing"
  printf '%s\n' "$OUT" | sed 's/^/        /'
fi

echo ""
echo "──────────────────────────────────────────────────────────────────────────────────"
echo "new-code-anchor lanes: PASS $PASS · FAIL $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
