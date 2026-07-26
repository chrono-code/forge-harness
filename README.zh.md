<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/banner.png" alt="forge-harness — 锻造你的项目，让它通过，然后更快出炉。品质是杠杆，速度是结果。" width="680">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e.svg" alt="MIT License"></a>
  <a href="https://zenodo.org/records/20397566"><img src="https://img.shields.io/badge/DOI-10.5281%2Fzenodo.20397566-blue.svg" alt="DOI"></a>
  <img src="https://img.shields.io/badge/Claude_Code-compatible-a855f7.svg" alt="Claude Code">
  <a href="https://github.com/chrono-meta/forge-harness/issues/72"><img src="https://img.shields.io/badge/Codex-beta_·_help_validate-f59e0b.svg" alt="Codex-compatible beta — help validate (issue #72)"></a>
  <a href="https://www.npmjs.com/package/@chrono-meta/fh-gate"><img src="https://img.shields.io/npm/v/@chrono-meta/fh-gate.svg?color=cb3837" alt="npm"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.ko.md">한국어</a> · <b>中文</b> · <a href="README.ja.md">日本語</a>
</p>

<p align="center">
  <b>锻造你的 Claude Code 项目 —— 让它通过，它会更快出炉。</b><br>
  一个实践者的 <b>元框架 (meta-harness)</b> —— 你的项目框架们所栖居的星系。<br>它抬高每个项目的 <b>下限 (floor)</b>（把设置框架化）和 <b>上限 (ceiling)</b>（加速工作），再把这些收益在你的整个项目组合中复利累积。
</p>

<p align="center">
  <b>品质是杠杆，速度是结果。</b> 每一次变更都要挣得通过门禁的资格 ——<br>对抗 (adversarial) · 幽灵 (phantom) · 回归 (regression) —— 而 <i>正是这一点</i>让下一次变更更快。
</p>

<p align="center">
  <i>Fork 它。改名。让它成为你的。</i>
</p>

<p align="center">
  <img src="docs/pillars.svg" alt="FORK · ADAPT · COLLABORATE · EMPOWER" width="680">
</p>

<p align="center">
  <a href="docs/ETHOS.md"><b>原则</b></a> ·
  <a href="docs/WHY.md"><b>存在的理由</b></a> ·
  <a href="docs/OUTPUT_EVIDENCE.md"><b>证据</b></a> ·
  <a href="CHEATSHEET.md"><b>如何使用</b></a>
</p>

---

| 如果你为此而来…… | forge-harness 这样解决 |
|---|---|
| 会话结束后上下文就消失了 | 持久化的 `tracks/` —— 随处可续、可恢复 |
| 你在每个项目里重复相同的设置 | 一次连接到中枢，跨所有项目共享 |
| 团队的 AI 经验只留在个人脑子里 | 把它编码固化，让所有人共享 |
| 你希望工作越积累，AI 越 *变好* | 技能与模式随会话逐次复利累积 |
| 你需要给 AI 生成的代码一层治理 | `fh-gate` 把任何编码 agent 包裹为一道生成后门禁 |

> **本文档面向人类。** AI 运行规则 → `CLAUDE.md` · 命令参考 → `CHEATSHEET.md`

---

## 2 分钟上手

**前置条件**：Claude Code CLI —— 用 `claude --version` 确认

```bash
# 1. 安装插件
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness

# 2. 克隆中枢
git clone https://github.com/chrono-meta/forge-harness.git ~/forge-harness
cd ~/forge-harness

# 3. 启动会话
claude
```

> ✅ Claude 会读取 `CLAUDE.md`，并询问要连接哪个项目或开始什么任务。
> 说 **"连接一个项目"** → 中枢扫描 `../`，找到 `.git` 目录，创建 `tracks/{project}/`。

**仅插件（不克隆）：**
```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git  # 仅一次
claude plugin install -s user fh-meta@forge-harness
cd ~/projects/{your-project} && claude
```

> ⚠️ **仅插件是部分协同。** 你得到技能和 agent，但 **得不到** Layer 1 —— 即
> `CLAUDE.md` 治理（主动引导、4 轴门禁、模式分支）和复利式上下文（`tracks/` 记忆累积、
> `harvest-loop` 学习）。每个技能在隔离状态下运行效果相同；缺的是让它们在会话之间
> 复利累积的编排。当你想要完整套装而不只是工具时，请克隆中枢（见上）。

> 🚪 **初来乍到 / 只想要技能？** 从有主张的正门开始 ——
> [`templates/starter_profile.md`](templates/starter_profile.md)：一条安装命令、一份精选的
> 头五个技能，以及一道零安装的治理门禁（`npx … fh-gate`）。其余技能等你需要时再出场。

---

## 它是什么

forge-harness 由 **两个截然不同的层** 构成：

| 层 | 内容 | AI 兼容性 |
|---|---|---|
| **方法论层** | `tracks/`、`knowledge/`、`SKILL.md` 文档、会话协议 | 任何 AI 模型 |
| **自动化层** | `plugins/*/agents/`（FH agent）、`.claude/agents/`（现场项目覆盖）、hooks、斜杠命令、`CLAUDE.md` 规则 | 仅 Claude Code |

方法论层是可移植的核心 —— 持久中枢、累积学习、跨项目知识策展。自动化层让它在运行 Claude Code 时毫无摩擦。

**它所处的位置（2026）：** "框架工程 (harness engineering)"如今已是公开范式 —— 而基础的 agent
编排正迅速商品化为标准基础设施。FH 刻意不把任何东西押在那套管道上。它的持久层是那些 *不会*
商品化的东西：治理门禁（对抗 · 幽灵 · 回归）、漂移控制，以及跨项目复利循环。路由与派发是
手段；**门禁与循环才是资产。**

```
forge-harness/   ← 中枢（持久大脑）
├── knowledge/   → 跨所有项目共享
└── tracks/      → 每个项目的工作记录

Project A  ──→  在 CLAUDE.md 中连接中枢
Project B  ──→  在 CLAUDE.md 中连接中枢
```

---

## 为什么它是框架，而不是工具箱

先说框架*为何存在*：它读取你的**意图**，并把意图锻造成**机械化的形态** —— AI 能可靠遵循的规则，
或者根本不需要模型的确定性代码。你给出意图与洞察；框架把它们锻成可执行的形态；你确认；它便成为
机械。回报是**人这一侧的试错大幅减少**：请求 → 反馈 → 重新生成的循环并没有消失，而是*换了位置*
—— 挪进框架内部，由 agent 与 sidecar 并行运转 —— 于是你的时间下降，你的注意力只花在不可逆的
变更上。

规模是第二个重点。**技能、agent 或插件** 是一个工具。**框架** 高出一级 —— 是一颗 *星*：
一个项目的工具、规则、门禁与记忆，绑成一个运作的整体。**forge-harness 就是这些星所栖居的
星系**：它把众多框架绑定在共享的下限之上以防止漂移，并让它们一起演化而不是四散。

这个星系不只是容器。FH 可以在自己的沙箱里**以仿真方式跑一个现场框架** —— 单次昂贵，总体
更便宜，因为试错汇聚在一处并复利累积 —— 当仿真验证通过，它就把该项目**输出 (emit)** 为一个
独立的、特化的框架。这就是它所朝向的目标。实际上，它以四种方式运作：

**① 组装 (Assemble)** —— FH 以优化后的 token 成本运行一整 *簇* 框架，并把最合适的那个交到你手上。
你不是一个个去接线技能；你得到的是一个 **框架** —— 连同它的插件、技能与 agent —— 已按需组装好。

**② 锻造 (Forge)** *(品质门禁)* —— 每次变更都要穿过对抗 · 幽灵 · 回归门禁来挣得它的资格。
这不是"多检查"。它是一个 **责任路由器 (responsibility router)**：随着自动化上升，人的签字变少但
每一次更重，于是门禁只把你的注意力花在变更 *不可逆* 的地方。品质是杠杆；速度是结果。

**③ 边车 (Sidecar)** —— 能力本身留在前沿。FH 跨多个 LLM（Claude、Codex、Gemini、本地）派发，
使原始算力永不绑死在单一模型或单一世代上。重点 *不是* 去修补每个模型的弱点 —— 随着模型变强，
那套脚手架会成为死代码。重点是 **搭上前沿的演化**：底座 (substrate) 现在原生就能做到的就卸掉，
它接下来推出的就吸收进来。去相关 (decorrelation) 是当下的信任杠杆（跨家族面板胜过单一模型的
上限）；共同演化 (co-evolution) 才是结构。

**④ 自演化循环 (Self-evolving loop)** —— 框架无需重建就变得更好，沿两个方向：**向外**，
每次会话的教训复利汇入中枢，让下一个项目起步更快；**向内**，它捕捉并修复 *自身* 的缺陷
（4 轴门禁、双向校验、按用户适配）。

整件事是一次分工：**原始能力属于模型；组装、信任与演化属于框架。**

> **这里的自愈不是一句主张 —— 它就在提交日志里。** 正是这份 README 的语气规则，在会话进行中
> 被 FH 抓到自身漂移而修正：语气失误 → 诊断 → 一位攻击 *它自己第一版修正* 的跨家族 challenger
> → 再修正 → 下限层级复核 → 记忆更新。一个框架修复自身缺陷的实录 —— 是记录，不是口号。

---

## 为什么它有效

和你的 AI 经历一场漫长的协同创作会话后，你和它共享同一份上下文 —— 也共享同样的盲点。值得拥有的
审阅者，是那个从未见过你推理过程的人。你可以手动获得它：把成果粘进一个全新的空聊天窗口。FH
只是把这件苦差事变成了一条例行命令。

- **边车 / agent 派发** → 一位对你会话上下文一无所知的审阅者
- **steel-quench · phantom-quench** → 那一遍冷审阅，随需即得

它与模型无关：与某一个 AI 共同构建，用任何其他 AI 跑那遍冷审阅。谁缺席了原来的会话，谁就是你的
冷审阅者 —— 这不是给模型排名。

**FH 不主张的东西：** 冷审阅是你的基座模型自身的能力，不是 FH 附加的检测引擎 —— 给一个全新实例
一句普通提示，也能做到其中大部分。FH 的价值更窄也更诚实：它取一套源自真实实践的方法，把跑那遍
独立审阅，从一件你会跳过的苦差事变成 *例行*。方法论是可复制的；FH 打包的是工作流，而不是秘方。

---

## 面向 AI 生成代码的治理层

FH 把任何编码 agent（OpenCode、Codex 等）包裹为一道 **生成后治理门禁**。

```bash
npx --package @chrono-meta/fh-gate fh-gate                    # 默认：Claude 后端
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate   # Codex 后端
FH_BACKEND=auto npx --package @chrono-meta/fh-gate fh-gate "src/foo.ts" full
# → FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE
```

`fh-gate` 对两种运行时使用同一套 FH 治理提示。`FH_BACKEND=claude` 运行 `claude --print`；`FH_BACKEND=codex` 运行 `codex exec`；`FH_BACKEND=auto` 在两个 CLI 都存在时优先选择 Codex —— 但 `auto` 是回退式*选择*，只运行一条腿。`FH_BACKEND=cross` 会运行两个模型家族并对 findings 取并集(只有一方发现的问题仍然是问题，因此是并集而非投票)，判定取各腿中最严重者。成本约为 2 倍，因此并非默认值，适用于判定/门禁/不可逆面的变更。输出始终声明实际运行了哪些腿(`FH_GATE_LEGS:`、`FH_GATE_DECORRELATED:`) —— 在只装了一个家族的机器上，`cross` 会降级为单腿并明确说明，因为让单家族结果读起来像交叉验证过更糟。

若要在 Claude Code 之外直接执行技能或 agent，使用 `fh-run`：

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run --skill phantom-quench --file docs/foo.md
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run --agent fh-commons:quench-challenger --file plugins/fh-meta/skills/foo/SKILL.md
```

若要检查某个变更过的 FH 技能/agent 表面是否仍有一条干净的 Codex 适配器路径，运行：

```bash
npx --package @chrono-meta/fh-gate fh-codex-doctor --strict
```

`fh-codex-doctor` 扫描规范的技能/agent 注册表，报告哪些单元是 Codex 原生、需要适配器、Claude 原生
或未分类。它是那条薄适配器边界的漂移检测器；它不试图克隆 Claude Code 自动化层。从 FH 检出目录运行时
扫描当前工作树；在检出目录之外运行时扫描已安装的包。

对于以 Codex 为主的工作，只要可用就继续使用 Codex 自带的 goal/session 功能。`fh-goal` 只是一个可移植
包装器，用于那些之后应跟上 FH 治理的一次性非交互运行：

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-goal --prompt "Implement X and update tests" --gate quick
```

更广的 FH 自动化层仍然依赖 Claude Code 来提供子 agent、hooks 与斜杠命令。可移植路径是共享文档
加运行时适配器，而不是分开维护的 Codex 分支和 Claude 分支。

**推荐姿态 —— Claude Code 作编排者，其余作边车。** FH 的自动化层（自动触发的 hooks、子 agent
派发、引导、记忆）是 Claude-Code 原生的，因此最完整的体验是 **以 Claude Code 作主编排者，把
Gemini、Codex 或 Antigravity（`agy`）作为主动使用的边车**。你也可以 **用一个非 CC 运行时作主
agent** —— 通过 `fh-gate`/`fh-run` 你保有完整的方法论层与 M1 技能，但 **得不到** 自动驾驶层：
hooks 不会自动触发，M2 的 agent 派发步骤需要适配器（或交互式批准），M3 技能仅供参考。这是一条
刻意的两层边界，不是待填补的缺口。各运行时详情：[`docs/codex-compat.md`](docs/codex-compat.md)
（逐层）与 [`multi_model_sidecar_strategy.md`](knowledge/shared/harness-core/multi_model_sidecar_strategy.md)
（边车引擎，含 2026-06-18 EOL 时点的 Gemini→`agy` 承接）。

**实证结果（2026-05-31）**：应用于 OpenCode 的 AI 生成 `permission/arity.ts`（163 行，CI 绿）。
当前门禁语义将其归为 BLOCKED：2 项 CI 未捕获的 A 级发现（允许列表中的短 token 溢出、arity
表中缺失的 executor 工具）。

完整规格：[`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md)

---

## 大锻炉 (The forge)

forge-harness 把项目当作钢来对待 —— 而这个隐喻是字面的，不是装饰。工作被塑形、以攻击淬硬，
唯有如此才更快出炉，因为它挺过了考验。

| 工序 | 发生了什么 | 命令 |
|---|---|---|
| **锻造 (Forge)** | 把生坯项目塑形为框架 —— 抬高其下限 | `install-wizard`、"把这个项目框架化" |
| **淬火 (Quench)** | 以攻击将其淬硬 —— 冷审阅只让健全的东西留存 | `steel-quench` · `phantom-quench` |
| **回火 (Temper)** | 把淬硬资产里的脆性 (brittleness) 再退掉 | `steel-quench` Wave-T · `templates/temper_check.sh` |
| → **加速 (Accelerate)** | 一把挺过锻炉的刀刃切得更快 | `goal-quench` —— *Pass → Accelerate* |

四道工序全部出货。回火 (Temper) 在被造出 *之前* 就先起了名字 —— 刻意为之（见
[`ETHOS.md`](docs/ETHOS.md#the-forge)）—— 并在测量运行验证之后出货。围绕这座锻炉，还有两个
签名部件让它持续运转：`harvest-loop`（每次会话的教训成为永久技能）与
`agent-composer`（编排派发）。其余技能等你需要时再出场 —— 完整清单见下。

## 37 skills · 8 agents

<details>
<summary>全部资产激活检查</summary>

| 资产 | 角色 | 触发语 |
|---|---|---|
| `steel-quench` | 全谱对抗验证 | "跑一遍淬火"、"从根上攻击" |
| `phantom-quench` | 幽灵主张检测 + 溯源回溯 | "验证来源"、"接地审计" |
| `harvest-loop` | 会话末学习 → 演化流水线 | "收割这次会话" |
| `agent-composer` | 设计最优 agent 派发 | "并行跑"、"用哪些 agent？" |
| `sim-conductor` | 元模拟编排者 | "外部用户视角" |
| `context-doctor` | token 效率 + `.claudeignore` | "会话变慢了"、"清理上下文" |
| `harness-doctor` | 框架结构诊断 | "检查我的 Claude 配置" |
| `pipeline-conductor` | 4 轴品质门禁（后向/对抗/前向/记录） | "跑品质门禁" |
| `field-harvest` | 把现场模式反向传回中枢 | "这个我能复用" |
| `frontier-digest` | HN + arXiv → 可执行洞见 | "AI 趋势摘要" |
| `hub-cc-pr-reviewer` | 自动 PR 审阅 | "审阅这个 PR" |
| `verify-bidirectional` | 反向校验决策 | "那样对吗？"、"再确认一下" |
| `deep-clarify` | 苏格拉底式需求澄清 | "我不确定要造什么" |
| `install-wizard` | 初次引导 | "首次设置" |
| `plugin-recommender` | 插件推荐 | "这有没有好用的工具？" |
| `apex-review` | 高管视角品质审阅 | "这个撑得住吗？" |
| `meta-prompt-builder` | 元提示设计 | "给 agent 写个提示" |
| `asset-placement-gate` | 中枢 vs 项目资产路由 | "这个该共享吗？" |
| `cross-ecosystem-synergy-detection` | 跨工具协同探测 | "我的工具们配合得好吗？" |
| `corpus-grounding-expander` | 多版本公有领域语料 → 已验证公理接地库 | "扩大接地语料" |
| `persona-roster-expander` | 人设种子 → 分层的、判断映射的阵容 | "扩大这些人设" |
| `convergence-loop` *(fh-commons)* | N 轮收敛循环 | "单遍通过很可疑" |
| `token-budget-gate` *(fh-commons)* | 任务前 token 成本估算 | "这个多贵？" |
| `mcp-circuit-breaker` *(fh-commons)* | MCP 工具失败模式检测 | "MCP 一直失败" |
| `quench-challenger` *(fh-commons)* | 对抗压测 agent | "拿魔鬼来挑战这个" |
| *(+ 更多资产)* | marketplace-gate · contention-layer · edit-manifest · fact-checker · goal-quench · hub-persona-auditor · install-doctor · memory-hygiene · persona-innovator · prompt-regression · public-surface-audit · salience-splitter | |

| 激活数量 | 诊断 |
|:---:|---|
| **28+** | 高级 —— 串联 agent-composer + sim-conductor + steel-quench + pipeline-conductor |
| **10–27** | 激活阶段 —— 逐步启用未勾选的资产 |
| **0–9** | 起步阶段 —— 从 `install-wizard` 开始 |

**按你想做的事找技能：**

| 集群 | 技能 |
|---|---|
| 验证 | `steel-quench` · `phantom-quench` · `convergence-loop` · `prompt-regression` · `return-path-gate` |
| 编排 | `agent-composer` · `pipeline-conductor` · `goal-quench` · `deliberation` |
| 诊断 | `harness-doctor` · `context-doctor` · `install-doctor` · `mcp-circuit-breaker` |
| 收割 / 学习 | `harvest-loop` · `field-harvest` · `edit-manifest` · `memory-hygiene` |
| 门禁 / 守卫 | `token-budget-gate` · `asset-placement-gate` · `marketplace-gate` |
| 发现 | `plugin-recommender` · `cross-ecosystem-synergy-detection` · `frontier-digest` · `verify-bidirectional` |
| 内容 / 模拟 | `sim-conductor` · `apex-review` · `meta-prompt-builder` · `deep-clarify` |
| 设置 | `install-wizard` · `hub-cc-pr-reviewer` · `salience-splitter` |

> **完整用语手册** —— 每个技能 + agent 连同其一句话定义，以及触发它的平白说法：
> [`CHEATSHEET.md` §12](CHEATSHEET.md#12-skills--agents--what-each-does-and-what-to-say)。

</details>

---

## 模型设置

Claude Code 不会按任务复杂度自动选择模型 —— 这个要你设置一次。

```bash
/model sonnet   # 推荐默认 —— FH 会在关键处自行派发更强的模型
```

| 命令 | 谁执行什么 | 最适合 |
|---|---|---|
| `/model sonnet` | Sonnet 会话；FH 在声明的下限 (floor) 上派发上层 token 的子 agent | **FH 默认** —— 运行 + 日常开发 |
| `/model opus` | Opus 处理一切 | 编辑框架的会话（Mode D）· 每一轮最大深度 |
| `/model opusplan` | Opus *规划* · Sonnet 执行 *(当 Opus 介入时)* | 讲究成本的日常编码 —— 见注意事项 |

**为什么现在默认 Sonnet 也行得通**：测量结果（见下文 §Model setup evidence note），*运行* FH 几乎
与模型无关 —— 上下文里的规则完成了大部分工作。仍然需要更强模型的，是一小部分深度敏感的轮次，而
FH 会自行处理它们：**部分技能与 agent 声明了一个模型层级下限**（例如 `quench-challenger` 的下限
在 opus），当你的环境能够到达时，它们会以那个下限层级的子 agent 派发 —— 你的会话模型不受触碰。
**FH 绝不切换你的会话模型**：你手动设置的默认值会被遵守；下限只作用于 FH 自身的子 agent 派发。
若你的环境上限低于某个下限（例如仅 Sonnet 的 API 路由），带下限的资产仍以可用的最佳层级运行，
并在其输出中打上明确的 `below-floor` 标记 —— 降级的交付是可见的，绝不悄无声息（层级下限解析：
`knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Tier-floor`）。

**`opusplan` 注意事项（已测量）**：其 Opus 介入 **无法保证** —— 在一次测量的 10 轮运行中它用 Opus
**0** 轮（CC 把很少的轮次归类为 "plan-mode"）。若你想每一轮都用 Opus，请固定 `/model opus`
（后续运行中 22/22 轮均为 Opus）。**子 agent 派发** 模型由派发自身的 `model` 参数设定；会话模型/
plan-mode **不会** 传播到子 agent。

> **按角色**：运行 FH（现场项目、门禁、日常开发）→ `/model sonnet` + 让下限去升级。编辑框架
> 本身（Mode D）→ 固定你手上最强的模型 —— 框架 *自我开发* 才是层级深度可测量地物有所值的地方
>（设计增量发现），而运行则不然。子 agent 的 token 成本可在会话 jsonl 的 `message.model` 中经
> CC 看到。

**测量，而非断言**（实测示例）：在一套盲测规则应用测验中，*运行* FH 几乎与模型无关 ——
**测量的每一个 Claude 层级都得分 94–100%**（Fable、Opus 4.8、Sonnet 4.6 与 5、Haiku 4.5）；
失掉的少数分数是格式纪律，绝非陷阱或门禁级失误。各层级只在超越评分标准的 *设计* 增量上分野
（开发框架，而非运行框架）—— 这正是为何默认是配以 **层级下限派发** 覆盖深度敏感轮次的 Sonnet，
而固定更强的模型仅推荐用于编辑框架的会话。

这被表述为一条 **不变式，而非逐模型排行榜。** 两条结构性定律，新版本都无法推翻：

1. **运行在各层级间趋于平坦** —— 上下文里的规则完成工作，所以每一层级在规则应用上都触到天花板
   （在 2026-07-03 的一次复现中，Sonnet 5 在测验天花板上与 Opus 4.8 打平）。
2. **深度（设计增量）按层级排序，且这个排序在 *同一世代内* 固定** —— 较低层级绝不会超越 **同**
   世代的较高层级（层级的定价就是要物有所值，所以厂商保持排序）。*跨* 世代时，一个较新的低层级
   模型可以胜过一个较旧的高层级模型（运行上 Sonnet 5 ≥ Opus 4.8 正是这种跨世代情形）—— 但任何
   世代当前的顶层层级仍赢下它自己的深度轮次。

所以这条准则是恒久的，不会腐坏：**运行默认取中间层级；深度则升级到当前顶层层级。** 只有当一个
新模型成为现场主力 *候选* 时才有必要重新测量（一次性的跨世代阈值检查），绝不是为了重新确认同世代
的层级顺序 —— 那由设计保证。详情 + 带日期的运行：`docs/OUTPUT_EVIDENCE.md` §Validation signals。

如果你把外部 CLI（Gemini、Codex、`gh copilot`）当边车用，它们的成本记在各自的额度里，不会出现在 CC 的 token 显示中。

### 硬件层级（本地边车是可选的加速器）

FH **不需要本地 LLM** —— 基准线就是任何能跑 Claude Code 的东西。本地模型是 *可选* 的，仅用于
金丝雀 (canary) / 廉价广度的档位：

| 层级 | 规格 | 本地运行 | 换来什么 |
|---|---|---|---|
| **最低** | 任何能跑 Claude Code 的东西 | 无 | 完整方法论 + 门禁；运行 FH 在测过的每一层级都 ~模型平坦（94–100%） |
| **推荐** | 笔记本级，~16GB RAM | 一个 8B 级量化模型（例如一个 8B / 小型 Gemma） | 一道免 token 的 **下限金丝雀**（在计费模拟前先预筛）· 离线分诊 · 一条廉价广度的面板臂 |
| **可选（重）** | ~24GB 显存 GPU | 一个 27–32B 模型 | 一道 *更强* 的去相关金丝雀 |

> 本地层级是 **金丝雀，绝不是最终裁决** —— 已测量：下限模型漏掉了前沿捕获的一个微妙对抗案例
>（连 27–32B 本地模型在该案例上也只得 1/4）。它们降低 *广度的成本*；裁决留在前沿。

---

## 多模型边车

把 Gemini、Codex 或 `gh copilot` 作为独立审阅者，与 Claude 并肩运行。重点是 **上下文隔离**：
一个 *没有* 共同创作过这份工作的审阅者对它的泡沫 (froth) 是冷静的 —— 坐在协作 *之外* 的人，往往能
抓住那位如今成了共享成果拥护者的共同作者顺滑略过的东西。它是对称的，不是给模型排名：当你与
Gemini 共建时，一个全新的 Claude 抓它的泡沫；当你与 Claude 共建时，一个全新的边车抓 Claude 的泡沫。

在一个内部案例研究中，逐层叠加审阅者浮现出越来越多的问题 —— 单遍会话内的审阅漏掉的项，被跨会话的
人设抓到；而一个外部 CLI 审阅者浮现出几个 Claude 人设们共享盲点的问题。请把它当作一个实测示例，
**而非基准**：收益随任务复杂度以及你共同创作该产物的程度而放大，而一个隔离的审阅者也会加入你需要
分诊的误报 (false positive)。在某个具体任务上净收益是否值得，是一个经验性的、因用途而异的问题。

当额外审阅者是外部 CLI 时，Claude 侧的 token 成本不会增加 —— 它记在各自的额度里。

---

## 研究 (Research)

> **FH 论文** —— 下述方法论是有文献记录的，不只是断言：
> - **v1.0 —— 方法论** · [Zenodo](https://zenodo.org/records/20397566)（DOI 10.5281/zenodo.20397566）。两层设计、6 轴框架、4-agent 编排，以及复利循环，均附实证证据。
> - **cs.SE companion —— 治理门禁方法论** · **已发表** [Zenodo](https://zenodo.org/records/20680081)（DOI 10.5281/zenodo.20680081 · 最新 v1.1 10.5281/zenodo.20740038 · CC-BY-4.0）· arXiv 已提交（cs.SE，审核中）。
> - **cs.AI companion —— "Governance Dividend"** · 筹备中。

外部收敛：
- ["Dive into Claude Code: The Design Space of Today's and Future AI Agent Systems"](https://arxiv.org/abs/2604.14228) —— arXiv 2026 年 4 月
- ["Code as Agent Harness"](https://arxiv.org/abs/2605.18747) —— arXiv 2026 年 5 月
- Stanford IRIS Lab：["Meta-Harness"](https://arxiv.org/abs/2603.28052) —— 以 4 倍更少的 token 提升 +7.7pts

---

## 了解更多

| 资源 | 用途 |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | AI 运行规则 + 同步/推送协议 |
| [`CHEATSHEET.md`](CHEATSHEET.md) | 完整命令参考 |
| [`AGENTS.md`](AGENTS.md) | 运行时 agent 规格 |
| [`CATALOG.md`](CATALOG.md) | 过往工作检索索引 |
| [`CONTRIBUTING.md`](docs/CONTRIBUTING.md) | 如何贡献技能与模式 |
| [`tracks/_contrib/`](tracks/_contrib/README.md) | **同意通道** —— 分享一个去标识化的工作会话；仓库在众多操作者间复利累积，而不只在本地 |
| [`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md) | 治理门禁规格 |
</content>
</invoke>
