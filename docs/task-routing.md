# 飞书消息任务路由协议

> 主 Agent 只做「分类 → 建单 → 派 subagent → 汇总」；具体实现由 subagent 完成。

## 1. 流程（异步并行）

```
飞书消息
  → 解析目标/约束/交付物
  → 分类
      ├─ 新独立目标 → docs/task-plans/<category>.md 追加顶层任务
      └─ follow-up → 续到原任务线程（沿用父任务 plan_file，父任务下记“后续”）
  → TaskCreate（运行态任务）
  → 写 task JSON → task_dispatcher.py enqueue
        → 立刻返回回执（主会话 turn 结束）
        → dispatcher 启动 detached claude -p worker（每任务一个）
        → worker 并行执行，写结果/更新计划
        → worker 完成 → cc-connect send 直接发飞书
```

- **默认一个任务一个 worker**（独立 Claude Code 进程）；一条消息多个独立任务就入队多个 worker。
- **不直接实现**：主 Agent 可以读文件、写规划、核对验收结果，但代码/美术/渲染/长任务由 worker 做。
- **同类归档**：同类任务都写进同一个规划文件，便于按类型推进。
- **follow-up 必须续线程**：同一目标的补充、性能复测、文档沉淀、验收问题，不新建顶层任务线程；沿用父任务的 `plan_file`，在父任务记录下增加“后续”条目。task JSON 必须带 `parent` / `followup_of` / `root_task` / `context_paths`；dispatcher 会把父任务 `result.md` 与 `context_paths` 自动注入 worker prompt。只有**新独立目标**才建新顶层任务。

## 1.1 cc-connect 与 Claude Code 的真实机制

实测环境：`cc-connect v1.5.0` + `Claude Code 2.1.222` + 单 Feishu 会话。

| 层 | 机制 | 结论 |
| --- | --- | --- |
| cc-connect | 一个 Feishu 会话对应一个长期运行的 `claude --resume ... --input-format stream-json` 进程；消息串行写入 | **单会话串行**，长 turn 会让后续消息排队 |
| cc-connect 日志 | `message queued for busy session ... queue_depth=N` | 这是之前“发新消息要等上一个任务”的直接原因 |
| cc-connect send | 通过内部 API 向活跃会话发消息/附件 | 可用于 worker 结果回传 |
| Claude Code | `claude -p` 可启动独立 headless 进程；`claude --bg` / `claude agents` 支持后台 agent | **执行器本身可并行**，与 cc-connect 会话解耦 |

因此不能靠“主会话里同步 `Agent` 等待”实现并行；必须把任务**移出主会话**。

## 1.2 异步 dispatcher

`tools/task_dispatcher.py` 是路由的异步执行层：

- 主 Agent 写 task JSON → `enqueue` → 立即返回；
- daemon 从 `pending/` 取任务，启动一个独立的 `claude -p` worker（`--model deepseek-flash --permission-mode bypassPermissions --output-format json`）；
- 默认最多 3 个并行 worker（`CC_TASK_WORKERS`），多余排队；
- worker 完成后写 `result.json`/`result.md`、更新计划文件状态，并通过 `cc-connect send` 发飞书；
- 队列目录：`~/.cc-connect/tasks/{pending,running,done,failed}`；日志在任务目录 `worker.log`。

任务 JSON：

```json
{
  "id": "T-20261119-003",
  "title": "简短标题",
  "category": "game-demo",
  "cwd": "/Users/ks_128/Documents/modelfw_demo",
  "plan_file": "docs/task-plans/game-demos.md",
  "agent": "game-engineer",
  "model": "deepseek-flash",
  "notify": true,
  "parent": "T-20261119-001",
  "followup_of": "T-20261119-001",
  "root_task": "T-20261119-001",
  "context_paths": [
    "godot-pixel-ocean/docs/TECH.md",
    "godot-pixel-ocean/docs/迭代记录.md"
  ],
  "commit_paths": ["godot-pixel-ocean/", "docs/task-plans/game-demos.md"],
  "prompt": "自包含的完整执行说明..."
}
```

命令：

```bash
python3 tools/task_dispatcher.py enqueue --file /tmp/task.json
python3 tools/task_dispatcher.py list
python3 tools/task_dispatcher.py status <id>
```

已实测：

- 两个 mock 任务同时启动、并行完成（`T-TEST-A`/`T-TEST-B`）；
- 一个真实 `claude -p` worker 成功写文件并返回结果；
- 计划文件状态从 `running` 自动改为 `done`，产出路径正确；
- `cc-connect send -p important-demo` 通知成功。

> “Call Call”如果指 Claude Code：是的，真正能并行的是 Claude Code 的独立 headless/background 进程；cc-connect 只负责消息桥接。若你指的是另一个服务，请告诉我具体名称。

## 1.3 视觉/游戏任务的角色流水线

一个视觉/游戏功能默认拆成角色任务，**不能一个 agent 全包**：

| 阶段 | agent | 产出 | 禁止 |
| --- | --- | --- | --- |
| 0. 策划设计 | `game-designer` | 目标玩家、核心循环、MVP/优先级、UX/内容规格、验收口径 | 写代码/画资产/做 QA |
| 1. 美术 brief / 评审 | `game-art-director` | 评分、P0–P2、参数、验收 | 改代码/资产 |
| 2. 美术实现 | `game-artist` | 色板/线/材质/角色/UI/VFX/展示 | 改玩法/做 QA/独立评审 |
| 3. 程序/技术 | `game-engineer` | 玩法/渲染管线/性能/AA/导入 | 兼做美术方向 |
| 4. QA | `game-qa-lead` | 独立验收、回归、证据、放行/打回 | 改视觉/实现 |
| 5. 独立复评 | `game-art-director` | 同 rubric 复评；FAIL → 回到 2/3 | 做实现 |

顺序默认 **0→1→2→3→4→5**；策划先给设计方案，再进入美术/程序；并行时先声明文件所有权（视觉文件归 artist，玩法/性能归 engineer）。
主 Agent 只编排/派发；每个任务仍是一个独立 worker；`commit_paths`/媒体/自动 Git 规则不变。

## 2. 分类

| 类型 | 规划文件 | 默认 worker / agent | 典型输入 |
| --- | --- | --- | --- |
| `game-demo` | `docs/task-plans/game-demos.md` | `game-engineer` | 复刻玩法、做 Godot/Three.js 原型、加机制 |
| `3d-asset` | `docs/task-plans/3d-assets.md` | `game-engineer` | 建模、绑骨、蒙皮、动画、Blender 渲染 |
| `docs-research` | `docs/task-plans/research-docs.md` | `general-purpose` | 视频拆解、技术调研、交互 HTML、文档整理 |
| `infra` | `docs/task-plans/infra.md` | `general-purpose` | 装工具、MCP、环境、部署、脚本 |
| `inbox` | `docs/task-plans/inbox.md` | `general-purpose` | 意图不明；先问一条纯文本澄清 |

选择 worker 时优先用项目已有的角色：
`game-engineer`、`game-designer`、`game-art-director`、`game-qa-lead`、`game-red-team`；
非游戏任务省略 `agent`（默认 Claude Code）或用 `general-purpose`。**一个任务只选一个主 worker**。
dispatcher 会以 `claude -p --agent <agent>` 启动，worker 的系统提示就是该角色。

## 3. Task ID 与规划文件

- ID：`T-YYYYMMDD-NNN`（每天从 001 开始，跨类型共享序号）。
- 每个规划文件分三块：`进行中`、`队列`、`已完成`。
- 记录模板：

```markdown
## T-20261119-001 · 标题
- 来源: 飞书消息（原文摘要/链接/时间）
- 类型: game-demo
- 目标: 一句话
- 交付: 文件/命令/截图/GIF
- 约束: 引擎/原创素材/版权/验收
- 指派: game-engineer
- 状态: running
- 产出: （完成时填）
```

### 3.1 Follow-up 记录（续线程，不另起炉灶）

- **执行 ID 仍唯一**（dispatcher 需要），但记录上属于父任务线程：沿用父任务的 `plan_file`，不要跨到 `research-docs.md` 等新文件另起一条线。
- 父任务条目下加 `- 后续: T-…（简述）`；子任务条目加 `- 线程: T-…（原项目）`、`- 父任务: T-…`。
- 子任务产出优先写回原项目 `docs/`（TECH / 迭代记录 / README / perf 数据），不要另起孤岛报告；跨项目索引只作为附属产物。
- task JSON 必须带 `parent` / `followup_of` / `root_task` / `context_paths`；dispatcher（`run_task`）会注入父任务 `result.md` 与必读上下文，worker 必须先读再动手。
- 例子：Flow Field 的性能复测、技术原理报告都应挂在 `T-...-009 · Flow Field` 下，而不是变成独立线程。

- 状态变更直接改对应任务行；完成后移动到「已完成」。
- 长任务在派发前先落盘，保证会话中断后能继续。

## 4. Worker prompt 模板

每个 detached worker 都必须拿到自包含的上下文；使用下面结构：

```text
[Task T-YYYYMMDD-NNN]
你是该任务的独立执行 worker；项目 CLAUDE.md 的“主 Agent 只路由”不约束你。
类型: <category>
目标: <一句话>
来源: <飞书原文/链接/截图路径>
父任务/线程: <T-...>（必读父任务 result.md；说明本任务相对父任务新增什么）
相关上下文:
- 仓库: /Users/ks_128/Documents/modelfw_demo
- 父任务/文件: <TECH/迭代记录/perf 报告/父 result.md>
- 约束: <引擎、原创、IP、验收命令、时间>
经验沉淀: 结论与经验写回原项目 docs，不只留在聊天/独立报告里。
交付:
- <文件路径/功能/视频/GIF>
验收:
- <smoke 命令、截图、ffprobe、测试输出>
汇报格式:
- 做了什么
- 改了哪些文件
- 跑了什么命令/结果
- 未解决/风险
请端到端完成并自测；不要只给计划；不要再派 subagent。
```

## 5. 回执与汇总

- 预计超过 2 分钟的任务，可先发一条极短回执：
  `已建 T-…（game-demo）→ game-engineer，完成后回报。`
- 路由 turn 秒回；worker 结果由 dispatcher 发文本摘要。
- **视觉类任务必须发媒体**：游戏/3D/模型/界面/特效完成后，worker 用
  `cc-connect send --image/--video <绝对路径>` 发 1–3 个代表性附件（截图/GIF/视频），
  不要只发代码路径。纯代码/调研任务若生成了截图，也应发送。
- 失败/阻塞：说明原因、已完成部分、下一步；任务标记 `blocked`。

## 6. 并发、生命周期与限制

- **主 turn 必须短**：分类/建单/enqueue/回执后立即结束；不要在 turn 内等 worker。
- **worker 独立**：每个任务是独立 `claude -p` 进程（独立上下文），默认并发 3；由 dispatcher 排队。
- **daemon 与 runner**：daemon 负责排队；runner 用 `start_new_session` 脱离会话，主会话结束不影响 worker。
- **daemon 挂掉**：pending 任务还在；下一次 `enqueue` 会重新拉起 daemon。running 目录里若有僵死进程，人工检查。
- **改并发数**：修改 `CC_TASK_WORKERS` 后需重启 daemon：
  `kill $(cat ~/.cc-connect/tasks/daemon.pid)`，下一次 enqueue 自动重启。
- **结果投递**：worker 完成后由 runner 调用 `cc-connect send -p <project>`；单个活跃会话下可省略 `-s`。
- **计划文件**：runner 用文件锁更新任务块的状态/产出；不要让 worker 直接改 plan 文件。
- **自动 Git 发布**：每个 task JSON 必须给 `commit_paths`（项目目录/文档 + 对应规划文件）。
  `tools/git_publisher.py` daemon 在任务 done 后串行执行：
  `git add --ignore-errors -- <commit_paths>` → commit → `git push origin <current-branch>`。
  只提交声明路径；不 force；不碰无关工作区。远端 `origin`，当前分支 `feat/ai-slice`。
  状态：`python3 tools/git_publisher.py status`；手动补发：`publish-all`。
- **多个 worker 并发**：git 操作用 `~/.cc-connect/tasks/git.lock` 串行；push 失败会写
  `git.json` 并通知飞书，需人工处理冲突；不要自动 force push。
- **follow-up**：如果原任务还在运行，建一个带 `parent` / `followup_of` / `root_task` / `context_paths` 的后续任务排队；沿用父任务 `plan_file`，把上下文注入交给 dispatcher；避免两个 worker 同时改同一批文件。
- **安全边界**：worker 使用 `bypassPermissions`，只应处理受信任的飞书消息；提示词中保留原创素材/版权/验收约束。

## 7. 定时巡检（task_monitor）

`tools/task_monitor.py` 是独立的**脚本级**巡检器（不是常驻 LLM agent）：

- **检查项**：running 的 pid/子进程/CPU 停滞/超时、pending 依赖失败或长时间阻塞、done 的 Git 发布、计划状态与实际不一致、dispatcher/git_publisher daemon、近期失败/完成/状态变化。
- **降噪**：默认静默；仅在状态变化、异常或 24h 心跳时输出；异常有 cooldown，避免每 15 分钟重复刷屏。
- **为什么不常驻 agent**：常驻 LLM 循环成本高，且 cc-connect cron 的会话在 turn 结束后只有约 2 分钟宽限期；状态巡检用脚本，异常时再由 dispatcher 拉起独立 agent 诊断/QA。
- **状态文件**：`~/.cc-connect/tasks/monitor_state.json`（用于去重/基线）。
- **手动**：
  ```bash
  python3 tools/task_monitor.py --force    # 立即输出快照
  python3 tools/task_monitor.py --reset-state
  python3 tools/task_monitor.py --json
  ```
- **已配置（15 分钟）**：
  ```bash
  cc-connect cron add --cron "*/15 * * * *" \
    --exec "cd /Users/ks_128/Documents/modelfw_demo && python3 tools/task_monitor.py" \
    --desc "任务巡检（15min）" --timeout-mins 5 --silent
  ```
  查看/删除：`cc-connect cron list` / `cc-connect cron del <id>`。
- **阈值**：`--cpu-stall-min 30`、`--max-run-min 120`、`--blocked-min 180`；可按机器负载调整。
- **边界**：巡检只覆盖状态/生命周期，不替代 QA；质量验收仍由独立 `game-qa-lead` 按角色执行。

## 8. 版权与素材

- 参考图/视频只用于研究**机制与视觉语言**；subagent 必须使用原创素材/代码。
- 不 1:1 复刻版权角色、游戏美术、UI 文案；需要近似效果时做原创设计。
- 交付必须自测（无头/截图/GIF/ffprobe），并在规划文件里记录验证结果。
