#!/usr/bin/env bash
# test_preprep_diagram_lanes.sh — L12 diagram 레인 + diagram_from_json.py 거부 경로의 known-pair.
#
# 재는 것:
#   K1 known-negative  영수증·지문·validate·폭·viewBox·pad 전부 맞으면 findings 0
#   K2 stale          JSON 을 한 글자 고치면 «지문 다름» 1건을 이름으로 짚나
#   K3 resolution     PNG 실제 폭(IHDR)이 하한 미달이면 1건 — 영수증 자기신고(png_size)가 아니라 헤더를 읽나
#   K4 viewbox        viewBox 폭 > 상한이면 1건(글자 배율)
#   K5 unmeasured     영수증 없는 PNG 는 findings 0 + UNMEASURED 노트(0 으로 안 접나)
#   K6 not-configured diagram_source 표면이 없으면 NOT_CONFIGURED(통과 아님)
#   K7 refuse         diagram_from_json.py 가 validate 실패 JSON 을 **굽지 않나** — archify 는 스텁으로 대체
#                     (실물 archify·Chrome 없이 도는 레인이어야 CI 에서 앵커다)
# 🟥 archify·Chrome 이 없어도 돌아야 한다 — 그래서 K7 은 스텁 archify(ok:false)로 «거부»만 잰다.
#    «굽힘» 쪽 실사용은 tracks-meta/dispatch/2026-09-05_archify-preprep/REPORT.md 가 기록한다.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$HERE/plugins/fh-commons/skills/preprep"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }
command -v python3 >/dev/null 2>&1 || { echo "  ⚠️  UNMEASURED — python3 unavailable (not a pass)"; echo "diagram lanes: SKIPPED (not passed)"; exit 0; }

out=$(cd "$SKILL" && python3 - <<'PY' 2>&1
import sys, os, json, hashlib, struct, zlib, tempfile, subprocess
sys.path.insert(0, '.')
import lane_diagram as LD
def sha(p): return hashlib.sha256(open(p,'rb').read()).hexdigest()
def png(path, w, h=2):
    # 순수 표준 라이브러리 PNG(회색 1바이트/픽셀) — 폭만 의미 있다
    raw = b''.join(b'\x00' + b'\x80'*w for _ in range(h))
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t+d) & 0xffffffff)
    open(path,'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 0, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
d = tempfile.mkdtemp(prefix='l12_')
spec = os.path.join(d, 'fig.workflow.json'); json.dump({'diagram_type':'workflow','nodes':[{'id':'a','label':'개발'}]}, open(spec,'w'))
def receipt(pngp, **kw):
    r = {'spec_sha256': sha(spec), 'validate': {'ok': True, 'profile': 'showcase'}, 'viewbox_w': 720, 'pad': 0.03, 'png_size': [3840, 2]}
    r.update(kw); json.dump(r, open(pngp[:-4] + '.receipt.json', 'w'))
def run(surfs, extra=None):
    cfg = {'surfaces': surfs, 'diagram': {'min_px': 3840, 'max_viewbox_w': 720, 'min_pad': 0.02}}
    return LD.scan(cfg, d)
R = {}
# K1 negative
p1 = os.path.join(d, 'ok.png'); png(p1, 3840); receipt(p1)
f, n = run([{'id':'fig','path':'fig.workflow.json','kind':'diagram_source','render':'ok.png'}]); R['K1'] = len(f)
# K2 stale: JSON 고침
open(spec,'a').write('\n'); f, n = run([{'id':'fig','path':'fig.workflow.json','kind':'diagram_source','render':'ok.png'}])
R['K2'] = [x[2] for x in f]
receipt(p1)  # 다시 맞춤
# K3 resolution: 영수증은 3840 이라 «말하지만» 실제 헤더는 1000
p3 = os.path.join(d, 'small.png'); png(p3, 1000); receipt(p3, png_size=[3840, 2])
f, n = run([{'id':'fig','path':'fig.workflow.json','kind':'diagram_source','render':'small.png'}]); R['K3'] = [x[2] for x in f]
# K4 viewbox
p4 = os.path.join(d, 'wide.png'); png(p4, 3840); receipt(p4, viewbox_w=1137)
f, n = run([{'id':'fig','path':'fig.workflow.json','kind':'diagram_source','render':'wide.png'}]); R['K4'] = [x[2] for x in f]
# K5 unmeasured (영수증 없음)
p5 = os.path.join(d, 'hand.png'); png(p5, 3840)
f, n = run([{'id':'fig','path':'fig.workflow.json','kind':'diagram_source','render':'hand.png'}]); R['K5'] = {'n': len(f), 'unm': any('UNMEASURED' in s for s in n)}
# K6 not configured
f, n = run([]); R['K6'] = {'n': len(f), 'nc': any('NOT_CONFIGURED' in s for s in n)}
# K7 refuse — 스텁 archify(항상 ok:false) + 가짜 chrome. PNG 가 «안 생겨야» 한다
stub = os.path.join(d, 'archify_stub.mjs'); open(stub,'w').write('console.log(JSON.stringify({ok:false,diagnostics:[{code:"stub/fail",message:"stub"}]}))')
fake_chrome = os.path.join(d, 'chrome'); open(fake_chrome,'w').write('#!/bin/sh\nexit 0\n'); os.chmod(fake_chrome, 0o755)
outp = os.path.join(d, 'refused.png')
import shutil
if shutil.which('node'):
    r = subprocess.run([sys.executable, 'diagram_from_json.py', spec, '--out', outp, '--archify', stub, '--chrome', fake_chrome], capture_output=True, text=True)
    R['K7'] = {'rc': r.returncode, 'png': os.path.exists(outp), 'msg': 'REFUSE' in r.stdout}
else:
    R['K7'] = {'rc': 'NO_NODE'}
print(json.dumps(R, ensure_ascii=False))
PY
); rc=$?
[ $rc -eq 0 ] || { echo "  ❌ INSTRUMENT ERROR — lane_diagram 실행 실패 (rc=$rc): $out"; exit 1; }
g(){ python3 -c "import json,sys;v=json.loads(sys.argv[1]);exec('r=v'+sys.argv[2]);print(r)" "$out" "$1"; }
[ "$(g "['K1']")" = "0" ] && ok "K1 known-negative: 다 맞으면 0건" || ng "K1 오탐 $(g "['K1']")건"
[ "$(g "['K2']")" = "['stale']" ] && ok "K2 stale: JSON 고치면 «stale» 1건을 이름으로" || ng "K2 실패: $(g "['K2']")"
[ "$(g "['K3']")" = "['resolution']" ] && ok "K3 resolution: 영수증이 3840 이라 해도 IHDR 1000 을 잡는다(자기신고 아님)" || ng "K3 실패: $(g "['K3']")"
[ "$(g "['K4']")" = "['viewbox']" ] && ok "K4 viewbox: 1137 > 720 을 잡는다(글자 배율)" || ng "K4 실패: $(g "['K4']")"
[ "$(g "['K5']['n']")" = "0" ] && [ "$(g "['K5']['unm']")" = "True" ] && ok "K5 영수증 없는 손그림 = UNMEASURED(0 아님·통과 아님)" || ng "K5 실패: $(g "['K5']")"
[ "$(g "['K6']['n']")" = "0" ] && [ "$(g "['K6']['nc']")" = "True" ] && ok "K6 표면 없음 = NOT_CONFIGURED" || ng "K6 실패: $(g "['K6']")"
k7=$(g "['K7']")
case "$k7" in
  *NO_NODE*) echo "  ⏭  K7 거부 경로 — node 부재라 UNMEASURED (통과 아님)";;
  *) [ "$(g "['K7']['rc']")" = "1" ] && [ "$(g "['K7']['png']")" = "False" ] && [ "$(g "['K7']['msg']")" = "True" ] && ok "K7 refuse: validate 실패면 exit 1 + PNG 미생성 + REFUSE 표기" || ng "K7 실패: $k7";;
esac
echo "diagram lanes: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
