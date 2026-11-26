# 任务规划 · 游戏 Demo

## 进行中

## T-20261126-033 · Swarmforge 3D 场景/模型性能压测（T-017 follow-up）
- 线程: T-20261126-017（百倍单位自走棋）
- 父任务: T-20261126-026（美术资产）
- 类型: game-demo（3D 渲染 / 性能压测）
- 目标: 把 Swarmforge 战斗视图增加 Godot 4.6 3D 场景 + 3D 模型，保留 2D 回退；用 MultiMeshInstance3D 压测 100/1000/3000 单位 FPS/draw calls/CPU，对比 2D，给出 3D 是否可行
- 交付: 更新 `godot-swarm-autobattler/`（3D 模式）；3D 截图/GIF/MP4；性能表；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU
- 约束: 保持玩法/AI/UI/2D 模式不回归；真 3D 低模（禁止 billboard 冒充）；原创资产；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+ 目标
- 指派: game-engineer worker（dispatcher）
- 状态: queued

## T-20261126-032 · Emberhold 3D 版独立美术复评（T-022 follow-up）
- 线程: T-20261126-022（Emberhold 单文件塔防）
- 父任务: T-20261126-031（QA）
- 类型: game-demo（美术复评）
- 目标: 独立复评 Godot 3D 版是否达到“3D 场景/模型迭代”的目标；塔/敌人/地形/光照/VFX/UI 与性能；PASS/REJECT
- 交付: `godot-emberhold-3d/docs/art-review-final-T-20261126-032.md`；证据
- 约束: 不改代码/资产；1920×1080 目标尺寸
- 指派: game-art-director worker（dispatcher）
- 状态: canceled（目标误判：用户指的是 Swarmforge；T-029 额外产物保留，不做后续）

## T-20261126-031 · Emberhold 3D 版 QA 验收（T-022 follow-up）
- 线程: T-20261126-022（Emberhold）
- 父任务: T-20261126-030（3D 美术）
- 类型: game-demo（QA 验收）
- 目标: 独立验收 Godot 3D 版：HTML→Godot 玩法/AI 一致性、2 地图、4 塔/敌人、12 波、AI 托管、性能/console/smoke；PASS/REJECT
- 交付: `godot-emberhold-3d/docs/qa-T-20261126-031.md`；可复现证据
- 约束: 不改美术/实现；1920×1080 真实 GPU
- 指派: game-qa-lead worker（dispatcher）
- 状态: canceled（目标误判：用户指的是 Swarmforge；T-029 额外产物保留，不做后续）

## T-20261126-030 · Emberhold 3D 场景/模型美术升级（T-022 follow-up）
- 线程: T-20261126-022（Emberhold）
- 父任务: T-20261126-029（Godot 3D 移植）
- 类型: game-demo（美术实现）
- 目标: 在 Godot 3D 版上做 3D 美术 pass：塔/敌人/地形/路径/道具/出生门/光照/阴影/雾/VFX/UI skin；保持玩法/AI 不变，Intel 30fps+
- 交付: 更新 `godot-emberhold-3d/`；before/after 截图/GIF/MP4；docs；性能数据
- 约束: 原创低模/材质；不复制 Cinderwatch/第三方资产；不改玩法/数值/AI；Godot 4.6 GL Compatibility
- 指派: game-artist worker（dispatcher）
- 状态: canceled（目标误判：用户指的是 Swarmforge；T-029 额外产物保留，不做后续）

## T-20261126-029 · Emberhold 移植 Godot 4.6 3D（T-022 follow-up）
- 线程: T-20261126-022（Emberhold 单文件塔防）
- 父任务: T-20261126-022（done）
- 类型: game-demo（Godot 3D 移植）
- 目标: 把 `web-html-tower-defense/` 的完整玩法/AI 移植到 Godot 4.6 3D：2 地图、4 塔、敌人/12 波、金币/生命、升级/出售、暂停/倍速、AI 指挥官、地图过渡、UI；3D 场景/相机/低模/光照
- 交付: `godot-emberhold-3d/` 可玩项目；HTML→Godot parity 表；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU
- 约束: 不改 HTML 版；原创低模/程序化；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；保留原 AI 行为/参数
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-029/result.md
- 说明: HTML 版未改动；实时方向光阴影默认关（Intel HD 30fps+），接触阴影/光照/雾保留，`-- --shadows` 可开

## T-20261126-028 · Swarmforge 美术升级独立复评（T-017 follow-up）
- 线程: T-20261126-017（百倍单位自走棋）
- 父任务: T-20261126-027（QA）
- 类型: game-demo（美术复评）
- 目标: 对照 T-20261126-025 brief 判断升级后是否达到生产级；检查单位剪影/卡牌/棋盘/VFX/UI 与 3000 单位性能；PASS/REJECT
- 交付: `godot-swarm-autobattler/docs/art-review-final-T-20261126-028.md`；证据
- 约束: 不改代码/资产；1920×1080 目标尺寸审查
- 指派: game-art-director worker（dispatcher）
- 状态: canceled（2D 美术复评取消；改为 T-033 Swarmforge 3D 性能压测）

## T-20261126-027 · Swarmforge 美术升级 QA 验收（T-017 follow-up）
- 线程: T-20261126-017（百倍单位自走棋）
- 父任务: T-20261126-026（美术升级）
- 类型: game-demo（QA 验收）
- 目标: 独立验收 P0/P1 关闭情况、3000 单位 FPS/draw calls、商店/战斗/阵容码回归、console/smoke；PASS/REJECT
- 交付: `godot-swarm-autobattler/docs/qa-T-20261126-027.md`；可复现证据
- 约束: 不改美术/实现；1920×1080 真实 GPU
- 指派: game-qa-lead worker（dispatcher）
- 状态: canceled（2D 美术 QA 取消；改为 T-033 Swarmforge 3D 性能压测）

## T-20261126-026 · Swarmforge 生产级美术资产升级（T-017 follow-up）
- 线程: T-20261126-017（百倍单位自走棋）
- 父任务: T-20261126-025（brief）
- 类型: game-demo（美术实现）
- 目标: 按 brief 落地 P0/P1：6–8 种可读单位剪影/阵营色/攻击帧、卡牌插画+稀有度框、棋盘环境/光照、VFX/伤害数字、UI/字体/图标；保持 MultiMesh/3000 单位 30fps
- 交付: 更新 `godot-swarm-autobattler/`；before/after 截图/GIF/MP4；docs；性能数据；smoke
- 约束: 原创资产；不复制 TFT/Hearthstone/全军出鸡 IP；不改玩法/数值；Godot 4.6 GL Compatibility，Intel 30fps+
- 指派: game-artist worker（dispatcher）
- 状态: running

## T-20261126-025 · Swarmforge 生产级美术 brief（T-017 follow-up）
- 线程: T-20261126-017（百倍单位自走棋）
- 父任务: T-20261126-017（done）
- 类型: game-demo（美术总监 brief）
- 目标: 在 1920×1080 审查当前美术，定义“生产级”可执行标准：单位剪影/阵营色、卡牌插画/稀有度框、棋盘环境、VFX、UI/字体/图标；给出 P0–P2 + 参数 + 3000 单位性能预算
- 交付: `godot-swarm-autobattler/docs/art-review-T-20261126-025.md` + 标注图；不改代码/资产
- 约束: 不复制 TFT/Hearthstone/全军出鸡 角色/UI/卡牌/品牌；MultiMesh/3000 单位 30fps 是硬约束；fail-closed 验收
- 指派: game-art-director worker（dispatcher）
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-025/result.md
- 状态: done

## T-20261126-024 · 复刻 Claude+Codex+Godot 3D 动作游戏（3h25m）
- 来源: 飞书消息（B 站《Claude + Codex + Godot，3小时25分钟做出一款3D游戏！》，https://b23.tv/huVtu9e，2026-11-26，7:26，UP AI前沿君；封面为低多边形芽苗勇者 vs 蘑菇怪）
- 类型: game-demo（3D 低多边形动作 / AI 开发复刻）
- 目标: 识别视频最终 3D 游戏的核心循环与表现，在 Godot 4.6 复刻成可玩 vertical slice：第三人称芽苗勇者、蘑菇敌人、近战/闪避、血量/击退、目标/胜负；原创名称/低模/关卡
- 交付: `godot-sproutbound/` 可玩项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU
- 约束: 复刻游戏不复制视频流程/素材/角色设计/品牌；原创低模/程序化资产；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；视频不明确处写假设
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-024/result.md

## T-20261126-022 · 复刻单文件 HTML 塔防 + AI 指挥官
- 来源: 飞书消息（B 站《Fable 5.2 把一个完整塔防塞进单个 HTML：零后端零美术资源，AI 指挥官能自己守塔（带试玩地址）》，https://b23.tv/ech1X6H，2026-11-26，27s，UP eddieliugd；原 Demo Cinderwatch，MIT）
- 类型: game-demo（Web 单文件塔防 / AI 托管）
- 目标: 复刻“单 HTML + 零后端 + 零外部美术 + AI 指挥官自动守塔”的体验；原创名称/美术/代码，不照搬 Cinderwatch
- 交付: `web-html-tower-defense/index.html`（HTML+CSS+原生 JS 全内联，无外部依赖/素材）；AI 托管/手动切换；2–3 地图过渡；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；Playwright 验证
- 约束: 单文件、零后端、零外部美术/字体/音频/CDN；原创程序化抖动像素；不复制 Cinderwatch 代码/素材/名称（MIT 仅作参考，若复用必须署名）；浏览器 1280×720/1920×1080，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-022/result.md
- 状态: done
- 后续: T-20261126-029 Godot 3D 移植（done，额外产物保留）；T-030~T-032 取消（目标误判，用户指的是 Swarmforge）

## T-20261126-021 · 优化风格化海洋海岛-水交接（T-010 follow-up）
- 线程: T-20261126-010（风格化海洋）
- 父任务: T-20261126-010（done）
- 类型: game-demo（美术优化 / 岸线）
- 目标: 结合参考视频分析并优化海岛与水的交接：湿沙带、浅水透明/深度色阶、岸线泡沫多带+噪声、礁石湿基/泡沫环、接触阴影/水线；去掉硬切色块与平板光晕
- 交付: 更新 `godot-stylized-ocean-v2/`；同机位 before/after 截图 ≥6；10s GIF/MP4；docs 更新；smoke + 真实 GPU
- 约束: 只改岸线/浅水/泡沫/湿沙/接触阴影；保留现有波浪/交互/UI/性能；原创素材，不复制参考视频/作者素材；Godot 4.6 GL Compatibility，Intel 30fps+
- 指派: game-artist worker（dispatcher）
- 状态: done
- 备注: T-011 QA 验收 = REJECT（视觉）：岸线硬切/旧青色光晕已修好（湿沙/透明浅水/三条泡沫带 PASS），但太阳高光不可见（P0-1）、礁石泡沫环呈白色甜甜圈（P0-2）；报告 `godot-stylized-ocean-v2/docs/qa-T-20261126-011.md`

## T-20261126-020 · 3D 像素水景修复独立复评（T-008 follow-up）
- 线程: T-20261126-008（3D 像素水面与鱼）
- 父任务: T-20261126-019（鱼/场景美术修复）
- 类型: game-demo（美术复评）
- 目标: 独立复评修复后的 3D 像素水景：黑点/脏噪、鱼轮廓/鱼群、水色/焦散/泡沫、构图与像素稳定；对照参考视频，PASS/REJECT
- 交付: `godot-3d-pixel-water-fish/docs/art-review-final-T-20261126-020.md`；1280×720/1920×1080 证据
- 约束: 不改代码/资产；只审查与结论
- 指派: game-art-director worker（dispatcher）
- 状态: queued

## T-20261126-019 · 3D 像素水景鱼/场景美术修复（T-008 follow-up）
- 线程: T-20261126-008（3D 像素水面与鱼）
- 父任务: T-20261126-018（渲染修复）
- 类型: game-demo（美术实现）
- 目标: 重做可读的低模鱼（身体/眼/鳍/尾）、鱼群间距/游动，以及水色/岸线/岛/水草/睡莲/光感；保持 3D 像素量化风格
- 交付: 更新 `godot-3d-pixel-water-fish/`；before/after 截图/GIF/MP4；docs 更新；smoke + 真实 GPU
- 约束: 原创素材；不复制参考视频/作者素材；只改视觉/资产，不改交互/玩法；1280×720/1920×1080，Intel 30fps+
- 指派: game-artist worker（dispatcher）
- 状态: queued

## T-20261126-018 · 3D 像素水景渲染异常修复（T-008 follow-up）
- 线程: T-20261126-008（3D 像素水面与鱼）
- 父任务: T-20261126-008（done）
- 类型: game-demo（渲染修复）
- 目标: 修掉水面/草地/岛上的黑色碎点（dither/hash/outline 过强）、水下黑线与折射越界、水体浑浊/焦散泡沫不可读；保留像素管线与性能
- 交付: 更新 `godot-3d-pixel-water-fish/`；同机位 before/after 截图 ≥6 组；TECH/迭代记录；GIF/MP4；smoke + 真实 GPU
- 约束: 不改鱼模型/关卡/交互/整体美术方向；不复制参考素材；真实 GPU；Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: failed

## T-20261126-017 · 复刻《全军出鸡》式百倍单位自走棋
- 来源: 飞书消息（B 站《酒馆战旗，但场上单位数量×100倍……》，https://b23.tv/2vtJIfx，2026-11-26，27:06，UP 独立游戏蜥蜴君；游戏《全军出鸡：鸡械绿洲自走棋》demo）
- 类型: game-demo（自走棋 / 大规模单位）
- 目标: 复刻抽象循环：商店/升本/三合一金卡/高星核心卡 → 每张卡生成数百单位 → 同屏上千单位自动战斗；加入原创“贪婪潮”风险收益与阵容码镜像对战
- 交付: `godot-swarm-autobattler/` 可玩 vertical slice；100/1000/3000 单位性能数据；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU
- 约束: 只复刻抽象机制；不复制 Hearthstone Battlegrounds / 全军出鸡 / 鸡械绿洲 的角色/UI/卡牌/美术/品牌；原创单位/卡牌/主题；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；用实例化渲染，禁止每单位 Node
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-017/result.md
- 后续: T-20261126-025 美术 brief → T-20261126-026 美术资产（running，作为 3D 素材基础）→ T-20261126-033 Swarmforge 3D 性能压测；2D QA/复评 T-027/T-028 取消

## T-20261126-016 · 复刻 Monument Valley 式等轴不可能几何解谜
- 来源: 飞书消息（B 站《这是解谜游戏史上最富有想象力的关卡之一》，https://b23.tv/dM7vHb6，2026-11-26，4:47，UP A宝OVO_；游戏 Monument Valley）
- 类型: game-demo（等轴不可能几何 / 解谜）
- 目标: 复刻视频展示的核心不可能几何体验：固定等轴相机、旋转建筑/路径、屏幕空间对齐后连接不同深度的路径；原创几何/角色/关卡，不复制 Monument Valley 的具体关卡/美术/品牌
- 交付: `godot-foldpath-puzzle/` 可玩 vertical slice（3 关）；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU
- 约束: 只复刻抽象机制；不复制 Monument Valley/ustwo 的关卡/角色/美术/音乐/品牌；原创低模/色板/关卡；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-016/result.md

## T-20261126-015 · 复刻《Trifolium》3D 一笔画打结解谜
- 来源: 飞书消息（B 站《【解谜游戏】可以打结的一笔画〈Trifolium〉Demo试玩》，https://b23.tv/PGfHEPL，2026-11-26，23:58，UP GT阿某；Trifolium / EmptyMatter，Steam demo）
- 类型: game-demo（3D 一笔画 / 打结解谜）
- 目标: 复刻 3D 一笔画+打结核心：画连续线绕柱/套圈/打结，满足结条件而非只数圈；友好 undo；小开放区域与目标判定
- 交付: `godot-knotline-puzzle/` 可玩 vertical slice；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU
- 约束: 只复刻抽象机制，不复制 Trifolium/EmptyMatter 素材/品牌/关卡；原创低模/关卡；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；结检测可近似但须在 TECH 说明
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-015/result.md

## T-20261126-014 · 复刻《SideStamp》滚块涂色解谜
- 来源: 飞书消息（B 站《〈SideStamp〉官方预告片 | 一款关于色彩与旋转的解谜游戏》，https://b23.tv/CKwXd38，2026-11-26，80s，1920×1080，GoodHeartGames；简介：roll blocks into pools of paint to color the proper tiles）
- 类型: game-demo（3D 等轴解谜 / 滚块涂色）
- 目标: 复刻核心循环：滚动方块 → 漆池给接触面染色 → 滚到目标砖盖章 → 旋转改变朝下面 → 完成目标图案/关卡；原创名称/美术/关卡
- 交付: `godot-hueroll-puzzle/` 可玩 Godot 4.6 vertical slice；≥6 关；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 只复刻抽象机制，不复制 SideStamp/GoodHeartGames 角色/UI/关卡/品牌/素材；原创低模/关卡；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-014/result.md

## T-20261126-012 · 风格化海洋第二版 独立美术复评
- 线程: T-20261126-010（风格化海洋）
- 父任务: T-20261126-011（QA）
- 类型: game-demo（美术复评）
- 目标: 独立复评 `godot-stylized-ocean-v2/` 是否达到参考视频的视觉语言与交互效果，给出 PASS/REJECT
- 交付: `godot-stylized-ocean-v2/docs/art-review-final-T-20261126-012.md`；1280×720/1920×1080 证据
- 约束: 不改代码/资产；只审查与结论
- 指派: game-art-director worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-012/result.md
- 结论: **REJECT，6.2/10（外放门槛 7.0）**。P0-1 俯视太阳闪点 0 个 >0.65 亮像素（参考同区 2274；低机位 20° 有宽光路 17287 px >0.80）；P0-2 水中礁石白环 72 角分箱 50% 有 >0.93 白核（参考 1%），25% 缩略图成白点。P1：浅水 5–10 m 灰/橄榄（`#78aca2` vs 参考 `#1985ab`，焦散对比 0.049 vs 0.084）、主泡沫带偏细偏匀、拖尾叠成白弹簧/点击环实心 torus、“岸线编辑可视化”橙色样条被背面剔除不可见（运行时 cull_disabled 即可见）。岸线整改有效部分（湿沙/透明浅水/三带泡沫/陆地接触阴影）实测存在。
- 备注: 独立自拍+量化判定，QA 报告仅引用性能/输入仿真；参考帧只存 `/tmp/ocean_v2_ref/`，未入库。修复清单、参数与验收阈值见报告。

## T-20261126-011 · 风格化海洋第二版 QA 验收
- 线程: T-20261126-010（风格化海洋）
- 父任务: T-20261126-010（实现）
- 类型: game-demo（QA 验收）
- 目标: 独立验收风格化海洋：波浪/色阶/泡沫/高光、鼠标涟漪/点击交互、相机、性能、console、smoke；对照参考视频
- 交付: `godot-stylized-ocean-v2/docs/qa-T-20261126-011.md`；PASS/REJECT + 可复现证据
- 约束: 不改美术/实现；1280×720/1920×1080 真实 GPU
- 指派: game-qa-lead worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-011/result.md
- 结论: **REJECT（视觉）**；功能/交互/性能/回归/资产 PASS。P0-1 太阳高光在 720/1080 不可见（水面 0 个 >0.8 亮斑）；P0-2 礁石泡沫环过亮过完整（白色甜甜圈/平板光晕）；P1 泡沫蕾丝/焦散/帆船；P2 文档默认值漂移。证据与复现命令见报告。
- 后续: T-20261126-012 独立美术复评 → **REJECT 6.2/10**（同两项 P0；新增 P1 浅水色/泡沫带/拖尾/岸线样条不可见）；见 `godot-stylized-ocean-v2/docs/art-review-final-T-20261126-012.md`

## T-20261126-010 · 复刻《风格化海洋第二版》交互水景
- 来源: 飞书消息（B 站《风格化海洋第二版》，https://b23.tv/WCH7Sow，2026-11-26，31s，1920×1080，UP TechFusion；简介：改版了之前的风格化海洋交互）
- 类型: game-demo（3D 风格化海洋 / 交互水景）
- 目标: 复刻视频的风格化海洋与交互：Gerstner/多层波浪、深度色阶、浪尖/岸边泡沫、卡通高光/菲涅尔、天空/岛屿/小船，以及鼠标涟漪/点击落石/扰动交互
- 交付: `godot-stylized-ocean-v2/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创低模/贴图/代码，不复制视频/原作者素材；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；不做重型流体模拟
- 指派: game-artist worker（dispatcher；视觉主导，QA/复评独立）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-010/result.md
- 备注: 视觉主导；水面/岛屿/道具/涟漪/落石/雨/昼夜/中文 UI 全部实现；真实阴影关闭（GL Compat 下方向光不稳定），使用手绘方向光 + 软接触阴影；夜/雨/调试视图齐全。交接 T-20261126-011（QA）、T-20261126-012（美术独立复评）
- 后续: T-20261126-021 海岛-水交接优化 → T-20261126-011 QA → T-20261126-012 美术复评

## T-20261126-008 · 复刻 3D 像素水面与鱼（t3ssel8r 风格）
- 来源: 飞书消息（B 站《做了水和鱼》，https://b23.tv/fnj2fKz，2026-11-26，49s，UP 迷茫Mmang_；简介：3D 像素渲染，借鉴 t3ssel8r，主要使用 GPT-6 编程）
- 类型: game-demo（3D 像素渲染 / 水面 / 鱼群）
- 目标: 复刻视频的 3D 像素水景：低分辨率 RT + 最近邻放大、色彩量化/抖动/描边、风格化水面（深浅色阶/折射/泡沫/焦散/波纹）与原创低多边形鱼群游动
- 交付: `godot-3d-pixel-water-fish/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创低模/贴图/代码，不复制 t3ssel8r/原作者素材或代码；Godot 4.6 GL Compatibility（若需换渲染器须说明），1280×720/1920×1080 显示，Intel 30fps+；不用付费资产
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-008/result.md
- 后续: T-20261126-018 渲染异常修复 → T-20261126-019 鱼/场景美术 → T-20261126-020 独立复评

## T-20261126-007 · 水面视觉整改独立复评（T-001 follow-up）
- 线程: T-20261126-001（水面 Shader）
- 父任务: T-20261126-006（QA）
- 类型: game-demo（美术复评）
- 目标: 对整改后的水面 demo 做独立复评：P0/P1 是否关闭、是否达到参考视频的视觉语言、是否可外放
- 交付: `godot-water-shader/docs/art-review-final-T-20261126-007.md`；pass/reject + 证据
- 约束: 不改代码/资产；在 1280×720 与 1920×1080 目标尺寸审查；对照 T-20261126-004 brief
- 指派: game-art-director worker（dispatcher）
- 状态: queued

## T-20261126-006 · 水面视觉整改 QA 验收（T-001 follow-up）
- 线程: T-20261126-001（水面 Shader）
- 父任务: T-20261126-005（整改）
- 类型: game-demo（QA 验收）
- 目标: 独立验收整改后水面 demo：P0/P1 关闭情况、海/河/湖/桥/雨积水回归、真实 GPU FPS/console、smoke
- 交付: `godot-water-shader/docs/qa-T-20261126-006.md`；放行/打回 + 可复现证据
- 约束: 不改美术方向/实现；only 验收；1280×720/1920×1080
- 指派: game-qa-lead worker（dispatcher）
- 状态: failed

## T-20261126-005 · 按 brief 整改水面 Demo 视觉（T-001 follow-up）
- 线程: T-20261126-001（水面 Shader）
- 父任务: T-20261126-004（视觉诊断 brief）
- 类型: game-demo（美术实现 / 水面视觉）
- 目标: 按 art-review 的 P0/P1 整改 `godot-water-shader/`：水深色阶/透明沙底、焦散、双波前白沫、湿沙岸线、反射/高光、场景美术与光感，去掉“调试线”观感；保留 16px mask/8 邻域/BFS/单 shader 管线
- 交付: 更新项目；before/after 截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU；commit_paths `godot-water-shader/` + 计划文件
- 约束: 原创素材；不复制视频/Unity 素材；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；不新增额外相机/Viewport
- 指派: game-artist worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261126-005/result.md

## T-20261126-004 · 水面 Demo 视觉诊断与 P0–P2 整改 brief（T-001 follow-up）
- 线程: T-20261126-001（水面 Shader）
- 父任务: T-20261126-001（done）
- 类型: game-demo（美术评审）
- 目标: 在目标显示尺寸审查当前水面 demo（截图/GIF/实机），量化“效果差”的维度，产出带证据与参数的 P0–P2 整改 brief
- 交付: `godot-water-shader/docs/art-review-T-20261126-004.md` + 标注图；不改代码/资产
- 约束: 对照参考视频帧只提取视觉语言，不复制素材；fail-closed 验收口径
- 指派: game-art-director worker（dispatcher）
- 状态: done

## T-20261126-002 · 复刻 2D 太阳/月亮动态影子（零额外灯光）
- 来源: 飞书消息（B 站《2D游戏太阳和月亮影子怎么做？零额外灯光源码拆解》，https://b23.tv/2btzuwT，2026-11-26，3:28，UP 小武同学贼下饭）
- 类型: game-demo（2D 像素光照 / 动态影子）
- 目标: 复刻零额外灯光的日月接力影子：太阳/月亮沿同一南侧天空东升西落 → 3 个全局 Shader 向量 → 顶点坍缩零叠黑地面影 + 单通道 RHalf 2.5D 高度遮挡图 + 60% 软膝限长；夜景暖黄路灯与冷蓝月影共存
- 交付: `godot-sun-moon-shadows/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创像素场景/素材，不复制 Unity/C# 源码或视频素材；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；不依赖逐物 Light2D/内置 2D 阴影组件
- 指派: game-engineer worker（dispatcher）
- 状态: done

## T-20261126-001 · 复刻 2D 海/河/湖共用 1 个水面 Shader（零额外网格）
- 来源: 飞书消息（B 站《2D游戏海河湖共用1个水面Shader？零额外网格源码拆解》，https://b23.tv/KYEA6ng，2026-11-26，3:54）
- 类型: game-demo（2D 水面 Shader / 程序化水深场）
- 目标: 复刻一套水面方案：手绘岸线 16px 抠图 → 2-Pass 8 邻域水深 → 零分配 BFS 区分海/河/湖 → 单一 Shader 表现浅滩/焦散/双波前白沫/桥面裁切/雨积水
- 交付: `godot-water-shader/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创像素场景/素材，不复制 Unity/C# 源码或视频素材；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；不额外建水面网格
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 后续: T-20261126-004 视觉诊断 → T-20261126-005 整改 → T-20261126-006 QA → T-20261126-007 独立复评

## T-20261125-013 · 复刻 Godot 法线贴图精灵光照教程
- 来源: 飞书消息（B 站《Godot 法线贴图：实现精灵光照效果》，https://b23.tv/3eSeHcH，2026-11-25，4:16）
- 类型: game-demo（2D 精灵光照 / 法线贴图）
- 目标: 按教程复刻 2D 精灵法线贴图光照：法线生成/导入、方向/点光、漫反射/高光、法线调试与前后对比
- 交付: `godot-sprite-normal-light/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创精灵/法线/场景，不复制教程/原作素材；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: done

## T-20261125-012 · 复刻 LDtk 式 2D 关卡编辑器（Godot 工具）
- 来源: 飞书消息（B 站《免费开源！3 分钟认识 2D 关卡编辑器 LDtk》，https://b23.tv/SpeXw3f，2026-11-25，3:04）
- 类型: game-demo（2D 关卡编辑器 / 工具）
- 目标: 复刻 LDtk 的核心工作流：画关卡结构 → 规则自动铺砖 → 放置出生点/敌人/宝箱并配置属性 → 保存/加载 → 预览
- 交付: `godot-level-editor/` 可运行 Godot 4.6 编辑器 demo；JSON schema + 保存/加载；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创瓦片/UI/代码，不复制 LDtk 品牌/素材/源码；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；不做完整 LDtk 克隆，只做核心 MVP
- 指派: game-engineer worker（dispatcher）
- 状态: done

## T-20261125-010 · 复刻《八方旅人》式 2D 像素光影 + 移轴景深
- 来源: 飞书消息（B 站《2d游戏怎么做出像八方旅人一样的质感？我教你！》，https://b23.tv/LXVeIZQ，2026-11-25，3:19）
- 类型: game-demo（2D 像素光照 / 屏幕后处理）
- 目标: 复刻 2D 像素“微缩沙盘”质感：实时 2D 光照/长影 + 不依赖 3D 深度缓冲的移轴景深/双环散景 + UI 不糊
- 交付: `godot-hd2d/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创像素场景/素材，不复制 Unity/C# 源码或视频素材；不复制八方旅人/SE 的素材/UI/品牌；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: done

## T-20261125-009 · 复刻 feralui 风格治愈场景（AI 游戏场景 / 微动画）
- 来源: 飞书消息（B 站《有人用 ai 搞的一个游戏 feralui 的场景，感觉非常不错，转发分享下》，https://b23.tv/towtE2d，2026-11-25，1:11）
- 类型: game-demo（3D/2.5D 场景 / 治愈系微动画）
- 目标: 按视频画面复刻一个治愈、微动画到位的原创场景 vertical slice：构图/配色/光照/环境动画/可交互小物件；不依赖 3A 后处理
- 交付: `godot-feralui-scene/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 不复制 feralui/X 作者/视频的角色/场景/UI/素材/品牌；原创低模/程序化资产；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261125-009/result.md
- 验收: smoke 85/85 + `FERALUI_SCENE_SMOKE_OK`；真实 GPU console 0 ERROR/WARNING；Intel HD 720p 夜 42fps / 1080p 窗口 30fps（median，HUD 可见；FPS gate 同时通过）

## T-20261125-008 · 复刻 2D 像素法线受光 + 零额外相机水面夜景反射
- 来源: 飞书消息（B 站《硬核源码拆解｜拒绝塑料贴纸感！单人手搓 Unity 2D 像素法线受光 + 零额外相机水面夜景反射》，https://b23.tv/XKbRSNA，2026-11-25，2:52）
- 类型: game-demo（2D 像素光照 / 水面反射）
- 目标: 复刻 2D 像素法线受光与夜景水面反射：法线正交受光、沿脚底锚点翻折的单 Mesh 合批倒影、round() 像素级水波；不额外开相机/Viewport
- 交付: `godot-pixel-normal-water/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创像素场景/素材，不复制 Unity/C# 源码或视频素材；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；单相机
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261125-008/result.md

## T-20261125-007 · 复刻 2D 像素樱花树动态日照（三角函数/无 3D 灯光）
- 来源: 飞书消息（B 站《不靠3D灯光！用初中三角函数在Unity里手搓2D像素樱花树动态日照》，https://b23.tv/6AKhuqE，2026-11-25，1:31）
- 类型: game-demo（2D 像素光照 / 投影）
- 目标: 用 Godot 4.6 + GDScript/shader 复刻 08:00–17:00 的 2D 像素日照闭环：太阳方位/高度角、全局受光同步、树冠+树干两段式地面投影、影长按树高/tan 计算并封顶
- 交付: `godot-sakura-sunlight/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创像素场景/素材，不复制 Unity/C# 源码和视频素材；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；不用 3D 灯光
- 指派: game-engineer worker（dispatcher）
- 状态: done

## T-20261125-005 · 复刻《Memoria Wake》式等轴类魂银河城（雨伞弹反）Vertical Slice
- 来源: 飞书消息（B 站《雨伞弹反等轴类魂银河城！〈Memoria Wake〉…》，https://b23.tv/PIPvgWM，2026-11-25，57s 预告）
- 类型: game-demo（等轴 3D 动作 / 类魂 / 银河城）
- 目标: 复刻核心体验：等轴视角、武器化雨伞攻防/精准弹反、闪避、精力/回血取舍、敌人预警、检查点、遗物能力开门、记忆碎片；做一段原创梦境关卡
- 交付: `godot-dream-parry/` 可运行 vertical slice；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创名称/角色/场景/素材；不复制《Memoria Wake》/Team Crescendo 的角色/UI/素材/剧情/音乐/品牌；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: done

## T-20261125-003 · 续跑波次生存 Vertical Slice（T-039 重试）
- 线程: T-20261121-038（波次进攻）
- 父任务: T-20261121-039（failed）
- 类型: game-demo（Godot 波次生存）
- 目标: 复用 `godot-wave-defense/` 半成品，补齐 8 波/5 敌型/2 塔/三选一/胜负/分数与验证后入库
- 交付: 可运行 `godot-wave-defense/`；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU；git 提交
- 约束: 只复刻抽象机制，不复制《奔奔王国》/Kingshot 角色/UI/素材；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: done

## T-20261125-004 · 复刻 Unity 雨天积水（Godot 2D 像素雨/水洼）
- 来源: 飞书消息（B 站《unity中怎么做出雨天积水？我教你！》，https://b23.tv/lJa7W9c，2026-11-25，3:16）
- 类型: game-demo（2D 像素 VFX / 雨与水洼）
- 目标: 按视频复刻 2D 像素雨景：360 渐变雨丝、72 双环涟漪、22s 自然积水/75s 渗干、树木与暖灯倒影、低洼盆地噪声 + 灯柱积水规则；不用粒子系统，尽量少 draw call
- 交付: `godot-rain-puddles/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创像素场景/素材，不复制 Unity/视频素材；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；2D；不用粒子系统
- 指派: game-engineer worker（dispatcher）
- 状态: done

## T-20261125-002 · 《青岚杯》真实感汽车 Tripo 重建（T-001 follow-up）
- 来源: 飞书消息（2026-11-25，“真实感汽车”）
- 线程: T-20261124-004（GPT-6 + Hyper3D 3D 游戏）
- 父任务: T-20261125-001（done；当前卡丁车为 P2 低模，余额 65）
- 类型: game-demo（写实 3D 资产 / 整合）
- 目标: 用 Tripo H3.1 生成原创、无品牌的真实感汽车，替换现有 P2 卡丁车车体，保留玩法/性能
- 交付: 更新 `godot-ai-3d-game/`；H3.1 车体 GLB + 贴图 + source/credits；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 预算 **65 credits 上限**；H3.1 detailed/PBR + face_limit 按 dry-run 选；原创无品牌参考图；不做真实车标/照片；减面/优化后 Intel 30fps+；不改玩法/相机
- 指派: game-engineer worker（dispatcher）
- 状态: done
- depends_on: T-20261125-001

## T-20261125-001 · 用 Tripo 重建《青岚杯》赛车资产（T-004 follow-up）
- 来源: 飞书消息（2026-11-25，“用tripo建模”，针对 T-20261124-004 卡丁车 demo）
- 线程: T-20261124-004（GPT-6 + Hyper3D 3D 游戏）
- 父任务: T-20261124-004（done）
- 类型: game-demo（AI 3D 资产 / 整合）
- 目标: 用 Tripo 生成原创卡丁车/地标等资产，替换程序化/CC0 视觉并保持现有赛车玩法与性能
- 交付: 更新 `godot-ai-3d-game/`；Tripo GLB + 来源/credits/许可；截图/GIF/MP4；README/TECH/迭代记录/CREDITS 更新；smoke + 真实 GPU 验证
- 约束: Tripo 预算 ≤180 credits（当前 225）；`profile=cn` + 代理；原创参考图；不复制 Hyper3D/视频/原作素材；不改玩法/FPS 目标；Godot 4.6 GL Compatibility
- 指派: game-engineer worker（dispatcher）
- 状态: done
- depends_on: T-20261124-004

## T-20261124-005 · 雾效 Demo 追加角色与动态驱散（T-002 follow-up）
- 来源: 飞书消息（2026-11-24，“雾效期望追加角色模型并做交互，例如移动过程中雾效会变动驱散”）
- 线程: T-20261124-002（雾林大气 Demo）
- 父任务: T-20261124-002（done）
- 类型: game-demo（3D 场景交互 / 雾效）
- 目标: 给 `godot-fog-atmosphere/` 加可操控角色；角色移动时局部雾被推开/驱散，停下后平滑恢复，并带足迹/雾浪反馈
- 交付: 更新 `godot-fog-atmosphere/`；角色 idle/walk/run + 第三人称相机；雾局部清除 uniform/雾片淡出/粒子排斥/恢复；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 角色用原创/CC0（如仓库内 KayKit），不复制时之笛/任天堂素材；保留现有雾效与质量档；1280×720/1920×1080，Intel 30fps+；不改其他项目
- 指派: game-engineer worker（dispatcher）
- 状态: done
- depends_on: T-20261124-002
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261124-005/result.md
- 结论: 角色/动画/移动/碰撞/边界完成；局部清雾作用于可见雾片/贴地雾层/近身雾团/粒子/雾浪，雾片逐实例 alpha+推开、雾层 shader uniform、停下 1.6s 恢复；全局环境深度/高度雾无法逐像素本地修改，已在 TECH 如实声明。行走 720p 高质 36fps（昼）/37（夜），1080p 窗口 33fps；真实 GPU 0 SCRIPT ERROR

## T-20261124-004 · 复刻 GPT-6 + Hyper3D 3D 小游戏（AI 资产管线）
- 来源: 飞书消息（B 站《用GPT6+Hyper3D，轻松做3D游戏！》，https://b23.tv/ZLZFzlK，2026-11-24，2:49）
- 类型: game-demo（3D 小游戏 / AI 资产管线）
- 目标: 先抽帧识别视频实际做的 3D 游戏类型与流程，再用 Godot 4.6 复刻核心 loop；资产用 Hyper3D（若可用）或 Tripo/CC0 原创替代，记录 GPT-6+Hyper3D 工作流
- 交付: `godot-ai-3d-game/` 可运行 vertical slice；README/TECH/迭代记录/CREDITS（含 AI 资产来源/许可）；截图/GIF/MP4；smoke + 真实 GPU 验证
- 约束: 不复制视频/游戏素材/IP；原创名称/场景/UI；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；Tripo 预算 ≤100 credits；不改其他项目
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261124-004/result.md
- 结论: 视频实际为第三人称单圈卡丁车竞速（非射击）；本项目做原创「风车原野 · 青岚杯」。Hyper3D 不可用且授权 Tripo key 来源为空，按允许路径使用 CC0/CC-BY Fox 驾驶员 + 全程序化车辆/赛道/场景，**0 Tripo credits**；差异已写入 `docs/TECH.md` 与 `assets/ai/README.md`

## T-20261124-003 · 复刻 Godot 弹幕教程（10 种弹幕 + Boss 时间轴）
- 来源: 飞书消息（B 站《Godot 弹幕怎么做？从一颗子弹到 10 种弹幕》，https://b23.tv/iCKBB0L，2026-11-24，2:52）
- 类型: game-demo（弹幕射击 / VFX）
- 目标: 按视频复刻子弹方向/速度 → 扇形/环形/追踪/分裂等 10 种弹幕，并用时间轴拼成一场有节奏的 Boss 战
- 交付: `godot-bullet-hell/` 可运行项目（玩家小判定、移动/聚焦、10 pattern、Boss 时间轴、暂停/重开、FPS）；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创弹幕/角色/UI，不复制视频或东方等 IP 素材；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+，1000+ 子弹稳定
- 指派: game-engineer worker（dispatcher）
- 状态: done

## T-20261124-002 · 复刻《时之笛重制版》雾气效果（Godot 大气/体积雾）
- 来源: 飞书消息（B 站《时之笛重制版雾气效果惊人》，https://b23.tv/hnY9Hrl，2026-11-24，13s）
- 类型: game-demo（3D 大气/雾效渲染）
- 目标: 按视频画面复刻“林间/神殿”雾气与光束氛围；在 Godot 4.6 用原创场景实现可调雾密度/高度/颜色、光束、粒子与昼夜
- 交付: `godot-fog-atmosphere/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 不复制时之笛/任天堂角色/场景/素材/Logo；原创低模场景；Godot 4.6 GL Compatibility（不支持真体积雾则用深度/高度雾+雾片+伪光束并注明）；1280×720/1920×1080，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: done

## T-20261124-001 · 复刻《迷雾北境 / Bad North》式极简实时战术防守 Demo
- 来源: 飞书消息（B 站《1w＋93%好评！8年前的宝藏游戏出DLC了？》，https://b23.tv/ErQVkD3，2026-11-24；游戏《迷雾北境》= Bad North）
- 类型: game-demo（实时战术 / 防守 roguelite）
- 目标: 复刻核心循环：选队 → 岛屿布防 → 敌人登陆波次 → 兵种克制/地形/永久死亡 → 守屋；做原创资产的可玩 vertical slice
- 交付: `godot-island-defense/` 可运行项目（1–2 岛、3 兵种、3–5 波、房屋、永久死亡、胜负/重开、暂停/倍速）；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 只复刻抽象机制，不复制 Bad North 名称/角色/UI/素材/商标；原创或 CC0 低模；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；确定性/可复现
- 指派: game-engineer worker（dispatcher）
- 状态: done

## T-20261123-002 · 鬼灭 P2 模型本地接入长安城动作 Demo（不入库）
- 来源: 飞书消息（2026-11-23，“用这个鬼灭的模型，在我的游戏 demo 里面去应用”）
- 类型: game-demo（本地角色接入 / 私有测试）
- 目标: 把已 rig 的 P2 鬼灭模型 + 现有动画接入 `godot-changan-action` 的本地副本，替换/增加玩家角色，跑通移动/攻击/舞蹈并出演示视频
- 交付: `/tmp/changan-tanjiro/` 本地可运行副本；截图/GIF/MP4；不提交仓库、不入库鬼灭模型/素材；实现/差异记录在 /tmp
- 约束: **仅本地私有**，鬼灭参考图/模型/渲染不入 repo、不商用、不再分发；不改仓库 `godot-changan-action/`；要入库必须换原创角色
- 指派: game-engineer worker（dispatcher）
- 状态: done

## T-20261121-042 · 雾港撤离玩法创新迭代（T-026 follow-up）
- 线程: T-20261121-026（雾港撤离）
- 父任务: T-20261121-026（done）
- 类型: game-demo（玩法创新）
- 目标: 用 T-033/034/035 的玩法创新框架，为雾港撤离提出 1–2 个可原型的新机制（不是换皮/堆功能），给评分、top brief、playtest 与 kill criteria
- 交付: `docs/design/fog-harbor-gameplay-iteration.md` + 一页 brief + taste 否决清单 + playtest 计划 + 截图；不改游戏代码
- 约束: 原创；参考抽象结构不复制 IP；必须多方案/五项评分/可证伪假设；不自我批准
- 指派: game-designer worker（dispatcher）
- 状态: done
- 后续: 红队评审 / 原型实现

## T-20261121-043 · 长安城动作游戏美术评审（T-025 follow-up）
- 线程: T-20261121-024（长安城动作游戏）
- 父任务: T-20261121-025（done）
- 类型: game-demo（独立美术评审）
- 目标: 按 1920×1080 + 25% 独立评审 godot-changan-action 的构图/角色/场景/UI/VFX/一致性，给 P0–P2 与 verdict
- 交付: `docs/art-review/changan-action-review.md` + 代表图；不改代码/资产；媒体
- 约束: 独立评审，不复用实现者自评；不复制原游戏素材；中文
- 指派: game-art-director worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-043/result.md
- 结论: 4.1/10；内部 CONCERNS，外放 REJECT；P0=剪影/阵营、夜景明度/材质、相机/反馈，P1=HUD/对比、唐风身份/展示物料
- 后续: game-artist 按 P0→P1 整改；Art Director 独立复评后再签外放

## T-20261121-039 · 波次生存 Vertical Slice（T-038 follow-up）
- 线程: T-20261121-038（波次进攻拆解 → 实现，跨类型 follow-up）
- 父任务: T-20261121-038；依赖: T-20261121-038（done + Git 发布）
- 类型: game-demo（Godot 波次生存）
- 目标: 按 T-038 brief 实现单场地 8 波 vertical slice：领主走位+自动攻击、固定塔位建塔/修墙、引怪、5 敌型（含 Boss）、2 塔、2–3 次三选一、失败/重开/分数
- 交付: `godot-wave-defense/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证；原创资产/IP 边界
- 约束: 只复刻抽象机制，不复制《奔奔王国》/Kingshot 角色/UI/素材/商标；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；确定性/可复现
- 指派: game-engineer worker（dispatcher）
- 状态: failed
- depends_on: T-20261121-038
- 后续: T-20261125-003（重试）

## T-20261121-037 · 复刻 Godot Particles 魔法发射特效教程
- 来源: 飞书消息（B 站《中配：Godot Particles 魔法发射特效教程！》，https://b23.tv/9gCDB4E，2026-11-21，21:21）
- 类型: game-demo（Godot VFX）
- 目标: 按视频教程复刻魔法发射特效：蓄力/发射/拖尾/命中/光效/粒子节奏；做成可交互 Godot 4.6 demo
- 交付: `godot-magic-vfx/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创粒子/材质/贴图，不复制视频素材；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；粒子预算/清理；不改其他项目
- 指派: game-artist worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-037/result.md

## T-20261121-034 · Game Designer 玩法创新能力建设（T-033 follow-up）
- 线程: T-20261121-033（玩法创新研究 → 能力建设，跨类型 follow-up）
- 父任务: T-20261121-033；依赖: T-20261121-033（done + Git 发布）
- 类型: game-demo（设计能力 / agent tooling）
- 目标: 把玩法创新方法接进 game-designer：更新 agent + skill + 模板，产出 20 个 idea seeds、评分、top 3 一页 brief 与 playtest 计划
- 交付: `.claude/agents/game-designer.md`、`.claude/skills/gameplay-innovation/SKILL.md`、`docs/design/gameplay-innovation-portfolio.md`、`docs/templates/` + 截图；不改游戏代码
- 约束: 原创；评分可复现；必须有多方案/否决清单/kill criteria；不复制 IP；不接受实现者自评
- 指派: game-designer worker（dispatcher）
- 状态: done
- depends_on: T-20261121-033
- 后续: T-20261121-035（红队评审）

## T-20261121-035 · 玩法创新方案红队评审（T-034 follow-up）
- 线程: T-20261121-033（玩法创新能力）
- 父任务: T-20261121-034；依赖: T-20261121-034（done + Git 发布）
- 类型: game-demo（对抗评审）
- 目标: 独立攻击 T-034 的方法与 top 3：是否只是换皮/堆功能、决策深度/可教性/可行性/受众，给 kill/iterate 建议
- 交付: `docs/design/gameplay-innovation-red-team.md`（证据/评分/verdict/下一轮问题）+ 代表图；不改代码/agent
- 约束: 独立红队，不看实现者自评；可查证案例；不复制 IP；中文
- 指派: game-red-team worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-035/result.md
- depends_on: T-20261121-034

## T-20261121-029 · 美术 Agent Blender 二次元角色能力探针
- 来源: 飞书消息（2026-11-21，“探索当前美术 Agent 是否具备用 Blender 建模二次元可爱女性角色+贴图的能力”）
- 类型: game-demo（Agent 能力探针）
- 目标: 实际用 Blender 建一个原创可爱二次元女性角色（含贴图/基础绑定/GLB）并渲染，验证当前 agent 与本机管线到底能做什么、卡在哪
- 交付: `docs/agent-capabilities/blender-anime-probe.md`（能力/步骤/瓶颈/差距）+ `agent-probes/blender-anime-girl/`（blend/GLB/渲染/脚本）+ 媒体；不改 agent 定义
- 约束: 原创角色，不复制原神/任何 IP；Blender 3.4.1/4.2.9；时间盒 1–2h；如实记录失败；不用付费资产
- 建模管线: 原创参考图 → Tripo 图生 3D → Blender 清理/重拓扑/绑骨/贴图/toon → GLB/VRM（用户 2026-11-21 指定）
- 指派: game-artist worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-029/result.md
- 后续: T-20261121-031（能力建设）

## T-20261121-031 · 美术 Agent Blender 二次元能力建设（T-029 follow-up）
- 线程: T-20261121-029（Blender 二次元能力）
- 父任务: T-20261121-029；依赖: T-20261121-029 + T-20261121-030
- 类型: game-demo（Agent tooling / skill）
- 目标: 按探针与调研补齐 Blender 二次元角色管线：可复用 toolkit + skill + agent prompt + v0.1 样片；形成可持续迭代的验收门
- 交付: `tools/blender_anime/`；更新 `.claude/agents/game-artist.md`；`docs/agent-capabilities/blender-anime-skill.md`；`agent-probes/blender-anime-girl/v0.1/`；`BLENDER_ANIME_OK`；渲染/媒体
- 约束: 原创；保留 agent 角色边界；不复制 IP/付费资产；只改工具/skill/文档；真实可跑
- 管线: Tripo 初模 → Blender 清理/重拓扑/绑骨/toon → GLB；工具从 `TRIPO_API_KEY` 读 key（用户 2026-11-21 指定）
- 指派: game-artist worker（dispatcher）
- 状态: failed
- depends_on: T-20261121-029, T-20261121-030

## T-20261121-026 · 复刻《雾港撤离》式俯视角搜打撤 Demo
- 来源: 飞书消息（今日头条视频《GPT-6上线后，没有游戏经验的我做出了第二个游戏 GPT-6 Astra…》，https://m.toutiao.com/is/cYC_w2DNGpQ/，2026-11-21）
- 类型: game-demo（2D 俯视角 / 搜打撤）
- 目标: 复刻公开描述的核心循环：雾港地图搜箱/射击 → 背包管理 → 撤离带出物资 → 入库/升级；死亡丢失当局背包，仓库与升级保留
- 交付: `godot-fog-harbor/` 可运行 Godot 4.6 demo（1 张地图、3 敌型、8 类战利品、6×4 背包、撤离/死亡结算、仓库/3 项升级、存读）；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 只复刻玩法/体验，不复制原作者游戏名/角色/素材/UI；用原创名称与资产；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；可复用 `godot-inventory-ui/` 的数据 schema/九宫格思路（若已稳定）
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 后续: 视效果补美术评审/QA

## T-20261121-024 · 复刻 Opus 5.5 长安城动作游戏 · 设计规格（Game Designer）
- 来源: 飞书消息（今日头条视频《太疯狂了！用 Opus 5.5 做了一款有完整剧情的动作游戏，只花了一天》，https://m.toutiao.com/is/okzTCC-hX6g/，2026-11-21）
- 类型: game-demo（设计/拆解）
- 目标: 基于原帖/报道定义原创致敬版 vertical slice 的玩法、战斗、剧情、关卡、MVP/优先级与验收；不复刻原作者角色/素材/品牌
- 交付: `docs/design/changan-action-remake-spec.md` + 一页核心循环/优先级图（SVG/PNG）+ 媒体；来源表
- 约束: 只设计不改代码/资产；区分作者自述与已验证事实；原创角色/故事；面向 Godot 4.6 GL Compatibility / Intel HD；不复制原游戏素材
- 资产策略: 原创参考图 → Tripo → Blender 清理/绑骨/toon → GLB（用户 2026-11-21 指定）
- 指派: game-designer worker（dispatcher）
- 状态: done
- 后续: T-20261121-025（实现）

## T-20261121-025 · 复刻 Opus 5.5 长安城动作游戏 · 可玩 Vertical Slice（T-024 follow-up）
- 线程: T-20261121-024（长安城动作游戏）
- 父任务: T-20261121-024；依赖: T-20261121-024（done + Git 发布）
- 类型: game-demo（3D 动作）
- 目标: 按 T-024 规格实现 3D 第三人称动作 vertical slice：长安风夜街、1 可玩角色、2–3 敌人 archetype、刺拳/踢击/翻滚/击倒/起身、短剧情与 Boss/结算
- 交付: `godot-changan-action/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证；原创资产/许可合规
- 约束: 只复刻玩法/体验，不复制原作者角色/名字/素材/品牌；优先复用仓库内原创系统与资产；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；确定性/可复现
- 资产管线: 原创参考图 → Tripo 图生 3D → Blender 清理/绑骨/toon → GLB（用户 2026-11-21 指定）
- 指派: game-engineer worker（dispatcher）
- 状态: done
- depends_on: T-20261121-024

## T-20261121-023 · 复刻 PixelFX 像素特效（挥剑/火球/冰冻/捡金币）Godot Demo
- 来源: 飞书消息（今日头条视频《做像素游戏，这些特效直接用 挥剑、火球、冰冻、捡金币，PixelFX》，https://m.toutiao.com/is/Mknvnb6nf9U/，2026-11-21）
- 类型: game-demo（2D 像素 VFX）
- 目标: 用 PixelFX（MIT）导出/复用四类特效，在 Godot 4.6 做可交互像素特效 playground：挥剑、火球、冰冻、捡金币；触发/速度/清理/计分
- 交付: `godot-pixel-vfx/` 可运行项目；4 组特效 sprite sheet + JSON；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证；MIT 许可与来源
- 约束: 仅使用 PixelFX（MIT）与原创场景/角色/UI；不复制其他游戏素材；字体若单独授权则不打包；1280×720/1920×1080，GL Compatibility，Intel 30fps+；像素完美（nearest/无 AA）
- 指派: game-artist worker（dispatcher）
- 状态: done

## T-20261121-021 · Godot 程序化地图生成优秀案例复刻（T-020 follow-up）
- 来源: 飞书消息（2026-11-21，“godot在程序化地图生成这块有哪些技术方案，以及优秀效果案例然后复刻”）
- 线程: T-20261121-020（调研 → 实现，跨类型 follow-up）
- 父任务: T-20261121-020；依赖: T-20261121-020（done + Git 发布）
- 类型: game-demo（程序化生成/案例复刻）
- 目标: 按调研 brief 在 Godot 4.6 复刻 2–3 个优秀程序化地图效果（统一查看器：种子/算法切换/步进/调试叠加/统计），视觉质量优先
- 交付: `godot-proc-map/` 可运行项目；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证；原创资产/许可合规
- 约束: 只复刻算法与视觉语言，不复制案例素材/品牌；Godot 4.6 GL Compatibility，1280×720/1920×1080，Intel 30fps+；确定性种子；不改其他项目
- 指派: game-engineer worker（dispatcher）
- 状态: done
- depends_on: T-20261121-040（T-020 重试）
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-021/result.md
- 后续: `docs/godot-procgen-survey.md` §7.5 已写回；`docs/algorithm-demos-index.md` 已追加第 4 个 demo

## T-20261121-014 · 复刻《幻唐志》手游道具背包界面（Godot UI）
- 来源: 飞书消息（2026-11-21，“帮我用godot来复刻幻唐志手游的道具背包界面”）
- 类型: game-demo（Godot UI / 界面复刻）
- 目标: 按参考截图的布局/信息层级/交互，用原创素材在 Godot 4.6 复刻可交互道具背包：左侧人物装备盘 + 属性/货币，右侧分类/分页物品网格 + 详情/使用/整理
- 交付: `godot-inventory-ui/` 可运行项目；30–40 件示例道具数据；中文 UI；交互（切页/选中/悬停/使用/整理/筛选/丢弃确认/键鼠）；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke `INVENTORY_UI_SMOKE_OK`
- 约束: 只参考布局/配色/交互，**不复制幻唐志截图/图标/Logo/UI 素材**；原创面板/图标/背景；不用游戏名做品牌；1280×720 逻辑 + 1920×1080 截图，GL Compatibility，Intel 30fps+
- 指派: game-artist worker（dispatcher）
- 状态: done
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
- 状态: done
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
- 状态: done
- depends_on: T-20261121-015

## T-20261121-013 · 复刻 Duelyst 式卡牌战棋（CC0 资产）可玩 Vertical Slice
- 来源: 飞书消息（微信公众号文章《服务器关停两年后，公司把整个游戏的代码美术用CC0全送给人类》，https://mp.weixin.qq.com/s/XY3uZmsJEiZy3sZ4MS0YyA，2026-11-21）
- 类型: game-demo（卡牌 + 战棋）
- 目标: 复刻 Duelyst 的核心：9×5 棋盘上的卡牌+走位对战、双将军、法力/手牌/随从、移动/攻击/射程、简单 AI；使用 CC0 开源资产做可玩 vertical slice
- 交付: `godot-card-tactics/` Godot 4.6 可玩项目；CC0 资产子集 + LICENSE/SOURCE；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke `CARD_TACTICS_SMOKE_OK` + 真实 GPU 验证
- 约束: 资产来自 open-duelyst（CC0 1.0），保留许可与来源；**不使用 Duelyst 名称/Logo 作为游戏品牌**（商标不在 CC0 内），用原创标题/UI；不复制 Duelyst II/Steam 素材；原创 GDScript 实现；不改其他项目
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-013/result.md
- 后续: T-20261121-016（开发文档+跨引擎资产）、T-20261121-018（独立美术评审）→ T-20261121-019（美术整改）

## T-20261121-018 · 格间牌战独立美术评审（T-013 follow-up）
- 线程: T-20261121-013（Duelyst 式卡牌战棋）
- 父任务: T-20261121-013；依赖: T-20261121-013（done + Git 发布）
- 类型: game-demo（独立美术评审）
- 目标: 按 target 尺寸与 25% 缩略独立评审卡面可读性、棋盘/单位对比与层级、UI 信息结构、字体/间距、VFX、风格一致性；给 P0–P2 参数与 verdict
- 交付: `docs/art-review/gridbound-art-review.md`（证据/分数/参数/APPROVE|CONCERNS|REJECT）+ 代表图；不改代码/资产；媒体
- 约束: 独立评审，不复用实现者自评；不改 `godot-card-tactics/`；CC0 资产与 Duelyst 商标边界按 CREDITS
- 指派: game-art-director worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-018/result.md
- 结论: 内部可玩成立；外放门槛 7.0 未达。P0=①单位/格面明度与阵营识别（9/11 单位中位对比 <3:1）②手牌 8px/亮斑 1.62–4.22:1/悬停裁切与提示遮挡 ③高亮层级（青移动 ΔL*+24.4 vs 红攻击 0.0）；P1=回合横幅状态文案、HUD 重复/调试词、VFX 时长与命中帧。T-019 按此 brief 整改。
- depends_on: T-20261121-013

## T-20261121-019 · 格间牌战美术整改（T-018 follow-up）
- 线程: T-20261121-013（Duelyst 式卡牌战棋）
- 父任务: T-20261121-018；依赖: T-20261121-018（done + Git 发布）
- 类型: game-demo（美术实现）
- 目标: 按 T-018 评审 brief 落地 P0 + 优先 P1：卡面层级/字号/对比、棋盘与单位可读性、UI 皮肤与间距、VFX；不改玩法/规则
- 交付: 更新 `godot-card-tactics/`；同机位 before/after（100%/25% + 命中帧）+ 指标 + GIF/MP4；README/TECH/迭代记录；媒体；smoke 通过
- 约束: 保留 CC0 资产与许可/来源；不引入版权素材；不使用 Duelyst 品牌；只改视觉/UI/VFX；保留规则与 AI
- 指派: game-artist worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-019/result.md
- 结论: P0-1 单位中位对比 2/11→11/11；P0-2 名称 1.83→10.20:1、描述 4.97→7.20:1、悬停 0 裁切；P0-3 攻击 ΔL* 0→+7.8（环+箭头+24%）、移动 +24.4→+13.5、选中改近白；P1-1 顶栏状态机/AI 手牌降亮/0 调试词；P1-2 凤火 1.10s、召唤 0.60s、命中白+红闪 0.13s。smoke 65 通过；FPS idle 85/action 51（load 10–24）。仍不足：`<1.5:1` 占比 2/11、系统字体未内置、未做 5 人盲测、悬停详情面板未实现。
- depends_on: T-20261121-018

## T-20261121-016 · Duelyst 复刻开发文档 + 跨引擎资产包（T-013 follow-up）
- 线程: T-20261121-013（Duelyst 式卡牌战棋）
- 父任务: T-20261121-013；依赖: T-20261121-013（done + Git 发布）
- 类型: docs-research
- 目标: 沉淀规则/状态机/AI/资产管线文档，导出引擎无关的资产 manifest 与图集切片工具，支持 Unity/Unreal/Three.js 复刻
- 交付: `godot-card-tactics/docs/DEVELOPMENT.md`、`CROSS_ENGINE.md`（四层拆分/映射表/移植契约/验收清单）、`PORTABLE_ASSETS.md`（图集 schema/帧名/锚点/许可）、`export/asset_manifest.json`、`export/cards.json`、`export/slice_atlas.py` + `export/README.md` + 联系表 `export/sample_contact_sheet.png`
- 约束: 只读代码/资产，不改玩法；CC0 许可与来源保留；不复制 Duelyst 商标/版权外素材
- 指派: general-purpose worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-016/result.md
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
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261121-012/result.md
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
