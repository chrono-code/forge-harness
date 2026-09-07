#!/usr/bin/env python3
"""doc_claim_triad_scan.py — 문서가 「A 가 B 를 쓴다」고 적었을 때, A 가 실제로 B 를 «실행»하는가.

왜 존재하나
-----------
`[[feedback_rule_misdescribes_its_own_machine]]` — 문서는 정상 발화하는데 «자기 기계에 대한
서술»이 틀린 결함 클래스. 코드가 아니라 «주장»이 틀린 것이라 적대검증·블라인드 sim·되돌림이
구조적으로 못 잡는다. 이 레포에서 실제로 두 번 났다(둘 다 CLAUDE.md 상주층).

판별자는 «이름이 있나»가 아니라 «실행하나»다 — 실측 known-pair:
    templates/.git-hooks/pre-push:631  bash "$REPO_ROOT/scripts/session_close_check.sh"   → 실행
    templates/.git-hooks/pre-push:514  grep -E '(...|predelete_check)\\.sh'                → 언급뿐

🟥 이것은 «리뷰 표면»이지 판정이 아니다. 문서가 두 경로를 나란히 적었다고 해서 «A 가 B 를
   부른다»는 주장인 것은 아니다(과탐 방향). 그래서 출력은 «확인하라»지 «결함이다»가 아니다.

🟥 구조 술어만 쓴다 — FH 고유 어휘(마커·4축·영혼)를 넣지 않는다. 그래야 남의 레포에도 돈다.
"""
from __future__ import annotations
import os, re, sys, json, argparse
from typing import Dict, List, Tuple

DOC_EXT = {".md"}
EXEC_EXT = {".sh", ".py", ".js", ".mjs", ".ts", ".bash"}
HOOK_NAMES = {"pre-commit", "pre-push", "commit-msg", "post-commit", "prepare-commit-msg"}

PATH_RE = re.compile(r'(?<![\w/.-])((?:[\w.-]+/)+[\w.-]+(?:\.(?:sh|py|js|mjs|ts|bash|yml|yaml|json|md))?)')
SKIP_DIRS = {".git", "node_modules", ".venv", "venv", "dist", "build", "__pycache__", ".playwright-mcp"}

def is_execish(p: str) -> bool:
    b = os.path.basename(p)
    return os.path.splitext(b)[1] in EXEC_EXT or b in HOOK_NAMES

def walk(root: str, exts=None) -> List[str]:
    out = []
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in SKIP_DIRS]
        for fn in fns:
            if exts is None or os.path.splitext(fn)[1] in exts:
                out.append(os.path.join(dp, fn))
    return out

def resolve(root: str, p: str) -> str | None:
    cand = os.path.join(root, p)
    if os.path.isfile(cand):
        return cand
    base = os.path.basename(p)
    hits = [f for f in walk(root) if os.path.basename(f) == base]
    return hits[0] if len(hits) == 1 else None

# 실행 증거: 인터프리터 뒤 또는 명령 위치. 주석줄과 grep 패턴 안은 제외.
def executes(src_path: str, target_base: str, target_path: str = "") -> Tuple[str, str]:
    """→ (verdict, evidence)  verdict ∈ EXECUTES | MENTIONS-ONLY | ABSENT"""
    try:
        lines = open(src_path, encoding="utf-8", errors="replace").read().split("\n")
    except OSError:
        return ("ABSENT", "unreadable")
    mention = ""
    esc = re.escape(target_base)
    # 🟥 어간으로도 잡는다 — grep 대안식 안에서는 베이스네임이 이어져 있지 않다.
    #    실측: pre-push:514 는 `predelete_check)\.sh` 라 "predelete_check.sh" 로는 0건이다.
    stem = os.path.splitext(target_base)[0]
    stem_re = re.compile(re.escape(stem) + r'[)\\]*' + re.escape(os.path.splitext(target_base)[1]))
    exec_re = re.compile(r'(?:^|[;&|(]|\$\()\s*(?:(?:bash|sh|source|\.|python3?|node|exec|zsh)\s+)?'
                         r'[^\n#]{0,120}?' + esc)
    # 🟥 전체 경로가 줄에 있으면 그걸 우선한다 (cross-family codex [A]).
    #    basename 만 보면 다른 디렉터리의 동명 파일 실행을 B 실행으로 오인한다.
    for i, ln in enumerate(lines, 1):
        has_full = bool(target_path) and target_path in ln
        if not has_full and target_base not in ln and not stem_re.search(ln):
            continue
        mention = mention or f"{i}: {ln.strip()[:110]}"
        stripped = ln.lstrip()
        if stripped.startswith("#"):
            continue
        # grep/rg 패턴 안이면 언급이다
        if re.search(r'\b(?:grep|rg|egrep|fgrep|ag)\b[^\n]{0,80}' + esc, ln):
            continue
        # 인터프리터 호출 또는 명령 위치
        # 🟥 출력 구문 안의 인터프리터 호출은 실행이 아니다 (cross-family codex [A]).
        #    `echo "bash target.sh"` 는 실행처럼 «보이지만» 아무것도 안 돌린다.
        if re.search(r'\b(?:echo|printf|cat|sed|awk)\b[^\n]{0,40}' + esc, ln):
            continue
        if re.search(r'(?:bash|sh|zsh|source|python3?|node|exec)\s+["\']?[^"\']{0,120}' + esc, ln):
            return ("EXECUTES", f"{i}: {ln.strip()[:110]}")
        if exec_re.search(ln) and not re.search(r'(?:echo|printf|cat)\s', ln):
            return ("EXECUTES", f"{i}: {ln.strip()[:110]}")
    return ("MENTIONS-ONLY", mention) if mention else ("ABSENT", "")


# ── 🟥 나열과 주장을 가른다 ───────────────────────────────────────────────────
# 손검증 2026-09-07: 초판은 «한 줄에 두 실행아티팩트» 를 주장으로 셌는데, 표본이 전부
#   **File:** a.sh · b.sh · c        (나열)
#   Fixtures: `x_lanes.sh` · `y_lanes.sh`.   (나열)
#   python3 scan.py --files src/a.py         (예시 인자)
# 였다. 즉 «관계» 가 아니라 «공존» 을 쟀다 — [[feedback_metric_measures_presence_not_relation]].
#
# 좁히는 술어는 «구조»로만 짠다(언어 중립 — 남의 레포에도 같은 잣대여야 하므로):
#   두 경로 «사이»의 텍스트가 구분자/공백/괄호/백틱뿐이면 그건 나열이다.
#   사이에 실질 낱말이 최소 1개 있어야 관계 주장 후보다.
_SEP_ONLY = re.compile(r'^[\s`\'"*·,;|/()\[\]{}<>&+~\-—–:.]*$')

# 🟥 접속사만 남은 사이 = 여전히 나열이다 (cross-family codex 2026-09-07 [B] · 레인 L3 가 빨개져서 확인).
#    실측: `A · B` `A, B` `"A" "B"` 는 이미 걸렀는데 **`A and B` · `A plus B` 는 통과했다.**
#    실물 사례 — CATALOG.md:137 `Anchors: X (pre-commit) and Y (pre-push)`.
#
# 🟥 **명명된 대가: 이 목록은 언어 의존이다.** 이 파일의 나머지는 구조 술어라 어느 레포에나
#    같은 잣대인데, 이 한 줄만 «영어·한국어 접속사»를 안다. 남의 레포에 돌릴 때 그 언어의
#    접속사가 목록에 없으면 **그쪽 나열이 주장으로 세어진다**(= 그쪽 주장 수가 부풀려진다).
#    측정에 쓸 때 편향 방향: 영어 접속사는 덮으므로 **영어 레포는 더 엄격하게** 걸러진다 —
#    즉 octo 쪽 후보가 줄고 FH 쪽 분모가 상대적으로 커 보이는 방향이다(우리에게 불리한 쪽).
_CONNECTORS = {"and", "plus", "or", "및", "와", "과", "그리고", "vs", "versus", "&"}

def asserts_relation(line: str, a: str, b: str) -> bool:
    ia, ib = line.find(a), line.find(b)
    if ia < 0 or ib < 0:
        return False
    lo, hi = (ia + len(a), ib) if ia < ib else (ib + len(b), ia)
    if hi <= lo:
        return False
    between = line[lo:hi]
    if len(between) > 200:
        return False
    if _SEP_ONLY.match(between):
        return False
    # 구분자를 걷어낸 나머지가 접속사뿐이면 그것도 나열이다
    words = [w for w in re.split(r'[^\w가-힣&]+', between) if w]
    if words and all(w.lower() in _CONNECTORS for w in words):
        return False
    return True

def scan(root: str) -> Dict:
    root = os.path.abspath(root)
    claims = []
    for doc in walk(root, DOC_EXT):
        try:
            lines = open(doc, encoding="utf-8", errors="replace").read().split("\n")
        except OSError:
            continue
        for i, ln in enumerate(lines, 1):
            paths = [p for p in PATH_RE.findall(ln)]
            paths = [p for p in dict.fromkeys(paths)]
            execs = [p for p in paths if is_execish(p)]
            if len(paths) < 2 or not execs:
                continue
            for a in execs:
                for b in paths:
                    if b == a or not is_execish(b):
                        continue
                    if not asserts_relation(ln, a, b):
                        continue
                    claims.append((os.path.relpath(doc, root), i, a, b, ln.strip()[:150]))
    # 🟥 방향은 문서에서 못 읽는다 — «A 가 B 에 배선됐다» 와 «A 가 B 를 부른다» 가
    #    같은 두 경로로 반대 방향을 뜻한다. 그래서 **무순서 쌍**으로 접고, 어느 한쪽이라도
    #    실행하면 EXECUTES 다. 이 접기를 안 하면 참인 주장 절반이 MENTIONS-ONLY 로 나온다
    #    (실측: CLAUDE.md:1422 session_close_check ↔ pre-push).
    # 🟥 명명된 대가 (cross-family codex 2026-09-07 [S]): 이 접기 때문에 **방향이 실제로 반대인
    #    거짓 주장은 통과한다.** 고치지 않는다 — 방향은 산문에서 안 읽히고, 그걸 읽으려는 시도가
    #    이 계기가 세 번 뚫린 이유다. 이 계기는 오탐을 줄이는 쪽을 택하고, 방향 오류는
    #    **사람/에이전트 판단에 남긴다**. 리뷰 표면이지 판정이 아니라는 계약과 일관된다.
    seen = set(); results = []
    for doc, ln, a, b, text in claims:
        key = (doc, ln, *sorted((a, b)))
        if key in seen:
            continue
        seen.add(key)
        ap = resolve(root, a); bp = resolve(root, b)
        if ap is None or bp is None:
            miss = "A-MISSING" if ap is None else "B-MISSING"
            results.append(dict(doc=doc, line=ln, a=a, b=b, verdict=miss, ev="", text=text)); continue
        v1, e1 = executes(ap, os.path.basename(b), b)
        v2, e2 = executes(bp, os.path.basename(a), a)
        if v1 == "EXECUTES":
            results.append(dict(doc=doc, line=ln, a=a, b=b, verdict="EXECUTES", ev=f"{a}: {e1}", text=text))
        elif v2 == "EXECUTES":
            results.append(dict(doc=doc, line=ln, a=b, b=a, verdict="EXECUTES", ev=f"{b}: {e2}", text=text))
        else:
            ev = f"{a}: {e1}" if e1 else (f"{b}: {e2}" if e2 else "")
            v = "MENTIONS-ONLY" if (e1 or e2) else "ABSENT"
            results.append(dict(doc=doc, line=ln, a=a, b=b, verdict=v, ev=ev, text=text))
    counts = {}
    for r in results:
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
    return dict(root=root, docs=len(walk(root, DOC_EXT)), claims=len(results),
                counts=counts, results=results)

# ── 계기 보정 ────────────────────────────────────────────────────────────────
def selftest(root: str) -> int:
    """known-pair — 이 레포의 «실물»로 보정한다. 픽스처가 아니라 실재하는 두 관계."""
    pairs = [
        # (A, B, 기대, 왜)
        ("templates/.git-hooks/pre-push", "scripts/session_close_check.sh", "EXECUTES",
         "known-negative: 진짜로 실행한다 (:631 bash ...)"),
        ("templates/.git-hooks/pre-push", "scripts/predelete_check.sh", "MENTIONS-ONLY",
         "known-positive: grep 패턴 안 + 주석뿐 (:514 :705)"),
    ]
    # ── 절반 ①: 주장 추출기 (나열 vs 관계) ──────────────────────────────
    # 🟥 이 보정이 없어서 초판이 «공존» 을 «주장» 으로 세고 756건이라는 거짓 숫자를 냈다.
    #    픽스처는 그때 손검증에서 나온 «실제로 뚫린 표기» 그대로 쓴다.
    A, B = "scripts/foo.sh", "scripts/bar.sh"
    extract_pairs = [
        (f"**File:** {A} \u00b7 {B} \u00b7 templates/.git-hooks/pre-commit", False, "나열(가운뎃점)"),
        (f"Fixtures: `{A}` \u00b7 `{B}`.", False, "나열(백틱+가운뎃점)"),
        (f"Anchors: `{A}`, `{B}`", False, "나열(쉼표)"),
        (f"{A} 는 {B} 를 호출한다", True, "관계(한국어)"),
        (f"`{A}` is wired into `{B}`", True, "관계(영어)"),
        (f"the hook {A} blocks by running {B}", True, "관계(영어·동사)"),
    ]
    print("계기 보정 ① — 주장 추출기 (나열을 주장으로 세지 않는가)")
    bad0 = 0
    for line, want, why in extract_pairs:
        got = asserts_relation(line, A, B)
        ok = got == want
        bad0 += 0 if ok else 1
        print(f"  {'PASS' if ok else 'FAIL'}  got={str(got):<5} want={str(want):<5} {why}")
    if bad0:
        print(f"\nINSTRUMENT ERROR — 주장 추출기가 {bad0}건을 안 가른다.")
        return 2
    print()

    print("계기 보정 \u2461 — 실행 판별기 (이 레포의 실물 관계)")
    bad = 0
    for a, b, want, why in pairs:
        ap = resolve(root, a)
        if ap is None:
            print(f"  FAIL  {a} 를 못 찾음 — 보정 불가"); bad += 1; continue
        # 🟥 B 의 실재도 본다 (cross-family codex, 2026-09-07 [S]).
        #    안 보면 대상이 삭제·이동돼도 «A 가 이름을 언급»한다는 이유로 보정이 통과한다.
        #    known-pair 가 조용히 낡는 자리다.
        if resolve(root, b) is None:
            print(f"  FAIL  {b} 가 실재하지 않는다 — known-pair 가 낡았다"); bad += 1; continue
        got, ev = executes(ap, os.path.basename(b))
        ok = got == want
        bad += 0 if ok else 1
        print(f"  {'PASS' if ok else 'FAIL'}  {os.path.basename(b):<28} got={got:<14} want={want:<14} {why}")
        if not ok:
            print(f"        증거: {ev[:100]}")
    if bad:
        print(f"\nINSTRUMENT ERROR — {bad} 건이 안 갈린다. 이 스캐너의 숫자를 쓰지 마라.")
        return 2
    print("\n계기가 둘을 가른다. 「실행」과 「언급」이 구별된다.")
    return 0

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("root", nargs="?", default=".")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--home", default=None,
                    help="외부 레포를 스캔할 때 «실행 판별기» 보정을 어느 레포에서 할지. "
                         "executes() 는 파일 내용의 순수 함수라 보정이 이식된다 — "
                         "그러나 추출기 보정(합성 픽스처)은 어디서나 같다.")
    ap.add_argument("--show", default="MENTIONS-ONLY,B-MISSING,A-MISSING")
    a = ap.parse_args()
    root = os.path.abspath(a.root)
    cal_root = os.path.abspath(a.home) if a.home else root
    if a.selftest:
        return selftest(cal_root)
    # 보정 없이 숫자를 못 낸다 — 보정 실패면 스캔 안 한다
    if selftest(cal_root) != 0:
        print("\n🟥 보정 실패 → 스캔하지 않는다.")
        return 2
    print()
    r = scan(root)
    if r["claims"] == 0:
        print(f"NO-CLAIMS — 문서 {r['docs']}건에서 «두 실행아티팩트가 한 줄에» 나오는 주장이 0건이다.")
        print("이것은 «결함 0» 이 아니라 «이 계기가 잴 표면이 없음» 이다.")
        return 3
    print(f"문서 {r['docs']}건 · 주장후보 {r['claims']}건")
    for k in sorted(r["counts"], key=lambda x: -r["counts"][x]):
        print(f"  {r['counts'][k]:>5}  {k}")
    show = set(a.show.split(","))
    flagged = [x for x in r["results"] if x["verdict"] in show]
    print(f"\n── 확인 대상 {len(flagged)}건 (리뷰 표면이지 판정이 아니다) ──")
    for x in flagged[:40]:
        print(f"  {x['doc']}:{x['line']}  [{x['verdict']}]  {x['a']} → {x['b']}")
        if x["ev"]: print(f"      A쪽 {x['ev']}")
    if len(flagged) > 40:
        print(f"  … 외 {len(flagged)-40}건")
    if a.json:
        print(json.dumps(r, ensure_ascii=False, indent=1))
    return 0

if __name__ == "__main__":
    sys.exit(main())
