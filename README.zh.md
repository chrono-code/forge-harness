<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/banner.png" alt="forge-harness — 锻造你的项目，让它通过，然后更快出炉。品质是杠杆，速度是结果。" width="680">
</p>

<p align="center">
  <a href="https://github.com/walkinglabs/awesome-harness-engineering#coding-agent-harnesses"><img src="https://awesome.re/mentioned-badge.svg" alt="Mentioned in Awesome Harness Engineering"></a>
  <a href="https://github.com/VoltAgent/awesome-agent-skills#community-skills"><img src="https://img.shields.io/badge/listed_in-awesome--agent--skills-0ea5e9.svg" alt="Listed in awesome-agent-skills"></a>
  <a href="https://github.com/anthropics/claude-code"><img src="https://img.shields.io/badge/Claude_Code-compatible-a855f7.svg" alt="Claude Code compatible — official Claude Code repository"></a>
  <a href="https://chrono-meta.github.io/forge-harness/"><img src="https://img.shields.io/badge/whole_map-interactive-6366f1.svg" alt="FH whole map — interactive diagrams on GitHub Pages"></a>
  <a href="https://www.npmjs.com/package/@chrono-meta/fh-gate"><img src="https://img.shields.io/npm/v/@chrono-meta/fh-gate.svg?color=cb3837" alt="npm"></a>
  <a href="https://github.com/chrono-meta/homebrew-forge-harness"><img src="https://img.shields.io/badge/homebrew-tap-FBB040.svg" alt="Homebrew tap"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e.svg" alt="MIT License"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.ko.md">한국어</a> · <b>中文</b> · <a href="README.ja.md">日本語</a>
</p>

<p align="center">
  <b>别再一遍遍向 agent 解释规则 — 把它们放进项目里。</b>
</p>

<p align="center">
  <b>抓住的不只是你的 agent，还有你——的质量门禁。</b>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/gate-block.gif" alt="regression guard blocking a change that dropped a Done When section, then passing once it is restored" width="820">
</p>
<p align="center">
  <sub>这是真实运行，不是演示。一个 agent“整理”技能定义文件（<code>SKILL.md</code>）时删掉了 <b>Done When（完成条件）</b>小节。门禁会点名指出被删的小节；把它放回去，其余整理照常通过。<br>重新生成：<code>brew install vhs &amp;&amp; vhs docs/demo/gate-block.tape</code></sub>
</p>

<p align="center">
  你大概已经在对 Claude Code 反复说同样的话：要跑的检查、要守的规则、一次变更该有的样子。
  变得可复用的正是这一部分，而它刻意保持通用的形态，好在使用过程中按你的场景当场锻造。<br>
  <sub>长起来的是尝试的次数：试错从你身上剥离，并行地跑。</sub>
</p>

<p align="center">
  项目、技能、框架 —— 造出来、验过、再加速：这些都在这里交代。<br>
  它不会就这么把结果递还给你，而是先让这份工作穿过好几道会以 <i>不同方式</i> 失败的检查。<br>
  <b>而当同一个请求反复回来，它就替你造出那个专门干这件事的框架。</b>
</p>

---

## 二选一。装法不同，拿到的东西也不同。

### ① 只要门禁 —— 不需要 Claude Code

```bash
npx --package @chrono-meta/fh-gate fh-gate          # 无需安装
brew tap chrono-meta/forge-harness && brew install forge-harness   # 或者用这个
```

**在 GitHub Actions 里** —— 同一道门禁作为一个 step，判定依然是带类型的：

```yaml
- uses: chrono-meta/forge-harness@v3.1.1
  with:
    files: ${{ steps.changed.outputs.files }}
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

这个 step 会输出 `verdict`（PASS · PENDING · BLOCKED · ESCALATE · HARNESS_ERROR · ARG_ERROR ·
DRY_RUN · UNKNOWN）和 `reviewed`。**`reviewed: false` 不是通过** —— 后端始终没有回答、一次 dry
run、这层封装不认识的退出码，全都落在这里，而且默认全部让这个 step 失败。这个默认值正是重点：
一道根本没跑过的检查，绝不能读起来是绿的。想要更宽松的策略就用 `fail-on:` 改，但要清楚你换掉的
是什么。


**你会拿到**

- 变更在合并**之前**就有判定，而且这个判定会指名这次变更**丢了什么**，不是"好像哪里不对"。
  上面那个 GIF 就是对一个真实 diff 的这种判定。
- 判定是**带类型的值**，不是需要你 grep 的文本：`PASS · PENDING · BLOCKED · ESCALATE`。
- 只要有 shell 就能跑 —— CI、pre-commit 钩子、别的编码 agent。Claude Code 是可选的。
- **它审的不只是 agent 的代码，也包括你自己的。** 把一份 diff 指给它，它会点名那处薄弱 —— 悄悄
  往 PASS 方向降级的判定、根本不存在的引用、泄漏的密钥、没有依据的主张 —— 好让你在合并*之前*改掉
  再跑一遍。每个 FH 引擎各自落在哪里（造框架 · 写技能/agent · 代码评审 · 不可逆面的门禁 ·
  上下文延续），以及模型层级与投入程度会改变什么：[`docs/USE_CASES.md`](docs/USE_CASES.md) ·
  [`docs/model_tier_expectations.md`](docs/model_tier_expectations.md)。
  这些门禁与 ISO/IEC 的 AI 测试及 AI 质量标准（42119 · 29119-11 · 25059 · 42001）如何对齐 ——
  以带证据指针的自评形式：[`docs/STANDARDS_ALIGNMENT.md`](docs/STANDARDS_ALIGNMENT.md)。

### ② 整套框架 —— 在 Claude Code 里

```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness
claude plugin install -s user fh-qp@forge-harness      # 可选：QP（Quality Platform）—— 通过本会话的 Playwright / computer-use MCP，对 Web/桌面应用做 计划→执行→回归
git clone https://github.com/chrono-meta/forge-harness.git ~/projects/forge-harness
cd ~/projects/forge-harness && claude        # 然后打个招呼：你好 · hi · 안녕 · こんにちは
```

<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/door2-menu.gif" alt="在刚克隆的 forge-harness 里输入 hi：FH 读出这个检出，打开新用户菜单，并提示安装向导还没跑过" width="820">
</p>
<p align="center">
  <sub>第四行做的全部事情。这是几分钟前才建的克隆 —— 它读出检出，看到没有会话文件，打开<b>新用户</b>菜单，并告诉你向导还没跑。<br>启动与等待时间已隐藏；屏幕上每一个字都是那次真实运行的输出。重新生成：<code>vhs docs/demo/door2-menu.tape</code></sub>
</p>

**在①之上你还会拿到**

- 你不必再自己挑该跑哪一道检查。它读出你正要做什么 —— 公开、删除、改写历史、开 PR ——
  然后叫出那一刻该用的门禁。①是一条你要记住的命令，②是替你记住的那一层。
- **41 种技能 · 8 个 agent**，用平常话就能叫：诊断一个项目、加速一个项目、给新项目接线。
- `tracks/` 留住每次会话学到的东西，于是**第二次会话从第一次停下的地方开始**。
  复利长在这里，第一天也判断不了的同样在这里。
- 同一件事请求三次，它就不再回答了，而是给你造一个专门回答它的框架。

<sub>🟥 <b>②不会给你的一样东西。</b>FH 里还有一个 4 轴 <b>pre-commit</b> 钩子，但它不是给你的仓库用的：
它把中枢路径和中枢标记写死在代码里，装进你的项目只会挡住你的提交，而不是帮你。安装向导也把它列为
可选项，并写着「如果你不是在开发 FH 本身，就跳过」。<b>你自己仓库的门禁是①</b> —— 接到 CI
或你自己的 pre-commit 上。</sub>

<sub><b>拿不准？</b>先从①开始。一条命令，也没有什么要卸载的；②是①的超集，
①里学到的东西一样都不会浪费。</sub>

### 两扇门都«不是»什么

**它不替代事后的评审。** 它只是把问题提前，让抵达人类评审者的量变小 —— 不是让人不再评审。
它针对的瓶颈，是"生成的速度"和"人能核对的速度"之间的差距；它从**前面**收窄这个差距，
办法是减少需要往后传的东西。

**diff 看不见的，依然是人的活。** 只有真跑起来才会显形的东西 —— 在真实的屏幕上、对着真实的状态 ——
不在这些工具能触及的范围内。那部分工作不会因为上游有一道门禁就变少，变短的是队列。

---

## 它真的抓到过什么吗？

**在别人写的真实代码上**（2026-05-31）。`fh-gate` 跑在 OpenCode 的 AI 生成文件
`permission/arity.ts` 上 —— 163 行，agent 写的，**CI 是绿的**。判定：**BLOCKED**，两项 CI 没抓到
的 A 级发现（允许列表中的短 token 溢出；arity 表中缺失的 executor 工具）。

**在植入的洞上，模型固定不动**（2026-07-14）。八个隐晦的 *默认偏向 PASS*（fail-open）的洞，由另外
两个模型撰写，所以这套测试集并没有对着我们调过。模型固定在一个中等层级的下限上，只有 **方法** 在变：

| 方法 | 抓到 | 误报 |
|---|---|---|
| 普通审阅 | 5/8 —— **而且其中 2 次抓错了 bug**（假信心，比干脆漏掉更糟） | — |
| + FH 的降级方向 (degrade-direction) 透镜 | 6/8 | 0 |
| + 换一个模型家族，同一套透镜 | **8/8** | 0 |

🟥 **吃重的那一行不是 8/8。** 两条单模型的路线漏掉的是 **同样那两个洞** —— 一个假值的 error
sentinel，以及一处分隔符取反的解析。同样的输入，同样的盲点：再来一位 *同一种类* 的审阅者也一样
会漏掉。这就是去相关 (decorrelation) 的全部理由，其余都是算术。样本很小（单次抽样）；增加重复
次数和更难的洞是已经写明的下一步。方法：
[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) §Dominance ·
更多带日期的运行：[`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md)。

<p align="center">
  <b>质量是杠杆，速度是结果。</b> ·
  <a href="docs/ETHOS.md"><b>原则</b></a> ·
  <a href="docs/WHY.md"><b>存在的理由</b></a> ·
  <a href="docs/OUTPUT_EVIDENCE.md"><b>证据</b></a> ·
  <a href="CHEATSHEET.md"><b>如何使用</b></a><br>
  <sub>如果这对你有用，⭐ 一下能帮助更多人发现它。</sub>
</p>

| 如果你为此而来…… | forge-harness 这样解决 |
|---|---|
| 会话结束后上下文就消失了 | 持久化的 `tracks/` —— 随处可续、可恢复 |
| 你在每个项目里重复相同的设置 | 一次连接到中枢，跨所有项目共享 |
| 团队的 AI 经验只留在个人脑子里 | 把它编码固化，让所有人共享 |
| 你希望工作越积累，AI 越 *变好* | 技能与模式随会话逐次复利累积 |
| 你需要给 AI 生成的代码一层治理 | `fh-gate` 把任何编码 agent 包裹为一道生成后门禁 |

> **本文档面向人类。** AI 运行规则 → [`CLAUDE.md`](CLAUDE.md) · 命令参考 →
> [`CHEATSHEET.md`](CHEATSHEET.md)。上面那两扇门就是全部的决定；以下都是需要时再查的资料。

---

## 上手

**打一句 `你好`** —— 或者 `hi`、`안녕`、`こんにちは`、`hola`、`bonjour`。任何一句都会打开一个带
编号的菜单：选一个入口，回答几个问题，它就替你运行安装向导。说 **"连接一个项目"**，中枢会扫描
`../`，找到 `.git` 目录，并创建 `tracks/{project}/`。

<sub>🟥 <b>关于这一点，说实话</b>：语言对齐是一条背后没有任何机械兜底的散文规则，所以它并不总是
成立 —— 2026-08-21 在一个干净克隆上做的盲测里，它把整个菜单都翻了过来，但 <b>菜单会不会弹出来</b>
更不稳：有一种问候写法就没能唤出菜单。直接说一声，它就会切过来。这条残留被如实写在
<code>CLAUDE.md</code> §Voice/Tone 里，而不是被抹平。</sub>

**前置条件。** 门②需要 Claude Code CLI（`claude --version`）；门①不需要 —— 这正是它存在的理由。
另有一道门禁需要 **Python + PyYAML**（它要解析 YAML，缺了就 fail closed，会让整个 `npm test` 变红）：
`python3 -m pip install --user pyyaml`。为什么它 fail closed：[`CHEATSHEET.md`](CHEATSHEET.md) §6。

**你的头 15 分钟。** 当一句招呼能让 🐿️ 门菜单出现、而"连接一个项目"能建出
`tracks/{your-project}/` 时，设置就成功了。然后在同一个会话里拿下一个收益：说 **"加速这个项目"**
（一份排过序、安装要过门禁的方案），或者 **"跑一下 /context-doctor"**（token 浪费扫描）；想做完整
的初始设置 —— hooks、门禁、基线，每一项单独批准，拒绝会被记录 —— 请要 **`/install-wizard`**。
一条诚实说明：FH 的回报是 **复利累积**，它从 **第 2 个会话起** 才显形；第一天给你的是菜单、方案和
门禁，别在第一天就去评判它。已经克隆到别的地方了？那个路径 *就是* 你的中枢。碰到不认识的词 →
[`GLOSSARY.md`](knowledge/shared/GLOSSARY.md)；只想在一个项目上试试②？
[`templates/starter_profile.md`](templates/starter_profile.md) 是一条命令加一份精选的头五个技能。

> ⚠️ **仅插件是部分协同。** 你可以只装插件而不克隆中枢
> （`claude plugin install -s user fh-meta@forge-harness`，然后 `cd` 进你的项目）。你会拿到技能和
> agent，但 **拿不到** 中枢那一侧的编排 —— 即 `CLAUDE.md` 治理，以及让它们跨会话复利累积的
> `tracks/` 记忆。
>
> 🟥 **有两个版本号，它们量的不是同一件事。** **包版本**（页首的 npm 徽章）是你装到的东西；
> **身份成熟度发布**（`identity-v1.0.0`，在 Releases 页上）是这个框架走到了哪一步 —— 刻意停在
> `0.x`，因为它拒绝在五重身份还没全绿时就声称全绿。两者不在同一把尺子上，一个高的包版本号并不
> 等于成熟：[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md)。
> 🟢 **2026-09-04 —— 两个计数器合并了。** `identity-v1.0.0`（每一重身份都 🟢）是身份轨道上的
> **最后**一个标签，也是第一个带 *Latest* 徽章的标签。从此以后，一次发布就是**两者共用的一个
> 号码** —— 下一个是承载身份 1.0 的那个包主版本 —— 发布说明用英文写，并附一份韩文摘要。上面那段
> 保留下来，是作为"当年还没全绿时为何要把两条轨道分开"的理由；它是历史，不是当下的规则。

---

## 为什么它是框架，而不是工具箱

框架读取你的**意图**，并把它锻造成**机械化的形态** —— AI 能可靠遵循的规则，或者根本不需要模型的
确定性代码。回报是**人这一侧的试错大幅减少**：请求 → 反馈 → 重新生成的循环 *换了位置* —— 挪进
框架内部并行运转 —— 于是你的注意力只花在不可逆的变更上。**技能、agent 或插件** 是一个工具；
**框架** 高出一级 —— 是一颗 *星*：一个项目的工具、规则、门禁与记忆，绑成一个运作的整体。
**forge-harness 就是这些星所栖居的星系**，它把众多框架绑定在共享的下限之上，让它们一起演化而不是
四散漂移。它还能在自己的沙箱里**以仿真方式跑一个现场框架**，再把它**输出 (emit)** 为一个独立的
框架 —— 🟥 请把这一步读作行进方向，而不是一项已出货的功能：孵化舱迄今只输出过一次，而那次运行
并没有走完整套流程。

```
forge-harness/   ← 中枢（持久大脑）              Project A ──→ 在 CLAUDE.md 中连接中枢
├── knowledge/   → 跨所有项目共享                Project B ──→ 在 CLAUDE.md 中连接中枢
└── tracks/      → 每个项目的工作记录
```

在结构上它是 **两个层** —— 一个与模型无关的 **方法论层**（`tracks/`、`knowledge/`、`SKILL.md`
文档），和一个 Claude-Code 原生的 **自动化层**（agent、hooks、斜杠命令、`CLAUDE.md` 规则）。
这条边界是刻意的，不是待填补的缺口：[`docs/codex-compat.md`](docs/codex-compat.md)。
**它所处的位置（2026）：** 基础的 agent 编排正迅速商品化为标准基础设施，而 FH 刻意不把任何东西押
在那套管道上 —— 它的持久层是那些 *不会* 商品化的东西：治理门禁、漂移控制，以及跨项目复利循环。
路由与派发是手段；**门禁与循环才是资产。**

### 五重身份 —— FH 是为了什么

这不是五个模块，也不是五项已出货的功能：它们是 **技能自然聚拢成的形状**，是事后给它命名，而不是
叠加在它们之上。

| | 身份 | 一个人得到什么 |
|---|---|---|
| **①** | **框架集群 (Harness cluster)** | 一个任务同时驾驭多个框架，治理在它们 *之间* 算出来 —— 没有的能力就**调用**而不是自己造，看到该造的就**吸收** |
| **②** | **项目孵化器 (Project incubator)** | 新框架出炉时 **就已经会走路**，而不是一副空的脚手架 |
| **③** | **治理门禁 (Governance gate)** | 不该出货的东西被 **机械地** 拦下，而不是靠记得去检查 |
| **④** | **前沿吸收 (Frontier absorption)** | 拿不准的时候，先翻 *自己已有的* 再翻 *世上已有的* —— 于是什么都不重造 |
| **⑤** | **放大器 (Amplifier)** | 一句简短的意图被一路锻造到成品 |

第六行是刻意不放进表里的：`Ⓑ` **项目助推器 (Project Booster)** —— FH 的机制去加速 *对方框架自身
的开发* —— 是真实存在且已被评级的，但它坐在另一层上，所以用字母而不是编号。**而且这张表不是五项
能用的功能**：成熟度按身份逐项评级（`aspirational → partial → RC → REALIZED`）并配有带日期的
证据，刻意 **没有** 复制到这里 —— 同一个等级放进两个文件总会有一个先腐坏，而本页有四种语言版本。
在你依赖上表任何一行之前，请先读那些等级：
[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md)。 而**每一个该怎么用** —— 哪条命令、哪扇门点亮哪重身份 —— 见 [`docs/IDENTITIES.md`](docs/IDENTITIES.md)：等级说的是*做到了几分*，那一页说的是*怎么调用*。

有两条性质横贯这五重身份。**它搭上前沿，而不是给前沿打补丁** —— 跨家族派发（Claude、Codex、
Gemini、本地）是为了共同演化，不是为了糊住弱点。**去相关 (decorrelation)** 是当下的信任杠杆，
也是本页最吃重的那个词：刻意让两道检查以 *不同的方式* 失败 —— 换一个模型家族、拿真实目标真跑
一次、请外人来审你自己的记录 —— 好让其中一道看不见的，另一道看得见。而且 **它沿两个方向演化**：
向外，每次会话的教训复利汇入中枢；向内，同一套门禁掉转过来对准框架自己。

---

## 它是怎么被造出来的 —— 三 · 四 · 五 · 六

**三段工序 · 四大引擎 · 五重身份 · 六轴验证。** 上面那五重身份，是工序与引擎彼此咬合的地方浮现
出来的东西 —— 这五重是已经锻打过、评过级、稳定下来的那些；其余的身份则随着你往哪个方向驾驭、
推到多远而浮现又退去（操作者的表述，2026-09-05）。**四大引擎**（`judgment-circuit` · `ship-gate` ·
`context-continuity` · `external-grounding`）是所有带 FH 特征的产出共同的那个内核；而 **三段工序**
—— ① 在设计 *之前* 先立判断回路 → ② 中段并行去相关 → ③ 在六条轴上烧一遍 —— 是 FH 每一件活计都要
走的顺序，锻造一台引擎本身也不例外，速度是末尾那支箭，不是第四个方框。**整张地图** —— FH 是什么、
它是怎么实现的（每个节点都是一条真实路径）、为什么可信（门禁 · 检查通道 · 等级，都带文件路径），
以及哪些是操作者本地的、哪些是通用的 —— 都在一页里：[`docs/map/FH_MAP.md`](docs/map/FH_MAP.md)，
旁边还有三张可交互的图 —— 可在 **[chrono-meta.github.io/forge-harness](https://chrono-meta.github.io/forge-harness/)** 上直接看。

[![FH 整张地图 —— 从入口 → 三段工序 → 四大引擎 → 身份的流程（点击查看可交互版本）](docs/map/fh_process.workflow.png)](https://chrono-meta.github.io/forge-harness/map/fh_process.workflow.html)
⚠️ **六条轴不是第四层**，它们是 *③ 段究竟由什么构成*。完整正典，以及为什么这刻意 *不是* 一个干净的分层：
[`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md) —— 同样这三段
用铁匠的用词（锻造 · 淬火 · 回火）讲一遍，在 [`ETHOS.md`](docs/ETHOS.md#the-forge) 里。

🟥 **轴不是按*有多对抗*来分的，是按*它拿到了什么*来分的。** 给两位审阅者同样的输入，同一个盲点
就会留下来，你堆多少位都一样：

| 轴 | **它拿到什么** | 它抓到什么 | 典型手段 |
|---|---|---|---|
| **ⓐ 不同家族** | 变更 + 作者的框架叙述 | **实现** 错了 | 换一个模型家族的审阅者（`auto-decorrelation`） |
| **ⓑ 立场 (standpoint)** | 变更 + **目标框架自己的正典** | **你引用的那条规约是不是真这么说** | 在那个框架自己的仓库与规则里跑这份变更（[`§7`](knowledge/shared/harness-core/field_verdict_crossfamily_gate.md)） |
| **ⓒ 隔离接地** | 作者写下的那些句子 —— 他的主张，*以及* 他在 **动手之前声明过的东西** —— + 此刻的这棵树 | **主张** 错了 · 增量与当初声明的对不上 | 找一个没写过它的人，把它说的重新测一遍 |
| **ⓓ 第三方对面** | 问题 + **别人的代码库** | **这是不是早就被解过了** · 你的变更会碰到别人仓库的哪里 | 在一个无关的第三方仓库里看同一个问题 |
| **ⓔ 首次真实使用** | 一个实打实的目标 | **你测量的方式** 错了 —— 量具的量具 | 拿一个真实目标真跑一次，然后动手核对 |
| **ⓕ 撤回并观察** | 把接线删掉之后的那棵树 | **锚** 错了 —— 那道检查是装饰 | 把它守护的东西删掉，确认 *正是那一条* 检查变红 |

**你不必每次都把六条跑满，这正是设计** —— 别做乘法，要挑：

```
一行小修（typo · gitignore）    一条都不烧 —— 答案只有一个时，栽一套坐标系本身就是开销
普通代码变更（可逆）             ⓔ 首次真实使用 + ⓕ 撤回
判定 · 门禁代码                 + ⓐ 不同家族 —— 判定逻辑正是那种「与作者共享同一份乐观」的
                               审阅者会结构性地漏掉的东西
会碰到别人框架的变更             + ⓑ 立场 —— 就算堆三个家族，若三个都吃下了你的框架叙述，
                               「那份正典是不是真这么说」就没有人去看
超大型 · 不可逆                 + ⓒ 隔离 + ⓓ 第三方对面。全部烧一遍
```

一条轴是由它的 **输入** 定义的，不是由审阅者的能力定义的，所以基础模型的进步取代不了这一套：
模型再强，也依然看不见它没拿到的信息。🟥 **引用之前必须读的限制** —— 这张表是 **n=1**（一份产物、
一次会话、一位作者）；而当 16 条发现被抹去出处、交给另外两个家族的分类器做盲判之后，作者归给 ⓓ 的
**5 条里有 3 条** 被判成了别的轴。在这些门禁里过完的一整天，连同被漏掉的部分：
[`docs/GATE_DAY.md`](docs/GATE_DAY.md)。

---

## 规则住在哪里 —— 三个位置

框架靠把规则写下来学习，而那份总是被加载的文件只会越来越长 —— 于是推理走进死角：*一个不断学习的
框架，启动成本只会不断变贵。* 但它并没有，因为一条规则有 **三个位置**，选哪一个取决于 *这条规则
必须在什么时候触发*：**总是加载**（触发条件是一个 *意图* —— 没有任何 hook 能挂上去，所以显著性是
唯一的一层）· **门禁自己的报错信息**（触发条件是一个 *动作*；那条挡住你的信息同时也在教你正确的
形态，而且这个位置是免费的）· **hook**（记录本身的属性 —— 在场、带类型、可归属、非空洞）。
中间那个位置通常是空着没用的。完整的表，以及"它只在失败时才触发"这条诚实的限制：
[gate-locality](knowledge/shared/harness-core/gate_locality_principle.md) §Where a rule lives。

---

## 在 Claude Code 之外跑 —— `fh-gate` CLI

FH 把任何编码 agent（OpenCode、Codex 等）包裹为一道 **生成后治理门禁**。

```bash
npx --package @chrono-meta/fh-gate fh-gate                    # 默认：Claude 后端
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate   # Codex 后端
FH_BACKEND=cross npx --package @chrono-meta/fh-gate fh-gate   # 两个家族都跑，findings 取并集
# → FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE
```

对每种运行时都是同一套治理提示。`auto` 是回退式 *选择* —— 它只跑 **一条** 腿；`cross` 会跑两个
家族并对 findings 取并集（只有一方发现的问题仍然是问题），成本约 2 倍，适用于判定 / 门禁 /
不可逆面的变更，而不是默认值。输出始终声明实际跑了哪些腿，所以单家族的结果绝不会读起来像交叉
验证过。`fh-run`（直接跑一个技能或 agent）、`fh-goal` 与 `fh-codex-doctor`（适配器漂移检查）
随它一起出货 —— 参数与完整环境变量表见 [`CHEATSHEET.md`](CHEATSHEET.md)，规格见
[`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md)。
**推荐姿态 —— Claude Code 作编排者，其余作边车**：非 CC 运行时也可以当你的主 agent，并通过
`fh-gate`/`fh-run` 保有方法论层，但拿不到自动驾驶层（hooks 不会自动触发，派发需要适配器）——
逐层详情在 [`docs/codex-compat.md`](docs/codex-compat.md)。

---

## 模型设置

Claude Code 不会按任务复杂度自动选择模型 —— 这个要你设置一次。

| 命令 | 谁执行什么 | 最适合 |
|---|---|---|
| `/model sonnet` | Sonnet 会话；FH 在声明的下限 (floor) 上派发更高层级的子 agent | **FH 默认** —— 运行 + 日常开发 |
| `/model opus` | Opus 处理一切 | 编辑框架的会话 · 每一轮最大深度 |
| `/model opusplan` | Opus *规划* · Sonnet 执行 *(当 Opus 介入时)* | 讲究成本的日常编码 —— 见注意事项 |

已测量：*运行* FH 几乎与模型无关 —— 上下文里的规则完成了大部分工作 —— 所以 FH 会自行在声明的
下限上派发那少数几个深度敏感的轮次，并且 **绝不切换你的会话模型**；上限低于下限的环境会拿到一个
明确的 `below-floor` 标记，而不是悄无声息地降级。⚠️ `opusplan` 的 Opus 介入 **无法保证**（一次
实测的 10 轮运行里是 0 轮）。那条准则背后的两条结构性定律、可选本地边车的硬件层级，以及多模型
边车姿态：[`docs/MODEL_SETUP.md`](docs/MODEL_SETUP.md)。

---

## 41 skills · 8 agents

计数 = 未废弃的技能。按验证 · 编排 · 诊断 · 收割 · 门禁 · 发现 · 模拟 · 设置分簇，另有 8 个 agent
（`challenger` · `quench-challenger` · `beginner` · `main-player` · `expert` · `fact-checker` ·
`hub-persona-auditor` · `persona-innovator`），由这些技能派发或直接点名调用。**完整用语手册** ——
每个技能和 agent 连同它的一句话定义，以及触发它的那句平白说法：
[`CHEATSHEET.md` §12](CHEATSHEET.md#12-skills--agents--what-each-does-and-what-to-say)。

---

## 了解更多

| 资源 | 用途 |
|---|---|
| [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) | 怎么真正用起来，从头到尾 |
| [`CHEATSHEET.md`](CHEATSHEET.md) | 完整命令参考 |
| [`docs/ETHOS.md`](docs/ETHOS.md) | FH 相信什么 —— 大锻炉、冷审阅者、让主张配得上自己的措辞 |
| [`docs/WHY.md`](docs/WHY.md) | 它为什么存在 |
| [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md) | 证据 —— 论文、带日期的运行、外部收敛 |
| [`docs/GATE_DAY.md`](docs/GATE_DAY.md) | 在这些门禁里过完的一天，测量过，漏掉的也点了名 |
| [`docs/MODEL_SETUP.md`](docs/MODEL_SETUP.md) | 用哪个模型跑 FH、硬件层级、边车 |
| [`docs/codex-compat.md`](docs/codex-compat.md) | 在非 Claude-Code 运行时上跑 FH |
| [`knowledge/shared/GLOSSARY.md`](knowledge/shared/GLOSSARY.md) | 不认识的词 |
| [`CLAUDE.md`](CLAUDE.md) | AI 运行规则 + 同步/推送协议 |
| [`AGENTS.md`](AGENTS.md) | 运行时 agent 规格 |
| [`CATALOG.md`](CATALOG.md) | 过往工作检索索引 |
| [`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md) | 三层正典 —— 工序、引擎、身份 |
| [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) | 身份等级、两条版本轨道、dominance 结果 |
| [`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md) | 治理门禁规格 |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | 如何贡献技能与模式 |
| [`tracks/_contrib/`](tracks/_contrib/README.md) | **同意通道** —— 分享一个去标识化的工作会话；仓库在众多操作者之间复利累积 |

> **FH 论文**：v1.0 方法论 · [Zenodo](https://zenodo.org/records/20397566)（DOI
> 10.5281/zenodo.20397566）· cs.SE companion，已发表 ·
> [Zenodo](https://zenodo.org/records/20680081)（DOI 10.5281/zenodo.20680081）· cs.AI companion
> 筹备中。这些、独立的收敛性工作，以及每一项的注意事项：
> [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md)。
