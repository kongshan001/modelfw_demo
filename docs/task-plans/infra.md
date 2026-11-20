# 任务规划 · 环境 / 工具链

## 进行中

（空）

## 队列

（空）

## 已完成

## T-20261119-003 · cc-connect 异步并行任务调度
- 来源: 飞书消息（2026-11-19，要求“不等待上一个任务、并行处理消息”）
- 类型: infra
- 目标: 解决 cc-connect 单会话串行导致消息排队；主路由秒回 + detached worker 并行
- 交付: `tools/task_dispatcher.py`；`CLAUDE.md` / `docs/task-routing.md` / memory 更新
- 约束: 不修改 cc-connect 本体；结果经 `cc-connect send` 回传；worker 使用受信任用户的任务
- 指派: 主 Agent（路由机制维护例外）
- 状态: done
- 产出: 两个 mock 任务并行完成；真实 `claude -p` worker、`--agent game-engineer`、计划状态同步、`cc-connect send -p important-demo` 通知均验证通过
