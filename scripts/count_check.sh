#!/usr/bin/env bash
# count_check.sh — skill/agent count-consistency check (single source).
# Class: mandatory-pass (harness_6axis_framework.md §Axis 5) — exit 1 on drift.
#
# Called by ALL THREE count-consistency boundaries so one logic runs everywhere:
#   - scripts/selfcheck.sh            → publish-readiness (prepublishOnly + npm test)
#   - templates/.git-hooks/pre-commit → local commit time, `--staged` (index mode)
#   - .github/workflows/validate.yml  → PR/merge boundary (checked-out tree == committed)
#
# Origin (fh_signal_2026-06-21): the count check used to live ONLY at the publish boundary.
# But the actor that breaks it — a commit/merge that adds/removes a skill dir — acts at
# commit/merge time, so a skill-adding PR (#111) merged with stale counts and they sat
# undetected on main until the next publish. This is the gate-locality gap (a gate must
# live where the breaking action happens). One source, three boundaries, no reinvention.
#
# Modes:
#   (default)  count the WORKING TREE — selfcheck (publish; tree == HEAD) and CI
#              (a checked-out PR IS the committed state). cat/glob the on-disk files.
#   --staged   count the INDEX (exactly what THIS commit will contain) — the pre-commit
#              hook. Fixes steel-quench S1 (2026-06-21): a worktree-only count can
#              FALSE-PASS a commit that stages a skill add but leaves the count-file
#              updates unstaged — the gate would verify a different tree than it commits.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || { echo "COUNT-CHECK: FAIL (cannot cd to repo root)"; exit 1; }

MODE="worktree"
[ "${1:-}" = "--staged" ] && MODE="staged"
fail=0

# Read a tracked file's content from the active tree (index in --staged, disk otherwise).
read_tree() { # read_tree <path>
  if [ "$MODE" = staged ]; then git show ":$1" 2>/dev/null; else cat "$1" 2>/dev/null; fi
}
# List a plugin's top-level SKILL.md paths in the active tree.
list_skills() { # list_skills <plugin>
  if [ "$MODE" = staged ]; then
    git ls-files --cached -- "plugins/$1/skills" 2>/dev/null \
      | grep -E "^plugins/$1/skills/[^/]+/SKILL\.md$"
  else
    local s
    for s in plugins/"$1"/skills/*/SKILL.md; do [ -f "$s" ] && echo "$s"; done
  fi
}
# Count a plugin's top-level agent .md files in the active tree.
count_agents() { # count_agents <plugin>
  if [ "$MODE" = staged ]; then
    git ls-files --cached -- "plugins/$1/agents" 2>/dev/null \
      | grep -cE "^plugins/$1/agents/[^/]+\.md$"
  else
    ls plugins/"$1"/agents/*.md 2>/dev/null | wc -l | tr -d ' '
  fi
}
# Active skill = SKILL.md whose head (first 20 lines) carries no deprecation marker
# (a whole-file grep false-positives on skills that merely mention the word).
count_active() { # count_active <plugin>
  local n=0 s
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    read_tree "$s" | head -20 | grep -qE 'deprecated: true|DEPRECATED' || n=$((n+1))
  done < <(list_skills "$1")
  echo "$n"
}

meta_sk=$(count_active fh-meta); meta_ag=$(count_agents fh-meta)
com_sk=$(count_active fh-commons); com_ag=$(count_agents fh-commons)
total_sk=$((meta_sk + com_sk)); total_ag=$((meta_ag + com_ag))

# Impossible-zero guard (steel-quench A4 — fail CLOSED): fh-meta always has active skills.
# A 0 means the tree/glob resolved to nothing (wrong cwd, empty index, sh-as-bash shim) —
# a gate must never return "consistent" from an empty tree.
if [ "$meta_sk" -eq 0 ]; then
  echo "COUNT-CHECK: FAIL (0 active fh-meta skills — empty/wrong tree, mode=$MODE)"
  exit 1
fi

count_check() { # count_check <label> <file> <expected-string>
  # Containment, not equality, was the bug: every expected string starts with a digit, so a
  # stale "16 skills + 2 agents" CONTAINS "6 skills + 2 agents" and a plain `grep -q` reported
  # PASS while the count had actually drifted. Guard the boundaries so a longer number cannot
  # satisfy a shorter one, and escape the expected text (it carries `+` and `(` `)`, which are
  # ERE metacharacters) so it is matched as the literal it is meant to be.
  local esc
  esc=$(printf '%s' "$3" | sed 's/[][\.*^$+?(){}|\\/]/\\&/g')
  if read_tree "$2" | grep -qE "(^|[^0-9])${esc}([^0-9]|\$)"; then
    echo "PASS  count: $1"
  else
    echo "FAIL  count: $1 — expected \"$3\" in $2 (actual: fh-meta ${meta_sk}sk/${meta_ag}ag, fh-commons ${com_sk}sk/${com_ag}ag)"
    fail=1
  fi
}
count_check "fh-meta plugin.json"      plugins/fh-meta/.claude-plugin/plugin.json    "${meta_sk} skills + ${meta_ag} agents"
count_check "fh-commons plugin.json"   plugins/fh-commons/.claude-plugin/plugin.json "${com_sk} skills"
count_check "marketplace.json fh-meta" .claude-plugin/marketplace.json               "${meta_sk} skills + ${meta_ag} agents"
# ── README 렌더링만 per-repo override 를 받는다 ──────────────────────────────────────────────
# 왜 이 한 줄만 다른가: plugin.json·marketplace.json 의 문자열은 **기계 결합**(영문 고정,
# 소비처가 파싱한다)이지만 README 헤더는 **사람이 읽는 산문**이라 하류 하네스가 자기 언어로 쓴다.
# 이 스크립트는 공유층이라 여기에 렌더링을 하드코딩하면 다음 sync 가 하류의 지역화를 덮고,
# 그 레인은 **이식 이후 한 번도 통과 못 하는 검사**가 된다 — 통과 불가능한 게이트는 게이트가
# 아니라 `--no-verify` 훈련기다(실측: pmh-dev #55 가 그 상태를 손으로 되돌려야 했고, 다음
# sync 에 다시 깨질 예정이었다. 이슈 chronoloy-dev/pmh-dev#57).
#
# 규약: 소비 레포는 `.claude/rules/count_readme_format` 에 printf 템플릿 한 줄을 둔다
#       (`%s` 두 개 = skills 수, agents 수). 그 파일을 **자기 sync 제외목록에 등재**해야 한다 —
#       등재 안 하면 이 override 자체가 덮이므로, 그 등재가 이 규약의 전제다.
# 부재 → 영문 기본값. 즉 FH 자신과 지역화 안 한 설치는 종전과 동일하다(fail-closed 아님:
#       README 렌더링은 가역 표면이고, 없는 파일을 요구하면 새 설치가 전부 막힌다).
README_FMT_FILE="${COUNT_README_FORMAT_FILE:-.claude/rules/count_readme_format}"
if [ -r "$README_FMT_FILE" ]; then
  README_FMT=$(head -1 "$README_FMT_FILE")
  case "$README_FMT" in
    *%s*%s*) : ;;   # %s 두 개 필수 — 하나뿐이면 두 번째 수치가 검사에서 빠진다(무음 축소)
    *) echo "FAIL  count: README format override 가 %s 를 두 개 갖지 않는다: '$README_FMT' ($README_FMT_FILE)"; fail=1; README_FMT="" ;;
  esac
else
  README_FMT='%s skills · %s agents'
fi
# shellcheck disable=SC2059  # 템플릿은 선언 파일에서 온다 — 그게 이 기능의 요점
[ -n "$README_FMT" ] && count_check "README header" README.md "$(printf "$README_FMT" "$total_sk" "$total_ag")"
count_check "local_fh_context fh-meta" templates/local_fh_context.md                 "(fh-meta, ${meta_sk})"

if [ "$fail" -ne 0 ]; then
  echo "COUNT-CHECK: FAIL"
  exit 1
fi
echo "COUNT-CHECK: PASS (mode=$MODE)"
exit 0
