#!/usr/bin/env python3
"""R1~R5 · P1/P3 self-test — known-pair 계량 + 실물 재현.

exit 0 = 전부 통과 · 1 = 실패 있음 · 2 = 픽스처 생성 불가(python-pptx 부재 등, UNMEASURED)

구성:
  ① known-pair — `fixtures/mk_slide_fixtures.py` 로 R1·R2·R4·R5·P1·P3 를 테스트 시점에 만든다
     (R3 는 예외 — 실물 구조 2장을 줄인 `fixtures/fixture_R3_{positive,negative}.pptx` 를 쓴다.
     선두 줄 판별이 절대좌표·srgbClr 런 구조에 기대므로, 검출기 가정대로 «생성»한 픽스처는
     검출기 자신을 검증 못 한다 — 자기참조. `tracks-meta` 원장이 지목한 방침)
  ② --baseline 델타 모드 — 편집 전/후 한 쌍에서 새 어긋남 1건만 잡히는지
  ③ 실물 재현 — 실제 백업 pptx(환경변수 PREPREP_REAL_CORPUS 가 가리키는 디렉터리, 있을 때만)에 돌려 원장이 인용한 실사고 4+1건이
     그대로 뜨는지 확인한다. 그 코퍼스가 없는 머신에서는 SKIP(«통과»로 세지 않는다).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'fixtures'))

PASS, FAIL, SKIP = 0, 0, 0


def ok(msg):
    global PASS
    PASS += 1
    print('  ✅', msg)


def ng(msg):
    global FAIL
    FAIL += 1
    print('  ❌', msg)


def sk(msg):
    global SKIP
    SKIP += 1
    print('  ⏭ ', msg, '— SKIPPED (PASS 아님)')


def codes_of(deck_path, LSR):
    deck = LSR.Deck(deck_path)
    F = LSR.analyze(deck)
    return F, {k for k, _, _ in F}


def run_known_pairs(fx_dir):
    print('\n[1] known-pair — R1·R2·R4·R5·P1·P3 (생성 픽스처) + R3 (실물 픽스처)')
    import lane_slide_relations as LSR
    import lane_geometry as LG

    # R1
    _, cp = codes_of(os.path.join(fx_dir, 'r1_pos.pptx'), LSR)
    _, cn = codes_of(os.path.join(fx_dir, 'r1_neg.pptx'), LSR)
    ok('R1 known-positive 검출') if 'R1' in cp else ng(f'R1 known-positive 미검출 ({cp})')
    ok('R1 known-negative 무검출') if 'R1' not in cn else ng(f'R1 known-negative에서 오탐 ({cn})')

    # R2
    _, cp = codes_of(os.path.join(fx_dir, 'r2_pos.pptx'), LSR)
    _, cn = codes_of(os.path.join(fx_dir, 'r2_neg.pptx'), LSR)
    ok('R2 known-positive 검출') if 'R2' in cp else ng(f'R2 known-positive 미검출 ({cp})')
    ok('R2 known-negative 무검출') if 'R2' not in cn else ng(f'R2 known-negative에서 오탐 ({cn})')

    # R3 — 실물 픽스처 (자기참조 회피)
    r3p = os.path.join(HERE, 'fixtures', 'fixture_R3_positive.pptx')
    r3n = os.path.join(HERE, 'fixtures', 'fixture_R3_negative.pptx')
    if os.path.exists(r3p) and os.path.exists(r3n):
        _, cp = codes_of(r3p, LSR)
        _, cn = codes_of(r3n, LSR)
        ok('R3 known-positive(실물 2장) 검출') if 'R3' in cp else ng(f'R3 known-positive 미검출 ({cp})')
        ok('R3 known-negative(실물 2장) 무검출') if 'R3' not in cn else ng(f'R3 known-negative에서 오탐 ({cn})')
    else:
        sk('R3 known-pair — fixture_R3_{positive,negative}.pptx 없음')

    # R4
    Fp, cp = codes_of(os.path.join(fx_dir, 'r4_pos.pptx'), LSR)
    Fn, cn = codes_of(os.path.join(fx_dir, 'r4_neg.pptx'), LSR)
    ok('R4 known-positive 검출(아웃라이어 500자)') if 'R4' in cp else ng(f'R4 known-positive 미검출 ({cp})')
    ok('R4 known-negative 무검출(동값 분포)') if 'R4' not in cn else ng(f'R4 known-negative에서 오탐 ({cn})')

    # R5
    Fp, cp = codes_of(os.path.join(fx_dir, 'r5_pos.pptx'), LSR)
    Fn, cn = codes_of(os.path.join(fx_dir, 'r5_neg.pptx'), LSR)
    ok('R5 known-positive 검출(비율 30.0)') if 'R5' in cp else ng(f'R5 known-positive 미검출 ({cp})')
    ok('R5 known-negative 무검출(동일 비율)') if 'R5' not in cn else ng(f'R5 known-negative에서 오탐 ({cn})')

    # P1 — 3팔(임계 안 소폭 이동은 뜼다 · 임계 밖 큰 이동은 안 뜼다 · 무이동은 안 뜼다)
    lines, compared = LG.collect_lines(os.path.join(fx_dir, 'p1.pptx'), 200000, 63500)
    p1_lines = [l for l in lines if 'gate_bar' in l]
    ok(f'P1 대조된 도형-쌍 {compared} > 0 (비교 안함 아님)') if compared > 0 else ng('P1 compared=0 — UNMEASURED')
    ok(f'P1 후보 정확히 1건(임계 안 이동만)') if len(p1_lines) == 1 else ng(f'P1 후보 {len(p1_lines)}건 (want 1) — {p1_lines}')
    if p1_lines:
        ok('P1 유일 후보가 정확히 (1→2p) 소폭 이동 — 큰 이동(2→3p)·무이동(3→4p)은 안 뜬다') \
            if '1p→2' in p1_lines[0].replace(' ', '') else ng(f'P1 후보가 엉뚱한 쌍을 가리킨다 {p1_lines}')

    # P3
    lines3, _ = LG.collect_lines(os.path.join(fx_dir, 'p3.pptx'), 200000, 63500)
    p3_lines = [l for l in lines3 if 'stub' in l]
    ok('P3 후보 정확히 1건(임계 안 틀/겹침만)') if len(p3_lines) == 1 else ng(f'P3 후보 {len(p3_lines)}건 (want 1) — {p3_lines}')


def run_baseline_delta(fx_dir):
    print('\n[2] --baseline 델타 모드 — 편집 전/후 한 쌍')
    import lane_geometry as LG
    new, gone, cmp_b, cmp_c = LG.delta(os.path.join(fx_dir, 'geo_base.pptx'),
                                        os.path.join(fx_dir, 'geo_edited.pptx'), 200000, 63500)
    ok('델타 새 어긋남 정확히 1건') if len(new) == 1 else ng(f'델타 새 어긋남 {len(new)}건 (want 1)')
    ok('델타 사라진 어긋남 0건(깨끗한 기준본)') if len(gone) == 0 else ng(f'델타 사라진 어긋남 {len(gone)}건 (want 0)')
    ok(f'기준본 대조 {cmp_b} > 0 · 현재본 대조 {cmp_c} > 0') if cmp_b > 0 and cmp_c > 0 \
        else ng(f'기준본/현재본 대조 0 있음 — UNMEASURED (cmp_b={cmp_b}, cmp_c={cmp_c})')
    # scan(cfg, root) 래퍼로도 동일하게 도는지 확인 (preprep.py 가 실제로 부르는 경로)
    cfg = {'surfaces_by_id': {'built_deck': {'path': os.path.join(fx_dir, 'geo_edited.pptx')}},
           'geometry': {'baseline': os.path.join(fx_dir, 'geo_base.pptx')}}
    fP, nP = LG.scan(cfg, '.')
    ok('scan(cfg, root) 래퍼가 델타 모드로 도고 새 어긋남 1건을 notes 에 낸다') \
        if any('새 어긋남 1건' in n for n in nP) else ng(f'scan() 델타 출력 이상 — {nP}')


REAL_BASE = os.environ.get('PREPREP_REAL_CORPUS', '')  # 기본값 없음 — 다른 머신에서 거짓 SKIP 방지(SKIP != PASS)
REAL_TARGETS = [
    ('ifkakao26_slides_v1.3_pre-engine-strip_20260904_210857.pptx', 'R1', 40,
     '선두 줄이 «그러나»로 뒤집는데'),
    ('ifkakao26_slides_v1.3_pre-40p_20260904_213452.pptx', 'R2', 41,
     '«이 셋/세 가지»라 부르는데 번호가 없다'),
    ('ifkakao26_slides_v1.3_pre-38trim_20260904_210428.pptx', 'R4', 38,
     '화면 250자'),
    ('ifkakao26_slides_v1.3_pre-40p_20260904_213452.pptx', 'R5', 112,
     '29.2자/초'),
]


def run_real_corpus():
    print('\n[3] 실물 재현 (PREPREP_REAL_CORPUS 백업, 있을 때만) — 원장이 인용한 실사고 4+1건')
    if not os.path.isdir(REAL_BASE):
        sk(f'실물 코퍼스 미지정/미존재({REAL_BASE or "PREPREP_REAL_CORPUS unset"}) — SKIP, 통과 아님')
        return
    import lane_slide_relations as LSR
    import lane_geometry as LG
    for fname, code, want_page, want_sub in REAL_TARGETS:
        p = os.path.join(REAL_BASE, fname)
        if not os.path.exists(p):
            sk(f'{fname} 없음 — 재현 건너뜀')
            continue
        deck = LSR.Deck(p)
        F = LSR.analyze(deck)
        hit = [x for x in F if x[0] == code and abs(x[1] - want_page) <= 1 and want_sub in x[2]]
        ok(f'{code} 실물 재현 — {fname} 약 {want_page}p — {hit[0][2][:60] if hit else ""}') \
            if hit else ng(f'{code} 실물 미재현 — {fname}')

    # P1/P3 36p (보너스 확인 — 원장이 명시적으로 요구한 4건에는 없지만 신호 자체의 원적 사건)
    align36 = os.path.join(REAL_BASE, 'ifkakao26_slides_v1.3_pre-align36_222442.pptx')
    if os.path.exists(align36):
        lines, compared = LG.collect_lines(align36, 200000, 63500)
        hit_p1 = any('s5017' in l and '35000' in l and '35p' in l.replace(' ', '') for l in lines)
        hit_p3 = any('s5016' in l and 's5017' in l and '35000' in l for l in lines)
        ok('P1 실물 재현 — 35p→36p s5017 x -35,000') if hit_p1 else ng('P1 실물 미재현')
        ok('P3 실물 재현 — 36p s5016→s5017 겹침 35,000') if hit_p3 else ng('P3 실물 미재현')
    else:
        sk('ifkakao26_slides_v1.3_pre-align36_222442.pptx 없음 — P1/P3 보너스 재현 건너뜀')


def main():
    try:
        import mk_slide_fixtures
    except ImportError as e:
        print(f'❌ python-pptx 또는 픽스처 모듈 부재 — UNMEASURED: {e}')
        return 2
    import tempfile
    fx_dir = tempfile.mkdtemp(prefix='preprep_lanes_rp_')
    mk_slide_fixtures.build_all(fx_dir)
    print(f'픽스처 생성: {fx_dir}')

    run_known_pairs(fx_dir)
    run_baseline_delta(fx_dir)
    run_real_corpus()

    print(f'\n결과: {PASS} passed · {FAIL} failed · {SKIP} skipped (skip != pass)')
    return 1 if FAIL else 0


if __name__ == '__main__':
    sys.exit(main())
