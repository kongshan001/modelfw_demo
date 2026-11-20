# 项目工作规则

## 飞书消息默认任务路由（长期规则）

通过飞书 / cc-connect 进来的**实质消息**，主 Agent 默认只做**路由器**，不直接实现需求
（本条只约束飞书入口的主 Agent；被派发的 subagent 就是该任务的实现者）：

1. **解析**：提取目标、约束、交付物、链接、相关文件。
2. **分类**：按任务类型选择任务规划文件（见下表）。
3. **建单**：在对应 `docs/task-plans/*.md` 追加任务记录；同步用 `TaskCreate` 建任务。
   - 同类新任务 → 追加到同一规划文件；
   - 已有任务的 follow-up / 修正 → 续到原任务，不重复建单。
4. **异步派发（关键）**：每个任务写成一个 JSON
   （id/title/category/agent/prompt/plan_file/cwd/model/notify/**commit_paths**），
   调用 `python3 tools/task_dispatcher.py enqueue --file <task.json>`。
   调度器会启动一个**独立的 `claude -p --agent <agent>` worker 进程**（独立上下文，
   等价于该任务的 subagent），**主 Agent 不等待**。
   一个任务一个 worker；默认最多 3 个并行（`CC_TASK_WORKERS`），其余排队。
5. **秒回**：路由 turn 只做「解析 → 建单 → 入队 → 回执」，必须快速结束。
   **严禁**在 turn 内同步调用 `Agent` 等待任务完成；cc-connect 是单会话串行桥，
   长 turn 会把后续飞书消息排队（日志已见 `message queued for busy session`）。
6. **结果**：worker 完成后由调度器通过 `cc-connect send` 直接发飞书，并更新计划文件状态；
   主 Agent 下次收到消息时只做状态查询/验收核对，不再重复汇总。
   **视觉类任务（游戏/3D/模型/界面/特效）必须附效果图、GIF 或视频**：
   worker 完成时用 `cc-connect send --image/--video <绝对路径>` 发 1–3 个代表性附件，
   再让 runner 发文本摘要；纯代码/调研任务如果生成了截图也应发送。
   **自动提交/推送**：`tools/git_publisher.py` 会按 task JSON 的 `commit_paths`
   把产出提交并 push 到 `origin` 当前分支（只 add 声明路径，不 force，不动无关工作区）。
   `commit_paths` 至少包含项目目录/文档 + 对应 `docs/task-plans/*.md`。
7. **不越界**：主 Agent 可以分类、写规划、做验收核对，但**不直接写代码/做美术/跑长任务**。
8. **例外**：纯确认、感谢、状态查询等无实质工作的消息 → 简短回复，不派 worker；
   维护路由机制本身可直接处理。

### 调度器命令

```bash
python3 tools/task_dispatcher.py enqueue --file /tmp/task.json
python3 tools/task_dispatcher.py list
python3 tools/task_dispatcher.py status <id>
```

- 队列/结果：`~/.cc-connect/tasks/{pending,running,done,failed}`；
- worker 日志：对应任务目录 `worker.log`；
- 主会话不再因为单个长任务阻塞；多条飞书消息可以连续入队、并行执行。
- cc-connect 只负责桥接与 `cc-connect send`；真正的并行执行者是 Claude Code 的 headless worker。
- Git 发布：`python3 tools/git_publisher.py status` / `publish-all`；daemon 由 enqueue 自动拉起。
  远端：`origin`（https://github.com/kongshan001/modelfw_demo.git），当前分支 `feat/ai-slice`。

### 视觉/游戏任务的角色分工（必须）

一个大功能不能由一个 agent 同时做美术、程序、QA。默认拆成独立角色任务：

| 角色 | agent | 职责 | 不做 |
| --- | --- | --- | --- |
| 美术总监 | `game-art-director` | brief、严格评审、独立复评、P0–P2 + 参数 | 不改代码/资产 |
| 美术实现 | `game-artist` | 色板/线/材质/角色/UI/VFX/展示物料；视觉代码/资产 | 不做玩法/QA/独立评审 |
| 程序 | `game-engineer` | 玩法/系统/渲染管线/性能/AA/导入/工具 | 不做美术方向/独立评审 |
| QA | `game-qa-lead` | 独立验收、回归、证据、放行/打回 | 不改美术方向/实现 |
| 策划 | `game-designer` | 机制/体验/规格（需要时） | 不做实现/美术评审 |

- 一个任务一个角色；主 Agent 只编排，不兼做。
- 默认顺序：**Game Designer 设计方案** → Art Director brief（若无）→ **Game Artist** → **Game Engineer**（技术/性能/AA）→ **QA Lead** → **Art Director 独立复评**。
- 策划负责“做什么、给谁玩、核心循环、MVP/优先级、验收口径”，不写代码、不画资产、不做 QA/独立评审。
- 同一项目并行时先声明文件所有权；视觉文件归 artist，玩法/性能文件归 engineer。
- **禁止**让 game-engineer 兼做美术整改，或让 game-art-director 做实现；也不要把 QA 塞给实现者。

### 分类与默认 subagent

| 类型 | 规划文件 | 默认 subagent |
| --- | --- | --- |
| 游戏原型 / Godot / Three.js Demo | `docs/task-plans/game-demos.md` | `game-engineer` |
| 3D 建模 / 骨骼 / 蒙皮 / 动画 / 渲染 | `docs/task-plans/3d-assets.md` | `game-engineer` |
| 技术文档 / 视频拆解 / 交互 HTML / 调研 | `docs/task-plans/research-docs.md` | `general-purpose` |
| 环境 / 安装 / MCP / 部署 / 工具链 | `docs/task-plans/infra.md` | `general-purpose` |
| 不确定 / 需要澄清 | `docs/task-plans/inbox.md` | `general-purpose` + 一条纯文本澄清 |

### 任务记录格式

```markdown
## T-YYYYMMDD-NNN · 标题
- 来源: 飞书消息 / 链接 / 时间
- 类型: game-demo | 3d-asset | docs-research | infra | inbox
- 目标: 一句话
- 交付: 文件/命令/验收物
- 约束: 版权、原创素材、引擎、验收方式
- 指派: subagent 名称
- 状态: queued | running | done | blocked
- 产出: 文件路径 / 验证结果
```

详细协议、subagent prompt 模板与 follow-up 规则见 `docs/task-routing.md`。
