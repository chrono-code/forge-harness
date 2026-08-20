#!/usr/bin/env bash
# residency_admission_check.sh — 상주 텍스트 **유입** 게이트.
#
# 왜 있나 (2026-08-20 실측). 감량은 유출 문제가 아니라 유입 문제였다:
#   CLAUDE.md   23,839(05-26) → 70,758(07-20 «11.9% 감량» 직후) → 144,138(08-20)
#   07-20 이후 31일간 +73,380 = 약 2,367 bytes/일 (최근 5일은 약 7,000/일, 가속)
#   같은 기간 어블레이션 CUT 판정 = **0건** (4개 절 시도 → KEEP 3 · UNCALIBRATED 1)
# 즉 배수구를 넓히는 쪽엔 레버가 거의 없고, 수도꼭지는 아무도 안 보고 있었다.
# 가장 큰 감량 후보 절(22k)조차 **유입 9일치**다 — 완벽히 잘라도 한 달이면 원위치이고,
# 그건 가설이 아니라 07-20 에 실제로 일어난 일이다.
#
# 무엇을 검사하나 — 🟥 **결론이 아니라 기록의 속성**이다 (§Mechanization Boundary).
# 「이 문단이 상주할 가치가 있나」는 판정하지 않는다. 「저자가 유형을 선언했나」만 본다.
# `crossfamily:` · `standpoint:` 와 같은 형태이고 같은 마커에 얹힌다.
#
# 🟥 명시 잔여 — 이 게이트가 잡는 것은 **침묵**이지 **거짓 선언**이 아니다.
# `detail-belongs-elsewhere` 는 자기 거절 값이라 압박받는 세션은 절대 고르지 않는다.
# 형식은 채널이고 진위는 사람이다. 위 두 필드와 같은 이유로 받아들인다.
# 보완: 순증마다 **총량과 베이스라인 대비 델타를 출력**한다 — 그건 자기신고가 아니라
# 측정이라 게임이 안 되고, 추가하는 그 순간에 보인다.
#
# ── 🔒 사전등록 (이 게이트가 값을 냈는지 나중에 채점하기 위해, 배선 **전에** 적는다) ──
# 가설: 이 게이트는 상주 유입을 줄인다.
# 채점: 배선일로부터 30일간 CLAUDE.md 순증 bytes/day 를 직전 31일(2026-07-20~08-20)의
#       **2,367 bytes/day** 와 대조한다. 베이스라인 144,138 @ 2026-08-20.
# 🟥 사전등록 없이 나중에 «줄어든 것 같다» 로 채점하면 07-20 의 「11.9% 감량」과 같은 종류의
#    숫자가 하나 더 생긴다 — 그 숫자는 한 달 뒤 2.1배로 반증됐다.
# 🟥 **정직한 기대값은 «유입 차단» 이 아니라 «유입에 이름이 붙는다» 이다** (peer 재프레이밍).
#    형식 검사는 침묵을 잡지 위조를 못 잡고, 저자는 압박받으면 `soul` 을 고른다
#    (`crossfamily:` 가 이미 거짓 값이 레인을 통과한 실측을 갖고 있다).
#    이름이 붙는 것만으로도 값이 있다 — **다음 감량이 무엇을 지울지 고를 수 있게 된다.**
#
# ── 손 캘리브레이션 (enum 이 실물에서 실제로 가르는가 · 2026-08-20) ──
# 게이트는 기록을 보지 내용을 판정하지 않으므로, enum 의 판별력은 **손으로** 잰다.
# 최근 5일 최대 유입 둘에 적용했더니 **서로 다른 답**이 나왔다:
#   §Mechanization Boundary (10,157 B) → `soul`        — 「기계는 비가역 경계에만, 판단은
#                                                        진화에」는 판단 좌표계다. 상주 정당
#   §Expedition (5,748 B)              → `relocatable(knowledge/shared/rules/operations.md)`
#                                        — 캐던스 절차 + 실측 이력. §Cadence Rules 가 이미 거기 있다
# ⇒ 실물 두 건이 갈렸다. 같은 답만 나왔으면 이 enum 은 판별력이 0 이다.
#
# exit 0 = 통과(감량·무변경 포함) · 1 = 차단 · 2 = 하네스 오류(PASS 아님)

set -uo pipefail

RESIDENT_FILE="CLAUDE.md"
BASELINE_BYTES=144138
BASELINE_DATE="2026-08-20"
# 🟥 사람이 읽는 출력은 enum 을 뱉지 않는다. 기계 어휘는 기계 안에만 둔다 —
#    사용자가 우리 용어를 배우게 만들면 그 게이트는 이식 후 통과 불가가 된다
#    (`count_check.sh:94-106` 이 같은 법칙을 README 렌더링에서 이미 실측했다).
VALID="soul irreversible-gate disambiguator pointer relocatable"

# 🟥 루트는 **스크립트 위치가 아니라 검사 대상 레포**다. 초판은 `dirname $0/..` 를 썼는데,
#    소비자 설치에서 그건 `node_modules/@chrono-meta/fh-gate` 라 **소비자 레포의 CLAUDE.md 가
#    아니라 패키지 안의 우리 CLAUDE.md** 를 검사한다. 정적으로 읽을 땐 안 보였고,
#    팩을 풀어 돌려서 나왔다(§Local Execution First — 실행이 하중선인 이유).
#    호출자(pre-commit)가 $1 로 레포 루트를 준다. 없으면 git 에게 묻는다.
ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT=""
fi
# ── 적용 가능성 판정 (🟥 «구조적으로 해당 없음» 과 «도구가 없음» 을 같은 값으로 접지 않는다) ──
if [ -z "$ROOT" ]; then
  echo "  SKIP  상주 유입 게이트 — git 레포가 아니다 (적용 대상 없음, 통과가 아니라 해당 없음)"
  exit 0
fi
if [ ! -f "$ROOT/$RESIDENT_FILE" ]; then
  echo "  SKIP  상주 유입 게이트 — 이 레포에 $RESIDENT_FILE 이 없다 (적용 대상 없음)"
  exit 0
fi

# ── 순증 계산: 스테이징된 변경만 본다 ────────────────────────────────────────
diffstat=$(git -C "$ROOT" diff --cached --numstat -- "$RESIDENT_FILE" 2>/dev/null)
rc=$?
[ "$rc" -ne 0 ] && { echo "❌ HARNESS ERROR: git diff 실패 (rc=$rc) — 미측정이지 통과 아님" >&2; exit 2; }
[ -z "$diffstat" ] && exit 0                      # 이 커밋은 상주를 안 건드린다

ins=$(printf '%s' "$diffstat" | awk '{print $1}')
del=$(printf '%s' "$diffstat" | awk '{print $2}')
case "$ins$del" in *-*) echo "ℹ️  $RESIDENT_FILE 이 바이너리로 보고됨 — 판정 불가"; exit 2 ;; esac
net=$(( ins - del ))

cur=$(wc -c < "$ROOT/$RESIDENT_FILE" | tr -d ' ')
# 🟥 베이스라인은 **FH 자신의** CLAUDE.md 기준이다. 다른 레포에서 델타를 찍으면 남의 파일을
#    우리 숫자로 재는 것이라 무의미하다 — 소비 레포에선 총량만 말한다.
if [ "$cur" -lt $(( BASELINE_BYTES / 4 )) ] || [ "$cur" -gt $(( BASELINE_BYTES * 4 )) ]; then
  printf '  상주 규모: %s bytes (이 레포 기준 · FH 베이스라인과 스케일이 달라 델타는 생략)\n' "$cur"
  BASELINE_BYTES=0
fi
delta=$(( cur - BASELINE_BYTES ))
if [ "$BASELINE_BYTES" -gt 0 ]; then pct=$(( delta * 1000 / BASELINE_BYTES )); else pct=0; fi
if [ "$BASELINE_BYTES" -gt 0 ]; then
  printf '  상주 규모: %s bytes (기준 %s @ %s · %+d, %+d.%d%%)\n' \
    "$cur" "$BASELINE_BYTES" "$BASELINE_DATE" "$delta" "$((pct/10))" "$((pct%10<0?-pct%10:pct%10))"
fi

if [ "$net" -le 0 ]; then
  echo "  ✅ 상주 순증 없음 (+$ins/-$del 줄) — 유입 게이트 해당 없음"
  exit 0
fi

# ── 순증이다. 마커에 유형 선언이 있어야 한다 ─────────────────────────────────
# 🟥 단, **이 레포가 4축 마커 체제를 돌릴 때만** 그렇다. 마커 디렉터리 자체가 없으면
#    그건 소비 레포이고, 거기서 마커를 요구하면 **이식 이후 한 번도 통과 못 하는 검사**가 된다
#    — 통과 불가능한 게이트는 게이트가 아니라 `--no-verify` 훈련기다
#    (`count_check.sh:94-106` 이 README 렌더링에서 이미 실측한 법칙).
#    소비자 트리 ARM 3 실행이 이걸 냈다: 소비자가 자기 CLAUDE.md 를 늘리자 rc=2 로 막혔다.
if [ ! -d "$ROOT/tracks/_meta" ]; then
  echo "  SKIP  상주 유입 게이트 — 이 레포는 4축 마커 체제를 안 돌린다 (적용 대상 없음)"
  echo "        (순증 +$net 줄은 봤다. 판정하지 않는 이유는 마커 디렉터리 부재다)"
  exit 0
fi

today=$(date +%Y-%m-%d)
marker=$(ls -t "$ROOT"/tracks/_meta/.axes_23_passed_*_"$today".marker 2>/dev/null | head -1)
if [ -z "$marker" ]; then
  cat >&2 <<MSG
❌ 상주 순증(+$net 줄)인데 오늘자 마커가 없다.
   이 검사는 마커 위에 얹힌다 — 4축 마커를 먼저 쓴 다음 다시 커밋해라.
MSG
  exit 2
fi

line=$(grep -E '^residency:' "$marker" | head -1)
if [ -z "$line" ]; then
  cat >&2 <<MSG
❌ $RESIDENT_FILE 이 +$net 줄 늘었는데, 그게 왜 **항상 로드되어야 하는지**가 안 적혀 있다.

   늘어난 내용이 다음 중 무엇인가? 마커에 한 줄 적어라 — 근거를 같이.
     · 판단 회로다 (무엇이 성공 · 어디로 기움 · 절대 안 함)      → residency: soul — <근거>
     · 비가역 경계에서 발화해야 한다 (출하·삭제·이력 재작성)      → residency: irreversible-gate — <근거>
     · 특정 오독 하나를 막는 줄이다                               → residency: disambiguator — <무엇을 막나>
     · 상세로 보내는 포인터다                                     → residency: pointer — <어디로>
     · 🟥 사실 다른 파일로 갈 수 있는 내용이다                     → residency: relocatable(<경로>)
       (목적지를 적으면 이 커밋은 막힌다 — 거기로 옮기고 여기엔 포인터만 남겨라)

   왜 묻나: 07-20 감량 이후 31일간 +73,380 bytes (약 2,367/일). 같은 기간 어블레이션이
   낸 CUT 판정은 0건이다. 나가는 문은 사실상 닫혀 있으므로 들어오는 문에서 정한다.
MSG
  exit 1
fi

# 🟥 구분자는 «em-dash» 또는 «공백-하이픈-공백» 이다. 맨하이픈으로 자르면
#    `detail-belongs-elsewhere` 가 `detail` 로 잘린다 — 되돌림 프로브가 이걸 잡았다
#    (그 전까지 그 레인은 «못 알아듣는 값» 으로 **우연히** 초록이었다).
val=$(printf '%s' "$line" | sed -E 's/^residency:[[:space:]]*//; s/[[:space:]]*—.*$//; s/[[:space:]]+-[[:space:]].*$//' | tr -d ' ')
grounds=$(printf '%s' "$line" | sed -E 's/^residency:[^—]*—[[:space:]]*//; s/^residency:[^-]*[[:space:]]-[[:space:]]//')

# 🟥 `relocatable(<경로>)` 는 **매개변수를 갖는다** — 정확 일치로만 보면 정상 사용이
#    «못 알아듣는 값» 으로 막히고 자기 브랜치는 죽은 코드가 된다(되돌림 프로브가 지목).
ok=0; for v in $VALID; do
  case "$val" in "$v") ok=1 ;; "$v"'('*')') ok=1 ;; esac
done
if [ "$ok" -ne 1 ]; then
  echo "❌ 마커의 residency 값 '$val' 을 못 알아듣는다. 위 다섯 중 하나로 적어라." >&2
  exit 1
fi

case "$val" in
  relocatable*)
    dest=$(printf '%s' "$val" | sed -E 's/^relocatable\(?//; s/\)$//')
    if [ -z "$dest" ] || [ "$dest" = "relocatable" ]; then
      echo "❌ 옮길 곳을 안 적었다. 어느 파일로 가야 하나 — 경로를 괄호 안에 적어라." >&2
      exit 1
    fi
    cat >&2 <<MSG
🟥 저자가 «이건 $dest 로 갈 수 있다» 고 적었는데 상주가 +$net 줄 늘었다. 둘이 안 맞는다.
   $dest 로 옮기고 $RESIDENT_FILE 엔 **명령형 포인터 한 줄**만 남겨라.
MSG
    exit 1 ;;
esac

if [ "${#grounds}" -lt 12 ] || [ "$grounds" = "$line" ]; then
  echo "❌ residency: $val 인데 근거가 비었다. '— ' 뒤에 왜 상주여야 하는지 한 줄." >&2
  exit 1
fi

# ── soul 흡수구 완충 (advisory · 절대 차단하지 않는다) ──────────────────────
# peer 지적: 「판단 좌표계」는 저자가 자기 델타에 거의 항상 붙일 수 있는 라벨이라
# `soul` 이 기본 흡수구가 된다. 🟥 게이트는 마커를 읽지 내용을 안 읽으므로 이건
# **기계로 판정할 수 없다** — 픽스처를 만들어도 그냥 통과한다.
# 대신 **재서 보여준다**: 추가된 줄의 «근거 표지»(날짜·실측·n=·반증·런 #) 밀도.
# 캘리브레이션 실물 2점 (.claude/regression/fixtures/):
#     §Mechanization Boundary → soul        근거표지  3%
#     §Expedition             → relocatable 근거표지 16%
# 🟥 **n=2 다. 판정에 쓰지 않는다** — 중점 10% 를 넘으면 한 줄 묻기만 한다.
if [ "$val" = "soul" ]; then
  addl=$(git -C "$ROOT" diff --cached -- "$RESIDENT_FILE" | grep -c '^+[^+]' 2>/dev/null)
  provl=$(git -C "$ROOT" diff --cached -- "$RESIDENT_FILE" \
          | grep '^+[^+]' \
          | grep -cE '[0-9]{4}-[0-9]{2}-[0-9]{2}|실측|측정|n=[0-9]|반증|런 #[0-9]|PR #[0-9]' 2>/dev/null)
  if [ "${addl:-0}" -gt 0 ]; then
    d=$(( provl * 100 / addl ))
    if [ "$d" -ge 10 ]; then
      echo "  ⚠️ soul 로 선언했는데 추가분의 ${d}% 가 근거 서술이다(날짜·실측·n=)."
      echo "     판단 좌표계가 맞나, 아니면 근거는 signal 로 보내고 결론 한 줄만 남길 수 있나?"
      echo "     (참고 2점: 판단 좌표계 3%% · 이관 대상 16%%. n=2 — 판정 아니라 물음이다)"
    fi
  fi
fi

echo "  ✅ 상주 순증 +$net 줄 · 유형 선언됨 ($val)"
exit 0
