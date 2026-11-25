# 任务规划 · 文档 / 调研

## 进行中 / 最近完成

## T-20261125-006 · 沉淀「打击感」设计经验：浏漓顿挫与 Godot 实现参数
- 来源: 飞书消息（B 站《打击感从哪里来？杜甫一千年前就写过》，https://b23.tv/fyoa1l9，2026-11-25，2:58）
- 类型: docs-research
- 目标: 拆解视频的打击感层次（对手反应/刀停/声响/节奏），结合只狼、怪猎 0.2s 等案例，沉淀成可执行的 hit-feel 设计/审计 playbook、参数范围与 Godot 实现映射
- 交付: `docs/game-feel-hit-impact-playbook.md` + 交互 HTML 检查表 + `docs/templates/hit-feel-audit.md` + 截图；来源 URL/访问日期
- 约束: 只研究/写文档，不改代码；不复制视频/游戏素材；区分公开事实/作者观点/推断；参数给范围并标注来源；中文
- 指派: general-purpose worker（dispatcher）
- 状态: done

## T-20261121-040 · 续跑 Godot 程序化地图调研（T-020 重试）
- 线程: T-20261121-020（程序化地图）
- 父任务: T-20261121-020（failed）；原 T-021 阻塞于此
- 类型: docs-research
- 目标: 复用 T-020 失败前产物，补完 Godot 程序化地图技术方案/案例/2–3 个复刻目标 brief，解除 T-021 阻塞
- 交付: `docs/godot-procgen-survey.md` + 交互 HTML + 截图；明确 T-021 实现 brief
- 约束: 只调研/写 brief；案例可查证；区分 Godot 原生/插件/非 Godot；不复制素材；中文
- 指派: general-purpose worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-040/result.md
- 结论: 复用 T-020 已落盘正文并补完交付与复核。3 个 demo 在 Chrome 150 headless 实测 0 console error（CA 连通块 1 / BSP 21/21 可达 / 噪声 5 河 7 POI）；案例复核修正 7 项（Cassette Beasts 原文 404→Wayback、Dome Keeper 删未证实细节、Lumencraft 补 Steam 程序化证据、Brotato 补固定竞技场证据、Road to Vostok/ΔV 改为未证实、loothammer 改为 README MIT）；T-021 brief 已就绪（A：BSP+TileSet Terrain 64×48 ≤50ms；B：噪声生物群系 96×64 ≤100ms；C 可选）。微基准沿用 T-020 数据、未重跑（版本已复核）。
- 后续: T-20261121-021（复刻实现，依赖改为本任务）

## T-20261121-041 · 续跑 AI 半成品 4 步抢救法（T-028 重试）
- 线程: T-20261121-028（AI 半成品抢救）
- 父任务: T-20261121-028（failed）
- 类型: docs-research
- 目标: 复用失败前产物，完成 playbook + 交互 HTML + taste/clarify/judge 模板
- 交付: `docs/ai-half-finished-rescue-playbook.md` + 交互 HTML + `docs/templates/` + 截图；媒体
- 约束: 只调研/写模板；不复制《烬谷盗火录》素材；模板可直接用于 dispatcher/worker prompt；中文
- 指派: general-purpose worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-041/result.md
- 结论: 4 招落成 7 步 SOP + 10 层 triage + 3 模板；交互版含 triage 向导（12 症状/10 层/JSON 导出）、否决清单编辑器（本地保存/Markdown 导出）、裁判 rubric（5 套/加权/P0 门禁/反谄媚自检）；Chrome 150 交互自测 0 控制台错误。相对 T-028 新增 HTML、2 张截图与自测证据，正文方法结论不变。
- 后续: 无（T-028 线程收口）

## T-20261121-038 · 拆解「挑战极限，一局搞定，你能顶住几波进攻」并给复刻 brief
- 来源: 飞书消息（今日头条链接，https://m.toutiao.com/is/Xt1ba_Px_vo/，文章 ID 7690271997971939903，2026-11-22）
- 类型: docs-research
- 目标: 先识别链接里的游戏/演示与真实的波次进攻机制，再给可复刻的 Godot 波次生存 vertical slice brief
- 交付: `docs/wave-defense-teardown.md`（结论先行；游戏/来源识别；核心循环/波次/难度/升级/反馈；复刻范围与验收；IP 边界；来源）+ 截图；媒体
- 约束: 只研究/写 brief，不做实现；链接页无元数据，需尝试页面 JSON/yt-dlp/搜索交叉识别；不复制游戏素材/IP；不确定处明确标注
- 指派: general-purpose worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-038/result.md
- 结论: 链接是《奔奔王国》来源账号（疑似官方）的 182s 竖屏广告创意，不是完整实机；真实游戏开局约 3 波塔防后转城建/SLG，另有 20 波联盟活动；已给单场地 8 波 Godot 4.6 GL 复刻 brief（5 种敌人/2 种塔/3 个决策点/失败重开分数），并附 IP 边界与验收

## T-20261121-036 · 调研 · 小游戏换皮/重皮肤管线（B 站 BV16gs36aECJ）
- 来源: 飞书消息（B 站《同一个小游戏，一个晚上换了三套皮》，https://b23.tv/BxqFSUh，2026-11-21）
- 类型: docs-research
- 目标: 拆解“布局参考 → 风格模型洗 → 4K 修字 → 设定表切零件 → 文件名映射进游戏”的换皮流程，转成适用于本仓库的 reskin kit 规格与工具替代方案
- 交付: `docs/reskin-pipeline-teardown.md`（结论先行 + 步骤/参数 + 提示词模板 + 零件 manifest + 工具替代 + 验收 + IP 边界 + 来源）+ 交互 HTML 检查表 + 截图；媒体
- 约束: 只研究/写规格，不复制《末日小队》素材/界面；风格只做通用描述，不点名模仿在世艺术家；区分魔触（商业工具）与开源替代；不写入代码
- 指派: general-purpose worker（dispatcher）
- 状态: done

## T-20261121-033 · 调研 · 玩法创新方法与案例库（Game Designer 能力建设）
- 来源: 飞书消息（2026-11-21，“AI 做游戏越来越便宜，后续更需要玩法创新；策划 agent 是否具备，若不具备帮我推动积累”）
- 类型: docs-research
- 目标: 系统调研玩法创新的方法、案例与评估/验证流程，产出 game-designer 可复用的创新框架、评分表、案例库与针对当前项目的 idea seeds
- 交付: `docs/design/gameplay-innovation-research.md`（结论先行 + 方法/案例/评分/流程/反模式 + 来源）+ 交互 HTML（约束卡/评分器）+ 截图；媒体
- 约束: 只调研/写方法，不改代码；案例必须可查证（Balatro/Slay the Spire/Baba Is You/Outer Wilds/Hades 等），区分事实/推断；不复制 IP
- 指派: general-purpose worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-033/result.md
- 备注: 10 个案例 / 24 个 idea seeds / 3 个一页 brief；交互版含约束卡随机器、五项评分器、案例卡；已发 2 张截图到飞书。

## T-20261121-032 · 调研 · 鬼灭「无限城」AI 3D 动作游戏 + MotionStage 工具
- 来源: 飞书消息（B 站《7.9万人玩过的鬼灭游戏，我是怎么用 AI 做出来的｜附开源动作工具》，https://b23.tv/MsgL53G，2026-11-21）
- 类型: docs-research
- 目标: 拆解作者用 AI 做 3D 动作游戏的流程/三个坑，并核实开源工具 MotionStage（MIT）的能力与接入方式，给本仓库 3D 动作/Blender 管线建议
- 交付: `docs/motion-stage-and-ai-3d-game-teardown.md`（结论先行 + 流程/坑 + MotionStage 技术/许可/导出 + 接入方案 + IP 边界 + 来源）+ 工具截图/证据；媒体
- 约束: 只研究，不复制鬼灭 IP/游戏素材/角色；MotionStage 为 MIT，可研究/试用但保留许可；不改游戏代码；区分作者自述与验证
- 指派: general-purpose worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-032/result.md

## T-20261121-030 · 调研 · Blender 二次元女性角色管线（供美术 Agent 能力建设）
- 来源: 飞书消息（2026-11-21，“如果不具备，调研怎么把这个能力补全到美术 agent，持续迭代到接近原神品质”）
- 类型: docs-research
- 目标: 调研可复现的 Blender 二次元可爱女性角色管线（比例/脸/眼/发/服装、建模/拓扑/UV/贴图、toon/描边、绑定、导出、验收），并给出 agent skill/toolkit 设计
- 交付: `docs/agent-capabilities/blender-anime-pipeline.md`（结论先行 + 管线对比 + 许可/版本 + 质量分级 + skill 草案 + 来源）+ 截图；不写游戏代码
- 约束: 只调研；优先开源/免费工具；核实插件许可与 Blender 3.4/4.2 兼容；区分“可达风格化”与“原神级生产管线”；不复制 IP；面向 Intel HD 渲染限制
- 范围补充: 必须覆盖 Tripo 图生 3D（API/计费/输出/接入），并与 TripoSR 等方案对比
- 指派: general-purpose worker（dispatcher）
- 状态: done
- 线程: T-20261121-029（能力建设）
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-030/result.md

## T-20261121-028 · 调研 · AI 半成品游戏 4 步抢救法（B 站 BV1AVs461EFQ）
- 来源: 飞书消息（B 站《AI给的半成品差点意思？4招妙手回春！》，https://b23.tv/VmLeMCN，2026-11-21）
- 类型: docs-research
- 目标: 拆解视频 4 个方法（分层诊断、先问清楚、否决清单=taste、AI 互评/中立裁判），转成适用于本仓库多 agent 流水线的 SOP、模板与验收清单
- 交付: `docs/ai-half-finished-rescue-playbook.md` + 交互 HTML（triage 向导/否决清单/裁判 rubric）+ `docs/templates/` 模板 + 截图；来源
- 约束: 只调研/写模板，不改代码；不复制《烬谷盗火录》素材；区分视频观点与验证；模板要能直接用于 dispatcher/worker prompt
- 指派: general-purpose worker（dispatcher）
- 状态: failed（已由 T-20261121-041 续跑收口）
- 后续: T-20261121-041（failed 重试；补齐交互版/截图/自测）

## T-20261121-027 · 调研 · 独立开发者 10 个开源游戏工具链（B 站 BV11D4j64Eh3）
- 来源: 飞书消息（B 站《一个人做游戏：引擎、美术、3D、配音、NPC，10 个开源工具全覆盖》，https://b23.tv/AYWbnRR，2026-11-21）
- 类型: docs-research
- 目标: 核实视频提到的 10 个开源工具的许可/能力/成熟度/硬件/集成成本，给出适合本仓库的采用矩阵与最小工作流
- 交付: `docs/open-source-solo-gamedev-toolkit.md`（结论先行 + 工具对比表 + 采用矩阵 + 风险/许可 + 来源）+ 交互 HTML（工具筛选/管线图）+ 截图；媒体
- 约束: 只调研不安装/不改造；以官方仓库/文档核实版本与许可；区分视频 claim 与已验证事实；AI 语音/美术注意版权与肖像/声音授权；中文
- 指派: general-purpose worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-027/result.md
- 结论: 本仓库主线 Godot + Blender；Whisper/OpenVoice/TripoSR/ComfyUI/SB3/Ren'Py 值得按需评估；ML-Agents（锁 Unity 6）与 RVC（声音授权风险）不进主线；ComfyUI/TripoSR 在本机 Intel Mac 需云端 GPU。视频 claim “TripoSR A100 <0.5s”“OpenVoice V2 MIT 免费商用”已用官方 README 核实。

## T-20261121-020 · 调研 · Godot 程序化地图生成技术方案与优秀案例
- 来源: 飞书消息（2026-11-21，“godot在程序化地图生成这块有哪些技术方案，以及优秀效果案例然后复刻”）
- 类型: docs-research
- 目标: 系统调研 Godot 4.6 程序化地图生成的技术方案与优秀效果案例，给出 2–3 个可复刻目标与实现 brief（含参数/验收/许可）
- 交付: `docs/godot-procgen-survey.md`（结论先行 + 技术对比表 + 案例表 + 推荐 + brief）+ 交互式 HTML + 截图；来源 URL/访问日期
- 约束: 只调研不改进游戏代码；区分 Godot 原生/插件/非 Godot 可移植；案例必须可查证，标注许可；不复制版权素材；面向 Godot 4.6 GL Compatibility / Intel HD
- 指派: general-purpose worker（dispatcher）
- 状态: failed → 产物由 T-040 补完（2026-11-22）
- 产出: 正文 HTML 在失败前已落盘；T-040 补齐截图/复核/交付，见 `docs/godot-procgen-survey.md` §7.4
- 备注: 失败原因 `API Error: Connection closed mid-response`；`docs/godot-procgen-survey.md` 与 HTML 当时已写入（16:38/16:41）但未截图、未发送、未提交
- 后续: T-20261121-021（复刻实现）、T-20261121-022（3D 海岛 deep dive）

## T-20261121-022 · 调研 · Godot 3D 海岛生成方案（T-020 follow-up）
- 来源: 飞书消息（2026-11-21，“帮我调研下 godot 如何生成 3d 海岛”）
- 线程: T-20261121-020（程序化地图调研）
- 父任务: T-20261121-020；不硬依赖（可与 T-020 并行；若 T-020 报告已出则复用其结论）
- 类型: docs-research
- 目标: 聚焦 Godot 4.6 的 3D 海岛生成：高度场/岛屿遮罩/噪声/侵蚀、网格与碰撞、水面/海岸、植被散布、LOD/分块、性能与插件选型；给可落地实现方案
- 交付: `docs/godot-3d-island-survey.md`（结论先行 + 方案对比 + 推荐栈 + MVP 步骤/参数/验收 + 来源）+ 交互 HTML（高度场/岛屿遮罩/海岸线可视化）+ 截图
- 约束: 只调研不写游戏代码；区分 Godot 原生/插件/非 Godot；核实许可与版本；面向 GL Compatibility / Intel HD；不复制版权素材
- 指派: general-purpose worker（dispatcher）
- 状态: done
- depends_on: []
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-022/result.md
- 结论: 默认高度场路线（257² 高度场 / 8×8 分块 / HeightMapShape3D / 预生成岸线深度图水面）；低多边形为风格化备选；体素只作后续扩展；实测 257² 生成约 1.0–1.6 s（不含侵蚀），侵蚀需离线

## T-20261121-010 · 调研 · 回合制游戏法术表现性能分析与审计方法
- 来源: 飞书消息（2026-11-21，“回合制游戏的法术表现性能分析审计一般如何处理”）
- 类型: docs-research
- 目标: 调研业界对回合制游戏法术/VFX 表现做性能分析与审计的通用做法，形成可套用到 `godot-battle/` 的审计协议、预算表与验收门槛
- 交付: `docs/spell-vfx-performance-audit.md`（结论先行 + 四层拆分 + Godot/Unity/Unreal/Three.js 映射 + 测量项/工具链/流程/门槛/报告模板）+ 交互式 HTML 检查表 + 截图；来源与访问日期
- 约束: 只调研不改进游戏代码；区分公开事实与推断；不复制素材；面向 Godot 4.6 GL Compatibility / Intel HD 6000 与移动档位；中文
- 指派: general-purpose worker（dispatcher）
- 状态: done

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
