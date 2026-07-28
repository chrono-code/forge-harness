#!/usr/bin/env bash
# test_memory_link_check.sh — known-pair anchor for scripts/memory_link_check.py.
#
# WHY: the checker's --fix-separators path WRITES to personal knowledge files. Everything it gets
# wrong, it gets wrong silently and in bulk. Two of its rules were found only by attacking it:
#   * a first draft rewrote links inside FENCED blocks — i.e. it "corrected" the examples that
#     document the convention, which is the probe-damages-the-remedy class;
#   * a first measurement counted cross-store links as broken, overstating the defect by 44%.
# Both are pinned below, alongside the classes.
#
# Lanes
#   C1  the five classes separate on a fixture (ok / separator / cross-store-absent / placeholder / dangling)
#   F1  a link inside a fenced block is COUNTED but never REWRITTEN
#   F2  a link inside inline backticks IS rewritten (this corpus styles real links that way —
#       measured 2026-07-28: 25 such links repaired, 0 fenced changes in the same run)
#   F3  aliased links [[target|alias]] keep their alias
#   F4  re-running the fixer changes nothing (idempotent)
#   G1  an empty store reports an extractor failure, never a clean graph
#
# Exit 0 = 6/6.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHK="$ROOT/scripts/memory_link_check.py"
[ -f "$CHK" ] || { echo "FAIL: $CHK missing"; exit 1; }

pass=0; fail=0
ok()  { printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  ❌ %s\n' "$1"; fail=$((fail+1)); }

TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
mkdir -p "$TD/store"
printf -- '---\nname: real_target\n---\nbody\n' > "$TD/store/real_target.md"
cat > "$TD/store/src.md" <<'EOF'
---
name: src
---
plain ok: [[real_target]]
plain separator: [[real-target]]
alias: [[real-target|shown as this]]
inline: `[[real-target]]`
dangling: [[nothing_here]]
placeholder: [[link]]

```
fenced example — must NOT be rewritten: [[real-target]]
```
EOF

_run() { python3 "$CHK" --memory "$TD/store" "$@" 2>/dev/null; }

out=$(_run)
# FIRST match only. `dangling` appears twice in the report — once as a count row and once as a
# section header ("dangling (nothing on disk...)") — so an unbounded match returned two lines and
# the numeric comparison silently failed against a correct tool. Instrument fault, fixed here.
_n() { printf '%s\n' "$out" | awk -v k="$1" '$1==k && $2 ~ /^[0-9]+$/ {print $2; exit}'; }
if [ "$(_n ok)" = "1" ] && [ "$(_n placeholder)" = "1" ] && [ "$(_n dangling)" = "1" ] && [ "$(_n separator)" -ge 4 ]; then
  ok "C1 classes separate (ok=$(_n ok) separator=$(_n separator) placeholder=$(_n placeholder) dangling=$(_n dangling))"
else
  bad "C1 class counts wrong"; printf '%s\n' "$out" | sed 's/^/     /'
fi

_run --fix-separators --quiet >/dev/null
body=$(cat "$TD/store/src.md")

if printf '%s' "$body" | sed -n '/```/,/```/p' | grep -q '\[\[real-target\]\]'; then
  ok "F1 fenced example left untouched (the documentation of the rule survives the fixer)"
else
  bad "F1 the fixer rewrote a link inside a fenced block — it corrected its own example"
fi

if printf '%s' "$body" | grep -q 'inline: `\[\[real_target\]\]`'; then
  ok "F2 inline-backticked link repaired (this store's citation style is a real link)"
else
  bad "F2 inline-backticked link was not repaired"
fi

if printf '%s' "$body" | grep -q '\[\[real_target|shown as this\]\]'; then
  ok "F3 alias preserved through the rewrite"
else
  bad "F3 alias lost or target not rewritten"
fi

before=$(cat "$TD/store/src.md")
_run --fix-separators --quiet >/dev/null
if [ "$before" = "$(cat "$TD/store/src.md")" ]; then
  ok "F4 idempotent on re-run"
else
  bad "F4 a second run changed the file again"
fi

mkdir -p "$TD/empty"
if python3 "$CHK" --memory "$TD/empty" >/dev/null 2>&1; then
  bad "G1 an empty store exited 0 — a scan that cannot see its subject reported a clean graph"
else
  ok "G1 empty store fails as an extractor error, not a pass"
fi

echo "----"
echo "memory-link-check anchor: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
