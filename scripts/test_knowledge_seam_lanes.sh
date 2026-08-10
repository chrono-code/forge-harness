#!/usr/bin/env bash
# test_knowledge_seam_lanes.sh — knowledge_seam_check.sh 의 known-pair 레인 (BLOCK/PASS 대칭).
# 적대 2라운드(같은 계열 M4·S5·R5 + 교차 계열 codex M6·S3·R2)의 결함이 레인으로 앵커됨.
# exit 계약: 0=PASS · 1=FAIL · 3=UNMEASURED · 4=READ-FAIL
set -uo pipefail
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/knowledge_seam_check.sh"
[ -f "$SCRIPT" ] || { echo "FATAL: $SCRIPT 없음"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; failn=0
_lane(){ # $1 이름 $2 기대exit $3 요구패턴 $4 금지패턴 $5 인자
  out=$(bash "$SCRIPT" "$5" 2>&1); rc=$?
  ok=1
  [ "$rc" -eq "$2" ] || ok=0
  if [ -n "$3" ]; then grep -q -- "$3" <<<"$out" || ok=0; fi
  if [ -n "$4" ]; then grep -q -- "$4" <<<"$out" && ok=0; fi
  if [ "$ok" -eq 1 ]; then echo "PASS  $1"; pass=$((pass+1)); else
    echo "FAIL  $1 (rc=$rc 기대=$2)"; sed 's/^/      /' <<<"$out" | head -6; failn=$((failn+1)); fi
}
mk_page(){ printf -- '---\ndescription: %s\ndate: 2026-08-01\n---\nbody\n' "$2" > "$1"; }
mk_seam(){ printf -- '---\nadoption_path: conform\nsynced_at: 2026-08-01\n---\n' > "$1"; }

# ── 기본 대칭 ──
_lane "L1 부재→UNMEASURED·rc3"      3 "UNMEASURED" "" "$T/nope"
mkdir -p "$T/empty"
_lane "L2 빈슬롯→UNMEASURED·rc3"    3 "UNMEASURED" "^PASS  K3" "$T/empty"
mkdir -p "$T/good"; printf '# INDEX\n- a.md — 설명\n' > "$T/good/INDEX.md"
mk_page "$T/good/a.md" "페이지 a"; mk_seam "$T/good/SEAM.md"
_lane "L3 완전만족→PASS"            0 "-- seam check: PASS --" "" "$T/good"
mkdir -p "$T/noidx"; mk_page "$T/noidx/a.md" "a"; mk_seam "$T/noidx/SEAM.md"
_lane "L4 인덱스부재→FAIL"          1 "K2 진입 인덱스 부재" "" "$T/noidx"
mkdir -p "$T/nodesc"; printf '# INDEX\n' > "$T/nodesc/INDEX.md"
printf -- '---\ndate: 2026-08-01\n---\nbody\n' > "$T/nodesc/b.md"; mk_seam "$T/nodesc/SEAM.md"
_lane "L5 설명누락→FAIL"            1 "K3 설명 누락" "" "$T/nodesc"
mkdir -p "$T/nodate"; printf '# INDEX\n' > "$T/nodate/INDEX.md"
printf -- '---\ndescription: c\n---\nbody\n' > "$T/nodate/c.md"; mk_seam "$T/nodate/SEAM.md"
_lane "L6 날짜누락→WARN·비차단"      0 "WARN  K3-d 날짜 누락" "" "$T/nodate"
mkdir -p "$T/noseam"; printf '# INDEX\n' > "$T/noseam/INDEX.md"; mk_page "$T/noseam/d.md" "d"
_lane "L7 SEAM부재→FAIL"            1 "SEAM.md 부재" "" "$T/noseam"
mkdir -p "$T/badpath"; printf '# INDEX\n' > "$T/badpath/INDEX.md"; mk_page "$T/badpath/e.md" "e"
printf -- '---\nadoption_path: yolo\nsynced_at: 2026-08-01\n---\n' > "$T/badpath/SEAM.md"
_lane "L8 불법값→FAIL"              1 "유효한 adoption_path 없음" "" "$T/badpath"
mkdir -p "$T/longfm"; printf '# INDEX\n' > "$T/longfm/INDEX.md"
{ echo '---'; for i in $(seq 1 14); do echo "meta$i: v"; done; echo 'description: 깊은 설명'; echo 'date: 2026-08-01'; echo '---'; echo body; } > "$T/longfm/f.md"
mk_seam "$T/longfm/SEAM.md"
_lane "L9 긴frontmatter desc+date→PASS" 0 "K3-d 최종갱신일 1건 전건 존재" "no-desc" "$T/longfm"
mkdir -p "$T/hollow"; printf '# INDEX\n' > "$T/hollow/INDEX.md"; mk_seam "$T/hollow/SEAM.md"
_lane "L10 보일러플레이트만→UNMEASURED·rc3" 3 "내용 페이지 0건" "-- seam check: PASS --" "$T/hollow"
mkdir -p "$T/fb"; printf '# INDEX\n- g.md — 지도 문서 설명줄\n' > "$T/fb/INDEX.md"
printf 'no frontmatter body\n' > "$T/fb/g.md"; mk_seam "$T/fb/SEAM.md"
_lane "L11 폴백 설명줄→PASS(desc축)"  0 "K3 설명 1건 전건 존재" "no-desc" "$T/fb"
mkdir -p "$T/sub"; printf '# INDEX\n- data.md — 진짜 항목\n' > "$T/sub/INDEX.md"
printf 'no frontmatter\n' > "$T/sub/a.md"; mk_page "$T/sub/data.md" "데이터"; mk_seam "$T/sub/SEAM.md"
_lane "L12 substring 오탐→FAIL"     1 "K3 설명 누락" "" "$T/sub"
# ── READ-FAIL 축 ──
if [ "$(id -u)" != "0" ]; then
  mkdir -p "$T/locked"; mk_page "$T/locked/h.md" "h"; chmod 000 "$T/locked"
  _lane "L13 권한불가(dir)→READ-FAIL·rc4" 4 "READ-FAIL" "UNMEASURED" "$T/locked"
  chmod 755 "$T/locked"
else
  echo "SKIP  L13 (root 실행 — 권한 레인 무의미)"
fi
mk_page "$T/notadir.md" "x"
_lane "L17 파일을 dir 로 전달→READ-FAIL·rc4" 4 "READ-FAIL" "" "$T/notadir.md"
if [ "$(id -u)" != "0" ]; then
  mkdir -p "$T/subun/inner"; printf '# INDEX\n' > "$T/subun/INDEX.md"
  mk_page "$T/subun/ok.md" "ok"; mk_page "$T/subun/inner/bad.md" "bad"; mk_seam "$T/subun/SEAM.md"
  chmod 000 "$T/subun/inner/bad.md"
  _lane "L18 하위 unreadable 파일→READ-FAIL·rc4" 4 "unreadable" "-- seam check: PASS --" "$T/subun"
  chmod 644 "$T/subun/inner/bad.md"
else
  echo "SKIP  L18 (root)"
fi
# ── 표기/경계 축 ──
mkdir -p "$T/lower"; printf '# idx\n' > "$T/lower/index.md"; mk_page "$T/lower/i.md" "i"; mk_seam "$T/lower/SEAM.md"
_lane "L14 소문자 index.md→PASS"    0 "K2 인덱스 존재" "K2 진입 인덱스 부재" "$T/lower"
mkdir -p "$T/prefix"; printf '# INDEX\n' > "$T/prefix/INDEX.md"; mk_page "$T/prefix/j.md" "j"
printf -- '---\nadoption_path: forked-away-from-contract\nsynced_at: 2026-08-01\n---\n' > "$T/prefix/SEAM.md"
_lane "L15 prefix 위조→FAIL"        1 "유효한 adoption_path 없음" "" "$T/prefix"
_lane "L16 trailing slash→PASS"     0 "-- seam check: PASS --" "" "$T/good/"
# ── codex 라운드 앵커 ──
mkdir -p "$T/nested/topics"; printf '# INDEX\n- topics/README.md — 섹션 개요문서 설명\n' > "$T/nested/INDEX.md"
printf 'no frontmatter\n' > "$T/nested/topics/README.md"; mk_seam "$T/nested/SEAM.md"
_lane "L19 하위 README=내용페이지(K3 대상·인덱스 설명줄로 충족)→PASS" 0 "K3 설명 1건 전건 존재" "" "$T/nested"
mkdir -p "$T/nested2/topics"; printf '# INDEX\n' > "$T/nested2/INDEX.md"
printf 'no frontmatter\n' > "$T/nested2/topics/INDEX.md"; mk_page "$T/nested2/z.md" "z"; mk_seam "$T/nested2/SEAM.md"
_lane "L20 하위 INDEX 무설명→FAIL(제외 과광 회귀)" 1 "K3 설명 누락" "" "$T/nested2"
mkdir -p "$T/bodyseam"; printf '# INDEX\n' > "$T/bodyseam/INDEX.md"; mk_page "$T/bodyseam/k.md" "k"
printf -- '# 본문\nadoption_path: conform\nsynced_at: 2026-08-01\n' > "$T/bodyseam/SEAM.md"
_lane "L21 본문 기재 SEAM→FAIL(frontmatter 요구)" 1 "frontmatter" "" "$T/bodyseam"
mkdir -p "$T/nosync"; printf '# INDEX\n' > "$T/nosync/INDEX.md"; mk_page "$T/nosync/l.md" "l"
printf -- '---\nadoption_path: conform\n---\n' > "$T/nosync/SEAM.md"
_lane "L22 synced_at 부재→FAIL(mandatory)" 1 "synced_at" "" "$T/nosync"
mkdir -p "$T/emptyval"; printf '# INDEX\n' > "$T/emptyval/INDEX.md"
printf -- '---\ndescription:\ndate: 2026-08-01\n---\nbody\n' > "$T/emptyval/m.md"; mk_seam "$T/emptyval/SEAM.md"
_lane "L23 빈 description 값→FAIL" 1 "K3 설명 누락" "" "$T/emptyval"
mkdir -p "$T/deep/docs"; printf '# INDEX\n- docs/a+b.md — 중첩경로와 regex 문자 설명\n' > "$T/deep/INDEX.md"
printf 'no frontmatter\n' > "$T/deep/docs/a+b.md"; mk_seam "$T/deep/SEAM.md"
_lane "L24 중첩경로+regex문자 폴백→PASS" 0 "K3 설명 1건 전건 존재" "no-desc" "$T/deep"
mkdir -p "$T/.hidden_parent/org"; printf '# INDEX\n- n.md — 숨김 조상 아래 정상 페이지\n' > "$T/.hidden_parent/org/INDEX.md"
mk_page "$T/.hidden_parent/org/n.md" "n"; mk_seam "$T/.hidden_parent/org/SEAM.md"
_lane "L25 숨김 조상 경로→PASS(필터 오발동 회귀)" 0 "-- seam check: PASS --" "UNMEASURED" "$T/.hidden_parent/org"

# ── codex 3라운드 앵커 ──
mkdir -p "$T/unclosed"; printf '# INDEX\n' > "$T/unclosed/INDEX.md"
printf -- '---\ndescription: 미닫힘 설명\ndate: 2026-08-01\n' > "$T/unclosed/o.md"; mk_seam "$T/unclosed/SEAM.md"
_lane "L26 미닫힘 frontmatter→FAIL(불인정)" 1 "K3 설명 누락" "" "$T/unclosed"
mkdir -p "$T/sfx/docs"; printf '# INDEX\n- docs/a.md — 하위 문서 설명\n' > "$T/sfx/INDEX.md"
printf 'no frontmatter\n' > "$T/sfx/a.md"
printf 'no frontmatter\n' > "$T/sfx/docs/a.md"; mk_seam "$T/sfx/SEAM.md"
_lane "L27 suffix 경로 오인정 차단→FAIL(루트 a.md 는 미설명)" 1 "K3 설명 누락 1/" "" "$T/sfx"
if [ "$(id -u)" != "0" ]; then
  mkdir -p "$T/lockidx"; printf '# INDEX\n' > "$T/lockidx/INDEX.md"; mk_page "$T/lockidx/p.md" "p"; mk_seam "$T/lockidx/SEAM.md"
  chmod 000 "$T/lockidx/INDEX.md"
  _lane "L28 루트 인덱스 unreadable→READ-FAIL·rc4" 4 "READ-FAIL" "-- seam check: PASS --" "$T/lockidx"
  chmod 644 "$T/lockidx/INDEX.md"
else
  echo "SKIP  L28 (root)"
fi
mkdir -p "$T/badsync"; printf '# INDEX\n' > "$T/badsync/INDEX.md"; mk_page "$T/badsync/q.md" "q"
printf -- '---\nadoption_path: conform\nsynced_at: 2026-08-01BROKEN\n---\n' > "$T/badsync/SEAM.md"
_lane "L29 synced_at 쓰레기 접미→FAIL" 1 "synced_at" "" "$T/badsync"
mkdir -p "$T/nullval"; printf '# INDEX\n' > "$T/nullval/INDEX.md"
printf -- '---\ndescription: null\ndate: 2026-08-01\n---\nbody\n' > "$T/nullval/r.md"; mk_seam "$T/nullval/SEAM.md"
_lane "L30 description null→FAIL" 1 "K3 설명 누락" "" "$T/nullval"

# ── codex 4라운드 앵커 ──
mkdir -p "$T/cmtval"; printf '# INDEX\n' > "$T/cmtval/INDEX.md"
printf -- '---\ndescription: "" # TODO\ndate: 2026-08-01\n---\nbody\n' > "$T/cmtval/s.md"; mk_seam "$T/cmtval/SEAM.md"
_lane "L31 quoted-empty+주석→FAIL" 1 "K3 설명 누락" "" "$T/cmtval"
mkdir -p "$T/blockscalar"; printf '# INDEX\n' > "$T/blockscalar/INDEX.md"
printf -- '---\ndescription: |-\ndate: 2026-08-01\n---\nbody\n' > "$T/blockscalar/t.md"; mk_seam "$T/blockscalar/SEAM.md"
_lane "L32 block scalar 머리만→FAIL" 1 "K3 설명 누락" "" "$T/blockscalar"
mkdir -p "$T/prefixname"; printf '# INDEX\n- a.md-bak — 백업 문서 설명\n' > "$T/prefixname/INDEX.md"
printf 'no frontmatter\n' > "$T/prefixname/a.md"; mk_page "$T/prefixname/a.md-bak.md" "bak"; mk_seam "$T/prefixname/SEAM.md"
_lane "L33 prefix 파일명(a.md-bak) 오인정 차단→FAIL" 1 "K3 설명 누락" "" "$T/prefixname"
# ── codex 5라운드 앵커 ──
mkdir -p "$T/bsind"; printf '# INDEX\n' > "$T/bsind/INDEX.md"
printf -- '---\ndescription: |2\ndate: 2026-08-01\n---\nbody\n' > "$T/bsind/u.md"; mk_seam "$T/bsind/SEAM.md"
_lane "L34 block scalar indicator(|2)→FAIL" 1 "K3 설명 누락" "" "$T/bsind"

echo "== lanes: $pass pass / $failn fail =="
[ "$failn" -eq 0 ] || exit 1
