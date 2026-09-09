<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/banner.png" alt="forge-harness — プロジェクトを鍛え、通せば、より速く仕上がる。品質が梃子であり、速度はその結果だ。" width="680">
</p>

<p align="center">
  <a href="https://github.com/walkinglabs/awesome-harness-engineering#coding-agent-harnesses"><img src="https://awesome.re/mentioned-badge.svg" alt="Mentioned in Awesome Harness Engineering"></a>
  <a href="https://github.com/VoltAgent/awesome-agent-skills#community-skills"><img src="https://img.shields.io/badge/listed_in-awesome--agent--skills-0ea5e9.svg" alt="Listed in awesome-agent-skills"></a>
  <a href="https://github.com/anthropics/claude-code"><img src="https://img.shields.io/badge/Claude_Code-compatible-a855f7.svg" alt="Claude Code compatible — official Claude Code repository"></a>
  <a href="https://chrono-meta.github.io/forge-harness/"><img src="https://img.shields.io/badge/whole_map-interactive-6366f1.svg" alt="FH whole map — interactive diagrams on GitHub Pages"></a>
  <a href="https://github.com/marketplace/actions/fh-gate-typed-ai-code-review-verdict"><img src="https://img.shields.io/badge/GitHub_Action-marketplace-2088FF.svg" alt="GitHub Actions Marketplace — fh-gate"></a>
  <a href="https://www.npmjs.com/package/@chrono-meta/fh-gate"><img src="https://img.shields.io/npm/v/@chrono-meta/fh-gate.svg?color=cb3837" alt="npm"></a>
  <a href="https://github.com/chrono-meta/homebrew-forge-harness"><img src="https://img.shields.io/badge/homebrew-tap-FBB040.svg" alt="Homebrew tap"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e.svg" alt="MIT License"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.ko.md">한국어</a> · <a href="README.zh.md">中文</a> · <b>日本語</b>
</p>

<p align="center">
  <b>エージェントに毎回説明していたルールを、プロジェクトに置く。</b>
</p>

<p align="center">
  <b>あなたのエージェントだけでなく、あなたを捕まえる品質ゲート。</b>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/gate-block.gif" alt="regression guard blocking a change that dropped a Done When section, then passing once it is restored" width="820">
</p>
<p align="center">
  <sub>演出ではなく実際の実行です。エージェントがスキル定義ファイル（<code>SKILL.md</code>）を「整理」した際に <b>Done When（完了条件）</b> の節を消しました。ゲートは消えた節を名指しし、それを戻せば残りの整理はそのまま通ります。<br>再生成: <code>brew install vhs &amp;&amp; vhs docs/demo/gate-block.tape</code></sub>
</p>

<p align="center">
  すでに Claude Code へ同じことを繰り返し伝えているはずです — 走らせる検査、守るべきルール、
  変更が満たすべき形。再利用できるようになるのはまさにその部分で、あえて汎用の形のままにしてあるので、
  使ううちにあなたの事例へ合わせて鍛えられます。<br>
  <sub>大きくなるのは試行の回数です: 試行錯誤があなたから離れ、並列で回ります。</sub>
</p>

<p align="center">
  プロジェクト、スキル、ハーネス — 作ること、検証すること、速くすること。ここで頼んでください。<br>
  ただ結果を手渡したりはしません。まず、<i>違うかたちで</i>失敗する検査をいくつも通します。<br>
  <b>そして同じ依頼が繰り返し戻ってきたら、それを代わりにやるハーネスを作って渡します。</b>
</p>

---

## どちらか一つを選んでください。入れ方も、得られるものも違います。

### ① ゲートだけ — Claude Code は不要です

```bash
npx --package @chrono-meta/fh-gate fh-gate          # インストール不要
brew tap chrono-meta/forge-harness && brew install forge-harness   # あるいはこちら
```

**GitHub Actions では** — 同じゲートを1つのステップとして、判定は型のあるまま:

```yaml
- uses: chrono-meta/forge-harness@v3.1.2
  with:
    files: ${{ steps.changed.outputs.files }}
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

[GitHub Actions マーケットプレイス](https://github.com/marketplace/actions/fh-gate-typed-ai-code-review-verdict) に掲載されている。

このステップは `verdict`（PASS · PENDING · BLOCKED · ESCALATE · HARNESS_ERROR · ARG_ERROR ·
DRY_RUN · UNKNOWN）と `reviewed` を出します。**`reviewed: false` は合格ではありません** —
バックエンドが最後まで答えなかった場合、dry run、このラッパーが知らない終了コード、そのすべてが
ここに落ち、既定ではいずれもステップを失敗させます。その既定こそが要点です: 走らなかった検査が
グリーンに読めては絶対にいけません。もっと緩い方針が欲しければ `fail-on:` で変えられますが、
何と引き換えにしているかは分かった上でどうぞ。


**得られるもの**

- 変更がマージされる**前に**判定が出ます。その判定は、この変更が**何を失ったか**を名指しします。
  「なんとなくおかしい」ではありません。上の GIF が、実際の diff に対するその判定です。
- 判定は grep するテキストではなく、**型のある値**です: `PASS · PENDING · BLOCKED · ESCALATE`。
- シェルが動く場所ならどこでも動きます。CI、pre-commit フック、別のコーディングエージェント。
  Claude Code は任意です。
- **エージェントのコードだけでなく、あなたのコードも見ます。** diff を指し示せば、弱いところを
  名指しします — 静かに PASS 側へ劣化していく判定、存在しない参照、漏れた秘密、根拠のない主張 —
  マージの*前に*直して回し直せます。各 FH エンジンがどこに効くのか（ハーネスを作る · スキル/
  エージェントを書く · コードレビュー · 不可逆な面のゲート · 文脈の連続性）、そしてモデルのティアと
  かける手間で何が変わるのか: [`docs/USE_CASES.md`](docs/USE_CASES.md) ·
  [`docs/model_tier_expectations.md`](docs/model_tier_expectations.md)。
  これらのゲートが ISO/IEC の AI テスト規格・AI 品質規格（42119 · 29119-11 · 25059 · 42001）と
  どう対応するかを、証拠へのポインタ付きの自己評価として:
  [`docs/STANDARDS_ALIGNMENT.md`](docs/STANDARDS_ALIGNMENT.md)。

### ② ハーネス全体 — Claude Code の中で

```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness
claude plugin install -s user fh-qp@forge-harness      # 任意: QP (Quality Platform) — セッションの Playwright / computer-use MCP を通して Web・デスクトップアプリを 計画→実行→回帰
git clone https://github.com/chrono-meta/forge-harness.git ~/projects/forge-harness
cd ~/projects/forge-harness && claude        # そのあと挨拶を一言: こんにちは · hi · 안녕 · 你好
```

<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/door2-menu.gif" alt="クローンしたばかりの forge-harness で hi と打つと、FH がチェックアウトを読み、新規ユーザー向けメニューを開き、インストールウィザードが未実行だと知らせる" width="820">
</p>
<p align="center">
  <sub>四行目がすることの全部です。数分前に作ったクローンです — チェックアウトを読み、セッションファイルが無いことを見て、<b>新規ユーザー</b>のメニューを開きます。そしてウィザードがまだ走っていないと伝えます。<br>起動と待ち時間は隠してあります。画面の文字はすべてその実行の出力です。作り直し: <code>vhs docs/demo/door2-menu.tape</code></sub>
</p>

**①に加えて得られるもの**

- どの検査を掛けるかを自分で選ばなくてよくなります。いま何をしようとしているか — 公開、削除、
  履歴の書き換え、PR — を読み取り、その場に合うゲートを名前で挙げます。①が覚えて打つコマンド
  一つなら、②は代わりに覚えておく層です。
- **スキル41種 · エージェント8種**を普通の言葉で呼べます。プロジェクトを診断し、加速し、新しく配線します。
- `tracks/` が各セッションの学びを残すので、**2回目のセッションが1回目の止まった場所から始まります**。
  複利が付くのはここで、初日には判断できないのもここです。
- 同じことを三度頼むと、答えるのをやめます。代わりに、その答えを出すハーネスを作って渡します。

<sub>🟥 <b>②が与え「ない」もの。</b>FH には 4軸の <b>pre-commit</b> フックもありますが、あなたの
リポジトリ用ではありません。ハブのパスとハブのマーカーをコードに埋め込んでいるため、あなたの
プロジェクトに入れると助けになる代わりにコミットを止めます。インストーラ自身もこれを任意項目と
し、「FH 自体を開発するのでなければ飛ばしてください」と書いています。<b>あなたのリポジトリの
ゲートは①です</b> — CI か、自分で用意した pre-commit に掛けてください。</sub>

<sub><b>迷ったら</b>①から。コマンド一つで済み、消すものもありません。②は①を含んでいるので、
①で覚えたことは一つも捨てられません。</sub>

### どちらの扉でも«ない»こと

**後段のレビューを置き換えません。** 問いを前に倒すだけです。人間のレビュアーに届く量が減るので
あって、人間がレビューをやめるのではありません。狙っている詰まりは «作られる速さ» と
«人が確かめられる速さ» の差で、その差を**前側から**縮めます。後ろへ渡るものを減らすやり方で。

**diff で見えないものは、依然として人の仕事です。** 実際に動かして初めて現れるもの —— 本物の画面で、
本物の状態を相手に —— は、これらの道具が届く範囲の外です。その仕事は、上流にゲートがあるからといって
減りません。減るのは待ち行列です。

---

## 本当に何か捕まえるのか?

**他人が書いた実際のコードで** (2026-05-31)。`fh-gate` を OpenCode の AI 生成
`permission/arity.ts` に掛けました — 163行、エージェントが書いたもの、**CI はグリーン**。判定は
**BLOCKED**、CI が見逃した A 級の発見2件（許可リストの短トークンオーバーフロー、arity テーブルから
抜けた executor ツール）に対して。

**モデルを固定したまま、植えた穴で** (2026-07-14)。*既定で PASS へ倒れる*（フェイルオープン）微妙な
穴を8つ、こちらに合わせて調整されないよう*別の*モデル2つに書かせました。モデルは中位ティアの床に
固定したままで、変えたのは**方法**だけです:

| 方法 | 捕まえた数 | 誤検知 |
|---|---|---|
| 素のレビュー | 5/8 — **しかもうち2件は別のバグを指していました**（誤った確信。きれいな見落としより悪い） | — |
| + FH の劣化方向レンズ | 6/8 | 0 |
| + 別のモデルファミリー、同じレンズ | **8/8** | 0 |

🟥 **荷重を担っている行は 8/8 ではありません。** 単一モデルの2レーンは**同じ2つの穴**を落としました —
偽値のエラーセンチネルと、区切り文字の否定の解析です。同じ入力、同じ盲点: *同じ種類*の2人目の
レビュアーを足しても、やはり落としていたはずです。それが脱相関の唯一の論拠であり、残りは算術です。
標本は小さく（単一の抽出）、反復とより難しい穴が明示された次の一歩です。方法:
[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) §Dominance ·
日付入りの実行はさらに: [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md)。

<p align="center">
  <b>品質が梃子であり、速度はその結果です。</b> ·
  <a href="docs/ETHOS.md"><b>原則</b></a> ·
  <a href="docs/WHY.md"><b>存在理由</b></a> ·
  <a href="docs/OUTPUT_EVIDENCE.md"><b>証拠</b></a> ·
  <a href="CHEATSHEET.md"><b>使い方</b></a><br>
  <sub>役に立ったら ⭐ が他の人の発見につながります。</sub>
</p>

| こんな理由で来たなら… | forge-harness が解決します |
|---|---|
| セッションが終わると文脈が消える | 永続 `tracks/` — どこからでも続きを再開 |
| プロジェクトごとに同じ設定を繰り返す | ハブに一度つなげば全プロジェクトで共有 |
| チームの AI ノウハウが人の頭の中にしかない | コードに刻んで全員で共有 |
| 作業が積み上がるほど AI が*より良く*なってほしい | スキルとパターンがセッションを重ねて複利で積み上がる |
| AI が生成したコードにガバナンス層が必要だ | `fh-gate` がどんなコーディングエージェントでも生成後ゲートで包む |

> **この文書は人間のためのものです。** AI 運用ルール → [`CLAUDE.md`](CLAUDE.md) · コマンド
> リファレンス → [`CHEATSHEET.md`](CHEATSHEET.md)。上の二つの扉が決定のすべてで、以下は必要に
> なったときに見る参考資料です。

---

## 始める

**`こんにちは` と入力してください** — `hi`, `안녕`, `你好`, `hola`, `bonjour` でも構いません。
どれでも番号付きのメニューが開きます。入口を選び、いくつか答えれば、インストールウィザードまで
代わりに実行します。**「プロジェクトを接続して」**と言えば、ハブが `../` をスキャンして `.git`
ディレクトリを見つけ、`tracks/{project}/` を作ります。

<sub>🟥 <b>そこは正直に</b>: 言語を合わせるのは散文のルールで、その背後に機械的な床は何もないため、
いつも守られるわけではありません。2026-08-21 に新しいクローンでブラインド計測したところ、メニューは
まるごと翻訳されました。ただしメニューが出るかどうかのほうが揺れていて、ある挨拶のかたちでは
まったく出ませんでした。そう言ってもらえれば切り替えます。ならして隠さず
<code>CLAUDE.md</code> §Voice/Tone に書いてあります。</sub>

**前提条件。** 扉②には Claude Code CLI が必要です（`claude --version`）。扉①には不要で、それが①の
存在理由です。ゲートが1つだけ **Python + PyYAML** を追加で必要とします（YAML を解析し、無ければ
フェイルクローズするので `npm test` 全体が赤くなります）: `python3 -m pip install --user pyyaml`。
なぜフェイルクローズするのか: [`CHEATSHEET.md`](CHEATSHEET.md) §6。

**最初の15分。** セットアップがうまくいったことは、挨拶で 🐿️ のドアメニューが出て、「プロジェクトを
接続して」で `tracks/{your-project}/` ができることで分かります。次に同じセッションのうちに成果を1つ:
**「このプロジェクトを加速して」**（ランク付きで、インストールはゲート付きの計画）または
**「`/context-doctor` を回して」**（トークン浪費のスキャン）。初期セットアップ一式 — フック · ゲート ·
ベースライン、項目ごとに個別承認され、断ればそれが記録されます — が欲しいときは
**`/install-wizard`** と頼んでください。正直な注記が1つ: FH の見返りは**複利**で、効いてくるのは
**セッション2以降**です。初日に手に入るのはメニュー、計画、ゲートなので、初日で判断しないでください。
すでに別の場所にクローン済みですか? そのパスが*あなたの*ハブです。見慣れない言葉は →
[`GLOSSARY.md`](knowledge/shared/GLOSSARY.md)。②をプロジェクト一つだけで試したいなら
[`templates/starter_profile.md`](templates/starter_profile.md) が、コマンド一つと厳選した最初の5つです。

> ⚠️ **プラグインのみは部分シナジーです。** ハブをクローンせずにプラグインだけ入れることもできます
> （`claude plugin install -s user fh-meta@forge-harness` のあと自分のプロジェクトへ `cd`）。スキルと
> エージェントは得られますが、**ハブ側のオーケストレーション**は得られません — `CLAUDE.md` の
> ガバナンスも、それらをセッションをまたいで複利にする `tracks/` の記憶もです。
>
> 🟥 **バージョン番号は2つあり、測っているものが違います。** **パッケージのバージョン**（上部の npm
> バッジ）はあなたが入れるものです。**アイデンティティ成熟度のリリース**（`identity-v1.0.0`、
> Releases ページ）はハーネスがどこまで来たかです — 5つの正体が緑でないうちは緑と言うことを拒むので、
> 設計上 `0.x` です。二つは同じ物差しではなく、パッケージ番号が高いことは成熟ではありません:
> [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md)。
> 🟢 **2026-09-04 — 2つのカウンターが合流します。** `identity-v1.0.0`（正体がすべて 🟢）は
> アイデンティティ系列の**最後**のタグであり、*Latest* バッジを付ける最初のタグです。これ以降、
> リリースは**両方を1つの番号で**表します — 次はアイデンティティ 1.0 を載せるパッケージのメジャー
> です — そしてリリースノートは英語で書き、韓国語の要約を添えます。上の段落は、すべてが緑では
> なかった間になぜ系列を分けていたのかという理由として残します。いまのルールではなく、履歴です。

---

## ツールボックスではなくハーネスである理由

ハーネスはあなたの**意図**を読み取り、**機械化された形**へと鍛え上げます — AI が確実に従うルール、
あるいはモデルを一切必要としない決定的なコードへ。見返りは**人間側の試行錯誤が減ること**です:
リクエスト → フィードバック → 再生成のループがハーネスの内部へ*場所を移し*、並列で回るので、あなたの
注意は変更が不可逆な地点にだけ向かいます。**スキル · エージェント · プラグイン**は1つの道具です。
**ハーネス**は一段上 — 1つの*星 (star)*: あるプロジェクトの道具 · ルール · ゲート · 記憶が、1つの
働く体へと束ねられたもの。**forge-harness はその星たちが暮らす銀河です** — 複数を共通の床の上に束ね、
散り散りになる代わりに共に進化させます。FH はフィールドハーネスを**自らのサンドボックス内で
シミュレーションとして走らせ**、そのあと独立したハーネスとして**送り出す (EMIT)** こともできます —
🟥 この一歩は出荷済みの機能ではなく*進む方向*として読んでください: チャンバーが送り出したのは1回きりで、
そのランは完全なフローを通っていません。

```
forge-harness/   ← ハブ (永続する脳)              Project A ──→ CLAUDE.md でハブを接続
├── knowledge/   → 全プロジェクトで共有            Project B ──→ CLAUDE.md でハブを接続
└── tracks/      → プロジェクト別の作業記録
```

構造としては**2つの層**です — モデル非依存の**方法論層**（`tracks/`, `knowledge/`, `SKILL.md` 文書）と、
Claude Code ネイティブの**自動化層**（エージェント、フック、スラッシュコマンド、`CLAUDE.md` ルール）。
この境界は埋めるべきギャップではなく意図されたものです:
[`docs/codex-compat.md`](docs/codex-compat.md)。**これが立つ位置 (2026):** 基本的なエージェント
オーケストレーションは標準インフラへと商品化されつつあり、FH はその配管に何も賭けていません — 永続層は
*商品化されないもの*です: ガバナンスゲート、ドリフト制御、プロジェクト間の複利ループ。ルーティングと
ディスパッチは手段であり、**ゲートとループが資産です。**

### 5つの正体 — FH は何のためにあるのか

5つのモジュールでも5つの出荷済み機能でもありません。スキルが**固まっていく形**に、後から名前を
付けたものです。

| | 正体 | 人が手にするもの |
|---|---|---|
| **①** | **ハーネスクラスター** | 1つの作業が複数のハーネスに乗り、ガバナンスはその*あいだ*で計算されます — 持っていない能力は作らずに**呼び**、作るべきだったものは**取り込む** |
| **②** | **プロジェクトインキュベーター** | 新しいハーネスが空のスキャフォールドではなく、**生まれた場所で既に歩ける状態**で出てきます |
| **③** | **ガバナンスゲート** | 出してはいけないものが、覚えて確認する代わりに**機械的に**止まります |
| **④** | **フロンティア吸収** | 確信が持てないとき、*手持ちのもの* → *世の中にあるもの* の順に先に探すので、作り直しが起きません |
| **⑤** | **増幅器 (Amplifier)** | 短い意図が、完成した成果物まで鍛え上げられます |

6つ目の行は意図的にありません: `Ⓑ` **プロジェクトブースター** — FH の機構が*相手のハーネス自身の
開発*を加速すること — は実在し等級も付いていますが、別の層に座るので番号ではなく文字です。
**そしてこの表は「5つの動く機能」ではありません**: 成熟度は正体ごとに
（`aspirational → partial → RC → REALIZED`）日付入りの証拠とともに採点され、ここには**あえて写しません**
— 2つのファイルに置かれた等級は片方が必ず腐りますし、このページは4言語で存在します。どの行かに頼る前に
等級を読んでください: [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md)。 そして**それぞれをどう使うか** — どのコマンド・どの扉がどのアイデンティティを点けるか — は [`docs/IDENTITIES.md`](docs/IDENTITIES.md) です。等級は*どこまで出来ているか*を、そのページは*どう呼ぶか*を述べます。

5つすべてを横断する性質が2つあります。**フロンティアに継ぎを当てるのではなく、フロンティアに乗ります**
— ファミリーをまたいでディスパッチするのは（Claude, Codex, Gemini, ローカル）弱点を埋めるためではなく、
共進化するためです。**脱相関 (decorrelation)** が今日の信頼の梃子であり、このページで最も荷重を担う
言葉です: 2つの検査が*違うかたちで*失敗するように意図的に仕組むこと — 別のモデルファミリー、実際の
対象に対する1回の実行、自分の記録に対する外部からの監査 — そうすれば一方に見えないものを、もう一方が
見ています。そして**2つの方向へ進化します**: *外へ*、各セッションの教訓がハブに複利で積み上がり、
*内へ*、同じゲートがハーネス自身に向きます。

---

## どう作られているか — 3段 · 4大 · 5つ · 6軸

**3段工程 · 4大エンジン · 5つの正体 · 6軸検証。** 上の正体は、工程とエンジンが噛み合うところに
現れてくるものです — この5つは鍛えられ、等級が付き、安定したもので、それ以外の正体はどちらへ舵を
切りどこまで押し込むかによって現れては引いていきます（運用者の定式化、2026-09-05）。**4大エンジン**
（`judgment-circuit` · `ship-gate` · `context-continuity` · `external-grounding`）は FH らしい成果が
すべてそこから出てくる中核であり、**3段工程** — ① 設計の*前に*判断回路を植える → ② 中間で並列脱相関
→ ③ 6つの軸で焼き切る — は、エンジンを鍛えるときも含めて FH のあらゆる仕事が踏む順序です。速度は
最後の矢印であって、4つめの箱ではありません。**全体地図** — FH とは何か、どう実装されているか
（どのノードも実在するパス）、なぜ信頼できるのか（ゲート · レーン · 等級をファイルパス付きで）、
何が運用者ローカルで何が汎用か — は1ページにまとまっています:
[`docs/map/FH_MAP.md`](docs/map/FH_MAP.md)。その隣にインタラクティブな図が3枚あり、
**[chrono-meta.github.io/forge-harness](https://chrono-meta.github.io/forge-harness/)** で公開されています。

[![FH 全体地図 — 扉 → 3段工程 → 4大エンジン → 正体へと続く流れ（クリックでインタラクティブ版）](docs/map/fh_process.workflow.png)](https://chrono-meta.github.io/forge-harness/map/fh_process.workflow.html)
⚠️ **6軸は4つめの層ではありません** —
③段階が*何でできているか*です。完全な正典と、なぜこれがきれいな積み木では*ない*のか:
[`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md) — 同じ三つを鍛冶屋の
言葉（鍛え · 焼き入れ · 焼き戻し）で言い直したものは [`ETHOS.md`](docs/ETHOS.md#the-forge) にあります。

🟥 **軸は「どれだけ敵対的か」ではなく「何を受け取ったか」で分かれます。** 同じ入力を2人に渡せば、
何人足しても同じ盲点が残ります:

| 軸 | **受け取るもの** | 何を捕まえるか | 典型的な計器 |
|---|---|---|---|
| **ⓐ 別ファミリー** | 変更分 + 著者のフレーミング | **実装**が間違っている | 別のモデルファミリーからのレビュアー (`auto-decorrelation`) |
| **ⓑ 立ち位置 (standpoint)** | 変更分 + **対象ハーネス自身の正典** | **引用した規約が本当にそう言っているか** | そのハーネス自身のレポとルールの側で変更分を走らせる ([`§7`](knowledge/shared/harness-core/field_verdict_crossfamily_gate.md)) |
| **ⓒ 隔離されたグラウンディング** | 著者が書いた文 — その主張、*そして* **始める前に宣言しておいたもの** — + いまのツリー | **主張**が間違っている · デルタが宣言と食い違う | 書いていない誰かが、書かれている内容を測り直す |
| **ⓓ 第三者との対面** | 問題 + **他人のコードベース** | **これはもう解かれているのでは** · 自分の変更が他人のレポのどこに触るか | 無関係な第三のレポで同じ問題を見る |
| **ⓔ 初の実使用** | 実物の対象1件 | **測り方**が間違っている — 計器の計器 | 実際の対象1件に対して一度走らせ、手で確かめる |
| **ⓕ 戻して観察する** | 配線を消したツリー | **アンカー**が間違っている — その検査は装飾だ | 守っている対象を消し、*その特定の*検査が赤くなることを確かめる |

**6つを毎回すべて回すわけではなく、それが設計です** — 掛け算せずに、**選んでください**:

```
1行の修正（typo · gitignore）      何も焼きません。答えが1つなら、回路を植えること自体が
                                   オーバーヘッドです
通常のコード変更（可逆）            ⓔ 初の実使用 + ⓕ 戻し
verdict · ゲートのコード           + ⓐ 別ファミリー — verdict のロジックは、著者と同じ楽観を
                                   共有するレビュアーが構造的に見落とします
他人のハーネスに触れる変更          + ⓑ 立ち位置 — ファミリーを3つ足しても、全員が自分の
                                   フレーミングを飲んでしまえば「その正典が本当にそう言って
                                   いるか」は誰も見ません
超大型 · 不可逆                    + ⓒ 隔離 + ⓓ 第三者との対面。全部焼きます
```

軸は*レビュアーの能力*ではなく**入力**で定義されるので、基盤モデルの進化がこれを置き換えることは
ありません: モデルが強くなっても、受け取っていない情報は見えないままです。🟥 **引用する前に限界を** —
この表は **n=1**（1つの成果物 · 1セッション · 1人の著者）であり、発見16件を出典を消したまま別ファミリー
2つに判定させたところ、著者が ⓓ に帰属させた**5件のうち3件**が別の軸と判定されました。これらのゲートの
内側で過ごした1日を、見落としも名指しして記録したもの: [`docs/GATE_DAY.md`](docs/GATE_DAY.md)。

---

## ルールはどこに座るか — 3つの席

ハーネスはルールを書き留めることで学び、常時読み込まれるファイルは長くなる一方です — だから推論は
袋小路に入ります: *学び続けるハーネスは、起動が高くつき続ける。* そうはなりません。ルールには
**3つの席**があり、*そのルールがいつ発火しなければならないか*で選ばれるからです: **常時読み込み**
（トリガーが*意図*であるもの — フックを掛けられないので、顕在性だけが層です）· **ゲート自身の
エラーメッセージ**（トリガーが*行為*であるもの。あなたを止めるメッセージが同時に形を教え、この席は
無料です）· **フック**（記録の性質 — 存在する、型がある、帰属できる、空でない）。たいてい使われずに
残っているのは真ん中の席です。完全な表と、「失敗したときにしか発火しない」という正直な限界:
[gate-locality](knowledge/shared/harness-core/gate_locality_principle.md) §Where a rule lives。

---

## Claude Code の外で動かす — `fh-gate` CLI

FH はどんなコーディングエージェント（OpenCode, Codex など）でも**生成後ガバナンスゲート**で包みます。

```bash
npx --package @chrono-meta/fh-gate fh-gate                    # 既定: Claude バックエンド
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate   # Codex バックエンド
FH_BACKEND=cross npx --package @chrono-meta/fh-gate fh-gate   # 両ファミリー、findings を union
# → FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE
```

どのランタイムにも同じガバナンスプロンプトを使います。`auto` はフォールバック*選択*で、レグは1つだけ
走ります。`cross` は両ファミリーを走らせて findings を union し（一方だけが見つけた指摘も指摘です）、
コストは約2倍なので、判定 · ゲート · 不可逆な面に関わる変更のためのもので、既定値ではありません。出力は
実際に走ったレグを常に明示するので、単一ファミリーの結果がクロスチェック済みに見えることはありません。
`fh-run`（スキルやエージェントを直接1つ）· `fh-goal` · `fh-codex-doctor`（アダプターのドリフト検知）が
同梱されています — フラグと環境変数の一覧は [`CHEATSHEET.md`](CHEATSHEET.md)、仕様は
[`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md)。
**推奨スタンス — Claude Code をオーケストレーターに、他をサイドカーに**: 非 CC ランタイムをメイン
エージェントにしても `fh-gate`/`fh-run` を通じて方法論層は維持されますが、オートパイロットは得られません
（フックが自動発火せず、ディスパッチにはアダプターが要ります）— ティア別の詳細は
[`docs/codex-compat.md`](docs/codex-compat.md)。

---

## モデル設定

Claude Code は作業の複雑さでモデルを自動選択しません — これは一度だけ設定します。

| コマンド | 誰が何を実行 | 最適な用途 |
|---|---|---|
| `/model sonnet` | Sonnet セッション; FH が宣言された床でより上位のサブエージェントをディスパッチ | **FH 既定値** — 運用 + 日常開発 |
| `/model opus` | Opus がすべてを処理 | ハーネス編集セッション · 毎ターン最大の深さ |
| `/model opusplan` | Opus が*計画* · Sonnet が実行 *(Opus が関与するとき)* | コスト意識の日常コーディング — 注意点を参照 |

測定によれば、FH の*運用*はほぼモデルフラットです — 文脈に入ったルールが仕事をします。だから FH は
深さに敏感な少数のターンだけを宣言された床で自らディスパッチし、**あなたのセッションモデルには決して
触れません**。床より低い環境では静かに劣化させず、明示的な `below-floor` フラグを付けます。⚠️
`opusplan` の Opus 関与は**保証されません**（測定したある実行では10ターン中0）。その背後にある2つの
構造法則、任意のローカルサイドカー向けのハードウェアティア、マルチモデルサイドカーの姿勢:
[`docs/MODEL_SETUP.md`](docs/MODEL_SETUP.md)。

---

## 41 skills · 8 agents

カウント = 非 deprecated のスキル。検証 · オーケストレーション · 診断 · 収穫 · ゲート · 発見 ·
シミュレーション · 設定 にクラスタリングされ、加えて8つのエージェント（`challenger` ·
`quench-challenger` · `beginner` · `main-player` · `expert` · `fact-checker` · `hub-persona-auditor` ·
`persona-innovator`）が、それらのスキルから、または名指しでディスパッチされます。**完全フレーズ集** —
すべてのスキルとエージェントの一行定義、そしてそれを発火させる表現:
[`CHEATSHEET.md` §12](CHEATSHEET.md#12-skills--agents--what-each-does-and-what-to-say)。

---

## もっと知る

| リソース | 目的 |
|---|---|
| [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) | 実際の使い方、最初から最後まで |
| [`CHEATSHEET.md`](CHEATSHEET.md) | 全コマンドリファレンス |
| [`docs/ETHOS.md`](docs/ETHOS.md) | FH が信じていること — 鍛冶場、冷静なレビュアー、言葉に見合う主張 |
| [`docs/WHY.md`](docs/WHY.md) | 存在理由 |
| [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md) | 証拠 — 論文、日付入りの実行、外部の収束 |
| [`docs/GATE_DAY.md`](docs/GATE_DAY.md) | ゲートの内側で過ごした1日、測定つき、見落としも名指しで |
| [`docs/MODEL_SETUP.md`](docs/MODEL_SETUP.md) | どのモデルで FH を回すか、ハードウェアティア、サイドカー |
| [`docs/codex-compat.md`](docs/codex-compat.md) | 非 Claude Code ランタイムで FH を回す |
| [`knowledge/shared/GLOSSARY.md`](knowledge/shared/GLOSSARY.md) | 見慣れない言葉 |
| [`CLAUDE.md`](CLAUDE.md) | AI 運用ルール + 同期/プッシュプロトコル |
| [`AGENTS.md`](AGENTS.md) | ランタイムエージェント仕様 |
| [`CATALOG.md`](CATALOG.md) | 過去作業の検索インデックス |
| [`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md) | 3層の正典 — 工程、エンジン、正体 |
| [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) | 正体ごとの等級、2つのバージョン系列、優位性の結果 |
| [`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md) | ガバナンスゲート仕様 |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | スキルとパターンの貢献方法 |
| [`tracks/_contrib/`](tracks/_contrib/README.md) | **同意レーン** — 非識別化した作業セッションを共有; レポが運用者たちにまたがって複利で積み上がる |

> **FH 論文**: v1.0.1 方法論 · [Zenodo](https://zenodo.org/records/22542168) (DOI
> 10.5281/zenodo.22542168) · cs.SE companion v1.2.2、プレプリント公開 ·
> [Zenodo](https://zenodo.org/records/22674575) (DOI 10.5281/zenodo.22674575) ·
> [arXiv:2609.04218](https://arxiv.org/abs/2609.04218) (v2 は 2026-09-09 公開 — §6.7 を追加し、タイトルの主張を格下げ。Zenodo v1.2.2 も同日に同一内容で公開され、両者は一致する) · cs.AI companion は
> 準備中。これら、独立した収束的研究、そしてそれぞれの但し書き:
> [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md)。
