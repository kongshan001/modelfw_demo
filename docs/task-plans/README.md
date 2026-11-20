# 任务规划

飞书消息经路由器分类后，落到对应规划文件；**一个任务默认一个 detached worker**
（`tools/task_dispatcher.py` 启动独立 `claude -p` 进程，主会话秒回，多任务并行）。

| 文件 | 类型 | 默认 subagent |
| --- | --- | --- |
| [game-demos.md](game-demos.md) | 游戏原型 / Godot / Three.js | game-engineer |
| [3d-assets.md](3d-assets.md) | 3D 建模 / 骨骼 / 蒙皮 / 动画 | game-engineer |
| [research-docs.md](research-docs.md) | 文档 / 视频拆解 / 调研 / HTML | general-purpose |
| [infra.md](infra.md) | 环境 / 安装 / MCP / 部署 | general-purpose |
| [inbox.md](inbox.md) | 未分类 / 待澄清 | general-purpose |

## 任务记录模板

```markdown
## T-YYYYMMDD-NNN · 标题
- 来源: 飞书消息 / 链接 / 时间
- 类型: game-demo | 3d-asset | docs-research | infra | inbox
- 目标:
- 交付:
- 约束:
- 指派:
- 状态: queued | running | done | blocked
- 产出:
```

协议细节见 [../task-routing.md](../task-routing.md)。
