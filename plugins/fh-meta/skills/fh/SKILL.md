---
name: fh
description: Renders the FH hub map on demand — the door menu, a starter set of skills, and the most-used trigger phrases — without requiring a greeting. State-aware; composes live candidates from the session card and tracks.
user-invocable: true
allowed-tools: ["Read", "Grep", "Glob"]
# /fh is read-only by construction: it detects state and renders a map. It was the only one of
# the 40 SKILL.md files with no allowed-tools declaration at all. Read/Grep/Glob is the full set
# its body needs — no Bash, Write, Edit, or Agent appears anywhere in it.
---

# /fh — hub map on demand

The greeting flow (CLAUDE.md §Active Onboarding) fires on greetings, start intents, new-task and
discovery utterances — but it is salience-dependent, once-per-session, and skipped entirely when the
user opens with a task. This command is the **explicit, deterministic** route to the same map: slash
autocomplete discoverability, invocable mid-session any number of times, no reliance on the model
catching a phrase. Same map, different guarantee — /fh does not claim a gap in *which utterances*
fire onboarding; it closes the *how-reliably-and-when* gap.

## Execution Steps

### Step 1. State detection (reuse, don't re-derive)

Run the same mechanical branch test as §Active Onboarding: session files / mapped project tracks
under `tracks/` (underscore dirs don't count) → new / returning; FH-dev state (session card ·
open `fh_signal_*` · `CLAUDE.local.md`) → operator. Do not invent a separate test — the canonical
branch rules live in CLAUDE.md §Active Onboarding and `fh_detail_protocols.md` Step 2.

### Step 2. Render the door menu

Output the door skeleton for the detected branch **verbatim from the canonical source** (CLAUDE.md
§Active Onboarding — including the 🐿️ same-line welcome). Compose door ③ / 🔧 candidates live from
the session card and CATALOG, exactly as the greeting path would.

### Step 3. Render the quick map (below the menu)

- **Starter set**: the curated first-five from `templates/starter_profile.md` (read it — do not
  hardcode a list that can go stale), one line each.
- **Most-used phrases**: 5-8 rows from CHEATSHEET §4 (universal phrases + the full-autonomy
  contract line).
- If cwd is a mapped field project: one line noting "진단해줘" routes to the Field-Harness
  Diagnostic here.

### Step 4. Hand off

End with "pick a door, say a phrase, or just state your task". Do not auto-run anything — this
command is a map, not a dispatcher.


## Step 3.5 — 가이드 · Q&A (📖 문을 골랐을 때만 진입)

🟥 **Q&A 는 net-new 기능이 아니다.** FH 에 대해 묻고 답하는 것은 이미 된다(CLAUDE.md 가 상주라
세션이 문·게이트·스킬을 안다). 이 절이 더하는 것은 **하나뿐**이다 — 「무엇을 근거로 답하나,
그리고 없으면 없다고 말한다」는 **계약**. 그래서 새 스킬을 만들지 않고 여기 붙인다.

**ⓐ 가이드** — `docs/USER_GUIDE.md` 의 **경로와 3줄 목차**를 출력한다. 승인하면 플랫폼 opener 를
제안한다(`uname -s`: Darwin→`open` · Linux→`xdg-open` · MINGW/MSYS→`start`). opener 가 없으면
조용히 건너뛴다 — 경로는 이미 나갔으므로 손실이 없다.
🟥 **전문 인라인 출력 금지.** 자동 실행도 안 한다.

**ⓑ Q&A** — 1문 1답. 근거는 아래 코퍼스 **안에서만** 찾는다:

```
1 docs/USER_GUIDE.md              사용법 · FAQ
2 CHEATSHEET.md                   명령 · 트리거 문구
3 knowledge/shared/GLOSSARY.md    용어
4 README.md §Get started/§Learn more   설치 · 진입 경로
5 CATALOG.md                      「예전에 뭐 했지」
6 설치된 SKILL.md frontmatter     「무슨 스킬 있어」
```

**degrade — 코퍼스에 없으면**
🟥 **지어내지 않는다.** 「못 찾음 — 코퍼스 N개를 봤고 여기엔 없다」 + **다음 한 걸음**(어느 파일을
열지 · `/install-doctor` 같은 실제 진단 경로)을 준다. 「아마 이럴 것이다」 형태의 답은 **금지**다.
이건 §Instrument Calibration 의 «미측정을 0으로 렌더하지 않는다» 와 같은 규율이다.
답마다 `file:line` 을 단다 — 근거 없는 문장은 팬텀이다.

⚠️ 코퍼스 밖 질문(도메인 작업 · 코드)은 이 절이 아니라 평소대로 처리한다. Q&A 는 **FH 사용법**용이다.

## Done When

| Condition | Check class |
|---|---|
| Door menu rendered for the correct state branch (new/returning/operator) | mandatory-pass (output exists; branch test is the mechanical §Active Onboarding rule) |
| Menu text matches the canonical skeleton (no drifted fork of the door labels) | measured — at render time, diff the rendered labels against CLAUDE.md §Active Onboarding (the render-vs-source diff IS the check; the canonical-side 4-axis guard only protects the source, not this skill's rendering) |
| Starter set and phrases sourced from their canonical files, not hardcoded | judged — paired with `/phantom-quench` back-trace (each rendered item must exist in its source file) |

## Trigger Phrases

- `/fh` (primary — explicit slash command)
- "show me the menu" · "메뉴 보여줘"
- "what can this hub do" · "여기서 뭘 할 수 있어"
- "지도 보여줘" · "skill map"

Natural-language triggers deliberately overlap the §Active Onboarding discovery triggers — both
routes render the same map from the same canonical source, so whichever route catches first, the
outcome is identical (collision-safe by construction, not by luck). Baseline Step 0.5 trigger-probe:
due at the next harness-doctor run (this skill is a routing surface — obligation per CLAUDE.md
§New Skill Creation Pre-Commit Gate).

## Constraints

- Never duplicates the menu skeleton into this file — CLAUDE.md is the single source; this skill
  only *renders* it. (The 2026-07-17 audit found label-drift risk across duplicated menu copies;
  this skill must not add a third copy.)
- Read-only: no state writes, no dispatch.
