#!/usr/bin/env python3
"""docs/map 의 archify 산출 HTML 에 붙이는 재생성-후 후처리 — 두 가지만 한다.

  (1) reader-width floor  뷰어의 `MIN_READER_WIDTH = 960` 상수를 뷰포트 비례 하한으로 바꾼다.
      archify 뷰어는 «스크롤 없이 다 담기» 를 목표로 폭을 줄이는데, 세로 예산이 모자라면
      1728px 화면에서도 960px 로 바닥을 친다(실측 2026-09-06: 1728×950 → 960). 지도는
      «한 화면에 담기» 보다 «넓게 읽기» 가 목적이라 하한을 화면 비례로 올린다.
      실측 효과(1728×950, fh_process): 960 → 1382.  가로 오버플로 없음(1280×800 → 1216).

  (2) SVG 재생성      HTML 안의 유일한 <svg> + 뷰어 <style> 을 심은 정적 벡터를 다시 만든다.
      기존 커밋본 두 장(fh_trust.dataflow.svg · fh_assets.architecture.svg)에 대해
      바이트 동일 재현을 known-pair 로 확인하고 만든 추출기다.

fail-closed: 기대한 리터럴이 없으면(렌더러 버전 드리프트) 종료코드 3 으로 멈춘다 —
조용히 «패치할 게 없었다» 로 넘어가면 다음 발행이 옛 동작으로 나간다.

  usage: map_postprocess.py <file.html> [...]   실제 적용
         map_postprocess.py --check <file.html> [...]   적용 여부만 보고(쓰기 없음)
exit: 0 적용/이미적용  ·  3 리터럴 부재(드리프트)  ·  4 인자/파일 오류
"""
import re
import sys

OLD = 'var MIN_READER_WIDTH = 960;'
NEW = ('var MIN_READER_WIDTH = Math.min(1440, '
       'Math.max(960, Math.round(window.innerWidth * 0.80)));')


def build_svg(html: str) -> str:
    styles = re.findall(r'<style[^>]*>(.*?)</style>', html, re.S)
    if len(styles) != 1:
        raise ValueError(f'expected exactly 1 <style> block, got {len(styles)}')
    m = re.search(r'<svg\b.*?</svg>', html, re.S)
    if not m:
        raise ValueError('no <svg> block found')
    svg = m.group(0).replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" ', 1)
    tag_end = svg.index('>') + 1
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            + svg[:tag_end] + '<style><![CDATA[\n' + styles[0] + '\n]]></style>'
            + svg[tag_end:])


def process(path: str, check_only: bool) -> int:
    try:
        html = open(path, encoding='utf-8').read()
    except OSError as exc:
        print(f'ERROR  {path}: {exc}', file=sys.stderr)
        return 4
    has_old, has_new = OLD in html, NEW in html
    if not has_old and not has_new:
        print(f'DRIFT  {path}: neither the original nor the patched reader-width '
              f'literal is present — archify version drift, patch NOT applied',
              file=sys.stderr)
        return 3
    if check_only:
        print(f'{"PATCHED" if has_new else "UNPATCHED"}  {path}')
        return 0
    patched = html.replace(OLD, NEW) if has_old else html
    svg_path = re.sub(r'\.html$', '.svg', path)
    # 쓰기 전에 둘 다 만들어 둔다 — 중간에 실패하면 «반쯤 적용된 트리»가 남고,
    # 특히 open(...,'w') 은 예외가 나기 전에 이미 대상을 0바이트로 잘라 놓는다(L6 가 잡았다).
    try:
        svg = build_svg(patched)
    except ValueError as exc:
        print(f'ERROR  {svg_path}: {exc} — nothing written', file=sys.stderr)
        return 3
    if has_old:
        open(path, 'w', encoding='utf-8').write(patched)
        print(f'PATCH  {path}: reader-width floor -> viewport-proportional')
    else:
        print(f'SKIP   {path}: already patched (idempotent)')
    open(svg_path, 'w', encoding='utf-8').write(svg)
    print(f'SVG    {svg_path}')
    return 0


def main(argv):
    check_only = '--check' in argv
    files = [a for a in argv if not a.startswith('--')]
    if not files:
        print(__doc__, file=sys.stderr)
        return 4
    worst = 0
    for path in files:
        worst = max(worst, process(path, check_only))
    return worst


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
