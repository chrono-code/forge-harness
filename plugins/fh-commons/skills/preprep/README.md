# preprep — standalone 으로 세우기

이 디렉터리가 **단일 소스**다. FH 안에서는 스킬로 쓰고(`SKILL.md`), 밖에서는 아래처럼 뽑아
**독립 현장 하네스**로 세운다. 🟥 **손으로 고쳐 쓴 사본을 만들지 마라** — 사본이 둘이면 갈리고,
`scripts/test_preprep_drift_anchor.sh` 가 그것을 잡는다.

```bash
mkdir -p ~/preprep && cd ~/preprep
cp <이 디렉터리>/{preprep.py,interslide_deps.py,lane_prose.py} .
cp <이 디렉터리>/surfaces.example.yaml   surfaces.yaml
cp <이 디렉터리>/canon_terms.example.yaml  canon_terms.yaml
cp <이 디렉터리>/jargon_terms.example.yaml jargon_terms.yaml
$EDITOR surfaces.yaml          # root 와 표면 목록을 적는다. 여기가 사람 몫이다
python3 preprep.py
```

의존: `pyyaml` · `python-pptx` 둘뿐이다(나머지는 표준 라이브러리). FH 도, 네트워크도 필요 없다.

## 드리프트를 막는 법

```bash
PREPREP_STANDALONE_DIR=~/preprep bash <FH>/scripts/test_preprep_drift_anchor.sh
```
`D2` 가 코드 3파일을 **바이트 대조**한다. 환경변수를 안 주면 `SKIPPED` 이고 **SKIP 은 PASS 가
아니다** — 기본 경로를 박아두면 다른 머신에서 거짓 SKIP 이 나기 때문에 일부러 안 박았다.

## 왜 이원화인가

메타하네스(FH)는 **optimize** 하고 현장하네스는 **simpler over time** 이다. 발표 하나 준비하려는
사람에게 FH 의 상주 규칙 전량을 지우는 것은 순수 낭비다. 그래서 같은 코드를 두 진입점으로 낸다.

## 안 들어온 것

`ooxml/` (수동 OOXML 수술 도구 — `V·tree_of·save·textbox`) 는 **이 하네스의 일부가 아니다.**
자동 러너에서 호출부 0이고(컨트롤 동반 확인), 그 안의 `build.py` 는 옛 세션 스크래치패드
절대경로를 물고 있어 지금 아무 데서도 안 돈다. 필요하면 그것대로 따로 고쳐라.
