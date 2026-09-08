#!/usr/bin/env python3
"""finding_verify.py — typed review findings in, cross-family verdicts on, false positives dropped BY CODE.

WHY THIS EXISTS. FH's review output is prose end to end: a governor reads, judges, and writes. Nothing
in that path can be counted, filtered, or handed to a second family, because a prose finding has no
fields. Measured 2026-09-08 on eight GHSA cases x3: FH's review made 52 claims of which 5 were wrong
about the code (9.6%); a sibling harness (octo) made 73 claims -- 40% MORE -- with 2 wrong (2.7%). Its
advantage is not better reading. Its pipeline emits findings as typed JSON, has a different-family
agent stamp each one `confirmed|false-positive|needs-debate`, and then DELETES the false positives with
a filter. Judgment stays with a model; the drop is mechanical. This script is that stage for FH.

WHAT IS MECHANIZED AND WHAT IS NOT (CLAUDE.md 'Mechanization Boundary'). The channel is mechanized:
every finding carries a verdict, the verdict comes from a command that is not the author, the drop is
performed by code, and what was dropped is written down. The judgment -- is this claim true of the
source -- is made by whatever model the verifier command runs, never frozen here. This file contains
no rule about what makes a finding wrong.

DEGRADE DIRECTION. A review surface is reversible, so an unreachable verifier does not block. It must
not be silent either: with no verifier every finding is stamped `unverified`, NOTHING is dropped, the
status is UNVERIFIED and the exit code says so. An unverified run must never read as a clean one.

THE DROP SIDE IS MEASURED TOO, OR THE RUN SAYS IT WAS NOT. A stage that deletes claims improves any
precision number for free: delete enough and nothing wrong survives. So the error rate of the SURVIVORS
is not a result on its own — it is only meaningful beside the error rate of the DELETIONS. Measured on
this pipeline's first real use, 2026-09-08: the verifier dropped a claim that the project's own earlier
record grades a real A-tier defect. One drop, one wrong. That is why `--audit-verifier` exists and why
the summary line carries `drop_audit=UNAUDITED` in bold terms when drops happened and nobody checked
them. The auditor must not be the family that made the drop; when it is the family that PRODUCED the
finding, that is an appeal by an interested party and is recorded as `audit_role=appeal`, not hidden.

INPUT   JSONL, one finding per line:
        {"id","file","line","severity","category","title","detail","confidence","producer_family"}
        `id` and `title` are required; the rest are optional and pass through untouched.
        When `producer_family` is present and equals the verifier's family, that finding is stamped
        `unverified` rather than judged -- see the note above VERDICTS.
AUDITOR   Optional, and required for the drop-side number to exist. Same protocol as the verifier, but
        it receives only the DROPPED findings and answers {"id","verdict":"correct-drop|wrong-drop|
        uncertain","why"}. A `wrong-drop` finding is moved back into confirmed.jsonl with
        `reinstated: true` -- the audit is not advisory, it reverses the deletion.
VERIFIER  A command that reads the findings JSONL on stdin and writes JSONL verdicts on stdout:
        {"id","verdict":"confirmed|false-positive|needs-debate","why"}
        Set it with --verifier or FH_VERIFY_CMD. Run it as a DIFFERENT model family than the author;
        this script cannot check that, and says so rather than pretending to.
OUTPUT  <out>/confirmed.jsonl  survivors (confirmed + needs-debate, the latter flagged)
        <out>/dropped.jsonl    false positives, with the verifier's reason -- never silent
        stdout                 one summary line, machine-readable
EXIT    0 verified and (no drops, or drops audited) with >=1 survivor · 1 same but nothing survives
        3 UNVERIFIED (degraded) · 4 drops happened and were never audited · 2 usage or schema error
"""
import argparse, json, os, subprocess, sys

REQUIRED = ("id", "title")
VERDICTS = ("confirmed", "false-positive", "needs-debate")
AUDIT_VERDICTS = ("correct-drop", "wrong-drop", "uncertain")

# A finding is never verified by the family that produced it. That is the one property of the record
# this file enforces on its own: same-family review shares the author's blind spot, so a verdict from
# the producer is not a second opinion. It is a channel rule, not a judgment -- the script does not
# decide whether the claim is true, only that the party answering must not be the party asking.


def read_findings(path):
    out, seen = [], set()
    src = sys.stdin if path == "-" else open(path, encoding="utf-8")
    for n, line in enumerate(src, 1):
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError as e:
            raise SystemExit(f"finding_verify: line {n} is not JSON: {e}")
        for k in REQUIRED:
            if not d.get(k):
                raise SystemExit(f"finding_verify: line {n} missing required field '{k}'")
        if d["id"] in seen:
            raise SystemExit(f"finding_verify: duplicate id {d['id']!r} on line {n}")
        seen.add(d["id"])
        out.append(d)
    return out


def run_verifier(cmd, findings, allowed=VERDICTS):
    """Returns (verdicts_by_id, error_or_None). Any failure degrades; it never raises.

    `allowed` is the verdict vocabulary. The audit pass speaks a different one, and a verdict outside
    the expected set is dropped rather than coerced -- a stage that silently reinterprets an unknown
    label is how an unanswered question becomes an answer."""
    payload = "\n".join(json.dumps(f, ensure_ascii=False) for f in findings) + "\n"
    try:
        p = subprocess.run(cmd, shell=True, input=payload, capture_output=True,
                           text=True, timeout=int(os.environ.get("FH_VERIFY_TIMEOUT", "600")))
    except Exception as e:                                   # noqa: BLE001 - degrade on anything
        return {}, f"verifier did not run: {e}"
    if p.returncode != 0:
        return {}, f"verifier exit {p.returncode}: {(p.stderr or '').strip()[:200]}"
    got = {}
    for line in p.stdout.splitlines():
        line = line.strip()
        if not line or not line.startswith("{"):
            continue                                          # tolerate chatter around the JSONL
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if d.get("id") and d.get("verdict") in allowed:
            got[d["id"]] = d
    if not got:
        return {}, "verifier returned no parseable verdict"
    return got, None


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("findings", help="JSONL file, or - for stdin")
    ap.add_argument("--out", required=True, help="directory for confirmed.jsonl / dropped.jsonl")
    ap.add_argument("--verifier", default=os.environ.get("FH_VERIFY_CMD", ""),
                    help="shell command; findings JSONL on stdin, verdict JSONL on stdout")
    ap.add_argument("--family", default=os.environ.get("FH_VERIFY_FAMILY", "unstated"),
                    help="model family of the verifier, recorded verbatim and never checked")
    ap.add_argument("--audit-verifier", default=os.environ.get("FH_AUDIT_CMD", ""),
                    help="command that re-checks the DROPPED findings; without it the run is UNAUDITED")
    ap.add_argument("--audit-family", default=os.environ.get("FH_AUDIT_FAMILY", "unstated"),
                    help="model family of the auditor; must differ from the verifier's")
    a = ap.parse_args()

    findings = read_findings(a.findings)
    os.makedirs(a.out, exist_ok=True)

    if not a.verifier.strip():
        verdicts, err = {}, "no verifier configured (--verifier / FH_VERIFY_CMD)"
    else:
        verdicts, err = run_verifier(a.verifier, findings)

    confirmed, dropped, debate, unverified = [], [], 0, 0
    for f in findings:
        v = verdicts.get(f["id"])
        if v is None:
            # Degraded, or the verifier skipped this one. Keep it, mark it, never drop it silently.
            f = dict(f, verdict="unverified",
                     verify_note=err or "verifier returned no verdict for this finding")
            unverified += 1
            confirmed.append(f)
            continue
        if f.get("producer_family") and f["producer_family"] == a.family:
            f = dict(f, verdict="unverified", verify_note="verifier is the producing family "
                     f"({a.family}); a finding is not verified by its own author")
            unverified += 1
            confirmed.append(f)
            continue
        f = dict(f, verdict=v["verdict"], verify_why=v.get("why", ""), verify_family=a.family)
        if v["verdict"] == "false-positive":
            dropped.append(f)
        else:
            if v["verdict"] == "needs-debate":
                debate += 1
            confirmed.append(f)

    # ── drop audit ────────────────────────────────────────────────────────────────────────────────
    # Nothing here judges whether a drop was right; it routes the question to a party that did not make
    # the drop, and moves a reversed drop back. The refusal to report a bare precision number when this
    # did not run is the mechanized part.
    audited = wrong_drops = reinstated = 0
    audit_status = "UNAUDITED"
    audit_note = ""
    if dropped and a.audit_verifier.strip():
        if a.audit_family == a.family:
            audit_note = ("auditor is the family that made the drop (%s) -- refused; a deletion is not "
                          "checked by the party that made it" % a.family)
        else:
            av, aerr = run_verifier(a.audit_verifier, dropped, AUDIT_VERDICTS)
            if aerr:
                audit_note = "auditor did not answer: " + aerr
            else:
                kept = []
                for d in dropped:
                    r = av.get(d["id"])
                    if r is None:
                        kept.append(dict(d, drop_verdict="unaudited"))
                        continue
                    audited += 1
                    role = "appeal" if d.get("producer_family") == a.audit_family else "independent"
                    d = dict(d, drop_verdict=r["verdict"], drop_why=r.get("why", ""),
                             audit_family=a.audit_family, audit_role=role)
                    if r["verdict"] == "wrong-drop":
                        wrong_drops += 1
                        reinstated += 1
                        confirmed.append(dict(d, reinstated=True))
                    else:
                        kept.append(d)
                dropped = kept
                audit_status = "AUDITED"
    elif not dropped:
        audit_status = "NO-DROPS"

    for name, rows in (("confirmed.jsonl", confirmed), ("dropped.jsonl", dropped)):
        with open(os.path.join(a.out, name), "w", encoding="utf-8") as fh:
            for r in rows:
                fh.write(json.dumps(r, ensure_ascii=False) + "\n")

    status = "UNVERIFIED" if unverified else "VERIFIED"
    print("FINDINGS in={} confirmed={} dropped={} debate={} unverified={} family={} status={}{}".format(
        len(findings), len(confirmed) - unverified, len(dropped), debate, unverified,
        a.family, status, "" if not err else " reason=" + err.replace("\n", " ")))
    # 🟥 The drop line is unconditional. A survivor-side number without it is a precision claim made by
    # deleting, and this pipeline does not let a reader compute one without seeing whether the
    # deletions were checked.
    print("DROPS dropped={} audited={} wrong_drops={} reinstated={} auditor={} drop_audit={}{}".format(
        len(dropped), audited, wrong_drops, reinstated, a.audit_family, audit_status,
        "" if not audit_note else " reason=" + audit_note.replace("\n", " ")))
    if unverified:
        return 3
    if audit_status == "UNAUDITED":
        return 4                      # drops happened and nobody checked them: not a completed run
    return 0 if confirmed else 1


if __name__ == "__main__":
    sys.exit(main())
