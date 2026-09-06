#!/usr/bin/env python3
"""probe_live_eval_lib.py — parsing + scoring core for scripts/probe_live_eval.sh.

Split out of the .sh entrypoint on purpose: the lane test
(scripts/test_probe_live_eval_lanes.sh) needs to calibrate the SCORER against known-pair fixture
text — PASS/FAIL/UNCALIBRATED/FAILED-TO-RUN — without ever invoking `claude`. A pure, import-safe
module makes that a direct function call instead of a shell-out with a live API dependency.

No third-party deps (no pyyaml) — `probes_live.yaml` is deliberately NOT full YAML; it's a fixed,
hand-authored subset this module parses with a small line-based reader (see `parse_probes_live`).
If that format ever needs real YAML nesting, switch formats deliberately — don't let a stdlib-only
parser silently start guessing.
"""
import json
import re
import sys
import os
import glob
from datetime import date

ID_RE = re.compile(r'^[A-Z][A-Z0-9]*-[A-Z0-9]+-[0-9]+$')
UTTERANCE_RE = re.compile(r'`[^`]+`|"[^"]+"')
VALID_CLASSES = ('mandatory-pass', 'measured', 'judged')

# The one judgment call the mechanical rule (class + quoted-literal) cannot make: these rows ARE
# backtick-quoted (`npm test`, `npm publish`) but the quoted text is a SHELL COMMAND a CI job runs,
# not something a user types to Claude in conversation. Passing it as --prompt would test "does
# Claude talk about npm test", not "does npm test actually gate publish" — a different question the
# probe was never about. Named here, not folded into the regex, so it stays greppable as a decision
# rather than disappearing into pattern tuning.
CLI_EVENT_EXCLUDE = {"G-CODE-01", "G-CODE-02", "G-CODE-03"}

# The second judgment call, and a different one: these rows are perfectly good CHAT utterances, but
# the behavior they check is delegated to a surface THE ARM DOES NOT HAVE. G-TRIG-03 is the measured
# case (2026-09-06): its probes.md rationale cites CLAUDE.md's Autonomous-Initiative table, but the
# `harness-doctor` row was deliberately REMOVED from that table in the 2026-07-17 row diet and
# delegated to the skill's own frontmatter `description`. The arm runs with
# `--tools "Read,Grep,Glob"` and no Skill tool — a known-pair confirmed it ("list every Skill
# available to you" -> NO-SKILL-TOOL, while the tool-listing control answered correctly) — so the
# probe was scoring a route that cannot exist in its own environment. It failed 0/5 for that reason
# and for no other.
#
# 🟥 EXCLUDING IT DOES NOT MEAN THE HARNESS IS FINE. "Does the row-diet delegation actually fire at
# the floor tier?" is now UNMEASURED, not answered — that question needs a different instrument (an
# arm that can see the skill layer), and building one re-calibrates all 12 probes, so it is not a
# calibration-week change. Named here so the gap stays greppable instead of dissolving into a
# permanently-red lane nobody reads.
ARM_CAPABILITY_EXCLUDE = {"G-TRIG-03"}


def parse_probes_md(path):
    """Return [{id, input, class, raw_class}] for every table-row probe in probes.md.

    Markdown-table split by '|', not a markdown library — probes.md cells contain no literal
    pipe characters (checked: the file is hand-authored prose + code spans only), so this is a
    faithful parse, not a heuristic one. Rows are recognized by column-1 matching ID_RE after
    stripping backticks; the header row, the `|---|` separator, and prose lines that happen to
    start with '|' (none currently do) are excluded by that same test.
    """
    rows = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line.startswith('|'):
                continue
            cells = [c.strip() for c in line.split('|')]
            # split('|') on "| a | b | c | d | e |" yields ['', a, b, c, d, e, ''] — 7 elements.
            if len(cells) != 7:
                continue
            id_cell = cells[1].strip('`').strip()
            if not ID_RE.match(id_cell):
                continue
            input_cell = cells[2]
            class_cell = cells[5]
            class_tok = class_cell.split('—')[0].strip()
            rows.append({
                'id': id_cell,
                'input': input_cell,
                'class': class_tok,
                'raw_class': class_cell,
            })
    return rows


def parse_probes_live(path):
    """Fixed-format reader for probes_live.yaml's `- id: ...` / `    key: value` block shape.

    Deliberately not a general YAML parser (no pyyaml dependency, see module docstring). Values
    are taken verbatim after the first ':' and unquoted if wrapped in matching double-quotes —
    this is why every value in probes_live.yaml that could contain a literal colon is avoided by
    convention (documented in that file's header) rather than escaped here.
    """
    probes = []
    cur = None
    with open(path, encoding='utf-8') as f:
        for raw in f:
            line = raw.rstrip('\n')
            stripped = line.strip()
            if not stripped or stripped.startswith('#'):
                continue
            if stripped == 'probes:':
                continue
            if stripped.startswith('- id:'):
                if cur is not None:
                    probes.append(cur)
                cur = {'id': _unquote(stripped[len('- id:'):].strip())}
                continue
            if cur is None:
                continue
            m = re.match(r'^([a-z_]+):\s*(.*)$', stripped)
            if not m:
                continue
            key, val = m.group(1), _unquote(m.group(2).strip())
            cur[key] = val
    if cur is not None:
        probes.append(cur)
    return probes


def _unquote(s):
    if len(s) >= 2 and s[0] == '"' and s[-1] == '"':
        return s[1:-1]
    return s


def classify(id_, input_pat, class_tok):
    """Apply the mechanical selection rule. Returns (bucket, reason) — reason is None iff
    bucket == 'SELECTABLE'."""
    if class_tok == 'judged':
        return 'EXCLUDED', 'JUDGED'
    if class_tok not in VALID_CLASSES:
        return 'EXCLUDED', 'UNKNOWN-CLASS(%s)' % (class_tok or '<empty>')
    if input_pat.strip().startswith('[INERT-ANCHOR]'):
        return 'EXCLUDED', 'INERT-ANCHOR'
    if id_ in CLI_EVENT_EXCLUDE:
        return 'EXCLUDED', 'NOT-CHAT-UTTERANCE (shell command, not a chat turn)'
    if id_ in ARM_CAPABILITY_EXCLUDE:
        return 'EXCLUDED', 'NOT-LIVE-MEASURABLE (skill-description route; the arm has no Skill tool)'
    if not UTTERANCE_RE.search(input_pat):
        return 'EXCLUDED', 'NO-UTTERANCE (no quoted/backticked literal a user would type)'
    return 'SELECTABLE', None


def build_selection(probes_md_rows, live_rows):
    """Cross-reference probes.md (source of truth for WHICH probes exist and their class) against
    probes_live.yaml (source of truth for HOW to score the selected ones).

    Returns dict: selected [{id,input,control_input,polarity,expect_re}], excluded [{id,reason}],
    warnings [str] — warnings never block a run, they name drift between the two files.
    """
    live_by_id = {p['id']: p for p in live_rows}
    md_ids = set()
    selected, excluded, warnings = [], [], []

    for row in probes_md_rows:
        md_ids.add(row['id'])
        bucket, reason = classify(row['id'], row['input'], row['class'])
        if bucket == 'EXCLUDED':
            in_yaml = row['id'] in live_by_id
            excluded.append({'id': row['id'], 'reason': reason, 'in_probes_live': in_yaml})
            if in_yaml:
                warnings.append(
                    "STALE-YAML-ENTRY: %s is authored in probes_live.yaml but the mechanical rule "
                    "excludes it (%s) — re-curate or remove it." % (row['id'], reason))
            continue
        # SELECTABLE per the mechanical rule.
        if row['id'] not in live_by_id:
            excluded.append({'id': row['id'], 'reason': 'NOT-YET-AUTHORED', 'in_probes_live': False})
            warnings.append(
                "NOT-YET-AUTHORED: %s passes the mechanical selection rule but has no entry in "
                "probes_live.yaml — add polarity/expect_re/control_input by hand to include it."
                % row['id'])
            continue
        spec = live_by_id[row['id']]
        missing = [k for k in ('polarity', 'input', 'expect_re', 'control_input') if k not in spec]
        if missing:
            excluded.append({'id': row['id'], 'reason': 'INCOMPLETE-YAML-ENTRY(%s)' % ','.join(missing),
                              'in_probes_live': True})
            warnings.append("INCOMPLETE-YAML-ENTRY: %s is missing field(s): %s"
                             % (row['id'], ','.join(missing)))
            continue
        if spec['polarity'] not in ('present', 'absent'):
            excluded.append({'id': row['id'], 'reason': 'BAD-POLARITY(%s)' % spec['polarity'],
                              'in_probes_live': True})
            warnings.append("BAD-POLARITY: %s declares polarity=%r (must be present|absent)"
                             % (row['id'], spec['polarity']))
            continue
        selected.append({
            'id': row['id'],
            'input': spec['input'],
            'control_input': spec['control_input'],
            'polarity': spec['polarity'],
            'expect_re': spec['expect_re'],
        })

    # Dead-pointer guard: an id in probes_live.yaml that does not exist in probes.md AT ALL.
    for p in live_rows:
        if p['id'] not in md_ids:
            warnings.append(
                "DEAD-POINTER: %s is in probes_live.yaml but does not exist in probes.md — "
                "probes.md is the source of truth, remove or fix the id." % p['id'])

    return {'selected': selected, 'excluded': excluded, 'warnings': warnings}


def filter_selection(selected, subset=None, ids=None):
    """Apply --subset N (first N in file order) or --ids P1,P2 (exact set, order preserved from
    the request; unknown ids are reported, not silently dropped)."""
    if ids:
        wanted = [i.strip() for i in ids.split(',') if i.strip()]
        by_id = {p['id']: p for p in selected}
        out, unknown = [], []
        for w in wanted:
            if w in by_id:
                out.append(by_id[w])
            else:
                unknown.append(w)
        return out, unknown
    if subset:
        n = int(subset)
        return selected[:n], []
    return selected, []


# ── Scoring ──────────────────────────────────────────────────────────────────────────────────
FAILED_TO_RUN = 'FAILED-TO-RUN'
UNCALIBRATED = 'UNCALIBRATED'
PASS = 'PASS'
FAIL = 'FAIL'


def _read_text(path):
    if not os.path.isfile(path):
        return None
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            return f.read()
    except OSError:
        return None


def _read_first_line(path):
    """First non-empty line of `path`, or None if the file is absent/empty entirely. Diagnostic
    use only (the `reason` column below) — never feeds score_probe's verdict."""
    text = _read_text(path)
    if not text:
        return None
    for line in text.splitlines():
        line = line.strip()
        if line:
            return line
    return None


def _failure_reason(base, arm):
    """Best-effort one-line reason a FAILED-TO-RUN arm produced nothing to score: the arm's own
    stderr first line (usually the actual shell error, e.g. "timeout: command not found") when
    there is one; otherwise an rc/bytes fallback — rc parsed from the runner's own console log
    (sim_isolated_run.sh prints "(rc=<n>, ...)" there) and bytes from the actual output file's
    size (0 for a file that was never written). Purely a diagnostic label for the report/console —
    never used by score_probe, which stays unchanged."""
    stderr_line = _read_first_line(os.path.join(base, '%s_r1.stderr.txt' % arm))
    if stderr_line:
        return stderr_line
    out_path = os.path.join(base, '%s_r1.txt' % arm)
    try:
        nbytes = os.path.getsize(out_path) if os.path.isfile(out_path) else 0
    except OSError:
        nbytes = 0
    log_text = _read_text(os.path.join(base, '_runner_%s.log' % arm)) or ''
    m = re.search(r'\(rc=(-?\d+)', log_text)
    rc_s = m.group(1) if m else '?'
    return 'rc=%s bytes=%d' % (rc_s, nbytes)


def _md_escape(s):
    """Keep a diagnostic string from breaking a markdown table row — reason text comes from
    arbitrary stderr/log content, which can contain a literal '|' or a newline."""
    return (s or '').replace('|', '\\|').replace('\n', ' ').replace('\r', ' ')


def score_probe(primary_text, control_text, polarity, expect_re):
    """Three-valued-plus-one verdict for one probe. `primary_text`/`control_text` are None when
    the corresponding output file was missing or empty — that is FAILED-TO-RUN, never a silent
    FAIL (an unreachable API and a wrong response are different failure classes; collapsing them
    is the exact defect CLAUDE.md's not-found-is-not-zero memory entry names)."""
    if primary_text is None or control_text is None or primary_text == '' or control_text == '':
        return FAILED_TO_RUN, False, False
    pat = re.compile(expect_re)
    primary_hit = bool(pat.search(primary_text))
    control_hit = bool(pat.search(control_text))
    if polarity == 'present':
        if control_hit:
            # The pattern fired on a KNOWN-NEGATIVE input too — it cannot discriminate, so a
            # primary hit proves nothing. Per-probe calibration failure, not a pass or a fail.
            return UNCALIBRATED, primary_hit, control_hit
        return (PASS if primary_hit else FAIL), primary_hit, control_hit
    else:  # polarity == 'absent'
        if not control_hit:
            # The control was supposed to be the case where the pattern DOES fire, proving the
            # instrument can detect it at all. If it never fires here either, primary's silence
            # is not evidence of anything — it could just be a pattern that never matches.
            return UNCALIBRATED, primary_hit, control_hit
        return (PASS if not primary_hit else FAIL), primary_hit, control_hit


def score_run(live_rows, run_root, ids_in_order, threshold, model, reps=1):
    """Read <run_root>/<id>/{primary,control}_r{1..reps}.txt for every id, score EACH rep, take the
    majority, and return a report dict. Does not touch the network or spawn `claude` — pure
    filesystem + regex.

    WHY MAJORITY AND WHY THE DISTRIBUTION IS KEPT (2026-09-06, measured). Re-scoring three live run
    artifacts found 5 of 12 probes FLAKY: two runs 15 minutes apart, identical `corpus_head_date`,
    identical model and prompts, flipped 4 probes. Observed pass_rate across those runs was
    0.50 / 0.67 / 0.67 — i.e. the single-rep noise floor is wider than the distance to the 0.80
    threshold, so a reps=1 pass_rate cannot support a threshold decision at all. Majority over
    reps>=3 narrows it; keeping `pass_k/ran_k` in the row keeps the variance visible instead of
    collapsing it into a bare verdict (a verdict with no spread reads the same whether it was 3/3
    or 2/3, and those are different facts).

    Verdict composition, in this order — each branch exists to keep a distinct non-answer distinct:
      * no rep produced BOTH texts            -> FAILED-TO-RUN (the run, not the rule, is the failure)
      * ANY rep scored UNCALIBRATED           -> UNCALIBRATED. Deliberately NOT majority-voted: the
                                                 pattern firing on a known-negative even once means
                                                 discrimination is in doubt, and a majority would
                                                 launder that into a pass.
      * otherwise                             -> PASS iff strict majority of the reps that ran
    """
    by_id = {p['id']: p for p in live_rows}
    reps = max(1, int(reps or 1))
    rows = []
    for pid in ids_in_order:
        spec = by_id.get(pid)
        if spec is None:
            rows.append({'id': pid, 'verdict': 'UNKNOWN-ID', 'primary_hit': None, 'control_hit': None})
            continue
        base = os.path.join(run_root, pid)
        per_rep = []          # [(verdict, phit, chit, primary_text, control_text)]
        for i in range(1, reps + 1):
            pt = _read_text(os.path.join(base, 'primary_r%d.txt' % i))
            ct = _read_text(os.path.join(base, 'control_r%d.txt' % i))
            v, ph, ch = score_probe(pt, ct, spec['polarity'], spec['expect_re'])
            per_rep.append((v, ph, ch, pt, ct))

        ran_reps = [r for r in per_rep if r[0] != FAILED_TO_RUN]
        uncal = [r for r in per_rep if r[0] == UNCALIBRATED]
        pass_reps = [r for r in per_rep if r[0] == PASS]

        if not ran_reps:
            verdict = FAILED_TO_RUN
        elif uncal:
            verdict = UNCALIBRATED
        else:
            verdict = PASS if (len(pass_reps) * 2 > len(ran_reps)) else FAIL

        # primary_hit/control_hit stay single-valued for backward compatibility with the existing
        # report columns and lanes: they report rep 1, and `reps` carries the spread.
        phit, chit = per_rep[0][1], per_rep[0][2]
        row = {'id': pid, 'verdict': verdict, 'primary_hit': phit, 'control_hit': chit,
               'polarity': spec['polarity'], 'reason': '',
               'reps': '%d/%d' % (len(pass_reps), len(ran_reps)) if ran_reps else '0/0',
               'reps_requested': reps,
               'rep_verdicts': [r[0] for r in per_rep]}
        if len(ran_reps) > 1 and 0 < len(pass_reps) < len(ran_reps):
            row['reason'] = 'FLAKY across reps (%s)' % ','.join(r[0] for r in per_rep)
        if verdict == FAILED_TO_RUN:
            # Diagnostic only — score_probe already decided the verdict above from exactly the
            # same texts; this never changes it, only explains it. Reported from rep 1.
            reasons = []
            primary_text, control_text = per_rep[0][3], per_rep[0][4]
            if primary_text is None or primary_text == '':
                reasons.append('primary: %s' % _failure_reason(base, 'primary'))
            if control_text is None or control_text == '':
                reasons.append('control: %s' % _failure_reason(base, 'control'))
            row['reason'] = '; '.join(reasons)
        rows.append(row)

    failed_to_run = [r for r in rows if r['verdict'] == FAILED_TO_RUN]
    uncalibrated = [r for r in rows if r['verdict'] == UNCALIBRATED]
    ran = [r for r in rows if r['verdict'] in (PASS, FAIL)]
    passed = [r for r in rows if r['verdict'] == PASS]

    if uncalibrated:
        overall = 'UNCALIBRATED'
        rc = 2
        pass_rate = None
    elif not ran:
        overall = 'NO-PROBES-RAN'
        rc = 2
        pass_rate = None
    else:
        pass_rate = len(passed) / float(len(ran))
        if pass_rate < threshold:
            overall = 'FAIL'
            rc = 1
        else:
            overall = 'PASS'
            rc = 0

    return {
        'rows': rows,
        'total': len(rows),
        'failed_to_run': len(failed_to_run),
        'uncalibrated': len(uncalibrated),
        'ran': len(ran),
        'passed': len(passed),
        'pass_rate': pass_rate,
        'threshold': threshold,
        'overall': overall,
        'rc': rc,
        'model': model,
    }


def render_report_md(select_result, score_result, run_date):
    lines = []
    lines.append("# live_eval — %s" % run_date)
    lines.append("")
    lines.append("Live (behavioral) probe run — see `.claude/regression/probes_live.yaml` for what "
                  "each probe checks and why. Static-only coverage lives in `/prompt-regression`; "
                  "this file is its live twin's record.")
    lines.append("")
    lines.append("## Selection")
    lines.append("- Selected: %d" % len(select_result['selected']))
    lines.append("- Excluded: %d" % len(select_result['excluded']))
    if select_result['warnings']:
        lines.append("- Warnings: %d (see below)" % len(select_result['warnings']))
    lines.append("")
    if score_result is not None:
        lines.append("## Run — model=%s threshold=%.2f" % (score_result['model'], score_result['threshold']))
        lines.append("")
        lines.append("| Probe | Verdict | reps(pass/ran) | primary_hit | control_hit | polarity | Reason |")
        lines.append("|---|---|---|---|---|---|---|")
        for r in score_result['rows']:
            lines.append("| %s | %s | %s | %s | %s | %s | %s |" % (
                r['id'], r['verdict'], r.get('reps', '-'),
                r.get('primary_hit'), r.get('control_hit'), r.get('polarity', ''),
                _md_escape(r.get('reason', ''))))
        lines.append("")
        pr = score_result['pass_rate']
        pr_s = ("%.2f" % pr) if pr is not None else "n/a"
        lines.append("**Overall: %s** — ran=%d failed_to_run=%d uncalibrated=%d passed=%d pass_rate=%s"
                      % (score_result['overall'], score_result['ran'], score_result['failed_to_run'],
                         score_result['uncalibrated'], score_result['passed'], pr_s))
        lines.append("")
    lines.append("## Excluded (from probes.md, 33-row snapshot)")
    lines.append("")
    lines.append("| Probe | Reason |")
    lines.append("|---|---|")
    for e in select_result['excluded']:
        lines.append("| %s | %s |" % (e['id'], e['reason']))
    if select_result['warnings']:
        lines.append("")
        lines.append("## Warnings")
        for w in select_result['warnings']:
            lines.append("- %s" % w)
    return "\n".join(lines) + "\n"


# ── CLI ──────────────────────────────────────────────────────────────────────────────────────
def _cmd_select(args):
    probes_md_rows = parse_probes_md(args.probes_md)
    live_rows = parse_probes_live(args.probes_live)
    result = build_selection(probes_md_rows, live_rows)
    filtered, unknown = filter_selection(result['selected'], subset=args.subset, ids=args.ids)

    print("── probe_live_eval selection ──────────────────────────────────────")
    print("probes.md rows: %d   selectable-per-rule: %d   authored-in-yaml: %d"
          % (len(probes_md_rows),
             sum(1 for r in probes_md_rows if classify(r['id'], r['input'], r['class'])[0] == 'SELECTABLE'),
             len(result['selected'])))
    if args.subset or args.ids:
        print("filter applied: %s -> %d probe(s) this run"
              % (('--subset ' + str(args.subset)) if args.subset else ('--ids ' + args.ids), len(filtered)))
    if unknown:
        print("⚠️  unknown ids requested via --ids (not in the live-authored set): %s" % ', '.join(unknown))
    print("")
    print("SELECTED (%d):" % len(filtered))
    for p in filtered:
        print("  %-14s polarity=%-7s input=%r" % (p['id'], p['polarity'], p['input']))
    print("")
    print("EXCLUDED (%d):" % len(result['excluded']))
    for e in result['excluded']:
        print("  %-14s %s" % (e['id'], e['reason']))
    if result['warnings']:
        print("")
        print("WARNINGS (%d):" % len(result['warnings']))
        for w in result['warnings']:
            print("  - %s" % w)

    if args.json_out:
        with open(args.json_out, 'w', encoding='utf-8') as f:
            json.dump({'selected': filtered, 'excluded': result['excluded'],
                       'warnings': result['warnings'], 'unknown_ids': unknown,
                       'full_selected': result['selected']}, f, ensure_ascii=False, indent=2)
    if args.spec_dir:
        os.makedirs(args.spec_dir, exist_ok=True)
        for p in filtered:
            with open(os.path.join(args.spec_dir, p['id'] + '.input.txt'), 'w', encoding='utf-8') as f:
                f.write(p['input'])
            with open(os.path.join(args.spec_dir, p['id'] + '.control.txt'), 'w', encoding='utf-8') as f:
                f.write(p['control_input'])
        with open(os.path.join(args.spec_dir, 'selected_ids.txt'), 'w', encoding='utf-8') as f:
            for p in filtered:
                f.write(p['id'] + '\n')

    # Dead pointers and stale yaml entries are authoring bugs, not scoring failures — the lane
    # test asserts this exit code directly (fixture with a deliberately dead id → nonzero).
    dead = [w for w in result['warnings'] if w.startswith('DEAD-POINTER')]
    return 1 if dead else 0


def _cmd_score(args):
    live_rows = parse_probes_live(args.probes_live)
    with open(args.select_json, encoding='utf-8') as f:
        select_result = json.load(f)
    ids_in_order = [line.strip() for line in open(args.ids_file, encoding='utf-8') if line.strip()]
    score_result = score_run(live_rows, args.run_root, ids_in_order, args.threshold, args.model,
                             reps=getattr(args, 'reps', 1))

    print("── probe_live_eval score ──────────────────────────────────────────")
    for r in score_result['rows']:
        line = ("  %-14s %-14s primary_hit=%-5s control_hit=%-5s polarity=%s"
                % (r['id'], r['verdict'], r.get('primary_hit'), r.get('control_hit'), r.get('polarity', '')))
        reason = r.get('reason', '')
        if reason:
            line += " reason=%s" % reason
        print(line)
    print("")
    pr = score_result['pass_rate']
    pr_s = ("%.2f" % pr) if pr is not None else "n/a"
    print("total=%d ran=%d failed_to_run=%d uncalibrated=%d passed=%d pass_rate=%s threshold=%.2f"
          % (score_result['total'], score_result['ran'], score_result['failed_to_run'],
             score_result['uncalibrated'], score_result['passed'], pr_s, score_result['threshold']))
    print("OVERALL: %s (rc=%d)" % (score_result['overall'], score_result['rc']))

    if args.report_out:
        md = render_report_md(select_result, score_result, args.run_date or str(date.today()))
        os.makedirs(os.path.dirname(args.report_out), exist_ok=True)
        with open(args.report_out, 'w', encoding='utf-8') as f:
            f.write(md)
        print("report: %s" % args.report_out)

    return score_result['rc']


def main():
    import argparse
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest='cmd', required=True)

    sp = sub.add_parser('select')
    sp.add_argument('--probes-md', required=True)
    sp.add_argument('--probes-live', required=True)
    sp.add_argument('--subset')
    sp.add_argument('--ids')
    sp.add_argument('--json-out')
    sp.add_argument('--spec-dir')

    sc = sub.add_parser('score')
    sc.add_argument('--probes-live', required=True)
    sc.add_argument('--select-json', required=True)
    sc.add_argument('--ids-file', required=True)
    sc.add_argument('--run-root', required=True)
    sc.add_argument('--threshold', type=float, required=True)
    sc.add_argument('--model', required=True)
    sc.add_argument('--report-out')
    sc.add_argument('--run-date')
    sc.add_argument('--reps', type=int, default=1)

    args = ap.parse_args()
    if args.cmd == 'select':
        sys.exit(_cmd_select(args))
    elif args.cmd == 'score':
        sys.exit(_cmd_score(args))


if __name__ == '__main__':
    main()
