# 任务规划 · 文档 / 调研

## 进行中

## T-20261120-001 · 拆解 Unity 仿绝区零 Demo
- 来源: 飞书消息（B 站 BV1FVsp6FELe，2026-11-20）
- 类型: docs-research
- 目标: 拆解「Unity | 2027届-仿绝区零Demo」的战斗、动画、渲染、UI 与制作范围，输出可复刻方案
- 交付: `docs/zzz-unity-demo-teardown.md` + 交互 HTML（复用现有设计系统）+ 截图；来源/时间点
- 约束: 只研究，不在本机安装 Unity；不复制视频/游戏素材；引用创作者/仓库；图表原创
- 指派: detached general worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261120-001/result.md

## 队列

（空）

## 已完成

## T-20261119-004 · 拆解 Windows 双击安装 APK 的开源项目
- 来源: 飞书消息（B 站 BV1XcsK6AEFs，2026-11-19）
- 类型: docs-research
- 目标: 识别视频中的 GitHub 开源项目，拆解它让 Windows 双击 APK 安装的原理、依赖、兼容性、安全风险与可复现步骤
- 交付: `docs/apk-on-windows-teardown.md` + 交互 HTML（复用现有设计系统）；来源/时间点；HTML 截图
- 约束: 只做研究，不在本机安装 Windows 工具；引用原始仓库/文档；不复制视频画面/素材；不确定处明确标注
- 指派: detached general worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261119-004/result.md

## T-20261119-001 · 拆解 Rogue 程序化关卡生成算法
- 来源: 飞书消息（B 站 BV14Un16fEvz，2026-11-19）
- 类型: docs-research
- 目标: 拆解视频中的程序化关卡生成算法，输出技术讲义 md + 交互 HTML，并给出可在代码/Godot 中复刻的最小算法清单或示例
- 交付: `docs/procedural-generation-teardown.md`、`docs/procedural-generation-teardown-交互版.html`；可选最小算法 demo；结构校验/截图
- 约束: 只研究算法与设计思路；图表/文字原创，不复制视频画面/素材；需标注视频时间点与来源
- 指派: general-purpose
- 状态: done
- 产出: 上述 md/html；`docs/procedural-generation-demos/{generators.py,verify.py}`（ALL_GENERATORS_OK、21 seeds 连通）；`docs/shots/procedural-generation*.png`
