#!/usr/bin/env bash
# knowledge_seam_check.sh — 기계 판정: knowledge/{org}/ 이 seam 계약(K1·K2·K3)을 만족하는가.
# 정본: knowledge/shared/rules/knowledge_layer_seam.md
# provenance: pmh-dev@cbe3932 역수확(2026-08-10). FH 이식 시 같은 계열 적대 라운드(M4·S5·R5)
#   + 교차 계열 codex 라운드(M6·S3·R2)가 잡은 결함 전건 수리 — 상세는 PR 캡슐.
#
# 파서 경계(명명된 잔여): frontmatter 는 제한 awk 파서다 — YAML 전체 의미론(컬렉션 []·{} ·
#   공백만 든 quoted string · 앵커/별칭)은 범위 밖. find 는 line-based 라 개행 포함 파일명 미지원.
#   인덱스 폴백은 공백-비포함 파일명 전제(공백 포함 파일명은 개행과 같은 족의 범위 밖 — frontmatter 경로 사용).
#   수집의 TOCTOU(cd 후 상태 변화)는 stderr 기반 승격까지만. 여기 명명하고 더 조이지 않는다.
# Exit 계약 (typed — stdout prose 가 아니라 이 코드가 판정이다):
#   0 = PASS          1 = FAIL(계약 위반)      2 = usage 오류
#   3 = UNMEASURED    4 = READ-FAIL(경로/권한/수집 실패 — §6 «실패로 보고», 부재로 위장 금지)
#   호출자는 3·4 를 명시 처리한다 — 0/비0 이분법에서 3·4 는 FAIL 쪽으로 떨어진다(안전 방향).
# Usage: bash scripts/knowledge_seam_check.sh <org-dir>
set -uo pipefail
DIR="${1:-}"
[ -z "$DIR" ] && { echo "usage: $0 <org-dir>"; exit 2; }
DIR="${DIR%/}"   # trailing slash 로 판정이 갈리지 않게 정규화

fail=0
_no(){ echo "FAIL  $1"; fail=1; }
_ok(){ echo "PASS  $1"; }
_warn(){ echo "WARN  $1"; }
_unm(){ echo "UNMEASURED  $1"; }

if [ ! -e "$DIR" ]; then
  _unm "K1: $DIR 부재 — '맥락 없음'이지 '위반'이 아니다(§1 빈 슬롯 규약)."
  echo "-- seam check: UNMEASURED --"; exit 3
fi
if [ ! -d "$DIR" ] || [ ! -r "$DIR" ] || [ ! -x "$DIR" ]; then
  echo "READ-FAIL  $DIR 접근 불가(비디렉터리/권한) — §6: 조용히 빈 결과로 진행하지 않는다."
  echo "-- seam check: READ-FAIL --"; exit 4
fi

# 잔여(정책 선택, R): 숨김 하위 트리는 -prune 하지 않는다 — 그 안의 권한 오류도 READ-FAIL 로
# 승격된다(무시 대상의 오류가 판정을 멈추는 쪽 = 보수 방향 선택).
# 파일 수집 — $DIR 안에서 상대경로로 (숨김 조상 경로가 '*/.*' 필터를 오발동시키지 않게),
# find 의 실패(stderr)는 삼키지 않고 READ-FAIL 로 승격한다(§6).
FIND_ERR=$(mktemp); trap 'rm -f "$FIND_ERR"' EXIT
MD_LIST=$(cd "$DIR" && find . -type f -name '*.md' -not -path '*/.*' 2>"$FIND_ERR" | sed 's|^\./||')
if [ -s "$FIND_ERR" ]; then
  echo "READ-FAIL  파일 수집 실패: $(head -1 "$FIND_ERR") — §6: 실패는 부재가 아니다."
  echo "-- seam check: READ-FAIL --"; exit 4
fi
MD_COUNT=$(printf '%s\n' "$MD_LIST" | grep -c . || true)
if [ "$MD_COUNT" -eq 0 ]; then
  _unm "K1: $DIR 에 마크다운 0건 — 빈 슬롯. K2/K3 는 검사 대상이 없어 UNMEASURED(공허 PASS 금지)."
  echo "-- seam check: UNMEASURED --"; exit 3
fi
_ok "K1 마크다운 ${MD_COUNT}건"

# 진입 인덱스 — 후보 4종. 이 목록은 계약 §0/K2·Step 2-O 와 동일해야 한다(3표면 정합).
IDX_BASE=""
for c in INDEX.md index.md README.md readme.md; do
  [ -f "$DIR/$c" ] && { IDX_BASE="$c"; break; }
done
IDX=""
if [ -z "$IDX_BASE" ]; then
  _no "K2 진입 인덱스 부재 ($DIR/INDEX.md·index.md·README.md·readme.md 중 하나)"
else
  IDX="$DIR/$IDX_BASE"
  if [ ! -r "$IDX" ]; then
    echo "READ-FAIL  진입 인덱스 읽기 불가: $IDX — §6: 실패는 부재/통과로 위장하지 않는다."
    echo "-- seam check: READ-FAIL --"; exit 4
  fi
  L=$(wc -l < "$IDX" | tr -d ' '); L=${L:-0}
  C=$(wc -c < "$IDX" | tr -d ' '); C=${C:-0}
  _ok "K2 인덱스 존재: $IDX"
  # ⚠️ 크기는 보고만 한다(원본의 '≤200줄'은 유도 없는 임계였다 — UNCALIBRATED 이력 보존).
  # 단위 주의: wc -c = 바이트(자수 아님 — 한글 3바이트/자라 토큰 추정 과대 가능).
  echo "UNCALIBRATED  K2-c 인덱스 크기 ${L}줄 / ${C}바이트 (≈$((C/2100))k 토큰 추정, 한글 과대 가능) — 판정 근거 아님."
fi

# frontmatter 파서 — 첫 ---/둘째 --- 사이에서 «키: 비어있지 않은 값» (빈 값은 보유가 아니다)
_fm_has(){ # $1 파일 $2 키 정규식(alternation 허용) — 닫힌 frontmatter 안의 비어있지 않은 값만 인정
  # ⚠️ awk 의 exit 는 END 로 점프하고 END 의 exit 가 상태를 덮어쓴다 — 그래서 판정은 END 한 곳에서만.
  awk -v key="$2" '
    BEGIN{q=sprintf("%c",39)}
    NR==1 && $0!="---"{bad=1; exit}
    /^---$/{n++; if(n==2){closed=1; exit} next}
    n==1 && $0 ~ "^("key"):"{
      val=$0; sub("^[^:]*:[[:space:]]*","",val)
      sub("[[:space:]]+#.*$","",val)            # YAML inline comment 제거 후 판정
      sub("[[:space:]]*$","",val)
      if (val == "") next
      if (val == "\"\"" || val == q q) next    # quoted-empty
      if (val == "null" || val == "~") next
      if (val ~ /^[|>][0-9+-]*$/) next          # block scalar 머리만 있는 것(|,|-,|2,|+2,>-,>2- 등 indicator 변형 포함)
      found=1
    }
    END{exit (!bad && closed && found)?0:1}' "$1" 2>/dev/null
}
# 인덱스 폴백 — 고정문자열 매치 + 경계 문자 + 설명 잔여 요구 (regex 합성 금지: ERE/BRE 혼합 사고 차단)
_idx_desc(){ # $1 상대경로  — IDX 전역 사용. 성공=0
  [ -n "$IDX" ] || return 1
  local line pre post restc
  while IFS= read -r line; do
    case "$line" in *"$1"*) ;; *) continue;; esac
    pre="${line%%"$1"*}"; post="${line#*"$1"}"
    # "/" 는 경계가 아니다 — docs/a.md 줄이 루트 a.md 로 오인정되는 suffix 매치 차단
    case "${pre: -1}" in ""|" "|"("|'`') ;; *) continue;; esac
    # 후행 경계는 «끝/공백/백틱/닫는괄호»만 — -,:,, 는 파일명 연속 문자일 수 있다(a.md-bak 오인정 차단)
    case "${post:0:1}" in ""|" "|'`'|")") ;; *) continue;; esac
    restc=$(printf '%s' "$post" | tr -d ' `—:,)-' | wc -c | tr -d ' ')
    [ "$restc" -gt 2 ] && return 0
  done < <(grep -F -- "$1" "$IDX" 2>/dev/null)
  return 1
}

MISS_D=0; MISS_DATE=0; CHECKED=0; HAS_RA=0; READ_MISS=0
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  # 제외는 «루트의» 진입 인덱스와 SEAM.md 만 — 하위 디렉터리의 동명 파일은 내용 페이지다(K3 대상).
  # 비교는 소문자 정규화: 대소문자 무시 FS(macOS)에선 [ -f INDEX.md ] 가 index.md 에 매치돼
  # IDX_BASE 표기와 find 실명이 갈릴 수 있다(레인 L14 가 잡은 실측).
  rel_lc=$(printf '%s' "$rel" | tr 'A-Z' 'a-z')
  [ -n "$IDX_BASE" ] && [ "$rel_lc" = "$(printf '%s' "$IDX_BASE" | tr 'A-Z' 'a-z')" ] && continue
  [ "$rel_lc" = "seam.md" ] && continue
  f="$DIR/$rel"
  if [ ! -r "$f" ]; then READ_MISS=$((READ_MISS+1)); echo "      unreadable: $f"; continue; fi
  CHECKED=$((CHECKED+1))
  has_desc=0
  _fm_has "$f" "description" && has_desc=1
  [ "$has_desc" -eq 0 ] && _idx_desc "$rel" && has_desc=1
  if [ "$has_desc" -eq 0 ]; then
    MISS_D=$((MISS_D+1)); [ "$MISS_D" -le 5 ] && echo "      no-desc: $f"
  fi
  _fm_has "$f" "date|updated|last_updated" || MISS_DATE=$((MISS_DATE+1))
  _fm_has "$f" "review_after" && HAS_RA=$((HAS_RA+1))
done <<EOF
$MD_LIST
EOF
if [ "$READ_MISS" -gt 0 ]; then
  echo "READ-FAIL  읽기 불가 파일 ${READ_MISS}건 — §6: 실패는 부재/통과로 위장하지 않는다."
  echo "-- seam check: READ-FAIL --"; exit 4
fi

if [ "$CHECKED" -eq 0 ]; then
  _unm "K3: 인덱스 외 내용 페이지 0건 — 검사 대상 없음. 보일러플레이트만으로 PASS 를 사지 않는다."
  echo "-- seam check: UNMEASURED --"; exit 3
fi
[ "$MISS_D" -eq 0 ] && _ok "K3 설명 ${CHECKED}건 전건 존재" || _no "K3 설명 누락 ${MISS_D}/${CHECKED}건"
[ "$MISS_DATE" -eq 0 ] && _ok "K3-d 최종갱신일 ${CHECKED}건 전건 존재" \
  || _warn "K3-d 날짜 누락 ${MISS_DATE}/${CHECKED}건 — stale 판정 불가 → '미상'으로 보고(§6 · 권장 조항이라 비차단)"
echo "INFO  K3-f review_after 보유 ${HAS_RA}/${CHECKED}건 — 0건이면 Step 2-O 는 전건 Partial 상한(Grounded 도달 불가)"

S="$DIR/SEAM.md"
if [ -f "$S" ] && [ ! -r "$S" ]; then
  echo "READ-FAIL  SEAM.md 읽기 불가: $S — §6."
  echo "-- seam check: READ-FAIL --"; exit 4
fi
if [ -f "$S" ]; then
  # Done When 이 «frontmatter 에 기록»이므로 frontmatter 파서로 본다 — 본문/코드블록 기재는 불인정.
  # 닫힘 --- 없는 frontmatter 는 불인정(END 도달 = 미닫힘 = 실패).
  if awk 'NR==1 && $0!="---"{bad=1; exit} /^---$/{n++; if(n==2){closed=1; exit} next} n==1 && $0 ~ "^adoption_path:[[:space:]]*(fork|git-map|export-sync|extract|conform)[[:space:]]*$"{ok=1} END{exit (!bad && closed && ok)?0:1}' "$S"; then
    _ok "SEAM.md adoption_path (frontmatter) 기록됨"
  else
    _no "SEAM.md frontmatter 에 유효한 adoption_path 없음 (본문 기재·미닫힘 frontmatter 불인정)"
  fi
  if awk 'NR==1 && $0!="---"{bad=1; exit} /^---$/{n++; if(n==2){closed=1; exit} next} n==1 && $0 ~ "^synced_at:[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*$"{ok=1} END{exit (!bad && closed && ok)?0:1}' "$S"; then
    _ok "SEAM.md synced_at (YYYY-MM-DD) 기록됨"
  else
    _no "SEAM.md frontmatter 에 synced_at(YYYY-MM-DD 정확 형식) 없음 — Done When mandatory 항목"
  fi
else
  _no "SEAM.md 부재 — 채택 경로 기록 필요(§Done When)"
fi

echo "-- seam check: $([ "$fail" -eq 0 ] && echo PASS || echo FAIL) --"
exit "$fail"
