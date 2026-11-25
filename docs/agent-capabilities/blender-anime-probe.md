# Blender 二次元角色能力探针（T-20261121-029）

- 日期：2026-11-21
- 执行：game-artist worker（独立执行，探针性质，非最终交付）
- 样片：**青禾 / Qinghe**，原创小药师学徒
- 素材：`agent-probes/blender-anime-girl/`
- 结论版本：本文件 + `contact_sheet.png` + `qinghe.glb` 为唯一事实来源

---

## 0. 结论先行

**能跑通一整条“原创 → 程序化建模 → toon 材质 → 分层眼 → 22 骨骨架 → GLB → EEVEE 渲染 → 复导入验证”的美术链路，约 1 小时实际执行。**
但离“生产级二次元角色”仍有明显差距：拓扑/UV/权重是自动生成级别，头发/面部/手指没有专项绑定，本机 Blender 4.2.9 的 GPU 渲染路径完全不可用，Tripo 图生 3D 因无 key 未测。

> 2026-11-25 后续：T-20261125-011 在本样片上补做了**眨眼能力测试**
> （几何眼睑 + 6 morph targets + 7 s / 24 fps clip，Godot 4.6 / Blender 3.4.1 验证 27/27）。
> 产物见 `agent-probes/blink-test/`，方法/坑见 [`docs/BLINK.md`](../BLINK.md)。
> 本文件其余“无面部表情/动画”的判断指**原始 qinghe**，眨眼变体单独成资产。

### 0.1 实测能做到

| 能力 | 证据 |
|---|---|
| 原创程序化角色（头/发/五官/躯干/四肢/简化手/服装/鞋/配饰） | `scripts/build_qinghe.py` 单脚本生成，2:11 完成构建 |
| 轻 chibi 二次元比例、统一色板 | 4.8 头身；12 色主色板；1440×1800 四视图 |
| Toon/cel 材质 | EEVEE Shader-to-RGB 三段色阶；反向外壳描边 3.8 mm |
| 分层眼睛 + 虹膜贴图 | 眼白/虹膜/瞳孔/双高光 5 层贴合曲面 decal；256² 程序化虹膜 |
| 贴图 | 3 张 256² 嵌入 GLB：裙、围裙、虹膜；另生成发丝/阴影/背景贴图 |
| 基础绑定 | 22 骨（root + 21 deform），A-pose，自动最近骨权重，蒙皮 GLB |
| GLB 导出 + 复导入 | 7,015,008 B；3.4.1 复导入 2 mesh + 1 armature + 22 joints + 3 embedded images |
| 渲染与自检 | 正面/侧面/背面/3-4/脸部特写；角色卡；25% 缩略图；纯黑剪影 14.17% 覆盖 |

### 0.2 实测做不到 / 边界

| 限制 | 证据/原因 |
|---|---|
| **Blender 4.2.9 Workbench / EEVEE Next 渲染不可用** | 两者均 SIGSEGV（`DRW_state_set` / `DRW_state_reset` / `DRW_render_to_image`），**默认立方体也崩**，与本样片无关 |
| Blender 4.2.9 Cycles CPU 能跑，但 toon 不对 | 26.4 s/320×400/8spp 渲染成功；Shader-to-RGB 在 Cycles 不成立，角色整体变深色（`renders/engine42_cycles_cpu_test.png`） |
| Freestyle 描边不实用 | 320×400/8spp 单球：Freestyle visibility 51 s + 渲染 7 s；已改用 inverted-hull 外壳描边 |
| Tripo 图生 3D 未测 | 本机无 `TRIPO_API_KEY`（env 与 `teamai env list` 均为空）；API 经代理可达但返回 401 |
| 拓扑/UV 非生产级 | 头/身 voxel remesh + smooth；103,558 tris；无统一 UV 图集；仅眼/裙/围裙用贴图 |
| 面部侧视缺陷 | 分层眼 decal 在正侧面会看到眼白/虹膜浮贴在脸侧（侧视板可见） |
| 头发是低模发片/球体 | 平涂 toon；发丝贴图因各部件 UV 方向不一致未用于最终头发；无头发骨 |
| 绑定不完整 | 无 IK/约束/动画 clip；手指刚性绑手骨；无面部表情/口型/手指骨。眨眼变体已用形态键补齐（`blink-test`），但不改原始骨骼 |
| 几何偏重 | 角色 103,558 tris + 描边壳 101,870 tris（渲染约 205k tris）；移动端需 LOD/减面 |

### 0.3 当前阻塞（按重要性）

1. **Tripo key 缺失**：默认管线（参考图 → Tripo → Blender 清理）无法开始；本样片只覆盖 Blender-only 基线与“Tripo 后处理”可复用部分。
2. **Blender 4.2.9 GPU 渲染崩溃**：本机只能用 3.4.1 EEVEE Legacy 出图，或 4.2 Cycles CPU（但需把 toon 换成 Principled/烘焙）。
3. **生产级拓扑/UV/绑定** 未建设：需要 retopo/UV/权重/表情/动画专项，属于后续能力建设（T-20261121-031）。

---

## 1. 目标与时间盒

- 目标：用 Blender 实际做一个原创、可爱、二次元女性角色（贴图 + 基础绑定 + GLB + 渲染），验证“美术 agent + 本机管线”的真实边界，不追求最终质量。
- 约束：原创；不复制原神/任何 IP；不用付费资产；不改 `.claude/agents/game-artist.md`；不改其他项目；时间盒 1–2 h。
- 实际：约 1 小时（含 2 轮视觉迭代）；Blender 计算约 6 分钟：
  - 构建 + GLB 导出：2:11（GLB 导出本身 19.9 s）
  - 最终 6 张渲染板：87.2 s（首帧 53.5 s 含 shader 编译，稳态 8–9 s/帧）
  - 4.2 引擎探针 + 复导入校验：约 3 分钟

---

## 2. 角色与规格

**青禾 / Qinghe**，原创药师学徒。设计元素：青绿色波波头 + 双丸子 + 叶发簪 + 呆毛，琥珀色大眼，青玉连衣裙 + 奶油围裙 + 棕色药囊（带草药），金色滚边与腕饰。

| 项 | 实测值 |
|---|---|
| 比例 | 4.8 头身（轻 chibi）；身高 1.30 m，含呆毛 1.388 m |
| 尺寸 | 0.637 × 0.37 × 1.388 m（宽×深×高，含手臂/头发） |
| 网格 | 103,558 tris / 52,221 原始 verts（GLB 拆分后 54,539）；描边壳 101,870 tris / 53,464 verts |
| 材质 | 21 个 toon/emission 材质（皮肤 2、发 2、裙/围裙、玉/金/奶油、皮革 2、叶、眼 5、袖/口、描边等）；GLB 内 22 个 Principled 材质 |
| 贴图 | T_Dress、T_Apron、T_EyeIris（256²，嵌入 GLB）；另 T_Hair、T_Shadow、T_Backdrop |
| 骨架 | 22 骨：root、hips、spine、chest、neck、head、shoulder/upper_arm/forearm/hand L/R、thigh/shin/foot/toe L/R；A-pose；无动画 |
| 权重 | 最近骨段距离自动权重（k=2, power 4–4.5）；头部/发/眼/手/脚刚性绑定 |
| GLB | `qinghe.glb` 7,015,008 B；1 skin / 22 joints / 2 meshes / 22 materials / 3 images / 0 animations |
| .blend | `qinghe.blend` 20,208,544 B（打包贴图 + toon 材质 + 舞台/灯光/相机） |

**设计原创性**：未使用任何参考游戏/IP 的角色、服装、脸、logo 或素材；全部几何/纹理由脚本生成。色板与发型/服装为本任务原创组合。

---

## 3. 执行步骤（全部可复跑）

工作目录：`agent-probes/blender-anime-girl/`

```bash
# 1) 构建（Blender 3.4.1）
/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/build_qinghe.py
# -> qinghe.blend, qinghe.glb, textures/*.png
# -> QINGHE_BUILD_OK tris=103558 tris_outline=101870 verts=52221 bones=22 mats=21

# 2) 四视图/特写/剪影板
/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/render_qinghe.py
# -> renders/{front,side,back,three_quarter}.png 1440×1800; face_closeup.png 1440×1440
# -> renders/_silhouette_raw.png

# 3) 角色卡/缩略图/纯黑剪影
python3 scripts/make_sheets.py
# -> renders/contact_sheet.png, contact_sheet_25pct.png, silhouette_front.png

# 4) GLB 复导入校验
/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/validate_glb.py
# -> GLB_VALIDATE_OK ...
```

技术路线（从 `blender-wukong-ultimate` 的自研代码借鉴思路，未复制外部素材）：

1. 纯 Python/bpy 生成基础体（球/管/刀片/环形/盒/贴面 decal）。
2. 头/身体：voxel remesh（头 0.005 m / 身 0.006 m）+ smooth，得到连续轮廓（代价：无环线）。
3. 材质：EEVEE `Diffuse → Shader to RGB → ColorRamp（3 段 CONSTANT）→ Multiply 基础色 → Emission`；虹膜/高光/睫毛用发光材质。
4. 描边：复制角色网格、沿法线外扩 3.8 mm、翻转法线、Backface Culling + 深色材质（倒壳法），并剔除眼/眉/嘴/腮红等 decal 面，避免眼睛周围出现脏线。
5. 绑定：22 骨人形骨架；按骨段距离自动分配权重；GLB 导出前把材质换成 Principled 变体（toon 节点不可移植），导出后恢复。
6. 舞台：无缝圆柱背景（Generated 坐标渐变 emission）+ 发光地板 + 接触阴影面片 + 三点面光；Standard 视图变换。
7. 验证：3.4.1/4.2.9 复导入 GLB；角色卡/25% 缩略图/alpha 剪影。

---

## 4. 渲染引擎矩阵（本机实测）

| Blender / 引擎 | 命令/设置 | 结果 | 耗时 | 证据 |
|---|---|---|---|---|
| **3.4.1 / EEVEE Legacy** | 最终路径；1440×1800，32 spp | ✅ 6 张板成功 | 87.2 s（首帧 53.5 s 含编译，其余 8–9 s） | `renders/*.png` |
| 3.4.1 / EEVEE + Freestyle | 320×400，8 spp，单球测试 | ⚠️ 能出线，但 Freestyle visibility 51.4 s + 渲染 6.8 s，共约 60 s；不可用 | — | 已弃用，改倒壳描边 |
| **4.2.9 / Workbench** | 默认立方体，256×256，`--factory` | ❌ SIGSEGV（returncode -11），43.2 s 后崩；`qinghe.blend` 同样崩 | — | 崩溃栈：`drw_state_set` / `DRW_state_reset` / `DRW_render_to_image` |
| **4.2.9 / EEVEE Next** | `qinghe.blend`，480×600，8 spp | ❌ 同样 SIGSEGV（-11） | — | 同上 |
| 4.2.9 / Cycles CPU | `qinghe.blend`，320×400，8 spp，CPU | ⚠️ 渲染成功（exit 0） | 26.4 s | `renders/engine42_cycles_cpu_test.png`；toon 节点不兼容，角色变深色 |
| 3.4.1 / GLB 复导入 | `scripts/validate_glb.py` | ✅ 2 mesh + 1 armature，22 bones，3 images，UVMap，蒙皮 modifier | — | `GLB_VALIDATE_OK` |
| 4.2.9 / GLB 复导入 | 同上 | ✅ 资产本身正常；4.2 环境的 BlenderMCP 额外带出 1 个 Icosphere（GLB JSON 中不存在） | — | GLB JSON 25 nodes / 2 meshes / 0 animations |

说明：

- Freestyle 的“线稿”观感更好，但在本机（Intel HD 6000）visibility 计算过慢，因此最终用倒壳描边。倒壳还可随 GLB 一起导出（引擎端可选关闭）。
- 4.2.9 的崩溃发生在 draw manager，默认场景也复现，属于**本机 4.2 GPU 路径问题**，不是资产问题；结论是**本机 4.2 不能用于最终出图**，3.4.1 EEVEE Legacy 是当前可靠路径，4.2 Cycles CPU 可作后备但需替换 toon 材质。
- GLB 的 Principled 变体是给引擎/Cycles 用的；.blend 内保留 EEVEE toon 材质。两套材质在同一资产上验证过。

---

## 5. 质量自评（10 分制，按探针标准）

| 维度 | 分数 | 说明 |
|---|---|---|
| 比例/剪影 | 8.0 | 4.8 头身成立；头/发/裙/腿轮廓清楚；手臂略细、脖子偏长（高领+颈饰缓解） |
| 脸（正/3-4） | 7.5 | 大眼、虹膜层次、腮红、微笑、眉眼比例可爱；接近可用的 chibi 概念稿 |
| 脸（正侧面） | 5.0 | 眼白/虹膜 decal 浮贴在脸侧；无眼球体积/眼睑包裹 |
| 头发 | 7.0 | 波波头+双丸子+呆毛+叶簪剪影成立；平涂无发丝，发片有硬边 |
| 手/脚 | 5.0 | 手为掌+4 指+拇指的简化刚性块；靴子块面成立；无手指骨 |
| 服装/配色 | 7.5 | 围裙/裙/药囊/金边层级清楚；色板统一；细节停在块面 |
| 拓扑 | 3.0 | voxel remesh + smooth，无动画环线；103.6k tris 偏重 |
| UV/贴图 | 4.0 | 各部件自带 UV；无统一 atlas；仅 3 张实际贴图；皮肤/发为平涂 |
| 材质/风格 | 7.0 | 三段 cel + 倒壳描边，正/3-4 读感好；不可直接移植到引擎/Cycles |
| 绑定 | 5.0 | 22 骨 A-pose + 自动权重 + GLB 蒙皮验证；无 IK/表情/手指/头发/动画 |
| 展示/自检 | 8.0 | 四视图 + 特写 + 角色卡 + 25% 缩略图 + 纯黑剪影 + GLB 复导入 |
| **生产就绪度** | **2.0** | 作为能力探针/概念样片成立；不是可交付游戏资产 |

**最满意的部分**：正面/3-4 的脸、配色、围裙+药囊层级、倒壳描边的整体完成度。
**最不满意的部分**：侧视眼白浮贴、头发只有平涂、拓扑/UV 无法进入动画流程、描边让几何翻倍。

---

## 6. 差距清单（按优先级）

### P0（阻塞默认管线/生产交付）

| # | 差距 | 现状 | 下一步 | 建议负责 |
|---|---|---|---|---|
| P0-1 | Tripo 图生 3D 没测 | 无 key，401 | 取得 `TRIPO_API_KEY`，按 §7 跑通并记录 task id/credits | infra + game-artist |
| P0-2 | 拓扑/UV/权重非生产级 | voxel remesh；自动最近骨权重；无统一 UV | retopo + 环线 + UV atlas + 手绘权重；再用 animation-retarget-kit 做 walk/run 验证 | game-engineer + game-artist |
| P0-3 | 4.2.9 GPU 渲染崩溃 | Workbench/EEVEE Next 在默认立方体上也 SIGSEGV | 固定 3.4.1 出图；或修驱动/换机；4.2 Cycles CPU 需替换 toon | game-engineer |

### P1（质量/可移植性）

| # | 差距 | 下一步 |
|---|---|---|
| P1-1 | 侧视眼 decal 浮贴 | 改用眼球几何 + 贴图，或把眼睛画进头部 UV；加眼睑/睫毛几何 |
| P1-2 | 头发平涂、无发丝/发骨 | 统一头发 UV 后使用发丝贴图；加 2–3 根发骨；或曲线/发片 groom |
| P1-3 | 手部刚性、无手指骨 | 手部 retopo + 每指 2 骨；或先做握拳/张开两个状态 |
| P1-4 | 描边壳几何翻倍 | 引擎端后处理描边或可选 LOD；GLB 提供带/不带描边两版 |
| P1-5 | toon 节点不可移植 | 烘焙 cel 色阶到贴图/引擎 shader；GLB 仅保留 Principled 近似 |

### P2（打磨）

- 脖子偏长/手臂偏细：微调比例；或增加更大领口/袖型。
- 服装细节停在块面：可补刺绣、扣子、褶皱线。
- 表情/动画：眨眼已由 T-20261125-011 用几何眼睑 + 6 个 morph targets 补齐（7 s / 24 fps，含双眨与左右错帧）；仍缺口型、眉/颊联动、眼神 look-at 与身体动画。
- LOD：角色 103k tris + 描边 102k；目标移动端 <15k tris（含描边可选）。

---

## 7. Tripo 管线段（默认管线，本次未测）

用户 2026-11-21 指定默认管线：**原创参考图（front/side/back）→ Tripo 图生 3D（API）→ Blender 清理/重拓扑/绑骨/贴图/toon → GLB/VRM**。

### 7.1 本次实测状态

- `TRIPO_API_KEY`：未设置（`env` 无；`teamai env list` 返回 “No env variables defined”）。
- 网络：Tripo API 直连会超时；必须走系统代理 `http://127.0.0.1:7897`。
- 连通性/鉴权探测（无 key）：
  ```bash
  HTTPS_PROXY=http://127.0.0.1:7897 HTTP_PROXY=http://127.0.0.1:7897 \
    curl -sS -m 20 -o /tmp/tripo_probe.json -w '%{http_code}\n' \
    -X POST https://openapi.tripo3d.ai/v2/openapi/task \
    -H 'Content-Type: application/json' -d '{"type":"text_to_model"}'
  # -> HTTP 401
  # -> {"code":2,"status":"error","message":"Authentication required",
  #     "suggestion":"Check if your credentials is valid"}
  ```
- 结论：**网络可达、鉴权可用链路未验证；缺 key，图生 3D 未执行**。本报告不伪造 Tripo 输出，也不记录任何 key。

### 7.2 key 可用后的补测清单（建议由 T-20261121-031 执行）

1. **准备原创参考图**：
   - 当前 `renders/front|side|back.png` 是 70 mm 透视，不是严格正交；Tripo 输入建议重渲**正交** front/side/back（`cam.data.type='ORTHO'`，`ortho_scale≈1.55`，1024²，透明/纯色背景）。
   - 参考图必须是本角色原创渲染，不能用参考游戏/IP 图。
2. **调用 Tripo**：
   - 通过 `teamai env exec --` 注入 env，禁止把 key 写入脚本/日志/截图/聊天。
   - 按官方 v2 文档构造 `image_to_model`（或 multiview）请求，上传参考图，轮询 task，下载 GLB。
   - **记录**：task id、model version、credits、上传/生成/下载耗时、输入参考图。
3. **Blender 清理**：
   - 3.4.1 导入 Tripo GLB；检查 tris/UV/材质/骨骼/尺寸/朝向；重新缩放、居中、重命名。
   - retopo/decimate、统一 UV、toon 材质替换、22 骨重绑/权重、描边壳（可选）、GLB 导出。
   - 复用本探针的 `validate_glb.py` 与角色卡/渲染脚本；对 Tripo 生成的四视图做 A/B。
4. **验收**：
   - GLB 复导入（3.4.1）通过；骨骼/贴图/面数/尺寸报告；
   - front/side/back/3-4 渲染 1024–1920；记录引擎/耗时/崩溃；
   - 与 Blender-only 基线（本样片）对照，明确 Tripo 在“头部/脸部/发丝/拓扑”上的增益与仍需清理项；
   - 不在任何交付物中出现 key。

**当前 blocker**：`TRIPO_API_KEY` 缺失。**预期**（未验证，不能当结论）：Tripo 可能带来更有机的头脸与发丝初模，但拓扑/UV/绑定仍需 Blender 清理；本轮 Blender-only 基线可作为“无 Tripo 回退”和清理步骤的参照。

---

## 8. 交接（handoff）

| 对象 | 需要处理 |
|---|---|
| **game-engineer** | ① 4.2.9 GPU 崩溃定位/规避（固定 3.4.1 或修驱动）；② 减面/retopo/UV/权重；③ GLB 引擎导入（Godot/Unity/UE/Three.js）与描边开关；④ 后续动画/重定向；⑤ 将 toon 烘焙/移植到引擎 |
| **game-art-director** | 独立复评风格/比例/脸/发/服装是否达到系列 target；给 P0/P1 参数；决定是否保留此设计 |
| **game-qa-lead** | 验收口径：GLB 复导入、骨骼/贴图/尺寸、四视图、剪影、25% 缩略图；用本报告的数字建立 golden；不把“看起来更好”当验收 |
| **Tripo / T-20261121-031** | 提供 key 后按 §7 跑图生 3D；正交参考图 + task id/credits 记录；清理后再评审 |
| **后续能力建设** | T-20261121-031 可复用：`build_qinghe.py` 的构建/材质/绑定/GLB 导出、`render_qinghe.py` 的角色卡、`validate_glb.py`、`probe_engines_42.py` |

---

## 9. 产物清单

| 路径 | 内容 |
|---|---|
| `agent-probes/blender-anime-girl/qinghe.blend` | 完整场景（toon 材质、舞台、灯光、相机、22 骨） |
| `agent-probes/blender-anime-girl/qinghe.glb` | 7,015,008 B；2 mesh + 22 骨 + 3 嵌入贴图 |
| `agent-probes/blender-anime-girl/scripts/build_qinghe.py` | 建模/贴图/材质/绑定/GLB |
| `.../scripts/render_qinghe.py` | 四视图 + 特写 + 剪影 alpha |
| `.../scripts/make_sheets.py` | 角色卡 / 25% / 纯黑剪影 |
| `.../scripts/validate_glb.py` | GLB 复导入报告 |
| `.../scripts/probe_engines_42.py` | 4.2.9 引擎探针（Workbench/EEVEE Next/Cycles CPU） |
| `.../textures/` | T_Dress / T_Apron / T_EyeIris / T_Hair / T_Shadow / T_Backdrop |
| `.../renders/front|side|back|three_quarter.png` | 1440×1800，32 spp |
| `.../renders/face_closeup.png` | 1440×1440 |
| `.../renders/contact_sheet.png` | 2×2 角色卡（含标签） |
| `.../renders/contact_sheet_25pct.png` | 25% 缩略图自检 |
| `.../renders/silhouette_front.png` | 纯黑剪影（白底，alpha>0.5，覆盖 14.17%） |
| `.../renders/engine42_cycles_cpu_test.png` | 4.2.9 Cycles CPU 反例（toon 节点变深色） |

---

## 10. 约束合规

- ✅ 原创角色与资产；未复制原神/任何 IP 的角色、服装、脸、logo、UI；未使用付费资产/外部模型。
- ✅ 未修改 `.claude/agents/game-artist.md`；未改其他项目；仅改 `agent-probes/`、`docs/agent-capabilities/`、`docs/task-plans/game-demos.md`（任务记录）。
- ✅ 未在任何文件/日志/截图/聊天中写入 Tripo key（本机根本没有 key）。
- ✅ 失败如实记录：Freestyle 过慢、4.2 GPU 崩溃、Cycles toon 不兼容、Tripo 401、侧视眼浮贴、头发平涂。
- ⚠️ 本样片是**能力探针**，不是生产资产；不能直接作为游戏角色交付。
