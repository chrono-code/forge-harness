#!/usr/bin/env bash
# sim_isolated_run.sh — run a blind floor-tier sim WITHOUT letting it become an agent fleet.
#
# WHY THIS EXISTS (measured 2026-08-29, twice):
#   A blind sim of identity ④ was launched as 12 parallel `claude -p` calls in the LIVE repo cwd.
#   Three things went wrong, and the third is the one that matters:
#     1. the arms wrote 6 files into the working tree and read each other's output — corpus
#        self-contamination, the same defect as the 2026-08-23 probe's invalidated arm A3;
#     2. one arm registered a **launchd agent** in ~/Library/LaunchAgents — an unrequested,
#        persistent change to the operator's machine, made by something called "a measurement";
#     3. 🟥 the contamination produced a FALSE POSITIVE POINTING AT THE DESIRED CONCLUSION.
#        An arm answered "이미 돼있어" — found prior art, declined to rebuild — which is the
#        textbook success scene for identity ④. The "prior art" was a file another arm had
#        created two minutes earlier. Scored naively, ④ would have looked GREEN, on the same
#        day the operator asked for ④ to be shown green.
#   Isolation is therefore not "keep the answer word out of the prompt". It is "put the target
#   where the arms cannot reach it".
#
# WHAT THIS GIVES YOU, and what it does NOT:
#   ✅ PREVENTS repo-tree contamination   — each arm gets its own disposable clone
#   ✅ PREVENTS settings inheritance      — `--restricted` ignores user/project/local settings
#   ✅ DETECTS machine-level side effects — LaunchAgents / crontab / ~/.claude snapshot diff
#   🟥 DOES NOT PREVENT machine-level side effects in `act` mode. Full containment needs an OS
#      sandbox, which this script does not provide. `observe` mode prevents them by removing the
#      tools that could cause them; `act` mode trades that for behavioural fidelity and reports
#      what happened. Saying "isolated" without this paragraph would be the lie this file exists
#      to stop. A detector is not a gate (CLAUDE.md §Surface-Class Degrade Invariant).
#
# MODES
#   observe (default)  --tools "Read,Grep,Glob"  → read-only. No writes possible.
#   act                write tools, inside a disposable clone. Machine surfaces are snapshotted
#                      before and after; any delta is printed LOUDLY and the run is CONTAMINATED.
#   --no-harness       adds `--restricted`, which DROPS the project CLAUDE.md. See below — this is
#                      a CONTROL arm generator, never the default.
#
# 🟥 WHY `--restricted` IS NOT THE DEFAULT — measured, one variable at a time, 2026-08-29.
#   `--restricted` reads like the isolation flag you want ("ignores user, project and local
#   settings files"). It also drops the project memory, so the harness under test is not loaded.
#   The first build of this script used it, and the very first smoke run returned a bare
#   "안녕하세요! 무엇을 도와드릴까요?" to a greeting — which would have been written up as
#   **"the onboarding menu does not fire at floor tier"**, a large and false claim about FH.
#   Worse, the first known-positive PASSED and hid it: the arm answered a CLAUDE.md question
#   correctly *by grepping a file*, so "the harness is loaded" and "the model can search" were
#   never separated. The discriminating pair needs `--tools ""` so search is impossible:
#       same clone, --tools "", --restricted      → "그런 규칙이 없어요"   (memory ABSENT)
#       same clone, --tools "", no --restricted   → "🐿️"                  (memory PRESENT)
#   One variable, opposite answers. ([[feedback_instrument_cannot_discriminate_hypotheses]])
#
# 🟥 THE SAME FLAG ALSO KILLS `act` MODE'S WRITE PATH — measured 2026-09-03, known-pair.
#   `--restricted` ignores settings for PERMISSIONS too, not just memory, and `-p` has no TTY to
#   ask a human — so `act`+`--no-harness` cannot Write/Edit AT ALL, regardless of what the model
#   decides. Confirmed with one variable (`--restricted` on/off, same prompt, same --tools): Edit
#   succeeds without it; with it every rep says "The edit was blocked — permission to write to
#   file.txt wasn't granted." Deterministic, not a race — this is why a real run reads 5/5.
#   ⇒ A "did not edit" result from `act --no-harness` is NOT evidence the base model chose not to
#   write. Use `--no-harness` as an observe-mode control (memory presence, per the pair above)
#   only — never to ask whether a write would have happened. Workaround not built: `--restricted`
#   still honors an explicit `--settings <file>` (per `claude --help`), so a minimal file carrying
#   only Write/Edit approval could restore act-mode fidelity here — filed, not implemented.
#
# 🟢 AND THE DEFECT IS REUSABLE AS AN INSTRUMENT. `--no-harness` answers a question this repo
#   asks constantly and usually by eye: **does this behaviour come from FH, or would the base
#   model have done it anyway?** Run the same prompt with and without the flag; a behaviour that
#   survives `--no-harness` was never the harness's doing. That is a control arm, and it is the
#   cheapest honest one available here.
#
# USAGE
#   bash scripts/sim_isolated_run.sh --arm cluster --reps 3 --prompt "이 프로젝트 가속화하고 싶어"
#   bash scripts/sim_isolated_run.sh --arm build --mode act --reps 3 --prompt "..." --model sonnet
#   bash scripts/sim_isolated_run.sh --arm door3 --reps 3 --prompt "..." \
#        --setup 'mkdir -p tracks/demoproj'      # build the precondition inside the clone
#   Outputs land in a run dir printed at the end; each arm/rep is its own file.
#
# 🟥 OBSERVE MODE CANNOT SEE AN EMPTY DIRECTORY — and FH has machine signals that ARE empty
#   directories. `fh_detail_protocols.md` §Branch test defines a mapped project as a
#   `tracks/{name}/` **dir**, which is routinely empty; `Glob` matches files, so a read-only arm
#   reports "no mapped projects" no matter what you created. Measured 2026-08-29: a `--setup` that
#   ran `mkdir -p tracks/demoproj` succeeded, the directory existed in the clone, and all three
#   arms still answered "매핑된 프로젝트가 하나도 없다". The fixture was real and invisible.
#   ⇒ **A fixture for observe mode must contain a FILE.** This is an instrument constraint, not an
#   FH defect (a normal session has Bash and can `ls`) — but scoring an arm without knowing it
#   produces a confident zero from a fixture that was never observable.
#
# 🟥 PROJECT HOOKS DO RUN IN A DISPOSABLE CLONE — an earlier version of this paragraph said the
#   opposite, and it was wrong (RETRACTED 2026-09-03). It read: "PROJECT HOOKS DO NOT RUN IN A
#   DISPOSABLE CLONE … measured 2026-08-30: an arm copied `.claude/settings.json` into its clone to
#   make the PreToolUse PriorArt hook live; not one of the three clones grew
#   `.claude/.prior_art_events.tsv`". That absence was read as "hooks never fire here" with NO
#   control arm whose hook was known to fire — and it narrowed two rounds of the identity-⑤
#   design (the hook-layer arm was declared unmeasurable). Known pair, 2026-09-03: a PreToolUse
#   Bash hook that appends to `$CLAUDE_PROJECT_DIR/_hook_evidence.txt`, installed via
#   `--setup 'cp <settings.json> .claude/settings.json'`, FIRED inside this runner's own clone
#   (act mode, deny settings.local.json present) and in a bare `claude -p` clone, trusted or not.
#   Why the 2026-08-30 arm saw nothing — CONFIRMED the same day, one more known pair: with the
#   real project hook set copied into a clone, an arm asked to build a new mechanism script FOUND
#   PRIOR ART and never called Write (identity-④ behaviour), so the Write-matched PriorArt hook had
#   nothing to fire on; an arm forced to Write a new scripts/*.sh produced `.prior_art_events.tsv`
#   with a FIRE row inside the clone. The stimulus never reached the hook — a hook that is never
#   triggered looks identical to a hook that cannot run, which is why a control arm whose hook is
#   KNOWN to fire is mandatory. Signal: tracks/_meta/fh_signal_2026-09-03_runner-hooks-do-fire.md
#   What SURVIVES from the old paragraph: before claiming a hook-dependent result, check the
#   hook's own evidence file INSIDE the clone; absence of that file invalidates the ARM, never the
#   hypothesis. And `--setup` writing an UNTRACKED file (.claude/settings.json is gitignored) is
#   not contamination — the tree baseline is taken after setup, and git status never sees it.
#
# 🟥 CONTROL IS NOT OPTIONAL. Always run at least one arm whose correct answer is "the thing
#   being measured should NOT fire". An instrument that fires on everything measures nothing
#   ([[feedback_control_presence_is_not_discrimination]]).
#
# ── ⓒ 격리 그라운딩 — 날짜 오염 통제 (six_axis_review_2026-09-04 강화 #3, RECORD ONLY) ──────────
#   WHY: LiveCodeBench (arXiv 2403.07974) and the contamination-taxonomy literature
#   (frontier_verification_map_2026-09-04.md §ⓒ) filter benchmark items by RELEASE DATE precisely
#   because a model can have memorized — not reasoned about — anything published before its
#   training cutoff. This runner has the same exposure: a sim arm's "correct" answer about a
#   doc/rule/gate can be recall of that doc's OWN CONTENT (if the doc predates the model's cutoff
#   and the model happened to see this repo, or a near-identical one, during training) rather than
#   evidence the harness under test actually delivers the behaviour to a cold session.
#   THIS IS A RECORDING, NOT A GATE — per CLAUDE.md §Mechanization Boundary, "what the right value
#   IS" stays judgment; only "was it recorded" is a channel. Below writes two fields per rep to
#   `<out>/<arm>_r<rep>.meta.tsv` and does NOT compare them or fail a run on their basis:
#     corpus_head_date   — the clone's HEAD commit date (ISO 8601). PROXY, named honestly: this
#                          runner cannot resolve which files a given PROMPT actually cites, so it
#                          records the whole corpus's most recent commit as an upper bound on
#                          "how fresh could the cited material be", not a per-file citation date.
#     sim_model / sim_model_cutoff — the `--model` value and a best-effort known cutoff via
#                          `_model_known_cutoff()` below, `UNKNOWN` when not recorded there. This
#                          table WILL go stale as new models ship — it is deliberately not treated
#                          as authoritative; a scoring session should verify the cutoff it cites
#                          rather than trust this file's guess (§Instrument-Calibration).
#
# ── ⓒ 격리 그라운딩 — 일회용 샌드박스 표준 (six_axis_review_2026-09-04 강화 #3) ─────────────────
#   프런티어 대조표가 "ephemeral wipe-and-reseed 샌드박스(E2B/Modal/Runloop)"를 도입 후보로 든다.
#   조직 제약상 외부 도구는 보류하고(§도입 후보 3), 이 러너가 "이미 그렇게 동작하는 부분"과
#   "아닌 부분"을 정직하게 갈라 적는다 — 매번 재발견하지 않도록.
#
#   WIPE (매 rep 마다 새로 만든다 — 재사용 없음):
#     ✅ 이미 참 — 매 rep 이 독립된 `git clone` (§위 "A disposable clone per REP") + 독립된 부모
#        디렉터리(§L10). 오늘 실행한 실측 (`test_sim_isolated_run_lanes.sh`):
#          ✅ L10 no clone shares a parent with another (2 clones, 0 co-parented)
#          ✅ L10b control — 2 clones found (L10 did not pass on an empty set)
#        (재현: `bash scripts/test_sim_isolated_run_lanes.sh` — 위 두 줄이 그대로 나온다.)
#   RESEED (팔이 못 보면 안 되는 자산을 클론에서 지운다):
#     ✅ 이미 참 — ARM_BLIND_PATHS 제거(§아래) + 그 자체가 known-pair 로 검정됨:
#          ✅ L24 팔 눈가림 자산이 클론에서 제거된다 (히트 >0 → 0)
#   기계-표면 리셋 (LaunchAgents/crontab/settings — VM 리셋과 달리 "지우고 다시 만들지" 않는다):
#     🟥 아직 부분 — observe 모드는 도구 자체가 없어 못 건드리고(구조적 예방), act 모드는 실제
#        변경을 만들고 나서 **탐지**만 한다(§L7). "매 rep 전 기계 상태를 초기화"는 하지 않는다 —
#        E2B/Modal 급 VM wipe-and-reseed와의 실제 델타는 이 한 줄이다. 진짜 OS 샌드박스가 필요한
#        이유는 헤더 상단 "WHAT THIS GIVES YOU" 절이 이미 말한다 — 여기서 되풀이하지 않는다.
#   요약: 파일시스템 코퍼스 축(WIPE+RESEED)은 클론 단위로 이미 wipe-and-reseed다. 기계 표면 축은
#   아니다 — 탐지기이지 리셋기가 아니다. 이 두 문장이 "샌드박스 표준"의 정직한 전부다.
#
# ── timeout(1) RESOLUTION — macOS ships none, and launchd's PATH cannot see Homebrew's
#   (2026-09-05, measured) ──────────────────────────────────────────────────────────────────────
#   WHY: stock macOS ships no `timeout(1)`. Homebrew coreutils installs `gtimeout` (plain
#   `timeout` only if the user un-prefixes GNU coreutils onto PATH) under a prefix an interactive
#   login shell sees but a launchd job's PATH does NOT — this repo's own plist templates ship
#   `$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin`, no Homebrew prefix at all. The first launchd
#   live-eval run (2026-09-05 02:30) hit exactly this: every one of 12 probes × 2 arms died at
#   `timeout: command not found` before `claude` ever ran, and the report showed 12/12
#   FAILED-TO-RUN with no clue why — a "did this fire" question this repo cares about a great
#   deal (§Skeleton-Not-Muscle) answered wrong for a reason that had nothing to do with the
#   harness under test. FH ships this script via npm (package.json `files[]`), so a stock-macOS
#   consumer with no Homebrew coreutils hits the identical wall running it by hand — this is not
#   a launchd-only defect. Resolution below: GNU `timeout` → `gtimeout` → a bash-native watchdog
#   fallback, so a run never silently trades "no timeout enforcement" for "works on my machine".
#   The resolved kind is printed in the run header as `timeout_tool=` so a run names its own
#   control rather than leaving it to be inferred from a failure days later.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# ── 경로 격리 계산 (함수로 꺼냈다 — 레인이 «실행»해서 검증할 수 있게) ──────────────
# 🟥 처음엔 인라인이었고 레인이 `grep` 으로만 확인했다. new-code-anchor 게이트가 그것을
#    **MENTION_ONLY** 로 잡았다: 「레인이 파일을 이름만 대고 실행하지 않는다」.
#    옳은 지적이다 — 그래서 함수로 꺼내 레인이 진짜로 부르게 한다.
fh_sim_write_path_isolation() { # $1=WORK $2=OUTDIR $3=REPO_ROOT $4=HOME → 0=썼다 1=격리없음(차단)
  local _w="$1" _out="$2" _repo="$3" _home="$4"
  # ── 🟥 경로 격리 (2026-08-30 — 이 러너는 이날까지 «격리»가 아니었다) ──────────────
  #    헤더가 *"disposable clone 이라 오염 없음"* 이라 적어왔는데, **클론은 cwd 일 뿐이고
  #    읽기는 어디든 갔다.** `--tools "Read,Grep,Glob"` 는 «쓰기»만 막지 «경로»를 안 막는다.
  #    실측(같은 날, known-pair): observe 팔이 `/tmp` 파일을 출력했고, **채점용 qset 을
  #    정답 토큰까지 통째로** 읽었고, 앞선 팔의 답변 디렉터리를 나열했다(159,050 파일).
  #    ⇒ 맥락유지 3개 회차가 전부 무효. 세 번의 VOID 는 «다른 증상 셋»이 아니라 **근인 하나**였다.
  #
  # 🟥 **첫 수리는 과차단이었다 — 클론 자신을 막았다.** `Read(//tmp/**)` 로 통째로 막았는데
  #    `WRAP="$_out/..."` 라서 `--out /tmp/...` 이면 **클론이 그 아래 산다.** ARM 이
  #    *"working directory 에 대한 read 권한이 모든 도구에서 거부"* 라고 답했다.
  #    ⇒ 광범위 차단 대신 **위험한 곳만 이름으로** 막는다: 실제 레포 · 홈 · 이 회차의 out 디렉터리.
  #    그 셋이 «이 실험이 자기 답을 볼 수 있는» 전부다(소스·qset·앞선 팔의 답변).
  #    ⚠️ 완전 격리가 아니다 — 열거 안 한 절대경로는 여전히 읽힌다. 그렇게 적는다.
  # 형태도 실측으로 골랐다: `Read(/x/**)`(슬래시 하나)는 **안 막힌다**. `Read(//x/**)` 라야 한다.
  # `Glob(...)`/`Grep(...)` 을 섞으면 클론 안까지 과차단됐다 — 그래서 **Read 만** 둔다.
  mkdir -p "$_w/.claude"
  # 🟥 cross-family(agy #4): 여기가 **명백한 fail-open** 이었다 — 격리 규칙이 없는
  #    `settings.local.json` 이 클론에 있으면 주입을 건너뛰고 **비격리 상태로 측정을 강행**한다.
  #    「SKIPPED 라고 알렸다」는 변명이 안 된다: 이 회차의 산출은 그래도 숫자로 쓰인다.
  #    ⇒ 격리 없이는 **회차를 시작하지 않는다**. 강행은 명시 플래그로만.
  if [ -f "$_w/.claude/settings.local.json" ] && ! grep -q '"deny"' "$_w/.claude/settings.local.json" 2>/dev/null; then
    if [ "${FH_SIM_NO_ISOLATION_OK:-}" = 1 ]; then
      echo "  ⚠️  arm 격리 없이 강행됨(FH_SIM_NO_ISOLATION_OK=1) — 이 회차는 오염 가능하다고 기록해라." >&2
    else
      echo "  ❌ arm settings.local.json 이 이미 있는데 deny 규칙이 없다 — **격리 없이 재지 않는다.**" >&2
      echo "     강행: FH_SIM_NO_ISOLATION_OK=1 (그러면 그 회차는 오염 가능으로 기록해라)" >&2
      : # 오염 표기는 호출부가 한다(함수는 rc 로만 말한다)
      return 1
    fi
  fi
  if [ -f "$_w/.claude/settings.local.json" ]; then
    :
  else
    # 🟥 **물리경로로 계산한다** (2026-08-30, 세 번째 수리). macOS 에서 `/tmp` 는
    #    `/private/tmp` 심링크라 **같은 자리가 두 이름**을 갖는다. 논리경로만 적으면
    #    어떤 회차는 클론을 막고(과차단) 어떤 회차는 레포를 못 막는다(누출) — 즉 격리가
    #    **비결정적**이 된다. 실측: 같은 설정에서 한 팔은 «working directory 거부», 다른 팔은
    #    레포의 qset 을 읽었다. 비결정적 격리는 격리가 아니다.
    _phys(){ ( cd "$1" 2>/dev/null && pwd -P ) || printf '%s' "$1"; }
    _p_repo=$(_phys "$_repo"); _p_home=$(_phys "$_home")
    _p_out=$(_phys "$_out");     _p_work=$(_phys "$_w")
    _deny_repo="//${_p_repo#/}"
    _deny_home="//${_p_home#/}"
    _deny_out="//${_p_out#/}"; _extra_out=""
    # 🟥 클론이 out 아래 살면 out 을 통째로 막을 수 없다. 그 경우 «앞선 팔의 답변 파일»만 막는다.
    # 클론이 out 아래 살면 out 을 통째로 못 막는다. 그때는 «다른 팔의 산출»만 막는다 —
    # 🟥 `*.txt` 만으로는 부족했다: 다른 팔의 **클론 트리**(`w_*/repo/**`)에 주입된 봉인 원장을
    #    읽을 수 있었다. 그것도 막고, **내 클론은 예외로 둔다**.
    case "$_p_work" in
      "$_p_out"/*)
        _deny_out="//${_p_out#/}/*.txt"
        # 🟥 2026-08-31 — 종전 `w_*` 는 **자기 클론에도 매치**했다. 바로 위 주석이
        #    「내 클론은 예외로 둔다」고 적어놓고 코드엔 그 예외가 없었다
        #    ([[feedback_rule_misdescribes_its_own_machine]]). 조건 분기는 **항상 참**이라
        #    (`WRAP="$OUTDIR/w_${ARM}_r${r}"`) 이 deny 가 모든 회차에 붙었고, 그래서
        #    **팔은 자기 운반체를 한 번도 못 읽었다.** known-pair 로 확정:
        #      자기 클론의 seal → BLOCKED · 같은 클론의 CLAUDE.md → 읽힘
        #    ⇒ `DELIVERY` 는 한 번도 측정된 적이 없다. `_ccrun7` 의 positive ARM PASS 는
        #      운반체가 아니라 stdin 으로 샌 정답키였다(두 결함이 서로를 가려줬다).
        # 🟥 글롭으로는 「나만 빼고」를 표현할 수 없다. 그래서 설정을 쓰는 시점에
        #    **이미 존재하는 형제만 이름으로** 막는다. 팔·rep 이 순차 루프이므로
        #    (`for r in $(seq 1 "$REPS")` · `&`/`wait` 없음) 그 시점 열거는 완전하다 —
        #    뒤에 생길 형제는 이 팔이 끝난 뒤에 만들어진다.
        _extra_out=""
        _my_wrap="$(basename "$(dirname "$_p_work")")"
        for _sib in "$_p_out"/w_*; do
          [ -d "$_sib" ] || continue
          _sib_b="$(basename "$_sib")"
          [ "$_sib_b" = "$_my_wrap" ] && continue          # 나는 뺀다 — 그게 이 수리의 전부다
          _extra_out="$_extra_out,\"Read(//${_p_out#/}/$_sib_b/repo/tracks/**)\""
        done
        ;;
    esac
    # 🟥 cross-family(agy #1): 기본 `$TMPDIR`(macOS `/var/folders/**`)·공유 경로·마운트 볼륨이
    #    빠져 있었다. 산출물이 기본 TMPDIR 에 생기면 앞선 팔의 결과가 그대로 읽힌다.
    #    🟥 단 **클론이 사는 경로는 막으면 안 된다**(첫 수리가 그렇게 자기 발을 쐈다) —
    #    그래서 `$_w` 를 품는 접두사는 목록에서 뺀다. 계산으로 하지, 손으로 고르지 않는다.
    _extra=""
    for d in /var/folders /private/var/folders /Users/Shared /Volumes /var/tmp /private/tmp /tmp; do
      _pd=$(_phys "$d"); [ -n "$_pd" ] || continue
      case "$_p_work" in "$_pd"/*) continue ;; esac  # 내 클론이 그 아래면 막지 않는다(물리경로 비교)
      case "$_p_out"  in "$_pd"/*) continue ;; esac  # out 도 마찬가지 — 위에서 정밀하게 다룬다
      d="$_pd"
      case "$_extra" in *"Read(//${d#/}/**)"*) continue ;; esac   # 중복 금지(실행으로 드러났다)
      _extra="$_extra,\"Read(//${d#/}/**)\""
    done
    # 🟥 함수로 꺼내 «실행»해보자마자 JSON 결함이 드러났다: 종전엔 `_deny_out` 안에 따옴표·괄호를
    #    끼워넣어 `Read(...*.txt` 가 안 닫히고 `tracks/**))` 로 두 번 닫혔다. **grep 레인이었으면
    #    영영 못 봤다** — new-code-anchor 게이트가 MENTION_ONLY 를 막은 것이 이걸 잡았다.
    #    ⇒ 조각을 문자열로 조립하지 말고 **필드별로 분리**한다. 그리고 중복도 제거한다.
    printf '{"permissions":{"deny":["Read(%s/**)","Read(%s/**)","Read(%s)"%s%s]}}' \
      "$_deny_repo" "$_deny_home" "$_deny_out" "$_extra_out" "$_extra" > "$_w/.claude/settings.local.json"
  fi

  # ── 🟥 조립 검증 (2026-08-31 신설) — 파싱만 보면 이 결함을 놓친다 ─────────────
  #    회차 3(_ccrun7)은 위 문단이 고친 바로 그 파손을 안고 돌았다:
  #      'Read(//private/tmp/_ccrun7/*.txt'                  ← 닫는 괄호 없음
  #      'Read(//private/tmp/_ccrun7/w_*/repo/tracks/**))'   ← 괄호 둘
  #    파손된 규칙은 매칭이 안 되므로 **형제 클론의 tracks/ 가 안 막혔고**, 거기 seal 이 있다.
  #    그 회차의 CTRL 이 기대토큰을 축자로 댄 것이 그렇게 설명된다.
  #    🟥 **그 JSON 은 «정상 파싱된다».** 파손은 구조가 아니라 규칙 문자열 «안»에 있다.
  #    그래서 「JSON 파싱 레인」은 두 팔을 못 가르는 **장식**이다
  #    ([[feedback_anchor_can_be_decorative]]). known-pair 로 확인했다:
  #      K+ 회차3 실물 : JSON=OK · 문법위반 2 · 중복 1   ← 잡힌다
  #      K- 현행 조립  : JSON=OK · 문법위반 0 · 중복 0   ← 안 잡힌다
  #    ⇒ 검사는 셋이다: 파싱 ∧ 항목 문법(괄호 정확히 한 쌍) ∧ 중복 0.
  #    🟥 fail-closed — 격리가 깨진 채로 재느니 안 재는 게 낫다. 이 함수의 rc 1 은 호출부에서
  #    CONTAMINATED=1 + continue 로 이어져 **그 팔은 안 뜬다**(격리 없이는 회차를 시작 안 한다).
  #    ⚠️ 문법 검사의 한계를 이름으로 남긴다: 패턴 «안»에 괄호를 쓰는 규칙은 이 검사가
  #       거짓 위반으로 잡는다. 현재 조립은 그런 규칙을 안 만든다 — 만들게 되면 여기를 고쳐라.
  if ! python3 - "$_w/.claude/settings.local.json" <<'_PYEOF'
import json,re,sys
try:
    d=json.load(open(sys.argv[1]))
except Exception as e:
    print("  ISOLATION-ASSEMBLY: JSON parse failed: %s" % e); sys.exit(1)
rules=d.get("permissions",{}).get("deny",[])
if not rules:
    print("  ISOLATION-ASSEMBLY: deny list EMPTY — 격리 없음"); sys.exit(1)
pat=re.compile(r'^[A-Za-z]+\([^()]*\)$')
bad=[r for r in rules if not pat.match(r)]
dup=sorted({r for r in rules if rules.count(r)>1})
if bad or dup:
    for r in bad: print("  ISOLATION-ASSEMBLY: malformed rule: %r" % r)
    for r in dup: print("  ISOLATION-ASSEMBLY: duplicate rule: %r" % r)
    sys.exit(1)
sys.exit(0)
_PYEOF
  then
    echo "  ❌ 격리 규칙 조립이 깨졌다 — **이 팔은 안 띄운다**(fail-closed)." >&2
    return 1
  fi

  return 0
}

BASE_REF=""; BASE_SHA=""
ARM=""; REPS=1; PROMPT=""; MODE="observe"; MODEL="sonnet"; TIMEOUT=900; OUTDIR=""; NOHARNESS=0; SETUP=""; EXTRA=""
while [ $# -gt 0 ]; do
  case "$1" in
    --arm)     ARM="${2:-}"; shift 2 ;;
    --reps)    REPS="${2:-1}"; shift 2 ;;
    --prompt)  PROMPT="${2:-}"; shift 2 ;;
    --mode)    MODE="${2:-observe}"; shift 2 ;;
    --model)   MODEL="${2:-sonnet}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-900}"; shift 2 ;;
    --out)     OUTDIR="${2:-}"; shift 2 ;;
    --no-harness) NOHARNESS=1; shift ;;   # CONTROL arm: drops project CLAUDE.md. Not isolation.
    --base-ref) BASE_REF="${2:-}"; shift 2 ;;   # BASE 얕은 클론 (2026-09-01) — 아래 참조
    --base-sha) BASE_SHA="${2:-}"; shift 2 ;;
    --setup)   SETUP="${2:-}"; shift 2 ;;  # shell run INSIDE each clone before the sim. See below.
    --extra-tools) EXTRA="${2:-}"; shift 2 ;;  # append tools to the mode's set. See TOOL VISIBILITY.
    --mcp-config) MCPCFG="${2:-}"; shift 2 ;;  # the ONLY MCP servers an arm may see (see MCP ISOLATION). Default: none.
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done
[ -n "$ARM" ]    || { echo "FAIL: --arm required" >&2; exit 2; }
[ -n "$PROMPT" ] || { echo "FAIL: --prompt required" >&2; exit 2; }
case "$MODE" in observe|act) ;; *) echo "FAIL: --mode must be observe|act" >&2; exit 2 ;; esac

command -v claude >/dev/null 2>&1 || { echo "FAIL: claude CLI not on PATH" >&2; exit 2; }

# ── timeout(1) resolution — see §timeout(1) RESOLUTION in the header above for WHY. ──────────────
# GNU `timeout` → Homebrew's `gtimeout` → a bash-native watchdog. Never silently proceeds with NO
# enforcement at all — that would trade "wrong binary name" for "no timeout, ever", which is worse.
TIMEOUT_KIND=""; TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_KIND="gnu"; TIMEOUT_BIN="$(command -v timeout)"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_KIND="gtimeout"; TIMEOUT_BIN="$(command -v gtimeout)"
else
  TIMEOUT_KIND="bash-fallback"; TIMEOUT_BIN=""
fi

# fh_run_with_timeout SECONDS CMD... — used only when neither `timeout` nor `gtimeout` resolved.
# Backgrounds CMD, TERMs it if SECONDS elapses, grants 5s to exit cleanly, then KILLs. The verdict
# "did this actually time out" is a FLAG FILE the watchdog writes when it intervenes — not CMD's
# own exit code — because a child that catches SIGTERM and exits 0 anyway must still be reported
# as timed out (matching GNU timeout's rc=124 convention), not read as if it had answered normally.
fh_run_with_timeout() {
  local _secs="$1"; shift
  local _flag; _flag="$(mktemp "${TMPDIR:-/tmp}/fh_to_XXXXXX")"; rm -f "$_flag"
  "$@" &
  local _cpid=$!
  ( sleep "$_secs" 2>/dev/null
    if kill -0 "$_cpid" 2>/dev/null; then
      : > "$_flag"
      kill -TERM "$_cpid" 2>/dev/null
      sleep 5
      kill -0 "$_cpid" 2>/dev/null && kill -KILL "$_cpid" 2>/dev/null
    fi
  ) &
  local _watchdog=$!
  local _rc=0
  wait "$_cpid" 2>/dev/null; _rc=$?
  # The watchdog subshell owns a `sleep`; killing the subshell alone leaves that sleep as an
  # orphan for up to SECONDS (test_frontier_digest_retry.sh challenger B-2 measured exactly this
  # class). Kill the subshell's children first, then the subshell.
  pkill -P "$_watchdog" 2>/dev/null; kill "$_watchdog" 2>/dev/null; wait "$_watchdog" 2>/dev/null
  if [ -f "$_flag" ]; then
    rm -f "$_flag"
    return 124
  fi
  rm -f "$_flag" 2>/dev/null
  return "$_rc"
}

# fh_timeout SECONDS CMD... — drop-in for `timeout SECONDS CMD...` using whichever kind resolved
# above. The call site never branches on TIMEOUT_KIND itself.
fh_timeout() {
  local _secs="$1"; shift
  case "$TIMEOUT_KIND" in
    gnu)      command timeout "$_secs" "$@" ;;
    gtimeout) command gtimeout "$_secs" "$@" ;;
    *)        fh_run_with_timeout "$_secs" "$@" ;;
  esac
}

OUTDIR="${OUTDIR:-$(mktemp -d "${TMPDIR:-/tmp}/fh-sim-XXXXXX")}"
mkdir -p "$OUTDIR"

# ── machine-surface snapshot ──────────────────────────────────────────────────────────────────
# Enumerated, not guessed. Each line is a surface a past run actually touched or plausibly could.
# `not found` is written as `ABSENT`, never as an empty string — an unreadable surface and an
# empty one must not collapse ([[feedback_not_found_is_not_zero_family]]).
snapshot() {
  local f="$1"
  {
    echo "## LaunchAgents"
    ls -1 "$HOME/Library/LaunchAgents" 2>/dev/null || echo "ABSENT"
    echo "## crontab"
    crontab -l 2>/dev/null || echo "ABSENT"
    echo "## claude settings mtime"
    # GNU-first on purpose: `stat -f` on GNU coreutils means "filesystem info" and SUCCEEDS,
    # so a BSD-first chain never reaches the fallback and silently reports the wrong thing.
    # Caught by this repo's own portability lint on the first commit attempt of this file.
    stat -c '%Y %n' "$HOME/.claude/settings.json" 2>/dev/null \
      || stat -f '%m %N' "$HOME/.claude/settings.json" 2>/dev/null || echo "ABSENT"
  } > "$f"
}

# ⓒ 날짜 오염 통제 — 기록 전용 헬퍼(§헤더 참조). 판정 아님, 있으면 값·없으면 UNKNOWN.
# 🟥 이 표는 부패한다(stale) — 새 모델이 나올 때마다 손으로 갱신해야 한다. 여기 적힌 값을
# «검증됨»으로 인용하지 마라: 이 스크립트 자신이 그렇게 적어두라고 요구한다(§Instrument-Calibration).
_model_known_cutoff() { # $1=--model 값 → ISO 월 또는 UNKNOWN
  case "$1" in
    *sonnet-5*|sonnet) printf '2026-01' ;;   # 이 세션의 시스템 프롬프트가 스스로 적은 값
    *) printf 'UNKNOWN' ;;
  esac
}

echo "── sim_isolated_run ──────────────────────────────────────────────"
echo "arm=$ARM mode=$MODE model=$MODEL reps=$REPS timeout=${TIMEOUT}s"
echo "timeout_tool=${TIMEOUT_KIND}${TIMEOUT_BIN:+:$TIMEOUT_BIN}"
echo "out=$OUTDIR"

snapshot "$OUTDIR/_machine_before.txt"

CONTAMINATED=0
for r in $(seq 1 "$REPS"); do
  # Each clone gets its OWN parent directory. Siblings under one parent are visible to `../`,
  # and that is not hypothetical: an arm measured 2026-08-29 scanned its parent for mappable
  # projects and reported finding "iso_A, door_CTRL" — the other arms' work dirs. Content stayed
  # isolated, but their EXISTENCE leaked into the arm's reasoning, which is enough to change an
  # answer about "what projects are around". Isolation has to hold for the parent too.
  WRAP="$OUTDIR/w_${ARM}_r${r}"; mkdir -p "$WRAP"
  WORK="$WRAP/repo"
  # A disposable clone per REP, not per arm: two reps of the same arm contaminate each other
  # exactly as two different arms do. That was the measured failure — reps 1 and 2 of build_cron.
  # ── BASE 얕은 클론 (2026-09-01, §7-12) ──────────────────────────────────────
  # 🟥 왜: 이 레포의 «개발 이력 자체»가 팔의 코퍼스에 들어간다. 세션 시작 컨텍스트가 최근 커밋을
  #    싣고(실측: 팔이 5줄을 그대로 옮겼다), 그 줄들이 「팔의 클론에서 정답지를 없앤다」처럼
  #    실험을 설명한다. 파일을 지워도 안 닫힌다 — 이력은 strip 대상이 아니다.
  # 🟥 그리고 «지우는 것»이 오히려 악화시켰다: rm 만 하면 `git status` 가 51줄로 이름을 광고한다
  #    (실측 0줄 → 52줄). 얕은 클론은 status 가 «원래» 0 이라 그 문제가 없다.
  # 🟥 `file://` 이 «필수»다 — 로컬 «경로»로 주면 git 이 `--depth` 를 **조용히 무시**한다.
  # 🟥 ref 는 움직인다. 그래서 sha 를 «둘 다» 받고 클론 후 대조한다 — 안 맞으면 다른 코퍼스다.
  if [ -n "$BASE_REF" ] || [ -n "$BASE_SHA" ]; then
    if [ -z "$BASE_REF" ] || [ -z "$BASE_SHA" ]; then
      echo "  ❌ --base-ref 와 --base-sha 는 «둘 다» 필요하다(하나만 주면 대조를 못 한다)"; exit 2
    fi
    if ! git clone --quiet --depth 1 --branch "$BASE_REF" "file://$REPO_ROOT" "$WORK" 2>"$OUTDIR/_clone_${ARM}_r${r}.err"; then
      echo "  ❌ r$r BASE CLONE FAILED — see $OUTDIR/_clone_${ARM}_r${r}.err"; continue
    fi
    _got="$(git -C "$WORK" rev-parse HEAD 2>/dev/null)"
    case "$_got" in
      "$BASE_SHA"*) : ;;
      *) echo "  ❌ r$r BASE SHA MISMATCH — ref=$BASE_REF 기대=$BASE_SHA 실제=${_got:-읽기실패}"
         echo "     🟥 ref 가 움직였다 = «다른 코퍼스»다. 회차를 재현할 수 없다."
         rm -rf "$WRAP"; exit 9 ;;
    esac
  elif ! git clone --quiet --local --no-hardlinks "$REPO_ROOT" "$WORK" 2>"$OUTDIR/_clone_${ARM}_r${r}.err"; then
    echo "  ❌ r$r CLONE FAILED — see $OUTDIR/_clone_${ARM}_r${r}.err"
    continue
  fi

  # ⓒ 날짜 오염 통제 — 기록만, 판정 아님(§헤더). corpus_head_date 는 "프롬프트가 인용하는
  # 파일들"의 날짜가 아니라 그 상한(코퍼스 전체 HEAD)이다 — 러너는 프롬프트가 무엇을 인용하는지
  # 모르므로 더 좁게 잴 수 없다. 그렇게 좁혀 적는다.
  _corpus_date=$(git -C "$WORK" log -1 --format=%cI 2>/dev/null); [ -n "$_corpus_date" ] || _corpus_date="UNKNOWN"
  _cutoff=$(_model_known_cutoff "$MODEL")
  {
    printf 'corpus_head_date\t%s\n' "$_corpus_date"
    printf 'sim_model\t%s\n' "$MODEL"
    printf 'sim_model_cutoff\t%s\n' "$_cutoff"
  } > "$OUTDIR/${ARM}_r${r}.meta.tsv"

  # ── 🟥 팔이 읽으면 안 되는 tracked 자산을 «클론 안에서» 제거한다 (2026-09-01) ──────
  # 왜: 얼린 정답지(`scripts/fixtures/knownpair_refusal_48_*`)가 tracked 가 되면서
  #     **모든 팔의 클론에 들어갔다.** 실측 — negative 문항의 핵심 명사구가 그 안에 있다
  #     (브랜드5·도시6·팀명7·향3·카페3·상자4·제품명7 히트, 「가상의」38/48 파일).
  #     그러면 팔이 자기 질문과 거의 같은 문항의 **모범 거절 48개**를 찾는다 ⇒ 베끼거나
  #     시험임을 추론한다. 둘 다 «저자에게 유리한» 방향이다.
  #     자산을 tracked 로 옮기는 것이 그 자산이 «재는 코퍼스»를 바꾼 것이다.
  # 🟥 왜 deny 가 아니라 «제거»인가: deny 는 «못 읽게» 하고 이건 «없게» 한다. 없는 파일은
  #     Read·Grep·Glob·Bash 어느 것으로도 못 읽는다 — **도구 목록에 의존하지 않는다.**
  #     클론은 일회용이라 제거가 파괴적 표면이 아니다(원본은 안 건드린다).
  # 🟥 목록으로 둔다 — 「팔이 읽으면 안 되는 자산」은 늘어난다. 지금은 하나다.
  # 🟥 `scripts/round` — 이건 «시험 인지»가 아니라 **정답 유출**이다:
  #     `eligcheck_qset.sh:30-31` 이 축자로 「negative: CTRL 이 «거절»해야 적격」·
  #     「conflict: CTRL 이 «원래값을 답해야» 적격」 을 적는다. 읽은 팔의 거절은
  #     «능력»이 아니라 «힌트를 따른 것»이다.
  # 🟥 2026-09-01: 러너 재작성 중 이 항목이 «조용히 사라졌다»(커밋 3265224 가 되돌려졌다).
  #     arm_blind_probe 가 「히트 8→1」로 잡았다 — 프로브가 없었으면 회차가 그대로 열렸다.
  # 🟥 `scripts/context_continuity_score.sh` — «공통 노출»이 «차등»으로 전환되는 자리다.
  #     :386 `setup=""; [ "$arm" = ARM ] && setup="$SETUP_ARM"`
  #     :388 `if [ "$DELIVER" = 1 ] && [ "$arm" = ARM ]; then`
  #     ⇒ 이 분기를 읽은 팔은 «내 프롬프트에 봉인 줄이 있나»로 **자기 배정을 역추론**한다.
  #     공통 노출은 «수준»만 옮기지만(차이는 남는다), 자기 배정을 알면 **비교 자체가 죽는다.**
  # 🟥 지워도 conflict prior 가 안 죽는지 «먼저» 확인했다(실측, BASE 트리):
  #     tool_result 1파일(채점기 밖) · Automati 33 · banner.png 4 — 채점기 안 0
  #     compaction_probe.sh 7 중 1 · starter.md 22 중 1 — 여유 충분
  ARM_BLIND_PATHS=( "scripts/fixtures" "scripts/round" "scripts/context_continuity_score.sh" )
  for _bp in "${ARM_BLIND_PATHS[@]}"; do
    rm -rf "$WORK/$_bp"
    # 🟥 rm 의 rc 를 안 믿는다 — 경로 오타면 rm 은 «성공»을 낸다(지울 게 없으니).
    #    판정은 «제거 후에 정말 없는가»로 한다.
    if [ -e "$WORK/$_bp" ]; then
      echo "  ❌ r$r BLIND-STRIP FAILED — $_bp 가 클론에 남았다. 이 회차는 오염이다"
      rm -rf "$WORK"; continue 2
    fi
  done

  # --setup: build the PRECONDITION the measurement needs, inside the clone, before the sim.
  # WHY THIS EXISTS: the first door-③ measurement (2026-08-29) scored 0/3 on both arms and the
  # number meant nothing — a fresh clone has no mapped project tracks, so door ③ can never reach
  # the follow-up proposal that was under test. Both arms correctly answered "there is nothing to
  # accelerate" and the instrument never entered the state it was built to observe. A run whose
  # precondition is unmet does not produce a negative result; it produces no result. Setting the
  # fixture up INSIDE the disposable clone keeps that from being a reason to touch the live tree.
  if [ -n "$SETUP" ]; then
    if ! ( cd "$WORK" && eval "$SETUP" ) >"$WRAP/_setup.log" 2>&1; then
      echo "  ❌ r$r SETUP FAILED — precondition not built, arm is VOID (see $WRAP/_setup.log)"
      CONTAMINATED=1
      continue
    fi
  fi
  # 🟥 기준선은 «클론 직후»가 아니라 «--setup 직후»다 (2026-08-30, 첫 실사용이 잡았다).
  #    아래 :treediff 는 `git status --porcelain` 을 클론 시점 기준으로 읽었다. 그러면
  #    `--setup` 이 추적 파일을 건드리는 순간 그 팔은 **자동으로 CONTAMINATED** 가 된다 —
  #    즉 «전제를 만드는 공식 수단»이 «판정을 무효로 만드는 수단»이었다.
  #    실측: CTRL 3팔이 `rm -f .claude/soul_tenets.txt`(내가 시킨 그 삭제) 한 줄 때문에 전량 무효.
  #    ⇒ setup 이 만든 변화를 기준선으로 빼고, **팔이 만든 변화만** 본다.
  #    ⚠️ 이것은 오염 검사를 «약화»시키는 게 아니다: setup 은 내가 선언한 조작이고 로그에 남는다.
  #       팔이 만든 변화는 여전히 한 줄도 허용 안 된다(observe 모드).
  ( cd "$WORK" && git status --porcelain ) > "$WRAP/_tree_baseline.txt" 2>/dev/null

  fh_sim_write_path_isolation "$WORK" "$OUTDIR" "$REPO_ROOT" "$HOME" || { CONTAMINATED=1; continue; }

  if [ "$MODE" = observe ]; then
    TOOLS=(--tools "Read,Grep,Glob")
  else
    TOOLS=(--tools "Read,Grep,Glob,Bash,Write,Edit")
  fi
  # 🟥 TOOL VISIBILITY IS PART OF THE MEASUREMENT, NOT A DETAIL. `Glob` matches FILES; a
  # directory with no file directly inside it is invisible to a Read/Grep/Glob arm. FH's branch
  # test keys on `tracks/{name}/` DIRECTORIES, so an observe-mode arm can report "tracks/ has only
  # .gitkeep" while `tracks/demoproj/` and `tracks/webshop/` both exist — measured 2026-08-29,
  # verified by opening the clones. That looks exactly like a session misjudging, and it is not.
  # ⇒ When the thing under test depends on ENUMERATION, add Bash and say so:
  #      --extra-tools Bash
  # and treat the observe-only number as the "cannot enumerate" arm rather than as a defect rate.
  [ -n "$EXTRA" ] && TOOLS[1]="${TOOLS[1]},$EXTRA"
  # `--restricted` is opt-in ONLY, and opting in means you are measuring the BASE MODEL, not FH.
  [ "$NOHARNESS" -eq 1 ] && TOOLS+=(--restricted)

  # Blindness comes from the CLONE, not from a flag: `CLAUDE.local.md` is gitignored, so the
  # operator's register pin and standing bindings are structurally absent from every arm. That is
  # verifiable (`git ls-files | grep CLAUDE` returns CLAUDE.md alone) rather than asserted.
  # `.claude/settings.json` is untracked too, so no hooks fire — which makes an arm resemble a
  # CONSUMER install. State that when scoring: this measures the shipped surface, not this node.
  # ── 🟥 실행 기록 (2026-08-31 신설) — 「누출 기전을 못 짚었다」가 아니라 «볼 수 없었다» ──
  #    회차 3(_ccrun7)에서 CTRL 산출물이 qset 기대토큰을 축자로 댔는데(4/6·3/6 파일,
  #    known-negative 0), **팔이 무엇을 받았는지 재구성이 원리적으로 불가능**했다:
  #    프롬프트는 어디에도 안 남고, `.err` 24개는 전부 0바이트이며(그건 *클론* 에러다),
  #    아래 `2>/dev/null` 이 claude 자신의 stderr 를 통째로 버렸다.
  #    ⇒ 두 채널을 연다. **마스킹하지 않는다** — 누출을 보려고 만든 계기가 누출을 가리면
  #    계기가 아니다. 이 파일들은 정답 토큰을 그대로 담을 수 있고, 그것이 목적이다.
  #    ⚠️ 그러므로 이 산출 디렉터리는 «답을 아는» 자리다. 다른 팔이 읽지 못하도록 막는 것은
  #       fh_sim_write_path_isolation 의 `_deny_out` 이고, 그 결박이 이 덤프의 전제다.
  printf '%s' "$PROMPT" > "$OUTDIR/${ARM}_r${r}.prompt.txt"
  # 🟥 `< /dev/null` 이 **하중이다** — 빼면 격리가 통째로 무너진다 (2026-08-31 확정).
  #    `claude -p` 는 **stdin 이 TTY 가 아니면 그것을 읽어 프롬프트 뒤에 붙인다.**
  #    호출부(`context_continuity_score.sh`)는 `while … done < "$QSET"` 루프 «안»에서 이 러너를
  #    부르므로, 러너도 그 밑 claude 도 **stdin = 채점용 qset(정답 열 포함)** 을 상속했다.
  #    ⇒ 모든 팔이 매 회차 **정답키 전체**를 받았다. ARM 도 CTRL 도.
  #    known-pair (같은 모델·같은 플래그, 변수는 stdin 하나):
  #      stdin=파일     → 판정줄은 NOTHING_APPENDED 인데 **본문이 미끼 토큰을 축자로 인용**한다
  #      stdin=/dev/null → 미끼 토큰이 어디에도 안 나온다
  #    🟥 그래서 이 결함은 «팔에게 물어보면» 안 잡힌다 — 팔은 그것을 «프롬프트 인젝션»이라
  #    부르며 정직하게 거부하면서도, 거부문 안에서 정답을 말한다. 채점기는 그걸 토큰으로 센다.
  #    이것이 회차 1~3 과 probe1~4 를 전부 무효로 만든 근인이고, 경로 deny·코퍼스 마스킹은
  #    **원리적으로 못 막는다**(도구 읽기가 아니라 프롬프트 조립이다).
  # 🟥 MCP ISOLATION (measured 2026-09-05, QP chamber floor sim): a headless arm launched by this
  #    runner saw the OPERATOR'S user-scope MCP servers (a cloud drive, a wiki, a browser bridge)
  #    in its tool list — the clone isolates files and settings, not `~/.claude.json` MCP scope.
  #    A blind arm with a write-capable MCP is a residency hole, not a sim. `--strict-mcp-config`
  #    = "only the servers given by --mcp-config" (CLI --help), and with no --mcp-config that is
  #    NONE. An arm that legitimately needs a server (e.g. Playwright for a web target) gets it
  #    explicitly via --mcp-config <file inside the clone>; nothing is inherited.
  MCPARGS=(--strict-mcp-config); [ -n "${MCPCFG:-}" ] && MCPARGS+=(--mcp-config "$MCPCFG")   # bash 3.2 + set -u: expanded with the ${a[@]+"${a[@]}"} idiom below
  ( cd "$WORK" && fh_timeout "$TIMEOUT" claude -p "$PROMPT" \
        --model "$MODEL" "${TOOLS[@]}" ${MCPARGS[@]+"${MCPARGS[@]}"} \
        < /dev/null 2>"$OUTDIR/${ARM}_r${r}.stderr.txt" ) > "$OUTDIR/${ARM}_r${r}.txt"
  rc=$?
  bytes=$(wc -c < "$OUTDIR/${ARM}_r${r}.txt" | tr -d ' ')

  # 🟥 An empty output is NOT a "no" answer. The first version of tonight's runner used
  # `timeout 300`, which killed exactly the heavy arms — the ones where the behaviour under test
  # actually fired — and left 0-byte files that read as "the identity did not fire". A false RED
  # generated by the instrument. So the verdict here is three-valued, never two.
  if [ "$rc" -ne 0 ] && [ "$bytes" -eq 0 ]; then
    echo "  ⚠️  r$r UNMEASURED (rc=$rc, 0 bytes) — timeout or crash, NOT a negative result"
  elif [ "$bytes" -eq 0 ]; then
    echo "  ⚠️  r$r EMPTY (rc=0) — the session said nothing; distinct from UNMEASURED"
  else
    echo "  ✅ r$r captured ${bytes}B"
  fi

  # Report what the arm changed inside its own clone — in `act` mode this is the interesting part,
  # and in `observe` mode a non-empty diff means --restricted did not hold and the run is void.
  ( cd "$WORK" && git status --porcelain ) > "$WRAP/_tree_final.txt" 2>/dev/null
  # setup 기준선을 뺀다. 기준선 파일이 없으면(=setup 미사용) 빈 파일로 두어 종전과 동일하게 동작한다.
  [ -f "$WRAP/_tree_baseline.txt" ] || : > "$WRAP/_tree_baseline.txt"
  comm -13 <(sort "$WRAP/_tree_baseline.txt") <(sort "$WRAP/_tree_final.txt") \
       > "$OUTDIR/${ARM}_r${r}.treediff.txt" 2>/dev/null
  # 🟥 setup 이 만든 변화도 «버리지 말고» 별도로 남긴다 — 조용히 사라지면 다음 감사자가
  #    «CTRL 이 정말 등록부 없이 돌았나»를 확인할 방법이 없다.
  cp "$WRAP/_tree_baseline.txt" "$OUTDIR/${ARM}_r${r}.setupdiff.txt" 2>/dev/null || true
  tchanged=$(wc -l < "$OUTDIR/${ARM}_r${r}.treediff.txt" | tr -d ' ')
  if [ "$MODE" = observe ] && [ "$tchanged" -gt 0 ]; then
    echo "     🟥 r$r VOID — observe mode wrote $tchanged path(s); the read-only tool set did not hold"
    CONTAMINATED=1
  elif [ "$tchanged" -gt 0 ]; then
    echo "     ℹ️  r$r touched $tchanged path(s) inside its own clone (contained)"
  fi
done

snapshot "$OUTDIR/_machine_after.txt"
if ! diff -q "$OUTDIR/_machine_before.txt" "$OUTDIR/_machine_after.txt" >/dev/null 2>&1; then
  echo ""
  echo "🟥🟥🟥 MACHINE SURFACE CHANGED DURING THIS RUN — the sim had side effects outside its clone."
  diff "$OUTDIR/_machine_before.txt" "$OUTDIR/_machine_after.txt" | sed 's/^/     /'
  echo "     이 실행은 CONTAMINATED 다. 채점하기 전에 되돌려라."
  CONTAMINATED=1
fi

echo ""
echo "── scoring reminder (the part no script can do for you) ──────────"
echo "  🟥 «찾았다»는 답이 나오면 그것이 «언제 생겼는지»부터 봐라."
echo "     tonight's false positive was an arm finding another arm's output and calling it prior art."
echo "  🟥 컨트롤 팔 없이 낸 숫자는 숫자가 아니다."
echo "  🟢 «이게 FH 때문인가»가 궁금하면 같은 프롬프트를 --no-harness 로 한 번 더 돌려라."
[ "$NOHARNESS" -eq 1 ] && echo "  ⚠️  이 실행은 --no-harness 다 — FH 를 잰 것이 아니라 «FH 없이도 그런가»를 잰 것이다."
echo ""
[ "$CONTAMINATED" -eq 1 ] && echo "RESULT: CONTAMINATED — do not score" || echo "RESULT: CLEAN"
echo "OUT: $OUTDIR"
# Detector, never a gate: always exit 0 so a caller cannot be trained to skip running it.
exit 0
