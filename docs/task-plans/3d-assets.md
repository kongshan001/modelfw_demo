# 任务规划 · 3D 资产

## 进行中

## T-20261123-001 · 3D 角色动画方案对比（Mixamo vs 商业/开源/AI 动捕）
- 来源: 飞书消息（2026-11-23，“模型动画想更丰富，知道 Mixamo，但不确定是否有更好的方案”）
- 类型: 3d-asset（动画管线调研）
- 目标: 对比 2026 年可用的角色绑定与动画方案，给 Tripo 模型（尤其二次元）一条可落地的“更丰富动画”管线与决策矩阵
- 交付: `docs/3d-animation-solutions.md`（Mixamo/AccuRIG+ActorCore/Cascadeur/视频动捕/VRM+MMD/Blender Rigify/AI 等；许可/价格/质量/限制/导出/学习成本 + 推荐流程 + 测试计划）+ 截图；媒体
- 约束: 只调研/验证，不安装付费软件/不替用户登录；不复制 IP 素材；区分官方/社区/实测；优先能接 Blender/Godot 的方案
- 指派: general-purpose worker（dispatcher）
- 状态: failed

## T-20261121-045 · Tripo 高质量图生 3D 工作流调研 + 鬼灭主角私有测试
- 来源: 飞书消息（2026-11-23，“搜一张鬼灭主角图，让 Tripo 生成模型；调研外部如何用 Tripo 做高质量模型”）
- 类型: 3d-asset（Tripo 工作流 / 私有技术测试）
- 目标: 调研 Tripo 高质量图生 3D 的外部最佳实践；用一张公开鬼灭主角参考图做私有测试，评估 Tripo P2/高质量参数的实际效果与差距
- 交付: `docs/tripo-high-quality-workflow.md`（外部方法/来源/参数/预处/后处/评估/成本）+ 本地 `/tmp/tripo-demon-slayer/` 测试（GLB/渲染，**不入库**）+ 2–3 张渲染；媒体
- 约束: 仅私人技术评估，不把鬼灭参考图/衍生模型提交仓库、不商用、不再分发；预算 ≤250 credits；记录实际 credits；不伪造质量；后续要入库/展示必须换原创角色
- 指派: game-artist worker（dispatcher）
- 状态: done（worker API 中断，产物人工恢复；dispatcher 记录为 failed）
- 产出: `docs/tripo-high-quality-workflow.md`；P2/H3.1 私有测试在 `/tmp/tripo-demon-slayer/`（鬼灭 IP，不入库）；原创样片 `agent-probes/tripo-qinghe/`；`tools/tripo/`
- 备注: 实际消耗 185 credits（P2 125 + H3.1 60），余额 300；鬼灭参考图/衍生 GLB/渲染未提交仓库

## T-20261119-008 · 齐天大圣 · 极意（游戏级可玩版）
- 来源: 飞书消息（2026-11-19；接受原创方向，要求精美、游戏可用、可外放体验）
- 父任务: T-20261119-006（首版金发猴王）
- 类型: 3d-asset
- 目标: 原创「齐天大圣·极意」银发形态，达到游戏级质量；Blender 模型/骨骼/蒙皮/动画 + Godot 4.6 可玩展示，不 1:1 复刻版权角色
- 交付: Blender 源文件 + `.glb`（skin/animations）；`godot-wukong-ultimate/` 可玩展示（相机/移动/蓄力/气功波/靶子/HUD/VFX）；before/after 截图 + GIF/MP4；README/TECH/迭代记录/CREDITS；smoke/性能/导入验证
- 约束: 原创角色；银发/银白斗气/肌肉/破损橙裤/蓝腰带/猴尾；不复制悟空脸/服装/品牌；1280×720 GL Compatibility，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261119-008/result.md

## 队列

（空）

## 已完成

## T-20261119-006 · 齐天大圣 · 斗战形态（首版）
- 来源: 飞书需求（2026-11-19，超级赛亚人孙悟空）
- 类型: 3d-asset
- 目标: Blender 程序化建模 + 25 骨骼 + 显式蒙皮 + 气功波 8 秒动画
- 交付: `blender-wukong/wukong.blend`、`wukong.glb`、`docs/wukong_ki.mp4`、GIF、poster、rig.png、README/TECH/迭代记录/CREDITS
- 约束: 原创金发猴王；未复制具体版权角色
- 指派: game-engineer（历史任务，非 dispatcher）
- 状态: done
- 产出: 24 deform joints / 1 skin / 1 animation / 8s GLB；视频 960×540/24fps；截图与骨架图
