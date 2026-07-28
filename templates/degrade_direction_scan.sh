#!/usr/bin/env bash
# degrade_direction_scan.sh — mechanical pre-screen for the "default-toward-PASS" smell
#
# The correlated blind spot measured 2026-07-03 across 3 harnesses (qasp/the-bible/pmh):
#   "When a verdict surface cannot mechanically ground its judgment, it defaults toward
#    PASS instead of safe-fail." Same-family review (even frontier + target-tier sim)
#   shares the author's optimistic reading of that discretion and misses it; a
#   different-family auditor catches it. This script is the cheap MECHANICAL pre-screen
#   that runs BEFORE the cross-family pass — it flags the code shapes where a permissive
#   value lands on an unconstrained branch, so the reviewer's attention goes there first.
#
# IT IS A REVIEW SURFACE, NOT A HARD GATE. Grep-heuristic → false positives are expected.
# A hit means "prove this is not default-toward-PASS", not "this is a bug". It never
# blocks a commit on its own (advisory exit code). The terminal verdict is the
# cross-family adversarial review + governor source-grounding, never this scan alone.
# (Irreversibility-gate note: because it is advisory, a degraded/empty run is a no-op,
#  not a free pass — the cross-family review is the load-bearing check it feeds.)
#
# NAMED RECALL RESIDUALS (cross-family audit, gpt-5.5, 2026-07-28 — accepted, not closed):
#   * Indirection defeats every probe. `allow() { exit 0; }` … `check || allow` is the same
#     fail-open shape one function call away, and a line-oriented grep cannot follow it. This is
#     inherent to the heuristic, not a bug to patch — it is why the terminal verdict is the
#     cross-family review, and why a clean run is never evidence of safety.
#   * The regression anchor proves the probes on the fixture GRAMMAR it ships, not on every
#     spelling of each class (e.g. `if ! cmd; then :; fi`, arithmetic-context defaults).
#
# Usage:
#   bash scripts/degrade_direction_scan.sh [path ...]        # scan dirs/files (default: .)
#   git diff --name-only main..HEAD -- '*.py' | xargs bash scripts/degrade_direction_scan.sh
# Exit:  0 = no smells found; 2 = smells found (ADVISORY signal — do not hard-block on it)
set -uo pipefail

TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=(".")

# Permissive values a verdict/gate surface must never land on by *default* / fall-through.
PASS='(True|"PASS"|'"'"'PASS'"'"'|"ALLOW"|'"'"'ALLOW'"'"'|"OK"|'"'"'OK'"'"'|"VALID"|'"'"'VALID'"'"'|"GRANTED"|'"'"'GRANTED'"'"'|"PASSED"|'"'"'PASSED'"'"'|allow|ALLOW)'

# Collect target files. Scannable = py + sh (the smell probes are Python-shaped but bash surfaces —
# incl. this gate's own pre-push/pre-commit-hook trigger category — must not be invisibly dropped).
# Anything else is tracked as UNSCANNABLE so a load-bearing surface in another language is reported
# as "not covered", never silently folded into an "advisory clean" (M#2, steel-quench 2026-07-03).
FILES=(); UNSCANNABLE=()
for t in "${TARGETS[@]}"; do
  if [ -d "$t" ]; then
    while IFS= read -r f; do FILES+=("$f"); done < <(find "$t" -type f \( -name '*.py' -o -name '*.sh' \) 2>/dev/null)
    # Shebang pass — this is what makes git hooks visible at all. Measured 2026-07-28:
    # `templates/.git-hooks` (files named `pre-push`, no extension, under a dotted directory) —
    # FH's own mechanical floor — reported "no scannable (py/sh) target files", exit 0.
    # Shebang pass. Deliberately NOT restricted to extensionless names: a cross-family audit
    # (2026-07-28, gpt-5.5) found that an earlier draft skipped any dotted basename, so a shell
    # file named `helper.bash` carrying an identical known-positive was dropped from a DIRECTORY
    # target in silence — while the explicit-file branch reported the same file as UNSCANNABLE.
    # Silent-drop on one path and honest-report on the other is the fail-open half. Confirmed by
    # running both paths on the same fixture before accepting the finding.
    while IFS= read -r f; do
      b="${f##*/}"                      # basename — a dotted DIRECTORY (.git-hooks) is not an extension
      case "$b" in
        *.py|*.sh) continue ;;          # already collected above
        *.md|*.json|*.yaml|*.yml|*.txt|*.lock|*.png|*.jpg|*.svg|*.pdf|*.zip) continue ;;
      esac
      head -n1 "$f" 2>/dev/null | grep -qE '^#!.*\b(ba|z|k)?sh\b' && FILES+=("$f")
    done < <(find "$t" -type f 2>/dev/null)
  elif [ -f "$t" ]; then
    tb="${t##*/}"
    case "$tb" in
      *.py|*.sh) FILES+=("$t") ;;
      *.*) UNSCANNABLE+=("$t") ;;
      *) if head -n1 "$t" 2>/dev/null | grep -qE '^#!.*\b(ba|z|k)?sh\b'; then FILES+=("$t"); else UNSCANNABLE+=("$t"); fi ;;
    esac
  fi
done
if [ ${#FILES[@]} -eq 0 ]; then
  if [ ${#UNSCANNABLE[@]} -gt 0 ]; then
    echo "degrade-scan: ${#UNSCANNABLE[@]} changed file(s) are OUTSIDE the scannable set (py/sh) — NOT scanned, NOT 'clean':"
    printf '  (unscannable) %s\n' "${UNSCANNABLE[@]}"
    echo "A load-bearing surface in another language must go straight to cross-family review."
    exit 2   # advisory non-clean — an orchestrator keying on exit code must not read this as clean
  fi
  echo "degrade-scan: no scannable (py/sh) target files"; exit 0
fi

hits=0
emit() { printf '  %s:%s\n    [%s] %s\n' "$1" "$2" "$3" "$4"; hits=$((hits+1)); }

for f in "${FILES[@]}"; do
  # ---- Shell-shaped probes (S*) -------------------------------------------------------------
  # Calibration finding (2026-07-28, known-pair): every probe below the S-block is PYTHON-shaped
  # (`except:` / `.get(k, True)` / `if not x:` / `.split()`), none of which exist in bash. A .sh file
  # was still COLLECTED and counted, so a fail-open shell gate printed "no smells in 1 scanned py/sh
  # file" — a FALSE CLEAN, which is worse than honest non-coverage. A known-positive .sh carrying four
  # distinct default-toward-PASS shapes scored 0/4. These probes close that; they run on any file
  # whose basename ends in .sh OR that carries a shell shebang (see the is_sh test below).
  is_sh=""; fb="${f##*/}"
  case "$fb" in
    *.sh) is_sh=1 ;;
    *.py) ;;
    # Any other collected file reached FILES only via the shebang pass, or is a dotted shell name
    # like `helper.bash`. Re-check the shebang rather than keying on the extension — keying on the
    # extension is what produced the collect-but-never-probe false clean this whole block exists to
    # close (n+10). Collected-but-unprobed must not be reachable again.
    *) head -n1 "$f" 2>/dev/null | grep -qE '^#!.*\b(ba|z|k)?sh\b' && is_sh=1 ;;
  esac
  if [ -n "$is_sh" ]; then
    # S1 — permissive short-circuit on a FAILING CHECK: `scan=$(...) || return 0`, `verify … || exit 0`.
    #   The check errored and the surface reports success. Safe-fail is `|| return 1` / `|| exit 1`.
    #   SCOPED to check-shaped left-hand sides (command substitution, or a verb like
    #   scan/check/verify/grep/audit/validate/gate). A PRECONDITION guard — `[ -d x ] || exit 0`,
    #   `[[ $d =~ … ]] || return 0` — is deliberately excluded: "this run does not apply here" is not
    #   the same claim as "this check passed". Hand-measured 2026-07-28: unscoped, 6/6 sampled hits
    #   were false positives, 4 of them precondition guards.
    #   EXCEPTION, re-added after an adversarial pass on this very scoping: a `-f`/`-x` test is a
    #   DEPENDENCY check, not a scope check. `[ -f "$GUARD_LIB" ] || exit 0` means "my guard library
    #   is missing, therefore allow" — the fail-open shape that bit qasp on 2026-07-28. Excluding it
    #   with the scope guards would have hidden exactly the class this scan exists to find.
    while IFS= read -r m; do
      emit "$f" "${m%%:*}" "S1:||→PASS(sh)" "failing check short-circuits to a permissive result (\`|| return 0\` / \`|| exit 0\` / \`|| true\`) — an errored check must fail closed, not report success"
    done < <(grep -nE '\|\|[[:space:]]*(return[[:space:]]+0|exit[[:space:]]+0|true)([[:space:]]*(#|;|$))' "$f" 2>/dev/null \
             | grep -vE '#[[:space:]]*noqa[:[:space:]]*degrade' \
             | grep -vE '^[0-9]+:[[:space:]]*(if[[:space:]]+)?\[\[?[[:space:]]*(-[dznN][[:space:]]|[^]]*=~)' \
             | grep -E '(\$\(|`|\[[[:space:]]*-[fx][[:space:]]|\b(scan|check|verify|validate|audit|grep|gate|assert|lint|test_)[A-Za-z_]*[[:space:](])')

    # S2 — `else` fall-through to a permissive exit/return within 2 lines (unenumerated case → allow).
    while IFS= read -r ln; do
      emit "$f" "$ln" "S2:else→PASS(sh)" "else/fall-through branch exits permissively — the unenumerated case should fail closed"
    done < <(grep -nE -A2 '^[[:space:]]*else[[:space:]]*$' "$f" 2>/dev/null \
             | grep -E '^[0-9]+[-:][[:space:]]*(exit[[:space:]]+0|return[[:space:]]+0)[[:space:]]*(#.*)?$' \
             | grep -oE '^[0-9]+' | sort -u)

    # S3 — empty/unset defaulted to a permissive VERDICT: `${V:-PASS}` / `V="PASS"` after a failed read.
    #   "the value never arrived" must not be spelled the same way as "the value said PASS".
    #   `${V:-0}` and `${V:-true}` are NOT flagged: numeric defaulting is the prescribed integer
    #   sanitization against the pipefail-fallback class (see S5), and flagging it would push an
    #   author to delete the remedy. Measured 2026-07-28 — `${PRS:-0}` in session_close_check.sh is
    #   the fix, not the defect. Only explicit verdict words count.
    while IFS= read -r m; do
      emit "$f" "${m%%:*}" "S3:default→PASS(sh)" "unset/empty defaults to a permissive verdict — absent is not clean (\`not found\` ≠ \`0\`); default to the blocking value"
    done < <(grep -nE "(\\$\{[A-Za-z_][A-Za-z0-9_]*:?-[[:space:]]*(PASS|OK|ALLOW|GRANTED|VALID|PASSED)\}|\|\|[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[\"']?(PASS|OK|ALLOW|GRANTED|VALID))" "$f" 2>/dev/null \
             | grep -vE '#[[:space:]]*noqa[:[:space:]]*degrade')

    # S4 — empty-output guard treated as clean: `if [ -z "$out" ]; then return 0/exit 0`.
    #   Identical to Probe E's falsy-sentinel class, in shell spelling: an errored scan produces empty
    #   output, so "found nothing" and "never ran" become indistinguishable.
    while IFS= read -r ln; do
      emit "$f" "$ln" "S4:empty→PASS(sh)" "empty output treated as clean — a scan that errored also produces empty output; distinguish 'errored/absent' from 'verified clean'"
    done < <(grep -nE -A2 '^[[:space:]]*(if|elif)[[:space:]]+\[+[[:space:]]*-z[[:space:]]' "$f" 2>/dev/null \
             | grep -E '^[0-9]+[-:][[:space:]]*(exit[[:space:]]+0|return[[:space:]]+0)[[:space:]]*(#.*)?$' \
             | grep -oE '^[0-9]+' | sort -u)

    # S5 — the pipefail-fallback disarm: `... | grep -c ... || echo 0` appends a SECOND line under
    #   `set -o pipefail`, so the later `-gt` integer test becomes a bash error (= false) and the guard
    #   passes silently, with the error going only to stderr. Measured class, 2026-07-26.
    #
    # NARROWED 2026-07-28 after hand-verifying all 9 hits this repo produced: 9/9 were false
    # positives, i.e. the probe was pure noise for its own class, and 100% FP trains dismissal of
    # the one hit that will matter. Two distinct causes, both mechanically reproduced:
    #   (a) `a || b || echo 0` was read as a pipeline — the old regex could anchor its `\|` on the
    #       SECOND bar of the first `||`. No pipe exists, so no second line can ever be produced.
    #       (Every `_mtime() { stat -c %Y … || stat -f %m … || echo 0; }` in the tree was flagged.)
    #   (b) a real pipeline whose failing stage emits NOTHING (`… | jq -r … || echo 0`) — the
    #       fallback then supplies the only line, which is exactly the intended behavior.
    # The disarm needs BOTH a real pipe AND a final stage that emits regardless of upstream failure
    # — a counter (`grep -c`, `wc`). That is the measured shape: `find … | grep -c . || echo 0`
    # yields "9\n0" and the `-gt` guard goes silent. Verified as a known pair (both directions) in
    # scripts/test_degrade_scan_shell_probes.sh; narrowing without that anchor would just trade a
    # noisy probe for a blind one.
    while IFS= read -r m; do
      emit "$f" "${m%%:*}" "S5:pipefail-fallback(sh)" "\`|| echo 0\` fallback on a pipeline ending in a counter (grep -c/wc) — that stage emits even when an upstream stage fails, so under \`set -o pipefail\` the value gains a SECOND line, the integer comparison errors out, and the guard passes silently; split the pipeline and sanitize to an integer"
    done < <(grep -nE '[^|]\|[[:space:]]*([a-z]+[[:space:]]+)*(grep[^|]*-c|wc)[^|]*\|\|[[:space:]]*echo[[:space:]]+[\"'"'"']?0' "$f" 2>/dev/null \
             | grep -vE '^[0-9]+:[[:space:]]*#' \
             | grep -vE '#[[:space:]]*noqa[:[:space:]]*degrade')
  fi

  # Probe A — except/else/finally block returning a permissive value within 2 lines.
  #   The classic "swallow the error → report success". A safe-fail returns BLOCK/None/raise.
  while IFS= read -r line; do
    ln="${line%%:*}"
    emit "$f" "$ln" "A:except/else→PASS" "permissive return on an error/fall-through branch — safe-fail must return BLOCK/None or re-raise"
  done < <(grep -nE -A2 '^[[:space:]]*(except([[:space:]][^:]*)?|else|finally)[[:space:]]*:' "$f" 2>/dev/null \
           | grep -E "return[[:space:]]+$PASS([[:space:],)]|$)" | grep -oE '^[0-9]+' | sort -u | sed 's/$/:/')

  # Probe B — dict default / setdefault to a permissive value (unknown key → PASS).
  while IFS= read -r m; do
    emit "$f" "${m%%:*}" "B:default→PASS" "unknown-key default is permissive — unenumerated case should default to safe-fail"
  done < <(grep -nE "(\.get\([^,]+,[[:space:]]*$PASS[[:space:])]|setdefault\([^,]+,[[:space:]]*$PASS[[:space:])])" "$f" 2>/dev/null)

  # Probe C — substring membership on a grounding/verdict/state line (loose match, not exact).
  #   `if tok in text` masks paid⊂prepaid / 완료⊂미완료. Exact/word-boundary is the safe form.
  while IFS= read -r m; do
    emit "$f" "${m%%:*}" "C:substring-grounding" "substring 'in' on a verdict/state/present line — use exact or word-boundary match, not containment"
  done < <(grep -nE '\b(verdict|present|ground|state|match|expected|assert)\w*\b' "$f" 2>/dev/null \
           | grep -vE ':[[:space:]]*(#|//|from |import )' | grep -vE '#[[:space:]]*noqa[:[:space:]]*degrade' \
           | grep -E '[^._a-zA-Z]in[[:space:]]' | grep -vE '\bfor\b|__contains__|not in|in \(|in \[|in \{|in range|in enumerate|in [A-Z_]+\b' \
           | grep -oE '^[0-9]+' | sed 's/$/:/')

  # Probe C2 — bare `VAR in VAR` in an if/return/assert/while context, WITHOUT a grounding keyword.
  #   Probe C is keyword-gated (low-noise) and therefore misses the doc's own headline example
  #   `tok in text` (paid⊂prepaid) when the variables aren't named verdict/state (M#4, steel-quench).
  #   C2 closes that: simple var-in-var (not a collection literal / range / for) = a likely
  #   containment check that should be exact/word-boundary if it grounds a verdict. Higher noise; advisory.
  while IFS= read -r m; do
    emit "$f" "${m%%:*}" "C2:substring-boolean" "bare 'X in Y' in if/return/assert — if this grounds a presence/verdict check, use exact/word-boundary match, not containment"
  done < <(grep -nE '^[[:space:]]*(if|elif|return|assert|while)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*[[:space:]]*[:)]?[[:space:]]*$' "$f" 2>/dev/null \
           | grep -vE '\bfor\b|in range|in enumerate|not in' \
           | grep -vE '\b(verdict|present|ground|state|match|expected)\w*\b')

  # Probe E — negated-falsy guard returning permissive (dominance-benchmark round-2 f2 class): an error
  # SENTINEL (None / {} / "" / []) is falsy, so `if not X: return <PASS>` treats "the check errored / never
  # ran" identically to "the check ran and found nothing clean". Distinguish errored from clean before allowing.
  while IFS= read -r ln; do
    emit "$f" "$ln" "E:falsy-sentinel→PASS" "negated-falsy guard returns permissive — a falsy error sentinel (None/{}/'') masquerades as 'clean'; a gate must distinguish 'errored/absent' from 'verified clean'"
  done < <(grep -nE -A2 '^[[:space:]]*if[[:space:]]+not[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*[[:space:]]*:' "$f" 2>/dev/null \
           | grep -E "return[[:space:]]+$PASS([[:space:],)]|$)" | grep -oE '^[0-9]+' | sort -u | sed 's/$/:/')

  # Probe F — positional field-select from a split result feeding a decision (round-2 c3 class): taking the
  # decision from `parts[-1]`/`parts[0]` of an attacker-influenceable split lets a crafted field (e.g. a
  # signed DENY whose free-form comment ends "::ALLOW") negate the verdict. Validate structure, don't select by position.
  if grep -qE '\.r?split\(' "$f" 2>/dev/null; then
    while IFS= read -r m; do
      emit "$f" "${m%%:*}" "F:split-positional-verdict" "decision taken by position ([-1]/[0]) from a split result — an attacker-controlled trailing/leading field can negate the verdict; validate structure, don't select by position"
    done < <(grep -nE '\[[[:space:]]*-?[01][[:space:]]*\]' "$f" 2>/dev/null \
             | grep -iE 'decision|verdict|allow|deny|approv|grant|status|result|policy')
  fi
done

echo "----"
[ ${#UNSCANNABLE[@]} -gt 0 ] && printf 'note: %s changed file(s) outside py/sh — NOT covered by this scan (send to cross-family directly).\n' "${#UNSCANNABLE[@]}"
if [ "$hits" -gt 0 ]; then
  echo "degrade-scan: $hits smell(s) — ADVISORY. Each = 'prove this is not default-toward-PASS'."
  echo "Terminal verdict = cross-family adversarial review (auto-decorrelation), not this scan."
  exit 2
fi
# Scope-honest clean message (M#2): "clean" means only "no py/sh-pattern smells in the SCANNED set" —
# it does NOT assert the changed load-bearing surface is safe (other languages, non-code surfaces,
# and the lint's own recall gaps are out of scope). The load-bearing check is the cross-family review.
echo "degrade-scan: no default-toward-PASS smells in ${#FILES[@]} scanned py/sh file(s) — does NOT cover other languages / non-code surfaces / the cross-family check (advisory)."
exit 0
