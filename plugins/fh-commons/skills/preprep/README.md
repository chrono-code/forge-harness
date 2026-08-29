# preprep — standalone 으로 세우기

이 디렉터리가 **단일 소스**다. FH 안에서는 스킬로 쓰고(`SKILL.md`), 밖에서는 아래처럼 뽑아
**독립 현장 하네스**로 세운다. 🟥 **손으로 고쳐 쓴 사본을 만들지 마라** — 사본이 둘이면 갈리고,
`scripts/test_preprep_drift_anchor.sh` 가 그것을 잡는다.

```bash
mkdir -p ~/preprep && cd ~/preprep
cp <이 디렉터리>/{preprep.py,interslide_deps.py,lane_progression.py} .
cp -r <이 디렉터리>/ooxml .          # 덱(pptx)을 다룬다면. 아니면 생략
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

## `ooxml/` — 하나는 들어오고 하나는 안 들어왔다

🟥 **초판은 `ooxml/` 을 통째로 뺐고 그게 틀렸다.** 디렉터리 안에 성격이 다른 둘이 있었는데
build.py 의 병(옛 세션 스크래치패드 절대경로 → 지금 아무 데서도 안 돎)을 **디렉터리 단위로**
gate.py 에 전가했다. 후보 목록을 한 종류로 가정한 결함이다.

| | 상태 |
|---|---|
| `gate.py` | 🟢 **들어왔다.** 164줄 · 절대경로 0 · **이미 인자를 받는다**(`argv[1] > OOXML_ROOT > cwd`) · 없는 트리에 fail-closed. 운영자가 「위치가 어긋나 있다」로 지목한 것을 ⑥이 정확히 본다 |
| `build.py` | 🔴 **안 들어왔다.** 사람이 `exec` 로 올려 쓰는 수동 편집기이고 죽은 절대경로를 물고 있다. 필요하면 그것대로 따로 고쳐라 |

`gate.py` 는 `lxml` 을 쓴다 — standalone 의 세 번째 의존이다(`pyyaml` · `python-pptx` · `lxml`).
덱을 안 다루면 안 부르면 되고, 그때는 `lxml` 도 필요 없다.
