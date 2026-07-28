#!/usr/bin/env python3
"""nearcheck.py — read-only near-duplicate probe over a markdown memory store.

Design absorbed from obsidian-mind's `memory-similarity.ts` (MIT, breferrari) — the PROPOSITIONS,
not the code:
  * lexical, not semantic. An embedding call on the write hot path costs latency and money, and
    the failure being prevented is the LITERAL re-record (a session restating a lesson in nearly
    the same words), not two genuinely different phrasings. Semantics is what RECALL is for.
  * facet-gated: two notes are only comparable when their declared reach overlaps.
  * pure: no IO in the scoring core, so it can be calibrated on fixtures.

DEVIATION, and why: obsidian-mind tokenizes on word boundaries. This corpus is majority KOREAN,
where whitespace tokens are morphologically inflected and word-level overlap under-reports badly —
the same failure class this repo already measured (an ASCII-token scanner over a Korean corpus
produced ~96% false positives). So the shingles here are CHARACTER 3-grams over NFC-normalized,
markup-stripped text, which is script-agnostic.

READ-ONLY. Writes nothing. Exit 0 always — this is a measurement, not a gate.
"""
from __future__ import annotations
import re, sys, unicodedata
from pathlib import Path
from itertools import combinations

N = 3          # character shingle size
TOP = 40       # how many pairs to print

def strip_markup(t: str) -> str:
    t = re.sub(r"```.*?```", " ", t, flags=re.S)      # fenced code
    t = re.sub(r"`[^`]*`", " ", t)                    # inline code
    t = re.sub(r"\[\[([^\]]*)\]\]", r"\1", t)         # wikilinks -> text
    t = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", t)    # md links -> text
    t = re.sub(r"https?://\S+", " ", t)
    t = re.sub(r"[#*_>|\-–—·:;,.!?()\[\]{}\"'`~^=+/\\]", " ", t)
    return re.sub(r"\s+", " ", t).strip()

def parse(p: Path) -> dict:
    raw = p.read_text(encoding="utf-8", errors="ignore")
    fm, body = {}, raw
    if raw.startswith("---"):
        end = raw.find("\n---", 3)
        if end > 0:
            for line in raw[3:end].splitlines():
                if ":" in line and not line.startswith(" "):
                    k, v = line.split(":", 1)
                    fm[k.strip()] = v.strip().strip('"')
            body = raw[end + 4 :]
    return {
        "path": p,
        "name": fm.get("name", p.stem),
        "desc": fm.get("description", ""),
        "type": fm.get("type", ""),
        "body": unicodedata.normalize("NFC", strip_markup(body)),
    }

def shingles(t: str) -> set[str]:
    t = t.replace(" ", "")
    return {t[i : i + N] for i in range(max(0, len(t) - N + 1))}

def jaccard(a: set, b: set) -> float:
    if not a or not b:
        return 0.0
    inter = len(a & b)
    return inter / (len(a) + len(b) - inter)

def containment(a: set, b: set) -> float:
    """Asymmetric: how much of the SMALLER note is inside the larger.

    Jaccard alone under-reports the case that matters most here — a short lesson later restated
    inside a longer note.

    SIZE-GATED (repaired 2026-07-28 after the probe's first run): without the gate this metric
    SATURATES on size-asymmetric pairs. Korean character 3-grams have a very high base rate
    (inflectional endings and particles recur everywhere), so a 22 KB note "contains" almost every
    short note's shingles and the top of the ranking became one large file paired with everything.
    Hand-check that killed it: user_role.md (658 B, "user is a QA engineer") scored 0.80 against a
    22 KB provenance note. Not a near-duplicate by any reading — an instrument artifact.
    A restatement worth flagging is of COMPARABLE size; a short note swallowed by a long one is
    the containment metric measuring the alphabet, not the content.
    """
    if not a or not b:
        return 0.0
    small, large = (a, b) if len(a) <= len(b) else (b, a)
    if len(small) < 0.34 * len(large):
        return 0.0
    return len(small & large) / len(small)

def main(argv):
    root = Path(argv[1])
    docs = [parse(p) for p in sorted(root.glob("*.md"))
            if p.name not in {"MEMORY.md", "MEMORY_archive.md"}]
    if not docs:
        print("EXTRACTOR_BROKE: 0 documents parsed — the probe did not run", file=sys.stderr)
        return 2
    # Corpus-frequency filter — the second half of the same repair. A shingle present in most
    # notes carries no evidence of duplication; it is this corpus's alphabet. Dropping the common
    # band is the lexical equivalent of a stopword list, derived rather than hand-listed so it
    # transfers to a corpus in any script.
    from collections import Counter
    df = Counter()
    for d in docs:
        d["sh_raw"] = shingles(d["body"])
        df.update(d["sh_raw"])
    cutoff = max(2, int(0.15 * len(docs)))
    common = {g for g, n in df.items() if n > cutoff}
    for d in docs:
        d["sh"] = d["sh_raw"] - common
        d["shd"] = shingles(d["desc"]) - common

    empty = [d["path"].name for d in docs if len(d["sh"]) < 20]
    pairs = []
    for a, b in combinations(docs, 2):
        j = jaccard(a["sh"], b["sh"])
        c = containment(a["sh"], b["sh"])
        jd = jaccard(a["shd"], b["shd"])
        if j >= 0.25 or c >= 0.55 or jd >= 0.45:
            pairs.append((max(j, c), j, c, jd, a, b))
    pairs.sort(key=lambda t: -t[0])

    print(f"scanned: {len(docs)} notes  (skipped index files)")
    print(f"corpus-common shingles dropped: {len(common)} (present in >{cutoff} notes)")
    print(f"too-short-to-score (<20 shingles): {len(empty)}" + (f" → {empty}" if empty else ""))
    print(f"candidate pairs above threshold: {len(pairs)}\n")
    for score, j, c, jd, a, b in pairs[:TOP]:
        print(f"[{score:.2f}] jac={j:.2f} cont={c:.2f} desc={jd:.2f}")
        print(f"    A {a['path'].name}")
        print(f"    B {b['path'].name}")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
