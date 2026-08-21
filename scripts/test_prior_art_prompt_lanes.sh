#!/usr/bin/env bash
# test_prior_art_prompt_lanes.sh — T2 훅의 known-pair 앵커.
# 🟥 이 훅의 사활은 «막나» 가 아니라 **«소음이 아닌가»** 다. 냉독자가 지목한 자기무력화 경로:
# 트리거가 부정확하면 하루 수십 번 뜨고, 3회 거절 억제가 오전 중에 켜져서 기능이 조용히 죽는다.
# 그래서 음성 레인이 양성보다 많다.
set -uo pipefail
FH="$(cd "$(dirname "$0")/.." && pwd)"
H="$FH/scripts/prior_art_prompt.sh"
PASS=0; FAIL=0
T="$(mktemp -d -t pap.XXXXXX)" || exit 3
trap 'rm -rf "$T"' EXIT INT TERM
chk(){ if [ "$2" = "$3" ]; then echo "  ✅ $1"; PASS=$((PASS+1)); else echo "  ❌ $1 (got=$2 want=$3)"; FAIL=$((FAIL+1)); fi; }
# 각 호출은 세션-스탬프를 격리해야 «한 번만» 규칙에 서로 안 걸린다
fires(){ local d; d="$(mktemp -d -t papd.XXXXXX)"; mkdir -p "$d/.claude"
  local o; o=$(printf '{"tool_input":{"file_path":"%s"}}' "$1" | CLAUDE_PROJECT_DIR="$d" bash "$H" 2>/dev/null)
  rm -rf "$d"; [ -n "$o" ] && echo yes || echo no; }

echo "── 양성: 새 «메커니즘» 을 쓰기 직전 ──"
chk "P1 새 .sh"            "$(fires "$T/new_gate.sh")" yes
chk "P2 새 SKILL.md"       "$(fires "$T/plugins/x/skills/y/SKILL.md")" yes
chk "P3 새 agents/*.md"    "$(fires "$T/plugins/x/agents/z.md")" yes
chk "P4 새 .py"            "$(fires "$T/tool.py")" yes

echo "── 음성: 소음이 되면 이 능력이 죽는다 ──"
printf 'x\n' > "$T/exists.sh"
chk "N1 🟥 «이미 있는 파일 편집» 은 새로 짓기가 아니다" "$(fires "$T/exists.sh")" no
chk "N2 기록/산출물(.md 일반)"      "$(fires "$T/notes.md")" no
chk "N3 tracks/ 아래 기록"          "$(fires "$T/tracks/_meta/x.sh")" no
chk "N4 로그"                       "$(fires "$T/logs/a.sh")" no
chk "N5 json/lock"                  "$(fires "$T/a.json")" no

echo "── 🟥 스코프가 «세션» 이지 «날짜» 가 아니다 (초판 결함의 앵커) ──"
# 초판은 스탬프를 날짜로 잡아, 하루에 세션을 여럿 도는 환경에서 **첫 세션만 뜨고 나머지는 전부
# 침묵**했다. 주석은 «세션당» 이었고 구현은 «하루당» 이었다 — 그 둘이 갈리는 것이 이 레인이다.
S="$(mktemp -d -t papsid.XXXXXX)"; mkdir -p "$S/.claude"
sid_fire(){ local o; o=$(printf '{"session_id":"%s","tool_input":{"file_path":"%s/%s.sh"}}' "$1" "$T" "$2" \
  | CLAUDE_PROJECT_DIR="$S" bash "$H" 2>/dev/null); [ -n "$o" ] && echo yes || echo no; }
chk "S1 세션 A 1회차 → 뜬다"        "$(sid_fire sess-A f1)" yes
chk "S2 세션 A 2회차 → 무음"        "$(sid_fire sess-A f2)" no
chk "S3 🟥 세션 B 1회차 → 뜬다 (같은 날 다른 세션)" "$(sid_fire sess-B f3)" yes
chk "S4 CONTROL — session_id 없으면 날짜로 degrade(무음 아님)" \
    "$(printf '{"tool_input":{"file_path":"%s/f4.sh"}}' "$T" | CLAUDE_PROJECT_DIR="$(mktemp -d -t papnos.XXXXXX)" bash "$H" 2>/dev/null | grep -c additionalContext)" 1
rm -rf "$S"

echo "── 세션당 한 번 (3회 거절 억제로 조용히 죽는 경로 차단) ──"
D="$(mktemp -d -t paponce.XXXXXX)"; mkdir -p "$D/.claude"
o1=$(printf '{"tool_input":{"file_path":"%s/a.sh"}}' "$T" | CLAUDE_PROJECT_DIR="$D" bash "$H" 2>/dev/null)
o2=$(printf '{"tool_input":{"file_path":"%s/b.sh"}}' "$T" | CLAUDE_PROJECT_DIR="$D" bash "$H" 2>/dev/null)
chk "O1 첫 번째는 뜬다"   "$([ -n "$o1" ] && echo yes || echo no)" yes
chk "O2 두 번째는 안 뜬다" "$([ -n "$o2" ] && echo yes || echo no)" no
rm -rf "$D"

echo "── 🟥 절대 안 막는다 (가역 표면) ──"
D2="$(mktemp -d -t papnb.XXXXXX)"; mkdir -p "$D2/.claude"
out=$(printf '{"tool_input":{"file_path":"%s/c.sh"}}' "$T" | CLAUDE_PROJECT_DIR="$D2" bash "$H" 2>/dev/null); rc=$?
chk "B1 exit 0" "$rc" 0
chk "B2 permissionDecision 을 안 낸다 (자동승인 역전 금지)" \
    "$(printf '%s' "$out" | grep -c permissionDecision)" 0
chk "B3 모델 채널(additionalContext)로 간다" \
    "$(printf '%s' "$out" | grep -c additionalContext)" 1
rm -rf "$D2"

echo "── D: Bash 경로 — 🟥 첫 실사용이 «비발화» 로 났던 자리 (2026-08-21) ──"
# matcher 가 `Write` 뿐이었는데 auto-mode 는 파일을 **Bash 리다이렉트/heredoc** 으로 만든다.
# 즉 이 훅이 겨냥한 순간이 구조적으로 Write 를 안 탔다. 아래가 그 재현이다.
D3=$(mktemp -d); export CLAUDE_PROJECT_DIR="$D3"; mkdir -p "$D3/.claude"
chk "D1 Bash heredoc 로 새 .sh → 발화" \
    "$(printf '%s' '{"session_id":"d1","tool_input":{"command":"cat > scripts/new_thing.sh <<EOF\necho hi\nEOF"}}' | bash "$H" 2>/dev/null | grep -c additionalContext)" 1
rm -f "$D3/.claude/.prior_art_prompted_"*
chk "D2 printf 리다이렉트로 새 SKILL.md → 발화" \
    "$(printf '%s' '{"session_id":"d2","tool_input":{"command":"printf x > plugins/z/skills/q/SKILL.md"}}' | bash "$H" 2>/dev/null | grep -c additionalContext)" 1
rm -f "$D3/.claude/.prior_art_prompted_"*
# ★컨트롤 — D1/D2 가 «Bash 면 무조건 발화» 가 아님을 보인다. 소음이 이 훅을 죽인다.
chk "D3 ★컨트롤 로그 리다이렉트 + 2>/dev/null → 침묵" \
    "$(printf '%s' '{"session_id":"d3","tool_input":{"command":"echo x > /tmp/a.log 2>/dev/null"}}' | bash "$H" 2>/dev/null | wc -c | tr -d ' ')" 0
chk "D4 ★컨트롤 tracks/ 산출물 리다이렉트 → 침묵" \
    "$(printf '%s' '{"session_id":"d4","tool_input":{"command":"cat > tracks/_meta/note.sh <<EOF\nx\nEOF"}}' | bash "$H" 2>/dev/null | wc -c | tr -d ' ')" 0
chk "D5 ★컨트롤 리다이렉트 없는 명령 → 침묵" \
    "$(printf '%s' '{"session_id":"d5","tool_input":{"command":"git status --short"}}' | bash "$H" 2>/dev/null | wc -c | tr -d ' ')" 0
chk "D6 ★컨트롤 같은 세션 두 번째 Bash → 침묵 (세션당 1회가 Bash 에서도 산다)" \
    "$( { printf '%s' '{"session_id":"d6","tool_input":{"command":"cat > scripts/a.sh <<EOF\nx\nEOF"}}' | bash "$H" >/dev/null 2>&1
         printf '%s' '{"session_id":"d6","tool_input":{"command":"cat > scripts/b.sh <<EOF\nx\nEOF"}}' | bash "$H" 2>/dev/null | wc -c | tr -d ' '; } )" 0
unset CLAUDE_PROJECT_DIR; rm -rf "$D3"

echo "── CONTROL: 계기가 죽으면 조용히 통과 (advisory 는 세션을 못 죽인다) ──"
chk "C1 입력이 JSON 이 아니면 무음 exit 0" \
    "$(printf 'not json' | bash "$H" >/dev/null 2>&1; echo $?)" 0
chk "C2 file_path 없으면 무음" "$(printf '{"tool_input":{}}' | bash "$H" 2>/dev/null | wc -c | tr -d ' ')" 0

echo
if [ "$FAIL" -eq 0 ]; then echo "════ prior-art-prompt lanes: $PASS passed · 0 failed ════"; exit 0
else echo "🟥 prior-art-prompt lanes: $FAIL 실패 / $((PASS+FAIL))"; exit 1; fi
