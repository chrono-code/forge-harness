#!/usr/bin/env bash
# finding_fleet.sh — run a parallel, multi-family review fleet over one file and emit TYPED findings.
#
# WHY. FH's review output has always been prose, so nothing downstream could count it, filter it, or
# hand it to a second opinion. Measured 2026-09-08 over eight GHSA cases x3: FH made 52 claims with 5
# wrong about the code (9.6%); a sibling harness made 73 -- 40% more -- with 2 wrong (2.7%). The gap
# was not reading quality. That harness emits findings as typed records, has a different family stamp
# each one, and deletes the false positives with a filter. This script is the first half of that shape
# for FH: fan out to several families in parallel, each returning JSONL. The second half, the reject
# stage, is scripts/finding_verify.py, and it refuses to let a family verify its own findings.
#
# WHAT IS MECHANIZED: that each finding carries the family and role that produced it, that the members
# run in parallel and independently, and that a member which fails is recorded as failed rather than
# quietly contributing nothing. WHAT IS NOT: what counts as a defect. No rule about findings lives here.
#
# FLEET TABLE. One member per line, `family|role|command`. The command receives the review prompt BOTH
# on stdin and as a file whose path replaces the token PROMPT_FILE in the command — some CLIs take the
# prompt as an argument and their -p flag is variadic, so piping it silently turns the next flag into
# the prompt (measured 2026-09-08: `agy -p --model X` sent "--model" as the prompt and reported it).
# Must print JSONL findings on stdout. Override with --fleet <file>; the default is two external
# families so that neither is the Claude governor calling this script.
#
# Usage:  bash scripts/finding_fleet.sh <target-file> --out <dir> [--fleet <table>] [--roles-only]
#         bash scripts/finding_fleet.sh --selftest
# Exit:   0 = at least one member returned findings · 1 = all members failed (nothing was reviewed)
#         2 = usage error
set -uo pipefail
export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"
# Binaries are resolved from PATH, then from the usual install roots. Never hard-code a home path:
# this file ships in the npm package and a literal home directory is both a leak and wrong on the
# consumer's machine. Override with FH_CODEX_BIN / FH_AGY_BIN.
CODEX="${FH_CODEX_BIN:-$(command -v codex 2>/dev/null || echo "$HOME/.npm-global/bin/codex")}"
AGY="${FH_AGY_BIN:-$(command -v agy 2>/dev/null || echo "$HOME/.local/bin/agy")}"

default_fleet() {
  cat <<'EOF'
codex|logic|CODEX_BIN exec --sandbox read-only --skip-git-repo-check -m gpt-6-astra -c model_reasoning_effort="high"
gemini|security|AGY_BIN --model gemini-3.8-flash-high --output-format text --print-timeout 5m -p "$(cat PROMPT_FILE)"
EOF
}

PROMPT_HEAD='You are one reviewer in a parallel fleet. Review the file below for defects in your assigned area.

Output ONLY JSON Lines, one object per finding, nothing else — no prose, no code fences:
{"title":"<short claim>","file":"<name>","line":<int>,"severity":"S|A|B","category":"<one word>","detail":"<what goes wrong and when>","confidence":<0.0-1.0>}

S = exploitable or fail-open. A = real but non-blocking. B = minor.
Report only defects you can point to a specific line for. If you find none, output nothing.

Your assigned area: '

run_member() { # $1=family $2=role $3=command $4=target $5=outdir
  local fam="$1" role="$2" cmd="$3" tgt="$4" out="$5"
  cmd="${cmd//CODEX_BIN/$CODEX}"; cmd="${cmd//AGY_BIN/$AGY}"
  local raw="$out/raw_${fam}_${role}.txt" pf="$out/prompt_${fam}_${role}.txt"
  { printf '%s%s\n\n===== FILE: %s =====\n' "$PROMPT_HEAD" "$role" "$(basename "$tgt")"; cat "$tgt"; } > "$pf"
  cmd="${cmd//PROMPT_FILE/$pf}"
  eval "$cmd" < "$pf" > "$raw" 2>"$out/err_${fam}_${role}.txt"
  local rc=$?
  FAM="$fam" ROLE="$role" RC="$rc" /usr/bin/python3 - "$raw" "$out/part_${fam}_${role}.jsonl" <<'PY'
import json, os, sys
fam, role, rc = os.environ["FAM"], os.environ["ROLE"], os.environ["RC"]
src, dst = sys.argv[1], sys.argv[2]
n = 0
with open(dst, "w", encoding="utf-8") as w:
    for line in open(src, encoding="utf-8", errors="replace"):
        line = line.strip().lstrip("﻿")
        if not line.startswith("{"):
            continue                      # tolerate banners and fences around the JSONL
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not d.get("title"):
            continue
        n += 1
        d["id"] = f"{fam}-{role}-{n}"
        d["producer_family"] = fam
        d["producer_role"] = role
        w.write(json.dumps(d, ensure_ascii=False) + "\n")
print(f"MEMBER family={fam} role={role} rc={rc} findings={n}")
PY
}

selftest() {
  local d fails; d="$(mktemp -d 2>/dev/null)" || d=""
  [ -n "$d" ] && [ -w "$d" ] || { echo "SELFTEST: ENV-BLOCKED (mktemp -d failed) — unmeasured, not a pass"; return 3; }
  printf 'def f(x):\n    return x\n' > "$d/t.py"
  local fails=0
  # Stub members are real scripts: they must consume stdin (a member that ignores it dies of SIGPIPE
  # on a large file, which is a property of the harness, not of the member) and then print.
  cat > "$d/m_ok.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"title":"t","file":"t.py","line":1,"severity":"B","confidence":0.5}'
EOS
  cat > "$d/m_prose.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo "I reviewed it and it looks fine to me."
EOS
  cat > "$d/m_fail.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
exit 1
EOS
  chmod +x "$d/m_ok.sh" "$d/m_prose.sh" "$d/m_fail.sh"
  printf 'stub|logic|sh %s\n' "$d/m_ok.sh" > "$d/fleet"
  bash "$0" "$d/t.py" --out "$d/o1" --fleet "$d/fleet" >/dev/null 2>&1
  if [ -s "$d/o1/findings.jsonl" ] && /usr/bin/grep -q '"producer_family": "stub"' "$d/o1/findings.jsonl"; then
    echo "  ✅ known-positive: a member's JSONL survives and is tagged with its family"
  else echo "  ❌ known-positive parse/tag"; fails=1; fi
  printf 'proser|logic|sh %s\n' "$d/m_prose.sh" > "$d/fleet2"
  bash "$0" "$d/t.py" --out "$d/o2" --fleet "$d/fleet2" >/dev/null 2>&1
  if [ ! -s "$d/o2/findings.jsonl" ]; then echo "  ✅ known-negative: prose contributes no findings"
  else echo "  ❌ known-negative: prose leaked into findings"; fails=1; fi
  printf 'faily|logic|sh %s\n' "$d/m_fail.sh" > "$d/fleet3"
  bash "$0" "$d/t.py" --out "$d/o3" --fleet "$d/fleet3" >/dev/null 2>&1
  if /usr/bin/grep -q 'rc=1' "$d/o3/members.txt" 2>/dev/null; then echo "  ✅ failing member recorded with its exit code"
  else echo "  ❌ failing member not recorded"; fails=1; fi
  if [ ! -s "$d/o3/findings.jsonl" ] && ! bash "$0" "$d/t.py" --out "$d/o4" --fleet "$d/fleet3" >/dev/null 2>&1; then
    echo "  ✅ all-members-failed exits non-zero (empty list must not read as clean)"
  else echo "  ❌ all-members-failed did not exit non-zero"; fails=1; fi
  /bin/rm -rf "$d"
  [ "$fails" -eq 0 ] && { echo "SELFTEST: PASS"; return 0; } || { echo "SELFTEST: FAIL"; return 1; }
}

[ $# -ge 1 ] || { echo "usage: $0 <target-file> --out <dir> [--fleet <table>] | --selftest" >&2; exit 2; }
[ "$1" = "--selftest" ] && { selftest; exit $?; }
TARGET="$1"; shift
OUT=""; FLEET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="${2:-}"; shift 2 ;;
    --fleet) FLEET="${2:-}"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 2; }
[ -n "$OUT" ] || { echo "--out is required" >&2; exit 2; }
mkdir -p "$OUT"
if [ -n "$FLEET" ]; then cp "$FLEET" "$OUT/fleet.txt"; else default_fleet > "$OUT/fleet.txt"; fi

: > "$OUT/members.txt"
while IFS='|' read -r fam role cmd; do
  [ -n "${fam:-}" ] || continue
  case "$fam" in \#*) continue ;; esac
  run_member "$fam" "$role" "$cmd" "$TARGET" "$OUT" >> "$OUT/members.txt" 2>&1 &
done < "$OUT/fleet.txt"
wait

cat "$OUT"/part_*.jsonl > "$OUT/findings.jsonl" 2>/dev/null || : > "$OUT/findings.jsonl"
TOTAL=$(/usr/bin/wc -l < "$OUT/findings.jsonl" | /usr/bin/tr -d ' ')
MEMBERS=$(/usr/bin/wc -l < "$OUT/fleet.txt" | /usr/bin/tr -d ' ')
OK=$(/usr/bin/grep -c 'rc=0' "$OUT/members.txt" 2>/dev/null); OK=${OK:-0}   # 🟥 never `|| echo 0` here: grep prints 0 AND the fallback echoes 0, giving "0\n0"
echo "FLEET members=$MEMBERS ok=$OK findings=$TOTAL out=$OUT"
cat "$OUT/members.txt"
[ "$OK" -gt 0 ] || { echo "🟥 every member failed — nothing was reviewed, and an empty finding list here means UNREVIEWED, not clean"; exit 1; }
exit 0
