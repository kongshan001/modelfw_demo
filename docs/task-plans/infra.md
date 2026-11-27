# 任务规划 · 环境 / 工具链

## 进行中

## T-20261127-006 · 实测腾讯 TencentDB Agent Memory（跨会话长期记忆）
- 来源: 飞书消息（B 站《给 AI 装上长期记忆，腾讯这个框架开源了》，https://b23.tv/mIvaqZU，2026-11-27，37s，UP 你也太不小心了_；简介：腾讯云数据库团队开源 Agent Memory 框架，让 AI 记住跨会话上下文）
- 类型: infra（AI 框架实测 / 长期记忆）
- 目标: 核实并本地试跑 `TencentCloud/TencentDB-Agent-Memory`：L0–L3 记忆层级、Chat Memory/Skill/LLM-Wiki/Code-Graph、Memory Hub、跨会话召回与 Token 节省；给出安装/许可/依赖/可用性结论
- 交付: `agent-memory-test/`（隔离安装/复现脚本、两会话演示、日志/截图、docs 报告）；如有 UI 发截图
- 约束: 不申请/不写死腾讯云付费资源或凭证；密钥只走 env/本地，不入库；官方 vs 社区本地 fork 明确标注；不改现有 memory/路由；真实可复现，失败给阻塞报告
- 指派: general-purpose worker（dispatcher）
- 状态: done

## T-20261126-003 · 新建 game_task 仓库归档游戏代码与资产
- 来源: 飞书消息（2026-11-26，“代码产物、游戏资产都要进 git repo，弄一个新 repo，例如叫 game_task”）
- 类型: infra（Git 归档 / 资产快照）
- 目标: 新建公开仓库 `kongshan001/game_task`，把 modelfw_demo 中已跟踪的游戏代码/资产/文档做一次快照归档，并生成 README/MANIFEST 与增量同步说明
- 交付: `https://github.com/kongshan001/game_task`；快照 commit；README、MANIFEST（任务→目录/commit）、.gitignore；文件数/大小/最大文件/密钥扫描报告
- 约束: 只导出 `git archive HEAD` 的已跟踪文件；不复制未跟踪/忽略内容（`tripo-out/`、`.tripo/`、`.godot/`、`*.blend1`、缓存）；排除 benchmark/harness/cpp/product-scout 等非游戏工程与 T-20261123-002 的第三方 IP；不改 modelfw_demo；公开（内容均已公开）
- 指派: general-purpose worker（dispatcher）
- 状态: done

## 队列

（空）

## 已完成

## T-20261121-044 · 商品截图比价 Web 应用（Product Scout）
- 来源: 飞书消息（2026-11-22，“上传商品截图，全网查同款/同型号最低价与好评差评，给购买渠道/链接/价格/评价摘要”）
- 类型: infra（Web 应用 / 信息聚合）
- 目标: 上传商品截图 → OCR/视觉提取品牌型号等 → 用户可编辑 → 多渠道公开价格/评分/评论摘要 → 购买决策表（渠道/链接/价格/口碑）
- 交付: `product-scout/` 可运行 Next.js 应用；Demo 模式 + 可插拔搜索/视觉 provider；单元/E2E 测试；截图/GIF/MP4；README/ARCHITECTURE；媒体
- 约束: 不绕过反爬/ToS；只用官方或公开搜索 API/链接；不伪造“全网最低”；不持久化用户截图；密钥只走 env；中文 UI；响应式；Demo 数据必须明确标注
- 指派: general-purpose worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-044/result.md

## T-20261119-003 · cc-connect 异步并行任务调度
- 来源: 飞书消息（2026-11-19，要求“不等待上一个任务、并行处理消息”）
- 类型: infra
- 目标: 解决 cc-connect 单会话串行导致消息排队；主路由秒回 + detached worker 并行
- 交付: `tools/task_dispatcher.py`；`CLAUDE.md` / `docs/task-routing.md` / memory 更新
- 约束: 不修改 cc-connect 本体；结果经 `cc-connect send` 回传；worker 使用受信任用户的任务
- 指派: 主 Agent（路由机制维护例外）
- 状态: done
- 产出: 两个 mock 任务并行完成；真实 `claude -p` worker、`--agent game-engineer`、计划状态同步、`cc-connect send -p important-demo` 通知均验证通过
