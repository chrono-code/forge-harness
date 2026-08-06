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
import json, sys, glob, os
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

if drift:
    print(f"LOCKSTEP: DRIFT — {len(drift)} of {checked} shipped version string(s) do not match package.json")
    print("\n".join(drift))
    print("Bump every string above in the same commit — Codex caches plugins on this version,")
    print("so a stale entry ships as 'already installed' on the runtime that cannot report it.")
    sys.exit(1)

print(f"LOCKSTEP: PASS — {checked} shipped version string(s) all at {want}")
PY
