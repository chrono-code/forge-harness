<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/banner.png" alt="forge-harness — プロジェクトを鍛え、通せば、より速く仕上がる。品質が梃子であり、速度はその結果だ。" width="680">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e.svg" alt="MIT License"></a>
  <a href="https://zenodo.org/records/20397566"><img src="https://img.shields.io/badge/DOI-10.5281%2Fzenodo.20397566-blue.svg" alt="DOI"></a>
  <img src="https://img.shields.io/badge/Claude_Code-compatible-a855f7.svg" alt="Claude Code">
  <a href="https://github.com/chrono-meta/forge-harness/issues/72"><img src="https://img.shields.io/badge/Codex-beta_·_help_validate-f59e0b.svg" alt="Codex-compatible beta — help validate (issue #72)"></a>
  <a href="https://www.npmjs.com/package/@chrono-meta/fh-gate"><img src="https://img.shields.io/npm/v/@chrono-meta/fh-gate.svg?color=cb3837" alt="npm"></a>
  <a href="https://github.com/chrono-meta/homebrew-forge-harness"><img src="https://img.shields.io/badge/homebrew-tap-FBB040.svg" alt="Homebrew tap"></a>
  <a href="https://github.com/chrono-meta/forge-harness/stargazers"><img src="https://img.shields.io/github/stars/chrono-meta/forge-harness?style=social" alt="GitHub stars"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.ko.md">한국어</a> · <a href="README.zh.md">中文</a> · <b>日本語</b>
</p>

<p align="center">
  <sub>役に立ったら ⭐ が他の人の発見につながります。</sub>
</p>

<p align="center">
  <b>あなたの Claude Code プロジェクトを鍛えて — 通せば、より速く仕上がります。</b><br>
  実務者の<b>メタハーネス (meta-harness)</b> — あなたのプロジェクトハーネスたちが暮らす銀河。<br>各プロジェクトの<b>床 (floor)</b> を上げ（設定をハーネス化）、<b>天井 (ceiling)</b> を上げた上で（作業を加速）、その利得をポートフォリオ全体に複利で積み上げます。
</p>

<p align="center">
  <b>品質が梃子であり、速度はその結果です。</b> あらゆる変更はゲートを通って自らの値打ちを証明します —<br>敵対的 (adversarial) · ファントム (phantom) · 回帰 (regression) — そして<i>それ</i>が次の変更をより速くします。
</p>

<p align="center">
  <i>フォークしてください。名前を変えてください。あなたのものにしてください。</i>
</p>

<p align="center">
  <img src="docs/pillars.svg" alt="FORK · ADAPT · COLLABORATE · EMPOWER" width="680">
</p>

<p align="center">
  <a href="docs/ETHOS.md"><b>原則</b></a> ·
  <a href="docs/WHY.md"><b>存在理由</b></a> ·
  <a href="docs/OUTPUT_EVIDENCE.md"><b>証拠</b></a> ·
  <a href="CHEATSHEET.md"><b>使い方</b></a>
</p>

---

| こんな理由で来たなら… | forge-harness が解決します |
|---|---|
| セッションが終わると文脈が消える | 永続 `tracks/` — どこからでも続きを再開 |
| プロジェクトごとに同じ設定を繰り返す | ハブに一度つなげば全プロジェクトで共有 |
| チームの AI ノウハウが人の頭の中にしかない | コードに刻んで全員で共有 |
| 作業が積み上がるほど AI が*より良く*なってほしい | スキルとパターンがセッションを重ねて複利で積み上がる |
| AI が生成したコードにガバナンス層が必要だ | `fh-gate` がどんなコーディングエージェントでも生成後ゲートで包む |

> **この文書は人間のためのものです。** AI 運用ルール → `CLAUDE.md` · コマンドリファレンス → `CHEATSHEET.md`

---

## 2分で始める

**前提条件**: Claude Code CLI — `claude --version` で確認

<details><summary><b>任意: 1つのゲートが Python + PyYAML を必要とします</b> — 無いと <code>npm test</code> が赤くなります</summary>

同意レジストリ (consent-registry) のゲートは YAML を解析し、解析できないときは**フェイルクローズ**します —
検証されていない同意記録がきれいな記録として読まれてはいけないので、これは正しい挙動です。ただしその
フェイルクローズは、PyYAML の無いマシンでは `npm test`（および `prepublishOnly`）全体を赤にします。そして
2026-08-12 まで、この要件は**どこにも**書かれていませんでした。いまはここに書かれています — そしてこの編集
時点では*ここにだけ*です: `package.json` にもチートシートにも他のどの文書にも依然として無いので、このブロックが
新しいマシンがこれを知れる唯一の場所です。これは「どこにも無い」よりは改善であって、修正ではありません:

```bash
python3 -m pip install --user pyyaml     # 確認:  python3 -c 'import yaml; print(yaml.__version__)'
```

なぜ暗黙のままにせずわざわざ書き出すのか: あるリリースが、`python3` がたまたま**無関係な別プロジェクトの
virtualenv**（PyYAML 入り）に解決されたセッションから緑で出荷されたことがあります — マシン自身の `python3` には
入っていませんでした。ゲートは迂回されたのではなく、通ったのです。ただしその通過が可搬ではなかっただけです。
いまはそのゲートのすべての判定が、使ったインタプリタと PyYAML のバージョンを印字するので、緑が何によって
生まれた緑なのかを読み手の推測に委ねません。

</details>

```bash
# 1. プラグインをインストール
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness

# 2. ハブをクローン
git clone https://github.com/chrono-meta/forge-harness.git ~/projects/forge-harness
cd ~/projects/forge-harness

# 3. セッションを開始
claude
```

> ✅ そのあと**挨拶を打ってください（「hi」）** — 🚪 のドアメニューは*打たれた挨拶*に対して現れるもので、
> 起動しただけでは現れません。
> **「プロジェクトを接続して」** と言えば → ハブが `../` をスキャンして `.git` ディレクトリを見つけ、`tracks/{project}/` を作成します。
> 初期セットアップ一式（フック · ゲート · ベースライン — 項目ごとに個別承認され、断ればそれは尊重され
> 記録されます）が欲しいときは **`/install-wizard`** と頼んでください。
> すでに別の場所にクローン済みですか? そのパスが*あなたの*ハブです — 文書中の `~/projects/forge-harness` は
> すべて、あなたの実際のクローンパスとして読み替えてください。

**最初の15分** — 成功が何に見えるか、そしてそれをどう使うか:

1. セットアップがうまくいったことは、挨拶（「hi」）で 🚪 のドアメニューが出て、「プロジェクトを接続して」で
   `tracks/{your-project}/` ができることで分かります。
2. 次に同じセッションのうちに即効の成果を1つ取ってください: **「このプロジェクトを加速して」**（配線する
   値打ちのあるスキル/プラグインのランク付き計画、インストールはゲート付き）または
   **「`/context-doctor` を回して」**（トークン浪費のスキャン）。
3. 正直な注記が1つ: FH の中核の見返りは**複利**です — セッション記録、収穫された学習、セッションをまたぐ
   記憶。これは**セッション2以降**から効いてきます。初日に手に入るのはメニュー、加速計画、そして
   ガバナンスゲートです。初日で複利を判断しないでください。

途中で見慣れない言葉が出てきたら → [`knowledge/shared/GLOSSARY.md`](knowledge/shared/GLOSSARY.md)。

**プラグインのみ（クローンなし）:**
```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git  # 初回1回
claude plugin install -s user fh-meta@forge-harness
cd ~/projects/{your-project} && claude
```

> ⚠️ **プラグインのみは部分シナジーです。** スキルとエージェントは得られますが、**ハブ側の
> オーケストレーション**は得られません — `CLAUDE.md` のガバナンス（能動オンボーディング、4軸ゲート、
> モード分岐; 自動化層）と、複利で積み上がる文脈（`tracks/` のメモリ蓄積、`harvest-loop` の学習;
> 方法論層）です。
> 各スキルは孤立していても同じように動きます。抜けるのは、それらをセッションをまたいで複利にする
> オーケストレーションのほうです。道具だけでなく全体セットが欲しくなったら、ハブをクローンしてください（上記参照）。

**どの入口があなた向きか?**

| あなたは… | ここから始める |
|---|---|
| 個人開発者、プロジェクト1つ、まず試したい | [`templates/starter_profile.md`](templates/starter_profile.md) — コマンド1つ、厳選された最初の5つのスキル |
| プロジェクトが複数、複利で積み上がるハブが欲しい | ハブをクローン（上のクイックスタート） |
| CI / 非 Claude ランタイム、ゲートだけ欲しい | `npx @chrono-meta/fh-gate`（インストール不要のガバナンスゲート） |
| `npx`/`npm` より `brew` がいい | `brew tap chrono-meta/forge-harness && brew install forge-harness` — 内容は100%同一、インストール体験だけが違います（コミュニティ tap; まだ Homebrew Core には入っていないので、先に tap しないと `brew search` では見つかりません） |

---

## これは何か

forge-harness は**2つの明確な層**で構成されています:

| 層 | 内容 | AI 互換性 |
|---|---|---|
| **方法論層** | `tracks/`, `knowledge/`, `SKILL.md` 文書、セッションプロトコル | あらゆる AI モデル |
| **自動化層** | `plugins/*/agents/` (FH エージェント)、`.claude/agents/` (フィールドプロジェクトのオーバーライド)、フック、スラッシュコマンド、`CLAUDE.md` ルール | Claude Code 専用 |

方法論層は移植可能な核です — 永続ハブ、学習の蓄積、プロジェクト間の知識キュレーション。自動化層は Claude Code 上でこれを摩擦なく動かします。

**これが立つ位置 (2026):** 「ハーネスエンジニアリング」はいまや公開パラダイムであり — 基本的なエージェント
オーケストレーションは急速に標準インフラへと商品化されています。FH はその配管 (plumbing) に何も賭けて
いません。FH の永続層は*商品化されないもの*です: ガバナンスゲート（敵対的 · ファントム · 回帰）、ドリフト
制御、そしてプロジェクト間の複利ループ。ルーティングとディスパッチは手段であり、**ゲートとループが資産です。**

```
forge-harness/   ← ハブ (永続する脳)
├── knowledge/   → 全プロジェクトで共有
└── tracks/      → プロジェクト別の作業記録

Project A  ──→  CLAUDE.md でハブを接続
Project B  ──→  CLAUDE.md でハブを接続
```

---

## ツールボックスではなくハーネスである理由

まず、ハーネスが*何のためにあるのか*から: ハーネスはあなたの**意図**を読み取り、**機械化された形**
へと鍛え上げます — AI が確実に従うルール、あるいはモデルを一切必要としない決定的なコードへ。
あなたが意図と洞察を渡し、ハーネスがそれを実行可能な形に鍛え、あなたが承認すれば、それは機械に
なります。見返りは**人間側の試行錯誤の最小化**です: リクエスト → フィードバック → 再生成のループは
消えるのではなく、*場所を移す*のです — ハーネスの内部へ、エージェントとサイドカーが並列で回す
場所へ — その結果あなたの時間は減り、あなたの注意は変更が不可逆な地点にだけ使われます。

スケールが第二の要点です。**スキル · エージェント · プラグイン**は1つの道具です。**ハーネス**は一段上 —
1つの*星 (star)* です: あるプロジェクトの道具 · ルール · ゲート · 記憶が、1つの働く体へと束ねられたもの。
**forge-harness はその星たちが暮らす銀河です**: 複数のハーネスを共通の床の上に束ねてドリフトを防ぎ、
散り散りになる代わりに共に進化させます。

この銀河はただの容れ物ではありません。FH はフィールドハーネスを**自らのサンドボックス内で
シミュレーションとして走らせることができ** — 1回あたりは高くつきますが、試行錯誤が一箇所に集まり
複利で積み上がるため総コストは安くなります — シミュレーションが検証されれば、その
プロジェクトを独立した特化ハーネスとして**送り出します (EMIT)**。**この最後の一歩は目指している目標で
あって、出荷済みの機能ではありません** — インキュベーションチャンバーが送り出したのは1回きりで、それを
生んだランは完全なフローを通っていません。シミュレーションして送り出すという文は*進む方向*として
読んでください。その手前にあるものはすべて、今日すでに使われています。

### 5つの正体 (five identities) — FH は何のためにあるのか

これは5つのモジュールではなく、5つの出荷済み機能でもありません。スキルが**固まっていく形**の名前です —
上に載せた新しい層ではなく、スキルとエージェントに散らばって既にそこにあったものに名前を付けたもの
です。これはこのページ冒頭の課題表とは別のレベルにあります: あの表は*あなたが抱えて来たかもしれない
症状*であり、こちらは*ハブが何を軸に組み立てられているか*です。

| | 正体 | 人が手にするもの |
|---|---|---|
| **①** | **マルチハーネスクラスター** | 1つの作業が複数のハーネスに乗り、ガバナンスはその*あいだ*で計算されます |
| **②** | **プロジェクトインキュベーター** | 新しいハーネスが空のスキャフォールドではなく、**生まれた場所で既に歩ける状態**で出てきます |
| **③** | **ガバナンスゲート** | 出してはいけないものが、覚えて確認する代わりに**機械的に**止まります |
| **④** | **フロンティア → 組織への伝播** | 外から届いたものが、組織の*内側*まで届ききります |
| **⑤** | **増幅器 (Amplifier)** | 短い意図が、完成した成果物まで鍛え上げられます |

**5つが等しく仕上がっているわけではなく、この表を「5つの動く機能」として読んではいけません。** 成熟度は
正体ごとに4段階（`aspirational → partial → RC (ラボで立った) → REALIZED (外を歩いた)`）で追跡され、
それぞれに日付入りの証拠の行が付いています。その等級はここには**あえて写しません**: 2つのファイルに
置かれた等級は片方が必ず腐りますし、このページは4言語で存在するので、ここに写せば写しは4つになります。
上のどの行かに頼る前に、現在の等級を読んでください — それはファイル1つです:
[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md)。1文だけ欲しいなら、
**2026-08-15** 時点で: **③ と ⑤ は緑 — ラボの外で実証済み。①, ②, ④ はリリース候補 — 作られ較正されて
いますが、他人の手の中で歩くところはまだ示されていません。** この文とゲートファイルが食い違ったときは、
ゲートファイルが正しく、この行が古いということです。

5つすべてを横断する性質が2つあり、どちらもオンにする機能ではありません:

- **フロンティアに継ぎを当てるのではなく、フロンティアに乗ります。** FH はファミリーをまたいで
  ディスパッチします（Claude, Codex, Gemini, ローカル）— ただし要点は各モデルの弱点を埋めることでは
  *ありません*。そうしたスキャフォールディングはモデルが強くなれば死ぬからです。これは共進化です:
  substrate がいまやネイティブでやってくれるものは脱ぎ捨て、次に出してくるものは吸収します。
  **脱相関 (decorrelation)** が*いまの*信頼の梃子であり、このページで最も荷重を担う言葉です:
  2つの検査が*違うかたちで*失敗するように意図的に仕組むこと — 別のモデルファミリーからのレビュアー、
  実際の対象に対する1回の実行、自分の記録に対する外部からの監査 — そうすれば一方が見えていないものを、
  もう一方は見ています。クロスファミリーのパネルが単一モデルの天井を超えるのはまさにその理由であって、
  規模が大きいからではありません。
- **2つの方向へ進化します。** *外へ*、各セッションの教訓がハブに複利で積み上がり、次のプロジェクトが
  より先から始まります。*内へ*、**自分自身の**欠陥を捕まえて直します — 同じゲートを、ハーネス自身に
  向けたものです。

全体は1つの分業です: **raw な能力はモデルのもの、組み立て · 信頼 · 進化はハーネスのもの。**

---

## どう作られているか — 工程 → エンジン → 正体

上の5つの正体は表面です。その下に2つの層があり、3つすべてに名前を付けることが「FH は何をするのか」が
1つの未分化な塊に潰れるのを防ぎます:

```
5つの正体      人が実際に使えるもの              (表面 — 手に入るもの)
   ↑ 支えているのは
4大エンジン    それを可能にする能力              (能力 — できること)
   ↑ 生み出しているのは
3段工程        そのエンジンを鍛える「順序」      (工程 — どう作られるか)
```

**4大エンジン。** それぞれが上のいずれかの正体を足元で支えています。これらはこのページのために発明された
ものではありません: 出荷準備ゲートが既に、すべての正体をこの同じ4つの能力に対して専用の列で採点して
いました（[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md)）。ですから
名前を付けたのは、分類体系を作る作業ではなく認識でした。

| エンジン | 何であるか | 支える正体 |
|---|---|---|
| `judgment-circuit` | 何を成功とするか、不確実なときどちらへ倒すか、何が範囲外か、何は決してやらないか — **判断の座標系** | ⑤ 増幅器 · ② インキュベーター |
| `ship-gate` | 不可逆な表面の手前での機械的な遮断 — commit, publish, delete, rewrite | ③ ガバナンスゲート |
| `context-continuity` | 圧縮 · サブエージェント · マシン · セッションをまたいで筋を見失わないこと | ① クラスター · ② インキュベーター |
| `external-grounding` | 新規性を主張したり設計を決めたりする*前に*、レポの外へ手を伸ばすこと | ④ フロンティア → 組織 |

エンジンは常に名前で書き、番号では書きません — ここの表の順序と他所の散文の順序は異なるので、
「エンジン④」はどちらを読むかで2つの別のエンジンに復号されてしまいます。

`judgment-circuit` はもっとも誤読されやすいので、はっきり書きます: **これは「決めるための座標系」で
あって、ハーネスが何者であるかの表明ではありません。** その行にある4項目がこのエンジンのすべてです。
日本語で「魂」のような1語に言い換えないでください — その語は*ペルソナ*として読まれますが、このエンジンの
背後にある測定（105ラン、アイデンティティ宣言の有無でプロンプトを比較）の最大の発見は、まさにその2つが
別物だということでした:「あなたは〜だ」を加えると、試した中で最も弱いモデルで*正味の損失*として現れ、
それを取り除くと元に戻りました。1語の言い換えは、その測定が切り分けたものをそのまま再融合させてしまいます。
数値そのものはここではあえて引用しません — 出典がスケールを記録しておらず、スケールの無い数値を表紙に
置けばそれは装飾だからです。数値は文脈込みで
[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) にあります。また判断回路は
一度に作られるものでもありません: FH は新しいハーネスに**種となる草案**を渡し、そのハーネスが実際に
使われるなかで埋まっていきます。

**3段工程** — これはメニューではなく*投資の順序*です:

```
① 設計の前に回路を        判断回路が最初に入ります — 成功 · 傾け方 · 範囲外 · 決してやらないこと —
                          やったことの記録として後から書き起こすものではありません

② 中間では脱相関して      作業を「違うかたちで失敗する」検査に分けて、一度に走らせます。どの違いが効くかを
   加速する               選んでください — 同じ種類のレビュアーをもう1人足すのは脱相関ではなく、同じ盲点を
                          2度持つだけです。並列化それ自体には方向がなく、選ぶのは①の判断回路です。
                          これは「働き方」であって、③の最終検査ではありません。

③ 最後に4つの軸で         下の4軸です。敵対的レビューはそのうちの1つであって、全部ではありません
   焼き切る
```

**4つの検証軸** — 「レビューしました」が実際には最初の1つだけを指していた、と判明しがちな場所です。
真ん中の列を読んでどれを取るかを決め、右の列でそれが何を捕まえるかを確かめてください:

| 軸 | こういうときに手を伸ばす | 何を捕まえるか | 典型的な計器 |
|---|---|---|---|
| **ⓐ 別ファミリー** | その変更が何かを決めるとき — PASS/FAIL、ゲート、安全ルール | **実装**が間違っている | 別のモデルファミリーからのレビュアー (`auto-decorrelation`) |
| **ⓑ 初の実使用** | 数値 · カウント · スキャンの出力を信じようとしているとき | **測り方**が間違っている | 実際の対象1件に対して一度走らせ、結果を自分の目で見る |
| **ⓒ 記録のグラウンディング** | 他人がそれを元に動く主張 · 数値 · 引用を書き留めたとき | **主張**が間違っている | 書いていない誰かが、書かれている内容を測り直す |
| **ⓓ 戻して観察する** | テスト · ガード · 検査を足して、それが自分を守っていると思っているとき | **アンカー**が間違っている — その検査は装飾だ | 守っている対象を消して、*その特定の*検査が赤くなることを確かめる |

**4つを毎回すべて回すわけではなく、それが設計です。** 1行の修正はどれも要求しません。verdict を返す
変更は ⓐ を要求します。公表する数値は ⓑ と ⓒ を要求します。新しいガードは ⓓ を要求します。不可逆な
表面 — publish, delete, 履歴の書き換え — は、その失敗モードがさらしている軸を要求し、迷ったときは
もう1つ回すほうに倒します。レビュアーを増やすことは、軸を1つ足すことと同じではありません。

これら4つの外側に、もう1つの軸があります。それは*何を*検査するかではなく、*誰の*グラウンドトゥルースに
立つかを変えるからです: **standpoint（立ち位置）** — 変更が別のハーネスへまたがるとき、自分の読み方では
なく、対象側自身のレポとルールから diff を走らせてください
([`field_verdict_crossfamily_gate.md §7`](knowledge/shared/harness-core/field_verdict_crossfamily_gate.md))。

> **正直な注記 — これはきれいな積み木ではなく、そこが要点です。** 段階①と段階③はエンジンと同じ素材で
> できているので、下の層が上の層を使っています。この矛盾は*主語*で解けます: **エンジン**は FH が
> あなたの作業に適用するものであり、**工程**は FH が自分自身のエンジンを鍛えるときに使う順序です。
> 手法を外から借りてきたのならエンジンとは無関係だったはずで、この重なりこそがドッグフーディングの
> 指紋です。各主張の背後にある標本の限界を含む完全な正典:
> [`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md)。

> **ここでのセルフヒーリングは主張ではありません — 確かめてください。** このレポの `git log` がその記録で
> あり、同じ形が繰り返されます: 見落としが捕まり、その修正が攻撃され、そして攻撃は元のものではなく
> *修正のほう*に当たることが多い。ハッシュで開けるものが1つ — `cb74ea4`、ハーネスがセッション途中で
> レジスターをドリフトさせたあと、`CLAUDE.md §Voice/Tone` にレジスター一貫性のルールが加えられたコミット
> です。もう1つは、この節を追加したのと同じ変更のなかで: 「何にも走らされていないテスト」を見つけるのが
> 仕事そのものである検査器が、あるスクリプトの*自分自身のコメント*から緑のカウントを報告しているのが
> 捕まり、さらにそれを直すために書かれたガード自体が、消しても失敗するテストを1つも持っていないことが
> 判明しました — 見つけたのは著者ではなく別のモデルファミリーで、実際に失敗するフィクスチャを付けて
> 閉じられました。フィーチャーブランチ上のコミットハッシュは squash-merge を生き延びないので、こちらは
> 腐る ID ではなく「その形」で引用しています。

---

## 動く理由

AI と長い共同執筆セッションを経ると、あなたと AI は同じ文脈を共有します — そして同じ盲点も
共有します。持つ価値のあるレビュアーは、あなたの推論を一度も見たことのないレビュアーです。手作業でも
得られます: 作業を空の新しいチャットに貼り付ければいいのです。FH はその面倒な作業をコマンド1つの
ルーティンに変えるだけです。

- **サイドカー / エージェントディスパッチ** → あなたのセッションの文脈がまったくないレビュアー
- **steel-quench · phantom-quench** → その冷静な検討を、必要なときにすぐ

モデルに依存しません: ある AI と一緒に作り、冷静な検討は他のどの AI ででも回します。もともとの
セッションにいなかった側があなたの冷静なレビュアーです — これはモデルの順位付けではありません。

**FH が主張しないこと:** 冷静な検討はあなたのベースモデル自身の能力であって、FH が追加する検知
エンジンではありません — 新しいインスタンスに普通のプロンプトを入れても、かなりの部分で同じことをします。FH の価値は
より狭く正直です: 実際の実務から出た方法を取り、その独立した検討を*スキップする面倒な作業*の代わりに
*ルーティン*にします。方法論はコピー可能であり、FH がパッケージするのは秘伝のソースではなくワークフローです。

---

## AI 生成コードのためのガバナンス層

FH はどんなコーディングエージェント（OpenCode, Codex など）でも**生成後ガバナンスゲート**で包みます。

```bash
npx --package @chrono-meta/fh-gate fh-gate                    # 既定: Claude バックエンド
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate   # Codex バックエンド
FH_BACKEND=auto npx --package @chrono-meta/fh-gate fh-gate "src/foo.ts" full
# → FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE

# または Homebrew 経由（内容は同じ、インストール後は npx 接頭辞不要）:
brew tap chrono-meta/forge-harness && brew install forge-harness
fh-gate
```

`fh-gate` は両ランタイムに同じ FH ガバナンスプロンプトを使います。`FH_BACKEND=claude` は `claude --print` を、`FH_BACKEND=codex` は `codex exec` を実行し、`FH_BACKEND=auto` は両 CLI が揃っていれば Codex を優先します — ただし `auto` はフォールバック*選択*であり、レグは 1 つだけ走ります。`FH_BACKEND=cross` は両ファミリーを走らせて findings を union します(一方だけが見つけた指摘も指摘なので、投票ではなく union)。判定はレグ中で最も重いものです。コストは約 2 倍なので既定ではなく、判定・ゲート・不可逆な面の変更に使います。出力は実際に走ったレグを常に明示します(`FH_GATE_LEGS:`、`FH_GATE_DECORRELATED:`) — 片方のファミリーしかない環境では単一レグに縮退し、その事実を明記します。

Claude Code の外でスキルやエージェントを直接実行するには `fh-run` を使います:

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run --skill phantom-quench --file docs/foo.md
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run --agent fh-commons:quench-challenger --file plugins/fh-meta/skills/foo/SKILL.md
```

変更された FH スキル/エージェント表面が依然としてきれいな Codex アダプター経路を持つか確認するには:

```bash
npx --package @chrono-meta/fh-gate fh-codex-doctor --strict
```

`fh-codex-doctor` は正典のスキル/エージェントレジストリをスキャンし、どのユニットが Codex ネイティブか、アダプターが
必要か、Claude ネイティブか、未分類かを報告します。薄いアダプター境界のドリフト検知器であり、Claude
Code の自動化層を複製しようとはしません。FH チェックアウトから実行すれば現在の作業ツリーを、外から実行すれば
インストール済みパッケージをスキャンします。

Codex 主導の作業では、可能な限り Codex のネイティブな goal/session 機能を使い続けてください。`fh-goal` は FH
ガバナンスが後に続くべき一度きりの非対話実行のための移植用ラッパーにすぎません:

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-goal --prompt "Implement X and update tests" --gate quick
```

より広い FH 自動化層は、依然としてサブエージェント · フック · スラッシュコマンドのために Claude Code に依存します。移植
経路は共有文書 + ランタイムアダプターであり、別々の Codex フォークと Claude フォークではありません。

**推奨スタンス — Claude Code をオーケストレーターに、他をサイドカーに。** FH の自動化層（自動発火フック、
サブエージェントディスパッチ、オンボーディング、メモリ）は Claude Code ネイティブなので、もっとも完全な体験は **Claude
Code をメインオーケストレーターとし、Gemini, Codex, または Antigravity (`agy`) を能動的に使う
サイドカー**として回すことです。**非 CC ランタイムをメインエージェント**として回すこともできます —
`fh-gate`/`fh-run` を通じて方法論層全体と M1 スキルは維持されますが、オートパイロット層は得られません:
フックが自動発火せず、M2 エージェントディスパッチ段階はアダプター（または対話的承認）が必要で、M3
スキルは参照用です。これは意図された2層の境界であって、埋めるべきギャップではありません。ランタイム別の詳細:
[`docs/codex-compat.md`](docs/codex-compat.md) (ティア別) と
[`multi_model_sidecar_strategy.md`](knowledge/shared/harness-core/multi_model_sidecar_strategy.md)
(サイドカーエンジン、2026-06-18 EOL 時点の Gemini→`agy` 承継を含む)。

**実証結果 (2026-05-31)**: OpenCode の AI 生成 `permission/arity.ts`（163行、CI グリーン）に適用。
現在のゲート意味論はこれを BLOCKED に分類します: CI が捕まえられなかった A 級の発見 2件（許可リストの短トークン
オーバーフロー、arity テーブルから抜けた executor ツール）。

完全な仕様: [`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md)

---

## 鍛冶場 (The forge)

forge-harness はプロジェクトを鋼のように扱います — そしてこの比喩は装飾ではなく文字通りです。
作業は形を与えられ、攻撃で硬くなり、そうして生き延びたからこそ、はじめてより速く出荷されます。

| 工程 | 何が起きるか | コマンド |
|---|---|---|
| **鍛え (Forge)** | 生のプロジェクトをハーネスへ形づくる — その床を上げる | `install-wizard`, "harness-ify this project" |
| **焼き入れ (Quench)** | 攻撃で硬くする — 冷静な検討が健全なものだけを残す | `steel-quench` · `phantom-quench` |
| **焼き戻し (Temper)** | 硬くなった資産から脆さ (brittleness) を再び抜く | `steel-quench` Wave-T · `templates/temper_check.sh` |
| → **加速 (Accelerate)** | 鍛冶場を生き延びた刃はより速く斬る | `goal-quench` — *Pass → Accelerate* |

4工程すべてが出荷されます。焼き戻し (Temper) は作られる*前に*名前が先に付けられ — 意図的に（参照:
[`ETHOS.md`](docs/ETHOS.md#the-forge)）— 測定実行が検証したのちに出荷されました。鍛冶場の周りで、さらに2つの
シグネチャが回り続けます: `harvest-loop`（各セッションの教訓が恒久スキルになる）と
`agent-composer`（ディスパッチをオーケストレーション）。残りのスキルは必要になるまで待ちます — 全リストは
下に。

## 40 skills · 8 agents

> カウント = 非 deprecated のスキル（旧名ルーティングのためだけに残されている deprecated
> リダイレクトスタブは除外）。

<details>
<summary>全資産のアクティベーション確認</summary>

| 資産 | 役割 | トリガー |
|---|---|---|
| `steel-quench` | 全方位の敵対的検証 | "Run the quench", "Attack from the root" |
| `phantom-quench` | ファントム主張の検知 + ソース逆追跡 | "Verify the source", "Grounding audit" |
| `harvest-loop` | セッション終了の学習 → 進化パイプライン | "Harvest the session" |
| `agent-composer` | 最適なエージェントディスパッチを設計 | "Run in parallel", "Which agents?" |
| `sim-conductor` | メタシミュレーションオーケストレーター | "External user perspective" |
| `context-doctor` | トークン効率 + `.claudeignore` | "Session is slow", "Clean up context" |
| `harness-doctor` | ハーネス構造の診断 | "Check my Claude setup" |
| `pipeline-conductor` | 4軸品質ゲート (後方/敵対/前方/記録) | "Run the quality gate" |
| `field-harvest` | フィールドパターンをハブへ逆伝播 | "I could reuse this" |
| `dialogue-harvest` | AI 対話ログの採掘: 追従 (sycophancy) を剥がし、誘導された主張と独立した主張をラベル分け | "What did I actually contribute in this thread?" |
| `frontier-digest` | HN + arXiv → 実行可能な洞察 | "AI trend digest" |
| `hub-cc-pr-reviewer` | 自動 PR レビュー | "Review this PR" |
| `verify-bidirectional` | 決定の逆検証 | "Is that right?", "Double-check" |
| `deep-clarify` | ソクラテス式の要件明確化 | "I'm not sure what to build" |
| `install-wizard` | 初期オンボーディング | "First-time setup" |
| `plugin-recommender` | プラグイン推薦 | "Is there a good tool for this?" |
| `apex-review` | 経営層視点の品質レビュー | "Will this hold up?" |
| `meta-prompt-builder` | メタプロンプト設計 | "Write a prompt for the agent" |
| `asset-placement-gate` | ハブ vs プロジェクトの資産ルーティング | "Should this be shared?" |
| `cross-ecosystem-synergy-detection` | ツール間シナジーの発見 | "Are my tools working together?" |
| `corpus-grounding-expander` | 多バージョンのパブリックドメインコーパス → 検証済み公理グラウンディングストア | "Broaden the grounded corpus" |
| `persona-roster-expander` | ペルソナのシード → ティア別・判断マッピングされたキャスト | "Broaden these personas" |
| `convergence-loop` *(fh-commons)* | N ラウンドの収束ループ | "Single-pass seems suspicious" |
| `token-budget-gate` *(fh-commons)* | 作業前のトークンコスト推定 | "How expensive is this?" |
| `mcp-circuit-breaker` *(fh-commons)* | MCP ツールの失敗パターン検知 | "MCP keeps failing" |
| `ko-tech-writer` *(fh-commons)* | 韓国語テクニカルライティングのパイプライン（レジスターの較正、翻訳調の除去、正直さの層分け、知覚的 QA） | "기술문서 써줘", "번역투 고쳐줘" |
| `quench-challenger` *(fh-commons)* | 敵対的プレッシャーテストエージェント | "Challenge this with a devil" |
| `auto-decorrelation` | 負荷を担う変更に対して別モデルファミリーのレビュアーを招集 | "Decorrelate this verification" |
| `video-ingest` | 動画 → エージェント文脈へ、能力と長さでルーティング | "What does this video show?" |
| `fh` | 挨拶なしで、必要なときにハブマップを描画 | "fh" |
| *(+ 残りのスキル)* | marketplace-gate · contention-layer · deliberation · edit-manifest · goal-quench · install-doctor · memory-hygiene · prompt-regression · public-surface-audit · return-path-gate · salience-splitter | |
| **8 エージェント** | `challenger` · `quench-challenger`（敵対）· `beginner` · `main-player` · `expert`（ユーザー習熟度スペクトラム — 冷たい初読、日常利用、ドメイン権威）· `fact-checker` · `hub-persona-auditor` · `persona-innovator` | 上記スキルから、または名指しでディスパッチ |

| アクティブ数 | 診断 |
|:---:|---|
| **表面の半分かそれ以上** | 上級 — agent-composer + sim-conductor + steel-quench + pipeline-conductor を連鎖 |
| **ひと握りからそこまで** | アクティベーション段階 — 未チェックの資産を段階的にオンにする |
| **ほとんどなし** | 初期段階 — `install-wizard` から始める |

> このバンドはおおまかな自己点検であって、測定ではありません — 閾値を定義した成果物は存在せず、
> 以前の固定された数値はもっと小さいロスターに対して較正されたものだったので、ロスターが増えるにつれて
> 静かにずれていきました。スキルを多く使うこと自体も目標ではありません — 自分の作業が実際に必要と
> するものを使うことが目標です。

**やりたいことでスキルを探す:**

| クラスター | スキル |
|---|---|
| 検証 | `steel-quench` · `phantom-quench` · `convergence-loop` · `prompt-regression` · `return-path-gate` |
| オーケストレーション | `agent-composer` · `pipeline-conductor` · `goal-quench` · `deliberation` |
| 診断 | `harness-doctor` · `context-doctor` · `install-doctor` · `mcp-circuit-breaker` |
| 収穫 / 学習 | `harvest-loop` · `field-harvest` · `edit-manifest` · `memory-hygiene` |
| ゲート / ガード | `token-budget-gate` · `asset-placement-gate` · `marketplace-gate` |
| 発見 | `plugin-recommender` · `cross-ecosystem-synergy-detection` · `frontier-digest` · `verify-bidirectional` |
| コンテンツ / シミュレーション | `sim-conductor` · `apex-review` · `meta-prompt-builder` · `deep-clarify` |
| 設定 | `install-wizard` · `hub-cc-pr-reviewer` · `salience-splitter` |

> **完全フレーズ集** — すべてのスキル + エージェントとその一行定義、そしてそれを発火させる平易な表現:
> [`CHEATSHEET.md` §12](CHEATSHEET.md#12-skills--agents--what-each-does-and-what-to-say).

</details>

---

## モデル設定

Claude Code は作業の複雑さでモデルを自動選択しません — これは一度だけ設定します。

```bash
/model sonnet   # 推奨既定値 — FH が重要な箇所には自ら強いモデルをディスパッチ
```

| コマンド | 誰が何を実行 | 最適な用途 |
|---|---|---|
| `/model sonnet` | Sonnet セッション; FH が宣言された床 (floor) で上位ティアのサブエージェントをディスパッチ | **FH 既定値** — 運用 + 日常開発 |
| `/model opus` | Opus がすべてを処理 | ハーネス編集セッション (Mode D) · 毎ターン最大の深さ |
| `/model opusplan` | Opus が*計画* · Sonnet が実行 *(Opus が関与するとき)* | コスト意識の日常コーディング — 注意点を参照 |

**なぜいま Sonnet 既定値で通用するのか**: 測定結果（下記 *主張ではなく測定* を参照）、FH *運用*はほぼ
モデルフラットです — 文脈に入ったルールが大部分の仕事をします。それでも強いモデルが必要なのは深さに
敏感な少数のターンで、FH はそれを自ら処理します: **一部のスキルとエージェントはモデルティアの床を
宣言**し（例: `quench-challenger` は opus に床）、環境が届けばその床ティアの
サブエージェントとしてディスパッチされます — あなたのセッションモデルには触れません。**FH は決してあなたの
セッションモデルを変えません**: 手で設定した既定値はそのまま従い、床は FH 自身のサブエージェント
ディスパッチにのみ適用されます。環境が床より低いところで上限になると（例: Sonnet 専用 API ルーティング）、床が
かかった資産は依然として利用可能な最良のティアで実行され、出力に明示的な `below-floor` フラグを付けます —
劣化した提供は見えるように、決して静かに済まされません（ティア床の解決:
`knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Tier-floor`）。

**`opusplan` の注意点（測定済み）**: Opus の関与は**保証されません** — 測定した10ターンの実行で Opus を
**0**ターン使いました（CC が "plan-mode" に分類するターンが少ない）。毎ターン Opus を望むなら `/model opus` で
固定してください（後続の実行で 22/22 ターン Opus）。**サブエージェントディスパッチ**のモデルはディスパッチ自体の `model`
パラメーターで決まります; セッションモデル/plan-mode はサブエージェントへ伝播し**ません**。

> **役割別**: FH 運用（フィールドプロジェクト、ゲート、日常開発）→ `/model sonnet` + 床にエスカレーションさせて
> おく。ハーネス自体の編集 (Mode D) → 持っている最強のモデルを固定 — ハーネスの*自己開発*はティアの深さが
> 測定可能なかたちで値打ちを払う場所であり（設計増分の発見）、運用はそうではありません。サブエージェントのトークン
> コストはセッション jsonl の `message.model` から CC で見られます。

**主張ではなく測定**（実測例）: ブラインドのルール適用バッテリーで FH *運用*はほぼモデルフラットです —
30点のブラインドバッテリー（2026-06-10）で走らせた4ティアは **94–100%** を記録し（最上位ティアのアンカー /
Opus 4.8 / Sonnet 4.6 / Haiku 4.5 = 100 / 100 / 97 / 94）、2026-07-03 の再現では Opus 4.8 · **Sonnet 5** ·
Haiku 4.5 がそれぞれ 16/16 で再アンカーされました。丸い1つの数字ではなく、正直な注記を2つ: 出典の成果物は
最上位ティアの名前を意図的に伏せているので、このページでも名前を出しません。そして**現在の**最上位ティアは
このバッテリーで走らせていません — 先に持ち越されるのは下のドクトリンであって、スコアではありません。
失った少数の点数は
フォーマットの規律であって、罠やゲート級のミスではありません。ティアが分かれるのはルーブリック超過の*設計*
増分だけ（ハーネスを開発するのであって運用するのではない）— だから既定値が**ティア床ディスパッチ**で深さに
敏感なターンを覆う Sonnet であり、固定された強いモデルはハーネス編集セッションにのみ推奨されます。

これは**不変式として述べられ、モデル別のリーダーボードではありません。** 新しいリリースが覆せない2つの構造法則:

1. **運用はティアをまたいで平坦化する** — 文脈のルールが仕事をするので、あらゆるティアがルール適用で天井に
   届きます（2026-07-03 の再現で Sonnet 5 がバッテリー天井で Opus 4.8 と同率）。
2. **深さ（設計増分）はティア順序であり、その順序は*ある世代の中で*固定される** — 低いティアが**同じ**
   世代の高いティアを決して追い越しません（ティアは値打ち通りに価格付けされるので、ベンダーが順序を
   維持します）。*世代をまたいで*は、新しい低ティアのモデルが古い高ティアを超えることがあります（運用での
   Sonnet 5 ≥ Opus 4.8 がまさにこの世代交差のケース）— しかしどの世代でも現在の最上位ティアは依然として
   自らの深さターンで勝ちます。

だからドクトリンは恒久的で、腐りません: **運用は中間ティアを既定値に; 深さは現在の最上位
ティアへエスカレーション。** 再測定が正当なのは新しいモデルがフィールドメインの*候補*になるときだけ（一度きりの世代交差の
閾値確認）であって、同世代のティア順序を再確認するためではありません — それは設計で保証されます。詳細 +
日付別の実行: `docs/OUTPUT_EVIDENCE.md` §Validation signals.

外部 CLI（Gemini, Codex, `gh copilot`）をサイドカーとして使うと、そのコストは各自のクォータに請求され、CC のトークン表示には見えません。

### ハードウェアティア（ローカルサイドカーは任意のアクセラレーター）

FH は**ローカル LLM を必要としません** — 基準線は Claude Code を動かす何であってもです。ローカルモデルは
*任意*であり、カナリア / 低コスト幅出しの段だけに使われます:

| ティア | 仕様 | ローカル実行 | 何が得られるか |
|---|---|---|---|
| **最小** | Claude Code を動かす何でも | なし | 方法論 + ゲートすべて; FH 運用は測定したすべてのティアで ~モデルフラット (94–100%) |
| **推奨** | ラップトップ級、~16GB RAM | 8B 級の量子化モデル1つ（例: 8B / 小型 Gemma） | トークン無料の**床カナリア**（課金される sim の前の事前スクリーン）· オフライントリアージ · 低コスト幅出しのパネルアーム |
| **任意（ヘビー）** | ~24GB VRAM GPU | 27–32B モデル | *より強い*脱相関カナリア |

> ローカルティアは**カナリアであって最終判定では決してありません** — 測定: 床モデルはフロンティアが捕まえた微妙な
> 敵対ケースを見逃しました（27–32B のローカルでさえそのケースで 1/4）。ローカルは*幅出しのコスト*を
> 下げるだけで、判定はフロンティアに残ります。

---

## マルチモデルサイドカー

Gemini, Codex, または `gh copilot` を Claude の隣で独立したレビュアーとして回します。要点は**文脈の隔離**です:
作業を一緒に作ら*なかった*レビュアーはその泡 (froth) に冷静です — 協業の*外*に座る者が、いまや共有された
結果の擁護者となった共同著者が滑らかに見過ごしたものをよく捕まえます。これは対称的で、モデル順位ではありません:
Gemini と一緒に作れば新しい Claude がその泡を捕まえ、Claude と一緒に作れば新しいサイドカーが Claude の泡を捕まえます。

ある内部のケーススタディでは、レビュアーを層に重ねるほどより多くの問題が明らかになりました — 単一のセッション内パスが
見逃した項目をセッション間のペルソナが捕まえ、外部 CLI のレビュアーが Claude のペルソナたちが共有した盲点をいくつか
明らかにしました。これをベンチマークではなく**実測例**として扱ってください: 利得は作業の複雑さと成果物をどれだけ
共同創作したかに比例して大きくなり、隔離されたレビュアーはトリアージすべき誤検知 (false positive) も加えます。
与えられた作業で純利得が値打ちあるかは、経験的で使うたびに異なる問いです。

レビュアーが外部 CLI のとき Claude 側のトークンコストは増えません — 各自のクォータに請求されます。

---

## 研究 (Research)

> **FH 論文** — 以下の方法論は主張だけでなく文書化されています:
> - **v1.0 — 方法論** · [Zenodo](https://zenodo.org/records/20397566) (DOI 10.5281/zenodo.20397566). 2層設計、6軸フレームワーク、4エージェントオーケストレーション、そして複利ループを実証証拠とともに。
> - **cs.SE companion — ガバナンスゲート方法論** · **掲載済み** [Zenodo](https://zenodo.org/records/20680081) (DOI 10.5281/zenodo.20680081 · 最新 v1.1 10.5281/zenodo.20740038 · CC-BY-4.0) · arXiv 提出済み (cs.SE); モデレーションの結果はこのレポでは追跡していないので、「提出済み」は
>   このページが保証できる最後の状態であって、現在の状態ではないものとして読んでください。
> - **cs.AI companion — "Governance Dividend"** · 準備中。

外部の収束:
- ["Dive into Claude Code: The Design Space of Today's and Future AI Agent Systems"](https://arxiv.org/abs/2604.14228) — arXiv 2026年4月
- ["Code as Agent Harness"](https://arxiv.org/abs/2605.18747) — arXiv 2026年5月
- Stanford IRIS Lab: ["Meta-Harness"](https://arxiv.org/abs/2603.28052) — 4倍少ないトークンで +7.7pts

---

## もっと知る

| リソース | 目的 |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | AI 運用ルール + 同期/プッシュプロトコル |
| [`CHEATSHEET.md`](CHEATSHEET.md) | 全コマンドリファレンス |
| [`AGENTS.md`](AGENTS.md) | ランタイムエージェント仕様 |
| [`CATALOG.md`](CATALOG.md) | 過去作業の検索インデックス |
| [`CONTRIBUTING.md`](docs/CONTRIBUTING.md) | スキルとパターンの貢献方法 |
| [`tracks/_contrib/`](tracks/_contrib/README.md) | **同意レーン** — 非識別化した作業セッションを共有; レポがローカルだけでなく運用者たちにまたがって複利で積み上がる |
| [`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md) | ガバナンスゲート仕様 |
