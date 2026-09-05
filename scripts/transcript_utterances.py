#!/usr/bin/env python3
"""transcript_utterances.py — Claude Code 전사본(jsonl) → 운영자 발화.

WHY THIS FILE EXISTS. 이 추출 로직은 `compaction_probe.sh` 안에 heredoc 으로 인라인돼 있었고,
「받는 절반」(발화 → 기록 착지) 을 배선하려면 두 번째 소비처가 필요했다. 사본을 두 벌 두는 것은
`[[feedback_divergent_leniency_duplicate_normalizers]]` — 전처리가 갈리면 **한쪽만 통과하는
입력이 다른 쪽에서 무음 드롭된다**. 그래서 파일 하나로 꺼낸다.

🟥 SEAL 출력은 바이트 동일해야 한다. `--format seal` 은 인라인 판본을 **그대로** 재현한다
(줄 형식 · 합계/제외 문구 · 카운터 이름까지). `scripts/test_utterance_intake_lanes.sh` L10 이
골든으로 고정하고, L12/L12b 가 «이 파일이 정말 seal 경로에 있는가» 를 되돌림으로 잰다.

── 무엇을 발화로 세는가 (그리고 왜) ──────────────────────────────────────────
`type=user` 는 **사람 발화가 아니다** — 툴 결과 · peer 메시지 · task 알림이 같은 타입으로 온다
(`[[feedback_type_user_is_not_human_utterance.md]]`: 39 vs 실제 30). 실측(2026-09-05, 이 레포의
전사본 전수): `<task-notification` 3791 · `<cross-session-message` 1467 · `<local-command-*` 232 —
전부 `<` 로 시작하므로 봉투 접두 규칙이 잡는다.
  · content 가 str          → 발화 후보
  · content 가 list         → tool_result 블록이 하나라도 있으면 **툴 결과**(제외).
                              아니면 text 블록만 이어붙인다. 🟥 이미지 첨부 실발화가 list 다 —
                              「list = 툴결과」로 가르면 그런 발화가 구조적으로 안 보인다.
  · text 블록이 없음        → 이미지 전용 등. **세되 싣지 않는다**(지우지 않는다).
  · `<` 또는 `/` 로 시작    → 메타 봉투 · 슬래시 커맨드(제외)
  · `--min-chars N` 미만    → 짧은 응답(«ㄱㄱ» «응» «승인»). **별도 카운터**로 센다.
  · `--strip-system-markers` → 아래 §시스템 마커. **기본 OFF** — 켜면 seal 출력이 바뀐다.

🟥 제외분을 반드시 인쇄한다. 합계만 찍으면 그 원장이 완전한 것처럼 읽힌다 —
`[[feedback_not_found_is_not_zero_family]]`.

── 사용 ──────────────────────────────────────────────────────────────────────
  python3 scripts/transcript_utterances.py <transcript.jsonl> [--min-chars N]
         [--format tsv|seal] [--strip-system-markers]
    tsv  (기본) : `n<TAB>ts<TAB>text`  한 줄 한 발화. ts 가 없으면 `-`.
    seal        : compaction_probe seal 블록 (바이트 동일)
  종료코드: 0 정상 · 2 인자/파일 문제(호출부의 «파싱 실패» 폴백이 여기서 뜬다)

이식성: 표준 라이브러리만. python3.6+ (f-string).
"""
import json
import re
import sys


# ── 시스템 마커 (실측 2026-09-05, 이 레포 전사본 전수 — 대괄호 접두 171 건) ──────────────
# `type=user` 로 오지만 **운영자가 친 것이 아닌** 것들. 개수를 세서 골랐다:
#     [Cross-session delivery notice] 66 · [Request interrupted by user] 45 ·
#     [automated-run: launchd] 31 · [Image #N] 17 · [Cross-session idle notice] 4
# 정책 두 갈래 — ⓐ **통째로 버릴 것**(발신자가 사람이 아니다) ⓑ **마커만 벗길 것**(뒤에 실발화가 온다).
# 🟥 `[자율 루프 …]` 8 건은 **일부러 안 넣었다** — 운영자가 쓴 무인 실행 프롬프트라 과포함(안전)
#    쪽에 둔다. 과소포함은 무음 손실이라 방향이 다르다.
# 🟥 기본 OFF. 켜면 seal 출력이 바뀌므로 `--strip-system-markers` 를 준 소비처(intake)만 받는다.
# 🟥 압축 이어붙임 프리앰블도 `type=user` 로 온다 — 실측 21 건, 그리고 **첫 실사용에서
#    미착지 목록에 그대로 떴다**(2026-09-05). 런타임이 주입한 요약이지 운영자 발화가 아니다.
#    괄호로 시작하지 않아 앞의 대괄호 규칙이 구조적으로 못 잡는다 — 별도 접두로 센다.
_DROP_PREFIXES = ('[Cross-session delivery notice]', '[Cross-session idle notice]',
                  '[automated-run:',
                  'This session is being continued from a previous conversation')
_STRIP_MARKER = re.compile(r'^\[(?:Image|Request interrupted by user)[^\]]*\]\s*')


def _is_slash_command(t):
    """슬래시 커맨드인가, 절대경로로 시작하는 실발화인가.

    🟥 실측 2026-09-05, 이 레포 전사본 전수: `<` 봉투가 아닌 `/` 접두 발화 **28 건 중 13 건**
    (46%)이 **절대경로로 시작하는 진짜 발화**였다 — «/Users/…/OT.pptx.pdf 이건 발표자 ot자료인…»
    처럼 지시가 통째로 딸려 있다. 옛 규칙(`startswith('/')` → 커맨드)은 그 13 건을 무음 삭제했다.
    판별자: **첫 낱말의 `/` 개수**. `/compact` `/install-wizard --dry-run` = 1 개(커맨드) ·
    `/Users/<name>/…` = 2 개 이상(경로). 이 코퍼스에서 15/13 으로 깨끗이 갈린다.

    🟥 이 규칙은 `--strip-system-markers` 를 준 소비처에만 적용된다. seal 은 안 준다 —
    바꾸면 기존 원장 출력이 달라지고, 그건 리팩터가 아니라 **행동 변경**이라 운영자 판단이다.
    즉 seal 쪽에는 이 결함이 **아직 남아 있다**(보고서에 이름으로 남긴다).
    """
    return t.split(' ', 1)[0].count('/') == 1


def _apply_system_markers(t):
    """→ (text, dropped).  dropped=True 면 이 레코드는 발화가 아니다."""
    for pref in _DROP_PREFIXES:
        if t.startswith(pref):
            return '', True
    prev = None
    while prev != t:
        prev = t
        t = _STRIP_MARKER.sub('', t)
    if not t.strip():
        return '', True
    return t, False


def _iter_records(path):
    with open(path, errors='replace') as fh:
        for line in fh:
            try:
                yield json.loads(line)
            except Exception:
                continue


def extract(path, min_chars=0, strip_system=False):
    """→ (utterances, counters).  utterances = [(n, ts, text), ...] (1-based n)."""
    out = []
    n = 0
    c = {'tool': 0, 'meta': 0, 'other': 0, 'short': 0, 'sys': 0}
    for d in _iter_records(path):
        if d.get('type') != 'user':
            continue
        # Runtime-flagged provenance: isMeta (harness-injected — command expansions, caveats,
        # image placeholders) and isSidechain (a sub-agent's conversation) are not operator
        # utterances. A channel property of the record itself, not a content judgment. Measured on
        # a live transcript 2026-09-05: 1 of 379 user records is isMeta with plain text (the image
        # placeholder), 0 isSidechain — so the seal ledger loses exactly that line. (codex finding 4)
        if d.get('isMeta') or d.get('isSidechain'):
            c['meta'] += 1
            continue
        m = d.get('message') or {}
        content = m.get('content')
        if isinstance(content, str):
            t = content
        elif isinstance(content, list):
            if any(isinstance(b, dict) and b.get('type') == 'tool_result' for b in content):
                c['tool'] += 1
                continue
            parts = [b.get('text', '') for b in content
                     if isinstance(b, dict) and b.get('type') == 'text']
            if not parts:
                c['other'] += 1          # 이미지 전용 등 — 셈에서 지우지 않고 센다
                continue
            t = ' '.join(parts)
        else:
            c['other'] += 1
            continue
        t = ' '.join(t.split())
        if not t:
            c['other'] += 1
            continue
        if t.startswith('<'):                        # 메타 봉투
            c['meta'] += 1
            continue
        if t.startswith('/'):
            # strip_system 이 꺼져 있으면 옛 규칙 그대로 — seal 출력 바이트 동일의 근거다.
            if not (strip_system and not _is_slash_command(t)):
                c['meta'] += 1
                continue
        if strip_system:
            t, dropped = _apply_system_markers(t)
            if dropped:
                c['sys'] += 1
                continue
        if min_chars and len(t) < min_chars:
            c['short'] += 1
            continue
        n += 1
        out.append((n, d.get('timestamp') or '-', t))
    return out, c


def _seal(utterances, c):
    # 🟥 인라인 판본과 **바이트 동일**. 문구·구두점·카운터 이름을 바꾸지 마라 (L10 골든).
    for n, _ts, t in utterances:
        print(f"{n}. {t[:200]}")
    total = len(utterances)
    print(f"\n합계: {total}건" if total else "- (발화 0건)")
    print(f"제외: tool_result {c['tool']} · 메타/커맨드 {c['meta']} · 텍스트없음 {c['other']}")


def _tsv(utterances, c):
    for n, ts, t in utterances:
        # 탭·개행은 위에서 이미 접혔다. 그래도 방어적으로 한 번 더 — 한 줄 = 한 발화가 계약이다.
        print(f"{n}\t{ts}\t" + t.replace('\t', ' '))
    # 제외분은 stderr 로. stdout 은 «한 줄 한 발화» 계약이라 소비처가 `wc -l` 로 세도 안전해야 한다.
    sys.stderr.write(
        f"제외: tool_result {c['tool']} · 메타/커맨드 {c['meta']} · "
        f"텍스트없음 {c['other']} · 짧음 {c['short']} · 시스템마커 {c['sys']}\n")


def main(argv):
    if len(argv) < 2:
        sys.stderr.write("usage: transcript_utterances.py <transcript.jsonl> "
                         "[--min-chars N] [--format tsv|seal]\n")
        return 2
    path = argv[1]
    min_chars = 0
    fmt = 'tsv'
    strip_system = False
    i = 2
    while i < len(argv):
        a = argv[i]
        if a == '--min-chars' and i + 1 < len(argv):
            try:
                min_chars = int(argv[i + 1])
            except ValueError:
                sys.stderr.write(f"transcript_utterances: --min-chars 값이 정수가 아니다: {argv[i+1]}\n")
                return 2
            i += 2
        elif a == '--format' and i + 1 < len(argv):
            fmt = argv[i + 1]
            if fmt not in ('tsv', 'seal'):
                sys.stderr.write(f"transcript_utterances: --format 은 tsv|seal: {fmt}\n")
                return 2
            i += 2
        elif a == '--strip-system-markers':
            strip_system = True
            i += 1
        else:
            sys.stderr.write(f"transcript_utterances: 알 수 없는 인자: {a}\n")
            return 2
    try:
        utterances, counters = extract(path, min_chars, strip_system)
    except OSError as e:
        # 호출부(compaction_probe seal)의 «파싱 실패» 폴백이 이 비영 종료로 뜬다.
        sys.stderr.write(f"transcript_utterances: 전사본을 열 수 없다: {e}\n")
        return 2
    if fmt == 'seal':
        _seal(utterances, counters)
    else:
        _tsv(utterances, counters)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
