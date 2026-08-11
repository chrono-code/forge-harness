---
name: marketplace-gate
description: Evaluates whether a repository meets marketplace listing criteria via a 5-point check and outputs a listing suitability verdict. Checks README completeness, zero-config readiness, maintenance signals, duplication, and public safety.
user-invocable: true
allowed-tools: ["Read", "Bash", "Grep", "Glob"]
model: sonnet
category: Composability Gate
---

# marketplace-gate — Marketplace Listing Suitability Gate

Evaluates a repository against 5 listing criteria — README completeness, zero-config readiness, maintenance signals, duplication, and public safety — and outputs a listing suitability verdict.

> While `asset-placement-gate` answers "is this asset suitable for FH?",
> `marketplace-gate` answers "is this repo ready to be listed in a marketplace?"

## Triggers

- `/marketplace-gate`
- `/marketplace-gate --target <repo path>`
- "Can I list this in the marketplace?", "Pre-listing repo check", "Verify before publishing", "Is this ready for marketplace listing?"
- "Can other teams use this repo?", "Is there a checklist before external distribution?", "Check if this is ready to be public"
- "Review for open-source release", "Verify before sharing outside the team"

---

## Step 0. Confirm Target Path

Use the path specified by `--target <path>` if provided. Otherwise use current cwd.

```bash
REPO_PATH="${ARGUMENTS#--target }"
REPO_PATH="${REPO_PATH:-$(pwd)}"
echo "Target: $REPO_PATH"
ls "$REPO_PATH" 2>/dev/null | head -20 || echo "Path not found — please verify the path"
```

Stop immediately if path is not found.

---

## Step 1. 5-Point Check

### Check 1 — README Completeness

```bash
README=$(ls "$REPO_PATH"/README* 2>/dev/null | head -1)
[ -z "$README" ] && echo "FAIL: No README found" && exit
# Installation command exists
grep -i "install\|clone\|setup" "$README" | head -3
# Code block (usage example) exists
grep -c '```' "$README" 2>/dev/null
```

| Criterion | Check |
|---|---|
| README file exists | ls |
| Purpose in 1 sentence (first 50 lines) | presence check |
| Installation path documented | install·clone·setup keywords |
| At least 1 usage example | code block presence |
| Version notation | version·v[0-9] pattern |

Result: **PASS** (5/5) / **PARTIAL** (3-4/5) / **FAIL** (≤2/5)

### Check 2 — Immediate Usability (zero-config)

```bash
# plugin manifest exists
ls "$REPO_PATH"/.claude-plugin/plugin.json "$REPO_PATH"/package.json 2>/dev/null
# single-line install command (from README)
grep -i "claude plugin install\|npm install\|pip install\|brew install" "$README" 2>/dev/null | head -3
# prerequisites documented
grep -i "prerequisite\|requirement\|env\|api.key" "$README" -A 2 | head -6
```

| Criterion | Check |
|---|---|
| Single-line install command in README | grep |
| Prerequisites documented (API key, env var, etc.) | grep |
| Plugin manifest exists | ls |

Result: **PASS** / **PARTIAL** / **FAIL**

### Check 3 — Maintenance Signals

```bash
cd "$REPO_PATH" 2>/dev/null || { echo "ABORT: cannot cd to $REPO_PATH — refusing to measure the current repo in its place"; exit 1; }
git log -1 --format="Last commit: %ar (%ad)" --date=short 2>/dev/null
ls CHANGELOG* 2>/dev/null && echo "CHANGELOG found" || echo "No CHANGELOG"
git tag -l 2>/dev/null | tail -5
```

| Criterion | Check |
|---|---|
| Last commit within 60 days | git log |
| CHANGELOG or version bump history | ls |
| git tags exist (version management) | git tag |

Result: **ACTIVE** / **STALE** (60–180 days) / **ABANDONED** (180+ days)

### Check 4 — Duplication / Conflict Detection

```bash
# list skills in target repo (directory-based — skills are directory-registered in this ecosystem;
# plugin.json carries no skills array, so a manifest read is NOT a skill list. An earlier version
# of this check read `plugin.json["skills"]`, a key that never exists, so it rendered every healthy
# repo as STALE — a broken instrument, calibrated against this very repo.)
find "$REPO_PATH" -name "SKILL.md" 2>/dev/null | xargs -I{} dirname {} | xargs -I{} basename {} | sort > /tmp/_mkt_target_skills.txt
cat /tmp/_mkt_target_skills.txt
# compare with hub skills — SKIPPED must be visible, never silent. The readability test matters:
# FH_DIR set-but-wrong yields an empty ls through the pipe, which reads as "0 overlaps" — a silent
# skip wearing a pass. Set-but-unreadable is its own labeled state.
if [ -n "$FH_DIR" ] && [ -d "$FH_DIR/plugins" ]; then
  ls "$FH_DIR"/plugins/*/skills/ 2>/dev/null | grep -v ':$' | grep -v '^$' | sort > /tmp/_mkt_hub_skills.txt
  comm -12 /tmp/_mkt_target_skills.txt /tmp/_mkt_hub_skills.txt | sed 's/^/NAME-OVERLAP: /'
elif [ -n "$FH_DIR" ]; then
  echo "SKIPPED: FH_DIR set but $FH_DIR/plugins unreadable — hub cross-check NOT run (not a CLEAN signal)"
else
  echo "SKIPPED: FH_DIR unset — hub cross-check NOT run (this is not a CLEAN signal)"
fi
```

**Duplication verdict**: name overlap with hub skills → **OVERLAP**/**CONFLICT** by role comparison.
Hub cross-check skipped → report `CLEAN (target-internal only — hub cross-check SKIPPED)`, never bare CLEAN.

| Criterion | Check |
|---|---|
| No name conflict with existing FH skills | name comparison (or visible SKIPPED) |
| No functional duplication | description keyword comparison |

Result: **CLEAN** / **OVERLAP** (N candidates) / **CONFLICT** (direct conflict)

### Check 5 — Public Safety

**Primary path (no-reinvention)**: when `public-surface-audit` is installed, run it against
`$REPO_PATH` and map its verdict — `LEAK` → **BLOCKED** · `REVIEW` → **WARNING** · `CLEAN` → **SAFE**
· `NOT_CONFIGURED` → **WARNING(NOT_CONFIGURED)** (pattern source absent — not a clean bill). That
skill is the real token scanner; this check does not re-implement it. The `NOT_CONFIGURED` qualifier
survives into the Step 2 aggregate — see the 🟢 rule there (an unmeasured public surface must not be
absorbed into an ignorable ⚠️).

**Fallback (screening-grade only)** — when public-surface-audit is not installed:

```bash
# placeholder-literal screening — catches template residue, NOT real internal hostnames or secrets
grep -r "<your-ghe-url>\|internal-domain\|internal-api" \
  "$REPO_PATH" --include="*.md" --include="*.json" --include="*.yaml" -l 2>/dev/null | head -10
# sensitive information exposure (assignment shapes only)
grep -rE "API_KEY\s*=|SECRET\s*=|PASSWORD\s*=" \
  "$REPO_PATH" --include="*.md" --include="*.json" --include="*.yaml" --include="*.yml" \
  --include="*.sh" --include="*.env*" -l 2>/dev/null | head -5
# license
ls "$REPO_PATH"/LICENSE* 2>/dev/null && echo "LICENSE found" || echo "No LICENSE"
```

Fallback results are always labeled `(screening-grade — placeholder patterns; not a hostname/secret
scanner)`. A go-public action still owes the Pre-Publish Surface Gate's full chain regardless of a
SAFE here — this check screens listing readiness, it does not clear publication.

| Criterion | Check |
|---|---|
| No hardcoded internal domains (or clearly marked as internal-only) | public-surface-audit (or screening-grade grep, labeled) |
| No sensitive information exposed | public-surface-audit (or screening-grade grep, labeled) |
| LICENSE file exists | ls |

Result: **SAFE** / **WARNING** (N items to review) / **BLOCKED** (sensitive info exposed)

---

## Step 2. Verdict Output

```
marketplace-gate — Listing Suitability Verdict
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Target: {REPO_PATH}

  Check 1 README completeness  : ✅ PASS / ⚠️ PARTIAL / ❌ FAIL
  Check 2 zero-config          : ✅ PASS / ⚠️ PARTIAL / ❌ FAIL
  Check 3 Maintenance signals  : ✅ ACTIVE / ⚠️ STALE / ❌ ABANDONED
  Check 4 Duplication detection: ✅ CLEAN / ⚠️ OVERLAP({N}) / ❌ CONFLICT
  Check 5 Public safety        : ✅ SAFE / ⚠️ WARNING({N}) / ❌ BLOCKED

  Overall verdict — counted over the ❌-class {FAIL, ABANDONED, CONFLICT, BLOCKED}
  (each check has its own vocabulary; the aggregate counts the ❌ column, not the token "FAIL" —
   an ABANDONED or CONFLICT is a failure even though its word differs):
    🟢 Recommended for listing  — 0 ❌-class results, AND Check 5 does not carry the
                                  NOT_CONFIGURED qualifier (an unmeasured surface caps
                                  the verdict at 🟡 — unmeasured ≠ pass)
    🟡 Conditional listing      — exactly 1 ❌-class result, and it is not BLOCKED
    🔴 Listing on hold          — 2+ ❌-class results, or any BLOCKED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Follow-up Connections

| Situation | Next skill |
|---|---|
| Check 1 FAIL — README needs improvement | `hub-persona-auditor` — external reader perspective audit |
| Check 4 OVERLAP — confirm duplication | `cross-ecosystem-synergy-detection` — explore synergy potential |
| Check 5 WARNING — internal assets need cleanup | `harness-doctor` — internal structure consistency diagnosis |
| After 🟢 verdict — install test | `install-doctor` — pre-install conflict verification |

## Done When

```
All steps 0–2 completed                                        — mandatory-pass
+ Full 5-point check results output (Check 1–5 individual
  verdicts, skipped legs rendered as visible SKIPPED)          — mandatory-pass
+ Overall verdict output (🟢/🟡/🔴) counted over the ❌-class    — measured (❌-class count)
+ Before any 🟢 Recommended verdict: phantom-quench ran over
  the target's citations/URLs/path refs; phantom refs found
  → verdict auto-downgrades to 🟡 Conditional                   — mandatory-pass
```

(The phantom-quench leg sits inside Done When on purpose — an earlier version stated it below the
fence, so the fence alone could be satisfied without it.)

> When `agent-composer` receives a "comprehensive marketplace listing audit" request,
> recommend: Wave 0 `fact-checker` → Wave 1 `marketplace-gate` + `hub-persona-auditor` in parallel.
