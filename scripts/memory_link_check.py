#!/usr/bin/env python3
"""memory_link_check.py — wikilink integrity over the memory graph.

WHY THIS EXISTS (measured 2026-07-28, 872 links across 210 notes)

`memory_intent_recall.md` makes the memory store a GRAPH: nodes are files, edges are `[[links]]`,
and recall walks one hop from an index hit. That doctrine is only as good as the edges. Nothing
checked them, and the first measurement found **50 edges pointing at a note that exists under a
different separator** (`[[feedback-pmh-issue-routing]]` while the file is
`feedback_pmh_issue_routing.md`) plus **22 pointing at nothing at all**. A 1-hop walk across a dead
edge returns nothing and looks exactly like "there is nothing related" — the failure is silent, and
it degrades the one mechanism that is supposed to surface a forgotten lesson.

Absorbed from obsidian-mind's `wikilinks.ts` (MIT, breferrari) — the concern, not the code.

TWO INSTRUMENT RULES LEARNED WHILE WRITING IT, both from wrong first numbers:

  1. RESOLVE ACROSS EVERY STORE THE AUTHOR CAN LINK INTO. A first pass scanned only the memory
     directory and reported 39 "missing". 17 of those resolve in the hub repo or the companion
     store — legitimate cross-store edges. Counting them as broken would have overstated the
     defect by 44% and sent someone hunting for files that are exactly where they belong.
  2. EXCLUDE THE DOC TEMPLATE. `[[link]]` / `[[name]]` appear inside prose that DESCRIBES the
     convention. Scoring the instructions as defects is the "probe flags its own remedy" class.

CLASSES (a link is exactly one)
  ok            resolves in the memory store as written
  separator     resolves after -/_ normalization — mechanically repairable, and the only class
                `--fix-separators` will touch
  cross-store   resolves in the hub repo or companion store — reported, never "fixed"
  placeholder   the convention's own example text
  dangling      resolves nowhere. A human decides: write the note, or drop the edge.

DEGRADE DIRECTION: advisory. This is a reversible surface (a memory edit is re-editable), so it
reports and never blocks. `--fix-separators` writes, and only for the one class where the target is
proven to exist.

Usage:
  python3 scripts/memory_link_check.py [--memory DIR] [--fix-separators] [--quiet]
Exit: 0 = scanned (always, unless the extractor itself broke) · 2 = extractor found no notes
"""
from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

LINK_RE = re.compile(r"\[\[([^\]|#]+)")
# Fenced blocks are QUOTED CONTENT — a `[[wrong-form]]` inside one is usually an example of the
# convention, and "fixing" it destroys the documentation that teaches the rule. Skipped on the
# write path only; they are still COUNTED, because a reader deserves to know they exist.
#
# Inline backticks are deliberately NOT skipped. Measured on this corpus (2026-07-28): 25 of the
# 150 repaired links sat inside inline code and every one was a real link the author had merely
# styled with backticks — that is this store's citation convention. Fenced-block changes in the
# same run: 0. So the two spans are not the same thing here, and treating them alike would either
# damage examples (skip nothing) or leave a quarter of the dead edges dead (skip both).
FENCE_RE = re.compile(r"```.*?```", re.S)
PLACEHOLDERS = {"link", "name", "their-name"}
def default_memory() -> Path | None:
    """Locate this project's Claude-Code memory dir WITHOUT hard-coding a username or path.

    Claude Code stores per-project memory under ~/.claude/projects/<encoded-abs-path>/memory, and
    the encoding maps path separators to '-', so it differs per user and per OS. Globbing the
    encoded tail (parent + project folder) is portable AND keeps an operator's real home path out
    of a public file — the confidentiality gate rejected the first draft of this line for exactly
    that reason, which is the gate working.
    """
    root = Path(__file__).resolve().parents[1]
    tail = f"{root.parent.name}-{root.name}"
    base = Path.home() / ".claude/projects"
    if not base.is_dir():
        return None
    for d in sorted(base.glob(f"*{tail}")):
        if (d / "memory").is_dir():
            return d / "memory"
    return None


def extra_roots() -> list[Path]:
    """Other stores an author may legitimately link into.

    The hub itself, plus any sibling store named by MEMORY_LINK_EXTRA_ROOTS (colon-separated).
    A private companion store is NOT named here: its name is operator configuration, not a
    property of this tool, and embedding it would publish a private repo name.
    """
    import os
    roots = [Path(__file__).resolve().parents[1]]
    for raw in filter(None, os.environ.get("MEMORY_LINK_EXTRA_ROOTS", "").split(":")):
        roots.append(Path(raw).expanduser())
    return [r for r in roots if r.is_dir()]


def norm(s: str) -> str:
    return s.replace("-", "_").lower()


def build_index(memory: Path) -> dict[str, tuple[str, str]]:
    idx: dict[str, tuple[str, str]] = {}
    for p in sorted(memory.glob("*.md")):
        idx.setdefault(norm(p.stem), ("memory", p.name))
    for root in extra_roots():
        for p in root.rglob("*.md"):
            if ".git" in p.parts:
                continue
            idx.setdefault(norm(p.stem), (root.name, str(p.relative_to(root))))
    return idx


def classify(target: str, memory: Path, idx: dict) -> str:
    t = target.strip()
    if t in PLACEHOLDERS:
        return "placeholder"
    if (memory / f"{t}.md").exists():
        return "ok"
    hit = idx.get(norm(t))
    if hit is None:
        return "dangling"
    return "separator" if hit[0] == "memory" else "cross-store"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--memory", type=Path, default=None)
    ap.add_argument("--fix-separators", action="store_true",
                    help="rewrite ONLY the separator class, whose target is proven to exist")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()

    memory = a.memory or default_memory()
    if memory is None or not memory.is_dir():
        print(f"memory-link-check: SKIP (no memory dir at {memory})")
        return 0
    notes = sorted(memory.glob("*.md"))
    if not notes:
        # Impossible-zero guard: a store with no notes means the path or glob broke. A scan that
        # cannot see its subject must not report a clean graph.
        print("memory-link-check: FAIL — 0 notes found; the scan broke, it did not pass", file=sys.stderr)
        return 2

    idx = build_index(memory)
    counts: Counter[str] = Counter()
    dangling: list[tuple[str, str]] = []
    seps: list[tuple[Path, str, str]] = []

    for p in notes:
        text = p.read_text(encoding="utf-8", errors="ignore")
        for raw in LINK_RE.findall(text):
            t = raw.strip()
            k = classify(t, memory, idx)
            counts[k] += 1
            if k == "dangling":
                dangling.append((p.name, t))
            elif k == "separator":
                seps.append((p, t, idx[norm(t)][1][:-3]))

    total = sum(counts.values())
    if not a.quiet:
        print(f"memory-link-check: {len(notes)} notes · {total} links")
        for k in ("ok", "separator", "cross-store", "placeholder", "dangling"):
            print(f"  {k:12s} {counts[k]}")
        if dangling:
            print("\n  dangling (nothing on disk answers these — write the note, or drop the edge):")
            for t, n in Counter(t for _, t in dangling).most_common():
                print(f"    {n}x  [[{t}]]")

    if a.fix_separators and seps:
        touched, skipped = 0, 0
        for p in {s[0] for s in seps}:
            text = p.read_text(encoding="utf-8")
            # Split on fenced blocks and rewrite only the parts OUTSIDE them, then rejoin. Doing it
            # by span keeps the fence contents byte-identical instead of relying on the replacement
            # string being unique.
            parts, last, out = [], 0, []
            for m in FENCE_RE.finditer(text):
                parts.append((text[last:m.start()], True))
                parts.append((m.group(0), False))
                last = m.end()
            parts.append((text[last:], True))
            for chunk, editable in parts:
                if editable:
                    for _, wrong, right in [s for s in seps if s[0] == p]:
                        chunk = chunk.replace(f"[[{wrong}]]", f"[[{right}]]")
                        chunk = chunk.replace(f"[[{wrong}|", f"[[{right}|")
                else:
                    skipped += sum(chunk.count(f"[[{s[1]}") for s in seps if s[0] == p)
                out.append(chunk)
            p.write_text("".join(out), encoding="utf-8")
            touched += 1
        print(f"\n  fixed {len(seps) - skipped} separator link(s) across {touched} file(s)"
              + (f"; left {skipped} inside fenced blocks (quoted examples)" if skipped else ""))
    elif seps and not a.quiet:
        print(f"\n  {len(seps)} separator link(s) are mechanically repairable → --fix-separators")
    return 0


if __name__ == "__main__":
    sys.exit(main())
