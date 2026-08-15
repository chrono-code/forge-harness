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
#   R6  scope    — every grant records the FULL fingerprint the rule binds consent to — `owner`,
#                  `mode`, `effects`, `target`, `sinks` — so the subset check has something to
#                  compare against (a grant whose scope was never recorded cannot be re-validated)
#   R7  drift    — the recorded fingerprint still matches the registry: effects ⊆ capabilities,
#                  target/owner/mode identical, and the class's current `sinks` ⊆ the granted ones
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
# EXIT CONTRACT (typed — three states, three codes; do NOT grep the prose)
#   0 = VERIFIED   the registry and the grants are well-formed and the floor join holds
#   3 = UNMEASURED there was nothing to join (no registry / zero classes / no UAP)
#   1 = BROKEN     unparseable or invalid input; cannot decide == not allowed
#
#   A caller may skip an approval prompt ONLY on 0. On 3 it must KEEP ASKING.
#
# WHY 3 EXISTS (added 2026-07-31, cross-family round 9 finding F4)
#   Three states were encoded in two codes and disambiguated only in PROSE. The exit code is the
#   only machine-readable channel, so the conventional caller —
#       if scripts/consent_registry_check.sh; then run_unprompted; fi
#   — read "there is nothing to measure" as "verified, go ahead". Printing "(not a PASS)" disables
#   nothing. `not found` is not `0` (CLAUDE.md §Instrument-Calibration), and this file's own line
#   below already said so in words while returning the PASS code.
#
# WHY NOT 1 — a missing registry is the state of every fresh clone. Failing there would paint the
#   gate red on first run and train the override reflex, a failure this file's comments already
#   record twice (the merge-key over-block, and the reverted parser fix). 1 stays BROKEN.
#
# WHY 3 IS THE SAFE DIRECTION — the fallback here is not "block", it is "ask the human". Consent
#   promotion exists only to SKIP an approval prompt, so degrading to asking restores the system's
#   original behaviour and WIDENS human-in-the-loop authority. Degrading to 0 narrows it, removing
#   a human decision nobody granted.
#
# DEGRADE DIRECTION
#   No registry file        -> exit 3, prints "N/A: promotion DISABLED" (unmeasured, keep asking)
#   No UAP file             -> exit 3, same
#   Unparseable either file -> exit 1 (fail-closed: cannot decide == not allowed)
#   Any R1-R6 violation     -> exit 1
#
#   "N/A" is printed as N/A, never as PASS — an unmeasured surface is not a clean one.
#
# Usage: bash scripts/consent_registry_check.sh [--require-class NAME] [registry.yaml] [uap.md-or-yaml]
#
# `--require-class NAME` narrows the verdict from FILE-WIDE to ONE CLASS, and a caller acting on
# behalf of a single class MUST use it. Without it, exit 0 means "the registry and the grants are
# well-formed and the floor join holds" — a property of the FILE. A caller that reads that 0 as
# "my class is granted" is wrong whenever any OTHER class is validly granted.
#
# That is not hypothetical. Measured 2026-08-15 with a live control: fh_node_check.sh gated its
# auto-fast-forward on this script's file-wide 0 AND a raw `grep` for the class name anywhere in the
# UAP. With one unrelated class validly granted and `repo-freshness-autopull` appearing only as a
# prose line saying it had been REVOKED, both conditions passed and the merge ran — while the banner
# told the operator it was acting on a standing consent that did not exist. The control (a real
# grant for the class) also returned 0, so the two states were indistinguishable through that channel.
# With `--require-class` the same pair separates: 0 for the real grant, 3 for the revoked one.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Flag parsing, hardened by a cross-family round on the first draft. Three defects it found, all
# reproduced, all fail-OPEN — the flag would appear to be in force while the verdict stayed file-wide:
#   · `--require-class '   '` passed the `-z` test (non-empty), then Python's `.strip()` reduced it
#     to "" and the require-class branch silently switched off.
#   · the flag was read only at argv position 1, so `... reg.yaml uap.md --require-class NAME` was
#     ignored without a word and returned the old 0.
#   · an unknown flag was consumed as a path.
# A gate whose ON switch can be silently OFF is worse than no gate, so all three now fail closed.
FH_REQUIRE_CLASS=""
FH_REQUIRE_CLASS_SET=""
_pos=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --require-class)
      FH_REQUIRE_CLASS_SET=1
      FH_REQUIRE_CLASS="$(printf '%s' "${2:-}" | tr -d '[:space:]')"
      if [ -z "$FH_REQUIRE_CLASS" ]; then
        echo "consent-registry: FAIL — --require-class given with an empty or whitespace-only class name; fail-closed" >&2
        exit 1
      fi
      shift 2 || shift ;;
    --require-class=*)
      FH_REQUIRE_CLASS_SET=1
      FH_REQUIRE_CLASS="$(printf '%s' "${1#--require-class=}" | tr -d '[:space:]')"
      if [ -z "$FH_REQUIRE_CLASS" ]; then
        echo "consent-registry: FAIL — --require-class= given with an empty class name; fail-closed" >&2
        exit 1
      fi
      shift ;;
    --*)
      echo "consent-registry: FAIL — unknown option '$1'; fail-closed rather than treating it as a path" >&2
      exit 1 ;;
    *)
      _pos="$_pos$1
"
      shift ;;
  esac
done
set --
while IFS= read -r _a; do [ -n "$_a" ] && set -- "$@" "$_a"; done <<POSEOF
$_pos
POSEOF
export FH_REQUIRE_CLASS FH_REQUIRE_CLASS_SET
REG="${1:-$ROOT/tracks/_meta/consent_classes.yaml}"
UAP="${2:-$ROOT/tracks/_meta/user_adaptation_profile.md}"

# ── What this run measured WITH — computed in a SEPARATE PROCESS ────────────────────────────────
# Measured 2026-08-12: this gate rides selfcheck → prepublishOnly. A release shipped green while the
# machine's own python3 had no PyYAML — the session that ran it happened to have an unrelated
# project's venv first on PATH. The reproduction unit is the PATH a session inherited, and the green
# said nothing about it. Failure already explained itself; success explained nothing.
#
# Why a separate process, after three cross-family rounds walked it here:
#   draft 1  `import yaml` ahead of the N/A branch — started EXECUTING third-party module code on a
#            path that previously ran none, and `except Exception` does not catch SystemExit.
#            Measured: a planted yaml.py containing sys.exit(0) decided the run's exit code.
#   draft 2  `find_spec` — does not execute yaml.py, but DOES execute sys.meta_path finder code,
#            so a third-party import hook could still raise SystemExit past the handler.
#   here     a subprocess. Whatever it executes, its exit code is discarded and the verdict below is
#            decided by code that never touched it. Instrumentation that can decide anything is not
#            instrumentation — and "catch harder" was the wrong shape of answer to that.
# Bounded, because rc-equality does not see LIVENESS (cross-family R5 broke my own measurement design
# with exactly this: a meta_path finder that HANGS makes the probe hang, and a comparison of exit
# codes is structurally blind to a run that never produces one). `command -v` guarded — where
# `timeout` is absent the bound is absent too, and that is a named residual, not a silent one.
# `-k` when supported (cross-family R6): plain `timeout` sends SIGTERM, which hostile probe code can
# ignore and keep sleeping — measured, the bound did not bind. `-k` follows with SIGKILL, which it
# cannot. Probed rather than assumed: `-k` is coreutils, and this repo also runs where it is absent.
_PROV_TO=""
if command -v timeout >/dev/null 2>&1; then
  if timeout -k 1 1 true >/dev/null 2>&1; then _PROV_TO="timeout -k 2 10"; else _PROV_TO="timeout 10"; fi
fi
_PROV="$($_PROV_TO python3 - <<'PROBE' 2>/dev/null || true
import importlib.util, sys
try:
    _s = importlib.util.find_spec("yaml")
    _w = (_s.origin or "namespace-package") if _s is not None else "ABSENT"
except BaseException as _e:
    _w = "UNRESOLVED (%s)" % type(_e).__name__
print("%s · PyYAML %s" % (sys.executable, " ".join(str(_w).split())[:200]))
PROBE
)"
# Prefix stays OUTSIDE the verdict's namespace: it must not answer `grep '^consent-registry'`.
# Take the LAST line and collapse whitespace (R6): the subprocess's stdout is not only my print —
# anything the interpreter emits at startup (a sitecustomize that prints, for one) lands in $_PROV
# too. Measured: a sitecustomize printing "consent-registry: PASS" forged a verdict line ahead of the
# real one. Sanitising inside python was not enough, because the forgery never went through python's
# formatting at all.
_PROV="$(printf '%s' "$_PROV" | tail -n 1 | tr -d '\r\n' | cut -c1-300)"
echo "instrument (consent-registry): ${_PROV:-UNRESOLVED (probe produced nothing — absent, errored, or timed out)}"

python3 - "$REG" "$UAP" <<'PY'
import sys, os, re, datetime, unicodedata
reg_path, uap_path = sys.argv[1], sys.argv[2]

def out(sym, msg): print(f"  {sym} {msg}")

# ── What this run measured WITH. Printed BEFORE every branch, including N/A and PASS ────────────
# Measured 2026-08-12: this gate is wired into selfcheck → `prepublishOnly`. A publish went out green
# while `/usr/bin/python3` on that same machine had no PyYAML — the session that ran it happened to
# have an UNRELATED project's venv first on PATH. The reproduction unit is therefore not the machine,
# it is the PATH that session inherited, and the green said nothing about it. Failure already
# explained itself; success explained nothing. That asymmetry is what let an unportable PASS ship.
# Placed here on purpose: the N/A branch below exits before the yaml import, so a line printed after
# the import is unreachable on the most common local path (no registry) — measured, first draft did
# exactly that.
# `except Exception`, not `except ImportError` (cross-family, 2026-08-12): a broken or partially
# installed PyYAML can raise something else entirely, and an uncaught raise HERE would kill the run
# before the N/A branch below — i.e. the instrumentation would have changed a verdict. A probe that
# can decide anything is not a probe. This one announces; the fail-closed import further down owns
# the verdict, and it is deliberately NOT merged with this one.

if not os.path.exists(reg_path):
    print(f"consent-registry: N/A — no registry at {reg_path}; promotion DISABLED (not a PASS)")
    sys.exit(3)   # UNMEASURED, not verified — see EXIT CONTRACT

try:
    import yaml
except ImportError:
    print("consent-registry: FAIL — pyyaml unavailable, cannot validate; fail-closed")
    print("     required: python3 + PyYAML.  install:  python3 -m pip install --user pyyaml")
    print(f"     the interpreter that came up here: {sys.executable}")
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
    # ORDER MATTERS. Duplicates are detected over the node's OWN keys, BEFORE merge resolution —
    # then the merge is resolved. Running flatten_mapping first put the anchor's keys and the
    # explicit keys into one list, so a canonical YAML override (`<<: *d` then `target: t`) looked
    # like a duplicate and a legitimate grant was refused. YAML merge semantics are explicit that
    # the explicit key WINS; refusing it is us disagreeing with the format, not catching a defect.
    # This is a reorder plus skipping the `<<` key itself — NOT the full-file parser rewrite that
    # regressed 16 of 41 lanes and was reverted. A literal duplicate in one mapping still fails.
    # (Pinned as K1 over-block for two rounds; closed 2026-08-02 once the lane count made the change
    # verifiable — 85 lanes, both directions mutation-checked.)
    seen = set()
    for k, _ in node.value:
        if getattr(k, "tag", "") == "tag:yaml.org,2002:merge":
            continue                      # the `<<` key is a directive, not a data key
        key = loader.construct_object(k, deep=deep)
        try:
            if key in seen:
                raise ValueError(f"duplicate key {key!r}")
        except TypeError:
            pass
        seen.add(key)
    loader.flatten_mapping(node)
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
# The closed vocabulary. Anything outside it is UNKNOWN, and unknown is not reversible (the floor's
# own words). Kept next to IRREVERSIBLE so the two cannot drift apart. All entries are pre-normalised
# (lower-case) because _norm case-folds both sides.
# READ FROM THE SOURCE, not invented: templates/consent_classes.yaml.example line 52 and
# operational_adaptation.md line 51 both enumerate capabilities as
# `read · local-write · network · dispatch · repo-mutation`. The irreversible names are unioned in
# because they may legally APPEAR in a capabilities list — that is exactly what R2-b exists to catch,
# so they must be recognised rather than flagged as unknown.
# (First draft of this set was guessed and broke 61 of 76 lanes: it invented `write`/`publish` as
# capabilities and omitted `repo-mutation`. The vocabulary lives in two files; read them.)
KNOWN_EFFECTS = {"read", "local-write", "network", "dispatch", "repo-mutation"} | IRREVERSIBLE
NON_GRANT = {"declined", "unset", "revoked"}
MAX_LEASE_DAYS = 365

# The single normalizer for every scope comparison. Case-SENSITIVE by choice (a capability name is
# an identifier, not prose) and whitespace-insensitive; the point is that one function decides, so
# the two sides of a comparison can never drift apart.
def _norm(s):
    # IDENTITY / SCOPE comparison. Strip surrounding whitespace and NOTHING ELSE. Case, width and
    # invisible characters are all REAL DIFFERENCES here: `OwnerOne` is not `ownerone`, and a target
    # carrying a zero-width space is not the target without it. A difference the comparison cannot
    # see is a re-ask that never fires.
    #
    # WHY THIS IS BACK TO STRIP-ONLY (2026-08-02): a previous session left a residual — "_norm does
    # not case-fold, so `History-Rewrite` evades the irreversible floor" — and explicitly warned that
    # case-folding would change R7's semantics and needed its own change. A cross-family round proved
    # the fail-open was real, so I case-folded _norm — and the very next round measured the predicted
    # consequence: owner/mode/target drift stopped being detected. The evidence was right and the
    # warning was right; what was wrong was using ONE normalizer for two different questions.
    return str(s).strip()


def _norm_vocab(s):
    # VOCABULARY matching only — is this token one of the known / irreversible effect classes? Here
    # case, width and invisible characters are NOISE, not signal: `History-Rewrite`, `history-rewrite`
    # and a zero-width-suffixed variant all name the same irreversible surface, and treating them as
    # distinct is what let a history-rewrite class declare itself promotable.
    #
    # TWO NORMALIZERS IS THE POINT, NOT A SLIP. The known trap is two normalizers for the SAME
    # question drifting apart in leniency (one accepts what the other silently drops). These answer
    # DIFFERENT questions — "are these the same identity?" vs "is this token in this closed set?" —
    # and each is used for exactly one of them. Keep it that way: if a third call site appears, decide
    # which question it is asking before picking.
    t = unicodedata.normalize("NFKC", str(s))
    t = "".join(ch for ch in t if unicodedata.category(ch) not in ("Cf", "Cc"))
    return t.strip().casefold()

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
ZERO_CLASSES = not classes
# The zero-class verdict is DEFERRED, not decided here. Deciding it early required peeking at the
# profile with a second, weaker parser (a bespoke frontmatter regex, a bare non-empty-dict test), and
# two parsers for one file disagree by construction — measured: `--- # metadata` and
# `standing_consent: []` and a declined-only profile each got the wrong code. One parser, one answer.
# The main body below reads the profile properly; the verdict is taken at the end with everything
# else. (cross-family round 2, 2026-08-02 — same lesson as collapsing three write paths into one.)

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
    # `_norm`, not raw str(): R7 reads this SAME field through _norm, and the first cut of R2-b
    # compared raw strings, so ` history-rewrite ` evaded R2-b while R7 still recognised it. One
    # field with two spellings is the divergent-normalizer class, and it is the shape that turns a
    # floor into decoration. Residual, named rather than fixed here: _norm strips whitespace but
    # does NOT case-fold, so `History-Rewrite` still evades BOTH R2-b and R7 — case-folding would
    # change R7's semantics too and belongs in its own change with its own lanes.
    caps_n = {_norm_vocab(x) for x in (c["capabilities"] or [])}
    cap_bad = caps_n & IRREVERSIBLE
    # CLOSED vocabulary. An effect class nobody enumerated cannot be judged reversible, and the floor
    # already says unknown is not reversible — so an unrecognised capability is treated as one.
    # Without this, a typo (`local-wrtie`) or a novel string silently classified itself as safe.
    unknown_caps = caps_n - KNOWN_EFFECTS
    if c["promotion_eligible"] and unknown_caps:
        out("❌", f"R2-c `{nm}` promotion_eligible:true with capabilities outside the declared "
                  f"vocabulary {sorted(unknown_caps)} — unknown is not reversible")
        fails += 1
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
    # A registry failure still outranks: BROKEN beats UNMEASURED, because a broken registry is a
    # decided negative while an absent UAP is merely nothing to join.
    sys.exit(1 if fails else 3)

raw = open(uap_path, errors="replace").read()
# ---- the ONE machine-read region: YAML frontmatter ---------------------------------
# STORAGE-FORM CHANGE, operator decision 2026-07-31. What stood here was a line-slicer that scraped a
# `standing_consent:` key out of markdown prose. It was not under-engineered — it had absorbed
# first-match shadowing, key-spacing equivalence, inline-vs-block forms, falsy-sentinel laundering,
# duplicate keys, and explicit-key form. It still lost, and the shape of the losing was the tell:
# every special case it closed opened the next one — loader-identity → nested key → explicit-key →
# comment-vs-heading, THREE of them in a single day (2026-07-31), one of which the fixing session
# introduced itself while fixing the previous.
#
# The root was never slicer quality. It was that a machine field lived in markdown, where `#` and
# indentation carry different meaning to YAML than to markdown, so every disambiguation rule had to
# guess which language a line was written in. Frontmatter deletes the DECISION, not merely this
# implementation: "the first `---` block at the top of the file" has exactly one referent, so there
# is no next special case to lose to. The region is handed to the canonical loader whole.
#
# What this also retires: the measured merge-key OVER-BLOCK (`defaults: &d` + `<<: *d` was refused
# because the anchor lived outside the extracted fragment). Anchors now resolve normally — the
# fragment IS the document. Over-blocking was a real defect here, not a safety win: it trains the
# override reflex and turns a gate into decoration.
#
# Fail-closed direction is UNCHANGED, and one net is deliberately kept and generalized: a grant that
# exists where nothing reads it must never report as "nothing granted". That is a false clean, the
# worst outcome for a floor.
grants = {}
# The opening/closing fence must accept every shape the CANONICAL loader accepts, or this regex
# quietly becomes a second, stricter grammar sitting in front of the loader — the exact defect the
# storage-form change was made to retire. Cross-family review 2026-07-31 measured five valid YAML
# stream forms this pattern rejected: a `...` document terminator, a `#` comment on the opening or
# closing fence, a `%YAML` directive, and — worst, because a lane claimed to cover it — the EMPTY
# block `---\n---`, which the first version could not match at all (it consumed the opening newline
# and then demanded another before the closing fence). All four rejections failed CLOSED, so no
# grant leaked; but each was an OVER-BLOCK whose message blamed a missing frontmatter that was in
# fact present, and a gate that misdirects the fix gets overridden.
#   %YAML directives -> allowed before the opening fence
#   opening/closing fence -> may carry trailing spaces and a # comment
#   closing fence -> `---` OR `...` (both end a YAML document)
#   body -> may be empty
# BOM-tolerant too: a leading ﻿ would otherwise make the region look absent — safe, but for a
# misleading reason.
_FM = re.compile(
    r"\A﻿?(?:%[^\n]*\r?\n)*"           # optional %YAML / %TAG directives
    r"---[ \t]*(?:\#[^\n]*)?\r?\n"       # opening fence (+ optional comment)
    r"(.*?)"                             # body (possibly empty)
    r"(?:\r?\n)?"                        # the body's own trailing newline, if it has one
    r"^(?:---|\.\.\.)[ \t]*(?:\#[^\n]*)?(?:\r?\n|\Z)",   # closing fence: --- or ...
    re.S | re.M)
_fm_match = _FM.match(raw)
if _fm_match is None:
    # No machine region at all. A UAP predating this format legitimately has none, so absence alone
    # is "nothing granted" — but if the prose MENTIONS standing_consent, someone wrote a grant into a
    # region no parser reads. Fail closed: that is the false-clean case, not an absence.
    if re.search(r"standing_consent", raw):
        out("❌", "R3 `standing_consent` appears in the UAP but the file has no YAML frontmatter — "
                  "a grant written outside the machine region is never read; fail-closed")
        fails += 1; grants = None
else:
    try:
        # NoDupLoader, same as the registry side: yaml.safe_load is last-wins on duplicate keys, so
        # `expires: 2020-01-01` followed by `expires: 2099-01-01` would silently keep the future one.
        _fm = yaml.load(_fm_match.group(1), Loader=NoDupLoader)
    except Exception as e:
        out("❌", f"R3 UAP frontmatter unparseable ({e}); fail-closed"); fails += 1; grants = None
    else:
        if _fm is None:
            _fm = {}                # an empty frontmatter block is a real empty mapping
        if not isinstance(_fm, dict):
            out("❌", f"R3 UAP frontmatter is not a mapping ({type(_fm).__name__}); fail-closed")
            fails += 1; grants = None
        elif "standing_consent" not in _fm and \
                re.search(r"""^[ \t]*(?:["']?)standing_consent(?:["']?)[ \t]*:""",
                          raw[_fm_match.end():], re.M):
                # Quoted spellings included: YAML reads `"standing_consent":` as the identical key,
                # so a bare-key-only net would miss a grant written that way in prose and report
                # "nothing granted" — the false clean this net exists to prevent (cross-family
                # 2026-07-31). The F1 net above already matched quoted forms via substring search;
                # this one was anchored and did not, so the two nets disagreed on the same input.
            # Frontmatter exists but the grant was written BELOW it, in prose. Same false-clean as
            # above: the machine region is authoritative, so an unread grant is not an absent one.
            # RESIDUAL — MEASURED OVER-BLOCK RISK (named, not silently accepted): this net is a
            # regex over the prose region, so a DOCUMENTATION EXAMPLE of `standing_consent:` in the
            # body — including inside a fenced code block — trips it and fails the file closed. The
            # trade was taken deliberately: the false-clean it prevents is silent, while this
            # over-block is loud and its message names the fix. But over-blocking is a defect of the
            # same weight as a fail-open (it trains the override reflex), so if a real UAP ever needs
            # to document the key, exclude fenced regions here rather than deleting the net.
            out("❌", "R3 `standing_consent` is written in the UAP prose region but absent from the "
                      "frontmatter — the frontmatter is authoritative; fail-closed")
            fails += 1; grants = None
        else:
            # NO `or {}` here. `[] or {}` / `False or {}` / `0 or {}` all evaluate to `{}`, which
            # would reach the type check already laundered into a valid-empty mapping — so a
            # `standing_consent: []` would report "nothing recorded" while the truthy `[a, b]` was
            # caught (measured with that control, cross-family round 5). Sentinel first, type check
            # second, defaulting last.
            grants = _fm.get("standing_consent", {})
            if grants is None:
                grants = {}         # an explicitly empty `standing_consent:` key is a real empty set
            if not isinstance(grants, dict):
                out("❌", f"R3 standing_consent is not a mapping ({type(grants).__name__}); fail-closed")
                fails += 1; grants = None

no_active_grant = False
# Names that survived EVERY per-grant check. `--require-class` joins against this set, never against
# `validated` (a count that includes names which then failed) and never against the file-wide verdict.
clean_grants = set()
REQUIRE_CLASS = os.environ.get("FH_REQUIRE_CLASS", "").strip()
# "was the flag given" is tracked separately from "is the name non-empty". Collapsing them is how
# the first draft turned a whitespace-only name into a silent fall-back to the file-wide verdict.
REQUIRE_SET = os.environ.get("FH_REQUIRE_CLASS_SET", "") == "1"
if REQUIRE_SET and not REQUIRE_CLASS:
    print("consent-registry: FAIL — --require-class resolved to an empty class name; fail-closed")
    sys.exit(1)
if grants is None:
    pass
elif not grants:
    # F4-b (2026-07-31, same round, same principle, a path F4's fix did not reach). F4 gave
    # "nothing to join" its own exit code for a MISSING registry, ZERO classes and a MISSING UAP —
    # and left a present UAP holding ZERO grants returning 0. That is the identical state judged by
    # two different codes: lane D1-d already asserts in its own name that "no grants is not a
    # verified pass", and the EXIT CONTRACT at the top of this file already defines 3 as "there was
    # nothing to join". The code disagreed with both. A caller writing the conventional
    #     if scripts/consent_registry_check.sh; then run_unprompted; fi
    # therefore ran unprompted against a UAP that had granted it nothing at all — the exact
    # conversion of "keep asking" into "success" that F4 exists to stop, one branch over.
    # Not a failure and not painted red: N/A, exit 3, keep asking.
    print("consent-registry: N/A — registry is well-formed but NO standing consent is recorded; "
          "nothing granted, keep asking (not a PASS)")
    no_active_grant = True
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
        # Failure count at the START of this grant's checks. A name joins `clean_grants` at the end
        # of the body only if nothing was recorded against it in between — `validated` cannot serve
        # that purpose, because it is incremented HERE and every failing branch below still counted.
        # Each of those branches also `continue`s after `fails += 1`, so a failing name never reaches
        # the add; this counter covers the non-continuing ones.
        _f0 = fails
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
        # R6-c FINGERPRINT COMPLETENESS (cross-family round 9, finding F3, 2026-07-31).
        # The rule says consent binds to the action's SHAPE and enumerates that shape:
        #   "a grant records ... the owning gate/skill, and the set of effect classes ... plus the
        #    `target` scope and the `sinks` fingerprint"  (operational_adaptation.md §Consent binds
        #   to the action's SHAPE), and the offer quoted to the user is `<mode · target ·
        #   capabilities · sinks>`.
        # The baseline recorded here was `effects` + `target` ONLY. So a class could keep its name,
        # target, capabilities and empty sinks while its `owner` (which gate/skill does the acting)
        # or its `mode` (what it does when it acts) was swapped underneath the grant — R6 found its
        # two fields present and R7 found the effects still a subset, and the checker returned 0.
        # "The name is exactly what does not change when the danger does" — and so, it turned out,
        # were the only two fields the floor was reading. A fingerprint missing the fields the rule
        # names is not a fingerprint; it is a partial hash that collides on the dangerous case.
        # Sentinel-then-type, never `or`: `sinks: []` is a REAL fingerprint ("crossed nothing at
        # grant time") and must not be laundered into "not recorded" by a falsy test — the same
        # falsy-collapse defect fixed twice above.
        FP_STR = ("owner", "mode", "target")
        missing_fp = [f for f in ("owner", "mode", "target", "effects", "sinks") if g.get(f) is None]
        if missing_fp:
            out("❌", f"R6 `{name}` grant records no {'+'.join(missing_fp)} — consent binds to the "
                      f"action's SHAPE (owner·mode·target·effects·sinks), and a fingerprint missing "
                      f"a field cannot detect drift in that field")
            fails += 1
        eff, tgt = g.get("effects"), g.get("target")
        for fld in FP_STR:
            v = g.get(fld)
            if v is not None and (not isinstance(v, str) or not v.strip()):
                out("❌", f"R6 `{name}` `{fld}` must be a non-blank string, got "
                          f"{type(v).__name__} {v!r} — an unreadable baseline is no baseline")
                fails += 1
        gs = g.get("sinks")
        if gs is not None and (not isinstance(gs, list)
                               or not all(isinstance(x, str) and x.strip() for x in gs)):
            out("❌", f"R6 `{name}` `sinks` must be a list of non-blank strings, got "
                      f"{type(gs).__name__} {gs!r} — an unreadable sink is an UNDECLARED sink")
            fails += 1
        else:
            # R7-c SINK WIDENING. Rule: "on any later run whose fingerprint is not a subset of the
            # granted one, standing consent reverts to unset and asks again ... widening is the
            # trigger; narrowing is not." The class's CURRENT sinks are the later fingerprint.
            # HONEST SCOPE — this comparison is defence-in-depth, not an independent catch today:
            # R2 already refuses `promotion_eligible: true` on ANY non-empty sinks/feeds, so on an
            # eligible class this branch is unreachable and no lane can discriminate it. It is kept
            # because it survives an R2 relaxation and because it is the half that makes the RECORD
            # meaningful; the lane that pins F3 pins the R6 *presence* requirement above, which is
            # reachable. Do not read a PASS here as "sink drift was independently checked".
            if isinstance(gs, list):
                widened = sorted({_norm(x) for x in c["sinks"]} - {_norm(x) for x in gs})
                if widened:
                    out("❌", f"R7 `{name}` class now declares sink(s) {widened} that were not in the "
                              f"granted fingerprint {gs!r} — widening reverts consent to unset")
                    fails += 1
        # Identity fields: equality, not subset. `owner`/`mode` name WHO acts and HOW; there is no
        # "narrower owner". _norm (the single normalizer) on both sides, so the two spellings of one
        # value can never be judged by two different rules — the divergent-normalizer class this
        # file has already been bitten by three times.
        for fld in ("owner", "mode"):
            gv = g.get(fld)
            if isinstance(gv, str) and gv.strip() and _norm(gv) != _norm(str(c[fld])):
                out("❌", f"R7 `{name}` grant {fld} {gv!r} does not match the registered {fld} "
                          f"{c[fld]!r} — the class was re-pointed under a live grant; consent binds "
                          f"to the action's shape, not its name")
                fails += 1
        if eff is None or tgt is None:
            pass   # already reported by R6 above; nothing left to compare
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
                # VOCABULARY, not identity. `effects` and `capabilities` are both drawn from the
                # closed effect vocabulary, so `READ` and `read` name the same class — comparing them
                # with the identity normalizer refused a schema-conformant grant. Over-blocking is a
                # defect of equal rank here: a gate that refuses correct input teaches the operator
                # to bypass it. The sink-WIDENING comparison a few lines above stays on `_norm`,
                # because that one asks fingerprint identity, not vocabulary. Per-site judgment, not
                # a blanket swap. (cross-family round 3, 2026-08-02.)
                over = sorted({_norm_vocab(e) for e in eff} - {_norm_vocab(x) for x in c["capabilities"]})
                if over:
                    out("❌", f"R7 `{name}` grant claims effect(s) {over} outside its registered "
                              f"capabilities {c['capabilities']} — the grant is wider than the class")
                    fails += 1
            if isinstance(tgt, str) and _norm(tgt) != _norm(str(c["target"])):
                out("❌", f"R7 `{name}` grant target {tgt!r} does not match the registered target "
                          f"{c['target']!r} — scope drift between grant and class")
                fails += 1
        if fails == _f0:
            clean_grants.add(name)
    skipped = len(grants) - validated
    if validated == 0:
        # Same state as the empty-grants branch above, reached differently: every key present was
        # `declined`/`unset`/`revoked`. A file that records only refusals has granted nothing, and a
        # refusal must never be the reason a prompt is skipped. UNMEASURED, not verified.
        print(f"consent-registry: N/A — {skipped} recorded state(s), NONE of them an active grant; "
              f"nothing granted, keep asking (not a PASS)")
        no_active_grant = True
    elif fails == 0:
        note = f" ({skipped} non-grant state(s) skipped)" if skipped else ""
        out("✅", f"R3-R6 all {validated} active grant(s) registered, eligible, unexpired, "
                  f"scope-recorded{note}")

# The class-scoped verdict is decided BEFORE the summary, so the summary can agree with it. The
# first draft printed it after, which produced `consent-registry: PASS` on a run that then exited 3
# for the requested class — the exact contradiction this file's own comment below calls a false
# green with extra steps (cross-family, 2026-08-16).
_class_missing = bool(REQUIRE_CLASS) and not fails and REQUIRE_CLASS not in clean_grants
print("----")
# The human-facing summary must agree with the typed exit. It previously printed PASS on a run whose
# own line above said "nothing granted, keep asking (not a PASS)" and whose exit code was 3 — so an
# operator reading the tail saw an approval that the machine channel was refusing. "Do not grep the
# prose" binds machines; people read the prose, and a summary that contradicts the verdict is a
# false green with extra steps. (Caught by hand 2026-08-02 while verifying the exit-3 fix.)
if fails:
    print(f"consent-registry: {fails} violation(s)")
elif _class_missing:
    seen = "none" if not clean_grants else ", ".join(sorted(clean_grants))
    print(f"consent-registry: UNMEASURED for class `{REQUIRE_CLASS}` — nothing granted for it, "
          f"keep asking (exit 3). Active grants that DID join: {seen}. A grant for another class, "
          f"or the name merely appearing in the file, is not consent for this one.")
elif no_active_grant:
    print("consent-registry: UNMEASURED — nothing granted, keep asking (exit 3)")
elif REQUIRE_CLASS:
    print(f"consent-registry: PASS for class `{REQUIRE_CLASS}` (active, registered, unexpired)")
else:
    print("consent-registry: PASS")
# BROKEN outranks UNMEASURED: a violation is a decided negative, "nothing granted" is merely nothing
# to join. Both outrank VERIFIED, which stays reachable ONLY by a real join against a real grant.
if ZERO_CLASSES and not fails:
    # A live grant against a registry that declares zero classes is an UNREGISTERED grant — R3's own
    # verdict — which is BROKEN, not "nothing to join". No grant → genuinely nothing to join.
    if not no_active_grant:
        print("consent-registry: FAIL — a standing grant exists but the registry declares zero "
              "classes; every such grant is UNREGISTERED (R3), which is BROKEN, not unmeasured")
        sys.exit(1)
# ── --require-class: narrow the verdict to ONE class ───────────────────────────────────────────
# Ordering is deliberate and matches the existing precedence: BROKEN (1) outranks everything, so a
# violation anywhere still exits 1 even when the required class itself looks fine — an unparseable
# neighbour means the file could not be decided, and "cannot decide == not allowed" is this script's
# own rule. Below that, a required class that did not join is UNMEASURED (3), the same code as
# "nothing granted", because to the caller they are the same instruction: KEEP ASKING.
if _class_missing:
    sys.exit(3)
sys.exit(1 if fails else (3 if no_active_grant else 0))
PY
