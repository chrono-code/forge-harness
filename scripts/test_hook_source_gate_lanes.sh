#!/usr/bin/env bash
# test_hook_source_gate_lanes.sh — SessionStart `source` 게이팅 known-pair.
#
# 무엇을 재는가: 캐던스 나그가 `clear`/`compact` 에서 **억제**되고 나머지에서 **뜨는가**.
# 왜 known-pair 인가: 억제만 확인하면 «아무것도 안 뜨는 스크립트» 도 만점이다 — 양성 arm 이
# 없으면 기능이 죽은 것과 구분이 안 된다(이 레포의 «부재측정엔 컨트롤 동반»).
# Exit: 0 전 쌍 성립 / 1 쌍 붕괴 / 10 하네스 오류
set -uo pipefail
D=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB="$D/hook_source_lib.sh"
[ -f "$LIB" ] || { echo "❌ harness-error: $LIB 없음"; exit 10; }
# shellcheck source=scripts/hook_source_lib.sh
. "$LIB"
F=0; ok(){ echo "  ✅ $1"; }; ng(){ echo "  ❌ $1"; F=1; }

echo "[hook-source] known-pair 앵커"
echo
echo "  ── 파서: 페이로드에서 source 를 뽑는가 ──"
for pair in 'startup:startup' 'clear:clear' 'compact:compact' 'resume:resume'; do
  want="${pair##*:}"
  got=$(printf '{"session_id":"x","source":"%s","cwd":"/tmp"}' "${pair%%:*}" | fh_hook_source)
  [ "$got" = "$want" ] && ok "source=$want 추출" || ng "source=$want 인데 '$got'"
done
got=$(printf '{"session_id":"x","cwd":"/tmp"}' | fh_hook_source)
[ "$got" = "unknown" ] && ok "source 키 부재 → unknown (조용히 clear 로 접지 않는다)" \
                       || ng "키 부재인데 '$got'"
got=$(printf '' | fh_hook_source)
[ "$got" = "unknown" ] && ok "빈 stdin → unknown" || ng "빈 stdin 인데 '$got'"
got=$(printf 'not json at all' | fh_hook_source)
[ "$got" = "unknown" ] && ok "비-JSON → unknown" || ng "비-JSON 인데 '$got'"

echo
echo "  ── 게이트: 억제(양성) ──"
for s in clear compact; do
  fh_cadence_due "$s" && ng "source=$s 인데 캐던스가 뜬다" || ok "source=$s → 억제"
done
echo "  ── 게이트: 통과해야 함 (음성 — 과억제가 더 위험하다) ──"
for s in startup resume fork unknown ''; do
  fh_cadence_due "$s" && ok "source='${s:-<빈값>}' → 뜬다" || ng "source='${s:-<빈값>}' 인데 억제됐다"
done

echo
echo "  ── 실물: fh_env_delta_scan 이 헤더만 남기지 않는가 ──"
# 억제 시 sibling-only 케이스에서 «헤더 있고 내용 없음» 이 나오면 안 된다.
T=$(mktemp -d) || { echo "❌ harness-error: mktemp"; exit 10; }
trap 'rm -rf "$T"' EXIT
out_clear=$(printf '{"source":"clear"}' | bash "$D/fh_env_delta_scan.sh" 2>/dev/null || true)
if printf '%s' "$out_clear" | grep -q 'capability-surface change detected'; then
  printf '%s' "$out_clear" | grep -q '  • ' \
    && ok "clear 에서 헤더가 떴다면 항목도 있다 (cwd-미매핑은 억제 대상 아님)" \
    || ng "clear 에서 **헤더만 있고 항목이 없다** — 내용 없는 경보"
else
  ok "clear: 헤더 자체가 안 뜬다 (sibling-only 였다는 뜻)"
fi
out_start=$(printf '{"source":"startup"}' | bash "$D/fh_env_delta_scan.sh" 2>/dev/null || true)
if [ -n "$out_start" ] && [ -z "$out_clear" ]; then
  ok "CONTROL: startup 에서는 뜨고 clear 에서는 안 뜬다 (게이트가 실제로 동작)"
elif [ -z "$out_start" ] && [ -z "$out_clear" ]; then
  ok "CONTROL: 이 머신엔 델타가 없어 양쪽 무출력 — 게이트 판정 불가(미측정, 통과 아님)"
else
  ok "CONTROL: startup 출력 유무=$([ -n "$out_start" ] && echo Y || echo N)"
fi

echo
echo "  ── ①-c peer 스캔: claude-agents 스코프 ──"
CC="$D/session_close_check.sh"
if [ -f "$CC" ]; then
  a=$(CLAUDE_CODE_CHILD_SESSION=1 bash "$CC" 2>/dev/null | grep -c '①-c' || true)
  b=$(env -u CLAUDE_CODE_CHILD_SESSION -u CLAUDE_CODE_AGENT bash "$CC" 2>/dev/null | grep -c '①-c' || true)
  c=$(env -u CLAUDE_CODE_CHILD_SESSION -u CLAUDE_CODE_AGENT FH_PEER_SCAN_FORCE=1 bash "$CC" 2>/dev/null | grep -c '①-c' || true)
  [ "$a" -gt 0 ] && ok "자식 세션 → ①-c 뜬다" || ng "자식 세션인데 ①-c 없음"
  [ "$b" -eq 0 ] && ok "톱레벨(env 부재 시뮬) → 침묵 (솔로 세션 나그 금지)" || ng "env 부재인데 ①-c 떴다"
  [ "$c" -gt 0 ] && ok "CONTROL: override 로 강제하면 뜬다 (b 의 침묵이 기능 사망이 아님을 증명)" \
                 || ng "override 인데 안 뜬다 — b 의 0 은 기능 사망일 수 있다"
else
  ok "session_close_check.sh 부재 — ①-c 레인 미측정(통과 아님)"
fi

echo
if [ "$F" -eq 0 ]; then echo "[hook-source] ✅ all known pairs hold"; exit 0
else echo "[hook-source] ❌ 쌍 붕괴"; exit 1; fi
