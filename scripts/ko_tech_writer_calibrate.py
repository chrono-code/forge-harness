#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ko_tech_writer_calibrate.py — `ko-tech-writer` Step 2 / Step 4-b 스캔의 **판별력** known-pair.

왜 파이썬인가 (엔진 선택은 취향이 아니라 실측 결과다)
─────────────────────────────────────────────────────────
`SKILL.md` Step 4 가 허용 엔진을 명시한다: *"유니코드 인식 엔진(ripgrep · GNU grep UTF-8
로케일 · Python `re` — **`grep -P` 는 예외**)"*. 초판은 `rg` 로 고정했고 **CI 에서 죽었다** —
ubuntu-latest 에 ripgrep 이 없다(2026-08-17 실측, `HARNESS ERROR ... exited 10`).
같은 실행에서 이식성 린트도 걸렸다: 셸 파일 안의 `[가-힣]` 문자 범위는
**GNU grep C 로케일에서 exit 2 로 죽고 그 결과가 «무매치» 로 읽힌다** — 즉 fail-open.

Python `re` 는 ⓐ 세 허용 엔진 중 **어디에나 있는 유일한 것**이고 ⓑ 유니코드를 기본으로
인식하며 ⓒ 패턴이 셸 밖으로 나가 로케일 문제를 구조적으로 없앤다. **격하가 아니라
정본이 이미 허용한 등가 엔진으로의 이동**이다.

무엇을 주고 무엇을 안 주는가 — 섞지 마라
─────────────────────────────────────────────────────────
  준다     각 스캔이 **양성을 잡고 음성을 안 잡는가**(=판별력). 재현 커맨드와 실행 출력.
  안 준다  그 스캔이 **임의 문서에서 잔여 0건인가**. 그건 문서마다 따로 재는 것이다.
           ⇒ 이걸 통과했다고 «Step 2 잔여 0» 을 주장하면
              `harness_terminal_correlation_and_recommendations.md` 의 강등 사유가 그대로 재발한다.

exit: 0 전 레인 판별 · 1 판별 실패 · 10 harness error(픽스처 부재)
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, "..", "plugins", "fh-commons", "skills", "ko-tech-writer", "fixtures")
POS = os.path.join(FIX, "known_positive.md")
NEG = os.path.join(FIX, "known_negative.md")

# (라벨, 패턴) — Step 2 의 5클래스 + Step 4-b 의 2패턴.
# 🟥 여기 패턴과 SKILL.md 코드블록의 패턴은 **서로 다른 문자열이다**(예: C1 은 `" — "` 양쪽
#    공백형인데 SKILL.md 는 그 형태를 금지한다). 이 스위트가 초록이어도 **SKILL.md 쪽 패턴이
#    보정된 것은 아니다.** 두 벌인 상태이고, 그 사실이 SKILL.md §Step 2-a 에도 적혀 있다.
#
# ⚠️ 아래 판정의 인용문은 **사문(死文)이다** — 2026-08-25 에 SKILL.md 에서 삭제됐다.
#    그 파일은 이제 「앞 몇 줄」식 위치 열거를 안 쓰고 표의 `check-class` 열로 채점한다
#    (위치 서술이 행 추가 때마다 조용히 어긋났다). 판정 자체는 유효하므로 남긴다.
#    🟥 **「둘뿐」도 2026-08-25 부로 그 시점 상태다** — 같은 날 SKILL.md 코드블록에 C2(용어-머리)
#    패턴이 실렸다. C4 는 여전히 이 파일에만 있다(아래 참조).
#
# 🟥 정본의 분류가 과장이라는 것이 첫 캘리브레이션에서 드러났다. SKILL.md 는
#    "앞 다섯 줄은 기계 검출 가능" 이라 적었는데, **당시 grep 을 싣고 있던 것은
#    C1(줄표)·C5(소유 직역) 둘뿐**이고 C2·C3·C4 의 «검출 힌트» 칸은 산문 서술이었다.
#    특히 C4 는 «서술어 없는 마침» 이라는 서술뿐 패턴이 없다 — 지금도 그렇다.
LANES = [
    ("C1 줄표 이어붙임", r"(다|것|음) — "),
    ("C2 용어-머리", r"^\s*[-*]\s+\*\*[^*]+\*\* — "),
    ("C3 콜론 나열투", r"[가-힣]은: "),
    # C4: SKILL.md 에 패턴이 없다. 아래는 **후보 검출**이지 판정이 아니다
    # (SKILL.md 자신의 규율: "grep은 후보를 표시할 뿐, 남길지 판정은 문맥으로").
    # 닫힌 명사 어휘라 **recall 이 낮다** — 낮은 쪽이 과차단보다 안전한 방향이고,
    # 넓히려면 어휘를 늘리는 게 아니라 형태소 분석이 필요하다.
    ("C4 조각문(후보·닫힌 어휘)", r"(층|것|점|축|건|뿐|바|셈)\.\s*(<!--|$)"),
    ("C5 소유 직역", r"(을|를) (갖|가지)"),
    ("C6 전칭 어휘", r"전부|모두|하나도|전혀|일절|예외 없이"),
    ("C6b 부정형 전칭", r"(안|못) ?(했|만들|나오|잡히)|지 않았(다|습니다)"),
]

# 절대 잡히면 안 되는 토큰 — 「늘 잡는다」를 내는 죽은 계기 배제용
NEVER = r"ZZZ_absent_token_ZZZ"


def count(path, pattern):
    """패턴에 매칭되는 **줄 수**. 파일 부재는 예외로 올린다(무음 0 금지)."""
    rx = re.compile(pattern, re.MULTILINE)
    n = 0
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if rx.search(line.rstrip("\n")):
                n += 1
    return n


def main():
    for p in (POS, NEG):
        if not os.path.isfile(p):
            sys.stderr.write("harness error: fixture missing %s\n" % p)
            return 10

    print("engine: python%d.%d re (unicode-aware)"
          % (sys.version_info[0], sys.version_info[1]))
    print("known-positive: %s" % os.path.relpath(POS, os.path.join(HERE, "..")))
    print("known-negative: %s" % os.path.relpath(NEG, os.path.join(HERE, "..")))
    print("")

    npass = nfail = 0
    for label, pat in LANES:
        p = count(POS, pat)
        n = count(NEG, pat)
        if p >= 1 and n == 0:
            print("OK   %s -- positive %d / negative 0 (discriminates)" % (label, p))
            npass += 1
        elif p < 1:
            print("FAIL %s -- MISSES the positive (positive %d). A blind instrument." % (label, p))
            nfail += 1
        else:
            print("FAIL %s -- HITS the negative (negative %d). Over-blocks; no discrimination."
                  % (label, n))
            nfail += 1

    # META 컨트롤 1 — 없는 토큰이 양쪽 다 0인가 (계기가 «늘 잡는다» 를 내지 않는다)
    if count(POS, NEVER) == 0 and count(NEG, NEVER) == 0:
        print("OK   META control -- an absent token matches nothing in either fixture")
        npass += 1
    else:
        print("FAIL META control -- an absent token matched. Do not trust this suite.")
        nfail += 1

    # META 컨트롤 2 — 두 픽스처가 실제로 다른 파일인가
    with open(POS, encoding="utf-8") as a, open(NEG, encoding="utf-8") as b:
        if a.read() != b.read():
            print("OK   META control -- positive/negative fixtures differ")
            npass += 1
        else:
            print("FAIL META control -- the two fixtures are identical; results are meaningless")
            nfail += 1

    print("")
    if nfail == 0:
        print("CALIBRATED (%d lanes) -- Step 2 five classes + Step 4-b two patterns discriminate."
              % npass)
        print("  NOT proven: 'zero residue' in any real document. That is measured per document.")
        print("  Citing this suite as evidence of 'zero residue' reproduces the very downgrade")
        print("  recorded in harness_terminal_correlation_and_recommendations.md.")
        return 0
    print("NOT CALIBRATED (%d/%d failed)" % (nfail, npass + nfail))
    return 1


if __name__ == "__main__":
    sys.exit(main())
