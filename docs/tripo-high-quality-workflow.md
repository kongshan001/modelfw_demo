# Tripo 高质量图生 3D 工作流：外部调研 + 私有技术测试

- 任务：T-20261121-045（game-artist）
- 日期：2026-11-23
- 工具：Tripo CLI 0.11.2（API v3，`profile=cn`）、Blender 3.4.1、Pillow 12.2.0
- 测试性质：**私有、一次性、非商用**。参考图与衍生 GLB 仅存放在 `/tmp/tripo-demon-slayer/`，**不提交仓库、不再分发、不进入任何项目资产**。

## 0. 结论先行（TL;DR）

1. **两个候选都成功，实际共花 185 credits**：P2 125（生成 120 + 转换 5），H3.1 60；预算 250，账户余额 485 → 300。
2. **P2（game-pc 预设，5,096 tris，125 credits）**：轮廓、箱子和羽织棋盘格可辨认，适合**远景 NPC / 概念验证**；但手是连体手套、刀是薄片且位置错误、耳饰与发丝糊在一起、脸完全靠贴图，近景/绑定不合格。评分 **5.5/10**（远景 7/10，近景 3/10）。
3. **H3.1（film 预设 + detailed 几何 + PBR，60 credits）**：面数、五官、发丝、服装褶皱、贴图质量明显高于 P2，适合**展示 / 概念评审 / 3D 打印起点**；但 GLB 66.4MB、高面数，必须重拓扑后才能进游戏，手/刀/耳饰仍有瑕疵。评分 **7.3/10**（展示 7.5/10，直接进游戏 4/10，重拓扑后 6.5/10）。
4. **真正决定质量的是输入图与后处理，不是 seed**：单图 3/4 全身、纯色底、1024+、A-pose、无遮挡；角色优先多视图（至少正面 + 背面），或先生成 3D 友好转面参考。平涂赛璐璐插画缺少深度线索，细长部件（发梢、刀、耳饰）最容易断裂/融合（Figmee 经验，本次实测吻合）。
5. **推荐可复用管线**：原创参考图（front/3q/back）→ 去背/裁切/正方形 1024+ → Tripo H3.1 首轮（`face_limit=50000–100000`、PBR、texture detailed、多 seed）→ 360° 检查 → Blender 重拓扑/UV/贴图/绑骨/toon → GLB/VRM。P2 用于低模探索和远景资产。
6. **预设 ≠ 规格**：`--for game-pc` 不会自动设置 `face_limit`（本次 P2 自适应只有 5,096 tris），也不会自动开 PBR；必须显式传参。GLB 不能存 quad，`quad=true` 会强制 FBX；要四边形就导出 FBX。完整命令见 §3。

---

## 1. 外部调研：官方说明 vs 社区经验

> 标记：**[官方]** = Tripo 官方文档/帮助中心/CLI 文档；**[社区]** = 第三方教程/独立评测；**[本次]** = 我们的实测。访问日期均为 **2026-11-23**。

### 1.1 输入图要求

| 主题 | 官方说明 | 社区经验 | 本次结论 |
|---|---|---|---|
| 主体数量 | 一张图一个主体；多主体会被合并成一个 mesh [官方 O1] | 同左；复杂背景会让角色和背景融合 [社区 C1] | 只放一个角色 |
| 构图 | 主体占画面 **70–85%**，居中，四周留干净边距；全身不要出框 [官方 O1] | 全身完整，刀尖/脚/披风边缘都要在画面内；“切掉的细节等于浪费输入” [社区 C1/C5] | 我们做到 85% 高、居中 |
| 背景 | 纯色底，白/浅灰最好；避免渐变、反光、复杂背景 [官方 O1] | 去背/抠图后再上传；背景色会渗进贴图 [社区 C1/C2] | 官方图自带 alpha，直接合成白底 |
| 分辨率 | 目标 **1024×1024 以上**；低于 512 几何会糊 [官方 O1]；API 最低要求 256×256、≤20MB [官方 O2] | 用原图不要二次压缩；JPEG 压缩噪点会被当成表面细节 [官方 O1] | 源图人物高 1165px，输出 1024² |
| 光照 | 均匀柔光；避免硬阴影/高光，否则会被烘进贴图 [官方 O1] | 硬光会把颜色和明暗画进材质，后期难救 [社区 C2] | 官方立绘本身平光，适合 |
| 视角/姿态 | 正面或轻微 3/4、平视；角色用放松 A-pose（绑定）或 T-pose；手臂离开身体 [官方 O1] | A-pose 对绑定最友好；姿势必须在图里，Tripo 的 Pose 选项只对文生 3D 生效 [社区 C1] | 本次是 3/4、非 A-pose，手在胸前 → 手部融合 |
| 遮挡 | 避免严重遮挡；被挡住的背面只能靠猜 [官方 O1] | 单图会猜背面；背面细节错是常态 [社区 C2] | 箱子和手遮挡胸/背，背面被猜 |
| 文字/水印 | 官方清单未单列文字；主体清晰、无干扰 [官方 O1] | 文字/Logo 可能被当成几何或贴图 [社区 C2] | 选图时排除水印（最终图为官方透明立绘） |

### 1.2 单图 vs 多视图

- **[官方 O3]** 多视图接口接受 2–4 张（front/left/back/right），**front 必填**，所有视图需同一光照；多角度能提高几何精度和贴图覆盖。
- **[官方 O1]** 单图靠深度/体积/表面朝向估计；多视图重建真实几何；角色如果背面重要，至少加一张背面图。
- **[社区 C1/C2]** 角色、载具、要绑定或特写的资产优先多视图；视图之间比例/光照/姿势要一致，否则会更乱。
- **[本次]** 单图 + 箱子 + 手在胸前 → 手和刀明显是“猜”的；下一轮至少 front + back 两视图。

### 1.3 模型版本与预设

| 模型 | 官方定位 | 面数/价格（官方 CLI 文档） | 社区经验 |
|---|---|---|---|
| **H3.1**（v3.1-20260211） | 高精度几何，最佳质量，支持 H-only 参数：`geometry_quality=detailed`（+20）、`smart_low_poly`（+10）、`generate_parts`（+20）、`quad`（+5）[官方 O4/O5] | 图生 3D **20–50 credits**（按贴图档）+ 附加项；最大 1.5M 三角面（detailed 2M）[官方 O2/O5] | 默认输出 1.41–1.49M 三角面，直接进游戏太重；50k 限制下 45.7k–48.8k；适合 hero/展示/打印 [社区 C3] |
| **P2**（P2-20260801） | 默认模型；可编辑低模拓扑；面数 48–50,000 tri / 48–25,000 quad；**不支持** `geometry_quality`/`smart_low_poly`/`generate_parts` [官方 O4/O5] | **100–130 credits**（按贴图档）[官方 O5] | 默认 4,445–5,474 tris；简单形体干净，细小部件弱；quad 适合绑定 [社区 C3]；20k 限制实测 P2 超 794 tris（3.97%），H3.1 18,834 [社区 C4] |
| P1 | 更低成本低模，face_limit 50–20,000，无 quad/quality [官方 O4] | 官方未标价（CLI 不预估）[官方 O5] | 用于移动端/预算极紧场景 |

- **[官方 O5]** 场景预设：`game-mobile / game-pc / film / print / ar-web / anim / toy`。预设只改参数、处理链和交付格式，**不会改变默认模型**；要 H3.1 必须显式 `--model tripo-v3.1`。
- **[本次]** `--for game-pc` 生成参数是 `texture_quality=detailed, pbr=false`，并追加 FBX 转换；`--for film` 默认 `quad=true` → 强制 FBX。预设不是质量档位，参数要逐项确认。

### 1.4 贴图 / PBR / face_limit

- **[官方 O2]** `texture_quality`: `fast / standard / detailed / extreme(8K)`；`pbr=true` 会强制 `texture=true`，输出 base_color、metallic、roughness、normal；API 默认 PBR=true，但 **CLI 默认发送 pbr=false**，要显式开。
- **[官方 O2]** `face_limit`：游戏资产建议 **50,000–100,000**；Web/移动 10,000–50,000；省略则自适应（本次 P2 自适应约 5k）。
- **[官方 O2]** `delight`：贴图前去掉参考图光照；v3.5 贴图下显式指定版本才默认 true，否则默认 false。平涂插画建议保留原明暗（本次 `delight=false`）。
- **[社区 C1]** face_limit 是“上限”不是精确值：请求 5,000 面，P2 返回 6,160 面（quad）；低于约 150/250 面质量会崩。
- **[社区 C3/C4]** 50k 限制下 H3.1 更守预算，P2 可能小幅超限；**下载后必须自己数三角面**，不能只看请求参数。

### 1.5 Seed / 重试 / 失败处理

- **[官方 O2]** `model_seed`（几何）、`texture_seed`（贴图）、`image_seed`（2D）可复现；相同 seed + 相同输入 → 相同结果。
- **[官方 O5]** CLI `-n/--candidates 2` 可并行多 seed 候选；`tripo redo <task>` 用新 seed 重跑（新付费任务）；失败/取消任务自动退款；网络失败不要重复提交，用 `task get <id> --download` 续传。
- **[社区 C1]** 一次只改一个变量（图/姿势/seed），不要同时改材质、发型、构图。
- **[本次]** 首轮只跑了 1 个 seed/模型；下一轮建议同一输入跑 2 seeds，挑手/刀更好的那个。

### 1.6 后处理（Blender）

- **[官方 O1]** 角色可把身体和衣服分开生成，几何更干净、绑定更容易；3D 打印可先用白色素模截图再图生 3D。
- **[社区 C1]** 高模先重拓扑/减面再绑定；P2 quad 更适合变形；检查肩、肘、膝权重。
- **[社区 C5]** AI 结果是“可评审候选”，不是生产批准；重拓扑、UV、贴图、绑定、动画是后续独立工序。
- **[本次]** 用 Blender 3.4.1 做 8 视角转台 + front/3q/back 1024 渲染 + clay + 剪影，作为验收证据；未做重拓扑/绑骨（不在本轮范围）。

---

## 2. 参考图与预处理

### 2.1 参考图

- 来源：**TV 动画《鬼灭之刃》官方门户 kimetsu.com** 的全身角色立绘（角色：灶门炭治郎）。
- URL：`https://kimetsu.com/anime/portal/assets/img/chara/full/img_chara_full_1.png`（访问 2026-11-23）。
- 原始文件：2020×1200 PNG，带 alpha；人物实际包围盒 **524×1165**；正面偏 3/4、全身、无文字/水印、透明底。
- 为什么选它：官方来源、全身、清晰、无遮挡边、无 Logo；比官方新闻页的场景截图更适合图生 3D。
- **IP 边界**：该文件只存在 `/tmp/tripo-demon-slayer/ref/`；不进入仓库、不用于商业、不再分发。

### 2.2 预处理步骤（Pillow 12.2.0）

1. 读取带 alpha 的 PNG，`getbbox()` 去掉四周空白：2020×1200 → **524×1165**。
2. 计算目标：1024×1024 白底，人物高度占 **85%**（870px）。
3. 等比缩放：524×1165 → **391×870**（LANCZOS）。
4. 居中合成到 1024×1024 纯白画布：x=316，y=77。
5. 输出 `prep/tanjiro_1024_white.png`（299KB，RGB）；另存透明裁剪 `prep/tanjiro_transparent_crop.png` 作记录。
6. 未使用 rembg：原图自带 alpha，直接合成白底，避免抠图边缘误差。

自检：主体高度 870/1024 = 85%，居中，白底，无文字/水印；符合官方 70–85% 与 1024+ 建议。参考图中的木箱和刀也被保留——这会诱导模型把箱/刀当主体的一部分，是本次手/刀 artifact 的原因之一。

---

## 3. 生成命令、参数与成本

环境：Tripo CLI 0.11.2，`--profile cn`，所有命令加 `HTTPS_PROXY/HTTP_PROXY=http://127.0.0.1:7897`。API key 只在 `~/.tripo/config.json`，未写入仓库/日志。

### 3.1 候选 A：P2 / game-pc（低模游戏路线）

```bash
npx tripo-cli make prep/tanjiro_1024_white.png \
  --for game-pc --then convert:gltf \
  --profile cn -o out/p2 --name tanjiro-p2 --json
```

- Dry-run：`valid=true`，预估 **120 credits**；生成参数 `texture=true, texture_quality=detailed, pbr=false, model=P2-20260801`；`convert:gltf` 覆盖预设的 FBX 链。
- 实际：**125 credits**（image_to_model 120 + convert_model 5）。
- 任务 ID：`acd1b6ba-407b-4a71-a19c-01ce96904c91`（生成）、`116f8545-e5b1-4f0c-b847-81bfc60d1e81`（GLTF 转换）。
- 产物：`out/p2/tripo-out/tanjiro-p2-convert-116f8545/model.glb`，**3.0MB**。

### 3.2 候选 B：H3.1 / film + detailed（高精度路线）

```bash
npx tripo-cli make prep/tanjiro_1024_white.png \
  --for film --model tripo-v3.1 \
  -p geometry_quality=detailed -p pbr=true -p texture_quality=detailed -p quad=false \
  --profile cn -o out/h31 --name tanjiro-h31 --json
```

- Dry-run：`valid=true`，预估 **60 credits**；`quad=false` 关闭 film 预设默认的 quad（否则强制 FBX），直接交付 GLB。
- 实际：**60 credits**。
- 任务 ID：`64d78c69-1d4b-40f8-89e5-8f9a3d1542eb`。
- 产物：`out/h31/tripo-out/tanjiro-h31-64d78c69/model.glb`，**66,439,016 bytes（66.4MB）**。
- 下载：代理单连接约 43KB/s，且多次中途断开；本次改为 **8 路 HTTP Range 续传**（每段独立重试/校验字节数），约 15 分钟完成。生成本身约 2 分 15 秒。大文件下载是 H3.1 的实际工程成本。
- 完整性校验：文件字节数必须等于 CDN `content-length`，文件头应为 `glTF`（`67 6c 54 46`）；本次曾出现 4MB 半截文件，Blender 报 `Bad GLB: file size doesn't match`。

### 3.3 成本汇总

| 项目 | P2 | H3.1 | 合计 |
|---|---|---|---|
| 生成 | 120 | 60 | 180 |
| 转换 | 5 | 0 | 5 |
| **实际** | **125** | **60** | **185** |
| dry-run 预估 | 120（+转换） | 60 | 180 |
| 预算 | 250 | — | 余额 485 → **300** |

结论：**在 250 credits 预算内完成了 2 个候选**，H3.1 的单位成本只有 P2 的 48%，但文件/面数是另一个量级。

---

## 4. 渲染与评估方法

- Blender **3.4.1**（`/Applications/Blender.app`），EEVEE Legacy；Intel 集显可稳定输出，未用 4.2 的 EEVEE Next。
- 导入 GLB → 统一缩放到高度 2.0、脚底 z=0、XY 居中 → 正交相机 (`ortho_scale=2.3–2.45`)。
- 灯光：3 盏 Area（key 420W / fill 180W / rim 300W），世界灰 0.82，地面浅灰。
- 视角：先 8 张 512² 转台（每 45°）确认朝向；本次模型朝 **+X**，因此 **front=90°、3/4=135°、back=270°**。最终 front/3q/back **1024²**；另有 clay 素模、alpha 剪影、8 帧转台。
- 颜色管理 Standard；贴图由 GLB 内嵌（P2 4K base color；H3.1 PBR 套图）。
- 评估维度：剪影、脸/眼、头发、服装、手指、刀/箱/耳饰、贴图、悬浮/破面、拓扑/引擎可用性、成本/体积。
- 渲染文件只在 `/tmp/tripo-demon-slayer/render/`，未入库；代表性图片通过飞书私发。

---

## 5. 结果与评分

> 本节数据来自 Blender 3.4.1 实际导入与渲染；P2：6,837 verts / **5,096 tris** / 1 material / 4096² base color / 无 PBR / 3.0MB；H3.1：1,023,519 verts / **1,971,068 tris** / 1 material / 3×4096² PBR / 66.4MB。渲染图仅私发飞书，未入库。

### 5.1 P2（5,096 tris，125 credits）

| 维度 | 观察 | 分数 |
|---|---|---|
| 剪影 | 箱子、羽织、裤脚可认；袖子与手臂融合，脚部姿态可读 | 7/10 |
| 脸/眼 | 眼睛/嘴靠贴图，远看可认；近看五官平、鼻/嘴有涂抹感 | 5/10 |
| 头发 | 块状发束，部分尖角融合，缺少细发丝 | 5/10 |
| 服装 | 羽织棋盘格与配色还原不错；褶皱硬、绑带简化 | 6.5/10 |
| 手指 | **连体手套状**，没有独立手指 | 2/10 |
| 刀/箱/耳饰 | 箱子在但很薄；刀是薄片且位置错；耳饰只剩小碎片 | 3.5/10 |
| 贴图 | 4K base color，图案清楚；脸部略糊；无 PBR | 6/10 |
| 悬浮/破面 | 未见明显悬浮块；脚底有深色/疑似破洞；**网格 1,029 个连通岛、895 个 ≤10 顶点碎岛、6,546 条非流形/边界边**（部分可能是睫毛/眼卡，但数量过高） | 5/10 |
| 游戏可用性 | 5k tris 适合远景 NPC；三角面、手/刀不合格，不适合主角/绑定 | 7/10 远景，3/10 近景 |
| **总分** | **5.5/10** | |

> P2 网格诊断（Blender，本地文件）：6,837 verts / 5,096 tris / **1,029 islands** / 895 个 ≤10 顶点岛 / 6,546 条非流形边 / 1 个 UV 层 / 1 个材质 / 4096² base color。低模游戏资产可以是多岛结构，但近千个碎岛意味着绑定、LOD 和碰撞都要额外清理。

### 5.2 H3.1（1,971,068 tris，60 credits）

| 维度 | 观察 | 分数 |
|---|---|---|
| 面数/体积 | **1,023,519 verts / 1,971,068 tris**；GLB **66.4MB**；4K Color/NormalGL/ORM 三张 PBR 贴图 | 2/10 游戏预算，8/10 细节 |
| 剪影 | 轮廓干净，箱子/羽织/刀/绑腿可读；背面箱子覆盖躯干，符合参考 | 8/10 |
| 脸/眼 | 眼、眉、鼻、嘴有几何+贴图，正面/3q 近景可认；牙齿是块状白面，眼高光是贴图，缺少真正眼球 | 7.5/10 |
| 头发 | 有独立发束和层次，背面发丝丰富；细发梢仍有融合/漂浮 | 7.5/10 |
| 服装 | 羽织褶皱、领口、腰带、扣子结构完整，棋盘格对齐较好；接缝处略拉伸 | 8/10 |
| 手指 | clay 下可见手指，但右手与背带融合、左手手指粘连，仍非生产级 | 5/10 |
| 刀/箱/耳饰 | 箱子木纹+金属包边最好（8/10）；刀柄在胸前、刀鞘在背后，接近参考摆法但握持关系不对、无刀镡/刃口；耳饰只剩细杆+红点，与头发融合 | 6/10 |
| 贴图/PBR | 4K PBR 套图，皮肤/布料/木纹干净；抬起脚的鞋底是灰色未贴图区 | 8/10 |
| 悬浮/破面 | **373 个连通岛（仅 12 个 ≤10 顶点）**、75,224 条非流形/边界边；相对 197 万面比 P2 干净得多；刀身与柄分离、鞋底灰块是可见 artifact | 7/10 |
| 游戏可用性 | 直接进游戏 4/10（1.97M tris / 66.4MB 必须重拓扑+LOD）；重拓扑到 20k–50k 后可 6.5/10；展示/概念评审 7.5/10 | |
| **总分** | **7.3/10** | |

> H3.1 网格诊断（Blender，本地文件）：1,023,519 verts / 1,971,068 tris / 373 islands / 12 个 ≤10 顶点岛 / 75,224 条非流形边 / 1 UV 层 / 1 材质 / 3×4096² PBR 贴图。相比 P2 的 1,029 岛/895 碎岛，H3.1 的拓扑结构相对干净，但绝对面数和文件体积是游戏不可接受的量级。

### 5.3 与参考图的差距（P2 vs H3.1）

- **姿势**：参考是 3/4 行走、双手在胸前；两个模型都保留了姿势。P2 手/袖完全融合；H3.1 有手指但右手与背带粘连。
- **箱子**：参考中箱子在背后、有木纹和金属包边。P2 是一块薄板 + 细条背带；H3.1 有厚度、木纹、金属包边，明显更接近。
- **刀**：参考中刀柄在右手附近、刀鞘向左后下方延伸。P2 生成一片薄片穿过胸侧；H3.1 刀柄在胸前、刀鞘在背后，摆法接近，但不在手里、无刀镡/刃口细节。
- **耳饰**：参考是明显的花札耳环。P2 只剩小碎片；H3.1 是细杆+红点，均未还原花札图案。
- **脸**：参考是动画平涂五官。P2 完全靠 4K 贴图，近景糊；H3.1 有眼窝/眉/鼻/嘴几何，近景可读，牙齿块状、眼高光为贴图。
- **羽织**：两者棋盘格都还原，H3.1 的褶皱、厚度、边缘更好；接缝处均有拉伸。
- **脚**：两者抬起脚的鞋底都有问题（P2 深色/疑似破洞，H3.1 灰色未贴图块）。
- **结论**：H3.1 在五官、发丝、服装、箱子、贴图上全面优于 P2；P2 仅在成本、体积、面数预算上占优。两者都不能直接作为生产资产。

---

## 6. 下一轮改进（可执行）

### 6.1 输入图

1. **多视图**：至少 front + back（官方建议 2–4 视图），文件名带 `front/back`；视图之间同姿势、同光照、同比例。可用 Tripo 的 `generate image-to-multiview` 把单张立绘扩成 4 视图，但扩图本身会引入猜测，需人工检查。
2. **去掉干扰物**：先做“身体 only”版本（去掉箱子、刀、耳饰），单独生成角色；刀/箱/耳饰作为独立道具生成，再在 Blender 组装。这能显著改善手部和胸前结构。
3. **A-pose**：绑定用途必须 A-pose，手臂离开躯干；本次手在胸前是手部融合的主因。
4. **分辨率**：1024² 是底线；有条件用 1536–2048 源图，主体 70–85%。
5. **纯色底**：白/浅灰；不要保留透明底直接上传（本次合成白底是正确做法）。

### 6.2 生成参数

1. **游戏主角**：H3.1 + `geometry_quality=detailed` + `face_limit=50000`（或 100000）+ `pbr=true` + `texture_quality=detailed`；生成后用 Blender 数三角面，超限再减面。
2. **绑定用低模**：P2 + `face_limit=20000–50000` + `quad=true` → **FBX**（quad 不能进 GLB）；或 H3.1 高模 → Blender 重拓扑成 quad。
3. **多 seed**：`-n 2` 或 `redo` 跑 2 个候选，挑手/刀最好的；记录 `model_seed`/`texture_seed`。
4. **贴图**：平涂动画风保留 `delight=false`；写实/需要引擎打光时用 `delight=true`；PBR 开。
5. **朝向**：`orientation=align_image` 便于和参考图对位；但后续还要处理时，官方建议在最后 `convert` 步骤再设 `export_orientation`。
6. **失败处理**：网络失败不要重复提交；`task get <id> --download` 续传；失败任务自动退款。

### 6.3 Blender 后处理

1. **重拓扑**：高模用 Instant Meshes / RetopoFlow / 手工；目标 20k–50k tris（PC 主角）或 5k–15k（NPC）。
2. **UV + 烘焙**：高模 → 低模 bake（base color/normal/AO）；或直接用 Tripo 的 4K 贴图重投影。
3. **手/脸/刀**：手部单独重做（或用手模替换）；刀/耳饰作为独立 mesh；脸保留贴图 + 轻微几何（鼻/嘴）即可，动画风不必做眼球几何。
4. **Toon**：Shader to RGB + ColorRamp + 描边（Solidify/Inverted Hull）；动画风不要直接上 PBR 高光。
5. **绑定**：Rigify/手动骨架；肩、肘、膝权重测试；A-pose 入绑定。
6. **验收**：front/3q/back 1024、25% 缩略、纯黑剪影、4× 局部（手/脸/刀）、360° 转台；检查悬浮块、破面、贴图接缝、脚底穿插。

### 6.4 成本与流程

- 每个概念先 `--dry-run`，确认模型/参数/预估；P2 探索（125 credits/次），H3.1 定稿（60 credits/次）；2 候选/概念 ≈ 185 credits。
- 先 P2 看轮廓，再用 H3.1 出高模；或反过来：H3.1 定稿 → 重拓扑成 P2 级低模。不要用 P2 5k 自适应结果直接当主角。
- 大文件（H3.1 66MB）预留下载时间/带宽；下载后先校验 GLB 完整性（本次曾出现 4MB 半截文件，Blender 报 “Bad GLB: file size doesn't match”）。

---

## 7. IP 边界与合规

- 本次参考图是**公开官方角色立绘**，仅用于**私人技术评估**；图片、GLB、渲染全部只存 `/tmp/tripo-demon-slayer/`，**未提交仓库、未商用、未再分发**。
- 未复制官方 Logo/文字/水印进仓库或项目资产；飞书只私发渲染给任务发起人。
- **产品化/入库必须换原创角色**；不得把鬼灭角色、服装、耳饰、箱子等衍生造型用于项目、Demo、宣传或商店素材。
- Tripo 条款：付费方案通常赋予用户输入/输出权利，但仍需自行确保上传素材的版权；不要把第三方 IP 用于商业生成。
- 本文档只记录方法、参数、数字和来源 URL，不包含角色图片或衍生模型。

---

## 8. 来源（访问日期 2026-11-23）

### 官方

- [O1] Tripo Help Center — *How to Get Better Image-to-3D Results*：<https://www.tripo3d.ai/help/features/how-to-get-better-image-to-3d-results>（站点直连 403；经 Wayback 快照读取正文）
- [O2] Tripo 开发者文档 — *图片生成 3D 模型（H 系列）*：<https://developers.tripo3d.com/zh/docs/generation-image-to-model/standard>
- [O3] Tripo 开发者文档 — *多视图生成 3D 模型（H 系列）*：<https://developers.tripo3d.com/zh/docs/generation-multiview-to-model/standard>
- [O4] Tripo 开发者文档 — *模型与版本*：<https://developers.tripo3d.com/zh/docs/models-and-versions>
- [O5] Tripo CLI 0.11.2 内置文档：`tripo docs --topic commands/generate`、`tripo docs --topic commands/make`（本地命令，2026-11-23）
- [O6] Tripo 官方博客 — *如何创建动漫风格的 3D 角色*：<https://www.tripo3d.ai/zh/blog/create-anime-inspired-3d-character>（站点 403，仅检索摘要，未作为关键论据）

### 社区 / 第三方

- [C1] Layer.ai — *Prompt Tripo for image-to-3D*：<https://help.layer.ai/articles/8007256752-prompt-tripo-for-image-to-3d>
- [C2] Figmee — *Tripo AI Tutorial: with Tips for Illustrations*：<https://figmee.me/en/blog/tripo-ai-illustration-3d-guide>
- [C3] Voyager — *Tripo AI Review 2026: Pricing, Free Plan, H3.1 and P2*：<https://voyager.so/blog/tripo-ai-review>
- [C4] SandBase — *Tripo P2 vs H3.1: The 20K Face Limit Test*：<https://blog.sandbase.ai/tripo-p2-vs-h3-1-image-to-3d-2027/>
- [C5] Crowjack — *From Character Brief to Reviewable 3D Candidate*：<https://crowjack.com/tripo-ai-workflow-for-game-creators>

### 参考图

- [R1] TV 动画《鬼灭之刃》官方门户全身角色立绘：<https://kimetsu.com/anime/portal/assets/img/chara/full/img_chara_full_1.png>（仅本地测试，不入库）

---

## 附录 A：本地测试文件（不入库）

```
/tmp/tripo-demon-slayer/
├── ref/portal/full_1.png                  # 官方原图 2020×1200
├── prep/tanjiro_1024_white.png            # 1024² 白底输入
├── out/p2/tripo-out/tanjiro-p2-convert-116f8545/model.glb
├── out/h31/tripo-out/tanjiro-h31-64d78c69/model.glb
├── render/p2/                             # 8 视角 + front/3q/back + clay + 剪影
├── render/h31/                            # 同上（H3.1）
├── render/p2_alpha/                       # 透明底合成/剪影
└── render_model.py / render_alpha.py      # Blender 渲染脚本
```

## 附录 B：复现命令（不含 key）

```bash
# 预处理（Pillow）
python3 - <<'EOF'
from PIL import Image
src = Image.open('ref/portal/full_1.png').convert('RGBA')
char = src.crop(src.getbbox())
W, H = char.size
target, subj_h = 1024, int(1024*0.85)
subj_w = round(W * subj_h / H)
char = char.resize((subj_w, subj_h), Image.LANCZOS)
canvas = Image.new('RGBA', (target, target), (255,255,255,255))
canvas.alpha_composite(char, ((target-subj_w)//2, (target-subj_h)//2))
canvas.convert('RGB').save('prep/tanjiro_1024_white.png')
EOF

# Dry-run（免费）
HTTPS_PROXY=http://127.0.0.1:7897 HTTP_PROXY=http://127.0.0.1:7897 \
  npx tripo-cli make prep/tanjiro_1024_white.png --for game-pc --then convert:gltf --profile cn --dry-run --json

# 生成（付费；先确认预估）
HTTPS_PROXY=http://127.0.0.1:7897 HTTP_PROXY=http://127.0.0.1:7897 \
  npx tripo-cli make prep/tanjiro_1024_white.png --for game-pc --then convert:gltf --profile cn -o out/p2 --json

# 渲染（Blender 3.4.1）
/Applications/Blender.app/Contents/MacOS/Blender -b -P render_model.py -- out/p2/tripo-out/*/model.glb render/p2 --finals

# 下载续传（网络中断时）
npx tripo-cli task get <task_id> --download --profile cn
```
