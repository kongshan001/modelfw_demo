# 任务规划 · 游戏 Demo

## 进行中

## T-20261121-014 · 复刻《幻唐志》手游道具背包界面（Godot UI）
- 来源: 飞书消息（2026-11-21，“帮我用godot来复刻幻唐志手游的道具背包界面”）
- 类型: game-demo（Godot UI / 界面复刻）
- 目标: 按参考截图的布局/信息层级/交互，用原创素材在 Godot 4.6 复刻可交互道具背包：左侧人物装备盘 + 属性/货币，右侧分类/分页物品网格 + 详情/使用/整理
- 交付: `godot-inventory-ui/` 可运行项目；30–40 件示例道具数据；中文 UI；交互（切页/选中/悬停/使用/整理/筛选/丢弃确认/键鼠）；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke `INVENTORY_UI_SMOKE_OK`
- 约束: 只参考布局/配色/交互，**不复制幻唐志截图/图标/Logo/UI 素材**；原创面板/图标/背景；不用游戏名做品牌；1280×720 逻辑 + 1920×1080 截图，GL Compatibility，Intel 30fps+
- 指派: game-artist worker（dispatcher）
- 状态: running
- 后续: T-20261121-015（1:1 复刻校正，等本任务完成后启动）

## T-20261121-015 · 背包界面 1:1 复刻校正（T-014 follow-up）
- 来源: 飞书消息（2026-11-21，“注意是尽量做到1比1复刻”）
- 线程: T-20261121-014（幻唐志背包界面）
- 父任务: T-20261121-014；依赖: T-20261121-014（done + Git 发布）
- 类型: game-demo（UI 保真度校正）
- 目标: 在 T-014 可交互版本上做 1:1 校正：量参考图归一化坐标/尺寸/色值，逐项对齐面板边界、左右分区、装备槽、页签、物品网格、属性/货币行与字号；交互/信息层级同步
- 交付: 更新 `godot-inventory-ui/`；`docs/fidelity-1to1.md`（参考 vs 实现测量表、误差、例外）；同尺寸对照图（参考图不入库）；新截图/GIF/MP4；smoke 通过
- 约束: 1:1 指布局/比例/配色/交互；**不复制参考截图/图标/Logo/受版权素材**，用原创重绘；不用幻唐志品牌；不改其他项目
- 指派: game-artist worker（dispatcher）
- 状态: blocked（等 T-014 done + Git 发布）
- depends_on: T-20261121-014
- 后续: T-20261121-017（开发文档 + 跨引擎资产包）

## T-20261121-017 · 背包界面开发文档 + 跨引擎资产包（T-015 follow-up）
- 线程: T-20261121-014（幻唐志背包界面）
- 父任务: T-20261121-015；依赖: T-20261121-015（done + Git 发布）
- 类型: docs-research
- 目标: 沉淀开发文档与技术原理；导出引擎无关的 UI 规格/资产清单，方便在 Unity/Unreal/Three.js 等引擎复刻
- 交付: `godot-inventory-ui/docs/DEVELOPMENT.md`（节点树/状态机/数据 schema/动效）、`CROSS_ENGINE.md`（四层拆分/映射表/移植契约/验收清单）、`PORTABLE_ASSETS.md`（九宫格/图标/色板/命名/许可）、`export/ui_layout.json`、`export/asset_manifest.json` + 截图
- 约束: 只读项目/资产，不改 UI 行为；原创素材；参考图不入库；不得复制幻唐志素材/Logo
- 指派: general-purpose worker（dispatcher）
- 状态: blocked（等 T-015 done + Git 发布）
- depends_on: T-20261121-015

## T-20261121-013 · 复刻 Duelyst 式卡牌战棋（CC0 资产）可玩 Vertical Slice
- 来源: 飞书消息（微信公众号文章《服务器关停两年后，公司把整个游戏的代码美术用CC0全送给人类》，https://mp.weixin.qq.com/s/XY3uZmsJEiZy3sZ4MS0YyA，2026-11-21）
- 类型: game-demo（卡牌 + 战棋）
- 目标: 复刻 Duelyst 的核心：9×5 棋盘上的卡牌+走位对战、双将军、法力/手牌/随从、移动/攻击/射程、简单 AI；使用 CC0 开源资产做可玩 vertical slice
- 交付: `godot-card-tactics/` Godot 4.6 可玩项目；CC0 资产子集 + LICENSE/SOURCE；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke `CARD_TACTICS_SMOKE_OK` + 真实 GPU 验证
- 约束: 资产来自 open-duelyst（CC0 1.0），保留许可与来源；**不使用 Duelyst 名称/Logo 作为游戏品牌**（商标不在 CC0 内），用原创标题/UI；不复制 Duelyst II/Steam 素材；原创 GDScript 实现；不改其他项目
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: `godot-card-tactics/`（9×5 棋盘、玩家 vs AI、16 卡池、20 张套牌、嘲讽/远程/疾行/登场治疗、胜负/重开、固定 seed 可复现）；CC0 资产子集 60 源文件/约 1.1MB（LICENSE/SOURCE/CREDITS）；`CARD_TACTICS_SMOKE_OK`（65 checks）；5 张 1920×1080 截图 + 10.43s MP4/GIF；Intel HD 6000 实测待机 avg 117.2 FPS / AI 行动 avg 100.0 FPS；README/TECH/迭代记录
- 后续: T-20261121-016（开发文档 + 跨引擎资产包）

## T-20261121-016 · Duelyst 复刻开发文档 + 跨引擎资产包（T-013 follow-up）
- 线程: T-20261121-013（Duelyst 式卡牌战棋）
- 父任务: T-20261121-013；依赖: T-20261121-013（done + Git 发布）
- 类型: docs-research
- 目标: 沉淀规则/状态机/AI/资产管线文档，导出引擎无关的资产 manifest 与图集切片工具，支持 Unity/Unreal/Three.js 复刻
- 交付: `godot-card-tactics/docs/DEVELOPMENT.md`、`CROSS_ENGINE.md`（四层拆分/映射表/移植契约/验收清单）、`PORTABLE_ASSETS.md`（图集 schema/帧名/锚点/许可）、`export/asset_manifest.json`、`export/slice_atlas.py` + 联系表截图
- 约束: 只读代码/资产，不改玩法；CC0 许可与来源保留；不复制 Duelyst 商标/版权外素材
- 指派: general-purpose worker（dispatcher）
- 状态: blocked（等 T-013 done + Git 发布）
- depends_on: T-20261121-013

## T-20261121-011 · Flow Field 审计级性能复测与优化消融（T-009 follow-up）
- 来源: 飞书消息（2026-11-21，“做好文档积累以及技术原理分析报告”，承接 T-009 性能讨论）
- 线程: T-20261121-009（Flow Field）
- 父任务: T-20261121-009（Flow Field 已发布；现有 19.7→31.5→47.0 为单次累计对比）
- 类型: game-demo（性能审计/工具）
- 目标: 补齐审计级数据：消融矩阵、5 轮采样、P50/P95/P99、worst/hitch、720p+1080p、引擎渲染计数；解释每项优化的独立贡献
- 交付: `godot-flowfield/tools/` 复测工具；`godot-flowfield/docs/perf/` 原始 CSV/JSON + REPORT.md + 对比图；smoke 无回归；媒体
- 约束: 不改主 demo 默认行为/视觉；只改 bench/工具；同 seed/地图；真实 GPU；报告写清方法与局限
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-011/result.md

## T-20261121-012 · Flow Field 技术原理报告 + 文档沉淀（T-009 follow-up）
- 来源: 飞书消息（2026-11-21，“做好文档积累以及技术原理分析报告”）
- 线程: T-20261121-009（Flow Field）
- 父任务: T-20261121-009；依赖: T-20261121-011（审计数据）
- 类型: docs-research
- 目标: Flow Field 深挖 + WFC/Steering/Flow Field 总览；用消融数据解释优化机制；经验写回原项目 docs；按四层拆分给出跨引擎映射与移植契约
- 交付: `godot-flowfield/docs/TECHNICAL_PRINCIPLES.md` + 单文件交互 HTML + 更新 `godot-flowfield/docs/TECH.md` §6 + `docs/algorithm-demos-index.md` + Godot/Unity/Unreal/Three.js 映射表/移植契约/验收清单 + 截图
- 约束: 只读代码/docs，不改游戏代码/资产；原创图表；来源与访问日期；区分公开事实/推断；结论先行；中文
- 指派: general-purpose worker（dispatcher）
- 状态: blocked（等 T-011 done + Git 发布）
- depends_on: T-20261121-011

## T-20261121-009 · 续跑 Flow Field 流场寻路 Demo（T-008 重试）
- 来源: 飞书反馈（2026-11-21，“相关 demo 工程注意提交 git repo”；T-008 worker API 中断，遗留未完成的 `godot-flowfield/`）
- 父任务: T-20261121-008（failed，API Error: Connection closed mid-response）
- 类型: game-demo（AI 寻路算法复刻 · 续跑）
- 目标: 在现有 `godot-flowfield/` 半成品上续跑，完成 Flow Field demo 全部交付与验证，并确保工程提交入库
- 交付: 可运行 `godot-flowfield/`；README/TECH/迭代记录/CREDITS；smoke `FLOWFIELD_SMOKE_OK`；1920×1080 截图 ≥4 + 10s GIF/MP4；200/500/1000 智能体 FPS
- 约束: 不复制视频素材；Godot 4.6 GL Compatibility；不穿墙、流场单调、同地图可重复；commit_paths 必须包含 `godot-flowfield/`，完成后确认已在 git 历史中
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 后续: T-20261121-011（性能审计复测）、T-20261121-012（技术原理报告 + 文档沉淀）

## T-20261121-008 · 复刻 Flow Field 流场寻路群体寻路 Demo
- 来源: 飞书消息（B 站 BV12bzZY2EfA《〈群体寻路与避障〉Flow Field 流场寻路算法如何实现群体寻路》，3:53，2026-11-21）
- 类型: game-demo（AI 寻路算法复刻）
- 目标: 按视频实际内容复刻 Flow Field：代价场 → 积分场（Dijkstra）→ 流场方向；群体沿流场移动 + 局部避让；动态障碍/多目标；代价/积分/流向可视化
- 交付: `godot-flowfield/` 可运行 Godot 4.6 demo（地图/目标/障碍编辑、智能体数量、三视图切换、FPS）；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创场景/UI/名字，不复制视频素材；Godot 4.6 GL Compatibility，1280×720，Intel 30fps+；不穿墙、流场单调、同地图可重复；独立项目避免与 T-006 文件冲突
- 指派: game-engineer worker（dispatcher）
- 状态: failed

## T-20261121-007 · 材质与特效专项整改（Game Artist）
- 来源: 飞书消息（2026-11-21，“那就补充下材质和特效”，承接 T-20261121-004 外部对标 G1/G5）
- 父任务: T-20261121-004（对标：材质 3.5 / VFX 3.7，差两档+）
- 类型: game-demo（美术实现：材质/光照/VFX）
- 目标: 按对标 brief 落地 G1 材质/色阶管线 + G5 舞台光照/VFX；本轮不做 G2 动作、G3/G4 UI 重构
- 交付: 更新 `godot-paper-doll/`；同机位 before/after（100%/25%/640×360 命中帧）+ 指标（L* 分箱、阴影色相、墨占比、舞台层数、斩击 ROI）+ GIF/MP4；README/TECH/迭代记录；媒体
- 约束: 只改视觉层/材质/光照/VFX；保留 17 槽/8 向/4 动作/16 预设；不降 AA/超采样；原创素材；FPS 不回退；外部参考图不入库
- 指派: game-artist worker（dispatcher）
- 状态: done

## T-20261121-006 · 复刻《群体寻路与避障》Steering Behavior 可交互 Demo
- 来源: 飞书消息（B 站 BV1yCqfYuEh1《〈群体寻路与避障〉Steering Behavior 转向行为如何实现避障智能体》，4:03，2026-11-21）
- 类型: game-demo（AI/转向行为复刻）
- 目标: 按视频实际内容复刻 Steering Behaviors 群体移动与避障：seek/flee/arrive/pursue/evade/wander + separation/alignment/cohesion + 障碍物躲避/路径跟随；力向量与感知可视化
- 交付: `godot-steering/` 可运行 Godot 4.6 demo（行为开关/权重、智能体数量、场景预设、力/射线/邻居可视化、FPS）；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创场景/UI/名字，不复制视频素材；Godot 4.6 GL Compatibility，1280×720，Intel 30fps+；不穿墙、无 NaN/爆炸；不改其他项目
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-006/result.md

## T-20261121-005 · 复刻《地图随机生成》波函数坍缩（WFC）可交互 Demo
- 来源: 飞书消息（B 站 BV1Br421M7Vm《〈地图随机生成〉波函数坍缩算法是如何实现的》，4:50，2026-11-21）
- 类型: game-demo（程序化生成/算法复刻）
- 目标: 按视频实际内容复刻 WFC 地图生成：叠加态/熵/坍缩/约束传播/回溯，逐步可视化 + 固定种子复现
- 交付: `godot-wfc/` 可运行 Godot 4.6 demo（控制面板/步进/速度/种子/尺寸/算法视图）；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创瓦片/UI/名字，不复制视频素材；Godot 4.6 GL Compatibility，1280×720，Intel 30fps+；确定性种子；不改其他项目
- 指派: game-engineer worker（dispatcher）
- 状态: done

## T-20261121-004 · 外部参考对标 · 美术质量差距量化（Art Director）
- 来源: 飞书消息（2026-11-21，“美术去外部拿参考图对比看一下，究竟我们的美术质量差异有多大”）
- 类型: game-demo（美术对标/评估）
- 目标: 以 `godot-paper-doll/` 当前 build 为基准，选 3–4 款同品类/同风格外部参考，同尺寸并排对比，量化各维度差距（0–10 分 + 档位），给出 P0–P2 整改 brief
- 交付: `docs/art-review/external-benchmark.md`（参考清单+URL、评分表、差距结论、Top gaps、下一轮 brief）；2–3 张并排对比拼图（本地 /tmp，不入库）；媒体发送
- 约束: 外部素材仅本地分析、不入库/不再分发，记录来源与版权；不改代码/资产；目标尺寸 + 25% 缩略双尺度评审；评分必须带证据与参数
- 指派: game-art-director worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-004/result.md

## T-20261121-001 · 纸娃娃走路脚姿/滑步修复（Game Artist）
- 来源: 飞书反馈（2026-11-21，“走路的脚的那个姿势特别奇怪”）
- 父任务: T-20261120-012（独立复评 REJECT，R2-P0-2 walk 45.26px）
- 类型: game-demo（动画/美术实现）
- 目标: 修复 walk 支撑脚滑步与脚踝/脚掌姿势；`qa_motion_probe` 8 向 ≤2px；侧向 walk 可见不滑；不改玩法/其他 P0
- 交付: 更新 `godot-paper-doll/`；侧向 walk 截图/GIF + 探针输出；README/TECH/迭代记录；媒体
- 约束: 只改动画/视觉相关代码；保留 17 槽/8 向/4 动作/16 预设；原创；不做 QA/独立复评
- 指派: game-artist worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-001/result.md

## T-20261121-002 · 走路脚姿 QA 复验（QA Lead）
- 父任务: T-20261121-001；依赖: T-20261121-001（done + Git 已发布）
- 类型: game-demo（QA）
- 目标: 独立复验 walk 8 向支撑脚 ≤2px、脚姿可读、无回归；不改代码
- 交付: `docs/qa-review/paperdoll-walk-qa.md` + `walk_contact_strip`/侧向 GIF；媒体
- 约束: 只写 QA 证据；失败打回
- 指派: game-qa-lead worker
- 状态: done
- depends_on: T-20261121-001
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-002/result.md

## T-20261121-003 · 走路动画独立复评（Art Director）
- 父任务: T-20261121-002；依赖: T-20261121-002（done + Git 已发布）
- 类型: game-demo（独立复评）
- 目标: `game-art-director` 独立看侧向 walk/脚姿/接触；verdict；不改代码
- 交付: `docs/art-review/paperdoll-walk-review.md` + 代表图；FAIL 给下一轮 brief
- 约束: 独立评审；不实现
- 指派: game-art-director worker
- 状态: done
- depends_on: T-20261121-002
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-003/result.md

## T-20261120-013 · 纸娃娃策划设计方案（Game Designer）
- 来源: 飞书反馈（“缺了个策划提设计方案”，2026-11-20）
- 父任务: T-20261120-006
- 类型: game-demo（策划）
- 目标: 先定义目标玩家/核心循环/MVP/优先级/UX 内容/验收口径，给美术/程序/QA 同一份设计依据
- 交付: `docs/design/paperdoll-design-spec.md` + 一页流程/优先级图；媒体
- 约束: 不写代码/不画资产/不做 QA/不做独立美术评审；读参考视频、评审、当前 build
- 指派: game-designer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261120-013/result.md

## T-20261120-009 · 纸娃娃美术实现（Game Artist）
- 来源: 飞书消息（角色分工：美术参与开发，2026-11-20）
- 父任务: T-20261120-007（美术 brief）/ T-20261120-006（项目）
- 类型: game-demo（美术实现）
- 目标: 由 `game-artist` 按评审 brief 实现 P0-1/P0-3/P0-4/P0-5 + P1 视觉项；不改玩法；P0-2 AA/缩略图技术项留给 T-010 工程师
- 交付: 更新后的 `godot-paper-doll/` 视觉层；before/after/剪影/8 向/动作/舞台/UI 物料；FPS 不回归；媒体发送
- 约束: 只改视觉文件/资产；原创；不复制参考素材；保留 17 槽/8 向/4 动作/16 预设；不做 QA/独立评审
- 指派: game-artist worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261120-009/result.md

## T-20261120-010 · 纸娃娃技术/性能/AA（Game Engineer）
- 父任务: T-20261120-009；依赖: T-20261120-009 + T-20261120-013（done + Git 已发布）
- 类型: game-demo（技术）
- 目标: 只做技术/性能/AA/缩略图烘焙/集成：2× SubViewport 超采样、Linear、mini 删细节、一次性烘焙、FPS；不重做美术方向
- 交付: 更新后的 `godot-paper-doll/`；PAPERDOLL_SMOKE_OK/verify/FPS/截图；TECH/迭代记录；媒体
- 约束: 不改美术风格/玩法；不改 QA/评审；原创
- 指派: game-engineer worker
- 状态: done
- depends_on: T-20261120-009, T-20261120-013
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261120-010/result.md

## T-20261120-011 · 纸娃娃 QA 独立验收（QA Lead）
- 父任务: T-20261120-010；依赖: T-20261120-010（done + Git 已发布）
- 类型: game-demo（QA）
- 目标: 独立验收；按评审 §8 跑 smoke/截图/剪影/8 向/动作/GIF/指标；不改代码/美术；出 verdict
- 交付: `docs/qa-review/paperdoll-qa.md` + 指标/截图；媒体
- 约束: 只写 QA 报告；失败打回，不自己修；依赖 T-010
- 指派: game-qa-lead worker
- 状态: done
- depends_on: T-20261120-010
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261120-011/result.md

## T-20261120-012 · 纸娃娃独立美术复评（Art Director）
- 父任务: T-20261120-011；依赖: T-20261120-011（done + Git 已发布）
- 类型: game-demo（独立复评）
- 目标: 由 `game-art-director`（非 game-artist 实现者）用同一 rubric 复评最新 build/QA 证据；给 APPROVE/CONCERNS/REJECT
- 交付: `docs/art-review/paperdoll-art-review-round2.md` + 代表图；不改代码；FAIL 给下一轮整改 brief
- 约束: 独立评审；不实现；依赖 T-011
- 指派: game-art-director worker
- 状态: done
- depends_on: T-20261120-011
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261120-012/result.md

## T-20261120-008 · 纸娃娃美术整改（P0+P1）
- 来源: 飞书消息（“推进提升美术质量”，2026-11-20）
- 父任务: T-20261120-007（美术评审 4.2/10，门槛 7.0）
- 类型: game-demo（美术整改）
- 目标: 按评审 brief 落地 P0 全部 + P1-2/P1-5（并尽量 P1-1/P1-3/P1-4），把 `godot-paper-doll` 从 4.2 提升到公开试玩 ≥7.0；不改玩法
- 交付: 更新后的 `godot-paper-doll/`；before/after 1280×720 / 25% / 纯黑剪影 / 8 向罗盘 / 4×3 动作关键帧 / 6s GIF；FPS/对比度/墨占比；README/TECH/迭代记录；媒体发送
- 约束: 原创美术/代码；不复制参考片素材；保留 17 槽/8 向/4 动作/16 预设；Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: stopped
- 产出: 角色分工修正；engineer-only 美术任务停止，改由 T-20261120-009 Game Artist 执行

## T-20261120-007 · 纸娃娃美术评审 + 美术 agent 提示词库
- 来源: 飞书反馈（2026-11-20，“这个效果有让美术agent审核评估吗…如果美术不太行就网上看看有没有可以复用的美术agent提示词”）
- 父任务: T-20261120-006
- 类型: game-demo（美术评审）
- 目标: 用 game-art-director 对 `godot-paper-doll` 做严格评审（P0–P2 + 参数建议）；调研可复用美术 agent 提示词，更新通用美术总监 prompt / 提示词库
- 交付: `docs/art-review/paperdoll-art-review.md`、`docs/art-direction/art-agent-prompt-pack.md`、更新 `.claude/agents/game-art-director.md`；代表截图；不修改游戏代码
- 约束: 只评审/提示词；引用网上来源与许可；不改 `godot-paper-doll` 代码；完成后发媒体并自动提交
- 指派: game-art-director worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261120-007/result.md

## T-20261120-006 · 木头人纸娃娃角色系统（T-004 重试）
- 来源: 飞书消息（“需要”重试 T-20261120-004，2026-11-20）
- 父任务: T-20261120-004
- 类型: game-demo
- 目标: 完成 17 槽位分层纸娃娃（8 方向 + idle/walk/attack/hit + 独立换色 + 16 预设 + 4×4 阵容 + 保存/加载），修复上次 API 中断留下的半成品
- 交付: `godot-paper-doll/` 可玩组合器；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke
- 约束: 原创木头人美术/UI/名字；不复制视频素材/品牌；1280×720 GL Compatibility；完成后发媒体并自动提交
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261120-006/result.md

## T-20261120-005 · 修正像素水面倒影/水线（T-002 follow-up）
- 来源: 飞书反馈（2026-11-20；截图 `godot-pixel-ocean/docs/shots/01_sunset_wide.png`）
- 父任务: T-20261120-002
- 类型: game-demo
- 目标: 修复“木筏像飞起来”的倒影问题：倒影平面/水线/接触泡沫/反射偏移对齐，木筏贴水而不是悬空
- 交付: `godot-pixel-ocean/` 修复；before/after `01_sunset_wide`、`02_sunset_reflection` + GIF/MP4；TECH/迭代记录更新；smoke；媒体发送
- 约束: 只改水面/倒影/水线表现，不改玩法；原创；1280×720 GL Compatibility，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261120-005/result.md

## T-20261120-004 · 木头人 17 槽位纸娃娃角色系统复刻
- 来源: 飞书消息（B 站 BV1dbxc6aEyU《独立游戏 | 一个木头人，怎么变成16个角色》，2026-11-20）
- 类型: game-demo
- 目标: 复刻 17 槽位分层纸娃娃：头/发型/衣服/帽子/武器等单独换装，8 方向 + 走路/攻击/挨打，每部件独立换色，16 个预设角色
- 交付: `godot-paper-doll/` Godot 4.6 2D 角色组合器（槽位/变体/颜色/方向/动作/随机/16 预设/阵容展示）；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke
- 约束: 原创木头人美术/UI/名字；不复制视频素材/创作者游戏品牌；1280×720 GL Compatibility；完成后必须发媒体
- 指派: game-engineer worker（dispatcher）
- 状态: failed
- 产出: /Users/ks_128/.cc-connect/tasks/failed/T-20261120-004/result.md

## T-20261120-003 · 像素木筏钓鱼/收集/扩建复刻
- 来源: 飞书消息（B 站 BV19yWi6HEEK《玩家是对开发者最好的奖励！》，2026-11-20；同一作者“大肥鱼的开发日记”）
- 类型: game-demo
- 目标: 复刻该 devlog 里的核心循环：木筏钓鱼/钩资源 → 木材/桶/箱 → 扩建木筏/箱子 → 净水/烤鱼；加入自动瞄准/追踪、5 点浮力、像素水面
- 交付: `godot-raft-fishing/` 可玩 Godot 4.6 vertical slice；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创名字/UI/素材；不复制该作者的游戏素材/品牌；可复用 T-20261120-002 的水面（若已完成），否则先简化；1280×720 GL Compatibility，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261120-003/result.md

## T-20261120-002 · 像素水面 + 木筏效果复刻
- 来源: 飞书消息（B 站 BV1ehsm69EnT《我做了一个很酷的效果》，2026-11-20）
- 类型: game-demo
- 目标: 复刻视频的水面配方：密集水面网格 + 3 道浪 + 拉长/挤尖 + 木筏五点浮力 + 像素水纹 + 浪边/逆光白沫 + 镜面/倒影 + 碎金光 + 透明
- 交付: `godot-pixel-ocean/` 可交互 Godot 4.6 demo（参数面板/昼夜/浪/泡沫/倒影/透明）；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke
- 约束: 原创 shader/材质/贴图；不复制视频素材；1280×720 GL Compatibility，Intel 30fps+；完成后必须发媒体
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261120-002/result.md

## T-20261119-007 · Reelward 美术升级（T-002 follow-up）
- 来源: 飞书反馈（2026-11-19，“这个美术效果太差了”）
- 父任务: T-20261119-002
- 类型: game-demo
- 目标: 保留现有玩法/测试，对 Reelward 做整体视觉升级：符号/单位/背景/老虎机柜/UI/VFX/字体/过渡
- 交付: 更新后的 `godot-slot-defense/`；before/after 截图 + GIF/MP4；README/TECH/迭代记录更新；smoke/verify 通过
- 约束: 原创暗色霓虹像素风，不复制 Slotbound 美术/UI/文案；1280×720 GL Compatibility，Intel 30fps+；不改玩法
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261119-007/result.md

## T-20261119-005 · Water Pro + Three.js 体积云复刻
- 来源: 飞书消息（B 站 BV1BRHw6fEfW，2026-11-19）
- 类型: game-demo
- 目标: 识别视频中的开源项目，拆解 Water Pro 风格水体 + Three.js 体积云，在仓库做一个可运行的视觉 demo
- 交付: `threejs-water-clouds/` 静态 Three.js 项目（水体 + 体积云 + 天空 + 相机控制）；README/TECH/迭代记录/CREDITS；1280×720 真实 GPU 截图 + GIF/MP4；浏览器 console 0
- 约束: 先查原项目 license；允许复用的代码/素材必须署名；否则净室原创；不复制版权素材；不修改其他项目
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261119-005/result.md

## 队列

（空）

## 已完成

## T-20261119-002 · 复刻老虎机塔防（Slotbound 风格）
- 来源: 飞书消息（复刻 Slotbound / 转运军团，2026-11-19；参考视频 https://m.toutiao.com/is/7cAgSDz5ulI/）
- 类型: game-demo
- 目标: 在 Godot 4.6 做原创版「3×3 老虎机 → 召唤单位 → 自动战斗 → 波次/商店改概率」vertical slice
- 交付: `godot-slot-defense/` 可玩项目（3×3 转轮、6 符号、连线召唤、单战线、5 波+Boss、4 类道具商店、心数/金币、胜负/重开、倍速）；README/TECH/迭代记录/CREDITS；截图 + GIF；headless smoke
- 约束: 只复刻玩法循环，不复制 Slotbound 美术/UI/文案/品牌；原创符号/素材/名字（Reelward / 转轮守卫）；1280×720 GL Compatibility；不修改其他项目
- 指派: game-engineer
- 状态: done
- 产出: `godot-slot-defense/`；`SLOT_SMOKE_OK checks=94`、`VERIFY_OK`；6 张 1280×720 截图；GIF 720×405/10s；MP4 1280×720/10s；8/8 seeds 通关（68.2–75.5s）
