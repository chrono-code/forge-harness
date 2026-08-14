#!/usr/bin/env bash
# version_lockstep_check.sh — every shipped manifest must carry package.json's version.
#
# Why this exists (measured 2026-08-06, while republishing 1.4.88 → 1.4.89):
# CLAUDE.md §④-b says to bump "package.json + every .claude-plugin/plugin.json + marketplace.json".
# That instruction reads as four files, but `.claude-plugin/marketplace.json` carries **one version
# per plugin entry** — five strings across four files. A bump that edited the first entry left the
# second at the old version, and `test_tag_version_lanes.sh` passed 8/8 anyway: that lane compares
# the git TAG to package.json and never opens marketplace.json. The stale entry was caught by an
# ad-hoc `sort | uniq -c`, i.e. by luck, not by an instrument.
#
# Codex caches plugins on the plugin.json version, so a stale entry ships a plugin that the other
# runtime believes it already has — the drift is silent on exactly the surface that cannot report it.
#
# Exit 0 = all aligned · exit 1 = drift (names every offending file:line) · exit 2 = harness error
# (a manifest is missing or unparseable — NOT a pass; an instrument that could not look has not
# looked, and this gate guards an irreversible surface).

set -uo pipefail
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

command -v python3 >/dev/null 2>&1 || { echo "LOCKSTEP: HARNESS-ERROR — python3 unavailable"; exit 2; }

python3 - "$ROOT" <<'PY'
import json, sys, glob, os, re
root = sys.argv[1]
pkg_path = os.path.join(root, 'package.json')
try:
    want = json.load(open(pkg_path))['version']
except Exception as e:
    print(f"LOCKSTEP: HARNESS-ERROR — cannot read {pkg_path}: {e}")
    sys.exit(2)

# (path, list-of-(label, version)) — every manifest that ships a version string.
targets = []
for p in sorted(glob.glob(os.path.join(root, 'plugins', '*', '.claude-plugin', 'plugin.json'))):
    targets.append(p)
mk = os.path.join(root, '.claude-plugin', 'marketplace.json')
if os.path.exists(mk):
    targets.append(mk)

if not targets:
    # Absence is not alignment. If the manifests vanished, say so rather than reporting a clean run.
    print("LOCKSTEP: HARNESS-ERROR — no plugin/marketplace manifest found; alignment is UNKNOWN, not aligned")
    sys.exit(2)

drift, checked = [], 0
for p in targets:
    try:
        d = json.load(open(p))
    except Exception as e:
        print(f"LOCKSTEP: HARNESS-ERROR — cannot parse {p}: {e}")
        sys.exit(2)
    rel = os.path.relpath(p, root)
    # A manifest carries a version either at the top level (plugin.json) or once per plugin entry
    # (marketplace.json). Walk both shapes so a new entry cannot be silently uncovered.
    found = []
    if isinstance(d.get('version'), str):
        found.append(('(top-level)', d['version']))
    for key in ('plugins', 'entries'):
        for i, ent in enumerate(d.get(key) or []):
            if isinstance(ent, dict) and isinstance(ent.get('version'), str):
                found.append((f"{key}[{i}] {ent.get('name', '?')}", ent['version']))
    if not found:
        print(f"LOCKSTEP: HARNESS-ERROR — {rel} carries no version string; expected at least one")
        sys.exit(2)
    for label, got in found:
        checked += 1
        if got != want:
            drift.append(f"  {rel} :: {label} = {got}  (package.json = {want})")

# ── CHANGELOG is a shipped version surface too, and it was outside this check ─────────────────
# Measured 2026-08-13, by a peer session, AFTER 1.4.97 was already published: the four JSON
# manifests all read 1.4.97 and plugins/fh-meta/CHANGELOG.md's newest entry was still [1.4.96].
# So the tarball a consumer downloads carries a changelog with no entry for the version they just
# installed — six merged PRs invisible on the record surface. This check reported PASS while that
# was true, because its target list was "manifests carrying a JSON version field" rather than
# "surfaces that state which version this is".
# ★ That is the half-fix propagation boundary in its purest form: the version was updated
# everywhere the CHECK looked, which is not the same set as everywhere it MATTERS.
# Non-blocking is deliberate and narrow: a missing entry is a documentation gap, not a broken
# package, and turning a publish red on prose would train the override this repo has already
# measured people reaching for. It is LOUD, it names the file, and it is impossible to miss in the
# publish output — which is what the JSON drift arms could not have been, since those genuinely
# break installs.
CHANGELOGS = sorted(glob.glob(os.path.join(root, 'plugins', '*', 'CHANGELOG.md')))
for p in CHANGELOGS:
    rel = os.path.relpath(p, root)
    try:
        txt = open(p, encoding='utf-8', errors='replace').read()
    except OSError as e:
        print(f"LOCKSTEP: HARNESS-ERROR — cannot read {rel}: {e}")
        sys.exit(2)
    # The heading form this repo uses: `### [x.y.z] — DATE`. Absence of ANY such heading means the
    # extractor stopped matching the file's real shape — report that rather than a clean run.
    heads = re.findall(r'^#+\s*\[(\d+\.\d+\.\d+)\]', txt, re.M)
    if not heads:
        print(f"LOCKSTEP: HARNESS-ERROR — {rel} has no `[x.y.z]` heading; the extractor is blind, "
              f"which is not the same as the changelog being current")
        sys.exit(2)
    if want not in heads:
        print(f"LOCKSTEP: ⚠️  {rel} has no entry for {want} (newest is {heads[0]}) — the published "
              f"tarball would carry a changelog that does not mention the version it ships")

if drift:
    print(f"LOCKSTEP: DRIFT — {len(drift)} of {checked} shipped version string(s) do not match package.json")
    print("\n".join(drift))
    print("Bump every string above in the same commit — Codex caches plugins on this version,")
    print("so a stale entry ships as 'already installed' on the runtime that cannot report it.")
    sys.exit(1)

# ── Self-restatement — a file that states its own count/version twice can drift from itself ──
# Measured 2026-08-13 (peer session, reship axis): N=2 on two DIFFERENT surfaces, both real —
#   (a) a memory file's YAML frontmatter `description:` stated an npm version differently from
#       its own body (1.4.95 vs 1.4.92 — a lockstep drift, just in prose instead of JSON)
#   (b) lane_runner_check.sh's own header comment stated "11/8" while a later comment said the
#       DEBT count was 12 — caught by cross-family review, not by re-reading (see that file's own
#       header for the incident write-up; it has since self-corrected into a historical note).
# «타표면 재발 = 기계화 의무» (recurrence on a second, different surface obligates mechanizing) —
# found→extend into THIS lens rather than a new scanner: same idiom (extract candidate values,
# compare, collect drift, report), new target surfaces.
#
# Advisory (like the CHANGELOG check above), same reasoning: a stale self-count is a documentation
# defect, not a broken package, and turning publish red on prose trains the override this repo has
# already measured people reaching for.
#
# Scope, deliberately narrow — the two false-positive traps that would have made this noise instead
# of signal, both avoided on purpose:
#   1. tracks/**/*.md and this repo's session cards are EXCLUDED. Those are running logs that
#      legitimately cite dozens of historical version numbers across dated sessions — scanning them
#      for "two differing v-numbers in one file" would fire on nearly every one. The mission here is
#      "does a single-snapshot doc contradict itself", not "every version ever mentioned".
#   2. The DEBT counter only fires on 2+ DISTINCT values for the SAME literal label ("DEBT") within
#      comment lines of one file — not on any two numbers that happen to appear near each other. A
#      one-off historical narration ("this said 11/8 until it was fixed") does not by itself carry
#      two live DEBT-labeled claims, so it does not false-positive as an active contradiction.
def _self_restate_md():
    hits = []
    candidates = [os.path.join(root, 'CLAUDE.md'), os.path.join(root, 'AGENTS.md')]
    candidates += sorted(glob.glob(os.path.join(root, 'plugins', '*', 'skills', '*', 'SKILL.md')))
    # v-prefix optional — cross-family review found the real incident that motivated this arm
    # (a memory file's frontmatter `latest v1.4.97` vs body `latest **1.4.97**`) does not carry the
    # prefix on the body side, so the mandatory-v form never fires on the actual shape it exists
    # to catch. Bare N.N.N is noisier (could match an unrelated dependency version), but the
    # candidate list above is narrow enough (CLAUDE.md/AGENTS.md/SKILL.md only) that this stays
    # advisory-tolerable rather than explosive.
    VERPAT = re.compile(r'\bv?(\d+\.\d+\.\d+)\b')
    for p in candidates:
        if not os.path.exists(p):
            continue
        try:
            txt = open(p, encoding='utf-8', errors='replace').read()
        except OSError:
            continue
        m = re.match(r'^---\n(.*?)\n---\n(.*)$', txt, re.S)
        if not m:
            continue
        fm, body = m.group(1), m.group(2)
        fm_vers = set(VERPAT.findall(fm))
        body_vers = set(VERPAT.findall(body))
        drifted = fm_vers - body_vers
        if fm_vers and body_vers and drifted:
            rel = os.path.relpath(p, root)
            hits.append(f"  {rel} :: frontmatter states v{{{','.join(sorted(drifted))}}} not "
                        f"found anywhere in body (body has v{{{','.join(sorted(body_vers))}}})")
    return hits

def _self_restate_sh():
    hits = []
    # Tight: DEBT immediately followed by (optional :/=, whitespace) a number — not "any digit
    # within 12 chars" (that matched an unrelated exit-code legend entry across a bullet, «DEBT ·
    # 1»). A number immediately followed by an arrow (→ / ->) is a before→after transition
    # narration ("DEBT 2 → 0"), not a live claim about the current count — excluded on purpose,
    # calibrated against this repo's own lane_runner_check.sh (known-negative: 3 raw matches with
    # the loose form, 1 real match with this form — verified by hand, 2026-08-14).
    DEBTPAT = re.compile(r'\bDEBT\b\s*[:=]?\s*(\d+)\b(?!\s*(?:→|->))')
    # test_*.sh / *_lanes.sh are excluded — measured 2026-08-14 on this check's own test file:
    # a known-pair fixture legitimately embeds two differing DEBT numbers as heredoc TEST DATA
    # (proving the detector can tell them apart), and that heredoc text is also literal source in
    # the test file itself. Those are fixtures, not a claim about the test file's own state — same
    # distinction the `suites` glob elsewhere in this repo already draws between subject scripts
    # and the test scripts that exercise them.
    for p in (sorted(f for f in glob.glob(os.path.join(root, 'scripts', '*.sh'))
                      if not re.match(r'^(test_.*|.*_lanes)\.sh$', os.path.basename(f)))
              + sorted(f for f in glob.glob(os.path.join(root, 'templates', '*.sh'))
                        if not re.match(r'^(test_.*|.*_lanes)\.sh$', os.path.basename(f)))):
        try:
            txt = open(p, encoding='utf-8', errors='replace').read()
        except OSError:
            continue
        # Comment lines only — a live `DEBT=()` array literal is code computing the fact, not a
        # restated claim about it, and must not be treated as a second (possibly stale) copy.
        vals = set()
        for ln in txt.splitlines():
            if not re.match(r'^\s*#', ln):
                continue
            vals |= {int(m) for m in DEBTPAT.findall(ln)}
        if len(vals) > 1:
            rel = os.path.relpath(p, root)
            hits.append(f"  {rel} :: comments state DEBT as {sorted(vals)} — pick one number, "
                        f"or point the stale comment at the live count instead of a literal")
    return hits

restate_hits = _self_restate_md() + _self_restate_sh()
if restate_hits:
    print(f"LOCKSTEP: ⚠️  self-restatement drift — {len(restate_hits)} file(s) state their own "
          f"version/count more than once and the copies disagree:")
    print("\n".join(restate_hits))

print(f"LOCKSTEP: PASS — {checked} shipped version string(s) all at {want}")
PY
