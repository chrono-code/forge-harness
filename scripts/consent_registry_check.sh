#!/usr/bin/env bash
# consent_registry_check.sh — mechanical floor for accept-side consent promotion.
#
# WHY (cross-family review round 2, 2026-07-29)
#   Round 1 verdict on the prose rule was REJECT; the revision moved it to NARROW-IT, and the
#   reviewer's sharpest remaining point was that the revision "reads mechanical" while several of its
#   predicates — sink tainting, promotion eligibility, effect-subset, expiry — were still semantic.
#   A rule that reads as a control but cannot be checked is worse than an absent one: it buys the
#   confidence without the enforcement. This script is the missing half. It does not judge; it joins
#   `standing_consent` against the declared registry and fails closed on anything it cannot decide.
#
# WHAT IT ENFORCES (all mechanical — no model, no judgment)
#   R1  registry schema — every class carries all required fields
#   R2  eligibility soundness — promotion_eligible:true is FORBIDDEN when sinks/feeds are non-empty
#       or contain `unknown` (the taint + unknown-is-not-reversible rules)
#   R3  join     — every standing_consent key resolves to a registered class
#   R4  floor    — every standing_consent key resolves to a promotion_eligible class
#   R5  lease    — every grant carries `expires` and is not past it
#   R6  scope    — every grant records `effects` AND `target`, so the subset check has something to
#                  compare against (a grant whose scope was never recorded cannot be re-validated)
#
# WHAT IT DOES *NOT* CHECK (named, so the prose above it cannot over-claim)
#   - the effect-SUBSET comparison itself. R6 proves a baseline was recorded; it does not compare a
#     live action's fingerprint against it, because this script never sees the live action. That
#     comparison is still a runtime obligation of the rule, i.e. still salience-dependent.
#   - the 3-consecutive count, retry dedupe, and same-operation identity — those live in the UAP
#     logger, not here.
#   - `excludes` / adversarial examples / independent review on a registry entry — required by the
#     rule, not yet mechanized. Do not read a PASS here as "the registry was reviewed."
#   - the existence or contents of `consent_runs.log`.
#   A PASS from this script means the registry and the grants are WELL-FORMED and the floor join
#   holds. It does not mean the promotion mechanism as a whole was verified.
#
# DEGRADE DIRECTION
#   No registry file        -> exit 0, prints "N/A: promotion DISABLED" (safe: nothing can promote)
#   No UAP file             -> exit 0, same
#   Unparseable either file -> exit 1 (fail-closed: cannot decide == not allowed)
#   Any R1-R6 violation     -> exit 1
#
#   "N/A" is printed as N/A, never as PASS — an unmeasured surface is not a clean one.
#
# Usage: bash scripts/consent_registry_check.sh [registry.yaml] [uap.md-or-yaml]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REG="${1:-$ROOT/tracks/_meta/consent_classes.yaml}"
UAP="${2:-$ROOT/tracks/_meta/user_adaptation_profile.md}"

python3 - "$REG" "$UAP" <<'PY'
import sys, os, re, datetime
reg_path, uap_path = sys.argv[1], sys.argv[2]

def out(sym, msg): print(f"  {sym} {msg}")

if not os.path.exists(reg_path):
    print(f"consent-registry: N/A — no registry at {reg_path}; promotion DISABLED (not a PASS)")
    sys.exit(0)

try:
    import yaml
except ImportError:
    print("consent-registry: FAIL — pyyaml unavailable, cannot validate; fail-closed")
    sys.exit(1)

# H9 DUPLICATE YAML KEYS. yaml.safe_load is last-wins on duplicate mapping keys, so
# `expires: 2020-01-01` followed by `expires: 2099-01-01` silently keeps the future one, and a
# duplicated grant key keeps whichever was written last. A consent record whose meaning depends on
# which duplicate a parser happens to keep is not a record. Reject duplicates at load time.
class NoDupLoader(yaml.SafeLoader):
    pass

def _no_dup(loader, node, deep=False):
    # Resolve `<<: *anchor` merge keys FIRST. Without this the merge key survives as a literal `<<`
    # entry and a perfectly ordinary DRY registry was refused (measured: a valid grant written via
    # a merge key exited 1 as an unregistered class). Over-blocking is not a safety win — it trains
    # the override reflex and turns the gate into decoration, so it counts as a defect like any
    # fail-open.
    loader.flatten_mapping(node)
    seen = set()
    for k, _ in node.value:
        key = loader.construct_object(k, deep=deep)
        try:
            if key in seen:
                raise ValueError(f"duplicate key {key!r}")
        except TypeError:
            pass
        seen.add(key)
    return yaml.SafeLoader.construct_mapping(loader, node, deep)

NoDupLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _no_dup)

def load(text_or_stream, what):
    global fails
    try:
        return yaml.load(text_or_stream, Loader=NoDupLoader)
    except Exception as e:
        print(f"consent-registry: FAIL — {what} unparseable ({e}); fail-closed")
        sys.exit(1)

fails = 0
reg = load(open(reg_path), "registry")

REQUIRED = ["name", "owner", "mode", "target", "capabilities", "sinks", "feeds", "promotion_eligible"]
STR_FIELDS = ["name", "owner", "mode", "target"]
IRREVERSIBLE = {"go-public", "publish", "delete", "history-rewrite", "unknown"}
NON_GRANT = {"declined", "unset", "revoked"}
MAX_LEASE_DAYS = 365

# The single normalizer for every scope comparison. Case-SENSITIVE by choice (a capability name is
# an identifier, not prose) and whitespace-insensitive; the point is that one function decides, so
# the two sides of a comparison can never drift apart.
def _norm(s):
    return str(s).strip()

# H1 FALSY CONTAINERS. `reg or {}` / `classes or []` laundered `false`, `0`, `[]` and a bare
# `classes:` into a valid-empty registry that exited 0 — the same falsy-collapse defect already
# fixed on the GRANT side, left unfixed here. Half a fix propagated is a hole. Sentinel, then type,
# then default — and an empty registry is stated as N/A, never as a clean pass.
if not isinstance(reg, dict):
    print(f"consent-registry: FAIL — registry root is {type(reg).__name__}, not a mapping; fail-closed")
    sys.exit(1)
if "classes" not in reg:
    print("consent-registry: FAIL — registry has no `classes` key; fail-closed")
    sys.exit(1)
classes = reg["classes"]
if classes is None:
    classes = []
if not isinstance(classes, list):
    print(f"consent-registry: FAIL — `classes` is {type(classes).__name__}, not a list; fail-closed")
    sys.exit(1)
if not classes:
    print("consent-registry: N/A — registry declares zero classes; promotion DISABLED (not a PASS)")
    sys.exit(0)

by_name = {}
for i, c in enumerate(classes):
    if not isinstance(c, dict):
        out("❌", f"R1 class #{i} is not a mapping"); fails += 1; continue
    nm = c.get("name", f"<unnamed #{i}>")
    missing = [f for f in REQUIRED if f not in c]
    if missing:
        out("❌", f"R1 `{nm}` missing required field(s): {', '.join(missing)}"); fails += 1
        continue
    # R1-b STRICT TYPES. `promotion_eligible: "false"` (quoted) is a truthy STRING, so every
    # eligibility test below silently inverts and an intended-ineligible class becomes promotable.
    # Measured 2026-07-29 against a control: quoted "false" PASSed a grant that real `false` blocked.
    # One quote character disarmed the floor — so the type is checked, not coerced.
    if not isinstance(c["promotion_eligible"], bool):
        out("❌", f"R1-b `{nm}` promotion_eligible must be a YAML boolean, got "
                  f"{type(c['promotion_eligible']).__name__} {c['promotion_eligible']!r} "
                  f"(a quoted \"false\" is truthy and would invert the floor)")
        fails += 1; continue
    # H2 scalar fields: a `mode: 123` or `target: ""` described nothing, so the entry a human was
    # asked to review as a grant-of-future-autonomy was unreadable. H3 list ITEMS were never typed,
    # only their container — `sinks: [123]` counted as a declared sink.
    bad_field = False
    for fld in STR_FIELDS:
        if not isinstance(c[fld], str) or not c[fld].strip():
            out("❌", f"R1-b `{nm}` `{fld}` must be a non-blank string, got "
                      f"{type(c[fld]).__name__} {c[fld]!r}")
            fails += 1; bad_field = True
    for fld in ("capabilities", "sinks", "feeds"):
        if not isinstance(c[fld], list):
            out("❌", f"R1-b `{nm}` `{fld}` must be a list, got {type(c[fld]).__name__}")
            fails += 1; bad_field = True
        elif not all(isinstance(x, str) and x.strip() for x in c[fld]):
            out("❌", f"R1-b `{nm}` `{fld}` must contain only non-blank strings, got {c[fld]!r} "
                      f"— an unreadable sink is an UNDECLARED sink, and undeclared is unknown")
            fails += 1; bad_field = True
    if bad_field:
        continue
    # R1-c UNIQUE NAMES. Consent is keyed by class name; a duplicate silently shadowed the earlier
    # entry, so appending an eligible twin below an ineligible one granted the ineligible class.
    if nm in by_name:
        out("❌", f"R1-c duplicate class name `{nm}` — consent is keyed by name, so a duplicate "
                  f"shadows the earlier entry and can launder an ineligible class")
        fails += 1; continue
    by_name[nm] = c
    # R2 — eligibility must be SOUND, not merely asserted. This is the line that stops a class from
    # declaring itself promotable while naming an irreversible sink two fields above.
    taint = set(map(str, c["sinks"] or [])) | set(map(str, c["feeds"] or []))
    bad = taint & IRREVERSIBLE
    # R2-b — the CAPABILITY field is part of the floor too. Until 2026-07-31 IRREVERSIBLE was
    # intersected ONLY with sinks|feeds, so a class could DECLARE `capabilities: [history-rewrite]`
    # outright and stay promotable as long as it named no sink: R2 saw an empty taint and R7's
    # effect-subset rule then CONFIRMED the grant, because the effect really was a subset of the
    # declared capabilities. The gate agreed with itself all the way to exit 0.
    # R2's own comment above says "naming an irreversible SINK two fields above" — the guard was
    # written against the sink field and the capability field was never in its scope. Sinks are
    # where an effect LEAKS; capabilities are what the class is allowed to DO, and the floor cares
    # about both. Checked separately from `bad` so the message names which field carried it.
    # Found by codex/gpt-5.6-sol in round 9; the local canary returned CONVERGED on the same diff.
    cap_bad = set(map(str, c["capabilities"] or [])) & IRREVERSIBLE
    if c["promotion_eligible"] and bad:
        out("❌", f"R2 `{nm}` claims promotion_eligible:true but sinks/feeds include {sorted(bad)}")
        fails += 1
    elif c["promotion_eligible"] and cap_bad:
        out("❌", f"R2-b `{nm}` claims promotion_eligible:true but declares irreversible "
                  f"capabilities {sorted(cap_bad)} — an irreversible act is not made reversible by "
                  f"having no declared sink")
        fails += 1
    elif c["promotion_eligible"] and taint:
        out("❌", f"R2 `{nm}` claims promotion_eligible:true with non-empty sinks/feeds {sorted(taint)} "
                  f"— unlisted sinks are UNKNOWN, and unknown is not reversible")
        fails += 1

if fails == 0:
    out("✅", f"R1/R2 registry schema + eligibility soundness ({len(by_name)} class(es))")

# ---- standing_consent side --------------------------------------------------------
if not os.path.exists(uap_path):
    print(f"consent-registry: N/A — no UAP at {uap_path}; nothing granted (not a PASS)")
    sys.exit(1 if fails else 0)

raw = open(uap_path, errors="replace").read()
# Match BOTH the block form (`standing_consent:` then an indented body) and the inline flow form
# (`standing_consent: {a: {...}}`). The first version matched only the block form, so an inline
# grant — including an EXPIRED one — was read as "no standing consent recorded" and reported PASS.
# A grant the checker cannot see is not an absent grant; that is a false clean, the worst outcome
# for a floor. Measured 2026-07-29 with a control (block form caught it, inline form did not).
grants = {}
# FIRST-MATCH SHADOWING (cross-family round 4, confirmed against a control): reading only the first
# `standing_consent:` meant a benign or empty one earlier in the file HID a real grant later in it —
# `standing_consent: {}` followed by an expired grant reported PASS, while the same expired grant
# alone was caught. A checker that stops at the first occurrence is trivially defeated by appending.
# There is exactly one consent block or the file is not decidable.
# YAML-KEY EQUIVALENCE (round 6): `standing_consent : {...}` — a space or tab before the colon —
# is the SAME YAML key but did not match `^standing_consent:`. Standalone it still failed closed
# via the no-known-form net below; but paired with a normal empty block it was invisible to both
# the count and the extraction, so the empty block was parsed and the real grant vanished. All
# three patterns now allow `[ \t]*` before the colon.
# RESIDUAL — MEASURED OVER-BLOCK (2026-07-29): a grant written with a YAML merge key
# (`defaults: &d {...}` + `standing_consent:\n  <<: *d`) is REFUSED, because the anchor `&d` lives
# outside the extracted fragment and the alias is undefined when the fragment is re-parsed alone.
# That is ordinary DRY YAML, and over-blocking is a defect of the same weight as a fail-open: it
# trains the override reflex and turns the gate into decoration. A whole-file-parse-first path was
# attempted and reverted the same session — it regressed 16 of 40 anchor lanes, and shipping a
# broken floor to close an over-block is a worse trade. Anchor lane N4 pins the current behaviour so
# the next attempt is a measured delta, not a rediscovery.
# RESIDUAL (named): this is regex-scraping a YAML key out of a markdown file, so it approximates
# the YAML spec rather than implementing it (quoted keys, anchors, multi-doc streams are not
# handled). The mitigation is the fail-closed net below, not a claim of completeness.
occurrences = re.findall(r"^standing_consent[ \t]*:", raw, re.M)
if len(occurrences) > 1:
    out("❌", f"R3 the UAP declares `standing_consent` {len(occurrences)} times — ambiguous which "
              f"is authoritative, and an early benign block would shadow a later grant; fail-closed")
    fails += 1
    body = None
    grants = None
else:
    m = re.search(r"^standing_consent[ \t]*:[ \t]*(\{.*)$", raw, re.M)   # inline flow form
    if not m:
        m = re.search(r"^standing_consent[ \t]*:[ \t]*$(.*?)(?=^\S|\Z)", raw, re.M | re.S)  # block form
        body = ("standing_consent:\n" + m.group(1)) if m else None   # re-emitted canonically
    else:
        body = "standing_consent: " + m.group(1)
if grants is not None and body is not None:
    try:
        # NoDupLoader here too. The duplicate-key rejection was added on the registry side and
        # NOT here in the same edit — the third half-fix of this session, committed while
        # fixing a half-fix. Duplicate grant keys were still last-wins: an expired grant
        # followed by a future one silently kept the future one.
        parsed = yaml.load(body, Loader=NoDupLoader)
        # NO `or {}` HERE. `[] or {}` / `False or {}` / `0 or {}` all evaluate to `{}`, which reached
        # the type check already laundered into a valid-empty mapping — so `standing_consent:\n  []`
        # reported "no standing consent recorded" and exit 0, while the truthy `[a, b]` was caught
        # (measured with that control, cross-family round 5). The falsy branch is exactly the one an
        # accident produces. Sentinel first, type check second, defaulting last.
        grants = (parsed if isinstance(parsed, dict) else {}).get("standing_consent", {})
        if grants is None:
            grants = {}            # an explicitly empty `standing_consent:` key is a real empty set
        if not isinstance(grants, dict):
            out("❌", f"R3 standing_consent is not a mapping ({type(grants).__name__}); fail-closed")
            fails += 1; grants = None
    except Exception as e:
        out("❌", f"R3 standing_consent block unparseable ({e}); fail-closed"); fails += 1
        grants = None
elif re.search(r"standing_consent", raw):
    # The key appears but neither form matched — do not silently read that as "nothing granted".
    out("❌", "R3 `standing_consent` appears in the UAP but matched no known form; fail-closed")
    fails += 1; grants = None

if grants is None:
    pass
elif not grants:
    out("✅", "R3-R6 no standing consent recorded (nothing to validate)")
else:
    today = datetime.date.today()
    validated = 0
    for name, g in grants.items():
        # H4 grant key: registry `name: 123` + UAP `123:` used to join fine because neither side was
        # typed. Both sides are strings or the join is meaningless.
        if not isinstance(name, str) or not name.strip():
            out("❌", f"R3 grant key {name!r} must be a non-blank string"); fails += 1; continue
        # `declined` / `unset` / `revoked` are first-class states in this storage model, not grants.
        # Coercing them into `{"granted": ...}` turned a legitimate refusal into a malformed grant
        # and reported violations against a user who said no.
        if isinstance(g, str) and g.strip().lower() in NON_GRANT:
            continue
        if not isinstance(g, dict):
            out("❌", f"R3 `{name}` has value {g!r} — not a grant mapping and not one of "
                      f"{sorted(NON_GRANT)}; fail-closed")
            fails += 1; continue
        # Normalize identically to the scalar branch above. Without .strip() a `state: "revoked "`
        # fell through and was validated as an ACTIVE grant (cross-family round 4) — two spellings of
        # the same state judged by two different normalizers is the divergent-normalizer class.
        # H6 UNKNOWN STATE. Only the three canonical states were recognized; anything else — a typo
        # like `revokedd`, or a state a future version adds — fell through and was validated as an
        # ACTIVE grant. A record whose state we cannot read is not a grant we may honour.
        if "state" in g:
            st = g["state"]
            if not isinstance(st, str) or st.strip().lower() not in (NON_GRANT | {"granted"}):
                out("❌", f"R3 `{name}` has unrecognized state {st!r} — expected one of "
                          f"{sorted(NON_GRANT | {'granted'})}; fail-closed")
                fails += 1; continue
            if st.strip().lower() in NON_GRANT:
                continue
        validated += 1
        c = by_name.get(name)
        if c is None:
            out("❌", f"R3 `{name}` granted but NOT in the registry (unregistered == unknown)"); fails += 1; continue
        if not c.get("promotion_eligible"):
            out("❌", f"R4 `{name}` granted but registry says promotion_eligible:false"); fails += 1; continue
        # H5 `granted` was never checked at all — a grant with no grant date cannot be audited
        # against the three approvals that were supposed to produce it.
        def _date(v, fld):
            if isinstance(v, datetime.date):
                return v
            if isinstance(v, str) and re.fullmatch(r"\d{4}-\d{2}-\d{2}", v.strip()):
                try:
                    return datetime.date.fromisoformat(v.strip())
                except ValueError:
                    return None
            return None   # ints like 29991231 are NOT dates; basic-format parsing accepted them
        gd = _date(g.get("granted"), "granted")
        if gd is None:
            out("❌", f"R5 `{name}` has missing or non-ISO `granted` ({g.get('granted')!r}) — "
                      f"expected YYYY-MM-DD"); fails += 1
        elif gd > today:
            # A consent dated in the future has not been given. `granted: 2099-01-01` passed.
            out("❌", f"R5 `{name}` is `granted` {gd}, in the FUTURE — a consent that has not "
                      f"happened yet cannot authorize anything"); fails += 1
        exp = g.get("expires")
        if exp is None:
            out("❌", f"R5 `{name}` granted with no `expires` — standing consent is a lease, not a transfer"); fails += 1
        else:
            d = _date(exp, "expires")
            if d is None:
                out("❌", f"R5 `{name}` has non-ISO expires={exp!r} — expected YYYY-MM-DD "
                          f"(`29991231` parsed as a date under basic-format rules and slipped through)")
                fails += 1
            elif d < today:
                out("❌", f"R5 `{name}` expired {d} — must lapse to unset, not keep running"); fails += 1
            # H7 LEASE BOUND. `expires: 9999-12-31` satisfied "has an expiry" while defeating the
            # entire point of one. A lease longer than the maximum is a transfer wearing a lease's
            # clothes.
            elif gd is not None and (d - gd).days > MAX_LEASE_DAYS:
                out("❌", f"R5 `{name}` lease is {(d - gd).days} days (max {MAX_LEASE_DAYS}) — "
                          f"an unbounded expiry is a transfer, not a lease"); fails += 1
        # R6 — a grant with no recorded scope can never be re-validated against a drifted action.
        # R6 — presence AND type. The registry side got strict types at R1-b; the grant side did not,
        # so `effects: true` / `target: 123` were "recorded" and passed while a MISSING field was
        # caught (measured with that control, cross-family round 7). Half a fix propagated is a hole:
        # a baseline that is not a list-of-effects and a real target string cannot be compared against
        # anything later, which is the entire purpose of recording it.
        eff, tgt = g.get("effects"), g.get("target")
        if eff is None or tgt is None:
            out("❌", f"R6 `{name}` grant records no `effects`+`target` — the subset check has no baseline")
            fails += 1
        else:
            if not isinstance(eff, list) or not eff or not all(isinstance(e, str) and e.strip() for e in eff):
                out("❌", f"R6 `{name}` `effects` must be a non-empty list of strings, got "
                          f"{type(eff).__name__} {eff!r} — an uncomparable baseline is not a baseline")
                fails += 1
            if not isinstance(tgt, str) or not tgt.strip():
                out("❌", f"R6 `{name}` `target` must be a non-empty string, got "
                          f"{type(tgt).__name__} {tgt!r}")
                fails += 1
            # R7 STORED-SCOPE SUBSET. The grant recorded its own scope and nothing compared it to
            # what the registry actually authorizes, so `effects: [repo-mutation]` sat happily under
            # a `capabilities: [read]` class. This is the mechanizable HALF of the subset rule: it
            # cannot see a LIVE action (still a runtime obligation, still named as residual), but a
            # STORED grant wider than its own class is checkable right here — and was not checked.
            if isinstance(eff, list) and all(isinstance(e, str) for e in eff):
                # One normalizer, both sides. Before this the grant side was stripped and the
                # registry side was not, so `[" read "]` matched while `[READ]` did not — whitespace
                # forgiving, case strict, for no stated reason. Divergent normalizers on the two
                # sides of a comparison is the same defect class this file already fixed twice.
                over = sorted({_norm(e) for e in eff} - {_norm(x) for x in c["capabilities"]})
                if over:
                    out("❌", f"R7 `{name}` grant claims effect(s) {over} outside its registered "
                              f"capabilities {c['capabilities']} — the grant is wider than the class")
                    fails += 1
            if isinstance(tgt, str) and _norm(tgt) != _norm(str(c["target"])):
                out("❌", f"R7 `{name}` grant target {tgt!r} does not match the registered target "
                          f"{c['target']!r} — scope drift between grant and class")
                fails += 1
    if fails == 0:
        skipped = len(grants) - validated
        note = f" ({skipped} non-grant state(s) skipped)" if skipped else ""
        out("✅", f"R3-R6 all {validated} active grant(s) registered, eligible, unexpired, "
                  f"scope-recorded{note}")

print("----")
print(f"consent-registry: {'PASS' if fails == 0 else f'{fails} violation(s)'}")
sys.exit(0 if fails == 0 else 1)
PY
