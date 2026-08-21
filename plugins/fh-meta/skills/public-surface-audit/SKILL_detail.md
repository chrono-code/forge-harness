---
name: public-surface-audit-detail
description: On-demand execution detail for public-surface-audit — scan scripts, report/JSON templates, provenance.
load: on-demand
---

## §Step3-Scan-Script

```bash
cd "$REPO_PATH" || exit 1
# Build the tracked-file list once.
git ls-files > /tmp/_psa_tracked.txt

# ── Single-source preference: when the shared library exists, use it and write NO second loop ──
# scripts/psa_scan_lib.sh owns loading + row validation + exemptions for the hook layer; a hand-rolled
# copy here is a second normalizer with its own leniency (the divergence class this rewrite removed).
if [ -r "scripts/psa_scan_lib.sh" ]; then
  . scripts/psa_scan_lib.sh
  psa_load ".claude/rules/.public-surface-patterns.defaults" \
           "${PSA_PATTERNS:-.claude/rules/.public-surface-patterns}"
  { [ "$PSA_DEFAULTS_OK" -eq 1 ] || [ "$PSA_OVERRIDE_PRESENT" -eq 1 ]; } \
    || { echo "⚪ NOT CONFIGURED: neither pattern layer present. Not scanning."; exit 2; }
  [ "$PSA_BAD_ROWS" -gt 0 ] \
    && { echo "HARNESS_ERROR: $PSA_BAD_ROWS unusable pattern row(s) — verdict cannot be CLEAN"; exit 10; }
  # Feed every tracked file as path<TAB>line, the stream psa_scan_tagged consumes. Sourcing the lib
  # without these calls is a no-op scan — measured on this repo (PSA_STREAM stayed unset), so the
  # calls are spelled out here rather than pointed at.
  # 🟥 rc 를 반드시 받아라 (2026-08-21 배선 리뷰 S-1). 이 파이프는 **원래 뚫렸던 바로 그 진입점**이고,
  #    바로 아래 coverage 조건이 `$?` 를 덮으므로 여기서 안 받으면 계약이 소실된다.
  #    계약: 0=신고할 것 없음 · 1=유출(이미 인쇄됨) · 3=NOT SCANNED(계기 사망)
  #    ⚠️ `_psa_rc=0` 은 반드시 `while` **밖**에 둔다 — 안에 두면 루프 본문이라 매 줄 초기화되고
  #       파이프 서브셸에 갇힌다(초판이 그렇게 넣었고 `bash -n` 은 통과했다. 문법은 맞고 의미가 틀린다).
  _psa_rc=0
  while IFS= read -r f; do
    awk -v p="$f" '{printf "%s\t%s\n", p, $0}' "$f" 2>/dev/null
  done < /tmp/_psa_tracked.txt | psa_scan_tagged || _psa_rc=$?
  # 🟥 3 은 «깨끗» 이 아니라 «안 쟀다» 다. 여기서 멈춰야 한다 — 이 스킬은 publish 직전에
  #    Pre-Publish Gate 가 1번으로 체이닝하는 렌즈이고, 그 자리에서 미측정을 통과시키면
  #    아래 coverage 줄이 «defaults-only 로는 스캔했다» 는 인상까지 얹는다.
  if [ "$_psa_rc" -eq 3 ]; then
    echo "⛔ INSTRUMENT DEAD: the scanner did not run (rc=3). NOT SCANNED is not clean."
    echo "   Fix first — run under bash (zsh special vars can blank PATH inside the matcher),"
    echo "   and confirm psa_load ran (PSA_STREAM non-empty). Do NOT report a verdict from this run."
    exit 3
  fi
  [ "$PSA_OVERRIDE_PRESENT" -eq 1 ] \
    || echo "coverage: defaults-only — operator literals NOT CONFIGURED (identity/company classes UNSCANNED)"
else
  # ── Standalone fallback (no hub scripts in this repo) — validated loop, malformed rows COUNTED ──
  PSA_DEFAULTS=".claude/rules/.public-surface-patterns.defaults"
  PATTERN_SRC="${PSA_PATTERNS:-.claude/rules/.public-surface-patterns}"
  SRC_LIST=""
  [ -e "$PSA_DEFAULTS" ] && SRC_LIST="$PSA_DEFAULTS"
  [ -e "$PATTERN_SRC" ]  && SRC_LIST="$SRC_LIST $PATTERN_SRC"
  [ -n "$SRC_LIST" ] || { echo "⚪ NOT CONFIGURED: no pattern source (neither defaults nor override). Not scanning."; exit 2; }

  MALFORMED=0
  cat $SRC_LIST > /tmp/_psa_rows.txt    # no pipe into the loop — a piped while runs in a subshell and loses MALFORMED
  # `|| [ -n "$severity" ]` keeps a final row that lacks a trailing newline — `read` alone drops it silently.
  while IFS=$'\t' read -r severity regex || [ -n "$severity" ]; do
    case "$severity" in ''|'#'*) continue ;; esac                     # blank / comment rows
    if [ -z "$regex" ]; then                                          # no tab separator → malformed, VISIBLE
      MALFORMED=$((MALFORMED+1)); echo "MALFORMED ROW (no <TAB>): $severity" >&2; continue
    fi
    printf 'x\n' | grep -qE "$regex" 2>/dev/null
    rc=$?                                                             # plain rc capture — `if !` would negate $?
    if [ "$rc" -ge 2 ]; then                                          # grep rc≥2 = invalid regex, not "no match"
      MALFORMED=$((MALFORMED+1)); echo "MALFORMED ROW (bad regex): $regex" >&2; continue
    fi
    grep -nIE "$regex" $(cat /tmp/_psa_tracked.txt) | sed "s/^/[$severity] /"
  done < /tmp/_psa_rows.txt
  # Malformed rows poison the verdict: part of the pattern file never scanned → CLEAN is unprovable.
  [ "$MALFORMED" -gt 0 ] && { echo "HARNESS_ERROR: $MALFORMED malformed pattern row(s) — verdict cannot be CLEAN"; exit 10; }
fi
```

**Why the fallback validates instead of skipping**: the previous loop dropped a malformed row with a
bare `continue` and discarded grep's stderr — a broken pattern file scanned "clean" by silently not
scanning. `not found ≠ 0`: a row that never ran is not a row with zero hits.

For each pattern, run `grep -nIE "<regex>" $(git ls-files)`:
- `-n` → line numbers (required for `file:line` output)
- `-I` → skip binary files
- `-E` → extended regex (alternation in the pattern table)

Then remove any hit whose `file` + matched `token` is on the Step 2 allowlist. Do this for **every**
pattern row before producing the report — do not stop at the first HIT.

**Binary / generated carve-out**: `-I` already skips binaries. Additionally note (do not auto-suppress)
hits inside generated artifacts (e.g. `paper/*.html` exported from a private source) — these are real
leaks on the public surface and must be reported, but the fix is "regenerate from a sanitized source",
not "edit the HTML by hand". Flag them with a `(generated artifact)` note.

---

## §Step3b-FP-Hygiene-Script

```bash
# FP-hygiene tests the MATCHED TOKEN only — never the whole line. A line-level `grep -v` would
# suppress a real leak that merely *mentions* an example (e.g. `user=<realname> # see EXAMPLE.md`),
# violating PSA's "allowlist tight" rule. So extract the matched span per hit and drop it only when
# the span is *entirely* a placeholder/example (anchored ^…$).
PLACEHOLDER='^(<[a-z0-9_-]+>|\{project\}|EXAMPLE|dummy|changeme|REDACTED|xxxx)$'
grep -nIE "$regex" $(cat /tmp/_psa_tracked.txt) 2>/dev/null | while IFS= read -r hit; do
  tok=$(printf '%s' "$hit" | grep -oiE "$regex" | head -1)
  printf '%s' "$tok" | grep -qiE "$PLACEHOLDER" && continue   # token IS a placeholder → drop
  printf '%s\n' "$hit"
done
```

This differs from the Step 2 allowlist: Step 2 suppresses by **file::token legitimacy**, Step 3b by
**token value-shape**. Both run — Step 2 then Step 3b. Keep it tight (PSA's "allowlist tight" rule): if a
token only *contains* an example substring but is otherwise a real private value, it still reports.

---

## §Step3c-Ignore-Verification-Script

```bash
# Expected-private set = conventional FH local-only files, EXTENDED with any `# private-path: <path>`
# lines the operator added to the gitignored pattern source (self-extends per repo — not a frozen
# operator snapshot). Built one-path-per-line + while-read so it is portable across bash AND zsh
# (zsh does not word-split an unquoted variable, so `for f in $VAR` would break). A non-existent file
# is skipped; an all-absent set emits n/a, never a silent pass.
present=$({ printf '%s\n' CLAUDE.local.md .claude/rules/.public-surface-patterns \
             .claude/rules/local_fh_context.md tracks/_meta/user_adaptation_profile.md
           grep -E '^# private-path:' .claude/rules/.public-surface-patterns 2>/dev/null \
             | sed -E 's/^# private-path:[[:space:]]*//'; } \
         | awk 'NF' | sort -u | while IFS= read -r f; do [ -e "$f" ] && printf '%s\n' "$f"; done)
[ -z "$present" ] && echo "n/a (no expected-private files present in this repo — add '# private-path:' lines to the pattern source if any exist)"
printf '%s\n' "$present" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  # Tracked status is tested FIRST: a file can match an ignore rule yet still be force-added
  # (`git add -f`) — the exact ignored-but-committed mechanism behind the PR #109 leak. Tracked wins,
  # so an ignored-but-committed file reports TRACKED (not a false-clean OK).
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    echo "TRACKED $f (already committed — Step 3 scans its contents; un-track if it must be private: git rm --cached)"
  elif rule=$(git check-ignore -v "$f" 2>/dev/null); then
    echo "OK      $f → ignored by [$rule]"
  else
    echo "MISS    $f (exists, NOT ignored, NOT tracked — one 'git add .' from a leak; add an ignore rule)"
  fi
done
```

Why this is the safeguard for **gitignore mistakes** (a wrong assumption about what is ignored):
`.gitignore` is committed/shared, `.git/info/exclude` is local/personal, and a global `core.excludesFile`
ignores across all repos — `git check-ignore -v` is the one command that says *which* rule (if any)
applies, so an "I thought it was ignored" error surfaces here instead of in a public PR (the PR #109
class of leak). Diagnostic-only: this step never writes — it reports, the operator adds the ignore rule.

---

## §Report-Template

```
public-surface-audit — Operator-Private Token Scan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Target: {REPO_PATH}   |   Tracked files scanned: {N}

  🔴 HIGH  ({count})
    {file}:{line}  →  {matched token}   [class: username | company asset]
  🟠 MED   ({count})
    {file}:{line}  →  {matched token}   [class: absolute home path | ignore-MISS (Step 3c)]
  🟡 LOW   ({count})
    {file}:{line}  →  {matched token}   [class: companion-store | private wiring]

  Allowlist-suppressed: {count} hit(s) (legitimate references — not leaks)

  Verdict:
    ⚪ NOT CONFIGURED — pattern source absent (nothing scanned — NOT a clean result; set up first)
    🟢 CLEAN        — pattern source present (incl. empty), 0 HIGH + 0 MED + 0 LOW (after allowlist)
    🟡 REVIEW       — 0 HIGH + 0 MED, LOW-only (drift, not a breach)
    🔴 LEAK         — 1+ HIGH or 1+ MED (block publish / fix before commit)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## §JSON-Schema

```json
{
  "target": "{REPO_PATH}",
  "tracked_files": 0,
  "findings": [
    {"file": "path", "line": 42, "token": "<matched>", "severity": "HIGH", "class": "username"}
  ],
  "counts": {"HIGH": 0, "MED": 0, "LOW": 0, "suppressed": 0},
  "verdict": "CLEAN"
}
```

---

## §Sister-Asset-Provenance

Step 3b (FP hygiene) and Step 5 (`--json`) were imported from **garrytan/gstack** `gstack-redact`
(`lib/redact-engine.ts`) during a hands-on sister-asset cross-audit (2026-06-06; see
`tracks/_audit/session_2026_06_06_gstack_sister_handson.md`). They are adapted to PSA's operator-IP
ontology — `gstack-redact`'s generic secret/PII classes (AWS / PEM / JWT / hostname) stay out of PSA's
scope (orthogonal coverage: PSA = operator-IP leak, redact = generic secret). The reverse direction
(PSA's operator private-codename + bare-username classes, which `gstack-redact` structurally cannot
detect) is a candidate contribution back to gstack.
