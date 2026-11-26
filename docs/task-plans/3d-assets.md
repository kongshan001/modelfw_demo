# 任务规划 · 3D 资产

## 进行中

## T-20261126-013 · Action Forge 深度复测：250+ 动画/分层/姿势/导出（T-009 follow-up）
- 来源: 飞书消息（B 站《终于有一款真正好用的免费3D动画工具了！》，https://b23.tv/X1qGE6U，2026-11-26，24:16，UP 海盗CG；ActionForge 250+ 动画、layering/posing/retargeting/export）
- 线程: T-20261126-009（Action Forge 实测）
- 父任务: T-20261126-009
- 类型: 3d-asset（动画工具深度实测）
- 目标: 在 T-009 基础上验证 250+ 动画库、分层/姿势、重定向与导出 Blender/Godot 的实际可用性；做一条分层合成（如走路 + 上半身姿势）的演示动画，给出是否替代 Mixamo 的结论
- 交付: 更新 `action-forge-test/`（导出 GLB、Godot 预览、Action Forge 录屏、截图、docs 追加）；媒体
- 约束: 只用 CC0/仓库样例；不登录/不绕过付费；真实可复现；不复制视频/软件素材
- 指派: game-engineer worker（dispatcher）
- 状态: queued

## T-20261126-009 · 实测 Action Forge（Mixamo 免费替代）动画效果
- 来源: 飞书消息（B 站《这款免费软件，可能要让Mixamo失业了》，https://b23.tv/6hQ7yHY，2026-11-26，16:29，UP 海盗CG；介绍 Action Forge https://actionforge.app/）
- 类型: 3d-asset（动画工具实测 / 重定向）
- 目标: 实测 Action Forge 的动画编辑/重定向效果：本地 CC0 角色 + 现有 Mixamo 样例动画，走通导入→调整→导出 GLB→Godot 预览；与 Mixamo 做同条件对比，给出可用性/质量/限制结论
- 交付: `action-forge-test/`（脚本、导出 GLB、Action Forge 录屏、Godot 预览工程、截图/GIF/MP4）+ 项目 docs（结论先行、步骤、参数、许可/账号限制、对比表）；媒体
- 约束: 只用原创/CC0 资产（KayKit/Mixamo 样例）；不把敏感/私有数据上传；遵守 Action Forge 条款，不绕过登录/付费；若需登录则记录阻塞并给可验证的替代；Godot 4.6 GL Compatibility，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-009/result.md
  - 关键数字: Rogue 41 骨/12 mesh/5901 verts；动画 `Michelle Walk_fit` 1.0333s；in-place root XZ 0 / root-motion 0.0197m；Blender 骨长偏差 1e-06；Godot 720p 平均 52.4 FPS（Intel HD 6000）；headless 600 帧 0 ERROR；smoke `SMOKE_OK`
  - 结论: 可完成重定向/编辑/GLB 导出，免登录免上传；自动映射 KayKit Rogue 仅 17 骨且行走屈膝/前倾，需手工修正；Speed 1.5× 不烘焙；仅动画 GLB 的 Godot 骨名坑；不替代 Mixamo 的自动绑定/库质量
  - 媒体: `recordings/af_operation.mp4`（14s）、`recordings/godot_preview.mp4`（12s）、`screenshots/godot_clean_pair.png`、`godot_clean_bones.png`、`rogue_retarget_ui.png`
- 后续: T-20261126-013 深度复测 250+ 动画/分层/姿势/导出（依赖 T-009 完成）

## T-20261125-011 · 原创角色眨眼动画能力测试（Blender 形态键）
- 来源: 飞书消息（2026-11-25，“一般模型做眨眼动画需要注意什么”→“可以试试”）
- 类型: 3d-asset（面部动画 / 形态键）
- 目标: 在原创 qinghe/taoyao 模型上实际做眨眼：眼睑形态键、随机节奏/双眨/左右错帧、GLB morph 导出、渲染验收；验证我们是否具备该能力
- 交付: Blender 脚本 + 更新模型/GLB；face close-up GIF/MP4 + 关键帧；docs/BLINK.md（眼睑路径/节奏/坑/导出）；README；媒体
- 约束: 仅用原创模型，不复制 IP/参考素材；Blender 3.4.1；眼睑不得穿模、高光稳定；形态键导出 glTF/Godot 可用；不改其他项目
- 指派: game-artist worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261125-011/result.md
  - 资产: `agent-probes/blink-test/qinghe_blink.blend`（4.45 MB）/ `qinghe_blink.glb`（7.33 MB，6 morph targets + 7 s clip）/ 6 张 1024² 关键帧 / `blink_face_loop.mp4`（512² 24fps 7.0s）/ `blink_face_loop.gif` / `target_size_blink.gif` / 节奏图 / 对照图
  - 工具: `tools/blender_blink/`（build / render / make_media / inspect_glb / reimport_check / validate / blink_schedule）
  - 文档: `docs/BLINK.md`（结构/眼睑路径/形态键/节奏/坑/导出/验证/复用清单）；`agent-probes/blink-test/README.md`；qinghe README、探针报告已补链接
  - 验证: 27/27 自动检查通过（`blink_validation.json`）；Godot 4.6 导入 6 blend shapes + 6 条轨道；Blender 回导帧 1→17 位移 73.9 mm
  - 关键数字: 上/下睑 81.98% / 18.02%；投影 Half 混合态最小离面 9.43 mm > 高光 8.2 mm；Open 保真 1.42/255；180 px 眼部 ROI 40.2% 像素变化 >30/255
  - 备注: 原始 qinghe 无眼睑骨/decal 眼；taoyao 同构未重复搭建；Godot 仅 headless 导入，未做 GPU 回放（handoff 给 engineer/QA）

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
