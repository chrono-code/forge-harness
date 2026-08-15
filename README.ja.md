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

```bash
# 1. プラグインをインストール
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness

# 2. ハブをクローン
git clone https://github.com/chrono-meta/forge-harness.git ~/forge-harness
cd ~/forge-harness

# 3. セッションを開始
claude
```

> ✅ Claude が `CLAUDE.md` を読み、どのプロジェクトを接続するか、あるいはどの作業を始めるかを尋ねます。
> **「プロジェクトを接続して」** と言えば → ハブが `../` をスキャンして `.git` ディレクトリを見つけ、`tracks/{project}/` を作成します。

**プラグインのみ（クローンなし）:**
```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git  # 初回1回
claude plugin install -s user fh-meta@forge-harness
cd ~/projects/{your-project} && claude
```

> ⚠️ **プラグインのみは部分シナジーです。** スキルとエージェントは得られますが **Layer 1** は得られません —
> `CLAUDE.md` ガバナンス（能動オンボーディング、4軸ゲート、モード分岐）と複利文脈（`tracks/` メモリ蓄積、
> `harvest-loop` 学習）が抜けます。各スキルは孤立していても同じように動きますが、抜けるのはそれらを
> セッションをまたいで複利にするオーケストレーションです。道具だけでなく全体セットが欲しいなら、ハブを
> クローンしてください（上記参照）。

> 🚪 **初めてですか / スキルだけ欲しいですか?** 意見のこもった正面玄関から始めてください —
> [`templates/starter_profile.md`](templates/starter_profile.md): インストールコマンド1つ、厳選された
> 最初の5つのスキル、そしてインストール不要のガバナンスゲート（`npx … fh-gate`）。残りのスキルは必要になるまで待ちます。

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
プロジェクトを独立した特化ハーネスとして**送り出します (EMIT)**。これが目指す目標です。実際には、
4つの方法で働きます:

**① 組み立て (Assemble)** — FH はハーネスの*クラスター*を最適なトークンコストで運用し、プロジェクトに合う
ハーネスを手に握らせます。スキルを1つずつ配線するのではなく、**ハーネス**を — そのプラグイン · スキル ·
エージェントまで含めて — 合わせて組み立てた状態で受け取ります。

**② 鍛え (Forge)** *(品質ゲート)* — あらゆる変更は敵対的 · ファントム · 回帰ゲートを通って自らの値打ちを
証明します。これは「もっと検査する」ではありません。**責任ルーター (responsibility router)** です: 自動化が
増えるほど人間の承認は減り1件あたりの重みは増すので、ゲートはあなたの注意を*取り返しのつかない*地点にだけ
使います。品質が梃子であり、速度はその結果です。

**③ サイドカー (Sidecar)** — 能力そのものはフロンティアに置きます。FH は複数の LLM（Claude, Codex, Gemini,
ローカル）へディスパッチし、raw な力が1つのモデルや1つの世代に縛られないようにします。要点は各モデルの
弱点を*機械的に埋めることではありません* — そうしたスキャフォールディングはモデルが強くなれば死んだコードに
なります。要点は**フロンティアの進化に共に乗ること**です: substrate がいまやネイティブでやってくれるものは
脱ぎ捨て、新しく出してくるものは吸収します。脱相関 (decorrelation) は*いまの*信頼の梃子であり（クロス
ファミリーのパネルが単一モデルの天井を超えます）、共進化 (co-evolution) が構造です。

**④ 自己進化ループ (Self-evolving loop)** — ハーネスは再構築なしにより良くなります、2つの方向へ:
**外へ**、各セッションの教訓がハブに複利で積み上がって次のプロジェクトがより速く始まり、**内へ**、
*自分自身の*欠陥を捕まえて直します（4軸ゲート、双方向検証、ユーザー別適応）。

全体は1つの分業です: **raw な能力はモデルのもの、組み立て · 信頼 · 進化はハーネスのもの。**

> **ここでのセルフヒーリングは主張ではなく — コミットログにあります。** まさにこの README の声のルールが
> セッションの途中で、FH が自らのドリフトを捕まえて直されました: トーンのミス → 診断 → 自らの最初の修正案まで
> 攻撃したクロスファミリー challenger → 再修正 → 床ティアでの再検証 → メモリ反映。ハーネスが自らの欠陥を
> 自分で直した実例 — スローガンではなく記録です。

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

## 37 skills · 8 agents

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
| `quench-challenger` *(fh-commons)* | 敵対的プレッシャーテストエージェント | "Challenge this with a devil" |
| *(+ 追加資産)* | marketplace-gate · contention-layer · edit-manifest · fact-checker · goal-quench · hub-persona-auditor · install-doctor · memory-hygiene · persona-innovator · prompt-regression · public-surface-audit · salience-splitter | |

| アクティブ数 | 診断 |
|:---:|---|
| **28+** | 上級 — agent-composer + sim-conductor + steel-quench + pipeline-conductor を連鎖 |
| **10–27** | アクティベーション段階 — 未チェックの資産を段階的にオンにする |
| **0–9** | 初期段階 — `install-wizard` から始める |

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

**なぜいま Sonnet 既定値で通用するのか**: 測定結果（下記 §Model setup evidence note 参照）、FH *運用*はほぼ
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
**測定したすべての Claude ティアが 94–100%**（Fable, Opus 4.8, Sonnet 4.6 と 5, Haiku 4.5）; 失った少数の点数は
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
> - **cs.SE companion — ガバナンスゲート方法論** · **掲載済み** [Zenodo](https://zenodo.org/records/20680081) (DOI 10.5281/zenodo.20680081 · 最新 v1.1 10.5281/zenodo.20740038 · CC-BY-4.0) · arXiv 提出済み (cs.SE, モデレーション中)。
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
