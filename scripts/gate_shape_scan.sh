#!/usr/bin/env bash
# gate_shape_scan.sh — is this file «gate-shaped»? The mechanical half of the Field-Harness
# Load-Bearing Change Gate trigger for files whose project is NOT mapped (CLAUDE.md
# §Field-Harness Load-Bearing Change Gate · field_verdict_crossfamily_gate.md
# §Registration is not a precondition, 2026-09-08).
#
# IT IS A CLASSIFIER OF THE FILE'S SHAPE, NOT A VERDICT ON THE FILE. A hit means «this file is
# in the gate's scope — run degrade-lint + cross-family before a merge verdict». A miss means
# «not in scope by identifier»; the task's own naming of the file as gate/auth/exposure code is a
# separate MANUAL escalation and is not read here (a prompt is not a property of the file).
#
# What counts (three classes — each hit is printed with the class and the matched line):
#   VERDICT   word-bounded, case-insensitive: allow(ed) deny denied permit(ted) approve/approved/approval
#             verdict permission(s) auth authn authz authorize(d) authorization authenticat* auth_<x>
#             (🟥 `author`/`authored`/`allowance` do NOT match — the auth branch is a closed list, not `auth.*`)
#             (🟥 `reject` is deliberately absent — it collides with the Promise API `reject(err)`,
#              measured on a real TS mock server: 2 hits, both Promise callbacks. Named residual:
#              a gate that spells its refusal `reject(` is missed by this class; `deny` is not.)
#             permission auth authn authz  ·  plus the UPPERCASE enum literals PASS FAIL BLOCK
#             (uppercase only — lowercase `pass`/`fail`/`block` are ordinary words/keywords)
#   EXPOSURE  a socket/server bind or listen: listen( bind( ListenAndServe Serve( 0.0.0.0 INADDR_ANY
#   IRREV     an irreversible-op path: publish( delete( unlink( rm -rf force-push --force
#             history-rewrite filter-branch reset --hard
# Comment/string handling (named residual, crude on purpose): a line whose first non-blank
# characters are `#`, `//`, `* ` (star+space/end: block-comment body), `/*`, `-- ` (dash-dash+space/end:
# SQL/Lua), `;`, `"""`, `'''` is skipped; `*allow = 1` and a continued `--force` line are CODE and scanned. Inline trailing comments
# and string literals are NOT stripped — a false positive here costs one review, a false negative
# costs a missed gate, so the scan leans toward firing.
# Supported: any text file. Binary or unreadable → UNSCANNABLE (exit 3), never a silent miss.
#
# Usage:  bash scripts/gate_shape_scan.sh <file> [file ...]
#         bash scripts/gate_shape_scan.sh --selftest        # known-pair calibration
# Exit:   0 = GATE-SHAPED (≥1 hit, all files scannable) · 1 = NOT-GATE-SHAPED · 3 = UNSCANNABLE/usage
#         (3 dominates 0: a hit next to an unscannable file still exits 3 — that file is unresolved)
set -uo pipefail
export LC_ALL=C
VERDICT_RE='\b(allow(ed)?|deny|denied|permit(ted)?|approv(e|ed|al)|verdict|permissions?|auth(n|z|orize|orized|orization|entic[a-z]*|_[a-z_]+)?)\b'
ENUM_RE='\b(PASS|FAIL|BLOCK)\b'
EXPOSURE_RE='(\blisten\(|\bbind\(|ListenAndServe|\bServe\(|0\.0\.0\.0|INADDR_ANY)'
IRREV_RE='(\bpublish\(|\bdelete\(|\bunlink\(|rm -rf|force-push|--force\b|history-rewrite|filter-branch|reset --hard)'
COMMENT_RE='^[[:space:]]*(#|//|\*([[:space:]]|$)|/\*|--([[:space:]]|$)|;|"""|'"'''"')'

scan_one() { # $1=file → prints hits, returns 0 hit / 1 none / 3 unscannable
  local f="$1" body v e r hits
  [ -r "$f" ] || { echo "UNSCANNABLE  $f (unreadable)"; return 3; }
  if /usr/bin/file -b --mime-encoding "$f" 2>/dev/null | /usr/bin/grep -q '^binary$'; then
    echo "UNSCANNABLE  $f (binary)"; return 3; fi
  # one pass: drop comment-led lines, then classify (VERDICT wins over EXPOSURE over IRREV per line)
  body=$(/usr/bin/grep -nEv "$COMMENT_RE" "$f" 2>/dev/null || true)
  v=$(printf '%s\n' "$body" | /usr/bin/grep -Ei "$VERDICT_RE" || true)
  v2=$(printf '%s\n' "$body" | /usr/bin/grep -E "$ENUM_RE" || true)
  e=$(printf '%s\n' "$body" | /usr/bin/grep -E "$EXPOSURE_RE" || true)
  r=$(printf '%s\n' "$body" | /usr/bin/grep -E "$IRREV_RE" || true)
  hits=0
  [ -n "$v" ]  && { hits=1; printf '%s\n' "$v"  | /usr/bin/cut -c1-140 | /usr/bin/sed "s|^|VERDICT   $f:|"; }
  [ -n "$v2" ] && { hits=1; printf '%s\n' "$v2" | /usr/bin/cut -c1-140 | /usr/bin/sed "s|^|VERDICT   $f:|"; }
  [ -n "$e" ]  && { hits=1; printf '%s\n' "$e"  | /usr/bin/cut -c1-140 | /usr/bin/sed "s|^|EXPOSURE  $f:|"; }
  [ -n "$r" ]  && { hits=1; printf '%s\n' "$r"  | /usr/bin/cut -c1-140 | /usr/bin/sed "s|^|IRREV     $f:|"; }
  [ "$hits" -gt 0 ] && return 0 || return 1
}

selftest() { # known pair — positive must hit, negative must not, comment-only must not
  local d rc_pos rc_pos2 rc_neg rc_cmt rc_bin rc_irr rc_bnd rc_star fails=0
  d="$(mktemp -d 2>/dev/null)" || d=""
  [ -n "$d" ] && [ -w "$d" ] || { echo "SELFTEST: ENV-BLOCKED (mktemp -d failed) — result unmeasured, not a pass"; return 3; }
  printf 'export class S {\n  start() {\n    this.app.listen(this.config.port, () => {});\n  }\n}\n' > "$d/pos_exposure.ts"
  printf 'def check(user):\n    if user.role == "admin":\n        return Verdict.ALLOW\n    return Verdict.DENY\n' > "$d/pos_verdict.py"
  printf 'def add(a, b):\n    """Return the sum. Pass through ints."""\n    return a + b\n\ndef fmt(x):\n    return f"{x:.2f}"\n' > "$d/neg_util.py"
  printf '# we allow anything here\n// auth is elsewhere\n/* listen( is not called */\n * allow: block-comment body\n-- deny in a SQL comment\nx = 1\n' > "$d/neg_comments.py"
  printf '\x00\x01\x02binary\x00' > "$d/bin.dat"
  printf 'set -e\ngit push origin main \\\n  --force\n' > "$d/pos_irrev.sh"
  printf 'authored_by = "x"\nallowance = 3\nauthor = "y"\n' > "$d/neg_boundary.py"
  printf 'int f(int *allow) {\n  *allow = 1;\n  return 0;\n}\n' > "$d/pos_star.c"
  scan_one "$d/pos_exposure.ts" >/dev/null; rc_pos=$?
  scan_one "$d/pos_verdict.py"  >/dev/null; rc_pos2=$?
  scan_one "$d/neg_util.py"     >/dev/null; rc_neg=$?
  scan_one "$d/neg_comments.py" >/dev/null; rc_cmt=$?
  scan_one "$d/bin.dat"         >/dev/null; rc_bin=$?
  scan_one "$d/pos_irrev.sh"    >/dev/null; rc_irr=$?
  scan_one "$d/neg_boundary.py" >/dev/null; rc_bnd=$?
  scan_one "$d/pos_star.c"      >/dev/null; rc_star=$?
  [ "$rc_pos" -eq 0 ]  && echo "  ✅ known-positive exposure (listen()) → GATE-SHAPED"      || { echo "  ❌ known-positive exposure rc=$rc_pos"; fails=1; }
  [ "$rc_pos2" -eq 0 ] && echo "  ✅ known-positive verdict (ALLOW/DENY) → GATE-SHAPED"    || { echo "  ❌ known-positive verdict rc=$rc_pos2"; fails=1; }
  [ "$rc_neg" -eq 1 ]  && echo "  ✅ known-negative util (docstring 'Pass') → NOT"          || { echo "  ❌ known-negative util rc=$rc_neg"; fails=1; }
  [ "$rc_cmt" -eq 1 ]  && echo "  ✅ comment-only mentions (#, //, /*, ' * ', '-- ') → NOT"                            || { echo "  ❌ comment-only rc=$rc_cmt"; fails=1; }
  [ "$rc_bin" -eq 3 ]  && echo "  ✅ binary → UNSCANNABLE (not a silent miss)"              || { echo "  ❌ binary rc=$rc_bin"; fails=1; }
  [ "$rc_irr" -eq 0 ]  && echo "  ✅ known-positive irreversible (continued --force line) → GATE-SHAPED" || { echo "  ❌ known-positive irrev rc=$rc_irr"; fails=1; }
  [ "$rc_bnd" -eq 1 ]  && echo "  ✅ boundary: author/authored/allowance → NOT"                || { echo "  ❌ boundary rc=$rc_bnd"; fails=1; }
  [ "$rc_star" -eq 0 ] && echo "  ✅ code line starting with *allow (not a comment) → GATE-SHAPED" || { echo "  ❌ star-code rc=$rc_star"; fails=1; }
  /bin/rm -rf "$d"
  [ "$fails" -eq 0 ] && { echo "SELFTEST: PASS"; return 0; } || { echo "SELFTEST: FAIL"; return 3; }
}

[ $# -ge 1 ] || { echo "usage: $0 <file> [file ...] | --selftest" >&2; exit 3; }
[ "$1" = "--selftest" ] && { selftest; exit $?; }
ANY=0; UNS=0
for f in "$@"; do scan_one "$f"; rc=$?; [ "$rc" -eq 0 ] && ANY=1; [ "$rc" -eq 3 ] && UNS=1; done
if [ "$UNS" -eq 1 ]; then
  [ "$ANY" -eq 1 ] && echo "GATE-SHAPED in the scannable files —"
  echo "UNSCANNABLE — ≥1 file could not be classified; decide those by hand. Exit 3 dominates any hit (never a silent miss)"; exit 3
elif [ "$ANY" -eq 1 ]; then echo "GATE-SHAPED — run degrade-lint + cross-family before a merge verdict"; exit 0
else echo "NOT-GATE-SHAPED (by identifier; the task's own naming is a separate manual escalation)"; exit 1; fi
