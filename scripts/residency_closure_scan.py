#!/usr/bin/env python3
"""Residency 폐포 스캔 — 외부 계열 dispatch 전에 **무엇이 실제로 나가는지**를 판별한다.

운영자 결정(2026-08-09, 요지 — 원문 인용 아님): 엔진 소스 자체는 보호 대상 IP 가 아니고,
외부 계열 송신 가부의 기준은 **폐포 스캔**이다.

→ residency 대상은 **코드 자체가 아니라 거기 섞여 들어간 조직 식별자**다.
   그래서 판별자는 「이 레포는 누구 것인가」(사람 판단)가 아니라
   **「이 모듈의 로컬 임포트 폐포에 조직 식별자가 있는가」**(기계 판정)다.

## 왜 폐포인가 — 그리고 폐포의 한계

파일 하나만 보면 그 파일이 import 하는 설정/클라이언트 모듈에 박힌 호스트명을 놓친다.
실측(2026-08-09, qasp-dev):

    <clean module>      폐포  2개   조직 식별자 0건            → 밖으로 나가도 된다
    <config-coupled>    폐포  2개   조직토큰 ×2 · 호스트 ×3    → 안 된다 (설정 모듈 경유)
    <wide closure>      폐포 27개   조직토큰 ×30 · 호스트 ×30  → 안 된다

🟡 **폐포는 스크리닝이지 송신물 그 자체가 아니다.** 폐포가 0이면 확실히 안전하지만,
   폐포가 0이 아니라고 **반드시 못 보내는 것은 아니다** — 오염된 파일을 payload 에서
   빼면 된다. 이 스크립트는 «어느 파일이 오염됐는지» 를 찍어서 그 선택을 가능하게 한다.
   (`--files` 로 실제 송신 파일 목록을 주면 폐포 대신 그것만 잰다.)

## 🟥 CLEAN 은 «보내도 안전» 이 아니다 — 스크리닝이다

cross-family 적대검증(gpt-5.5, 2026-08-09)이 false-CLEAN 경로 다수를 냈고 **픽스처로 재현**했다.
확정 3건은 닫았다(상대 임포트 · 루트 화이트리스트 · `from pkg import sub`; 레인 테스트 참조).
**닫지 못한 것은 원리적이라 이름을 붙여 남긴다** — 이걸 안 적고 CLEAN 을 floor 로 쓰면 유출한다:

    · 동적 임포트(`importlib`) · 플러그인 엔트리포인트 · 네임스페이스 패키지 → 간선이 안 보인다
    · **비-파이썬 반출물**(.env · YAML/JSON · 픽스처 · 노트북 · 락파일) → 폐포에 아예 없다
    · 인코딩/조립(문자열 분할 · base64 · 퍼센트 · 동형문자) → 정규식이 못 본다
    · `--files` 는 **큐레이션 우회**가 가능하다 — 목록을 좁게 주면 CLEAN 이 나온다
    · TOCTOU — 스캔 후 송신 전에 파일이 바뀌면 판정이 낡는다
    · 파싱 실패 모듈의 의존은 안 따라간다(그 경우 stderr 로 알린다)

∴ **판정 의미**: CLEAN = «명시된 패턴·명시된 한계 안에서 조직 식별자를 못 찾았다».
   TAINTED 는 강한 신호(찾았다)이고, CLEAN 은 약한 신호(못 찾았다)다 — 비대칭이 본질이다.
   `not found ≠ 0` 을 이 도구 자신에게도 적용한다.

## 종료 코드

    0   CLEAN      — 조직 식별자 0건. 외부 계열 dispatch 가능
    1   TAINTED    — 오염 파일 있음. 그 파일을 빼거나 경계-내 패널로
    10  HARNESS    — 패턴 파일 없음/스캔 불가. **fail-closed** (0 으로 읽지 마라)

## 패턴 (2층 — 공개 레포에 조직 리터럴을 두지 않는다)

    .claude/rules/.residency-patterns.defaults   커밋됨. 일반형만(조직 리터럴 없음)
    .claude/rules/.residency-patterns            gitignored. 운영자 리터럴
    RESIDENCY_PATTERNS=<path>                     환경변수 오버라이드

한 줄 = 정규식 하나. `#` 주석·빈 줄 무시.
🟥 **오버라이드 파일이 없으면 exit 10 이다.** 일반형 defaults 만으로 "0건" 을 내면
   그건 «깨끗하다»가 아니라 «조직 리터럴을 안 봤다» 이고, 그 둘을 접으면
   not-found 를 0 으로 렌더하는 그 결함이다.
"""
from __future__ import annotations

import argparse
import ast
import os
import re
import sys
from collections import deque
from pathlib import Path


EXIT_CLEAN, EXIT_TAINTED, EXIT_HARNESS = 0, 1, 10


def _module_path(repo: Path, mod: str) -> Path | None:
    rel = mod.replace(".", "/")
    for cand in (repo / f"{rel}.py", repo / rel / "__init__.py"):
        if cand.is_file():
            return cand
    return None


def _local_imports(path: Path, mod: str) -> tuple[list[str], bool]:
    """(후보 모듈, 파싱실패여부). **파싱 실패를 조용히 0으로 렌더하지 않는다.**

    cross-family 적대검증(2026-08-09)이 재현으로 반증한 3가지를 여기서 닫는다:
      · 상대 임포트(`from .x import y`)를 `level == 0` 조건이 통째로 버렸다
      · `("src","scripts",…)` 루트 화이트리스트가 다른 레이아웃을 통째로 못 봤다
      · `from pkg import sub` 가 `pkg/__init__.py` 만 훑고 `pkg/sub.py` 를 놓쳤다
    """
    try:
        tree = ast.parse(path.read_text(encoding="utf-8", errors="ignore"))
    except (SyntaxError, ValueError):
        return [], True
    pkg = mod.rsplit(".", 1)[0] if "." in mod else ""
    out: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            out += [a.name for a in node.names]
        elif isinstance(node, ast.ImportFrom):
            base = node.module or ""
            if node.level:                      # 상대 임포트 — 현재 패키지 기준으로 푼다
                parts = pkg.split(".") if pkg else []
                up = node.level - 1
                anchor = ".".join(parts[:len(parts) - up]) if up <= len(parts) else ""
                base = f"{anchor}.{base}".strip(".") if base else anchor
            if base:
                out.append(base)
                # `from pkg import sub` — sub 가 모듈일 수 있다
                out += [f"{base}.{a.name}" for a in node.names]
    return out, False


def closure(repo: Path, start: str) -> tuple[list[Path], int]:
    """도달 가능한 **레포 안** 모듈 파일 + 파싱실패 수.

    로컬 판정은 화이트리스트가 아니라 **레포 안에 해당 파일이 실재하는가**다.
    부모 패키지의 `__init__.py` 도 포함한다 — 거기 상수가 박혀 있으면 같이 나간다.
    """
    seen: set[str] = set()
    files: list[Path] = []
    unparsed = 0
    q = deque([start])
    while q:
        mod = q.popleft()
        if mod in seen:
            continue
        seen.add(mod)
        p = _module_path(repo, mod)
        if p is None:
            continue
        files.append(p)
        # 부모 패키지 __init__.py 도 payload 에 딸려간다
        parts = mod.split(".")
        for i in range(1, len(parts)):
            init = _module_path(repo, ".".join(parts[:i]))
            if init is not None and init not in files:
                files.append(init)
        deps, failed = _local_imports(p, mod)
        unparsed += int(failed)
        q.extend(d for d in deps if d not in seen)
    return files, unparsed


def load_patterns(repo: Path) -> tuple[list[tuple[str, re.Pattern]], str | None]:
    """(패턴 목록, 오류). 오버라이드가 없으면 오류를 돌려준다 — fail-closed."""
    # ★패턴은 **이 스크립트가 사는 레포**(FH)에서 찾는다 — 스캔 대상 레포가 아니다.
    #   대상 레포 기준으로 찾으면 남의 레포를 스캔할 때마다 defaults 부재로 fail-closed 가 되어
    #   주 용도(다른 레포의 모듈을 재는 것)를 통째로 막는다. 실측으로 잡았다.
    home = Path(__file__).resolve().parent.parent
    defaults = home / ".claude/rules/.residency-patterns.defaults"
    override = Path(os.environ.get("RESIDENCY_PATTERNS", "")) if os.environ.get(
        "RESIDENCY_PATTERNS") else home / ".claude/rules/.residency-patterns"
    pats: list[tuple[str, re.Pattern]] = []
    for src in (defaults, override):
        if not src.is_file():
            continue
        for line in src.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            try:
                pats.append((src.name, re.compile(line, re.I)))
            except re.error:
                return [], f"패턴 컴파일 실패: {src}: {line!r}"
    override_pats = 0
    if override.is_file():
        for line in override.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                override_pats += 1
    if override.is_file() and override_pats == 0:
        return [], (
            f"운영자 패턴 파일이 비었다(주석뿐이거나 0줄): {override}\n"
            "  «비었다» 를 «깨끗하다» 로 읽으면 안 된다 — 없는 것과 같다. fail-closed.")
    if not defaults.is_file():
        return [], f"defaults 패턴 파일이 없다: {defaults} — 패턴 층이 불완전하다. fail-closed."
    if not override.is_file():
        return pats, (
            f"운영자 패턴 파일이 없다: {override}\n"
            "  일반형 defaults 만으로 낸 '0건' 은 «깨끗하다» 가 아니라 «조직 리터럴을 안 봤다» 다.\n"
            "  → 파일을 만들거나 RESIDENCY_PATTERNS=<path> 를 줘라. fail-closed 로 멈춘다.")
    if not pats:
        return [], "패턴이 하나도 없다 (defaults·override 둘 다 비었다)"
    return pats, None


def scan(files: list[Path], pats) -> dict[Path, list[str]]:
    hits: dict[Path, list[str]] = {}
    for f in files:
        text = f.read_text(encoding="utf-8", errors="ignore")
        for _src, rx in pats:
            found = rx.findall(text)
            if found:
                hits.setdefault(f, []).append(f"{rx.pattern} ×{len(found)}")
    return hits


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("targets", nargs="+",
                    help="모듈 경로(src.act2.precondition) 또는 --files 일 때 파일 경로")
    ap.add_argument("--repo", default=".", help="레포 루트 (기본 cwd)")
    ap.add_argument("--files", action="store_true",
                    help="폐포를 안 따라가고 **주어진 파일만** 잰다 — 실제 송신 payload 를 잴 때")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    pats, err = load_patterns(repo)
    if err:
        print(f"🟥 HARNESS_ERROR — {err}", file=sys.stderr)
        return EXIT_HARNESS

    if args.files:
        files = [Path(t) if Path(t).is_absolute() else repo / t for t in args.targets]
        missing = [f for f in files if not f.is_file()]
        if missing:
            print(f"🟥 HARNESS_ERROR — 파일 없음: {missing}", file=sys.stderr)
            return EXIT_HARNESS
    else:
        files = []
        unparsed_total = 0
        for t in args.targets:
            got, unparsed = closure(repo, t)
            unparsed_total += unparsed
            if not got:
                print(f"🟥 HARNESS_ERROR — 모듈을 못 찾았다: {t} (repo={repo})", file=sys.stderr)
                return EXIT_HARNESS
            files += got
        files = sorted(set(files))
        if unparsed_total:
            print(f"🟡 파싱 실패 모듈 {unparsed_total}개 — 그 의존은 **안 따라갔다**. CLEAN 이어도 미탐 잔여다.", file=sys.stderr)

    hits = scan(files, pats)
    scope = "파일" if args.files else "폐포"
    print(f"{scope} {len(files)}개 · 패턴 {len(pats)}개")
    if not hits:
        print("✅ CLEAN(스크리닝) — 이 패턴·이 한계 안에서 조직 식별자를 못 찾았다")
        print("   🟡 «보내도 안전» 이 아니다. 비-파이썬 반출물·동적 임포트·인코딩·"
              "TOCTOU 는 이 도구가 못 본다 (헤더 §CLEAN 은 스크리닝이다).")
        return EXIT_CLEAN

    print(f"🟥 TAINTED — 오염 파일 {len(hits)}개")
    for f, why in sorted(hits.items()):
        print(f"   {f.relative_to(repo) if repo in f.parents else f}")
        for w in why:
            print(f"      {w}")
    print("\n→ 선택지: ⓐ 이 파일들을 payload 에서 빼고 --files 로 재검 "
          "ⓑ 경계-내 패널로 라우팅")
    return EXIT_TAINTED


if __name__ == "__main__":
    sys.exit(main())
