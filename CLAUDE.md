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
   （id/title/category/agent/prompt/plan_file/cwd/model/notify），
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
